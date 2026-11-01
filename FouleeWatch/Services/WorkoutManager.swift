import Foundation
import HealthKit
import CoreLocation
import WatchKit
import Observation

/// Séance de course sur la Watch : HKWorkoutSession (cardio, distance, calories, enregistrement dans Santé)
/// + GPS pour le tracé et le dénivelé.
@MainActor
@Observable
final class WorkoutManager: NSObject {
    enum Phase { case idle, active, saving, summary }

    private(set) var phase: Phase = .idle
    private(set) var isPaused = false
    private(set) var isOutdoor = true
    /// Mètres.
    private(set) var distance: Double = 0
    private(set) var heartRate: Double = 0
    private(set) var averageHeartRate: Double = 0
    private(set) var maxHeartRate: Double = 0
    private(set) var activeEnergy: Double = 0
    /// Allure instantanée en s/km (moyenne glissante ~30 s).
    private(set) var currentPace: Double = 0
    private(set) var elevationGain: Double = 0
    private(set) var summary: WatchRunPayload?
    private(set) var sentToPhone = false
    var errorMessage: String?

    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var routeBuilder: HKWorkoutRouteBuilder?
    @ObservationIgnored private var points: [RoutePoint] = []
    @ObservationIgnored private var segment = 0
    @ObservationIgnored private var altitudeReference: Double?
    @ObservationIgnored private var paceWindow: [(time: Date, distance: Double)] = []
    @ObservationIgnored private var nextKm = 1
    @ObservationIgnored private var startDate: Date?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    // MARK: - Autorisations

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
        let read: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
        ]
        try? await healthStore.requestAuthorization(toShare: share, read: read)
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Contrôle de la séance

    func start(outdoor: Bool) async {
        resetMetrics()
        isOutdoor = outdoor
        errorMessage = nil

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = outdoor ? .outdoor : .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            if outdoor {
                routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
                locationManager.startUpdatingLocation()
            }

            let start = Date()
            startDate = start
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            phase = .active
            WKInterfaceDevice.current().play(.start)
        } catch {
            errorMessage = "Impossible de démarrer : \(error.localizedDescription)"
            locationManager.stopUpdatingLocation()
            phase = .idle
        }
    }

    func togglePause() {
        guard let session else { return }
        if isPaused { session.resume() } else { session.pause() }
    }

    func end() {
        guard let session else { return }
        phase = .saving
        locationManager.stopUpdatingLocation()
        session.end()
    }

    func dismissSummary() {
        summary = nil
        phase = .idle
    }

    func elapsedTime(at date: Date) -> TimeInterval {
        builder?.elapsedTime(at: date) ?? 0
    }

    private func resetMetrics() {
        distance = 0
        heartRate = 0
        averageHeartRate = 0
        maxHeartRate = 0
        activeEnergy = 0
        currentPace = 0
        elevationGain = 0
        isPaused = false
        summary = nil
        sentToPhone = false
        points = []
        segment = 0
        altitudeReference = nil
        paceWindow = []
        nextKm = 1
        startDate = nil
    }

    // MARK: - Fin de séance

    private func finish(at date: Date) async {
        guard let builder else {
            phase = .idle
            return
        }
        var workoutID: UUID?
        do {
            try await builder.endCollection(at: date)
            let workout = try await builder.finishWorkout()
            workoutID = workout?.uuid
            if let workout, let routeBuilder, !points.isEmpty {
                _ = try? await routeBuilder.finishRoute(with: workout, metadata: nil)
            }
        } catch {
            errorMessage = "Course non enregistrée dans Santé : \(error.localizedDescription)"
        }

        let payload = WatchRunPayload(
            id: UUID(),
            healthKitID: workoutID,
            startDate: startDate ?? date,
            endDate: date,
            duration: builder.elapsedTime,
            distance: distance,
            calories: activeEnergy > 0 ? activeEnergy : nil,
            averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
            maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil,
            elevationGain: elevationGain,
            isOutdoor: isOutdoor,
            points: points
        )
        summary = payload
        sentToPhone = payload.distance >= 50 && PhoneConnector.shared.send(payload)

        session = nil
        self.builder = nil
        routeBuilder = nil
        phase = .summary
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Mises à jour

    private func handle(state: HKWorkoutSessionState, date: Date) {
        switch state {
        case .paused:
            isPaused = true
            paceWindow = []
            currentPace = 0
            WKInterfaceDevice.current().play(.stop)
        case .running:
            if isPaused {
                isPaused = false
                segment += 1
                WKInterfaceDevice.current().play(.start)
            }
        case .ended:
            Task { await finish(at: date) }
        default:
            break
        }
    }

    private func update(heartRate hr: Double?, average: Double?, max: Double?, energy: Double?, distance newDistance: Double?) {
        if let hr { heartRate = hr }
        if let average { averageHeartRate = average }
        if let max { maxHeartRate = max }
        if let energy { activeEnergy = energy }
        if let newDistance {
            distance = newDistance
            updatePace(at: Date())
            while distance >= Double(nextKm) * 1000 {
                WKInterfaceDevice.current().play(.notification)
                nextKm += 1
            }
        }
    }

    private func updatePace(at time: Date) {
        guard !isPaused else { return }
        paceWindow.append((time, distance))
        while paceWindow.count > 2, let first = paceWindow.first, time.timeIntervalSince(first.time) > 30 {
            paceWindow.removeFirst()
        }
        guard let first = paceWindow.first else { return }
        let dd = distance - first.distance
        let dt = time.timeIntervalSince(first.time)
        currentPace = dd > 10 && dt > 0 ? dt / (dd / 1000) : 0
    }

    private func process(_ locations: [CLLocation]) {
        guard phase == .active, !isPaused else { return }
        let accurate = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 30 }
        guard !accurate.isEmpty else { return }
        routeBuilder?.insertRouteData(accurate) { _, _ in }
        for location in accurate {
            let altitude: Double
            if location.verticalAccuracy >= 0, location.verticalAccuracy <= 20 {
                altitude = location.altitude
            } else {
                altitude = points.last?.altitude ?? location.altitude
            }
            if let reference = altitudeReference {
                if altitude - reference >= 3 {
                    elevationGain += altitude - reference
                    altitudeReference = altitude
                } else if reference - altitude >= 3 {
                    altitudeReference = altitude
                }
            } else {
                altitudeReference = altitude
            }
            points.append(RoutePoint(location: location, altitude: altitude, segment: segment))
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in self.handle(state: toState, date: date) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.errorMessage = message }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var hr: Double?
        var average: Double?
        var max: Double?
        var energy: Double?
        var distance: Double?
        let bpm = HKUnit.count().unitDivided(by: .minute())

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let stats = workoutBuilder.statistics(for: quantityType) else { continue }
            switch quantityType {
            case HKQuantityType(.heartRate):
                hr = stats.mostRecentQuantity()?.doubleValue(for: bpm)
                average = stats.averageQuantity()?.doubleValue(for: bpm)
                max = stats.maximumQuantity()?.doubleValue(for: bpm)
            case HKQuantityType(.activeEnergyBurned):
                energy = stats.sumQuantity()?.doubleValue(for: .kilocalorie())
            case HKQuantityType(.distanceWalkingRunning):
                distance = stats.sumQuantity()?.doubleValue(for: .meter())
            default:
                break
            }
        }
        Task { @MainActor in
            self.update(heartRate: hr, average: average, max: max, energy: energy, distance: distance)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

// MARK: - CLLocationManagerDelegate

extension WorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.process(locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

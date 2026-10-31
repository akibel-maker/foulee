import Foundation
import CoreLocation
import CoreMotion
import Observation

/// Résultat brut d'une course terminée.
struct RunResult {
    let startDate: Date
    let endDate: Date
    let movingTime: TimeInterval
    let distance: Double
    let elevationGain: Double
    let points: [RoutePoint]
    let locations: [CLLocation]
    let steps: Int?
}

/// Enregistre une course en direct : GPS (y compris écran verrouillé), chrono, allure, dénivelé, cadence.
@MainActor
@Observable
final class RunTracker: NSObject, CLLocationManagerDelegate {
    enum State { case idle, running, paused }

    private(set) var state: State = .idle
    private(set) var points: [RoutePoint] = []
    private(set) var distance: Double = 0
    private(set) var movingTime: TimeInterval = 0
    private(set) var elevationGain: Double = 0
    /// Allure instantanée (moyenne glissante sur ~30 s), en s/km.
    private(set) var currentPace: Double = 0
    private(set) var lastKmPace: Double = 0
    /// Cadence instantanée en pas/minute.
    private(set) var cadence: Double = 0
    private(set) var steps: Int = 0
    private(set) var currentLocation: CLLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// Précision GPS actuelle (m), pour l'indicateur de signal.
    private(set) var gpsAccuracy: Double?

    var averagePace: Double { distance > 20 ? movingTime / (distance / 1000) : 0 }
    var isActive: Bool { state != .idle }
    var hasLocationPermission: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    private let manager = CLLocationManager()
    private let pedometer = CMPedometer()
    private let coach = VoiceCoach()
    @ObservationIgnored private var backgroundSession: CLBackgroundActivitySession?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var startDate: Date?
    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var segmentStart: Date?
    @ObservationIgnored private var segment = 0
    @ObservationIgnored private var lastRecorded: CLLocation?
    @ObservationIgnored private var altitudeReference: Double?
    @ObservationIgnored private var lastAltitude: Double?
    @ObservationIgnored private var paceWindow: [(time: Date, distance: Double)] = []
    @ObservationIgnored private var nextKm = 1
    @ObservationIgnored private var timeAtLastKm: TimeInterval = 0
    @ObservationIgnored private var recordedLocations: [CLLocation] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
    }

    // MARK: - Autorisations & aperçu

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Démarre le GPS sans enregistrer (pour la carte et les suggestions d'itinéraire).
    func startPreview() {
        guard hasLocationPermission else {
            if authorization == .notDetermined { requestPermission() }
            return
        }
        manager.startUpdatingLocation()
    }

    func stopPreview() {
        guard state == .idle else { return }
        manager.stopUpdatingLocation()
    }

    // MARK: - Contrôle de la course

    func start(voiceCoach: Bool) {
        resetMetrics()
        coach.enabled = voiceCoach
        state = .running
        let now = Date()
        startDate = now
        segmentStart = now
        backgroundSession = CLBackgroundActivitySession()
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        startPedometer(from: now)
        startTimer()
        coach.say("C'est parti, bonne course !")
    }

    func pause() {
        guard state == .running, let segmentStart else { return }
        accumulated += Date().timeIntervalSince(segmentStart)
        self.segmentStart = nil
        movingTime = accumulated
        state = .paused
        lastRecorded = nil
        paceWindow.removeAll()
        currentPace = 0
        coach.say("Course en pause.")
    }

    func resume() {
        guard state == .paused else { return }
        segment += 1
        segmentStart = Date()
        state = .running
        coach.say("Reprise de la course.")
    }

    /// Termine la course et renvoie les données collectées.
    func finish() -> RunResult? {
        guard state != .idle, let startDate else { return nil }
        if state == .running, let segmentStart {
            accumulated += Date().timeIntervalSince(segmentStart)
        }
        let result = RunResult(
            startDate: startDate,
            endDate: Date(),
            movingTime: accumulated,
            distance: distance,
            elevationGain: elevationGain,
            points: points,
            locations: recordedLocations,
            steps: steps > 0 ? steps : nil
        )
        coach.say("Course terminée. \(Fmt.km(distance)) kilomètres en \(Fmt.spokenDuration(accumulated)). Bravo !")
        stopRecording()
        return result
    }

    /// Abandonne la course sans l'enregistrer.
    func discard() {
        stopRecording()
        resetMetrics()
    }

    private func stopRecording() {
        state = .idle
        timer?.invalidate()
        timer = nil
        pedometer.stopUpdates()
        manager.allowsBackgroundLocationUpdates = false
        backgroundSession?.invalidate()
        backgroundSession = nil
        segmentStart = nil
    }

    private func resetMetrics() {
        points = []
        recordedLocations = []
        distance = 0
        movingTime = 0
        elevationGain = 0
        currentPace = 0
        lastKmPace = 0
        cadence = 0
        steps = 0
        accumulated = 0
        segment = 0
        lastRecorded = nil
        altitudeReference = nil
        lastAltitude = nil
        paceWindow = []
        nextKm = 1
        timeAtLastKm = 0
        startDate = nil
    }

    private var movingTimeNow: TimeInterval {
        accumulated + (segmentStart.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state == .running else { return }
                self.movingTime = self.movingTimeNow
            }
        }
    }

    private func startPedometer(from date: Date) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: date) { [weak self] data, _ in
            guard let data else { return }
            let stepCount = data.numberOfSteps.intValue
            let currentCadence = data.currentCadence?.doubleValue
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.steps = stepCount
                if let currentCadence { self.cadence = currentCadence * 60 }
            }
        }
    }

    // MARK: - Traitement GPS

    private func process(_ location: CLLocation) {
        currentLocation = location
        gpsAccuracy = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
        guard state == .running else { return }
        // Filtre les points imprécis ou périmés.
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 25 else { return }
        guard abs(location.timestamp.timeIntervalSinceNow) < 10 else { return }

        let altitude: Double
        if location.verticalAccuracy >= 0, location.verticalAccuracy <= 20 {
            altitude = location.altitude
        } else {
            altitude = lastAltitude ?? location.altitude
        }

        if let previous = lastRecorded {
            let d = location.distance(from: previous)
            let dt = location.timestamp.timeIntervalSince(previous.timestamp)
            guard dt > 0 else { return }
            // Saut GPS aberrant (> 43 km/h) : on ignore le point.
            if d / dt > 12 { return }
            distance += d
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
        lastAltitude = altitude
        lastRecorded = location
        recordedLocations.append(location)
        points.append(RoutePoint(location: location, altitude: altitude, segment: segment))

        updateCurrentPace(at: location.timestamp)
        checkKilometer()
    }

    private func updateCurrentPace(at time: Date) {
        paceWindow.append((time, distance))
        while paceWindow.count > 2, let first = paceWindow.first, time.timeIntervalSince(first.time) > 30 {
            paceWindow.removeFirst()
        }
        guard let first = paceWindow.first else { return }
        let dd = distance - first.distance
        let dt = time.timeIntervalSince(first.time)
        currentPace = dd > 10 && dt > 0 ? dt / (dd / 1000) : 0
    }

    private func checkKilometer() {
        while distance >= Double(nextKm) * 1000 {
            let now = movingTimeNow
            lastKmPace = now - timeAtLastKm
            timeAtLastKm = now
            coach.say("\(nextKm) kilomètre\(nextKm > 1 ? "s" : ""). Temps : \(Fmt.spokenDuration(now)). "
                      + "Dernier kilomètre : \(Fmt.spokenPace(lastKmPace)).")
            nextKm += 1
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            for location in locations { self.process(location) }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            self.authorization = status
            if self.hasLocationPermission { manager.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Erreurs temporaires (pas de signal) : CoreLocation réessaie tout seul.
    }
}

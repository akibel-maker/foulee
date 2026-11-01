import Foundation
import HealthKit
import CoreLocation

/// Accès à l'app Santé : fréquence cardiaque, poids, enregistrement et import des courses.
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var typesToShare: Set<HKSampleType> {
        [HKObjectType.workoutType(),
         HKSeriesType.workoutRoute(),
         HKQuantityType(.distanceWalkingRunning),
         HKQuantityType(.activeEnergyBurned)]
    }

    private var typesToRead: Set<HKObjectType> {
        [HKObjectType.workoutType(),
         HKSeriesType.workoutRoute(),
         HKQuantityType(.distanceWalkingRunning),
         HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.heartRate),
         HKQuantityType(.bodyMass),
         HKCategoryType(.sleepAnalysis),
         HKQuantityType(.stepCount)]
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    // MARK: - Lecture

    /// Fréquence cardiaque moyenne sur une période (si une Apple Watch était portée).
    func averageHeartRate(from start: Date, to end: Date) async -> Double? {
        guard isAvailable else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.heartRate), predicate: predicate),
            options: .discreteAverage
        )
        let stats = try? await descriptor.result(for: store)
        return stats?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
    }

    /// Dernier poids enregistré dans Santé (kg).
    func latestBodyMass() async -> Double? {
        guard isAvailable else { return nil }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let samples = try? await descriptor.result(for: store)
        return samples?.first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    /// Échantillons de sommeil (Apple Watch, iPhone, autres apps) sur une période.
    func sleepSamples(from start: Date, to end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: store)
    }

    /// Nombre de pas par jour (clé : début de journée).
    func dailySteps(from start: Date, to end: Date) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: start)
        let predicate = HKQuery.predicateForSamples(withStart: anchor, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: predicate),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var result: [Date: Double] = [:]
        for stats in collection.statistics() {
            if let value = stats.sumQuantity()?.doubleValue(for: .count()) {
                result[calendar.startOfDay(for: stats.startDate)] = value
            }
        }
        return result
    }

    func fetchRunningWorkouts(limit: Int = 1000) async throws -> [HKWorkout] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForWorkouts(with: .running))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: limit
        )
        return try await descriptor.result(for: store)
    }

    func distance(of workout: HKWorkout) -> Double {
        workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .meter()) ?? 0
    }

    func energy(of workout: HKWorkout) -> Double? {
        workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
    }

    func heartRate(of workout: HKWorkout) -> Double? {
        workout.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
    }

    /// Tracé GPS d'un entraînement Santé.
    func locations(for workout: HKWorkout) async throws -> [CLLocation] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.sample(type: HKSeriesType.workoutRoute(), predicate: HKQuery.predicateForObjects(from: workout))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let routes = try await descriptor.result(for: store).compactMap { $0 as? HKWorkoutRoute }
        var all: [CLLocation] = []
        for route in routes {
            all += try await locations(of: route)
        }
        return all
    }

    private func locations(of route: HKWorkoutRoute) async throws -> [CLLocation] {
        /// Collecte les points reçus par lots ; protégé par un verrou car HealthKit rappelle depuis un autre fil.
        final class Accumulator: @unchecked Sendable {
            private let lock = NSLock()
            private var _locations: [CLLocation] = []
            private var _finished = false

            var finished: Bool {
                get { lock.withLock { _finished } }
                set { lock.withLock { _finished = newValue } }
            }

            var locations: [CLLocation] {
                get { lock.withLock { _locations } }
                set { lock.withLock { _locations = newValue } }
            }
        }
        let store = self.store
        let accumulator = Accumulator()
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                guard !accumulator.finished else { return }
                if let error {
                    accumulator.finished = true
                    continuation.resume(throwing: error)
                    return
                }
                accumulator.locations += locations ?? []
                if done {
                    accumulator.finished = true
                    continuation.resume(returning: accumulator.locations)
                }
            }
            store.execute(query)
        }
    }

    // MARK: - Écriture

    /// Enregistre la course dans Santé (avec son tracé). Renvoie l'identifiant de l'entraînement.
    func saveWorkout(run: Run, locations: [CLLocation]) async throws -> UUID? {
        guard isAvailable else { return nil }
        try await requestAuthorization()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: run.startDate)
        var samples: [HKSample] = [
            HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning),
                             quantity: HKQuantity(unit: .meter(), doubleValue: run.distance),
                             start: run.startDate, end: run.endDate)
        ]
        if let kcal = run.calories {
            samples.append(HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                            start: run.startDate, end: run.endDate))
        }
        try await builder.addSamples(samples)
        try await builder.endCollection(at: run.endDate)
        guard let workout = try await builder.finishWorkout() else { return nil }

        if !locations.isEmpty {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
            try await routeBuilder.insertRouteData(locations)
            _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }
        return workout.uuid
    }
}

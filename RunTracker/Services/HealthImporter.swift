import Foundation
import SwiftData

/// Importe dans l'historique les courses déjà présentes dans l'app Santé (Apple Watch, autres apps…).
@MainActor
enum HealthImporter {
    static func importRuns(into context: ModelContext) async throws -> Int {
        let health = HealthKitManager.shared
        guard health.isAvailable else { return 0 }
        try await health.requestAuthorization()

        let workouts = try await health.fetchRunningWorkouts()
        let existing = try context.fetch(FetchDescriptor<Run>())
        let knownIDs = Set(existing.compactMap(\.healthKitID))
        let ownBundle = Bundle.main.bundleIdentifier

        var imported = 0
        for workout in workouts {
            guard !knownIDs.contains(workout.uuid),
                  !isFromThisApp(workout.sourceRevision.source.bundleIdentifier, ownBundle: ownBundle) else { continue }

            let run = Run(name: Run.defaultName(for: workout.startDate),
                          startDate: workout.startDate,
                          endDate: workout.endDate,
                          duration: workout.duration,
                          distance: health.distance(of: workout))
            run.source = "sante"
            run.healthKitID = workout.uuid
            run.calories = health.energy(of: workout)
            run.averageHeartRate = health.heartRate(of: workout)

            if let locations = try? await health.locations(for: workout), locations.count > 1 {
                run.setPoints(locations.map { RoutePoint(location: $0, segment: 0) })
                run.updateDerivedMetrics(recomputeDistance: run.distance == 0)
            }
            context.insert(run)
            imported += 1
        }
        try context.save()
        return imported
    }

    /// Les courses de Foulée (iPhone ou Watch, dont l'identifiant commence par celui de l'app) arrivent déjà directement.
    private static func isFromThisApp(_ bundleID: String, ownBundle: String?) -> Bool {
        guard let ownBundle else { return false }
        return bundleID == ownBundle || bundleID.hasPrefix(ownBundle + ".")
    }
}

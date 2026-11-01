import Foundation
import Observation

/// Nombre de pas par jour (app Santé), pour les habitudes automatiques.
@MainActor
@Observable
final class StepsStore {
    private(set) var stepsByDay: [Date: Double] = [:]
    private(set) var isLoading = false

    func load(days: Int = 400) async {
        let health = HealthKitManager.shared
        guard health.isAvailable, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        try? await health.requestAuthorization()
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else { return }
        if let steps = try? await health.dailySteps(from: start, to: end) {
            stepsByDay = steps
        }
    }

    func steps(on day: Date) -> Double {
        stepsByDay[Calendar.current.startOfDay(for: day)] ?? 0
    }
}

import Foundation
import Observation

/// Nuits de sommeil lues dans l'app Santé (enregistrées par l'Apple Watch, l'iPhone ou une autre app).
@MainActor
@Observable
final class SleepStore {
    /// Triées de la plus ancienne à la plus récente.
    private(set) var nights: [SleepNight] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    func load(days: Int = 90) async {
        let health = HealthKitManager.shared
        guard health.isAvailable, !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            try await health.requestAuthorization()
            let end = Date()
            guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else { return }
            let samples = try await health.sleepSamples(from: start, to: end)
            let intervals = samples.map { SleepSampleInterval(start: $0.startDate, end: $0.endDate, value: $0.value) }
            nights = SleepAggregator.nights(from: intervals)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadIfNeeded() async {
        if !hasLoaded { await load() }
    }

    var lastNight: SleepNight? { nights.last }

    /// Nuits des `count` derniers jours.
    func recentNights(_ count: Int) -> [SleepNight] {
        guard let limit = Calendar.current.date(byAdding: .day, value: -count, to: Calendar.current.startOfDay(for: .now)) else {
            return nights
        }
        return nights.filter { $0.date > limit }
    }

    func averageSleep(lastDays: Int) -> TimeInterval? {
        let recent = recentNights(lastDays)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0) { $0 + $1.asleep } / Double(recent.count)
    }

    /// Nuit qui précède une date (même jour de réveil).
    func night(before date: Date) -> SleepNight? {
        let day = Calendar.current.startOfDay(for: date)
        return nights.first { $0.date == day }
    }
}

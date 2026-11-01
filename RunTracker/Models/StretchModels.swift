import Foundation
import SwiftData

/// Une séance d'étirements terminée.
@Model
final class StretchSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var routineID: String = ""
    var routineName: String = ""
    /// Durée réellement pratiquée, en secondes.
    var duration: TimeInterval = 0
    var moveCount: Int = 0

    init(date: Date, routineID: String, routineName: String, duration: TimeInterval, moveCount: Int) {
        self.date = date
        self.routineID = routineID
        self.routineName = routineName
        self.duration = duration
        self.moveCount = moveCount
    }
}

/// Routine créée par l'utilisateur à partir de la bibliothèque de mouvements.
@Model
final class CustomStretchRoutine {
    var id: UUID = UUID()
    var name: String = ""
    var tintRaw: String = HabitColor.orange.rawValue
    var stepsData: Data?
    var createdAt: Date = Date()

    init(name: String, tint: HabitColor, steps: [StretchStep]) {
        self.name = name
        self.tintRaw = tint.rawValue
        self.steps = steps
    }

    var tint: HabitColor {
        get { HabitColor(rawValue: tintRaw) ?? .orange }
        set { tintRaw = newValue.rawValue }
    }

    var steps: [StretchStep] {
        get {
            guard let stepsData else { return [] }
            return (try? JSONDecoder().decode([StretchStep].self, from: stepsData)) ?? []
        }
        set { stepsData = try? JSONEncoder().encode(newValue) }
    }

    var asRoutine: StretchRoutine {
        let zones = Set(steps.compactMap { StretchLibrary.move($0.moveID) }.flatMap(\.zones))
        return StretchRoutine(id: "custom-\(id.uuidString)", name: name,
                              summary: zones.isEmpty ? "Routine personnelle" : zones.map(\.label).sorted().joined(separator: ", "),
                              symbol: "star.fill", tint: tint, steps: steps, isCustom: true)
    }
}

struct StretchStats {
    var currentStreak = 0
    var longestStreak = 0
    var daysCompleted = 0
    var totalMinutes = 0
    var lastSession: Date?
    var sessionCount = 0
}

enum StretchStatsCalculator {
    static func stats(for sessions: [StretchSession], now: Date = .now) -> StretchStats {
        let cal = Calendar.current
        let days = Set(sessions.map { cal.startOfDay(for: $0.date) })
        var stats = StretchStats()
        stats.daysCompleted = days.count
        stats.sessionCount = sessions.count
        stats.totalMinutes = Int((sessions.reduce(0) { $0 + $1.duration } / 60).rounded())
        stats.lastSession = sessions.map(\.date).max()

        // Plus longue série de jours consécutifs.
        var longest = 0
        var run = 0
        var previous: Date?
        for day in days.sorted() {
            if let previous, cal.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previous = day
        }
        stats.longestStreak = longest

        // Série en cours : aujourd'hui ne casse pas la série tant que la journée n'est pas finie.
        let today = cal.startOfDay(for: now)
        var day = days.contains(today) ? today : (cal.date(byAdding: .day, value: -1, to: today) ?? today)
        var current = 0
        while days.contains(day) {
            current += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        stats.currentStreak = current
        return stats
    }

    /// Minutes d'étirements pratiquées un jour donné (pour les habitudes automatiques).
    static func minutes(on day: Date, sessions: [StretchSession]) -> Double {
        let cal = Calendar.current
        return sessions.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.duration } / 60
    }
}

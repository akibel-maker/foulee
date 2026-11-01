import Foundation
import SwiftData
import SwiftUI

enum HabitKind: String, CaseIterable, Identifiable {
    /// Fait / pas fait.
    case check
    /// Quantité à atteindre (verres d'eau, minutes de lecture, pas…).
    case count

    var id: Self { self }
    var label: String { self == .check ? "Oui / Non" : "Quantité" }
}

enum HabitSchedule: String, CaseIterable, Identifiable {
    case daily, weekdays, timesPerWeek

    var id: Self { self }

    var label: String {
        switch self {
        case .daily: "Tous les jours"
        case .weekdays: "Certains jours"
        case .timesPerWeek: "X fois par semaine"
        }
    }
}

enum HabitAutoSource: String, CaseIterable, Identifiable {
    case none, steps, stretching

    var id: Self { self }

    var label: String {
        switch self {
        case .none: "Saisie manuelle"
        case .steps: "Pas (app Santé)"
        case .stretching: "Minutes d'étirements (Foulée)"
        }
    }
}

enum HabitColor: String, CaseIterable, Identifiable {
    case orange, red, pink, purple, indigo, blue, teal, green, yellow

    var id: Self { self }

    var color: Color {
        switch self {
        case .orange: .orange
        case .red: .red
        case .pink: .pink
        case .purple: .purple
        case .indigo: .indigo
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .yellow: .yellow
        }
    }
}

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "✅"
    var colorRaw: String = HabitColor.orange.rawValue
    var kindRaw: String = HabitKind.check.rawValue
    /// Quantité visée par jour (1 pour une habitude Oui / Non).
    var target: Double = 1
    var unit: String = ""
    var scheduleRaw: String = HabitSchedule.daily.rawValue
    /// Jours prévus : bit 0 = lundi … bit 6 = dimanche.
    var weekdaysMask: Int = 0b111_1111
    var timesPerWeek: Int = 3
    var reminderEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var autoSourceRaw: String = HabitAutoSource.none.rawValue
    var createdAt: Date = Date()
    var isArchived: Bool = false
    var sortOrder: Int = 0
    /// Valeurs saisies par jour, clé "aaaa-mm-jj".
    var logData: Data?

    init(name: String, emoji: String) {
        self.name = name
        self.emoji = emoji
    }

    var kind: HabitKind {
        get { HabitKind(rawValue: kindRaw) ?? .check }
        set { kindRaw = newValue.rawValue }
    }

    var schedule: HabitSchedule {
        get { HabitSchedule(rawValue: scheduleRaw) ?? .daily }
        set { scheduleRaw = newValue.rawValue }
    }

    var autoSource: HabitAutoSource {
        get { HabitAutoSource(rawValue: autoSourceRaw) ?? .none }
        set { autoSourceRaw = newValue.rawValue }
    }

    var habitColor: HabitColor {
        get { HabitColor(rawValue: colorRaw) ?? .orange }
        set { colorRaw = newValue.rawValue }
    }

    var color: Color { habitColor.color }

    var effectiveTarget: Double { kind == .check ? 1 : max(target, 1) }

    var log: [String: Double] {
        get {
            guard let logData else { return [:] }
            return (try? JSONDecoder().decode([String: Double].self, from: logData)) ?? [:]
        }
        set { logData = try? JSONEncoder().encode(newValue) }
    }

    func loggedValue(on day: Date) -> Double {
        log[HabitDay.key(day)] ?? 0
    }

    func setLoggedValue(_ value: Double, on day: Date) {
        var current = log
        current[HabitDay.key(day)] = value > 0 ? value : nil
        log = current
    }

    /// Ex. « Tous les jours », « Lun, Mer, Ven », « 3 fois par semaine ».
    var scheduleDescription: String {
        switch schedule {
        case .daily:
            return "Tous les jours"
        case .weekdays:
            let names = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]
            let days = (0..<7).filter { weekdaysMask & (1 << $0) != 0 }.map { names[$0] }
            return days.count == 7 ? "Tous les jours" : days.joined(separator: ", ")
        case .timesPerWeek:
            return "\(timesPerWeek) fois par semaine"
        }
    }

    func formatValue(_ value: Double) -> String {
        if autoSource == .steps { return value.formatted(.number.precision(.fractionLength(0))) }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : value.formatted(.number.precision(.fractionLength(1)))
    }
}

/// Modèles proposés à la création.
struct HabitPreset: Identifiable {
    let name: String
    let emoji: String
    let color: HabitColor
    var kind: HabitKind = .check
    var target: Double = 1
    var unit: String = ""
    var schedule: HabitSchedule = .daily
    var timesPerWeek: Int = 3
    var autoSource: HabitAutoSource = .none
    var id: String { name }

    static let all: [HabitPreset] = [
        HabitPreset(name: "Boire de l'eau", emoji: "💧", color: .blue, kind: .count, target: 8, unit: "verres"),
        HabitPreset(name: "Méditer", emoji: "🧘", color: .purple),
        HabitPreset(name: "Lire", emoji: "📖", color: .orange, kind: .count, target: 20, unit: "min"),
        HabitPreset(name: "Étirements", emoji: "🤸", color: .teal, kind: .count, target: 5, unit: "min",
                    autoSource: .stretching),
        HabitPreset(name: "10 000 pas", emoji: "👟", color: .green, kind: .count, target: 10_000, unit: "pas",
                    autoSource: .steps),
        HabitPreset(name: "Renforcement", emoji: "💪", color: .red, schedule: .timesPerWeek, timesPerWeek: 3),
        HabitPreset(name: "Fruits et légumes", emoji: "🥗", color: .green, kind: .count, target: 5, unit: "portions"),
        HabitPreset(name: "Pas d'alcool", emoji: "🚫", color: .pink),
        HabitPreset(name: "Coucher avant 23 h", emoji: "🌙", color: .indigo),
        HabitPreset(name: "Pas d'écran au lit", emoji: "📵", color: .yellow),
    ]
}

enum HabitDay {
    static var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    static func key(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// 0 = lundi … 6 = dimanche
    static func weekdayIndex(_ date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }
}

import Foundation
import SwiftData
import SwiftUI

enum GoalKind: String, CaseIterable, Identifiable, Codable {
    case distance, runs, duration, elevation, longestRun, sleepAverage, sleepNights

    var id: Self { self }

    var label: String {
        switch self {
        case .distance: "Distance"
        case .runs: "Nombre de sorties"
        case .duration: "Temps de course"
        case .elevation: "Dénivelé"
        case .longestRun: "Sortie longue"
        case .sleepAverage: "Sommeil moyen"
        case .sleepNights: "Nuits complètes"
        }
    }

    var explanation: String {
        switch self {
        case .distance: "Total de kilomètres courus sur la période."
        case .runs: "Nombre de courses sur la période."
        case .duration: "Temps total passé à courir."
        case .elevation: "Dénivelé positif cumulé."
        case .longestRun: "Réussir au moins une course de cette distance."
        case .sleepAverage: "Durée moyenne de sommeil par nuit (données Santé)."
        case .sleepNights: "Nombre de nuits où tu atteins ton objectif de sommeil."
        }
    }

    var systemImage: String {
        switch self {
        case .distance: "figure.run"
        case .runs: "calendar.badge.checkmark"
        case .duration: "stopwatch"
        case .elevation: "mountain.2"
        case .longestRun: "flag.checkered"
        case .sleepAverage: "bed.double"
        case .sleepNights: "moon.stars"
        }
    }

    var unit: String {
        switch self {
        case .distance, .longestRun: "km"
        case .runs: "sorties"
        case .duration, .sleepAverage: "h"
        case .elevation: "m"
        case .sleepNights: "nuits"
        }
    }

    var color: Color {
        switch self {
        case .distance: .orange
        case .runs: .green
        case .duration: .yellow
        case .elevation: .brown
        case .longestRun: .red
        case .sleepAverage, .sleepNights: .indigo
        }
    }

    var defaultTarget: Double {
        switch self {
        case .distance: 20
        case .runs: 3
        case .duration: 3
        case .elevation: 300
        case .longestRun: 10
        case .sleepAverage: 7.5
        case .sleepNights: 5
        }
    }

    var step: Double {
        switch self {
        case .distance: 5
        case .runs, .sleepNights: 1
        case .duration, .sleepAverage: 0.5
        case .elevation: 50
        case .longestRun: 1
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .distance: 1...5000
        case .runs: 1...365
        case .duration: 0.5...500
        case .elevation: 50...100_000
        case .longestRun: 1...100
        case .sleepAverage: 4...12
        case .sleepNights: 1...366
        }
    }

    var isSleep: Bool { self == .sleepAverage || self == .sleepNights }

    /// Les objectifs cumulatifs progressent jour après jour (on peut calculer un « reste à faire par jour »).
    var isCumulative: Bool { ![.longestRun, .sleepAverage].contains(self) }

    func format(_ value: Double) -> String {
        switch self {
        case .distance, .longestRun:
            return value.formatted(.number.precision(.fractionLength(value < 100 ? 1 : 0)))
        case .duration:
            return value.formatted(.number.precision(.fractionLength(1)))
        case .sleepAverage:
            return Fmt.sleep(value * 3600)
        case .runs, .elevation, .sleepNights:
            return "\(Int(value.rounded()))"
        }
    }

    /// Valeur + unité, ex. « 12,4 km », « 7 h 12 ».
    func formatWithUnit(_ value: Double) -> String {
        self == .sleepAverage ? format(value) : "\(format(value)) \(unit)"
    }
}

enum GoalPeriod: String, CaseIterable, Identifiable, Codable {
    case week, month, year, custom

    var id: Self { self }

    var label: String {
        switch self {
        case .week: "Chaque semaine"
        case .month: "Chaque mois"
        case .year: "Cette année"
        case .custom: "Jusqu'à une date"
        }
    }

    var suffix: String {
        switch self {
        case .week: "par semaine"
        case .month: "par mois"
        case .year: "par an"
        case .custom: ""
        }
    }

    var streakUnit: String {
        switch self {
        case .week: "sem."
        case .month: "mois"
        case .year: "an(s)"
        case .custom: ""
        }
    }

    var component: Calendar.Component? {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        case .custom: nil
        }
    }
}

@Model
final class Goal {
    var id: UUID = UUID()
    var title: String = ""
    var kindRaw: String = GoalKind.distance.rawValue
    var periodRaw: String = GoalPeriod.week.rawValue
    var target: Double = 0
    var createdAt: Date = Date()
    /// Date limite pour la période « Jusqu'à une date ».
    var deadline: Date?

    init(kind: GoalKind, period: GoalPeriod, target: Double, title: String = "", deadline: Date? = nil) {
        self.kindRaw = kind.rawValue
        self.periodRaw = period.rawValue
        self.target = target
        self.title = title
        self.deadline = deadline
    }

    var kind: GoalKind {
        get { GoalKind(rawValue: kindRaw) ?? .distance }
        set { kindRaw = newValue.rawValue }
    }

    var period: GoalPeriod {
        get { GoalPeriod(rawValue: periodRaw) ?? .week }
        set { periodRaw = newValue.rawValue }
    }

    var displayTitle: String {
        title.isEmpty ? Goal.autoTitle(kind: kind, period: period, target: target, deadline: deadline) : title
    }

    static func autoTitle(kind: GoalKind, period: GoalPeriod, target: Double, deadline: Date?) -> String {
        let value = kind.formatWithUnit(target)
        let base: String
        switch kind {
        case .distance, .runs, .elevation: base = value
        case .duration: base = "\(value) de course"
        case .longestRun: base = "Une sortie de \(value)"
        case .sleepAverage: base = "\(value) de sommeil en moyenne"
        case .sleepNights: base = "\(value) de bon sommeil"
        }
        if period == .custom, let deadline {
            return "\(base) d'ici le \(Fmt.shortDate(deadline))"
        }
        return period.suffix.isEmpty ? base : "\(base) \(period.suffix)"
    }
}

/// Modèles proposés à la création d'un objectif.
struct GoalPreset: Identifiable {
    let kind: GoalKind
    let period: GoalPeriod
    let target: Double
    var id: String { "\(kind.rawValue)-\(period.rawValue)-\(target)" }

    static let all: [GoalPreset] = [
        GoalPreset(kind: .distance, period: .week, target: 20),
        GoalPreset(kind: .runs, period: .week, target: 3),
        GoalPreset(kind: .distance, period: .month, target: 100),
        GoalPreset(kind: .longestRun, period: .month, target: 15),
        GoalPreset(kind: .sleepAverage, period: .week, target: 7.5),
        GoalPreset(kind: .elevation, period: .month, target: 1000),
        GoalPreset(kind: .distance, period: .year, target: 1000),
    ]
}

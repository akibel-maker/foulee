import Foundation
import SwiftUI

/// Une nuit de sommeil, reconstituée à partir des échantillons de l'app Santé (Apple Watch, iPhone, autres apps).
struct SleepNight: Identifiable, Hashable {
    /// Jour du réveil (début de journée).
    let date: Date
    var asleep: TimeInterval
    var core: TimeInterval
    var deep: TimeInterval
    var rem: TimeInterval
    var unspecified: TimeInterval
    var awake: TimeInterval
    var inBed: TimeInterval
    var bedtime: Date?
    var wakeTime: Date?

    var id: Date { date }
    var hasStages: Bool { core + deep + rem > 0 }

    func duration(of stage: SleepStage) -> TimeInterval {
        switch stage {
        case .deep: deep
        case .core: core
        case .rem: rem
        case .unspecified: unspecified
        case .awake: awake
        }
    }
}

enum SleepStage: String, CaseIterable, Identifiable {
    case deep, core, rem, unspecified, awake

    var id: Self { self }

    var label: String {
        switch self {
        case .deep: "Profond"
        case .core: "Léger"
        case .rem: "Paradoxal"
        case .unspecified: "Endormi"
        case .awake: "Éveillé"
        }
    }

    var color: Color {
        switch self {
        case .deep: Color(red: 0.24, green: 0.25, blue: 0.75)
        case .core: Color(red: 0.36, green: 0.55, blue: 0.98)
        case .rem: Color(red: 0.55, green: 0.80, blue: 1.0)
        case .unspecified: Color(red: 0.42, green: 0.48, blue: 0.95)
        case .awake: Color(red: 1.0, green: 0.55, blue: 0.40)
        }
    }

    /// Phases de sommeil (sans l'éveil), dans l'ordre d'affichage des graphiques.
    static let asleepStages: [SleepStage] = [.deep, .core, .rem, .unspecified]
}

/// Échantillon brut : `value` reprend les valeurs de HKCategoryValueSleepAnalysis
/// (0 au lit, 1 endormi non précisé, 2 éveillé, 3 léger, 4 profond, 5 paradoxal).
struct SleepSampleInterval {
    let start: Date
    let end: Date
    let value: Int
}

enum SleepAggregator {
    private static let asleepValues: Set<Int> = [1, 3, 4, 5]

    /// Regroupe les échantillons par nuit. Les sources qui se chevauchent (iPhone + Watch) ne sont comptées qu'une fois.
    static func nights(from samples: [SleepSampleInterval], calendar: Calendar = .current) -> [SleepNight] {
        // Un sommeil commencé à 23 h ou à 1 h est rattaché au même jour de réveil.
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.start.addingTimeInterval(12 * 3600)) }
        var result: [SleepNight] = []
        for (day, items) in grouped {
            func union(_ values: Set<Int>) -> TimeInterval {
                unionLength(items.filter { values.contains($0.value) }.map { ($0.start, $0.end) })
            }
            let asleepItems = items.filter { asleepValues.contains($0.value) }
            let inBedItems = items.filter { $0.value == 0 }
            var asleep = union(asleepValues)
            let inBed = unionLength((asleepItems + inBedItems).map { ($0.start, $0.end) })
            // Anciennes données iPhone : seulement « au lit ».
            let reference = asleepItems.isEmpty ? inBedItems : asleepItems
            if asleepItems.isEmpty { asleep = inBed }
            // On ignore les siestes et les bribes.
            guard asleep >= 3600 else { continue }

            let core = union([3])
            let deep = union([4])
            let rem = union([5])
            var night = SleepNight(date: day, asleep: asleep, core: core, deep: deep, rem: rem,
                                   unspecified: 0, awake: union([2]), inBed: inBed,
                                   bedtime: reference.map(\.start).min(),
                                   wakeTime: reference.map(\.end).max())
            night.unspecified = max(0, asleep - core - deep - rem)
            result.append(night)
        }
        return result.sorted { $0.date < $1.date }
    }

    /// Durée totale couverte par des intervalles qui peuvent se chevaucher.
    static func unionLength(_ intervals: [(Date, Date)]) -> TimeInterval {
        let sorted = intervals.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }
        var total = 0.0
        var currentStart: Date?
        var currentEnd: Date?
        for (start, end) in sorted {
            if let ce = currentEnd, start <= ce {
                if end > ce { currentEnd = end }
            } else {
                if let cs = currentStart, let ce = currentEnd { total += ce.timeIntervalSince(cs) }
                currentStart = start
                currentEnd = end
            }
        }
        if let cs = currentStart, let ce = currentEnd { total += ce.timeIntervalSince(cs) }
        return total
    }

    /// Minutes écoulées depuis 18 h (gère le passage de minuit pour les moyennes d'heure de coucher).
    static func minutesSinceEvening(_ date: Date, calendar: Calendar = .current) -> Double {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
        return (minutes - 18 * 60 + 1440).truncatingRemainder(dividingBy: 1440)
    }
}

import Foundation
import SwiftData
import CoreLocation

/// Temps intermédiaire (par kilomètre).
struct Split: Codable, Hashable, Identifiable {
    var index: Int
    var duration: TimeInterval
    var distance: Double
    var elevationGain: Double

    var id: Int { index }
    /// Allure en secondes par kilomètre.
    var pace: Double { distance > 0 ? duration / (distance / 1000) : 0 }
}

/// Meilleur temps réalisé sur une distance de référence au sein d'une course.
struct BestEffort: Codable, Hashable {
    var distance: Double
    var time: TimeInterval
}

@Model
final class Run {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    /// Temps en mouvement (pauses exclues), en secondes.
    var duration: TimeInterval = 0
    /// Distance en mètres.
    var distance: Double = 0
    /// Dénivelé positif en mètres.
    var elevationGain: Double = 0
    var averageHeartRate: Double?
    var calories: Double?
    var steps: Int?
    var notes: String = ""
    /// "app" (iPhone), "watch" (app Foulée de l'Apple Watch) ou "sante" (importée depuis l'app Santé).
    var source: String = "app"
    var healthKitID: UUID?

    @Attribute(.externalStorage) var routeData: Data?
    var splitsData: Data?
    var bestEffortsData: Data?

    init(name: String, startDate: Date, endDate: Date, duration: TimeInterval, distance: Double) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.distance = distance
    }

    // MARK: - Données dérivées

    var points: [RoutePoint] {
        guard let routeData else { return [] }
        return (try? JSONDecoder().decode([RoutePoint].self, from: routeData)) ?? []
    }

    func setPoints(_ newPoints: [RoutePoint]) {
        routeData = try? JSONEncoder().encode(newPoints)
    }

    var splits: [Split] {
        guard let splitsData else { return [] }
        return (try? JSONDecoder().decode([Split].self, from: splitsData)) ?? []
    }

    var bestEfforts: [BestEffort] {
        guard let bestEffortsData else { return [] }
        return (try? JSONDecoder().decode([BestEffort].self, from: bestEffortsData)) ?? []
    }

    func bestEffort(for distance: Double) -> TimeInterval? {
        bestEfforts.first { abs($0.distance - distance) < 1 }?.time
    }

    /// Allure moyenne en secondes par kilomètre.
    var averagePace: Double { distance > 0 ? duration / (distance / 1000) : 0 }

    /// Cadence moyenne en pas par minute.
    var averageCadence: Double? {
        guard let steps, duration > 0 else { return nil }
        return Double(steps) / (duration / 60)
    }

    /// Recalcule splits, meilleurs efforts (et éventuellement distance/dénivelé) à partir du tracé.
    func updateDerivedMetrics(recomputeDistance: Bool) {
        let pts = points
        guard pts.count > 1 else { return }
        let track = RunMetrics.Track(points: pts)
        if recomputeDistance {
            distance = track.totalDistance
        }
        if recomputeDistance || elevationGain == 0 {
            elevationGain = track.totalGain
        }
        splitsData = try? JSONEncoder().encode(RunMetrics.splits(track))
        bestEffortsData = try? JSONEncoder().encode(RunMetrics.bestEfforts(track))
    }

    static func defaultName(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Course du matin"
        case 12..<14: return "Course de midi"
        case 14..<18: return "Course de l'après-midi"
        case 18..<22: return "Course du soir"
        default: return "Course de nuit"
        }
    }
}

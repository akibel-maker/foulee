import Foundation
import CoreLocation
import MapKit
import Observation

enum Difficulty: String, CaseIterable, Identifiable {
    case facile, modere, difficile

    var id: Self { self }

    var label: String {
        switch self {
        case .facile: "Facile"
        case .modere: "Modéré"
        case .difficile: "Difficile"
        }
    }

    var systemImage: String {
        switch self {
        case .facile: "leaf"
        case .modere: "flame"
        case .difficile: "mountain.2"
        }
    }

    /// Classe un parcours selon son dénivelé positif par kilomètre.
    static func classify(gainPerKm: Double) -> Difficulty {
        switch gainPerKm {
        case ..<8: .facile
        case ..<20: .modere
        default: .difficile
        }
    }
}

struct SuggestedRoute: Identifiable, Equatable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let distance: Double
    /// nil si l'altimétrie n'a pas pu être récupérée.
    let elevationGain: Double?
    let elevationProfile: [Double]
    let direction: String

    var gainPerKm: Double? {
        guard let elevationGain, distance > 0 else { return nil }
        return elevationGain / (distance / 1000)
    }

    var difficulty: Difficulty? { gainPerKm.map(Difficulty.classify) }

    /// Durée estimée : 10 m de D+ ≈ 100 m de plat.
    func estimatedDuration(pace secondsPerKm: Double) -> TimeInterval {
        let equivalentKm = (distance + (elevationGain ?? 0) * 10) / 1000
        return equivalentKm * secondsPerKm
    }

    static func == (lhs: SuggestedRoute, rhs: SuggestedRoute) -> Bool { lhs.id == rhs.id }
}

/// Génère des boucles qui partent et reviennent au point de départ, sur chemins piétons (Apple Plans),
/// puis les classe par difficulté grâce au dénivelé.
@MainActor
@Observable
final class RouteSuggester {
    private(set) var isLoading = false
    private(set) var suggestions: [SuggestedRoute] = []
    var errorMessage: String?

    private enum RouteError: Error { case noRoute }

    private static let directions: [(bearing: Double, label: String)] = [
        (0, "vers le nord"), (90, "vers l'est"), (180, "vers le sud"), (270, "vers l'ouest"),
    ]

    func suggest(from start: CLLocationCoordinate2D, targetKm: Double, difficulty: Difficulty) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let target = targetKm * 1000

        var loops: [(coords: [CLLocationCoordinate2D], distance: Double, label: String)] = []
        await withTaskGroup(of: Optional<(coords: [CLLocationCoordinate2D], distance: Double, label: String)>.self) { group in
            for direction in Self.directions {
                group.addTask {
                    guard let loop = try? await Self.buildLoop(start: start, bearing: direction.bearing, target: target) else {
                        return nil
                    }
                    return (loop.coords, loop.distance, direction.label)
                }
            }
            for await loop in group {
                if let loop { loops.append(loop) }
            }
        }

        guard !loops.isEmpty else {
            suggestions = []
            errorMessage = "Impossible de calculer un itinéraire ici. Réessaie dans une minute (Apple Plans limite le nombre de requêtes)."
            return
        }

        var routes: [SuggestedRoute] = []
        for loop in loops {
            let samples = Geo.downsample(Geo.resample(loop.coords, spacing: 50), maxCount: 100)
            let profile = (try? await ElevationService.elevations(for: samples)) ?? []
            let gain: Double? = profile.isEmpty ? nil : RunMetrics.elevationGain(profile, threshold: 1)
            routes.append(SuggestedRoute(coordinates: loop.coords, distance: loop.distance,
                                         elevationGain: gain, elevationProfile: profile, direction: loop.label))
        }

        suggestions = Self.rank(routes, for: difficulty, target: target)
        if routes.allSatisfy({ $0.elevationGain == nil }) {
            errorMessage = "Dénivelé indisponible (pas de connexion ?) : les itinéraires ne sont pas classés par difficulté."
        }
    }

    func clear() {
        suggestions = []
        errorMessage = nil
    }

    /// Le meilleur itinéraire pour la difficulté demandée arrive en premier.
    private static func rank(_ routes: [SuggestedRoute], for difficulty: Difficulty, target: Double) -> [SuggestedRoute] {
        let gains = routes.compactMap(\.gainPerKm).sorted()
        let median = gains.isEmpty ? 0 : gains[gains.count / 2]
        func score(_ route: SuggestedRoute) -> Double {
            let distancePenalty = abs(route.distance - target) / target * 50
            guard let g = route.gainPerKm else { return distancePenalty }
            switch difficulty {
            case .facile: return g + distancePenalty
            case .difficile: return -g + distancePenalty
            case .modere: return abs(g - max(median, 10)) + distancePenalty
            }
        }
        return routes.sorted { score($0) < score($1) }
    }

    /// Boucle : départ → 3 points sur un cercle → retour, en ajustant le rayon pour coller à la distance voulue.
    private static func buildLoop(start: CLLocationCoordinate2D, bearing: Double, target: Double) async throws
        -> (coords: [CLLocationCoordinate2D], distance: Double) {
        // Périmètre d'un carré inscrit ≈ 5,66 r ; les rues ajoutent ~25 % → r ≈ distance / 7.
        var radius = target / 7
        var best: (coords: [CLLocationCoordinate2D], distance: Double)?
        for _ in 0..<2 {
            let loop = try await route(start: start, bearing: bearing, radius: radius)
            if best == nil || abs(loop.distance - target) < abs(best!.distance - target) { best = loop }
            let ratio = target / max(loop.distance, 1)
            if abs(1 - ratio) < 0.08 { break }
            radius *= ratio
        }
        guard let best else { throw RouteError.noRoute }
        return best
    }

    private static func route(start: CLLocationCoordinate2D, bearing: Double, radius: Double) async throws
        -> (coords: [CLLocationCoordinate2D], distance: Double) {
        let center = start.offset(by: radius, bearing: bearing)
        let startAngle = bearing + 180 // angle du point de départ vu depuis le centre
        let waypoints = [90.0, 180, 270].map { center.offset(by: radius, bearing: startAngle + $0) }
        let stops = [start] + waypoints + [start]

        var coords: [CLLocationCoordinate2D] = []
        var distance = 0.0
        for i in 0..<(stops.count - 1) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: stops[i]))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: stops[i + 1]))
            request.transportType = .walking
            let response = try await MKDirections(request: request).calculate()
            guard let leg = response.routes.first else { throw RouteError.noRoute }
            coords += leg.polyline.coordinates
            distance += leg.distance
        }
        return (coords, distance)
    }
}

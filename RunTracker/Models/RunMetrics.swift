import Foundation
import CoreLocation

/// Calculs purs sur un tracé : distance cumulée, temps en mouvement, dénivelé, splits, records.
enum RunMetrics {

    /// Distances de référence pour les records personnels.
    static let effortDistances: [(distance: Double, label: String)] = [
        (1000, "1 km"),
        (5000, "5 km"),
        (10000, "10 km"),
        (21097.5, "Semi-marathon"),
        (42195, "Marathon"),
    ]

    /// Séries cumulées le long du tracé (une valeur par point).
    struct Track {
        private(set) var distance: [Double] = []
        private(set) var time: [Double] = []
        private(set) var gain: [Double] = []
        private(set) var altitude: [Double] = []

        init(points: [RoutePoint], gainThreshold: Double = 3) {
            guard let first = points.first else { return }
            distance = [0]
            time = [0]
            gain = [0]
            altitude = [first.altitude]
            var reference = first.altitude
            var totalGain = 0.0
            for i in 1..<points.count {
                let a = points[i - 1]
                let b = points[i]
                var dd = 0.0
                var dt = 0.0
                if a.segment == b.segment {
                    dd = CLLocation(latitude: a.latitude, longitude: a.longitude)
                        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
                    dt = max(0, b.timestamp.timeIntervalSince(a.timestamp))
                }
                distance.append(distance[i - 1] + dd)
                time.append(time[i - 1] + dt)
                // Hystérésis : on ignore les petites variations d'altitude (bruit GPS).
                if b.altitude - reference >= gainThreshold {
                    totalGain += b.altitude - reference
                    reference = b.altitude
                } else if reference - b.altitude >= gainThreshold {
                    reference = b.altitude
                }
                gain.append(totalGain)
                altitude.append(b.altitude)
            }
        }

        var totalDistance: Double { distance.last ?? 0 }
        var totalTime: Double { time.last ?? 0 }
        var totalGain: Double { gain.last ?? 0 }

        /// Valeur d'une série interpolée à une distance donnée.
        func interpolate(_ values: [Double], atDistance d: Double) -> Double {
            guard let last = distance.indices.last, last > 0 else { return values.first ?? 0 }
            if d <= distance[0] { return values[0] }
            if d >= distance[last] { return values[last] }
            var lo = 0
            var hi = last
            while lo < hi {
                let mid = (lo + hi) / 2
                if distance[mid] < d { lo = mid + 1 } else { hi = mid }
            }
            let i = max(lo, 1)
            let d0 = distance[i - 1]
            let d1 = distance[i]
            let f = d1 > d0 ? (d - d0) / (d1 - d0) : 1
            return values[i - 1] + (values[i] - values[i - 1]) * f
        }
    }

    static func splits(_ track: Track) -> [Split] {
        let total = track.totalDistance
        guard total > 0 else { return [] }
        var result: [Split] = []
        var km = 1
        var previousTime = 0.0
        var previousGain = 0.0
        var previousDistance = 0.0
        while Double(km) * 1000 <= total {
            let d = Double(km) * 1000
            let t = track.interpolate(track.time, atDistance: d)
            let g = track.interpolate(track.gain, atDistance: d)
            result.append(Split(index: km, duration: t - previousTime, distance: 1000, elevationGain: g - previousGain))
            previousTime = t
            previousGain = g
            previousDistance = d
            km += 1
        }
        let rest = total - previousDistance
        if rest >= 100 {
            result.append(Split(index: km, duration: track.totalTime - previousTime, distance: rest,
                                elevationGain: track.totalGain - previousGain))
        }
        return result
    }

    /// Meilleur temps (fenêtre glissante) pour couvrir `target` mètres.
    static func bestEffort(_ track: Track, distance target: Double) -> TimeInterval? {
        guard track.totalDistance >= target else { return nil }
        var best = Double.infinity
        for i in track.distance.indices {
            let endDistance = track.distance[i] + target
            if endDistance > track.totalDistance { break }
            let endTime = track.interpolate(track.time, atDistance: endDistance)
            best = min(best, endTime - track.time[i])
        }
        return best.isFinite && best > 0 ? best : nil
    }

    static func bestEfforts(_ track: Track) -> [BestEffort] {
        effortDistances.compactMap { item in
            bestEffort(track, distance: item.distance).map { BestEffort(distance: item.distance, time: $0) }
        }
    }

    /// Dénivelé positif cumulé d'une série d'altitudes.
    static func elevationGain(_ altitudes: [Double], threshold: Double) -> Double {
        guard var reference = altitudes.first else { return 0 }
        var gain = 0.0
        for a in altitudes.dropFirst() {
            if a - reference >= threshold {
                gain += a - reference
                reference = a
            } else if reference - a >= threshold {
                reference = a
            }
        }
        return gain
    }
}

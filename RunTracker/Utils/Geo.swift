import Foundation
import CoreLocation
import MapKit

extension CLLocationCoordinate2D {
    /// Point situé à `meters` mètres dans la direction `bearing` (degrés, 0 = nord).
    func offset(by meters: Double, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let angular = meters / earthRadius
        let theta = bearing * .pi / 180
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(theta))
        let lon2 = lon1 + atan2(sin(theta) * sin(angular) * cos(lat1), cos(angular) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    func distance(to other: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

enum Geo {
    /// Rectangle englobant un tracé, avec une marge, pour cadrer la carte.
    static func mapRect(for coordinates: [CLLocationCoordinate2D], padding: Double = 0.15) -> MKMapRect? {
        guard !coordinates.isEmpty else { return nil }
        let rect = MKPolyline(coordinates: coordinates, count: coordinates.count).boundingMapRect
        let dx = max(rect.width * padding, 300)
        let dy = max(rect.height * padding, 300)
        return rect.insetBy(dx: -dx, dy: -dy)
    }

    /// Garde au plus `maxCount` éléments, régulièrement espacés.
    static func downsample<T>(_ items: [T], maxCount: Int) -> [T] {
        guard items.count > maxCount, maxCount > 1 else { return items }
        let step = Double(items.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { items[Int((Double($0) * step).rounded())] }
    }

    /// Ré-échantillonne un tracé tous les `spacing` mètres (pour l'altimétrie).
    static func resample(_ coords: [CLLocationCoordinate2D], spacing: Double) -> [CLLocationCoordinate2D] {
        guard var previous = coords.first else { return [] }
        var result = [previous]
        var sinceLast = 0.0
        for c in coords.dropFirst() {
            sinceLast += previous.distance(to: c)
            if sinceLast >= spacing {
                result.append(c)
                sinceLast = 0
            }
            previous = c
        }
        if let last = coords.last, result.count > 1 || coords.count > 1 { result.append(last) }
        return result
    }
}

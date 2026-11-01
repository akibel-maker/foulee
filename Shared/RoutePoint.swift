import Foundation
import CoreLocation

/// Un point GPS enregistré pendant la course.
struct RoutePoint: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var timestamp: Date
    /// Numéro de segment : il change à chaque pause, pour ne pas compter la distance/le temps de pause.
    var segment: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double, altitude: Double, timestamp: Date, segment: Int) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.segment = segment
    }

    init(location: CLLocation, altitude: Double? = nil, segment: Int) {
        self.init(latitude: location.coordinate.latitude,
                  longitude: location.coordinate.longitude,
                  altitude: altitude ?? location.altitude,
                  timestamp: location.timestamp,
                  segment: segment)
    }
}

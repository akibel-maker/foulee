import Foundation
import CoreLocation

/// Altitudes via l'API gratuite Open-Meteo (pas de clé nécessaire).
enum ElevationService {
    private struct Response: Decodable { let elevation: [Double] }

    static func elevations(for coordinates: [CLLocationCoordinate2D]) async throws -> [Double] {
        var result: [Double] = []
        for start in stride(from: 0, to: coordinates.count, by: 100) {
            let chunk = coordinates[start..<min(start + 100, coordinates.count)]
            var components = URLComponents(string: "https://api.open-meteo.com/v1/elevation")!
            components.queryItems = [
                URLQueryItem(name: "latitude", value: chunk.map { String(format: "%.5f", $0.latitude) }.joined(separator: ",")),
                URLQueryItem(name: "longitude", value: chunk.map { String(format: "%.5f", $0.longitude) }.joined(separator: ",")),
            ]
            guard let url = components.url else { throw URLError(.badURL) }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            result += try JSONDecoder().decode(Response.self, from: data).elevation
        }
        return result
    }
}

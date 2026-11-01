import Foundation

/// Course enregistrée sur l'Apple Watch, envoyée à l'iPhone via WatchConnectivity.
struct WatchRunPayload: Codable, Identifiable {
    var id: UUID
    /// Identifiant de l'entraînement enregistré dans Santé (évite les doublons à l'import).
    var healthKitID: UUID?
    var startDate: Date
    var endDate: Date
    /// Temps en mouvement (pauses exclues), en secondes.
    var duration: TimeInterval
    /// Distance en mètres.
    var distance: Double
    var calories: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var elevationGain: Double
    var isOutdoor: Bool
    var points: [RoutePoint]

    /// Allure moyenne en secondes par kilomètre.
    var averagePace: Double { distance > 0 ? duration / (distance / 1000) : 0 }

    static let fileType = "foulee.run"

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decode(_ data: Data) throws -> WatchRunPayload {
        try JSONDecoder().decode(WatchRunPayload.self, from: data)
    }
}

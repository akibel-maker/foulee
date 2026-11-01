import Foundation
import SwiftData
import WatchConnectivity

/// Reçoit les courses enregistrées sur l'Apple Watch et les ajoute à l'historique.
@MainActor
final class WatchSyncService: NSObject {
    static let shared = WatchSyncService()

    private var container: ModelContainer?

    func start(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil { session.delegate = self }
        if session.activationState != .activated { session.activate() }
    }

    fileprivate func save(_ data: Data) {
        guard let container, let payload = try? WatchRunPayload.decode(data) else { return }
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Run>())) ?? []
        let alreadyKnown = existing.contains { run in
            run.id == payload.id || (payload.healthKitID != nil && run.healthKitID == payload.healthKitID)
        }
        guard !alreadyKnown else { return }

        let run = Run(name: Run.defaultName(for: payload.startDate),
                      startDate: payload.startDate,
                      endDate: payload.endDate,
                      duration: payload.duration,
                      distance: payload.distance)
        run.id = payload.id
        run.source = "watch"
        run.healthKitID = payload.healthKitID
        run.calories = payload.calories
        run.averageHeartRate = payload.averageHeartRate
        run.elevationGain = payload.elevationGain
        if payload.points.count > 1 {
            run.setPoints(payload.points)
            run.updateDerivedMetrics(recomputeDistance: false)
        }
        context.insert(run)
        try? context.save()
    }
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["type"] as? String == WatchRunPayload.fileType,
              let data = try? Data(contentsOf: file.fileURL) else { return }
        // Le fichier est supprimé par le système au retour de cette méthode : on lit les données avant.
        Task { @MainActor in WatchSyncService.shared.save(data) }
    }
}

import Foundation
import WatchConnectivity

/// Envoie les courses terminées à l'iPhone. Les transferts de fichiers sont mis en file d'attente
/// par watchOS : ils partent même si l'iPhone est hors de portée au moment de la course.
@MainActor
final class PhoneConnector: NSObject, WCSessionDelegate {
    static let shared = PhoneConnector()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil { session.delegate = self }
        if session.activationState != .activated { session.activate() }
    }

    /// Renvoie `true` si la course a été mise en file d'envoi.
    @discardableResult
    func send(_ payload: WatchRunPayload) -> Bool {
        activate()
        guard WCSession.isSupported() else { return false }
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("run-\(payload.id.uuidString).json")
            try payload.encoded().write(to: url, options: .atomic)
            WCSession.default.transferFile(url, metadata: ["type": WatchRunPayload.fileType])
            return true
        } catch {
            return false
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if error == nil {
            try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        }
    }
}

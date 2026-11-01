import Foundation
import Observation
import UIKit

/// Lecteur guidé d'une routine : préparation, minuteur par mouvement, changement de côté, voix et vibrations.
@MainActor
@Observable
final class StretchPlayer {
    struct Item: Identifiable {
        let id = UUID()
        let move: StretchMove
        let seconds: Int
    }

    enum Phase { case prepare, active, finished }

    let routine: StretchRoutine
    let items: [Item]
    private(set) var phase: Phase = .prepare
    private(set) var index = 0
    private(set) var remaining: Double = 5
    private(set) var isPaused = false
    /// Deuxième côté d'un mouvement bilatéral.
    private(set) var onSecondSide = false
    private(set) var activeSeconds: Double = 0
    let startedAt = Date()

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var deadline: Date?
    @ObservationIgnored private var lastTick = Date()
    @ObservationIgnored private let coach = VoiceCoach()
    @ObservationIgnored private var countdownSpoken = Set<Int>()

    static let prepareSeconds: Double = 5

    init(routine: StretchRoutine, steps: [(move: StretchMove, seconds: Int)], voice: Bool) {
        self.routine = routine
        self.items = steps.map { Item(move: $0.move, seconds: $0.seconds) }
        coach.enabled = voice
    }

    var current: Item? { items.indices.contains(index) ? items[index] : nil }
    var next: Item? { items.indices.contains(index + 1) ? items[index + 1] : nil }

    var currentDuration: Double {
        phase == .prepare ? Self.prepareSeconds : Double(current?.seconds ?? 1)
    }

    /// Avancement global (0…1).
    var overallProgress: Double {
        let total = Double(items.reduce(0) { $0 + $1.seconds })
        guard total > 0 else { return 0 }
        let done = Double(items.prefix(index).reduce(0) { $0 + $1.seconds })
        let inStep = phase == .active ? (currentDuration - remaining) : 0
        return min(1, (done + inStep) / total)
    }

    // MARK: - Contrôles

    func start() {
        guard let first = current else { return }
        phase = .prepare
        remaining = Self.prepareSeconds
        deadline = Date().addingTimeInterval(remaining)
        lastTick = Date()
        coach.say("Prépare-toi. Premier mouvement : \(first.move.name).")
        UIApplication.shared.isIdleTimerDisabled = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func togglePause() {
        guard phase != .finished else { return }
        if isPaused {
            deadline = Date().addingTimeInterval(remaining)
            lastTick = Date()
            isPaused = false
        } else {
            isPaused = true
            deadline = nil
        }
    }

    func skip() {
        guard phase != .finished else { return }
        if phase == .prepare { beginStep(0) } else { advance() }
    }

    func previous() {
        guard phase == .active else { return }
        let elapsed = currentDuration - remaining
        beginStep(elapsed > 3 || index == 0 ? index : index - 1)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Déroulement

    private func tick() {
        let now = Date()
        if phase == .active && !isPaused { activeSeconds += now.timeIntervalSince(lastTick) }
        lastTick = now
        guard !isPaused, let deadline, phase != .finished else { return }
        remaining = max(0, deadline.timeIntervalSince(now))

        if phase == .active, let item = current {
            if item.move.bilateral && !onSecondSide && remaining <= Double(item.seconds) / 2 {
                onSecondSide = true
                coach.say("Change de côté.")
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
            let whole = Int(remaining.rounded(.up))
            if whole <= 3, whole > 0, item.seconds >= 15, !countdownSpoken.contains(whole) {
                countdownSpoken.insert(whole)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        if remaining <= 0 {
            phase == .prepare ? beginStep(0) : advance()
        }
    }

    private func beginStep(_ newIndex: Int) {
        guard items.indices.contains(newIndex) else { finish(); return }
        index = newIndex
        phase = .active
        onSecondSide = false
        countdownSpoken = []
        remaining = Double(items[newIndex].seconds)
        if !isPaused { deadline = Date().addingTimeInterval(remaining) }
        let item = items[newIndex]
        coach.say(item.move.bilateral ? "\(item.move.name). Premier côté." : item.move.name)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func advance() {
        if index + 1 < items.count {
            beginStep(index + 1)
        } else {
            finish()
        }
    }

    private func finish() {
        phase = .finished
        remaining = 0
        deadline = nil
        coach.say("Routine terminée. Bravo !")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        stop()
    }
}

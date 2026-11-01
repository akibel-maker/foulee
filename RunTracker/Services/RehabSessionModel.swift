import Foundation
import Observation
import UIKit

/// Séance guidée : séries, temps de repos, maintien guidé et arrêt en cas de douleur.
@MainActor
@Observable
final class RehabSessionModel {
    enum Stage { case painCheck, exercise, rest, finish }

    let phase: RehabPhase
    let items: [RehabPrescription]
    private(set) var stage: Stage = .painCheck
    private(set) var index = 0
    private(set) var setsDone: [Int]
    private(set) var painStops: Set<Int> = []
    private(set) var restRemaining = 0
    let restDuration: Int
    var painBefore = 2.0
    var painAfter = 2.0
    var notes = ""
    private(set) var startedAt = Date()

    // Maintien guidé
    private(set) var guideActive = false
    private(set) var guideRep = 0
    private(set) var guideHolding = false
    private(set) var guideRemaining = 0

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let coach = VoiceCoach()

    init(phase: RehabPhase, includeOptional: Bool, restSeconds: Int, voice: Bool) {
        self.phase = phase
        self.items = phase.prescriptions.filter { includeOptional || !$0.optional }
        self.setsDone = Array(repeating: 0, count: items.count)
        self.restDuration = restSeconds
        coach.enabled = voice
    }

    var current: RehabPrescription? { items.indices.contains(index) ? items[index] : nil }
    var stoppedForPain: Bool { !painStops.isEmpty }
    var totalSets: Int { items.reduce(0) { $0 + $1.sets } }
    var doneSets: Int { setsDone.reduce(0, +) }
    var progress: Double { totalSets > 0 ? Double(doneSets) / Double(totalSets) : 0 }

    // MARK: - Déroulé

    func begin() {
        startedAt = Date()
        stage = .exercise
        announceCurrent()
    }

    func completeSet() {
        guard let item = current else { return }
        setsDone[index] = min(item.sets, setsDone[index] + 1)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let exerciseDone = setsDone[index] >= item.sets
        if exerciseDone && index == items.count - 1 {
            finish()
        } else {
            startRest()
        }
    }

    func skipRest() {
        timer?.invalidate()
        afterRest()
    }

    func skipExercise() {
        stopGuide()
        moveToNextExercise()
    }

    /// Douleur vive ou irradiation : on arrête l'exercice (et éventuellement la séance).
    func stopForPain(endSession: Bool) {
        stopGuide()
        painStops.insert(index)
        coach.say("Exercice arrêté.")
        if endSession { finish() } else { moveToNextExercise() }
    }

    func finish() {
        stopGuide()
        timer?.invalidate()
        stage = .finish
        coach.say("Séance terminée.")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        guideActive = false
    }

    private func moveToNextExercise() {
        timer?.invalidate()
        if index + 1 < items.count {
            index += 1
            stage = .exercise
            announceCurrent()
        } else {
            finish()
        }
    }

    private func announceCurrent() {
        guard let item = current, let exercise = item.exercise else { return }
        coach.say("\(exercise.name). \(item.sets) série\(item.sets > 1 ? "s" : "") de \(item.reps).")
    }

    private func startRest() {
        stage = .rest
        restRemaining = restDuration
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.restRemaining -= 1
                if self.restRemaining == 3 { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                if self.restRemaining <= 0 {
                    self.timer?.invalidate()
                    self.afterRest()
                }
            }
        }
    }

    private func afterRest() {
        guard let item = current else { finish(); return }
        if setsDone[index] >= item.sets {
            moveToNextExercise()
        } else {
            stage = .exercise
            coach.say("Série \(setsDone[index] + 1).")
        }
    }

    // MARK: - Maintien guidé (rentrer le menton, omoplates…)

    func startGuide() {
        guard let item = current, let hold = item.exercise?.holdSeconds else { return }
        guideActive = true
        guideRep = 1
        startHold(hold)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.guideTick(hold: hold, reps: item.targetReps) }
        }
    }

    func stopGuide() {
        guard guideActive else { return }
        guideActive = false
        timer?.invalidate()
    }

    private func startHold(_ seconds: Int) {
        guideHolding = true
        guideRemaining = seconds
        coach.say("Maintiens.")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func guideTick(hold: Int, reps: Int) {
        guideRemaining -= 1
        guard guideRemaining <= 0 else { return }
        if guideHolding {
            guideHolding = false
            guideRemaining = 3
            coach.say("Relâche.")
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else if guideRep < reps {
            guideRep += 1
            startHold(hold)
        } else {
            stopGuide()
            completeSet()
        }
    }
}

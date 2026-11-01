import Foundation
import SwiftData

// MARK: - Bilan avant de commencer

enum PainTrend: Int, CaseIterable, Identifiable, Codable {
    case muchBetter, slightlyBetter, same, worse
    var id: Self { self }
    var label: String {
        switch self {
        case .muchBetter: "Nettement diminuée"
        case .slightlyBetter: "Un peu diminuée"
        case .same: "Identique"
        case .worse: "Plus forte"
        }
    }
}

enum MobilityChange: Int, CaseIterable, Identifiable, Codable {
    case clearly, slightly, no
    var id: Self { self }
    var label: String {
        switch self {
        case .clearly: "Oui, nettement"
        case .slightly: "Un peu"
        case .no: "Non"
        }
    }
}

enum OsteoTreatment: Int, CaseIterable, Identifiable, Codable {
    case manipulation, softOnly, unknown
    var id: Self { self }
    var label: String {
        switch self {
        case .manipulation: "Il a fait craquer / manipulé mon cou"
        case .softOnly: "Uniquement massages, exercices, électrostimulation"
        case .unknown: "Je ne sais pas"
        }
    }
}

enum ScreeningResult: String, Codable {
    /// Signe d'alerte : prise en charge médicale urgente.
    case urgent
    /// Examen médical à privilégier avant de commencer.
    case medical
    /// Ça va mieux mais pas encore assez : patienter.
    case wait
    /// La phase 1 peut commencer, avec l'accord d'un professionnel.
    case ready

    var title: String {
        switch self {
        case .urgent: "Prise en charge médicale urgente"
        case .medical: "Examen médical d'abord"
        case .wait: "Encore un peu de patience"
        case .ready: "Tu peux envisager la phase 1"
        }
    }

    var message: String {
        switch self {
        case .urgent:
            return RehabContent.urgentSigns
        case .medical:
            return "Ta douleur ne s'est pas nettement calmée, reste forte, s'aggrave ou te réveille la nuit, ou les mouvements du cou ne sont pas plus faciles. Fais-toi examiner rapidement par un médecin avant de commencer. En attendant : pas de manipulation cervicale forcée, d'étirement intense ni de musculation du cou."
        case .wait:
            return "La douleur diminue mais n'est pas encore nettement calmée. Le programme est prévu pour reprendre une fois la douleur aiguë nettement calmée et les mouvements du cou plus faciles. Refais le point dans quelques jours, ou demande l'avis d'un professionnel de santé."
        case .ready:
            return "La douleur aiguë s'est nettement calmée et les mouvements du cou sont plus faciles. Tu peux commencer la phase 1 une fois qu'un professionnel de santé a confirmé que des exercices doux sont appropriés."
        }
    }

    var symbol: String {
        switch self {
        case .urgent: "cross.case.fill"
        case .medical: "stethoscope"
        case .wait: "hourglass"
        case .ready: "checkmark.seal.fill"
        }
    }
}

@Model
final class RehabScreening {
    var id: UUID = UUID()
    var date: Date = Date()
    var painTrendRaw: Int = PainTrend.same.rawValue
    var mobilityRaw: Int = MobilityChange.no.rawValue
    var treatmentRaw: Int = OsteoTreatment.unknown.rawValue
    var stillStrong: Bool = false
    var worsening: Bool = false
    var nightPain: Bool = false
    var urgentSigns: Bool = false
    var resultRaw: String = ScreeningResult.medical.rawValue

    init() {}

    var painTrend: PainTrend {
        get { PainTrend(rawValue: painTrendRaw) ?? .same }
        set { painTrendRaw = newValue.rawValue }
    }
    var mobility: MobilityChange {
        get { MobilityChange(rawValue: mobilityRaw) ?? .no }
        set { mobilityRaw = newValue.rawValue }
    }
    var treatment: OsteoTreatment {
        get { OsteoTreatment(rawValue: treatmentRaw) ?? .unknown }
        set { treatmentRaw = newValue.rawValue }
    }
    var result: ScreeningResult { ScreeningResult(rawValue: resultRaw) ?? .medical }

    /// Règles tirées du programme.
    static func evaluate(painTrend: PainTrend, mobility: MobilityChange, stillStrong: Bool, worsening: Bool,
                         nightPain: Bool, urgentSigns: Bool) -> ScreeningResult {
        if urgentSigns { return .urgent }
        if stillStrong || worsening || nightPain || painTrend == .same || painTrend == .worse || mobility == .no {
            return .medical
        }
        if painTrend == .muchBetter { return .ready }
        return .wait
    }
}

// MARK: - Séances

struct RehabExerciseLog: Codable, Hashable, Identifiable {
    var exerciseID: String
    var setsPlanned: Int
    var setsDone: Int
    var stoppedForPain = false
    var id: String { exerciseID }
}

@Model
final class RehabSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var phase: Int = 1
    var duration: TimeInterval = 0
    var painBefore: Int = 0
    var painAfter: Int = 0
    var stoppedForPain: Bool = false
    var notes: String = ""
    var logsData: Data?

    init(date: Date, phase: Int) {
        self.date = date
        self.phase = phase
    }

    var logs: [RehabExerciseLog] {
        get {
            guard let logsData else { return [] }
            return (try? JSONDecoder().decode([RehabExerciseLog].self, from: logsData)) ?? []
        }
        set { logsData = try? JSONEncoder().encode(newValue) }
    }

    var completion: Double {
        let planned = logs.reduce(0) { $0 + $1.setsPlanned }
        return planned > 0 ? Double(logs.reduce(0) { $0 + $1.setsDone }) / Double(planned) : 0
    }
}

// MARK: - Bilan hebdomadaire

@Model
final class RehabCheckIn {
    var id: UUID = UUID()
    var date: Date = Date()
    /// Rotation de la tête : 1 (très difficile, asymétrique) … 5 (facile et symétrique).
    var rotation: Int = 3
    /// Douleur au réveil, 0 à 10.
    var wakePain: Int = 0
    /// Douleur vers l'omoplate : 0 jamais, 1 parfois, 2 souvent, 3 tout le temps.
    var scapulaPain: Int = 0
    /// Travail sur écran : 1 (mal toléré) … 5 (bien toléré).
    var screenTolerance: Int = 3
    var exercisesControlled: Bool = true
    var worsening: Bool = false
    var urgentSigns: Bool = false
    var notes: String = ""

    init() {}

    static let scapulaLabels = ["Jamais", "Parfois", "Souvent", "Tout le temps"]
}

/// État du programme (stocké dans les préférences).
enum RehabProgram {
    static let totalWeeks = 8

    static func week(since start: Date, now: Date = .now) -> Int {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start),
                                                   to: Calendar.current.startOfDay(for: now)).day ?? 0
        return max(1, days / 7 + 1)
    }

    /// Évolution d'un bilan à l'autre : nombre d'indicateurs améliorés / dégradés.
    static func trend(from previous: RehabCheckIn, to current: RehabCheckIn) -> (better: Int, worse: Int) {
        var better = 0
        var worse = 0
        func compare(_ old: Int, _ new: Int, higherIsBetter: Bool) {
            if new == old { return }
            if (new > old) == higherIsBetter { better += 1 } else { worse += 1 }
        }
        compare(previous.rotation, current.rotation, higherIsBetter: true)
        compare(previous.wakePain, current.wakePain, higherIsBetter: false)
        compare(previous.scapulaPain, current.scapulaPain, higherIsBetter: false)
        compare(previous.screenTolerance, current.screenTolerance, higherIsBetter: true)
        return (better, worse)
    }
}

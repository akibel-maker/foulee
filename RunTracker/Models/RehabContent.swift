import Foundation
import SwiftUI

// Programme de renforcement du dos et du cou — 8 semaines (contenu fourni par l'utilisateur).

enum RehabEquipment: String, Hashable {
    case none, wall, chair, band, dumbbell

    var label: String {
        switch self {
        case .none: "Sans matériel"
        case .wall: "Un mur"
        case .chair: "Une chaise"
        case .band: "Un élastique"
        case .dumbbell: "Un haltère léger"
        }
    }

    var symbol: String {
        switch self {
        case .none: "hand.raised"
        case .wall: "rectangle.portrait"
        case .chair: "chair"
        case .band: "line.diagonal"
        case .dumbbell: "dumbbell"
        }
    }
}

struct RehabExercise: Identifiable, Hashable {
    let id: String
    let name: String
    let steps: [String]
    let symbol: String
    var equipment: RehabEquipment = .none
    /// Temps de maintien par répétition (guidage), en secondes.
    var holdSeconds: Int? = nil
    var warning: String? = nil
}

struct RehabPrescription: Identifiable, Hashable {
    let exerciseID: String
    let sets: Int
    /// Texte affiché, ex. « 8–12 », « 6 par côté ».
    let reps: String
    /// Répétitions visées (pour le guidage).
    let targetReps: Int
    var note: String? = nil
    var optional = false

    var id: String { exerciseID + (optional ? "-opt" : "") }
    var exercise: RehabExercise? { RehabContent.exercise(exerciseID) }
}

struct RehabPhase: Identifiable, Hashable {
    let number: Int
    let weeks: ClosedRange<Int>
    let title: String
    let objective: String
    /// Condition pour entrer dans la phase.
    let entryCondition: String
    /// Points à confirmer avant de passer à cette phase.
    let entryChecks: [String]
    let prescriptions: [RehabPrescription]
    let frequency: String
    let minSessionsPerWeek: Int
    let maxSessionsPerWeek: Int
    let notes: [String]

    var id: Int { number }
    var weeksLabel: String { "Semaines \(weeks.lowerBound) et \(weeks.upperBound)" }
}

enum RehabContent {
    // MARK: - Messages de sécurité

    static let introduction = "Programme de 8 semaines pour renforcer progressivement le cou, le haut du dos et les épaules, avec l'objectif de réduire les récidives."

    static let priority = "Si la douleur est toujours forte, s'aggrave ou te réveille la nuit, fais-toi examiner rapidement par un médecin avant de commencer ce programme. Une séance d'ostéopathie ne suffit pas à écarter toutes les causes possibles. En attendant : pas de manipulation cervicale forcée, d'étirement intense ni de musculation du cou."

    static let startCondition = "Le programme est prévu pour reprendre progressivement une fois la douleur aiguë nettement calmée et les mouvements du cou redevenus plus faciles."

    static let safetyRule = "Une légère fatigue musculaire est acceptable. Une douleur vive, une douleur qui descend davantage vers l'omoplate ou le bras, ou une aggravation qui persiste après la séance signifie qu'il faut arrêter l'exercice et réévaluer le programme."

    static let urgentSigns = "Si tu développes une faiblesse, des engourdissements importants, de la fièvre ou un mal de tête intense, demande une prise en charge médicale urgente."

    static let neckResistance = "Pour le cou : ne commence pas les exercices de résistance manuelle du cou sans avis d'un kinésithérapeute. Les muscles cervicaux sont déjà sollicités par les mouvements contrôlés du menton et le maintien d'une bonne posture."

    static let organisation: [(label: String, value: String)] = [
        ("Durée", "8 semaines"),
        ("Fréquence", "2 séances par semaine au début, puis 3 si tout va bien"),
        ("Séance", "15 à 30 minutes"),
        ("Matériel", "Un mur, une chaise, puis idéalement un élastique de musculation"),
        ("Objectif", "Stabilité cervicale, muscles entre les omoplates, haut du dos"),
    ]

    // MARK: - Exercices

    static let exercises: [RehabExercise] = [
        RehabExercise(id: "chinTuck", name: "Rentrer le menton",
                      steps: ["Assieds-toi, le regard horizontal.",
                              "Recule légèrement le menton, comme pour créer un petit double menton.",
                              "Garde la tête droite : ne baisse pas le regard.",
                              "Maintiens 2 à 3 secondes, puis relâche."],
                      symbol: "person.bust", equipment: .chair, holdSeconds: 3),
        RehabExercise(id: "scapSqueeze", name: "Rapprocher les omoplates",
                      steps: ["Assieds-toi ou tiens-toi debout, épaules relâchées.",
                              "Rapproche doucement les omoplates sans hausser les épaules.",
                              "Maintiens 3 secondes, puis relâche."],
                      symbol: "figure.stand", holdSeconds: 3),
        RehabExercise(id: "shoulderCircles", name: "Cercles d'épaules lents",
                      steps: ["Debout ou assis, bras relâchés le long du corps.",
                              "Fais rouler lentement les épaules en dessinant des cercles, sans hausser excessivement.",
                              "Reste dans une amplitude confortable."],
                      symbol: "figure.cooldown"),
        RehabExercise(id: "wallSlides", name: "Glissés des bras contre un mur",
                      steps: ["Place-toi face au mur, les mains à hauteur des épaules.",
                              "Fais glisser lentement les mains vers le haut, uniquement dans une amplitude confortable.",
                              "Ne cambre pas le dos et ne force pas sur le cou."],
                      symbol: "figure.arms.open", equipment: .wall),
        RehabExercise(id: "chairExtension", name: "Extension douce du haut du dos sur une chaise",
                      steps: ["Assieds-toi au fond d'une chaise, le haut du dossier sous les omoplates.",
                              "Croise les bras sur la poitrine.",
                              "Redresse doucement le haut du dos vers l'arrière, dans une amplitude confortable, puis reviens.",
                              "Garde la tête dans le prolongement du dos : ne la bascule pas en arrière."],
                      symbol: "chair", equipment: .chair),
        RehabExercise(id: "bandRow", name: "Tirage avec élastique",
                      steps: ["Fixe l'élastique à un support stable, à hauteur de poitrine.",
                              "Tire les coudes vers l'arrière en gardant les épaules basses.",
                              "Reviens lentement à la position de départ."],
                      symbol: "figure.rower", equipment: .band),
        RehabExercise(id: "externalRotation", name: "Rotation externe des épaules avec élastique",
                      steps: ["Garde les coudes contre le corps, pliés à 90°.",
                              "Écarte les mains en tirant légèrement sur l'élastique.",
                              "Ne tourne pas le tronc et ne hausse pas les épaules."],
                      symbol: "figure.strengthtraining.traditional", equipment: .band),
        RehabExercise(id: "birdDog", name: "Bird dog",
                      steps: ["Mets-toi à quatre pattes.",
                              "Tends lentement un bras et la jambe opposée.",
                              "Garde le dos stable et le cou dans le prolongement de la colonne.",
                              "Reviens, puis change de côté."],
                      symbol: "figure.core.training"),
        RehabExercise(id: "wallPushup", name: "Pompes contre un mur ou sur un support haut",
                      steps: ["Mains contre un mur (ou sur un support haut et stable), à hauteur et largeur d'épaules.",
                              "Plie les coudes pour rapprocher la poitrine, le corps bien aligné.",
                              "Repousse lentement, le cou dans le prolongement du dos."],
                      symbol: "figure.strengthtraining.functional", equipment: .wall,
                      warning: "Les pompes doivent rester faciles et ne provoquer ni douleur cervicale ni irradiation vers l'omoplate."),
        RehabExercise(id: "dumbbellRow", name: "Tirage avec haltère (optionnel)",
                      steps: ["Une main et un genou en appui sur une chaise ou un banc, dos stable et plat.",
                              "Tire l'haltère vers la hanche en gardant l'épaule basse.",
                              "Redescends lentement. Charge légère."],
                      symbol: "dumbbell", equipment: .dumbbell,
                      warning: "Seulement si tu maîtrises le mouvement et qu'il est indolore."),
    ]

    private static let exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    static func exercise(_ id: String) -> RehabExercise? { exercisesByID[id] }

    // MARK: - Phases

    static let phases: [RehabPhase] = [
        RehabPhase(number: 1, weeks: 1...2, title: "Mobilité et contrôle",
                   objective: "Retrouver le contrôle sans irriter le cou",
                   entryCondition: "À commencer uniquement lorsque la douleur aiguë s'est nettement calmée et qu'un professionnel de santé a confirmé que des exercices doux sont appropriés.",
                   entryChecks: ["La douleur aiguë s'est nettement calmée.",
                                 "Un professionnel de santé a confirmé que des exercices doux sont appropriés."],
                   prescriptions: [
                       RehabPrescription(exerciseID: "chinTuck", sets: 2, reps: "5", targetReps: 5),
                       RehabPrescription(exerciseID: "scapSqueeze", sets: 2, reps: "8", targetReps: 8),
                       RehabPrescription(exerciseID: "shoulderCircles", sets: 1, reps: "10", targetReps: 10),
                       RehabPrescription(exerciseID: "wallSlides", sets: 2, reps: "6", targetReps: 6),
                       RehabPrescription(exerciseID: "chairExtension", sets: 1, reps: "6", targetReps: 6),
                   ],
                   frequency: "2 à 3 fois par semaine, en laissant au moins un jour de repos entre les séances.",
                   minSessionsPerWeek: 2, maxSessionsPerWeek: 3,
                   notes: ["Si un mouvement provoque une douleur vive ou augmente la douleur vers l'omoplate, arrête-le."]),
        RehabPhase(number: 2, weeks: 3...4, title: "Renforcement léger",
                   objective: "Renforcer les muscles stabilisateurs",
                   entryCondition: "Passe à cette phase si les douleurs ont nettement diminué et que tu tournes la tête presque normalement.",
                   entryChecks: ["Les douleurs ont nettement diminué.",
                                 "Je tourne la tête presque normalement."],
                   prescriptions: [
                       RehabPrescription(exerciseID: "chinTuck", sets: 2, reps: "8", targetReps: 8),
                       RehabPrescription(exerciseID: "bandRow", sets: 2, reps: "10", targetReps: 10),
                       RehabPrescription(exerciseID: "externalRotation", sets: 2, reps: "10", targetReps: 10),
                       RehabPrescription(exerciseID: "wallSlides", sets: 2, reps: "8", targetReps: 8),
                       RehabPrescription(exerciseID: "birdDog", sets: 2, reps: "6 par côté", targetReps: 6),
                   ],
                   frequency: "2 séances par semaine au départ, puis 3 si la récupération est bonne.",
                   minSessionsPerWeek: 2, maxSessionsPerWeek: 3,
                   notes: []),
        RehabPhase(number: 3, weeks: 5...6, title: "Renforcement du haut du dos",
                   objective: "Développer la force du haut du dos",
                   entryCondition: "Si les exercices précédents sont bien tolérés, tu peux augmenter progressivement le volume.",
                   entryChecks: ["Les exercices de la phase 2 sont bien tolérés, sans aggravation."],
                   prescriptions: [
                       RehabPrescription(exerciseID: "bandRow", sets: 3, reps: "12", targetReps: 12),
                       RehabPrescription(exerciseID: "externalRotation", sets: 3, reps: "12", targetReps: 12),
                       RehabPrescription(exerciseID: "wallPushup", sets: 2, reps: "8–12", targetReps: 10),
                       RehabPrescription(exerciseID: "birdDog", sets: 2, reps: "8 par côté", targetReps: 8),
                       RehabPrescription(exerciseID: "wallSlides", sets: 2, reps: "10", targetReps: 10),
                   ],
                   frequency: "2 à 3 séances par semaine.",
                   minSessionsPerWeek: 2, maxSessionsPerWeek: 3,
                   notes: ["Fais les mouvements lentement, sans élan.",
                           "Garde le cou dans une position confortable.",
                           "Augmente d'abord le nombre de répétitions, puis la résistance.",
                           "Ne cherche pas à aller à l'échec musculaire."]),
        RehabPhase(number: 4, weeks: 7...8, title: "Consolidation",
                   objective: "Consolider les acquis et préparer l'entretien à long terme",
                   entryCondition: "Si la phase 3 est bien tolérée.",
                   entryChecks: ["Les exercices de la phase 3 sont bien tolérés, sans aggravation."],
                   prescriptions: [
                       RehabPrescription(exerciseID: "bandRow", sets: 3, reps: "10–12", targetReps: 11,
                                         note: "Avec un élastique plus résistant"),
                       RehabPrescription(exerciseID: "externalRotation", sets: 3, reps: "12", targetReps: 12),
                       RehabPrescription(exerciseID: "wallPushup", sets: 3, reps: "8–12", targetReps: 10,
                                         note: "Sur un support adapté"),
                       RehabPrescription(exerciseID: "birdDog", sets: 3, reps: "8 par côté", targetReps: 8),
                       RehabPrescription(exerciseID: "wallSlides", sets: 2, reps: "10", targetReps: 10),
                       RehabPrescription(exerciseID: "dumbbellRow", sets: 2, reps: "10", targetReps: 10,
                                         note: "Charge légère, dos stable", optional: true),
                   ],
                   frequency: "2 à 3 séances par semaine.",
                   minSessionsPerWeek: 2, maxSessionsPerWeek: 3,
                   notes: [neckResistance]),
    ]

    static func phase(_ number: Int) -> RehabPhase { phases[max(0, min(phases.count - 1, number - 1))] }

    // MARK: - Habitudes quotidiennes

    static let workTips = ["Toutes les 30 à 60 minutes, lève-toi ou change de position.",
                           "Place l'écran à une hauteur confortable.",
                           "Évite de garder longtemps la tête penchée vers le téléphone.",
                           "Relâche régulièrement les épaules."]

    static let dailyTips = ["Augmente progressivement les activités physiques.",
                            "Évite de porter un sac toujours du même côté.",
                            "Ne cherche pas à maintenir une posture rigide toute la journée : varie les positions.",
                            "Privilégie un sommeil confortable, avec un oreiller qui maintient la tête dans l'alignement du corps."]

    /// Habitudes proposées à l'ajout dans l'onglet Quotidien.
    static let suggestedHabits: [HabitPreset] = [
        HabitPreset(name: "Pause mouvement (30–60 min)", emoji: "🧍", color: .teal, kind: .count, target: 6, unit: "pauses"),
        HabitPreset(name: "Relâcher les épaules", emoji: "😌", color: .blue),
        HabitPreset(name: "Téléphone à hauteur des yeux", emoji: "📱", color: .yellow),
        HabitPreset(name: "Changer le sac de côté", emoji: "🎒", color: .purple),
    ]
}

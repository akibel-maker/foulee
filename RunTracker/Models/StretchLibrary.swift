import Foundation
import SwiftUI

// Contenu tiré du « Guide pratique des routines d'étirements » (12 routines, mouvements dédoublonnés).

enum StretchZone: String, CaseIterable, Identifiable, Hashable {
    case neck, shoulders, chest, upperBack, lowerBack, hips, hamstrings, quads, arms, fullBody

    var id: Self { self }

    var label: String {
        switch self {
        case .neck: "Cou"
        case .shoulders: "Épaules"
        case .chest: "Poitrine"
        case .upperBack: "Haut du dos"
        case .lowerBack: "Lombaires"
        case .hips: "Hanches"
        case .hamstrings: "Ischio-jambiers"
        case .quads: "Quadriceps"
        case .arms: "Bras et poignets"
        case .fullBody: "Corps entier"
        }
    }

    var symbol: String {
        switch self {
        case .neck: "figure.cooldown"
        case .shoulders: "figure.arms.open"
        case .chest: "figure.stand"
        case .upperBack: "figure.taichi"
        case .lowerBack: "figure.yoga"
        case .hips: "figure.strengthtraining.functional"
        case .hamstrings: "figure.flexibility"
        case .quads: "figure.barre"
        case .arms: "hand.raised"
        case .fullBody: "figure.mind.and.body"
        }
    }

    var tint: HabitColor {
        switch self {
        case .neck: .yellow
        case .shoulders: .teal
        case .chest: .pink
        case .upperBack: .blue
        case .lowerBack: .green
        case .hips: .purple
        case .hamstrings: .red
        case .quads: .orange
        case .arms: .indigo
        case .fullBody: .teal
        }
    }
}

/// Moments de la journée (organisation suggérée par le guide).
enum StretchMoment: String, CaseIterable, Identifiable, Hashable {
    case morning, work, posture, afterRun, evening, mobility, advanced

    var id: Self { self }

    var label: String {
        switch self {
        case .morning: "Matin"
        case .work: "Au bureau"
        case .posture: "Posture"
        case .afterRun: "Après la course"
        case .evening: "Soir et sommeil"
        case .mobility: "Mobilité"
        case .advanced: "Avancé"
        }
    }

    var symbol: String {
        switch self {
        case .morning: "sunrise"
        case .work: "laptopcomputer"
        case .posture: "person.bust"
        case .afterRun: "figure.run"
        case .evening: "moon.stars"
        case .mobility: "arrow.triangle.2.circlepath"
        case .advanced: "flame"
        }
    }
}

/// Position de départ : sert à enchaîner les mouvements de façon fluide (debout → assis → sol → allongé).
enum StretchPosition: Int, Comparable {
    case standing, seated, kneeling, floor, lying

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct StretchMove: Identifiable, Hashable {
    let id: String
    let name: String
    let englishName: String
    let instruction: String
    let zones: [StretchZone]
    let symbol: String
    let position: StretchPosition
    /// Se fait d'un côté puis de l'autre : annonce « change de côté » à mi-temps.
    var bilateral = false
    /// Mouvement de la nuque : à éviter en cas de douleur cervicale.
    var neck = false
    /// Posture avancée, désactivée par défaut.
    var advanced = false
}

struct StretchStep: Hashable, Codable, Identifiable {
    var id = UUID()
    var moveID: String
    var seconds: Int

    init(moveID: String, seconds: Int) {
        self.moveID = moveID
        self.seconds = seconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        moveID = try container.decode(String.self, forKey: .moveID)
        seconds = try container.decode(Int.self, forKey: .seconds)
    }
}

struct StretchRoutine: Identifiable, Hashable {
    let id: String
    let name: String
    var originalName: String? = nil
    let summary: String
    let symbol: String
    let tint: HabitColor
    var moments: [StretchMoment] = []
    let steps: [StretchStep]
    var caution: String? = nil
    var isCustom = false

    var moves: [StretchMove] { steps.compactMap { StretchLibrary.move($0.moveID) } }
    var totalSeconds: Int { steps.reduce(0) { $0 + $1.seconds } }
    var minutes: Int { max(1, Int((Double(totalSeconds) / 60).rounded())) }
    var zones: Set<StretchZone> { Set(moves.flatMap(\.zones)) }
    var hasAdvanced: Bool { moves.contains(where: \.advanced) }

    /// Étapes réellement jouées selon les réglages (postures avancées, précaution cervicale, rythme).
    func playableSteps(includeAdvanced: Bool, neckCaution: Bool, pace: Double) -> [(move: StretchMove, seconds: Int)] {
        steps.compactMap { step in
            guard let move = StretchLibrary.move(step.moveID) else { return nil }
            if move.advanced && (!includeAdvanced || (neckCaution && move.neck)) { return nil }
            if neckCaution && move.neck { return nil }
            return (move, max(10, Int((Double(step.seconds) * pace / 5).rounded()) * 5))
        }
    }
}

enum StretchLibrary {
    static let neckCautionText = "Si tu as un torticolis ou une douleur qui descend vers l'omoplate, évite les mouvements du cou douloureux et les postures inversées (chandelle, charrue). Ne force jamais un étirement. Demande un avis médical si la douleur est importante ou persiste ; une douleur dorsale accompagnée de difficultés respiratoires nécessite une évaluation urgente."

    // MARK: - Mouvements

    static let moves: [StretchMove] = [
        StretchMove(id: "upwardSalute", name: "Salut vers le ciel", englishName: "Upward Salute",
                    instruction: "Debout, lève les bras au-dessus de la tête et grandis-toi, sans cambrer exagérément.",
                    zones: [.shoulders, .fullBody], symbol: "figure.arms.open", position: .standing),
        StretchMove(id: "toeTouch", name: "Toucher les orteils", englishName: "Toe Touch",
                    instruction: "Penche le buste depuis les hanches vers les pieds, genoux souples.",
                    zones: [.hamstrings, .lowerBack], symbol: "figure.flexibility", position: .standing),
        StretchMove(id: "lunge", name: "Fente", englishName: "Lunge",
                    instruction: "Un pied devant, genou arrière au sol si confortable ; avance doucement le bassin.",
                    zones: [.hips, .quads], symbol: "figure.strengthtraining.functional", position: .kneeling, bilateral: true),
        StretchMove(id: "upwardDog", name: "Chien tête en haut", englishName: "Upward Dog",
                    instruction: "Au sol, relève le torse en prenant appui sur les mains et ouvre la poitrine, sans comprimer le bas du dos.",
                    zones: [.lowerBack, .chest], symbol: "figure.yoga", position: .floor),
        StretchMove(id: "childsPose", name: "Posture de l'enfant", englishName: "Child's Pose",
                    instruction: "À genoux, recule les fesses vers les talons et étire les bras devant toi.",
                    zones: [.lowerBack, .shoulders], symbol: "figure.yoga", position: .kneeling),
        StretchMove(id: "downwardDog", name: "Chien tête en bas", englishName: "Downward Dog",
                    instruction: "Mains et pieds au sol, pousse les hanches vers le haut et l'arrière.",
                    zones: [.hamstrings, .shoulders], symbol: "figure.yoga", position: .floor),
        StretchMove(id: "wideLegBend", name: "Flexion jambes écartées", englishName: "Wide Leg Bend",
                    instruction: "Écarte les pieds et penche le buste vers le sol depuis les hanches.",
                    zones: [.hamstrings, .hips], symbol: "figure.flexibility", position: .standing),
        StretchMove(id: "goodMornings", name: "Good mornings", englishName: "Good Mornings",
                    instruction: "Mains derrière la tête, recule les hanches et penche le buste, puis redresse-toi.",
                    zones: [.hamstrings, .lowerBack], symbol: "figure.core.training", position: .standing),
        StretchMove(id: "trunkTwist", name: "Rotation du buste", englishName: "Trunk Twist",
                    instruction: "Bras ouverts, tourne doucement le haut du corps à droite puis à gauche.",
                    zones: [.upperBack, .fullBody], symbol: "figure.taichi", position: .standing),
        StretchMove(id: "neckMobility", name: "Mobilité du cou", englishName: "Neck Roll",
                    instruction: "Mobilise doucement la tête de côté en côté par petites inclinaisons contrôlées ; évite les grands cercles.",
                    zones: [.neck], symbol: "figure.cooldown", position: .standing, neck: true),
        StretchMove(id: "shoulderRolls", name: "Rotations des épaules", englishName: "Shoulder Rolls",
                    instruction: "Roule les épaules lentement vers l'arrière puis vers l'avant, sans hausser excessivement.",
                    zones: [.shoulders], symbol: "figure.cooldown", position: .standing),
        StretchMove(id: "overheadReach", name: "Étirement vers le haut", englishName: "Overhead Reach",
                    instruction: "Assis ou debout, tends les bras vers le plafond en allongeant le dos.",
                    zones: [.upperBack, .shoulders], symbol: "figure.arms.open", position: .standing),
        StretchMove(id: "sideBend", name: "Inclinaison latérale", englishName: "Side Bend",
                    instruction: "Lève un bras et incline doucement le buste du côté opposé ; change de côté.",
                    zones: [.upperBack], symbol: "figure.barre", position: .standing, bilateral: true),
        StretchMove(id: "cactusArms", name: "Bras en cactus", englishName: "Cactus Arms",
                    instruction: "Coudes pliés à 90° et bras ouverts, ouvre la poitrine et rapproche doucement les omoplates.",
                    zones: [.chest, .upperBack], symbol: "figure.arms.open", position: .standing),
        StretchMove(id: "neckFlex", name: "Flexion du cou", englishName: "Neck Flex",
                    instruction: "Abaisse doucement le menton vers la poitrine, sans tirer sur la tête.",
                    zones: [.neck], symbol: "figure.cooldown", position: .standing, neck: true),
        StretchMove(id: "neckLaterals", name: "Inclinaisons du cou", englishName: "Neck Laterals",
                    instruction: "Incline une oreille vers l'épaule correspondante en gardant l'épaule basse.",
                    zones: [.neck], symbol: "figure.cooldown", position: .standing, bilateral: true, neck: true),
        StretchMove(id: "diver", name: "Plongeur", englishName: "Diver",
                    instruction: "Penche le buste vers l'avant et dirige les bras vers l'arrière.",
                    zones: [.shoulders, .upperBack], symbol: "figure.flexibility", position: .standing),
        StretchMove(id: "chinRetractions", name: "Rétractions du menton", englishName: "Chin Retractions",
                    instruction: "Regard horizontal, rentre le menton vers l'arrière comme pour créer un double menton, sans douleur.",
                    zones: [.neck], symbol: "figure.stand", position: .standing, neck: true),
        StretchMove(id: "wallPecs", name: "Pectoraux au mur", englishName: "Wall Pecs",
                    instruction: "Avant-bras contre un mur, avance doucement le corps pour ouvrir la poitrine.",
                    zones: [.chest, .shoulders], symbol: "figure.stand", position: .standing, bilateral: true),
        StretchMove(id: "wallDog", name: "Chien au mur", englishName: "Wall Dog",
                    instruction: "Mains au mur, recule les pieds et abaisse le buste entre les bras.",
                    zones: [.shoulders, .upperBack], symbol: "figure.flexibility", position: .standing),
        StretchMove(id: "doorwayPecs", name: "Pectoraux dans l'encadrement", englishName: "Doorway Pecs",
                    instruction: "Avant-bras sur les montants d'une porte, avance doucement pour étirer les pectoraux.",
                    zones: [.chest], symbol: "figure.stand", position: .standing),
        StretchMove(id: "oneArmHug", name: "Bras croisé", englishName: "One Arm Hug",
                    instruction: "Ramène un bras devant la poitrine et accompagne-le doucement avec l'autre.",
                    zones: [.shoulders, .arms], symbol: "figure.cooldown", position: .standing, bilateral: true),
        StretchMove(id: "reverseShoulder", name: "Épaules inversées", englishName: "Reverse Shoulder",
                    instruction: "Mains jointes derrière le dos, tends les bras et soulève-les légèrement si c'est confortable.",
                    zones: [.shoulders, .chest], symbol: "figure.stand", position: .standing),
        StretchMove(id: "seatedFigureFour", name: "Figure 4 assise", englishName: "Seated Figure Four",
                    instruction: "Assis, pose une cheville sur la cuisse opposée et penche légèrement le buste en avant.",
                    zones: [.hips], symbol: "figure.mind.and.body", position: .seated, bilateral: true),
        StretchMove(id: "seatedHamstring", name: "Ischios assis", englishName: "Seated Hamstring",
                    instruction: "Tends une jambe, talon au sol et orteils vers le haut ; penche-toi depuis les hanches.",
                    zones: [.hamstrings], symbol: "figure.mind.and.body", position: .seated, bilateral: true),
        StretchMove(id: "trunkRotation", name: "Rotation assise", englishName: "Trunk Rotation",
                    instruction: "Assis, tourne doucement le haut du corps de chaque côté.",
                    zones: [.upperBack], symbol: "figure.mind.and.body", position: .seated),
        StretchMove(id: "chestOpener", name: "Ouverture de la poitrine", englishName: "Chest Opener",
                    instruction: "Mains derrière la tête, ouvre les coudes et rapproche légèrement les omoplates.",
                    zones: [.chest], symbol: "figure.arms.open", position: .standing),
        StretchMove(id: "overheadTricep", name: "Triceps derrière la tête", englishName: "Overhead Tricep",
                    instruction: "Plie un bras derrière la tête et accompagne doucement le coude avec l'autre main.",
                    zones: [.arms, .shoulders], symbol: "figure.arms.open", position: .standing, bilateral: true),
        StretchMove(id: "forearmStretch", name: "Avant-bras", englishName: "Forearm Stretch",
                    instruction: "Tends un bras et ramène doucement les doigts vers toi, puis vers le bas.",
                    zones: [.arms], symbol: "hand.raised", position: .standing, bilateral: true),
        StretchMove(id: "neckExtension", name: "Extension du cou", englishName: "Neck Extension",
                    instruction: "Relève légèrement le menton seulement si cela reste confortable ; ne comprime pas la nuque.",
                    zones: [.neck], symbol: "figure.cooldown", position: .standing, neck: true),
        StretchMove(id: "earToShoulder", name: "Oreille vers l'épaule", englishName: "Ear-to-Shoulder",
                    instruction: "Incline la tête d'un côté sans lever l'épaule.",
                    zones: [.neck], symbol: "figure.cooldown", position: .standing, bilateral: true, neck: true),
        StretchMove(id: "scaleneStretch", name: "Scalènes", englishName: "Scalene Stretch",
                    instruction: "Incline légèrement la tête sur le côté ; ne tire pas sur la tête.",
                    zones: [.neck], symbol: "figure.cooldown", position: .standing, bilateral: true, neck: true),
        StretchMove(id: "scapulaStretch", name: "Entre cou et omoplate", englishName: "Scapula Stretch",
                    instruction: "Abaisse doucement la tête et relâche la région entre le cou et l'omoplate.",
                    zones: [.neck, .upperBack], symbol: "figure.cooldown", position: .standing, bilateral: true, neck: true),
        StretchMove(id: "neckRotation", name: "Rotation du cou", englishName: "Neck Rotation",
                    instruction: "Tourne lentement la tête à droite puis à gauche, sans aller dans la douleur.",
                    zones: [.neck], symbol: "figure.cooldown", position: .standing, neck: true),
        StretchMove(id: "ragDoll", name: "Poupée de chiffon", englishName: "Rag Doll",
                    instruction: "Debout, genoux souples, penche le buste et laisse les bras et la tête relâchés.",
                    zones: [.hamstrings, .lowerBack], symbol: "figure.flexibility", position: .standing),
        StretchMove(id: "kneesToChest", name: "Genoux à la poitrine", englishName: "Knees-to-chest",
                    instruction: "Sur le dos, ramène les genoux vers la poitrine.",
                    zones: [.lowerBack], symbol: "figure.pilates", position: .lying),
        StretchMove(id: "happyBaby", name: "Bébé heureux", englishName: "Happy Baby",
                    instruction: "Sur le dos, ramène les genoux vers les aisselles ; attrape les pieds si possible.",
                    zones: [.hips, .lowerBack], symbol: "figure.pilates", position: .lying),
        StretchMove(id: "reclinedButterfly", name: "Papillon allongé", englishName: "Reclined Butterfly",
                    instruction: "Allongé, rapproche les plantes de pieds et laisse les genoux s'ouvrir.",
                    zones: [.hips], symbol: "figure.pilates", position: .lying),
        StretchMove(id: "spinalTwist", name: "Torsion allongée", englishName: "Spinal Twist",
                    instruction: "Sur le dos, laisse les genoux basculer doucement d'un côté puis de l'autre.",
                    zones: [.lowerBack, .upperBack], symbol: "figure.pilates", position: .lying, bilateral: true),
        StretchMove(id: "quadStretch", name: "Quadriceps", englishName: "Quad Stretch",
                    instruction: "Plie un genou et rapproche doucement le talon de la fesse.",
                    zones: [.quads], symbol: "figure.barre", position: .standing, bilateral: true),
        StretchMove(id: "legsUpWall", name: "Jambes au mur", englishName: "Legs-up-wall",
                    instruction: "Allongé près d'un mur, place les jambes verticalement contre celui-ci.",
                    zones: [.hamstrings, .fullBody], symbol: "figure.pilates", position: .lying),
        StretchMove(id: "catCow", name: "Chat-vache", englishName: "Cat Cow",
                    instruction: "À quatre pattes, creuse doucement le dos à l'inspiration puis arrondis-le à l'expiration.",
                    zones: [.upperBack, .lowerBack], symbol: "figure.yoga", position: .floor),
        StretchMove(id: "seatedTwist", name: "Torsion assise", englishName: "Seated Twist",
                    instruction: "Assis, grandis-toi puis tourne doucement le buste de chaque côté.",
                    zones: [.upperBack], symbol: "figure.mind.and.body", position: .seated, bilateral: true),
        StretchMove(id: "locust", name: "Sauterelle", englishName: "Locust Pose",
                    instruction: "Sur le ventre, soulève légèrement le torse et/ou les jambes sans forcer.",
                    zones: [.lowerBack, .upperBack], symbol: "figure.pilates", position: .lying),
        StretchMove(id: "shoulderStand", name: "Chandelle", englishName: "Shoulder Stand",
                    instruction: "Posture inversée avancée qui charge le cou : à omettre sans encadrement adapté.",
                    zones: [.neck, .fullBody], symbol: "figure.pilates", position: .lying, neck: true, advanced: true),
        StretchMove(id: "plow", name: "Charrue", englishName: "Plow",
                    instruction: "Jambes au-dessus de la tête : posture avancée, à omettre en cas de douleur cervicale ou sans maîtrise.",
                    zones: [.neck, .hamstrings], symbol: "figure.pilates", position: .lying, neck: true, advanced: true),
        StretchMove(id: "crossLegFold", name: "Flexion jambes croisées", englishName: "Cross Leg Fold",
                    instruction: "Croise un pied devant l'autre et penche doucement le buste.",
                    zones: [.hamstrings], symbol: "figure.flexibility", position: .standing, bilateral: true),
        StretchMove(id: "sideLunge", name: "Fente latérale", englishName: "Side Lunge",
                    instruction: "Plie un genou en gardant l'autre jambe tendue.",
                    zones: [.hips, .hamstrings], symbol: "figure.strengthtraining.functional", position: .standing, bilateral: true),
        StretchMove(id: "reverseLunge", name: "Fente inversée", englishName: "Reverse Lunge",
                    instruction: "Depuis une position à genoux, tends une jambe devant toi, talon au sol, et penche légèrement le buste.",
                    zones: [.hamstrings], symbol: "figure.strengthtraining.functional", position: .kneeling, bilateral: true),
        StretchMove(id: "seatedFold", name: "Flexion assise", englishName: "Seated Fold",
                    instruction: "Assis, jambes tendues, penche-toi depuis les hanches.",
                    zones: [.hamstrings, .lowerBack], symbol: "figure.mind.and.body", position: .seated),
        StretchMove(id: "hurdler", name: "Haies", englishName: "Hurdler",
                    instruction: "Assis, replie une jambe et penche-toi vers la jambe tendue.",
                    zones: [.hamstrings], symbol: "figure.mind.and.body", position: .seated, bilateral: true),
        StretchMove(id: "butterfly", name: "Papillon", englishName: "Butterfly",
                    instruction: "Assis, rapproche les plantes de pieds et laisse les genoux s'ouvrir.",
                    zones: [.hips], symbol: "figure.mind.and.body", position: .seated),
        StretchMove(id: "lyingFigureFour", name: "Figure 4 allongée", englishName: "Lying Figure Four",
                    instruction: "Allongé, pose une cheville sur le genou opposé et rapproche la cuisse vers toi.",
                    zones: [.hips], symbol: "figure.pilates", position: .lying, bilateral: true),
        StretchMove(id: "wallArms", name: "Bras au mur", englishName: "Wall Arms",
                    instruction: "Paume contre un mur, tourne doucement le buste dans le sens opposé.",
                    zones: [.chest, .arms], symbol: "figure.stand", position: .standing, bilateral: true),
        StretchMove(id: "forwardFold", name: "Flexion mains jointes", englishName: "Forward Fold",
                    instruction: "Mains jointes derrière le dos, penche-toi en avant sans forcer et laisse les bras s'étirer.",
                    zones: [.hamstrings, .shoulders], symbol: "figure.flexibility", position: .standing),
        StretchMove(id: "squatStretch", name: "Squat profond", englishName: "Squat Stretch",
                    instruction: "Descends en squat dans une amplitude confortable.",
                    zones: [.hips], symbol: "figure.core.training", position: .standing),
        StretchMove(id: "kneelingQuad", name: "Quadriceps à genoux", englishName: "Kneeling Quad",
                    instruction: "À genoux, étire doucement l'avant de la cuisse.",
                    zones: [.quads], symbol: "figure.strengthtraining.functional", position: .kneeling, bilateral: true),
        StretchMove(id: "thunderbolt", name: "Posture du diamant", englishName: "Thunderbolt",
                    instruction: "Assieds-toi sur les talons uniquement si les genoux le tolèrent.",
                    zones: [.quads], symbol: "figure.mind.and.body", position: .kneeling),
        StretchMove(id: "saddle", name: "Posture de la selle", englishName: "Saddle Pose",
                    instruction: "À genoux, incline doucement le corps vers l'arrière ; posture avancée.",
                    zones: [.quads], symbol: "figure.yoga", position: .kneeling, advanced: true),
        StretchMove(id: "toeSquat", name: "Squat sur les orteils", englishName: "Toe Squat",
                    instruction: "À genoux, replie les orteils et assieds-toi doucement vers les talons.",
                    zones: [.quads], symbol: "figure.mind.and.body", position: .kneeling),
        StretchMove(id: "wristExtension", name: "Extension du poignet", englishName: "Wrist Extension",
                    instruction: "Tends un bras et étire doucement le poignet.",
                    zones: [.arms], symbol: "hand.raised", position: .kneeling, bilateral: true),
        StretchMove(id: "lizard", name: "Lézard", englishName: "Lizard Pose",
                    instruction: "Depuis une fente, place le pied avant à l'extérieur de la main.",
                    zones: [.hips], symbol: "figure.strengthtraining.functional", position: .floor, bilateral: true),
        StretchMove(id: "pigeon", name: "Pigeon", englishName: "Pigeon",
                    instruction: "Une jambe pliée devant, l'autre étendue derrière ; reste dans une amplitude confortable.",
                    zones: [.hips], symbol: "figure.yoga", position: .floor, bilateral: true),
        StretchMove(id: "frog", name: "Grenouille", englishName: "Frog Pose",
                    instruction: "À quatre pattes, écarte progressivement les genoux sans forcer.",
                    zones: [.hips], symbol: "figure.yoga", position: .floor),
        StretchMove(id: "puppy", name: "Chiot", englishName: "Puppy Pose",
                    instruction: "À quatre pattes, avance les mains et abaisse la poitrine.",
                    zones: [.shoulders, .upperBack], symbol: "figure.yoga", position: .floor),
        StretchMove(id: "twistedSphinx", name: "Sphinx en torsion", englishName: "Twisted Sphinx",
                    instruction: "Sur le ventre, relève le torse sur les avant-bras et ajoute une rotation douce.",
                    zones: [.lowerBack], symbol: "figure.pilates", position: .lying, bilateral: true),
        StretchMove(id: "lyingHamstring", name: "Ischios allongé", englishName: "Lying Hamstring",
                    instruction: "Sur le dos, lève une jambe et rapproche-la doucement du torse.",
                    zones: [.hamstrings], symbol: "figure.pilates", position: .lying, bilateral: true),
    ]

    private static let movesByID: [String: StretchMove] = Dictionary(uniqueKeysWithValues: moves.map { ($0.id, $0) })

    static func move(_ id: String) -> StretchMove? { movesByID[id] }

    // MARK: - Routines du guide

    /// Répartit la durée annoncée dans le guide entre les mouvements (arrondi à 5 s).
    private static func steps(_ ids: [String], minutes: Double) -> [StretchStep] {
        let perMove = max(20, Int((minutes * 60 / Double(ids.count) / 5).rounded()) * 5)
        return ids.map { StretchStep(moveID: $0, seconds: perMove) }
    }

    static let routines: [StretchRoutine] = [
        StretchRoutine(id: "wakeUp", name: "Réveil", originalName: "Wake Up",
                       summary: "Réveil et mobilité générale", symbol: "sunrise.fill", tint: .orange,
                       moments: [.morning],
                       steps: steps(["upwardSalute", "toeTouch", "lunge", "upwardDog", "childsPose", "downwardDog",
                                     "wideLegBend", "upwardSalute"], minutes: 5)),
        StretchRoutine(id: "wakeShake", name: "Réveil dynamique", originalName: "Wake & Shake 1",
                       summary: "Routine dynamique pour se mettre en route", symbol: "bolt.fill", tint: .yellow,
                       moments: [.morning],
                       steps: steps(["goodMornings", "trunkTwist", "neckMobility"], minutes: 3)),
        StretchRoutine(id: "postureReset", name: "Posture", originalName: "Posture Reset",
                       summary: "Mobilité du cou, des épaules et du haut du dos", symbol: "person.bust.fill", tint: .teal,
                       moments: [.posture, .work],
                       steps: steps(["shoulderRolls", "overheadReach", "sideBend", "cactusArms", "neckFlex",
                                     "neckMobility", "neckLaterals", "diver"], minutes: 4)),
        StretchRoutine(id: "techNeck", name: "Nuque d'écran", originalName: "Tech Neck",
                       summary: "Tête projetée vers l'avant et épaules arrondies", symbol: "iphone", tint: .blue,
                       moments: [.posture, .work],
                       steps: steps(["chinRetractions", "wallPecs", "upwardSalute", "chinRetractions", "wallDog",
                                     "doorwayPecs", "oneArmHug", "reverseShoulder", "neckLaterals", "chinRetractions"],
                                    minutes: 5)),
        StretchRoutine(id: "deskStretch", name: "Au bureau", originalName: "Desk Stretch",
                       summary: "Pause après une longue période assise", symbol: "laptopcomputer", tint: .indigo,
                       moments: [.work],
                       steps: steps(["seatedFigureFour", "seatedHamstring", "trunkRotation", "chestOpener",
                                     "oneArmHug", "overheadTricep", "forearmStretch"], minutes: 6)),
        StretchRoutine(id: "neck1", name: "Cou", originalName: "Neck 1",
                       summary: "Mobilité cervicale, uniquement si les mouvements sont indolores", symbol: "figure.cooldown",
                       tint: .yellow, moments: [.posture],
                       steps: steps(["shoulderRolls", "neckMobility", "chinRetractions", "diver", "cactusArms",
                                     "neckExtension", "neckFlex", "earToShoulder", "scaleneStretch", "scapulaStretch",
                                     "neckRotation"], minutes: 4),
                       caution: "À faire uniquement si les mouvements sont indolores."),
        StretchRoutine(id: "sleep", name: "Sommeil", originalName: "Sleep",
                       summary: "Retour au calme avant le coucher", symbol: "moon.stars.fill", tint: .indigo,
                       moments: [.evening],
                       steps: steps(["ragDoll", "upwardDog", "childsPose", "kneesToChest", "happyBaby",
                                     "reclinedButterfly", "spinalTwist", "quadStretch", "legsUpWall"], minutes: 10)),
        StretchRoutine(id: "detox", name: "Mobilité et rotations", originalName: "Detox",
                       summary: "Mobilité et rotations de la colonne", symbol: "arrow.triangle.2.circlepath", tint: .green,
                       moments: [.mobility],
                       steps: steps(["wideLegBend", "upwardDog", "downwardDog", "catCow", "seatedTwist", "spinalTwist",
                                     "locust", "shoulderStand", "plow"], minutes: 8),
                       caution: "Le nom d'origine ne signifie pas une détoxification médicale. Chandelle et charrue sont des postures avancées, désactivées par défaut."),
        StretchRoutine(id: "hamstrings1", name: "Ischio-jambiers", originalName: "Hamstrings 1",
                       summary: "Arrière des cuisses et mobilité des jambes", symbol: "figure.flexibility", tint: .red,
                       moments: [.afterRun],
                       steps: steps(["toeTouch", "crossLegFold", "wideLegBend", "sideLunge", "reverseLunge",
                                     "seatedFold", "hurdler"], minutes: 6)),
        StretchRoutine(id: "hips1", name: "Hanches", originalName: "Hips 1",
                       summary: "Hanches, fessiers et cuisses", symbol: "figure.strengthtraining.functional", tint: .purple,
                       moments: [.afterRun],
                       steps: steps(["lunge", "reverseLunge", "butterfly", "lyingFigureFour", "quadStretch",
                                     "spinalTwist"], minutes: 6)),
        StretchRoutine(id: "shoulders1", name: "Épaules", originalName: "Shoulders 1",
                       summary: "Épaules, pectoraux et haut du dos", symbol: "figure.arms.open", tint: .teal,
                       moments: [.posture, .mobility],
                       steps: steps(["chestOpener", "oneArmHug", "reverseShoulder", "overheadTricep", "wallArms",
                                     "forwardFold", "wallPecs", "diver", "wallDog", "doorwayPecs"], minutes: 5)),
        StretchRoutine(id: "expert", name: "Expert", originalName: "Expert",
                       summary: "Routine générale avancée", symbol: "flame.fill", tint: .red,
                       moments: [.advanced],
                       steps: steps(["upwardSalute", "ragDoll", "chestOpener", "toeTouch", "overheadTricep", "forwardFold",
                                     "oneArmHug", "wideLegBend", "sideLunge", "squatStretch", "lunge", "reverseLunge",
                                     "kneelingQuad", "upwardDog", "childsPose", "downwardDog", "thunderbolt", "saddle",
                                     "toeSquat", "wristExtension", "lizard", "pigeon", "frog", "puppy", "twistedSphinx",
                                     "seatedTwist", "kneesToChest", "happyBaby", "lyingFigureFour", "lyingHamstring"],
                                    minutes: 30)),
    ]

    static func routine(_ id: String) -> StretchRoutine? { routines.first { $0.id == id } }

    // MARK: - Suggestions

    /// Routine conseillée selon le moment (organisation du guide) et une course récente.
    static func suggestions(now: Date = .now, ranRecently: Bool) -> [StretchRoutine] {
        let hour = Calendar.current.component(.hour, from: now)
        let weekday = Calendar.current.component(.weekday, from: now)
        let isWorkday = (2...6).contains(weekday)
        var ids: [String]
        if ranRecently {
            ids = ["hamstrings1", "hips1"]
        } else {
            switch hour {
            case 5..<10: ids = ["wakeUp", "wakeShake"]
            case 10..<17: ids = isWorkday ? ["deskStretch", "postureReset"] : ["hips1", "shoulders1"]
            case 17..<20: ids = ["techNeck", "postureReset"]
            default: ids = ["sleep", "hips1"]
            }
        }
        return ids.compactMap(routine)
    }

    // MARK: - Routine composée automatiquement

    /// Construit une routine à partir de zones ciblées et d'une durée.
    static func compose(zones: Set<StretchZone>, minutes: Int, neckCaution: Bool, calm: Bool) -> StretchRoutine {
        let secondsPerMove = calm ? 45 : 30
        let count = max(3, minutes * 60 / secondsPerMove)
        var candidates = moves.filter { move in
            !move.advanced && !(neckCaution && move.neck)
                && (zones.isEmpty || !zones.isDisjoint(with: move.zones))
        }
        // Les mouvements qui couvrent plusieurs zones demandées passent en premier, puis variété.
        candidates.sort { a, b in
            let sa = zones.intersection(a.zones).count
            let sb = zones.intersection(b.zones).count
            return sa != sb ? sa > sb : a.id < b.id
        }
        // Enchaînement fluide : debout → assis → à genoux → sol → allongé.
        let chosen = Array(candidates.prefix(count)).sorted { $0.position < $1.position }
        let name = zones.count == 1 ? "Express \(zones.first!.label.lowercased())" : "Ma routine du moment"
        return StretchRoutine(id: "composed-\(UUID().uuidString)", name: name,
                              summary: zones.isEmpty ? "Corps entier" : zones.map(\.label).sorted().joined(separator: ", "),
                              symbol: "sparkles", tint: .orange,
                              steps: chosen.map { StretchStep(moveID: $0.id, seconds: secondsPerMove) },
                              isCustom: true)
    }
}

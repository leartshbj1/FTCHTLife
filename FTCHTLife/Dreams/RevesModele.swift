import Foundation

// Rêves de vie : format des données dans docs/reves-format.md.
// Catalogue : FTCHTLife/Resources/Data/Dreams/*.json (un tableau de ReveDefinition par fichier).

// MARK: - Catalogue

enum ReveNiveau: String, Codable, CaseIterable {
    case serieux, ambitieux, absurde

    var nom: String {
        switch self {
        case .serieux: return "Sérieux"
        case .ambitieux: return "Ambitieux"
        case .absurde: return "Absurde"
        }
    }

    var icone: String {
        switch self {
        case .serieux: return "house.fill"
        case .ambitieux: return "crown.fill"
        case .absurde: return "theatermasks.fill"
        }
    }

    /// Bonus de bonheur par défaut quand le rêve est réalisé.
    var bonheurParDefaut: Int {
        switch self {
        case .serieux: return 20
        case .ambitieux: return 30
        case .absurde: return 25
        }
    }

    /// Poids par défaut dans le score « vie réussie ».
    var pointsParDefaut: Int {
        switch self {
        case .serieux: return 20
        case .ambitieux: return 35
        case .absurde: return 25
        }
    }
}

/// Conditions qui réalisent un rêve automatiquement. Toutes doivent être vraies.
struct ReveConditions: Codable, Equatable {
    var minMoney: Int?
    var maxMoney: Int?
    /// "ecoleObligatoire", "bac", "licence", "master", "doctorat".
    var minDiploma: String?
    /// Filière du diplôme obtenu ("medecine", "droit"…).
    var diplomaField: String?
    /// Identifiants de métiers acceptés (Emploi.metierId).
    var jobs: [String]?
    /// Bouts de mots cherchés dans l'intitulé du poste (sans accents ni majuscules).
    var jobTitleContains: [String]?
    var minJobLevel: Int?
    var minJobYears: Int?
    var minSalary: Int?
    /// true : adulte sans emploi ni études. false : en emploi ou en études.
    var unemployed: Bool?
    var minHappiness: Int?
    var maxHappiness: Int?
    var minHealth: Int?
    var maxHealth: Int?
    var minSmarts: Int?
    var maxSmarts: Int?
    var minLooks: Int?
    var maxLooks: Int?
    var minKarma: Int?
    var maxKarma: Int?
    var minAge: Int?
    var partner: Bool?
    var minChildren: Int?
    var minFriends: Int?
    /// Événements « unique » qui doivent tous avoir eu lieu.
    var seenEvents: [String]?
}

struct ReveDefinition: Codable, Identifiable, Equatable {
    var id: String
    var level: ReveNiveau
    var title: String
    var description: String
    var achievedText: String
    var failedText: String?
    var happiness: Int?
    var points: Int?
    var weight: Double?
    /// "any", "male" ou "female".
    var gender: String?
    /// Situation nécessaire au tirage : "mother", "father", "siblings", "friend".
    var requires: [String]?
    /// Âge limite : passé cet âge sans réussite, le rêve est raté.
    var deadlineAge: Int?
    var conditions: ReveConditions?
    /// Une seule de ces marques suffit à réaliser le rêve. La marque égale à l'id marche toujours.
    var marks: [String]?

    var bonheur: Int { happiness ?? level.bonheurParDefaut }
    var valeur: Int { max(1, points ?? level.pointsParDefaut) }
}

// MARK: - État sauvegardé avec le joueur

enum ReveStatut: String, Codable {
    case enCours, realise, rate
}

struct ReveActif: Codable, Equatable, Identifiable {
    var id: String
    var statut: ReveStatut = .enCours
    /// Âge auquel le rêve a été réalisé ou raté.
    var ageFin: Int?
}

/// Les rêves de la vie en cours. À stocker dans `Joueur.reves` (optionnel : les anciennes sauvegardes restent lisibles).
struct RevesDeVie: Codable, Equatable {
    var reves: [ReveActif] = []
    /// Âge du tirage, nil tant que les rêves n'ont pas été tirés.
    var ageTirage: Int?
    /// Marques posées par les événements (`dreamMarks`) et les autres modules.
    var marques: [String] = []
    var bonusTousRealises: Bool = false

    var tire: Bool { ageTirage != nil }
    var enCours: [ReveActif] { reves.filter { $0.statut == .enCours } }
    var realises: [ReveActif] { reves.filter { $0.statut == .realise } }
    var rates: [ReveActif] { reves.filter { $0.statut == .rate } }
}

// MARK: - Score « vie réussie »

struct RevesScore: Equatable {
    /// Score total sur 100.
    var total: Int
    /// Part des rêves (sur 60).
    var partReves: Int
    /// Part de la vie en général : bonheur, karma, longévité, entourage, réussite (sur 40).
    var partVie: Int
    var revesRealises: Int
    var revesTires: Int
    var mention: String
    var commentaire: String
    /// Détail ligne par ligne, pour l'écran de mort ou la nécrologie.
    var details: [String]
}

import Foundation

// Module Agence de détective privé : ouvrir son agence, prendre des affaires, enquêter, recruter.
// Règles, formats et branchement : docs/SECTE_DETECTIVE.md.
// Données : Resources/Data/Detective/affaires.json et Resources/Data/DetectiveEvents/*.json.

// MARK: - Données (JSON)

/// Fin d'une affaire avec un dilemme (ce qu'on fait de la vérité).
struct AgenceDenouement: Codable, Equatable {
    var text: String
    var choices: [AgenceChoix]
}

/// Un type d'affaire (adultère, fraude à l'assurance, disparition…).
struct AgenceTypeAffaire: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var icone: String
    var description: String
    /// Honoraires [min, max] en euros pour une agence débutante.
    var honoraires: [Int]
    /// Points d'enquête nécessaires [min, max].
    var difficulte: [Int]
    /// Années avant que le client abandonne.
    var duree: Int
    /// Réputation minimum de l'agence pour qu'on te confie ce genre d'affaire.
    var reputationMin: Int
    /// Risque de se faire blesser à chaque année d'enquête (0 à 1).
    var danger: Double
    /// Bonus par méthode (ex. {"filature": 1.4, "recherches": 0.7}). Absent = 1.
    var methodes: [String: Double]?
    /// Qui vient te voir (« Une pharmacienne inquiète »).
    var clients: [String]
    /// Qui ou quoi on cherche (« son mari, Gérald », « un comptable disparu »).
    var cibles: [String]
    /// Ce que l'enquête fait découvrir, une ligne par année.
    var indices: [String]
    /// Dilemmes possibles à la fin (une carte au hasard). Vide = rapport remis sans histoire.
    var denouements: [AgenceDenouement]
}

/// Effets d'une issue sur l'agence (en plus des effets classiques sur le joueur).
struct AgenceEffets: Codable, Equatable {
    var reputation: Int?
    /// Part des honoraires restants payée par le client (1 = tout, 0 = rien, 2 = le double).
    var paiement: Double?
    /// Somme en plus (pot-de-vin, prime…), en euros.
    var bonus: Int?
    /// Plainte contre l'agence : risque de suspension de l'agrément.
    var plainte: Bool?
    /// L'agrément est suspendu pendant N années.
    var suspension: Int?
    var prisonMois: Int?
    var infraction: String?
    /// L'affaire devient célèbre (racontée dans la presse, ajoutée au palmarès).
    var celebre: Bool?
    /// Un enquêteur de l'agence s'en va.
    var enqueteurPart: Bool?
    /// Compétence de l'enquêteur visé (+/-).
    var enqueteurCompetence: Int?
    /// Signal envoyé aux répercussions.
    var signal: String?
}

struct AgenceIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    var effects: Effets?
    var agence: AgenceEffets?
}

struct AgenceChoix: Codable, Equatable {
    var label: String
    /// Coût payé par le joueur avant le tirage.
    var cost: Int?
    var requiresSkill: [String: Int]?
    var outcomes: [AgenceIssue]
}

struct AgenceConditions: Codable, Equatable {
    var minReputation: Int?
    var maxReputation: Int?
    var minEnqueteurs: Int?
    /// Il faut une affaire en cours ({client}, {cible}, {affaire}).
    var affaireEnCours: Bool?
    /// Types d'affaire possibles pour l'affaire visée.
    var typesAffaire: [String]?
    /// true = seulement sans agrément (agence clandestine), false = seulement avec.
    var sansAgrement: Bool?
    var minEquipement: Int?
    var minBureau: Int?
    var minResolues: Int?
    var minAnnees: Int?
}

/// Un événement de la vie de l'agence (clients, police, menaces, presse, équipe).
struct AgenceEvenement: Codable, Identifiable, Equatable {
    var id: String
    /// "agence", "terrain" (pendant une affaire), "equipe", "police", "presse".
    var kind: String
    var weight: Double?
    var unique: Bool?
    var conditions: AgenceConditions?
    var text: String
    var choices: [AgenceChoix]
}

// MARK: - Méthodes d'enquête

enum AgenceMethode: String, Codable, CaseIterable, Identifiable {
    case filature, planque, terrain, recherches, infiltration, limite

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .filature: return "Filature"
        case .planque: return "Planque"
        case .terrain: return "Enquête de voisinage"
        case .recherches: return "Recherches et fichiers"
        case .infiltration: return "Infiltration"
        case .limite: return "Méthodes limites"
        }
    }

    var icone: String {
        switch self {
        case .filature: return "figure.walk"
        case .planque: return "camera.fill"
        case .terrain: return "bubble.left.and.bubble.right.fill"
        case .recherches: return "desktopcomputer"
        case .infiltration: return "theatermasks.fill"
        case .limite: return "exclamationmark.triangle.fill"
        }
    }

    var description: String {
        switch self {
        case .filature: return "Suivre la cible sans se faire voir. Il faut de l'endurance."
        case .planque: return "Des heures dans une voiture avec un téléobjectif et un thermos."
        case .terrain: return "Interroger voisins, collègues, commerçants. Le bagout compte."
        case .recherches: return "Registres, réseaux sociaux, recoupements. Pour les têtes bien faites."
        case .infiltration: return "Se faire passer pour quelqu'un d'autre. Efficace, risqué."
        case .limite: return "Micros, piratage, poubelles, faux prétextes. Très efficace, illégal."
        }
    }

    /// Compétence (module Compétences) qui aide.
    var competence: String {
        switch self {
        case .filature: return "sport"
        case .planque: return "photo"
        case .terrain: return "eloquence"
        case .recherches: return "code"
        case .infiltration: return "seduction"
        case .limite: return "bricolage"
        }
    }

    /// Points d'enquête de base par an.
    var base: Double {
        switch self {
        case .filature: return 24
        case .planque: return 22
        case .terrain: return 21
        case .recherches: return 23
        case .infiltration: return 32
        case .limite: return 40
        }
    }

    /// Risque de blessure en plus (0 à 1).
    var danger: Double {
        switch self {
        case .infiltration: return 0.08
        case .filature: return 0.03
        case .limite: return 0.04
        default: return 0
        }
    }

    /// Risque de plainte ou de poursuites (0 à 1).
    var risqueLegal: Double {
        switch self {
        case .limite: return 0.22
        case .infiltration: return 0.05
        default: return 0
        }
    }
}

// MARK: - État sauvegardé

struct AgenceEnqueteur: Codable, Identifiable, Equatable {
    var id = UUID()
    var prenom: String
    var nom: String
    var genre: Genre
    /// Relation du joueur si c'est un proche.
    var relationId: UUID?
    var competence: Int
    var salaire: Int
    /// Méthode où il ou elle est le plus à l'aise.
    var specialite: AgenceMethode
    var annees: Int = 0

    var nomComplet: String { "\(prenom) \(nom)" }
}

struct AgenceAffaire: Codable, Identifiable, Equatable {
    var id = UUID()
    var typeId: String
    var client: String
    var cible: String
    var honoraires: Int
    /// Points d'enquête nécessaires.
    var difficulte: Int
    var progres: Int = 0
    var annees: Int = 0
    var dureeMax: Int
    /// Enquêteur chargé de l'affaire (nil = le joueur lui-même).
    var enqueteurId: UUID? = nil
    /// Méthode choisie pour cette année (nil = enquête de voisinage par défaut).
    var methode: AgenceMethode? = nil
    /// Indices trouvés (lignes de texte).
    var indices: [String] = []
}

struct AgenceBilan: Codable, Equatable {
    var age: Int
    var recettes: Int
    var charges: Int
    var resolues: Int
    var ratees: Int
}

/// Fin d'affaire en attente d'une carte de dénouement.
struct AgenceDenouementEnAttente: Codable, Equatable {
    var typeId: String
    var index: Int
    var client: String
    var cible: String
    /// Honoraires restant à payer.
    var reste: Int
}

struct AgenceEtat: Codable, Equatable {
    var nom: String
    var ageOuverture: Int
    var reputation: Int = 8
    /// Agrément officiel (carte professionnelle). Sans lui, l'agence est clandestine.
    var agrement: Bool
    /// Âge jusqu'auquel l'agrément est suspendu.
    var suspenduJusqua: Int? = nil
    /// Matériel : 0 téléphone, 1 téléobjectif, 2 balises et micros, 3 labo et drones.
    var equipement: Int = 0
    /// Bureau : 0 chez soi, 1 petit bureau, 2 bureaux en centre-ville, 3 agence de prestige.
    var bureau: Int = 0
    var enqueteurs: [AgenceEnqueteur] = []
    var offres: [AgenceAffaire] = []
    var affaires: [AgenceAffaire] = []
    var denouements: [AgenceDenouementEnAttente] = []
    var resolues: Int = 0
    var ratees: Int = 0
    var celebres: [String] = []
    var annees: Int = 0
    var actionsAnnee: [String] = []
    var evenementsVus: [String] = []
    var bilan: AgenceBilan? = nil
    var plaintes: Int = 0
    /// Candidats au poste d'enquêteur (renouvelés chaque année).
    var candidats: [AgenceEnqueteur] = []
    /// Dénouement montré en carte cette année (pour payer le reste des honoraires après le choix).
    var denouementActif: AgenceDenouementEnAttente? = nil
    /// Affaire et enquêteur visés par la carte de l'année ({client}, {cible}, {enqueteur}).
    var affaireCibleId: UUID? = nil
    var enqueteurCibleId: UUID? = nil

    var suspendue: Bool { suspenduJusqua != nil }
}

struct AgenceArchive: Codable, Equatable, Identifiable {
    var id = UUID()
    var nom: String
    var ageDebut: Int
    var ageFin: Int
    var resolues: Int
    var celebres: [String]
    /// "fermee", "faillite", "justice", "mort".
    var fin: String
}

struct AgencesEtat: Codable, Equatable {
    var actuelle: AgenceEtat? = nil
    var anciennes: [AgenceArchive] = []
    var signaux: [String] = []
}

import Foundation

// Module Secte : fonder un mouvement, attirer des adeptes, gérer les dons… et finir devant un juge.
// Règles, formats et branchement : docs/SECTE_DETECTIVE.md.
// Données : Resources/Data/Secte/doctrines.json et Resources/Data/SecteEvents/*.json.

// MARK: - Données (JSON)

/// Une doctrine qu'on peut fonder (bien-être, apocalyptique, soucoupes volantes…).
struct SecteDoctrine: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var icone: String
    var description: String
    /// Comment on appelle les membres (« disciples », « éveillés »…).
    var adeptesNom: String
    /// Titre du fondateur, au masculin et au féminin (« Guide », « Guide »).
    var titreGourou: [String]
    /// Don moyen d'un adepte par an, en euros, à la contribution « modérée ».
    var donMoyen: Int
    /// Facilité à recruter (1 = normal).
    var attrait: Double
    /// Tendance naturelle aux dérives (points de dérive en plus par an).
    var risque: Int
    var nomsSuggeres: [String]
    /// Phrases du journal quand le joueur prêche.
    var preches: [String]
}

/// Effets d'une issue sur la secte (en plus des effets classiques sur le joueur).
struct SecteEffets: Codable, Equatable {
    /// Adeptes en plus ou en moins (nombre).
    var adeptes: Int?
    /// Adeptes en plus ou en moins, en pourcentage du total (ex. -20).
    var adeptesPct: Int?
    var ferveur: Int?
    var derive: Int?
    var surveillance: Int?
    var notoriete: Int?
    /// Trésor de la secte, en euros.
    var tresor: Int?
    /// Trésor en pourcentage (ex. -50 = la moitié part).
    var tresorPct: Int?
    /// Avance (+1) ou recul (-1) de l'enquête judiciaire.
    var enquete: Int?
    /// Préparation de la défense (avocats), de 0 à 3.
    var defense: Int?
    /// Prison pour le fondateur (mois). 0 = condamnation sans prison (amende, sursis).
    var prisonMois: Int?
    /// Infraction inscrite au casier (avec prisonMois).
    var infraction: String?
    /// Le mouvement est dissous (par la justice ou par le joueur).
    var dissoudre: Bool?
    /// Signal envoyé aux répercussions (ex. "secte_scandale").
    var signal: String?
}

struct SecteIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    var effects: Effets?
    var secte: SecteEffets?
}

struct SecteChoix: Codable, Equatable {
    var label: String
    /// Coût payé par le trésor de la secte (ou par le joueur s'il ne suffit pas).
    var cost: Int?
    var requiresSkill: [String: Int]?
    var outcomes: [SecteIssue]
}

struct SecteConditions: Codable, Equatable {
    var minAdeptes: Int?
    var maxAdeptes: Int?
    var minFerveur: Int?
    var maxFerveur: Int?
    var minDerive: Int?
    var maxDerive: Int?
    var minSurveillance: Int?
    var minNotoriete: Int?
    var minTresor: Int?
    /// Lieux possibles ("salon", "local", "temple", "domaine").
    var lieux: [String]?
    /// Stade exact de l'enquête (0 à 4).
    var enquete: Int?
    /// Il faut qu'un proche du joueur soit dans la secte ({proche}).
    var procheMembre: Bool?
    var minAnnees: Int?
}

/// Un événement de la secte : vie du mouvement, dérives, presse, justice.
struct SecteEvenement: Codable, Identifiable, Equatable {
    var id: String
    /// "vie" (vie du mouvement), "derive", "exterieur" (presse, familles, rivaux), "enquete" (carte d'un stade de l'enquête).
    var kind: String
    /// Doctrines concernées (vide ou absent = toutes).
    var doctrines: [String]?
    var weight: Double?
    var unique: Bool?
    var conditions: SecteConditions?
    var text: String
    var choices: [SecteChoix]
}

// MARK: - État sauvegardé

enum SecteLieu: String, Codable, CaseIterable, Identifiable {
    case salon, local, temple, domaine

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .salon: return "Ton salon"
        case .local: return "Un local loué"
        case .temple: return "Un temple"
        case .domaine: return "Un domaine à la campagne"
        }
    }

    var description: String {
        switch self {
        case .salon: return "Des chaises pliantes et du thé. On y tient à trente, serrés."
        case .local: return "Une ancienne boutique, des rideaux tirés. Jusqu'à 300 adeptes."
        case .temple: return "Un vrai lieu de culte, avec ton nom sur la façade. Jusqu'à 5 000 adeptes."
        case .domaine: return "Les adeptes vivent sur place et travaillent pour la communauté. Tu y consacres tout ton temps."
        }
    }

    /// Nombre d'adeptes que le lieu peut accueillir.
    var capacite: Int {
        switch self {
        case .salon: return 30
        case .local: return 300
        case .temple: return 5_000
        case .domaine: return 50_000
        }
    }

    /// Prix pour s'y installer (payé par le trésor, puis par le joueur).
    var prix: Int {
        switch self {
        case .salon: return 0
        case .local: return 8_000
        case .temple: return 450_000
        case .domaine: return 2_500_000
        }
    }

    /// Charges par an.
    var charges: Int {
        switch self {
        case .salon: return 0
        case .local: return 14_000
        case .temple: return 80_000
        case .domaine: return 220_000
        }
    }

    var rang: Int { SecteLieu.allCases.firstIndex(of: self) ?? 0 }
}

/// Bilan d'une année du mouvement.
struct SecteBilan: Codable, Equatable {
    var age: Int
    var nouveaux: Int
    var departs: Int
    var dons: Int
    var charges: Int
}

struct SecteEtat: Codable, Equatable {
    var nom: String
    var doctrineId: String
    var ageFondation: Int
    var adeptes: Int = 3
    /// Dévotion des adeptes (0 à 100).
    var ferveur: Int = 55
    /// Emprise, pressions, abus (0 à 100). Plus elle monte, plus la justice s'y intéresse.
    var derive: Int = 0
    /// Attention de la presse, des familles et des autorités (0 à 100).
    var surveillance: Int = 0
    /// À quel point le grand public te connaît (0 à 100).
    var notoriete: Int = 0
    /// Argent de la secte (séparé de l'argent du joueur).
    var tresor: Int = 0
    /// Contribution demandée : 0 libre, 1 modérée, 2 dîme, 3 « tout donner ».
    var contribution: Int = 1
    var lieu: SecteLieu = .salon
    /// Enquête judiciaire : 0 rien, 1 article de presse, 2 enquête préliminaire, 3 perquisition, 4 procès.
    var enquete: Int = 0
    /// Dernier stade de l'enquête pour lequel une carte a été montrée.
    var stadeAnnonce: Int = 0
    /// Avocats préparés (0 à 3).
    var defense: Int = 0
    /// Règles strictes (isolement des familles, téléphones confisqués…).
    var reglesStrictes: Bool = false
    /// Proches du joueur devenus adeptes.
    var prochesIds: [UUID] = []
    var annees: Int = 0
    var actionsAnnee: [String] = []
    var evenementsVus: [String] = []
    var bilan: SecteBilan? = nil
    /// Somme prise dans la caisse par le fondateur, depuis le début.
    var prelevements: Int = 0
}

/// Une secte qui n'existe plus.
struct SecteArchive: Codable, Equatable, Identifiable {
    var id = UUID()
    var nom: String
    var doctrineId: String
    var ageDebut: Int
    var ageFin: Int
    var adeptesMax: Int
    /// "dissoute" (par le joueur), "justice" (dissoute par un juge), "abandon" (plus personne), "mort".
    var fin: String
}

struct SectesEtat: Codable, Equatable {
    var actuelle: SecteEtat? = nil
    var anciennes: [SecteArchive] = []
    /// Plus grand nombre d'adeptes atteint par la secte actuelle.
    var adeptesMax: Int = 0
    /// Signaux à envoyer au prochain passage (fondation, scandale…).
    var signaux: [String] = []
}

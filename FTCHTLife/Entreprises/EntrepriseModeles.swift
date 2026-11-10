import Foundation

// Module Entreprises : créer sa propre boîte. Règles, formats et branchement : docs/ENTREPRISES.md.
// Données : Resources/Data/Entreprises/*.json (types) et Resources/Data/EntrepriseEvents/*.json (crises, opportunités).

// MARK: - Données (JSON)

/// Un type d'entreprise qu'on peut fonder (kebab, salon de coiffure, startup…).
struct EntrepriseType: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var secteur: String
    var icone: String
    var description: String
    var produit: String
    var coutCreation: Int
    var ageMin: Int?
    var diplomeMin: String?
    var filiere: String?
    var intelligenceMin: Int?
    var chiffreAffairesBase: Int
    var marge: Double
    var volatilite: Double
    var risque: Double
    var multipleValeur: Double
    var salaireEmploye: Int
    var postes: [String]
    var niveaux: [String]
    var nomsSuggeres: [String]

    var diplomeRequis: Diplome {
        switch diplomeMin ?? "aucun" {
        case "ecoleObligatoire": return .ecoleObligatoire
        case "bac": return .bac
        case "licence": return .licence
        case "master": return .master
        case "doctorat": return .doctorat
        default: return .aucun
        }
    }

    var filiereRequise: Filiere? { filiere.flatMap { Filiere(rawValue: $0) } }

    func nomNiveau(_ niveau: Int) -> String {
        guard !niveaux.isEmpty else { return "Niveau \(niveau + 1)" }
        return niveaux[min(max(0, niveau), niveaux.count - 1)]
    }

    var secteurNom: String { EntrepriseCatalogue.nomSecteur(secteur) }
}

/// Effets d'une issue sur la boîte. Montants en euros pour un niveau 0, multipliés par l'échelle de la boîte.
struct EntrepriseEffets: Codable, Equatable {
    var cash: Int?
    var argentJoueur: Int?
    var dette: Int?
    var reputation: Int?
    var elan: Int?
    var moral: Int?
    var employeMoral: Int?
    var employeCompetence: Int?
    var employePart: Bool?
    var lienEmploye: Int?
    var niveau: Int?
    var faillite: Bool?
}

struct EntrepriseIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    var business: EntrepriseEffets?
    var effects: Effets?
}

struct EntrepriseChoix: Codable, Equatable {
    var label: String
    /// Coût (niveau 0, mis à l'échelle) payé avant le tirage.
    var cost: Int?
    var outcomes: [EntrepriseIssue]
}

struct EntrepriseConditions: Codable, Equatable {
    /// "proche", "inconnu" ou "any" : il faut un employé de ce genre, désigné par {employe}.
    var employe: String?
    var minEmployes: Int?
    var maxEmployes: Int?
    var minAnnees: Int?
    var enDifficulte: Bool?
    var patronAbsent: Bool?
    var minReputation: Int?
    var maxReputation: Int?
}

/// Une crise, une opportunité ou un drame d'équipe, proposé au bilan annuel.
struct EntrepriseEvenement: Codable, Identifiable, Equatable {
    var id: String
    var kind: String?
    var secteurs: [String]?
    var types: [String]?
    var minNiveau: Int?
    var maxNiveau: Int?
    var weight: Double?
    var unique: Bool?
    var conditions: EntrepriseConditions?
    var text: String
    var choices: [EntrepriseChoix]
    /// Issue appliquée si le joueur n'a pas décidé avant le bilan suivant.
    var ignore: EntrepriseIssue?
}

// MARK: - État sauvegardé

/// Un employé nommé (poste clé). Un proche garde le lien vers sa relation.
struct EntrepriseEmploye: Codable, Identifiable, Equatable {
    var id = UUID()
    var prenom: String
    var nom: String
    var genre: Genre
    /// Relation du joueur (ami, famille…) si c'est un proche.
    var relationId: UUID?
    /// « Ami », « Mère »… pour l'affichage.
    var lienLibelle: String?
    var poste: String
    var competence: Int
    var motivation: Int
    var salaire: Int
    var annees: Int = 0

    var estProche: Bool { relationId != nil }
    var nomComplet: String { "\(prenom) \(nom)" }
}

/// La crise de l'année, en attente d'une décision.
struct EntrepriseCrise: Codable, Equatable {
    var evenementId: String
    var employeId: UUID?
    /// Texte déjà rempli au moment du tirage.
    var texte: String
}

struct EntrepriseBilan: Codable, Equatable {
    var age: Int
    var chiffreAffaires: Int
    var resultat: Int
}

struct Entreprise: Codable, Identifiable, Equatable {
    var id = UUID()
    var typeId: String
    var nom: String
    var ageCreation: Int
    var annees: Int = 0
    var niveau: Int = 0
    var niveauMax: Int = 0
    var tresorerie: Int = 0
    var dette: Int = 0
    var detteInitiale: Int = 0
    var reputation: Int = 50
    var elan: Int = 0
    var employes: [EntrepriseEmploye] = []
    var candidats: [EntrepriseEmploye] = []
    var historique: [EntrepriseBilan] = []
    var anneesDansLeRouge: Int = 0
    var crise: EntrepriseCrise?
    var evenementsVus: [String] = []
    var offreRachat: Int?
    var dividendes: Int = 0
    var concurrent: String

    var dernierBilan: EntrepriseBilan? { historique.last }
    var echelle: Double { EntrepriseMoteur.echelle(niveau) }
}

/// Une boîte qui n'existe plus (vendue, en faillite) : pour l'historique et la nécrologie.
struct EntrepriseArchive: Codable, Identifiable, Equatable {
    var id = UUID()
    var nom: String
    var typeId: String
    var ageDebut: Int
    var ageFin: Int
    /// "vendue" ou "faillite".
    var fin: String
    var montant: Int
    var niveauMax: Int
}

/// Tout ce que le module stocke dans la sauvegarde (`Joueur.entreprises`).
struct EntreprisesEtat: Codable, Equatable {
    var actives: [Entreprise] = []
    var archives: [EntrepriseArchive] = []
    /// Signaux pour le module Répercussions (entreprise_creee, entreprise_faillite…). À vider par celui qui les lit.
    var signaux: [String] = []
}

// MARK: - Catalogue

enum EntrepriseCatalogue {
    static let types: [EntrepriseType] = DonneesJSON.chargerTableaux(dossier: "Entreprises", type: EntrepriseType.self)
    static let evenements: [EntrepriseEvenement] = DonneesJSON.chargerTableaux(dossier: "EntrepriseEvents", type: EntrepriseEvenement.self)

    static func type(_ id: String) -> EntrepriseType? { types.first { $0.id == id } }
    static func evenement(_ id: String) -> EntrepriseEvenement? { evenements.first { $0.id == id } }

    static let ordreSecteurs = ["restauration", "beaute", "commerce", "mode", "tech", "services",
                                "artisanat", "loisirs", "immobilier", "transport"]

    static func nomSecteur(_ s: String) -> String {
        switch s {
        case "restauration": return "Restauration"
        case "beaute": return "Beauté"
        case "commerce": return "Commerce"
        case "mode": return "Mode"
        case "tech": return "Tech"
        case "services": return "Services"
        case "artisanat": return "Artisanat"
        case "loisirs": return "Loisirs"
        case "immobilier": return "Immobilier"
        case "transport": return "Transport"
        default: return s.capitalized
        }
    }

    static let concurrents = [
        "Chez Gégé", "Le Truc d'en Face", "MégaBidule SA", "Les Frères Pas-Cher", "Holding Requin & Fils",
        "Discount Royal", "Maison Prétentieuse", "Le Coin du Coin", "Groupe Vautour", "Super Pareil",
        "Start-Up Bidon", "Chez Ta Cousine", "Les Établissements Fourbes", "Crocodile Industries",
        "Au Bon Plagiat", "Le Clone", "Maxi Moins", "Patrick & Patrick", "L'Usine à Gaz", "Ultra Basique",
    ]
}

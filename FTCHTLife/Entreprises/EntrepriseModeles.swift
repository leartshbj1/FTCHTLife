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

    // Gestion poussée (v2). Valeurs par défaut pour les anciennes sauvegardes : voir init(from:).
    /// Points de vente (camions, salons, boutiques, agences…).
    var sites: Int = 1
    /// Unités de production (types à usine). −1 = à initialiser.
    var usines: Int = -1
    /// Employés « anonymes » (hors cadres nommés). −1 = à initialiser selon le besoin.
    var effectif: Int = -1
    /// Multiplicateur de prix (0,6 à 2).
    var prix: Double = 1
    /// Qualité de 1 à 5.
    var qualite: Int = 3
    /// Budget marketing en % du chiffre d'affaires.
    var marketing: Int = 2
    /// Niveau des salaires (0,8 à 1,4).
    var salaireNiveau: Double = 1
    /// Moral de l'équipe 0-100.
    var moral: Int = 60
    /// Pression de la concurrence (0,75 à 1,35), bouge chaque année.
    var pression: Double = 1
    /// Ids des leviers propres au métier activés.
    var leviers: [String] = []
    /// Dernier rapport annuel détaillé.
    var rapport: EntrepriseRapport?
    /// Le rapport de l'année n'a pas encore été montré au joueur.
    var rapportNonLu: Bool = false

    var dernierBilan: EntrepriseBilan? { historique.last }
    var echelle: Double { EntrepriseMoteur.echelle(niveau) }
}

/// Rapport annuel détaillé d'une boîte.
struct EntrepriseRapport: Codable, Equatable {
    var age: Int
    /// Clients potentiels sur les zones couvertes.
    var marche: Int
    var demande: Int
    var capacite: Int
    var ventes: Int
    var prixVente: Double
    var chiffreAffaires: Int
    var achats: Int
    var salaires: Int
    var loyers: Int
    var marketing: Int
    var leviers: Int
    var banque: Int
    var resultat: Int
    var tresorerie: Int
    var effectif: Int
    var sites: Int
    var usines: Int
    var reputation: Int
    var moral: Int
    var partDeMarche: Double
    var faits: [String] = []
    var conseils: [String] = []

    var couts: Int { achats + salaires + loyers + marketing + leviers + banque }
    var clientsRefuses: Int { max(0, demande - ventes) }
    var tauxOccupation: Double { capacite > 0 ? Double(ventes) / Double(capacite) : 0 }
}

extension Entreprise {
    enum CodingKeys: String, CodingKey {
        case id, typeId, nom, ageCreation, annees, niveau, niveauMax, tresorerie, dette, detteInitiale, reputation, elan
        case employes, candidats, historique, anneesDansLeRouge, crise, evenementsVus, offreRachat, dividendes, concurrent
        case sites, usines, effectif, prix, qualite, marketing, salaireNiveau, moral, pression, leviers, rapport, rapportNonLu
    }

    /// Lecture tolérante : les anciennes sauvegardes n'ont pas les champs de la gestion poussée.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        typeId = try c.decode(String.self, forKey: .typeId)
        nom = try c.decode(String.self, forKey: .nom)
        ageCreation = try c.decodeIfPresent(Int.self, forKey: .ageCreation) ?? 18
        annees = try c.decodeIfPresent(Int.self, forKey: .annees) ?? 0
        niveau = try c.decodeIfPresent(Int.self, forKey: .niveau) ?? 0
        niveauMax = try c.decodeIfPresent(Int.self, forKey: .niveauMax) ?? niveau
        tresorerie = try c.decodeIfPresent(Int.self, forKey: .tresorerie) ?? 0
        dette = try c.decodeIfPresent(Int.self, forKey: .dette) ?? 0
        detteInitiale = try c.decodeIfPresent(Int.self, forKey: .detteInitiale) ?? dette
        reputation = try c.decodeIfPresent(Int.self, forKey: .reputation) ?? 50
        elan = try c.decodeIfPresent(Int.self, forKey: .elan) ?? 0
        employes = try c.decodeIfPresent([EntrepriseEmploye].self, forKey: .employes) ?? []
        candidats = try c.decodeIfPresent([EntrepriseEmploye].self, forKey: .candidats) ?? []
        historique = try c.decodeIfPresent([EntrepriseBilan].self, forKey: .historique) ?? []
        anneesDansLeRouge = try c.decodeIfPresent(Int.self, forKey: .anneesDansLeRouge) ?? 0
        crise = try c.decodeIfPresent(EntrepriseCrise.self, forKey: .crise)
        evenementsVus = try c.decodeIfPresent([String].self, forKey: .evenementsVus) ?? []
        offreRachat = try c.decodeIfPresent(Int.self, forKey: .offreRachat)
        dividendes = try c.decodeIfPresent(Int.self, forKey: .dividendes) ?? 0
        concurrent = try c.decodeIfPresent(String.self, forKey: .concurrent) ?? "Le Truc d'en Face"
        sites = try c.decodeIfPresent(Int.self, forKey: .sites) ?? EntrepriseMoteur.seuilsSites[min(max(0, niveau), 5)]
        usines = try c.decodeIfPresent(Int.self, forKey: .usines) ?? -1
        effectif = try c.decodeIfPresent(Int.self, forKey: .effectif) ?? -1
        prix = try c.decodeIfPresent(Double.self, forKey: .prix) ?? 1
        qualite = try c.decodeIfPresent(Int.self, forKey: .qualite) ?? 3
        marketing = try c.decodeIfPresent(Int.self, forKey: .marketing) ?? 2
        salaireNiveau = try c.decodeIfPresent(Double.self, forKey: .salaireNiveau) ?? 1
        moral = try c.decodeIfPresent(Int.self, forKey: .moral) ?? 60
        pression = try c.decodeIfPresent(Double.self, forKey: .pression) ?? 1
        leviers = try c.decodeIfPresent([String].self, forKey: .leviers) ?? []
        rapport = try c.decodeIfPresent(EntrepriseRapport.self, forKey: .rapport)
        rapportNonLu = try c.decodeIfPresent(Bool.self, forKey: .rapportNonLu) ?? false
    }
}

// MARK: - Leviers propres au métier (Data/EntrepriseLeviers)

struct EntrepriseUnite: Codable, Equatable {
    var nom: String
    var pluriel: String
    var cout: Int?
}

struct EntrepriseLevierEffets: Codable, Equatable {
    var demande: Int?
    var prix: Int?
    var coutVariable: Int?
    var capacite: Int?
    var productivite: Int?
    var reputation: Int?
    var moral: Int?
    var risque: Int?
    var karma: Int?
}

struct EntrepriseLevier: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    var icone: String
    var groupe: String?
    var niveauMin: Int?
    var coutInstallation: Int?
    var coutAnnuel: Int?
    var parSite: Bool?
    var effets: EntrepriseLevierEffets?
    var activation: String?
}

struct EntrepriseLeviersType: Codable, Equatable {
    var typeId: String
    var vente: EntrepriseUnite?
    var site: EntrepriseUnite?
    var usine: EntrepriseUnite?
    var prixUnitaire: Double?
    var elasticite: Double?
    var leviers: [EntrepriseLevier]?
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
    static let leviersParType: [String: EntrepriseLeviersType] = {
        var d: [String: EntrepriseLeviersType] = [:]
        for l in DonneesJSON.chargerTableaux(dossier: "EntrepriseLeviers", type: EntrepriseLeviersType.self) { d[l.typeId] = l }
        return d
    }()
    /// Calibrage économique de chaque type, calculé une fois.
    static let economies: [String: EntrepriseEco] = {
        var d: [String: EntrepriseEco] = [:]
        for t in types { d[t.id] = EntrepriseEco(t, donnees: leviersParType[t.id]) }
        return d
    }()

    static func eco(_ typeId: String) -> EntrepriseEco? { economies[typeId] }

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

import Foundation

// Carrière politique : types de données et catalogue.
// Format des fichiers JSON et branchement dans le moteur : docs/POLITIQUE.md.

// MARK: - Postes

/// Les mandats possibles, du plus modeste au plus haut.
enum PolPoste: String, Codable, CaseIterable, Identifiable {
    case conseiller, adjoint, maire, depute, ministre, president

    var id: String { rawValue }

    /// Nom du poste accordé au genre du joueur.
    func nom(_ genre: Genre) -> String {
        let f = genre == .femme
        switch self {
        case .conseiller: return f ? "Conseillère municipale" : "Conseiller municipal"
        case .adjoint: return f ? "Adjointe au maire" : "Adjoint au maire"
        case .maire: return "Maire"
        case .depute: return f ? "Députée" : "Député"
        case .ministre: return "Ministre"
        case .president: return f ? "Présidente de la République" : "Président de la République"
        }
    }

    /// Durée du mandat en années (nil = pas de durée fixe : on peut être remercié à tout moment).
    var duree: Int? {
        switch self {
        case .conseiller, .maire: return 6
        case .depute, .president: return 5
        case .adjoint, .ministre: return nil
        }
    }

    /// Indemnité annuelle (versée chaque année en plus d'un éventuel salaire).
    var indemnite: Int {
        switch self {
        case .conseiller: return 2_400
        case .adjoint: return 14_000
        case .maire: return 38_000
        case .depute: return 92_000
        case .ministre: return 135_000
        case .president: return 190_000
        }
    }

    /// Élection au suffrage (sinon nomination).
    var estElu: Bool { self != .adjoint && self != .ministre }

    /// Ordre hiérarchique (sert à savoir si un nouveau mandat est une promotion).
    var rang: Int {
        switch self {
        case .conseiller: return 0
        case .adjoint: return 1
        case .maire: return 2
        case .depute: return 3
        case .ministre: return 4
        case .president: return 5
        }
    }

    /// Les lois de ce niveau : municipales pour la mairie, nationales au-dessus.
    var niveauLois: String? {
        switch self {
        case .conseiller: return nil
        case .adjoint, .maire: return "municipal"
        case .depute, .ministre, .president: return "national"
        }
    }

    /// Montant de campagne qui donne le bonus maximal.
    var budgetReference: Int {
        switch self {
        case .conseiller, .adjoint: return 3_000
        case .maire: return 25_000
        case .depute: return 90_000
        case .ministre: return 1
        case .president: return 2_000_000
        }
    }

    /// Caution à payer pour se présenter.
    var caution: Int {
        switch self {
        case .conseiller, .adjoint, .ministre: return 0
        case .maire: return 1_500
        case .depute: return 6_000
        case .president: return 150_000
        }
    }

    /// Facilité de l'élection (ajoutée au score).
    var facilite: Double {
        switch self {
        case .conseiller: return 18
        case .adjoint: return 0
        case .maire: return 2
        case .depute: return -4
        case .ministre: return 0
        case .president: return -14
        }
    }
}

// MARK: - État sauvegardé

/// Mandat en cours.
struct PolMandat: Codable, Equatable {
    var poste: PolPoste
    /// Années restantes (nil = sans échéance).
    var anneesRestantes: Int?
    /// Pour un ministre : identifiant du ministère.
    var ministereId: String?
    /// Nombre de fois que ce mandat a été obtenu d'affilée (réélections).
    var numero: Int = 1
    var ageDebut: Int
}

/// Mandat terminé, pour l'historique et la nécrologie.
struct PolMandatPasse: Codable, Equatable, Identifiable {
    var id = UUID()
    var poste: PolPoste
    var ministereId: String?
    var ageDebut: Int
    var ageFin: Int
    var fin: String
}

/// Campagne en cours : l'élection a lieu au prochain passage d'année.
struct PolCandidature: Codable, Equatable {
    var poste: PolPoste
    var adversaire: String
    var adversairePartiId: String?
    /// Bonus ou malus accumulés pendant la campagne (meetings, débats, coups bas…).
    var points: Double = 0
    var depenses: Int = 0
    var debatFait: Bool = false
    var reelection: Bool = false
}

/// Dossier posé sur le bureau du joueur, à traiter avant le prochain passage d'année.
struct PolDossierEnAttente: Codable, Equatable, Identifiable {
    var id: String { dossierId }
    var dossierId: String
    var ageArrivee: Int
}

/// Tout l'état politique d'une vie. À stocker comme champ optionnel de `Joueur` (`var politique: PolEtat?`).
struct PolEtat: Codable, Equatable {
    var partiId: String?
    /// Fidélité au parti (0-100).
    var loyaute: Int = 50
    /// Ce que les électeurs pensent de toi (0-100).
    var popularite: Int = 15
    /// Réseau, appuis, carnet d'adresses (0-100).
    var influence: Int = 5
    /// Soupçons, affaires, casseroles (0-100).
    var casseroles: Int = 0
    /// Caisse de campagne en euros.
    var caisse: Int = 0
    /// Parrainages d'élus (présidentielle : 500 requis).
    var parrainages: Int = 0
    var mandat: PolMandat?
    var candidature: PolCandidature?
    var historique: [PolMandatPasse] = []
    /// Lois en vigueur (identifiants de Data/Politique/Lois).
    var loisActives: [String] = []
    /// Lois que le joueur a fait adopter.
    var loisVotees: [String] = []
    /// Lois déjà proposées pendant ce mandat (on ne repropose pas une loi rejetée tout de suite).
    var loisTentees: [String] = []
    var dossiers: [PolDossierEnAttente] = []
    var dossiersVus: [String] = []
    var dernierSondage: Int?
    var dernierResultat: String?
    var mandatsPresident: Int = 0
    var elections: Int = 0
    var electionsGagnees: Int = 0
    /// Années d'inéligibilité restantes après une condamnation.
    var ineligibilite: Int = 0
    /// Titres de presse de l'année, pour le Journal du monde.
    var titres: [String] = []

    init() {}

    // Décodage tolérant : les futurs champs ne cassent pas les anciennes sauvegardes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        partiId = try c.decodeIfPresent(String.self, forKey: .partiId)
        loyaute = try c.decodeIfPresent(Int.self, forKey: .loyaute) ?? 50
        popularite = try c.decodeIfPresent(Int.self, forKey: .popularite) ?? 15
        influence = try c.decodeIfPresent(Int.self, forKey: .influence) ?? 5
        casseroles = try c.decodeIfPresent(Int.self, forKey: .casseroles) ?? 0
        caisse = try c.decodeIfPresent(Int.self, forKey: .caisse) ?? 0
        parrainages = try c.decodeIfPresent(Int.self, forKey: .parrainages) ?? 0
        mandat = try c.decodeIfPresent(PolMandat.self, forKey: .mandat)
        candidature = try c.decodeIfPresent(PolCandidature.self, forKey: .candidature)
        historique = try c.decodeIfPresent([PolMandatPasse].self, forKey: .historique) ?? []
        loisActives = try c.decodeIfPresent([String].self, forKey: .loisActives) ?? []
        loisVotees = try c.decodeIfPresent([String].self, forKey: .loisVotees) ?? []
        loisTentees = try c.decodeIfPresent([String].self, forKey: .loisTentees) ?? []
        dossiers = try c.decodeIfPresent([PolDossierEnAttente].self, forKey: .dossiers) ?? []
        dossiersVus = try c.decodeIfPresent([String].self, forKey: .dossiersVus) ?? []
        dernierSondage = try c.decodeIfPresent(Int.self, forKey: .dernierSondage)
        dernierResultat = try c.decodeIfPresent(String.self, forKey: .dernierResultat)
        mandatsPresident = try c.decodeIfPresent(Int.self, forKey: .mandatsPresident) ?? 0
        elections = try c.decodeIfPresent(Int.self, forKey: .elections) ?? 0
        electionsGagnees = try c.decodeIfPresent(Int.self, forKey: .electionsGagnees) ?? 0
        ineligibilite = try c.decodeIfPresent(Int.self, forKey: .ineligibilite) ?? 0
        titres = try c.decodeIfPresent([String].self, forKey: .titres) ?? []
    }

    mutating func borner() {
        loyaute = Stats.borne(loyaute)
        popularite = Stats.borne(popularite)
        influence = Stats.borne(influence)
        casseroles = Stats.borne(casseroles)
        caisse = max(0, caisse)
        parrainages = max(0, parrainages)
    }

    /// A déjà occupé (ou occupe) ce poste.
    func aOccupe(_ p: PolPoste) -> Bool {
        mandat?.poste == p || historique.contains { $0.poste == p }
    }

    /// Plus haut rang jamais atteint (-1 si aucun mandat).
    var rangMax: Int {
        ([mandat?.poste.rang ?? -1] + historique.map { $0.poste.rang }).max() ?? -1
    }
}

// MARK: - Données JSON

/// Parti politique (Data/Politique/Partis/*.json).
struct PolParti: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var sigle: String
    var slogan: String
    var description: String
    /// Couleur au format "#RRGGBB".
    var couleur: String
    /// "gauche", "droite", "centre", "ailleurs".
    var bord: String
    /// Bonus (ou malus) aux élections.
    var bonusElection: Double
    /// Cotisation annuelle prélevée tant qu'on est membre.
    var cotisation: Int
    /// Influence gagnée en adhérant.
    var influence: Int?
}

/// Ministère (Data/Politique/Ministeres/*.json).
struct PolMinistere: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
}

/// Effets politiques d'une issue (en points, sauf caisse et parrainages).
struct PolEffets: Codable, Equatable {
    var popularite: Int?
    var influence: Int?
    var casseroles: Int?
    var loyaute: Int?
    var caisse: Int?
    var parrainages: Int?
    /// Bonus de campagne (seulement pendant une candidature).
    var campagne: Double?
    /// Fin du mandat en cours (démission forcée, destitution…). Texte = raison.
    var finMandat: String?
    /// Années d'inéligibilité.
    var ineligibilite: Int?
    /// Fait adopter une loi précise (identifiant).
    var loi: String?
    /// Abroge une loi précise (identifiant).
    var abroger: String?
    /// Exclusion du parti.
    var exclusionParti: Bool?
}

struct PolIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    /// Effets classiques sur le joueur (format des événements du moteur).
    var effects: Effets?
    var pol: PolEffets?
}

struct PolChoix: Codable, Equatable {
    var label: String
    var outcomes: [PolIssue]
}

/// Dossier, scandale, débat ou moment de campagne (Data/Politique/Dossiers/*.json).
struct PolDossier: Codable, Identifiable, Equatable {
    var id: String
    /// "dossier" (bureau d'élu), "scandale", "debat" (débat télévisé), "campagne" (pendant une campagne), "militant" (vie de parti).
    var kind: String
    /// Postes concernés : "militant", "conseiller", "adjoint", "maire", "depute", "ministre", "president", ou "any".
    /// Pour "debat" et "campagne" : le poste visé par la candidature.
    var postes: [String]
    /// Pour un ministre : ministère concerné (absent = tous).
    var ministere: String?
    var weight: Double?
    var unique: Bool?
    var title: String
    var text: String
    var choices: [PolChoix]
}

/// Loi, arrêté ou décret absurde (Data/Politique/Lois/*.json).
struct PolLoi: Codable, Identifiable, Equatable {
    var id: String
    /// "municipal" ou "national".
    var niveau: String
    /// Pour une loi nationale : ministère qui peut la porter par décret (absent = seulement députés et président).
    var ministere: String?
    var titre: String
    var description: String
    /// 0 (passe toute seule) à 100 (quasi impossible).
    var difficulte: Int
    /// Effets immédiats à l'adoption.
    var adoption: PolEffets?
    /// Effets appliqués au joueur chaque année tant que la loi est en vigueur.
    var annuel: Effets?
    /// Multiplicateurs de prix (clés du Journal du monde : immobilier, voitures, nourriture, tout…).
    var prix: [String: Double]?
    /// Multiplicateurs de salaires par secteur (clés du Journal du monde : tech, sante, politique, tout…).
    var salaires: [String: Double]?
    /// Autres règles du jeu modifiées, lues par les autres modules (voir docs/POLITIQUE.md).
    var regles: [String: Double]?
    /// Tag ajouté au joueur tant que la loi est en vigueur (utilisable dans conditions.tags des événements).
    var tag: String?
    /// Titre de presse quand la loi passe ({ville}, {prenom}, {nom}, {poste}).
    var headline: String
    var texteAdoption: String
    var texteRejet: String
}

// MARK: - Catalogue

enum PolCatalogue {
    static let partis: [PolParti] = DonneesJSON.chargerTableaux(dossier: "Politique/Partis", type: PolParti.self)
    static let ministeres: [PolMinistere] = DonneesJSON.chargerTableaux(dossier: "Politique/Ministeres", type: PolMinistere.self)
    static let dossiers: [PolDossier] = DonneesJSON.chargerTableaux(dossier: "Politique/Dossiers", type: PolDossier.self)
    static let lois: [PolLoi] = DonneesJSON.chargerTableaux(dossier: "Politique/Lois", type: PolLoi.self)

    private static let dossiersParId: [String: PolDossier] = Dictionary(dossiers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    private static let loisParId: [String: PolLoi] = Dictionary(lois.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func parti(_ id: String?) -> PolParti? { id.flatMap { i in partis.first { $0.id == i } } }
    static func ministere(_ id: String?) -> PolMinistere? { id.flatMap { i in ministeres.first { $0.id == i } } }
    static func dossier(_ id: String) -> PolDossier? { dossiersParId[id] }
    static func loi(_ id: String) -> PolLoi? { loisParId[id] }
}

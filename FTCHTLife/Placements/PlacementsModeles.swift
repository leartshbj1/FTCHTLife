import Foundation

// Module Placements : livret d'épargne, bourse (actions, fonds, or), cryptos absurdes et immobilier locatif.
// Format des données et branchement : docs/PLACEMENTS.md.
// Tous les types sont préfixés « Placement » pour éviter les collisions.

// MARK: - Catalogue (données JSON)

enum PlacementType: String, Codable, CaseIterable {
    case action, fonds, or, crypto

    var nom: String {
        switch self {
        case .action: return "Action"
        case .fonds: return "Fonds"
        case .or: return "Métal précieux"
        case .crypto: return "Crypto"
        }
    }
}

/// Secteurs de la bourse. Le Journal du monde peut viser un secteur avec la clé de marché `bourse_<secteur>`.
enum PlacementSecteur: String, Codable, CaseIterable {
    case tech, alimentation, energie, luxe, sante, transport, loisirs, finance, industrie

    var nom: String {
        switch self {
        case .tech: return "Tech"
        case .alimentation: return "Alimentation"
        case .energie: return "Énergie"
        case .luxe: return "Luxe"
        case .sante: return "Santé"
        case .transport: return "Transport"
        case .loisirs: return "Loisirs"
        case .finance: return "Finance"
        case .industrie: return "Industrie"
        }
    }
}

/// Un titre qu'on peut acheter : action, fonds, or ou crypto. Fichiers `Data/Placements/Actifs/*.json`.
struct PlacementActif: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var ticker: String
    var type: PlacementType
    var secteur: PlacementSecteur?
    var description: String
    /// Prix d'une part au début d'une vie, en euros.
    var prixInitial: Double
    /// Tendance annuelle moyenne (0.06 = +6 % par an en moyenne).
    var rendement: Double
    /// Écart type annuel (0.25 = ça bouge de ±25 % une année normale).
    var volatilite: Double
    /// Part du prix versée chaque année en dividendes (0.03 = 3 %).
    var dividende: Double?
    /// Cryptos : chance par an d'exploser (prix ×10 à ×100).
    var chanceLune: Double?
    /// Cryptos : chance par an de valoir zéro pour toujours.
    var chanceZero: Double?
    /// Cryptos : texte quand elle explose. Peut contenir {nom}, {ticker}.
    var texteLune: String?
    /// Texte quand elle meurt (crypto) ou fait faillite (action). Peut contenir {nom}, {ticker}.
    var texteZero: String?
    /// Cryptos : présente dès le début de la vie (sinon lancée plus tard, au hasard).
    var depart: Bool?
}

/// Une nouvelle de marché tirée chaque année. Fichiers `Data/Placements/Nouvelles/*.json`.
struct PlacementNouvelle: Codable, Identifiable, Equatable {
    var id: String
    var texte: String
    /// Cible : "tout", "bourse", "crypto", "or", "immobilier", un secteur ("tech"…) ou l'id d'un actif ("act_…").
    var cible: String
    /// Variation de prix appliquée à la cible (−0.3 = −30 %), tirée entre min et max.
    var variationMin: Double
    var variationMax: Double
    var poids: Double?
}

/// Un bien locatif à acheter. Fichiers `Data/Placements/Biens/*.json`.
struct PlacementBienModele: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    var prix: Int
    /// Loyer annuel quand il est loué.
    var loyerAnnuel: Int
    /// Charges annuelles (taxe, entretien, copropriété), payées même sans locataire.
    var charges: Int
    /// Chance par an d'un pépin (0.15 = 15 %).
    var risque: Double
    var icone: String?
    /// Le nom avec possessif, inséré à la place de {bien} : « ton studio sous les toits ».
    var designation: String?
}

/// Profil de locataire. Fichiers `Data/Placements/Locataires/*.json`.
struct PlacementLocataireModele: Codable, Identifiable, Equatable {
    var id: String
    /// Description après le prénom, ex. « qui élève des escargots dans la baignoire ».
    var description: String
    /// Chance de payer le loyer chaque année (0 à 1).
    var fiabilite: Double
    /// Chance par an de partir de lui-même.
    var depart: Double?
    var poids: Double?
}

/// Pépin dans un bien locatif. Fichiers `Data/Placements/Incidents/*.json`.
struct PlacementIncident: Codable, Identifiable, Equatable {
    var id: String
    /// Texte, peut contenir {bien} (nom du bien) et {locataire} (prénom).
    var texte: String
    /// Coût en euros, tiré entre min et max (peut être 0, ou négatif pour un gain).
    var coutMin: Int
    var coutMax: Int
    var bonheur: Int?
    var karma: Int?
    /// Le locataire part.
    var locatairePart: Bool?
    /// Multiplie la valeur du bien (0.9 = −10 %).
    var valeur: Double?
    /// "loue" = seulement avec un locataire, "vide" = seulement sans, absent = toujours.
    var condition: String?
    var poids: Double?
}

enum PlacementsCatalogue {
    static let actifs: [PlacementActif] = DonneesJSON.chargerTableaux(dossier: "Placements/Actifs", type: PlacementActif.self)
    static let nouvelles: [PlacementNouvelle] = DonneesJSON.chargerTableaux(dossier: "Placements/Nouvelles", type: PlacementNouvelle.self)
    static let biens: [PlacementBienModele] = DonneesJSON.chargerTableaux(dossier: "Placements/Biens", type: PlacementBienModele.self)
    static let locataires: [PlacementLocataireModele] = DonneesJSON.chargerTableaux(dossier: "Placements/Locataires", type: PlacementLocataireModele.self)
    static let incidents: [PlacementIncident] = DonneesJSON.chargerTableaux(dossier: "Placements/Incidents", type: PlacementIncident.self)

    static func actif(_ id: String) -> PlacementActif? { actifs.first { $0.id == id } }
    static func bien(_ id: String) -> PlacementBienModele? { biens.first { $0.id == id } }
    static func locataire(_ id: String) -> PlacementLocataireModele? { locataires.first { $0.id == id } }
}

// MARK: - État sauvegardé (champ optionnel `placements` de Joueur)

struct PlacementCours: Codable, Equatable {
    var prix: Double
    /// Prix des dernières années (le plus récent à la fin), pour les courbes.
    var historique: [Double]
    /// Crypto morte ou entreprise en faillite : vaut zéro pour toujours.
    var mort: Bool = false
    /// Une crypto pas encore lancée n'apparaît pas.
    var lancee: Bool = true

    /// Variation sur la dernière année (0.1 = +10 %).
    var variation: Double {
        guard historique.count >= 2, let avant = historique.dropLast().last, avant > 0 else { return 0 }
        return prix / avant - 1
    }
}

struct PlacementPosition: Codable, Equatable {
    var actifId: String
    var quantite: Double
    /// Total payé pour ces parts (prix de revient), en euros.
    var investi: Double
}

struct PlacementLivret: Codable, Equatable {
    var solde: Int = 0
    var interetsCumules: Int = 0
}

struct PlacementBienPossede: Codable, Equatable, Identifiable {
    var id = UUID()
    var modeleId: String
    var nom: String
    var designation: String
    var valeur: Int
    var prixAchat: Int
    var loyerAnnuel: Int
    var charges: Int
    var risque: Double
    /// Prénom du locataire actuel (nil = vide).
    var locataire: String?
    var locataireModeleId: String?
    /// Capital restant dû sur le crédit.
    var credit: Int = 0
    /// Remboursement annuel du crédit (capital + intérêts).
    var annuite: Int = 0
    var annees: Int = 0
    var loyersEncaisses: Int = 0
    /// Année (compteur de PlacementsEtat.annees) de la dernière hausse de loyer.
    var anneeHausse: Int = -1
}

struct PlacementsEtat: Codable, Equatable {
    var livret = PlacementLivret()
    /// Taux annuel du livret (0.02 = 2 %).
    var tauxLivret: Double = 0.02
    var cours: [String: PlacementCours] = [:]
    var positions: [PlacementPosition] = []
    var biens: [PlacementBienPossede] = []
    /// Nouvelles du marché de l'année écoulée.
    var nouvelles: [String] = []
    var dividendesCumules: Int = 0
    /// Argent perdu dans des cryptos mortes.
    var perteCrypto: Int = 0
    /// Plus gros coup réussi en crypto (gain en euros).
    var meilleurCoupCrypto: Int = 0
    var annees: Int = 0
}

/// Ce dont le module a besoin du joueur et du monde pour passer une année ou faire une action.
struct PlacementsContexte {
    var age: Int
    /// Salaire annuel brut (0 sans emploi), pour savoir si la banque prête.
    var salaireAnnuel: Int = 0
    /// Multiplicateurs du Journal du monde : "bourse", "bourse_<secteur>", "crypto", "or", "immobilier_locatif", "epargne". 1.0 = neutre.
    var multiplicateurs: [String: Double] = [:]
    /// Mode triche : pas de pépins locatifs, cryptos immortelles.
    var triche: Bool = false

    func mult(_ cle: String) -> Double { multiplicateurs[cle] ?? 1.0 }
}

/// Résultat d'une année : à ajouter au journal et aux stats du joueur. L'argent est déjà appliqué.
struct PlacementsBilan {
    var lignes: [String] = []
    var bonheur: Int = 0
    var karma: Int = 0
    /// Variation d'argent liquide due aux placements cette année (dividendes, loyers, intérêts retirés…).
    var argent: Int = 0
}

// MARK: - Décodage tolérant
// Les champs ajoutés plus tard ne doivent pas casser une ancienne sauvegarde : tout est lu avec decodeIfPresent.

extension PlacementCours {
    enum CodingKeys: String, CodingKey { case prix, historique, mort, lancee }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prix = try c.decodeIfPresent(Double.self, forKey: .prix) ?? 0
        historique = try c.decodeIfPresent([Double].self, forKey: .historique) ?? []
        mort = try c.decodeIfPresent(Bool.self, forKey: .mort) ?? false
        lancee = try c.decodeIfPresent(Bool.self, forKey: .lancee) ?? true
    }
}

extension PlacementBienPossede {
    enum CodingKeys: String, CodingKey {
        case id, modeleId, nom, designation, valeur, prixAchat, loyerAnnuel, charges, risque
        case locataire, locataireModeleId, credit, annuite, annees, loyersEncaisses, anneeHausse
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        modeleId = try c.decodeIfPresent(String.self, forKey: .modeleId) ?? ""
        nom = try c.decodeIfPresent(String.self, forKey: .nom) ?? "Bien"
        designation = try c.decodeIfPresent(String.self, forKey: .designation) ?? "ton bien"
        valeur = try c.decodeIfPresent(Int.self, forKey: .valeur) ?? 0
        prixAchat = try c.decodeIfPresent(Int.self, forKey: .prixAchat) ?? valeur
        loyerAnnuel = try c.decodeIfPresent(Int.self, forKey: .loyerAnnuel) ?? 0
        charges = try c.decodeIfPresent(Int.self, forKey: .charges) ?? 0
        risque = try c.decodeIfPresent(Double.self, forKey: .risque) ?? 0.1
        locataire = try c.decodeIfPresent(String.self, forKey: .locataire)
        locataireModeleId = try c.decodeIfPresent(String.self, forKey: .locataireModeleId)
        credit = try c.decodeIfPresent(Int.self, forKey: .credit) ?? 0
        annuite = try c.decodeIfPresent(Int.self, forKey: .annuite) ?? 0
        annees = try c.decodeIfPresent(Int.self, forKey: .annees) ?? 0
        loyersEncaisses = try c.decodeIfPresent(Int.self, forKey: .loyersEncaisses) ?? 0
        anneeHausse = try c.decodeIfPresent(Int.self, forKey: .anneeHausse) ?? -1
    }
}

extension PlacementsEtat {
    enum CodingKeys: String, CodingKey {
        case livret, tauxLivret, cours, positions, biens, nouvelles
        case dividendesCumules, perteCrypto, meilleurCoupCrypto, annees
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        livret = try c.decodeIfPresent(PlacementLivret.self, forKey: .livret) ?? PlacementLivret()
        tauxLivret = try c.decodeIfPresent(Double.self, forKey: .tauxLivret) ?? 0.02
        cours = try c.decodeIfPresent([String: PlacementCours].self, forKey: .cours) ?? [:]
        positions = try c.decodeIfPresent([PlacementPosition].self, forKey: .positions) ?? []
        biens = try c.decodeIfPresent([PlacementBienPossede].self, forKey: .biens) ?? []
        nouvelles = try c.decodeIfPresent([String].self, forKey: .nouvelles) ?? []
        dividendesCumules = try c.decodeIfPresent(Int.self, forKey: .dividendesCumules) ?? 0
        perteCrypto = try c.decodeIfPresent(Int.self, forKey: .perteCrypto) ?? 0
        meilleurCoupCrypto = try c.decodeIfPresent(Int.self, forKey: .meilleurCoupCrypto) ?? 0
        annees = try c.decodeIfPresent(Int.self, forKey: .annees) ?? 0
    }
}

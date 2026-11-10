import Foundation

// Module « Vivre à l'étranger » : modèles et données.
// Données : FTCHTLife/Resources/Data/Etranger/pays.json et langues.json.
// Branchement dans le moteur : docs/ETRANGER.md.

// MARK: - Données (JSON)

/// Une langue que le joueur peut apprendre.
struct ExpatLangue: Codable, Identifiable, Equatable {
    let id: String
    /// En minuscules : « allemand ».
    let nom: String
    /// 1 (facile pour un francophone) à 5 (très difficile).
    let difficulte: Int
    let bonjour: String
    let merci: String
}

/// Une loi ou une règle du pays. Son id devient le tag `loi_<id>` quand le joueur y vit.
struct ExpatLoi: Codable, Identifiable, Equatable {
    let id: String
    let titre: String
    let texte: String
}

/// Un pays où l'on peut vivre. Les ids sont ceux de la création de perso (`fr`, `jp`…).
struct ExpatPays: Codable, Identifiable, Equatable {
    let id: String
    let nom: String
    let drapeau: String
    /// `ue`, `europe`, `amerique`, `afrique`, `asie`, `oceanie`. Libre circulation entre pays `ue`.
    let zone: String
    /// Langue principale, celle que l'immersion fait progresser.
    let langue: String
    /// Autres langues parlées : les connaître aide à communiquer.
    let autresLangues: [String]
    let villes: [String]
    /// Coefficient des salaires par rapport à la France (1 = France).
    let salaire: Double
    /// Coefficient du coût de la vie par rapport à la France.
    let prix: Double
    /// Part du salaire prise en impôts (le moteur en prend 25 % partout).
    let impots: Double
    /// Coefficient du prix des soins (médecin, hôpital).
    let sante: Double
    /// Difficulté du visa : 0 (aucun) à 4 (très difficile).
    let visa: Int
    /// Années de résidence avant de pouvoir demander la nationalité.
    let naturalisation: Int
    /// Prix du déménagement en euros (avion, cartons, caution).
    let coutDemenagement: Int
    let presentation: String
    let lois: [ExpatLoi]
    let coutumes: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nom = try c.decode(String.self, forKey: .nom)
        drapeau = try c.decode(String.self, forKey: .drapeau)
        zone = try c.decode(String.self, forKey: .zone)
        langue = try c.decode(String.self, forKey: .langue)
        autresLangues = try c.decodeIfPresent([String].self, forKey: .autresLangues) ?? []
        villes = try c.decode([String].self, forKey: .villes)
        salaire = try c.decodeIfPresent(Double.self, forKey: .salaire) ?? 1
        prix = try c.decodeIfPresent(Double.self, forKey: .prix) ?? 1
        impots = try c.decodeIfPresent(Double.self, forKey: .impots) ?? 0.25
        sante = try c.decodeIfPresent(Double.self, forKey: .sante) ?? 1
        visa = try c.decodeIfPresent(Int.self, forKey: .visa) ?? 2
        naturalisation = try c.decodeIfPresent(Int.self, forKey: .naturalisation) ?? 5
        coutDemenagement = try c.decodeIfPresent(Int.self, forKey: .coutDemenagement) ?? 2500
        presentation = try c.decodeIfPresent(String.self, forKey: .presentation) ?? ""
        lois = try c.decodeIfPresent([ExpatLoi].self, forKey: .lois) ?? []
        coutumes = try c.decodeIfPresent([String].self, forKey: .coutumes) ?? []
    }

    init(id: String, nom: String, drapeau: String, zone: String, langue: String, autresLangues: [String] = [],
         villes: [String], salaire: Double = 1, prix: Double = 1, impots: Double = 0.25, sante: Double = 1,
         visa: Int = 2, naturalisation: Int = 5, coutDemenagement: Int = 2500, presentation: String = "",
         lois: [ExpatLoi] = [], coutumes: [String] = []) {
        self.id = id; self.nom = nom; self.drapeau = drapeau; self.zone = zone; self.langue = langue
        self.autresLangues = autresLangues; self.villes = villes; self.salaire = salaire; self.prix = prix
        self.impots = impots; self.sante = sante; self.visa = visa; self.naturalisation = naturalisation
        self.coutDemenagement = coutDemenagement; self.presentation = presentation; self.lois = lois
        self.coutumes = coutumes
    }

    var toutesLangues: [String] { [langue] + autresLangues }

    /// « en Suisse », « au Japon », « aux États-Unis ».
    var enPays: String {
        if let p = ExpatPays.prepositions[id] { return "\(p) \(nom)" }
        return "en \(nom)"
    }

    static let prepositions: [String: String] = [
        "ca": "au", "ma": "au", "sn": "au", "xk": "au", "us": "aux", "gb": "au", "pt": "au",
        "br": "au", "jp": "au", "mx": "au", "ng": "au",
    ]

    var libelleVisa: String {
        switch visa {
        case 0: return "Sans visa"
        case 1: return "Visa facile"
        case 2: return "Visa moyen"
        case 3: return "Visa difficile"
        default: return "Visa très difficile"
        }
    }
}

/// Catalogue des pays et des langues, chargé une fois depuis Data/Etranger.
struct ExpatCatalogue {
    let pays: [ExpatPays]
    let langues: [ExpatLangue]

    func trouverPays(_ id: String) -> ExpatPays? { pays.first { $0.id == id } }
    func trouverLangue(_ id: String) -> ExpatLangue? { langues.first { $0.id == id } }
    func nomLangue(_ id: String) -> String { trouverLangue(id)?.nom ?? id }

    static let shared: ExpatCatalogue = charger()

    static func charger() -> ExpatCatalogue {
        let base = DonneesJSON.dossierData?.appendingPathComponent("Etranger", isDirectory: true)
        func lire<T: Decodable>(_ fichier: String, _ type: T.Type) -> [T] {
            guard let url = base?.appendingPathComponent(fichier),
                  let data = try? Data(contentsOf: url) else { return [] }
            do { return try JSONDecoder().decode([T].self, from: data) } catch {
                print("⚠️ Étranger : \(fichier) invalide : \(error)")
                return []
            }
        }
        let pays = lire("pays.json", ExpatPays.self)
        let langues = lire("langues.json", ExpatLangue.self)
        return ExpatCatalogue(pays: pays.isEmpty ? [secours] : pays,
                              langues: langues.isEmpty ? [ExpatLangue(id: "fr", nom: "français", difficulte: 1, bonjour: "Bonjour", merci: "Merci")] : langues)
    }

    static let secours = ExpatPays(id: "fr", nom: "France", drapeau: "🇫🇷", zone: "ue", langue: "fr",
                                   villes: ["Paris", "Lyon", "Marseille"], visa: 2,
                                   presentation: "Le pays où l'on râle avec passion.")
}

// MARK: - État du joueur (sauvegardé)

/// Un séjour dans un pays (pour l'historique et la nécrologie).
struct ExpatSejour: Codable, Equatable {
    var pays: String
    var ville: String
    var ageArrivee: Int
    var ageDepart: Int?
}

/// Tout ce que le module retient sur le joueur. À stocker dans `Joueur` (champ optionnel `etranger`).
struct ExpatEtat: Codable, Equatable {
    var paysNaissance: String
    var paysActuel: String
    /// Nationalités (pays de naissance + naturalisations).
    var nationalites: [String]
    /// Niveau par langue, 0 à 100 (100 = langue maternelle).
    var langues: [String: Int]
    /// Années passées dans le pays actuel.
    var anneesDansPays: Int = 0
    var sejours: [ExpatSejour] = []
    /// Âge du retour au pays de naissance (pour le tag `de_retour`).
    var ageRetour: Int?
    /// Visas refusés : pays → âge du refus (pas de nouvelle demande la même année).
    var refus: [String: Int] = [:]
    /// Pays visités au moins une fois (y compris le pays de naissance).
    var paysConnus: [String] = []

    /// État de départ : né dans `pays`, parle sa langue (et un peu des autres).
    static func naissance(pays id: String, ville: String, age: Int = 0,
                          catalogue: ExpatCatalogue = .shared) -> ExpatEtat {
        let p = catalogue.trouverPays(id) ?? catalogue.trouverPays("fr") ?? ExpatCatalogue.secours
        var langues: [String: Int] = [p.langue: 100]
        for l in p.autresLangues where langues[l] == nil { langues[l] = 55 }
        return ExpatEtat(paysNaissance: p.id, paysActuel: p.id, nationalites: [p.id], langues: langues,
                         anneesDansPays: age, sejours: [ExpatSejour(pays: p.id, ville: ville, ageArrivee: 0)],
                         paysConnus: [p.id])
    }

    /// Vit hors de son pays de naissance (tag `etranger`).
    var vitAilleurs: Bool { paysActuel != paysNaissance }

    func niveau(_ langue: String) -> Int { langues[langue] ?? 0 }
}

extension ExpatEtat {
    static func libelleNiveau(_ n: Int) -> String {
        switch n {
        case ..<1: return "Aucune notion"
        case ..<20: return "Tu dis bonjour à l'envers"
        case ..<40: return "Touriste qui pointe du doigt"
        case ..<60: return "Débrouillard"
        case ..<80: return "Courant"
        case ..<100: return "Bilingue"
        default: return "Langue maternelle"
        }
    }
}

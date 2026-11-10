import Foundation

// Module « Loisirs » : activités (randonnée, sport, hobbies, sorties, aventure…), leur progression,
// leurs blessures, abonnements et trophées. Les suites des années suivantes passent par le système
// de répercussions (signaux renvoyés dans LoisirResultat.signaux).
// Format des données : docs/LOISIRS.md. Données : Resources/Data/Loisirs/*.json.

// MARK: - Catégories

enum LoisirCategorie: String, CaseIterable, Identifiable {
    case nature, sport, bienEtre = "bien_etre", sorties, hobbies, aventure

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .nature: return "Nature et plein air"
        case .sport: return "Sport"
        case .bienEtre: return "Bien-être"
        case .sorties: return "Sorties"
        case .hobbies: return "Hobbies"
        case .aventure: return "Aventure et sensations"
        }
    }

    var icone: String {
        switch self {
        case .nature: return "mountain.2.fill"
        case .sport: return "figure.run"
        case .bienEtre: return "leaf.fill"
        case .sorties: return "ticket.fill"
        case .hobbies: return "paintpalette.fill"
        case .aventure: return "airplane.departure"
        }
    }
}

// MARK: - Données (JSON)

/// Blessure provoquée par une issue. Elle dure plusieurs années et bloque les activités physiques difficiles.
struct LoisirBlessure: Codable, Equatable {
    /// Nom sans article : « entorse à la cheville ».
    var name: String
    /// Durée en années (défaut 1).
    var years: Int?
    /// Variation de santé appliquée à chaque nouvelle année tant que la blessure dure (ex. -2).
    var healthPerYear: Int?
}

struct LoisirIssue: Codable, Equatable {
    /// Poids relatif de l'issue (défaut 1).
    var chance: Double?
    var text: String
    var effects: Effets?
    /// Issue « ratée » : elle devient plus rare quand le niveau monte.
    var bad: Bool?
    /// L'issue n'est possible qu'à partir de ce niveau (0 à 4).
    var minLevel: Int?
    /// L'issue n'est possible que jusqu'à ce niveau (0 à 4).
    var maxLevel: Int?
    var injury: LoisirBlessure?
    /// Trophée gagné (une seule fois par vie).
    var trophy: String?
    /// Signal pour le système de répercussions : « sommet » donne « <signal de l'activité>_sommet ».
    var signal: String?
    /// Signal précis propre à cette issue : envoie « <id de l'activité>_<key> » (pour une suite écrite exprès).
    var key: String?
}

struct LoisirOption: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    var description: String?
    /// Coût en euros (payé par les parents avant 18 ans). Gratuit si un abonnement de l'activité est actif.
    var cost: Int?
    var minAge: Int?
    /// Niveau minimum dans l'activité (0 à 4).
    var minLevel: Int?
    var minHealth: Int?
    /// Expérience gagnée (défaut 1).
    var xp: Int?
    var outcomes: [LoisirIssue]
}

struct LoisirAbonnement: Codable, Equatable {
    var name: String
    var yearlyCost: Int
}

struct LoisirActivite: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    /// Nom de symbole SF Symbols.
    var icon: String
    /// nature, sport, bien_etre, sorties, hobbies, aventure.
    var category: String
    var description: String
    var minAge: Int
    var maxAge: Int?
    /// Nombre de séances possibles par an (défaut 1).
    var perYear: Int?
    /// Activité physique : bloquée (options difficiles) en cas de blessure, compte pour le tag « sportif ».
    var physical: Bool?
    /// Tags requis / interdits (mêmes tags que les événements + tags des loisirs).
    var tags: [String]?
    var excludeTags: [String]?
    var subscription: LoisirAbonnement?
    /// Nom du signal envoyé au système de répercussions (défaut : l'id). Ex. « voyage » pour un trek lointain.
    var signal: String?
    var options: [LoisirOption]

    var categorie: LoisirCategorie { LoisirCategorie(rawValue: category) ?? .hobbies }
    var estPhysique: Bool { physical ?? false }
    var seancesParAn: Int { max(1, perYear ?? 1) }
}

// MARK: - État sauvegardé

struct LoisirBlessureActive: Codable, Equatable {
    var nom: String
    var anneesRestantes: Int
    var santeParAn: Int
    var activite: String
}

/// État des loisirs du joueur, à ranger dans `Joueur` (champ optionnel `loisirs: LoisirsEtat?`).
struct LoisirsEtat: Codable, Equatable {
    /// Expérience accumulée par activité.
    var xp: [String: Int] = [:]
    /// Séances faites cette année par activité (remis à zéro chaque année).
    var seancesAnnee: [String: Int] = [:]
    /// Nombre d'années d'affilée où l'activité a été pratiquée.
    var anneesAffilee: [String: Int] = [:]
    /// Âge de la dernière pratique par activité.
    var dernierAge: [String: Int] = [:]
    /// Activités dont l'abonnement est actif.
    var abonnements: [String] = []
    /// Années d'abonnement payées sans y aller, par activité.
    var anneesSansAller: [String: Int] = [:]
    var blessures: [LoisirBlessureActive] = []
    var trophees: [String] = []
    var totalSeances: Int = 0

    init() {}

    // Décodage tolérant : une sauvegarde plus ancienne (champ manquant) reste lisible.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = try c.decodeIfPresent([String: Int].self, forKey: .xp) ?? [:]
        seancesAnnee = try c.decodeIfPresent([String: Int].self, forKey: .seancesAnnee) ?? [:]
        anneesAffilee = try c.decodeIfPresent([String: Int].self, forKey: .anneesAffilee) ?? [:]
        dernierAge = try c.decodeIfPresent([String: Int].self, forKey: .dernierAge) ?? [:]
        abonnements = try c.decodeIfPresent([String].self, forKey: .abonnements) ?? []
        anneesSansAller = try c.decodeIfPresent([String: Int].self, forKey: .anneesSansAller) ?? [:]
        blessures = try c.decodeIfPresent([LoisirBlessureActive].self, forKey: .blessures) ?? []
        trophees = try c.decodeIfPresent([String].self, forKey: .trophees) ?? []
        totalSeances = try c.decodeIfPresent(Int.self, forKey: .totalSeances) ?? 0
    }

    func experience(_ id: String) -> Int { xp[id] ?? 0 }
    func niveau(_ id: String) -> Int { LoisirsRegles.niveau(xp: experience(id)) }
    func seances(_ id: String) -> Int { seancesAnnee[id] ?? 0 }
    func estAbonne(_ id: String) -> Bool { abonnements.contains(id) }
    var estBlesse: Bool { !blessures.isEmpty }
}

// MARK: - Règles

enum LoisirsRegles {
    /// Expérience nécessaire pour chaque niveau (0 = débutant … 4 = légende).
    static let seuils = [0, 3, 8, 16, 30]

    static func niveau(xp: Int) -> Int {
        var n = 0
        for (i, s) in seuils.enumerated() where xp >= s { n = i }
        return n
    }

    static func nomNiveau(_ n: Int, genre: Genre) -> String {
        let f = genre == .femme
        switch n {
        case 0: return f ? "Débutante" : "Débutant"
        case 1: return f ? "Amatrice" : "Amateur"
        case 2: return f ? "Confirmée" : "Confirmé"
        case 3: return f ? "Experte" : "Expert"
        default: return "Légende"
        }
    }

    /// Progression vers le niveau suivant, de 0 à 1 (1 au niveau maximum).
    static func progression(xp: Int) -> Double {
        let n = niveau(xp: xp)
        guard n + 1 < seuils.count else { return 1 }
        let bas = seuils[n], haut = seuils[n + 1]
        return Double(xp - bas) / Double(haut - bas)
    }

    /// Tags ajoutés par les loisirs, à fusionner avec `GameEngine.tags(_:)` :
    /// - `pratique_<id>` : a déjà pratiqué l'activité ;
    /// - `habitue_<id>` : niveau 2 (confirmé) ou plus ;
    /// - `sportif` : niveau 2+ dans une activité physique ;
    /// - `blesse` : blessure de loisir en cours ;
    /// - `abonne` : au moins un abonnement actif ;
    /// - `aventurier` : a pratiqué une activité de la catégorie aventure ;
    /// - `trophee` : a gagné au moins un trophée.
    static func tags(_ etat: LoisirsEtat?) -> Set<String> {
        guard let e = etat else { return [] }
        var t: Set<String> = []
        for (id, x) in e.xp where x > 0 {
            t.insert("pratique_\(id)")
            if niveau(xp: x) >= 2 {
                t.insert("habitue_\(id)")
                if LoisirsCatalogue.activite(id)?.estPhysique == true { t.insert("sportif") }
            }
            if LoisirsCatalogue.activite(id)?.categorie == .aventure { t.insert("aventurier") }
        }
        if e.estBlesse { t.insert("blesse") }
        if !e.abonnements.isEmpty { t.insert("abonne") }
        if !e.trophees.isEmpty { t.insert("trophee") }
        return t
    }
}

// MARK: - Catalogue

enum LoisirsCatalogue {
    /// Toutes les activités de Data/Loisirs, dans l'ordre des fichiers.
    static let toutes: [LoisirActivite] = DonneesJSON.chargerTableaux(dossier: "Loisirs", type: LoisirActivite.self)

    private static let index: [String: LoisirActivite] = {
        var d: [String: LoisirActivite] = [:]
        for a in toutes where d[a.id] == nil { d[a.id] = a }
        return d
    }()

    static func activite(_ id: String) -> LoisirActivite? { index[id] }

    static func parCategorie(_ c: LoisirCategorie) -> [LoisirActivite] {
        toutes.filter { $0.categorie == c }
    }
}

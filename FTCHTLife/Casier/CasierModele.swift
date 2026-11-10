import Foundation

// Module « casier judiciaire effaçable ». Voir docs/CASIER.md.
// Types préfixés « Casier » pour éviter les collisions avec les autres modules.

// MARK: - Gravité

enum CasierGravite: String, Codable, CaseIterable, Comparable {
    case contravention, delit, crime

    var rang: Int {
        switch self {
        case .contravention: return 0
        case .delit: return 1
        case .crime: return 2
        }
    }

    static func < (a: CasierGravite, b: CasierGravite) -> Bool { a.rang < b.rang }

    var nom: String {
        switch self {
        case .contravention: return "Contravention"
        case .delit: return "Délit"
        case .crime: return "Crime"
        }
    }

    var icone: String {
        switch self {
        case .contravention: return "doc.text"
        case .delit: return "exclamationmark.triangle.fill"
        case .crime: return "flame.fill"
        }
    }

    /// Années sans récidive avant l'effacement automatique (réhabilitation).
    var delaiRehabilitation: Int {
        switch self {
        case .contravention: return 3
        case .delit: return 5
        case .crime: return 10
        }
    }

    /// Heures de travaux d'intérêt général à faire pour effacer (ou, pour un crime, raccourcir le délai).
    var heuresTIG: Int {
        switch self {
        case .contravention: return 60
        case .delit: return 180
        case .crime: return 300
        }
    }

    /// Multiplicateur du prix des avocats.
    var facteurPrix: Double {
        switch self {
        case .contravention: return 0.4
        case .delit: return 1
        case .crime: return 3
        }
    }

    /// Multiplicateur des chances d'effacement par avocat ou piston.
    var facteurChance: Double {
        switch self {
        case .contravention: return 1.3
        case .delit: return 1
        case .crime: return 0.45
        }
    }
}

// MARK: - Casier

struct CasierCondamnation: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Groupe nominal en minuscules, ex. « vol de nains de jardin ».
    var infraction: String
    var gravite: CasierGravite
    /// Âge du joueur au moment de la condamnation.
    var age: Int
    /// Comment elle a été effacée (rempli quand elle passe aux archives).
    var effaceePar: String? = nil
    var ageEffacement: Int? = nil
}

/// Travaux d'intérêt général en cours.
struct CasierTIG: Codable, Equatable {
    var condamnationId: UUID
    var heuresTotal: Int
    var heuresFaites: Int
    var mission: String
}

/// État du casier, à stocker dans la sauvegarde (champ optionnel `casier` de `Joueur`).
struct CasierJudiciaire: Codable, Equatable {
    /// Condamnations encore inscrites.
    var condamnations: [CasierCondamnation] = []
    /// Condamnations effacées (archives, pour l'écran et le tag `casier_efface`).
    var effacees: [CasierCondamnation] = []
    /// Années écoulées depuis la dernière condamnation, hors prison.
    var anneesSansRecidive: Int = 0
    var tig: CasierTIG? = nil
    /// Pistons déjà tentés dans cette vie (chacun ne sert qu'une fois).
    var pistonsUtilises: [String] = []
    /// Nombre total de condamnations reçues dans la vie.
    var totalCondamnations: Int = 0

    var estVierge: Bool { condamnations.isEmpty }
    var graviteMax: CasierGravite? { condamnations.map(\.gravite).max() }

    /// Années restantes avant le prochain effacement automatique, ou nil si casier vierge.
    var prochainEffacementDans: Int? {
        guard let plusCourt = condamnations.map({ $0.gravite.delaiRehabilitation }).min() else { return nil }
        return max(0, plusCourt - anneesSansRecidive)
    }

    /// Années restantes avant que tout le casier soit effacé automatiquement.
    var effacementTotalDans: Int? {
        guard let g = graviteMax else { return nil }
        return max(0, g.delaiRehabilitation - anneesSansRecidive)
    }
}

// MARK: - Effet d'événement

/// Sous-objet `"casier"` dans les effets d'un événement (voir docs/CASIER.md).
struct CasierEffet: Codable, Equatable {
    struct Nouvelle: Codable, Equatable {
        var infraction: String
        var gravite: CasierGravite
    }
    /// Ajoute une condamnation.
    var condamnation: Nouvelle?
    /// "une" (la plus légère) ou "tout".
    var effacer: String?
    /// Années ajoutées au compteur sans récidive.
    var delai: Int?
}

// MARK: - Données (Resources/Data/Casier/…)

/// Un avocat qu'on peut engager pour faire effacer une condamnation (`Data/Casier/Avocats`).
struct CasierAvocat: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    /// Prix pour un délit ; multiplié par `CasierGravite.facteurPrix`.
    var prix: Int
    /// Chance de base (0…1) pour un délit.
    var chance: Double
    /// Gravité la plus lourde qu'il accepte de plaider.
    var graviteMax: CasierGravite
    /// Chance (0…1) que la combine soit découverte : nouvelle condamnation.
    var risque: Double?
    var infractionRisque: String?
    var succes: [String]
    var echecs: [String]
    var scandales: [String]?
}

/// Une personne ou une combine pour faire « disparaître » le casier (`Data/Casier/Pistons`).
struct CasierPiston: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    /// "parent", "ami", "partenaire", "fratrie", "metier", "riche" ou "aucune".
    var condition: String
    /// Lien minimal avec la relation (pour parent, ami, partenaire, fratrie).
    var lienMin: Int?
    /// Métiers qui donnent accès à ce piston (ids ou mots du titre), pour condition "metier".
    var metiers: [String]?
    /// Argent dépensé (dîner, cadeau, « don »).
    var prix: Int?
    var chance: Double
    var graviteMax: CasierGravite
    var risque: Double?
    var infractionRisque: String?
    /// Variation du lien avec la relation en cas d'échec.
    var lienEchec: Int?
    var succes: [String]
    var echecs: [String]
    var scandales: [String]?
}

/// Métier fermé tant que le casier contient une condamnation assez lourde (`Data/Casier/Metiers`).
struct CasierMetierFerme: Codable, Equatable {
    /// Nom du domaine affiché dans l'écran du casier, ex. « Police et douane ».
    var nom: String
    /// Ids exacts de métiers.
    var ids: [String]?
    /// Mots à chercher dans le titre du métier (minuscules, sans accents nécessaires).
    var motsCles: [String]?
    /// Gravité à partir de laquelle le métier est fermé.
    var graviteMin: CasierGravite
    var raison: String
}

/// Une mission de TIG (`Data/Casier/TIG`).
struct CasierMissionTIG: Codable, Equatable {
    var mission: String
    /// Phrases racontées dans le journal pendant les heures de TIG.
    var anecdotes: [String]
}

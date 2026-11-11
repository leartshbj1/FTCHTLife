import Foundation

// Module « Cœur » : liaisons secrètes, écarts, soupçons, découverte, enfants cachés,
// partenaire infidèle, crise de couple, thérapie, relation libre. Voir docs/COEUR.md.
// Types préfixés « Coeur ». État rangé dans `Joueur.coeur`.

// MARK: - Effets (sous-objet "coeur" des effets d'un événement, d'une suite ou d'un message)

struct CoeurEffets: Codable, Equatable {
    /// Aventure d'un soir : tromperie sans liaison durable.
    var ecart: Bool?
    /// "debut", "fin", "officialiser" (quitter le/la partenaire pour l'amant·e), "avouer".
    var liaison: String?
    /// Où l'amant·e a été rencontré·e : travail, ex, soiree, ami, voyage, sport, voisin, pecho, reseaux, fan, autre.
    var via: String?
    /// Variation de l'attachement de l'amant·e (0 à 100).
    var intensite: Int?
    /// Variation des soupçons du/de la partenaire (0 à 100 ; 100 = tout est découvert).
    var soupcon: Int?
    /// Le/la partenaire découvre tout (liaison ou écarts).
    var decouverte: Bool?
    /// Grossesse dans la liaison (n'agit qu'avec le tag liaison_hetero).
    var grossesse: Bool?
    /// Enfant caché : "reconnaitre", "pension", "cacher", "reveler".
    var enfantCache: String?
    /// Le/la partenaire commence (true) ou arrête (false) de tromper le joueur, en secret.
    var partenaireInfidele: Bool?
    /// Variation des soupçons du joueur envers son/sa partenaire.
    var soupconJoueur: Int?
    /// Le joueur prend son/sa partenaire sur le fait (si il/elle le trompe vraiment).
    var trahisonDecouverte: Bool?
    /// Pardon : fin de la crise, on tourne la page.
    var pardon: Bool?
    /// Années de crise de couple (le lien baisse chaque année sans thérapie).
    var crise: Int?
    /// Années de thérapie de couple (2 400 € par an, le lien remonte).
    var therapie: Int?
    /// Relation libre acceptée (true) ou terminée (false).
    var relationLibre: Bool?
    /// Scandale sur les réseaux : pourcentage d'abonnés perdus (si le joueur est un peu connu).
    var scandale: Int?
}

// MARK: - État sauvegardé

/// La personne avec qui le joueur a une liaison secrète.
struct CoeurLiaison: Codable, Equatable {
    var prenom: String
    var nom: String
    var genre: Genre
    var age: Int
    /// Âge du joueur au début de la liaison.
    var depuisAge: Int
    var via: String
    /// Attachement de l'amant·e (0 à 100).
    var intensite: Int = 55
    /// Soupçons du/de la partenaire (0 à 100).
    var soupcon: Int = 0
    /// L'amant·e a posé un ultimatum (« quitte-le/la ou c'est fini »).
    var ultimatum: Bool = false
}

/// Un enfant né d'une liaison ou d'un écart.
struct CoeurEnfantCache: Codable, Equatable, Identifiable {
    var id = UUID()
    var prenom: String
    var genre: Genre
    /// Âge du joueur à la naissance de l'enfant.
    var neQuandJoueurAvait: Int
    /// Prénom de l'autre parent.
    var autreParent: String
    var pension: Bool = false
    /// Le/la partenaire du joueur est au courant.
    var revele: Bool = false
    /// Reconnu : il est devenu un enfant dans la famille du joueur.
    var reconnu: Bool = false

    func age(_ ageJoueur: Int) -> Int { max(0, ageJoueur - neQuandJoueurAvait) }
}

struct CoeurEtat: Codable, Equatable {
    var liaison: CoeurLiaison?
    /// Prénoms des anciens amants et anciennes maîtresses.
    var anciennes: [String] = []
    /// Bébé de la liaison en route chez l'amante (mois restants) et prénom de l'autre parent.
    var grossesseLiaison: Int?
    var parentGrossesse: String?
    var enfantsCaches: [CoeurEnfantCache] = []
    /// Joueuse : le bébé en route ou né passe pour celui du partenaire, mais ne l'est pas.
    var paterniteDouteuse: Bool = false
    /// Écarts d'un soir que personne ne connaît (encore).
    var ecartsCaches: Int = 0
    /// Le/la partenaire trompe le joueur (le joueur ne le sait pas forcément).
    var partenaireInfidele: Bool = false
    /// Le joueur a pris son/sa partenaire sur le fait et n'a pas encore tranché.
    var trahi: Bool = false
    /// Soupçons du joueur envers son/sa partenaire (0 à 100).
    var soupconJoueur: Int = 0
    var tromperies: Int = 0
    var decouvertes: Int = 0
    var pardons: Int = 0
    /// Années de crise de couple restantes.
    var crise: Int = 0
    /// Années de thérapie de couple restantes.
    var therapie: Int = 0
    var relationLibre: Bool = false
    /// Actions limitées faites cette année (voir en cachette, fouiller le téléphone…).
    var actionsAnnee: [String] = []

    enum CodingKeys: String, CodingKey {
        case liaison, anciennes, grossesseLiaison, parentGrossesse, enfantsCaches, paterniteDouteuse, ecartsCaches
        case partenaireInfidele, trahi, soupconJoueur, tromperies, decouvertes, pardons, crise, therapie
        case relationLibre, actionsAnnee
    }

    init() {}

    /// Lecture tolérante : un champ ajouté plus tard ne casse pas les anciennes sauvegardes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        liaison = try c.decodeIfPresent(CoeurLiaison.self, forKey: .liaison)
        anciennes = try c.decodeIfPresent([String].self, forKey: .anciennes) ?? []
        grossesseLiaison = try c.decodeIfPresent(Int.self, forKey: .grossesseLiaison)
        parentGrossesse = try c.decodeIfPresent(String.self, forKey: .parentGrossesse)
        enfantsCaches = try c.decodeIfPresent([CoeurEnfantCache].self, forKey: .enfantsCaches) ?? []
        paterniteDouteuse = try c.decodeIfPresent(Bool.self, forKey: .paterniteDouteuse) ?? false
        ecartsCaches = try c.decodeIfPresent(Int.self, forKey: .ecartsCaches) ?? 0
        partenaireInfidele = try c.decodeIfPresent(Bool.self, forKey: .partenaireInfidele) ?? false
        trahi = try c.decodeIfPresent(Bool.self, forKey: .trahi) ?? false
        soupconJoueur = try c.decodeIfPresent(Int.self, forKey: .soupconJoueur) ?? 0
        tromperies = try c.decodeIfPresent(Int.self, forKey: .tromperies) ?? 0
        decouvertes = try c.decodeIfPresent(Int.self, forKey: .decouvertes) ?? 0
        pardons = try c.decodeIfPresent(Int.self, forKey: .pardons) ?? 0
        crise = try c.decodeIfPresent(Int.self, forKey: .crise) ?? 0
        therapie = try c.decodeIfPresent(Int.self, forKey: .therapie) ?? 0
        relationLibre = try c.decodeIfPresent(Bool.self, forKey: .relationLibre) ?? false
        actionsAnnee = try c.decodeIfPresent([String].self, forKey: .actionsAnnee) ?? []
    }

    /// Enfants cachés que le/la partenaire ne connaît pas.
    var enfantsSecrets: [CoeurEnfantCache] { enfantsCaches.filter { !$0.revele && !$0.reconnu } }

    func nombreActions(_ cle: String) -> Int { actionsAnnee.filter { $0 == cle }.count }
}

extension CoeurLiaison {
    /// « ton amant » / « ta maîtresse ».
    var role: String { genre == .femme ? "ta maîtresse" : "ton amant" }
    var pronom: String { genre == .femme ? "elle" : "il" }
    var nomComplet: String { "\(prenom) \(nom)" }

    /// Où vous vous êtes rencontrés, pour la fiche.
    var lieuTexte: String {
        switch via {
        case "travail": return "au travail"
        case "ex": return "une vieille histoire qui revient"
        case "soiree": return "en soirée"
        case "ami": return "dans ton cercle d'amis"
        case "voyage": return "en voyage"
        case "sport": return "à la salle de sport"
        case "voisin": return "dans ton immeuble"
        case "pecho": return "sur Pécho"
        case "reseaux": return "sur les réseaux"
        case "fan": return "un·e fan"
        default: return "par hasard"
        }
    }
}

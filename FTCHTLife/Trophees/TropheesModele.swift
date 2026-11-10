import Foundation

// Trophées : collection persistante sur toutes les vies, avec des bonus de départ à équiper.
// Format des données et branchement : docs/TROPHEES.md.
// Données : FTCHTLife/Resources/Data/Trophees/*.json (un tableau de TropheeDef par fichier).

/// Rareté d'un trophée (couleur et ordre d'affichage).
enum TropheeRarete: String, Codable, CaseIterable, Comparable {
    case bronze, argent, or, legendaire

    var nom: String {
        switch self {
        case .bronze: return "Bronze"
        case .argent: return "Argent"
        case .or: return "Or"
        case .legendaire: return "Légendaire"
        }
    }

    var ordre: Int {
        switch self {
        case .bronze: return 0
        case .argent: return 1
        case .or: return 2
        case .legendaire: return 3
        }
    }

    static func < (a: TropheeRarete, b: TropheeRarete) -> Bool { a.ordre < b.ordre }
}

/// Moment où la condition d'un trophée est vérifiée.
enum TropheeMoment: String, Codable {
    /// À tout moment pendant la vie (et au moment de la mort).
    case vie
    /// Seulement au moment de la mort.
    case mort
}

/// Conditions d'un trophée. Tous les champs sont optionnels et doivent TOUS être remplis.
struct TropheeCondition: Codable, Equatable {
    var moment: TropheeMoment?

    /// Nombre minimal de signaux dans la vie en cours, ex. {"mariage": 5}.
    /// Mêmes noms de signaux que les répercussions (docs/REPERCUSSIONS.md) + ceux de docs/TROPHEES.md.
    var compteurs: [String: Int]?
    /// Nombre maximal de signaux dans la vie en cours, ex. {"embauche": 0}.
    var maxCompteurs: [String: Int]?
    /// Nombre minimal de signaux sur toutes les vies, ex. {"mort": 10}.
    var compteursTotal: [String: Int]?
    /// Le signal est arrivé au moins une fois à cet âge ou plus tard, ex. {"crime_reussi": 80}.
    var apresAge: [String: Int]?
    /// Le signal est arrivé au moins une fois à cet âge ou plus tôt, ex. {"naissance_enfant": 17}.
    var avantAge: [String: Int]?

    /// Drapeaux (souvenirs du module répercussions) que le joueur doit tous avoir / ne pas avoir.
    var drapeaux: [String]?
    var sansDrapeaux: [String]?
    /// Tags du moteur et des modules (voir docs/ARCHITECTURE.md).
    var tags: [String]?
    var excludeTags: [String]?

    var gender: String?
    var minAge: Int?
    var maxAge: Int?
    var minArgent: Int?
    var maxArgent: Int?

    var minSante: Int?
    var maxSante: Int?
    var minBonheur: Int?
    var maxBonheur: Int?
    var minIntelligence: Int?
    var maxIntelligence: Int?
    var minApparence: Int?
    var maxApparence: Int?
    var minKarma: Int?
    var maxKarma: Int?

    /// Diplôme minimal / maximal : "aucun", "ecoleObligatoire", "bac", "licence", "master", "doctorat".
    var diplome: String?
    var maxDiplome: String?
    /// Filière du diplôme obtenu : "medecine", "droit", "informatique", "commerce", "arts", "sciences".
    var filiere: String?
    /// true = a un emploi, false = n'en a pas.
    var emploi: Bool?
    /// L'emploi actuel est l'un de ces métiers (ids de Donnees.metiers ou du module métiers).
    var metiers: [String]?
    /// Niveau minimal dans l'emploi actuel (0 à 4).
    var minNiveau: Int?
    var minAnneesEmploi: Int?

    /// Nombre minimal / maximal de proches vivants par type : "mere", "pere", "frere", "soeur",
    /// "ami", "partenaire", "enfant", "ex", plus "fratrie" et "parents".
    var minRelations: [String: Int]?
    var maxRelations: [String: Int]?
    /// Comme minRelations mais en comptant aussi les morts.
    var minRelationsTotal: [String: Int]?

    /// La cause de la mort contient l'un de ces mots (sans tenir compte des majuscules).
    var causeContient: [String]?
    /// Le prénom du joueur commence par l'un de ces textes.
    var prenomCommencePar: [String]?

    /// Nombre minimal de causes de mort différentes sur toutes les vies.
    var minCausesDifferentes: Int?
    /// Nombre minimal de trophées déjà obtenus.
    var minTrophees: Int?
    /// Le mode Shkurtaaa doit être actif (true) ou coupé (false).
    var shkurtaaa: Bool?
}

/// Bonus de départ débloqué par un trophée, appliqué à la naissance si le joueur l'a équipé.
struct TropheeBonus: Codable, Equatable {
    var titre: String
    var description: String
    var argent: Int?
    var sante: Int?
    var bonheur: Int?
    var intelligence: Int?
    var apparence: Int?
    var karma: Int?
    /// Argent ajouté à chacun des deux parents (héritage plus tard, cadeaux…).
    var argentParents: Int?
    /// Lien ajouté avec chacun des parents.
    var lienParents: Int?
    /// Ajoute un ami d'enfance dès la naissance.
    var ami: Bool?
}

/// Un trophée du catalogue.
struct TropheeDef: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    /// Catégorie d'affichage : "vie", "mort", "argent", "amour", "famille", "ecole", "travail", "crime",
    /// "sante", "loisirs", "casino", "permis", "boutique", "celebrite", "monde", "secret", "collection"…
    var categorie: String
    var rarete: TropheeRarete
    /// Caché tant qu'il n'est pas obtenu (« ??? »).
    var secret: Bool?
    var condition: TropheeCondition
    var bonus: TropheeBonus?
}

enum CatalogueTrophees {
    /// Tous les trophées de tous les fichiers de Data/Trophees.
    static let tous: [TropheeDef] = DonneesJSON.chargerTableaux(dossier: "Trophees", type: TropheeDef.self)

    static let parId: [String: TropheeDef] = Dictionary(tous.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    struct Categorie: Identifiable {
        let id: String
        let nom: String
        let icone: String
    }

    static let categories: [Categorie] = [
        Categorie(id: "vie", nom: "Vivre", icone: "figure.walk"),
        Categorie(id: "mort", nom: "Mourir", icone: "leaf.fill"),
        Categorie(id: "argent", nom: "Argent", icone: "eurosign.circle.fill"),
        Categorie(id: "amour", nom: "Amour", icone: "heart.fill"),
        Categorie(id: "famille", nom: "Famille", icone: "house.fill"),
        Categorie(id: "ecole", nom: "École et études", icone: "graduationcap.fill"),
        Categorie(id: "travail", nom: "Travail", icone: "briefcase.fill"),
        Categorie(id: "crime", nom: "Crime et justice", icone: "lock.fill"),
        Categorie(id: "sante", nom: "Santé et corps", icone: "cross.case.fill"),
        Categorie(id: "loisirs", nom: "Loisirs", icone: "figure.hiking"),
        Categorie(id: "casino", nom: "Jeux d'argent", icone: "suit.club.fill"),
        Categorie(id: "permis", nom: "Permis et volant", icone: "car.fill"),
        Categorie(id: "boutique", nom: "Achats", icone: "bag.fill"),
        Categorie(id: "celebrite", nom: "Célébrité", icone: "star.fill"),
        Categorie(id: "monde", nom: "Monde et société", icone: "globe.europe.africa.fill"),
        Categorie(id: "animaux", nom: "Animaux", icone: "pawprint.fill"),
        Categorie(id: "etrange", nom: "Étrange", icone: "eye.fill"),
        Categorie(id: "collection", nom: "Collectionneur", icone: "trophy.fill"),
    ]

    static func nomCategorie(_ id: String) -> String {
        categories.first { $0.id == id }?.nom ?? id.capitalized
    }

    static func iconeCategorie(_ id: String) -> String {
        categories.first { $0.id == id }?.icone ?? "trophy.fill"
    }
}

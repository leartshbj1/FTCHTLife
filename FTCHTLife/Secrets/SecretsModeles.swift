import Foundation

// Secrets et chantage : types des données et état sauvegardé.
// Format des données, règles et branchement dans le moteur : docs/SECRETS.md.

// MARK: - Données (JSON)

/// Un secret possible, chez un proche ou chez le joueur. Fichiers : Data/Secrets/Modeles/*.json.
struct SecretModele: Codable, Identifiable, Equatable {
    var id: String
    var titre: String
    /// 1 (gênant) à 5 (explosif).
    var gravite: Int
    /// "mere", "pere", "frere", "soeur", "ami", "partenaire", "enfant", "ex" et "joueur".
    var porteurs: [String]
    var minAge: Int?
    var maxAge: Int?
    /// "any", "male" ou "female" (genre du porteur).
    var genre: String?
    var poids: Double?
    /// Si vrai, un prénom au hasard remplace {complice}.
    var complice: Bool?
    /// Proches du joueur que la révélation d'un secret du joueur blesse beaucoup plus.
    var blesse: [String]?
    /// Signal de répercussion émis à la révélation.
    var signalRevelation: String?
    /// Signaux du jeu qui créent ce secret chez le joueur.
    var signaux: [String]?
    /// Si vrai, ce secret du joueur n'apparaît que via `signaux`.
    var seulementSignal: Bool?

    // Secret d'un proche
    var resume: String?
    var indices: [String]?
    var decouvertes: [String]?
    var revelations: [String]?
    var chantages: [String]?

    // Secret du joueur
    var resumeJoueur: String?
    var naissances: [String]?
    var demasques: [String]?
    var revelationsJoueur: [String]?

    var pourJoueur: Bool { porteurs.contains("joueur") }

    func peutEtrePorte(par type: String, age: Int, genre g: Genre) -> Bool {
        guard porteurs.contains(type) else { return false }
        if let m = minAge, age < m { return false }
        if let m = maxAge, age > m { return false }
        if genre == "male" && g != .homme { return false }
        if genre == "female" && g != .femme { return false }
        return true
    }
}

/// Un « pire moment » pour révéler un secret gardé. Fichiers : Data/Secrets/Moments/*.json.
struct SecretMoment: Codable, Identifiable, Equatable {
    var id: String
    var porteurs: [String]
    var minAge: Int?
    var maxAge: Int?
    /// Amplifie les dégâts et la honte (1 à 3).
    var multiplicateur: Double?
    var texte: String
    var resultats: [String]
}

/// Textes génériques rangés par clé. Fichiers : Data/Secrets/Textes/*.json.
struct SecretTextes: Codable, Equatable {
    var cle: String
    var textes: [String]
}

enum BibliothequeSecrets {
    static let modeles: [SecretModele] = DonneesJSON.chargerTableaux(dossier: "Secrets/Modeles", type: SecretModele.self)
    static let moments: [SecretMoment] = DonneesJSON.chargerTableaux(dossier: "Secrets/Moments", type: SecretMoment.self)
    static let textes: [String: [String]] = {
        var d: [String: [String]] = [:]
        for t in DonneesJSON.chargerTableaux(dossier: "Secrets/Textes", type: SecretTextes.self) {
            d[t.cle, default: []] += t.textes
        }
        return d
    }()

    private static let parId: [String: SecretModele] =
        Dictionary(modeles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func modele(_ id: String) -> SecretModele? { parId[id] }

    /// Un texte au hasard pour une clé, ou le texte de secours.
    static func texte(_ cle: String, secours: String) -> String {
        textes[cle]?.randomElement() ?? secours
    }
}

// MARK: - État (sauvegarde)

enum SecretStatut: String, Codable {
    /// Proche : le joueur ne le connaît pas. Joueur : personne ne le connaît, ou ceux qui savent se taisent.
    case cache
    /// Proche : le joueur le connaît et le garde pour lui (peut ressortir au pire moment).
    case garde
    /// Proche : le joueur lui a dit qu'il savait. On reste entre nous.
    case partage
    /// Proche : le joueur le fait chanter. Joueur : quelqu'un fait chanter le joueur.
    case chantage
    /// Équilibre de la terreur : chacun tient l'autre, personne ne parle.
    case equilibre
    /// Tout le monde est au courant.
    case revele
}

/// Un secret en cours dans une vie.
struct SecretInstance: Codable, Identifiable, Equatable {
    var id = UUID()
    var modeleId: String
    /// Proche qui porte le secret ; nil = le joueur.
    var porteurId: UUID?
    var complice: String?
    var compliceFemme: Bool = false
    /// Âge du joueur quand le secret est apparu.
    var ageCreation: Int
    var statut: SecretStatut = .cache
    /// Secret d'un proche : nombre d'indices déjà vus.
    var indices: Int = 0
    /// Secret du joueur : proches qui sont au courant.
    var savent: [UUID] = []
    /// Secret du joueur : qui le fait chanter.
    var maitreChanteurId: UUID?
    /// Montant annuel du chantage (dans un sens ou dans l'autre).
    var montant: Int = 0
    var anneesChantage: Int = 0
    var ageRevelation: Int?

    var estDuJoueur: Bool { porteurId == nil }
    var modele: SecretModele? { BibliothequeSecrets.modele(modeleId) }
}

/// Type de choix proposé sur une carte de secret.
enum SecretAction: String, Codable {
    case garder, direQueTuSais, reveler, faireChanter
    case revelerMaintenant, taire
    case payer, refuser, avouer, contreMenacer
}

/// Une carte en attente de réponse (affichée par le moteur comme un événement).
struct SecretCarte: Codable, Equatable {
    var id: String
    var secretId: UUID
    var actions: [SecretAction]
    /// Pour une carte « pire moment ».
    var momentId: String?
    /// Pour une carte de chantage : le maître chanteur et le montant demandé.
    var relationId: UUID?
    var montant: Int?
}

/// État des secrets d'une vie, stocké dans `Joueur.secrets`.
struct SecretsEtat: Codable, Equatable {
    var secrets: [SecretInstance] = []
    var cartes: [SecretCarte] = []

    init() {}

    func index(_ id: UUID) -> Int? { secrets.firstIndex { $0.id == id } }
    func duProche(_ relationId: UUID) -> [SecretInstance] { secrets.filter { $0.porteurId == relationId } }
    var duJoueur: [SecretInstance] { secrets.filter { $0.estDuJoueur } }
}

/// Ce qui s'est passé dans l'année côté secrets.
struct SecretsAnnee {
    var lignes: [String] = []
    /// Cartes à afficher comme des événements (ids "secret_carte:…").
    var evenements: [Evenement] = []
    /// Signaux pour le module répercussions.
    var signaux: [String] = []
}

/// Résultat d'une action sur un secret.
struct SecretsResultat {
    var texte: String
    var signaux: [String] = []
}

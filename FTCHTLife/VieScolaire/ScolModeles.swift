import Foundation

// Vie au collège et au lycée : voir docs/VIE_SCOLAIRE.md.

// MARK: - État sauvegardé

/// Tout ce que le module retient sur la scolarité du joueur (11 à 18 ans).
struct ScolEtat: Codable, Equatable {
    var popularite: Int = 50
    var faveurProfs: Int = 50
    /// Id du groupe (`sportifs`, `intellos`…), nil = sans groupe.
    var groupe: String?
    var anneesDansGroupe: Int = 0
    /// Lettre de la classe de l'année (« B » pour « 4e B »).
    var lettreClasse: String = "A"

    var estDelegue: Bool = false
    var promesse: String?
    var mandats: Int = 0
    /// Âge auquel le joueur s'est présenté pour la dernière fois (une élection par an).
    var electionAge: Int?

    var collesAnnee: Int = 0
    var collesTotal: Int = 0
    var convocations: Int = 0
    var convoqueCetteAnnee: Bool = false
    /// Bonus (ou malus) de moyenne gagné pendant l'année, en points sur 20.
    var bonusNotes: Double = 0

    var bulletins: [ScolBulletin] = []
    var brevet: Bool?
    var noteOralFrancais: Double?
    var noteGrandOral: Double?
    var voyages: [String] = []
    var scenesVues: [String] = []

    /// Choses à faire cette année (situations, convocation, voyage, oral).
    var aFaire: [ScolTache] = []

    init() {}

    // Lecture tolérante : un champ ajouté plus tard ne casse pas les anciennes sauvegardes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        popularite = try c.decodeIfPresent(Int.self, forKey: .popularite) ?? 50
        faveurProfs = try c.decodeIfPresent(Int.self, forKey: .faveurProfs) ?? 50
        groupe = try c.decodeIfPresent(String.self, forKey: .groupe)
        anneesDansGroupe = try c.decodeIfPresent(Int.self, forKey: .anneesDansGroupe) ?? 0
        lettreClasse = try c.decodeIfPresent(String.self, forKey: .lettreClasse) ?? "A"
        estDelegue = try c.decodeIfPresent(Bool.self, forKey: .estDelegue) ?? false
        promesse = try c.decodeIfPresent(String.self, forKey: .promesse)
        mandats = try c.decodeIfPresent(Int.self, forKey: .mandats) ?? 0
        electionAge = try c.decodeIfPresent(Int.self, forKey: .electionAge)
        collesAnnee = try c.decodeIfPresent(Int.self, forKey: .collesAnnee) ?? 0
        collesTotal = try c.decodeIfPresent(Int.self, forKey: .collesTotal) ?? 0
        convocations = try c.decodeIfPresent(Int.self, forKey: .convocations) ?? 0
        convoqueCetteAnnee = try c.decodeIfPresent(Bool.self, forKey: .convoqueCetteAnnee) ?? false
        bonusNotes = try c.decodeIfPresent(Double.self, forKey: .bonusNotes) ?? 0
        bulletins = try c.decodeIfPresent([ScolBulletin].self, forKey: .bulletins) ?? []
        brevet = try c.decodeIfPresent(Bool.self, forKey: .brevet)
        noteOralFrancais = try c.decodeIfPresent(Double.self, forKey: .noteOralFrancais)
        noteGrandOral = try c.decodeIfPresent(Double.self, forKey: .noteGrandOral)
        voyages = try c.decodeIfPresent([String].self, forKey: .voyages) ?? []
        scenesVues = try c.decodeIfPresent([String].self, forKey: .scenesVues) ?? []
        aFaire = try c.decodeIfPresent([ScolTache].self, forKey: .aFaire) ?? []
    }
}

/// Une chose qui attend le joueur dans l'écran « Vie au bahut ».
struct ScolTache: Codable, Equatable, Identifiable, Hashable {
    enum Sorte: String, Codable {
        case situation, convocation, voyage, oral
    }

    var sorte: Sorte
    /// Id de la scène ou du voyage, ou examen (`francais`, `grand_oral`) pour un oral.
    var ref: String

    var id: String { sorte.rawValue + ":" + ref }
}

// MARK: - Bulletin

struct ScolNote: Codable, Equatable, Identifiable {
    var id = UUID()
    var matiere: String
    var note: Double
    var appreciation: String
}

enum ScolMention: String, Codable, CaseIterable {
    case felicitations, compliments, encouragements, rien
    case avertissementTravail = "avertissement_travail"
    case avertissementConduite = "avertissement_conduite"

    var titre: String {
        switch self {
        case .felicitations: return "Félicitations"
        case .compliments: return "Compliments"
        case .encouragements: return "Encouragements"
        case .rien: return "Pas de mention"
        case .avertissementTravail: return "Avertissement travail"
        case .avertissementConduite: return "Avertissement conduite"
        }
    }

    var estPositive: Bool { self == .felicitations || self == .compliments || self == .encouragements }
    var estAvertissement: Bool { self == .avertissementTravail || self == .avertissementConduite }
}

struct ScolBulletin: Codable, Equatable, Identifiable {
    var id = UUID()
    var age: Int
    var classe: String
    var moyenne: Double
    var notes: [ScolNote]
    var appreciationGenerale: String
    var mention: ScolMention
    var motDuDelegue: String?
    var colles: Int
}

// MARK: - Effets

/// Sous-objet `"school"` des effets.
struct ScolEffets: Codable, Equatable {
    var popularity: Int?
    var teachers: Int?
    var detention: Int?
    var summonParents: Bool?
    var grades: Double?
    var joinGroup: String?
    var leaveGroup: Bool?
    var loseDelegate: Bool?
}

/// Effets complets d'une issue : ceux du moteur (`Effets`) et ceux de l'école.
struct ScolEffetsComplets: Decodable, Equatable {
    var moteur: Effets?
    var ecole: ScolEffets?

    private struct Enveloppe: Decodable {
        var school: ScolEffets?
    }

    init(moteur: Effets? = nil, ecole: ScolEffets? = nil) {
        self.moteur = moteur
        self.ecole = ecole
    }

    init(from decoder: Decoder) throws {
        moteur = try? Effets(from: decoder)
        ecole = (try? Enveloppe(from: decoder))?.school
    }
}

// MARK: - Données

struct ScolConditions: Decodable, Equatable {
    var gender: String?
    var tags: [String]?
    var excludeTags: [String]?
}

struct ScolIssue: Decodable, Equatable {
    var chance: Double?
    var text: String
    var effects: ScolEffetsComplets?
}

struct ScolChoix: Decodable, Equatable {
    var label: String
    var outcomes: [ScolIssue]
}

/// Situation, convocation ou scène de voyage : une carte à choix.
struct ScolScene: Decodable, Equatable, Identifiable {
    var id: String
    var minAge: Int?
    var maxAge: Int?
    var weight: Double?
    var unique: Bool?
    var conditions: ScolConditions?
    var text: String
    var choices: [ScolChoix]
}

struct ScolRequis: Decodable, Equatable {
    var stat: String
    var min: Int
}

struct ScolGroupe: Decodable, Equatable, Identifiable {
    var id: String
    var nom: String
    var icone: String
    var description: String
    var requis: ScolRequis?
    var accepte: String
    var refuse: String
    var quitte: String
    var parAn: ScolEffetsComplets?
}

struct ScolAction: Decodable, Equatable, Identifiable {
    var id: String
    var titre: String
    var icone: String
    var description: String
    var groupe: String?
    var minAge: Int
    var maxAge: Int
    var conditions: ScolConditions?
    var outcomes: [ScolIssue]
}

struct ScolVoyage: Decodable, Equatable, Identifiable {
    var id: String
    var destination: String
    var niveau: String
    var cout: Int
    var intro: String
    var retour: String
    var scenes: [ScolScene]
}

struct ScolReponse: Decodable, Equatable {
    var text: String
    var points: Int
    var reaction: String
}

struct ScolQuestion: Decodable, Equatable {
    var question: String
    var reponses: [ScolReponse]
}

struct ScolOral: Decodable, Equatable, Identifiable {
    var id: String
    var examen: String
    var sujet: String
    var intro: String
    var questions: [ScolQuestion]
}

struct ScolTexte: Decodable, Equatable {
    var type: String
    var text: String
    var matiere: String?
    var tranche: String?
    var trait: String?
    var mention: String?
    var id: String?
    var discours: String?
    var bonus: Int?
    var realiste: Bool?
    var bilan: String?
}

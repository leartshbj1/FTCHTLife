import Foundation

// Module « Testament et guerre d'héritage ».
// Voir docs/SUCCESSION.md pour le format des données et le branchement dans le moteur.

// MARK: - Testament

/// À qui va le patrimoine.
enum SuccessionBeneficiaire: String, Codable, CaseIterable, Identifiable {
    /// Partage égal entre les enfants (et le partenaire).
    case egal
    /// Tout à l'enfant préféré.
    case enfant
    /// Tout au partenaire.
    case partenaire
    /// Tout au chat.
    case chat
    /// Tout à une œuvre (absurde) de charité.
    case oeuvre
    /// Rien à personne : tout est brûlé, dépensé ou laissé à l'État.
    case personne
    /// Au premier inconnu qui viendra à l'enterrement.
    case inconnu
    /// Tout à un ami.
    case ami
    /// Pas de testament : partage selon la loi (et donc selon les avocats).
    case aucun

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .egal: return "Partage égal"
        case .enfant: return "Tout à l'enfant préféré"
        case .partenaire: return "Tout à l'amour de ma vie"
        case .chat: return "Tout au chat"
        case .oeuvre: return "Tout à une œuvre"
        case .personne: return "Rien à personne"
        case .inconnu: return "Au premier inconnu de l'enterrement"
        case .ami: return "Tout à un ami"
        case .aucun: return "Pas de testament"
        }
    }

    var icone: String {
        switch self {
        case .egal: return "equal.circle"
        case .enfant: return "star.circle"
        case .partenaire: return "heart.circle"
        case .chat: return "pawprint.circle"
        case .oeuvre: return "gift.circle"
        case .personne: return "flame.circle"
        case .inconnu: return "questionmark.circle"
        case .ami: return "person.2.circle"
        case .aucun: return "xmark.circle"
        }
    }

    /// Part de chaos que ce choix apporte à la famille (0 à 40).
    var drame: Int {
        switch self {
        case .egal: return 5
        case .aucun: return 15
        case .partenaire: return 18
        case .ami: return 28
        case .enfant: return 30
        case .oeuvre: return 30
        case .inconnu: return 35
        case .chat: return 38
        case .personne: return 40
        }
    }
}

/// Sur quoi le testament est écrit. Plus c'est fragile, plus on peut le contester.
enum SuccessionSupport: String, Codable, CaseIterable, Identifiable {
    case notaire, papier, serviette, video, tatouage, aucun

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .notaire: return "Chez le notaire"
        case .papier: return "À la main, sur papier"
        case .serviette: return "Sur une serviette de restaurant"
        case .video: return "En vidéo sur les réseaux"
        case .tatouage: return "Tatoué dans le dos"
        case .aucun: return "Nulle part"
        }
    }

    var detail: String {
        switch self {
        case .notaire: return "Solide, cher, et le notaire sent le cuir."
        case .papier: return "Classique. Ton écriture de médecin peut poser problème."
        case .serviette: return "Gratuit. Il y a une tache de sauce sur la clause 2."
        case .video: return "Tout le monde le verra. Absolument tout le monde."
        case .tatouage: return "Impossible à perdre. Difficile à modifier."
        case .aucun: return ""
        }
    }

    var cout: Int {
        switch self {
        case .notaire: return 1500
        case .tatouage: return 400
        default: return 0
        }
    }

    /// Solidité juridique, de 0 à 100.
    var solidite: Int {
        switch self {
        case .notaire: return 90
        case .papier: return 60
        case .tatouage: return 45
        case .video: return 35
        case .serviette: return 20
        case .aucun: return 0
        }
    }

    static var choisissables: [SuccessionSupport] { allCases.filter { $0 != .aucun } }
}

struct SuccessionTestament: Codable, Equatable {
    var beneficiaire: SuccessionBeneficiaire
    /// Relation choisie (enfant préféré ou ami).
    var beneficiaireId: UUID?
    var beneficiairePrenom: String?
    var oeuvreId: String?
    var support: SuccessionSupport
    /// Ids des clauses (Data/Succession/Clauses).
    var clauses: [String] = []
    /// Gardé secret (pas annoncé à la famille).
    var secret: Bool = true
    var redigeA: Int
    /// Nombre de fois où il a été réécrit.
    var versions: Int = 1
}

/// Une clause absurde ajoutée au testament.
struct SuccessionClause: Codable, Identifiable, Equatable {
    var id: String
    var texte: String
    /// Ajout de tension dans la famille (0 à 3).
    var drame: Int?
    /// Réaction de la famille quand on l'annonce (journal).
    var reaction: String?
}

/// Une œuvre de charité (absurde).
struct SuccessionOeuvre: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
}

/// Un bien du défunt (maison, voiture…) fourni par la boutique, pour les textes et le calcul.
struct SuccessionBien: Codable, Equatable {
    var nom: String
    var valeur: Int
}

// MARK: - Dossier de succession

/// Place de l'héritier (le joueur) dans le testament.
enum SuccessionRole: String, Codable {
    /// Seul héritier (enfant unique, pas de partenaire).
    case seul
    /// Désigné comme héritier unique alors qu'il y avait d'autres prétendants.
    case favori
    /// Partage avec la fratrie.
    case egal
    /// Le testament donne tout à quelqu'un (ou quelque chose) d'autre.
    case desherite
}

/// Quelqu'un qui veut sa part.
struct SuccessionRival: Codable, Equatable, Identifiable {
    var id = UUID()
    var prenom: String
    var genre: Genre
    /// « cousin », « tante », « frère »…
    var role: String
    /// 0 à 100.
    var hostilite: Int
    /// Vraie relation du joueur (frère ou sœur), si c'en est une.
    var relationId: UUID?
    /// Désignation toute faite (« le nouveau compagnon de ta mère, Gérard »), sinon construite avec `role`.
    var libre: String?

    /// « ton cousin Gérard ».
    var designation: String {
        if let libre { return libre }
        let voyelle = ["a", "e", "é", "i", "o", "u", "h"].contains { role.lowercased().hasPrefix($0) }
        let det = (genre == .femme && !voyelle) ? "ta" : "ton"
        return "\(det) \(role) \(prenom)"
    }
}

struct SuccessionDossier: Codable, Equatable, Identifiable {
    var id = UUID()
    var defuntPrenom: String
    var defuntNom: String
    var defuntGenre: Genre
    /// « mere », « pere » ou « autre » : lien du défunt avec l'héritier.
    var lien: String
    var ageDeces: Int
    /// Argent + biens. Négatif = dettes.
    var patrimoine: Int
    var bien: String
    var testament: SuccessionTestament
    var role: SuccessionRole
    /// Part du joueur, versée à l'ouverture.
    var part: Int
    /// Ambiance familiale, de 0 (calme) à 100 (guerre totale).
    var tension: Int
    var rivaux: [SuccessionRival]
    /// Frères et sœurs qui héritent aussi (prénoms).
    var coheritiers: [String]
    var chat: String
    var notaire: String
    var oeuvre: String
    /// Prénom (ou nom) de celui qui touche tout, s'il y en a un.
    var beneficiaireNom: String
    var flags: [String] = []
    var vus: [String] = []
    /// Résumé lisible de ce qui s'est passé.
    var historique: [String] = []
    /// Ce que le joueur a réellement touché (ou perdu) dans cette affaire.
    var bilan: Int = 0
    var ouvert: Bool = true

    var rivalPrincipal: SuccessionRival? { rivaux.max { $0.hostilite < $1.hostilite } }
    var dettes: Bool { patrimoine < 0 }

    /// « ta mère », « ton père », « ton grand-oncle Marcel ».
    var leDefunt: String {
        switch lien {
        case "mere": return "ta mère"
        case "pere": return "ton père"
        default: return (defuntGenre == .femme ? "ta tante " : "ton oncle ") + defuntPrenom
        }
    }
}

/// Une étape programmée de la guerre d'héritage.
struct SuccessionProgramme: Codable, Equatable {
    var dossierId: UUID
    var age: Int
    /// Phase à tirer (« ouverture », « guerre ») ou épisode précis (`episodeId`).
    var phase: String
    var episodeId: String?
}

/// État sauvegardé dans le joueur : son propre testament et les successions dont il hérite.
struct SuccessionEtat: Codable, Equatable {
    var testament: SuccessionTestament?
    var dossiers: [SuccessionDossier] = []
    var programme: [SuccessionProgramme] = []
    /// Épisodes `unique` déjà vus dans cette vie.
    var vus: [String] = []
    /// Lien vers l'épisode en cours : id d'événement → dossier.
    var enCours: [String: UUID] = [:]

    var dossiersOuverts: [SuccessionDossier] { dossiers.filter { $0.ouvert } }
}

// MARK: - Données JSON

struct SuccessionConditions: Codable, Equatable {
    var roles: [String]?
    var beneficiaires: [String]?
    var supports: [String]?
    /// Lien du défunt : « mere », « pere », « autre ».
    var liens: [String]?
    var minTension: Int?
    var maxTension: Int?
    var minPatrimoine: Int?
    var maxPatrimoine: Int?
    var dettes: Bool?
    /// Le joueur a des frères et sœurs cohéritiers.
    var fratrie: Bool?
    /// Le défunt avait écrit un testament.
    var testament: Bool?
    /// Au moins une de ces clauses est dans le testament.
    var clauses: [String]?
    var flags: [String]?
    var excludeFlags: [String]?
    /// Âge du joueur.
    var minAge: Int?
    var maxAge: Int?
    /// Hostilité du rival principal.
    var minHostilite: Int?
    var maxHostilite: Int?
    /// Chroniques seulement : le défunt avait des enfants.
    var enfants: Bool?
}

struct SuccessionEffets: Codable, Equatable {
    var happiness: Int?
    var health: Int?
    var smarts: Int?
    var looks: Int?
    var karma: Int?
    var money: Int?
    /// Pourcentage du patrimoine (positif) gagné ou perdu.
    var moneyPct: Double?
    var relationships: [String: Int]?
    /// Variation de l'hostilité du rival principal.
    var rival: Int?
    var death: String?
}

struct SuccessionIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    var effects: SuccessionEffets?
    /// Épisodes de phase « suite » à programmer.
    var next: [String]?
    /// [min, max] années avant la suite (défaut [1, 2]).
    var delay: [Int]?
    var setFlags: [String]?
    var clearFlags: [String]?
    /// Ferme le dossier (la guerre est finie).
    var close: Bool?
}

struct SuccessionChoix: Codable, Equatable {
    var label: String
    var outcomes: [SuccessionIssue]
}

struct SuccessionEpisode: Codable, Identifiable, Equatable {
    var id: String
    /// « ouverture », « guerre » ou « suite ».
    var phase: String
    var weight: Double?
    /// Une seule fois par vie (défaut : une fois par dossier).
    var unique: Bool?
    var conditions: SuccessionConditions?
    var text: String
    var effects: SuccessionEffets?
    var next: [String]?
    var delay: [Int]?
    var setFlags: [String]?
    var close: Bool?
    var choices: [SuccessionChoix]?
}

/// Une ligne racontant ce qui s'est passé après la mort du joueur.
struct SuccessionChronique: Codable, Identifiable, Equatable {
    var id: String
    var weight: Double?
    var conditions: SuccessionConditions?
    var text: String
}

/// Ce que coûte et provoque la rédaction d'un testament.
struct SuccessionRedaction: Equatable {
    var cout: Int
    /// Variation du lien par relation.
    var liens: [UUID: Int]
    var bonheur: Int
    var karma: Int
    var lignes: [String]
}

// MARK: - Lecture du testament (mort du joueur)

/// Un proche qui peut hériter.
struct SuccessionProche: Codable, Equatable {
    var prenom: String
    var genre: Genre
    var id: UUID?
}

/// Une ligne du partage.
struct SuccessionPart: Codable, Equatable, Identifiable {
    var id = UUID()
    /// « Kevin (fils) », « le chat Moustache », « l'État »…
    var libelle: String
    var relationId: UUID?
    var montant: Int
}

/// Ce que lit le notaire à la mort du joueur. À garder pour l'écran de mort et le passer à l'héritier (générations).
struct SuccessionLecture: Codable, Equatable {
    var defuntPrenom: String
    var defuntNom: String
    var defuntGenre: Genre
    var ageDeces: Int
    var karma: Int
    var patrimoine: Int
    var bien: String
    var testament: SuccessionTestament
    var enfants: [SuccessionProche]
    var partenaire: SuccessionProche?
    var parts: [SuccessionPart]
    var tension: Int
    /// Le prétendant inventé qui surgira (cousin, tante…).
    var cousin: SuccessionRival
    var chat: String
    var notaire: String
    var oeuvre: String
    var beneficiaireNom: String
}

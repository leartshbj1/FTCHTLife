import Foundation

// Journal du monde : chaque année un flash info absurde, dont certains modifient l'économie
// (prix, salaires, marchés, fréquence des événements…) pendant une ou plusieurs années.
// Format des données : docs/MONDE_FORMAT.md. Branchement dans le moteur : docs/MONDE_INTEGRATION.md.

/// Multiplicateurs appliqués au monde tant qu'un flash est actif (1.0 = aucun changement).
struct MondeModificateurs: Codable, Equatable {
    /// Catégorie de prix -> multiplicateur. Clé "tout" = toutes les catégories.
    var prix: [String: Double]?
    /// Secteur d'activité -> multiplicateur de salaire. Clé "tout" = tous les secteurs.
    var salaires: [String: Double]?
    var evenements: MondeModifEvenements?
    /// Marchés financiers (bourse, crypto, or, immobilier_locatif, epargne, bourse_<secteur>).
    var marches: [String: Double]?
    /// Multiplie la chance de mourir chaque année.
    var mortalite: Double?
    /// Multiplie la pension de retraite.
    var retraite: Double?
}

struct MondeModifEvenements: Codable, Equatable {
    /// Catégorie d'événement (champ `category`) -> multiplicateur de poids.
    var categories: [String: Double]?
    /// Début d'id d'événement (ex. "tra_") -> multiplicateur de poids.
    var prefixes: [String: Double]?
}

/// Effet appliqué au joueur (une fois ou chaque année), éventuellement réservé à certains joueurs.
struct MondeEffetJoueur: Codable, Equatable {
    /// Tags joueur requis (voir GameEngine.tags), tous obligatoires.
    var tags: [String]?
    var excludeTags: [String]?
    /// Ligne écrite dans le journal de l'année quand l'effet s'applique.
    var text: String?
    var effects: Effets
}

/// Un flash info du journal du monde (un élément des fichiers Data/Monde/*.json).
struct MondeFlash: Codable, Identifiable, Equatable {
    var id: String
    /// economie, politique, science, insolite, meteo, sport, people, sante, tech, international.
    var rubrique: String
    var titre: String
    var texte: String
    var poids: Double?
    /// Années pendant lesquelles les effets durent. 0 = flash pour rire.
    var duree: Int?
    /// Par défaut un flash ne sort qu'une fois par vie.
    var unique: Bool?
    var minAge: Int?
    var maxAge: Int?
    var requiertTagsMonde: [String]?
    var excluTagsMonde: [String]?
    /// Ne sort jamais au hasard : seulement en suite d'un autre flash ou via MondeJournal.forcer.
    var suiteSeulement: Bool?
    var modificateurs: MondeModificateurs?
    var effetsImmediats: [MondeEffetJoueur]?
    var effetsAnnuels: [MondeEffetJoueur]?
    /// Événements qui ne peuvent arriver que pendant ce flash.
    var evenements: [Evenement]?
    var tagsMonde: [String]?
    var texteFin: String?
    var suites: [String]?
    var chanceSuite: Double?

    var dureeEffets: Int { max(0, duree ?? 0) }
    var estUnique: Bool { unique ?? true }

    var emojiRubrique: String {
        switch rubrique {
        case "economie": return "💶"
        case "politique": return "🏛️"
        case "science": return "🔬"
        case "insolite": return "🦆"
        case "meteo": return "🌦️"
        case "sport": return "🏆"
        case "people": return "📸"
        case "sante": return "🩺"
        case "tech": return "📱"
        case "international": return "🌍"
        default: return "📰"
        }
    }

    var nomRubrique: String {
        switch rubrique {
        case "economie": return "Économie"
        case "politique": return "Politique"
        case "science": return "Science"
        case "insolite": return "Insolite"
        case "meteo": return "Météo"
        case "sport": return "Sport"
        case "people": return "People"
        case "sante": return "Santé"
        case "tech": return "Tech"
        case "international": return "International"
        default: return "Actualité"
        }
    }
}

/// Un flash dont les effets sont en cours.
struct MondeFlashActif: Codable, Equatable {
    var id: String
    var anneesRestantes: Int
    /// Âge du joueur l'année de publication.
    var ageDebut: Int
}

/// Une une publiée, pour les archives du journal.
struct MondeUne: Codable, Equatable, Identifiable {
    var id: String
    var age: Int
}

/// État du monde à sauvegarder avec le joueur (champ optionnel `monde` de Joueur).
struct MondeEtat: Codable, Equatable {
    var actifs: [MondeFlashActif] = []
    /// Toutes les unes publiées pendant la vie, de la plus ancienne à la plus récente.
    var archives: [MondeUne] = []
    /// Suites programmées pour l'année prochaine.
    var suitesEnAttente: [String] = []

    init() {}

    var derniereUne: MondeUne? { archives.last }
    var idsActifs: Set<String> { Set(actifs.map(\.id)) }
}

/// Ce qui s'est passé dans le monde lors d'un passage d'année.
struct MondeRapport {
    /// Le flash publié cette année (nil si rien de neuf).
    var flash: MondeFlash?
    /// Lignes à écrire dans le journal de l'année (une, fins de crises, effets ressentis).
    var lignes: [String] = []
    /// Effets à appliquer au joueur avec GameEngine.appliquer (déjà filtrés par tags).
    var effets: [Effets] = []
}

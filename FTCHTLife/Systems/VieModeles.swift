import Foundation

// Module amour / crime / santé / générations.
// Format des données : docs/donnees-vie-sociale.md.

// MARK: - Effets en plus des effets du moteur (sous-objet "vie" des effets)

struct VieEffets: Codable, Equatable {
    /// Envoie en prison (ou rallonge / réduit la peine si négatif et déjà en prison).
    var jailMonths: Int?
    /// Amende en euros.
    var fine: Int?
    /// 1 = ajoute une ligne au casier judiciaire.
    var record: Int?
    /// Id d'une maladie (Data/Health).
    var disease: String?
    /// Guérit une maladie au hasard.
    var cure: Bool?
    /// Rupture (ou divorce) avec le/la partenaire.
    var breakup: Bool?
    /// Démarre une relation avec quelqu'un de nouveau (si célibataire).
    var newPartner: Bool?
    /// Grossesse (joueuse ou partenaire).
    var pregnancy: Bool?
    /// Id d'une addiction (Data/HealthAddictions).
    var addiction: String?
    /// Clé de relation ("partner", "child", "friend", "parent", "sibling", "ex") : cette personne meurt.
    var targetDies: String?

    // Le Milieu (VieMilieu.swift)
    var milieuRespect: Int?
    var milieuChaleur: Int?
    var milieuLoyaute: Int?
    /// Argent sale gagné (ou perdu), à blanchir.
    var argentSale: Int?
    /// true ouvre une enquête de police, false la classe.
    var enquete: Bool?
    var quitterMilieu: Bool?
    var promotion: Bool?
    /// Le stock du trafic est saisi.
    var saisie: Bool?
}

// MARK: - État sauvegardé du module (champ `vie` de Joueur)

enum VieStatutCouple: String, Codable, Equatable {
    case fiance, marie
}

enum VieRoleProche: String, Codable, Equatable {
    case grandParent, petitEnfant, codetenu, ennemi

    func libelle(_ genre: Genre) -> String {
        let f = genre == .femme
        switch self {
        case .grandParent: return f ? "Grand-mère" : "Grand-père"
        case .petitEnfant: return f ? "Petite-fille" : "Petit-fils"
        case .codetenu: return f ? "Codétenue" : "Codétenu"
        case .ennemi: return f ? "Ennemie" : "Ennemi"
        }
    }
}

/// Personnes que le moteur ne connaît pas (grands-parents, petits-enfants, codétenus, ennemis).
struct VieProche: Codable, Identifiable, Equatable {
    var id = UUID()
    var prenom: String
    var nom: String
    var genre: Genre
    var role: VieRoleProche
    var age: Int
    var lien: Int
    var argent: Int = 0
    var vivant = true

    var nomComplet: String { "\(prenom) \(nom)" }
}

struct VieCasierLigne: Codable, Equatable {
    var age: Int
    var crime: String
    var mois: Int
}

/// Arrestation en attente de jugement.
struct VieProces: Codable, Equatable {
    var crimeId: String
    var crimeNom: String
    var moisMin: Int
    var moisMax: Int
    var amendeMin: Int
    var amendeMax: Int
}

struct VieJustice: Codable, Equatable {
    var casier: [VieCasierLigne] = []
    var moisRestants = 0
    var moisPurges = 0
    var crimes = 0
    var evasions = 0
    var notoriete = 0
    var comportement = 50
    var prison: String?
    var proces: VieProces?
    var actionsPrisonAnnee: [String] = []

    var enPrison: Bool { moisRestants > 0 }
}

struct VieMaladie: Codable, Equatable, Identifiable {
    var id: String
    var depuisAge: Int
    var traitee = false
}

struct VieSante: Codable, Equatable {
    var maladies: [VieMaladie] = []
    var addictions: [String] = []
    var gueries = 0
    var visitesAnnee = 0

    func a(_ id: String) -> Bool { maladies.contains { $0.id == id } }
}

struct VieEtat: Codable, Equatable {
    // Couple
    var statutCouple: VieStatutCouple?
    var anneesEnsemble = 0
    var mariages = 0
    var divorces = 0
    var rendezVousAnnee = 0
    // Bébé en route : mois restants, prénom de l'autre parent.
    var grossesse: Int?
    var autreParent: String?
    // Amis
    var meilleurAmiId: UUID?
    // Personnes en plus
    var proches: [VieProche] = []
    // Justice, santé
    var justice = VieJustice()
    var sante = VieSante()
    // Petits messages d'étapes déjà annoncés (id de l'étape + id de la personne)
    var etapesVues: [String] = []
    // Générations
    var generation = 1
    var ancetres: [String] = []
    // Crime organisé (nil tant que le joueur n'y a pas touché)
    var milieu: VieMilieuEtat?

    var codetenus: [VieProche] { proches.filter { $0.vivant && $0.role == .codetenu } }
    var grandsParents: [VieProche] { proches.filter { $0.vivant && $0.role == .grandParent } }
    var petitsEnfants: [VieProche] { proches.filter { $0.vivant && $0.role == .petitEnfant } }
}

extension Joueur {
    /// État du module. Passe par `VieSysteme.acces` (= \.vie, branché par le moteur).
    var vieEtat: VieEtat {
        get {
            guard let k = VieSysteme.acces else { return VieEtat() }
            return self[keyPath: k] ?? VieEtat()
        }
        set {
            guard let k = VieSysteme.acces else { return }
            self[keyPath: k] = newValue
        }
    }

    var partenaireActuel: Relation? { relations.first { $0.type == .partenaire && $0.vivant } }
    var enfantsVivants: [Relation] { relations.filter { $0.type == .enfant && $0.vivant } }
    var parentsVivants: [Relation] { relations.filter { $0.type.estParent && $0.vivant } }
    var fratrieVivante: [Relation] { relations.filter { ($0.type == .frere || $0.type == .soeur) && $0.vivant } }
    var exVivants: [Relation] { relations.filter { $0.type == .ex && $0.vivant } }

    /// « marié », « fiancée »… selon le genre du joueur.
    var statutCoupleTexte: String {
        guard partenaireActuel != nil else { return g("Célibataire", "Célibataire") }
        switch vieEtat.statutCouple {
        case .marie: return g("Marié", "Mariée")
        case .fiance: return g("Fiancé", "Fiancée")
        case nil: return "En couple"
        }
    }
}

// MARK: - Petits outils

enum VieHasard {
    static func reussi(_ chance: Double) -> Bool { Double.random(in: 0..<1) < chance }
    static func borne(_ c: Double) -> Double { min(0.98, max(0.02, c)) }

    /// Chance de mourir dans l'année pour un proche âgé (santé moyenne).
    static func chanceDeces(age: Int) -> Double {
        guard age >= 50 else { return 0.0005 }
        return min(0.95, pow(Double(age - 50) / 50, 4) * 0.6)
    }
}

extension Array where Element == String {
    func auHasard(_ defaut: String) -> String { randomElement() ?? defaut }
}

extension Relation {
    /// « il » / « elle ».
    var pronom: String { genre == .femme ? "elle" : "il" }
    /// Accord simple : « mort » / « morte ».
    func a(_ masculin: String, _ feminin: String) -> String { genre == .femme ? feminin : masculin }
}

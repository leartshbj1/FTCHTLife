import Foundation

// Animaux de compagnie : modèle et données.
// Format des données et branchement dans le moteur : docs/ANIMAUX.md.
// Données : FTCHTLife/Resources/Data/Animaux/{Especes,Caracteres,Evenements}/*.json.

/// Une espèce adoptable (chat, chien, perroquet…).
struct AnimalEspece: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    /// "le", "la" ou "l'".
    var article: String
    var emoji: String
    /// "commun" (refuge, animalerie) ou "exotique" (vendeur spécialisé, 18 ans et plus).
    var categorie: String
    /// Prix à l'animalerie ou chez le vendeur exotique.
    var prix: Int
    /// Frais d'adoption au refuge (espèces communes).
    var prixRefuge: Int?
    /// Coût d'entretien par an.
    var entretien: Int
    /// [début de la vieillesse, âge maximal ordinaire].
    var esperanceVie: [Int]
    var promenable: Bool?
    /// Verbe au présent : "miaule", "aboie"…
    var cri: String
    var ageMinJoueur: Int?
    var description: String
    var noms: [String]
    /// Caractères possibles (nil = tous).
    var caracteres: [String]?

    var exotique: Bool { categorie == "exotique" }
    var feminin: Bool { article == "la" }
    var nomMinuscule: String { nom.lowercased() }
    /// « le chat », « la chèvre », « l'iguane ».
    var avecArticle: String { article == "l'" ? "l'" + nomMinuscule : article + " " + nomMinuscule }
    /// « ton chat », « ta chèvre », « ton iguane ».
    var avecPossessif: String { (feminin ? "ta " : "ton ") + nomMinuscule }
    var debutVieillesse: Int { esperanceVie.first ?? 10 }
    var ageMax: Int { esperanceVie.last ?? 15 }
}

/// Un trait de caractère (peureux, voleur, jaloux, génie…).
struct AnimalCaractere: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var emoji: String
    var description: String
    var poids: Double?
}

/// Un animal du joueur.
struct Animal: Codable, Identifiable, Equatable {
    var id = UUID()
    var nom: String
    var especeId: String
    var caractereId: String
    var femelle: Bool
    var age: Int
    /// Lien avec le joueur, 0-100.
    var lien: Int
    /// Santé de l'animal, 0-100.
    var sante: Int
    /// Maladie en cours (phrase courte), nil = en bonne santé.
    var maladie: String?
    /// Âge du joueur à l'adoption.
    var adopteA: Int
    /// Pourquoi il n'est plus là (rempli quand il quitte le foyer).
    var depart: String?
    /// Âge du joueur au départ.
    var departA: Int?
    var mort: Bool = false
    /// Actions déjà faites cette année ("caresser", "jouer"…).
    var actionsAnnee: [String] = []
    /// Événements uniques déjà vécus par cet animal.
    var evenementsVus: [String] = []

    var espece: AnimalEspece? { Animaux.espece(especeId) }
    var caractere: AnimalCaractere? { Animaux.caractere(caractereId) }
    var emoji: String { espece?.emoji ?? "🐾" }
    var nomEspece: String { espece?.nom ?? "Animal" }
    func accord(_ masculin: String, _ feminin: String) -> String { femelle ? feminin : masculin }
}

/// Un événement d'animal à choix, en attente d'une réponse du joueur. Stocké dans la sauvegarde.
struct AnimalEvenementEnAttente: Codable, Identifiable, Equatable {
    var id = UUID()
    var evenementId: String
    var animalId: UUID
    var texte: String
    var resultat: String?
}

/// État des animaux d'une vie, à stocker dans `Joueur` (champ optionnel `animaux`).
struct AnimauxEtat: Codable, Equatable {
    /// Animaux présents au foyer.
    var animaux: [Animal] = []
    /// Animaux morts, partis ou abandonnés.
    var disparus: [Animal] = []
    /// Événements à choix en attente.
    var enAttente: [AnimalEvenementEnAttente] = []

    init() {}

    var coutAnnuel: Int { animaux.reduce(0) { $0 + ($1.espece?.entretien ?? 300) } }
}

// MARK: - Événements d'animaux

/// Effets d'un événement sur l'animal concerné.
struct AnimalEffets: Codable, Equatable {
    var bond: Int?
    var health: Int?
    var sick: String?
    var cure: Bool?
    var death: String?
    var runaway: Bool?
    var newPet: String?
    var trait: String?
}

struct AnimalIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    var effects: Effets?
    var pet: AnimalEffets?
}

struct AnimalChoix: Codable, Equatable {
    var label: String
    var outcomes: [AnimalIssue]
}

struct AnimalEvenement: Codable, Identifiable, Equatable {
    var id: String
    var especes: [String]?
    var caracteres: [String]?
    var minAgeAnimal: Int?
    var maxAgeAnimal: Int?
    /// Âge du joueur.
    var minAge: Int?
    var maxAge: Int?
    var minLien: Int?
    var maxLien: Int?
    var malade: Bool?
    var vieux: Bool?
    var weight: Double?
    var unique: Bool?
    var conditions: ConditionsEvenement?
    var text: String
    var effects: Effets?
    var pet: AnimalEffets?
    var choices: [AnimalChoix]?

    /// Version « événement du moteur », pour vérifier l'âge du joueur et les conditions avec `conditionsRemplies`.
    var commeEvenement: Evenement {
        Evenement(id: id, category: "animaux", minAge: minAge ?? 0, maxAge: maxAge ?? 200, weight: weight,
                  unique: nil, conditions: conditions, text: text, effects: nil, choices: nil)
    }
}

// MARK: - Données

enum Animaux {
    static let especes: [AnimalEspece] = DonneesJSON.chargerTableaux(dossier: "Animaux/Especes", type: AnimalEspece.self)
    static let caracteres: [AnimalCaractere] = DonneesJSON.chargerTableaux(dossier: "Animaux/Caracteres", type: AnimalCaractere.self)
    static let evenements: [AnimalEvenement] = DonneesJSON.chargerTableaux(dossier: "Animaux/Evenements", type: AnimalEvenement.self)

    private static let especesParId: [String: AnimalEspece] = Dictionary(especes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    private static let caracteresParId: [String: AnimalCaractere] = Dictionary(caracteres.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    private static let evenementsParId: [String: AnimalEvenement] = Dictionary(evenements.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func espece(_ id: String) -> AnimalEspece? { especesParId[id] }
    static func caractere(_ id: String) -> AnimalCaractere? { caracteresParId[id] }
    static func evenement(_ id: String) -> AnimalEvenement? { evenementsParId[id] }

    /// Nombre maximal d'animaux au foyer.
    static let maxAnimaux = 8
    /// Âge minimal du joueur pour avoir un animal.
    static let ageMinimal = 3

    static let nomsDeSecours = ["Truc", "Bidule", "Machin", "Chouchou", "Patate", "Loulou"]

    /// Maladies tirées au hasard pendant l'année.
    static let maladies = [
        "une otite carabinée", "des vers (beurk)", "une indigestion de chaussettes", "une crise de foie",
        "un rhume des foins", "une dépression saisonnière", "une allergie au lundi", "des puces olympiques",
        "une infection mystérieuse", "une rage de dents", "une conjonctivite", "un surpoids alarmant",
        "une crise existentielle", "des rhumatismes",
    ]

    /// Fins de phrase pour une mort de vieillesse (« … est mort/morte … »).
    static let mortsDeVieillesse = [
        "de vieillesse, en boule sur ton oreiller",
        "paisiblement, au soleil, à l'endroit exact où il ne fallait pas",
        "de vieillesse, en rêvant visiblement de nourriture",
        "dans son sommeil, après un dernier ronflement légendaire",
        "de vieillesse, au milieu de tous ses jouets volés",
    ]

    /// « de la grippe », « d'une otite », « de vers » : complément de « mort… ».
    static func deMaladie(_ m: String) -> String {
        if m.hasPrefix("une ") || m.hasPrefix("un ") { return "d'" + m }
        if m.hasPrefix("des ") { return "de " + m.dropFirst(4) }
        if m.hasPrefix("le ") { return "du " + m.dropFirst(3) }
        if m.hasPrefix("les ") { return "des " + m.dropFirst(4) }
        if let c = m.first, "aeéèêiouyh".contains(c) { return "d'" + m }
        return "de " + m
    }

    /// Tire un élément au hasard selon son poids.
    static func tirer<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0.0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.randomElement() }
        var r = Double.random(in: 0..<total)
        for element in liste {
            r -= max(0, poids(element))
            if r < 0 { return element }
        }
        return liste.last
    }

    /// Crée un animal d'une espèce, caractère tiré au hasard sauf s'il est donné.
    static func nouvelAnimal(_ espece: AnimalEspece, age: Int = 0, ageJoueur: Int,
                             caractere: String? = nil, nom: String? = nil) -> Animal {
        let possibles = caracteres.filter { espece.caracteres?.contains($0.id) ?? true }
        let car = caractere ?? tirer(possibles, poids: { $0.poids ?? 1 })?.id ?? "calin"
        let nomChoisi = (nom?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        return Animal(nom: nomChoisi ?? espece.noms.randomElement() ?? nomsDeSecours.randomElement()!,
                      especeId: espece.id, caractereId: car, femelle: Bool.random(), age: age,
                      lien: Int.random(in: 45...70), sante: Int.random(in: 75...100), maladie: nil,
                      adopteA: ageJoueur)
    }

    /// Chance de mourir dans l'année.
    static func chanceDeces(_ a: Animal) -> Double {
        guard let e = a.espece else { return 0.05 }
        let base: Double
        if a.age < e.debutVieillesse {
            base = 0.005
        } else if a.age <= e.ageMax {
            let span = Double(max(1, e.ageMax - e.debutVieillesse))
            base = 0.08 + 0.5 * Double(a.age - e.debutVieillesse) / span
        } else {
            base = 0.75
        }
        let facteurSante = 1.6 - Double(a.sante) / 100
        return min(0.95, base * facteurSante)
    }
}

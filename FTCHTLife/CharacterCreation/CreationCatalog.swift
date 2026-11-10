import Foundation

struct Country: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let flag: String
    let currency: String
    let cities: [String]
    let maleNames: [String]
    let femaleNames: [String]
    let lastNames: [String]

    func randomFirstName<G: RandomNumberGenerator>(for gender: Gender, using rng: inout G) -> String {
        switch gender {
        case .male: return maleNames.randomElement(using: &rng) ?? "Jean"
        case .female: return femaleNames.randomElement(using: &rng) ?? "Marie"
        case .nonBinary: return (maleNames + femaleNames).randomElement(using: &rng) ?? "Camille"
        }
    }
}

/// Trait de caractère choisi à la création. Le moteur peut lire `id` pour
/// moduler les événements (ex. « hypocondriaque » rend les visites chez le médecin plus fréquentes).
struct Trait: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let description: String
    let modifiers: StatModifiers
    /// Traits incompatibles (on ne peut pas être « Flemmard » et « Bourreau de travail »).
    let excludes: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decode(String.self, forKey: .emoji)
        description = try c.decode(String.self, forKey: .description)
        modifiers = try c.decodeIfPresent(StatModifiers.self, forKey: .modifiers) ?? StatModifiers()
        excludes = try c.decodeIfPresent([String].self, forKey: .excludes) ?? []
    }

    init(id: String, name: String, emoji: String, description: String, modifiers: StatModifiers = .init(), excludes: [String] = []) {
        self.id = id; self.name = name; self.emoji = emoji; self.description = description
        self.modifiers = modifiers; self.excludes = excludes
    }
}

/// Talent inné : un seul par personnage. Le moteur s'en sert pour les carrières
/// (bonus de réussite dans les métiers liés `careerTags`).
struct Talent: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let description: String
    let modifiers: StatModifiers
    let careerTags: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decode(String.self, forKey: .emoji)
        description = try c.decode(String.self, forKey: .description)
        modifiers = try c.decodeIfPresent(StatModifiers.self, forKey: .modifiers) ?? StatModifiers()
        careerTags = try c.decodeIfPresent([String].self, forKey: .careerTags) ?? []
    }

    init(id: String, name: String, emoji: String, description: String, modifiers: StatModifiers = .init(), careerTags: [String] = []) {
        self.id = id; self.name = name; self.emoji = emoji; self.description = description
        self.modifiers = modifiers; self.careerTags = careerTags
    }
}

/// Données de l'écran de création, chargées depuis `creation_data.json`.
struct CreationCatalog: Codable {
    let countries: [Country]
    let traits: [Trait]
    let talents: [Talent]

    func country(_ id: String) -> Country? { countries.first { $0.id == id } }
    func trait(_ id: String) -> Trait? { traits.first { $0.id == id } }
    func talent(_ id: String) -> Talent? { talents.first { $0.id == id } }

    /// Vrai si `id` est incompatible avec un des traits déjà choisis.
    func conflicts(_ id: String, with chosen: [String]) -> Bool {
        guard let t = trait(id) else { return false }
        return chosen.contains { other in
            t.excludes.contains(other) || (trait(other)?.excludes.contains(id) ?? false)
        }
    }

    static let shared: CreationCatalog = load()

    static func load(bundle: Bundle = .main) -> CreationCatalog {
        guard
            let url = bundle.url(forResource: "creation_data", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(CreationCatalog.self, from: data),
            !catalog.countries.isEmpty
        else {
            return fallback
        }
        return catalog
    }

    /// Filet de sécurité si le JSON manque du bundle.
    static let fallback = CreationCatalog(
        countries: [
            Country(id: "fr", name: "France", flag: "🇫🇷", currency: "€",
                    cities: ["Paris", "Lyon", "Marseille"],
                    maleNames: ["Lucas", "Hugo", "Karim"],
                    femaleNames: ["Léa", "Chloé", "Inès"],
                    lastNames: ["Martin", "Bernard", "Petit"])
        ],
        traits: [
            Trait(id: "optimist", name: "Optimiste", emoji: "🌞", description: "Le verre est à moitié plein. De quoi, on ne sait pas.",
                  modifiers: StatModifiers(happiness: 10))
        ],
        talents: [
            Talent(id: "none", name: "Aucun", emoji: "🥔", description: "Tu es une patate. Une patate libre.")
        ]
    )
}

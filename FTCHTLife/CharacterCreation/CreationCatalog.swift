import Foundation

struct CreationCountry: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let flag: String
    let currency: String
    let cities: [String]
    let maleNames: [String]
    let femaleNames: [String]
    let lastNames: [String]

    func randomFirstName<G: RandomNumberGenerator>(for gender: CreationGender, using rng: inout G) -> String {
        switch gender {
        case .male: return maleNames.randomElement(using: &rng) ?? "Jean"
        case .female: return femaleNames.randomElement(using: &rng) ?? "Marie"
        case .nonBinary: return (maleNames + femaleNames).randomElement(using: &rng) ?? "Camille"
        }
    }
}

/// CreationTrait de caractère choisi à la création. Le moteur peut lire `id` pour
/// moduler les événements (ex. « hypocondriaque » rend les visites chez le médecin plus fréquentes).
struct CreationTrait: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let description: String
    let modifiers: CreationStatModifiers
    /// Traits incompatibles (on ne peut pas être « Flemmard » et « Bourreau de travail »).
    let excludes: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decode(String.self, forKey: .emoji)
        description = try c.decode(String.self, forKey: .description)
        modifiers = try c.decodeIfPresent(CreationStatModifiers.self, forKey: .modifiers) ?? CreationStatModifiers()
        excludes = try c.decodeIfPresent([String].self, forKey: .excludes) ?? []
    }

    init(id: String, name: String, emoji: String, description: String, modifiers: CreationStatModifiers = .init(), excludes: [String] = []) {
        self.id = id; self.name = name; self.emoji = emoji; self.description = description
        self.modifiers = modifiers; self.excludes = excludes
    }
}

/// CreationTalent inné : un seul par personnage. Le moteur s'en sert pour les carrières
/// (bonus de réussite dans les métiers liés `careerTags`).
struct CreationTalent: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let description: String
    let modifiers: CreationStatModifiers
    let careerTags: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decode(String.self, forKey: .emoji)
        description = try c.decode(String.self, forKey: .description)
        modifiers = try c.decodeIfPresent(CreationStatModifiers.self, forKey: .modifiers) ?? CreationStatModifiers()
        careerTags = try c.decodeIfPresent([String].self, forKey: .careerTags) ?? []
    }

    init(id: String, name: String, emoji: String, description: String, modifiers: CreationStatModifiers = .init(), careerTags: [String] = []) {
        self.id = id; self.name = name; self.emoji = emoji; self.description = description
        self.modifiers = modifiers; self.careerTags = careerTags
    }
}

/// Données de l'écran de création, chargées depuis `creation_data.json`.
struct CreationCatalog: Codable {
    let countries: [CreationCountry]
    let traits: [CreationTrait]
    let talents: [CreationTalent]

    func country(_ id: String) -> CreationCountry? { countries.first { $0.id == id } }
    func trait(_ id: String) -> CreationTrait? { traits.first { $0.id == id } }
    func talent(_ id: String) -> CreationTalent? { talents.first { $0.id == id } }

    /// Vrai si `id` est incompatible avec un des traits déjà choisis.
    func conflicts(_ id: String, with chosen: [String]) -> Bool {
        guard let t = trait(id) else { return false }
        return chosen.contains { other in
            t.excludes.contains(other) || (trait(other)?.excludes.contains(id) ?? false)
        }
    }

    static let shared: CreationCatalog = load()

    /// Chemin dans le bundle : Data/Creation/creation_data.json (voir docs/ARCHITECTURE.md).
    static func load() -> CreationCatalog {
        guard
            let url = DonneesJSON.dossierData?
                .appendingPathComponent("Creation", isDirectory: true)
                .appendingPathComponent("creation_data.json"),
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
            CreationCountry(id: "fr", name: "France", flag: "🇫🇷", currency: "€",
                    cities: ["Paris", "Lyon", "Marseille"],
                    maleNames: ["Lucas", "Hugo", "Karim"],
                    femaleNames: ["Léa", "Chloé", "Inès"],
                    lastNames: ["Martin", "Bernard", "Petit"])
        ],
        traits: [
            CreationTrait(id: "optimist", name: "Optimiste", emoji: "🌞", description: "Le verre est à moitié plein. De quoi, on ne sait pas.",
                  modifiers: CreationStatModifiers(happiness: 10))
        ],
        talents: [
            CreationTalent(id: "none", name: "Aucun", emoji: "🥔", description: "Tu es une patate. Une patate libre.")
        ]
    )
}

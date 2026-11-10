import SwiftUI

// MARK: - Genre

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female, nonBinary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: return "Homme"
        case .female: return "Femme"
        case .nonBinary: return "Non-binaire"
        }
    }

    var symbol: String {
        switch self {
        case .male: return "♂"
        case .female: return "♀"
        case .nonBinary: return "⚧"
        }
    }
}

// MARK: - Apparence

enum SkinTone: String, Codable, CaseIterable, Identifiable {
    case porcelain, light, beige, tan, brown, deep
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .porcelain: return Color(red: 0.98, green: 0.88, blue: 0.80)
        case .light: return Color(red: 0.95, green: 0.80, blue: 0.68)
        case .beige: return Color(red: 0.87, green: 0.68, blue: 0.52)
        case .tan: return Color(red: 0.76, green: 0.55, blue: 0.38)
        case .brown: return Color(red: 0.55, green: 0.36, blue: 0.24)
        case .deep: return Color(red: 0.36, green: 0.23, blue: 0.16)
        }
    }
}

enum HairStyle: String, Codable, CaseIterable, Identifiable {
    case bald, buzz, short, curly, long, bun, mohawk, afro
    var id: String { rawValue }

    var label: String {
        switch self {
        case .bald: return "Chauve"
        case .buzz: return "Rasé"
        case .short: return "Court"
        case .curly: return "Bouclé"
        case .long: return "Long"
        case .bun: return "Chignon"
        case .mohawk: return "Crête"
        case .afro: return "Afro"
        }
    }
}

enum HairColor: String, Codable, CaseIterable, Identifiable {
    case black, brown, chestnut, blond, red, grey, blue, pink
    var id: String { rawValue }

    var label: String {
        switch self {
        case .black: return "Noir"
        case .brown: return "Brun"
        case .chestnut: return "Châtain"
        case .blond: return "Blond"
        case .red: return "Roux"
        case .grey: return "Gris"
        case .blue: return "Bleu"
        case .pink: return "Rose"
        }
    }

    var color: Color {
        switch self {
        case .black: return Color(red: 0.10, green: 0.09, blue: 0.09)
        case .brown: return Color(red: 0.28, green: 0.17, blue: 0.10)
        case .chestnut: return Color(red: 0.50, green: 0.32, blue: 0.18)
        case .blond: return Color(red: 0.93, green: 0.78, blue: 0.42)
        case .red: return Color(red: 0.78, green: 0.33, blue: 0.14)
        case .grey: return Color(red: 0.70, green: 0.70, blue: 0.72)
        case .blue: return Color(red: 0.25, green: 0.48, blue: 0.90)
        case .pink: return Color(red: 0.95, green: 0.50, blue: 0.70)
        }
    }

    /// Couleurs « fantaisie » : un bébé ne naît pas avec les cheveux bleus.
    var isNatural: Bool { self != .blue && self != .pink }
}

enum EyeColor: String, Codable, CaseIterable, Identifiable {
    case brown, hazel, green, blue, grey
    var id: String { rawValue }

    var label: String {
        switch self {
        case .brown: return "Marron"
        case .hazel: return "Noisette"
        case .green: return "Vert"
        case .blue: return "Bleu"
        case .grey: return "Gris"
        }
    }

    var color: Color {
        switch self {
        case .brown: return Color(red: 0.35, green: 0.20, blue: 0.10)
        case .hazel: return Color(red: 0.55, green: 0.42, blue: 0.20)
        case .green: return Color(red: 0.25, green: 0.55, blue: 0.30)
        case .blue: return Color(red: 0.25, green: 0.50, blue: 0.85)
        case .grey: return Color(red: 0.50, green: 0.55, blue: 0.60)
        }
    }
}

struct Appearance: Codable, Equatable {
    var skin: SkinTone
    var hairStyle: HairStyle
    var hairColor: HairColor
    var eyes: EyeColor
    var hasFreckles: Bool
    var hasGlasses: Bool

    static func random<G: RandomNumberGenerator>(using rng: inout G) -> Appearance {
        Appearance(
            skin: SkinTone.allCases.randomElement(using: &rng)!,
            hairStyle: HairStyle.allCases.filter { $0 != .bald }.randomElement(using: &rng)!,
            hairColor: HairColor.allCases.filter(\.isNatural).randomElement(using: &rng)!,
            eyes: EyeColor.allCases.randomElement(using: &rng)!,
            hasFreckles: Int.random(in: 0..<5, using: &rng) == 0,
            hasGlasses: Int.random(in: 0..<6, using: &rng) == 0
        )
    }
}

// MARK: - Milieu familial

enum FamilyWealth: String, Codable, CaseIterable, Identifiable {
    case broke, modest, comfortable, rich, filthyRich
    var id: String { rawValue }

    var label: String {
        switch self {
        case .broke: return "Fauchée"
        case .modest: return "Modeste"
        case .comfortable: return "Aisée"
        case .rich: return "Riche"
        case .filthyRich: return "Indécemment riche"
        }
    }

    var blurb: String {
        switch self {
        case .broke: return "Le frigo sert surtout d'étagère."
        case .modest: return "On ne manque de rien, sauf de vacances."
        case .comfortable: return "Deux voitures et un abonnement à la salle jamais utilisé."
        case .rich: return "Ta nounou a une nounou."
        case .filthyRich: return "Ton doudou est assuré chez Lloyd's."
        }
    }

    /// Argent des parents à la naissance, en unité de base (€).
    var familyMoney: Int {
        switch self {
        case .broke: return 300
        case .modest: return 8_000
        case .comfortable: return 60_000
        case .rich: return 750_000
        case .filthyRich: return 25_000_000
        }
    }
}

// MARK: - Stats de départ

struct StartingStats: Codable, Equatable {
    var health: Int
    var happiness: Int
    var smarts: Int
    var looks: Int

    static func clamp(_ v: Int) -> Int { min(100, max(0, v)) }

    mutating func apply(_ m: StatModifiers) {
        health = Self.clamp(health + m.health)
        happiness = Self.clamp(happiness + m.happiness)
        smarts = Self.clamp(smarts + m.smarts)
        looks = Self.clamp(looks + m.looks)
    }
}

struct StatModifiers: Codable, Equatable {
    var health: Int = 0
    var happiness: Int = 0
    var smarts: Int = 0
    var looks: Int = 0

    init(health: Int = 0, happiness: Int = 0, smarts: Int = 0, looks: Int = 0) {
        self.health = health; self.happiness = happiness; self.smarts = smarts; self.looks = looks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        health = try c.decodeIfPresent(Int.self, forKey: .health) ?? 0
        happiness = try c.decodeIfPresent(Int.self, forKey: .happiness) ?? 0
        smarts = try c.decodeIfPresent(Int.self, forKey: .smarts) ?? 0
        looks = try c.decodeIfPresent(Int.self, forKey: .looks) ?? 0
    }
}

// MARK: - Brouillon de personnage

/// Résultat de l'écran de création. Le moteur le convertit en personnage jouable.
struct CharacterDraft: Codable, Equatable {
    var firstName: String
    var lastName: String
    var gender: Gender
    var countryID: String
    var city: String
    var birthYear: Int
    var appearance: Appearance
    var wealth: FamilyWealth
    var traitIDs: [String]
    var talentID: String?
    /// Stats « tirées à la naissance », avant les bonus des traits/talent.
    var baseStats: StartingStats

    static let maxTraits = 2

    var fullName: String { "\(firstName) \(lastName)" }

    /// Stats finales = base + traits + talent.
    func finalStats(catalog: CreationCatalog) -> StartingStats {
        var s = baseStats
        for id in traitIDs {
            if let t = catalog.trait(id) { s.apply(t.modifiers) }
        }
        if let id = talentID, let t = catalog.talent(id) { s.apply(t.modifiers) }
        return s
    }

    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && !countryID.isEmpty && !city.isEmpty
            && traitIDs.count <= Self.maxTraits
    }

    static func randomStats<G: RandomNumberGenerator>(using rng: inout G) -> StartingStats {
        // Somme de deux dés : on est plus souvent moyen que génie.
        func roll() -> Int { Int.random(in: 10...55, using: &rng) + Int.random(in: 10...45, using: &rng) }
        return StartingStats(health: StartingStats.clamp(roll() + 10), happiness: roll(), smarts: roll(), looks: roll())
    }

    static func random<G: RandomNumberGenerator>(catalog: CreationCatalog, using rng: inout G) -> CharacterDraft {
        let gender: Gender = Int.random(in: 0..<20, using: &rng) == 0
            ? .nonBinary
            : (Bool.random(using: &rng) ? .male : .female)
        let country = catalog.countries.randomElement(using: &rng) ?? CreationCatalog.fallback.countries[0]
        let wealthRoll = Int.random(in: 0..<100, using: &rng)
        let wealth: FamilyWealth
        switch wealthRoll {
        case ..<15: wealth = .broke
        case ..<55: wealth = .modest
        case ..<85: wealth = .comfortable
        case ..<98: wealth = .rich
        default: wealth = .filthyRich
        }
        let traitCount = Int.random(in: 0...maxTraits, using: &rng)
        var traits: [String] = []
        for t in catalog.traits.shuffled(using: &rng) where traits.count < traitCount {
            if !catalog.conflicts(t.id, with: traits) { traits.append(t.id) }
        }
        return CharacterDraft(
            firstName: country.randomFirstName(for: gender, using: &rng),
            lastName: country.lastNames.randomElement(using: &rng) ?? "Dupont",
            gender: gender,
            countryID: country.id,
            city: country.cities.randomElement(using: &rng) ?? country.name,
            birthYear: Calendar.current.component(.year, from: Date()),
            appearance: .random(using: &rng),
            wealth: wealth,
            traitIDs: traits,
            talentID: catalog.talents.randomElement(using: &rng)?.id,
            baseStats: randomStats(using: &rng)
        )
    }

    static func random(catalog: CreationCatalog) -> CharacterDraft {
        var rng = SystemRandomNumberGenerator()
        return random(catalog: catalog, using: &rng)
    }
}

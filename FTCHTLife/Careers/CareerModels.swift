import Foundation

// MARK: - Études

/// Niveau d'études, du plus bas au plus haut.
/// `cap` est une voie pro : il est atteint avec un CAP ou avec un niveau ≥ bac.
enum CareerEducation: String, Codable, CaseIterable, Comparable {
    case noDiploma = "none", brevet, cap, bac, licence, master, doctorat

    var rank: Int {
        switch self {
        case .noDiploma: return 0
        case .brevet: return 1
        case .cap: return 2
        case .bac: return 3
        case .licence: return 4
        case .master: return 5
        case .doctorat: return 6
        }
    }

    static func < (lhs: CareerEducation, rhs: CareerEducation) -> Bool { lhs.rank < rhs.rank }

    /// Vrai si ce niveau (celui du perso) satisfait le niveau `required`.
    func satisfies(_ required: CareerEducation) -> Bool {
        if required == .cap { return self == .cap || self >= .bac }
        if self == .cap { return required <= .brevet || required == .cap }
        return self >= required
    }

    var label: String {
        switch self {
        case .noDiploma: return "Aucun diplôme"
        case .brevet: return "Brevet"
        case .cap: return "CAP"
        case .bac: return "Bac"
        case .licence: return "Licence"
        case .master: return "Master"
        case .doctorat: return "Doctorat"
        }
    }
}

struct CareerMajor: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let level: CareerEducation
}

// MARK: - Métiers

enum CareerKind: String, Codable, CaseIterable {
    case standard, partTime, freelance, special, illegal, military

    var label: String {
        switch self {
        case .standard: return "Temps plein"
        case .partTime: return "Petit boulot"
        case .freelance: return "Indépendant"
        case .special: return "Carrière spéciale"
        case .illegal: return "Carrière illégale"
        case .military: return "Armée"
        }
    }
}

enum CareerSkill: String, Codable {
    case smarts, looks, health, talent, charisma, athleticism
}

struct CareerRequirements: Codable, Hashable {
    var education: CareerEducation = .noDiploma
    var majors: [String] = []
    var minAge: Int = 18
    var maxAge: Int?
    var minSmarts: Int = 0
    var minLooks: Int = 0
    var minHealth: Int = 0
    var requiresLicense: String?

    enum CodingKeys: String, CodingKey {
        case education, majors, minAge, maxAge, minSmarts, minLooks, minHealth, requiresLicense
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        education = try c.decodeIfPresent(CareerEducation.self, forKey: .education) ?? .noDiploma
        majors = try c.decodeIfPresent([String].self, forKey: .majors) ?? []
        minAge = try c.decodeIfPresent(Int.self, forKey: .minAge) ?? 18
        maxAge = try c.decodeIfPresent(Int.self, forKey: .maxAge)
        minSmarts = try c.decodeIfPresent(Int.self, forKey: .minSmarts) ?? 0
        minLooks = try c.decodeIfPresent(Int.self, forKey: .minLooks) ?? 0
        minHealth = try c.decodeIfPresent(Int.self, forKey: .minHealth) ?? 0
        requiresLicense = try c.decodeIfPresent(String.self, forKey: .requiresLicense)
    }
}

struct CareerStep: Codable, Hashable {
    let title: String
    let salary: Int
    let yearsToPromote: Int
}

struct CareerSpecial: Codable, Hashable {
    var fameGain: Int = 0
    var arrestRisk: Int = 0
    var skill: CareerSkill?
    var audition: Bool = false
    var incomeVariance: Double = 0

    enum CodingKeys: String, CodingKey { case fameGain, arrestRisk, skill, audition, incomeVariance }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fameGain = try c.decodeIfPresent(Int.self, forKey: .fameGain) ?? 0
        arrestRisk = try c.decodeIfPresent(Int.self, forKey: .arrestRisk) ?? 0
        skill = try c.decodeIfPresent(CareerSkill.self, forKey: .skill)
        audition = try c.decodeIfPresent(Bool.self, forKey: .audition) ?? false
        incomeVariance = try c.decodeIfPresent(Double.self, forKey: .incomeVariance) ?? 0
    }
}

struct CareerJob: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let sector: String
    let kind: CareerKind
    let description: String?
    let requirements: CareerRequirements
    let ladder: [CareerStep]
    let stress: Int
    let prestige: Int
    let hiringDifficulty: Int
    let special: CareerSpecial?

    var topLevel: Int { max(ladder.count - 1, 0) }
    func step(_ level: Int) -> CareerStep { ladder[min(max(level, 0), topLevel)] }
    var entrySalary: Int { ladder.first?.salary ?? 0 }
}

// MARK: - Événements de travail

struct CareerEventConditions: Codable, Hashable {
    var careers: [String] = []
    var sectors: [String] = []
    var kinds: [CareerKind] = []
    var minLevel: Int = 0
    var minYearsInJob: Int = 0

    enum CodingKeys: String, CodingKey { case careers, sectors, kinds, minLevel, minYearsInJob }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        careers = try c.decodeIfPresent([String].self, forKey: .careers) ?? []
        sectors = try c.decodeIfPresent([String].self, forKey: .sectors) ?? []
        kinds = try c.decodeIfPresent([CareerKind].self, forKey: .kinds) ?? []
        minLevel = try c.decodeIfPresent(Int.self, forKey: .minLevel) ?? 0
        minYearsInJob = try c.decodeIfPresent(Int.self, forKey: .minYearsInJob) ?? 0
    }
}

/// Effets d'un résultat. Toutes les valeurs sont facultatives.
struct CareerEffects: Codable, Hashable {
    var happiness: Int?
    var health: Int?
    var smarts: Int?
    var looks: Int?
    var karma: Int?
    var fame: Int?
    var money: Int?
    var performance: Int?
    var bossRelation: Int?
    var coworkerRelation: Int?
    var salaryMultiplier: Double?
    var promoted: Bool?
    var fired: Bool?
    var quit: Bool?
    var arrested: Bool?
    var injured: Bool?
}

struct CareerEventOutcome: Codable, Hashable {
    let chance: Int
    let text: String
    let effects: CareerEffects?
}

struct CareerEventChoice: Codable, Hashable {
    let label: String
    let outcomes: [CareerEventOutcome]
}

struct CareerWorkEvent: Codable, Identifiable, Hashable {
    let id: String
    let conditions: CareerEventConditions?
    let weight: Int?
    let text: String
    let choices: [CareerEventChoice]
}

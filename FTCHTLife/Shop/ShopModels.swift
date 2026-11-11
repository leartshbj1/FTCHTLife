import Foundation

// MARK: - Catégories

enum ShopCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case realEstate, car, moto, boat, aircraft, jewelry, watch, art, fashion, gadget, collection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .realEstate: return "Immobilier"
        case .car: return "Voitures"
        case .moto: return "Deux-roues"
        case .boat: return "Bateaux"
        case .aircraft: return "Avions"
        case .jewelry: return "Bijoux"
        case .watch: return "Montres"
        case .art: return "Art"
        case .fashion: return "Mode"
        case .gadget: return "Gadgets"
        case .collection: return "Collections"
        }
    }

    var icon: String {
        switch self {
        case .realEstate: return "house.fill"
        case .car: return "car.fill"
        case .moto: return "bicycle"
        case .boat: return "sailboat.fill"
        case .aircraft: return "airplane"
        case .jewelry: return "sparkles"
        case .watch: return "watch.analog"
        case .art: return "paintpalette.fill"
        case .fashion: return "tshirt.fill"
        case .gadget: return "iphone"
        case .collection: return "star.fill"
        }
    }

    /// Coût d'une remise à neuf complète, en part du prix neuf.
    var repairRate: Double {
        switch self {
        case .realEstate: return 0.25
        case .car, .moto: return 0.40
        case .boat, .aircraft: return 0.35
        case .fashion, .gadget: return 0.30
        case .art, .collection: return 0.20
        case .jewelry, .watch: return 0.10
        }
    }

    /// Prime d'assurance annuelle, en part de la valeur.
    var insuranceRate: Double {
        switch self {
        case .realEstate: return 0.004
        case .car, .moto: return 0.04
        case .boat, .aircraft: return 0.025
        case .jewelry, .watch, .art, .collection: return 0.012
        case .fashion, .gadget: return 0.05
        }
    }

    /// Influence de l'état (0 à 100) sur le prix de revente.
    func conditionFactor(_ condition: Int) -> Double {
        let c = Double(max(0, min(100, condition))) / 100
        switch self {
        case .realEstate: return 0.65 + 0.35 * c
        case .car, .moto, .boat, .aircraft: return 0.25 + 0.75 * c
        case .jewelry, .watch, .art, .collection: return 0.80 + 0.20 * c
        case .fashion, .gadget: return 0.10 + 0.90 * c
        }
    }

    /// Nom de la catégorie côté Journal du monde.
    var mondeKey: String {
        switch self {
        case .realEstate: return "immobilier"
        case .car, .moto: return "voitures"
        case .boat: return "bateaux"
        case .aircraft: return "avions"
        case .jewelry: return "bijoux"
        case .watch, .art, .collection: return "luxe"
        case .fashion: return "vetements"
        case .gadget: return "tech"
        }
    }

    var isVehicle: Bool { [.car, .moto, .boat, .aircraft].contains(self) }
    var isGiftable: Bool { [.jewelry, .watch, .fashion, .gadget, .art].contains(self) }
}

enum ShopFinancing: String, Codable {
    case none, carLoan, mortgage

    var years: Int { self == .mortgage ? 20 : 5 }
    var rate: Double { self == .mortgage ? 0.039 : 0.065 }
    var downPaymentShare: Double { self == .mortgage ? 0.20 : 0.10 }
}

// MARK: - Données du catalogue (JSON)

struct ShopItem: Codable, Identifiable, Hashable {
    let id: String
    let category: ShopCategory
    let subcategory: String
    let name: String
    let brand: String
    let description: String
    let icon: String
    let price: Int
    let minAge: Int
    let upkeep: Int
    let appreciation: Double
    let volatility: Double
    let wear: Int
    let happiness: Int
    let looks: Int
    let health: Int
    let prestige: Int
    let rentIncome: Int
    let financing: ShopFinancing
    let usedMarket: Bool
    let tags: [String]
    let city: String?
    /// Émoji affiché dans les listes (facultatif : sinon déduit de la catégorie, voir `LuxeEmoji`).
    let emoji: String?

    var displayName: String { brand.isEmpty ? name : "\(name)" }
    var emojiAffiche: String { emoji ?? LuxeEmoji.pour(self) }
}

struct ShopRental: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let rentPerYear: Int
    let happiness: Int
    let prestige: Int
    let city: String?
}

struct ShopEffects: Codable, Hashable {
    var money: Int?
    var happiness: Int?
    var health: Int?
    var looks: Int?
    var smarts: Int?
    var karma: Int?
    var condition: Int?
    var valuePct: Double?
    var destroy: Bool?
    var stolen: Bool?
    /// Mondanité / célébrité (voir `ShopActor.mondanite`).
    var fame: Int?

}

struct ShopOutcome: Codable, Hashable {
    let weight: Int
    let text: String
    let effects: ShopEffects?
}

struct ShopTrip: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let destination: String
    let description: String
    let icon: String
    let price: Int
    let minAge: Int
    let happiness: Int
    let health: Int
    let outcomes: [ShopOutcome]
}

enum ShopEventScope: String, Codable { case item, owner, trip }

struct ShopEventChoice: Codable, Hashable {
    let label: String
    let outcomes: [ShopOutcome]
}

struct ShopEventDef: Codable, Identifiable, Hashable {
    let id: String
    let scope: ShopEventScope
    let categories: [ShopCategory]?
    let subcategories: [String]?
    let tags: [String]?
    let chance: Double
    let minAge: Int?
    let minPrestige: Int?
    let maxCondition: Int?
    let text: String
    let choices: [ShopEventChoice]
}

// MARK: - Ce que possède le perso (sauvegardé)

struct ShopLoan: Codable, Hashable {
    var principal: Int
    var remaining: Int
    var rate: Double
    var yearsLeft: Int
    var yearlyPayment: Int
    var missedPayments: Int = 0

    static func make(amount: Int, financing: ShopFinancing) -> ShopLoan {
        let r = financing.rate
        let n = Double(financing.years)
        let payment = Double(amount) * r / (1 - pow(1 + r, -n))
        return ShopLoan(principal: amount, remaining: amount, rate: r,
                    yearsLeft: financing.years, yearlyPayment: Int(payment.rounded(.up)))
    }
}

struct ShopOwnedItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let catalogId: String
    var nickname: String?
    var purchasePrice: Int
    var value: Int
    var condition: Int
    var yearsOwned: Int = 0
    var isRentedOut: Bool = false
    var isInsured: Bool = false
    var loan: ShopLoan?
}

struct ShopListing: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let catalogId: String
    let price: Int
    let condition: Int
    let isUsed: Bool
    /// Petite annonce rigolote affichée sous l'offre d'occasion.
    let pitch: String?
}

enum ShopResidence: Codable, Hashable {
    case parents
    case rental(id: String)
    case owned(id: UUID)
}

struct ShopTravelRecord: Codable, Hashable {
    let tripId: String
    let age: Int
}

/// Tout l'état boutique d'un perso. À stocker dans l'état du personnage.
struct Possessions: Codable, Hashable {
    var items: [ShopOwnedItem] = []
    var residence: ShopResidence = .parents
    var creditScore: Int = 650
    var market: [ShopListing] = []
    var marketAge: Int = -1
    var travels: [ShopTravelRecord] = []
    var totalSpent: Int = 0
    /// Événements tirés au passage d'année, en attente d'un choix du joueur.
    var pendingEvents: [PendingShopEvent] = []
    /// Vie de luxe : spa, soirées VIP, dons, société secrète (nil tant que rien n'a été fait).
    var luxe: LuxeEtat?

    init() {}

    // Décodage tolérant : une vieille sauvegarde sans certains champs reste lisible.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([ShopOwnedItem].self, forKey: .items) ?? []
        residence = try c.decodeIfPresent(ShopResidence.self, forKey: .residence) ?? .parents
        creditScore = try c.decodeIfPresent(Int.self, forKey: .creditScore) ?? 650
        market = try c.decodeIfPresent([ShopListing].self, forKey: .market) ?? []
        marketAge = try c.decodeIfPresent(Int.self, forKey: .marketAge) ?? -1
        travels = try c.decodeIfPresent([ShopTravelRecord].self, forKey: .travels) ?? []
        totalSpent = try c.decodeIfPresent(Int.self, forKey: .totalSpent) ?? 0
        pendingEvents = try c.decodeIfPresent([PendingShopEvent].self, forKey: .pendingEvents) ?? []
        luxe = try c.decodeIfPresent(LuxeEtat.self, forKey: .luxe)
    }

    var debt: Int { items.compactMap { $0.loan?.remaining }.reduce(0, +) }
    var assetsValue: Int { items.map(\.value).reduce(0, +) }
    var netWorthOfAssets: Int { assetsValue - debt }
}

// MARK: - Interface avec le moteur principal

/// Le personnage du moteur principal se conforme à ce protocole pour utiliser la boutique.
protocol ShopActor {
    var firstName: String { get }
    var age: Int { get }
    var money: Int { get set }
    var happiness: Int { get set }
    var health: Int { get set }
    var looks: Int { get set }
    var smarts: Int { get set }
    var karma: Int { get set }
    var boutique: Possessions { get set }
    /// Célébrité mondaine, 0 à 100. Par défaut gardée dans `boutique.luxe` ;
    /// un module « célébrité » peut l'implémenter sur `Joueur` pour la brancher sur sa propre jauge.
    var mondanite: Int { get set }
}

extension ShopActor {
    var mondanite: Int {
        get { boutique.luxe?.mondanite ?? 0 }
        set {
            var l = boutique.luxe ?? LuxeEtat()
            l.mondanite = max(0, min(100, newValue))
            boutique.luxe = l
        }
    }
}

/// Un événement tiré pendant le passage d'année, en attente d'un choix du joueur.
struct PendingShopEvent: Codable, Identifiable, Hashable {
    var id = UUID()
    let def: ShopEventDef
    let itemId: UUID?
    let text: String
}

struct ShopResult: Hashable {
    var ok: Bool
    var message: String
}

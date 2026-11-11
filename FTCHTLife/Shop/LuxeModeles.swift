import Foundation

// Vie de luxe : concessions et joailliers (vitrines du catalogue), spa, soirées VIP,
// dons aux œuvres et sociétés secrètes. Données dans Data/Shop/luxe_*.json (voir docs/boutique-format.md, §7).

// MARK: - Maisons (concessions, joailliers)

enum LuxeMaisonType: String, Codable, CaseIterable, Identifiable {
    case auto, bateau, avion, joaillier

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .auto: return "Concessions automobiles"
        case .bateau: return "Chantiers navals"
        case .avion: return "Aviation privée"
        case .joaillier: return "Joailliers et horlogers"
        }
    }

    var sousTitre: String {
        switch self {
        case .auto: return "Supercars, limousines et bolides de collection"
        case .bateau: return "Yachts, vedettes, voiliers et sous-marins"
        case .avion: return "Jets privés, hélicoptères et hydravions"
        case .joaillier: return "Haute joaillerie, diadèmes et grandes complications"
        }
    }

    var emoji: String {
        switch self {
        case .auto: return "🏎️"
        case .bateau: return "🛥️"
        case .avion: return "🛩️"
        case .joaillier: return "💎"
        }
    }
}

/// Une vitrine : un concessionnaire ou un joaillier qui présente une partie du catalogue.
struct LuxeMaison: Codable, Identifiable, Hashable {
    let id: String
    let type: LuxeMaisonType
    let name: String
    let emoji: String
    let description: String
    /// Phrase du vendeur à l'entrée.
    let accueil: String
    let categories: [ShopCategory]
    /// Vide = toutes les sous-catégories des catégories.
    let subcategories: [String]?
    /// Prix minimum des pièces exposées.
    let minPrice: Int?
    /// Marques exposées en plus (peu importe le prix).
    let brands: [String]?
    /// Accès sur rendez-vous : patrimoine minimum (argent + biens − crédits).
    let minPatrimoine: Int?
    /// Accès sur rendez-vous : mondanité minimum.
    let minMondanite: Int?
}

// MARK: - Services (spa, soirées VIP)

enum LuxeServiceType: String, Codable {
    case spa, vip
}

struct LuxeService: Codable, Identifiable, Hashable {
    let id: String
    let type: LuxeServiceType
    let name: String
    let emoji: String
    let description: String
    let price: Int
    let minAge: Int
    let minPatrimoine: Int?
    let minMondanite: Int?
    /// Effets sûrs, appliqués à chaque fois.
    let effects: ShopEffects?
    /// Un résultat tiré au hasard en plus.
    let outcomes: [ShopOutcome]
}

// MARK: - Œuvres de charité

struct LuxeOeuvre: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let cause: String
    let description: String
    /// Remerciements possibles (un au hasard). {amount} = montant donné.
    let merci: [String]
    /// Hommage quand on a donné au moins 1 M€ à cette œuvre.
    let hommage: String
}

// MARK: - Sociétés secrètes

struct LuxeRang: Codable, Hashable {
    let titre: String
    /// Prix de la cérémonie pour atteindre ce rang (0 pour le premier).
    let cout: Int
    /// Années minimum passées au rang précédent.
    let anneesMin: Int
    /// Coup de pouce du réseau : somme moyenne par an (versée une année sur deux environ).
    let reseau: Int
}

struct LuxeRituel: Codable, Hashable, Identifiable {
    let id: String
    let text: String
    let choices: [ShopEventChoice]
}

struct LuxeSociete: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let devise: String
    let description: String
    let minAge: Int
    let minPatrimoine: Int
    let minMondanite: Int
    let droitEntree: Int
    let cotisation: Int
    let rangs: [LuxeRang]
    let rituels: [LuxeRituel]
}

// MARK: - État sauvegardé

struct LuxeMembre: Codable, Hashable {
    var societeId: String
    var rang: Int = 0
    var annees: Int = 0
    var anneesAuRang: Int = 0
    /// Âge auquel le perso a assisté à la dernière réunion.
    var derniereReunion: Int = -1
}

struct LuxeEtat: Codable, Hashable {
    /// Âge auquel `faitsCetteAnnee` s'applique (tout se remet à zéro à l'anniversaire suivant).
    var annee: Int = -1
    /// Services faits et œuvres déjà remerciées cette année.
    var faitsCetteAnnee: [String] = []
    var mondanite: Int = 0
    var donsTotal: Int = 0
    var donsParOeuvre: [String: Int] = [:]
    var societe: LuxeMembre?
    /// Sociétés quittées ou qui t'ont chassé : plus jamais de cooptation.
    var bannies: [String] = []
    var spaTotal: Int = 0
    var soireesTotal: Int = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        annee = try c.decodeIfPresent(Int.self, forKey: .annee) ?? -1
        faitsCetteAnnee = try c.decodeIfPresent([String].self, forKey: .faitsCetteAnnee) ?? []
        mondanite = try c.decodeIfPresent(Int.self, forKey: .mondanite) ?? 0
        donsTotal = try c.decodeIfPresent(Int.self, forKey: .donsTotal) ?? 0
        donsParOeuvre = try c.decodeIfPresent([String: Int].self, forKey: .donsParOeuvre) ?? [:]
        societe = try c.decodeIfPresent(LuxeMembre.self, forKey: .societe)
        bannies = try c.decodeIfPresent([String].self, forKey: .bannies) ?? []
        spaTotal = try c.decodeIfPresent(Int.self, forKey: .spaTotal) ?? 0
        soireesTotal = try c.decodeIfPresent(Int.self, forKey: .soireesTotal) ?? 0
    }
}

// MARK: - Chargement des données

final class LuxeCatalogue: @unchecked Sendable {
    static let shared = LuxeCatalogue()

    let maisons: [LuxeMaison]
    let services: [LuxeService]
    let oeuvres: [LuxeOeuvre]
    let societes: [LuxeSociete]

    init(bundle: Bundle = .main) {
        let urls = ShopCatalog.jsonURLs(in: bundle)
        func load<T: Decodable>(_ type: T.Type, _ nom: String) -> [T] {
            guard let url = urls.first(where: { $0.deletingPathExtension().lastPathComponent == nom }) else { return [] }
            do {
                return try JSONDecoder().decode([T].self, from: Data(contentsOf: url))
            } catch {
                #if DEBUG
                print("[Luxe] Fichier illisible \(url.lastPathComponent): \(error)")
                #endif
                return []
            }
        }
        maisons = load(LuxeMaison.self, "luxe_maisons")
        services = load(LuxeService.self, "luxe_services")
        oeuvres = load(LuxeOeuvre.self, "luxe_oeuvres")
        societes = load(LuxeSociete.self, "luxe_societes")
    }

    func maisons(_ type: LuxeMaisonType) -> [LuxeMaison] { maisons.filter { $0.type == type } }
    func services(_ type: LuxeServiceType) -> [LuxeService] {
        services.filter { $0.type == type }.sorted { $0.price < $1.price }
    }
    func societe(_ id: String) -> LuxeSociete? { societes.first { $0.id == id } }
    func oeuvre(_ id: String) -> LuxeOeuvre? { oeuvres.first { $0.id == id } }

    /// Les pièces exposées par une maison, de la moins chère à la plus chère.
    func vitrine(_ m: LuxeMaison) -> [ShopItem] {
        let subs = Set(m.subcategories ?? [])
        let brands = Set(m.brands ?? [])
        return ShopCatalog.shared.items.filter { item in
            if brands.contains(item.brand) { return true }
            guard m.categories.contains(item.category) else { return false }
            if !subs.isEmpty && !subs.contains(item.subcategory) { return false }
            return item.price >= (m.minPrice ?? 0)
        }
        .sorted { $0.price < $1.price }
    }
}

// MARK: - Émojis des biens

enum LuxeEmoji {
    static func pour(_ item: ShopItem) -> String {
        let s = item.subcategory
        switch item.category {
        case .car:
            switch s {
            case "supercar", "hypercar", "sportive": return "🏎️"
            case "suv", "4x4": return "🚙"
            case "pickup": return "🛻"
            case "limousine": return "🚘"
            case "monospace": return "🚐"
            case "epave": return "🚗"
            case "electrique": return "🔋"
            case "collection", "cabriolet": return "🚘"
            case "insolite": return "🚌"
            default: return "🚗"
            }
        case .moto:
            switch s {
            case "velo": return "🚲"
            case "scooter", "mobylette": return "🛵"
            case "trottinette": return "🛴"
            case "jetpack": return "🚀"
            case "quad", "motoneige": return "🛷"
            default: return "🏍️"
            }
        case .boat:
            switch s {
            case "yacht", "megayacht", "gigayacht", "vedette", "offshore", "horsbord", "semi-rigide": return "🛥️"
            case "voilier", "catamaran", "trimaran", "dériveur", "trois-mats", "pirate", "drakkar": return "⛵"
            case "kayak", "canoe", "pirogue", "barque", "gondole": return "🛶"
            case "ferry", "bateau-mouche", "peniche", "barge", "house-boat": return "⛴️"
            case "sousmarin", "bathyscaphe", "brise-glace", "chalutier", "remorqueur": return "🚢"
            case "scooter-mer": return "🌊"
            default: return "🚤"
            }
        case .aircraft:
            switch s {
            case "helicoptere", "autogire": return "🚁"
            case "montgolfiere", "dirigeable": return "🎈"
            case "parapente", "paramoteur", "deltaplane": return "🪂"
            case "navette", "jetpack": return "🚀"
            case "jet", "grosporteur", "chasse", "bombardier-eau": return "✈️"
            case "cerfvolant": return "🪁"
            case "drone": return "🛸"
            default: return "🛩️"
            }
        case .realEstate:
            switch s {
            case "studio", "appartement": return "🏢"
            case "loft", "penthouse": return "🌆"
            case "villa": return "🏡"
            case "manoir": return "🏛️"
            case "chateau": return "🏰"
            case "ferme": return "🌾"
            case "chalet": return "🏔️"
            case "ile": return "🏝️"
            case "insolite": return "🛖"
            default: return "🏠"
            }
        case .jewelry:
            switch s {
            case "bague", "alliance", "chevaliere": return "💍"
            case "diademe": return "👑"
            case "grillz": return "😬"
            case "collier", "pendentif": return "📿"
            default: return "💎"
            }
        case .watch: return "⌚"
        case .art:
            switch s {
            case "sculpture", "antiquite": return "🗿"
            case "photographie": return "📷"
            default: return "🖼️"
            }
        case .fashion:
            switch s {
            case "robe", "haute-couture", "defile": return "👗"
            case "chaussures", "bottes": return "👠"
            case "baskets": return "👟"
            case "sac", "maroquinerie": return "👜"
            case "manteau": return "🧥"
            case "costume", "cravate", "chemise": return "👔"
            case "lunettes": return "🕶️"
            case "chapeau", "casquette": return "🎩"
            case "chaussettes": return "🧦"
            case "echarpe", "gants": return "🧣"
            case "jean": return "👖"
            case "deguisement": return "🦸"
            case "maillot": return "🩱"
            default: return "👕"
            }
        case .gadget:
            switch s {
            case "telephone", "tablette": return "📱"
            case "ordinateur": return "💻"
            case "console": return "🎮"
            case "tv": return "📺"
            case "audio": return "🎧"
            case "robot", "domotique": return "🤖"
            case "appareil-photo": return "📷"
            case "drone": return "🛸"
            case "jouet": return "🧸"
            default: return "🔌"
            }
        case .collection:
            switch s {
            case "vin": return "🍷"
            case "dinosaure": return "🦖"
            case "meteorite": return "☄️"
            case "piece": return "🪙"
            case "timbre": return "✉️"
            case "cartes": return "🃏"
            case "bd": return "📚"
            case "vinyles": return "💿"
            case "jeux-video": return "👾"
            case "autographe": return "✍️"
            default: return "🏆"
            }
        }
    }

    static func categorie(_ c: ShopCategory) -> String {
        switch c {
        case .realEstate: return "🏡"
        case .car: return "🚗"
        case .moto: return "🏍️"
        case .boat: return "🛥️"
        case .aircraft: return "✈️"
        case .jewelry: return "💍"
        case .watch: return "⌚"
        case .art: return "🖼️"
        case .fashion: return "👗"
        case .gadget: return "📱"
        case .collection: return "🏆"
        }
    }
}

import Foundation

/// Charge une fois pour toutes les données JSON de la boutique depuis le bundle.
/// Dossier Data/Shop. Les fichiers sont reconnus par leur préfixe : catalog_*.json,
/// events_*.json, rentals.json et travel.json.
final class ShopCatalog: @unchecked Sendable {
    static let shared = ShopCatalog()

    let items: [ShopItem]
    let rentals: [ShopRental]
    let trips: [ShopTrip]
    let events: [ShopEventDef]
    private let itemsById: [String: ShopItem]
    private let rentalsById: [String: ShopRental]
    private let tripsById: [String: ShopTrip]

    init(bundle: Bundle = .main) {
        let urls = ShopCatalog.jsonURLs(in: bundle)
        func load<T: Decodable>(_ type: T.Type, where match: (String) -> Bool) -> [T] {
            urls.filter { match($0.deletingPathExtension().lastPathComponent) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .flatMap { url -> [T] in
                    do {
                        let data = try Data(contentsOf: url)
                        return try JSONDecoder().decode([T].self, from: data)
                    } catch {
                        #if DEBUG
                        print("[Boutique] Fichier illisible \(url.lastPathComponent): \(error)")
                        #endif
                        return []
                    }
                }
        }
        items = load(ShopItem.self) { $0.hasPrefix("catalog_") }
        rentals = load(ShopRental.self) { $0 == "rentals" }
        trips = load(ShopTrip.self) { $0 == "travel" }
        events = load(ShopEventDef.self) { $0.hasPrefix("events_") }
        itemsById = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        rentalsById = Dictionary(rentals.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        tripsById = Dictionary(trips.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    static func jsonURLs(in bundle: Bundle) -> [URL] {
        // Emplacement normal : Data/Shop copié tel quel dans l'app (voir docs/ARCHITECTURE.md).
        if let base = DonneesJSON.dossierData?.appendingPathComponent("Shop", isDirectory: true),
           let files = try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) {
            let json = files.filter { $0.pathExtension == "json" }
            if !json.isEmpty { return json }
        }
        // Secours : fichiers posés à plat dans le bundle.
        return bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
    }

    func item(_ id: String) -> ShopItem? { itemsById[id] }
    func rental(_ id: String) -> ShopRental? { rentalsById[id] }
    func trip(_ id: String) -> ShopTrip? { tripsById[id] }

    func items(in category: ShopCategory) -> [ShopItem] {
        items.filter { $0.category == category }.sorted { $0.price < $1.price }
    }

    func subcategories(in category: ShopCategory) -> [String] {
        var seen = Set<String>()
        return items(in: category).compactMap { seen.insert($0.subcategory).inserted ? $0.subcategory : nil }
    }
}

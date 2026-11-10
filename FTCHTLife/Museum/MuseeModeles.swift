import Foundation

// Nécrologie et musée des vies : voir docs/MUSEE.md.

/// Conditions d'un surnom ou d'une phrase de nécrologie.
struct NecroConditions: Codable, Equatable {
    var tags: [String]?
    var excludeTags: [String]?
    var minAge: Int?
    var maxAge: Int?
}

/// Un surnom absurde (Data/Museum/surnoms*.json).
struct NecroSurnom: Codable, Identifiable, Equatable {
    var id: String
    var text: String
    var textFemale: String?
    var weight: Double?
    var conditions: NecroConditions?
}

/// Une phrase de nécrologie (Data/Museum/necro_*.json).
struct NecroPhrase: Codable, Identifiable, Equatable {
    var id: String
    var section: String
    var text: String
    var textFemale: String?
    var weight: Double?
    var conditions: NecroConditions?
}

/// Une vie terminée, exposée au musée.
struct MuseeVie: Codable, Identifiable, Equatable {
    /// Identifiant stable de la vie (id de la première année du journal).
    var id: String
    var dateFin: Date
    var prenom: String
    var nom: String
    var genre: Genre
    var surnom: String
    var ville: String
    var age: Int
    var cause: String
    var dernierMetier: String?
    var fortune: Int
    var diplome: String
    var stats: Stats
    var nbAmis: Int
    var nbEnfants: Int
    var nbEx: Int
    var scoreVieReussie: Int?
    /// Manchette du journal.
    var titre: String
    /// Paragraphes de la nécrologie.
    var paragraphes: [String]
    var epitaphe: String
    /// Moments forts tirés du journal de la vie.
    var faitsMarquants: [String]

    var nomComplet: String { "\(prenom) \(nom)" }
    var nomAvecSurnom: String { "\(prenom) « \(surnom) » \(nom)" }
    var mort: String { genre == .femme ? "Morte" : "Mort" }
}

/// Tables de données chargées une fois.
enum NecroDonnees {
    static let surnoms: [NecroSurnom] = charger(prefixe: "surnoms", type: NecroSurnom.self)
    static let phrases: [NecroPhrase] = charger(prefixe: "necro_", type: NecroPhrase.self)

    /// Lit les fichiers de Data/Museum dont le nom commence par `prefixe` (chacun contient un tableau).
    static func charger<T: Decodable>(prefixe: String, type: T.Type) -> [T] {
        guard let base = DonneesJSON.dossierData?.appendingPathComponent("Museum", isDirectory: true),
              let fichiers = try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) else {
            return []
        }
        var resultat: [T] = []
        for url in fichiers.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where url.pathExtension == "json" && url.lastPathComponent.hasPrefix(prefixe) {
            do {
                resultat += try JSONDecoder().decode([T].self, from: Data(contentsOf: url))
            } catch {
                print("⚠️ Fichier du musée invalide \(url.lastPathComponent) : \(error)")
            }
        }
        return resultat
    }
}

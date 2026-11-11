import Foundation

// Format des événements : voir docs/ARCHITECTURE.md.
// Les fichiers sont dans FTCHTLife/Resources/Data/Events/<categorie>.json (un tableau d'événements par fichier).

/// Effets qu'un événement applique au joueur. Stats en points (delta), argent en euros.
struct Effets: Codable, Equatable {
    var happiness: Int?
    var health: Int?
    var smarts: Int?
    var looks: Int?
    var karma: Int?
    var money: Int?
    var stress: Int?
    var fame: Int?
    /// Variation du lien par type de relation : "mother", "father", "sibling", "friend", "partner", "child", "parent" (les deux parents).
    var relationships: [String: Int]?
    var newFriend: Bool?
    /// Si présent, le joueur meurt avec cette cause (ex. "écrasé par un distributeur de boissons").
    var death: String?
    /// Drapeaux (souvenirs) posés / retirés sur le joueur. Voir docs/REPERCUSSIONS.md.
    var setFlags: [String]?
    var clearFlags: [String]?
    /// Ids de suites (Data/Repercussions) à programmer.
    var followUps: [String]?
    /// XP gagnée (ou perdue) par compétence, ex. {"cuisine": 6}. Voir docs/COMPETENCES.md.
    var skills: [String: Int]?
    /// Module amour/crime/santé (prison, maladies, grossesse…). Voir FTCHTLife/Systems.
    var vie: VieEffets?
    /// Module casier judiciaire. Voir docs/CASIER.md.
    var casier: CasierEffet?
    /// Réputation de la famille. Voir docs/REPUTATION_FAMILLE.md.
    var familyRep: [String: Int]?
    /// Marques des rêves de vie. Voir docs/reves-format.md.
    var dreamMarks: [String]?
    /// Module entourage (fiançailles, mariage, offre d'emploi…). Voir docs/ENTOURAGE.md.
    var entourage: EntourageEffets?
    /// Module Beauté (réparer, soigner, calvitie, coupe ratée, opération offerte). Voir docs/BEAUTE.md.
    var beaute: BeauteEffets?
}

struct ConditionsEvenement: Codable, Equatable {
    /// "any", "male" ou "female".
    var gender: String?
    var minMoney: Int?
    var maxMoney: Int?
    var requiresJob: Bool?
    var requiresPartner: Bool?
    var requiresSchool: Bool?
    /// Tags que le joueur doit tous avoir (voir GameEngine.tags).
    var tags: [String]?
    /// Tags que le joueur ne doit pas avoir.
    var excludeTags: [String]?
    /// Drapeaux (souvenirs) que le joueur doit tous avoir / ne doit pas avoir. Voir docs/REPERCUSSIONS.md.
    var flags: [String]?
    var excludeFlags: [String]?
    /// Niveau minimum (1 à 5) exigé par compétence, ex. {"guitare": 3}. Voir docs/COMPETENCES.md.
    var skills: [String: Int]?
}

struct Issue: Codable, Equatable {
    /// Poids relatif de cette issue (les chances d'un choix n'ont pas besoin de faire 1).
    var chance: Double?
    var text: String
    var effects: Effets?
}

struct Choix: Codable, Equatable {
    var label: String
    var outcomes: [Issue]
    /// Choix caché : visible seulement si le joueur a ces niveaux de compétence. Voir docs/COMPETENCES.md.
    var requiresSkill: [String: Int]?
}

struct Evenement: Codable, Identifiable, Equatable {
    var id: String
    var category: String?
    var minAge: Int
    var maxAge: Int
    var weight: Double?
    /// Si vrai, l'événement n'arrive qu'une fois par vie.
    var unique: Bool?
    var conditions: ConditionsEvenement?
    var text: String
    /// Effets directs, pour un événement sans choix.
    var effects: Effets?
    var choices: [Choix]?
}

/// Un événement prêt à être affiché, avec les noms déjà remplacés.
struct EvenementAffiche: Identifiable, Equatable {
    let id = UUID()
    let evenement: Evenement
    let texte: String
    var resultat: String?
}

enum BibliothequeEvenements {
    /// Tous les événements de tous les fichiers JSON de Data/Events.
    static let tous: [Evenement] = DonneesJSON.chargerTableaux(dossier: "Events", type: Evenement.self)
}

/// Lecture des fichiers JSON rangés dans le dossier Data de l'app.
enum DonneesJSON {
    static var dossierData: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Data", isDirectory: true)
    }

    /// Lit tous les fichiers .json d'un sous-dossier de Data, chacun contenant un tableau de T.
    /// Un fichier invalide est ignoré (et signalé dans la console) au lieu de faire planter le jeu.
    static func chargerTableaux<T: Decodable>(dossier: String, type: T.Type) -> [T] {
        guard let base = dossierData?.appendingPathComponent(dossier, isDirectory: true),
              let fichiers = try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) else {
            return []
        }
        var resultat: [T] = []
        for url in fichiers.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                resultat += try JSONDecoder().decode([T].self, from: data)
            } catch {
                print("⚠️ Fichier de données invalide \(url.lastPathComponent) : \(error)")
            }
        }
        return resultat
    }
}

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
    /// Module « Cœur » (liaisons, tromperies, enfants cachés, crises de couple). Voir docs/COEUR.md.
    var coeur: CoeurEffets?
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
    /// Scène à choix enchaînés : après cette issue, la même carte continue avec une nouvelle question.
    /// Voir docs/SCENES.md.
    var then: EtapeScene? = nil
}

/// Étape suivante d'une scène (idée 58) : un texte et 1 à 4 choix, dans la même carte que l'événement.
/// Une scène compte pour un seul événement dans la limite de 3 événements à choix par an.
struct EtapeScene: Codable, Equatable {
    /// Id pour les répercussions (`"on": "event:<id>"`). Défaut : "<id de l'événement>#<n° d'étape>".
    var id: String?
    var text: String
    var choices: [Choix]
}

struct Choix: Codable, Equatable {
    var label: String
    var outcomes: [Issue]
    /// Choix caché : visible seulement si le joueur a ces niveaux de compétence. Voir docs/COMPETENCES.md.
    var requiresSkill: [String: Int]?
    /// Force le niveau de risque affiché avant de choisir : "none", "low", "medium", "high" ou "extreme".
    /// Absent = calculé à partir des issues (voir Engine/Risques.swift).
    var risk: String? = nil
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
    /// Rempli par le moteur (pas dans les JSON) : ce qui a causé cette suite, pour le rappel
    /// « Parce que tu as fait X il y a N ans ». Voir Engine/Souvenirs.swift.
    var rappel: Souvenir? = nil
}

/// Un événement prêt à être affiché, avec les noms déjà remplacés.
struct EvenementAffiche: Identifiable, Equatable {
    let id = UUID()
    let evenement: Evenement
    let texte: String
    var resultat: String?

    // Scènes à choix enchaînés (docs/SCENES.md)
    /// Étape affichée (nil = la première, celle de l'événement).
    var etape: EtapeScene? = nil
    /// Texte de l'étape affichée, noms remplacés.
    var texteEtape: String? = nil
    /// Numéro de l'étape affichée (1 = la première).
    var numeroEtape: Int = 1
    /// Étape qui suivra quand le joueur touchera « Continuer ».
    var suiteEnAttente: EtapeScene? = nil
    /// Étapes déjà jouées dans cette carte.
    var etapesPassees: [EtapePassee] = []
    /// Le dernier choix a laissé des traces (souvenir ou suite programmée).
    var laisseDesTraces = false
    /// Index du dernier choix fait dans l'étape affichée.
    var dernierChoix: Int? = nil

    var texteCourant: String { texteEtape ?? texte }
    var choixCourants: [Choix] { etape?.choices ?? evenement.choices ?? [] }
    /// La scène compte au moins deux étapes.
    var estScene: Bool { numeroEtape > 1 || suiteEnAttente != nil || Self.contientEtapes(evenement.choices) }

    static func contientEtapes(_ choix: [Choix]?) -> Bool {
        (choix ?? []).contains { $0.outcomes.contains { $0.then != nil } }
    }
}

/// Une étape déjà jouée d'une scène.
struct EtapePassee: Equatable {
    let texte: String
    let choix: String
    let resultat: String
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

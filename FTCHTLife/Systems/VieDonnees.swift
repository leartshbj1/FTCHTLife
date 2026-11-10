import Foundation

// MARK: - Types des fichiers de données du module

struct CrimeDefinition: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var icon: String?
    var minAge: Int
    var difficulty: Double
    var arrestChance: Double
    var lootMin: Int
    var lootMax: Int
    var karma: Int
    var sentenceMinMonths: Int
    var sentenceMaxMonths: Int
    var fineMin: Int
    var fineMax: Int
    var successTexts: [String]
    var failTexts: [String]
    var arrestTexts: [String]
}

/// Effets simples des activités de prison et des étapes.
struct VieEffetsSimples: Codable, Equatable {
    var health: Int?
    var happiness: Int?
    var smarts: Int?
    var looks: Int?
    var karma: Int?
    var money: Int?
    var bond: Int?
    var jailMonths: Int?
}

struct CrimeActivitePrison: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var icon: String?
    var texts: [String]
    var effects: VieEffetsSimples?
    var risk: Double?
    var badTexts: [String]?
    var badEffects: VieEffetsSimples?
}

struct SanteGuerison: Codable, Equatable {
    var doctor: Double
    var hospital: Double
    var alternative: Double
}

struct SanteMaladie: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var description: String
    var minAge: Int
    var maxAge: Int
    var yearlyChance: Double
    var severity: Int
    var chronic: Bool
    var contagious: Bool?
    var healthPerYear: Int
    var happinessPerYear: Int?
    var deathChancePerYear: Double
    var selfHealChance: Double
    var cure: SanteGuerison
    var costDoctor: Int
    var costHospital: Int
}

struct SanteAlternative: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var cost: Int
    var cureBonus: Double
    var texts: [String]
}

struct SanteAddiction: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var yearlyHealth: Int
    var yearlyHappiness: Int
    var yearlyMoney: Int
    var relapseChance: Double
    var rehabCost: Int
    var rehabSuccess: Double
    var texts: [String]
}

/// Petit message d'après (premiers pas, anniversaire de mariage…).
struct VieEtape: Codable, Identifiable, Equatable {
    var id: String
    /// child, grandchild, spouse, partner, fiance, friend, bestFriend, ex, mother, father, brother, sister, self
    var kind: String
    /// age, years, chance
    var trigger: String
    var value: Double
    var texts: [String]
    var effects: VieEffetsSimples?
}

// MARK: - Chargement

enum VieDonnees {
    static let crimes: [CrimeDefinition] = DonneesJSON.chargerTableaux(dossier: "Crime", type: CrimeDefinition.self)
    static let activitesPrison: [CrimeActivitePrison] = DonneesJSON.chargerTableaux(dossier: "CrimePrison", type: CrimeActivitePrison.self)
    static let maladies: [SanteMaladie] = DonneesJSON.chargerTableaux(dossier: "Health", type: SanteMaladie.self)
    static let alternatives: [SanteAlternative] = DonneesJSON.chargerTableaux(dossier: "HealthAlternatives", type: SanteAlternative.self)
    static let addictions: [SanteAddiction] = DonneesJSON.chargerTableaux(dossier: "HealthAddictions", type: SanteAddiction.self)
    static let etapes: [VieEtape] = DonneesJSON.chargerTableaux(dossier: "Relationships", type: VieEtape.self)

    static let maladiesParId: [String: SanteMaladie] = Dictionary(maladies.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    static let addictionsParId: [String: SanteAddiction] = Dictionary(addictions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    /// Répliques des actions de relation (Data/RelationshipsTexts/dialogues.json, un objet clé → phrases).
    static let dialogues: [String: [String]] = {
        guard let url = DonneesJSON.dossierData?.appendingPathComponent("RelationshipsTexts/dialogues.json"),
              let data = try? Data(contentsOf: url),
              let d = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        return d
    }()

    /// Une réplique au hasard, {nom} remplacé par le prénom de l'autre personne.
    static func replique(_ cle: String, nom: String, defaut: String) -> String {
        (dialogues[cle]?.randomElement() ?? defaut).replacingOccurrences(of: "{nom}", with: nom)
    }

    private struct Noms: Codable { var male: [String]; var female: [String]; var last: [String] }

    private static let noms: Noms? = {
        guard let url = DonneesJSON.dossierData?.appendingPathComponent("RelationshipsTexts/noms.json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Noms.self, from: data)
    }()

    static func prenom(_ genre: Genre) -> String {
        let liste = genre == .femme ? noms?.female : noms?.male
        return liste?.randomElement() ?? Donnees.prenom(genre)
    }

    static func nomFamille() -> String {
        noms?.last.randomElement() ?? Donnees.noms.randomElement() ?? "Martin"
    }

    static func maladie(_ id: String) -> SanteMaladie? { maladiesParId[id] }
    static func addiction(_ id: String) -> SanteAddiction? { addictionsParId[id] }
}

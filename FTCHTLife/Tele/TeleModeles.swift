import Foundation

// Jeux télé et téléréalité : formats des données.
// Format complet et branchement dans le moteur : docs/TELE.md.
// Données :
//   FTCHTLife/Resources/Data/Tele/Emissions/*.json : un tableau de TeleEmission par fichier
//   FTCHTLife/Resources/Data/Tele/Quiz/*.json      : un tableau de TeleQuestion par fichier
//   FTCHTLife/Resources/Data/Tele/Offres/*.json    : un tableau de TeleOffre par fichier
//   FTCHTLife/Resources/Data/Tele/Evenements/*.json : événements de retombées (format Evenement)

// MARK: - Émissions à manches (île, villa, cuisine, télé-crochet…)

/// Une émission de téléréalité jouée en plusieurs manches.
struct TeleEmission: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var slogan: String
    /// Nom d'un symbole SF Symbols.
    var icone: String
    var ageMin: Int
    var ageMax: Int
    var casting: TeleCasting
    /// Gain du vainqueur, en euros.
    var prix: Int
    /// Cachet versé pour chaque manche jouée, en euros.
    var cachet: Int
    /// Célébrité gagnée en cas de victoire (en plus de celle des manches).
    var celebriteVictoire: Int
    /// Textes d'ouverture (un tiré au hasard).
    var intro: [String]
    var manches: [TeleManche]
    /// Textes quand le joueur est éliminé. Variable possible : {manche}.
    var eliminations: [String]
    /// Textes quand le joueur gagne la finale.
    var victoires: [String]
    /// Textes quand le joueur perd la finale.
    var defaitesFinale: [String]
}

struct TeleCasting: Codable, Equatable {
    /// Statistique testée pour être pris au casting (voir TeleMoteur.valeur).
    var stat: String
    var difficulte: Int
    var acceptes: [String]
    var refus: [String]
}

struct TeleManche: Codable, Equatable {
    var titre: String
    /// Une situation est tirée au hasard dans cette liste.
    var situations: [TeleSituation]
}

struct TeleSituation: Codable, Equatable, Identifiable {
    var id: String
    var texte: String
    var choix: [TeleChoix]
}

struct TeleChoix: Codable, Equatable {
    var label: String
    /// Statistique testée : sante, bonheur, intelligence, apparence, karma, charisme, voix, cuisine, celebrite, hasard.
    var stat: String
    /// 0 (facile) à 100 (presque impossible).
    var difficulte: Int
    var reussite: [TeleResultat]
    var echec: [TeleResultat]
}

struct TeleResultat: Codable, Equatable {
    var texte: String
    /// Points de la manche, de -3 à 3. Décident de l'élimination.
    var points: Int
    /// Effets classiques (mêmes clés que les événements). `fame` = célébrité.
    var effets: Effets?
    /// Moment culte (souvent humiliant) dont le public se souviendra. Ex. « ta chute dans la piscine ».
    var culte: String?
    /// Vrai : tu formes un couple avec {crush} dans l'émission.
    var couple: Bool?
    /// Vrai : ton couple de l'émission explose.
    var rupture: Bool?
}

// MARK: - Quiz

/// Une question du quiz « Cerveau ou Râteau ».
struct TeleQuestion: Codable, Identifiable, Equatable {
    var id: String
    /// 1 = facile, 2 = moyen, 3 = difficile.
    var niveau: Int
    var theme: String
    var question: String
    var bonne: String
    /// Exactement trois mauvaises réponses.
    var mauvaises: [String]
}

// MARK: - Offres pour monnayer sa célébrité

struct TeleOffre: Codable, Identifiable, Equatable {
    var id: String
    var titre: String
    var description: String
    var icone: String
    /// Célébrité minimale pour recevoir l'offre.
    var celebriteMin: Int
    var ageMin: Int
    /// Gain en euros [min, max], multiplié par la célébrité actuelle / 50.
    var gain: [Int]
    /// Textes possibles du résultat (variable {gain}).
    var textes: [String]
    var effets: Effets?
    /// Probabilité que ça tourne mal (0…1).
    var risque: Double?
    var textesRates: [String]?
    var effetsRates: Effets?
}

// MARK: - État sauvegardé

/// Ce que le module retient sur la vie en cours. À ajouter dans `Joueur` (champ optionnel `tele`).
struct TeleEtat: Codable, Equatable {
    /// Célébrité au moment `celebriteAge` (0…100). Elle fond chaque année : voir `celebrite(age:)`.
    var celebriteBase: Double = 0
    var celebriteAge: Int = 0
    var participations: Int = 0
    var victoires: Int = 0
    var gainsTotaux: Int = 0
    var humiliations: Int = 0
    /// Ids des émissions déjà faites (une même émission peut être refaite les années suivantes).
    var emissionsFaites: [String] = []
    /// Moments cultes, du plus ancien au plus récent.
    var momentsCultes: [String] = []
    /// Talents cachés, tirés une fois par vie (0…100).
    var talentVoix: Int = Int.random(in: 0...100)
    var talentCuisine: Int = Int.random(in: 0...100)
    /// Meilleur gain au quiz.
    var recordQuiz: Int = 0
    /// Âge de la dernière apparition à la télé.
    var derniereApparition: Int?

    /// Perte de célébrité par an : la gloire fond de 35 % chaque année.
    static let fonte = 0.65

    func celebrite(age: Int) -> Int {
        let ans = max(0, age - celebriteAge)
        return Int((celebriteBase * pow(TeleEtat.fonte, Double(ans))).rounded())
    }

    mutating func ajouterCelebrite(_ delta: Int, age: Int) {
        let actuelle = Double(celebrite(age: age))
        celebriteBase = min(100, max(0, actuelle + Double(delta)))
        celebriteAge = age
    }

    /// Libellé du statut de star.
    func statut(age: Int) -> String {
        let c = celebrite(age: age)
        switch c {
        case 80...: return "Star nationale"
        case 60..<80: return "Visage connu"
        case 40..<60: return "On te reconnaît au supermarché"
        case 20..<40: return "Vaguement familier"
        case 1..<20: return participations > 0 ? "Ex-candidat·e oublié·e" : "Inconnu·e"
        default: return participations > 0 ? "Has-been" : "Inconnu·e"
        }
    }
}

// MARK: - Bibliothèque

enum TeleBibliotheque {
    static let emissions: [TeleEmission] = DonneesJSON.chargerTableaux(dossier: "Tele/Emissions", type: TeleEmission.self)
    static let questions: [TeleQuestion] = DonneesJSON.chargerTableaux(dossier: "Tele/Quiz", type: TeleQuestion.self)
    static let offres: [TeleOffre] = DonneesJSON.chargerTableaux(dossier: "Tele/Offres", type: TeleOffre.self)
    /// Événements de retombées (format normal des événements, tags tv_*). Le moteur les ajoute à sa bibliothèque.
    static let evenements: [Evenement] = DonneesJSON.chargerTableaux(dossier: "Tele/Evenements", type: Evenement.self)
}

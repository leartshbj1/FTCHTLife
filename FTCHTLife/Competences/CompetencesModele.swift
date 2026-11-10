import Foundation

// Module Compétences : langues, cuisine, guitare, bricolage, sport, code, séduction…
// Elles montent en pratiquant (onglet Compétences, cours, boulot, études, école, activités, événements)
// et débloquent des choix cachés dans les événements. Voir docs/COMPETENCES.md.

// MARK: - Données (Resources/Data/Competences, CompetencesCours, CompetencesSources)

/// Une compétence du jeu (Data/Competences/*.json).
struct CompetenceDef: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    /// Nom d'un symbole SF (iOS 16).
    var icone: String
    /// langues, arts, pratique, corps, tete, social.
    var categorie: String
    var minAge: Int
    var description: String
    /// Phrase qui dit ce que la compétence permet (affichée dans l'écran).
    var debloque: String
    /// Titre rigolo pour chaque niveau, du niveau 1 au niveau 5.
    var titres: [String]
    /// Message affiché quand on atteint chaque niveau, du niveau 1 au niveau 5.
    var paliers: [String]
    var pratique: CompetencePratique
    /// Multiplicateur d'apprentissage avant 13 ans (défaut 1.2, langues 1.6).
    var bonusEnfant: Double?
    /// XP perdue par an quand on ne pratique plus depuis 4 ans (défaut 2).
    var oubli: Int?
}

/// Ce qui se passe quand on pratique la compétence depuis l'écran Compétences.
struct CompetencePratique: Codable, Equatable {
    /// Libellé du bouton, ex. « Cuisiner un plat ». Défaut : « S'entraîner ».
    var verbe: String?
    /// Textes selon le niveau : 0-1, 2-3, 4-5.
    var debut: [String]
    var milieu: [String]
    var maitre: [String]
    /// Effets sur les stats à chaque pratique réussie.
    var effects: Effets?
    /// Petits drames possibles, surtout aux bas niveaux.
    var accidents: [CompetenceAccident]?
    /// Coût d'une séance pour un adulte (matériel, salle…).
    var cout: Int?
}

struct CompetenceAccident: Codable, Equatable {
    /// Probabilité (0 à 1) à chaque pratique.
    var chance: Double
    /// L'accident ne peut arriver que jusqu'à ce niveau (défaut 5).
    var maxNiveau: Int?
    var text: String
    var effects: Effets?
}

/// Un cours payant (Data/CompetencesCours/*.json), une fois par an.
struct CompetenceCours: Codable, Identifiable, Equatable {
    var id: String
    var competence: String
    var titre: String
    var description: String
    var cout: Int
    var minAge: Int?
    /// Niveau minimum pour s'inscrire (masterclass…).
    var niveauMin: Int?
    /// Au-delà de ce niveau, le cours n'apprend plus rien.
    var niveauMax: Int?
    /// XP de base [min, max].
    var gain: [Int]
    var textes: [String]
    var effects: Effets?
}

/// Gains automatiques (Data/CompetencesSources/*.json).
/// type : "metier" (chaque année au travail), "filiere" (chaque année d'études), "etudes" (toute filière),
/// "ecole" (chaque année d'école avant le bac), "retraite" (chaque année après 65 ans sans emploi),
/// "activite" (après une activité de l'onglet Activités).
struct CompetenceSource: Codable, Identifiable, Equatable {
    var id: String
    var type: String
    /// Ids exacts : metierId, filière (rawValue) ou id d'activité.
    var ids: [String]?
    /// Morceaux de mots cherchés dans l'id ou l'intitulé du métier (sans accents ni majuscules).
    var motsCles: [String]?
    var minAge: Int?
    var maxAge: Int?
    /// Probabilité (0 à 1) que le gain ait lieu cette année / cette fois (défaut 1).
    var chance: Double?
    /// XP de base par compétence.
    var gains: [String: Int]
}

enum CatalogueCompetences {
    static let toutes: [CompetenceDef] = DonneesJSON.chargerTableaux(dossier: "Competences", type: CompetenceDef.self)
    static let cours: [CompetenceCours] = DonneesJSON.chargerTableaux(dossier: "CompetencesCours", type: CompetenceCours.self)
    static let sources: [CompetenceSource] = DonneesJSON.chargerTableaux(dossier: "CompetencesSources", type: CompetenceSource.self)

    static let parId: [String: CompetenceDef] = {
        var d: [String: CompetenceDef] = [:]
        for c in toutes where d[c.id] == nil { d[c.id] = c }
        return d
    }()

    static func def(_ id: String) -> CompetenceDef? { parId[id] }

    static func cours(pour id: String) -> [CompetenceCours] {
        cours.filter { $0.competence == id }
    }

    /// Catégories dans l'ordre d'affichage.
    static let categories: [CompetenceCategorie] = [
        CompetenceCategorie(id: "langues", nom: "Langues"),
        CompetenceCategorie(id: "arts", nom: "Arts et musique"),
        CompetenceCategorie(id: "pratique", nom: "De tes mains"),
        CompetenceCategorie(id: "corps", nom: "Corps"),
        CompetenceCategorie(id: "tete", nom: "Tête"),
        CompetenceCategorie(id: "social", nom: "Avec les autres"),
    ]
}

struct CompetenceCategorie: Identifiable, Equatable {
    let id: String
    let nom: String
}

// MARK: - État sauvegardé

/// État des compétences du joueur, à stocker dans `Joueur.competences` (optionnel).
struct CompetencesEtat: Codable, Equatable {
    /// XP par compétence, de 0 à 100.
    var xp: [String: Int] = [:]
    /// Âge du joueur lors de la dernière progression (pour l'oubli).
    var dernierePratique: [String: Int] = [:]
    /// Meilleur niveau déjà atteint (chaque palier n'est annoncé qu'une fois).
    var meilleurNiveau: [String: Int] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case xp, dernierePratique, meilleurNiveau
    }

    // Décodage tolérant : une ancienne sauvegarde sans certains champs reste lisible.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = try c.decodeIfPresent([String: Int].self, forKey: .xp) ?? [:]
        dernierePratique = try c.decodeIfPresent([String: Int].self, forKey: .dernierePratique) ?? [:]
        meilleurNiveau = try c.decodeIfPresent([String: Int].self, forKey: .meilleurNiveau) ?? [:]
    }
}

/// Résultat d'un gain d'XP.
struct CompetenceGain: Equatable {
    let id: String
    /// XP réellement gagnée (ou perdue si négatif).
    let gain: Int
    let niveauAvant: Int
    let niveauApres: Int
    /// Phrases à écrire dans le journal (nouveau palier, perte de niveau).
    let messages: [String]
}

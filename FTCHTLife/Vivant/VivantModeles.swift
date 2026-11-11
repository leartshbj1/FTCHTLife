import Foundation

// Jeu vivant (idées 40 à 47) : les moments qui découlent de ce que le joueur possède, fait ou a lancé.
// Spécification : docs/VIVANT.md.
// Données :
//   - Data/Events/vivant_*.json : événements classiques liés à la situation (vie d'élu, biens, métier, notoriété) ;
//   - Data/Repercussions/vivant_*.json : suites rep_viv_ déclenchées par les signaux de ce module (résultats, proches) ;
//   - Data/VivantAnniversaires/*.json : anniversaires de l'histoire du joueur ;
//   - Data/VivantProjets/*.json : projets personnels au long cours.

// MARK: - État

/// État du module, rangé dans `Joueur.jeuVivant` (optionnel : les anciennes sauvegardes restent lisibles).
struct JeuVivantEtat: Codable, Equatable {
    /// Photo de la situation au dernier passage d'année, pour repérer ce qui a changé.
    var photo: VivantPhoto?
    /// Dates marquantes de la vie (mariage, bac, sortie de prison…) pour les anniversaires.
    var jalons: [VivantJalon] = []
    /// Projet personnel en cours.
    var projet: VivantProjetEnCours?
    /// Projets terminés ou abandonnés.
    var projetsFinis: [VivantProjetFini] = []
    /// Dernière sortie avec un bien : "bateau", "avion_prive" → âge.
    var sorties: [String: Int] = [:]
    /// Ids des anniversaires déjà montrés (un même anniversaire ne revient pas).
    var anniversairesVus: [String] = []

    init() {}
}

/// Ce qu'on compare d'une année sur l'autre pour envoyer des signaux.
struct VivantPhoto: Codable, Equatable {
    var argent: Int = 0
    var objets: [String] = []            // ids des biens possédés (UUID)
    var proprietaire = false
    var mandat: String?                  // poste politique actuel
    var mandatNumero = 0
    var gouverne = false
    var placements = 0
    var paysActuel: String?
    var condamnations = 0
    var casierEfface = false
    var starTele = false
    var starReseaux = false
    var millionnaire = false
    var milliardaire = false
}

/// Une date marquante de la vie du joueur.
struct VivantJalon: Codable, Equatable {
    var type: String
    var age: Int
    /// Nom associé : prénom de la personne épousée, du parent disparu, de l'enfant, nom de la boîte, du pays…
    var nom: String?
}

struct VivantProjetEnCours: Codable, Equatable {
    var id: String
    var ageDebut: Int
    /// Prochaine étape à jouer (index dans `etapes`).
    var etape: Int = 0
    var progres: Int = 0
}

struct VivantProjetFini: Codable, Equatable, Identifiable {
    var id: String
    var ageFin: Int
    /// "reussite", "moyen", "echec" ou "abandon".
    var fin: String
}

// MARK: - Données

/// Un anniversaire de l'histoire du joueur (Data/VivantAnniversaires).
struct VivantAnniversaire: Codable, Equatable, Identifiable {
    var id: String
    var jalon: String
    var annees: [Int]
    var conditions: ConditionsEvenement?
    /// Phrase du journal si la carte ne peut pas être montrée cette année.
    var ligne: String?
    var text: String
    var effects: Effets?
    var choices: [Choix]?
}

/// Issue d'une étape de projet : une issue classique, plus la progression.
struct VivantIssueProjet: Codable, Equatable {
    var chance: Double?
    var text: String
    var effects: Effets?
    var progres: Int?
    var abandon: Bool?

    var issue: Issue { Issue(chance: chance, text: text, effects: effects) }
}

struct VivantChoixProjet: Codable, Equatable {
    var label: String
    var outcomes: [VivantIssueProjet]
    var requiresSkill: [String: Int]?
    /// Le choix n'apparaît que si le joueur a ces tags (un proche, par exemple).
    var requiresTags: [String]?
}

struct VivantEtapeProjet: Codable, Equatable {
    var text: String
    var choices: [VivantChoixProjet]
}

struct VivantFinProjet: Codable, Equatable {
    var text: String
    var effects: Effets?
    var setFlags: [String]?
}

struct VivantFinsProjet: Codable, Equatable {
    var reussite: VivantFinProjet
    var moyen: VivantFinProjet
    var echec: VivantFinProjet
}

/// Un projet personnel au long cours (Data/VivantProjets).
struct VivantProjet: Codable, Equatable, Identifiable {
    var id: String
    var nom: String
    var emoji: String?
    var description: String
    var minAge: Int?
    var maxAge: Int?
    var conditions: ConditionsEvenement?
    /// Coût au lancement.
    var cout: Int?
    /// Coût de chaque année.
    var coutAnnuel: Int?
    /// Compétence qui progresse chaque année du projet.
    var competence: String?
    var etapes: [VivantEtapeProjet]
    var fins: VivantFinsProjet
    var abandon: String?
}

enum VivantBibliotheque {
    static let anniversaires: [VivantAnniversaire] =
        DonneesJSON.chargerTableaux(dossier: "VivantAnniversaires", type: VivantAnniversaire.self)
    static let projets: [VivantProjet] =
        DonneesJSON.chargerTableaux(dossier: "VivantProjets", type: VivantProjet.self)

    private static let projetsParId: [String: VivantProjet] =
        Dictionary(projets.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func projet(_ id: String) -> VivantProjet? { projetsParId[id] }
}

import Foundation

// MARK: - Module Voisinage : voisins récurrents et vie de quartier
//
// Chaque logement a ses voisins (retraité curieux, famille bruyante, voisin mystérieux…) qui
// vieillissent, se souviennent de ce que tu leur as fait, déménagent, tombent amoureux de toi
// ou te déclarent la guerre des haies. Voir docs/VOISINAGE.md pour le format et le branchement.
//
// Données : FTCHTLife/Resources/Data/Voisinage/
//   - Archetypes/*.json    : types de voisins (tableau de VoisinArchetype)
//   - Interactions/*.json  : actions possibles avec un voisin ou le quartier (tableau de VoisinageInteraction)
//   - Evenements/*.json    : événements de quartier (tableau de VoisinageEvenement)

// MARK: - Logement

/// Type de logement, qui décide quels voisins et quels événements on peut avoir.
enum VoisinageLogement: String, Codable, CaseIterable {
    case appartement   // immeuble : palier, ascenseur, syndic, colis
    case maison        // pavillon : haies, parking, barbecue, tondeuse
    case villa         // quartier chic : piscines, jalousie, gardiens
    case campagne      // ferme, chalet : voisins à 800 m, tracteurs, poules
    case caravane      // camping, mobil-home, péniche : voisins de passage

    var nom: String {
        switch self {
        case .appartement: return "Appartement"
        case .maison: return "Maison"
        case .villa: return "Villa"
        case .campagne: return "Campagne"
        case .caravane: return "Caravane"
        }
    }

    var icone: String {
        switch self {
        case .appartement: return "building.2.fill"
        case .maison: return "house.fill"
        case .villa: return "building.columns.fill"
        case .campagne: return "leaf.fill"
        case .caravane: return "car.side.fill"
        }
    }

    /// Nombre de voisins proches suivis par le jeu.
    var nombreVoisins: ClosedRange<Int> {
        switch self {
        case .appartement: return 4...5
        case .maison: return 3...4
        case .villa: return 2...3
        case .campagne: return 2...2
        case .caravane: return 3...4
        }
    }

    /// Devine le type de logement à partir d'un identifiant ou d'un nom de bien (module boutique).
    /// Ex. "studio_centre" → appartement, "Pavillon avec jardin" → maison, "Château" → villa.
    static func depuis(_ texte: String) -> VoisinageLogement {
        let t = texte.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        let correspondances: [(VoisinageLogement, [String])] = [
            (.caravane, ["caravane", "camping", "mobil", "peniche", "van", "tente", "yacht", "bateau", "voilier"]),
            (.campagne, ["ferme", "chalet", "campagne", "grange", "moulin", "cabane", "ranch"]),
            (.villa, ["villa", "manoir", "chateau", "palais", "domaine", "propriete", "hotel particulier", "ile"]),
            (.maison, ["maison", "pavillon", "longere", "bungalow", "mas", "fermette"]),
            (.appartement, ["appart", "studio", "loft", "duplex", "penthouse", "chambre", "colocation", "coloc", "hlm", "t1", "t2", "t3", "t4"]),
        ]
        for (type, mots) in correspondances where mots.contains(where: { t.contains($0) }) {
            return type
        }
        return .appartement
    }
}

// MARK: - Voisin

/// Ce que le voisin pense de toi.
enum VoisinStatut: String, Codable {
    case neutre, ami, ennemi, amour

    var libelle: String {
        switch self {
        case .neutre: return "Voisin"
        case .ami: return "Ami"
        case .ennemi: return "Ennemi juré"
        case .amour: return "Amour de palier"
        }
    }
}

struct Voisin: Codable, Identifiable, Equatable {
    var id = UUID()
    var archetype: String
    var prenom: String
    var nom: String
    var genre: Genre
    var age: Int
    /// Relation avec toi, 0 à 100.
    var lien: Int
    var statut: VoisinStatut = .neutre
    var celibataire: Bool
    /// Où il habite par rapport à toi (« palier », « 3e étage », « maison d'en face »…).
    var emplacement: String
    var anneesDansLeQuartier: Int = 0
    /// Ce qu'il retient de toi (souvenirs posés par les événements), ex. "a_vole_son_colis".
    var souvenirs: [String] = []
    /// Faux s'il est mort ou parti.
    var vivant: Bool = true
    /// Vrai s'il a déménagé (et pas mort).
    var parti: Bool = false
    /// S'il est devenu ton ami ou ton copain/ta copine : l'id de la relation correspondante.
    var relationId: UUID?

    var nomComplet: String { "\(prenom) \(nom)" }
    /// « M. Gashi » / « Mme Rossi ».
    var civilite: String { (genre == .femme ? "Mme " : "M. ") + nom }
}

// MARK: - Copropriété

struct VoisinageCopro: Codable, Equatable {
    var nomSyndic: String
    /// Charges annuelles payées par un propriétaire.
    var chargesAnnuelles: Int
    /// Le joueur est président(e) du conseil syndical.
    var president: Bool = false
    /// Travaux votés en AG (texte libre affiché dans l'écran Voisins).
    var travauxVotes: [String] = []
}

// MARK: - État sauvegardé

/// État du voisinage du joueur, à ranger dans `Joueur.voisinage` (optionnel).
struct VoisinageEtat: Codable, Equatable {
    var logement: VoisinageLogement
    /// Vrai tant que le joueur habite chez ses parents.
    var chezParents: Bool
    var proprietaire: Bool
    var quartier: String
    var adresse: String
    /// Ambiance du quartier, 0 (zone de guerre) à 100 (carte postale).
    var ambiance: Int
    var voisins: [Voisin]
    var copro: VoisinageCopro?
    /// Drapeaux du quartier, ex. "guerre_des_haies", "fete_des_voisins_ratee".
    var drapeaux: [String] = []
    /// Compteurs, ex. "colis_voles": 3.
    var compteurs: [String: Int] = [:]
    /// Événements uniques déjà vus (ids).
    var vus: [String] = []
    /// Anciens voisins (partis ou morts) pour les souvenirs et la nécrologie.
    var anciens: [Voisin] = []
    var anneesIci: Int = 0
    /// Loyer annuel payé par le module (déménagement « Quitter le nid »). `nil` quand la boutique gère le logement.
    var loyerAnnuel: Int?
    /// Événements de quartier affichés et en attente d'un choix : id de l'événement → voisin ciblé.
    var enCours: [String: UUID] = [:]

    var voisinsPresents: [Voisin] { voisins.filter { $0.vivant } }

    func a(_ drapeau: String) -> Bool { drapeaux.contains(drapeau) }
}

// MARK: - Archétypes (données)

struct VoisinArchetype: Codable, Identifiable, Equatable {
    var id: String
    var titreM: String
    var titreF: String
    var description: String
    /// Logements où on peut le croiser.
    var logements: [VoisinageLogement]
    var ageMin: Int
    var ageMax: Int
    /// "any", "male" ou "female".
    var gender: String?
    var weight: Double?
    /// Traits de 0 à 100, qui changent les chances des interactions.
    var bruit: Int
    var curiosite: Int
    var gentillesse: Int
    /// Probabilité d'être célibataire.
    var celibat: Double?
    /// Phrases d'ambiance qui tombent dans le journal (variables {voisin}, {voisin_nom}, {il}…).
    var phrases: [String]
}

// MARK: - Événements de quartier (données)

/// Cible un voisin pour l'événement : le premier voisin qui correspond est tiré au hasard.
struct VoisinageCible: Codable, Equatable {
    var archetypes: [String]?
    var statuts: [VoisinStatut]?
    var minLien: Int?
    var maxLien: Int?
    /// Le voisin doit être célibataire, adulte, et avoir un âge proche du joueur (± 12 ans).
    var celibataire: Bool?
    /// "any", "male", "female" pour le voisin.
    var gender: String?
    /// Le voisin doit être de genre opposé au joueur (pratique pour les amours ; absent = peu importe).
    var opposite: Bool?
    var minAge: Int?
    var maxAge: Int?
    /// Souvenirs que le voisin doit avoir / ne pas avoir.
    var souvenirs: [String]?
    var sansSouvenirs: [String]?
}

/// Conditions propres au quartier.
struct VoisinageConditions: Codable, Equatable {
    var logements: [VoisinageLogement]?
    var chezParents: Bool?
    var proprietaire: Bool?
    /// Le joueur doit être président(e) du conseil syndical.
    var president: Bool?
    var minAmbiance: Int?
    var maxAmbiance: Int?
    var drapeaux: [String]?
    var sansDrapeaux: [String]?
    var minCompteurs: [String: Int]?
    /// Années minimum passées à cette adresse.
    var minAnnees: Int?
}

/// Ce qu'une issue change au voisin ciblé et au quartier.
struct VoisinageEffet: Codable, Equatable {
    /// Variation du lien avec le voisin ciblé.
    var lien: Int?
    var statut: VoisinStatut?
    /// Souvenirs ajoutés au voisin ciblé.
    var souvenir: [String]?
    var oublie: [String]?
    /// Le voisin déménage (remplacé l'année suivante).
    var demenage: Bool?
    /// Le voisin meurt (rare, avec texte de l'issue).
    var meurt: Bool?
    /// Le voisin devient ton ami (ajouté à tes relations).
    var devientAmi: Bool?
    /// Le voisin devient ton copain / ta copine (ajouté à tes relations).
    var devientPartenaire: Bool?
    /// Variation du lien avec TOUS les voisins (fête ratée, scandale…).
    var lienTous: Int?
    var ambiance: Int?
    var drapeaux: [String]?
    var retireDrapeaux: [String]?
    var compteurs: [String: Int]?
    /// Copropriété : le joueur devient (true) ou cesse d'être (false) président du conseil syndical.
    var president: Bool?
    /// Copropriété : variation des charges annuelles.
    var charges: Int?
    /// Copropriété : travaux votés (texte affiché).
    var travaux: String?
    /// Signaux envoyés au module Répercussions (ex. "fete_des_voisins").
    var signaux: [String]?
}

struct VoisinageIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    var effects: Effets?
    var voisin: VoisinageEffet?
}

struct VoisinageChoix: Codable, Equatable {
    var label: String
    var outcomes: [VoisinageIssue]
}

/// Un événement de quartier. Même format que les événements du moteur, plus `quartier`, `cible` et `voisin`.
struct VoisinageEvenement: Codable, Identifiable, Equatable {
    var id: String
    var minAge: Int
    var maxAge: Int
    var weight: Double?
    var unique: Bool?
    /// Conditions du moteur (genre, argent, tags…).
    var conditions: ConditionsEvenement?
    /// Conditions de quartier.
    var quartier: VoisinageConditions?
    /// Voisin concerné. Absent = événement de quartier sans voisin précis.
    var cible: VoisinageCible?
    var text: String
    var effects: Effets?
    /// Effet voisin/quartier pour un événement sans choix.
    var voisin: VoisinageEffet?
    var choices: [VoisinageChoix]?
}

// MARK: - Interactions (données)

struct VoisinageInteractionIssue: Codable, Equatable {
    var chance: Double?
    /// Le poids est multiplié selon un trait du voisin : "bruit", "curiosite", "gentillesse".
    var trait: String?
    /// "haut" : plus le trait est élevé, plus l'issue est probable ; "bas" : l'inverse.
    var sens: String?
    /// Poids multiplié par 2 si le lien est au moins à cette valeur.
    var bonusLien: Int?
    var text: String
    var effects: Effets?
    var voisin: VoisinageEffet?
}

struct VoisinageInteraction: Codable, Identifiable, Equatable {
    var id: String
    var titre: String
    var icone: String
    var description: String
    /// "voisin" (sur un voisin précis) ou "quartier".
    var portee: String
    var minAge: Int
    var maxAge: Int?
    var cout: Int?
    var cible: VoisinageCible?
    var quartier: VoisinageConditions?
    var conditions: ConditionsEvenement?
    var outcomes: [VoisinageInteractionIssue]
}

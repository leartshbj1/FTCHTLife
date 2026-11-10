import Foundation

// Module « Vieillesse et maison de retraite ». Voir docs/RETRAITE.md.
// Données : FTCHTLife/Resources/Data/Retraite/<Sous-dossier>/*.json (un tableau par fichier).

// MARK: - Catalogue

/// Une maison de retraite qu'on peut choisir (ou que les enfants choisissent pour toi).
struct RetraiteResidence: Codable, Identifiable, Equatable {
    let id: String
    let nom: String
    let description: String
    /// Prix de la pension par an, en euros.
    let prixAnnuel: Int
    /// 0-100 : effet sur la santé chaque année.
    let confort: Int
    /// 0-100 : effet sur le bonheur chaque année.
    let ambiance: Int
    /// 0-100 : plus c'est haut, plus l'évasion est difficile.
    let surveillance: Int
    /// Ce qui fait la réputation de l'établissement (« loto », « danse », « securite »…).
    let specialite: String
}

/// Un résultat possible d'une activité ou d'un voyage.
struct RetraiteResultatAlea: Codable, Equatable {
    var chance: Double?
    var texte: String
    var effets: Effets?
}

/// Activité de résidence ou de club senior (loto à part).
struct RetraiteActivite: Codable, Identifiable, Equatable {
    let id: String
    let titre: String
    let icone: String
    let description: String
    /// Vrai : seulement quand on vit en maison de retraite.
    var residenceSeulement: Bool?
    var ageMin: Int?
    var cout: Int?
    let resultats: [RetraiteResultatAlea]
}

/// Voyage de retraités.
struct RetraiteVoyage: Codable, Identifiable, Equatable {
    let id: String
    let titre: String
    let icone: String
    let description: String
    var ageMin: Int?
    let cout: Int
    let resultats: [RetraiteResultatAlea]
}

/// Lot du loto du jeudi.
struct RetraiteLot: Codable, Identifiable, Equatable {
    let id: String
    let nom: String
    /// Ce que le lot rapporte en euros (revente ou bon d'achat).
    let valeur: Int
    let poids: Int
}

/// Réservoir de noms et de phrases pour les résidents.
struct RetraiteNomsResidents: Codable {
    var prenomsHommes: [String]
    var prenomsFemmes: [String]
    var noms: [String]
    var traits: [String]
    var phrasesDeces: [String]
    var phrasesArrivee: [String]

    static let secours = RetraiteNomsResidents(
        prenomsHommes: ["Lucien", "Marcel"], prenomsFemmes: ["Germaine", "Odette"], noms: ["Gourdin", "Pichard"],
        traits: ["se plaint de la soupe par principe"],
        phrasesDeces: ["{resident} nous a quittés."],
        phrasesArrivee: ["Nouvelle arrivée à la résidence : {resident}, qui {trait}."])
}

/// Phrases du journal écrites par le module.
struct RetraitePhrases: Codable {
    var placementImpose: [String]
    var placementServicesSociaux: [String]
    var anneeResidence: [String]
    var aucuneVisite: [String]
    var visite: [String]
    var naissancePetitEnfant: [String]
    var rattrape: [String]
    var cavale: [String]
    var liberte: [String]
    var evasionRatee: [String]

    static let secours = RetraitePhrases(
        placementImpose: ["Tes enfants t'ont installé{e} à {residence}."],
        placementServicesSociaux: ["Les services sociaux t'ont installé{e} à {residence}."],
        anneeResidence: ["Une année de plus à {residence}."],
        aucuneVisite: ["Aucun petit-enfant n'est venu cette année."],
        visite: ["{petitenfant} est venu{pe} te voir."],
        naissancePetitEnfant: ["{enfant} a eu un bébé : {petitenfant} !"],
        rattrape: ["On t'a retrouvé{e}. Retour à {residence}."],
        cavale: ["Une année de plus en cavale."],
        liberte: ["On a arrêté de te chercher. Tu es libre !"],
        evasionRatee: ["Évasion ratée."])
}

enum RetraiteCatalogue {
    static let residences: [RetraiteResidence] =
        DonneesJSON.chargerTableaux(dossier: "Retraite/Residences", type: RetraiteResidence.self)
            .sorted { $0.prixAnnuel < $1.prixAnnuel }
    static let activites: [RetraiteActivite] =
        DonneesJSON.chargerTableaux(dossier: "Retraite/Activites", type: RetraiteActivite.self)
    static let voyages: [RetraiteVoyage] =
        DonneesJSON.chargerTableaux(dossier: "Retraite/Voyages", type: RetraiteVoyage.self)
            .sorted { $0.cout < $1.cout }
    static let lots: [RetraiteLot] =
        DonneesJSON.chargerTableaux(dossier: "Retraite/Lots", type: RetraiteLot.self)
    static let noms: RetraiteNomsResidents =
        DonneesJSON.chargerTableaux(dossier: "Retraite/Residents", type: RetraiteNomsResidents.self).first ?? .secours
    static let phrases: RetraitePhrases =
        DonneesJSON.chargerTableaux(dossier: "Retraite/Phrases", type: RetraitePhrases.self).first ?? .secours

    static func residence(_ id: String?) -> RetraiteResidence? {
        guard let id else { return nil }
        return residences.first { $0.id == id }
    }

    /// Résidence la moins chère (celle que choisissent les enfants radins et l'aide sociale).
    static var moinsChere: RetraiteResidence? { residences.first }
}

// MARK: - État du joueur (sauvegardé)

enum RetraiteStatutResident: String, Codable {
    case connaissance, ami, rival, flirt, couple, marie

    var libelle: String {
        switch self {
        case .connaissance: return "Voisin·e de couloir"
        case .ami: return "Ami·e"
        case .rival: return "Ennemi·e juré·e"
        case .flirt: return "Ça flirte"
        case .couple: return "En couple"
        case .marie: return "Marié·e avec toi"
        }
    }

    var estRomance: Bool { self == .couple || self == .marie }
}

/// Un autre pensionnaire de la maison de retraite.
struct RetraiteResident: Codable, Identifiable, Equatable {
    var id = UUID()
    var prenom: String
    var nom: String
    var genre: Genre
    var age: Int
    var trait: String
    var lien: Int
    var statut: RetraiteStatutResident = .connaissance
    var vivant: Bool = true
    /// A accepté de t'aider à t'évader.
    var complice: Bool = false
    /// Id de la relation `.partenaire` créée dans `Joueur.relations` quand vous vous mettez en couple.
    var relationId: UUID?

    var nomComplet: String { "\(prenom) \(nom)" }
}

/// Un petit-enfant (enfant d'un de tes enfants).
struct RetraitePetitEnfant: Codable, Identifiable, Equatable {
    var id = UUID()
    var prenom: String
    var genre: Genre
    var age: Int
    /// Id de la relation `.enfant` du joueur qui est son parent.
    var parentId: UUID
    var parentPrenom: String
    var lien: Int
    /// Âge du joueur lors de la dernière visite.
    var derniereVisite: Int?
}

/// Tout ce que le module retient sur la vieillesse du joueur. À stocker dans `Joueur.retraite` (optionnel).
struct RetraiteEtat: Codable, Equatable {
    /// Résidence actuelle (nil = chez soi, ou en cavale).
    var residenceId: String?
    /// Vrai si les enfants ou les services sociaux ont décidé à ta place.
    var imposee: Bool = false
    var anneesEnResidence: Int = 0
    /// Vigilance supplémentaire de la direction après des tentatives d'évasion (0-60).
    var vigilance: Int = 0
    /// Progression du tunnel creusé à la cuillère, en %.
    var tunnel: Int = 0
    var enCavale: Bool = false
    var anneesCavale: Int = 0
    var derniereResidenceId: String?
    var evasionsReussies: Int = 0
    var evasionsRatees: Int = 0
    var residents: [RetraiteResident] = []
    var petitsEnfants: [RetraitePetitEnfant] = []
    var anneesSansVisite: Int = 0
    /// Âge auquel tu as « évoqué l'héritage » (les visites augmentent l'année suivante).
    var heritageEvoqueAge: Int?
    var lotoParties: Int = 0
    var lotoGains: Int = 0
    var lotoBanniJusqua: Int?
    var lotsGagnes: [String] = []
    var voyagesFaits: [String] = []

    init() {}

    var enResidence: Bool { residenceId != nil }
    var residence: RetraiteResidence? { RetraiteCatalogue.residence(residenceId) }
    var residentsVivants: [RetraiteResident] { residents.filter { $0.vivant } }
    var romance: RetraiteResident? { residents.first { $0.vivant && $0.statut.estRomance } }

    // Décodage tolérant : une ancienne sauvegarde sans un champ récent reste lisible.
    enum CodingKeys: String, CodingKey {
        case residenceId, imposee, anneesEnResidence, vigilance, tunnel, enCavale, anneesCavale, derniereResidenceId
        case evasionsReussies, evasionsRatees, residents, petitsEnfants, anneesSansVisite, heritageEvoqueAge
        case lotoParties, lotoGains, lotoBanniJusqua, lotsGagnes, voyagesFaits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        residenceId = try c.decodeIfPresent(String.self, forKey: .residenceId)
        imposee = try c.decodeIfPresent(Bool.self, forKey: .imposee) ?? false
        anneesEnResidence = try c.decodeIfPresent(Int.self, forKey: .anneesEnResidence) ?? 0
        vigilance = try c.decodeIfPresent(Int.self, forKey: .vigilance) ?? 0
        tunnel = try c.decodeIfPresent(Int.self, forKey: .tunnel) ?? 0
        enCavale = try c.decodeIfPresent(Bool.self, forKey: .enCavale) ?? false
        anneesCavale = try c.decodeIfPresent(Int.self, forKey: .anneesCavale) ?? 0
        derniereResidenceId = try c.decodeIfPresent(String.self, forKey: .derniereResidenceId)
        evasionsReussies = try c.decodeIfPresent(Int.self, forKey: .evasionsReussies) ?? 0
        evasionsRatees = try c.decodeIfPresent(Int.self, forKey: .evasionsRatees) ?? 0
        residents = try c.decodeIfPresent([RetraiteResident].self, forKey: .residents) ?? []
        petitsEnfants = try c.decodeIfPresent([RetraitePetitEnfant].self, forKey: .petitsEnfants) ?? []
        anneesSansVisite = try c.decodeIfPresent(Int.self, forKey: .anneesSansVisite) ?? 0
        heritageEvoqueAge = try c.decodeIfPresent(Int.self, forKey: .heritageEvoqueAge)
        lotoParties = try c.decodeIfPresent(Int.self, forKey: .lotoParties) ?? 0
        lotoGains = try c.decodeIfPresent(Int.self, forKey: .lotoGains) ?? 0
        lotoBanniJusqua = try c.decodeIfPresent(Int.self, forKey: .lotoBanniJusqua)
        lotsGagnes = try c.decodeIfPresent([String].self, forKey: .lotsGagnes) ?? []
        voyagesFaits = try c.decodeIfPresent([String].self, forKey: .voyagesFaits) ?? []
    }
}

/// Ce que renvoie une action du module : le texte à afficher (et à écrire dans le journal)
/// et les signaux à transmettre au module Répercussions.
struct RetraiteResultat: Equatable {
    var texte: String
    var signaux: [String] = []
}

/// Ce que renvoie le passage d'une année.
struct RetraiteBilan: Equatable {
    var lignes: [String] = []
    var signaux: [String] = []
}

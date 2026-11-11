import Foundation

// MARK: - Genre

enum Genre: String, Codable, CaseIterable {
    case homme, femme
}

// MARK: - Stats

struct Stats: Codable, Equatable {
    var sante: Int
    var bonheur: Int
    var intelligence: Int
    var apparence: Int
    var karma: Int

    mutating func borner() {
        sante = Stats.borne(sante)
        bonheur = Stats.borne(bonheur)
        intelligence = Stats.borne(intelligence)
        apparence = Stats.borne(apparence)
        karma = Stats.borne(karma)
    }

    static func borne(_ v: Int) -> Int { min(100, max(0, v)) }

    static func aleatoire() -> Stats {
        Stats(
            sante: Int.random(in: 60...100),
            bonheur: Int.random(in: 50...100),
            intelligence: Int.random(in: 5...100),
            apparence: Int.random(in: 5...100),
            karma: Int.random(in: 40...70)
        )
    }
}

// MARK: - Diplômes et filières

enum Diplome: Int, Codable, Comparable, CaseIterable {
    case aucun = 0
    case ecoleObligatoire
    case bac
    case licence
    case master
    case doctorat

    static func < (a: Diplome, b: Diplome) -> Bool { a.rawValue < b.rawValue }

    var nom: String {
        switch self {
        case .aucun: return "Aucun"
        case .ecoleObligatoire: return "Fin de scolarité"
        case .bac: return "Bac"
        case .licence: return "Licence"
        case .master: return "Master"
        case .doctorat: return "Doctorat"
        }
    }
}

enum Filiere: String, Codable, CaseIterable, Identifiable {
    case medecine, droit, informatique, commerce, arts, sciences

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .medecine: return "Médecine"
        case .droit: return "Droit"
        case .informatique: return "Informatique"
        case .commerce: return "Commerce"
        case .arts: return "Arts"
        case .sciences: return "Sciences"
        }
    }

    /// Durée des études en années.
    var duree: Int {
        switch self {
        case .medecine: return 6
        case .droit: return 5
        default: return 3
        }
    }

    /// Frais par année.
    var fraisAnnuels: Int {
        switch self {
        case .medecine: return 4000
        case .droit, .commerce: return 3000
        default: return 2000
        }
    }

    var intelligenceMin: Int {
        switch self {
        case .medecine: return 70
        case .droit: return 55
        case .informatique, .sciences: return 50
        case .commerce: return 35
        case .arts: return 15
        }
    }

    var diplomeObtenu: Diplome {
        switch self {
        case .medecine: return .doctorat
        case .droit: return .master
        default: return .licence
        }
    }
}

struct Etudes: Codable, Equatable {
    var filiere: Filiere
    var annee: Int
}

// MARK: - Emploi

struct Metier: Identifiable, Hashable {
    let id: String
    let titre: String
    let salaire: Int
    let diplome: Diplome
    let filiere: Filiere?
    let intelligenceMin: Int
    let apparenceMin: Int
}

struct Emploi: Codable, Equatable {
    var metierId: String
    var titre: String
    var salaire: Int
    var annees: Int
    var performance: Int
    var niveau: Int
}

// MARK: - Relations

enum TypeRelation: String, Codable {
    case mere, pere, frere, soeur, ami, partenaire, enfant, ex

    var estParent: Bool { self == .mere || self == .pere }
}

struct Relation: Codable, Identifiable, Equatable {
    var id = UUID()
    var prenom: String
    var nom: String
    var genre: Genre
    var type: TypeRelation
    var age: Int
    var lien: Int
    var argent: Int = 0
    var vivant: Bool = true

    var nomComplet: String { "\(prenom) \(nom)" }

    /// « Ta mère », « Ton ami »… en début de phrase.
    var designation: String {
        let mot = libelle.lowercased()
        let voyelle = ["a", "e", "é", "i", "o", "u"].contains { mot.hasPrefix($0) }
        return (genre == .femme && !voyelle ? "Ta " : "Ton ") + mot
    }

    var libelle: String {
        switch type {
        case .mere: return "Mère"
        case .pere: return "Père"
        case .frere: return "Frère"
        case .soeur: return "Sœur"
        case .ami: return genre == .femme ? "Amie" : "Ami"
        case .partenaire: return genre == .femme ? "Copine" : "Copain"
        case .enfant: return genre == .femme ? "Fille" : "Fils"
        case .ex: return "Ex"
        }
    }
}

// MARK: - Journal

struct Annee: Codable, Identifiable, Equatable {
    var id = UUID()
    var age: Int
    var lignes: [String]
}

// MARK: - Joueur

struct Joueur: Codable, Equatable {
    var prenom: String
    var nom: String
    var genre: Genre
    var age: Int
    var ville: String
    var stats: Stats
    var argent: Int
    var diplome: Diplome
    var filiereDiplome: Filiere?
    var etudes: Etudes?
    var emploi: Emploi?
    var relations: [Relation]
    var vivant: Bool = true
    var causeDeces: String?
    var journal: [Annee]
    var evenementsVus: [String] = []
    var actionsAnnee: [String] = []
    var aQuitteEcole: Bool = false
    /// Biens, logement et crédits (module Shop).
    var possessions: Possessions?
    /// Secrets et chantage (module Secrets, voir docs/SECRETS.md).
    var secrets: SecretsEtat?
    /// Module Entreprises (docs/ENTREPRISES.md).
    var entreprises: EntreprisesEtat? = nil

    // États des modules (tous optionnels : les anciennes sauvegardes restent lisibles).
    var vie: VieEtat? = nil
    var casier: CasierJudiciaire? = nil
    var competences: CompetencesEtat? = nil
    var scolarite: ScolEtat? = nil
    var tele: TeleEtat? = nil
    var permis: PermisEtat? = nil
    var placements: PlacementsEtat? = nil
    var politique: PolEtat? = nil
    var telephone: PhoneEtat? = nil
    var loisirs: LoisirsEtat? = nil
    var animaux: AnimauxEtat? = nil
    var reves: RevesDeVie? = nil
    var monde: MondeEtat? = nil
    var fetes: FetesEtat? = nil
    var repercussions: RepercussionsEtat? = nil
    var reputationFamille: RepFamilleEtat? = nil
    var retraite: RetraiteEtat? = nil
    var succession: SuccessionEtat? = nil
    var voisinage: VoisinageEtat? = nil
    /// Dernier métier exercé (gardé pour la nécrologie, car `emploi` est vidé à la mort).
    var dernierEmploi: Emploi? = nil
    /// Emploi du module Métiers (Careers) et CV.
    var carriere: CareerJobState? = nil
    var historiqueCarriere: [CareerRecord]? = nil
    /// Module « Vivre à l'étranger » (docs/ETRANGER.md).
    var etranger: ExpatEtat? = nil
    /// Module « Jeu vivant » : jalons, projets, photo de l'an passé (docs/VIVANT.md).
    var jeuVivant: JeuVivantEtat? = nil
    /// Module Beauté : coiffeur, chirurgie esthétique, calvitie (docs/BEAUTE.md).
    var beaute: BeauteEtat? = nil

    var nomComplet: String { "\(prenom) \(nom)" }

    /// Accorde un mot selon le genre du joueur.
    func g(_ masculin: String, _ feminin: String) -> String {
        genre == .femme ? feminin : masculin
    }

    var mere: Relation? { relations.first { $0.type == .mere } }
    var pere: Relation? { relations.first { $0.type == .pere } }
    var amis: [Relation] { relations.filter { $0.type == .ami && $0.vivant } }

    /// Niveau scolaire automatique (avant le bac).
    var niveauScolaire: String? {
        guard !aQuitteEcole, diplome < .bac else { return nil }
        switch age {
        case 3...5: return "Maternelle"
        case 6...10: return "École primaire"
        case 11...14: return "Collège"
        case 15...18: return "Lycée"
        default: return nil
        }
    }

    var occupation: String {
        if !vivant { return g("Décédé", "Décédée") }
        if let e = emploi { return e.titre }
        if let e = etudes { return g("Étudiant", "Étudiante") + " en \(e.filiere.nom.lowercased())" }
        if let n = niveauScolaire { return n }
        if age < 3 { return "Bébé à plein temps" }
        if age >= 65 { return g("Retraité", "Retraitée") }
        return "Sans emploi"
    }
}

extension Joueur {
    /// État du module Étranger, créé à la volée pour les vieilles sauvegardes.
    var etatExpat: ExpatEtat { etranger ?? ExpatEtat.naissance(pays: "fr", ville: ville, age: age) }
}

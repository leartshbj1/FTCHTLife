import Foundation

// Module Gloire : gérer sa célébrité (livre, pubs, fêtes, séances photo, plateaux télé, attaché de presse)
// et poursuivre quelqu'un en justice (procès). Voir docs/GLOIRE.md.
// La gloire elle-même (0…100) est la célébrité du module Télé (`TeleEtat`) : une seule jauge pour tout le jeu.

// MARK: - Effets

/// Effets d'une issue du module (tous facultatifs).
struct GloireEffets: Codable, Equatable {
    var bonheur: Int?
    var sante: Int?
    var intelligence: Int?
    var apparence: Int?
    var karma: Int?
    var argent: Int?
    var gloire: Int?
    var nouvelAmi: Bool?
    /// Signal envoyé aux répercussions (docs/REPERCUSSIONS.md).
    var signal: String?
    /// Compte comme un scandale (statistique du module).
    var scandale: Bool?
    /// Cause de mort (overdose, accident…). Le mode Shkurtaaa peut l'empêcher.
    var deces: String?
}

/// Une issue possible : texte + effets. `chance` = poids relatif.
struct GloireIssue: Codable, Equatable {
    var chance: Double?
    var texte: String
    var effets: GloireEffets?
}

/// Proposition qui tombe pendant une activité : accepter ou refuser.
struct GloireDilemme: Codable, Equatable {
    /// Probabilité que la proposition arrive (0…1).
    var chance: Double
    var texte: String
    var accepter: String
    var refuser: String
    var siAccepte: [GloireIssue]
    var siRefuse: [GloireIssue]
}

// MARK: - Catalogue

/// Genre de livre.
struct GloireGenreLivre: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var emoji: String
    var description: String
    var ageMin: Int
    var gloireMin: Int
    /// Ventes de base d'un livre moyen d'un inconnu.
    var ventes: Int
    /// Poids de la gloire dans les ventes (2 = une autobiographie se vend surtout sur ton nom).
    var poidsGloire: Double
    /// Compétence qui aide (docs/COMPETENCES.md), facultative.
    var competence: String?
    /// Titres possibles. Variables : {prenom}, {nom}.
    var titres: [String]
    var critiquesBonnes: [String]
    var critiquesMoyennes: [String]
    var critiquesMauvaises: [String]
}

/// Offre de publicité.
struct GloirePub: Codable, Identifiable, Equatable {
    var id: String
    var marque: String
    var produit: String
    var emoji: String
    var gloireMin: Int
    var ageMin: Int
    var ageMax: Int?
    /// Cachet [min, max] pour une gloire de 50.
    var cachet: [Int]
    var gloire: Int
    /// Produit douteux : mieux payé, mais le karma trinque et ça peut tourner au scandale.
    var louche: Bool?
    /// Probabilité que ça tourne mal (0…1).
    var risque: Double?
    var textes: [String]
    var textesRates: [String]?
    var effetsRates: GloireEffets?
}

/// Activité de gloire : fête, séance photo ou plateau télé.
struct GloireActivite: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var emoji: String
    var description: String
    var ageMin: Int
    var gloireMin: Int
    /// Prix à payer (0 = invité).
    var prix: Int
    /// Cachet [min, max] pour une gloire de 50 (activités payées).
    var cachet: [Int]?
    /// Stat qui fait réussir : apparence, intelligence, bonheur, karma, sante, gloire.
    var stat: String
    var succes: [GloireIssue]
    var rates: [GloireIssue]
    var dilemmes: [GloireDilemme]?
}

struct GloireCatalogue: Codable {
    var livres: [GloireGenreLivre]
    var pubs: [GloirePub]
    var fetes: [GloireActivite]
    var shootings: [GloireActivite]
    var plateaux: [GloireActivite]

    static let vide = GloireCatalogue(livres: [], pubs: [], fetes: [], shootings: [], plateaux: [])

    /// Lu une fois dans Data/Gloire/catalogue.json.
    static let charge: GloireCatalogue = {
        guard let url = DonneesJSON.dossierData?.appendingPathComponent("Gloire/catalogue.json"),
              let data = try? Data(contentsOf: url) else { return .vide }
        do {
            return try JSONDecoder().decode(GloireCatalogue.self, from: data)
        } catch {
            print("⚠️ Catalogue gloire invalide : \(error)")
            return .vide
        }
    }()

    func activite(_ id: String) -> GloireActivite? {
        (fetes + shootings + plateaux).first { $0.id == id }
    }
}

// MARK: - État sauvegardé (Joueur.gloire)

struct GloireLivre: Codable, Identifiable, Equatable {
    var id = UUID()
    var titre: String
    var genre: String
    var age: Int
    /// Note de la critique, 1 à 5 étoiles.
    var note: Int
    var ventesAnnee: Int
    var ventesTotales: Int
    var revenus: Int
    var droitsEuro: Double
    var adapte: Bool = false
}

struct GloireEtat: Codable, Equatable {
    var livres: [GloireLivre] = []
    var pubs: Int = 0
    var revenusPubs: Int = 0
    var fetes: Int = 0
    var shootings: Int = 0
    var plateaux: Int = 0
    var scandales: Int = 0
    /// Attaché·e de presse engagé·e (coûte chaque année, entretient la gloire).
    var attachePresse: Bool = false
    var attacheNom: String?
    /// Dossiers de procès.
    var proces: [ProcesDossier] = []
}

// MARK: - Procès

/// Cible fixe d'un procès (entreprise, institution…). Les proches viennent de `Joueur.relations`.
struct ProcesCible: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var emoji: String
    var description: String
    /// Famille de motifs : employeur, entreprise, medecin, presse, etat, voisin.
    var type: String
    /// emploi (a un travail), ancienEmploi (a déjà travaillé), prison (est passé par la prison), gloire (gloire ≥ 20).
    var condition: String?
    /// Force de la défense adverse (0…40) : retirée des chances.
    var defense: Int
    /// Multiplicateur des dommages (une multinationale paie plus qu'un voisin).
    var poche: Double
}

struct ProcesMotif: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    /// Types de cibles concernés : proche, employeur, entreprise, medecin, presse, etat, voisin.
    var cibles: [String]
    /// Solidité du dossier, 0…100.
    var solidite: Int
    /// Dommages et intérêts [min, max].
    var dommages: [Int]
    /// Procédure abusive : en cas de défaite, amende civile en plus.
    var frivole: Bool?
    /// Textes du verdict. Variables : {cible}, {montant}, {avocat}.
    var victoire: [String]
    var defaite: [String]
}

struct ProcesAvocat: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var emoji: String
    var description: String
    var honoraires: Int
    /// Bonus de chances (points).
    var bonus: Int
    /// Part des dommages prise par l'avocat en cas de victoire (0…1).
    var pourcentage: Double?
    /// "droit" : seulement avec un diplôme de droit ou un bon niveau d'éloquence.
    var condition: String?
}

struct ProcesStrategie: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var emoji: String
    var description: String
    /// Stat utilisée : intelligence, apparence, karma, bonheur.
    var stat: String
    /// Écart de chances maximal (± points) selon la stat.
    var amplitude: Int
    var textes: [String]
}

struct ProcesCatalogue: Codable {
    var cibles: [ProcesCible]
    var motifs: [ProcesMotif]
    var avocats: [ProcesAvocat]
    var strategies: [ProcesStrategie]
    /// Phrases de l'audience préliminaire. Variables : {cible}, {motif}.
    var audiences: [String]
    /// Offres d'accord à l'amiable. Variables : {cible}, {montant}.
    var accords: [String]

    static let vide = ProcesCatalogue(cibles: [], motifs: [], avocats: [], strategies: [], audiences: [], accords: [])

    /// Lu une fois dans Data/Gloire/proces.json.
    static let charge: ProcesCatalogue = {
        guard let url = DonneesJSON.dossierData?.appendingPathComponent("Gloire/proces.json"),
              let data = try? Data(contentsOf: url) else { return .vide }
        do {
            return try JSONDecoder().decode(ProcesCatalogue.self, from: data)
        } catch {
            print("⚠️ Catalogue procès invalide : \(error)")
            return .vide
        }
    }()
}

/// Procès terminé, gardé dans l'historique.
struct ProcesDossier: Codable, Identifiable, Equatable {
    var id = UUID()
    var age: Int
    var cible: String
    var motif: String
    /// gagne, perdu, accord
    var issue: String
    /// Argent reçu (positif) ou payé (négatif), honoraires compris.
    var bilan: Int
}

/// Procès en cours (dans l'écran, pas sauvegardé) : de l'audience au verdict.
struct ProcesAudience: Equatable {
    enum Phase: Equatable { case accord, plaidoirie, verdict }

    var cibleNom: String
    var cibleEmoji: String
    /// Id de la relation poursuivie (si c'est un proche).
    var relation: UUID?
    var cibleType: String
    var motif: ProcesMotif
    var avocat: ProcesAvocat
    /// Chances de gagner avant la plaidoirie (0…1).
    var chance: Double
    /// Dommages demandés.
    var demande: Int
    /// Offre d'accord à l'amiable (nil = pas d'offre).
    var offre: Int?
    var texteAudience: String
    var texteOffre: String?
    var phase: Phase
    var texteVerdict: String = ""
    var gagne: Bool = false
}

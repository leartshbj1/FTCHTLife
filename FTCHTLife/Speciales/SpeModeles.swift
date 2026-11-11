import Foundation

// Carrières spéciales (MMA, sportif pro, mannequin, réalisateur, musicien), salle de sport, musée et investissements.
// Voir docs/CARRIERES_SPECIALES.md.

// MARK: - Types de carrière

enum SpeCarriereType: String, Codable, CaseIterable, Identifiable {
    case mma, sport, mannequin, cinema, musique

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .mma: return "Combattant MMA"
        case .sport: return "Sportif pro"
        case .mannequin: return "Mannequin"
        case .cinema: return "Réalisateur"
        case .musique: return "Musicien"
        }
    }

    func nom(_ femme: Bool) -> String {
        switch self {
        case .mma: return femme ? "Combattante MMA" : "Combattant MMA"
        case .sport: return femme ? "Sportive pro" : "Sportif pro"
        case .mannequin: return "Mannequin"
        case .cinema: return femme ? "Réalisatrice" : "Réalisateur"
        case .musique: return femme ? "Musicienne" : "Musicien"
        }
    }

    var emoji: String {
        switch self {
        case .mma: return "🥊"
        case .sport: return "🏅"
        case .mannequin: return "📸"
        case .cinema: return "🎬"
        case .musique: return "🎸"
        }
    }

    var accroche: String {
        switch self {
        case .mma: return "Salle, sparring, pesée, combats. Vise la ceinture."
        case .sport: return "Centre de formation, transferts, sélection nationale."
        case .mannequin: return "Castings, défilés, campagnes. Ton visage est ton outil."
        case .cinema: return "Écris, finance et tourne tes films. Festivals et box-office."
        case .musique: return "Solo ou en groupe. Chansons, albums, tournées, label."
        }
    }
}

// MARK: - État d'une carrière

struct SpeFilm: Codable, Equatable, Identifiable {
    var id = UUID()
    var titre: String
    var genre: String
    /// 0 court-métrage, 1 petit, 2 moyen, 3 gros budget.
    var taille: Int
    var budget: Int
    /// 0 inconnus, 1 acteurs connus, 2 une star.
    var casting: Int
    /// Le joueur a payé lui-même (il touche les bénéfices).
    var autoFinance: Bool
    var ageTournage: Int
    var sorti: Bool = false
    var critique: Int = 0
    var recettes: Int = 0
    var prix: [String] = []
}

struct SpeAlbum: Codable, Equatable, Identifiable {
    var id = UUID()
    var titre: String
    var age: Int
    var note: Int
    var ventes: Int
    var certification: String?
}

struct SpeCarriere: Codable, Equatable {
    var type: SpeCarriereType
    var ageDebut: Int
    /// Rang de 0 à 5 (voir SpeCatalogue.rangs).
    var niveau: Int = 0
    /// Réputation dans le milieu (0-100).
    var reputation: Int = 10
    /// Forme physique, ou inspiration pour les artistes (0-100).
    var forme: Int = 70
    var annees: Int = 0
    /// Années d'arrêt restantes (blessure).
    var blessure: Int = 0
    var gainsTotal: Int = 0
    var actionsAnnee: [String] = []
    var palmares: [String] = []
    var bilan: [String] = []
    var coach: String = ""

    // MMA
    var victoires: Int = 0
    var defaites: Int = 0
    var ko: Int = 0
    var serie: Int = 0
    var ceintures: Int = 0
    var commotions: Int = 0
    var combatsAnnee: Int = 0

    // Sport
    var sport: String = ""
    var club: String = ""
    var titres: Int = 0
    var selections: Int = 0
    var performance: Int = 50
    var saisonsRatees: Int = 0

    // Mannequin
    var agence: String = ""
    var campagnes: Int = 0
    var defiles: Int = 0
    var abonnes: Int = 0

    // Cinéma
    var films: [SpeFilm] = []
    var projet: SpeFilm? = nil
    var scenarios: Int = 0

    // Musique
    var nomScene: String = ""
    var genre: String = ""
    var enGroupe: Bool = false
    var label: String = ""
    var fans: Int = 0
    var chansons: Int = 0
    var albums: [SpeAlbum] = []
    var offreLabel: String = ""

    // Bilan de l'année (optionnels : les sauvegardes d'avant restent lisibles)
    /// Valeurs au début de l'année (réputation, gains, fans…) pour calculer les écarts du bilan.
    var instantane: [String: Int]? = nil
    /// Faits marquants de l'année (combats, prix…), affichés dans le bilan.
    var faits: [String]? = nil

    init(type: SpeCarriereType, ageDebut: Int) {
        self.type = type
        self.ageDebut = ageDebut
    }
}

struct SpeArchive: Codable, Equatable, Identifiable {
    var id = UUID()
    var type: SpeCarriereType
    var rang: String
    var ageDebut: Int
    var ageFin: Int
    var resume: String
}

// MARK: - Musée

struct SpeOeuvre: Codable, Equatable, Identifiable {
    var id: String
    var nom: String
    var auteur: String
    var theme: String
    var valeur: Int
    var prestige: Int
}

struct SpeMusee: Codable, Equatable {
    var nom: String
    var theme: String
    /// 0 petit, 1 moyen, 2 grand, 3 national.
    var taille: Int
    var ageOuverture: Int
    var prestige: Int = 10
    var notoriete: Int = 5
    var prixBillet: Int = 8
    var collection: [SpeOeuvre] = []
    var visiteursAn: Int = 0
    var expoAnnee: String = ""
    var actionsAnnee: [String] = []
    var bilan: [String] = []
    var resultatAn: Int = 0
    /// Visiteurs et prestige de l'année d'avant (bilan).
    var visiteursAvant: Int? = nil
    var prestigeAvant: Int? = nil

    init(nom: String, theme: String, taille: Int, ageOuverture: Int) {
        self.nom = nom
        self.theme = theme
        self.taille = taille
        self.ageOuverture = ageOuverture
    }
}

// MARK: - Investissements

enum SpeInvestType: String, Codable, CaseIterable, Identifiable {
    case combattant, film, album, club, agence

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .combattant: return "Sponsoriser un combattant"
        case .film: return "Coproduire un film"
        case .album: return "Financer un album"
        case .club: return "Racheter un club de sport"
        case .agence: return "Monter une agence de mannequins"
        }
    }

    var emoji: String {
        switch self {
        case .combattant: return "🥊"
        case .film: return "🎞️"
        case .album: return "💿"
        case .club: return "🏟️"
        case .agence: return "💄"
        }
    }

    var description: String {
        switch self {
        case .combattant: return "Tu paies son camp, tu touches une part de ses bourses. Un KO peut tout effacer."
        case .film: return "Tout se joue à la sortie : flop, succès d'estime ou carton. Paiement au bout de deux ans."
        case .album: return "Un artiste prometteur. Si ça décolle, tu touches une part des ventes."
        case .club: return "Tu deviens président. Les supporters, eux, ne pardonnent rien."
        case .agence: return "Des rendements réguliers, tant que les scandales restent loin."
        }
    }

    /// Montants proposés (trois paliers).
    var paliers: [Int] {
        switch self {
        case .combattant: return [20_000, 100_000, 500_000]
        case .film: return [250_000, 2_000_000, 15_000_000]
        case .album: return [30_000, 200_000, 1_000_000]
        case .club: return [3_000_000, 40_000_000, 400_000_000]
        case .agence: return [300_000, 1_500_000, 6_000_000]
        }
    }
}

struct SpeInvest: Codable, Equatable, Identifiable {
    var id = UUID()
    var type: SpeInvestType
    var nom: String
    var mise: Int
    var valeur: Int
    var ageDebut: Int
    var annees: Int = 0
    var termine: Bool = false
    var dernier: String = ""
}

// MARK: - État du module

struct SpeEtat: Codable, Equatable {
    var carriere: SpeCarriere? = nil
    var anciennes: [SpeArchive] = []

    // Salle de sport (ouverte à tous)
    /// 0 aucun, 1 salle de quartier, 2 club de boxe et MMA, 3 salle premium.
    var abonnement: Int = 0
    var salleNom: String = ""
    var force: Int = 15
    var technique: Int = 5
    var cardio: Int = 20
    var actionsSalle: [String] = []

    var musee: SpeMusee? = nil
    var anciensMusees: [String] = []
    var investissements: [SpeInvest] = []
    var cartesVues: [String] = []

    /// Bilan de l'année à afficher en pop-up au passage d'année (nil = déjà vu).
    var bilan: SpeBilanAnnee? = nil
    /// Emploi normal tel qu'il était l'an dernier (bilan des métiers).
    var metierAvant: SpeMetierInstantane? = nil
    /// Marqueurs de l'année écoulée (film_succes, defaite_ko…) : ils déclenchent des cartes de réaction.
    var marqueurs: [String]? = nil
    /// Marqueurs posés pendant l'année en cours (combats, clips…), versés dans `marqueurs` au passage d'année.
    var marqueursAnnee: [String]? = nil

    init() {}

    mutating func marquer(_ m: String) {
        var l = marqueursAnnee ?? []
        if !l.contains(m) { l.append(m) }
        marqueursAnnee = l
    }
}

// MARK: - Bilan de l'année

struct SpeBilanLigne: Codable, Equatable, Identifiable {
    var id = UUID()
    var emoji: String
    var libelle: String
    var valeur: String
    /// 1 bonne nouvelle, -1 mauvaise, 0 neutre.
    var ton: Int = 0
}

struct SpeBilanSection: Codable, Equatable, Identifiable {
    var id = UUID()
    var emoji: String
    var titre: String
    var sousTitre: String
    /// Le grand chiffre de l'année (entrées, combats, note de saison…).
    var grosChiffre: String = ""
    var grosLibelle: String = ""
    var lignes: [SpeBilanLigne] = []
    var faits: [String] = []
}

struct SpeBilanAnnee: Codable, Equatable, Identifiable {
    var id = UUID()
    var age: Int
    var sections: [SpeBilanSection]
    /// Carrière spéciale, musée ou investissements : le mode rapide s'arrête pour le montrer.
    var important: Bool
}

struct SpeMetierInstantane: Codable, Equatable {
    var titre: String
    var salaire: Int
    var niveau: Int
    var performance: Int
    var entreprise: String
}

// MARK: - Cartes (Data/SpecialesEvents)

/// Effets propres au module dans une issue de carte.
struct SpeEffets: Codable, Equatable {
    var reputation: Int?
    var forme: Int?
    var niveau: Int?
    var blessure: Int?
    var gainPct: Int?
    var fansPct: Int?
    var force: Int?
    var technique: Int?
    var cardio: Int?
    var prestige: Int?
    var visiteursPct: Int?
    var collectionPct: Int?
    var investPct: Int?
    var finCarriere: Bool?
    var signal: String?
}

struct SpeIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    var effects: Effets?
    var spe: SpeEffets?
}

struct SpeChoix: Codable, Equatable {
    var label: String
    var outcomes: [SpeIssue]
    var cost: Int?
    var costPct: Int?
    var requiresSkill: [String: Int]?
    var risk: String?
}

struct SpeCarte: Codable, Equatable, Identifiable {
    var id: String
    var carriere: String
    var minNiveau: Int?
    var maxNiveau: Int?
    var minAge: Int?
    var maxAge: Int?
    var sports: [String]?
    var genres: [String]?
    /// Cartes « invest » : types d'investissement concernés (combattant, film, album, club, agence).
    var types: [String]?
    /// Carte de réaction : n'arrive que l'année où l'un de ces marqueurs est posé (voir docs).
    var marqueurs: [String]?
    var groupe: Bool?
    var unique: Bool?
    var poids: Double?
    var text: String
    var choices: [SpeChoix]
}

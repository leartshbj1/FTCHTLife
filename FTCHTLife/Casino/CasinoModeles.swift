import Foundation

// MARK: - Jeux

/// Tous les jeux d'argent du module casino.
enum CasinoJeu: String, Codable, CaseIterable, Identifiable {
    case blackjack, roulette, machines, videoPoker, holdem, paris, courses, loto, grattage, pileOuFace, des, roue, bonneteau

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .blackjack: return "Blackjack"
        case .roulette: return "Roulette"
        case .machines: return "Machines à sous"
        case .videoPoker: return "Vidéo poker"
        case .holdem: return "Poker Texas Hold'em"
        case .paris: return "Paris sportifs"
        case .courses: return "Courses hippiques"
        case .loto: return "Loto"
        case .grattage: return "Jeux à gratter"
        case .pileOuFace: return "Quitte ou double"
        case .des: return "Dés"
        case .roue: return "Roue de la fortune"
        case .bonneteau: return "Bonneteau"
        }
    }

    var icone: String {
        switch self {
        case .blackjack: return "suit.club.fill"
        case .roulette: return "circle.circle.fill"
        case .machines: return "dollarsign.square.fill"
        case .videoPoker: return "rectangle.on.rectangle.angled"
        case .holdem: return "suit.spade.fill"
        case .paris: return "sportscourt.fill"
        case .courses: return "flag.checkered"
        case .loto: return "ticket.fill"
        case .grattage: return "rectangle.and.pencil.and.ellipsis"
        case .pileOuFace: return "centsign.circle.fill"
        case .des: return "dice.fill"
        case .roue: return "sun.max.fill"
        case .bonneteau: return "cup.and.saucer.fill"
        }
    }

    var description: String {
        switch self {
        case .blackjack: return "Approche-toi de 21 sans exploser. Le croupier, lui, ne transpire jamais."
        case .roulette: return "Une bille, 37 cases, et toute ton épargne."
        case .machines: return "Tirer sur un levier jusqu'à oublier son propre prénom."
        case .videoPoker: return "Du poker sans adversaire. Juste toi et ta solitude."
        case .holdem: return "Contre des inconnus qui portent des lunettes de soleil à l'intérieur."
        case .paris: return "Parier sur des équipes que tu ne sais pas situer sur une carte."
        case .courses: return "Des chevaux courent, ton loyer aussi."
        case .loto: return "Choisir 5 numéros et un rêve."
        case .grattage: return "Gratter avec une pièce de 2 € pour en perdre 5."
        case .pileOuFace: return "Une pièce, deux faces, zéro stratégie."
        case .des: return "Lancer deux dés et prier."
        case .roue: return "Elle tourne. Ton estomac aussi."
        case .bonneteau: return "Trois gobelets, une bille, un monsieur très sympa. Trop sympa."
        }
    }
}

// MARK: - Lieux

/// Les endroits où l'on peut jouer. Chacun a ses jeux et ses limites de mise.
enum CasinoLieu: String, Codable, CaseIterable, Identifiable {
    case bar, casino, palais, tripot

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .bar: return "Bar-tabac Le Fer à Cheval"
        case .casino: return "Casino du Lac Morne"
        case .palais: return "Le Palais Doré"
        case .tripot: return "L'Arrière-Boutique"
        }
    }

    var sousTitre: String {
        switch self {
        case .bar: return "Loto, grattage, paris et un comptoir qui colle."
        case .casino: return "Moquette à motifs, lumière éternelle, pas d'horloge."
        case .palais: return "Réservé aux gros joueurs. Le champagne est gratuit, le reste non."
        case .tripot: return "Clandestin. On ne pose pas de questions, on ne fait pas de reçus."
        }
    }

    var icone: String {
        switch self {
        case .bar: return "cup.and.saucer.fill"
        case .casino: return "building.columns.fill"
        case .palais: return "crown.fill"
        case .tripot: return "door.left.hand.closed"
        }
    }

    var miseMin: Int {
        switch self {
        case .bar: return 2
        case .casino: return 10
        case .palais: return 1_000
        case .tripot: return 50
        }
    }

    var miseMax: Int {
        switch self {
        case .bar: return 500
        case .casino: return 10_000
        case .palais: return 5_000_000
        case .tripot: return 100_000
        }
    }

    var jeux: [CasinoJeu] {
        switch self {
        case .bar: return [.grattage, .loto, .paris, .courses, .machines]
        case .casino: return [.blackjack, .roulette, .machines, .videoPoker, .roue, .des]
        case .palais: return [.blackjack, .roulette, .machines, .videoPoker, .roue, .paris]
        case .tripot: return [.holdem, .des, .bonneteau, .pileOuFace]
        }
    }

    /// Les lieux où une interdiction de casino s'applique (le tripot s'en moque).
    var respecteInterdiction: Bool { self != .tripot }
}

// MARK: - Statut VIP

enum CasinoVIP: Int, Codable, CaseIterable, Comparable {
    case visiteur = 0, habitue, bronze, argent, or, platine, baleine

    static func < (a: CasinoVIP, b: CasinoVIP) -> Bool { a.rawValue < b.rawValue }

    /// Total misé (sur toute la vie) nécessaire pour atteindre ce statut.
    var seuil: Int {
        switch self {
        case .visiteur: return 0
        case .habitue: return 10_000
        case .bronze: return 50_000
        case .argent: return 250_000
        case .or: return 1_000_000
        case .platine: return 10_000_000
        case .baleine: return 100_000_000
        }
    }

    var nom: String {
        switch self {
        case .visiteur: return "Visiteur"
        case .habitue: return "Habitué"
        case .bronze: return "Carte Bronze"
        case .argent: return "Carte Argent"
        case .or: return "Carte Or"
        case .platine: return "Carte Platine"
        case .baleine: return "Baleine"
        }
    }

    var avantage: String {
        switch self {
        case .visiteur: return "Le vigile connaît ton visage. Pas ton prénom."
        case .habitue: return "Le barman te sert ton café sans demander."
        case .bronze: return "Cocktails gratuits. Ils sont très dilués."
        case .argent: return "Une suite offerte chaque année où tu joues."
        case .or: return "Accès au Palais Doré et un serveur qui rit à tes blagues."
        case .platine: return "Jet privé pour aller perdre ailleurs."
        case .baleine: return "Le directeur t'appelle « mon ami ». Il ment."
        }
    }

    static func pour(totalMise: Int) -> CasinoVIP {
        allCases.last { totalMise >= $0.seuil } ?? .visiteur
    }

    var suivant: CasinoVIP? { CasinoVIP(rawValue: rawValue + 1) }
}

// MARK: - Statistiques

struct CasinoStatJeu: Codable, Equatable {
    var parties: Int = 0
    var mise: Int = 0
    var gagne: Int = 0
    var net: Int { gagne - mise }
}

/// Tout ce que le casino retient sur le joueur pendant une vie.
struct CasinoEtat: Codable, Equatable {
    /// Addiction au jeu, 0 à 100 (gardée en décimal pour monter doucement).
    var addictionBrute: Double = 0
    var totalMise: Int = 0
    var totalGagne: Int = 0
    var plusGrosGain: Int = 0
    var plusGrossePerte: Int = 0
    var jackpots: Int = 0

    // Année en cours (remis à zéro à chaque +1 an).
    var miseAnnee: Int = 0
    var gagneAnnee: Int = 0
    var partiesAnnee: Int = 0
    var anneesSansJouer: Int = 0

    // Interdiction de casino.
    var interditJusqua: Int? = nil
    var raisonInterdiction: String? = nil
    /// Soupçons de triche (comptage de cartes, etc.) : à 100, on est banni.
    var soupcons: Int = 0

    // Usurier.
    var detteUsurier: Int = 0
    var anneesDetteImpayee: Int = 0

    // Soins.
    var reunionsJA: Int = 0
    var curesSuivies: Int = 0
    /// Plus haut niveau d'addiction atteint : sert aux rechutes.
    var addictionMax: Int = 0

    // Gros lots progressifs.
    var jackpotLoto: Int = 3_000_000
    var jackpotMachine: Int = 250_000

    var parJeu: [String: CasinoStatJeu] = [:]

    var addiction: Int { min(100, max(0, Int(addictionBrute.rounded()))) }
    var vip: CasinoVIP { CasinoVIP.pour(totalMise: totalMise) }
    var netVie: Int { totalGagne - totalMise }
    var netAnnee: Int { gagneAnnee - miseAnnee }

    func estInterdit(age: Int) -> Bool {
        guard let fin = interditJusqua else { return false }
        return age < fin
    }

    mutating func ajouterAddiction(_ delta: Double) {
        addictionBrute = min(100, max(0, addictionBrute + delta))
        addictionMax = max(addictionMax, addiction)
    }
}

// MARK: - Niveaux d'addiction

enum CasinoNiveauAddiction: Int {
    case aucune, occasionnel, habitue, accro, compulsif

    static func pour(_ addiction: Int) -> CasinoNiveauAddiction {
        switch addiction {
        case ..<10: return .aucune
        case ..<30: return .occasionnel
        case ..<50: return .habitue
        case ..<75: return .accro
        default: return .compulsif
        }
    }

    var nom: String {
        switch self {
        case .aucune: return "Aucune"
        case .occasionnel: return "Joueur du dimanche"
        case .habitue: return "Habitué"
        case .accro: return "Accro"
        case .compulsif: return "Compulsif"
        }
    }

    var description: String {
        switch self {
        case .aucune: return "Tu sais à peine ce qu'est un jeton."
        case .occasionnel: return "Un petit ticket de temps en temps. Rien de grave. Pour l'instant."
        case .habitue: return "Le croupier connaît ta boisson préférée."
        case .accro: return "Tu rêves en cerises et en sept rouges."
        case .compulsif: return "Tu as parié sur la couleur du prochain bus. Et perdu."
        }
    }
}

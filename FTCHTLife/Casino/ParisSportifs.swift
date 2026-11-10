import SwiftUI

// MARK: - Sports

/// Façon dont un sport produit ses scores.
enum ParisModeScore {
    /// Buts/points rares : loi de Poisson de moyenne donnée (par équipe, à forces égales).
    case poisson(Double)
    /// Gros scores : loi normale (moyenne, écart-type).
    case gauss(Double, Double)
    /// Manches gagnantes (2 = au meilleur des 3).
    case sets(Int)
    /// Mènes jusqu'à 13.
    case petanque
    /// Essais, transformations et pénalités.
    case rugby
}

enum ParisSport: CaseIterable {
    case football, rugby, tennis, basket, handball, curling, petanque, tongs, lits, polochons, escargots, corde, pingPong

    var nom: String {
        switch self {
        case .football: return "Football"
        case .rugby: return "Rugby"
        case .tennis: return "Tennis"
        case .basket: return "Basket"
        case .handball: return "Handball"
        case .curling: return "Curling"
        case .petanque: return "Pétanque"
        case .tongs: return "Lancer de tongs"
        case .lits: return "Course de lits d'hôpital"
        case .polochons: return "Bataille de polochons"
        case .escargots: return "Course d'escargots"
        case .corde: return "Tir à la corde"
        case .pingPong: return "Ping-pong sous-marin"
        }
    }

    var emoji: String {
        switch self {
        case .football: return "⚽️"
        case .rugby: return "🏉"
        case .tennis: return "🎾"
        case .basket: return "🏀"
        case .handball: return "🤾"
        case .curling: return "🥌"
        case .petanque: return "⚫️"
        case .tongs: return "🩴"
        case .lits: return "🛏️"
        case .polochons: return "🪶"
        case .escargots: return "🐌"
        case .corde: return "🪢"
        case .pingPong: return "🏓"
        }
    }

    /// Sport à joueurs individuels (sinon : équipes).
    var individuel: Bool {
        switch self {
        case .tennis, .tongs, .pingPong: return true
        default: return false
        }
    }

    var nulPossible: Bool {
        switch self {
        case .football, .rugby, .handball: return true
        default: return false
        }
    }

    var mode: ParisModeScore {
        switch self {
        case .football: return .poisson(1.35)
        case .rugby: return .rugby
        case .tennis: return .sets(2)
        case .basket: return .gauss(82, 9)
        case .handball: return .gauss(27, 3.5)
        case .curling: return .poisson(5)
        case .petanque: return .petanque
        case .tongs: return .gauss(31, 5)
        case .lits: return .poisson(8)
        case .polochons: return .poisson(3)
        case .escargots: return .gauss(42, 9)
        case .corde: return .sets(2)
        case .pingPong: return .sets(3)
        }
    }

    /// Unité affichée après le score.
    var unite: String {
        switch self {
        case .tongs: return " m"
        case .lits: return " tours"
        case .escargots: return " cm"
        default: return ""
        }
    }

    /// Écart à partir duquel une victoire est « large ».
    var ecartLarge: Int {
        switch self {
        case .football: return 3
        case .rugby: return 20
        case .tennis: return 2
        case .basket: return 15
        case .handball: return 7
        case .curling: return 4
        case .petanque: return 8
        case .tongs: return 8
        case .lits: return 4
        case .polochons: return 3
        case .escargots: return 15
        case .corde: return 2
        case .pingPong: return 3
        }
    }
}

// MARK: - Modèles

enum ParisIssue: Hashable {
    case un, nul, deux

    var code: String {
        switch self {
        case .un: return "1"
        case .nul: return "N"
        case .deux: return "2"
        }
    }
}

struct ParisMatch: Identifiable {
    let id: Int
    let sport: ParisSport
    let nomA: String
    let nomB: String
    /// Forces cachées (1 à 10).
    let forceA: Double
    let forceB: Double
    let cote1: Double
    let coteN: Double?
    let cote2: Double
    var scoreA: Int? = nil
    var scoreB: Int? = nil
    var commentaire: String? = nil

    var issue: ParisIssue? {
        guard let a = scoreA, let b = scoreB else { return nil }
        if a > b { return .un }
        if a < b { return .deux }
        return .nul
    }

    var issues: [ParisIssue] { coteN == nil ? [.un, .deux] : [.un, .nul, .deux] }

    func cote(_ i: ParisIssue) -> Double {
        switch i {
        case .un: return cote1
        case .nul: return coteN ?? 1
        case .deux: return cote2
        }
    }

    func libelle(_ i: ParisIssue) -> String {
        switch i {
        case .un: return "Victoire \(nomA)"
        case .nul: return "Match nul \(nomA) – \(nomB)"
        case .deux: return "Victoire \(nomB)"
        }
    }
}

/// Un pari absurde sur un événement du match.
struct ParisFou: Identifiable {
    let id: Int
    let match: Int
    let texte: String
    let proba: Double
    let cote: Double
    var arrive: Bool? = nil
}

struct ParisFouModele {
    let texte: String
    let proba: Double
    /// Sports concernés (vide = tous).
    let sports: [ParisSport]
}

/// Une sélection sur un ticket.
enum ParisChoix: Hashable {
    case resultat(Int, ParisIssue)
    case fou(Int)

    var matchResultat: Int? {
        if case .resultat(let id, _) = self { return id }
        return nil
    }

    var estFou: Bool {
        if case .fou = self { return true }
        return false
    }
}

struct ParisTicket: Identifiable {
    let id = UUID()
    let choix: [ParisChoix]
    let lignes: [String]
    let cote: Double
    let mise: Int
    var gagne: Bool? = nil
    var bons: Int = 0

    var gainPotentiel: Int { Int(Double(mise) * cote) }
}

enum ParisPhase {
    case pronostics, enCours, termine
}

// MARK: - Moteur

enum ParisMoteur {
    static let margeMatch = 1.08
    static let margeFou = 1.15
    static let coteMaxCombine = 10_000.0
    static let simulations = 2_000

    static func aleatoire() -> Double { Double.random(in: 0..<1) }

    static func poisson(_ lambda: Double) -> Int {
        if lambda <= 0 { return 0 }
        if lambda > 30 { return max(0, Int(gauss(lambda, lambda.squareRoot()).rounded())) }
        let limite = exp(-lambda)
        var k = 0
        var p = 1.0
        repeat {
            k += 1
            p *= aleatoire()
        } while p > limite
        return k - 1
    }

    static func gauss(_ moyenne: Double, _ ecart: Double) -> Double {
        let u1 = Double.random(in: Double.leastNonzeroMagnitude..<1)
        let u2 = aleatoire()
        return moyenne + ecart * (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }

    /// Probabilité de gagner une manche, accentuée par l'exposant.
    static func penche(_ s: Double, _ k: Double) -> Double {
        let a = pow(s, k)
        let b = pow(1 - s, k)
        return a / max(0.000_001, a + b)
    }

    static func rugbyScore(_ f: Double) -> Int {
        let essais = poisson(2.2 * f)
        var transfos = 0
        for _ in 0..<essais where aleatoire() < 0.7 { transfos += 1 }
        let penalites = poisson(1.4 + 0.8 * f)
        return 5 * essais + 2 * transfos + 3 * penalites
    }

    /// Score d'un match selon le sport et les forces cachées.
    static func simuler(_ sport: ParisSport, _ forceA: Double, _ forceB: Double) -> (Int, Int) {
        let s = forceA / max(0.001, forceA + forceB)
        var a = 0
        var b = 0
        switch sport.mode {
        case .poisson(let m):
            a = poisson(m * 2 * s)
            b = poisson(m * 2 * (1 - s))
        case .gauss(let m, let e):
            a = max(0, Int(gauss(m * (1 + (s - 0.5) * 0.5), e).rounded()))
            b = max(0, Int(gauss(m * (1 + (0.5 - s) * 0.5), e).rounded()))
        case .sets(let n):
            let q = penche(s, 1.6)
            while a < n && b < n {
                if aleatoire() < q { a += 1 } else { b += 1 }
            }
        case .petanque:
            let q = penche(s, 1.3)
            while a < 13 && b < 13 {
                let points = [1, 1, 1, 2, 2, 3, 4].randomElement() ?? 1
                if aleatoire() < q { a = min(13, a + points) } else { b = min(13, b + points) }
            }
        case .rugby:
            a = rugbyScore(2 * s)
            b = rugbyScore(2 * (1 - s))
        }
        if !sport.nulPossible && a == b {
            // Prolongation, tir au but de tong, photo-finish de lit…
            if aleatoire() < s { a += 1 } else { b += 1 }
        }
        return (a, b)
    }

    /// Probabilités (1, N, 2) estimées en rejouant le match un grand nombre de fois.
    static func probabilites(_ sport: ParisSport, _ forceA: Double, _ forceB: Double) -> (Double, Double, Double) {
        var un = 0
        var nul = 0
        var deux = 0
        for _ in 0..<simulations {
            let (a, b) = simuler(sport, forceA, forceB)
            if a > b { un += 1 } else if a < b { deux += 1 } else { nul += 1 }
        }
        let n = Double(simulations)
        return (Double(un) / n, Double(nul) / n, Double(deux) / n)
    }

    /// Cote arrondie vers le bas au centime, marge du bookmaker comprise.
    static func cote(_ p: Double, marge: Double) -> Double {
        // Léger rabot supplémentaire sur les outsiders (le bookmaker se méfie du hasard).
        let brute = 1 / ((max(p, 0.002) + 0.004) * marge)
        return min(500, max(1.01, (brute * 100).rounded(.down) / 100))
    }

    static func coteCombinee(_ cotes: [Double]) -> Double {
        let produit = cotes.reduce(1, *)
        return min(coteMaxCombine, (produit * 100).rounded(.down) / 100)
    }

    static func texteCote(_ c: Double) -> String {
        String(format: "%.2f", c).replacingOccurrences(of: ".", with: ",")
    }

    static func nouvelleJournee() -> (matchs: [ParisMatch], fous: [ParisFou]) {
        var equipes = ParisNoms.equipes.shuffled()
        var joueurs = ParisNoms.joueurs.shuffled()
        let n = Int.random(in: 6...8)
        let reserve: [ParisSport] = ParisSport.allCases + [.football, .rugby, .tennis, .basket]
        var sports: [ParisSport] = [.football]
        var essais = 0
        while sports.count < n && essais < 200 {
            essais += 1
            guard let s = reserve.randomElement() else { break }
            if sports.filter({ $0 == s }).count < 2 { sports.append(s) }
        }
        sports.shuffle()

        var matchs: [ParisMatch] = []
        for (i, sport) in sports.enumerated() {
            let nomA: String
            let nomB: String
            if sport.individuel {
                nomA = joueurs.popLast() ?? "Joueur mystère"
                nomB = joueurs.popLast() ?? "Joueuse masquée"
            } else {
                nomA = equipes.popLast() ?? "FC Inconnu"
                nomB = equipes.popLast() ?? "AS Anonyme"
            }
            let fA = Double.random(in: 1...10)
            let fB = Double.random(in: 1...10)
            let (p1, pN, p2) = probabilites(sport, fA, fB)
            let coteN: Double? = sport.nulPossible ? cote(pN, marge: margeMatch) : nil
            matchs.append(ParisMatch(id: i, sport: sport, nomA: nomA, nomB: nomB, forceA: fA, forceB: fB,
                                     cote1: cote(p1, marge: margeMatch), coteN: coteN, cote2: cote(p2, marge: margeMatch)))
        }

        var fous: [ParisFou] = []
        var utilises = Set<String>()
        for m in matchs.shuffled() {
            if fous.count >= 4 { break }
            let possibles = ParisTextes.fous.filter { modele in
                (modele.sports.isEmpty || modele.sports.contains(m.sport)) && !utilises.contains(modele.texte)
            }
            guard let modele = possibles.randomElement() else { continue }
            utilises.insert(modele.texte)
            fous.append(ParisFou(id: fous.count, match: m.id, texte: modele.texte, proba: modele.proba,
                                 cote: cote(modele.proba, marge: margeFou)))
        }
        fous.sort { $0.match < $1.match }
        return (matchs, fous)
    }

    static func choixGagnant(_ c: ParisChoix, matchs: [ParisMatch], fous: [ParisFou]) -> Bool {
        switch c {
        case .resultat(let id, let issue):
            guard let m = matchs.first(where: { $0.id == id }) else { return false }
            return m.issue == issue
        case .fou(let id):
            return fous.first(where: { $0.id == id })?.arrive == true
        }
    }

    static func commentaire(_ m: ParisMatch) -> String {
        guard let a = m.scoreA, let b = m.scoreB else { return "" }
        let gagnant = a >= b ? m.nomA : m.nomB
        let perdant = a >= b ? m.nomB : m.nomA
        let forceG = a >= b ? m.forceA : m.forceB
        let forceP = a >= b ? m.forceB : m.forceA
        let liste: [String]
        if a == b {
            liste = ParisTextes.nul
        } else if m.sport == .petanque && min(a, b) == 0 {
            liste = ParisTextes.fanny
        } else if forceG < forceP * 0.7 {
            liste = ParisTextes.surprise
        } else if abs(a - b) >= m.sport.ecartLarge {
            liste = ParisTextes.large
        } else {
            liste = ParisTextes.serree
        }
        let modele = liste.randomElement() ?? ""
        return modele
            .replacingOccurrences(of: "{G}", with: gagnant)
            .replacingOccurrences(of: "{P}", with: perdant)
            .replacingOccurrences(of: "{A}", with: m.nomA)
            .replacingOccurrences(of: "{B}", with: m.nomB)
    }
}

// MARK: - Noms

enum ParisNoms {
    static let equipes = [
        "Olympique de Saint-Glinglin", "FC Pas-de-Bol", "Racing Club de Trifouilly", "AS Moumoute",
        "Stade Pépère", "US des Chaussettes Orphelines", "Sporting du Lundi Matin", "Dynamo Tartiflette",
        "Real Mollasson", "Inter de Pétaouchnok", "AJ Cassoulet", "Les Mouettes Rieuses",
        "FC Raplapla", "Girondins de la Flemme", "Atlético Croquette", "Les Loutres Énervées",
        "Entente Bras-Cassés", "US Torticolis", "Stade du Rhume des Foins", "Les Pingouins Vénères",
        "Spartak Saucisson", "Borussia Gratin", "CSKA Camembert", "Les Hérissons Mous",
        "AC Pantoufle", "CA de Bourg-la-Sieste", "Les Lamas Cracheurs", "FC Vas-y-Mollo",
        "Standard de Perpète", "Les Bisons Timides", "RC Coup-de-Pompe", "SC Grosse Fatigue",
        "Les Castors Insomniaques", "Olympique Raclette", "Les Phoques Tristes", "AS Flan-Pâtissier",
        "Union des Tontons Vexés", "Les Moustiques Tigrés", "FC Belle-Mère", "Les Gnous Imprévisibles",
        "Stade Courant-d'Air", "Les Mamies Turbo", "Paris Sans Gagner", "AS Pot-au-Feu",
        "Les Limaces Fusées", "Dynamo Sieste", "FC Croque-Monsieur", "Les Vikings de Romorantin",
        "Red Star de la Buvette", "Les Kangourous Dépressifs", "Galaxy de Saint-Pancrace", "AS Bigoudi",
    ]

    static let joueurs = [
        "Jean-Michel Revers", "Bérénice Smash", "Gérard Lifté", "Sandrine Ace", "Kévin Double-Faute",
        "Josiane Volée", "Dédé la Fusée", "Mamie Ginette", "Tonton Raymond", "Bruno Gros-Bras",
        "Lucette Tir-Tendu", "Pépé Marcel", "Le Grand Fred", "Ludovic Coup-Droit", "Brigitte Filet",
        "Steve Chouchou", "Yvette Carreau", "Norbert Pied-Léger", "Paulette Plongeon", "Rémi Ramollo",
        "Huguette Turbo", "Patrice Bras-Cassé", "Maryse Amortie", "Igor Tamis", "Nadège Bulldozer",
        "Thierry Tuba", "Odile Effet-Rétro",
    ]
}

// MARK: - Textes

enum ParisTextes {
    static let large = [
        "{G} a atomisé {P}. Les joueurs de {P} ont demandé l'asile politique dans les vestiaires.",
        "Démonstration de {G}. {P} a passé la seconde moitié du match à chercher ses clés de voiture.",
        "{P} a été tellement dominé que son entraîneur a fini par encourager {G}.",
        "Correction historique : la dignité de {P} a quitté le terrain avant la pause.",
        "{G} a gagné si largement que l'arbitre a proposé à {P} de recommencer. Refusé, par fatigue.",
        "Le tableau d'affichage de {P} a demandé un arrêt maladie.",
        "{G} l'emporte facilement. {P} accuse le soleil, la lune et un pigeon suspect.",
        "Humiliation pour {P}, dont les supporters se sont reconvertis en cours de match dans le macramé.",
        "{G} a joué avec {P} comme un chat avec une pelote. Une pelote très triste.",
    ]

    static let serree = [
        "{G} l'emporte d'un cheveu. Le cheveu sera exposé au musée du club.",
        "Victoire arrachée par {G} sur une action que personne n'a comprise, même au ralenti.",
        "{P} a perdu de justesse, puis a raté le car du retour, de justesse aussi.",
        "{G} gagne au bout du suspense. Trois spectateurs ont fait un malaise, un quatrième a fait des crêpes.",
        "Match serré : {G} s'impose grâce à un coup de génie, ou de chance. L'enquête est en cours.",
        "{P} était à deux doigts. Malheureusement, c'étaient les mauvais doigts.",
        "{G} gagne sur le fil. Le fil a porté plainte.",
        "Victoire de {G} à l'arraché. Le capitaine la dédie à sa grand-mère, qui dormait.",
        "{G} s'impose dans la douleur. Surtout celle de {P}.",
    ]

    static let nul = [
        "Match nul. Les deux camps se sont serré la main, puis disputé le dernier sandwich.",
        "Égalité parfaite entre {A} et {B}. Même l'ennui était partagé équitablement.",
        "Personne ne gagne. Le seul vainqueur du soir est le vendeur de merguez.",
        "{A} et {B} se quittent dos à dos. L'arbitre a proposé un pierre-feuille-ciseaux, refusé par la fédération.",
        "Match nul, et c'est un euphémisme.",
        "Les supporters de {A} et de {B} sont repartis bras dessus bras dessous. Vers le même bar.",
        "Ni vainqueur, ni vaincu, ni intérêt.",
        "Égalité. Les deux entraîneurs affirment avoir « fait le match qu'il fallait ». Lequel, mystère.",
    ]

    static let surprise = [
        "Énorme surprise : {G} bat {P} ! Le bookmaker a renversé son café sur sa calculatrice.",
        "Personne n'y croyait, pas même {G}, qui avait déjà réservé ses vacances.",
        "{P}, grand favori, s'incline. Ses joueurs avaient confondu échauffement et sieste.",
        "Exploit de {G} ! La mascotte a été portée en triomphe, puis lâchée par accident.",
        "{G} renverse {P}. Les statisticiens sont en cellule de soutien psychologique.",
        "Le petit poucet {G} terrasse {P}. Le grand poucet est vexé.",
        "Coup de tonnerre : {P} perd contre {G}. Son président annonce « une réflexion », c'est-à-dire une sieste.",
        "Miracle : {G} gagne. Un supporter affirme avoir prié saint Gégé, patron des causes perdues.",
    ]

    static let fanny = [
        "FANNY ! {P} n'a pas marqué un point. La tradition exige un bisou à la statue. Ils l'ont fait en pleurant.",
        "13 à 0. {P} est reparti sous les rires et le chant des cigales.",
        "Fanny pour {P}, qui va devoir payer la tournée et vivre avec ça.",
        "{G} inflige une fanny à {P}. Le cochonnet lui-même a eu de la peine.",
    ]

    static let fous: [ParisFouModele] = [
        ParisFouModele(texte: "L'arbitre va pleurer", proba: 0.07, sports: []),
        ParisFouModele(texte: "Un chien entre sur le terrain", proba: 0.05, sports: []),
        ParisFouModele(texte: "Le gardien marque", proba: 0.03, sports: [.football, .handball]),
        ParisFouModele(texte: "Un joueur réclame sa maman au micro", proba: 0.04, sports: []),
        ParisFouModele(texte: "Un spectateur torse nu malgré le froid", proba: 0.26, sports: []),
        ParisFouModele(texte: "Deux mascottes se battent", proba: 0.06, sports: []),
        ParisFouModele(texte: "Quelqu'un perd une chaussure", proba: 0.15, sports: []),
        ParisFouModele(texte: "Le commentateur s'endort en direct", proba: 0.05, sports: []),
        ParisFouModele(texte: "Demande en mariage dans les tribunes", proba: 0.10, sports: []),
        ParisFouModele(texte: "Il pleut des grenouilles", proba: 0.004, sports: []),
        ParisFouModele(texte: "Le ballon éclate", proba: 0.02, sports: [.football, .basket, .handball, .rugby]),
        ParisFouModele(texte: "Un pigeon vole la balle", proba: 0.03, sports: [.tennis, .pingPong]),
        ParisFouModele(texte: "Le cochonnet disparaît mystérieusement", proba: 0.06, sports: [.petanque]),
        ParisFouModele(texte: "Une tong atterrit dans la buvette", proba: 0.12, sports: [.tongs]),
        ParisFouModele(texte: "Un lit s'échappe dans la rue", proba: 0.08, sports: [.lits]),
        ParisFouModele(texte: "Un escargot fait demi-tour", proba: 0.20, sports: [.escargots]),
        ParisFouModele(texte: "La corde casse", proba: 0.05, sports: [.corde]),
        ParisFouModele(texte: "Un oreiller explose en neige de plumes", proba: 0.30, sports: [.polochons]),
        ParisFouModele(texte: "Une pierre de curling file jusqu'au parking", proba: 0.04, sports: [.curling]),
        ParisFouModele(texte: "Un joueur marque contre son camp et fête ça", proba: 0.04, sports: [.football]),
        ParisFouModele(texte: "Le panier se décroche", proba: 0.02, sports: [.basket]),
        ParisFouModele(texte: "La mêlée s'effondre en rigolant", proba: 0.09, sports: [.rugby]),
    ]

    static let validation = [
        "Ticket enregistré. Le buraliste l'a tamponné avec un sourire carnassier.",
        "C'est validé. Plus moyen de reculer, à part en pleurant.",
        "Ticket pris. Tu le plies soigneusement dans ton portefeuille, à côté de tes espoirs.",
        "Pari enregistré. Le bookmaker te souhaite bonne chance, sans conviction.",
        "Validé ! Tu ressens déjà la fierté de quelqu'un qui n'a encore rien gagné.",
        "Ticket imprimé. L'encre sent l'optimisme et le tabac froid.",
    ]

    static func gain(_ g: (String, String) -> String) -> [String] {
        [
            "Ticket gagnant ! Tu cries « je le savais » alors que tu avais choisi au hasard.",
            "Gagné ! Le buraliste te tend tes billets avec un regard plein de jalousie.",
            "Ton intuition a payé. Ton intuition demande maintenant une augmentation.",
            "Victoire ! Tu viens de comprendre le sport. Ça ne durera pas.",
            "Ça passe ! Tu te sens soudain " + g("expert", "experte") + " en tout. Tu ne l'es pas.",
            "Ticket gagnant. Tu envisages de quitter ton travail. Ne fais pas ça.",
            "Gagné ! Tu embrasses ton ticket, puis l'écran, puis un inconnu.",
            "Le bookmaker te paie en soupirant. C'est le plus beau son du monde.",
        ]
    }

    static func jackpot(_ g: (String, String) -> String) -> [String] {
        [
            "COMBINÉ DE LÉGENDE ! Le bookmaker appelle sa mère pour lui dire qu'il l'aime.",
            "Énorme ! Ton ticket sera encadré au-dessus du comptoir, à côté de la photo du chat du patron.",
            "Tu as réussi l'impossible. Quelque part, un statisticien démissionne.",
            "JACKPOT ! Tu fais un tour d'honneur du bar. Les habitués applaudissent mollement.",
            "Cote astronomique, gain cosmique. Tu raconteras ça pendant 40 ans. Les autres s'en lasseront en 2.",
            "Incroyable ! Tu es " + g("devenu", "devenue") + " une légende des paris. Ta photo circule sur des forums douteux.",
            "Le bookmaker vérifie ton ticket trois fois, à la loupe, puis à la lampe UV. Il est bon. Il pleure.",
        ]
    }

    static func presque(_ g: (String, String) -> String) -> [String] {
        [
            "À un match près ! Ce match restera ton ennemi personnel jusqu'à ta mort.",
            "Toutes tes sélections sont passées sauf une. Il y a toujours « sauf une ».",
            "Perdu à une sélection. Tu vas y repenser cette nuit vers 3 h 47.",
            "Si près du but… Le but, lui, ne pense pas à toi.",
            "Un seul match t'a " + g("trahi", "trahie") + ". Tu ne regarderas plus jamais ce sport de la même façon.",
            "Le combiné est tombé au dernier moment. Comme ton moral.",
            "Presque ! Mais le bookmaker ne paie pas les « presque », tu as vérifié.",
            "Une sélection de trop. La prochaine fois, tu parieras sur moins de choses. (Non.)",
        ]
    }

    static func perte(_ g: (String, String) -> String) -> [String] {
        [
            "Perdu. Le sport est imprévisible ; ton porte-monnaie, lui, est très prévisible : vide.",
            "Ticket perdant. Tu le froisses avec la rage d'un joueur de pétanque privé de pastis.",
            "Raté. Tu blâmes l'arbitre, la météo et l'alignement des planètes.",
            "Perdu ! Tu jures d'arrêter les paris. Rendez-vous demain, même heure.",
            "Ton pronostic était audacieux. Faux, mais audacieux.",
            "Le bookmaker te remercie chaleureusement pour ta contribution à ses vacances.",
            "Défaite. Tu viens d'apprendre que les noms d'équipe rigolos ne gagnent pas plus souvent.",
            "Ticket perdu. Tu t'es fait avoir, tu le sais, il le sait, tout le bar le sait.",
            "Perdu. Tu demandes si on peut annuler un pari après coup. Le buraliste rit encore.",
            "C'est perdu. Mais tu as passé un bon moment. Non ? Bon. Tu es " + g("déçu", "déçue") + ", c'est normal.",
        ]
    }

    static let mixte = [
        "Un ticket gagnant, mais pas assez pour rembourser les autres. La comptabilité des parieurs est un art triste.",
        "Tu as gagné d'un côté, perdu de l'autre. Au total, le bookmaker te remercie.",
        "Un bon ticket noyé dans les mauvais. Comme une perle dans une soupe froide.",
        "Tu repars avec un peu d'argent et beaucoup de regrets. Surtout des regrets.",
    ]
}

// MARK: - Vue principale

struct ParisSportifsVue: View {
    let lieu: CasinoLieu
    @EnvironmentObject var engine: GameEngine

    @State private var matchs: [ParisMatch] = []
    @State private var fous: [ParisFou] = []
    @State private var selection: [ParisChoix] = []
    @State private var tickets: [ParisTicket] = []
    @State private var mise: Int = 0
    @State private var phase: ParisPhase = .pronostics
    @State private var nbRevele: Int = 0
    @State private var montrerFous = false
    @State private var message: String?
    @State private var messageGain: Bool?

    private let maxTickets = 5
    private let maxSelections = 4

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                entete
                ForEach(matchs) { m in
                    ligneMatch(m)
                }
                optionFous
                if phase == .pronostics {
                    ticketEnCours
                }
                if !tickets.isEmpty {
                    ticketsValides
                }
                if let m = message {
                    CasinoBandeau(texte: m, gain: messageGain)
                }
                actions
            }
            .padding()
        }
        .onAppear {
            if matchs.isEmpty { nouvelleJournee() }
        }
    }

    // MARK: Infos

    @MainActor private var argent: Int { engine.joueur?.argent ?? 0 }

    private func match(_ id: Int) -> ParisMatch? { matchs.first { $0.id == id } }

    private func fou(_ id: Int) -> ParisFou? { fous.first { $0.id == id } }

    private func estRevele(_ matchID: Int) -> Bool {
        switch phase {
        case .pronostics: return false
        case .enCours: return matchID < nbRevele
        case .termine: return true
        }
    }

    private func coteDe(_ c: ParisChoix) -> Double {
        switch c {
        case .resultat(let id, let issue):
            return match(id)?.cote(issue) ?? 1
        case .fou(let id):
            return fou(id)?.cote ?? 1
        }
    }

    private func libelle(_ c: ParisChoix) -> String {
        switch c {
        case .resultat(let id, let issue):
            guard let m = match(id) else { return "?" }
            return "\(m.sport.emoji) \(m.libelle(issue))"
        case .fou(let id):
            guard let f = fou(id) else { return "?" }
            return "🤪 \(f.texte)"
        }
    }

    private var coteSelection: Double { ParisMoteur.coteCombinee(selection.map { coteDe($0) }) }

    @MainActor private var peutValider: Bool {
        phase == .pronostics && !selection.isEmpty && tickets.count < maxTickets
            && CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent)
    }

    // MARK: Sous-vues

    private var entete: some View {
        VStack(spacing: 4) {
            Text("📺 Programme du jour")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(CasinoStyle.or)
            Text("Touche une cote pour l'ajouter à ton ticket. Combine 2 à 4 sélections pour multiplier les cotes (et les ennuis).")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private func ligneMatch(_ m: ParisMatch) -> some View {
        let choisies: [ParisIssue] = m.issues.filter { selection.contains(.resultat(m.id, $0)) }
        return ParisMatchLigne(match: m,
                               revele: estRevele(m.id),
                               enCours: phase == .enCours,
                               choisies: choisies,
                               modifiable: phase == .pronostics) { issue in
            basculer(.resultat(m.id, issue))
        }
    }

    private var optionFous: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $montrerFous.animation()) {
                Label("Pari fou", systemImage: "theatermasks.fill")
                    .font(.headline)
                    .foregroundStyle(CasinoStyle.or)
            }
            .tint(CasinoStyle.or)
            if montrerFous {
                Text("Parie sur l'improbable. Les cotes sont énormes parce que les chances sont minuscules. Vraiment minuscules.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                ForEach(fous) { f in
                    ParisFouLigne(fou: f,
                                  match: match(f.match),
                                  revele: estRevele(f.match),
                                  choisi: selection.contains(.fou(f.id)),
                                  modifiable: phase == .pronostics) {
                        basculer(.fou(f.id))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
    }

    @MainActor private var ticketEnCours: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selection.count > 1 ? "Ticket combiné (\(selection.count) sélections)" : "Ton ticket")
                .font(.headline)
                .foregroundStyle(CasinoStyle.or)
            if selection.isEmpty {
                Text("Aucune sélection. Tu peux valider jusqu'à \(maxTickets) tickets avant de lancer les matchs.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(selection, id: \.self) { c in
                    ligneSelection(c)
                }
                HStack {
                    Text("Cote totale").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(ParisMoteur.texteCote(coteSelection))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(CasinoStyle.or)
                }
                .foregroundStyle(.white)
                CasinoSelecteurMise(mise: $mise, lieu: lieu, argent: argent)
                Text("Gain potentiel : \(Format.argent(Int(Double(mise) * coteSelection)))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                CasinoBouton(titre: tickets.count >= maxTickets ? "Maximum \(maxTickets) tickets" : "Valider le ticket",
                             actif: peutValider) {
                    valider()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
    }

    private func ligneSelection(_ c: ParisChoix) -> some View {
        HStack(spacing: 8) {
            Text(libelle(c))
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 4)
            Text(ParisMoteur.texteCote(coteDe(c)))
                .font(.caption.weight(.bold))
                .foregroundStyle(CasinoStyle.or)
            Button {
                basculer(c)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    private var ticketsValides: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tickets validés").font(.headline).foregroundStyle(CasinoStyle.or)
            ForEach(tickets) { t in
                ParisTicketVue(ticket: t, resultatVisible: phase == .termine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor @ViewBuilder private var actions: some View {
        switch phase {
        case .pronostics:
            CasinoBouton(titre: tickets.isEmpty ? "Valide un ticket pour lancer les matchs" : "Lancer les matchs !",
                         couleur: CasinoStyle.rouge,
                         actif: !tickets.isEmpty) {
                lancer()
            }
            if tickets.isEmpty {
                CasinoBouton(titre: "Nouveaux matchs", couleur: Color.black.opacity(0.45)) {
                    nouvelleJournee()
                }
            }
        case .enCours:
            HStack(spacing: 10) {
                ProgressView().tint(CasinoStyle.or)
                Text("Matchs en cours… Ne regarde pas, ça porte malheur.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 10)
        case .termine:
            CasinoBouton(titre: "Nouveaux matchs") {
                nouvelleJournee()
            }
        }
    }

    // MARK: Actions

    private func basculer(_ c: ParisChoix) {
        guard phase == .pronostics else { return }
        if let i = selection.firstIndex(of: c) {
            selection.remove(at: i)
            return
        }
        if let id = c.matchResultat, let i = selection.firstIndex(where: { $0.matchResultat == id }) {
            selection[i] = c
            return
        }
        guard selection.count < maxSelections else {
            message = "4 sélections maximum par ticket. Même le bookmaker trouve que tu exagères."
            messageGain = nil
            return
        }
        selection.append(c)
    }

    private func nouvelleJournee() {
        let journee = ParisMoteur.nouvelleJournee()
        withAnimation {
            matchs = journee.matchs
            fous = journee.fous
            selection = []
            tickets = []
            phase = .pronostics
            nbRevele = 0
            message = nil
            messageGain = nil
        }
    }

    @MainActor private func valider() {
        guard phase == .pronostics, !selection.isEmpty, tickets.count < maxTickets else { return }
        guard CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent) else {
            message = "Mise impossible : entre \(Format.argent(lieu.miseMin)) et \(Format.argent(min(lieu.miseMax, argent)))."
            messageGain = false
            return
        }
        let lignes = selection.map { "\(libelle($0)) @ \(ParisMoteur.texteCote(coteDe($0)))" }
        let ticket = ParisTicket(choix: selection, lignes: lignes, cote: coteSelection, mise: mise)
        guard engine.casinoMiser(mise, jeu: .paris) else {
            message = "Le bookmaker refuse ta mise. Ton compte en banque aussi."
            messageGain = false
            return
        }
        withAnimation {
            tickets.append(ticket)
            selection = []
            message = ParisTextes.validation.randomElement()
            messageGain = nil
        }
    }

    @MainActor private func lancer() {
        guard phase == .pronostics, !tickets.isEmpty else { return }
        var resultats = matchs
        for i in resultats.indices {
            let (a, b) = ParisMoteur.simuler(resultats[i].sport, resultats[i].forceA, resultats[i].forceB)
            resultats[i].scoreA = a
            resultats[i].scoreB = b
            resultats[i].commentaire = ParisMoteur.commentaire(resultats[i])
        }
        var fousJoues = fous
        for i in fousJoues.indices {
            fousJoues[i].arrive = ParisMoteur.aleatoire() < fousJoues[i].proba
        }
        var tk = tickets
        for i in tk.indices {
            let bons = tk[i].choix.filter { ParisMoteur.choixGagnant($0, matchs: resultats, fous: fousJoues) }.count
            tk[i].bons = bons
            tk[i].gagne = bons == tk[i].choix.count
        }
        let aDesFous = tk.contains { t in t.choix.contains(where: { $0.estFou }) }
        let ticketsJoues = tk

        nbRevele = 0
        message = nil
        messageGain = nil
        matchs = resultats
        fous = fousJoues
        tickets = tk
        if aDesFous { montrerFous = true }
        phase = .enCours

        let moteur = engine
        let nombre = resultats.count
        Task { @MainActor in
            for i in 0..<nombre {
                try? await Task.sleep(nanoseconds: 750_000_000)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                    nbRevele = i + 1
                }
            }
            try? await Task.sleep(nanoseconds: 600_000_000)
            let bilan = ParisSportifsVue.regler(ticketsJoues, engine: moteur)
            withAnimation(.spring()) {
                phase = .termine
                message = bilan.texte
                messageGain = bilan.gain
            }
        }
    }

    /// Règle tous les tickets (un appel à casinoRegler par ticket) et renvoie le texte du bilan.
    @MainActor private static func regler(_ tickets: [ParisTicket], engine: GameEngine) -> (texte: String, gain: Bool?) {
        var totalMise = 0
        var totalPaye = 0
        var meilleureCote = 0.0
        var presque = false
        var unGagnant = false
        for t in tickets {
            let gagne = t.gagne == true
            let paiement = gagne ? t.gainPotentiel : 0
            let detail = t.choix.count > 1 ? "Paris sportifs (combiné de \(t.choix.count))" : "Paris sportifs"
            engine.casinoRegler(mise: t.mise, paiement: paiement, jeu: .paris, detail: detail)
            totalMise += t.mise
            totalPaye += paiement
            if gagne {
                unGagnant = true
                meilleureCote = max(meilleureCote, t.cote)
            } else if t.choix.count > 1 && t.bons == t.choix.count - 1 {
                presque = true
            }
        }
        let joueur = engine.joueur
        let g: (String, String) -> String = { m, f in joueur?.g(m, f) ?? m }
        let net = totalPaye - totalMise
        let phrase: String
        if net > 0 {
            phrase = (meilleureCote >= 20 ? ParisTextes.jackpot(g) : ParisTextes.gain(g)).randomElement() ?? ""
        } else if unGagnant {
            phrase = ParisTextes.mixte.randomElement() ?? ""
        } else if presque {
            phrase = ParisTextes.presque(g).randomElement() ?? ""
        } else {
            phrase = ParisTextes.perte(g).randomElement() ?? ""
        }
        let bilan: String
        if net > 0 {
            bilan = "Tu encaisses \(Format.argent(totalPaye)) (+\(Format.argent(net)))."
        } else if totalPaye > 0 {
            bilan = "Tu récupères \(Format.argent(totalPaye)) sur \(Format.argent(totalMise)) misés."
        } else {
            bilan = "Tu perds \(Format.argent(totalMise))."
        }
        let gain: Bool? = net > 0 ? true : (net < 0 ? false : nil)
        return (phrase + "\n" + bilan, gain)
    }
}

// MARK: - Ligne de match

struct ParisMatchLigne: View {
    let match: ParisMatch
    let revele: Bool
    let enCours: Bool
    let choisies: [ParisIssue]
    let modifiable: Bool
    let choisir: (ParisIssue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(match.sport.emoji) \(match.sport.nom)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CasinoStyle.or)
                Spacer()
                statut
            }
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    nom(match.nomA, gagnant: revele && match.issue == .un)
                    nom(match.nomB, gagnant: revele && match.issue == .deux)
                }
                Spacer(minLength: 4)
                if revele, let a = match.scoreA, let b = match.scoreB {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(a)\(match.sport.unite)")
                        Text("\(b)\(match.sport.unite)")
                    }
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(CasinoStyle.or)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            if revele, let c = match.commentaire {
                Text(c)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            HStack(spacing: 8) {
                ForEach(match.issues, id: \.self) { i in
                    ParisBoutonCote(titre: i.code,
                                    cote: match.cote(i),
                                    choisi: choisies.contains(i),
                                    gagnant: revele && match.issue == i,
                                    actif: modifiable) {
                        choisir(i)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(choisies.isEmpty ? Color.clear : CasinoStyle.or.opacity(0.7), lineWidth: 1.5)
        )
    }

    @ViewBuilder private var statut: some View {
        if revele {
            Text("Terminé")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.15), in: Capsule())
                .foregroundStyle(.white)
        } else if enCours {
            HStack(spacing: 4) {
                ProgressView().tint(.white).scaleEffect(0.7)
                Text("En cours").font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func nom(_ texte: String, gagnant: Bool) -> some View {
        Text(texte)
            .font(.subheadline.weight(gagnant ? .heavy : .medium))
            .foregroundStyle(gagnant ? CasinoStyle.or : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

struct ParisBoutonCote: View {
    let titre: String
    let cote: Double
    let choisi: Bool
    let gagnant: Bool
    let actif: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(titre)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Text(ParisMoteur.texteCote(cote))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(choisi ? CasinoStyle.or : Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(gagnant ? Color.green : Color.white.opacity(0.15), lineWidth: gagnant ? 2.5 : 1)
            )
            .foregroundStyle(choisi ? CasinoStyle.nuit : Color.white)
        }
        .buttonStyle(.plain)
        .disabled(!actif)
    }
}

// MARK: - Pari fou

struct ParisFouLigne: View {
    let fou: ParisFou
    let match: ParisMatch?
    let revele: Bool
    let choisi: Bool
    let modifiable: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("🤪 \(fou.texte)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let m = match {
                    Text("\(m.sport.emoji) \(m.nomA) – \(m.nomB)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                if revele, let arrive = fou.arrive {
                    Text(arrive ? "✅ C'est arrivé !" : "❌ Ça n'est pas arrivé.")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(arrive ? Color.green : Color.white.opacity(0.7))
                }
            }
            Spacer(minLength: 4)
            ParisBoutonCote(titre: "Cote", cote: fou.cote, choisi: choisi, gagnant: revele && fou.arrive == true,
                            actif: modifiable, action: action)
                .frame(width: 76)
        }
        .padding(8)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Ticket

struct ParisTicketVue: View {
    let ticket: ParisTicket
    let resultatVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(ticket.lignes.enumerated()), id: \.offset) { _, ligne in
                Text("• \(ligne)")
                    .font(.caption)
                    .foregroundStyle(CasinoStyle.nuit)
                    .lineLimit(2)
            }
            Divider()
            HStack {
                Text("Mise \(Format.argent(ticket.mise)) × \(ParisMoteur.texteCote(ticket.cote))")
                Spacer()
                Text(statut)
                    .fontWeight(.heavy)
                    .foregroundStyle(couleurStatut)
            }
            .font(.caption)
            .foregroundStyle(CasinoStyle.nuit)
        }
        .padding(10)
        .background(CasinoStyle.creme, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.gray)
        )
    }

    private var statut: String {
        guard resultatVisible, let g = ticket.gagne else { return "→ \(Format.argent(ticket.gainPotentiel))" }
        return g ? "GAGNÉ \(Format.argent(ticket.gainPotentiel))" : "PERDU"
    }

    private var couleurStatut: Color {
        guard resultatVisible, let g = ticket.gagne else { return CasinoStyle.nuit }
        return g ? Color(red: 0.1, green: 0.55, blue: 0.25) : CasinoStyle.rouge
    }
}

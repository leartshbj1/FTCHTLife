import Foundation
import SwiftUI

// MARK: - Règles

/// Calculs purs du blackjack (valeurs, totaux, comptage Hi-Lo).
enum BlackjackRegles {
    /// Nombre de jeux de 52 cartes dans le sabot.
    static let nombreJeux = 6
    /// En dessous de ce nombre de cartes (25 % du sabot), on remélange avant la main suivante.
    static let seuilMelange = 52 * nombreJeux / 4

    /// Valeur d'une carte : 2-10 → valeur, figures → 10, As → 11 (ramené à 1 si besoin dans `total`).
    static func valeur(_ c: CasinoCarte) -> Int {
        if c.rang == 14 { return 11 }
        return min(c.rang, 10)
    }

    /// Meilleur total d'une main (les As valent 11 tant qu'on ne dépasse pas 21).
    static func total(_ cartes: [CasinoCarte]) -> Int {
        totalEtSouplesse(cartes).total
    }

    /// Main « souple » : un As compte encore pour 11.
    static func estSouple(_ cartes: [CasinoCarte]) -> Bool {
        totalEtSouplesse(cartes).souple
    }

    static func totalEtSouplesse(_ cartes: [CasinoCarte]) -> (total: Int, souple: Bool) {
        var somme = 0
        var nbAs = 0
        for c in cartes {
            somme += valeur(c)
            if c.rang == 14 { nbAs += 1 }
        }
        while somme > 21 && nbAs > 0 {
            somme -= 10
            nbAs -= 1
        }
        return (somme, nbAs > 0)
    }

    /// Blackjack naturel : 21 en deux cartes.
    static func estBlackjack(_ cartes: [CasinoCarte]) -> Bool {
        cartes.count == 2 && total(cartes) == 21
    }

    /// Comptage Hi-Lo : 2-6 → +1, 7-9 → 0, 10/figures/As → -1.
    static func hiLo(_ c: CasinoCarte) -> Int {
        switch c.rang {
        case 2...6: return 1
        case 7...9: return 0
        default: return -1
        }
    }
}

// MARK: - Modèles

enum BlackjackPhase {
    case mise, distribution, joueur, croupier, fin
}

/// Issue d'une main (sert aussi à choisir la phrase du croupier).
enum BlackjackIssue {
    case gagne, perdu, blackjack, bust, egalite, croupierSaute

    /// Ce que rapporte une main (mise comprise).
    func paiement(mise: Int) -> Int {
        switch self {
        case .blackjack: return mise + (mise * 3) / 2
        case .gagne, .croupierSaute: return mise * 2
        case .egalite: return mise
        case .perdu, .bust: return 0
        }
    }

    var libelle: String {
        switch self {
        case .gagne: return "Gagné"
        case .perdu: return "Perdu"
        case .blackjack: return "Blackjack !"
        case .bust: return "Sauté"
        case .egalite: return "Égalité"
        case .croupierSaute: return "Croupier sauté"
        }
    }

    var estGain: Bool? {
        switch self {
        case .gagne, .blackjack, .croupierSaute: return true
        case .perdu, .bust: return false
        case .egalite: return nil
        }
    }
}

/// Une main du joueur (deux après une séparation).
struct BlackjackMain: Identifiable {
    let id = UUID()
    var cartes: [CasinoCarte] = []
    var mise: Int
    var doublee = false
    var terminee = false
    /// Main issue d'une séparation : un 21 en deux cartes n'y est pas un blackjack naturel.
    var issueSplit = false
    var issue: BlackjackIssue? = nil

    var total: Int { BlackjackRegles.total(cartes) }
    var souple: Bool { BlackjackRegles.estSouple(cartes) }
    var bust: Bool { total > 21 }
    var estBlackjack: Bool { !issueSplit && BlackjackRegles.estBlackjack(cartes) }
}

/// Une étape de distribution animée.
enum BlackjackEtape {
    case joueur(Int)
    case croupier(cachee: Bool)
}

// MARK: - Table

/// État et déroulement d'une table de blackjack. Toutes les méthodes sont appelées sur le fil principal
/// (actions de boutons et `DispatchQueue.main.asyncAfter`).
final class BlackjackTable: ObservableObject {
    @Published private(set) var sabot: [CasinoCarte] = CasinoCarte.paquet(jeux: BlackjackRegles.nombreJeux)
    @Published private(set) var mains: [BlackjackMain] = []
    @Published private(set) var croupier: [CasinoCarte] = []
    @Published private(set) var carteCacheeVisible = false
    @Published private(set) var angleCachee: Double = 0
    @Published private(set) var phase: BlackjackPhase = .mise
    @Published private(set) var mainActive = 0
    @Published private(set) var occupe = false
    /// Compte courant Hi-Lo (cartes vues depuis le dernier mélange).
    @Published private(set) var compte = 0
    @Published var message: String?
    @Published var messageGain: Bool?
    @Published var phraseCroupier: String = BlackjackTextes.accueil.randomElement()!
    @Published var compterActif = false {
        didSet {
            if compterActif && phase != .mise && phase != .fin { aCompteCetteMain = true }
        }
    }
    /// Message de bannissement : la table est fermée pour ce joueur.
    @Published var banni: String?

    private weak var engine: GameEngine?
    private var miseTotale = 0
    private var miseInitiale = 0
    private var miseMainPrecedente: Int?
    private var aCompteCetteMain = false

    // MARK: Infos pour la vue

    var cartesRestantes: Int { sabot.count }

    /// Vrai compte = compte courant / nombre de jeux restant dans le sabot.
    var vraiCompte: Double {
        let jeuxRestants = max(Double(sabot.count) / 52.0, 0.5)
        return Double(compte) / jeuxRestants
    }

    /// Total affiché du croupier (seulement la carte visible tant que l'autre est cachée).
    var totalCroupierVisible: Int? {
        guard !croupier.isEmpty else { return nil }
        if carteCacheeVisible { return BlackjackRegles.total(croupier) }
        return BlackjackRegles.total([croupier[0]])
    }

    var enJeu: Bool { phase == .distribution || phase == .joueur || phase == .croupier }

    var mainCourante: BlackjackMain? {
        guard phase == .joueur, mainActive < mains.count else { return nil }
        return mains[mainActive]
    }

    func peutTirer() -> Bool {
        guard banni == nil, !occupe, let m = mainCourante else { return false }
        return !m.terminee && m.total < 21
    }

    func peutDoubler(argent: Int) -> Bool {
        guard banni == nil, !occupe, let m = mainCourante else { return false }
        let asSepares = m.issueSplit && m.cartes.first?.rang == 14
        return m.cartes.count == 2 && !m.doublee && !asSepares && argent >= m.mise
    }

    func peutSeparer(argent: Int) -> Bool {
        guard banni == nil, !occupe, mains.count == 1, let m = mainCourante else { return false }
        return m.cartes.count == 2 && m.cartes[0].rang == m.cartes[1].rang && argent >= m.mise
    }

    // MARK: Utilitaires

    private func apres(_ delai: Double, _ action: @escaping (BlackjackTable) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delai) { [weak self] in
            guard let self = self else { return }
            action(self)
        }
    }

    private func piocher(visible: Bool) -> CasinoCarte {
        if sabot.isEmpty {
            sabot = CasinoCarte.paquet(jeux: BlackjackRegles.nombreJeux)
            compte = 0
        }
        let c = sabot.removeLast()
        if visible { compte += BlackjackRegles.hiLo(c) }
        return c
    }

    private func executer(_ etape: BlackjackEtape) {
        switch etape {
        case .joueur(let i):
            guard i < mains.count else { return }
            let c = piocher(visible: true)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                mains[i].cartes.append(c)
            }
        case .croupier(let cachee):
            let c = piocher(visible: !cachee)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                croupier.append(c)
            }
        }
    }

    /// Distribue les cartes une à une, puis appelle `fin`.
    private func jouerEtapes(_ etapes: [BlackjackEtape], delai: Double = 0.45, fin: @escaping (BlackjackTable) -> Void) {
        guard let premiere = etapes.first else {
            fin(self)
            return
        }
        executer(premiere)
        let reste = Array(etapes.dropFirst())
        apres(delai) { t in
            t.jouerEtapes(reste, delai: delai, fin: fin)
        }
    }

    // MARK: Déroulement

    /// Lance une nouvelle main. Renvoie false (avec un message) si la mise est impossible.
    func distribuer(engine: GameEngine, mise: Int, lieu: CasinoLieu, comptage: Bool) {
        guard banni == nil, !occupe, phase == .mise || phase == .fin else { return }
        let argent = engine.joueur?.argent ?? 0
        guard CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent) else {
            withAnimation {
                messageGain = false
                message = mise > argent
                    ? "Raymond regarde tes jetons, puis toi, puis tes jetons. Il manque des sous."
                    : "Mise entre \(Format.argent(lieu.miseMin)) et \(Format.argent(lieu.miseMax)), s'il te plaît."
            }
            return
        }
        guard engine.casinoMiser(mise, jeu: .blackjack) else {
            withAnimation {
                messageGain = false
                message = "Ta carte bancaire a refusé de participer."
            }
            return
        }
        self.engine = engine
        occupe = true
        miseTotale = mise
        miseInitiale = mise
        aCompteCetteMain = comptage

        var melange = false
        if sabot.count < BlackjackRegles.seuilMelange {
            sabot = CasinoCarte.paquet(jeux: BlackjackRegles.nombreJeux)
            compte = 0
            melange = true
        }

        withAnimation(.easeOut(duration: 0.2)) {
            message = nil
            messageGain = nil
            mains = [BlackjackMain(mise: mise)]
            croupier = []
            carteCacheeVisible = false
            angleCachee = 0
            mainActive = 0
            phase = .distribution
            phraseCroupier = melange
                ? BlackjackTextes.melange.randomElement()!
                : BlackjackTextes.distribution.randomElement()!
        }

        let etapes: [BlackjackEtape] = [.joueur(0), .croupier(cachee: false), .joueur(0), .croupier(cachee: true)]
        apres(melange ? 0.9 : 0.25) { t in
            t.jouerEtapes(etapes) { t2 in t2.apresDistribution() }
        }
    }

    private func apresDistribution() {
        guard !mains.isEmpty else { return }
        let joueurBJ = mains[0].estBlackjack
        let croupierBJ = BlackjackRegles.estBlackjack(croupier)
        if joueurBJ || croupierBJ {
            // Le croupier vérifie sa carte cachée : on passe directement au règlement.
            mains[0].terminee = true
            tourCroupier()
        } else {
            mainActive = 0
            phase = .joueur
            occupe = false
        }
    }

    func tirer() {
        guard peutTirer() else { return }
        occupe = true
        executer(.joueur(mainActive))
        apres(0.4) { t in t.verifierMainActive() }
    }

    func rester() {
        guard banni == nil, !occupe, mainCourante != nil else { return }
        occupe = true
        mains[mainActive].terminee = true
        mainSuivante()
    }

    func doubler(engine: GameEngine) {
        let argent = engine.joueur?.argent ?? 0
        guard peutDoubler(argent: argent) else { return }
        let i = mainActive
        let supplement = mains[i].mise
        guard engine.casinoMiser(supplement, jeu: .blackjack) else { return }
        occupe = true
        miseTotale += supplement
        mains[i].mise += supplement
        mains[i].doublee = true
        executer(.joueur(i))
        apres(0.55) { t in
            guard i < t.mains.count else { return }
            t.mains[i].terminee = true
            t.mainSuivante()
        }
    }

    func separer(engine: GameEngine) {
        let argent = engine.joueur?.argent ?? 0
        guard peutSeparer(argent: argent) else { return }
        let supplement = mains[0].mise
        guard engine.casinoMiser(supplement, jeu: .blackjack) else { return }
        occupe = true
        miseTotale += supplement
        let seconde = mains[0].cartes[1]
        let desAs = seconde.rang == 14
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            mains[0].cartes = [mains[0].cartes[0]]
            mains[0].issueSplit = true
            mains.append(BlackjackMain(cartes: [seconde], mise: supplement, issueSplit: true))
            mainActive = 0
            phraseCroupier = desAs
                ? "Des As séparés : une carte chacun, c'est le règlement. Raymond n'y peut rien, Raymond s'en fiche."
                : BlackjackTextes.separation.randomElement()!
        }
        apres(0.35) { t in
            t.jouerEtapes([.joueur(0), .joueur(1)]) { t2 in
                if desAs {
                    for k in t2.mains.indices { t2.mains[k].terminee = true }
                    t2.mainSuivante()
                } else {
                    t2.mainActive = 0
                    t2.verifierMainActive()
                }
            }
        }
    }

    private func verifierMainActive() {
        guard mainActive < mains.count else {
            mainSuivante()
            return
        }
        if mains[mainActive].terminee || mains[mainActive].total >= 21 {
            mains[mainActive].terminee = true
            mainSuivante()
        } else {
            phase = .joueur
            occupe = false
        }
    }

    private func mainSuivante() {
        if let i = mains.firstIndex(where: { !$0.terminee }) {
            mainActive = i
            verifierMainActive()
        } else {
            tourCroupier()
        }
    }

    private func tourCroupier() {
        occupe = true
        phase = .croupier
        reveler { t in
            let doitTirer = t.mains.contains { !$0.bust && !$0.estBlackjack }
            t.tirerCroupier(doitTirer)
        }
    }

    /// Retourne la carte cachée du croupier (demi-tour, changement de face, demi-tour).
    private func reveler(_ ensuite: @escaping (BlackjackTable) -> Void) {
        withAnimation(.easeIn(duration: 0.2)) { angleCachee = 90 }
        apres(0.2) { t in
            t.carteCacheeVisible = true
            if t.croupier.count > 1 { t.compte += BlackjackRegles.hiLo(t.croupier[1]) }
            withAnimation(.easeOut(duration: 0.22)) { t.angleCachee = 0 }
            t.apres(0.6) { t2 in ensuite(t2) }
        }
    }

    /// Le croupier tire jusqu'à 16 et reste sur tous les 17.
    private func tirerCroupier(_ doitTirer: Bool) {
        if doitTirer && BlackjackRegles.total(croupier) < 17 {
            executer(.croupier(cachee: false))
            apres(0.6) { t in t.tirerCroupier(true) }
        } else {
            regler()
        }
    }

    private func regler() {
        let totalCroupier = BlackjackRegles.total(croupier)
        let croupierBJ = BlackjackRegles.estBlackjack(croupier)
        let croupierSaute = totalCroupier > 21
        var paiement = 0
        var issues: [BlackjackIssue] = []

        for k in mains.indices {
            let m = mains[k]
            let issue: BlackjackIssue
            if m.bust {
                issue = .bust
            } else if m.estBlackjack && !croupierBJ {
                issue = .blackjack
            } else if croupierBJ {
                issue = m.estBlackjack ? .egalite : .perdu
            } else if croupierSaute {
                issue = .croupierSaute
            } else if m.total > totalCroupier {
                issue = .gagne
            } else if m.total < totalCroupier {
                issue = .perdu
            } else {
                issue = .egalite
            }
            paiement += issue.paiement(mise: m.mise)
            issues.append(issue)
            mains[k].issue = issue
        }

        let net = paiement - miseTotale
        let categorie: BlackjackIssue
        if issues.contains(.blackjack) {
            categorie = .blackjack
        } else if net > 0 {
            categorie = issues.contains(.croupierSaute) ? .croupierSaute : .gagne
        } else if net == 0 {
            categorie = .egalite
        } else if issues.allSatisfy({ $0 == .bust }) {
            categorie = .bust
        } else {
            categorie = .perdu
        }

        let feminin = engine?.joueur?.genre == .femme
        var texte: String
        if net > 0 {
            texte = (categorie == .blackjack ? "Blackjack ! " : "") + "Tu gagnes \(Format.argent(net))."
        } else if net == 0 {
            texte = "Égalité : mise rendue (\(Format.argent(miseTotale)))."
        } else {
            texte = "Tu perds \(Format.argent(-net))."
        }
        if mains.count > 1 {
            texte += " (" + mains.map { $0.issue?.libelle ?? "?" }.joined(separator: " / ") + ")"
        }

        engine?.casinoRegler(mise: miseTotale, paiement: paiement, jeu: .blackjack, detail: "Blackjack")

        var phrase = BlackjackTextes.accorder(BlackjackTextes.phrases(categorie).randomElement()!, feminin: feminin)

        // Comptage de cartes : le chef de salle observe.
        if aCompteCetteMain, let engine = engine {
            let grosseVariation = miseMainPrecedente.map { miseInitiale >= 4 * $0 } ?? false
            let points = grosseVariation ? Int.random(in: 10...25) : Int.random(in: 3...6)
            if let ban = engine.casinoSoupcon(points, raison: "comptage de cartes au blackjack") {
                banni = ban
                phrase = BlackjackTextes.accorder(BlackjackTextes.bannissement.randomElement()!, feminin: feminin)
            } else if grosseVariation {
                phrase += " " + BlackjackTextes.accorder(BlackjackTextes.soupconsForts.randomElement()!, feminin: feminin)
            }
        }
        miseMainPrecedente = miseInitiale

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            message = texte
            messageGain = net > 0 ? true : (net < 0 ? false : nil)
            phraseCroupier = phrase
            phase = .fin
        }
        occupe = false
    }

    /// Ferme la table (bannissement détecté à l'ouverture).
    func fermer(_ texte: String) {
        banni = texte
    }
}

// MARK: - Textes

/// Les répliques de Raymond, croupier depuis 1987, qui n'a jamais souri en service.
enum BlackjackTextes {
    /// Remplace les « {masculin/féminin} » selon le genre du joueur.
    static func accorder(_ texte: String, feminin: Bool) -> String {
        var resultat = ""
        var reste = Substring(texte)
        while let debut = reste.firstIndex(of: "{"), let fin = reste[debut...].firstIndex(of: "}") {
            resultat.append(contentsOf: reste[..<debut])
            let contenu = reste[reste.index(after: debut)..<fin]
            let parties = contenu.split(separator: "/", omittingEmptySubsequences: false)
            if parties.count == 2 {
                resultat.append(contentsOf: feminin ? parties[1] : parties[0])
            } else {
                resultat.append(contentsOf: contenu)
            }
            reste = reste[reste.index(after: fin)...]
        }
        resultat.append(contentsOf: reste)
        return resultat
    }

    static func phrases(_ issue: BlackjackIssue) -> [String] {
        switch issue {
        case .gagne: return gagne
        case .perdu: return perdu
        case .blackjack: return blackjack
        case .bust: return bust
        case .egalite: return egalite
        case .croupierSaute: return croupierSaute
        }
    }

    static let accueil = [
        "« Bienvenue. Je m'appelle Raymond. Je ne transpire pas, je ne cligne pas des yeux, je distribue. »",
        "« Asseyez-vous. Le tabouret est chaud, le précédent joueur vient de partir en pleurant. »",
        "« Six jeux dans le sabot, zéro pitié dans le cœur. Mise quand tu veux. »",
        "« Ici, on vise 21. Pas 22. Les gens confondent souvent. »",
        "« Je vous préviens : je suis payé pareil que vous gagniez ou non. Enfin, surtout quand vous perdez. »",
        "« Bonsoir. Ou bonjour. Il n'y a pas d'horloge ici, je ne sais plus. »",
    ]

    static let distribution = [
        "« Cartes. »",
        "« Et une, et deux… je pourrais faire ça les yeux fermés. Je l'ai déjà fait, d'ailleurs. »",
        "« Que la chance soit avec toi. Pas trop quand même. »",
        "« Je distribue. Toi, tu espères. Chacun son métier. »",
        "« Attention, cartes chaudes. Elles sortent du sabot. »",
        "« Voilà. Ne regarde pas mes cartes, je ne regarde pas ton compte en banque. »",
        "« Je sens que c'est ta main. Je dis ça à tout le monde. »",
    ]

    static let melange = [
        "« Petite pause : je remélange les six jeux. Admire mes poignets. »",
        "« Le sabot est presque vide, comme tes poches bientôt. Je remélange. »",
        "« Nouveau mélange ! Tout ce que tu as mémorisé ne vaut plus rien. »",
        "« Je mélange. Ça fait un bruit de pluie, c'est relaxant. Pour moi. »",
        "« Trois cent douze cartes, une seule intention : te prendre ta mise. »",
        "« Remélange réglementaire. Non, tu ne peux pas couper avec ta carte Vitale. »",
    ]

    static let separation = [
        "« Deux mains ? Ambitieux. Deux fois plus de chances de perdre. »",
        "« Séparation acceptée. Comme mon divorce. »",
        "« Tu coupes la paire en deux. Salomon serait fier. »",
        "« Deux mains, deux mises, deux fois plus de frissons. »",
        "« D'accord, on dédouble. Je préviens la comptabilité. »",
    ]

    static let gagne = [
        "« Bien joué. Je vais devoir expliquer ça à mon chef. »",
        "« Félicitations. Ne t'habitue pas, c'est mauvais pour la santé. »",
        "« Tu gagnes. Raymond encaisse le choc. Raymond est un professionnel. »",
        "« Voilà tes jetons. Le casino te remercie de bien vouloir les reperdre ici. »",
        "« Gagné. Tu as l'air {content/contente}. C'est louche. »",
        "« Ah. Bon. Très bien. Je vais aller pleurer dans le local à balais pendant ma pause. »",
        "« Belle main. Ma grand-mère aurait fait pareil, mais plus vite. »",
        "« Tu gagnes. Ne fais pas de danse, la caméra 14 filme tout. »",
        "« Payé. Profite, ça arrive environ une fois sur deux, et ça ne dure jamais. »",
        "« Victoire. Je propose qu'on n'en parle à personne. »",
    ]

    static let perdu = [
        "« Perdu. La maison te remercie pour ta contribution. »",
        "« Dommage. Ton argent est entre de bonnes mains : les nôtres. »",
        "« Je ramasse. Ne le prends pas personnellement, je fais ça à tout le monde. »",
        "« Raté. Mais tu as perdu avec beaucoup d'élégance. Enfin, de l'élégance. »",
        "« La banque gagne. La banque gagne toujours. C'est écrit au-dessus de la porte, en tout petit. »",
        "« Perdu. Tu veux un mouchoir ? Ils sont à 3 €. »",
        "« Ça arrive. Surtout à toi, apparemment. »",
        "« Ne regarde pas le plafond, il n'y a pas de remboursement là-haut. »",
        "« Perdu. Tu peux te refaire. Statistiquement non, mais émotionnellement oui. »",
        "« Merci, je vais pouvoir payer mon parking. »",
    ]

    static let blackjack = [
        "« Blackjack. Raymond n'a pas cligné des yeux depuis 1987, mais là il cligne. »",
        "« Vingt-et-un du premier coup. Tu as un pacte avec quelqu'un ? »",
        "« Blackjack ! Payé trois pour deux. Je compte lentement pour profiter du malaise. »",
        "« Un As et une figure. Le plus beau couple du casino, après le directeur et son yacht. »",
        "« Blackjack. Je vais devoir prévenir le chef de salle que tu es {né/née} sous une bonne étoile. »",
        "« Magnifique. Je te déteste un tout petit peu, professionnellement. »",
        "« Blackjack ! Les machines à sous de la salle d'à côté sont jalouses. »",
        "« Ah. Le naturel. Revenu au galop, comme on dit. »",
    ]

    static let bust = [
        "« Vingt-deux. Si près. Si loin. Surtout loin. »",
        "« Tu as sauté. Comme un bouchon de champagne, mais en triste. »",
        "« Trop ! Le 21, c'est un plafond, pas un échauffement. »",
        "« Tu as dépassé. Je ne juge pas. Si, un peu. »",
        "« Explosion. Le service de nettoyage est prévenu. »",
        "« Tu as tiré sur 16 ? Courageux{/se}. Pas malin, mais courageux{/se}. »",
        "« Sauté ! Même moi, je ne l'aurais pas fait. Et je suis payé pour que tu le fasses. »",
        "« C'est ce qu'on appelle viser la Lune et finir dans le parking. »",
        "« Bust. Un mot anglais pour dire « ruiné » plus vite. »",
        "« Tu as voulu une carte de plus. Elle a voulu ton argent. »",
    ]

    static let egalite = [
        "« Égalité. Personne ne gagne, personne ne perd, tout le monde s'ennuie. »",
        "« Match nul. Je te rends ta mise, avec mon regard déçu en prime. »",
        "« Égalité. On appelle ça « pousser ». Moi j'appelle ça « perdre du temps ». »",
        "« Ex æquo. Comme deux cousins à un mariage : on fait semblant d'être contents. »",
        "« Égalité. Ta mise revient, intacte et un peu traumatisée. »",
        "« Même total. C'est presque romantique. »",
        "« Égalité. Les comptables du casino soupirent dans leur bureau. »",
        "« Personne ne gagne. C'est la Suisse de la main. »",
    ]

    static let croupierSaute = [
        "« J'ai sauté. Ça arrive aux meilleurs. Surtout à moi, ce soir. »",
        "« Vingt-quatre. Le sabot m'a trahi. Je ne lui parle plus. »",
        "« J'ai dépassé. Je vais réfléchir à ma vie pendant ma pause cigarette. »",
        "« Le croupier saute, le joueur encaisse, le chef de salle grimace. »",
        "« Ah. Trop. Je mets ça sur le compte de la climatisation. »",
        "« J'ai explosé. Ne le répète pas, j'ai une réputation. »",
        "« Le règlement m'oblige à tirer sur 16. Le règlement est mon ennemi. »",
        "« Payé. Je te regarde comme on regarde un pigeon qui vient de voler une frite. »",
    ]

    static let soupconsForts = [
        "Un monsieur en costume vient de noter quelque chose dans un petit carnet.",
        "Le chef de salle s'est rapproché de la table. Il fait semblant de lire le menu du bar.",
        "Raymond murmure dans son col de chemise. Il n'a pas de micro. Si ?",
        "Une caméra au plafond vient de tourner vers toi avec un petit bruit sec.",
        "Une dame en tailleur te fixe depuis le bar. Elle ne boit rien.",
        "« Belle progression de mise », dit Raymond, sans aucune intonation.",
    ]

    static let bannissement = [
        "« Je crois que quelqu'un veut te parler. » Raymond désigne deux armoires à glace derrière toi.",
        "« On sait compter, nous aussi. » Raymond range ses cartes et ne te regarde plus.",
        "« Ta mémoire est impressionnante. Celle de notre service de sécurité aussi. »",
        "« Dommage, tu étais {mon client préféré/ma cliente préférée}. Non, je mens. »",
        "« La table est fermée. Pour toi. Pour longtemps. »",
        "« Le comptage de cartes n'est pas illégal. Mais te mettre dehors non plus. »",
    ]
}

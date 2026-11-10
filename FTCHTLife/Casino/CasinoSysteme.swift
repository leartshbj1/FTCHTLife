import Foundation
import SwiftUI

// MARK: - Stockage

/// Garde l'état casino de chaque vie.
///
/// Tant que `Joueur` n'a pas de champ `casino`, l'état est rangé à côté de la sauvegarde,
/// sous la clé de la vie (identifiant de la première année du journal). Le jour où le moteur
/// ajoute `var casino: CasinoEtat?` à `Joueur`, il suffit de changer `etat(pour:)` et
/// `enregistrer(_:pour:)` : tout le reste du module passe par ces deux fonctions.
final class CasinoStockage: ObservableObject {
    static let shared = CasinoStockage()

    @Published private(set) var etats: [String: CasinoEtat] = [:]

    private var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ftchtlife-casino.json")
    }

    private init() {
        if let data = try? Data(contentsOf: url),
           let e = try? JSONDecoder().decode([String: CasinoEtat].self, from: data) {
            etats = e
        }
    }

    static func cle(_ j: Joueur) -> String {
        j.journal.first.map { $0.id.uuidString } ?? "\(j.prenom)|\(j.nom)|\(j.ville)"
    }

    func etat(pour j: Joueur) -> CasinoEtat {
        etats[Self.cle(j)] ?? CasinoEtat()
    }

    func enregistrer(_ e: CasinoEtat, pour j: Joueur) {
        let cle = Self.cle(j)
        // On ne garde que la vie en cours : les anciennes vies sont oubliées.
        etats = [cle: e]
        if let data = try? JSONEncoder().encode(etats) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Signaux pour les répercussions

/// Signaux envoyés au système de répercussions (suites différées : addiction, famille qui réclame
/// sa part d'un gros gain…). Le moteur branche `CasinoSignaux.recepteur` sur
/// `Repercussions.signaler` ; tant qu'il n'est pas branché, les signaux sont ignorés.
///
/// Signaux émis : casino_gain, casino_perte, casino_jackpot, casino_ruine, casino_triche,
/// casino_triche_attrape, casino_usurier, casino_usurier_violence, loterie_ticket, loterie_gain,
/// pari_sportif_gain, pari_sportif_perte.
enum CasinoSignaux {
    static var recepteur: ((String, inout Joueur) -> Void)?

    static func emettre(_ signal: String, _ j: inout Joueur) {
        recepteur?(signal, &j)
    }
}

// MARK: - Branchement moteur

extension GameEngine {

    /// État casino de la vie en cours.
    var casinoEtat: CasinoEtat {
        guard let j = joueur else { return CasinoEtat() }
        return CasinoStockage.shared.etat(pour: j)
    }

    /// Modifie le joueur et son état casino en une fois, puis sauvegarde.
    func casinoModifier(_ action: (inout Joueur, inout CasinoEtat) -> Void) {
        guard let j0 = joueur else { return }
        var etat = CasinoStockage.shared.etat(pour: j0)
        modifier { j in action(&j, &etat) }
        if let j = joueur { CasinoStockage.shared.enregistrer(etat, pour: j) }
    }

    /// Pourquoi le joueur ne peut pas entrer dans ce lieu, ou nil s'il peut.
    func casinoRefusEntree(_ lieu: CasinoLieu) -> String? {
        guard let j = joueur, j.vivant else { return "Les morts ne jouent pas. Officiellement." }
        let e = casinoEtat
        if j.age < 18 {
            return ["Le videur t'a regardé, a ri, et t'a raccompagné jusqu'à l'arrêt de bus.",
                    "« Reviens quand tu auras de la barbe, ou au moins 18 ans. »",
                    "On t'a offert un sirop de grenadine et montré la sortie."].randomElement()!
        }
        if lieu.respecteInterdiction && e.estInterdit(age: j.age) {
            let fin = e.interditJusqua ?? j.age
            return "Tu es " + j.g("interdit", "interdite") + " de casino jusqu'à \(fin) ans (\(e.raisonInterdiction ?? "sur décision du directeur")). Ta photo est scotchée à l'entrée."
        }
        if lieu == .palais && e.vip < .or && j.argent < 1_000_000 && j.stats.apparence < 90 {
            return "Le portier a regardé tes chaussures, puis ton relevé de compte imaginaire, et a dit non. Il faut la carte Or ou 1'000'000 € sur le compte."
        }
        return nil
    }

    /// À appeler quand le joueur entre dans un lieu. Renvoie un message s'il s'est passé quelque chose
    /// (descente de police au tripot, cadeau VIP…).
    func casinoEntrer(_ lieu: CasinoLieu) -> String? {
        guard casinoRefusEntree(lieu) == nil else { return nil }
        var message: String?
        if lieu == .tripot && Double.random(in: 0...1) < 0.06 {
            casinoModifier { j, _ in
                let amende = min(max(j.argent, 0), 3_000)
                j.argent -= amende
                j.stats.karma -= 8
                j.stats.bonheur -= 5
                message = "🚨 Descente de police à l'Arrière-Boutique ! Tu as essayé de te cacher dans un placard à balais. Amende : \(Format.argent(amende))."
                ajouterLigne(&j, message!)
            }
        }
        return message
    }

    /// Retire une mise du compte du joueur. Renvoie false si c'est impossible (pas assez d'argent, mise nulle…).
    /// À appeler à chaque mise, y compris les relances (doubler au blackjack, relancer au poker).
    @discardableResult
    func casinoMiser(_ mise: Int, jeu: CasinoJeu) -> Bool {
        guard mise > 0, let j = joueur, j.vivant, j.argent >= mise else { return false }
        let avant = max(j.argent, 1)
        casinoModifier { j, e in
            j.argent -= mise
            e.totalMise += mise
            e.miseAnnee += mise
            var s = e.parJeu[jeu.rawValue] ?? CasinoStatJeu()
            s.mise += mise
            e.parJeu[jeu.rawValue] = s
            // Plus on mise une grosse part de ce qu'on a, plus on devient accro.
            let part = min(1.0, Double(mise) / Double(max(avant, 500)))
            e.ajouterAddiction(0.12 + 2.5 * part)
        }
        return true
    }

    /// Règle une partie : `paiement` est ce que le joueur récupère (mise comprise), 0 s'il a tout perdu.
    /// `mise` est le total misé sur la partie (relances comprises). Compte la partie dans les statistiques,
    /// fait varier le bonheur et écrit dans le journal les gains et pertes marquants.
    func casinoRegler(mise: Int, paiement: Int, jeu: CasinoJeu, detail: String? = nil) {
        guard let j0 = joueur, j0.vivant else { return }
        let net = paiement - mise
        let fortune = max(j0.argent + paiement, 1_000)
        casinoModifier { j, e in
            j.argent += paiement
            e.totalGagne += paiement
            e.gagneAnnee += paiement
            e.partiesAnnee += 1
            var s = e.parJeu[jeu.rawValue] ?? CasinoStatJeu()
            s.parties += 1
            s.gagne += paiement
            e.parJeu[jeu.rawValue] = s

            if net > 0 {
                e.plusGrosGain = max(e.plusGrosGain, net)
                // La victoire, c'est ce qui rend accro.
                let multiplicateur = Double(paiement) / Double(max(mise, 1))
                if multiplicateur >= 20 { e.ajouterAddiction(1.5); e.jackpots += 1 }
                if Double(net) > Double(fortune) * 0.2 || net >= 10_000 { j.stats.bonheur += Int.random(in: 2...6) }
                else if Bool.random() { j.stats.bonheur += 1 }
            } else if net < 0 {
                e.plusGrossePerte = max(e.plusGrossePerte, -net)
                if Double(-net) > Double(fortune) * 0.2 {
                    j.stats.bonheur -= Int.random(in: 3...8)
                    // « Je vais me refaire » : perdre gros donne envie de rejouer.
                    e.ajouterAddiction(1.0)
                }
            }

            let estLoterie = jeu == .loto || jeu == .grattage
            let estPari = jeu == .paris || jeu == .courses
            if estLoterie {
                CasinoSignaux.emettre("loterie_ticket", &j)
                if net > 0 { CasinoSignaux.emettre("loterie_gain", &j) }
            } else if estPari {
                CasinoSignaux.emettre(net > 0 ? "pari_sportif_gain" : "pari_sportif_perte", &j)
            } else if net != 0 {
                CasinoSignaux.emettre(net > 0 ? "casino_gain" : "casino_perte", &j)
            }
            if net > 0 && Double(paiement) >= Double(mise) * 20 && net >= 1_000 { CasinoSignaux.emettre("casino_jackpot", &j) }
            if net < 0 && j.argent < 100 && mise >= 1_000 { CasinoSignaux.emettre("casino_ruine", &j) }

            if net >= 50_000 || (net >= 5_000 && Double(paiement) >= Double(mise) * 20) {
                ajouterLigne(&j, "🎰 \(detail ?? jeu.nom) : tu as gagné \(Format.argent(net)) ! " + CasinoTextes.grosGains.randomElement()!)
            } else if -net >= 50_000 {
                ajouterLigne(&j, "💸 \(detail ?? jeu.nom) : tu as perdu \(Format.argent(-net)). " + CasinoTextes.grossesPertes.randomElement()!)
            }
        }
    }

    /// Ajoute des soupçons de triche (comptage de cartes, machine secouée…).
    /// Renvoie un message si le joueur vient d'être banni.
    @discardableResult
    func casinoSoupcon(_ points: Int, raison: String) -> String? {
        var message: String?
        casinoModifier { j, e in
            e.soupcons += points
            CasinoSignaux.emettre("casino_triche", &j)
            if e.soupcons >= 100 {
                CasinoSignaux.emettre("casino_triche_attrape", &j)
                e.soupcons = 0
                e.interditJusqua = j.age + 5
                e.raisonInterdiction = raison
                j.stats.karma -= 5
                message = "🚫 Deux messieurs en costume t'ont soulevé par les coudes et sorti du casino. Tu es " + j.g("interdit", "interdite") + " de casino pendant 5 ans (\(raison))."
                ajouterLigne(&j, message!)
            }
        }
        return message
    }

    /// Fait avancer un gros lot progressif (machines, loto) et renvoie sa nouvelle valeur.
    func casinoJackpot(loto: Bool, ajouter: Int = 0, reinitialiser: Bool = false) -> Int {
        var valeur = 0
        casinoModifier { _, e in
            if loto {
                e.jackpotLoto = reinitialiser ? 3_000_000 : e.jackpotLoto + ajouter
                valeur = e.jackpotLoto
            } else {
                e.jackpotMachine = reinitialiser ? 250_000 : e.jackpotMachine + ajouter
                valeur = e.jackpotMachine
            }
        }
        return valeur
    }
}

// MARK: - Soins, usurier, interdiction volontaire

extension GameEngine {

    func casinoPeutAllerJA() -> Bool {
        guard let j = joueur, j.age >= 16 else { return false }
        return !j.actionsAnnee.contains("casino_ja")
    }

    /// Réunion des Joueurs Anonymes (une fois par an, gratuite).
    func casinoJoueursAnonymes() -> String {
        guard casinoPeutAllerJA() else { return "Tu es déjà " + (joueur?.g("allé", "allée") ?? "allé") + " à une réunion cette année. Le café y est trop mauvais pour y retourner." }
        var texte = ""
        casinoModifier { j, e in
            j.actionsAnnee.append("casino_ja")
            e.reunionsJA += 1
            let baisse = Double.random(in: 8...15)
            e.ajouterAddiction(-baisse)
            j.stats.bonheur += 3
            texte = CasinoTextes.reunionsJA.randomElement()! + " (-\(Int(baisse)) addiction)"
            ajouterLigne(&j, "🤝 Joueurs Anonymes : " + texte)
        }
        return texte
    }

    static let casinoPrixCure = 15_000

    func casinoPeutFaireCure() -> Bool {
        guard let j = joueur, j.age >= 16 else { return false }
        return !j.actionsAnnee.contains("casino_cure")
    }

    /// Cure dans une clinique spécialisée (chère, très efficace).
    func casinoCure() -> String {
        guard let j0 = joueur else { return "" }
        guard casinoPeutFaireCure() else { return "Tu as déjà fait une cure cette année." }
        guard j0.argent >= Self.casinoPrixCure else { return "La clinique Les Tilleuls Zen coûte \(Format.argent(Self.casinoPrixCure)). Ironiquement, tu as tout perdu au jeu." }
        var texte = ""
        casinoModifier { j, e in
            j.actionsAnnee.append("casino_cure")
            j.argent -= Self.casinoPrixCure
            e.curesSuivies += 1
            e.ajouterAddiction(-Double.random(in: 35...50))
            j.stats.bonheur += 5
            j.stats.sante += 3
            texte = CasinoTextes.cures.randomElement()!
            ajouterLigne(&j, "🌿 Cure de désintoxication au jeu : " + texte)
        }
        return texte
    }

    /// Se faire interdire volontairement de casino pendant `annees` ans.
    func casinoAutoInterdiction(annees: Int = 5) -> String {
        var texte = ""
        casinoModifier { j, e in
            e.interditJusqua = max(e.interditJusqua ?? 0, j.age + annees)
            e.raisonInterdiction = "interdiction volontaire"
            j.stats.karma += 3
            texte = "Tu as signé ta propre interdiction de casino pour \(annees) ans. L'employé t'a serré la main comme à un héros de guerre."
            ajouterLigne(&j, "🚪 " + texte)
        }
        return texte
    }

    /// Montant maximum que Tonton Gégé accepte de prêter.
    var casinoPlafondUsurier: Int {
        guard let j = joueur, j.age >= 18 else { return 0 }
        let e = casinoEtat
        if e.anneesDetteImpayee >= 2 { return 0 }
        var plafond = 10_000
        if let emploi = j.emploi { plafond = max(plafond, emploi.salaire) }
        if e.vip >= .argent { plafond *= 3 }
        return max(0, plafond * 2 - e.detteUsurier)
    }

    /// Emprunter à l'usurier. Intérêts : 30 % par an.
    func casinoEmprunter(_ montant: Int) -> String {
        guard montant > 0 else { return "" }
        guard montant <= casinoPlafondUsurier else {
            return "Tonton Gégé a ri très fort, puis plus du tout. « Pas plus de \(Format.argent(casinoPlafondUsurier)), mon petit. »"
        }
        var texte = ""
        casinoModifier { j, e in
            j.argent += montant
            e.detteUsurier += montant
            j.stats.karma -= 2
            CasinoSignaux.emettre("casino_usurier", &j)
            texte = "Tonton Gégé t'a prêté \(Format.argent(montant)) en billets froissés. « 30 % par an. Et je sais où habite ta mère. »"
            ajouterLigne(&j, "🤌 " + texte)
        }
        return texte
    }

    /// Rembourser l'usurier.
    func casinoRembourser(_ montant: Int) -> String {
        guard let j0 = joueur else { return "" }
        let e0 = casinoEtat
        let paye = min(montant, e0.detteUsurier, max(j0.argent, 0))
        guard paye > 0 else { return "Tu n'as rien à rembourser, ou rien pour rembourser." }
        var texte = ""
        casinoModifier { j, e in
            j.argent -= paye
            e.detteUsurier -= paye
            if e.detteUsurier == 0 {
                e.anneesDetteImpayee = 0
                texte = "Dette réglée ! Tonton Gégé t'a pincé la joue. Tu ne sais pas si c'était affectueux."
                ajouterLigne(&j, "🤝 Tu as fini de rembourser Tonton Gégé.")
            } else {
                texte = "Tu as remboursé \(Format.argent(paye)). Il reste \(Format.argent(e.detteUsurier)). Gégé compte les billets en léchant son pouce."
            }
        }
        return texte
    }
}

// MARK: - Passage de l'année et étiquettes (appelés par le moteur)

enum CasinoSysteme {

    /// Étiquettes à ajouter à `GameEngine.tags(_:)` pour les événements casino.
    static func tags(_ j: Joueur) -> Set<String> {
        let e = CasinoStockage.shared.etat(pour: j)
        var t: Set<String> = []
        if e.totalMise > 0 { t.insert("gambled") }
        if e.addiction >= 25 { t.insert("gambler") }
        if e.addiction >= 60 { t.insert("gambling_addict") }
        if e.addictionMax >= 60 && e.addiction < 25 { t.insert("gambler_recovering") }
        if e.detteUsurier > 0 { t.insert("casino_debt") }
        if e.vip >= .or { t.insert("casino_vip") }
        if e.estInterdit(age: j.age) { t.insert("casino_banned") }
        if e.plusGrosGain >= 100_000 { t.insert("casino_winner") }
        if e.netVie <= -100_000 { t.insert("casino_ruined") }
        return t
    }

    /// À appeler dans `vieillir()` après `j.age += 1`. Renvoie les lignes à ajouter au journal de la
    /// nouvelle année et, si l'usurier a perdu patience pour de bon, une cause de décès.
    static func finAnnee(_ j: inout Joueur) -> (lignes: [String], deces: String?) {
        guard j.vivant else { return ([], nil) }
        var e = CasinoStockage.shared.etat(pour: j)
        var lignes: [String] = []
        var deces: String?
        let aJoue = e.partiesAnnee > 0

        // Bilan de l'année écoulée.
        if aJoue {
            let net = e.netAnnee
            let signe = net >= 0 ? "+" : "−"
            lignes.append("🎲 Bilan jeux de l'an dernier : \(Format.argent(e.miseAnnee)) misés, \(signe)\(Format.argent(abs(net))).")
            e.anneesSansJouer = 0
            e.ajouterAddiction(-1.5)
            if e.vip >= .argent && Double.random(in: 0...1) < 0.6 {
                j.stats.bonheur += 4
                lignes.append(CasinoTextes.cadeauxVIP.randomElement()!)
            }
        } else if e.totalMise > 0 {
            e.anneesSansJouer += 1
            let interdit = e.estInterdit(age: j.age)
            e.ajouterAddiction(interdit ? -12 : -7)
        }

        // Conséquences de l'addiction.
        let niveau = CasinoNiveauAddiction.pour(e.addiction)
        if niveau.rawValue >= CasinoNiveauAddiction.accro.rawValue {
            j.stats.bonheur -= Int.random(in: 3...8)
            if Double.random(in: 0...1) < (niveau == .compulsif ? 0.6 : 0.35), j.argent > 200 {
                let perte = max(200, Int(Double(j.argent) * Double.random(in: 0.05...0.25)))
                j.argent -= perte
                e.totalMise += perte
                lignes.append("🎰 " + CasinoTextes.envies.randomElement()! + " (−\(Format.argent(perte)))")
            }
            if let i = j.relations.firstIndex(where: { $0.type == .partenaire && $0.vivant }), Double.random(in: 0...1) < 0.4 {
                j.relations[i].lien = Stats.borne(j.relations[i].lien - Int.random(in: 8...20))
                lignes.append(CasinoTextes.partenaireFache.randomElement()!.replacingOccurrences(of: "{p}", with: j.relations[i].prenom))
            }
        }
        if niveau == .compulsif {
            j.stats.sante -= Int.random(in: 1...4)
            if Double.random(in: 0...1) < 0.3,
               let i = j.relations.indices.filter({ j.relations[$0].type.estParent && j.relations[$0].vivant && j.relations[$0].argent > 1_000 }).randomElement() {
                let pret = min(j.relations[i].argent / 4, 20_000)
                j.relations[i].argent -= pret
                j.relations[i].lien = Stats.borne(j.relations[i].lien - 15)
                j.argent += pret
                lignes.append("💔 Tu as « emprunté » \(Format.argent(pret)) à \(j.relations[i].prenom). Tu as juré que c'était pour un dentiste.")
            }
            j.stats.karma -= 2
        }
        // Rechute d'un ancien accro.
        if !aJoue && e.addictionMax >= 60 && e.addiction < 30 && Double.random(in: 0...1) < 0.12 {
            e.ajouterAddiction(20)
            lignes.append(CasinoTextes.rechutes.randomElement()!)
        }

        // Usurier.
        if e.detteUsurier > 0 {
            e.detteUsurier = Int(Double(e.detteUsurier) * 1.30)
            e.anneesDetteImpayee += 1
            switch e.anneesDetteImpayee {
            case 1:
                lignes.append("🤌 Tonton Gégé te rappelle que tu lui dois \(Format.argent(e.detteUsurier)). Il a dit « bonne année » en faisant craquer ses doigts.")
            case 2:
                if j.argent >= e.detteUsurier {
                    j.argent -= e.detteUsurier
                    lignes.append("🚪 Les neveux de Tonton Gégé sont passés « faire les comptes ». Ils ont pris \(Format.argent(e.detteUsurier)) et ta télé, par principe.")
                    e.detteUsurier = 0
                    e.anneesDetteImpayee = 0
                } else {
                    j.stats.sante -= Int.random(in: 15...30)
                    j.stats.bonheur -= 10
                    CasinoSignaux.emettre("casino_usurier_violence", &j)
                    lignes.append("🦵 Les neveux de Tonton Gégé t'ont attendu en bas de chez toi. Tu as maintenant une jambe qui regarde à gauche. Dette : \(Format.argent(e.detteUsurier)).")
                }
            default:
                if j.argent >= e.detteUsurier {
                    j.argent -= e.detteUsurier
                    lignes.append("🚪 Tonton Gégé s'est servi directement sur ton compte. Tu ne sais pas comment. Tu ne veux pas savoir.")
                    e.detteUsurier = 0
                    e.anneesDetteImpayee = 0
                } else if Double.random(in: 0...1) < 0.2 {
                    deces = ["après une « discussion » avec Tonton Gégé au bord du canal",
                             "en tombant tout seul dans une bétonnière, d'après Tonton Gégé",
                             "lors d'une partie de pêche avec les neveux de Tonton Gégé. Tu étais l'appât"].randomElement()!
                } else {
                    j.stats.sante -= Int.random(in: 20...35)
                    CasinoSignaux.emettre("casino_usurier_violence", &j)
                    lignes.append("🩼 Nouvelle visite des neveux de Tonton Gégé. Ton dentiste va pouvoir s'acheter un bateau.")
                }
            }
        }

        // Fin d'interdiction.
        if let fin = e.interditJusqua, j.age == fin {
            lignes.append("🎟️ Ton interdiction de casino est levée. Le vigile a enlevé ta photo du mur. Il l'a gardée.")
            e.interditJusqua = nil
            e.raisonInterdiction = nil
        }
        e.soupcons = max(0, e.soupcons - 30)

        // Remise à zéro de l'année.
        e.miseAnnee = 0
        e.gagneAnnee = 0
        e.partiesAnnee = 0
        j.stats.borner()
        CasinoStockage.shared.enregistrer(e, pour: j)
        return (lignes, deces)
    }
}

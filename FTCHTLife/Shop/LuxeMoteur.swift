import Foundation

/// Logique de la vie de luxe. Sans état propre : tout est dans `Possessions.luxe`.
enum LuxeMoteur {
    static var catalogue: LuxeCatalogue { .shared }

    // MARK: Outils

    /// Patrimoine : argent + valeur des biens − crédits.
    static func patrimoine(_ p: some ShopActor) -> Int {
        p.money + p.boutique.netWorthOfAssets
    }

    /// Remet à zéro les « une fois par an » quand le perso a pris un an.
    static func etat<P: ShopActor>(_ p: inout P) -> LuxeEtat {
        var l = p.boutique.luxe ?? LuxeEtat()
        if l.annee != p.age {
            l.annee = p.age
            l.faitsCetteAnnee = []
        }
        p.boutique.luxe = l
        return l
    }

    static func dejaFait(_ id: String, _ p: some ShopActor) -> Bool {
        guard let l = p.boutique.luxe, l.annee == p.age else { return false }
        return l.faitsCetteAnnee.contains(id)
    }

    private static func marquer<P: ShopActor>(_ id: String, _ p: inout P) {
        var l = etat(&p)
        if !l.faitsCetteAnnee.contains(id) { l.faitsCetteAnnee.append(id) }
        p.boutique.luxe = l
    }

    static func prix(_ base: Int) -> Int {
        max(1, Int((Double(base) * ShopHooks.priceMultiplier("luxe")).rounded()))
    }

    /// Raison pour laquelle une porte reste fermée, ou nil si elle s'ouvre.
    static func verrou(minAge: Int = 0, minPatrimoine: Int?, minMondanite: Int?, _ p: some ShopActor) -> String? {
        if p.age < minAge { return "Dès \(minAge) ans." }
        if let m = minPatrimoine, m > 0, patrimoine(p) < m {
            return "Sur invitation : il faut un patrimoine d'au moins \(Format.argent(m))."
        }
        if let m = minMondanite, m > 0, p.mondanite < m {
            return "Sur liste : il faut une mondanité d'au moins \(m)/100. Fais-toi un nom d'abord."
        }
        return nil
    }

    static func verrou(_ m: LuxeMaison, _ p: some ShopActor) -> String? {
        verrou(minPatrimoine: m.minPatrimoine, minMondanite: m.minMondanite, p)
    }

    static func verrou(_ s: LuxeService, _ p: some ShopActor) -> String? {
        if let v = verrou(minAge: s.minAge, minPatrimoine: s.minPatrimoine, minMondanite: s.minMondanite, p) { return v }
        if dejaFait(s.id, p) { return "Déjà fait cette année. Reviens après « Âge +1 »." }
        return nil
    }

    static func titreMondain(_ m: Int) -> String {
        switch m {
        case ..<10: return "Inconnu au bataillon"
        case ..<25: return "Visage familier"
        case ..<45: return "Habitué des soirées"
        case ..<65: return "Personnalité en vue"
        case ..<85: return "Star des magazines"
        default: return "Icône mondiale"
        }
    }

    // MARK: Spa et soirées VIP

    static func profiter<P: ShopActor>(_ s: LuxeService, _ p: inout P) -> ShopResult {
        if let v = verrou(s, p) { return ShopResult(ok: false, message: v) }
        let cout = prix(s.price)
        guard ShopHooks.canAfford(cout, p.money) else {
            return ShopResult(ok: false, message: s.type == .spa
                ? "L'hôtesse a regardé ta carte bancaire, puis la porte. Message reçu."
                : "Le videur a vérifié ton nom sur la liste, puis ton compte en banque. Ni l'un ni l'autre n'y est.")
        }
        var rng = SystemRandomNumberGenerator()
        ShopEngine.pay(cout, &p)
        marquer(s.id, &p)
        var texte = "\(s.name) (\(Format.argent(cout)))."
        if let e = s.effects { ShopEngine.apply(e, itemId: nil, &p) }
        if let o = ShopEngine.pick(s.outcomes, using: &rng) {
            texte += " " + ShopEngine.fill(o.text, person: p)
            if let e = o.effects { ShopEngine.apply(e, itemId: nil, &p) }
        }
        var l = p.boutique.luxe ?? LuxeEtat()
        if s.type == .spa { l.spaTotal += 1 } else { l.soireesTotal += 1 }
        p.boutique.luxe = l
        return ShopResult(ok: true, message: texte)
    }

    // MARK: Dons

    static let montantsDon = [50, 500, 5_000, 50_000, 500_000, 5_000_000, 50_000_000, 500_000_000]

    static func titreDonateur(_ total: Int) -> String? {
        switch total {
        case ..<1_000: return nil
        case ..<100_000: return "Donateur fidèle"
        case ..<1_000_000: return "Bienfaiteur"
        case ..<10_000_000: return "Mécène"
        case ..<100_000_000: return "Grand philanthrope"
        default: return "Légende de la philanthropie"
        }
    }

    static func donner<P: ShopActor>(_ montant: Int, a o: LuxeOeuvre, anonyme: Bool, _ p: inout P) -> ShopResult {
        guard montant > 0 else { return ShopResult(ok: false, message: "Un don de zéro euro. Même le reçu fiscal a eu honte.") }
        guard p.age >= 12 else { return ShopResult(ok: false, message: "Tes parents ont confisqué ta tirelire avant que tu la vides. Dès 12 ans.") }
        guard ShopHooks.canAfford(montant, p.money) else {
            return ShopResult(ok: false, message: "Ta banque a refusé le virement. Généreux, oui. Solvable, non.")
        }
        var rng = SystemRandomNumberGenerator()
        let fortune = max(1, p.money)
        ShopEngine.pay(montant, &p)
        let cle = "don_" + o.id
        let premierDeLAnnee = !dejaFait(cle, p)
        marquer(cle, &p)

        var l = p.boutique.luxe ?? LuxeEtat()
        let avant = l.donsParOeuvre[o.id] ?? 0
        let titreAvant = titreDonateur(l.donsTotal)
        l.donsTotal += montant
        l.donsParOeuvre[o.id] = avant + montant
        p.boutique.luxe = l

        var texte = "Tu as donné \(Format.argent(montant)) à \(o.name)."
        if let merci = o.merci.randomElement(using: &rng) {
            texte += " " + ShopEngine.fill(merci, person: p, amount: montant)
        }
        if premierDeLAnnee {
            // Karma et bonheur : un peu plus par ordre de grandeur, une fois par œuvre et par an.
            let ordre = max(1, Int(log10(Double(montant))))
            let karma = min(14, 2 * ordre - 2 + (anonyme ? 2 : 0))
            let bonheur = min(8, ordre)
            ShopEngine.applyStats(happiness: bonheur, karma: max(1, karma), &p)
            if !anonyme {
                let part = Double(montant) / Double(fortune)
                if montant >= 100_000 && part >= 0.01 {
                    p.mondanite += min(12, ordre - 3)
                    texte += " La presse parle de ta générosité. Ton nom est sur toutes les plaquettes du gala."
                } else if montant >= 100_000 && part < 0.001 {
                    p.mondanite -= 2
                    texte += " Un journaliste a calculé que c'était 0,1 % de ta fortune. Le titre de l'article est cruel."
                }
            } else {
                texte += " Personne ne saura que c'était toi. C'est peut-être ça, la classe."
            }
        } else {
            texte += " Ils t'ont déjà remercié cette année, mais l'argent, lui, fait du bien."
        }
        if avant < 1_000_000, avant + montant >= 1_000_000 {
            texte += " " + ShopEngine.fill(o.hommage, person: p)
            if !anonyme { p.mondanite += 3 }
        }
        if let t = titreDonateur(l.donsTotal), t != titreAvant {
            texte += " Nouveau titre : \(t)."
        }
        return ShopResult(ok: true, message: texte)
    }

    // MARK: Société secrète

    /// La société dont le perso est membre (nil s'il n'en a pas).
    static func societe(_ p: some ShopActor) -> LuxeSociete? {
        guard let m = p.boutique.luxe?.societe else { return nil }
        return catalogue.societe(m.societeId)
    }

    static func verrouCooptation(_ s: LuxeSociete, _ p: some ShopActor) -> String? {
        let l = p.boutique.luxe
        if l?.bannies.contains(s.id) == true { return "Ils ne t'ont pas oublié. Et ils ne pardonnent pas." }
        if l?.societe != nil { return "Tu appartiens déjà à une société. On ne sert pas deux maîtres." }
        if let v = verrou(minAge: s.minAge, minPatrimoine: s.minPatrimoine, minMondanite: s.minMondanite, p) { return v }
        if dejaFait("coopt_" + s.id, p) { return "Ta candidature a été examinée cette année. Patience." }
        return nil
    }

    static func demanderCooptation<P: ShopActor>(_ s: LuxeSociete, _ p: inout P) -> ShopResult {
        if let v = verrouCooptation(s, p) { return ShopResult(ok: false, message: v) }
        let droit = prix(s.droitEntree)
        guard ShopHooks.canAfford(droit, p.money) else {
            return ShopResult(ok: false, message: "Le droit d'entrée est de \(Format.argent(droit)). Ton parrain a fait semblant de ne pas te connaître.")
        }
        marquer("coopt_" + s.id, &p)
        // Plus on est riche et connu au-delà du minimum, plus la porte s'ouvre facilement.
        var chance = 0.45
        if patrimoine(p) >= s.minPatrimoine * 3 { chance += 0.2 }
        if p.mondanite >= s.minMondanite + 20 { chance += 0.15 }
        if p.karma < 25 { chance += 0.05 }
        guard Double.random(in: 0..<1) < chance else {
            return ShopResult(ok: false, message: "Une enveloppe noire, sans timbre, dans ta boîte aux lettres : « Pas cette année. » Personne n'a vu qui l'a déposée.")
        }
        ShopEngine.pay(droit, &p)
        var l = p.boutique.luxe ?? LuxeEtat()
        l.societe = LuxeMembre(societeId: s.id)
        p.boutique.luxe = l
        ShopEngine.applyStats(happiness: 6, &p)
        let rang = s.rangs.first?.titre ?? "membre"
        return ShopResult(ok: true, message: "Cérémonie d'initiation, yeux bandés, serment à voix basse. Te voilà \(rang) de \(s.name). Droit d'entrée : \(Format.argent(droit)). Devise : « \(s.devise) »")
    }

    static func peutReunion(_ p: some ShopActor) -> Bool {
        guard societe(p) != nil, let m = p.boutique.luxe?.societe else { return false }
        return m.derniereReunion != p.age
    }

    /// Tire le rituel de la réunion annuelle. Le joueur choisit ensuite avec `resoudreRituel`.
    static func tirerRituel<P: ShopActor>(_ p: inout P) -> LuxeRituel? {
        guard let s = societe(p), var m = p.boutique.luxe?.societe, m.derniereReunion != p.age else { return nil }
        m.derniereReunion = p.age
        var l = p.boutique.luxe ?? LuxeEtat()
        l.societe = m
        p.boutique.luxe = l
        return s.rituels.randomElement()
    }

    static func resoudreRituel<P: ShopActor>(_ r: LuxeRituel, choix: Int, _ p: inout P) -> String {
        guard r.choices.indices.contains(choix) else { return "" }
        var rng = SystemRandomNumberGenerator()
        guard let o = ShopEngine.pick(r.choices[choix].outcomes, using: &rng) else { return "" }
        var texte = ShopEngine.fill(o.text, person: p, amount: o.effects?.money.map(abs))
        if let e = o.effects { ShopEngine.apply(e, itemId: nil, &p) }
        // Bien se tenir en réunion fait monter plus vite : chaque réunion compte double pour l'ancienneté.
        if var l = p.boutique.luxe, var m = l.societe {
            m.anneesAuRang += 1
            l.societe = m
            p.boutique.luxe = l
        }
        if texte.isEmpty { texte = "La réunion s'est terminée à l'aube, comme toujours." }
        return texte
    }

    static func prochainRang(_ p: some ShopActor) -> LuxeRang? {
        guard let s = societe(p), let m = p.boutique.luxe?.societe, s.rangs.indices.contains(m.rang + 1) else { return nil }
        return s.rangs[m.rang + 1]
    }

    static func verrouPromotion(_ p: some ShopActor) -> String? {
        guard societe(p) != nil, let m = p.boutique.luxe?.societe else { return "Tu n'es membre de rien." }
        guard let r = prochainRang(p) else { return "Tu es déjà au sommet. Au-dessus, il n'y a que des rumeurs." }
        if m.anneesAuRang < r.anneesMin { return "Il faut encore de l'ancienneté : \(r.anneesMin - m.anneesAuRang) an(s) ou réunion(s) de plus." }
        if dejaFait("promo", p) { return "Le conseil ne se réunit qu'une fois par an pour les promotions." }
        return nil
    }

    static func demanderPromotion<P: ShopActor>(_ p: inout P) -> ShopResult {
        if let v = verrouPromotion(p) { return ShopResult(ok: false, message: v) }
        guard let s = societe(p), var m = p.boutique.luxe?.societe, let r = prochainRang(p) else { return ShopResult(ok: false, message: "") }
        let cout = prix(r.cout)
        guard ShopHooks.canAfford(cout, p.money) else {
            return ShopResult(ok: false, message: "La cérémonie du grade \(r.titre) coûte \(Format.argent(cout)). Le Grand Trésorier ne fait pas crédit.")
        }
        marquer("promo", &p)
        // Plus le grade est haut, plus le vote est serré.
        let chance = max(0.35, 0.8 - Double(m.rang) * 0.1)
        guard Double.random(in: 0..<1) < chance else {
            return ShopResult(ok: false, message: "Vote à boules noires et blanches. Une boule noire de trop. Personne ne te dira de qui.")
        }
        ShopEngine.pay(cout, &p)
        m.rang += 1
        m.anneesAuRang = 0
        var l = p.boutique.luxe ?? LuxeEtat()
        l.societe = m
        p.boutique.luxe = l
        ShopEngine.applyStats(happiness: 8, &p)
        return ShopResult(ok: true, message: "Promotion acceptée. Tu es désormais \(r.titre) de \(s.name). Le réseau t'ouvre des portes que tu ne soupçonnais pas.")
    }

    static func quitter<P: ShopActor>(_ p: inout P) -> String {
        guard let s = societe(p), let m = p.boutique.luxe?.societe else { return "" }
        var l = p.boutique.luxe ?? LuxeEtat()
        l.societe = nil
        if !l.bannies.contains(s.id) { l.bannies.append(s.id) }
        p.boutique.luxe = l
        let tirage = Int.random(in: 0..<100)
        if m.rang >= 2 && tirage < 30 {
            ShopEngine.applyStats(happiness: -12, health: -4, &p)
            return "Tu as rendu ton insigne. Depuis, une voiture noire stationne parfois devant chez toi. Tu dors mal."
        } else if tirage < 50 {
            ShopEngine.applyStats(happiness: -5, &p)
            p.mondanite -= 3
            return "Tu as quitté \(s.name). Certaines invitations ont cessé d'arriver, comme par hasard."
        }
        ShopEngine.applyStats(happiness: 2, &p)
        return "Tu as quitté \(s.name) poliment. Ils ont pris acte, sans un mot. Tu te sens plus léger."
    }

    static func trahir<P: ShopActor>(_ p: inout P) -> String {
        guard let s = societe(p), let m = p.boutique.luxe?.societe else { return "" }
        var l = p.boutique.luxe ?? LuxeEtat()
        l.societe = nil
        if !l.bannies.contains(s.id) { l.bannies.append(s.id) }
        p.boutique.luxe = l
        let cachet = 20_000 * (m.rang + 1) * (m.rang + 1)
        ShopEngine.earn(cachet, &p)
        ShopEngine.applyStats(karma: -10, &p)
        p.mondanite += 10
        if Int.random(in: 0..<100) < 15 + m.rang * 10 {
            ShopEngine.applyStats(happiness: -15, health: -25, &p)
            return "Le journal t'a payé \(Format.argent(cachet)) pour les secrets de \(s.name). Trois semaines plus tard, tes freins ont lâché dans une descente. Les enquêteurs parlent d'un accident."
        }
        ShopEngine.applyStats(happiness: -6, &p)
        return "Le journal t'a payé \(Format.argent(cachet)) pour les secrets de \(s.name). Le scandale fait la une. Tu changes d'itinéraire pour rentrer chez toi, au cas où."
    }

    // MARK: Passage d'année

    static func passageAnnee<P: ShopActor>(_ p: inout P) -> [String] {
        guard var l = p.boutique.luxe else { return [] }
        var lignes: [String] = []
        // La célébrité retombe si on ne l'entretient pas.
        if l.mondanite > 0 {
            l.mondanite = max(0, l.mondanite - (l.mondanite > 50 ? 3 : 1))
        }
        p.boutique.luxe = l

        if let s = societe(p), var m = p.boutique.luxe?.societe {
            m.annees += 1
            m.anneesAuRang += 1
            let cotisation = prix(s.cotisation)
            if ShopHooks.canAfford(cotisation, p.money) {
                ShopEngine.pay(cotisation, &p)
                lignes.append("Cotisation annuelle à \(s.name) : \(Format.argent(cotisation)).")
                let rang = s.rangs[min(m.rang, s.rangs.count - 1)]
                if rang.reseau > 0, Int.random(in: 0..<100) < 50 {
                    let gain = Int(Double(rang.reseau) * Double.random(in: 0.5...1.5))
                    ShopEngine.earn(gain, &p)
                    lignes.append("Un frère de \(s.name) t'a glissé une affaire à l'oreille : \(Format.argent(gain)) de gagnés.")
                }
                if Int.random(in: 0..<100) < 3 {
                    ShopEngine.applyStats(happiness: -6, &p)
                    p.mondanite += 4
                    lignes.append("Un site d'enquête a publié une liste de membres de \(s.name). Ton nom y figure.")
                }
                var l2 = p.boutique.luxe ?? LuxeEtat()
                l2.societe = m
                p.boutique.luxe = l2
            } else {
                var l2 = p.boutique.luxe ?? LuxeEtat()
                l2.societe = nil
                l2.bannies.append(s.id)
                p.boutique.luxe = l2
                ShopEngine.applyStats(happiness: -8, &p)
                lignes.append("Tu n'as pas pu payer ta cotisation à \(s.name). Ton insigne a disparu de ton tiroir pendant la nuit. Tu es radié.")
            }
        }
        return lignes
    }
}

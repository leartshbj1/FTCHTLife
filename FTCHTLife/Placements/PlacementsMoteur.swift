import Foundation

/// Règles du module Placements. Fonctions pures sur PlacementsEtat + l'argent du joueur.
/// Le moteur du jeu appelle `passerAnnee` une fois par an, l'écran appelle les actions (acheter, vendre…).
enum PlacementsMoteur {

    // MARK: Réglages

    static let ageMinBourse = 18
    static let plafondLivret = 50_000
    static let fraisCourtage = 0.01
    static let fraisNotaire = 0.08
    static let fraisVenteImmo = 0.05
    static let tauxCredit = 0.035
    static let dureeCredit = 20
    static let apportMin = 0.20
    /// Part du salaire qu'on peut consacrer aux crédits.
    static let tauxEndettement = 0.35
    static let historiqueMax = 15
    static let chanceNouvelleCrypto = 0.35
    static let chanceTrouverLocataire = 0.7
    static let prixMaxCrypto = 1_000_000.0

    // MARK: Création

    /// Marché de départ d'une vie, avec quelques années de passé pour les courbes.
    static func nouveau() -> PlacementsEtat {
        var e = PlacementsEtat()
        e.tauxLivret = Double.random(in: 0.01...0.03)
        for a in PlacementsCatalogue.actifs {
            let lancee = a.type != .crypto || (a.depart ?? false)
            let prix = max(0.0001, a.prixInitial * Double.random(in: 0.75...1.3))
            e.cours[a.id] = PlacementCours(prix: prix, historique: lancee ? passeFictif(a, prix: prix) : [], lancee: lancee)
        }
        return e
    }

    /// Ajoute au marché les actifs ajoutés au jeu depuis la sauvegarde.
    static func completer(_ e: inout PlacementsEtat) {
        for a in PlacementsCatalogue.actifs where e.cours[a.id] == nil {
            let lancee = a.type != .crypto
            e.cours[a.id] = PlacementCours(prix: a.prixInitial, historique: lancee ? [a.prixInitial] : [], lancee: lancee)
        }
    }

    private static func passeFictif(_ a: PlacementActif, prix: Double) -> [Double] {
        let annees = a.type == .crypto ? 3 : 8
        var p = prix
        var h = [p]
        for _ in 0..<annees {
            p = max(0.0001, p / facteurNormal(a))
            h.insert(p, at: 0)
        }
        return h
    }

    // MARK: Hasard

    static func gauss() -> Double {
        let u1 = Double.random(in: Double.ulpOfOne...1)
        let u2 = Double.random(in: 0...1)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    static func tirage<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.randomElement() }
        var r = Double.random(in: 0..<total)
        for x in liste {
            r -= max(0, poids(x))
            if r < 0 { return x }
        }
        return liste.last
    }

    /// Mouvement « normal » d'une année : tendance + bruit (log-normal).
    static func facteurNormal(_ a: PlacementActif) -> Double {
        let v = a.volatilite
        let f = exp(a.rendement - v * v / 2 + v * gauss())
        return min(8, max(0.08, f))
    }

    // MARK: Outils

    /// Convertit en Int sans jamais planter, même avec des montants délirants (mode triche, crypto ×100…).
    static func entier(_ d: Double) -> Int {
        guard d.isFinite else { return d > 0 ? Int.max / 4 : 0 }
        return Int(min(Double(Int.max / 4), max(Double(Int.min / 4), d.rounded())))
    }

    static func ajouter(_ argent: inout Int, _ montant: Double) {
        argent = entier(Double(argent) + montant)
    }

    static func remplir(_ texte: String, _ a: PlacementActif) -> String {
        texte.replacingOccurrences(of: "{nom}", with: a.nom).replacingOccurrences(of: "{ticker}", with: a.ticker)
    }

    static func prix(_ e: PlacementsEtat, _ id: String) -> Double {
        guard let c = e.cours[id], !c.mort else { return 0 }
        return c.prix
    }

    static func position(_ e: PlacementsEtat, _ id: String) -> PlacementPosition? {
        e.positions.first { $0.actifId == id }
    }

    static func valeur(_ p: PlacementPosition, _ e: PlacementsEtat) -> Double {
        p.quantite * prix(e, p.actifId)
    }

    /// Valeur des titres détenus (tous types, ou un seul).
    static func valeurTitres(_ e: PlacementsEtat, type: PlacementType? = nil) -> Double {
        e.positions.reduce(0) { total, p in
            guard let a = PlacementsCatalogue.actif(p.actifId) else { return total }
            if let t = type, a.type != t { return total }
            return total + valeur(p, e)
        }
    }

    static func investiTitres(_ e: PlacementsEtat, type: PlacementType? = nil) -> Double {
        e.positions.reduce(0) { total, p in
            guard let a = PlacementsCatalogue.actif(p.actifId) else { return total }
            if let t = type, a.type != t { return total }
            return total + p.investi
        }
    }

    static func valeurImmobiliere(_ e: PlacementsEtat) -> Int { e.biens.reduce(0) { $0 + $1.valeur } }
    static func dettesImmobilieres(_ e: PlacementsEtat) -> Int { e.biens.reduce(0) { $0 + $1.credit } }
    static func annuites(_ e: PlacementsEtat) -> Int { e.biens.reduce(0) { $0 + ($1.credit > 0 ? $1.annuite : 0) } }

    /// Tout ce que le joueur possède en placements, dettes déduites (pour l'héritage, la nécrologie…).
    static func patrimoine(_ e: PlacementsEtat) -> Int {
        entier(Double(e.livret.solde) + valeurTitres(e) + Double(valeurImmobiliere(e) - dettesImmobilieres(e)))
    }

    /// Tags de joueur posés par le module, pour les conditions d'événements.
    static func tags(_ e: PlacementsEtat) -> Set<String> {
        var t: Set<String> = []
        if valeurTitres(e, type: .action) + valeurTitres(e, type: .fonds) + valeurTitres(e, type: .or) > 0 { t.insert("investisseur") }
        if e.positions.contains(where: { PlacementsCatalogue.actif($0.actifId)?.type == .crypto }) { t.insert("crypto") }
        if !e.biens.isEmpty { t.insert("proprietaire_bailleur") }
        if e.livret.solde >= 1000 { t.insert("epargnant") }
        if e.perteCrypto > 0 { t.insert("ruine_crypto") }
        return t
    }

    static func concerne(_ cible: String, _ a: PlacementActif) -> Bool {
        switch cible {
        case "tout": return true
        case "bourse": return a.type == .action || a.type == .fonds
        case "crypto": return a.type == .crypto
        case "or": return a.type == .or
        case "immobilier": return false
        default: return a.secteur?.rawValue == cible || a.id == cible
        }
    }

    // MARK: - Une année

    /// Fait passer une année : intérêts, cours, dividendes, cryptos, loyers, crédits, pépins.
    /// Modifie `argent` directement et renvoie les lignes de journal et les variations de stats.
    static func passerAnnee(_ e: inout PlacementsEtat, argent: inout Int, contexte ctx: PlacementsContexte) -> PlacementsBilan {
        completer(&e)
        var b = PlacementsBilan()
        let argentAvant = argent
        e.annees += 1
        var nouvelles: [String] = []

        // Livret
        e.tauxLivret = min(0.045, max(0.005, e.tauxLivret + Double.random(in: -0.004...0.004)))
        if e.livret.solde > 0 {
            let interets = entier(Double(e.livret.solde) * e.tauxLivret * ctx.mult("epargne"))
            e.livret.solde += interets
            e.livret.interetsCumules += interets
            if interets > 0 {
                b.lignes.append("🐷 Ton livret t'a rapporté \(Format.argent(interets)) d'intérêts. Ne dépense pas tout d'un coup.")
            }
        }

        // Nouvelles du marché
        var chocs: [(cible: String, facteur: Double, texte: String)] = []
        let nb = Int.random(in: 1...3)
        var pool = PlacementsCatalogue.nouvelles
        for _ in 0..<nb {
            guard let n = tirage(pool, poids: { $0.poids ?? 1 }) else { break }
            pool.removeAll { $0.id == n.id }
            let lo = min(n.variationMin, n.variationMax), hi = max(n.variationMin, n.variationMax)
            let v = lo == hi ? lo : Double.random(in: lo...hi)
            chocs.append((n.cible, max(0.05, 1 + v), n.texte))
            nouvelles.append("📰 " + n.texte)
        }

        // Cours
        let detenus = Set(e.positions.map { $0.actifId })
        let valeurAvant = valeurTitres(e) - valeurTitres(e, type: .crypto)
        var nouvellesDuJoueur = Set<String>()
        for a in PlacementsCatalogue.actifs {
            guard var c = e.cours[a.id], c.lancee, !c.mort else { continue }
            var f = facteurNormal(a)
            for choc in chocs where concerne(choc.cible, a) {
                f *= choc.facteur
                if detenus.contains(a.id) { nouvellesDuJoueur.insert(choc.texte) }
            }
            switch a.type {
            case .action, .fonds:
                f *= ctx.mult("bourse")
                if let s = a.secteur { f *= ctx.mult("bourse_" + s.rawValue) }
            case .or:
                f *= ctx.mult("or")
            case .crypto:
                f *= ctx.mult("crypto")
            }

            if a.type == .crypto {
                let r = Double.random(in: 0...1)
                let zero = ctx.triche ? 0 : (a.chanceZero ?? 0.1)
                let lune = a.chanceLune ?? 0.04
                if r < zero {
                    c.mort = true
                    c.prix = 0
                    let texte = remplir(a.texteZero ?? "{nom} ({ticker}) ne vaut plus rien. Le fondateur a supprimé son compte.", a)
                    nouvelles.append("💀 " + texte)
                    if let p = position(e, a.id) {
                        let perte = entier(p.investi)
                        e.perteCrypto += perte
                        b.lignes.append("💀 \(texte) Tu perds \(Format.argent(perte)).")
                        b.bonheur -= 10
                        e.positions.removeAll { $0.actifId == a.id }
                    }
                } else if r < zero + lune {
                    let mult = Double.random(in: 10...100)
                    c.prix = min(prixMaxCrypto, c.prix * mult)
                    let texte = remplir(a.texteLune ?? "{nom} ({ticker}) s'envole sans aucune raison.", a)
                    nouvelles.append("🚀 " + texte + " (×\(Int(mult)))")
                    if let p = position(e, a.id) {
                        b.lignes.append("🚀 \(texte) Tes parts valent maintenant \(Format.argent(entier(p.quantite * c.prix))).")
                        b.bonheur += 12
                    }
                } else {
                    c.prix = min(prixMaxCrypto, max(0.000001, c.prix * f))
                }
            } else {
                c.prix = max(0.01, c.prix * f)
                // Faillite : cours effondré, ou très rare accident pour une action
                if a.type == .action && (c.prix < a.prixInitial * 0.03 || Double.random(in: 0...1) < 0.002) {
                    c.mort = true
                    c.prix = 0
                    let texte = remplir(a.texteZero ?? "{nom} ({ticker}) fait faillite. Les locaux sont transformés en salle d'escalade.", a)
                    nouvelles.append("🪦 " + texte)
                    if let p = position(e, a.id) {
                        b.lignes.append("🪦 \(texte) Tes \(Format.argent(entier(p.investi))) investis partent avec.")
                        b.bonheur -= 6
                        e.positions.removeAll { $0.actifId == a.id }
                    }
                }
            }
            c.historique.append(c.prix)
            if c.historique.count > historiqueMax { c.historique.removeFirst(c.historique.count - historiqueMax) }
            e.cours[a.id] = c
        }

        // Nouvelle crypto
        if Double.random(in: 0...1) < chanceNouvelleCrypto {
            let candidates = PlacementsCatalogue.actifs.filter { $0.type == .crypto && e.cours[$0.id]?.lancee == false }
            if let a = candidates.randomElement() {
                e.cours[a.id] = PlacementCours(prix: a.prixInitial, historique: [a.prixInitial], lancee: true)
                nouvelles.append("✨ Nouvelle crypto : \(a.nom) (\(a.ticker)). \(a.description)")
            }
        }

        // Bilan bourse
        for t in nouvellesDuJoueur.prefix(2) { b.lignes.append("📰 " + t) }
        let valeurApres = valeurTitres(e) - valeurTitres(e, type: .crypto)
        if valeurAvant >= 1 {
            let pct = valeurApres / valeurAvant - 1
            let signe = pct >= 0 ? "+" : ""
            let emoji = pct >= 0 ? "📈" : "📉"
            b.lignes.append("\(emoji) Ton portefeuille en bourse : \(signe)\(Int((pct * 100).rounded())) % cette année (valeur \(Format.argent(entier(valeurApres)))).")
            if pct > 0.25 { b.bonheur += 4 } else if pct < -0.25 { b.bonheur -= 5 }
        }

        // Dividendes
        var dividendes = 0.0
        for p in e.positions {
            guard let a = PlacementsCatalogue.actif(p.actifId), let d = a.dividende, d > 0 else { continue }
            dividendes += valeur(p, e) * d
        }
        if dividendes >= 1 {
            ajouter(&argent, dividendes)
            e.dividendesCumules = entier(Double(e.dividendesCumules) + dividendes)
            b.lignes.append("💶 Tu touches \(Format.argent(entier(dividendes))) de dividendes sans lever le petit doigt.")
        }

        // Immobilier locatif
        if !e.biens.isEmpty {
            let lignesImmo = anneeImmobiliere(&e, argent: &argent, ctx: ctx, chocs: chocs.filter { $0.cible == "immobilier" || $0.cible == "tout" }.map { $0.facteur }, bilan: &b)
            b.lignes += lignesImmo
        }

        e.nouvelles = nouvelles
        b.argent = argent - argentAvant
        return b
    }

    private static func anneeImmobiliere(_ e: inout PlacementsEtat, argent: inout Int, ctx: PlacementsContexte, chocs: [Double], bilan b: inout PlacementsBilan) -> [String] {
        var lignes: [String] = []
        var netTotal = 0.0
        var facteurMarche = exp(0.02 + 0.06 * gauss()) * ctx.mult("immobilier_locatif")
        for c in chocs { facteurMarche *= c }

        for i in e.biens.indices {
            var bien = e.biens[i]
            bien.annees += 1
            bien.valeur = entier(Double(bien.valeur) * facteurMarche)
            bien.loyerAnnuel = entier(Double(bien.loyerAnnuel) * 1.015)
            var net = -Double(bien.charges)

            if let nom = bien.locataire {
                let modele = bien.locataireModeleId.flatMap { PlacementsCatalogue.locataire($0) }
                if Double.random(in: 0...1) < (modele?.fiabilite ?? 0.85) || ctx.triche {
                    net += Double(bien.loyerAnnuel)
                    bien.loyersEncaisses += bien.loyerAnnuel
                } else {
                    lignes.append("😤 \(nom) n'a pas payé le loyer de \(bien.designation). Paraît que « c'est en cours ».")
                    b.bonheur -= 2
                }
                if Double.random(in: 0...1) < (modele?.depart ?? 0.15) {
                    lignes.append("📦 \(nom) quitte \(bien.designation) en laissant un mot gentil et une odeur de friture.")
                    bien.locataire = nil
                    bien.locataireModeleId = nil
                }
            } else if Double.random(in: 0...1) < chanceTrouverLocataire, let loc = tirage(PlacementsCatalogue.locataires, poids: { $0.poids ?? 1 }) {
                let prenom = (Donnees.prenomsHommes + Donnees.prenomsFemmes).randomElement() ?? "Kevin"
                bien.locataire = prenom
                bien.locataireModeleId = loc.id
                lignes.append("🔑 Nouveau locataire dans \(bien.designation) : \(prenom), \(loc.description).")
                net += Double(bien.loyerAnnuel) / 2
                bien.loyersEncaisses += bien.loyerAnnuel / 2
            }

            // Pépin
            if !ctx.triche && Double.random(in: 0...1) < bien.risque {
                let possibles = PlacementsCatalogue.incidents.filter {
                    switch $0.condition {
                    case "loue": return bien.locataire != nil
                    case "vide": return bien.locataire == nil
                    default: return true
                    }
                }
                if let inc = tirage(possibles, poids: { $0.poids ?? 1 }) {
                    let lo = min(inc.coutMin, inc.coutMax), hi = max(inc.coutMin, inc.coutMax)
                    let cout = Int.random(in: lo...hi)
                    var texte = inc.texte
                        .replacingOccurrences(of: "{bien}", with: bien.designation)
                        .replacingOccurrences(of: "{locataire}", with: bien.locataire ?? "ton locataire")
                    if cout > 0 { texte += " (−\(Format.argent(cout)))" } else if cout < 0 { texte += " (+\(Format.argent(-cout)))" }
                    lignes.append("🏚️ " + texte)
                    net -= Double(cout)
                    b.bonheur += inc.bonheur ?? 0
                    b.karma += inc.karma ?? 0
                    if let v = inc.valeur { bien.valeur = entier(Double(bien.valeur) * v) }
                    if inc.locatairePart == true {
                        bien.locataire = nil
                        bien.locataireModeleId = nil
                    }
                }
            }

            // Crédit
            if bien.credit > 0 {
                let interets = Double(bien.credit) * tauxCredit
                let paiement = min(Double(bien.annuite), Double(bien.credit) + interets)
                bien.credit = max(0, entier(Double(bien.credit) + interets - paiement))
                net -= paiement
                if bien.credit == 0 {
                    lignes.append("🎉 Tu as fini de rembourser le crédit de \(bien.designation). Ton banquier t'envoie une carte de condoléances.")
                    b.bonheur += 5
                }
            }

            netTotal += net
            e.biens[i] = bien
        }
        ajouter(&argent, netTotal)
        let n = entier(netTotal)
        lignes.append("🏠 Bilan de tes locations : \(n >= 0 ? "+" : "−")\(Format.argent(abs(n))) net cette année.")
        return lignes
    }

    // MARK: - Actions du joueur
    // Chaque action renvoie un message pour le joueur. Si l'action est refusée, rien n'est modifié.

    static func deposer(_ montant: Int, _ e: inout PlacementsEtat, argent: inout Int) -> String {
        guard montant > 0 else { return "Déposer zéro euro. Audacieux." }
        guard argent >= montant else { return "Tu n'as pas \(Format.argent(montant)) sur ton compte. Ton banquier rit encore." }
        let place = plafondLivret - e.livret.solde
        guard place > 0 else { return "Ton livret est plein (plafond \(Format.argent(plafondLivret))). Même l'écureuil trouve que c'est assez." }
        let m = min(montant, place)
        argent -= m
        e.livret.solde += m
        let fin = m < montant ? " Le reste ne rentre pas : plafond atteint." : ""
        return "Tu ranges \(Format.argent(m)) sur ton livret.\(fin)"
    }

    static func retirer(_ montant: Int, _ e: inout PlacementsEtat, argent: inout Int) -> String {
        let m = min(montant, e.livret.solde)
        guard m > 0 else { return "Ton livret est vide. Il n'y a que de la poussière et un vieux ticket de métro." }
        e.livret.solde -= m
        argent += m
        return "Tu retires \(Format.argent(m)) de ton livret."
    }

    static func peutInvestir(_ ctx: PlacementsContexte) -> Bool { ctx.age >= ageMinBourse }

    static func acheter(_ actifId: String, montant: Int, _ e: inout PlacementsEtat, argent: inout Int, contexte ctx: PlacementsContexte) -> String {
        guard peutInvestir(ctx) else { return "Il faut avoir \(ageMinBourse) ans pour jouer en bourse. Ta tirelire en forme de cochon, elle, t'attend." }
        guard let a = PlacementsCatalogue.actif(actifId), let c = e.cours[actifId], c.lancee, !c.mort, c.prix > 0 else {
            return "Ce titre n'est plus disponible."
        }
        guard montant > 0 else { return "Acheter pour zéro euro, c'est regarder." }
        guard argent >= montant else { return "Tu n'as pas \(Format.argent(montant)). Le courtier te raccroche au nez." }
        let frais = max(1, Double(montant) * fraisCourtage)
        let net = Double(montant) - frais
        guard net > 0 else { return "Avec les frais, il ne reste rien à investir." }
        let q = net / c.prix
        argent -= montant
        if let i = e.positions.firstIndex(where: { $0.actifId == actifId }) {
            e.positions[i].quantite += q
            e.positions[i].investi += Double(montant)
        } else {
            e.positions.append(PlacementPosition(actifId: actifId, quantite: q, investi: Double(montant)))
        }
        let blague = a.type == .crypto ? " Ton cousin serait fier. Ton banquier, moins." : ""
        return "Tu achètes \(PlacementsFormat.quantite(q)) \(a.type == .crypto ? "jetons" : "parts") de \(a.nom) pour \(Format.argent(montant)) (dont \(Format.argent(entier(frais))) de frais).\(blague)"
    }

    /// Vend une fraction (0 à 1) d'une position.
    static func vendre(_ actifId: String, fraction: Double, _ e: inout PlacementsEtat, argent: inout Int) -> String {
        guard let i = e.positions.firstIndex(where: { $0.actifId == actifId }), let a = PlacementsCatalogue.actif(actifId) else {
            return "Tu ne possèdes pas ce titre."
        }
        let f = min(1, max(0, fraction))
        guard f > 0 else { return "Vendre zéro part, c'est très zen." }
        let p = e.positions[i]
        let q = p.quantite * f
        let brut = q * prix(e, actifId)
        let frais = brut > 0 ? max(1, brut * fraisCourtage) : 0
        let net = max(0, brut - frais)
        let investi = p.investi * f
        let gain = net - investi
        ajouter(&argent, net)
        if f >= 0.9999 {
            e.positions.remove(at: i)
        } else {
            e.positions[i].quantite -= q
            e.positions[i].investi -= investi
        }
        if a.type == .crypto && gain > Double(e.meilleurCoupCrypto) { e.meilleurCoupCrypto = entier(gain) }
        let g = entier(gain)
        let bilan: String
        if g > 0 { bilan = "Plus-value : +\(Format.argent(g)). Tu te sens comme un loup de la finance." }
        else if g < 0 { bilan = "Moins-value : −\(Format.argent(-g)). On appelle ça « apprendre »." }
        else { bilan = "Ni gagné ni perdu. Très suisse." }
        return "Tu vends pour \(Format.argent(entier(net))) de \(a.nom). \(bilan)"
    }

    /// Ce que coûte un bien à l'achat, comptant ou à crédit.
    static func coutAchat(_ m: PlacementBienModele, credit: Bool) -> (apport: Int, emprunt: Int, annuite: Int) {
        let notaire = entier(Double(m.prix) * fraisNotaire)
        guard credit else { return (m.prix + notaire, 0, 0) }
        let apport = entier(Double(m.prix) * apportMin) + notaire
        let emprunt = m.prix - entier(Double(m.prix) * apportMin)
        return (apport, emprunt, annuite(emprunt))
    }

    static func annuite(_ emprunt: Int) -> Int {
        let t = tauxCredit, n = Double(dureeCredit)
        return entier(Double(emprunt) * t / (1 - pow(1 + t, -n)))
    }

    static func acheterBien(_ modeleId: String, credit: Bool, _ e: inout PlacementsEtat, argent: inout Int, contexte ctx: PlacementsContexte) -> String {
        guard peutInvestir(ctx) else { return "Aucun notaire ne signe avec quelqu'un qui a encore un cartable." }
        guard let m = PlacementsCatalogue.bien(modeleId) else { return "Ce bien n'est plus à vendre." }
        let cout = coutAchat(m, credit: credit)
        guard argent >= cout.apport else {
            return credit
                ? "Il te faut \(Format.argent(cout.apport)) d'apport (20 % + frais de notaire). Ton banquier te conseille de « revenir avec des sous »."
                : "Il te faut \(Format.argent(cout.apport)) frais de notaire compris. Tu peux essayer le crédit."
        }
        if credit {
            let capacite = Double(ctx.salaireAnnuel) * tauxEndettement
            guard ctx.salaireAnnuel > 0 || ctx.triche else { return "Sans salaire, la banque refuse. Elle te propose à la place un stylo publicitaire." }
            guard Double(annuites(e) + cout.annuite) <= capacite || ctx.triche else {
                return "La banque refuse : les remboursements (\(Format.argent(cout.annuite))/an) dépasseraient 35 % de ton salaire. Elle t'offre quand même un calendrier."
            }
        }
        argent -= cout.apport
        let bien = PlacementBienPossede(
            modeleId: m.id, nom: m.nom, designation: m.designation ?? "ton bien « \(m.nom) »",
            valeur: m.prix, prixAchat: m.prix, loyerAnnuel: m.loyerAnnuel, charges: m.charges, risque: m.risque,
            locataire: nil, locataireModeleId: nil, credit: cout.emprunt, annuite: cout.annuite)
        e.biens.append(bien)
        if credit {
            return "Félicitations, tu es propriétaire de \(m.nom) ! Et endetté·e pour \(dureeCredit) ans : \(Format.argent(cout.annuite)) par an. Tu cherches un locataire."
        }
        return "Tu achètes \(m.nom) cash pour \(Format.argent(cout.apport)). Le notaire a souri, c'est rare. Tu cherches un locataire."
    }

    static func vendreBien(_ id: UUID, _ e: inout PlacementsEtat, argent: inout Int) -> String {
        guard let i = e.biens.firstIndex(where: { $0.id == id }) else { return "Ce bien n'est plus à toi." }
        let bien = e.biens[i]
        let produit = entier(Double(bien.valeur) * (1 - fraisVenteImmo)) - bien.credit
        argent += produit
        e.biens.remove(at: i)
        let pv = bien.valeur - bien.prixAchat
        let detail = pv >= 0 ? "Il a pris \(Format.argent(pv)) depuis l'achat." : "Il a perdu \(Format.argent(-pv)) depuis l'achat. Aïe."
        let creditTxt = bien.credit > 0 ? " Le crédit restant (\(Format.argent(bien.credit))) est remboursé au passage." : ""
        return "Tu vends \(bien.nom). Il te reste \(Format.argent(produit)) après frais.\(creditTxt) \(detail)"
    }

    static func augmenterLoyer(_ id: UUID, _ e: inout PlacementsEtat) -> (message: String, karma: Int) {
        guard let i = e.biens.firstIndex(where: { $0.id == id }) else { return ("Ce bien n'est plus à toi.", 0) }
        guard e.biens[i].anneeHausse != e.annees else { return ("Tu as déjà augmenté ce loyer cette année. Même toi, tu as des limites.", 0) }
        e.biens[i].anneeHausse = e.annees
        e.biens[i].loyerAnnuel = entier(Double(e.biens[i].loyerAnnuel) * 1.10)
        guard let nom = e.biens[i].locataire else {
            return ("Loyer augmenté de 10 %. Les prochains locataires paieront pour le papier peint.", 0)
        }
        if Double.random(in: 0...1) < 0.3 {
            e.biens[i].locataire = nil
            e.biens[i].locataireModeleId = nil
            return ("\(nom) refuse la hausse et déménage en emportant les ampoules.", -2)
        }
        return ("\(nom) accepte la hausse de 10 % en te regardant comme un méchant de dessin animé.", -2)
    }

    static func expulser(_ id: UUID, _ e: inout PlacementsEtat) -> (message: String, karma: Int) {
        guard let i = e.biens.firstIndex(where: { $0.id == id }), let nom = e.biens[i].locataire else {
            return ("Il n'y a personne à expulser. Juste un écho.", 0)
        }
        e.biens[i].locataire = nil
        e.biens[i].locataireModeleId = nil
        return ("\(nom) quitte les lieux. Le quartier entier te trouve sans cœur.", -4)
    }

    static func rembourserCredit(_ id: UUID, _ e: inout PlacementsEtat, argent: inout Int) -> String {
        guard let i = e.biens.firstIndex(where: { $0.id == id }), e.biens[i].credit > 0 else { return "Il n'y a plus de crédit sur ce bien." }
        let du = e.biens[i].credit
        guard argent >= du else { return "Il te faut \(Format.argent(du)) pour solder ce crédit." }
        argent -= du
        e.biens[i].credit = 0
        return "Crédit soldé : \(Format.argent(du)). Ton banquier essuie une larme."
    }
}

// MARK: - Affichage des montants à virgule

enum PlacementsFormat {
    /// Prix d'une part : centimes pour les petits prix, décimales pour les cryptos à 0,0003 €.
    static func prix(_ p: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.decimalSeparator = ","
        switch p {
        case 0: return "0 €"
        case ..<0.01:
            f.maximumSignificantDigits = 3
            f.usesSignificantDigits = true
        case ..<1000:
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
        default:
            f.maximumFractionDigits = 0
        }
        return (f.string(from: NSNumber(value: p)) ?? "\(p)") + " €"
    }

    static func quantite(_ q: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.decimalSeparator = ","
        f.maximumFractionDigits = q < 10 ? 3 : (q < 1000 ? 1 : 0)
        return f.string(from: NSNumber(value: q)) ?? "\(q)"
    }

    static func pourcentage(_ v: Double) -> String {
        let p = Int((v * 100).rounded())
        return (p > 0 ? "+" : "") + "\(p) %"
    }
}

import Foundation

/// Résultat d'une action politique : un texte à afficher, et parfois un dossier à trancher tout de suite
/// (débat télévisé, imprévu de campagne, vie de parti).
struct PolResultat {
    var texte: String
    var dossier: PolDossier? = nil
}

/// Toute la logique de la carrière politique. Fonctions pures sur `Joueur` et `PolEtat`.
/// Branchement : docs/POLITIQUE.md.
enum PolMoteur {

    static let ageMilitant = 16
    static let ageCandidat = 18
    static let agePresident = 35
    static let parrainagesRequis = 500

    // MARK: - Passage d'année

    /// À appeler une fois par an dans `GameEngine.vieillir()`. Renvoie les lignes du journal de l'année.
    static func passerAnnee(_ j: inout Joueur, _ e: inout PolEtat) -> [String] {
        var l: [String] = []
        e.titres = []
        guard j.vivant else { return l }

        // Lois en vigueur
        appliquerLoisAnnuelles(&j, &e, &l)

        // Parti
        if let parti = PolCatalogue.parti(e.partiId) {
            j.argent -= parti.cotisation
            e.loyaute += Int.random(in: -2...1)
        }

        if e.ineligibilite > 0 {
            e.ineligibilite -= 1
            if e.ineligibilite == 0 { l.append("⚖️ Ta peine d'inéligibilité est terminée. Les urnes te tendent à nouveau les bras.") }
        }

        // Dossiers non traités
        for d in e.dossiers {
            guard let dossier = PolCatalogue.dossier(d.dossierId) else { continue }
            if dossier.kind == "scandale" {
                e.popularite -= 8
                e.casseroles += 5
                l.append("📰 Tu n'as jamais répondu au scandale « \(dossier.title) ». Le silence a été très mal interprété.")
            } else {
                e.popularite -= 4
                l.append("📂 Le dossier « \(dossier.title) » a pris la poussière sur ton bureau. La presse l'a remarqué.")
            }
        }
        e.dossiers = []

        // Mandat en cours : indemnité, échéance, remaniement
        var mandatFini = false
        if var m = e.mandat {
            j.argent += Int(Double(m.poste.indemnite) * 0.8)
            if let r = m.anneesRestantes {
                m.anneesRestantes = r - 1
                mandatFini = r - 1 <= 0
            }
            e.mandat = m
            if m.poste == .ministre {
                remaniement(&j, &e, &l)
            }
        }

        // Élection
        if let c = e.candidature {
            resoudreElection(c, &j, &e, &l)
            e.candidature = nil
        }

        // Fin de mandat sans réélection
        if mandatFini, let m = e.mandat, (m.anneesRestantes ?? 1) <= 0 {
            terminerMandat(&j, &e, fin: "fin du mandat")
            l.append("🎗️ Ton mandat de \(m.poste.nom(j.genre).lowercased()) s'achève. Tu rends l'écharpe, le badge et la place de parking.")
        }

        // Nomination au gouvernement d'un député bien vu
        if e.mandat?.poste == .depute, empechementMinistere(j, e) == nil, e.candidature == nil,
           Double.random(in: 0...1) < 0.05 + Double(e.influence + e.loyaute) / 2000 {
            l.append(nommerMinistre(&j, &e, appel: true))
        }

        // Dérive des jauges
        let enPoste = e.mandat != nil
        if e.popularite > 30 { e.popularite -= Int.random(in: 1...4) } else { e.popularite += Int.random(in: 0...2) }
        if enPoste { e.popularite -= 1 }
        e.popularite += Int(regleSomme("popularite", e).rounded())
        if !enPoste && e.partiId == nil { e.influence -= 2 } else if enPoste { e.influence += 1 }
        e.casseroles -= Int.random(in: 2...5)
        if j.stats.karma < 25 { e.casseroles += 2 }
        if let emp = j.emploi, metiersPolitiques.contains(emp.metierId) { e.influence += 2 }
        e.borner()

        // Justice
        justice(&j, &e, &l)

        // Scandales
        if e.partiId != nil || enPoste {
            var chance = Double(e.casseroles) / 250
            if j.stats.karma < 30 { chance += 0.08 }
            if enPoste { chance += 0.05 }
            if Double.random(in: 0...1) < chance, let s = tirerDossier(kind: "scandale", poste: posteCourant(e), j, e) {
                e.dossiers.append(PolDossierEnAttente(dossierId: s.id, ageArrivee: j.age))
                l.append("📰 Scandale : « \(s.title) ». Ton téléphone n'arrête plus de sonner (onglet Politique).")
            }
        }

        // Dossiers de l'année
        if let m = e.mandat {
            let nombre = m.poste == .president ? Int.random(in: 2...3) : Int.random(in: 1...2)
            var arrives = 0
            for _ in 0..<nombre where e.dossiers.count < 4 {
                if let d = tirerDossier(kind: "dossier", poste: m.poste.rawValue, j, e),
                   !e.dossiers.contains(where: { $0.dossierId == d.id }) {
                    e.dossiers.append(PolDossierEnAttente(dossierId: d.id, ageArrivee: j.age))
                    arrives += 1
                }
            }
            if arrives > 0 {
                l.append("📂 \(arrives == 1 ? "Un nouveau dossier t'attend" : "\(arrives) nouveaux dossiers t'attendent") sur ton bureau (onglet Politique).")
            }
        } else if e.partiId != nil, j.age >= ageMilitant, Double.random(in: 0...1) < 0.4, e.dossiers.count < 4,
                  let d = tirerDossier(kind: "militant", poste: "militant", j, e) {
            e.dossiers.append(PolDossierEnAttente(dossierId: d.id, ageArrivee: j.age))
            l.append("📂 Ta section de \(nomParti(e)) a besoin de toi (onglet Politique).")
        }

        // Sondage
        if enPoste || e.rangMax >= 2 {
            let s = Stats.borne(e.popularite + Int.random(in: -6...6))
            e.dernierSondage = s
            l.append("📊 Sondage \(instituts.randomElement()!) : \(s) % d'opinions favorables (marge d'erreur : \(margesErreur.randomElement()!)).")
        }

        e.borner()
        j.stats.borner()
        return l
    }

    /// Métiers (fil métiers, secteur politique) qui donnent de l'influence chaque année.
    static let metiersPolitiques: Set<String> = [
        "attache_parlementaire", "collaborateur_elu", "chef_cabinet", "lobbyiste", "conseiller_com_politique",
        "militant_permanent", "porte_parole_parti", "plume_discours", "sondeur", "directeur_campagne",
    ]

    static let instituts = [
        "Opinion-Peut-Être", "IFOP-ou-Presque", "Sondo-Matic", "BVA-Savoir", "Harris-Tweed",
        "Institut du Doigt Mouillé", "Kantar-Pas-Tout", "Ipsé-Dixit", "OpinionWay-de-Côté", "Elabe-Bof",
    ]
    static let margesErreur = ["± 3 points", "± 3 points", "± 5 points", "± 40 points", "« ça dépend »", "on a demandé à 12 personnes"]

    private static func appliquerLoisAnnuelles(_ j: inout Joueur, _ e: inout PolEtat, _ l: inout [String]) {
        let avant = j.argent
        var bonheur = 0
        for id in e.loisActives {
            guard let loi = PolCatalogue.loi(id), let a = loi.annuel else { continue }
            let b = j.stats.bonheur
            appliquerSimple(a, &j)
            bonheur += j.stats.bonheur - b
        }
        let impots = regleSomme("impots", e)
        if impots > 0, let emp = j.emploi {
            j.argent -= Int(Double(emp.salaire) * 0.75 * impots)
        }
        let delta = j.argent - avant
        if abs(delta) >= 100 {
            l.append(delta < 0
                     ? "📜 Les lois en vigueur t'ont coûté \(Format.argent(-delta)) cette année."
                     : "📜 Les lois en vigueur t'ont rapporté \(Format.argent(delta)) cette année.")
        } else if bonheur >= 3 {
            l.append("📜 Les lois en vigueur te rendent la vie un peu plus douce.")
        }
    }

    private static func remaniement(_ j: inout Joueur, _ e: inout PolEtat, _ l: inout [String]) {
        var risque = 0.08 + Double(e.casseroles) / 300
        if e.popularite < 30 { risque += 0.15 }
        if e.loyaute < 30 { risque += 0.15 }
        if Double.random(in: 0...1) < risque {
            let ancien = nomMinistere(e)
            terminerMandat(&j, &e, fin: "remaniement")
            j.stats.bonheur -= 10
            l.append("🔄 Remaniement ! Tu quittes le \(ancien) par un SMS de trois mots. Ton bureau a déjà été vidé.")
        } else if Double.random(in: 0...1) < 0.06, var m = e.mandat,
                  let nouveau = PolCatalogue.ministeres.filter({ $0.id != m.ministereId }).randomElement() {
            m.ministereId = nouveau.id
            e.mandat = m
            l.append("🔄 Remaniement : tu passes au \(nouveau.nom). Personne ne t'a demandé ton avis.")
        }
    }

    private static func justice(_ j: inout Joueur, _ e: inout PolEtat, _ l: inout [String]) {
        guard e.casseroles >= 85, Double.random(in: 0...1) < 0.3 else { return }
        if e.casseroles >= 95 && Double.random(in: 0...1) < 0.5 {
            let amende = min(max(0, j.argent), 75_000)
            j.argent -= amende
            e.ineligibilite = 5
            e.casseroles = 40
            e.popularite -= 20
            j.stats.bonheur -= 20
            j.stats.karma -= 5
            if e.mandat != nil { terminerMandat(&j, &e, fin: "condamnation") }
            e.candidature = nil
            l.append("⚖️ Tu es " + j.g("condamné", "condamnée") + " : \(Format.argent(amende)) d'amende et 5 ans d'inéligibilité. Ton avocat parle d'« acharnement ».")
            e.titres.append(remplir("{prenom} {nom} condamné{e} : « Je suis la victime de tout ça »", j, e))
        } else {
            e.popularite -= 12
            j.stats.bonheur -= 8
            l.append("⚖️ Tu es " + j.g("mis", "mise") + " en examen. Tu déclares avoir « toute confiance en la justice de ton pays ».")
            e.titres.append(remplir("{prenom} {nom} mis{e} en examen", j, e))
        }
    }

    // MARK: - Élections

    /// Raison pour laquelle le joueur ne peut pas se présenter (nil = il peut).
    static func empechementCandidature(_ p: PolPoste, _ j: Joueur, _ e: PolEtat) -> String? {
        guard p.estElu else { return "Ce poste ne s'obtient pas par élection." }
        guard j.vivant else { return "Tu es " + j.g("mort", "morte") + "." }
        if e.candidature != nil { return "Tu es déjà en campagne." }
        if e.ineligibilite > 0 { return "Tu es " + j.g("inéligible", "inéligible") + " encore \(e.ineligibilite) an\(e.ineligibilite > 1 ? "s" : "")." }
        let ageMin = p == .president ? agePresident : ageCandidat
        if j.age < ageMin { return "Il faut avoir \(ageMin) ans." }
        if let m = e.mandat {
            if m.poste == .adjoint && p == .conseiller {
                if (m.anneesRestantes ?? 0) > 1 { return "Ton mandat dure encore \(m.anneesRestantes ?? 0) ans." }
            } else if m.poste == p {
                if (m.anneesRestantes ?? 0) > 1 { return "Ton mandat dure encore \(m.anneesRestantes ?? 0) ans." }
            } else if m.poste.rang >= p.rang {
                return "Tu occupes déjà un poste plus important."
            }
        }
        switch p {
        case .conseiller:
            break
        case .maire:
            if !(e.aOccupe(.conseiller) || e.aOccupe(.adjoint)) && e.influence < 40 {
                return "Il faut avoir été conseiller municipal, ou 40 d'influence."
            }
        case .depute:
            if !(e.aOccupe(.maire) || e.aOccupe(.adjoint)) && e.influence < 55 {
                return "Il faut avoir été maire ou adjoint, ou 55 d'influence."
            }
        case .president:
            if !(e.aOccupe(.depute) || e.aOccupe(.ministre)) { return "Il faut avoir été député ou ministre." }
            if e.influence < 60 { return "Il faut 60 d'influence." }
            if e.parrainages < parrainagesRequis { return "Il faut \(parrainagesRequis) parrainages (tu en as \(e.parrainages))." }
            if e.mandatsPresident >= 2 && regleSomme("mandatsIllimites", e) < 1 { return "Deux mandats maximum. La Constitution est formelle (pour l'instant)." }
        case .adjoint, .ministre:
            break
        }
        if j.argent + e.caisse < p.caution { return "La caution coûte \(Format.argent(p.caution))." }
        return nil
    }

    /// Se déclarer candidat. L'élection a lieu au prochain passage d'année.
    static func seDeclarer(_ p: PolPoste, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        if let raison = empechementCandidature(p, j, e) { return PolResultat(texte: raison) }
        payer(p.caution, &j, &e)
        let g = Genre.allCases.randomElement()!
        let adv = "\(Donnees.prenom(g)) \(Donnees.noms.randomElement()!)"
        let partiAdv = PolCatalogue.partis.filter { $0.id != e.partiId }.randomElement()
        let reelection = e.mandat?.poste == p
        e.candidature = PolCandidature(poste: p, adversaire: adv, adversairePartiId: partiAdv?.id, reelection: reelection)
        e.parrainages = p == .president ? e.parrainages - parrainagesRequis : e.parrainages
        e.titres.append(remplir("{prenom} {nom} candidat{e} : « J'y ai beaucoup réfléchi en me rasant »", j, e))
        let advTexte = adv + (partiAdv.map { " (\($0.sigle))" } ?? "")
        var t = reelection
            ? "Tu te représentes. Ton bilan ? « Globalement positif », d'après toi."
            : "Tu es " + j.g("candidat", "candidate") + " au poste de \(p.nom(j.genre).lowercased()) !"
        t += " Ton adversaire principal : \(advTexte). L'élection aura lieu à la fin de l'année."
        if p.caution > 0 { t += " Caution versée : \(Format.argent(p.caution))." }
        return PolResultat(texte: t)
    }

    static func scoreElection(_ c: PolCandidature, _ j: Joueur, _ e: PolEtat, depense: Int) -> Double {
        let p = c.poste
        var s = 15 + p.facilite
        s += Double(e.popularite) * 0.42
        s += Double(e.influence) * 0.22
        s += min(14, Double(depense) / Double(max(1, p.budgetReference)) * 12)
        if let parti = PolCatalogue.parti(e.partiId) {
            s += parti.bonusElection
        } else {
            s -= p == .conseiller ? 1 : 4
        }
        s += Double(j.stats.apparence - 50) * 0.08
        s += Double(j.stats.intelligence - 50) * 0.05
        s += Double(j.stats.karma - 50) * 0.03
        s += max(-15, min(20, c.points))
        s -= Double(e.casseroles) * 0.25
        if c.reelection { s += 6 }
        s += regleSomme("elections", e)
        return s
    }

    private static func pourcentage(_ x: Double) -> String {
        String(format: "%.1f", x).replacingOccurrences(of: ".", with: ",") + " %"
    }

    private static func resoudreElection(_ c: PolCandidature, _ j: inout Joueur, _ e: inout PolEtat, _ l: inout [String]) {
        let p = c.poste
        let depense = min(e.caisse, Int(Double(p.budgetReference) * 1.5)) + c.depenses
        e.caisse -= min(e.caisse, Int(Double(p.budgetReference) * 1.5))
        let score = scoreElection(c, j, e, depense: depense) + Double.random(in: -12...12)
        e.elections += 1
        let nomPoste = p.nom(j.genre).lowercased()

        var gagne = score >= 50
        var detail: String
        if p == .president {
            let tour1 = max(2.1, min(46, score * 0.55 + Double.random(in: -3...3)))
            if score < 42 {
                gagne = false
                detail = "Premier tour : \(pourcentage(tour1)). Éliminé" + j.g("", "e") + " dès le premier tour."
            } else {
                let tour2 = max(50.1, min(78, 50 + (score - 50) * 0.7))
                let perdu = max(22, min(49.9, 50 + (score - 50) * 0.7))
                detail = "Premier tour : \(pourcentage(tour1)). Second tour : \(pourcentage(gagne ? tour2 : perdu))."
            }
        } else {
            let pct = gagne ? max(50.1, min(97, 50 + (score - 50) * 0.7)) : max(0.4, min(49.9, 50 + (score - 50) * 0.7))
            detail = "Résultat : \(pourcentage(pct))."
        }

        if gagne {
            e.electionsGagnees += 1
            e.popularite += 5
            e.influence += 6 + p.rang * 2
            j.stats.bonheur += 15
            if p == .president { e.mandatsPresident += 1 }
            if c.reelection, var m = e.mandat {
                m.anneesRestantes = p.duree
                m.numero += 1
                e.mandat = m
                e.dernierResultat = "Réélu" + j.g("", "e") + " \(nomPoste) ! \(detail)"
                l.append("🗳️ Tu es " + j.g("réélu", "réélue") + " \(nomPoste) ! \(detail) Ton adversaire, \(c.adversaire), réclame un recomptage.")
            } else {
                if e.mandat != nil { terminerMandat(&j, &e, fin: "élu" + j.g("", "e") + " \(nomPoste)") }
                e.mandat = PolMandat(poste: p, anneesRestantes: p.duree, ageDebut: j.age)
                e.loisTentees = []
                e.dernierResultat = "Élu" + j.g("", "e") + " \(nomPoste) ! \(detail)"
                l.append("🗳️ Tu es " + j.g("élu", "élue") + " \(nomPoste) ! \(detail) " + victoires.randomElement()!)
            }
            e.titres.append(remplir("{prenom} {nom} " + j.g("élu", "élue") + " \(nomPoste)", j, e))
            if p == .maire { e.titres[e.titres.count - 1] += " de \(j.ville)" }
        } else {
            e.popularite -= 5
            j.stats.bonheur -= 12
            e.dernierResultat = "Battu" + j.g("", "e") + " (\(nomPoste)). \(detail)"
            l.append("🗳️ Tu as perdu l'élection. \(detail) " + defaites.randomElement()!)
            if c.reelection, e.mandat?.poste == p {
                terminerMandat(&j, &e, fin: "battu" + j.g("", "e") + " aux élections")
            }
        }
    }

    static let victoires = [
        "Tu fais ton discours de victoire debout sur une chaise. Elle cède.",
        "Ta soirée électorale finit au karaoké. Tu chantes faux, mais en élu.",
        "Tes militants scandent ton nom. Ils l'écorchent un peu.",
        "Tu remercies ta famille, tes militants et, par erreur, ton adversaire.",
    ]
    static let defaites = [
        "Tu reconnais ta défaite avec dignité, puis tu cries dans un oreiller.",
        "Tu accuses la météo, la date et l'alignement des planètes.",
        "Ton équipe de campagne a déjà mis ton numéro en bloqué.",
        "Tu annonces « prendre du recul ». Tu restes trois jours au lit.",
    ]

    // MARK: - Nominations

    static func empechementMinistere(_ j: Joueur, _ e: PolEtat) -> String? {
        if e.partiId == nil { return "Il faut un parti pour entrer au gouvernement." }
        if e.ineligibilite > 0 { return "Personne ne veut d'un ministre condamné. Enfin, presque personne." }
        if let m = e.mandat, m.poste.rang >= PolPoste.ministre.rang { return "Tu es déjà au-dessus de ça." }
        if !(e.aOccupe(.depute)) && e.influence < 75 { return "Il faut être ou avoir été député, ou 75 d'influence." }
        return nil
    }

    /// Faire acte de candidature auprès du chef de l'État (une fois par an).
    static func demanderMinistere(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        if let r = empechementMinistere(j, e) { return PolResultat(texte: r) }
        guard marquer("ministere", &j) else { return dejaFait }
        let chance = max(0.03, (Double(e.loyaute) * 0.35 + Double(e.influence) * 0.35 + Double(e.popularite) * 0.2 - Double(e.casseroles) * 0.3) / 100)
        if Double.random(in: 0...1) < chance {
            return PolResultat(texte: nommerMinistre(&j, &e, appel: false))
        }
        e.loyaute -= 2
        return PolResultat(texte: [
            "Tu as envoyé ton CV au chef de l'État. On t'a répondu avec un emoji pouce.",
            "Tu as attendu trois heures devant le Palais. Le portier t'a offert un café, par pitié.",
            "On t'a promis « un poste quand l'occasion se présentera ». C'est-à-dire jamais.",
        ].randomElement()!)
    }

    private static func nommerMinistre(_ j: inout Joueur, _ e: inout PolEtat, appel: Bool) -> String {
        let choisi = PolCatalogue.ministeres.randomElement()
        if e.mandat != nil { terminerMandat(&j, &e, fin: "entré" + j.g("", "e") + " au gouvernement") }
        e.mandat = PolMandat(poste: .ministre, anneesRestantes: nil, ministereId: choisi?.id, ageDebut: j.age)
        e.loisTentees = []
        e.influence += 10
        e.popularite += 4
        j.stats.bonheur += 15
        let nom = choisi?.nom ?? "Ministère des Choses Diverses"
        e.titres.append(remplir("{prenom} {nom} nommé{e} au \(nom)", j, e))
        return (appel ? "📞 Le chef de l'État t'appelle un dimanche à 7 h. " : "") +
            "🏛️ Tu es " + j.g("nommé", "nommée") + " ministre : \(nom) ! Tu as une voiture avec chauffeur. Tu ne sais pas où est le bouton de la radio."
    }

    /// Demander une délégation d'adjoint au maire (quand on est conseiller, une fois par an).
    static func briguerAdjoint(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let m = e.mandat, m.poste == .conseiller else { return PolResultat(texte: "Il faut être conseiller municipal.") }
        guard marquer("adjoint", &j) else { return dejaFait }
        let chance = Double(e.loyaute + e.influence) / 250 + 0.1
        if Double.random(in: 0...1) < chance {
            let restantes = m.anneesRestantes
            terminerMandat(&j, &e, fin: "devenu" + j.g("", "e") + " adjoint" + j.g("", "e"))
            e.mandat = PolMandat(poste: .adjoint, anneesRestantes: restantes, ageDebut: j.age)
            e.loisTentees = []
            e.influence += 5
            let delegation = delegations.randomElement()!
            return PolResultat(texte: "Le maire te nomme " + j.g("adjoint", "adjointe") + " \(delegation). C'est un début.")
        }
        e.loyaute -= 3
        return PolResultat(texte: "Le maire t'a écouté" + j.g("", "e") + " avec attention, puis a donné le poste à son beau-frère.")
    }

    static let delegations = [
        "aux fêtes et aux ronds-points", "aux poubelles et à l'espoir",
        "aux affaires de pigeons", "au stationnement et aux cris de rage", "à la culture (et au loto du dimanche)",
        "aux sports de canapé", "aux réverbères qui clignotent",
    ]

    // MARK: - Actions de parti

    static func adherer(_ partiId: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let p = PolCatalogue.parti(partiId) else { return PolResultat(texte: "Ce parti n'existe plus. Il s'est dissous pendant une réunion.") }
        guard j.age >= ageMilitant else { return PolResultat(texte: "Il faut avoir \(ageMilitant) ans pour prendre sa carte.") }
        guard e.partiId == nil else { return PolResultat(texte: "Tu as déjà une carte. Les gens qui en ont deux finissent ministres ou en procès.") }
        e.partiId = p.id
        e.loyaute = 50
        e.influence += p.influence ?? 3
        j.argent -= p.cotisation
        return PolResultat(texte: "Tu prends ta carte au \(p.nom) (\(p.sigle)). « \(p.slogan) » On t'a donné un badge et une pile de tracts.")
    }

    static func quitterParti(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let p = PolCatalogue.parti(e.partiId) else { return PolResultat(texte: "Tu n'as pas de parti.") }
        e.partiId = nil
        e.influence -= 8
        e.popularite += Int.random(in: -4...4)
        e.titres.append(remplir("{prenom} {nom} claque la porte du \(p.sigle)", j, e))
        return PolResultat(texte: "Tu quittes le \(p.nom) avec une lettre ouverte de onze pages. Personne ne l'a lue jusqu'au bout.")
    }

    static func militer(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.partiId != nil else { return PolResultat(texte: "Il te faut un parti pour militer.") }
        guard marquer("militer", &j) else { return dejaFait }
        e.influence += Int.random(in: 2...5)
        e.loyaute += 3
        e.popularite += Int.random(in: 0...2)
        j.stats.sante -= Int.random(in: 0...1)
        let texte = [
            "Tu as tracté au marché sous la pluie. Une dame a pris ton tract pour emballer ses poireaux.",
            "Tu as collé 300 affiches. Tu as collé aussi ta manche, ta main et un chat errant.",
            "Tu as passé la soirée à la permanence du parti. Il restait des chips de la dernière élection.",
            "Tu as fait du phoning. Sur 80 appels, 79 répondeurs et un monsieur qui voulait parler de son chien.",
        ].randomElement()!
        if e.mandat == nil, Double.random(in: 0...1) < 0.3, let d = tirerDossier(kind: "militant", poste: "militant", j, e) {
            return PolResultat(texte: texte, dossier: d)
        }
        return PolResultat(texte: texte)
    }

    static func flatter(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.partiId != nil else { return PolResultat(texte: "Il n'y a personne à flatter : tu n'as pas de parti.") }
        guard marquer("flatter", &j) else { return dejaFait }
        e.loyaute += 5
        e.influence += Int.random(in: 1...4)
        j.stats.karma -= 1
        return PolResultat(texte: [
            "Tu as ri très fort à la blague du président de fédération. Elle n'était pas drôle.",
            "Tu as offert une bouteille au chef du parti. Il t'appelle maintenant « mon petit », ce qui est un progrès.",
            "Tu as liké toutes les photos de vacances du secrétaire général, depuis 2011.",
        ].randomElement()!)
    }

    static func leverFonds(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard j.age >= ageCandidat else { return PolResultat(texte: "Personne ne fait de chèque à un mineur, même pour la démocratie.") }
        guard marquer("fonds", &j) else { return dejaFait }
        let rang = max(0, e.rangMax)
        let base = Double(e.influence * 150 + e.popularite * 80 + 500)
        let montant = Int(base * pow(2.6, Double(rang)) * Double.random(in: 0.6...1.4))
        e.caisse += montant
        if Double.random(in: 0...1) < 0.25 {
            e.casseroles += Int.random(in: 4...10)
            return PolResultat(texte: "Ton dîner de levée de fonds rapporte \(Format.argent(montant)). Un des donateurs a payé en lingots, ce qui pose question.")
        }
        return PolResultat(texte: "Ton dîner à \(Format.argent(rang >= 3 ? 1000 : 50)) le couvert rapporte \(Format.argent(montant)) à ta caisse de campagne. Le saumon était tiède.")
    }

    static func verserCaisse(_ montant: Int, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard montant > 0, j.argent >= montant else { return PolResultat(texte: "Tu n'as pas assez d'argent.") }
        j.argent -= montant
        e.caisse += montant
        return PolResultat(texte: "Tu verses \(Format.argent(montant)) de ta poche dans ta caisse de campagne. La démocratie te remercie.")
    }

    static func recolterParrainages(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.aOccupe(.depute) || e.aOccupe(.ministre) else { return PolResultat(texte: "Les maires ne parrainent que des gens qu'ils connaissent. Personne ne te connaît.") }
        guard marquer("parrainages", &j) else { return dejaFait }
        let n = e.influence * 3 + Int.random(in: 30...160) + (e.partiId == nil ? -40 : 30)
        e.parrainages += max(10, n)
        return PolResultat(texte: "Tu as fait le tour des mairies rurales. +\(max(10, n)) parrainages, et 4 kilos de tarte aux pommes. Total : \(e.parrainages)/\(parrainagesRequis).")
    }

    // MARK: - Campagne

    enum ActionCampagne: String, CaseIterable, Identifiable {
        case meeting, porteAPorte, affiches, promesse, coupBas
        var id: String { rawValue }
        var titre: String {
            switch self {
            case .meeting: return "Faire un meeting"
            case .porteAPorte: return "Faire du porte-à-porte"
            case .affiches: return "Payer une campagne d'affichage"
            case .promesse: return "Promettre n'importe quoi"
            case .coupBas: return "Lancer un coup bas"
            }
        }
        var icone: String {
            switch self {
            case .meeting: return "megaphone.fill"
            case .porteAPorte: return "door.left.hand.closed"
            case .affiches: return "photo.on.rectangle.angled"
            case .promesse: return "hand.raised.fill"
            case .coupBas: return "theatermasks.fill"
            }
        }
    }

    static func campagne(_ a: ActionCampagne, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard var c = e.candidature else { return PolResultat(texte: "Tu n'es pas en campagne.") }
        guard marquer("cam_" + a.rawValue, &j) else { return dejaFait }
        var t: String
        switch a {
        case .meeting:
            if Double.random(in: 0...1) < 0.2 {
                c.points -= 4
                e.popularite -= 3
                t = "Ton meeting tourne mal : le micro diffuse ta conversation privée sur ton adversaire. Tout le monde a entendu « ce gros nul »."
            } else {
                let g = Double.random(in: 2...6)
                c.points += g
                e.popularite += 2
                t = "Meeting réussi ! \(Int.random(in: 80...2400)) personnes, dont la moitié venues pour le buffet."
            }
        case .porteAPorte:
            c.points += Double.random(in: 1...4)
            j.stats.karma += 1
            j.stats.sante -= 1
            t = "Porte-à-porte : 6 étages sans ascenseur, 3 chiens, et une mamie qui t'a gardé" + j.g("", "e") + " deux heures pour te montrer ses photos de vacances. Elle votera pour toi."
        case .affiches:
            let cout = max(200, c.poste.budgetReference / 5)
            payer(cout, &j, &e)
            c.depenses += cout
            c.points += Double.random(in: 2...5)
            t = "Ta tête s'affiche dans toute la ville (\(Format.argent(cout))). Quelqu'un t'a déjà dessiné une moustache."
        case .promesse:
            c.points += 5
            e.popularite += 4
            e.casseroles += 3
            t = "Tu promets " + promesses.randomElement()! + ". La foule est en délire. Ton directeur de campagne est livide."
        case .coupBas:
            j.stats.karma -= 5
            if Double.random(in: 0...1) < 0.5 {
                c.points += 6
                t = "Tu révèles que \(c.adversaire) met de l'ananas sur sa pizza. Sa campagne ne s'en remet pas."
            } else {
                c.points -= 6
                e.casseroles += 5
                t = "Ton coup bas contre \(c.adversaire) se retourne contre toi. Le journal du soir parle de « méthodes de cour de récré »."
            }
        }
        e.candidature = c
        if Double.random(in: 0...1) < 0.35, let d = tirerDossier(kind: "campagne", poste: c.poste.rawValue, j, e) {
            return PolResultat(texte: t, dossier: d)
        }
        return PolResultat(texte: t)
    }

    static let promesses = [
        "la sieste remboursée par la Sécurité sociale", "des croissants gratuits le dimanche",
        "de supprimer les lundis", "un rond-point pour chaque habitant", "du Wi-Fi dans les forêts",
        "de baisser les impôts et d'augmenter tout le reste", "un été de dix mois",
        "de transformer la mairie en piscine à vagues",
    ]

    /// Débat télévisé (une fois par campagne).
    static func debat(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard var c = e.candidature else { return PolResultat(texte: "Tu n'es pas en campagne.") }
        guard !c.debatFait else { return PolResultat(texte: "Le débat a déjà eu lieu. Tu peux encore le revoir en boucle et grincer des dents.") }
        guard let d = tirerDossier(kind: "debat", poste: c.poste.rawValue, j, e) else {
            return PolResultat(texte: "Aucune chaîne ne veut organiser le débat. Ton adversaire non plus.")
        }
        c.debatFait = true
        e.candidature = c
        return PolResultat(texte: "Plateau télé, maquillage, projecteurs. C'est l'heure du débat contre \(c.adversaire).", dossier: d)
    }

    static func abandonnerCampagne(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let c = e.candidature else { return PolResultat(texte: "Tu n'es pas en campagne.") }
        e.candidature = nil
        e.popularite -= 3
        return PolResultat(texte: "Tu retires ta candidature pour « te consacrer à ta famille ». Ta famille n'était pas au courant. \(c.adversaire) te remercie.")
    }

    // MARK: - Actions d'élu

    static func inaugurer(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.mandat != nil else { return PolResultat(texte: "Il faut un mandat pour couper des rubans.") }
        guard marquer("inaugurer", &j) else { return dejaFait }
        e.popularite += Int.random(in: 2...5)
        return PolResultat(texte: "Tu inaugures " + inaugurations.randomElement()! + ". Les grands ciseaux, c'est vraiment le meilleur moment du mandat.")
    }

    static let inaugurations = [
        "un rond-point", "un nouveau banc public", "une piste cyclable de 40 mètres", "des toilettes publiques",
        "un parking à vélos sans vélos", "une plaque commémorant l'inauguration d'une autre plaque",
        "un lampadaire", "une médiathèque fermée le samedi",
    ]

    static func serrerMains(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard j.age >= ageCandidat else { return PolResultat(texte: "Tu serres des mains à la sortie de l'école. Les parents trouvent ça bizarre.") }
        guard marquer("mains", &j) else { return dejaFait }
        e.popularite += Int.random(in: 1...4)
        j.stats.sante -= 1
        if var c = e.candidature { c.points += 1; e.candidature = c }
        return PolResultat(texte: [
            "Tu as serré 1 200 mains au salon de l'agriculture et caressé 40 vaches. Une t'a léché" + j.g("", "e") + " pour la photo.",
            "Tu as fait le marché. Tu as goûté tous les fromages. Tu n'as plus faim jusqu'en mars.",
            "Tu as serré des mains à la sortie du métro. Un monsieur t'a confondu" + j.g("", "e") + " avec un vendeur de calendriers.",
        ].randomElement()!)
    }

    static func phraseChoc(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard j.age >= ageCandidat, e.partiId != nil || e.mandat != nil else {
            return PolResultat(texte: "Personne ne t'a tendu de micro. Tu cries ta phrase choc dans le vide.")
        }
        guard marquer("phrase", &j) else { return dejaFait }
        let phrase = phrasesChoc.randomElement()!
        if Double.random(in: 0...1) < 0.5 {
            e.popularite += Int.random(in: 4...8)
            e.influence += 2
            e.titres.append(remplir("« \(phrase) » : la phrase de {prenom} {nom} fait le buzz", j, e))
            return PolResultat(texte: "« \(phrase) » Ta petite phrase tourne en boucle. Les gens l'impriment sur des t-shirts.")
        }
        e.popularite -= Int.random(in: 4...8)
        e.casseroles += 3
        e.titres.append(remplir("Polémique après la sortie de {prenom} {nom}", j, e))
        return PolResultat(texte: "« \(phrase) » Ta petite phrase déclenche une polémique de trois jours. Tu dis avoir été « sorti" + j.g("", "e") + " de son contexte ».")
    }

    static let phrasesChoc = [
        "Le travail, c'est la santé, donc je me ménage.", "Je ne suis pas d'accord avec moi-même, et je l'assume.",
        "Les impôts, c'est comme le sport : c'est bien pour les autres.", "Je traverserai la rue, mais au passage piéton.",
        "Mon programme tient sur un ticket de caisse, et c'est sa force.", "Le peuple a faim ? Qu'il mange des biscottes, c'est moins de miettes.",
        "Je n'ai pas de casseroles, j'ai une batterie de cuisine.", "Le futur, c'est demain, et ça, personne ne l'avait vu venir.",
    ]

    static func seServir(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let m = e.mandat else { return PolResultat(texte: "Il n'y a aucun budget public à portée de main.") }
        guard marquer("servir", &j) else { return dejaFait }
        let montant = Int(Double(m.poste.indemnite) * Double.random(in: 0.2...1.0))
        j.argent += montant
        e.casseroles += Int.random(in: 10...25)
        j.stats.karma -= 6
        return PolResultat(texte: "Tu passes \(Format.argent(montant)) de « frais de représentation ». Dont un jacuzzi, « pour réfléchir ».")
    }

    static func demissionner(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let m = e.mandat else { return PolResultat(texte: "Tu n'as aucun mandat.") }
        terminerMandat(&j, &e, fin: "démission")
        e.popularite -= 5
        e.titres.append(remplir("Coup de tonnerre : {prenom} {nom} démissionne", j, e))
        return PolResultat(texte: "Tu démissionnes de ton poste de \(m.poste.nom(j.genre).lowercased()). Tu pars avec une plante verte et la dignité qu'il te reste.")
    }

    // MARK: - Lois

    /// Lois que le joueur peut proposer avec son mandat actuel.
    static func loisProposables(_ e: PolEtat) -> [PolLoi] {
        guard let m = e.mandat, let niveau = m.poste.niveauLois else { return [] }
        return PolCatalogue.lois.filter { loi in
            guard loi.niveau == niveau, !e.loisActives.contains(loi.id), !e.loisTentees.contains(loi.id) else { return false }
            if m.poste == .ministre { return loi.ministere != nil && loi.ministere == m.ministereId }
            return true
        }
    }

    static func chanceAdoption(_ loi: PolLoi, _ e: PolEtat) -> Double {
        var c = 0.75 - Double(loi.difficulte) / 100 * 0.7
        c += Double(e.influence) * 0.003 + Double(e.popularite) * 0.002
        switch e.mandat?.poste {
        case .maire?: c += 0.05
        case .adjoint?, .depute?: c -= 0.05
        case .ministre?: c += 0.05
        case .president?: c += 0.1
        default: break
        }
        return max(0.03, min(0.95, c))
    }

    /// Proposer une loi (une par an).
    static func proposerLoi(_ id: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let loi = PolCatalogue.loi(id), loisProposables(e).contains(where: { $0.id == id }) else {
            return PolResultat(texte: "Tu ne peux pas proposer ce texte.")
        }
        guard marquer("loi", &j) else { return PolResultat(texte: "Tu as déjà proposé un texte cette année. Le Parlement a besoin de faire la sieste.") }
        e.loisTentees.append(id)
        if Double.random(in: 0...1) < chanceAdoption(loi, e) {
            e.loisActives.append(id)
            e.loisVotees.append(id)
            if let a = loi.adoption { appliquerPol(a, &j, &e) }
            e.titres.append(remplir(loi.headline, j, e))
            return PolResultat(texte: "✅ \(loi.titre) : adoptée ! " + remplir(loi.texteAdoption, j, e))
        }
        e.popularite -= 2
        e.influence -= 1
        return PolResultat(texte: "❌ \(loi.titre) : rejetée. " + remplir(loi.texteRejet, j, e))
    }

    /// Lois en vigueur que le joueur peut abroger avec son mandat actuel.
    static func loisAbrogeables(_ e: PolEtat) -> [PolLoi] {
        guard let m = e.mandat, let niveau = m.poste.niveauLois, m.poste != .ministre else { return [] }
        return e.loisActives.compactMap { PolCatalogue.loi($0) }.filter { $0.niveau == niveau }
    }

    static func abrogerLoi(_ id: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let loi = PolCatalogue.loi(id), loisAbrogeables(e).contains(where: { $0.id == id }) else {
            return PolResultat(texte: "Tu ne peux pas abroger ce texte.")
        }
        guard marquer("loi", &j) else { return PolResultat(texte: "Tu as déjà fait voter un texte cette année.") }
        if Double.random(in: 0...1) < min(0.9, 0.55 + Double(e.influence) * 0.003) {
            e.loisActives.removeAll { $0 == id }
            e.popularite -= (loi.adoption?.popularite ?? 0) / 2
            e.titres.append(remplir("Fin de partie pour « \(loi.titre) »", j, e))
            return PolResultat(texte: "🗑️ « \(loi.titre) » est abrogée. Retour à la normale, ou ce qui en tenait lieu.")
        }
        e.influence -= 2
        return PolResultat(texte: "L'abrogation de « \(loi.titre) » est rejetée. Visiblement, les gens s'y étaient attachés.")
    }

    // MARK: - Dossiers

    /// Poste utilisé pour filtrer dossiers et scandales.
    static func posteCourant(_ e: PolEtat) -> String {
        e.mandat?.poste.rawValue ?? "militant"
    }

    static func tirerDossier(kind: String, poste: String, _ j: Joueur, _ e: PolEtat) -> PolDossier? {
        let ministere = e.mandat?.ministereId
        let candidats = PolCatalogue.dossiers.filter { d in
            guard d.kind == kind, d.postes.contains(poste) || d.postes.contains("any") else { return false }
            if d.unique == true && e.dossiersVus.contains(d.id) { return false }
            if let m = d.ministere, poste == PolPoste.ministre.rawValue, m != ministere { return false }
            return true
        }
        return tirage(candidats) { $0.weight ?? 1 }
    }

    /// Trancher un dossier (du bureau ou présenté directement). Renvoie le texte du résultat.
    /// `appliquer` : passer `engine.appliquer` pour profiter des effets complets du moteur (sinon version simple).
    static func trancher(_ d: PolDossier, choix: Int, _ j: inout Joueur, _ e: inout PolEtat,
                         appliquer: ((Effets, inout Joueur) -> Void)? = nil) -> String {
        e.dossiers.removeAll { $0.dossierId == d.id }
        if !e.dossiersVus.contains(d.id) { e.dossiersVus.append(d.id) }
        guard d.choices.indices.contains(choix),
              let issue = tirage(d.choices[choix].outcomes, poids: { $0.chance ?? 1 }) else { return "" }
        let texte = remplir(issue.text, j, e)
        ajouterLigne(&j, "\(d.title) : \(texte)")
        if let eff = issue.effects {
            if let a = appliquer { a(eff, &j) } else { appliquerSimple(eff, &j) }
        }
        if let p = issue.pol { appliquerPol(p, &j, &e) }
        e.borner()
        j.stats.borner()
        return texte
    }

    /// Dossiers en attente, prêts à être affichés.
    static func dossiersEnAttente(_ e: PolEtat) -> [PolDossier] {
        e.dossiers.compactMap { PolCatalogue.dossier($0.dossierId) }
    }

    // MARK: - Effets

    static func appliquerPol(_ p: PolEffets, _ j: inout Joueur, _ e: inout PolEtat) {
        e.popularite += p.popularite ?? 0
        e.influence += p.influence ?? 0
        e.casseroles += p.casseroles ?? 0
        e.loyaute += p.loyaute ?? 0
        e.caisse += p.caisse ?? 0
        e.parrainages += p.parrainages ?? 0
        if let c = p.campagne, var cand = e.candidature {
            cand.points += c
            e.candidature = cand
        }
        if let id = p.loi, !e.loisActives.contains(id), let loi = PolCatalogue.loi(id) {
            e.loisActives.append(id)
            e.titres.append(remplir(loi.headline, j, e))
        }
        if let id = p.abroger { e.loisActives.removeAll { $0 == id } }
        if p.exclusionParti == true, e.partiId != nil {
            e.partiId = nil
            e.influence -= 5
            ajouterLigne(&j, "Tu es " + j.g("exclu", "exclue") + " de ton parti. Ta carte a été découpée en direct.")
        }
        if let n = p.ineligibilite, n > 0 {
            e.ineligibilite = max(e.ineligibilite, n)
            e.candidature = nil
        }
        if let raison = p.finMandat, e.mandat != nil {
            terminerMandat(&j, &e, fin: raison)
            ajouterLigne(&j, "Ton mandat prend fin : \(raison).")
        }
        e.borner()
    }

    /// Effets du moteur, version autonome (stats, argent, liens, nouvel ami, mort).
    static func appliquerSimple(_ eff: Effets, _ j: inout Joueur) {
        j.stats.sante += eff.health ?? 0
        j.stats.bonheur += eff.happiness ?? 0
        j.stats.intelligence += eff.smarts ?? 0
        j.stats.apparence += eff.looks ?? 0
        j.stats.karma += eff.karma ?? 0
        j.argent += eff.money ?? 0
        j.stats.borner()
        if let liens = eff.relationships {
            for (cle, delta) in liens {
                for i in j.relations.indices where j.relations[i].vivant && correspond(j.relations[i].type, cle) {
                    j.relations[i].lien = Stats.borne(j.relations[i].lien + delta)
                }
            }
        }
        if eff.newFriend == true {
            let g = Genre.allCases.randomElement()!
            let ami = Relation(prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement()!, genre: g, type: .ami,
                               age: max(1, j.age + Int.random(in: -5...5)), lien: Int.random(in: 50...80))
            j.relations.append(ami)
            ajouterLigne(&j, "Tu t'es fait " + (g == .femme ? "une nouvelle amie" : "un nouvel ami") + " : \(ami.prenom).")
        }
        if let cause = eff.death, j.vivant {
            j.vivant = false
            j.causeDeces = cause
            j.emploi = nil
            j.etudes = nil
            ajouterLigne(&j, "⚰️ Tu es " + j.g("mort", "morte") + " \(cause), à \(j.age) ans.")
        }
    }

    private static func correspond(_ type: TypeRelation, _ cle: String) -> Bool {
        switch cle {
        case "mother": return type == .mere
        case "father": return type == .pere
        case "parent": return type.estParent
        case "sibling": return type == .frere || type == .soeur
        case "friend": return type == .ami
        case "partner": return type == .partenaire
        case "child": return type == .enfant
        default: return false
        }
    }

    // MARK: - Lecture pour les autres modules

    /// Tags à ajouter à `GameEngine.tags(_:)`.
    static func tags(_ e: PolEtat?) -> Set<String> {
        guard let e = e else { return [] }
        var t: Set<String> = []
        if e.partiId != nil { t.insert("pol_militant") }
        if let m = e.mandat {
            t.insert("pol_elu")
            t.insert("pol_" + m.poste.rawValue)
        }
        if e.candidature != nil { t.insert("pol_candidat") }
        if e.casseroles >= 50 { t.insert("pol_scandale") }
        for id in e.loisActives { if let tag = PolCatalogue.loi(id)?.tag { t.insert(tag) } }
        return t
    }

    /// Titres de presse politiques de l'année (pour le Journal du monde).
    static func titresActualite(_ e: PolEtat?) -> [String] { e?.titres ?? [] }

    /// Multiplicateurs de prix des lois en vigueur (à passer en `extra:` au Journal du monde).
    static func facteursPrix(_ e: PolEtat?) -> [[String: Double]] {
        (e?.loisActives ?? []).compactMap { PolCatalogue.loi($0)?.prix }
    }

    /// Multiplicateurs de salaires des lois en vigueur (à passer en `extra:` au Journal du monde).
    static func facteursSalaires(_ e: PolEtat?) -> [[String: Double]] {
        (e?.loisActives ?? []).compactMap { PolCatalogue.loi($0)?.salaires }
    }

    /// Produit des multiplicateurs d'une règle (prison, amendes, retraite, mortalite…). 1 si aucune loi.
    static func regle(_ cle: String, _ e: PolEtat?) -> Double {
        (e?.loisActives ?? []).compactMap { PolCatalogue.loi($0)?.regles?[cle] }.reduce(1, *)
    }

    /// Somme d'une règle additive (ageRetraite, elections, popularite, impots, mandatsIllimites). 0 si aucune loi.
    static func regleSomme(_ cle: String, _ e: PolEtat?) -> Double {
        (e?.loisActives ?? []).compactMap { PolCatalogue.loi($0)?.regles?[cle] }.reduce(0, +)
    }

    /// Une ligne pour la nécrologie, ou nil sans carrière politique.
    static func resumeCarriere(_ e: PolEtat?, genre: Genre) -> String? {
        guard let e = e else { return nil }
        let postes = ([e.mandat?.poste].compactMap { $0 } + e.historique.map { $0.poste })
        guard let top = postes.max(by: { $0.rang < $1.rang }) else {
            if let p = PolCatalogue.parti(e.partiId) { return (genre == .femme ? "Militante" : "Militant") + " fidèle du \(p.nom)" }
            return nil
        }
        var t = (e.mandat?.poste == top ? "" : (genre == .femme ? "Ancienne " : "Ancien ")) + top.nom(genre).lowercased()
        t = t.prefix(1).uppercased() + t.dropFirst()
        if top == .president && e.mandatsPresident > 1 { t += " (\(e.mandatsPresident) mandats)" }
        let n = e.loisVotees.count
        if n > 0 { t += ", auteur" + (genre == .femme ? "e" : "") + " de \(n) loi\(n > 1 ? "s" : "") absurde\(n > 1 ? "s" : "")" }
        return t
    }

    // MARK: - Outils

    static let dejaFait = PolResultat(texte: "Tu as déjà fait ça cette année. Même en politique, il y a des limites (peu).")

    /// Marque une action comme faite cette année. Renvoie false si elle l'était déjà.
    static func marquer(_ cle: String, _ j: inout Joueur) -> Bool {
        let k = "pol_" + cle
        if j.actionsAnnee.contains(k) { return false }
        j.actionsAnnee.append(k)
        return true
    }

    static func dejaFaitCetteAnnee(_ cle: String, _ j: Joueur) -> Bool {
        j.actionsAnnee.contains("pol_" + cle)
    }

    /// Paie d'abord avec la caisse de campagne, puis avec l'argent du joueur.
    private static func payer(_ montant: Int, _ j: inout Joueur, _ e: inout PolEtat) {
        let deCaisse = min(e.caisse, montant)
        e.caisse -= deCaisse
        j.argent -= montant - deCaisse
    }

    static func terminerMandat(_ j: inout Joueur, _ e: inout PolEtat, fin: String) {
        guard let m = e.mandat else { return }
        e.historique.append(PolMandatPasse(poste: m.poste, ministereId: m.ministereId, ageDebut: m.ageDebut, ageFin: j.age, fin: fin))
        e.mandat = nil
        e.dossiers.removeAll { PolCatalogue.dossier($0.dossierId)?.kind == "dossier" }
    }

    static func nomParti(_ e: PolEtat) -> String {
        PolCatalogue.parti(e.partiId)?.nom ?? "ton parti"
    }

    static func nomMinistere(_ e: PolEtat) -> String {
        PolCatalogue.ministere(e.mandat?.ministereId)?.nom ?? "Ministère des Choses Diverses"
    }

    static func ajouterLigne(_ j: inout Joueur, _ texte: String) {
        if j.journal.isEmpty { j.journal.append(Annee(age: j.age, lignes: [])) }
        j.journal[j.journal.count - 1].lignes.append(texte)
    }

    static func remplir(_ texte: String, _ j: Joueur, _ e: PolEtat?) -> String {
        var t = texte
        t = t.replacingOccurrences(of: "{prenom}", with: j.prenom)
        t = t.replacingOccurrences(of: "{nom}", with: j.nom)
        t = t.replacingOccurrences(of: "{ville}", with: j.ville)
        t = t.replacingOccurrences(of: "{mere}", with: j.mere?.prenom ?? "ta mère")
        t = t.replacingOccurrences(of: "{pere}", with: j.pere?.prenom ?? "ton père")
        t = t.replacingOccurrences(of: "{partenaire}", with: j.relations.first { $0.type == .partenaire && $0.vivant }?.prenom ?? "ton crush")
        t = t.replacingOccurrences(of: "{ami}", with: j.amis.randomElement()?.prenom ?? "ton pote")
        t = t.replacingOccurrences(of: "{parti}", with: e.map(nomParti) ?? "ton parti")
        t = t.replacingOccurrences(of: "{poste}", with: e?.mandat?.poste.nom(j.genre).lowercased() ?? j.g("militant", "militante"))
        t = t.replacingOccurrences(of: "{adversaire}", with: e?.candidature?.adversaire ?? "ton adversaire")
        t = t.replacingOccurrences(of: "{ministere}", with: e.map(nomMinistere) ?? "ton ministère")
        t = t.replacingOccurrences(of: "{e}", with: j.genre == .femme ? "e" : "")
        return t
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
}

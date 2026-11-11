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
        defer {
            e.titresPublies = e.titres
            e.titres = []
            e.flashsPublies = e.flashsMonde
            e.flashsMonde = []
        }
        guard j.vivant else { return l }

        // Lois en vigueur
        appliquerLoisAnnuelles(&j, &e, &l)

        // Parti
        if let parti = e.parti {
            j.argent -= parti.cotisation
            e.loyaute += Int.random(in: -2...1)
        }

        if e.ineligibilite > 0 {
            e.ineligibilite -= 1
            if e.ineligibilite == 0 { l.append("⚖️ Ta peine d'inéligibilité est terminée. Tu peux de nouveau te présenter à une élection.") }
        }

        // Dossiers non traités
        for d in e.dossiers {
            guard let dossier = PolCatalogue.dossier(d.dossierId) else { continue }
            if dossier.kind == "scandale" {
                e.popularite -= 8
                e.casseroles += 5
                l.append("📰 Tu n'as jamais répondu au scandale « \(dossier.title) ». Ton silence a été interprété comme un aveu.")
            } else {
                e.popularite -= 4
                l.append("📂 Le dossier « \(dossier.title) » est resté sans réponse. L'opposition et la presse te le reprochent.")
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
            if m.poste == .ministre || m.poste == .premierMinistre {
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
            l.append("🎗️ Ton mandat de \(m.poste.nom(j.genre).lowercased()) s'achève. Tu passes le relais et tu fais tes cartons.")
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

        // Pays, électorat, rivaux, parti, équipe, gouvernement
        anneeProfonde(&j, &e, &l)

        // Justice
        justice(&j, &e, &l)

        // Scandales
        if e.partiId != nil || enPoste {
            var chance = Double(e.casseroles) / 250
            if j.stats.karma < 30 { chance += 0.08 }
            if enPoste { chance += 0.05 }
            if Double.random(in: 0...1) < chance,
               let s = tirerDossier(kind: "scandale", poste: posteCourant(e), j, e) ?? tirerDossier(kind: "scandale", poste: posteVoisin(e), j, e) {
                e.dossiers.append(PolDossierEnAttente(dossierId: s.id, ageArrivee: j.age))
                l.append("📰 Scandale : « \(s.title) ». La presse attend ta réponse (onglet Politique).")
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
        "Opinia", "Institut Delorme", "Baromètre Civis", "Panel France", "Statéo",
        "Institut Vauban", "Mesure & Opinion", "Cap Sondages", "Observatoire Marianne", "Tendances Publiques",
    ]
    static let margesErreur = ["± 2 points", "± 3 points", "± 3 points", "± 3,5 points", "± 4 points", "± 5 points"]

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
            let estPM = e.mandat?.poste == .premierMinistre
            let ancien = nomMinistere(e)
            terminerMandat(&j, &e, fin: "remaniement")
            j.stats.bonheur -= 10
            l.append(estPM
                     ? "🔄 Le chef de l'État te remplace à la tête du gouvernement « pour donner un nouveau souffle ». Tu quittes Matignon."
                     : "🔄 Remaniement ! Tu quittes le \(ancien). L'annonce est tombée sans que tu sois prévenu" + j.g("", "e") + ".")
        } else if Double.random(in: 0...1) < 0.06, var m = e.mandat, m.poste == .ministre,
                  let nouveau = PolCatalogue.ministeres.filter({ $0.id != m.ministereId }).randomElement() {
            m.ministereId = nouveau.id
            e.mandat = m
            l.append("🔄 Remaniement : tu passes au \(nouveau.nom). Une nouvelle administration, de nouveaux dossiers.")
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
            l.append("⚖️ Tu es " + j.g("condamné", "condamnée") + " : \(Format.argent(amende)) d'amende et 5 ans d'inéligibilité. Ton avocat annonce faire appel.")
            e.titres.append(remplir("{prenom} {nom} condamné{e} et déclaré{e} inéligible", j, e))
        } else {
            e.popularite -= 12
            j.stats.bonheur -= 8
            if let proces = tirerDossier(kind: "proces", poste: "any", j, e), e.dossiers.count < 5 {
                e.dossiers.append(PolDossierEnAttente(dossierId: proces.id, ageArrivee: j.age))
            }
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
        if e.ineligibilite > 0 { return "Tu es inéligible encore \(e.ineligibilite) an\(e.ineligibilite > 1 ? "s" : "")." }
        if j.age < p.ageMin { return "Il faut avoir \(p.ageMin) ans." }
        if let m = e.mandat {
            let finProche = (m.anneesRestantes ?? 0) <= 1
            if m.poste == p {
                if !finProche { return "Ton mandat dure encore \(m.anneesRestantes ?? 0) ans." }
            } else if m.poste == .adjoint && p == .conseiller {
                if !finProche { return "Ton mandat dure encore \(m.anneesRestantes ?? 0) ans." }
            } else if m.poste == .presidentRegion && p == .conseillerRegional {
                if !finProche { return "Ton mandat dure encore \(m.anneesRestantes ?? 0) ans." }
            } else if m.poste == .presidentAssemblee && p == .depute {
                if !finProche { return "Ton mandat dure encore \(m.anneesRestantes ?? 0) ans." }
            } else if m.poste.rang >= p.rang {
                return "Tu occupes déjà un poste plus important."
            }
        }
        switch p {
        case .maire:
            if !(e.aOccupe(.conseiller) || e.aOccupe(.adjoint)) && e.influence < 40 {
                return "Il faut avoir été conseiller municipal, ou 40 d'influence."
            }
        case .conseillerRegional:
            if !(e.aOccupe(.conseiller) || e.aOccupe(.adjoint) || e.aOccupe(.maire)) && e.influence < 30 {
                return "Il faut avoir été élu municipal, ou 30 d'influence."
            }
        case .presidentRegion:
            if e.mandat?.poste != .conseillerRegional { return "Il faut siéger au conseil régional." }
        case .depute:
            if !(e.aOccupe(.maire) || e.aOccupe(.adjoint) || e.aOccupe(.conseillerRegional)) && e.influence < 55 {
                return "Il faut avoir été maire, adjoint ou élu régional, ou 55 d'influence."
            }
        case .senateur:
            if !(e.aOccupe(.maire) || e.aOccupe(.conseillerRegional) || e.aOccupe(.presidentRegion)) && e.influence < 60 {
                return "Les grands électeurs ne connaissent que les maires et les élus régionaux (ou 60 d'influence)."
            }
        case .presidentAssemblee:
            if e.mandat?.poste != .depute && e.mandat?.poste != .presidentAssemblee { return "Il faut être député." }
        case .president:
            if !(e.aOccupe(.depute) || e.aOccupe(.ministre) || e.aOccupe(.premierMinistre) || e.aOccupe(.senateur)) {
                return "Il faut avoir été député, sénateur ou ministre."
            }
            if e.influence < 60 { return "Il faut 60 d'influence." }
            if e.parrainages < parrainagesRequis { return "Il faut \(parrainagesRequis) parrainages (tu en as \(e.parrainages))." }
            if e.mandatsPresident >= 2 && regleSomme("mandatsIllimites", e) < 1 { return "La Constitution limite à deux mandats consécutifs." }
        case .secretaireGeneral:
            if !(e.aOccupe(.president) || e.aOccupe(.commissaire)) { return "Il faut avoir été président ou commissaire." }
            if e.influence < 70 { return "Il faut 70 d'influence." }
        default:
            break
        }
        if j.argent + e.caisse < p.caution { return "La caution coûte \(Format.argent(p.caution))." }
        return nil
    }

    /// Se déclarer candidat. L'élection a lieu au prochain passage d'année.
    static func seDeclarer(_ p: PolPoste, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        if let raison = empechementCandidature(p, j, e) { return PolResultat(texte: raison) }
        payer(p.caution, &j, &e)
        let rival = choisirAdversaire(p, &e)
        let adv = rival.nomComplet
        let partiAdv = PolCatalogue.parti(rival.partiId)
        let reelection = e.mandat?.poste == p
        var dissident = false
        var noteParti = ""
        if besoinInvestiture(p, e) {
            if e.investiture == p.rawValue {
                noteParti = " Ton parti t'a officiellement investi" + j.g("", "e") + "."
            } else if let parti = e.parti {
                dissident = true
                e.partiId = nil
                e.rangParti = 0
                e.influence -= 6
                noteParti = " Sans investiture, tu pars en dissidence : le \(parti.nom) t'exclut dans l'heure."
            }
        }
        e.investiture = nil
        var cand = PolCandidature(poste: p, adversaire: adv, adversairePartiId: partiAdv?.id, reelection: reelection)
        cand.rivalId = rival.id
        cand.dissident = dissident
        e.candidature = cand
        e.parrainages = p == .president ? e.parrainages - parrainagesRequis : e.parrainages
        e.titres.append(remplir("{prenom} {nom} officialise sa candidature", j, e))
        let advTexte = adv + (partiAdv.map { " (\($0.sigle))" } ?? "")
        var t = reelection
            ? "Tu te représentes. Tu vas devoir défendre ton bilan."
            : "Tu es " + j.g("candidat", "candidate") + " au poste de \(p.nom(j.genre).lowercased()) !"
        t += " Ton adversaire principal : \(advTexte). L'élection aura lieu à la fin de l'année."
        if p.caution > 0 { t += " Caution versée : \(Format.argent(p.caution))." }
        t += noteParti
        if rival.duels > 0 { t += " Vous vous êtes déjà affrontés \(rival.duels) fois. Le duel s'annonce tendu." }
        return PolResultat(texte: t)
    }

    static func scoreElection(_ c: PolCandidature, _ j: Joueur, _ e: PolEtat, depense: Int) -> Double {
        let p = c.poste
        var s = 15 + p.facilite
        if p.electionIndirecte {
            // Les élus votent : réseau, loyauté, rang déjà atteint.
            s += Double(e.influence) * 0.45 + Double(e.loyaute) * 0.12 + Double(e.popularite) * 0.12
            s += Double(max(0, e.rangMax)) * 2.5
            if e.estChefDeParti { s += 5 }
        } else {
            s += popularitePonderee(e) * 0.42
            s += Double(e.influence) * 0.22
            s += min(14, Double(depense) / Double(max(1, p.budgetReference)) * 12)
            s += Double(j.stats.apparence - 50) * 0.08
            if let d = e.equipe.first(where: { $0.role == .directeur }) { s += Double(d.competence) / 12 }
        }
        if let parti = e.parti {
            s += parti.bonusElection
            if e.partiPerso?.id == parti.id { s += Double(min(6, e.electionsGagnees)) - 3 }
        } else {
            s -= p == .conseiller ? 1 : 4
        }
        s += Double(j.stats.intelligence - 50) * 0.05
        s += Double(j.stats.karma - 50) * 0.03
        s += max(-15, min(20, c.points))
        s -= Double(e.casseroles) * 0.25
        if c.reelection { s += 6 }
        if c.dissident == true { s -= 3 }
        s += regleSomme("elections", e)
        return s
    }

    static func pourcentage(_ x: Double) -> String {
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
        var soiree = PolSoiree(poste: p, gagne: gagne, reelection: c.reelection, adversaire: c.adversaire, score: 0)
        if p == .president {
            let tour1 = max(2.1, min(46, score * 0.55 + Double.random(in: -3...3)))
            soiree.tour1 = tour1
            soiree.participation = Double.random(in: 70...82)
            if score < 42 {
                gagne = false
                soiree.eliminePremierTour = true
                soiree.score = tour1
                detail = "Premier tour : \(pourcentage(tour1)). Éliminé" + j.g("", "e") + " dès le premier tour."
            } else {
                let tour2 = max(50.1, min(78, 50 + (score - 50) * 0.7))
                let perdu = max(22, min(49.9, 50 + (score - 50) * 0.7))
                soiree.score = gagne ? tour2 : perdu
                detail = "Premier tour : \(pourcentage(tour1)). Second tour : \(pourcentage(gagne ? tour2 : perdu))."
            }
        } else if p.electionIndirecte {
            let electeurs = p == .secretaireGeneral ? "pays membres" : (p == .senateur ? "grands électeurs" : (p == .presidentAssemblee ? "députés" : "conseillers régionaux"))
            let pct = gagne ? max(50.1, min(97, 50 + (score - 50) * 0.7)) : max(0.4, min(49.9, 50 + (score - 50) * 0.7))
            soiree.score = pct
            detail = "Vote des \(electeurs) : \(pourcentage(pct))."
        } else {
            let pct = gagne ? max(50.1, min(97, 50 + (score - 50) * 0.7)) : max(0.4, min(49.9, 50 + (score - 50) * 0.7))
            soiree.score = pct
            soiree.participation = participationPour(p)
            detail = "Résultat : \(pourcentage(pct))."
        }
        soiree.gagne = gagne
        e.soiree = soiree
        majRivalApresElection(c, gagne: gagne, &e)

        if gagne {
            e.electionsGagnees += 1
            e.popularite += 5
            e.influence += 6 + p.rang * 2
            j.stats.bonheur += 15
            if p == .president {
                e.mandatsPresident += 1
                apresVictoirePresidentielle(score: score, &j, &e, &l)
            }
            if c.reelection, var m = e.mandat {
                m.anneesRestantes = p.duree
                m.numero += 1
                e.mandat = m
                e.dernierResultat = "Réélu" + j.g("", "e") + " \(nomPoste) ! \(detail)"
                l.append("🗳️ Tu es " + j.g("réélu", "réélue") + " \(nomPoste) ! \(detail) Ton adversaire, \(c.adversaire), reconnaît sa défaite.")
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
        "Tu prononces ton discours de victoire devant tes militants, la voix nouée.",
        "Tu promets d'être au service de tous, y compris de ceux qui n'ont pas voté pour toi.",
        "Tes militants scandent ton nom. Tu penses déjà aux premiers dossiers.",
        "Tu remercies ta famille, tes militants et, par erreur, ton adversaire.",
    ]
    static let defaites = [
        "Tu reconnais ta défaite avec dignité et tu félicites ton adversaire.",
        "Tu analyses les résultats bureau par bureau. Il a manqué peu de chose.",
        "Ton équipe de campagne se disperse. Certains te reprochent tes choix.",
        "Tu annonces « prendre du recul ». La soirée électorale a été longue.",
    ]

    // MARK: - Nominations

    static func empechementMinistere(_ j: Joueur, _ e: PolEtat) -> String? {
        if e.partiId == nil { return "Il faut un parti pour entrer au gouvernement." }
        if e.ineligibilite > 0 { return "Un ministre condamné serait intenable pour le gouvernement." }
        if let m = e.mandat, m.poste.rang >= PolPoste.ministre.rang { return "Tu occupes déjà un poste plus élevé." }
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
            "Tu as fait passer le message à l'Élysée. On t'a remercié poliment, sans rien promettre.",
            "Tu as déjeuné avec un conseiller du Président. Ton nom circule, mais pas assez.",
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
        let nom = choisi?.nom ?? "Ministère délégué"
        e.titres.append(remplir("{prenom} {nom} nommé{e} au \(nom)", j, e))
        return (appel ? "📞 Le chef de l'État t'appelle un dimanche à 7 h. " : "") +
            "🏛️ Tu es " + j.g("nommé", "nommée") + " ministre : \(nom) ! Ton cabinet t'attend avec une pile de notes à lire avant demain."
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
            return PolResultat(texte: "Le maire te nomme " + j.g("adjoint", "adjointe") + " \(delegation). Tu as enfin une délégation à toi.")
        }
        e.loyaute -= 3
        return PolResultat(texte: "Le maire t'a écouté" + j.g("", "e") + " avec attention, puis a donné le poste à un fidèle de longue date.")
    }

    static let delegations = [
        "à l'urbanisme", "à la propreté et aux déchets",
        "à la sécurité et à la tranquillité publique", "aux mobilités et au stationnement", "à la culture",
        "aux sports et à la vie associative", "aux écoles et à la petite enfance",
    ]

    // MARK: - Actions de parti

    static func adherer(_ partiId: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let p = PolCatalogue.parti(partiId) else { return PolResultat(texte: "Ce parti n'existe plus.") }
        guard j.age >= ageMilitant else { return PolResultat(texte: "Il faut avoir \(ageMilitant) ans pour prendre sa carte.") }
        guard e.partiId == nil else { return PolResultat(texte: "Tu es déjà membre d'un parti. Quitte-le d'abord.") }
        e.partiId = p.id
        e.loyaute = 50
        e.influence += p.influence ?? 3
        j.argent -= p.cotisation
        return PolResultat(texte: "Tu prends ta carte au \(p.nom) (\(p.sigle)). « \(p.slogan) » La section locale t'accueille et te confie tes premiers tracts.")
    }

    static func quitterParti(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let p = e.parti else { return PolResultat(texte: "Tu n'as pas de parti.") }
        e.partiId = nil
        e.influence -= 8
        e.popularite += Int.random(in: -4...4)
        e.titres.append(remplir("{prenom} {nom} claque la porte du \(p.sigle)", j, e))
        return PolResultat(texte: "Tu quittes le \(p.nom) avec une lettre ouverte. Certains anciens camarades ne te le pardonneront pas.")
    }

    static func militer(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.partiId != nil else { return PolResultat(texte: "Il te faut un parti pour militer.") }
        guard marquer("militer", &j) else { return dejaFait }
        e.influence += Int.random(in: 2...5)
        e.loyaute += 3
        e.popularite += Int.random(in: 0...2)
        j.stats.sante -= Int.random(in: 0...1)
        let texte = [
            "Tu as tracté au marché sous la pluie. Quelques habitants se sont arrêtés pour discuter.",
            "Tu as collé des affiches toute la nuit avec la section. Les anciens t'ont appris les bons endroits.",
            "Tu as tenu la permanence du parti. Un retraité est venu parler de sa pension pendant une heure.",
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
            "Tu as soutenu publiquement la motion du président de fédération. Il s'en souviendra.",
            "Tu as invité le chef du parti à déjeuner. Il t'appelle maintenant par ton prénom.",
            "Tu as défendu la direction à la télévision, même sur un sujet qui te gêne.",
        ].randomElement()!)
    }

    static func leverFonds(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard j.age >= ageCandidat else { return PolResultat(texte: "Il faut être majeur pour lever des fonds.") }
        guard marquer("fonds", &j) else { return dejaFait }
        let rang = min(5, max(0, e.rangMax))
        let base = Double(e.influence * 150 + e.popularite * 80 + 500)
        let tresorier = e.equipe.first { $0.role == .tresorier }
        let multiplicateur: Double = pow(2.6, Double(rang))
        let hasard: Double = Double.random(in: 0.6...1.4)
        let bonusTresorier: Double = 1 + Double(tresorier?.competence ?? 0) / 100
        let montant = Int(base * multiplicateur * hasard * bonusTresorier)
        e.caisse += montant
        if Double.random(in: 0...1) < (tresorier == nil ? 0.25 : 0.12) {
            e.casseroles += Int.random(in: 4...10)
            return PolResultat(texte: "Ton dîner de levée de fonds rapporte \(Format.argent(montant)). Un des chèques vient d'une entreprise, ce qui est interdit. La presse s'y intéresse.")
        }
        return PolResultat(texte: "Ton dîner à \(Format.argent(rang >= 3 ? 1000 : 50)) le couvert rapporte \(Format.argent(montant)) à ta caisse de campagne.")
    }

    static func verserCaisse(_ montant: Int, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard montant > 0, j.argent >= montant else { return PolResultat(texte: "Tu n'as pas assez d'argent.") }
        j.argent -= montant
        e.caisse += montant
        return PolResultat(texte: "Tu verses \(Format.argent(montant)) de ta poche dans ta caisse de campagne. Ton compte en banque, un peu moins.")
    }

    static func recolterParrainages(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.aOccupe(.depute) || e.aOccupe(.ministre) else { return PolResultat(texte: "Les maires ne parrainent que des gens qu'ils connaissent. Tu n'as pas encore assez de réseau.") }
        guard marquer("parrainages", &j) else { return dejaFait }
        let n = e.influence * 3 + Int.random(in: 30...160) + (e.partiId == nil ? -40 : 30)
        e.parrainages += max(10, n)
        return PolResultat(texte: "Tu as fait le tour des mairies rurales. +\(max(10, n)) parrainages, et beaucoup de cafés partagés. Total : \(e.parrainages)/\(parrainagesRequis).")
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
            case .promesse: return "Faire une promesse forte"
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
                t = "Ton meeting tourne mal : des opposants perturbent ta prise de parole et la presse ne retient que les huées."
            } else {
                let g = Double.random(in: 2...6)
                c.points += g
                e.popularite += 2
                t = "Meeting réussi ! \(Int.random(in: 80...2400)) personnes, et une bonne couverture dans la presse locale."
            }
        case .porteAPorte:
            c.points += Double.random(in: 1...4)
            j.stats.karma += 1
            j.stats.sante -= 1
            t = "Porte-à-porte : des dizaines de portes, beaucoup de méfiance, et quelques vraies conversations sur le loyer, l'école et le travail. Ça compte."
        case .affiches:
            let cout = max(200, c.poste.budgetReference / 5)
            payer(cout, &j, &e)
            c.depenses += cout
            c.points += Double.random(in: 2...5)
            t = "Ta tête s'affiche dans toute la ville (\(Format.argent(cout))). Ton visage et ton slogan sont partout."
        case .promesse:
            c.points += 5
            e.popularite += 4
            e.casseroles += 3
            t = "Tu promets " + promesses.randomElement()! + ". La salle applaudit. Ton équipe se demande déjà comment la financer."
        case .coupBas:
            j.stats.karma -= 5
            if Double.random(in: 0...1) < 0.5 {
                c.points += 6
                t = "Tu exhumes une vieille contradiction de \(c.adversaire). Sa campagne passe la semaine à se justifier."
            } else {
                c.points -= 6
                e.casseroles += 5
                t = "Ton coup bas contre \(c.adversaire) se retourne contre toi. Le journal du soir parle de « campagne de caniveau »."
            }
        }
        e.candidature = c
        if Double.random(in: 0...1) < 0.35, let d = tirerDossier(kind: "campagne", poste: c.poste.rawValue, j, e) {
            return PolResultat(texte: t, dossier: d)
        }
        return PolResultat(texte: t)
    }

    static let promesses = [
        "de ne plus augmenter les impôts locaux pendant tout le mandat", "la gratuité des transports pour les moins de 25 ans",
        "un médecin dans chaque quartier", "de construire 2 000 logements", "de doubler les effectifs de police",
        "de baisser les impôts et d'augmenter tout le reste", "la cantine à 1 euro",
        "de rouvrir la maternité",
    ]

    /// Débat télévisé (une fois par campagne).
    static func debat(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard var c = e.candidature else { return PolResultat(texte: "Tu n'es pas en campagne.") }
        guard !c.debatFait else { return PolResultat(texte: "Le débat a déjà eu lieu. Les chaînes en diffusent encore des extraits.") }
        guard let d = tirerDossier(kind: "debat", poste: c.poste.rawValue, j, e) else {
            return PolResultat(texte: "Aucune chaîne ne veut organiser le débat. Ton adversaire a refusé tous les formats.")
        }
        c.debatFait = true
        e.candidature = c
        return PolResultat(texte: "Plateau télé, maquillage, projecteurs. C'est l'heure du débat contre \(c.adversaire).", dossier: d)
    }

    static func abandonnerCampagne(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let c = e.candidature else { return PolResultat(texte: "Tu n'es pas en campagne.") }
        e.candidature = nil
        e.popularite -= 3
        return PolResultat(texte: "Tu retires ta candidature pour « te consacrer à ta famille ». \(c.adversaire) salue « une décision responsable ».")
    }

    // MARK: - Actions d'élu

    static func inaugurer(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.mandat != nil else { return PolResultat(texte: "Il faut un mandat pour inaugurer.") }
        guard marquer("inaugurer", &j) else { return dejaFait }
        e.popularite += Int.random(in: 2...5)
        return PolResultat(texte: "Tu inaugures " + inaugurations.randomElement()! + ". C'est un projet que tu as porté depuis le début.")
    }

    static let inaugurations = [
        "une nouvelle école", "une maison de santé", "une piste cyclable", "un gymnase rénové",
        "un parking à vélos sans vélos", "une résidence de logements sociaux",
        "une crèche", "une médiathèque",
    ]

    static func serrerMains(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard j.age >= ageCandidat else { return PolResultat(texte: "Tu serres des mains à la sortie de l'école. Tu es trop jeune pour être candidat" + j.g("", "e") + ".") }
        guard marquer("mains", &j) else { return dejaFait }
        e.popularite += Int.random(in: 1...4)
        j.stats.sante -= 1
        if var c = e.candidature { c.points += 1; e.candidature = c }
        return PolResultat(texte: [
            "Tu as passé la journée au salon de l'agriculture. Les éleveurs t'ont parlé de leurs prix et de leurs dettes.",
            "Tu as fait le marché. Les commerçants t'ont parlé des loyers et des charges.",
            "Tu as serré des mains à la sortie du métro. Un monsieur t'a confondu" + j.g("", "e") + " avec un vendeur de calendriers.",
        ].randomElement()!)
    }

    static func phraseChoc(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard j.age >= ageCandidat, e.partiId != nil || e.mandat != nil else {
            return PolResultat(texte: "Personne ne t'a tendu de micro. Tu n'as pas encore de tribune.")
        }
        guard marquer("phrase", &j) else { return dejaFait }
        let phrase = phrasesChoc.randomElement()!
        if Double.random(in: 0...1) < 0.5 {
            e.popularite += Int.random(in: 4...8)
            e.influence += 2
            e.titres.append(remplir("« \(phrase) » : la phrase de {prenom} {nom} fait le buzz", j, e))
            return PolResultat(texte: "« \(phrase) » Ta petite phrase tourne en boucle. Elle résume bien ce que beaucoup pensent.")
        }
        e.popularite -= Int.random(in: 4...8)
        e.casseroles += 3
        e.titres.append(remplir("Polémique après la sortie de {prenom} {nom}", j, e))
        return PolResultat(texte: "« \(phrase) » Ta petite phrase déclenche une polémique nationale. Tu dis avoir été « sorti" + j.g("", "e") + " de son contexte ».")
    }

    static let phrasesChoc = [
        "Ceux qui travaillent ne doivent plus payer pour ceux qui trichent.", "L'État n'a pas à tout faire, mais il doit tout voir.",
        "Les impôts, c'est comme le sport : c'est bien pour les autres.", "On ne gouverne pas un pays avec des sondages.",
        "La République ne recule pas devant la violence.", "Il y a deux France, et je ne laisserai personne sur le bord de la route.",
        "Les élites ont oublié ceux qui se lèvent tôt.", "Je préfère perdre une élection que perdre mon honneur.",
    ]

    static func seServir(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let m = e.mandat else { return PolResultat(texte: "Tu n'as accès à aucun budget public.") }
        guard marquer("servir", &j) else { return dejaFait }
        let montant = Int(Double(m.poste.indemnite) * Double.random(in: 0.2...1.0))
        j.argent += montant
        e.casseroles += Int.random(in: 10...25)
        j.stats.karma -= 6
        return PolResultat(texte: "Tu passes \(Format.argent(montant)) de « frais de représentation ». Des notes de restaurant et un voyage difficile à justifier.")
    }

    static func demissionner(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let m = e.mandat else { return PolResultat(texte: "Tu n'as aucun mandat.") }
        terminerMandat(&j, &e, fin: "démission")
        e.popularite -= 5
        e.titres.append(remplir("Coup de tonnerre : {prenom} {nom} démissionne", j, e))
        return PolResultat(texte: "Tu démissionnes de ton poste de \(m.poste.nom(j.genre).lowercased()). Ta décision surprend jusque dans ton propre camp.")
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
        case .premierMinistre?: c += 0.08
        case .presidentRegion?: c += 0.05
        case .presidentAssemblee?: c += 0.03
        case .senateur?: c -= 0.05
        case .commissaire?, .secretaireGeneral?: c -= 0.08
        default: break
        }
        if loi.niveau == "national", e.mandat?.poste.gouverne == true {
            c += Double(e.majorite - 50) / 200
        }
        return max(0.03, min(0.95, c))
    }

    /// Proposer une loi (une par an).
    static func proposerLoi(_ id: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let loi = PolCatalogue.loi(id), loisProposables(e).contains(where: { $0.id == id }) else {
            return PolResultat(texte: "Tu ne peux pas proposer ce texte.")
        }
        guard marquer("loi", &j) else { return PolResultat(texte: "Tu as déjà proposé un texte cette année. Le calendrier parlementaire est plein.") }
        e.loisTentees.append(id)
        if Double.random(in: 0...1) < chanceAdoption(loi, e) {
            e.loisActives.append(id)
            e.loisVotees.append(id)
            if let a = loi.adoption { appliquerPol(a, &j, &e) }
            e.titres.append(remplir(loi.headline, j, e))
            if let flash = loi.monde { e.flashsMonde.append(flash) }
            if let dp = loi.adoption?.popularite, dp < 0 { e.mobilisation += -dp * 2 }
            e.borner()
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
            return PolResultat(texte: "🗑️ « \(loi.titre) » est abrogée. Le texte ne s'appliquera plus.")
        }
        e.influence -= 2
        return PolResultat(texte: "L'abrogation de « \(loi.titre) » est rejetée. La majorité n'a pas suivi.")
    }

    // MARK: - Dossiers

    /// Poste utilisé pour filtrer dossiers et scandales.
    static func posteCourant(_ e: PolEtat) -> String {
        e.mandat?.poste.rawValue ?? "militant"
    }

    /// Poste proche, pour les postes qui n'ont pas de contenu propre d'un type donné (scandales…).
    static func posteVoisin(_ e: PolEtat) -> String {
        switch e.mandat?.poste {
        case .conseillerRegional?, .presidentRegion?: return PolPoste.maire.rawValue
        case .senateur?, .presidentAssemblee?: return PolPoste.depute.rawValue
        case .premierMinistre?: return PolPoste.ministre.rawValue
        case .commissaire?, .secretaireGeneral?: return PolPoste.president.rawValue
        default: return "militant"
        }
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
        if var p = issue.pol {
            if d.kind == "scandale", let com = e.equipe.first(where: { $0.role == .com }), let dp = p.popularite, dp < 0 {
                p.popularite = dp + Int(Double(-dp) * Double(com.competence) / 200)
            }
            if d.kind == "debat", let plume = e.equipe.first(where: { $0.role == .plume }), let c = p.campagne, c > 0 {
                p.campagne = c + Double(plume.competence) / 40
            }
            appliquerPol(p, &j, &e)
        }
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
        if let dp = p.popularite, dp != 0 {
            for s in PolSegment.allCases { e.segments[s.rawValue] = Stats.borne(e.opinion(s) + dp / 2) }
        }
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
            if let flash = loi.monde { e.flashsMonde.append(flash) }
        }
        if let id = p.abroger { e.loisActives.removeAll { $0 == id } }
        appliquerPolProfond(p, &e)
        if p.exclusionParti == true, e.partiId != nil {
            e.partiId = nil
            e.influence -= 5
            ajouterLigne(&j, "Tu es " + j.g("exclu", "exclue") + " de ton parti. La décision a été prise en bureau national.")
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
        if e.estChefDeParti { t.insert("pol_chef_parti") }
        if e.mandat?.poste.gouverne == true { t.insert("pol_gouverne") }
        if e.mandat == nil && e.rangMax >= 2 { t.insert("pol_ancien") }
        for id in e.loisActives { if let tag = PolCatalogue.loi(id)?.tag { t.insert(tag) } }
        return t
    }

    /// Titres de presse politiques de l'année écoulée (à lire après `passerAnnee`, pour le Journal du monde).
    static func titresActualite(_ e: PolEtat?) -> [String] { e?.titresPublies ?? [] }

    /// Flashs du Journal du monde à publier (lois adoptées l'année écoulée), à lire après `passerAnnee`
    /// et à passer à `MondeJournal.forcer(id:etat:age:tagsJoueur:)`.
    static func flashsMonde(_ e: PolEtat?) -> [String] { e?.flashsPublies ?? [] }

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
            if let p = e.parti { return (genre == .femme ? "Militante" : "Militant") + " fidèle du \(p.nom)" }
            return nil
        }
        var t = (e.mandat?.poste == top ? "" : (genre == .femme ? "Ancienne " : "Ancien ")) + top.nom(genre).lowercased()
        t = t.prefix(1).uppercased() + t.dropFirst()
        if top == .president && e.mandatsPresident > 1 { t += " (\(e.mandatsPresident) mandats)" }
        let n = e.loisVotees.count
        if n > 0 { t += ", auteur" + (genre == .femme ? "e" : "") + " de \(n) loi\(n > 1 ? "s" : "")" }
        return t
    }

    // MARK: - Outils

    static let dejaFait = PolResultat(texte: "Tu as déjà fait ça cette année. Attends l'année prochaine.")

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
    static func payer(_ montant: Int, _ j: inout Joueur, _ e: inout PolEtat) {
        let deCaisse = min(e.caisse, montant)
        e.caisse -= deCaisse
        j.argent -= montant - deCaisse
    }

    static func terminerMandat(_ j: inout Joueur, _ e: inout PolEtat, fin: String) {
        guard let m = e.mandat else { return }
        e.historique.append(PolMandatPasse(poste: m.poste, ministereId: m.ministereId, ageDebut: m.ageDebut, ageFin: j.age, fin: fin))
        e.mandat = nil
        if m.poste == .president { e.premierMinistrePNJ = nil }
        e.dossiers.removeAll { ["dossier", "crise", "lobby"].contains(PolCatalogue.dossier($0.dossierId)?.kind ?? "") }
    }

    static func nomParti(_ e: PolEtat) -> String {
        e.parti?.nom ?? "ton parti"
    }

    static func nomMinistere(_ e: PolEtat) -> String {
        PolCatalogue.ministere(e.mandat?.ministereId)?.nom ?? "Ministère délégué"
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
        t = t.replacingOccurrences(of: "{partenaire}", with: j.relations.first { $0.type == .partenaire && $0.vivant }?.prenom ?? "ton conjoint")
        t = t.replacingOccurrences(of: "{ami}", with: j.amis.randomElement()?.prenom ?? "un ami")
        t = t.replacingOccurrences(of: "{parti}", with: e.map(nomParti) ?? "ton parti")
        t = t.replacingOccurrences(of: "{poste}", with: e?.mandat?.poste.nom(j.genre).lowercased() ?? j.g("militant", "militante"))
        t = t.replacingOccurrences(of: "{adversaire}", with: e?.candidature?.adversaire ?? "ton adversaire")
        t = t.replacingOccurrences(of: "{ministere}", with: e.map(nomMinistere) ?? "ton ministère")
        t = t.replacingOccurrences(of: "{rival}", with: e?.rivalPrincipal?.nomComplet ?? "ton vieux rival")
        t = t.replacingOccurrences(of: "{pm}", with: e?.premierMinistrePNJ?.nomComplet ?? "le Premier ministre")
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

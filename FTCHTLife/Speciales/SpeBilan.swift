import Foundation

// Bilan de l'année (pop-up au passage d'année) : une section par carrière, musée, investissements et emploi.
// Voir docs/CARRIERES_SPECIALES.md, section « Bilan de l'année ».

extension SpeMoteur {

    // MARK: - Outils

    private static let formateurNombre: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f
    }()

    static func nb(_ n: Int) -> String {
        formateurNombre.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// « 62 (+8) », « 40 (−3) » ou « 62 ».
    static func avecEcart(_ valeur: Int, _ avant: Int?, format: (Int) -> String = { SpeMoteur.nb($0) }) -> String {
        guard let a = avant, a != valeur else { return format(valeur) }
        let d = valeur - a
        return "\(format(valeur)) (\(d > 0 ? "+" : "−")\(format(abs(d))))"
    }

    static func ton(_ valeur: Int, _ avant: Int?) -> Int {
        guard let a = avant else { return 0 }
        return valeur > a ? 1 : (valeur < a ? -1 : 0)
    }

    /// Valeurs au début de l'année, pour les écarts du bilan suivant.
    static func instantane(_ c: SpeCarriere) -> [String: Int] {
        ["rep": c.reputation, "niveau": c.niveau, "gains": c.gainsTotal, "fans": c.fans, "abonnes": c.abonnes,
         "campagnes": c.campagnes, "defiles": c.defiles, "victoires": c.victoires, "defaites": c.defaites, "ko": c.ko,
         "titres": c.titres, "selections": c.selections, "albums": c.albums.count, "films": c.films.count]
    }

    /// Écoutes en streaming estimées (0,004 € l'écoute).
    static func ecoutes(_ c: SpeCarriere) -> Int {
        Int(Double(c.fans) * 0.4 * (1 + 0.1 * Double(c.albums.count)) / 0.004)
    }

    // MARK: - Carrière spéciale

    static func sectionCarriere(_ c: SpeCarriere, _ j: Joueur, lignesAnnee: [String], fin: Bool) -> SpeBilanSection {
        let f = femme(j)
        let av = c.instantane
        let rang = SpeCatalogue.rang(c, femme: f)
        var s = SpeBilanSection(emoji: c.type == .sport ? SpeCatalogue.sport(c.sport).emoji : c.type.emoji,
                                titre: c.type.nom(f), sousTitre: rang)
        var lignes: [SpeBilanLigne] = []
        let promu = (av?["niveau"]).map { c.niveau > $0 } ?? false
        let retrograde = (av?["niveau"]).map { c.niveau < $0 } ?? false
        lignes.append(SpeBilanLigne(emoji: "⭐️", libelle: "Rang", valeur: rang + (promu ? " (promotion !)" : (retrograde ? " (en baisse)" : "")),
                                    ton: promu ? 1 : (retrograde ? -1 : 0)))
        lignes.append(SpeBilanLigne(emoji: "📈", libelle: "Réputation", valeur: avecEcart(c.reputation, av?["rep"]), ton: ton(c.reputation, av?["rep"])))
        if let g0 = av?["gains"] {
            let g = c.gainsTotal - g0
            lignes.append(SpeBilanLigne(emoji: "💶", libelle: "Gagné cette année", valeur: Format.argent(g), ton: g > 0 ? 1 : 0))
        }

        switch c.type {
        case .mma:
            let v = c.victoires - (av?["victoires"] ?? c.victoires)
            let d = c.defaites - (av?["defaites"] ?? c.defaites)
            s.grosChiffre = "\(v) V – \(d) D"
            s.grosLibelle = v + d == 0 ? "Aucun combat cette année" : "Combats de l'année"
            lignes.append(SpeBilanLigne(emoji: "📋", libelle: "Palmarès", valeur: "\(c.victoires) V – \(c.defaites) D (\(c.ko) avant la limite)"))
            lignes.append(SpeBilanLigne(emoji: "⚡️", libelle: "Forme", valeur: "\(c.forme)/100"))
            if c.ceintures > 0 { lignes.append(SpeBilanLigne(emoji: "🏆", libelle: "Combats de titre gagnés", valeur: "\(c.ceintures)", ton: 1)) }
            if c.blessure > 0 { lignes.append(SpeBilanLigne(emoji: "🩹", libelle: "Blessure", valeur: "\(c.blessure) an\(c.blessure > 1 ? "s" : "") d'arrêt", ton: -1)) }
            if c.commotions >= 2 { lignes.append(SpeBilanLigne(emoji: "🧠", libelle: "Commotions", valeur: "\(c.commotions)", ton: -1)) }

        case .sport:
            s.grosChiffre = c.performance > 0 ? "\(c.performance)/100" : "—"
            s.grosLibelle = c.performance > 0 ? "Note de la saison" : "Saison blanche"
            lignes.append(SpeBilanLigne(emoji: "🛡️", libelle: SpeCatalogue.sport(c.sport).collectif ? "Club" : "Équipe", valeur: c.club))
            lignes.append(SpeBilanLigne(emoji: "🏆", libelle: "Titres", valeur: avecEcart(c.titres, av?["titres"]), ton: ton(c.titres, av?["titres"])))
            lignes.append(SpeBilanLigne(emoji: "🎽", libelle: "Sélections nationales", valeur: avecEcart(c.selections, av?["selections"]), ton: ton(c.selections, av?["selections"])))
            lignes.append(SpeBilanLigne(emoji: "👥", libelle: "Fans", valeur: avecEcart(c.fans, av?["fans"]), ton: ton(c.fans, av?["fans"])))
            if c.blessure > 0 { lignes.append(SpeBilanLigne(emoji: "🩹", libelle: "Blessure", valeur: "\(c.blessure) an\(c.blessure > 1 ? "s" : "") d'arrêt", ton: -1)) }

        case .mannequin:
            let camp = c.campagnes - (av?["campagnes"] ?? c.campagnes)
            let def = c.defiles - (av?["defiles"] ?? c.defiles)
            s.grosChiffre = nb(c.abonnes)
            s.grosLibelle = "Abonnés"
            lignes.append(SpeBilanLigne(emoji: "🏢", libelle: "Agence", valeur: c.agence))
            lignes.append(SpeBilanLigne(emoji: "📸", libelle: "Campagnes cette année", valeur: "\(camp)", ton: camp > 0 ? 1 : 0))
            lignes.append(SpeBilanLigne(emoji: "👠", libelle: "Défilés cette année", valeur: "\(def)", ton: def > 0 ? 1 : 0))
            lignes.append(SpeBilanLigne(emoji: "📱", libelle: "Abonnés", valeur: avecEcart(c.abonnes, av?["abonnes"]), ton: ton(c.abonnes, av?["abonnes"])))
            lignes.append(SpeBilanLigne(emoji: "✨", libelle: "Apparence", valeur: "\(j.stats.apparence)/100"))

        case .cinema:
            let nouveaux = c.films.count - (av?["films"] ?? c.films.count)
            if nouveaux > 0, let film = c.films.last {
                if film.taille == 0 {
                    s.grosChiffre = "\(film.critique)/100"
                    s.grosLibelle = "« \(film.titre) » (court-métrage) : score de la critique"
                } else {
                    s.grosChiffre = "\(nb(film.recettes / 9)) entrées"
                    s.grosLibelle = "« \(film.titre) » est sorti"
                    lignes.append(SpeBilanLigne(emoji: "🎟️", libelle: "Vues en salle et en ligne", valeur: nb(film.recettes / 9 + film.recettes / 30)))
                    lignes.append(SpeBilanLigne(emoji: "📝", libelle: "Score de la critique", valeur: "\(film.critique)/100",
                                                ton: film.critique >= 65 ? 1 : (film.critique < 45 ? -1 : 0)))
                    lignes.append(SpeBilanLigne(emoji: "💰", libelle: "Recettes", valeur: Format.argent(film.recettes),
                                                ton: film.recettes >= film.budget ? 1 : -1))
                    lignes.append(SpeBilanLigne(emoji: "🧾", libelle: "Budget", valeur: Format.argent(film.budget) + (film.autoFinance ? " (tes fonds)" : " (producteur)")))
                }
                for p in film.prix { s.faits.append("🏆 \(p)") }
            } else if let p = c.projet {
                s.grosChiffre = "En tournage"
                s.grosLibelle = "« \(p.titre) » sort l'an prochain"
            } else {
                s.grosChiffre = "Pas de film"
                s.grosLibelle = "Écris un scénario et lance un tournage"
            }
            lignes.append(SpeBilanLigne(emoji: "🎞️", libelle: "Filmographie", valeur: "\(c.films.count) film\(c.films.count > 1 ? "s" : "")"))

        case .musique:
            s.grosChiffre = nb(ecoutes(c))
            s.grosLibelle = "Écoutes en streaming"
            lignes.append(SpeBilanLigne(emoji: "👥", libelle: "Fans", valeur: avecEcart(c.fans, av?["fans"]), ton: ton(c.fans, av?["fans"])))
            let nouveaux = c.albums.count - (av?["albums"] ?? c.albums.count)
            if nouveaux > 0, let a = c.albums.last {
                lignes.append(SpeBilanLigne(emoji: "💿", libelle: "Album « \(a.titre) »", valeur: "note \(a.note)/100, \(nb(a.ventes)) ventes",
                                            ton: a.note >= 65 ? 1 : (a.note < 45 ? -1 : 0)))
                if let cert = a.certification { s.faits.append("🏆 \(cert) pour « \(a.titre) »") }
            }
            lignes.append(SpeBilanLigne(emoji: "🏷️", libelle: "Label", valeur: c.label.isEmpty ? "Indépendant" : c.label))
            lignes.append(SpeBilanLigne(emoji: "✍️", libelle: "Chansons en stock", valeur: "\(c.chansons)"))
        }

        s.lignes = lignes
        s.faits = (c.faits ?? []) + s.faits + lignesAnnee.filter { l in
            ["🏆", "⭐️", "🩹", "📉", "✉️", "🎽", "🧠"].contains { l.hasPrefix($0) }
        }
        if fin { s.sousTitre = rang + " · fin de carrière" }
        return s
    }

    /// Marqueurs posés par le bilan (cartes de réaction de l'année).
    static func marqueursCarriere(_ c: SpeCarriere, _ j: Joueur) -> [String] {
        var m: [String] = []
        let av = c.instantane
        if let n = av?["niveau"] {
            if c.niveau > n { m.append("promotion") }
            if c.niveau < n { m.append("retrogradation") }
        }
        if let r = av?["rep"], c.reputation - r <= -8 { m.append("reputation_baisse") }
        if c.blessure > 0 { m.append("blessure") }
        switch c.type {
        case .mma:
            if c.victoires + c.defaites == (av?["victoires"] ?? 0) + (av?["defaites"] ?? 0) && c.annees > 1 { m.append("inactif") }
        case .sport:
            if c.performance >= 80 { m.append("saison_top") }
            if c.performance > 0 && c.performance < 35 { m.append("saison_ratee") }
            if let t = av?["titres"], c.titres > t { m.append("titre") }
            if let s = av?["selections"], c.selections > s { m.append("selection") }
        case .mannequin:
            if let x = av?["campagnes"], c.campagnes - x >= 1 { m.append("campagne") }
            if j.stats.apparence < 45 { m.append("baisse") }
        case .cinema:
            let nouveaux = c.films.count - (av?["films"] ?? c.films.count)
            if nouveaux > 0, let f = c.films.last {
                if f.taille == 0 {
                    m.append(f.prix.isEmpty ? "court_sorti" : "court_prix")
                } else {
                    if f.recettes > f.budget * 2 { m.append("film_succes") }
                    else if f.recettes < f.budget / 2 { m.append("film_flop") }
                    else { m.append("film_moyen") }
                    if !f.prix.isEmpty { m.append("film_prix") }
                    if f.critique >= 75 { m.append("critique_bonne") }
                    if f.critique < 40 { m.append("critique_mauvaise") }
                }
            } else if c.projet == nil && c.annees > 1 {
                m.append("sans_film")
            }
        case .musique:
            let nouveaux = c.albums.count - (av?["albums"] ?? c.albums.count)
            if nouveaux > 0, let a = c.albums.last {
                if a.certification != nil { m.append("album_certifie") }
                if a.note >= 75 { m.append("album_succes") }
                if a.note < 45 { m.append("album_flop") }
            }
            if let f = av?["fans"], c.fans < f { m.append("fans_baisse") }
            if !c.offreLabel.isEmpty { m.append("offre_label") }
        }
        return m
    }

    // MARK: - Musée

    static func sectionMusee(_ m: SpeMusee) -> SpeBilanSection {
        var s = SpeBilanSection(emoji: "🖼️", titre: m.nom, sousTitre: "\(SpeCatalogue.taillesMusee[min(3, m.taille)]) · \(SpeCatalogue.nomTheme(m.theme))")
        s.grosChiffre = nb(m.visiteursAn)
        s.grosLibelle = "Visiteurs"
        let valeur = m.collection.reduce(0) { $0 + $1.valeur }
        s.lignes = [
            SpeBilanLigne(emoji: "👥", libelle: "Visiteurs", valeur: avecEcart(m.visiteursAn, (m.visiteursAvant ?? 0) > 0 ? m.visiteursAvant : nil),
                          ton: ton(m.visiteursAn, (m.visiteursAvant ?? 0) > 0 ? m.visiteursAvant : nil)),
            SpeBilanLigne(emoji: "💶", libelle: m.resultatAn >= 0 ? "Bénéfice" : "Perte", valeur: Format.argent(abs(m.resultatAn)),
                          ton: m.resultatAn >= 0 ? 1 : -1),
            SpeBilanLigne(emoji: "👑", libelle: "Prestige", valeur: avecEcart(m.prestige, m.prestigeAvant), ton: ton(m.prestige, m.prestigeAvant)),
            SpeBilanLigne(emoji: "📣", libelle: "Notoriété", valeur: "\(m.notoriete)/100"),
            SpeBilanLigne(emoji: "🖼️", libelle: "Collection", valeur: "\(m.collection.count) œuvres, \(Format.argent(valeur))"),
        ]
        return s
    }

    // MARK: - Investissements

    static func sectionInvest(_ e: SpeEtat, avant: [UUID: Int]) -> (section: SpeBilanSection, marqueurs: [String]) {
        var s = SpeBilanSection(emoji: "💰", titre: "Investissements", sousTitre: "\(avant.count) projet\(avant.count > 1 ? "s" : "") suivi\(avant.count > 1 ? "s" : "")")
        var total = 0
        var marqueurs: [String] = []
        for inv in e.investissements {
            guard let v0 = avant[inv.id] else { continue }
            total += inv.valeur - v0
            let pct = v0 > 0 ? (inv.valeur - v0) * 100 / v0 : 0
            let valeur = inv.termine ? "terminé : \(Format.argent(inv.valeur))" : "\(Format.argent(inv.valeur)) (\(pct >= 0 ? "+" : "−")\(abs(pct)) %)"
            s.lignes.append(SpeBilanLigne(emoji: inv.type.emoji, libelle: inv.nom, valeur: valeur, ton: inv.valeur >= v0 ? 1 : -1))
            if !inv.dernier.isEmpty { s.faits.append(inv.dernier) }
            if pct >= 50 { marqueurs.append("invest_succes") }
            if pct <= -40 { marqueurs.append("invest_echec") }
        }
        s.grosChiffre = (total >= 0 ? "+" : "−") + Format.argent(abs(total))
        s.grosLibelle = "Variation de la valeur de tes parts"
        return (s, marqueurs)
    }

    // MARK: - Emploi normal

    static func sectionMetier(_ em: Emploi, _ j: Joueur, avant: SpeMetierInstantane?) -> SpeBilanSection {
        let entreprise = j.carriere?.company ?? ""
        var s = SpeBilanSection(emoji: "💼", titre: em.titre, sousTitre: entreprise.isEmpty ? "Ton travail" : entreprise)
        s.grosChiffre = Format.argent(em.salaire)
        s.grosLibelle = "Salaire annuel"
        let memePoste = avant?.titre == em.titre
        let perf = j.carriere?.performance ?? em.performance
        s.lignes.append(SpeBilanLigne(emoji: "💶", libelle: "Salaire", valeur: avecEcart(em.salaire, memePoste ? avant?.salaire : nil, format: { Format.argent($0) }),
                                      ton: memePoste ? ton(em.salaire, avant?.salaire) : 0))
        s.lignes.append(SpeBilanLigne(emoji: "📊", libelle: "Performance", valeur: avecEcart(perf, memePoste ? avant?.performance : nil) + "/100",
                                      ton: memePoste ? ton(perf, avant?.performance) : 0))
        let anciennete = j.carriere?.yearsInJob ?? em.annees
        s.lignes.append(SpeBilanLigne(emoji: "🗓️", libelle: "Ancienneté", valeur: "\(anciennete) an\(anciennete > 1 ? "s" : "")"))
        if let cj = j.carriere {
            s.lignes.append(SpeBilanLigne(emoji: "🤝", libelle: "Relation avec ton chef", valeur: "\(cj.bossRelation)/100",
                                          ton: cj.bossRelation >= 60 ? 1 : (cj.bossRelation < 35 ? -1 : 0)))
        }
        if let a = avant {
            if a.titre != em.titre {
                s.faits.append(a.entreprise == entreprise && !entreprise.isEmpty ? "⭐️ Promotion : tu deviens \(em.titre.lowercased()) !" : "🆕 Nouveau poste : \(em.titre.lowercased()).")
            } else if em.salaire > a.salaire * 105 / 100 {
                s.faits.append("💶 Augmentation de \(Format.argent(em.salaire - a.salaire)) par an.")
            }
        } else {
            s.faits.append("🆕 Première année à ce poste.")
        }
        if perf < 30 { s.faits.append("⚠️ Ta performance inquiète ta hiérarchie.") }
        return s
    }
}

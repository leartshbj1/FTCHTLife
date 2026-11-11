import Foundation

/// Logique des carrières spéciales, de la salle de sport, du musée et des investissements.
/// Les fonctions ici ne touchent qu'au joueur passé en paramètre (le moteur fait la sauvegarde et le journal).
enum SpeMoteur {
    static let prefixe = "spe:"
    static let ageMinSalle = 14

    // MARK: - Petits outils

    static func borne(_ v: Int) -> Int { min(100, max(0, v)) }

    static func bornerSalle(_ e: inout SpeEtat) {
        e.force = borne(e.force)
        e.technique = borne(e.technique)
        e.cardio = borne(e.cardio)
    }

    static func borner(_ c: inout SpeCarriere) {
        c.reputation = borne(c.reputation)
        c.forme = borne(c.forme)
        c.niveau = min(5, max(0, c.niveau))
        c.fans = max(0, c.fans)
        c.abonnes = max(0, c.abonnes)
    }

    static func gagner(_ montant: Int, _ j: inout Joueur) {
        j.argent = Shkurtaaa.argent(j.argent + montant)
    }

    static func femme(_ j: Joueur) -> Bool { j.genre == .femme }

    /// Une carrière spéciale devient un temps plein dès le rang 1.
    static func pleinTemps(_ c: SpeCarriere) -> Bool { c.niveau >= 1 }

    static func titre(_ c: SpeCarriere, _ j: Joueur) -> String {
        let f = femme(j)
        switch c.type {
        case .sport: return "\(f ? "Sportive" : "Sportif") (\(SpeCatalogue.sport(c.sport).nom.lowercased()), \(SpeCatalogue.rang(c, femme: f).lowercased()))"
        default: return "\(c.type.nom(f)) (\(SpeCatalogue.rang(c, femme: f).lowercased()))"
        }
    }

    /// Talent sportif (0-100) selon les stats de salle, la santé et la compétence « sport ».
    static func talent(_ e: SpeEtat, sport: String, _ j: Joueur) -> Int {
        let s = SpeCatalogue.sport(sport)
        let base = Double(e.force) * s.poids.0 + Double(e.cardio) * s.poids.1 + Double(e.technique) * s.poids.2
        let bonus = Double(Competences.niveau("sport", j) * 6) + Double(j.stats.sante - 50) / 5
        return borne(Int(base + bonus))
    }

    /// Puissance de combat (sans hasard), pour l'affichage.
    static func puissance(_ e: SpeEtat) -> Int {
        borne(Int(Double(e.force) * 0.3 + Double(e.technique) * 0.4 + Double(e.cardio) * 0.3))
    }

    // MARK: - Tags

    static func tags(_ e: SpeEtat?) -> Set<String> {
        guard let e = e else { return [] }
        var t: Set<String> = []
        if let c = e.carriere {
            t.insert("spe_" + c.type.rawValue)
            if c.niveau >= 4 { t.insert("spe_star") }
            if c.type == .sport { t.insert("spe_sport_" + c.sport) }
        }
        for a in e.anciennes { t.insert("spe_ancien_" + a.type.rawValue) }
        if e.musee != nil { t.insert("proprio_musee") }
        if e.investissements.contains(where: { !$0.termine }) { t.insert("investisseur") }
        if e.investissements.contains(where: { !$0.termine && $0.type == .club }) { t.insert("president_club") }
        if e.abonnement > 0 { t.insert("salle_sport") }
        if e.force >= 60 { t.insert("costaud") }
        return t
    }

    // MARK: - Commencer une carrière

    static func blocageDebut(_ t: SpeCarriereType, _ j: Joueur) -> String? {
        let e = j.speciales ?? SpeEtat()
        if let c = e.carriere { return "Tu es déjà \(titre(c, j).lowercased()). Une carrière à la fois." }
        if j.vieEtat.justice.enPrison { return "Tu es en prison. Les recruteurs ne font pas les parloirs." }
        switch t {
        case .mma:
            if j.age < 16 { return "Dès 16 ans, avec l'accord des parents. Pour l'instant, la salle." }
            if j.age > 40 { return "À \(j.age) ans, aucune fédération ne te délivrera de licence pour un premier combat." }
            if e.force < 30 || e.technique < 30 {
                return "Il faut au moins 30 en force et 30 en technique (tu as \(e.force) et \(e.technique)). Va à la salle et prends des cours de boxe."
            }
            if j.stats.sante < 40 { return "Le médecin refuse ton certificat : santé trop fragile." }
        case .sport:
            if j.age < 14 { return "Les essais en centre de formation commencent à 14 ans." }
            if j.age > 27 { return "À \(j.age) ans, les clubs ne recrutent plus de débutants." }
            if j.stats.sante < 50 { return "Il faut une santé d'au moins 50 pour passer les tests physiques." }
        case .mannequin:
            if j.age < 16 { return "Dès 16 ans." }
            if j.age > 35 { return "Les agences ne prennent plus de débutants à \(j.age) ans. Injuste, mais c'est le milieu." }
            if j.stats.apparence < 55 { return "Les agences demandent une apparence d'au moins 55 (tu as \(j.stats.apparence))." }
        case .cinema:
            if j.age < 16 { return "Dès 16 ans. En attendant, filme ton chat." }
        case .musique:
            if j.age < 12 { return "Dès 12 ans. Pour l'instant, la flûte à bec." }
        }
        return nil
    }

    /// Chance de réussir les essais d'un club (sport).
    static func chanceEssais(_ e: SpeEtat, sport: String, _ j: Joueur) -> Double {
        let t = Double(talent(e, sport: sport, j))
        let age = j.age <= 18 ? 0.0 : Double(j.age - 18) * 0.04
        return min(0.9, max(0.05, (t - 25) / 50 - age))
    }

    /// Chance qu'une agence réponde (mannequin).
    static func chanceAgence(_ j: Joueur) -> Double {
        min(0.9, max(0.1, Double(j.stats.apparence - 45) / 40))
    }

    // MARK: - Passage d'année

    struct Bilan {
        var lignes: [String] = []
        var signaux: [String] = []
    }

    static func passerAnnee(_ j: inout Joueur) -> Bilan {
        guard var e = j.speciales else { return Bilan() }
        var b = Bilan()
        e.actionsSalle = []

        // Salle de sport
        if e.abonnement > 0 {
            let prix = SpeCatalogue.prixAbonnement[min(3, e.abonnement)]
            if j.argent < prix && !Shkurtaaa.actif {
                b.lignes.append("🏋️ Prélèvement refusé : \(e.salleNom) résilie ton abonnement.")
                e.abonnement = 0
            } else {
                gagner(-prix, &j)
            }
        }
        let sportif = e.carriere.map { $0.type == .mma || $0.type == .sport } ?? false
        if e.abonnement == 0 && !sportif {
            e.force -= 2
            e.cardio -= 2
            e.technique -= 1
        }
        if j.age > 35 {
            e.cardio -= 1
            e.force -= j.age > 50 ? 2 : 1
        }
        bornerSalle(&e)

        // Carrière
        if var c = e.carriere {
            c.annees += 1
            c.bilan = []
            var fin: String? = nil
            switch c.type {
            case .mma: anneeMMA(&c, &e, &j, &b, &fin)
            case .sport: anneeSport(&c, &e, &j, &b, &fin)
            case .mannequin: anneeMannequin(&c, &j, &b)
            case .cinema: anneeCinema(&c, &j, &b)
            case .musique: anneeMusique(&c, &j, &b)
            }
            c.actionsAnnee = []
            borner(&c)
            e.carriere = c
            if let raison = fin {
                b.lignes.append(terminer(&e, j, raison: raison))
                b.signaux.append("spe_fin_carriere")
            }
        }

        // Musée
        if var m = e.musee {
            anneeMusee(&m, &j, &b)
            e.musee = m
        }

        // Investissements
        anneeInvestissements(&e, &j, &b)

        bornerSalle(&e)
        j.speciales = e
        return b
    }

    /// Montée de rang : ligne du journal et signaux.
    static func promotion(_ c: inout SpeCarriere, _ j: Joueur, _ b: inout Bilan, texte: String) {
        c.niveau = min(5, c.niveau + 1)
        let rang = SpeCatalogue.rang(c, femme: femme(j))
        c.palmares.append("\(rang) à \(j.age) ans")
        b.lignes.append("⭐️ " + texte)
        b.signaux.append("spe_promotion")
        if c.niveau >= 4 { b.signaux.append("celebrite") }
    }

    // MARK: MMA

    static func anneeMMA(_ c: inout SpeCarriere, _ e: inout SpeEtat, _ j: inout Joueur, _ b: inout Bilan, _ fin: inout String?) {
        if c.blessure > 0 {
            c.blessure -= 1
            b.lignes.append(c.blessure > 0 ? "🩹 Toujours en convalescence. Kiné trois fois par semaine." : "🩹 Ta blessure est guérie. Retour sur les tapis.")
        } else if c.combatsAnnee == 0 && c.annees > 1 {
            c.reputation -= 4
            b.lignes.append("🥊 Aucun combat cette année : dans le milieu, on t'oublie vite.")
        }
        if c.niveau >= 1 {
            let sponsors = SpeCatalogue.revenu(.mma, c.niveau) * c.reputation / 250
            if sponsors > 0 {
                gagner(sponsors, &j)
                c.gainsTotal += sponsors
                b.lignes.append("🥊 Sponsors et apparitions : \(Format.argent(sponsors)).")
            }
        }
        c.forme += 30
        if j.age >= 34 {
            c.forme -= (j.age - 32) * 2
            e.cardio -= 2
        }
        if c.commotions >= 4 {
            j.stats.intelligence -= 2
            j.stats.sante -= 3
            b.lignes.append("🧠 Maux de tête, trous de mémoire : les médecins te parlent de commotions à répétition.")
        }
        c.combatsAnnee = 0
        if j.age >= 45 {
            fin = "âge"
        }
    }

    struct ResultatCombat {
        var texte: String
        var gagne: Bool
        var signaux: [String]
    }

    static let nomsDifficulte = ["Un adversaire à ta portée", "Un adversaire coriace", "La tête d'affiche", "Combat pour la ceinture"]
    static let nomsStrategie = ["Debout : pieds-poings", "Au sol : lutte et soumissions", "Prudent : aux points"]

    /// Combat. `difficulte` 0-3 (3 = titre), `strategie` 0 debout, 1 sol, 2 prudent.
    static func combattre(_ c: inout SpeCarriere, _ e: inout SpeEtat, _ j: inout Joueur, difficulte: Int, strategie: Int) -> ResultatCombat {
        let adv = SpeCatalogue.adversaire(j.age &* 7 &+ c.victoires &+ c.defaites &* 3 &+ difficulte)
        let ligue = SpeCatalogue.ligues[c.niveau]
        var p = Double(e.force) * 0.3 + Double(e.technique) * 0.4 + Double(e.cardio) * 0.3
        p *= 0.7 + Double(c.forme) / 333
        switch strategie {
        case 0: p += Double(e.force) * 0.08
        case 1: p += Double(e.technique) * 0.08
        default: p += Double(e.cardio) * 0.05
        }
        if j.age > 32 { p -= Double(j.age - 32) * 1.5 }
        p += Double(Competences.niveau("sport", j) * 2)
        p += Double.random(in: -14...14)
        let o = 22 + Double(c.niveau) * 11 + Double(min(3, difficulte)) * 8 + Double.random(in: -14...14)
        let marge = p - o
        let gagne = marge > 0
        var signaux: [String] = []

        // Façon de finir
        let methode: String
        if gagne {
            if marge > 18 { methode = strategie == 1 ? "soumission" : "KO" }
            else if marge > 9 && strategie != 2 { methode = Bool.random() ? "KO" : "soumission" }
            else { methode = "décision" }
        } else {
            if marge < -16 { methode = strategie == 1 ? "soumission" : "KO" }
            else if marge < -9 { methode = Bool.random() ? "KO" : "soumission" }
            else { methode = "décision" }
        }
        let round = methode == "décision" ? 3 : Int.random(in: 1...3)

        // Récit
        var recit = "🥊 \(ligue). Face à toi : \(adv). "
        let debuts = ["Le premier round sert à se jauger : jabs, feintes, le public siffle un peu.",
                      "Dès la cloche, il fonce. Tu encaisses un crochet qui fait trembler tes jambes.",
                      "Tu prends le centre de la cage et tu imposes ton rythme.",
                      "Il te plaque contre le grillage. Tu sens chaque seconde passer.",
                      "Tu touches le premier, une droite sèche qui lui ouvre l'arcade."]
        recit += debuts.randomElement() ?? ""
        recit += " "
        if gagne {
            switch methode {
            case "KO": recit += "Au \(round == 1 ? "1er" : "\(round)e") round, ton enchaînement passe. Il s'effondre. L'arbitre arrête tout. Victoire par KO !"
            case "soumission": recit += "Au \(round == 1 ? "1er" : "\(round)e") round, tu prends son dos et serres l'étranglement. Il tape. Victoire par soumission !"
            default: recit += "Trois rounds durs, aucun ne lâche. Les juges te donnent la victoire aux points."
            }
        } else {
            switch methode {
            case "KO": recit += "Au \(round == 1 ? "1er" : "\(round)e") round, tu ne vois pas partir le coup. Tu te réveilles avec le médecin au-dessus de toi. Défaite par KO."
            case "soumission": recit += "Au \(round == 1 ? "1er" : "\(round)e") round, il te prend une clé de bras. Tu tapes avant la casse. Défaite par soumission."
            default: recit += "Combat serré. Les juges lèvent son bras. Défaite aux points, et tu n'es pas d'accord."
            }
        }

        // Bourse
        let facteurs = [0.2, 0.3, 0.45, 0.8]
        var bourse = Int(Double(SpeCatalogue.revenu(.mma, c.niveau)) * facteurs[min(3, difficulte)])
        if gagne { bourse *= 2 }
        if c.niveau == 0 { bourse = gagne ? 400 : 200 }
        gagner(bourse, &j)
        c.gainsTotal += bourse
        recit += " Bourse : \(Format.argent(bourse))."

        c.combatsAnnee += 1
        c.forme -= 25
        if gagne {
            c.victoires += 1
            if methode != "décision" { c.ko += 1 }
            c.serie = c.serie > 0 ? c.serie + 1 : 1
            c.reputation += 3 + min(3, difficulte) * 3 + (methode == "décision" ? 0 : 3)
            j.stats.bonheur += 8
            signaux.append("spe_victoire")
        } else {
            c.defaites += 1
            c.serie = c.serie < 0 ? c.serie - 1 : -1
            c.reputation -= max(1, 4 - min(3, difficulte)) + (methode == "KO" ? 3 : 0)
            j.stats.bonheur -= 8
            j.stats.sante -= methode == "KO" ? 12 : 5
            if methode == "KO" {
                c.commotions += 1
                j.stats.intelligence -= 1
            }
            signaux.append("spe_defaite")
        }
        // Blessure
        var risque = [0.15, 0.10, 0.06][min(2, strategie)]
        if !gagne { risque += 0.10 }
        if Double.random(in: 0...1) < risque {
            c.blessure = Double.random(in: 0...1) < 0.25 ? 2 : 1
            j.stats.sante -= 10
            recit += " Bilan médical : " + ["main cassée", "ligaments du genou touchés", "fracture de l'orbite", "côtes fêlées"].randomElement()!
                + ". Arrêt de \(c.blessure) an\(c.blessure > 1 ? "s" : "")."
        }

        // Titre
        if difficulte == 3 {
            if gagne {
                c.ceintures += 1
                if c.niveau == 4 {
                    c.niveau = 5
                    c.palmares.append("Ceinture mondiale à \(j.age) ans")
                    recit += " 🏆 La ceinture est à toi. \(femme(j) ? "Championne" : "Champion") du monde."
                    signaux.append("celebrite")
                } else {
                    c.palmares.append("Défense de titre réussie à \(j.age) ans")
                    recit += " 🏆 Tu gardes la ceinture."
                }
                c.reputation += 6
            } else if c.niveau == 5 {
                c.niveau = 4
                recit += " La ceinture change de taille."
            }
        } else if gagne && c.niveau < 4 && c.serie >= 2 && c.reputation >= SpeCatalogue.seuilsReputation[c.niveau + 1] {
            c.niveau += 1
            let r = SpeCatalogue.rang(c, femme: femme(j))
            c.palmares.append("\(r) à \(j.age) ans")
            recit += " ⭐️ Un contrat t'attend : tu passes \(r.lowercased()) (\(SpeCatalogue.ligues[c.niveau]))."
            signaux.append("spe_promotion")
            if c.niveau >= 4 { signaux.append("celebrite") }
        } else if !gagne && c.serie <= -3 && c.niveau >= 1 && c.niveau <= 4 {
            c.niveau -= 1
            c.serie = 0
            recit += " Trois défaites de suite : la ligue ne renouvelle pas ton contrat. Retour à l'échelon du dessous."
        }
        borner(&c)
        return ResultatCombat(texte: recit, gagne: gagne, signaux: signaux)
    }

    /// Le combat pour la ceinture est-il proposé ?
    static func titreDisponible(_ c: SpeCarriere) -> Bool {
        c.niveau == 5 || (c.niveau == 4 && c.serie >= 2 && c.reputation >= 80)
    }

    // MARK: Sport

    static func anneeSport(_ c: inout SpeCarriere, _ e: inout SpeEtat, _ j: inout Joueur, _ b: inout Bilan, _ fin: inout String?) {
        let sp = SpeCatalogue.sport(c.sport)
        if c.blessure > 0 {
            c.blessure -= 1
            c.performance = 0
            let salaire = SpeCatalogue.revenu(.sport, c.niveau) / 2
            gagner(salaire, &j)
            c.gainsTotal += salaire
            b.lignes.append("🩹 Saison blanche à cause de ta blessure. \(c.club) te verse la moitié de ton salaire : \(Format.argent(salaire)).")
        } else {
            let t = talent(e, sport: c.sport, j)
            var perf = Double(t) * 0.6 + Double(c.forme) * 0.3 + Double.random(in: -15...20)
            if j.age > 30 { perf -= Double(j.age - 30) * 2 }
            if c.actionsAnnee.contains("entrainement") { perf += 4 }
            let p = borne(Int(perf))
            c.performance = p
            let salaire = Int(Double(SpeCatalogue.revenu(.sport, c.niveau)) * (0.6 + Double(p) / 100))
            gagner(salaire, &j)
            c.gainsTotal += salaire
            let appreciation: String
            switch p {
            case 80...: appreciation = "Saison exceptionnelle"
            case 60..<80: appreciation = "Bonne saison"
            case 40..<60: appreciation = "Saison correcte"
            default: appreciation = "Saison ratée"
            }
            b.lignes.append("\(sp.emoji) \(appreciation) avec \(c.club) (note \(p)/100). Salaire : \(Format.argent(salaire)).")
            c.reputation += (p - 50) / 5
            if p >= 75 && Double.random(in: 0...1) < 0.25 + Double(p - 75) / 50 {
                c.titres += 1
                c.reputation += 8
                let titre = sp.collectif ? "Titre de champion avec \(c.club)" : "Victoire majeure sur \(sp.competition)"
                c.palmares.append("\(titre) à \(j.age) ans")
                b.lignes.append("🏆 \(titre) !")
                j.stats.bonheur += 10
                b.signaux.append("spe_titre")
            }
            if c.niveau >= 2 && p >= 72 && Double.random(in: 0...1) < 0.5 {
                c.selections += 1
                c.reputation += 4
                if c.selections == 1 {
                    c.palmares.append("Première sélection nationale à \(j.age) ans")
                    b.lignes.append("🎽 Première sélection en équipe nationale. Tu chantes l'hymne en tremblant.")
                }
            }
            var risque = 0.07 + (j.age > 30 ? 0.05 : 0)
            if c.actionsAnnee.contains("preparateur") { risque -= 0.04 }
            if e.abonnement == 3 { risque -= 0.01 }
            if Double.random(in: 0...1) < risque {
                c.blessure = Double.random(in: 0...1) < 0.25 ? 2 : 1
                j.stats.sante -= 10
                b.lignes.append("🩹 Blessure en fin de saison : " + ["rupture des ligaments croisés", "fracture de fatigue", "déchirure musculaire", "épaule luxée"].randomElement()! + ".")
            }
            if p < 35 {
                c.saisonsRatees += 1
                if c.saisonsRatees >= 2 && c.niveau > 0 {
                    c.niveau -= 1
                    c.saisonsRatees = 0
                    c.club = SpeCatalogue.club(c.sport, niveau: c.niveau, cle: j.age)
                    b.lignes.append("📉 Deux saisons ratées : on ne te garde pas. Tu rebondis à \(c.club).")
                }
            } else if p >= 50 {
                c.saisonsRatees = 0
            }
            if c.niveau < 5 && p >= 65 && c.reputation >= SpeCatalogue.seuilsReputation[c.niveau + 1] && (c.niveau < 4 || c.titres >= 3) {
                c.club = SpeCatalogue.club(c.sport, niveau: c.niveau + 1, cle: j.age)
                let texte = c.niveau + 1 == 5 ? "Tu entres dans la légende de ton sport." : "Transfert : tu rejoins \(c.club)."
                promotion(&c, j, &b, texte: texte)
            }
        }
        // Récupération et âge
        c.forme += 20
        if j.age > 29 { c.forme -= (j.age - 29) * 2 }
        e.cardio += c.blessure > 0 ? -4 : 1
        e.technique += c.blessure > 0 ? 0 : 1
        if j.age >= 39 { fin = "âge" }
    }

    // MARK: Mannequin

    static let apparenceRang = [0, 55, 62, 70, 78, 85]

    static func anneeMannequin(_ c: inout SpeCarriere, _ j: inout Joueur, _ b: inout Bilan) {
        let app = j.stats.apparence
        var revenu = Int(Double(SpeCatalogue.revenu(.mannequin, c.niveau)) * (0.4 + Double(app) / 100 + Double(c.reputation) / 200)
                         * Double.random(in: 0.8...1.2))
        if app < 45 {
            revenu /= 3
            c.reputation -= 5
            b.lignes.append("📸 Les bookings se font rares. Ton agence te parle de « renouveler ton image ».")
        }
        gagner(revenu, &j)
        c.gainsTotal += revenu
        b.lignes.append("📸 Année de mannequinat avec \(c.agence) : \(Format.argent(revenu)).")
        if j.age >= 30 && c.niveau < 4 {
            c.reputation -= (j.age - 28) / 2
            if j.age % 3 == 0 { b.lignes.append("📸 On te propose moins de défilés. Le mot « jeune » revient dans tous les castings.") }
        }
        c.abonnes += c.abonnes / 10 + c.niveau * 2_000 + 200
        if c.niveau < 5 && c.reputation >= SpeCatalogue.seuilsReputation[c.niveau + 1] && app >= apparenceRang[c.niveau + 1] {
            let ancienne = c.agence
            if c.niveau + 1 == 1 || c.niveau + 1 == 3 {
                c.agence = SpeCatalogue.agences[c.niveau + 1][abs(j.age) % SpeCatalogue.agences[c.niveau + 1].count]
            }
            let texte = c.agence != ancienne ? "\(c.agence) te signe. Nouveau rang : \(SpeCatalogue.rangs(.mannequin, femme: femme(j))[c.niveau + 1].lowercased())."
                : "Nouveau rang : \(SpeCatalogue.rangs(.mannequin, femme: femme(j))[c.niveau + 1].lowercased())."
            promotion(&c, j, &b, texte: texte)
        }
        c.forme += 15
    }

    // MARK: Cinéma

    /// Réputation nécessaire pour qu'un producteur finance chaque taille de film.
    static let reputationProducteur = [0, 15, 35, 55]
    /// Taille de film maximale selon le rang.
    static func tailleMax(_ c: SpeCarriere) -> Int {
        switch c.niveau {
        case 0: return c.reputation >= 15 ? 1 : 0
        case 1: return 1
        case 2: return 2
        default: return 3
        }
    }

    static let filmsRequis = [0, 1, 2, 4, 6, 9]

    static func anneeCinema(_ c: inout SpeCarriere, _ j: inout Joueur, _ b: inout Bilan) {
        if var f = c.projet, f.ageTournage < j.age {
            let lignesFilm = sortirFilm(&f, &c, &j, &b)
            b.lignes += lignesFilm
            c.films.append(f)
            c.projet = nil
        } else if c.projet == nil, c.annees > 2, (c.films.last?.ageTournage ?? 0) < j.age - 3 {
            c.reputation -= 3
            b.lignes.append("🎬 Pas de film depuis longtemps. Les producteurs ne rappellent plus.")
        }
        let droits = c.films.reduce(0) { $0 + $1.recettes } / 100
        if droits > 0 {
            gagner(droits, &j)
            c.gainsTotal += droits
            b.lignes.append("🎬 Droits sur tes anciens films (télé, plateformes) : \(Format.argent(droits)).")
        }
        if c.niveau >= 2 {
            let a_cote = SpeCatalogue.revenu(.cinema, c.niveau) / 5
            gagner(a_cote, &j)
            c.gainsTotal += a_cote
        }
        let longs = c.films.filter { $0.taille >= 1 }.count
        if c.niveau < 5 && c.reputation >= SpeCatalogue.seuilsReputation[c.niveau + 1] && longs >= filmsRequis[c.niveau + 1] {
            let texte = "On parle de toi comme \(SpeCatalogue.rangs(.cinema, femme: femme(j))[c.niveau + 1].lowercased())."
            promotion(&c, j, &b, texte: texte)
        }
        c.forme += 15
    }

    static func sortirFilm(_ f: inout SpeFilm, _ c: inout SpeCarriere, _ j: inout Joueur, _ b: inout Bilan) -> [String] {
        var lignes: [String] = []
        var q = Double(j.stats.intelligence) * 0.3 + Double(c.reputation) * 0.2 + Double(c.forme) * 0.3 + Double(min(5, c.scenarios) * 4)
        q += [0.0, 6, 10][min(2, f.casting)]
        let bonusCritique: [String: Double] = ["auteur": 10, "documentaire": 6, "drame": 5, "horreur": -4, "action": -4]
        q += bonusCritique[f.genre] ?? 0
        if j.filiereDiplome == .arts { q += 5 }
        q += Double(Competences.niveau("photo", j) * 2)
        q += Double.random(in: -20...20)
        f.critique = borne(Int(q))
        c.scenarios = max(0, c.scenarios - 1)
        f.sorti = true

        if f.taille == 0 {
            c.reputation += (f.critique - 45) / 4
            lignes.append("🎬 Ton court-métrage « \(f.titre) » tourne dans les festivals : critique \(f.critique)/100.")
            if f.critique >= 75 && Double.random(in: 0...1) < 0.6 {
                let prix = "Prix du court-métrage au festival de Clairmont"
                f.prix.append(prix)
                c.palmares.append("\(prix) (« \(f.titre) »)")
                c.reputation += 6
                lignes.append("🏆 \(prix) !")
            }
            return lignes
        }

        let genreMult: Double
        switch f.genre {
        case "comedie": genreMult = 1.3
        case "action": genreMult = f.taille >= 2 ? 1.5 : 0.9
        case "horreur": genreMult = f.taille <= 1 ? 1.6 : 1.1
        case "sf": genreMult = f.taille == 3 ? 1.5 : 0.8
        case "documentaire": genreMult = 0.4
        case "auteur": genreMult = 0.35
        default: genreMult = 0.8
        }
        let attrait = Double(f.critique) / 60
        let mult = attrait * attrait * genreMult * [1.0, 1.3, 1.8][min(2, f.casting)] * Double.random(in: 0.4...1.8)
        f.recettes = Int(Double(f.budget) * mult)
        let entrees = f.recettes / 9
        lignes.append("🎬 Sortie de « \(f.titre) » (\(SpeCatalogue.nomGenreFilm(f.genre).lowercased())) : critique \(f.critique)/100, \(entrees) entrées, \(Format.argent(f.recettes)) de recettes.")

        var part: Int
        if f.autoFinance {
            part = f.recettes / 2
            lignes.append("Tu as financé le film : après les distributeurs, tu touches \(Format.argent(part)) (budget : \(Format.argent(f.budget))).")
        } else {
            part = SpeCatalogue.revenu(.cinema, c.niveau)
            if f.recettes > f.budget { part += (f.recettes - f.budget) / 20 }
            lignes.append("Ton cachet de \(femme(j) ? "réalisatrice" : "réalisateur") et ta part des bénéfices : \(Format.argent(part)).")
        }
        gagner(part, &j)
        c.gainsTotal += part

        c.reputation += (f.critique - 50) / 4 + (f.recettes > f.budget * 2 ? 4 : 0) - (f.recettes < f.budget / 2 ? 4 : 0)
        if f.recettes > f.budget * 2 {
            b.signaux.append("spe_film_succes")
            j.stats.bonheur += 8
        } else if f.recettes < f.budget / 2 {
            b.signaux.append("spe_film_flop")
            j.stats.bonheur -= 6
        }
        // Récompenses
        var recompenses: [String] = []
        if f.critique >= 82 && Double.random(in: 0...1) < 0.5 { recompenses.append("Étoile de la meilleure réalisation") }
        if f.critique >= 88 && Double.random(in: 0...1) < 0.4 { recompenses.append("Grand prix du festival de la Côte") }
        if f.critique >= 75 && f.recettes > f.budget * 3 && Double.random(in: 0...1) < 0.4 { recompenses.append("Étoile du public") }
        for r in recompenses {
            f.prix.append(r)
            c.palmares.append("\(r) (« \(f.titre) »)")
            c.reputation += 6
            lignes.append("🏆 \(r) pour « \(f.titre) » !")
        }
        return lignes
    }

    // MARK: Musique

    static func anneeMusique(_ c: inout SpeCarriere, _ j: inout Joueur, _ b: inout Bilan) {
        var streams = Int(Double(c.fans) * 0.4 * (1 + 0.1 * Double(c.albums.count)))
        if !c.label.isEmpty { streams = streams * 35 / 100 }
        let concerts = c.fans >= 500 ? SpeCatalogue.revenu(.musique, c.niveau) / 4 : 0
        let total = streams + concerts
        if total > 0 {
            gagner(total, &j)
            c.gainsTotal += total
            b.lignes.append("🎶 Streams et concerts : \(Format.argent(total))\(c.label.isEmpty ? "" : " (après la part de \(c.label))").")
        }
        let dernier = c.albums.last?.age ?? c.ageDebut
        if j.age - dernier >= 3 && c.fans > 0 {
            c.fans -= c.fans / 8
            b.lignes.append("🎶 Pas de nouvel album depuis \(j.age - dernier) ans : une partie du public passe à autre chose.")
        }
        // Rang selon les fans (le rang 2 demande un label ou 100 000 fans en indépendant).
        var cible = 0
        for (i, s) in SpeCatalogue.seuilsFans.enumerated() where c.fans >= s { cible = i }
        if cible >= 2 && c.label.isEmpty && c.fans < 100_000 { cible = 1 }
        while c.niveau < cible {
            let texte = "\(c.nomScene) passe un cap : \(SpeCatalogue.rangs(.musique, femme: femme(j))[c.niveau + 1].lowercased())."
            promotion(&c, j, &b, texte: texte)
        }
        if c.label.isEmpty && c.offreLabel.isEmpty && c.fans >= 5_000 && Double.random(in: 0...1) < 0.5 {
            c.offreLabel = SpeCatalogue.labels.randomElement() ?? "Disques Mirage"
            b.lignes.append("✉️ Le label \(c.offreLabel) veut signer \(c.nomScene). L'offre t'attend dans ta carrière.")
        }
        c.forme += 15
    }

    static let certifications: [(seuil: Int, nom: String)] = [(500_000, "Disque de diamant"), (100_000, "Disque de platine"), (50_000, "Disque d'or")]

    // MARK: - Musée

    static func anneeMusee(_ m: inout SpeMusee, _ j: inout Joueur, _ b: inout Bilan) {
        let facteurPrix: Double
        switch m.prixBillet {
        case 0: facteurPrix = 1.5
        case 1...10: facteurPrix = 1.0
        case 11...18: facteurPrix = 0.8
        default: facteurPrix = 0.6
        }
        let expo = m.expoAnnee.isEmpty ? 1.0 : 1.3
        let base = Double(SpeCatalogue.visiteursBase[min(3, m.taille)])
        m.visiteursAn = Int(base * (0.4 + Double(m.prestige) / 100 + Double(m.notoriete) / 200) * facteurPrix * expo * Double.random(in: 0.85...1.15))
        let recettes = m.visiteursAn * m.prixBillet + m.visiteursAn * 4
        let charges = SpeCatalogue.chargesMusee[min(3, m.taille)] + m.collection.count * 2_000
        m.resultatAn = recettes - charges
        gagner(m.resultatAn, &j)
        b.lignes.append("🏛️ \(m.nom) : \(m.visiteursAn) visiteurs, \(m.resultatAn >= 0 ? "bénéfice" : "perte") de \(Format.argent(abs(m.resultatAn))).")

        let somme = m.collection.reduce(0) { $0 + ($1.theme == m.theme ? $1.prestige : $1.prestige / 2) }
        let cible = min(100, somme * 6 / max(1, SpeCatalogue.capaciteOeuvres[min(3, m.taille)]) + 10)
        m.prestige = borne(m.prestige + (cible - m.prestige) / 3)
        m.notoriete = borne(m.notoriete + (m.expoAnnee.isEmpty ? -1 : 3))
        for i in m.collection.indices {
            m.collection[i].valeur = Int(Double(m.collection[i].valeur) * Double.random(in: 1.0...1.06))
        }
        m.expoAnnee = ""
        m.actionsAnnee = []
    }

    /// Œuvres proposées cette année (même liste toute l'année).
    static func marche(_ m: SpeMusee, age: Int) -> [SpeOeuvre] {
        let possedees = Set(m.collection.map { $0.id })
        var liste: [SpeOeuvre] = []
        // Une pièce de grand catalogue du thème, si disponible.
        let grandes = SpeCatalogue.oeuvres.filter { $0.theme == m.theme && !possedees.contains($0.id) }
        if let g = choixStable(grandes, age) { liste.append(g) }
        if let autre = choixStable(SpeCatalogue.oeuvres.filter { $0.theme != m.theme && !possedees.contains($0.id) }, age &+ 3) {
            liste.append(autre)
        }
        for i in 0..<4 {
            let o = oeuvreGeneree(theme: m.theme, cle: age &* 10 &+ i)
            if !possedees.contains(o.id) { liste.append(o) }
        }
        return liste
    }

    static func oeuvreGeneree(theme: String, cle: Int) -> SpeOeuvre {
        let debuts: [String: [String]] = [
            "beauxarts": ["Portrait d'une inconnue", "Paysage de rivière", "Scène de marché", "Nature morte", "Vue du port", "La Couturière"],
            "contemporain": ["Sans titre", "Installation", "Fragment", "Écran blanc", "Tension", "Sculpture molle"],
            "histoire": ["Fibule", "Manuscrit enluminé", "Vase funéraire", "Armure de tournoi", "Affiche de propagande", "Tablette d'argile"],
            "sciences": ["Microscope", "Herbier", "Fossile d'ammonite", "Globe céleste", "Machine à vapeur miniature", "Planche anatomique"],
            "automobile": ["Cabriolet", "Berline", "Side-car", "Roadster", "Camionnette de livraison", "Voiture de course"],
            "insolite": ["Collection de boutons", "Machine à remonter les chaussettes", "Le plus petit vélo du monde", "Valise de magicien",
                         "Perruque de juge", "Distributeur de chewing-gum"],
        ]
        let fins = ["en bleu", "de 1880", "n°\(abs(cle) % 90 + 3)", "du XVIIe siècle", "(attribué)", "de la collection Morel",
                    "aux oiseaux", "de 1923", "du Grand Siècle", "(provenance discutée)"]
        let auteurs = ["Atelier de Lyon", "Anonyme", "Marguerite Roche", "Victor Lenain", "École flamande", "Iris Tanaka",
                       "Manufacture royale", "Ottavio Brera"]
        let d = debuts[theme] ?? debuts["insolite"]!
        let nom = "\(d[abs(cle &* 7) % d.count]) \(fins[abs(cle &* 13 &+ 1) % fins.count])"
        let palier = abs(cle &* 31) % 10
        let valeur: Int
        let prestige: Int
        switch palier {
        case 0...4: valeur = 30_000 + abs(cle &* 977) % 120_000; prestige = 3
        case 5...7: valeur = 200_000 + abs(cle &* 4_201) % 600_000; prestige = 6
        case 8: valeur = 1_000_000 + abs(cle &* 7_919) % 2_000_000; prestige = 11
        default: valeur = 4_000_000 + abs(cle &* 104_729) % 6_000_000; prestige = 18
        }
        return SpeOeuvre(id: "g_\(theme)_\(cle)", nom: nom, auteur: auteurs[abs(cle &* 3) % auteurs.count], theme: theme,
                         valeur: valeur, prestige: prestige)
    }

    static func prixAchat(_ o: SpeOeuvre) -> Int { o.valeur * 11 / 10 }

    // MARK: - Investissements

    static func anneeInvestissements(_ e: inout SpeEtat, _ j: inout Joueur, _ b: inout Bilan) {
        for i in e.investissements.indices where !e.investissements[i].termine {
            var inv = e.investissements[i]
            inv.annees += 1
            switch inv.type {
            case .combattant:
                if Double.random(in: 0...1) < 0.08 {
                    inv.valeur = inv.valeur / 10
                    inv.dernier = "\(inv.nom) a pris un KO terrible et parle d'arrêter. Ta part ne vaut presque plus rien."
                } else {
                    let r = Double.random(in: -0.3...0.45)
                    inv.valeur = max(0, Int(Double(inv.valeur) * (1 + r)))
                    let dividende = inv.valeur / 12
                    gagner(dividende, &j)
                    inv.dernier = r >= 0 ? "\(inv.nom) gagne ses combats. Ta part des bourses : \(Format.argent(dividende))."
                        : "\(inv.nom) enchaîne les défaites. Ta part des bourses : \(Format.argent(dividende))."
                }
            case .film, .album:
                if inv.annees >= 2 {
                    let x = Double.random(in: 0...1)
                    let mult: Double
                    let texte: String
                    if inv.type == .film {
                        if x < 0.35 { mult = 0.3; texte = "\(inv.nom) fait un flop en salles." }
                        else if x < 0.8 { mult = Double.random(in: 1.1...1.4); texte = "\(inv.nom) rentre dans ses frais, avec un petit bénéfice." }
                        else { mult = Double.random(in: 2.0...4.0); texte = "\(inv.nom) cartonne au box-office !" }
                    } else {
                        if x < 0.5 { mult = 0.2; texte = "\(inv.nom) passe inaperçu." }
                        else if x < 0.85 { mult = Double.random(in: 1.0...1.5); texte = "\(inv.nom) trouve son public." }
                        else { mult = Double.random(in: 2.0...5.0); texte = "\(inv.nom) devient un tube !" }
                    }
                    inv.valeur = Int(Double(inv.valeur) * mult)
                    gagner(inv.valeur, &j)
                    inv.termine = true
                    inv.dernier = texte + " Tu récupères \(Format.argent(inv.valeur)) (mise : \(Format.argent(inv.mise)))."
                } else {
                    inv.dernier = inv.type == .film ? "\(inv.nom) est en tournage." : "\(inv.nom) est en studio."
                }
            case .club:
                let r = Double.random(in: -0.12...0.15)
                inv.valeur = max(0, Int(Double(inv.valeur) * (1 + r)))
                let frais = inv.valeur * 3 / 100
                gagner(-frais, &j)
                inv.dernier = (r >= 0 ? "Bonne saison pour \(inv.nom), les supporters chantent ton nom." : "Saison difficile pour \(inv.nom), banderoles hostiles en tribune.")
                    + " Frais de fonctionnement : \(Format.argent(frais))."
            case .agence:
                let r = Double.random(in: -0.05...0.18)
                inv.valeur = max(0, Int(Double(inv.valeur) * (1 + r)))
                let dividende = inv.valeur * 6 / 100
                gagner(dividende, &j)
                inv.dernier = "\(inv.nom) place ses mannequins. Dividende : \(Format.argent(dividende))."
            }
            b.lignes.append("💼 " + inv.dernier)
            e.investissements[i] = inv
        }
    }

    // MARK: - Fin de carrière

    @discardableResult
    static func terminer(_ e: inout SpeEtat, _ j: Joueur, raison: String) -> String {
        guard let c = e.carriere else { return "" }
        let f = femme(j)
        let rang = SpeCatalogue.rang(c, femme: f)
        var resume = "\(c.annees) an\(c.annees > 1 ? "s" : ""), \(Format.argent(c.gainsTotal)) gagnés"
        switch c.type {
        case .mma: resume += ", \(c.victoires) victoires, \(c.defaites) défaites" + (c.ceintures > 0 ? ", \(c.ceintures) combat(s) de titre gagné(s)" : "")
        case .sport: resume += ", \(c.titres) titre(s), \(c.selections) sélection(s)"
        case .mannequin: resume += ", \(c.campagnes) campagnes, \(c.defiles) défilés"
        case .cinema: resume += ", \(c.films.count) film(s)"
        case .musique: resume += ", \(c.albums.count) album(s), \(c.fans) fans"
        }
        e.anciennes.append(SpeArchive(type: c.type, rang: rang, ageDebut: c.ageDebut, ageFin: j.age, resume: resume))
        e.carriere = nil
        switch raison {
        case "âge": return "🏁 Ton corps décide pour toi : fin de ta carrière de \(c.type.nom(f).lowercased()) (\(resume))."
        case "carte": return "🏁 Ta carrière de \(c.type.nom(f).lowercased()) s'arrête là (\(resume))."
        case "mort": return ""
        default: return "🏁 Tu mets fin à ta carrière de \(c.type.nom(f).lowercased()). Bilan : \(resume)."
        }
    }

    // MARK: - Cartes

    static func carte(_ id: String) -> SpeCarte? { SpeCatalogue.cartes.first { $0.id == id } }

    static func niveauPour(_ source: String, _ e: SpeEtat) -> Int {
        if source == "musee" { return e.musee?.taille ?? 0 }
        if let c = e.carriere, c.type.rawValue == source { return c.niveau }
        return 0
    }

    static func carteOK(_ k: SpeCarte, _ e: SpeEtat, _ j: Joueur) -> Bool {
        let n = niveauPour(k.carriere, e)
        if let m = k.minNiveau, n < m { return false }
        if let m = k.maxNiveau, n > m { return false }
        if let a = k.minAge, j.age < a { return false }
        if let a = k.maxAge, j.age > a { return false }
        if k.unique == true && e.cartesVues.contains(k.id) { return false }
        if k.carriere == "invest" && investsVises(e, types: k.types).isEmpty { return false }
        if let c = e.carriere {
            if let s = k.sports, !s.isEmpty, c.type == .sport, !s.contains(c.sport) { return false }
            if let g = k.genres, !g.isEmpty {
                let genre = c.type == .cinema ? (c.projet?.genre ?? c.films.last?.genre ?? "") : c.genre
                if !g.contains(genre) { return false }
            }
            if let gr = k.groupe, c.type == .musique, gr != c.enGroupe { return false }
        }
        return true
    }

    /// Au plus une carte du module par an.
    static func carteDeLAnnee(_ e: SpeEtat, _ j: Joueur) -> SpeCarte? {
        var sources: [String] = []
        if let c = e.carriere, Double.random(in: 0...1) < 0.6 { sources.append(c.type.rawValue) }
        if e.musee != nil, Double.random(in: 0...1) < 0.35 { sources.append("musee") }
        if e.investissements.contains(where: { !$0.termine }), Double.random(in: 0...1) < 0.25 { sources.append("invest") }
        if e.abonnement > 0, e.carriere?.type != .mma, Double.random(in: 0...1) < 0.2 { sources.append("salle") }
        for s in sources {
            let liste = SpeCatalogue.cartes.filter { $0.carriere == s && carteOK($0, e, j) }
            if let k = GameEngine.tirage(liste, poids: { $0.poids ?? 1 }) { return k }
        }
        return nil
    }

    /// Investissements en cours visés par une carte (tous si la carte ne précise pas de type).
    static func investsVises(_ e: SpeEtat, types: [String]?) -> [SpeInvest] {
        e.investissements.filter { inv in
            !inv.termine && (types == nil || types!.isEmpty || types!.contains(inv.type.rawValue))
        }
    }

    static func referenceArgent(_ k: SpeCarte, _ e: SpeEtat) -> Int {
        if let c = e.carriere, c.type.rawValue == k.carriere { return SpeCatalogue.revenu(c.type, c.niveau) }
        return 100_000
    }

    static func cout(_ ch: SpeChoix, _ k: SpeCarte, _ e: SpeEtat) -> Int {
        if let c = ch.cost, c > 0 { return c }
        if let p = ch.costPct, p > 0 { return referenceArgent(k, e) * p / 100 }
        return 0
    }

    static func versEvenement(_ k: SpeCarte, _ e: SpeEtat, _ j: Joueur) -> Evenement {
        let choix: [Choix] = k.choices.map { ch in
            var label = remplir(ch.label, e, j, types: k.types)
            let prix = cout(ch, k, e)
            if prix > 0 { label += " (\(Format.argent(prix)))" }
            let issues = ch.outcomes.map { o in
                Issue(chance: max(0.01, o.chance ?? 1), text: remplir(o.text, e, j, types: k.types), effects: o.effects)
            }
            return Choix(label: label, outcomes: issues, requiresSkill: ch.requiresSkill, risk: ch.risk)
        }
        return Evenement(id: prefixe + k.id, category: "speciales", minAge: 0, maxAge: 200, weight: 1, unique: nil,
                         conditions: nil, text: remplir(k.text, e, j, types: k.types), effects: nil, choices: choix)
    }

    /// Applique la partie `spe` d'une issue. Renvoie lignes et signaux.
    static func appliquer(_ fx: SpeEffets, carte k: SpeCarte, _ j: inout Joueur) -> Bilan {
        var b = Bilan()
        guard var e = j.speciales else { return b }
        let ref = referenceArgent(k, e)
        if var c = e.carriere, c.type.rawValue == k.carriere {
            c.reputation += fx.reputation ?? 0
            c.forme += fx.forme ?? 0
            if let n = fx.niveau, n != 0 {
                let avant = c.niveau
                c.niveau = min(5, max(0, c.niveau + n))
                if c.niveau != avant {
                    let r = SpeCatalogue.rang(c, femme: femme(j))
                    if c.niveau > avant { c.palmares.append("\(r) à \(j.age) ans") }
                    b.lignes.append(c.niveau > avant ? "⭐️ Nouveau rang : \(r.lowercased())." : "📉 Tu redescends : \(r.lowercased()).")
                }
            }
            if let bl = fx.blessure, bl > 0 { c.blessure = max(c.blessure, bl) }
            if let p = fx.fansPct {
                if c.type == .musique || c.type == .sport { c.fans += c.fans * p / 100 }
                c.abonnes += c.abonnes * p / 100
            }
            borner(&c)
            e.carriere = c
        }
        if var m = e.musee, k.carriere == "musee" {
            m.notoriete = borne(m.notoriete + (fx.reputation ?? 0))
            m.prestige = borne(m.prestige + (fx.prestige ?? 0))
            if let v = fx.visiteursPct, v != 0 {
                let gain = m.visiteursAn * v / 100 * max(4, m.prixBillet + 4)
                gagner(gain, &j)
                m.notoriete = borne(m.notoriete + v / 10)
            }
            if let p = fx.collectionPct, p != 0 {
                for i in m.collection.indices { m.collection[i].valeur = max(0, m.collection[i].valeur * (100 + p) / 100) }
            }
            e.musee = m
        }
        if let g = fx.gainPct, g != 0 { gagner(ref * g / 100, &j) }
        e.force += fx.force ?? 0
        e.technique += fx.technique ?? 0
        e.cardio += fx.cardio ?? 0
        bornerSalle(&e)
        if let p = fx.investPct, p != 0 {
            let vise = choixStable(investsVises(e, types: k.types), j.age)
            if let v = vise, let i = e.investissements.firstIndex(where: { $0.id == v.id }) {
                e.investissements[i].valeur = max(0, e.investissements[i].valeur * (100 + p) / 100)
            }
        }
        if fx.finCarriere == true, let c = e.carriere, c.type.rawValue == k.carriere {
            b.lignes.append(terminer(&e, j, raison: "carte"))
            b.signaux.append("spe_fin_carriere")
        }
        if let s = fx.signal { b.signaux.append(s) }
        j.speciales = e
        return b
    }

    // MARK: - Textes

    static func remplir(_ texte: String, _ e: SpeEtat, _ j: Joueur, types: [String]? = nil) -> String {
        guard texte.contains("{") else { return texte }
        var t = texte
        let c = e.carriere
        let f = femme(j)
        func r(_ cle: String, _ valeur: String) {
            if t.contains(cle) { t = t.replacingOccurrences(of: cle, with: valeur) }
        }
        r("{rang}", c.map { SpeCatalogue.rang($0, femme: f).lowercased() } ?? "débutant")
        r("{coach}", c.map { $0.coach.isEmpty ? "ton coach" : $0.coach } ?? (choixStable(SpeCatalogue.coachs, j.age) ?? "ton coach"))
        r("{adversaire}", SpeCatalogue.adversaire(j.age &* 5 &+ (c?.victoires ?? 0)))
        r("{ligue}", SpeCatalogue.ligues[c?.niveau ?? 0])
        r("{salle}", e.salleNom.isEmpty ? "ta salle" : e.salleNom)
        r("{club}", c.map { $0.club.isEmpty ? "ton club" : $0.club } ?? "ton club")
        r("{sport}", c.map { SpeCatalogue.sport($0.sport).nom.lowercased() } ?? "sport")
        r("{agence}", c.map { $0.agence.isEmpty ? "ton agence" : $0.agence } ?? "ton agence")
        r("{marque}", choixStable(SpeCatalogue.marques, j.age) ?? "Maison Delaunay")
        r("{film}", c.flatMap { $0.projet?.titre ?? $0.films.last?.titre } ?? "ton prochain film")
        r("{groupe}", c.map { $0.nomScene.isEmpty ? j.prenom : $0.nomScene } ?? j.prenom)
        r("{label}", c.map { !$0.label.isEmpty ? $0.label : (!$0.offreLabel.isEmpty ? $0.offreLabel : "ton label") } ?? "ton label")
        r("{musee}", e.musee?.nom ?? "ton musée")
        r("{oeuvre}", e.musee.flatMap { choixStable($0.collection, j.age)?.nom } ?? "ta pièce maîtresse")
        r("{projet}", choixStable(investsVises(e, types: types), j.age)?.nom ?? "ton investissement")
        return t
    }
}

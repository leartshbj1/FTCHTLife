import Foundation

// Branchement des carrières spéciales dans le moteur et actions du joueur. Voir docs/CARRIERES_SPECIALES.md.

/// Réponse d'une action : faite (on sauvegarde) ou refusée (rien ne change).
enum SpeResultat {
    case ok(String)
    case refus(String)
}

enum SpeEntrainement: String, CaseIterable, Identifiable {
    case muscu, cardio, boxe, coach, courir

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .muscu: return "Musculation"
        case .cardio: return "Cardio"
        case .boxe: return "Cours de boxe"
        case .coach: return "Séance avec un coach perso"
        case .courir: return "Courir dehors"
        }
    }

    var emoji: String {
        switch self {
        case .muscu: return "🏋️"
        case .cardio: return "🚴"
        case .boxe: return "🥊"
        case .coach: return "📋"
        case .courir: return "🏃"
        }
    }

    var description: String {
        switch self {
        case .muscu: return "Force en hausse, un peu de santé et d'apparence."
        case .cardio: return "Endurance et santé."
        case .boxe: return "Technique de combat. 400 € hors club de boxe."
        case .coach: return "Tout progresse un peu. 3 000 €."
        case .courir: return "Gratuit, sans abonnement. Un peu de cardio."
        }
    }
}

extension GameEngine {

    // MARK: - Moteur

    /// Appelé dans `modulesAnnee`.
    func specialesAnnee(_ j: inout Joueur) -> [String] {
        let b = SpeMoteur.passerAnnee(&j)
        for s in b.signaux { SignauxModules.signaler(s, &j) }
        return b.lignes
    }

    /// Appelé à la fin de `modulesAvantTirage` : au plus une carte du module par an.
    func specialesAvantTirage() {
        guard var j = joueur, j.vivant, !j.vieEtat.justice.enPrison, var e = j.speciales,
              let k = SpeMoteur.carteDeLAnnee(e, j) else { return }
        if k.unique == true { e.cartesVues.append(k.id) }
        j.speciales = e
        joueur = j
        var ev = SpeMoteur.versEvenement(k, e, j)
        let joueurActuel = j
        ev.choices = ev.choices?.map { c in
            var c2 = c
            c2.label = self.remplir(c.label, joueurActuel)
            return c2
        }
        fileEvenements.append(EvenementAffiche(evenement: ev, texte: remplir(ev.text, j)))
    }

    /// Appelé dans `modulesApresChoix`.
    func specialesApresChoix(_ ev: Evenement, choix index: Int, issue k: Int?, _ j: inout Joueur) {
        guard ev.id.hasPrefix(SpeMoteur.prefixe),
              let carte = SpeMoteur.carte(String(ev.id.dropFirst(SpeMoteur.prefixe.count))),
              carte.choices.indices.contains(index) else { return }
        let ch = carte.choices[index]
        let prix = SpeMoteur.cout(ch, carte, j.speciales ?? SpeEtat())
        if prix > 0 { j.argent = Shkurtaaa.argent(j.argent - prix) }
        guard let k = k, ch.outcomes.indices.contains(k), let fx = ch.outcomes[k].spe else { return }
        let b = SpeMoteur.appliquer(fx, carte: carte, &j)
        for l in b.lignes where !l.isEmpty { ajouterLigne(&j, l) }
        for s in b.signaux { SignauxModules.signaler(s, &j) }
    }

    /// Appelé dans `modulesMort`.
    func specialesMort(_ j: inout Joueur) {
        guard var e = j.speciales, e.carriere != nil else { return }
        SpeMoteur.terminer(&e, j, raison: "mort")
        j.speciales = e
    }

    // MARK: - Outils d'action

    func speFaire(_ corps: (inout SpeEtat, inout Joueur) -> SpeResultat) -> String {
        guard var j = joueur, j.vivant else { return "Aucune vie en cours." }
        if j.vieEtat.justice.enPrison { return "Tu es en prison. Ça attendra ta sortie." }
        var e = j.speciales ?? SpeEtat()
        switch corps(&e, &j) {
        case .refus(let m):
            return m
        case .ok(let m):
            j.speciales = e
            j.argent = Shkurtaaa.argent(j.argent)
            j.stats.borner()
            if !m.isEmpty { ajouterLigne(&j, m) }
            joueur = j
            sauvegarder()
            return m
        }
    }

    /// Action de carrière, une fois par an (clé `cle`).
    func speCarriereAction(_ type: SpeCarriereType, cle: String, blesseOK: Bool = true,
                           _ corps: (inout SpeCarriere, inout SpeEtat, inout Joueur) -> SpeResultat) -> String {
        speFaire { e, j in
            guard var c = e.carriere, c.type == type else { return .refus("Ce n'est pas ta carrière.") }
            if c.actionsAnnee.contains(cle) { return .refus("Déjà fait cette année. Reviens après « Âge +1 ».") }
            if !blesseOK && c.blessure > 0 { return .refus("Tu es blessé\(j.genre == .femme ? "e" : ""). Repos forcé encore \(c.blessure) an\(c.blessure > 1 ? "s" : "").") }
            let r = corps(&c, &e, &j)
            if case .ok = r {
                c.actionsAnnee.append(cle)
                SpeMoteur.borner(&c)
                e.carriere = c
            }
            return r
        }
    }

    // MARK: - Salle de sport

    func speAbonnement(_ niveau: Int) -> String {
        speFaire { e, j in
            guard j.age >= SpeMoteur.ageMinSalle else { return .refus("Dès \(SpeMoteur.ageMinSalle) ans.") }
            let n = min(3, max(0, niveau))
            guard n != e.abonnement else { return .refus("C'est déjà ton abonnement.") }
            if n == 0 {
                let nom = e.salleNom
                e.abonnement = 0
                return .ok("🏋️ Tu résilies ton abonnement à \(nom.isEmpty ? "la salle" : nom). Ton canapé te remercie.")
            }
            let prix = SpeCatalogue.prixAbonnement[n]
            guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Il faut \(Format.argent(prix)) pour l'année.") }
            j.argent -= prix
            e.abonnement = n
            e.salleNom = n == 2 ? (choixStable(SpeCatalogue.nomsClubsCombat, j.age) ?? "Team Granit")
                : (choixStable(SpeCatalogue.nomsSalles, j.age &+ n) ?? "La Forge")
            return .ok("🏋️ Nouvel abonnement : \(SpeCatalogue.abonnements[n].lowercased()) « \(e.salleNom) », \(Format.argent(prix)) par an.")
        }
    }

    func speEntrainer(_ t: SpeEntrainement) -> String {
        speFaire { e, j in
            guard j.age >= SpeMoteur.ageMinSalle || t == .courir else { return .refus("Dès \(SpeMoteur.ageMinSalle) ans.") }
            guard !e.actionsSalle.contains(t.rawValue) else { return .refus("Déjà fait cette année. Les muscles poussent aussi pendant le repos.") }
            let bonus = e.abonnement == 3 ? 2 : 0
            var texte: String
            switch t {
            case .muscu:
                guard e.abonnement > 0 else { return .refus("Il faut un abonnement à une salle.") }
                let g = Int.random(in: 3...6) + bonus
                e.force += g
                j.stats.sante += 2
                j.stats.apparence += 1
                if Double.random(in: 0...1) < 0.06 {
                    j.stats.sante -= 8
                    texte = "🏋️ Tu charges trop la barre pour impressionner le voisin de banc. Dos bloqué une semaine. Force +\(g) quand même."
                } else {
                    texte = "🏋️ " + ["Séance jambes. Tu descends les escaliers comme un faon qui vient de naître.",
                                    "Développé couché, tractions, gainage. Tu sens tes bras le lendemain matin.",
                                    "Tu bats ton record au soulevé de terre. Personne n'a vu, mais tu le sais.",
                                    "Une année de séances régulières. Tes t-shirts serrent aux épaules."].randomElement()! + " Force +\(g)."
                }
            case .cardio:
                guard e.abonnement > 0 else { return .refus("Il faut un abonnement à une salle (ou va courir dehors).") }
                let g = Int.random(in: 4...7) + bonus
                e.cardio += g
                j.stats.sante += 3
                texte = "🚴 " + ["Vélo, rameur, corde à sauter. Tu montes enfin quatre étages sans t'arrêter.",
                                "Intervalles sur tapis. Tu as cru mourir deux fois, puis ça va mieux."].randomElement()! + " Cardio +\(g)."
            case .boxe:
                let prix = e.abonnement == 2 ? 0 : 400
                if prix > 0 {
                    guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Les cours coûtent \(Format.argent(prix)).") }
                    j.argent -= prix
                }
                let g = Int.random(in: 4...7) + bonus
                e.technique += g
                e.cardio += 2
                var lignes = Competences.appliquer(["sport": 3], &j)
                lignes.insert("🥊 " + ["Gauche, droite, crochet, on recommence. Ton coach dit que tu baisses la garde.",
                                      "Premier sparring : tu prends plus que tu ne donnes, mais tu restes debout.",
                                      "Tu travailles le jeu de jambes sur la corde. Tes chevilles protestent.",
                                      "Le coach te fait taper dans les pattes d'ours pendant une heure. Tu dors comme un bébé."].randomElement()!
                              + " Technique +\(g)." + (prix > 0 ? " (\(Format.argent(prix)))" : ""), at: 0)
                texte = lignes.joined(separator: " ")
            case .coach:
                guard e.abonnement > 0 else { return .refus("Il faut un abonnement à une salle.") }
                guard Shkurtaaa.peutPayer(3_000, solde: j.argent) else { return .refus("Un coach perso coûte \(Format.argent(3_000)) pour l'année.") }
                j.argent -= 3_000
                e.force += 3 + bonus
                e.technique += 3
                e.cardio += 3 + bonus
                j.stats.sante += 2
                texte = "📋 Un coach perso te suit toute l'année : programme, nutrition, sommeil. Force, technique et cardio +3."
            case .courir:
                let g = Int.random(in: 2...3)
                e.cardio += g
                j.stats.sante += 2
                texte = "🏃 " + ["Tu cours le long du canal trois fois par semaine. Les canards te reconnaissent.",
                                "Footing sous la pluie. Tu te sens héroïque, puis enrhumé."].randomElement()! + " Cardio +\(g)."
            }
            e.actionsSalle.append(t.rawValue)
            SpeMoteur.bornerSalle(&e)
            return .ok(texte)
        }
    }

    // MARK: - Commencer et arrêter

    func speCommencer(_ t: SpeCarriereType, sport: String = "football", genre: String = "pop", enGroupe: Bool = false, nomScene: String = "") -> String {
        speFaire { e, j in
            if let r = SpeMoteur.blocageDebut(t, j) { return .refus(r) }
            if let r = self.empechementEmploi(j) { return .refus(r) }
            var c = SpeCarriere(type: t, ageDebut: j.age)
            c.coach = choixStable(SpeCatalogue.coachs, j.age) ?? "Momo Benali"
            let texte: String
            switch t {
            case .mma:
                texte = "🥊 Licence amateur en poche. \(c.coach) accepte de te préparer pour ton premier combat. « Tu vas prendre des coups. La question, c'est si tu reviens le lendemain. »"
            case .sport:
                guard !e.actionsSalle.contains("essais") else { return .refus("Tu as déjà passé des essais cette année.") }
                e.actionsSalle.append("essais")
                let s = SpeCatalogue.sport(sport)
                if Double.random(in: 0...1) >= SpeMoteur.chanceEssais(e, sport: sport, j) {
                    return .ok("\(s.emoji) Essais ratés en \(s.nom.lowercased()). Le recruteur note : « manque de \(e.cardio < e.force ? "caisse" : "puissance") ». Entraîne-toi et retente l'an prochain.")
                }
                c.sport = sport
                c.niveau = j.age >= 20 ? 1 : 0
                c.club = SpeCatalogue.club(sport, niveau: c.niveau, cle: j.age)
                c.reputation = c.niveau == 1 ? 26 : 10
                texte = "\(s.emoji) Essais réussis ! Tu signes ton premier contrat avec \(c.club) (\(SpeCatalogue.rang(c, femme: j.genre == .femme).lowercased()))."
            case .mannequin:
                guard !e.actionsSalle.contains("photos") else { return .refus("Les agences ont déjà tes photos cette année.") }
                e.actionsSalle.append("photos")
                if Double.random(in: 0...1) >= SpeMoteur.chanceAgence(j) {
                    return .ok("📸 Tu envoies tes photos à une dizaine d'agences. Une seule répond, pour te proposer un « book professionnel » à 900 €. Tu refuses. Réessaie l'an prochain.")
                }
                c.agence = SpeCatalogue.agences[0][abs(j.age) % SpeCatalogue.agences[0].count]
                texte = "📸 \(c.agence) te rappelle. Premier contrat : des catalogues de vêtements. Tu souris à un portant pendant six heures."
            case .cinema:
                c.reputation = 5
                texte = "🎬 Tu achètes une caméra d'occasion et tu écris ton premier court-métrage sur un coin de table. Le cinéma commence ici."
            case .musique:
                c.genre = genre
                c.enGroupe = enGroupe
                let nom = nomScene.trimmingCharacters(in: .whitespacesAndNewlines)
                c.nomScene = !nom.isEmpty ? nom : (enGroupe ? (choixStable(SpeCatalogue.nomsGroupes, j.age) ?? "Les Volts") : j.prenom)
                c.fans = 50
                c.chansons = 2
                texte = enGroupe
                    ? "🎸 Tu montes \(c.nomScene) avec des potes (\(SpeCatalogue.nomGenreMusique(genre).lowercased())). Première répétition dans un garage. Les voisins ne sont pas fans. Pas encore."
                    : "🎤 Tu te lances en solo sous le nom de \(c.nomScene) (\(SpeCatalogue.nomGenreMusique(genre).lowercased())). Cinquante abonnés, dont ta famille."
            }
            e.carriere = c
            SignauxModules.signaler("spe_debut_" + t.rawValue, &j)
            return .ok(texte)
        }
    }

    func speArreter() -> String {
        speFaire { e, j in
            guard e.carriere != nil else { return .refus("Tu n'as pas de carrière spéciale.") }
            let texte = SpeMoteur.terminer(&e, j, raison: "volontaire")
            SignauxModules.signaler("spe_fin_carriere", &j)
            return .ok(texte)
        }
    }

    // MARK: - MMA

    func speCombattre(difficulte: Int, strategie: Int) -> String {
        speFaire { e, j in
            guard var c = e.carriere, c.type == .mma else { return .refus("Tu n'es pas combattant.") }
            if c.blessure > 0 { return .refus("Tu es blessé\(j.genre == .femme ? "e" : ""). Le médecin de la ligue refuse ta licence cette année.") }
            if c.combatsAnnee >= 3 { return .refus("Trois combats cette année, c'est le maximum. Ton corps doit récupérer.") }
            if c.forme < 30 { return .refus("Forme trop basse (\(c.forme)/100). Fais un camp d'entraînement ou attends l'an prochain.") }
            if difficulte == 3 && !SpeMoteur.titreDisponible(c) { return .refus("Pas de combat pour la ceinture pour l'instant.") }
            let r = SpeMoteur.combattre(&c, &e, &j, difficulte: difficulte, strategie: strategie)
            e.carriere = c
            for s in r.signaux { SignauxModules.signaler(s, &j) }
            return .ok(r.texte)
        }
    }

    func speMMACamp() -> String {
        speCarriereAction(.mma, cle: "camp", blesseOK: false) { c, e, j in
            let prix = max(500, SpeCatalogue.revenu(.mma, c.niveau) / 10)
            guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Un camp coûte \(Format.argent(prix)).") }
            j.argent -= prix
            c.forme += 25
            e.technique += 3
            e.force += 2
            e.cardio += 3
            SpeMoteur.bornerSalle(&e)
            return .ok("⛺️ Six semaines de camp avec \(c.coach) : deux séances par jour, régime strict, sparrings filmés. Forme +25. (\(Format.argent(prix)))")
        }
    }

    func speMMAPresse() -> String {
        speCarriereAction(.mma, cle: "presse") { c, e, j in
            if Double.random(in: 0...1) < 0.2 {
                c.reputation += 10
                j.stats.karma -= 6
                let amende = max(500, SpeCatalogue.revenu(.mma, c.niveau) / 20)
                j.argent -= amende
                return .ok("🎙️ Conférence de presse houleuse : tu renverses la table, la vidéo fait le tour du monde. La ligue t'inflige \(Format.argent(amende)) d'amende. Tout le monde veut voir ton prochain combat.")
            }
            c.reputation += Int.random(in: 4...8)
            j.stats.karma -= 2
            return .ok("🎙️ Tu promets de « finir » ton prochain adversaire au premier round. Les réseaux adorent, ta mère beaucoup moins.")
        }
    }

    func speMMACoach() -> String {
        speCarriereAction(.mma, cle: "coach") { c, e, j in
            let prix = max(1_000, SpeCatalogue.revenu(.mma, c.niveau) / 8)
            guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Un nouveau staff coûte \(Format.argent(prix)).") }
            j.argent -= prix
            let ancien = c.coach
            c.coach = SpeCatalogue.coachs.filter { $0 != ancien }.randomElement() ?? ancien
            e.technique += 4
            c.forme += 5
            SpeMoteur.bornerSalle(&e)
            return .ok("📋 Tu quittes \(ancien) pour \(c.coach). Nouvelle méthode, nouveaux partenaires d'entraînement. Technique +4. (\(Format.argent(prix)))")
        }
    }

    // MARK: - Sport

    enum SpeSportAction: String {
        case entrainement, preparateur, transfert, sponsor, medias
    }

    func speSport(_ a: SpeSportAction) -> String {
        speCarriereAction(.sport, cle: a.rawValue, blesseOK: a == .sponsor || a == .medias) { c, e, j in
            let ref = SpeCatalogue.revenu(.sport, c.niveau)
            switch a {
            case .entrainement:
                c.forme += 12
                e.cardio += 3
                e.technique += 3
                SpeMoteur.bornerSalle(&e)
                return .ok("💪 Séances en plus, vidéo des matchs, étirements. Tu arrives le premier, tu pars le dernier. Forme +12.")
            case .preparateur:
                let prix = max(2_000, ref / 20)
                guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Un préparateur coûte \(Format.argent(prix)).") }
                j.argent -= prix
                c.forme += 15
                j.stats.sante += 3
                return .ok("🩺 Un préparateur physique te suit toute l'année. Moins de risques de blessure, plus de jus en fin de match. (\(Format.argent(prix)))")
            case .transfert:
                guard c.niveau < 4 else { return .refus("À ton niveau, ce sont les clubs qui viennent à toi.") }
                if c.performance >= 65 && c.reputation >= SpeCatalogue.seuilsReputation[c.niveau + 1] - 8 && Double.random(in: 0...1) < 0.6 {
                    let ancien = c.club
                    c.niveau += 1
                    c.club = SpeCatalogue.club(c.sport, niveau: c.niveau, cle: j.age &+ 1)
                    c.palmares.append("\(SpeCatalogue.rang(c, femme: j.genre == .femme)) à \(j.age) ans")
                    SignauxModules.signaler("spe_promotion", &j)
                    return .ok("✍️ Transfert bouclé : tu quittes \(ancien) pour \(c.club). Le salaire change d'échelle.")
                }
                c.reputation -= 3
                return .ok("✍️ Ton agent appelle partout. Réponse polie : « pas pour l'instant ». Ton club a appris que tu voulais partir.")
            case .sponsor:
                guard c.niveau >= 1 else { return .refus("Les marques attendent que tu sois pro.") }
                let gain = Int(Double(ref) * (0.1 + Double(c.reputation) / 400))
                SpeMoteur.gagner(gain, &j)
                c.gainsTotal += gain
                c.reputation += 1
                return .ok("🤝 Contrat avec une marque de boissons énergisantes. Tu dois sourire avec une canette à la main. \(Format.argent(gain)).")
            case .medias:
                c.fans += 1_000 * (c.niveau + 1) + c.fans / 10
                c.abonnes += 2_000 * (c.niveau + 1) + c.abonnes / 10
                if Double.random(in: 0...1) < 0.15 {
                    c.reputation -= 5
                    return .ok("📺 Interview d'après-match à chaud : tu critiques l'arbitre et ton entraîneur. Polémique d'une semaine.")
                }
                c.reputation += 2
                return .ok("📺 Interviews, vidéos d'entraînement, une émission du dimanche. Ton nom circule.")
            }
        }
    }

    // MARK: - Mannequin

    enum SpeMannequinAction: String {
        case casting, shooting, defile, soins, reseaux, agence
    }

    func speMannequin(_ a: SpeMannequinAction) -> String {
        speCarriereAction(.mannequin, cle: a.rawValue, blesseOK: a == .reseaux || a == .soins) { c, e, j in
            let ref = SpeCatalogue.revenu(.mannequin, c.niveau)
            let app = j.stats.apparence
            switch a {
            case .casting:
                let chance = min(0.9, max(0.1, Double(app - 40 + c.reputation / 2 - c.niveau * 8) / 100))
                if Double.random(in: 0...1) < chance {
                    let marque = SpeCatalogue.marques.randomElement() ?? "Ostra"
                    let gain = ref * 15 / 100
                    SpeMoteur.gagner(gain, &j)
                    c.gainsTotal += gain
                    c.reputation += Int.random(in: 4...7)
                    c.campagnes += 1
                    return .ok("📸 Casting décroché : campagne pour \(marque). \(Format.argent(gain)).")
                }
                j.stats.bonheur -= 4
                return .ok("📸 Trois heures d'attente, trente secondes devant le jury. « Merci, suivant. »")
            case .shooting:
                let gain = ref * 8 / 100
                SpeMoteur.gagner(gain, &j)
                c.gainsTotal += gain
                c.reputation += 2
                return .ok("📷 Shooting en studio de 7 h à 19 h. Le photographe dit « magnifique » à chaque déclenchement. \(Format.argent(gain)).")
            case .defile:
                guard c.niveau >= 2 else { return .refus("Les défilés, c'est à partir du rang « Défilés nationaux ».") }
                let gain = ref / 10
                SpeMoteur.gagner(gain, &j)
                c.gainsTotal += gain
                c.reputation += 5
                c.defiles += 1
                return .ok("👠 Défilé : douze secondes de podium, six heures de coiffure et de maquillage. Tu ne tombes pas. \(Format.argent(gain)).")
            case .soins:
                guard Shkurtaaa.peutPayer(1_500, solde: j.argent) else { return .refus("Il faut \(Format.argent(1_500)).") }
                j.argent -= 1_500
                j.stats.apparence += 3
                j.stats.sante += 1
                return .ok("🧴 Sommeil, sport, dermatologue, nutritionniste. Tu prends soin de toi sans te priver. Apparence +3.")
            case .reseaux:
                c.abonnes += 1_500 * (c.niveau + 1) + c.abonnes / 8
                c.reputation += 1
                return .ok("📱 Coulisses, tenues, une photo sans filtre qui touche beaucoup de gens. Tes abonnés grimpent.")
            case .agence:
                guard c.niveau < 5 else { return .refus("Tu es déjà tout en haut.") }
                let n = c.niveau + 1
                if c.reputation >= SpeCatalogue.seuilsReputation[n] - 5 && app >= SpeMoteur.apparenceRang[n] {
                    let ancienne = c.agence
                    let liste = SpeCatalogue.agences[n]
                    c.agence = liste.first { $0 != ancienne } ?? liste[0]
                    c.niveau = n
                    c.palmares.append("\(SpeCatalogue.rang(c, femme: j.genre == .femme)) à \(j.age) ans")
                    SignauxModules.signaler("spe_promotion", &j)
                    if n >= 4 { SignauxModules.signaler("celebrite", &j) }
                    return .ok("✍️ \(c.agence) te signe. Nouveau rang : \(SpeCatalogue.rang(c, femme: j.genre == .femme).lowercased()).")
                }
                return .ok("✍️ Les grandes agences regardent ton book… et te disent de revenir dans un an. (Réputation ou apparence insuffisante.)")
            }
        }
    }

    // MARK: - Cinéma

    func speEcrireScenario() -> String {
        speCarriereAction(.cinema, cle: "scenario") { c, e, j in
            c.scenarios += 1
            c.forme += 10
            j.stats.intelligence += 1
            return .ok("✍️ Tu écris un scénario de 110 pages, tu en jettes 40, tu réécris le reste. Il tient debout. (Scénarios prêts : \(c.scenarios))")
        }
    }

    func speMasterclass() -> String {
        speCarriereAction(.cinema, cle: "masterclass") { c, e, j in
            guard c.niveau >= 3 else { return .refus("On t'invitera quand tu seras reconnu\(j.genre == .femme ? "e" : "").") }
            let gain = SpeCatalogue.revenu(.cinema, c.niveau) / 10
            SpeMoteur.gagner(gain, &j)
            c.gainsTotal += gain
            c.reputation += 2
            return .ok("🎓 Masterclass devant 300 étudiants. Une question te fait réfléchir pendant des semaines. \(Format.argent(gain)).")
        }
    }

    func speTourner(titre: String, genre: String, taille: Int, casting: Int, autoFinance: Bool) -> String {
        speCarriereAction(.cinema, cle: "tournage") { c, e, j in
            if let p = c.projet { return .refus("Un film à la fois : « \(p.titre) » sort l'an prochain.") }
            let tl = min(3, max(0, taille))
            guard tl <= SpeMoteur.tailleMax(c) else {
                return .refus("Personne ne te confie un \(SpeCatalogue.taillesFilm[tl].lowercased()) pour l'instant.")
            }
            let cast = min(2, max(0, casting))
            let budget = Int(Double(SpeCatalogue.budgetsFilm[tl]) * (1 + SpeCatalogue.surcoutCasting[cast]))
            let auto = tl == 0 ? true : autoFinance
            if !auto && c.reputation < SpeMoteur.reputationProducteur[tl] {
                return .refus("Aucun producteur ne suit (réputation \(c.reputation), il faut \(SpeMoteur.reputationProducteur[tl])). Finance-le toi-même ou vise plus petit.")
            }
            if auto {
                guard Shkurtaaa.peutPayer(budget, solde: j.argent) else { return .refus("Il faut \(Format.argent(budget)) pour financer ce film.") }
                j.argent -= budget
            }
            let propre = titre.trimmingCharacters(in: .whitespacesAndNewlines)
            let t = propre.isEmpty ? SpeCatalogue.titreFilm(j.age &* 3 &+ c.films.count) : propre
            c.projet = SpeFilm(titre: t, genre: genre, taille: tl, budget: budget, casting: cast, autoFinance: auto, ageTournage: j.age)
            c.forme -= 20
            j.stats.sante -= 3
            return .ok("🎬 Premier clap de « \(t) » : \(SpeCatalogue.nomGenreFilm(genre).lowercased()), \(SpeCatalogue.taillesFilm[tl].lowercased()), \(SpeCatalogue.castings[cast].lowercased()). Budget \(Format.argent(budget))\(auto ? ", sur tes fonds" : ", payé par un producteur"). Sortie l'an prochain.")
        }
    }

    // MARK: - Musique

    enum SpeMusiqueAction: String {
        case ecrire, album, tournee, clip, caritatif, signer, quitterLabel
    }

    func speMusique(_ a: SpeMusiqueAction) -> String {
        speCarriereAction(.musique, cle: a.rawValue) { c, e, j in
            let talent = max(Competences.niveau("guitare", j), Competences.niveau("piano", j), Competences.niveau("chant", j))
            switch a {
            case .ecrire:
                let n = 2 + talent + c.forme / 40
                c.chansons += n
                c.forme -= 10
                let competence = c.genre == "rap" ? "eloquence" : "chant"
                var lignes = Competences.appliquer([competence: 3], &j)
                lignes.insert("✍️ Des nuits sur ton carnet et ton ordinateur. \(n) nouvelles chansons (\(c.chansons) en stock).", at: 0)
                return .ok(lignes.joined(separator: " "))
            case .album:
                guard c.chansons >= 8 else { return .refus("Il faut au moins 8 chansons pour un album (tu en as \(c.chansons)).") }
                let prix = c.label.isEmpty ? 2_500 * (c.niveau + 1) : 0
                if prix > 0 {
                    guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Le studio coûte \(Format.argent(prix)).") }
                    j.argent -= prix
                }
                var note = 30 + talent * 8 + c.forme / 4 + min(c.chansons, 20) + Int.random(in: -15...15)
                note = SpeMoteur.borne(note)
                let base = Double(max(300, c.fans / 2) + (c.label.isEmpty ? 0 : 5_000 * max(1, c.niveau)))
                let gainFans = Int(base * pow(Double(note) / 60, 2) * Double.random(in: 0.6...1.6))
                c.fans += gainFans
                let ventes = gainFans / 3 + c.fans / 20
                let certif = SpeMoteur.certifications.first { ventes >= $0.seuil }?.nom
                let titre = SpeCatalogue.titresAlbums[abs(j.age &* 5 &+ c.albums.count) % SpeCatalogue.titresAlbums.count]
                c.albums.append(SpeAlbum(titre: titre, age: j.age, note: note, ventes: ventes, certification: certif))
                c.chansons = max(0, c.chansons - 10)
                c.reputation += (note - 50) / 5
                c.forme -= 10
                if let cert = certif {
                    c.palmares.append("\(cert) pour « \(titre) »")
                    SignauxModules.signaler("spe_disque", &j)
                }
                let accueil = note >= 75 ? "La critique adore." : (note >= 50 ? "Accueil correct." : "La critique est dure.")
                var texte = "💿 Sortie de l'album « \(titre) » (note \(note)/100). \(accueil) \(ventes) ventes et streams équivalents, +\(gainFans) fans."
                if let cert = certif { texte += " 🏆 \(cert) !" }
                if prix > 0 { texte += " Studio : \(Format.argent(prix))." }
                return .ok(texte)
            case .tournee:
                guard c.niveau >= 1 else { return .refus("Personne n'achète encore de billets pour te voir. Commence par les scènes ouvertes.") }
                let gain = Int(Double(c.fans) * Double.random(in: 0.3...0.7)) + SpeCatalogue.revenu(.musique, c.niveau) / 5
                SpeMoteur.gagner(gain, &j)
                c.gainsTotal += gain
                c.fans += c.fans * 8 / 100
                c.forme -= 20
                j.stats.sante -= 6
                return .ok("🚐 Tournée : \(Int.random(in: 18...60)) dates, des nuits dans le bus, ta voix qui fatigue. \(Format.argent(gain)) et des fans en plus.")
            case .clip:
                let prix = 1_500 * (c.niveau + 1)
                guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Le clip coûte \(Format.argent(prix)).") }
                j.argent -= prix
                if Double.random(in: 0...1) < 0.12 {
                    let g = max(5_000, c.fans)
                    c.fans += g
                    c.reputation += 6
                    return .ok("🎥 Ton clip devient viral : une chorégraphie reprise partout. +\(g) fans en deux semaines. (\(Format.argent(prix)))")
                }
                c.fans += c.fans / 20 + 100
                return .ok("🎥 Clip tourné en une nuit dans un parking. Joli, mais l'algorithme en a décidé autrement. (\(Format.argent(prix)))")
            case .caritatif:
                c.fans += c.fans * 3 / 100 + 50
                j.stats.karma += 6
                j.stats.bonheur += 4
                return .ok("❤️ Concert gratuit pour une association. Personne ne filme le meilleur moment, et c'est très bien comme ça.")
            case .signer:
                guard !c.offreLabel.isEmpty else { return .refus("Aucun label ne t'a fait d'offre pour l'instant.") }
                c.label = c.offreLabel
                c.offreLabel = ""
                let avance = SpeCatalogue.revenu(.musique, max(2, c.niveau)) / 2
                SpeMoteur.gagner(avance, &j)
                c.gainsTotal += avance
                c.fans += c.fans / 5
                return .ok("✍️ Tu signes chez \(c.label). Avance : \(Format.argent(avance)). En échange, le label garde l'essentiel des streams et a son mot à dire sur tout.")
            case .quitterLabel:
                guard !c.label.isEmpty else { return .refus("Tu es déjà indépendant\(j.genre == .femme ? "e" : "").") }
                let ancien = c.label
                c.label = ""
                c.reputation -= 2
                return .ok("🚪 Tu quittes \(ancien). Tu gardes enfin tes revenus, mais plus personne ne paie la promo.")
            }
        }
    }

    // MARK: - Musée

    func speOuvrirMusee(nom: String, theme: String, taille: Int) -> String {
        speFaire { e, j in
            guard e.musee == nil else { return .refus("Tu as déjà un musée.") }
            guard j.age >= 21 else { return .refus("Dès 21 ans.") }
            let t = min(2, max(0, taille))
            let prix = SpeCatalogue.prixOuverture[t]
            guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Ouvrir un \(SpeCatalogue.taillesMusee[t].lowercased()) coûte \(Format.argent(prix)).") }
            let propre = nom.trimmingCharacters(in: .whitespacesAndNewlines)
            let n = propre.isEmpty ? "Musée \(j.nom)" : propre
            j.argent -= prix
            e.musee = SpeMusee(nom: n, theme: theme, taille: t, ageOuverture: j.age)
            j.stats.bonheur += 8
            SignauxModules.signaler("musee_ouvert", &j)
            return .ok("🏛️ Inauguration du \(n) (\(SpeCatalogue.nomTheme(theme).lowercased())). Ruban coupé, discours, petits fours. Les salles sont encore un peu vides.")
        }
    }

    func speAcheterOeuvre(_ o: SpeOeuvre) -> String {
        speFaire { e, j in
            guard var m = e.musee else { return .refus("Tu n'as pas de musée.") }
            guard m.collection.count < SpeCatalogue.capaciteOeuvres[min(3, m.taille)] else { return .refus("Les salles sont pleines. Agrandis le musée ou vends une pièce.") }
            guard !m.collection.contains(where: { $0.id == o.id }) else { return .refus("Elle est déjà dans ta collection.") }
            guard m.actionsAnnee.filter({ $0 == "achat" }).count < 3 else { return .refus("Trois acquisitions par an : le conseil scientifique a besoin de souffler.") }
            let prix = SpeMoteur.prixAchat(o)
            guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Il faut \(Format.argent(prix)) (frais de vente compris).") }
            j.argent -= prix
            m.collection.append(o)
            m.actionsAnnee.append("achat")
            m.notoriete = SpeMoteur.borne(m.notoriete + o.prestige / 3)
            e.musee = m
            return .ok("🖼️ Acquisition : « \(o.nom) » (\(o.auteur)) pour \(Format.argent(prix)). Elle rejoint les collections du \(m.nom).")
        }
    }

    func speVendreOeuvre(_ id: String) -> String {
        speFaire { e, j in
            guard var m = e.musee, let i = m.collection.firstIndex(where: { $0.id == id }) else { return .refus("Introuvable.") }
            let o = m.collection.remove(at: i)
            let prix = Int(Double(o.valeur) * Double.random(in: 0.8...1.3))
            SpeMoteur.gagner(prix, &j)
            m.notoriete = SpeMoteur.borne(m.notoriete - 2)
            e.musee = m
            return .ok("🔨 « \(o.nom) » part aux enchères pour \(Format.argent(prix)). Quelques habitués du musée t'écrivent leur tristesse.")
        }
    }

    enum SpeMuseeAction: String {
        case expo, gala, agrandir, donner, vendre
    }

    func speMusee(_ a: SpeMuseeAction) -> String {
        speFaire { e, j in
            guard var m = e.musee else { return .refus("Tu n'as pas de musée.") }
            if (a == .expo || a == .gala) && m.actionsAnnee.contains(a.rawValue) { return .refus("Déjà fait cette année.") }
            switch a {
            case .expo:
                let prix = 40_000 * (m.taille + 1) * (m.taille + 1)
                guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("Une exposition coûte \(Format.argent(prix)).") }
                j.argent -= prix
                let sujets = ["« Le corps en mouvement »", "« Rouge »", "« Machines rêvées »", "« Les oubliés de l'histoire »", "« Petits objets, grandes histoires »", "« Lumières du Nord »"]
                m.expoAnnee = sujets.randomElement() ?? "« Rouge »"
                m.notoriete = SpeMoteur.borne(m.notoriete + 5)
                m.actionsAnnee.append(a.rawValue)
                e.musee = m
                return .ok("🎟️ Exposition temporaire \(m.expoAnnee) : affiches dans le métro, file d'attente le week-end. Plus de visiteurs cette année. (\(Format.argent(prix)))")
            case .gala:
                let gain = (m.prestige * 2_000 + m.notoriete * 1_000) * (m.taille + 1)
                SpeMoteur.gagner(gain, &j)
                m.notoriete = SpeMoteur.borne(m.notoriete + 2)
                m.actionsAnnee.append(a.rawValue)
                e.musee = m
                return .ok("🥂 Gala de mécènes : discours, enchères silencieuses, un collectionneur qui s'endort. \(Format.argent(gain)) récoltés.")
            case .agrandir:
                guard m.taille < 3 else { return .refus("C'est déjà un musée national.") }
                let n = m.taille + 1
                if n == 3 && m.prestige < 70 { return .refus("Pour devenir musée national, il faut un prestige d'au moins 70 (tu as \(m.prestige)).") }
                let prix = SpeCatalogue.prixAgrandir[n]
                guard Shkurtaaa.peutPayer(prix, solde: j.argent) else { return .refus("L'agrandissement coûte \(Format.argent(prix)).") }
                j.argent -= prix
                m.taille = n
                e.musee = m
                return .ok("🏗️ Nouvelle aile inaugurée : le \(m.nom) devient un \(SpeCatalogue.taillesMusee[n].lowercased()). (\(Format.argent(prix)))")
            case .donner:
                e.anciensMusees.append("\(m.nom) (donné à l'État à \(j.age) ans)")
                e.musee = nil
                j.stats.karma += 25
                j.stats.bonheur += 10
                SignauxModules.signaler("musee_donne", &j)
                return .ok("🎁 Tu donnes le \(m.nom) et ses \(m.collection.count) œuvres à l'État. Une plaque à ton nom à l'entrée, pour toujours.")
            case .vendre:
                let valeur = SpeCatalogue.prixOuverture[min(2, m.taille)] * 6 / 10 + m.collection.reduce(0) { $0 + $1.valeur }
                SpeMoteur.gagner(valeur, &j)
                e.anciensMusees.append("\(m.nom) (vendu à \(j.age) ans)")
                e.musee = nil
                return .ok("💼 Tu vends le \(m.nom), bâtiment et collection, pour \(Format.argent(valeur)).")
            }
        }
    }

    func speMuseePrix(_ prix: Int) {
        modifier { j in
            guard var e = j.speciales, var m = e.musee else { return }
            m.prixBillet = max(0, min(40, prix))
            e.musee = m
            j.speciales = e
        }
    }

    // MARK: - Investissements

    func speInvestir(_ t: SpeInvestType, palier: Int) -> String {
        speFaire { e, j in
            guard j.age >= 18 else { return .refus("Dès 18 ans.") }
            let p = min(2, max(0, palier))
            let mise = t.paliers[p]
            guard Shkurtaaa.peutPayer(mise, solde: j.argent) else { return .refus("Il faut \(Format.argent(mise)).") }
            if t == .club && e.investissements.contains(where: { $0.type == .club && !$0.termine }) {
                return .refus("Tu présides déjà un club. Les supporters n'aiment pas les infidélités.")
            }
            j.argent -= mise
            let nom = SpeCatalogue.nomInvest(t, cle: j.age &* 7 &+ e.investissements.count)
            e.investissements.append(SpeInvest(type: t, nom: nom, mise: mise, valeur: mise, ageDebut: j.age))
            let texte: String
            switch t {
            case .combattant: texte = "🥊 Tu sponsorises \(nom) : \(Format.argent(mise)) pour son camp et ses déplacements, contre une part de ses bourses."
            case .film: texte = "🎞️ Tu coproduis \(nom) avec \(Format.argent(mise)). Ton nom sera au générique, en petit."
            case .album: texte = "💿 Tu finances \(nom) : \(Format.argent(mise)) de studio, de mixage et de promo."
            case .club: texte = "🏟️ Tu rachètes \(nom) pour \(Format.argent(mise)). Premier match en tribune présidentielle : on chante ton nom (pour l'instant)."
            case .agence: texte = "💄 Tu montes \(nom) avec \(Format.argent(mise)). Premier recrutement : une réceptionniste et un photographe."
            }
            return .ok(texte)
        }
    }

    func speRetirer(_ id: UUID) -> String {
        speFaire { e, j in
            guard let i = e.investissements.firstIndex(where: { $0.id == id && !$0.termine }) else { return .refus("Introuvable.") }
            var inv = e.investissements[i]
            guard inv.type != .film && inv.type != .album else { return .refus("Impossible de sortir avant la fin du projet.") }
            let gain = inv.valeur * 9 / 10
            SpeMoteur.gagner(gain, &j)
            inv.termine = true
            inv.dernier = "Revendu \(Format.argent(gain)) à \(j.age) ans (mise : \(Format.argent(inv.mise)))."
            e.investissements[i] = inv
            return .ok("💼 Tu revends ta part dans \(inv.nom) : \(Format.argent(gain)).")
        }
    }
}

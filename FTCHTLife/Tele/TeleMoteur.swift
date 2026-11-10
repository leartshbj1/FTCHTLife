import Foundation

// Jeux télé et téléréalité : règles du jeu. Voir docs/TELE.md.

// MARK: - Stockage de l'état

/// Où le module lit et écrit son état.
/// Par défaut : UserDefaults, une entrée par vie (le module marche sans toucher au moteur).
/// Quand le moteur aura ajouté `var tele: TeleEtat?` dans `Joueur`, il suffit de remplacer ces deux fonctions :
///     TeleStockage.lire = { $0.tele ?? TeleEtat() }
///     TeleStockage.ecrire = { j, etat in j.tele = etat }
enum TeleStockage {
    static var lire: (Joueur) -> TeleEtat = { j in
        guard let data = UserDefaults.standard.data(forKey: TeleStockage.cle(j)),
              let etat = try? JSONDecoder().decode(TeleEtat.self, from: data) else { return TeleEtat() }
        return etat
    }

    static var ecrire: (inout Joueur, TeleEtat) -> Void = { j, etat in
        if let data = try? JSONEncoder().encode(etat) {
            UserDefaults.standard.set(data, forKey: TeleStockage.cle(j))
        }
    }

    /// Une clé par vie : l'identifiant de la première année du journal ne change jamais.
    static func cle(_ j: Joueur) -> String {
        "ftchtlife.tele." + (j.journal.first?.id.uuidString ?? j.nomComplet)
    }
}

// MARK: - Partie en cours d'une émission à manches

enum TeleFin: Equatable {
    case elimine(manche: Int)
    case victoire
    case defaiteFinale
    case abandon
    case mort
}

struct TeleCandidat: Equatable {
    var prenom: String
    var genre: Genre
}

struct TelePartie: Identifiable, Equatable {
    let id = UUID()
    let emission: TeleEmission
    var manche = 0
    var situation: TeleSituation
    /// Texte de la situation, variables déjà remplacées.
    var texteSituation: String
    /// Résultat du dernier choix, variables déjà remplacées.
    var texteResultat: String?
    var pointsManche = 0
    var pointsTotal = 0
    var rival: TeleCandidat
    var crush: TeleCandidat
    var enCouple = false
    var celebriteGagnee = 0
    var cachets = 0
    var fin: TeleFin?
    /// Texte de fin (élimination, victoire…), variables remplacées.
    var texteFin: String?
    /// Vrai entre le résultat d'un choix et le passage à la manche suivante.
    var attenteSuite: Bool { texteResultat != nil }
    var derniereManche: Bool { manche == emission.manches.count - 1 }
}

// MARK: - Quiz

enum TeleQuiz {
    /// Gains de l'échelle, question par question.
    static let echelle = [200, 500, 1_000, 2_000, 5_000, 10_000, 20_000, 50_000, 100_000, 250_000]
    /// Index du palier : une fois cette question réussie, le gain est assuré.
    static let palier = 4
    static let secondesParQuestion = 25
    static let niveaux = [1, 1, 1, 2, 2, 2, 2, 3, 3, 3]

    /// Gain assuré si le joueur se trompe après avoir réussi `bonnes` questions.
    static func gainAssure(bonnes: Int) -> Int {
        bonnes > palier ? echelle[palier] : 0
    }

    static func tirerQuestions() -> [TeleQuestion] {
        var deja: Set<String> = []
        var liste: [TeleQuestion] = []
        for n in niveaux {
            let pool = TeleBibliotheque.questions.filter { $0.niveau == n && !deja.contains($0.id) }
            let secours = TeleBibliotheque.questions.filter { !deja.contains($0.id) }
            guard let q = pool.randomElement() ?? secours.randomElement() else { break }
            deja.insert(q.id)
            liste.append(q)
        }
        return liste
    }
}

// MARK: - Moteur

extension GameEngine {

    static let teleCandidatsH = ["Jordan", "Steevy", "Brandon", "Mickaël", "Kenzo", "Dimitri", "Jean-Kévin", "Valentin", "Tony", "Ryan", "Bryan", "Anthony"]
    static let teleCandidatsF = ["Kelly", "Shanna", "Vanessa", "Cindy", "Maëva", "Jessica", "Laura", "Nabilla-Rose", "Océane", "Sabrina", "Marine", "Ambre"]

    // MARK: État

    var teleEtat: TeleEtat {
        guard let j = joueur else { return TeleEtat() }
        return TeleStockage.lire(j)
    }

    func teleCelebrite() -> Int {
        guard let j = joueur else { return 0 }
        return TeleStockage.lire(j).celebrite(age: j.age)
    }

    /// Tags à ajouter à `tags(_:)` pour les événements de retombées (Events/tele_*.json).
    static func teleTags(_ j: Joueur) -> Set<String> {
        let e = TeleStockage.lire(j)
        let c = e.celebrite(age: j.age)
        var t: Set<String> = []
        if e.participations > 0 { t.insert("tv_candidat") }
        if c >= 40 { t.insert("tv_star") }
        if e.participations > 0 && c < 15 { t.insert("tv_has_been") }
        if e.victoires > 0 { t.insert("tv_winner") }
        if !e.momentsCultes.isEmpty { t.insert("tv_culte") }
        return t
    }

    /// Variables du module : {emission}, {rival}, {crush}, {manche}, {gain}, {culte}, {celebrite}.
    /// Le moteur peut l'appeler dans `remplir` pour que les événements de retombées puissent utiliser {culte}.
    static func teleRemplir(_ texte: String, _ j: Joueur, partie: TelePartie? = nil, gain: Int? = nil) -> String {
        var t = texte
        let etat = TeleStockage.lire(j)
        if let p = partie {
            t = t.replacingOccurrences(of: "{emission}", with: p.emission.nom)
            t = t.replacingOccurrences(of: "{rival}", with: p.rival.prenom)
            t = t.replacingOccurrences(of: "{crush}", with: p.crush.prenom)
            t = t.replacingOccurrences(of: "{manche}", with: p.emission.manches.indices.contains(p.manche) ? p.emission.manches[p.manche].titre.lowercased() : "la finale")
        }
        if let g = gain { t = t.replacingOccurrences(of: "{gain}", with: Format.argent(g)) }
        t = t.replacingOccurrences(of: "{culte}", with: etat.momentsCultes.last ?? "ton passage à la télé")
        t = t.replacingOccurrences(of: "{celebrite}", with: "\(etat.celebrite(age: j.age))")
        return t
    }

    private func teleTexte(_ texte: String, _ j: Joueur, _ partie: TelePartie? = nil, gain: Int? = nil) -> String {
        remplir(GameEngine.teleRemplir(texte, j, partie: partie, gain: gain), j)
    }

    /// Valeur d'une statistique pour les tests (0…100).
    func teleValeur(_ stat: String, _ j: Joueur, _ etat: TeleEtat) -> Int {
        switch stat {
        case "sante": return j.stats.sante
        case "bonheur": return j.stats.bonheur
        case "intelligence": return j.stats.intelligence
        case "apparence": return j.stats.apparence
        case "karma": return j.stats.karma
        case "charisme": return (j.stats.apparence + j.stats.bonheur) / 2
        case "voix": return etat.talentVoix
        case "cuisine": return etat.talentCuisine
        case "celebrite": return etat.celebrite(age: j.age)
        default: return 50
        }
    }

    /// Chance de réussir un test : 50 % quand la stat égale la difficulté.
    static func teleChance(valeur: Int, difficulte: Int) -> Double {
        min(0.92, max(0.08, 0.5 + Double(valeur - difficulte) / 110))
    }

    private func teleEnregistrer(_ j: inout Joueur, _ etat: TeleEtat) {
        TeleStockage.ecrire(&j, etat)
    }

    // MARK: Disponibilité

    static let teleCleQuiz = "tele_quiz"

    func teleCleAnnee(_ e: TeleEmission) -> String { "tele_" + e.id }

    /// nil si l'émission est disponible, sinon la raison.
    func teleIndisponible(_ e: TeleEmission) -> String? {
        guard let j = joueur, j.vivant else { return "Tu es mort·e. Même la télé ne veut plus de toi." }
        if j.age < e.ageMin { return "À partir de \(e.ageMin) ans." }
        if j.age > e.ageMax { return "Réservé aux moins de \(e.ageMax + 1) ans. La prod veut du sang neuf." }
        if j.actionsAnnee.contains(teleCleAnnee(e)) { return "Déjà tenté cette année." }
        return nil
    }

    func teleQuizIndisponible() -> String? {
        guard let j = joueur, j.vivant else { return "Tu es mort·e." }
        if j.age < 10 { return "À partir de 10 ans." }
        if j.actionsAnnee.contains(Self.teleCleQuiz) { return "Déjà joué cette année." }
        return nil
    }

    // MARK: Émissions à manches

    /// Passe le casting. Renvoie la partie si le joueur est pris, sinon le texte du refus.
    func teleCasting(_ e: TeleEmission) -> (partie: TelePartie?, texte: String) {
        guard var j = joueur, teleIndisponible(e) == nil, let premiere = e.manches.first?.situations.randomElement() else {
            return (nil, "Le casting est fermé.")
        }
        var etat = TeleStockage.lire(j)
        j.actionsAnnee.append(teleCleAnnee(e))
        let chance = Self.teleChance(valeur: teleValeur(e.casting.stat, j, etat), difficulte: e.casting.difficulte)
            + Double(etat.celebrite(age: j.age)) / 400
        let genreRival = Genre.allCases.randomElement()!
        let genreCrush: Genre = Double.random(in: 0...1) < 0.8 ? (j.genre == .homme ? .femme : .homme) : j.genre
        var partie = TelePartie(
            emission: e, situation: premiere, texteSituation: "",
            rival: TeleCandidat(prenom: Self.teleNomCandidat(genreRival), genre: genreRival),
            crush: TeleCandidat(prenom: Self.teleNomCandidat(genreCrush), genre: genreCrush))
        if partie.crush.prenom == partie.rival.prenom {
            partie.crush.prenom = Self.teleNomCandidat(genreCrush == .homme ? .femme : .homme)
        }

        guard Double.random(in: 0...1) < chance else {
            let texte = teleTexte(e.casting.refus.randomElement() ?? "La production ne t'a jamais rappelé·e.", j, partie)
            ajouterLigne(&j, "📺 Casting de « \(e.nom) » : refusé. " + texte)
            // On enregistre quand même : les talents cachés tirés pour ce casting restent ceux de cette vie.
            teleEnregistrer(&j, etat)
            joueur = j
            sauvegarder()
            return (nil, texte)
        }

        etat.participations += 1
        etat.derniereApparition = j.age
        if !etat.emissionsFaites.contains(e.id) { etat.emissionsFaites.append(e.id) }
        teleEnregistrer(&j, etat)
        joueur = j
        sauvegarder()

        let intro = teleTexte(e.casting.acceptes.randomElement() ?? "Tu es pris·e !", j, partie)
            + "\n\n" + teleTexte(e.intro.randomElement() ?? "", j, partie)
        partie.texteSituation = intro + "\n\n" + teleTexte(premiere.texte, j, partie)
        return (partie, intro)
    }

    static func teleNomCandidat(_ g: Genre) -> String {
        (g == .homme ? teleCandidatsH : teleCandidatsF).randomElement()!
    }

    /// Le joueur fait un choix dans la situation en cours.
    func teleChoisir(_ p: inout TelePartie, _ index: Int) {
        guard p.fin == nil, !p.attenteSuite, p.situation.choix.indices.contains(index), var j = joueur, j.vivant else { return }
        var etat = TeleStockage.lire(j)
        let c = p.situation.choix[index]
        let chance = Self.teleChance(valeur: teleValeur(c.stat, j, etat), difficulte: c.difficulte)
        let reussi = Double.random(in: 0...1) < chance
        let pool = reussi ? c.reussite : c.echec
        let r = pool.randomElement() ?? TeleResultat(texte: reussi ? "Ça passe." : "Ça casse.", points: reussi ? 1 : -1)

        p.pointsManche += r.points
        p.pointsTotal += r.points
        var texte = teleTexte(r.texte, j, p)
        if let eff = r.effets {
            appliquer(eff, &j)
            if let f = eff.fame, f != 0 {
                etat.ajouterCelebrite(f, age: j.age)
                p.celebriteGagnee += f
            }
        }
        if let culte = r.culte {
            let moment = teleTexte(culte, j, p)
            etat.momentsCultes.append(moment)
            if etat.momentsCultes.count > 12 { etat.momentsCultes.removeFirst() }
            etat.humiliations += 1
            etat.ajouterCelebrite(6, age: j.age)
            p.celebriteGagnee += 6
            texte += "\n\n🎬 Moment culte : « \(moment) ». Internet ne l'oubliera jamais."
        }
        if r.couple == true && !p.enCouple {
            p.enCouple = true
            texte += "\n\n💘 Tu es en couple avec \(p.crush.prenom) dans l'émission."
        }
        if r.rupture == true && p.enCouple {
            p.enCouple = false
            texte += "\n\n💔 Ton couple avec \(p.crush.prenom), c'est fini. Devant 4 millions de personnes."
        }
        p.texteResultat = texte
        teleEnregistrer(&j, etat)
        joueur = j
        sauvegarder()

        if !j.vivant {
            p.fin = .mort
            p.texteFin = "L'émission a été déprogrammée. Hommage à la fin du générique."
        }
    }

    /// Après le résultat : verdict de la manche, puis manche suivante ou fin.
    func teleSuite(_ p: inout TelePartie) {
        guard p.fin == nil, p.attenteSuite, var j = joueur, j.vivant else { return }
        var etat = TeleStockage.lire(j)

        // Cachet et célébrité de la manche.
        j.argent += p.emission.cachet
        p.cachets += p.emission.cachet
        let gloire = 3 + max(0, p.pointsManche)
        etat.ajouterCelebrite(gloire, age: j.age)
        p.celebriteGagnee += gloire

        if p.derniereManche {
            let chance = min(0.9, max(0.08, 0.35 + 0.12 * Double(p.pointsManche) + 0.03 * Double(p.pointsTotal)))
            if Double.random(in: 0...1) < chance {
                p.fin = .victoire
                j.argent += p.emission.prix
                etat.victoires += 1
                etat.gainsTotaux += p.emission.prix
                etat.ajouterCelebrite(p.emission.celebriteVictoire, age: j.age)
                p.celebriteGagnee += p.emission.celebriteVictoire
                j.stats.bonheur += 20
                p.texteFin = teleTexte(p.emission.victoires.randomElement() ?? "Tu as gagné !", j, p, gain: p.emission.prix)
            } else {
                p.fin = .defaiteFinale
                j.stats.bonheur -= 5
                p.texteFin = teleTexte(p.emission.defaitesFinale.randomElement() ?? "Tu perds en finale.", j, p)
            }
        } else {
            let survie = min(0.95, max(0.05, 0.55 + 0.15 * Double(p.pointsManche) + (p.manche == 0 ? 0.1 : 0)))
            if Double.random(in: 0...1) < survie {
                p.manche += 1
                p.pointsManche = 0
                p.texteResultat = nil
                if let s = p.emission.manches[p.manche].situations.randomElement() {
                    p.situation = s
                    p.texteSituation = teleTexte(s.texte, j, p)
                }
                etat.gainsTotaux += p.emission.cachet
                teleEnregistrer(&j, etat)
                joueur = j
                sauvegarder()
                return
            }
            p.fin = .elimine(manche: p.manche)
            j.stats.bonheur -= 6
            p.texteFin = teleTexte(p.emission.eliminations.randomElement() ?? "Tu es éliminé·e.", j, p)
        }
        etat.gainsTotaux += p.emission.cachet
        j.stats.borner()
        teleEnregistrer(&j, etat)
        joueur = j
        teleTerminer(&p)
    }

    /// Quitter l'émission en cours de route.
    func teleAbandonner(_ p: inout TelePartie) {
        guard p.fin == nil, var j = joueur else { return }
        p.fin = .abandon
        j.stats.bonheur -= 3
        var etat = TeleStockage.lire(j)
        etat.momentsCultes.append("l'abandon en larmes de \(j.prenom) dans « \(p.emission.nom) »")
        etat.humiliations += 1
        etat.ajouterCelebrite(4, age: j.age)
        p.celebriteGagnee += 4
        j.stats.borner()
        teleEnregistrer(&j, etat)
        joueur = j
        p.texteFin = "Tu as quitté l'aventure. La production a gardé les images de ta sortie, au ralenti, avec un violon."
        teleTerminer(&p)
    }

    /// Écrit le résumé dans le journal et gère le couple formé à l'écran.
    private func teleTerminer(_ p: inout TelePartie) {
        guard var j = joueur else { return }
        let nb = p.emission.manches.count
        var resume = "📺 « \(p.emission.nom) » : "
        switch p.fin {
        case .victoire: resume += "tu as GAGNÉ ! +\(Format.argent(p.emission.prix))."
        case .defaiteFinale: resume += "battu·e en finale."
        case .elimine(let m): resume += "éliminé·e à l'étape \(m + 1) sur \(nb)."
        case .abandon: resume += "abandon à l'étape \(p.manche + 1) sur \(nb)."
        case .mort, nil: resume += "tournage interrompu."
        }
        if p.cachets > 0 { resume += " Cachets : \(Format.argent(p.cachets))." }
        if p.celebriteGagnee > 0 { resume += " Célébrité +\(p.celebriteGagnee)." }
        ajouterLigne(&j, resume)

        if p.enCouple && j.vivant {
            let aDejaQuelquun = j.relations.contains { $0.type == .partenaire && $0.vivant }
            if aDejaQuelquun {
                for i in j.relations.indices where j.relations[i].type == .partenaire && j.relations[i].vivant {
                    j.relations[i].lien = Stats.borne(j.relations[i].lien - 35)
                }
                ajouterLigne(&j, "\(j.relations.first { $0.type == .partenaire && $0.vivant }?.prenom ?? "Ton couple") a tout vu à la télé. Ton histoire avec \(p.crush.prenom) passe très mal à la maison.")
            } else {
                j.relations.append(Relation(prenom: p.crush.prenom, nom: Donnees.noms.randomElement()!, genre: p.crush.genre,
                                            type: .partenaire, age: max(18, j.age + Int.random(in: -4...4)), lien: Int.random(in: 55...80)))
                ajouterLigne(&j, "💘 Tu sors de l'émission en couple avec \(p.crush.prenom). Les magazines parient sur trois mois.")
            }
        }
        joueur = j
        sauvegarder()
    }

    // MARK: Quiz

    /// Casting du quiz (facile). Renvoie nil si le joueur est pris, sinon le texte du refus.
    func teleQuizCasting() -> String? {
        guard var j = joueur, teleQuizIndisponible() == nil else { return "Le plateau est fermé." }
        j.actionsAnnee.append(Self.teleCleQuiz)
        let etat = TeleStockage.lire(j)
        let chance = Self.teleChance(valeur: (j.stats.intelligence + j.stats.bonheur) / 2, difficulte: 15) + Double(etat.celebrite(age: j.age)) / 400
        if Double.random(in: 0...1) >= chance || TeleBibliotheque.questions.count < TeleQuiz.niveaux.count {
            let refus = [
                "Au casting, tu as répondu « Napoléon » à toutes les questions, même « Comment tu t'appelles ? ». Refusé·e.",
                "La production a trouvé que tu « manquais de peps ». Tu as hoché la tête sans peps.",
                "Tu as raté le casting : tu cherchais le studio dans le mauvais bâtiment, puis dans la mauvaise ville.",
            ]
            let texte = refus.randomElement()!
            ajouterLigne(&j, "📺 Casting de « Cerveau ou Râteau » : refusé. " + texte)
            joueur = j
            sauvegarder()
            return texte
        }
        joueur = j
        sauvegarder()
        return nil
    }

    /// Fin du quiz. `bonnes` = nombre de bonnes réponses ; `encaisse` = vrai si le joueur s'est arrêté de lui-même.
    @discardableResult
    func teleQuizFin(bonnes: Int, encaisse: Bool, derniereQuestion: TeleQuestion?) -> String {
        guard var j = joueur else { return "" }
        var etat = TeleStockage.lire(j)
        let total = TeleQuiz.echelle.count
        let gain: Int
        if bonnes >= total { gain = TeleQuiz.echelle[total - 1] }
        else if encaisse { gain = bonnes > 0 ? TeleQuiz.echelle[bonnes - 1] : 0 }
        else { gain = TeleQuiz.gainAssure(bonnes: bonnes) }

        var texte: String
        if bonnes >= total {
            texte = "🏆 SANS-FAUTE ! Tu repars avec \(Format.argent(gain)). Le présentateur pleure, les confettis tombent, ta mère appelle tout le quartier."
        } else if encaisse {
            texte = gain > 0
                ? "Tu t'arrêtes avec \(Format.argent(gain)). Sage décision. Le public hue un peu, par principe."
                : "Tu repars sans rien, mais avec ta dignité. C'est déjà ça."
        } else if bonnes == 0 {
            texte = "Râteau dès la première question, à 200 €. Le présentateur a dû retenir un rire. Il n'a pas réussi."
            etat.momentsCultes.append("le râteau à 200 € de \(j.prenom) dans « Cerveau ou Râteau »")
            etat.humiliations += 1
        } else {
            texte = "Mauvaise réponse ! La trappe s'ouvre sous tes pieds. "
                + (gain > 0 ? "Heureusement, tu gardes le palier : \(Format.argent(gain))." : "Tu repars avec zéro euro et un bleu à la fesse.")
        }
        if let q = derniereQuestion, !encaisse, bonnes < total {
            texte += "\nLa bonne réponse était : \(q.bonne)."
        }

        if gain > 0 {
            if j.age < 18 {
                let garde = gain / 2
                j.argent += garde
                texte += "\nTu es mineur·e : tes parents « placent » l'autre moitié. Ils ont acheté un jacuzzi."
            } else {
                j.argent += gain
            }
            etat.gainsTotaux += gain
        }
        etat.recordQuiz = max(etat.recordQuiz, gain)
        etat.participations += 1
        etat.derniereApparition = j.age
        if bonnes >= total { etat.victoires += 1 }
        let gloire = bonnes >= total ? 30 : (bonnes == 0 ? 8 : 2 + bonnes * 2)
        etat.ajouterCelebrite(gloire, age: j.age)
        j.stats.bonheur += bonnes >= 7 ? 12 : (bonnes == 0 ? -8 : 2)
        j.stats.intelligence += bonnes >= 5 ? 2 : 0
        if !etat.emissionsFaites.contains("quiz") { etat.emissionsFaites.append("quiz") }

        j.stats.borner()
        ajouterLigne(&j, "📺 « Cerveau ou Râteau » : \(bonnes) bonne\(bonnes > 1 ? "s" : "") réponse\(bonnes > 1 ? "s" : ""), gain \(Format.argent(gain)). Célébrité +\(gloire).")
        teleEnregistrer(&j, etat)
        joueur = j
        sauvegarder()
        return texte
    }

    /// Joker « Appel à un proche » : le nom du proche et la réponse qu'il donne.
    func teleQuizAppel(_ q: TeleQuestion) -> (nom: String, reponse: String, sur: Bool) {
        let j = joueur
        let proches = (j?.relations ?? []).filter { $0.vivant && $0.type != .enfant && $0.age >= 12 }
        let p = proches.max { a, b in a.lien + Int.random(in: 0...40) < b.lien + Int.random(in: 0...40) }
        let nom = p?.prenom ?? "Ton voisin"
        let fiabilite = q.niveau == 1 ? 0.85 : (q.niveau == 2 ? 0.65 : 0.45)
        if Double.random(in: 0...1) < fiabilite {
            return (nom, q.bonne, Double.random(in: 0...1) < 0.7)
        }
        return (nom, q.mauvaises.randomElement() ?? q.bonne, Double.random(in: 0...1) < 0.3)
    }

    /// Joker « Le public » : pourcentages par réponse, dans l'ordre donné.
    static func teleQuizPublic(_ q: TeleQuestion, reponses: [String]) -> [Int] {
        let force = q.niveau == 1 ? 55.0 : (q.niveau == 2 ? 38.0 : 24.0)
        var poids = reponses.map { $0 == q.bonne ? force + Double.random(in: 0...25) : Double.random(in: 5...30) }
        let total = poids.reduce(0, +)
        poids = poids.map { $0 / total * 100 }
        var pc = poids.map { Int($0.rounded()) }
        if let i = pc.indices.max(by: { pc[$0] < pc[$1] }) { pc[i] += 100 - pc.reduce(0, +) }
        return pc
    }

    // MARK: Offres de célébrité

    func teleOffres() -> [TeleOffre] {
        guard let j = joueur, j.vivant else { return [] }
        let c = TeleStockage.lire(j).celebrite(age: j.age)
        return TeleBibliotheque.offres.filter { c >= $0.celebriteMin && j.age >= $0.ageMin }
    }

    func teleOffreDisponible(_ o: TeleOffre) -> Bool {
        guard let j = joueur, j.vivant else { return false }
        return !j.actionsAnnee.contains("tele_offre_" + o.id)
    }

    /// Accepte une offre et renvoie le texte du résultat.
    func teleAccepterOffre(_ o: TeleOffre) -> String {
        guard var j = joueur, j.vivant, teleOffreDisponible(o) else { return "" }
        var etat = TeleStockage.lire(j)
        j.actionsAnnee.append("tele_offre_" + o.id)
        let c = etat.celebrite(age: j.age)
        let rate = Double.random(in: 0...1) < (o.risque ?? 0)
        let texte: String
        if rate {
            texte = teleTexte(o.textesRates?.randomElement() ?? "Ça a mal tourné.", j)
            if let eff = o.effetsRates {
                appliquer(eff, &j)
                if let f = eff.fame { etat.ajouterCelebrite(f, age: j.age) }
            }
        } else {
            let mini = o.gain.first ?? 0, maxi = max(mini, o.gain.last ?? mini)
            let gain = Int(Double(Int.random(in: mini...maxi)) * max(0.3, Double(c) / 50))
            j.argent += gain
            etat.gainsTotaux += gain
            texte = teleTexte(o.textes.randomElement() ?? "Tu encaisses {gain}.", j, gain: gain)
            if let eff = o.effets {
                appliquer(eff, &j)
                if let f = eff.fame { etat.ajouterCelebrite(f, age: j.age) }
            }
        }
        ajouterLigne(&j, "⭐ " + o.titre + " : " + texte)
        teleEnregistrer(&j, etat)
        joueur = j
        sauvegarder()
        return texte
    }
}

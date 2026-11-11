import Foundation

// Actions avec les proches qui ouvrent tout de suite une carte de choix (module Cœur).
// Données : Resources/Data/CoeurCartes/*.json. Voir docs/COEUR.md, section « Cartes d'action ».

/// Une carte de suite d'action : un événement normal, plus l'action qui l'ouvre et l'âge de la personne visée.
struct CoeurCarte: Decodable {
    var action: String
    var cibleMinAge: Int?
    var cibleMaxAge: Int?
    /// "male" / "female" : genre de la personne visée.
    var cibleGenre: String?
    var evenement: Evenement

    enum CodingKeys: String, CodingKey { case action, cibleMinAge, cibleMaxAge, cibleGenre }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        action = try c.decode(String.self, forKey: .action)
        cibleMinAge = try c.decodeIfPresent(Int.self, forKey: .cibleMinAge)
        cibleMaxAge = try c.decodeIfPresent(Int.self, forKey: .cibleMaxAge)
        cibleGenre = try c.decodeIfPresent(String.self, forKey: .cibleGenre)
        evenement = try Evenement(from: decoder)
    }
}

enum CoeurCartes {
    static let toutes: [CoeurCarte] = DonneesJSON.chargerTableaux(dossier: "CoeurCartes", type: CoeurCarte.self)
}

/// Une carte prête à être montrée (texte déjà rempli).
struct CoeurCartePrete: Identifiable, Equatable {
    let id = UUID()
    let evenement: Evenement
    let texte: String
    /// Ce que l'action a fait avant la carte (affiché en haut).
    let intro: String
}

enum CoeurActionProche: String, CaseIterable, Identifiable {
    // Partenaire
    case conversation, nuit, anniversaire, avenir, surprise, contraception, therapie, vendre, insulter, rompre
    // Enfants
    case jouer, devoirs, parlerVie, punir, argentPoche, conduite, conseilAdulte
    // Parents, fratrie, amis
    case visite, sortie

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .conversation: return "Avoir une conversation"
        case .nuit: return "Faire l'amour"
        case .anniversaire: return "Fêter un anniversaire"
        case .avenir: return "Parler de l'avenir"
        case .surprise: return "Préparer une surprise"
        case .contraception: return "Parler de contraception"
        case .therapie: return "Thérapie de couple"
        case .vendre: return "Lui vendre quelque chose"
        case .insulter: return "Insulter"
        case .rompre: return "Rompre"
        case .jouer: return "Jouer ensemble"
        case .devoirs: return "Aider aux devoirs"
        case .parlerVie: return "Avoir une vraie discussion"
        case .punir: return "Punir une bêtise"
        case .argentPoche: return "Parler d'argent de poche"
        case .conduite: return "Lui apprendre à conduire"
        case .conseilAdulte: return "Prendre des nouvelles"
        case .visite: return "Rendre visite"
        case .sortie: return "Sortir ensemble"
        }
    }

    var icone: String {
        switch self {
        case .conversation: return "bubble.left.and.bubble.right.fill"
        case .nuit: return "moon.stars.fill"
        case .anniversaire: return "birthday.cake.fill"
        case .avenir: return "sparkles"
        case .surprise: return "gift.fill"
        case .contraception: return "pills.fill"
        case .therapie: return "cross.case.fill"
        case .vendre: return "tag.fill"
        case .insulter: return "hand.thumbsdown.fill"
        case .rompre: return "heart.slash.fill"
        case .jouer: return "gamecontroller.fill"
        case .devoirs: return "book.fill"
        case .parlerVie: return "bubble.left.and.bubble.right.fill"
        case .punir: return "hand.raised.fill"
        case .argentPoche: return "eurosign.circle.fill"
        case .conduite: return "car.fill"
        case .conseilAdulte: return "phone.fill"
        case .visite: return "house.fill"
        case .sortie: return "figure.walk"
        }
    }

    /// Les actions possibles avec cette personne.
    static func pour(_ r: Relation, _ j: Joueur) -> [CoeurActionProche] {
        guard r.vivant, !j.vieEtat.justice.enPrison else { return [] }
        switch r.type {
        case .partenaire:
            let t = CoeurSysteme.tags(j)
            var a: [CoeurActionProche] = [.conversation]
            if j.age >= 18 && r.age >= 18 { a.append(.nuit) }
            a.append(.anniversaire)
            if j.age >= 16 { a += [.avenir, .surprise] }
            if j.age >= 16 && r.age >= 16 && t.contains("contraception_possible") { a.append(.contraception) }
            if j.age >= 18 && j.coeurEtat.therapie == 0 { a.append(.therapie) }
            if j.age >= 16 { a.append(.vendre) }
            a.append(.insulter)
            // Le divorce reste dans « Plus d'actions » ; un couple protégé (âme sœur) ne rompt jamais.
            if j.vieEtat.statutCouple != .marie && !CoeurSysteme.estProtege(j) && !AmeSoeur.estAmeSoeur(r, j) {
                a.append(.rompre)
            }
            return a
        case .enfant:
            guard j.age >= 16 else { return [] }
            var a: [CoeurActionProche] = []
            if r.age <= 12 { a.append(.jouer) }
            if (6...17).contains(r.age) { a.append(.devoirs) }
            if (11...20).contains(r.age) { a.append(.parlerVie) }
            if (4...17).contains(r.age) { a.append(.punir) }
            if (8...25).contains(r.age) { a.append(.argentPoche) }
            if (16...22).contains(r.age) { a.append(.conduite) }
            if r.age >= 18 { a.append(.conseilAdulte) }
            return a
        case .mere, .pere:
            return j.age >= 18 ? [.visite] : []
        case .frere, .soeur, .ami:
            return j.age >= 12 ? [.sortie] : []
        case .ex:
            return []
        }
    }
}

extension CoeurActionProche {
    /// Grande icône des lignes de la fiche du/de la partenaire.
    var emoji: String {
        switch self {
        case .conversation: return "💬"
        case .nuit: return "❤️‍🔥"
        case .anniversaire: return "🎂"
        case .avenir: return "🔮"
        case .surprise: return "🎁"
        case .contraception: return "💊"
        case .therapie: return "🛋️"
        case .vendre: return "🏷️"
        case .insulter: return "🤬"
        case .rompre: return "💔"
        case .jouer: return "🧸"
        case .devoirs: return "📚"
        case .parlerVie: return "🗣️"
        case .punir: return "✋"
        case .argentPoche: return "💶"
        case .conduite: return "🚗"
        case .conseilAdulte: return "📞"
        case .visite: return "🏠"
        case .sortie: return "🚶"
        }
    }

    /// Petite phrase sous le titre.
    func sousTitre(_ r: Relation, _ j: Joueur) -> String {
        switch self {
        case .conversation: return "Parler de tout, de rien, ou de ce qui fâche"
        case .nuit: return "Une nuit rien qu'à vous deux"
        case .anniversaire:
            let n = j.vieEtat.anneesEnsemble
            return n >= 1 ? "Le sien, ou vos \(n) an\(n > 1 ? "s" : "") ensemble" : "Le sien : \(r.age) ans, ça se fête"
        case .avenir: return "Enfants, maison, projets…"
        case .surprise: return "Fleurs, voyage, petit mot…"
        case .contraception:
            if let m = CoeurSysteme.contraceptionActive(j) { return "En ce moment : \(CoeurSysteme.nomContraception(m))" }
            return "Pilule, stérilet, implant, préservatifs…"
        case .therapie: return "Un psy pour vous deux (150 € la séance)"
        case .vendre: return "Ta vieille voiture, une montre, un plan foireux…"
        case .insulter: return "Dire ce que tu penses. Vraiment."
        case .rompre: return j.vieEtat.statutCouple == .fiance ? "Annuler les fiançailles et partir" : "Mettre fin à votre histoire"
        default: return ""
        }
    }
}

@MainActor
enum CoeurActionsSysteme {

    /// Chance qu'une carte suive l'action (sinon juste un petit texte).
    static func chanceCarte(_ a: CoeurActionProche) -> Double {
        switch a {
        case .nuit, .parlerVie, .avenir, .conversation, .anniversaire, .contraception, .therapie, .vendre, .insulter, .rompre: return 1
        case .punir, .conduite, .argentPoche: return 0.85
        default: return 0.7
        }
    }

    static func cleAnnee(_ a: CoeurActionProche, _ id: UUID) -> String { "coeur_\(a.rawValue)_\(id.uuidString)" }

    static func dejaFait(_ a: CoeurActionProche, _ id: UUID, _ j: Joueur) -> Bool {
        // On peut toujours tenter de rompre, même après avoir renoncé.
        a != .rompre && j.actionsAnnee.contains(cleAnnee(a, id))
    }

    /// Cartes possibles pour cette action et cette personne.
    static func cartes(_ a: CoeurActionProche, _ r: Relation, _ j: Joueur, engine: GameEngine) -> [Evenement] {
        let t = engine.tags(j)
        return CoeurCartes.toutes.filter { c in
            guard c.action == a.rawValue else { return false }
            if let m = c.cibleMinAge, r.age < m { return false }
            if let m = c.cibleMaxAge, r.age > m { return false }
            if c.cibleGenre == "male" && r.genre != .homme { return false }
            if c.cibleGenre == "female" && r.genre != .femme { return false }
            return engine.conditionsRemplies(c.evenement, j, tags: t)
        }.map(\.evenement)
    }

    /// Fait l'action : petit effet immédiat, puis peut-être une carte à choix.
    static func faire(_ a: CoeurActionProche, sur id: UUID, _ j: inout Joueur, engine: GameEngine) -> (texte: String, carte: CoeurCartePrete?) {
        guard let i = j.relations.firstIndex(where: { $0.id == id }) else { return ("", nil) }
        let r = j.relations[i]
        if dejaFait(a, id, j) { return ("Tu l'as déjà fait cette année avec \(r.prenom).", nil) }
        if a != .rompre { j.actionsAnnee.append(cleAnnee(a, id)) }

        var c = j.coeurEtat
        c.cibleCarte = id
        j.coeurEtat = c

        // Insulter ou rompre ne rapproche pas ; le reste donne un petit bonus de lien.
        if ![.insulter, .rompre, .vendre].contains(a) {
            j.relations[i].lien = Stats.borne(r.lien + Int.random(in: 1...4))
        }
        let intro = phraseIntro(a, r)
        let possibles = cartes(a, j.relations[i], j, engine: engine)
        if !possibles.isEmpty, VieHasard.reussi(chanceCarte(a)),
           let e = GameEngine.tirage(possibles, poids: { $0.weight ?? 1 }) {
            if e.unique == true { j.evenementsVus.append(e.id) }
            let texte = engine.remplir(e.text, j)
            return (intro, CoeurCartePrete(evenement: e, texte: texte, intro: intro))
        }
        if a == .rompre {
            // Sans carte (ne devrait pas arriver) : rupture simple.
            let l = VieRelations.rompre(&j, parLeJoueur: true).joined(separator: " ")
            engine.ajouterLigne(&j, l)
            return (l, nil)
        }
        if a == .insulter {
            j.relations[i].lien = Stats.borne(j.relations[i].lien - Int.random(in: 6...12))
            engine.ajouterLigne(&j, intro)
            return (intro, nil)
        }
        j.stats.bonheur += 2
        engine.ajouterLigne(&j, intro)
        return (intro, nil)
    }

    static func phraseIntro(_ a: CoeurActionProche, _ r: Relation) -> String {
        let n = r.prenom
        switch a {
        case .conversation: return "Tu poses ton téléphone et tu t'assois avec \(n)."
        case .nuit: return "Soirée en tête-à-tête avec \(n). Bougies, musique douce, téléphone retourné."
        case .anniversaire: return "Un anniversaire à fêter avec \(n)."
        case .avenir: return "Tu t'assois avec \(n) pour parler de l'avenir. Le vrai."
        case .surprise: return "Tu prépares une surprise pour \(n)."
        case .contraception: return "Sujet sérieux ce soir avec \(n) : la contraception."
        case .therapie: return "Tu proposes à \(n) d'aller voir un thérapeute de couple."
        case .vendre: return "Tu as un truc à vendre, et \(n) a une carte bancaire."
        case .insulter: return "\(n) t'agace. Les mots sortent avant que tu réfléchisses."
        case .rompre: return "Tu as pris ta décision : avec \(n), c'est fini."
        case .jouer: return "Tu passes un moment à jouer avec \(n)."
        case .devoirs: return "Tu t'installes à côté de \(n) pour les devoirs."
        case .parlerVie: return "Tu proposes à \(n) une vraie discussion, sans écran."
        case .punir: return "\(n) a dépassé les bornes. Il faut réagir."
        case .argentPoche: return "\(n) vient te parler d'argent de poche."
        case .conduite: return "Leçon de conduite avec \(n). Tu serres la poignée de la portière."
        case .conseilAdulte: return "Tu appelles \(n) pour prendre des nouvelles."
        case .visite: return "Tu rends visite à \(n)."
        case .sortie: return "Tu sors avec \(n)."
        }
    }
}

extension GameEngine {
    /// Résout une carte d'action (même logique qu'un événement à choix) et renvoie le texte du résultat.
    func resoudreCarteCoeur(_ carte: CoeurCartePrete, choix index: Int) -> String {
        resoudreCarteCoeur(carte, etape: nil, numero: 0, choix: index).texte
    }

    /// Résout un choix de la carte ou d'une étape de scène (`then`, voir docs/SCENES.md).
    /// Renvoie le texte du résultat et l'étape suivante éventuelle.
    func resoudreCarteCoeur(_ carte: CoeurCartePrete, etape: EtapeScene?, numero: Int, choix index: Int) -> (texte: String, suite: EtapeScene?) {
        let liste = etape?.choices ?? carte.evenement.choices ?? []
        guard var j = joueur, liste.indices.contains(index) else { return ("", nil) }
        let c = liste[index]
        let issue = Self.tirage(c.outcomes)
        let resultat = remplir(issue?.text ?? "Il ne se passe rien.", j)
        let question = etape.map { remplir($0.text, j) } ?? carte.texte
        ajouterLigne(&j, (etape == nil ? carte.intro + " " : "") + question + " → " + c.label + ". " + resultat)
        if let eff = issue?.effects { appliquer(eff, &j) }
        let e = carte.evenement
        let evt = etape.map { et in
            Evenement(id: et.id ?? "\(e.id)#\(numero)", category: e.category, minAge: e.minAge, maxAge: e.maxAge,
                      weight: nil, unique: nil, conditions: nil, text: et.text, effects: nil, choices: et.choices)
        } ?? e
        modulesApresChoix(evt, choix: index, c, issue: issue, &j)
        var suite: EtapeScene? = nil
        if let s = issue?.then, !s.choices.isEmpty, j.vivant {
            suite = s
        }
        if suite == nil {
            var ce = j.coeurEtat
            ce.cibleCarte = nil
            j.coeurEtat = ce
        }
        joueur = j
        sauvegarder()
        return (resultat, suite)
    }
}

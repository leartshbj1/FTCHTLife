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
    case nuit, avenir, surprise
    // Enfants
    case jouer, devoirs, parlerVie, punir, argentPoche, conduite, conseilAdulte
    // Parents, fratrie, amis
    case visite, sortie

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .nuit: return "Passer une nuit ensemble"
        case .avenir: return "Parler de l'avenir"
        case .surprise: return "Préparer une surprise"
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
        case .nuit: return "moon.stars.fill"
        case .avenir: return "sparkles"
        case .surprise: return "gift.fill"
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
            var a: [CoeurActionProche] = []
            if j.age >= 18 && r.age >= 18 { a.append(.nuit) }
            if j.age >= 16 { a += [.avenir, .surprise] }
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

@MainActor
enum CoeurActionsSysteme {

    /// Chance qu'une carte suive l'action (sinon juste un petit texte).
    static func chanceCarte(_ a: CoeurActionProche) -> Double {
        switch a {
        case .nuit, .parlerVie, .avenir: return 1
        case .punir, .conduite, .argentPoche: return 0.85
        default: return 0.7
        }
    }

    static func cleAnnee(_ a: CoeurActionProche, _ id: UUID) -> String { "coeur_\(a.rawValue)_\(id.uuidString)" }

    static func dejaFait(_ a: CoeurActionProche, _ id: UUID, _ j: Joueur) -> Bool {
        j.actionsAnnee.contains(cleAnnee(a, id))
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
        j.actionsAnnee.append(cleAnnee(a, id))

        var c = j.coeurEtat
        c.cibleCarte = id
        j.coeurEtat = c

        j.relations[i].lien = Stats.borne(r.lien + Int.random(in: 1...4))
        let intro = phraseIntro(a, r)
        let possibles = cartes(a, j.relations[i], j, engine: engine)
        if !possibles.isEmpty, VieHasard.reussi(chanceCarte(a)),
           let e = GameEngine.tirage(possibles, poids: { $0.weight ?? 1 }) {
            if e.unique == true { j.evenementsVus.append(e.id) }
            let texte = engine.remplir(e.text, j)
            return (intro, CoeurCartePrete(evenement: e, texte: texte, intro: intro))
        }
        j.stats.bonheur += 2
        engine.ajouterLigne(&j, intro)
        return (intro, nil)
    }

    static func phraseIntro(_ a: CoeurActionProche, _ r: Relation) -> String {
        let n = r.prenom
        switch a {
        case .nuit: return "Soirée en tête-à-tête avec \(n). Bougies, musique douce, téléphone retourné."
        case .avenir: return "Tu t'assois avec \(n) pour parler de l'avenir. Le vrai."
        case .surprise: return "Tu prépares une surprise pour \(n)."
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
        guard var j = joueur, let choix = carte.evenement.choices, choix.indices.contains(index) else { return "" }
        let c = choix[index]
        let issue = Self.tirage(c.outcomes)
        let resultat = remplir(issue?.text ?? "Il ne se passe rien.", j)
        ajouterLigne(&j, carte.intro + " " + carte.texte + " → " + c.label + ". " + resultat)
        if let eff = issue?.effects { appliquer(eff, &j) }
        modulesApresChoix(carte.evenement, choix: index, c, issue: issue, &j)
        var ce = j.coeurEtat
        ce.cibleCarte = nil
        j.coeurEtat = ce
        joueur = j
        sauvegarder()
        return resultat
    }
}

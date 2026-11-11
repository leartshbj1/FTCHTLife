import Foundation

// Easter egg « Leart et Shkurta » (docs/AME_SOEUR.md).
//
// - Un perso prénommé Leart tombe amoureux de Shkurta à 18 ans, obligatoirement.
// - Une perso prénommée Shkurta (ou Shkurte) tombe amoureuse de Leart à 17 ans, obligatoirement.
// - Ensuite, ils ne peuvent jamais se quitter : pas de rupture, pas de divorce, pas de liaison,
//   l'âme sœur suit à l'étranger et ne meurt pas avant le joueur.
// - Chaque année, une carte de leur histoire (resto Royal, demande, mariage, bébé, vieillesse…) a de
//   bonnes chances d'arriver. Les cartes sont dans Data/Events/ame_soeur_*.json (ids ame_l_* et ame_s_*),
//   tirées seulement par ce module.
//
// Pour tous les autres prénoms, rien ne change.

/// État sauvegardé (champ `ameSoeur` de Joueur). Nil tant que la rencontre n'a pas eu lieu.
struct AmeSoeurEtat: Codable, Equatable {
    /// Id de la relation (Shkurta ou Leart) dans `Joueur.relations`.
    var relationId: UUID
    var ageRencontre: Int
    /// Dernières cartes de l'histoire, pour ne pas revoir les mêmes trop vite.
    var recentes: [String] = []
}

enum AmeSoeur {

    enum Profil: Equatable {
        /// Le joueur s'appelle Leart : son âme sœur est Shkurta.
        case leart
        /// La joueuse s'appelle Shkurta ou Shkurte : son âme sœur est Leart.
        case shkurta

        var ageRencontre: Int { self == .leart ? 18 : 17 }
        var prenomAmeSoeur: String { self == .leart ? "Shkurta" : "Leart" }
        var genreAmeSoeur: Genre { self == .leart ? .femme : .homme }
        var tag: String { self == .leart ? "ame_soeur_leart" : "ame_soeur_shkurta" }
        /// Préfixe des cartes de ce côté de l'histoire.
        var prefixeCartes: String { self == .leart ? "ame_l_" : "ame_s_" }
        var carteRencontre: String { prefixeCartes + "0001" }
    }

    static let tag = "ame_soeur"
    static let prefixe = "ame_"
    /// Chance qu'une carte de l'histoire arrive une année donnée (la rencontre arrive toujours).
    static let chanceCarteAnnuelle = 0.8
    /// Le lien avec l'âme sœur ne descend jamais sous ce seuil.
    static let lienMinimum = 60

    // MARK: - Qui est concerné

    /// « Leart », « leart », « LEART », « Shkurta », « shkurte »… (espaces, casse et accents ignorés).
    static func profil(prenom: String) -> Profil? {
        let p = prenom.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        switch p {
        case "leart": return .leart
        case "shkurta", "shkurte": return .shkurta
        default: return nil
        }
    }

    static func profil(_ j: Joueur) -> Profil? { profil(prenom: j.prenom) }

    /// La relation est-elle l'âme sœur du joueur ?
    static func estAmeSoeur(_ r: Relation, _ j: Joueur) -> Bool {
        guard let id = j.ameSoeur?.relationId else { return false }
        return r.id == id
    }

    /// Vrai quand le/la partenaire actuel·le est l'âme sœur : ce couple ne peut pas se séparer.
    static func coupleProtege(_ j: Joueur) -> Bool {
        guard let id = j.ameSoeur?.relationId, let p = j.partenaireActuel else { return false }
        return p.id == id
    }

    // MARK: - Tags

    static func tags(_ j: Joueur) -> Set<String> {
        guard coupleProtege(j), let p = profil(j) else { return [] }
        return [tag, p.tag]
    }

    // MARK: - Année

    /// Chaque année : la rencontre (à l'âge prévu), puis le couple reste soudé.
    static func passerAnnee(_ j: inout Joueur) -> [String] {
        guard j.vivant, let p = profil(j) else { return [] }
        guard let etat = j.ameSoeur else {
            return j.age >= p.ageRencontre ? rencontre(p, &j) : []
        }
        guard let i = j.relations.firstIndex(where: { $0.id == etat.relationId }), j.relations[i].vivant else { return [] }
        var lignes: [String] = []
        // Filet de sécurité : si un module a malgré tout séparé le couple, l'âme sœur revient.
        if j.relations[i].type != .partenaire {
            for k in j.relations.indices where k != i && j.relations[k].type == .partenaire && j.relations[k].vivant {
                j.relations[k].type = .ex
                j.relations[k].lien = min(j.relations[k].lien, 30)
            }
            j.relations[i].type = .partenaire
            var v = j.vieEtat; v.statutCouple = nil; j.vieEtat = v
            lignes.append("❤️ \(p.prenomAmeSoeur) est revenu\(p == .leart ? "e" : "") frapper à ta porte. « On s'était promis : jamais l'un sans l'autre. » Tu as ouvert avant la fin de la phrase.")
        }
        j.relations[i].lien = max(j.relations[i].lien, lienMinimum)
        return lignes
    }

    /// Le coup de foudre. L'ancien couple, s'il y en a un, s'arrête net.
    static func rencontre(_ p: Profil, _ j: inout Joueur) -> [String] {
        var lignes: [String] = []
        let etaitMarie = j.vieEtat.statutCouple == .marie
        for k in j.relations.indices where j.relations[k].type == .partenaire && j.relations[k].vivant {
            let ancien = j.relations[k].prenom
            j.relations[k].type = .ex
            j.relations[k].lien = min(j.relations[k].lien, 30)
            lignes.append(etaitMarie
                ? "💔 Tu quittes \(ancien). Personne n'a rien fait de mal : ton cœur vient simplement de choisir quelqu'un d'autre, pour toujours."
                : "💔 Tu quittes \(ancien). Ce n'est la faute de personne : ton cœur a choisi quelqu'un d'autre.")
        }
        var v = j.vieEtat
        v.statutCouple = nil
        v.anneesEnsemble = 0
        j.vieEtat = v

        let ageAmeSoeur = p == .leart ? max(16, j.age - 1) : j.age + 1
        let r = Relation(prenom: p.prenomAmeSoeur, nom: Donnees.noms.randomElement() ?? j.nom, genre: p.genreAmeSoeur,
                         type: .partenaire, age: ageAmeSoeur, lien: 100, argent: Int.random(in: 0...3_000))
        j.relations.append(r)
        j.ameSoeur = AmeSoeurEtat(relationId: r.id, ageRencontre: j.age)
        j.stats.bonheur += 25
        j.stats.borner()
        lignes.append(p == .leart
            ? "💘 Tu as croisé Shkurta. Un regard, et plus rien d'autre n'existe. Tu le sais tout de suite : c'est elle, et ce sera elle toute ta vie."
            : "💘 Tu as croisé Leart. Un sourire, et ton cœur a fait un bond. Tu le sais tout de suite : c'est lui, et ce sera lui toute ta vie.")
        SignauxModules.signaler("rencontre", &j)
        SignauxModules.signaler("couple", &j)
        SignauxModules.signaler("ame_soeur_rencontre", &j)
        return lignes
    }

    // MARK: - Ce qui ne peut pas arriver à ce couple

    /// Remplace une rupture ou un divorce (VieRelations.rompre) : ils ne se quittent pas.
    static func refusRupture(_ j: inout Joueur, parLeJoueur: Bool) -> [String] {
        let id = j.ameSoeur?.relationId
        guard let p = profil(j), let i = j.relations.firstIndex(where: { $0.id == id }) else { return [] }
        j.relations[i].lien = max(j.relations[i].lien, lienMinimum + 10)
        let nom = p.prenomAmeSoeur
        let pronom = p == .leart ? "elle" : "lui"
        if parLeJoueur {
            return [[
                "Tu as voulu partir. Tu as tenu jusqu'au bout de la rue, puis tu as fait demi-tour en courant. Sans \(nom), rien n'a de sens.",
                "Tu as écrit un message pour quitter \(nom). Tu l'as effacé lettre par lettre, puis tu as écrit « je t'aime » à la place.",
                "Tu as fait ta valise. \(nom) l'a regardée, puis t'a regardé\(j.genre == .femme ? "e" : ""). Tu l'as défaite sans un mot. Vous êtes faits l'un pour l'autre, et vous le savez.",
            ].randomElement()!]
        }
        return [[
            "\(nom) a claqué la porte sous le coup de la colère… et l'a rouverte dix secondes plus tard. « On ne se quitte pas, toi et moi. Jamais. »",
            "\(nom) a fait sa valise, puis l'a défaite en pleurant. Impossible de vivre sans toi, et tu ne pourrais pas vivre sans \(pronom).",
            "La crise a été rude, mais \(nom) est revenu\(p == .leart ? "e" : "") avant le soir, avec ton dessert préféré. Ce couple-là ne se brise pas.",
        ].randomElement()!]
    }

    /// Ids des événements dont un choix est traduit en tromperie ou en liaison (règles "emit" des répercussions).
    private static let evenementsTromperie: Set<String> = {
        let signaux: Set<String> = ["tromperie", "tromperie_decouverte", "liaison_debut", "rupture", "largue", "divorce"]
        var ids: Set<String> = []
        for r in Repercussions.toutes where r.on.hasPrefix("event:") {
            if !(r.emit ?? []).filter({ signaux.contains($0) }).isEmpty { ids.insert(String(r.on.dropFirst(6))) }
        }
        return ids
    }()

    /// L'événement pourrait-il séparer le couple (rupture, divorce, mort du partenaire, tromperie, liaison) ?
    static func menaceLeCouple(_ e: Evenement) -> Bool {
        // Module Cœur : liaisons, tentations, crises, enfants cachés.
        if e.id.hasPrefix("coe_") && e.category == "amour" { return true }
        if evenementsTromperie.contains(e.id) { return true }
        func menace(_ fx: Effets?) -> Bool {
            guard let v = fx?.vie else { return false }
            return v.breakup == true || v.targetDies == "partner"
        }
        if menace(e.effects) { return true }
        return e.choices?.contains { c in c.outcomes.contains { menace($0.effects) } } ?? false
    }

    /// Filtre de tous les tirages (événements aléatoires et suites), branché dans VieSysteme.evenementAutorise.
    static func evenementAutorise(_ e: Evenement, tags: Set<String>) -> Bool {
        if e.id.hasPrefix(prefixe) { return false }   // les cartes de l'histoire sont tirées par ce module
        guard tags.contains(tag) else { return true }
        return !menaceLeCouple(e)
    }

    /// Ligne ajoutée au journal quand le joueur meurt.
    static func adieu(_ j: Joueur) -> String? {
        let id = j.ameSoeur?.relationId
        guard let p = profil(j), let r = j.relations.first(where: { $0.id == id }), r.vivant,
              r.type == .partenaire else { return nil }
        return p == .leart
            ? "🤍 Shkurta était là, ta main dans la sienne, jusqu'au dernier instant. Vous ne vous êtes jamais quittés."
            : "🤍 Leart était là, ta main dans la sienne, jusqu'au dernier instant. Vous ne vous êtes jamais quittés."
    }

    // MARK: - Cartes de l'histoire

    /// Toutes les cartes (ids ame_l_* et ame_s_*), lues dans Data/Events.
    static let cartes: [Evenement] = BibliothequeEvenements.tous.filter { $0.id.hasPrefix(prefixe) }

    /// Choisit la carte de l'année (ou nil). La rencontre passe avant tout le reste.
    static func carteDeLAnnee(_ j: Joueur, _ p: Profil, eligible: (Evenement) -> Bool) -> Evenement? {
        let candidates = cartes.filter { $0.id.hasPrefix(p.prefixeCartes) && eligible($0) }
        if let r = candidates.first(where: { $0.id == p.carteRencontre }) { return r }
        guard Double.random(in: 0..<1) < chanceCarteAnnuelle else { return nil }
        let recentes = Set(j.ameSoeur?.recentes ?? [])
        let fraiches = candidates.filter { !recentes.contains($0.id) }
        return GameEngine.tirage(fraiches.isEmpty ? candidates : fraiches) { $0.weight ?? 1 }
    }
}

extension GameEngine {

    /// Après les fêtes et les suites, avant le tirage : la carte de l'année de l'histoire, en tête de file.
    /// Elle passe par la limite de 3 cartes à choix par an comme les autres (limiterFileEvenements).
    func ameSoeurAvantTirage() {
        guard var j = joueur, j.vivant, let p = AmeSoeur.profil(j), var etat = j.ameSoeur,
              AmeSoeur.coupleProtege(j) else { return }
        let t = tags(j)
        // En prison, seules les cartes « prison » (le parloir) passent ; dehors, jamais.
        let enPrison = j.vieEtat.justice.enPrison
        guard let e = AmeSoeur.carteDeLAnnee(j, p, eligible: {
            ($0.category == "prison") == enPrison && self.conditionsRemplies($0, j, tags: t)
        }) else { return }
        etat.recentes = Array((etat.recentes + [e.id]).suffix(8))
        j.ameSoeur = etat
        guard let choix = e.choices, !choix.isEmpty else {
            joueur = j
            declencher(e)
            return
        }
        if e.unique == true { j.evenementsVus.append(e.id) }
        joueur = j
        // Juste après les cartes prioritaires (soirée électorale, secrets, testament), avant tout le reste.
        let position = fileEvenements.firstIndex { prioriteEvenement($0.evenement) > 0 } ?? fileEvenements.count
        fileEvenements.insert(EvenementAffiche(evenement: e, texte: remplir(e.text, j)), at: position)
    }
}

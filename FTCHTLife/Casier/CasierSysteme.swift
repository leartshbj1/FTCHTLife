import Foundation

/// Règles du casier judiciaire : condamnations, effacement (avocat, TIG, années sans récidive, piston),
/// métiers fermés et tags d'événements. Voir docs/CASIER.md pour le branchement dans le moteur.
enum CasierSysteme {

    // MARK: - Données

    static let avocats: [CasierAvocat] = DonneesJSON.chargerTableaux(dossier: "Casier/Avocats", type: CasierAvocat.self)
    static let pistons: [CasierPiston] = DonneesJSON.chargerTableaux(dossier: "Casier/Pistons", type: CasierPiston.self)
    static let metiersFermes: [CasierMetierFerme] = DonneesJSON.chargerTableaux(dossier: "Casier/Metiers", type: CasierMetierFerme.self)
    static let missionsTIG: [CasierMissionTIG] = DonneesJSON.chargerTableaux(dossier: "Casier/TIG", type: CasierMissionTIG.self)

    /// Clés posées dans `Joueur.actionsAnnee` (une tentative de chaque par an).
    static let cleAvocat = "casier_avocat"
    static let clePiston = "casier_piston"
    static let cleTIG = "casier_tig"

    // MARK: - Tags d'événements

    /// `casier` : au moins une condamnation inscrite. `casier_lourd` : un crime inscrit.
    /// `tig` : travaux d'intérêt général en cours. `casier_efface` : casier vierge après avoir été effacé.
    static func tags(_ casier: CasierJudiciaire?) -> Set<String> {
        guard let c = casier else { return [] }
        var t: Set<String> = []
        if !c.estVierge { t.insert("casier") }
        if c.graviteMax == .crime { t.insert("casier_lourd") }
        if c.tig != nil { t.insert("tig") }
        if c.estVierge && !c.effacees.isEmpty { t.insert("casier_efface") }
        return t
    }

    // MARK: - Condamner (appelé par le module crime et par les événements)

    /// Inscrit une condamnation. Remet à zéro le compteur sans récidive. Renvoie la ligne de journal.
    @discardableResult
    static func condamner(_ c: inout CasierJudiciaire, infraction: String, gravite: CasierGravite, age: Int) -> String {
        let recidive = !c.estVierge || !c.effacees.isEmpty
        c.condamnations.append(CasierCondamnation(infraction: infraction, gravite: gravite, age: age))
        c.totalCondamnations += 1
        c.anneesSansRecidive = 0
        var ligne = "📁 Inscrit à ton casier judiciaire : \(infraction) (\(gravite.nom.lowercased()))."
        if recidive {
            ligne += " " + [
                "Le greffier a soupiré en voyant ton nom. Encore.",
                "Récidive. Le compteur repart à zéro, comme tes bonnes résolutions.",
                "Ton dossier commence à avoir besoin d'un classeur à lui tout seul.",
            ].randomElement()!
        }
        return ligne
    }

    /// Retire une condamnation du casier et la range dans les archives.
    @discardableResult
    static func effacer(_ c: inout CasierJudiciaire, id: UUID, par moyen: String, age: Int) -> CasierCondamnation? {
        guard let i = c.condamnations.firstIndex(where: { $0.id == id }) else { return nil }
        var cond = c.condamnations.remove(at: i)
        cond.effaceePar = moyen
        cond.ageEffacement = age
        c.effacees.append(cond)
        if c.tig?.condamnationId == id { c.tig = nil }
        return cond
    }

    private static func phraseCasierVierge() -> String {
        [
            "✨ Ton casier judiciaire est vierge. Ta mère peut à nouveau parler de toi aux voisins.",
            "✨ Casier vierge ! Même le commissariat a oublié ta tête. Enfin, presque.",
            "✨ Plus rien sur ton casier. Tu es officiellement une personne fréquentable.",
        ].randomElement()!
    }

    // MARK: - Passage d'une année

    /// À appeler à chaque anniversaire. `enPrison` : les années derrière les barreaux ne comptent pas.
    static func passerAnnee(_ c: inout CasierJudiciaire, joueur j: Joueur, enPrison: Bool = false) -> [String] {
        let age = j.age
        guard !c.estVierge || c.tig != nil else { return [] }
        var lignes: [String] = []
        let avaitCasier = !c.estVierge
        if !enPrison && avaitCasier { c.anneesSansRecidive += 1 }

        // Travaux d'intérêt général
        if !enPrison, let t = c.tig {
            let heures = Int.random(in: 50...110)
            lignes.append(contentsOf: avancerTIG(&c, heures: heures, age: age))
            if c.tig != nil, Double.random(in: 0..<1) < 0.6 { lignes.append("🧹 " + anecdoteTIG(t.mission, j)) }
        }

        // Réhabilitation automatique
        lignes.append(contentsOf: rehabiliter(&c, age: age))
        if avaitCasier && c.estVierge { lignes.append(phraseCasierVierge()) }
        return lignes
    }

    /// Efface les condamnations dont le délai sans récidive est atteint.
    private static func rehabiliter(_ c: inout CasierJudiciaire, age: Int) -> [String] {
        let annees = c.anneesSansRecidive
        let mures = c.condamnations.filter { annees >= $0.gravite.delaiRehabilitation }
        var lignes: [String] = []
        for cond in mures {
            guard effacer(&c, id: cond.id, par: "années sans récidive", age: age) != nil else { continue }
            let chute = [
                "La patience paie, apparemment.",
                "Tu n'as rien fait pour ça, à part ne rien faire. Bravo.",
                "Le tampon « réhabilité » est le plus beau tampon du monde.",
            ].randomElement()!
            lignes.append("🧽 \(c.anneesSansRecidive) ans sans histoire : « \(cond.infraction) » disparaît de ton casier. " + chute)
        }
        return lignes
    }

    // MARK: - Effets d'événements

    /// Applique le sous-objet `"casier"` d'un effet d'événement et renvoie les lignes de journal.
    static func appliquer(_ e: CasierEffet, _ c: inout CasierJudiciaire, age: Int) -> [String] {
        var lignes: [String] = []
        if let d = e.delai, d > 0, !c.estVierge {
            c.anneesSansRecidive += d
            lignes.append(contentsOf: rehabiliter(&c, age: age))
        }
        switch e.effacer {
        case "tout":
            let avant = !c.estVierge
            let toutes = c.condamnations
            for cond in toutes { effacer(&c, id: cond.id, par: "un coup de chance", age: age) }
            if avant { lignes.append(phraseCasierVierge()) }
        case "une":
            if let cond = c.condamnations.min(by: { $0.gravite < $1.gravite }) {
                effacer(&c, id: cond.id, par: "un coup de chance", age: age)
                lignes.append("🧽 « \(cond.infraction) » disparaît de ton casier.")
                if c.estVierge { lignes.append(phraseCasierVierge()) }
            }
        default: break
        }
        if let n = e.condamnation {
            lignes.append(condamner(&c, infraction: n.infraction, gravite: n.gravite, age: age))
        }
        return lignes
    }

    // MARK: - Métiers fermés

    /// Raison pour laquelle le métier est fermé au joueur, ou nil s'il est ouvert.
    /// Marche avec les métiers du moteur et ceux du module métiers (comparaison par id puis par mots du titre).
    static func raisonMetierFerme(id: String, titre: String, casier: CasierJudiciaire?) -> String? {
        guard let g = casier?.graviteMax else { return nil }
        for regle in metiersFermes where g >= regle.graviteMin {
            if regle.ids?.contains(id) == true { return regle.raison }
            if let mots = regle.motsCles, mots.contains(where: { contientMot(titre, $0) }) {
                return regle.raison
            }
        }
        return nil
    }

    /// Minuscules sans accents, tout ce qui n'est pas une lettre devient une espace.
    static func normaliser(_ s: String) -> String {
        let plie = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        return String(plie.map { $0.isLetter ? $0 : " " })
    }

    /// Vrai si un mot du titre commence par `mot` (« polic » trouve « Policier·ère » mais « maire » ne trouve pas « primaire »).
    static func contientMot(_ titre: String, _ mot: String) -> Bool {
        (" " + normaliser(titre)).contains(" " + normaliser(mot))
    }

    // MARK: - Avocat

    static func prix(_ a: CasierAvocat, pour g: CasierGravite) -> Int {
        Int((Double(a.prix) * g.facteurPrix).rounded())
    }

    /// Bonus commun aux avocats et pistons : ancienneté sans récidive, karma, malus de récidiviste.
    private static func bonus(_ c: CasierJudiciaire, _ j: Joueur) -> Double {
        0.03 * Double(min(c.anneesSansRecidive, 8))
            + Double(j.stats.karma - 50) / 500
            - 0.04 * Double(min(max(0, c.totalCondamnations - 1), 5))
    }

    static func chance(_ a: CasierAvocat, cible: CasierCondamnation, casier c: CasierJudiciaire, joueur j: Joueur) -> Double {
        min(0.92, max(0.03, a.chance * cible.gravite.facteurChance + bonus(c, j)))
    }

    /// Nil si l'avocat peut être engagé, sinon la raison.
    static func avocatIndisponible(_ a: CasierAvocat, cible: CasierCondamnation, casier c: CasierJudiciaire, joueur j: Joueur) -> String? {
        if j.age < 16 { return "Aucun avocat ne prend un client qui a encore un goûter dans son sac." }
        if j.actionsAnnee.contains(cleAvocat) { return "Tu as déjà vu un avocat cette année. Le tribunal a besoin de souffler." }
        if cible.gravite > a.graviteMax { return "\(a.nom) ne touche pas aux affaires aussi lourdes." }
        if j.argent < prix(a, pour: cible.gravite) { return "Pas assez d'argent : il faut \(Format.argent(prix(a, pour: cible.gravite)))." }
        return nil
    }

    /// Engage l'avocat pour faire effacer `cibleId`. Renvoie le texte du résultat.
    static func engagerAvocat(_ a: CasierAvocat, cibleId: UUID, casier c: inout CasierJudiciaire, joueur j: inout Joueur) -> String {
        guard let cible = c.condamnations.first(where: { $0.id == cibleId }) else { return "Cette condamnation n'est plus sur ton casier." }
        if let raison = avocatIndisponible(a, cible: cible, casier: c, joueur: j) { return raison }
        let p = chance(a, cible: cible, casier: c, joueur: j)
        j.argent -= prix(a, pour: cible.gravite)
        j.actionsAnnee.append(cleAvocat)

        if let risque = a.risque, Double.random(in: 0..<1) < risque {
            j.stats.karma -= 10
            j.stats.bonheur -= 10
            let txt = remplir(a.scandales?.randomElement() ?? "La combine de ton avocat a été découverte.", j, cible: cible, contact: a.nom)
            let ligne = condamner(&c, infraction: a.infractionRisque ?? "complicité de falsification de casier", gravite: .delit, age: j.age)
            return txt + "\n\n" + ligne
        }
        if Double.random(in: 0..<1) < p {
            effacer(&c, id: cible.id, par: a.nom, age: j.age)
            j.stats.bonheur += 12
            var txt = remplir(a.succes.randomElement() ?? "Effacé !", j, cible: cible, contact: a.nom)
            if c.estVierge { txt += "\n\n" + phraseCasierVierge() }
            return txt
        }
        j.stats.bonheur -= 6
        return remplir(a.echecs.randomElement() ?? "Requête rejetée.", j, cible: cible, contact: a.nom)
    }

    // MARK: - Piston

    /// La personne qui sert de piston, si la condition en demande une.
    static func contact(_ p: CasierPiston, _ j: Joueur) -> Relation? {
        let lienMin = p.lienMin ?? 0
        let candidats = j.relations.filter { r in
            guard r.vivant, r.lien >= lienMin else { return false }
            switch p.condition {
            case "parent": return r.type.estParent
            case "ami": return r.type == .ami
            case "partenaire": return r.type == .partenaire
            case "fratrie": return r.type == .frere || r.type == .soeur
            default: return false
            }
        }
        return candidats.max { $0.lien < $1.lien }
    }

    static func chance(_ p: CasierPiston, cible: CasierCondamnation, casier c: CasierJudiciaire, joueur j: Joueur) -> Double {
        min(0.9, max(0.03, p.chance * cible.gravite.facteurChance + bonus(c, j)))
    }

    /// Nil si le piston peut être tenté, sinon la raison.
    static func pistonIndisponible(_ p: CasierPiston, cible: CasierCondamnation, casier c: CasierJudiciaire, joueur j: Joueur) -> String? {
        if j.age < 16 { return "Personne ne pistonne un ado. Reviens avec une carte de visite." }
        if c.pistonsUtilises.contains(p.id) { return "Ce piston est grillé. On ne te répond plus." }
        if j.actionsAnnee.contains(clePiston) { return "Tu as déjà fait jouer tes relations cette année. Fais-toi oublier un peu." }
        if cible.gravite > p.graviteMax { return "Même le meilleur piston a ses limites. Celle-là est trop grosse." }
        switch p.condition {
        case "parent", "ami", "partenaire", "fratrie":
            if contact(p, j) == nil { return "Il te faut quelqu'un de proche (lien \(p.lienMin ?? 0) % ou plus) pour ça." }
        case "metier":
            guard let e = j.emploi else { return "Il faut un travail dans le bon milieu pour avoir ce genre de collègues." }
            let ok = (p.metiers ?? []).contains { e.metierId == $0 || contientMot(e.titre, $0) }
            if !ok { return "Tes collègues actuels ne connaissent personne d'utile. Ils connaissent surtout la machine à café." }
        case "riche":
            if j.argent < 100_000 { return "Ce genre de dîner ne s'ouvre qu'aux gens qui ont au moins \(Format.argent(100_000))." }
        default: break
        }
        if let prix = p.prix, j.argent < prix { return "Pas assez d'argent : il faut \(Format.argent(prix))." }
        return nil
    }

    /// Fait jouer le piston pour effacer `cibleId`. Renvoie le texte du résultat.
    static func activerPiston(_ p: CasierPiston, cibleId: UUID, casier c: inout CasierJudiciaire, joueur j: inout Joueur) -> String {
        guard let cible = c.condamnations.first(where: { $0.id == cibleId }) else { return "Cette condamnation n'est plus sur ton casier." }
        if let raison = pistonIndisponible(p, cible: cible, casier: c, joueur: j) { return raison }
        let personne = contact(p, j)
        let nomContact = personne?.prenom ?? p.nom
        let proba = chance(p, cible: cible, casier: c, joueur: j)
        j.argent -= p.prix ?? 0
        j.actionsAnnee.append(clePiston)
        c.pistonsUtilises.append(p.id)

        if let risque = p.risque, Double.random(in: 0..<1) < risque {
            j.stats.karma -= 12
            j.stats.bonheur -= 10
            let txt = remplir(p.scandales?.randomElement() ?? "Le piston a fuité dans la presse.", j, cible: cible, contact: nomContact)
            let ligne = condamner(&c, infraction: p.infractionRisque ?? "trafic d'influence", gravite: .delit, age: j.age)
            return txt + "\n\n" + ligne
        }
        if Double.random(in: 0..<1) < proba {
            effacer(&c, id: cible.id, par: "piston (\(nomContact))", age: j.age)
            j.stats.bonheur += 12
            j.stats.karma -= 3
            var txt = remplir(p.succes.randomElement() ?? "Le dossier a disparu.", j, cible: cible, contact: nomContact)
            if c.estVierge { txt += "\n\n" + phraseCasierVierge() }
            return txt
        }
        if let id = personne?.id, let i = j.relations.firstIndex(where: { $0.id == id }) {
            j.relations[i].lien = Stats.borne(j.relations[i].lien + (p.lienEchec ?? -10))
        }
        j.stats.bonheur -= 5
        return remplir(p.echecs.randomElement() ?? "Ça n'a rien donné.", j, cible: cible, contact: nomContact)
    }

    // MARK: - Travaux d'intérêt général

    /// Nil si les TIG peuvent commencer pour cette condamnation, sinon la raison.
    static func tigIndisponible(cible: CasierCondamnation, casier c: CasierJudiciaire, joueur j: Joueur) -> String? {
        if j.age < 16 { return "Les TIG, c'est à partir de 16 ans. En attendant, range ta chambre." }
        if c.tig != nil { return "Tu as déjà des travaux d'intérêt général en cours. Un balai à la fois." }
        return nil
    }

    /// S'inscrire aux TIG. Pour un crime, finir les heures raccourcit le délai de 3 ans au lieu d'effacer.
    static func commencerTIG(cibleId: UUID, casier c: inout CasierJudiciaire, joueur j: inout Joueur) -> String {
        guard let cible = c.condamnations.first(where: { $0.id == cibleId }) else { return "Cette condamnation n'est plus sur ton casier." }
        if let raison = tigIndisponible(cible: cible, casier: c, joueur: j) { return raison }
        let mission = missionsTIG.randomElement()?.mission ?? "repeindre les bancs du parc municipal"
        c.tig = CasierTIG(condamnationId: cible.id, heuresTotal: cible.gravite.heuresTIG, heuresFaites: 0, mission: mission)
        j.actionsAnnee.append(cleTIG)
        j.stats.karma += 3
        let but = cible.gravite == .crime
            ? "Pour un crime, ça ne l'effacera pas, mais ça raccourcira l'attente de 3 ans."
            : "À la fin, « \(cible.infraction) » sera effacé de ton casier."
        return "Tu t'inscris aux travaux d'intérêt général : \(cible.gravite.heuresTIG) heures à \(mission). \(but) Tu avanceras un peu chaque année."
    }

    /// Faire des heures en plus cette année.
    static func heuresEnPlus(casier c: inout CasierJudiciaire, joueur j: inout Joueur) -> String {
        guard let t = c.tig else { return "Tu n'as pas de travaux d'intérêt général en cours." }
        if j.actionsAnnee.contains(cleTIG) { return "Tu as déjà donné de ta personne cette année. Le balai a besoin de repos." }
        j.actionsAnnee.append(cleTIG)
        j.stats.sante -= 2
        j.stats.bonheur -= 3
        j.stats.karma += 3
        let heures = Int.random(in: 30...70)
        var txt = "Tu fais \(heures) heures de plus. " + anecdoteTIG(t.mission, j)
        let lignes = avancerTIG(&c, heures: heures, age: j.age)
        if !lignes.isEmpty { txt += "\n\n" + lignes.joined(separator: "\n") }
        return txt
    }

    static func abandonnerTIG(casier c: inout CasierJudiciaire, joueur j: inout Joueur) -> String {
        guard c.tig != nil else { return "Tu n'as pas de travaux d'intérêt général en cours." }
        c.tig = nil
        j.stats.karma -= 5
        return "Tu as rendu ton gilet fluo. Le responsable a noté ton nom dans un petit carnet. Toutes tes heures sont perdues."
    }

    /// Ajoute des heures et termine les TIG si le total est atteint.
    private static func avancerTIG(_ c: inout CasierJudiciaire, heures: Int, age: Int) -> [String] {
        guard var t = c.tig else { return [] }
        t.heuresFaites = min(t.heuresTotal, t.heuresFaites + heures)
        guard t.heuresFaites >= t.heuresTotal else {
            c.tig = t
            return ["🦺 Travaux d'intérêt général : \(t.heuresFaites) heures sur \(t.heuresTotal)."]
        }
        c.tig = nil
        guard let cible = c.condamnations.first(where: { $0.id == t.condamnationId }) else {
            return ["🦺 Tu as fini tes travaux d'intérêt général. La condamnation avait déjà disparu, mais le parc est très propre."]
        }
        if cible.gravite == .crime {
            c.anneesSansRecidive += 3
            var l = ["🦺 Tu as fini tes \(t.heuresTotal) heures de TIG. Le juge raccourcit de 3 ans l'attente pour « \(cible.infraction) »."]
            l.append(contentsOf: rehabiliter(&c, age: age))
            if c.estVierge { l.append(phraseCasierVierge()) }
            return l
        }
        effacer(&c, id: cible.id, par: "travaux d'intérêt général", age: age)
        var l = ["🦺 Tu as fini tes \(t.heuresTotal) heures de TIG. « \(cible.infraction) » est effacé de ton casier. Tu peux garder le gilet fluo."]
        if c.estVierge { l.append(phraseCasierVierge()) }
        return l
    }

    private static func anecdoteTIG(_ mission: String, _ j: Joueur) -> String {
        let anecdotes = missionsTIG.first { $0.mission == mission }?.anecdotes ?? []
        if let a = anecdotes.randomElement() { return remplir(a, j, cible: nil, contact: "") }
        return "Tu as passé l'après-midi à \(mission). Personne ne t'a dit merci, mais personne ne t'a arrêté non plus."
    }

    // MARK: - Textes

    /// Remplace {prenom}, {e}, {ville}, {contact} (avocat ou personne du piston) et {infraction}.
    static func remplir(_ texte: String, _ j: Joueur, cible: CasierCondamnation?, contact: String) -> String {
        var t = texte
        t = t.replacingOccurrences(of: "{prenom}", with: j.prenom)
        t = t.replacingOccurrences(of: "{ville}", with: j.ville)
        t = t.replacingOccurrences(of: "{contact}", with: contact)
        t = t.replacingOccurrences(of: "{infraction}", with: cible?.infraction ?? "ton petit écart")
        t = t.replacingOccurrences(of: "{e}", with: j.genre == .femme ? "e" : "")
        return t
    }

    /// Résumé court pour le profil : « Vierge », « 1 délit », « 2 contraventions, 1 crime »…
    static func resume(_ casier: CasierJudiciaire?) -> String {
        guard let c = casier, !c.estVierge else { return "Vierge" }
        return CasierGravite.allCases.reversed().compactMap { g -> String? in
            let n = c.condamnations.filter { $0.gravite == g }.count
            guard n > 0 else { return nil }
            return "\(n) \(g.nom.lowercased())\(n > 1 ? "s" : "")"
        }.joined(separator: ", ")
    }
}

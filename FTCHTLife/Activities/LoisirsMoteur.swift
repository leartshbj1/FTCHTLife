import Foundation

// Logique des loisirs. Les règles pures sont dans `LoisirsRegles` ; ce qui touche au joueur en cours
// passe par une extension de `GameEngine` (fonctions publiques du moteur seulement : appliquer, remplir,
// ajouterLigne, sauvegarder, tags).

/// Résultat d'une séance, affiché à l'écran et renvoyé au moteur.
struct LoisirResultat: Identifiable, Equatable {
    let id = UUID()
    var titre: String
    var icone: String
    var texte: String
    /// « +3 santé · -40 € ».
    var resume: String
    /// Lignes en plus : niveau gagné, trophée, blessure.
    var extras: [String]
    /// Signaux pour le système de répercussions (ex. « randonnee », « randonnee_sommet »).
    var signaux: [String]
    var mort: Bool
}

/// Pourquoi une option n'est pas disponible.
enum LoisirStatut: Equatable {
    case ok
    case tropJeune(Int)
    case dejaFait
    case blesse(String)
    case niveau(Int)
    case sante(Int)
    case argent(Int)

    func raison(genre: Genre) -> String? {
        switch self {
        case .ok: return nil
        case .tropJeune(let a): return "Dès \(a) ans"
        case .dejaFait: return "Plus de séance possible cette année"
        case .blesse(let nom): return "Impossible avec ta blessure (\(nom))"
        case .niveau(let n): return "Niveau « \(LoisirsRegles.nomNiveau(n, genre: genre)) » requis"
        case .sante(let s): return "Il faut au moins \(s) % de santé"
        case .argent(let m): return "Il te faut \(Format.argent(m))"
        }
    }
}

extension LoisirsRegles {

    /// L'activité apparaît-elle dans la liste (âge et tags) ?
    static func visible(_ a: LoisirActivite, _ j: Joueur, tags: Set<String>) -> Bool {
        guard j.age >= a.minAge else { return false }
        if let m = a.maxAge, j.age > m { return false }
        if let t = a.tags, !Set(t).isSubset(of: tags) { return false }
        if let x = a.excludeTags, !Set(x).isDisjoint(with: tags) { return false }
        return true
    }

    /// Prix réellement payé : gratuit avec l'abonnement, payé par les parents avant 18 ans.
    static func cout(_ a: LoisirActivite, _ o: LoisirOption, _ j: Joueur, _ e: LoisirsEtat) -> Int {
        if e.estAbonne(a.id) || j.age < 18 { return 0 }
        return max(0, o.cost ?? 0)
    }

    static func statut(_ a: LoisirActivite, _ o: LoisirOption, _ j: Joueur, _ e: LoisirsEtat) -> LoisirStatut {
        let ageMin = max(a.minAge, o.minAge ?? 0)
        if j.age < ageMin { return .tropJeune(ageMin) }
        if e.seances(a.id) >= a.seancesParAn { return .dejaFait }
        let niveauMin = o.minLevel ?? 0
        if e.niveau(a.id) < niveauMin { return .niveau(niveauMin) }
        if a.estPhysique && niveauMin >= 2, let b = e.blessures.first { return .blesse(b.nom) }
        if let s = o.minHealth, j.stats.sante < s { return .sante(s) }
        let prix = cout(a, o, j, e)
        if prix > 0 && j.argent < prix { return .argent(prix) }
        return .ok
    }

    /// Tire une issue selon le niveau : les issues ratées deviennent plus rares avec l'expérience,
    /// plus fréquentes quand on est blessé ou en mauvaise santé (activités physiques).
    static func tirerIssue(_ o: LoisirOption, niveau: Int, blesse: Bool, sante: Int, physique: Bool) -> LoisirIssue? {
        let possibles = o.outcomes.filter { niveau >= ($0.minLevel ?? 0) && niveau <= ($0.maxLevel ?? 4) }
        let liste = possibles.isEmpty ? o.outcomes : possibles
        func poids(_ i: LoisirIssue) -> Double {
            var p = max(0, i.chance ?? 1)
            if i.bad == true {
                p *= max(0.3, 1 - 0.15 * Double(niveau))
                if physique && blesse { p *= 1.5 }
                if physique && sante < 30 { p *= 1.3 }
            }
            return p
        }
        let total = liste.reduce(0.0) { $0 + poids($1) }
        guard total > 0 else { return liste.randomElement() }
        var r = Double.random(in: 0..<total)
        for i in liste {
            r -= poids(i)
            if r < 0 { return i }
        }
        return liste.last
    }

    /// Résumé des changements entre deux états du joueur : « +3 santé · -40 € ».
    static func resume(avant: Joueur, apres: Joueur) -> String {
        var morceaux: [String] = []
        func ajouter(_ delta: Int, _ nom: String) {
            if delta != 0 { morceaux.append((delta > 0 ? "+" : "") + "\(delta) \(nom)") }
        }
        ajouter(apres.stats.sante - avant.stats.sante, "santé")
        ajouter(apres.stats.bonheur - avant.stats.bonheur, "bonheur")
        ajouter(apres.stats.intelligence - avant.stats.intelligence, "intelligence")
        ajouter(apres.stats.apparence - avant.stats.apparence, "apparence")
        ajouter(apres.stats.karma - avant.stats.karma, "karma")
        let argent = apres.argent - avant.argent
        if argent != 0 { morceaux.append((argent > 0 ? "+" : "-") + Format.argent(abs(argent))) }
        return morceaux.joined(separator: " · ")
    }

    // MARK: Textes des messages annuels

    // {A} = nom de l'activité, {n} = nombre d'années, {s} = nom de l'abonnement.
    static let textesSeriePhysique = [
        "{A} : {n} ans d'affilée. Ton cœur t'envoie une carte de remerciement.",
        "{A} : {n} ans sans t'arrêter. Tes genoux ont créé un syndicat.",
        "{A} : {n} années de suite. Ton médecin te montre en exemple à ses autres patients.",
        "{A} : {n} ans d'affilée. Tu as des muscles dont tu ignorais l'existence.",
    ]
    static let textesSerieTete = [
        "{A} : {n} ans d'affilée. Tu en parles à table. Beaucoup trop.",
        "{A} : {n} ans de suite. C'est officiellement ta personnalité.",
        "{A} : {n} ans sans lâcher. Ta famille a renoncé à te faire changer de sujet.",
        "{A} : {n} ans de pratique. Tu dis « à mon niveau » dans les conversations.",
    ]
    static let textesAbandon = [
        "{A} : trois ans que tu n'en fais plus. Ton matériel prend la poussière en silence.",
        "{A} : trois ans sans pratiquer. Tu dis encore « j'en fais » quand on te demande.",
        "{A} : tu as arrêté il y a trois ans. Tu regardes des vidéos des autres en soupirant.",
    ]
    static let textesAbonnementInutile = [
        "Tu as payé ton {s} toute l'année sans y aller une seule fois. Un don, en somme.",
        "Ton {s} a été prélevé. Tu n'y es pas allé{e}. Tu as culpabilisé, ça compte comme du cardio.",
        "Ton {s} : encore une année payée pour rien. Le gérant t'a envoyé des chocolats.",
    ]
}

// MARK: - Branchement sur le moteur

extension GameEngine {

    /// Tags du joueur + tags des loisirs (à utiliser tant que le moteur ne les fusionne pas lui-même).
    func tagsLoisirs(_ j: Joueur, etat: LoisirsEtat?) -> Set<String> {
        tags(j).union(LoisirsRegles.tags(etat))
    }

    /// Fait une séance de l'activité `a` avec l'option `o`.
    /// - Parameters:
    ///   - etat: où ranger l'état des loisirs dans `Joueur` (ex. `\.loisirs`).
    ///   - signaler: appelée pour chaque signal (ex. vers `Repercussions.signaler`).
    @discardableResult
    func pratiquerLoisir(_ a: LoisirActivite, option o: LoisirOption,
                         etat kp: WritableKeyPath<Joueur, LoisirsEtat?>,
                         signaler: ((String, inout Joueur) -> Void)? = nil) -> LoisirResultat? {
        guard var j = joueur, j.vivant else { return nil }
        var e = j[keyPath: kp] ?? LoisirsEtat()
        let statut = LoisirsRegles.statut(a, o, j, e)
        if statut != .ok {
            return LoisirResultat(titre: a.title, icone: a.icon, texte: statut.raison(genre: j.genre) ?? "",
                                  resume: "", extras: [], signaux: [], mort: false)
        }
        let avant = j
        let niveauAvant = e.niveau(a.id)
        j.argent -= LoisirsRegles.cout(a, o, j, e)
        e.seancesAnnee[a.id, default: 0] += 1
        e.xp[a.id, default: 0] += max(1, o.xp ?? 1)
        e.dernierAge[a.id] = j.age
        e.anneesSansAller[a.id] = 0
        e.totalSeances += 1

        let issue = LoisirsRegles.tirerIssue(o, niveau: niveauAvant, blesse: e.estBlesse,
                                             sante: j.stats.sante, physique: a.estPhysique)
        let texte = remplir(issue?.text ?? "Il ne s'est rien passé. Même pas un peu.", j)
        ajouterLigne(&j, "\(a.title) : \(texte)")

        var extras: [String] = []
        if let b = issue?.injury {
            let annees = max(1, b.years ?? 1)
            e.blessures.removeAll { $0.nom == b.name }
            e.blessures.append(LoisirBlessureActive(nom: b.name, anneesRestantes: annees,
                                                    santeParAn: b.healthPerYear ?? -1, activite: a.id))
            extras.append("🩹 Blessure : \(b.name) (\(annees) an\(annees > 1 ? "s" : "")).")
        }
        if let t = issue?.trophy, !e.trophees.contains(t) {
            e.trophees.append(t)
            j.stats.bonheur += 5
            extras.append("🏆 Trophée : \(t) !")
        }
        if let eff = issue?.effects { appliquer(eff, &j) }

        if j.vivant {
            let niveauApres = e.niveau(a.id)
            if niveauApres > niveauAvant {
                j.stats.bonheur += 2
                extras.append("📈 \(a.title) : tu passes au niveau « \(LoisirsRegles.nomNiveau(niveauApres, genre: j.genre)) ».")
            }
        }
        j.stats.borner()
        for x in extras { ajouterLigne(&j, x) }

        // Signaux pour les répercussions.
        let base = a.signal ?? a.id
        var signaux = [base]
        if let s = issue?.signal { signaux.append("\(base)_\(s)") }
        else if issue?.injury != nil { signaux.append("\(base)_blessure") }
        if let k = issue?.key { signaux.append("\(a.id)_\(k)") }

        j[keyPath: kp] = e
        if let signaler = signaler {
            for s in signaux { signaler(s, &j) }
        }
        let resultat = LoisirResultat(titre: a.title, icone: a.icon, texte: texte,
                                      resume: LoisirsRegles.resume(avant: avant, apres: j),
                                      extras: extras, signaux: signaux, mort: !j.vivant)
        joueur = j
        sauvegarder()
        return resultat
    }

    /// Prend ou résilie l'abonnement de l'activité. Renvoie le texte à afficher.
    func basculerAbonnementLoisir(_ a: LoisirActivite, etat kp: WritableKeyPath<Joueur, LoisirsEtat?>) -> String {
        guard var j = joueur, j.vivant, let ab = a.subscription else { return "" }
        var e = j[keyPath: kp] ?? LoisirsEtat()
        let nom = ab.name.lowercased()
        let texte: String
        if e.estAbonne(a.id) {
            e.abonnements.removeAll { $0 == a.id }
            texte = "Tu as résilié ton \(nom). Il a fallu trois lettres recommandées et un duel au regard."
        } else {
            if j.age >= 18 {
                guard j.argent >= ab.yearlyCost else {
                    return "Il te faut \(Format.argent(ab.yearlyCost)) pour t'abonner."
                }
                j.argent -= ab.yearlyCost
                texte = "Tu as pris un \(nom) (\(Format.argent(ab.yearlyCost))/an). Cette fois, c'est la bonne. Promis."
            } else {
                texte = "Tes parents t'ont payé un \(nom). Ils ont dit « tu as intérêt à y aller »."
            }
            e.abonnements.append(a.id)
            e.anneesSansAller[a.id] = 0
        }
        ajouterLigne(&j, texte)
        j[keyPath: kp] = e
        joueur = j
        sauvegarder()
        return texte
    }

    /// À appeler dans `vieillir()` après `j.age += 1` : séries, abandons, abonnements, blessures.
    /// Renvoie les lignes à ajouter au journal de la nouvelle année.
    func passerAnneeLoisirs(_ j: inout Joueur, etat kp: WritableKeyPath<Joueur, LoisirsEtat?>) -> [String] {
        guard var e = j[keyPath: kp] else { return [] }
        var lignes: [String] = []
        let ref = j
        func phrase(_ modele: String, _ a: LoisirActivite, n: Int = 0, s: String = "") -> String {
            remplir(modele.replacingOccurrences(of: "{A}", with: a.title)
                .replacingOccurrences(of: "{n}", with: "\(n)")
                .replacingOccurrences(of: "{s}", with: s), ref)
        }

        // Séries d'années de pratique et abandons.
        var bonusSante = 0, bonusBonheur = 0
        for (id, dernier) in e.dernierAge.sorted(by: { $0.key < $1.key }) {
            guard let a = LoisirsCatalogue.activite(id) else { continue }
            if dernier == j.age - 1 {
                let serie = (e.anneesAffilee[id] ?? 0) + 1
                e.anneesAffilee[id] = serie
                if serie >= 2 {
                    if a.estPhysique { bonusSante += 1 } else { bonusBonheur += 1 }
                }
                if [3, 5, 10, 20].contains(serie) {
                    let pool = a.estPhysique ? LoisirsRegles.textesSeriePhysique : LoisirsRegles.textesSerieTete
                    lignes.append("🔥 " + phrase(pool.randomElement()!, a, n: serie))
                    if a.estPhysique { j.stats.sante += 2 } else { j.stats.bonheur += 2 }
                }
            } else {
                e.anneesAffilee[id] = 0
                if j.age - dernier == 3 && e.niveau(id) >= 2 {
                    lignes.append(phrase(LoisirsRegles.textesAbandon.randomElement()!, a))
                }
            }
        }
        j.stats.sante += min(3, bonusSante)
        j.stats.bonheur += min(3, bonusBonheur)

        // Abonnements : prélevés chaque année (les parents paient avant 18 ans).
        for id in e.abonnements {
            guard let a = LoisirsCatalogue.activite(id), let ab = a.subscription else { continue }
            let nom = ab.name.lowercased()
            if e.seances(id) == 0 {
                e.anneesSansAller[id, default: 0] += 1
                lignes.append(phrase(LoisirsRegles.textesAbonnementInutile.randomElement()!, a, s: nom))
            }
            if j.age >= 18 {
                if j.argent < ab.yearlyCost {
                    e.abonnements.removeAll { $0 == id }
                    lignes.append("💳 Ta banque a refusé le prélèvement de ton \(nom). Abonnement résilié, dignité aussi.")
                } else {
                    j.argent -= ab.yearlyCost
                    lignes.append("💳 \(ab.name) : -\(Format.argent(ab.yearlyCost)).")
                }
            }
        }

        // Blessures.
        var restantes: [LoisirBlessureActive] = []
        for var b in e.blessures {
            b.anneesRestantes -= 1
            j.stats.sante += b.santeParAn
            if b.anneesRestantes <= 0 {
                lignes.append(remplir("🩹 Tu es enfin remis{e} de ta blessure (\(b.nom)).", ref))
            } else {
                if b.santeParAn < 0 { lignes.append("🩹 Ta blessure (\(b.nom)) te fait encore souffrir.") }
                restantes.append(b)
            }
        }
        e.blessures = restantes

        e.seancesAnnee = [:]
        j.stats.borner()
        j[keyPath: kp] = e
        return lignes
    }
}

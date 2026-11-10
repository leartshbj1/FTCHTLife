import Foundation

/// Règles des compétences. Fonctions sans état, utilisables par le moteur et par n'importe quel module.
/// Aucune de ces fonctions n'écrit dans le journal : elles renvoient des phrases que l'appelant ajoute
/// (avec `engine.ajouterLigne`, ou dans les `lignes` de l'année dans `vieillir`).
enum Competences {

    // MARK: - Accès à l'état du joueur

    /// À brancher par le moteur au démarrage : `Competences.acces = \Joueur.competences`.
    /// Tant que ce n'est pas fait, les compétences restent à zéro et les gains sont ignorés.
    static var acces: WritableKeyPath<Joueur, CompetencesEtat?>?

    static func etat(_ j: Joueur) -> CompetencesEtat {
        guard let k = acces else { return CompetencesEtat() }
        return j[keyPath: k] ?? CompetencesEtat()
    }

    static func ecrire(_ e: CompetencesEtat, _ j: inout Joueur) {
        guard let k = acces else { return }
        j[keyPath: k] = e
    }

    // MARK: - Niveaux

    /// XP nécessaire pour atteindre chaque niveau (index = niveau).
    static let seuils = [0, 5, 20, 40, 65, 90]
    static let nomsNiveaux = ["Jamais essayé", "Débutant", "Amateur", "Confirmé", "Expert", "Maître"]
    static let xpMax = 100

    static func niveau(xp: Int) -> Int {
        var n = 0
        for i in 1..<seuils.count where xp >= seuils[i] { n = i }
        return n
    }

    static func xp(_ id: String, _ j: Joueur) -> Int { etat(j).xp[id] ?? 0 }

    static func niveau(_ id: String, _ j: Joueur) -> Int { niveau(xp: xp(id, j)) }

    static func nomNiveau(_ n: Int) -> String { nomsNiveaux[max(0, min(5, n))] }

    /// Titre rigolo du niveau, ex. « Cordon-bleu du dimanche ».
    static func titre(_ def: CompetenceDef, niveau n: Int) -> String {
        guard n >= 1, def.titres.count >= n else { return nomNiveau(n) }
        return def.titres[n - 1]
    }

    /// Avancement dans le niveau en cours, de 0 à 1 (1 au niveau max).
    static func avancement(xp: Int) -> Double {
        let n = niveau(xp: xp)
        guard n < 5 else { return 1 }
        let bas = seuils[n], haut = seuils[n + 1]
        return Double(xp - bas) / Double(haut - bas)
    }

    /// XP restant avant le niveau suivant (nil au niveau max).
    static func xpAvantNiveauSuivant(xp: Int) -> Int? {
        let n = niveau(xp: xp)
        guard n < 5 else { return nil }
        return seuils[n + 1] - xp
    }

    // MARK: - Conditions et choix cachés

    /// Vrai si le joueur a tous les niveaux demandés, ex. ["cuisine": 3, "eloquence": 2].
    static func aLeNiveau(_ exigences: [String: Int]?, _ j: Joueur) -> Bool {
        guard let ex = exigences, !ex.isEmpty else { return true }
        let e = etat(j)
        for (id, mini) in ex where niveau(xp: e.xp[id] ?? 0) < mini {
            return false
        }
        return true
    }

    /// Un choix d'événement est-il visible pour ce joueur ?
    static func choixVisible(_ c: Choix, _ j: Joueur) -> Bool {
        aLeNiveau(c.requiresSkill, j)
    }

    /// Les choix visibles, avec leur index d'origine (à passer tel quel à `engine.choisir`).
    static func choixVisibles(_ choix: [Choix], _ j: Joueur) -> [(index: Int, choix: Choix)] {
        var r: [(index: Int, choix: Choix)] = []
        for (i, c) in choix.enumerated() where choixVisible(c, j) {
            r.append((index: i, choix: c))
        }
        return r
    }

    /// Petit texte à afficher sur un choix caché débloqué, ex. « Cuisine · Confirmé ».
    static func badge(_ c: Choix) -> String? {
        guard let ex = c.requiresSkill, !ex.isEmpty else { return nil }
        let morceaux = ex.keys.sorted().map { id -> String in
            let nom = CatalogueCompetences.def(id)?.nom ?? id
            return nom + " · " + nomNiveau(ex[id] ?? 1)
        }
        return morceaux.joined(separator: " + ")
    }

    /// Icône (symbole SF) de la première compétence exigée par un choix caché.
    static func iconeBadge(_ c: Choix) -> String? {
        guard let id = c.requiresSkill?.keys.sorted().first else { return nil }
        return CatalogueCompetences.def(id)?.icone
    }

    // MARK: - Progression

    /// Multiplicateur d'apprentissage selon l'âge, l'intelligence et le niveau (rendements décroissants).
    static func facteur(_ def: CompetenceDef?, niveau n: Int, _ j: Joueur) -> Double {
        let parNiveau: [Double] = [1.0, 1.0, 0.85, 0.7, 0.55, 0.4]
        var f = parNiveau[max(0, min(5, n))]
        f *= 0.75 + Double(j.stats.intelligence) / 200
        if j.age < 13 {
            f *= def?.bonusEnfant ?? 1.2
        } else if j.age >= 70 {
            f *= 0.65
        } else if j.age >= 55 {
            f *= 0.8
        }
        return f
    }

    /// Ajoute (ou retire si négatif) de l'XP à une compétence.
    /// `brut: true` ignore le multiplicateur (mode triche, récompenses fixes).
    @discardableResult
    static func gagner(_ id: String, _ base: Int, _ j: inout Joueur, brut: Bool = false) -> CompetenceGain {
        var e = etat(j)
        let avant = e.xp[id] ?? 0
        let nAvant = niveau(xp: avant)
        let def = CatalogueCompetences.def(id)
        guard def != nil, base != 0, acces != nil else {
            return CompetenceGain(id: id, gain: 0, niveauAvant: nAvant, niveauApres: nAvant, messages: [])
        }
        var delta = base
        if base > 0 && !brut {
            delta = max(1, Int((Double(base) * facteur(def, niveau: nAvant, j)).rounded()))
        }
        let apres = max(0, min(xpMax, avant + delta))
        let nApres = niveau(xp: apres)
        e.xp[id] = apres
        if delta > 0 { e.dernierePratique[id] = j.age }

        var messages: [String] = []
        if let def = def {
            if nApres > nAvant {
                let meilleur = e.meilleurNiveau[id] ?? 0
                if nApres > meilleur {
                    e.meilleurNiveau[id] = nApres
                    let palier = def.paliers.count >= nApres ? def.paliers[nApres - 1] : ""
                    messages.append("🎯 \(def.nom) : niveau \(nApres), « \(titre(def, niveau: nApres)) ». " + palier)
                } else {
                    messages.append("🎯 Tu retrouves ton niveau en \(def.nom.lowercased()) : « \(titre(def, niveau: nApres)) ».")
                }
            } else if nApres < nAvant {
                messages.append("📉 Tu rouilles en \(def.nom.lowercased()) : retour au niveau « \(nomNiveau(nApres)) ».")
            }
        }
        ecrire(e, &j)
        return CompetenceGain(id: id, gain: apres - avant, niveauAvant: nAvant, niveauApres: nApres,
                              messages: messages.map { $0.trimmingCharacters(in: .whitespaces) })
    }

    /// Applique `effects.skills` d'un événement. Renvoie les phrases de palier à écrire dans le journal.
    @discardableResult
    static func appliquer(_ gains: [String: Int]?, _ j: inout Joueur) -> [String] {
        guard let gains = gains else { return [] }
        var messages: [String] = []
        for id in gains.keys.sorted() {
            messages += gagner(id, gains[id] ?? 0, &j).messages
        }
        return messages
    }

    /// Utiliser un talent dans un choix caché fait un peu progresser. À appeler quand le joueur choisit.
    @discardableResult
    static func apresChoix(_ c: Choix, _ j: inout Joueur) -> [String] {
        guard let ex = c.requiresSkill else { return [] }
        var messages: [String] = []
        for id in ex.keys.sorted() {
            messages += gagner(id, 2, &j).messages
        }
        return messages
    }

    /// Gains liés à une activité de l'onglet Activités (sources de type "activite").
    /// Renvoie un petit texte à ajouter au résultat de l'activité, ex. « (Sport +7 XP) », puis les paliers.
    static func apresActivite(_ activiteId: String, _ j: inout Joueur) -> [String] {
        var resume: [String] = []
        var messages: [String] = []
        for s in CatalogueCompetences.sources where s.type == "activite" && (s.ids ?? []).contains(activiteId) {
            guard ageOK(s, j), Double.random(in: 0..<1) < (s.chance ?? 1) else { continue }
            for id in s.gains.keys.sorted() {
                let g = gagner(id, s.gains[id] ?? 0, &j)
                if g.gain > 0, let def = CatalogueCompetences.def(id) {
                    resume.append("\(def.nom) +\(g.gain) XP")
                }
                messages += g.messages
            }
        }
        guard !resume.isEmpty else { return messages }
        return ["(" + resume.joined(separator: ", ") + ")"] + messages
    }

    // MARK: - Fin d'année

    /// À appeler dans `vieillir`, après le passage de l'âge, l'emploi et les études.
    /// Gains du travail, des études, de l'école, de la retraite, puis l'oubli. Renvoie les lignes de l'année.
    static func finAnnee(_ j: inout Joueur) -> [String] {
        guard acces != nil, j.vivant else { return [] }
        var lignes: [String] = []
        for s in CatalogueCompetences.sources where sourceActive(s, j) {
            guard Double.random(in: 0..<1) < (s.chance ?? 1) else { continue }
            for id in s.gains.keys.sorted() {
                lignes += gagner(id, s.gains[id] ?? 0, &j).messages
            }
        }
        lignes += oublier(&j)
        return lignes
    }

    static func ageOK(_ s: CompetenceSource, _ j: Joueur) -> Bool {
        if let m = s.minAge, j.age < m { return false }
        if let m = s.maxAge, j.age > m { return false }
        return true
    }

    static func sourceActive(_ s: CompetenceSource, _ j: Joueur) -> Bool {
        guard ageOK(s, j) else { return false }
        switch s.type {
        case "metier":
            guard let emploi = j.emploi else { return false }
            if (s.ids ?? []).contains(emploi.metierId) { return true }
            let texte = simplifier(emploi.metierId + " " + emploi.titre)
            return (s.motsCles ?? []).contains { texte.contains(simplifier($0)) }
        case "filiere":
            guard let e = j.etudes else { return false }
            return (s.ids ?? []).contains(e.filiere.rawValue)
        case "etudes":
            return j.etudes != nil
        case "ecole":
            return j.niveauScolaire != nil && j.age >= 6
        case "retraite":
            return j.age >= 65 && j.emploi == nil
        default:
            return false
        }
    }

    /// Sans pratique depuis 4 ans, une compétence au-dessus de 20 XP redescend doucement (jamais sous 20).
    static func oublier(_ j: inout Joueur) -> [String] {
        var e = etat(j)
        var lignes: [String] = []
        for id in e.xp.keys.sorted() {
            let xp = e.xp[id] ?? 0
            guard xp > 20 else { continue }
            let derniere = e.dernierePratique[id] ?? j.age
            guard j.age - derniere >= 4 else { continue }
            let perte = CatalogueCompetences.def(id)?.oubli ?? 2
            ecrire(e, &j)
            let g = gagner(id, -min(perte, xp - 20), &j)
            lignes += g.messages
            e = etat(j)
        }
        return lignes
    }

    static func simplifier(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
    }

    // MARK: - Pratique et cours (logique sans interface)

    static func cleePratique(_ id: String) -> String { "cmp_" + id }
    static func cleeCours(_ id: String) -> String { "cmpc_" + id }

    /// Texte de pratique adapté au niveau.
    static func textePratique(_ def: CompetenceDef, niveau n: Int) -> String {
        let liste: [String]
        switch n {
        case 0...1: liste = def.pratique.debut
        case 2...3: liste = def.pratique.milieu
        default: liste = def.pratique.maitre
        }
        return liste.randomElement() ?? "Tu t'entraînes. C'est déjà ça."
    }

    /// Les compétences accessibles à cet âge, dans l'ordre du catalogue.
    static func accessibles(_ j: Joueur) -> [CompetenceDef] {
        CatalogueCompetences.toutes.filter { j.age >= $0.minAge }
    }

    /// Meilleure compétence du joueur (pour le profil, la nécrologie…).
    static func meilleure(_ j: Joueur) -> (def: CompetenceDef, niveau: Int)? {
        let e = etat(j)
        guard let best = e.xp.max(by: { $0.value < $1.value }), best.value >= seuils[1],
              let def = CatalogueCompetences.def(best.key) else { return nil }
        return (def: def, niveau: niveau(xp: best.value))
    }

    /// Tags à ajouter à `GameEngine.tags` (optionnel) : "skill_<id>" dès le niveau 3, pour les modules qui ne lisent que les tags.
    static func tags(_ j: Joueur) -> Set<String> {
        var t: Set<String> = []
        for (id, xp) in etat(j).xp where niveau(xp: xp) >= 3 {
            t.insert("skill_" + id)
        }
        return t
    }

    /// Mode Shkurtaaa : tout au niveau Maître.
    static func toutAuMax(_ j: inout Joueur) {
        var e = etat(j)
        for def in CatalogueCompetences.toutes {
            e.xp[def.id] = xpMax
            e.dernierePratique[def.id] = j.age
            e.meilleurNiveau[def.id] = 5
        }
        ecrire(e, &j)
    }
}

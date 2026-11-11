import Foundation

// Répercussions : les suites des événements et des actions, qui ressortent des années plus tard.
// Format des données et branchement dans le moteur : docs/REPERCUSSIONS.md.
// Données : FTCHTLife/Resources/Data/Repercussions/*.json (un tableau de Repercussion par fichier).

/// Conditions vérifiées au moment où la suite doit arriver.
/// Reprend les conditions d'événement et ajoute les drapeaux (souvenirs) et les compteurs.
struct RepercussionConditions: Codable, Equatable {
    var gender: String?
    var minMoney: Int?
    var maxMoney: Int?
    var requiresJob: Bool?
    var requiresPartner: Bool?
    var requiresSchool: Bool?
    var tags: [String]?
    var excludeTags: [String]?
    /// Drapeaux que le joueur doit tous avoir.
    var flags: [String]?
    /// Drapeaux que le joueur ne doit pas avoir.
    var excludeFlags: [String]?
    /// Nombre minimal de fois qu'un signal a eu lieu, par ex. {"casino_perte": 5}.
    var minCounters: [String: Int]?
    /// Nombre maximal de fois qu'un signal a eu lieu.
    var maxCounters: [String: Int]?
    /// Le drapeau doit être posé depuis au moins N années, par ex. {"coeur_brise": 2}.
    var flagMinYears: [String: Int]?
    /// Le drapeau doit être posé depuis au plus N années.
    var flagMaxYears: [String: Int]?

    /// Partie « événement classique » des conditions, vérifiée par le moteur.
    var conditionsEvenement: ConditionsEvenement {
        ConditionsEvenement(gender: gender, minMoney: minMoney, maxMoney: maxMoney,
                            requiresJob: requiresJob, requiresPartner: requiresPartner,
                            requiresSchool: requiresSchool, tags: tags, excludeTags: excludeTags)
    }
}

/// Une suite : « quand X arrive, Y arrive N ans plus tard ».
struct Repercussion: Codable, Identifiable, Equatable {
    var id: String
    /// Signal déclencheur : "event:<id d'événement>" ou un signal de module ("mariage", "casino_perte"…).
    var on: String
    /// Pour un événement : index du choix (à partir de 0). Absent = n'importe quel choix.
    var choice: Int?
    /// Pour un événement : index de l'issue dans le choix (à partir de 0). Absent = n'importe quelle issue.
    var outcome: Int?
    /// Probabilité (0…1) que la suite soit programmée quand le signal arrive. Défaut 1.
    var chance: Double?
    /// Délai en années [min, max] après le signal. Défaut [1, 1]. 0 = à la fin de la même année.
    var delay: [Int]?
    /// Si la suite ne peut pas arriver à l'échéance (conditions, prison…), on réessaie pendant ce nombre d'années. Défaut 2.
    var patience: Int?
    /// N'arrive qu'une fois par vie. Défaut false.
    var unique: Bool?
    /// Âge du joueur requis au moment où la suite arrive.
    var minAge: Int?
    var maxAge: Int?
    /// Conditions vérifiées à l'échéance.
    var conditions: RepercussionConditions?
    /// Conditions vérifiées au moment du signal (drapeaux et compteurs seulement), pour ne pas programmer inutilement.
    var requires: RepercussionConditions?
    /// Drapeaux posés tout de suite, au moment du signal (même si la suite n'est pas tirée).
    var remember: [String]?
    /// Drapeaux retirés tout de suite, au moment du signal.
    var forget: [String]?
    /// Signaux émis tout de suite, au moment du signal (même si `chance` rate). Sert à traduire un choix
    /// d'événement en signal commun, par ex. "event:adu_0042" choix 1 → "tromperie".
    var emit: [String]?
    /// Drapeaux posés quand la suite arrive.
    var setFlags: [String]?
    /// Drapeaux retirés quand la suite arrive.
    var clearFlags: [String]?
    /// Catégorie de l'événement produit (défaut "suite"). Ex. "prison" pour une suite qui peut arriver en prison :
    /// le moteur n'y laisse passer que les catégories "prison" et "sante".
    var category: String?
    /// Texte de la suite. Absent = la règle ne fait que poser des drapeaux.
    var text: String?
    var effects: Effets?
    var choices: [Choix]?
}

/// Une suite programmée, en attente de son échéance. Stockée dans la sauvegarde.
struct RepercussionProgrammee: Codable, Equatable {
    var id: String
    /// Âge du joueur à partir duquel la suite arrive.
    var age: Int
    /// Dernier âge où elle peut encore arriver (échéance + patience).
    var ageMax: Int
}

/// État des répercussions d'une vie, à stocker dans `Joueur` (champ optionnel).
struct RepercussionsEtat: Codable, Equatable {
    /// Drapeaux (souvenirs) actifs → âge auquel ils ont été posés.
    var flags: [String: Int] = [:]
    /// Nombre de fois que chaque signal est arrivé ("casino_perte", "event:base_0011", "event:base_0011/0").
    var compteurs: [String: Int] = [:]
    var programmees: [RepercussionProgrammee] = []
    /// Ids des suites uniques déjà arrivées ou programmées.
    var uniquesVues: [String] = []

    init() {}

    func a(_ flag: String) -> Bool { flags[flag] != nil }
    func compteur(_ signal: String) -> Int { compteurs[signal] ?? 0 }
}

enum Repercussions {
    /// Toutes les règles de tous les fichiers de Data/Repercussions.
    static let toutes: [Repercussion] = DonneesJSON.chargerTableaux(dossier: "Repercussions", type: Repercussion.self)

    private static let parSignal: [String: [Repercussion]] = Dictionary(grouping: toutes, by: { $0.on })
    private static let parId: [String: Repercussion] = Dictionary(toutes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func regle(_ id: String) -> Repercussion? { parId[id] }

    /// Années pendant lesquelles une suite bloquée (conditions non remplies, joueur en prison…) attend avant d'être oubliée.
    static let patienceParDefaut = 2

    // MARK: - Signaux

    /// À appeler quand quelque chose arrive au joueur.
    /// - Événement : `signaler("event:\(e.id)", choix: i, issue: k, ...)` (choix/issue absents pour un événement sans choix).
    /// - Module : `signaler("mariage", ...)`, `signaler("casino_perte", ...)` (liste dans docs/REPERCUSSIONS.md).
    /// Pose les drapeaux immédiats et programme les suites. Ne touche pas aux stats.
    static func signaler(_ signal: String, choix: Int? = nil, issue: Int? = nil,
                         age: Int, etat: inout RepercussionsEtat) {
        signaler(signal, choix: choix, issue: issue, age: age, etat: &etat, profondeur: 0)
    }

    private static func signaler(_ signal: String, choix: Int?, issue: Int?,
                                 age: Int, etat: inout RepercussionsEtat, profondeur: Int) {
        etat.compteurs[signal, default: 0] += 1
        if let c = choix { etat.compteurs["\(signal)/\(c)", default: 0] += 1 }

        for r in parSignal[signal] ?? [] {
            if let c = r.choice, c != choix { continue }
            if let o = r.outcome, o != issue { continue }
            if let req = r.requires, !drapeauxOK(req, etat, age: age) { continue }
            if r.unique == true && etat.uniquesVues.contains(r.id) { continue }

            for f in r.forget ?? [] { etat.flags[f] = nil }
            for f in r.remember ?? [] where etat.flags[f] == nil { etat.flags[f] = age }
            if profondeur < 4 {
                for autre in r.emit ?? [] where autre != signal {
                    signaler(autre, choix: nil, issue: nil, age: age, etat: &etat, profondeur: profondeur + 1)
                }
            }

            guard r.text != nil || r.setFlags != nil || r.clearFlags != nil else { continue }  // règle de marquage / traduction seule
            guard Double.random(in: 0..<1) < (r.chance ?? 1) else { continue }
            programmer(r, age: age, etat: &etat)
        }
    }

    /// Programme directement une suite par son id (par ex. depuis un effet "followUps").
    static func programmer(id: String, age: Int, etat: inout RepercussionsEtat) {
        guard let r = parId[id] else { return }
        if r.unique == true && etat.uniquesVues.contains(r.id) { return }
        programmer(r, age: age, etat: &etat)
    }

    private static func programmer(_ r: Repercussion, age: Int, etat: inout RepercussionsEtat) {
        let d = r.delay ?? [1, 1]
        let mini = max(0, d.first ?? 1)
        let maxi = max(mini, d.count > 1 ? d[1] : mini)
        let echeance = age + Int.random(in: mini...maxi)
        // Les échéances ne sont vérifiées qu'au passage d'année : une suite à délai 0 signalée en cours d'année
        // doit encore être valable au prochain passage (âge + 1), sinon elle serait oubliée.
        let dernier = max(echeance, age + 1) + max(0, r.patience ?? patienceParDefaut)
        etat.programmees.append(RepercussionProgrammee(id: r.id, age: echeance, ageMax: dernier))
        if r.unique == true { etat.uniquesVues.append(r.id) }
    }

    // MARK: - Échéances

    /// À appeler une fois par année, après le vieillissement et avant le tirage des événements aléatoires.
    /// Rend les suites qui arrivent cette année, sous forme d'événements à déclencher comme les autres
    /// (texte + effets dans le journal, ou carte à choix). `conditionsOK` est la vérification du moteur
    /// pour les conditions classiques (âge compris : l'événement rendu a minAge/maxAge).
    /// Les drapeaux "setFlags"/"clearFlags" des suites rendues sont appliqués ici.
    static func echeances(age: Int, etat: inout RepercussionsEtat,
                          conditionsOK: (Evenement) -> Bool) -> [Evenement] {
        var arrivees: [Evenement] = []
        var restantes: [RepercussionProgrammee] = []

        for p in etat.programmees {
            guard let r = parId[p.id] else { continue }          // règle supprimée : on oublie
            if p.age > age { restantes.append(p); continue }     // pas encore
            if p.ageMax < age { continue }                       // trop tard : on oublie
            let e = evenement(r)
            let ok = (r.conditions.map { drapeauxOK($0, etat, age: age) } ?? true) && conditionsOK(e)
            if !ok {
                if age < p.ageMax { restantes.append(p) }        // on retentera l'an prochain
                continue
            }
            for f in r.clearFlags ?? [] { etat.flags[f] = nil }
            for f in r.setFlags ?? [] where etat.flags[f] == nil { etat.flags[f] = age }
            if r.text != nil { arrivees.append(e) }
        }
        etat.programmees = restantes
        return arrivees + etatsDurables(age: age, etat: &etat, conditionsOK: conditionsOK)
    }

    /// Signal spécial : les règles "on": "chaque_annee" sont évaluées à chaque passage d'année, sans être programmées.
    /// Elles décrivent des états durables (« tu fumes », « tu as des dettes », « tu cours trois fois par semaine »)
    /// qui pèsent un peu chaque année sur les stats, et leur guérison ou aggravation.
    static let signalAnnuel = "chaque_annee"
    /// Nombre maximal d'états durables affichés par an (les règles sans texte ne comptent pas).
    static let maxEtatsParAn = 3

    private static func etatsDurables(age: Int, etat: inout RepercussionsEtat,
                                      conditionsOK: (Evenement) -> Bool) -> [Evenement] {
        let candidates = (parSignal[signalAnnuel] ?? []).filter { r in
            if r.unique == true && etat.uniquesVues.contains(r.id) { return false }
            if let c = r.conditions, !drapeauxOK(c, etat, age: age) { return false }
            return conditionsOK(evenement(r))
        }.shuffled()
        var arrivees: [Evenement] = []
        for r in candidates {
            guard Double.random(in: 0..<1) < (r.chance ?? 1) else { continue }
            if r.text != nil && arrivees.count >= maxEtatsParAn { continue }
            // Un drapeau retiré par un état plus tôt cette année peut rendre un autre état caduc.
            if let c = r.conditions, !drapeauxOK(c, etat, age: age) { continue }
            for f in r.forget ?? [] { etat.flags[f] = nil }
            for f in r.remember ?? [] where etat.flags[f] == nil { etat.flags[f] = age }
            for f in r.clearFlags ?? [] { etat.flags[f] = nil }
            for f in r.setFlags ?? [] where etat.flags[f] == nil { etat.flags[f] = age }
            if r.unique == true { etat.uniquesVues.append(r.id) }
            etat.compteurs["\(signalAnnuel):\(r.id)", default: 0] += 1
            if r.text != nil { arrivees.append(evenement(r)) }
        }
        return arrivees
    }

    /// Transforme une suite en événement affichable par le moteur.
    static func evenement(_ r: Repercussion) -> Evenement {
        Evenement(id: r.id, category: r.category ?? "suite", minAge: r.minAge ?? 0, maxAge: r.maxAge ?? 200,
                  weight: 1, unique: nil, conditions: r.conditions?.conditionsEvenement,
                  text: r.text ?? "", effects: r.effects, choices: r.choices)
    }

    // MARK: - Drapeaux

    /// Pose ou retire des drapeaux (pour un effet "setFlags"/"clearFlags" d'événement).
    static func appliquerDrapeaux(poser: [String]?, retirer: [String]?, age: Int, etat: inout RepercussionsEtat) {
        for f in retirer ?? [] { etat.flags[f] = nil }
        for f in poser ?? [] where etat.flags[f] == nil { etat.flags[f] = age }
    }

    /// Vérifie flags / excludeFlags d'un événement classique.
    static func drapeauxOK(flags: [String]?, excludeFlags: [String]?, etat: RepercussionsEtat?) -> Bool {
        let actifs = Set(etat?.flags.keys.map { $0 } ?? [])
        if let f = flags, !Set(f).isSubset(of: actifs) { return false }
        if let x = excludeFlags, !Set(x).isDisjoint(with: actifs) { return false }
        return true
    }

    static func drapeauxOK(_ c: RepercussionConditions, _ etat: RepercussionsEtat, age: Int) -> Bool {
        guard drapeauxOK(flags: c.flags, excludeFlags: c.excludeFlags, etat: etat) else { return false }
        for (f, n) in c.flagMinYears ?? [:] {
            guard let pose = etat.flags[f], age - pose >= n else { return false }
        }
        for (f, n) in c.flagMaxYears ?? [:] {
            guard let pose = etat.flags[f], age - pose <= n else { return false }
        }
        for (s, n) in c.minCounters ?? [:] where etat.compteur(s) < n { return false }
        for (s, n) in c.maxCounters ?? [:] where etat.compteur(s) > n { return false }
        return true
    }
}

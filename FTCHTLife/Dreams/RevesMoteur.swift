import Foundation

/// Ce qu'une mise à jour des rêves produit : lignes à écrire dans le journal et variation de bonheur.
struct RevesBilan: Equatable {
    var lignes: [String] = []
    var bonheur: Int = 0
}

/// Logique des rêves de vie : tirage à 16 ans, rêves réalisés ou ratés, score « vie réussie ».
/// Tout est autonome : le moteur appelle ces fonctions (voir docs/reves-format.md, « Branchement »).
enum RevesMoteur {
    static let ageTirage = 16
    static let nombreDeReves = 3
    /// Malus de bonheur quand un rêve est raté (date limite dépassée).
    static let malusRate = 5
    /// Bonus quand les 3 rêves sont réalisés.
    static let bonusTousRealises = 15

    static let catalogue: [ReveDefinition] = DonneesJSON.chargerTableaux(dossier: "Dreams", type: ReveDefinition.self)

    static let parId: [String: ReveDefinition] = Dictionary(catalogue.map { ($0.id, $0) },
                                                           uniquingKeysWith: { premier, _ in premier })

    static func definition(_ id: String) -> ReveDefinition? { parId[id] }

    // MARK: - Mise à jour annuelle

    /// Tire les rêves à 16 ans, puis vérifie chaque rêve en cours (réalisé, ou raté si la date limite est passée).
    /// À appeler chaque année et après chaque choix ou action. Ne fait rien si le joueur est mort.
    static func mettreAJour(_ etat: inout RevesDeVie, joueur j: Joueur) -> RevesBilan {
        var bilan = RevesBilan()
        guard j.vivant else { return bilan }

        if !etat.tire {
            guard j.age >= ageTirage else { return bilan }
            etat.reves = tirer(pour: j, marques: etat.marques)
            etat.ageTirage = j.age
            if !etat.reves.isEmpty {
                let titres = etat.reves.compactMap { definition($0.id) }.map { "« \(texte($0.title, j)) »" }
                bilan.lignes.append("🌠 " + phrasesTirage.randomElement()! + " " + titres.joined(separator: ", ") + ". (Voir le profil.)")
            }
        }

        for i in etat.reves.indices where etat.reves[i].statut == .enCours {
            guard let r = definition(etat.reves[i].id) else { continue }
            if estRealise(r, j, marques: etat.marques) {
                etat.reves[i].statut = .realise
                etat.reves[i].ageFin = j.age
                bilan.bonheur += r.bonheur
                bilan.lignes.append("🌟 Rêve réalisé : \(texte(r.title, j)) ! \(texte(r.achievedText, j)) (+\(r.bonheur) bonheur)")
            } else if let limite = r.deadlineAge, j.age >= limite {
                etat.reves[i].statut = .rate
                etat.reves[i].ageFin = j.age
                bilan.bonheur -= malusRate
                let raison = r.failedText.map { texte($0, j) } ?? phrasesRate.randomElement()!
                bilan.lignes.append("💔 Rêve raté : \(texte(r.title, j)). \(raison)")
            }
        }

        if !etat.bonusTousRealises, etat.reves.count >= nombreDeReves,
           etat.reves.allSatisfy({ $0.statut == .realise }) {
            etat.bonusTousRealises = true
            bilan.bonheur += bonusTousRealises
            bilan.lignes.append("🏆 Tes \(etat.reves.count) rêves sont réalisés. Tu peux mourir tranquille. Mais pas tout de suite, hein. (+\(bonusTousRealises) bonheur)")
        }
        return bilan
    }

    static let phrasesTirage = [
        "Tu écris tes rêves secrets dans un carnet caché sous ton matelas :",
        "Une nuit d'insomnie, tu te fixes trois rêves pour ta vie :",
        "Entre deux crises d'ado, tu notes tes rêves secrets au dos d'un ticket de caisse :",
        "Tu as fait le point sur ta vie (à 16 ans, c'est rapide). Tes rêves secrets :",
    ]

    static let phrasesRate = [
        "Trop tard. Tu fais semblant de ne jamais l'avoir voulu.",
        "Le train est passé. Tu étais aux toilettes.",
        "Tu ranges ce rêve dans un carton, à côté de ton vélo d'appartement.",
    ]

    // MARK: - Tirage

    /// Tire un rêve par niveau (sérieux, ambitieux, absurde), en évitant ceux déjà réalisés ou impossibles.
    static func tirer(pour j: Joueur, marques: [String] = []) -> [ReveActif] {
        let possibles = catalogue.filter { eligible($0, j) && !estRealise($0, j, marques: marques) }
        var choisis: [ReveDefinition] = []
        for niveau in ReveNiveau.allCases {
            let candidats = possibles.filter { $0.level == niveau && compatible($0, choisis) }
            if let r = tirage(candidats) { choisis.append(r) }
        }
        // S'il manque un niveau dans le catalogue, on complète avec n'importe quel rêve.
        while choisis.count < nombreDeReves {
            let reste = possibles.filter { compatible($0, choisis) }
            guard let r = tirage(reste) else { break }
            choisis.append(r)
        }
        return choisis.map { ReveActif(id: $0.id) }
    }

    /// Évite deux rêves identiques ou qui se réalisent avec la même marque (ex. deux « voir la mer »).
    private static func compatible(_ r: ReveDefinition, _ choisis: [ReveDefinition]) -> Bool {
        let marques = Set((r.marks ?? []) + [r.id])
        return !choisis.contains { autre in
            autre.id == r.id || !marques.isDisjoint(with: (autre.marks ?? []) + [autre.id])
        }
    }

    static func eligible(_ r: ReveDefinition, _ j: Joueur) -> Bool {
        if r.gender == "male" && j.genre != .homme { return false }
        if r.gender == "female" && j.genre != .femme { return false }
        if let limite = r.deadlineAge, j.age >= limite { return false }
        for besoin in r.requires ?? [] {
            switch besoin {
            case "mother": if j.mere?.vivant != true { return false }
            case "father": if j.pere?.vivant != true { return false }
            case "siblings":
                if !j.relations.contains(where: { ($0.type == .frere || $0.type == .soeur) && $0.vivant }) { return false }
            case "friend": if j.amis.isEmpty { return false }
            default: break
            }
        }
        return true
    }

    private static func tirage(_ liste: [ReveDefinition]) -> ReveDefinition? {
        let total = liste.reduce(0.0) { $0 + max(0, $1.weight ?? 1) }
        guard total > 0 else { return liste.randomElement() }
        var r = Double.random(in: 0..<total)
        for element in liste {
            r -= max(0, element.weight ?? 1)
            if r < 0 { return element }
        }
        return liste.last
    }

    // MARK: - Réalisation

    static func estRealise(_ r: ReveDefinition, _ j: Joueur, marques: [String]) -> Bool {
        if marques.contains(r.id) { return true }
        if let m = r.marks, m.contains(where: { marques.contains($0) }) { return true }
        if let c = r.conditions, c != ReveConditions() { return conditionsRemplies(c, j) }
        return false
    }

    static func conditionsRemplies(_ c: ReveConditions, _ j: Joueur) -> Bool {
        func auMoins(_ seuil: Int?, _ valeur: Int) -> Bool { seuil.map { valeur >= $0 } ?? true }
        func auPlus(_ seuil: Int?, _ valeur: Int) -> Bool { seuil.map { valeur <= $0 } ?? true }
        let s = j.stats

        guard auMoins(c.minMoney, j.argent), auPlus(c.maxMoney, j.argent),
              auMoins(c.minHappiness, s.bonheur), auPlus(c.maxHappiness, s.bonheur),
              auMoins(c.minHealth, s.sante), auPlus(c.maxHealth, s.sante),
              auMoins(c.minSmarts, s.intelligence), auPlus(c.maxSmarts, s.intelligence),
              auMoins(c.minLooks, s.apparence), auPlus(c.maxLooks, s.apparence),
              auMoins(c.minKarma, s.karma), auPlus(c.maxKarma, s.karma),
              auMoins(c.minAge, j.age) else { return false }

        if let d = c.minDiploma {
            guard let niveau = diplome(d), j.diplome >= niveau else { return false }
        }
        if let f = c.diplomaField {
            guard j.filiereDiplome?.rawValue == f else { return false }
        }
        if let ids = c.jobs {
            guard let e = j.emploi, ids.contains(e.metierId) else { return false }
        }
        if let mots = c.jobTitleContains {
            guard let e = j.emploi else { return false }
            let titre = normaliser(e.titre)
            guard mots.contains(where: { titre.contains(normaliser($0)) }) else { return false }
        }
        if c.minJobLevel != nil || c.minJobYears != nil || c.minSalary != nil {
            guard let e = j.emploi,
                  auMoins(c.minJobLevel, e.niveau),
                  auMoins(c.minJobYears, e.annees),
                  auMoins(c.minSalary, e.salaire) else { return false }
        }
        if let u = c.unemployed {
            let sansRien = j.age >= 18 && j.emploi == nil && j.etudes == nil
            guard u == sansRien else { return false }
        }
        if let p = c.partner {
            let aPartenaire = j.relations.contains(where: { $0.type == .partenaire && $0.vivant })
            guard p == aPartenaire else { return false }
        }
        if let n = c.minChildren {
            guard j.relations.filter({ $0.type == .enfant && $0.vivant }).count >= n else { return false }
        }
        if let n = c.minFriends {
            guard j.amis.count >= n else { return false }
        }
        if let vus = c.seenEvents {
            guard vus.allSatisfy({ j.evenementsVus.contains($0) }) else { return false }
        }
        return true
    }

    static func diplome(_ nom: String) -> Diplome? {
        switch nom {
        case "aucun": return .aucun
        case "ecoleObligatoire": return .ecoleObligatoire
        case "bac": return .bac
        case "licence": return .licence
        case "master": return .master
        case "doctorat": return .doctorat
        default: return nil
        }
    }

    static func normaliser(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
    }

    // MARK: - Marques et tags

    /// Pose des marques (venant d'un événement `dreamMarks` ou d'un autre module). Un rêve qui attend une de ces marques
    /// sera réalisé à la prochaine mise à jour. Les marques posées avant 16 ans comptent aussi : le tirage évite ces rêves.
    static func marquer(_ etat: inout RevesDeVie?, _ marques: [String]) {
        var e = etat ?? RevesDeVie()
        marquer(&e, marques)
        etat = e
    }

    static func marquer(_ etat: inout RevesDeVie, _ marques: [String]) {
        for m in marques where !m.isEmpty && !etat.marques.contains(m) {
            etat.marques.append(m)
        }
    }

    /// Tags pour filtrer les événements : l'id de chaque rêve en cours (ex. "reve_ping_pong_pere").
    static func tags(_ etat: RevesDeVie?) -> Set<String> {
        guard let e = etat else { return [] }
        return Set(e.enCours.map(\.id))
    }

    // MARK: - Textes

    /// Remplace {prenom}, {nom}, {ville}, {mere}, {pere}, {fratrie} et {e}.
    static func texte(_ s: String, _ j: Joueur) -> String {
        let fratrie = j.relations.first { ($0.type == .frere || $0.type == .soeur) && $0.vivant }
        let remplacements: [(String, String)] = [
            ("{prenom}", j.prenom),
            ("{nom}", j.nom),
            ("{ville}", j.ville),
            ("{mere}", j.mere?.prenom ?? "ta mère"),
            ("{pere}", j.pere?.prenom ?? "ton père"),
            ("{fratrie}", fratrie?.prenom ?? "ton cousin"),
            ("{e}", j.genre == .femme ? "e" : ""),
        ]
        var t = s
        for (cle, valeur) in remplacements {
            t = t.replacingOccurrences(of: cle, with: valeur)
        }
        return t
    }

    static func titre(_ actif: ReveActif, _ j: Joueur) -> String {
        definition(actif.id).map { texte($0.title, j) } ?? "Un rêve oublié"
    }

    // MARK: - Score « vie réussie »

    /// Juste le score sur 100 (pour la nécrologie et le musée) : `RevesMoteur.scoreVieReussie(j.reves, joueur: j)`.
    static func scoreVieReussie(_ etat: RevesDeVie?, joueur j: Joueur) -> Int {
        score(etat, joueur: j).total
    }

    /// Score sur 100 : 60 points pour les rêves (pondérés par leurs points), 40 pour la vie en général.
    static func score(_ etat: RevesDeVie?, joueur j: Joueur) -> RevesScore {
        let actifs = (etat?.reves ?? []).compactMap { a in definition(a.id).map { (a, $0) } }
        let possible = actifs.reduce(0) { $0 + $1.1.valeur }
        let obtenu = actifs.filter { $0.0.statut == .realise }.reduce(0) { $0 + $1.1.valeur }
        let nbRealises = actifs.filter { $0.0.statut == .realise }.count

        // La vie en général (sur 40).
        let enfants = j.relations.filter { $0.type == .enfant && $0.vivant }.count
        let partenaire = j.relations.contains(where: { $0.type == .partenaire && $0.vivant }) ? 1 : 0
        let bonheur = Double(j.stats.bonheur) / 100 * 12
        let karma = Double(j.stats.karma) / 100 * 8
        let longevite = min(1, Double(j.age) / 90) * 8
        let entourage = min(1, Double(j.amis.count + 2 * partenaire + 2 * enfants) / 8) * 6
        let rangDiplome = Double(j.diplome.rawValue) / Double(Diplome.doctorat.rawValue)
        let fortune = j.argent <= 1 ? 0 : min(1, log10(Double(j.argent)) / 7)
        let reussite = (rangDiplome + fortune) / 2 * 6
        let partVie = Int((bonheur + karma + longevite + entourage + reussite).rounded())

        let partReves: Int
        let total: Int
        if possible > 0 {
            partReves = Int((60 * Double(obtenu) / Double(possible)).rounded())
            total = min(100, partReves + partVie)
        } else {
            // Mort avant d'avoir des rêves : on note seulement la vie, ramenée sur 100.
            partReves = 0
            total = min(100, Int((Double(partVie) * 2.5).rounded()))
        }

        var details: [String] = []
        for (a, r) in actifs {
            let t = texte(r.title, j)
            switch a.statut {
            case .realise: details.append("✓ \(t)" + (a.ageFin.map { " (à \($0) ans)" } ?? ""))
            case .rate: details.append("✗ \(t)" + (a.ageFin.map { " (raté à \($0) ans)" } ?? ""))
            case .enCours: details.append("… \(t) (jamais réalisé)")
            }
        }

        let (libelle, commentaire) = Self.mention(total: total, aDesReves: possible > 0,
                                                  tousRealises: possible > 0 && obtenu == possible)
        return RevesScore(total: total, partReves: partReves, partVie: partVie,
                          revesRealises: nbRealises, revesTires: actifs.count,
                          mention: libelle, commentaire: commentaire, details: details)
    }

    static func mention(total: Int, aDesReves: Bool, tousRealises: Bool) -> (String, String) {
        if !aDesReves {
            return ("Vie trop courte pour rêver", "Tu n'as même pas eu le temps d'avoir des rêves. Le destin a été radin.")
        }
        if tousRealises && total >= 90 {
            return ("Légende", "Tous tes rêves, et une vie au top. Les anges veulent un autographe.")
        }
        switch total {
        case 90...: return ("Vie réussie haut la main", "Tu peux reposer en paix, et même te vanter un peu.")
        case 75..<90: return ("Vie réussie", "Pas parfaite, mais tu as coché l'essentiel. Bravo.")
        case 60..<75: return ("Belle vie", "Quelques regrets, beaucoup de souvenirs. Le bon ratio.")
        case 40..<60: return ("Vie correcte", "Ni ratée ni réussie. Une vie format standard, livrée sans options.")
        case 20..<40: return ("Vie bancale", "Il y a eu de bons moments. Il fallait bien chercher.")
        default: return ("Vie ratée avec panache", "Au moins, personne ne t'oubliera. Surtout pas tes créanciers.")
        }
    }
}

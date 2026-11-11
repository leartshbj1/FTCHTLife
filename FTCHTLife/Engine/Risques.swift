import Foundation

// Idée 59 : le risque de chaque choix est affiché avant de choisir.
// Calculé à partir des issues (chances et effets) : on ne montre ni les chiffres ni les issues,
// seulement un niveau (« Risqué ») et ce qui est en jeu (santé, argent, liberté…).
// Un auteur peut forcer le niveau avec `"risk": "high"` sur un choix. Voir docs/SCENES.md.

enum NiveauRisque: Int, Comparable {
    case aucun, faible, moyen, eleve, extreme

    static func < (a: NiveauRisque, b: NiveauRisque) -> Bool { a.rawValue < b.rawValue }

    init?(cle: String) {
        switch cle {
        case "none": self = .aucun
        case "low": self = .faible
        case "medium": self = .moyen
        case "high": self = .eleve
        case "extreme": self = .extreme
        default: return nil
        }
    }
}

/// Ce qu'un choix peut coûter.
enum EnjeuRisque: String, CaseIterable {
    case vie, liberte, sante, argent, coeur, proches, moral, reputation

    var nom: String {
        switch self {
        case .vie: return "ta vie"
        case .liberte: return "ta liberté"
        case .sante: return "santé"
        case .argent: return "argent"
        case .coeur: return "ton couple"
        case .proches: return "tes proches"
        case .moral: return "moral"
        case .reputation: return "réputation"
        }
    }

    var icone: String {
        switch self {
        case .vie: return "bolt.heart.fill"
        case .liberte: return "lock.fill"
        case .sante: return "cross.case.fill"
        case .argent: return "eurosign.circle.fill"
        case .coeur: return "heart.slash.fill"
        case .proches: return "person.2.fill"
        case .moral: return "cloud.rain.fill"
        case .reputation: return "megaphone.fill"
        }
    }
}

/// Risque d'un choix, prêt à afficher.
struct RisqueChoix: Equatable {
    let niveau: NiveauRisque
    /// Ce qui est en jeu, du plus grave au moins grave (3 au plus).
    let enjeux: [EnjeuRisque]
    /// Quitte ou double : une bonne chance de gros gain ET une bonne chance de grosse perte.
    let pari: Bool
    /// Probabilité que ça tourne mal (0…1).
    let chanceMauvaise: Double

    var titre: String {
        switch niveau {
        case .aucun: return "Sans risque"
        case .faible: return "Risque faible"
        case .moyen: return pari ? "Quitte ou double" : "Risqué"
        case .eleve: return pari ? "Gros pari" : "Très risqué"
        case .extreme: return enjeux.first == .vie ? "Danger de mort" : "Extrêmement risqué"
        }
    }

    /// « souvent », « parfois »… : à quelle fréquence ça tourne mal.
    var frequence: String? {
        guard niveau >= .faible else { return nil }
        switch chanceMauvaise {
        case ..<0.12: return "rarement"
        case ..<0.35: return "parfois"
        case ..<0.65: return "souvent"
        default: return "presque toujours"
        }
    }

    /// Texte complet pour VoiceOver.
    var description: String {
        var t = titre
        if !enjeux.isEmpty { t += ", en jeu : " + enjeux.map(\.nom).joined(separator: ", ") }
        if let f = frequence { t += ", ça tourne mal \(f)" }
        return t
    }
}

enum Risques {

    /// Mots-clés d'un drapeau qui abîme durablement (habitudes, dettes, réputation).
    static let drapeauxNefastes: [String: EnjeuRisque] = [
        "fume": .sante, "boit_trop": .sante, "mange_mal": .sante, "sedentaire": .sante, "insomniaque": .sante,
        "dos_fragile": .sante, "genou_fragile": .sante, "accro_aux_ecrans": .moral, "deprime": .moral, "anxieux": .moral,
        "burn_out": .moral, "coeur_brise": .moral, "solitaire": .moral, "complexe": .moral, "traumatise": .moral,
        "menteur_notoire": .reputation, "rapporteur": .reputation, "harcele": .moral, "honte_publique": .reputation,
        "casier_judiciaire": .liberte, "sous_controle_judiciaire": .liberte, "endette": .argent, "panier_perce": .argent,
        "dette_louche": .argent, "surendette": .argent, "voleur": .reputation, "rancunier": .proches,
    ]

    /// Gravité d'une issue (0 = rien de mauvais) et ce qu'elle touche.
    static func perte(_ eff: Effets?, argentJoueur: Int) -> (score: Double, enjeux: [EnjeuRisque: Double]) {
        guard let e = eff else { return (0, [:]) }
        var enjeux: [EnjeuRisque: Double] = [:]
        func ajoute(_ x: EnjeuRisque, _ v: Double) { if v > 0 { enjeux[x, default: 0] += v } }

        if e.death != nil { ajoute(.vie, 100) }
        if let v = e.vie {
            if let m = v.jailMonths, m > 0 { ajoute(.liberte, 35 + min(40, Double(m) / 2)) }
            if (v.record ?? 0) > 0 || v.enquete == true { ajoute(.liberte, 18) }
            if let f = v.fine, f > 0 { ajoute(.argent, perteArgent(f, argentJoueur)) }
            if v.disease != nil { ajoute(.sante, 25) }
            if v.addiction != nil { ajoute(.sante, 28) }
            if v.breakup == true { ajoute(.coeur, 25) }
            if v.targetDies != nil { ajoute(.proches, 45) }
            if v.saisie == true { ajoute(.argent, 15) }
        }
        if e.casier?.condamnation != nil { ajoute(.liberte, 20) }
        if let c = e.coeur {
            if c.decouverte == true || c.trahisonDecouverte == true { ajoute(.coeur, 22) }
            if let s = c.scandale, s > 0 { ajoute(.reputation, Double(s) / 2) }
            if let cr = c.crise, cr > 0 { ajoute(.coeur, min(30, Double(cr) * 8)) }
        }
        ajoute(.sante, -Double(e.health ?? 0) * 1.1)
        ajoute(.moral, -Double(e.happiness ?? 0) * 0.5)
        ajoute(.moral, -Double(e.looks ?? 0) * 0.3)
        if let m = e.money, m < 0 { ajoute(.argent, perteArgent(-m, argentJoueur)) }
        let liens = (e.relationships ?? [:]).values.filter { $0 < 0 }.reduce(0, +)
        ajoute((e.relationships?["partner"] ?? 0) < 0 ? .coeur : .proches, -Double(liens) * 0.5)
        for f in e.setFlags ?? [] {
            if let x = drapeauxNefastes[f] { ajoute(x, 10) }
        }
        let score = min(100, enjeux.values.reduce(0, +))
        return (score, enjeux)
    }

    /// Une perte d'argent pèse selon ce que le joueur possède : 500 € ne font pas peur à un millionnaire.
    static func perteArgent(_ montant: Int, _ argent: Int) -> Double {
        let base = Double(max(3000, argent))
        return min(45, Double(montant) / base * 40)
    }

    /// Gain d'une issue, pour repérer les quitte ou double.
    static func gain(_ eff: Effets?, argentJoueur: Int) -> Double {
        guard let e = eff else { return 0 }
        var g = 0.0
        g += max(0, Double(e.happiness ?? 0)) * 0.5
        g += max(0, Double(e.health ?? 0))
        if let m = e.money, m > 0 { g += min(45, Double(m) / Double(max(3000, argentJoueur)) * 40) }
        return g
    }

    /// Risque d'un choix pour ce joueur, ou nil si on ne peut rien en dire (issues résolues ailleurs).
    static func evaluer(_ c: Choix, argentJoueur: Int) -> RisqueChoix? {
        let issues = c.outcomes
        let force = c.risk.flatMap(NiveauRisque.init(cle:))
        guard !issues.isEmpty else { return force.map { RisqueChoix(niveau: $0, enjeux: [], pari: false, chanceMauvaise: 0.5) } }
        let total = issues.reduce(0.0) { $0 + max(0, $1.chance ?? 1) }
        guard total > 0 else { return nil }

        var attendu = 0.0, pire = 0.0, mauvaise = 0.0, chanceGrosGain = 0.0, chanceGrossePerte = 0.0
        var enjeux: [EnjeuRisque: Double] = [:]
        for i in issues {
            let p = max(0, i.chance ?? 1) / total
            let (score, parEnjeu) = perte(i.effects, argentJoueur: argentJoueur)
            attendu += p * score
            if p >= 0.04 { pire = max(pire, score) }
            if score >= 8 { mauvaise += p }
            if score >= 18 { chanceGrossePerte += p }
            if gain(i.effects, argentJoueur: argentJoueur) >= 15 { chanceGrosGain += p }
            for (x, v) in parEnjeu { enjeux[x, default: 0] += p * v + (p >= 0.04 ? v * 0.15 : 0) }
        }
        let danger = attendu + 0.3 * pire
        var niveau: NiveauRisque
        switch danger {
        case ..<5: niveau = .aucun
        case ..<12: niveau = .faible
        case ..<24: niveau = .moyen
        case ..<42: niveau = .eleve
        default: niveau = .extreme
        }
        // Une chance réelle de mourir ou d'aller en prison n'est jamais « faible ».
        if (enjeux[.vie] ?? 0) > 0 { niveau = max(niveau, mauvaise >= 0.2 ? .extreme : .eleve) }
        if (enjeux[.liberte] ?? 0) >= 10 { niveau = max(niveau, .moyen) }
        if let f = force { niveau = f }
        let tries = enjeux.filter { $0.value >= 2 }.sorted { $0.value > $1.value }.map(\.key)
        return RisqueChoix(niveau: niveau, enjeux: niveau == .aucun ? [] : Array(tries.prefix(3)),
                           pari: chanceGrosGain >= 0.15 && chanceGrossePerte >= 0.15,
                           chanceMauvaise: mauvaise)
    }

    /// Ces cartes sont résolues par du code (secrets, successions, soirées électorales…) :
    /// leurs issues JSON ne disent rien du vrai risque, on n'affiche rien.
    static func resoluesAilleurs(_ e: Evenement) -> Bool {
        let id = e.id
        return Secrets.estCarte(id) || id.hasPrefix("suc_") || id.hasPrefix(PolMoteur.prefixeSoiree) || id.hasPrefix("work:")
    }

    /// Risques à afficher sous chaque choix visible d'une carte (index du choix → risque).
    /// « Sans risque » n'est montré que s'il y a un autre choix risqué à côté, pour comparer.
    static func pourCarte(_ e: Evenement, choix: [Choix], argentJoueur: Int) -> [Int: RisqueChoix] {
        guard !resoluesAilleurs(e) else { return [:] }
        var r: [Int: RisqueChoix] = [:]
        for (i, c) in choix.enumerated() {
            if let x = evaluer(c, argentJoueur: argentJoueur) { r[i] = x }
        }
        let auMoinsUnRisque = r.values.contains { $0.niveau > .aucun }
        if !auMoinsUnRisque { return [:] }
        return r
    }
}

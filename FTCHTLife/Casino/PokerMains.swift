import Foundation

// MARK: - Catégories de mains

/// Les catégories de mains au poker, de la plus faible à la plus forte.
enum PokerCategorie: Int, Comparable, CaseIterable {
    case carteHaute = 0, paire, doublePaire, brelan, quinte, couleur, full, carre, quinteFlush, quinteFlushRoyale

    static func < (a: PokerCategorie, b: PokerCategorie) -> Bool { a.rawValue < b.rawValue }

    var nom: String {
        switch self {
        case .carteHaute: return "Carte haute"
        case .paire: return "Paire"
        case .doublePaire: return "Double paire"
        case .brelan: return "Brelan"
        case .quinte: return "Quinte"
        case .couleur: return "Couleur"
        case .full: return "Full"
        case .carre: return "Carré"
        case .quinteFlush: return "Quinte flush"
        case .quinteFlushRoyale: return "Quinte flush royale"
        }
    }
}

// MARK: - Valeur d'une main

/// Valeur comparable d'une main de 5 cartes : catégorie puis départage.
///
/// Tout tient dans un entier : la catégorie dans les bits 20 et plus, puis jusqu'à cinq rangs
/// de départage (4 bits chacun, du plus important au moins important). Deux mains de même score
/// sont exactement à égalité.
struct PokerValeurMain: Comparable, Hashable {
    let score: Int

    init(score: Int) { self.score = score }

    init(categorie: PokerCategorie, departage: [Int]) {
        var s = categorie.rawValue
        for i in 0..<5 {
            s = (s << 4) | (i < departage.count ? (departage[i] & 0xF) : 0)
        }
        score = s
    }

    var categorie: PokerCategorie { PokerCategorie(rawValue: score >> 20) ?? .carteHaute }

    /// Rangs de départage, du plus important au moins important (ex. paire de 8 : [8, As, 10, 4]).
    var departage: [Int] {
        (0..<5).map { (score >> (16 - 4 * $0)) & 0xF }.filter { $0 > 0 }
    }

    static func < (a: PokerValeurMain, b: PokerValeurMain) -> Bool { a.score < b.score }
    static func == (a: PokerValeurMain, b: PokerValeurMain) -> Bool { a.score == b.score }

    /// « Full aux Rois par les 7 », « Paire de Valets »…
    var description: String {
        let d = departage
        let r0 = d.first ?? 0
        let r1 = d.count > 1 ? d[1] : 0
        switch categorie {
        case .carteHaute: return "Carte haute : \(PokerNoms.singulier(r0))"
        case .paire: return "Paire " + PokerNoms.de(r0)
        case .doublePaire: return "Double paire : \(PokerNoms.pluriel(r0)) et \(PokerNoms.pluriel(r1))"
        case .brelan: return "Brelan " + PokerNoms.de(r0)
        case .quinte: return "Quinte " + PokerNoms.au(r0)
        case .couleur: return "Couleur hauteur \(PokerNoms.singulier(r0))"
        case .full: return "Full aux \(PokerNoms.pluriel(r0)) par les \(PokerNoms.pluriel(r1))"
        case .carre: return "Carré " + PokerNoms.de(r0)
        case .quinteFlush: return "Quinte flush " + PokerNoms.au(r0)
        case .quinteFlushRoyale: return "Quinte flush royale"
        }
    }
}

/// Noms des rangs pour les descriptions de mains.
enum PokerNoms {
    static func singulier(_ r: Int) -> String {
        switch r {
        case 11: return "Valet"
        case 12: return "Dame"
        case 13: return "Roi"
        case 14, 1: return "As"
        default: return "\(r)"
        }
    }

    static func pluriel(_ r: Int) -> String {
        switch r {
        case 11: return "Valets"
        case 12: return "Dames"
        case 13: return "Rois"
        case 14, 1: return "As"
        default: return "\(r)"
        }
    }

    /// « d'As », « de Rois », « de 7 ».
    static func de(_ r: Int) -> String {
        r == 14 ? "d'As" : "de \(pluriel(r))"
    }

    /// « à l'As », « au Roi », « au 5 ».
    static func au(_ r: Int) -> String {
        r == 14 ? "à l'As" : "au \(singulier(r))"
    }
}

/// Meilleure main trouvée parmi plusieurs cartes, avec les 5 cartes qui la composent.
struct PokerMeilleureMain {
    let valeur: PokerValeurMain
    let cartes: [CasinoCarte]
}

// MARK: - Évaluateur

enum PokerEvaluateur {

    // MARK: Codage compact

    /// Code entier d'une carte : rang × 4 + couleur (couleur de 0 à 3). Sert aux calculs rapides.
    static func code(_ c: CasinoCarte) -> Int {
        (c.rang << 2) | indiceCouleur(c.couleur)
    }

    static func indiceCouleur(_ c: CasinoCouleurCarte) -> Int {
        switch c {
        case .pique: return 0
        case .coeur: return 1
        case .carreau: return 2
        case .trefle: return 3
        }
    }

    /// Les 52 codes d'un paquet complet.
    static let tousLesCodes: [Int] = {
        var codes: [Int] = []
        for r in 2...14 {
            for s in 0..<4 { codes.append((r << 2) | s) }
        }
        return codes
    }()

    // MARK: API publique

    /// Valeur d'une main de 5 cartes (fonctionne aussi de 5 à 7 cartes : meilleure main possible).
    static func evaluer(_ cartes: [CasinoCarte]) -> PokerValeurMain {
        PokerValeurMain(score: score(cartes.map(code)))
    }

    /// Meilleure main de 5 cartes parmi 5 à 7 (21 combinaisons pour 7 cartes).
    static func meilleureMain(_ cartes: [CasinoCarte]) -> PokerMeilleureMain {
        guard cartes.count > 5 else {
            return PokerMeilleureMain(valeur: evaluer(cartes), cartes: cartes)
        }
        let codes = cartes.map(code)
        var meilleurScore = -1
        var meilleurIndices: [Int] = []
        for combi in combinaisons(cartes.count, 5) {
            let s = score(combi.map { codes[$0] })
            if s > meilleurScore {
                meilleurScore = s
                meilleurIndices = combi
            }
        }
        return PokerMeilleureMain(valeur: PokerValeurMain(score: meilleurScore),
                                  cartes: meilleurIndices.map { cartes[$0] })
    }

    /// Toutes les façons de choisir `k` indices parmi `0..<n`, dans l'ordre.
    static func combinaisons(_ n: Int, _ k: Int) -> [[Int]] {
        if let deja = cacheCombinaisons["\(n)-\(k)"] { return deja }
        var resultat: [[Int]] = []
        var courant: [Int] = []
        func explorer(_ debut: Int) {
            if courant.count == k {
                resultat.append(courant)
                return
            }
            guard debut < n else { return }
            for i in debut..<n {
                courant.append(i)
                explorer(i + 1)
                courant.removeLast()
            }
        }
        explorer(0)
        cacheCombinaisons["\(n)-\(k)"] = resultat
        return resultat
    }

    private static var cacheCombinaisons: [String: [[Int]]] = [:]

    // MARK: Score rapide

    /// Score de la meilleure main de 5 cartes contenue dans `codes` (5 à 7 cartes, codes = rang × 4 + couleur).
    /// Calcul direct (sans énumérer les combinaisons), utilisé par les simulations Monte-Carlo.
    static func score(_ codes: [Int]) -> Int {
        var compte = [Int](repeating: 0, count: 15)
        var masqueParCouleur = [0, 0, 0, 0]
        var nbParCouleur = [0, 0, 0, 0]
        var masque = 0
        for c in codes {
            let r = c >> 2
            let s = c & 3
            compte[r] += 1
            masqueParCouleur[s] |= (1 << r)
            nbParCouleur[s] += 1
            masque |= (1 << r)
        }

        // Couleur (et quinte flush).
        var couleurFlush = -1
        for s in 0..<4 where nbParCouleur[s] >= 5 { couleurFlush = s }
        if couleurFlush >= 0 {
            let h = hauteurQuinte(masqueParCouleur[couleurFlush])
            if h > 0 {
                return PokerValeurMain(categorie: h == 14 ? .quinteFlushRoyale : .quinteFlush, departage: [h]).score
            }
        }

        var carres: [Int] = []
        var brelans: [Int] = []
        var paires: [Int] = []
        for r in stride(from: 14, through: 2, by: -1) {
            switch compte[r] {
            case 4: carres.append(r)
            case 3: brelans.append(r)
            case 2: paires.append(r)
            default: break
            }
        }

        if let q = carres.first {
            let kicker = rangsPresents(compte, sauf: [q], max: 1)
            return PokerValeurMain(categorie: .carre, departage: [q] + kicker).score
        }
        if let b = brelans.first {
            var p = brelans.count > 1 ? brelans[1] : 0
            if let pp = paires.first, pp > p { p = pp }
            if p > 0 {
                return PokerValeurMain(categorie: .full, departage: [b, p]).score
            }
        }
        if couleurFlush >= 0 {
            var hautes: [Int] = []
            let m = masqueParCouleur[couleurFlush]
            for r in stride(from: 14, through: 2, by: -1) where hautes.count < 5 && (m & (1 << r)) != 0 {
                hautes.append(r)
            }
            return PokerValeurMain(categorie: .couleur, departage: hautes).score
        }
        let hq = hauteurQuinte(masque)
        if hq > 0 {
            return PokerValeurMain(categorie: .quinte, departage: [hq]).score
        }
        if let b = brelans.first {
            return PokerValeurMain(categorie: .brelan, departage: [b] + rangsPresents(compte, sauf: [b], max: 2)).score
        }
        if paires.count >= 2 {
            let p1 = paires[0]
            let p2 = paires[1]
            return PokerValeurMain(categorie: .doublePaire, departage: [p1, p2] + rangsPresents(compte, sauf: [p1, p2], max: 1)).score
        }
        if let p = paires.first {
            return PokerValeurMain(categorie: .paire, departage: [p] + rangsPresents(compte, sauf: [p], max: 3)).score
        }
        return PokerValeurMain(categorie: .carteHaute, departage: rangsPresents(compte, sauf: [], max: 5)).score
    }

    /// Hauteur de la meilleure quinte dans un masque de rangs (bit r = rang r présent), 0 si aucune.
    /// L'As compte aussi comme 1 (quinte A-2-3-4-5, hauteur 5).
    static func hauteurQuinte(_ masqueRangs: Int) -> Int {
        var m = masqueRangs
        if (m & (1 << 14)) != 0 { m |= (1 << 1) }
        for h in stride(from: 14, through: 5, by: -1) {
            let bits = 0b11111 << (h - 4)
            if (m & bits) == bits { return h }
        }
        return 0
    }

    /// Les `max` plus hauts rangs présents, en ignorant ceux de `sauf`.
    private static func rangsPresents(_ compte: [Int], sauf: [Int], max: Int) -> [Int] {
        var res: [Int] = []
        for r in stride(from: 14, through: 2, by: -1) where res.count < max && compte[r] > 0 && !sauf.contains(r) {
            res.append(r)
        }
        return res
    }

    // MARK: Force d'une main (pour les robots)

    /// Force pré-flop de deux cartes, de 0 (7-2 dépareillés) à 1 (paire d'As).
    /// Barème simple inspiré des tables classiques : hauteur, paire, couleur, écart.
    static func forcePreflop(_ a: CasinoCarte, _ b: CasinoCarte) -> Double {
        let haut = max(a.rang, b.rang)
        let bas = min(a.rang, b.rang)
        func points(_ r: Int) -> Double {
            switch r {
            case 14: return 10
            case 13: return 8
            case 12: return 7
            case 11: return 6
            default: return Double(r) / 2
            }
        }
        var p = points(haut)
        if haut == bas {
            p = max(5, p * 2)
        } else {
            if a.couleur == b.couleur { p += 2 }
            let ecart = haut - bas - 1
            switch ecart {
            case 0: break
            case 1: p -= 1
            case 2: p -= 2
            case 3: p -= 4
            default: p -= 5
            }
            if ecart <= 1 && haut < 12 { p += 1 }
        }
        return min(1, max(0, (p + 1) / 21))
    }

    /// Probabilité (0…1) de gagner l'abattage contre `adversaires` mains aléatoires, estimée par
    /// Monte-Carlo. Les égalités comptent pour une part. `tableau` : 0 à 5 cartes communes.
    static func equite(main: [CasinoCarte], tableau: [CasinoCarte], adversaires: Int, simulations: Int = 150) -> Double {
        guard adversaires > 0 else { return 1 }
        guard simulations > 0 else { return 0.5 }
        let mesCodes = main.map(code)
        let tableCodes = tableau.map(code)
        let connus = Set(mesCodes + tableCodes)
        var paquet = tousLesCodes.filter { !connus.contains($0) }
        let manque = max(0, 5 - tableCodes.count)
        let besoin = manque + 2 * adversaires
        guard paquet.count >= besoin else { return 0.5 }

        var total = 0.0
        for _ in 0..<simulations {
            // Mélange partiel : seules les `besoin` premières cartes servent.
            for i in 0..<besoin {
                let j = Int.random(in: i..<paquet.count)
                if i != j { paquet.swapAt(i, j) }
            }
            var board = tableCodes
            for i in 0..<manque { board.append(paquet[i]) }
            let monScore = score(mesCodes + board)
            var battu = false
            var egalites = 0
            for a in 0..<adversaires {
                let i0 = manque + 2 * a
                let s = score([paquet[i0], paquet[i0 + 1]] + board)
                if s > monScore { battu = true; break }
                if s == monScore { egalites += 1 }
            }
            if !battu { total += 1.0 / Double(egalites + 1) }
        }
        return total / Double(simulations)
    }
}

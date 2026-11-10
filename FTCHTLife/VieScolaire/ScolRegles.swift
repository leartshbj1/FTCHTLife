import Foundation

/// Où l'état scolaire est rangé dans la sauvegarde.
enum ScolStockage {
    /// Le fil moteur met ici `\Joueur.scolarite` une fois le champ ajouté à `Joueur`.
    /// Tant que c'est nil, l'état est rangé dans UserDefaults (une entrée par vie).
    static var chemin: WritableKeyPath<Joueur, ScolEtat?>?

    static func lire(_ j: Joueur) -> ScolEtat {
        if let c = chemin { return j[keyPath: c] ?? ScolEtat() }
        guard let data = UserDefaults.standard.data(forKey: cle(j)),
              let etat = try? JSONDecoder().decode(ScolEtat.self, from: data) else { return ScolEtat() }
        return etat
    }

    static func ecrire(_ etat: ScolEtat, _ j: inout Joueur) {
        if let c = chemin {
            j[keyPath: c] = etat
            return
        }
        if let data = try? JSONEncoder().encode(etat) {
            UserDefaults.standard.set(data, forKey: cle(j))
        }
    }

    /// La première année du journal a un identifiant unique et stable : il sert d'identifiant de la vie.
    private static func cle(_ j: Joueur) -> String {
        "ftchtlife.scolarite." + (j.journal.first?.id.uuidString ?? j.nomComplet)
    }
}

/// Règles pures du module (pas d'accès au moteur).
enum ScolRegles {
    static let groupesIds = ["sportifs", "intellos", "rebelles", "gamers", "artistes", "stars"]

    /// Vrai si le joueur est au collège ou au lycée (de 11 à 17 ans, avant le bac).
    static func scolarise(_ j: Joueur) -> Bool {
        j.vivant && !j.aQuitteEcole && j.diplome < .bac && (11...17).contains(j.age)
    }

    static func niveau(_ age: Int) -> String { age <= 14 ? "college" : "lycee" }

    static func nomNiveau(_ age: Int) -> String {
        switch age {
        case 11: return "6e"
        case 12: return "5e"
        case 13: return "4e"
        case 14: return "3e"
        case 15: return "2nde"
        case 16: return "1re"
        default: return "Terminale"
        }
    }

    static func classe(_ age: Int, _ etat: ScolEtat) -> String { nomNiveau(age) + " " + etat.lettreClasse }

    /// Langue vivante 2, fixe pour toute la vie.
    static func lv2(_ j: Joueur) -> String { j.prenom.count % 2 == 0 ? "espagnol" : "allemand" }

    /// `etat` : l'état en cours de modification s'il n'est pas encore sauvegardé.
    static func tags(_ j: Joueur, etat: ScolEtat? = nil) -> Set<String> {
        guard scolarise(j) else { return [] }
        let e = etat ?? ScolStockage.lire(j)
        var t: Set<String> = [j.age <= 14 ? "scol_college" : "scol_lycee"]
        switch j.age {
        case 11: t.insert("scol_6e")
        case 12: t.insert("scol_5e")
        case 13: t.insert("scol_4e")
        case 14: t.insert("scol_3e")
        case 15: t.insert("scol_2nde")
        case 16: t.insert("scol_1re")
        default: t.insert("scol_terminale")
        }
        if e.popularite >= 70 { t.insert("scol_populaire") }
        if e.popularite < 30 { t.insert("scol_impopulaire") }
        if e.faveurProfs >= 70 { t.insert("scol_chouchou") }
        if e.faveurProfs < 30 { t.insert("scol_bete_noire") }
        if e.estDelegue { t.insert("scol_delegue") }
        if e.collesAnnee > 0 { t.insert("scol_colle") }
        if let g = e.groupe { t.insert("scol_groupe_" + g) } else { t.insert("scol_sans_groupe") }
        return t
    }

    static func conditionsOK(_ c: ScolConditions?, _ j: Joueur, tags t: Set<String>) -> Bool {
        guard let c = c else { return true }
        if c.gender == "male" && j.genre != .homme { return false }
        if c.gender == "female" && j.genre != .femme { return false }
        if let r = c.tags, !Set(r).isSubset(of: t) { return false }
        if let x = c.excludeTags, !Set(x).isDisjoint(with: t) { return false }
        return true
    }

    static func ageOK(_ s: ScolScene, _ age: Int) -> Bool {
        age >= (s.minAge ?? 0) && age <= (s.maxAge ?? 200)
    }

    /// Valeur d'une stat nommée comme dans les données (`health`, `smarts`, `popularity`…).
    static func stat(_ nom: String, _ j: Joueur, _ e: ScolEtat) -> Int {
        switch nom {
        case "health": return j.stats.sante
        case "happiness": return j.stats.bonheur
        case "smarts": return j.stats.intelligence
        case "looks": return j.stats.apparence
        case "karma": return j.stats.karma
        case "popularity": return e.popularite
        default: return 0
        }
    }

    static func nomStat(_ nom: String) -> String {
        switch nom {
        case "health": return "santé"
        case "happiness": return "bonheur"
        case "smarts": return "intelligence"
        case "looks": return "apparence"
        case "karma": return "karma"
        case "popularity": return "popularité"
        default: return nom
        }
    }

    static func tranche(_ note: Double) -> String {
        switch note {
        case 16...: return "excellent"
        case 13..<16: return "bien"
        case 10..<13: return "moyen"
        case 7..<10: return "faible"
        default: return "nul"
        }
    }

    static func arrondi(_ note: Double) -> Double {
        (min(20, max(0, note)) * 2).rounded() / 2
    }

    static func formatNote(_ note: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: note)) ?? "\(note)"
    }

    static func borne(_ v: Int) -> Int { min(100, max(0, v)) }

    /// Un élément au hasard selon son poids.
    static func tirage<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0.0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.randomElement() }
        var r = Double.random(in: 0..<total)
        for x in liste {
            r -= max(0, poids(x))
            if r < 0 { return x }
        }
        return liste.last
    }

    static func tirage(_ issues: [ScolIssue]) -> ScolIssue? {
        tirage(issues) { $0.chance ?? 1 }
    }
}

/// Noms tirés une fois pour une scène, pour que le texte et le résultat parlent du même prof.
struct ScolContexte: Equatable {
    var matiere: String
    var prof: String
    var camarade: String

    static func nouveau(_ j: Joueur) -> ScolContexte {
        let matiere = ScolDonnees.matieres(age: min(17, max(11, j.age)), lv2: ScolRegles.lv2(j)).randomElement() ?? "maths"
        let g = Genre.allCases.randomElement()!
        return ScolContexte(matiere: matiere, prof: ScolDonnees.prof(matiere), camarade: Donnees.prenom(g))
    }
}

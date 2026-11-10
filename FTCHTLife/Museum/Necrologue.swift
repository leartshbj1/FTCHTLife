import Foundation

/// Fabrique la nécrologie d'une vie terminée à partir de l'état final du joueur.
enum Necrologue {
    static let sectionsMilieu = ["enfance", "etudes", "carriere", "argent", "amour", "famille", "caractere"]
    static let maxSectionsMilieu = 4

    /// Identifiant stable d'une vie : l'id de sa première année de journal (créée à la naissance).
    static func identifiant(_ j: Joueur) -> String {
        if let premiere = j.journal.first { return premiere.id.uuidString }
        return "\(j.nomComplet)-\(j.ville)-\(j.age)"
    }

    // MARK: - Génération

    static func generer(joueur j: Joueur, dernierMetier: String? = nil, scoreVieReussie: Int? = nil,
                        surnoms: [NecroSurnom] = NecroDonnees.surnoms,
                        phrases: [NecroPhrase] = NecroDonnees.phrases) -> MuseeVie {
        let metier = dernierMetier ?? j.emploi?.titre
        let t = tags(j, dernierMetier: metier, scoreVieReussie: scoreVieReussie)
        let femme = j.genre == .femme

        // Un enfant mort jeune n'hérite pas d'un surnom d'adulte : on garde les surnoms de son âge s'il y en a.
        let jeunesse: Set<String> = ["bebe", "enfant", "ado"]
        var pool = surnoms
        if !t.isDisjoint(with: jeunesse) {
            let pourJeunes = surnoms.filter {
                !Set($0.conditions?.tags ?? []).isDisjoint(with: jeunesse) || ($0.conditions?.maxAge ?? 200) < 18
            }
            if pourJeunes.contains(where: { accepte($0.conditions, age: j.age, tags: t) }) { pool = pourJeunes }
        }
        let surnomBrut = choisir(pool, age: j.age, tags: t, conditions: { $0.conditions }, poids: { $0.weight })
            .map { femme ? ($0.textFemale ?? $0.text) : $0.text }
        let surnom = surnomBrut.map { remplacerAccord($0, femme: femme) } ?? "la Légende du quartier"

        let vars = variables(j, surnom: surnom, metier: metier)

        func phrase(_ section: String) -> String? {
            let candidats = phrases.filter { $0.section == section }
            guard let p = choisir(candidats, age: j.age, tags: t, conditions: { $0.conditions }, poids: { $0.weight }) else { return nil }
            return remplir(femme ? (p.textFemale ?? p.text) : p.text, vars)
        }

        let titre = phrase("titre") ?? "\(j.ville) perd \(surnom)"
        var paragraphes: [String] = []
        if let intro = phrase("intro") {
            paragraphes.append(intro)
        } else {
            paragraphes.append("\(j.nomComplet), dit\(femme ? "e" : "") « \(surnom) », s'est éteint\(femme ? "e" : "") à \(j.age) ans.")
        }

        // Sections du milieu : on garde l'ordre, au plus 4, en privilégiant celles qui ont une phrase précise.
        var milieu: [(index: Int, texte: String, precise: Bool)] = []
        for (i, s) in sectionsMilieu.enumerated() {
            let candidats = phrases.filter { $0.section == s }
            guard let p = choisir(candidats, age: j.age, tags: t, conditions: { $0.conditions }, poids: { $0.weight }) else { continue }
            let precise = !(p.conditions?.tags ?? []).isEmpty
            milieu.append((i, remplir(femme ? (p.textFemale ?? p.text) : p.text, vars), precise))
        }
        if milieu.count > maxSectionsMilieu {
            let precises = milieu.filter { $0.precise }.shuffled()
            let autres = milieu.filter { !$0.precise }.shuffled()
            milieu = Array((precises + autres).prefix(maxSectionsMilieu)).sorted { $0.index < $1.index }
        }
        paragraphes += milieu.map { $0.texte }

        let cause = j.causeDeces ?? "mystérieusement"
        paragraphes.append(phrase("fin") ?? "\(j.prenom) est mort\(femme ? "e" : "") \(cause).")
        let epitaphe = phrase("epitaphe") ?? "Ici repose \(j.prenom). Enfin tranquille."

        return MuseeVie(
            id: identifiant(j),
            dateFin: Date(),
            prenom: j.prenom,
            nom: j.nom,
            genre: j.genre,
            surnom: surnom,
            ville: j.ville,
            age: j.age,
            cause: cause,
            dernierMetier: metier,
            fortune: j.argent,
            diplome: j.diplome.nom,
            stats: j.stats,
            nbAmis: j.relations.filter { $0.type == .ami }.count,
            nbEnfants: j.relations.filter { $0.type == .enfant }.count,
            nbEx: j.relations.filter { $0.type == .ex }.count,
            scoreVieReussie: scoreVieReussie,
            titre: titre,
            paragraphes: paragraphes,
            epitaphe: epitaphe,
            faitsMarquants: faitsMarquants(j)
        )
    }

    // MARK: - Tags

    static func tags(_ j: Joueur, dernierMetier: String?, scoreVieReussie: Int?) -> Set<String> {
        var t: Set<String> = [j.genre == .femme ? "female" : "male"]

        switch j.age {
        case ..<3: t.insert("bebe")
        case 3...12: t.insert("enfant")
        case 13...17: t.insert("ado")
        case 18...39: t.insert("jeune")
        case 40...64: t.insert("adulte")
        case 65...89: t.insert("vieux")
        default: t.insert("tres_vieux")
        }
        if j.age >= 100 { t.insert("centenaire") }

        if j.argent < 0 { t.insert("endette") }
        if j.argent < 1000 { t.insert("fauche") }
        if j.argent >= 100_000 { t.insert("aise") }
        if j.argent >= 1_000_000 { t.insert("riche") }
        if j.argent >= 1_000_000_000 { t.insert("milliardaire") }

        if j.age >= 18 && j.diplome < .bac { t.insert("sans_diplome") }
        if j.diplome == .bac { t.insert("bachelier") }
        if j.diplome >= .licence { t.insert("diplome_sup") }
        if j.diplome == .doctorat { t.insert("doctorat") }
        if let f = j.filiereDiplome, j.diplome >= .licence { t.insert("filiere_\(f.rawValue)") }

        if dernierMetier != nil { t.insert("travailleur") }
        if j.etudes != nil { t.insert("etudiant") }
        if dernierMetier == nil && j.etudes == nil {
            if j.age >= 65 { t.insert("retraite") }
            else if j.age >= 18 { t.insert("chomeur") }
        }

        let s = j.stats
        if s.intelligence >= 75 { t.insert("intelligent") }
        if s.intelligence <= 25 { t.insert("bete") }
        if s.apparence >= 75 { t.insert("beau") }
        if s.apparence <= 25 { t.insert("moche") }
        if s.karma >= 75 { t.insert("gentil") }
        if s.karma <= 25 { t.insert("mechant") }
        if s.bonheur >= 75 { t.insert("heureux") }
        if s.bonheur <= 25 { t.insert("deprime") }
        if s.sante < 30 { t.insert("malade") }

        let amis = j.relations.filter { $0.type == .ami }.count
        if amis >= 5 { t.insert("populaire") }
        if amis == 0 && j.age >= 13 { t.insert("solitaire") }
        let partenaire = j.relations.contains { $0.type == .partenaire && $0.vivant }
        if partenaire { t.insert("en_couple") } else if j.age >= 18 { t.insert("celibataire") }
        if j.relations.filter({ $0.type == .ex }).count >= 3 { t.insert("ex_nombreux") }

        let enfants = j.relations.filter { $0.type == .enfant }.count
        if enfants >= 1 { t.insert("parent") }
        if enfants >= 4 { t.insert("famille_nombreuse") }
        if j.relations.contains(where: { $0.type == .frere || $0.type == .soeur }) {
            t.insert("fratrie")
        } else {
            t.insert("enfant_unique")
        }
        let parents = j.relations.filter { $0.type.estParent }
        if !parents.isEmpty && parents.allSatisfy({ !$0.vivant }) { t.insert("orphelin") }

        t.insert(typeMort(j.causeDeces))

        if let score = scoreVieReussie {
            if score >= 75 { t.insert("vie_reussie") }
            if score <= 25 { t.insert("vie_ratee") }
        }
        return t
    }

    static func typeMort(_ cause: String?) -> String {
        let c = (cause ?? "").lowercased()
        if c.contains("vieillesse") || c.contains("sommeil") || c.contains("crise cardiaque") || c.contains("avc") {
            return "mort_naturelle"
        }
        if c.contains("maladie") || c.contains("cancer") || c.contains("blessures") || c.contains("grippe") {
            return "mort_maladie"
        }
        return "mort_absurde"
    }

    // MARK: - Tirage

    static func accepte(_ c: NecroConditions?, age: Int, tags t: Set<String>) -> Bool {
        guard let c = c else { return true }
        if let m = c.minAge, age < m { return false }
        if let m = c.maxAge, age > m { return false }
        if let r = c.tags, !Set(r).isSubset(of: t) { return false }
        if let x = c.excludeTags, !Set(x).isDisjoint(with: t) { return false }
        return true
    }

    /// Tirage pondéré ; une entrée qui demande des tags précis pèse plus lourd.
    static func choisir<T>(_ liste: [T], age: Int, tags t: Set<String>,
                           conditions: (T) -> NecroConditions?, poids: (T) -> Double?) -> T? {
        let ok = liste.filter { accepte(conditions($0), age: age, tags: t) }
        let poidsFinal: [Double] = ok.map { e in
            let base = max(0.01, poids(e) ?? 1)
            let precision = Double(conditions(e)?.tags?.count ?? 0)
            return base * (1 + precision * 1.5)
        }
        let total = poidsFinal.reduce(0, +)
        guard total > 0 else { return ok.first }
        var r = Double.random(in: 0..<total)
        for (e, w) in zip(ok, poidsFinal) {
            r -= w
            if r < 0 { return e }
        }
        return ok.last
    }

    // MARK: - Textes

    static func variables(_ j: Joueur, surnom: String, metier: String?) -> [String: String] {
        let femme = j.genre == .femme
        let partenaire = j.relations.first { $0.type == .partenaire && $0.vivant }
        return [
            "prenom": j.prenom,
            "nom": j.nom,
            "surnom": surnom,
            "ville": j.ville,
            "age": "\(j.age)",
            "cause": j.causeDeces ?? "mystérieusement",
            "metier": (metier ?? "touche-à-tout").lowercased(),
            "fortune": Format.argent(j.argent),
            "diplome": j.diplome.nom.lowercased(),
            "filiere": j.filiereDiplome?.nom.lowercased() ?? "sciences du canapé",
            "nbAmis": "\(j.relations.filter { $0.type == .ami }.count)",
            "nbEnfants": "\(j.relations.filter { $0.type == .enfant }.count)",
            "nbEx": "\(j.relations.filter { $0.type == .ex }.count)",
            "partenaire": partenaire?.prenom ?? "personne",
            "mere": j.mere?.prenom ?? "sa mère",
            "pere": j.pere?.prenom ?? "son père",
            "e": femme ? "e" : "",
            "il": femme ? "elle" : "il",
            "Il": femme ? "Elle" : "Il",
            "le": femme ? "la" : "le",
        ]
    }

    static func remplir(_ texte: String, _ vars: [String: String]) -> String {
        var t = texte
        for (cle, valeur) in vars {
            t = t.replacingOccurrences(of: "{\(cle)}", with: valeur)
        }
        return majusculeInitiale(t)
    }

    static func remplacerAccord(_ texte: String, femme: Bool) -> String {
        texte.replacingOccurrences(of: "{e}", with: femme ? "e" : "")
    }

    /// Une phrase qui commence par {surnom} (« le Roi… ») doit débuter par une majuscule.
    static func majusculeInitiale(_ t: String) -> String {
        guard let premier = t.first, premier.isLowercase else { return t }
        return premier.uppercased() + t.dropFirst()
    }

    /// Lignes marquantes du journal (diplômes, promotions, deuils…), au plus 8.
    static func faitsMarquants(_ j: Joueur) -> [String] {
        let marqueurs = ["🎓", "📈", "📉", "💀", "💍", "👶", "🏆", "🚔", "💰", "❤️", "💔"]
        var faits: [String] = []
        for annee in j.journal {
            for ligne in annee.lignes where marqueurs.contains(where: { ligne.hasPrefix($0) }) {
                faits.append("\(annee.age) ans : \(ligne)")
            }
        }
        if faits.count > 8 {
            // On garde le début et la fin de la vie.
            faits = Array(faits.prefix(4)) + Array(faits.suffix(4))
        }
        return faits
    }
}

import Foundation

// Carte de vie à partager (idée 26) : tout ce qu'on affiche sur la carte, calculé à partir d'un Joueur mort.
// Module autonome : ne lit que le modèle du moteur, ne modifie rien. Voir docs/CARTE_VIE.md.

/// Un moment marquant de la vie, tiré du journal.
struct CarteVieMoment: Codable, Equatable {
    var age: Int
    var texte: String
    /// Positif = bon moment, négatif = mauvais moment.
    var score: Int
}

/// Un chiffre clé affiché dans la grille de la carte.
struct CarteVieChiffre: Identifiable, Equatable {
    var id: String { titre }
    var titre: String
    var valeur: String
    var icone: String
}

/// Résumé complet d'une vie, prêt à dessiner.
struct CarteVieResume: Equatable {
    var nomComplet: String
    var prenom: String
    var surnom: String
    var age: Int
    var ville: String
    var genre: Genre
    var phraseDeces: String
    var chiffres: [CarteVieChiffre]
    var meilleur: CarteVieMoment?
    var pire: CarteVieMoment?
    /// Note sur 20, pour le plaisir de comparer avec les copains.
    var note: Int
    var verdict: String
    // Pour le portrait dessiné par défaut.
    var bonheur: Int
    var karma: Int
    var argent: Int
    var apparence: Int

    /// - Parameters:
    ///   - surnom: le surnom de la nécrologie (`MuseeStore.shared.enregistrer(joueur:).surnom`). Sans surnom, la carte en invente un.
    ///   - dernierMetier: le dernier métier exercé (le moteur vide `emploi` à la mort). Sans lui, la carte le cherche dans le journal.
    ///   - meilleur, pire: moments déjà connus (sinon la carte les cherche dans le journal).
    init(joueur j: Joueur, surnom: String? = nil, dernierMetier: String? = nil,
         meilleur: CarteVieMoment? = nil, pire: CarteVieMoment? = nil) {
        nomComplet = j.nomComplet
        prenom = j.prenom
        age = j.age
        ville = j.ville
        genre = j.genre
        bonheur = j.stats.bonheur
        karma = j.stats.karma
        argent = j.argent
        apparence = j.stats.apparence

        let s = (surnom?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? CarteVieResume.surnomDeSecours(j)
        self.surnom = s.prefix(1).uppercased() + s.dropFirst()

        let cause = j.causeDeces ?? "mystérieusement"
        phraseDeces = j.g("Mort", "Morte") + " \(cause), à \(j.age) an\(j.age > 1 ? "s" : "")."

        let moments = CarteVieResume.moments(j)
        self.meilleur = meilleur ?? moments.meilleur
        self.pire = pire ?? moments.pire

        let metier = dernierMetier ?? j.emploi?.titre ?? CarteVieResume.dernierMetierDuJournal(j)
        let amis = j.relations.filter { $0.type == .ami }.count
        let enfants = j.relations.filter { $0.type == .enfant }.count
        let amours = j.relations.filter { $0.type == .partenaire || $0.type == .ex }.count
        chiffres = [
            CarteVieChiffre(titre: "Fortune", valeur: CarteVieResume.argentCourt(j.argent), icone: "banknote.fill"),
            CarteVieChiffre(titre: "Métier", valeur: metier ?? (j.age < 18 ? "Trop jeune" : "Aucun, fièrement"), icone: "briefcase.fill"),
            CarteVieChiffre(titre: "Diplôme", valeur: j.diplome.nom, icone: "graduationcap.fill"),
            CarteVieChiffre(titre: "Amis", valeur: "\(amis)", icone: "person.2.fill"),
            CarteVieChiffre(titre: enfants > 0 ? "Enfants" : "Amours", valeur: "\(enfants > 0 ? enfants : amours)",
                            icone: enfants > 0 ? "figure.and.child.holdinghands" : "heart.fill"),
            CarteVieChiffre(titre: "Karma", valeur: "\(j.stats.karma)%", icone: "sparkles"),
        ]

        note = CarteVieResume.note(j, amis: amis, enfants: enfants)
        verdict = CarteVieResume.verdict(note: note)
    }

    // MARK: - Moments marquants

    /// Mots (en minuscules) qui rendent une ligne du journal plutôt heureuse ou plutôt triste, avec leur poids.
    static let motsPositifs: [(String, Int)] = [
        ("🎓", 6), ("📈", 6), ("🎉", 5), ("💍", 7), ("❤️", 5), ("🏆", 7), ("💰", 5), ("👶", 6),
        ("promotion", 6), ("diplômé", 6), ("embauché", 5), ("tu as eu ton bac", 6), ("tu hérites", 4),
        ("gagné", 5), ("gagnes", 5), ("jackpot", 8), ("loto", 4), ("mariage", 6), ("marié", 6),
        ("amoureux", 5), ("amoureuse", 5), ("bisou", 3), ("naissance", 5), ("tu es devenu parent", 6),
        ("célèbre", 5), ("record", 4), ("fier", 3), ("fière", 3), ("rire", 2), ("bonheur", 3),
        ("nouvel ami", 3), ("nouvelle amie", 3), ("cadeau", 2), ("vacances", 3), ("évadé", 4), ("évadée", 4),
        ("libéré", 4), ("libérée", 4), ("guéri", 5), ("guérie", 5), ("millionnaire", 7), ("milliardaire", 8),
    ]
    static let motsNegatifs: [(String, Int)] = [
        ("💀", 8), ("📉", 6), ("💔", 6), ("🚑", 5), ("🚓", 5), ("⛓", 6), ("😭", 4),
        ("viré", 6), ("virée", 6), ("raté", 4), ("ratée", 4), ("prison", 7), ("arrêté", 5), ("arrêtée", 5),
        ("condamné", 6), ("condamnée", 6), ("divorce", 6), ("largué", 5), ("larguée", 5), ("quitté", 4),
        ("trompé", 5), ("trompée", 5), ("accident", 5), ("hôpital", 4), ("cassé", 3), ("blessé", 4),
        ("cancer", 7), ("maladie", 4), ("malade", 3), ("ruiné", 7), ("ruinée", 7), ("dettes", 5),
        ("faillite", 7), ("volé", 4), ("humilié", 4), ("humiliée", 4), ("honte", 3), ("vomi", 3),
        ("perdu", 3), ("pleuré", 3), ("pleures", 3), ("mordu", 2), ("refusé", 2), ("entretien raté", 2),
        ("est mort", 7), ("est morte", 7), ("enterrement", 5), ("cambriolé", 5), ("arnaqué", 5), ("arnaquée", 5),
    ]

    /// Score d'une ligne du journal : > 0 si plutôt heureuse, < 0 si plutôt triste.
    static func score(_ ligne: String) -> Int {
        let t = ligne.lowercased()
        var s = 0
        for (mot, poids) in motsPositifs where t.contains(mot) { s += poids }
        for (mot, poids) in motsNegatifs where t.contains(mot) { s -= poids }
        // Les gains et pertes d'argent écrits en toutes lettres.
        if t.contains("tu gagnes") || t.contains("tu touches") { s += 2 }
        if t.contains("tu perds") || t.contains("tu dois") { s -= 2 }
        return s
    }

    /// Cherche le meilleur et le pire moment dans le journal (la mort elle-même ne compte pas, elle est déjà sur la carte).
    static func moments(_ j: Joueur) -> (meilleur: CarteVieMoment?, pire: CarteVieMoment?) {
        var meilleur: CarteVieMoment?
        var pire: CarteVieMoment?
        for annee in j.journal where annee.age > 0 {
            for ligne in annee.lignes {
                if ligne.hasPrefix("⚰️") { continue }
                if ligne.contains("Va voir l'onglet") { continue }
                let s = score(ligne)
                // À score égal, on garde le plus récent (on s'en souvient mieux).
                if s > 0 && s >= (meilleur?.score ?? 0) {
                    meilleur = CarteVieMoment(age: annee.age, texte: ligne, score: s)
                }
                if s < 0 && s <= (pire?.score ?? 0) {
                    pire = CarteVieMoment(age: annee.age, texte: ligne, score: s)
                }
            }
        }
        return (meilleur, pire)
    }

    // MARK: - Métier

    /// Retrouve le dernier poste dans le journal (« embauché comme … ! », « Promotion ! Tu es maintenant … à »).
    static func dernierMetierDuJournal(_ j: Joueur) -> String? {
        for annee in j.journal.reversed() {
            for ligne in annee.lignes.reversed() {
                if let r = ligne.range(of: "Tu es maintenant "), let fin = ligne.range(of: " à ", range: r.upperBound..<ligne.endIndex) {
                    return majuscule(String(ligne[r.upperBound..<fin.lowerBound]))
                }
                if let r = ligne.range(of: " comme "), ligne.contains("embauch"),
                   let fin = ligne.range(of: " !", range: r.upperBound..<ligne.endIndex) {
                    return majuscule(String(ligne[r.upperBound..<fin.lowerBound]))
                }
            }
        }
        return nil
    }

    static func majuscule(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    // MARK: - Note et verdict

    static func note(_ j: Joueur, amis: Int, enfants: Int) -> Int {
        var n = 0.0
        n += Double(j.stats.bonheur) / 100 * 5
        n += Double(j.stats.karma) / 100 * 3
        n += Double(j.stats.intelligence) / 100 * 2
        n += min(4, Double(j.age) / 20)
        n += min(2, Double(amis) * 0.5 + Double(enfants) * 0.5)
        n += Double(j.diplome.rawValue) * 0.4
        if j.argent >= 1_000_000 { n += 2 } else if j.argent >= 100_000 { n += 1 } else if j.argent < 0 { n -= 1.5 }
        return max(0, min(20, Int(n.rounded())))
    }

    static func verdict(note: Int) -> String {
        switch note {
        case ..<4: return "Une vie. Techniquement."
        case ..<8: return "Peut mieux faire. Beaucoup mieux."
        case ..<11: return "Ni fait, ni à faire."
        case ..<14: return "Une vie honnête, avec des miettes de gloire."
        case ..<17: return "Belle vie. Les voisins sont jaloux."
        default: return "Légendaire. On en parlera aux repas de famille."
        }
    }

    // MARK: - Surnom de secours (si la nécrologie n'en fournit pas)

    static func surnomDeSecours(_ j: Joueur) -> String {
        let f = j.genre == .femme
        if j.age < 5 { return f ? "la Comète" : "le Météore" }
        if j.argent >= 1_000_000 { return f ? "la Reine du pognon" : "le Roi du pognon" }
        if j.argent < 0 { return f ? "la Dame aux dettes" : "l'Homme aux dettes" }
        if j.stats.karma >= 85 { return f ? "la Sainte du quartier" : "le Saint du quartier" }
        if j.stats.karma <= 15 { return "la Terreur du quartier" }
        if j.stats.intelligence >= 85 { return f ? "la Tête bien pleine" : "le Cerveau sur pattes" }
        if j.stats.apparence >= 85 { return f ? "la Beauté fatale" : "le Beau gosse éternel" }
        if j.age >= 95 { return "l'Increvable" }
        if j.stats.bonheur <= 20 { return f ? "la Ronchonne" : "le Ronchon" }
        if j.emploi == nil && j.age >= 30 && j.age < 65 { return f ? "la Reine du canapé" : "le Roi du canapé" }
        return f ? "la Discrète" : "le Discret"
    }

    // MARK: - Format

    /// « 1,2 M€ », « 45 k€ », « -3 k€ »… pour tenir dans une petite case.
    static func argentCourt(_ montant: Int) -> String {
        let v = Double(montant)
        let a = abs(v)
        func f(_ x: Double, _ suffixe: String) -> String {
            let s = x < 10 ? String(format: "%.1f", x) : String(format: "%.0f", x)
            return (v < 0 ? "-" : "") + s.replacingOccurrences(of: ".", with: ",").replacingOccurrences(of: ",0", with: "") + suffixe
        }
        if a >= 1_000_000_000 { return f(a / 1_000_000_000, " Md€") }
        if a >= 1_000_000 { return f(a / 1_000_000, " M€") }
        if a >= 10_000 { return f(a / 1_000, " k€") }
        return "\(montant) €"
    }
}

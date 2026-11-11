import Foundation

/// Données du module Secte, lues une fois.
enum SecteCatalogue {
    static let doctrines: [SecteDoctrine] = DonneesJSON.chargerTableaux(dossier: "Secte", type: SecteDoctrine.self)
    static let evenements: [SecteEvenement] = DonneesJSON.chargerTableaux(dossier: "SecteEvents", type: SecteEvenement.self)

    static func doctrine(_ id: String) -> SecteDoctrine? { doctrines.first { $0.id == id } }
    static func evenement(_ id: String) -> SecteEvenement? { evenements.first { $0.id == id } }
}

/// Règles chiffrées et fonctions pures du module Secte.
enum SecteMoteur {
    static let ageMin = 18
    /// Préfixe des cartes de la secte dans la file d'événements du moteur.
    static let prefixe = "secte:"
    /// Seuil d'adeptes à partir duquel le mouvement prend tout le temps du fondateur.
    static let seuilPleinTemps = 300
    static let nomsContribution = ["Libre", "Modérée", "Dîme (10 %)", "Tout donner"]
    static let multiplicateurDons = [0.25, 1.0, 2.2, 4.0]
    static let coutsDefense = [40_000, 90_000, 200_000]

    // MARK: - Lecture

    static func actuelle(_ j: Joueur) -> SecteEtat? { j.sectes?.actuelle }

    /// La secte prend-elle tout le temps du fondateur (plus de métier à côté) ?
    static func pleinTemps(_ s: SecteEtat) -> Bool {
        s.lieu == .domaine || s.adeptes >= seuilPleinTemps
    }

    static func titre(_ s: SecteEtat, _ j: Joueur) -> String {
        guard let d = SecteCatalogue.doctrine(s.doctrineId), d.titreGourou.count == 2 else { return j.g("Gourou", "Gourou") }
        return j.genre == .femme ? d.titreGourou[1] : d.titreGourou[0]
    }

    /// Stade du mouvement, pour l'affichage.
    static func stade(_ s: SecteEtat) -> String {
        switch s.adeptes {
        case ..<20: return "Petit cercle"
        case ..<100: return "Groupe"
        case ..<1_000: return "Mouvement"
        case ..<10_000: return "Église"
        default: return "Empire spirituel"
        }
    }

    static let nomsEnquete = ["Aucune", "Articles et plaintes", "Enquête préliminaire", "Perquisition et mise en examen", "Procès"]

    /// Charisme du fondateur (0,4 à 1,8) : apparence, intelligence, éloquence, séduction.
    static func charisme(_ j: Joueur) -> Double {
        let elo = Double(Competences.niveau("eloquence", j))
        let sed = Double(Competences.niveau("seduction", j))
        let mag = Double(Competences.niveau("magie", j))
        let c = 0.4 + Double(j.stats.apparence) / 250 + Double(j.stats.intelligence) / 400 + elo * 0.09 + sed * 0.04 + mag * 0.03
        return min(1.8, max(0.4, c))
    }

    static func blocageFondation(_ j: Joueur) -> String? {
        if !j.vivant { return "Tu es mort\(j.genre == .femme ? "e" : ""). Même les prophètes ont leurs limites." }
        if j.age < ageMin { return "Il faut avoir \(ageMin) ans pour fonder un mouvement." }
        if j.vieEtat.justice.enPrison { return "Tu es en prison. Tu peux méditer, pas recruter." }
        if j.sectes?.actuelle != nil { return "Tu as déjà un mouvement. Un seul culte à la fois." }
        return nil
    }

    // MARK: - Tags

    static func tags(_ etat: SectesEtat?) -> Set<String> {
        guard let etat = etat else { return [] }
        var t: Set<String> = []
        if let s = etat.actuelle {
            t.insert("gourou")
            if s.lieu == .domaine { t.insert("secte_communaute") }
            if s.adeptes >= 1_000 { t.insert("secte_grande") }
            if s.enquete >= 1 { t.insert("secte_enquete") }
            if !s.prochesIds.isEmpty { t.insert("proche_dans_secte") }
        }
        if !etat.anciennes.isEmpty { t.insert("ancien_gourou") }
        return t
    }

    // MARK: - Textes

    /// Remplace les variables du module : {secte}, {doctrine}, {adeptes}, {nb}, {gourou}, {proche}.
    static func remplir(_ texte: String, _ s: SecteEtat, _ j: Joueur, proche: Relation? = nil) -> String {
        guard texte.contains("{") else { return texte }
        let d = SecteCatalogue.doctrine(s.doctrineId)
        var t = texte
        t = t.replacingOccurrences(of: "{secte}", with: s.nom)
        t = t.replacingOccurrences(of: "{doctrine}", with: d?.nom.lowercased() ?? "ta doctrine")
        t = t.replacingOccurrences(of: "{adeptes}", with: d?.adeptesNom ?? "adeptes")
        t = t.replacingOccurrences(of: "{nb}", with: "\(s.adeptes)")
        t = t.replacingOccurrences(of: "{gourou}", with: titre(s, j))
        let p = proche ?? procheMembre(s, j)
        t = t.replacingOccurrences(of: "{proche}", with: p?.prenom ?? "un proche")
        return t
    }

    /// Un proche du joueur qui est dans la secte (le même toute l'année).
    static func procheMembre(_ s: SecteEtat, _ j: Joueur) -> Relation? {
        let membres = j.relations.filter { $0.vivant && s.prochesIds.contains($0.id) }
        return choixStable(membres, j.age)
    }

    // MARK: - Événements

    static func eligible(_ ev: SecteEvenement, _ s: SecteEtat, _ j: Joueur) -> Bool {
        if ev.unique == true && s.evenementsVus.contains(ev.id) { return false }
        if let ds = ev.doctrines, !ds.isEmpty, !ds.contains(s.doctrineId) { return false }
        guard let c = ev.conditions else { return ev.kind != "enquete" }
        if let m = c.minAdeptes, s.adeptes < m { return false }
        if let m = c.maxAdeptes, s.adeptes > m { return false }
        if let m = c.minFerveur, s.ferveur < m { return false }
        if let m = c.maxFerveur, s.ferveur > m { return false }
        if let m = c.minDerive, s.derive < m { return false }
        if let m = c.maxDerive, s.derive > m { return false }
        if let m = c.minSurveillance, s.surveillance < m { return false }
        if let m = c.minNotoriete, s.notoriete < m { return false }
        if let m = c.minTresor, s.tresor < m { return false }
        if let l = c.lieux, !l.isEmpty, !l.contains(s.lieu.rawValue) { return false }
        if let e = c.enquete, e != s.enquete { return false }
        if ev.kind == "enquete" && c.enquete == nil { return false }
        if c.procheMembre == true && procheMembre(s, j) == nil { return false }
        if c.procheMembre == false && procheMembre(s, j) != nil { return false }
        if let m = c.minAnnees, s.annees < m { return false }
        return true
    }

    /// La carte de l'année : celle du stade de l'enquête s'il vient de changer (ou du procès), sinon une au hasard.
    static func carteDeLAnnee(_ s: SecteEtat, _ j: Joueur) -> SecteEvenement? {
        if s.enquete > 0 && (s.enquete != s.stadeAnnonce || s.enquete == 4) {
            let cartes = SecteCatalogue.evenements.filter { $0.kind == "enquete" && eligible($0, s, j) }
            if let c = GameEngine.tirage(cartes, poids: { $0.weight ?? 1 }) { return c }
        }
        guard Double.random(in: 0...1) < 0.7 else { return nil }
        let cartes = SecteCatalogue.evenements.filter { $0.kind != "enquete" && eligible($0, s, j) }
        return GameEngine.tirage(cartes) { ev in
            let base = ev.weight ?? 1
            switch ev.kind {
            case "derive": return base * (0.6 + Double(s.derive) / 40)
            case "exterieur": return base * (0.6 + Double(s.surveillance + s.notoriete) / 60)
            default: return base
            }
        }
    }

    /// Transforme une carte en événement du moteur (variables du module déjà remplies, chances ajustées).
    static func versEvenement(_ ev: SecteEvenement, _ s: SecteEtat, _ j: Joueur) -> Evenement {
        let proche = procheMembre(s, j)
        let choix: [Choix] = ev.choices.map { c in
            var label = remplir(c.label, s, j, proche: proche)
            if let cout = c.cost, cout > 0 { label += " (\(Format.argent(cout)))" }
            let issues: [Issue] = c.outcomes.map { o in
                var chance = o.chance ?? 1
                if let mois = o.secte?.prisonMois, mois > 0 {
                    // Plus il y a eu d'abus, plus la peine est probable ; les avocats aident.
                    chance *= (0.5 + Double(s.derive) / 100) * (1 - 0.2 * Double(s.defense))
                }
                return Issue(chance: max(0.01, chance), text: remplir(o.text, s, j, proche: proche), effects: o.effects)
            }
            return Choix(label: label, outcomes: issues, requiresSkill: c.requiresSkill)
        }
        return Evenement(id: prefixe + ev.id, category: "secte", minAge: 0, maxAge: 200, weight: 1, unique: nil,
                         conditions: nil, text: remplir(ev.text, s, j, proche: proche), effects: nil, choices: choix)
    }

    // MARK: - Effets

    /// Applique les effets d'une issue au mouvement. Renvoie les signaux à envoyer.
    static func appliquer(_ fx: SecteEffets, _ s: inout SecteEtat) -> [String] {
        var signaux: [String] = []
        s.adeptes += fx.adeptes ?? 0
        if let p = fx.adeptesPct { s.adeptes += s.adeptes * p / 100 }
        s.ferveur += fx.ferveur ?? 0
        s.derive += fx.derive ?? 0
        s.surveillance += fx.surveillance ?? 0
        s.notoriete += fx.notoriete ?? 0
        s.tresor += fx.tresor ?? 0
        if let p = fx.tresorPct { s.tresor += s.tresor * p / 100 }
        if let d = fx.defense { s.defense = min(3, max(0, s.defense + d)) }
        if let e = fx.enquete {
            let avant = s.enquete
            s.enquete = min(4, max(0, s.enquete + e))
            if s.enquete == 0 && avant > 0 { s.stadeAnnonce = 0; s.surveillance -= 10 }
            if s.enquete > avant { signaux.append(signalStade(s.enquete)) }
        }
        if let sig = fx.signal { signaux.append(sig) }
        borner(&s)
        return signaux
    }

    static func signalStade(_ stade: Int) -> String {
        switch stade {
        case 1: return "secte_enquete"
        case 3: return "secte_perquisition"
        case 4: return "secte_proces"
        default: return "secte_enquete"
        }
    }

    static func borner(_ s: inout SecteEtat) {
        s.adeptes = max(0, s.adeptes)
        s.ferveur = Stats.borne(s.ferveur)
        s.derive = Stats.borne(s.derive)
        s.surveillance = Stats.borne(s.surveillance)
        s.notoriete = Stats.borne(s.notoriete)
    }

    // MARK: - Passage d'année

    struct Annee {
        var lignes: [String] = []
        var signaux: [String] = []
        /// Argent que le joueur a dû sortir de sa poche (négatif) pour renflouer la caisse.
        var argentJoueur = 0
    }

    /// Une année du mouvement : recrues, départs, dons, charges, dérive, attention des autorités.
    static func passerAnnee(_ s: inout SecteEtat, _ j: Joueur) -> Annee {
        var a = Annee()
        guard let d = SecteCatalogue.doctrine(s.doctrineId) else { return a }
        s.annees += 1
        s.actionsAnnee = []
        let enPrison = j.vieEtat.justice.enPrison
        let ch = charisme(j)
        let c = min(3, max(0, s.contribution))

        // Recrues et départs
        var attrait = d.attrait * (0.5 + Double(s.notoriete) / 100) * ch
        if s.reglesStrictes { attrait *= 0.8 }
        if s.enquete >= 1 { attrait *= max(0.3, 1 - 0.15 * Double(s.enquete)) }
        if enPrison { attrait *= 0.3 }
        var nouveaux = Int((Double(s.adeptes) * 0.12 + Double.random(in: 0...3)) * attrait)
        nouveaux = max(0, min(nouveaux, s.lieu.capacite - s.adeptes))
        var taux = Double(max(0, 65 - s.ferveur)) / 180 + [0.0, 0.01, 0.04, 0.09][c] + 0.04 * Double(s.enquete)
        if s.reglesStrictes { taux *= 0.6 }
        if enPrison { taux += 0.12 }
        let departs = min(s.adeptes, Int(Double(s.adeptes) * taux + Double.random(in: 0..<1)))
        s.adeptes += nouveaux - departs

        // Argent
        let dons = Int(Double(s.adeptes) * Double(d.donMoyen) * multiplicateurDons[c]
                       * (0.4 + Double(s.ferveur) / 100) * Double.random(in: 0.85...1.15))
        let travail = s.lieu == .domaine ? s.adeptes * 1_500 : 0
        let charges = s.lieu.charges + s.adeptes * (s.lieu == .domaine ? 1_200 : 40)
        s.tresor += dons + travail - charges
        if s.tresor < 0 {
            a.argentJoueur = s.tresor
            a.lignes.append("💸 La caisse de \(s.nom) est vide : tu sors \(Format.argent(-s.tresor)) de ta poche pour payer les charges.")
            s.tresor = 0
        }

        // Ferveur, dérive, surveillance
        s.ferveur += (s.lieu == .domaine ? 3 : 0) + (s.reglesStrictes ? 4 : 0) + (enPrison ? 4 : 0) - 3 - (c == 3 ? 2 : 0) + Int.random(in: -3...3)
        s.derive += d.risque + [-3, -1, 3, 7][c] + (s.reglesStrictes ? 6 : -1) + (s.lieu == .domaine ? 3 : 0) + (s.adeptes >= 1_000 ? 2 : 0)
        s.surveillance += s.derive / 10 + s.notoriete / 25 + (s.adeptes >= 1_000 ? 3 : 0) + (s.adeptes >= 10_000 ? 4 : 0) - 4
        s.notoriete += s.adeptes >= 1_000 ? 1 : (s.notoriete > 10 ? -1 : 0)
        borner(&s)

        // Enquête judiciaire
        let avant = s.enquete
        if s.enquete == 0 {
            if s.surveillance >= 35 && Double.random(in: 0...1) < Double(s.surveillance - 25) / 100 { s.enquete = 1 }
        } else if s.enquete < 4 {
            let p = Double(s.surveillance - 30 + s.derive / 2) / 100 - 0.05 * Double(s.defense)
            if Double.random(in: 0...1) < p {
                s.enquete += 1
            } else if s.surveillance < 20 && s.enquete <= 2 && Double.random(in: 0...1) < 0.5 {
                s.enquete = 0
                s.stadeAnnonce = 0
                a.lignes.append("⚖️ L'enquête sur \(s.nom) est classée sans suite. Pour l'instant.")
            }
        }
        if s.enquete > avant { a.signaux.append(signalStade(s.enquete)) }

        s.bilan = SecteBilan(age: j.age, nouveaux: nouveaux, departs: departs, dons: dons + travail, charges: charges)
        var ligne = "🕯️ \(s.nom) : \(s.adeptes) \(d.adeptesNom)"
        if nouveaux > 0 || departs > 0 { ligne += " (+\(nouveaux), −\(departs))" }
        ligne += ". Dons de l'année : \(Format.argent(dons + travail)). Caisse : \(Format.argent(s.tresor))."
        a.lignes.insert(ligne, at: 0)
        if enPrison { a.lignes.append("Depuis ta cellule, tu fais passer des messages. Tes lieutenants tiennent le mouvement… à leur façon.") }
        if s.enquete > avant {
            switch s.enquete {
            case 1: a.lignes.append("📰 Des familles d'adeptes alertent la presse sur \(s.nom).")
            case 2: a.lignes.append("🚔 Le parquet ouvre une enquête préliminaire sur \(s.nom).")
            case 3: a.lignes.append("🚨 Les enquêteurs préparent une perquisition. Ton avocat ne dort plus.")
            default: a.lignes.append("⚖️ Tu es renvoyé\(j.genre == .femme ? "e" : "") devant le tribunal.")
            }
        }
        return a
    }
}

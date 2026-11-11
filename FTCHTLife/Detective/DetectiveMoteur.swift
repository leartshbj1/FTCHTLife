import Foundation

/// Données du module Agence de détective, lues une fois.
enum AgenceCatalogue {
    static let types: [AgenceTypeAffaire] = DonneesJSON.chargerTableaux(dossier: "Detective", type: AgenceTypeAffaire.self)
    static let evenements: [AgenceEvenement] = DonneesJSON.chargerTableaux(dossier: "DetectiveEvents", type: AgenceEvenement.self)

    static func type(_ id: String) -> AgenceTypeAffaire? { types.first { $0.id == id } }
    static func evenement(_ id: String) -> AgenceEvenement? { evenements.first { $0.id == id } }
}

/// Règles chiffrées et fonctions pures de l'agence de détective.
enum AgenceMoteur {
    static let ageMinAgrement = 21
    static let ageMinClandestin = 18
    static let coutFormation = 7_500
    static let fraisAgrement = 1_500
    static let coutClandestin = 1_000
    /// Part des honoraires versée à l'acceptation.
    static let acompte = 0.3
    static let prefixe = "agence:"
    static let prefixeDenouement = "agence:den:"

    static let nomsEquipement = ["Ton téléphone", "Téléobjectif", "Balises et micros", "Labo et drones"]
    static let coutsEquipement = [0, 3_000, 15_000, 60_000]
    static let entretienEquipement = [0, 600, 2_500, 8_000]
    static let nomsBureau = ["Ta cuisine", "Petit bureau", "Bureaux en centre-ville", "Agence de prestige"]
    static let coutsBureau = [0, 5_000, 25_000, 120_000]
    static let loyersBureau = [0, 9_000, 28_000, 85_000]

    static func actuelle(_ j: Joueur) -> AgenceEtat? { j.agences?.actuelle }

    static func titre(_ j: Joueur) -> String { j.g("Détective privé", "Détective privée") }

    /// Nombre d'affaires qu'on peut mener en même temps.
    static func capacite(_ a: AgenceEtat) -> Int { 2 + a.enqueteurs.count * 2 + (a.bureau >= 2 ? 1 : 0) }

    static func maxEnqueteurs(_ a: AgenceEtat) -> Int { [1, 2, 5, 10][min(3, max(0, a.bureau))] }

    // MARK: - Ouverture

    /// Raison qui empêche d'ouvrir l'agence, ou nil.
    static func blocageOuverture(_ j: Joueur, agrement: Bool) -> String? {
        if !j.vivant { return "Tu es mort\(j.genre == .femme ? "e" : ""). L'enquête est close." }
        if j.vieEtat.justice.enPrison { return "Tu es en prison. Tu enquêteras sur la cantine." }
        if j.agences?.actuelle != nil { return "Tu as déjà une agence." }
        if j.etudes != nil { return "Termine tes études d'abord." }
        if agrement {
            if j.age < ageMinAgrement { return "La carte professionnelle s'obtient à partir de \(ageMinAgrement) ans." }
            if j.diplome < .bac { return "Il faut au moins le bac pour suivre la formation d'agent de recherches privées." }
            if CasierSysteme.tags(j.casier).contains("casier_lourd") || j.vieEtat.justice.casier.contains(where: { $0.mois >= 60 }) {
                return "Ton casier judiciaire t'interdit la carte professionnelle. Reste la voie clandestine…"
            }
        } else if j.age < ageMinClandestin {
            return "Dès \(ageMinClandestin) ans."
        }
        let cout = coutOuverture(j, agrement: agrement)
        if !Shkurtaaa.peutPayer(cout, solde: j.argent) { return "Il te faut \(Format.argent(cout))." }
        return nil
    }

    static func coutOuverture(_ j: Joueur, agrement: Bool) -> Int {
        guard agrement else { return coutClandestin }
        return fraisAgrement + (j.filiereDiplome == .droit ? 0 : coutFormation)
    }

    // MARK: - Tags

    static func tags(_ etat: AgencesEtat?) -> Set<String> {
        guard let etat = etat else { return [] }
        var t: Set<String> = []
        if let a = etat.actuelle {
            t.insert("detective")
            if a.reputation >= 70 || a.celebres.count >= 2 { t.insert("detective_celebre") }
            if !a.agrement { t.insert("detective_clandestin") }
        }
        if !etat.anciennes.isEmpty { t.insert("ancien_detective") }
        return t
    }

    // MARK: - Offres et équipe

    /// Les affaires proposées cette année.
    static func offres(_ a: AgenceEtat) -> [AgenceAffaire] {
        if a.suspendue { return [] }
        let nombre = min(6, 2 + a.reputation / 25 + a.bureau)
        let accessibles = AgenceCatalogue.types.filter { $0.reputationMin <= a.reputation + 5 * a.bureau }
        guard !accessibles.isEmpty else { return [] }
        var liste: [AgenceAffaire] = []
        for _ in 0..<nombre {
            guard let t = accessibles.randomElement() else { break }
            liste.append(nouvelleAffaire(t, a))
        }
        return liste
    }

    static func nouvelleAffaire(_ t: AgenceTypeAffaire, _ a: AgenceEtat) -> AgenceAffaire {
        let hMin = t.honoraires.first ?? 1_000, hMax = max(hMin, t.honoraires.last ?? hMin)
        let dMin = t.difficulte.first ?? 30, dMax = max(dMin, t.difficulte.last ?? dMin)
        let facteur = 1 + Double(a.reputation) / 60 + Double(a.bureau) * 0.25
        let honoraires = Int(Double(Int.random(in: hMin...hMax)) * facteur) / 100 * 100
        return AgenceAffaire(typeId: t.id, client: t.clients.randomElement() ?? "Un client", cible: t.cibles.randomElement() ?? "la cible",
                             honoraires: max(100, honoraires), difficulte: Int.random(in: dMin...dMax), dureeMax: max(1, t.duree))
    }

    static func candidats(_ a: AgenceEtat) -> [AgenceEnqueteur] {
        (0..<3).map { _ in
            let g = Genre.allCases.randomElement()!
            let competence = Int.random(in: 15...90)
            return AgenceEnqueteur(prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement()!, genre: g, relationId: nil,
                                   competence: competence, salaire: 22_000 + competence * 380 + Int.random(in: 0...4_000),
                                   specialite: AgenceMethode.allCases.filter { $0 != .limite }.randomElement()!)
        }
    }

    static func depuisProche(_ r: Relation) -> AgenceEnqueteur {
        AgenceEnqueteur(prenom: r.prenom, nom: r.nom, genre: r.genre, relationId: r.id, competence: Int.random(in: 10...60),
                        salaire: 20_000 + Int.random(in: 0...6_000),
                        specialite: AgenceMethode.allCases.filter { $0 != .limite }.randomElement()!)
    }

    // MARK: - Textes

    /// Remplace {agence}, {client}, {cible}, {affaire}, {enqueteur}.
    static func remplir(_ texte: String, _ a: AgenceEtat, affaire: AgenceAffaire? = nil, client: String? = nil, cible: String? = nil,
                        typeId: String? = nil, enqueteur: AgenceEnqueteur? = nil) -> String {
        guard texte.contains("{") else { return texte }
        var t = texte
        t = t.replacingOccurrences(of: "{agence}", with: a.nom)
        let cl = client ?? affaire?.client ?? "ton client"
        let ci = cible ?? affaire?.cible ?? "la personne visée"
        let ty = (typeId ?? affaire?.typeId).flatMap { AgenceCatalogue.type($0)?.nom.lowercased() } ?? "l'affaire"
        // {client} et {cible} sont d'abord remplis, puis leurs propres variables ({ville}…) par le moteur.
        t = t.replacingOccurrences(of: "{client}", with: cl)
        t = t.replacingOccurrences(of: "{cible}", with: ci)
        t = t.replacingOccurrences(of: "{affaire}", with: ty)
        t = t.replacingOccurrences(of: "{enqueteur}", with: enqueteur?.prenom ?? "ton enquêteur")
        return t
    }

    // MARK: - Événements

    static func eligible(_ ev: AgenceEvenement, _ a: AgenceEtat, affaire: AgenceAffaire?, _ j: Joueur) -> Bool {
        if ev.unique == true && a.evenementsVus.contains(ev.id) { return false }
        guard let c = ev.conditions else { return true }
        if let m = c.minReputation, a.reputation < m { return false }
        if let m = c.maxReputation, a.reputation > m { return false }
        if let m = c.minEnqueteurs, a.enqueteurs.count < m { return false }
        if c.affaireEnCours == true && affaire == nil { return false }
        if let ts = c.typesAffaire, !ts.isEmpty {
            guard let af = affaire, ts.contains(af.typeId) else { return false }
        }
        if let s = c.sansAgrement, s == a.agrement { return false }
        if let m = c.minEquipement, a.equipement < m { return false }
        if let m = c.minBureau, a.bureau < m { return false }
        if let m = c.minResolues, a.resolues < m { return false }
        if let m = c.minAnnees, a.annees < m { return false }
        return true
    }

    static func versEvenement(id: String, texte: String, choix liste: [AgenceChoix], remplir: (String) -> String) -> Evenement {
        let choix: [Choix] = liste.map { c in
            var label = remplir(c.label)
            if let cout = c.cost, cout > 0 { label += " (\(Format.argent(cout)))" }
            let issues = c.outcomes.map { Issue(chance: $0.chance ?? 1, text: remplir($0.text), effects: $0.effects) }
            return Choix(label: label, outcomes: issues, requiresSkill: c.requiresSkill)
        }
        return Evenement(id: id, category: "agence", minAge: 0, maxAge: 200, weight: 1, unique: nil, conditions: nil,
                         text: remplir(texte), effects: nil, choices: choix)
    }

    // MARK: - Enquête

    /// Efficacité (0,4 à 2) de la personne qui mène l'affaire avec cette méthode.
    static func efficacite(_ methode: AgenceMethode, enqueteur: AgenceEnqueteur?, _ a: AgenceEtat, _ j: Joueur) -> Double {
        if let e = enqueteur {
            return 0.55 + Double(e.competence) / 100 + (e.specialite == methode ? 0.25 : 0) + Double(min(e.annees, 10)) * 0.02
        }
        let niveau = Double(Competences.niveau(methode.competence, j))
        let v = 0.75 + niveau * 0.12 + Double(j.stats.intelligence) / 300 + Double(min(a.annees, 10)) * 0.03
        return min(2, max(0.4, v))
    }

    /// Points d'enquête attendus en un an (pour l'affichage).
    static func pointsAttendus(_ af: AgenceAffaire, _ a: AgenceEtat, _ j: Joueur) -> Int {
        let m = af.methode ?? .terrain
        let enq = af.enqueteurId.flatMap { id in a.enqueteurs.first { $0.id == id } }
        let bonus = AgenceCatalogue.type(af.typeId)?.methodes?[m.rawValue] ?? 1
        return Int(m.base * efficacite(m, enqueteur: enq, a, j) * bonus * (1 + Double(a.equipement) * 0.15))
    }
}

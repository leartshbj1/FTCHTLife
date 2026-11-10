import Foundation

// MARK: - Données chargées depuis Data/Voisinage

enum VoisinageDonnees {
    static let archetypes: [VoisinArchetype] = DonneesJSON.chargerTableaux(dossier: "Voisinage/Archetypes", type: VoisinArchetype.self)
    static let evenements: [VoisinageEvenement] = DonneesJSON.chargerTableaux(dossier: "Voisinage/Evenements", type: VoisinageEvenement.self)
    static let interactions: [VoisinageInteraction] = DonneesJSON.chargerTableaux(dossier: "Voisinage/Interactions", type: VoisinageInteraction.self)

    private static let archetypesParId: [String: VoisinArchetype] =
        Dictionary(archetypes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    private static let evenementsParId: [String: VoisinageEvenement] =
        Dictionary(evenements.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func archetype(_ id: String) -> VoisinArchetype? { archetypesParId[id] }
    static func evenement(_ id: String) -> VoisinageEvenement? { evenementsParId[id] }

    // Noms de quartiers, rues et syndics.

    static let quartiers: [VoisinageLogement: [String]] = [
        .appartement: ["Résidence Les Mimosas", "Résidence du Parc (sans parc)", "Les Terrasses du Soleil", "Tour Horizon",
                       "Résidence Bellevue (vue sur le parking)", "Le Carré des Lilas", "Résidence Le Panoramique", "Les Jardins Suspendus"],
        .maison: ["Lotissement Le Clos Fleuri", "Impasse des Glycines", "Lotissement Les Hauts du Bois", "Hameau des Tilleuls",
                  "Le Domaine des Pins (trois pins)", "Lotissement Les Coquelicots", "Quartier des Cerisiers"],
        .villa: ["Les Hauts de la Colline", "Domaine des Cèdres", "Avenue des Ambassadeurs", "Résidence privée Le Golf",
                 "Les Villas du Lac", "Quartier des Millionnaires Discrets"],
        .campagne: ["Lieu-dit La Grange Brûlée", "Hameau du Bout du Monde", "Le Plateau des Vaches", "La Combe aux Loups",
                    "Hameau des Trois Fermes", "Lieu-dit Pas de Réseau"],
        .caravane: ["Camping Les Flots Bleus", "Camping La Sardine Heureuse", "Aire des Mobil-Homes Joyeux", "Port de plaisance du Canal",
                    "Camping Le Bout du Lac", "Camping Les Palmiers (en plastique)"],
    ]

    static let rues = ["rue des Glycines", "allée des Platanes", "avenue de la République", "rue du Moulin", "chemin des Écoliers",
                       "rue Victor-Hugo", "impasse du Paradis", "rue de la Paix (ironie)", "boulevard des Rêves", "rue des Lilas",
                       "chemin de la Fontaine", "allée des Peupliers", "rue du Four", "place de l'Église"]

    static let syndics = ["Syndic Lenteur & Fils", "Copro-Zen Gestion", "Cabinet Injoignable SA", "Gestimmo Plus (ou moins)",
                          "Syndic du Bon Vouloir", "Agence Répondeur Immobilier", "Foncia-Peut-Être", "Gérance Plus Tard"]

    static let emplacements: [VoisinageLogement: [String]] = [
        .appartement: ["sur ton palier", "juste au-dessus", "juste en dessous", "au rez-de-chaussée", "au dernier étage",
                       "au 2e", "au 4e", "en face de l'ascenseur", "au fond du couloir"],
        .maison: ["dans la maison d'en face", "juste à côté", "de l'autre côté de la haie", "au bout de l'impasse",
                  "dans la maison aux volets bleus", "derrière ton jardin"],
        .villa: ["dans la villa d'à côté", "derrière le grand portail", "dans la villa avec la statue", "en haut de la colline"],
        .campagne: ["à la ferme d'à côté, à 800 m", "de l'autre côté du champ", "au vieux moulin", "en bas du chemin"],
        .caravane: ["dans le mobil-home d'à côté", "à l'emplacement 14", "près des sanitaires", "dans le camping-car garé en face",
                    "sur la péniche voisine"],
    ]
}

// MARK: - Stockage
//
// Le fil moteur ajoute `var voisinage: VoisinageEtat?` à `Joueur`, puis remplace les deux lignes marquées ⚙️
// par `j.voisinage` / `j.voisinage = etat`. En attendant, l'état est gardé en mémoire (perdu à la fermeture).

enum VoisinageStockage {
    private static var memoire: [UUID: VoisinageEtat] = [:]

    private static func cle(_ j: Joueur) -> UUID? { j.journal.first?.id }

    static func lire(_ j: Joueur) -> VoisinageEtat? {
        guard let k = cle(j) else { return nil }
        return memoire[k]   // ⚙️ return j.voisinage
    }

    static func ecrire(_ j: inout Joueur, _ etat: VoisinageEtat?) {
        guard let k = cle(j) else { return }
        memoire[k] = etat   // ⚙️ j.voisinage = etat
    }

    /// Signaux envoyés au module Répercussions. Le fil moteur peut brancher :
    /// `VoisinageStockage.signaler = { s, j in var e = j.repercussions ?? RepercussionsEtat(); Repercussions.signaler(s, age: j.age, etat: &e); j.repercussions = e }`
    static var signaler: (String, inout Joueur) -> Void = { _, _ in }
}

// MARK: - Moteur du voisinage (logique pure, sans GameEngine)

@MainActor
enum VoisinageMoteur {

    /// Chance qu'un événement de quartier arrive dans l'année.
    static let chanceEvenement = 0.45
    /// Chance qu'une phrase d'ambiance d'un voisin tombe dans le journal.
    static let chancePhrase = 0.55

    // MARK: Création

    /// Quartier des parents, à la naissance.
    static func quartierDesParents(_ j: Joueur) -> VoisinageEtat {
        let argentParents = j.relations.filter { $0.type.estParent }.reduce(0) { $0 + $1.argent }
        let logement: VoisinageLogement
        switch argentParents {
        case 140_000...: logement = Double.random(in: 0...1) < 0.4 ? .villa : .maison
        case 50_000...: logement = Double.random(in: 0...1) < 0.6 ? .maison : .appartement
        default: logement = Double.random(in: 0...1) < 0.12 ? .caravane : .appartement
        }
        var etat = nouveauQuartier(logement: logement, chezParents: true, proprietaire: false, ageJoueur: j.age)
        etat.proprietaire = logement != .appartement || Double.random(in: 0...1) < 0.4
        return etat
    }

    static func nouveauQuartier(logement: VoisinageLogement, chezParents: Bool, proprietaire: Bool, ageJoueur: Int) -> VoisinageEtat {
        let quartier = VoisinageDonnees.quartiers[logement]?.randomElement() ?? "Quartier sans nom"
        let adresse = "\(Int.random(in: 1...148)), \(VoisinageDonnees.rues.randomElement()!)"
        var etat = VoisinageEtat(logement: logement, chezParents: chezParents, proprietaire: proprietaire,
                                 quartier: quartier, adresse: adresse, ambiance: Int.random(in: 35...70), voisins: [])
        if logement == .appartement {
            etat.copro = VoisinageCopro(nomSyndic: VoisinageDonnees.syndics.randomElement()!,
                                        chargesAnnuelles: Int.random(in: 12...40) * 100)
        }
        let n = Int.random(in: logement.nombreVoisins)
        for _ in 0..<n {
            if let v = genererVoisin(etat: etat, ageJoueur: ageJoueur) { etat.voisins.append(v) }
        }
        return etat
    }

    /// Tire un nouveau voisin adapté au logement, en évitant les doublons d'archétype et d'emplacement.
    static func genererVoisin(etat: VoisinageEtat, ageJoueur: Int) -> Voisin? {
        let dejaLa = Set(etat.voisinsPresents.map { $0.archetype })
        var possibles = VoisinageDonnees.archetypes.filter { $0.logements.contains(etat.logement) && !dejaLa.contains($0.id) }
        if possibles.isEmpty { possibles = VoisinageDonnees.archetypes.filter { $0.logements.contains(etat.logement) } }
        guard let a = GameEngine.tirage(possibles, poids: { $0.weight ?? 1 }) else { return nil }

        let genre: Genre
        switch a.gender {
        case "male": genre = .homme
        case "female": genre = .femme
        default: genre = Genre.allCases.randomElement()!
        }
        var age = Int.random(in: a.ageMin...max(a.ageMin, a.ageMax))
        // L'amour de palier a un âge proche du joueur quand c'est possible.
        if a.id == "voisine_de_palier_charmante", ageJoueur >= 18 {
            age = min(a.ageMax, max(a.ageMin, ageJoueur + Int.random(in: -6...6)))
        }
        let pris = Set(etat.voisinsPresents.map { $0.emplacement })
        let lieux = VoisinageDonnees.emplacements[etat.logement] ?? ["à côté"]
        let lieu = lieux.filter { !pris.contains($0) }.randomElement() ?? lieux.randomElement()!
        return Voisin(archetype: a.id, prenom: Donnees.prenom(genre), nom: Donnees.noms.randomElement()!, genre: genre,
                      age: age, lien: Int.random(in: 35...60) + (a.gentillesse - 50) / 5,
                      celibataire: Double.random(in: 0...1) < (a.celibat ?? 0.5), emplacement: lieu)
    }

    // MARK: Textes

    static func titre(_ v: Voisin) -> String {
        guard let a = VoisinageDonnees.archetype(v.archetype) else { return v.genre == .femme ? "la voisine" : "le voisin" }
        return v.genre == .femme ? a.titreF : a.titreM
    }

    /// Remplace les variables du voisinage. Les variables du moteur ({prenom}, {e}…) sont remplacées ensuite par `GameEngine.remplir`.
    static func remplir(_ texte: String, voisin v: Voisin?, etat: VoisinageEtat) -> String {
        var t = texte
        if let v = v {
            let f = v.genre == .femme
            t = t.replacingOccurrences(of: "{voisin_nom}", with: v.civilite)
            t = t.replacingOccurrences(of: "{voisin_complet}", with: v.nomComplet)
            t = t.replacingOccurrences(of: "{voisin_qui}", with: titre(v))
            t = t.replacingOccurrences(of: "{voisin_age}", with: "\(v.age)")
            t = t.replacingOccurrences(of: "{voisin}", with: v.prenom)
            t = t.replacingOccurrences(of: "{emplacement}", with: v.emplacement)
            t = t.replacingOccurrences(of: "{Il}", with: f ? "Elle" : "Il")
            t = t.replacingOccurrences(of: "{il}", with: f ? "elle" : "il")
            t = t.replacingOccurrences(of: "{lui}", with: f ? "elle" : "lui")
            t = t.replacingOccurrences(of: "{ve}", with: f ? "e" : "")
        }
        t = t.replacingOccurrences(of: "{quartier}", with: etat.quartier)
        t = t.replacingOccurrences(of: "{adresse}", with: etat.adresse)
        t = t.replacingOccurrences(of: "{syndic}", with: etat.copro?.nomSyndic ?? "le syndic")
        return t
    }

    // MARK: Tags

    static func tags(_ etat: VoisinageEtat) -> Set<String> {
        var t: Set<String> = []
        switch etat.logement {
        case .appartement: t.insert("vit_en_appartement")
        case .maison: t.insert("vit_en_maison")
        case .villa: t.insert("vit_en_villa")
        case .campagne: t.insert("vit_a_la_campagne")
        case .caravane: t.insert("vit_en_caravane")
        }
        if etat.chezParents { t.insert("chez_parents") }
        if etat.proprietaire && !etat.chezParents { t.insert("proprietaire") }
        let presents = etat.voisinsPresents
        if presents.contains(where: { $0.statut == .ennemi }) { t.insert("voisin_ennemi") }
        if presents.contains(where: { $0.statut == .ami }) { t.insert("voisin_ami") }
        if presents.contains(where: { $0.statut == .amour }) { t.insert("amour_de_palier") }
        if etat.copro?.president == true { t.insert("president_copro") }
        if etat.ambiance >= 70 { t.insert("quartier_sympa") }
        if etat.ambiance < 30 { t.insert("quartier_tendu") }
        return t
    }

    // MARK: Conditions

    /// Mêmes règles que `GameEngine.conditionsRemplies`, sans l'âge ni `unique`.
    static func conditionsMoteur(_ c: ConditionsEvenement?, _ j: Joueur, tags t: Set<String>) -> Bool {
        guard let c = c else { return true }
        if c.gender == "male" && j.genre != .homme { return false }
        if c.gender == "female" && j.genre != .femme { return false }
        if let m = c.minMoney, j.argent < m { return false }
        if let m = c.maxMoney, j.argent > m { return false }
        if let r = c.requiresJob, r != t.contains("job") { return false }
        if let r = c.requiresPartner, r != t.contains("partner") { return false }
        if let r = c.requiresSchool, r != (t.contains("school") || t.contains("university")) { return false }
        if let r = c.tags, !Set(r).isSubset(of: t) { return false }
        if let x = c.excludeTags, !Set(x).isDisjoint(with: t) { return false }
        return true
    }

    static func conditionsQuartier(_ q: VoisinageConditions?, _ etat: VoisinageEtat) -> Bool {
        guard let q = q else { return true }
        if let l = q.logements, !l.contains(etat.logement) { return false }
        if let c = q.chezParents, c != etat.chezParents { return false }
        if let p = q.proprietaire, p != (etat.proprietaire && !etat.chezParents) { return false }
        if let p = q.president, p != (etat.copro?.president ?? false) { return false }
        if let m = q.minAmbiance, etat.ambiance < m { return false }
        if let m = q.maxAmbiance, etat.ambiance > m { return false }
        if let d = q.drapeaux, !d.allSatisfy({ etat.a($0) }) { return false }
        if let d = q.sansDrapeaux, d.contains(where: { etat.a($0) }) { return false }
        if let mc = q.minCompteurs, mc.contains(where: { (etat.compteurs[$0.key] ?? 0) < $0.value }) { return false }
        if let m = q.minAnnees, etat.anneesIci < m { return false }
        return true
    }

    static func correspond(_ v: Voisin, _ c: VoisinageCible?, joueur j: Joueur) -> Bool {
        guard v.vivant else { return false }
        guard let c = c else { return true }
        if let a = c.archetypes, !a.contains(v.archetype) { return false }
        if let s = c.statuts, !s.contains(v.statut) { return false }
        if let m = c.minLien, v.lien < m { return false }
        if let m = c.maxLien, v.lien > m { return false }
        if c.celibataire == true {
            guard v.celibataire, v.age >= 18, j.age >= 18, abs(v.age - j.age) <= 12 else { return false }
        }
        if c.gender == "male" && v.genre != .homme { return false }
        if c.gender == "female" && v.genre != .femme { return false }
        if c.opposite == true && v.genre == j.genre { return false }
        if let m = c.minAge, v.age < m { return false }
        if let m = c.maxAge, v.age > m { return false }
        if let s = c.souvenirs, !s.allSatisfy({ v.souvenirs.contains($0) }) { return false }
        if let s = c.sansSouvenirs, s.contains(where: { v.souvenirs.contains($0) }) { return false }
        return true
    }

    // MARK: Événements

    /// Événements possibles cette année, avec les voisins qui peuvent être ciblés.
    static func candidats(_ j: Joueur, _ etat: VoisinageEtat, tags: Set<String>) -> [(VoisinageEvenement, [Voisin])] {
        VoisinageDonnees.evenements.compactMap { e -> (VoisinageEvenement, [Voisin])? in
            guard j.age >= e.minAge, j.age <= e.maxAge else { return nil }
            if e.unique == true && etat.vus.contains(e.id) { return nil }
            guard conditionsQuartier(e.quartier, etat), conditionsMoteur(e.conditions, j, tags: tags) else { return nil }
            if e.cible == nil { return (e, []) }
            let possibles = etat.voisinsPresents.filter { correspond($0, e.cible, joueur: j) }
            return possibles.isEmpty ? nil : (e, possibles)
        }
    }

    /// Transforme un événement de quartier en événement du moteur (variables du voisin déjà remplacées).
    static func versEvenement(_ e: VoisinageEvenement, voisin: Voisin?, etat: VoisinageEtat) -> Evenement {
        let choix = e.choices?.map { c in
            Choix(label: remplir(c.label, voisin: voisin, etat: etat),
                  outcomes: c.outcomes.map { Issue(chance: $0.chance, text: remplir($0.text, voisin: voisin, etat: etat), effects: $0.effects) })
        }
        return Evenement(id: e.id, category: "voisinage", minAge: e.minAge, maxAge: e.maxAge, weight: e.weight,
                         unique: e.unique, conditions: nil, text: remplir(e.text, voisin: voisin, etat: etat),
                         effects: e.effects, choices: choix)
    }

    // MARK: Effets sur le voisin et le quartier

    /// Applique un effet de voisinage. Renvoie les lignes de journal à ajouter et les signaux pour les Répercussions.
    /// Les effets « moteur » (stats, argent…) sont appliqués à part par `GameEngine.appliquer`.
    @discardableResult
    static func appliquer(_ eff: VoisinageEffet?, voisinId: UUID?, _ j: inout Joueur, _ etat: inout VoisinageEtat) -> (lignes: [String], signaux: [String]) {
        guard let eff = eff else { return ([], []) }
        var lignes: [String] = []
        var signaux = eff.signaux ?? []

        if let d = eff.lienTous {
            for i in etat.voisins.indices where etat.voisins[i].vivant {
                etat.voisins[i].lien = Stats.borne(etat.voisins[i].lien + d)
            }
        }
        if let a = eff.ambiance { etat.ambiance = Stats.borne(etat.ambiance + a) }
        for d in eff.drapeaux ?? [] where !etat.drapeaux.contains(d) { etat.drapeaux.append(d) }
        if let r = eff.retireDrapeaux { etat.drapeaux.removeAll { r.contains($0) } }
        for (k, n) in eff.compteurs ?? [:] { etat.compteurs[k, default: 0] += n }
        if var copro = etat.copro {
            if let p = eff.president {
                if p && !copro.president { signaux.append("president_copro") }
                copro.president = p
            }
            if let c = eff.charges { copro.chargesAnnuelles = max(0, copro.chargesAnnuelles + c) }
            if let t = eff.travaux, !copro.travauxVotes.contains(t) { copro.travauxVotes.append(t) }
            etat.copro = copro
        }

        guard let id = voisinId, let i = etat.voisins.firstIndex(where: { $0.id == id }) else { return (lignes, signaux) }
        var v = etat.voisins[i]
        if let d = eff.lien { v.lien = Stats.borne(v.lien + d) }
        for s in eff.souvenir ?? [] where !v.souvenirs.contains(s) { v.souvenirs.append(s) }
        if let o = eff.oublie { v.souvenirs.removeAll { o.contains($0) } }
        if let s = eff.statut, s != v.statut {
            v.statut = s
            switch s {
            case .ennemi: signaux.append("voisin_ennemi")
            case .ami: signaux.append("voisin_ami")
            case .amour: signaux.append("amour_de_palier")
            case .neutre: break
            }
        }
        if eff.devientAmi == true, v.relationId == nil {
            let r = Relation(prenom: v.prenom, nom: v.nom, genre: v.genre, type: .ami, age: v.age, lien: max(v.lien, 60))
            j.relations.append(r)
            v.relationId = r.id
            if v.statut == .neutre || v.statut == .ennemi { v.statut = .ami }
            lignes.append("\(v.prenom) fait maintenant partie de tes " + (v.genre == .femme ? "amies." : "amis."))
            if !signaux.contains("voisin_ami") { signaux.append("voisin_ami") }
        }
        if eff.devientPartenaire == true, j.age >= 18, v.age >= 18,
           !j.relations.contains(where: { $0.type == .partenaire && $0.vivant }) {
            // Si le voisin était déjà un ami dans tes relations, il change de case.
            if let rid = v.relationId, let k = j.relations.firstIndex(where: { $0.id == rid }) {
                j.relations[k].type = .partenaire
                j.relations[k].lien = max(j.relations[k].lien, 70)
            } else {
                let r = Relation(prenom: v.prenom, nom: v.nom, genre: v.genre, type: .partenaire, age: v.age, lien: max(v.lien, 70))
                j.relations.append(r)
                v.relationId = r.id
            }
            v.statut = .amour
            v.celibataire = false
            lignes.append("❤️ \(v.prenom), qui habite \(v.emplacement), est maintenant " + (v.genre == .femme ? "ta copine." : "ton copain."))
            if !signaux.contains("amour_de_palier") { signaux.append("amour_de_palier") }
        }
        if eff.meurt == true {
            v.vivant = false
            if let rid = v.relationId, let k = j.relations.firstIndex(where: { $0.id == rid }) { j.relations[k].vivant = false }
            signaux.append("voisin_mort")
        } else if eff.demenage == true {
            v.vivant = false
            v.parti = true
            // Un ami ou un amour qui déménage reste dans tes relations.
        }
        etat.voisins[i] = v
        if !v.vivant {
            etat.voisins.remove(at: i)
            etat.anciens.append(v)
            if etat.anciens.count > 30 { etat.anciens.removeFirst(etat.anciens.count - 30) }
        }
        return (lignes, signaux)
    }

    // MARK: Année

    struct BilanAnnee {
        var lignes: [String] = []
        var signaux: [String] = []
        /// Événement de quartier tiré cette année, avec le voisin ciblé.
        var evenement: VoisinageEvenement?
        var voisin: Voisin?
    }

    /// Fait vivre le quartier pendant un an (à appeler après le passage de l'âge du joueur).
    static func passerUneAnnee(_ j: inout Joueur, _ etat: inout VoisinageEtat, tags tagsMoteur: Set<String>) -> BilanAnnee {
        var res = BilanAnnee()
        etat.anneesIci += 1

        // Les voisins vieillissent, déménagent ou meurent.
        var partis: [Voisin] = []
        for i in etat.voisins.indices where etat.voisins[i].vivant {
            etat.voisins[i].age += 1
            etat.voisins[i].anneesDansLeQuartier += 1
            etat.voisins[i].lien = Stats.borne(etat.voisins[i].lien + Int.random(in: -2...1))
            var v = etat.voisins[i]
            // Un voisin devenu ami ou partenaire suit le destin de la relation.
            if let rid = v.relationId, let r = j.relations.first(where: { $0.id == rid }) {
                if !r.vivant { v.vivant = false; etat.voisins[i] = v; partis.append(v) }
                continue
            }
            if v.age >= 55 && Double.random(in: 0...1) < GameEngine.chanceDeces(age: v.age, sante: 65) {
                v.vivant = false
                res.lignes.append(remplir("🕯️ {voisin_nom}, {voisin_qui} qui habitait {emplacement}, est mort{ve} à {voisin_age} ans.", voisin: v, etat: etat)
                                  + (v.lien >= 70 ? " Le quartier ne sera plus pareil." : v.statut == .ennemi ? " Tu ne sais pas trop quoi ressentir." : ""))
                if v.lien >= 70 { j.stats.bonheur -= 6 }
                res.signaux.append("voisin_mort")
            } else {
                let chance = v.statut == .ennemi ? 0.10 : v.statut == .amour ? 0.0 : 0.05
                if Double.random(in: 0...1) < chance {
                    v.vivant = false
                    v.parti = true
                    res.lignes.append(remplir(phrasesDepart.randomElement()!, voisin: v, etat: etat))
                    if v.lien >= 75 { j.stats.bonheur -= 3 }
                }
            }
            etat.voisins[i] = v
            if !v.vivant { partis.append(v) }
        }
        if !partis.isEmpty {
            etat.voisins.removeAll { !$0.vivant }
            etat.anciens.append(contentsOf: partis)
            if etat.anciens.count > 30 { etat.anciens.removeFirst(etat.anciens.count - 30) }
        } else if etat.voisinsPresents.count < etat.logement.nombreVoisins.lowerBound,
                  let nv = genererVoisin(etat: etat, ageJoueur: j.age) {
            // Un logement vide trouve preneur l'année d'après.
            etat.voisins.append(nv)
            res.lignes.append(remplir(phrasesArrivee.randomElement()!, voisin: nv, etat: etat))
            res.signaux.append("nouveau_voisin")
        }

        // L'ambiance revient doucement vers la moyenne.
        if etat.ambiance > 55 { etat.ambiance -= 1 } else if etat.ambiance < 45 { etat.ambiance += 1 }

        // Argent : charges de copro et loyer (si le module boutique ne s'en occupe pas).
        if !etat.chezParents {
            if etat.proprietaire, let c = etat.copro, c.chargesAnnuelles > 0 {
                j.argent -= c.chargesAnnuelles
                res.lignes.append("Charges de copro payées à \(c.nomSyndic) : \(Format.argent(c.chargesAnnuelles)).")
            }
            if let loyer = etat.loyerAnnuel, loyer > 0 {
                j.argent -= loyer
            }
        }

        // Une phrase d'ambiance d'un voisin.
        if Double.random(in: 0...1) < chancePhrase, let v = etat.voisinsPresents.randomElement(),
           let phrase = VoisinageDonnees.archetype(v.archetype)?.phrases.randomElement() {
            res.lignes.append(remplir(phrase, voisin: v, etat: etat))
        }

        // Un événement de quartier.
        if Double.random(in: 0...1) < chanceEvenement {
            let tous = tagsMoteur.union(tags(etat))
            let liste = candidats(j, etat, tags: tous)
            if let tire = GameEngine.tirage(liste, poids: { $0.0.weight ?? 1 }) {
                let e = tire.0
                res.evenement = e
                res.voisin = tire.1.randomElement()
                if e.unique == true { etat.vus.append(e.id) }
            }
        }
        return res
    }

    static let phrasesDepart = [
        "📦 {voisin}, {voisin_qui}, a déménagé. Le camion est parti avec un bout de ta boîte aux lettres.",
        "📦 {voisin_nom} déménage. {Il} a laissé un mot : « Bonne chance avec les autres. »",
        "📦 {voisin} est parti{ve} sans prévenir. Seule trace : un pot de fleurs mort et une odeur de mystère.",
        "📦 {voisin}, qui habitait {emplacement}, a déménagé à l'autre bout du pays. Hasard ? Tu préfères ne pas savoir.",
    ]

    static let phrasesArrivee = [
        "🏠 Nouveau voisin : {voisin_complet}, {voisin_qui}, emménage {emplacement}. Ça promet.",
        "🏠 Quelqu'un emménage {emplacement} : {voisin}, {voisin_qui}. Les cartons étaient étiquetés « NE PAS OUVRIR ».",
        "🏠 {voisin_complet} vient d'arriver {emplacement}. {Il} a déjà demandé le code du Wi-Fi.",
        "🏠 Bienvenue à {voisin}, {voisin_qui}, qui s'installe {emplacement}. Le rideau du quartier a bougé.",
    ]

    // MARK: Interactions

    static func interactionPossible(_ i: VoisinageInteraction, voisin: Voisin?, _ j: Joueur, _ etat: VoisinageEtat, tags: Set<String>) -> Bool {
        guard j.vivant, j.age >= i.minAge else { return false }
        if let m = i.maxAge, j.age > m { return false }
        guard conditionsQuartier(i.quartier, etat), conditionsMoteur(i.conditions, j, tags: tags) else { return false }
        if i.portee == "voisin" {
            guard let v = voisin, correspond(v, i.cible, joueur: j) else { return false }
        }
        return true
    }

    static func cleAnnee(_ i: VoisinageInteraction, voisin: Voisin?) -> String {
        "vsi_" + i.id + (voisin.map { "_" + String($0.id.uuidString.prefix(8)) } ?? "")
    }

    /// Tire l'issue d'une interaction en tenant compte des traits du voisin et du lien.
    static func tirerIssue(_ i: VoisinageInteraction, voisin: Voisin?) -> VoisinageInteractionIssue? {
        let a = voisin.flatMap { VoisinageDonnees.archetype($0.archetype) }
        return GameEngine.tirage(i.outcomes) { o in
            var p = o.chance ?? 1
            if let trait = o.trait, let a = a {
                let valeur: Int
                switch trait {
                case "bruit": valeur = a.bruit
                case "curiosite": valeur = a.curiosite
                default: valeur = a.gentillesse
                }
                let x = Double(o.sens == "bas" ? 100 - valeur : valeur) / 50
                p *= max(0.1, x)
            }
            if let b = o.bonusLien, let v = voisin, v.lien >= b { p *= 2 }
            return p
        }
    }
}

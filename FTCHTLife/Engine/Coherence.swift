import Foundation

// Règles de bon sens entre les modules, limite d'événements par année et tags de train de vie.

extension GameEngine {

    /// Nombre maximum d'événements à choix par année.
    static let maxEvenementsAChoix = 3

    /// Mandats qui prennent tout le temps : on ne garde pas son métier à côté.
    static let postesPleinTemps: Set<PolPoste> = [.maire, .presidentRegion, .depute, .senateur, .presidentAssemblee,
                                                             .ministre, .premierMinistre, .commissaire, .president, .secretaireGeneral]

    // MARK: - Cohérence de la situation

    /// Raison qui empêche d'avoir un emploi en ce moment (prison, chef de parti, mandat à plein temps), ou nil.
    func empechementEmploi(_ j: Joueur) -> String? {
        if j.vieEtat.justice.enPrison { return "Tu es en prison. Les recruteurs ne font pas les parloirs." }
        if let raison = empechementActivite(j) { return raison }
        if let pol = j.politique {
            if pol.estChefDeParti { return "Tu diriges un parti : c'est déjà un travail à plein temps (non payé)." }
            if let p = pol.mandat?.poste, Self.postesPleinTemps.contains(p) {
                return "Ton mandat de \(p.nom(j.genre).lowercased()) est un temps plein. Démissionne d'abord si tu veux retravailler."
            }
        }
        return nil
    }

    private func besoinCoherence(_ j: Joueur) -> Bool {
        guard j.vivant, j.emploi != nil || j.carriere != nil else { return false }
        return (j.carriere != nil && j.emploi == nil) || empechementEmploi(j) != nil
    }

    /// Activité à plein temps du joueur (agence de détective, grande secte) qui empêche d'avoir un emploi, ou nil.
    func empechementActivite(_ j: Joueur) -> String? {
        if j.agences?.actuelle != nil { return "Ton agence de détective est ton métier à plein temps." }
        if let s = j.sectes?.actuelle, SecteMoteur.pleinTemps(s) {
            return "\(s.nom) occupe désormais tout ton temps."
        }
        return nil
    }

    /// Termine l'emploi quand la situation ne le permet plus.
    func coherenceSituation(_ j: inout Joueur) {
        guard besoinCoherence(j) else { return }
        let ancien = j.dernierEmploi
        if j.vieEtat.justice.enPrison {
            if j.carriere != nil { terminerCarriere(&j, raison: .arrested) } else { j.dernierEmploi = j.emploi; j.emploi = nil }
            ajouterLigne(&j, "Tu perds ton emploi : difficile de pointer au bureau depuis une cellule.")
        } else if let pol = j.politique, pol.estChefDeParti || pol.mandat.map({ Self.postesPleinTemps.contains($0.poste) }) == true {
            let titre = j.emploi?.titre.lowercased() ?? "ton poste"
            if j.carriere != nil { terminerCarriere(&j, raison: .quit) } else { j.dernierEmploi = j.emploi; j.emploi = nil }
            ajouterLigne(&j, pol.estChefDeParti
                ? "Tu quittes ton poste de \(titre) pour te consacrer à ton parti. Ton patron te souhaite bonne chance, ton banquier un peu moins."
                : "Tu quittes ton poste de \(titre) : ton mandat est un temps plein (et même un peu plus).")
        } else if let raison = empechementActivite(j) {
            let titre = j.emploi?.titre.lowercased() ?? "ton poste"
            if j.carriere != nil { terminerCarriere(&j, raison: .quit) } else { j.dernierEmploi = j.emploi; j.emploi = nil }
            ajouterLigne(&j, "Tu quittes ton poste de \(titre). " + raison)
        } else if j.carriere != nil && j.emploi == nil {
            // Un module a retiré l'emploi (expatriation, démission…) : la carrière s'arrête aussi.
            terminerCarriere(&j, raison: .quit)
        }
        if j.dernierEmploi == nil { j.dernierEmploi = ancien }
    }

    /// Appelé à chaque changement du joueur (voir `joueur.didSet`).
    func verifierCoherence() {
        guard !enCoherence, var j = joueur, besoinCoherence(j) else { return }
        enCoherence = true
        coherenceSituation(&j)
        joueur = j
        enCoherence = false
    }

    // MARK: - Limite d'événements

    /// Ordre de priorité quand il y a trop d'événements dans l'année (0 = garder en premier).
    func prioriteEvenement(_ e: Evenement) -> Int {
        let id = e.id
        if Secrets.estCarte(id) || id.hasPrefix("suc_") || id.hasPrefix(PolMoteur.prefixeSoiree) { return 0 }
        if id.hasPrefix(SecteMoteur.prefixe + "sec_enq") || id.hasPrefix(AgenceMoteur.prefixeDenouement) { return 0 }
        if id.hasPrefix("work:") { return 2 }
        if id.hasPrefix("fet_") { return 3 }
        return 1   // suites des choix passés, voisins…
    }

    /// Garde au plus `maxEvenementsAChoix` événements à choix dans l'année, les plus importants d'abord.
    func limiterFileEvenements() {
        let place = Self.maxEvenementsAChoix - (evenementEnCours == nil ? 0 : 1)
        guard fileEvenements.count > place else { return }
        let tries = fileEvenements.enumerated().sorted {
            let a = prioriteEvenement($0.element.evenement), b = prioriteEvenement($1.element.evenement)
            return a != b ? a < b : $0.offset < $1.offset
        }
        fileEvenements = tries.prefix(max(0, place)).sorted { $0.offset < $1.offset }.map(\.element)
    }

    /// Les événements qui collent à la situation (tags, souvenirs, emploi, couple) sortent plus souvent.
    func bonusSituation(_ e: Evenement) -> Double {
        guard let c = e.conditions else { return 1 }
        var n = (c.tags?.count ?? 0) + (c.flags?.count ?? 0)
        if c.requiresJob == true { n += 1 }
        if c.requiresPartner == true { n += 1 }
        if c.minMoney != nil { n += 1 }
        return 1 + 0.8 * Double(min(n, 4))
    }

    // MARK: - Train de vie

    /// Tags décrivant le train de vie : argent, logement, biens, salaire.
    func tagsTrainDeVie(_ j: Joueur) -> Set<String> {
        var t: Set<String> = []
        if j.argent >= 1_000_000 { t.insert("millionaire") }
        if j.argent >= 1_000_000_000 { t.insert("milliardaire") }
        if j.argent < 0 { t.insert("endette") }
        if let s = j.emploi?.salaire {
            if s >= 100_000 { t.insert("gros_salaire") }
            if s < 25_000 { t.insert("petit_salaire") }
        }
        let p = j.possessions ?? Possessions()
        switch p.residence {
        case .parents: if j.age >= 18 { t.insert("chez_parents") }
        case .rental: t.insert("locataire")
        case .owned: t.insert("proprietaire")
        }
        var valeur = 0
        var maisons = 0
        for item in p.items {
            valeur += item.value
            guard let c = ShopCatalog.shared.item(item.catalogId) else { continue }
            switch c.category {
            case .realEstate: maisons += 1
            case .car:
                t.insert("voiture")
                if c.price >= 80_000 { t.insert("voiture_luxe") }
            case .moto: t.insert("moto")
            case .boat: t.insert("bateau")
            case .aircraft: t.insert("avion_prive")
            case .jewelry, .watch: t.insert("bijoux")
            case .art: t.insert("collection_art")
            default: break
            }
        }
        if maisons >= 2 { t.insert("multi_proprietaire") }
        if valeur >= 1_000_000 { t.insert("vie_de_luxe") }
        if p.travels.count >= 3 { t.insert("grand_voyageur") }
        return t
    }
}

/// Choix « stable » dans une liste : même résultat pour la même clé (l'âge du joueur),
/// pour que {ami}, {enfant}, {fratrie}… désignent la même personne dans le texte et dans l'issue d'une carte.
func choixStable<T>(_ liste: [T], _ cle: Int) -> T? {
    guard !liste.isEmpty else { return nil }
    return liste[abs(cle &* 7919 &+ 13) % liste.count]
}

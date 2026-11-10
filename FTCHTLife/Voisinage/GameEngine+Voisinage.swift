import Foundation

// MARK: - Branchement du voisinage dans le moteur
//
// Le fil moteur n'a que quelques lignes à ajouter (détails dans docs/VOISINAGE.md, « Branchement ») :
//   1. `Joueur` : `var voisinage: VoisinageEtat?`, puis les deux lignes ⚙️ de `VoisinageStockage`.
//   2. `vieillir()` : `voisinageAnnee()` juste avant `tirerEvenements()`.
//   3. `choisir(_:)` : `voisinageApresChoix(aff.evenement, choix: index, issue: issue, &j)` juste après `appliquer`.
//   4. Un bouton « Voisins » qui ouvre `VoisinageView()`.
// Optionnel : `voisinageNouvelleVie()` à la fin de `nouvelleVie` (sinon le quartier est créé au premier anniversaire),
// les tags du voisinage dans `tags(_:)`, et `VoisinageStockage.signaler` vers le module Répercussions.

extension GameEngine {

    /// Voisinage du joueur en cours (nil avant le premier passage d'année d'une ancienne sauvegarde).
    var voisinage: VoisinageEtat? {
        joueur.flatMap { VoisinageStockage.lire($0) }
    }

    /// Renvoie l'état du voisinage, en le créant si besoin (quartier des parents pour un mineur).
    func voisinageEtat(_ j: inout Joueur) -> VoisinageEtat {
        if let e = VoisinageStockage.lire(j) { return e }
        let e = j.age < 18
            ? VoisinageMoteur.quartierDesParents(j)
            : VoisinageMoteur.nouveauQuartier(logement: .appartement, chezParents: false, proprietaire: false, ageJoueur: j.age)
        VoisinageStockage.ecrire(&j, e)
        return e
    }

    // MARK: Crochets du moteur

    /// À appeler à la fin de `nouvelleVie` : le bébé découvre le quartier de ses parents.
    func voisinageNouvelleVie() {
        modifier { j in
            let e = VoisinageMoteur.quartierDesParents(j)
            VoisinageStockage.ecrire(&j, e)
            let lieu: String
            switch e.logement {
            case .appartement: lieu = "un appartement"
            case .maison: lieu = "une maison"
            case .villa: lieu = "une villa"
            case .campagne: lieu = "une ferme"
            case .caravane: lieu = "une caravane"
            }
            ajouterLigne(&j, "Tes parents habitent \(lieu) (\(e.quartier), \(e.adresse)). Les voisins t'ont déjà jugé" + j.g("", "e") + " à travers la fenêtre.")
        }
    }

    /// À appeler dans `vieillir()`, après `joueur = j` et avant `tirerEvenements()`.
    /// Fait vivre le quartier et peut afficher un événement de voisinage (avant les autres événements de l'année).
    func voisinageAnnee() {
        guard var j = joueur, j.vivant else { return }
        var etat = voisinageEtat(&j)
        let res = VoisinageMoteur.passerUneAnnee(&j, &etat, tags: tags(j))
        for l in res.lignes { ajouterLigne(&j, remplir(l, j)) }
        var signaux = res.signaux

        if let e = res.evenement {
            if let choix = e.choices, !choix.isEmpty {
                let ev = VoisinageMoteur.versEvenement(e, voisin: res.voisin, etat: etat)
                etat.enCours[e.id] = res.voisin?.id
                VoisinageStockage.ecrire(&j, etat)
                joueur = j
                let aff = EvenementAffiche(evenement: ev, texte: remplir(ev.text, j))
                if evenementEnCours == nil { evenementEnCours = aff }
            } else {
                ajouterLigne(&j, remplir(VoisinageMoteur.remplir(e.text, voisin: res.voisin, etat: etat), j))
                if let eff = e.effects { appliquer(eff, &j) }
                let r = VoisinageMoteur.appliquer(e.voisin, voisinId: res.voisin?.id, &j, &etat)
                for l in r.lignes { ajouterLigne(&j, l) }
                signaux += r.signaux
            }
        }
        j.stats.borner()
        VoisinageStockage.ecrire(&j, etat)
        for s in signaux { VoisinageStockage.signaler(s, &j) }
        joueur = j
    }

    /// À appeler dans `choisir(_:)` juste après `appliquer(eff, &j)` : applique les effets sur le voisin et le quartier.
    /// Ne fait rien pour un événement qui ne vient pas du voisinage.
    func voisinageApresChoix(_ evenement: Evenement, choix index: Int, issue: Issue?, _ j: inout Joueur) {
        guard evenement.category == "voisinage", let source = VoisinageDonnees.evenement(evenement.id),
              let choixSource = source.choices, choixSource.indices.contains(index),
              var etat = VoisinageStockage.lire(j) else { return }
        let affiches = evenement.choices?[index].outcomes ?? []
        let k = issue.flatMap { affiches.firstIndex(of: $0) } ?? 0
        let issues = choixSource[index].outcomes
        guard issues.indices.contains(k) else { return }
        let voisinId = etat.enCours.removeValue(forKey: evenement.id)
        let r = VoisinageMoteur.appliquer(issues[k].voisin, voisinId: voisinId, &j, &etat)
        for l in r.lignes { ajouterLigne(&j, l) }
        VoisinageStockage.ecrire(&j, etat)
        for s in r.signaux { VoisinageStockage.signaler(s, &j) }
    }

    // MARK: Pour le module boutique

    /// Le joueur emménage dans un nouveau logement (achat ou location gérés par la boutique).
    /// Ex. `engine.voisinageEmmenager(logement: .depuis(bien.nom), proprietaire: true)`.
    func voisinageEmmenager(logement: VoisinageLogement, proprietaire: Bool, loyerAnnuel: Int? = nil) {
        modifier { j in
            let ancien = voisinageEtat(&j)
            var nouveau = VoisinageMoteur.nouveauQuartier(logement: logement, chezParents: false, proprietaire: proprietaire, ageJoueur: j.age)
            nouveau.loyerAnnuel = loyerAnnuel
            // Les amis et amours du quartier restent dans tes relations ; les autres voisins deviennent des souvenirs.
            nouveau.anciens = Array((ancien.anciens + ancien.voisinsPresents).suffix(30))
            let ennemis = ancien.voisinsPresents.filter { $0.statut == .ennemi }.count
            var ligne = "🚚 Tu emménages au \(nouveau.adresse) (\(nouveau.quartier))."
            if ancien.chezParents { ligne = "🚚 Tu quittes le nid ! Nouvelle adresse : \(nouveau.adresse) (\(nouveau.quartier))." }
            if ennemis > 0 { ligne += " Tes anciens ennemis de quartier fêtent ton départ." }
            ajouterLigne(&j, ligne)
            if let v = nouveau.voisinsPresents.randomElement() {
                ajouterLigne(&j, remplir(VoisinageMoteur.remplir("Premier contact : {voisin}, {voisin_qui}, t'observe depuis {emplacement}.", voisin: v, etat: nouveau), j))
            }
            VoisinageStockage.ecrire(&j, nouveau)
            VoisinageStockage.signaler("demenagement", &j)
        }
    }

    // MARK: Pour l'écran Voisins

    /// Interactions affichées pour un voisin (portée "voisin") ou pour le quartier (voisin nil, portée "quartier").
    func voisinageInteractions(voisin: Voisin?) -> [VoisinageAction] {
        guard let j = joueur, let etat = VoisinageStockage.lire(j) else { return [] }
        let t = tags(j).union(VoisinageMoteur.tags(etat))
        let portee = voisin == nil ? "quartier" : "voisin"
        return VoisinageDonnees.interactions
            .filter { $0.portee == portee && VoisinageMoteur.interactionPossible($0, voisin: voisin, j, etat, tags: t) }
            .map { i -> VoisinageAction in
                let fait = j.actionsAnnee.contains(VoisinageMoteur.cleAnnee(i, voisin: voisin))
                let cout = j.age < 18 ? 0 : (i.cout ?? 0)
                return VoisinageAction(interaction: i, dispo: !fait && j.argent >= cout)
            }
    }

    /// Fait une interaction et renvoie le texte du résultat.
    func voisinageFaire(_ i: VoisinageInteraction, voisinId: UUID?) -> String {
        var texte = ""
        modifier { j in
            guard j.vivant else { return }
            var etat = voisinageEtat(&j)
            let voisin = voisinId.flatMap { id in etat.voisins.first { $0.id == id } }
            let t = tags(j).union(VoisinageMoteur.tags(etat))
            guard VoisinageMoteur.interactionPossible(i, voisin: voisin, j, etat, tags: t) else {
                texte = "Ce n'est pas possible pour le moment."
                return
            }
            let cle = VoisinageMoteur.cleAnnee(i, voisin: voisin)
            if j.actionsAnnee.contains(cle) { texte = "Tu l'as déjà fait cette année. Laisse respirer le quartier."; return }
            let cout = j.age < 18 ? 0 : (i.cout ?? 0)
            if cout > 0 && j.argent < cout { texte = "Tu n'as pas assez d'argent (\(Format.argent(cout)))."; return }
            j.argent -= cout
            j.actionsAnnee.append(cle)
            guard let issue = VoisinageMoteur.tirerIssue(i, voisin: voisin) else { return }
            texte = remplir(VoisinageMoteur.remplir(issue.text, voisin: voisin, etat: etat), j)
            ajouterLigne(&j, texte)
            if let eff = issue.effects { appliquer(eff, &j) }
            let r = VoisinageMoteur.appliquer(issue.voisin, voisinId: voisin?.id, &j, &etat)
            for l in r.lignes { ajouterLigne(&j, l) }
            if !r.lignes.isEmpty { texte += "\n\n" + r.lignes.joined(separator: "\n") }
            VoisinageStockage.ecrire(&j, etat)
            for s in r.signaux { VoisinageStockage.signaler(s, &j) }
        }
        return texte
    }

    /// Loyers annuels proposés par le déménagement simple de l'écran Voisins.
    static let voisinageLoyers: [VoisinageOffreLocation] = [
        VoisinageOffreLocation(logement: .appartement, loyer: 9_600, description: "Un deux-pièces en immeuble"),
        VoisinageOffreLocation(logement: .maison, loyer: 16_800, description: "Une petite maison avec jardin (et haie)"),
        VoisinageOffreLocation(logement: .caravane, loyer: 3_600, description: "Un mobil-home au camping, à l'année"),
    ]

    /// Déménagement simple en location depuis l'écran Voisins (quand la boutique ne s'en charge pas).
    func voisinageDemenagerEnLocation(_ logement: VoisinageLogement) -> String {
        guard let j = joueur, j.age >= 18 else { return "Tu es trop jeune pour signer un bail." }
        guard let offre = Self.voisinageLoyers.first(where: { $0.logement == logement }) else { return "" }
        let caution = offre.loyer / 4
        if j.argent < caution { return "Le propriétaire veut trois mois de caution (\(Format.argent(caution))). Ton compte a ri." }
        modifier { j in j.argent -= caution }
        voisinageEmmenager(logement: logement, proprietaire: false, loyerAnnuel: offre.loyer)
        return "Bail signé ! Loyer : \(Format.argent(offre.loyer)) par an, caution de \(Format.argent(caution)) payée. Tes nouveaux voisins t'observent déjà."
    }
}

/// Une interaction proposée dans l'écran Voisins.
struct VoisinageAction: Identifiable {
    let interaction: VoisinageInteraction
    let dispo: Bool
    var id: String { interaction.id }
}

/// Une offre de location de l'écran Voisins.
struct VoisinageOffreLocation: Identifiable {
    let logement: VoisinageLogement
    let loyer: Int
    let description: String
    var id: String { logement.rawValue }
}

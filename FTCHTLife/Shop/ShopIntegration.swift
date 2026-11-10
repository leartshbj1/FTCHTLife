import Foundation

// Branchement de la boutique sur le joueur du moteur.
// Le seul changement hors de Shop/ est le champ `var possessions: Possessions?` de `Joueur`.

extension Joueur: ShopActor {
    var firstName: String { prenom }
    var money: Int {
        get { argent }
        set { argent = newValue }
    }
    var happiness: Int {
        get { stats.bonheur }
        set { stats.bonheur = newValue }
    }
    var health: Int {
        get { stats.sante }
        set { stats.sante = newValue }
    }
    var looks: Int {
        get { stats.apparence }
        set { stats.apparence = newValue }
    }
    var smarts: Int {
        get { stats.intelligence }
        set { stats.intelligence = newValue }
    }
    var karma: Int {
        get { stats.karma }
        set { stats.karma = newValue }
    }
    var boutique: Possessions {
        get { possessions ?? Possessions() }
        set { possessions = newValue }
    }
}

extension GameEngine {
    /// À appeler par le moteur à chaque « +1 an », après le vieillissement.
    /// Paie l'entretien, les crédits et les loyers, fait évoluer la valeur des biens
    /// et tire les événements liés aux biens (gardés dans `joueur.possessions.pendingEvents`).
    func passageAnneeBoutique(_ j: inout Joueur) {
        guard j.possessions != nil else { return }
        let rapport = ShopEngine.yearlyTick(&j)
        for ligne in rapport.lines { ajouterLigne(&j, ligne) }
        if !rapport.events.isEmpty {
            ajouterLigne(&j, "Quelque chose est arrivé à tes biens. Ouvre la boutique pour voir.")
        }
    }

    /// Événements de biens en attente d'une réponse (pour afficher un badge).
    var evenementsBoutiqueEnAttente: Int {
        joueur?.possessions?.pendingEvents.count ?? 0
    }
}

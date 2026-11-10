import Foundation

extension GameEngine {
    /// Met à jour les rêves du joueur (tirage à 16 ans, rêves réalisés ou ratés), applique le bonheur et écrit le journal.
    /// Le chemin désigne le champ qui stocke les rêves, ex. `revesMettreAJour(&j, etat: \.reves)`.
    /// À appeler dans `vieillir()`, après chaque choix d'événement et dans `modifier(_:)`.
    func revesMettreAJour(_ j: inout Joueur, etat cle: WritableKeyPath<Joueur, RevesDeVie?>) {
        guard j.vivant else { return }
        var etat = j[keyPath: cle] ?? RevesDeVie()
        let bilan = RevesMoteur.mettreAJour(&etat, joueur: j)
        j[keyPath: cle] = etat
        guard bilan.bonheur != 0 || !bilan.lignes.isEmpty else { return }
        j.stats.bonheur += bilan.bonheur
        j.stats.borner()
        for ligne in bilan.lignes {
            ajouterLigne(&j, ligne)
        }
    }
}

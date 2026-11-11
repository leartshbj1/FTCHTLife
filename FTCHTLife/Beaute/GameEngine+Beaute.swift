import Foundation

// Branchement du module Beauté (coiffeur, chirurgie esthétique) dans le moteur. Voir docs/BEAUTE.md.

extension GameEngine {

    /// Écrit le résultat au journal (si l'action a eu lieu) et gère une éventuelle mort au bloc.
    private func beauteFinir(_ r: BeauteResultat, _ j: inout Joueur) {
        guard r.ok else { return }
        if !r.texte.isEmpty { ajouterLigne(&j, r.texte) }
        if let cause = r.deces, Shkurtaaa.peutMourir(deVieillesse: false) { mourir(&j, cause: cause) }
    }

    func beauteCoiffer(salon: String, coupe: String, couleur: String?) -> String {
        var texte = ""
        modifier { j in
            let r = BeauteMoteur.coiffer(&j, salon: salon, coupe: coupe, couleur: couleur)
            texte = r.texte
            beauteFinir(r, &j)
        }
        return texte
    }

    func beauteOperer(_ intervention: String, clinique: String) -> String {
        var texte = ""
        modifier { j in
            let r = BeauteMoteur.operer(&j, intervention: intervention, clinique: clinique)
            texte = r.texte
            beauteFinir(r, &j)
        }
        return texte
    }

    func beauteReparer(_ operation: UUID) -> String {
        var texte = ""
        modifier { j in
            let r = BeauteMoteur.reparer(&j, operation: operation)
            texte = r.texte
            beauteFinir(r, &j)
        }
        return texte
    }

    func beauteSoigner(_ suite: UUID) -> String {
        var texte = ""
        modifier { j in
            let r = BeauteMoteur.soigner(&j, suite: suite)
            texte = r.texte
            beauteFinir(r, &j)
        }
        return texte
    }

    /// Sous-objet "beaute" des effets d'un événement (appelé depuis modulesAppliquer).
    func beauteAppliquer(_ fx: BeauteEffets?, _ j: inout Joueur) {
        guard let fx = fx else { return }
        beauteFinir(BeauteMoteur.appliquer(fx, &j), &j)
    }
}

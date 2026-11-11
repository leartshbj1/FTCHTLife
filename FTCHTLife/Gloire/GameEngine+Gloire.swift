import Foundation

// Branchement du module Gloire (célébrité + procès) dans le moteur. Voir docs/GLOIRE.md.

extension GameEngine {

    /// Écrit le résultat au journal (si l'action a eu lieu), marque le rêve « célèbre » et gère une éventuelle mort.
    private func gloireFinir(_ r: GloireResultat, _ j: inout Joueur) {
        guard r.ok else { return }
        if !r.texte.isEmpty { ajouterLigne(&j, r.texte) }
        for l in r.lignes { ajouterLigne(&j, l) }
        if GloireMoteur.gloire(j) >= 60 { RevesMoteur.marquer(&j.reves, ["celebre"]) }
        if let cause = r.deces, Shkurtaaa.peutMourir(deVieillesse: false) {
            mourir(&j, cause: cause)
        } else if j.stats.sante <= 0, Shkurtaaa.peutMourir(deVieillesse: false) {
            mourir(&j, cause: "d'épuisement, sous les projecteurs")
        }
    }

    private func gloireAgir(_ action: (inout Joueur) -> GloireResultat) -> GloireResultat {
        var r = GloireResultat.refus("")
        modifier { j in
            guard j.vivant else { return }
            r = action(&j)
            gloireFinir(r, &j)
        }
        return r
    }

    func gloireEcrireLivre(_ genre: String, pretePlume: Bool) -> GloireResultat {
        gloireAgir { GloireMoteur.ecrireLivre(genre, pretePlume: pretePlume, &$0) }
    }

    func gloireTournerPub(_ id: String) -> GloireResultat {
        gloireAgir { GloireMoteur.tournerPub(id, &$0) }
    }

    func gloireFaire(_ id: String) -> GloireResultat {
        gloireAgir { GloireMoteur.faire(id, &$0) }
    }

    func gloireTrancher(_ d: GloireDilemme, accepte: Bool) -> GloireResultat {
        gloireAgir { GloireMoteur.trancher(d, accepte: accepte, &$0) }
    }

    func gloireAttache(engager: Bool) -> GloireResultat {
        gloireAgir { j in
            if engager { return GloireMoteur.engagerAttache(&j) }
            return GloireMoteur.renvoyerAttache(&j)
        }
    }

    // MARK: - Procès

    /// Lance un procès. Renvoie l'audience, ou la raison du refus.
    func procesOuvrir(_ cible: ProcesCibleProposee, _ motif: ProcesMotif, _ avocat: ProcesAvocat) -> (audience: ProcesAudience?, refus: String?) {
        var res: (audience: ProcesAudience?, refus: String?) = (nil, "Aucune vie en cours.")
        modifier { j in
            guard j.vivant else { return }
            res = ProcesMoteur.ouvrir(cible, motif, avocat, &j)
            if res.audience != nil {
                ajouterLigne(&j, "⚖️ Tu attaques \(cible.nom) en justice (\(GloireMoteur.texte(motif.nom, j).lowercased())). \(avocat.nom) prend le dossier.")
            }
        }
        return res
    }

    func procesAccord(_ aud: inout ProcesAudience) {
        var copie = aud
        modifier { j in
            let t = ProcesMoteur.accepterAccord(&copie, &j)
            if !t.isEmpty { ajouterLigne(&j, t) }
        }
        aud = copie
    }

    func procesPlaider(_ strategie: ProcesStrategie, _ aud: inout ProcesAudience) {
        var copie = aud
        modifier { j in
            let t = ProcesMoteur.plaider(strategie, &copie, &j)
            if !t.isEmpty { ajouterLigne(&j, t.replacingOccurrences(of: "\n\n", with: " ")) }
            if GloireMoteur.gloire(j) >= 60 { RevesMoteur.marquer(&j.reves, ["celebre"]) }
        }
        aud = copie
    }
}

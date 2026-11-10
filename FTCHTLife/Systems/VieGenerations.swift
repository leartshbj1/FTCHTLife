import Foundation

/// Rejouer avec un de ses enfants après sa mort.
enum VieGenerations {

    /// Autres modules à transmettre à l'héritier (réputation de la famille…), branché par le moteur :
    /// `VieGenerations.transmission = { ancien, h in h.reputationFamille = ReputationFamille.transmettre(parent: ancien,
    ///   etat: ancien.reputationFamille ?? ReputationFamille.aleatoire(), heritier: h);
    ///   return ReputationFamille.lignesNaissance(h.reputationFamille!, joueur: h) }`
    /// Renvoie des lignes de journal.
    static var transmission: ((Joueur, inout Joueur) -> [String])?

    static func heritiers(_ j: Joueur) -> [Relation] {
        j.relations.filter { $0.type == .enfant && $0.vivant }.sorted { $0.age > $1.age }
    }

    /// Part d'héritage de chaque enfant (droits de succession 20 %).
    static func partHeritage(_ j: Joueur) -> Int {
        let n = max(1, heritiers(j).count)
        let biens = max(0, j.argent)
        let conjoint = j.partenaireActuel != nil && j.vieEtat.statutCouple == .marie
        let aPartager = conjoint ? biens / 2 : biens
        return aPartager * 8 / 10 / n
    }

    /// Crée la nouvelle vie : l'enfant choisi devient le joueur.
    static func continuer(avec enfantId: UUID, depuis ancien: Joueur) -> Joueur? {
        guard let enfant = ancien.relations.first(where: { $0.id == enfantId && $0.vivant && $0.type == .enfant }) else { return nil }
        let heritage = partHeritage(ancien)

        var relations: [Relation] = []
        // L'ancien joueur devient le parent décédé.
        relations.append(Relation(prenom: ancien.prenom, nom: ancien.nom, genre: ancien.genre,
                                  type: ancien.genre == .femme ? .mere : .pere, age: ancien.age,
                                  lien: min(100, enfant.lien + 10), argent: 0, vivant: false))
        // L'autre parent (partenaire au moment de la mort).
        if let p = ancien.partenaireActuel {
            relations.append(Relation(prenom: p.prenom, nom: p.nom, genre: p.genre,
                                      type: p.genre == .femme ? .mere : .pere, age: p.age,
                                      lien: Int.random(in: 50...90), argent: ancien.vieEtat.statutCouple == .marie ? max(0, ancien.argent) / 2 : p.argent))
        }
        // Frères et sœurs.
        for f in heritiers(ancien) where f.id != enfantId {
            relations.append(Relation(prenom: f.prenom, nom: f.nom, genre: f.genre, type: f.genre == .femme ? .soeur : .frere,
                                      age: f.age, lien: Int.random(in: 30...80), argent: heritage))
        }

        // Stats : un peu de l'héritage génétique, un peu de hasard.
        var stats = Stats.aleatoire()
        stats.intelligence = (stats.intelligence + ancien.stats.intelligence) / 2
        stats.apparence = (stats.apparence + ancien.stats.apparence) / 2
        stats.bonheur = max(20, stats.bonheur - 25)
        stats.borner()

        var j = Joueur(prenom: enfant.prenom, nom: enfant.nom, genre: enfant.genre, age: enfant.age, ville: ancien.ville,
                       stats: stats, argent: heritage, diplome: enfant.age >= 16 ? .ecoleObligatoire : .aucun, filiereDiplome: nil,
                       etudes: nil, emploi: nil, relations: relations, journal: [])
        var v = VieEtat()
        v.generation = ancien.vieEtat.generation + 1
        v.ancetres = ancien.vieEtat.ancetres + ["\(ancien.nomComplet) (\(ancien.age) ans)"]
        // Les grands-parents de la nouvelle vie : les parents encore vivants de l'ancien joueur.
        for gp in ancien.parentsVivants {
            v.proches.append(VieProche(prenom: gp.prenom, nom: gp.nom, genre: gp.genre, role: .grandParent, age: gp.age, lien: gp.lien, argent: gp.argent))
        }
        j.vieEtat = v

        var lignes = [
            "Génération \(v.generation) : tu reprends la vie de \(enfant.prenom), \(enfant.age) an\(enfant.age > 1 ? "s" : "").",
            "\(ancien.genre == .femme ? "Ta mère" : "Ton père"), \(ancien.prenom), est \(ancien.g("mort", "morte")) \(ancien.causeDeces ?? "").",
        ]
        if heritage > 0 { lignes.append("Tu hérites de \(Format.argent(heritage)) (après 20 % de droits de succession, merci l'État).") }
        else if ancien.argent < 0 { lignes.append("Tu hérites… de rien. Et heureusement, les dettes ne se transmettent pas ici.") }
        lignes.append(["Tu as aussi hérité de son rire bizarre.", "Tu as aussi hérité de sa collection de cuillères souvenirs.", "Tu as aussi hérité de son nez. Désolé."].auHasard(""))
        j.journal = [Annee(age: j.age, lignes: lignes)]
        if let t = transmission {
            let plus = t(ancien, &j)
            j.journal[0].lignes += plus
        }
        return j
    }
}

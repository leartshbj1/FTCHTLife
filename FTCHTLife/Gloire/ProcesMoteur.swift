import Foundation

// Procès : poursuivre quelqu'un en justice (Activités → Procès). Voir docs/GLOIRE.md.
// Déroulé : choisir la cible, le motif, l'avocat → audience (offre d'accord à l'amiable possible)
// → plaidoirie (stratégie) → verdict.

/// Cible proposée à l'écran : un proche ou une cible fixe du catalogue.
struct ProcesCibleProposee: Identifiable, Equatable {
    var id: String
    var nom: String
    var emoji: String
    var description: String
    var type: String
    var relation: UUID?
    var defense: Int
    var poche: Double
}

enum ProcesMoteur {
    static var catalogue: ProcesCatalogue { ProcesCatalogue.charge }
    static let ageMin = 18

    // MARK: - Choix

    static func refus(_ j: Joueur) -> String? {
        if j.age < ageMin { return "Dès \(ageMin) ans. Avant, tu peux seulement le dire à tes parents." }
        if j.actionsAnnee.contains("proces") { return "Un procès par an. Ton avocat a besoin de vacances, et toi d'un peu de calme." }
        return nil
    }

    static func emoji(_ r: Relation) -> String {
        switch r.type {
        case .mere: return "👩"
        case .pere: return "👨"
        case .frere: return "👦"
        case .soeur: return "👧"
        case .ami: return r.genre == .femme ? "👱‍♀️" : "🧔"
        case .partenaire: return "❤️"
        case .enfant: return r.genre == .femme ? "👧" : "👦"
        case .ex: return "💔"
        }
    }

    static func conditionOK(_ c: String?, _ j: Joueur) -> Bool {
        guard let c = c else { return true }
        switch c {
        case "emploi": return j.carriere != nil || j.emploi != nil
        case "ancienEmploi": return !(j.historiqueCarriere ?? []).isEmpty
        case "prison": return (j.casier?.totalCondamnations ?? 0) > 0
        case "gloire": return GloireMoteur.gloire(j) >= 20
        default: return true
        }
    }

    static func nomCible(_ c: ProcesCible, _ j: Joueur) -> String {
        switch c.id {
        case "employeur": return j.carriere.map { "Ton employeur, \($0.company)" } ?? "Ton employeur"
        case "ancien_employeur": return (j.historiqueCarriere?.last).map { "Ton ancien employeur, \($0.company)" } ?? "Ton ancien employeur"
        default: return c.nom
        }
    }

    static func cibles(_ j: Joueur) -> [ProcesCibleProposee] {
        var liste: [ProcesCibleProposee] = []
        for r in j.relations where r.vivant {
            liste.append(ProcesCibleProposee(id: r.id.uuidString, nom: r.nomComplet, emoji: emoji(r),
                                             description: "\(r.libelle), \(r.age) ans", type: "proche", relation: r.id,
                                             defense: 8, poche: 1))
        }
        for c in catalogue.cibles where conditionOK(c.condition, j) {
            liste.append(ProcesCibleProposee(id: c.id, nom: nomCible(c, j), emoji: c.emoji, description: c.description,
                                             type: c.type, relation: nil, defense: c.defense, poche: c.poche))
        }
        return liste
    }

    static func motifs(_ type: String) -> [ProcesMotif] {
        catalogue.motifs.filter { $0.cibles.contains(type) }
    }

    static func avocats(_ j: Joueur) -> [ProcesAvocat] {
        catalogue.avocats.filter { a in
            guard a.condition == "droit" else { return true }
            return j.filiereDiplome == .droit || Competences.niveau("eloquence", j) >= 3
        }
    }

    /// Chances de gagner avant la plaidoirie (0…1).
    static func chance(_ cible: ProcesCibleProposee, _ motif: ProcesMotif, _ avocat: ProcesAvocat, _ j: Joueur) -> Double {
        var c = Double(motif.solidite + avocat.bonus - cible.defense) / 100
        c += Double(j.stats.intelligence - 50) / 400
        c += Double(j.stats.karma - 50) / 600
        if avocat.condition == "droit" { c += Double(j.stats.intelligence - 50) / 200 }
        return min(0.93, max(0.03, c))
    }

    static func estimation(_ c: Double) -> String {
        switch c {
        case 0.7...: return "Dossier en béton"
        case 0.5..<0.7: return "Dossier solide"
        case 0.3..<0.5: return "Dossier fragile"
        case 0.15..<0.3: return "Pari risqué"
        default: return "Perdu d'avance (en théorie)"
        }
    }

    static func texte(_ t: String, _ j: Joueur, cible: String, motif: String = "", montant: Int = 0, avocat: String = "") -> String {
        GloireMoteur.texte(t, j, ["cible": cible, "motif": motif.lowercased(), "montant": Format.argent(montant), "avocat": avocat])
    }

    // MARK: - Audience

    /// Lance la procédure : paie l'avocat, prépare l'audience. Renvoie nil + raison si impossible.
    static func ouvrir(_ cible: ProcesCibleProposee, _ motif: ProcesMotif, _ avocat: ProcesAvocat,
                       _ j: inout Joueur) -> (audience: ProcesAudience?, refus: String?) {
        if let r = refus(j) { return (nil, r) }
        guard Shkurtaaa.peutPayer(avocat.honoraires, solde: j.argent) else {
            return (nil, "\(avocat.nom) demande \(Format.argent(avocat.honoraires)) d'avance. Tu ne les as pas.")
        }
        j.actionsAnnee.append("proces")
        j.argent -= avocat.honoraires

        let mini = motif.dommages.first ?? 1_000
        let maxi = max(mini, motif.dommages.last ?? mini)
        var demande = Int(Double(Int.random(in: mini...maxi)) * cible.poche)
        if let rid = cible.relation, let r = j.relations.first(where: { $0.id == rid }) {
            demande = min(demande, max(r.argent, 8_000))
            if let i = j.relations.firstIndex(where: { $0.id == rid }) {
                j.relations[i].lien = Stats.borne(j.relations[i].lien - 25)
            }
        }
        demande = max(500, demande)

        let c = chance(cible, motif, avocat, j)
        var offre: Int? = nil
        if Double.random(in: 0...1) < 0.3 + c * 0.4 {
            let part: Double = Double.random(in: 0.25...0.6) * (0.6 + c)
            offre = max(300, Int(Double(demande) * part))
        }
        let texteOffre: String? = offre.map {
            texte(catalogue.accords.randomElement() ?? "{cible} propose {montant} pour en rester là.",
                  j, cible: cible.nom, motif: motif.nom, montant: $0, avocat: avocat.nom)
        }
        let texteAudience = texte(catalogue.audiences.randomElement() ?? "L'audience s'ouvre. {cible} est là, et te regarde.",
                                  j, cible: cible.nom, motif: motif.nom, montant: demande, avocat: avocat.nom)
        let aud = ProcesAudience(
            cibleNom: cible.nom, cibleEmoji: cible.emoji, relation: cible.relation, cibleType: cible.type,
            motif: motif, avocat: avocat, chance: c, demande: demande, offre: offre,
            texteAudience: texteAudience, texteOffre: texteOffre,
            phase: offre == nil ? .plaidoirie : .accord)
        return (aud, nil)
    }

    private static func partAvocat(_ montant: Int, _ a: ProcesAvocat) -> Int {
        Int(Double(montant) * (a.pourcentage ?? 0))
    }

    private static func archiver(_ aud: ProcesAudience, issue: String, bilan: Int, _ j: inout Joueur) {
        var e = GloireMoteur.etat(j)
        e.proces.append(ProcesDossier(age: j.age, cible: aud.cibleNom, motif: GloireMoteur.texte(aud.motif.nom, j), issue: issue, bilan: bilan))
        j.gloire = e
        if aud.relation != nil { SignauxModules.signaler("poursuite_proche", &j) }
    }

    /// Accepte l'accord à l'amiable.
    static func accepterAccord(_ aud: inout ProcesAudience, _ j: inout Joueur) -> String {
        guard let offre = aud.offre, aud.phase == .accord else { return "" }
        let part = partAvocat(offre, aud.avocat)
        let net = offre - part
        j.argent += net
        j.stats.bonheur += 4
        j.stats.borner()
        var t = "🤝 Accord à l'amiable avec \(aud.cibleNom) : tu touches \(Format.argent(offre))"
        t += part > 0 ? ", dont \(Format.argent(part)) pour \(aud.avocat.nom)." : "."
        t += " Pas de verdict, pas de gros titre, mais l'argent est là."
        archiver(aud, issue: "accord", bilan: net - aud.avocat.honoraires, &j)
        SignauxModules.signaler("poursuite_accord", &j)
        aud.phase = .verdict
        aud.gagne = true
        aud.texteVerdict = t
        return t
    }

    static func refuserAccord(_ aud: inout ProcesAudience) {
        guard aud.phase == .accord else { return }
        aud.phase = .plaidoirie
    }

    /// Plaidoirie puis verdict.
    static func plaider(_ strategie: ProcesStrategie, _ aud: inout ProcesAudience, _ j: inout Joueur) -> String {
        guard aud.phase == .plaidoirie else { return aud.texteVerdict }
        let v = GloireMoteur.valeur(strategie.stat, j)
        let modif = Double(strategie.amplitude) * Double(v - 50) / 50 / 100
        let c = min(0.95, max(0.02, aud.chance + modif))
        let gagne = Double.random(in: 0...1) < c
        let g = GloireMoteur.gloire(j)
        let plaidoirie = texte(strategie.textes.randomElement() ?? "", j, cible: aud.cibleNom, motif: aud.motif.nom, avocat: aud.avocat.nom)

        var t = plaidoirie.isEmpty ? "" : plaidoirie + "\n\n"
        if gagne {
            let montant = max(500, Int(Double(aud.demande) * Double.random(in: 0.6...1.0)))
            let part = partAvocat(montant, aud.avocat)
            j.argent += montant - part
            j.stats.bonheur += 10
            t += "⚖️ " + texte(aud.motif.victoire.randomElement() ?? "Le tribunal te donne raison : {cible} doit te verser {montant}.",
                               j, cible: aud.cibleNom, motif: aud.motif.nom, montant: montant, avocat: aud.avocat.nom)
            if part > 0 { t += " \(aud.avocat.nom) garde \(Format.argent(part))." }
            if aud.motif.frivole == true { j.stats.karma -= 3 }
            archiver(aud, issue: "gagne", bilan: montant - part - aud.avocat.honoraires, &j)
            SignauxModules.signaler("poursuite_gagnee", &j)
        } else {
            var frais = aud.avocat.honoraires / 2 + 1_500
            t += "⚖️ " + texte(aud.motif.defaite.randomElement() ?? "Le tribunal te déboute. {cible} sourit.",
                               j, cible: aud.cibleNom, motif: aud.motif.nom, avocat: aud.avocat.nom)
            if aud.motif.frivole == true {
                let amende = Int.random(in: 1_000...10_000)
                frais += amende
                j.stats.karma -= 4
                t += " Le juge te colle en plus \(Format.argent(amende)) d'amende civile pour procédure abusive."
            }
            t += " Tu dois \(Format.argent(frais)) de frais de justice."
            j.argent -= frais
            j.stats.bonheur -= 8
            archiver(aud, issue: "perdu", bilan: -frais - aud.avocat.honoraires, &j)
            SignauxModules.signaler("poursuite_perdue", &j)
        }

        if let rid = aud.relation, let i = j.relations.firstIndex(where: { $0.id == rid }) {
            j.relations[i].lien = Stats.borne(j.relations[i].lien - (gagne ? 30 : 15))
            let r = j.relations[i]
            t += gagne
                ? " \(r.prenom) ne te parle plus. Les repas de famille vont être longs."
                : " \(r.prenom) a gagné, et te le rappellera à chaque fête de famille."
        }
        if g >= 25 {
            GloireMoteur.ajouterGloire(3, &j)
            t += " Les magazines en font leurs choux gras."
        }
        j.stats.borner()
        aud.phase = .verdict
        aud.gagne = gagne
        aud.texteVerdict = t
        return t
    }
}

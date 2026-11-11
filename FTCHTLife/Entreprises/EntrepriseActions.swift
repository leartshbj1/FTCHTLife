import Foundation

// Actions du module Entreprises, branchées sur le moteur. Chaque action renvoie le texte à afficher.

extension GameEngine {

    // MARK: - Bilan annuel (appelé dans vieillir)

    /// À appeler à chaque +1 an, avant d'écrire le journal : `lignes += bilanEntreprises(&j)`.
    func bilanEntreprises(_ j: inout Joueur) -> [String] {
        guard var etat = j.entreprises, !etat.actives.isEmpty, j.vivant else { return [] }
        var lignes: [String] = []
        var restantes: [Entreprise] = []
        for ancienne in etat.actives {
            var e = ancienne
            guard let type = EntrepriseCatalogue.type(e.typeId) else {
                restantes.append(e)
                continue
            }
            var faillite = false
            // Crise de l'an dernier restée sans réponse
            if let c = e.crise {
                e.crise = nil
                let issue = EntrepriseCatalogue.evenement(c.evenementId)?.ignore
                    ?? EntrepriseIssue(chance: 1, text: "Tu as fait l'autruche. Les clients, eux, ont tout vu.",
                                       business: EntrepriseEffets(reputation: -5), effects: nil)
                let r = appliquerIssueEntreprise(issue, &e, type, employeId: c.employeId, &j)
                lignes.append("🙈 \(e.nom) : tu n'as rien décidé. \(r.texte)")
                faillite = r.faillite
            }
            if !faillite {
                faillite = !bilanAnnuelEntreprise(&e, type, &j, &lignes)
            }
            if faillite {
                lignes.append(fermerEnFaillite(e, type, &etat, &j))
            } else {
                restantes.append(e)
            }
        }
        etat.actives = restantes
        j.entreprises = etat
        j.stats.borner()
        return lignes
    }

    /// Calcule l'année d'une boîte. Renvoie false si elle fait faillite.
    private func bilanAnnuelEntreprise(_ e: inout Entreprise, _ type: EntrepriseType, _ j: inout Joueur, _ lignes: inout [String]) -> Bool {
        // Proches décédés : leur poste se libère.
        let relations = j.relations
        let disparus = e.employes.filter { emp in
            guard let rid = emp.relationId else { return false }
            return !(relations.first { $0.id == rid }?.vivant ?? false)
        }
        for m in disparus {
            lignes.append("🕯️ \(m.prenom) ne viendra plus travailler chez \(e.nom). Son poste de \(m.poste.lowercased()) est vide.")
        }
        let idsDisparus = Set(disparus.map { $0.id })
        e.employes.removeAll { idsDisparus.contains($0.id) }

        guard let eco = EntrepriseCatalogue.eco(type.id) else { return true }
        let patronDisponible = j.emploi == nil && j.etudes == nil
        EntrepriseMoteur.normaliser(&e, eco, patronDisponible: patronDisponible)
        let lev = EntrepriseSimulation.effetsLeviers(e, eco)
        var faits: [String] = []

        // L'année : demande, capacité, ventes, coûts
        let v = max(0, min(0.9, type.volatilite))
        let alea = 1 + Double.random(in: -v...v)
        var r = EntrepriseSimulation.annee(e, eco, patronDisponible: patronDisponible, alea: alea, age: j.age)
        let precedent = e.rapport
        if e.dette > 0 {
            let rembourse = min(e.dette, max(1, e.detteInitiale / EntrepriseMoteur.dureeEmprunt))
            e.dette -= rembourse
        }
        e.tresorerie += r.resultat
        r.tresorerie = e.tresorerie
        e.historique.append(EntrepriseBilan(age: j.age, chiffreAffaires: r.chiffreAffaires, resultat: r.resultat))
        if e.historique.count > 15 { e.historique.removeFirst(e.historique.count - 15) }
        e.annees += 1
        if alea > 1 + v * 0.6 { faits.append("📈 Année faste sur le marché : les clients se sont rués sur les \(eco.vente.pluriel).") }
        if alea < 1 - v * 0.6 { faits.append("📉 Le marché s'est effondré cette année. Ce n'est pas ta faute. Enfin, pas que.") }

        // Réputation, élan, moral
        let cibleRep = EntrepriseSimulation.cibleReputation(e, r)
        e.reputation = Stats.borne(e.reputation + (cibleRep - e.reputation) * 3 / 10 + (lev.reputation ?? 0) + Int.random(in: -2...2))
        e.elan = e.elan * 7 / 10
        let cibleMoral = EntrepriseSimulation.cibleMoral(e, r, lev)
        e.moral = Stats.borne(e.moral + (cibleMoral - e.moral) * 4 / 10 + Int.random(in: -3...3))
        if r.capacite > 0 && Double(r.demande) > Double(r.capacite) * 1.1 {
            faits.append("😩 L'équipe est débordée : \(r.clientsRefuses) clients sont repartis sans rien.")
        }
        if e.moral < 30 && e.effectif > 0 {
            let partis = max(1, Int(Double(e.effectif) * Double.random(in: 0.1...0.25)))
            e.effectif -= min(partis, e.effectif)
            faits.append("🚪 Moral au plus bas : \(partis) employé\(partis > 1 ? "s ont" : " a") démissionné.")
        }
        if let k = lev.karma, k != 0 { j.stats.karma += k }

        // La concurrence bouge
        let avant = e.pression
        e.pression = min(1.35, max(0.75, e.pression * Double.random(in: 0.93...1.08)))
        if e.pression > avant * 1.05 {
            faits.append("🥊 \(e.concurrent) a cassé ses prix et ouvert à côté de chez toi.")
        } else if e.pression < avant * 0.95 {
            faits.append("😌 \(e.concurrent) traverse une mauvaise passe. Tes clients reviennent.")
        }

        // Cadres nommés
        for i in e.employes.indices {
            e.employes[i].annees += 1
            e.employes[i].competence = Stats.borne(e.employes[i].competence + Int.random(in: 0...3))
            e.employes[i].motivation = Stats.borne(e.employes[i].motivation + Int.random(in: -7...3) + (e.moral - 50) / 20)
        }
        let demissions = e.employes.filter { $0.motivation < 15 && Double.random(in: 0...1) < 0.5 }
        for d in demissions {
            faits.append("🚪 \(d.prenom) a démissionné en laissant un mot : « Bisous, débrouille-toi. »")
        }
        let idsDemissions = Set(demissions.map { $0.id })
        e.employes.removeAll { idsDemissions.contains($0.id) }

        // Le patron qui fait tout lui-même
        let manquants = EntrepriseSimulation.postesCadresManquants(e)
        if manquants > 0 {
            j.stats.bonheur -= 2 * manquants
            j.stats.sante -= manquants / 2
        }

        // Rapport
        r.reputation = e.reputation
        r.moral = e.moral
        r.effectif = e.effectif
        r.faits = faits
        r.conseils = EntrepriseSimulation.conseils(e, eco, r, patronDisponible: patronDisponible)
        e.rapport = r
        e.rapportNonLu = true

        let icone = r.resultat >= 0 ? "🏪" : "📉"
        var ligne = "\(icone) \(e.nom) : \(r.ventes) \(r.ventes > 1 ? eco.vente.pluriel : eco.vente.nom), chiffre d'affaires \(Format.argent(r.chiffreAffaires)), résultat \(r.resultat >= 0 ? "+" : "")\(Format.argent(r.resultat))"
        if let p = precedent, p.chiffreAffaires > 0 {
            let evo = Int((Double(r.chiffreAffaires) / Double(p.chiffreAffaires) - 1) * 100)
            ligne += " (\(evo >= 0 ? "+" : "")\(evo) %)"
        }
        lignes.append(ligne + ", trésorerie \(Format.argent(e.tresorerie)).")

        // Faillite ?
        if e.tresorerie < EntrepriseMoteur.seuilFaillite(e, type) {
            e.anneesDansLeRouge += 1
            if e.anneesDansLeRouge >= 2 { return false }
            lignes.append("⚠️ \(e.nom) est dans le rouge vif. Renfloue la caisse, sinon elle ne passera pas l'année prochaine.")
        } else {
            e.anneesDansLeRouge = 0
        }

        // Candidats et offre de rachat de l'année
        e.candidats = EntrepriseMoteur.candidats(e, type)
        if Double.random(in: 0...1) < 0.6 {
            let offre = Int(Double(EntrepriseMoteur.valeur(e, type)) * Double.random(in: 0.7...1.3))
            e.offreRachat = offre > 0 ? offre : nil
        } else {
            e.offreRachat = nil
        }

        // Crise ou opportunité de l'année
        let risqueLeviers = 1 + Double(lev.risque ?? 0) / 100
        if Double.random(in: 0...1) < min(0.9, 0.5 * type.risque * risqueLeviers) {
            let patronAbsent = j.emploi != nil
            let possibles = EntrepriseCatalogue.evenements.filter { EntrepriseMoteur.eligible($0, e, type, patronAbsent: patronAbsent) }
            if let ev = EntrepriseMoteur.tirage(possibles, poids: { $0.weight ?? 1 }) {
                var emp: EntrepriseEmploye? = nil
                if let quel = ev.conditions?.employe { emp = EntrepriseMoteur.employeCible(quel, e) }
                let texte = remplir(EntrepriseMoteur.remplir(ev.text, e, type, employe: emp), j)
                e.crise = EntrepriseCrise(evenementId: ev.id, employeId: emp?.id, texte: texte)
                if ev.unique == true { e.evenementsVus.append(ev.id) }
                lignes.append("\(Self.iconeEvenementEntreprise(ev.kind)) \(e.nom) : \(texte) (à décider dans Entreprises)")
            }
        }
        return true
    }

    nonisolated static func iconeEvenementEntreprise(_ kind: String?) -> String {
        switch kind ?? "crise" {
        case "opportunite": return "✨"
        case "equipe": return "👥"
        case "absurde": return "🌀"
        default: return "🚨"
        }
    }

    // MARK: - Outils internes

    private func enregistrerJoueur(_ j: Joueur) {
        var j = j
        j.stats.borner()
        joueur = j
        sauvegarder()
    }

    /// Paie d'abord avec la trésorerie, puis avec l'argent du joueur.
    private func payer(_ montant: Int, _ e: inout Entreprise, _ j: inout Joueur) -> Bool {
        guard montant > 0 else { return true }
        let dispoBoite = max(0, e.tresorerie)
        if dispoBoite + max(0, j.argent) < montant { return false }
        let deLaBoite = min(dispoBoite, montant)
        e.tresorerie -= deLaBoite
        j.argent -= montant - deLaBoite
        return true
    }

    /// Ce que le joueur peut dépenser pour une boîte (trésorerie positive + son argent).
    func budgetEntreprise(_ e: Entreprise) -> Int {
        max(0, e.tresorerie) + max(0, joueur?.argent ?? 0)
    }

    /// Nom du niveau actuel, variables remplies.
    func nomDuNiveau(_ e: Entreprise) -> String {
        guard let type = EntrepriseCatalogue.type(e.typeId), let j = joueur else { return "" }
        return remplir(EntrepriseMoteur.remplir(type.nomNiveau(e.niveau), e, type, employe: nil), j)
    }

    /// Libellé d'un choix de crise, variables remplies.
    func libelleChoixEntreprise(_ label: String, _ e: Entreprise) -> String {
        guard let type = EntrepriseCatalogue.type(e.typeId), let j = joueur else { return label }
        let emp = e.crise?.employeId.flatMap { id in e.employes.first { $0.id == id } }
        return remplir(EntrepriseMoteur.remplir(label, e, type, employe: emp), j)
    }

    private func appliquerIssueEntreprise(_ issue: EntrepriseIssue, _ e: inout Entreprise, _ type: EntrepriseType,
                                          employeId: UUID?, _ j: inout Joueur) -> (texte: String, faillite: Bool) {
        let employe = employeId.flatMap { id in e.employes.first { $0.id == id } }
        let texte = remplir(EntrepriseMoteur.remplir(issue.text, e, type, employe: employe), j)
        var faillite = false
        if let b = issue.business {
            e.tresorerie += EntrepriseMoteur.aEchelle(b.cash, e)
            j.argent += EntrepriseMoteur.aEchelle(b.argentJoueur, e)
            let nouvelleDette = EntrepriseMoteur.aEchelle(b.dette, e)
            if nouvelleDette != 0 {
                e.dette = max(0, e.dette + nouvelleDette)
                e.detteInitiale = max(e.detteInitiale, e.dette)
            }
            e.reputation = Stats.borne(e.reputation + (b.reputation ?? 0))
            e.elan = min(100, max(-50, e.elan + (b.elan ?? 0)))
            if let m = b.moral {
                for i in e.employes.indices { e.employes[i].motivation = Stats.borne(e.employes[i].motivation + m) }
            }
            if let id = employe?.id, let k = e.employes.firstIndex(where: { $0.id == id }) {
                e.employes[k].motivation = Stats.borne(e.employes[k].motivation + (b.employeMoral ?? 0))
                e.employes[k].competence = Stats.borne(e.employes[k].competence + (b.employeCompetence ?? 0))
                if let lien = b.lienEmploye, let rid = e.employes[k].relationId,
                   let ri = j.relations.firstIndex(where: { $0.id == rid }) {
                    j.relations[ri].lien = Stats.borne(j.relations[ri].lien + lien)
                }
                if b.employePart == true { e.employes.remove(at: k) }
            }
            if let n = b.niveau, n != 0 {
                // Un niveau de plus ou de moins = le nombre de points de vente du niveau visé.
                let vise = min(EntrepriseMoteur.niveauMax, max(0, e.niveau + n))
                let seuil = EntrepriseMoteur.seuilsSites[vise]
                e.sites = n > 0 ? max(e.sites, seuil) : max(1, min(e.sites, seuil))
                e.niveau = EntrepriseMoteur.niveauPourSites(e.sites)
                e.niveauMax = max(e.niveauMax, e.niveau)
            }
            faillite = b.faillite == true
        }
        if let eff = issue.effects { appliquer(eff, &j) }
        return (texte, faillite)
    }

    private func fermerEnFaillite(_ e: Entreprise, _ type: EntrepriseType, _ etat: inout EntreprisesEtat, _ j: inout Joueur) -> String {
        let trou = min(0, e.tresorerie) - e.dette
        let perte = trou / 2
        j.argent += perte
        j.stats.bonheur -= 20
        for emp in e.employes {
            if let rid = emp.relationId, let ri = j.relations.firstIndex(where: { $0.id == rid }) {
                j.relations[ri].lien = Stats.borne(j.relations[ri].lien - 10)
            }
        }
        etat.archives.append(EntrepriseArchive(nom: e.nom, typeId: e.typeId, ageDebut: e.ageCreation, ageFin: j.age,
                                               fin: "faillite", montant: perte, niveauMax: e.niveauMax))
        etat.signaux.append("entreprise_faillite")
        let chute = [
            "Le liquidateur a même emporté la plante verte.",
            "Ton enseigne a été rachetée par \(e.concurrent), qui l'a accrochée à l'envers pour se moquer.",
            "Tes anciens clients organisent une minute de silence. Elle dure trois secondes.",
            "Tu gardes un mug avec le logo. C'est tout ce qu'il reste.",
        ].randomElement()!
        return "💥 « \(e.nom) » fait faillite. "
            + (perte < 0 ? "Ta caution personnelle te coûte \(Format.argent(-perte)). " : "")
            + chute
    }

    /// Modifie une boîte du joueur et sauvegarde.
    private func agirSurEntreprise(_ id: UUID,
                                   _ action: (inout Entreprise, EntrepriseType, inout Joueur, inout [String]) -> String) -> String {
        guard var j = joueur, j.vivant, var etat = j.entreprises,
              let k = etat.actives.firstIndex(where: { $0.id == id }),
              let type = EntrepriseCatalogue.type(etat.actives[k].typeId) else { return "" }
        var e = etat.actives[k]
        var signaux: [String] = []
        let message = action(&e, type, &j, &signaux)
        etat.actives[k] = e
        etat.signaux += signaux
        j.entreprises = etat
        enregistrerJoueur(j)
        return message
    }

    // MARK: - Création

    func creerEntreprise(_ type: EntrepriseType, nom: String, emprunt: Bool) -> String {
        guard var j = joueur else { return "" }
        if let blocage = EntrepriseMoteur.blocageCreation(type, j) { return blocage }
        let propre = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        let nomFinal = propre.isEmpty ? (type.nomsSuggeres.randomElement() ?? type.nom) : String(propre.prefix(40))
        let apport = emprunt ? Int(Double(type.coutCreation) * EntrepriseMoteur.apportMinimum) : type.coutCreation
        let dette = type.coutCreation - apport
        if j.argent < apport { return "Il te faut \(Format.argent(apport)). Tu as \(Format.argent(j.argent))." }
        j.argent -= apport
        var e = Entreprise(typeId: type.id, nom: nomFinal, ageCreation: j.age, dette: dette, detteInitiale: dette,
                           concurrent: EntrepriseCatalogue.concurrents.randomElement()!)
        if let eco = EntrepriseCatalogue.eco(type.id) {
            EntrepriseMoteur.normaliser(&e, eco, patronDisponible: j.emploi == nil && j.etudes == nil)
        }
        e.candidats = EntrepriseMoteur.candidats(e, type)
        var etat = j.entreprises ?? EntreprisesEtat()
        etat.actives.append(e)
        etat.signaux.append("entreprise_creee")
        j.entreprises = etat
        j.stats.bonheur += 8
        let texte = "🚀 Tu as fondé « \(nomFinal) » (\(type.nom.lowercased())) pour \(Format.argent(type.coutCreation))"
            + (dette > 0 ? ", dont \(Format.argent(dette)) empruntés à la banque" : "") + ". "
            + remplir(EntrepriseMoteur.phrasesCreation.randomElement()!, j)
        ajouterLigne(&j, texte)
        enregistrerJoueur(j)
        return texte
    }

    // MARK: - Crise

    func resoudreCriseEntreprise(_ id: UUID, choix index: Int) -> String {
        guard var j = joueur, j.vivant, var etat = j.entreprises,
              let k = etat.actives.firstIndex(where: { $0.id == id }) else { return "" }
        var e = etat.actives[k]
        guard let c = e.crise, let ev = EntrepriseCatalogue.evenement(c.evenementId),
              ev.choices.indices.contains(index), let type = EntrepriseCatalogue.type(e.typeId) else { return "" }
        let choix = ev.choices[index]
        if let cout = choix.cost, cout > 0 {
            let montant = EntrepriseMoteur.aEchelle(cout, e)
            if !payer(montant, &e, &j) { return "Il faut \(Format.argent(montant)) pour ça. Ni la caisse ni ton compte ne les ont." }
        }
        let label = libelleChoixEntreprise(choix.label, e)
        e.crise = nil
        guard let issue = EntrepriseMoteur.tirage(choix.outcomes, poids: { $0.chance ?? 1 }) else { return "" }
        let r = appliquerIssueEntreprise(issue, &e, type, employeId: c.employeId, &j)
        ajouterLigne(&j, "\(e.nom) : \(c.texte) → \(label). \(r.texte)")
        var message = r.texte
        if r.faillite {
            etat.actives.remove(at: k)
            let fin = fermerEnFaillite(e, type, &etat, &j)
            ajouterLigne(&j, fin)
            message += "\n\n" + fin
        } else {
            etat.actives[k] = e
        }
        j.entreprises = etat
        enregistrerJoueur(j)
        return message
    }

    // MARK: - Gestion

    func faireDeLaPub(_ id: UUID) -> String {
        agirSurEntreprise(id) { e, type, j, _ in
            let cle = "ent_pub_" + e.id.uuidString
            if j.actionsAnnee.contains(cle) { return "Une campagne par an, sinon les gens saturent." }
            let cout = EntrepriseMoteur.coutPub(e, type)
            guard payer(cout, &e, &j) else { return "La campagne coûte \(Format.argent(cout)). Tu ne les as pas." }
            j.actionsAnnee.append(cle)
            let rep = Int.random(in: 2...12)
            let gain = Int.random(in: 8...25)
            e.reputation = Stats.borne(e.reputation + rep)
            e.elan = min(100, e.elan + gain)
            return EntrepriseMoteur.phrasesPub.randomElement()! + " (\(Format.argent(cout)), +\(rep) réputation, +\(gain) % d'élan)"
        }
    }

    func travaillerDansSaBoite(_ id: UUID) -> String {
        agirSurEntreprise(id) { e, _, j, _ in
            let cle = "ent_bosse_" + e.id.uuidString
            if j.actionsAnnee.contains(cle) { return "Tu as déjà donné ton corps à \(e.nom) cette année." }
            j.actionsAnnee.append(cle)
            j.stats.sante -= 3
            j.stats.bonheur -= 3
            e.elan = min(100, e.elan + 10)
            e.reputation = Stats.borne(e.reputation + 2)
            for i in e.employes.indices { e.employes[i].motivation = Stats.borne(e.employes[i].motivation + 5) }
            return EntrepriseMoteur.phrasesTravail.randomElement()! + " (+10 % d'élan, −3 santé)"
        }
    }

    /// Le joueur se verse une part de la trésorerie (une fois par an), 20 % d'impôts.
    func verserDividende(_ id: UUID, part: Double) -> String {
        agirSurEntreprise(id) { e, _, j, _ in
            let cle = "ent_div_" + e.id.uuidString
            if j.actionsAnnee.contains(cle) { return "Tu t'es déjà " + j.g("servi", "servie") + " cette année. Le fisc te regarde." }
            guard e.tresorerie > 0 else { return "La caisse est vide. Tu as secoué le tiroir : une pièce de 20 centimes et un trombone." }
            let brut = Int(Double(e.tresorerie) * min(1, max(0, part)))
            guard brut > 0 else { return "" }
            let net = Int(Double(brut) * 0.8)
            e.tresorerie -= brut
            e.dividendes += net
            j.argent += net
            j.stats.bonheur += 3
            j.actionsAnnee.append(cle)
            return "Tu te verses \(Format.argent(net)) après impôts. Le fisc garde \(Format.argent(brut - net)) et t'envoie un petit cœur."
        }
    }

    func injecterArgent(_ id: UUID, montant: Int) -> String {
        agirSurEntreprise(id) { e, _, j, _ in
            guard montant > 0 else { return "" }
            guard j.argent >= montant else { return "Tu n'as pas \(Format.argent(montant)) sur ton compte." }
            j.argent -= montant
            e.tresorerie += montant
            return "Tu remets \(Format.argent(montant)) dans \(e.nom). Ton conseiller bancaire soupire très fort."
        }
    }

    // MARK: - Pilotage (gestion poussée)

    /// Met le niveau à jour après un changement du nombre de points de vente. Renvoie une phrase si le niveau change.
    private func majNiveauEntreprise(_ e: inout Entreprise, _ type: EntrepriseType, _ j: inout Joueur, _ signaux: inout [String]) -> String? {
        let avant = e.niveau
        e.niveau = EntrepriseMoteur.niveauPourSites(e.sites)
        let nouveauRecord = e.niveau > e.niveauMax
        e.niveauMax = max(e.niveauMax, e.niveau)
        guard e.niveau != avant else { return nil }
        e.candidats = EntrepriseMoteur.candidats(e, type)
        let nomNiveau = remplir(EntrepriseMoteur.remplir(type.nomNiveau(e.niveau), e, type, employe: nil), j)
        if e.niveau < avant { return "📉 \(e.nom) redevient : \(nomNiveau)." }
        let texte: String
        if e.niveau == EntrepriseMoteur.niveauMax {
            if nouveauRecord {
                signaux.append("entreprise_empire")
                j.stats.bonheur += 25
            }
            texte = "👑 \(e.nom), c'est maintenant : \(nomNiveau). Tu es officiellement " + j.g("un magnat", "une magnate")
                + ". Les gens baissent les yeux quand tu entres dans une boulangerie."
        } else {
            if nouveauRecord {
                signaux.append("entreprise_agrandie")
                j.stats.bonheur += 8
            }
            texte = "📈 \(e.nom) devient : \(nomNiveau). Il faudra \(EntrepriseMoteur.postes(e)) cadres aux postes clés."
        }
        ajouterLigne(&j, texte)
        return texte
    }

    func ouvrirSites(_ id: UUID, nombre: Int) -> String {
        agirSurEntreprise(id) { e, type, j, signaux in
            guard let eco = EntrepriseCatalogue.eco(type.id), nombre > 0 else { return "" }
            let n = min(nombre, EntrepriseMoteur.maxSites - e.sites)
            guard n > 0 else { return "Tu as déjà \(e.sites) \(eco.site.pluriel). Même les dictateurs s'arrêtent à un moment." }
            let cout = eco.coutSite * n
            guard payer(cout, &e, &j) else { return "Il faut \(Format.argent(cout)) (trésorerie et ton argent compris)." }
            e.sites += n
            var texte = "Et de \(e.sites) \(e.sites > 1 ? eco.site.pluriel : eco.site.nom) ! Ouverture : \(Format.argent(cout))."
            texte += " Pense à embaucher : il faut du monde pour les faire tourner."
            if let niveau = majNiveauEntreprise(&e, type, &j, &signaux) { texte += "\n\n" + niveau }
            return texte
        }
    }

    func fermerSites(_ id: UUID, nombre: Int) -> String {
        agirSurEntreprise(id) { e, type, j, signaux in
            guard let eco = EntrepriseCatalogue.eco(type.id), nombre > 0 else { return "" }
            let n = min(nombre, e.sites - 1)
            guard n > 0 else { return "C'est ton dernier \(eco.site.nom). Pour tout fermer, va dans « Et après ? »." }
            let rendu = Int(Double(eco.coutSite * n) * 0.3)
            e.sites -= n
            e.tresorerie += rendu
            e.moral = Stats.borne(e.moral - 5)
            var texte = "Tu fermes \(n) \(n > 1 ? eco.site.pluriel : eco.site.nom) et récupères \(Format.argent(rendu)) en revendant les meubles."
            if let niveau = majNiveauEntreprise(&e, type, &j, &signaux) { texte += "\n\n" + niveau }
            return texte
        }
    }

    func ouvrirUsines(_ id: UUID, nombre: Int) -> String {
        agirSurEntreprise(id) { e, type, j, _ in
            guard let eco = EntrepriseCatalogue.eco(type.id), let u = eco.usine, nombre > 0 else { return "" }
            let cout = eco.coutUsine * nombre
            guard payer(cout, &e, &j) else { return "Il faut \(Format.argent(cout)) (trésorerie et ton argent compris)." }
            e.usines = max(0, e.usines) + nombre
            return "Tu construis \(nombre) \(nombre > 1 ? u.pluriel : u.nom) pour \(Format.argent(cout)). Les voisins adorent le bruit."
        }
    }

    func fermerUsines(_ id: UUID, nombre: Int) -> String {
        agirSurEntreprise(id) { e, type, _, _ in
            guard let eco = EntrepriseCatalogue.eco(type.id), let u = eco.usine, nombre > 0 else { return "" }
            let n = min(nombre, max(0, e.usines) - 1)
            guard n > 0 else { return "Sans \(u.nom), tu n'aurais plus rien à vendre." }
            let rendu = Int(Double(eco.coutUsine * n) * 0.3)
            e.usines -= n
            e.tresorerie += rendu
            e.moral = Stats.borne(e.moral - 8)
            return "Tu fermes \(n) \(n > 1 ? u.pluriel : u.nom) et récupères \(Format.argent(rendu)). La presse locale parle de toi, et pas en bien."
        }
    }

    /// Embauche (delta > 0) ou licencie (delta < 0) du personnel.
    func changerEffectif(_ id: UUID, delta: Int) -> String {
        agirSurEntreprise(id) { e, type, j, _ in
            guard delta != 0 else { return "" }
            let salaire = Double(type.salaireEmploye) * e.salaireNiveau
            if delta > 0 {
                let cout = Int(salaire * 0.1 * Double(delta))
                guard payer(cout, &e, &j) else { return "Recruter coûte \(Format.argent(cout)) (annonces, entretiens, café). Tu ne les as pas." }
                e.effectif = max(0, e.effectif) + delta
                return "Tu embauches \(delta) personne\(delta > 1 ? "s" : ""). Recrutement : \(Format.argent(cout)). L'équipe compte maintenant \(e.effectif) employés."
            }
            let n = min(-delta, max(0, e.effectif))
            guard n > 0 else { return "Il n'y a plus personne à licencier. À part toi." }
            let indemnites = Int(salaire * 0.25 * Double(n))
            e.tresorerie -= indemnites
            e.effectif -= n
            e.moral = Stats.borne(e.moral - min(25, 3 + n * 40 / max(1, e.effectif + n)))
            if n >= 5 { j.stats.karma -= 2 }
            return "Tu licencies \(n) personne\(n > 1 ? "s" : ""). Indemnités : \(Format.argent(indemnites)). Ceux qui restent font semblant de ne pas avoir peur."
        }
    }

    /// Met l'effectif au niveau conseillé pour la demande prévue.
    func ajusterEffectif(_ id: UUID) -> String {
        guard let j = joueur, let e = j.entreprises?.actives.first(where: { $0.id == id }),
              let eco = EntrepriseCatalogue.eco(e.typeId) else { return "" }
        let cible = EntrepriseSimulation.effectifConseille(e, eco, patronDisponible: j.emploi == nil && j.etudes == nil)
        let delta = cible - max(0, e.effectif)
        if delta == 0 { return "L'effectif est déjà parfait. Tu peux te remettre à ne rien faire." }
        return changerEffectif(id, delta: delta)
    }

    func reglerPrix(_ id: UUID, _ prix: Double) -> String {
        agirSurEntreprise(id) { e, _, _, _ in
            e.prix = min(2, max(0.6, prix))
            return ""
        }
    }

    func reglerQualite(_ id: UUID, _ qualite: Int) -> String {
        agirSurEntreprise(id) { e, _, _, _ in
            e.qualite = min(5, max(1, qualite))
            return ""
        }
    }

    func reglerMarketing(_ id: UUID, _ pourcent: Int) -> String {
        agirSurEntreprise(id) { e, _, _, _ in
            e.marketing = min(30, max(0, pourcent))
            return ""
        }
    }

    func reglerSalaires(_ id: UUID, _ niveau: Double) -> String {
        agirSurEntreprise(id) { e, _, _, _ in
            let avant = e.salaireNiveau
            e.salaireNiveau = min(1.4, max(0.8, niveau))
            if e.salaireNiveau < avant { e.moral = Stats.borne(e.moral - 10) }
            if e.salaireNiveau > avant { e.moral = Stats.borne(e.moral + 5) }
            return ""
        }
    }

    func activerLevier(_ id: UUID, levier: String) -> String {
        agirSurEntreprise(id) { e, type, j, _ in
            guard let eco = EntrepriseCatalogue.eco(type.id), let l = eco.levier(levier) else { return "" }
            if e.leviers.contains(levier) { return "C'est déjà en place." }
            if e.niveau < (l.niveauMin ?? 0) { return "Ta boîte est encore trop petite pour ça." }
            let cout = (l.coutInstallation ?? 0) * (l.parSite == true ? e.sites : 1)
            guard payer(cout, &e, &j) else { return "Il faut \(Format.argent(cout)) pour mettre ça en place." }
            if let g = l.groupe {
                e.leviers.removeAll { autre in eco.levier(autre)?.groupe == g }
            }
            e.leviers.append(levier)
            let phrase = l.activation.map { remplir(EntrepriseMoteur.remplir($0, e, type, employe: nil), j) } ?? "C'est en place."
            return phrase + (cout > 0 ? " (\(Format.argent(cout)))" : "")
        }
    }

    func desactiverLevier(_ id: UUID, levier: String) -> String {
        agirSurEntreprise(id) { e, type, _, _ in
            e.leviers.removeAll { $0 == levier }
            let nom = EntrepriseCatalogue.eco(type.id)?.levier(levier)?.nom ?? "Ce levier"
            return "« \(nom) » est arrêté. L'argent déjà dépensé, lui, ne revient pas."
        }
    }

    /// Estimation de l'année prochaine avec les réglages actuels (sans hasard).
    func estimationEntreprise(_ e: Entreprise) -> EntrepriseRapport? {
        guard let j = joueur, let eco = EntrepriseCatalogue.eco(e.typeId) else { return nil }
        let patron = j.emploi == nil && j.etudes == nil
        var copie = e
        EntrepriseMoteur.normaliser(&copie, eco, patronDisponible: patron)
        return EntrepriseSimulation.annee(copie, eco, patronDisponible: patron, age: j.age + 1)
    }

    func effectifConseilleEntreprise(_ e: Entreprise) -> Int {
        guard let j = joueur, let eco = EntrepriseCatalogue.eco(e.typeId) else { return 0 }
        var copie = e
        let patron = j.emploi == nil && j.etudes == nil
        EntrepriseMoteur.normaliser(&copie, eco, patronDisponible: patron)
        return EntrepriseSimulation.effectifConseille(copie, eco, patronDisponible: patron)
    }

    /// Complète les champs des boîtes venues d'anciennes sauvegardes (à appeler à l'ouverture de l'écran).
    func normaliserEntreprises() {
        guard var j = joueur, var etat = j.entreprises else { return }
        let patron = j.emploi == nil && j.etudes == nil
        var change = false
        for i in etat.actives.indices {
            guard let eco = EntrepriseCatalogue.eco(etat.actives[i].typeId) else { continue }
            let avant = etat.actives[i]
            EntrepriseMoteur.normaliser(&etat.actives[i], eco, patronDisponible: patron)
            if etat.actives[i] != avant { change = true }
        }
        guard change else { return }
        j.entreprises = etat
        enregistrerJoueur(j)
    }

    /// Boîtes dont le rapport annuel n'a pas encore été montré.
    var entreprisesAvecRapportNonLu: [Entreprise] {
        joueur?.entreprises?.actives.filter { $0.rapportNonLu && $0.rapport != nil } ?? []
    }

    func marquerRapportsEntreprisesLus() {
        guard var j = joueur, var etat = j.entreprises else { return }
        guard etat.actives.contains(where: { $0.rapportNonLu }) else { return }
        for i in etat.actives.indices { etat.actives[i].rapportNonLu = false }
        j.entreprises = etat
        enregistrerJoueur(j)
    }

    func rembourserDetteEntreprise(_ id: UUID) -> String {
        agirSurEntreprise(id) { e, _, j, _ in
            guard e.dette > 0 else { return "\(e.nom) ne doit rien à personne. Profite, c'est rare." }
            let montant = e.dette
            guard payer(montant, &e, &j) else { return "Il faut \(Format.argent(montant)) pour solder le prêt." }
            e.dette = 0
            e.detteInitiale = 0
            return "Tu as remboursé la banque d'un coup. Ton banquier a perdu son sourire et un peu de sa raison de vivre."
        }
    }

    func renommerEntreprise(_ id: UUID, nom: String) -> String {
        agirSurEntreprise(id) { e, _, _, _ in
            let propre = nom.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !propre.isEmpty else { return "Un nom vide ? Même pour une startup, c'est trop conceptuel." }
            let ancien = e.nom
            e.nom = String(propre.prefix(40))
            e.reputation = Stats.borne(e.reputation - 3)
            return "« \(ancien) » s'appelle maintenant « \(e.nom) ». Les clients sont un peu perdus."
        }
    }

    // MARK: - Équipe

    func embaucherCandidat(_ id: UUID, candidat: UUID) -> String {
        agirSurEntreprise(id) { e, type, _, _ in
            guard e.employes.count < EntrepriseMoteur.postes(e) else { return "Tous les postes clés sont pris. Agrandis la boîte ou vire quelqu'un." }
            guard var c = e.candidats.first(where: { $0.id == candidat }) else { return "" }
            e.candidats.removeAll { $0.id == candidat }
            c.poste = EntrepriseMoteur.posteLibre(e, type)
            e.employes.append(c)
            let chute = [
                "Son CV mentionnait « maîtrise d'Excel ». On verra.",
                "Pendant l'entretien, " + (c.genre == .femme ? "elle" : "il") + " t'a demandé à quelle heure était la pause.",
                "Ses références viennent toutes de sa grand-mère.",
                "Premier jour : " + (c.genre == .femme ? "elle" : "il") + " a déjà renommé le wifi.",
            ].randomElement()!
            return "\(c.prenom) rejoint \(e.nom) comme \(c.poste.lowercased()). \(chute)"
        }
    }

    func embaucherProche(_ id: UUID, relation: UUID) -> String {
        agirSurEntreprise(id) { e, type, j, _ in
            guard e.employes.count < EntrepriseMoteur.postes(e) else { return "Tous les postes clés sont pris. Agrandis la boîte ou vire quelqu'un." }
            guard let ri = j.relations.firstIndex(where: { $0.id == relation }) else { return "" }
            let r = j.relations[ri]
            if r.lien < 25 && Double.random(in: 0...1) < 0.6 {
                return "\(r.prenom) a refusé. Travailler pour toi serait, cite, « au-dessus de mes forces »."
            }
            let emp = EntrepriseMoteur.employeDepuisProche(r, type, poste: EntrepriseMoteur.posteLibre(e, type))
            e.employes.append(emp)
            j.relations[ri].lien = Stats.borne(j.relations[ri].lien + 8)
            return "\(r.designation), \(r.prenom), devient \(emp.poste.lowercased()) chez \(e.nom). Les repas de famille vont ressembler à des réunions."
        }
    }

    func licencierEmploye(_ id: UUID, employe: UUID) -> String {
        agirSurEntreprise(id) { e, _, j, signaux in
            guard let emp = e.employes.first(where: { $0.id == employe }) else { return "" }
            e.employes.removeAll { $0.id == employe }
            for i in e.employes.indices { e.employes[i].motivation = Stats.borne(e.employes[i].motivation - 3) }
            if let rid = emp.relationId, let ri = j.relations.firstIndex(where: { $0.id == rid }) {
                let r = j.relations[ri]
                j.relations[ri].lien = Stats.borne(r.lien - 35)
                j.stats.karma -= 3
                j.stats.bonheur -= 5
                signaux.append("proche_licencie")
                switch r.type {
                case .mere, .pere:
                    return "Tu as viré " + (r.type == .mere ? "ta propre mère" : "ton propre père")
                        + ". " + (r.type == .mere ? "Elle" : "Il") + " te rappelle que t'élever, c'était aussi sans préavis."
                case .partenaire:
                    return "Tu as viré \(r.prenom), qui partage ton lit. Ce soir, tu dors sur le canapé. Peut-être cette année."
                case .frere, .soeur:
                    return "Tu as viré \(r.prenom). Tes parents ont appris la nouvelle avant toi, et ils ont choisi leur camp."
                case .enfant:
                    return "Tu as viré ton propre enfant, \(r.prenom). C'est sûrement très formateur. Pour qui, on ne sait pas."
                default:
                    return "Tu as viré \(r.prenom). Le groupe WhatsApp des amis est devenu très silencieux."
                }
            }
            j.stats.karma -= 1
            return "Tu as viré \(emp.prenom). " + (emp.genre == .femme ? "Elle" : "Il") + " est " + (emp.genre == .femme ? "partie" : "parti") + " avec l'agrafeuse. C'était sa vengeance."
        }
    }

    func augmenterEmploye(_ id: UUID, employe: UUID) -> String {
        agirSurEntreprise(id) { e, _, j, _ in
            guard let k = e.employes.firstIndex(where: { $0.id == employe }) else { return "" }
            let cle = "ent_aug_" + employe.uuidString
            if j.actionsAnnee.contains(cle) { return "\(e.employes[k].prenom) a déjà eu son augmentation cette année. Pas d'abus." }
            j.actionsAnnee.append(cle)
            e.employes[k].salaire = Int(Double(e.employes[k].salaire) * 1.1)
            e.employes[k].motivation = Stats.borne(e.employes[k].motivation + 15)
            if let rid = e.employes[k].relationId, let ri = j.relations.firstIndex(where: { $0.id == rid }) {
                j.relations[ri].lien = Stats.borne(j.relations[ri].lien + 5)
            }
            return "\(e.employes[k].prenom) passe à \(Format.argent(e.employes[k].salaire))/an. Sa motivation remonte en flèche."
        }
    }

    // MARK: - Fin d'une boîte

    func vendreEntreprise(_ id: UUID) -> String {
        guard var j = joueur, j.vivant, var etat = j.entreprises,
              let k = etat.actives.firstIndex(where: { $0.id == id }) else { return "" }
        guard let offre = etat.actives[k].offreRachat, offre > 0 else {
            return "Personne ne veut l'acheter pour l'instant. Même pour un euro symbolique."
        }
        let e = etat.actives.remove(at: k)
        j.argent += offre
        j.stats.bonheur += 12
        etat.archives.append(EntrepriseArchive(nom: e.nom, typeId: e.typeId, ageDebut: e.ageCreation, ageFin: j.age,
                                               fin: "vendue", montant: offre, niveauMax: e.niveauMax))
        etat.signaux.append("entreprise_vendue")
        j.entreprises = etat
        let texte = "🤝 Tu as vendu « \(e.nom) » pour \(Format.argent(offre)). Le repreneur a déjà changé le logo. Il est moche."
        ajouterLigne(&j, texte)
        enregistrerJoueur(j)
        return texte
    }

    /// Ferme la boîte : à l'amiable si elle peut payer ses dettes, sinon faillite.
    func fermerEntreprise(_ id: UUID) -> String {
        guard var j = joueur, j.vivant, var etat = j.entreprises,
              let k = etat.actives.firstIndex(where: { $0.id == id }),
              let type = EntrepriseCatalogue.type(etat.actives[k].typeId) else { return "" }
        let e = etat.actives.remove(at: k)
        let texte: String
        let net = e.tresorerie - e.dette
        if net >= 0 {
            j.argent += net
            j.stats.bonheur -= 5
            etat.archives.append(EntrepriseArchive(nom: e.nom, typeId: e.typeId, ageDebut: e.ageCreation, ageFin: j.age,
                                                   fin: "fermee", montant: net, niveauMax: e.niveauMax))
            etat.signaux.append("entreprise_fermee")
            texte = "🔒 Tu as fermé « \(e.nom) » proprement et récupéré \(Format.argent(net)). Il reste une odeur de \(type.produit) dans la rue."
        } else {
            texte = fermerEnFaillite(e, type, &etat, &j)
        }
        j.entreprises = etat
        ajouterLigne(&j, texte)
        enregistrerJoueur(j)
        return texte
    }
}

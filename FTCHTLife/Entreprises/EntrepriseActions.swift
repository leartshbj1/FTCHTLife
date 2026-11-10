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

        // Chiffre d'affaires
        let base = Double(type.chiffreAffairesBase) * e.echelle
        let v = max(0, min(0.9, type.volatilite))
        let marche = 1 + Double.random(in: -v...v)
        let image = 0.5 + Double(e.reputation) / 100
        var equipe = 1.0
        for emp in e.employes {
            equipe += Double(emp.competence - 50) / 400 + Double(emp.motivation - 50) / 800
        }
        let manquants = max(0, EntrepriseMoteur.postes(e) - e.employes.count)
        equipe = max(0.4, equipe - 0.08 * Double(manquants))
        let elan = max(0.3, 1 + Double(e.elan) / 100)
        let absent = (j.emploi != nil || j.etudes != nil) ? 0.85 : 1.0
        let ca = max(0, Int(base * marche * image * equipe * elan * absent))

        // Charges, salaires au-dessus (ou en dessous) du salaire normal, banque
        let charges = EntrepriseMoteur.charges(e, type)
        let surcout = e.employes.reduce(0) { $0 + ($1.salaire - type.salaireEmploye) }
        var banque = 0
        if e.dette > 0 {
            let interets = Int(Double(e.dette) * EntrepriseMoteur.tauxInteret)
            let rembourse = min(e.dette, max(1, e.detteInitiale / EntrepriseMoteur.dureeEmprunt))
            e.dette -= rembourse
            banque = interets + rembourse
        }
        let resultat = ca - charges - surcout - banque
        e.tresorerie += resultat
        e.historique.append(EntrepriseBilan(age: j.age, chiffreAffaires: ca, resultat: resultat))
        if e.historique.count > 12 { e.historique.removeFirst(e.historique.count - 12) }
        e.annees += 1

        // Réputation qui revient doucement vers la moyenne, élan qui s'estompe
        e.reputation = Stats.borne(e.reputation + (50 - e.reputation) / 10 + Int.random(in: -2...2))
        e.elan = e.elan * 7 / 10

        // Équipe
        for i in e.employes.indices {
            e.employes[i].annees += 1
            e.employes[i].competence = Stats.borne(e.employes[i].competence + Int.random(in: 0...3))
            e.employes[i].motivation = Stats.borne(e.employes[i].motivation + Int.random(in: -7...3))
        }
        let demissions = e.employes.filter { $0.motivation < 15 && Double.random(in: 0...1) < 0.5 }
        for d in demissions {
            lignes.append("🚪 \(d.prenom) a démissionné de \(e.nom) en laissant un mot : « Bisous, débrouille-toi. »")
        }
        let idsDemissions = Set(demissions.map { $0.id })
        e.employes.removeAll { idsDemissions.contains($0.id) }

        // Le patron qui fait tout lui-même
        if manquants > 0 {
            j.stats.bonheur -= 2 * manquants
            j.stats.sante -= manquants / 2
        }

        let icone = resultat >= 0 ? "🏪" : "📉"
        lignes.append("\(icone) \(e.nom) : chiffre d'affaires \(Format.argent(ca)), résultat \(resultat >= 0 ? "+" : "")\(Format.argent(resultat)), trésorerie \(Format.argent(e.tresorerie)).")

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
        if Double.random(in: 0...1) < min(0.9, 0.5 * type.risque) {
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

    static func iconeEvenementEntreprise(_ kind: String?) -> String {
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
                e.niveau = min(EntrepriseMoteur.niveauMax, max(0, e.niveau + n))
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

    func agrandirEntreprise(_ id: UUID) -> String {
        agirSurEntreprise(id) { e, type, j, signaux in
            guard let cout = EntrepriseMoteur.coutAgrandissement(e, type) else {
                return "\(e.nom) est déjà un empire. Il ne reste plus qu'à ouvrir une succursale sur la Lune."
            }
            let cle = "ent_agr_" + e.id.uuidString
            if j.actionsAnnee.contains(cle) { return "Un agrandissement par an. Laisse sécher la peinture." }
            guard payer(cout, &e, &j) else { return "Il faut \(Format.argent(cout)) (trésorerie et ton argent compris)." }
            j.actionsAnnee.append(cle)
            e.niveau += 1
            e.niveauMax = max(e.niveauMax, e.niveau)
            e.reputation = Stats.borne(e.reputation + 3)
            e.candidats = EntrepriseMoteur.candidats(e, type)
            let nomNiveau = remplir(EntrepriseMoteur.remplir(type.nomNiveau(e.niveau), e, type, employe: nil), j)
            let texte: String
            if e.niveau == EntrepriseMoteur.niveauMax {
                signaux.append("entreprise_empire")
                j.stats.bonheur += 25
                texte = "👑 \(e.nom), c'est maintenant : \(nomNiveau). Tu es officiellement " + j.g("un magnat", "une magnate")
                    + ". Les gens baissent les yeux quand tu entres dans une boulangerie."
            } else {
                signaux.append("entreprise_agrandie")
                j.stats.bonheur += 8
                texte = "📈 \(e.nom) grandit : \(nomNiveau). Il faudra \(EntrepriseMoteur.postes(e)) personnes aux postes clés."
            }
            ajouterLigne(&j, texte)
            return texte
        }
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

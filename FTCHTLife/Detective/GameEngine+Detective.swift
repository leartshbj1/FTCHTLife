import Foundation

// Branchement du module Agence de détective dans le moteur et actions du joueur. Voir docs/SECTE_DETECTIVE.md.

extension GameEngine {

    // MARK: - Passage d'année

    /// Appelé dans `modulesAnnee` : l'année de l'agence (enquêtes, honoraires, charges, nouvelles offres).
    func agenceAnnee(_ j: inout Joueur) -> [String] {
        guard var etat = j.agences, var a = etat.actuelle else { return [] }
        var lignes: [String] = []
        var signaux: [String] = []
        a.annees += 1
        a.actionsAnnee = []
        a.denouementActif = nil
        if let fin = a.suspenduJusqua, j.age >= fin {
            a.suspenduJusqua = nil
            lignes.append("📇 Ta carte professionnelle est rétablie. Tu peux reprendre des affaires.")
        }
        let enPrison = j.vieEtat.justice.enPrison
        var recettes = 0, resolues = 0, ratees = 0
        var restantes: [AgenceAffaire] = []

        for var af in a.affaires {
            guard let type = AgenceCatalogue.type(af.typeId) else { continue }
            let nomAffaire = type.nom.lowercased()
            if enPrison && af.enqueteurId == nil {
                ratees += 1
                a.reputation -= 4
                lignes.append("❌ \(type.nom) : ton client reprend son dossier. Un détective en prison, ça ne rassure personne.")
                signaux.append("agence_affaire_ratee")
                continue
            }
            let methode = af.methode ?? .terrain
            let enq = af.enqueteurId.flatMap { id in a.enqueteurs.first { $0.id == id } }
            let bonus = type.methodes?[methode.rawValue] ?? 1
            let points = methode.base * AgenceMoteur.efficacite(methode, enqueteur: enq, a, j) * bonus
                * (1 + Double(a.equipement) * 0.15) * Double.random(in: 0.7...1.3)
            af.progres += max(1, Int(points))
            af.annees += 1
            if !type.indices.isEmpty {
                let indice = remplir(AgenceMoteur.remplir(type.indices[(af.annees - 1) % type.indices.count], a, affaire: af), j)
                af.indices.append(indice)
                lignes.append("🔎 " + indice)
            }
            if enq == nil {
                for l in Competences.appliquer([methode.competence: 2], &j) { lignes.append(l) }
            }

            // Danger sur le terrain (pour le joueur seulement).
            if enq == nil && Double.random(in: 0...1) < type.danger + methode.danger {
                let blessure = Int.random(in: 8...25)
                j.stats.sante -= blessure
                let repere = j.genre == .femme ? "repérée" : "repéré"
                lignes.append(["🩹 Pendant l'affaire (" + nomAffaire + "), quelqu'un t'a " + repere + ". Tu t'en sors avec des points de suture.",
                               "🩹 Une planque qui tourne mal : coup de portière, chute dans un escalier. Tu boites pendant des semaines.",
                               "🩹 On t'attendait à la sortie d'un parking. Tu as compris le message, et ton arcade aussi."].randomElement()!)
                signaux.append("agence_blessure")
            }

            // Méthodes à la limite de la loi.
            if methode == .limite { signaux.append("agence_methode_limite") }
            if Double.random(in: 0...1) < methode.risqueLegal {
                a.plaintes += 1
                a.reputation -= 8
                signaux.append("agence_plainte")
                if !a.agrement && Double.random(in: 0...1) < 0.5 {
                    lignes.append("🚔 La cible a porté plainte. Pas de carte professionnelle, des micros dans un salon : le juge n'apprécie pas.")
                    for l in condamnerAgence("atteinte à la vie privée", mois: Int.random(in: 0...1) == 0 ? 0 : Int.random(in: 3...10), &j) { lignes.append(l) }
                } else if a.agrement && Double.random(in: 0...1) < 0.45 {
                    let ans = Int.random(in: 1...2)
                    a.suspenduJusqua = j.age + ans
                    lignes.append("📇 Plainte pour atteinte à la vie privée : ta carte professionnelle est suspendue \(ans) an\(ans > 1 ? "s" : "").")
                    signaux.append("agence_suspendue")
                } else {
                    lignes.append("⚠️ La cible a remarqué tes méthodes et porte plainte. L'affaire se règle à l'amiable, contre un chèque.")
                    j.argent -= 2_000 + a.reputation * 50
                }
            }

            if af.progres >= af.difficulte {
                // Affaire résolue.
                let reste = af.honoraires - Int(Double(af.honoraires) * AgenceMoteur.acompte)
                resolues += 1
                a.resolues += 1
                signaux.append("agence_affaire_resolue")
                if !type.denouements.isEmpty && a.denouements.isEmpty && Double.random(in: 0...1) < 0.8 {
                    a.denouements.append(AgenceDenouementEnAttente(typeId: type.id, index: Int.random(in: 0..<type.denouements.count),
                                                                    client: af.client, cible: af.cible, reste: reste))
                    lignes.append("✅ \(type.nom) : tu tiens la vérité. Reste à décider quoi en faire.")
                } else {
                    recettes += reste
                    a.reputation += 3 + af.difficulte / 30
                    lignes.append("✅ \(type.nom) : affaire résolue, rapport remis. Le client règle \(Format.argent(reste)).")
                }
                if let i = a.enqueteurs.firstIndex(where: { $0.id == af.enqueteurId }) {
                    a.enqueteurs[i].competence = min(100, a.enqueteurs[i].competence + 3)
                }
            } else if af.annees >= af.dureeMax {
                ratees += 1
                a.ratees += 1
                a.reputation -= 5
                signaux.append("agence_affaire_ratee")
                lignes.append("❌ \(type.nom) : le client perd patience et récupère son dossier. Tu gardes l'acompte, pas ta fierté.")
            } else {
                restantes.append(af)
            }
        }
        a.affaires = restantes

        // Charges et paie.
        let salaires = a.enqueteurs.reduce(0) { $0 + $1.salaire }
        let charges = AgenceMoteur.loyersBureau[a.bureau] + AgenceMoteur.entretienEquipement[a.equipement] + salaires
            + (a.agrement ? 900 : 0)
        j.argent = Shkurtaaa.argent(j.argent + recettes - charges)
        for i in a.enqueteurs.indices { a.enqueteurs[i].annees += 1 }
        if resolues == 0 && a.reputation > 10 { a.reputation -= 1 }
        a.reputation = Stats.borne(a.reputation)
        a.bilan = AgenceBilan(age: j.age, recettes: recettes, charges: charges, resolues: resolues, ratees: ratees)
        a.offres = enPrison ? [] : AgenceMoteur.offres(a)
        a.candidats = AgenceMoteur.candidats(a)
        lignes.insert("🕵️ \(a.nom) : \(resolues) affaire\(resolues > 1 ? "s" : "") résolue\(resolues > 1 ? "s" : ""), \(ratees) ratée\(ratees > 1 ? "s" : ""). Recettes \(Format.argent(recettes)), charges \(Format.argent(charges)).", at: 0)

        etat.actuelle = a
        j.agences = etat

        // Faillite : plus d'argent et des charges qu'on ne peut plus payer.
        if j.argent < -max(20_000, charges * 2) && !Shkurtaaa.actif {
            lignes.append(fermerAgence(&j, fin: "faillite"))
            signaux.append("agence_fermee")
            signaux.append("faillite")
        }
        for s in signaux { SignauxModules.signaler(s, &j) }
        return lignes
    }

    /// Appelé à la fin de `modulesAvantTirage` : au plus une carte de l'agence par an
    /// (le dénouement d'une affaire résolue, sinon parfois un événement de la vie de l'agence).
    func agenceAvantTirage() {
        guard var j = joueur, j.vivant, !j.vieEtat.justice.enPrison, var etat = j.agences, var a = etat.actuelle else { return }

        // Dénouements : un seul en carte, les autres se règlent sans histoire.
        if !a.denouements.isEmpty {
            let attente = a.denouements.removeFirst()
            for autre in a.denouements {
                j.argent = Shkurtaaa.argent(j.argent + autre.reste)
                a.reputation = Stats.borne(a.reputation + 3)
            }
            a.denouements = []
            if let type = AgenceCatalogue.type(attente.typeId), type.denouements.indices.contains(attente.index) {
                let d = type.denouements[attente.index]
                a.denouementActif = attente
                etat.actuelle = a
                j.agences = etat
                joueur = j
                let ev = AgenceMoteur.versEvenement(id: AgenceMoteur.prefixeDenouement + type.id + ":\(attente.index)", texte: d.text, choix: d.choices) {
                    AgenceMoteur.remplir($0, a, client: attente.client, cible: attente.cible, typeId: attente.typeId)
                }
                fileEvenements.append(EvenementAffiche(evenement: ev, texte: remplir(ev.text, j)))
                return
            }
            j.argent = Shkurtaaa.argent(j.argent + attente.reste)
        }

        guard Double.random(in: 0...1) < 0.6 else {
            etat.actuelle = a
            j.agences = etat
            joueur = j
            return
        }
        let affaire = a.affaires.randomElement()
        let enqueteur = a.enqueteurs.randomElement()
        let cartes = AgenceCatalogue.evenements.filter { AgenceMoteur.eligible($0, a, affaire: affaire, j) }
        guard let carte = GameEngine.tirage(cartes, poids: { $0.weight ?? 1 }) else {
            etat.actuelle = a
            j.agences = etat
            joueur = j
            return
        }
        if carte.unique == true { a.evenementsVus.append(carte.id) }
        a.affaireCibleId = affaire?.id
        a.enqueteurCibleId = enqueteur?.id
        etat.actuelle = a
        j.agences = etat
        joueur = j
        let ev = AgenceMoteur.versEvenement(id: AgenceMoteur.prefixe + carte.id, texte: carte.text, choix: carte.choices) {
            AgenceMoteur.remplir($0, a, affaire: affaire, enqueteur: enqueteur)
        }
        fileEvenements.append(EvenementAffiche(evenement: ev, texte: remplir(ev.text, j)))
    }

    /// Appelé dans `modulesApresChoix` : effets d'une carte sur l'agence.
    func agenceApresChoix(_ e: Evenement, choix index: Int, issue k: Int?, _ j: inout Joueur) {
        guard e.id.hasPrefix(AgenceMoteur.prefixe), var etat = j.agences, var a = etat.actuelle else { return }
        let liste: [AgenceChoix]
        var reste = 0
        var nomAffaire: String?
        let denouement = e.id.hasPrefix(AgenceMoteur.prefixeDenouement)
        if denouement {
            let parties = e.id.dropFirst(AgenceMoteur.prefixeDenouement.count).split(separator: ":")
            guard parties.count == 2, let type = AgenceCatalogue.type(String(parties[0])), let i = Int(parties[1]),
                  type.denouements.indices.contains(i) else { return }
            liste = type.denouements[i].choices
            nomAffaire = type.nom
            reste = a.denouementActif?.reste ?? 0
            a.denouementActif = nil
        } else {
            guard let def = AgenceCatalogue.evenement(String(e.id.dropFirst(AgenceMoteur.prefixe.count))) else { return }
            liste = def.choices
        }
        guard liste.indices.contains(index) else { return }
        let c = liste[index]
        if let cout = c.cost, cout > 0 { j.argent = Shkurtaaa.argent(j.argent - cout) }
        let fx: AgenceEffets? = k.flatMap { c.outcomes.indices.contains($0) ? c.outcomes[$0].agence : nil }
        var signaux: [String] = []

        // Paiement du client (dénouement) : tout par défaut.
        if denouement {
            let paye = Int(Double(reste) * (fx?.paiement ?? 1))
            j.argent = Shkurtaaa.argent(j.argent + paye)
            if paye > 0 { ajouterLigne(&j, "💶 Le client règle \(Format.argent(paye)).") } else if reste > 0 { ajouterLigne(&j, "💶 Le client ne paiera pas le solde.") }
            if fx?.reputation == nil { a.reputation += 2 }
        }
        if let fx {
            a.reputation += fx.reputation ?? 0
            if let b = fx.bonus, b != 0 { j.argent = Shkurtaaa.argent(j.argent + b) }
            if fx.plainte == true {
                a.plaintes += 1
                a.reputation -= 5
                if !signaux.contains("agence_plainte") { signaux.append("agence_plainte") }
                if a.agrement && fx.suspension == nil && Double.random(in: 0...1) < 0.35 {
                    a.suspenduJusqua = j.age + 1
                    ajouterLigne(&j, "📇 Après la plainte, ta carte professionnelle est suspendue un an.")
                    signaux.append("agence_suspendue")
                }
            }
            if let ans = fx.suspension, ans > 0 {
                a.suspenduJusqua = max(a.suspenduJusqua ?? 0, j.age + ans)
                a.offres = []
                signaux.append("agence_suspendue")
            }
            if fx.celebre == true {
                let nom = nomAffaire ?? nomCelebre(e)
                a.celebres.append(nom)
                a.reputation += 10
                signaux.append("agence_affaire_celebre")
            }
            if let id = a.enqueteurCibleId, let i = a.enqueteurs.firstIndex(where: { $0.id == id }) {
                if let d = fx.enqueteurCompetence { a.enqueteurs[i].competence = Stats.borne(a.enqueteurs[i].competence + d) }
                if fx.enqueteurPart == true {
                    let parti = a.enqueteurs.remove(at: i)
                    for k2 in a.affaires.indices where a.affaires[k2].enqueteurId == parti.id { a.affaires[k2].enqueteurId = nil }
                    ajouterLigne(&j, "\(parti.prenom) quitte l'agence.")
                }
            }
            if let s = fx.signal, !signaux.contains(s) { signaux.append(s) }
        }
        a.reputation = Stats.borne(a.reputation)
        etat.actuelle = a
        j.agences = etat

        if let mois = fx?.prisonMois {
            for l in condamnerAgence(fx?.infraction ?? "atteinte à la vie privée", mois: mois, &j) { ajouterLigne(&j, l) }
        }
        for s in signaux { SignauxModules.signaler(s, &j) }
    }

    private func nomCelebre(_ e: Evenement) -> String {
        let t = e.text
        return t.count > 60 ? String(t.prefix(57)) + "…" : t
    }

    func condamnerAgence(_ infraction: String, mois: Int, _ j: inout Joueur) -> [String] {
        // Même chemin que la secte : casier, puis prison si besoin.
        condamnerSecte(infraction, mois: mois, &j)
    }

    @discardableResult
    func fermerAgence(_ j: inout Joueur, fin: String) -> String {
        guard var etat = j.agences, let a = etat.actuelle else { return "" }
        etat.anciennes.append(AgenceArchive(nom: a.nom, ageDebut: a.ageOuverture, ageFin: j.age, resolues: a.resolues,
                                            celebres: a.celebres, fin: fin))
        etat.actuelle = nil
        j.agences = etat
        switch fin {
        case "faillite": return "🕵️ \(a.nom) met la clé sous la porte : plus de quoi payer le loyer ni les salaires."
        case "mort": return ""
        default: return "🕵️ Tu fermes \(a.nom) après \(a.annees) an\(a.annees > 1 ? "s" : "") et \(a.resolues) affaire\(a.resolues > 1 ? "s" : "") résolue\(a.resolues > 1 ? "s" : "")."
        }
    }

    // MARK: - Actions du joueur

    /// Ouvre l'agence. Renvoie un message d'erreur, ou nil si c'est fait.
    @discardableResult
    func ouvrirAgence(nom: String, agrement: Bool) -> String? {
        guard var j = joueur else { return "Aucune vie en cours." }
        if let raison = AgenceMoteur.blocageOuverture(j, agrement: agrement) { return raison }
        let propre = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !propre.isEmpty else { return "Il faut un nom sur la plaque." }
        let cout = AgenceMoteur.coutOuverture(j, agrement: agrement)
        j.argent = Shkurtaaa.argent(j.argent - cout)
        var etat = j.agences ?? AgencesEtat()
        var a = AgenceEtat(nom: propre, ageOuverture: j.age, agrement: agrement)
        a.offres = AgenceMoteur.offres(a)
        a.candidats = AgenceMoteur.candidats(a)
        etat.actuelle = a
        j.agences = etat
        ajouterLigne(&j, agrement
            ? "🕵️ Tu ouvres « \(propre) ». Carte professionnelle en poche, plaque vissée, premier client attendu."
            : "🕵️ Tu ouvres « \(propre) », sans carte professionnelle. Pas de plaque, juste un numéro qui circule.")
        SignauxModules.signaler("agence_ouverte", &j)
        joueur = j
        sauvegarder()
        return nil
    }

    /// Modifie l'agence du joueur et sauvegarde.
    private func modifierAgence(_ action: (inout AgenceEtat, inout Joueur) -> String) -> String {
        guard var j = joueur, var etat = j.agences, var a = etat.actuelle else { return "Tu n'as pas d'agence." }
        let message = action(&a, &j)
        a.reputation = Stats.borne(a.reputation)
        etat.actuelle = a
        j.agences = etat
        j.argent = Shkurtaaa.argent(j.argent)
        joueur = j
        sauvegarder()
        return message
    }

    func accepterAffaire(_ id: UUID) -> String {
        modifierAgence { a, j in
            guard let i = a.offres.firstIndex(where: { $0.id == id }) else { return "Cette offre n'existe plus." }
            if j.vieEtat.justice.enPrison { return "Tu es en prison." }
            if a.suspendue { return "Ta carte est suspendue : pas de nouvelle affaire pour l'instant." }
            guard a.affaires.count < AgenceMoteur.capacite(a) else {
                return "Tu as déjà \(a.affaires.count) affaires en cours. Recrute un enquêteur pour en prendre plus."
            }
            let af = a.offres.remove(at: i)
            let acompte = Int(Double(af.honoraires) * AgenceMoteur.acompte)
            j.argent += acompte
            a.affaires.append(af)
            let nom = AgenceCatalogue.type(af.typeId)?.nom.lowercased() ?? "affaire"
            let texte = "Tu acceptes l'affaire (\(nom)). Acompte encaissé : \(Format.argent(acompte))."
            self.ajouterLigne(&j, "📁 " + texte)
            return texte
        }
    }

    func refuserAffaire(_ id: UUID) {
        _ = modifierAgence { a, _ in
            a.offres.removeAll { $0.id == id }
            return ""
        }
    }

    func choisirMethode(_ affaireId: UUID, _ methode: AgenceMethode) {
        _ = modifierAgence { a, _ in
            if let i = a.affaires.firstIndex(where: { $0.id == affaireId }) { a.affaires[i].methode = methode }
            return ""
        }
    }

    func assignerAffaire(_ affaireId: UUID, enqueteur: UUID?) {
        _ = modifierAgence { a, _ in
            if let i = a.affaires.firstIndex(where: { $0.id == affaireId }) { a.affaires[i].enqueteurId = enqueteur }
            return ""
        }
    }

    func abandonnerAffaire(_ affaireId: UUID) -> String {
        modifierAgence { a, j in
            guard let i = a.affaires.firstIndex(where: { $0.id == affaireId }) else { return "" }
            let af = a.affaires.remove(at: i)
            a.reputation -= 4
            a.ratees += 1
            let texte = "Tu rends son dossier à ton client. Il repart avec un regard qui en dit long."
            self.ajouterLigne(&j, "📁 " + texte)
            _ = af
            return texte
        }
    }

    func embaucherEnqueteur(_ id: UUID) -> String {
        modifierAgence { a, j in
            guard let i = a.candidats.firstIndex(where: { $0.id == id }) else { return "Ce candidat a trouvé ailleurs." }
            guard a.enqueteurs.count < AgenceMoteur.maxEnqueteurs(a) else { return "Plus de place dans tes bureaux. Il faut plus grand." }
            let e = a.candidats.remove(at: i)
            a.enqueteurs.append(e)
            let texte = "\(e.prenom) \(e.nom) rejoint \(a.nom) (\(e.specialite.nom.lowercased()), \(Format.argent(e.salaire))/an)."
            self.ajouterLigne(&j, "🤝 " + texte)
            return texte
        }
    }

    func embaucherProche(_ r: Relation) -> String {
        modifierAgence { a, j in
            guard a.enqueteurs.count < AgenceMoteur.maxEnqueteurs(a) else { return "Plus de place dans tes bureaux." }
            guard !a.enqueteurs.contains(where: { $0.relationId == r.id }) else { return "\(r.prenom) travaille déjà avec toi." }
            let e = AgenceMoteur.depuisProche(r)
            a.enqueteurs.append(e)
            if let i = j.relations.firstIndex(where: { $0.id == r.id }) { j.relations[i].lien = Stats.borne(j.relations[i].lien + 5) }
            let texte = "\(r.designation), \(r.prenom), devient enquêteur pour \(a.nom). Les repas de famille vont ressembler à des interrogatoires."
            self.ajouterLigne(&j, "🤝 " + texte)
            return texte
        }
    }

    func licencierEnqueteur(_ id: UUID) -> String {
        modifierAgence { a, j in
            guard let i = a.enqueteurs.firstIndex(where: { $0.id == id }) else { return "" }
            let e = a.enqueteurs.remove(at: i)
            for k in a.affaires.indices where a.affaires[k].enqueteurId == id { a.affaires[k].enqueteurId = nil }
            if let rid = e.relationId, let r = j.relations.firstIndex(where: { $0.id == rid }) {
                j.relations[r].lien = Stats.borne(j.relations[r].lien - 20)
            }
            j.argent -= e.salaire / 4
            let texte = "Tu te sépares de \(e.prenom). Trois mois de salaire d'indemnités."
            self.ajouterLigne(&j, texte)
            return texte
        }
    }

    func ameliorerEquipement() -> String {
        modifierAgence { a, j in
            guard a.equipement < 3 else { return "Tu as déjà le meilleur matériel." }
            let cout = AgenceMoteur.coutsEquipement[a.equipement + 1]
            guard Shkurtaaa.peutPayer(cout, solde: j.argent) else { return "Il faut \(Format.argent(cout))." }
            j.argent -= cout
            a.equipement += 1
            let texte = "Nouveau matériel : \(AgenceMoteur.nomsEquipement[a.equipement].lowercased())."
            self.ajouterLigne(&j, "📷 " + texte)
            return texte
        }
    }

    func demenagerAgence(_ niveau: Int) -> String {
        modifierAgence { a, j in
            let n = min(3, max(0, niveau))
            guard n != a.bureau else { return "Tu y es déjà." }
            if n > a.bureau {
                let cout = AgenceMoteur.coutsBureau[n]
                guard Shkurtaaa.peutPayer(cout, solde: j.argent) else { return "L'installation coûte \(Format.argent(cout))." }
                j.argent -= cout
                a.reputation += 3 * (n - a.bureau)
            }
            a.bureau = n
            while a.enqueteurs.count > AgenceMoteur.maxEnqueteurs(a) {
                let e = a.enqueteurs.removeLast()
                for k in a.affaires.indices where a.affaires[k].enqueteurId == e.id { a.affaires[k].enqueteurId = nil }
            }
            let texte = "\(a.nom) s'installe : \(AgenceMoteur.nomsBureau[n].lowercased())."
            self.ajouterLigne(&j, "🏢 " + texte)
            return texte
        }
    }

    func publiciteAgence() -> String {
        modifierAgence { a, j in
            guard !a.actionsAnnee.contains("pub") else { return "Tu as déjà fait ta pub cette année." }
            let cout = 2_000 * (1 + a.bureau)
            guard Shkurtaaa.peutPayer(cout, solde: j.argent) else { return "Une campagne coûte \(Format.argent(cout))." }
            j.argent -= cout
            let gain = Int.random(in: 3...8)
            a.reputation += gain
            a.actionsAnnee.append("pub")
            let nouvelles = Array(AgenceMoteur.offres(a).prefix(2))
            a.offres.append(contentsOf: nouvelles)
            let texte = ["Encart dans la presse locale : « Discrétion, efficacité, résultats ».",
                         "Tu optimises ton site. Les avis clients sont élogieux (deux sont de ta mère).",
                         "Tu donnes une conférence au club des notaires. Trois cartes de visite échangées."].randomElement()! + " Réputation +\(gain)."
            self.ajouterLigne(&j, texte)
            return texte
        }
    }

    func demanderAgrement() -> String {
        guard let j = joueur, let a = j.agences?.actuelle else { return "Tu n'as pas d'agence." }
        guard !a.agrement else { return "Tu as déjà ta carte professionnelle." }
        var test = j
        test.agences = nil
        if let raison = AgenceMoteur.blocageOuverture(test, agrement: true) { return raison }
        return modifierAgence { a, j in
            let cout = AgenceMoteur.coutOuverture(j, agrement: true)
            j.argent -= cout
            a.agrement = true
            a.reputation += 5
            let texte = "Formation suivie, dossier accepté : \(a.nom) a enfin pignon sur rue, en toute légalité."
            self.ajouterLigne(&j, "📇 " + texte)
            return texte
        }
    }

    func fermerMonAgence() -> String {
        guard var j = joueur else { return "" }
        let ligne = fermerAgence(&j, fin: "fermee")
        ajouterLigne(&j, ligne)
        SignauxModules.signaler("agence_fermee", &j)
        joueur = j
        sauvegarder()
        return ligne
    }

    /// Les proches qu'on peut embaucher comme enquêteur.
    func agenceProchesEmbauchables() -> [Relation] {
        guard let j = joueur, let a = j.agences?.actuelle else { return [] }
        let deja = Set(a.enqueteurs.compactMap { $0.relationId })
        let types: [TypeRelation] = [.frere, .soeur, .ami, .partenaire, .enfant, .mere, .pere, .ex]
        return j.relations.filter { $0.vivant && types.contains($0.type) && $0.age >= 18 && $0.age <= 70 && !deja.contains($0.id) }
    }
}

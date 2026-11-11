import Foundation

// Branchement du module Jeu vivant dans le moteur. Voir docs/VIVANT.md, section « Branchement ».

extension GameEngine {

    func vivantTags(_ j: Joueur) -> Set<String> { JeuVivant.tags(j, phone: PhoneEngine.tags(j.telephone)) }

    /// Après l'écriture de l'année : compare la situation avec l'an passé et envoie les signaux
    /// (achats, élection, fortune, placements, expatriation, casier, célébrité, entreprise).
    /// Les suites rep_viv_ à délai 0 arrivent dans ce même passage d'année.
    func vivantApresAnnee(_ j: inout Joueur) {
        var etat = j.jeuVivant ?? JeuVivantEtat()
        let nouvelle = JeuVivant.photo(j, phone: PhoneEngine.tags(j.telephone))
        var signaux: [String] = []
        if let ancienne = etat.photo { signaux = JeuVivant.signaux(avant: ancienne, apres: nouvelle, j) }
        etat.photo = nouvelle
        j.jeuVivant = etat

        // Signaux mis en attente par le module Entreprises (entreprise_creee, entreprise_faillite…).
        if var ent = j.entreprises, !ent.signaux.isEmpty {
            for s in ent.signaux where !signaux.contains(s) {
                signaux.append(s)
                if s == "entreprise_faillite" && !signaux.contains("faillite") { signaux.append("faillite") }
            }
            ent.signaux = []
            j.entreprises = ent
        }
        for s in signaux { SignauxModules.signaler(s, &j) }
    }

    /// Fin de la préparation de l'année : étape du projet en cours, anniversaire, et au plus un moment « vivant ».
    func vivantAvantTirage() {
        guard var j = joueur, j.vivant else { return }
        var etat = j.jeuVivant ?? JeuVivantEtat()
        let t = tags(j)

        // 1. Projet en cours : coût de l'année, compétence, carte d'étape (en pause pendant la prison).
        var carteProjet: Evenement?
        if let enCours = etat.projet, let p = VivantBibliotheque.projet(enCours.id), j.age > enCours.ageDebut, !t.contains("prison") {
            if let cout = p.coutAnnuel, cout > 0 { j.argent = Shkurtaaa.argent(j.argent - cout) }
            if let comp = p.competence {
                for ligne in Competences.appliquer([comp: 1], &j) { ajouterLigne(&j, ligne) }
            }
            carteProjet = JeuVivant.carteEtape(p, etape: enCours.etape, j, tags: t)
        }

        // 2. Un seul moment « vivant » par an : on repousse les suites en trop d'un an.
        var garde = 0
        var restants: [EvenementAffiche] = []
        var rep = j.repercussions ?? RepercussionsEtat()
        for aff in fileEvenements {
            guard JeuVivant.estMoment(aff.evenement.id) else { restants.append(aff); continue }
            if garde < JeuVivant.maxMomentsParAn {
                garde += 1
                restants.append(aff)
            } else if aff.evenement.id.hasPrefix(JeuVivant.prefixeSuite) {
                rep.programmees.append(RepercussionProgrammee(id: aff.evenement.id, age: j.age + 1, ageMax: j.age + 2))
            }
        }
        j.repercussions = rep
        fileEvenements = restants

        // 3. Anniversaire de l'histoire du joueur : en carte s'il reste de la place, sinon une ligne du journal.
        if let anniv = JeuVivant.anniversaire(j, conditionsOK: { self.conditionsRemplies($0, j, tags: t) }) {
            etat = j.jeuVivant ?? etat
            etat.anniversairesVus.append(anniv.cle)
            j.jeuVivant = etat
            let place = Self.maxEvenementsAChoix - fileEvenements.count - (evenementEnCours == nil ? 0 : 1)
            if garde < JeuVivant.maxMomentsParAn && place > (carteProjet == nil ? 0 : 1) && !t.contains("prison") {
                joueur = j
                declencher(anniv.evenement)
                j = joueur ?? j
            } else if let ligne = anniv.ligne {
                ajouterLigne(&j, "🗓️ " + remplir(ligne, j))
            }
        }

        joueur = j
        if let carte = carteProjet {
            // Le projet du joueur passe avant les autres moments de l'année.
            fileEvenements.insert(EvenementAffiche(evenement: carte, texte: remplir(carte.text, j)), at: 0)
        }
    }

    /// Après un choix : progression du projet, sorties avec les biens.
    func vivantApresChoix(_ e: Evenement, choix index: Int, issue k: Int?, _ j: inout Joueur) {
        if e.id.hasPrefix(JeuVivant.prefixeBiens) {
            var etat = j.jeuVivant ?? JeuVivantEtat()
            for cle in ["bateau", "avion_prive"] where e.conditions?.tags?.contains(cle) == true
                || e.conditions?.tags?.contains(cle == "bateau" ? "bateau_oublie" : "avion_oublie") == true {
                etat.sorties[cle] = j.age
            }
            j.jeuVivant = etat
        }
        guard let carte = JeuVivant.lireCarte(e.id), var etat = j.jeuVivant, var enCours = etat.projet,
              let p = VivantBibliotheque.projet(enCours.id), carte.etape == enCours.etape,
              p.etapes.indices.contains(carte.etape), carte.choix.indices.contains(index) else { return }
        let donnees = p.etapes[carte.etape].choices
        let iChoix = carte.choix[index]
        guard donnees.indices.contains(iChoix) else { return }
        let issues = donnees[iChoix].outcomes
        let issue = k.flatMap { issues.indices.contains($0) ? issues[$0] : nil }

        if issue?.abandon == true {
            etat.projet = nil
            etat.projetsFinis.append(VivantProjetFini(id: p.id, ageFin: j.age, fin: "abandon"))
            j.jeuVivant = etat
            ajouterLigne(&j, "📕 " + remplir(p.abandon ?? "Tu abandonnes ton projet : \(p.nom.lowercased()).", j))
            SignauxModules.signaler("projet_abandon", &j)
            return
        }
        enCours.progres += issue?.progres ?? 0
        enCours.etape += 1
        guard enCours.etape >= p.etapes.count else {
            etat.projet = enCours
            j.jeuVivant = etat
            return
        }

        // Dernière étape : la fin du projet.
        let fin = JeuVivant.fin(p, progres: enCours.progres)
        let texte: VivantFinProjet
        switch fin {
        case "reussite": texte = p.fins.reussite
        case "moyen": texte = p.fins.moyen
        default: texte = p.fins.echec
        }
        etat.projet = nil
        etat.projetsFinis.append(VivantProjetFini(id: p.id, ageFin: j.age, fin: fin))
        j.jeuVivant = etat
        let emoji = fin == "reussite" ? "🏆 " : (fin == "moyen" ? "📘 " : "📕 ")
        ajouterLigne(&j, emoji + remplir(texte.text.replacingOccurrences(of: "{projet}", with: p.nom.lowercased()), j))
        if var eff = texte.effects {
            eff.setFlags = (eff.setFlags ?? []) + (texte.setFlags ?? [])
            appliquer(eff, &j)
        } else if let f = texte.setFlags {
            appliquer(Effets(setFlags: f), &j)
        }
        SignauxModules.signaler("projet_\(fin)", &j)
        SignauxModules.signaler("projet_\(p.id)_\(fin)", &j)
    }

    // MARK: - Actions du joueur

    func projetsDisponibles() -> [VivantProjet] {
        guard let j = joueur else { return [] }
        let t = tags(j)
        return JeuVivant.projetsDisponibles(j) { self.conditionsRemplies($0, j, tags: t) }
    }

    /// Lance un projet. Renvoie un message d'erreur, ou nil si c'est parti.
    @discardableResult
    func lancerProjet(_ p: VivantProjet) -> String? {
        guard var j = joueur, j.vivant else { return "Aucune vie en cours." }
        var etat = j.jeuVivant ?? JeuVivantEtat()
        if etat.projet != nil { return "Tu as déjà un projet en cours. Termine-le ou abandonne-le d'abord." }
        if j.vieEtat.justice.enPrison { return "Difficile de lancer un projet depuis une cellule." }
        let cout = p.cout ?? 0
        if cout > 0 && !Shkurtaaa.peutPayer(cout, solde: j.argent) { return "Il te faut \(Format.argent(cout)) pour te lancer." }
        j.argent = Shkurtaaa.argent(j.argent - cout)
        etat.projet = VivantProjetEnCours(id: p.id, ageDebut: j.age)
        j.jeuVivant = etat
        ajouterLigne(&j, (p.emoji.map { $0 + " " } ?? "") + "Tu te lances dans un projet : \(p.nom.lowercased()).")
        SignauxModules.signaler("projet_lance", &j)
        joueur = j
        sauvegarder()
        return nil
    }

    func abandonnerProjet() {
        guard var j = joueur, var etat = j.jeuVivant, let enCours = etat.projet else { return }
        let p = VivantBibliotheque.projet(enCours.id)
        etat.projet = nil
        etat.projetsFinis.append(VivantProjetFini(id: enCours.id, ageFin: j.age, fin: "abandon"))
        j.jeuVivant = etat
        j.stats.bonheur -= 4
        j.stats.borner()
        ajouterLigne(&j, "📕 " + remplir(p?.abandon ?? "Tu abandonnes ton projet.", j))
        SignauxModules.signaler("projet_abandon", &j)
        joueur = j
        sauvegarder()
    }
}

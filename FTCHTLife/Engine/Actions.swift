import Foundation

/// Une activité proposée dans l'onglet Activités.
struct Activite: Identifiable {
    let id: String
    let titre: String
    let icone: String
    let ageMin: Int
    let cout: Int
    let description: String
}

extension GameEngine {

    // MARK: - Activités

    static let activites: [Activite] = [
        Activite(id: "biblio", titre: "Bibliothèque", icone: "books.vertical.fill", ageMin: 6, cout: 0, description: "Lire des livres, ou dormir dessus."),
        Activite(id: "sport", titre: "Salle de sport", icone: "dumbbell.fill", ageMin: 13, cout: 0, description: "Soulever des trucs lourds pour rien."),
        Activite(id: "meditation", titre: "Méditation", icone: "leaf.fill", ageMin: 10, cout: 0, description: "Respirer très fort en silence."),
        Activite(id: "amis", titre: "Se faire des amis", icone: "person.2.fill", ageMin: 5, cout: 0, description: "Aller vers les gens. Courage."),
        Activite(id: "soiree", titre: "Faire la fête", icone: "party.popper.fill", ageMin: 16, cout: 50, description: "Musique forte, décisions douteuses."),
        Activite(id: "medecin", titre: "Médecin", icone: "cross.case.fill", ageMin: 0, cout: 200, description: "Se faire soigner (un peu)."),
        Activite(id: "vacances", titre: "Vacances", icone: "airplane", ageMin: 18, cout: 1500, description: "Une semaine au soleil."),
        Activite(id: "chirurgie", titre: "Chirurgie esthétique", icone: "wand.and.stars", ageMin: 18, cout: 6000, description: "Changer de visage. Ou pas."),
        Activite(id: "loterie", titre: "Loterie", icone: "ticket.fill", ageMin: 18, cout: 10, description: "Un billet, un rêve, aucune chance."),
        Activite(id: "casino", titre: "Casino", icone: "suit.spade.fill", ageMin: 18, cout: 500, description: "Miser 500 € à la roulette."),
    ]

    func activiteDisponible(_ a: Activite) -> Bool {
        guard let j = joueur, j.vivant else { return false }
        return j.age >= a.ageMin && !j.actionsAnnee.contains("act_" + a.id)
    }

    /// Fait l'activité et renvoie le texte du résultat.
    func faireActivite(_ a: Activite) -> String {
        guard var j = joueur, j.vivant else { return "" }
        if j.age < a.ageMin { return "Tu es trop jeune pour ça." }
        if j.actionsAnnee.contains("act_" + a.id) { return "Tu l'as déjà fait cette année. Calme-toi." }
        // Les parents paient pour les mineurs.
        let paye = j.age < 18 ? 0 : a.cout
        if paye > 0 && j.argent < paye { return "Tu n'as pas assez d'argent (\(Format.argent(paye)))." }
        j.argent -= paye
        j.actionsAnnee.append("act_" + a.id)

        var texte: String
        switch a.id {
        case "biblio":
            let g = Int.random(in: 1...5)
            j.stats.intelligence += g
            texte = ["Tu as lu un livre entier. Avec les pages et tout.",
                     "Tu as lu un dictionnaire. Tu connais maintenant le mot « zygomatique ».",
                     "Tu t'es " + j.g("endormi", "endormie") + " sur une encyclopédie. Ça compte, non ?"].randomElement()!
            texte += " (+\(g) intelligence)"
        case "sport":
            let s = Int.random(in: 2...6), ap = Int.random(in: 0...3)
            j.stats.sante += s
            j.stats.apparence += ap
            texte = ["Tu as couru sur un tapis pendant 40 minutes pour aller nulle part.",
                     "Tu as fait un selfie devant le miroir. Et un peu de sport aussi.",
                     "Un type énorme t'a regardé de travers. Tu as soulevé plus fort."].randomElement()!
            texte += " (+\(s) santé)"
        case "meditation":
            let b = Int.random(in: 3...8)
            j.stats.bonheur += b
            texte = "Tu as médité. Tu as surtout pensé à ce que tu allais manger. (+\(b) bonheur)"
        case "amis":
            if Double.random(in: 0...1) < 0.55 + Double(j.stats.apparence) / 400 {
                var eff = Effets()
                eff.newFriend = true
                eff.happiness = 5
                appliquer(eff, &j)
                texte = "Tu as abordé quelqu'un et ça s'est bien passé ! \(j.amis.last?.prenom ?? "") est maintenant " + (j.amis.last?.genre == .femme ? "ton amie." : "ton ami.")
            } else {
                j.stats.bonheur -= 3
                texte = ["Tu as dit « salut » et la personne a fait semblant d'être au téléphone.",
                         "Tu as raconté une blague. Personne n'a ri. Même pas toi."].randomElement()!
            }
        case "soiree":
            let r = Int.random(in: 0...9)
            if r < 5 {
                j.stats.bonheur += 8
                texte = "Soirée géniale ! Tu as dansé sur une table jusqu'à 4h du matin."
            } else if r < 8 {
                j.stats.bonheur += 3
                j.stats.sante -= 4
                texte = "Tu t'es " + j.g("réveillé", "réveillée") + " dans une baignoire avec une gueule de bois monumentale."
            } else {
                var eff = Effets()
                eff.newFriend = true
                eff.happiness = 6
                appliquer(eff, &j)
                texte = "Tu as rencontré quelqu'un de cool en faisant la queue aux toilettes."
            }
        case "medecin":
            let s = Int.random(in: 5...15)
            j.stats.sante += s
            texte = ["Le médecin t'a dit de boire de l'eau. 200 € le conseil.",
                     "Le médecin a pris ta tension, puis la sienne, par curiosité.",
                     "On t'a prescrit du repos. Et un sirop qui a goût de bougie."].randomElement()!
            texte += " (+\(s) santé)"
        case "vacances":
            let b = Int.random(in: 10...20)
            j.stats.bonheur += b
            texte = ["Tu es " + j.g("parti", "partie") + " en Grèce. Tu as pris un coup de soleil en forme de t-shirt.",
                     "Une semaine en Espagne. Tu as appris à dire « encore une sangria ».",
                     "Tu es " + j.g("allé", "allée") + " au Japon et tu as mangé un truc qui bougeait encore."].randomElement()!
            texte += " (+\(b) bonheur)"
        case "chirurgie":
            if Double.random(in: 0...1) < 0.8 {
                let ap = Int.random(in: 8...25)
                j.stats.apparence += ap
                texte = "L'opération est un succès. Ton miroir ne te reconnaît plus. (+\(ap) apparence)"
            } else {
                j.stats.apparence -= 20
                j.stats.bonheur -= 15
                texte = "Le chirurgien a éternué au mauvais moment. Tu ressembles maintenant à un poisson-lune. (-20 apparence)"
            }
        case "loterie":
            let r = Int.random(in: 1...10000)
            if r == 1 {
                j.argent += 2_000_000
                j.stats.bonheur += 50
                texte = "🤑 JACKPOT ! Tu as gagné 2'000'000 € ! Des cousins dont tu ignorais l'existence t'appellent déjà."
            } else if r <= 300 {
                j.argent += 100
                texte = "Tu as gagné 100 €. Tu as dépensé 10 € pour ça. Rentable !"
            } else {
                texte = ["Perdu. Le numéro gagnant était ta date de naissance, à un chiffre près.",
                         "Perdu. Comme prévu par absolument tout le monde."].randomElement()!
            }
        case "casino":
            if Double.random(in: 0...1) < 0.45 {
                j.argent += 1000
                j.stats.bonheur += 5
                texte = "Tu as misé sur le rouge… et c'est rouge ! Tu repars avec 1'000 €."
            } else {
                j.stats.bonheur -= 5
                texte = "Tu as misé sur le noir. C'était le zéro. Le croupier a souri un peu trop."
            }
        default:
            texte = "Il ne s'est rien passé."
        }
        j.stats.borner()
        ajouterLigne(&j, texte)
        joueur = j
        sauvegarder()
        return texte
    }

    // MARK: - École

    func etudierPlus() -> String {
        guard var j = joueur, !j.actionsAnnee.contains("etudier") else { return "Tu as déjà assez étudié cette année." }
        j.actionsAnnee.append("etudier")
        let g = Int.random(in: 2...6)
        j.stats.intelligence += g
        j.stats.bonheur -= 2
        let t = "Tu as révisé comme jamais. Ton cerveau fume légèrement. (+\(g) intelligence)"
        j.stats.borner()
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }

    func secherLesCours() -> String {
        guard var j = joueur, !j.actionsAnnee.contains("secher") else { return "Tu as déjà séché cette année. Ne pousse pas." }
        j.actionsAnnee.append("secher")
        j.stats.intelligence -= 3
        j.stats.bonheur += 5
        var t = "Tu as séché les cours pour aller au parc. Liberté !"
        if Double.random(in: 0...1) < 0.35 {
            t += " Mais ta mère t'a " + j.g("vu", "vue") + " depuis le bus."
            for i in j.relations.indices where j.relations[i].type.estParent {
                j.relations[i].lien = Stats.borne(j.relations[i].lien - 10)
            }
        }
        j.stats.borner()
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }

    func quitterEcole() -> String {
        guard var j = joueur else { return "" }
        guard j.age >= 16 else { return "Tu as moins de 16 ans. La loi dit non. Ta mère aussi." }
        j.aQuitteEcole = true
        if j.diplome < .ecoleObligatoire { j.diplome = .ecoleObligatoire }
        let t = "Tu as quitté l'école. Tes profs ont fait semblant d'être tristes."
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }

    // MARK: - Université

    func peutEntrerUniversite(_ f: Filiere) -> Bool {
        guard let j = joueur else { return false }
        return j.age >= 18 && j.diplome >= .bac && j.etudes == nil
    }

    func inscrireUniversite(_ f: Filiere) -> String {
        guard var j = joueur, peutEntrerUniversite(f) else { return "Impossible de t'inscrire." }
        if j.stats.intelligence < f.intelligenceMin {
            let t = "Ta candidature en \(f.nom.lowercased()) a été refusée. Ils ont gardé ta lettre pour rire en réunion."
            ajouterLigne(&j, t)
            joueur = j
            sauvegarder()
            return t
        }
        j.etudes = Etudes(filiere: f, annee: 1)
        j.emploi = nil
        let t = "Tu es " + j.g("admis", "admise") + " en \(f.nom.lowercased()) ! \(f.duree) ans d'études, \(Format.argent(f.fraisAnnuels)) par an. Tes parents paient pas, au fait."
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }

    func abandonnerEtudes() -> String {
        guard var j = joueur, let e = j.etudes else { return "" }
        j.etudes = nil
        j.stats.bonheur += 3
        let t = "Tu as abandonné tes études de \(e.filiere.nom.lowercased()). Tu vas devenir youtubeur, c'est sûr."
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }

    // MARK: - Travail

    func metiersAccessibles() -> [Metier] {
        Donnees.metiers
    }

    func conditionsRemplies(_ m: Metier) -> Bool {
        guard let j = joueur else { return false }
        if j.diplome < m.diplome { return false }
        if let f = m.filiere, j.filiereDiplome != f { return false }
        return true
    }

    func postuler(_ m: Metier) -> String {
        guard var j = joueur else { return "" }
        if j.age < 18 { return "Reviens quand tu seras majeur·e." }
        if j.etudes != nil { return "Tu es en études. Finis-les d'abord (ou abandonne)." }
        if let raison = empechementEmploi(j) { return raison }
        if !j.actionsAnnee.filter({ $0 == "postuler" }).isEmpty && j.actionsAnnee.filter({ $0 == "postuler" }).count >= 3 {
            return "Tu as déjà passé 3 entretiens cette année. Repose-toi."
        }
        j.actionsAnnee.append("postuler")
        guard conditionsRemplies(m) else {
            let t = "Refusé pour le poste de \(m.titre.lowercased()) : il faut \(m.diplome.nom.lowercased())\(m.filiere.map { " en " + $0.nom.lowercased() } ?? "")."
            joueur = j
            return t
        }
        var chance = 0.45
        chance += Double(j.stats.intelligence - m.intelligenceMin) / 150
        chance += Double(j.stats.apparence - 50) / 400
        if j.stats.intelligence < m.intelligenceMin { chance -= 0.35 }
        if j.stats.apparence < m.apparenceMin { chance -= 0.6 }
        let t: String
        if Double.random(in: 0...1) < max(0.05, min(0.92, chance)) {
            j.emploi = Emploi(metierId: m.id, titre: m.titre, salaire: m.salaire, annees: 0, performance: 50, niveau: 0)
            t = "🎉 Tu es " + j.g("embauché", "embauchée") + " comme \(m.titre.lowercased()) ! Salaire : \(Format.argent(m.salaire))/an."
            j.stats.bonheur += 10
        } else {
            t = [
                "Entretien raté pour le poste de \(m.titre.lowercased()). Tu as appelé le recruteur « maman ».",
                "Refusé·e. Le recruteur a dit que tu manquais « d'énergie positive ».",
                "Pas retenu·e. Ta poignée de main ressemblait à un poisson mort, paraît-il.",
            ].randomElement()!
            j.stats.bonheur -= 3
        }
        j.stats.borner()
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }

    func travaillerDur() -> String {
        guard var j = joueur, var e = j.emploi else { return "" }
        if j.actionsAnnee.contains("bosser") { return "Tu as déjà fait des heures sup cette année. Ton dos dit stop." }
        j.actionsAnnee.append("bosser")
        e.performance = Stats.borne(e.performance + Int.random(in: 8...18))
        j.emploi = e
        j.stats.bonheur -= 3
        j.stats.sante -= 1
        j.stats.borner()
        let t = "Tu as travaillé comme un·e acharné·e. Ton patron a remarqué. Ou pas."
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }

    func demanderAugmentation() -> String {
        guard var j = joueur, var e = j.emploi else { return "" }
        if j.actionsAnnee.contains("augmentation") { return "Tu as déjà demandé cette année. Ton patron t'évite dans les couloirs." }
        j.actionsAnnee.append("augmentation")
        let t: String
        if Double.random(in: 0...1) < Double(e.performance) / 160 {
            let hausse = Int(Double(e.salaire) * Double.random(in: 0.04...0.12))
            e.salaire += hausse
            t = "Augmentation accordée : +\(Format.argent(hausse))/an. Tu as gardé ton calme. À l'extérieur."
        } else {
            e.performance = Stats.borne(e.performance - 5)
            t = "Ton patron a ri. Longtemps. Puis il a dit non."
        }
        j.emploi = e
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }

    func demissionner() -> String {
        guard var j = joueur, let e = j.emploi else { return "" }
        j.emploi = nil
        j.stats.bonheur += 5
        let t = "Tu as démissionné de ton poste de \(e.titre.lowercased()). Tu as claqué la porte. Elle s'est rouverte toute seule."
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }

    // MARK: - Relations

    enum ActionRelation: String, CaseIterable, Identifiable {
        case temps, discuter, cadeau, argent, insulter
        var id: String { rawValue }
        var titre: String {
            switch self {
            case .temps: return "Passer du temps ensemble"
            case .discuter: return "Discuter"
            case .cadeau: return "Offrir un cadeau (100 €)"
            case .argent: return "Demander de l'argent"
            case .insulter: return "Insulter"
            }
        }
        var icone: String {
            switch self {
            case .temps: return "heart.fill"
            case .discuter: return "bubble.left.and.bubble.right.fill"
            case .cadeau: return "gift.fill"
            case .argent: return "banknote.fill"
            case .insulter: return "hand.thumbsdown.fill"
            }
        }
    }

    func actionsPossibles(_ r: Relation) -> [ActionRelation] {
        guard r.vivant else { return [] }
        var a: [ActionRelation] = [.temps, .discuter, .cadeau, .insulter]
        if r.type.estParent { a.insert(.argent, at: 3) }
        return a
    }

    func agir(_ action: ActionRelation, sur id: UUID) -> String {
        guard var j = joueur, let i = j.relations.firstIndex(where: { $0.id == id }) else { return "" }
        let r = j.relations[i]
        let cle = "rel_\(action.rawValue)_\(id.uuidString)"
        if j.actionsAnnee.contains(cle) { return "Tu l'as déjà fait cette année avec \(r.prenom)." }
        j.actionsAnnee.append(cle)
        var t: String
        switch action {
        case .temps:
            j.relations[i].lien = Stats.borne(r.lien + Int.random(in: 5...12))
            j.stats.bonheur += 3
            t = ["Tu as passé l'après-midi avec \(r.prenom) à regarder des vidéos de chats.",
                 "\(r.prenom) et toi êtes allés manger une fondue. Personne n'a perdu son pain.",
                 "Tu as fait une balade avec \(r.prenom). Vous avez parlé de la météo pendant deux heures."].randomElement()!
        case .discuter:
            j.relations[i].lien = Stats.borne(r.lien + Int.random(in: 1...6))
            t = ["Tu as discuté avec \(r.prenom) de la vie, de la mort et des prix de l'essence.",
                 "\(r.prenom) t'a raconté sa journée. Tu as hoché la tête au bon moment."].randomElement()!
        case .cadeau:
            if j.age >= 18 && j.argent < 100 { j.actionsAnnee.removeLast(); return "Tu n'as pas assez d'argent pour un cadeau." }
            if j.age >= 18 { j.argent -= 100 }
            j.relations[i].lien = Stats.borne(r.lien + Int.random(in: 6...15))
            t = ["Tu as offert des chaussettes à \(r.prenom). Iel a fait semblant d'adorer.",
                 "Tu as offert une plante à \(r.prenom). Elle sera morte dans deux semaines.",
                 "\(r.prenom) a adoré ton cadeau. Tu l'avais trouvé dans ton grenier."].randomElement()!
        case .argent:
            let chance = Double(r.lien) / 130
            if r.argent > 50 && Double.random(in: 0...1) < chance {
                let montant = min(r.argent, Int.random(in: 1...10) * (j.age < 18 ? 10 : 200))
                j.argent += montant
                j.relations[i].argent -= montant
                j.relations[i].lien = Stats.borne(r.lien - 3)
                t = "\(r.prenom) t'a donné \(Format.argent(montant)) en soupirant très fort."
            } else {
                j.relations[i].lien = Stats.borne(r.lien - 6)
                t = "\(r.prenom) a dit non et t'a parlé de « la valeur du travail » pendant 20 minutes."
            }
        case .insulter:
            j.relations[i].lien = Stats.borne(r.lien - Int.random(in: 10...20))
            j.stats.karma -= 3
            t = ["Tu as dit à \(r.prenom) qu'iel avait une tête de pied. Ambiance.",
                 "Tu as traité \(r.prenom) de « moule avariée ». C'est sorti tout seul.",
                 "Tu as dit à \(r.prenom) que sa cuisine avait le goût de carton mouillé."].randomElement()!
        }
        j.stats.borner()
        ajouterLigne(&j, t)
        joueur = j
        sauvegarder()
        return t
    }
}

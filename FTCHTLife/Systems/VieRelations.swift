import Foundation

/// Amour, mariage, enfants, amis, famille élargie.
enum VieRelations {

    // MARK: - Naissance

    /// À appeler une fois à la naissance : ajoute des grands-parents.
    static func naissance(_ j: inout Joueur) -> [String] {
        var v = j.vieEtat
        var lignes: [String] = []
        let nb = [0, 1, 2, 2, 3, 4].randomElement() ?? 2
        for _ in 0..<nb {
            let g: Genre = Bool.random() ? .homme : .femme
            let parent = j.parentsVivants.randomElement()
            let age = (parent?.age ?? 30) + Int.random(in: 20...34)
            let gp = VieProche(prenom: VieDonnees.prenom(g), nom: parent?.nom ?? j.nom, genre: g, role: .grandParent,
                               age: age, lien: Int.random(in: 50...95), argent: Int.random(in: 0...150_000))
            v.proches.append(gp)
        }
        if !v.grandsParents.isEmpty {
            let noms = v.grandsParents.map { "\($0.role.libelle($0.genre).lowercased()) \($0.prenom)" }.joined(separator: ", ")
            lignes.append("Côté grands-parents : \(noms). Prépare-toi aux bisous qui piquent.")
        }
        j.vieEtat = v
        return lignes
    }

    // MARK: - +1 an

    static func vieillir(_ j: inout Joueur) -> [String] {
        var lignes: [String] = []
        var v = j.vieEtat
        v.rendezVousAnnee = 0

        // Couple
        if let p = j.partenaireActuel {
            v.anneesEnsemble += 1
            j.vieEtat = v
            if p.lien < 15 && VieHasard.reussi(v.statutCouple == .marie ? 0.3 : 0.5) {
                lignes += rompre(&j, parLeJoueur: false)
            }
            v = j.vieEtat
        } else {
            v.anneesEnsemble = 0
            v.statutCouple = nil
        }

        // Grands-parents, petits-enfants, codétenus vieillissent
        for i in v.proches.indices where v.proches[i].vivant {
            v.proches[i].age += 1
            v.proches[i].lien = Stats.borne(v.proches[i].lien + Int.random(in: -3...1))
            let p = v.proches[i]
            if p.role == .grandParent && VieHasard.reussi(VieHasard.chanceDeces(age: p.age) + (p.age > 95 ? 0.3 : 0)) {
                v.proches[i].vivant = false
                lignes.append("💀 \(p.role.libelle(p.genre)) \(p.prenom) est \(p.genre == .femme ? "morte" : "mort") à \(p.age) ans. Il reste trois boîtes de biscuits rassis chez \(p.genre == .femme ? "elle" : "lui").")
                j.stats.bonheur -= 8
                if p.argent > 0 && VieHasard.reussi(0.5) {
                    let part = p.argent / 3
                    j.argent += part
                    lignes.append("Tu hérites de \(Format.argent(part)) et d'un service à thé que personne ne veut.")
                }
            }
        }

        // Grossesse → naissance
        if let mois = v.grossesse {
            j.vieEtat = v
            if mois <= 12 {
                lignes += naissanceBebe(&j)
            } else {
                var w = j.vieEtat
                w.grossesse = mois - 12
                j.vieEtat = w
            }
            v = j.vieEtat
        }

        // Petit frère / petite sœur quand on est petit
        if j.age < 14, j.parentsVivants.count == 2, VieHasard.reussi(0.06) {
            let g: Genre = Bool.random() ? .homme : .femme
            let bebe = Relation(prenom: VieDonnees.prenom(g), nom: j.nom, genre: g, type: g == .homme ? .frere : .soeur,
                                age: 0, lien: Int.random(in: 50...90))
            j.relations.append(bebe)
            lignes.append("Tes parents ont eu un bébé : \(g == .homme ? "un petit frère" : "une petite sœur"), \(bebe.prenom). Adieu ta tranquillité.")
        }

        // Les enfants mineurs coûtent cher
        let mineurs = j.enfantsVivants.filter { $0.age < 18 }.count
        if mineurs > 0 && j.age >= 18 && !v.justice.enPrison {
            let cout = mineurs * 2_400
            j.argent -= cout
            if VieHasard.reussi(0.15) {
                lignes.append("Tes enfants t'ont coûté \(Format.argent(cout)) cette année. Surtout en goûters.")
            }
        }

        // Petits-enfants
        for enfant in j.enfantsVivants where (24...45).contains(enfant.age) && VieHasard.reussi(0.07) {
            let g: Genre = Bool.random() ? .homme : .femme
            let pe = VieProche(prenom: VieDonnees.prenom(g), nom: enfant.genre == .homme ? enfant.nom : VieDonnees.nomFamille(),
                               genre: g, role: .petitEnfant, age: 0, lien: 75)
            v.proches.append(pe)
            lignes.append("\(enfant.prenom) a eu un bébé, \(pe.prenom) ! Tu es \(j.g("grand-père", "grand-mère")). Tu te sens vieux/vieille d'un coup.")
        }

        // Amis négligés qui s'éloignent
        j.vieEtat = v
        for ami in j.amis where ami.lien < 8 && VieHasard.reussi(0.4) {
            if let i = j.relations.firstIndex(where: { $0.id == ami.id }) {
                j.relations.remove(at: i)
                lignes.append("\(ami.prenom) et toi ne vous parlez plus. Vous vous likez encore, par politesse.")
            }
        }
        // Nouveaux amis à l'école
        if (6...22).contains(j.age), j.amis.count < 3, !v.justice.enPrison, VieHasard.reussi(0.25) {
            lignes.append(nouvelAmi(&j))
        }
        // L'humeur suit un peu les relations
        let liens = j.relations.filter { $0.vivant }.map(\.lien)
        if !liens.isEmpty {
            let moyenne = liens.reduce(0, +) / liens.count
            j.stats.bonheur += (moyenne - 50) / 20
        }
        return lignes
    }

    // MARK: - Actions sur une relation (en plus de celles du moteur)

    enum Action: String, CaseIterable, Identifiable {
        case complimenter, disputer, flirter, rendezVous, demanderEnMariage, seMarier, rompre, divorcer
        case bebe, meilleurAmi, finAmitie, reconcilier, voyageAmoureux, presenterParents

        var id: String { rawValue }

        var titre: String {
            switch self {
            case .complimenter: return "Faire un compliment"
            case .disputer: return "Se disputer"
            case .flirter: return "Flirter"
            case .rendezVous: return "Rendez-vous romantique (150 €)"
            case .demanderEnMariage: return "Demander en mariage (bague 2 500 €)"
            case .seMarier: return "Organiser le mariage (12 000 €)"
            case .rompre: return "Rompre"
            case .divorcer: return "Divorcer"
            case .bebe: return "Essayer d'avoir un bébé"
            case .meilleurAmi: return "Proposer d'être meilleurs amis"
            case .finAmitie: return "Mettre fin à l'amitié"
            case .reconcilier: return "Tenter de se réconcilier"
            case .voyageAmoureux: return "Week-end en amoureux (900 €)"
            case .presenterParents: return "Présenter à tes parents"
            }
        }

        var icone: String {
            switch self {
            case .complimenter: return "hand.thumbsup.fill"
            case .disputer: return "cloud.bolt.fill"
            case .flirter: return "heart.text.square.fill"
            case .rendezVous: return "wineglass.fill"
            case .demanderEnMariage: return "sparkles"
            case .seMarier: return "bell.fill"
            case .rompre: return "heart.slash.fill"
            case .divorcer: return "doc.text.fill"
            case .bebe: return "figure.and.child.holdinghands"
            case .meilleurAmi: return "star.fill"
            case .finAmitie: return "person.fill.xmark"
            case .reconcilier: return "hands.sparkles.fill"
            case .voyageAmoureux: return "airplane"
            case .presenterParents: return "house.fill"
            }
        }
    }

    static func actions(_ r: Relation, _ j: Joueur) -> [Action] {
        guard r.vivant, !j.vieEtat.justice.enPrison else { return [] }
        var a: [Action] = [.complimenter]
        if j.age >= 6 { a.append(.disputer) }
        let celibataire = j.partenaireActuel == nil
        let ageOk = j.age >= 14 && r.age >= 14 && abs(r.age - j.age) <= 15
        switch r.type {
        case .partenaire:
            a += [.rendezVous, .voyageAmoureux]
            switch j.vieEtat.statutCouple {
            case .marie: a.append(.divorcer)
            case .fiance: a += [.seMarier, .rompre]
            case nil: a += [.presenterParents, .rompre]; if j.age >= 18 { a.append(.demanderEnMariage) }
            }
            if j.age >= 18 && j.age <= 55 { a.append(.bebe) }
        case .ami:
            if j.vieEtat.meilleurAmiId != r.id { a.append(.meilleurAmi) }
            a.append(.finAmitie)
            if celibataire && ageOk { a.append(.flirter) }
        case .ex:
            a.append(.reconcilier)
        default:
            break
        }
        if r.type == .ex && celibataire && ageOk { a.append(.flirter) }
        return a
    }

    /// Fait l'action et renvoie le texte affiché (déjà ajouté au journal par l'appelant).
    static func agir(_ action: Action, sur id: UUID, _ j: inout Joueur) -> String {
        guard let i = j.relations.firstIndex(where: { $0.id == id }) else { return "" }
        let r = j.relations[i]
        let nom = r.prenom
        let cle = "vie_\(action.rawValue)_\(id.uuidString)"
        let unParAn: Set<Action> = [.complimenter, .disputer, .flirter, .meilleurAmi, .reconcilier, .presenterParents, .voyageAmoureux]
        if unParAn.contains(action) && j.actionsAnnee.contains(cle) { return "Tu l'as déjà fait cette année avec \(nom). Laisse respirer." }
        if unParAn.contains(action) { j.actionsAnnee.append(cle) }
        func lien(_ d: Int) { j.relations[i].lien = Stats.borne(j.relations[i].lien + d) }
        func paye(_ prix: Int) -> Bool {
            if j.age < 18 && prix <= 200 { return true }
            guard j.argent >= prix else { return false }
            j.argent -= prix
            return true
        }

        switch action {
        case .complimenter:
            if VieHasard.reussi(0.75) { lien(Int.random(in: 2...6)); return VieDonnees.replique("complimentGood", nom: nom, defaut: "\(nom) a rougi jusqu'aux oreilles.") }
            lien(-1); return VieDonnees.replique("complimentBad", nom: nom, defaut: "\(nom) se demande ce que tu veux en échange.")

        case .disputer:
            lien(-Int.random(in: 6...14)); j.stats.bonheur -= 3
            return VieDonnees.replique("argue", nom: nom, defaut: "Grosse dispute avec \(nom) sur la bonne façon de remplir le lave-vaisselle.")

        case .flirter:
            let chance = VieHasard.borne(0.2 + Double(j.stats.apparence) / 250 + Double(r.lien) / 400)
            if VieHasard.reussi(VieBonus.seduction(chance)) {
                j.relations[i].type = .partenaire
                j.relations[i].lien = max(r.lien, 60)
                var v = j.vieEtat; v.statutCouple = nil; v.anneesEnsemble = 0; j.vieEtat = v
                j.stats.bonheur += 8
                VieSysteme.signaler("couple", &j)
                return VieDonnees.replique("flirtGood", nom: nom, defaut: "\(nom) a craqué. Vous êtes ensemble !")
            }
            lien(-6); j.stats.bonheur -= 3
            return VieDonnees.replique("flirtBad", nom: nom, defaut: "\(nom) t'a répondu « t'es comme un frère pour moi ». Aïe.")

        case .rendezVous:
            guard paye(150) else { return "Pas les moyens d'un resto. Pique-nique sur un rond-point ?" }
            var v = j.vieEtat; v.rendezVousAnnee += 1; j.vieEtat = v
            if v.rendezVousAnnee > 3 && VieHasard.reussi(0.4) { lien(-2); return "\(nom) commence à trouver que vous passez votre vie au restaurant." }
            VieSysteme.signaler("rendez_vous", &j)
            if VieHasard.reussi(0.72) { lien(Int.random(in: 6...12)); j.stats.bonheur += 5; return VieDonnees.replique("dateGood", nom: nom, defaut: "Soirée parfaite avec \(nom).") }
            VieSysteme.signaler("rendez_vous_rate", &j)
            lien(-4); return VieDonnees.replique("dateBad", nom: nom, defaut: "Le serveur a renversé la soupe sur \(nom). Ambiance glaciale.")

        case .voyageAmoureux:
            guard paye(900) else { return "Il te faut 900 € pour le week-end. Camping dans le salon, alors ?" }
            if VieHasard.reussi(0.8) { lien(Int.random(in: 10...18)); j.stats.bonheur += 8; return ["Week-end à Venise avec \(nom). Vous avez pris 400 photos du même pont.", "Week-end à la mer avec \(nom). Coup de soleil en forme de cœur.", "Week-end à la montagne avec \(nom). Vous avez vu une marmotte, c'était le sommet du voyage."].auHasard("") }
            lien(-5); return "Week-end catastrophe avec \(nom) : valise perdue, hôtel en travaux et dispute dans le train."

        case .presenterParents:
            if VieHasard.reussi(0.65) { lien(8); return "Tes parents adorent \(nom). Ta mère a déjà sorti les photos de toi tout nu dans le bain." }
            lien(-4); return "Le repas avec tes parents était tendu. Ton père a demandé à \(nom) combien \(r.pronom) gagnait."

        case .demanderEnMariage:
            guard paye(2_500) else { return "La bague coûte 2 500 €. Une bague en capsule de bière, ça ne compte pas." }
            let annees = j.vieEtat.anneesEnsemble
            let chance = Double(r.lien) / 100 * (annees >= 2 ? 1 : (annees == 1 ? 0.7 : 0.35))
            if VieHasard.reussi(VieBonus.seduction(chance)) {
                var v = j.vieEtat; v.statutCouple = .fiance; j.vieEtat = v
                lien(10); j.stats.bonheur += 12
                VieSysteme.signaler("demande_mariage", &j)
                return VieDonnees.replique("proposalYes", nom: nom, defaut: "\(nom) a dit OUI ! Tu es \(j.g("fiancé", "fiancée")) !")
            }
            lien(-15); j.stats.bonheur -= 15
            j.argent += 1_000
            VieSysteme.signaler("demande_refusee", &j)
            return VieDonnees.replique("proposalNo", nom: nom, defaut: "\(nom) a dit non. Devant tout le restaurant.") + " Tu revends la bague 1 000 €."

        case .seMarier:
            guard paye(12_000) else { return "Le mariage coûte 12 000 €. Ou un barbecue à la mairie ?" }
            var v = j.vieEtat; v.statutCouple = .marie; v.mariages += 1; j.vieEtat = v
            j.relations[i].nom = r.nom
            lien(15); j.stats.bonheur += 18
            VieSysteme.signaler("mariage", &j)
            return VieDonnees.replique("weddingTexts", nom: nom, defaut: "Tu as épousé \(nom) ! Tonton a fait un discours de 45 minutes.")

        case .rompre:
            return rompre(&j, parLeJoueur: true).joined(separator: " ")

        case .divorcer:
            return rompre(&j, parLeJoueur: true).joined(separator: " ")

        case .bebe:
            if j.vieEtat.grossesse != nil { return "Un bébé est déjà en route. Doucement." }
            let ageFemme = j.genre == .femme ? j.age : r.genre == .femme ? r.age : 30
            if r.genre == j.genre { return "Vous voulez un enfant ? Pensez à l'adoption, dans le menu Famille." }
            if ageFemme > 48 { return "La nature dit non. L'adoption dit peut-être." }
            if r.lien < 40 { lien(-5); return "\(nom) n'est pas du tout d'humeur." }
            if VieHasard.reussi(0.45) { return conception(&j).joined(separator: " ") }
            return "Pas de bébé cette fois. Mais vous avez bien rigolé."

        case .meilleurAmi:
            if r.lien >= 70 && VieHasard.reussi(0.7) {
                var v = j.vieEtat; v.meilleurAmiId = id; j.vieEtat = v
                lien(10)
                VieSysteme.signaler("meilleur_ami", &j)
                return "\(nom) est officiellement ton meilleur ami·e. Bracelets assortis commandés."
            }
            lien(-4); return "\(nom) a dit « on verra ». Ça veut dire non."

        case .finAmitie:
            j.relations.remove(at: i)
            if j.vieEtat.meilleurAmiId == id { var v = j.vieEtat; v.meilleurAmiId = nil; j.vieEtat = v }
            return "Tu as mis fin à ton amitié avec \(nom), et tu l'as bloqué·e partout."

        case .reconcilier:
            if VieHasard.reussi(0.45) { lien(15); return "\(nom) accepte d'aller boire un café. Vous avez ri de vos disputes. Un peu." }
            lien(-5); return "\(nom) a vu ton message et a laissé « vu » depuis trois semaines."
        }
    }

    // MARK: - Rencontres

    struct Profil: Identifiable, Equatable {
        let id = UUID()
        let prenom: String
        let nom: String
        let genre: Genre
        let age: Int
        let metier: String
        let apparence: Int
        let bio: String
    }

    static let metiersRencontre = ["Barista", "Notaire", "DJ le week-end", "Coach de vie", "Pompier", "Développeur·se", "Sans emploi (par choix)", "Fleuriste", "Influenceur·se", "Prof de maths", "Vétérinaire", "Chauffeur·se de bus", "Astrologue", "Comptable", "Moniteur·rice de ski"]
    static let bios = [
        "Aime les balades, déteste les gens qui marchent lentement.",
        "Cherche quelqu'un pour finir mes frites.",
        "Pas de prise de tête. Sauf le dimanche.",
        "Mon chat doit t'approuver.",
        "Je cuisine très mal mais avec passion.",
        "Signe astrologique : fatigué·e.",
        "Je fais du sport (je regarde des matchs).",
        "Je réponds en trois jours ouvrés.",
        "Fan de randonnée et de siestes de 4 heures.",
        "Je connais tous les dialogues de mon film préféré. Tous.",
        "Allergique aux gens qui mettent l'ananas sur la pizza. Ou pas, on en discute.",
        "Grand cœur, petit appart.",
    ]

    static func profils(_ j: Joueur, genre: Genre?, nombre: Int = 6) -> [Profil] {
        (0..<nombre).map { _ in
            let g = genre ?? (j.genre == .homme ? .femme : .homme)
            let age = max(16, j.age + Int.random(in: -6...6))
            return Profil(prenom: VieDonnees.prenom(g), nom: VieDonnees.nomFamille(), genre: g, age: j.age < 18 ? min(17, max(14, age)) : max(18, age),
                          metier: j.age < 18 ? "Lycéen·ne" : metiersRencontre.auHasard("Barista"),
                          apparence: Int.random(in: 10...100), bio: bios.auHasard(""))
        }
    }

    static func tenter(_ p: Profil, _ j: inout Joueur) -> String {
        if j.partenaireActuel != nil { return "Tu es déjà en couple. On ne fait pas ça ici." }
        if j.vieEtat.justice.enPrison { return "Les rencontres en prison, c'est par le parloir. Et c'est compliqué." }
        let ecart = Double(j.stats.apparence - p.apparence) / 200
        let chance = VieHasard.borne(0.45 + ecart + Double(j.stats.bonheur) / 600)
        if VieHasard.reussi(VieBonus.seduction(chance)) {
            let r = Relation(prenom: p.prenom, nom: p.nom, genre: p.genre, type: .partenaire, age: p.age,
                             lien: Int.random(in: 50...75), argent: j.age < 18 ? 0 : Int.random(in: 0...50_000))
            j.relations.append(r)
            var v = j.vieEtat; v.statutCouple = nil; v.anneesEnsemble = 0; j.vieEtat = v
            j.stats.bonheur += 8
            VieSysteme.signaler("rencontre", &j)
            VieSysteme.signaler("couple", &j)
            return "\(p.prenom) a dit oui ! Vous êtes officiellement ensemble. " + VieDonnees.replique("dateGood", nom: p.prenom, defaut: "")
        }
        j.stats.bonheur -= 3
        return VieDonnees.replique("flirtBad", nom: p.prenom, defaut: "\(p.prenom) a poliment décliné. Puis t'a bloqué·e.")
    }

    // MARK: - Rupture, divorce

    @discardableResult
    static func rompre(_ j: inout Joueur, parLeJoueur: Bool) -> [String] {
        guard let p = j.partenaireActuel, let i = j.relations.firstIndex(where: { $0.id == p.id }) else { return [] }
        var v = j.vieEtat
        let etaitMarie = v.statutCouple == .marie
        j.relations[i].type = .ex
        j.relations[i].lien = min(p.lien, etaitMarie ? 15 : 25)
        v.statutCouple = nil
        v.anneesEnsemble = 0
        var lignes: [String] = []
        let etaitFiance = v.statutCouple == .fiance
        if etaitMarie {
            v.divorces += 1
            let perte = max(0, j.argent / 2)
            j.argent -= perte
            j.stats.bonheur -= 15
            let qui = parLeJoueur ? "Tu as demandé le divorce." : "\(p.prenom) a demandé le divorce."
            lignes.append("\(qui) " + VieDonnees.replique("divorce", nom: p.prenom, defaut: "L'avocat de \(p.prenom) avait un très beau costume.") + " Tu perds \(Format.argent(perte)).")
        } else {
            j.stats.bonheur -= parLeJoueur ? 4 : 12
            lignes.append(parLeJoueur
                ? VieDonnees.replique("breakup", nom: p.prenom, defaut: "Tu as rompu avec \(p.prenom) par message vocal.")
                : "\(p.prenom) a rompu avec toi. Par post-it, collé sur le frigo.")
        }
        j.vieEtat = v
        if etaitMarie { VieSysteme.signaler("divorce", &j) }
        else { VieSysteme.signaler(parLeJoueur ? "rupture" : "largue", &j) }
        if etaitFiance { VieSysteme.signaler("fiancailles_rompues", &j) }
        return lignes
    }

    // MARK: - Bébés

    @discardableResult
    static func conception(_ j: inout Joueur) -> [String] {
        var v = j.vieEtat
        guard v.grossesse == nil, j.age >= 16 else { return [] }
        let p = j.partenaireActuel
        v.grossesse = 9
        v.autreParent = p?.prenom
        j.vieEtat = v
        VieSysteme.signaler("grossesse", &j)
        if j.genre == .femme { return ["Tu es enceinte ! Le bébé arrive l'an prochain."] }
        return ["\(p?.prenom ?? "Ta partenaire") est enceinte ! Le bébé arrive l'an prochain. Tu as déjà peur."]
    }

    static func naissanceBebe(_ j: inout Joueur) -> [String] {
        var v = j.vieEtat
        v.grossesse = nil
        let jumeaux = VieHasard.reussi(0.03)
        var lignes: [String] = []
        for _ in 0..<(jumeaux ? 2 : 1) {
            let g: Genre = Bool.random() ? .homme : .femme
            let bebe = Relation(prenom: VieDonnees.prenom(g), nom: j.nom, genre: g, type: .enfant, age: 0, lien: 90)
            j.relations.append(bebe)
            lignes.append("👶 " + VieDonnees.replique("birthTexts", nom: bebe.prenom, defaut: "Bienvenue à \(bebe.prenom) !") + " (\(g == .homme ? "un garçon" : "une fille"))")
        }
        if jumeaux { lignes.append("Des jumeaux ! Tu ne dormiras plus jamais.") }
        v.autreParent = nil
        j.vieEtat = v
        j.stats.bonheur += 15
        VieSysteme.signaler("naissance_enfant", &j)
        return lignes
    }

    static func adopter(_ j: inout Joueur) -> String {
        guard j.age >= 21 else { return "Il faut avoir 21 ans pour adopter." }
        guard j.argent >= 15_000 else { return "L'adoption coûte 15 000 € de frais de dossier." }
        if !j.vieEtat.justice.casier.isEmpty && !VieHasard.reussi(0.3) { return "L'agence a vu ton casier judiciaire. Elle a raccroché très vite." }
        j.argent -= 15_000
        let g: Genre = Bool.random() ? .homme : .femme
        let enfant = Relation(prenom: VieDonnees.prenom(g), nom: j.nom, genre: g, type: .enfant, age: Int.random(in: 0...10), lien: 70)
        j.relations.append(enfant)
        j.stats.bonheur += 12
        VieSysteme.signaler("adoption", &j)
        return "Tu as adopté \(enfant.prenom), \(enfant.age) an\(enfant.age > 1 ? "s" : ""). \(enfant.a("Il", "Elle")) a déjà pris la meilleure chambre."
    }

    // MARK: - Amis

    static func nouvelAmi(_ j: inout Joueur) -> String {
        let g: Genre = Bool.random() ? .homme : .femme
        let ami = Relation(prenom: VieDonnees.prenom(g), nom: VieDonnees.nomFamille(), genre: g, type: .ami,
                           age: max(3, j.age + Int.random(in: -2...2)), lien: Int.random(in: 50...80))
        j.relations.append(ami)
        let lieu = j.age < 18 ? "à l'école" : ["au boulot", "à la salle", "dans une file d'attente", "à un mariage", "au supermarché"].auHasard("au boulot")
        return "Tu t'es fait \(g == .femme ? "une nouvelle amie" : "un nouvel ami") \(lieu) : \(ami.prenom)."
    }

}

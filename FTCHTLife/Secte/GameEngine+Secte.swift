import Foundation

// Branchement du module Secte dans le moteur et actions du joueur. Voir docs/SECTE_DETECTIVE.md.

/// Ce que le joueur peut faire depuis l'écran de son mouvement.
enum SecteAction: Equatable {
    case precher, retraite, communication, durcir, ouvrir, defense
    case remuneration(Int)
    case recruterProche(UUID)

    /// Clé pour la limite « une fois par an ».
    var cle: String {
        switch self {
        case .precher: return "precher"
        case .retraite: return "retraite"
        case .communication: return "communication"
        case .durcir, .ouvrir: return "regles"
        case .defense: return "defense"
        case .remuneration: return "remuneration"
        case .recruterProche: return "recruter"
        }
    }
}

extension GameEngine {

    // MARK: - Passage d'année

    /// Appelé dans `modulesAnnee` : l'année du mouvement.
    func secteAnnee(_ j: inout Joueur) -> [String] {
        guard var etat = j.sectes, var s = etat.actuelle else { return [] }
        let bilan = SecteMoteur.passerAnnee(&s, j)
        j.argent = Shkurtaaa.argent(j.argent + bilan.argentJoueur)
        var lignes = bilan.lignes
        var signaux = bilan.signaux
        if s.adeptes >= SecteMoteur.seuilPleinTemps && etat.adeptesMax < SecteMoteur.seuilPleinTemps {
            signaux.append("secte_mouvement")
        }
        etat.adeptesMax = max(etat.adeptesMax, s.adeptes)
        // Les proches partis de la vie du joueur (décès…) ne comptent plus.
        let vivants = Set(j.relations.filter { $0.vivant }.map { $0.id })
        s.prochesIds = s.prochesIds.filter { vivants.contains($0) }
        if s.adeptes <= 0 {
            lignes.append("🕯️ Plus personne ne vient aux réunions de \(s.nom). Le mouvement s'éteint sans bruit.")
            etat.anciennes.append(SecteArchive(nom: s.nom, doctrineId: s.doctrineId, ageDebut: s.ageFondation, ageFin: j.age,
                                               adeptesMax: etat.adeptesMax, fin: "abandon"))
            etat.actuelle = nil
            etat.adeptesMax = 0
            signaux.append("secte_dissoute")
        } else {
            etat.actuelle = s
        }
        j.sectes = etat
        for sig in signaux { SignauxModules.signaler(sig, &j) }
        return lignes
    }

    /// Appelé à la fin de `modulesAvantTirage` : au plus une carte de la secte par an.
    func secteAvantTirage() {
        guard var j = joueur, j.vivant, !j.vieEtat.justice.enPrison,
              var etat = j.sectes, var s = etat.actuelle,
              let carte = SecteMoteur.carteDeLAnnee(s, j) else { return }
        if carte.kind == "enquete" { s.stadeAnnonce = s.enquete }
        if carte.unique == true { s.evenementsVus.append(carte.id) }
        etat.actuelle = s
        j.sectes = etat
        joueur = j
        let ev = SecteMoteur.versEvenement(carte, s, j)
        let affiche = EvenementAffiche(evenement: ev, texte: remplir(ev.text, j))
        if carte.kind == "enquete" { fileEvenements.insert(affiche, at: 0) } else { fileEvenements.append(affiche) }
    }

    /// Appelé dans `modulesApresChoix` : effets de la carte sur le mouvement.
    func secteApresChoix(_ e: Evenement, choix index: Int, issue k: Int?, _ j: inout Joueur) {
        guard e.id.hasPrefix(SecteMoteur.prefixe), var etat = j.sectes, var s = etat.actuelle,
              let def = SecteCatalogue.evenement(String(e.id.dropFirst(SecteMoteur.prefixe.count))),
              def.choices.indices.contains(index) else { return }
        let c = def.choices[index]
        if let cout = c.cost, cout > 0 { payerPourSecte(cout, &s, &j) }
        guard let k, c.outcomes.indices.contains(k), let fx = c.outcomes[k].secte else {
            etat.actuelle = s
            j.sectes = etat
            return
        }
        let enProces = s.enquete == 4
        var signaux = SecteMoteur.appliquer(fx, &s)
        etat.actuelle = s
        j.sectes = etat

        // Justice : condamnation du fondateur.
        if let mois = fx.prisonMois {
            if var e2 = j.sectes, var s2 = e2.actuelle {
                s2.enquete = 0
                s2.stadeAnnonce = 0
                s2.defense = 0
                s2.surveillance = Stats.borne(s2.surveillance - 25)
                e2.actuelle = s2
                j.sectes = e2
            }
            for l in condamnerSecte(fx.infraction ?? "abus de faiblesse", mois: mois, &j) { ajouterLigne(&j, l) }
            if !signaux.contains("secte_condamnation") { signaux.append("secte_condamnation") }
        } else if enProces && (fx.signal == "secte_relaxe" || (fx.enquete ?? 0) < 0) {
            if var e2 = j.sectes, var s2 = e2.actuelle {
                s2.enquete = 0
                s2.stadeAnnonce = 0
                e2.actuelle = s2
                j.sectes = e2
            }
        }
        if fx.dissoudre == true {
            let ligne = fermerSecte(&j, fin: enProces || fx.prisonMois != nil ? "justice" : "dissoute")
            ajouterLigne(&j, ligne)
            if !signaux.contains("secte_dissoute") { signaux.append("secte_dissoute") }
        }
        for sig in signaux { SignauxModules.signaler(sig, &j) }
    }

    /// Paie d'abord avec le trésor de la secte, puis avec l'argent du joueur.
    func payerPourSecte(_ montant: Int, _ s: inout SecteEtat, _ j: inout Joueur) {
        let caisse = min(max(0, s.tresor), montant)
        s.tresor -= caisse
        j.argent = Shkurtaaa.argent(j.argent - (montant - caisse))
    }

    /// Casier + prison (0 mois = condamnation avec sursis ou amende).
    func condamnerSecte(_ infraction: String, mois: Int, _ j: inout Joueur) -> [String] {
        var lignes: [String] = []
        var v = j.vieEtat
        v.justice.casier.append(VieCasierLigne(age: j.age, crime: infraction, mois: mois))
        j.vieEtat = v
        if let l = VieSysteme.condamnation?(infraction.lowercased(), mois, &j) { lignes.append(l) }
        if mois > 0 {
            lignes += VieCrime.emprisonner(mois, &j)
        } else {
            lignes.append("⚖️ Condamné\(j.genre == .femme ? "e" : "") pour \(infraction.lowercased()), avec sursis. Tu ressors libre, mais tout le monde a lu le jugement.")
        }
        return lignes
    }

    /// Ferme le mouvement et l'archive. Renvoie la ligne du journal.
    @discardableResult
    func fermerSecte(_ j: inout Joueur, fin: String) -> String {
        guard var etat = j.sectes, let s = etat.actuelle else { return "" }
        etat.anciennes.append(SecteArchive(nom: s.nom, doctrineId: s.doctrineId, ageDebut: s.ageFondation, ageFin: j.age,
                                           adeptesMax: max(etat.adeptesMax, s.adeptes), fin: fin))
        etat.actuelle = nil
        etat.adeptesMax = 0
        j.sectes = etat
        switch fin {
        case "justice": return "⚖️ Le tribunal prononce la dissolution de \(s.nom). Les \(s.adeptes) membres se retrouvent seuls avec leurs questions."
        case "mort": return ""
        default: return "🕯️ Tu dissous \(s.nom). Certains pleurent, d'autres respirent."
        }
    }

    // MARK: - Actions du joueur

    /// Fonde un mouvement. Renvoie un message d'erreur, ou nil si c'est fait.
    @discardableResult
    func fonderSecte(nom: String, doctrine d: SecteDoctrine) -> String? {
        guard var j = joueur else { return "Aucune vie en cours." }
        if let raison = SecteMoteur.blocageFondation(j) { return raison }
        let propre = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !propre.isEmpty else { return "Il faut un nom à ton mouvement." }
        var etat = j.sectes ?? SectesEtat()
        let s = SecteEtat(nom: propre, doctrineId: d.id, ageFondation: j.age)
        etat.actuelle = s
        etat.adeptesMax = s.adeptes
        j.sectes = etat
        ajouterLigne(&j, "🕯️ Tu fondes « \(propre) » (\(d.nom.lowercased())). Trois personnes assistent à la première réunion, dans ton salon.")
        SignauxModules.signaler("secte_fondee", &j)
        joueur = j
        sauvegarder()
        return nil
    }

    /// Change la contribution demandée aux adeptes (0 à 3).
    func secteContribution(_ niveau: Int) {
        modifier { j in
            guard var etat = j.sectes, var s = etat.actuelle else { return }
            let n = min(3, max(0, niveau))
            guard n != s.contribution else { return }
            if n > s.contribution { s.derive += 2 * (n - s.contribution); s.ferveur -= 2 * (n - s.contribution) }
            s.contribution = n
            SecteMoteur.borner(&s)
            etat.actuelle = s
            j.sectes = etat
            self.ajouterLigne(&j, "Tu fixes la contribution des membres de \(s.nom) : \(SecteMoteur.nomsContribution[n].lowercased()).")
        }
    }

    /// Change de lieu. Renvoie un message (erreur ou réussite).
    func secteDemenager(_ lieu: SecteLieu) -> String {
        guard var j = joueur, var etat = j.sectes, var s = etat.actuelle else { return "Tu n'as pas de mouvement." }
        guard lieu != s.lieu else { return "Vous y êtes déjà." }
        if j.vieEtat.justice.enPrison { return "Difficile de signer un bail depuis une cellule." }
        if lieu.rang > s.lieu.rang {
            guard Shkurtaaa.peutPayer(lieu.prix - max(0, s.tresor), solde: j.argent) || s.tresor >= lieu.prix else {
                return "Il faut \(Format.argent(lieu.prix)) (caisse du mouvement puis ton argent)."
            }
            payerPourSecte(lieu.prix, &s, &j)
        }
        if lieu.capacite < s.adeptes {
            let partis = s.adeptes - lieu.capacite
            s.adeptes = lieu.capacite
            ajouterLigne(&j, "Le nouveau lieu est trop petit : \(partis) membres ne suivent pas.")
        }
        let ancien = s.lieu
        s.lieu = lieu
        if lieu == .domaine { s.ferveur += 8; s.derive += 6; s.surveillance += 6 }
        if ancien == .domaine { s.derive -= 5 }
        SecteMoteur.borner(&s)
        etat.actuelle = s
        j.sectes = etat
        let texte: String
        switch lieu {
        case .salon: texte = "Retour au salon. Moins de charges, plus d'intimité, et les voisins qui comptent les voitures."
        case .local: texte = "Tu loues un local pour \(s.nom). Des chaises alignées, un pupitre, une porte qui ferme à clé."
        case .temple: texte = "Tu inaugures le temple de \(s.nom). Ton nom est gravé au-dessus de l'entrée."
        case .domaine: texte = "Tu achètes un domaine à la campagne. Les membres de \(s.nom) s'y installent. Désormais, c'est toute ta vie."
        }
        ajouterLigne(&j, "🏛️ " + texte)
        joueur = j
        sauvegarder()
        return texte
    }

    /// Action de l'année. Renvoie le message à afficher.
    func secteAgir(_ action: SecteAction) -> String {
        guard var j = joueur, j.vivant, var etat = j.sectes, var s = etat.actuelle,
              let d = SecteCatalogue.doctrine(s.doctrineId) else { return "Tu n'as pas de mouvement." }
        if j.vieEtat.justice.enPrison { return "Tu es en prison. Tes lieutenants agissent à ta place (et pas forcément comme tu voudrais)." }
        if s.actionsAnnee.contains(action.cle) { return "Tu l'as déjà fait cette année. Patience, même pour un prophète." }
        let ch = SecteMoteur.charisme(j)
        var message = ""
        var signaux: [String] = []

        switch action {
        case .precher:
            let place = max(0, s.lieu.capacite - s.adeptes)
            let gain = min(place, Int((3 + Double(s.adeptes) * 0.06) * ch * d.attrait * Double.random(in: 0.5...1.5)))
            s.adeptes += gain
            s.notoriete += 2
            s.ferveur += 2
            for l in Competences.appliquer(["eloquence": 3], &j) { ajouterLigne(&j, l) }
            let preche = remplir(SecteMoteur.remplir(d.preches.randomElement() ?? "Tu prêches devant {nb} {adeptes}.", s, j), j)
            message = preche + (gain > 0 ? " \(gain) nouvelles personnes rejoignent \(s.nom)." : (place == 0 ? " Le lieu est plein : il faut plus grand." : " Personne de nouveau ce soir."))

        case .retraite:
            guard s.adeptes >= 5 else { return "Il faut au moins 5 membres pour organiser une retraite." }
            let gain = Int(Double(s.adeptes) * Double(d.donMoyen) * 0.3 * (0.5 + Double(s.ferveur) / 100))
            s.tresor += gain
            s.ferveur += 6
            s.derive += 2
            message = "Trois jours de retraite payante : jeûne, chants, confidences en cercle. La caisse encaisse \(Format.argent(gain))."

        case .communication:
            let cout = 5_000 + s.notoriete * 400
            guard s.tresor + max(0, j.argent) >= cout || Shkurtaaa.actif else { return "Une campagne coûte \(Format.argent(cout))." }
            payerPourSecte(cout, &s, &j)
            let n = Int.random(in: 6...14)
            s.notoriete += n
            s.surveillance += 5
            let place = max(0, s.lieu.capacite - s.adeptes)
            let gain = min(place, Int(Double(max(5, s.adeptes / 10)) * ch))
            s.adeptes += gain
            message = ["Un livre signé de ta main, « La voie de \(s.nom) », se vend en gare.",
                       "Ta chaîne VousTube passe la barre des cent mille vues. Les commentaires sont partagés.",
                       "Tu passes dans une émission de fin de soirée. Le présentateur sourit, le public t'écoute."].randomElement()!
                + " Notoriété +\(n), \(gain) nouvelles recrues."

        case .durcir:
            guard !s.reglesStrictes else { return "Les règles sont déjà strictes." }
            s.reglesStrictes = true
            s.ferveur += 12
            s.derive += 15
            s.surveillance += 6
            s.adeptes -= s.adeptes * 5 / 100
            j.stats.karma -= 8
            signaux.append("secte_regles_strictes")
            message = "Nouvelles règles : téléphones confiés à l'accueil, contacts avec les familles « déconseillés », rapports hebdomadaires. Ceux qui restent sont plus fervents. Les autres partent, ou n'osent plus."

        case .ouvrir:
            s.reglesStrictes = false
            s.derive -= 15
            s.surveillance -= 10
            s.ferveur -= 8
            s.adeptes -= s.adeptes * 8 / 100
            j.stats.karma += 5
            message = "Tu ouvres les portes : les familles peuvent venir, les comptes sont publiés, un médiateur extérieur est accepté. Des membres partent, ceux qui restent le font librement."

        case .defense:
            guard s.enquete >= 1 else { return "Aucune procédure en cours. Garde ton argent." }
            guard s.defense < 3 else { return "Tu as déjà les meilleurs avocats du pays." }
            let cout = SecteMoteur.coutsDefense[s.defense]
            guard s.tresor + max(0, j.argent) >= cout || Shkurtaaa.actif else { return "Ce cabinet demande \(Format.argent(cout))." }
            payerPourSecte(cout, &s, &j)
            s.defense += 1
            message = ["Un avocat pénaliste réputé accepte ton dossier.",
                       "Un cabinet parisien prend l'affaire. Ils facturent même les silences.",
                       "Une star du barreau rejoint ta défense. Elle n'a jamais perdu un procès médiatique."][s.defense - 1]

        case .remuneration(let niveau):
            let n = min(3, max(1, niveau))
            let montant: Int
            switch n {
            case 1: montant = min(max(0, s.tresor), 24_000 + s.adeptes * 20)
            case 2: montant = max(0, s.tresor) / 4
            default: montant = max(0, s.tresor) * 6 / 10
            }
            guard montant > 0 else { return "La caisse est vide." }
            s.tresor -= montant
            s.prelevements += montant
            j.argent = Shkurtaaa.argent(j.argent + montant)
            s.derive += [0, 1, 5, 12][n]
            s.surveillance += [0, 1, 4, 10][n]
            if n == 3 { j.stats.karma -= 10; s.ferveur -= 4 }
            if n >= 2 { signaux.append("secte_prelevement") }
            message = n == 1
                ? "Tu te verses une rémunération modeste : \(Format.argent(montant)). Les comptes restent présentables."
                : "Tu te sers dans la caisse : \(Format.argent(montant)). Officiellement, « pour la mission »."

        case .recruterProche(let id):
            guard let i = j.relations.firstIndex(where: { $0.id == id && $0.vivant }) else { return "Cette personne n'est plus là." }
            let r = j.relations[i]
            guard !s.prochesIds.contains(id) else { return "\(r.prenom) fait déjà partie du mouvement." }
            var chance = 0.12 + Double(r.lien) / 220 + ch * 0.15
            if r.type.estParent { chance -= 0.1 }
            if r.type == .partenaire { chance += 0.1 }
            if Double.random(in: 0...1) < min(0.85, chance) {
                s.prochesIds.append(id)
                s.adeptes += 1
                j.relations[i].lien = Stats.borne(r.lien + 5)
                j.stats.karma -= 3
                signaux.append("secte_proche_recrute")
                message = "\(r.designation), \(r.prenom), rejoint \(s.nom). Tu ne sais pas si tu dois t'en réjouir."
            } else {
                j.relations[i].lien = Stats.borne(r.lien - 15)
                message = "\(r.designation), \(r.prenom), refuse net. « Je ne te reconnais plus. » Le silence s'installe entre vous."
            }
        }

        s.actionsAnnee.append(action.cle)
        SecteMoteur.borner(&s)
        j.stats.borner()
        etat.actuelle = s
        j.sectes = etat
        ajouterLigne(&j, message)
        for sig in signaux { SignauxModules.signaler(sig, &j) }
        joueur = j
        sauvegarder()
        return message
    }

    /// Dissoudre son mouvement. `rendre` : on rembourse les membres avec la caisse.
    func dissoudreSecte(rendre: Bool) -> String {
        guard var j = joueur, var etat = j.sectes, let s = etat.actuelle else { return "Tu n'as pas de mouvement." }
        let texte: String
        if rendre {
            j.stats.karma += 10
            texte = "Tu dissous \(s.nom) et rends ce qui reste dans la caisse (\(Format.argent(max(0, s.tresor)))) aux membres. Certains te remercient, d'autres ne te pardonneront jamais."
        } else {
            let garde = max(0, s.tresor) / 2
            j.argent = Shkurtaaa.argent(j.argent + garde)
            j.stats.karma -= 15
            texte = "Tu dissous \(s.nom) et gardes \(Format.argent(garde)) de la caisse. Le reste s'évapore en « frais de liquidation »."
            if s.surveillance >= 40 {
                var rep = j.repercussions ?? RepercussionsEtat()
                Repercussions.appliquerDrapeaux(poser: ["secte_caisse_gardee"], retirer: nil, age: j.age, etat: &rep)
                j.repercussions = rep
            }
        }
        etat.actuelle = s
        j.sectes = etat
        fermerSecte(&j, fin: "dissoute")
        ajouterLigne(&j, "🕯️ " + texte)
        SignauxModules.signaler("secte_dissoute", &j)
        joueur = j
        sauvegarder()
        return texte
    }

    /// Les proches qu'on peut tenter de faire entrer dans le mouvement.
    func secteProchesRecrutables() -> [Relation] {
        guard let j = joueur, let s = j.sectes?.actuelle else { return [] }
        let types: [TypeRelation] = [.mere, .pere, .frere, .soeur, .ami, .partenaire, .enfant, .ex]
        return j.relations.filter { $0.vivant && types.contains($0.type) && $0.age >= 16 && !s.prochesIds.contains($0.id) }
    }
}

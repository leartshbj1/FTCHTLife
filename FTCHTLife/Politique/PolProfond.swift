import Foundation

// Deuxième couche de la carrière politique : pays et électorat, rivaux, vie de parti,
// équipe, gouvernement, après-politique. Voir docs/POLITIQUE.md.

extension PolMoteur {

    // MARK: - Électorat

    /// Popularité qui compte dans une élection directe : moitié popularité générale, moitié groupes d'électeurs pondérés
    /// (avec les affinités du parti).
    static func popularitePonderee(_ e: PolEtat) -> Double {
        let affinites = e.parti?.segments ?? [:]
        let groupes = PolSegment.allCases.reduce(0.0) { acc, s in
            acc + s.poids * Double(Stats.borne(e.opinion(s) + (affinites[s.rawValue] ?? 0)))
        }
        return Double(e.popularite) * 0.5 + groupes * 0.5
    }

    // MARK: - Rivaux

    /// Choisit l'adversaire d'une campagne : souvent un rival connu, sinon un nouveau venu qui devient un rival.
    static func choisirAdversaire(_ p: PolPoste, _ e: inout PolEtat) -> PolRival {
        let possibles = e.rivaux.filter { $0.niveau >= p.rang - 1 }
        if let r = possibles.randomElement(), Double.random(in: 0...1) < 0.6 { return r }
        let g = Genre.allCases.randomElement()!
        let parti = PolCatalogue.partisDuPays(e.paysId).filter { $0.id != e.partiId }.randomElement()
        let nouveau = PolRival(prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement()!, genre: g,
                               partiId: parti?.id, rancune: Int.random(in: 5...25), niveau: max(0, p.rang - 1))
        e.rivaux.append(nouveau)
        if e.rivaux.count > 5, let moinsRancunier = e.rivaux.min(by: { $0.rancune < $1.rancune }) {
            e.rivaux.removeAll { $0.id == moinsRancunier.id }
        }
        return e.rivaux.first { $0.id == nouveau.id } ?? nouveau
    }

    static func majRivalApresElection(_ c: PolCandidature, gagne: Bool, _ e: inout PolEtat) {
        guard let id = c.rivalId, let i = e.rivaux.firstIndex(where: { $0.id == id }) else { return }
        e.rivaux[i].duels += 1
        if gagne {
            e.rivaux[i].rancune += 15
        } else {
            e.rivaux[i].rancune += 5
            e.rivaux[i].niveau = max(e.rivaux[i].niveau, c.poste.rang)
        }
    }

    static func reconcilier(_ id: UUID, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let i = e.rivaux.firstIndex(where: { $0.id == id }) else { return PolResultat(texte: "Ce rival n'est plus dans la course.") }
        guard marquer("rival_" + id.uuidString, &j) else { return dejaFait }
        let r = e.rivaux[i]
        if Double.random(in: 0...1) < 0.6 {
            e.rivaux[i].rancune -= Int.random(in: 15...30)
            e.borner()
            return PolResultat(texte: "Déjeuner de réconciliation avec \(r.nomComplet). Vous vous êtes dit les choses. Ce n'est pas de l'amitié, mais c'est une trêve.")
        }
        e.rivaux[i].rancune += 5
        e.borner()
        return PolResultat(texte: "\(r.nomComplet) est venu" + (r.genre == .femme ? "e" : "") + " au déjeuner surtout pour te tester. Rien n'est réglé entre vous.")
    }

    static func attaquerRival(_ id: UUID, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let i = e.rivaux.firstIndex(where: { $0.id == id }) else { return PolResultat(texte: "Ce rival n'est plus dans la course.") }
        guard marquer("rival_" + id.uuidString, &j) else { return dejaFait }
        let r = e.rivaux[i]
        j.stats.karma -= 4
        e.rivaux[i].rancune += 20
        if Double.random(in: 0...1) < 0.55 {
            e.rivaux[i].niveau = max(0, r.niveau - 1)
            e.popularite += 2
            e.titres.append("Affaire \(r.nom) : les révélations qui font tache")
            e.borner()
            return PolResultat(texte: "Tu fais fuiter le vieux dossier de \(r.nomComplet) (des notes de frais jamais justifiées). Sa carrière recule d'un cran.")
        }
        e.casseroles += 6
        e.popularite -= 3
        e.borner()
        return PolResultat(texte: "Ton dossier sur \(r.nomComplet) était faux. C'est maintenant toi qui fais la une, pour de mauvaises raisons.")
    }

    static func allianceRival(_ id: UUID, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let i = e.rivaux.firstIndex(where: { $0.id == id }) else { return PolResultat(texte: "Ce rival n'est plus dans la course.") }
        guard marquer("rival_" + id.uuidString, &j) else { return dejaFait }
        let r = e.rivaux[i]
        if e.rivaux[i].rancune < 50 {
            e.rivaux[i].rancune -= 15
            e.influence += 5
            e.loyaute -= 3
            e.borner()
            return PolResultat(texte: "Alliance scellée avec \(r.nomComplet) lors d'un dîner discret. Ton parti grince des dents, ton réseau s'agrandit.")
        }
        e.borner()
        return PolResultat(texte: "\(r.nomComplet) refuse sèchement. La rancune est encore trop fraîche.")
    }

    // MARK: - Parti

    static let rangsParti = ["Adhérent", "Cadre local", "Bureau national", "Chef du parti"]

    struct Courant: Identifiable {
        let nom: String
        let description: String
        var id: String { nom }
    }

    static let courants: [Courant] = [
        Courant(nom: "Les Réformateurs", description: "Moderniser le parti et parler aux classes moyennes urbaines."),
        Courant(nom: "Les Historiques", description: "Les fondateurs et les anciens, gardiens de la ligne."),
        Courant(nom: "Les Bâtisseurs", description: "Les élus locaux, pragmatiques, qui veulent des résultats concrets."),
        Courant(nom: "Les Centristes", description: "Le compromis avant tout. Ni trop, ni trop peu."),
        Courant(nom: "Les Frondeurs", description: "Ils contestent la direction et réclament un retour aux promesses."),
    ]

    static func changerCourant(_ nom: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.partiId != nil else { return PolResultat(texte: "Il te faut un parti pour rejoindre un courant.") }
        guard marquer("courant", &j) else { return dejaFait }
        let ancien = e.courant
        e.courant = nom
        switch nom {
        case "Les Frondeurs": e.loyaute -= 10; e.popularite += 4
        case "Les Historiques": e.loyaute += 6
        case "Les Ambitieux": e.influence += 4; e.loyaute -= 4
        case "Les Modernes": e.segments["jeunes"] = Stats.borne(e.opinion(.jeunes) + 4)
        default: e.loyaute += 2
        }
        e.borner()
        return PolResultat(texte: ancien == nil
                           ? "Tu rejoins le courant « \(nom) ». Tu as désormais une famille dans la famille."
                           : "Tu quittes « \(ancien!) » pour « \(nom) ». Tes anciens camarades parlent de trahison, les nouveaux de lucidité.")
    }

    /// Monter dans l'appareil du parti (une fois par an).
    static func monterDansLeParti(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.partiId != nil else { return PolResultat(texte: "Il te faut un parti.") }
        guard e.rangParti < 2 else { return PolResultat(texte: "Tu es déjà au bureau national. La prochaine marche, c'est le congrès.") }
        guard marquer("rang_parti", &j) else { return dejaFait }
        let chance = (Double(e.loyaute) * 0.4 + Double(e.influence) * 0.4) / 100 - Double(e.rangParti) * 0.12 + 0.1
        if Double.random(in: 0...1) < chance {
            e.rangParti += 1
            e.influence += 4
            e.borner()
            return PolResultat(texte: "Te voilà « \(rangsParti[e.rangParti].lowercased()) ». Tu pèses désormais dans les décisions internes.")
        }
        e.loyaute -= 2
        e.borner()
        return PolResultat(texte: "Le vote interne t'a préféré un cadre plus ancien, qui connaît par cœur les statuts du parti et qui a su compter ses soutiens.")
    }

    /// Congrès : prendre la tête du parti (bureau national requis, une fois par an).
    static func congres(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let parti = e.parti, e.rangParti == 2 else { return PolResultat(texte: "Il faut siéger au bureau national pour briguer la tête du parti.") }
        guard marquer("congres", &j) else { return dejaFait }
        let chance = (Double(e.influence) * 0.4 + Double(e.loyaute) * 0.3 + Double(e.popularite) * 0.2) / 100 - 0.1
        if Double.random(in: 0...1) < chance {
            e.rangParti = 3
            e.influence += 10
            e.titres.append(remplir("{prenom} {nom} prend la tête du \(parti.sigle)", j, e))
            e.borner()
            return PolResultat(texte: "🎉 Congrès gagné ! Tu es " + j.g("le chef", "la cheffe") + " du \(parti.nom). Il va falloir rassembler ceux qui ont voté contre toi.")
        }
        e.loyaute -= 6
        if var r = e.rivalPrincipal, let i = e.rivaux.firstIndex(where: { $0.id == r.id }) {
            r.rancune += 10
            e.rivaux[i] = r
        }
        e.borner()
        return PolResultat(texte: "Congrès perdu à 43 voix près. Une motion de synthèse a été votée à 4 h du matin. Tes soutiens sont amers.")
    }

    /// Fonder son propre parti.
    static func fonderParti(nom: String, sigle: String, slogan: String, couleur: String, bord: String,
                            _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        let n = nom.trimmingCharacters(in: .whitespaces)
        let s = sigle.trimmingCharacters(in: .whitespaces).uppercased()
        guard !n.isEmpty, !s.isEmpty else { return PolResultat(texte: "Il faut un nom et un sigle.") }
        guard !systeme(j).estPartiUnique else { return PolResultat(texte: "Ici, un seul parti est autorisé. Fonder le tien te vaudrait bien plus qu'une amende.") }
        guard j.age >= ageCandidat else { return PolResultat(texte: "Il faut être majeur pour fonder un parti.") }
        guard e.influence >= 20 || j.argent >= 20_000 else { return PolResultat(texte: "Il faut 20 d'influence ou 20 000 € pour déposer les statuts.") }
        var texte = ""
        if let ancien = e.parti, ancien.id != "perso" {
            texte = "Tu quittes le \(ancien.nom) avec fracas. "
            e.influence -= 5
        }
        if e.influence < 20 { j.argent -= 20_000 }
        let sl = slogan.trimmingCharacters(in: .whitespaces)
        e.partiPerso = PolParti(id: "perso", nom: n, sigle: s, slogan: sl.isEmpty ? "Pour une autre voie." : sl,
                                description: "Fondé par \(j.prenom) \(j.nom) avec une poignée de fidèles.",
                                couleur: couleur, bord: bord, bonusElection: 0, cotisation: 0, influence: 0, segments: nil)
        e.partiId = "perso"
        e.rangParti = 3
        e.loyaute = 100
        e.borner()
        e.titres.append("Un nouveau parti est né : le \(n) (\(s))")
        return PolResultat(texte: texte + "Tu fondes le \(n) (\(s)). « \(e.partiPerso?.slogan ?? "") » Pour l'instant, il y a toi et une poignée de fidèles. Chaque élection gagnée le rendra plus fort.")
    }

    /// Postes pour lesquels un membre de parti doit obtenir l'investiture (sinon : dissidence).
    static func besoinInvestiture(_ p: PolPoste, _ e: PolEtat) -> Bool {
        guard e.partiId != nil, !e.estChefDeParti else { return false }
        return [.maire, .depute, .senateur, .presidentRegion, .president].contains(p) && e.mandat?.poste != p
    }

    /// Demander l'investiture du parti (primaire pour la présidentielle), une fois par an.
    static func demanderInvestiture(_ p: PolPoste, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let parti = e.parti, besoinInvestiture(p, e) else { return PolResultat(texte: "Tu n'as pas besoin d'investiture pour ce poste.") }
        guard marquer("investiture", &j) else { return dejaFait }
        let chance: Double
        if p == .president {
            chance = (popularitePonderee(e) * 0.4 + Double(e.influence) * 0.3 + Double(e.loyaute) * 0.2) / 100 + Double(e.rangParti) * 0.05
        } else {
            chance = (Double(e.loyaute) * 0.45 + Double(e.influence) * 0.35) / 100 + Double(e.rangParti) * 0.08
        }
        if Double.random(in: 0...1) < chance {
            e.investiture = p.rawValue
            if p == .president { e.titres.append(remplir("Primaire du \(parti.sigle) : {prenom} {nom} l'emporte", j, e)) }
            return PolResultat(texte: p == .president
                               ? "🗳️ Tu gagnes la primaire du \(parti.nom) ! Tes concurrents te félicitent, certains du bout des lèvres."
                               : "Le \(parti.nom) t'investit pour le poste de \(p.nom(j).polMinuscule()). L'appareil du parti est derrière toi.")
        }
        e.loyaute -= 3
        return PolResultat(texte: p == .president
                           ? "Tu perds la primaire du \(parti.nom). Le vainqueur te propose « un rôle important dans la campagne ». Tu sais ce que ça veut dire."
                           : "Le parti investit quelqu'un d'autre. Tu peux encore te présenter en dissident, mais tu seras exclu" + j.g("", "e") + ".")
    }

    // MARK: - Équipe

    static func candidatsEquipe(_ role: PolRole) -> [PolMembre] {
        (0..<3).map { _ in
            let g = Genre.allCases.randomElement()!
            let comp = Int.random(in: 15...95)
            return PolMembre(role: role, prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement()!, genre: g,
                             competence: comp, loyaute: Int.random(in: 35...85),
                             salaire: Int(Double(role.salaireBase) * (0.5 + Double(comp) / 100)))
        }
    }

    static func recruter(_ m: PolMembre, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard j.age >= ageCandidat else { return PolResultat(texte: "Il faut être majeur pour recruter une équipe.") }
        guard !e.equipe.contains(where: { $0.role == m.role }) else { return PolResultat(texte: "Ce poste est déjà occupé dans ton équipe.") }
        e.equipe.append(m)
        return PolResultat(texte: "\(m.nomComplet) rejoint ton équipe (\(m.role.titre.lowercased())) pour \(Format.argent(m.salaire))/an.")
    }

    static func renvoyer(_ id: UUID, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let m = e.equipe.first(where: { $0.id == id }) else { return PolResultat(texte: "Cette personne est déjà partie.") }
        e.equipe.removeAll { $0.id == id }
        if m.competence > 70 && Double.random(in: 0...1) < 0.4 {
            e.casseroles += 5
            e.borner()
            return PolResultat(texte: "\(m.nomComplet) part en claquant la porte et rejoint ton rival avec tous tes fichiers.")
        }
        return PolResultat(texte: "Tu remercies \(m.nomComplet). Le départ se fait sans bruit.")
    }

    static func augmenter(_ id: UUID, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let i = e.equipe.firstIndex(where: { $0.id == id }) else { return PolResultat(texte: "Cette personne est déjà partie.") }
        guard marquer("augmenter_" + id.uuidString, &j) else { return dejaFait }
        let prime = e.equipe[i].salaire / 4
        payer(prime, &j, &e)
        e.equipe[i].loyaute = Stats.borne(e.equipe[i].loyaute + 15)
        return PolResultat(texte: "Prime de \(Format.argent(prime)) pour \(e.equipe[i].nomComplet). Sa loyauté se renforce.")
    }

    // MARK: - Nominations : Premier ministre, commissaire

    static func empechementPremierMinistre(_ j: Joueur, _ e: PolEtat) -> String? {
        let s = systeme(j)
        guard s.existe(.premierMinistre) else { return "Ce poste n'existe pas \(s.auPays)." }
        guard s.modeElection(.premierMinistre) == "nomination" else {
            return "Ici, on devient chef du gouvernement en gagnant les législatives à la tête de son parti."
        }
        guard e.partiId != nil else { return "Il faut un parti." }
        guard let m = e.mandat, [.ministre, .depute, .presidentAssemblee, .senateur].contains(m.poste) else {
            return "Il faut être ministre, député ou sénateur."
        }
        if e.influence < 60 { return "Il faut 60 d'influence." }
        return nil
    }

    static func viserPremierMinistre(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        if let r = empechementPremierMinistre(j, e) { return PolResultat(texte: r) }
        guard marquer("premier_ministre", &j) else { return dejaFait }
        let chance = max(0.02, (Double(e.loyaute) * 0.3 + Double(e.influence) * 0.35 + popularitePonderee(e) * 0.25 - Double(e.casseroles) * 0.3) / 100 - 0.12)
        guard Double.random(in: 0...1) < chance else {
            e.loyaute -= 2
            e.borner()
            return PolResultat(texte: "Le chef de l'État t'a reçu" + j.g("", "e") + " vingt minutes, t'a écouté" + j.g("", "e") + " avec attention, puis a nommé quelqu'un d'autre.")
        }
        if e.mandat != nil { terminerMandat(&j, &e, fin: "nommé" + j.g("", "e") + " à la tête du gouvernement") }
        e.mandat = PolMandat(poste: .premierMinistre, anneesRestantes: nil, ageDebut: j.age)
        e.loisTentees = []
        e.influence += 12
        e.majorite = max(e.majorite, 52)
        j.stats.bonheur += 15
        e.titres.append(remplir("{prenom} {nom} nommé{e} à la tête du gouvernement", j, e))
        e.borner()
        return PolResultat(texte: "🏛️ Tu es " + j.g("nommé", "nommée") + " \(PolPoste.premierMinistre.nom(j).polMinuscule()) ! " + remplir("Ton bureau est {au_siege_gouv}. Les dossiers s'empilent déjà.", j, e))
    }

    static func empechementCommissaire(_ j: Joueur, _ e: PolEtat) -> String? {
        if systeme(j).union == nil { return "Ton pays n'appartient à aucune union qui nomme des commissaires." }
        if !(e.aOccupe(.ministre) || e.aOccupe(.premierMinistre)) { return "Il faut avoir été ministre." }
        if let m = e.mandat, m.poste.rang >= PolPoste.commissaire.rang { return "Tu occupes déjà un poste plus élevé." }
        if e.influence < 55 { return "Il faut 55 d'influence." }
        return nil
    }

    static func partirCommission(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        if let r = empechementCommissaire(j, e) { return PolResultat(texte: r) }
        guard marquer("commission", &j) else { return dejaFait }
        let chance = (Double(e.influence) * 0.5 + Double(j.stats.intelligence) * 0.2) / 100 - Double(e.casseroles) / 300
        let s = systeme(j)
        guard Double.random(in: 0...1) < chance else {
            return PolResultat(texte: "\(s.commission.prefix(1).uppercased() + s.commission.dropFirst()) a préféré un candidat plus expérimenté sur les dossiers de l'Union.")
        }
        if e.mandat != nil { terminerMandat(&j, &e, fin: "parti" + j.g("", "e") + " à \(s.commission)") }
        e.mandat = PolMandat(poste: .commissaire, anneesRestantes: s.duree(.commissaire), ageDebut: j.age)
        e.loisTentees = []
        e.influence += 8
        j.stats.bonheur += 10
        e.borner()
        return PolResultat(texte: (s.estUE ? "🇪🇺" : "🌍") + " Te voilà membre de \(s.commission), chargé" + j.g("", "e") + remplir(" d'un portefeuille important à {siege_union}.", j, e))
    }

    // MARK: - Gouvernement (joueur président)

    static let traitsPNJ = ["loyal", "ambitieux", "populaire", "technocrate", "gaffeur"]

    static func descriptionTrait(_ t: String) -> String {
        switch t {
        case "loyal": return "Loyal : ta majorité tient mieux"
        case "ambitieux": return "Ambitieux : efficace, mais lorgne ta place"
        case "populaire": return "Populaire : +2 de popularité par an"
        case "technocrate": return "Technocrate : bon pour la croissance, peu charismatique"
        default: return "Gaffeur : imprévisible devant un micro"
        }
    }

    static func candidatsPremierMinistre() -> [PolPNJ] {
        traitsPNJ.shuffled().prefix(3).map { t in
            let g = Genre.allCases.randomElement()!
            return PolPNJ(prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement()!, genre: g, trait: t, loyaute: Int.random(in: 45...85))
        }
    }

    static func nommerPremierMinistre(_ pnj: PolPNJ, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.mandat?.poste == .president else { return PolResultat(texte: "Seul le chef de l'État nomme le Premier ministre.") }
        guard marquer("nommer_pm", &j) else { return PolResultat(texte: "Tu as déjà changé de Premier ministre cette année. Un autre changement déstabiliserait le pays.") }
        let ancien = e.premierMinistrePNJ
        e.premierMinistrePNJ = pnj
        e.titres.append("\(pnj.nomComplet) nommé" + (pnj.genre == .femme ? "e" : "") + " à la tête du gouvernement")
        if let a = ancien {
            e.popularite += Int.random(in: -2...3)
            e.borner()
            return PolResultat(texte: "Tu remercies \(a.nomComplet) et nommes \(pnj.nomComplet). La passation de pouvoirs a lieu le soir même.")
        }
        return PolResultat(texte: "Tu nommes \(pnj.nomComplet) à la tête du gouvernement. \(descriptionTrait(pnj.trait)).")
    }

    static func apresVictoirePresidentielle(score: Double, _ j: inout Joueur, _ e: inout PolEtat, _ l: inout [String]) {
        e.majorite = Stats.borne(Int(48 + (score - 50) * 1.2) + Int.random(in: -6...10))
        e.dissolutionFaite = false
        e.premierMinistrePNJ = nil
        let s = systeme(j)
        if s.existe(.premierMinistre) {
            l.append(e.majorite >= 50
                     ? "🏛️ Les législatives te donnent une majorité : \(e.majorite) % des sièges. Nomme vite ton gouvernement (onglet Politique)."
                     : "🏛️ Les législatives tournent mal : \(e.majorite) % des sièges seulement. Chaque texte sera une bataille.")
        } else {
            l.append(e.majorite >= 50
                     ? "🏛️ Ton camp contrôle \(s.parlementNom) avec \(e.majorite) % des sièges. Tes réformes ont une chance."
                     : remplir("🏛️ Ton camp est minoritaire {au_parlement} (\(e.majorite) % des sièges). Chaque texte sera une négociation.", j, e))
        }
    }

    /// Référendum sur une loi nationale (président, une fois par an).
    static func referendum(_ id: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard e.mandat?.poste == .president, let loi = PolCatalogue.loi(id), loi.niveau == "national", !e.loisActives.contains(id) else {
            return PolResultat(texte: "Impossible d'organiser ce référendum.")
        }
        guard systeme(j).referendum == true else { return PolResultat(texte: "La Constitution ne prévoit pas ce type de référendum.") }
        guard marquer("referendum", &j) else { return PolResultat(texte: "Un seul référendum par an.") }
        let chance = popularitePonderee(e) / 100 * 0.9 + 0.08 - Double(loi.difficulte) / 400
        if Double.random(in: 0...1) < chance {
            e.loisActives.append(id)
            e.loisVotees.append(id)
            if let a = loi.adoption { appliquerPol(a, &j, &e) }
            e.popularite += 5
            e.titres.append("Référendum : le « oui » l'emporte pour « \(loi.titre) »")
            if let flash = loi.monde { e.flashsMonde.append(flash) }
            e.borner()
            return PolResultat(texte: "🗳️ Le « oui » l'emporte ! « \(loi.titre) » entre en vigueur. " + remplir(loi.texteAdoption, j, e))
        }
        e.popularite -= 12
        e.mobilisation += 15
        e.titres.append("Référendum : le pays dit « non » à {prenom} {nom}".replacingOccurrences(of: "{prenom}", with: j.prenom).replacingOccurrences(of: "{nom}", with: j.nom))
        e.borner()
        return PolResultat(texte: "🗳️ Le « non » l'emporte à \(Int.random(in: 52...71)) %. Les éditorialistes parlent d'un « désaveu ». Ton autorité en sort affaiblie.")
    }

    /// Dissoudre la chambre (chef de l'exécutif, une fois par mandat).
    static func dissoudre(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        let s = systeme(j)
        guard s.dissolution == true else { return PolResultat(texte: "La Constitution ne permet pas de dissoudre \(s.parlementNom).") }
        let parPM = e.mandat?.poste == .premierMinistre && s.executifParlementaire
        guard (e.mandat?.poste == .president && !s.presidentSymbolique) || parPM else {
            return PolResultat(texte: "Seul le chef de l'exécutif peut provoquer des élections anticipées.")
        }
        guard !e.dissolutionFaite else { return PolResultat(texte: "Tu as déjà dissous \(s.parlementNom) pendant ce mandat. Une seule dissolution par mandat.") }
        e.dissolutionFaite = true
        let avant = e.majorite
        e.majorite = Stats.borne(Int(popularitePonderee(e)) + Int.random(in: -12...20))
        e.borner()
        if e.majorite >= 50 {
            e.influence += 6
            return PolResultat(texte: "🏛️ Coup de poker gagné : ta majorité passe de \(avant) % à \(e.majorite) % des sièges. Tes ministres respirent.")
        }
        if parPM {
            if e.majorite < 35 {
                terminerMandat(&j, &e, fin: "battu" + j.g("", "e") + " aux élections anticipées")
                return PolResultat(texte: "🏛️ Coup de poker perdu : ton parti tombe à \(e.majorite) % des sièges. L'opposition forme le gouvernement, tu rends les clés.")
            }
            var l: [String] = []
            coalitionSiBesoin(j, &e, &l)
            e.influence -= 4
            return PolResultat(texte: "🏛️ Pari à moitié perdu : \(e.majorite) % des sièges. Tu gardes la tête du gouvernement, mais il faudra composer. " + l.joined(separator: " "))
        }
        guard s.existe(.premierMinistre) else {
            e.influence -= 8
            return PolResultat(texte: "🏛️ Coup de poker perdu : \(e.majorite) % des sièges. L'opposition contrôle désormais \(s.parlementNom) et bloquera tes textes.")
        }
        e.premierMinistrePNJ = PolPNJ(prenom: Donnees.prenom(.homme), nom: Donnees.noms.randomElement()!, genre: .homme, trait: "ambitieux", loyaute: 10)
        e.influence -= 8
        return PolResultat(texte: "🏛️ Coup de poker perdu : \(e.majorite) % des sièges. C'est la cohabitation : l'opposition t'impose son Premier ministre, \(e.premierMinistrePNJ?.nomComplet ?? "un inconnu"), qui gouverne contre toi.")
    }

    /// Faire passer une loi en force (49.3 en France, décret ailleurs) : Premier ministre, ou président.
    static func passerEnForce(_ id: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        let poste = e.mandat?.poste
        let s = systeme(j)
        guard let procedure = s.passerEnForce else { return PolResultat(texte: "Aucune procédure ne permet ici d'adopter un texte sans vote.") }
        let sansPM = !s.existe(.premierMinistre)
        guard poste == .premierMinistre || (poste == .president && (e.premierMinistrePNJ != nil || sansPM)),
              let loi = PolCatalogue.loi(id), loi.niveau == "national", !e.loisActives.contains(id) else {
            return PolResultat(texte: "Tu ne peux pas utiliser \(procedure) pour ce texte.")
        }
        guard marquer("loi", &j) else { return PolResultat(texte: "Tu as déjà fait voter un texte cette année.") }
        e.loisActives.append(id)
        e.loisVotees.append(id)
        if let a = loi.adoption { appliquerPol(a, &j, &e) }
        if let flash = loi.monde { e.flashsMonde.append(flash) }
        e.popularite -= 8
        e.mobilisation += 20
        e.titres.append("Adoptée sans vote : « \(loi.titre) », la rue gronde")
        var t = "⚡ Par \(procedure), « \(loi.titre) » est adoptée sans vote."
        if sansPM {
            t += " L'opposition dénonce un passage en force et saisit la justice constitutionnelle."
            e.borner()
            return PolResultat(texte: t)
        }
        t += " L'opposition dépose une motion de censure."
        if e.majorite < 55 && Double.random(in: 0...1) < 0.35 {
            if poste == .premierMinistre {
                terminerMandat(&j, &e, fin: "renversé" + j.g("", "e") + " par une motion de censure")
                t += " Elle passe ! Ton gouvernement tombe. Tu remets ta démission au chef de l'État."
            } else {
                e.premierMinistrePNJ = nil
                t += " Elle passe ! Ton Premier ministre est renversé. Il faut en nommer un autre."
            }
        } else {
            t += " Elle échoue de 9 voix. Le gouvernement survit."
        }
        e.borner()
        return PolResultat(texte: t)
    }

    // MARK: - Après la politique

    static func estAncien(_ e: PolEtat) -> Bool { e.mandat == nil && e.rangMax >= 2 }

    static func ecrireMemoires(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard estAncien(e) else { return PolResultat(texte: "Il faut avoir une carrière derrière soi pour écrire ses mémoires.") }
        guard !e.memoires else { return PolResultat(texte: "Tu as déjà écrit tes mémoires. Un deuxième livre n'intéresse pas les éditeurs.") }
        e.memoires = true
        let avance = (e.rangMax + 1) * (e.rangMax + 1) * 6_000 + e.popularite * 500
        j.argent += avance
        if Double.random(in: 0...1) < 0.4 {
            e.casseroles += 8
            e.rivaux.indices.forEach { e.rivaux[$0].rancune += 10 }
            e.borner()
            return PolResultat(texte: "📕 Tes mémoires « Ce que je n'ai jamais dit » règlent beaucoup de comptes. Avance : \(Format.argent(avance)). Tes anciens collègues ne te parlent plus.")
        }
        e.popularite += 4
        e.borner()
        return PolResultat(texte: "📕 Tes mémoires sortent : 480 pages, dont 200 sur ta jeunesse. Avance : \(Format.argent(avance)). Les critiques saluent un témoignage sincère.")
    }

    static func conferences(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard estAncien(e) else { return PolResultat(texte: "Il faut une carrière derrière soi pour donner des conférences.") }
        guard marquer("conferences", &j) else { return dejaFait }
        let cachet = (e.rangMax + 1) * (e.rangMax + 1) * 4_000
        j.argent += cachet
        e.popularite -= 1
        e.borner()
        return PolResultat(texte: "🎤 Tournée de conférences sur « l'art de décider » devant des cadres de banque. Cachet total : \(Format.argent(cachet)). Le monde de l'entreprise écoute ton expérience.")
    }

    static func creerFondation(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard estAncien(e) else { return PolResultat(texte: "Il faut une carrière pour créer une fondation à son nom.") }
        guard !e.fondation else { return PolResultat(texte: "Ta fondation existe déjà. Elle poursuit son travail.") }
        guard j.argent >= 50_000 else { return PolResultat(texte: "Il faut 50 000 € pour créer une fondation.") }
        e.fondation = true
        j.argent -= 50_000
        j.stats.karma += 10
        j.stats.bonheur += 5
        e.popularite += 6
        e.casseroles -= 10
        e.borner()
        return PolResultat(texte: "🏛️ La Fondation \(j.prenom) \(j.nom) voit le jour. Elle finance des bibliothèques, des bourses, et des programmes pour les jeunes des quartiers.")
    }

    static func chroniqueur(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard estAncien(e) else { return PolResultat(texte: "Les plateaux télé veulent des anciens ministres, pas des débutants.") }
        guard marquer("chroniqueur", &j) else { return dejaFait }
        j.argent += 25_000 + e.rangMax * 8_000
        if Double.random(in: 0...1) < 0.5 {
            e.popularite += 4
            e.borner()
            return PolResultat(texte: "📺 Chroniqueur" + j.g("", "se") + " dans une émission du soir. Tu commentes la politique avec le recul de quelqu'un qui a connu le pouvoir, et ça plaît.")
        }
        e.popularite -= 3
        e.borner()
        return PolResultat(texte: "📺 Tu t'es énervé" + j.g("", "e") + " en direct contre un autre invité. La séquence tourne en boucle sur les réseaux.")
    }

    static func conseilAdministration(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard estAncien(e) else { return PolResultat(texte: "Ton carnet d'adresses n'intéresse pas encore les entreprises.") }
        guard marquer("conseil_admin", &j) else { return dejaFait }
        let jetons = (e.rangMax + 1) * 15_000
        j.argent += jetons
        e.casseroles += 6
        j.stats.karma -= 2
        e.borner()
        return PolResultat(texte: "💼 Tu entres au conseil d'administration d'un grand groupe du BTP. \(Format.argent(jetons)) de jetons de présence par an pour quelques réunions. La presse parle de pantouflage.")
    }

    // MARK: - Effets

    static func appliquerPolProfond(_ p: PolEffets, _ e: inout PolEtat) {
        if let segs = p.segments {
            for (k, v) in segs { e.segments[k] = Stats.borne((e.segments[k] ?? 40) + v) }
        }
        if let pays = p.pays {
            e.pays.dette += pays["dette"] ?? 0
            e.pays.chomage += pays["chomage"] ?? 0
            e.pays.croissance += pays["croissance"] ?? 0
            e.pays.securite += Int((pays["securite"] ?? 0).rounded())
            e.pays.moral += Int((pays["moral"] ?? 0).rounded())
        }
        e.mobilisation += p.mobilisation ?? 0
        e.majorite += p.majorite ?? 0
        if let r = p.rival, let rival = e.rivalPrincipal, let i = e.rivaux.firstIndex(where: { $0.id == rival.id }) {
            e.rivaux[i].rancune += r
        }
    }

    // MARK: - Année

    static func anneeProfonde(_ j: inout Joueur, _ e: inout PolEtat, _ l: inout [String]) {
        let poste = e.mandat?.poste

        // Le pays
        var p = e.pays
        p.croissance += Double.random(in: -0.8...0.8) + Double(p.moral - 50) / 100 - (p.croissance - 1.3) * 0.25
        p.chomage += -(p.croissance - 1.5) * 0.3 + Double.random(in: -0.3...0.3)
        p.dette += 3 - p.croissance + Double.random(in: -1...1)
        p.moral += (p.croissance > 2 ? 2 : (p.croissance < 0 ? -3 : 0)) - e.mobilisation / 20 + Int.random(in: -3...3)
        p.securite += Int.random(in: -3...3)
        p.borner()
        e.pays = p

        // Jugement du bilan quand on gouverne
        if poste?.gouverne == true {
            let bilan = Int(((p.croissance - 1) * 1.5 - (p.chomage - 8) * 0.8 + Double(p.moral - 50) / 10).rounded())
            e.popularite += max(-6, min(6, bilan))
            l.append("📈 Bilan du pays : croissance \(format1(p.croissance)) %, chômage \(format1(p.chomage)) %, dette \(Int(p.dette)) % du PIB, moral \(p.moral)/100.")
        }

        // Les groupes d'électeurs reviennent lentement vers 40
        for s in PolSegment.allCases {
            let v = e.opinion(s)
            e.segments[s.rawValue] = v + (v > 40 ? -1 : (v < 40 ? 1 : 0))
        }

        // Colère sociale
        if e.mobilisation >= 60 && poste?.gouverne == true {
            e.popularite -= 5
            e.pays.moral -= 5
            l.append("✊ Grève générale contre ta politique : trains à l'arrêt, écoles fermées, et des centaines de milliers de manifestants.")
            if let derniere = e.loisVotees.last(where: { e.loisActives.contains($0) }), Double.random(in: 0...1) < 0.3,
               let loi = PolCatalogue.loi(derniere) {
                e.loisActives.removeAll { $0 == derniere }
                l.append("La rue a gagné : « \(loi.titre) » est retirée.")
            }
        }
        e.mobilisation -= 10

        // Rivaux
        for i in e.rivaux.indices {
            e.rivaux[i].rancune -= 2
            if Double.random(in: 0...1) < 0.05 { e.rivaux[i].niveau += 1 }
            let r = e.rivaux[i]
            if r.rancune >= 60 && Double.random(in: 0...1) < 0.15 {
                if Bool.random() {
                    e.casseroles += 6
                    l.append("🗡️ \(r.nomComplet) a fait fuiter une vieille histoire sur toi. Les journaux s'en emparent.")
                } else {
                    e.popularite -= 4
                    l.append("🗡️ \(r.nomComplet) t'a démoli" + j.g("", "e") + " en direct à la télé. On te reproche tes revirements.")
                }
            }
        }

        // Chef de parti
        if e.estChefDeParti {
            e.caisse += e.influence * 300 + 2_000
            e.influence += 1
            if Double.random(in: 0...1) < 0.4, e.dossiers.count < 5, let d = tirerDossier(kind: "parti", poste: "chef_parti", j, e) {
                e.dossiers.append(PolDossierEnAttente(dossierId: d.id, ageArrivee: j.age))
                l.append("📂 Ton parti a besoin de son chef (onglet Politique).")
            }
        }

        // Équipe
        var salaires = 0
        var partis: [String] = []
        for i in e.equipe.indices {
            salaires += e.equipe[i].salaire
            e.equipe[i].loyaute += Int.random(in: -6...3)
            if e.equipe[i].role == .garde { j.stats.sante += 1 }
            if e.equipe[i].role == .plume, poste != nil { e.popularite += 1 }
            if e.equipe[i].loyaute < 25 && Double.random(in: 0...1) < 0.3 {
                let m = e.equipe[i]
                partis.append(m.id.uuidString)
                e.casseroles += 10
                e.popularite -= 5
                l.append("🐍 \(m.nomComplet), ton " + m.role.titre.lowercased() + ", a vendu tes messages privés à la presse avant de démissionner.")
            }
        }
        e.equipe.removeAll { partis.contains($0.id.uuidString) }
        if salaires > 0 {
            payer(salaires, &j, &e)
            l.append("👥 Salaires de ton équipe : \(Format.argent(salaires)).")
        }

        // Gouvernement du joueur président (régime où le président gouverne)
        let sysAnnee = systeme(j)
        if poste == .president && !sysAnnee.presidentSymbolique {
            if let pm = e.premierMinistrePNJ {
                switch pm.trait {
                case "populaire": e.popularite += 2
                case "technocrate": e.pays.croissance += 0.3; e.popularite -= 1
                case "gaffeur":
                    if Double.random(in: 0...1) < 0.25 {
                        e.popularite -= 3
                        l.append("🤦 \(pm.nomComplet) a commis une gaffe diplomatique en conférence de presse. Deux ambassadeurs sont convoqués.")
                    }
                case "ambitieux":
                    if Double.random(in: 0...1) < 0.12 {
                        e.premierMinistrePNJ = nil
                        e.rivaux.append(PolRival(prenom: pm.prenom, nom: pm.nom, genre: pm.genre, partiId: e.partiId, rancune: 55, niveau: 5))
                        l.append("🗡️ \(pm.nomComplet) démissionne pour « préparer l'avenir ». L'avenir, c'est ta place.")
                    }
                default:
                    e.majorite += 1
                }
            } else if sysAnnee.existe(.premierMinistre) {
                e.popularite -= 2
                l.append("🏛️ Le pays n'a pas de chef de gouvernement. Les affaires courantes paralysent l'action publique.")
            }
            // Destitution
            if e.casseroles >= 85 && e.majorite < 40 && Double.random(in: 0...1) < 0.25 {
                terminerMandat(&j, &e, fin: "destitution")
                e.ineligibilite = max(e.ineligibilite, 3)
                l.append("⚖️ Le Parlement prononce ta destitution. Tu quittes le Palais dans un silence pesant.")
                e.titres.append(remplir("Historique : {prenom} {nom} destitué{e}", j, e))
            }
        }

        // Premier ministre joueur : motion de censure
        if poste == .premierMinistre, e.majorite < 45, e.popularite < 30, Double.random(in: 0...1) < 0.2 {
            terminerMandat(&j, &e, fin: "renversé" + j.g("", "e") + " par une motion de censure")
            l.append("🏛️ Motion de censure adoptée ! Ton gouvernement tombe. Tu remets ta démission.")
        }

        // Lobbys, crises, après-politique
        if let m = e.mandat, m.poste.rang >= 1, Double.random(in: 0...1) < 0.3, e.dossiers.count < 5,
           let d = tirerDossier(kind: "lobby", poste: m.poste.rawValue, j, e) {
            e.dossiers.append(PolDossierEnAttente(dossierId: d.id, ageArrivee: j.age))
            l.append("💼 Un lobby demande un rendez-vous discret (onglet Politique).")
        }
        if let m = e.mandat, m.poste.gouverne, Double.random(in: 0...1) < 0.4, e.dossiers.count < 5,
           let d = tirerDossier(kind: "crise", poste: m.poste.rawValue, j, e) {
            e.dossiers.append(PolDossierEnAttente(dossierId: d.id, ageArrivee: j.age))
            l.append("🚨 Crise : « \(d.title) ». Le pays attend ta réaction (onglet Politique).")
        }
        if estAncien(e), Double.random(in: 0...1) < 0.3, e.dossiers.count < 5,
           let d = tirerDossier(kind: "apres", poste: "ancien", j, e) {
            e.dossiers.append(PolDossierEnAttente(dossierId: d.id, ageArrivee: j.age))
        }
        e.borner()
    }

    static func format1(_ x: Double) -> String {
        String(format: "%.1f", x).replacingOccurrences(of: ".", with: ",")
    }

    /// État de départ pour un enfant du joueur (dynastie politique) : un peu d'influence et le même parti.
    static func heritage(_ e: PolEtat?) -> PolEtat? {
        guard let e = e, e.rangMax >= 2 else { return nil }
        var h = PolEtat()
        h.influence = min(40, e.rangMax * 6)
        h.popularite = 15 + min(15, e.rangMax * 2)
        h.casseroles = e.casseroles / 4
        return h
    }
}

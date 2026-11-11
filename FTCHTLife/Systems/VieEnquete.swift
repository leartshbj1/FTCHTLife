import Foundation

// L'enquête contre le joueur, étape par étape (signalement, filature, écoutes, perquisition),
// avec une réaction possible par an. La fuite à l'étranger et le mandat international.
// Les commerces de façade pour blanchir, et le contrôle fiscal.
// `VieMilieuEtat.enquete` contient l'étape (0…3).

// MARK: - Enquête

enum MilieuEnquete {

    static func etape(_ j: Joueur) -> Int? { VieMilieu.etat(j).enquete.map { min(3, max(0, $0)) } }

    static func titre(_ e: Int) -> String {
        switch e {
        case 0: return "Signalement"
        case 1: return "Filature"
        case 2: return "Écoutes"
        default: return "Perquisition en préparation"
        }
    }

    static func description(_ e: Int) -> String {
        switch e {
        case 0: return "Quelqu'un a parlé de toi à la police. Un dossier existe, encore mince."
        case 1: return "Des voitures banalisées, des visages qui reviennent. On te suit."
        case 2: return "Tes téléphones sont sur écoute. Chaque mot peut finir dans un procès-verbal."
        default: return "Les enquêteurs pensent en avoir assez. Une perquisition se prépare, peut-être pour l'année prochaine."
        }
    }

    static func reactions(_ e: Int, _ j: Joueur) -> [TraficOption] {
        let p = MilieuProtection.etat(j)
        switch e {
        case 0:
            return [TraficOption(label: "Faire le vide autour de toi", detail: "Moins d'activité, l'enquête avance moins vite"),
                    TraficOption(label: "Chercher qui t'a balancé", detail: "Peut tout arrêter. Peut tout aggraver."),
                    TraficOption(label: p.avocat > 0 ? "Prévenir ton avocat" : "Prendre un avocat", detail: "Il prépare ta défense dès maintenant")]
        case 1:
            return [TraficOption(label: "Changer toutes tes habitudes", detail: "Ralentit l'enquête, ton business en souffre"),
                    TraficOption(label: "Faire suivre les enquêteurs", detail: Format.argent(10_000) + ", savoir ce qu'ils savent"),
                    TraficOption(label: "Semer une fausse piste", detail: "Quitte ou double")]
        case 2:
            return [TraficOption(label: p.jetables ? "Durcir les règles au téléphone" : "Passer aux téléphones jetables", detail: "Les écoutes ne donnent presque plus rien"),
                    TraficOption(label: "Donner de fausses informations au téléphone", detail: "Les envoyer sur une mauvaise piste"),
                    TraficOption(label: "Ne plus parler de rien, à personne", detail: "L'enquête ralentit, la solitude pèse")]
        default:
            return [TraficOption(label: "Tout déménager cette nuit", detail: Format.argent(30_000) + ", moins de preuves, une partie du stock perdue"),
                    TraficOption(label: "Fuir à l'étranger", detail: "Tu abandonnes ton business. Un mandat international suivra."),
                    TraficOption(label: "Négocier avec le procureur", detail: "Donner d'autres noms. Le milieu pourrait l'apprendre.")]
        }
    }

    static func peutReagir(_ j: Joueur) -> Bool {
        etape(j) != nil && !VieMilieu.etat(j).actionsAnnee.contains("enquete_reaction") && !j.vieEtat.justice.enPrison
    }

    static func reagir(_ choix: Int, _ j: inout Joueur) -> [String] {
        guard let e = etape(j), peutReagir(j) else { return ["Tu as déjà réagi cette année. Bouger encore te rendrait suspect."] }
        VieMilieu.modifier(&j) { $0.actionsAnnee.append("enquete_reaction") }
        func frein(_ n: Int) { MilieuProtection.modifier(&j) { $0.frein += n } }
        func preuves(_ n: Int) { MilieuProtection.modifier(&j) { $0.preuvesFaibles += n } }
        func chaleur(_ n: Int) { VieMilieu.modifier(&j) { $0.chaleur += n } }
        func etapeA(_ n: Int?) { VieMilieu.modifier(&j) { $0.enquete = n } }
        switch (e, choix) {
        case (0, 0):
            frein(30); chaleur(-10)
            MilieuTrafic.modifier(&j) { b, _ in b.fidelite -= 5 }
            return ["Tu coupes les contacts inutiles, tu ranges, tu te fais oublier. Tes clients trouvent que tu es devenu difficile à joindre."]
        case (0, 1):
            j.stats.karma -= 6
            j.stats.borner()
            if VieHasard.reussi(0.4) {
                fermer(&j)
                return ["Tu as fini par savoir qui avait parlé. Une visite, une conversation à voix basse. Il est revenu sur sa déposition. Le dossier est classé."]
            }
            if VieHasard.reussi(0.35) {
                chaleur(12); etapeA(1)
                return ["Tes questions sont remontées jusqu'aux enquêteurs. Maintenant, ils savent que tu sais. Ils passent à la vitesse supérieure."]
            }
            return ["Tu cherches, tu interroges, tu ne trouves rien. Tout le monde a une tête de traître."]
        case (0, _):
            if MilieuProtection.etat(j).avocat == 0 {
                let l = MilieuProtection.choisirAvocat(1, &j)
                if MilieuProtection.etat(j).avocat == 0 { return [l] }
            }
            preuves(15)
            return ["Ton avocat épluche ce qui peut l'être et te donne des consignes : ne rien signer, ne rien dire, ne rien garder chez toi."]

        case (1, 0):
            frein(40)
            MilieuTrafic.modifier(&j) { b, _ in b.fidelite -= 6 }
            return ["Nouveaux trajets, nouveaux horaires, nouvelles voitures. Les filatures perdent ta trace. Ton business tourne moins bien sans toi."]
        case (1, 1):
            guard MilieuTrafic.payer(10_000, &j) else { return ["Il faut \(Format.argent(10_000))."] }
            if VieHasard.reussi(0.6) {
                frein(25); preuves(10)
                return ["Un ancien gendarme suit ceux qui te suivent. Tu sais maintenant qui ils sont, où ils se garent et ce qu'ils cherchent."]
            }
            chaleur(15)
            return ["Ton homme s'est fait repérer. Les enquêteurs savent maintenant que tu les surveilles. Ça ne les a pas découragés."]
        case (1, _):
            if VieHasard.reussi(0.5) {
                etapeA(0); chaleur(-5)
                return ["Pendant des semaines, tu emmènes les filatures dans une vie parfaitement banale. Ils finissent par douter."]
            }
            chaleur(10); etapeA(2)
            return ["Ta fausse piste était trop parfaite. Les enquêteurs ont compris, et demandent des écoutes."]

        case (2, 0):
            if !MilieuProtection.etat(j).jetables { MilieuProtection.modifier(&j) { $0.jetables = true } }
            frein(40)
            return ["Plus rien d'important ne passe par un téléphone. Les écoutes enregistrent des heures de silence et de banalités."]
        case (2, 1):
            if VieHasard.reussi(0.45) {
                etapeA(1); preuves(20)
                return ["Tu parles d'une livraison qui n'existe pas. Les policiers mobilisent quarante hommes sur un parking vide. Le juge n'apprécie pas."]
            }
            if VieHasard.reussi(0.55) {
                chaleur(15)
                return ["Ta mise en scène sonnait faux. Les enquêteurs ont compris que tu savais. Ils notent tout, y compris ça."]
            }
            return ["Tes fausses pistes se perdent dans le dossier. Peut-être que personne ne les a écoutées."]
        case (2, _):
            frein(25)
            j.stats.bonheur -= 8
            j.stats.borner()
            return ["Tu ne dis plus rien d'important à personne : ni à ta famille, ni à tes amis. Les enquêteurs n'entendent rien. Toi, tu te sens seul."]

        case (3, 0):
            guard MilieuTrafic.payer(30_000, &j) else { return ["Il faut \(Format.argent(30_000)) pour tout déménager."] }
            preuves(35)
            MilieuTrafic.modifier(&j) { b, _ in for i in b.lignes.indices { b.lignes[i].stock /= 2 } }
            return ["Une nuit entière à tout charger dans des camionnettes. Au matin, les planques sont vides. Une partie du stock n'a pas survécu au voyage."]
        case (3, 1):
            return fuir(&j)
        default:
            guard MilieuProtection.etat(j).avocat > 0 else { return ["Sans avocat, personne ne négocie avec un procureur."] }
            j.stats.karma -= 5
            j.stats.borner()
            if VieHasard.reussi(0.25) {
                VieMilieu.modifier(&j) { $0.balance = true; $0.respect -= 20 }
                fermer(&j)
                VieSysteme.signaler("balance", &j)
                return ["Le procureur accepte. Ton dossier est classé. Mais dans le milieu, une rumeur circule : tu as donné des noms. Tu es devenu une balance."]
            }
            if VieHasard.reussi(0.4) {
                fermer(&j)
                VieMilieu.modifier(&j) { $0.respect -= 5 }
                return ["Ton avocat a négocié dans un bureau sans fenêtre. Tu as donné ce qu'il fallait, sans que personne ne le sache. Le dossier est classé."]
            }
            preuves(10)
            return ["Le procureur écoute, puis refuse. Il veut plus gros que toi. Ton avocat a au moins gagné du temps."]
        }
    }

    static func fermer(_ j: inout Joueur) {
        VieMilieu.modifier(&j) { $0.enquete = nil }
        MilieuProtection.modifier(&j) { $0.frein = 0; $0.preuvesFaibles = 0 }
        VieSysteme.signaler("enquete_classee", &j)
    }

    // MARK: Fuite et mandat international

    static func fuir(_ j: inout Joueur) -> [String] {
        let m = VieMilieu.etat(j)
        guard m.argentSale + j.argent >= 50_000 else { return ["Fuir coûte cher : il faut au moins \(Format.argent(50_000))."] }
        _ = MilieuTrafic.payer(50_000, &j)
        VieMilieu.modifier(&j) { $0.enquete = nil; $0.trafic = nil; $0.coup = nil; $0.chaleur = 30 }
        MilieuProtection.modifier(&j) { $0.recherche = true; $0.frein = 0; $0.preuvesFaibles = 0; $0.policiers = 0; $0.douaniers = 0 }
        j.stats.bonheur -= 15
        j.stats.borner()
        VieSysteme.signaler("fuite_etranger", &j)
        return ["Un faux passeport, un aller simple, une valise. Les enquêteurs trouvent un appartement vide. Ton business s'effondre sans toi. Un mandat d'arrêt international porte désormais ton nom."]
    }

    static func seRendre(_ j: inout Joueur) -> [String] {
        guard MilieuProtection.etat(j).recherche else { return [] }
        MilieuProtection.modifier(&j) { $0.recherche = false }
        let mois = Int(Double(Int.random(in: 36...96)) * 0.6)
        return VieMilieu.arreter("association de malfaiteurs", mois: mois,
                                 texte: "Tu te présentes au consulat avec ton vrai passeport. Le retour se fait menotté, mais le juge tient compte de ta reddition.", &j)
    }

    // MARK: +1 an

    static func vieillir(_ j: inout Joueur) -> [String] {
        var lignes: [String] = []
        let enPrison = j.vieEtat.justice.enPrison
        let p = MilieuProtection.etat(j)

        // En prison (par un événement), la fuite est finie.
        if p.recherche && enPrison { MilieuProtection.modifier(&j) { $0.recherche = false } }
        // En fuite : Interpol peut te retrouver.
        if p.recherche && !enPrison {
            if VieHasard.reussi(VieBonus.arrestation(0.12)) {
                MilieuProtection.modifier(&j) { $0.recherche = false }
                VieSysteme.signaler("extradition", &j)
                lignes += VieMilieu.arreter("association de malfaiteurs", mois: Int.random(in: 60...180),
                                            texte: "Interpol t'a retrouvé. Arrêté à l'aube dans ton appartement d'exil, tu es extradé une semaine plus tard.", &j)
            }
            return lignes
        }

        let e = VieMilieu.etat(j)
        if let et = etape(j) {
            guard !enPrison else { return [] }
            if et >= 3 {
                // La perquisition a lieu.
                let reussite = VieHasard.borne((0.8 - Double(p.preuvesFaibles) / 100) * MilieuProtection.facteurArrestation(j))
                if VieHasard.reussi(VieBonus.arrestation(reussite)) {
                    let base = 24 + e.rang * 24 + (e.trafic != nil ? 24 : 0) + e.argentSale / 50_000
                    let mois = Int(Double(min(base, 360)) * (1 - Double(p.preuvesFaibles) / 100))
                    let garde = p.comptable ? e.argentSale / 2 : 0
                    lignes += VieMilieu.arreter("association de malfaiteurs", mois: max(6, mois),
                                                texte: "6 h du matin. La porte vole en éclats. Perquisition. Tout ce que l'enquête a rassemblé depuis des années se referme sur toi.", &j)
                    VieMilieu.modifier(&j) { $0.argentSale = garde }
                    MilieuProtection.modifier(&j) { $0.frein = 0; $0.preuvesFaibles = 0 }
                    if garde > 0 { lignes.append("Ton comptable a mis \(Format.argent(garde)) à l'abri avant la saisie.") }
                } else {
                    VieMilieu.modifier(&j) { $0.enquete = 1 }
                    MilieuProtection.modifier(&j) { $0.frein = 0 }
                    lignes.append("La perquisition ne donne presque rien. Les enquêteurs repartent furieux. Ils ne lâcheront pas, mais ils devront tout reprendre.")
                }
                return lignes
            }
            let progression = VieHasard.borne((0.35 + Double(e.chaleur) / 250) * MilieuProtection.facteurArrestation(j) * (1 - Double(p.frein) / 100)
                                              * (et == 2 && p.jetables ? 0.5 : 1))
            let classement = 0.3 + 0.1 * Double(p.avocat) + (p.juge ? 0.2 : 0)
            if VieHasard.reussi(progression) {
                VieMilieu.modifier(&j) { $0.enquete = et + 1 }
                lignes.append("L'enquête contre toi avance : \(titre(et + 1).lowercased()). \(description(et + 1))")
            } else if e.chaleur < 15 + 10 * p.avocat && VieHasard.reussi(classement) {
                fermer(&j)
                lignes.append("Ton avocat t'apprend que l'enquête te visant a été classée faute de preuves.")
            }
            MilieuProtection.modifier(&j) { $0.frein = 0 }
        } else if !enPrison && (e.membre || e.trafic != nil) && VieHasard.reussi(Double(e.chaleur) / 250 * MilieuProtection.facteurOuverture(j)) {
            VieMilieu.modifier(&j) { $0.enquete = 0 }
            VieSysteme.signaler("enquete_ouverte", &j)
            lignes.append("Quelqu'un a parlé de toi à la police. Une enquête est ouverte : pour l'instant, un simple signalement.")
        }
        return lignes
    }

    static func tags(_ j: Joueur) -> Set<String> {
        guard let e = etape(j) else { return [] }
        return [["enquete_signalement", "enquete_filature", "enquete_ecoutes", "enquete_perquisition"][e]]
    }
}

// MARK: - Commerces de façade

struct MilieuFacade: Identifiable, Equatable {
    let id: String
    let nom: String
    let prix: Int
    /// Argent sale blanchissable par an.
    let capacite: Int
    /// Revenu légal par an.
    let revenu: Int
    let rangMin: Int
}

enum MilieuFacades {

    static let liste: [MilieuFacade] = [
        MilieuFacade(id: "laverie", nom: "Une laverie automatique", prix: 60_000, capacite: 80_000, revenu: 6_000, rangMin: 0),
        MilieuFacade(id: "coiffure", nom: "Un salon de coiffure", prix: 80_000, capacite: 100_000, revenu: 8_000, rangMin: 0),
        MilieuFacade(id: "snack", nom: "Un snack", prix: 90_000, capacite: 120_000, revenu: 9_000, rangMin: 0),
        MilieuFacade(id: "telephonie", nom: "Une boutique de téléphonie", prix: 100_000, capacite: 150_000, revenu: 8_000, rangMin: 0),
        MilieuFacade(id: "lavage", nom: "Une station de lavage", prix: 120_000, capacite: 180_000, revenu: 10_000, rangMin: 1),
        MilieuFacade(id: "garage", nom: "Un garage", prix: 150_000, capacite: 220_000, revenu: 14_000, rangMin: 1),
        MilieuFacade(id: "bar", nom: "Un bar", prix: 200_000, capacite: 300_000, revenu: 18_000, rangMin: 1),
        MilieuFacade(id: "restaurant", nom: "Un restaurant", prix: 400_000, capacite: 600_000, revenu: 30_000, rangMin: 2),
        MilieuFacade(id: "boite", nom: "Une boîte de nuit", prix: 800_000, capacite: 1_200_000, revenu: 60_000, rangMin: 3),
        MilieuFacade(id: "hotel", nom: "Un hôtel", prix: 1_500_000, capacite: 2_500_000, revenu: 100_000, rangMin: 3),
    ]

    static func facade(_ id: String) -> MilieuFacade? { liste.first { $0.id == id } }

    static func possedees(_ j: Joueur) -> [MilieuFacade] { (VieMilieu.etat(j).facades ?? []).compactMap { facade($0) } }

    static func capacite(_ j: Joueur) -> Int { possedees(j).reduce(0) { $0 + $1.capacite } }

    static func capaciteRestante(_ j: Joueur) -> Int { max(0, capacite(j) - (VieMilieu.etat(j).blanchiFacades ?? 0)) }

    static func commission(_ j: Joueur) -> Int { MilieuProtection.etat(j).comptable ? 5 : 8 }

    static func accessibles(_ j: Joueur) -> [MilieuFacade] {
        let m = VieMilieu.etat(j)
        let rang = m.membre ? m.rang : 0
        let deja = Set(m.facades ?? [])
        return liste.filter { $0.rangMin <= rang && !deja.contains($0.id) }
    }

    static func acheter(_ f: MilieuFacade, _ j: inout Joueur) -> String {
        if (VieMilieu.etat(j).facades ?? []).count >= 5 { return "Cinq commerces, c'est déjà beaucoup. Un de plus et le fisc va s'intéresser à ta réussite." }
        guard MilieuTrafic.payer(f.prix, &j) else { return "\(f.nom) coûte \(Format.argent(f.prix))." }
        VieMilieu.modifier(&j) { $0.facades = ($0.facades ?? []) + [f.id] }
        VieSysteme.signaler("facade_achat", &j)
        return "Tu rachètes \(f.nom.lowercased()). Une vraie enseigne, de vrais clients, une vraie comptabilité. Et des recettes qui vont bientôt dépasser de loin le nombre de clients."
    }

    static func vendre(_ id: String, _ j: inout Joueur) -> String {
        guard let f = facade(id) else { return "" }
        VieMilieu.modifier(&j) { $0.facades = ($0.facades ?? []).filter { $0 != id } }
        let prix = f.prix * 6 / 10
        j.argent += prix
        return "Tu revends \(f.nom.lowercased()) pour \(Format.argent(prix))."
    }

    /// Blanchit par les commerces, dans la limite de leur capacité annuelle.
    static func blanchir(_ j: inout Joueur) -> String {
        let m = VieMilieu.etat(j)
        let somme = min(m.argentSale, capaciteRestante(j))
        guard somme > 0 else {
            return m.argentSale == 0 ? "Tu n'as pas d'argent sale à blanchir." : "Tes commerces ont déjà blanchi tout ce qu'ils pouvaient cette année sans éveiller les soupçons."
        }
        let net = somme * (100 - commission(j)) / 100
        j.argent += net
        VieMilieu.modifier(&j) {
            $0.argentSale -= somme
            $0.blanchiFacades = ($0.blanchiFacades ?? 0) + somme
            $0.blanchiAnnee = ($0.blanchiAnnee ?? 0) + somme
        }
        VieSysteme.signaler("blanchiment", &j)
        return "Tes commerces déclarent des recettes un peu trop belles. \(Format.argent(net)) ressortent propres, en salaires et en dividendes."
    }

    /// Risque de contrôle fiscal cette année.
    static func risqueControle(_ j: Joueur) -> Double {
        let m = VieMilieu.etat(j)
        let p = MilieuProtection.etat(j)
        let blanchi = m.blanchiAnnee ?? 0
        var r = 0.02 * Double(possedees(j).count)
        r += Double(max(0, blanchi - capacite(j))) / 400_000
        if j.argent > 1_000_000 && j.emploi == nil && possedees(j).isEmpty { r += 0.1 }
        r *= (p.comptable ? 0.5 : 1) * (p.preteNom ? 0.7 : 1)
        return min(0.6, r)
    }

    static func vieillir(_ j: inout Joueur) -> [String] {
        let m = VieMilieu.etat(j)
        guard m.facades != nil || (m.blanchiAnnee ?? 0) > 0 else { return [] }
        var lignes: [String] = []
        let revenu = possedees(j).reduce(0) { $0 + $1.revenu }
        if revenu > 0 {
            j.argent += revenu
            lignes.append("Tes commerces ont rapporté \(Format.argent(revenu)) de bénéfices légaux.")
        }
        if !j.vieEtat.justice.enPrison && VieHasard.reussi(risqueControle(j)) {
            let redressement = min(max(0, j.argent), max(5_000, (m.blanchiAnnee ?? 0) * 4 / 10 + revenu))
            j.argent -= redressement
            VieSysteme.signaler("controle_fiscal", &j)
            lignes.append("Contrôle fiscal. Deux inspecteurs passent trois semaines à éplucher tes comptes. Redressement : \(Format.argent(redressement)).")
            if VieHasard.reussi(0.3) {
                if let f = possedees(j).randomElement() {
                    VieMilieu.modifier(&j) { $0.facades = ($0.facades ?? []).filter { $0 != f.id } }
                    lignes.append("\(f.nom) est placé sous scellés.")
                }
                if VieMilieu.etat(j).enquete == nil {
                    VieMilieu.modifier(&j) { $0.enquete = 0 }
                    VieSysteme.signaler("enquete_ouverte", &j)
                    lignes.append("Le fisc transmet ton dossier à la justice. Une enquête est ouverte.")
                }
            }
        }
        VieMilieu.modifier(&j) { $0.blanchiAnnee = 0; $0.blanchiFacades = 0 }
        return lignes
    }

    static func tags(_ j: Joueur) -> Set<String> {
        (VieMilieu.etat(j).facades ?? []).isEmpty ? [] : ["facade"]
    }
}

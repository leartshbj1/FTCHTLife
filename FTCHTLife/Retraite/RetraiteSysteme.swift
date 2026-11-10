import Foundation

/// Règles du module « Vieillesse et maison de retraite ».
/// Toutes les fonctions modifient le joueur et l'état du module passés en `inout` ; elles ne touchent pas au moteur.
/// Branchement : voir docs/RETRAITE.md.
enum RetraiteSysteme {

    // MARK: - Réglages

    /// Âge à partir duquel l'onglet Retraite a du sens.
    static let ageOnglet = 60
    /// Âge minimum pour entrer de soi-même en maison de retraite.
    static let ageEntreeChoisie = 65
    /// Âge à partir duquel les enfants peuvent te placer.
    static let agePlacement = 75
    /// Années de cavale avant que la résidence arrête de te chercher.
    static let anneesAvantLiberte = 3
    static let prixCarton = 2

    // MARK: - Tags pour les événements

    /// Tags à ajouter à `GameEngine.tags(_:)`.
    static func tags(_ e: RetraiteEtat?) -> Set<String> {
        guard let e else { return [] }
        var t: Set<String> = []
        if e.enResidence { t.insert("maison_retraite") }
        if e.enResidence && e.imposee { t.insert("maison_retraite_imposee") }
        if e.enCavale { t.insert("en_cavale") }
        if e.romance != nil { t.insert("romance_residence") }
        if !e.petitsEnfants.isEmpty { t.insert("grand_parent") }
        if e.anneesSansVisite >= 3 && e.petitsEnfants.contains(where: { $0.age >= 6 }) { t.insert("petits_enfants_absents") }
        if !e.voyagesFaits.isEmpty { t.insert("senior_voyageur") }
        if e.lotoGains >= 3 { t.insert("champion_loto") }
        return t
    }

    // MARK: - Une année passe

    /// À appeler dans `GameEngine.vieillir()`, après l'âge +1 et le salaire/la retraite.
    static func annee(_ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteBilan {
        var b = RetraiteBilan()
        guard j.vivant else { return b }
        petitsEnfantsAnnee(&j, &e, &b)
        if e.enCavale {
            cavaleAnnee(&j, &e, &b)
        } else if e.enResidence {
            residenceAnnee(&j, &e, &b)
        } else {
            placementEventuel(&j, &e, &b)
        }
        e.vigilance = max(0, e.vigilance - 5)
        j.stats.borner()
        return b
    }

    private static func petitsEnfantsAnnee(_ j: inout Joueur, _ e: inout RetraiteEtat, _ b: inout RetraiteBilan) {
        for i in e.petitsEnfants.indices {
            e.petitsEnfants[i].age += 1
            e.petitsEnfants[i].lien = Stats.borne(e.petitsEnfants[i].lien + Int.random(in: -4...1))
        }
        // Naissances : tes enfants adultes font des enfants.
        if j.age >= 38 {
            for enfant in j.relations where enfant.type == .enfant && enfant.vivant && (22...45).contains(enfant.age) {
                let deja = e.petitsEnfants.filter { $0.parentId == enfant.id }.count
                guard deja < 3, Double.random(in: 0...1) < 0.10 else { continue }
                let g = Genre.allCases.randomElement()!
                let pe = RetraitePetitEnfant(prenom: Donnees.prenom(g), genre: g, age: 0, parentId: enfant.id,
                                             parentPrenom: enfant.prenom, lien: Int.random(in: 60...90))
                e.petitsEnfants.append(pe)
                j.stats.bonheur += 8
                b.lignes.append(texte(RetraiteCatalogue.phrases.naissancePetitEnfant.randomElement()!, j,
                                      petitEnfant: pe, enfant: enfant.prenom))
                b.signaux.append("petit_enfant")
            }
        }
        // Visites (ou absence de visites).
        let enAgeDeVenir = e.petitsEnfants.filter { $0.age >= 6 }
        guard j.age >= 60, !enAgeDeVenir.isEmpty, !e.enCavale else { return }
        let heritage = e.heritageEvoqueAge.map { j.age - $0 <= 1 } ?? false
        var visiteurs: [Int] = []
        for i in e.petitsEnfants.indices where e.petitsEnfants[i].age >= 6 {
            var chance = 0.08 + Double(e.petitsEnfants[i].lien) / 400
            if j.argent >= 100_000 { chance += 0.12 }
            if heritage { chance += 0.35 }
            if e.enResidence { chance -= 0.04 }
            if Double.random(in: 0...1) < chance { visiteurs.append(i) }
        }
        if let i = visiteurs.randomElement() {
            for k in visiteurs {
                e.petitsEnfants[k].derniereVisite = j.age
                e.petitsEnfants[k].lien = Stats.borne(e.petitsEnfants[k].lien + 6)
            }
            e.anneesSansVisite = 0
            j.stats.bonheur += 4 + 2 * visiteurs.count
            b.lignes.append(texte(RetraiteCatalogue.phrases.visite.randomElement()!, j, petitEnfant: e.petitsEnfants[i]))
            b.signaux.append("visite_petits_enfants")
        } else {
            e.anneesSansVisite += 1
            if j.age >= 65 && (e.anneesSansVisite >= 2 || e.enResidence) {
                j.stats.bonheur -= 3
                b.lignes.append(texte(RetraiteCatalogue.phrases.aucuneVisite.randomElement()!, j))
            }
        }
    }

    private static func cavaleAnnee(_ j: inout Joueur, _ e: inout RetraiteEtat, _ b: inout RetraiteBilan) {
        e.anneesCavale += 1
        let chanceRattrape = max(0.10, 0.32 - Double(j.stats.intelligence) / 500)
        if Double.random(in: 0...1) < chanceRattrape, let r = RetraiteCatalogue.residence(e.derniereResidenceId) ?? RetraiteCatalogue.moinsChere {
            entrer(r, imposee: true, &j, &e, garderResidents: true)
            e.vigilance = min(60, e.vigilance + 25)
            j.stats.bonheur -= 10
            b.lignes.append(texte(RetraiteCatalogue.phrases.rattrape.randomElement()!, j, residence: r.nom))
            b.signaux.append("cavale_rattrape")
        } else if e.anneesCavale >= anneesAvantLiberte {
            e.enCavale = false
            e.anneesCavale = 0
            j.stats.bonheur += 15
            b.lignes.append(texte(RetraiteCatalogue.phrases.liberte.randomElement()!, j))
            b.signaux.append("cavale_liberte")
        } else {
            j.stats.bonheur += 4
            j.stats.sante -= 2
            b.lignes.append(texte(RetraiteCatalogue.phrases.cavale.randomElement()!, j))
        }
    }

    private static func residenceAnnee(_ j: inout Joueur, _ e: inout RetraiteEtat, _ b: inout RetraiteBilan) {
        guard var r = e.residence else {
            // Résidence disparue du catalogue : retour à la maison.
            e.residenceId = nil
            return
        }
        e.anneesEnResidence += 1

        // La pension.
        if j.argent >= r.prixAnnuel {
            j.argent -= r.prixAnnuel
        } else if j.relations.contains(where: { $0.type == .enfant && $0.vivant && $0.age >= 25 }) {
            for i in j.relations.indices where j.relations[i].type == .enfant && j.relations[i].vivant {
                j.relations[i].lien = Stats.borne(j.relations[i].lien - 6)
            }
            b.lignes.append("Tu n'as plus de quoi payer \(r.nom) : tes enfants règlent la pension (\(Format.argent(r.prixAnnuel))) en soupirant très fort au téléphone.")
        } else if let moins = RetraiteCatalogue.moinsChere, moins.id != r.id {
            b.lignes.append("Plus un sou pour payer \(r.nom). L'aide sociale te transfère à \(moins.nom). Ta nouvelle chambre donne sur le local poubelles.")
            e.residenceId = moins.id
            e.derniereResidenceId = moins.id
            e.imposee = true
            r = moins
        } else {
            b.lignes.append("L'aide sociale paie ta pension à \(r.nom). La directrice te sert la soupe avec un regard appuyé.")
        }

        // Effets de l'établissement.
        j.stats.sante += (r.confort - 45) / 15
        j.stats.bonheur += (r.ambiance - 50) / 12 - (e.imposee ? 2 : 0)
        if Double.random(in: 0...1) < 0.5 {
            b.lignes.append(texte(RetraiteCatalogue.phrases.anneeResidence.randomElement()!, j, residence: r.nom))
        }

        // Les autres pensionnaires.
        for i in e.residents.indices where e.residents[i].vivant {
            e.residents[i].age += 1
            e.residents[i].lien = Stats.borne(e.residents[i].lien + Int.random(in: -3...1))
            let res = e.residents[i]
            let risque = 0.04 + Double(max(0, res.age - 82)) * 0.012
            if Double.random(in: 0...1) < risque {
                e.residents[i].vivant = false
                if let rid = res.relationId, let k = j.relations.firstIndex(where: { $0.id == rid }) {
                    j.relations[k].vivant = false
                }
                b.lignes.append("🕊️ " + texte(RetraiteCatalogue.noms.phrasesDeces.randomElement()!, j, resident: res))
                if res.statut.estRomance {
                    j.stats.bonheur -= 20
                    b.lignes.append("Tu as perdu \(res.prenom), ton grand amour de couloir. La résidence entière porte un brassard noir.")
                    b.signaux.append("veuvage_residence")
                } else if res.statut == .ami {
                    j.stats.bonheur -= 6
                } else if res.statut == .rival {
                    j.stats.bonheur += 2
                    b.lignes.append("Tu as gagné le duel final contre \(res.prenom) : tu lui as survécu.")
                }
            } else if res.statut == .rival && res.lien >= 40 {
                e.residents[i].statut = .connaissance
            }
        }
        // On garde les disparus récents en mémoire (romance comprise), mais pas indéfiniment.
        let morts = e.residents.filter { !$0.vivant }
        if morts.count > 12 {
            let aRetirer = Set(morts.prefix(morts.count - 12).map(\.id))
            e.residents.removeAll { aRetirer.contains($0.id) }
        }
        // Nouveaux arrivants.
        var arrivees = 0
        while e.residentsVivants.count < 6 && arrivees < 2 {
            let n = nouveauResident(ageJoueur: j.age)
            e.residents.append(n)
            arrivees += 1
            if arrivees == 1 {
                b.lignes.append(texte(RetraiteCatalogue.noms.phrasesArrivee.randomElement()!, j, resident: n))
            }
        }
    }

    /// Les enfants (ou les services sociaux) décident de te placer.
    private static func placementEventuel(_ j: inout Joueur, _ e: inout RetraiteEtat, _ b: inout RetraiteBilan) {
        guard j.age >= agePlacement, !RetraiteCatalogue.residences.isEmpty else { return }
        let enfants = j.relations.filter { $0.type == .enfant && $0.vivant && $0.age >= 25 }
        var chance: Double
        if enfants.isEmpty {
            guard j.age >= 85, j.stats.sante < 30 else { return }
            chance = 0.18
        } else {
            let lienMoyen = enfants.map(\.lien).reduce(0, +) / enfants.count
            chance = 0.04
            if j.stats.sante < 40 { chance += 0.12 }
            if j.stats.sante < 20 { chance += 0.15 }
            chance += Double(max(0, j.age - 80)) * 0.012
            if lienMoyen < 35 { chance += 0.08 }
            if j.relations.contains(where: { $0.type == .partenaire && $0.vivant }) { chance -= 0.04 }
        }
        guard Double.random(in: 0...1) < chance else { return }

        // Les enfants regardent d'abord le prix.
        let abordables = RetraiteCatalogue.residences.filter { $0.prixAnnuel * 3 <= max(j.argent, 0) }
        let lienMoyen = enfants.isEmpty ? 0 : enfants.map(\.lien).reduce(0, +) / enfants.count
        let choix: RetraiteResidence
        if !enfants.isEmpty && lienMoyen >= 70, let belle = abordables.suffix(3).randomElement() {
            choix = belle
        } else {
            choix = RetraiteCatalogue.residences.prefix(3).randomElement() ?? RetraiteCatalogue.residences[0]
        }
        entrer(choix, imposee: true, &j, &e)
        j.stats.bonheur -= 12
        let modele = enfants.isEmpty ? RetraiteCatalogue.phrases.placementServicesSociaux : RetraiteCatalogue.phrases.placementImpose
        b.lignes.append("🏥 " + texte(modele.randomElement()!, j, residence: choix.nom))
        b.signaux.append("maison_retraite_imposee")
    }

    // MARK: - Entrer, sortir

    static func entrer(_ r: RetraiteResidence, imposee: Bool, _ j: inout Joueur, _ e: inout RetraiteEtat, garderResidents: Bool = false) {
        let memeResidence = e.derniereResidenceId == r.id
        e.residenceId = r.id
        e.derniereResidenceId = r.id
        e.imposee = imposee
        e.enCavale = false
        e.anneesCavale = 0
        e.tunnel = 0
        if !(garderResidents && memeResidence) {
            e.anneesEnResidence = 0
            // Une romance survit au déménagement, les autres restent derrière.
            e.residents = e.residents.filter { $0.vivant && $0.statut.estRomance }
        }
        while e.residentsVivants.count < 5 {
            e.residents.append(nouveauResident(ageJoueur: j.age))
        }
    }

    static func nouveauResident(ageJoueur: Int) -> RetraiteResident {
        let n = RetraiteCatalogue.noms
        let g = Genre.allCases.randomElement()!
        let prenom = (g == .femme ? n.prenomsFemmes : n.prenomsHommes).randomElement() ?? "Lucien"
        return RetraiteResident(prenom: prenom, nom: n.noms.randomElement() ?? "Gourdin", genre: g,
                                age: max(68, ageJoueur + Int.random(in: -6...12)),
                                trait: n.traits.randomElement() ?? "se plaint de la soupe",
                                lien: Int.random(in: 25...60))
    }

    static func peutVisiterResidences(_ j: Joueur, _ e: RetraiteEtat) -> Bool {
        j.vivant && j.age >= ageEntreeChoisie && !e.enResidence && !e.enCavale
    }

    /// Entrer de son plein gré dans une résidence.
    static func sInstaller(_ r: RetraiteResidence, _ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard peutVisiterResidences(j, e) else { return RetraiteResultat(texte: "Ce n'est pas possible pour l'instant.") }
        guard j.argent >= r.prixAnnuel else {
            return RetraiteResultat(texte: "La directrice a regardé ton relevé de compte, puis la porte. Il faut \(Format.argent(r.prixAnnuel)) par an.")
        }
        entrer(r, imposee: false, &j, &e)
        j.stats.bonheur += 4
        let accueil = [
            "Bienvenue à \(r.nom) ! On t'a remis un badge, un plan des couloirs et un sifflet « en cas de besoin ».",
            "Tu poses tes valises à \(r.nom). Ta voisine de chambre t'a déjà résumé la vie de tout le monde.",
            "Te voilà à \(r.nom). L'animatrice t'a serré{e} dans ses bras pendant 40 secondes. Tu ne la connais pas.",
        ].randomElement()!
        return RetraiteResultat(texte: texte(accueil, j), signaux: ["maison_retraite_entree"])
    }

    /// Partir d'une résidence choisie. La romance part avec toi et devient ton/ta partenaire.
    static func quitter(_ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard let r = e.residence else { return RetraiteResultat(texte: "Tu ne vis pas en résidence.") }
        guard !e.imposee else { return RetraiteResultat(texte: "Tes enfants ont signé les papiers. Il va falloir négocier… ou t'évader.") }
        var texteSortie = "Tu as rendu ta chambre à \(r.nom). L'aide-soignante a pleuré. Le cuisinier, beaucoup moins."
        sortir(&j, &e, &texteSortie)
        return RetraiteResultat(texte: texte(texteSortie, j), signaux: ["maison_retraite_sortie"])
    }

    private static func sortir(_ j: inout Joueur, _ e: inout RetraiteEtat, _ texteSortie: inout String) {
        if let amour = e.romance, let rid = amour.relationId, j.relations.contains(where: { $0.id == rid && $0.vivant }) {
            texteSortie += " \(amour.prenom) part avec toi, valise dans une main, déambulateur dans l'autre."
        } else if let amour = e.romance, !j.relations.contains(where: { $0.type == .partenaire && $0.vivant }) {
            j.relations.append(Relation(prenom: amour.prenom, nom: amour.nom, genre: amour.genre, type: .partenaire,
                                        age: amour.age, lien: amour.lien))
            texteSortie += " \(amour.prenom) part avec toi, valise dans une main, déambulateur dans l'autre."
        }
        e.residenceId = nil
        e.imposee = false
        e.anneesEnResidence = 0
        e.tunnel = 0
        e.residents = []
    }

    /// Négocier avec tes enfants pour quitter une résidence imposée (une fois par an).
    static func negocierSortie(_ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard e.enResidence, e.imposee else { return RetraiteResultat(texte: "Personne ne te retient.") }
        guard marquer(&j, "ret_negocier") else { return dejaFait }
        let enfants = j.relations.filter { $0.type == .enfant && $0.vivant }
        let lienMoyen = enfants.isEmpty ? 40 : enfants.map(\.lien).reduce(0, +) / enfants.count
        var chance = 0.12 + Double(j.stats.intelligence) / 400 + Double(lienMoyen) / 400
        if j.stats.sante >= 60 { chance += 0.15 }
        if j.stats.sante < 30 { chance -= 0.10 }
        if Double.random(in: 0...1) < chance {
            var t = "Après un plaidoyer de 45 minutes avec diapositives, tes enfants cèdent : tu rentres chez toi !"
            sortir(&j, &e, &t)
            j.stats.bonheur += 15
            return RetraiteResultat(texte: texte(t, j), signaux: ["maison_retraite_sortie"])
        }
        for i in j.relations.indices where j.relations[i].type == .enfant && j.relations[i].vivant {
            j.relations[i].lien = Stats.borne(j.relations[i].lien - 3)
        }
        j.stats.bonheur -= 4
        return RetraiteResultat(texte: [
            "Tes enfants ont écouté tes arguments, hoché la tête, puis parlé de la météo.",
            "Ta fille a dit « on verra l'année prochaine ». Elle dit ça depuis trois ans.",
            "Ton fils a répondu par un émoji pouce. La négociation est close.",
        ].randomElement()!)
    }

    // MARK: - Évasion

    enum MethodeEvasion: String, CaseIterable, Identifiable {
        case draps, deguisement, marche, chocolats, malaise, tunnel

        var id: String { rawValue }

        var titre: String {
            switch self {
            case .draps: return "Draps noués par la fenêtre"
            case .deguisement: return "Se déguiser en livreur"
            case .marche: return "Disparaître à la sortie au marché"
            case .chocolats: return "Soudoyer le gardien de nuit"
            case .malaise: return "Simuler un malaise, fuir l'ambulance"
            case .tunnel: return "Creuser un tunnel à la cuillère"
            }
        }

        var icone: String {
            switch self {
            case .draps: return "bed.double.fill"
            case .deguisement: return "shippingbox.fill"
            case .marche: return "basket.fill"
            case .chocolats: return "gift.fill"
            case .malaise: return "cross.case.fill"
            case .tunnel: return "hammer.fill"
            }
        }

        var description: String {
            switch self {
            case .draps: return "Classique, rapide, dangereux pour les hanches."
            case .deguisement: return "Une casquette, un carton vide, l'air pressé."
            case .marche: return "Profiter d'un moment d'inattention entre les poireaux."
            case .chocolats: return "Une boîte de chocolats fins et 200 € dans l'emballage."
            case .malaise: return "Un grand art. Demande de la santé pour courir ensuite."
            case .tunnel: return "Lent mais sûr. Plusieurs années de travail."
            }
        }

        var cout: Int { self == .chocolats ? 230 : 0 }

        var base: Double {
            switch self {
            case .draps: return 0.40
            case .deguisement: return 0.35
            case .marche: return 0.45
            case .chocolats: return 0.50
            case .malaise: return 0.38
            case .tunnel: return 1
            }
        }
    }

    static func chanceEvasion(_ m: MethodeEvasion, _ j: Joueur, _ e: RetraiteEtat) -> Double {
        guard m != .tunnel else { return 1 }
        let surveillance = Double((e.residence?.surveillance ?? 50) + e.vigilance)
        var c = m.base + Double(j.stats.sante - 50) / 250 - surveillance / 250
        if m == .malaise { c += Double(j.stats.sante - 50) / 250 }
        if m == .deguisement { c += Double(j.stats.intelligence - 50) / 300 }
        if e.residentsVivants.contains(where: { $0.complice }) { c += 0.12 }
        if e.residence?.specialite == "evasion" { c += 0.10 }
        return min(0.9, max(0.03, c))
    }

    /// Une tentative d'évasion par an.
    static func evasion(_ m: MethodeEvasion, _ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard let r = e.residence else { return RetraiteResultat(texte: "Tu n'es enfermé{e} nulle part. Profite.") }
        guard !j.actionsAnnee.contains("ret_evasion") else {
            return RetraiteResultat(texte: "Tu as déjà tenté ta chance cette année. La direction a encore ta photo sur le frigo.")
        }
        guard j.argent >= m.cout else { return RetraiteResultat(texte: "Il faut \(Format.argent(m.cout)) pour acheter le gardien. Il a des goûts de luxe.") }
        j.actionsAnnee.append("ret_evasion")
        j.argent -= m.cout

        if m == .tunnel {
            e.tunnel += Int.random(in: 15...35)
            if e.tunnel < 100 {
                j.stats.sante -= 1
                return RetraiteResultat(texte: [
                    "Le tunnel avance : \(e.tunnel) %. Tu caches la terre dans tes chaussons et dans le pot de la plante verte.",
                    "Tunnel à \(e.tunnel) %. L'aide-soignante s'étonne de la quantité de cuillères qui disparaissent.",
                    "Tunnel à \(e.tunnel) %. Tu as croisé une taupe. Elle t'a regardé{e} avec respect.",
                ].randomElement().map { texte($0, j) }!)
            }
        }

        let complices = e.residentsVivants.filter { $0.complice }
        if m == .tunnel || Double.random(in: 0...1) < chanceEvasion(m, j, e) {
            let recit: String
            switch m {
            case .draps: recit = "Les draps ont tenu ! Tu as atterri dans les hortensias et couru (marché vite) jusqu'à l'arrêt de bus."
            case .deguisement: recit = "« Livraison pour la cuisine ! » Le portail s'est ouvert. Tu es parti{e} avec le carton, par principe."
            case .marche: recit = "Entre le fromager et le marchand de poulets, tu t'es volatilisé{e}. On n'a retrouvé que ton cabas."
            case .chocolats: recit = "Le gardien a mangé un chocolat, compté les billets, puis regardé ailleurs pendant exactement 4 minutes."
            case .malaise: recit = "Tu t'es effondré{e} de façon très convaincante. À un feu rouge, tu as ouvert la porte de l'ambulance et filé."
            case .tunnel: recit = "Le tunnel débouche dans le jardin du voisin, en plein barbecue. Tu as pris une merguez et disparu."
            }
            let cavale = r.nom
            e.derniereResidenceId = r.id
            e.residenceId = nil
            e.imposee = false
            e.tunnel = 0
            e.enCavale = true
            e.anneesCavale = 0
            e.evasionsReussies += 1
            j.stats.bonheur += 15
            var t = "🏃 " + recit + " Tu es en cavale, loin de \(cavale) !"
            if let c = complices.randomElement() { t += " Merci à \(c.prenom), ton complice de l'ombre." }
            if !e.residents.isEmpty, let amour = e.romance {
                t += " \(amour.prenom) t'attendra. Ou pas."
            }
            e.residents = e.residents.filter { $0.statut.estRomance }
            return RetraiteResultat(texte: texte(t, j), signaux: ["evasion_retraite"])
        }

        e.evasionsRatees += 1
        e.vigilance = min(60, e.vigilance + 15)
        j.stats.bonheur -= 5
        var t = RetraiteCatalogue.phrases.evasionRatee.randomElement()!
        switch m {
        case .draps:
            j.stats.sante -= 6
            t += " Les draps étaient en polyester premier prix. Ta hanche s'en souviendra."
        case .malaise:
            j.stats.sante -= 2
            t += " Le médecin de garde a tout de suite vu que ton « infarctus » était à droite."
        case .chocolats:
            t += " Le gardien a gardé les chocolats ET les billets, puis il a prévenu la directrice."
        case .deguisement:
            t += " Le vrai livreur est arrivé en même temps que toi. Malaise."
        case .marche:
            t += " Tu t'es arrêté{e} pour goûter les olives. Fatal."
        case .tunnel:
            break
        }
        if let c = complices.randomElement(), Double.random(in: 0...1) < 0.3,
           let k = e.residents.firstIndex(where: { $0.id == c.id }) {
            e.residents[k].complice = false
            e.residents[k].lien = Stats.borne(e.residents[k].lien - 20)
            t += " \(c.prenom) a tout balancé pour un yaourt de plus."
        }
        return RetraiteResultat(texte: texte(t, j), signaux: ["evasion_ratee"])
    }

    /// Mettre fin à sa cavale de soi-même.
    static func seRendre(_ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard e.enCavale, let r = RetraiteCatalogue.residence(e.derniereResidenceId) ?? RetraiteCatalogue.moinsChere else {
            return RetraiteResultat(texte: "Tu n'es pas en fuite.")
        }
        entrer(r, imposee: true, &j, &e, garderResidents: true)
        j.stats.bonheur -= 3
        return RetraiteResultat(texte: "Tu as sonné au portail de \(r.nom) avec des croissants. La directrice a pris les croissants, puis ton bras.",
                                signaux: ["cavale_fin"])
    }

    // MARK: - Loto du jeudi

    static func lotoDisponible(_ j: Joueur, _ e: RetraiteEtat) -> Bool {
        j.vivant && (e.enResidence || j.age >= ageEntreeChoisie) && !j.actionsAnnee.contains("ret_loto")
            && !lotoBanni(j, e)
    }

    static func lotoBanni(_ j: Joueur, _ e: RetraiteEtat) -> Bool {
        if let fin = e.lotoBanniJusqua { return j.age <= fin }
        return false
    }

    static func nomLoto(_ e: RetraiteEtat) -> String {
        e.enResidence ? "Loto du jeudi" : "Loto de la salle des fêtes"
    }

    static func loto(_ j: inout Joueur, _ e: inout RetraiteEtat, cartons: Int, triche: Bool) -> RetraiteResultat {
        guard !lotoBanni(j, e) else { return RetraiteResultat(texte: "Tu es interdit{e} de loto. Ta photo est affichée à côté du boulier.").rempli(j) }
        guard marquer(&j, "ret_loto") else { return dejaFait }
        let cout = cartons * prixCarton
        guard j.argent >= cout else { return RetraiteResultat(texte: "Même pas \(Format.argent(cout)) pour des cartons ? Gênant.") }
        j.argent -= cout
        e.lotoParties += 1

        if triche && Double.random(in: 0...1) < 0.35 {
            e.lotoBanniJusqua = j.age + 2
            j.stats.karma -= 5
            j.stats.bonheur -= 6
            return RetraiteResultat(texte: [
                "Ton carton pré-rempli au feutre a été repéré par Mme la doyenne, 101 ans, œil de lynx. Exclusion de deux ans.",
                "Tu as crié « Quine ! » avant même le premier numéro. Personne n'a été dupe. Interdit{e} de loto pour deux ans.",
            ].randomElement()!, signaux: ["loto_triche_attrape"]).rempli(j)
        }

        var chance = min(0.7, 0.08 * Double(cartons) + (triche ? 0.25 : 0))
        if e.residence?.specialite == "loto" { chance += 0.05 }
        guard Double.random(in: 0...1) < chance,
              let lot = RetraiteTirage.tirage(RetraiteCatalogue.lots, poids: { Double($0.poids) }) else {
            j.stats.bonheur -= 1
            return RetraiteResultat(texte: [
                "Il te manquait le 37. Toute la soirée. Il te manque encore, la nuit, dans tes rêves.",
                "Ta voisine a gagné trois fois de suite. Tu ne lui adresses plus la parole.",
                "Tu t'es endormi{e} au 12e numéro. Tu avais peut-être gagné. On ne saura jamais.",
                "Le boulier s'est coincé, la soirée s'est terminée en débat sur la soupe. Pas de lot.",
            ].randomElement()!).rempli(j)
        }
        e.lotoGains += 1
        e.lotsGagnes.append(lot.id)
        j.argent += lot.valeur
        j.stats.bonheur += lot.valeur >= 1000 ? 15 : 6
        var t = "QUINE ! Tu remportes \(lot.nom) au \(nomLoto(e).lowercased())."
        if lot.valeur > 0 { t += " (+\(Format.argent(lot.valeur)))" }
        if e.lotoGains == 3 { t += " Troisième victoire : on t'appelle désormais « la terreur du boulier »." }
        if triche { t += " Personne n'a rien vu. Pour l'instant." ; j.stats.karma -= 2 }
        return RetraiteResultat(texte: t, signaux: ["loto_gain"]).rempli(j)
    }

    // MARK: - Activités et voyages

    static func activitesVisibles(_ j: Joueur, _ e: RetraiteEtat) -> [RetraiteActivite] {
        RetraiteCatalogue.activites.filter { a in
            j.age >= (a.ageMin ?? 60) && (a.residenceSeulement != true || e.enResidence)
        }
    }

    static func activiteDisponible(_ a: RetraiteActivite, _ j: Joueur) -> Bool {
        j.vivant && !j.actionsAnnee.contains("ret_act_" + a.id)
    }

    static func faireActivite(_ a: RetraiteActivite, _ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard a.residenceSeulement != true || e.enResidence else { return RetraiteResultat(texte: "Il faut vivre en résidence pour ça.") }
        let cout = a.cout ?? 0
        guard j.argent >= cout else { return RetraiteResultat(texte: "Il te faut \(Format.argent(cout)).") }
        guard marquer(&j, "ret_act_" + a.id) else { return dejaFait }
        j.argent -= cout
        guard let r = RetraiteTirage.tirage(a.resultats, poids: { $0.chance ?? 1 }) else {
            return RetraiteResultat(texte: "Il ne s'est rien passé. C'était reposant.")
        }
        var t = texte(r.texte, j)
        if let eff = r.effets { t += appliquer(eff, &j) }
        return RetraiteResultat(texte: t, signaux: [a.id])
    }

    static func voyageDisponible(_ v: RetraiteVoyage, _ j: Joueur) -> Bool {
        j.vivant && j.age >= (v.ageMin ?? 60) && !j.actionsAnnee.contains("ret_voy_" + v.id)
    }

    static func partirEnVoyage(_ v: RetraiteVoyage, _ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard j.age >= (v.ageMin ?? 60) else { return RetraiteResultat(texte: "Réservé aux plus de \(v.ageMin ?? 60) ans. Repasse plus tard.") }
        guard j.argent >= v.cout else { return RetraiteResultat(texte: "Il faut \(Format.argent(v.cout)). Ta pension ne suit pas.") }
        guard marquer(&j, "ret_voy_" + v.id) else { return dejaFait }
        j.argent -= v.cout
        guard let r = RetraiteTirage.tirage(v.resultats, poids: { $0.chance ?? 1 }) else {
            return RetraiteResultat(texte: "Voyage annulé. On t'a remboursé un bon d'achat.")
        }
        var t = ""
        if e.enResidence && e.imposee {
            t = "La direction a accepté, contre une décharge signée en trois exemplaires. "
        } else if e.enCavale {
            t = "Voyager sous un faux nom, c'est grisant. "
        }
        t += texte(r.texte, j)
        if let eff = r.effets { t += appliquer(eff, &j) }
        e.voyagesFaits.append(v.id)
        return RetraiteResultat(texte: t, signaux: ["voyage", "voyage_retraite"])
    }

    // MARK: - Résidents

    enum Interaction: String, CaseIterable, Identifiable {
        case discuter, cartes, flirter, declarer, mariage, complot, farce

        var id: String { rawValue }

        var titre: String {
            switch self {
            case .discuter: return "Discuter"
            case .cartes: return "Jouer aux cartes"
            case .flirter: return "Flirter"
            case .declarer: return "Déclarer ta flamme"
            case .mariage: return "Demander en mariage"
            case .complot: return "Proposer une évasion à deux"
            case .farce: return "Lui faire une farce"
            }
        }

        var icone: String {
            switch self {
            case .discuter: return "bubble.left.and.bubble.right.fill"
            case .cartes: return "suit.heart.fill"
            case .flirter: return "eye.fill"
            case .declarer: return "heart.fill"
            case .mariage: return "sparkles"
            case .complot: return "key.fill"
            case .farce: return "theatermasks.fill"
            }
        }
    }

    static func interactionsPossibles(_ r: RetraiteResident) -> [Interaction] {
        var l: [Interaction] = [.discuter, .cartes]
        switch r.statut {
        case .couple: l.append(.mariage)
        case .marie: break
        case .flirt: l.append(.declarer)
        default: l.append(.flirter)
        }
        if !r.complice { l.append(.complot) }
        l.append(.farce)
        return l
    }

    static func interactionDisponible(_ r: RetraiteResident, _ j: Joueur) -> Bool {
        j.vivant && r.vivant && !j.actionsAnnee.contains("ret_res_" + r.id.uuidString)
    }

    static func interagir(_ action: Interaction, avec id: UUID, _ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard let k = e.residents.firstIndex(where: { $0.id == id }), e.residents[k].vivant else {
            return RetraiteResultat(texte: "Cette personne n'est plus là.")
        }
        guard marquer(&j, "ret_res_" + id.uuidString) else {
            return RetraiteResultat(texte: "Vous vous êtes déjà vus cette année. Il faut savoir se faire désirer.")
        }
        var r = e.residents[k]
        var t: String
        var signaux: [String] = []
        let elle = r.genre == .femme
        switch action {
        case .discuter:
            let g = Int.random(in: 5...12)
            r.lien = Stats.borne(r.lien + g)
            j.stats.bonheur += 3
            t = [
                "\(r.prenom) t'a raconté sa vie pendant deux heures. Pour info, \(r.prenom) \(r.trait).",
                "Vous avez critiqué la soupe ensemble. Rien ne rapproche plus que la soupe.",
                "\(r.prenom) t'a montré 140 photos de son chat décédé en 1994. C'était émouvant, puis long.",
            ].randomElement()!
            if r.statut == .connaissance && r.lien >= 60 { r.statut = .ami; t += " Vous êtes maintenant ami·e·s." }
            if r.statut == .rival && r.lien >= 40 { r.statut = .connaissance; t += " La hache de guerre est enterrée (sous le potager)." }
        case .cartes:
            if Double.random(in: 0...1) < 0.5 + Double(j.stats.intelligence - 50) / 200 {
                let gain = Int.random(in: 5...40)
                j.argent += gain
                j.stats.bonheur += 4
                r.lien = Stats.borne(r.lien - 2)
                t = "Tu as plumé \(r.prenom) à la belote : \(Format.argent(gain)). \(elle ? "Elle" : "Il") parle d'une revanche « avant de mourir »."
            } else {
                let perte = Int.random(in: 5...30)
                j.argent -= perte
                r.lien = Stats.borne(r.lien + 4)
                t = "\(r.prenom) t'a battu{e} au rami et a fait une petite danse de la victoire. Tu perds \(Format.argent(perte))."
            }
        case .flirter:
            let chance = 0.30 + Double(j.stats.apparence) / 250 + Double(r.lien) / 300
            if Double.random(in: 0...1) < chance {
                r.lien = Stats.borne(r.lien + 12)
                if r.statut != .couple && r.statut != .marie { r.statut = .flirt }
                j.stats.bonheur += 6
                t = [
                    "Tu as offert ton flan à \(r.prenom). Le regard qu'on t'a rendu valait tous les desserts.",
                    "Tu as fait un compliment sur le dentier de \(r.prenom). Ça a marché, contre toute attente.",
                    "Clin d'œil, sourire, main frôlée au-dessus du sucrier. Le réfectoire entier a retenu son souffle.",
                ].randomElement()!
                if let p = j.relations.firstIndex(where: { $0.type == .partenaire && $0.vivant }), Double.random(in: 0...1) < 0.3 {
                    j.relations[p].lien = Stats.borne(j.relations[p].lien - 20)
                    t += " Mauvaise nouvelle : \(j.relations[p].prenom) l'a appris par le club de bridge."
                    signaux.append("tromperie_decouverte")
                }
            } else {
                r.lien = Stats.borne(r.lien - 5)
                j.stats.bonheur -= 3
                t = [
                    "\(r.prenom) t'a demandé si tu avais quelque chose dans l'œil.",
                    "Ta tentative de séduction a été interrompue par l'heure des médicaments.",
                    "\(r.prenom) a cru que tu voulais sa place devant la télé et t'a tapé avec sa canne.",
                ].randomElement()!
            }
        case .declarer:
            if Double.random(in: 0...1) < Double(r.lien) / 100 + 0.1 {
                r.statut = .couple
                r.lien = Stats.borne(r.lien + 15)
                j.stats.bonheur += 12
                t = "Tu as déclaré ta flamme à \(r.prenom) pendant le thé dansant. Réponse : « Il était temps ! » Vous êtes en couple."
                signaux.append("romance_residence")
                if !j.relations.contains(where: { $0.type == .partenaire && $0.vivant }) {
                    let rel = Relation(prenom: r.prenom, nom: r.nom, genre: r.genre, type: .partenaire, age: r.age, lien: r.lien)
                    j.relations.append(rel)
                    r.relationId = rel.id
                } else {
                    t += " Petit détail : tu es déjà en couple ailleurs. Le couloir B garde le secret."
                }
            } else {
                r.lien = Stats.borne(r.lien - 15)
                r.statut = .ami
                j.stats.bonheur -= 8
                t = "\(r.prenom) t'a répondu « je t'aime bien, mais comme un frère de couloir ». Aïe."
            }
        case .mariage:
            if r.statut == .couple && r.lien >= 70 && Double.random(in: 0...1) < 0.8 {
                r.statut = .marie
                r.lien = Stats.borne(r.lien + 10)
                j.stats.bonheur += 18
                t = "OUI ! Le mariage a été célébré au réfectoire entre la purée et le flan. Le maire s'est trompé de prénom deux fois."
                signaux.append("mariage_residence")
                if let p = j.relations.firstIndex(where: { $0.type == .partenaire && $0.vivant }) {
                    j.relations[p].lien = Stats.borne(j.relations[p].lien - 40)
                    t += " Ce qui pose un léger problème avec \(j.relations[p].prenom)."
                }
            } else {
                r.lien = Stats.borne(r.lien - 6)
                j.stats.bonheur -= 5
                t = "\(r.prenom) a dit « pas avant mes 100 ans ». C'est dans quelques années. Patience."
            }
        case .complot:
            if r.lien >= 50 || Double.random(in: 0...1) < 0.2 {
                r.complice = true
                r.lien = Stats.borne(r.lien + 5)
                t = "\(r.prenom) a dit oui, et sorti de sous son matelas un plan de la résidence dessiné en 1997. Ça aidera pour ton évasion."
            } else {
                r.lien = Stats.borne(r.lien - 10)
                e.vigilance = min(60, e.vigilance + 10)
                t = "\(r.prenom) a tout raconté à la directrice contre un deuxième dessert. La surveillance est renforcée."
            }
        case .farce:
            r.lien = Stats.borne(r.lien - Int.random(in: 15...25))
            j.stats.bonheur += 5
            j.stats.karma -= 3
            t = [
                "Tu as remplacé le sucre de \(r.prenom) par du sel. Son cri a réveillé l'aile B.",
                "Tu as caché le déambulateur de \(r.prenom) dans la chapelle. Une heure de recherches, un chapelet de jurons.",
                "Tu as réglé la télé de \(r.prenom) en albanais. \(elle ? "Elle" : "Il") regarde maintenant des feuilletons qu'\(elle ? "elle" : "il") adore.",
            ].randomElement()!
            if r.lien < 25 && !r.statut.estRomance {
                r.statut = .rival
                t += " Vous êtes officiellement ennemi·e·s."
            }
        }
        e.residents[k] = r
        return RetraiteResultat(texte: texte(t, j, resident: r), signaux: signaux)
    }

    // MARK: - Petits-enfants

    static func appeler(_ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        let candidats = e.petitsEnfants.indices.filter { e.petitsEnfants[$0].age >= 6 }
        guard let i = candidats.randomElement() else { return RetraiteResultat(texte: "Tes petits-enfants sont trop petits pour répondre au téléphone. Ils le mangent.") }
        guard marquer(&j, "ret_appel") else { return dejaFait }
        let pe = e.petitsEnfants[i]
        if Double.random(in: 0...1) < 0.25 + Double(pe.lien) / 200 {
            e.petitsEnfants[i].lien = Stats.borne(pe.lien + 6)
            j.stats.bonheur += 5
            return RetraiteResultat(texte: [
                "\(pe.prenom) a décroché ! Vous avez parlé 12 minutes, dont 9 sur le réseau qui coupe.",
                "\(pe.prenom) t'a répondu en visio. Tu as vu son plafond pendant toute la conversation. C'était quand même bien.",
                "\(pe.prenom) t'a raconté ses études. Tu n'as rien compris, mais tu as dit « c'est formidable » au bon moment.",
            ].randomElement()!)
        }
        j.stats.bonheur -= 2
        return RetraiteResultat(texte: [
            "Messagerie de \(pe.prenom) : « Yo c'est moi, laisse un vocal ». Tu as laissé un vocal de 7 minutes.",
            "\(pe.prenom) a refusé l'appel, puis t'a envoyé « jsuis en cours ». Il est 23 h.",
            "Tu as appelé \(pe.prenom). C'est sa mère qui a répondu. Elle voulait parler de ton testament.",
        ].randomElement()!)
    }

    static func evoquerHeritage(_ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard !e.petitsEnfants.isEmpty else { return RetraiteResultat(texte: "Tu n'as pas de petits-enfants à appâter.") }
        guard marquer(&j, "ret_heritage") else { return dejaFait }
        e.heritageEvoqueAge = j.age
        j.stats.karma -= 3
        return RetraiteResultat(texte: "Tu as glissé « tout ça, ce sera pour vous un jour » au repas de famille, en caressant ton portefeuille. Tes petits-enfants ont soudain très envie de te voir l'an prochain.")
    }

    static func envoyerCarte(_ j: inout Joueur, _ e: inout RetraiteEtat) -> RetraiteResultat {
        guard !e.petitsEnfants.isEmpty else { return RetraiteResultat(texte: "Tu n'as personne à qui envoyer une carte.") }
        let cout = 20 * e.petitsEnfants.count
        guard j.argent >= cout else { return RetraiteResultat(texte: "Il faudrait \(Format.argent(cout)). Les cartes à billet coûtent cher.") }
        guard marquer(&j, "ret_carte") else { return dejaFait }
        j.argent -= cout
        for i in e.petitsEnfants.indices { e.petitsEnfants[i].lien = Stats.borne(e.petitsEnfants[i].lien + 6) }
        j.stats.bonheur += 2
        return RetraiteResultat(texte: "Tu as envoyé une carte à chaque petit-enfant, avec un billet de 20 € scotché dedans. Le scotch a coûté plus cher que prévu.")
    }

    // MARK: - Outils

    static let dejaFait = RetraiteResultat(texte: "Tu as déjà fait ça cette année. À ton âge, on se ménage.")

    /// Ajoute une clé à `actionsAnnee`. Renvoie faux si l'action a déjà été faite cette année.
    static func marquer(_ j: inout Joueur, _ cle: String) -> Bool {
        if j.actionsAnnee.contains(cle) { return false }
        j.actionsAnnee.append(cle)
        return true
    }

    /// Applique les effets d'une activité ou d'un voyage. Renvoie un petit résumé (« (+4 santé) »).
    static func appliquer(_ eff: Effets, _ j: inout Joueur) -> String {
        j.stats.sante += eff.health ?? 0
        j.stats.bonheur += eff.happiness ?? 0
        j.stats.intelligence += eff.smarts ?? 0
        j.stats.apparence += eff.looks ?? 0
        j.stats.karma += eff.karma ?? 0
        j.argent += eff.money ?? 0
        j.stats.borner()
        for (cle, delta) in eff.relationships ?? [:] {
            for i in j.relations.indices where j.relations[i].vivant && correspond(j.relations[i].type, cle) {
                j.relations[i].lien = Stats.borne(j.relations[i].lien + delta)
            }
        }
        var suite = ""
        if eff.newFriend == true {
            let g = Genre.allCases.randomElement()!
            let ami = Relation(prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement()!, genre: g, type: .ami,
                               age: max(55, j.age + Int.random(in: -8...8)), lien: Int.random(in: 50...80))
            j.relations.append(ami)
            suite = " " + (g == .femme ? "Nouvelle amie" : "Nouvel ami") + " : \(ami.prenom)."
        }
        var morceaux: [String] = []
        if let v = eff.health, v != 0 { morceaux.append("\(v > 0 ? "+" : "")\(v) santé") }
        if let v = eff.happiness, v != 0 { morceaux.append("\(v > 0 ? "+" : "")\(v) bonheur") }
        if let v = eff.smarts, v != 0 { morceaux.append("\(v > 0 ? "+" : "")\(v) intelligence") }
        if let v = eff.looks, v != 0 { morceaux.append("\(v > 0 ? "+" : "")\(v) apparence") }
        if let v = eff.money, v != 0 { morceaux.append((v > 0 ? "+" : "−") + Format.argent(abs(v))) }
        return suite + (morceaux.isEmpty ? "" : " (" + morceaux.joined(separator: ", ") + ")")
    }

    static func correspond(_ type: TypeRelation, _ cle: String) -> Bool {
        switch cle {
        case "mother": return type == .mere
        case "father": return type == .pere
        case "parent": return type.estParent
        case "sibling": return type == .frere || type == .soeur
        case "friend": return type == .ami
        case "partner": return type == .partenaire
        case "child": return type == .enfant
        default: return false
        }
    }

    /// Remplace les variables des textes du module.
    static func texte(_ s: String, _ j: Joueur, residence: String? = nil, resident: RetraiteResident? = nil,
                      petitEnfant: RetraitePetitEnfant? = nil, enfant: String? = nil) -> String {
        var t = s
        if let residence { t = t.replacingOccurrences(of: "{residence}", with: residence) }
        if let r = resident {
            let f = r.genre == .femme
            t = t.replacingOccurrences(of: "{resident}", with: r.nomComplet)
            t = t.replacingOccurrences(of: "{trait}", with: r.trait)
            t = t.replacingOccurrences(of: "{il}", with: f ? "elle" : "il")
            t = t.replacingOccurrences(of: "{ner}", with: f ? "ne" : "")
            t = t.replacingOccurrences(of: "{er}", with: f ? "e" : "")
        }
        // Les traits peuvent aussi contenir des accords quand ils sont affichés seuls.
        t = t.replacingOccurrences(of: "{ner}", with: "").replacingOccurrences(of: "{er}", with: "")
        if let pe = petitEnfant {
            t = t.replacingOccurrences(of: "{petitenfant}", with: pe.prenom)
            t = t.replacingOccurrences(of: "{pe}", with: pe.genre == .femme ? "e" : "")
        }
        if let enfant { t = t.replacingOccurrences(of: "{enfant}", with: enfant) }
        t = t.replacingOccurrences(of: "{grandparent}", with: j.g("grand-père", "grand-mère"))
        t = t.replacingOccurrences(of: "{prenom}", with: j.prenom)
        t = t.replacingOccurrences(of: "{nom}", with: j.nom)
        t = t.replacingOccurrences(of: "{ville}", with: j.ville)
        t = t.replacingOccurrences(of: "{e}", with: j.genre == .femme ? "e" : "")
        return t
    }

    /// Trait d'un résident accordé à son genre, pour l'affichage.
    static func trait(_ r: RetraiteResident) -> String {
        let f = r.genre == .femme
        return r.trait.replacingOccurrences(of: "{ner}", with: f ? "ne" : "").replacingOccurrences(of: "{er}", with: f ? "e" : "")
    }
}

extension RetraiteResultat {
    /// Remplace {e} et {prenom} dans le texte.
    func rempli(_ j: Joueur) -> RetraiteResultat {
        RetraiteResultat(texte: RetraiteSysteme.texte(texte, j), signaux: signaux)
    }
}

/// Tirage pondéré, autonome (le tirage du moteur est isolé sur le thread principal).
enum RetraiteTirage {
    static func tirage<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0.0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.first }
        var r = Double.random(in: 0..<total)
        for element in liste {
            r -= max(0, poids(element))
            if r < 0 { return element }
        }
        return liste.last
    }
}

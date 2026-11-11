import Foundation

// Le Milieu : crime organisé (gangs, mafias, cartels, trafic, enquêtes).
// Données : Data/Milieu, Data/MilieuMissions, Data/MilieuProduits. Format : docs/donnees-vie-sociale.md.

// MARK: - Données

struct MilieuOrganisation: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var type: String
    var description: String
    var rangs: [String]
    var minAge: Int
    var notorieteMin: Int
    var dangerosite: Int
    var specialites: [String]
    var rivaux: [String]
    var textesRecrutement: [String]
    var textesRefus: [String]

    var typeTexte: String {
        switch type {
        case "gang": return "Gang"
        case "mafia": return "Famille mafieuse"
        case "cartel": return "Cartel"
        case "clan": return "Clan"
        case "reseau": return "Réseau"
        default: return type.capitalized
        }
    }

    func rang(_ i: Int) -> String { rangs.indices.contains(i) ? rangs[i] : (rangs.last ?? "Membre") }
}

struct MilieuMission: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var icon: String?
    var type: String
    var rangMin: Int
    var specialite: String?
    var difficulte: Double
    var risqueArrestation: Double
    var risqueBlessure: Double
    var gainMin: Int
    var gainMax: Int
    var respect: Int
    var chaleur: Int
    var karma: Int
    var peineMinMois: Int
    var peineMaxMois: Int
    var textesReussite: [String]
    var textesEchec: [String]
    var textesArrestation: [String]
    var textesBlessure: [String]
}

struct MilieuProduit: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var prixLot: Int
    var reventeMin: Int
    var reventeMax: Int
    var chaleur: Int
    var peineMinMois: Int
    var peineMaxMois: Int
    var rangMin: Int
    var description: String
    /// Lots demandés par an dans un quartier moyen (VieTrafic.swift).
    var demandeBase: Double?
}

enum MilieuDonnees {
    static let organisations: [MilieuOrganisation] = DonneesJSON.chargerTableaux(dossier: "Milieu", type: MilieuOrganisation.self)
    static let missions: [MilieuMission] = DonneesJSON.chargerTableaux(dossier: "MilieuMissions", type: MilieuMission.self)
    static let produits: [MilieuProduit] = DonneesJSON.chargerTableaux(dossier: "MilieuProduits", type: MilieuProduit.self)

    static func organisation(_ id: String?) -> MilieuOrganisation? {
        guard let id else { return nil }
        return organisations.first { $0.id == id }
    }

    static func produit(_ id: String?) -> MilieuProduit? {
        guard let id else { return nil }
        return produits.first { $0.id == id }
    }
}

// MARK: - État sauvegardé

struct VieTrafic: Codable, Equatable {
    var produitId: String
    /// Nombre de lots en stock.
    var lots: Int
    /// Taille du réseau de revente (1…10).
    var reseau: Int = 1
    var anneesActif = 0
    /// Le business détaillé (VieTrafic.swift). nil pour les anciennes sauvegardes.
    var business: TraficBusiness?

    /// Business, converti depuis l'ancien format si besoin. Garde produitId et lots à jour.
    var b: TraficBusiness {
        get { business ?? TraficBusiness(lignes: [VieLigneTrafic(produitId: produitId, stock: lots)]) }
        set {
            business = newValue
            if let p = newValue.lignes.first { produitId = p.produitId }
            lots = newValue.stockTotal
        }
    }
}

struct VieMilieuEtat: Codable, Equatable {
    var organisationId: String?
    var rang = 0
    var respect = 0
    var loyaute = 50
    /// Attention de la police (0…100).
    var chaleur = 0
    var territoires = 0
    /// Argent gagné illégalement, à blanchir avant d'être dépensé.
    var argentSale = 0
    var chefNom: String?
    var rivalId: String?
    /// Années d'enquête en cours (nil = pas d'enquête).
    var enquete: Int?
    var trafic: VieTrafic?
    var missionsReussies = 0
    var anneesDansLeMilieu = 0
    var anciennesOrganisations: [String] = []
    var balance = false
    var actionsAnnee: [String] = []
    /// Mort violente à annoncer au moteur (VieSysteme.causeDeces).
    var causeDeces: String?
    /// Casse en préparation (VieCoups.swift).
    var coup: VieCoupEnCours?
    var coupsReussis: Int?
    var coupsRates: Int?
    /// Protection contre la police (VieProtection.swift).
    var protection: VieProtection?
    /// Trafic international (VieInternational.swift).
    var international: VieInternationalEtat?
    /// Commerces de façade et argent blanchi cette année (VieEnquete.swift).
    var facades: [String]?
    var blanchiAnnee: Int?
    var blanchiFacades: Int?

    var membre: Bool { organisationId != nil }
}

extension VieEtat {
    var milieuEtat: VieMilieuEtat {
        get { milieu ?? VieMilieuEtat() }
        set { milieu = newValue }
    }
}

// MARK: - Système

enum VieMilieu {

    static func etat(_ j: Joueur) -> VieMilieuEtat { j.vieEtat.milieuEtat }

    static func modifier(_ j: inout Joueur, _ f: (inout VieMilieuEtat) -> Void) {
        var v = j.vieEtat
        var m = v.milieuEtat
        f(&m)
        m.respect = Stats.borne(m.respect)
        m.loyaute = Stats.borne(m.loyaute)
        m.chaleur = Stats.borne(m.chaleur)
        m.argentSale = max(0, m.argentSale)
        v.milieu = m
        j.vieEtat = v
    }

    static func organisation(_ j: Joueur) -> MilieuOrganisation? { MilieuDonnees.organisation(etat(j).organisationId) }

    // MARK: Tags et textes

    static func tags(_ j: Joueur) -> Set<String> {
        guard let m = j.vieEtat.milieu else { return [] }
        var t: Set<String> = []
        if m.membre { t.insert("gang") }
        if m.membre && m.rang >= 3 { t.insert("gang_haut") }
        if m.trafic != nil { t.insert("dealer") }
        if m.enquete != nil { t.insert("sous_enquete") }
        if m.chaleur >= 60 { t.insert("chaleur") }
        if !m.membre && !m.anciennesOrganisations.isEmpty { t.insert("ancien_gang") }
        if m.balance { t.insert("balance") }
        if m.argentSale >= 10_000 { t.insert("argent_sale") }
        t.formUnion(MilieuTrafic.tags(j))
        if m.coup != nil { t.insert("coup_prepare") }
        if (m.coupsReussis ?? 0) > 0 { t.insert("braqueur") }
        t.formUnion(MilieuProtection.tags(j))
        t.formUnion(MilieuEnquete.tags(j))
        t.formUnion(MilieuFacades.tags(j))
        t.formUnion(MilieuInternational.tags(j))
        return t
    }

    static func remplir(_ texte: String, _ j: Joueur) -> String {
        guard texte.contains("{") else { return texte }
        let m = etat(j)
        let org = organisation(j)
        var t = texte
        t = t.replacingOccurrences(of: "{organisation}", with: org?.nom ?? "l'organisation")
        t = t.replacingOccurrences(of: "{chef}", with: m.chefNom ?? "le patron")
        t = t.replacingOccurrences(of: "{rival}", with: MilieuDonnees.organisation(m.rivalId)?.nom ?? "la bande d'en face")
        t = t.replacingOccurrences(of: "{rang}", with: org?.rang(m.rang).lowercased() ?? "petite main")
        t = MilieuTrafic.remplir(t, j)
        t = MilieuInternational.remplir(t, j)
        return t
    }

    // MARK: Entrer, monter, sortir

    /// Notoriété criminelle du joueur (crimes commis + réputation).
    static func notoriete(_ j: Joueur) -> Int {
        let v = j.vieEtat
        return min(100, v.justice.notoriete + v.justice.casier.count * 5 + etat(j).respect / 2)
    }

    static func organisationsAccessibles(_ j: Joueur) -> [MilieuOrganisation] {
        let n = notoriete(j)
        let m = etat(j)
        return MilieuDonnees.organisations
            .filter { j.age >= $0.minAge && !m.anciennesOrganisations.contains($0.id) }
            .sorted { ($0.notorieteMin, $0.dangerosite) < ($1.notorieteMin, $1.dangerosite) }
            .filter { $0.notorieteMin <= n + 15 }
    }

    static func rejoindre(_ org: MilieuOrganisation, _ j: inout Joueur) -> String {
        let m = etat(j)
        if m.membre { return "Tu appartiens déjà à une organisation. On ne sert pas deux maîtres." }
        if j.vieEtat.justice.enPrison { return "Le recrutement se fera à ta sortie. Si tu sors." }
        if m.balance { return "Tout le monde sait que tu as parlé à la police. Personne ne t'ouvrira la porte." }
        let cle = "milieu_candidature"
        if m.actionsAnnee.contains(cle) { return "Tu as déjà tenté ta chance cette année. Trop insister, c'est suspect." }
        modifier(&j) { $0.actionsAnnee.append(cle) }
        let ecart = Double(notoriete(j) - org.notorieteMin) / 100
        let chance = VieHasard.borne(0.55 + ecart + Double(j.stats.karma < 40 ? 10 : 0) / 100)
        guard VieHasard.reussi(chance) else {
            return org.textesRefus.auHasard("On ne te connaît pas. Reviens quand tu auras un nom.")
        }
        let chef = "\(VieDonnees.prenom(Bool.random() ? .homme : .femme)) « \(surnoms.auHasard("le Vieux")) »"
        modifier(&j) {
            $0.organisationId = org.id
            $0.rang = 0
            $0.respect = 5
            $0.loyaute = 55
            $0.chefNom = chef
            $0.rivalId = org.rivaux.randomElement()
            $0.anneesDansLeMilieu = 0
        }
        j.stats.karma -= 5
        j.stats.borner()
        VieSysteme.signaler("gang_entree", &j)
        return org.textesRecrutement.auHasard("Tu fais désormais partie de \(org.nom).") + " Tu entres dans \(org.nom) comme \(org.rang(0).lowercased()). Ton chef : \(chef)."
    }

    static let surnoms = ["le Vieux", "la Lame", "Silence", "le Comptable", "Bouche-Cousue", "la Veuve", "le Docteur", "Deux-Fois", "l'Horloger", "Sans-Visage", "le Gitan", "la Reine", "le Boucher", "Petit Prince"]

    static func demanderPromotion(_ j: inout Joueur) -> String {
        guard let org = organisation(j) else { return "" }
        let m = etat(j)
        if m.rang >= 4 { return "Tu es déjà au sommet. Il n'y a plus qu'une direction possible." }
        if m.actionsAnnee.contains("milieu_promotion") { return "Tu as déjà demandé cette année. \(m.chefNom ?? "Le chef") n'aime pas les impatients." }
        modifier(&j) { $0.actionsAnnee.append("milieu_promotion") }
        let seuil = [15, 35, 60, 85][min(3, m.rang)]
        if m.rang == 3 {
            return "Pour devenir \(org.rang(4).lowercased()), il faut prendre la place de \(m.chefNom ?? "ton chef"). Personne ne te la donnera."
        }
        if m.respect >= seuil && VieHasard.reussi(VieHasard.borne(0.4 + Double(m.loyaute) / 200)) {
            modifier(&j) { $0.rang += 1; $0.respect -= 5 }
            VieSysteme.signaler("gang_promotion", &j)
            return "Tu deviens \(org.rang(m.rang + 1).lowercased()) de \(org.nom). Plus d'argent, plus d'hommes, plus d'ennemis."
        }
        modifier(&j) { $0.loyaute -= 5 }
        return m.respect < seuil
            ? "« Pas encore. » Il te faut plus de respect dans la rue (\(m.respect)/\(seuil))."
            : "\(m.chefNom ?? "Le chef") te regarde longtemps, puis refuse. Tu as l'impression d'avoir fait une erreur en demandant."
    }

    /// Prendre la tête de l'organisation : coup risqué, ouvert aux lieutenants.
    static func prendreLePouvoir(_ j: inout Joueur) -> [String] {
        guard let org = organisation(j) else { return [] }
        let m = etat(j)
        guard m.rang == 3 else { return ["Seul un \(org.rang(3).lowercased()) peut tenter ça."] }
        let chance = VieHasard.borne(0.25 + Double(m.respect) / 250 + Double(j.stats.intelligence) / 500)
        if VieHasard.reussi(chance) {
            let ancien = m.chefNom ?? "l'ancien chef"
            let moi = j.prenom
            modifier(&j) { $0.rang = 4; $0.chefNom = moi; $0.respect += 15; $0.chaleur += 15 }
            j.stats.karma -= 15
            j.stats.borner()
            VieSysteme.signaler("gang_chef", &j)
            return ["\(ancien) a disparu une nuit d'hiver. Le lendemain, tout le monde t'appelait « patron ». Tu diriges désormais \(org.nom)."]
        }
        if VieHasard.reussi(0.5) && VieBonus.peutMourir() {
            j.vivant = false
            j.causeDeces = "abattu après avoir tenté de prendre la tête de \(org.nom)"
            j.emploi = nil
            j.etudes = nil
            return ["Le coup a été éventé. \(m.chefNom ?? "Le chef") t'attendait. On n'a jamais retrouvé ta voiture."]
        }
        modifier(&j) { $0.rang = 1; $0.respect = max(0, $0.respect - 30); $0.loyaute = 10 }
        j.stats.sante -= 30
        j.stats.borner()
        VieSysteme.signaler("gang_trahison", &j)
        return ["Ta tentative a échoué. Tu as survécu, mais on t'a rétrogradé et marqué. Plus personne ne te tourne le dos."]
    }

    static func quitter(_ j: inout Joueur) -> [String] {
        guard let org = organisation(j) else { return [] }
        let m = etat(j)
        var lignes: [String] = []
        let danger = Double(org.dangerosite) * 0.08 + Double(m.rang) * 0.06
        modifier(&j) {
            $0.anciennesOrganisations.append(org.id)
            $0.organisationId = nil
            $0.rang = 0
            $0.trafic = nil
        }
        VieSysteme.signaler("gang_sortie", &j)
        lignes.append("Tu as quitté \(org.nom). Certains ont compris. D'autres ne pardonnent jamais.")
        if VieHasard.reussi(danger) {
            j.stats.sante -= Int.random(in: 20...45)
            j.stats.bonheur -= 15
            j.stats.borner()
            lignes.append("Quelques semaines plus tard, on t'a rappelé que personne ne quitte \(org.nom) sans payer. Tu t'es réveillé·e à l'hôpital.")
        }
        return lignes
    }

    /// Témoigner contre l'organisation : enquête classée, casier allégé, mais tu deviens une cible.
    static func balancer(_ j: inout Joueur) -> [String] {
        guard let org = organisation(j) else { return [] }
        modifier(&j) {
            $0.balance = true
            $0.enquete = nil
            $0.chaleur = 0
            $0.anciennesOrganisations.append(org.id)
            $0.organisationId = nil
            $0.trafic = nil
            $0.argentSale = 0
        }
        var v = j.vieEtat
        if v.justice.enPrison { v.justice.moisRestants = max(1, v.justice.moisRestants / 3) }
        j.vieEtat = v
        j.stats.bonheur -= 20
        j.stats.borner()
        VieSysteme.signaler("balance", &j)
        return ["Tu as tout raconté aux enquêteurs : les noms, les lieux, les comptes. \(org.nom) est démantelé en une nuit de descentes. Tu changes d'adresse, de numéro, presque de visage. Tu ne dormiras plus jamais vraiment tranquille."]
    }

    // MARK: Missions

    static func missions(_ j: Joueur) -> [MilieuMission] {
        guard let org = organisation(j) else { return [] }
        let m = etat(j)
        return MilieuDonnees.missions
            .filter { $0.rangMin <= m.rang && ($0.specialite == nil || org.specialites.contains($0.specialite!)) }
            .sorted { ($0.rangMin, $0.gainMax) < ($1.rangMin, $1.gainMax) }
    }

    static func faire(_ mi: MilieuMission, _ j: inout Joueur) -> [String] {
        guard let org = organisation(j) else { return [] }
        if j.vieEtat.justice.enPrison { return ["Tu es en prison. Les affaires continuent sans toi."] }
        let m = etat(j)
        let faites = m.actionsAnnee.filter { $0.hasPrefix("mission_") }.count
        if faites >= 4 { return ["Quatre opérations cette année. Même les plus fous savent se faire oublier."] }
        modifier(&j) { $0.actionsAnnee.append("mission_\(mi.id)") }
        j.stats.karma += mi.karma
        let reussite = VieHasard.borne(1 - mi.difficulte + Double(j.stats.intelligence - 50) / 400 + Double(m.rang) * 0.03)
        if VieHasard.reussi(reussite) {
            let gain = Int.random(in: mi.gainMin...max(mi.gainMin, mi.gainMax)) * (100 + org.dangerosite * 10) / 100
            modifier(&j) {
                $0.argentSale += gain
                $0.respect += mi.respect
                $0.chaleur += mi.chaleur
                $0.missionsReussies += 1
                $0.loyaute += 2
            }
            VieSysteme.signaler("mission_reussie", &j)
            var l = [mi.textesReussite.auHasard("C'est fait.") + " (+\(Format.argent(gain)) d'argent sale)"]
            if VieHasard.reussi(mi.risqueBlessure / 2) {
                j.stats.sante -= Int.random(in: 5...20)
                l.append(mi.textesBlessure.auHasard("Tu t'en sors, mais blessé·e."))
            }
            j.stats.borner()
            return l
        }
        modifier(&j) { $0.chaleur += mi.chaleur / 2 + 3; $0.respect -= 2 }
        VieSysteme.signaler("mission_ratee", &j)
        if VieHasard.reussi(VieBonus.arrestation(mi.risqueArrestation + Double(etat(j).chaleur) / 400)) {
            return arreter(mi.nom, mois: Int.random(in: mi.peineMinMois...max(mi.peineMinMois, mi.peineMaxMois)), texte: mi.textesArrestation.auHasard("La police t'attendait."), &j)
        }
        if VieHasard.reussi(mi.risqueBlessure) {
            j.stats.sante -= Int.random(in: 10...35)
            j.stats.borner()
            return [mi.textesBlessure.auHasard("Ça a mal tourné. Tu saignes.")]
        }
        return [mi.textesEchec.auHasard("Ça a raté. {chef} ne va pas aimer.")]
    }

    static func arreter(_ crime: String, mois moisBruts: Int, texte: String, _ j: inout Joueur) -> [String] {
        var lignes = [texte]
        // Avocat attitré et juge acheté (VieProtection.swift).
        let facteur = MilieuProtection.facteurPeine(j)
        let mois = moisBruts > 0 ? max(1, Int(Double(moisBruts) * facteur)) : 0
        if facteur < 1 && moisBruts > 0 { lignes.append(MilieuProtection.etat(j).juge ? "Ton avocat et un juge bienveillant font tomber une partie des charges." : "Ton avocat fait tomber une partie des charges.") }
        modifier(&j) { $0.enquete = nil; $0.trafic = nil }
        var v = j.vieEtat
        v.justice.casier.append(VieCasierLigne(age: j.age, crime: crime, mois: mois))
        j.vieEtat = v
        VieSysteme.signaler("arrestation", &j)
        if let l = VieSysteme.condamnation?(crime.lowercased(), mois, &j) { lignes.append(l) }
        lignes += VieCrime.emprisonner(max(1, mois), &j)
        return lignes
    }

    // MARK: Blanchiment

    static func blanchir(_ montant: Int, _ j: inout Joueur) -> String {
        let m = etat(j)
        let somme = min(montant, m.argentSale)
        guard somme > 0 else { return "Tu n'as pas d'argent sale à blanchir." }
        let commission = (m.rang >= 3 ? 15 : 30) - (MilieuProtection.etat(j).comptable ? 10 : 0)
        let net = somme * (100 - commission) / 100
        j.argent += net
        modifier(&j) { $0.blanchiAnnee = ($0.blanchiAnnee ?? 0) + somme }
        modifier(&j) { $0.argentSale -= somme; $0.chaleur += somme > 200_000 ? 8 : 3 }
        VieSysteme.signaler("blanchiment", &j)
        return "Ton argent passe par une laverie, un garage et deux sociétés écrans. Tu récupères \(Format.argent(net)) propres (commission de \(commission) %)."
    }

    // MARK: Guerre de territoire

    static func guerreDeTerritoire(_ j: inout Joueur) -> [String] {
        guard let org = organisation(j) else { return [] }
        let m = etat(j)
        guard m.rang >= 2 else { return ["Ce n'est pas à toi de décider d'une guerre."] }
        if m.actionsAnnee.contains("milieu_guerre") { return ["Une guerre par an. Il faut enterrer les morts."] }
        modifier(&j) { $0.actionsAnnee.append("milieu_guerre") }
        let rival = MilieuDonnees.organisation(m.rivalId)?.nom ?? "les rivaux"
        VieSysteme.signaler("guerre_territoire", &j)
        let chance = VieHasard.borne(0.45 + Double(m.respect) / 300 + Double(org.dangerosite) * 0.03)
        if VieHasard.reussi(chance) {
            modifier(&j) { $0.territoires += 1; $0.respect += 10; $0.chaleur += 20 }
            return ["Après des semaines de tension, \(rival) recule. Un nouveau territoire est à vous. Le quartier, lui, compte ses blessés."]
        }
        modifier(&j) { $0.territoires = max(0, $0.territoires - 1); $0.respect -= 8; $0.chaleur += 15 }
        j.stats.sante -= Int.random(in: 10...30)
        j.stats.bonheur -= 10
        j.stats.borner()
        var l = ["La guerre contre \(rival) tourne mal. Vous perdez du terrain, et des hommes."]
        if VieHasard.reussi(0.15) { l += VieSysteme.tuer("friend", &j) }
        return l
    }

    // MARK: Pot-de-vin

    static func corrompre(_ j: inout Joueur) -> String {
        let m = etat(j)
        guard m.rang >= 2 else { return "Tu n'as pas les contacts pour ça." }
        let cout = 10_000 + m.chaleur * 1_000
        guard m.argentSale + j.argent >= cout else { return "Un fonctionnaire coûte au moins \(Format.argent(cout))." }
        let sale = min(m.argentSale, cout)
        j.argent -= cout - sale
        if VieHasard.reussi(0.7) {
            modifier(&j) { $0.argentSale -= sale; $0.chaleur -= 30; if VieHasard.reussi(0.5) { $0.enquete = nil } }
            return "Une enveloppe change de main dans un parking. Des dossiers se perdent, des patrouilles changent d'itinéraire."
        }
        modifier(&j) { $0.argentSale -= sale; $0.chaleur += 20; $0.enquete = $0.enquete ?? 0 }
        VieSysteme.signaler("enquete_ouverte", &j)
        return "Le fonctionnaire était un enquêteur infiltré. La tentative de corruption s'ajoute à ton dossier."
    }

    // MARK: +1 an

    static func vieillir(_ j: inout Joueur) -> [String] {
        guard j.vieEtat.milieu != nil else { return [] }
        var lignes: [String] = []
        modifier(&j) { $0.actionsAnnee = [] }
        let enPrison = j.vieEtat.justice.enPrison
        let m = etat(j)

        // Trafic (VieTrafic.swift) et casse en préparation (VieCoups.swift).
        lignes += MilieuTrafic.vieillir(&j)
        lignes += MilieuCoups.vieillir(&j)
        lignes += MilieuInternational.vieillir(&j)

        // Tribut au chef, loyauté.
        if m.membre && m.rang < 4 && !enPrison {
            modifier(&j) { $0.anneesDansLeMilieu += 1; $0.loyaute -= 3 }
            let tribut = etat(j).argentSale / 5
            if tribut > 0 {
                modifier(&j) { $0.argentSale -= tribut }
                lignes.append("Tu reverses \(Format.argent(tribut)) à \(m.chefNom ?? "ton chef"). C'est la règle.")
            }
        }
        // Chef : revenus des territoires.
        if m.membre && m.rang >= 3 && !enPrison {
            let revenu = (m.territoires + 1) * Int.random(in: 20_000...80_000) * (m.rang == 4 ? 3 : 1)
            modifier(&j) { $0.argentSale += revenu; $0.chaleur += 5 }
            lignes.append("Les territoires de ton organisation te rapportent \(Format.argent(revenu)) d'argent sale.")
        }

        // Police : l'attention retombe un peu. Protection payée, enquête par étapes, commerces et fisc.
        modifier(&j) { $0.chaleur -= enPrison ? 15 : 6 }
        lignes += MilieuProtection.vieillir(&j)
        lignes += MilieuEnquete.vieillir(&j)
        lignes += MilieuFacades.vieillir(&j)
        let e = etat(j)

        // Violence du milieu : les hauts rangs risquent leur vie.
        if e.membre && !enPrison && VieHasard.reussi(Double(e.rang) * 0.02 + Double(organisation(j)?.dangerosite ?? 1) * 0.005) {
            if VieHasard.reussi(0.3) && VieBonus.peutMourir() {
                modifier(&j) { $0.causeDeces = "abattu dans un règlement de comptes" }
                lignes.append("Une moto s'est arrêtée à ta hauteur au feu rouge. C'est la dernière chose dont tu te souviens.")
            } else {
                j.stats.sante -= Int.random(in: 15...40)
                lignes.append("On a tenté de t'éliminer. Tu as survécu, de justesse. Quelqu'un, quelque part, a parlé.")
            }
        }
        // Trahison : la loyauté très basse se paie.
        if e.membre && e.loyaute < 15 && VieHasard.reussi(0.25) {
            lignes += quitterExclu(&j)
        }
        j.stats.borner()
        return lignes
    }

    private static func quitterExclu(_ j: inout Joueur) -> [String] {
        guard let org = organisation(j) else { return [] }
        modifier(&j) { $0.anciennesOrganisations.append(org.id); $0.organisationId = nil; $0.rang = 0; $0.trafic = nil; $0.argentSale /= 2 }
        j.stats.sante -= 25
        j.stats.borner()
        VieSysteme.signaler("gang_trahison", &j)
        return ["\(org.nom) ne te faisait plus confiance. Ils t'ont pris la moitié de ton argent sale et laissé sur le bord de la route. Tu n'en fais plus partie."]
    }

    // MARK: Effets d'événements

    static func appliquer(_ fx: VieEffets, _ j: inout Joueur) -> [String] {
        var lignes: [String] = []
        let a = etat(j)
        modifier(&j) {
            $0.respect += fx.milieuRespect ?? 0
            $0.chaleur += fx.milieuChaleur ?? 0
            $0.loyaute += fx.milieuLoyaute ?? 0
            $0.argentSale += fx.argentSale ?? 0
        }
        if fx.saisie == true { MilieuTrafic.saisir(&j) }
        MilieuTrafic.appliquer(fx, &j)
        MilieuProtection.appliquer(fx, &j)
        MilieuInternational.appliquer(fx, &j)
        if fx.enquete == true && a.enquete == nil {
            modifier(&j) { $0.enquete = 0 }
            VieSysteme.signaler("enquete_ouverte", &j)
        } else if fx.enquete == false && a.enquete != nil {
            modifier(&j) { $0.enquete = nil }
            VieSysteme.signaler("enquete_classee", &j)
        }
        if fx.saisie == true { VieSysteme.signaler("trafic_saisie", &j) }
        if fx.promotion == true, let org = organisation(j), etat(j).rang < 3 {
            modifier(&j) { $0.rang += 1 }
            VieSysteme.signaler("gang_promotion", &j)
            lignes.append("Tu deviens \(org.rang(etat(j).rang).lowercased()) de \(org.nom).")
        }
        if fx.quitterMilieu == true, etat(j).membre {
            lignes += quitter(&j)
        }
        return lignes
    }
}

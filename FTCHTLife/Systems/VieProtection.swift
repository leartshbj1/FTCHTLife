import Foundation

// Protection contre la police : avocat attitré, policiers et douaniers payés, juge acheté, comptable, prête-nom,
// année à profil bas, destruction de preuves. Appelé par VieMilieu (enquêtes, arrestations, blanchiment) et VieTrafic.

// MARK: - État sauvegardé

struct VieProtection: Codable, Equatable {
    /// 0 aucun, 1 avocat sérieux, 2 ténor du barreau.
    var avocat = 0
    /// Policiers payés (0…5).
    var policiers = 0
    /// Douaniers payés (0…3).
    var douaniers = 0
    var juge = false
    var comptable = false
    var preteNom = false
    /// Profil bas pour l'année en cours.
    var profilBas = false
    /// Téléphones jetables (contre les écoutes).
    var jetables = false
    /// Enquête : frein à la progression cette année (en %), et preuves fragilisées (en %).
    var frein = 0
    var preuvesFaibles = 0
    /// En fuite à l'étranger, recherché par mandat international.
    var recherche = false
}

// MARK: - Système

enum MilieuProtection {

    static let maxPoliciers = 5
    static let maxDouaniers = 3
    static let coutDouanier = 20_000
    static let coutJuge = 150_000
    static let coutComptable = 25_000
    static let coutPreteNom = 10_000
    static let coutPreuves = 20_000
    static let coutJetables = 3_000

    static func etat(_ j: Joueur) -> VieProtection { VieMilieu.etat(j).protection ?? VieProtection() }

    static func modifier(_ j: inout Joueur, _ f: (inout VieProtection) -> Void) {
        VieMilieu.modifier(&j) { m in
            var p = m.protection ?? VieProtection()
            f(&p)
            p.avocat = min(2, max(0, p.avocat))
            p.policiers = min(maxPoliciers, max(0, p.policiers))
            p.douaniers = min(maxDouaniers, max(0, p.douaniers))
            p.frein = min(80, max(0, p.frein))
            p.preuvesFaibles = min(60, max(0, p.preuvesFaibles))
            m.protection = p
        }
    }

    // MARK: Coûts

    static func coutAvocat(_ niveau: Int) -> Int { niveau >= 2 ? 60_000 : (niveau == 1 ? 15_000 : 0) }

    static func coutPolicier(_ j: Joueur) -> Int { 12_000 + 4_000 * VieMilieu.etat(j).rang }

    static func coutAnnuel(_ j: Joueur) -> Int {
        let p = etat(j)
        return coutAvocat(p.avocat) + p.policiers * coutPolicier(j) + p.douaniers * coutDouanier
            + (p.juge ? coutJuge : 0) + (p.comptable ? coutComptable : 0) + (p.preteNom ? coutPreteNom : 0)
            + (p.jetables ? coutJetables : 0)
    }

    static func peutAcheterJuge(_ j: Joueur) -> Bool {
        let m = VieMilieu.etat(j)
        return m.membre && m.rang >= 3
    }

    // MARK: Effets sur la police

    /// Multiplicateur des peines (avocat, juge).
    static func facteurPeine(_ j: Joueur) -> Double {
        let p = etat(j)
        var f = p.avocat == 2 ? 0.5 : (p.avocat == 1 ? 0.75 : 1)
        if p.juge { f *= 0.7 }
        return f
    }

    /// Multiplicateur du risque qu'une enquête aboutisse à une arrestation.
    static func facteurArrestation(_ j: Joueur) -> Double {
        let p = etat(j)
        return max(0.25, 1 - 0.1 * Double(p.policiers) - (p.juge ? 0.35 : 0) - 0.1 * Double(p.avocat))
    }

    /// Multiplicateur du risque qu'une enquête s'ouvre.
    static func facteurOuverture(_ j: Joueur) -> Double {
        let p = etat(j)
        return max(0.2, 1 - (p.preteNom ? 0.4 : 0) - 0.08 * Double(p.policiers) - (p.profilBas ? 0.3 : 0))
    }

    /// Multiplicateur du risque de descente sur le stock.
    static func facteurDescente(_ j: Joueur) -> Double {
        let p = etat(j)
        return max(0.15, 1 - 0.15 * Double(p.policiers)) * (p.profilBas ? 0.4 : 1)
    }

    /// Multiplicateur du risque de saisie en douane.
    static func facteurDouane(_ j: Joueur) -> Double { max(0.3, 1 - 0.2 * Double(etat(j).douaniers)) }

    /// Risque estimé d'être arrêté cette année (affiché au joueur).
    static func risqueAnnuel(_ j: Joueur) -> Double {
        let m = VieMilieu.etat(j)
        if let annees = m.enquete {
            return VieHasard.borne((0.25 + Double(annees) * 0.15 + Double(m.chaleur) / 300) * facteurArrestation(j))
        }
        guard m.membre || m.trafic != nil else { return 0 }
        let ouverture = Double(m.chaleur) / 250 * facteurOuverture(j)
        return min(0.95, ouverture * 0.3)
    }

    /// Ce qui fait monter ou baisser l'attention de la police, estimé sur un an.
    static func explications(_ j: Joueur) -> [(String, Int)] {
        let m = VieMilieu.etat(j)
        let p = etat(j)
        var l: [(String, Int)] = [("Le temps qui passe", -6)]
        if let t = m.trafic {
            let b = t.b
            var ventes = 0.0
            for li in b.lignes {
                guard let pr = MilieuDonnees.produit(li.produitId) else { continue }
                let police = Double(b.zones.compactMap { TraficDonnees.zone($0.zoneId)?.police }.reduce(0, +)) / Double(max(1, b.zones.count))
                ventes += Double(li.vendus * pr.chaleur) * police / 60 / 4
            }
            ventes *= b.strategie.chaleur * (p.profilBas ? 0.5 : 1)
            if ventes >= 1 { l.append(("Les ventes de ton réseau (stratégie \(b.strategie.nom.lowercased()))", min(25, Int(ventes)))) }
            if b.securite > 0 { l.append(("Tes guetteurs et tes planques", -3 * b.securite)) }
        }
        if m.membre && m.rang >= 3 { l.append(("Les territoires de ton organisation", 5)) }
        if p.policiers > 0 { l.append(("\(p.policiers) policier\(p.policiers > 1 ? "s" : "") payé\(p.policiers > 1 ? "s" : "")", -4 * p.policiers)) }
        if p.juge { l.append(("Le juge", -5)) }
        if p.profilBas { l.append(("Ton année à profil bas", -20)) }
        return l
    }

    // MARK: Actions

    static func choisirAvocat(_ niveau: Int, _ j: inout Joueur) -> String {
        let p = etat(j)
        if niveau == p.avocat { return "" }
        if niveau == 0 {
            modifier(&j) { $0.avocat = 0 }
            return "Tu mets fin au contrat de ton avocat. Il te serre la main un peu trop longtemps : il sait beaucoup de choses."
        }
        let cout = coutAvocat(niveau)
        guard MilieuTrafic.payer(cout, &j) else { return "Il faut \(Format.argent(cout)) d'avance pour la première année." }
        modifier(&j) { $0.avocat = niveau }
        return niveau == 2
            ? "Un ténor du barreau accepte de te défendre. Il ne demande jamais si tu es coupable. Il demande seulement si tu peux payer."
            : "Un avocat sérieux accepte de s'occuper de tes affaires. Un numéro à appeler à toute heure, et le droit de se taire bien appliqué."
    }

    static func recruterPolicier(_ j: inout Joueur) -> [String] {
        let p = etat(j)
        if p.policiers >= maxPoliciers { return ["Tu as déjà assez de monde dans la police. Un de plus, et l'un d'eux finira par parler."] }
        if VieMilieu.etat(j).actionsAnnee.contains("protection_policier") { return ["Tu as déjà approché un policier cette année. Il faut du temps pour trouver la bonne personne."] }
        VieMilieu.modifier(&j) { $0.actionsAnnee.append("protection_policier") }
        let cout = coutPolicier(j)
        guard MilieuTrafic.payer(cout, &j) else { return ["Il faut \(Format.argent(cout)) pour la première année."] }
        if VieHasard.reussi(0.12) {
            VieMilieu.modifier(&j) { $0.chaleur += 20 }
            var l = ["Le policier que tu as approché travaillait pour la police des polices. Ton enveloppe est sous scellés."]
            if VieMilieu.etat(j).enquete == nil {
                VieMilieu.modifier(&j) { $0.enquete = 0 }
                VieSysteme.signaler("enquete_ouverte", &j)
                l.append("Une enquête pour corruption est ouverte.")
            }
            return l
        }
        modifier(&j) { $0.policiers += 1 }
        return [["Un brigadier fatigué, des dettes de jeu, un divorce. Il accepte ton enveloppe sans te regarder.",
                 "Une inspectrice ambitieuse accepte de te prévenir des descentes. Elle ne fait pas ça pour l'argent, dit-elle. Elle prend l'argent quand même.",
                 "Un vieux policier qui a tout vu accepte. « Je ne veux pas de sang dans mon secteur. Le reste, je ne le vois pas. »"].auHasard("Un policier accepte ton argent.")]
    }

    static func lacherPolicier(_ j: inout Joueur) -> String {
        guard etat(j).policiers > 0 else { return "" }
        modifier(&j) { $0.policiers -= 1 }
        if VieHasard.reussi(0.1) {
            VieMilieu.modifier(&j) { $0.chaleur += 10 }
            return "Tu arrêtes de payer un de tes policiers. Il le prend mal. Les contrôles reprennent dans ton secteur."
        }
        return "Tu arrêtes de payer un de tes policiers. Il ne dit rien. Il se souviendra de tout."
    }

    static func recruterDouanier(_ j: inout Joueur) -> String {
        if etat(j).douaniers >= maxDouaniers { return "Tu as déjà assez de douaniers. Un de plus et ça se verrait dans leurs plannings." }
        guard MilieuTrafic.payer(coutDouanier, &j) else { return "Un douanier coûte \(Format.argent(coutDouanier)) par an." }
        if VieHasard.reussi(0.1) {
            VieMilieu.modifier(&j) { $0.chaleur += 15 }
            return "Le douanier a pris l'argent puis a rédigé un rapport. Ton nom circule désormais dans les services des douanes."
        }
        modifier(&j) { $0.douaniers += 1 }
        return "Un agent des douanes accepte de regarder ailleurs, certains jours, sur certains conteneurs."
    }

    static func lacherDouanier(_ j: inout Joueur) -> String {
        guard etat(j).douaniers > 0 else { return "" }
        modifier(&j) { $0.douaniers -= 1 }
        return "Tu cesses de payer un douanier. Tes cargaisons repassent par le circuit normal."
    }

    static func acheterJuge(_ j: inout Joueur) -> [String] {
        guard peutAcheterJuge(j) else { return ["Seuls les dirigeants d'une organisation ont les relations pour approcher un juge."] }
        if etat(j).juge { return [] }
        if VieMilieu.etat(j).actionsAnnee.contains("protection_juge") { return ["Tu as déjà tenté ta chance cette année."] }
        VieMilieu.modifier(&j) { $0.actionsAnnee.append("protection_juge") }
        guard MilieuTrafic.payer(coutJuge, &j) else { return ["Un juge coûte \(Format.argent(coutJuge)) par an. Au moins."] }
        if VieHasard.reussi(0.55) {
            modifier(&j) { $0.juge = true }
            VieSysteme.signaler("juge_achete", &j)
            return ["Un dîner dans une maison de campagne, un chalet à son nom à la montagne. Le juge accepte. Les dossiers qui te concernent vont désormais prendre beaucoup de retard."]
        }
        VieMilieu.modifier(&j) { $0.chaleur += 20 }
        var l = ["Le juge a refusé, poliment. L'argent est perdu, et il connaît maintenant ton visage."]
        if VieHasard.reussi(0.3), VieMilieu.etat(j).enquete == nil {
            VieMilieu.modifier(&j) { $0.enquete = 0 }
            VieSysteme.signaler("enquete_ouverte", &j)
            l.append("Il a signalé la tentative. Une enquête est ouverte.")
        }
        return l
    }

    static func lacherJuge(_ j: inout Joueur) -> String {
        modifier(&j) { $0.juge = false }
        return "Tu cesses de payer le juge. Il a autant à perdre que toi : il se taira."
    }

    static func basculerComptable(_ j: inout Joueur) -> String {
        if etat(j).comptable {
            modifier(&j) { $0.comptable = false }
            return "Ton comptable range ses classeurs et disparaît. Tu espères qu'il a brûlé les doubles."
        }
        guard MilieuTrafic.payer(coutComptable, &j) else { return "Un comptable discret coûte \(Format.argent(coutComptable)) par an." }
        modifier(&j) { $0.comptable = true }
        return "Un ancien expert-comptable rayé de l'ordre prend tes finances en main : sociétés écrans, factures, comptes à l'étranger. Le blanchiment te coûte moins cher, et une partie de ton argent devient introuvable."
    }

    static func basculerPreteNom(_ j: inout Joueur) -> String {
        if etat(j).preteNom {
            modifier(&j) { $0.preteNom = false }
            return "Tu reprends tes biens à ton nom. Plus simple, plus visible."
        }
        guard MilieuTrafic.payer(coutPreteNom, &j) else { return "Un prête-nom coûte \(Format.argent(coutPreteNom)) par an." }
        modifier(&j) { $0.preteNom = true }
        return "Un cousin éloigné accepte de mettre ta voiture, ton appartement et deux sociétés à son nom. Sur le papier, tu ne possèdes rien."
    }

    static func basculerJetables(_ j: inout Joueur) -> String {
        let actif = !etat(j).jetables
        modifier(&j) { $0.jetables = actif }
        return actif
            ? "Des téléphones achetés en liquide, changés chaque mois, jamais allumés chez toi. Les écoutes auront plus de mal à te suivre."
            : "Tu reviens à un seul téléphone. Plus pratique. Plus risqué."
    }

    static func basculerProfilBas(_ j: inout Joueur) -> String {
        let actif = !etat(j).profilBas
        modifier(&j) { $0.profilBas = actif }
        if actif { VieSysteme.signaler("profil_bas", &j) }
        return actif
            ? "Cette année, tu fais profil bas : moins de ventes, pas d'opérations voyantes, des journées entières à ne rien faire. Le réseau s'impatiente."
            : "Tu reprends les affaires normalement."
    }

    static func detruirePreuves(_ j: inout Joueur) -> String {
        guard let annees = VieMilieu.etat(j).enquete else { return "Il n'y a pas d'enquête en cours contre toi." }
        if VieMilieu.etat(j).actionsAnnee.contains("protection_preuves") { return "Tu as déjà fait le ménage cette année. Recommencer laisserait des traces." }
        VieMilieu.modifier(&j) { $0.actionsAnnee.append("protection_preuves") }
        guard MilieuTrafic.payer(coutPreuves, &j) else { return "Faire disparaître des preuves coûte \(Format.argent(coutPreuves))." }
        j.stats.karma -= 4
        j.stats.borner()
        if VieHasard.reussi(0.55) {
            VieMilieu.modifier(&j) { $0.enquete = 0; $0.chaleur -= 10 }
            return "Des téléphones broyés, des disques durs dans le canal, un entrepôt nettoyé à l'eau de javel. L'enquête repart presque de zéro."
        }
        if VieHasard.reussi(0.45) {
            VieMilieu.modifier(&j) { $0.enquete = annees + 1; $0.chaleur += 15 }
            return "La personne chargée du ménage a été suivie. Les enquêteurs ajoutent l'entrave à la justice à ton dossier."
        }
        return "Tu fais disparaître ce que tu peux. Tu ne sais pas si c'était suffisant."
    }

    // MARK: +1 an

    static func vieillir(_ j: inout Joueur) -> [String] {
        guard let p = VieMilieu.etat(j).protection else { return [] }
        var lignes: [String] = []
        let cout = coutAnnuel(j)
        if cout > 0 {
            if MilieuTrafic.payer(cout, &j) {
                lignes.append("Ta protection t'a coûté \(Format.argent(cout)) cette année (avocat, contacts, prête-noms).")
            } else {
                modifier(&j) { $0.juge = false; $0.policiers = max(0, $0.policiers - 2); $0.douaniers = 0; $0.preteNom = false }
                VieMilieu.modifier(&j) { $0.chaleur += 10 }
                lignes.append("Tu n'as pas pu payer tout le monde. Le juge, des policiers et des douaniers ont cessé de te protéger. Certains savent beaucoup trop de choses.")
            }
        }
        // Les contacts payés font baisser l'attention de la police.
        let p2 = etat(j)
        let baisse = 4 * p2.policiers + (p2.juge ? 5 : 0) + (p.profilBas ? 20 : 0)
        if baisse > 0 { VieMilieu.modifier(&j) { $0.chaleur -= baisse } }
        // Scandale : un contact se fait prendre.
        let risque = 0.03 * Double(p2.policiers) + 0.05 * Double(p2.douaniers) + (p2.juge ? 0.06 : 0)
        if VieHasard.reussi(risque) {
            let qui = Double.random(in: 0..<max(0.001, risque))
            let texte: String
            if p2.juge && qui < 0.06 {
                modifier(&j) { $0.juge = false }
                texte = "Le juge que tu payais a été arrêté. Sa photo, menottes aux poignets, fait la une des journaux."
            } else if p2.douaniers > 0 && qui < (p2.juge ? 0.06 : 0) + 0.05 * Double(p2.douaniers) {
                modifier(&j) { $0.douaniers -= 1 }
                texte = "Un des douaniers que tu payais est tombé lors d'un contrôle interne."
            } else {
                modifier(&j) { $0.policiers -= 1 }
                texte = "Un des policiers que tu payais a été arrêté par la police des polices."
            }
            VieMilieu.modifier(&j) { $0.chaleur += 20 }
            VieSysteme.signaler("protection_scandale", &j)
            lignes.append(texte)
            if VieMilieu.etat(j).enquete == nil && VieHasard.reussi(0.5) {
                VieMilieu.modifier(&j) { $0.enquete = 0 }
                VieSysteme.signaler("enquete_ouverte", &j)
                lignes.append("Il a donné des noms. Le tien en fait partie. Une enquête est ouverte.")
            }
        }
        if p.profilBas {
            modifier(&j) { $0.profilBas = false }
            lignes.append("Ton année à profil bas s'achève. La police s'est un peu désintéressée de toi.")
        }
        return lignes
    }

    // MARK: Tags, effets

    static func tags(_ j: Joueur) -> Set<String> {
        guard let p = VieMilieu.etat(j).protection else { return [] }
        var t: Set<String> = []
        if p.policiers > 0 || p.juge { t.insert("protege") }
        if p.avocat > 0 { t.insert("avocat_attitre") }
        if p.profilBas { t.insert("profil_bas") }
        if p.douaniers > 0 { t.insert("douanier") }
        if p.recherche { t.insert("recherche") }
        return t
    }

    static func appliquer(_ fx: VieEffets, _ j: inout Joueur) {
        if let d = fx.contactPolice, d != 0 {
            modifier(&j) { $0.policiers += d }
        }
    }
}

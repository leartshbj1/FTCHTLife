import Foundation

// Préparer un casse : choisir la cible, recruter l'équipe, faire des repérages, choisir le plan, passer à l'acte.
// Données : Data/MilieuCoups. Appelé par VieMilieu (tags, vieillir) et VieCoupView.

// MARK: - Données

struct MilieuCible: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    var icon: String?
    var minAge: Int
    var notorieteMin: Int
    var difficulte: Double
    var butinMin: Int
    var butinMax: Int
    var peineMinMois: Int
    var peineMaxMois: Int
    var chaleur: Int
    var roles: [String]
    var reperageCout: Int
}

enum CoupRole {
    static func nom(_ r: String) -> String {
        switch r {
        case "chauffeur": return "Chauffeur"
        case "guetteur": return "Guetteur"
        case "perceur": return "Perceur de coffres"
        case "informaticien": return "Informaticien"
        case "gros_bras": return "Gros bras"
        case "infiltre": return "Complice à l'intérieur"
        default: return r.capitalized
        }
    }

    static func icone(_ r: String) -> String {
        switch r {
        case "chauffeur": return "car.fill"
        case "guetteur": return "eye.fill"
        case "perceur": return "lock.open.fill"
        case "informaticien": return "desktopcomputer"
        case "gros_bras": return "figure.boxing"
        case "infiltre": return "person.fill.questionmark"
        default: return "person.fill"
        }
    }
}

enum CoupPlan: String, Codable, CaseIterable, Identifiable {
    case discret, rapide, force

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .discret: return "Discret"
        case .rapide: return "Rapide"
        case .force: return "Par la force"
        }
    }

    var detail: String {
        switch self {
        case .discret: return "Personne ne doit rien voir. Le meilleur butin si tout se passe bien, mais les cibles les mieux gardées le pardonnent mal."
        case .rapide: return "Entrer, prendre, sortir en trois minutes. Plus sûr, mais on laisse une partie du butin."
        case .force: return "Des armes, des cris, des otages peut-être. Ça marche souvent. Les juges, eux, ne pardonnent pas."
        }
    }
}

// MARK: - État sauvegardé

struct VieEquipier: Codable, Equatable, Identifiable {
    var id = UUID()
    var prenom: String
    var surnom: String
    var role: String
    var talent: Int
    var fiabilite: Int
    /// Part du butin demandée, en %.
    var part: Int

    var nom: String { "\(prenom) « \(surnom) »" }
}

struct VieCoupEnCours: Codable, Equatable {
    var cibleId: String
    var equipe: [VieEquipier] = []
    var candidats: [VieEquipier] = []
    var reperages = 0
    var plan: CoupPlan = .discret
    /// Années de préparation (plus c'est long, plus ça fuit).
    var annees = 0
}

// MARK: - Système

enum MilieuCoups {

    static let cibles: [MilieuCible] = DonneesJSON.chargerTableaux(dossier: "MilieuCoups", type: MilieuCible.self)

    static func cible(_ id: String?) -> MilieuCible? {
        guard let id else { return nil }
        return cibles.first { $0.id == id }
    }

    static func coup(_ j: Joueur) -> VieCoupEnCours? { VieMilieu.etat(j).coup }

    static func modifier(_ j: inout Joueur, _ f: (inout VieCoupEnCours) -> Void) {
        VieMilieu.modifier(&j) { m in
            guard var c = m.coup else { return }
            f(&c)
            m.coup = c
        }
    }

    static func peutPreparer(_ j: Joueur) -> Bool {
        j.age >= 16 && !VieMilieu.etat(j).balance && !j.vieEtat.justice.enPrison
    }

    static func ciblesAccessibles(_ j: Joueur) -> [MilieuCible] {
        let n = VieMilieu.notoriete(j) + (VieMilieu.etat(j).coupsReussis ?? 0) * 8
        return cibles.filter { j.age >= $0.minAge && $0.notorieteMin <= n + 10 }.sorted { $0.difficulte < $1.difficulte }
    }

    static let surnoms = ["la Fouine", "Mains-d'Or", "le Muet", "Rapide", "le Prof", "Belle-Gueule", "la Pince", "Petit Louis", "le Notaire",
                          "Clé-à-Molette", "la Comète", "Tonnerre", "le Chat", "Grand Max", "Zéro", "la Douane", "le Pasteur", "Sésame"]

    static func genererCandidats(_ roles: [String], membre: Bool) -> [VieEquipier] {
        roles.flatMap { r in
            (0..<3).map { _ -> VieEquipier in
                let talent = Int.random(in: 30...95)
                let fiab = min(100, Int.random(in: 20...95) + (membre ? 8 : 0))
                let part = 4 + talent / 9 + (r == "perceur" || r == "informaticien" ? 3 : 0) + (fiab > 75 ? 2 : 0)
                return VieEquipier(prenom: VieDonnees.prenom(Bool.random() ? .homme : .femme), surnom: surnoms.auHasard("le Muet"),
                                   role: r, talent: talent, fiabilite: fiab, part: part)
            }
        }
    }

    // MARK: Préparer

    static func choisir(_ c: MilieuCible, _ j: inout Joueur) -> String {
        guard peutPreparer(j) else { return "Ce n'est pas le moment." }
        if coup(j) != nil { return "Tu prépares déjà un coup. Un à la fois." }
        let candidats = genererCandidats(c.roles, membre: VieMilieu.etat(j).membre)
        VieMilieu.modifier(&j) { $0.coup = VieCoupEnCours(cibleId: c.id, candidats: candidats) }
        return "Tu commences à préparer ton coup : \(c.nom.lowercased()). Il te faut une équipe : \(c.roles.map { CoupRole.nom($0).lowercased() }.joined(separator: ", "))."
    }

    static func recruter(_ e: VieEquipier, _ j: inout Joueur) -> String {
        guard coup(j) != nil else { return "" }
        modifier(&j) { c in
            c.equipe.removeAll { $0.role == e.role }
            c.equipe.append(e)
        }
        let fiable = e.fiabilite >= 70 ? "On dit qu'il n'a jamais parlé." : (e.fiabilite < 40 ? "On dit aussi qu'il parle trop quand il boit." : "Personne ne sait vraiment ce qu'il vaut sous pression.")
        return "\(e.nom) accepte de faire partie du coup comme \(CoupRole.nom(e.role).lowercased()), pour \(e.part) % du butin. \(fiable)"
    }

    static func reperer(_ j: inout Joueur) -> String {
        guard let co = coup(j), let c = cible(co.cibleId) else { return "" }
        if co.reperages >= 3 { return "Tu connais déjà la cible par cœur. Y retourner, c'est te faire remarquer." }
        let cle = "coup_reperage_\(co.reperages)"
        let faits = VieMilieu.etat(j).actionsAnnee.filter { $0.hasPrefix("coup_reperage") }.count
        if faits >= 2 { return "Deux repérages cette année. Revenir encore serait trop visible." }
        guard MilieuTrafic.payer(c.reperageCout, &j) else { return "Un repérage sérieux coûte \(Format.argent(c.reperageCout)) (location de voiture, matériel, informateurs)." }
        VieMilieu.modifier(&j) { $0.actionsAnnee.append(cle) }
        modifier(&j) { $0.reperages += 1 }
        if VieHasard.reussi(0.12) {
            VieMilieu.modifier(&j) { $0.chaleur += 6 }
            return "Pendant ton repérage, un employé t'a regardé un peu trop longtemps. Tu as noté les horaires, les caméras, les angles morts. Lui a peut-être noté ta plaque."
        }
        return ["Tu passes des heures dans une voiture garée en face. Horaires, relèves, caméras : tout est noté dans un carnet.",
                "Tu te fais passer pour un client, puis pour un livreur. Tu connais maintenant les lieux mieux que ceux qui y travaillent.",
                "Ton équipe reconstitue les lieux dans un entrepôt vide. Chacun répète ses gestes jusqu'à ne plus y penser."].auHasard("Repérage fait.")
    }

    static func choisirPlan(_ p: CoupPlan, _ j: inout Joueur) {
        modifier(&j) { $0.plan = p }
    }

    static func abandonner(_ j: inout Joueur) -> String {
        guard let co = coup(j) else { return "" }
        VieMilieu.modifier(&j) { $0.coup = nil }
        if !co.equipe.isEmpty && VieHasard.reussi(0.15) {
            VieMilieu.modifier(&j) { $0.chaleur += 8 }
            return "Tu annules tout. Un membre de l'équipe, déçu, raconte l'histoire dans un bar. Elle finit par arriver aux mauvaises oreilles."
        }
        return "Tu annules tout. L'équipe se disperse sans un mot. Certains coups ne doivent jamais avoir lieu."
    }

    // MARK: Chances

    static func rolesManquants(_ co: VieCoupEnCours) -> [String] {
        guard let c = cible(co.cibleId) else { return [] }
        return c.roles.filter { r in !co.equipe.contains { $0.role == r } }
    }

    static func chance(_ co: VieCoupEnCours, _ j: Joueur) -> Double {
        guard let c = cible(co.cibleId) else { return 0 }
        var ch = 1 - c.difficulte
        ch += co.equipe.reduce(0.0) { $0 + Double($1.talent - 50) / 400 }
        ch += Double(co.reperages) * 0.07
        ch += Double(j.stats.intelligence - 50) / 500
        switch co.plan {
        case .discret: ch -= c.difficulte >= 0.6 ? 0.05 : 0
        case .rapide: ch += 0.05
        case .force: ch += 0.08
        }
        ch -= Double(rolesManquants(co).count) * 0.25
        return VieHasard.borne(ch)
    }

    static func chanceTexte(_ ch: Double) -> String {
        switch ch {
        case ..<0.3: return "Presque suicidaire"
        case ..<0.5: return "Très risqué"
        case ..<0.65: return "Risqué"
        case ..<0.8: return "Jouable"
        default: return "Bien préparé"
        }
    }

    // MARK: Passer à l'acte

    static func executer(_ j: inout Joueur) -> [String] {
        guard let co = coup(j), let c = cible(co.cibleId) else { return [] }
        if j.vieEtat.justice.enPrison { return ["Tu es en prison."] }
        if VieMilieu.etat(j).actionsAnnee.contains("coup_execute") { return ["Un coup par an. Il faut laisser retomber la poussière."] }
        let manquants = rolesManquants(co)
        if !manquants.isEmpty { return ["Il te manque encore : \(manquants.map { CoupRole.nom($0).lowercased() }.joined(separator: ", "))."] }
        VieMilieu.modifier(&j) { $0.actionsAnnee.append("coup_execute"); $0.coup = nil }

        let ch = chance(co, j)
        var lignes: [String] = []
        // Le traître éventuel.
        let traitre = co.equipe.first { VieHasard.reussi(Double(100 - $0.fiabilite) / 500 + (co.plan == .force ? 0.03 : 0)) }
        let traitreParle = traitre != nil && Bool.random()

        // Approche
        let guetteur = co.equipe.first { $0.role == "guetteur" || $0.role == "infiltre" }
        lignes.append((guetteur?.talent ?? 50) >= 60
            ? "Le soir venu, \(guetteur?.prenom ?? "ton guetteur") confirme : la voie est libre. Tout le monde est en place."
            : "L'approche est plus nerveuse que prévu. Une voiture passe deux fois. Personne ne dit rien.")

        if let t = traitre, traitreParle, VieHasard.reussi(0.6) {
            VieSysteme.signaler("coup_trahison", &j)
            VieSysteme.signaler("coup_rate", &j)
            VieMilieu.modifier(&j) { $0.coupsRates = ($0.coupsRates ?? 0) + 1 }
            lignes.append("Des gyrophares partout, avant même que vous ayez touché à quoi que ce soit. Quelqu'un avait parlé. Au commissariat, tu comprends que c'était \(t.nom).")
            let mois = Int.random(in: c.peineMinMois...max(c.peineMinMois, c.peineMaxMois)) / 2
            if mois > 0 {
                return lignes + VieMilieu.arreter("tentative de vol en bande organisée", mois: max(6, mois), texte: "On te passe les menottes sur le parking.", &j)
            }
            VieMilieu.modifier(&j) { $0.chaleur += c.chaleur / 2 }
            return lignes + ["Les propriétaires préfèrent ne pas porter plainte. Mais ils savent maintenant qui tu es."]
        }

        let jet = Double.random(in: 0..<1)
        let multiplicateur: Double = co.plan == .rapide ? 0.75 : (co.plan == .force ? 1.05 : 1)
        if co.plan == .force { j.stats.karma -= 12; j.stats.borner() }

        if jet < ch + 0.15 {
            let partiel = jet >= ch
            let coeur = co.equipe.first { $0.role == "perceur" || $0.role == "informaticien" || $0.role == "gros_bras" }
            lignes.append(partiel
                ? "Au cœur de l'opération, quelque chose cède trop tard. Vous devez partir avec une partie seulement."
                : "\(coeur?.prenom ?? "Ton équipe") fait exactement ce qui était prévu. Les secondes passent, longues comme des heures.")
            var butin = Double(Int.random(in: c.butinMin...max(c.butinMin, c.butinMax))) * multiplicateur
            if partiel { butin *= 0.35 }
            let parts = co.equipe.reduce(0) { $0 + $1.part }
            var net = Int(butin) * max(10, 100 - parts) / 100
            let chauffeur = co.equipe.first { $0.role == "chauffeur" }
            lignes.append((chauffeur?.talent ?? 50) >= 55
                ? "\(chauffeur?.prenom ?? "Le chauffeur") vous sort de la ville par des rues que personne ne surveille. Personne ne vous suit."
                : "La fuite est chaotique : un feu grillé, une sirène au loin. Vous changez trois fois de voiture.")
            if let t = traitre, !traitreParle {
                let vole = net / 2
                net -= vole
                lignes.append("Au moment du partage, \(t.nom) n'est pas au rendez-vous. Ni lui, ni le sac qu'il portait. \(Format.argent(vole)) de moins pour toi.")
                VieSysteme.signaler("coup_trahison", &j)
            }
            VieMilieu.modifier(&j) {
                $0.argentSale += net
                $0.chaleur += Int(Double(c.chaleur) * (partiel ? 1.3 : 1) * (co.plan == .force ? 1.4 : 1))
                $0.respect += partiel ? 4 : 10
                $0.coupsReussis = ($0.coupsReussis ?? 0) + 1
            }
            var v = j.vieEtat
            v.justice.notoriete += partiel ? 3 : 8
            v.justice.crimes += 1
            j.vieEtat = v
            if co.plan == .force && VieHasard.reussi(0.25) {
                j.stats.karma -= 10
                lignes.append("Un vigile a été blessé pendant l'opération. Les journaux publient sa photo, avec ses enfants.")
            }
            if let t = traitre, traitreParle {
                lignes.append("Quelques semaines plus tard, tu apprends que \(t.nom) se vante dans les bars.")
                if VieMilieu.etat(j).enquete == nil {
                    VieMilieu.modifier(&j) { $0.enquete = 0 }
                    VieSysteme.signaler("enquete_ouverte", &j)
                }
            }
            j.stats.bonheur += partiel ? 2 : 10
            j.stats.borner()
            VieSysteme.signaler("coup_reussi", &j)
            lignes.append("Ta part : \(Format.argent(net)) d'argent sale, après celle de l'équipe (\(parts) %).")
            return lignes
        }

        // Échec
        VieMilieu.modifier(&j) { $0.coupsRates = ($0.coupsRates ?? 0) + 1; $0.chaleur += c.chaleur }
        VieSysteme.signaler("coup_rate", &j)
        lignes.append(["Une alarme que personne n'avait repérée se déclenche. Il faut tout abandonner.",
                       "Le coffre ne cède pas. Les minutes passent, puis il est trop tard.",
                       "Un employé est resté plus tard que prévu. Tout s'écroule en une seconde."].auHasard("Ça rate."))
        let chauffeur = co.equipe.first { $0.role == "chauffeur" }
        let arrestation = VieBonus.arrestation(0.55 + (co.plan == .force ? 0.1 : 0) - Double(chauffeur?.talent ?? 50) / 400)
        if VieHasard.reussi(arrestation) {
            var mois = Int.random(in: c.peineMinMois...max(c.peineMinMois, c.peineMaxMois))
            if co.plan == .force { mois = mois * 3 / 2 }
            if mois == 0 {
                j.stats.sante -= Int.random(in: 20...40)
                j.stats.borner()
                return lignes + ["Les hommes de la maison vous rattrapent avant la police. Ils ne portent pas plainte. Ils règlent ça eux-mêmes."]
            }
            return lignes + VieMilieu.arreter("vol en bande organisée", mois: mois, texte: "La voiture est bloquée au premier carrefour. Tu as encore les gants aux mains.", &j)
        }
        if co.plan == .force && VieHasard.reussi(0.3) {
            j.stats.sante -= Int.random(in: 15...35)
            lignes.append("Tu t'en sors avec une blessure qu'il faudra soigner sans passer par l'hôpital.")
        }
        j.stats.bonheur -= 8
        j.stats.borner()
        lignes.append("Vous vous dispersez dans la nuit, les mains vides. Il faudra des mois pour que la peur retombe.")
        return lignes
    }

    // MARK: +1 an

    static func vieillir(_ j: inout Joueur) -> [String] {
        guard let co = coup(j), !j.vieEtat.justice.enPrison else { return [] }
        var lignes: [String] = []
        let membre = VieMilieu.etat(j).membre
        let roles = cible(co.cibleId)?.roles ?? []
        modifier(&j) { c in
            c.annees += 1
            c.candidats = genererCandidats(roles, membre: membre)
        }
        if !co.equipe.isEmpty {
            let fiab = Double(co.equipe.reduce(0) { $0 + $1.fiabilite }) / Double(co.equipe.count)
            if VieHasard.reussi(0.08 * Double(co.annees + 1) * (100 - fiab) / 50) {
                VieMilieu.modifier(&j) { $0.chaleur += 10 }
                lignes.append("Ton projet de coup commence à se savoir. Une préparation trop longue finit toujours par fuiter.")
            }
            if let e = co.equipe.randomElement(), VieHasard.reussi(0.1) {
                modifier(&j) { c in c.equipe.removeAll { $0.id == e.id } }
                lignes.append("\(e.nom) quitte l'équipe : une autre affaire, ou la peur. Il faudra le remplacer.")
            }
        }
        return lignes
    }
}

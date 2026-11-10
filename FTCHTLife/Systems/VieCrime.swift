import Foundation

/// Crimes, procès, prison.
enum VieCrime {

    static let prisons = [
        "Centre pénitentiaire des Mouettes", "Maison d'arrêt de Saint-Grumeau", "Prison des Trois-Verrous",
        "Centre de détention du Bois-Tordu", "Pénitencier de la Pointe-aux-Regrets", "Maison centrale des Glaïeuls",
    ]

    // MARK: - Commettre un crime

    static func disponibles(_ j: Joueur) -> [CrimeDefinition] {
        VieDonnees.crimes.filter { j.age >= $0.minAge }.sorted { $0.difficulty < $1.difficulty }
    }

    /// Commet un crime. Renvoie le texte affiché. Une arrestation crée un procès en attente.
    static func commettre(_ c: CrimeDefinition, _ j: inout Joueur) -> String {
        var v = j.vieEtat
        if v.justice.enPrison { return "Tu es déjà en prison. Un crime à la fois." }
        if v.justice.proces != nil { return "Ton procès n'a pas encore eu lieu. Fais profil bas." }
        let cle = "vie_crime_\(c.id)"
        if j.actionsAnnee.filter({ $0.hasPrefix("vie_crime_") }).count >= 3 { return "Trois crimes cette année, c'est assez. Même les criminels prennent des vacances." }
        j.actionsAnnee.append(cle)
        v.justice.crimes += 1

        // Expérience et intelligence aident.
        let experience = min(0.2, Double(v.justice.crimes) * 0.01)
        let reussite = VieHasard.borne(1 - c.difficulty + Double(j.stats.intelligence - 50) / 400 + experience)
        j.stats.karma += c.karma
        if VieHasard.reussi(reussite) {
            let butin = Int.random(in: c.lootMin...max(c.lootMin, c.lootMax))
            j.argent += butin
            v.justice.notoriete = min(100, v.justice.notoriete + max(1, Int(c.difficulty * 10)))
            j.vieEtat = v
            VieSysteme.signaler("crime_reussi", &j)
            let texte = c.successTexts.auHasard("Ça a marché !")
            return butin > 0 ? "\(texte) (+\(Format.argent(butin)))" : texte
        }
        // Raté : arrêté ou non ?
        let arrestation = VieBonus.arrestation(VieHasard.borne(c.arrestChance + Double(v.justice.casier.count) * 0.03))
        if VieHasard.reussi(arrestation) {
            v.justice.proces = VieProces(crimeId: c.id, crimeNom: c.name, moisMin: c.sentenceMinMonths, moisMax: c.sentenceMaxMonths,
                                         amendeMin: c.fineMin, amendeMax: c.fineMax)
            j.vieEtat = v
            VieSysteme.signaler("arrestation", &j)
            return c.arrestTexts.auHasard("La police t'a attrapé·e.") + " 🚔 Tu es en garde à vue. Il va falloir choisir un avocat."
        }
        j.vieEtat = v
        VieSysteme.signaler("crime_rate", &j)
        return c.failTexts.auHasard("Raté. Mais personne ne t'a vu·e.")
    }

    // MARK: - Procès

    enum Avocat: String, CaseIterable, Identifiable {
        case commisOffice, correct, tenor, plaiderCoupable

        var id: String { rawValue }

        var titre: String {
            switch self {
            case .commisOffice: return "Avocat commis d'office (gratuit)"
            case .correct: return "Avocat correct (5 000 €)"
            case .tenor: return "Ténor du barreau (40 000 €)"
            case .plaiderCoupable: return "Plaider coupable"
            }
        }

        var detail: String {
            switch self {
            case .commisOffice: return "Il a lu ton dossier dans l'ascenseur."
            case .correct: return "Costume propre, plaidoirie honnête."
            case .tenor: return "Il a fait pleurer trois jurés et un greffier."
            case .plaiderCoupable: return "Peine réduite, dignité aussi."
            }
        }

        var prix: Int {
            switch self {
            case .commisOffice, .plaiderCoupable: return 0
            case .correct: return 5_000
            case .tenor: return 40_000
            }
        }

        var chanceAcquittement: Double {
            switch self {
            case .commisOffice: return 0.12
            case .correct: return 0.3
            case .tenor: return 0.6
            case .plaiderCoupable: return 0
            }
        }
    }

    static func juger(_ avocat: Avocat, _ j: inout Joueur) -> [String] {
        var v = j.vieEtat
        guard let p = v.justice.proces else { return [] }
        if avocat.prix > 0 && j.argent < avocat.prix { return ["Tu n'as pas les moyens de cet avocat."] }
        j.argent -= avocat.prix
        v.justice.proces = nil
        let karmaBonus = Double(j.stats.karma - 50) / 500
        let recidive = Double(v.justice.casier.count) * 0.05
        if VieHasard.reussi(VieHasard.borne(avocat.chanceAcquittement + karmaBonus - recidive)) && avocat != .plaiderCoupable {
            j.vieEtat = v
            VieSysteme.signaler("proces_gagne", &j)
            j.stats.bonheur += 10
            return [["Acquitté·e ! Le juge s'est excusé de t'avoir dérangé·e.", "Non coupable ! Ton avocat a parlé 3 heures, tout le monde s'est endormi, et c'est passé.", "Vice de procédure : le policier avait mal orthographié ton nom. Tu es libre."].auHasard("Acquitté·e !")]
        }
        var mois = Int.random(in: p.moisMin...max(p.moisMin, p.moisMax))
        if avocat == .plaiderCoupable { mois = mois * 6 / 10 }
        if avocat == .tenor { mois = mois * 7 / 10 }
        mois += v.justice.casier.count * 2
        let amende = Int.random(in: p.amendeMin...max(p.amendeMin, p.amendeMax))
        j.argent -= amende
        v.justice.casier.append(VieCasierLigne(age: j.age, crime: p.crimeNom, mois: mois))
        j.vieEtat = v
        VieSysteme.signaler("proces_perdu", &j)
        var lignes = ["⚖️ Coupable de « \(p.crimeNom) ». Amende de \(Format.argent(amende))."]
        if mois > 0 {
            lignes += emprisonner(mois, &j)
        } else {
            lignes.append("Pas de prison, juste un sermon du juge et une mention au casier.")
        }
        return lignes
    }

    // MARK: - Prison

    @discardableResult
    static func emprisonner(_ mois: Int, _ j: inout Joueur) -> [String] {
        var v = j.vieEtat
        let deja = v.justice.enPrison
        v.justice.moisRestants += mois
        if !deja {
            v.justice.prison = prisons.auHasard("la prison")
            v.justice.comportement = 50
            // Un codétenu
            let g = j.genre
            v.proches.removeAll { $0.role == .codetenu }
            v.proches.append(VieProche(prenom: VieDonnees.prenom(g), nom: VieDonnees.nomFamille(), genre: g, role: .codetenu,
                                       age: max(18, j.age + Int.random(in: -10...20)), lien: Int.random(in: 20...60)))
        }
        j.vieEtat = v
        // Plus de travail ni d'études en prison.
        if !deja {
            j.emploi = nil
            j.etudes = nil
            VieSysteme.signaler("prison_entree", &j)
        }
        j.stats.bonheur -= deja ? 5 : 20
        return [deja ? "Ta peine est rallongée de \(dureeTexte(mois))."
                     : "🔒 Condamné·e à \(dureeTexte(mois)) de prison. Direction : \(v.justice.prison ?? "la prison")."]
    }

    static func liberer(_ j: inout Joueur, evasion: Bool = false) -> String {
        var v = j.vieEtat
        v.justice.moisRestants = 0
        v.proches.removeAll { $0.role == .codetenu }
        let prison = v.justice.prison ?? "prison"
        v.justice.prison = nil
        if evasion { v.justice.evasions += 1 }
        j.vieEtat = v
        VieSysteme.signaler(evasion ? "evasion" : "prison_sortie", &j)
        return evasion ? "Tu t'es évadé·e de \(prison) ! Tu es en cavale."
                       : "🔓 Tu sors de \(prison). L'air libre sent bon. Le RER beaucoup moins."
    }

    static func dureeTexte(_ mois: Int) -> String {
        if mois < 12 { return "\(mois) mois" }
        let a = mois / 12, m = mois % 12
        return "\(a) an\(a > 1 ? "s" : "")" + (m > 0 ? " et \(m) mois" : "")
    }

    /// Une année passe en prison.
    static func vieillir(_ j: inout Joueur) -> [String] {
        var v = j.vieEtat
        v.justice.actionsPrisonAnnee = []
        guard v.justice.enPrison else { j.vieEtat = v; return [] }
        let purges = min(12, v.justice.moisRestants)
        v.justice.moisRestants -= purges
        v.justice.moisPurges += purges
        j.stats.bonheur -= 4
        j.vieEtat = v
        if v.justice.moisRestants <= 0 {
            return [liberer(&j)]
        }
        // Libération conditionnelle automatique pour bonne conduite.
        if v.justice.comportement >= 80 && v.justice.moisRestants > 12 && VieHasard.reussi(0.25) {
            return ["Grâce à ta conduite exemplaire, tu obtiens une libération conditionnelle.", liberer(&j)]
        }
        return ["Encore \(dureeTexte(v.justice.moisRestants)) à tirer."]
    }

    /// Activités disponibles en prison (fichiers Data/CrimePrison).
    static func faire(_ a: CrimeActivitePrison, _ j: inout Joueur) -> String {
        var v = j.vieEtat
        guard v.justice.enPrison else { return "Tu n'es pas en prison." }
        if v.justice.actionsPrisonAnnee.contains(a.id) { return "Tu l'as déjà fait cette année. Les gardiens te surveillent." }
        v.justice.actionsPrisonAnnee.append(a.id)
        j.vieEtat = v
        let estEvasion = a.id.contains("evad") || a.id.contains("evasion")
        var risque = a.risk ?? 0
        if estEvasion { risque = 1 - VieBonus.evasion(1 - risque) }
        if VieHasard.reussi(risque) {
            if let fx = a.badEffects { appliquer(fx, &j) }
            if estEvasion { var w = j.vieEtat; w.justice.comportement = max(0, w.justice.comportement - 30); j.vieEtat = w }
            return (a.badTexts ?? []).auHasard("Ça a mal tourné.")
        }
        if estEvasion {
            return a.texts.auHasard("Tu t'es fait la malle !") + " " + liberer(&j, evasion: true)
        }
        if let fx = a.effects { appliquer(fx, &j) }
        var w = j.vieEtat
        w.justice.comportement = min(100, w.justice.comportement + 4)
        j.vieEtat = w
        if w.justice.enPrison == false { return a.texts.auHasard("") + " " + liberer(&j) }
        return a.texts.auHasard("Le temps passe.")
    }

    /// Effets simples (activités, étapes). `bond` ne s'applique pas ici.
    static func appliquer(_ fx: VieEffetsSimples, _ j: inout Joueur) {
        j.stats.sante += fx.health ?? 0
        j.stats.bonheur += fx.happiness ?? 0
        j.stats.intelligence += fx.smarts ?? 0
        j.stats.apparence += fx.looks ?? 0
        j.stats.karma += fx.karma ?? 0
        j.argent += fx.money ?? 0
        j.stats.borner()
        if let m = fx.jailMonths, m != 0 {
            var v = j.vieEtat
            if v.justice.enPrison {
                v.justice.moisRestants = max(0, v.justice.moisRestants + m)
                j.vieEtat = v
            } else if m > 0 {
                emprisonner(m, &j)
            }
        }
    }

    /// Demande de libération conditionnelle (une fois par an).
    static func demanderConditionnelle(_ j: inout Joueur) -> String {
        var v = j.vieEtat
        guard v.justice.enPrison else { return "" }
        if v.justice.actionsPrisonAnnee.contains("conditionnelle") { return "La commission t'a déjà reçu·e cette année." }
        v.justice.actionsPrisonAnnee.append("conditionnelle")
        j.vieEtat = v
        let chance = VieHasard.borne(Double(v.justice.comportement) / 200 + Double(j.stats.karma - 50) / 300)
        if VieHasard.reussi(chance) {
            return "La commission accepte ta libération conditionnelle ! " + liberer(&j)
        }
        return ["Refusé. Un membre de la commission t'a reconnu·e : tu lui avais volé son vélo en 2014.",
                "Refusé. Ton dossier dit « sourit bizarrement ».",
                "Refusé. Reviens l'an prochain avec un CV et un sourire."].auHasard("Refusé.")
    }
}

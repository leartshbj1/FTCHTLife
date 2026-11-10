import Foundation

/// Maladies, soins, addictions.
enum VieSanteSysteme {

    // MARK: - Attraper / guérir

    @discardableResult
    static func attraper(_ id: String, _ j: inout Joueur) -> [String] {
        guard let m = VieDonnees.maladie(id) else { return [] }
        var v = j.vieEtat
        guard !v.sante.a(id) else { return [] }
        v.sante.maladies.append(VieMaladie(id: id, depuisAge: j.age))
        j.vieEtat = v
        VieSysteme.signaler("maladie", &j)
        return ["🤒 Diagnostic : \(m.name). \(m.description)"]
    }

    @discardableResult
    static func guerirAuHasard(_ j: inout Joueur) -> [String] {
        var v = j.vieEtat
        guard let i = v.sante.maladies.indices.first(where: { !(VieDonnees.maladie(v.sante.maladies[$0].id)?.chronic ?? false) }) else { return [] }
        let m = v.sante.maladies.remove(at: i)
        v.sante.gueries += 1
        j.vieEtat = v
        VieSysteme.signaler("guerison", &j)
        return ["Tu es guéri·e : \(VieDonnees.maladie(m.id)?.name ?? "ta maladie") n'est plus qu'un mauvais souvenir."]
    }

    @discardableResult
    static func ajouterAddiction(_ id: String, _ j: inout Joueur) -> [String] {
        var v = j.vieEtat
        guard !v.sante.addictions.contains(id) else { return [] }
        v.sante.addictions.append(id)
        j.vieEtat = v
        VieSysteme.signaler("addiction", &j)
        let nom = VieDonnees.addiction(id)?.name ?? id
        return ["Tu es devenu·e accro : \(nom.lowercased()). Ça commence toujours par « juste une fois »."]
    }

    // MARK: - +1 an

    static func vieillir(_ j: inout Joueur) -> [String] {
        var lignes: [String] = []
        var v = j.vieEtat
        v.sante.visitesAnnee = 0
        for i in v.sante.maladies.indices { v.sante.maladies[i].traitee = false }

        // Nouvelles maladies (au plus une par an, sauf malchance).
        let candidates = VieDonnees.maladies.filter { j.age >= $0.minAge && j.age <= $0.maxAge && !v.sante.a($0.id) }
        let fragilite = j.stats.sante < 40 ? 1.5 : (j.stats.sante > 80 ? 0.7 : 1.0)
        let maxNouvelles = VieHasard.reussi(0.1) ? 2 : 1
        var nouvelles = 0
        for m in candidates.shuffled() where nouvelles < maxNouvelles {
            if VieHasard.reussi(m.yearlyChance * fragilite) {
                v.sante.maladies.append(VieMaladie(id: m.id, depuisAge: j.age))
                lignes.append("🤒 Tu as attrapé : \(m.name). \(m.description)")
                nouvelles += 1
            }
        }
        j.vieEtat = v
        if nouvelles > 0 { VieSysteme.signaler("maladie", &j) }
        v = j.vieEtat

        // Effets des maladies, guérisons naturelles.
        var restantes: [VieMaladie] = []
        for mal in v.sante.maladies {
            guard let m = VieDonnees.maladie(mal.id) else { continue }
            j.stats.sante += VieBonus.sante(m.healthPerYear)
            j.stats.bonheur += m.happinessPerYear ?? 0
            if !m.chronic && mal.depuisAge < j.age && VieHasard.reussi(m.selfHealChance) {
                lignes.append("Ton corps s'est débarrassé tout seul de : \(m.name). Bravo à lui.")
                v.sante.gueries += 1
            } else {
                restantes.append(mal)
            }
        }
        v.sante.maladies = restantes

        // Addictions
        for id in v.sante.addictions {
            guard let a = VieDonnees.addiction(id) else { continue }
            j.stats.sante += a.yearlyHealth
            j.stats.bonheur += a.yearlyHappiness
            j.argent += a.yearlyMoney
            if VieHasard.reussi(0.35) { lignes.append(a.texts.auHasard("Ton addiction te coûte cher.")) }
        }
        j.stats.borner()
        j.vieEtat = v
        return lignes
    }

    /// Cause de décès due à une maladie, ou nil.
    static func causeDeces(_ j: Joueur) -> String? {
        for mal in j.vieEtat.sante.maladies {
            guard let m = VieDonnees.maladie(mal.id) else { continue }
            let facteur = j.stats.sante < 20 ? 2.5 : 1.0
            if VieHasard.reussi(m.deathChancePerYear * facteur) && VieBonus.peutMourir() {
                return "des suites de : \(m.name.lowercased())"
            }
        }
        return nil
    }

    // MARK: - Soins

    enum Soin: String, CaseIterable, Identifiable {
        case medecin, hopital
        var id: String { rawValue }
        var titre: String { self == .medecin ? "Médecin généraliste" : "Hôpital" }
        var icone: String { self == .medecin ? "stethoscope" : "cross.case.fill" }
    }

    static func prix(_ soin: Soin, _ m: SanteMaladie) -> Int {
        soin == .medecin ? m.costDoctor : m.costHospital
    }

    static func soigner(_ id: String, avec soin: Soin, _ j: inout Joueur) -> String {
        var v = j.vieEtat
        guard let i = v.sante.maladies.firstIndex(where: { $0.id == id }), let m = VieDonnees.maladie(id) else { return "" }
        if v.sante.maladies[i].traitee { return "Tu as déjà essayé de soigner ça cette année. Patience." }
        let cout = j.age < 18 ? 0 : prix(soin, m)
        if j.argent < cout { return "Il te faut \(Format.argent(cout)). La santé n'a pas de prix, mais elle a un tarif." }
        j.argent -= cout
        v.sante.maladies[i].traitee = true
        v.sante.visitesAnnee += 1
        j.vieEtat = v
        if soin == .hopital { VieSysteme.signaler("hopital", &j) }
        let base = soin == .medecin ? m.cure.doctor : m.cure.hospital
        if m.chronic {
            j.stats.sante += soin == .medecin ? 4 : 10
            j.stats.borner()
            return "\(m.name) ne se guérit pas, mais le traitement te soulage. (+santé)"
        }
        if VieHasard.reussi(VieBonus.guerison(base)) {
            var w = j.vieEtat
            w.sante.maladies.removeAll { $0.id == id }
            w.sante.gueries += 1
            j.vieEtat = w
            j.stats.sante += 6
            j.stats.borner()
            VieSysteme.signaler("guerison", &j)
            return soin == .medecin
                ? ["Le médecin t'a guéri·e de : \(m.name). Il a aussi essayé de te vendre des vitamines.", "Guéri·e de \(m.name.lowercased()) ! Le médecin a mis 4 minutes, salle d'attente comprise : 3 heures."].auHasard("Guéri·e !")
                : ["L'hôpital t'a guéri·e de : \(m.name). La nourriture, par contre, a failli t'achever.", "Guéri·e de \(m.name.lowercased()) ! Ton voisin de chambre ronflait comme un tracteur, mais tu es guéri·e."].auHasard("Guéri·e !")
        }
        return "Le traitement n'a pas marché cette fois. \(m.name) s'accroche."
    }

    static func alternative(_ alt: SanteAlternative, pour id: String, _ j: inout Joueur) -> String {
        var v = j.vieEtat
        guard let i = v.sante.maladies.firstIndex(where: { $0.id == id }), let m = VieDonnees.maladie(id) else { return "" }
        if j.argent < alt.cost && j.age >= 18 { return "Il te faut \(Format.argent(alt.cost))." }
        if j.age >= 18 { j.argent -= alt.cost }
        v.sante.maladies[i].traitee = true
        j.vieEtat = v
        let texte = alt.texts.auHasard("Ça sentait l'encens.")
        if !m.chronic && VieHasard.reussi(VieBonus.guerison(m.cure.alternative + alt.cureBonus)) {
            var w = j.vieEtat
            w.sante.maladies.removeAll { $0.id == id }
            j.vieEtat = w
            VieSysteme.signaler("guerison", &j)
            return texte + " Et… tu es guéri·e ! Personne ne comprend pourquoi."
        }
        return texte + " Aucun effet, à part sur ton compte en banque."
    }

    static func desintox(_ id: String, _ j: inout Joueur) -> String {
        guard let a = VieDonnees.addiction(id) else { return "" }
        let cout = j.age < 18 ? 0 : a.rehabCost
        if j.argent < cout { return "La cure coûte \(Format.argent(cout))." }
        j.argent -= cout
        VieSysteme.signaler("cure_desintox", &j)
        if VieHasard.reussi(VieBonus.guerison(a.rehabSuccess)) {
            var v = j.vieEtat
            v.sante.addictions.removeAll { $0 == id }
            j.vieEtat = v
            j.stats.bonheur += 8
            return "Cure réussie : tu es libéré·e de ton addiction (\(a.name.lowercased())). Tu as même gardé le t-shirt souvenir."
        }
        return "Cure ratée. Tu as tenu trois semaines, puis tu as craqué dans une station-service."
    }

    /// Bilan de santé : petit bonus et diagnostic.
    static func bilan(_ j: inout Joueur) -> String {
        let cout = j.age < 18 ? 0 : 80
        if j.argent < cout { return "Le bilan coûte 80 €." }
        j.argent -= cout
        j.stats.sante += 2
        j.stats.borner()
        let maladies = j.vieEtat.sante.maladies.compactMap { VieDonnees.maladie($0.id)?.name }
        if maladies.isEmpty {
            return ["Bilan parfait. Le médecin t'a dit de « manger moins de fromage », comme à tout le monde.", "Tout va bien. Le médecin a l'air presque déçu."].auHasard("Tout va bien.")
        }
        return "Le médecin a trouvé : \(maladies.joined(separator: ", ")). Il a fait « hmm » trois fois."
    }
}

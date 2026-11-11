import Foundation

// Module « Entourage » : les proches, les collègues et la vie poussent le joueur à agir.
// Contenu : Data/Events/entourage_*.json (ids ent_…) et Data/Repercussions/entourage_*.json (ids rep_ent_…).
// Voir docs/ENTOURAGE.md.

/// Effets en plus pour les événements de l'entourage : `"effects": {"entourage": {...}}`.
/// Ils changent vraiment la situation du joueur (fiançailles, mariage, nouvel emploi…).
struct EntourageEffets: Codable, Equatable {
    /// Le joueur et son/sa partenaire se fiancent (émet `demande_mariage`).
    var fiancailles: Bool?
    /// Le joueur épouse son/sa partenaire (émet `mariage`).
    var mariage: Bool?
    /// Offre d'emploi acceptée : id d'un métier (Data/Careers), `"secteur:<secteur>"`,
    /// `"meme_secteur"` (secteur du métier actuel) ou `"auto"` (n'importe quel métier ouvert au profil).
    var offreEmploi: String?
    /// Échelon de départ du nouveau poste (0 = premier). Par défaut 0, ou l'échelon actuel pour `meme_secteur`.
    var niveau: Int?
    /// Bonus de salaire en % sur le salaire de l'échelon (ex. 15 = +15 %).
    var salaireBonus: Int?
    /// Le joueur quitte son emploi actuel (émet `demission`).
    var demission: Bool?
    /// Signaux communs à émettre (voir docs/REPERCUSSIONS.md), ex. `["demenagement"]`.
    var signaux: [String]?
}

enum EntourageTags {
    /// Tags de situation : ancienneté du couple, âge des enfants et des parents, ancienneté au travail.
    static func tags(_ j: Joueur) -> Set<String> {
        var t: Set<String> = []
        if j.partenaireActuel != nil {
            let annees = j.vieEtat.anneesEnsemble
            if annees >= 2 { t.insert("couple_2ans") }
            if annees >= 5 { t.insert("couple_5ans") }
        }
        for r in j.relations where r.vivant {
            switch r.type {
            case .enfant:
                if r.age < 3 { t.insert("enfant_bebe") }
                else if r.age < 12 { t.insert("enfant_petit") }
                else if r.age < 18 { t.insert("enfant_ado") }
                else { t.insert("enfant_adulte") }
            case .mere, .pere:
                if r.age >= 70 { t.insert("parent_age") }
                if r.age >= 80 { t.insert("parent_tres_age") }
            default:
                break
            }
        }
        if let e = j.emploi {
            if e.annees <= 1 { t.insert("poste_nouveau") }
            if e.annees >= 5 { t.insert("poste_ancien") }
        }
        if j.carriere != nil { t.insert("carriere") }
        return t
    }
}

extension GameEngine {

    /// Applique les effets « entourage » d'une issue. Renvoie les lignes à ajouter au journal.
    func entourageAppliquer(_ fx: EntourageEffets?, _ j: inout Joueur) -> [String] {
        guard let fx else { return [] }
        var lignes: [String] = []

        if fx.demission == true, j.emploi != nil || j.carriere != nil {
            let titre = j.emploi?.titre.lowercased() ?? "ton poste"
            if j.carriere != nil { terminerCarriere(&j, raison: .quit) } else { j.dernierEmploi = j.emploi; j.emploi = nil }
            lignes.append("Tu quittes ton poste de \(titre).")
            SignauxModules.signaler("demission", &j)
        }

        if let offre = fx.offreEmploi, let l = entourageEmbaucher(offre, niveau: fx.niveau, bonus: fx.salaireBonus, &j) {
            lignes.append(l)
        }

        if let p = j.partenaireActuel {
            if fx.fiancailles == true, j.vieEtat.statutCouple == nil {
                var v = j.vieEtat; v.statutCouple = .fiance; j.vieEtat = v
                lignes.append("💍 Tu es " + j.g("fiancé", "fiancée") + " à \(p.prenom).")
                SignauxModules.signaler("demande_mariage", &j)
            }
            if fx.mariage == true, j.vieEtat.statutCouple != .marie {
                var v = j.vieEtat; v.statutCouple = .marie; v.mariages += 1; j.vieEtat = v
                lignes.append("💒 Tu as épousé \(p.prenom).")
                SignauxModules.signaler("mariage", &j)
            }
        }

        for s in fx.signaux ?? [] { SignauxModules.signaler(s, &j) }
        j.stats.borner()
        return lignes
    }

    /// Embauche directe (offre d'emploi venue de l'entourage). Nil si l'offre ne peut pas aboutir sans rien dire.
    private func entourageEmbaucher(_ offre: String, niveau: Int?, bonus: Int?, _ j: inout Joueur) -> String? {
        if j.age < 16 { return nil }
        if let raison = empechementEmploi(j) { return "L'offre tombe à l'eau. " + raison }
        if j.etudes != nil { return "L'offre tombe à l'eau : tu es encore en études." }
        let moteur = CareerEngine()
        let profil = Self.profilCarriere(j)
        let ouverts = moteur.catalog.careers.filter {
            $0.kind != .illegal && $0.kind != .special && moteur.eligibility(for: $0, profile: profil).isEligible
                && CasierSysteme.raisonMetierFerme(id: $0.id, titre: $0.name, casier: j.casier) == nil
        }
        let actuel = j.carriere.flatMap { moteur.catalog.career($0.careerId) }
        var niveauDepart = niveau ?? 0
        let metier: CareerJob?
        switch offre {
        case "auto":
            metier = ouverts.filter { $0.id != actuel?.id }.randomElement()
        case "meme_secteur":
            guard let a = actuel else { metier = ouverts.randomElement(); break }
            metier = ouverts.filter { $0.sector == a.sector && $0.id != a.id }.randomElement() ?? ouverts.filter { $0.id != a.id }.randomElement()
            if niveau == nil { niveauDepart = j.carriere?.level ?? 0 }
        default:
            if offre.hasPrefix("secteur:") {
                let s = String(offre.dropFirst("secteur:".count))
                metier = ouverts.filter { $0.sector == s && $0.id != actuel?.id }.randomElement()
            } else if let m = moteur.catalog.career(offre) {
                if case let .blocked(raison) = moteur.eligibility(for: m, profile: profil) {
                    return "L'offre tombe à l'eau. " + raison
                }
                metier = m
            } else {
                metier = nil
            }
        }
        guard let m = metier else { return nil }
        var rng = SystemRandomNumberGenerator()
        var poste = moteur.newJob(m, level: min(max(0, niveauDepart), m.topLevel), using: &rng)
        poste.salary = m.step(poste.level).salary * (100 + (bonus ?? 0)) / 100
        terminerCarriere(&j, raison: .quit)
        if j.emploi != nil { j.dernierEmploi = j.emploi; j.emploi = nil }
        j.carriere = poste
        synchroniserEmploi(&j)
        SignauxModules.signaler("embauche", &j)
        let titre = moteur.title(of: poste, female: j.genre == .femme)
        return "💼 Nouveau poste : \(titre) chez \(poste.company), \(Format.argent(poste.salary))/an."
    }
}

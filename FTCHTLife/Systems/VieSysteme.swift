import Foundation

/// Point d'entrée du module pour le moteur.
///
/// Branchement (fil moteur) :
/// - `Joueur` : `var vie: VieEtat? = nil` ; `Effets` : `var vie: VieEffets?`
/// - init du moteur : `VieSysteme.acces = \.vie` et
///   `VieSysteme.signal = { s, j in var e = j.repercussions ?? RepercussionsEtat(); Repercussions.signaler(s, age: j.age, etat: &e); j.repercussions = e }`
/// - naissance : `lignes += VieSysteme.naissance(&j)`
/// - vieillir : `lignes += VieSysteme.vieillir(&j)` après les relations, et avant la mort naturelle
///   `if let c = VieSysteme.causeDeces(j) { mourir(&j, cause: c) }`
/// - tags : `t.formUnion(VieSysteme.tags(j))`
/// - tirage : ne garder que les événements où `VieSysteme.evenementAutorise(e, tags: t)`
/// - remplir : `t = VieSysteme.remplir(t, j)` avant le reste
/// - après chaque issue : `lignes += VieSysteme.apresIssue(evenementId: e.id, effets: eff.vie, &j)`
enum VieSysteme {

    /// Où est rangé l'état du module dans `Joueur` (\.vie).
    static var acces: WritableKeyPath<Joueur, VieEtat?>?

    /// Envoie un signal au module Répercussions (branché par le moteur).
    static var signal: ((String, inout Joueur) -> Void)?

    /// Inscription au casier judiciaire (module Casier) : infraction, mois de prison.
    /// Branchement : `VieSysteme.condamnation = { inf, mois, j in var c = j.casier ?? CasierJudiciaire();
    /// let g: Gravite = mois == 0 ? .contravention : (mois < 60 ? .delit : .crime);
    /// let l = CasierSysteme.condamner(&c, infraction: inf, gravite: g, age: j.age); j.casier = c; return l }`
    static var condamnation: ((String, Int, inout Joueur) -> String?)?

    static func signaler(_ nom: String, _ j: inout Joueur) {
        signal?(nom, &j)
    }

    // MARK: - Naissance

    static func naissance(_ j: inout Joueur) -> [String] {
        var v = VieEtat()
        v.generation = j.vieEtat.generation
        v.ancetres = j.vieEtat.ancetres
        j.vieEtat = v
        return VieRelations.naissance(&j)
    }

    // MARK: - +1 an

    static func vieillir(_ j: inout Joueur) -> [String] {
        var lignes: [String] = []
        lignes += VieCrime.vieillir(&j)
        lignes += VieRelations.vieillir(&j)
        lignes += VieSanteSysteme.vieillir(&j)
        lignes += VieEtapes.annoncer(&j)
        // Enfants qui deviennent majeurs : signal pour les répercussions.
        if j.enfantsVivants.contains(where: { $0.age == 18 }) { signaler("enfant_majeur", &j) }
        j.stats.borner()
        return lignes
    }

    static func causeDeces(_ j: Joueur) -> String? {
        VieSanteSysteme.causeDeces(j)
    }

    // MARK: - Tags et filtre des événements

    static func tags(_ j: Joueur) -> Set<String> {
        let v = j.vieEtat
        var t: Set<String> = []
        if v.justice.enPrison { t.insert("prison") }
        if !v.justice.casier.isEmpty { t.insert("record") }
        if !v.sante.maladies.isEmpty { t.insert("malade") } else { t.insert("bien_portant") }
        if !v.sante.addictions.isEmpty { t.insert("addiction") }
        if v.grossesse != nil { t.insert("pregnant") }
        if !j.exVivants.isEmpty { t.insert("ex") }
        if !j.parentsVivants.isEmpty { t.insert("parents") }
        if !v.grandsParents.isEmpty { t.insert("grandparents") }
        if !v.petitsEnfants.isEmpty { t.insert("grandchildren") }
        if j.partenaireActuel != nil {
            switch v.statutCouple {
            case .marie: t.insert("married")
            case .fiance: t.insert("engaged")
            case nil: t.insert("dating")
            }
        } else {
            t.insert("single")
        }
        return t
    }

    /// En prison, seuls les événements « prison » et « sante » arrivent.
    static func evenementAutorise(_ e: Evenement, tags: Set<String>) -> Bool {
        let cat = e.category ?? ""
        if tags.contains("prison") { return cat == "prison" || cat == "sante" }
        return cat != "prison"
    }

    // MARK: - Textes

    static func remplir(_ texte: String, _ j: Joueur) -> String {
        guard texte.contains("{") else { return texte }
        var t = texte
        t = t.replacingOccurrences(of: "{enfant}", with: choixStable(j.enfantsVivants, j.age)?.prenom ?? "ton gamin")
        t = t.replacingOccurrences(of: "{ex}", with: choixStable(j.exVivants, j.age)?.prenom ?? "ton ex")
        t = t.replacingOccurrences(of: "{codetenu}", with: j.vieEtat.codetenus.first?.prenom ?? ["Le Grand Momo", "Tonton Rasoir", "Kiki la Lime"].auHasard("Momo"))
        t = t.replacingOccurrences(of: "{grandparent}", with: choixStable(j.vieEtat.grandsParents, j.age)?.prenom ?? "Mamie")
        return t
    }

    // MARK: - Effets en plus

    static func apresIssue(evenementId: String, effets fx: VieEffets?, _ j: inout Joueur) -> [String] {
        guard let fx else { return [] }
        var lignes: [String] = []
        if let amende = fx.fine, amende > 0 {
            j.argent -= amende
            lignes.append("Amende de \(Format.argent(amende)).")
        }
        if fx.record == 1 || (fx.jailMonths ?? 0) > 0 && !j.vieEtat.justice.enPrison {
            if let l = condamnation?("délit divers", max(0, fx.jailMonths ?? 0), &j) { lignes.append(l) }
        }
        if fx.record == 1 {
            var v = j.vieEtat
            v.justice.casier.append(VieCasierLigne(age: j.age, crime: "Délit divers", mois: max(0, fx.jailMonths ?? 0)))
            j.vieEtat = v
        }
        if let m = fx.jailMonths, m != 0 {
            var v = j.vieEtat
            if v.justice.enPrison {
                v.justice.moisRestants = max(0, v.justice.moisRestants + m)
                j.vieEtat = v
                if v.justice.moisRestants == 0 {
                    lignes.append(VieCrime.liberer(&j))
                } else {
                    lignes.append(m < 0 ? "Ta peine est réduite de \(VieCrime.dureeTexte(-m))." : "Ta peine est rallongée de \(VieCrime.dureeTexte(m)).")
                }
            } else if m > 0 {
                if fx.record != 1 {
                    v.justice.casier.append(VieCasierLigne(age: j.age, crime: "Délit divers", mois: m))
                    j.vieEtat = v
                }
                lignes += VieCrime.emprisonner(m, &j)
            }
        }
        if let d = fx.disease { lignes += VieSanteSysteme.attraper(d, &j) }
        if fx.cure == true { lignes += VieSanteSysteme.guerirAuHasard(&j) }
        if let a = fx.addiction { lignes += VieSanteSysteme.ajouterAddiction(a, &j) }
        if fx.breakup == true { lignes += VieRelations.rompre(&j, parLeJoueur: false) }
        if fx.newPartner == true, j.partenaireActuel == nil, j.age >= 14 {
            if let p = VieRelations.profils(j, genre: nil, nombre: 1).first {
                j.relations.append(Relation(prenom: p.prenom, nom: p.nom, genre: p.genre, type: .partenaire, age: p.age, lien: 65))
                var v = j.vieEtat; v.statutCouple = nil; v.anneesEnsemble = 0; j.vieEtat = v
                lignes.append("Tu sors maintenant avec \(p.prenom) (\(p.age) ans, \(p.metier.lowercased())).")
                signaler("couple", &j)
            }
        }
        if fx.pregnancy == true, j.partenaireActuel != nil, j.age >= 16, j.age <= 50 {
            lignes += VieRelations.conception(&j)
        }
        if let cible = fx.targetDies {
            lignes += tuer(cible, &j)
        }
        return lignes
    }

    /// Fait mourir une personne de la catégorie donnée (partner, child, friend, parent, sibling, ex).
    static func tuer(_ cle: String, _ j: inout Joueur) -> [String] {
        let types: [TypeRelation]
        switch cle {
        case "partner": types = [.partenaire]
        case "child": types = [.enfant]
        case "friend": types = [.ami]
        case "parent": types = [.mere, .pere]
        case "mother": types = [.mere]
        case "father": types = [.pere]
        case "sibling": types = [.frere, .soeur]
        case "ex": types = [.ex]
        default: return []
        }
        guard let i = j.relations.indices.filter({ types.contains(j.relations[$0].type) && j.relations[$0].vivant }).randomElement() else { return [] }
        j.relations[i].vivant = false
        let r = j.relations[i]
        j.stats.bonheur -= r.type == .partenaire || r.type == .enfant ? 25 : 10
        j.stats.borner()
        if r.type == .partenaire {
            var v = j.vieEtat; v.statutCouple = nil; v.anneesEnsemble = 0; j.vieEtat = v
            signaler("veuvage", &j)
        } else {
            signaler("deces_proche", &j)
        }
        return ["💀 \(r.designation), \(r.prenom), est \(r.a("mort", "morte")) à \(r.age) ans."]
    }
}

/// Crochets du mode Shkurtaaa (triche). Valeur d'origine tant que le mode n'est pas branché.
enum VieBonus {
    static var seductionHook: ((Double) -> Double)?
    static var arrestationHook: ((Double) -> Double)?
    static var evasionHook: ((Double) -> Double)?
    static var guerisonHook: ((Double) -> Double)?
    static var santeHook: ((Int) -> Int)?
    static var peutMourirHook: (() -> Bool)?

    static func seduction(_ c: Double) -> Double { seductionHook?(c) ?? c }
    static func arrestation(_ c: Double) -> Double { arrestationHook?(c) ?? c }
    static func evasion(_ c: Double) -> Double { evasionHook?(c) ?? c }
    static func guerison(_ c: Double) -> Double { guerisonHook?(c) ?? c }
    /// Perte de santé annuelle due à une maladie (négative).
    static func sante(_ delta: Int) -> Int { santeHook?(delta) ?? delta }
    static func peutMourir() -> Bool { peutMourirHook?() ?? true }
}

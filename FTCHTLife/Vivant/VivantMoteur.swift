import Foundation

// Jeu vivant : signaux, jalons, anniversaires, projets et limite d'un moment « vivant » par an.
// Voir docs/VIVANT.md.

enum JeuVivant {
    /// Au plus ce nombre de cartes « vivantes » (suites rep_viv_ et anniversaires) par année.
    static let maxMomentsParAn = 1

    static let prefixeSuite = "rep_viv_"
    static let prefixeAnniversaire = "viv_anv_"
    static let prefixeProjet = "viv_prj_"
    static let prefixeBiens = "viv_bien_"

    static func estMoment(_ id: String) -> Bool {
        id.hasPrefix(prefixeSuite) || id.hasPrefix(prefixeAnniversaire)
    }

    // MARK: - Photo et signaux

    /// `phone` : tags du téléphone (PhoneEngine est sur le fil principal, le moteur les passe).
    static func photo(_ j: Joueur, phone: Set<String>) -> VivantPhoto {
        var p = VivantPhoto()
        p.argent = j.argent
        let biens = j.possessions ?? Possessions()
        p.objets = biens.items.map { $0.id.uuidString }
        if case .owned = biens.residence { p.proprietaire = true }
        if let m = j.politique?.mandat {
            p.mandat = m.poste.rawValue
            p.mandatNumero = m.numero
            p.gouverne = m.poste.gouverne
        }
        p.placements = PlacementsMoteur.patrimoine(j.placements ?? PlacementsEtat())
        p.paysActuel = j.etranger?.paysActuel
        p.condamnations = j.casier?.condamnations.count ?? 0
        p.casierEfface = CasierSysteme.tags(j.casier).contains("casier_efface")
        p.starTele = GameEngine.teleTags(j).contains("tv_star")
        p.starReseaux = phone.contains("star_reseaux")
        p.millionnaire = j.argent >= 1_000_000
        p.milliardaire = j.argent >= 1_000_000_000
        return p
    }

    /// Signaux à envoyer d'après ce qui a changé depuis la photo précédente.
    static func signaux(avant a: VivantPhoto, apres b: VivantPhoto, _ j: Joueur) -> [String] {
        var s: [String] = []
        func ajouter(_ x: String) { if !s.contains(x) { s.append(x) } }

        // Achats
        let anciens = Set(a.objets)
        let items = (j.possessions ?? Possessions()).items.filter { !anciens.contains($0.id.uuidString) }
        for item in items {
            guard let c = ShopCatalog.shared.item(item.catalogId) else { continue }
            switch c.category {
            case .car:
                ajouter("achat_voiture")
                if c.price >= 80_000 { ajouter("achat_voiture_luxe") }
            case .moto: ajouter("achat_moto")
            case .boat: ajouter("achat_bateau")
            case .aircraft: ajouter("achat_avion")
            case .realEstate: ajouter("achat_maison")
            case .jewelry, .watch: ajouter("achat_bijoux")
            default: break
            }
            if item.purchasePrice >= 50_000 { ajouter("gros_achat") }
        }
        if !a.proprietaire && b.proprietaire { ajouter("achat_maison") }

        // Politique (la soirée électorale est gérée par le module Politique)
        if b.mandat != nil && b.mandat != a.mandat { ajouter("election_gagnee") }
        else if b.mandat != nil && b.mandatNumero > a.mandatNumero { ajouter("reelection") }
        if a.mandat != nil && b.mandat == nil { ajouter("mandat_perdu") }
        if !a.gouverne && b.gouverne { ajouter("entree_gouvernement") }

        // Argent
        let compteurs = j.repercussions?.compteurs ?? [:]
        if b.millionnaire && !a.millionnaire && (compteurs["millionnaire"] ?? 0) == 0 { ajouter("millionnaire") }
        if b.milliardaire && !a.milliardaire && (compteurs["milliardaire"] ?? 0) == 0 { ajouter("milliardaire") }
        if a.argent >= 100_000 && b.argent < 0 { ajouter("ruine") }

        // Placements : on écarte les mouvements faits par le joueur (achat ou vente compensés par l'argent liquide).
        let delta = b.placements - a.placements
        let deltaArgent = b.argent - a.argent
        if a.placements >= 10_000, Double(b.placements) <= Double(a.placements) * 0.7, deltaArgent < -delta / 2 {
            ajouter("placements_krach")
        }
        if a.placements >= 5_000, Double(b.placements) >= Double(a.placements) * 1.5, deltaArgent > -delta / 2 {
            ajouter("placements_envolee")
        }

        // Étranger
        if let pays = b.paysActuel, let avant = a.paysActuel, pays != avant {
            ajouter(pays == j.etatExpat.paysNaissance ? "retour_pays" : "expatriation")
        }

        // Justice, célébrité
        if b.condamnations > a.condamnations { ajouter("condamnation") }
        if b.casierEfface && !a.casierEfface { ajouter("casier_efface") }
        if b.starTele && !a.starTele { ajouter("celebrite") }
        if b.starReseaux && !a.starReseaux { ajouter("star_reseaux") }
        return s
    }

    // MARK: - Jalons

    /// Signaux qui deviennent une date marquante. `true` = seulement la première fois.
    static let jalons: [String: (type: String, premierSeulement: Bool)] = [
        "mariage": ("mariage", false),
        "couple": ("rencontre_couple", false),
        "divorce": ("divorce", false),
        "veuvage": ("veuvage", false),
        "deces_parent": ("deces_parent", false),
        "bac_obtenu": ("bac_obtenu", true),
        "diplome": ("diplome", false),
        "embauche": ("premier_emploi", true),
        "retraite": ("retraite", true),
        "prison_sortie": ("prison_sortie", false),
        "evasion": ("prison_sortie", false),
        "entreprise_creee": ("entreprise_creee", false),
        "achat_maison": ("achat_maison", true),
        "naissance_enfant": ("naissance_enfant", false),
        "adoption": ("naissance_enfant", false),
        "election_gagnee": ("election_gagnee", true),
        "expatriation": ("expatriation", false),
        "permis_obtenu": ("permis_obtenu", true),
    ]

    /// Appelé pour chaque signal de module (SignauxModules.signaler).
    static func surSignal(_ signal: String, _ j: inout Joueur) {
        guard let def = jalons[signal] else { return }
        var etat = j.jeuVivant ?? JeuVivantEtat()
        if def.premierSeulement && etat.jalons.contains(where: { $0.type == def.type }) { return }
        if etat.jalons.contains(where: { $0.type == def.type && $0.age == j.age }) && def.type != "naissance_enfant" { return }
        etat.jalons.append(VivantJalon(type: def.type, age: j.age, nom: nomJalon(def.type, j, etat)))
        j.jeuVivant = etat
    }

    private static func nomJalon(_ type: String, _ j: Joueur, _ etat: JeuVivantEtat) -> String? {
        let dejaNommes = Set(etat.jalons.filter { $0.type == type }.compactMap(\.nom))
        switch type {
        case "mariage", "rencontre_couple": return j.partenaireActuel?.prenom
        case "divorce": return j.exVivants.last?.prenom
        case "veuvage": return j.relations.last { $0.type == .partenaire && !$0.vivant }?.prenom
        case "deces_parent":
            return j.relations.last { $0.type.estParent && !$0.vivant && !dejaNommes.contains($0.prenom) }?.prenom
        case "naissance_enfant":
            return j.relations.last { $0.type == .enfant && $0.vivant && !dejaNommes.contains($0.prenom) }?.prenom
                ?? j.relations.last { $0.type == .enfant }?.prenom
        case "premier_emploi": return j.emploi?.titre
        case "entreprise_creee": return j.entreprises?.actives.max { $0.ageCreation < $1.ageCreation }?.nom
        case "election_gagnee": return j.politique?.mandat?.poste.nom(j)
        case "expatriation":
            let id = j.etatExpat.paysActuel
            return ExpatCatalogue.shared.trouverPays(id)?.nom ?? id
        default: return nil
        }
    }

    // MARK: - Tags

    static func tags(_ j: Joueur, phone: Set<String>) -> Set<String> {
        var t: Set<String> = []
        if let c = j.carriere, let job = CareerCatalog.shared.career(c.careerId) {
            t.insert("secteur_\(job.sector)")
            t.insert("metier_\(job.id)")
        }
        if let m = j.politique?.mandat {
            if j.age - m.ageDebut <= 1 { t.insert("mandat_debut") }
            if j.age - m.ageDebut >= 3 { t.insert("mandat_installe") }
        }
        let etat = j.jeuVivant ?? JeuVivantEtat()
        for item in (j.possessions ?? Possessions()).items where item.yearsOwned >= 3 {
            guard let c = ShopCatalog.shared.item(item.catalogId) else { continue }
            let cle: String, tag: String
            switch c.category {
            case .boat: cle = "bateau"; tag = "bateau_oublie"
            case .aircraft: cle = "avion_prive"; tag = "avion_oublie"
            default: continue
            }
            if let derniere = etat.sorties[cle], j.age - derniere < 3 { continue }
            t.insert(tag)
        }
        let tele = GameEngine.teleTags(j)
        if j.politique?.mandat != nil || tele.contains("tv_star") || phone.contains("star_reseaux")
            || phone.contains("influencer") || EntrepriseMoteur.tags(j.entreprises).contains("magnat")
            || j.argent >= 1_000_000_000 {
            t.insert("notable")
        }
        if etat.projet != nil { t.insert("projet_en_cours") }
        return t
    }

    // MARK: - Anniversaires

    /// Anniversaire possible cette année (au plus un), déjà prêt à afficher, et la clé à noter comme vue.
    static func anniversaire(_ j: Joueur, conditionsOK: (Evenement) -> Bool) -> (evenement: Evenement, ligne: String?, cle: String)? {
        let etat = j.jeuVivant ?? JeuVivantEtat()
        var candidats: [(VivantAnniversaire, VivantJalon, Int)] = []
        for jalon in etat.jalons {
            let n = j.age - jalon.age
            guard n > 0 else { continue }
            // Les anniversaires de couple ne valent qu'avec la même personne.
            if jalon.type == "mariage" || jalon.type == "rencontre_couple" {
                guard let nom = jalon.nom, j.partenaireActuel?.prenom == nom else { continue }
            }
            for a in VivantBibliotheque.anniversaires where a.jalon == jalon.type && a.annees.contains(n) {
                if a.text.contains("{jalon_nom}") && jalon.nom == nil { continue }
                if etat.anniversairesVus.contains(cle(a, jalon)) { continue }
                candidats.append((a, jalon, n))
            }
        }
        typealias Candidat = (evenement: Evenement, ligne: String?, cle: String, annees: Int)
        let valides: [Candidat] = candidats.compactMap { c in
            let e = evenement(c.0, jalon: c.1, annees: c.2)
            guard conditionsOK(e) else { return nil }
            return (e, c.0.ligne.map { remplir($0, jalon: c.1, annees: c.2) }, cle(c.0, c.1), c.2)
        }
        // Les plus grands anniversaires d'abord (25 ans de mariage avant 1 an de permis), puis au hasard.
        guard let plusGrand = valides.map({ $0.annees }).max(),
              let choisi = valides.filter({ $0.annees == plusGrand }).randomElement() else { return nil }
        return (choisi.evenement, choisi.ligne, choisi.cle)
    }

    private static func cle(_ a: VivantAnniversaire, _ jalon: VivantJalon) -> String {
        "\(a.id)@\(jalon.type)@\(jalon.age)@\(jalon.nom ?? "")"
    }

    static func remplir(_ texte: String, jalon: VivantJalon, annees: Int) -> String {
        texte.replacingOccurrences(of: "{jalon_nom}", with: jalon.nom ?? "")
            .replacingOccurrences(of: "{annees}", with: "\(annees)")
    }

    private static func evenement(_ a: VivantAnniversaire, jalon: VivantJalon, annees: Int) -> Evenement {
        let r: (String) -> String = { remplir($0, jalon: jalon, annees: annees) }
        let choix = a.choices?.map { c in
            Choix(label: r(c.label), outcomes: c.outcomes.map { Issue(chance: $0.chance, text: r($0.text), effects: $0.effects) },
                  requiresSkill: c.requiresSkill)
        }
        return Evenement(id: a.id, category: "vivant", minAge: 0, maxAge: 200, weight: 1, unique: nil,
                         conditions: a.conditions, text: r(a.text), effects: a.effects, choices: choix)
    }

    // MARK: - Projets

    /// Projets que le joueur peut lancer maintenant.
    static func projetsDisponibles(_ j: Joueur, conditionsOK: (Evenement) -> Bool) -> [VivantProjet] {
        VivantBibliotheque.projets.filter { p in
            j.age >= (p.minAge ?? 12) && j.age <= (p.maxAge ?? 120)
                && conditionsOK(Evenement(id: "viv_prj_test", category: "vivant", minAge: 0, maxAge: 200, weight: 1,
                                          unique: nil, conditions: p.conditions, text: "", effects: nil, choices: nil))
        }
    }

    /// Carte de l'étape en cours du projet. L'id garde la correspondance entre les choix affichés et ceux des données :
    /// `viv_prj_<étape>_<index des choix séparés par des points>`.
    static func carteEtape(_ p: VivantProjet, etape: Int, _ j: Joueur, tags: Set<String>) -> Evenement? {
        guard p.etapes.indices.contains(etape) else { return nil }
        let e = p.etapes[etape]
        let visibles = e.choices.indices.filter { i in
            let c = e.choices[i]
            return Set(c.requiresTags ?? []).isSubset(of: tags) && Competences.aLeNiveau(c.requiresSkill, j)
        }
        guard !visibles.isEmpty else { return nil }
        let r: (String) -> String = { $0.replacingOccurrences(of: "{projet}", with: p.nom.lowercased()) }
        let choix = visibles.map { i -> Choix in
            let c = e.choices[i]
            return Choix(label: r(c.label), outcomes: c.outcomes.map { Issue(chance: $0.chance, text: r($0.text), effects: $0.effects) },
                         requiresSkill: nil)
        }
        let id = prefixeProjet + "\(etape)_" + visibles.map(String.init).joined(separator: ".")
        let titre = (p.emoji.map { $0 + " " } ?? "") + p.nom + " (\(etape + 1)/\(p.etapes.count)). "
        return Evenement(id: id, category: "vivant", minAge: 0, maxAge: 200, weight: 1, unique: nil,
                         conditions: nil, text: titre + r(e.text), effects: nil, choices: choix)
    }

    /// Lit l'id d'une carte d'étape : (étape, index des choix des données).
    static func lireCarte(_ id: String) -> (etape: Int, choix: [Int])? {
        guard id.hasPrefix(prefixeProjet) else { return nil }
        let morceaux = id.dropFirst(prefixeProjet.count).split(separator: "_")
        guard morceaux.count == 2, let etape = Int(morceaux[0]) else { return nil }
        return (etape, morceaux[1].split(separator: ".").compactMap { Int($0) })
    }

    /// Fin d'un projet d'après les progrès : "reussite", "moyen" ou "echec".
    static func fin(_ p: VivantProjet, progres: Int) -> String {
        let n = Double(p.etapes.count)
        if Double(progres) >= 1.5 * n { return "reussite" }
        if Double(progres) >= 0.75 * n { return "moyen" }
        return "echec"
    }
}

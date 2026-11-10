import Foundation

/// Logique du module « Testament et guerre d'héritage ». Voir docs/SUCCESSION.md.
enum Successions {

    // MARK: - Données

    static let episodes: [SuccessionEpisode] = DonneesJSON.chargerTableaux(dossier: "Succession/Episodes", type: SuccessionEpisode.self)
    static let clauses: [SuccessionClause] = DonneesJSON.chargerTableaux(dossier: "Succession/Clauses", type: SuccessionClause.self)
    static let oeuvres: [SuccessionOeuvre] = DonneesJSON.chargerTableaux(dossier: "Succession/Oeuvres", type: SuccessionOeuvre.self)
    static let chroniquesData: [SuccessionChronique] = DonneesJSON.chargerTableaux(dossier: "Succession/Chroniques", type: SuccessionChronique.self)

    static func clause(_ id: String) -> SuccessionClause? { clauses.first { $0.id == id } }
    static func oeuvre(_ id: String?) -> SuccessionOeuvre? { oeuvres.first { $0.id == id } }

    static let nomsChats = [
        "Moustache", "Pacha", "Croquette", "Monsieur Pantoufle", "Biscotte", "Ronron", "Gros Loulou",
        "Princesse Tartiflette", "Napoléon", "Mimine", "Kebab", "Duchesse", "Brioche", "Zorro", "Tigrou-Bernard",
    ]

    static let notaires = [
        "Maître Duchemin", "Maître Lacrampe", "Maître Ventremou", "Maître Grosjean-Pinson", "Maître Coffrefort",
        "Maître Plumeau", "Maître Bordereau", "Maître Tamponnet", "Maître Paraphe", "Maître Sansouci",
    ]

    /// Prétendants inventés : rôle et genre.
    static let rolesInventes: [(String, Genre)] = [
        ("cousin", .homme), ("cousine", .femme), ("oncle", .homme), ("tante", .femme),
        ("demi-frère", .homme), ("demi-sœur", .femme), ("parrain", .homme), ("marraine", .femme),
        ("grand-oncle", .homme), ("petite-cousine", .femme), ("beau-frère", .homme), ("belle-sœur", .femme),
    ]

    static let oeuvresSecours = ["l'Amicale des pigeons sans domicile", "la Fondation pour les chaussettes orphelines"]

    /// Tirage pondéré (copie de `GameEngine.tirage`, qui est isolé sur le MainActor).
    static func tirer<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0.0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.first }
        var r = Double.random(in: 0..<total)
        for element in liste {
            r -= max(0, poids(element))
            if r < 0 { return element }
        }
        return liste.last
    }

    // MARK: - Tags

    /// Tags à ajouter à `GameEngine.tags(_:)` pour les événements classiques.
    static func tags(_ etat: SuccessionEtat?) -> Set<String> {
        guard let etat else { return [] }
        var t: Set<String> = []
        if let tes = etat.testament {
            t.insert("testament")
            t.insert("testament_\(tes.beneficiaire.rawValue)")
            t.insert(tes.secret ? "testament_secret" : "testament_annonce")
        }
        if !etat.dossiers.isEmpty { t.insert("heritier") }
        if etat.dossiers.contains(where: { $0.ouvert }) { t.insert("heritier_en_guerre") }
        if etat.dossiers.contains(where: { $0.role == .desherite }) { t.insert("desherite") }
        if etat.dossiers.reduce(0, { $0 + max(0, $1.bilan) }) >= 100_000 { t.insert("a_herite_gros") }
        return t
    }

    // MARK: - Rédiger son testament

    /// Résumé lisible d'un testament.
    static func description(_ t: SuccessionTestament) -> String {
        let qui: String
        switch t.beneficiaire {
        case .egal: qui = "Partage égal entre tes enfants et ton partenaire."
        case .enfant: qui = "Tout à \(t.beneficiairePrenom ?? "ton enfant préféré"). Les autres apprécieront."
        case .partenaire: qui = "Tout à \(t.beneficiairePrenom ?? "l'amour de ta vie")."
        case .chat: qui = "Tout au chat. Le chat ne dit pas merci."
        case .oeuvre: qui = "Tout à \(oeuvre(t.oeuvreId)?.nom ?? oeuvresSecours[0])."
        case .personne: qui = "Rien à personne. Tu as demandé qu'on brûle les billets dans le jardin."
        case .inconnu: qui = "Tout au premier inconnu qui viendra à ton enterrement."
        case .ami: qui = "Tout à ton ami \(t.beneficiairePrenom ?? "de toujours")."
        case .aucun: qui = "Pas de testament : la loi (et les avocats) décideront."
        }
        return qui + " " + t.support.titre + "."
    }

    /// Coût et réactions d'un nouveau testament (pour l'aperçu et l'enregistrement).
    static func redaction(nouveau t: SuccessionTestament, ancien: SuccessionTestament?, joueur j: Joueur) -> SuccessionRedaction {
        var r = SuccessionRedaction(cout: t.support.cout, liens: [:], bonheur: 2, karma: 0, lignes: [])
        let enfants = j.relations.filter { $0.type == .enfant && $0.vivant }
        let partenaire = j.relations.first { $0.type == .partenaire && $0.vivant }
        let versions = (ancien?.versions ?? 0) + 1

        r.lignes.append("✍️ Tu as rédigé ton testament (\(t.support.titre.lowercased())). " + description(t))
        if t.support == .tatouage { r.lignes.append("Le tatoueur a demandé trois fois si tu étais sûr\(j.genre == .femme ? "e" : "") pour « rien à ma belle-mère ».") }
        if versions == 3 { r.lignes.append("C'est ta troisième version. Ton notaire commence à te tutoyer.") }
        if versions >= 5 { r.lignes.append("Version n°\(versions). Ta famille a créé un groupe pour suivre les mises à jour.") }

        guard !t.secret else {
            r.lignes.append("Tu le gardes secret. Tu souris beaucoup au repas de famille, ça inquiète tout le monde.")
            return r
        }

        // Annoncé à la famille : chacun réagit.
        for e in enfants {
            var d = 0
            switch t.beneficiaire {
            case .egal: d = 3
            case .enfant: d = e.id == t.beneficiaireId ? 15 : -15
            case .partenaire: d = -6
            case .chat, .personne, .inconnu: d = -12
            case .oeuvre, .ami: d = -10
            case .aucun: d = 0
            }
            if d != 0 { r.liens[e.id, default: 0] += d }
        }
        if let p = partenaire {
            switch t.beneficiaire {
            case .partenaire: r.liens[p.id, default: 0] += 12
            case .egal, .aucun: break
            default: r.liens[p.id, default: 0] -= 10
            }
        }
        if t.beneficiaire == .ami, let id = t.beneficiaireId { r.liens[id, default: 0] += 20 }

        switch t.beneficiaire {
        case .enfant:
            r.lignes.append("Tu l'annonces au repas du dimanche. \(t.beneficiairePrenom ?? "Ton enfant préféré") reprend du gratin. Les autres posent leur fourchette.")
        case .chat:
            r.lignes.append("Tu l'annonces à la famille. Le chat cligne lentement des yeux. Tes enfants ne clignent plus du tout.")
            r.bonheur += 4
        case .personne:
            r.lignes.append("Tu annonces que personne n'aura rien. Silence total, puis quelqu'un demande si le canapé compte.")
            r.karma -= 3
        case .oeuvre:
            r.lignes.append("Tu annonces que tout ira à une œuvre. Ta famille découvre soudain une passion pour la charité, la tienne.")
            r.karma += 5
        case .inconnu:
            r.lignes.append("Tu annonces que tout ira au premier inconnu de ton enterrement. Des gens commencent à te suivre dans la rue.")
        case .egal:
            r.lignes.append("Partage égal. Tout le monde est déçu de la même façon, c'est ça la justice.")
        default:
            r.lignes.append("Tu l'annonces à la famille. L'ambiance du repas passe de « tiède » à « Guerre froide ».")
        }
        for id in t.clauses {
            if let c = clause(id), let reac = c.reaction, Bool.random() { r.lignes.append(reac) }
        }
        return r
    }

    /// Enregistre le testament : paie, applique les réactions et renvoie les lignes du journal.
    @discardableResult
    static func enregistrer(_ t: SuccessionTestament, joueur j: inout Joueur, etat: inout SuccessionEtat) -> [String] {
        var t = t
        t.versions = (etat.testament?.versions ?? 0) + 1
        t.redigeA = j.age
        let r = redaction(nouveau: t, ancien: etat.testament, joueur: j)
        j.argent -= r.cout
        j.stats.bonheur += r.bonheur
        j.stats.karma += r.karma
        j.stats.borner()
        for i in j.relations.indices {
            if let d = r.liens[j.relations[i].id] { j.relations[i].lien = Stats.borne(j.relations[i].lien + d) }
        }
        etat.testament = t
        return r.lignes
    }

    /// Déchire le testament.
    static func dechirer(etat: inout SuccessionEtat) -> String {
        etat.testament = nil
        return "Tu as déchiré ton testament. Tu as dû le recoller pour vérifier que c'était le bon, puis le redéchirer."
    }

    // MARK: - Tension

    static func tension(testament t: SuccessionTestament, coheritiers: Int, patrimoine: Int, karmaDefunt: Int) -> Int {
        var v = t.beneficiaire.drame
        v += (100 - t.support.solidite) / 4
        v += t.clauses.compactMap { clause($0)?.drame }.reduce(0, +) * 4
        v += min(coheritiers, 4) * 6
        if patrimoine > 1_000_000 { v += 15 } else if patrimoine > 100_000 { v += 8 }
        if patrimoine < 0 { v += 5 }
        v += (50 - karmaDefunt) / 5
        v += min(12, max(0, t.versions - 1) * 3)
        v += Int.random(in: -5...10)
        return Stats.borne(v)
    }

    // MARK: - Ouverture d'une succession

    static func bienPour(patrimoine: Int, prenomDefunt: String) -> String {
        switch patrimoine {
        case ..<0: return "le canapé saisi et la vieille Twingo"
        case ..<20_000: return "le garage plein de bazar de \(prenomDefunt)"
        case ..<150_000: return "l'appartement de \(prenomDefunt)"
        case ..<1_000_000: return "la maison de famille"
        default: return "la villa avec piscine de \(prenomDefunt)"
        }
    }

    static func inventerRival(hostilite: Int) -> SuccessionRival {
        let (role, genre) = rolesInventes.randomElement()!
        return SuccessionRival(prenom: Donnees.prenom(genre), genre: genre, role: role, hostilite: hostilite)
    }

    /// Testament tiré au hasard pour un parent PNJ.
    static func testamentPNJ(defunt: Relation, heritiers: [Relation], partenaire: Bool) -> SuccessionTestament {
        let choix: [(SuccessionBeneficiaire, Double)] = [
            (.aucun, 30), (.egal, 30), (.enfant, heritiers.count > 1 ? 14 : 4), (.partenaire, partenaire ? 8 : 3),
            (.chat, 6), (.oeuvre, 4), (.inconnu, 3), (.personne, 3), (.ami, 2),
        ]
        let b = tirer(choix) { $0.1 }?.0 ?? .aucun
        let supports: [(SuccessionSupport, Double)] = [(.notaire, 40), (.papier, 30), (.serviette, 10), (.video, 10), (.tatouage, 3)]
        let support = b == .aucun ? SuccessionSupport.aucun : (tirer(supports) { $0.1 }?.0 ?? .papier)
        var t = SuccessionTestament(beneficiaire: b, support: support, secret: true, redigeA: max(18, defunt.age - Int.random(in: 1...20)))
        if b == .enfant, let e = heritiers.randomElement() {
            t.beneficiaireId = e.id
            t.beneficiairePrenom = e.prenom
        }
        if b == .oeuvre { t.oeuvreId = oeuvres.randomElement()?.id }
        if b != .aucun, !clauses.isEmpty {
            t.clauses = Array(clauses.shuffled().prefix([0, 0, 1, 1, 2].randomElement()!)).map(\.id)
        }
        t.versions = [1, 1, 1, 2, 3, 6].randomElement()!
        return t
    }

    /// Un parent du joueur meurt : ouvre un dossier et programme l'ouverture (cette année, ou aux 18 ans du joueur).
    /// - Parameter joueur: le joueur, avec son âge de l'année en cours.
    static func ouvrirPourParent(defunt r: Relation, joueur j: Joueur, autreParentVivant: Bool, etat: inout SuccessionEtat) {
        let fratrie = j.relations.filter { ($0.type == .frere || $0.type == .soeur) && $0.vivant }
        let moiRelation = Relation(prenom: j.prenom, nom: j.nom, genre: j.genre, type: .enfant, age: j.age, lien: 100)
        let heritiers = [moiRelation] + fratrie
        var t = testamentPNJ(defunt: r, heritiers: heritiers, partenaire: autreParentVivant)
        // L'id du joueur n'existe pas en tant que relation : on le remplace par un marqueur.
        let moi = UUID()
        if t.beneficiaireId == moiRelation.id { t.beneficiaireId = moi }

        var patrimoine = max(0, r.argent)
        if Double.random(in: 0...1) < 0.08 { patrimoine = -Int.random(in: 5...60) * 1000 }
        let karma = Int.random(in: 20...80)
        let tension = Self.tension(testament: t, coheritiers: fratrie.count, patrimoine: patrimoine, karmaDefunt: karma)

        let enfants = [SuccessionProche(prenom: j.prenom, genre: j.genre, id: moi)]
            + fratrie.map { SuccessionProche(prenom: $0.prenom, genre: $0.genre, id: $0.id) }
        var partenaireProche: SuccessionProche?
        if t.beneficiaire == .partenaire {
            if autreParentVivant, let p = j.relations.first(where: { $0.type.estParent && $0.id != r.id && $0.vivant }) {
                partenaireProche = SuccessionProche(prenom: p.prenom, genre: p.genre, id: p.id)
            } else {
                let g: Genre = r.genre == .femme ? .homme : .femme
                partenaireProche = SuccessionProche(prenom: Donnees.prenom(g), genre: g, id: nil)
            }
        }

        var lecture = construireLecture(defuntPrenom: r.prenom, defuntNom: r.nom, defuntGenre: r.genre, age: r.age,
                                        karma: karma, patrimoine: patrimoine, biens: [], testament: t,
                                        enfants: enfants, partenaire: partenaireProche, freresSoeurs: [], tension: tension)
        if t.beneficiaire == .partenaire, partenaireProche?.id == nil, let p = partenaireProche {
            // Une nouvelle conquête que personne ne connaissait.
            let libre = (p.genre == .femme ? "la nouvelle compagne de " : "le nouveau compagnon de ")
                + (r.genre == .femme ? "ta mère" : "ton père") + ", \(p.prenom)"
            lecture.cousin = SuccessionRival(prenom: p.prenom, genre: p.genre, role: p.genre == .femme ? "belle-mère" : "beau-père",
                                             hostilite: 60, libre: libre)
        }
        let dossier = construireDossier(lecture: lecture, heritier: enfants[0], coheritiers: Array(enfants.dropFirst()),
                                        lien: r.genre == .femme ? "mere" : "pere")
        ajouter(dossier, ageHeritier: j.age, etat: &etat)
    }

    /// Le joueur meurt : ce que lit le notaire. À calculer une seule fois et à garder.
    static func ouvrirPourJoueur(defunt j: Joueur, testament: SuccessionTestament?, biens: [SuccessionBien] = []) -> SuccessionLecture {
        let t = testament ?? SuccessionTestament(beneficiaire: .aucun, support: .aucun, redigeA: j.age)
        let enfants = j.relations.filter { $0.type == .enfant && $0.vivant }
            .map { SuccessionProche(prenom: $0.prenom, genre: $0.genre, id: $0.id) }
        let partenaire = j.relations.first { $0.type == .partenaire && $0.vivant }
            .map { SuccessionProche(prenom: $0.prenom, genre: $0.genre, id: $0.id) }
        let freres = j.relations.filter { ($0.type == .frere || $0.type == .soeur) && $0.vivant }
            .map { SuccessionProche(prenom: $0.prenom, genre: $0.genre, id: $0.id) }
        let patrimoine = j.argent + biens.reduce(0) { $0 + $1.valeur }
        let tension = Self.tension(testament: t, coheritiers: max(0, enfants.count - 1), patrimoine: patrimoine, karmaDefunt: j.stats.karma)
        var lecture = construireLecture(defuntPrenom: j.prenom, defuntNom: j.nom, defuntGenre: j.genre, age: j.age,
                                        karma: j.stats.karma, patrimoine: patrimoine, biens: biens, testament: t,
                                        enfants: enfants, partenaire: partenaire, freresSoeurs: freres, tension: tension)
        if t.beneficiaire == .ami, let id = t.beneficiaireId, let ami = j.relations.first(where: { $0.id == id }) {
            lecture.beneficiaireNom = ami.prenom
        }
        return lecture
    }

    static func construireLecture(defuntPrenom: String, defuntNom: String, defuntGenre: Genre, age: Int, karma: Int,
                                  patrimoine: Int, biens: [SuccessionBien], testament t: SuccessionTestament,
                                  enfants: [SuccessionProche], partenaire: SuccessionProche?, freresSoeurs: [SuccessionProche],
                                  tension: Int) -> SuccessionLecture {
        let chat = nomsChats.randomElement()!
        let nomOeuvre = oeuvre(t.oeuvreId)?.nom ?? oeuvres.randomElement()?.nom ?? oeuvresSecours.randomElement()!
        let inconnu = "un certain " + Donnees.prenom(.homme)
        let total = max(0, patrimoine)
        var parts: [SuccessionPart] = []

        func libelle(_ p: SuccessionProche, _ lien: String) -> String { "\(p.prenom) (\(lien))" }
        let libEnfant: (SuccessionProche) -> String = { libelle($0, $0.genre == .femme ? "fille" : "fils") }

        var beneficiaireNom = "toute la famille"
        switch t.beneficiaire {
        case .egal, .aucun:
            var ayants: [(String, UUID?)] = enfants.map { (libEnfant($0), $0.id) }
            if let p = partenaire {
                if t.beneficiaire == .aucun && !ayants.isEmpty {
                    let quart = total / 4
                    parts.append(SuccessionPart(libelle: libelle(p, "partenaire"), relationId: p.id, montant: quart))
                    let reste = total - quart
                    for a in ayants { parts.append(SuccessionPart(libelle: a.0, relationId: a.1, montant: reste / ayants.count)) }
                    ayants = []
                } else {
                    ayants.append((libelle(p, "partenaire"), p.id))
                }
            }
            if ayants.isEmpty && parts.isEmpty {
                ayants = freresSoeurs.map { (libelle($0, $0.genre == .femme ? "sœur" : "frère"), $0.id) }
            }
            if ayants.isEmpty && parts.isEmpty {
                parts.append(SuccessionPart(libelle: "l'État, qui te remercie sans émotion", relationId: nil, montant: total))
                beneficiaireNom = "l'État"
            }
            for a in ayants { parts.append(SuccessionPart(libelle: a.0, relationId: a.1, montant: total / ayants.count)) }
        case .enfant:
            let e = enfants.first { $0.id == t.beneficiaireId }
            let nom = e.map(libEnfant) ?? (t.beneficiairePrenom ?? "ton enfant préféré")
            parts.append(SuccessionPart(libelle: nom, relationId: t.beneficiaireId, montant: total))
            beneficiaireNom = e?.prenom ?? t.beneficiairePrenom ?? "ton enfant préféré"
        case .partenaire:
            let nom = partenaire?.prenom ?? t.beneficiairePrenom ?? "l'amour de sa vie"
            parts.append(SuccessionPart(libelle: nom, relationId: partenaire?.id, montant: total))
            beneficiaireNom = nom
        case .chat:
            parts.append(SuccessionPart(libelle: "le chat \(chat)", relationId: nil, montant: total))
            beneficiaireNom = "le chat \(chat)"
        case .oeuvre:
            parts.append(SuccessionPart(libelle: nomOeuvre, relationId: nil, montant: total))
            beneficiaireNom = nomOeuvre
        case .personne:
            parts.append(SuccessionPart(libelle: "personne (tout brûlé dans le jardin)", relationId: nil, montant: 0))
            beneficiaireNom = "personne"
        case .inconnu:
            parts.append(SuccessionPart(libelle: inconnu + ", vu une fois à l'enterrement", relationId: nil, montant: total))
            beneficiaireNom = inconnu
        case .ami:
            let nom = t.beneficiairePrenom ?? "un vieil ami"
            parts.append(SuccessionPart(libelle: nom + " (ami)", relationId: t.beneficiaireId, montant: total))
            beneficiaireNom = nom
        }

        return SuccessionLecture(
            defuntPrenom: defuntPrenom, defuntNom: defuntNom, defuntGenre: defuntGenre, ageDeces: age, karma: karma,
            patrimoine: patrimoine, bien: biens.max(by: { $0.valeur < $1.valeur })?.nom ?? bienPour(patrimoine: patrimoine, prenomDefunt: defuntPrenom),
            testament: t, enfants: enfants, partenaire: partenaire, parts: parts, tension: tension,
            cousin: inventerRival(hostilite: min(100, 30 + tension / 2)), chat: chat,
            notaire: notaires.randomElement()!, oeuvre: nomOeuvre, beneficiaireNom: beneficiaireNom)
    }

    /// Le dossier vu par un héritier (un enfant du défunt).
    static func construireDossier(lecture l: SuccessionLecture, heritier: SuccessionProche,
                                  coheritiers: [SuccessionProche], lien: String) -> SuccessionDossier {
        let t = l.testament
        var part = 0
        if l.patrimoine >= 0 {
            if let p = l.parts.first(where: { $0.relationId != nil && $0.relationId == heritier.id }) {
                part = p.montant
            } else if t.beneficiaire == .egal || t.beneficiaire == .aucun,
                      let p = l.parts.first(where: { $0.libelle.hasPrefix(heritier.prenom + " (") }) {
                part = p.montant
            }
        }
        let role: SuccessionRole
        switch t.beneficiaire {
        case .egal, .aucun:
            role = coheritiers.isEmpty ? .seul : .egal
        case .enfant:
            if t.beneficiaireId == heritier.id || (t.beneficiaireId == nil && t.beneficiairePrenom == heritier.prenom) {
                role = coheritiers.isEmpty ? .seul : .favori
            } else {
                role = .desherite
            }
        default:
            role = .desherite
        }

        var rivaux: [SuccessionRival] = []
        for c in coheritiers {
            var h: Int
            switch role {
            case .favori: h = Int.random(in: 50...85)
            case .egal: h = Int.random(in: 10...45)
            case .desherite: h = (t.beneficiaire == .enfant && c.id == t.beneficiaireId) ? Int.random(in: 55...80) : Int.random(in: 5...30)
            case .seul: h = 10
            }
            h = Stats.borne(h + l.tension / 5)
            rivaux.append(SuccessionRival(prenom: c.prenom, genre: c.genre, role: c.genre == .femme ? "sœur" : "frère",
                                          hostilite: h, relationId: c.id))
        }
        rivaux.append(l.cousin)
        if l.tension >= 60 { rivaux.append(inventerRival(hostilite: Int.random(in: 30...70))) }

        let benefNom: String
        if t.beneficiaire == .enfant && role != .desherite {
            benefNom = "toi"
        } else {
            benefNom = l.beneficiaireNom
        }

        return SuccessionDossier(
            defuntPrenom: l.defuntPrenom, defuntNom: l.defuntNom, defuntGenre: l.defuntGenre, lien: lien,
            ageDeces: l.ageDeces, patrimoine: l.patrimoine, bien: l.bien, testament: t, role: role, part: part,
            tension: l.tension, rivaux: rivaux, coheritiers: coheritiers.map(\.prenom), chat: l.chat,
            notaire: l.notaire, oeuvre: l.oeuvre, beneficiaireNom: benefNom)
    }

    /// Ajoute un dossier et programme l'ouverture puis les épisodes de guerre.
    static func ajouter(_ dossier: SuccessionDossier, ageHeritier: Int, etat: inout SuccessionEtat) {
        etat.dossiers.append(dossier)
        var age = max(ageHeritier, 18)
        etat.programme.append(SuccessionProgramme(dossierId: dossier.id, age: age, phase: "ouverture"))
        let n: Int
        switch dossier.tension {
        case ..<25: n = 1
        case ..<50: n = 2
        case ..<75: n = 3
        default: n = 4
        }
        for k in 0..<n {
            age += k == 0 ? Int.random(in: 1...2) : Int.random(in: 1...3)
            etat.programme.append(SuccessionProgramme(dossierId: dossier.id, age: age, phase: "guerre"))
        }
    }

    /// Générations : l'enfant `heritier` reprend la partie. Son état de départ, avec le dossier à jouer.
    static func etatPourHeritier(lecture l: SuccessionLecture, heritier: Relation, ageHeritier: Int? = nil) -> SuccessionEtat {
        let moi = SuccessionProche(prenom: heritier.prenom, genre: heritier.genre, id: heritier.id)
        let autres = l.enfants.filter { $0.id != heritier.id }
        let dossier = construireDossier(lecture: l, heritier: moi, coheritiers: autres,
                                        lien: l.defuntGenre == .femme ? "mere" : "pere")
        var etat = SuccessionEtat()
        ajouter(dossier, ageHeritier: ageHeritier ?? heritier.age, etat: &etat)
        return etat
    }

    // MARK: - Épisodes de l'année

    /// Épisodes dus cette année, prêts à passer dans `declencher` (textes et montants calculés).
    static func episodesDeLAnnee(joueur j: Joueur, etat: inout SuccessionEtat) -> [Evenement] {
        let dus = etat.programme.filter { $0.age <= j.age }
        guard !dus.isEmpty else { return [] }
        etat.programme.removeAll { $0.age <= j.age }
        var resultat: [Evenement] = []

        for p in dus.sorted(by: { ($0.phase == "ouverture" ? 0 : 1, $0.age) < ($1.phase == "ouverture" ? 0 : 1, $1.age) }) {
            guard let di = etat.dossiers.firstIndex(where: { $0.id == p.dossierId }), etat.dossiers[di].ouvert else { continue }
            let d = etat.dossiers[di]
            var ep: SuccessionEpisode?
            if let id = p.episodeId {
                ep = episodes.first { $0.id == id }
            } else {
                let pool = episodes.filter {
                    $0.phase == p.phase && !d.vus.contains($0.id) && !($0.unique == true && etat.vus.contains($0.id))
                        && !etat.enCours.keys.contains($0.id) && conditionsOK($0.conditions, d, j)
                }
                ep = tirer(pool) { $0.weight ?? 1 }
            }
            if ep == nil && p.phase == "ouverture" { ep = ouvertureDeSecours(d) }
            guard let e = ep else { continue }

            etat.dossiers[di].vus.append(e.id)
            if e.unique == true { etat.vus.append(e.id) }
            let bonus = p.phase == "ouverture" ? d.part : 0
            if bonus != 0 {
                etat.dossiers[di].bilan += bonus
                etat.dossiers[di].historique.append("\(j.age) ans : ouverture du testament, tu touches \(Format.argent(bonus)).")
            } else if p.phase == "ouverture" {
                etat.dossiers[di].historique.append("\(j.age) ans : ouverture du testament, tu ne touches rien.")
            }

            let texte = remplir(e.text, etat.dossiers[di])
            if let choix = e.choices, !choix.isEmpty {
                etat.enCours[e.id] = d.id
                let c: [Choix] = choix.map { (ch: SuccessionChoix) -> Choix in
                    Choix(label: remplir(ch.label, etat.dossiers[di])
                        .replacingOccurrences(of: "{e}", with: j.genre == .femme ? "e" : "")
                        .replacingOccurrences(of: "{prenom}", with: j.prenom), outcomes: ch.outcomes.map { (o: SuccessionIssue) -> Issue in
                        Issue(chance: o.chance, text: remplir(o.text, etat.dossiers[di]),
                              effects: effets(o.effects, etat.dossiers[di], bonus: bonus))
                    })
                }
                resultat.append(Evenement(id: e.id, category: "succession", minAge: 0, maxAge: 200, weight: nil,
                                          unique: nil, conditions: nil, text: texte, effects: nil, choices: c))
            } else {
                resultat.append(Evenement(id: e.id, category: "succession", minAge: 0, maxAge: 200, weight: nil,
                                          unique: nil, conditions: nil, text: texte,
                                          effects: effets(e.effects, etat.dossiers[di], bonus: bonus), choices: nil))
                suivre(dossierIndex: di, effets: e.effects, next: e.next, delay: e.delay, setFlags: e.setFlags,
                       clearFlags: nil, close: e.close, resume: texte, age: j.age, etat: &etat)
            }
        }
        return resultat
    }

    /// Après un choix dans un épisode `suc_…` : hostilité, drapeaux, suites et historique.
    static func apresChoix(evenementId: String, choix: Int, issue: Int, joueur j: Joueur, etat: inout SuccessionEtat) {
        guard let dossierId = etat.enCours.removeValue(forKey: evenementId),
              let di = etat.dossiers.firstIndex(where: { $0.id == dossierId }),
              let e = episodes.first(where: { $0.id == evenementId }) ?? (evenementId == idSecours ? ouvertureDeSecours(etat.dossiers[di]) : nil),
              let ch = e.choices, ch.indices.contains(choix), ch[choix].outcomes.indices.contains(issue) else {
            fermerSiFini(etat: &etat)
            return
        }
        let o = ch[choix].outcomes[issue]
        let resume = remplir(ch[choix].label, etat.dossiers[di]) + " : " + remplir(o.text, etat.dossiers[di])
        suivre(dossierIndex: di, effets: o.effects, next: o.next, delay: o.delay, setFlags: o.setFlags,
               clearFlags: o.clearFlags, close: o.close, resume: resume, age: j.age, etat: &etat)
    }

    private static func suivre(dossierIndex di: Int, effets eff: SuccessionEffets?, next: [String]?, delay: [Int]?,
                               setFlags: [String]?, clearFlags: [String]?, close: Bool?, resume: String, age: Int,
                               etat: inout SuccessionEtat) {
        var d = etat.dossiers[di]
        d.historique.append("\(age) ans : \(resume)")
        if let eff {
            d.bilan += montant(eff, d)
            if let r = eff.rival, let k = d.rivaux.indices.max(by: { d.rivaux[$0].hostilite < d.rivaux[$1].hostilite }) {
                d.rivaux[k].hostilite = Stats.borne(d.rivaux[k].hostilite + r)
            }
        }
        for f in setFlags ?? [] where !d.flags.contains(f) { d.flags.append(f) }
        d.flags.removeAll { (clearFlags ?? []).contains($0) }
        if close == true {
            d.ouvert = false
            etat.programme.removeAll { $0.dossierId == d.id }
        } else if let next, !next.isEmpty {
            let mini = delay?.first ?? 1
            let maxi = max(mini, delay?.last ?? 2)
            for id in next {
                etat.programme.append(SuccessionProgramme(dossierId: d.id, age: age + Int.random(in: mini...maxi), phase: "suite", episodeId: id))
            }
        }
        etat.dossiers[di] = d
        fermerSiFini(etat: &etat)
    }

    /// Ferme les dossiers qui n'ont plus rien de prévu.
    static func fermerSiFini(etat: inout SuccessionEtat) {
        for i in etat.dossiers.indices where etat.dossiers[i].ouvert {
            let id = etat.dossiers[i].id
            if !etat.programme.contains(where: { $0.dossierId == id }) && !etat.enCours.values.contains(id) {
                etat.dossiers[i].ouvert = false
            }
        }
    }

    // MARK: - Conditions, effets, textes

    static func conditionsOK(_ c: SuccessionConditions?, _ d: SuccessionDossier, _ j: Joueur) -> Bool {
        guard let c else { return true }
        if let v = c.roles, !v.contains(d.role.rawValue) { return false }
        if let v = c.beneficiaires, !v.contains(d.testament.beneficiaire.rawValue) { return false }
        if let v = c.supports, !v.contains(d.testament.support.rawValue) { return false }
        if let v = c.liens, !v.contains(d.lien) { return false }
        if let m = c.minTension, d.tension < m { return false }
        if let m = c.maxTension, d.tension > m { return false }
        if let m = c.minPatrimoine, d.patrimoine < m { return false }
        if let m = c.maxPatrimoine, d.patrimoine > m { return false }
        if let b = c.dettes, b != d.dettes { return false }
        if let b = c.fratrie, b != !d.coheritiers.isEmpty { return false }
        if let b = c.testament, b != (d.testament.beneficiaire != .aucun) { return false }
        if let v = c.clauses, Set(v).isDisjoint(with: d.testament.clauses) { return false }
        if let v = c.flags, !Set(v).isSubset(of: d.flags) { return false }
        if let v = c.excludeFlags, !Set(v).isDisjoint(with: d.flags) { return false }
        if let m = c.minAge, j.age < m { return false }
        if let m = c.maxAge, j.age > m { return false }
        let h = d.rivalPrincipal?.hostilite ?? 0
        if let m = c.minHostilite, h < m { return false }
        if let m = c.maxHostilite, h > m { return false }
        return true
    }

    /// Montant en euros d'un effet (argent fixe + pourcentage du patrimoine).
    static func montant(_ e: SuccessionEffets, _ d: SuccessionDossier) -> Int {
        let pct = e.moneyPct.map { Int(Double(max(0, d.patrimoine)) * $0 / 100) } ?? 0
        return (e.money ?? 0) + pct
    }

    static func effets(_ e: SuccessionEffets?, _ d: SuccessionDossier, bonus: Int) -> Effets? {
        guard e != nil || bonus != 0 else { return nil }
        let s = e ?? SuccessionEffets()
        let argent = montant(s, d) + bonus
        return Effets(happiness: s.happiness, health: s.health, smarts: s.smarts, looks: s.looks, karma: s.karma,
                      money: argent == 0 ? nil : argent, stress: nil, fame: nil, relationships: s.relationships,
                      newFriend: nil, death: s.death)
    }

    static func majuscule(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    /// Remplace les variables du module. Les variables du moteur ({prenom}, {e}…) restent pour `GameEngine.remplir`.
    static func remplir(_ texte: String, _ d: SuccessionDossier) -> String {
        guard texte.contains("{") else { return texte }
        var t = texte
        let rival = d.rivalPrincipal
        let rivalDesignation = rival?.designation ?? "ton cousin Gérard"
        let rempl: [(String, String)] = [
            ("{defunt}", d.defuntPrenom),
            ("{le_defunt}", d.leDefunt),
            ("{Le_defunt}", majuscule(d.leDefunt)),
            ("{rival}", rivalDesignation),
            ("{Rival}", majuscule(rivalDesignation)),
            ("{rival_prenom}", rival?.prenom ?? "Gérard"),
            ("{frere}", d.coheritiers.first ?? rival?.prenom ?? "ton cousin"),
            ("{bien}", d.bien),
            ("{patrimoine}", Format.argent(d.patrimoine)),
            ("{part}", Format.argent(d.part)),
            ("{beneficiaire}", d.beneficiaireNom),
            ("{chat}", d.chat),
            ("{oeuvre}", d.oeuvre),
            ("{notaire}", d.notaire),
        ]
        for (cle, valeur) in rempl { t = t.replacingOccurrences(of: cle, with: valeur) }
        return remplacerPourcentages(t, patrimoine: d.patrimoine)
    }

    /// {pct:15} → 15 % du patrimoine, formaté.
    static func remplacerPourcentages(_ texte: String, patrimoine: Int) -> String {
        guard texte.contains("{pct:"),
              let regex = try? NSRegularExpression(pattern: "\\{pct:(-?[0-9]+)\\}") else { return texte }
        var t = texte
        let ns = t as NSString
        let matches = regex.matches(in: t, range: NSRange(location: 0, length: ns.length))
        for m in matches.reversed() {
            let n = Int(ns.substring(with: m.range(at: 1))) ?? 0
            let valeur = Format.argent(abs(max(0, patrimoine) * n / 100))
            t = (t as NSString).replacingCharacters(in: m.range, with: valeur)
        }
        return t
    }

    // MARK: - Ouverture de secours (si aucune donnée ne correspond)

    static let idSecours = "suc_secours_ouverture"

    static func ouvertureDeSecours(_ d: SuccessionDossier) -> SuccessionEpisode {
        let texte: String
        if d.dettes {
            texte = "{notaire} lit le testament de {le_defunt}. Surprise : il n'y a que des dettes ({patrimoine}). Le notaire range vite son stylo."
        } else if d.part > 0 {
            texte = "{notaire} lit le testament de {le_defunt}. Tu touches {part}. {Rival} te regarde comme un rôti du dimanche."
        } else {
            texte = "{notaire} lit le testament de {le_defunt}. Tout va à {beneficiaire}. Tu repars avec un stylo du cabinet."
        }
        return SuccessionEpisode(id: idSecours, phase: "ouverture", weight: 1, unique: nil, conditions: nil, text: texte,
                                 effects: SuccessionEffets(happiness: d.part > 0 ? 5 : -5), next: nil, delay: nil,
                                 setFlags: nil, close: nil, choices: nil)
    }

    // MARK: - Chroniques (mort du joueur)

    /// 2 à 4 phrases sur ce qui s'est passé après la mort du joueur.
    static func chroniques(lecture l: SuccessionLecture) -> [String] {
        let n = l.tension < 30 ? 2 : (l.tension < 65 ? 3 : 4)
        var pool = chroniquesData.filter { chroniqueOK($0.conditions, l) }
        var lignes: [String] = []
        for _ in 0..<n {
            guard let c = tirer(pool) { $0.weight ?? 1 } else { break }
            pool.removeAll { $0.id == c.id }
            lignes.append(remplirChronique(c.text, l))
        }
        return lignes
    }

    static func chroniqueOK(_ c: SuccessionConditions?, _ l: SuccessionLecture) -> Bool {
        guard let c else { return true }
        if let v = c.beneficiaires, !v.contains(l.testament.beneficiaire.rawValue) { return false }
        if let v = c.supports, !v.contains(l.testament.support.rawValue) { return false }
        if let m = c.minTension, l.tension < m { return false }
        if let m = c.maxTension, l.tension > m { return false }
        if let m = c.minPatrimoine, l.patrimoine < m { return false }
        if let m = c.maxPatrimoine, l.patrimoine > m { return false }
        if let b = c.dettes, b != (l.patrimoine < 0) { return false }
        if let b = c.enfants, b != !l.enfants.isEmpty { return false }
        if let b = c.testament, b != (l.testament.beneficiaire != .aucun) { return false }
        if let v = c.clauses, Set(v).isDisjoint(with: l.testament.clauses) { return false }
        if c.roles != nil || c.flags != nil || c.fratrie != nil { return false }
        return true
    }

    static func remplirChronique(_ texte: String, _ l: SuccessionLecture) -> String {
        let heritier: String = {
            if l.testament.beneficiaire == .enfant, let p = l.testament.beneficiairePrenom { return p }
            let humain = l.parts.filter { $0.relationId != nil }.max { $0.montant < $1.montant }
            return humain.map { String($0.libelle.split(separator: " ").first ?? "") } ?? l.enfants.first?.prenom ?? "ton neveu"
        }()
        let rempl: [(String, String)] = [
            ("{heritier}", heritier),
            ("{enfant}", l.enfants.randomElement()?.prenom ?? "ton neveu"),
            ("{partenaire}", l.partenaire?.prenom ?? "ton ex"),
            ("{rival}", l.cousin.designation),
            ("{Rival}", majuscule(l.cousin.designation)),
            ("{bien}", l.bien),
            ("{patrimoine}", Format.argent(l.patrimoine)),
            ("{chat}", l.chat),
            ("{oeuvre}", l.oeuvre),
            ("{notaire}", l.notaire),
            ("{beneficiaire}", l.beneficiaireNom),
            ("{prenom}", l.defuntPrenom),
            ("{e}", l.defuntGenre == .femme ? "e" : ""),
        ]
        var t = texte
        for (cle, valeur) in rempl { t = t.replacingOccurrences(of: cle, with: valeur) }
        return t
    }
}

import Foundation

// Module « Voyages sur mesure » : règles (transports possibles, devis, moments, fin du voyage).
// Voir docs/VOYAGES.md.

@MainActor
enum VoyMoteur {
    static var cat: VoyCatalogue { .shared }

    /// Voyages sur mesure possibles par an.
    static let maxParAn = 2
    static let ageMin = 12
    static let maxCompagnons = 6

    // MARK: - Ouverture

    /// Raison pour laquelle on ne peut pas partir maintenant (nil = on peut).
    static func verrou(_ j: Joueur) -> String? {
        if j.age < ageMin { return "Dès \(ageMin) ans. Avant, tu pars avec tes parents sans avoir ton mot à dire." }
        if j.vieEtat.justice.enPrison { return "Tu es en prison. Le seul voyage possible, c'est la promenade." }
        let n = (j.voyages ?? VoyagesEtat()).voyages(aLAge: j.age)
        if n >= maxParAn { return "Tu as déjà fait \(n) voyages sur mesure cette année. Reviens l'an prochain." }
        return nil
    }

    /// Proches qui peuvent venir.
    static func prochesPossibles(_ j: Joueur) -> [Relation] {
        j.relations.filter { $0.vivant && VoyTypeProche.depuis($0.type) != nil }
            .sorted { ordre($0.type) < ordre($1.type) }
    }

    private static func ordre(_ t: TypeRelation) -> Int {
        switch t {
        case .partenaire: return 0
        case .enfant: return 1
        case .mere, .pere: return 2
        case .frere, .soeur: return 3
        case .ami: return 4
        case .ex: return 5
        }
    }

    /// Distance utile : courte si on voyage dans le pays où l'on vit.
    static func distance(_ d: VoyDestination, _ j: Joueur) -> Int {
        if d.id == j.etatExpat.paysActuel { return min(d.distance, 450) }
        return d.distance
    }

    /// Accès utile : tout est « par la route » dans son propre pays.
    static func acces(_ d: VoyDestination, _ j: Joueur) -> String {
        d.id == j.etatExpat.paysActuel ? "route" : d.acces
    }

    // MARK: - Transports

    static func optionsTransport(_ d: VoyDestination, _ j: Joueur, voyageurs n: Int, jours: Int) -> [VoyOptionTransport] {
        let km = distance(d, j)
        let a = acces(d, j)
        let route = a == "route" || a == "ferry"
        let ferryEnPlus = a == "ferry" ? 70 : 0
        let permisVoiture = j.permis?.valide(.voiture, age: j.age) ?? false
        var options: [VoyOptionTransport] = []

        func ajouter(_ t: VoyTransportType, parPersonne: Double = 0, fixe: Double = 0, placesParVehicule: Int? = nil,
                     places: Int? = nil, confort: Int, karma: Int = 0, sante: Int = 0, detail: String, raison: String?) {
            options.append(VoyOptionTransport(type: t, vehiculeId: nil, nom: t.nom, detail: detail, places: places,
                                              parPersonne: Int(parPersonne.rounded()), fixe: Int(fixe.rounded()),
                                              placesParVehicule: placesParVehicule, equipageParJour: 0,
                                              confort: confort, karma: karma, sante: sante, groupes: t.groupes,
                                              raison: raison))
        }
        let kmAR = Double(km * 2)
        let pasDeLigne: String? = d.id == "aq" ? "Aucune ligne régulière ne va \(d.enPays)." : nil

        ajouter(.train, parPersonne: 0.12 * kmAR + Double(ferryEnPlus), confort: 2, karma: 1,
                detail: "Paysages et retards inclus.",
                raison: !route ? "Aucun train ne va \(d.enPays)." : (km > 3000 ? "Trop loin pour le train." : nil))
        ajouter(.autocar, parPersonne: 0.06 * kmAR + Double(ferryEnPlus), confort: -2, karma: 1,
                detail: "Pas cher, long, et quelqu'un mange un œuf dur.",
                raison: !route ? "Aucun car ne va \(d.enPays)." : (km > 3000 ? "Trop loin en autocar." : nil))
        ajouter(.covoiturage, parPersonne: 0.05 * kmAR, places: 4, confort: -1, karma: 1,
                detail: "Un inconnu, sa playlist et ses opinions.",
                raison: a != "route" ? "Pas de covoiturage jusque-là." : (km > 2000 ? "Personne ne fait ce trajet en covoiturage." : (j.age < 16 ? "Dès 16 ans." : nil)))
        ajouter(.autostop, places: 3, confort: -3, karma: 1, sante: -1,
                detail: "Gratuit. Le reste dépend des conducteurs.",
                raison: a != "route" ? "Le pouce ne traverse pas la mer." : (km > 2500 ? "Trop loin pour le stop." : (j.age < 16 ? "Dès 16 ans." : nil)))
        ajouter(.voitureLocation, fixe: (0.10 * kmAR + 45 * Double(jours) + Double(ferryEnPlus * 2)), placesParVehicule: 5, confort: 0,
                detail: "45 € par jour et par voiture de 5 places, plus l'essence.",
                raison: !route ? "On ne va pas \(d.enPays) en voiture." : (!permisVoiture ? "Il faut un permis voiture valide." : nil))
        ajouter(.avionLowCost, parPersonne: 0.07 * kmAR + 30, confort: -2,
                detail: "Bagage cabine de 40 cm, genoux sous le menton.",
                raison: km < 300 ? "Trop près pour prendre l'avion." : (km > 4500 ? "Aucune compagnie low cost ne vole aussi loin." : pasDeLigne))
        ajouter(.avionEco, parPersonne: 0.11 * kmAR + 40, confort: 0, karma: -1,
                detail: "Un plateau-repas et un film déjà vu.",
                raison: km < 300 ? "Trop près pour prendre l'avion." : pasDeLigne)
        ajouter(.avionBusiness, parPersonne: 0.35 * kmAR + 100, confort: 4, karma: -1,
                detail: "Siège-lit et vraie vaisselle.",
                raison: km < 300 ? "Trop près pour prendre l'avion." : pasDeLigne)
        ajouter(.avionPremiere, parPersonne: 0.8 * kmAR + 300, confort: 7, karma: -2,
                detail: "Ta propre cabine et du champagne au décollage.",
                raison: km < 1500 ? "Pas de première classe sur un vol aussi court." : pasDeLigne)
        ajouter(.jetLocation, fixe: 6 * kmAR + 3000, placesParVehicule: 12, confort: 9, karma: -3,
                detail: "Un jet rien que pour vous (12 places).",
                raison: km < 300 ? "Trop près, même pour un jet." : (j.age < 18 ? "Dès 18 ans." : nil))
        ajouter(.ferry, parPersonne: 0.10 * kmAR, confort: -1,
                detail: "Pont supérieur, vent de face, frites tièdes.",
                raison: !d.cotier ? "Pas de côte \(d.enPays)." : (a == "avion" ? "Aucun ferry ne va jusque-là." : (km > 3000 ? "Trop loin pour un ferry." : nil)))
        ajouter(.croisiere, parPersonne: 0.22 * kmAR + 400, confort: 4, karma: -2,
                detail: "Buffet à volonté, spectacle à 21 h.",
                raison: !d.cotier ? "Pas de côte \(d.enPays)." : (km < 800 ? "Trop près pour une croisière." : nil))

        options += vehiculesPerso(d, j, km: km, route: route, ferryEnPlus: ferryEnPlus)
        for i in options.indices where options[i].raison == nil {
            if let p = capacite(options[i]), n > p {
                options[i].raison = "Pas assez de places (\(p) au total)."
            }
        }
        return options
    }

    /// Places au total pour une option (nil = illimité).
    static func capacite(_ o: VoyOptionTransport) -> Int? {
        if o.placesParVehicule != nil { return nil }
        return o.places
    }

    /// Véhicules du joueur : voiture, moto (ou vélo), bateau, avion.
    static func vehiculesPerso(_ d: VoyDestination, _ j: Joueur, km: Int, route: Bool, ferryEnPlus: Int) -> [VoyOptionTransport] {
        var res: [VoyOptionTransport] = []
        let permis = j.permis ?? PermisEtat()
        let kmAR = Double(km * 2)
        for o in j.boutique.items {
            guard let item = ShopCatalog.shared.item(o.catalogId) else { continue }
            let nom = o.nickname ?? item.name
            let sub = item.subcategory
            var opt = VoyOptionTransport(type: .maVoiture, vehiculeId: o.id, nom: nom, detail: "", places: 5,
                                         parPersonne: 0, fixe: 0, placesParVehicule: nil, equipageParJour: 0,
                                         confort: 1, karma: 0, sante: 0, groupes: [], raison: nil,
                                         texte: texteVehicule(item))
            switch item.category {
            case .car:
                opt.type = .maVoiture
                switch sub {
                case "sportive", "supercar", "hypercar", "cabriolet", "insolite": opt.places = 2
                case "monospace": opt.places = 7
                case "limousine": opt.places = 8
                default: opt.places = 5
                }
                opt.fixe = Int(0.12 * kmAR * (1 + Double(item.price) / 300_000)) + ferryEnPlus * 2
                opt.confort = item.price >= 80_000 ? 4 : 1
                opt.detail = "\(opt.places ?? 5) places · essence et péages"
                if !route { opt.raison = "Ta voiture ne va pas \(d.enPays). Elle ne flotte pas." }
                else if !permis.valide(.voiture, age: j.age) { opt.raison = "Il te faut un permis voiture valide." }
            case .moto:
                opt.type = .maMoto
                let velo = sub == "velo" || sub == "trottinette"
                opt.places = (sub == "sidecar" || (!velo && sub != "mobylette")) ? 2 : 1
                opt.fixe = velo ? 0 : Int(0.06 * kmAR) + ferryEnPlus * 2
                opt.confort = velo ? -2 : 0
                opt.sante = velo ? 4 : 0
                opt.karma = velo ? 2 : 0
                opt.detail = velo ? "À la force des mollets" : "\(opt.places ?? 1) place\((opt.places ?? 1) > 1 ? "s" : "") · cheveux au vent"
                let permisOK: Bool
                if velo { permisOK = true }
                else if sub == "scooter" || sub == "mobylette" {
                    permisOK = permis.valide(.scooter, age: j.age) || permis.valide(.moto, age: j.age) || permis.valide(.voiture, age: j.age)
                } else { permisOK = permis.valide(.moto, age: j.age) }
                if ["jetpack", "motoneige", "quad"].contains(sub) { opt.raison = "Pas fait pour un long trajet sur la route." }
                else if !route { opt.raison = "Pas \(d.enPays) en deux-roues : il y a de l'eau entre vous." }
                else if sub == "trottinette" && km > 300 { opt.raison = "Trop loin en trottinette (300 km au plus)." }
                else if velo && km > 1500 { opt.raison = "Trop loin à vélo (1 500 km au plus)." }
                else if !permisOK { opt.raison = "Il te faut le permis qui va avec." }
            case .boat:
                opt.type = .monBateau
                let portee: Int? = item.price < 5_000 ? 80 : (item.price < 60_000 ? 1_500 : (item.price < 600_000 ? 5_000 : nil))
                opt.places = item.price < 60_000 ? 4 : (item.price < 600_000 ? 8 : 20)
                let parKm = min(25, max(0.2, Double(item.price) / 1_000_000 * 1.5))
                opt.fixe = Int(parKm * kmAR)
                opt.confort = item.price >= 1_000_000 ? 7 : 3
                opt.karma = item.price >= 1_000_000 ? -2 : 0
                opt.groupes = item.price >= 1_000_000 ? ["luxe"] : []
                if !permis.valide(.bateau, age: j.age) { opt.equipageParJour = item.price >= 1_000_000 ? 900 : 250 }
                opt.detail = "\(opt.places ?? 4) places" + (opt.equipageParJour > 0 ? " · skipper payé (pas de permis bateau)" : " · tu tiens la barre")
                if !d.cotier { opt.raison = "Pas de côte \(d.enPays). Même ton bateau a ses limites." }
                else if let p = portee, km > p { opt.raison = p < 100 ? "Trop petit pour la haute mer." : "Trop loin pour ce bateau (\(p) km au plus)." }
            case .aircraft:
                opt.type = .monAvion
                let regle = reglesAvion[sub]
                opt.places = regle?.places ?? 2
                let parKm = min(20, max(0.4, Double(item.price) / 4_000_000))
                opt.fixe = Int(parKm * kmAR)
                opt.confort = ["jet", "grosporteur", "navette"].contains(sub) ? 9 : 5
                opt.karma = ["jet", "grosporteur", "navette", "chasse"].contains(sub) ? -3 : -1
                opt.groupes = ["jet", "grosporteur", "navette", "helicoptere", "dirigeable"].contains(sub) ? ["luxe"] : []
                if let r = regle, !permis.valide(r.licence, age: j.age) { opt.equipageParJour = r.pilote }
                opt.detail = "\(opt.places ?? 2) places" + (opt.equipageParJour > 0 ? " · pilote payé (pas de licence)" : " · tu pilotes")
                if regle == nil { opt.raison = "Ça vole, mais pas jusque là." }
                else if let p = regle?.portee, km > p { opt.raison = "Trop loin pour cet appareil (\(p) km au plus)." }
                else if km < 50 { opt.raison = "Trop près pour sortir l'avion." }
            default:
                continue
            }
            opt.groupes.formUnion(opt.type.groupes)
            if opt.raison == nil, o.condition <= 10 { opt.raison = "\(nom) est en trop mauvais état pour partir." }
            res.append(opt)
        }
        return res
    }

    /// Avions du joueur : portée (nil = illimitée), places, licence, prix du pilote par jour.
    static let reglesAvion: [String: (portee: Int?, places: Int, licence: PermisType, pilote: Int)] = [
        "jet": (nil, 12, .avion, 1500),
        "grosporteur": (nil, 60, .avion, 3000),
        "navette": (nil, 7, .fusee, 5000),
        "bimoteur": (2500, 6, .avion, 600),
        "avion": (1500, 4, .avion, 500),
        "hydravion": (1500, 4, .avion, 500),
        "bombardier-eau": (1500, 4, .avion, 800),
        "chasse": (3000, 2, .avion, 2000),
        "voltige": (600, 2, .avion, 400),
        "biplan": (600, 2, .avion, 400),
        "helicoptere": (700, 4, .helicoptere, 700),
        "dirigeable": (1200, 10, .avion, 800),
        "autogire": (400, 2, .avion, 300),
        "ulm": (400, 2, .avion, 300),
        "voiture": (800, 2, .avion, 400),
    ]

    // MARK: - Devis

    static func devis(_ d: VoyDestination, option o: VoyOptionTransport, hebergement h: VoyHebergement, duree: VoyDuree,
                      compagnons: [Relation], invite: Bool, _ j: Joueur) -> VoyDevis {
        let n = 1 + compagnons.count
        let mult = ShopHooks.priceMultiplier("voyages")
        var transport = Double(o.parPersonne * n)
        if let ppv = o.placesParVehicule {
            transport += Double(o.fixe) * Double((n + ppv - 1) / ppv)
        } else {
            transport += Double(o.fixe)
        }
        // Les petits voyagent à moitié prix et dorment dans la chambre des grands.
        let petits = compagnons.filter { $0.age < 12 }.count
        let poids = 1 + 0.65 * Double(n - 1 - petits) + 0.3 * Double(petits)
        let heb = Double(d.prixJour) * h.multiplicateur * Double(duree.jours) * poids
        let equipage = o.equipageParJour * duree.jours
        let total = Int((transport + heb) * mult) + equipage
        let parents = j.age < 18
        var part = total
        if parents {
            part = 0
        } else if !invite {
            // Chacun paie sa part ; le joueur paie aussi pour les enfants mineurs.
            let mineurs = compagnons.filter { $0.age < 18 }.count
            let payeurs = max(1, n - mineurs)
            part = total * (1 + mineurs) / payeurs
        }
        return VoyDevis(transport: Int(transport * mult), hebergement: Int(heb * mult), equipage: equipage,
                        partJoueur: part, parLesParents: parents)
    }

    /// Ce qui empêche de partir avec ce plan (nil = c'est bon).
    static func probleme(_ d: VoyDestination, option o: VoyOptionTransport, hebergement h: VoyHebergement,
                         compagnons: [Relation], devis: VoyDevis, _ j: Joueur) -> String? {
        if let r = o.raison { return r }
        if compagnons.count > maxCompagnons { return "\(maxCompagnons) proches au plus." }
        if j.age < 18 && !compagnons.contains(where: { $0.type.estParent }) {
            return "Avant 18 ans, un parent doit venir (et payer)."
        }
        if j.age < h.ageMin { return "\(h.nom) : dès \(h.ageMin) ans." }
        if devis.parLesParents {
            let budgetParents = compagnons.filter { $0.type.estParent }.map(\.argent).reduce(0, +) + 3000
            if devis.total > budgetParents && !Shkurtaaa.actif {
                return "Tes parents ont dit non : \(Format.argent(devis.total)), c'est trop pour eux."
            }
        } else if !ShopHooks.canAfford(devis.partJoueur, j.argent) {
            return "Il te manque \(Format.argent(devis.partJoueur - j.argent)) pour ce voyage."
        }
        return nil
    }

    // MARK: - Départ

    static func vehiculeTexte(_ o: VoyOptionTransport) -> String {
        o.texte.isEmpty ? o.type.texte : o.texte
    }

    /// « ta voiture », « ton vélo », « ton jet »… selon le véhicule du joueur.
    static func texteVehicule(_ item: ShopItem) -> String {
        switch item.category {
        case .car: return "ta voiture"
        case .moto:
            switch item.subcategory {
            case "velo": return "ton vélo"
            case "trottinette": return "ta trottinette"
            case "scooter": return "ton scooter"
            case "mobylette": return "ta mobylette"
            default: return "ta moto"
            }
        case .boat:
            switch item.subcategory {
            case "yacht", "megayacht", "gigayacht": return "ton yacht"
            case "voilier", "trois-mats": return "ton voilier"
            case "catamaran": return "ton catamaran"
            default: return "ton bateau"
            }
        case .aircraft:
            switch item.subcategory {
            case "jet": return "ton jet"
            case "helicoptere": return "ton hélicoptère"
            case "hydravion": return "ton hydravion"
            case "dirigeable": return "ton dirigeable"
            case "navette": return "ta navette spatiale"
            default: return "ton avion"
            }
        default: return "ton véhicule"
        }
    }

    /// Paie, prépare les moments et renvoie le voyage prêt à se dérouler.
    static func partir(_ d: VoyDestination, ville: String, option o: VoyOptionTransport, hebergement h: VoyHebergement,
                       duree: VoyDuree, compagnons: [Relation], invite: Bool, engine: GameEngine) -> VoyEnCours? {
        guard let j0 = engine.joueur else { return nil }
        let dv = devis(d, option: o, hebergement: h, duree: duree, compagnons: compagnons, invite: invite, j0)
        guard probleme(d, option: o, hebergement: h, compagnons: compagnons, devis: dv, j0) == nil else { return nil }
        var voyage = VoyEnCours(destination: d, ville: ville, option: o, hebergement: h, duree: duree,
                                compagnons: compagnons.map(\.id), invite: invite, devis: dv,
                                nouveauPays: (j0.voyages?.pays[d.id] ?? 0) == 0 && d.id != j0.etatExpat.paysNaissance,
                                vehiculeTexte: vehiculeTexte(o))
        engine.modifier { j in
            if dv.parLesParents {
                var reste = dv.total
                for i in j.relations.indices where compagnons.contains(where: { $0.id == j.relations[i].id }) && j.relations[i].type.estParent {
                    let pris = min(reste, j.relations[i].argent)
                    j.relations[i].argent -= pris
                    reste -= pris
                }
            } else {
                j.argent -= dv.partJoueur
            }
            j.actionsAnnee.append("voyage_mesure")
            voyage.moments = tirerMoments(voyage, j, engine: engine)
        }
        return voyage
    }

    // MARK: - Moments

    /// Les moments du voyage : un trajet (souvent), le séjour, un retour (parfois).
    static func tirerMoments(_ v: VoyEnCours, _ j: Joueur, engine: GameEngine) -> [VoyMomentAffiche] {
        var phases: [String] = []
        if Double.random(in: 0..<1) < 0.75 { phases.append("trajet") }
        phases += Array(repeating: "sejour", count: v.duree.momentsSejour)
        if Double.random(in: 0..<1) < (v.duree == .weekend ? 0.35 : 0.6) { phases.append("retour") }

        let tags = engine.tags(j)
        let proches = j.relations.filter { v.compagnons.contains($0.id) }
        let vus = Set(j.voyages?.momentsVus ?? [])
        var pris: Set<String> = []
        var res: [VoyMomentAffiche] = []
        for phase in phases {
            let candidats = cat.moments.filter {
                $0.phase == phase && !pris.contains($0.id) && possible($0, v, j, proches: proches, tags: tags, vus: vus, engine: engine)
            }
            guard let m = GameEngine.tirage(candidats, poids: { ($0.weight ?? 1) * (vus.contains($0.id) ? 0.15 : 1) }) else { continue }
            pris.insert(m.id)
            res.append(afficher(m, v, j, proches: proches, engine: engine))
        }
        return res
    }

    static func possible(_ m: VoyMoment, _ v: VoyEnCours, _ j: Joueur, proches: [Relation], tags: Set<String>,
                         vus: Set<String>, engine: GameEngine) -> Bool {
        if m.unique == true && vus.contains(m.id) { return false }
        if let t = m.transports, !t.contains(v.option.type.rawValue) { return false }
        if let g = m.groupes, Set(g).isDisjoint(with: v.option.groupes) { return false }
        if let d = m.destinations, !d.contains(v.destination.id) { return false }
        if let c = m.continents, !c.contains(v.destination.continent) { return false }
        if let c = m.climats, !c.contains(v.destination.climat) { return false }
        if let h = m.hebergements, !h.contains(v.hebergement.rawValue) { return false }
        if let n = m.minJours, v.duree.jours < n { return false }
        if m.seul == true && !proches.isEmpty { return false }
        if m.groupe == true && proches.count < 3 { return false }
        if let avec = m.avec, !avec.isEmpty {
            let types = Set(avec)
            if !proches.contains(where: { VoyTypeProche.depuis($0.type).map { types.contains($0.rawValue) } ?? false }) { return false }
        }
        if m.vehiculeUse == true {
            guard let id = v.option.vehiculeId, let o = j.boutique.items.first(where: { $0.id == id }), o.condition <= 50 else { return false }
        }
        guard m.choices.contains(where: { Competences.aLeNiveau($0.requiresSkill, j) }) else { return false }
        return engine.conditionsRemplies(m.commeEvenement, j, tags: tags)
    }

    static func afficher(_ m: VoyMoment, _ v: VoyEnCours, _ j: Joueur, proches: [Relation], engine: GameEngine) -> VoyMomentAffiche {
        var compagnon: Relation?
        if let avec = m.avec, !avec.isEmpty {
            compagnon = proches.filter { VoyTypeProche.depuis($0.type).map { avec.contains($0.rawValue) } ?? false }.randomElement()
        } else if m.seul != true {
            compagnon = proches.randomElement()
        }
        let ctx = Contexte(v: v, compagnon: compagnon, incontournable: v.destination.incontournables.randomElement() ?? "les monuments",
                           specialite: v.destination.specialites.randomElement() ?? "la spécialité locale")
        let choix = m.choices.enumerated()
            .filter { Competences.aLeNiveau($0.element.requiresSkill, j) }
            .map { VoyChoixAffiche(index: $0.offset, label: remplir($0.element.label, ctx, j, engine: engine)) }
        return VoyMomentAffiche(moment: m, texte: remplir(m.text, ctx, j, engine: engine), choix: choix,
                                compagnonId: compagnon?.id, incontournable: ctx.incontournable, specialite: ctx.specialite)
    }

    struct Contexte {
        var v: VoyEnCours
        var compagnon: Relation?
        var incontournable: String
        var specialite: String
    }

    /// Remplit les variables du module, puis celles du moteur.
    static func remplir(_ texte: String, _ c: Contexte, _ j: Joueur, engine: GameEngine) -> String {
        guard texte.contains("{") else { return texte }
        var t = texte
        let r = c.compagnon
        let qui = r.map { $0.designation.lowercased() } ?? "ton compagnon de route"
        let quiMaj = r?.designation ?? "Ton compagnon de route"
        let femme = r?.genre == .femme
        let remplacements: [(String, String)] = [
            ("{compagnon_qui}", qui),
            ("{Compagnon_qui}", quiMaj),
            ("{compagnon_e}", femme ? "e" : ""),
            ("{compagnon}", r?.prenom ?? "ton compagnon de route"),
            ("{Il}", femme ? "Elle" : "Il"),
            ("{il}", femme ? "elle" : "il"),
            ("{pays}", c.v.destination.nom),
            ("{en_pays}", c.v.destination.enPays),
            ("{destination}", c.v.ville),
            ("{incontournable}", c.incontournable),
            ("{specialite}", c.specialite),
            ("{vehicule}", c.v.vehiculeTexte),
            ("{hebergement}", c.v.hebergement.texte),
            ("{nb}", "\(1 + c.v.compagnons.count)"),
        ]
        for (cle, valeur) in remplacements { t = t.replacingOccurrences(of: cle, with: valeur) }
        return engine.remplir(t, j)
    }

    // MARK: - Choix pendant un moment

    /// Applique le choix du joueur et renvoie le texte du résultat.
    static func choisir(_ index: Int, voyage v: inout VoyEnCours, engine: GameEngine) -> String {
        guard v.moments.indices.contains(v.index) else { return "" }
        let aff = v.moments[v.index]
        guard aff.moment.choices.indices.contains(index), engine.joueur != nil else { return "" }
        let c = aff.moment.choices[index]
        let issue = GameEngine.tirage(c.outcomes) { $0.chance ?? 1 }
        var texte = ""
        var souvenir: String?
        engine.modifier { j in
            let proches = j.relations.filter { v.compagnons.contains($0.id) }
            let compagnon = aff.compagnonId.flatMap { id in proches.first { $0.id == id } }
            let ctx = Contexte(v: v, compagnon: compagnon, incontournable: aff.incontournable, specialite: aff.specialite)
            texte = remplir(issue?.text ?? "Il ne se passe rien de spécial.", ctx, j, engine: engine)
            engine.ajouterLigne(&j, "🧳 " + aff.texte + " → " + remplir(c.label, ctx, j, engine: engine) + ". " + texte)
            if let i = issue {
                if var eff = i.effects {
                    eff.relationships = nil
                    engine.appliquer(eff, &j)
                }
                if let delta = i.compagnon, let id = aff.compagnonId, let k = j.relations.firstIndex(where: { $0.id == id }) {
                    j.relations[k].lien = Stats.borne(j.relations[k].lien + delta)
                }
                if let delta = i.compagnons {
                    for k in j.relations.indices where v.compagnons.contains(j.relations[k].id) {
                        j.relations[k].lien = Stats.borne(j.relations[k].lien + delta)
                    }
                }
                if let delta = i.vehicule, let id = v.option.vehiculeId,
                   let k = j.boutique.items.firstIndex(where: { $0.id == id }) {
                    j.boutique.items[k].condition = max(0, min(100, j.boutique.items[k].condition + delta))
                }
                if let s = i.souvenir { souvenir = remplir(s, ctx, j, engine: engine) }
                if let s = i.signal { SignauxModules.signaler(s, &j) }
            }
            let k = issue.flatMap { i in c.outcomes.firstIndex(of: i) }
            SignauxModules.signaler("event:\(aff.moment.id)", &j, choix: index, issue: k)
            var etat = j.voyages ?? VoyagesEtat()
            if !etat.momentsVus.contains(aff.moment.id) { etat.momentsVus.append(aff.moment.id) }
            j.voyages = etat
        }
        if let s = souvenir { v.souvenirs.append(s) }
        v.moments[v.index].resultat = texte
        return texte
    }

    // MARK: - Fin du voyage

    /// Bilan du voyage : stats, liens, langue, carnet, journal et signaux. Renvoie le récit.
    static func terminer(_ v: inout VoyEnCours, engine: GameEngine) {
        guard !v.termine else { return }
        v.termine = true
        var recit = ""
        engine.modifier { j in
            guard j.vivant else { return }
            let d = v.destination
            let proches = j.relations.filter { v.compagnons.contains($0.id) }

            // Stats
            var bonheur = v.duree.bonheur + v.option.confort + v.hebergement.bonheur + (v.nouveauPays ? 3 : 0)
            if proches.isEmpty && j.age >= 18 { bonheur -= 1 }
            j.stats.bonheur += bonheur
            j.stats.sante += v.hebergement.sante + v.option.sante + (v.duree.jours >= 7 ? 2 : 0)
            j.stats.karma += v.option.karma
            j.stats.borner()

            // Liens avec les proches présents
            for k in j.relations.indices where v.compagnons.contains(j.relations[k].id) {
                let bonus = Int.random(in: 3...7) + (v.invite || v.devis.parLesParents ? 4 : 0)
                j.relations[k].lien = Stats.borne(j.relations[k].lien + bonus)
            }

            // Langue et compétence
            var expat = j.etatExpat
            if ExpatCatalogue.shared.trouverPays(d.id) != nil, !expat.paysConnus.contains(d.id) { expat.paysConnus.append(d.id) }
            if let l = d.langue {
                let gain = v.duree.jours >= 30 ? 8 : (v.duree.jours >= 14 ? 4 : (v.duree.jours >= 7 ? 2 : 1))
                let actuel = expat.niveau(l)
                if actuel < 60 { expat.langues[l] = min(60, actuel + gain) }
            }
            j.etranger = expat
            if let comp = d.competence {
                let xp = v.duree.jours >= 30 ? 8 : (v.duree.jours >= 14 ? 5 : 3)
                engine.appliquer(Effets(skills: [comp: xp]), &j)
            }

            // Travail : un mois d'absence se remarque
            if v.duree.jours >= 14 {
                let perte = v.duree.jours >= 30 ? 10 : 3
                if var e = j.emploi {
                    e.performance = Stats.borne(e.performance - perte)
                    j.emploi = e
                }
                if var c = j.carriere {
                    c.performance = max(0, c.performance - perte)
                    j.carriere = c
                }
                if v.duree.jours >= 30 && (j.emploi != nil || j.carriere != nil) {
                    engine.ajouterLigne(&j, "Ton absence d'un mois a été remarquée au travail. Ta performance en a pris un coup.")
                }
            }

            // Véhicule personnel : usure
            if let id = v.option.vehiculeId, let k = j.boutique.items.firstIndex(where: { $0.id == id }) {
                let usure = min(25, max(3, distance(d, j) / 250))
                j.boutique.items[k].condition = max(0, j.boutique.items[k].condition - usure)
            }

            // Carnet
            let noms = proches.map(\.prenom)
            let cout = v.devis.parLesParents ? 0 : v.devis.partJoueur
            var etat = j.voyages ?? VoyagesEtat()
            etat.recits.append(VoyRecit(age: j.age, pays: d.id, ville: v.ville, transport: v.option.nom,
                                        hebergement: v.hebergement.nom, jours: v.duree.jours, compagnons: noms,
                                        cout: cout, souvenirs: v.souvenirs))
            etat.pays[d.id, default: 0] += 1
            j.voyages = etat
            var b = j.boutique
            b.travels.append(ShopTravelRecord(tripId: "mesure_\(d.id)", age: j.age))
            j.boutique = b

            // Journal
            let avec = noms.isEmpty ? j.g("seul", "seule") : "avec " + liste(noms)
            let transport = v.option.vehiculeId != nil ? "en \(v.option.nom)" : "(\(v.option.nom.lowercased()))"
            recit = "\(d.drapeau) \(v.duree.nom) \(d.enPays), à \(v.ville), \(transport), \(avec). "
                + (v.devis.parLesParents ? "Payé par tes parents." : "Coût : \(Format.argent(cout)).")
            if v.nouveauPays { recit += " Premier séjour \(d.enPays) !" }
            engine.ajouterLigne(&j, recit)

            // Signaux
            SignauxModules.signaler("voyage", &j)
            let types = Set(proches.compactMap { VoyTypeProche.depuis($0.type) })
            if types.contains(.partenaire) { SignauxModules.signaler("voyage_couple", &j) }
            if types.contains(.enfant) || types.contains(.parent) || types.contains(.fratrie) { SignauxModules.signaler("voyage_famille", &j) }
            if types.contains(.ami) { SignauxModules.signaler("voyage_amis", &j) }
            if proches.isEmpty { SignauxModules.signaler("voyage_seul", &j) }
            if v.option.groupes.contains("luxe") || v.hebergement == .luxe || v.hebergement == .palace {
                SignauxModules.signaler("voyage_luxe", &j)
            }
        }
        v.recit = recit
    }

    static func liste(_ noms: [String]) -> String {
        guard noms.count > 1 else { return noms.first ?? "" }
        return noms.dropLast().joined(separator: ", ") + " et " + noms.last!
    }

    // MARK: - Tags

    static func tags(_ e: VoyagesEtat?, age: Int) -> Set<String> {
        guard let e else { return [] }
        var t: Set<String> = []
        if e.recits.count >= 5 { t.insert("voyageur") }
        if e.pays.count >= 15 { t.insert("globe_trotter") }
        if e.recits.contains(where: { $0.age == age }) { t.insert("voyage_cette_annee") }
        return t
    }
}

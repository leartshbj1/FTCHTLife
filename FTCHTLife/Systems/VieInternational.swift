import Foundation

// Trafic international : routes d'import (fournisseurs étrangers) et d'export (marchés étrangers),
// cargaisons qui arrivent l'année suivante, saisies en douane, confiance des partenaires.
// Données : Data/MilieuRoutes. Appelé par VieMilieu (vieillir, tags, remplir, effets).

// MARK: - Données

struct MilieuRoute: Codable, Identifiable, Equatable {
    var id: String
    /// import ou export
    var sens: String
    var nom: String
    var region: String
    var partenaire: String
    var description: String
    var produits: [String]
    /// Import : part du prix d'achat local. Export : multiplicateur du prix du marché local.
    var facteur: Double
    /// Risque de saisie de base.
    var risque: Double
    var coutFixe: Int
    var minLots: Int
    var maxLots: Int
    var rangMin: Int

    var estImport: Bool { sens == "import" }
}

enum TransportMode: String, Codable, CaseIterable, Identifiable {
    case port, frontiere, avion

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .port: return "Par le port"
        case .frontiere: return "Par la frontière"
        case .avion: return "Par avion"
        }
    }

    var detail: String {
        switch self {
        case .port: return "Le prix normal, le risque normal"
        case .frontiere: return "30 % moins cher, plus de contrôles"
        case .avion: return "Trois fois plus cher, beaucoup moins de saisies"
        }
    }

    var risque: Double {
        switch self {
        case .port: return 1
        case .frontiere: return 1.25
        case .avion: return 0.55
        }
    }

    var cout: Double {
        switch self {
        case .port: return 1
        case .frontiere: return 0.7
        case .avion: return 3
        }
    }
}

// MARK: - État sauvegardé

struct VieCargaison: Codable, Equatable, Identifiable {
    var id = UUID()
    var routeId: String
    var produitId: String
    var lots: Int
    var mode: TransportMode
    /// Import : prix payé. Export : recette attendue.
    var montant: Int
}

struct VieInternationalEtat: Codable, Equatable {
    var cargaisons: [VieCargaison] = []
    /// Confiance de chaque partenaire, par route (0…100).
    var confiance: [String: Int] = [:]
    var livrees = 0
    var saisies = 0
}

// MARK: - Système

enum MilieuInternational {

    static let routes: [MilieuRoute] = DonneesJSON.chargerTableaux(dossier: "MilieuRoutes", type: MilieuRoute.self)
    static let maxCargaisons = 4

    static func route(_ id: String?) -> MilieuRoute? {
        guard let id else { return nil }
        return routes.first { $0.id == id }
    }

    static func etat(_ j: Joueur) -> VieInternationalEtat { VieMilieu.etat(j).international ?? VieInternationalEtat() }

    static func modifier(_ j: inout Joueur, _ f: (inout VieInternationalEtat) -> Void) {
        VieMilieu.modifier(&j) { m in
            var i = m.international ?? VieInternationalEtat()
            f(&i)
            for (k, v) in i.confiance { i.confiance[k] = Stats.borne(v) }
            m.international = i
        }
    }

    static func confiance(_ routeId: String, _ e: VieInternationalEtat) -> Int { e.confiance[routeId] ?? 30 }

    /// Ouvert aux membres d'une organisation (rang 2 et plus) et aux gros trafiquants.
    static func accessible(_ j: Joueur) -> Bool {
        let m = VieMilieu.etat(j)
        guard let t = m.trafic else { return false }
        return (m.membre && m.rang >= 1) || t.b.lotsVendusTotal >= 25
    }

    static func routesAccessibles(_ j: Joueur) -> [MilieuRoute] {
        let m = VieMilieu.etat(j)
        let rang = m.membre ? m.rang : 0
        return routes.filter { $0.rangMin <= rang }
    }

    static func maxLots(_ r: MilieuRoute, _ j: Joueur) -> Int {
        let c = confiance(r.id, etat(j))
        return max(r.minLots, Int(Double(r.maxLots) * (0.5 + Double(c) / 100)))
    }

    static func prixLot(_ r: MilieuRoute, _ p: MilieuProduit, _ j: Joueur) -> Int {
        let c = Double(confiance(r.id, etat(j)))
        let b = MilieuTrafic.business(j) ?? TraficBusiness()
        if r.estImport {
            return Int(Double(p.prixLot) * r.facteur * (1 - c / 500) * (1 + Double(b.coursDe(p.id)) / 200))
        }
        return Int(Double(MilieuTrafic.prixMarche(p, b)) * r.facteur * (1 + c / 500))
    }

    static func coutTransport(_ r: MilieuRoute, _ mode: TransportMode) -> Int { Int(Double(r.coutFixe) * mode.cout) }

    static func risque(_ r: MilieuRoute, _ mode: TransportMode, lots: Int, _ j: Joueur) -> Double {
        let c = Double(confiance(r.id, etat(j)))
        var x = r.risque * mode.risque * MilieuProtection.facteurDouane(j) * (1 + Double(VieMilieu.etat(j).chaleur) / 200) * (1 - c / 300)
        if lots > r.maxLots / 2 { x *= 1.15 }
        return VieHasard.borne(x)
    }

    // MARK: Actions

    static func envoyer(_ r: MilieuRoute, produitId: String, lots: Int, mode: TransportMode, _ j: inout Joueur) -> String {
        guard accessible(j), let p = MilieuDonnees.produit(produitId), r.produits.contains(produitId) else { return "" }
        if j.vieEtat.justice.enPrison { return "Impossible depuis ta cellule." }
        if etat(j).cargaisons.count >= maxCargaisons { return "Tu as déjà \(maxCargaisons) cargaisons en route. Plus, et tu ne pourrais plus rien contrôler." }
        let n = min(max(lots, r.minLots), maxLots(r, j))
        let transport = coutTransport(r, mode)
        if r.estImport {
            guard let b = MilieuTrafic.business(j) else { return "" }
            if !b.lignes.contains(where: { $0.produitId == produitId }) {
                if b.lignes.count >= MilieuTrafic.maxLignes(j) {
                    return "Ton réseau ne vend pas de \(p.nom.lowercased()) et ne peut pas gérer une marchandise de plus."
                }
                _ = MilieuTrafic.ajouterProduit(p, &j)
            }
            let total = prixLot(r, p, j) * n + transport
            guard MilieuTrafic.payer(total, &j) else { return "Cette cargaison coûte \(Format.argent(total)), transport compris." }
            modifier(&j) { $0.cargaisons.append(VieCargaison(routeId: r.id, produitId: produitId, lots: n, mode: mode, montant: total)) }
            VieMilieu.modifier(&j) { $0.chaleur += 3 }
            return "Commande passée chez \(r.partenaire) : \(n) lot\(n > 1 ? "s" : "") de \(p.nom.lowercased()), \(mode.nom.lowercased()). \(Format.argent(total)) envolés. La marchandise arrivera l'an prochain. Si elle arrive."
        }
        guard let l = MilieuTrafic.business(j)?.lignes.first(where: { $0.produitId == produitId }), l.stock > 0 else {
            return "Tu n'as pas de \(p.nom.lowercased()) en stock à envoyer."
        }
        let envoyes = min(n, l.stock)
        guard MilieuTrafic.payer(transport, &j) else { return "Le transport coûte \(Format.argent(transport))." }
        let recette = prixLot(r, p, j) * envoyes
        MilieuTrafic.modifier(&j) { b, _ in
            if let i = b.lignes.firstIndex(where: { $0.produitId == produitId }) { b.lignes[i].stock -= envoyes }
        }
        modifier(&j) { $0.cargaisons.append(VieCargaison(routeId: r.id, produitId: produitId, lots: envoyes, mode: mode, montant: recette)) }
        VieMilieu.modifier(&j) { $0.chaleur += 3 }
        return "\(envoyes) lot\(envoyes > 1 ? "s" : "") de \(p.nom.lowercased()) partent pour \(r.region), \(mode.nom.lowercased()). \(capitale(r.partenaire)) promet \(Format.argent(recette)) à l'arrivée."
    }

    // MARK: +1 an

    static func vieillir(_ j: inout Joueur) -> [String] {
        let e = etat(j)
        guard !e.cargaisons.isEmpty else { return [] }
        var lignes: [String] = []
        for c in e.cargaisons {
            guard let r = route(c.routeId), let p = MilieuDonnees.produit(c.produitId) else { continue }
            let nom = p.nom.lowercased()
            if VieHasard.reussi(risque(r, c.mode, lots: c.lots, j)) {
                modifier(&j) { $0.saisies += 1; $0.confiance[r.id] = confiance(r.id, $0) - 12 }
                VieMilieu.modifier(&j) { $0.chaleur += 10 + min(20, c.lots) }
                VieSysteme.signaler("cargaison_saisie", &j)
                lignes.append(r.estImport
                    ? "Ta cargaison de \(nom) (\(c.lots) lot\(c.lots > 1 ? "s" : "")) a été saisie à la douane. \(Format.argent(c.montant)) perdus."
                    : "Ta cargaison de \(nom) pour \(r.region) a été saisie à la douane avant d'arriver.")
                if VieHasard.reussi(0.2 + Double(c.lots) / 50), VieMilieu.etat(j).enquete == nil {
                    VieMilieu.modifier(&j) { $0.enquete = 0 }
                    VieSysteme.signaler("enquete_ouverte", &j)
                    lignes.append("Les douanes remontent la filière. Ton nom apparaît dans leur rapport.")
                }
                continue
            }
            modifier(&j) { $0.livrees += 1; $0.confiance[r.id] = confiance(r.id, $0) + 6 }
            VieSysteme.signaler("cargaison_livree", &j)
            if r.estImport {
                let ok = MilieuTrafic.business(j)?.lignes.contains { $0.produitId == c.produitId } ?? false
                if ok {
                    MilieuTrafic.modifier(&j) { b, _ in
                        if let i = b.lignes.firstIndex(where: { $0.produitId == c.produitId }) { b.lignes[i].stock += c.lots }
                    }
                    lignes.append("Ta cargaison de \(nom) est arrivée : \(c.lots) lot\(c.lots > 1 ? "s" : "") de plus dans tes planques.")
                } else {
                    let reprise = c.lots * p.prixLot * 7 / 10
                    VieMilieu.modifier(&j) { $0.argentSale += reprise }
                    lignes.append("Ta cargaison de \(nom) est arrivée, mais tu n'as plus de réseau pour la vendre. Un grossiste la rachète \(Format.argent(reprise)).")
                }
            } else {
                VieMilieu.modifier(&j) { $0.argentSale += c.montant; $0.respect += 3 }
                lignes.append("\(capitale(r.partenaire)) a payé : \(Format.argent(c.montant)) d'argent sale pour ta cargaison de \(nom).")
            }
        }
        modifier(&j) { $0.cargaisons = [] }
        return lignes
    }

    // MARK: Tags, textes, effets

    static func tags(_ j: Joueur) -> Set<String> {
        guard let e = VieMilieu.etat(j).international else { return [] }
        var t: Set<String> = []
        if !e.cargaisons.isEmpty || e.livrees + e.saisies > 0 { t.insert("international") }
        if !e.cargaisons.isEmpty { t.insert("cargaison_en_route") }
        return t
    }

    /// Partenaire principal : celui de la cargaison en route, sinon celui en qui on a le plus confiance.
    static func partenairePrincipal(_ j: Joueur) -> String? {
        guard let e = VieMilieu.etat(j).international else { return nil }
        if let c = e.cargaisons.first { return route(c.routeId)?.partenaire }
        return route(e.confiance.max { $0.value < $1.value }?.key)?.partenaire
    }

    static func remplir(_ texte: String, _ j: Joueur) -> String {
        guard texte.contains("{etranger}") else { return texte }
        return texte.replacingOccurrences(of: "{etranger}", with: partenairePrincipal(j) ?? "tes fournisseurs étrangers")
    }

    static func appliquer(_ fx: VieEffets, _ j: inout Joueur) {
        guard VieMilieu.etat(j).international != nil else { return }
        if let d = fx.confianceEtranger, d != 0 {
            modifier(&j) { e in
                for k in e.confiance.keys { e.confiance[k] = (e.confiance[k] ?? 30) + d }
                for c in e.cargaisons where e.confiance[c.routeId] == nil { e.confiance[c.routeId] = 30 + d }
            }
        }
        if fx.cargaisonSaisie == true, !etat(j).cargaisons.isEmpty {
            modifier(&j) { $0.saisies += $0.cargaisons.count; $0.cargaisons = [] }
            VieSysteme.signaler("cargaison_saisie", &j)
        }
    }
}

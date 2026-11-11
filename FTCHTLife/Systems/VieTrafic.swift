import Foundation

// Le business du trafic : marchandises, prix, qualité du fournisseur, quartiers, concurrents,
// stratégie, revendeurs, sécurité, bilan annuel et décisions difficiles.
// Données : Data/MilieuZones, Data/MilieuConcurrents (+ Data/MilieuProduits). Appelé par VieMilieu.

// MARK: - Données

struct MilieuZone: Codable, Identifiable, Equatable {
    var id: String
    /// Avec l'article : « la cité des Tilleuls ».
    var nom: String
    var description: String
    /// Multiplicateur de demande.
    var taille: Double
    /// Présence policière (0…100).
    var police: Int
    /// Multiplicateur du prix que paient les clients.
    var prix: Double
    /// Coût pour s'implanter.
    var entree: Int
    var rangMin: Int
    var clientele: String
    var preferences: [String: Double]

    func preference(_ produitId: String) -> Double { preferences[produitId] ?? 1 }
}

struct MilieuConcurrent: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    /// agressif, discount, premium, discret
    var style: String
    var description: String
    var force: Int
    /// Écart de prix par rapport au marché, en %.
    var prix: Int
    var qualite: String
    /// Quartiers où il peut s'installer (vide = partout).
    var zones: [String]

    var styleTexte: String {
        switch style {
        case "agressif": return "Agressif"
        case "discount": return "Casse les prix"
        case "premium": return "Haut de gamme"
        case "discret": return "Discret"
        default: return style.capitalized
        }
    }
}

enum TraficDonnees {
    static let zones: [MilieuZone] = DonneesJSON.chargerTableaux(dossier: "MilieuZones", type: MilieuZone.self)
    static let concurrents: [MilieuConcurrent] = DonneesJSON.chargerTableaux(dossier: "MilieuConcurrents", type: MilieuConcurrent.self)

    static func zone(_ id: String?) -> MilieuZone? {
        guard let id else { return nil }
        return zones.first { $0.id == id }
    }

    static func concurrent(_ id: String?) -> MilieuConcurrent? {
        guard let id else { return nil }
        return concurrents.first { $0.id == id }
    }
}

// MARK: - Choix du joueur

enum TraficQualite: String, Codable, CaseIterable, Identifiable {
    case coupee, standard, premier

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .coupee: return "Fournisseur bas de gamme"
        case .standard: return "Fournisseur habituel"
        case .premier: return "Premier choix"
        }
    }

    var detail: String {
        switch self {
        case .coupee: return "20 % moins cher, clients moins fidèles, plus d'accidents"
        case .standard: return "Le prix normal, la qualité attendue"
        case .premier: return "50 % plus cher, les clients reviennent"
        }
    }

    /// Attrait pour les clients.
    var score: Double {
        switch self {
        case .coupee: return 0.7
        case .standard: return 1
        case .premier: return 1.35
        }
    }

    /// Multiplicateur du prix d'achat.
    var cout: Double {
        switch self {
        case .coupee: return 0.8
        case .standard: return 1
        case .premier: return 1.5
        }
    }
}

enum TraficStrategie: String, Codable, CaseIterable, Identifiable {
    case discret, equilibre, expansion, intimidation

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .discret: return "Discrétion"
        case .equilibre: return "Équilibre"
        case .expansion: return "Expansion"
        case .intimidation: return "Intimidation"
        }
    }

    var detail: String {
        switch self {
        case .discret: return "Moins de ventes, beaucoup moins d'attention de la police."
        case .equilibre: return "Ni trop, ni trop peu."
        case .expansion: return "Plus de points de vente, plus de clients, plus de risques."
        case .intimidation: return "Faire peur aux concurrents. Efficace, violent, très surveillé."
        }
    }

    var capacite: Double {
        switch self {
        case .discret: return 0.75
        case .equilibre: return 1
        case .expansion: return 1.3
        case .intimidation: return 1.05
        }
    }

    var attrait: Double {
        switch self {
        case .discret: return 0.9
        case .equilibre: return 1
        case .expansion: return 1.15
        case .intimidation: return 1.05
        }
    }

    var chaleur: Double {
        switch self {
        case .discret: return 0.55
        case .equilibre: return 1
        case .expansion: return 1.35
        case .intimidation: return 1.5
        }
    }

    var tension: Int {
        switch self {
        case .discret: return -10
        case .equilibre: return 0
        case .expansion: return 8
        case .intimidation: return 4
        }
    }
}

/// Niveaux de prix proposés au joueur (écart au prix du marché, en %).
enum TraficPrix {
    static let niveaux = [-30, -15, 0, 15, 30]

    static func nom(_ p: Int) -> String {
        switch p {
        case ..<(-20): return "Bradé (−30 %)"
        case ..<(-5): return "Sous le marché (−15 %)"
        case ...5: return "Prix du marché"
        case ...20: return "Au-dessus (+15 %)"
        default: return "Premium (+30 %)"
        }
    }
}

// MARK: - État sauvegardé

struct VieLigneTrafic: Codable, Equatable, Identifiable {
    var produitId: String
    var stock = 0
    var prix = 0
    var qualite: TraficQualite = .standard
    /// Lots vendus l'an dernier.
    var vendus = 0

    var id: String { produitId }
}

struct VieZoneTrafic: Codable, Equatable, Identifiable {
    var zoneId: String
    var concurrentId: String?
    var prixConcurrent = 0
    var forceConcurrent = 50
    /// Tension avec le concurrent (0…100).
    var tension = 0
    /// Part de marché de l'an dernier, en %.
    var part = 0
    /// Années de trêve restantes.
    var treve = 0

    var id: String { zoneId }
}

struct VieBilanTrafic: Codable, Equatable {
    var lotsVendus = 0
    var demande = 0
    var capacite = 0
    var chiffre = 0
    var salaires = 0
    var securite = 0
    var benefice = 0
}

/// Dilemme en attente de réponse du joueur.
struct VieDecisionTrafic: Codable, Equatable {
    var type: String
    var nom: String
    var montant: Int
    var zoneId: String?
    var autreId: String?
}

struct TraficBusiness: Codable, Equatable {
    var lignes: [VieLigneTrafic] = []
    var zones: [VieZoneTrafic] = []
    var strategie: TraficStrategie = .equilibre
    /// Guetteurs et planques (0…3).
    var securite = 0
    /// Fidélité des clients (0…100).
    var fidelite = 40
    /// Cours du marché par marchandise, écart en %.
    var cours: [String: Int] = [:]
    var bilan: VieBilanTrafic?
    var decision: VieDecisionTrafic?
    var lotsVendusTotal = 0

    var stockTotal: Int { lignes.reduce(0) { $0 + $1.stock } }
    func coursDe(_ produitId: String) -> Int { cours[produitId] ?? 0 }
}

// MARK: - Système

enum MilieuTrafic {

    /// Fixe annuel par revendeur, plus une commission sur les ventes.
    static let salaireRevendeur = 1_500
    static let commission = 12
    static let lotsParRevendeur = 4.0
    static let coutSecurite = 6_000

    // MARK: Accès

    static func business(_ j: Joueur) -> TraficBusiness? { VieMilieu.etat(j).trafic?.b }

    static func modifier(_ j: inout Joueur, _ f: (inout TraficBusiness, inout VieTrafic) -> Void) {
        VieMilieu.modifier(&j) { m in
            guard var t = m.trafic else { return }
            var b = t.b
            f(&b, &t)
            b.fidelite = Stats.borne(b.fidelite)
            b.securite = min(3, max(0, b.securite))
            for i in b.lignes.indices { b.lignes[i].stock = max(0, b.lignes[i].stock) }
            for i in b.zones.indices {
                b.zones[i].tension = Stats.borne(b.zones[i].tension)
                b.zones[i].forceConcurrent = Stats.borne(b.zones[i].forceConcurrent)
                b.zones[i].prixConcurrent = min(40, max(-40, b.zones[i].prixConcurrent))
            }
            t.reseau = max(0, t.reseau)
            t.b = b
            m.trafic = t
        }
    }

    /// Paie avec l'argent sale d'abord, puis l'argent propre. false si pas assez.
    static func payer(_ montant: Int, _ j: inout Joueur) -> Bool {
        let m = VieMilieu.etat(j)
        guard montant > 0 else { return true }
        guard m.argentSale + j.argent >= montant else { return false }
        let sale = min(m.argentSale, montant)
        j.argent -= montant - sale
        VieMilieu.modifier(&j) { $0.argentSale -= sale }
        return true
    }

    // MARK: Limites

    static func peutDealer(_ j: Joueur) -> Bool {
        let m = VieMilieu.etat(j)
        return j.age >= 14 && !m.balance && !j.vieEtat.justice.enPrison
    }

    static func maxLignes(_ j: Joueur) -> Int {
        let m = VieMilieu.etat(j)
        return m.membre ? min(4, 1 + m.rang) : 1
    }

    static func maxZones(_ j: Joueur) -> Int {
        let m = VieMilieu.etat(j)
        return m.membre ? min(6, 1 + m.rang + m.territoires) : 2
    }

    static func maxReseau(_ j: Joueur) -> Int {
        let m = VieMilieu.etat(j)
        return m.membre ? min(30, 4 + m.rang * 4 + m.territoires * 2) : 4
    }

    static func produitsAccessibles(_ j: Joueur) -> [MilieuProduit] {
        let m = VieMilieu.etat(j)
        let rang = m.membre ? max(1, m.rang) : 1
        let deja = Set(business(j)?.lignes.map(\.produitId) ?? [])
        return MilieuDonnees.produits
            .filter { $0.rangMin <= rang && !deja.contains($0.id) }
            .sorted { $0.prixLot < $1.prixLot }
    }

    static func zonesAccessibles(_ j: Joueur) -> [MilieuZone] {
        let m = VieMilieu.etat(j)
        let rang = m.membre ? m.rang : 0
        let deja = Set(business(j)?.zones.map(\.zoneId) ?? [])
        return TraficDonnees.zones
            .filter { $0.rangMin <= rang && !deja.contains($0.id) }
            .sorted { $0.entree < $1.entree }
    }

    // MARK: Prix

    static func prixMarche(_ p: MilieuProduit, _ b: TraficBusiness, zone: MilieuZone? = nil) -> Int {
        let base = Double(p.reventeMin + p.reventeMax) / 2
        return Int(base * (1 + Double(b.coursDe(p.id)) / 100) * (zone?.prix ?? 1))
    }

    static func prixAchat(_ p: MilieuProduit, _ q: TraficQualite, _ b: TraficBusiness) -> Int {
        Int(Double(p.prixLot) * q.cout * (1 + Double(b.coursDe(p.id)) / 200))
    }

    // MARK: Ouvrir, fermer

    static func nouvelleZone(_ z: MilieuZone) -> VieZoneTrafic {
        var e = VieZoneTrafic(zoneId: z.id)
        let possibles = TraficDonnees.concurrents.filter { $0.zones.isEmpty || $0.zones.contains(z.id) }
        if let c = possibles.randomElement() {
            e.concurrentId = c.id
            e.prixConcurrent = c.prix
            e.forceConcurrent = Stats.borne(c.force + Int.random(in: -10...10))
            e.tension = 15
        }
        return e
    }

    static func ouvrir(_ p: MilieuProduit, _ z: MilieuZone, _ j: inout Joueur) -> [String] {
        guard peutDealer(j) else { return ["Ce n'est pas possible pour toi en ce moment."] }
        if VieMilieu.etat(j).trafic != nil { return ["Tu as déjà un business."] }
        guard payer(z.entree, &j) else { return ["S'installer dans \(z.nom) coûte \(Format.argent(z.entree)) (planques, téléphones, premiers revendeurs)."] }
        var b = TraficBusiness()
        b.lignes = [VieLigneTrafic(produitId: p.id)]
        b.zones = [nouvelleZone(z)]
        let zoneEtat = b.zones[0]
        VieMilieu.modifier(&j) {
            $0.trafic = VieTrafic(produitId: p.id, lots: 0, reseau: 1, anneesActif: 0, business: b)
            $0.chaleur += 3
        }
        j.stats.karma -= 4
        j.stats.borner()
        VieSysteme.signaler("trafic_debut", &j)
        var l = ["Tu montes ton business de \(p.nom.lowercased()) dans \(z.nom). Un revendeur, un téléphone, une planque. Tout le reste reste à construire."]
        if let c = TraficDonnees.concurrent(zoneEtat.concurrentId) {
            l.append("Le marché est déjà tenu par \(c.nom). Ils vont vite savoir que tu es là.")
        }
        return l
    }

    static func fermer(_ j: inout Joueur) -> String {
        let stock = business(j)?.stockTotal ?? 0
        VieMilieu.modifier(&j) { $0.trafic = nil; $0.chaleur -= 10 }
        return stock > 0
            ? "Tu fermes ton business. Le stock restant disparaît dans la nuit, les téléphones aussi. Il faudra du temps pour que le quartier oublie ton visage."
            : "Tu fermes ton business. Les revendeurs se dispersent, les téléphones finissent dans la rivière."
    }

    // MARK: Marchandises

    static func ajouterProduit(_ p: MilieuProduit, _ j: inout Joueur) -> String {
        guard let b = business(j) else { return "" }
        if b.lignes.count >= maxLignes(j) {
            return VieMilieu.etat(j).membre
                ? "Ton rang ne te permet pas de gérer plus de \(maxLignes(j)) marchandise\(maxLignes(j) > 1 ? "s" : "")."
                : "Seul, tu ne peux pas gérer plus d'une marchandise. Il faudrait une organisation derrière toi."
        }
        modifier(&j) { b, _ in b.lignes.append(VieLigneTrafic(produitId: p.id)) }
        return "Tu ajoutes \(p.nom.lowercased()) à ce que vend ton réseau. Nouveaux fournisseurs, nouveaux clients, nouveaux risques."
    }

    static func retirerProduit(_ produitId: String, _ j: inout Joueur) -> String {
        guard let b = business(j), b.lignes.count > 1, let l = b.lignes.first(where: { $0.produitId == produitId }),
              let p = MilieuDonnees.produit(produitId) else { return "Il te faut au moins une marchandise. Sinon, ferme le business." }
        let reprise = l.stock * p.prixLot / 2
        modifier(&j) { b, _ in b.lignes.removeAll { $0.produitId == produitId } }
        VieMilieu.modifier(&j) { $0.argentSale += reprise }
        return reprise > 0
            ? "Tu arrêtes \(p.nom.lowercased()). Un grossiste te rachète le stock à moitié prix : \(Format.argent(reprise))."
            : "Tu arrêtes \(p.nom.lowercased())."
    }

    static func acheter(_ produitId: String, lots: Int, _ j: inout Joueur) -> String {
        guard let b = business(j), let l = b.lignes.first(where: { $0.produitId == produitId }),
              let p = MilieuDonnees.produit(produitId) else { return "" }
        if j.vieEtat.justice.enPrison { return "Impossible depuis ta cellule." }
        let total = prixAchat(p, l.qualite, b) * lots
        guard payer(total, &j) else { return "Il te faut \(Format.argent(total)) pour \(lots) lot\(lots > 1 ? "s" : "")." }
        modifier(&j) { b, _ in
            if let i = b.lignes.firstIndex(where: { $0.produitId == produitId }) { b.lignes[i].stock += lots }
        }
        VieMilieu.modifier(&j) { $0.chaleur += max(1, p.chaleur * lots / 8) }
        return "Tu récupères \(lots) lot\(lots > 1 ? "s" : "") de \(p.nom.lowercased()) pour \(Format.argent(total)). Il faut maintenant les stocker sans attirer l'attention."
    }

    static func fixerPrix(_ produitId: String, _ prix: Int, _ j: inout Joueur) {
        modifier(&j) { b, _ in
            if let i = b.lignes.firstIndex(where: { $0.produitId == produitId }) { b.lignes[i].prix = prix }
        }
    }

    static func choisirQualite(_ produitId: String, _ q: TraficQualite, _ j: inout Joueur) -> String? {
        if q == .premier {
            let m = VieMilieu.etat(j)
            if !m.membre || m.rang < 2 {
                return "Les fournisseurs de premier choix ne traitent qu'avec les organisations établies (rang 3 et plus)."
            }
        }
        modifier(&j) { b, _ in
            if let i = b.lignes.firstIndex(where: { $0.produitId == produitId }) { b.lignes[i].qualite = q }
        }
        return nil
    }

    // MARK: Organisation

    static func choisirStrategie(_ s: TraficStrategie, _ j: inout Joueur) {
        modifier(&j) { b, _ in b.strategie = s }
    }

    static func choisirSecurite(_ n: Int, _ j: inout Joueur) {
        modifier(&j) { b, _ in b.securite = n }
    }

    static func recruter(_ j: inout Joueur) -> String {
        guard let t = VieMilieu.etat(j).trafic else { return "" }
        if t.reseau >= maxReseau(j) {
            return VieMilieu.etat(j).membre
                ? "Ton rang et tes territoires ne permettent pas plus de \(maxReseau(j)) revendeurs."
                : "Seul, tu ne peux pas tenir plus de \(maxReseau(j)) revendeurs. Au-delà, il faut une organisation."
        }
        let cout = 1_500 + 1_000 * t.reseau
        guard payer(cout, &j) else { return "Recruter un revendeur coûte \(Format.argent(cout))." }
        let nom = VieDonnees.prenom(Bool.random() ? .homme : .femme)
        modifier(&j) { _, t in t.reseau += 1 }
        VieMilieu.modifier(&j) { $0.chaleur += 3 }
        return "\(nom) rejoint ton réseau. Plus de ventes, et une bouche de plus qui peut parler."
    }

    static func licencier(_ j: inout Joueur) -> String {
        guard let t = VieMilieu.etat(j).trafic, t.reseau > 0 else { return "Tu n'as plus de revendeurs." }
        modifier(&j) { _, t in t.reseau -= 1 }
        if VieHasard.reussi(0.12) {
            VieMilieu.modifier(&j) { $0.chaleur += 10 }
            return "Tu te sépares d'un revendeur. Il est parti en claquant la porte, et il sait beaucoup de choses."
        }
        return "Tu te sépares d'un revendeur. Il prend l'argent que tu lui tends et disparaît."
    }

    // MARK: Quartiers

    static func ouvrirZone(_ z: MilieuZone, _ j: inout Joueur) -> [String] {
        guard let b = business(j) else { return [] }
        if b.zones.count >= maxZones(j) { return ["Tu ne peux pas tenir plus de \(maxZones(j)) quartiers avec tes moyens actuels."] }
        guard payer(z.entree, &j) else { return ["S'installer dans \(z.nom) coûte \(Format.argent(z.entree))."] }
        let e = nouvelleZone(z)
        modifier(&j) { b, _ in b.zones.append(e) }
        VieMilieu.modifier(&j) { $0.chaleur += 5; $0.respect += 3 }
        VieSysteme.signaler("trafic_zone", &j)
        var l = ["Tes revendeurs s'installent dans \(z.nom)."]
        if let c = TraficDonnees.concurrent(e.concurrentId) { l.append("\(capitale(c.nom)) tient déjà le terrain. La cohabitation ne sera pas simple.") }
        return l
    }

    static func quitterZone(_ zoneId: String, _ j: inout Joueur) -> String {
        guard let b = business(j), b.zones.count > 1 else { return "C'est ton dernier quartier. Pour partir, ferme le business." }
        modifier(&j) { b, _ in b.zones.removeAll { $0.zoneId == zoneId } }
        return "Tu retires tes revendeurs de \(TraficDonnees.zone(zoneId)?.nom ?? "ce quartier")."
    }

    static func negocier(_ zoneId: String, _ j: inout Joueur) -> String {
        guard let b = business(j), let z = b.zones.first(where: { $0.zoneId == zoneId }),
              let c = TraficDonnees.concurrent(z.concurrentId) else { return "" }
        let cle = "trf_neg_\(zoneId)"
        if VieMilieu.etat(j).actionsAnnee.contains(cle) { return "Tu as déjà proposé une trêve cette année. Insister serait un aveu de faiblesse." }
        VieMilieu.modifier(&j) { $0.actionsAnnee.append(cle) }
        let respect = VieMilieu.etat(j).respect
        let chance = VieHasard.borne(0.35 + Double(respect - z.forceConcurrent) / 150 + (c.style == "discret" ? 0.2 : 0) - (c.style == "agressif" ? 0.15 : 0))
        if VieHasard.reussi(chance) {
            modifier(&j) { b, _ in
                if let i = b.zones.firstIndex(where: { $0.zoneId == zoneId }) {
                    b.zones[i].treve = 3; b.zones[i].tension = 0; b.zones[i].prixConcurrent = 0
                }
            }
            return "Rendez-vous dans l'arrière-salle d'un restaurant fermé. Avec \(c.nom), vous vous mettez d'accord : chacun ses rues, les mêmes prix, pas de sang. Pour trois ans. En théorie."
        }
        modifier(&j) { b, _ in
            if let i = b.zones.firstIndex(where: { $0.zoneId == zoneId }) { b.zones[i].tension += 15 }
        }
        VieMilieu.modifier(&j) { $0.respect -= 3 }
        return "\(capitale(c.nom)) refuse de te recevoir. Le message est passé : pour eux, tu n'es pas un interlocuteur."
    }

    static func intimider(_ zoneId: String, _ j: inout Joueur) -> [String] {
        guard let b = business(j), let z = b.zones.first(where: { $0.zoneId == zoneId }),
              let c = TraficDonnees.concurrent(z.concurrentId), let t = VieMilieu.etat(j).trafic else { return [] }
        let cle = "trf_int_\(zoneId)"
        if VieMilieu.etat(j).actionsAnnee.contains(cle) { return ["Tu as déjà envoyé un message cette année dans ce quartier."] }
        VieMilieu.modifier(&j) { $0.actionsAnnee.append(cle) }
        let m = VieMilieu.etat(j)
        j.stats.karma -= 6
        let chance = VieHasard.borne(0.4 + Double(m.respect - z.forceConcurrent) / 120 + Double(t.reseau) * 0.02 + (m.membre ? 0.1 : 0))
        VieMilieu.modifier(&j) { $0.chaleur += 8 }
        if VieHasard.reussi(chance) {
            modifier(&j) { b, _ in
                if let i = b.zones.firstIndex(where: { $0.zoneId == zoneId }) {
                    b.zones[i].forceConcurrent -= Int.random(in: 15...30); b.zones[i].tension += 15
                }
            }
            VieMilieu.modifier(&j) { $0.respect += 6 }
            j.stats.borner()
            return ["Un point de vente de chez \(c.nom) est retourné en pleine nuit. Personne n'est blessé, mais tout le quartier a compris qui monte."]
        }
        modifier(&j) { b, _ in
            if let i = b.zones.firstIndex(where: { $0.zoneId == zoneId }) { b.zones[i].tension += 30 }
        }
        j.stats.sante -= Int.random(in: 8...25)
        j.stats.borner()
        return ["Ils t'attendaient. Tes hommes ont pris la fuite, toi tu as pris les coups. Chez \(c.nom), on rit encore de toi."]
    }

    static func racheter(_ zoneId: String, _ j: inout Joueur) -> String {
        guard let b = business(j), let z = b.zones.first(where: { $0.zoneId == zoneId }),
              let c = TraficDonnees.concurrent(z.concurrentId) else { return "" }
        let prix = coutRachat(z)
        guard z.forceConcurrent <= 40 else { return "\(capitale(c.nom)) est encore trop fort pour accepter de vendre. Affaiblis-le d'abord." }
        guard payer(prix, &j) else { return "Racheter la clientèle coûte \(Format.argent(prix))." }
        modifier(&j) { b, t in
            if let i = b.zones.firstIndex(where: { $0.zoneId == zoneId }) {
                b.zones[i].concurrentId = nil; b.zones[i].tension = 0; b.zones[i].forceConcurrent = 0
            }
            t.reseau += 1
            b.fidelite += 5
        }
        VieMilieu.modifier(&j) { $0.respect += 8 }
        return "\(capitale(c.nom)) te cède ses clients, ses planques et un revendeur pour \(Format.argent(prix)). Le quartier est à toi. Pour l'instant."
    }

    static func coutRachat(_ z: VieZoneTrafic) -> Int { 20_000 + z.forceConcurrent * 1_500 }

    // MARK: Effets d'événements, saisie

    static func saisir(_ j: inout Joueur) {
        modifier(&j) { b, _ in for i in b.lignes.indices { b.lignes[i].stock = 0 } }
    }

    static func appliquer(_ fx: VieEffets, _ j: inout Joueur) {
        guard VieMilieu.etat(j).trafic != nil else { return }
        modifier(&j) { b, t in
            b.fidelite += fx.clients ?? 0
            t.reseau = max(0, t.reseau + (fx.revendeurs ?? 0))
            if let d = fx.tension { for i in b.zones.indices { b.zones[i].tension += d } }
            if let s = fx.stock, !b.lignes.isEmpty {
                let i = s < 0 ? (b.lignes.indices.max { b.lignes[$0].stock < b.lignes[$1].stock } ?? 0) : 0
                b.lignes[i].stock += s
            }
        }
    }

    // MARK: Tags, textes

    static func tags(_ j: Joueur) -> Set<String> {
        let m = VieMilieu.etat(j)
        guard let t = m.trafic else { return [] }
        let b = t.b
        var s: Set<String> = []
        if t.reseau >= 6 || (b.bilan?.lotsVendus ?? 0) >= 12 { s.insert("dealer_gros") }
        if b.zones.contains(where: { $0.tension >= 60 && $0.concurrentId != nil }) { s.insert("guerre_prix") }
        if !b.lignes.isEmpty && b.stockTotal == 0 { s.insert("rupture_stock") }
        if !m.membre { s.insert("independant") }
        if t.reseau >= 1 { s.insert("a_revendeurs") }
        if let p = b.lignes.first?.produitId, ["cannabis", "ecstasy", "cocaine", "heroine", "medicaments_detournes"].contains(p) { s.insert("produit_drogue") }
        return s
    }

    static func remplir(_ texte: String, _ j: Joueur) -> String {
        guard texte.contains("{") else { return texte }
        let b = business(j)
        let p = MilieuDonnees.produit(b?.lignes.first?.produitId)
        let z = b?.zones.max { $0.tension < $1.tension }
        var t = texte
        t = t.replacingOccurrences(of: "{produit}", with: p?.nom.lowercased() ?? "la marchandise")
        t = t.replacingOccurrences(of: "{zone}", with: TraficDonnees.zone(z?.zoneId)?.nom ?? "le quartier")
        t = t.replacingOccurrences(of: "{concurrent}", with: TraficDonnees.concurrent(z?.concurrentId)?.nom ?? "la concurrence")
        return t
    }

    // MARK: +1 an

    static func vieillir(_ j: inout Joueur) -> [String] {
        guard let t0 = VieMilieu.etat(j).trafic else { return [] }
        var lignes: [String] = []
        let enPrison = j.vieEtat.justice.enPrison
        var b = t0.b
        // Ancien format : pas de quartier, on en donne un.
        if b.zones.isEmpty, let z = TraficDonnees.zone("cite_tilleuls") ?? TraficDonnees.zones.first {
            b.zones = [nouvelleZone(z)]
        }
        // Décision ignorée : elle se règle toute seule, rarement bien.
        if let d = b.decision {
            modifier(&j) { b2, _ in b2 = b; b2.decision = nil }
            lignes.append("Tu n'as rien décidé. D'autres l'ont fait pour toi.")
            lignes += TraficDecisions.resoudre(d, choix: TraficDecisions.defaut(d.type), &j)
            guard let t1 = VieMilieu.etat(j).trafic else { return lignes }
            b = t1.b
        }
        if enPrison {
            // En prison, le réseau s'effrite.
            modifier(&j) { b2, t in
                b2 = b
                b2.fidelite -= 15
                if t.reseau > 0 && VieHasard.reussi(0.5) { t.reseau -= 1 }
                for i in b2.lignes.indices where VieHasard.reussi(0.4) { b2.lignes[i].stock = max(0, b2.lignes[i].stock - 1) }
            }
            lignes.append("Sans toi, ton réseau tourne au ralenti. Des revendeurs partent, du stock disparaît.")
            return lignes
        }
        let t = VieMilieu.etat(j).trafic ?? t0

        // 1. Demande et parts de marché, case par case (marchandise × quartier).
        struct Case { var li: Int; var zi: Int; var voulu: Double; var part: Double; var demande: Double }
        var cases: [Case] = []
        for (li, l) in b.lignes.enumerated() {
            guard let p = MilieuDonnees.produit(l.produitId) else { continue }
            let attrait = l.qualite.score * pow(1 + Double(l.prix) / 100, -2.2) * (0.5 + Double(b.fidelite) / 100) * b.strategie.attrait
            for (zi, ze) in b.zones.enumerated() {
                guard let z = TraficDonnees.zone(ze.zoneId) else { continue }
                let demande = (p.demandeBase ?? 2) * z.taille * z.preference(p.id) * Double.random(in: 0.8...1.2) * (1 - Double(b.coursDe(p.id)) / 200)
                var rival = 0.35
                if ze.treve > 0 {
                    rival = attrait
                } else if let c = TraficDonnees.concurrent(ze.concurrentId) {
                    let q = TraficQualite(rawValue: c.qualite)?.score ?? 1
                    rival = q * pow(1 + Double(ze.prixConcurrent) / 100, -2.2) * (0.4 + Double(ze.forceConcurrent) / 100)
                }
                let part = attrait / (attrait + rival)
                cases.append(Case(li: li, zi: zi, voulu: demande * part, part: part, demande: demande))
            }
        }
        // 2. Capacité du réseau, puis stock disponible.
        let profilBas = MilieuProtection.etat(j).profilBas
        let capacite = Double(t.reseau) * lotsParRevendeur * b.strategie.capacite * (profilBas ? 0.35 : 1)
        let totalVoulu = cases.reduce(0.0) { $0 + $1.voulu }
        let facteurCapacite = totalVoulu > 0 ? min(1, capacite / totalVoulu) : 0
        var vendus = Array(repeating: 0, count: cases.count)
        var chiffre = 0
        var chaleur = 0.0
        var rupture = false
        for li in b.lignes.indices {
            let idx = cases.indices.filter { cases[$0].li == li }
            let voulu = idx.reduce(0.0) { $0 + cases[$1].voulu * facteurCapacite }
            let stock = Double(b.lignes[li].stock)
            if voulu > stock + 0.5 { rupture = true }
            let facteurStock = voulu > 0 ? min(1, stock / voulu) : 0
            var reste = b.lignes[li].stock
            for k in idx {
                let x = cases[k].voulu * facteurCapacite * facteurStock
                var n = Int(x)
                if Double.random(in: 0..<1) < x - Double(n) { n += 1 }
                n = min(n, reste)
                reste -= n
                vendus[k] = n
            }
            b.lignes[li].vendus = b.lignes[li].stock - reste
            b.lignes[li].stock = reste
        }
        for (k, c) in cases.enumerated() where vendus[k] > 0 {
            let l = b.lignes[c.li]
            guard let p = MilieuDonnees.produit(l.produitId), let z = TraficDonnees.zone(b.zones[c.zi].zoneId) else { continue }
            chiffre += vendus[k] * Int(Double(prixMarche(p, b, zone: z)) * (1 + Double(l.prix) / 100))
            chaleur += Double(vendus[k] * p.chaleur) * Double(z.police) / 60 / 4
        }
        // Parts de marché par quartier (pondérées par la demande).
        for zi in b.zones.indices {
            let cz = cases.filter { $0.zi == zi }
            let d = cz.reduce(0.0) { $0 + $1.demande }
            b.zones[zi].part = d > 0 ? Int(cz.reduce(0.0) { $0 + $1.part * $1.demande } / d * 100) : 0
        }
        let lotsVendus = vendus.reduce(0, +)
        let salaires = t.reseau * salaireRevendeur + chiffre * commission / 100
        let securite = b.securite * coutSecurite * b.zones.count
        let benefice = chiffre - salaires - securite
        b.bilan = VieBilanTrafic(lotsVendus: lotsVendus, demande: Int(cases.reduce(0.0) { $0 + $1.demande }), capacite: Int(capacite),
                                 chiffre: chiffre, salaires: salaires, securite: securite, benefice: benefice)
        b.lotsVendusTotal += lotsVendus

        // 3. Clients : qualité, prix, ruptures.
        let poids = max(1, b.lignes.reduce(0) { $0 + $1.vendus })
        let qualiteMoy = b.lignes.reduce(0.0) { $0 + $1.qualite.score * Double(max(1, $1.vendus)) } / Double(max(poids, b.lignes.count))
        let prixMoy = b.lignes.reduce(0) { $0 + $1.prix * max(1, $1.vendus) } / max(poids, b.lignes.count)
        b.fidelite += Int((qualiteMoy - 1) * 30) - prixMoy / 6 + (rupture ? -8 : 3)

        // 4. Cours du marché.
        for p in MilieuDonnees.produits {
            var c = b.coursDe(p.id)
            c += Int.random(in: -12...12) - c / 4
            if let l = b.lignes.first(where: { $0.produitId == p.id }), l.vendus >= 15 { c -= 5 }
            b.cours[p.id] = min(40, max(-40, c))
        }

        // 5. Concurrents.
        var guerre = false
        var incidents: [String] = []
        for zi in b.zones.indices {
            var z = b.zones[zi]
            let nomZone = TraficDonnees.zone(z.zoneId)?.nom ?? "ton quartier"
            if z.treve > 0 {
                z.treve -= 1
                z.tension -= 15
                if z.treve == 0 { incidents.append("La trêve dans \(nomZone) arrive à son terme. Personne ne parle de la renouveler.") }
            } else if let c = TraficDonnees.concurrent(z.concurrentId) {
                z.tension += b.strategie.tension - 6
                if prixMoy < z.prixConcurrent - 10 { z.tension += 15 }
                if z.part > 55 {
                    z.tension += 10
                    switch c.style {
                    case "discount": z.prixConcurrent -= Int.random(in: 5...10)
                    case "agressif": z.forceConcurrent += 8; z.tension += 10
                    case "premium": z.forceConcurrent += 3
                    default: z.forceConcurrent -= 2
                    }
                } else if z.part < 25 {
                    z.prixConcurrent += 5
                    z.forceConcurrent += 3
                }
                if b.strategie == .intimidation { z.forceConcurrent -= Int.random(in: 3...8) }
                z.tension = Stats.borne(z.tension)
                if z.tension >= 60 { guerre = true }
                if z.tension >= 70 && VieHasard.reussi(0.45) {
                    let nom = capitale(c.nom)
                    switch Int.random(in: 0..<3) {
                    case 0:
                        if t.reseau > 0 {
                            incidents.append("Dans \(nomZone), un de tes revendeurs a été passé à tabac par les hommes de chez \(c.nom). Il ne reviendra pas travailler.")
                            modifierReseau(-1, &b, &j)
                        }
                    case 1:
                        if let li = b.lignes.indices.filter({ b.lignes[$0].stock > 0 }).randomElement() {
                            let n = min(b.lignes[li].stock, Int.random(in: 1...2))
                            b.lignes[li].stock -= n
                            incidents.append("\(nom) a trouvé une de tes planques. \(n) lot\(n > 1 ? "s" : "") envolé\(n > 1 ? "s" : "").")
                        }
                    default:
                        b.fidelite -= 10
                        chaleur += 8
                        incidents.append("Ton point de vente principal dans \(nomZone) a brûlé dans la nuit. Les clients ont peur de revenir.")
                    }
                    z.tension -= 15
                }
                z.forceConcurrent = Stats.borne(z.forceConcurrent)
                if z.forceConcurrent <= 8 {
                    incidents.append("\(capitale(c.nom)) a quitté \(nomZone). Ses clients sont à prendre.")
                    z.concurrentId = nil
                    z.tension = 0
                }
            } else if VieHasard.reussi(0.12), let z0 = TraficDonnees.zone(z.zoneId) {
                let n = nouvelleZone(z0)
                if let c = TraficDonnees.concurrent(n.concurrentId) {
                    z.concurrentId = n.concurrentId
                    z.prixConcurrent = n.prixConcurrent
                    z.forceConcurrent = n.forceConcurrent
                    z.tension = 20
                    incidents.append("Un nouveau concurrent s'installe dans \(nomZone) : \(c.nom).")
                }
            }
            z.prixConcurrent = min(40, max(-40, z.prixConcurrent))
            b.zones[zi] = z
        }

        // 6. Bilan.
        chaleur = chaleur * b.strategie.chaleur * (profilBas ? 0.5 : 1) - Double(b.securite * 3)
        let deltaChaleur = min(25, max(-6, Int(chaleur)))
        let respect = min(5, lotsVendus / 4)
        modifier(&j) { b2, t in b2 = b; t.anneesActif += 1 }
        VieMilieu.modifier(&j) {
            $0.argentSale += benefice
            $0.chaleur += deltaChaleur
            $0.respect += respect
        }
        if lotsVendus > 0 {
            lignes.append("Bilan de ton business : \(lotsVendus) lot\(lotsVendus > 1 ? "s" : "") vendu\(lotsVendus > 1 ? "s" : ""), \(Format.argent(chiffre)) de chiffre, \(Format.argent(benefice)) une fois les revendeurs payés.")
        } else if b.stockTotal == 0 {
            lignes.append("Ton business n'a rien vendu cette année : pas de marchandise. Les revendeurs sont payés à attendre, et les clients vont voir ailleurs.")
        }
        if VieMilieu.etat(j).argentSale == 0 && benefice < 0 {
            modifier(&j) { _, t in t.reseau = max(0, t.reseau - 1) }
            lignes.append("Tu n'as pas pu payer tout le monde. Un revendeur est parti, en emportant ce qu'il savait.")
        }
        if rupture && lotsVendus > 0 { lignes.append("Tu as manqué de marchandise : des clients sont partis chez la concurrence.") }
        lignes += incidents
        if guerre { VieSysteme.signaler("trafic_guerre_prix", &j) }

        // Descente de police sur les planques.
        let policeMoy = Double(b.zones.compactMap { TraficDonnees.zone($0.zoneId)?.police }.reduce(0, +)) / Double(max(1, b.zones.count))
        let risqueDescente = Double(VieMilieu.etat(j).chaleur) / 400 * policeMoy / 60 * (1 - 0.15 * Double(b.securite)) * MilieuProtection.facteurDescente(j)
        if (business(j)?.stockTotal ?? 0) > 0 && VieHasard.reussi(risqueDescente) {
            if MilieuProtection.etat(j).policiers > 0 && VieHasard.reussi(0.5) {
                lignes.append("Un de tes policiers t'a prévenu la veille : descente dans une de tes planques. Quand la brigade arrive, il n'y a plus rien.")
            } else {
                saisir(&j)
                VieMilieu.modifier(&j) { $0.chaleur += 10 }
                VieSysteme.signaler("trafic_saisie", &j)
                lignes.append("Descente de la brigade des stupéfiants dans tes planques. Tout ton stock est saisi. Personne n'a parlé. Pour l'instant.")
            }
        }

        // 7. Un dilemme, au plus, par an.
        if let d = TraficDecisions.tirer(&j) {
            modifier(&j) { b2, _ in b2.decision = d }
            lignes.append("Une décision t'attend dans ton business.")
        }
        return lignes
    }

    private static func modifierReseau(_ delta: Int, _ b: inout TraficBusiness, _ j: inout Joueur) {
        let copie = b
        modifier(&j) { b2, t in b2 = copie; t.reseau = max(0, t.reseau + delta) }
    }
}

// MARK: - Dilemmes

struct TraficOption {
    let label: String
    let detail: String
}

enum TraficDecisions {

    static let types = ["revendeur_arrete", "vol_interne", "overdose", "penurie", "gros_client", "flic_ripou", "mineurs", "taxe", "partage"]

    /// Option choisie si le joueur laisse passer l'année sans répondre.
    static func defaut(_ type: String) -> Int {
        switch type {
        case "revendeur_arrete": return 1
        case "vol_interne": return 2
        case "overdose": return 1
        case "penurie": return 2
        case "gros_client": return 1
        case "flic_ripou": return 1
        case "mineurs": return 1
        case "taxe": return 1
        case "partage": return 2
        default: return 0
        }
    }

    static func titre(_ d: VieDecisionTrafic) -> String {
        switch d.type {
        case "revendeur_arrete": return "\(d.nom) est en garde à vue"
        case "vol_interne": return "Il manque de la marchandise"
        case "overdose": return "Une overdose dans le quartier"
        case "penurie": return "Ton fournisseur augmente ses prix"
        case "gros_client": return "Un acheteur veut une grosse quantité"
        case "flic_ripou": return "Un policier te fait une offre"
        case "mineurs": return "Des gamins veulent travailler pour toi"
        case "taxe": return "\(MilieuDonnees.organisation(d.autreId)?.nom ?? "Une organisation") réclame sa part"
        case "partage": return "\(cap(TraficDonnees.concurrent(d.autreId)?.nom ?? "Ton concurrent")) propose un accord"
        default: return "Décision"
        }
    }

    static func texte(_ d: VieDecisionTrafic) -> String {
        let zone = TraficDonnees.zone(d.zoneId)?.nom ?? "ton quartier"
        switch d.type {
        case "revendeur_arrete":
            return "\(d.nom), un de tes revendeurs, a été arrêté dans \(zone) avec de la marchandise sur lui. Il n'a encore rien dit. Un bon avocat coûte \(Format.argent(d.montant))."
        case "vol_interne":
            return "Les comptes ne tombent pas juste. Tout désigne \(d.nom), un revendeur. Il a pris pour environ \(Format.argent(d.montant)). Le reste du réseau attend de voir ce que tu vas faire."
        case "overdose":
            return "Un jeune de \(zone) a fait une overdose. Il a survécu, de justesse. Ce qu'il a pris venait de chez toi. Sa mère a fait le tour du quartier avec sa photo."
        case "penurie":
            return "Ton fournisseur de \(MilieuDonnees.produit(d.autreId)?.nom.lowercased() ?? "marchandise") te prévient : les prix montent. Il te demande \(Format.argent(d.montant)) de plus pour continuer à te servir. Un nouveau contact propose de le remplacer, sans références."
        case "gros_client":
            return "Un homme bien habillé veut acheter trois lots d'un coup, pour \(Format.argent(d.montant)) en liquide. C'est beaucoup d'argent, et tu ne le connais pas."
        case "flic_ripou":
            return "Un policier de la brigade locale t'aborde à la sortie d'un café. Pour \(Format.argent(d.montant)) par an, il te prévient des descentes et fait disparaître quelques rapports."
        case "mineurs":
            return "\(d.nom), un de tes revendeurs, veut faire travailler des gamins de treize ou quatorze ans comme guetteurs. Ils coûtent moins cher et ne risquent presque rien devant un juge. Toi, si."
        case "taxe":
            return "Des hommes de chez \(MilieuDonnees.organisation(d.autreId)?.nom ?? "une organisation") viennent te voir. Tu vends sur leur territoire, sans leur permission. Ils veulent \(Format.argent(d.montant)) par an. Ou que tu les rejoignes."
        case "partage":
            return "Chez \(TraficDonnees.concurrent(d.autreId)?.nom ?? "ton concurrent"), on en a assez de la guerre dans \(zone). Ils proposent un partage : chacun ses rues, les mêmes prix, pendant trois ans."
        default:
            return ""
        }
    }

    static func options(_ d: VieDecisionTrafic) -> [TraficOption] {
        switch d.type {
        case "revendeur_arrete":
            return [TraficOption(label: "Payer son avocat", detail: Format.argent(d.montant) + ", il te restera fidèle"),
                    TraficOption(label: "L'abandonner", detail: "Il risque de parler"),
                    TraficOption(label: "Lui faire passer un message", detail: "Il se taira. Par peur.")]
        case "vol_interne":
            return [TraficOption(label: "Le renvoyer", detail: "Un revendeur en moins"),
                    TraficOption(label: "Faire un exemple", detail: "Le réseau comprendra. La police aussi, peut-être."),
                    TraficOption(label: "Passer l'éponge", detail: "Les autres pourraient se servir à leur tour")]
        case "overdose":
            return [TraficOption(label: "Retirer le lot de la vente", detail: "Tu perds du stock, les clients te respectent"),
                    TraficOption(label: "Continuer comme si de rien n'était", detail: "Ce n'est pas ton problème. Vraiment ?"),
                    TraficOption(label: "Payer l'hôpital anonymement", detail: "Ta conscience, contre un risque d'être reconnu")]
        case "penurie":
            return [TraficOption(label: "Payer le prix fort", detail: Format.argent(d.montant)),
                    TraficOption(label: "Prendre le nouveau contact", detail: "Moins cher. Mais qui est-il ?"),
                    TraficOption(label: "Attendre que ça passe", detail: "Le marché va monter, tes clients vont attendre")]
        case "gros_client":
            return [TraficOption(label: "Accepter", detail: "Trois lots, beaucoup d'argent"),
                    TraficOption(label: "Refuser", detail: "Trop beau pour être vrai"),
                    TraficOption(label: "Le tester avec un seul lot", detail: "Moins d'argent, moins de risque")]
        case "flic_ripou":
            return [TraficOption(label: "Payer", detail: Format.argent(d.montant) + ", moins de descentes"),
                    TraficOption(label: "Refuser poliment", detail: "Il ne sera pas content")]
        case "mineurs":
            return [TraficOption(label: "Accepter", detail: "Plus de capacité, une ligne que tu franchis"),
                    TraficOption(label: "Refuser", detail: "Pas d'enfants dans ton business"),
                    TraficOption(label: "Renvoyer le revendeur", detail: "Pour qu'il ne le fasse pas dans ton dos")]
        case "taxe":
            return [TraficOption(label: "Payer", detail: Format.argent(d.montant) + " par an, la paix"),
                    TraficOption(label: "Refuser", detail: "Tu es chez toi. Eux ne pensent pas pareil."),
                    TraficOption(label: "Demander à les rejoindre", detail: "Moins de liberté, plus de protection")]
        case "partage":
            return [TraficOption(label: "Accepter le partage", detail: "Trois ans de paix, des prix alignés"),
                    TraficOption(label: "Exiger qu'ils partent", detail: "Tout ou rien"),
                    TraficOption(label: "Ne pas répondre", detail: "La guerre continue")]
        default:
            return []
        }
    }

    // MARK: Tirage

    static func tirer(_ j: inout Joueur) -> VieDecisionTrafic? {
        let m = VieMilieu.etat(j)
        guard let t = m.trafic else { return nil }
        let b = t.b
        let zoneId = b.zones.randomElement()?.zoneId
        let police = Double(b.zones.compactMap { TraficDonnees.zone($0.zoneId)?.police }.reduce(0, +)) / Double(max(1, b.zones.count))
        let prenom = VieDonnees.prenom(Bool.random() ? .homme : .femme)
        var possibles: [(Double, VieDecisionTrafic)] = []
        if t.reseau > 0 {
            let p = 0.03 * Double(t.reseau) * police / 60 * (1 - 0.2 * Double(b.securite)) * b.strategie.chaleur
            possibles.append((p, VieDecisionTrafic(type: "revendeur_arrete", nom: prenom, montant: 6_000 + 4_000 * m.rang, zoneId: zoneId)))
            let vol = 0.04 + 0.01 * Double(t.reseau) - Double(b.fidelite) / 2000
            if let l = b.lignes.first(where: { $0.stock > 0 }), let p2 = MilieuDonnees.produit(l.produitId) {
                possibles.append((vol, VieDecisionTrafic(type: "vol_interne", nom: prenom, montant: p2.prixLot, zoneId: zoneId, autreId: p2.id)))
            }
        }
        let dangereux = ["heroine", "cocaine", "medicaments_detournes", "ecstasy"]
        if let l = b.lignes.first(where: { dangereux.contains($0.produitId) && $0.vendus > 0 }) {
            let p = 0.05 * (l.qualite == .coupee ? 2.2 : l.qualite == .premier ? 0.6 : 1)
            possibles.append((p, VieDecisionTrafic(type: "overdose", nom: "", montant: 0, zoneId: zoneId, autreId: l.produitId)))
        }
        if let l = b.lignes.randomElement(), let p = MilieuDonnees.produit(l.produitId) {
            possibles.append((0.08, VieDecisionTrafic(type: "penurie", nom: "", montant: p.prixLot * 2, autreId: p.id)))
        }
        if t.reseau >= 5 || (b.bilan?.lotsVendus ?? 0) >= 10, let l = b.lignes.max(by: { $0.stock < $1.stock }), l.stock >= 3,
           let p = MilieuDonnees.produit(l.produitId) {
            possibles.append((0.12, VieDecisionTrafic(type: "gros_client", nom: "", montant: MilieuTrafic.prixMarche(p, b) * 3 * 13 / 10, autreId: p.id)))
        }
        if m.chaleur >= 35 {
            possibles.append((0.12, VieDecisionTrafic(type: "flic_ripou", nom: "", montant: 15_000 + m.chaleur * 500)))
        }
        if t.reseau >= 3 {
            possibles.append((0.05, VieDecisionTrafic(type: "mineurs", nom: prenom, montant: 0)))
        }
        if !m.membre, let org = MilieuDonnees.organisations.filter({ $0.notorieteMin <= 40 && !m.anciennesOrganisations.contains($0.id) }).randomElement() {
            let montant = max(5_000, (b.bilan?.chiffre ?? 0) / 4)
            possibles.append((0.3, VieDecisionTrafic(type: "taxe", nom: "", montant: montant, zoneId: zoneId, autreId: org.id)))
        }
        if let z = b.zones.first(where: { $0.tension >= 50 && $0.concurrentId != nil && $0.treve == 0 }) {
            possibles.append((0.2, VieDecisionTrafic(type: "partage", nom: "", montant: 0, zoneId: z.zoneId, autreId: z.concurrentId)))
        }
        for (p, d) in possibles.shuffled() where VieHasard.reussi(p) {
            if d.type == "revendeur_arrete" { VieSysteme.signaler("trafic_revendeur_arrete", &j) }
            if d.type == "overdose" {
                VieSysteme.signaler("trafic_overdose", &j)
                j.stats.bonheur -= 6
                j.stats.borner()
            }
            if d.type == "vol_interne", let id = d.autreId {
                MilieuTrafic.modifier(&j) { b, _ in
                    if let i = b.lignes.firstIndex(where: { $0.produitId == id }) { b.lignes[i].stock -= 1 }
                }
            }
            return d
        }
        return nil
    }

    // MARK: Résolution

    static func repondre(_ choix: Int, _ j: inout Joueur) -> [String] {
        guard let d = MilieuTrafic.business(j)?.decision else { return [] }
        MilieuTrafic.modifier(&j) { b, _ in b.decision = nil }
        return resoudre(d, choix: choix, &j)
    }

    static func resoudre(_ d: VieDecisionTrafic, choix: Int, _ j: inout Joueur) -> [String] {
        func chaleur(_ n: Int) { VieMilieu.modifier(&j) { $0.chaleur += n } }
        func respect(_ n: Int) { VieMilieu.modifier(&j) { $0.respect += n } }
        func fidelite(_ n: Int) { MilieuTrafic.modifier(&j) { b, _ in b.fidelite += n } }
        func reseau(_ n: Int) { MilieuTrafic.modifier(&j) { _, t in t.reseau = max(0, t.reseau + n) } }
        func enquete() -> [String] {
            if VieMilieu.etat(j).enquete == nil {
                VieMilieu.modifier(&j) { $0.enquete = 0 }
                VieSysteme.signaler("enquete_ouverte", &j)
                return ["Une enquête est ouverte sur ton réseau."]
            }
            return []
        }
        switch (d.type, choix) {
        case ("revendeur_arrete", 0):
            if !MilieuTrafic.payer(d.montant, &j) {
                reseau(-1)
                return ["Tu n'avais pas de quoi payer l'avocat. \(d.nom) a pris deux ans. Il ne te le pardonnera pas."] + (VieHasard.reussi(0.4) ? enquete() : [])
            }
            respect(4)
            fidelite(3)
            if VieHasard.reussi(0.5) {
                return ["L'avocat trouve un vice de procédure. \(d.nom) ressort au bout de 48 heures. Dans le réseau, on sait désormais que tu ne laisses tomber personne."]
            }
            reseau(-1)
            return ["Malgré l'avocat, \(d.nom) prend dix-huit mois. Il a tenu sa langue. Il s'en souviendra, à sa sortie."]
        case ("revendeur_arrete", 1):
            reseau(-1)
            respect(-3)
            if VieHasard.reussi(0.45) {
                chaleur(15)
                return ["Seul, sans avocat, \(d.nom) a fini par parler. Des noms, des adresses."] + enquete()
            }
            return ["\(d.nom) a pris sa peine sans un mot. Mais tout le réseau a vu que tu l'avais laissé tomber."]
        case ("revendeur_arrete", _):
            reseau(-1)
            j.stats.karma -= 12
            j.stats.borner()
            chaleur(6)
            respect(5)
            return ["Un message est arrivé jusqu'à sa cellule, avec une photo de la maison de sa mère. \(d.nom) n'a rien dit. Toi, tu as du mal à te regarder dans la glace."]

        case ("vol_interne", 0):
            reseau(-1)
            return ["Tu renvoies \(d.nom) sans un mot. Il part avec ce qu'il a pris, et une rancune de plus dans le quartier."]
        case ("vol_interne", 1):
            j.stats.karma -= 10
            j.stats.borner()
            respect(6)
            reseau(-1)
            fidelite(-3)
            if VieHasard.reussi(0.25) {
                chaleur(12)
                return ["\(d.nom) a fini aux urgences. Les médecins ont posé des questions. La police aussi."]
            }
            return ["Ce qui est arrivé à \(d.nom) a fait le tour du réseau. Plus personne ne se servira dans la caisse. Plus personne ne te regarde de la même façon non plus."]
        case ("vol_interne", _):
            respect(-5)
            MilieuTrafic.modifier(&j) { b, _ in
                if let i = b.lignes.indices.max(by: { b.lignes[$0].stock < b.lignes[$1].stock }) { b.lignes[i].stock -= 1 }
            }
            return ["Tu passes l'éponge. Quelques semaines plus tard, il manque encore de la marchandise. Ta patience est devenue une faiblesse connue."]

        case ("overdose", 0):
            MilieuTrafic.modifier(&j) { b, _ in
                if let id = d.autreId, let i = b.lignes.firstIndex(where: { $0.produitId == id }) { b.lignes[i].stock = b.lignes[i].stock / 2 }
            }
            fidelite(8)
            j.stats.karma += 4
            j.stats.borner()
            return ["Tu fais retirer tout le lot de la vente, à perte. Dans le quartier, on dit que tu n'es pas comme les autres. Ce n'est pas tout à fait faux."]
        case ("overdose", 1):
            j.stats.karma -= 8
            j.stats.bonheur -= 6
            j.stats.borner()
            fidelite(-10)
            chaleur(10)
            if VieHasard.reussi(0.3) {
                j.stats.karma -= 6
                j.stats.borner()
                return ["Une deuxième overdose, deux semaines plus tard. Celle-là n'a pas survécu. Les journaux en parlent. Les enquêteurs aussi."] + enquete()
            }
            return ["Tu continues à vendre. Le gamin s'en est sorti. Tu te répètes que ce n'est pas ta faute."]
        case ("overdose", _):
            guard MilieuTrafic.payer(5_000, &j) else { return ["Tu n'as même pas de quoi aider. Tu restes avec ça sur la conscience."] }
            j.stats.karma += 6
            j.stats.borner()
            if VieHasard.reussi(0.2) {
                chaleur(10)
                return ["Tu règles les frais d'hôpital en liquide, sans laisser de nom. Une infirmière a pourtant retenu ton visage."]
            }
            return ["Tu règles les frais d'hôpital en liquide, sans laisser de nom. Ça ne répare rien. Mais tu dors un peu mieux."]

        case ("penurie", 0):
            if !MilieuTrafic.payer(d.montant, &j) {
                fidelite(-10)
                return ["Tu n'as pas de quoi payer. Ton fournisseur sert quelqu'un d'autre en priorité."]
            }
            return ["Tu paies. Ton fournisseur te garde parmi ses clients prioritaires. Tes marges fondent, mais tes clients ne voient rien."]
        case ("penurie", 1):
            if VieHasard.reussi(0.2) {
                chaleur(20)
                MilieuTrafic.saisir(&j)
                VieSysteme.signaler("trafic_saisie", &j)
                return ["Le nouveau contact travaillait pour les stups. La première livraison était une souricière. Tu as perdu ton stock, et la police a ton visage."] + enquete()
            }
            MilieuTrafic.modifier(&j) { b, _ in
                if let id = d.autreId, let i = b.lignes.firstIndex(where: { $0.produitId == id }) { b.lignes[i].qualite = .coupee }
            }
            fidelite(-5)
            return ["Le nouveau contact livre à l'heure, pas cher. Mais la qualité baisse. Les clients s'en rendent compte."]
        case ("penurie", _):
            MilieuTrafic.modifier(&j) { b, _ in
                if let id = d.autreId { b.cours[id] = min(40, b.coursDe(id) + 20) }
            }
            fidelite(-8)
            return ["Tu attends. Le marché, lui, n'attend pas : les prix s'envolent et tes clients cherchent ailleurs."]

        case ("gros_client", 0):
            guard let id = d.autreId, let l = MilieuTrafic.business(j)?.lignes.first(where: { $0.produitId == id }), l.stock >= 3 else {
                return ["Tu n'as plus assez de stock. L'acheteur repart sans rien."]
            }
            MilieuTrafic.modifier(&j) { b, _ in
                if let i = b.lignes.firstIndex(where: { $0.produitId == id }) { b.lignes[i].stock -= 3 }
            }
            if VieHasard.reussi(VieBonus.arrestation(0.22)) {
                let p = MilieuDonnees.produit(id)
                let mois = Int.random(in: (p?.peineMinMois ?? 12)...max(p?.peineMinMois ?? 12, p?.peineMaxMois ?? 36))
                return VieMilieu.arreter("trafic de stupéfiants", mois: mois, texte: "L'homme bien habillé sort une carte tricolore. Six policiers surgissent du parking. C'était un piège.", &j)
            }
            VieMilieu.modifier(&j) { $0.argentSale += d.montant; $0.respect += 5; $0.chaleur += 8 }
            return ["La transaction se passe dans un parking souterrain. Trois lots, \(Format.argent(d.montant)) en billets usagés. Tu ne sauras jamais pour qui il travaillait."]
        case ("gros_client", 1):
            return ["Tu refuses. Plus tard, tu apprends qu'un autre a accepté. Tu ne sais pas encore si tu as eu de la chance ou peur."]
        case ("gros_client", _):
            guard let id = d.autreId else { return [] }
            if VieHasard.reussi(0.1) {
                chaleur(15)
                return ["Il prend le lot et paie. Une semaine plus tard, ton revendeur remarque une voiture banalisée. Le test, c'était lui qui le faisait."] + enquete()
            }
            MilieuTrafic.modifier(&j) { b, _ in
                if let i = b.lignes.firstIndex(where: { $0.produitId == id }) { b.lignes[i].stock -= 1 }
            }
            VieMilieu.modifier(&j) { $0.argentSale += d.montant / 3 }
            fidelite(3)
            return ["Un lot, payé rubis sur l'ongle. Il reviendra peut-être. Peut-être pas."]

        case ("flic_ripou", 0):
            guard MilieuTrafic.payer(d.montant, &j) else { return ["Tu n'as pas de quoi le payer. Il hausse les épaules : « Dommage. »"] }
            VieMilieu.modifier(&j) { $0.chaleur -= 25 }
            if VieHasard.reussi(0.15) {
                return ["Il est fiable, pendant un temps. Puis l'inspection générale s'intéresse à lui, et à ceux qui le payent."] + enquete()
            }
            return ["Désormais, un SMS anonyme arrive la veille de chaque descente. C'est de l'argent bien dépensé. Tant qu'il ne se fait pas prendre."]
        case ("flic_ripou", _):
            chaleur(8)
            return ["Tu refuses. Il sourit, range ses mains dans ses poches. Les contrôles dans ton quartier se multiplient le mois suivant."]

        case ("mineurs", 0):
            j.stats.karma -= 15
            j.stats.borner()
            reseau(2)
            chaleur(10)
            return ["Des gamins de treize ans surveillent désormais tes halls. Ils sont rapides, efficaces, et tu évites de croiser leur regard."]
        case ("mineurs", 1):
            j.stats.karma += 3
            j.stats.borner()
            return ["« Pas d'enfants. » \(d.nom) hausse les épaules. Tu n'es pas sûr qu'il t'ait écouté."]
        case ("mineurs", _):
            reseau(-1)
            j.stats.karma += 5
            j.stats.borner()
            return ["Tu renvoies \(d.nom). Tu as tes limites. Le quartier le saura."]

        case ("taxe", 0):
            guard MilieuTrafic.payer(d.montant, &j) else {
                MilieuTrafic.saisir(&j)
                return ["Tu n'as pas de quoi payer. On te laisse un mois. Le mois suivant, ta planque est vide."]
            }
            MilieuTrafic.modifier(&j) { b, _ in for i in b.zones.indices { b.zones[i].tension -= 20 } }
            return ["Tu paies. Une partie de ton travail finira dans la poche des autres. En échange, personne ne te touche."]
        case ("taxe", 1):
            respect(5)
            if VieHasard.reussi(0.45) {
                j.stats.sante -= Int.random(in: 15...35)
                j.stats.borner()
                MilieuTrafic.modifier(&j) { b, t in
                    if let i = b.lignes.indices.max(by: { b.lignes[$0].stock < b.lignes[$1].stock }) { b.lignes[i].stock = 0 }
                    t.reseau = max(0, t.reseau - 1)
                }
                return ["Leur réponse arrive une semaine plus tard, dans une cage d'escalier. Tu t'en sors avec des points de suture. Ta planque, elle, a été vidée."]
            }
            return ["Tu refuses, et tu tiens. Pour l'instant, ils n'ont rien fait. Pour l'instant."]
        case ("taxe", _):
            guard let org = MilieuDonnees.organisation(d.autreId) else { return [] }
            return [VieMilieu.rejoindre(org, &j)]

        case ("partage", 0):
            MilieuTrafic.modifier(&j) { b, _ in
                if let i = b.zones.firstIndex(where: { $0.zoneId == d.zoneId }) {
                    b.zones[i].treve = 3; b.zones[i].tension = 0; b.zones[i].prixConcurrent = 0
                }
                for i in b.lignes.indices { b.lignes[i].prix = max(0, b.lignes[i].prix) }
            }
            return ["Vous vous serrez la main dans une voiture garée sur un parking de supermarché. Trois ans de paix. Il faudra respecter la parole donnée."]
        case ("partage", 1):
            let m = VieMilieu.etat(j)
            guard let z = MilieuTrafic.business(j)?.zones.first(where: { $0.zoneId == d.zoneId }) else { return [] }
            if VieHasard.reussi(VieHasard.borne(0.3 + Double(m.respect - z.forceConcurrent) / 100)) {
                MilieuTrafic.modifier(&j) { b, _ in
                    if let i = b.zones.firstIndex(where: { $0.zoneId == d.zoneId }) { b.zones[i].concurrentId = nil; b.zones[i].tension = 0 }
                }
                respect(10)
                return ["Ils ont cédé. Le quartier est à toi. Ils ne l'oublieront pas."]
            }
            MilieuTrafic.modifier(&j) { b, _ in
                if let i = b.zones.firstIndex(where: { $0.zoneId == d.zoneId }) { b.zones[i].tension = 100 }
            }
            respect(-4)
            return ["Ta réponse les a humiliés. Dans le quartier, tout le monde sent que quelque chose va arriver."]
        case ("partage", _):
            MilieuTrafic.modifier(&j) { b, _ in
                if let i = b.zones.firstIndex(where: { $0.zoneId == d.zoneId }) { b.zones[i].tension += 10 }
            }
            return ["Tu laisses leur offre sans réponse. Ils prennent ça pour un refus."]
        default:
            return []
        }
    }

    private static func cap(_ s: String) -> String { capitale(s) }
}

/// Première lettre en majuscule (« les frères Haddad » → « Les frères Haddad »).
func capitale(_ s: String) -> String { s.prefix(1).uppercased() + String(s.dropFirst()) }

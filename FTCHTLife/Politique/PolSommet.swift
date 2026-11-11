import Foundation

// Sommet de l'État : décrets (signés sans vote, effets sur le pays et sur la vie du joueur),
// scène internationale (relations pays par pays, visites d'État, traités, sanctions, aide, conflits)
// et tableau de bord du pays. Données : Data/Politique/Decrets/*.json, dossiers kind "international" et "guerre".
// Format : docs/POLITIQUE.md, section « Sommet de l'État ».

// MARK: - Modèles

/// Décret signé par le chef de l'exécutif (Data/Politique/Decrets/*.json).
struct PolDecret: Codable, Identifiable, Equatable {
    var id: String
    /// economie, social, securite, ecologie, institutions, international, urgence.
    var domaine: String
    var titre: String
    var description: String
    /// Influence dépensée pour le signer.
    var cout: Int
    /// Chance que la justice l'annule (0-0.8).
    var contestation: Double?
    /// Restreint les libertés : plus efficace, mais coûte en intégrité et en relations internationales.
    var autoritaire: Bool?
    /// Années en vigueur (absent = jusqu'à abrogation).
    var duree: Int?
    var effets: PolEffets
    /// Effets politiques chaque année tant qu'il est en vigueur.
    var annuel: PolEffets?
    /// Effets immédiats sur la vie du joueur.
    var vie: Effets?
    /// Effets sur la vie du joueur chaque année tant qu'il est en vigueur.
    var annuelVie: Effets?
    var prix: [String: Double]?
    var salaires: [String: Double]?
    var regles: [String: Double]?
    var tag: String?
    /// Postes qui peuvent le signer (absent = chef de l'exécutif).
    var postes: [String]?
    var pays: [String]?
    var headline: String
    var texte: String
    var texteAnnulation: String?
}

struct PolDecretActif: Codable, Equatable {
    var id: String
    var anneesRestantes: Int?
}

/// Types d'accords entre deux pays.
enum PolTraiteType: String, Codable, CaseIterable, Identifiable {
    case commerce, defense, climat, energie, migration, etudiants

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .commerce: return "Accord de libre-échange"
        case .defense: return "Pacte de défense"
        case .climat: return "Accord climatique"
        case .energie: return "Partenariat énergétique"
        case .migration: return "Accord migratoire"
        case .etudiants: return "Échanges universitaires"
        }
    }

    var icone: String {
        switch self {
        case .commerce: return "shippingbox.fill"
        case .defense: return "shield.lefthalf.filled"
        case .climat: return "leaf.fill"
        case .energie: return "bolt.fill"
        case .migration: return "person.2.fill"
        case .etudiants: return "graduationcap.fill"
        }
    }

    var description: String {
        switch self {
        case .commerce: return "Croissance, mais les agriculteurs grincent"
        case .defense: return "Sécurité et poids diplomatique, tension avec les autres"
        case .climat: return "Les jeunes applaudissent, l'industrie paie"
        case .energie: return "Énergie moins chère, dette allégée"
        case .migration: return "Main-d'œuvre et contrôles, débat garanti"
        case .etudiants: return "Rayonnement et jeunesse, à petit prix"
        }
    }

    /// Effets à la signature.
    var signature: PolEffets {
        var p = PolEffets()
        switch self {
        case .commerce: p.segments = ["patrons": 5, "ruraux": -5]; p.popularite = 1
        case .defense: p.pays = ["securite": 4]; p.tension = 4; p.influenceMondiale = 3
        case .climat: p.segments = ["jeunes": 6, "patrons": -3]; p.influenceMondiale = 3
        case .energie: p.pays = ["moral": 2]; p.segments = ["patrons": 3]
        case .migration: p.segments = ["patrons": 4, "ruraux": -3]; p.mobilisation = 3
        case .etudiants: p.segments = ["jeunes": 4]; p.influenceMondiale = 2
        }
        return p
    }

    /// Effets chaque année tant que l'accord tient.
    var annuel: PolEffets {
        var p = PolEffets()
        switch self {
        case .commerce: p.pays = ["croissance": 0.2, "chomage": -0.1]
        case .defense: p.pays = ["securite": 1, "dette": 0.3]
        case .climat: p.pays = ["moral": 1, "croissance": -0.05]
        case .energie: p.pays = ["croissance": 0.1, "dette": -0.3]
        case .migration: p.pays = ["chomage": -0.1, "securite": 1]
        case .etudiants: p.influenceMondiale = 1
        }
        return p
    }
}

struct PolTraite: Codable, Equatable, Identifiable {
    var id = UUID()
    var type: PolTraiteType
    var pays: String
    var age: Int
}

/// Scène internationale du joueur.
struct PolInternational: Codable, Equatable {
    /// Relation avec chaque pays (-100 à 100), clé = id du pays. Absent = relation de départ calculée.
    var relations: [String: Int] = [:]
    /// Tension internationale (0-100).
    var tension: Int = 30
    /// Poids du pays sur la scène mondiale (0-100).
    var influenceMondiale: Int = 30
    var traites: [PolTraite] = []
    /// Pays visés par des sanctions.
    var sanctions: [String] = []
    /// Pays avec lequel un conflit armé est en cours.
    var conflit: String?
    var anneesConflit: Int = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        relations = try c.decodeIfPresent([String: Int].self, forKey: .relations) ?? [:]
        tension = try c.decodeIfPresent(Int.self, forKey: .tension) ?? 30
        influenceMondiale = try c.decodeIfPresent(Int.self, forKey: .influenceMondiale) ?? 30
        traites = try c.decodeIfPresent([PolTraite].self, forKey: .traites) ?? []
        sanctions = try c.decodeIfPresent([String].self, forKey: .sanctions) ?? []
        conflit = try c.decodeIfPresent(String.self, forKey: .conflit)
        anneesConflit = try c.decodeIfPresent(Int.self, forKey: .anneesConflit) ?? 0
    }

    mutating func borner() {
        tension = Stats.borne(tension)
        influenceMondiale = Stats.borne(influenceMondiale)
        for k in relations.keys { relations[k] = min(100, max(-100, relations[k] ?? 0)) }
    }
}

extension PolCatalogue {
    static let decrets: [PolDecret] = DonneesJSON.chargerTableaux(dossier: "Politique/Decrets", type: PolDecret.self)
    private static let decretsParId: [String: PolDecret] = Dictionary(decrets.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    static func decret(_ id: String) -> PolDecret? { decretsParId[id] }
}

// MARK: - Décrets

extension PolMoteur {

    static let decretsParAn = 2

    /// Le joueur dirige l'exécutif et peut signer des décrets.
    static func peutDecreter(_ j: Joueur, _ e: PolEtat) -> Bool {
        guard let m = e.mandat else { return false }
        let s = systeme(j)
        switch m.poste {
        case .president: return !s.presidentSymbolique || s.estPartiUnique
        case .premierMinistre: return true
        default: return false
        }
    }

    static func decretsRestants(_ j: Joueur) -> Int {
        decretsParAn - (1...decretsParAn).filter { dejaFaitCetteAnnee("decret_\($0)", j) }.count
    }

    static func decretsDisponibles(_ j: Joueur, _ e: PolEtat) -> [PolDecret] {
        guard peutDecreter(j, e), let m = e.mandat else { return [] }
        let pays = systeme(j).id
        let actifs = Set(e.decrets.map { $0.id })
        return PolCatalogue.decrets.filter { d in
            !actifs.contains(d.id) && (d.pays ?? [pays]).contains(pays) && (d.postes ?? [m.poste.rawValue]).contains(m.poste.rawValue)
        }
    }

    /// Chance que la justice annule le décret, selon le régime.
    static func risqueAnnulation(_ d: PolDecret, _ j: Joueur, _ e: PolEtat) -> Double {
        let s = systeme(j)
        var r = d.contestation ?? 0
        if s.estPartiUnique || s.electionsControlees == true { r *= 0.2 }
        if e.majorite >= 60 { r *= 0.8 }
        return min(0.8, max(0, r))
    }

    static func signerDecret(_ id: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let d = PolCatalogue.decret(id), decretsDisponibles(j, e).contains(where: { $0.id == id }) else {
            return PolResultat(texte: "Tu ne peux pas signer ce décret.")
        }
        guard e.influence >= d.cout else {
            return PolResultat(texte: "Il te manque du capital politique : ce décret demande \(d.cout) d'influence, tu en as \(e.influence).")
        }
        guard let n = (1...decretsParAn).first(where: { !dejaFaitCetteAnnee("decret_\($0)", j) }), marquer("decret_\(n)", &j) else {
            return PolResultat(texte: "Tu as déjà signé \(decretsParAn) décrets cette année. Un de plus, et on parlerait de gouvernement par ordonnances.")
        }
        let s = systeme(j)
        e.influence -= d.cout
        if Double.random(in: 0...1) < risqueAnnulation(d, j, e) {
            e.influence -= 2
            e.popularite -= 1
            e.borner()
            e.titres.append("La justice suspend le décret « \(d.titre) »")
            return PolResultat(texte: "⚖️ « \(d.titre) » : saisie en urgence, la justice suspend ton décret. " + remplir(d.texteAnnulation ?? "Le texte ne s'appliquera pas. L'opposition savoure.", j, e))
        }
        appliquerPol(d.effets, &j, &e)
        if let v = d.vie { appliquerSimple(v, &j) }
        if d.autoritaire == true {
            e.casseroles += 4
            if !(s.estPartiUnique || s.electionsControlees == true) { e.mobilisation += 8 }
            changerRelations(-3, &e)
        }
        let durable = d.duree != nil || d.annuel != nil || d.annuelVie != nil || d.prix != nil
            || d.salaires != nil || d.regles != nil || d.tag != nil
        e.decrets.append(PolDecretActif(id: d.id, anneesRestantes: durable ? d.duree : 1))
        e.titres.append(remplir(d.headline, j, e))
        e.borner()
        let resume = resumeEffets(d.effets)
        return PolResultat(texte: "🖋️ Décret signé : « \(d.titre) ». " + remplir(d.texte, j, e) + (resume.isEmpty ? "" : "\n\n" + resume))
    }

    /// Décrets en vigueur que le joueur peut abroger.
    static func decretsAbrogeables(_ j: Joueur, _ e: PolEtat) -> [PolDecret] {
        guard peutDecreter(j, e) else { return [] }
        return e.decrets.compactMap { PolCatalogue.decret($0.id) }
    }

    static func abrogerDecret(_ id: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard let d = PolCatalogue.decret(id), decretsAbrogeables(j, e).contains(where: { $0.id == id }) else {
            return PolResultat(texte: "Tu ne peux pas abroger ce décret.")
        }
        guard marquer("decret_abroger", &j) else { return PolResultat(texte: "Tu as déjà abrogé un décret cette année.") }
        e.decrets.removeAll { $0.id == id }
        e.popularite -= (d.effets.popularite ?? 0) / 2
        if d.autoritaire == true { e.casseroles -= 3; changerRelations(2, &e) }
        e.borner()
        e.titres.append("Le décret « \(d.titre) » est abrogé")
        return PolResultat(texte: "🗑️ Tu abroges « \(d.titre) ». Le texte cesse de s'appliquer dès sa publication.")
    }

    /// Effets annuels des décrets en vigueur et échéances.
    static func anneeDecrets(_ j: inout Joueur, _ e: inout PolEtat, _ l: inout [String]) {
        var restants: [PolDecretActif] = []
        for var a in e.decrets {
            guard let d = PolCatalogue.decret(a.id) else { continue }
            if let p = d.annuel { appliquerPol(p, &j, &e) }
            if let v = d.annuelVie { appliquerSimple(v, &j) }
            if let r = a.anneesRestantes {
                a.anneesRestantes = r - 1
                if r - 1 <= 0 {
                    if r > 1 || d.duree != nil { l.append("⌛ Le décret « \(d.titre) » arrive à échéance.") }
                    continue
                }
            }
            restants.append(a)
        }
        e.decrets = restants
    }

    /// Résumé lisible des effets d'un texte sur le pays et l'opinion.
    static func resumeEffets(_ p: PolEffets) -> String {
        var t: [String] = []
        func signe(_ x: Int) -> String { x > 0 ? "+\(x)" : "\(x)" }
        func signe1(_ x: Double) -> String { (x > 0 ? "+" : "") + format1(x) }
        if let v = p.popularite, v != 0 { t.append("popularité \(signe(v))") }
        if let v = p.influence, v != 0 { t.append("influence \(signe(v))") }
        let noms = ["croissance": "croissance", "chomage": "chômage", "dette": "dette", "securite": "sécurité", "moral": "moral"]
        for k in ["croissance", "chomage", "dette", "securite", "moral"] {
            if let v = p.pays?[k], v != 0 {
                let nom: String = noms[k] ?? k
                let valeur: String
                if k == "securite" || k == "moral" {
                    valeur = signe(Int(v))
                } else {
                    valeur = signe1(v) + (k == "dette" ? " pts" : " pt")
                }
                t.append(nom + " " + valeur)
            }
        }
        if let v = p.mobilisation, v != 0 { t.append("colère sociale \(signe(v))") }
        if let v = p.relations, v != 0 { t.append("relations internationales \(signe(v))") }
        if let v = p.influenceMondiale, v != 0 { t.append("poids mondial \(signe(v))") }
        if let v = p.tension, v != 0 { t.append("tension \(signe(v))") }
        for (k, v) in (p.segments ?? [:]).sorted(by: { $0.key < $1.key }) where v != 0 {
            if let s = PolSegment(rawValue: k) { t.append("\(s.nom.lowercased()) \(signe(v))") }
        }
        return t.isEmpty ? "" : "Effets : " + t.joined(separator: ", ") + "."
    }
}

// MARK: - Scène internationale

extension PolMoteur {

    /// Le joueur conduit la diplomatie (chef de l'exécutif, ministre des Affaires étrangères).
    static func peutDiplomatie(_ j: Joueur, _ e: PolEtat) -> Bool {
        if peutDecreter(j, e) { return true }
        return e.mandat?.poste == .ministre && e.mandat?.ministereId == "affaires_etrangeres"
    }

    /// Visites d'État possibles (aussi pour un chef d'État symbolique, qui représente le pays).
    static func peutVisiter(_ j: Joueur, _ e: PolEtat) -> Bool {
        peutDiplomatie(j, e) || e.mandat?.poste == .president
    }

    /// Les autres pays du jeu.
    static func autresPays(_ e: PolEtat) -> [String] {
        let ici = e.paysId ?? "fr"
        return PolCatalogue.systemes.map { $0.id }.filter { $0 != ici }
    }

    /// Relation de départ : même union, régimes proches, et une part d'histoire propre à chaque paire.
    static func relationInitiale(_ id: String, _ e: PolEtat) -> Int {
        let a = PolCatalogue.systeme(e.paysId)
        let b = PolCatalogue.systeme(id)
        var r = 15
        if let ua = a.union?.first, ua == b.union?.first { r += 25 }
        let fermeA = a.estPartiUnique || a.electionsControlees == true
        let fermeB = b.estPartiUnique || b.electionsControlees == true
        if fermeA != fermeB { r -= 25 }
        let cle = [a.id, b.id].sorted().joined()
        let h = cle.unicodeScalars.reduce(7) { ($0 * 31 + Int($1.value)) % 9973 }
        return r + h % 31 - 15
    }

    static func relation(_ id: String, _ e: PolEtat) -> Int {
        e.international.relations[id] ?? relationInitiale(id, e)
    }

    static func changerRelation(_ id: String, _ delta: Int, _ e: inout PolEtat) {
        e.international.relations[id] = min(100, max(-100, relation(id, e) + delta))
    }

    static func changerRelations(_ delta: Int, _ e: inout PolEtat) {
        for id in autresPays(e) { changerRelation(id, delta, &e) }
    }

    /// Pays le moins ami (ou celui du conflit en cours).
    static func paysCible(_ e: PolEtat) -> String? {
        if let c = e.international.conflit { return c }
        return autresPays(e).min { relation($0, e) < relation($1, e) }
    }

    /// Meilleur allié.
    static func paysAllie(_ e: PolEtat) -> String? {
        let cible = paysCible(e)
        return autresPays(e).filter { $0 != cible }.max { relation($0, e) < relation($1, e) }
    }

    static func nomPays(_ id: String) -> String { PolCatalogue.systeme(id).nomPays }

    static func drapeau(_ id: String) -> String { ExpatCatalogue.shared.trouverPays(id)?.drapeau ?? "🏳️" }

    /// Nom du pays avec majuscule (« La Turquie »), pour un début de phrase.
    static func nomPaysMaj(_ id: String) -> String {
        let n = nomPays(id)
        return n.prefix(1).uppercased() + String(n.dropFirst())
    }

    /// Remplace {pays_cible}, {au_pays_cible}, {du_pays_cible}, {pays_allie}…
    static func remplirDiplomatie(_ texte: String, _ e: PolEtat) -> String {
        var t = texte
        if t.contains("_cible}") {
            let s = PolCatalogue.systeme(paysCible(e) ?? "us")
            t = t.replacingOccurrences(of: "{au_pays_cible}", with: s.auPays)
                .replacingOccurrences(of: "{du_pays_cible}", with: s.duPays)
                .replacingOccurrences(of: "{pays_cible}", with: s.nomPays)
        }
        if t.contains("_allie}") {
            let s = PolCatalogue.systeme(paysAllie(e) ?? "de")
            t = t.replacingOccurrences(of: "{au_pays_allie}", with: s.auPays)
                .replacingOccurrences(of: "{du_pays_allie}", with: s.duPays)
                .replacingOccurrences(of: "{pays_allie}", with: s.nomPays)
        }
        return t
    }

    /// Clés `pol` de la scène internationale.
    static func appliquerInternational(_ p: PolEffets, _ j: inout Joueur, _ e: inout PolEtat) {
        e.international.tension += p.tension ?? 0
        e.international.influenceMondiale += p.influenceMondiale ?? 0
        if let d = p.relationCible, d != 0, let c = paysCible(e) { changerRelation(c, d, &e) }
        if let d = p.relationAllie, d != 0, let a = paysAllie(e) { changerRelation(a, d, &e) }
        if let d = p.relations, d != 0 { changerRelations(d, &e) }
        if p.conflit == 1, e.international.conflit == nil, let c = paysCible(e) {
            e.international.conflit = c
            e.international.anneesConflit = 0
            e.international.relations[c] = min(relation(c, e), -80)
            e.international.tension += 25
            e.international.traites.removeAll { $0.pays == c }
            e.titres.append("Conflit armé avec \(nomPays(c))")
            ajouterLigne(&j, "⚔️ Le conflit avec \(nomPays(c)) a commencé. Chaque année de guerre pèsera sur le pays (onglet Politique).")
        } else if p.conflit == -1, let c = e.international.conflit {
            terminerConflit(c, &j, &e)
        }
        e.international.borner()
    }

    static func terminerConflit(_ c: String, _ j: inout Joueur, _ e: inout PolEtat) {
        e.international.conflit = nil
        e.international.anneesConflit = 0
        e.international.tension -= 20
        changerRelation(c, 20, &e)
        e.titres.append("Cessez-le-feu avec \(nomPays(c))")
        ajouterLigne(&j, "🕊️ Cessez-le-feu avec \(nomPays(c)). Le pays respire, les familles attendent leurs soldats.")
    }

    // MARK: Actions

    static func empechementDiplomatie(_ pays: String, _ j: Joueur, _ e: PolEtat) -> String? {
        guard peutDiplomatie(j, e) else { return "Seul le chef de l'exécutif ou le ministre des Affaires étrangères conduit la diplomatie." }
        if e.international.conflit == pays { return "Vous êtes en guerre : seule une négociation de paix est possible." }
        return nil
    }

    static func visiteEtat(_ pays: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard peutVisiter(j, e) else { return PolResultat(texte: "Il faut représenter le pays pour faire une visite d'État.") }
        if e.international.conflit == pays { return PolResultat(texte: "Impossible : vous êtes en guerre.") }
        if e.international.sanctions.contains(pays) { return PolResultat(texte: "Une visite pendant tes propres sanctions ? Lève-les d'abord.") }
        guard let n = [1, 2].first(where: { !dejaFaitCetteAnnee("visite_\($0)", j) }), marquer("visite_\(n)", &j) else {
            return PolResultat(texte: "Deux visites d'État par an, c'est déjà beaucoup d'heures d'avion. Le reste attendra.")
        }
        guard marquer("visite_pays_" + pays, &j) else { return PolResultat(texte: "Tu y es déjà allé" + j.g("", "e") + " cette année.") }
        let s = PolCatalogue.systeme(pays)
        j.stats.bonheur += 2
        if Double.random(in: 0...1) < 0.12 + Double(e.casseroles) / 400 {
            changerRelation(pays, -5, &e)
            e.popularite -= 2
            e.borner()
            return PolResultat(texte: drapeau(pays) + " " + [
                "Visite d'État \(s.auPays). Une phrase sortie de son contexte en conférence de presse fait la une là-bas pendant trois jours. Tu rentres plus tôt que prévu.",
                "Visite d'État \(s.auPays). Le protocole s'emmêle, l'hymne est joué deux fois, et ton hôte y voit un manque de respect. Le communiqué final est glacial.",
            ].randomElement()! + "\n\nEffets : relation -5, popularité -2.")
        }
        let gain = Int.random(in: 8...14)
        changerRelation(pays, gain, &e)
        e.international.influenceMondiale += 2
        e.popularite += 1
        e.borner()
        e.international.borner()
        e.titres.append(remplir("{prenom} {nom} en visite d'État \(s.auPays)", j, e))
        return PolResultat(texte: drapeau(pays) + " " + [
            "Visite d'État \(s.auPays). Tapis rouge, dîner officiel et une longue conversation en tête-à-tête qui déborde de deux heures. Les deux délégations repartent avec des projets.",
            "Visite d'État \(s.auPays). Tu visites une usine, une université et un quartier populaire. La presse locale salue un ton direct et sans condescendance.",
            "Visite d'État \(s.auPays). Le discours devant les parlementaires est applaudi debout. Ton conseiller diplomatique note que c'est rare.",
            "Visite d'État \(s.auPays). Peu de choses spectaculaires, mais un accord discret sur les visas et une relation qui se réchauffe.",
        ].randomElement()! + "\n\nEffets : relation +\(gain), poids mondial +2, popularité +1.")
    }

    static func chanceTraite(_ pays: String, _ e: PolEtat) -> Double {
        var c = 0.25 + Double(relation(pays, e)) / 150 + Double(e.international.influenceMondiale) / 250
        if e.majorite < 50 { c -= 0.15 }
        return max(0.05, min(0.9, c))
    }

    static func empechementTraite(_ type: PolTraiteType, _ pays: String, _ j: Joueur, _ e: PolEtat) -> String? {
        if let r = empechementDiplomatie(pays, j, e) { return r }
        if e.international.sanctions.contains(pays) { return "Tes sanctions sont toujours en place." }
        if relation(pays, e) < 10 { return "La relation est trop froide pour négocier un accord." }
        if e.international.traites.contains(where: { $0.pays == pays && $0.type == type }) { return "Cet accord existe déjà." }
        return nil
    }

    static func proposerTraite(_ type: PolTraiteType, _ pays: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        if let r = empechementTraite(type, pays, j, e) { return PolResultat(texte: r) }
        guard marquer("traite", &j) else { return PolResultat(texte: "Un accord par an : les négociateurs ne dorment déjà plus.") }
        let nom = nomPays(pays)
        if Double.random(in: 0...1) < chanceTraite(pays, e) {
            e.international.traites.append(PolTraite(type: type, pays: pays, age: j.age))
            changerRelation(pays, 6, &e)
            appliquerPol(type.signature, &j, &e)
            e.titres.append("\(type.nom) signé avec \(nom)")
            return PolResultat(texte: drapeau(pays) + " ✍️ \(type.nom) signé avec \(nom) après des mois de négociations. "
                               + "Chaque année, il pèsera sur le pays tant qu'il tiendra.\n\n" + resumeEffets(type.signature))
        }
        changerRelation(pays, -3, &e)
        e.influence -= 1
        e.borner()
        return PolResultat(texte: drapeau(pays) + " Les négociations avec \(nom) échouent sur un dernier paragraphe. Chacun accuse l'autre d'avoir changé les règles à la dernière minute.\n\nEffets : relation -3.")
    }

    static func sanctionner(_ pays: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        if let r = empechementDiplomatie(pays, j, e) { return PolResultat(texte: r) }
        guard !e.international.sanctions.contains(pays) else { return PolResultat(texte: "Des sanctions sont déjà en place.") }
        guard marquer("sanctions", &j) else { return PolResultat(texte: "Tu as déjà décidé des sanctions cette année.") }
        let avant = relation(pays, e)
        e.international.sanctions.append(pays)
        e.international.traites.removeAll { $0.pays == pays }
        changerRelation(pays, -30, &e)
        e.international.tension += 5
        e.pays.croissance -= 0.2
        let dp = avant < -20 ? 3 : -2
        e.popularite += dp
        e.borner()
        e.international.borner()
        e.titres.append("Sanctions contre \(nomPays(pays))")
        return PolResultat(texte: drapeau(pays) + " 🚫 Sanctions contre \(nomPays(pays)) : avoirs gelés, exportations sensibles bloquées, accords suspendus. "
                           + (avant < -20 ? "L'opinion approuve ta fermeté." : "Une partie de l'opinion juge la mesure disproportionnée.")
                           + "\n\nEffets : relation -30, croissance -0,2 pt, tension +5, popularité \(dp > 0 ? "+" : "")\(dp).")
    }

    static func leverSanctions(_ pays: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard peutDiplomatie(j, e), e.international.sanctions.contains(pays) else { return PolResultat(texte: "Il n'y a pas de sanctions à lever.") }
        guard marquer("lever_sanctions", &j) else { return PolResultat(texte: "Tu as déjà levé des sanctions cette année.") }
        e.international.sanctions.removeAll { $0 == pays }
        changerRelation(pays, 15, &e)
        e.popularite -= 1
        e.borner()
        return PolResultat(texte: drapeau(pays) + " Tu lèves les sanctions contre \(nomPays(pays)). Un geste salué là-bas, commenté avec méfiance ici.\n\nEffets : relation +15, popularité -1.")
    }

    static func aideInternationale(_ pays: String, _ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        if let r = empechementDiplomatie(pays, j, e) { return PolResultat(texte: r) }
        guard marquer("aide", &j) else { return PolResultat(texte: "Le budget de l'aide internationale de l'année est déjà engagé.") }
        changerRelation(pays, 10, &e)
        e.international.influenceMondiale += 4
        e.pays.dette += 0.4
        e.pays.moral += 1
        e.borner()
        e.international.borner()
        e.titres.append("Aide d'urgence pour \(nomPays(pays))")
        return PolResultat(texte: drapeau(pays) + " 📦 Avions-cargos, médecins et une enveloppe d'urgence partent pour \(nomPays(pays)). Les images de l'arrivée font le tour des chaînes.\n\nEffets : relation +10, poids mondial +4, dette +0,4 pt, moral +1.")
    }

    static func negocierPaix(_ j: inout Joueur, _ e: inout PolEtat) -> PolResultat {
        guard peutDiplomatie(j, e), let c = e.international.conflit else { return PolResultat(texte: "Aucun conflit en cours.") }
        guard marquer("paix", &j) else { return PolResultat(texte: "Une tentative de négociation par an : la précédente n'a pas encore refroidi.") }
        let chance = 0.2 + Double(e.international.influenceMondiale) / 250 + Double(e.international.anneesConflit) * 0.08
        if Double.random(in: 0...1) < chance {
            terminerConflit(c, &j, &e)
            e.popularite += 6
            e.international.influenceMondiale += 5
            e.borner()
            e.international.borner()
            return PolResultat(texte: "🕊️ Après des semaines de pourparlers dans un pays neutre, un cessez-le-feu est signé avec \(nomPays(c)). Personne ne parle encore de paix, mais les armes se taisent.\n\nEffets : popularité +6, poids mondial +5.")
        }
        e.popularite -= 2
        e.borner()
        return PolResultat(texte: "Les émissaires reviennent les mains vides. \(nomPaysMaj(c)) pose des conditions que ton gouvernement ne peut pas accepter.\n\nEffets : popularité -2.")
    }

    // MARK: Année

    static func anneeInternationale(_ j: inout Joueur, _ e: inout PolEtat, _ l: inout [String]) {
        var i = e.international
        // Les relations reviennent doucement vers leur niveau de départ, la tension retombe.
        for (k, v) in i.relations {
            let base = relationInitiale(k, e)
            if v != base { i.relations[k] = v + (base > v ? 1 : -1) }
        }
        i.tension += (30 - i.tension) / 5
        e.international = i

        // Accords en vigueur
        for t in e.international.traites { appliquerPol(t.type.annuel, &j, &e) }
        // Sanctions : elles coûtent aussi à qui les impose
        e.pays.croissance -= 0.1 * Double(e.international.sanctions.count)

        // Conflit armé
        if let c = e.international.conflit {
            e.international.anneesConflit += 1
            let n = e.international.anneesConflit
            e.pays.dette += 3
            e.pays.croissance -= 0.6
            e.pays.moral -= 4
            e.pays.securite -= 3
            e.popularite += n == 1 ? 5 : -3
            e.international.tension = max(e.international.tension, 60)
            j.stats.bonheur -= 3
            l.append("⚔️ Le conflit avec \(nomPays(c)) entre dans sa \(n == 1 ? "première" : "\(n)e") année. Dette, moral et croissance en souffrent.")
            if n >= 3, Double.random(in: 0...1) < 0.2 {
                terminerConflit(c, &j, &e)
                l.append("🕊️ Épuisés, les deux camps acceptent un cessez-le-feu négocié par des pays tiers.")
            } else if let m = e.mandat, e.dossiers.count < 5,
                      let d = tirerDossier(kind: "guerre", poste: m.poste.rawValue, j, e) {
                e.dossiers.append(PolDossierEnAttente(dossierId: d.id, ageArrivee: j.age))
                l.append("🎖️ Décision de guerre : « \(d.title) » (onglet Politique).")
            }
        }

        // Dossier international de l'année
        if peutDiplomatie(j, e), let m = e.mandat, e.dossiers.count < 5,
           Double.random(in: 0...1) < (m.poste == .ministre ? 0.4 : 0.6),
           let d = tirerDossier(kind: "international", poste: m.poste.rawValue, j, e) {
            e.dossiers.append(PolDossierEnAttente(dossierId: d.id, ageArrivee: j.age))
            l.append("🌍 Dossier international : « \(d.title) » (onglet Politique).")
        }
        e.international.borner()
        e.borner()
    }

    /// Au début de l'année : on garde l'état du pays pour afficher les tendances du tableau de bord.
    static func memoriserTableauDeBord(_ e: inout PolEtat) {
        e.paysPrecedent = e.pays
        e.popularitePrecedente = e.popularite
    }
}

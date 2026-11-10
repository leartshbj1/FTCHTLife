import Foundation

/// Logique du journal du monde. Fonctions pures : le moteur garde un `MondeEtat` dans la sauvegarde
/// et appelle `nouvelleAnnee` à chaque anniversaire (voir docs/MONDE_INTEGRATION.md).
enum MondeJournal {
    /// Tous les flashs de Data/Monde/*.json.
    static let tous: [MondeFlash] = DonneesJSON.chargerTableaux(dossier: "Monde", type: MondeFlash.self)
    static let parId: [String: MondeFlash] = Dictionary(tous.map { ($0.id, $0) }, uniquingKeysWith: { premier, _ in premier })

    /// Chance qu'une une soit publiée une année donnée.
    static let chanceUne = 0.9
    /// Nombre maximum de flashs à effets actifs en même temps (au-delà, seuls les flashs pour rire sortent).
    static let maxActifs = 3
    /// Un flash non unique ne ressort pas tant qu'il est dans les N dernières unes.
    static let memoireRepetition = 15

    static func flash(_ id: String) -> MondeFlash? { parId[id] }

    // MARK: - Passage d'une année

    /// À appeler une fois par an, après `j.age += 1`.
    /// - Parameters:
    ///   - age: âge du joueur cette année.
    ///   - tagsJoueur: `GameEngine.tags(j)`, pour cibler les effets.
    ///   - remplir: remplace les variables {prenom}, {e}… (passer `{ engine.remplir($0, j) }`).
    static func nouvelleAnnee(_ etat: inout MondeEtat, age: Int, tagsJoueur: Set<String>,
                              remplir: (String) -> String = { $0 }) -> MondeRapport {
        var rapport = MondeRapport()

        // 1. Les crises en cours vieillissent ; celles qui finissent écrivent leur texte de fin et peuvent avoir une suite.
        var encore: [MondeFlashActif] = []
        for var actif in etat.actifs {
            actif.anneesRestantes -= 1
            if actif.anneesRestantes > 0 {
                encore.append(actif)
            } else if let f = flash(actif.id) {
                if let fin = f.texteFin { rapport.lignes.append("🗞️ " + remplir(fin)) }
                if let suites = f.suites, !suites.isEmpty, Double.random(in: 0..<1) < (f.chanceSuite ?? 0.5),
                   let suite = suites.randomElement() {
                    etat.suitesEnAttente.append(suite)
                }
            }
        }
        etat.actifs = encore

        // 2. La une de l'année : une suite programmée en priorité, sinon un tirage au sort.
        var publie: MondeFlash?
        while publie == nil, !etat.suitesEnAttente.isEmpty {
            let id = etat.suitesEnAttente.removeFirst()
            if let f = flash(id), !etat.idsActifs.contains(id) { publie = f }
        }
        if publie == nil, Double.random(in: 0..<1) < chanceUne {
            let candidats = tous.filter { peutSortir($0, etat: etat, age: age) }
            publie = tirage(candidats)
        }
        if let f = publie {
            publier(f, etat: &etat, age: age, tagsJoueur: tagsJoueur, remplir: remplir, rapport: &rapport)
        }

        // 3. Ce que les crises en cours font au joueur cette année.
        for actif in etat.actifs {
            guard let f = flash(actif.id) else { continue }
            for e in f.effetsAnnuels ?? [] where concerne(e, tagsJoueur) {
                if let t = e.text { rapport.lignes.append(remplir(t)) }
                rapport.effets.append(e.effects)
            }
        }
        return rapport
    }

    /// Publie un flash précis cette année (pour les modules Politique, Bourse…), même s'il est `suiteSeulement`.
    /// Renvoie nil si le flash n'existe pas ou est déjà en cours. Le rapport contient les effets immédiats
    /// et ceux de la première année (à appliquer avec GameEngine.appliquer).
    @discardableResult
    static func forcer(_ id: String, etat: inout MondeEtat, age: Int, tagsJoueur: Set<String>,
                       remplir: (String) -> String = { $0 }) -> MondeRapport? {
        guard let f = flash(id), !etat.idsActifs.contains(id) else { return nil }
        var rapport = MondeRapport()
        publier(f, etat: &etat, age: age, tagsJoueur: tagsJoueur, remplir: remplir, rapport: &rapport)
        for e in f.effetsAnnuels ?? [] where concerne(e, tagsJoueur) {
            if let t = e.text { rapport.lignes.append(remplir(t)) }
            rapport.effets.append(e.effects)
        }
        return rapport
    }

    private static func publier(_ f: MondeFlash, etat: inout MondeEtat, age: Int, tagsJoueur: Set<String>,
                                remplir: (String) -> String, rapport: inout MondeRapport) {
        rapport.flash = f
        etat.archives.append(MondeUne(id: f.id, age: age))
        rapport.lignes.append("📰 FLASH INFO : \(f.titre). " + remplir(f.texte))
        if f.dureeEffets > 0 {
            etat.actifs.append(MondeFlashActif(id: f.id, anneesRestantes: f.dureeEffets, ageDebut: age))
        }
        for e in f.effetsImmediats ?? [] where concerne(e, tagsJoueur) {
            if let t = e.text { rapport.lignes.append(remplir(t)) }
            rapport.effets.append(e.effects)
        }
    }

    /// Le flash peut-il être tiré au sort cette année ?
    static func peutSortir(_ f: MondeFlash, etat: MondeEtat, age: Int) -> Bool {
        if f.suiteSeulement == true { return false }
        if let m = f.minAge, age < m { return false }
        if let m = f.maxAge, age > m { return false }
        if etat.idsActifs.contains(f.id) { return false }
        if f.estUnique {
            if etat.archives.contains(where: { $0.id == f.id }) { return false }
        } else if etat.archives.suffix(memoireRepetition).contains(where: { $0.id == f.id }) {
            return false
        }
        let actifs = tags(etat)
        if let r = f.requiertTagsMonde, !Set(r).isSubset(of: actifs) { return false }
        if let x = f.excluTagsMonde, !Set(x).isDisjoint(with: actifs) { return false }
        // Une crise en cours peut aussi exclure le nouveau flash.
        let nouveaux = Set(f.tagsMonde ?? [])
        if !nouveaux.isEmpty {
            for a in etat.actifs {
                if let x = flash(a.id)?.excluTagsMonde, !nouveaux.isDisjoint(with: x) { return false }
            }
        }
        if f.dureeEffets > 0 && etat.actifs.count >= maxActifs { return false }
        return true
    }

    /// Tirage pondéré par `poids` (le moteur est isolé sur le MainActor, d'où cette copie locale).
    private static func tirage(_ liste: [MondeFlash]) -> MondeFlash? {
        let total = liste.reduce(0.0) { $0 + max(0, $1.poids ?? 1) }
        guard total > 0 else { return liste.randomElement() }
        var r = Double.random(in: 0..<total)
        for f in liste {
            r -= max(0, f.poids ?? 1)
            if r < 0 { return f }
        }
        return liste.last
    }

    private static func concerne(_ e: MondeEffetJoueur, _ tags: Set<String>) -> Bool {
        if let r = e.tags, !Set(r).isSubset(of: tags) { return false }
        if let x = e.excludeTags, !Set(x).isDisjoint(with: tags) { return false }
        return true
    }

    // MARK: - Ce qui est actif

    static func flashsActifs(_ etat: MondeEtat) -> [(flash: MondeFlash, actif: MondeFlashActif)] {
        etat.actifs.compactMap { a in flash(a.id).map { (flash: $0, actif: a) } }
    }

    private static func modificateursActifs(_ etat: MondeEtat) -> [MondeModificateurs] {
        etat.actifs.compactMap { flash($0.id)?.modificateurs }
    }

    /// Tags monde actifs, sans préfixe (ex. "crise_croissant").
    static func tags(_ etat: MondeEtat) -> Set<String> {
        Set(etat.actifs.flatMap { flash($0.id)?.tagsMonde ?? [] })
    }

    /// Tags à ajouter aux tags du joueur (préfixés "monde_"), pour les conditions des événements.
    static func tagsJoueur(_ etat: MondeEtat) -> Set<String> {
        Set(tags(etat).map { "monde_" + $0 })
    }

    /// Événements spéciaux possibles uniquement pendant les flashs en cours.
    static func evenementsActifs(_ etat: MondeEtat) -> [Evenement] {
        etat.actifs.flatMap { flash($0.id)?.evenements ?? [] }
    }

    // MARK: - Multiplicateurs

    static let borneMin = 0.1
    static let borneMax = 10.0

    private static func borne(_ x: Double) -> Double { min(borneMax, max(borneMin, x)) }

    /// Produit des facteurs `cle` et "tout" de plusieurs tables.
    private static func produit(_ tables: [[String: Double]], cle: String?) -> Double {
        var m = 1.0
        for t in tables {
            if let c = cle, let v = t[c] { m *= v }
            if let v = t["tout"] { m *= v }
        }
        return borne(m)
    }

    /// Multiplicateur des prix d'une catégorie (immobilier, voitures, bateaux, avions, bijoux, voyages, nourriture,
    /// tech, luxe, animaux, sante, etudes, loisirs, vetements). `extra` : tables d'autres modules (lois, etc.).
    static func multiplicateurPrix(_ categorie: String, etat: MondeEtat, extra: [[String: Double]] = []) -> Double {
        produit(modificateursActifs(etat).compactMap(\.prix) + extra, cle: categorie)
    }

    static func prix(_ montant: Int, categorie: String, etat: MondeEtat, extra: [[String: Double]] = []) -> Int {
        arrondi(montant, multiplicateurPrix(categorie, etat: etat, extra: extra))
    }

    /// Multiplicateur des salaires d'un secteur. Accepte aussi les secteurs du module Métiers (beaute_mode, art_culture…).
    static func multiplicateurSalaire(secteur: String?, etat: MondeEtat, extra: [[String: Double]] = []) -> Double {
        produit(modificateursActifs(etat).compactMap(\.salaires) + extra, cle: secteur.map(MondeSecteurs.normaliser))
    }

    static func salaire(_ montant: Int, secteur: String?, etat: MondeEtat, extra: [[String: Double]] = []) -> Int {
        arrondi(montant, multiplicateurSalaire(secteur: secteur, etat: etat, extra: extra))
    }

    /// Salaire d'un métier du moteur (Donnees.metiers) : le secteur est deviné depuis l'id et le titre.
    static func salaire(_ montant: Int, metierId: String, titre: String, etat: MondeEtat) -> Int {
        salaire(montant, secteur: MondeSecteurs.secteur(metierId: metierId, titre: titre), etat: etat)
    }

    /// Multiplicateur brut d'un marché (bourse, crypto, or, immobilier_locatif, epargne, bourse_<secteur>).
    /// `bourse_tech` ne contient pas `bourse` : le module Placements multiplie les deux.
    static func multiplicateurMarche(_ cle: String, etat: MondeEtat) -> Double {
        var m = 1.0
        for t in modificateursActifs(etat).compactMap(\.marches) {
            if let v = t[cle] { m *= v }
        }
        return borne(m)
    }

    /// Tous les multiplicateurs de marché en cours, à passer tels quels au module Placements.
    static func marches(_ etat: MondeEtat) -> [String: Double] {
        let cles = Set(modificateursActifs(etat).compactMap(\.marches).flatMap(\.keys))
        return Dictionary(uniqueKeysWithValues: cles.map { ($0, multiplicateurMarche($0, etat: etat)) })
    }

    /// Multiplie la chance de mourir dans l'année.
    static func multiplicateurMortalite(_ etat: MondeEtat) -> Double {
        borne(modificateursActifs(etat).reduce(1.0) { $0 * ($1.mortalite ?? 1) })
    }

    /// Multiplie la pension de retraite.
    static func multiplicateurRetraite(_ etat: MondeEtat) -> Double {
        borne(modificateursActifs(etat).reduce(1.0) { $0 * ($1.retraite ?? 1) })
    }

    /// Multiplicateur du poids d'un événement aléatoire, selon sa catégorie et le début de son id.
    static func multiplicateurEvenement(_ e: Evenement, etat: MondeEtat) -> Double {
        var m = 1.0
        for mod in modificateursActifs(etat) {
            guard let ev = mod.evenements else { continue }
            if let c = e.category, let v = ev.categories?[c] { m *= v }
            for (prefixe, v) in ev.prefixes ?? [:] where e.id.hasPrefix(prefixe) { m *= v }
        }
        return min(20, max(0.05, m))
    }

    /// Poids final d'un événement (à utiliser dans le tirage du moteur à la place de `e.weight ?? 1`).
    static func poidsEvenement(_ e: Evenement, etat: MondeEtat) -> Double {
        (e.weight ?? 1) * multiplicateurEvenement(e, etat: etat)
    }

    private static func arrondi(_ montant: Int, _ m: Double) -> Int {
        Int((Double(montant) * m).rounded())
    }

    // MARK: - Résumé lisible des effets

    /// Lignes courtes décrivant les effets d'un flash, ex. « 🏠 Immobilier +30 % ».
    static func resume(_ f: MondeFlash) -> [String] {
        var lignes: [String] = []
        if let m = f.modificateurs {
            for (cle, v) in (m.prix ?? [:]).sorted(by: { $0.key < $1.key }) {
                lignes.append("🏷️ Prix \(MondeLibelles.prix(cle)) \(pourcentage(v))")
            }
            for (cle, v) in (m.salaires ?? [:]).sorted(by: { $0.key < $1.key }) {
                lignes.append("💼 Salaires \(MondeLibelles.secteur(cle)) \(pourcentage(v))")
            }
            for (cle, v) in (m.marches ?? [:]).sorted(by: { $0.key < $1.key }) {
                lignes.append("📈 \(MondeLibelles.marche(cle)) \(pourcentage(v))")
            }
            for (cle, v) in (m.evenements?.categories ?? [:]).sorted(by: { $0.key < $1.key }) {
                lignes.append("🎲 Événements « \(cle) » \(v >= 1 ? "plus" : "moins") fréquents (×\(String(format: "%.1f", v)))")
            }
            if let v = m.mortalite, v != 1 { lignes.append("💀 Mortalité \(pourcentage(v))") }
            if let v = m.retraite, v != 1 { lignes.append("👴 Retraites \(pourcentage(v))") }
        }
        if !(f.effetsAnnuels ?? []).isEmpty { lignes.append("📅 Des effets chaque année sur certains habitants") }
        if !(f.evenements ?? []).isEmpty { lignes.append("✨ Des événements spéciaux possibles") }
        return lignes
    }

    static func pourcentage(_ v: Double) -> String {
        let p = Int(((v - 1) * 100).rounded())
        return p >= 0 ? "+\(p) %" : "−\(-p) %"
    }
}

/// Noms lisibles des clés de modificateurs.
enum MondeLibelles {
    static let tablePrix: [String: String] = [
            "immobilier": "de l'immobilier", "voitures": "des voitures", "bateaux": "des bateaux", "avions": "des avions",
            "bijoux": "des bijoux", "voyages": "des voyages", "nourriture": "de la nourriture", "tech": "de la tech",
            "luxe": "du luxe", "animaux": "des animaux", "sante": "des soins", "etudes": "des études",
            "loisirs": "des loisirs", "vetements": "des vêtements", "tout": "de tout",
    ]
    static func prix(_ cle: String) -> String { tablePrix[cle] ?? cle }

    static let tableSecteurs: [String: String] = [
            "restauration": "restauration", "commerce": "commerce", "transport": "transports", "batiment": "bâtiment",
            "beaute": "beauté et mode", "securite": "sécurité", "administration": "administration", "medias": "médias",
            "immobilier": "immobilier", "tech": "tech", "finance": "finance", "arts": "arts", "science": "science",
            "education": "éducation", "droit": "droit", "sante": "santé", "sport": "sport", "politique": "politique",
            "industrie": "industrie", "agriculture": "agriculture", "tourisme": "tourisme", "tout": "tous secteurs",
    ]
    static func secteur(_ cle: String) -> String { tableSecteurs[cle] ?? cle }

    static func marche(_ cle: String) -> String {
        if cle.hasPrefix("bourse_") { return "Bourse (" + String(cle.dropFirst("bourse_".count)) + ")" }
        let noms: [String: String] = [
            "bourse": "Bourse", "crypto": "Cryptos", "or": "Or", "immobilier_locatif": "Loyers",
            "epargne": "Taux du livret",
        ]
        return noms[cle] ?? cle
    }
}

import Foundation

/// Règles chiffrées et fonctions pures du module Entreprises.
enum EntrepriseMoteur {
    static let maxEntreprises = 3
    static let niveauMax = 5
    /// Taille relative de la boîte par niveau.
    static let echelles: [Double] = [1, 2.5, 6, 16, 50, 160]
    static let maxSites = 500
    /// Part du coût de création que le joueur doit payer lui-même s'il emprunte.
    static let apportMinimum = 0.3
    static let tauxInteret = 0.06
    static let dureeEmprunt = 8

    static func echelle(_ niveau: Int) -> Double {
        echelles[min(max(0, niveau), echelles.count - 1)]
    }

    static func aEchelle(_ montant: Int?, _ e: Entreprise) -> Int {
        Int(Double(montant ?? 0) * e.echelle)
    }

    /// Nombre de postes clés.
    static func postes(_ e: Entreprise) -> Int { min(8, e.niveau + 1) }

    static func coutPub(_ e: Entreprise, _ type: EntrepriseType) -> Int {
        max(500, Int(Double(type.coutCreation) * 0.08 * e.echelle))
    }

    /// Charges annuelles (dernier rapport, sinon estimation au réglage normal).
    static func charges(_ e: Entreprise, _ type: EntrepriseType) -> Int {
        if let r = e.rapport { return r.couts }
        return Int(Double(type.chiffreAffairesBase) * e.echelle * (1 - type.marge))
    }

    /// Trésorerie sous laquelle la boîte est considérée en grand danger.
    static func seuilFaillite(_ e: Entreprise, _ type: EntrepriseType) -> Int {
        -Int(Double(charges(e, type)) * 0.3)
    }

    /// Valeur estimée de la boîte (murs et machines + rentabilité + trésorerie − dette).
    static func valeur(_ e: Entreprise, _ type: EntrepriseType) -> Int {
        let eco = EntrepriseCatalogue.eco(type.id)
        let actifs = Double((eco?.coutSite ?? type.coutCreation) * e.sites + (eco?.coutUsine ?? 0) * max(0, e.usines)) * 0.5
        let resultat = Double(max(0, e.dernierBilan?.resultat ?? 0))
        let image = 0.6 + Double(e.reputation) / 125
        let v = actifs + resultat * type.multipleValeur * 4 * image + Double(e.tresorerie) - Double(e.dette)
        return max(0, Int(v))
    }

    // MARK: - Conditions de création

    /// Raison pour laquelle le joueur ne peut pas fonder ce type, ou nil s'il peut.
    static func blocageCreation(_ type: EntrepriseType, _ j: Joueur) -> String? {
        if !j.vivant { return "Tu es mort. Même pour un entrepreneur, c'est un frein." }
        let ageMin = type.ageMin ?? 18
        if j.age < ageMin { return "Il faut avoir \(ageMin) ans." }
        if (j.entreprises?.actives.count ?? 0) >= maxEntreprises { return "Tu as déjà \(maxEntreprises) boîtes. Respire." }
        if j.diplome < type.diplomeRequis { return "Diplôme requis : \(type.diplomeRequis.nom)." }
        if let f = type.filiereRequise, j.filiereDiplome != f { return "Il faut un diplôme en \(f.nom.lowercased())." }
        if j.stats.intelligence < (type.intelligenceMin ?? 0) { return "Ce n'est pas pour toi (intelligence \(type.intelligenceMin ?? 0) requise)." }
        let apport = Int(Double(type.coutCreation) * apportMinimum)
        if j.argent < apport { return "Il te faut au moins \(Format.argent(apport)) d'apport." }
        return nil
    }

    // MARK: - Tags et résumé

    /// Tags à ajouter à `GameEngine.tags(j)` pour les événements classiques.
    static func tags(_ etat: EntreprisesEtat?) -> Set<String> {
        guard let etat = etat else { return [] }
        var t: Set<String> = []
        if !etat.actives.isEmpty { t.insert("entrepreneur") }
        if etat.actives.contains(where: { !$0.employes.isEmpty }) { t.insert("patron") }
        if etat.actives.contains(where: { $0.niveau >= 4 }) { t.insert("magnat") }
        if !etat.archives.isEmpty { t.insert("ancien_entrepreneur") }
        if etat.archives.contains(where: { $0.fin == "faillite" }) { t.insert("failli") }
        return t
    }

    /// La première crise en attente (pour l'afficher en carte à la fin de l'année).
    static func criseEnAttente(_ j: Joueur) -> Entreprise? {
        j.entreprises?.actives.first { $0.crise != nil }
    }

    /// Lignes pour la nécrologie ou le bilan de vie.
    static func resumeVie(_ etat: EntreprisesEtat?) -> [String] {
        guard let etat = etat else { return [] }
        var lignes: [String] = []
        for e in etat.actives {
            let type = EntrepriseCatalogue.type(e.typeId)
            lignes.append("A fondé « \(e.nom) » (\(type?.nom.lowercased() ?? "entreprise")), toujours en activité.")
        }
        for a in etat.archives {
            let type = EntrepriseCatalogue.type(a.typeId)?.nom.lowercased() ?? "entreprise"
            if a.fin == "vendue" {
                lignes.append("A revendu « \(a.nom) » (\(type)) pour \(Format.argent(a.montant)).")
            } else if a.fin == "fermee" {
                lignes.append("A fermé « \(a.nom) » (\(type)) après \(a.ageFin - a.ageDebut) an\(a.ageFin - a.ageDebut > 1 ? "s" : "") sans trop de casse.")
            } else {
                lignes.append("A mené « \(a.nom) » (\(type)) droit à la faillite en \(a.ageFin - a.ageDebut) an\(a.ageFin - a.ageDebut > 1 ? "s" : "").")
            }
        }
        return lignes
    }

    // MARK: - Embauche

    static func nouveauCandidat(_ type: EntrepriseType, poste: String) -> EntrepriseEmploye {
        let g = Genre.allCases.randomElement()!
        let competence = Int.random(in: 20...92)
        let salaire = Int(Double(type.salaireEmploye) * (0.75 + Double(competence) / 200) * Double.random(in: 0.9...1.1))
        return EntrepriseEmploye(prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement()!, genre: g,
                                 relationId: nil, lienLibelle: nil, poste: poste,
                                 competence: competence, motivation: Int.random(in: 40...80), salaire: salaire)
    }

    static func candidats(_ e: Entreprise, _ type: EntrepriseType) -> [EntrepriseEmploye] {
        (0..<3).map { _ in nouveauCandidat(type, poste: posteLibre(e, type)) }
    }

    /// Un poste qui n'est pas encore occupé (ou un poste au hasard).
    static func posteLibre(_ e: Entreprise, _ type: EntrepriseType) -> String {
        let pris = Set(e.employes.map { $0.poste })
        return type.postes.first { !pris.contains($0) } ?? type.postes.randomElement() ?? "Employé·e"
    }

    /// Les proches qu'on peut embaucher (pas déjà employés dans une de ses boîtes).
    static func prochesEmbauchables(_ j: Joueur) -> [Relation] {
        let dejaEmployes = Set((j.entreprises?.actives ?? []).flatMap { $0.employes.compactMap { $0.relationId } })
        let types: [TypeRelation] = [.ami, .frere, .soeur, .mere, .pere, .partenaire, .enfant, .ex]
        return j.relations.filter {
            $0.vivant && types.contains($0.type) && $0.age >= 16 && $0.age <= 78 && !dejaEmployes.contains($0.id)
        }
    }

    static func employeDepuisProche(_ r: Relation, _ type: EntrepriseType, poste: String) -> EntrepriseEmploye {
        EntrepriseEmploye(prenom: r.prenom, nom: r.nom, genre: r.genre, relationId: r.id, lienLibelle: r.libelle,
                          poste: poste, competence: Int.random(in: 8...75), motivation: Int.random(in: 55...95),
                          salaire: Int(Double(type.salaireEmploye) * Double.random(in: 0.8...1.05)))
    }

    // MARK: - Événements

    static func eligible(_ ev: EntrepriseEvenement, _ e: Entreprise, _ type: EntrepriseType, patronAbsent: Bool) -> Bool {
        if e.niveau < (ev.minNiveau ?? 0) || e.niveau > (ev.maxNiveau ?? niveauMax) { return false }
        if ev.unique == true && e.evenementsVus.contains(ev.id) { return false }
        let filtreSecteur = ev.secteurs.map { !$0.isEmpty } ?? false
        let filtreType = ev.types.map { !$0.isEmpty } ?? false
        if filtreSecteur || filtreType {
            let okSecteur = ev.secteurs?.contains(type.secteur) ?? false
            let okType = ev.types?.contains(type.id) ?? false
            if !okSecteur && !okType { return false }
        }
        guard let c = ev.conditions else { return true }
        if let m = c.minEmployes, e.employes.count < m { return false }
        if let m = c.maxEmployes, e.employes.count > m { return false }
        if let m = c.minAnnees, e.annees < m { return false }
        if let d = c.enDifficulte, d != (e.tresorerie < 0) { return false }
        if let a = c.patronAbsent, a != patronAbsent { return false }
        if let m = c.minReputation, e.reputation < m { return false }
        if let m = c.maxReputation, e.reputation > m { return false }
        if let quel = c.employe, employeCible(quel, e) == nil { return false }
        return true
    }

    /// Choisit l'employé visé par un événement ("proche", "inconnu", "any").
    static func employeCible(_ quel: String, _ e: Entreprise) -> EntrepriseEmploye? {
        switch quel {
        case "proche": return e.employes.filter { $0.estProche }.randomElement()
        case "inconnu": return e.employes.filter { !$0.estProche }.randomElement()
        default: return e.employes.randomElement()
        }
    }

    static func tirage<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0.0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.first }
        var r = Double.random(in: 0..<total)
        for x in liste {
            r -= max(0, poids(x))
            if r < 0 { return x }
        }
        return liste.last
    }

    /// Remplace les variables propres aux entreprises. Les variables du joueur sont remplies ensuite par le moteur.
    static func remplir(_ texte: String, _ e: Entreprise, _ type: EntrepriseType, employe: EntrepriseEmploye?) -> String {
        var t = texte
        t = t.replacingOccurrences(of: "{niveau}", with: type.nomNiveau(e.niveau).lowercased())
        t = t.replacingOccurrences(of: "{entreprise}", with: e.nom)
        t = t.replacingOccurrences(of: "{produit}", with: type.produit)
        t = t.replacingOccurrences(of: "{employe}", with: employe?.prenom ?? "ton employé")
        t = t.replacingOccurrences(of: "{poste}", with: (employe?.poste ?? "employé").lowercased())
        t = t.replacingOccurrences(of: "{concurrent}", with: e.concurrent)
        return t
    }

    // MARK: - Textes

    static let phrasesCreation = [
        "Tu as signé 47 papiers. Tu n'en as lu aucun.",
        "Ton banquier t'a serré la main en souriant. Méfie-toi.",
        "Tu as imprimé 5 000 cartes de visite. Il y a une faute dans ton nom.",
        "Ta famille trouve que c'est « courageux ». Ça veut dire « idiot », mais poli.",
        "Tu t'es auto-proclamé{e} PDG. Personne n'a applaudi, sauf toi.",
    ]

    static let phrasesPub = [
        "Tu as payé un avion pour traîner une banderole. Il l'a perdue au-dessus du lac.",
        "Ta pub passe à la radio à 3 h du matin. Les insomniaques adorent.",
        "Tu as distribué des flyers. Les pigeons en ont fait un nid très tendance.",
        "Ton slogan est tellement nul qu'il est devenu un mème. Ça marche.",
        "Tu as sponsorisé l'équipe de foot des moins de 9 ans. Ils ont perdu 14-0, mais avec ton logo.",
        "Un panneau géant avec ta tête trône à l'entrée de la ville. Les enfants pleurent un peu.",
    ]

    static let phrasesTravail = [
        "Tu as fait des journées de 16 heures. Ton lit a oublié ton visage.",
        "Tu as tout fait toi-même, même réparer la machine à café avec une fourchette.",
        "Tu as dormi dans la réserve trois nuits. Tu commences à parler aux cartons.",
        "Tu as répondu à 400 mails. Dont 12 de ta mère.",
    ]
}

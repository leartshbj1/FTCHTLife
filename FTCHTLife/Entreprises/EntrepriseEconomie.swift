import Foundation

// Gestion poussée : modèle économique annuel (demande, part de marché, capacité, coûts). Voir docs/ENTREPRISES.md.

/// Calibrage économique d'un type de boîte. Les valeurs par défaut reproduisent, au réglage normal,
/// le chiffre d'affaires et la marge prévus dans types.json pour un seul point de vente.
struct EntrepriseEco {
    let type: EntrepriseType
    let vente: EntrepriseUnite
    let site: EntrepriseUnite
    let usine: EntrepriseUnite?
    let prixUnitaire: Double
    let elasticite: Double
    let leviers: [EntrepriseLevier]

    /// Clients potentiels par point de vente et par an.
    let marcheParSite: Double
    /// Coût d'achat d'une vente, qualité 3.
    let coutVariable: Double
    let capaciteSite: Double
    let capaciteUsine: Double
    let employesSite: Double
    let employesUsine: Double
    /// Encadrement fixe (gérance, compta…) quelle que soit la taille, couvert par le patron s'il est là.
    let employesFixes: Double
    let loyerSite: Double
    let loyerUsine: Double
    let coutSite: Int
    let coutUsine: Int

    var aUsine: Bool { usine != nil }

    init(_ type: EntrepriseType, donnees: EntrepriseLeviersType?) {
        self.type = type
        vente = donnees?.vente ?? EntrepriseUnite(nom: "vente", pluriel: "ventes", cout: nil)
        site = donnees?.site ?? EntrepriseUnite(nom: "local", pluriel: "locaux", cout: nil)
        usine = donnees?.usine
        leviers = donnees?.leviers ?? []
        elasticite = min(2.2, max(0.4, donnees?.elasticite ?? EntrepriseEco.elasticiteSecteur(type.secteur)))
        prixUnitaire = max(1, donnees?.prixUnitaire ?? EntrepriseEco.prixSecteur(type.secteur))

        let ca0 = Double(max(1000, type.chiffreAffairesBase))
        let marge = min(0.8, max(0.05, type.marge))
        let d0 = ca0 / prixUnitaire
        let a0 = EntrepriseEco.attractiviteDeReference(elasticite: elasticite)
        marcheParSite = d0 / (EntrepriseSimulation.partDeBase * a0)
        let couts = max(ca0 * 0.1, ca0 * (1 - marge) - ca0 * 0.02)
        coutVariable = 0.45 * couts / d0
        let personnel = 0.35 * couts / Double(max(1000, type.salaireEmploye))
        let loyers = 0.20 * couts
        // Au réglage normal, l'effectif utile vaut « personnel + 1 » (le patron compte pour 1).
        let k = usine != nil ? 1.52 : 1.25
        employesFixes = k
        if let u = usine {
            capaciteSite = 0
            capaciteUsine = d0 * 1.6
            employesSite = 0.4 * personnel * k
            employesUsine = 0.6 * personnel * k
            loyerSite = 0.4 * loyers
            loyerUsine = 0.6 * loyers
            coutSite = site.cout ?? Int(Double(type.coutCreation) * 0.4)
            coutUsine = u.cout ?? Int(Double(type.coutCreation) * 0.9)
        } else {
            capaciteSite = d0 * 1.3
            capaciteUsine = 0
            employesSite = personnel * k
            employesUsine = 0
            loyerSite = loyers
            loyerUsine = 0
            coutSite = site.cout ?? Int(Double(type.coutCreation) * 0.9)
            coutUsine = 0
        }
    }

    static func prixSecteur(_ s: String) -> Double {
        switch s {
        case "restauration": return 14
        case "beaute": return 35
        case "commerce": return 25
        case "mode": return 45
        case "tech": return 40
        case "services": return 80
        case "artisanat": return 900
        case "loisirs": return 30
        case "immobilier": return 8000
        case "transport": return 60
        default: return 30
        }
    }

    static func elasticiteSecteur(_ s: String) -> Double {
        switch s {
        case "restauration": return 1.3
        case "beaute": return 1.1
        case "commerce": return 1.6
        case "mode": return 1.2
        case "tech": return 0.9
        case "services": return 1.0
        case "artisanat": return 0.9
        case "loisirs": return 1.2
        case "immobilier": return 0.8
        case "transport": return 1.4
        default: return 1.2
        }
    }

    /// Attractivité au réglage par défaut (prix 1, qualité 3, marketing 2 %, réputation 50, équipe complète).
    static func attractiviteDeReference(elasticite: Double) -> Double {
        EntrepriseSimulation.facteurMarketing(2)
    }

    /// Personnel nécessaire pour faire tourner les unités à plein.
    func effectifNecessaire(sites: Int, usines: Int) -> Double {
        Double(sites) * employesSite + Double(max(0, usines)) * employesUsine + employesFixes
    }

    /// Clients potentiels : chaque nouveau point de vente mord un peu sur les autres.
    func marche(sites: Int) -> Double {
        marcheParSite * pow(Double(max(1, sites)), 0.95)
    }

    func capaciteUnites(sites: Int, usines: Int) -> Double {
        aUsine ? Double(max(0, usines)) * capaciteUsine : Double(sites) * capaciteSite
    }

    func levier(_ id: String) -> EntrepriseLevier? { leviers.first { $0.id == id } }
}

/// Calcul d'une année. Sert au bilan (avec hasard) et à l'estimation affichée au joueur (sans hasard).
enum EntrepriseSimulation {
    static let partDeBase = 0.3
    static let qualiteDemande: [Double] = [0.75, 0.9, 1.0, 1.12, 1.25]
    static let qualiteCout: [Double] = [0.7, 0.85, 1.0, 1.25, 1.6]
    static let qualiteNoms = ["Bas de gamme", "Économique", "Standard", "Soignée", "Haut de gamme"]
    static let budgetsMarketing = [0, 2, 5, 10, 20]
    static let niveauxPrix: [Double] = [0.6, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 2.0]
    static let niveauxSalaire: [Double] = [0.8, 0.9, 1.0, 1.15, 1.3, 1.4]
    /// Travail que fournit le patron : 1 personne s'il se consacre à sa boîte, 0,4 s'il a un autre emploi ou des études.
    static func travailDuPatron(_ disponible: Bool) -> Double { disponible ? 1 : 0.4 }

    static func facteurMarketing(_ pourcent: Int) -> Double {
        0.9 + 0.68 * (1 - exp(-Double(max(0, pourcent)) / 6))
    }

    static func facteurQualite(_ q: Int, _ table: [Double]) -> Double {
        table[min(max(1, q), 5) - 1]
    }

    /// Somme des effets des leviers actifs.
    static func effetsLeviers(_ e: Entreprise, _ eco: EntrepriseEco) -> EntrepriseLevierEffets {
        var t = EntrepriseLevierEffets(demande: 0, prix: 0, coutVariable: 0, capacite: 0, productivite: 0,
                                       reputation: 0, moral: 0, risque: 0, karma: 0)
        for id in e.leviers {
            guard let l = eco.levier(id), let f = l.effets else { continue }
            t.demande! += f.demande ?? 0
            t.prix! += f.prix ?? 0
            t.coutVariable! += f.coutVariable ?? 0
            t.capacite! += f.capacite ?? 0
            t.productivite! += f.productivite ?? 0
            t.reputation! += f.reputation ?? 0
            t.moral! += f.moral ?? 0
            t.risque! += f.risque ?? 0
            t.karma! += f.karma ?? 0
        }
        return t
    }

    static func coutAnnuelLeviers(_ e: Entreprise, _ eco: EntrepriseEco) -> Int {
        e.leviers.reduce(0) { total, id in
            guard let l = eco.levier(id) else { return total }
            return total + (l.coutAnnuel ?? 0) * (l.parSite == true ? e.sites : 1)
        }
    }

    static func postesCadresManquants(_ e: Entreprise) -> Int {
        max(0, EntrepriseMoteur.postes(e) - e.employes.count)
    }

    static func productivite(_ e: Entreprise, _ lev: EntrepriseLevierEffets, patronDisponible: Bool) -> Double {
        let moral = 0.85 + Double(e.moral) / 400
        let salaire = 1 + (e.salaireNiveau - 1) * 0.5
        var cadres = 0.0
        for emp in e.employes { cadres += Double(emp.competence - 40) / 600 + Double(emp.motivation - 50) / 1000 }
        cadres -= 0.05 * Double(postesCadresManquants(e))
        let patron = patronDisponible ? 1.0 : 0.9
        return max(0.3, moral * salaire * patron * (1 + cadres) * (1 + Double(lev.productivite ?? 0) / 100))
    }

    static func attractivite(_ e: Entreprise, _ eco: EntrepriseEco, _ lev: EntrepriseLevierEffets) -> Double {
        let q = facteurQualite(e.qualite, qualiteDemande)
        let mk = facteurMarketing(e.marketing)
        let rep = 0.5 + Double(e.reputation) / 100
        let elan = max(0.3, 1 + Double(e.elan) / 100)
        let prixF = pow(max(0.3, e.prix), -eco.elasticite)
        let leviers = max(0.2, 1 + Double(lev.demande ?? 0) / 100)
        let concurrence = 1 / max(0.5, e.pression)
        let gestion = max(0.7, 1 - 0.03 * Double(postesCadresManquants(e)))
        return q * mk * rep * elan * prixF * leviers * concurrence * gestion
    }

    /// Simule l'année. `alea` = hasard du marché (bilan) ; sans hasard pour l'estimation.
    /// `patronDisponible` : le joueur n'a ni emploi ni études et donne un coup de main.
    static func annee(_ e: Entreprise, _ eco: EntrepriseEco, patronDisponible: Bool, alea: Double = 1, age: Int) -> EntrepriseRapport {
        let lev = effetsLeviers(e, eco)
        let usines = max(0, e.usines)
        let marche = eco.marche(sites: e.sites)
        let part = min(0.95, partDeBase * attractivite(e, eco, lev))
        let demande = marche * part * alea

        let besoin = max(0.01, eco.effectifNecessaire(sites: e.sites, usines: usines))
        let bras = Double(max(0, e.effectif)) + travailDuPatron(patronDisponible)
        let encadrement = min(1, bras * productivite(e, lev, patronDisponible: patronDisponible) / besoin)
        let capaciteUnites = eco.capaciteUnites(sites: e.sites, usines: usines) * max(0.2, 1 + Double(lev.capacite ?? 0) / 100)
        let capacite = capaciteUnites * encadrement
        let ventes = max(0, min(demande, capacite))

        let prixVente = eco.prixUnitaire * e.prix * max(0.2, 1 + Double(lev.prix ?? 0) / 100)
        let ca = ventes * prixVente
        let achats = ventes * eco.coutVariable * facteurQualite(e.qualite, qualiteCout) * max(0.2, 1 + Double(lev.coutVariable ?? 0) / 100)
        let salaires = Double(max(0, e.effectif)) * Double(eco.type.salaireEmploye) * e.salaireNiveau
            + Double(e.employes.reduce(0) { $0 + $1.salaire })
        let loyers = Double(e.sites) * eco.loyerSite + Double(usines) * eco.loyerUsine
        let marketing = ca * Double(e.marketing) / 100
        let leviers = Double(coutAnnuelLeviers(e, eco))
        var banque = 0
        if e.dette > 0 {
            let interets = Int(Double(e.dette) * EntrepriseMoteur.tauxInteret)
            let rembourse = min(e.dette, max(1, e.detteInitiale / EntrepriseMoteur.dureeEmprunt))
            banque = interets + rembourse
        }
        let resultat = Int(ca - achats - salaires - loyers - marketing - leviers) - banque

        return EntrepriseRapport(age: age, marche: Int(marche), demande: Int(demande), capacite: Int(capacite),
                                 ventes: Int(ventes), prixVente: prixVente, chiffreAffaires: Int(ca),
                                 achats: Int(achats), salaires: Int(salaires), loyers: Int(loyers),
                                 marketing: Int(marketing), leviers: Int(leviers), banque: banque,
                                 resultat: resultat, tresorerie: e.tresorerie + resultat,
                                 effectif: max(0, e.effectif), sites: e.sites, usines: usines,
                                 reputation: e.reputation, moral: e.moral, partDeMarche: part)
    }

    /// Effectif qui couvre exactement la demande prévue (sans dépasser la capacité des locaux).
    static func effectifConseille(_ e: Entreprise, _ eco: EntrepriseEco, patronDisponible: Bool) -> Int {
        let lev = effetsLeviers(e, eco)
        let usines = max(0, e.usines)
        let part = min(0.95, partDeBase * attractivite(e, eco, lev))
        let demande = eco.marche(sites: e.sites) * part
        let capaciteUnites = eco.capaciteUnites(sites: e.sites, usines: usines) * max(0.2, 1 + Double(lev.capacite ?? 0) / 100)
        guard capaciteUnites > 0 else { return max(0, e.effectif) }
        let besoinPlein = eco.effectifNecessaire(sites: e.sites, usines: usines)
        let besoin = besoinPlein * min(1, demande / capaciteUnites) / productivite(e, lev, patronDisponible: patronDisponible)
        let total = besoin - travailDuPatron(patronDisponible)
        return max(0, Int(total.rounded()))
    }

    /// Cible de réputation selon les choix de gestion.
    static func cibleReputation(_ e: Entreprise, _ r: EntrepriseRapport) -> Int {
        var c = 50.0 + Double(e.qualite - 3) * 10
        if e.marketing >= 5 { c += 4 }
        if e.marketing >= 10 { c += 4 }
        let tolere = 0.85 + 0.1 * Double(e.qualite)
        c -= max(0, e.prix - tolere) * 40
        if e.prix <= 0.8 && e.qualite >= 3 { c += 5 }
        if r.demande > 0 && Double(r.clientsRefuses) / Double(r.demande) > 0.2 { c -= 6 }
        return Int(c)
    }

    /// Cible de moral selon les salaires et la charge de travail.
    static func cibleMoral(_ e: Entreprise, _ r: EntrepriseRapport, _ lev: EntrepriseLevierEffets) -> Int {
        var c = 55.0 + (e.salaireNiveau - 1) * 120 + Double(lev.moral ?? 0)
        if r.capacite > 0 && Double(r.demande) > Double(r.capacite) * 1.1 { c -= 12 }
        if r.tauxOccupation < 0.5 { c += 5 }
        return Stats.borne(Int(c))
    }

    /// Conseils pour le rapport (3 au plus).
    static func conseils(_ e: Entreprise, _ eco: EntrepriseEco, _ r: EntrepriseRapport, patronDisponible: Bool) -> [String] {
        var c: [String] = []
        let unite = eco.aUsine ? (eco.usine?.nom ?? "usine") : eco.site.nom
        if r.demande > 0 && Double(r.clientsRefuses) / Double(r.demande) > 0.1 {
            let conseille = effectifConseille(e, eco, patronDisponible: patronDisponible)
            if conseille > r.effectif {
                c.append("Tu as refusé \(r.clientsRefuses) clients faute de bras : passe à environ \(conseille) employés.")
            } else {
                c.append("Tu as refusé \(r.clientsRefuses) clients : tes locaux sont pleins, ouvre un\(eco.aUsine ? "e" : "") \(unite) de plus ou monte tes prix.")
            }
        }
        if r.capacite > 0 && r.tauxOccupation < 0.6 {
            c.append("Tu n'utilises que \(Int(r.tauxOccupation * 100)) % de ta capacité : baisse les prix, fais du marketing ou allège l'effectif.")
        }
        if e.moral < 40 {
            c.append("Le moral de l'équipe est à \(e.moral) % : augmente les salaires avant que tout le monde démissionne.")
        }
        if e.prix > 0.85 + 0.1 * Double(e.qualite) + 0.15 {
            c.append("Les clients trouvent tes prix trop élevés pour la qualité. Monte en gamme ou baisse les prix.")
        }
        if r.chiffreAffaires > 0 && r.resultat < 0 && e.marketing >= 10 {
            c.append("Le marketing te coûte \(e.marketing) % du chiffre d'affaires alors que tu perds de l'argent.")
        }
        if r.demande > r.capacite && e.prix < 1.2 && e.reputation >= 55 {
            c.append("Tu es plein et les clients t'aiment : tu peux sûrement augmenter tes prix.")
        }
        if e.dette > 0 && e.tresorerie > e.dette * 2 {
            c.append("Ta trésorerie couvre largement le prêt : rembourse la banque pour arrêter de payer des intérêts.")
        }
        return Array(c.prefix(3))
    }
}

extension EntrepriseMoteur {
    /// Nombre de points de vente à partir duquel on atteint chaque niveau.
    static let seuilsSites = [1, 2, 4, 10, 30, 100]

    static func niveauPourSites(_ sites: Int) -> Int {
        var n = 0
        for (i, s) in seuilsSites.enumerated() where sites >= s { n = i }
        return n
    }

    /// Complète les champs manquants (anciennes sauvegardes, nouvelles boîtes).
    static func normaliser(_ e: inout Entreprise, _ eco: EntrepriseEco, patronDisponible: Bool) {
        if e.sites < 1 { e.sites = 1 }
        if e.usines < 0 { e.usines = eco.aUsine ? max(1, e.sites / 2) : 0 }
        if !eco.aUsine { e.usines = 0 }
        if e.effectif < 0 {
            e.effectif = EntrepriseSimulation.effectifConseille(e, eco, patronDisponible: patronDisponible)
        }
        e.qualite = min(5, max(1, e.qualite))
        e.prix = min(2, max(0.6, e.prix))
        e.salaireNiveau = min(1.4, max(0.8, e.salaireNiveau))
        e.leviers = e.leviers.filter { eco.levier($0) != nil }
        e.niveau = niveauPourSites(e.sites)
        e.niveauMax = max(e.niveauMax, e.niveau)
    }
}

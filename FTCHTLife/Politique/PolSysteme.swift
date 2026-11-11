import Foundation

// La politique change selon le pays où vit le joueur (module « vivre à l'étranger » : j.etatExpat.paysActuel).
// Chaque pays a son système (Data/Politique/Systemes/systemes.json) : régime, noms des postes, institutions,
// mode d'élection, durées, âges, limites de mandats. Format : docs/POLITIQUE.md, section « Selon le pays ».

/// Système politique d'un pays.
struct PolSysteme: Codable, Identifiable, Equatable {
    var id: String
    /// semi_presidentiel, presidentiel, parlementaire, monarchie_parlementaire, monarchie_executive, directorial, parti_unique.
    var regime: String
    /// Poste qui dirige vraiment l'exécutif : "president", "premierMinistre" ou "ministre" (collège, Suisse).
    var chefExecutif: String
    /// « le président de la République », « le roi »…
    var chefEtat: String
    var resume: String
    /// [nom, « à/en … », « de … »] : ["la France", "en France", "de la France"].
    var pays: [String]
    var capitale: String
    /// Siège du chef de l'exécutif, en 3 formes.
    var palais: [String]
    /// Siège du gouvernement, en 3 formes.
    var siegeGouvernement: [String]
    /// Chambre principale, en 3 formes.
    var parlement: [String]
    var chambreHaute: [String]?
    /// [nom de l'union, siège] (Union européenne, Union africaine), ou nil : pas de poste de commissaire.
    var union: [String]?
    /// Noms locaux des postes : [masculin, féminin]. Absent = nom français.
    var postes: [String: [String]]
    /// Postes qui n'existent pas dans ce pays.
    var absents: [String]?
    /// Mode d'élection par poste : "directe", "indirecte" ou "nomination" (absent = règle française).
    var election: [String: String]
    var durees: [String: Int]
    var agesMin: [String: Int]
    var mandatsMax: [String: Int]
    var deuxTours: Bool?
    /// Nom de la procédure pour faire passer un texte sans vote (nil = impossible).
    var passerEnForce: String?
    var referendum: Bool?
    var dissolution: Bool?
    /// Gouvernements de coalition fréquents.
    var coalitions: Bool?
    /// Le parti au pouvoir est très avantagé, l'opposition gênée.
    var electionsControlees: Bool?
    /// Un seul parti : les carrières se font par désignation interne.
    var partiUnique: Bool?
    /// Parrainages d'élus exigés pour la présidentielle.
    var parrainages: Bool?
}

extension PolSysteme {
    /// Système de secours si les données manquent (France).
    static let secours = PolSysteme(
        id: "fr", regime: "semi_presidentiel", chefExecutif: "president", chefEtat: "le président de la République",
        resume: "République semi-présidentielle.", pays: ["la France", "en France", "de la France"], capitale: "Paris",
        palais: ["l'Élysée", "à l'Élysée", "de l'Élysée"], siegeGouvernement: ["Matignon", "à Matignon", "de Matignon"],
        parlement: ["l'Assemblée nationale", "à l'Assemblée nationale", "de l'Assemblée nationale"],
        chambreHaute: ["le Sénat", "au Sénat", "du Sénat"], union: ["l'Union européenne", "Bruxelles"],
        postes: [:], absents: [], election: [:], durees: [:], agesMin: [:], mandatsMax: ["president": 2],
        deuxTours: true, passerEnForce: "l'article 49.3", referendum: true, dissolution: true, coalitions: false,
        electionsControlees: false, partiUnique: false, parrainages: true)

    private func forme(_ f: [String]?, _ i: Int, _ defaut: String) -> String {
        guard let f = f, f.indices.contains(i) else { return defaut }
        return f[i]
    }

    var nomPays: String { forme(pays, 0, "le pays") }
    var auPays: String { forme(pays, 1, "dans le pays") }
    var duPays: String { forme(pays, 2, "du pays") }
    var parlementNom: String { forme(parlement, 0, "le Parlement") }

    /// Le poste existe-t-il dans ce pays ?
    func existe(_ p: PolPoste) -> Bool {
        if (absents ?? []).contains(p.rawValue) { return false }
        if p == .commissaire { return union != nil }
        return true
    }

    /// Nom local du poste.
    func nom(_ p: PolPoste, _ genre: Genre) -> String {
        if let n = postes[p.rawValue], n.count == 2 { return genre == .femme ? n[1] : n[0] }
        return p.nom(genre)
    }

    /// "directe", "indirecte" ou "nomination".
    func modeElection(_ p: PolPoste) -> String {
        if let m = election[p.rawValue] { return m }
        if !p.estElu { return "nomination" }
        return p.electionIndirecte ? "indirecte" : "directe"
    }

    func estElectif(_ p: PolPoste) -> Bool { existe(p) && modeElection(p) != "nomination" }
    func estIndirecte(_ p: PolPoste) -> Bool { modeElection(p) == "indirecte" }
    func duree(_ p: PolPoste) -> Int? { durees[p.rawValue] ?? p.duree }
    func ageMin(_ p: PolPoste) -> Int { agesMin[p.rawValue] ?? p.ageMin }

    /// Le chef de l'exécutif est le Premier ministre (régime parlementaire).
    var executifParlementaire: Bool { chefExecutif == "premierMinistre" }
    /// Le président n'a qu'un rôle symbolique (régimes parlementaires et collégial).
    var presidentSymbolique: Bool { chefExecutif != "president" }
    var estPartiUnique: Bool { partiUnique == true }

    /// « la Commission européenne », « la Commission de l'Union africaine ».
    var commission: String {
        guard let u = union?.first else { return "la Commission" }
        return u == "l'Union européenne" ? "la Commission européenne" : "la Commission de " + u
    }

    /// Pays de l'Union européenne (vote aux municipales pour les citoyens européens).
    var estUE: Bool { union?.first == "l'Union européenne" }
}

extension PolCatalogue {
    static let systemes: [PolSysteme] = DonneesJSON.chargerTableaux(dossier: "Politique/Systemes", type: PolSysteme.self)
    private static let systemesParId: [String: PolSysteme] = Dictionary(systemes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func systeme(_ id: String?) -> PolSysteme {
        systemesParId[id ?? "fr"] ?? systemesParId["fr"] ?? .secours
    }

    /// Partis d'un pays (un parti sans champ `pays` est français).
    static func partisDuPays(_ pays: String?) -> [PolParti] {
        let id = pays ?? "fr"
        return partis.filter { ($0.pays ?? ["fr"]).contains(id) }
    }
}

extension PolPoste {
    /// Nom du poste dans le pays où vit le joueur.
    func nom(_ j: Joueur) -> String { PolMoteur.systeme(j).nom(self, j.genre) }
}

extension PolMoteur {
    /// Système politique du pays où vit le joueur.
    static func systeme(_ j: Joueur) -> PolSysteme { PolCatalogue.systeme(j.etatExpat.paysActuel) }

    /// Le dossier ou la loi peut sortir dans ce pays.
    static func autoriseDansPays(_ pays: [String]?, _ e: PolEtat) -> Bool {
        guard let p = pays else { return true }
        return p.contains(e.paysId ?? "fr")
    }

    /// Le joueur peut se présenter dans ce pays (nationalité, ou citoyen européen aux municipales d'un pays de l'Union).
    static func peutSePresenterIci(_ p: PolPoste, _ j: Joueur) -> Bool {
        let s = systeme(j)
        let x = j.etatExpat
        if x.nationalites.contains(s.id) { return true }
        if s.estUE && (p == .conseiller || p == .adjoint) {
            return x.nationalites.contains { PolCatalogue.systeme($0).estUE && $0 == PolCatalogue.systeme($0).id }
        }
        return false
    }

    /// Au passage d'année : si le joueur a changé de pays, sa vie politique repart de zéro (sauf son passé).
    static func verifierPays(_ j: inout Joueur, _ e: inout PolEtat, _ l: inout [String]) {
        let s = systeme(j)
        defer { e.paysId = s.id }
        guard let ancien = e.paysId, ancien != s.id else { return }
        let avaitUneCarriere = e.mandat != nil || e.partiId != nil || e.candidature != nil
        if e.mandat != nil { terminerMandat(&j, &e, fin: "départ à l'étranger") }
        e.candidature = nil
        e.investiture = nil
        if let pid = e.partiId, pid != "perso" || e.partiPerso == nil {
            if !(PolCatalogue.parti(pid)?.pays ?? ["fr"]).contains(s.id) {
                e.partiId = nil
                e.rangParti = 0
                e.courant = nil
            }
        }
        if e.partiPerso != nil && e.partiId == "perso" {
            e.partiId = nil
            e.rangParti = 0
        }
        e.loisActives = []
        e.loisTentees = []
        e.dossiers = []
        e.rivaux = []
        e.premierMinistrePNJ = nil
        e.majorite = 50
        e.mobilisation = 0
        e.segments = [:]
        e.pays = PolPays()
        e.influence = max(5, e.influence / 3)
        e.popularite = 15
        e.parrainages = 0
        e.mandatsPresident = 0
        e.dissolutionFaite = false
        e.decrets = []
        e.international = PolInternational()
        if avaitUneCarriere {
            l.append("🌍 Nouvelle vie politique \(s.auPays) : \(s.resume) Ton parcours passé ne compte presque plus ici, ton réseau est à reconstruire.")
        }
    }

    /// Ajoute un dossier de coalition quand le joueur gouverne sans majorité absolue dans un pays de coalitions.
    static func coalitionSiBesoin(_ j: Joueur, _ e: inout PolEtat, _ l: inout [String], chance: Double = 1) {
        let s = systeme(j)
        guard s.coalitions == true, e.majorite < 50, let m = e.mandat,
              Double.random(in: 0...1) < chance, e.dossiers.count < 6,
              let d = tirerDossier(kind: "coalition", poste: m.poste.rawValue, j, e) else { return }
        e.dossiers.append(PolDossierEnAttente(dossierId: d.id, ageArrivee: j.age))
        l.append("🤝 Sans majorité absolue, il faut négocier : « \(d.title) » (onglet Politique).")
    }
}

extension PolMoteur {
    /// Remplace les variables d'institutions ({palais}, {au_parlement}, {du_pays}…) par celles du pays.
    static func remplirInstitutions(_ texte: String, _ s: PolSysteme) -> String {
        func f(_ v: [String]?, _ i: Int, _ d: String) -> String {
            guard let v = v, v.indices.contains(i) else { return d }
            return v[i]
        }
        let haute = s.chambreHaute ?? s.parlement
        let remplacements: [(String, String)] = [
            ("{au_pays}", s.auPays), ("{du_pays}", s.duPays), ("{pays}", s.nomPays),
            ("{capitale}", s.capitale), ("{chef_etat}", s.chefEtat),
            ("{au_palais}", f(s.palais, 1, "au palais")), ("{du_palais}", f(s.palais, 2, "du palais")), ("{palais}", f(s.palais, 0, "le palais")),
            ("{au_siege_gouv}", f(s.siegeGouvernement, 1, "au siège du gouvernement")),
            ("{du_siege_gouv}", f(s.siegeGouvernement, 2, "du siège du gouvernement")),
            ("{siege_gouv}", f(s.siegeGouvernement, 0, "le siège du gouvernement")),
            ("{au_parlement}", f(s.parlement, 1, "au Parlement")), ("{du_parlement}", f(s.parlement, 2, "du Parlement")),
            ("{parlement}", f(s.parlement, 0, "le Parlement")),
            ("{au_senat}", f(haute, 1, "au Parlement")), ("{du_senat}", f(haute, 2, "du Parlement")), ("{senat}", f(haute, 0, "le Parlement")),
            ("{siege_union}", f(s.union, 1, "la capitale de l'Union")), ("{union}", f(s.union, 0, "l'Union")),
        ]
        var t = texte
        for (cle, valeur) in remplacements where t.contains(cle) {
            t = t.replacingOccurrences(of: cle, with: valeur)
        }
        return t
    }
}

extension String {
    /// Première lettre en minuscule, le reste intact (« Député au Bundestag » → « député au Bundestag »).
    func polMinuscule() -> String {
        guard let premier = first else { return self }
        return premier.lowercased() + String(dropFirst())
    }
}

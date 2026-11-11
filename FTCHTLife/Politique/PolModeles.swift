import Foundation

// Carrière politique : types de données et catalogue.
// Format des fichiers JSON et branchement dans le moteur : docs/POLITIQUE.md.

// MARK: - Postes

/// Les mandats possibles, du plus modeste au plus haut.
enum PolPoste: String, Codable, CaseIterable, Identifiable {
    case conseiller, adjoint, conseillerRegional, maire, presidentRegion, depute, senateur, presidentAssemblee
    case ministre, premierMinistre, commissaire, president, secretaireGeneral

    var id: String { rawValue }

    /// Nom du poste accordé au genre du joueur.
    func nom(_ genre: Genre) -> String {
        let f = genre == .femme
        switch self {
        case .conseiller: return f ? "Conseillère municipale" : "Conseiller municipal"
        case .adjoint: return f ? "Adjointe au maire" : "Adjoint au maire"
        case .conseillerRegional: return f ? "Conseillère régionale" : "Conseiller régional"
        case .maire: return "Maire"
        case .presidentRegion: return f ? "Présidente de région" : "Président de région"
        case .depute: return f ? "Députée" : "Député"
        case .senateur: return f ? "Sénatrice" : "Sénateur"
        case .presidentAssemblee: return f ? "Présidente de l'Assemblée" : "Président de l'Assemblée"
        case .ministre: return "Ministre"
        case .premierMinistre: return f ? "Première ministre" : "Premier ministre"
        case .commissaire: return f ? "Commissaire européenne" : "Commissaire européen"
        case .president: return f ? "Présidente de la République" : "Président de la République"
        case .secretaireGeneral: return f ? "Secrétaire générale de l'Organisation des Nations" : "Secrétaire général de l'Organisation des Nations"
        }
    }

    /// Durée du mandat en années (nil = pas de durée fixe : on peut être remercié à tout moment).
    var duree: Int? {
        switch self {
        case .conseiller, .maire, .conseillerRegional, .presidentRegion, .senateur: return 6
        case .depute, .president, .presidentAssemblee, .commissaire, .secretaireGeneral: return 5
        case .adjoint, .ministre, .premierMinistre: return nil
        }
    }

    /// Indemnité annuelle (versée chaque année en plus d'un éventuel salaire).
    var indemnite: Int {
        switch self {
        case .conseiller: return 2_400
        case .adjoint: return 14_000
        case .conseillerRegional: return 18_000
        case .maire: return 38_000
        case .presidentRegion: return 70_000
        case .depute: return 92_000
        case .senateur: return 95_000
        case .presidentAssemblee: return 140_000
        case .ministre: return 135_000
        case .premierMinistre: return 165_000
        case .commissaire: return 260_000
        case .president: return 190_000
        case .secretaireGeneral: return 300_000
        }
    }

    /// S'obtient par une candidature (sinon par nomination).
    var estElu: Bool {
        switch self {
        case .adjoint, .ministre, .premierMinistre, .commissaire: return false
        default: return true
        }
    }

    /// Élu par d'autres élus (grands électeurs, conseillers, députés, pays) : la popularité compte peu, le réseau beaucoup.
    var electionIndirecte: Bool {
        switch self {
        case .presidentRegion, .senateur, .presidentAssemblee, .secretaireGeneral: return true
        default: return false
        }
    }

    /// Ordre hiérarchique (sert à savoir si un nouveau mandat est une promotion).
    var rang: Int {
        switch self {
        case .conseiller: return 0
        case .adjoint, .conseillerRegional: return 1
        case .maire: return 2
        case .presidentRegion, .depute: return 3
        case .senateur, .presidentAssemblee, .ministre: return 4
        case .premierMinistre, .commissaire: return 5
        case .president: return 6
        case .secretaireGeneral: return 7
        }
    }

    /// Niveau des lois que ce poste peut faire voter.
    var niveauLois: String? {
        switch self {
        case .conseiller, .conseillerRegional: return nil
        case .adjoint, .maire: return "municipal"
        case .presidentRegion: return "regional"
        case .depute, .senateur, .presidentAssemblee, .ministre, .premierMinistre, .president: return "national"
        case .commissaire, .secretaireGeneral: return "international"
        }
    }

    /// Poste qui gouverne le pays (bilan national, crises).
    var gouverne: Bool { self == .ministre || self == .premierMinistre || self == .president }

    /// Montant de campagne qui donne le bonus maximal.
    var budgetReference: Int {
        switch self {
        case .conseiller, .adjoint: return 3_000
        case .conseillerRegional: return 8_000
        case .maire: return 25_000
        case .depute: return 90_000
        case .president: return 2_000_000
        default: return 1
        }
    }

    /// Caution à payer pour se présenter.
    var caution: Int {
        switch self {
        case .conseillerRegional: return 1_000
        case .maire: return 1_500
        case .depute: return 6_000
        case .president: return 150_000
        default: return 0
        }
    }

    /// Facilité de l'élection (ajoutée au score).
    var facilite: Double {
        switch self {
        case .conseiller: return 18
        case .conseillerRegional: return 10
        case .maire: return 2
        case .depute: return -4
        case .senateur: return 5
        case .president: return -14
        case .secretaireGeneral: return -10
        default: return 0
        }
    }

    /// Âge minimum pour se présenter.
    var ageMin: Int {
        switch self {
        case .senateur: return 24
        case .president, .secretaireGeneral: return 35
        default: return 18
        }
    }
}

/// Les six groupes d'électeurs.
enum PolSegment: String, CaseIterable, Identifiable {
    case jeunes, retraites, ruraux, urbains, patrons, fonctionnaires

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .jeunes: return "Jeunes"
        case .retraites: return "Retraités"
        case .ruraux: return "Ruraux"
        case .urbains: return "Urbains"
        case .patrons: return "Patrons"
        case .fonctionnaires: return "Fonctionnaires"
        }
    }

    /// Poids dans une élection (les jeunes votent peu, les retraités beaucoup).
    var poids: Double {
        switch self {
        case .jeunes: return 0.12
        case .retraites: return 0.24
        case .ruraux: return 0.16
        case .urbains: return 0.22
        case .patrons: return 0.07
        case .fonctionnaires: return 0.19
        }
    }

    var icone: String {
        switch self {
        case .jeunes: return "figure.skateboarding"
        case .retraites: return "figure.walk.motion"
        case .ruraux: return "leaf.fill"
        case .urbains: return "building.2.fill"
        case .patrons: return "briefcase.fill"
        case .fonctionnaires: return "doc.on.clipboard.fill"
        }
    }
}

/// Indicateurs du pays, jugés par les électeurs quand le joueur gouverne.
struct PolPays: Codable, Equatable {
    /// Dette publique en % du PIB.
    var dette: Double = 98
    /// Taux de chômage en %.
    var chomage: Double = 8
    /// Croissance en %.
    var croissance: Double = 1.2
    /// Sentiment de sécurité (0-100).
    var securite: Int = 55
    /// Moral national (0-100).
    var moral: Int = 45

    mutating func borner() {
        dette = min(250, max(10, dette))
        chomage = min(30, max(2, chomage))
        croissance = min(7, max(-6, croissance))
        securite = Stats.borne(securite)
        moral = Stats.borne(moral)
    }
}

/// Rival politique récurrent.
struct PolRival: Codable, Equatable, Identifiable {
    var id = UUID()
    var prenom: String
    var nom: String
    var genre: Genre
    var partiId: String?
    /// Rancune envers le joueur (0-100).
    var rancune: Int = 20
    /// Rang de carrière atteint (comme PolPoste.rang).
    var niveau: Int = 0
    /// Nombre d'élections où il a affronté le joueur.
    var duels: Int = 0
    var nomComplet: String { "\(prenom) \(nom)" }
}

/// Personnage non joueur du gouvernement (Premier ministre nommé par le joueur président, par exemple).
struct PolPNJ: Codable, Equatable, Identifiable {
    var id = UUID()
    var prenom: String
    var nom: String
    var genre: Genre
    /// "loyal", "ambitieux", "populaire", "technocrate", "gaffeur".
    var trait: String
    var loyaute: Int = 60
    var nomComplet: String { "\(prenom) \(nom)" }
}

/// Rôles de l'équipe du joueur.
enum PolRole: String, Codable, CaseIterable, Identifiable {
    case directeur, plume, com, tresorier, garde

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .directeur: return "Directeur·rice de campagne"
        case .plume: return "Plume (écrit tes discours)"
        case .com: return "Conseiller·ère en communication"
        case .tresorier: return "Trésorier·ère"
        case .garde: return "Garde du corps"
        }
    }

    var effet: String {
        switch self {
        case .directeur: return "Bonus à chaque élection directe"
        case .plume: return "Meilleurs débats, popularité en poste"
        case .com: return "Amortit les scandales"
        case .tresorier: return "Plus d'argent aux levées de fonds, moins de casseroles"
        case .garde: return "Protège ta santé"
        }
    }

    var icone: String {
        switch self {
        case .directeur: return "flag.checkered"
        case .plume: return "pencil.and.outline"
        case .com: return "megaphone.fill"
        case .tresorier: return "eurosign.square.fill"
        case .garde: return "shield.lefthalf.filled"
        }
    }

    var salaireBase: Int {
        switch self {
        case .directeur: return 30_000
        case .plume: return 24_000
        case .com: return 34_000
        case .tresorier: return 20_000
        case .garde: return 28_000
        }
    }
}

/// Membre de l'équipe du joueur.
struct PolMembre: Codable, Equatable, Identifiable {
    var id = UUID()
    var role: PolRole
    var prenom: String
    var nom: String
    var genre: Genre
    var competence: Int
    var loyaute: Int
    var salaire: Int
    var nomComplet: String { "\(prenom) \(nom)" }
}

// MARK: - État sauvegardé

/// Mandat en cours.
struct PolMandat: Codable, Equatable {
    var poste: PolPoste
    /// Années restantes (nil = sans échéance).
    var anneesRestantes: Int?
    /// Pour un ministre : identifiant du ministère.
    var ministereId: String?
    /// Nombre de fois que ce mandat a été obtenu d'affilée (réélections).
    var numero: Int = 1
    var ageDebut: Int
}

/// Mandat terminé, pour l'historique et la nécrologie.
struct PolMandatPasse: Codable, Equatable, Identifiable {
    var id = UUID()
    var poste: PolPoste
    var ministereId: String?
    var ageDebut: Int
    var ageFin: Int
    var fin: String
}

/// Campagne en cours : l'élection a lieu au prochain passage d'année.
struct PolCandidature: Codable, Equatable {
    var poste: PolPoste
    var adversaire: String
    var adversairePartiId: String?
    /// Bonus ou malus accumulés pendant la campagne (meetings, débats, coups bas…).
    var points: Double = 0
    var depenses: Int = 0
    var debatFait: Bool = false
    var reelection: Bool = false
    /// Rival affronté (PolRival.id).
    var rivalId: UUID?
    /// Candidature sans l'investiture du parti.
    var dissident: Bool?
}

/// Dossier posé sur le bureau du joueur, à traiter avant le prochain passage d'année.
struct PolDossierEnAttente: Codable, Equatable, Identifiable {
    var id: String { dossierId }
    var dossierId: String
    var ageArrivee: Int
}

/// Tout l'état politique d'une vie. À stocker comme champ optionnel de `Joueur` (`var politique: PolEtat?`).
struct PolEtat: Codable, Equatable {
    var partiId: String?
    /// Fidélité au parti (0-100).
    var loyaute: Int = 50
    /// Ce que les électeurs pensent de toi (0-100).
    var popularite: Int = 15
    /// Réseau, appuis, carnet d'adresses (0-100).
    var influence: Int = 5
    /// Soupçons, affaires, casseroles (0-100).
    var casseroles: Int = 0
    /// Caisse de campagne en euros.
    var caisse: Int = 0
    /// Parrainages d'élus (présidentielle : 500 requis).
    var parrainages: Int = 0
    var mandat: PolMandat?
    var candidature: PolCandidature?
    var historique: [PolMandatPasse] = []
    /// Lois en vigueur (identifiants de Data/Politique/Lois).
    var loisActives: [String] = []
    /// Lois que le joueur a fait adopter.
    var loisVotees: [String] = []
    /// Lois déjà proposées pendant ce mandat (on ne repropose pas une loi rejetée tout de suite).
    var loisTentees: [String] = []
    var dossiers: [PolDossierEnAttente] = []
    var dossiersVus: [String] = []
    var dernierSondage: Int?
    var dernierResultat: String?
    var mandatsPresident: Int = 0
    var elections: Int = 0
    var electionsGagnees: Int = 0
    /// Années d'inéligibilité restantes après une condamnation.
    var ineligibilite: Int = 0
    /// Titres de presse de l'année en cours (remplis au fil des actions).
    var titres: [String] = []
    /// Titres de l'année qui vient de s'écouler, publiés au passage d'année (à lire par le Journal du monde).
    var titresPublies: [String] = []
    /// Flashs du Journal du monde déclenchés par les lois adoptées cette année.
    var flashsMonde: [String] = []
    /// Flashs à publier au passage d'année.
    var flashsPublies: [String] = []

    // Deuxième couche
    /// Opinion de chaque groupe d'électeurs (0-100), clé = PolSegment.rawValue.
    var segments: [String: Int] = [:]
    var pays = PolPays()
    var rivaux: [PolRival] = []
    /// 0 adhérent, 1 cadre, 2 bureau national, 3 chef du parti.
    var rangParti: Int = 0
    var courant: String?
    /// Parti fondé par le joueur.
    var partiPerso: PolParti?
    /// Investiture obtenue pour ce poste (rawValue).
    var investiture: String?
    var equipe: [PolMembre] = []
    /// Premier ministre nommé par le joueur président.
    var premierMinistrePNJ: PolPNJ?
    /// Sièges du camp du joueur à l'Assemblée (%).
    var majorite: Int = 50
    /// Colère sociale (0-100).
    var mobilisation: Int = 0
    var dissolutionFaite: Bool = false
    var memoires: Bool = false
    var fondation: Bool = false
    /// Résultat de la dernière élection, à montrer en événement « soirée électorale » au début de l'année suivante.
    var soiree: PolSoiree?

    init() {}

    // Décodage tolérant : les futurs champs ne cassent pas les anciennes sauvegardes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        partiId = try c.decodeIfPresent(String.self, forKey: .partiId)
        loyaute = try c.decodeIfPresent(Int.self, forKey: .loyaute) ?? 50
        popularite = try c.decodeIfPresent(Int.self, forKey: .popularite) ?? 15
        influence = try c.decodeIfPresent(Int.self, forKey: .influence) ?? 5
        casseroles = try c.decodeIfPresent(Int.self, forKey: .casseroles) ?? 0
        caisse = try c.decodeIfPresent(Int.self, forKey: .caisse) ?? 0
        parrainages = try c.decodeIfPresent(Int.self, forKey: .parrainages) ?? 0
        mandat = try c.decodeIfPresent(PolMandat.self, forKey: .mandat)
        candidature = try c.decodeIfPresent(PolCandidature.self, forKey: .candidature)
        historique = try c.decodeIfPresent([PolMandatPasse].self, forKey: .historique) ?? []
        loisActives = try c.decodeIfPresent([String].self, forKey: .loisActives) ?? []
        loisVotees = try c.decodeIfPresent([String].self, forKey: .loisVotees) ?? []
        loisTentees = try c.decodeIfPresent([String].self, forKey: .loisTentees) ?? []
        dossiers = try c.decodeIfPresent([PolDossierEnAttente].self, forKey: .dossiers) ?? []
        dossiersVus = try c.decodeIfPresent([String].self, forKey: .dossiersVus) ?? []
        dernierSondage = try c.decodeIfPresent(Int.self, forKey: .dernierSondage)
        dernierResultat = try c.decodeIfPresent(String.self, forKey: .dernierResultat)
        mandatsPresident = try c.decodeIfPresent(Int.self, forKey: .mandatsPresident) ?? 0
        elections = try c.decodeIfPresent(Int.self, forKey: .elections) ?? 0
        electionsGagnees = try c.decodeIfPresent(Int.self, forKey: .electionsGagnees) ?? 0
        ineligibilite = try c.decodeIfPresent(Int.self, forKey: .ineligibilite) ?? 0
        titres = try c.decodeIfPresent([String].self, forKey: .titres) ?? []
        titresPublies = try c.decodeIfPresent([String].self, forKey: .titresPublies) ?? []
        flashsMonde = try c.decodeIfPresent([String].self, forKey: .flashsMonde) ?? []
        flashsPublies = try c.decodeIfPresent([String].self, forKey: .flashsPublies) ?? []
        segments = try c.decodeIfPresent([String: Int].self, forKey: .segments) ?? [:]
        pays = try c.decodeIfPresent(PolPays.self, forKey: .pays) ?? PolPays()
        rivaux = try c.decodeIfPresent([PolRival].self, forKey: .rivaux) ?? []
        rangParti = try c.decodeIfPresent(Int.self, forKey: .rangParti) ?? 0
        courant = try c.decodeIfPresent(String.self, forKey: .courant)
        partiPerso = try c.decodeIfPresent(PolParti.self, forKey: .partiPerso)
        investiture = try c.decodeIfPresent(String.self, forKey: .investiture)
        equipe = try c.decodeIfPresent([PolMembre].self, forKey: .equipe) ?? []
        premierMinistrePNJ = try c.decodeIfPresent(PolPNJ.self, forKey: .premierMinistrePNJ)
        majorite = try c.decodeIfPresent(Int.self, forKey: .majorite) ?? 50
        mobilisation = try c.decodeIfPresent(Int.self, forKey: .mobilisation) ?? 0
        dissolutionFaite = try c.decodeIfPresent(Bool.self, forKey: .dissolutionFaite) ?? false
        memoires = try c.decodeIfPresent(Bool.self, forKey: .memoires) ?? false
        fondation = try c.decodeIfPresent(Bool.self, forKey: .fondation) ?? false
        soiree = try c.decodeIfPresent(PolSoiree.self, forKey: .soiree)
    }

    mutating func borner() {
        loyaute = Stats.borne(loyaute)
        popularite = Stats.borne(popularite)
        influence = Stats.borne(influence)
        casseroles = Stats.borne(casseroles)
        caisse = max(0, caisse)
        parrainages = max(0, parrainages)
        majorite = Stats.borne(majorite)
        mobilisation = Stats.borne(mobilisation)
        for k in segments.keys { segments[k] = Stats.borne(segments[k] ?? 40) }
        for i in rivaux.indices { rivaux[i].rancune = Stats.borne(rivaux[i].rancune) }
        pays.borner()
    }

    /// A déjà occupé (ou occupe) ce poste.
    func aOccupe(_ p: PolPoste) -> Bool {
        mandat?.poste == p || historique.contains { $0.poste == p }
    }

    /// Opinion d'un groupe d'électeurs (40 par défaut).
    func opinion(_ s: PolSegment) -> Int { segments[s.rawValue] ?? 40 }

    /// Parti du joueur (catalogue ou parti fondé par lui).
    var parti: PolParti? {
        if let p = partiPerso, p.id == partiId { return p }
        return PolCatalogue.parti(partiId)
    }

    var estChefDeParti: Bool { partiId != nil && rangParti >= 3 }

    /// Rival principal (le plus rancunier).
    var rivalPrincipal: PolRival? { rivaux.max { $0.rancune < $1.rancune } }

    /// Plus haut rang jamais atteint (-1 si aucun mandat).
    var rangMax: Int {
        ([mandat?.poste.rang ?? -1] + historique.map { $0.poste.rang }).max() ?? -1
    }
}

// MARK: - Données JSON

/// Parti politique (Data/Politique/Partis/*.json).
struct PolParti: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var sigle: String
    var slogan: String
    var description: String
    /// Couleur au format "#RRGGBB".
    var couleur: String
    /// "gauche", "droite", "centre", "ailleurs".
    var bord: String
    /// Bonus (ou malus) aux élections.
    var bonusElection: Double
    /// Cotisation annuelle prélevée tant qu'on est membre.
    var cotisation: Int
    /// Influence gagnée en adhérant.
    var influence: Int?
    /// Affinités avec les groupes d'électeurs (bonus au score de ce groupe).
    var segments: [String: Int]?
}

/// Ministère (Data/Politique/Ministeres/*.json).
struct PolMinistere: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
}

/// Effets politiques d'une issue (en points, sauf caisse et parrainages).
struct PolEffets: Codable, Equatable {
    var popularite: Int?
    var influence: Int?
    var casseroles: Int?
    var loyaute: Int?
    var caisse: Int?
    var parrainages: Int?
    /// Bonus de campagne (seulement pendant une candidature).
    var campagne: Double?
    /// Fin du mandat en cours (démission forcée, destitution…). Texte = raison.
    var finMandat: String?
    /// Années d'inéligibilité.
    var ineligibilite: Int?
    /// Fait adopter une loi précise (identifiant).
    var loi: String?
    /// Abroge une loi précise (identifiant).
    var abroger: String?
    /// Exclusion du parti.
    var exclusionParti: Bool?
    /// Opinion des groupes d'électeurs.
    var segments: [String: Int]?
    /// Indicateurs du pays : dette, chomage, croissance, securite, moral.
    var pays: [String: Double]?
    /// Colère sociale.
    var mobilisation: Int?
    /// Sièges du camp du joueur.
    var majorite: Int?
    /// Rancune du rival principal.
    var rival: Int?
}

struct PolIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    /// Effets classiques sur le joueur (format des événements du moteur).
    var effects: Effets?
    var pol: PolEffets?
}

struct PolChoix: Codable, Equatable {
    var label: String
    var outcomes: [PolIssue]
}

/// Dossier, scandale, débat ou moment de campagne (Data/Politique/Dossiers/*.json).
struct PolDossier: Codable, Identifiable, Equatable {
    var id: String
    /// "dossier" (bureau d'élu), "scandale", "debat" (débat télévisé), "campagne" (pendant une campagne), "militant" (vie de parti),
    /// "lobby", "proces", "crise", "parti" (chef de parti), "apres" (ancien élu).
    var kind: String
    /// Postes concernés : "militant", "conseiller", "adjoint", "maire", "depute", "ministre", "president", ou "any".
    /// Pour "debat" et "campagne" : le poste visé par la candidature.
    var postes: [String]
    /// Pour un ministre : ministère concerné (absent = tous).
    var ministere: String?
    var weight: Double?
    var unique: Bool?
    var title: String
    var text: String
    var choices: [PolChoix]
}

/// Loi, arrêté ou décret (Data/Politique/Lois/*.json).
struct PolLoi: Codable, Identifiable, Equatable {
    var id: String
    /// "municipal", "regional", "national" ou "international".
    var niveau: String
    /// Pour une loi nationale : ministère qui peut la porter par décret (absent = seulement députés et président).
    var ministere: String?
    var titre: String
    var description: String
    /// 0 (passe toute seule) à 100 (quasi impossible).
    var difficulte: Int
    /// Effets immédiats à l'adoption.
    var adoption: PolEffets?
    /// Effets appliqués au joueur chaque année tant que la loi est en vigueur.
    var annuel: Effets?
    /// Multiplicateurs de prix (clés du Journal du monde : immobilier, voitures, nourriture, tout…).
    var prix: [String: Double]?
    /// Multiplicateurs de salaires par secteur (clés du Journal du monde : tech, sante, politique, tout…).
    var salaires: [String: Double]?
    /// Autres règles du jeu modifiées, lues par les autres modules (voir docs/POLITIQUE.md).
    var regles: [String: Double]?
    /// Tag ajouté au joueur tant que la loi est en vigueur (utilisable dans conditions.tags des événements).
    var tag: String?
    /// Flash du Journal du monde à déclencher à l'adoption (id `mon_…`, voir docs/MONDE_FORMAT.md).
    var monde: String?
    /// Titre de presse quand la loi passe ({ville}, {prenom}, {nom}, {poste}).
    var headline: String
    var texteAdoption: String
    var texteRejet: String
}

// MARK: - Catalogue

enum PolCatalogue {
    static let partis: [PolParti] = DonneesJSON.chargerTableaux(dossier: "Politique/Partis", type: PolParti.self)
    static let ministeres: [PolMinistere] = DonneesJSON.chargerTableaux(dossier: "Politique/Ministeres", type: PolMinistere.self)
    static let dossiers: [PolDossier] = DonneesJSON.chargerTableaux(dossier: "Politique/Dossiers", type: PolDossier.self)
    static let lois: [PolLoi] = DonneesJSON.chargerTableaux(dossier: "Politique/Lois", type: PolLoi.self)

    private static let dossiersParId: [String: PolDossier] = Dictionary(dossiers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    private static let loisParId: [String: PolLoi] = Dictionary(lois.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func parti(_ id: String?) -> PolParti? { id.flatMap { i in partis.first { $0.id == i } } }
    static func ministere(_ id: String?) -> PolMinistere? { id.flatMap { i in ministeres.first { $0.id == i } } }
    static func dossier(_ id: String) -> PolDossier? { dossiersParId[id] }
    static func loi(_ id: String) -> PolLoi? { loisParId[id] }
}

/// Résultat d'une élection, gardé jusqu'à l'affichage de la soirée électorale.
struct PolSoiree: Codable, Equatable {
    var poste: PolPoste
    var gagne: Bool
    var reelection: Bool
    var adversaire: String
    /// Score final du joueur (second tour pour la présidentielle), en %.
    var score: Double
    /// Score du premier tour (présidentielle seulement).
    var tour1: Double?
    var eliminePremierTour: Bool = false
    /// Participation en % (nil pour une élection indirecte).
    var participation: Double?
}

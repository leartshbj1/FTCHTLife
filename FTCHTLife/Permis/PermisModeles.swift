import Foundation

// MARK: - Système de permis
//
// Permis de conduire (scooter, voiture, moto, poids lourd, bus), bateau, avion,
// hélicoptère, chasse, armes, pêche, drone… et fusée.
// Chaque permis = un code (quiz) puis une épreuve pratique (situations à choix).
// Les permis « route » partagent un capital de points (6 en probatoire, 12 ensuite).
// Branchement au moteur : voir docs/PERMIS.md.

/// Les différents permis du jeu.
enum PermisType: String, Codable, CaseIterable, Identifiable {
    case scooter, voiture, moto, poidsLourd, bus
    case bateau, avion, helicoptere
    case chasse, armes, peche, drone, fusee

    var id: String { rawValue }

    /// Identifiant partagé avec les autres modules (métiers, événements) : tag et clé de licence.
    var cle: String {
        switch self {
        case .scooter: return "permis_scooter"
        case .voiture: return "permis_voiture"
        case .moto: return "permis_moto"
        case .poidsLourd: return "permis_poids_lourd"
        case .bus: return "permis_bus"
        case .bateau: return "permis_bateau"
        case .avion: return "licence_pilote"
        case .helicoptere: return "licence_helico"
        case .chasse: return "permis_chasse"
        case .armes: return "permis_armes"
        case .peche: return "carte_peche"
        case .drone: return "brevet_drone"
        case .fusee: return "permis_fusee"
        }
    }

    var nom: String {
        switch self {
        case .scooter: return "Permis scooter"
        case .voiture: return "Permis voiture"
        case .moto: return "Permis moto"
        case .poidsLourd: return "Permis poids lourd"
        case .bus: return "Permis bus"
        case .bateau: return "Permis bateau"
        case .avion: return "Licence de pilote d'avion"
        case .helicoptere: return "Licence de pilote d'hélicoptère"
        case .chasse: return "Permis de chasse"
        case .armes: return "Permis de port d'arme"
        case .peche: return "Carte de pêche"
        case .drone: return "Brevet de télépilote de drone"
        case .fusee: return "Permis de piloter une fusée"
        }
    }

    /// Nom court, utilisé dans les phrases (« ton permis moto »).
    var nomCourt: String {
        switch self {
        case .scooter: return "permis scooter"
        case .voiture: return "permis voiture"
        case .moto: return "permis moto"
        case .poidsLourd: return "permis poids lourd"
        case .bus: return "permis bus"
        case .bateau: return "permis bateau"
        case .avion: return "licence de pilote"
        case .helicoptere: return "licence d'hélico"
        case .chasse: return "permis de chasse"
        case .armes: return "permis de port d'arme"
        case .peche: return "carte de pêche"
        case .drone: return "brevet de drone"
        case .fusee: return "permis fusée"
        }
    }

    /// Symbole SF Symbols.
    var icone: String {
        switch self {
        case .scooter: return "scooter"
        case .voiture: return "car.fill"
        case .moto: return "bicycle"
        case .poidsLourd: return "box.truck.fill"
        case .bus: return "bus.fill"
        case .bateau: return "sailboat.fill"
        case .avion: return "airplane"
        case .helicoptere: return "fanblades.fill"
        case .chasse: return "hare.fill"
        case .armes: return "scope"
        case .peche: return "fish.fill"
        case .drone: return "antenna.radiowaves.left.and.right"
        case .fusee: return "paperplane.fill"
        }
    }

    var description: String {
        switch self {
        case .scooter: return "50 cm³ de liberté et de bruit."
        case .voiture: return "Le grand classique. Créneau inclus."
        case .moto: return "Pour sentir le vent. Et les moucherons."
        case .poidsLourd: return "38 tonnes et un klaxon qui fait peur."
        case .bus: return "Transporter des gens qui ne disent jamais bonjour."
        case .bateau: return "Pour avoir l'air riche sur un lac."
        case .avion: return "Monomoteur, ciel bleu, angoisse légère."
        case .helicoptere: return "Comme un avion, mais en plus nerveux."
        case .chasse: return "Tirer sur des sangliers qui ne t'ont rien fait."
        case .armes: return "Paperasse, entretien psychologique, coffre-fort."
        case .peche: return "S'asseoir au bord de l'eau et ne rien attraper."
        case .drone: return "Filmer les toits des voisins, légalement."
        case .fusee: return "Le permis le plus cher de la galaxie."
        }
    }

    /// Âge minimum pour s'inscrire.
    var ageMin: Int {
        switch self {
        case .scooter: return 14
        case .voiture: return 18
        case .moto: return 18
        case .poidsLourd: return 21
        case .bus: return 24
        case .bateau: return 16
        case .avion: return 17
        case .helicoptere: return 18
        case .chasse: return 16
        case .armes: return 21
        case .peche: return 10
        case .drone: return 14
        case .fusee: return 30
        }
    }

    /// Prix d'une tentative au code (théorie).
    var prixCode: Int {
        switch self {
        case .scooter: return 30
        case .voiture, .moto: return 50
        case .poidsLourd, .bus: return 200
        case .bateau: return 150
        case .avion: return 1200
        case .helicoptere: return 2500
        case .chasse: return 250
        case .armes: return 300
        case .peche: return 40
        case .drone: return 60
        case .fusee: return 75_000
        }
    }

    /// Prix d'une tentative à l'épreuve pratique (leçons comprises).
    var prixPratique: Int {
        switch self {
        case .scooter: return 350
        case .voiture: return 1600
        case .moto: return 1300
        case .poidsLourd: return 3500
        case .bus: return 4000
        case .bateau: return 400
        case .avion: return 9000
        case .helicoptere: return 22_000
        case .chasse: return 200
        case .armes: return 400
        case .peche: return 20
        case .drone: return 150
        case .fusee: return 2_500_000
        }
    }

    /// Permis qui partagent le capital de points.
    var estRoute: Bool {
        switch self {
        case .scooter, .voiture, .moto, .poidsLourd, .bus: return true
        default: return false
        }
    }

    /// Permis qu'il faut déjà avoir pour s'inscrire.
    var prerequis: [PermisType] {
        switch self {
        case .poidsLourd, .bus: return [.voiture]
        case .fusee: return [.avion]
        default: return []
        }
    }

    /// Chance de base de réussir une situation de l'épreuve pratique avant les stats.
    var difficulte: Double {
        switch self {
        case .scooter, .peche, .drone: return 0.0
        case .voiture, .moto, .bateau, .chasse, .armes: return 0.05
        case .poidsLourd, .bus: return 0.08
        case .avion: return 0.10
        case .helicoptere: return 0.14
        case .fusee: return 0.20
        }
    }

    static var route: [PermisType] { allCases.filter { $0.estRoute } }
}

/// Un permis obtenu.
struct PermisDetenu: Codable, Equatable, Identifiable {
    var type: PermisType
    var ageObtention: Int
    /// Acheté au marché noir. Un contrôle peut le découvrir.
    var faux: Bool = false
    /// Retiré par les autorités (permis hors route ; la route utilise l'annulation).
    var retire: Bool = false

    var id: String { type.rawValue }
}

/// Une infraction inscrite au casier routier.
struct PermisInfraction: Codable, Equatable, Identifiable {
    var id = UUID()
    var age: Int
    var libelle: String
    var points: Int
}

/// Tout l'état « permis » d'une vie. À ranger dans `Joueur.permis` (optionnel).
struct PermisEtat: Codable, Equatable {
    var detenus: [PermisDetenu] = []
    /// Permis dont le code est réussi et qui attendent l'épreuve pratique.
    var codesReussis: [PermisType] = []
    /// Nombre d'échecs par permis (clé = rawValue).
    var echecs: [String: Int] = [:]
    /// Capital de points (permis route).
    var points: Int = 12
    /// Âge auquel le permis route devient définitif (fin de la période probatoire).
    var finProbatoire: Int?
    /// Âge jusqu'auquel le permis route est suspendu.
    var suspenduJusqua: Int?
    /// Âge avant lequel on ne peut pas repasser le permis route après annulation.
    var annuleJusqua: Int?
    /// Âge avant lequel l'inscription à un permis est interdite (fraude à l'examen…), par rawValue.
    var interditJusqua: [String: Int] = [:]
    /// Le joueur prend le volant sans permis valide, tous les jours.
    var conduiteSansPermis: Bool = false
    /// Nombre de fois arrêté sans permis valide.
    var arrestationsSansPermis: Int = 0
    var infractions: [PermisInfraction] = []
    /// Années de suite sans infraction.
    var anneesSansInfraction: Int = 0

    init() {}

    // Décodage tolérant : une ancienne sauvegarde sans un champ récent reste lisible.
    enum CodingKeys: String, CodingKey {
        case detenus, codesReussis, echecs, points, finProbatoire, suspenduJusqua, annuleJusqua
        case interditJusqua, conduiteSansPermis, arrestationsSansPermis, infractions, anneesSansInfraction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        detenus = try c.decodeIfPresent([PermisDetenu].self, forKey: .detenus) ?? []
        codesReussis = try c.decodeIfPresent([PermisType].self, forKey: .codesReussis) ?? []
        echecs = try c.decodeIfPresent([String: Int].self, forKey: .echecs) ?? [:]
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 12
        finProbatoire = try c.decodeIfPresent(Int.self, forKey: .finProbatoire)
        suspenduJusqua = try c.decodeIfPresent(Int.self, forKey: .suspenduJusqua)
        annuleJusqua = try c.decodeIfPresent(Int.self, forKey: .annuleJusqua)
        interditJusqua = try c.decodeIfPresent([String: Int].self, forKey: .interditJusqua) ?? [:]
        conduiteSansPermis = try c.decodeIfPresent(Bool.self, forKey: .conduiteSansPermis) ?? false
        arrestationsSansPermis = try c.decodeIfPresent(Int.self, forKey: .arrestationsSansPermis) ?? 0
        infractions = try c.decodeIfPresent([PermisInfraction].self, forKey: .infractions) ?? []
        anneesSansInfraction = try c.decodeIfPresent(Int.self, forKey: .anneesSansInfraction) ?? 0
    }

    // MARK: Lecture

    func detenu(_ t: PermisType) -> PermisDetenu? {
        detenus.first { $0.type == t && !$0.retire }
    }

    func possede(_ t: PermisType) -> Bool { detenu(t) != nil }

    var aPermisRoute: Bool { detenus.contains { $0.type.estRoute && !$0.retire } }

    func estSuspendu(age: Int) -> Bool {
        if let s = suspenduJusqua, age < s { return true }
        return false
    }

    func estAnnule(age: Int) -> Bool {
        if let a = annuleJusqua, age < a { return true }
        return false
    }

    func estProbatoire(age: Int) -> Bool {
        if let f = finProbatoire, age < f { return true }
        return false
    }

    /// Le joueur peut-il légalement utiliser ce permis ?
    func valide(_ t: PermisType, age: Int) -> Bool {
        guard let d = detenu(t), !d.faux else { return false }
        if t.estRoute && estSuspendu(age: age) { return false }
        return true
    }

    /// Peut conduire légalement au moins un véhicule de la route.
    func conduitLegalement(age: Int) -> Bool {
        PermisType.route.contains { valide($0, age: age) }
    }
}

// MARK: - Données JSON

/// Question du code. Fichiers : Resources/Data/Permis/Code/*.json
struct PermisQuestion: Codable, Identifiable, Equatable {
    var id: String
    /// Types de permis concernés (rawValue), ou "route" pour tous les permis de la route.
    var permis: [String]
    var question: String
    var reponses: [String]
    /// Index de la bonne réponse.
    var bonne: Int
    /// Phrase affichée après la réponse.
    var explication: String?
}

/// Effets d'une situation du permis. Stats en points, argent en euros.
struct PermisEffets: Codable, Equatable {
    var happiness: Int?
    var health: Int?
    var smarts: Int?
    var looks: Int?
    var karma: Int?
    var money: Int?
    /// Points perdus (nombre positif = points retirés).
    var points: Int?
    /// Libellé de l'infraction inscrite au casier (ex. « Excès de vitesse »).
    var infraction: String?
    /// Suspension du permis route, en années.
    var suspension: Int?
    /// Annulation du permis route (il faudra tout repasser).
    var annulation: Bool?
    /// Retrait du permis concerné (permis hors route).
    var retrait: Bool?
    /// Années de prison.
    var prison: Int?
    /// Contrôle de police : sanctionne la conduite sans permis ou avec un faux permis.
    var controle: Bool?
    /// Mort du joueur (la phrase suit « Tu es mort/morte … »).
    var death: String?
    /// Signal de répercussions émis (ex. "amende_vitesse", "accident_voiture"). Voir docs/REPERCUSSIONS.md.
    var signal: String?
}

/// Un choix dans une situation.
struct PermisChoix: Codable, Equatable {
    var label: String
    /// Chance de réussite (0 à 1, défaut 1). Modifiée par les stats à l'examen.
    var chance: Double?
    var success: String
    var failure: String?
    /// À l'examen : gravité de l'erreur en cas d'échec, "mineure" (défaut) ou "eliminatoire".
    var faute: String?
    var onSuccess: PermisEffets?
    var onFailure: PermisEffets?
}

/// Situation à choix : épreuve pratique (Data/Permis/Pratique) ou balade (Data/Permis/Route).
struct PermisScene: Codable, Identifiable, Equatable {
    var id: String
    /// Types de permis concernés (rawValue), "route" ou "any".
    var permis: [String]
    var text: String
    /// Pour les balades : "avec" (permis valide), "sans" (sans permis valide) ou absent (les deux).
    var permisRequis: String?
    var minAge: Int?
    var maxAge: Int?
    var weight: Double?
    var choices: [PermisChoix]
}

/// Incident annuel automatique (journal). Fichiers : Resources/Data/Permis/Incidents/*.json
struct PermisIncident: Codable, Identifiable, Equatable {
    var id: String
    /// Types de permis concernés (rawValue), "route" ou "any".
    var permis: [String]
    /// "avec" (permis valide), "sans" (conduit sans permis valide), absent = avec.
    var permisRequis: String?
    var minAge: Int?
    var maxAge: Int?
    var weight: Double?
    var text: String
    var effects: PermisEffets?
}

/// Ce qui ressort d'une année pour le moteur.
struct PermisBilanAnnee {
    var lignes: [String] = []
    /// Si non nil, le joueur meurt avec cette cause.
    var mort: String?
}

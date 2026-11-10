import Foundation

/// Ce que le moteur de carrière doit savoir du personnage.
/// Le moteur principal construit ce profil à partir de son propre modèle de perso.
struct CareerProfile: Hashable {
    var firstName: String
    var isFemale: Bool = false
    var age: Int
    var education: CareerEducation
    var majors: [String] = []
    var licenses: Set<String> = []
    var smarts: Int = 50
    var looks: Int = 50
    var health: Int = 50
    var happiness: Int = 50
    var karma: Int = 50
    var fame: Int = 0
    var talent: Int = 50
    var charisma: Int = 50
    var athleticism: Int = 50
    var hasCriminalRecord: Bool = false

    func value(of skill: CareerSkill) -> Int {
        switch skill {
        case .smarts: return smarts
        case .looks: return looks
        case .health: return health
        case .talent: return talent
        case .charisma: return charisma
        case .athleticism: return athleticism
        }
    }
}

/// L'emploi en cours du personnage. À sauvegarder avec le perso.
struct CareerJobState: Codable, Hashable {
    var careerId: String
    var level: Int = 0
    var yearsAtLevel: Int = 0
    var yearsInJob: Int = 0
    /// Jauge de performance 0–100.
    var performance: Int = 50
    /// Relations 0–100.
    var bossRelation: Int = 50
    var coworkerRelation: Int = 50
    /// Salaire annuel actuel en euros (peut dépasser celui de l'échelon après des augmentations).
    var salary: Int
    var company: String
    var bossName: String
    var coworkerName: String
    /// Nombre d'actions « travail » déjà faites cette année (limite les abus).
    var actionsThisYear: Int = 0
}

/// Une ligne du CV.
struct CareerRecord: Codable, Hashable {
    let careerId: String
    let title: String
    let company: String
    let startAge: Int
    var endAge: Int?
    var endReason: CareerEndReason?
    var lastSalary: Int
}

enum CareerEndReason: String, Codable {
    case quit, fired, retired, arrested, died, contractEnded

    var label: String {
        switch self {
        case .quit: return "Démission"
        case .fired: return "Licenciement"
        case .retired: return "Retraite"
        case .arrested: return "Arrestation"
        case .died: return "Décès"
        case .contractEnded: return "Fin de contrat"
        }
    }
}

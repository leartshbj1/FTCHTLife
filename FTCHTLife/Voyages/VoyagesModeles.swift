import Foundation

// Module « Voyages sur mesure » : modèles, données et état sauvegardé.
// Données : FTCHTLife/Resources/Data/Voyages (destinations.json, moments_*.json). Format : docs/VOYAGES.md.

// MARK: - Destinations (JSON)

struct VoyDestination: Codable, Identifiable, Hashable {
    let id: String
    let nom: String
    /// « au Japon », « en Italie ».
    let enPays: String
    let drapeau: String
    let continent: String
    /// Distance aller depuis Paris, en km.
    let distance: Int
    /// `route`, `ferry`, `mer` ou `avion`.
    let acces: String
    let cotier: Bool
    let ile: Bool
    let climat: String
    /// Id de langue du module Étranger.
    let langue: String?
    /// Compétence travaillée sur place (langue).
    let competence: String?
    /// Prix par personne et par jour, à l'hôtel.
    let prixJour: Int
    let danger: Int
    let villes: [String]
    let incontournables: [String]
    let specialites: [String]
    let presentation: String

    /// Accessible par la route (avec ou sans ferry).
    var parLaRoute: Bool { acces == "route" || acces == "ferry" }
}

// MARK: - Moments du voyage (JSON)

struct VoyIssue: Codable, Equatable {
    var chance: Double?
    var text: String
    var effects: Effets?
    /// Lien avec le proche désigné par {compagnon}.
    var compagnon: Int?
    /// Lien avec tous les proches présents.
    var compagnons: Int?
    /// État du véhicule personnel utilisé.
    var vehicule: Int?
    /// Ligne gardée dans le carnet de voyages.
    var souvenir: String?
    /// Signal envoyé aux répercussions.
    var signal: String?
}

struct VoyChoix: Codable, Equatable {
    var label: String
    var outcomes: [VoyIssue]
    var requiresSkill: [String: Int]?
}

struct VoyMoment: Codable, Equatable, Identifiable {
    var id: String
    /// `trajet`, `sejour` ou `retour`.
    var phase: String
    var weight: Double?
    var minAge: Int?
    var maxAge: Int?
    var unique: Bool?
    var avec: [String]?
    var seul: Bool?
    var groupe: Bool?
    var transports: [String]?
    var groupes: [String]?
    var destinations: [String]?
    var continents: [String]?
    var climats: [String]?
    var hebergements: [String]?
    var minJours: Int?
    var vehiculeUse: Bool?
    var conditions: ConditionsEvenement?
    var text: String
    var choices: [VoyChoix]

    /// Le même moment vu comme un événement du moteur, pour réutiliser ses conditions (âge, tags, drapeaux…).
    var commeEvenement: Evenement {
        Evenement(id: id, category: "voyage", minAge: minAge ?? 0, maxAge: maxAge ?? 200, weight: weight,
                  unique: nil, conditions: conditions, text: text, effects: nil, choices: nil)
    }
}

/// Toutes les données du module, chargées une fois.
final class VoyCatalogue: @unchecked Sendable {
    static let shared = VoyCatalogue()

    let destinations: [VoyDestination]
    let moments: [VoyMoment]
    private let parId: [String: VoyDestination]

    init() {
        let base = DonneesJSON.dossierData?.appendingPathComponent("Voyages", isDirectory: true)
        let fichiers = (base.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) } ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        func lire<T: Decodable>(_ url: URL, _ type: T.Type) -> [T] {
            do {
                return try JSONDecoder().decode([T].self, from: Data(contentsOf: url))
            } catch {
                print("⚠️ Voyages : \(url.lastPathComponent) invalide : \(error)")
                return []
            }
        }
        destinations = fichiers.filter { $0.lastPathComponent == "destinations.json" }
            .flatMap { lire($0, VoyDestination.self) }
        moments = fichiers.filter { $0.lastPathComponent.hasPrefix("moments_") }
            .flatMap { lire($0, VoyMoment.self) }
        parId = Dictionary(destinations.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func destination(_ id: String) -> VoyDestination? { parId[id] }

    static let continents: [VoyContinent] = [
        VoyContinent(id: "europe", nom: "Europe"), VoyContinent(id: "afrique", nom: "Afrique"),
        VoyContinent(id: "asie", nom: "Asie et Moyen-Orient"), VoyContinent(id: "amerique", nom: "Amériques"),
        VoyContinent(id: "oceanie", nom: "Océanie"), VoyContinent(id: "antarctique", nom: "Antarctique"),
    ]
}

struct VoyContinent: Identifiable, Hashable {
    let id: String
    let nom: String
}

// MARK: - Choix du joueur

enum VoyHebergement: String, Codable, CaseIterable, Identifiable {
    case camping, auberge, habitant, hotel, luxe, palace

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .camping: return "Camping"
        case .auberge: return "Auberge de jeunesse"
        case .habitant: return "Chez l'habitant"
        case .hotel: return "Hôtel"
        case .luxe: return "Hôtel de luxe"
        case .palace: return "Palace"
        }
    }

    /// Pour {hebergement} : « le camping », « ton hôtel »…
    var texte: String {
        switch self {
        case .camping: return "le camping"
        case .auberge: return "l'auberge de jeunesse"
        case .habitant: return "ta famille d'accueil"
        case .hotel: return "ton hôtel"
        case .luxe: return "ton hôtel de luxe"
        case .palace: return "ton palace"
        }
    }

    var icone: String {
        switch self {
        case .camping: return "tent.fill"
        case .auberge: return "bed.double.fill"
        case .habitant: return "house.fill"
        case .hotel: return "building.fill"
        case .luxe: return "star.fill"
        case .palace: return "crown.fill"
        }
    }

    /// Multiplicateur du prix par jour de la destination.
    var multiplicateur: Double {
        switch self {
        case .camping: return 0.35
        case .auberge: return 0.5
        case .habitant: return 0.55
        case .hotel: return 1
        case .luxe: return 2.6
        case .palace: return 6
        }
    }

    var bonheur: Int {
        switch self {
        case .camping: return -1
        case .auberge: return 0
        case .habitant: return 1
        case .hotel: return 2
        case .luxe: return 4
        case .palace: return 6
        }
    }

    var sante: Int {
        switch self {
        case .camping: return -1
        case .auberge, .habitant: return 0
        case .hotel: return 1
        case .luxe, .palace: return 2
        }
    }

    var ageMin: Int { self == .auberge ? 16 : 0 }
}

enum VoyDuree: Int, Codable, CaseIterable, Identifiable {
    case weekend = 3, semaine = 7, quinzaine = 14, mois = 30

    var id: Int { rawValue }
    var jours: Int { rawValue }

    var nom: String {
        switch self {
        case .weekend: return "Un week-end"
        case .semaine: return "Une semaine"
        case .quinzaine: return "Deux semaines"
        case .mois: return "Un mois"
        }
    }

    var bonheur: Int {
        switch self {
        case .weekend: return 4
        case .semaine: return 7
        case .quinzaine: return 10
        case .mois: return 12
        }
    }

    /// Nombre de moments sur place.
    var momentsSejour: Int {
        switch self {
        case .weekend: return 1
        case .semaine, .quinzaine: return 2
        case .mois: return 3
        }
    }
}

/// Type de proche, tel qu'il est écrit dans les moments (`avec`).
enum VoyTypeProche: String, CaseIterable {
    case partenaire, parent, enfant, fratrie, ami

    static func depuis(_ t: TypeRelation) -> VoyTypeProche? {
        switch t {
        case .partenaire: return .partenaire
        case .mere, .pere: return .parent
        case .enfant: return .enfant
        case .frere, .soeur: return .fratrie
        case .ami: return .ami
        case .ex: return nil
        }
    }
}

enum VoyTransportType: String, Codable, CaseIterable, Identifiable {
    case train, autocar, covoiturage, autostop, voitureLocation
    case avionLowCost, avionEco, avionBusiness, avionPremiere, jetLocation
    case ferry, croisiere
    case maVoiture, maMoto, monBateau, monAvion

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .train: return "Train"
        case .autocar: return "Autocar"
        case .covoiturage: return "Covoiturage"
        case .autostop: return "Auto-stop"
        case .voitureLocation: return "Voiture de location"
        case .avionLowCost: return "Avion low cost"
        case .avionEco: return "Avion, classe éco"
        case .avionBusiness: return "Avion, classe affaires"
        case .avionPremiere: return "Avion, première classe"
        case .jetLocation: return "Jet privé de location"
        case .ferry: return "Ferry"
        case .croisiere: return "Croisière"
        case .maVoiture: return "Ta voiture"
        case .maMoto: return "Ta moto"
        case .monBateau: return "Ton bateau"
        case .monAvion: return "Ton avion"
        }
    }

    /// Pour {vehicule} quand ce n'est pas un véhicule du joueur.
    var texte: String {
        switch self {
        case .train: return "le train"
        case .autocar: return "l'autocar"
        case .covoiturage: return "la voiture du covoiturage"
        case .autostop: return "la voiture qui t'a pris{e} en stop"
        case .voitureLocation: return "la voiture de location"
        case .avionLowCost, .avionEco, .avionBusiness, .avionPremiere: return "l'avion"
        case .jetLocation: return "le jet"
        case .ferry: return "le ferry"
        case .croisiere: return "le paquebot"
        case .maVoiture: return "ta voiture"
        case .maMoto: return "ta moto"
        case .monBateau: return "ton bateau"
        case .monAvion: return "ton avion"
        }
    }

    var icone: String {
        switch self {
        case .train: return "tram.fill"
        case .autocar: return "bus.fill"
        case .covoiturage, .voitureLocation, .maVoiture: return "car.fill"
        case .autostop: return "hand.thumbsup.fill"
        case .avionLowCost, .avionEco, .avionBusiness, .avionPremiere, .jetLocation, .monAvion: return "airplane"
        case .ferry, .croisiere: return "ferry.fill"
        case .maMoto: return "bicycle"
        case .monBateau: return "sailboat.fill"
        }
    }

    var groupes: Set<String> {
        switch self {
        case .train: return ["rail"]
        case .autocar, .covoiturage, .autostop, .voitureLocation: return ["route"]
        case .avionLowCost, .avionEco: return ["avion"]
        case .avionBusiness, .avionPremiere, .jetLocation: return ["avion", "luxe"]
        case .ferry: return ["mer"]
        case .croisiere: return ["mer", "luxe"]
        case .maVoiture, .maMoto: return ["route", "perso"]
        case .monBateau: return ["mer", "perso"]
        case .monAvion: return ["avion", "perso"]
        }
    }

    var personnel: Bool { [.maVoiture, .maMoto, .monBateau, .monAvion].contains(self) }
}

// MARK: - Plan et devis

/// Une façon d'y aller, calculée pour une destination donnée.
struct VoyOptionTransport: Identifiable, Hashable {
    var type: VoyTransportType
    /// Véhicule du joueur (`ShopOwnedItem.id`).
    var vehiculeId: UUID?
    var nom: String
    var detail: String
    /// Places au total (joueur compris) ; nil = illimité.
    var places: Int?
    /// Prix par personne, aller-retour.
    var parPersonne: Int
    /// Prix fixe (véhicule, carburant, équipage), aller-retour.
    var fixe: Int
    /// Si plusieurs véhicules sont nécessaires (location, jet) : places par véhicule.
    var placesParVehicule: Int?
    /// Équipage payé à la journée (skipper, pilote).
    var equipageParJour: Int
    var confort: Int
    var karma: Int
    var sante: Int
    var groupes: Set<String>
    /// Raison pour laquelle on ne peut pas (nil = possible).
    var raison: String?
    /// Pour {vehicule} : « ta voiture », « ton jet »…
    var texte: String = ""

    var id: String { type.rawValue + (vehiculeId?.uuidString ?? "") }
}

struct VoyDevis: Equatable {
    var transport: Int
    var hebergement: Int
    var equipage: Int
    var total: Int { transport + hebergement + equipage }
    /// Ce que paie le joueur.
    var partJoueur: Int
    /// Payé par les parents (joueur mineur).
    var parLesParents: Bool
}

// MARK: - Voyage en cours

/// Un moment prêt à être affiché, avec ses textes remplis.
struct VoyMomentAffiche: Identifiable, Equatable {
    let id = UUID()
    let moment: VoyMoment
    let texte: String
    /// Choix visibles (index dans `moment.choices`, libellé rempli).
    let choix: [VoyChoixAffiche]
    /// Proche désigné par {compagnon}.
    let compagnonId: UUID?
    /// Lieu et plat tirés pour ce moment (gardés pour remplir l'issue).
    let incontournable: String
    let specialite: String
    var resultat: String?
}

struct VoyChoixAffiche: Equatable, Identifiable {
    let index: Int
    let label: String
    var id: Int { index }
}

/// Tout ce qu'il faut savoir sur le voyage qui se déroule.
struct VoyEnCours: Equatable {
    var destination: VoyDestination
    var ville: String
    var option: VoyOptionTransport
    var hebergement: VoyHebergement
    var duree: VoyDuree
    var compagnons: [UUID]
    var invite: Bool
    var devis: VoyDevis
    var nouveauPays: Bool
    /// Nom du véhicule pour {vehicule}.
    var vehiculeTexte: String
    var moments: [VoyMomentAffiche] = []
    var index: Int = 0
    var souvenirs: [String] = []
    var termine = false
    var recit: String = ""
}

// MARK: - État sauvegardé

struct VoyRecit: Codable, Equatable, Identifiable {
    var id = UUID()
    var age: Int
    var pays: String
    var ville: String
    var transport: String
    var hebergement: String
    var jours: Int
    var compagnons: [String]
    var cout: Int
    var souvenirs: [String]
}

struct VoyagesEtat: Codable, Equatable {
    var recits: [VoyRecit] = []
    /// Nombre de voyages par pays (id de destination).
    var pays: [String: Int] = [:]
    /// Moments déjà vécus (les moments `unique` ne reviennent pas, les autres moins souvent).
    var momentsVus: [String] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recits = try c.decodeIfPresent([VoyRecit].self, forKey: .recits) ?? []
        pays = try c.decodeIfPresent([String: Int].self, forKey: .pays) ?? [:]
        momentsVus = try c.decodeIfPresent([String].self, forKey: .momentsVus) ?? []
    }

    func voyages(aLAge age: Int) -> Int { recits.filter { $0.age == age }.count }
}

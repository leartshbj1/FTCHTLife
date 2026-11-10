import Foundation
import Combine

// MARK: - Mode Shkurtaaa
//
// Mode triche / bonus activable dans les Paramètres.
// C'est un drapeau GLOBAL (pas lié à une vie) : les autres systèmes
// (argent, prison, carrière, amour, santé, études…) le consultent via
// `Shkurtaaa.shared` ou les raccourcis statiques en bas de ce fichier.
//
// Règle pour les autres systèmes : ne lisez jamais directement UserDefaults,
// passez toujours par les fonctions `Shkurtaaa.*`. Quand le mode est coupé,
// chaque fonction renvoie la valeur d'origine sans rien changer.

/// Un avantage du mode, activable un par un sous l'interrupteur principal.
enum ShkurtaaaPerk: String, CaseIterable, Codable, Identifiable {
    case argentInfini        // Argent jamais sous 100 milliards
    case evasionDirecte      // S'évader de prison d'un clic, à coup sûr
    case casierVierge        // Crimes jamais punis (jamais arrêté)
    case corpsDeFer          // Santé jamais sous 50 %, maladies guéries
    case moralDAcier         // Bonheur jamais sous 50 %
    case statsAuMax          // Toutes les stats à 100 % à la naissance
    case pistonPartout       // Toujours embauché, promotions garanties
    case irresistible        // Drague, couple et demande en mariage toujours acceptés
    case diplomeGaranti      // Toujours admis aux études et aux examens
    case vieEternelle        // Ne meurt jamais de vieillesse

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .argentInfini:   return "Compte en banque infini"
        case .evasionDirecte: return "Évasion express"
        case .casierVierge:   return "Casier vierge"
        case .corpsDeFer:     return "Corps de fer"
        case .moralDAcier:    return "Moral d'acier"
        case .statsAuMax:     return "Né parfait"
        case .pistonPartout:  return "Piston partout"
        case .irresistible:   return "Irrésistible"
        case .diplomeGaranti: return "Diplôme garanti"
        case .vieEternelle:   return "Vie éternelle"
        }
    }

    var detail: String {
        switch self {
        case .argentInfini:   return "Ton compte ne descend jamais sous 100 milliards. Achète tout, ça repousse."
        case .evasionDirecte: return "Un bouton « S'évader » en prison qui marche à tous les coups."
        case .casierVierge:   return "La police ne t'attrape jamais. Jamais."
        case .corpsDeFer:     return "Ta santé ne descend pas sous 50 % et tes maladies guérissent au premier médecin."
        case .moralDAcier:    return "Ton bonheur ne descend pas sous 50 %, même au pire de ta vie."
        case .statsAuMax:     return "Santé, bonheur, intelligence et apparence à 100 % dès la naissance."
        case .pistonPartout:  return "Toutes tes candidatures sont acceptées et chaque promotion est pour toi."
        case .irresistible:   return "Personne ne te dit non : rendez-vous, couple, mariage."
        case .diplomeGaranti: return "Admis partout, examens réussis à chaque fois."
        case .vieEternelle:   return "Tu ne meurs pas de vieillesse. Les accidents restent possibles… sauf avec Corps de fer."
        }
    }

    var symbole: String {
        switch self {
        case .argentInfini:   return "banknote.fill"
        case .evasionDirecte: return "figure.run"
        case .casierVierge:   return "hand.raised.slash.fill"
        case .corpsDeFer:     return "heart.fill"
        case .moralDAcier:    return "face.smiling.inverse"
        case .statsAuMax:     return "star.fill"
        case .pistonPartout:  return "briefcase.fill"
        case .irresistible:   return "flame.fill"
        case .diplomeGaranti: return "graduationcap.fill"
        case .vieEternelle:   return "infinity"
        }
    }

    /// Avantages actifs par défaut quand on allume le mode.
    static let parDefaut: Set<ShkurtaaaPerk> = Set(allCases).subtracting([.vieEternelle, .casierVierge])
}

/// État persistant du mode (sauvegardé dans UserDefaults).
final class Shkurtaaa: ObservableObject {
    static let shared = Shkurtaaa()

    /// Plancher d'argent du mode : 100 milliards.
    static let plancherArgent: Int64 = 100_000_000_000
    /// Plancher de santé / bonheur (sur 100).
    static let plancherStat: Int = 50

    private static let cleActif = "shkurtaaa.actif"
    private static let clePerks = "shkurtaaa.perks"

    private let defaults: UserDefaults

    @Published var estActif: Bool {
        didSet { defaults.set(estActif, forKey: Self.cleActif) }
    }

    @Published var perks: Set<ShkurtaaaPerk> {
        didSet { defaults.set(perks.map(\.rawValue).sorted(), forKey: Self.clePerks) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.estActif = defaults.bool(forKey: Self.cleActif)
        if let brut = defaults.stringArray(forKey: Self.clePerks) {
            self.perks = Set(brut.compactMap(ShkurtaaaPerk.init(rawValue:)))
        } else {
            self.perks = ShkurtaaaPerk.parDefaut
        }
    }

    /// Vrai si le mode est allumé ET cet avantage est coché.
    func a(_ perk: ShkurtaaaPerk) -> Bool {
        estActif && perks.contains(perk)
    }

    func basculer(_ perk: ShkurtaaaPerk) {
        if perks.contains(perk) { perks.remove(perk) } else { perks.insert(perk) }
    }
}

// MARK: - Raccourcis pour les autres systèmes

extension Shkurtaaa {
    static var actif: Bool { shared.estActif }
    static func a(_ perk: ShkurtaaaPerk) -> Bool { shared.a(perk) }

    // Argent ---------------------------------------------------------------

    /// À appliquer après CHAQUE changement d'argent (achat, salaire, amende, vol…).
    static func argent(_ montant: Int64) -> Int64 {
        a(.argentInfini) ? max(montant, plancherArgent) : montant
    }
    static func argent(_ montant: Int) -> Int {
        a(.argentInfini) ? max(montant, Int(plancherArgent)) : montant
    }
    static func argent(_ montant: Double) -> Double {
        a(.argentInfini) ? max(montant, Double(plancherArgent)) : montant
    }
    /// Pour la boutique : vrai si le joueur peut payer `prix` avec `solde`.
    static func peutPayer(_ prix: Int, solde: Int) -> Bool {
        a(.argentInfini) || solde >= prix
    }

    // Prison ---------------------------------------------------------------

    /// Affiche le bouton « S'évader (Shkurtaaa) » en prison.
    static var evasionInstantanee: Bool { a(.evasionDirecte) }
    /// Chance de réussite d'une évasion (0…1).
    static func chanceEvasion(_ base: Double) -> Double {
        a(.evasionDirecte) ? 1 : base
    }
    /// Chance de se faire arrêter après un crime (0…1).
    static func chanceArrestation(_ base: Double) -> Double {
        a(.casierVierge) ? 0 : base
    }

    // Stats ----------------------------------------------------------------

    static func sante(_ valeur: Int) -> Int {
        a(.corpsDeFer) ? max(valeur, plancherStat) : valeur
    }
    static func bonheur(_ valeur: Int) -> Int {
        a(.moralDAcier) ? max(valeur, plancherStat) : valeur
    }
    /// Valeur d'une stat à la naissance.
    static func statNaissance(_ valeur: Int) -> Int {
        a(.statsAuMax) ? 100 : valeur
    }
    /// Chance de guérir d'une maladie lors d'un traitement (0…1).
    static func chanceGuerison(_ base: Double) -> Double {
        a(.corpsDeFer) ? 1 : base
    }

    // Carrière, études, amour ---------------------------------------------

    static func chanceEmbauche(_ base: Double) -> Double { a(.pistonPartout) ? 1 : base }
    static func chancePromotion(_ base: Double) -> Double { a(.pistonPartout) ? 1 : base }
    static func chanceAdmission(_ base: Double) -> Double { a(.diplomeGaranti) ? 1 : base }
    static func chanceExamen(_ base: Double) -> Double { a(.diplomeGaranti) ? 1 : base }
    static func chanceSeduction(_ base: Double) -> Double { a(.irresistible) ? 1 : base }

    // Mort -----------------------------------------------------------------

    /// Le moteur appelle ceci avant de tuer le personnage.
    static func peutMourir(deVieillesse: Bool) -> Bool {
        if deVieillesse && a(.vieEternelle) { return false }
        if !deVieillesse && a(.vieEternelle) && a(.corpsDeFer) { return false }
        return true
    }
}

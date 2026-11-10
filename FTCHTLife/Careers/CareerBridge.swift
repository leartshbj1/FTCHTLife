import Foundation

// Correspondances entre le modèle du moteur (valeurs brutes de ses enums) et le module Carrières.
// Utilise des chaînes pour rester autonome : le moteur passe `joueur.diplome.rawValue`, etc.

extension CareerEducation {
    /// Depuis `Diplome.rawValue` du moteur (`aucun`, `ecoleObligatoire`, `bac`, `licence`, `master`, `doctorat`),
    /// ou directement depuis une valeur de ce module (`cap`, `brevet`…).
    init(diplomeRaw raw: String) {
        switch raw {
        case "aucun": self = .noDiploma
        case "ecoleObligatoire": self = .brevet
        default: self = CareerEducation(rawValue: raw) ?? .noDiploma
        }
    }
}

extension CareerMajor {
    /// Durée d'études typique, en années.
    var durationYears: Int {
        switch id {
        case "medecine": return 9
        case "pharmacie", "dentaire", "veterinaire": return 6
        default: break
        }
        switch level {
        case .cap: return 2
        case .bac, .licence: return 3
        case .master: return 5
        case .doctorat: return 8
        case .noDiploma, .brevet: return 1
        }
    }

    /// Frais d'inscription annuels indicatifs, en euros.
    var annualFees: Int {
        switch level {
        case .cap: return 0
        case .doctorat: return 900
        case .master: return 600
        default: return 300
        }
    }
}

enum CareerMajorMapping {
    /// Filières du moteur (`Filiere.rawValue`) vers les filières du module Carrières.
    static func majors(forFiliereRaw raw: String) -> [String] {
        switch raw {
        case "medecine": return ["medecine"]
        case "droit": return ["droit"]
        case "informatique": return ["informatique"]
        case "commerce": return ["commerce", "economie", "marketing", "comptabilite", "finance"]
        case "arts": return ["arts_plastiques", "design", "musique", "theatre"]
        case "sciences": return ["physique", "chimie", "biologie", "mathematiques"]
        default: return [raw]
        }
    }
}

extension CareerJobState {
    /// Titre du poste actuel (pratique pour remplir `Emploi.titre` du moteur).
    var currentTitle: String {
        CareerCatalog.shared.career(careerId)?.step(level).title ?? "Inconnu"
    }
}

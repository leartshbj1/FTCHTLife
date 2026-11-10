import Foundation

/// Données du module, lues une fois dans `Resources/Data/Scolarite/`.
enum ScolDonnees {
    static let situations: [ScolScene] = DonneesJSON.chargerTableaux(dossier: "Scolarite/Situations", type: ScolScene.self)
    static let convocations: [ScolScene] = DonneesJSON.chargerTableaux(dossier: "Scolarite/Convocations", type: ScolScene.self)
    static let groupes: [ScolGroupe] = DonneesJSON.chargerTableaux(dossier: "Scolarite/Groupes", type: ScolGroupe.self)
    static let actions: [ScolAction] = DonneesJSON.chargerTableaux(dossier: "Scolarite/Actions", type: ScolAction.self)
    static let voyages: [ScolVoyage] = DonneesJSON.chargerTableaux(dossier: "Scolarite/Voyages", type: ScolVoyage.self)
    static let oraux: [ScolOral] = DonneesJSON.chargerTableaux(dossier: "Scolarite/Oraux", type: ScolOral.self)
    static let tousLesTextes: [ScolTexte] = DonneesJSON.chargerTableaux(dossier: "Scolarite/Textes", type: ScolTexte.self)

    static func groupe(_ id: String?) -> ScolGroupe? {
        guard let id = id else { return nil }
        return groupes.first { $0.id == id }
    }

    static func situation(_ id: String) -> ScolScene? { situations.first { $0.id == id } }
    static func convocation(_ id: String) -> ScolScene? { convocations.first { $0.id == id } }
    static func voyage(_ id: String) -> ScolVoyage? { voyages.first { $0.id == id } }

    static func textes(_ type: String) -> [ScolTexte] { tousLesTextes.filter { $0.type == type } }

    static var promesses: [ScolTexte] { textes("promesse") }

    static func promesse(_ id: String?) -> ScolTexte? {
        guard let id = id else { return nil }
        return promesses.first { $0.id == id }
    }

    /// Un texte au hasard parmi ceux qui passent le filtre, ou `defaut`.
    static func auHasard(_ type: String, defaut: String, _ filtre: (ScolTexte) -> Bool = { _ in true }) -> String {
        textes(type).filter(filtre).randomElement()?.text ?? defaut
    }

    // MARK: Matières

    static let nomsMatieres: [String: String] = [
        "francais": "Français", "maths": "Maths", "histoire": "Histoire-géo", "anglais": "Anglais",
        "svt": "SVT", "physique": "Physique-chimie", "eps": "EPS", "arts": "Arts plastiques",
        "musique": "Musique", "techno": "Technologie", "philo": "Philosophie", "ses": "SES",
        "espagnol": "Espagnol", "allemand": "Allemand",
    ]

    static func nomMatiere(_ id: String) -> String { nomsMatieres[id] ?? id.capitalized }

    /// Matières du bulletin selon l'âge (classe).
    /// `lv2` : « espagnol » ou « allemand ».
    static func matieres(age: Int, lv2: String) -> [String] {
        switch age {
        case 11, 12: return ["francais", "maths", "histoire", "anglais", "svt", "eps", "arts", "musique", "techno"]
        case 13, 14: return ["francais", "maths", "histoire", "anglais", lv2, "svt", "physique", "eps", "techno"]
        case 15: return ["francais", "maths", "histoire", "anglais", lv2, "svt", "physique", "ses", "eps"]
        case 16: return ["francais", "maths", "histoire", "anglais", lv2, "svt", "physique", "ses", "eps"]
        default: return ["philo", "maths", "histoire", "anglais", lv2, "ses", "physique", "eps"]
        }
    }

    static func prof(_ matiere: String) -> String {
        auHasard("prof", defaut: ["M. Pichon", "Mme Garnier", "M. Brossard"].randomElement()!) { $0.matiere == matiere }
    }
}

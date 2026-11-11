import Foundation

// Module Beauté : coiffeur et chirurgie esthétique. Voir docs/BEAUTE.md.
// Catalogue : Resources/Data/Beaute/catalogue.json. Événements liés : Data/Events/beaute_NN.json (ids bea_NNNN).

// MARK: - Catalogue

struct BeauteSalon: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    var prix: Int
    /// Chance de base que la coupe soit réussie (0 à 1).
    var talent: Double
    /// Bonus d'apparence en plus quand c'est réussi.
    var prestige: Int
    var ageMin: Int
    /// Le salon fait aussi les couleurs.
    var couleur: Bool
    /// Les parents paient pour les mineurs dans ce salon.
    var mineurs: Bool
    /// Seul salon disponible en prison (et seulement là).
    var prison: Bool?
}

struct BeauteCoupe: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    /// "homme", "femme" ou absent (tout le monde).
    var genre: String?
    /// 0 (sage) à 3 (très audacieux) : plus c'est audacieux, plus ça peut rater et faire parler.
    var audace: Int
    var looks: Int
    /// 0 rasé, 1 court, 2 mi-long, 3 long. Avec une calvitie, seulement 0 et 1.
    var longueur: Int
    var prixFacteur: Double
    /// Années avant que la coupe ne repousse.
    var duree: Int
    var ageMin: Int
}

struct BeauteCouleur: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var audace: Int
    var looks: Int
    var prix: Int
    var ageMin: Int
    var duree: Int
}

struct BeauteClinique: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var description: String
    var prixFacteur: Double
    var risqueFacteur: Double
    var gainBonus: Int
    var illegal: Bool?
    /// Si présent, seules ces interventions sont proposées ici.
    var interventions: [String]?
}

struct BeauteComplication: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var texte: String
    /// Santé et bonheur perdus chaque année tant que ce n'est pas soigné.
    var sante: Int
    var bonheur: Int
    /// Apparence perdue tout de suite (rendue quand c'est soigné).
    var apparence: Int
    /// Années avant guérison seule (99 = jamais sans soin).
    var duree: Int
    var grave: Bool
    /// Prix du soin chez un chirurgien.
    var soin: Int
}

struct BeauteIntervention: Codable, Identifiable, Equatable {
    var id: String
    var nom: String
    var zone: String
    var description: String
    var prix: Int
    var gainMin: Int
    var gainMax: Int
    /// Chance de complication (avant les facteurs de clinique, d'âge, de santé…).
    var risque: Double
    /// Chance d'accident grave au bloc (réanimation, parfois la mort).
    var risqueGrave: Double
    /// Santé perdue pendant la convalescence.
    var sante: Int
    /// Bonheur gagné ou perdu tout de suite (convalescence).
    var bonheur: Int
    /// Années avant que l'effet ne disparaisse (absent = définitif).
    var duree: Int?
    var ageMin: Int
    /// Âge où le résultat est le meilleur : bien avant, l'effet est réduit.
    var ageIdeal: Int?
    var genre: String?
    /// Injection ou soin léger : ne compte pas comme passage au bloc.
    var leger: Bool?
    /// État réparé par l'opération ("calvitie").
    var repare: String?
    /// Tag posé sur le joueur tant que c'est en place (beaute_<marque>).
    var marque: String?
    var complications: [String]
    var reussite: [String]
    var rate: [String]
}

struct BeauteCatalogue: Codable {
    var salons: [BeauteSalon]
    var coupes: [BeauteCoupe]
    var couleurs: [BeauteCouleur]
    var cliniques: [BeauteClinique]
    var complications: [BeauteComplication]
    var interventions: [BeauteIntervention]

    static let vide = BeauteCatalogue(salons: [], coupes: [], couleurs: [], cliniques: [], complications: [], interventions: [])

    /// Lu une fois dans Data/Beaute/catalogue.json.
    static let charge: BeauteCatalogue = {
        guard let url = DonneesJSON.dossierData?.appendingPathComponent("Beaute/catalogue.json"),
              let data = try? Data(contentsOf: url) else { return .vide }
        do {
            return try JSONDecoder().decode(BeauteCatalogue.self, from: data)
        } catch {
            print("⚠️ Catalogue beauté invalide : \(error)")
            return .vide
        }
    }()

    func salon(_ id: String) -> BeauteSalon? { salons.first { $0.id == id } }
    func coupe(_ id: String) -> BeauteCoupe? { coupes.first { $0.id == id } }
    func couleur(_ id: String) -> BeauteCouleur? { couleurs.first { $0.id == id } }
    func clinique(_ id: String) -> BeauteClinique? { cliniques.first { $0.id == id } }
    func complication(_ id: String) -> BeauteComplication? { complications.first { $0.id == id } }
    func intervention(_ id: String) -> BeauteIntervention? { interventions.first { $0.id == id } }

    /// Zones dans l'ordre d'affichage.
    var zones: [String] {
        var vues: [String] = []
        for i in interventions where !vues.contains(i.zone) { vues.append(i.zone) }
        return vues
    }
}

// MARK: - État du joueur (Joueur.beaute)

/// Coupe et couleur actuelles. Le bonus (ou malus) d'apparence est rendu quand ça repousse.
struct BeauteCoiffure: Codable, Equatable {
    var coupe: String
    var couleur: String?
    var salon: String
    var age: Int
    /// Âge auquel la coupe a repoussé (bonus retiré).
    var expire: Int
    /// Apparence ajoutée (ou retirée si raté) par cette coupe.
    var bonus: Int
    var ratee: Bool
}

/// Une intervention faite (ou ratée).
struct BeauteOperation: Codable, Equatable, Identifiable {
    var id = UUID()
    var intervention: String
    var clinique: String
    var age: Int
    /// "reussie", "moyenne", "ratee", "complication", "grave".
    var resultat: String
    /// Apparence gagnée (pour les effets temporaires, retirée à l'expiration).
    var gain: Int
    /// Âge auquel l'effet s'efface (nil = définitif).
    var expire: Int?
    /// Raté pas encore réparé.
    var aReparer: Bool
    var prix: Int
}

/// Complication en cours.
struct BeauteSuite: Codable, Equatable, Identifiable {
    var id = UUID()
    var complication: String
    var intervention: String
    var depuis: Int
    var anneesRestantes: Int
    /// Apparence perdue, rendue au soin ou à la guérison.
    var apparencePerdue: Int
}

struct BeauteEtat: Codable, Equatable {
    var coiffure: BeauteCoiffure?
    var operations: [BeauteOperation] = []
    var suites: [BeauteSuite] = []
    var calvitie: Bool = false
    var calvitieDepuis: Int?
    /// Nombre de passages au coiffeur dans la vie.
    var coiffeurVisites: Int = 0
    var coiffuresRatees: Int = 0
    /// Argent total dépensé chez le chirurgien.
    var depenseChirurgie: Int = 0

    /// Passages au bloc (sans les injections et soins légers).
    var nbBloc: Int {
        operations.filter { op in
            BeauteCatalogue.charge.intervention(op.intervention)?.leger != true
        }.count
    }
}

// MARK: - Effets d'événements (sous-objet "beaute" de effects)

struct BeauteEffets: Codable, Equatable {
    /// Répare tous les ratés (chirurgie réparatrice offerte ou payée par l'événement).
    var reparer: Bool?
    /// Soigne toutes les complications en cours.
    var soigner: Bool?
    /// true : la calvitie commence ; false : elle disparaît.
    var calvitie: Bool?
    /// La coupe actuelle tourne mal (malus d'apparence jusqu'à repousse).
    var coupeRatee: Bool?
    /// Fait une intervention (id du catalogue) dans une clinique (id, par défaut « reconnu »), payée par l'événement.
    var operation: String?
    var clinique: String?
}

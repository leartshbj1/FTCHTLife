import Foundation

enum Donnees {
    static let prenomsHommes = [
        "Lucas", "Hugo", "Gabriel", "Louis", "Arthur", "Jules", "Adam", "Nathan", "Léo", "Noah",
        "Mathis", "Ethan", "Rayan", "Enzo", "Théo", "Kylian", "Yanis", "Samuel", "Liam", "Maxime",
        "Benoît", "Gérard", "Kevin", "Jean-Michel", "Dylan", "Arben", "Driton", "Luca", "Marco", "Bastien"
    ]

    static let prenomsFemmes = [
        "Emma", "Jade", "Louise", "Alice", "Chloé", "Lina", "Léa", "Rose", "Anna", "Mila",
        "Inès", "Julia", "Zoé", "Sarah", "Camille", "Manon", "Lola", "Nina", "Elena", "Clara",
        "Brigitte", "Josiane", "Jessica", "Marie-Thérèse", "Océane", "Albana", "Drita", "Giulia", "Mélanie", "Yasmine"
    ]

    static let noms = [
        "Martin", "Bernard", "Dubois", "Lambert", "Fontaine", "Rousseau", "Girard", "Morel", "Mercier", "Blanc",
        "Favre", "Rochat", "Bonvin", "Pittet", "Gashi", "Berisha", "Krasniqi", "Rossi", "Ferreira", "Da Silva",
        "Lefèvre", "Moreau", "Chevalier", "Perret", "Muller", "Schmid", "Benali", "Nguyen", "Durand", "Petit"
    ]

    static let villes = [
        "Genève", "Lausanne", "Fribourg", "Neuchâtel", "Sion", "Zurich", "Bienne", "Paris", "Lyon",
        "Marseille", "Lille", "Bordeaux", "Bruxelles", "Liège", "Montréal", "Prishtina", "Tirana"
    ]

    static func prenom(_ genre: Genre) -> String {
        (genre == .homme ? prenomsHommes : prenomsFemmes).randomElement()!
    }

    static let metiers: [Metier] = [
        // Sans diplôme
        Metier(id: "plongeur", titre: "Plongeur au kebab", salaire: 28000, diplome: .aucun, filiere: nil, intelligenceMin: 0, apparenceMin: 0),
        Metier(id: "caissier", titre: "Caissier·ère de supermarché", salaire: 32000, diplome: .aucun, filiere: nil, intelligenceMin: 0, apparenceMin: 0),
        Metier(id: "livreur", titre: "Livreur de pizzas", salaire: 30000, diplome: .aucun, filiere: nil, intelligenceMin: 0, apparenceMin: 0),
        Metier(id: "agent_entretien", titre: "Agent d'entretien", salaire: 34000, diplome: .aucun, filiere: nil, intelligenceMin: 0, apparenceMin: 0),
        Metier(id: "mannequin", titre: "Mannequin", salaire: 60000, diplome: .aucun, filiere: nil, intelligenceMin: 0, apparenceMin: 85),
        // Fin de scolarité
        Metier(id: "macon", titre: "Maçon", salaire: 48000, diplome: .ecoleObligatoire, filiere: nil, intelligenceMin: 10, apparenceMin: 0),
        Metier(id: "chauffeur", titre: "Chauffeur de bus", salaire: 50000, diplome: .ecoleObligatoire, filiere: nil, intelligenceMin: 15, apparenceMin: 0),
        Metier(id: "coiffeur", titre: "Coiffeur·euse", salaire: 42000, diplome: .ecoleObligatoire, filiere: nil, intelligenceMin: 10, apparenceMin: 40),
        Metier(id: "vendeur", titre: "Vendeur·euse de téléphones", salaire: 45000, diplome: .ecoleObligatoire, filiere: nil, intelligenceMin: 20, apparenceMin: 30),
        // Bac
        Metier(id: "policier", titre: "Policier·ère", salaire: 62000, diplome: .bac, filiere: nil, intelligenceMin: 30, apparenceMin: 0),
        Metier(id: "secretaire", titre: "Assistant·e administratif·ve", salaire: 55000, diplome: .bac, filiere: nil, intelligenceMin: 30, apparenceMin: 0),
        Metier(id: "influenceur", titre: "Influenceur·euse", salaire: 40000, diplome: .bac, filiere: nil, intelligenceMin: 0, apparenceMin: 70),
        Metier(id: "agent_immo", titre: "Agent immobilier", salaire: 65000, diplome: .bac, filiere: nil, intelligenceMin: 35, apparenceMin: 45),
        // Licence
        Metier(id: "dev", titre: "Développeur·euse", salaire: 95000, diplome: .licence, filiere: .informatique, intelligenceMin: 55, apparenceMin: 0),
        Metier(id: "comptable", titre: "Comptable", salaire: 85000, diplome: .licence, filiere: .commerce, intelligenceMin: 45, apparenceMin: 0),
        Metier(id: "marketing", titre: "Responsable marketing", salaire: 90000, diplome: .licence, filiere: .commerce, intelligenceMin: 40, apparenceMin: 40),
        Metier(id: "graphiste", titre: "Graphiste", salaire: 65000, diplome: .licence, filiere: .arts, intelligenceMin: 25, apparenceMin: 0),
        Metier(id: "chercheur", titre: "Chercheur·euse", salaire: 80000, diplome: .licence, filiere: .sciences, intelligenceMin: 65, apparenceMin: 0),
        Metier(id: "prof", titre: "Enseignant·e", salaire: 88000, diplome: .licence, filiere: nil, intelligenceMin: 50, apparenceMin: 0),
        // Master / doctorat
        Metier(id: "avocat", titre: "Avocat·e", salaire: 140000, diplome: .master, filiere: .droit, intelligenceMin: 60, apparenceMin: 0),
        Metier(id: "juge", titre: "Juge", salaire: 180000, diplome: .master, filiere: .droit, intelligenceMin: 75, apparenceMin: 0),
        Metier(id: "medecin", titre: "Médecin", salaire: 190000, diplome: .doctorat, filiere: .medecine, intelligenceMin: 70, apparenceMin: 0),
        Metier(id: "chirurgien", titre: "Chirurgien·ne", salaire: 280000, diplome: .doctorat, filiere: .medecine, intelligenceMin: 85, apparenceMin: 0),
    ]

    static func metier(_ id: String) -> Metier? { metiers.first { $0.id == id } }

    /// Intitulés des postes selon le niveau atteint (promotions).
    static func titrePromotion(base: String, niveau: Int) -> String {
        switch niveau {
        case 0: return base
        case 1: return base + " confirmé·e"
        case 2: return base + " senior"
        case 3: return "Chef·fe d'équipe (" + base.lowercased() + ")"
        default: return "Directeur·rice (" + base.lowercased() + ")"
        }
    }
}

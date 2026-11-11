import Foundation

/// Données fixes des carrières spéciales : rangs, revenus, noms inventés, œuvres du musée.
enum SpeCatalogue {

    // MARK: - Rangs et revenus

    static func rangs(_ t: SpeCarriereType, femme: Bool) -> [String] {
        switch t {
        case .mma:
            return [femme ? "Amatrice" : "Amateur", "Pro régional" + (femme ? "e" : ""), "Pro national" + (femme ? "e" : ""),
                    "Ligue continentale", "Ligue mondiale", femme ? "Championne du monde" : "Champion du monde"]
        case .sport:
            return ["Centre de formation", "Deuxième division", "Première division", "Grand club", "International" + (femme ? "e" : ""),
                    "Légende"]
        case .mannequin:
            return ["Catalogues", "Agence locale", "Défilés nationaux", "Semaines de la mode", "Égérie", "Top model mondial"]
        case .cinema:
            return ["Courts-métrages", "Premier long métrage", femme ? "Réalisatrice confirmée" : "Réalisateur confirmé",
                    femme ? "Autrice reconnue" : "Auteur reconnu", femme ? "Grande réalisatrice" : "Grand réalisateur", "Légende du cinéma"]
        case .musique:
            return ["Scènes ouvertes", "Artiste local" + (femme ? "e" : ""), "Signé" + (femme ? "e" : "") + " en label", "Disque d'or",
                    "Star", "Légende"]
        }
    }

    static func rang(_ c: SpeCarriere, femme: Bool) -> String {
        let r = rangs(c.type, femme: femme)
        return r[max(0, min(r.count - 1, c.niveau))]
    }

    /// Revenu de référence par an pour un rang (docs/CARRIERES_SPECIALES.md).
    static func revenu(_ t: SpeCarriereType, _ niveau: Int) -> Int {
        let table: [Int]
        switch t {
        case .mma: table = [3_000, 25_000, 80_000, 250_000, 900_000, 3_000_000]
        case .sport: table = [12_000, 60_000, 250_000, 1_200_000, 5_000_000, 15_000_000]
        case .mannequin: table = [8_000, 30_000, 90_000, 300_000, 1_200_000, 6_000_000]
        case .cinema: table = [5_000, 40_000, 120_000, 400_000, 1_500_000, 5_000_000]
        case .musique: table = [2_000, 15_000, 60_000, 250_000, 1_500_000, 8_000_000]
        }
        return table[max(0, min(5, niveau))]
    }

    /// Réputation nécessaire pour atteindre chaque rang.
    static let seuilsReputation = [0, 25, 40, 58, 74, 90]

    // MARK: - Salle de sport

    static let abonnements = ["Aucun abonnement", "Salle de quartier", "Club de boxe et MMA", "Salle premium"]
    static let prixAbonnement = [0, 360, 900, 2_400]
    static let descriptionsAbonnement = [
        "",
        "Machines un peu fatiguées, musique trop forte. Musculation et cardio.",
        "Ring, sacs, tatamis. Cours de boxe inclus, et des gens qui frappent fort.",
        "Coachs diplômés, sauna, serviettes pliées. Tout progresse plus vite.",
    ]
    static let nomsSalles = ["Iron Club", "La Forge", "Fitness du Centre", "Gym Olympe", "Le Hangar", "Muscle Factory", "Club Spartiate",
                             "Atlas Gym", "Le Dojo du Port", "Body Concept"]
    static let nomsClubsCombat = ["Team Fournaise", "Lions de Belleville", "Combat Academy Sud", "Dojo Kaizen", "Team Granit",
                                  "Le Clan du Nord", "Phoenix Fight Club", "Académie Valette"]

    // MARK: - MMA

    static let ligues = ["Gala amateur régional", "Ligue régionale de combat", "Championnat national pro", "Ligue continentale de combat",
                         "Ligue mondiale de combat", "Ligue mondiale de combat"]
    static let coachs = ["Momo Benali", "Karim Duval", "Sylvie Rocard", "Le vieux Tavares", "Dimitri Ivanov", "Jo Lacombe",
                         "Nadia Keller", "Coach Ferhat", "Bruno Massé", "Inès Garnier"]
    static let surnomsAdversaires = ["« Le Bulldozer »", "« La Faux »", "« Marteau »", "« Le Viking »", "« Mamba »", "« Le Boucher »",
                                     "« Tornade »", "« Le Docteur »", "« Pitbull »", "« Silencieux »", "« Le Mur »", "« Cobra »"]

    static func adversaire(_ cle: Int) -> String {
        let prenoms = ["Malik", "Sergueï", "Diego", "Thiago", "Yanis", "Tomasz", "Jonas", "Kenji", "Bilal", "Nikola", "Andreï", "Lucas"]
        let noms = ["Kovac", "Moreira", "Haddad", "Petrov", "Santos", "Dubreuil", "Okafor", "Lindqvist", "Ramos", "Varga", "Mendy", "Nowak"]
        let p = prenoms[abs(cle &* 31) % prenoms.count]
        let n = noms[abs(cle &* 17 &+ 5) % noms.count]
        let s = surnomsAdversaires[abs(cle &* 13 &+ 3) % surnomsAdversaires.count]
        return "\(p) \(s) \(n)"
    }

    // MARK: - Sport

    struct Sport {
        let id: String
        let nom: String
        let emoji: String
        let collectif: Bool
        /// Poids de force, cardio et technique dans le talent.
        let poids: (Double, Double, Double)
        let competition: String
    }

    static let sports: [Sport] = [
        Sport(id: "football", nom: "Football", emoji: "⚽", collectif: true, poids: (0.2, 0.4, 0.4), competition: "le championnat"),
        Sport(id: "basket", nom: "Basket", emoji: "🏀", collectif: true, poids: (0.3, 0.35, 0.35), competition: "le championnat"),
        Sport(id: "tennis", nom: "Tennis", emoji: "🎾", collectif: false, poids: (0.2, 0.3, 0.5), competition: "le circuit"),
        Sport(id: "rugby", nom: "Rugby", emoji: "🏉", collectif: true, poids: (0.5, 0.3, 0.2), competition: "le championnat"),
        Sport(id: "athletisme", nom: "Athlétisme", emoji: "🏃", collectif: false, poids: (0.3, 0.5, 0.2), competition: "la saison"),
        Sport(id: "cyclisme", nom: "Cyclisme", emoji: "🚴", collectif: false, poids: (0.2, 0.7, 0.1), competition: "la saison"),
    ]

    static func sport(_ id: String) -> Sport { sports.first { $0.id == id } ?? sports[0] }

    static let clubs: [String: [[String]]] = [
        "football": [["FC Rives-sur-Loire", "Stade Montvallon", "AS Port-Lambert"], ["US Bréhal", "FC Vallée Grise", "Racing Club du Lac"],
                     ["Olympique de Valcourt", "Stade Lumière", "AS Monterrey-sur-Mer"], ["Real Castellón Norte", "Athletic Lisboa Sul", "FC Rhénanie 1899"],
                     ["Sélection nationale", "Sélection nationale", "Sélection nationale"], ["Real Castellón Norte", "FC Rhénanie 1899", "Olympique de Valcourt"]],
        "basket": [["Espoirs de Montbrun", "Cadets de Saint-Aure"], ["BC Haute-Vienne", "Élan de Pornic"], ["ASVB Valcourt", "Paris Est Basket"],
                   ["Los Angeles Comets", "Madrid Ciudad Basket"], ["Sélection nationale", "Sélection nationale"], ["Los Angeles Comets", "Madrid Ciudad Basket"]],
        "tennis": [["Académie du Tennis-Club de Valcourt"], ["Circuit secondaire"], ["Circuit principal"], ["Top 20 mondial"], ["Top 5 mondial"], ["Numéro un mondial"]],
        "rugby": [["Espoirs du RC Aurillac-Bas"], ["US Montaigu Rugby", "SC Pays Basque Nord"], ["Stade Valcourtois", "RC Varois"],
                  ["Racing Lumière", "Stade de la Garonne"], ["XV national", "XV national"], ["Stade de la Garonne", "Racing Lumière"]],
        "athletisme": [["Club d'athlétisme de Valcourt"], ["Équipe régionale"], ["Équipe de France B"], ["Meetings internationaux"], ["Équipe nationale"], ["Légende des pistes"]],
        "cyclisme": [["Vélo Club Valcourt"], ["Équipe continentale Laforge"], ["Équipe pro Atlantique"], ["Team Horizon World"], ["Team Horizon World"], ["Team Horizon World"]],
    ]

    static func club(_ sport: String, niveau: Int, cle: Int) -> String {
        let liste = clubs[sport] ?? clubs["football"]!
        let n = liste[max(0, min(liste.count - 1, niveau))]
        return n[abs(cle) % n.count]
    }

    // MARK: - Mannequin

    static let agences = [["Agence Vitrine", "Studio Catalogue Plus"], ["Agence Lumière Model", "Visages de Province"],
                          ["Agence Silhouette", "Model Management Rive Gauche"], ["Atelier Models International", "Nova Faces"],
                          ["Atelier Models International", "Nova Faces"], ["Nova Faces", "Atelier Models International"]]
    static let marques = ["Maison Delaunay", "Ostra", "Vellane Paris", "Kiro", "Atelier Mirabeau", "Lune & Sel", "Haute Rive", "Solenne",
                          "Maison Corvo", "Elbaz Couture"]

    // MARK: - Cinéma

    static let genresFilm: [(id: String, nom: String, emoji: String)] = [
        ("comedie", "Comédie", "😂"), ("drame", "Drame", "🎭"), ("action", "Action", "💥"), ("horreur", "Horreur", "👻"),
        ("sf", "Science-fiction", "🚀"), ("documentaire", "Documentaire", "🎥"), ("auteur", "Film d'auteur", "🎞️"),
    ]

    static func nomGenreFilm(_ id: String) -> String { genresFilm.first { $0.id == id }?.nom ?? id }

    /// Budget selon la taille : court, petit, moyen, gros.
    static let budgetsFilm = [15_000, 600_000, 6_000_000, 45_000_000]
    static let taillesFilm = ["Court-métrage", "Petit budget", "Budget moyen", "Gros budget"]
    static let castings = ["Des inconnus", "Des acteurs connus", "Une star"]
    static let surcoutCasting = [0.0, 0.2, 0.5]

    static let motsTitres1 = ["Les Ombres", "Le Dernier", "La Nuit", "Les Enfants", "Le Silence", "La Ligne", "Un Été", "Le Bruit",
                              "Les Heures", "La Promesse", "Le Prix", "Les Racines", "La Fuite", "Le Retour"]
    static let motsTitres2 = ["de Valcourt", "du Port", "sans nom", "d'Octobre", "en Hiver", "des Autres", "de la Colline", "rouge",
                              "après la pluie", "du Nord", "à vendre", "de trop", "invisible", "sous la ville"]

    static func titreFilm(_ cle: Int) -> String {
        "\(motsTitres1[abs(cle &* 7) % motsTitres1.count]) \(motsTitres2[abs(cle &* 11 &+ 3) % motsTitres2.count])"
    }

    // MARK: - Musique

    static let genresMusique: [(id: String, nom: String, emoji: String)] = [
        ("rap", "Rap", "🎤"), ("pop", "Pop", "🎶"), ("rock", "Rock", "🎸"), ("electro", "Électro", "🎧"), ("variete", "Variété", "🎙️"),
        ("jazz", "Jazz", "🎷"),
    ]

    static func nomGenreMusique(_ id: String) -> String { genresMusique.first { $0.id == id }?.nom ?? id }

    static let labels = ["Disques Mirage", "Onde Courte Records", "Label 404", "Maison Sonore", "Satellite Music", "Rive Records"]
    static let nomsGroupes = ["Les Insomniaques", "Néon Brut", "Mauvaise Graine", "Les Voisins du Dessus", "Écho Sud", "Les Volts",
                              "Pluie Acide", "Faubourg 9", "Les Lendemains", "Céleste Panique"]
    static let titresAlbums = ["Premier Jet", "Nuits Blanches", "Béton Tendre", "Tout Doit Disparaître", "Ligne Directe", "Haute Tension",
                               "Les Jours Pairs", "Mémoire Vive", "Plein Ciel", "Retour à Zéro", "Sans Filtre", "Bleu Néon"]
    /// Fans nécessaires pour chaque rang.
    static let seuilsFans = [0, 2_000, 20_000, 200_000, 2_000_000, 20_000_000]

    // MARK: - Musée

    static let themesMusee: [(id: String, nom: String, emoji: String)] = [
        ("beauxarts", "Beaux-arts", "🖼️"), ("contemporain", "Art contemporain", "🗿"), ("histoire", "Histoire", "🏺"),
        ("sciences", "Sciences et techniques", "🔭"), ("automobile", "Automobile", "🏎️"), ("insolite", "Insolite", "🧦"),
    ]

    static func nomTheme(_ id: String) -> String { themesMusee.first { $0.id == id }?.nom ?? id }

    static let taillesMusee = ["Petit musée", "Musée moyen", "Grand musée", "Musée national"]
    static let prixOuverture = [2_000_000, 10_000_000, 50_000_000, 0]
    static let prixAgrandir = [0, 8_000_000, 40_000_000, 200_000_000]
    static let chargesMusee = [150_000, 600_000, 2_500_000, 8_000_000]
    static let visiteursBase = [15_000, 80_000, 400_000, 1_500_000]
    static let capaciteOeuvres = [8, 20, 50, 120]

    static let oeuvres: [SpeOeuvre] = [
        // Beaux-arts
        SpeOeuvre(id: "o_ba01", nom: "La Liseuse au balcon", auteur: "Henriette Maury", theme: "beauxarts", valeur: 450_000, prestige: 8),
        SpeOeuvre(id: "o_ba02", nom: "Port de Honfleur sous l'orage", auteur: "Jules Varenne", theme: "beauxarts", valeur: 1_200_000, prestige: 12),
        SpeOeuvre(id: "o_ba03", nom: "Autoportrait au chapeau gris", auteur: "Anselme Brugière", theme: "beauxarts", valeur: 3_500_000, prestige: 18),
        SpeOeuvre(id: "o_ba04", nom: "Nature morte aux citrons", auteur: "Clara Vossberg", theme: "beauxarts", valeur: 280_000, prestige: 5),
        SpeOeuvre(id: "o_ba05", nom: "Le Bal des moissons", auteur: "Émile Castagnet", theme: "beauxarts", valeur: 8_000_000, prestige: 26),
        SpeOeuvre(id: "o_ba06", nom: "Vierge à l'oiseau (atelier de)", auteur: "Maître de Sienne", theme: "beauxarts", valeur: 22_000_000, prestige: 38),
        SpeOeuvre(id: "o_ba07", nom: "Les Baigneuses de l'Aude", auteur: "Paul-Henri Sorel", theme: "beauxarts", valeur: 55_000_000, prestige: 52),
        // Contemporain
        SpeOeuvre(id: "o_co01", nom: "Néant n°7", auteur: "Kasia Wren", theme: "contemporain", valeur: 120_000, prestige: 4),
        SpeOeuvre(id: "o_co02", nom: "Chaise renversée (bleu)", auteur: "Tomas Ekberg", theme: "contemporain", valeur: 380_000, prestige: 7),
        SpeOeuvre(id: "o_co03", nom: "Mille Ballons Dégonflés", auteur: "Collectif Rumeur", theme: "contemporain", valeur: 900_000, prestige: 11),
        SpeOeuvre(id: "o_co04", nom: "Banane scotchée (édition 2)", auteur: "Anonyme", theme: "contemporain", valeur: 1_500_000, prestige: 14),
        SpeOeuvre(id: "o_co05", nom: "Mur de néons « Encore »", auteur: "Lina Ortega", theme: "contemporain", valeur: 4_000_000, prestige: 20),
        SpeOeuvre(id: "o_co06", nom: "Le Grand Requin dans le formol", auteur: "Dorian Haskell", theme: "contemporain", valeur: 14_000_000, prestige: 32),
        // Histoire
        SpeOeuvre(id: "o_hi01", nom: "Casque gaulois de Vercourt", auteur: "Fouilles de 1911", theme: "histoire", valeur: 300_000, prestige: 7),
        SpeOeuvre(id: "o_hi02", nom: "Lettres d'un poilu (correspondance complète)", auteur: "Famille Baudry", theme: "histoire", valeur: 90_000, prestige: 6),
        SpeOeuvre(id: "o_hi03", nom: "Sarcophage d'un scribe", auteur: "Moyen Empire", theme: "histoire", valeur: 6_000_000, prestige: 24),
        SpeOeuvre(id: "o_hi04", nom: "Épée d'apparat d'un maréchal", auteur: "Manufacture de Klingenthal", theme: "histoire", valeur: 750_000, prestige: 9),
        SpeOeuvre(id: "o_hi05", nom: "Mosaïque romaine des Saisons", auteur: "Villa de Saint-Romain", theme: "histoire", valeur: 12_000_000, prestige: 30),
        SpeOeuvre(id: "o_hi06", nom: "Carte du monde de 1507 (copie d'époque)", auteur: "Atelier de Saint-Dié", theme: "histoire", valeur: 2_500_000, prestige: 16),
        // Sciences
        SpeOeuvre(id: "o_sc01", nom: "Squelette de tricératops « Gertrude »", auteur: "Dakota, il y a 66 millions d'années", theme: "sciences", valeur: 18_000_000, prestige: 34),
        SpeOeuvre(id: "o_sc02", nom: "Lunette astronomique de 1780", auteur: "Atelier Lerebours", theme: "sciences", valeur: 400_000, prestige: 8),
        SpeOeuvre(id: "o_sc03", nom: "Météorite de Lunel", auteur: "Tombée en 1898", theme: "sciences", valeur: 650_000, prestige: 10),
        SpeOeuvre(id: "o_sc04", nom: "Machine à calculer à roues (réplique ancienne)", auteur: "XVIIIe siècle", theme: "sciences", valeur: 1_100_000, prestige: 12),
        SpeOeuvre(id: "o_sc05", nom: "Capsule d'entraînement spatial", auteur: "Programme spatial, 1971", theme: "sciences", valeur: 3_000_000, prestige: 18),
        // Automobile
        SpeOeuvre(id: "o_au01", nom: "Torpédo 1912 « La Grise »", auteur: "Automobiles Delmas", theme: "automobile", valeur: 700_000, prestige: 9),
        SpeOeuvre(id: "o_au02", nom: "Berline présidentielle de 1965", auteur: "Carrosserie Chapron-Morel", theme: "automobile", valeur: 1_800_000, prestige: 14),
        SpeOeuvre(id: "o_au03", nom: "Monoplace championne 1978", auteur: "Écurie Valcourt", theme: "automobile", valeur: 6_500_000, prestige: 22),
        SpeOeuvre(id: "o_au04", nom: "Coupé prototype à portes papillon", auteur: "Studio Ferrandi", theme: "automobile", valeur: 25_000_000, prestige: 36),
        SpeOeuvre(id: "o_au05", nom: "Mobylette du facteur de Bray", auteur: "1964, 212 000 km", theme: "automobile", valeur: 4_000, prestige: 3),
        // Insolite
        SpeOeuvre(id: "o_in01", nom: "Collection de 4 000 chaussettes orphelines", auteur: "Donation Lemaire", theme: "insolite", valeur: 20_000, prestige: 4),
        SpeOeuvre(id: "o_in02", nom: "Le plus gros tire-bouchon du monde", auteur: "Coutellerie Thiers", theme: "insolite", valeur: 60_000, prestige: 5),
        SpeOeuvre(id: "o_in03", nom: "Grille-pain ayant appartenu à un président", auteur: "Provenance certifiée (à peu près)", theme: "insolite", valeur: 150_000, prestige: 7),
        SpeOeuvre(id: "o_in04", nom: "Momie de chat sacré", auteur: "Basse Époque", theme: "insolite", valeur: 500_000, prestige: 10),
        SpeOeuvre(id: "o_in05", nom: "Robot cuisinier de l'Exposition de 1937", auteur: "Inventeur inconnu", theme: "insolite", valeur: 900_000, prestige: 12),
    ]

    static func oeuvre(_ id: String) -> SpeOeuvre? { oeuvres.first { $0.id == id } }

    // MARK: - Investissements

    static let nomsCombattants = ["Yanis « Le Roc » Belkacem", "Mila « Lame » Novak", "Sacha Dumont", "Ibrahim « Kaïman » Touré", "Lou Ferrand"]
    static let nomsAlbums = ["le premier album de Nour", "le disque de Mauvaise Graine", "l'album d'Ezra Lowe", "le projet de Kenza Rio", "l'album d'Ondine"]
    static let nomsFilms = ["« La Ligne de partage »", "« Les Héritiers du vent »", "« Marée basse »", "« Opération Colibri »", "« Le Ciel d'en bas »"]
    static let nomsClubsInvest = ["Stade Montvallon", "US Bréhal", "AS Port-Lambert", "Racing Club du Lac", "Olympique de Valcourt"]
    static let nomsAgences = ["Agence Silhouette", "Nova Faces Junior", "Visages Nouveaux", "Agence Nuance", "Studio Mannequins Sud"]

    static func nomInvest(_ t: SpeInvestType, cle: Int) -> String {
        let liste: [String]
        switch t {
        case .combattant: liste = nomsCombattants
        case .film: liste = nomsFilms
        case .album: liste = nomsAlbums
        case .club: liste = nomsClubsInvest
        case .agence: liste = nomsAgences
        }
        return liste[abs(cle) % liste.count]
    }

    // MARK: - Cartes

    static let cartes: [SpeCarte] = DonneesJSON.chargerTableaux(dossier: "SpecialesEvents", type: SpeCarte.self)
}

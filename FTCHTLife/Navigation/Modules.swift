import SwiftUI

// Catalogue de la navigation : 5 menus (catégories) et une entrée par écran du jeu.
// Pour ajouter un module : un `case` dans `ModuleJeu`, ses textes ci-dessous, puis son écran
// dans `EcranModule` (Navigation/EcranModule.swift). Voir docs/NAVIGATION.md.

// MARK: - Catégories (boutons de la barre du bas + « Moi »)

enum CategorieMenu: String, CaseIterable, Identifiable {
    case carriere, biens, relations, activites, moi

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .carriere: return "Carrière"
        case .biens: return "Biens"
        case .relations: return "Relations"
        case .activites: return "Activités"
        case .moi: return "Moi"
        }
    }

    var icone: String {
        switch self {
        case .carriere: return "briefcase.fill"
        case .biens: return "house.fill"
        case .relations: return "heart.fill"
        case .activites: return "figure.run"
        case .moi: return "person.crop.circle.fill"
        }
    }

    var couleur: Color {
        switch self {
        case .carriere: return Color(red: 0.20, green: 0.45, blue: 0.88)
        case .biens: return Color(red: 0.12, green: 0.60, blue: 0.40)
        case .relations: return Color(red: 0.90, green: 0.28, blue: 0.45)
        case .activites: return Color(red: 0.96, green: 0.52, blue: 0.12)
        case .moi: return Color(red: 0.50, green: 0.36, blue: 0.84)
        }
    }

    /// Phrase d'aide en haut du menu.
    var aide: String {
        switch self {
        case .carriere: return "École, études, travail, ta boîte, la politique et la retraite."
        case .biens: return "Acheter, posséder, placer ton argent et préparer ton héritage."
        case .relations: return "Famille, amour, amis, téléphone, voisins et animaux."
        case .activites: return "Sortir, te soigner, jouer, passer ton permis… ou mal tourner."
        case .moi: return "Ton profil, tes talents, tes trophées et les réglages du jeu."
        }
    }
}

// MARK: - Entrées des menus

enum ModuleJeu: String, CaseIterable, Identifiable {
    // Carrière
    case ecole, vieAuBahut, universite, offresEmploi, monTravail, entreprise, agenceDetective, secte, politique, retraite
    // Biens
    case boutique, mesBiens, placements, testament, heritages
    // Relations
    case famille, amour, amis, rencontres, telephone, voisins, animaux, reputationFamille, secrets
    // Activités
    case loisirs, projets, coiffeur, chirurgie, sante, television, casino, permis, voyages, etranger, crime, prison, casier, celebrite, proces
    // Moi
    case profil, competences, trophees, journalDuMonde, musee, reglages

    var id: String { rawValue }

    var categorie: CategorieMenu {
        switch self {
        case .ecole, .vieAuBahut, .universite, .offresEmploi, .monTravail, .entreprise, .agenceDetective, .secte, .politique, .retraite:
            return .carriere
        case .boutique, .mesBiens, .placements, .testament, .heritages:
            return .biens
        case .famille, .amour, .amis, .rencontres, .telephone, .voisins, .animaux, .reputationFamille, .secrets:
            return .relations
        case .loisirs, .projets, .coiffeur, .chirurgie, .sante, .television, .casino, .permis, .voyages, .etranger, .crime, .prison, .casier, .celebrite, .proces:
            return .activites
        case .profil, .competences, .trophees, .journalDuMonde, .musee, .reglages:
            return .moi
        }
    }

    /// Sous-titre de groupe dans le menu.
    var groupe: String {
        switch self {
        case .ecole, .vieAuBahut, .universite: return "Études"
        case .offresEmploi, .monTravail, .entreprise: return "Travail"
        case .agenceDetective, .secte: return "À ton compte"
        case .politique, .retraite: return "Plus tard"
        case .boutique, .mesBiens: return "Acheter et posséder"
        case .placements, .testament, .heritages: return "Argent et héritage"
        case .famille, .amour, .amis: return "Mes proches"
        case .rencontres, .telephone, .voisins, .animaux: return "Rencontrer et garder le contact"
        case .reputationFamille, .secrets: return "Réputation et secrets"
        case .loisirs, .projets, .television, .casino: return "Sorties et loisirs"
        case .coiffeur, .chirurgie: return "Prendre soin de soi"
        case .sante, .permis: return "Santé et démarches"
        case .voyages, .etranger: return "Voyager"
        case .crime, .prison, .casier: return "Hors-la-loi"
        case .celebrite, .proces: return "Gloire et justice"
        case .profil, .competences, .trophees: return "Moi"
        case .journalDuMonde, .musee, .reglages: return "Le jeu"
        }
    }

    var titre: String {
        switch self {
        case .ecole: return "École"
        case .vieAuBahut: return "Vie au bahut"
        case .universite: return "Université"
        case .offresEmploi: return "Offres d'emploi"
        case .monTravail: return "Mon travail"
        case .entreprise: return "Ma boîte"
        case .agenceDetective: return "Agence de détective"
        case .secte: return "Ma secte"
        case .politique: return "Politique"
        case .retraite: return "Retraite"
        case .boutique: return "Boutique"
        case .mesBiens: return "Mes biens"
        case .placements: return "Banque et placements"
        case .testament: return "Mon testament"
        case .heritages: return "Héritages"
        case .famille: return "Famille"
        case .amour: return "Amour"
        case .amis: return "Amis"
        case .rencontres: return "Rencontres"
        case .telephone: return "Téléphone"
        case .voisins: return "Voisins"
        case .animaux: return "Animaux"
        case .reputationFamille: return "Réputation du nom"
        case .secrets: return "Carnet des secrets"
        case .loisirs: return "Loisirs"
        case .projets: return "Projets perso"
        case .coiffeur: return "Coiffeur"
        case .chirurgie: return "Chirurgie esthétique"
        case .sante: return "Santé"
        case .television: return "Télévision"
        case .casino: return "Casino"
        case .permis: return "Permis"
        case .voyages: return "Voyage sur mesure"
        case .etranger: return "Vivre à l'étranger"
        case .crime: return "Crime"
        case .prison: return "Prison"
        case .casier: return "Casier judiciaire"
        case .celebrite: return "Célébrité"
        case .proces: return "Procès"
        case .profil: return "Mon profil"
        case .competences: return "Compétences"
        case .trophees: return "Trophées"
        case .journalDuMonde: return "Journal du monde"
        case .musee: return "Musée des vies"
        case .reglages: return "Réglages"
        }
    }

    var description: String {
        switch self {
        case .ecole: return "Étudier, sécher, quitter l'école."
        case .vieAuBahut: return "Popularité, bande, délégué, bulletins."
        case .universite: return "Choisir une filière et des années de pâtes."
        case .offresEmploi: return "Des centaines de métiers. Postule."
        case .monTravail: return "Bosser, glander, réclamer une augmentation."
        case .entreprise: return "Créer et faire tourner ta propre boîte."
        case .agenceDetective: return "Filatures, planques, clients et secrets."
        case .secte: return "Fonder un mouvement. Adeptes, dons, dérives."
        case .politique: return "De militant à président. Lois absurdes."
        case .retraite: return "Maison de retraite, loto du jeudi."
        case .boutique: return "Maisons, voitures, bateaux, bijoux, voyages."
        case .mesBiens: return "Tout ce que tu possèdes."
        case .placements: return "Livret, bourse, cryptos, locatif."
        case .testament: return "Qui hérite de quoi. Drame garanti."
        case .heritages: return "Successions en cours et passées."
        case .famille: return "Parents, frères et sœurs, enfants."
        case .amour: return "Ton couple, tes ex."
        case .amis: return "Tes potes et tes amies."
        case .rencontres: return "Trouver l'amour, ou au moins quelqu'un."
        case .telephone: return "Messages, réseaux sociaux, appli de drague."
        case .voisins: return "Le quartier et ses spécimens."
        case .animaux: return "Adopter, nourrir, pleurer."
        case .reputationFamille: return "Ce que la ville pense de ton nom."
        case .secrets: return "Ce que tu sais… et ce qu'on sait sur toi."
        case .loisirs: return "Sport, rando, hobbies, aventure."
        case .projets: return "Un roman, un marathon, une cabane : sur plusieurs années."
        case .coiffeur: return "Coupes, couleurs, ratés mémorables."
        case .chirurgie: return "Rhino, lifting, BBL… à tes risques."
        case .sante: return "Médecin, maladies, soins."
        case .television: return "Quiz, téléréalité, gloire éphémère."
        case .casino: return "Roulette, poker, machines à sous."
        case .permis: return "Code, conduite, points."
        case .voyages: return "65 pays, ton transport, tes proches, tes souvenirs."
        case .etranger: return "26 pays, visas, langues, choc culturel."
        case .crime: return "Petits larcins et gros coups."
        case .prison: return "Tu es derrière les barreaux."
        case .casier: return "Effacer ton passé judiciaire."
        case .celebrite: return "Livre, pubs, fêtes, photos, télé : gère ta gloire."
        case .proces: return "Poursuivre quelqu'un en justice."
        case .profil: return "Stats, rêves, réputation."
        case .competences: return "27 talents qui débloquent des choix."
        case .trophees: return "Trophées gardés d'une vie à l'autre."
        case .journalDuMonde: return "Les grandes nouvelles de l'année."
        case .musee: return "Tes vies passées."
        case .reglages: return "Mode Shkurtaaa, nouvelle vie."
        }
    }

    var icone: String {
        switch self {
        case .ecole: return "book.fill"
        case .vieAuBahut: return "backpack.fill"
        case .universite: return "graduationcap.fill"
        case .offresEmploi: return "magnifyingglass"
        case .monTravail: return "briefcase.fill"
        case .entreprise: return "building.2.fill"
        case .agenceDetective: return "magnifyingglass.circle.fill"
        case .secte: return "flame.fill"
        case .politique: return "building.columns.fill"
        case .retraite: return "figure.walk"
        case .boutique: return "cart.fill"
        case .mesBiens: return "key.fill"
        case .placements: return "chart.line.uptrend.xyaxis"
        case .testament: return "scroll.fill"
        case .heritages: return "envelope.open.fill"
        case .famille: return "figure.2.and.child.holdinghands"
        case .amour: return "heart.fill"
        case .amis: return "person.2.fill"
        case .rencontres: return "sparkles"
        case .telephone: return "iphone"
        case .voisins: return "house.and.flag.fill"
        case .animaux: return "pawprint.fill"
        case .reputationFamille: return "crown.fill"
        case .secrets: return "lock.fill"
        case .loisirs: return "figure.hiking"
        case .projets: return "hammer.fill"
        case .coiffeur: return "scissors"
        case .chirurgie: return "wand.and.stars"
        case .sante: return "cross.case.fill"
        case .television: return "tv.fill"
        case .casino: return "suit.spade.fill"
        case .permis: return "car.fill"
        case .voyages: return "suitcase.rolling.fill"
        case .etranger: return "globe.europe.africa.fill"
        case .crime: return "theatermasks.fill"
        case .prison: return "lock.shield.fill"
        case .casier: return "doc.text.magnifyingglass"
        case .celebrite: return "star.fill"
        case .proces: return "scalemass.fill"
        case .profil: return "person.text.rectangle.fill"
        case .competences: return "star.circle.fill"
        case .trophees: return "trophy.fill"
        case .journalDuMonde: return "newspaper.fill"
        case .musee: return "building.columns"
        case .reglages: return "gearshape.fill"
        }
    }

    /// Entrée affichée seulement dans certaines situations.
    func visible(_ j: Joueur) -> Bool {
        switch self {
        case .ecole: return j.niveauScolaire != nil
        case .vieAuBahut: return j.niveauScolaire != nil && j.age >= 11
        case .monTravail: return j.carriere != nil
        case .prison: return j.vieEtat.justice.enPrison
        case .retraite: return j.age >= 50
        default: return true
        }
    }

    /// Entrées impossibles derrière les barreaux.
    static let fermesEnPrison: [ModuleJeu] = [.offresEmploi, .entreprise, .boutique, .rencontres, .loisirs, .projets, .chirurgie,
                                              .television, .casino, .permis, .voyages, .etranger, .crime, .ecole, .universite, .celebrite]

    /// Raison pour laquelle l'entrée est fermée pour l'instant (nil = ouverte).
    func verrou(_ j: Joueur) -> String? {
        if !j.vivant { return "Tu es mort\(j.genre == .femme ? "e" : ""). Ça limite les possibilités." }
        if j.vieEtat.justice.enPrison && ModuleJeu.fermesEnPrison.contains(self) {
            return "Tu es en prison. Va voir l'entrée « Prison »."
        }
        switch self {
        case .ecole where j.age < 6: return "L'école commence à 6 ans. Avant, c'est la maternelle et la sieste."
        case .universite:
            if j.age < 18 { return "Dès 18 ans, avec le bac." }
            if j.diplome < .bac { return "Il te faut le bac pour entrer à l'université." }
            return nil
        case .offresEmploi where j.age < 14: return "Dès 14 ans. Avant, tu vends tes dessins à ta famille."
        case .entreprise where j.age < 16: return "Dès 16 ans. Pour l'instant, monte un stand de limonade."
        case .agenceDetective where j.age < AgenceMoteur.ageMinClandestin && j.agences?.actuelle == nil: return "Dès 18 ans. Pour l'instant, espionne ta sœur."
        case .secte where j.age < SecteMoteur.ageMin && j.sectes?.actuelle == nil: return "Dès 18 ans. Pour l'instant, ton club secret de la cabane suffit."
        case .politique where j.age < PolMoteur.ageMilitant: return "Dès \(PolMoteur.ageMilitant) ans."
        case .retraite where j.age < RetraiteSysteme.ageOnglet: return "Dès \(RetraiteSysteme.ageOnglet) ans. Profite, ça arrive vite."
        case .boutique where j.age < 12: return "Dès 12 ans. Tes parents gardent la carte bleue."
        case .placements where j.age < 10: return "Dès 10 ans, avec le livret."
        case .testament where j.age < 18: return "Dès 18 ans."
        case .etranger where j.age < 18: return "Dès 18 ans. Avant, tu suis tes parents."
        case .voyages where j.age < 12: return "Dès 12 ans. Avant, tu suis tes parents en vacances."
        case .rencontres where j.age < 14: return "Dès 14 ans. Pour l'instant, les cartes de récré suffisent."
        case .telephone where j.age < 13: return "Le téléphone arrive à 13 ans. Écran fissuré inclus."
        case .television where j.age < 10: return "Dès 10 ans."
        case .casino where j.age < 18: return "Interdit aux mineurs. Le videur a vu ta tête."
        case .permis where j.age < 10: return "Dès 10 ans (le vélo d'abord)."
        case .coiffeur where j.age < 2: return "Dès 2 ans. Pour l'instant, trois cheveux et un épi."
        case .chirurgie where j.age < 18: return "Dès 18 ans. Ton visage n'a pas fini de pousser."
        case .crime where j.age < 12: return "Dès 12 ans. Avant, voler des bonbons ne compte pas."
        case .celebrite where j.age < 6: return "Dès 6 ans. Pour l'instant, tu es célèbre à la crèche."
        case .proces where j.age < ProcesMoteur.ageMin: return "Dès \(ProcesMoteur.ageMin) ans. Avant, tu peux seulement le dire à tes parents."
        default: return nil
        }
    }
}

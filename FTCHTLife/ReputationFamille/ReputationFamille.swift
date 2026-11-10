import Foundation

// Réputation du nom de famille : cinq jauges transmises de génération en génération.
// Règles, format et branchement dans le moteur : docs/REPUTATION_FAMILLE.md.

// MARK: - Axes

enum RepFamilleAxe: String, Codable, CaseIterable, Identifiable {
    case respectee, mafieuse, ridicule, maudite, celebre

    var id: String { rawValue }

    /// Clé utilisée dans les effets des événements : "familyRep": {"respected": 5}.
    var cleEffet: String {
        switch self {
        case .respectee: return "respected"
        case .mafieuse: return "mafia"
        case .ridicule: return "ridiculous"
        case .maudite: return "cursed"
        case .celebre: return "famous"
        }
    }

    static func depuisCle(_ cle: String) -> RepFamilleAxe? {
        allCases.first { $0.cleEffet == cle || $0.rawValue == cle }
    }

    /// « respectée », « mafieuse »… (s'accorde avec « famille »).
    var adjectif: String {
        switch self {
        case .respectee: return "respectée"
        case .mafieuse: return "mafieuse"
        case .ridicule: return "ridicule"
        case .maudite: return "maudite"
        case .celebre: return "célèbre"
        }
    }

    var nomJauge: String {
        switch self {
        case .respectee: return "Respect"
        case .mafieuse: return "Mafia"
        case .ridicule: return "Ridicule"
        case .maudite: return "Malédiction"
        case .celebre: return "Célébrité"
        }
    }

    var icone: String {
        switch self {
        case .respectee: return "rosette"
        case .mafieuse: return "suit.spade.fill"
        case .ridicule: return "theatermasks.fill"
        case .maudite: return "moon.haze.fill"
        case .celebre: return "star.fill"
        }
    }

    var tag: String { "famille_" + rawValue }
    var tagLegendaire: String { tag + "_legendaire" }

    /// Part de la jauge qui survit au passage à la génération suivante.
    var memoire: Double {
        switch self {
        case .respectee: return 0.75
        case .mafieuse: return 0.80
        case .ridicule: return 0.70
        case .maudite: return 0.90
        case .celebre: return 0.75
        }
    }

    /// Le respect est la seule jauge « positive » : la monter redore le blason, monter les autres le salit
    /// (sauf la célébrité, neutre).
    var signeBlason: Int {
        switch self {
        case .respectee: return 1
        case .celebre: return 0
        case .mafieuse, .ridicule, .maudite: return -1
        }
    }
}

// MARK: - État sauvegardé

struct RepFamilleScores: Codable, Equatable {
    var respectee: Int = 0
    var mafieuse: Int = 0
    var ridicule: Int = 0
    var maudite: Int = 0
    var celebre: Int = 0

    subscript(axe: RepFamilleAxe) -> Int {
        get {
            switch axe {
            case .respectee: return respectee
            case .mafieuse: return mafieuse
            case .ridicule: return ridicule
            case .maudite: return maudite
            case .celebre: return celebre
            }
        }
        set {
            let v = min(100, max(0, newValue))
            switch axe {
            case .respectee: respectee = v
            case .mafieuse: mafieuse = v
            case .ridicule: ridicule = v
            case .maudite: maudite = v
            case .celebre: celebre = v
            }
        }
    }

    /// Jauges à partir de 30, de la plus forte à la plus faible.
    var marquantes: [RepFamilleAxe] {
        RepFamilleAxe.allCases
            .filter { self[$0] >= ReputationFamille.seuil }
            .sorted { self[$0] > self[$1] }
    }

    var dominante: RepFamilleAxe? { marquantes.first }

    /// Score de « blason » : respect moins ce qui salit. Sert au bilan (redoré ou sali).
    var blason: Int {
        RepFamilleAxe.allCases.reduce(0) { $0 + $1.signeBlason * self[$1] }
    }
}

/// Un ancêtre joué : il reste dans l'arbre de la famille.
struct RepFamilleAncetre: Codable, Equatable, Identifiable {
    var id = UUID()
    var prenom: String
    var nom: String
    var genre: Genre
    var generation: Int
    var ageDeces: Int
    var cause: String?
    /// « le Parrain », « la Sainte »…
    var surnom: String
    /// Ce qu'il a changé à la réputation pendant sa vie.
    var apport: RepFamilleScores
    var apportNegatif: RepFamilleScores
}

/// Un haut fait (ou une honte) retenu par la famille.
struct RepFamilleFait: Codable, Equatable, Identifiable {
    var id = UUID()
    var generation: Int
    var prenom: String
    var age: Int
    var texte: String
}

/// Bilan d'une vie, affiché sur l'écran de mort.
struct RepFamilleBilan: Codable, Equatable {
    var prenom: String
    var nom: String
    var surnom: String
    var avant: RepFamilleScores
    var apres: RepFamilleScores
    var lignes: [String]

    var differenceBlason: Int { apres.blason - avant.blason }
}

struct RepFamilleEtat: Codable, Equatable {
    var scores = RepFamilleScores()
    /// Jauges à la naissance du personnage en cours (pour le bilan).
    var scoresDepart = RepFamilleScores()
    /// 1 = premier personnage de la lignée.
    var generation: Int = 1
    var ancetres: [RepFamilleAncetre] = []
    var faits: [RepFamilleFait] = []
    /// Le personnage en cours a déjà changé de nom.
    var nomChange: Bool = false
    /// Le bilan de la vie en cours est fait (mort).
    var bilanFait: Bool = false
    var dernierBilan: RepFamilleBilan?
    /// Ce que le personnage en cours a ajouté / retiré, axe par axe (pour le surnom posthume).
    var gains = RepFamilleScores()
    var pertes = RepFamilleScores()
}

/// Résultat des effets passifs d'une année.
struct RepFamilleAnnee {
    var lignes: [String] = []
    var effets = Effets()
}

// MARK: - Règles

enum ReputationFamille {
    /// Une jauge compte (tag, titre) à partir de ce score.
    static let seuil = 30
    /// Jauge « légendaire ».
    static let seuilLegende = 70
    static let maxFaits = 40

    // MARK: Création

    /// Réputation d'une famille tirée au hasard pour une nouvelle vie (souvent sans histoire).
    static func aleatoire() -> RepFamilleEtat {
        var s = RepFamilleScores()
        for axe in RepFamilleAxe.allCases { s[axe] = Int.random(in: 0...15) }
        let r = Double.random(in: 0...1)
        if r > 0.55 {
            // Une réputation marquée
            let axe = RepFamilleAxe.allCases.randomElement()!
            s[axe] = Int.random(in: 30...65)
            if Double.random(in: 0...1) < 0.25 {
                let autre = RepFamilleAxe.allCases.filter { $0 != axe }.randomElement()!
                s[autre] = Int.random(in: 30...50)
            }
        }
        var e = RepFamilleEtat()
        e.scores = s
        e.scoresDepart = s
        return e
    }

    /// Réputation choisie (création de personnage) : un axe fort, le reste bas.
    static func choisie(_ axe: RepFamilleAxe?) -> RepFamilleEtat {
        var e = RepFamilleEtat()
        for a in RepFamilleAxe.allCases { e.scores[a] = Int.random(in: 0...10) }
        if let axe = axe { e.scores[axe] = Int.random(in: 45...60) }
        e.scoresDepart = e.scores
        return e
    }

    // MARK: Lecture

    static func tags(_ etat: RepFamilleEtat?) -> Set<String> {
        guard let etat = etat else { return [] }
        var t: Set<String> = []
        for axe in RepFamilleAxe.allCases {
            if etat.scores[axe] >= seuil { t.insert(axe.tag) }
            if etat.scores[axe] >= seuilLegende { t.insert(axe.tagLegendaire) }
        }
        if t.isEmpty { t.insert("famille_sans_histoire") }
        if etat.generation > 1 { t.insert("heritier") }
        return t
    }

    /// « Famille respectée », « Famille mafieuse et célèbre », « Lignée légendairement maudite »…
    static func titre(_ etat: RepFamilleEtat) -> String {
        let m = etat.scores.marquantes
        guard let premiere = m.first else { return "Famille sans histoire" }
        if etat.scores[premiere] >= seuilLegende && m.count == 1 {
            return "Lignée légendairement \(premiere.adjectif)"
        }
        let adjectifs = m.prefix(2).map { $0.adjectif }
        return "Famille " + adjectifs.joined(separator: " et ")
    }

    /// Phrase courte qui résume ce que les gens pensent du nom.
    static func resume(_ etat: RepFamilleEtat, nom: String) -> String {
        guard let d = etat.scores.dominante else {
            return "Quand on dit « \(nom) », les gens répondent « qui ? »."
        }
        let fort = etat.scores[d] >= seuilLegende
        switch d {
        case .respectee:
            return fort ? "Le nom \(nom) ouvre toutes les portes, même celles des toilettes de la mairie."
                        : "Les \(nom) ? Des gens bien. On leur prête une perceuse sans hésiter."
        case .mafieuse:
            return fort ? "On ne prononce pas « \(nom) » à voix haute. On fait un petit signe de tête."
                        : "Les \(nom) ont des « relations ». Personne ne veut savoir lesquelles."
        case .ridicule:
            return fort ? "« Faire un \(nom) » est entré dans le dictionnaire. Pas en bien."
                        : "Quand on dit « \(nom) », quelqu'un pouffe toujours au fond de la pièce."
        case .maudite:
            return fort ? "Les assureurs raccrochent quand ils entendent « \(nom) »."
                        : "Les \(nom) ont la guigne. Les chats noirs changent de trottoir en les voyant."
        case .celebre:
            return fort ? "Il y a une rue \(nom) dans chaque ville. Et un timbre."
                        : "« \(nom) ? Comme LES \(nom) ? » Oui. Comme eux."
        }
    }

    /// L'ancêtre le plus marquant, sous la forme « ton arrière-grand-père Marcel ».
    static func ancetreCite(_ etat: RepFamilleEtat?) -> String {
        guard let etat = etat, !etat.ancetres.isEmpty else { return "un lointain aïeul" }
        let a = etat.ancetres.max { poids($0) < poids($1) } ?? etat.ancetres.last!
        return lien(a, generationActuelle: etat.generation) + " " + a.prenom
    }

    private static func poids(_ a: RepFamilleAncetre) -> Int {
        RepFamilleAxe.allCases.reduce(0) { $0 + a.apport[$1] + a.apportNegatif[$1] }
    }

    /// « ta mère », « ton grand-père », « ton arrière-arrière-grand-père »…
    static func lien(_ a: RepFamilleAncetre, generationActuelle: Int) -> String {
        let ecart = max(1, generationActuelle - a.generation)
        let f = a.genre == .femme
        switch ecart {
        case 1: return f ? "ta mère" : "ton père"
        case 2: return f ? "ta grand-mère" : "ton grand-père"
        case 3: return f ? "ton arrière-grand-mère" : "ton arrière-grand-père"
        default:
            let prefixe = String(repeating: "arrière-", count: ecart - 2)
            return "ton " + prefixe + (f ? "grand-mère" : "grand-père")
        }
    }

    /// Remplace {ancetre} dans un texte d'événement. À appeler avant le remplissage du moteur.
    static func remplir(_ texte: String, etat: RepFamilleEtat?) -> String {
        guard texte.contains("{ancetre}") else { return texte }
        return texte.replacingOccurrences(of: "{ancetre}", with: ancetreCite(etat))
    }

    // MARK: Modifier

    /// Applique les deltas d'un effet "familyRep" ({"respected": 5, "mafia": -3}).
    static func modifier(_ deltas: [String: Int], etat: inout RepFamilleEtat, joueur: Joueur, fait: String? = nil) {
        for (cle, delta) in deltas {
            guard let axe = RepFamilleAxe.depuisCle(cle) else { continue }
            modifier(axe, delta, etat: &etat)
        }
        if let fait = fait { retenir(fait, joueur: joueur, etat: &etat) }
    }

    static func modifier(_ axe: RepFamilleAxe, _ delta: Int, etat: inout RepFamilleEtat) {
        let avant = etat.scores[axe]
        etat.scores[axe] = avant + delta
        let reel = etat.scores[axe] - avant
        if reel > 0 { etat.gains[axe] += reel } else if reel < 0 { etat.pertes[axe] += -reel }
    }

    /// Ajoute un haut fait au registre de la famille.
    static func retenir(_ texte: String, joueur: Joueur, etat: inout RepFamilleEtat) {
        etat.faits.append(RepFamilleFait(generation: etat.generation, prenom: joueur.prenom, age: joueur.age, texte: texte))
        if etat.faits.count > maxFaits { etat.faits.removeFirst(etat.faits.count - maxFaits) }
    }

    // MARK: Signaux des modules

    /// Deltas appliqués quand un module émet un signal (liste dans docs/REPERCUSSIONS.md).
    static let effetsSignaux: [String: [RepFamilleAxe: Int]] = [
        // Crime, justice
        "crime_reussi": [.mafieuse: 2],
        "crime_rate": [.ridicule: 2, .mafieuse: 1],
        "arrestation": [.respectee: -4, .mafieuse: 2, .ridicule: 1],
        "proces_gagne": [.respectee: 2],
        "proces_perdu": [.respectee: -3],
        "prison_entree": [.mafieuse: 6, .respectee: -6],
        "prison_sortie": [.mafieuse: 1],
        "evasion": [.mafieuse: 6, .celebre: 4],
        // École, travail
        "bac_obtenu": [.respectee: 1],
        "bac_rate": [.ridicule: 1],
        "diplome": [.respectee: 3],
        "promotion": [.respectee: 1],
        "licenciement": [.ridicule: 1],
        "retraite": [.respectee: 1],
        // Amour
        "mariage": [.respectee: 1],
        "divorce": [.ridicule: 2],
        "tromperie_decouverte": [.ridicule: 4, .respectee: -2],
        "demande_refusee": [.ridicule: 2],
        "fiancailles_rompues": [.ridicule: 2],
        "veuvage": [.maudite: 2],
        // Casino, jeux
        "casino_jackpot": [.celebre: 3],
        "casino_ruine": [.ridicule: 5, .respectee: -3],
        "casino_triche_attrape": [.mafieuse: 2, .ridicule: 3],
        "loterie_gain": [.celebre: 4],
        // Permis, voiture
        "permis_rate": [.ridicule: 1],
        "accident_voiture": [.maudite: 2],
        "faux_permis_demasque": [.ridicule: 4],
        "corruption_examinateur": [.mafieuse: 2],
        // Famille, santé, argent
        "deces_parent": [.maudite: 1],
        "heritage": [.respectee: 1],
        "maladie": [.maudite: 1],
        "hopital": [.maudite: 1],
        "addiction": [.respectee: -3, .ridicule: 2],
        "cure_desintox": [.respectee: 2],
        "chirurgie_esthetique": [.ridicule: 1, .celebre: 1],
        "achat_maison": [.respectee: 2],
        "faillite": [.ridicule: 6, .respectee: -4],
        "celebrite": [.celebre: 10],
        "gros_achat": [.celebre: 1],
    ]

    /// Signaux assez marquants pour entrer dans le registre de la famille.
    static let faitsSignaux: [String: String] = [
        "prison_entree": "est allé en prison",
        "evasion": "s'est évadé de prison",
        "diplome": "a décroché un diplôme",
        "casino_ruine": "s'est ruiné au casino",
        "casino_jackpot": "a fait sauter la banque du casino",
        "loterie_gain": "a gagné à la loterie",
        "faillite": "a fait faillite",
        "celebrite": "est devenu célèbre",
        "tromperie_decouverte": "s'est fait prendre en train de tromper",
        "faux_permis_demasque": "s'est fait prendre avec un faux permis",
    ]

    static func signaler(_ signal: String, joueur: Joueur, etat: inout RepFamilleEtat) {
        guard let deltas = effetsSignaux[signal] else { return }
        for (axe, d) in deltas { modifier(axe, d, etat: &etat) }
        if let f = faitsSignaux[signal] {
            retenir("\(joueur.prenom) \(accorder(f, joueur.genre)) à \(joueur.age) ans.", joueur: joueur, etat: &etat)
        }
    }

    /// Accorde « est allé », « s'est ruiné »… au féminin.
    static func accorder(_ texte: String, _ genre: Genre) -> String {
        guard genre == .femme else { return texte }
        return texte
            .replacingOccurrences(of: "allé", with: "allée")
            .replacingOccurrences(of: "évadé", with: "évadée")
            .replacingOccurrences(of: "ruiné", with: "ruinée")
            .replacingOccurrences(of: "devenu", with: "devenue")
    }

    // MARK: Naissance

    /// Une à trois phrases pour le journal de naissance.
    static func lignesNaissance(_ etat: RepFamilleEtat, joueur: Joueur) -> [String] {
        var lignes: [String] = []
        let nom = joueur.nom
        if etat.generation > 1, let parent = etat.ancetres.last {
            let l = lien(parent, generationActuelle: etat.generation)
            lignes.append("Tu es l'héritier\(joueur.genre == .femme ? "e" : "") de \(l) \(parent.prenom) \(parent.surnom), génération n° \(etat.generation) des \(nom).")
        }
        guard let d = etat.scores.dominante else {
            if etat.generation == 1 || Double.random(in: 0...1) < 0.5 {
                lignes.append(phrasesSansHistoire.randomElement()!.replacingOccurrences(of: "{nom}", with: nom))
            }
            return lignes
        }
        let phrases = phrasesNaissance[d] ?? []
        if let p = phrases.randomElement() {
            lignes.append(p.replacingOccurrences(of: "{nom}", with: nom))
        }
        return lignes
    }

    static let phrasesSansHistoire = [
        "Les {nom} n'ont jamais rien fait de notable. À toi de changer ça. Ou pas.",
        "Ta famille est si discrète que la mairie a égaré votre livret de famille trois fois.",
        "Aucun {nom} n'a jamais fait parler de lui. Le record est à battre.",
    ]

    static let phrasesNaissance: [RepFamilleAxe: [String]] = [
        .respectee: [
            "Le maire en personne envoie des fleurs. On ne naît pas {nom} par hasard.",
            "Le curé, le notaire et le boulanger sont venus à la maternité. Les {nom} sont des gens respectables.",
            "Dans ton berceau, une médaille de famille. Tu essaies de la manger.",
        ],
        .mafieuse: [
            "Trois hommes en costume sombre déposent une enveloppe dans ton berceau. Bienvenue chez les {nom}.",
            "La maternité t'a offert la chambre individuelle. Personne n'a osé envoyer la facture aux {nom}.",
            "Ton parrain a des lunettes noires, une bague énorme et pas de prénom connu.",
        ],
        .ridicule: [
            "L'infirmière lit « {nom} » sur ton bracelet et étouffe un fou rire.",
            "Ta famille est connue dans toute la région pour l'incident de la fondue de 1987. Personne ne t'en parlera. Tout le monde t'en parlera.",
            "Le journal local annonce ta naissance dans la rubrique « Insolite ». Comme pour chaque {nom}.",
        ],
        .maudite: [
            "Un orage éclate pile à ta naissance. Chez les {nom}, c'est la tradition.",
            "La sage-femme fait un signe de croix en lisant ton nom de famille.",
            "Le miroir de la chambre se fissure quand on te présente. Ta mère soupire : « Encore. »",
        ],
        .celebre: [
            "Des photographes attendent devant la maternité. Chez les {nom}, on ne naît pas discrètement.",
            "Ta naissance fait la une d'un magazine people. Tu as une page fan avant d'avoir des dents.",
            "Un inconnu demande un autographe à ton père dans le couloir. Les {nom}, toujours.",
        ],
    ]

    // MARK: Chaque année

    /// Effets passifs de la réputation, tirés au hasard (pas chaque année).
    static func annee(joueur j: Joueur, etat: inout RepFamilleEtat) -> RepFamilleAnnee {
        var r = RepFamilleAnnee()
        guard j.age >= 4, let d = etat.scores.marquantes.randomElement() else { return r }
        let force = etat.scores[d]
        let chance = force >= seuilLegende ? 0.30 : 0.15
        guard Double.random(in: 0...1) < chance else { return r }
        let nom = j.nom
        let e = j.genre == .femme ? "e" : ""

        switch d {
        case .respectee:
            if j.age < 18 {
                r.lignes.append(["Un prof te dit : « Avec un nom comme \(nom), j'attends le meilleur de toi. » Pression.",
                                 "On t'a élu délégué\(e) de classe sans que tu te présentes. Le nom suffit.",
                                 "Une vieille dame te pince la joue : « Tu as les yeux de ton grand-père, un homme si honnête. »"].randomElement()!)
                r.effets.smarts = 1
                r.effets.happiness = Int.random(in: -1...2)
            } else {
                r.lignes.append(["Ton banquier t'accorde un découvert « parce que c'est vous, \(nom) ».",
                                 "Tu passes devant tout le monde à la préfecture. Le nom \(nom) fait encore son effet.",
                                 "On t'invite à couper un ruban d'inauguration. Tu ne sais pas ce qu'on inaugure."].randomElement()!)
                r.effets.happiness = 2
                r.effets.karma = 1
            }
        case .mafieuse:
            if j.age < 18 {
                r.lignes.append(["Personne à l'école n'ose te piquer ton goûter. Ni te parler, d'ailleurs.",
                                 "Ton prof d'histoire te met 18 en évitant soigneusement ton regard.",
                                 "Un « tonton » que tu n'as jamais vu t'offre une montre en or pour tes \(j.age) ans."].randomElement()!)
                r.effets.happiness = 2
            } else {
                let enveloppe = Int.random(in: 2...12) * 500
                r.lignes.append(["Une enveloppe sans expéditeur glissée sous ta porte : \(Format.argent(enveloppe)). « Pour la famille. »",
                                 "Le restaurant du coin refuse ton argent : « Chez nous, les \(nom) ne paient pas. » Il te rend même \(Format.argent(enveloppe)).",
                                 "Un cousin éloigné te « rembourse » une dette que tu n'as jamais prêtée : \(Format.argent(enveloppe))."].randomElement()!)
                r.effets.money = enveloppe
                r.effets.karma = -2
            }
        case .ridicule:
            let moqueries: [String]
            if j.age < 18 {
                moqueries = ["À la récré, « faire un \(nom) » veut dire tomber dans la cantine. Tu n'as rien demandé.",
                             "Ton nom de famille est encore le sujet d'une chanson moqueuse en cours de musique.",
                             "On t'a demandé si c'est vrai, l'histoire de ton arrière-grand-oncle et du lama. C'est vrai."]
            } else {
                moqueries = ["Au guichet, l'employée lit « \(nom) », sourit, puis appelle sa collègue pour qu'elle voie aussi.",
                             "Un humoriste fait encore une blague sur les \(nom) à la télé. Ta mère a appelé pour se plaindre.",
                             "Ton nom figure dans un jeu à boire. Tu préfères ne pas savoir les règles."]
            }
            r.lignes.append(moqueries.randomElement()!)
            r.effets.happiness = -Int.random(in: 1...3)
        case .maudite:
            let lignes = ["Un pigeon t'a visé\(e) trois fois cette année. Le même pigeon. La malédiction des \(nom) ne prend pas de vacances.",
                          "Ta voiture, ta machine à laver et ton grille-pain sont tombés en panne le même jour. Normal, chez les \(nom).",
                          "Tu trouves un trèfle à quatre feuilles. Il fane dans ta main.",
                          "Une voyante te croise dans la rue et change de trottoir en courant."]
            r.lignes.append(lignes.randomElement()!)
            r.effets.happiness = -2
            if Double.random(in: 0...1) < 0.4 { r.effets.health = -Int.random(in: 1...4) }
        case .celebre:
            if j.age < 18 {
                r.lignes.append(["Un camarade te demande un autographe pour sa tante. Elle est fan de ta grand-mère.",
                                 "Ta photo de classe se vend sur internet. Tu ne touches rien.",
                                 "Un journaliste attend devant l'école. Il voulait juste savoir ce que mangent les \(nom) à midi."].randomElement()!)
                r.effets.happiness = Int.random(in: -1...3)
            } else {
                let cachet = Int.random(in: 1...8) * 1000
                r.lignes.append(["Une marque de yaourts te paie \(Format.argent(cachet)) pour poser avec un pot. Le nom \(nom) fait vendre.",
                                 "Des paparazzi te photographient en train de sortir les poubelles. « Les \(nom) aussi trient leurs déchets ! »",
                                 "On t'invite à une émission de télé pour parler de ta famille. Tu reçois \(Format.argent(cachet)) pour dire « c'est compliqué »."].randomElement()!)
                r.effets.money = cachet
                r.effets.happiness = 2
            }
        }
        return r
    }

    // MARK: Mort et bilan

    /// Bilan d'une vie à la mort du personnage : derniers ajustements, surnom posthume, ancêtre ajouté à l'arbre.
    @discardableResult
    static func bilanDeVie(joueur j: Joueur, etat: inout RepFamilleEtat) -> RepFamilleBilan {
        if etat.bilanFait, let b = etat.dernierBilan { return b }
        var lignes: [String] = []

        // La vie entière laisse une trace.
        if j.stats.karma >= 80 { modifier(.respectee, 6, etat: &etat); lignes.append("Ta gentillesse a fait du bien au nom.") }
        if j.stats.karma <= 15 { modifier(.respectee, -5, etat: &etat); modifier(.mafieuse, 2, etat: &etat); lignes.append("Ta méchanceté légendaire a terni le nom.") }
        if j.argent >= 10_000_000 { modifier(.celebre, 8, etat: &etat); modifier(.respectee, 3, etat: &etat); lignes.append("Ta fortune colossale fait parler d'elle.") }
        else if j.argent >= 1_000_000 { modifier(.celebre, 3, etat: &etat) }
        if j.argent < -10_000 { modifier(.ridicule, 3, etat: &etat); lignes.append("Tu laisses des dettes. Les huissiers connaissent désormais le nom.") }
        if j.diplome >= .doctorat { modifier(.respectee, 3, etat: &etat) }
        if j.age < 30 {
            modifier(.maudite, 6, etat: &etat)
            lignes.append("Partir si jeune… on parle déjà de malédiction.")
        } else if j.age >= 95 {
            modifier(.respectee, 4, etat: &etat)
            lignes.append("Mourir à \(j.age) ans force le respect.")
        }
        if let cause = j.causeDeces, !ReputationFamille.estNaturelle(cause) && !cause.contains("maladie") {
            // Une mort absurde (les événements) fait rire tout le monde, sauf la famille.
            if Double.random(in: 0...1) < 0.6 {
                modifier(.ridicule, 4, etat: &etat)
                lignes.append("Ta mort (\(cause)) restera dans les annales familiales.")
            }
        }

        let surnom = surnomPosthume(joueur: j, etat: etat)
        let ancetre = RepFamilleAncetre(prenom: j.prenom, nom: j.nom, genre: j.genre, generation: etat.generation,
                                        ageDeces: j.age, cause: j.causeDeces, surnom: surnom,
                                        apport: etat.gains, apportNegatif: etat.pertes)
        etat.ancetres.append(ancetre)

        let diff = etat.scores.blason - etat.scoresDepart.blason
        let verdict: String
        switch diff {
        case 25...: verdict = "Tu as redoré le blason des \(j.nom). Tes descendants te diront merci."
        case 8..<25: verdict = "Tu as un peu amélioré la réputation des \(j.nom)."
        case -7..<8: verdict = "Tu n'as presque rien changé à la réputation des \(j.nom)."
        case -24 ..< -7: verdict = "Tu as un peu sali le nom des \(j.nom)."
        default: verdict = "Tu as traîné le nom des \(j.nom) dans la boue. Tes descendants vont ramer."
        }
        lignes.insert(verdict, at: 0)
        if etat.scores[.celebre] - etat.scoresDepart[.celebre] >= 15 {
            lignes.append("En tout cas, plus personne n'ignore le nom \(j.nom).")
        }

        let b = RepFamilleBilan(prenom: j.prenom, nom: j.nom, surnom: surnom,
                                avant: etat.scoresDepart, apres: etat.scores, lignes: lignes)
        etat.dernierBilan = b
        etat.bilanFait = true
        return b
    }

    static func estNaturelle(_ cause: String) -> Bool {
        cause.contains("vieillesse") || cause.contains("crise cardiaque") || cause.contains("AVC") || cause.contains("blessures")
    }

    /// « le Parrain », « la Sainte », « l'Inconnu »… selon ce que le personnage a apporté.
    static func surnomPosthume(joueur j: Joueur, etat: RepFamilleEtat) -> String {
        let f = j.genre == .femme
        // Axe le plus modifié pendant la vie (en hausse).
        let meilleur = RepFamilleAxe.allCases.max { etat.gains[$0] < etat.gains[$1] }!
        let pireBaisse = RepFamilleAxe.allCases.max { etat.pertes[$0] < etat.pertes[$1] }!
        if etat.gains[meilleur] < 8 && etat.pertes[pireBaisse] < 8 {
            return f ? ["la Discrète", "l'Oubliée", "la Tranquille"].randomElement()! : ["le Discret", "l'Oublié", "le Tranquille"].randomElement()!
        }
        if etat.pertes[pireBaisse] > etat.gains[meilleur] {
            switch pireBaisse {
            case .mafieuse: return f ? "la Repentie" : "le Repenti"
            case .ridicule: return f ? "la Digne" : "le Digne"
            case .maudite: return f ? "la Conjureuse" : "le Conjureur"
            case .celebre: return f ? "l'Effacée" : "l'Effacé"
            case .respectee: return f ? "la Honte" : "la Honte"
            }
        }
        switch meilleur {
        case .respectee: return f ? ["la Sainte", "la Juste", "la Bienfaitrice"].randomElement()! : ["le Saint", "le Juste", "le Bienfaiteur"].randomElement()!
        case .mafieuse: return f ? ["la Marraine", "la Patronne", "la Main de fer"].randomElement()! : ["le Parrain", "le Patron", "la Main de fer"].randomElement()!
        case .ridicule: return f ? ["la Gaffeuse", "la Risée", "l'Inénarrable"].randomElement()! : ["le Gaffeur", "la Risée", "l'Inénarrable"].randomElement()!
        case .maudite: return f ? ["la Maudite", "la Chat-Noir", "la Malchanceuse"].randomElement()! : ["le Maudit", "le Chat-Noir", "le Malchanceux"].randomElement()!
        case .celebre: return f ? ["la Célèbre", "la Star", "l'Illustre"].randomElement()! : ["le Célèbre", "la Star", "l'Illustre"].randomElement()!
        }
    }

    // MARK: Succession

    /// Réputation reçue par l'héritier quand on continue avec un enfant.
    /// Fait le bilan du parent s'il manque, puis applique l'oubli d'une génération.
    static func transmettre(parent: Joueur, etat ancien: RepFamilleEtat, heritier: Joueur? = nil) -> RepFamilleEtat {
        var e = ancien
        if !e.bilanFait { bilanDeVie(joueur: parent, etat: &e) }
        for axe in RepFamilleAxe.allCases {
            let v = Double(e.scores[axe])
            let memoire = v >= 90 ? min(0.95, axe.memoire + 0.1) : axe.memoire
            e.scores[axe] = Int((v * memoire).rounded())
        }
        e.generation += 1
        e.scoresDepart = e.scores
        e.gains = RepFamilleScores()
        e.pertes = RepFamilleScores()
        e.nomChange = false
        e.bilanFait = false
        // Le bilan du parent reste lisible dans dernierBilan jusqu'à la prochaine mort.
        return e
    }
}

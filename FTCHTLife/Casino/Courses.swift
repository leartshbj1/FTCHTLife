import SwiftUI

// MARK: - Modèles

enum CoursesTypePari: CaseIterable, Hashable {
    case gagnant, place, couple

    var nom: String {
        switch self {
        case .gagnant: return "Gagnant"
        case .place: return "Placé"
        case .couple: return "Couplé"
        }
    }

    var explication: String {
        switch self {
        case .gagnant: return "Ton cheval doit finir premier. Simple, brutal."
        case .place: return "Ton cheval doit finir dans les 3 premiers. Moins de gloire, moins d'argent."
        case .couple: return "Choisis le 1er puis le 2e, dans l'ordre. Pour les devins et les inconscients."
        }
    }

    var nombreChevaux: Int { self == .couple ? 2 : 1 }
}

struct CoursesCheval: Identifiable {
    /// Numéro de couloir (0 à 7).
    let id: Int
    let nom: String
    /// Forme cachée, sous forme de poids dans le tirage de l'arrivée.
    let poids: Double
    let cote: Double
    let cotePlace: Double
    /// Les dernières places (« la musique »), vaguement liées à la forme.
    let musique: String

    var numero: Int { id + 1 }
}

struct CoursesPari: Identifiable {
    let id = UUID()
    let type: CoursesTypePari
    let chevaux: [Int]
    let cote: Double
    let mise: Int
    let libelle: String
    var gagne: Bool? = nil

    var gainPotentiel: Int { Int(Double(mise) * cote) }
}

struct CoursesLigneFil: Identifiable {
    let id = UUID()
    let texte: String
}

/// Déroulé complet d'une course, calculé avant le départ.
struct CoursesPlan {
    /// Numéros de couloir, du premier au dernier arrivé.
    let ordre: [Int]
    /// Pour chaque cheval, sa position (0 à 1) à chaque instant ; index 0 = départ.
    let parcours: [[Double]]
    /// Instant d'arrivée de chaque cheval.
    let arrivees: [Int]
    /// Commentaires à afficher à chaque instant.
    let commentaires: [Int: [String]]
    let nbTicks: Int

    func position(_ cheval: Int, _ tick: Int) -> Double {
        guard cheval >= 0, cheval < parcours.count else { return 0 }
        let p = parcours[cheval]
        guard !p.isEmpty else { return 0 }
        return p[min(max(0, tick), p.count - 1)]
    }

    /// Place finale (1 = vainqueur).
    func place(_ cheval: Int) -> Int {
        (ordre.firstIndex(of: cheval) ?? ordre.count) + 1
    }

    func estArrive(_ cheval: Int, _ tick: Int) -> Bool {
        guard cheval >= 0, cheval < arrivees.count else { return false }
        return tick >= arrivees[cheval]
    }
}

enum CoursesPhase {
    case paris, course, arrivee
}

// MARK: - Moteur

enum CoursesMoteur {
    static let marge = 1.15
    static let nombreChevaux = 8

    static func aleatoire() -> Double { Double.random(in: 0..<1) }

    /// Tire un ordre d'arrivée : chaque place est attribuée au hasard, proportionnellement au poids des chevaux restants.
    static func tirerOrdre(_ poids: [Double], places: Int) -> [Int] {
        var restants = Array(poids.indices)
        var ordre: [Int] = []
        while ordre.count < places && !restants.isEmpty {
            let total = restants.reduce(0.0) { $0 + poids[$1] }
            var r = Double.random(in: 0..<max(total, 0.000_001))
            var choisi = restants.count - 1
            for (k, c) in restants.enumerated() {
                r -= poids[c]
                if r < 0 {
                    choisi = k
                    break
                }
            }
            ordre.append(restants.remove(at: choisi))
        }
        return ordre
    }

    static func arrondiBas(_ x: Double, decimales: Double) -> Double {
        (x * decimales).rounded(.down) / decimales
    }

    static func nouvelleCourse() -> [CoursesCheval] {
        let noms = Array(CoursesNoms.chevaux.shuffled().prefix(nombreChevaux))
        let formes: [Double] = (0..<nombreChevaux).map { _ in Double.random(in: 1...10) }
        let poids: [Double] = formes.map { pow($0, 1.7) }
        let total = poids.reduce(0, +)

        // Probabilité de finir dans les 3 premiers, estimée par simulation.
        var podiums = [Int](repeating: 0, count: nombreChevaux)
        let essais = 4_000
        for _ in 0..<essais {
            for c in tirerOrdre(poids, places: 3) { podiums[c] += 1 }
        }

        var chevaux: [CoursesCheval] = []
        for i in 0..<nombreChevaux {
            let p = poids[i] / total
            let cote = min(999, max(1.1, arrondiBas(1 / (p * marge), decimales: 10)))
            let pPlace = max(0.005, Double(podiums[i]) / Double(essais))
            let coteJuste = arrondiBas(1 / (pPlace * marge), decimales: 100)
            let cotePlace = max(1.01, min(cote / 4 + 1, coteJuste))
            chevaux.append(CoursesCheval(id: i, nom: i < noms.count ? noms[i] : "Cheval n°\(i + 1)",
                                         poids: poids[i], cote: cote, cotePlace: cotePlace,
                                         musique: musique(formes[i])))
        }
        return chevaux
    }

    static func musique(_ forme: Double) -> String {
        let morceaux: [String] = (0..<4).map { _ -> String in
            if aleatoire() < 0.05 { return "T" }
            let base = (10 - forme) / 9 * 6
            let place = Int((base + Double.random(in: 0...3)).rounded()) + 1
            return place >= 10 ? "0" : "\(place)"
        }
        return morceaux.joined(separator: "-")
    }

    /// Cote du couplé ordonné (a premier, b deuxième).
    static func coteCouple(_ a: Int, _ b: Int, chevaux: [CoursesCheval]) -> Double {
        guard a != b, a >= 0, b >= 0, a < chevaux.count, b < chevaux.count else { return 1 }
        let total = chevaux.reduce(0.0) { $0 + $1.poids }
        let wa = chevaux[a].poids
        let wb = chevaux[b].poids
        let p = (wa / total) * (wb / max(total - wa, 0.000_001))
        return min(9_999, max(1.5, arrondiBas(1 / (max(p, 0.000_01) * marge), decimales: 10)))
    }

    static func pariGagnant(_ pari: CoursesPari, ordre: [Int]) -> Bool {
        guard let premier = pari.chevaux.first, ordre.count >= 3 else { return false }
        switch pari.type {
        case .gagnant:
            return ordre[0] == premier
        case .place:
            return ordre.prefix(3).contains(premier)
        case .couple:
            guard pari.chevaux.count == 2 else { return false }
            return ordre[0] == pari.chevaux[0] && ordre[1] == pari.chevaux[1]
        }
    }

    /// Le pari est perdu, mais vraiment de peu.
    static func pariPresque(_ pari: CoursesPari, ordre: [Int]) -> Bool {
        guard let premier = pari.chevaux.first, ordre.count >= 4 else { return false }
        switch pari.type {
        case .gagnant:
            return ordre[1] == premier
        case .place:
            return ordre[3] == premier
        case .couple:
            guard pari.chevaux.count == 2 else { return false }
            return Set(ordre.prefix(2)) == Set(pari.chevaux) || ordre[0] == premier
        }
    }

    static func texte(_ modele: String, _ nom: String) -> String {
        modele.replacingOccurrences(of: "{X}", with: nom)
    }

    /// Calcule toute la course : ordre d'arrivée, trajectoires par à-coups et commentaires.
    static func plan(_ chevaux: [CoursesCheval]) -> CoursesPlan {
        let n = chevaux.count
        let ordre = tirerOrdre(chevaux.map { $0.poids }, places: n)
        var arrivees = [Int](repeating: 0, count: n)
        var t = Int.random(in: 38...44)
        for c in ordre {
            arrivees[c] = t
            t += Int.random(in: 1...3)
        }

        var commentaires: [Int: [String]] = [:]
        func ajouter(_ tick: Int, _ texte: String) {
            commentaires[tick, default: []].append(texte)
        }

        var parcours: [[Double]] = []
        for c in 0..<n {
            let duree = max(1, arrivees[c])
            var increments: [Double] = (0..<duree).map { _ in Double.random(in: 0.3...1.7) }
            // Petites accélérations aléatoires.
            for _ in 0..<Int.random(in: 1...3) {
                let k = Int.random(in: 0..<duree)
                increments[k] *= 2.2
            }
            // Pause brouteuse (ou autre lubie).
            if duree > 24 && aleatoire() < 0.28 {
                let debut = Int.random(in: 8...(duree - 14))
                for k in debut..<min(duree, debut + 4) { increments[k] = 0 }
                let modele = CoursesTextes.pauses.randomElement() ?? "{X} s'arrête."
                ajouter(debut + 1, texte(modele, chevaux[c].nom))
            }
            let somme = max(increments.reduce(0, +), 0.000_001)
            var cumul: [Double] = [0]
            var s = 0.0
            for x in increments {
                s += x / somme
                cumul.append(min(0.999, s))
            }
            cumul[cumul.count - 1] = 1
            parcours.append(cumul)
        }

        func position(_ c: Int, _ tick: Int) -> Double {
            let p = parcours[c]
            return p[min(tick, p.count - 1)]
        }
        func tete(_ tick: Int) -> Int {
            (0..<n).max { position($0, tick) < position($1, tick) } ?? 0
        }
        func queue(_ tick: Int) -> Int {
            (0..<n).min { position($0, tick) < position($1, tick) } ?? 0
        }

        if let partant = chevaux.randomElement() {
            ajouter(1, texte(CoursesTextes.departs.randomElement() ?? "{X} s'élance !", partant.nom))
        }
        let premiereArrivee = arrivees.min() ?? 40
        var tick = 9
        var tour = 0
        while tick < premiereArrivee - 2 {
            switch tour % 3 {
            case 0:
                ajouter(tick, texte(CoursesTextes.tete.randomElement() ?? "{X} mène !", chevaux[tete(tick)].nom))
            case 1:
                ajouter(tick, texte(CoursesTextes.queue.randomElement() ?? "{X} est dernier.", chevaux[queue(tick)].nom))
            default:
                ajouter(tick, CoursesTextes.ambiance.randomElement() ?? "La foule hurle !")
            }
            tour += 1
            tick += Int.random(in: 7...10)
        }
        if let vainqueur = ordre.first {
            ajouter(arrivees[vainqueur], texte(CoursesTextes.arrivees.randomElement() ?? "{X} gagne !", chevaux[vainqueur].nom))
        }

        return CoursesPlan(ordre: ordre, parcours: parcours, arrivees: arrivees,
                           commentaires: commentaires, nbTicks: (arrivees.max() ?? 40) + 1)
    }

    static func texteCote(_ c: Double) -> String {
        if c >= 100 { return String(format: "%.0f", c.rounded(.down)) }
        var s = String(format: "%.2f", c)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Noms

enum CoursesNoms {
    static let chevaux = [
        "Tonnerre de Brest", "Pas Ce Soir Chéri", "Croissant Volant", "Mémé Supersonique", "Galop d'Essai Raté",
        "Fils de Personne", "Rillettes Express", "Prince du Bitume", "Jamais le Lundi", "Où Sont Mes Clés",
        "Fonce Gérard", "Tartine Beurrée", "Crise de la Quarantaine", "Paye Ta Tournée", "Sabot de Velours",
        "Ouragan de Poche", "Vent du Boulevard", "Ma Belle-Sœur", "Retraite Anticipée", "Café Serré",
        "Coup de Fourchette", "Dernier Métro", "Brouette Royale", "Patate Chaude", "Rêve de Foin",
        "Licorne Fatiguée", "Calme Plat", "Zéro Pointé", "Va Comprendre", "Bonne Excuse",
        "Flèche de Romorantin", "Pied de Biche", "Saucisse Sèche", "Fou du Volant", "Joie de Vivre Modérée",
        "Pantoufle Express", "Hennir de Rire", "Crinière au Vent", "Pluie du Matin", "Facture Impayée",
        "Promis Je Rembourse", "Météore du Dimanche", "Gros Câlin", "Tracteur Céleste", "Bisou Magique",
        "Fromage de Tête", "Plus Jamais Ça", "Avoine Divine", "Moustache Folle", "Rentre à la Maison",
        "Sieste Olympique", "Carotte Interdite",
    ]

    static let prix = [
        "Prix de la Belle-Mère", "Grand Prix du Comptoir", "Prix des Chaussettes Dépareillées",
        "Trophée du Lundi Pluvieux", "Prix Jean-Raoul de la Moquette", "Grand Prix du Crédit Revolving",
        "Prix de l'Avoine Tiède", "Critérium des Tocards", "Prix du Ticket Froissé", "Grand Steeple de la Sieste",
        "Prix des Espoirs Déçus", "Coupe du Loyer en Retard",
    ]
}

// MARK: - Textes

enum CoursesTextes {
    static let departs = [
        "Les stalles s'ouvrent ! {X} part comme une fusée.",
        "C'est parti ! {X} est parti… dans le mauvais sens, avant de se raviser.",
        "Départ donné ! {X} a mis deux secondes à comprendre ce qui se passait.",
        "Ils sont lâchés ! {X} prend un départ canon, son jockey un peu moins.",
        "Et c'est le départ ! {X} a éternué au moment du coup de pistolet.",
        "Départ ! {X} bondit, les sept autres suivent en râlant.",
    ]

    static let pauses = [
        "{X} s'arrête pour brouter !",
        "{X} s'arrête pour saluer sa mère dans les tribunes.",
        "{X} a vu un papillon. Il est perdu pour la science.",
        "{X} fait une pause pour réfléchir au sens de la vie.",
        "{X} refait ses lacets. Il n'a pas de lacets.",
        "{X} s'arrête net pour renifler un spectateur.",
        "{X} admire son reflet dans une flaque. Il se trouve beau.",
        "{X} a entendu un sachet de carottes s'ouvrir quelque part.",
        "{X} hésite, repart, puis hésite encore.",
    ]

    static let tete = [
        "{X} mène la danse !",
        "{X} est en tête et salue déjà la foule. Prématuré.",
        "C'est {X} qui caracole devant ! Son jockey prie en silence.",
        "{X} prend les commandes ! Ses parieurs se lèvent, les autres se rassoient.",
        "En tête : {X}, qui semble avoir avalé un moteur au petit-déjeuner.",
        "{X} file comme un livreur de pizza en retard !",
        "{X} est devant ! Pour l'instant. Rien n'est acquis, sauf les impôts.",
        "{X} accélère ! Le jockey a perdu son chapeau, mais pas sa dignité.",
    ]

    static let queue = [
        "{X} ferme la marche avec une sérénité admirable.",
        "{X} est dernier, mais dernier avec style.",
        "{X} semble avoir confondu course et balade digestive.",
        "Loin derrière, {X} profite du paysage.",
        "{X} traîne à l'arrière. On dirait qu'il attend le bus.",
        "{X} est bon dernier. Son entraîneur fait semblant de ne pas le connaître.",
    ]

    static let ambiance = [
        "Le peloton passe devant la buvette. Tentation palpable.",
        "Un pigeon traverse la piste. Personne ne s'arrête, sauf le pigeon.",
        "Le commentateur renverse son café. Il continue, très professionnel.",
        "La foule hurle. Un monsieur hurle plus fort : il a misé son camping-car.",
        "Les jockeys font des grimaces de concentration. Ou de douleur.",
        "Une dame en chapeau géant bouche la vue de tout le premier rang.",
        "Un enfant demande pourquoi les chevaux courent. Personne n'a de réponse satisfaisante.",
    ]

    static let arrivees = [
        "{X} l'emporte ! Il réclame une carotte et des droits télé.",
        "Victoire de {X} ! Son jockey pleure, son propriétaire calcule.",
        "{X} gagne d'un naseau ! Oui, d'un naseau.",
        "C'est {X} qui gagne ! La foule exulte, ou proteste, selon ses tickets.",
        "{X} passe la ligne en premier et ne comprend pas pourquoi tout le monde crie.",
        "Et c'est {X} ! Une victoire qui sent bon le foin et la revanche.",
    ]

    static let validation = [
        "Pari enregistré. Le guichetier mâchouille son crayon en te regardant.",
        "Ticket imprimé. Tu le tiens comme une relique.",
        "C'est joué. Tu commences déjà à parler à ton cheval à distance.",
        "Pari validé. Un vieux turfiste hoche la tête. Approbation ou pitié ?",
        "Enregistré ! Plus qu'à hurler des encouragements incompréhensibles.",
    ]

    static func gain(_ g: (String, String) -> String) -> [String] {
        [
            "Ton cheval a gagné ! Tu as envie de l'embrasser. Il a envie d'une carotte.",
            "Gagné ! Tu cries si fort que trois chevaux sursautent dans l'écurie d'à côté.",
            "Ticket gagnant ! Tu commences à parler de « ta science du turf ». Arrête.",
            "Bien joué ! Le guichetier te paie en grommelant que c'était évident.",
            "Victoire ! Tu offres une tournée imaginaire à tout l'hippodrome.",
            "Gagné ! Ton cheval et toi avez désormais un lien spirituel.",
            "Ça paie ! Tu t'achètes un chapeau ridicule pour fêter ça. Tu le portes déjà.",
            "Ton flair est récompensé. Ton flair, ou le hasard. Surtout le hasard.",
        ]
    }

    static func grosGain(_ g: (String, String) -> String) -> [String] {
        [
            "TOCARD GAGNANT ! L'hippodrome entier te regarde comme un prophète.",
            "Incroyable ! Tu avais misé sur le cheval dont tout le monde se moquait. Qui rit maintenant ?",
            "Énorme ! Le propriétaire du cheval te demande des conseils. Tu n'en as aucun.",
            "Coup de génie ! Tu raconteras cette course à tes petits-enfants, en exagérant.",
            "JACKPOT AU GALOP ! Ton ticket mérite un cadre doré et un garde du corps.",
            "Tu es " + g("devenu", "devenue") + " une légende du bar PMU du coin. On t'appelle désormais « le Devin ».",
        ]
    }

    static func perte(_ g: (String, String) -> String) -> [String] {
        [
            "Ton cheval a fini par arriver. Personne ne l'attendait plus.",
            "Perdu. Tu envisages de devenir cheval : ça a l'air moins stressant.",
            "Ton champion a couru avec le cœur. Malheureusement, pas avec les jambes.",
            "Raté ! Tu déchires ton ticket en confettis et tu les lances, seul, sans joie.",
            "Perdu. Ton cheval était peut-être meilleur en dressage. Ou en sieste.",
            "Le guichetier te fait un petit signe de compassion. C'est tout ce que tu récupères.",
            "Défaite. Tu soupçonnes le jockey d'avoir parié contre toi.",
            "Perdu ! « La prochaine, c'est la bonne », dis-tu, comme à chaque fois.",
            "Ton cheval a croisé un brin d'herbe intéressant. Fin de l'histoire.",
            "Tu es " + g("reparti", "repartie") + " avec un ticket froissé et une odeur de crottin. Bilan mitigé.",
        ]
    }

    static let presque = [
        "À une encolure près ! Une encolure, c'est long quand on la regarde de près.",
        "Si près… Ton cheval a ralenti avant la ligne pour poser pour les photographes.",
        "Presque ! La photo d'arrivée a tranché, et elle a tranché contre toi.",
        "Ton cheval termine juste derrière. Il dit qu'il a fait exprès, pour le suspense.",
        "Raté d'un poil. D'un poil de crinière, pour être précis.",
        "Tellement près que tu as levé les bras. Puis tu les as baissés, lentement.",
    ]

    static let mixte = [
        "Un pari gagnant, mais les autres ont tout mangé. Comme des chevaux devant un sac d'avoine.",
        "Gagné d'un côté, perdu de l'autre. L'hippodrome, lui, a gagné des deux côtés.",
        "Tu as eu du flair une fois sur deux. Ton porte-monnaie aurait préféré deux fois sur deux.",
        "Un bon pari ne suffit pas à sauver une mauvaise journée. Proverbe de turfiste.",
    ]
}

// MARK: - Vue principale

struct CoursesVue: View {
    let lieu: CasinoLieu
    @EnvironmentObject var engine: GameEngine

    @State private var chevaux: [CoursesCheval] = []
    @State private var nomCourse: String = ""
    @State private var typePari: CoursesTypePari = .gagnant
    @State private var choix: [Int] = []
    @State private var paris: [CoursesPari] = []
    @State private var mise: Int = 0
    @State private var phase: CoursesPhase = .paris
    @State private var plan: CoursesPlan?
    @State private var tick: Int = 0
    @State private var fil: [CoursesLigneFil] = []
    @State private var message: String?
    @State private var messageGain: Bool?

    private let maxParis = 4

    static let casaques: [Color] = [
        Color(red: 0.85, green: 0.15, blue: 0.15), Color(red: 0.15, green: 0.4, blue: 0.85),
        Color(red: 0.95, green: 0.8, blue: 0.1), Color(red: 0.1, green: 0.6, blue: 0.3),
        Color(red: 0.6, green: 0.2, blue: 0.7), Color(red: 0.95, green: 0.5, blue: 0.1),
        Color(red: 0.95, green: 0.45, blue: 0.65), Color(white: 0.15),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                entete
                CoursesPiste(chevaux: chevaux, plan: plan, tick: tick, mises: chevauxMises)
                if phase != .paris {
                    filCommentaires
                }
                if phase == .arrivee {
                    classement
                }
                if phase == .paris {
                    choixType
                    listeChevaux
                    ticketEnCours
                }
                if !paris.isEmpty {
                    parisPlaces
                }
                if let m = message {
                    CasinoBandeau(texte: m, gain: messageGain)
                }
                actions
            }
            .padding()
        }
        .onAppear {
            if chevaux.isEmpty { nouvelleCourse() }
        }
    }

    // MARK: Infos

    @MainActor private var argent: Int { engine.joueur?.argent ?? 0 }

    private var chevauxMises: Set<Int> {
        var s = Set<Int>()
        for p in paris { for c in p.chevaux { s.insert(c) } }
        return s
    }

    private func cheval(_ id: Int) -> CoursesCheval? {
        id >= 0 && id < chevaux.count ? chevaux[id] : nil
    }

    private var choixComplet: Bool { choix.count == typePari.nombreChevaux }

    private var coteChoix: Double? {
        guard choixComplet, let premier = choix.first, let c = cheval(premier) else { return nil }
        switch typePari {
        case .gagnant: return c.cote
        case .place: return c.cotePlace
        case .couple: return CoursesMoteur.coteCouple(choix[0], choix[1], chevaux: chevaux)
        }
    }

    private var libelleChoix: String {
        let noms = choix.compactMap { cheval($0) }.map { "n°\($0.numero) \($0.nom)" }
        switch typePari {
        case .gagnant: return "Gagnant : " + noms.joined()
        case .place: return "Placé : " + noms.joined()
        case .couple: return "Couplé : " + noms.joined(separator: " puis ")
        }
    }

    @MainActor private var peutParier: Bool {
        phase == .paris && coteChoix != nil && paris.count < maxParis
            && CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent)
    }

    // MARK: Sous-vues

    private var entete: some View {
        VStack(spacing: 4) {
            Text("🏇 \(nomCourse)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(CasinoStyle.or)
                .multilineTextAlignment(.center)
            Text("8 partants · 2 100 m · terrain « collant comme le comptoir »")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var filCommentaires: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("En direct de la tribune", systemImage: "mic.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(CasinoStyle.or)
            if fil.isEmpty {
                Text("Les chevaux entrent dans les stalles…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            ForEach(Array(fil.suffix(3).reversed())) { ligne in
                Text("🎙️ \(ligne.texte)")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var classement: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Classement officiel").font(.headline).foregroundStyle(CasinoStyle.or)
            if let p = plan {
                ForEach(Array(p.ordre.enumerated()), id: \.offset) { rang, id in
                    if let c = cheval(id) {
                        ligneClassement(rang: rang + 1, cheval: c)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
    }

    private func ligneClassement(rang: Int, cheval c: CoursesCheval) -> some View {
        HStack(spacing: 8) {
            Text(CoursesVue.medaille(rang))
                .font(.subheadline.weight(.heavy))
                .frame(width: 34, alignment: .leading)
            CoursesNumero(numero: c.numero)
            Text(c.nom)
                .font(.subheadline.weight(rang == 1 ? .heavy : .regular))
                .lineLimit(1)
            Spacer()
            Text(CoursesMoteur.texteCote(c.cote))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            if chevauxMises.contains(c.id) {
                Image(systemName: "ticket.fill").foregroundStyle(CasinoStyle.or)
            }
        }
        .foregroundStyle(rang <= 3 ? CasinoStyle.or : Color.white)
    }

    static func medaille(_ rang: Int) -> String {
        switch rang {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rang)e"
        }
    }

    private var choixType: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ForEach(CoursesTypePari.allCases, id: \.self) { t in
                    Button {
                        typePari = t
                        choix = []
                    } label: {
                        Text(t.nom)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(typePari == t ? CasinoStyle.or : Color.black.opacity(0.3), in: Capsule())
                            .foregroundStyle(typePari == t ? CasinoStyle.nuit : Color.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(typePari.explication)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var listeChevaux: some View {
        VStack(spacing: 6) {
            ForEach(chevaux) { c in
                CoursesChevalLigne(cheval: c,
                                   badge: badge(c.id),
                                   selectionne: choix.contains(c.id)) {
                    toucher(c.id)
                }
            }
            Text("La « musique », ce sont les dernières places du cheval (T = tombé, 0 = au-delà de 9e). Ça ne garantit rien, comme l'horoscope.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func badge(_ id: Int) -> String? {
        guard let i = choix.firstIndex(of: id) else { return nil }
        if typePari == .couple { return i == 0 ? "1er" : "2e" }
        return "✓"
    }

    @MainActor private var ticketEnCours: some View {
        VStack(alignment: .leading, spacing: 10) {
            if choixComplet, let cote = coteChoix {
                HStack {
                    Text(libelleChoix)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                    Spacer()
                    Text(CoursesMoteur.texteCote(cote))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(CasinoStyle.or)
                }
                .foregroundStyle(.white)
                CasinoSelecteurMise(mise: $mise, lieu: lieu, argent: argent)
                Text("Gain potentiel : \(Format.argent(Int(Double(mise) * cote)))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                CasinoBouton(titre: paris.count >= maxParis ? "Maximum \(maxParis) paris par course" : "Placer le pari",
                             actif: peutParier) {
                    placerPari()
                }
            } else {
                Text(typePari == .couple
                     ? (choix.isEmpty ? "Touche le cheval qui finira 1er, puis celui qui finira 2e." : "Et maintenant, le 2e ?")
                     : "Touche un cheval pour parier dessus.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
    }

    private var parisPlaces: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tes paris").font(.headline).foregroundStyle(CasinoStyle.or)
            ForEach(paris) { p in
                CoursesPariVue(pari: p, resultatVisible: phase == .arrivee)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor @ViewBuilder private var actions: some View {
        switch phase {
        case .paris:
            CasinoBouton(titre: paris.isEmpty ? "Place un pari pour lancer la course" : "Départ !",
                         couleur: CasinoStyle.rouge,
                         actif: !paris.isEmpty) {
                depart()
            }
            if paris.isEmpty {
                CasinoBouton(titre: "Voir une autre course", couleur: Color.black.opacity(0.45)) {
                    nouvelleCourse()
                }
            }
        case .course:
            HStack(spacing: 10) {
                ProgressView().tint(CasinoStyle.or)
                Text("Course en cours… Tu tapes du pied sans t'en rendre compte.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 8)
        case .arrivee:
            CasinoBouton(titre: "Course suivante") {
                nouvelleCourse()
            }
        }
    }

    // MARK: Actions

    private func toucher(_ id: Int) {
        guard phase == .paris else { return }
        if let i = choix.firstIndex(of: id) {
            choix.remove(at: i)
            return
        }
        if typePari == .couple {
            if choix.count < 2 { choix.append(id) } else { choix[1] = id }
        } else {
            choix = [id]
        }
    }

    private func nouvelleCourse() {
        let nouveaux = CoursesMoteur.nouvelleCourse()
        withAnimation {
            chevaux = nouveaux
            nomCourse = CoursesNoms.prix.randomElement() ?? "Grand Prix"
            choix = []
            paris = []
            plan = nil
            tick = 0
            fil = []
            phase = .paris
            message = nil
            messageGain = nil
        }
    }

    @MainActor private func placerPari() {
        guard phase == .paris, paris.count < maxParis, choixComplet, let cote = coteChoix else { return }
        guard CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent) else {
            message = "Mise impossible : entre \(Format.argent(lieu.miseMin)) et \(Format.argent(min(lieu.miseMax, argent)))."
            messageGain = false
            return
        }
        let pari = CoursesPari(type: typePari, chevaux: choix, cote: cote, mise: mise, libelle: libelleChoix)
        guard engine.casinoMiser(mise, jeu: .courses) else {
            message = "Le guichetier secoue la tête. Pas assez d'argent, pas de pari."
            messageGain = false
            return
        }
        withAnimation {
            paris.append(pari)
            choix = []
            message = CoursesTextes.validation.randomElement()
            messageGain = nil
        }
    }

    @MainActor private func depart() {
        guard phase == .paris, !paris.isEmpty, !chevaux.isEmpty else { return }
        let p = CoursesMoteur.plan(chevaux)
        var resultats = paris
        for i in resultats.indices {
            resultats[i].gagne = CoursesMoteur.pariGagnant(resultats[i], ordre: p.ordre)
        }
        let parisJoues = resultats
        let moteur = engine
        let ticks = p.nbTicks

        plan = p
        tick = 0
        fil = []
        choix = []
        message = nil
        messageGain = nil
        phase = .course

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            for t in 1...max(1, ticks) {
                try? await Task.sleep(nanoseconds: 150_000_000)
                withAnimation(.linear(duration: 0.15)) {
                    tick = t
                }
                if let textes = p.commentaires[t] {
                    withAnimation(.easeOut(duration: 0.25)) {
                        for texte in textes { fil.append(CoursesLigneFil(texte: texte)) }
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            let bilan = CoursesVue.regler(parisJoues, ordre: p.ordre, engine: moteur)
            withAnimation(.spring()) {
                paris = parisJoues
                phase = .arrivee
                message = bilan.texte
                messageGain = bilan.gain
            }
        }
    }

    /// Règle chaque pari (un appel à casinoRegler par pari) et renvoie le bilan.
    @MainActor private static func regler(_ paris: [CoursesPari], ordre: [Int], engine: GameEngine) -> (texte: String, gain: Bool?) {
        var totalMise = 0
        var totalPaye = 0
        var meilleurMultiplicateur = 0.0
        var unGagnant = false
        var presque = false
        for p in paris {
            let gagne = p.gagne == true
            let paiement = gagne ? p.gainPotentiel : 0
            engine.casinoRegler(mise: p.mise, paiement: paiement, jeu: .courses,
                                detail: "Courses hippiques (\(p.type.nom.lowercased()))")
            totalMise += p.mise
            totalPaye += paiement
            if gagne {
                unGagnant = true
                meilleurMultiplicateur = max(meilleurMultiplicateur, p.cote)
            } else if CoursesMoteur.pariPresque(p, ordre: ordre) {
                presque = true
            }
        }
        let joueur = engine.joueur
        let g: (String, String) -> String = { m, f in joueur?.g(m, f) ?? m }
        let net = totalPaye - totalMise
        let phrase: String
        if net > 0 {
            phrase = (meilleurMultiplicateur >= 15 ? CoursesTextes.grosGain({ g($0, $1) }) : CoursesTextes.gain({ g($0, $1) })).randomElement() ?? ""
        } else if unGagnant {
            phrase = CoursesTextes.mixte.randomElement() ?? ""
        } else if presque {
            phrase = CoursesTextes.presque.randomElement() ?? ""
        } else {
            phrase = CoursesTextes.perte({ g($0, $1) }).randomElement() ?? ""
        }
        let bilan: String
        if net > 0 {
            bilan = "Tu encaisses \(Format.argent(totalPaye)) (+\(Format.argent(net)))."
        } else if totalPaye > 0 {
            bilan = "Tu récupères \(Format.argent(totalPaye)) sur \(Format.argent(totalMise)) misés."
        } else {
            bilan = "Tu perds \(Format.argent(totalMise))."
        }
        let gain: Bool? = net > 0 ? true : (net < 0 ? false : nil)
        return (phrase + "\n" + bilan, gain)
    }
}

// MARK: - Piste

struct CoursesPiste: View {
    let chevaux: [CoursesCheval]
    let plan: CoursesPlan?
    let tick: Int
    let mises: Set<Int>

    var body: some View {
        VStack(spacing: 2) {
            ForEach(chevaux) { c in
                couloir(c)
            }
        }
        .padding(6)
        .background(Color(red: 0.2, green: 0.45, blue: 0.2), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
        )
    }

    private func couloir(_ c: CoursesCheval) -> some View {
        HStack(spacing: 4) {
            CoursesNumero(numero: c.numero)
                .overlay(
                    Circle().strokeBorder(mises.contains(c.id) ? CasinoStyle.or : Color.clear, lineWidth: 2)
                        .frame(width: 26, height: 26)
                )
            GeometryReader { geo in
                piste(c, largeur: geo.size.width)
            }
            .frame(height: 28)
        }
    }

    private func piste(_ c: CoursesCheval, largeur: CGFloat) -> some View {
        let course = max(0, largeur - 34)
        let position = CGFloat(plan?.position(c.id, tick) ?? 0)
        let arrive = plan?.estArrive(c.id, tick) ?? false
        let place = plan?.place(c.id) ?? 0
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(c.id % 2 == 0 ? Color(red: 0.72, green: 0.55, blue: 0.33) : Color(red: 0.66, green: 0.49, blue: 0.29))
            CoursesLigneArrivee()
                .frame(width: 6)
                .offset(x: largeur - 6)
            HStack(spacing: 0) {
                Text("🐎")
                    .font(.system(size: 22))
                    .scaleEffect(x: -1, y: 1)
                if arrive && place > 0 && place <= 3 {
                    Text(CoursesVue.medaille(place))
                        .font(.system(size: 12))
                }
            }
            .offset(x: course * position)
        }
        .clipped()
    }
}

struct CoursesLigneArrivee: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { k in
                HStack(spacing: 0) {
                    Rectangle().fill(k % 2 == 0 ? Color.white : Color.black)
                    Rectangle().fill(k % 2 == 0 ? Color.black : Color.white)
                }
            }
        }
    }
}

struct CoursesNumero: View {
    let numero: Int

    var body: some View {
        let couleur = CoursesVue.casaques[(numero - 1 + CoursesVue.casaques.count) % CoursesVue.casaques.count]
        return Text("\(numero)")
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(numero == 3 ? Color.black : Color.white)
            .frame(width: 22, height: 22)
            .background(couleur, in: Circle())
    }
}

// MARK: - Ligne de cheval (paris)

struct CoursesChevalLigne: View {
    let cheval: CoursesCheval
    let badge: String?
    let selectionne: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                CoursesNumero(numero: cheval.numero)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cheval.nom)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("Musique : \(cheval.musique)")
                        .font(.caption2)
                        .opacity(0.7)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CoursesMoteur.texteCote(cheval.cote))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("placé \(CoursesMoteur.texteCote(cheval.cotePlace))")
                        .font(.caption2)
                        .opacity(0.7)
                }
                if let b = badge {
                    Text(b)
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(CasinoStyle.rouge, in: Capsule())
                        .foregroundStyle(Color.white)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selectionne ? CasinoStyle.or : Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(selectionne ? CasinoStyle.nuit : Color.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pari placé

struct CoursesPariVue: View {
    let pari: CoursesPari
    let resultatVisible: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pari.libelle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text("Mise \(Format.argent(pari.mise)) × \(CoursesMoteur.texteCote(pari.cote))")
                    .font(.caption2)
            }
            Spacer()
            Text(statut)
                .font(.caption.weight(.heavy))
                .foregroundStyle(couleurStatut)
        }
        .foregroundStyle(CasinoStyle.nuit)
        .padding(10)
        .background(CasinoStyle.creme, in: RoundedRectangle(cornerRadius: 8))
    }

    private var statut: String {
        guard resultatVisible, let g = pari.gagne else { return "→ \(Format.argent(pari.gainPotentiel))" }
        return g ? "GAGNÉ \(Format.argent(pari.gainPotentiel))" : "PERDU"
    }

    private var couleurStatut: Color {
        guard resultatVisible, let g = pari.gagne else { return CasinoStyle.nuit }
        return g ? Color(red: 0.1, green: 0.55, blue: 0.25) : CasinoStyle.rouge
    }
}

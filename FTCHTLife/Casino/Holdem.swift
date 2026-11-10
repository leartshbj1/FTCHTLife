import SwiftUI

// MARK: - Personnalités des adversaires

/// Un adversaire-robot de la table de poker clandestine.
struct HoldemPersonnalite {
    let id: String
    let nom: String
    let emoji: String
    let portrait: String
    /// Force relative (1 = main moyenne) à partir de laquelle il suit.
    let seuilSuivre: Double
    /// Force relative à partir de laquelle il relance.
    let seuilRelance: Double
    /// Probabilité de relancer avec n'importe quoi.
    let bluff: Double
    /// Exigence sur la cote du pot (> 1 = se couche plus volontiers).
    let prudence: Double
    /// Ajout à la force perçue (> 0 = se croit toujours le meilleur).
    let optimisme: Double
    /// Amplitude du hasard dans ses décisions.
    let chaos: Double
    let arrivee: [String]
    let coucher: [String]
    let parole: [String]
    let suivre: [String]
    let relancer: [String]
    let gagne: [String]
    let ruine: [String]
}

enum HoldemCasting {
    static let tous: [HoldemPersonnalite] = [
        HoldemPersonnalite(
            id: "ginette", nom: "Mamie Ginette", emoji: "🧶",
            portrait: "Tricote entre deux mains. Ne joue que les As, et encore.",
            seuilSuivre: 1.45, seuilRelance: 2.1, bluff: 0.01, prudence: 1.6, optimisme: -0.1, chaos: 0.5,
            arrivee: ["Bonjour les jeunes. J'ai apporté des madeleines, elles ne sont pas pour vous.",
                      "Ginette s'assoit, sort ses aiguilles et une chaussette à moitié finie.",
                      "Je joue juste pour arrondir ma retraite. Et la vôtre, je vais la raccourcir."],
            coucher: ["Trop risqué. Je retourne à mon point mousse.",
                      "Non merci, mon cœur ne supporterait pas.",
                      "Je me couche. À mon âge on se couche tôt."],
            parole: ["Je ne dis rien. C'est plus poli.",
                     "Parole, mon petit.",
                     "*compte ses mailles* … parole."],
            suivre: ["Bon, je suis. Mais c'est bien parce que c'est toi.",
                     "Je suis. Ne le dites pas à mon kiné.",
                     "Je suis, comme feu mon Raymond suivait le tiercé."],
            relancer: ["Je relance. Oui, la mamie relance. Respire.",
                       "Tiens, une petite relance, comme un petit gâteau.",
                       "Je relance, et je tricote plus vite."],
            gagne: ["Ah ! Ça fera un bon goûter pour les petits-enfants.",
                    "Merci mes chéris. Vous êtes gentils de perdre.",
                    "*range les jetons dans un porte-monnaie en cuir de 1974*"],
            ruine: ["Bon, je rentre, il y a mon jeu télévisé.",
                    "Ruinée mais digne. Ginette range son tricot et s'en va.",
                    "Plus un sou. Je vais devoir vendre le service en porcelaine."]),
        HoldemPersonnalite(
            id: "kevin", nom: "Kévin-Lancelot", emoji: "🕶️",
            portrait: "Lunettes de soleil à 3 h du matin. Bluffe comme il respire.",
            seuilSuivre: 0.7, seuilRelance: 1.2, bluff: 0.28, prudence: 0.6, optimisme: 0.3, chaos: 1.5,
            arrivee: ["Yo la team. J'ai vendu une photo de mon chat en jeton numérique, je suis liquide.",
                      "Kévin-Lancelot s'assoit à l'envers sur sa chaise. Personne ne sait pourquoi.",
                      "On va jouer comme des loups. Des loups de la finance."],
            coucher: ["Je me couche, mais c'est stratégique. Tu peux pas comprendre.",
                      "Je lâche. Je garde mon énergie pour mon podcast.",
                      "Je me couche, mais en vrai j'avais un carré. Ou pas. Tu sauras jamais."],
            parole: ["Parole. Comme un vrai PDG.",
                     "Parole. Je laisse le marché respirer.",
                     "Je check, je check, je check-in."],
            suivre: ["Je suis. Pour le contenu.",
                     "Je suis, ça va faire un fil de discussion incroyable.",
                     "Je suis, mon horoscope financier est au vert."],
            relancer: ["RELANCE. Direction la Lune !",
                       "Je relance avec rien, et alors ? C'est ça, l'esprit start-up.",
                       "Relance ! Je pivote vers la victoire.",
                       "Je relance. Mes lunettes cachent ma peur."],
            gagne: ["FACILE. Je vais en faire une formation à 997 €.",
                    "C'est ça, le mental de gagnant, les gars.",
                    "Je réinvestis tout dans une boisson énergisante."],
            ruine: ["Je suis pas ruiné, je suis en phase de pré-rentabilité.",
                    "Kévin-Lancelot s'en va en promettant de revenir avec des investisseurs.",
                    "Je vais lever des fonds auprès de ma mère. Ciao."]),
        HoldemPersonnalite(
            id: "gerard", nom: "Gérard la Mâchoire", emoji: "🦈",
            portrait: "Le requin de la table. Boit de l'eau plate. Ne cligne jamais des yeux.",
            seuilSuivre: 1.1, seuilRelance: 1.45, bluff: 0.07, prudence: 1.0, optimisme: 0, chaos: 0.3,
            arrivee: ["Gérard s'assoit sans un mot et commande de l'eau plate. Mauvais signe.",
                      "Bonsoir. Je ne suis pas là pour m'amuser.",
                      "Il pose ses jetons en piles parfaitement alignées. Tout le monde frissonne."],
            coucher: ["Pas rentable.",
                      "Je me couche. Les chiffres sont clairs.",
                      "*soupire comme si tu l'avais déçu personnellement*"],
            parole: ["Parole.",
                     "Je te laisse parler. Je t'écoute… vraiment.",
                     "Parole. Je t'observe."],
            suivre: ["Je suis. Pour l'instant.",
                     "Je paie. Continue de faire ça.",
                     "Je paie pour voir. J'aime bien voir."],
            relancer: ["Relance. Ne le prends pas personnellement.",
                       "Je relance. Ton tic à l'œil gauche m'a tout dit.",
                       "Relance. Tu transpires, on dirait."],
            gagne: ["Merci pour ta contribution.",
                    "*empile les jetons sans sourire, ce qui est pire*",
                    "Prévisible."],
            ruine: ["« Ce n'était pas ma soirée. Ce sera la tienne bientôt. »",
                    "Même les requins ont des jours sans. Gérard s'éloigne en nageant.",
                    "Il part sans un mot. Le silence est assourdissant."]),
        HoldemPersonnalite(
            id: "jeanmi", nom: "Jean-Mi du Kebab", emoji: "🥙",
            portrait: "Suit absolument tout. Pose ses frites sur le tapis.",
            seuilSuivre: 0.4, seuilRelance: 1.9, bluff: 0.03, prudence: 0.3, optimisme: 0.2, chaos: 0.6,
            arrivee: ["Jean-Mi pose une barquette de frites sur le tapis. Personne n'ose rien dire.",
                      "Salut ! Je suis juste venu pour l'ambiance et la sauce blanche.",
                      "Je comprends pas trop les règles mais j'ai de la chance aux grattages."],
            coucher: ["Oh, je me couche, il y a de la sauce sur mes cartes de toute façon.",
                      "J'arrête, c'est trop de maths.",
                      "Je me couche. Mes frites refroidissent."],
            parole: ["Euh… parole ? C'est comme ça qu'on dit ?",
                     "Je dis rien, je mange.",
                     "Parole ! *la bouche pleine*"],
            suivre: ["Je suis ! Je suis toujours, moi.",
                     "Allez, je suis, on vit qu'une fois.",
                     "Je suis. J'ai deux cartes, c'est déjà pas mal.",
                     "Je suis, je veux voir la suite, c'est comme une série."],
            relancer: ["Je relance ? Oh, j'ai appuyé sur un truc.",
                       "Relance ! J'ai un bon pressentiment, ou une indigestion.",
                       "Allez hop, relance, c'est ma tournée."],
            gagne: ["J'AI GAGNÉ ? Mais avec quoi ?",
                    "Frites pour tout le monde ! … Non, en fait, pour moi.",
                    "C'est le kebab qui porte chance, je l'ai toujours dit."],
            ruine: ["Plus de jetons. Il me reste une frite. Je la garde.",
                    "Jean-Mi s'en va en se léchant les doigts, ruiné mais rassasié.",
                    "Je retourne au kebab, au moins là-bas j'ai une carte de fidélité."]),
        HoldemPersonnalite(
            id: "bouboule", nom: "Professeur Bouboule", emoji: "🧮",
            portrait: "Calcule tout à voix haute. Se trompe une fois sur deux.",
            seuilSuivre: 1.2, seuilRelance: 1.7, bluff: 0.03, prudence: 1.15, optimisme: 0, chaos: 0.25,
            arrivee: ["Le professeur Bouboule installe un tableau noir pliant. Personne ne lui a rien demandé.",
                      "Bonsoir. J'ai calculé que j'allais gagner. Avec une marge d'erreur de 100 %.",
                      "J'ai lu trois livres sur le poker. Enfin, les couvertures."],
            coucher: ["Selon mes calculs, je perds. Je me couche, comme une fonction décroissante.",
                      "Probabilité de victoire : 12,7 %. Je me retire.",
                      "Je me couche. Les mathématiques sont formelles, et cruelles."],
            parole: ["Parole. Variable en attente.",
                     "Je ne mise pas. C'est l'élément neutre.",
                     "Parole. J'additionne."],
            suivre: ["Cote du pot favorable : je suis. Normalement.",
                     "Je suis, d'après le théorème de Moi-Même.",
                     "J'ai fait une règle de trois : je suis."],
            relancer: ["Relance ! Mon espérance est positive. Enfin, je crois.",
                       "Je relance d'exactement une unité de relance. Fascinant, non ?",
                       "Relance. CQFD."],
            gagne: ["Comme prévu par mes équations. Celles du deuxième essai.",
                    "La science triomphe !",
                    "Victoire. Je vais en faire une publication."],
            ruine: ["Erreur d'arrondi. Je quitte la table.",
                    "Le professeur s'en va en marmonnant « le hasard est une hypothèse ».",
                    "Je rentre recalculer chez moi. Pendant dix ans."]),
        HoldemPersonnalite(
            id: "raymonde", nom: "Tata Raymonde", emoji: "💄",
            portrait: "Boa en plumes, parfum qui pique. Totalement imprévisible.",
            seuilSuivre: 0.9, seuilRelance: 1.4, bluff: 0.14, prudence: 0.9, optimisme: 0.1, chaos: 2.0,
            arrivee: ["Tata Raymonde arrive avec un boa en plumes et un parfum qui pique les yeux.",
                      "Bonsoir les beaux ! Qui veut voir mes photos de croisière ?",
                      "Raymonde embrasse tout le monde, même ceux qui n'ont rien demandé."],
            coucher: ["Ooooh je me couche, comme à la croisière de 98.",
                      "Non, pas cette fois. Ces cartes ont une mauvaise énergie.",
                      "Je me couche, mais je reste pour les potins."],
            parole: ["Parole ! Ça veut dire « joker », non ?",
                     "Je passe, mon chéri, je passe.",
                     "Parole, et un petit kir s'il vous plaît."],
            suivre: ["Je suis ! J'adore suivre, au bal aussi.",
                     "Allez, je suis, la vie est courte et mes ongles sont longs.",
                     "Je suis. Ma voyante m'a dit d'oser."],
            relancer: ["Je relance ! Pour l'amour !",
                       "RELANCE ! Ça me rappelle mon troisième mari.",
                       "Tiens, je relance, mais c'est pas méchant."],
            gagne: ["Youhou ! Je m'offre une nouvelle perruque !",
                    "*fait un petit tour sur elle-même, le boa perd des plumes*",
                    "Gagné ! C'est la robe à paillettes, ça."],
            ruine: ["Plus rien ! Bon, j'appelle mon quatrième mari.",
                    "Raymonde s'en va en laissant une traînée de plumes et de parfum.",
                    "Ruinée, mais coiffée. C'est l'essentiel."]),
        HoldemPersonnalite(
            id: "momo", nom: "Momo le Muet", emoji: "🤐",
            portrait: "N'a jamais prononcé un mot. On ne sait même pas s'il s'appelle Momo.",
            seuilSuivre: 1.05, seuilRelance: 1.55, bluff: 0.08, prudence: 1.0, optimisme: 0.05, chaos: 0.8,
            arrivee: ["Momo s'assoit. Il ne dit rien. Il ne dira jamais rien.",
                      "Un homme en imperméable s'installe. On l'appelle Momo. Lui ne s'appelle pas.",
                      "*hoche la tête une fois. C'est son discours de bienvenue.*"],
            coucher: ["*jette ses cartes avec une infinie tristesse*",
                      "*fait non de la tête, très lentement*",
                      "*soupire. C'est le plus long discours de sa vie.*"],
            parole: ["*tapote deux fois la table*",
                     "*cligne des yeux*",
                     "*…*"],
            suivre: ["*pousse ses jetons du bout de l'index*",
                     "*hausse un sourcil, et paie*",
                     "*suit sans te quitter des yeux*"],
            relancer: ["*pousse une pile de jetons. Le silence devient lourd.*",
                       "*relance et croise les bras*",
                       "*relance. Une mouche s'arrête de voler.*"],
            gagne: ["*esquisse un sourire de 0,3 seconde*",
                    "*ramasse les jetons comme on cueille des champignons*",
                    "*hoche la tête. Satisfait.*"],
            ruine: ["*se lève, met son chapeau, et disparaît dans la nuit*",
                    "Momo est parti. On n'est même pas sûr qu'il était là.",
                    "*laisse un mot sur la table : « … »*"]),
        HoldemPersonnalite(
            id: "brigitte", nom: "Brigitte des Douanes", emoji: "🛃",
            portrait: "Douanière à la retraite. Agressive, soupçonneuse, tamponne tout.",
            seuilSuivre: 0.9, seuilRelance: 1.25, bluff: 0.12, prudence: 0.85, optimisme: 0.1, chaos: 0.7,
            arrivee: ["Brigitte fouille ton regard. Tu n'as rien à déclarer ?",
                      "Brigitte s'installe et confisque la coupelle de cacahuètes.",
                      "Contrôle de routine. Mains sur la table, bien visibles."],
            coucher: ["Je me couche, mais je garde un œil sur toi.",
                      "Abandon temporaire. Le dossier reste ouvert.",
                      "Je lâche. Pour cette fois. Sous réserve."],
            parole: ["Parole. Vous avez le droit de garder le silence.",
                     "Parole. Papiers, s'il vous plaît.",
                     "Parole. Le chien renifle."],
            suivre: ["Je suis. Je suis toujours les suspects.",
                     "Je paie. Votre comportement est noté.",
                     "Je suis, et je photocopie."],
            relancer: ["Relance ! Taxe à l'importation.",
                       "Je relance. Ouvrez le coffre.",
                       "Relance ! Droits de douane majorés."],
            gagne: ["Saisie !",
                    "Marchandise confisquée. Merci de votre coopération.",
                    "*tamponne les jetons avant de les empiler*"],
            ruine: ["Brigitte part en exigeant une facture. Il n'y en a pas, c'est un tripot.",
                    "Je vais faire un rapport à ma hiérarchie. Je n'en ai plus. Tant pis.",
                    "Ruinée. Elle confisque une chaise en partant, par principe."]),
    ]
}

// MARK: - Textes de la table

enum HoldemTextes {
    static let victoire = [
        "Les robots applaudissent poliment, sauf un qui grince.",
        "Tu ramasses les jetons avec la grâce d'un pélican qui avale un poisson.",
        "Quelqu'un murmure « coup de chance ». Tu le prends comme un compliment.",
        "Le patron du tripot te regarde avec un nouveau respect. Et un peu de méfiance.",
        "Tu fais une petite danse intérieure. À l'extérieur, seul ton sourcil tremble.",
        "Les jetons glissent vers toi avec un bruit merveilleux. Tu voudrais l'avoir en sonnerie.",
        "Tu viens de financer ton prochain kebab. Et celui d'après.",
        "Une larme coule sur la joue d'un adversaire. Tu fais semblant de ne pas voir.",
    ]

    static let abandon = [
        "Tout le monde s'est couché. Tu ne sauras jamais si tu avais la meilleure main. Eux non plus.",
        "Personne n'a osé. C'est ton regard. Ou ton parfum.",
        "Victoire sans combat. Un vieux général chinois serait fier de toi.",
        "Ils se sont tous couchés. Ta main restera un mystère, comme le contenu des saucisses.",
        "Tu ramasses le pot en sifflotant. Quelqu'un siffle aussi, mais de colère.",
        "Pot gagné sans montrer tes cartes. Tu les caches contre ton cœur, très mystérieusement.",
    ]

    static let defaite = [
        "Tes jetons partent vers un autre horizon. Fais-leur coucou.",
        "Tu étais sûr{e} de toi. C'était mignon.",
        "Ton plan avait la solidité d'un parapluie en chocolat.",
        "Tu fixes tes cartes comme si elles allaient changer d'avis.",
        "La table entière fait « ooooh ». Pas le bon « ooooh ».",
        "Tu vas dire que c'était de la malchance. Un peu. Surtout de l'obstination.",
        "Les jetons s'en vont. Tu leur avais pourtant donné des prénoms.",
        "Tu fais semblant de rire. Ton portefeuille, lui, pleure pour de vrai.",
    ]

    static let partage = [
        "Égalité ! Le pot est coupé en parts, comme une pizza entre gens polis.",
        "Mêmes mains, même rage contenue. Partage.",
        "Le hasard n'a pas su choisir. Il a rendu tout le monde un peu moins pauvre.",
        "Partage du pot. Personne n'est content, c'est le principe de la justice.",
        "Ex æquo. Le patron du tripot râle : il préfère quand quelqu'un pleure.",
    ]

    static let couche = [
        "Tu t'es couché{e}. Sage décision, ou lâcheté stratégique.",
        "Tu regardes la fin de la main en mangeant des cacahuètes d'un autre siècle.",
        "Couché{e}. Tu observes, tu analyses, tu bâilles.",
        "Tu as jeté tes cartes. Elles ne t'en veulent pas.",
        "Hors du coup. Au moins, tes jetons restants ne risquent rien. Ceux-là.",
        "Tu fais comme si ta main était horrible. Peut-être qu'elle l'était.",
    ]

    static let ruine = [
        "Tu n'as plus un seul jeton. Le silence autour de la table est presque respectueux.",
        "À sec. Même la plante verte du tripot a l'air triste pour toi.",
        "Plus de jetons. Les robots te regardent comme un buffet vide.",
        "Tu fouilles tes poches. Tu trouves un ticket de bus et un regret.",
        "Ta pile de jetons a disparu. Il n'en reste que l'empreinte, comme un fossile.",
        "Ruiné{e} à la table. Tu peux recaver… ou garder un peu de dignité.",
    ]

    static let tricheReussie = [
        "Tu glisses un as de ta manche avec la dextérité d'un magicien de mariage. Personne n'a rien vu.",
        "Un as apparaît dans ta main. Tu toussotes pour couvrir le bruit du carton. Parfait.",
        "Opération manche : réussie. Ton cœur bat à 180.",
        "Tu as profité d'un éternuement général pour faire l'échange. Timing parfait.",
        "Ni vu ni connu. Ta grand-mère, qui t'a appris ce tour, serait fière et horrifiée.",
        "L'as a glissé comme du beurre. Ta vieille carte finit dans ta chaussette.",
    ]

    static let tricheAttrapee = [
        "Un as tombe de ta manche et roule sur la table. Il y en a maintenant cinq. Les robots savent compter jusqu'à cinq.",
        "« C'est quoi, ça ? » Un as dépasse de ta manche. Tu es raccompagné{e} dehors par le col, sans tes jetons.",
        "Tu as glissé l'as… dans le verre de quelqu'un. On te jette dans une flaque, sans tes jetons.",
        "Le requin de la table a vu ton geste. Il sourit. Puis deux armoires à glace t'escortent vers la sortie de secours.",
        "Ta manche fait « clac ». Tout le monde se retourne. Tu dis « c'est mon bracelet ». Personne ne te croit.",
        "Ton as avait un dos bleu. Les cartes de la maison ont un dos rouge. Détail fatal. Dehors !",
        "Un robot hurle « TRICHEUR ! » avec une voix de sirène. Tu finis dans la benne derrière le tripot.",
        "La caméra cachée dans le pot de fleurs a tout filmé. Tes jetons sont confisqués « pour préjudice moral ».",
    ]

    static let quitterGain = [
        "Tu te lèves avec tes gains. Les robots te maudissent sur trois générations.",
        "Tu pars en vainqueur. Le patron te tient la porte, puis la claque très fort.",
        "Tu encaisses et tu files avant que la chance ne remarque son erreur.",
        "Tu quittes la table, les poches lourdes et la tête haute.",
        "« Reviens quand tu veux ! » disent-ils. Ils ne le pensent pas du tout.",
        "Tu sors dans la nuit avec tes billets. Un chat te suit. Il sent l'argent.",
    ]

    static let quitterPerte = [
        "Tu quittes la table allégé{e}. Surtout côté portefeuille.",
        "Tu pars en promettant de revenir te refaire. C'est exactement ce qu'ils espèrent.",
        "Les robots te font un signe d'adieu. Avec ton argent.",
        "Tu sors. L'air frais de la nuit te rappelle que tu as perdu ton loyer.",
        "Bilan : moins d'argent, plus d'expérience. L'expérience ne paie pas le loyer.",
        "Le patron te donne une carte de fidélité. Mauvais signe.",
    ]

    static let quitterNul = [
        "Tu repars avec exactement ce que tu avais. Une soirée blanche, mais pas noire.",
        "Ni gagné, ni perdu. Juste trois heures de ta vie dans une arrière-boutique qui sent le chou.",
        "À l'équilibre. Les robots sont déçus, ils comptaient sur toi.",
    ]

    static let attente = [
        "réfléchit en se grattant le menton…",
        "fixe ses cartes intensément…",
        "fait semblant de calculer…",
        "hésite, les jetons à la main…",
    ]
}

// MARK: - Modèle de la table

enum HoldemAction { case coucher, suivre, relancer }

enum HoldemEtape: Int {
    case preflop, flop, turn, river, abattage

    var nom: String {
        switch self {
        case .preflop: return "Pré-flop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        case .abattage: return "Abattage"
        }
    }
}

/// Une place à la table (le joueur est toujours au siège 0, sans personnalité).
struct HoldemSiege: Identifiable {
    let id = UUID()
    var perso: HoldemPersonnalite?
    var jetons: Int
    var cartes: [CasinoCarte] = []
    /// Mise sur le tour d'enchères en cours.
    var mise: Int = 0
    /// Total misé sur la main.
    var contribution: Int = 0
    var couche: Bool = false
    var aAgi: Bool = false
    var bulle: String? = nil
    var etiquette: String? = nil

    var estJoueur: Bool { perso == nil }
    var nom: String { perso?.nom ?? "Toi" }
    var emoji: String { perso?.emoji ?? "🫵" }
}

struct HoldemLigne: Identifiable {
    let id = UUID()
    let texte: String
}

enum HoldemTriche {
    case impossible
    case reussie(String)
    case attrapee(String)
}

/// Toute la logique du Texas Hold'em à limite fixe contre trois robots.
final class HoldemTable: ObservableObject {
    @Published private(set) var assis = false
    @Published private(set) var sieges: [HoldemSiege] = []
    @Published private(set) var tableau: [CasinoCarte] = []
    @Published private(set) var etape: HoldemEtape = .preflop
    @Published private(set) var enMain = false
    @Published private(set) var tour: Int? = nil
    @Published private(set) var bouton = 0
    @Published private(set) var miseCourante = 0
    @Published private(set) var nbRelances = 0
    @Published private(set) var journal: [HoldemLigne] = []
    @Published private(set) var resultat: String? = nil
    @Published private(set) var resultatGain: Bool? = nil
    @Published private(set) var gagnants: Set<Int> = []
    @Published private(set) var cartesGagnantes: Set<UUID> = []
    @Published private(set) var mainsMontrees = false
    @Published private(set) var descriptions: [Int: String] = [:]
    @Published private(set) var asGlisse = false
    @Published private(set) var expulse = false
    @Published private(set) var investi = 0
    @Published private(set) var regle = false
    @Published private(set) var mainsJouees = 0

    private(set) var caveInitiale = 0
    private(set) var petiteBlinde = 1
    private(set) var grosseBlinde = 2
    /// Accord des textes au féminin.
    var feminin = false

    static let maxRelances = 3

    private var paquet: [CasinoCarte] = []
    /// Incrémenté à chaque changement de main : annule les actions de robots programmées.
    private var generation = 0
    private var dejaVenus: Set<String> = []

    // MARK: Lecture

    var jetonsJoueur: Int { sieges.first?.jetons ?? 0 }
    var pot: Int { sieges.reduce(0) { $0 + $1.contribution } }
    var aSuivreJoueur: Int {
        guard let s = sieges.first else { return 0 }
        return max(0, miseCourante - s.mise)
    }
    var tourJoueur: Bool { enMain && tour == 0 }
    var tailleRelance: Int { etape.rawValue >= HoldemEtape.turn.rawValue ? grosseBlinde * 2 : grosseBlinde }
    /// Montant total que le joueur aurait misé sur ce tour s'il relance.
    var cibleRelance: Int { miseCourante + tailleRelance }

    func peutRelancer(_ i: Int) -> Bool {
        guard enMain, sieges.indices.contains(i) else { return false }
        let s = sieges[i]
        guard !s.couche, nbRelances < Self.maxRelances else { return false }
        guard s.jetons > max(0, miseCourante - s.mise) else { return false }
        // Relancer ne sert à rien si plus personne ne peut payer.
        return sieges.indices.contains { $0 != i && !sieges[$0].couche && sieges[$0].jetons > 0 }
    }

    /// Description de la meilleure main du joueur en ce moment.
    var descriptionMainJoueur: String? {
        guard let s = sieges.first, s.cartes.count == 2 else { return nil }
        if tableau.count >= 3 {
            return PokerEvaluateur.meilleureMain(s.cartes + tableau).valeur.description
        }
        if s.cartes[0].rang == s.cartes[1].rang { return "Paire " + PokerNoms.de(s.cartes[0].rang) }
        let haut = max(s.cartes[0].rang, s.cartes[1].rang)
        let assorties = s.cartes[0].couleur == s.cartes[1].couleur ? ", assorties" : ""
        return "Hauteur \(PokerNoms.singulier(haut))" + assorties
    }

    func g(_ m: String, _ f: String) -> String { feminin ? f : m }

    private func accorder(_ s: String) -> String {
        s.replacingOccurrences(of: "{e}", with: feminin ? "e" : "")
    }

    // MARK: Arrivée et départ

    func asseoir(cave: Int) {
        generation += 1
        caveInitiale = cave
        investi = cave
        petiteBlinde = max(1, Int((Double(cave) / 50).rounded()))
        grosseBlinde = petiteBlinde * 2
        dejaVenus = []
        var places = [HoldemSiege(perso: nil, jetons: cave)]
        var lignes: [HoldemLigne] = [HoldemLigne(texte: "Tu t'assois avec \(Format.argent(cave)) de jetons. Blindes : \(Format.argent(petiteBlinde)) / \(Format.argent(grosseBlinde)).")]
        for _ in 0..<3 {
            let p = nouveauPerso(exclure: Set(places.compactMap { $0.perso?.id }))
            places.append(HoldemSiege(perso: p, jetons: caveRobot()))
            lignes.append(HoldemLigne(texte: "\(p.emoji) \(p.nom) : « \(p.arrivee.randomElement() ?? "…") »"))
        }
        sieges = places
        tableau = []
        enMain = false
        tour = nil
        bouton = Int.random(in: 0..<places.count)
        miseCourante = 0
        nbRelances = 0
        journal = lignes
        resultat = nil
        resultatGain = nil
        gagnants = []
        cartesGagnantes = []
        mainsMontrees = false
        descriptions = [:]
        asGlisse = false
        expulse = false
        regle = false
        mainsJouees = 0
        assis = true
    }

    func recaver(_ montant: Int) {
        guard assis, !regle, montant > 0, !sieges.isEmpty else { return }
        sieges[0].jetons += montant
        investi += montant
        ajouter("💰 Tu recaves \(Format.argent(montant)). Les robots se frottent les mains.")
        resultat = nil
        resultatGain = nil
    }

    /// Quitte la table. Renvoie ce qu'il faut régler (une seule fois), ou nil si c'est déjà fait.
    func quitter() -> (mise: Int, paiement: Int)? {
        guard assis, !regle else { return nil }
        regle = true
        generation += 1
        enMain = false
        tour = nil
        return (investi, max(0, jetonsJoueur))
    }

    /// Retour à l'écran d'accueil après un départ.
    func reinitialiser() {
        generation += 1
        assis = false
        sieges = []
        tableau = []
        journal = []
        enMain = false
        tour = nil
        resultat = nil
        resultatGain = nil
        expulse = false
        regle = false
        investi = 0
    }

    private func nouveauPerso(exclure: Set<String>) -> HoldemPersonnalite {
        var candidats = HoldemCasting.tous.filter { !exclure.contains($0.id) && !dejaVenus.contains($0.id) }
        if candidats.isEmpty {
            candidats = HoldemCasting.tous.filter { !exclure.contains($0.id) }
        }
        let p = candidats.randomElement() ?? HoldemCasting.tous[0]
        dejaVenus.insert(p.id)
        return p
    }

    private func caveRobot() -> Int {
        let base = Double(caveInitiale) * Double.random(in: 0.6...1.8)
        let arrondi = (Int(base) / grosseBlinde) * grosseBlinde
        return max(grosseBlinde * 10, arrondi)
    }

    private func ajouter(_ texte: String) {
        journal.append(HoldemLigne(texte: texte))
        if journal.count > 40 { journal.removeFirst(journal.count - 40) }
    }

    private func nomCourt(_ c: CasinoCarte) -> String { "\(c.nomRang)\(c.couleur.symbole)" }

    // MARK: Déroulement d'une main

    func nouvelleMain() {
        guard assis, !enMain, !expulse, !regle, sieges.count == 4, jetonsJoueur > 0 else { return }
        generation += 1

        // Les robots ruinés laissent leur place.
        for i in 1..<sieges.count where sieges[i].jetons <= 0 {
            let exclus = Set(sieges.compactMap { $0.perso?.id })
            let p = nouveauPerso(exclure: exclus)
            sieges[i] = HoldemSiege(perso: p, jetons: caveRobot())
            sieges[i].bulle = p.arrivee.randomElement()
            ajouter("\(p.emoji) \(p.nom) prend la place libre : « \(sieges[i].bulle ?? "…") »")
        }

        let n = sieges.count
        bouton = (bouton + 1) % n
        paquet = CasinoCarte.paquet()
        tableau = []
        for i in 0..<n {
            sieges[i].cartes = []
            sieges[i].mise = 0
            sieges[i].contribution = 0
            sieges[i].couche = false
            sieges[i].aAgi = false
            sieges[i].etiquette = nil
            if i == 0 { sieges[i].bulle = nil }
        }
        for _ in 0..<2 {
            for k in 1...n {
                let i = (bouton + k) % n
                if let c = paquet.popLast() { sieges[i].cartes.append(c) }
            }
        }
        etape = .preflop
        enMain = true
        resultat = nil
        resultatGain = nil
        gagnants = []
        cartesGagnantes = []
        mainsMontrees = false
        descriptions = [:]
        asGlisse = false
        nbRelances = 0
        mainsJouees += 1

        let pb = (bouton + 1) % n
        let gb = (bouton + 2) % n
        poster(pb, petiteBlinde, nom: "PB")
        poster(gb, grosseBlinde, nom: "GB")
        miseCourante = grosseBlinde
        ajouter("— Main n°\(mainsJouees) — \(sieges[bouton].emoji) \(sieges[bouton].nom) a le bouton.")

        if let premier = prochainAAgir(apres: gb) {
            donnerLaParole(premier)
        } else {
            finDuTour()
        }
    }

    private func poster(_ i: Int, _ montant: Int, nom: String) {
        let m = payer(i, montant)
        sieges[i].etiquette = sieges[i].jetons == 0 ? "\(nom) (tapis)" : "\(nom) \(Format.argent(m))"
    }

    @discardableResult
    private func payer(_ i: Int, _ montant: Int) -> Int {
        let m = min(max(0, montant), sieges[i].jetons)
        sieges[i].jetons -= m
        sieges[i].mise += m
        sieges[i].contribution += m
        return m
    }

    /// Ce siège doit-il encore parler sur ce tour d'enchères ?
    private func doitAgir(_ i: Int) -> Bool {
        let s = sieges[i]
        guard !s.couche, s.jetons > 0 else { return false }
        if s.mise < miseCourante { return true }
        if s.aAgi { return false }
        // Plus personne en face ne peut miser : inutile de parler.
        return sieges.indices.contains { $0 != i && !sieges[$0].couche && sieges[$0].jetons > 0 }
    }

    private func prochainAAgir(apres i: Int) -> Int? {
        let n = sieges.count
        guard n > 0 else { return nil }
        for k in 1...n {
            let j = (i + k) % n
            if doitAgir(j) { return j }
        }
        return nil
    }

    private func donnerLaParole(_ i: Int) {
        tour = i
        guard !sieges[i].estJoueur else { return }
        let gen = generation
        let delai = sieges[0].couche ? 0.45 : Double.random(in: 0.8...1.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + delai) { [weak self] in
            guard let self = self, self.generation == gen, self.enMain, self.tour == i else { return }
            self.executer(self.decisionRobot(i), siege: i)
        }
    }

    /// Action du joueur (siège 0), seulement quand c'est son tour.
    func jouer(_ action: HoldemAction) {
        guard enMain, tour == 0 else { return }
        executer(action, siege: 0)
    }

    private func executer(_ demande: HoldemAction, siege i: Int) {
        guard enMain, sieges.indices.contains(i) else { return }
        var action = demande
        let aSuivre = max(0, miseCourante - sieges[i].mise)
        if action == .relancer && !peutRelancer(i) { action = .suivre }
        // Un robot ne se couche jamais quand il peut parler gratuitement.
        if action == .coucher && aSuivre == 0 && !sieges[i].estJoueur { action = .suivre }

        let perso = sieges[i].perso
        let estJoueur = sieges[i].estJoueur
        let qui = estJoueur ? "Tu" : "\(sieges[i].emoji) \(sieges[i].nom)"
        let verbe: String
        var phrase: String? = nil

        switch action {
        case .coucher:
            sieges[i].couche = true
            sieges[i].etiquette = "Couché"
            verbe = estJoueur ? "te couches" : "se couche"
            phrase = perso?.coucher.randomElement()
        case .suivre:
            if aSuivre == 0 {
                sieges[i].etiquette = "Parole"
                verbe = estJoueur ? "dis parole" : "dit parole"
                phrase = perso?.parole.randomElement()
            } else {
                let m = payer(i, aSuivre)
                if sieges[i].jetons == 0 {
                    sieges[i].etiquette = "Tapis"
                    verbe = (estJoueur ? "fais" : "fait") + " tapis (\(Format.argent(m)))"
                } else {
                    sieges[i].etiquette = "Suit \(Format.argent(m))"
                    verbe = (estJoueur ? "suis" : "suit") + " \(Format.argent(m))"
                }
                phrase = perso?.suivre.randomElement()
            }
        case .relancer:
            payer(i, cibleRelance - sieges[i].mise)
            if sieges[i].mise > miseCourante {
                miseCourante = sieges[i].mise
                nbRelances += 1
                for j in sieges.indices where j != i { sieges[j].aAgi = false }
            }
            if sieges[i].jetons == 0 {
                sieges[i].etiquette = "Tapis"
                verbe = (estJoueur ? "fais" : "fait") + " tapis à \(Format.argent(sieges[i].mise))"
            } else {
                sieges[i].etiquette = "Relance \(Format.argent(sieges[i].mise))"
                verbe = (estJoueur ? "relances" : "relance") + " à \(Format.argent(sieges[i].mise))"
            }
            phrase = perso?.relancer.randomElement()
        }
        sieges[i].aAgi = true
        if !estJoueur { sieges[i].bulle = phrase }
        if let p = phrase {
            ajouter("\(qui) \(verbe). « \(p) »")
        } else {
            ajouter("\(qui) \(verbe).")
        }
        apresAction(i)
    }

    private func apresAction(_ i: Int) {
        let restants = sieges.indices.filter { !sieges[$0].couche }
        if restants.count == 1 {
            terminer(gagnantUnique: restants[0])
            return
        }
        if let j = prochainAAgir(apres: i) {
            donnerLaParole(j)
        } else {
            finDuTour()
        }
    }

    private func finDuTour() {
        tour = nil
        for i in sieges.indices {
            sieges[i].mise = 0
            sieges[i].aAgi = false
        }
        miseCourante = 0
        nbRelances = 0
        let gen = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, self.generation == gen, self.enMain else { return }
            self.rueSuivante()
        }
    }

    private func distribuer(_ nombre: Int) -> [CasinoCarte] {
        _ = paquet.popLast() // carte brûlée
        var cartes: [CasinoCarte] = []
        for _ in 0..<nombre {
            if let c = paquet.popLast() { cartes.append(c) }
        }
        return cartes
    }

    private func rueSuivante() {
        switch etape {
        case .preflop:
            tableau += distribuer(3)
            etape = .flop
        case .flop:
            tableau += distribuer(1)
            etape = .turn
        case .turn:
            tableau += distribuer(1)
            etape = .river
        case .river, .abattage:
            abattage()
            return
        }
        ajouter("🃏 \(etape.nom) : " + tableau.map { nomCourt($0) }.joined(separator: " "))
        for i in sieges.indices where !sieges[i].couche {
            sieges[i].etiquette = sieges[i].jetons == 0 ? "Tapis" : nil
        }
        let actifs = sieges.indices.filter { !sieges[$0].couche && sieges[$0].jetons > 0 }
        if actifs.count >= 2, let premier = prochainAAgir(apres: bouton) {
            donnerLaParole(premier)
        } else {
            // Tout le monde (ou presque) est à tapis : on dévoile la suite.
            finDuTour()
        }
    }

    private func abattage() {
        etape = .abattage
        tour = nil
        var mains: [Int: PokerMeilleureMain] = [:]
        for i in sieges.indices where !sieges[i].couche {
            mains[i] = PokerEvaluateur.meilleureMain(sieges[i].cartes + tableau)
        }
        let valeurs = mains.mapValues { $0.valeur }
        mainsMontrees = true
        descriptions = mains.mapValues { $0.valeur.description }
        if let meilleure = valeurs.values.max() {
            var ids: Set<UUID> = []
            for (_, m) in mains where m.valeur == meilleure {
                for c in m.cartes { ids.insert(c.id) }
            }
            cartesGagnantes = ids
        }
        for i in sieges.indices.sorted(by: { ordre($0) < ordre($1) }) {
            if let d = descriptions[i] {
                ajouter("👀 \(sieges[i].emoji) \(sieges[i].nom) montre " + sieges[i].cartes.map { nomCourt($0) }.joined(separator: " ") + " : \(d).")
            }
        }
        conclure(gains: repartir(valeurs), parAbandon: false)
    }

    private func terminer(gagnantUnique w: Int) {
        tour = nil
        conclure(gains: repartir([w: PokerValeurMain(score: 0)]), parAbandon: true)
    }

    /// Ordre de parole après le bouton (pour départager les jetons indivisibles).
    private func ordre(_ i: Int) -> Int {
        let n = max(1, sieges.count)
        return (i - bouton - 1 + 2 * n) % n
    }

    /// Répartit le pot entre les mains encore en lice, pot principal et pots annexes compris :
    /// un joueur à tapis ne peut gagner que ce qu'il a pu suivre. Le patron prélève 5 %
    /// (plafonnés à 3 grosses blindes) dès qu'il y a eu un flop.
    private func repartir(_ classement: [Int: PokerValeurMain]) -> [Int] {
        let n = sieges.count
        let contributions = sieges.map { $0.contribution }
        let total = contributions.reduce(0, +)
        var gains = [Int](repeating: 0, count: n)
        var commission = tableau.count >= 3 ? min(total * 5 / 100, grosseBlinde * 3) : 0
        let commissionTotale = commission
        let niveaux = Array(Set(classement.keys.map { contributions[$0] })).sorted()
        var precedent = 0
        var derniers: [Int] = []
        for niveau in niveaux where niveau > precedent {
            var portion = 0
            for c in contributions { portion += max(0, min(c, niveau) - precedent) }
            let prise = min(commission, portion)
            portion -= prise
            commission -= prise
            let eligibles = classement.keys.filter { contributions[$0] >= niveau }
            guard let meilleur = eligibles.compactMap({ classement[$0] }).max() else { continue }
            let gagnantsPot = eligibles.filter { classement[$0] == meilleur }.sorted { ordre($0) < ordre($1) }
            partager(portion, entre: gagnantsPot, gains: &gains)
            derniers = gagnantsPot
            precedent = niveau
        }
        // Jetons de joueurs couchés au-delà du plus gros tapis encore en lice.
        var reste = 0
        for c in contributions { reste += max(0, c - precedent) }
        if reste > 0 && !derniers.isEmpty { partager(reste, entre: derniers, gains: &gains) }
        if commissionTotale > 0 {
            ajouter("🧾 Le patron prélève sa commission : \(Format.argent(commissionTotale - commission)).")
        }
        return gains
    }

    private func partager(_ montant: Int, entre gagnants: [Int], gains: inout [Int]) {
        guard !gagnants.isEmpty, montant > 0 else { return }
        let part = montant / gagnants.count
        var reste = montant - part * gagnants.count
        for i in gagnants {
            gains[i] += part
            if reste > 0 {
                gains[i] += 1
                reste -= 1
            }
        }
    }

    private func conclure(gains: [Int], parAbandon: Bool) {
        generation += 1
        tour = nil
        enMain = false
        let n = sieges.count
        let nets = (0..<n).map { gains[$0] - sieges[$0].contribution }
        for i in 0..<n { sieges[i].jetons += gains[i] }
        var vainqueurs = Set((0..<n).filter { nets[$0] > 0 })
        if vainqueurs.isEmpty { vainqueurs = Set((0..<n).filter { gains[$0] > 0 }) }
        gagnants = vainqueurs

        // Le plus gros gagnant (pour les textes).
        let principal = (0..<n).max { gains[$0] < gains[$1] } ?? 0
        let nomPrincipal = principal == 0 ? "Toi" : "\(sieges[principal].emoji) \(sieges[principal].nom)"
        let mainPrincipale = descriptions[principal].map { " avec \($0)" } ?? ""

        for i in vainqueurs where i != 0 {
            sieges[i].bulle = sieges[i].perso?.gagne.randomElement()
        }
        if parAbandon {
            ajouter("🏆 \(nomPrincipal) ramasse \(Format.argent(gains[principal])) : tout le monde s'est couché.")
        } else {
            for i in (0..<n).sorted(by: { ordre($0) < ordre($1) }) where gains[i] > 0 {
                let qui = i == 0 ? "Tu ramasses" : "\(sieges[i].emoji) \(sieges[i].nom) ramasse"
                ajouter("🏆 \(qui) \(Format.argent(gains[i]))" + (descriptions[i].map { " (\($0))" } ?? "") + ".")
            }
        }

        // Textes pour le joueur.
        let netJoueur = nets[0]
        if sieges[0].couche {
            resultat = accorder(HoldemTextes.couche.randomElement() ?? "") + " \(nomPrincipal) ramasse \(Format.argent(gains[principal]))."
            resultatGain = nil
        } else if netJoueur > 0 {
            if parAbandon {
                resultat = "Tu gagnes \(Format.argent(netJoueur)) ! " + accorder(HoldemTextes.abandon.randomElement() ?? "")
            } else {
                let partageGagnant = vainqueurs.count > 1 && vainqueurs.contains(0)
                let debut: String = "Tu gagnes \(Format.argent(netJoueur))" + (descriptions[0].map { " avec \($0)" } ?? "") + " ! "
                let blague = partageGagnant ? (HoldemTextes.partage.randomElement() ?? "") : (HoldemTextes.victoire.randomElement() ?? "")
                resultat = debut + accorder(blague)
            }
            resultatGain = true
        } else if netJoueur == 0 {
            resultat = accorder(HoldemTextes.partage.randomElement() ?? "Partage.")
            resultatGain = nil
        } else {
            var t = "\(nomPrincipal) gagne\(mainPrincipale). "
            if gains[0] > 0 { t += "Tu récupères quand même \(Format.argent(gains[0])). " }
            resultat = t + accorder(HoldemTextes.defaite.randomElement() ?? "")
            resultatGain = false
        }

        // Robots à sec : ils annoncent leur départ.
        for i in 1..<n where sieges[i].jetons <= 0 {
            let adieu = sieges[i].perso?.ruine.randomElement() ?? "…"
            sieges[i].bulle = adieu
            ajouter("💀 \(sieges[i].emoji) \(sieges[i].nom) est à sec : « \(adieu) »")
        }
        if sieges[0].jetons <= 0 {
            let t = accorder(HoldemTextes.ruine.randomElement() ?? "")
            resultat = (resultat.map { $0 + "\n" } ?? "") + t
            resultatGain = false
        }
    }

    // MARK: Intelligence des robots

    private func decisionRobot(_ i: Int) -> HoldemAction {
        let s = sieges[i]
        guard let p = s.perso, s.cartes.count == 2 else { return .suivre }
        let adversaires = max(1, sieges.indices.filter { $0 != i && !sieges[$0].couche }.count)
        let equite: Double
        if tableau.isEmpty {
            // Pré-flop : table de force simple, convertie en chances contre N adversaires.
            let f = PokerEvaluateur.forcePreflop(s.cartes[0], s.cartes[1])
            let nAdv = Double(adversaires)
            let a = 0.73 - 0.08 * (nAdv - 1)
            let b = 1.02 + 0.44 * (nAdv - 1)
            equite = min(0.95, max(0.02, (a + b * f) / (nAdv + 1)))
        } else {
            equite = PokerEvaluateur.equite(main: s.cartes, tableau: tableau, adversaires: adversaires, simulations: 150)
        }
        // 1 = main moyenne à cette table, 2 = deux fois plus de chances que la moyenne…
        let relative = equite * Double(adversaires + 1)
        let force = relative + p.optimisme + Double.random(in: -0.2...0.2) * p.chaos
        let aSuivre = max(0, miseCourante - s.mise)
        let peutRel = peutRelancer(i)

        if peutRel && Double.random(in: 0..<1) < p.bluff / Double(1 + nbRelances) { return .relancer }
        if peutRel && force >= p.seuilRelance + 0.15 * Double(nbRelances) { return .relancer }
        if aSuivre == 0 { return .suivre }
        let cote = Double(aSuivre) / Double(max(1, pot + aSuivre))
        if force >= p.seuilSuivre || equite >= cote * p.prudence { return .suivre }
        // Déjà très engagé dans le pot : il s'accroche.
        if s.contribution > s.jetons && relative > 0.6 { return .suivre }
        return .coucher
    }

    // MARK: Triche

    /// Glisse un as dans la main du joueur (une fois par main). 25 % de chances de se faire prendre.
    func glisserUnAs() -> HoldemTriche {
        guard enMain, !asGlisse, let moi = sieges.first, !moi.couche, moi.cartes.count == 2 else { return .impossible }
        let visibles = Set((moi.cartes + tableau).filter { $0.rang == 14 }.map { $0.couleur })
        let libres = CasinoCouleurCarte.allCases.filter { !visibles.contains($0) }
        guard !libres.isEmpty else { return .impossible }
        asGlisse = true

        if Double.random(in: 0..<1) < 0.25 {
            generation += 1
            enMain = false
            tour = nil
            expulse = true
            sieges[0].jetons = 0
            let t = accorder(HoldemTextes.tricheAttrapee.randomElement() ?? "Dehors !")
            for i in 1..<sieges.count {
                sieges[i].bulle = ["TRICHEUR !", "Dehors !", "On ne fait pas ça chez nous.", "J'appelle mes cousins.", "*te montre la porte du doigt*"].randomElement()
            }
            ajouter("🚨 " + t)
            resultat = t
            resultatGain = false
            return .attrapee(t)
        }

        // De préférence un as encore dans le paquet (pour éviter les doublons).
        let dansPaquet = libres.filter { c in paquet.contains { $0.rang == 14 && $0.couleur == c } }
        let couleur = (dansPaquet.isEmpty ? libres : dansPaquet).randomElement() ?? libres[0]
        paquet.removeAll { $0.rang == 14 && $0.couleur == couleur }
        let indice = moi.cartes[0].rang <= moi.cartes[1].rang ? 0 : 1
        let ancienne = moi.cartes[indice]
        sieges[0].cartes[indice] = CasinoCarte(rang: 14, couleur: couleur)
        let t = accorder(HoldemTextes.tricheReussie.randomElement() ?? "") + " (\(ancienne.nomComplet) → As de \(couleur.rawValue))"
        ajouter("🤫 Tu as glissé un as dans ton jeu.")
        return .reussie(t)
    }
}

// MARK: - Vue

struct HoldemVue: View {
    let lieu: CasinoLieu
    @EnvironmentObject var engine: GameEngine
    @ObservedObject private var stockage = CasinoStockage.shared
    @StateObject private var table = HoldemTable()

    @State private var cave = 0
    @State private var recave = 0
    @State private var messageFin: String? = nil
    @State private var messageFinGain: Bool? = nil
    @State private var messageTriche: String? = nil
    @State private var expulseCetteVisite = false

    private var argent: Int { engine.joueur?.argent ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if table.assis && table.sieges.count == 4 {
                    tableEnCours
                } else {
                    accueil
                }
            }
            .padding()
        }
        .onDisappear { encaisser() }
    }

    // MARK: Accueil

    private var accueil: some View {
        VStack(spacing: 14) {
            Text("🃏 Poker à l'Arrière-Boutique")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(CasinoStyle.or)
            Text("Texas Hold'em à limite fixe. Trois habitués t'attendent autour d'une table en formica. Le patron prend 5 % de chaque pot qui voit un flop. On ne pose pas de questions.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            if let m = messageFin {
                CasinoBandeau(texte: m, gain: messageFinGain)
            }
            if expulseCetteVisite {
                CasinoBandeau(texte: "Le videur a ta photo, encore humide, scotchée sur la porte. Plus de poker pour toi ce soir.", gain: false)
            } else {
                CasinoSelecteurMise(mise: $cave, lieu: lieu, argent: argent, titre: "Cave (tes jetons pour la table)")
                Text("Blindes : \(Format.argent(blindePour(cave))) / \(Format.argent(blindePour(cave) * 2)) · relances fixes")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                CasinoBouton(titre: "S'asseoir à la table", actif: CasinoSelecteurMise.valide(cave, lieu: lieu, argent: argent)) {
                    sAsseoir()
                }
            }
        }
    }

    private func blindePour(_ c: Int) -> Int { max(1, Int((Double(c) / 50).rounded())) }

    private func sAsseoir() {
        guard !expulseCetteVisite, CasinoSelecteurMise.valide(cave, lieu: lieu, argent: argent) else { return }
        guard engine.casinoMiser(cave, jeu: .holdem) else { return }
        table.feminin = engine.joueur?.genre == .femme
        table.asseoir(cave: cave)
        messageFin = nil
        messageFinGain = nil
        messageTriche = nil
        table.nouvelleMain()
    }

    // MARK: Table

    private var tableEnCours: some View {
        VStack(spacing: 12) {
            enTete
            HStack(alignment: .top, spacing: 6) {
                ForEach(1..<4, id: \.self) { i in
                    HoldemSiegeVue(siege: table.sieges[i],
                                   actif: table.tour == i,
                                   montrer: table.mainsMontrees,
                                   gagnant: !table.enMain && table.gagnants.contains(i),
                                   bouton: table.bouton == i,
                                   description: table.descriptions[i],
                                   cartesGagnantes: table.cartesGagnantes)
                }
            }
            HoldemTableauVue(cartes: table.tableau,
                             pot: table.enMain ? table.pot : 0,
                             etape: table.etape,
                             enMain: table.enMain,
                             cartesGagnantes: table.cartesGagnantes)
            if let r = table.resultat {
                CasinoBandeau(texte: r, gain: table.resultatGain)
            }
            HoldemZoneJoueur(siege: table.sieges[0],
                             actif: table.tour == 0,
                             bouton: table.bouton == 0,
                             description: table.descriptionMainJoueur,
                             gagnant: !table.enMain && table.gagnants.contains(0),
                             cartesGagnantes: table.cartesGagnantes)
            commandes
            if let t = messageTriche {
                CasinoBandeau(texte: t, gain: nil)
            }
            boutonTriche
            journalVue
            CasinoBouton(titre: "Quitter la table (encaisser \(Format.argent(table.jetonsJoueur)))", couleur: Color.black.opacity(0.55)) {
                quitterLaTable()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: table.tableau.count)
        .animation(.easeInOut(duration: 0.3), value: table.enMain)
    }

    private var enTete: some View {
        HStack {
            Text("Main n°\(table.mainsJouees) · \(table.etape.nom)")
            Spacer()
            Text("Blindes \(Format.argent(table.petiteBlinde))/\(Format.argent(table.grosseBlinde))")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.75))
    }

    @ViewBuilder
    private var commandes: some View {
        if table.enMain {
            if table.tourJoueur {
                boutonsAction
            } else if table.sieges[0].couche {
                Text("Tu regardes la fin de la main en grignotant des cacahuètes.")
                    .font(.footnote.italic())
                    .foregroundStyle(.white.opacity(0.7))
            } else if let t = table.tour, table.sieges.indices.contains(t) {
                Text("\(table.sieges[t].emoji) \(table.sieges[t].nom) \(HoldemTextes.attente[t % HoldemTextes.attente.count])")
                    .font(.footnote.italic())
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("Le donneur distribue…")
                    .font(.footnote.italic())
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else if table.jetonsJoueur > 0 {
            CasinoBouton(titre: "Main suivante") { messageTriche = nil; table.nouvelleMain() }
        } else {
            recavePanneau
        }
    }

    private var boutonsAction: some View {
        let aSuivre = table.aSuivreJoueur
        let jetons = table.jetonsJoueur
        let texteSuivre: String
        if aSuivre == 0 {
            texteSuivre = "Parole"
        } else if aSuivre >= jetons {
            texteSuivre = "Tapis\n\(Format.argent(jetons))"
        } else {
            texteSuivre = "Suivre\n\(Format.argent(aSuivre))"
        }
        let cible = min(table.cibleRelance, table.sieges[0].mise + jetons)
        return HStack(spacing: 8) {
            HoldemBoutonAction(titre: "Se coucher", couleur: CasinoStyle.rouge, actif: true) { table.jouer(.coucher) }
            HoldemBoutonAction(titre: texteSuivre, couleur: Color(red: 0.15, green: 0.4, blue: 0.75), actif: true) { table.jouer(.suivre) }
            HoldemBoutonAction(titre: "Relancer\nà \(Format.argent(cible))", couleur: CasinoStyle.or, actif: table.peutRelancer(0)) { table.jouer(.relancer) }
        }
    }

    private var recavePanneau: some View {
        VStack(spacing: 10) {
            CasinoSelecteurMise(mise: $recave, lieu: lieu, argent: argent, titre: "Recave")
            CasinoBouton(titre: "Recaver et rejouer", actif: CasinoSelecteurMise.valide(recave, lieu: lieu, argent: argent)) {
                guard CasinoSelecteurMise.valide(recave, lieu: lieu, argent: argent),
                      engine.casinoMiser(recave, jeu: .holdem) else { return }
                table.recaver(recave)
                messageTriche = nil
                table.nouvelleMain()
            }
        }
    }

    @ViewBuilder
    private var boutonTriche: some View {
        if table.enMain && !table.asGlisse && !table.sieges[0].couche {
            Button {
                glisserUnAs()
            } label: {
                Label("Glisser un as dans sa manche", systemImage: "hand.raised.fingers.spread")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple.opacity(0.55), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }

    private var journalVue: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ce qui se dit à la table").font(.caption.weight(.bold)).foregroundStyle(CasinoStyle.or)
            ForEach(Array(table.journal.suffix(8).reversed())) { ligne in
                Text(ligne.texte)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Actions

    private func glisserUnAs() {
        switch table.glisserUnAs() {
        case .impossible:
            messageTriche = "Tu as déjà tous les as qu'il te faut. Ta manche est vide de toute façon."
        case .reussie(let t):
            messageTriche = "🤫 " + t
        case .attrapee(let t):
            let ban = engine.casinoSoupcon(40, raison: "triche au poker")
            expulseCetteVisite = true
            if let r = table.quitter() {
                engine.casinoRegler(mise: r.mise, paiement: 0, jeu: .holdem, detail: "Poker à l'Arrière-Boutique")
            }
            table.reinitialiser()
            messageFin = "🚨 " + t + (ban.map { "\n" + $0 } ?? "")
            messageFinGain = false
            messageTriche = nil
        }
    }

    private func quitterLaTable() {
        guard let r = table.quitter() else { return }
        engine.casinoRegler(mise: r.mise, paiement: r.paiement, jeu: .holdem, detail: "Poker à l'Arrière-Boutique")
        let net = r.paiement - r.mise
        let accord: (String) -> String = { s in
            s.replacingOccurrences(of: "{e}", with: engine.joueur?.genre == .femme ? "e" : "")
        }
        if net > 0 {
            messageFin = "Tu encaisses \(Format.argent(r.paiement)) (+\(Format.argent(net))). " + accord(HoldemTextes.quitterGain.randomElement() ?? "")
            messageFinGain = true
        } else if net < 0 {
            messageFin = "Tu repars avec \(Format.argent(r.paiement)) (−\(Format.argent(-net))). " + accord(HoldemTextes.quitterPerte.randomElement() ?? "")
            messageFinGain = false
        } else {
            messageFin = accord(HoldemTextes.quitterNul.randomElement() ?? "")
            messageFinGain = nil
        }
        messageTriche = nil
        table.reinitialiser()
    }

    /// Si le joueur s'en va sans passer par « Quitter », on encaisse quand même (une seule fois).
    private func encaisser() {
        guard let r = table.quitter() else { return }
        engine.casinoRegler(mise: r.mise, paiement: r.paiement, jeu: .holdem, detail: "Poker à l'Arrière-Boutique")
    }
}

// MARK: - Sous-vues

/// Bouton d'action compact (texte sur deux lignes possible).
struct HoldemBoutonAction: View {
    let titre: String
    let couleur: Color
    let actif: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titre)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 6)
                .background(actif ? couleur : Color.gray.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(couleur == CasinoStyle.or && actif ? CasinoStyle.nuit : .white)
        }
        .disabled(!actif)
    }
}

/// Un adversaire-robot autour de la table.
struct HoldemSiegeVue: View {
    let siege: HoldemSiege
    let actif: Bool
    let montrer: Bool
    let gagnant: Bool
    let bouton: Bool
    let description: String?
    let cartesGagnantes: Set<UUID>

    var body: some View {
        VStack(spacing: 4) {
            Text(siege.emoji).font(.system(size: 26))
            Text(siege.nom)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(Format.argent(siege.jetons))
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(CasinoStyle.or)
            cartes
            if let e = siege.etiquette {
                Text(e)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .foregroundStyle(.white)
            }
            if let d = description, montrer {
                Text(d)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(gagnant ? CasinoStyle.or : .white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            Text(siege.bulle ?? " ")
                .font(.system(size: 10).italic())
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .frame(minHeight: 28, alignment: .top)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(fond, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(actif ? CasinoStyle.or : (gagnant ? Color.green : Color.clear), lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if bouton { HoldemPastilleBouton().padding(4) }
        }
    }

    private var fond: Color { Color.black.opacity(siege.couche ? 0.15 : 0.3) }

    private var cartes: some View {
        HStack(spacing: -10) {
            ForEach(siege.cartes) { c in
                CasinoCarteVue(carte: c,
                               cachee: !montrer || siege.couche,
                               largeur: 30,
                               selectionnee: montrer && !siege.couche && cartesGagnantes.contains(c.id))
            }
        }
        .opacity(siege.couche ? 0.35 : 1)
        .frame(height: 50)
    }
}

/// La pastille « D » du donneur.
struct HoldemPastilleBouton: View {
    var body: some View {
        Text("D")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .frame(width: 20, height: 20)
            .background(Color.white, in: Circle())
            .foregroundStyle(Color.black)
    }
}

/// Les cartes communes et le pot.
struct HoldemTableauVue: View {
    let cartes: [CasinoCarte]
    let pot: Int
    let etape: HoldemEtape
    let enMain: Bool
    let cartesGagnantes: Set<UUID>

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    if i < cartes.count {
                        CasinoCarteVue(carte: cartes[i], largeur: 52,
                                       selectionnee: !enMain && cartesGagnantes.contains(cartes[i].id))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(width: 52, height: 52 * 1.42)
                    }
                }
            }
            .padding(.top, 10)
            HStack(spacing: 6) {
                Image(systemName: "circle.hexagongrid.fill")
                Text(enMain ? "Pot : \(Format.argent(pot))" : "Entre deux mains")
                    .monospacedDigit()
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(CasinoStyle.or)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            Capsule().fill(CasinoStyle.tapisFonce.opacity(0.8))
                .overlay(Capsule().strokeBorder(Color(red: 0.45, green: 0.28, blue: 0.12), lineWidth: 6))
        )
    }
}

/// La place du joueur : ses cartes, ses jetons, sa main.
struct HoldemZoneJoueur: View {
    let siege: HoldemSiege
    let actif: Bool
    let bouton: Bool
    let description: String?
    let gagnant: Bool
    let cartesGagnantes: Set<UUID>

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: -12) {
                ForEach(siege.cartes) { c in
                    CasinoCarteVue(carte: c, largeur: 64,
                                   selectionnee: cartesGagnantes.contains(c.id))
                }
            }
            .opacity(siege.couche ? 0.4 : 1)
            .frame(minWidth: 120, minHeight: 96)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Tes jetons").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                    if bouton { HoldemPastilleBouton() }
                }
                Text(Format.argent(siege.jetons))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(CasinoStyle.or)
                if let d = description {
                    Text(siege.couche ? "Couché (\(d))" : d)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(gagnant ? CasinoStyle.or : .white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                if let e = siege.etiquette {
                    Text(e)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.45), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(actif ? CasinoStyle.or : (gagnant ? Color.green : Color.clear), lineWidth: 2)
        )
    }
}

import Foundation

// Module Téléphone et réseaux sociaux. Voir docs/PHONE.md.
// Tous les types sont préfixés « Phone » pour éviter les collisions avec les autres modules.

// MARK: - Applis

/// Les applis inventées du téléphone (noms parodiques).
/// Les identifiants d'origine (pozz, tremousse, ronchon) restent pour les sauvegardes et les données.
enum PhoneApp: String, Codable, CaseIterable, Identifiable {
    case pozz, tremousse, ronchon, pecho, voustube, onlyfesses

    var id: String { rawValue }

    /// Les applis où l'on publie (Pécho est une appli de rencontre).
    static let reseaux: [PhoneApp] = [.pozz, .tremousse, .ronchon, .voustube, .onlyfesses]

    /// Les réseaux publics : leurs abonnés comptent dans le total (OnlyFesses a des abonnés payants, à part).
    static let publics: [PhoneApp] = [.pozz, .tremousse, .ronchon, .voustube]

    var nom: String {
        switch self {
        case .pozz: return "Instaglam"
        case .tremousse: return "TikTac"
        case .ronchon: return "Twitteur"
        case .pecho: return "Pécho"
        case .voustube: return "VousTube"
        case .onlyfesses: return "OnlyFesses"
        }
    }

    var icone: String {
        switch self {
        case .pozz: return "camera.aperture"
        case .tremousse: return "music.note"
        case .ronchon: return "bird.fill"
        case .pecho: return "heart.circle.fill"
        case .voustube: return "play.rectangle.fill"
        case .onlyfesses: return "lock.heart.fill"
        }
    }

    var ageMin: Int {
        switch self {
        case .pozz, .tremousse, .voustube: return 13
        case .ronchon: return 15
        case .pecho, .onlyfesses: return 18
        }
    }

    var slogan: String {
        switch self {
        case .pozz: return "Ta vie, en mieux éclairée."
        case .tremousse: return "15 secondes de gloire, renouvelables."
        case .ronchon: return "Dis ce que tu penses. Tout le monde s'en fiche, mais fort."
        case .pecho: return "L'amour à portée de pouce."
        case .voustube: return "Diffuse-toi toi-même."
        case .onlyfesses: return "Le contenu que ta grand-mère ne doit jamais voir."
        }
    }

    /// Ce qui fait marcher les posts sur cette appli (affiché au joueur).
    var conseil: String {
        switch self {
        case .pozz: return "Ici, l'apparence fait tout."
        case .tremousse: return "Ici, il faut de l'énergie (bonheur)."
        case .ronchon: return "Ici, il faut de l'esprit (intelligence)."
        case .pecho: return "Ici, l'apparence aide. Beaucoup."
        case .voustube: return "Ici, il faut du fond (intelligence) et du bon matériel."
        case .onlyfesses: return "Ici, l'apparence paie. Mais tout finit par se savoir."
        }
    }

    /// Mot pour les abonnés de cette appli.
    var motAbonnes: String { self == .onlyfesses ? "abonnés payants" : "abonnés" }
}

// MARK: - Données JSON (Resources/Data/Phone)

/// Un type de publication (Phone/Posts).
struct PhonePostModele: Decodable, Identifiable {
    var id: String
    var app: String
    var titre: String
    var icone: String
    var minAge: Int?
    var maxAge: Int?
    /// looks, smarts, happiness, karma ou none.
    var stat: String
    var risque: Double
    var viralite: Double
    var cout: Int?
    var conditions: ConditionsEvenement?
    /// Paliers : flop, moyen, succes, buzz, badbuzz.
    var textes: [String: [String]]
}

/// Un commentaire affiché sous un post (Phone/Commentaires).
struct PhoneCommentaireModele: Decodable, Identifiable {
    var id: String
    /// fan, hater, bizarre, famille, bot.
    var type: String
    var app: String?
    var minAbonnes: Int?
    var texte: String
}

/// Effets propres au téléphone, lus dans le même objet `effects` que les effets du moteur.
struct PhoneEffetsReseau: Decodable {
    var followers: Int?
    var followersPct: Double?
}

struct PhoneIssue: Decodable {
    var chance: Double?
    var text: String
    var effects: Effets?
    var reseau: PhoneEffetsReseau?

    enum CodingKeys: String, CodingKey { case chance, text, effects }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chance = try c.decodeIfPresent(Double.self, forKey: .chance)
        text = try c.decode(String.self, forKey: .text)
        effects = try c.decodeIfPresent(Effets.self, forKey: .effects)
        reseau = try c.decodeIfPresent(PhoneEffetsReseau.self, forKey: .effects)
    }
}

struct PhoneChoix: Decodable {
    var label: String
    var outcomes: [PhoneIssue]
}

/// Un message de la messagerie (Phone/Messages).
struct PhoneMessageModele: Decodable, Identifiable {
    var id: String
    /// bizarre, arnaque, famille, hater, fan, crush, ami, pro.
    var categorie: String
    var expediteur: String
    var app: String?
    var minAge: Int?
    var maxAge: Int?
    var weight: Double?
    var unique: Bool?
    var minAbonnes: Int?
    var conditions: ConditionsEvenement?
    var text: String
    var choices: [PhoneChoix]
}

/// Une marque qui propose un contrat (Phone/Sponsors).
struct PhoneSponsor: Decodable, Identifiable {
    var id: String
    var marque: String
    var produit: String
    var app: String?
    var minAbonnes: Int
    var minAge: Int?
    /// Euros par abonné et par an.
    var tarif: Double
    var minPaiement: Int
    /// Chance de scandale par an (0 à 1).
    var louche: Double
    var offre: String
    var accepte: String
    var scandale: String
}

/// Une bio de profil sur Pécho (Phone/Profils).
struct PhoneProfilModele: Decodable, Identifiable {
    var id: String
    /// any, male, female : genre de la personne du profil.
    var genre: String
    var minAge: Int?
    var maxAge: Int?
    var bio: String
}

/// Un déroulé de rendez-vous Pécho (Phone/RendezVous).
struct PhoneRendezVousModele: Decodable, Identifiable {
    var id: String
    /// lapin, catastrophe, bof, bien, coupdefoudre.
    var issue: String
    var texte: String
}

enum PhoneBibliotheque {
    static let posts = DonneesJSON.chargerTableaux(dossier: "Phone/Posts", type: PhonePostModele.self)
    static let commentaires = DonneesJSON.chargerTableaux(dossier: "Phone/Commentaires", type: PhoneCommentaireModele.self)
    static let messages = DonneesJSON.chargerTableaux(dossier: "Phone/Messages", type: PhoneMessageModele.self)
    static let sponsors = DonneesJSON.chargerTableaux(dossier: "Phone/Sponsors", type: PhoneSponsor.self)
    static let profils = DonneesJSON.chargerTableaux(dossier: "Phone/Profils", type: PhoneProfilModele.self)
    static let rendezVous = DonneesJSON.chargerTableaux(dossier: "Phone/RendezVous", type: PhoneRendezVousModele.self)

    static func sponsor(_ id: String) -> PhoneSponsor? { sponsors.first { $0.id == id } }
    static func message(_ id: String) -> PhoneMessageModele? { messages.first { $0.id == id } }
}

// MARK: - État sauvegardé (champ `telephone` de Joueur)

/// Un compte sur une appli.
struct PhoneCompte: Codable, Equatable {
    var abonnes: Int = 0
    var posts: Int = 0
    var certifie: Bool = false
    /// Abonnés achetés : ils peuvent être découverts (bad buzz).
    var fauxAbonnes: Int = 0
}

/// Une publication passée, affichée dans le fil de l'appli.
struct PhonePublication: Codable, Equatable, Identifiable {
    var id = UUID()
    var app: PhoneApp
    var titre: String
    var icone: String
    /// flop, moyen, succes, buzz, badbuzz.
    var palier: String
    /// Variation d'abonnés (négative en cas de perte).
    var gain: Int
    var likes: Int
    var texte: String
    var commentaires: [String]
    var age: Int
}

/// Un message reçu.
struct PhoneMessage: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Id du modèle (Phone/Messages), nil pour un message écrit par le code.
    var modeleId: String?
    /// Id de la marque si c'est une offre de sponsor.
    var sponsorId: String?
    var expediteur: String
    var categorie: String
    var texte: String
    var age: Int
    var lu: Bool = false
    /// Choix fait et résultat (nil tant qu'on n'a pas répondu).
    var choixFait: String?
    var reponse: String?
}

/// Un contrat de sponsor en cours.
struct PhoneContrat: Codable, Equatable, Identifiable {
    var id: String { sponsorId }
    var sponsorId: String
    var marque: String
    var depuisAge: Int
    /// Multiplicateur obtenu en négociant.
    var bonus: Double = 1
}

/// Une personne avec qui on a matché sur Pécho.
struct PhoneMatch: Codable, Equatable, Identifiable {
    var id = UUID()
    var prenom: String
    var genre: Genre
    var age: Int
    var bio: String
    var ageDuMatch: Int
}

/// Tout l'état du téléphone, sauvegardé avec le joueur.
struct PhoneEtat: Codable, Equatable {
    var aTelephone: Bool = false
    /// Comptes par appli (clé : rawValue de PhoneApp).
    var comptes: [String: PhoneCompte] = [:]
    var publications: [PhonePublication] = []
    var messages: [PhoneMessage] = []
    var contrats: [PhoneContrat] = []
    var matchs: [PhoneMatch] = []
    /// Qui on cherche sur Pécho : any, male, female.
    var recherche: String = "any"
    /// Messages et sponsors uniques déjà reçus.
    var messagesVus: [String] = []
    var sponsorsVus: [String] = []
    /// Posts publiés cette année, par appli.
    var postsAnnee: [String: Int] = [:]
    /// Actions limitées faites cette année (live, détox, swipe…).
    var actionsAnnee: [String] = []
    /// Années restantes pendant lesquelles le bad buzz « colle » (tag bad_buzz).
    var badBuzzRestant: Int = 0
    var detoxCetteAnnee: Bool = false
    /// Nombre de paliers d'abonnés déjà annoncés.
    var paliersAnnonces: Int = 0
    /// Meilleur total d'abonnés atteint dans la vie.
    var recordAbonnes: Int = 0
    /// VousTube : niveau du matériel (0 à 3).
    var materielTube: Int = 0
    /// OnlyFesses : prix de l'abonnement mensuel en euros, compte fermé, qui l'a découvert.
    var prixOnly: Int = 10
    var onlyFerme: Bool = false
    var onlyDecouvertPar: [String] = []

    enum CodingKeys: String, CodingKey {
        case aTelephone, comptes, publications, messages, contrats, matchs, recherche
        case messagesVus, sponsorsVus, postsAnnee, actionsAnnee, badBuzzRestant, detoxCetteAnnee
        case paliersAnnonces, recordAbonnes, materielTube, prixOnly, onlyFerme, onlyDecouvertPar
    }

    func compte(_ app: PhoneApp) -> PhoneCompte { comptes[app.rawValue] ?? PhoneCompte() }

    var abonnesTotal: Int { PhoneApp.publics.reduce(0) { $0 + compte($1).abonnes } }

    /// Le compte public qui a le plus d'abonnés (Instaglam par défaut).
    var appPrincipale: PhoneApp {
        PhoneApp.publics.max { compte($0).abonnes < compte($1).abonnes } ?? .pozz
    }

    /// Compte OnlyFesses ouvert (au moins une publication) et pas fermé.
    var onlyActif: Bool { !onlyFerme && compte(.onlyfesses).posts > 0 }

    var nonLus: Int { messages.filter { !$0.lu }.count }

    func nombreActions(_ cle: String) -> Int { actionsAnnee.filter { $0 == cle }.count }
}

extension PhoneEtat {
    /// Lecture tolérante : un champ ajouté plus tard ne casse pas les anciennes sauvegardes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        aTelephone = try c.decodeIfPresent(Bool.self, forKey: .aTelephone) ?? false
        comptes = try c.decodeIfPresent([String: PhoneCompte].self, forKey: .comptes) ?? [:]
        publications = try c.decodeIfPresent([PhonePublication].self, forKey: .publications) ?? []
        messages = try c.decodeIfPresent([PhoneMessage].self, forKey: .messages) ?? []
        contrats = try c.decodeIfPresent([PhoneContrat].self, forKey: .contrats) ?? []
        matchs = try c.decodeIfPresent([PhoneMatch].self, forKey: .matchs) ?? []
        recherche = try c.decodeIfPresent(String.self, forKey: .recherche) ?? "any"
        messagesVus = try c.decodeIfPresent([String].self, forKey: .messagesVus) ?? []
        sponsorsVus = try c.decodeIfPresent([String].self, forKey: .sponsorsVus) ?? []
        postsAnnee = try c.decodeIfPresent([String: Int].self, forKey: .postsAnnee) ?? [:]
        actionsAnnee = try c.decodeIfPresent([String].self, forKey: .actionsAnnee) ?? []
        badBuzzRestant = try c.decodeIfPresent(Int.self, forKey: .badBuzzRestant) ?? 0
        detoxCetteAnnee = try c.decodeIfPresent(Bool.self, forKey: .detoxCetteAnnee) ?? false
        paliersAnnonces = try c.decodeIfPresent(Int.self, forKey: .paliersAnnonces) ?? 0
        recordAbonnes = try c.decodeIfPresent(Int.self, forKey: .recordAbonnes) ?? 0
        materielTube = try c.decodeIfPresent(Int.self, forKey: .materielTube) ?? 0
        prixOnly = try c.decodeIfPresent(Int.self, forKey: .prixOnly) ?? 10
        onlyFerme = try c.decodeIfPresent(Bool.self, forKey: .onlyFerme) ?? false
        onlyDecouvertPar = try c.decodeIfPresent([String].self, forKey: .onlyDecouvertPar) ?? []
    }
}

/// Un profil affiché sur Pécho (pas sauvegardé).
struct PhoneProfil: Identifiable, Equatable {
    let id = UUID()
    let prenom: String
    let genre: Genre
    let age: Int
    let bio: String
}

// MARK: - Format

enum PhoneFormat {
    /// 12 400, 1 250 000…
    static func nombre(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// Version courte : 950, 12,4 k, 3,2 M.
    static func court(_ n: Int) -> String {
        let a = abs(n)
        let signe = n < 0 ? "-" : ""
        if a < 10_000 { return signe + nombre(a) }
        if a < 1_000_000 { return signe + decimale(Double(a) / 1_000) + " k" }
        if a < 1_000_000_000 { return signe + decimale(Double(a) / 1_000_000) + " M" }
        return signe + decimale(Double(a) / 1_000_000_000) + " Md"
    }

    private static func decimale(_ x: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.decimalSeparator = ","
        f.groupingSeparator = " "
        f.maximumFractionDigits = x < 100 ? 1 : 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: x)) ?? "\(Int(x))"
    }
}

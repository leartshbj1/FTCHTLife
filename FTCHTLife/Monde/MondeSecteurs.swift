import Foundation

/// Secteurs d'activité utilisés par les modificateurs de salaires du journal du monde.
enum MondeSecteurs {
    /// Traduit les secteurs du module Métiers (CareerJob.sector) vers ceux du journal.
    static let alias: [String: String] = [
        "beaute_mode": "beaute",
        "art_culture": "arts",
        "spectacle": "arts",
        "hotellerie_tourisme": "tourisme",
        "ingenierie": "industrie",
        "armee": "securite",
        "environnement": "science",
    ]

    static func normaliser(_ secteur: String) -> String {
        alias[secteur] ?? secteur
    }

    /// Secteur des métiers de base du moteur (Donnees.metiers).
    static let metiersMoteur: [String: String] = [
        "plongeur": "restauration", "caissier": "commerce", "livreur": "transport", "agent_entretien": "administration",
        "mannequin": "beaute", "macon": "batiment", "chauffeur": "transport", "coiffeur": "beaute",
        "vendeur": "commerce", "policier": "securite", "secretaire": "administration", "influenceur": "medias",
        "agent_immo": "immobilier", "dev": "tech", "comptable": "finance", "marketing": "commerce",
        "graphiste": "arts", "chercheur": "science", "prof": "education", "avocat": "droit", "juge": "droit",
        "medecin": "sante", "chirurgien": "sante",
    ]

    /// Mots du titre ou de l'id qui trahissent un secteur, pour les métiers inconnus.
    static let indices: [(mot: String, secteur: String)] = [
        ("cuisin", "restauration"), ("serveu", "restauration"), ("boulang", "restauration"),
        ("pizza", "restauration"), ("barman", "restauration"), ("kebab", "restauration"),
        ("vend", "commerce"), ("caiss", "commerce"), ("commerc", "commerce"),
        ("chauffeur", "transport"), ("pilote", "transport"), ("livr", "transport"), ("taxi", "transport"),
        ("maçon", "batiment"), ("macon", "batiment"), ("plombier", "batiment"), ("électricien", "batiment"),
        ("electricien", "batiment"), ("charpent", "batiment"), ("architecte", "batiment"),
        ("coiff", "beaute"), ("mannequin", "beaute"), ("esthéti", "beaute"), ("styliste", "beaute"),
        ("polic", "securite"), ("gendarm", "securite"), ("pompier", "securite"), ("militaire", "securite"), ("vigile", "securite"),
        ("journal", "medias"), ("influen", "medias"), ("présentat", "medias"), ("youtub", "medias"),
        ("immobili", "immobilier"),
        ("dévelop", "tech"), ("develop", "tech"), ("informati", "tech"), ("ingénieur", "industrie"), ("ingenieur", "industrie"),
        ("banqu", "finance"), ("trader", "finance"), ("compta", "finance"), ("financ", "finance"),
        ("artist", "arts"), ("musicien", "arts"), ("acteur", "arts"), ("actrice", "arts"), ("peintre", "arts"), ("graphist", "arts"),
        ("cherch", "science"), ("scientif", "science"), ("biolog", "science"), ("chimiste", "science"),
        ("prof", "education"), ("enseign", "education"), ("institut", "education"),
        ("avocat", "droit"), ("juge", "droit"), ("notaire", "droit"),
        ("médecin", "sante"), ("medecin", "sante"), ("infirm", "sante"), ("chirurg", "sante"), ("dentiste", "sante"), ("pharmac", "sante"),
        ("footbal", "sport"), ("sportif", "sport"), ("athlète", "sport"), ("coach", "sport"),
        ("maire", "politique"), ("député", "politique"), ("ministre", "politique"), ("président", "politique"),
        ("agricult", "agriculture"), ("fermier", "agriculture"), ("vigner", "agriculture"),
        ("hôtel", "tourisme"), ("hotel", "tourisme"), ("guide", "tourisme"),
        ("usine", "industrie"), ("ouvrier", "industrie"),
    ]

    /// Devine le secteur d'un métier à partir de son id et de son titre (nil si inconnu : seul « tout » s'applique).
    static func secteur(metierId: String, titre: String) -> String? {
        if let s = metiersMoteur[metierId] { return s }
        let texte = (metierId + " " + titre).lowercased()
        return indices.first { texte.contains($0.mot) }?.secteur
    }
}

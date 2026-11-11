import Foundation

// Idée 59 : « Parce que tu as fait X il y a N ans ».
// Chaque suite programmée par les Répercussions garde le souvenir de ce qui l'a causée (un choix dans une carte,
// ou un signal de module comme « mariage »). Quand la suite arrive, la carte l'affiche en bandeau et le journal le rappelle.
// Les drapeaux (fume, endette…) gardent aussi leur origine, pour les états durables.
// Voir docs/SCENES.md.

/// Ce qui a causé une suite ou un drapeau.
struct Souvenir: Codable, Equatable {
    /// Âge du joueur au moment des faits.
    var age: Int
    /// Proposition au passé qui suit « Parce que » : « tu as choisi « Accepter » », « tu t'es marié{e} ».
    /// `{e}` est remplacé à l'affichage.
    var quoi: String
    /// Extrait de la carte d'origine (« Ton voisin te propose… »), si le souvenir vient d'un choix.
    var contexte: String?
    /// Vrai pour un état qui dure (« tu fumes ») : la phrase devient « … depuis N ans ».
    var etat: Bool?

    /// « il y a 6 ans », « l'an dernier », « cette année ».
    static func quand(depuis age: Int, ageActuel: Int) -> String {
        let n = max(0, ageActuel - age)
        switch n {
        case 0: return "cette année"
        case 1: return "l'an dernier"
        default: return "il y a \(n) ans"
        }
    }

    /// « Parce que tu as choisi « Accepter » il y a 6 ans, à 14 ans. »
    func phrase(ageActuel: Int) -> String {
        let n = max(0, ageActuel - age)
        if etat == true {
            if n <= 0 { return "Parce que \(quoi) depuis cette année." }
            return "Parce que \(quoi) depuis \(n == 1 ? "un an" : "\(n) ans")."
        }
        var p = "Parce que \(quoi) \(Self.quand(depuis: age, ageActuel: ageActuel))"
        if n >= 3 { p += ", à \(age) an\(age > 1 ? "s" : "")" }
        return p + "."
    }

    /// Souvenir d'un choix dans une carte.
    static func choix(_ label: String, texte: String, age: Int) -> Souvenir {
        Souvenir(age: age, quoi: "tu as choisi « \(label) »", contexte: extrait(texte), etat: nil)
    }

    /// Début d'un texte, coupé proprement vers 90 caractères.
    static func extrait(_ texte: String, max: Int = 90) -> String {
        let t = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max else { return t }
        let coupe = String(t.prefix(max))
        let fin = coupe.lastIndex(of: " ").map { String(coupe[..<$0]) } ?? coupe
        return fin.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:")) + "…"
    }

    // MARK: - Signaux de module

    /// Souvenir par défaut d'un signal de module (quand il ne vient pas d'un choix dans une carte).
    static func pourSignal(_ signal: String, age: Int) -> Souvenir? {
        guard let q = phrasesSignaux[signal] else { return nil }
        return Souvenir(age: age, quoi: q, contexte: nil, etat: nil)
    }

    /// Ce qui suit « Parce que » pour chaque signal commun (docs/REPERCUSSIONS.md).
    static let phrasesSignaux: [String: String] = [
        // Amour
        "rencontre": "tu as fait une rencontre", "rendez_vous": "tu es sorti{e} avec quelqu'un",
        "rendez_vous_rate": "tu as raté un rendez-vous", "couple": "tu t'es mis{e} en couple",
        "rupture": "tu as rompu", "largue": "tu t'es fait quitter", "tromperie": "tu as trompé ton couple",
        "tromperie_decouverte": "ta tromperie a été découverte", "demande_mariage": "tu t'es fiancé{e}",
        "demande_refusee": "ta demande en mariage a été refusée", "fiancailles_rompues": "tes fiançailles ont été rompues",
        "mariage": "tu t'es marié{e}", "divorce": "tu as divorcé", "veuvage": "tu as perdu l'amour de ta vie",
        "meilleur_ami": "tu t'es fait un meilleur ami",
        // Bébés
        "grossesse": "une grossesse a été annoncée", "naissance_enfant": "tu as eu un enfant", "adoption": "tu as adopté",
        "enfant_majeur": "ton enfant est devenu majeur", "enfant_quitte_maison": "ton enfant a quitté la maison",
        // Casino
        "casino_gain": "tu as gagné au casino", "casino_perte": "tu as perdu au casino", "casino_jackpot": "tu as touché le jackpot",
        "casino_ruine": "tu t'es ruiné{e} au casino", "casino_triche": "tu as triché au casino",
        "casino_triche_attrape": "tu t'es fait prendre à tricher au casino", "loterie_gain": "tu as gagné à la loterie",
        "pari_sportif_gain": "tu as gagné un pari", "pari_sportif_perte": "tu as perdu un pari",
        "casino_usurier": "tu as emprunté à Tonton Gégé", "casino_usurier_violence": "les neveux de Tonton Gégé sont passés te voir",
        // Permis
        "permis_obtenu": "tu as eu ton permis", "permis_rate": "tu as raté ton permis", "permis_retire": "on t'a retiré ton permis",
        "amende_vitesse": "tu as été flashé{e}", "accident_voiture": "tu as eu un accident de voiture",
        "achat_voiture": "tu as acheté une voiture", "faux_permis_achete": "tu as acheté un faux permis",
        "conduite_sans_permis_arretee": "tu t'es fait arrêter sans permis", "corruption_examinateur": "tu as soudoyé l'examinateur",
        // Crime
        "crime_reussi": "tu as commis un crime", "crime_rate": "ton coup a raté", "arrestation": "tu as été arrêté{e}",
        "proces_gagne": "tu as gagné ton procès", "proces_perdu": "tu as perdu ton procès", "prison_entree": "tu es entré{e} en prison",
        "prison_sortie": "tu es sorti{e} de prison", "evasion": "tu t'es évadé{e}", "condamnation": "tu as été condamné{e}",
        // École, travail
        "bac_obtenu": "tu as eu ton bac", "bac_rate": "tu as raté ton bac", "diplome": "tu as eu ton diplôme",
        "abandon_etudes": "tu as abandonné tes études", "embauche": "tu as été embauché{e}", "promotion": "tu as été promu{e}",
        "licenciement": "tu as été licencié{e}", "demission": "tu as démissionné", "retraite": "tu as pris ta retraite",
        // Famille, santé, argent
        "deces_parent": "tu as perdu un parent", "deces_proche": "tu as perdu un proche", "heritage": "tu as hérité",
        "maladie": "tu es tombé{e} malade", "guerison": "tu as guéri", "addiction": "tu es devenu{e} accro",
        "cure_desintox": "tu as fait une cure", "chirurgie_esthetique": "tu t'es fait opérer", "hopital": "tu es passé{e} par l'hôpital",
        "achat_maison": "tu as acheté une maison", "demenagement": "tu as déménagé", "gros_achat": "tu as fait un gros achat",
        "faillite": "tu as fait faillite", "voyage": "tu es parti{e} en voyage", "celebrite": "tu es devenu{e} célèbre",
        // Jeu vivant
        "achat_voiture_luxe": "tu t'es offert une voiture de luxe", "achat_bateau": "tu t'es offert un bateau",
        "achat_avion": "tu t'es offert un avion", "election_gagnee": "tu as gagné une élection", "mandat_perdu": "tu as perdu ton mandat",
        "entree_gouvernement": "tu es entré{e} au gouvernement", "millionnaire": "tu es devenu{e} millionnaire",
        "milliardaire": "tu es devenu{e} milliardaire", "ruine": "tu t'es ruiné{e}", "expatriation": "tu es parti{e} vivre à l'étranger",
        "retour_pays": "tu es rentré{e} au pays", "casier_efface": "ton casier a été effacé", "star_reseaux": "tu es devenu{e} une star des réseaux",
        "entreprise_creee": "tu as créé ton entreprise", "entreprise_vendue": "tu as vendu ton entreprise",
        "entreprise_faillite": "ton entreprise a fait faillite", "projet_lance": "tu t'es lancé{e} dans un projet",
        // Beauté
        "coiffure_ratee": "ta coupe de cheveux a mal tourné", "chirurgie_ratee": "ton opération a mal tourné",
        "chirurgie_clandestine": "tu t'es fait opérer en douce",
        // Secte et agence
        "secte_fondee": "tu as fondé ta secte", "secte_scandale": "ta secte a fait scandale", "agence_ouverte": "tu as ouvert ton agence",
        "agence_affaire_celebre": "tu as résolu une affaire célèbre",
    ]

    // MARK: - États durables

    /// « tu fumes », « tu as des dettes »… pour les drapeaux d'état sans origine connue.
    static func pourDrapeau(_ flag: String, poseA age: Int) -> Souvenir? {
        guard let q = phrasesEtats[flag] else { return nil }
        return Souvenir(age: age, quoi: q, contexte: nil, etat: true)
    }

    static let phrasesEtats: [String: String] = [
        "fume": "tu fumes", "boit_trop": "tu bois trop", "mange_mal": "tu manges mal", "sportif_regulier": "tu fais du sport",
        "sedentaire": "tu ne bouges plus de ton canapé", "insomniaque": "tu dors mal", "dos_fragile": "ton dos te lâche",
        "genou_fragile": "ton genou te lâche", "accro_aux_ecrans": "tu vis devant les écrans", "zen": "tu as trouvé ta sérénité",
        "deprime": "tu broies du noir", "anxieux": "tu vis dans l'angoisse", "burn_out": "tu es épuisé{e}",
        "coeur_brise": "tu as le cœur brisé", "solitaire": "tu vis seul{e} dans ton coin", "optimiste": "tu vois le verre à moitié plein",
        "complexe": "tu es complexé{e}", "traumatise": "tu portes un traumatisme", "menteur_notoire": "tout le monde sait que tu mens",
        "populaire": "tu es populaire", "honte_publique": "on se souvient de ta honte publique", "heros_local": "le quartier te prend pour un héros",
        "endette": "tu as des dettes", "econome": "tu mets de côté", "panier_perce": "l'argent te file entre les doigts",
        "dette_louche": "tu dois de l'argent aux mauvaises personnes", "surendette": "tu croules sous les dettes",
        "lecteur_assidu": "tu lis beaucoup", "polyglotte": "tu parles plusieurs langues", "tatoue": "tu es tatoué{e}",
        "refait_de_partout": "tu es refait{e} de partout", "benevole": "tu fais du bénévolat", "voleur": "tu voles",
        "rancunier": "tu as la rancune tenace", "genereux": "tu as le cœur sur la main", "casier_judiciaire": "tu as un casier judiciaire",
        "poumons_goudronnes": "tes poumons sont abîmés", "foie_fatigue": "ton foie est fatigué", "tension_haute": "tu as de la tension",
    ]
}

/// Photo des répercussions avant un choix, pour dire après coup « ce choix laissera des traces ».
struct TracesChoix {
    let programmees: Int
    let drapeaux: Set<String>

    init(_ etat: RepercussionsEtat?) {
        programmees = etat?.programmees.count ?? 0
        drapeaux = Set((etat?.flags ?? [:]).keys)
    }

    /// Vrai si une suite a été programmée ou un nouveau drapeau posé.
    func differe(_ etat: RepercussionsEtat?) -> Bool {
        let apres = TracesChoix(etat)
        return apres.programmees > programmees || !apres.drapeaux.subtracting(drapeaux).isEmpty
    }
}

import Foundation

// Logique du module « Cœur ». Voir docs/COEUR.md.
// Toutes les fonctions prennent le joueur en inout et renvoient les lignes à écrire dans le journal.

extension Joueur {
    /// État du module Cœur (vide tant que rien ne s'est passé).
    var coeurEtat: CoeurEtat {
        get { coeur ?? CoeurEtat() }
        set { coeur = newValue }
    }
}

enum CoeurSysteme {

    /// Couple qui ne peut jamais se séparer ni être trompé (branché par le moteur, ex. module âme sœur).
    /// Vrai = pas de tentation qui aboutit, pas d'infidélité du/de la partenaire.
    static var coupleProtege: ((Joueur) -> Bool)?

    static func estProtege(_ j: Joueur) -> Bool { coupleProtege?(j) ?? false }

    static let prixTherapie = 2_400
    static let pensionAnnuelle = 3_600

    // MARK: - Tags

    static func tags(_ j: Joueur) -> Set<String> {
        let c = j.coeurEtat
        var t: Set<String> = []
        let enCouple = j.partenaireActuel != nil
        if let l = c.liaison {
            t.insert("liaison")
            if j.age - l.depuisAge >= 2 { t.insert("liaison_longue") }
            if l.ultimatum { t.insert("liaison_ultimatum") }
            if l.soupcon >= 50 { t.insert("liaison_soupcon") }
            let ageFemme = l.genre == .femme ? l.age : j.age
            if l.genre != j.genre && (18...45).contains(ageFemme)
                && c.grossesseLiaison == nil && j.vieEtat.grossesse == nil {
                t.insert("liaison_hetero")
            }
        } else if !c.anciennes.isEmpty {
            t.insert("ancien_amant")
        }
        if c.grossesseLiaison != nil { t.insert("grossesse_liaison") }
        if !c.enfantsSecrets.isEmpty { t.insert("enfant_cache") }
        if c.enfantsSecrets.contains(where: { $0.age(j.age) >= 18 }) { t.insert("enfant_cache_adulte") }
        if c.paterniteDouteuse { t.insert("paternite_douteuse") }
        if enCouple {
            if c.partenaireInfidele { t.insert("partenaire_infidele") }
            if c.soupconJoueur >= 30 { t.insert("soupcon_partenaire") }
            if c.trahi { t.insert("trahi") }
            if c.crise > 0 { t.insert("crise_couple") }
            if c.therapie > 0 { t.insert("therapie_couple") }
            if c.relationLibre { t.insert("relation_libre") }
            if c.ecartsCaches > 0 { t.insert("ecart_secret") }
        }
        if let p = j.partenaireActuel {
            if j.vieEtat.anneesEnsemble < 1 { t.insert("couple_recent") }
            let ageFemme = j.genre == .femme ? j.age : (p.genre == .femme ? p.age : 0)
            if p.genre != j.genre && (18...47).contains(ageFemme) && j.vieEtat.grossesse == nil {
                t.insert("couple_fertile")
            }
        }
        if c.tromperies >= 1 { t.insert("infidele") }
        if c.tromperies >= 3 { t.insert("infidele_recidiviste") }
        return t
    }

    // MARK: - Textes

    /// {amant}, {amant_role} (« ton amant » / « ta maîtresse »), {amant_il} (il / elle), {enfant_cache},
    /// et pour les cartes d'action : {cible}, {cible_il} (il/elle), {cible_lui} (lui/elle), {cible_le} (le/la), {cible_e}.
    static func remplir(_ texte: String, _ j: Joueur) -> String {
        guard texte.contains("{amant") || texte.contains("{enfant_cache}") || texte.contains("{cible") else { return texte }
        let c = j.coeurEtat
        var t = texte
        if texte.contains("{cible") {
            let r = c.cibleCarte.flatMap { id in j.relations.first { $0.id == id } }
            let femme = r?.genre == .femme
            t = t.replacingOccurrences(of: "{cible_il}", with: femme ? "elle" : "il")
            t = t.replacingOccurrences(of: "{cible_lui}", with: femme ? "elle" : "lui")
            t = t.replacingOccurrences(of: "{cible_le}", with: femme ? "la" : "le")
            t = t.replacingOccurrences(of: "{cible_e}", with: femme ? "e" : "")
            t = t.replacingOccurrences(of: "{cible}", with: r?.prenom ?? "ton proche")
        }
        if let l = c.liaison {
            t = t.replacingOccurrences(of: "{amant_role}", with: l.role)
            t = t.replacingOccurrences(of: "{amant_il}", with: l.pronom)
            t = t.replacingOccurrences(of: "{amant}", with: l.prenom)
        } else {
            t = t.replacingOccurrences(of: "{amant_role}", with: "ton ancienne flamme")
            t = t.replacingOccurrences(of: "{amant_il}", with: "cette personne")
            t = t.replacingOccurrences(of: "{amant}", with: c.anciennes.last ?? "ton ancienne flamme")
        }
        let enfant = c.enfantsSecrets.first ?? c.enfantsCaches.last
        t = t.replacingOccurrences(of: "{enfant_cache}", with: enfant?.prenom ?? "l'enfant")
        return t
    }

    // MARK: - Effets "coeur"

    static func appliquer(_ fx: CoeurEffets?, _ j: inout Joueur) -> [String] {
        guard let fx else { return [] }
        var lignes: [String] = []
        let enCouple = j.partenaireActuel != nil

        var c = j.coeurEtat
        if let d = fx.soupconJoueur { c.soupconJoueur = Stats.borne(c.soupconJoueur + d) }
        if let v = fx.partenaireInfidele, enCouple {
            c.partenaireInfidele = v
            if !v { c.trahi = false }
        }
        if let n = fx.crise, enCouple { c.crise = n > 0 ? max(c.crise, n) : 0 }
        if let n = fx.therapie, enCouple, n > 0 {
            c.therapie = max(c.therapie, n)
            VieSysteme.signaler("therapie_couple", &j)
        }
        j.coeurEtat = c

        if let r = fx.relationLibre, enCouple {
            var e = j.coeurEtat
            e.relationLibre = r
            if r { e.liaison?.soupcon = 0 }
            j.coeurEtat = e
            if r { VieSysteme.signaler("relation_libre", &j) }
        }
        if fx.pardon == true { lignes += pardonner(&j) }
        if fx.ecart == true { lignes += ecart(&j) }
        if let l = fx.liaison {
            switch l {
            case "debut": lignes += debuterLiaison(&j, via: fx.via ?? "autre")
            case "fin": lignes += finirLiaison(&j, parLeJoueur: true)
            case "officialiser": lignes += officialiser(&j)
            case "avouer": lignes += decouvrir(&j, aveu: true)
            default: break
            }
        }
        if let d = fx.intensite, var l = j.coeurEtat.liaison {
            l.intensite = Stats.borne(l.intensite + d)
            var e = j.coeurEtat; e.liaison = l; j.coeurEtat = e
            if l.intensite <= 0 { lignes += finirLiaison(&j, parLeJoueur: false) }
        }
        if let d = fx.soupcon {
            lignes += ajouterSoupcon(d, &j)
        }
        if fx.decouverte == true { lignes += decouvrir(&j, aveu: false, force: true) }
        if fx.grossesse == true { lignes += grossesse(&j) }
        if let a = fx.enfantCache { lignes += enfantCache(a, id: nil, &j) }
        if fx.trahisonDecouverte == true { lignes += prendreSurLeFait(&j) }
        if let s = fx.scandale, s > 0, let l = scandaleReseaux(Double(min(s, 80)) / 100, &j) { lignes.append(l) }
        if let d = fx.lienCible, let id = j.coeurEtat.cibleCarte, let i = j.relations.firstIndex(where: { $0.id == id }) {
            j.relations[i].lien = Stats.borne(j.relations[i].lien + d)
        }
        j.stats.borner()
        return lignes
    }

    /// Ajoute des soupçons au/à la partenaire ; à 100, tout est découvert.
    static func ajouterSoupcon(_ d: Int, _ j: inout Joueur) -> [String] {
        guard var l = j.coeurEtat.liaison else { return [] }
        if j.coeurEtat.relationLibre { return [] }
        l.soupcon = Stats.borne(l.soupcon + d)
        var e = j.coeurEtat; e.liaison = l; j.coeurEtat = e
        if l.soupcon >= 100 { return decouvrir(&j, aveu: false) }
        return []
    }

    // MARK: - Tromper

    private static func poserDrapeaux(_ poser: [String], _ j: inout Joueur) {
        var rep = j.repercussions ?? RepercussionsEtat()
        Repercussions.appliquerDrapeaux(poser: poser, retirer: nil, age: j.age, etat: &rep)
        j.repercussions = rep
    }

    private static func programmer(_ id: String, _ j: inout Joueur) {
        var rep = j.repercussions ?? RepercussionsEtat()
        Repercussions.programmer(id: id, age: j.age, etat: &rep)
        j.repercussions = rep
    }

    /// Aventure d'un soir.
    static func ecart(_ j: inout Joueur) -> [String] {
        guard let p = j.partenaireActuel, !estProtege(j) else { return [] }
        var c = j.coeurEtat
        c.tromperies += 1
        let libre = c.relationLibre
        if !libre { c.ecartsCaches += 1 }
        j.coeurEtat = c
        var lignes: [String] = []
        if libre {
            j.stats.bonheur += 2
            lignes.append("Relation libre oblige, ce n'est pas vraiment tromper. \(p.prenom) te demande quand même « c'était qui ? » d'un ton très détaché.")
        } else {
            j.stats.karma -= 6
            poserDrapeaux(["a_trompe_partenaire"], &j)
            VieSysteme.signaler("tromperie", &j)
        }
        // Une nuit peut avoir des conséquences (rarement).
        let ageFemme = j.genre == .femme ? j.age : max(18, j.age + Int.random(in: -6...4))
        if p.genre != j.genre, (18...44).contains(ageFemme), VieHasard.reussi(0.05) {
            if j.genre == .femme {
                if j.vieEtat.grossesse == nil {
                    _ = VieRelations.conception(&j)
                    var e = j.coeurEtat; e.paterniteDouteuse = true; j.coeurEtat = e
                    lignes.append("Quelques semaines plus tard : tu es enceinte. Et tu n'es pas du tout sûre que ce soit de \(p.prenom).")
                }
            } else if j.coeurEtat.grossesseLiaison == nil {
                var e = j.coeurEtat
                e.grossesseLiaison = 9
                e.parentGrossesse = VieDonnees.prenom(.femme)
                j.coeurEtat = e
                lignes.append("Quelques semaines plus tard, un message d'un numéro inconnu : « C'est \(e.parentGrossesse ?? "moi"). Il faut qu'on parle. Je suis enceinte. »")
                VieSysteme.signaler("grossesse_liaison", &j)
            }
        }
        return lignes
    }

    /// Démarre une liaison secrète (seulement si le joueur est en couple et n'en a pas déjà une).
    @discardableResult
    static func debuterLiaison(_ j: inout Joueur, via: String, prenom: String? = nil, genre: Genre? = nil, age: Int? = nil) -> [String] {
        guard let p = j.partenaireActuel, j.age >= 16, !estProtege(j) else { return [] }
        var c = j.coeurEtat
        guard c.liaison == nil else { return [] }
        var g: Genre = genre ?? (VieHasard.reussi(0.85) ? p.genre : (p.genre == .homme ? .femme : .homme))
        var pre = prenom ?? VieDonnees.prenom(g)
        var nom = VieDonnees.nomFamille()
        var a = age ?? max(18, j.age + Int.random(in: -8...6))
        if via == "ex", prenom == nil, let ex = j.exVivants.randomElement() {
            pre = ex.prenom; nom = ex.nom; g = ex.genre; a = ex.age
        }
        let libre = c.relationLibre
        c.liaison = CoeurLiaison(prenom: pre, nom: nom, genre: g, age: a, depuisAge: j.age, via: via,
                                 intensite: Int.random(in: 45...70), soupcon: libre ? 0 : Int.random(in: 0...15))
        c.tromperies += 1
        j.coeurEtat = c
        j.stats.bonheur += 6
        VieSysteme.signaler("liaison_debut", &j)
        if libre {
            return ["💋 Tu commences une histoire avec \(pre). Relation libre oblige, \(p.prenom) est au courant. En théorie, ça ne le dérange pas. En théorie."]
        }
        j.stats.karma -= 8
        poserDrapeaux(["a_trompe_partenaire"], &j)
        VieSysteme.signaler("tromperie", &j)
        let role = g == .femme ? "ta maîtresse" : "ton amant"
        return ["💋 Tu commences une liaison secrète avec \(pre), \(a) ans. \(pre) devient \(role). \(p.prenom) ne se doute de rien. Pour l'instant."]
    }

    /// Fin de la liaison, voulue par le joueur ou par l'amant·e.
    static func finirLiaison(_ j: inout Joueur, parLeJoueur: Bool) -> [String] {
        var c = j.coeurEtat
        guard let l = c.liaison else { return [] }
        c.liaison = nil
        c.anciennes.append(l.prenom)
        j.coeurEtat = c
        VieSysteme.signaler("liaison_fin", &j)
        if !parLeJoueur {
            j.stats.bonheur -= 8
            return ["💔 \(l.prenom) met fin à votre liaison : « Je ne serai jamais ta priorité. » \(l.genre == .femme ? "Elle" : "Il") a bloqué ton numéro. Tu ne peux en parler à personne, et c'est ça le pire."]
        }
        if j.partenaireActuel != nil, !c.relationLibre, l.intensite >= 80, VieHasard.reussi(0.35) {
            var lignes = ["Tu annonces à \(l.prenom) que c'est fini. \(l.genre == .femme ? "Elle" : "Il") ne le prend pas bien du tout et décide de tout raconter."]
            lignes += decouvrir(&j, aveu: false, force: true)
            return lignes
        }
        j.stats.bonheur -= 3
        return ["Tu mets fin à ta liaison avec \(l.prenom). Un dernier café, des lunettes de soleil, et chacun repart de son côté. Ta conscience respire un peu mieux."]
    }

    /// L'amant·e devient le/la partenaire officiel·le (le joueur doit être célibataire).
    private static func amantDevientPartenaire(_ j: inout Joueur) {
        var c = j.coeurEtat
        guard let l = c.liaison, j.partenaireActuel == nil else { return }
        let r = Relation(prenom: l.prenom, nom: l.nom, genre: l.genre, type: .partenaire, age: l.age,
                         lien: max(55, l.intensite), argent: Int.random(in: 0...40_000))
        j.relations.append(r)
        c.liaison = nil
        c.anciennes.append(l.prenom)
        c.crise = 0; c.therapie = 0; c.relationLibre = false; c.partenaireInfidele = false
        c.trahi = false; c.soupconJoueur = 0; c.ecartsCaches = 0
        j.coeurEtat = c
        var v = j.vieEtat; v.statutCouple = nil; v.anneesEnsemble = 0; j.vieEtat = v
        VieSysteme.signaler("liaison_officialisee", &j)
        VieSysteme.signaler("couple", &j)
    }

    /// Quitter son/sa partenaire pour l'amant·e.
    static func officialiser(_ j: inout Joueur) -> [String] {
        guard let l = j.coeurEtat.liaison, let p = j.partenaireActuel else { return [] }
        var lignes = VieRelations.rompre(&j, parLeJoueur: true)
        if let i = j.relations.firstIndex(where: { $0.id == p.id }) {
            j.relations[i].lien = min(j.relations[i].lien, 5)
        }
        VieSysteme.signaler("tromperie_decouverte", &j)
        amantDevientPartenaire(&j)
        for k in j.relations.indices where j.relations[k].type == .enfant && j.relations[k].vivant && j.relations[k].age >= 8 {
            j.relations[k].lien = Stats.borne(j.relations[k].lien - 12)
        }
        j.stats.karma -= 5
        lignes.append("Tu quittes \(p.prenom) pour \(l.prenom). Plus besoin de mentir : vous vous affichez au grand jour. Les amis de \(p.prenom) changent de trottoir quand ils te croisent.")
        if let s = scandaleReseaux(0.08, &j) { lignes.append(s) }
        return lignes
    }

    // MARK: - Découverte

    static let causesDecouverte = [
        "Un message de {amant} s'est affiché sur ton écran verrouillé pendant le dîner. Avec un cœur. {partenaire} l'a lu à voix haute.",
        "{partenaire} a trouvé une note d'hôtel dans la poche de ta veste. Ville : la tienne. Chambre : double.",
        "Une amie de {partenaire} vous a vus, {amant} et toi, au restaurant. Elle a pris une photo. Plusieurs, en fait.",
        "La montre connectée a tout raconté : rythme cardiaque à 140 un mardi à 15 h, adresse inconnue.",
        "{partenaire} a reconnu le parfum de {amant} sur ton écharpe. Puis dans la voiture. Puis partout.",
        "Le relevé de compte joint mentionnait « Bijouterie » et « Hôtel du Lac ». {partenaire} n'a reçu aucun bijou.",
        "Tu as appelé {partenaire} par le prénom de {amant}. Au lit. Il n'y a pas de bonne façon de rattraper ça.",
    ]

    static let causesEcart = [
        "Ton écart a fini par se savoir : la personne a retrouvé {partenaire} sur les réseaux et lui a tout raconté.",
        "Un ami commun a « fait une gaffe » pendant un apéro. {partenaire} a reposé son verre très lentement.",
        "{partenaire} a fait le lien entre ta « soirée qui a duré tard » et une photo publiée cette nuit-là.",
    ]

    /// Le/la partenaire découvre la liaison ou les écarts. Peut finir en rupture (ou divorce) ou en crise.
    static func decouvrir(_ j: inout Joueur, aveu: Bool, force: Bool = false) -> [String] {
        guard let p = j.partenaireActuel, let i = j.relations.firstIndex(where: { $0.id == p.id }) else { return [] }
        var c = j.coeurEtat
        let aQuelqueChose = c.liaison != nil || c.ecartsCaches > 0
        guard force || aQuelqueChose else { return [] }
        if c.relationLibre && c.ecartsCaches == 0 { return [] }
        let lienAvant = p.lien
        let marie = j.vieEtat.statutCouple == .marie
        let enfants = !j.enfantsVivants.isEmpty
        c.decouvertes += 1
        let recidive = c.decouvertes > 1
        let longue = c.liaison.map { j.age - $0.depuisAge >= 2 } ?? false
        var chanceDepart = 0.45 + (recidive ? 0.25 : 0) + (longue ? 0.15 : 0)
        chanceDepart -= (marie ? 0.1 : 0) + (enfants ? 0.1 : 0) + Double(lienAvant) / 250 + (aveu ? 0.2 : 0)
        chanceDepart = min(0.95, max(0.05, chanceDepart))
        let avaitLiaison = c.liaison != nil
        c.ecartsCaches = 0
        j.coeurEtat = c

        j.relations[i].lien = Stats.borne(lienAvant - Int.random(in: 30...50) + (aveu ? 12 : 0))
        j.stats.bonheur -= 15
        if !aveu { j.stats.karma -= 4 } else { j.stats.karma += 3 }
        poserDrapeaux(["a_trompe_partenaire"], &j)
        VieSysteme.signaler("tromperie_decouverte", &j)

        var lignes: [String] = []
        if aveu {
            lignes.append("💔 Tu avoues tout à \(p.prenom). Un long silence. Puis des questions, beaucoup de questions, jusqu'à 4 h du matin.")
        } else {
            let phrase = (avaitLiaison ? causesDecouverte : causesEcart).auHasard("{partenaire} a tout découvert.")
            lignes.append("💔 " + remplir(phrase, j).replacingOccurrences(of: "{partenaire}", with: p.prenom))
        }
        // Les enfants assez grands comprennent.
        for k in j.relations.indices where j.relations[k].type == .enfant && j.relations[k].vivant && j.relations[k].age >= 10 {
            j.relations[k].lien = Stats.borne(j.relations[k].lien - 12)
        }

        if VieHasard.reussi(chanceDepart) {
            lignes += VieRelations.rompre(&j, parLeJoueur: false)
            if let k = j.relations.firstIndex(where: { $0.id == p.id }) {
                j.relations[k].lien = min(j.relations[k].lien, 8)
            }
            if let l = j.coeurEtat.liaison {
                if VieHasard.reussi(Double(l.intensite) / 120) {
                    amantDevientPartenaire(&j)
                    lignes.append("\(l.prenom) débarque le soir même avec deux cartons et une plante verte. Vous n'avez plus à vous cacher.")
                } else {
                    var e = j.coeurEtat; e.liaison = nil; e.anciennes.append(l.prenom); j.coeurEtat = e
                    lignes.append("\(l.prenom) ne veut pas être « la personne pour qui tu as tout cassé » et disparaît aussi. Tu te retrouves seul\(j.g("", "e")) avec un canapé et des regrets.")
                }
            }
        } else {
            var e = j.coeurEtat
            e.crise = max(e.crise, 3)
            if let l = e.liaison { e.liaison = nil; e.anciennes.append(l.prenom) }
            j.coeurEtat = e
            lignes.append("\(p.prenom) reste. Pour l'instant. Tu dors sur le canapé, la confiance est en miettes et il faudra des années pour la reconstruire.")
            if avaitLiaison { lignes.append("Condition non négociable : tu ne revois plus jamais ton amant·e.") }
            programmer("rep_coe_0001", &j)
        }
        if (j.telephone?.abonnesTotal ?? 0) >= 50_000, let s = scandaleReseaux(0.15, &j) { lignes.append(s) }
        j.stats.borner()
        return lignes
    }

    /// Le joueur découvre que son/sa partenaire le trompe.
    static func prendreSurLeFait(_ j: inout Joueur) -> [String] {
        guard let p = j.partenaireActuel, let i = j.relations.firstIndex(where: { $0.id == p.id }) else { return [] }
        var c = j.coeurEtat
        guard c.partenaireInfidele else {
            c.soupconJoueur = max(0, c.soupconJoueur - 25)
            j.coeurEtat = c
            return ["Tu cherches, tu fouilles, tu recoupes… rien. \(p.prenom) est juste très investi\(p.genre == .femme ? "e" : "") dans son club de pétanque."]
        }
        c.trahi = true
        c.soupconJoueur = 100
        j.coeurEtat = c
        j.relations[i].lien = Stats.borne(p.lien - 25)
        j.stats.bonheur -= 18
        j.stats.sante -= 3
        poserDrapeaux(["s_est_fait_tromper", "coeur_brise"], &j)
        VieSysteme.signaler("tromperie_subie", &j)
        programmer("rep_coe_0002", &j)
        j.stats.borner()
        return ["💔 C'est confirmé : \(p.prenom) te trompe. Depuis des mois. Tout le monde avait l'air de savoir, sauf toi."]
    }

    /// Pardon : on tourne la page (crise finie, le/la partenaire promet d'arrêter).
    static func pardonner(_ j: inout Joueur) -> [String] {
        guard let p = j.partenaireActuel, let i = j.relations.firstIndex(where: { $0.id == p.id }) else { return [] }
        var c = j.coeurEtat
        let etaitTrahi = c.trahi
        c.trahi = false
        c.crise = 0
        c.pardons += 1
        if etaitTrahi && VieHasard.reussi(0.7) { c.partenaireInfidele = false }
        c.soupconJoueur = etaitTrahi ? 40 : c.soupconJoueur
        j.coeurEtat = c
        j.relations[i].lien = Stats.borne(p.lien + 10)
        j.stats.karma += 3
        return [etaitTrahi
                ? "Tu pardonnes à \(p.prenom). Pas tout de suite, pas tout à fait, mais tu essaies. Chaque vibration de son téléphone te serre encore le ventre."
                : "Vous décidez de tourner la page, \(p.prenom) et toi. Ce n'est pas magique, mais c'est un début."]
    }

    // MARK: - Bébés et enfants cachés

    static func grossesse(_ j: inout Joueur) -> [String] {
        var c = j.coeurEtat
        guard let l = c.liaison, l.genre != j.genre else { return [] }
        if j.genre == .femme {
            guard j.vieEtat.grossesse == nil, (16...47).contains(j.age) else { return [] }
            _ = VieRelations.conception(&j)
            var v = j.vieEtat; v.autreParent = l.prenom; j.vieEtat = v
            c = j.coeurEtat
            c.paterniteDouteuse = j.partenaireActuel != nil
            j.coeurEtat = c
            if let p = j.partenaireActuel {
                return ["🤰 Tu es enceinte. Et ce n'est pas de \(p.prenom). C'est de \(l.prenom). Tu fixes le test pendant vingt minutes."]
            }
            return ["🤰 Tu es enceinte de \(l.prenom)."]
        }
        guard c.grossesseLiaison == nil, (16...47).contains(l.age) else { return [] }
        c.grossesseLiaison = 9
        c.parentGrossesse = l.prenom
        j.coeurEtat = c
        VieSysteme.signaler("grossesse_liaison", &j)
        var texte = "🤰 \(l.prenom) est enceinte. De toi."
        if let p = j.partenaireActuel { texte += " \(p.prenom) n'en sait rien." }
        return [texte]
    }

    private static func naissanceCachee(_ j: inout Joueur) -> [String] {
        var c = j.coeurEtat
        let g: Genre = Bool.random() ? .homme : .femme
        let enfant = CoeurEnfantCache(prenom: VieDonnees.prenom(g), genre: g, neQuandJoueurAvait: j.age,
                                      autreParent: c.parentGrossesse ?? "son autre parent")
        c.enfantsCaches.append(enfant)
        c.grossesseLiaison = nil
        c.parentGrossesse = nil
        j.coeurEtat = c
        VieSysteme.signaler("enfant_cache_ne", &j)
        let qui = g == .homme ? "un petit garçon" : "une petite fille"
        var texte = "👶 \(enfant.autreParent) a accouché : \(qui), \(enfant.prenom). Ton enfant."
        if let p = j.partenaireActuel { texte += " \(p.prenom) n'en sait rien." }
        texte += " Tu peux le reconnaître ou verser une pension dans le menu Amour."
        return [texte]
    }

    /// Action sur un enfant caché (le dernier non reconnu si `id` est nil).
    static func enfantCache(_ action: String, id: UUID?, _ j: inout Joueur) -> [String] {
        var c = j.coeurEtat
        var index: Int? = nil
        if let x = id {
            index = c.enfantsCaches.firstIndex(where: { $0.id == x })
        } else {
            index = c.enfantsCaches.lastIndex(where: { !$0.reconnu })
        }
        guard let k = index else {
            if action == "reveler" && c.paterniteDouteuse { return revelerPaternite(&j) }
            return []
        }
        let e = c.enfantsCaches[k]
        switch action {
        case "pension":
            guard !e.pension else { return [] }
            c.enfantsCaches[k].pension = true
            j.coeurEtat = c
            j.stats.karma += 3
            return ["Tu verses une pension pour \(e.prenom) : 300 € par mois. \(e.autreParent) t'envoie une photo chaque Noël."]
        case "cacher":
            c.enfantsCaches[k].pension = false
            j.coeurEtat = c
            j.stats.karma -= 4
            return ["Tu fais comme si \(e.prenom) n'existait pas. \(e.autreParent) a gardé ton adresse, au cas où."]
        case "reconnaitre":
            guard !e.reconnu else { return [] }
            c.enfantsCaches[k].reconnu = true
            let dejaSu = e.revele
            c.enfantsCaches[k].revele = true
            j.coeurEtat = c
            let age = e.age(j.age)
            j.relations.append(Relation(prenom: e.prenom, nom: j.nom, genre: e.genre, type: .enfant, age: age,
                                        lien: age < 3 ? 70 : max(20, 55 - age * 2)))
            j.stats.karma += 5
            VieSysteme.signaler("enfant_cache_reconnu", &j)
            var lignes = ["Tu reconnais officiellement \(e.prenom). \(e.genre == .femme ? "Elle" : "Il") porte maintenant ton nom."]
            if !dejaSu { lignes += reactionEnfant(e, &j) }
            return lignes
        case "reveler":
            guard !e.revele else { return [] }
            c.enfantsCaches[k].revele = true
            j.coeurEtat = c
            return reactionEnfant(e, &j)
        default:
            return []
        }
    }

    /// Le/la partenaire apprend l'existence d'un enfant caché.
    private static func reactionEnfant(_ e: CoeurEnfantCache, _ j: inout Joueur) -> [String] {
        guard let p = j.partenaireActuel, let i = j.relations.firstIndex(where: { $0.id == p.id }) else { return [] }
        j.relations[i].lien = Stats.borne(p.lien - 35)
        j.stats.bonheur -= 10
        var c = j.coeurEtat; c.crise = max(c.crise, 2); j.coeurEtat = c
        VieSysteme.signaler("enfant_cache_revele", &j)
        VieSysteme.signaler("tromperie_decouverte", &j)
        var lignes = ["💔 \(p.prenom) apprend l'existence de \(e.prenom), \(e.age(j.age)) an\(e.age(j.age) > 1 ? "s" : ""). Il y a un avant et un après ce soir-là."]
        if p.lien - 35 < 15 && VieHasard.reussi(0.5) {
            lignes += VieRelations.rompre(&j, parLeJoueur: false)
        }
        return lignes
    }

    private static func revelerPaternite(_ j: inout Joueur) -> [String] {
        var c = j.coeurEtat
        c.paterniteDouteuse = false
        c.crise = max(c.crise, 3)
        j.coeurEtat = c
        guard let p = j.partenaireActuel, let i = j.relations.firstIndex(where: { $0.id == p.id }) else { return [] }
        j.relations[i].lien = Stats.borne(p.lien - 40)
        j.stats.bonheur -= 12
        VieSysteme.signaler("tromperie_decouverte", &j)
        var lignes = ["💔 \(p.prenom) apprend que l'enfant n'est pas le sien. Le silence qui suit dure une éternité."]
        if VieHasard.reussi(0.6) { lignes += VieRelations.rompre(&j, parLeJoueur: false) }
        return lignes
    }

    // MARK: - Réseaux sociaux

    /// Le scandale fait perdre des abonnés (seulement si le joueur est un peu connu).
    static func scandaleReseaux(_ part: Double, _ j: inout Joueur) -> String? {
        guard var t = j.telephone, t.aTelephone, t.abonnesTotal >= 5_000 else { return nil }
        var perte = 0
        for app in PhoneApp.publics {
            var compte = t.compte(app)
            let p = Int(Double(compte.abonnes) * part)
            compte.abonnes -= p
            perte += p
            t.comptes[app.rawValue] = compte
        }
        t.badBuzzRestant = max(t.badBuzzRestant, 2)
        j.telephone = t
        j.stats.bonheur -= 5
        return "📱 L'histoire fait le tour des réseaux. Tu perds \(PhoneFormat.nombre(perte)) abonnés et les commentaires sont… instructifs."
    }

    // MARK: - Une année passe

    static func passerAnnee(_ j: inout Joueur) -> [String] {
        var lignes: [String] = []
        var c = j.coeurEtat
        c.actionsAnnee = []
        j.coeurEtat = c
        guard j.vivant else { return [] }

        if j.partenaireActuel == nil {
            c = j.coeurEtat
            c.partenaireInfidele = false; c.trahi = false; c.soupconJoueur = 0
            c.crise = 0; c.therapie = 0; c.relationLibre = false; c.ecartsCaches = 0
            j.coeurEtat = c
        }

        lignes += anneeLiaison(&j)

        // Écarts cachés : ils finissent par se savoir… ou par s'oublier.
        c = j.coeurEtat
        if c.ecartsCaches > 0, j.partenaireActuel != nil {
            if VieHasard.reussi(min(0.45, 0.12 * Double(c.ecartsCaches))) {
                lignes += decouvrir(&j, aveu: false)
            } else if VieHasard.reussi(0.25) {
                c.ecartsCaches -= 1
                j.coeurEtat = c
            }
        }

        // Bébé de la liaison.
        c = j.coeurEtat
        if let m = c.grossesseLiaison {
            if m <= 12 {
                lignes += naissanceCachee(&j)
            } else {
                c.grossesseLiaison = m - 12
                j.coeurEtat = c
            }
        }

        lignes += anneeEnfantsCaches(&j)
        lignes += anneeCouple(&j)
        j.stats.borner()
        return lignes
    }

    private static func anneeLiaison(_ j: inout Joueur) -> [String] {
        var c = j.coeurEtat
        guard var l = c.liaison else { return [] }
        l.age += 1
        c.liaison = l
        j.coeurEtat = c
        guard let p = j.partenaireActuel else {
            if VieHasard.reussi(Double(l.intensite) / 110) {
                amantDevientPartenaire(&j)
                return ["Maintenant que tu es libre, \(l.prenom) s'installe chez toi. Plus de messages effacés, plus d'hôtels : vous êtes un couple normal. C'est presque décevant."]
            }
            c = j.coeurEtat
            c.liaison = nil
            c.anciennes.append(l.prenom)
            j.coeurEtat = c
            return ["Sans le frisson de l'interdit, ton histoire avec \(l.prenom) s'éteint d'elle-même."]
        }
        var lignes: [String] = []
        l.intensite = Stats.borne(l.intensite + Int.random(in: -6...8))
        if !c.relationLibre {
            var hausse = Int.random(in: 6...16)
            if (j.telephone?.abonnesTotal ?? 0) >= 100_000 { hausse += 8 }
            if j.age - l.depuisAge >= 3 { hausse += 5 }
            l.soupcon = Stats.borne(l.soupcon + hausse)
        }
        if l.intensite >= 85 && j.age - l.depuisAge >= 2 { l.ultimatum = true }
        c.liaison = l
        j.coeurEtat = c

        if j.age >= 18 {
            let cout = Int.random(in: 300...2_500)
            j.argent -= cout
            j.stats.sante -= 2
            if VieHasard.reussi(0.45) {
                lignes.append("Ta double vie avec \(l.prenom) t'a coûté \(Format.argent(cout)) cette année en hôtels, cadeaux et excuses. Et quelques nuits de sommeil.")
            }
        }
        if l.intensite <= 15 {
            lignes += finirLiaison(&j, parLeJoueur: false)
        } else if l.soupcon >= 100 {
            lignes += decouvrir(&j, aveu: false)
        } else if l.soupcon >= 70, VieHasard.reussi(0.5) {
            lignes.append(["\(p.prenom) pose beaucoup de questions sur tes « réunions tardives ». Tes réponses sont de moins en moins convaincantes.",
                           "\(p.prenom) a regardé ton téléphone un peu trop longtemps ce soir. Tu as mal dormi.",
                           "\(p.prenom) t'a demandé, l'air de rien : « Tu me le dirais, hein, s'il y avait quelqu'un ? »"].auHasard(""))
        }
        return lignes
    }

    private static func anneeEnfantsCaches(_ j: inout Joueur) -> [String] {
        var c = j.coeurEtat
        guard !c.enfantsCaches.isEmpty else { return [] }
        var lignes: [String] = []
        var aReveler: CoeurEnfantCache?
        for k in c.enfantsCaches.indices where !c.enfantsCaches[k].reconnu {
            let e = c.enfantsCaches[k]
            let age = e.age(j.age)
            if age < 18 {
                if e.pension {
                    j.argent -= pensionAnnuelle
                } else {
                    j.stats.karma -= 1
                    if VieHasard.reussi(0.06) {
                        c.enfantsCaches[k].pension = true
                        let arrieres = 4_000 + age * 1_000
                        j.argent -= arrieres
                        lignes.append("⚖️ \(e.autreParent) t'a assigné\(j.g("", "e")) devant le juge pour \(e.prenom). Pension obligatoire et \(Format.argent(arrieres)) d'arriérés.")
                    }
                }
            }
            if j.partenaireActuel != nil, !e.revele, aReveler == nil,
               VieHasard.reussi(e.pension ? 0.08 : 0.04) {
                c.enfantsCaches[k].revele = true
                aReveler = e
            }
        }
        j.coeurEtat = c
        if let e = aReveler {
            let p = j.partenaireActuel?.prenom ?? "Ton/ta partenaire"
            lignes.append("\(p) est tombé\(j.partenaireActuel?.genre == .femme ? "e" : "") sur les virements mensuels au nom de \(e.autreParent).")
            lignes += reactionEnfant(e, &j)
        }
        return lignes
    }

    private static func anneeCouple(_ j: inout Joueur) -> [String] {
        guard let p = j.partenaireActuel, let i = j.relations.firstIndex(where: { $0.id == p.id }) else { return [] }
        var c = j.coeurEtat
        var lignes: [String] = []
        if estProtege(j) && (c.partenaireInfidele || c.trahi) {
            c.partenaireInfidele = false
            c.trahi = false
            j.coeurEtat = c
        }

        // Le/la partenaire infidèle.
        if c.partenaireInfidele && !c.trahi {
            c.soupconJoueur = Stats.borne(c.soupconJoueur + Int.random(in: 5...15))
            j.coeurEtat = c
            if VieHasard.reussi(0.1) {
                lignes.append("💔 \(p.prenom) te quitte. Pour quelqu'un d'autre, avec qui ça durait depuis un moment. Tu es le/la dernier·e au courant.")
                poserDrapeaux(["s_est_fait_tromper", "coeur_brise"], &j)
                VieSysteme.signaler("tromperie_subie", &j)
                lignes += VieRelations.rompre(&j, parLeJoueur: false)
                return lignes
            }
        } else if !c.partenaireInfidele {
            var chance = 0.015
            if p.lien < 35 { chance += 0.05 }
            if c.tromperies > 0 { chance += 0.03 }
            if c.crise > 0 { chance += 0.04 }
            if c.relationLibre || estProtege(j) { chance = 0 }
            if VieHasard.reussi(chance) { c.partenaireInfidele = true }
            j.coeurEtat = c
        }

        // Crise et thérapie.
        c = j.coeurEtat
        if c.therapie > 0 {
            j.argent -= prixTherapie
            j.relations[i].lien = Stats.borne(j.relations[i].lien + Int.random(in: 6...12))
            c.therapie -= 1
            if VieHasard.reussi(0.5) {
                lignes.append(["Thérapie de couple : la psy vous a fait vous tenir les mains pendant dix minutes. C'était long. C'était utile.",
                               "Thérapie de couple : tu as appris à dire « je ressens » au lieu de « tu fais toujours ». Ça change tout, paraît-il.",
                               "Thérapie de couple : \(p.prenom) a pleuré, toi aussi. En sortant, vous avez partagé une crêpe. Petit pas."].auHasard(""))
            }
        }
        if c.crise > 0 {
            if c.therapie == 0 {
                j.relations[i].lien = Stats.borne(j.relations[i].lien - Int.random(in: 4...9))
                j.stats.bonheur -= 3
            }
            c.crise -= 1
            if c.crise == 0 {
                lignes.append(j.relations[i].lien >= 40
                              ? "La crise est derrière vous, \(p.prenom) et toi. Les cicatrices restent, mais vous riez de nouveau ensemble."
                              : "Vous vous êtes habitués à la crise, \(p.prenom) et toi. C'est peut-être pire.")
            }
        }
        j.coeurEtat = c

        if c.relationLibre && VieHasard.reussi(0.3) {
            let d = Int.random(in: -8...4)
            j.relations[i].lien = Stats.borne(j.relations[i].lien + d)
            lignes.append(d < 0 ? "Relation libre : \(p.prenom) a croisé ton « autre » au supermarché. Sourires très crispés au rayon fromages."
                                : "Relation libre : contre toute attente, ça vous réussit. Vous vous racontez tout, et ça vous rapproche.")
        }
        return lignes
    }

    // MARK: - Actions du menu Amour

    enum Action: Hashable {
        case voir, cadeau, weekend, rompreLiaison, quitterPourAmant, avouer
        case fouiller, detective, pardonner, quitterInfidele, therapie, relationLibre, finRelationLibre
        case reconnaitre(UUID), pension(UUID), avouerEnfant(UUID)
    }

    struct Option: Identifiable {
        let action: Action
        let titre: String
        let sousTitre: String?
        let icone: String
        let actif: Bool
        var id: Action { action }
    }

    static func optionsLiaison(_ j: Joueur) -> [Option] {
        let c = j.coeurEtat
        guard let l = c.liaison, j.partenaireActuel != nil, !j.vieEtat.justice.enPrison else { return [] }
        let p = j.partenaireActuel?.prenom ?? ""
        return [
            Option(action: .voir, titre: "Voir \(l.prenom) en cachette", sousTitre: "150 € · fait monter les soupçons", icone: "eye.slash.fill",
                   actif: c.nombreActions("voir") < 2),
            Option(action: .cadeau, titre: "Offrir un cadeau à \(l.prenom)", sousTitre: "500 € · une fois par an", icone: "gift.fill",
                   actif: c.nombreActions("cadeau") == 0),
            Option(action: .weekend, titre: "Week-end « séminaire » avec \(l.prenom)", sousTitre: "1 200 € · très risqué", icone: "suitcase.fill",
                   actif: c.nombreActions("weekend") == 0),
            Option(action: .rompreLiaison, titre: "Rompre avec \(l.prenom)", sousTitre: l.intensite >= 80 ? "\(l.prenom) risque de tout raconter" : nil,
                   icone: "heart.slash.fill", actif: true),
            Option(action: .quitterPourAmant, titre: "Quitter \(p) pour \(l.prenom)", sousTitre: j.vieEtat.statutCouple == .marie ? "divorce : tu perds la moitié de ton argent" : nil,
                   icone: "arrow.triangle.swap", actif: true),
            Option(action: .avouer, titre: "Tout avouer à \(p)", sousTitre: "plus de chances d'être pardonné·e", icone: "bubble.left.and.exclamationmark.bubble.right.fill",
                   actif: true),
        ]
    }

    static func optionsCouple(_ j: Joueur) -> [Option] {
        let c = j.coeurEtat
        guard let p = j.partenaireActuel, !j.vieEtat.justice.enPrison else { return [] }
        var o: [Option] = []
        if c.trahi {
            o.append(Option(action: .pardonner, titre: "Pardonner à \(p.prenom)", sousTitre: nil, icone: "hands.sparkles.fill", actif: true))
            o.append(Option(action: .quitterInfidele, titre: "Quitter \(p.prenom)", sousTitre: nil, icone: "door.left.hand.open", actif: true))
        }
        o.append(Option(action: .fouiller, titre: "Fouiller le téléphone de \(p.prenom)", sousTitre: "une fois par an · tu peux te faire prendre",
                        icone: "iphone.gen3", actif: c.nombreActions("fouiller") == 0))
        if c.soupconJoueur >= 30 && j.age >= 18 {
            o.append(Option(action: .detective, titre: "Engager un détective privé", sousTitre: "1 500 €", icone: "binoculars.fill",
                            actif: c.nombreActions("detective") == 0))
        }
        if c.therapie == 0 && (c.crise > 0 || p.lien < 60) && j.age >= 18 {
            o.append(Option(action: .therapie, titre: "Thérapie de couple", sousTitre: "\(Format.argent(prixTherapie)) par an pendant 2 ans", icone: "cross.case.fill", actif: true))
        }
        if j.age >= 20 {
            if c.relationLibre {
                o.append(Option(action: .finRelationLibre, titre: "Revenir à un couple exclusif", sousTitre: nil, icone: "lock.heart.fill", actif: true))
            } else {
                o.append(Option(action: .relationLibre, titre: "Proposer une relation libre", sousTitre: "une fois par an · \(p.prenom) peut mal le prendre",
                                icone: "lock.open.fill", actif: c.nombreActions("libre") == 0))
            }
        }
        return o
    }

    static func optionsEnfant(_ e: CoeurEnfantCache, _ j: Joueur) -> [Option] {
        var o: [Option] = []
        if !e.reconnu {
            o.append(Option(action: .reconnaitre(e.id), titre: "Reconnaître \(e.prenom)", sousTitre: e.revele ? nil : "ton couple va l'apprendre",
                            icone: "signature", actif: true))
            if !e.pension && e.age(j.age) < 18 {
                o.append(Option(action: .pension(e.id), titre: "Verser une pension", sousTitre: "\(Format.argent(pensionAnnuelle)) par an", icone: "eurosign.circle.fill", actif: true))
            }
            if !e.revele && j.partenaireActuel != nil {
                o.append(Option(action: .avouerEnfant(e.id), titre: "En parler à \(j.partenaireActuel?.prenom ?? "")", sousTitre: nil,
                                icone: "bubble.left.fill", actif: true))
            }
        }
        return o
    }

    /// Fait l'action et renvoie le texte (que l'appelant ajoute au journal).
    static func agir(_ action: Action, _ j: inout Joueur) -> String {
        var c = j.coeurEtat
        func payer(_ prix: Int) -> Bool {
            guard j.argent >= prix else { return false }
            j.argent -= prix
            return true
        }
        let p = j.partenaireActuel
        let nomP = p?.prenom ?? "ton/ta partenaire"
        var lignes: [String] = []

        switch action {
        case .voir:
            guard let l = c.liaison else { return "" }
            guard payer(150) else { return "Pas les moyens d'une chambre d'hôtel. Le parking du supermarché, vraiment ?" }
            c.actionsAnnee.append("voir")
            c.liaison?.intensite = Stats.borne(l.intensite + Int.random(in: 8...14))
            j.coeurEtat = c
            j.stats.bonheur += 5
            lignes.append(["Deux heures volées avec \(l.prenom). Tu rentres avec un sourire que tu dois cacher dans l'ascenseur.",
                           "Rendez-vous discret avec \(l.prenom) dans un café où personne ne te connaît. Enfin, tu crois.",
                           "Tu retrouves \(l.prenom) en douce. Tu as dit à \(nomP) que tu étais « chez le garagiste ». Ta voiture va très bien."].auHasard(""))
            lignes += ajouterSoupcon(Int.random(in: 8...18), &j)

        case .cadeau:
            guard let l = c.liaison else { return "" }
            guard payer(500) else { return "Il te faut 500 €. Un bouquet de pissenlits, ce n'est pas la même chose." }
            c.actionsAnnee.append("cadeau")
            c.liaison?.intensite = Stats.borne(l.intensite + 15)
            j.coeurEtat = c
            lignes.append("Tu offres un bracelet à \(l.prenom). Tu as payé en liquide, et caché le ticket dans une chaussette.")
            lignes += ajouterSoupcon(4, &j)

        case .weekend:
            guard let l = c.liaison else { return "" }
            guard payer(1_200) else { return "Un week-end, c'est 1 200 €. Ton « séminaire » attendra." }
            c.actionsAnnee.append("weekend")
            c.liaison?.intensite = Stats.borne(l.intensite + 20)
            j.coeurEtat = c
            j.stats.bonheur += 8
            lignes.append("Week-end « séminaire » à Biarritz avec \(l.prenom). Tu as même imprimé un faux programme pour \(nomP).")
            if VieHasard.reussi(0.18) {
                lignes.append("Mauvaise nouvelle : un collègue de \(nomP) était dans le même hôtel.")
                lignes += decouvrir(&j, aveu: false, force: true)
            } else {
                lignes += ajouterSoupcon(Int.random(in: 15...25), &j)
            }

        case .rompreLiaison:
            lignes += finirLiaison(&j, parLeJoueur: true)

        case .quitterPourAmant:
            lignes += officialiser(&j)

        case .avouer:
            lignes += decouvrir(&j, aveu: true, force: true)

        case .fouiller:
            guard p != nil else { return "" }
            c.actionsAnnee.append("fouiller")
            j.coeurEtat = c
            if c.partenaireInfidele && !c.trahi && VieHasard.reussi(0.55) {
                lignes += prendreSurLeFait(&j)
            } else if VieHasard.reussi(0.35), let i = j.relations.firstIndex(where: { $0.id == p?.id }) {
                j.relations[i].lien = Stats.borne(j.relations[i].lien - 10)
                lignes.append("\(nomP) t'a surpris\(j.g("", "e")) le téléphone à la main. « Tu cherches quoi, exactement ? » Ambiance.")
            } else {
                c = j.coeurEtat
                c.soupconJoueur = max(0, c.soupconJoueur - 10)
                j.coeurEtat = c
                lignes.append("Tu fais défiler les messages de \(nomP) : sa mère, son groupe de foot, des mèmes de chats. Rien. Tu reposes le téléphone avec un peu de honte.")
            }

        case .detective:
            guard p != nil else { return "" }
            guard payer(1_500) else { return "Le détective demande 1 500 €. Il ne fait pas crédit, il a vu trop de choses." }
            c.actionsAnnee.append("detective")
            j.coeurEtat = c
            if c.partenaireInfidele && !c.trahi && VieHasard.reussi(0.85) {
                lignes.append("Le détective pose une enveloppe sur la table. Dedans, des photos. Tu n'as pas besoin de les regarder longtemps.")
                lignes += prendreSurLeFait(&j)
            } else {
                c = j.coeurEtat
                c.soupconJoueur = 0
                j.coeurEtat = c
                lignes.append("Le détective n'a rien trouvé, à part que \(nomP) te prépare une surprise pour ton anniversaire. Tu te sens minable.")
            }

        case .pardonner:
            lignes += pardonner(&j)

        case .quitterInfidele:
            c.trahi = false
            j.coeurEtat = c
            j.stats.bonheur += 4
            lignes += VieRelations.rompre(&j, parLeJoueur: true)
            lignes.append("Tu claques la porte. Ça fait mal, mais tu gardes la tête haute.")

        case .therapie:
            guard p != nil else { return "" }
            c.therapie = 2
            j.coeurEtat = c
            VieSysteme.signaler("therapie_couple", &j)
            lignes.append("Tu proposes une thérapie de couple à \(nomP). Premier rendez-vous mardi, chez une psy qui a beaucoup de coussins.")

        case .relationLibre:
            guard let pp = p, let i = j.relations.firstIndex(where: { $0.id == pp.id }) else { return "" }
            c.actionsAnnee.append("libre")
            j.coeurEtat = c
            var chance = 0.2 + (pp.lien < 50 ? 0.1 : 0)
            if c.partenaireInfidele { chance = 0.7 }
            if VieHasard.reussi(chance) {
                c = j.coeurEtat
                c.relationLibre = true
                c.liaison?.soupcon = 0
                j.coeurEtat = c
                VieSysteme.signaler("relation_libre", &j)
                lignes.append(c.partenaireInfidele
                              ? "\(pp.prenom) accepte la relation libre. Tout de suite. Un peu trop vite, même."
                              : "\(pp.prenom) accepte la relation libre, après trois soirées de discussion et un tableau avec des règles.")
            } else {
                j.relations[i].lien = Stats.borne(pp.lien - 12)
                lignes.append("\(pp.prenom) te regarde longuement. « Il y a quelqu'un ? » La soirée est finie.")
                lignes += ajouterSoupcon(15, &j)
            }

        case .finRelationLibre:
            c.relationLibre = false
            j.coeurEtat = c
            lignes.append("Vous revenez à un couple exclusif, \(nomP) et toi. Les règles du tableau sont effacées.")

        case .reconnaitre(let id):
            lignes += enfantCache("reconnaitre", id: id, &j)
        case .pension(let id):
            lignes += enfantCache("pension", id: id, &j)
        case .avouerEnfant(let id):
            lignes += enfantCache("reveler", id: id, &j)
        }
        j.stats.borner()
        return lignes.filter { !$0.isEmpty }.joined(separator: " ")
    }
}

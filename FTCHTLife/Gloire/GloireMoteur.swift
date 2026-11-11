import Foundation

// Logique du module Gloire (docs/GLOIRE.md). Fonctions pures sur `Joueur` : le moteur (GameEngine+Gloire)
// les appelle dans `modifier`, écrit au journal et gère une éventuelle mort.

/// Résultat d'une action du module.
struct GloireResultat {
    /// false = action refusée (texte = raison), rien n'a changé.
    var ok: Bool
    var titre: String = ""
    var texte: String
    /// Lignes en plus pour le journal (nouvel ami, signaux…).
    var lignes: [String] = []
    var deces: String? = nil
    /// Proposition qui tombe juste après (accepter / refuser).
    var dilemme: GloireDilemme? = nil

    static func refus(_ texte: String) -> GloireResultat { GloireResultat(ok: false, texte: texte) }
}

enum GloireMoteur {
    static var catalogue: GloireCatalogue { GloireCatalogue.charge }

    static let prixPretePlume = 25_000
    static let prixAutoEdition = 1_500
    static let pubsParAn = 2

    static let attaches = ["Sabine « Coupe-Feu » Morel", "Kevin Buzz", "Bérénice Lacroix-Studio", "Jean-Rémi Com'",
                           "Maëlle Rideau", "Tonio Projecteur", "Capucine de Varenne", "Yanis Story"]

    // MARK: - Gloire (jauge partagée avec le module Télé)

    static func etat(_ j: Joueur) -> GloireEtat { j.gloire ?? GloireEtat() }

    /// Gloire actuelle, 0…100. Elle fond chaque année (voir TeleEtat.fonte).
    static func gloire(_ j: Joueur) -> Int { (j.tele ?? TeleEtat()).celebrite(age: j.age) }

    static func ajouterGloire(_ delta: Int, _ j: inout Joueur) {
        guard delta != 0 else { return }
        var t = j.tele ?? TeleEtat()
        t.ajouterCelebrite(delta, age: j.age)
        j.tele = t
    }

    /// Valeur de la barre « Gloire » de l'écran principal : affichée dès 10 %, ou dès qu'on a commencé à la gérer.
    static func gloireAffichee(_ j: Joueur) -> Int? {
        let g = gloire(j)
        if g >= 10 || (j.gloire != nil && g > 0) { return g }
        return nil
    }

    static func statut(_ g: Int, _ j: Joueur) -> String {
        let e = j.genre == .femme ? "e" : ""
        switch g {
        case 90...: return "Icône mondiale"
        case 75..<90: return "Superstar"
        case 60..<75: return "Star nationale"
        case 40..<60: return "Visage connu"
        case 20..<40: return "Célébrité locale"
        case 5..<20: return "Vaguement connu\(e)"
        default: return "Parfait\(e) inconnu\(e)"
        }
    }

    /// Multiplicateur des cachets selon la gloire (0,1 pour un inconnu, ~1 à 50 %, ~3 à 100 %).
    static func facteur(_ g: Int) -> Double { 0.1 + pow(Double(max(0, g)) / 50, 1.5) }

    static func valeur(_ stat: String, _ j: Joueur) -> Int {
        switch stat {
        case "apparence": return j.stats.apparence
        case "intelligence": return j.stats.intelligence
        case "bonheur": return j.stats.bonheur
        case "karma": return j.stats.karma
        case "sante": return j.stats.sante
        case "gloire": return gloire(j)
        default: return 50
        }
    }

    // MARK: - Outils

    static func texte(_ t: String, _ j: Joueur, _ vars: [String: String] = [:]) -> String {
        var s = t
        for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        s = s.replacingOccurrences(of: "{prenom}", with: j.prenom)
        s = s.replacingOccurrences(of: "{nom}", with: j.nom)
        s = s.replacingOccurrences(of: "{ville}", with: j.ville)
        s = s.replacingOccurrences(of: "{e}", with: j.genre == .femme ? "e" : "")
        return s
    }

    static func tirer(_ issues: [GloireIssue]) -> GloireIssue? {
        let total = issues.reduce(0.0) { $0 + max(0, $1.chance ?? 1) }
        guard total > 0 else { return issues.first }
        var r = Double.random(in: 0..<total)
        for i in issues {
            r -= max(0, i.chance ?? 1)
            if r < 0 { return i }
        }
        return issues.last
    }

    /// Hachage stable (contrairement à hashValue) pour garder les mêmes offres toute l'année.
    static func hache(_ s: String, _ n: Int) -> UInt64 {
        var h: UInt64 = 5381
        for u in (s + "#\(n)").unicodeScalars { h = (h &* 33) &+ UInt64(u.value) }
        return h
    }

    static func cachet(_ fourchette: [Int]?, gloire g: Int) -> Int {
        guard let f = fourchette, let mini = f.first else { return 0 }
        let maxi = max(mini, f.last ?? mini)
        return max(50, Int(Double(Int.random(in: mini...maxi)) * facteur(g)))
    }

    static func cachetEstime(_ fourchette: [Int]?, gloire g: Int) -> Int {
        guard let f = fourchette, let mini = f.first else { return 0 }
        let maxi = max(mini, f.last ?? mini)
        return max(50, Int(Double(mini + maxi) / 2 * facteur(g)))
    }

    /// Applique des effets et renvoie les lignes de journal en plus et une éventuelle cause de mort.
    static func appliquer(_ fx: GloireEffets?, _ j: inout Joueur) -> (lignes: [String], deces: String?) {
        guard let fx = fx else { return ([], nil) }
        j.stats.bonheur += fx.bonheur ?? 0
        j.stats.sante += fx.sante ?? 0
        j.stats.intelligence += fx.intelligence ?? 0
        j.stats.apparence += fx.apparence ?? 0
        j.stats.karma += fx.karma ?? 0
        j.argent += fx.argent ?? 0
        j.stats.borner()
        ajouterGloire(fx.gloire ?? 0, &j)
        var lignes: [String] = []
        if fx.nouvelAmi == true {
            let g = Genre.allCases.randomElement() ?? .homme
            let ami = Relation(prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement() ?? "Martin", genre: g, type: .ami,
                               age: max(18, j.age + Int.random(in: -6...6)), lien: Int.random(in: 45...75))
            j.relations.append(ami)
            lignes.append("Tu t'es fait " + (g == .femme ? "une nouvelle amie" : "un nouvel ami") + " dans le milieu : \(ami.prenom) \(ami.nom).")
        }
        if fx.scandale == true {
            var e = etat(j)
            e.scandales += 1
            j.gloire = e
            SignauxModules.signaler("gloire_scandale", &j)
        }
        if let s = fx.signal { SignauxModules.signaler(s, &j) }
        return (lignes, fx.deces)
    }

    static func etoiles(_ n: Int) -> String {
        String(repeating: "★", count: max(0, min(5, n))) + String(repeating: "☆", count: max(0, 5 - n))
    }

    // MARK: - Écrire un livre

    static func refusLivre(_ genre: GloireGenreLivre, _ j: Joueur) -> String? {
        if j.age < genre.ageMin { return "Dès \(genre.ageMin) ans." }
        if gloire(j) < genre.gloireMin {
            return "Aucun éditeur n'en veut tant que tu n'es pas connu\(j.genre == .femme ? "e" : "") (gloire \(genre.gloireMin) % minimum)."
        }
        if j.actionsAnnee.contains("gloire_livre") { return "Tu as déjà écrit un livre cette année. Même les génies dorment." }
        return nil
    }

    static func ecrireLivre(_ genreId: String, pretePlume: Bool, _ j: inout Joueur) -> GloireResultat {
        guard let genre = catalogue.livres.first(where: { $0.id == genreId }) else { return .refus("Ce genre n'existe pas.") }
        if let r = refusLivre(genre, j) { return .refus(r) }
        if pretePlume && !Shkurtaaa.peutPayer(prixPretePlume, solde: j.argent) {
            return .refus("Un prête-plume coûte \(Format.argent(prixPretePlume)). Tu ne les as pas.")
        }
        j.actionsAnnee.append("gloire_livre")
        let g = gloire(j)

        var q = Double(j.stats.intelligence) / 100 * 0.55 + Double.random(in: 0...0.35)
        if let c = genre.competence { q += Double(Competences.niveau(c, j)) * 0.05 }
        if pretePlume {
            q += 0.25
            j.argent -= prixPretePlume
            j.stats.karma -= 2
        }
        q = min(1, max(0, q))
        let note: Int
        switch q {
        case 0.85...: note = 5
        case 0.68..<0.85: note = 4
        case 0.5..<0.68: note = 3
        case 0.32..<0.5: note = 2
        default: note = 1
        }

        let editeur = q >= 0.3 || g >= 20
        let qualite: Double = 0.15 + q * q * 1.9
        let renom: Double = 1 + Double(g) * genre.poidsGloire / 20
        var ventes: Double = Double(genre.ventes) * qualite * renom
        ventes *= Double.random(in: 0.7...1.3)
        if !editeur {
            ventes *= 0.12
            j.argent -= prixAutoEdition
        }
        let v = max(12, Int(ventes))
        let droits = g >= 60 ? 2.5 : (g >= 25 ? 2.0 : 1.5)
        let avance = editeur ? g * g * 30 : 0
        let revenu = Int(Double(v) * droits) + avance
        j.argent += revenu

        let titre = texte(genre.titres.randomElement() ?? "Sans titre", j)
        let critiques = note >= 4 ? genre.critiquesBonnes : (note == 3 ? genre.critiquesMoyennes : genre.critiquesMauvaises)
        let critique = texte(critiques.randomElement() ?? "", j, ["titre": titre])

        let gain: Int
        switch v {
        case 200_000...: gain = 15
        case 50_000..<200_000: gain = 8
        case 10_000..<50_000: gain = 4
        case 2_000..<10_000: gain = 2
        default: gain = 1
        }
        ajouterGloire(gain, &j)
        j.stats.bonheur += note >= 4 ? 8 : (note == 3 ? 3 : -4)
        j.stats.intelligence += 2
        j.stats.borner()

        var e = etat(j)
        e.livres.append(GloireLivre(titre: titre, genre: genre.id, age: j.age, note: note, ventesAnnee: v,
                                    ventesTotales: v, revenus: revenu, droitsEuro: droits))
        j.gloire = e
        SignauxModules.signaler("livre_publie", &j)
        if v >= 100_000 { SignauxModules.signaler("best_seller", &j) }

        var t = "\(genre.emoji) Tu publies « \(titre) » (\(genre.nom.lowercased()))."
        if pretePlume { t += " Enfin, ton prête-plume l'a écrit. Toi, tu as signé." }
        if !editeur { t += " Aucun éditeur n'en a voulu : tu l'as auto-édité pour \(Format.argent(prixAutoEdition))." }
        t += " La critique : \(etoiles(note)). \(critique)"
        t += " \(v.formatted()) exemplaires vendus la première année"
        t += avance > 0 ? ", dont une avance de \(Format.argent(avance)). Tu touches \(Format.argent(revenu))." : ". Tu touches \(Format.argent(revenu))."
        if v >= 100_000 { t += " C'est un best-seller !" }
        return GloireResultat(ok: true, titre: "Écrire un livre", texte: t)
    }

    // MARK: - Publicités

    /// 4 offres au plus, les mêmes toute l'année, proches du niveau de gloire.
    static func offresPub(_ j: Joueur) -> [GloirePub] {
        let g = gloire(j)
        let eligibles = catalogue.pubs.filter { g >= $0.gloireMin && j.age >= $0.ageMin && j.age <= ($0.ageMax ?? 200) }
        let proches = eligibles.filter { $0.gloireMin >= g - 35 }
        let base = proches.count >= 3 ? proches : eligibles
        return Array(base.sorted { hache($0.id, j.age) < hache($1.id, j.age) }.prefix(4))
    }

    static func refusPub(_ p: GloirePub, _ j: Joueur) -> String? {
        if j.actionsAnnee.contains("gloire_pub_" + p.id) { return "Déjà tournée cette année." }
        if j.actionsAnnee.filter({ $0.hasPrefix("gloire_pub_") }).count >= pubsParAn {
            return "Deux pubs par an, pas plus : ton agent dit que le public va se lasser de ta tête."
        }
        return nil
    }

    static func tournerPub(_ id: String, _ j: inout Joueur) -> GloireResultat {
        guard let p = catalogue.pubs.first(where: { $0.id == id }) else { return .refus("Cette offre n'existe plus.") }
        if let r = refusPub(p, j) { return .refus(r) }
        j.actionsAnnee.append("gloire_pub_" + p.id)
        let montant = cachet(p.cachet, gloire: gloire(j))
        j.argent += montant
        if p.louche == true { j.stats.karma -= 4 }
        var e = etat(j)
        e.pubs += 1
        e.revenusPubs += montant
        j.gloire = e

        let vars = ["marque": p.marque, "produit": p.produit, "cachet": Format.argent(montant)]
        let rate = Double.random(in: 0...1) < (p.risque ?? 0)
        var r = GloireResultat(ok: true, titre: "\(p.emoji) Pub \(p.marque)", texte: "")
        if rate {
            r.texte = texte(p.textesRates?.randomElement() ?? "La pub pour {marque} tourne au fiasco.", j, vars)
            let fx = appliquer(p.effetsRates, &j)
            r.lignes = fx.lignes
            r.deces = fx.deces
            SignauxModules.signaler("pub_ratee", &j)
        } else {
            r.texte = texte(p.textes.randomElement() ?? "Tu tournes la pub pour {marque} et tu touches {cachet}.", j, vars)
            ajouterGloire(p.gloire, &j)
            j.stats.bonheur += 3
            SignauxModules.signaler("pub_tournee", &j)
        }
        r.texte = "\(p.emoji) " + r.texte
        return r
    }

    // MARK: - Fêtes, séances photo, plateaux télé

    static func typeActivite(_ id: String) -> String {
        if catalogue.fetes.contains(where: { $0.id == id }) { return "fete" }
        if catalogue.shootings.contains(where: { $0.id == id }) { return "shooting" }
        return "plateau"
    }

    static func refusActivite(_ a: GloireActivite, _ j: Joueur) -> String? {
        if j.age < a.ageMin { return "Dès \(a.ageMin) ans." }
        if gloire(j) < a.gloireMin {
            return "Personne ne t'y invite encore : il faut une gloire de \(a.gloireMin) % au moins."
        }
        if j.actionsAnnee.contains("gloire_act_" + a.id) { return "Déjà fait cette année." }
        if a.prix > 0 && !Shkurtaaa.peutPayer(a.prix, solde: j.argent) { return "Il te faut \(Format.argent(a.prix))." }
        return nil
    }

    /// Chance de réussir une activité (0…1).
    static func chance(_ a: GloireActivite, _ j: Joueur) -> Double {
        let base: Double = 0.3 + Double(valeur(a.stat, j)) / 100 * 0.55
        let bonus: Double = Double(gloire(j)) / 500
        return min(0.92, max(0.12, base + bonus))
    }

    static func faire(_ id: String, _ j: inout Joueur) -> GloireResultat {
        guard let a = catalogue.activite(id) else { return .refus("Cette activité n'existe plus.") }
        if let r = refusActivite(a, j) { return .refus(r) }
        j.actionsAnnee.append("gloire_act_" + a.id)
        j.argent -= a.prix
        var e = etat(j)
        switch typeActivite(a.id) {
        case "fete": e.fetes += 1
        case "shooting": e.shootings += 1
        default: e.plateaux += 1
        }
        j.gloire = e

        let g = gloire(j)
        let reussi = Double.random(in: 0...1) < chance(a, j)
        let montant = reussi ? cachet(a.cachet, gloire: g) : 0
        j.argent += montant
        let issue = tirer(reussi ? a.succes : a.rates)
        var r = GloireResultat(ok: true, titre: "\(a.emoji) \(a.nom)",
                               texte: "\(a.emoji) " + texte(issue?.texte ?? "", j, ["cachet": Format.argent(montant)]))
        let fx = appliquer(issue?.effets, &j)
        r.lignes = fx.lignes
        r.deces = fx.deces
        SignauxModules.signaler("gloire_" + typeActivite(a.id), &j)
        if fx.deces == nil, var d = (a.dilemmes ?? []).first(where: { Double.random(in: 0...1) < $0.chance }) {
            d.texte = texte(d.texte, j)
            r.dilemme = d
        }
        return r
    }

    static func trancher(_ d: GloireDilemme, accepte: Bool, _ j: inout Joueur) -> GloireResultat {
        let issue = tirer(accepte ? d.siAccepte : d.siRefuse)
        var r = GloireResultat(ok: true, titre: accepte ? d.accepter : d.refuser, texte: texte(issue?.texte ?? "", j))
        let fx = appliquer(issue?.effets, &j)
        r.lignes = fx.lignes
        r.deces = fx.deces
        return r
    }

    // MARK: - Attaché de presse

    static func coutAttache(_ j: Joueur) -> Int { 15_000 + gloire(j) * 1_200 }

    static func engagerAttache(_ j: inout Joueur) -> GloireResultat {
        var e = etat(j)
        if e.attachePresse { return .refus("Tu as déjà un·e attaché·e de presse.") }
        if j.age < 16 { return .refus("Dès 16 ans.") }
        let cout = coutAttache(j)
        guard Shkurtaaa.peutPayer(cout, solde: j.argent) else { return .refus("Il faut \(Format.argent(cout)) par an.") }
        j.argent -= cout
        let nom = attaches.randomElement() ?? "Kevin Buzz"
        e.attachePresse = true
        e.attacheNom = nom
        j.gloire = e
        ajouterGloire(4, &j)
        return GloireResultat(ok: true, titre: "Attaché de presse",
                              texte: "🤵 Tu engages \(nom) comme attaché·e de presse, pour \(Format.argent(cout)) par an. Premier conseil : « Ne réponds plus jamais toi-même à un journaliste. »")
    }

    static func renvoyerAttache(_ j: inout Joueur) -> GloireResultat {
        var e = etat(j)
        guard e.attachePresse else { return .refus("Tu n'as pas d'attaché·e de presse.") }
        let nom = e.attacheNom ?? "Ton attaché·e de presse"
        e.attachePresse = false
        e.attacheNom = nil
        j.gloire = e
        return GloireResultat(ok: true, titre: "Attaché de presse",
                              texte: "🤵 Tu te sépares de \(nom). Ton téléphone sonne moins. C'est reposant, et un peu vexant.")
    }

    // MARK: - Année

    static func passerAnnee(_ j: inout Joueur) -> [String] {
        guard var e = j.gloire else { return [] }
        var lignes: [String] = []
        var bonus = 0

        var droits = 0
        for i in e.livres.indices {
            var l = e.livres[i]
            guard l.ventesAnnee > 30 else { continue }
            let v = Int(Double(l.ventesAnnee) * Double.random(in: 0.3...0.55))
            l.ventesAnnee = v
            l.ventesTotales += v
            let r = Int(Double(v) * l.droitsEuro)
            l.revenus += r
            droits += r
            if !l.adapte && l.ventesTotales >= 150_000 && Double.random(in: 0...1) < 0.1 {
                l.adapte = true
                let film = max(50_000, l.ventesTotales)
                j.argent += film
                l.revenus += film
                bonus += 6
                lignes.append("🎬 Un studio achète les droits de « \(l.titre) » pour \(Format.argent(film)). Ton livre va devenir un film.")
            }
            e.livres[i] = l
        }
        if droits >= 300 {
            j.argent += droits
            lignes.append("📚 Droits d'auteur de l'année : \(Format.argent(droits)).")
        }

        if e.attachePresse {
            let cout = coutAttache(j)
            let nom = e.attacheNom ?? "Ton attaché·e de presse"
            if Shkurtaaa.peutPayer(cout, solde: j.argent) {
                j.argent -= cout
                bonus += 5
                lignes.append("🤵 \(nom) entretient ta gloire (\(Format.argent(cout)) d'honoraires).")
            } else {
                e.attachePresse = false
                e.attacheNom = nil
                lignes.append("🤵 Tu ne peux plus payer \(nom), qui part s'occuper d'un candidat de téléréalité.")
            }
        }
        j.gloire = e
        ajouterGloire(bonus, &j)

        let g = gloire(j)
        if g >= 70 && Double.random(in: 0...1) < 0.25 {
            lignes.append(["📬 Tu reçois des centaines de lettres de fans. L'une d'elles contient une mèche de cheveux. Tu préfères ne pas savoir de qui.",
                           "📸 Des paparazzis campent devant chez toi. Ton voisin leur vend des cafés.",
                           "🗞️ Un magazine people publie ton « régime secret ». Tu ne fais aucun régime."].randomElement() ?? "")
        }
        return lignes
    }

    // MARK: - Tags

    static func tags(_ j: Joueur) -> Set<String> {
        var t: Set<String> = []
        let g = gloire(j)
        if g >= 40 { t.insert("gloire_celebre") }
        if g >= 75 { t.insert("gloire_superstar") }
        if let e = j.gloire {
            if !e.livres.isEmpty { t.insert("auteur_publie") }
            if e.livres.contains(where: { $0.ventesTotales >= 100_000 }) { t.insert("best_seller") }
            if e.attachePresse { t.insert("attache_presse") }
            if e.proces.contains(where: { $0.issue == "gagne" }) { t.insert("a_gagne_proces") }
            if e.proces.contains(where: { $0.issue == "perdu" }) { t.insert("a_perdu_proces") }
        }
        return t
    }
}

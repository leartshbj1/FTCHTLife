import Foundation

// Logique du téléphone. Toutes les fonctions modifient un Joueur et un PhoneEtat passés en inout ;
// c'est l'appelant qui range l'état dans `joueur.telephone` (voir docs/PHONE.md).

@MainActor
enum PhoneEngine {

    static let postsParAnEtParAppli = 3
    static let swipesParAn = 20
    static let rendezVousParAn = 3
    static let maxContrats = 3
    static let paliers = [1_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000]
    static let seuilCertification = 100_000

    // MARK: - Tags et infos

    /// Tags à ajouter à GameEngine.tags(_:) : phone, influencer, star_reseaux, bad_buzz, sponsorise.
    static func tags(_ t: PhoneEtat?) -> Set<String> {
        guard let t = t, t.aTelephone else { return [] }
        var s: Set<String> = ["phone"]
        let total = t.abonnesTotal
        if total >= 10_000 { s.insert("influencer") }
        if total >= 1_000_000 { s.insert("star_reseaux") }
        if t.badBuzzRestant > 0 { s.insert("bad_buzz") }
        if !t.contrats.isEmpty { s.insert("sponsorise") }
        return s
    }

    /// Nombre de messages non lus (pour une pastille).
    static func nonLus(_ t: PhoneEtat?) -> Int { t?.nonLus ?? 0 }

    static func postsRestants(_ app: PhoneApp, _ t: PhoneEtat) -> Int {
        max(0, postsParAnEtParAppli - (t.postsAnnee[app.rawValue] ?? 0))
    }

    // MARK: - Obtenir un téléphone

    static let phrasesCadeau = [
        "📱 Tes parents t'offrent ton premier téléphone. L'écran est déjà fissuré, « comme ça tu ne le casseras pas ».",
        "📱 Tu reçois ton premier téléphone : l'ancien de {parent}, avec 412 photos de son jardin dedans.",
        "📱 Premier téléphone ! Tes parents ont activé le contrôle parental. Tu l'as désactivé en 4 minutes.",
        "📱 Tu as enfin un téléphone. Ton pouce découvre sa vraie vocation.",
    ]

    /// Donne le téléphone (cadeau à 13 ans, ou achat si on le demande plus tard).
    static func obtenirTelephone(_ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine, achat: Bool) -> String {
        guard !t.aTelephone else { return "Tu as déjà un téléphone. Il est dans ta main. Regarde." }
        guard j.age >= 13 else { return "Tes parents ont dit : « Pas de téléphone avant 13 ans. » Ils ont dit ça très fort." }
        if achat && j.age >= 18 {
            let prix = 250
            guard j.argent >= prix else { return "Il te faut \(Format.argent(prix)) pour un téléphone d'occasion. Même celui avec la touche 7 qui colle." }
            j.argent -= prix
            t.aTelephone = true
            ajouterMessageBienvenue(&j, &t, engine: engine)
            return "Tu achètes un téléphone d'occasion pour \(Format.argent(prix)). Le vendeur jure qu'il n'a « presque pas été mouillé »."
        }
        t.aTelephone = true
        ajouterMessageBienvenue(&j, &t, engine: engine)
        return engine.remplir(phrasesCadeau.randomElement()!, j)
    }

    private static func ajouterMessageBienvenue(_ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) {
        let expediteur = j.mere?.vivant == true ? (j.mere?.prenom ?? "Maman") + " (Maman)" : "Numéro inconnu"
        let texte = j.mere?.vivant == true
            ? "C'EST MAMAN. TU AS BIEN REÇU LE TÉLÉPHONE ? RÉPONDS. JE VOIS QUE TU AS LU. 👍👍👍🐟"
            : "Bienvenue sur ton nouveau téléphone ! Ceci n'est pas une arnaque. (C'est un peu une arnaque.)"
        t.messages.append(PhoneMessage(modeleId: nil, sponsorId: nil, expediteur: expediteur,
                                       categorie: "famille", texte: texte, age: j.age))
    }

    // MARK: - Une année passe

    /// À appeler dans GameEngine.vieillir() : renvoie les lignes à ajouter au journal de l'année.
    static func passerAnnee(_ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) -> [String] {
        var lignes: [String] = []
        defer {
            t.postsAnnee = [:]
            t.actionsAnnee = []
        }
        guard j.vivant else { return lignes }

        if !t.aTelephone {
            if j.age >= 13 {
                lignes.append(obtenirTelephone(&j, &t, engine: engine, achat: false))
            }
            return lignes
        }

        if t.badBuzzRestant > 0 { t.badBuzzRestant -= 1 }
        let detox = t.detoxCetteAnnee
        t.detoxCetteAnnee = false
        let totalPosts = t.postsAnnee.values.reduce(0, +)

        // Évolution des comptes.
        for app in PhoneApp.reseaux {
            guard var c = t.comptes[app.rawValue] else { continue }
            let a = Double(c.abonnes)
            let posts = t.postsAnnee[app.rawValue] ?? 0
            if posts == 0 {
                c.abonnes = max(0, c.abonnes - Int(a * Double.random(in: 0.03...0.12)))
            } else {
                c.abonnes += Int(a * Double.random(in: 0...0.02) * Double(posts))
            }
            if c.fauxAbonnes > 0 && Double.random(in: 0...1) < 0.25 {
                let perte = min(c.abonnes, c.fauxAbonnes + Int(Double(c.abonnes) * 0.1))
                c.abonnes -= perte
                c.fauxAbonnes = 0
                j.stats.karma -= 5
                j.stats.bonheur -= 6
                t.badBuzzRestant = 2
                lignes.append("📱 Scandale sur \(app.nom) : un journaliste a prouvé que tes abonnés venaient d'une ferme à clics. Tu perds \(PhoneFormat.nombre(perte)) abonnés et un peu de dignité.")
            }
            if !c.certifie && c.abonnes >= seuilCertification {
                c.certifie = true
                lignes.append("📱 Ton compte \(app.nom) est certifié ✓. Ta mère l'a annoncé à toute la boulangerie.")
            }
            t.comptes[app.rawValue] = c
        }

        // Revenus de Trémousse.
        let tre = t.compte(.tremousse).abonnes
        if tre >= 10_000 {
            let revenu = Int(Double(tre) * Double.random(in: 0.002...0.006))
            if revenu > 0 {
                j.argent += revenu
                lignes.append("📱 Trémousse te verse \(Format.argent(revenu)) pour tes vidéos. Tu appelles ça « mon salaire » devant tes oncles.")
            }
        }

        // Contrats de sponsors.
        var restants: [PhoneContrat] = []
        for contrat in t.contrats {
            guard let sp = PhoneBibliotheque.sponsor(contrat.sponsorId) else { continue }
            if Double.random(in: 0...1) < sp.louche * 0.35 {
                let app = t.appPrincipale
                var c = t.compte(app)
                let perte = Int(Double(c.abonnes) * Double.random(in: 0.08...0.2))
                c.abonnes -= perte
                t.comptes[app.rawValue] = c
                j.stats.karma -= 6
                j.stats.bonheur -= 8
                t.badBuzzRestant = 2
                lignes.append("📱 Bad buzz : " + remplir(sp.scandale, j, engine: engine, extra: ["marque": sp.marque]) + " Contrat terminé, \(PhoneFormat.nombre(perte)) abonnés partis.")
                continue
            }
            let paiement = paiementSponsor(sp, t, bonus: contrat.bonus)
            j.argent += paiement
            lignes.append("📱 \(sp.marque) te verse \(Format.argent(paiement)) pour ton partenariat.")
            restants.append(contrat)
        }
        t.contrats = restants

        // Offres de sponsors.
        if !detox && t.contrats.count < maxContrats && Double.random(in: 0...1) < 0.6 {
            let total = t.abonnesTotal
            let dejaProposes = Set(t.messages.compactMap { $0.reponse == nil ? $0.sponsorId : nil })
            let possibles = PhoneBibliotheque.sponsors.filter { sp in
                total >= sp.minAbonnes && j.age >= (sp.minAge ?? 16)
                    && !t.sponsorsVus.contains(sp.id) && !dejaProposes.contains(sp.id)
                    && (sp.app == nil || sp.app == "any" || t.compte(PhoneApp(rawValue: sp.app!) ?? .pozz).abonnes >= sp.minAbonnes)
            }
            if let sp = possibles.randomElement() {
                t.sponsorsVus.append(sp.id)
                let texte = remplir(sp.offre, j, engine: engine,
                                    extra: ["marque": sp.marque, "montant": Format.argent(paiementSponsor(sp, t, bonus: 1))])
                t.messages.append(PhoneMessage(modeleId: nil, sponsorId: sp.id, expediteur: sp.marque,
                                               categorie: "pro", texte: texte, age: j.age))
            }
        }

        // Nouveaux messages.
        if !detox {
            let nombre = Int.random(in: 1...3)
            for _ in 0..<nombre {
                guard let m = tirerMessage(j, t, engine: engine) else { break }
                if m.unique == true { t.messagesVus.append(m.id) }
                let extra = ["app": (PhoneApp(rawValue: m.app ?? "") ?? t.appPrincipale).nom,
                             "abonnes": PhoneFormat.nombre(t.abonnesTotal)]
                t.messages.append(PhoneMessage(modeleId: m.id, sponsorId: nil,
                                               expediteur: remplir(m.expediteur, j, engine: engine, extra: extra),
                                               categorie: m.categorie,
                                               texte: remplir(m.text, j, engine: engine, extra: extra),
                                               age: j.age))
            }
            let nouveaux = t.messages.filter { !$0.lu && $0.age == j.age }.count
            if nouveaux > 0 {
                lignes.append("📱 Tu as \(nouveaux) nouveau\(nouveaux > 1 ? "x" : "") message\(nouveaux > 1 ? "s" : "") sur ton téléphone.")
            }
        }
        nettoyerMessages(&t)

        // Paliers d'abonnés.
        let total = t.abonnesTotal
        t.recordAbonnes = max(t.recordAbonnes, total)
        while t.paliersAnnonces < paliers.count && total >= paliers[t.paliersAnnonces] {
            lignes.append("📱 " + phrasePalier(t.paliersAnnonces, j))
            j.stats.bonheur += 4
            t.paliersAnnonces += 1
        }

        // Temps d'écran.
        if totalPosts >= 7 {
            j.stats.bonheur -= 2
            j.stats.intelligence -= 1
            lignes.append("📱 " + ["Ton temps d'écran moyen : 9 h par jour. Ton pouce a des abdos.",
                                  "Tu as regardé ton téléphone 214 fois par jour. Il commence à te trouver collant.",
                                  "Tu rêves en format vertical maintenant."].randomElement()!)
        }
        j.stats.borner()
        return lignes
    }

    private static func phrasePalier(_ i: Int, _ j: Joueur) -> String {
        switch i {
        case 0: return "Tu passes les 1 000 abonnés ! Dont 300 tantes, 200 bots et un inconnu très motivé."
        case 1: return "10 000 abonnés ! On te reconnaît à la boulangerie. Enfin, la boulangère te reconnaît."
        case 2: return "100 000 abonnés ! Tu dis « ma communauté » sans rire."
        case 3: return "UN MILLION d'abonnés ! Tu es une star. Ta grand-mère imprime tes posts."
        case 4: return "10 millions d'abonnés. Des inconnus tatouent ta tête. Pas très bien."
        default: return "100 millions d'abonnés. Tu es plus suivi" + (j.genre == .femme ? "e" : "") + " que la météo."
        }
    }

    private static func nettoyerMessages(_ t: inout PhoneEtat) {
        // On garde au plus 40 messages : les plus anciens déjà traités partent d'abord.
        while t.messages.count > 40 {
            if let i = t.messages.firstIndex(where: { $0.lu && ($0.reponse != nil || $0.modeleId == nil && $0.sponsorId == nil) }) {
                t.messages.remove(at: i)
            } else {
                t.messages.removeFirst()
            }
        }
        if t.publications.count > 60 { t.publications.removeFirst(t.publications.count - 60) }
    }

    static func paiementSponsor(_ sp: PhoneSponsor, _ t: PhoneEtat, bonus: Double) -> Int {
        let base = Double(t.abonnesTotal) * sp.tarif * bonus
        return max(Int(Double(sp.minPaiement) * bonus), Int(base))
    }

    // MARK: - Conditions

    static func conditionsOK(_ c: ConditionsEvenement?, _ j: Joueur, tags: Set<String>) -> Bool {
        guard let c = c else { return true }
        if c.gender == "male" && j.genre != .homme { return false }
        if c.gender == "female" && j.genre != .femme { return false }
        if let m = c.minMoney, j.argent < m { return false }
        if let m = c.maxMoney, j.argent > m { return false }
        if let r = c.requiresJob, r != tags.contains("job") { return false }
        if let r = c.requiresPartner, r != tags.contains("partner") { return false }
        if let r = c.requiresSchool, r != (tags.contains("school") || tags.contains("university")) { return false }
        if let r = c.tags, !Set(r).isSubset(of: tags) { return false }
        if let x = c.excludeTags, !Set(x).isDisjoint(with: tags) { return false }
        return true
    }

    private static func tousLesTags(_ j: Joueur, _ t: PhoneEtat, engine: GameEngine) -> Set<String> {
        engine.tags(j).union(tags(t))
    }

    private static func tirerMessage(_ j: Joueur, _ t: PhoneEtat, engine: GameEngine) -> PhoneMessageModele? {
        let tg = tousLesTags(j, t, engine: engine)
        let total = t.abonnesTotal
        let enAttente = Set(t.messages.compactMap { $0.reponse == nil ? $0.modeleId : nil })
        let candidats = PhoneBibliotheque.messages.filter { m in
            j.age >= (m.minAge ?? 13) && j.age <= (m.maxAge ?? 120)
                && total >= (m.minAbonnes ?? 0)
                && !(m.unique == true && t.messagesVus.contains(m.id))
                && !enAttente.contains(m.id)
                && conditionsOK(m.conditions, j, tags: tg)
        }
        return GameEngine.tirage(candidats) { m in
            var w = m.weight ?? 1
            // Les haters se réveillent après un bad buzz.
            if m.categorie == "hater" && t.badBuzzRestant > 0 { w *= 3 }
            return w
        }
    }

    // MARK: - Textes

    /// Remplace les variables du téléphone ({app}, {abonnes}, {gain}, {marque}, {montant}, {match}) puis celles du moteur.
    static func remplir(_ texte: String, _ j: Joueur, engine: GameEngine, extra: [String: String] = [:]) -> String {
        var s = texte
        for (cle, valeur) in extra {
            s = s.replacingOccurrences(of: "{\(cle)}", with: valeur)
        }
        return engine.remplir(s, j)
    }

    // MARK: - Publier

    /// Types de post proposés au joueur pour une appli.
    static func postsDisponibles(_ app: PhoneApp, _ j: Joueur, _ t: PhoneEtat, engine: GameEngine) -> [PhonePostModele] {
        let tg = tousLesTags(j, t, engine: engine)
        return PhoneBibliotheque.posts.filter { m in
            m.app == app.rawValue && j.age >= (m.minAge ?? 13) && j.age <= (m.maxAge ?? 120)
                && conditionsOK(m.conditions, j, tags: tg)
        }
    }

    /// Raison pour laquelle on ne peut pas publier, ou nil si c'est possible.
    static func blocagePublication(_ m: PhonePostModele, _ j: Joueur, _ t: PhoneEtat) -> String? {
        guard let app = PhoneApp(rawValue: m.app) else { return "Cette appli n'existe plus." }
        if !t.aTelephone { return "Il te faut un téléphone." }
        if !j.vivant { return "Les morts ne postent pas. Enfin, pas encore." }
        if j.age < app.ageMin { return "\(app.nom) est interdit aux moins de \(app.ageMin) ans." }
        if t.detoxCetteAnnee { return "Tu es en détox numérique cette année. Courage." }
        if postsRestants(app, t) == 0 { return "Tu as déjà posté \(postsParAnEtParAppli) fois sur \(app.nom) cette année. Laisse respirer tes abonnés." }
        if let cout = m.cout, cout > 0, j.argent < cout { return "Il te faut \(Format.argent(cout)) pour ce post." }
        return nil
    }

    /// Publie un post et renvoie la publication (nil si impossible).
    static func publier(_ m: PhonePostModele, _ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) -> PhonePublication? {
        guard blocagePublication(m, j, t) == nil, let app = PhoneApp(rawValue: m.app) else { return nil }
        var c = t.compte(app)
        let a = Double(c.abonnes)

        let valeurStat: Int
        switch m.stat {
        case "looks": valeurStat = j.stats.apparence
        case "smarts": valeurStat = j.stats.intelligence
        case "happiness": valeurStat = j.stats.bonheur
        case "karma": valeurStat = j.stats.karma
        default: valeurStat = 50
        }
        let qualite = 0.55 * Double(valeurStat) / 100 + 0.45 * Double.random(in: 0...1)
        let pBad = min(0.6, m.risque * (1.5 - Double(j.stats.karma) / 100) + (c.certifie ? 0.02 : 0))
        let pBuzz = min(0.25, (0.01 + 0.05 * qualite) * m.viralite * (app == .tremousse ? 1.3 : 1))
        let r = Double.random(in: 0..<1)

        let palier: String
        if r < pBad { palier = "badbuzz" }
        else if r < pBad + pBuzz { palier = "buzz" }
        else if qualite < 0.35 { palier = "flop" }
        else if qualite < 0.65 { palier = "moyen" }
        else { palier = "succes" }

        var gain: Int
        switch palier {
        case "flop":
            gain = Int.random(in: 0...3) + Int(a * Double.random(in: -0.01...0.005))
            j.stats.bonheur -= 2
        case "moyen":
            gain = Int.random(in: 3...25) + Int(a * Double.random(in: 0.005...0.02))
            j.stats.bonheur += 1
        case "succes":
            gain = Int.random(in: 15...120) + Int(a * Double.random(in: 0.02...0.07))
            j.stats.bonheur += 4
        case "buzz":
            gain = Int(Double(Int.random(in: 1_000...25_000)) * m.viralite) + Int(a * Double.random(in: 0.1...0.5))
            j.stats.bonheur += 10
        default:
            gain = -(Int.random(in: 0...20) + Int(a * Double.random(in: 0.1...0.3)))
            j.stats.bonheur -= 10
            j.stats.karma -= 3
            t.badBuzzRestant = 2
        }
        if c.abonnes + gain < 0 { gain = -c.abonnes }
        c.abonnes += gain
        c.posts += 1
        t.comptes[app.rawValue] = c
        t.postsAnnee[app.rawValue, default: 0] += 1
        t.recordAbonnes = max(t.recordAbonnes, t.abonnesTotal)
        if let cout = m.cout, cout > 0 { j.argent -= cout }

        var likes = Int(Double(c.abonnes) * Double.random(in: 0.02...0.12)) + Int.random(in: 0...12)
        if palier == "buzz" { likes = likes * 8 + Int.random(in: 1_000...20_000) }
        if palier == "flop" { likes = min(likes, Int.random(in: 0...4)) }

        let extra = ["app": app.nom, "abonnes": PhoneFormat.nombre(c.abonnes), "gain": PhoneFormat.nombre(abs(gain))]
        let phrases = m.textes[palier] ?? []
        let texte = remplir(phrases.randomElement() ?? "Il se passe… des choses.", j, engine: engine, extra: extra)
        let pub = PhonePublication(app: app, titre: m.titre, icone: m.icone, palier: palier, gain: gain, likes: likes,
                                   texte: texte, commentaires: commentaires(palier: palier, app: app, abonnes: c.abonnes, j: j, engine: engine),
                                   age: j.age)
        t.publications.append(pub)
        nettoyerMessages(&t)

        let resume: String
        switch palier {
        case "buzz": resume = "🔥 BUZZ sur \(app.nom) avec « \(m.titre) » ! "
        case "badbuzz": resume = "💥 Bad buzz sur \(app.nom) avec « \(m.titre) ». "
        default: resume = "📱 Tu postes « \(m.titre) » sur \(app.nom). "
        }
        engine.ajouterLigne(&j, resume + texte)
        j.stats.borner()
        return pub
    }

    static let suffixesPseudo = ["_officiel", "_du_canape", "2008", "_sans_filtre", "xx", "_lol", "_42", "_pas_un_bot",
                                 "_le_vrai", "_en_vrai", "_75cl", "_moustache", "_croquette", "_turbo", "_zen", "99"]

    private static func pseudo(_ type: String, _ j: Joueur) -> String {
        switch type {
        case "famille":
            let famille = j.relations.filter { $0.vivant && ($0.type.estParent || $0.type == .frere || $0.type == .soeur) }
            if let r = famille.randomElement() {
                return r.type == .mere ? "Maman (\(r.prenom))" : r.type == .pere ? "Papa (\(r.prenom))" : r.prenom
            }
            return ["Tata Josiane", "Tonton Gérard", "Mamie", "Cousin Kevin"].randomElement()!
        case "bot":
            return ["gagne_un_iphone_" + String(Int.random(in: 100...999)), "crypto_reine_" + String(Int.random(in: 10...99)),
                    "user" + String(Int.random(in: 10_000_000...99_999_999))].randomElement()!
        default:
            let g = Genre.allCases.randomElement()!
            let base = Donnees.prenom(g).lowercased()
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: " ", with: "_")
            return base + suffixesPseudo.randomElement()!
        }
    }

    private static func commentaires(palier: String, app: PhoneApp, abonnes: Int, j: Joueur, engine: GameEngine) -> [String] {
        let types: [String]
        switch palier {
        case "flop": types = ["bot", "famille", "bizarre"]
        case "moyen": types = ["fan", "famille", "bizarre", "bot"]
        case "succes": types = ["fan", "fan", "bizarre", "hater"]
        case "buzz": types = ["fan", "fan", "hater", "bizarre"]
        default: types = ["hater", "hater", "hater", "bizarre", "famille"]
        }
        var resultat: [String] = []
        var deja: Set<String> = []
        let nombre = palier == "flop" ? Int.random(in: 0...2) : Int.random(in: 2...4)
        for _ in 0..<nombre {
            let type = types.randomElement()!
            let possibles = PhoneBibliotheque.commentaires.filter {
                $0.type == type && !deja.contains($0.id) && abonnes >= ($0.minAbonnes ?? 0)
                    && ($0.app == nil || $0.app == "any" || $0.app == app.rawValue)
            }
            guard let c = possibles.randomElement() else { continue }
            deja.insert(c.id)
            resultat.append(pseudo(type, j) + " : " + remplir(c.texte, j, engine: engine, extra: ["app": app.nom]))
        }
        return resultat
    }

    // MARK: - Autres actions des réseaux

    static let prixFauxAbonnes = 300
    static let nombreFauxAbonnes = 5_000

    static func acheterFauxAbonnes(_ app: PhoneApp, _ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) -> String {
        let cle = "faux_" + app.rawValue
        guard t.aTelephone, app != .pecho else { return "Impossible." }
        guard j.age >= 16 else { return "Le vendeur d'abonnés demande une carte bancaire. Celle de tes parents ne compte pas." }
        guard t.nombreActions(cle) == 0 else { return "Tu en as déjà acheté cette année. Même les bots ont des limites." }
        guard j.argent >= prixFauxAbonnes else { return "Il te faut \(Format.argent(prixFauxAbonnes)). Les faux abonnés, eux, ne sont pas gratuits." }
        j.argent -= prixFauxAbonnes
        var c = t.compte(app)
        c.abonnes += nombreFauxAbonnes
        c.fauxAbonnes += nombreFauxAbonnes
        t.comptes[app.rawValue] = c
        t.actionsAnnee.append(cle)
        j.stats.karma -= 2
        let texte = "Tu achètes \(PhoneFormat.nombre(nombreFauxAbonnes)) abonnés sur \(app.nom). Ils s'appellent tous « user48213… » et adorent tout ce que tu fais. Si quelqu'un le découvre, ça va piquer."
        engine.ajouterLigne(&j, "📱 " + texte)
        j.stats.borner()
        return texte
    }

    static func peutFaireLive(_ j: Joueur, _ t: PhoneEtat) -> Bool {
        t.aTelephone && !t.detoxCetteAnnee && t.compte(.tremousse).abonnes >= 500 && t.nombreActions("live") == 0
    }

    static func lancerLive(_ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) -> String {
        guard peutFaireLive(j, t) else {
            return "Il faut au moins 500 abonnés sur Trémousse pour un live, et un seul live par an."
        }
        t.actionsAnnee.append("live")
        var c = t.compte(.tremousse)
        let a = Double(c.abonnes)
        let dons = Int(a * Double.random(in: 0.001...0.01)) + Int.random(in: 0...50)
        let gain = Int(a * Double.random(in: 0...0.05))
        c.abonnes += gain
        t.comptes[PhoneApp.tremousse.rawValue] = c
        if j.age >= 16 { j.argent += dons }
        j.stats.bonheur += 3
        let anecdote = engine.remplir([
            "{parent} a traversé le champ de la caméra en peignoir. Tout le monde l'a vu. Tout le monde.",
            "Tu as parlé 2 heures à 4 personnes, dont un chat qui a marché sur le clavier.",
            "Tu as fait un live cuisine. Les pompiers ont rejoint le chat.",
            "Quelqu'un a demandé « c quoi ta routine » 340 fois. Tu as répondu « dormir » 340 fois.",
            "Un viewer t'a envoyé un don accompagné du message « pour ta coupe de cheveux ». Tu ne sais pas si c'est gentil.",
            "Ton wifi a coupé au meilleur moment. Le chat a cru que tu étais mort{e}.",
        ].randomElement()!, j)
        var texte = "Live sur Trémousse ! " + anecdote
        if j.age >= 16 {
            texte += " Dons reçus : \(Format.argent(dons))."
        } else {
            texte += " Les dons sont allés sur la carte de tes parents. Ils ne sont pas au courant."
        }
        if gain > 0 { texte += " +\(PhoneFormat.nombre(gain)) abonnés." }
        engine.ajouterLigne(&j, "📱 " + texte)
        j.stats.borner()
        return texte
    }

    static func detox(_ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) -> String {
        guard t.aTelephone, !t.detoxCetteAnnee else { return "Tu es déjà en détox. Repose ce téléphone." }
        t.detoxCetteAnnee = true
        j.stats.bonheur += 8
        j.stats.intelligence += 2
        j.stats.sante += 2
        let texte = ["Détox numérique ! Tu as découvert que les arbres existent en vrai, et en 3D.",
                     "Détox numérique : tu as lu un livre. Il n'avait pas de bouton « passer ».",
                     "Détox numérique. Tes abonnés vont t'oublier un peu, ta mère va enfin te voir de face."].randomElement()!
        engine.ajouterLigne(&j, "📵 " + texte)
        j.stats.borner()
        return texte
    }

    // MARK: - Messagerie

    /// Libellés des réponses possibles à un message.
    static func choix(_ m: PhoneMessage) -> [String] {
        if m.reponse != nil { return [] }
        if m.sponsorId != nil { return ["Signer", "Négocier", "Refuser"] }
        if let id = m.modeleId, let modele = PhoneBibliotheque.message(id) { return modele.choices.map { $0.label } }
        return ["Répondre « ok »", "Laisser en vu"]
    }

    static func marquerLu(_ id: UUID, _ t: inout PhoneEtat) {
        if let i = t.messages.firstIndex(where: { $0.id == id }) { t.messages[i].lu = true }
    }

    static func toutMarquerLu(_ t: inout PhoneEtat) {
        for i in t.messages.indices { t.messages[i].lu = true }
    }

    static func supprimerMessage(_ id: UUID, _ t: inout PhoneEtat) {
        t.messages.removeAll { $0.id == id }
    }

    /// Répond à un message et renvoie le texte du résultat.
    static func repondre(_ id: UUID, choix index: Int, _ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) -> String {
        guard let i = t.messages.firstIndex(where: { $0.id == id }), t.messages[i].reponse == nil else { return "" }
        var msg = t.messages[i]
        let libelles = choix(msg)
        guard libelles.indices.contains(index) else { return "" }
        let label = libelles[index]
        let resultat: String

        if let sid = msg.sponsorId, let sp = PhoneBibliotheque.sponsor(sid) {
            let extra = ["marque": sp.marque, "montant": Format.argent(paiementSponsor(sp, t, bonus: 1))]
            switch index {
            case 0, 1:
                if t.contrats.count >= maxContrats {
                    resultat = "Tu as déjà \(maxContrats) contrats. Ton agent (toi) dit non."
                } else if index == 1 && Double.random(in: 0...1) < 0.5 {
                    resultat = "Tu as demandé le double. \(sp.marque) a répondu par un GIF de chat qui rit, puis plus rien."
                } else {
                    let bonus = index == 1 ? 1.5 : 1
                    t.contrats.append(PhoneContrat(sponsorId: sp.id, marque: sp.marque, depuisAge: j.age, bonus: bonus))
                    let paiement = paiementSponsor(sp, t, bonus: bonus)
                    j.argent += paiement
                    if sp.louche >= 0.4 { j.stats.karma -= 2 }
                    resultat = (index == 1 ? "Négociation réussie, +50 % ! " : "")
                        + remplir(sp.accepte, j, engine: engine, extra: extra)
                        + " Premier versement : \(Format.argent(paiement))."
                }
            default:
                if sp.louche >= 0.4 { j.stats.karma += 2 }
                resultat = ["Tu refuses poliment. \(sp.marque) t'envoie quand même un échantillon. Il fait peur.",
                            "Tu refuses. Ton intégrité te remercie. Ton compte en banque boude.",
                            "Refusé. \(sp.marque) va proposer la même chose à ton cousin. Il va dire oui."].randomElement()!
            }
        } else if let mid = msg.modeleId, let modele = PhoneBibliotheque.message(mid), modele.choices.indices.contains(index) {
            let issue = GameEngine.tirage(modele.choices[index].outcomes) { $0.chance ?? 1 }
            let app = PhoneApp(rawValue: modele.app ?? "") ?? t.appPrincipale
            var gainAbonnes = 0
            if let reseau = issue?.reseau {
                let c = t.compte(app)
                gainAbonnes = (reseau.followers ?? 0) + Int(Double(c.abonnes) * (reseau.followersPct ?? 0))
            }
            let extra = ["app": app.nom, "abonnes": PhoneFormat.nombre(t.abonnesTotal), "gain": PhoneFormat.nombre(abs(gainAbonnes))]
            resultat = remplir(issue?.text ?? "Il ne se passe rien.", j, engine: engine, extra: extra)
            if gainAbonnes != 0 && t.aTelephone {
                var c = t.compte(app)
                c.abonnes = max(0, c.abonnes + gainAbonnes)
                t.comptes[app.rawValue] = c
            }
            if let eff = issue?.effects { engine.appliquer(eff, &j) }
        } else {
            resultat = index == 0 ? "Tu réponds « ok ». La conversation est terminée. C'était intense."
                                  : "Laissé en vu. Le pouvoir, c'est ça."
        }

        msg.lu = true
        msg.choixFait = label
        msg.reponse = resultat
        t.messages[i] = msg
        engine.ajouterLigne(&j, "💬 Message de \(msg.expediteur) → \(label). \(resultat)")
        j.stats.borner()
        return resultat
    }

    // MARK: - Pécho (rencontre)

    static func tirerProfil(_ j: Joueur, _ t: PhoneEtat) -> PhoneProfil? {
        guard j.age >= 18 else { return nil }
        let genre: Genre
        switch t.recherche {
        case "male": genre = .homme
        case "female": genre = .femme
        default: genre = Genre.allCases.randomElement()!
        }
        let basAge = max(18, j.age - 6)
        let hautAge = max(basAge, j.age + 6)
        let age = Int.random(in: basAge...hautAge)
        let cle = genre == .homme ? "male" : "female"
        let bios = PhoneBibliotheque.profils.filter {
            ($0.genre == "any" || $0.genre == cle) && age >= ($0.minAge ?? 18) && age <= ($0.maxAge ?? 120)
        }
        let bio = bios.randomElement()?.bio ?? "Pas de bio. Juste une photo floue devant un coucher de soleil."
        return PhoneProfil(prenom: Donnees.prenom(genre), genre: genre, age: age, bio: bio)
    }

    static func swipesRestants(_ t: PhoneEtat) -> Int { max(0, swipesParAn - t.nombreActions("swipe")) }

    static func swiper(_ p: PhoneProfil, aDroite: Bool, _ j: inout Joueur, _ t: inout PhoneEtat) -> String {
        guard j.age >= 18, t.aTelephone else { return "Pécho est réservé aux 18 ans et plus." }
        guard swipesRestants(t) > 0 else { return "Tu as swipé \(swipesParAn) fois cette année. Ton pouce demande un arrêt maladie." }
        t.actionsAnnee.append("swipe")
        if !aDroite {
            return ["Tu passes. \(p.prenom) ne le saura jamais.",
                    "À gauche. \(p.prenom) disparaît dans le grand néant de l'amour numérique.",
                    "Non merci. Le pouce a parlé."].randomElement()!
        }
        var chance = 0.18 + Double(j.stats.apparence) / 200
        if t.abonnesTotal >= 10_000 { chance += 0.1 }
        if t.abonnesTotal >= 1_000_000 { chance += 0.15 }
        if Double.random(in: 0...1) < min(0.9, chance) {
            t.matchs.append(PhoneMatch(prenom: p.prenom, genre: p.genre, age: p.age, bio: p.bio, ageDuMatch: j.age))
            if t.matchs.count > 30 { t.matchs.removeFirst(t.matchs.count - 30) }
            j.stats.bonheur += 2
            j.stats.borner()
            return "💘 C'est un match avec \(p.prenom) ! Tu peux lui proposer un rendez-vous."
        }
        return ["Pas de match. \(p.prenom) a swipé à gauche. Ça arrive aux meilleurs.",
                "Rien. \(p.prenom) t'a vu" + (j.genre == .femme ? "e" : "") + " et a choisi la solitude.",
                "Pas de match. L'algorithme dit que ce n'est « pas le moment ». Il dit ça à tout le monde."].randomElement()!
    }

    static func rendezVousRestants(_ t: PhoneEtat) -> Int { max(0, rendezVousParAn - t.nombreActions("rdv")) }

    static func rendezVous(_ id: UUID, _ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) -> String {
        guard let i = t.matchs.firstIndex(where: { $0.id == id }) else { return "" }
        guard rendezVousRestants(t) > 0 else { return "Trois rendez-vous cette année, c'est assez. Ton cœur et ton portefeuille ont besoin de repos." }
        let match = t.matchs[i]
        t.actionsAnnee.append("rdv")
        t.matchs.remove(at: i)

        var cout = 0
        if j.argent >= 60 { cout = Int.random(in: 25...60) }
        j.argent -= cout

        let bonus = Double(j.stats.apparence + j.stats.bonheur) / 400   // 0 à 0,5
        let poids: [(String, Double)] = [
            ("lapin", 0.15), ("catastrophe", 0.22 - bonus * 0.2), ("bof", 0.25),
            ("bien", 0.23 + bonus * 0.2), ("coupdefoudre", 0.12 + bonus * 0.2),
        ]
        let issue = GameEngine.tirage(poids) { $0.1 }?.0 ?? "bof"
        let modeles = PhoneBibliotheque.rendezVous.filter { $0.issue == issue }
        let texteBrut = modeles.randomElement()?.texte ?? "Le rendez-vous avec {match} s'est passé. C'est tout ce qu'on peut dire."
        var texte = remplir(texteBrut, j, engine: engine, extra: ["match": match.prenom])

        switch issue {
        case "lapin": j.stats.bonheur -= 6
        case "catastrophe": j.stats.bonheur -= 4
        case "bien": j.stats.bonheur += 6
        case "coupdefoudre":
            j.stats.bonheur += 12
            if let p = j.relations.firstIndex(where: { $0.type == .partenaire && $0.vivant }) {
                j.relations[p].lien = Stats.borne(j.relations[p].lien - 15)
                j.stats.karma -= 5
                texte += " Petit détail : tu es déjà en couple avec \(j.relations[p].prenom). Ambiance."
            } else {
                let partenaire = Relation(prenom: match.prenom, nom: Donnees.noms.randomElement()!, genre: match.genre,
                                          type: .partenaire, age: match.age + (j.age - match.ageDuMatch),
                                          lien: Int.random(in: 70...90))
                j.relations.append(partenaire)
                texte += " Vous êtes maintenant en couple !"
            }
        default: break
        }
        if cout > 0 { texte += " (Addition : \(Format.argent(cout)).)" }
        engine.ajouterLigne(&j, "💘 Rendez-vous Pécho avec \(match.prenom) : " + texte)
        j.stats.borner()
        return texte
    }
}

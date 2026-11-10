import Foundation

/// Règles du système de permis. Tout est statique et ne dépend que de `Joueur` et `PermisEtat`.
enum PermisModule {

    // MARK: - Branchements optionnels (à régler par le moteur au lancement de l'app)

    /// Modifie une chance de réussite à un examen (ex. mode Shkurtaaa « Diplôme garanti » :
    /// `PermisModule.ajusterChanceExamen = { Shkurtaaa.chanceExamen($0) }`).
    static var ajusterChanceExamen: ((Double) -> Double)?

    /// Envoie le joueur en prison (module crime). Paramètres : joueur, années, motif.
    /// Sans branchement, la peine est prononcée avec sursis.
    static var envoyerEnPrison: ((inout Joueur, Int, String) -> Void)?

    /// Émet un signal de répercussions (ex. "permis_obtenu"). À brancher sur `Repercussions.signaler`.
    static var signaler: ((inout Joueur, String) -> Void)?

    static func signal(_ j: inout Joueur, _ nom: String) {
        signaler?(&j, nom)
    }

    // MARK: - Données

    static let questions: [PermisQuestion] = DonneesJSON.chargerTableaux(dossier: "Permis/Code", type: PermisQuestion.self)
    static let scenesExamen: [PermisScene] = DonneesJSON.chargerTableaux(dossier: "Permis/Pratique", type: PermisScene.self)
    static let scenesBalade: [PermisScene] = DonneesJSON.chargerTableaux(dossier: "Permis/Route", type: PermisScene.self)
    static let incidents: [PermisIncident] = DonneesJSON.chargerTableaux(dossier: "Permis/Incidents", type: PermisIncident.self)

    static func concerne(_ liste: [String], _ t: PermisType) -> Bool {
        liste.contains("any") || liste.contains(t.rawValue) || (t.estRoute && liste.contains("route"))
    }

    static func ageOK(_ age: Int, min: Int?, max: Int?) -> Bool {
        age >= (min ?? 0) && age <= (max ?? 200)
    }

    // MARK: - Inscription et examens

    enum Etape: String {
        case code, pratique
    }

    /// Prochaine épreuve à passer pour ce permis, ou nil s'il est déjà obtenu (et valable).
    static func prochaineEtape(_ t: PermisType, _ p: PermisEtat) -> Etape? {
        if let d = p.detenu(t), !d.faux { return nil }
        return p.codesReussis.contains(t) ? .pratique : .code
    }

    static func cleAnnee(_ t: PermisType, _ e: Etape) -> String { "permis_\(e.rawValue)_\(t.rawValue)" }

    /// Prix payé par le joueur (les parents paient pour les mineurs).
    static func prix(_ t: PermisType, _ e: Etape, age: Int) -> Int {
        if age < 18 { return 0 }
        return e == .code ? t.prixCode : t.prixPratique
    }

    /// Raison pour laquelle on ne peut pas s'inscrire à ce permis maintenant, ou nil.
    static func blocage(_ t: PermisType, _ j: Joueur, _ p: PermisEtat) -> String? {
        guard let etape = prochaineEtape(t, p) else { return "Déjà obtenu." }
        if j.age < t.ageMin { return "Dès \(t.ageMin) ans." }
        if let manquant = t.prerequis.first(where: { !p.valide($0, age: j.age) }) {
            return "Il faut d'abord le \(manquant.nomCourt)."
        }
        if t.estRoute, let a = p.annuleJusqua, j.age < a {
            return "Permis annulé : tu pourras repasser à \(a) ans."
        }
        if let i = p.interditJusqua[t.rawValue], j.age < i {
            return "Interdit d'examen jusqu'à \(i) ans."
        }
        if t == .armes && j.stats.karma < 25 {
            return "Ton entretien psychologique a fait peur à la préfecture. (Karma trop bas)"
        }
        if j.actionsAnnee.contains(cleAnnee(t, etape)) {
            return "Déjà tenté cette année. Reviens l'an prochain."
        }
        let cout = prix(t, etape, age: j.age)
        if cout > 0 && j.argent < cout {
            return "Pas assez d'argent (\(Format.argent(cout)))."
        }
        return nil
    }

    /// Paie l'épreuve et la marque comme tentée cette année. Renvoie un message d'erreur ou nil.
    static func commencer(_ t: PermisType, _ e: Etape, _ j: inout Joueur, _ p: PermisEtat) -> String? {
        if let b = blocage(t, j, p) { return b }
        j.argent -= prix(t, e, age: j.age)
        j.actionsAnnee.append(cleAnnee(t, e))
        return nil
    }

    /// Questions du code pour ce permis.
    static func tirerQuestions(_ t: PermisType, nombre: Int = 5) -> [PermisQuestion] {
        let pool = questions.filter { concerne($0.permis, t) }
        let specifiques = pool.filter { $0.permis.contains(t.rawValue) }.shuffled()
        // Au moins deux questions propres au permis si possible, le reste pioché dans tout le pool.
        var choix = Array(specifiques.prefix(2))
        for q in pool.shuffled() where choix.count < nombre && !choix.contains(where: { $0.id == q.id }) {
            choix.append(q)
        }
        // Mélange les réponses pour que la bonne ne soit pas toujours à la même place.
        return choix.shuffled().map { q in
            guard q.reponses.indices.contains(q.bonne) else { return q }
            var m = q
            let ordre = Array(q.reponses.indices).shuffled()
            m.reponses = ordre.map { q.reponses[$0] }
            m.bonne = ordre.firstIndex(of: q.bonne) ?? 0
            return m
        }
    }

    /// Nombre de bonnes réponses nécessaires.
    static func seuilCode(total: Int) -> Int { max(1, total - 1) }

    /// Résultat du code.
    static func terminerCode(_ t: PermisType, bonnes: Int, total: Int, _ j: inout Joueur, _ p: inout PermisEtat) -> String {
        if bonnes >= seuilCode(total: total) {
            if !p.codesReussis.contains(t) { p.codesReussis.append(t) }
            j.stats.bonheur += 4
            j.stats.intelligence += 1
            signal(&j, "permis_code_obtenu")
            let phrase = [
                "Code réussi (\(bonnes)/\(total)) ! Tu as eu envie d'appeler tout ton répertoire.",
                "Code réussi (\(bonnes)/\(total)). La dame de l'accueil t'a dit « bravo » sans lever les yeux.",
                "Code en poche (\(bonnes)/\(total)). Tu sais enfin ce que veut dire ce panneau bizarre en forme de triangle.",
            ].randomElement()!
            return phrase + " Prochaine étape : la pratique."
        }
        let n = (p.echecs[t.rawValue] ?? 0) + 1
        p.echecs[t.rawValue] = n
        j.stats.bonheur -= 4
        signal(&j, "permis_code_rate")
        return texteEchec(t, n) + " (\(bonnes)/\(total), il en fallait \(seuilCode(total: total)).)"
    }

    static func texteEchec(_ t: PermisType, _ n: Int) -> String {
        switch n {
        case 1:
            return ["Raté. Tu blâmes la chaise, qui était bancale.",
                    "Raté. Tu as confondu « céder le passage » et « céder à la panique ».",
                    "Raté. L'examinateur a soupiré comme un ventilateur fatigué."].randomElement()!
        case 2:
            return "Raté, encore. Ta mère a commencé une phrase par « Quand j'avais ton âge… »."
        case 3:
            return "Troisième échec. L'école t'a offert une carte de fidélité : le 10e examen est gratuit."
        case 4...6:
            return "Échec n°\(n). Les examinateurs se connaissent tous et ils parlent de toi."
        default:
            return "Échec n°\(n). Ta photo est affichée dans la salle des profs du \(t.nomCourt), avec la mention « Courage »."
        }
    }

    /// Situations de l'épreuve pratique.
    static func tirerScenesExamen(_ t: PermisType, nombre: Int = 3) -> [PermisScene] {
        let pool = scenesExamen.filter { concerne($0.permis, t) }
        let specifiques = pool.filter { $0.permis.contains(t.rawValue) }.shuffled()
        var choix = Array(specifiques.prefix(2))
        for s in pool.shuffled() where choix.count < nombre && !choix.contains(where: { $0.id == s.id }) {
            choix.append(s)
        }
        return choix
    }

    /// Chance réelle de réussir un choix de l'épreuve pratique.
    static func chanceExamen(_ c: PermisChoix, _ t: PermisType, _ j: Joueur) -> Double {
        var chance = c.chance ?? 1
        if chance > 0 && chance < 1 {
            chance -= t.difficulte
            chance += (Double(j.stats.intelligence) - 50) / 500
            chance += (Double(j.stats.sante) - 50) / 1000
            if j.age >= 75 { chance -= 0.10 }
            chance = min(0.98, max(0.02, chance))
        }
        if let ajuster = ajusterChanceExamen { chance = ajuster(chance) }
        return chance
    }

    /// Joue un choix de l'épreuve pratique.
    static func jouerChoixExamen(_ c: PermisChoix, _ t: PermisType, _ j: Joueur) -> (reussi: Bool, texte: String, eliminatoire: Bool) {
        let reussi = Double.random(in: 0..<1) < chanceExamen(c, t, j)
        if reussi { return (true, remplir(c.success, j), false) }
        let elim = c.faute == "eliminatoire"
        let texte = remplir(c.failure ?? "L'examinateur note quelque chose. Ça n'a pas l'air d'être un compliment.", j)
        return (false, texte, elim)
    }

    static func examenReussi(fautesMineures: Int, eliminatoire: Bool) -> Bool {
        !eliminatoire && fautesMineures <= 1
    }

    /// Résultat de l'épreuve pratique.
    static func terminerPratique(_ t: PermisType, fautesMineures: Int, eliminatoire: Bool,
                                 _ j: inout Joueur, _ p: inout PermisEtat) -> String {
        if examenReussi(fautesMineures: fautesMineures, eliminatoire: eliminatoire) {
            return accorder(t, &j, &p, faux: false)
        }
        let n = (p.echecs[t.rawValue] ?? 0) + 1
        p.echecs[t.rawValue] = n
        j.stats.bonheur -= 6
        signal(&j, "permis_rate")
        let raison = eliminatoire ? "Faute éliminatoire." : "Trop de fautes (\(fautesMineures))."
        return "\(raison) " + texteEchec(t, n) + " Tu garderas ton code : retente la pratique l'an prochain."
    }

    /// Donne le permis au joueur.
    @discardableResult
    static func accorder(_ t: PermisType, _ j: inout Joueur, _ p: inout PermisEtat, faux: Bool) -> String {
        let premierRoute = t.estRoute && !p.detenus.contains { $0.type.estRoute && !$0.faux && !$0.retire }
        p.detenus.removeAll { $0.type == t }
        p.detenus.append(PermisDetenu(type: t, ageObtention: j.age, faux: faux))
        p.codesReussis.removeAll { $0 == t }
        if faux {
            signal(&j, "faux_permis_achete")
            return "Tu as maintenant un « \(t.nomCourt) ». Il sent encore l'imprimante."
        }

        p.interditJusqua[t.rawValue] = nil
        j.stats.bonheur += 12
        signal(&j, "permis_obtenu")
        if t.estRoute {
            p.conduiteSansPermis = false
            if premierRoute {
                p.points = 6
                p.finProbatoire = j.age + 3
                p.annuleJusqua = nil
                p.suspenduJusqua = nil
            }
        }
        let echecs = p.echecs[t.rawValue] ?? 0
        var texte: String
        switch t {
        case .voiture:
            texte = "🎉 Tu as ton permis voiture ! Ton père t'a tendu les clés en tremblant légèrement."
        case .moto:
            texte = "🎉 Permis moto obtenu ! Ta mère a déjà acheté un casque, une dorsale et des cierges."
        case .scooter:
            texte = "🎉 Permis scooter obtenu ! Tout le quartier va entendre parler de toi. Littéralement."
        case .poidsLourd:
            texte = "🎉 Permis poids lourd obtenu ! Tu as maintenant le droit de klaxonner comme un paquebot."
        case .bus:
            texte = "🎉 Permis bus obtenu ! Tu peux enfin fermer les portes au nez des gens qui courent."
        case .bateau:
            texte = "🎉 Permis bateau obtenu ! Tu dis déjà « bâbord » au lieu de « gauche » en voiture."
        case .avion:
            texte = "🎉 Licence de pilote obtenue ! Tu commences toutes tes phrases par « Ici votre commandant de bord »."
        case .helicoptere:
            texte = "🎉 Licence d'hélicoptère obtenue ! Tu peux maintenant arriver aux mariages de façon insupportable."
        case .chasse:
            texte = "🎉 Permis de chasse obtenu ! Les sangliers du canton ont tenu une réunion d'urgence."
        case .armes:
            texte = "🎉 Permis de port d'arme accordé. Le fonctionnaire t'a fixé longtemps avant de tamponner."
        case .peche:
            texte = "🎉 Carte de pêche obtenue ! Les poissons, eux, ne sont pas au courant."
        case .drone:
            texte = "🎉 Brevet de drone obtenu ! Les voisins ont acheté des rideaux."
        case .fusee:
            texte = "🚀 PERMIS FUSÉE OBTENU. Tu es la seule personne de \(j.ville) à pouvoir se garer en orbite."
        }
        if echecs >= 3 { texte += " Après \(echecs) échecs, l'école a sorti le champagne." }
        if t.estRoute && premierRoute { texte += " Permis probatoire : 6 points pour commencer, 12 dans 3 ans si tu restes sage." }
        return texte
    }

    // MARK: - Actions spéciales

    static let cleStage = "permis_stage"
    static let cleBalade = "permis_balade"

    /// Stage de récupération de points : +4 points, une fois par an.
    static func blocageStage(_ j: Joueur, _ p: PermisEtat) -> String? {
        if !p.aPermisRoute { return "Il faut un permis de la route." }
        if p.points >= 12 { return "Tu as déjà tous tes points." }
        if j.actionsAnnee.contains(cleStage) { return "Un stage par an maximum." }
        if j.argent < 250 { return "Pas assez d'argent (250 €)." }
        return nil
    }

    static func stageRecuperation(_ j: inout Joueur, _ p: inout PermisEtat) -> String {
        if let b = blocageStage(j, p) { return b }
        j.argent -= 250
        j.actionsAnnee.append(cleStage)
        let avant = p.points
        p.points = min(12, p.points + 4)
        signal(&j, "permis_points_recuperes")
        let phrase = [
            "Deux jours de stage avec un psychologue de la route. Un participant a pleuré en parlant de son Audi.",
            "Stage de récupération : on t'a montré des photos d'accidents, puis offert des croissants. Ambiance étrange.",
            "Au stage, tu as dû expliquer ton excès de vitesse devant le groupe. Tu as inventé une femme enceinte.",
            "Le formateur a passé deux jours à raconter sa propre suspension. Tu as eu tes points quand même.",
        ].randomElement()!
        return phrase + " (+\(p.points - avant) points, tu as \(p.points)/12)"
    }

    /// Prix d'un faux permis au marché noir.
    static func prixFaux(_ t: PermisType) -> Int {
        switch t {
        case .scooter, .peche, .drone: return 400
        case .voiture, .moto, .bateau, .chasse: return 1800
        case .poidsLourd, .bus, .armes: return 4500
        case .avion, .helicoptere: return 25_000
        case .fusee: return 0
        }
    }

    static func blocageFaux(_ t: PermisType, _ j: Joueur, _ p: PermisEtat) -> String? {
        if t == .fusee { return "Personne ne sait falsifier un permis fusée. Même pas la NASA." }
        if j.age < 16 { return "Le vendeur t'a dit de revenir avec un adulte. Ironique." }
        if p.possede(t) { return "Tu en as déjà un." }
        if j.argent < prixFaux(t) { return "Pas assez d'argent (\(Format.argent(prixFaux(t))))." }
        return nil
    }

    /// Acheter un faux permis au marché noir.
    static func acheterFaux(_ t: PermisType, _ j: inout Joueur, _ p: inout PermisEtat) -> String {
        if let b = blocageFaux(t, j, p) { return b }
        j.argent -= prixFaux(t)
        j.stats.karma -= 10
        if Double.random(in: 0..<1) < 0.2 {
            j.stats.bonheur -= 8
            return ["Le vendeur est parti avec ton argent. Le « permis » était une carte de fidélité de boulangerie.",
                    "Ton faux permis porte la photo d'un autre. D'une autre espèce, même : c'est un labrador.",
                    "Le faussaire a écrit ton nom avec trois fautes et « Répubique française ». Poubelle."].randomElement()!
        }
        return accorder(t, &j, &p, faux: true) + " Évite les contrôles de police."
    }

    static func cleSoudoyer(_ t: PermisType) -> String { "permis_soudoyer_\(t.rawValue)" }

    static func prixPotDeVin(_ t: PermisType) -> Int { max(300, t.prixPratique / 2) }

    static func blocageSoudoyer(_ t: PermisType, _ j: Joueur, _ p: PermisEtat) -> String? {
        if prochaineEtape(t, p) != .pratique { return "Il faut d'abord réussir le code." }
        if j.age < 16 { return "Tu as proposé ton argent de poche. L'examinateur a ri." }
        if j.actionsAnnee.contains(cleSoudoyer(t)) { return "Tu as déjà essayé cette année." }
        if let i = p.interditJusqua[t.rawValue], j.age < i { return "Interdit d'examen jusqu'à \(i) ans." }
        if j.argent < prixPotDeVin(t) { return "Pas assez d'argent (\(Format.argent(prixPotDeVin(t))))." }
        return nil
    }

    /// Glisser une enveloppe à l'examinateur.
    static func soudoyer(_ t: PermisType, _ j: inout Joueur, _ p: inout PermisEtat) -> String {
        if let b = blocageSoudoyer(t, j, p) { return b }
        j.actionsAnnee.append(cleSoudoyer(t))
        let r = Double.random(in: 0..<1)
        if r < 0.45 {
            j.argent -= prixPotDeVin(t)
            j.stats.karma -= 12
            signal(&j, "corruption_examinateur")
            let texte = ["L'examinateur a compté les billets, puis a dit « parfait créneau » sans quitter le parking.",
                         "L'enveloppe a disparu dans sa veste à une vitesse impressionnante. Tu n'as même pas démarré.",
                         "Il a dit « je n'ai rien vu ». Toi non plus, tu n'as rien vu. Surtout pas la route."].randomElement()!
            return texte + " " + accorder(t, &j, &p, faux: false)
        } else if r < 0.8 {
            j.stats.karma -= 3
            j.stats.bonheur -= 4
            return ["L'examinateur a repoussé l'enveloppe : « Pas avec ce montant. » Il voulait dire non, mais c'était ambigu.",
                    "« Je suis une personne intègre », a-t-il dit, en regardant l'enveloppe très longtemps."].randomElement()!
        } else {
            j.argent -= 2000
            j.stats.karma -= 8
            j.stats.bonheur -= 10
            p.interditJusqua[t.rawValue] = j.age + 3
            p.codesReussis.removeAll { $0 == t }
            p.infractions.append(PermisInfraction(age: j.age, libelle: "Tentative de corruption d'examinateur", points: 0))
            signal(&j, "corruption_ratee")
            return "L'examinateur était un inspecteur infiltré. Amende de 2'000 €, code annulé et interdiction de repasser le \(t.nomCourt) pendant 3 ans."
        }
    }

    // MARK: - Balades

    /// Véhicules que le joueur peut utiliser pour une balade, légalement ou non.
    static func vehiculesBalade(_ j: Joueur, _ p: PermisEtat) -> [PermisType] {
        PermisType.allCases.filter { t in
            guard p.possede(t) else { return false }
            if t.estRoute && !p.valide(t, age: j.age) { return false }
            return !scenesBalade.filter { concerne($0.permis, t) && $0.permisRequis != "sans" }.isEmpty
        }
    }

    static func blocageBalade(_ j: Joueur) -> String? {
        if j.age < 12 { return "Tes pieds ne touchent pas les pédales." }
        if j.actionsAnnee.contains(cleBalade) { return "Tu as déjà fait une sortie cette année." }
        return nil
    }

    /// Tire une situation de balade. `type == nil` : voiture sans permis valide.
    static func tirerBalade(_ type: PermisType?, _ j: Joueur) -> PermisScene? {
        let candidats: [PermisScene]
        if let t = type {
            candidats = scenesBalade.filter { concerne($0.permis, t) && $0.permisRequis != "sans" && ageOK(j.age, min: $0.minAge, max: $0.maxAge) }
        } else {
            candidats = scenesBalade.filter { $0.permisRequis == "sans" && ageOK(j.age, min: $0.minAge, max: $0.maxAge) }
        }
        return tirage(candidats) { $0.weight ?? 1 }
    }

    /// Joue un choix d'une balade et applique ses effets.
    static func jouerChoixBalade(_ c: PermisChoix, type: PermisType?, _ j: inout Joueur, _ p: inout PermisEtat) -> (texte: String, mort: String?) {
        let reussi = Double.random(in: 0..<1) < (c.chance ?? 1)
        var texte = remplir(reussi ? c.success : (c.failure ?? c.success), j)
        var mort: String?
        if let e = reussi ? c.onSuccess : c.onFailure {
            let r = appliquer(e, type: type ?? .voiture, &j, &p)
            if !r.lignes.isEmpty { texte += "\n\n" + r.lignes.joined(separator: "\n") }
            mort = r.mort
        }
        return (texte, mort)
    }

    // MARK: - Effets

    /// Applique les effets d'une situation. Renvoie les lignes de conséquences et une éventuelle cause de mort.
    static func appliquer(_ e: PermisEffets, type: PermisType, _ j: inout Joueur, _ p: inout PermisEtat) -> (lignes: [String], mort: String?) {
        var lignes: [String] = []
        j.stats.bonheur += e.happiness ?? 0
        j.stats.sante += e.health ?? 0
        j.stats.intelligence += e.smarts ?? 0
        j.stats.apparence += e.looks ?? 0
        j.stats.karma += e.karma ?? 0
        if let m = e.money, m != 0 {
            j.argent += m
            lignes.append(m < 0 ? "💸 \(Format.argent(m))" : "💰 +\(Format.argent(m))")
        }
        j.stats.borner()

        if e.controle == true {
            lignes += controle(type: type, &j, &p)
        }

        let legal = p.valide(type, age: j.age)
        let pts = e.points ?? 0
        if e.infraction != nil || pts > 0 {
            p.infractions.append(PermisInfraction(age: j.age, libelle: e.infraction ?? "Infraction routière",
                                                  points: legal && type.estRoute ? pts : 0))
            p.anneesSansInfraction = 0
        }
        if pts > 0 && legal && type.estRoute {
            p.points = max(0, p.points - pts)
            lignes.append("🪪 −\(pts) point\(pts > 1 ? "s" : "") sur ton permis (il t'en reste \(p.points)).")
            if p.points == 0 {
                lignes.append(annulerRoute(&j, &p, annees: max(1, e.suspension ?? 1), motif: "Plus aucun point"))
            }
        }
        if let s = e.suspension, s > 0, p.aPermisRoute, type.estRoute, !p.estAnnule(age: j.age) {
            let debut = max(j.age, p.suspenduJusqua ?? j.age)
            p.suspenduJusqua = debut + s
            signal(&j, "permis_suspendu")
            lignes.append("⛔️ Permis suspendu \(s) an\(s > 1 ? "s" : "") (jusqu'à \(debut + s) ans).")
        }
        if e.annulation == true, p.aPermisRoute {
            lignes.append(annulerRoute(&j, &p, annees: max(1, e.suspension ?? 2), motif: "Décision du tribunal"))
        }
        if e.retrait == true, !type.estRoute, let i = p.detenus.firstIndex(where: { $0.type == type && !$0.retire }) {
            p.detenus[i].retire = true
            p.interditJusqua[type.rawValue] = j.age + 3
            signal(&j, "permis_retire")
            lignes.append("⛔️ On t'a retiré ton \(type.nomCourt). Interdiction de le repasser pendant 3 ans.")
        }
        if let ans = e.prison, ans > 0 {
            lignes.append(prison(&j, ans: ans, motif: e.infraction ?? "infraction routière"))
        }
        if let nom = e.signal { signal(&j, nom) }
        var mort: String?
        if let d = e.death {
            mort = d
        } else if j.stats.sante <= 0 {
            mort = type.causeAccident
        }
        return (lignes, mort)
    }

    /// Annule le permis route.
    static func annulerRoute(_ j: inout Joueur, _ p: inout PermisEtat, annees: Int, motif: String) -> String {
        p.detenus.removeAll { $0.type.estRoute }
        p.codesReussis.removeAll { $0.estRoute }
        p.suspenduJusqua = nil
        p.finProbatoire = nil
        p.points = 12
        p.annuleJusqua = j.age + annees
        j.stats.bonheur -= 15
        signal(&j, "permis_annule")
        return "❌ PERMIS ANNULÉ (\(motif.lowercased())). Il faudra tout repasser, code compris, à partir de \(j.age + annees) ans."
    }

    /// Un contrôle de police : rien à signaler, ou sanction pour conduite sans permis / faux permis.
    static func controle(type: PermisType, _ j: inout Joueur, _ p: inout PermisEtat) -> [String] {
        if p.valide(type, age: j.age) { return [] }
        var lignes: [String] = []
        if let d = p.detenu(type), d.faux {
            if Double.random(in: 0..<1) < 0.4 {
                return ["Le policier a regardé ton faux permis, puis toi, puis le permis. « Bonne route. » Ton cœur bat encore."]
            }
            p.detenus.removeAll { $0.type == type }
            p.arrestationsSansPermis += 1
            p.infractions.append(PermisInfraction(age: j.age, libelle: "Faux et usage de faux (\(type.nomCourt))", points: 0))
            j.argent -= 3000
            j.stats.karma -= 10
            j.stats.bonheur -= 10
            signal(&j, "faux_permis_demasque")
            lignes.append("🚔 Ton faux \(type.nomCourt) a été démasqué : la photo était décollée. Amende de 3'000 €, permis confisqué.")
            if p.arrestationsSansPermis >= 2 {
                lignes.append(prison(&j, ans: 1, motif: "faux et usage de faux"))
            }
            return lignes
        }

        p.arrestationsSansPermis += 1
        let n = p.arrestationsSansPermis
        let suspendu = type.estRoute && p.estSuspendu(age: j.age)
        let libelle = suspendu ? "Conduite malgré une suspension" : "Conduite sans permis"
        p.infractions.append(PermisInfraction(age: j.age, libelle: libelle, points: 0))
        p.anneesSansInfraction = 0
        j.stats.bonheur -= 10
        j.stats.karma -= 5
        signal(&j, "conduite_sans_permis_arretee")
        if suspendu {
            let fin = (p.suspenduJusqua ?? j.age) + 2
            p.suspenduJusqua = fin
            j.argent -= 4500
            lignes.append("🚔 Arrêté pendant ta suspension. Amende de 4'500 € et suspension prolongée jusqu'à \(fin) ans.")
        } else if n == 1 {
            j.argent -= 950
            lignes.append("🚔 Pris en flagrant délit de conduite sans permis. Amende de 800 € et la voiture part à la fourrière (150 €).")
        } else if n == 2 {
            j.argent -= 3000
            let interdit = j.age + 2
            for t in PermisType.route { p.interditJusqua[t.rawValue] = max(p.interditJusqua[t.rawValue] ?? 0, interdit) }
            lignes.append("🚔 Récidive de conduite sans permis. Amende de 3'000 € et interdiction de passer le permis avant \(interdit) ans.")
        } else {
            j.argent -= 5000
            lignes.append("🚔 \(n)e arrestation sans permis. Le juge a soupiré, puis a cessé de soupirer. Amende de 5'000 €.")
            lignes.append(prison(&j, ans: n >= 5 ? 2 : 1, motif: libelle.lowercased()))
        }
        return lignes
    }

    /// Prison : délègue au module crime s'il est branché, sinon sursis.
    static func prison(_ j: inout Joueur, ans: Int, motif: String) -> String {
        let duree = "\(ans) an\(ans > 1 ? "s" : "")"
        if let envoyer = envoyerEnPrison {
            envoyer(&j, ans, motif)
            return "⚖️ Condamnation : \(duree) de prison pour \(motif)."
        }
        j.stats.bonheur -= 15
        j.stats.karma -= 10
        return "⚖️ Condamnation : \(duree) de prison avec sursis pour \(motif). Ton avocat a pleuré, le juge aussi."
    }

    // MARK: - Passage d'une année

    /// À appeler par le moteur dans `vieillir()`, APRÈS `j.age += 1`.
    static func passerAnnee(_ j: inout Joueur, _ p: inout PermisEtat) -> PermisBilanAnnee {
        var bilan = PermisBilanAnnee()
        let age = j.age

        // Fin des sanctions
        if let s = p.suspenduJusqua, age >= s {
            p.suspenduJusqua = nil
            if p.aPermisRoute { bilan.lignes.append("🪪 Fin de ta suspension : on t'a rendu ton permis. Il a pris la poussière.") }
        }
        if let a = p.annuleJusqua, age >= a {
            p.annuleJusqua = nil
            bilan.lignes.append("🪪 Tu as de nouveau le droit de passer le permis. L'auto-école a ressorti ta fiche.")
        }
        p.interditJusqua = p.interditJusqua.filter { $0.value > age }

        // Points
        if p.aPermisRoute {
            let infractionRecente = p.infractions.contains { $0.age >= age - 1 }
            if !infractionRecente {
                p.anneesSansInfraction += 1
                if p.estProbatoire(age: age) || p.finProbatoire == age {
                    if p.points < 12 {
                        p.points = min(12, p.points + 2)
                        bilan.lignes.append("🪪 Une année sans infraction : +2 points (\(p.points)/12).")
                    }
                } else if p.points < 12 && p.anneesSansInfraction >= 2 {
                    p.points = 12
                    bilan.lignes.append("🪪 Deux ans sans infraction : tu récupères tes 12 points. Le système t'a pardonné.")
                }
            }
            if p.finProbatoire == age {
                bilan.lignes.append("🪪 Fin de ta période probatoire. Tu peux décoller le « A » de ta voiture.")
            }
        }

        // Incidents
        var nombre = 0
        let routeValides = PermisType.route.filter { p.valide($0, age: age) }
        if let t = routeValides.randomElement(), Double.random(in: 0..<1) < 0.4 {
            if incident(t, avec: true, &j, &p, &bilan) { nombre += 1 }
        }
        let autres = PermisType.allCases.filter { !$0.estRoute && p.valide($0, age: age) }.shuffled()
        if let t = autres.first, Double.random(in: 0..<1) < 0.25, bilan.mort == nil {
            if incident(t, avec: true, &j, &p, &bilan) { nombre += 1 }
        }
        let conduitIllegalement = (p.conduiteSansPermis || p.detenus.contains { $0.type.estRoute && $0.faux })
            && routeValides.isEmpty && age >= 12
        if conduitIllegalement, nombre < 2, bilan.mort == nil, Double.random(in: 0..<1) < 0.45 {
            let t = p.detenus.first { $0.type.estRoute && $0.faux }?.type ?? .voiture
            _ = incident(t, avec: false, &j, &p, &bilan)
        }
        j.stats.borner()
        return bilan
    }

    /// Tire et applique un incident. Renvoie vrai si un incident a eu lieu.
    private static func incident(_ t: PermisType, avec: Bool, _ j: inout Joueur, _ p: inout PermisEtat, _ bilan: inout PermisBilanAnnee) -> Bool {
        let candidats = incidents.filter { i in
            let requis = i.permisRequis ?? "avec"
            guard ageOK(j.age, min: i.minAge, max: i.maxAge) else { return false }
            if avec { return requis == "avec" && concerne(i.permis, t) }
            return requis == "sans" && (concerne(i.permis, t) || i.permis.contains("route"))
        }
        guard let i = tirage(candidats, poids: { $0.weight ?? 1 }) else { return false }
        bilan.lignes.append(t.emoji + " " + remplir(i.text, j, p))
        if let e = i.effects {
            let r = appliquer(e, type: t, &j, &p)
            bilan.lignes += r.lignes
            if bilan.mort == nil { bilan.mort = r.mort }
        }
        return true
    }

    // MARK: - Tags pour les événements

    /// Permis valides (clés `PermisType.cle`), pour `CareerProfile.licenses` du module métiers.
    static func licences(_ p: PermisEtat?, age: Int) -> Set<String> {
        guard let p = p else { return [] }
        return Set(PermisType.allCases.filter { p.valide($0, age: age) }.map { $0.cle })
    }

    /// Tags à ajouter à `GameEngine.tags(_:)`.
    static func tags(_ etat: PermisEtat?, age: Int) -> Set<String> {
        var t: Set<String> = []
        let p = etat ?? PermisEtat()
        for d in p.detenus where !d.retire {
            t.insert(d.type.cle)
            if d.faux { t.insert("faux_permis") }
        }
        if p.conduitLegalement(age: age) { t.insert("conducteur") }
        if age >= 18 && !p.detenus.contains(where: { $0.type == .voiture }) { t.insert("sans_permis") }
        if p.estSuspendu(age: age) { t.insert("permis_suspendu") }
        if p.estAnnule(age: age) { t.insert("permis_annule") }
        if p.aPermisRoute && p.points <= 4 { t.insert("permis_points_bas") }
        if p.estProbatoire(age: age) && p.aPermisRoute { t.insert("permis_probatoire") }
        if p.conduiteSansPermis && !p.conduitLegalement(age: age) { t.insert("conduit_sans_permis") }
        if p.valide(.avion, age: age) || p.valide(.helicoptere, age: age) { t.insert("pilote") }
        if p.valide(.chasse, age: age) { t.insert("chasseur") }
        if p.infractions.count >= 5 { t.insert("chauffard") }
        return t
    }

    // MARK: - Outils

    static func tirage<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0.0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.randomElement() }
        var r = Double.random(in: 0..<total)
        for element in liste {
            r -= max(0, poids(element))
            if r < 0 { return element }
        }
        return liste.last
    }

    /// Remplace {prenom}, {nom}, {ville}, {mere}, {pere}, {ami}, {partenaire}, {e} et {points}.
    static func remplir(_ texte: String, _ j: Joueur, _ p: PermisEtat? = nil) -> String {
        var t = texte
        t = t.replacingOccurrences(of: "{prenom}", with: j.prenom)
        t = t.replacingOccurrences(of: "{nom}", with: j.nom)
        t = t.replacingOccurrences(of: "{ville}", with: j.ville)
        t = t.replacingOccurrences(of: "{mere}", with: j.mere?.prenom ?? "ta mère")
        t = t.replacingOccurrences(of: "{pere}", with: j.pere?.prenom ?? "ton père")
        t = t.replacingOccurrences(of: "{ami}", with: j.amis.randomElement()?.prenom ?? "ton pote")
        t = t.replacingOccurrences(of: "{partenaire}", with: j.relations.first { $0.type == .partenaire && $0.vivant }?.prenom ?? "ton crush")
        t = t.replacingOccurrences(of: "{points}", with: "\(p?.points ?? 12)")
        t = t.replacingOccurrences(of: "{e}", with: j.genre == .femme ? "e" : "")
        return t
    }
}

extension PermisType {
    /// Cause de mort si la santé tombe à zéro pendant un incident.
    var causeAccident: String {
        switch self {
        case .scooter: return "dans un accident de scooter"
        case .voiture: return "dans un accident de voiture"
        case .moto: return "dans un accident de moto"
        case .poidsLourd: return "dans un accident de camion"
        case .bus: return "dans un accident de bus"
        case .bateau: return "dans un naufrage"
        case .avion: return "dans un accident d'avion"
        case .helicoptere: return "dans un accident d'hélicoptère"
        case .chasse: return "dans un accident de chasse"
        case .armes: return "dans un accident de tir"
        case .peche: return "dans un accident de pêche, ce qui est un exploit"
        case .drone: return "sous les hélices de ton propre drone"
        case .fusee: return "quelque part entre la Terre et la Lune"
        }
    }

    var emoji: String {
        switch self {
        case .scooter: return "🛵"
        case .voiture: return "🚗"
        case .moto: return "🏍️"
        case .poidsLourd: return "🚚"
        case .bus: return "🚌"
        case .bateau: return "⛵️"
        case .avion: return "✈️"
        case .helicoptere: return "🚁"
        case .chasse: return "🦌"
        case .armes: return "🎯"
        case .peche: return "🎣"
        case .drone: return "🛸"
        case .fusee: return "🚀"
        }
    }
}

import Foundation

// Module « Vivre à l'étranger » : règles du jeu.
// Toutes les fonctions sont pures (Joueur + ExpatEtat en inout) : le moteur les appelle
// dans `engine.modifier { … }` ou dans `vieillir()`. Voir docs/ETRANGER.md.

/// Réponse à « est-ce que je peux m'installer là-bas ? ».
struct ExpatVerdict: Equatable {
    /// Faux = impossible (trop jeune, pas assez d'argent, refus récent…).
    var possible: Bool
    /// Raison si impossible, ou résumé du visa.
    var message: String
    /// Probabilité d'obtenir le visa (1 = libre circulation ou nationalité).
    var chanceVisa: Double
    /// Frais de dossier du visa, en euros.
    var fraisVisa: Int
    /// Coût total à payer (déménagement + visa).
    var coutTotal: Int
}

/// Pont vers le module Compétences, qui gère certaines langues (anglais, espagnol…).
/// Le moteur le branche au démarrage ; tant qu'il ne l'est pas, le module garde ses propres niveaux.
/// Voir docs/ETRANGER.md.
enum ExpatPontLangues {
    /// Niveau 0-100 d'une langue (id `en`, `es`…) si l'autre module la gère, sinon nil.
    static var lire: ((String, Joueur) -> Int?)?
    /// Ajoute des points dans l'autre module et renvoie les lignes à écrire dans le journal.
    static var gagner: ((String, Int, inout Joueur) -> [String])?
}

/// Niveau du joueur dans une langue (pour les listes).
struct ExpatNiveauLangue: Identifiable, Equatable {
    let id: String
    let niveau: Int
}

enum ExpatMoteur {

    static let ageMinimum = 18
    /// Coût de la vie annuel de référence (France) pour un adulte, en euros.
    static let coutVieReference = 12_000
    /// Impôt que le moteur prélève déjà sur les salaires (25 %).
    static let impotMoteur = 0.25

    // MARK: - Pays et langue

    static func paysActuel(_ e: ExpatEtat, _ cat: ExpatCatalogue = .shared) -> ExpatPays {
        cat.trouverPays(e.paysActuel) ?? cat.trouverPays(e.paysNaissance) ?? ExpatCatalogue.secours
    }

    /// Capacité à se débrouiller dans un pays : la meilleure de ses langues
    /// (les langues secondaires comptent aux trois quarts).
    static func communication(_ e: ExpatEtat, _ j: Joueur, dans p: ExpatPays) -> Int {
        var meilleur = niveau(p.langue, e, j)
        for l in p.autresLangues { meilleur = max(meilleur, niveau(l, e, j) * 3 / 4) }
        return meilleur
    }

    /// Niveau 0-100 d'une langue. Si le module Compétences gère cette langue (pont branché par le moteur),
    /// c'est lui qui fait foi pour l'apprentissage ; `ExpatEtat.langues` ne garde alors que le niveau
    /// de naissance (langue maternelle), et on prend le meilleur des deux.
    static func niveau(_ langue: String, _ e: ExpatEtat, _ j: Joueur) -> Int {
        let local = e.niveau(langue)
        guard let lire = ExpatPontLangues.lire, let externe = lire(langue, j) else { return local }
        return max(local, min(100, max(0, externe)))
    }

    /// Fait progresser une langue de `gain` points. Passe par le module Compétences s'il gère la langue.
    /// Renvoie (avant, après, lignes déjà écrites par l'autre module).
    @discardableResult
    static func apprendre(_ langue: String, _ gain: Int, plafond: Int = 99,
                          _ j: inout Joueur, _ e: inout ExpatEtat) -> (avant: Int, apres: Int, messages: [String]) {
        let avant = niveau(langue, e, j)
        guard avant < plafond else { return (avant, avant, []) }
        let g = min(gain, plafond - avant)
        if let gagner = ExpatPontLangues.gagner, ExpatPontLangues.lire?(langue, j) != nil {
            // Langue gérée par le module Compétences : c'est lui qui stocke la progression.
            let messages = gagner(langue, g, &j)
            return (avant, niveau(langue, e, j), messages)
        }
        e.langues[langue] = min(plafond, max(e.niveau(langue), avant + g))
        return (avant, niveau(langue, e, j), [])
    }

    /// Les langues du joueur triées du meilleur niveau au moins bon (niveau > 0).
    static func languesParlees(_ e: ExpatEtat, _ j: Joueur, _ cat: ExpatCatalogue = .shared) -> [ExpatNiveauLangue] {
        cat.langues.map { ExpatNiveauLangue(id: $0.id, niveau: niveau($0.id, e, j)) }
            .filter { $0.niveau > 0 }
            .sorted { $0.niveau == $1.niveau ? $0.id < $1.id : $0.niveau > $1.niveau }
    }

    // MARK: - Tags (pour les événements)

    /// Tags à ajouter à `GameEngine.tags(_:)`. Voir docs/ETRANGER_EVENTS.md.
    static func tags(_ e: ExpatEtat, _ j: Joueur, _ cat: ExpatCatalogue = .shared) -> Set<String> {
        let p = paysActuel(e, cat)
        var t: Set<String> = ["pays_\(p.id)", "zone_\(p.zone)"]
        for loi in p.lois { t.insert("loi_\(loi.id)") }
        if e.vitAilleurs {
            t.insert("etranger")
            if e.anneesDansPays < 2 { t.insert("expat_nouveau") }
            if e.anneesDansPays >= 5 { t.insert("expat_installe") }
            if communication(e, j, dans: p) < 40 { t.insert("langue_faible") }
        }
        let bonnes = languesParlees(e, j, cat).filter { $0.niveau >= 60 }.count
        if bonnes >= 2 { t.insert("bilingue") }
        if bonnes >= 3 { t.insert("polyglotte") }
        if e.nationalites.count >= 2 { t.insert("binational") }
        if let r = e.ageRetour, j.age - r < 3, !e.vitAilleurs { t.insert("de_retour") }
        return t
    }

    // MARK: - Argent

    /// Salaire local pour un métier dont le salaire de base (France) est `base`.
    /// Le moteur l'utilise quand il propose un emploi. Mal parler la langue coûte 20 %.
    static func salaireLocal(_ base: Int, _ e: ExpatEtat, _ j: Joueur, _ cat: ExpatCatalogue = .shared) -> Int {
        let p = paysActuel(e, cat)
        var s = Double(base) * p.salaire
        if e.vitAilleurs && communication(e, j, dans: p) < 40 { s *= 0.8 }
        return max(0, Int(s.rounded()))
    }

    /// Prix local d'un achat (boutique, activités) dont le prix en France est `base`.
    static func prixLocal(_ base: Int, _ e: ExpatEtat, _ cat: ExpatCatalogue = .shared) -> Int {
        Int((Double(base) * paysActuel(e, cat).prix).rounded())
    }

    /// Prix local d'un soin (médecin, hôpital) dont le prix en France est `base`.
    static func prixSoin(_ base: Int, _ e: ExpatEtat, _ cat: ExpatCatalogue = .shared) -> Int {
        Int((Double(base) * paysActuel(e, cat).sante).rounded())
    }

    // MARK: - Déménager

    /// Peut-on demander à s'installer dans `p` ? Ne modifie rien.
    static func verdict(_ j: Joueur, _ e: ExpatEtat, vers p: ExpatPays,
                        visaToujoursAccepte: Bool = false, _ cat: ExpatCatalogue = .shared) -> ExpatVerdict {
        let frais = fraisVisa(e, vers: p, cat)
        let cout = p.coutDemenagement + frais
        let chance = visaToujoursAccepte ? 1 : chanceVisa(j, e, vers: p, cat)
        var v = ExpatVerdict(possible: true, message: "", chanceVisa: chance, fraisVisa: frais, coutTotal: cout)
        if !j.vivant { v.possible = false; v.message = "Tu es mort. Même les fantômes ont besoin d'un visa."; return v }
        if p.id == e.paysActuel { v.possible = false; v.message = "Tu vis déjà \(p.enPays)."; return v }
        if j.age < ageMinimum {
            v.possible = false
            v.message = "Tu es trop jeune pour partir seul\(j.genre == .femme ? "e" : ""). Reviens à \(ageMinimum) ans, avec une valise."
            return v
        }
        if j.argent < cout {
            v.possible = false
            v.message = "Il te faut \(Format.argent(cout)) pour partir (billet, cartons, caution\(frais > 0 ? ", visa" : "")). Tu as \(Format.argent(j.argent))."
            return v
        }
        if let a = e.refus[p.id], a == j.age, !visaToujoursAccepte {
            v.possible = false
            v.message = "Ton visa a été refusé cette année. L'ambassade se souvient très bien de toi."
            return v
        }
        if frais == 0 {
            v.message = e.nationalites.contains(p.id) ? "Tu as la nationalité : pas de visa." : "Libre circulation : pas de visa."
        } else {
            v.message = "\(p.libelleVisa) · \(Int((chance * 100).rounded())) % de chances"
        }
        return v
    }

    static func libreCirculation(_ e: ExpatEtat, vers p: ExpatPays, _ cat: ExpatCatalogue = .shared) -> Bool {
        if e.nationalites.contains(p.id) { return true }
        if p.visa == 0 { return true }
        // L'UE et la Suisse : libre circulation pour les citoyens de l'UE et de la Suisse.
        let europeLibre = { (id: String) -> Bool in id == "ch" || cat.trouverPays(id)?.zone == "ue" }
        return europeLibre(p.id) && e.nationalites.contains(where: europeLibre)
    }

    static func fraisVisa(_ e: ExpatEtat, vers p: ExpatPays, _ cat: ExpatCatalogue = .shared) -> Int {
        libreCirculation(e, vers: p, cat) ? 0 : 80 + 120 * p.visa
    }

    /// Probabilité que l'ambassade dise oui.
    static func chanceVisa(_ j: Joueur, _ e: ExpatEtat, vers p: ExpatPays, _ cat: ExpatCatalogue = .shared) -> Double {
        if libreCirculation(e, vers: p, cat) { return 1 }
        var c: Double
        switch p.visa {
        case 1: c = 0.85
        case 2: c = 0.65
        case 3: c = 0.45
        default: c = 0.30
        }
        switch j.diplome {
        case .licence: c += 0.15
        case .master, .doctorat: c += 0.25
        default: break
        }
        if j.emploi != nil { c += 0.05 }
        if j.argent >= 500_000 { c += 0.30 } else if j.argent >= 50_000 { c += 0.12 }
        if communication(e, j, dans: p) >= 40 { c += 0.10 }
        if j.stats.karma < 20 { c -= 0.15 }
        if j.relations.contains(where: { $0.type == .partenaire && $0.vivant && $0.lien >= 80 }) { c += 0.03 }
        return min(0.97, max(0.05, c))
    }

    /// Résultat d'une tentative de déménagement.
    struct Resultat {
        var reussi: Bool
        /// Texte court pour une alerte.
        var resume: String
        /// Lignes écrites dans le journal.
        var lignes: [String]
    }

    /// Tente de s'installer dans `p`, à `ville`. Écrit dans le journal et modifie le joueur.
    /// Le moteur peut passer `visaToujoursAccepte: ShkurtaaaMode.actif` (mode triche).
    @discardableResult
    static func demenager(_ j: inout Joueur, _ e: inout ExpatEtat, vers p: ExpatPays, ville: String? = nil,
                          visaToujoursAccepte: Bool = false, _ cat: ExpatCatalogue = .shared) -> Resultat {
        let v = verdict(j, e, vers: p, visaToujoursAccepte: visaToujoursAccepte, cat)
        guard v.possible else { return Resultat(reussi: false, resume: v.message, lignes: []) }

        // Visa
        if v.fraisVisa > 0 {
            j.argent -= v.fraisVisa
            if Double.random(in: 0..<1) >= v.chanceVisa {
                e.refus[p.id] = j.age
                let raison = raisonsRefus.randomElement()!
                let ligne = "🛂 Visa refusé \(p.enPays) : \(raison) Tu perds \(Format.argent(v.fraisVisa)) de frais de dossier."
                ecrire(&j, ligne)
                j.stats.bonheur -= 5
                return Resultat(reussi: false, resume: ligne, lignes: [ligne])
            }
        }

        let ancien = paysActuel(e, cat)
        let villeArrivee = ville.flatMap { p.villes.contains($0) ? $0 : nil } ?? p.villes.randomElement() ?? p.nom
        var lignes: [String] = []
        j.argent -= p.coutDemenagement

        // Partir
        if !e.sejours.isEmpty, e.sejours[e.sejours.count - 1].ageDepart == nil {
            e.sejours[e.sejours.count - 1].ageDepart = j.age
        }
        let retour = p.id == e.paysNaissance
        if retour {
            lignes.append("🏡 Tu rentres au pays après \(e.anneesDansPays) an\(e.anneesDansPays > 1 ? "s" : "") \(ancien.enPays). Ta valise est plus lourde, toi aussi.")
            if e.sejours.count > 1 && e.anneesDansPays >= 2 { e.ageRetour = j.age }
        } else {
            lignes.append("✈️ Tu t'installes à \(villeArrivee), \(p.enPays) \(p.drapeau). " + arrivees.randomElement()!)
            if let l = cat.trouverLangue(p.langue), communication(e, j, dans: p) < 60 {
                lignes.append("Premier mot appris : « \(l.bonjour) ». Deuxième mot : « \(l.merci) ». Le reste viendra.")
            }
        }
        e.paysActuel = p.id
        e.anneesDansPays = 0
        e.sejours.append(ExpatSejour(pays: p.id, ville: villeArrivee, ageArrivee: j.age))
        if !e.paysConnus.contains(p.id) { e.paysConnus.append(p.id) }
        j.ville = villeArrivee

        // Travail : une mutation est possible, sinon on démissionne.
        if var emploi = j.emploi {
            if Double.random(in: 0..<1) < 0.25 {
                let ratio = p.salaire / max(0.05, ancien.salaire)
                emploi.salaire = max(1, Int((Double(emploi.salaire) * ratio).rounded()))
                j.emploi = emploi
                lignes.append("💼 Ton entreprise accepte de te muter. Nouveau salaire : \(Format.argent(emploi.salaire))/an.")
            } else {
                j.emploi = nil
                lignes.append("💼 Tu quittes ton poste de \(emploi.titre.lowercased()). Ton pot de départ avait un gâteau en forme de valise.")
            }
        }
        if j.etudes != nil {
            lignes.append("🎓 Tu continues tes études sur place. Ton dossier a mis six mois à te suivre.")
        }

        // Proches
        var partenaireSuit = true
        for i in j.relations.indices where j.relations[i].vivant {
            let r = j.relations[i]
            switch r.type {
            case .partenaire:
                let chance = AmeSoeur.estAmeSoeur(r, j) ? 1 : Double(r.lien) / 100 * 0.8 + 0.1
                if Double.random(in: 0..<1) < chance {
                    lignes.append("❤️ \(r.prenom) vient avec toi. Il y a eu des larmes, puis des cartons.")
                    j.relations[i].lien = Stats.borne(r.lien + 5)
                } else {
                    partenaireSuit = false
                    j.relations[i].type = .ex
                    j.relations[i].lien = Stats.borne(r.lien - 20)
                    lignes.append("💔 \(r.prenom) refuse de partir. Vous vous quittez à l'aéroport, comme dans un film, mais sans la musique.")
                }
            case .ami:
                j.relations[i].lien = Stats.borne(r.lien - Int.random(in: 8...18))
            case .mere, .pere:
                j.relations[i].lien = Stats.borne(r.lien + (retour ? 8 : -5))
            default:
                break
            }
        }
        if !retour && !j.amis.isEmpty {
            lignes.append("Tes amis promettent de venir te voir. Ils ne viendront pas, mais ils l'ont promis.")
        }
        j.stats.bonheur += retour ? 8 : (partenaireSuit ? 6 : -10)
        j.stats.borner()

        for l in lignes { ecrire(&j, l) }
        let resume = retour
            ? "Te voilà de retour \(p.enPays)."
            : "Te voilà à \(villeArrivee), \(p.enPays) \(p.drapeau)."
        return Resultat(reussi: true, resume: resume, lignes: lignes)
    }

    static let raisonsRefus = [
        "il manquait une photocopie de la photocopie.",
        "ta photo d'identité souriait, c'est interdit.",
        "l'agent a trouvé ta motivation « peu convaincante ».",
        "ton formulaire était rempli au stylo bleu au lieu de noir.",
        "le dossier est arrivé un jour férié, puis il a disparu.",
    ]

    static let arrivees = [
        "Ta valise, elle, est partie dans un autre pays.",
        "Tu as déjà perdu tes clés, ton adaptateur de prise et tes repères.",
        "Tu as atterri avec un sourire et trois sandwiches de chez toi dans la poche.",
        "Le douanier t'a demandé le but de ton séjour. Tu as répondu « la vie ». Il n'a pas ri.",
        "Tu as passé ta première nuit à fixer le plafond en te demandant ce que tu avais fait.",
    ]

    // MARK: - Langues

    /// Prendre un cours d'une langue (une fois par an et par langue). Renvoie le texte du résultat.
    static func prixCours(_ e: ExpatEtat, _ cat: ExpatCatalogue = .shared) -> Int {
        max(100, prixLocal(600, e, cat))
    }

    static func prendreCours(_ j: inout Joueur, _ e: inout ExpatEtat, langue id: String,
                             _ cat: ExpatCatalogue = .shared) -> String {
        guard let l = cat.trouverLangue(id) else { return "Cette langue n'existe pas. Pas encore." }
        let cle = "expat_cours_\(id)"
        if j.age < 6 { return "Tu apprends déjà à parler tout court. Une langue à la fois." }
        if j.actionsAnnee.contains(cle) { return "Tu as déjà pris des cours de \(l.nom) cette année. Ton cerveau demande une pause." }
        if niveau(id, e, j) >= 99 { return "Tu parles déjà le \(l.nom) comme un natif. Le prof veut prendre des cours avec toi." }
        let prix = j.age < 18 ? 0 : prixCours(e, cat)
        if j.argent < prix { return "Les cours de \(l.nom) coûtent \(Format.argent(prix)). Tu n'as pas de quoi." }
        j.argent -= prix
        j.actionsAnnee.append(cle)
        let (avant, apres, messages) = apprendre(id, gainCours(j, l), &j, &e)
        var texte = [
            "Tu as appris à conjuguer trois verbes et à commander un café.",
            "Ton prof a ri quand tu as prononcé ton prénom. Puis il t'a aidé.",
            "Tu connais maintenant les jours de la semaine et une insulte, par accident.",
            "Tu as fait un jeu de rôle où tu achetais des tomates. Tu étais excellent\(j.genre == .femme ? "e" : "").",
        ].randomElement()!
        texte += " (\(l.nom) : \(avant) → \(apres))"
        if seuilFranchi(avant, apres) { texte += " Tu passes au niveau « \(ExpatEtat.libelleNiveau(apres)) » !" }
        ecrire(&j, "📚 Cours de \(l.nom) : " + texte)
        for m in messages { ecrire(&j, m) }
        return texte
    }

    static func gainCours(_ j: Joueur, _ l: ExpatLangue) -> Int {
        let base = Int.random(in: 8...14) + j.stats.intelligence / 15
        return max(2, base * 3 / (l.difficulte + 2))
    }

    static func seuilFranchi(_ avant: Int, _ apres: Int) -> Bool {
        [20, 40, 60, 80].contains { avant < $0 && apres >= $0 }
    }

    // MARK: - Fin d'année

    /// À appeler une fois par an dans `GameEngine.vieillir()` (après l'âge +1, avant les événements).
    /// Gère l'immersion dans la langue, le coût de la vie, les impôts locaux, le mal du pays
    /// et la naturalisation. Renvoie les lignes à ajouter au journal de l'année
    /// (la fonction ne les écrit pas : le moteur les ajoute à ses `lignes`).
    static func finAnnee(_ j: inout Joueur, _ e: inout ExpatEtat, _ cat: ExpatCatalogue = .shared) -> [String] {
        guard j.vivant else { return [] }
        let p = paysActuel(e, cat)
        var lignes: [String] = []
        e.anneesDansPays += 1

        // Immersion : la langue du pays progresse toute seule.
        if let l = cat.trouverLangue(p.langue), niveau(p.langue, e, j) < 99 {
            var gain = max(1, (Int.random(in: 5...10) + j.stats.intelligence / 20) * 3 / (l.difficulte + 2))
            // Les enfants qui grandissent sur place apprennent vite.
            if j.age < 18 { gain += 6 }
            let (avant, apres, messages) = apprendre(p.langue, gain, &j, &e)
            if seuilFranchi(avant, apres) {
                lignes.append("🗣️ " + progresLangue(l, apres))
            }
            lignes += messages
        }

        guard j.age >= 18 else { return lignes }

        // Coût de la vie et impôts locaux (le moteur compte la France par défaut).
        var bilan = Int((Double(coutVieReference) * (1 - p.prix)).rounded())
        if let emploi = j.emploi {
            bilan += Int((Double(emploi.salaire) * (impotMoteur - p.impots)).rounded())
        }
        if bilan != 0 && p.id != "fr" {
            j.argent += bilan
            if abs(bilan) >= 500 && Double.random(in: 0..<1) < 0.5 {
                lignes.append(bilan > 0
                    ? "💶 La vie \(p.enPays) te coûte moins cher que prévu : \(Format.argent(bilan)) d'économisés cette année."
                    : "💸 La vie \(p.enPays) est chère : \(Format.argent(-bilan)) de plus que chez toi cette année, rien qu'en loyer et en courses.")
            }
        }

        if e.vitAilleurs {
            // Mal du pays les premières années.
            if e.anneesDansPays <= 2 {
                let parentsProches = j.relations.contains { $0.type.estParent && $0.vivant && $0.lien >= 70 }
                let perte = Int.random(in: 1...4) + (parentsProches ? 2 : 0)
                j.stats.bonheur -= perte
                if Double.random(in: 0..<1) < 0.5 {
                    lignes.append(malDuPays.randomElement()!)
                }
            } else if e.anneesDansPays == 5 {
                lignes.append("🏠 Cinq ans \(p.enPays). Tu dis « chez moi » sans préciser lequel.")
                j.stats.bonheur += 5
            }

            // Naturalisation.
            if !e.nationalites.contains(p.id) && e.anneesDansPays >= p.naturalisation {
                let langueOK = communication(e, j, dans: p) >= 40
                if langueOK && Double.random(in: 0..<1) < (j.stats.karma >= 30 ? 0.5 : 0.25) {
                    e.nationalites.append(p.id)
                    j.stats.bonheur += 10
                    lignes.append("🎉 Tu obtiens la nationalité \(adjectifNationalite(p)) ! Tu as répondu juste à la question sur l'hymne, de justesse.")
                } else if !langueOK && e.anneesDansPays == p.naturalisation {
                    lignes.append("📋 Tu pourrais demander la nationalité, mais il faut parler mieux le \(cat.nomLangue(p.langue)).")
                }
            }
        }
        j.stats.borner()
        return lignes
    }

    static func progresLangue(_ l: ExpatLangue, _ niveau: Int) -> String {
        switch niveau {
        case ..<40: return "Ton \(l.nom) progresse : tu comprends enfin ce que la boulangère te demande."
        case ..<60: return "Ton \(l.nom) devient correct : tu peux te plaindre au téléphone sans raccrocher en panique."
        case ..<80: return "Tu parles \(l.nom) couramment. Tu as même fait une blague, et quelqu'un a ri."
        default: return "Tu as rêvé en \(l.nom) cette nuit. Tu es officiellement bilingue."
        }
    }

    static let malDuPays = [
        "🥲 Le mal du pays te prend au supermarché, devant un rayon où ton fromage n'existe pas.",
        "🥲 Tu as appelé ta famille en visio. Ils ont passé l'appel à te montrer le chien.",
        "🥲 Tu as entendu ta langue maternelle dans la rue et tu as suivi les gens sur deux rues.",
        "🥲 Il pleut, tu es loin, et la machine à laver te parle dans une langue que tu ne connais pas.",
    ]

    static func adjectifNationalite(_ p: ExpatPays) -> String {
        let adjectifs: [String: String] = [
            "fr": "française", "be": "belge", "ch": "suisse", "ca": "canadienne", "ma": "marocaine",
            "dz": "algérienne", "tn": "tunisienne", "sn": "sénégalaise", "ci": "ivoirienne", "al": "albanaise",
            "xk": "kosovare", "us": "américaine", "gb": "britannique", "de": "allemande", "es": "espagnole",
            "it": "italienne", "pt": "portugaise", "br": "brésilienne", "jp": "japonaise", "cn": "chinoise",
            "in": "indienne", "mx": "mexicaine", "tr": "turque", "ru": "russe", "ng": "nigériane", "au": "australienne",
        ]
        return adjectifs[p.id] ?? "de ce pays (\(p.nom))"
    }

    // MARK: - Journal

    /// Ajoute une ligne au journal de l'année (même règle que `GameEngine.ajouterLigne`).
    static func ecrire(_ j: inout Joueur, _ texte: String) {
        if j.journal.isEmpty { j.journal.append(Annee(age: j.age, lignes: [])) }
        j.journal[j.journal.count - 1].lignes.append(texte)
    }
}

import Foundation

/// Résultat d'une action du module : texte à afficher, s'il faut l'écrire au journal, et une éventuelle mort.
struct BeauteResultat {
    var texte: String
    /// false = refus (pas assez d'argent, trop jeune…) : rien n'a changé, rien au journal.
    var ok: Bool
    var deces: String? = nil

    static func refus(_ t: String) -> BeauteResultat { BeauteResultat(texte: t, ok: false) }
}

/// Règles du coiffeur et de la chirurgie esthétique. Tout passe par `Joueur.beaute`.
enum BeauteMoteur {

    static var cat: BeauteCatalogue { BeauteCatalogue.charge }

    static func etat(_ j: Joueur) -> BeauteEtat { j.beaute ?? BeauteEtat() }

    static func accord(_ t: String, _ j: Joueur) -> String {
        t.replacingOccurrences(of: "{e}", with: j.genre == .femme ? "e" : "")
    }

    static func enPrison(_ j: Joueur) -> Bool { j.vieEtat.justice.enPrison }

    static func signe(_ n: Int) -> String { n >= 0 ? "+\(n)" : "\(n)" }

    // MARK: - Coiffeur

    static let actionCoiffeur = "beaute_coiffeur"

    static func salons(_ j: Joueur) -> [BeauteSalon] {
        if enPrison(j) { return cat.salons.filter { $0.prison == true } }
        return cat.salons.filter { $0.prison != true && j.age >= $0.ageMin }
    }

    static func coupes(_ j: Joueur) -> [BeauteCoupe] {
        let g = j.genre == .femme ? "femme" : "homme"
        return cat.coupes.filter { j.age >= $0.ageMin && ($0.genre == nil || $0.genre == g) }
    }

    static func couleurs(_ j: Joueur) -> [BeauteCouleur] {
        cat.couleurs.filter { j.age >= $0.ageMin }
    }

    static func prixCoupe(_ s: BeauteSalon, _ c: BeauteCoupe) -> Int {
        Int((Double(s.prix) * c.prixFacteur).rounded())
    }

    /// Une couleur coûte plus cher dans un salon cher.
    static func prixCouleur(_ s: BeauteSalon, _ col: BeauteCouleur) -> Int {
        let facteur = max(1.0, Double(s.prix) / 60.0)
        return Int((Double(col.prix) * facteur).rounded())
    }

    static func prixCoiffure(_ s: BeauteSalon, _ c: BeauteCoupe, _ col: BeauteCouleur?) -> Int {
        prixCoupe(s, c) + (col.map { prixCouleur(s, $0) } ?? 0)
    }

    /// Ce que le joueur paie vraiment (les parents paient pour les mineurs dans les salons simples).
    static func prixPaye(_ j: Joueur, _ s: BeauteSalon, _ c: BeauteCoupe, _ col: BeauteCouleur?) -> Int {
        if j.age < 18 && s.mineurs { return 0 }
        return prixCoiffure(s, c, col)
    }

    /// Raison pour laquelle on ne peut pas y aller (nil = possible).
    static func refusCoiffeur(_ j: Joueur, _ s: BeauteSalon, _ c: BeauteCoupe, _ col: BeauteCouleur?) -> String? {
        if !j.vivant { return "Trop tard pour une nouvelle coupe." }
        if j.age < 2 { return "Tu as trois cheveux. On attend un peu." }
        if j.actionsAnnee.contains(actionCoiffeur) { return accord("Tu es déjà passé{e} chez le coiffeur cette année. Laisse repousser.", j) }
        if etat(j).calvitie && c.longueur >= 2 {
            return "Il faudrait des cheveux pour ça. Choisis une coupe courte, ou regarde la greffe dans « Chirurgie esthétique »."
        }
        if let col = col {
            if !s.couleur { return "Ce salon ne fait pas les couleurs." }
            if j.age < col.ageMin { return "Pas de couleur avant \(col.ageMin) ans. Tes parents sont formels." }
        }
        if j.age < 18 && !s.mineurs {
            return "Tes parents refusent de payer \(Format.argent(prixCoiffure(s, c, col))) pour une coupe. Ils proposent le salon du quartier."
        }
        let prix = prixPaye(j, s, c, col)
        if prix > 0 && !Shkurtaaa.peutPayer(prix, solde: j.argent) {
            return "Il te manque de l'argent : la séance coûte \(Format.argent(prix))."
        }
        return nil
    }

    static func coiffureActive(_ j: Joueur) -> BeauteCoiffure? {
        guard let c = etat(j).coiffure, j.age < c.expire else { return nil }
        return c
    }

    static func coiffer(_ j: inout Joueur, salon: String, coupe: String, couleur: String?) -> BeauteResultat {
        guard let s = cat.salon(salon), let c = cat.coupe(coupe) else { return .refus("Ce salon n'existe plus.") }
        let col = couleur.flatMap { cat.couleur($0) }
        if let r = refusCoiffeur(j, s, c, col) { return .refus(r) }

        var e = etat(j)
        let prix = prixPaye(j, s, c, col)
        j.argent -= prix
        j.actionsAnnee.append(actionCoiffeur)
        e.coiffeurVisites += 1

        // L'ancienne coupe disparaît sous les ciseaux : son bonus (ou son malus) s'en va.
        if let ancienne = e.coiffure, j.age < ancienne.expire { j.stats.apparence -= ancienne.bonus }

        let audace = c.audace + (col?.audace ?? 0)
        var chance = s.talent - 0.06 * Double(c.audace) - 0.05 * Double(col?.audace ?? 0)
        if e.calvitie { chance -= 0.1 }
        chance = max(0.15, min(0.98, chance))
        let r = Double.random(in: 0...1)

        var lignes: [String] = []
        let suffixe: String = col.map { ", " + $0.nom.lowercased() } ?? ""
        let nomLook: String = "coupe « " + c.nom.lowercased() + suffixe + " »"
        let bonus: Int
        var ratee = false
        if r < chance {
            bonus = c.looks + s.prestige + (col?.looks ?? 0) + Int.random(in: 0...2)
            let b = Int.random(in: 3...8)
            j.stats.bonheur += b
            lignes.append(texteReussite(s, nomLook, j))
            if audace >= 4 { lignes.append(["Dans la rue, les gens se retournent. Pas tous pour les bonnes raisons, mais ils se retournent.",
                                            "Tu as un style. Personne ne sait lequel, mais c'en est un."].randomElement()!) }
        } else if r < chance + (1 - chance) * 0.45 {
            bonus = max(0, (c.looks + (col?.looks ?? 0)) / 2)
            j.stats.bonheur += 1
            lignes.append(["Résultat correct pour ta " + nomLook + ". Ni plus, ni moins. Comme un dimanche.",
                           "Ta " + nomLook + " est… acceptable. La coiffeuse dit que « ça va se faire ». Personne ne sait ce que ça veut dire."].randomElement()!)
        } else {
            ratee = true
            bonus = -(3 + 2 * c.audace + Int.random(in: 0...3))
            j.stats.bonheur -= Int.random(in: 6...10)
            e.coiffuresRatees += 1
            lignes.append(texteRate(s, c, col, j))
        }
        j.stats.apparence += bonus

        // Les mineurs et les coupes audacieuses : les parents ont leur mot à dire.
        if j.age < 18 && audace >= 2 {
            for i in j.relations.indices where j.relations[i].type.estParent && j.relations[i].vivant {
                j.relations[i].lien = Stats.borne(j.relations[i].lien - 4)
            }
            lignes.append(["Ta mère a failli s'étouffer avec son café en te voyant.",
                           "Ton père a demandé si c'était « un pari ». Tu as dit non. Il ne t'a pas cru{e}."].randomElement()!)
        }

        let duree = max(1, max(c.duree, col?.duree ?? 1))
        e.coiffure = BeauteCoiffure(coupe: c.id, couleur: col?.id, salon: s.id, age: j.age,
                                    expire: j.age + duree, bonus: bonus, ratee: ratee)
        j.beaute = e

        SignauxModules.signaler("coiffeur", &j)
        if ratee { SignauxModules.signaler("coiffure_ratee", &j) }
        else if audace >= 3 { SignauxModules.signaler("coiffure_audacieuse", &j) }

        var texte = "💇 " + s.nom + " : " + lignes.joined(separator: " ")
        texte += " (\(signe(bonus)) apparence"
        if prix > 0 { texte += ", \(Format.argent(prix))" }
        texte += ")"
        return BeauteResultat(texte: accord(texte, j), ok: true)
    }

    static func texteReussite(_ s: BeauteSalon, _ look: String, _ j: Joueur) -> String {
        switch s.id {
        case "maison":
            return ["Miracle : la coupe maison est réussie. Ta " + look + " ne se voit même pas faite au-dessus de l'évier.",
                    "La coupe maison tient la route. Il reste des cheveux dans le beurre, mais tu es " + j.g("beau", "belle") + "."].randomElement()!
        case "star":
            return ["Le coiffeur des stars a tourné autour de toi pendant une heure en murmurant. Ta " + look + " est une œuvre d'art.",
                    "Ta " + look + " est parfaite. Le coiffeur a pris une photo pour son compte Instaglam."].randomElement()!
        case "prison":
            return "Le codétenu a la main sûre. Ta " + look + " impose le respect dans la cour."
        default:
            return ["Ta " + look + " est superbe. Tu te souris dans chaque vitrine.",
                    "Réussite totale : ta " + look + " te va à merveille. On te demande l'adresse du salon.",
                    "Tu ressors avec une " + look + " impeccable et l'impression de valoir 20 % de plus."].randomElement()!
        }
    }

    static func texteRate(_ s: BeauteSalon, _ c: BeauteCoupe, _ col: BeauteCouleur?, _ j: Joueur) -> String {
        if let col = col, Bool.random() {
            return ["La couleur a mal pris : ton « \(col.nom.lowercased()) » a viré au jaune poussin, avec des reflets verts.",
                    "La décoloration a brûlé tes pointes. Elles cassent quand tu les touches."].randomElement()!
        }
        switch s.id {
        case "maison":
            return "La coupe maison a mal tourné : ta frange monte en escalier et il y a un trou derrière l'oreille. Bonnet obligatoire."
        case "prison":
            return "La tondeuse a dérapé. Tu as maintenant une raie rasée en zigzag. Personne n'ose rire, mais tout le monde regarde."
        default:
            return ["Ta coupe « \(c.nom.lowercased()) » est ratée. Tu as souri devant le miroir pour ne pas pleurer, puis tu as pleuré dans la voiture.",
                    "La coiffeuse a dit « oups » au milieu de ta coupe « \(c.nom.lowercased()) ». On ne veut jamais entendre « oups ».",
                    "C'est raté. Tu ressembles à un personnage de dessin animé qu'on aurait annulé après un épisode."].randomElement()!
        }
    }

    // MARK: - Chirurgie

    static let actionBloc = "beaute_bloc"

    static func interventions(_ j: Joueur, zone: String, clinique: BeauteClinique) -> [BeauteIntervention] {
        let g = j.genre == .femme ? "femme" : "homme"
        return cat.interventions.filter { (i: BeauteIntervention) -> Bool in
            if i.zone != zone { return false }
            if let ig = i.genre, ig != g { return false }
            if let liste = clinique.interventions, !liste.contains(i.id) { return false }
            return true
        }
    }

    static func prixOperation(_ i: BeauteIntervention, _ c: BeauteClinique) -> Int {
        Int((Double(i.prix) * c.prixFacteur).rounded())
    }

    /// Multiplicateur de risque selon la clinique, le nombre d'opérations, la santé et l'âge.
    static func facteurRisque(_ j: Joueur, _ c: BeauteClinique) -> Double {
        var f = c.risqueFacteur * (1 + 0.1 * Double(etat(j).nbBloc))
        if j.stats.sante < 40 { f *= 1.5 }
        if j.age >= 65 { f *= 1.4 }
        return f
    }

    static func niveauRisque(_ i: BeauteIntervention, _ j: Joueur, _ c: BeauteClinique) -> String {
        let p = (i.risque + 5 * i.risqueGrave) * facteurRisque(j, c)
        switch p {
        case ..<0.06: return "faible"
        case ..<0.12: return "moyen"
        case ..<0.22: return "élevé"
        default: return "très élevé"
        }
    }

    static func refusOperation(_ j: Joueur, _ i: BeauteIntervention, _ c: BeauteClinique, prix: Int? = nil) -> String? {
        let e = etat(j)
        if !j.vivant { return "Trop tard." }
        if enPrison(j) { return "Pas de chirurgie esthétique en prison. Le médecin de la prison fait des pansements, pas des miracles." }
        if j.age < i.ageMin { return "Dès \(i.ageMin) ans pour cette intervention." }
        if let cl = c.interventions, !cl.contains(i.id) { return "Cet endroit ne propose pas ça." }
        if i.repare == "calvitie" && !e.calvitie { return "Tes cheveux vont très bien. Le chirurgien refuse de te greffer quoi que ce soit." }
        if i.leger == true {
            if j.actionsAnnee.contains("beaute_" + i.id) { return "Déjà fait cette année. Il faut laisser le produit se tasser." }
        } else if j.actionsAnnee.contains(actionBloc) {
            return "Tu es déjà passé" + j.g("", "e") + " au bloc cette année. Ton corps a besoin d'un an pour s'en remettre."
        }
        let serieux = c.risqueFacteur <= 1.0
        if serieux && e.suites.contains(where: { cat.complication($0.complication)?.grave == true }) {
            return "Aucun chirurgien sérieux ne t'opère tant que ta complication grave n'est pas soignée."
        }
        if serieux && j.stats.sante < 25 { return "Ta santé est trop fragile. Le chirurgien refuse de t'endormir." }
        let p = prix ?? prixOperation(i, c)
        if p > 0 && !Shkurtaaa.peutPayer(p, solde: j.argent) { return "Il te manque de l'argent : \(Format.argent(p))." }
        return nil
    }

    static func operer(_ j: inout Joueur, intervention: String, clinique: String) -> BeauteResultat {
        guard let i = cat.intervention(intervention), let c = cat.clinique(clinique) else { return .refus("Intervention inconnue.") }
        if let r = refusOperation(j, i, c) { return .refus(r) }
        return executer(&j, i, c, prix: prixOperation(i, c))
    }

    /// Fait l'opération (déjà autorisée et payée par `prix`). Utilisé aussi par les événements (prix 0).
    static func executer(_ j: inout Joueur, _ i: BeauteIntervention, _ c: BeauteClinique, prix: Int) -> BeauteResultat {
        var e = etat(j)
        let leger = i.leger == true
        let nbAvant = e.nbBloc
        j.argent -= prix
        e.depenseChirurgie += prix
        j.actionsAnnee.append(leger ? "beaute_" + i.id : actionBloc)

        let f = facteurRisque(j, c)
        let pGrave = i.risqueGrave * f
        let pComp = i.risque * f
        let pRate = (leger ? 0.05 : 0.07) * f
        let r = Double.random(in: 0...1)

        let ageOp = j.age
        var op = BeauteOperation(intervention: i.id, clinique: c.id, age: ageOp, resultat: "reussie",
                                 gain: 0, expire: i.duree.map { ageOp + $0 }, aReparer: false, prix: prix)
        var lignes: [String] = []
        var deces: String? = nil
        var signaux: [String] = leger ? ["injections"] : ["chirurgie_esthetique"]
        signaux.append("chirurgie_" + i.id)
        if c.illegal == true { signaux.append("chirurgie_clandestine") }
        if c.id == "forfait" { signaux.append("chirurgie_forfait") }

        if r < pGrave {
            // Accident grave au bloc : ton sérieux, ce n'est pas une blague.
            op.resultat = "grave"
            op.expire = nil
            j.stats.sante -= 45
            j.stats.bonheur -= 20
            lignes.append(i.id == "bbl"
                ? "Pendant l'opération, de la graisse est passée dans une veine et a bloqué la circulation vers les poumons. C'est une embolie graisseuse, la complication qui rend le BBL si dangereux."
                : "Pendant l'opération, ton cœur s'est emballé puis a ralenti dangereusement. L'équipe a dû te réanimer.")
            if Shkurtaaa.peutMourir(deVieillesse: false) && Double.random(in: 0...1) < 0.45 {
                deces = "au bloc opératoire, pendant une chirurgie esthétique (« \(i.nom) »)"
                lignes.append("Les médecins n'ont pas pu te sauver.")
            } else {
                lignes.append("Tu as passé plusieurs jours en réanimation, entre la vie et la mort. Tu t'en sors, mais pas indemne.")
                ajouterSuite(&e, &j, "sequelles", i.id)
                if let cs = cat.complication("sequelles") { lignes.append(cs.texte) }
            }
            if c.illegal == true { lignes.append("La fausse esthéticienne a disparu. Son numéro ne répond plus.") }
            signaux += ["hopital", "chirurgie_ratee"]
        } else if r < pGrave + pComp, let compId = i.complications.randomElement(), let comp = cat.complication(compId) {
            op.resultat = "complication"
            op.gain = max(1, Int.random(in: i.gainMin...i.gainMax) / 2)
            j.stats.apparence += op.gain
            j.stats.sante -= comp.sante
            ajouterSuite(&e, &j, compId, i.id)
            lignes.append("Complication : " + comp.texte)
            if comp.grave { lignes.append("Tu dois être soigné" + j.g("", "e") + " vite : sans soin, ça peut mal finir.") }
            signaux.append("hopital")
        } else if r < pGrave + pComp + pRate {
            op.resultat = "ratee"
            op.gain = -Int.random(in: 5...12)
            op.aReparer = !leger
            j.stats.apparence += op.gain
            j.stats.bonheur -= 12
            lignes.append(i.rate.randomElement() ?? "C'est raté.")
            if !leger { lignes.append("Une chirurgie réparatrice sera nécessaire.") }
            signaux.append("chirurgie_ratee")
        } else {
            var gain = Int.random(in: i.gainMin...i.gainMax) + c.gainBonus
            if let ideal = i.ageIdeal, j.age < ideal - 10 {
                gain /= 2
                lignes.append("À ton âge, il n'y avait pas grand-chose à corriger : l'effet est discret.")
            }
            if !leger && nbAvant >= 4 {
                gain = Int(Double(gain) * max(0.25, 1 - 0.15 * Double(nbAvant - 3)))
                lignes.append("À force d'opérations, chaque nouvelle change de moins en moins de choses.")
            }
            if j.stats.apparence >= 90 { gain = min(gain, 3) }
            gain = max(1, gain)
            op.gain = gain
            j.stats.apparence += gain
            j.stats.bonheur += 6
            lignes.insert(i.reussite.randomElement() ?? "C'est réussi.", at: 0)
            if i.repare == "calvitie" && e.calvitie {
                e.calvitie = false
                e.calvitieDepuis = nil
                j.stats.apparence += 5
            }
        }

        if op.resultat != "grave" {
            j.stats.sante -= i.sante
            j.stats.bonheur += i.bonheur
        }
        e.operations.append(op)
        if !leger && e.nbBloc == 5 {
            lignes.append("Cinquième passage au bloc. Tu commences à regarder ton visage comme un chantier qui n'est jamais fini.")
        }
        j.beaute = e
        for s in signaux { SignauxModules.signaler(s, &j) }

        var texte = "🏥 " + i.nom + " (" + c.nom.lowercased() + ") : " + lignes.joined(separator: " ")
        if op.gain != 0 { texte += " (\(signe(op.gain)) apparence)" }
        if prix > 0 { texte += " Facture : \(Format.argent(prix))." }
        return BeauteResultat(texte: accord(texte, j), ok: true, deces: deces)
    }

    static func ajouterSuite(_ e: inout BeauteEtat, _ j: inout Joueur, _ compId: String, _ interventionId: String) {
        guard let comp = cat.complication(compId) else { return }
        let perte = max(0, -comp.apparence)
        j.stats.apparence -= perte
        e.suites.append(BeauteSuite(complication: compId, intervention: interventionId, depuis: j.age,
                                    anneesRestantes: comp.duree, apparencePerdue: perte))
    }

    // MARK: - Réparer et soigner

    static func prixReparation(_ op: BeauteOperation) -> Int {
        Int(Double(cat.intervention(op.intervention)?.prix ?? 5000) * 1.5)
    }

    static func reparer(_ j: inout Joueur, operation id: UUID) -> BeauteResultat {
        var e = etat(j)
        guard let k = e.operations.firstIndex(where: { $0.id == id && $0.aReparer }) else { return .refus("Rien à réparer.") }
        if enPrison(j) { return .refus("Pas de chirurgie en prison.") }
        if j.actionsAnnee.contains(actionBloc) { return .refus("Tu es déjà passé" + j.g("", "e") + " au bloc cette année. Attends l'an prochain.") }
        let prix = prixReparation(e.operations[k])
        if !Shkurtaaa.peutPayer(prix, solde: j.argent) { return .refus("La chirurgie réparatrice coûte \(Format.argent(prix)).") }
        j.argent -= prix
        e.depenseChirurgie += prix
        j.actionsAnnee.append(actionBloc)
        let nom = cat.intervention(e.operations[k].intervention)?.nom ?? "opération"
        let perte = abs(min(0, e.operations[k].gain))
        var texte: String
        if Double.random(in: 0...1) < 0.75 {
            let rendu = perte + Int.random(in: 0...3)
            j.stats.apparence += rendu
            j.stats.bonheur += 10
            e.operations[k].aReparer = false
            e.operations[k].gain = rendu - perte
            e.operations[k].resultat = "reparee"
            texte = "🏥 Chirurgie réparatrice (\(nom)) : le nouveau chirurgien a rattrapé le travail. Tu te reconnais enfin dans le miroir. (+\(rendu) apparence, \(Format.argent(prix)))"
        } else {
            let rendu = perte / 2
            j.stats.apparence += rendu
            j.stats.bonheur -= 4
            e.operations[k].gain += rendu
            texte = "🏥 Chirurgie réparatrice (\(nom)) : c'est mieux, mais pas encore ça. Il faudra peut-être y retourner. (+\(rendu) apparence, \(Format.argent(prix)))"
        }
        j.stats.sante -= 4
        j.beaute = e
        SignauxModules.signaler("chirurgie_esthetique", &j)
        return BeauteResultat(texte: texte, ok: true)
    }

    static func soigner(_ j: inout Joueur, suite id: UUID) -> BeauteResultat {
        var e = etat(j)
        guard let k = e.suites.firstIndex(where: { $0.id == id }), let comp = cat.complication(e.suites[k].complication) else {
            return .refus("Rien à soigner.")
        }
        if enPrison(j) { return .refus("Le médecin de la prison n'a pas le matériel pour ça.") }
        if !Shkurtaaa.peutPayer(comp.soin, solde: j.argent) { return .refus("Le soin coûte \(Format.argent(comp.soin)).") }
        j.argent -= comp.soin
        j.stats.apparence += e.suites[k].apparencePerdue
        j.stats.sante += 5
        j.stats.bonheur += 5
        e.suites.remove(at: k)
        j.beaute = e
        SignauxModules.signaler("guerison", &j)
        return BeauteResultat(texte: "🩺 \(comp.nom) soignée. Les médecins ont fait du bon travail ; tu respires enfin. (\(Format.argent(comp.soin)))", ok: true)
    }

    // MARK: - Effets d'événements

    static func appliquer(_ fx: BeauteEffets, _ j: inout Joueur) -> BeauteResultat {
        var lignes: [String] = []
        var deces: String? = nil
        var e = etat(j)
        if fx.reparer == true {
            for k in e.operations.indices where e.operations[k].aReparer {
                j.stats.apparence += abs(min(0, e.operations[k].gain))
                e.operations[k].gain = 0
                e.operations[k].aReparer = false
                e.operations[k].resultat = "reparee"
            }
        }
        if fx.soigner == true {
            for s in e.suites { j.stats.apparence += s.apparencePerdue }
            e.suites = []
        }
        if let cal = fx.calvitie {
            if cal && !e.calvitie {
                e.calvitie = true
                e.calvitieDepuis = j.age
                j.stats.apparence -= 5
            } else if !cal && e.calvitie {
                e.calvitie = false
                e.calvitieDepuis = nil
                j.stats.apparence += 5
            }
        }
        if fx.coupeRatee == true {
            if var c = e.coiffure, j.age < c.expire {
                j.stats.apparence -= c.bonus
                c.bonus = -6
                c.ratee = true
                c.expire = max(c.expire, j.age + 1)
                e.coiffure = c
            } else {
                e.coiffure = BeauteCoiffure(coupe: "pointes", couleur: nil, salon: "maison", age: j.age,
                                            expire: j.age + 1, bonus: -6, ratee: true)
            }
            j.stats.apparence -= 6
            e.coiffuresRatees += 1
        }
        j.beaute = e
        if let id = fx.operation, let i = cat.intervention(id),
           let c = cat.clinique(fx.clinique ?? "reconnu") ?? cat.clinique("reconnu") {
            let r = executer(&j, i, c, prix: 0)
            lignes.append(r.texte)
            deces = r.deces
        }
        return BeauteResultat(texte: lignes.joined(separator: " "), ok: !lignes.isEmpty, deces: deces)
    }

    // MARK: - Passage d'année

    static func passerAnnee(_ j: inout Joueur) -> (lignes: [String], deces: String?) {
        var lignes: [String] = []
        var deces: String? = nil
        var e = etat(j)
        let avant = e

        // Cheveux qui repoussent, couleur qui s'en va.
        if let c = e.coiffure, j.age >= c.expire {
            j.stats.apparence -= c.bonus
            if c.ratee {
                lignes.append("Ta coupe ratée a enfin repoussé. Tu peux ranger les bonnets.")
            } else if let col = c.couleur.flatMap({ cat.couleur($0) }) {
                lignes.append("Ta couleur « \(col.nom.lowercased()) » a disparu au fil des shampoings, et ta coupe a repoussé. Retour au naturel.")
            } else if c.bonus > 0 {
                lignes.append("Ta coupe « " + (cat.coupe(c.coupe)?.nom.lowercased() ?? "du moment") + " » a repoussé. Un passage chez le coiffeur ne serait pas de refus.")
            }
            e.coiffure = nil
        }

        // Injections, blanchiment… : l'effet s'efface.
        for k in e.operations.indices {
            guard let fin = e.operations[k].expire, j.age >= fin else { continue }
            let g = e.operations[k].gain
            j.stats.apparence -= g
            e.operations[k].gain = 0
            e.operations[k].expire = nil
            if let i = cat.intervention(e.operations[k].intervention) {
                lignes.append(g >= 0 ? "L'effet de « \(i.nom) » s'est dissipé. Il faudrait y retourner."
                                     : "Le produit raté (« \(i.nom) ») s'est enfin résorbé. Ouf.")
            }
        }

        // Complications en cours.
        var restantes: [BeauteSuite] = []
        for var s in e.suites {
            guard let comp = cat.complication(s.complication) else { continue }
            j.stats.sante -= comp.sante
            j.stats.bonheur -= comp.bonheur
            if comp.duree < 99 { s.anneesRestantes -= 1 }
            if comp.grave && deces == nil && Double.random(in: 0...1) < 0.08 && Shkurtaaa.peutMourir(deVieillesse: false) {
                deces = "des suites d'une complication de chirurgie esthétique jamais soignée"
            }
            if s.anneesRestantes <= 0 {
                j.stats.apparence += s.apparencePerdue
                lignes.append("\(comp.nom) : c'est enfin guéri, sans autre soin que le temps.")
            } else {
                lignes.append(comp.sante > 0
                    ? "\(comp.nom) après ton opération : ça te fait encore souffrir (-\(comp.sante) santé). Un soin réglerait le problème."
                    : "\(comp.nom) après ton opération : ça se voit toujours, et ça te pèse. Un chirurgien pourrait corriger ça.")
                restantes.append(s)
            }
        }
        e.suites = restantes

        // Calvitie.
        if !e.calvitie {
            let p: Double
            if j.genre == .homme && (25...70).contains(j.age) { p = 0.035 }
            else if j.genre == .femme && j.age >= 50 { p = 0.006 }
            else { p = 0 }
            if p > 0 && Double.random(in: 0...1) < p {
                e.calvitie = true
                e.calvitieDepuis = j.age
                j.stats.apparence -= 5
                j.stats.bonheur -= 4
                lignes.append(["Ton front gagne du terrain chaque matin. Le diagnostic tombe : calvitie. Tes cheveux te quittent, un par un, sans un mot.",
                               "Sous la lumière de la salle de bain, c'est clair : tu perds tes cheveux. Le siphon de la douche le savait avant toi."].randomElement()!)
                SignauxModules.signaler("calvitie", &j)
            }
        }

        // Obsession du miroir à force d'opérations.
        if e.nbBloc >= 5 && Double.random(in: 0...1) < 0.3 {
            j.stats.bonheur -= 3
            lignes.append("Tu passes de longues minutes devant le miroir à chercher le prochain défaut à corriger. Tu en trouves toujours un.")
        }

        if e != avant || j.beaute != nil { j.beaute = e }
        return (lignes, deces)
    }

    // MARK: - Tags

    static func tags(_ j: Joueur) -> Set<String> {
        // Jamais passé chez le coiffeur du jeu : petit rappel qu'il existe.
        guard let e = j.beaute else { return j.age >= 25 ? ["beaute_jamais_coiffeur"] : [] }
        var t: Set<String> = []
        let bloc = e.nbBloc
        if bloc >= 1 { t.insert("beaute_operee") }
        if bloc >= 3 { t.insert("beaute_refaite") }
        if bloc >= 5 { t.insert("beaute_accro") }
        if e.operations.contains(where: { $0.aReparer }) { t.insert("beaute_ratee") }
        if !e.suites.isEmpty { t.insert("beaute_complication") }
        if e.suites.contains(where: { cat.complication($0.complication)?.grave == true }) { t.insert("beaute_complication_grave") }
        if e.calvitie { t.insert("beaute_calvitie") }
        for op in e.operations where op.resultat != "grave" {
            if let m = cat.intervention(op.intervention)?.marque { t.insert("beaute_" + m) }
            if op.intervention == "lifting" { t.insert("beaute_lifting") }
            if op.intervention == "greffe" { t.insert("beaute_greffe") }
            if op.intervention == "jambes" { t.insert("beaute_jambes") }
            if let fin = op.expire, j.age < fin, op.gain > 0, cat.intervention(op.intervention)?.leger == true { t.insert("beaute_injections") }
        }
        if e.operations.contains(where: { cat.clinique($0.clinique)?.illegal == true }) { t.insert("beaute_clandestin") }
        if e.operations.contains(where: { $0.clinique == "forfait" }) { t.insert("beaute_tourisme") }
        if e.depenseChirurgie >= 50_000 { t.insert("beaute_gros_budget") }
        if let c = e.coiffure, j.age < c.expire {
            let coupe = cat.coupe(c.coupe)
            let col = c.couleur.flatMap { cat.couleur($0) }
            if c.ratee { t.insert("beaute_coupe_ratee") }
            else if (coupe?.audace ?? 0) >= 2 || (col?.audace ?? 0) >= 2 { t.insert("beaute_coupe_audacieuse") }
            if (col?.audace ?? 0) >= 3 { t.insert("beaute_couleur_vive") }
            if coupe?.longueur == 0 && coupe?.id != "barbe" { t.insert("beaute_crane_rase") }
            if c.salon == "star" { t.insert("beaute_coiffeur_star") }
        }
        if e.coiffeurVisites == 0 && j.age >= 25 { t.insert("beaute_jamais_coiffeur") }
        return t
    }

    /// Phrase courte pour l'écran : la coupe actuelle.
    static func descriptionLook(_ j: Joueur) -> String {
        let e = etat(j)
        var morceaux: [String] = []
        if let c = coiffureActive(j) {
            var t = cat.coupe(c.coupe)?.nom ?? "Coupe"
            if let col = c.couleur.flatMap({ cat.couleur($0) }) { t += ", " + col.nom.lowercased() }
            if c.ratee { t += " (ratée)" }
            morceaux.append(t)
        } else {
            morceaux.append("Cheveux au naturel")
        }
        if e.calvitie { morceaux.append("calvitie") }
        return morceaux.joined(separator: " · ")
    }
}

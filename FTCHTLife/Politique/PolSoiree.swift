import Foundation

// Soirée électorale : au début de l'année qui suit une élection, un événement à choix montre
// les résultats (scores, participation, adversaire) et laisse le joueur réagir.
// Branchement : GameEngine.modulesAvantTirage (affichage) et modulesApresChoix (effets politiques).

extension PolMoteur {

    /// Préfixe des ids d'événement de la soirée électorale.
    static let prefixeSoiree = "pol_soiree"

    /// Participation réaliste selon le type d'élection directe.
    static func participationPour(_ p: PolPoste) -> Double {
        switch p {
        case .conseiller, .adjoint, .maire: return Double.random(in: 44...66)
        case .conseillerRegional: return Double.random(in: 32...48)
        case .depute: return Double.random(in: 42...62)
        case .president: return Double.random(in: 70...82)
        default: return Double.random(in: 40...60)
        }
    }

    /// Retire la soirée en attente et la transforme en événement à afficher (nil s'il n'y a pas eu d'élection).
    static func soireeElectorale(_ e: inout PolEtat, _ j: Joueur) -> Evenement? {
        guard let s = e.soiree else { return nil }
        e.soiree = nil
        guard j.vivant else { return nil }
        let texte = [scene(s, j), resultat(s, j), participation(s)].filter { !$0.isEmpty }.joined(separator: " ")
        return Evenement(id: prefixeSoiree + (s.gagne ? "_victoire" : "_defaite"), category: "politique",
                         minAge: 0, maxAge: 200, weight: 0, unique: false, conditions: nil,
                         text: texte, effects: nil, choices: s.gagne ? choixVictoire(s, j) : choixDefaite(s, j))
    }

    /// Effets politiques du choix fait pendant la soirée électorale.
    static func apresChoixSoiree(evenementId: String, choix: Int, _ e: inout PolEtat) {
        guard evenementId.hasPrefix(prefixeSoiree) else { return }
        if evenementId.hasSuffix("_victoire") {
            switch choix {
            case 0: e.popularite += 3
            case 1: e.popularite += 2; e.influence += 1
            case 3: e.influence += 3; e.loyaute += 1
            default: break
            }
        } else {
            switch choix {
            case 0: e.popularite += 2
            case 1: e.popularite -= 2; e.loyaute += 3
            case 2: e.influence += 2; e.loyaute += 1
            default: break
            }
        }
        e.borner()
    }

    // MARK: - Textes

    private static func scene(_ s: PolSoiree, _ j: Joueur) -> String {
        switch s.poste {
        case .conseiller, .adjoint, .maire:
            return ["🗳️ Soirée électorale à \(j.ville). À 20 h, les bureaux ferment et le dépouillement commence à la salle des fêtes.",
                    "🗳️ Dimanche soir, mairie de \(j.ville). Les assesseurs comptent les bulletins un par un sous les néons.",
                    "🗳️ Les résultats des municipales tombent bureau par bureau à \(j.ville). Ton équipe guette chaque chiffre."].randomElement()!
        case .conseillerRegional:
            return ["🗳️ Soirée des régionales. Les résultats remontent des quatre coins de la région.",
                    "🗳️ Dimanche soir, siège de campagne régional. Les écrans affichent les premières estimations."].randomElement()!
        case .depute:
            return ["🗳️ Législatives, soir du second tour. Ta permanence de circonscription est pleine à craquer.",
                    "🗳️ 20 h, les estimations tombent pour ta circonscription. Personne n'ose parler."].randomElement()!
        case .president:
            if s.eliminePremierTour {
                return "🗳️ Présidentielle, soir du premier tour. À 20 h, les visages des deux qualifiés s'affichent à l'écran. Le tien n'y est pas."
            }
            return ["🗳️ Présidentielle, soir du second tour. À 20 h, un visage s'affiche sur toutes les chaînes du pays.",
                    "🗳️ Le pays retient son souffle. Ton QG de campagne attend 20 h, les yeux rivés sur le compte à rebours."].randomElement()!
        case .senateur:
            return "🗳️ Élections sénatoriales. Les grands électeurs du département ont voté toute la journée à la préfecture."
        case .presidentRegion:
            return "🗳️ Séance d'installation du conseil régional. Les élus votent pour désigner leur président."
        case .presidentAssemblee:
            return "🗳️ Hémicycle, vote à bulletin secret pour le perchoir. Les députés défilent devant l'urne."
        case .secretaireGeneral:
            return "🗳️ Le Conseil de sécurité a rendu sa recommandation, l'Assemblée générale passe au vote."
        default:
            return "🗳️ Soir d'élection. Les résultats tombent."
        }
    }

    private static func resultat(_ s: PolSoiree, _ j: Joueur) -> String {
        let nom = s.poste.nom(j.genre).lowercased()
        let adv = s.adversaire
        let advScore = pourcentage(max(0.1, 100 - s.score))
        if s.poste == .president {
            if s.eliminePremierTour {
                return "Avec \(pourcentage(s.score)) au premier tour, tu es " + j.g("éliminé", "éliminée") + ". \(adv) se qualifie pour le second tour."
            }
            let t1 = s.tour1.map { "Premier tour : \(pourcentage($0)). " } ?? ""
            return s.gagne
                ? t1 + "Second tour : \(pourcentage(s.score)) contre \(advScore) pour \(adv). Tu es " + j.g("élu", "élue") + " \(nom)" + (s.reelection ? " pour un nouveau mandat." : ".")
                : t1 + "Second tour : \(pourcentage(s.score)) contre \(advScore) pour \(adv). \(adv) remporte la présidentielle."
        }
        if s.poste.electionIndirecte {
            return s.gagne
                ? "Tu obtiens \(pourcentage(s.score)) des suffrages face à \(adv). Tu es " + j.g("élu", "élue") + " \(nom)."
                : "Tu n'obtiens que \(pourcentage(s.score)) des suffrages. \(adv) l'emporte."
        }
        let ecart = abs(s.score - 50) < 2 ? " Il s'en est fallu de quelques centaines de voix." : ""
        return s.gagne
            ? "Tu l'emportes avec \(pourcentage(s.score)) des voix contre \(advScore) pour \(adv). Tu es " + j.g(s.reelection ? "réélu" : "élu", s.reelection ? "réélue" : "élue") + " \(nom)." + ecart
            : "\(adv) l'emporte avec \(advScore) des voix. Tu obtiens \(pourcentage(s.score))." + ecart
    }

    private static func participation(_ s: PolSoiree) -> String {
        guard let p = s.participation else { return "" }
        return "Participation : \(pourcentage(p))."
    }

    // MARK: - Choix

    private static func effets(bonheur: Int = 0, karma: Int = 0, sante: Int = 0, liens: [String: Int]? = nil) -> Effets {
        var f = Effets()
        if bonheur != 0 { f.happiness = bonheur }
        if karma != 0 { f.karma = karma }
        if sante != 0 { f.health = sante }
        f.relationships = liens
        return f
    }

    private static func choixVictoire(_ s: PolSoiree, _ j: Joueur) -> [Choix] {
        let lieu = s.poste.rang <= 1 ? "sur le parvis de la mairie" : "devant tes militants"
        return [
            Choix(label: "Remercier tes électeurs \(lieu)", outcomes: [
                Issue(chance: 0.8, text: "Ton discours est sobre et juste. Les applaudissements durent longtemps, et la presse locale salue le ton.", effects: effets(bonheur: 5)),
                Issue(chance: 0.2, text: "Ta voix se brise au moment de remercier ceux qui t'ont accompagné" + j.g("", "e") + " depuis le début. La séquence touche beaucoup de monde.", effects: effets(bonheur: 7)),
            ]),
            Choix(label: "Appeler \(s.adversaire) pour saluer sa campagne", outcomes: [
                Issue(chance: 0.7, text: "L'appel est bref mais courtois. Vous vous promettez de travailler ensemble sur les sujets qui rassemblent.", effects: effets(bonheur: 2, karma: 3)),
                Issue(chance: 0.3, text: "\(s.adversaire) ne décroche pas. Ton message est rendu public par ton équipe, et ton geste est remarqué.", effects: effets(karma: 2)),
            ]),
            Choix(label: "Fêter la victoire avec tes proches", outcomes: [
                Issue(chance: 1, text: "La soirée se termine tard autour de la table familiale. Pour une fois, personne ne parle de politique.", effects: effets(bonheur: 8, liens: ["parent": 5, "partner": 5, "child": 4])),
            ]),
            Choix(label: "Réunir ton équipe dès ce soir pour préparer la suite", outcomes: [
                Issue(chance: 1, text: "À minuit, la liste des premières décisions est prête. Ton équipe est épuisée, mais elle sait où elle va.", effects: effets(bonheur: 2, sante: -1)),
            ]),
        ]
    }

    private static func choixDefaite(_ s: PolSoiree, _ j: Joueur) -> [Choix] {
        [
            Choix(label: "Reconnaître ta défaite et féliciter \(s.adversaire)", outcomes: [
                Issue(chance: 1, text: "Ton discours de défaite est digne. Plusieurs éditorialistes saluent ton attitude, même dans le camp d'en face.", effects: effets(bonheur: -2, karma: 4)),
            ]),
            Choix(label: "Dénoncer une campagne déloyale", outcomes: [
                Issue(chance: 0.6, text: "Tes militants applaudissent, mais une partie de l'opinion te trouve mauvais" + j.g("", "e") + " perdant" + j.g("", "e") + ".", effects: effets(bonheur: 1, karma: -2)),
                Issue(chance: 0.4, text: "Tes accusations font du bruit pendant quelques jours, puis retombent faute de preuves.", effects: effets(karma: -3)),
            ]),
            Choix(label: "Annoncer que tu seras de nouveau candidat" + j.g("", "e"), outcomes: [
                Issue(chance: 1, text: "« Ce n'est qu'un début. » Tes soutiens reprennent espoir et la presse note ta détermination.", effects: effets(bonheur: 3)),
            ]),
            Choix(label: "Rentrer chez toi et couper ton téléphone", outcomes: [
                Issue(chance: 1, text: "Tes proches t'attendent sans poser de questions. La défaite fait moins mal entouré" + j.g("", "e") + " des tiens.", effects: effets(bonheur: 2, liens: ["parent": 4, "partner": 6])),
            ]),
        ]
    }
}

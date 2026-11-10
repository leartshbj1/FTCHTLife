import Foundation

// Actions pour redorer (ou salir) le nom de famille. Chaque action se fait une fois par an au plus.
// Branchement : voir docs/REPUTATION_FAMILLE.md, point 11.

enum RepFamilleAction: String, CaseIterable, Identifiable {
    case don, agenceCom, exorcisme, memoires, diffamation, titreNoblesse, changerNom, profiterMafia, profiterCelebrite

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .don: return "Faire un don à la ville"
        case .agenceCom: return "Engager une agence de com'"
        case .exorcisme: return "Faire exorciser la lignée"
        case .memoires: return "Écrire les mémoires de la famille"
        case .diffamation: return "Porter plainte pour diffamation"
        case .titreNoblesse: return "Acheter un titre de noblesse en ligne"
        case .changerNom: return "Changer de nom de famille"
        case .profiterMafia: return "Faire jouer les relations de la famille"
        case .profiterCelebrite: return "Monnayer le nom de la famille"
        }
    }

    var icone: String {
        switch self {
        case .don: return "building.columns.fill"
        case .agenceCom: return "megaphone.fill"
        case .exorcisme: return "sparkles"
        case .memoires: return "book.closed.fill"
        case .diffamation: return "hammer.fill"
        case .titreNoblesse: return "crown.fill"
        case .changerNom: return "signature"
        case .profiterMafia: return "suit.spade.fill"
        case .profiterCelebrite: return "camera.fill"
        }
    }

    var ageMin: Int {
        switch self {
        case .titreNoblesse, .profiterCelebrite: return 16
        case .memoires: return 40
        default: return 18
        }
    }

    /// Prix fixe en euros (le don dépend de la fortune).
    func prix(_ j: Joueur) -> Int {
        switch self {
        case .don: return max(2000, j.argent / 20)
        case .agenceCom: return 15000
        case .exorcisme: return 1500
        case .memoires: return 0
        case .diffamation: return 5000
        case .titreNoblesse: return 300
        case .changerNom: return 800
        case .profiterMafia, .profiterCelebrite: return 0
        }
    }

    func description(_ j: Joueur) -> String {
        let p = prix(j)
        let cout = p > 0 ? " (\(Format.argent(p)))" : ""
        switch self {
        case .don: return "Redore le blason, efface un peu le reste\(cout)"
        case .agenceCom: return "Fait oublier le pire… en général\(cout)"
        case .exorcisme: return "Lève la malédiction, ou pas\(cout)"
        case .memoires: return "Raconte la légende familiale à ta façon"
        case .diffamation: return "Fait taire les moqueries, ou les amplifie\(cout)"
        case .titreNoblesse: return "Baron de quelque part, selon un site web\(cout)"
        case .changerNom: return "Repartir de zéro. Une fois par vie\(cout)"
        case .profiterMafia: return "De l'argent facile, un nom encore plus sale"
        case .profiterCelebrite: return "Placements de produit et plateaux télé"
        }
    }

    var cleAnnee: String { "repfam_" + rawValue }
}

extension ReputationFamille {
    /// nil si l'action est possible, sinon la raison.
    static func indisponible(_ a: RepFamilleAction, joueur j: Joueur, etat: RepFamilleEtat) -> String? {
        if !j.vivant { return "Trop tard." }
        if j.age < a.ageMin { return "À partir de \(a.ageMin) ans" }
        if j.actionsAnnee.contains(a.cleAnnee) { return "Déjà fait cette année" }
        if a.prix(j) > 0 && j.argent < a.prix(j) { return "Pas assez d'argent" }
        let s = etat.scores
        switch a {
        case .exorcisme where s.maudite < 15: return "Ta famille n'est pas maudite. Pour l'instant."
        case .diffamation where s.ridicule < 20 && s.mafieuse < 20: return "Personne ne dit de mal des \(j.nom)"
        case .changerNom where etat.nomChange: return "Tu as déjà changé de nom"
        case .profiterMafia where s.mafieuse < seuil: return "Ta famille n'a pas ce genre de relations"
        case .profiterCelebrite where s.celebre < seuil: return "Ton nom ne fait vendre personne"
        default: return nil
        }
    }

    /// Fait l'action, modifie le joueur et la réputation, renvoie le texte à afficher (et à mettre au journal).
    static func faire(_ a: RepFamilleAction, joueur j: inout Joueur, etat: inout RepFamilleEtat) -> String {
        if let raison = indisponible(a, joueur: j, etat: etat) { return raison }
        j.actionsAnnee.append(a.cleAnnee)
        let prix = a.prix(j)
        j.argent -= prix
        let nom = j.nom
        let r = Double.random(in: 0...1)

        switch a {
        case .don:
            if r < 0.2 {
                modifier(.respectee, 4, etat: &etat)
                modifier(.ridicule, 3, etat: &etat)
                return "Tu donnes \(Format.argent(prix)) à la ville. La plaque de remerciement dit « Famille \(nom.uppercased())E ». Personne ne la corrige."
            }
            let gain = prix >= 50_000 ? 14 : 8
            modifier(.respectee, gain, etat: &etat)
            modifier(.mafieuse, -3, etat: &etat)
            j.stats.karma += 3
            if prix >= 50_000 { retenir("\(j.prenom) a offert \(Format.argent(prix)) à la ville.", joueur: j, etat: &etat) }
            return "Tu offres \(Format.argent(prix)) à la ville. Le maire prononce « \(nom) » avec respect, pour une fois."

        case .agenceCom:
            let pire = [RepFamilleAxe.mafieuse, .ridicule, .maudite].max { etat.scores[$0] < etat.scores[$1] }!
            if r < 0.25 {
                modifier(.ridicule, 8, etat: &etat)
                modifier(.celebre, 5, etat: &etat)
                return "L'agence lance le hashtag #FiersDEtreDes\(nom.replacingOccurrences(of: " ", with: "")). Il devient viral… pour se moquer de vous."
            }
            let baisse = Int.random(in: 10...20)
            modifier(pire, -baisse, etat: &etat)
            modifier(.respectee, 3, etat: &etat)
            return "L'agence de com' produit un clip émouvant sur la famille \(nom) avec un piano triste. On oublie un peu que vous êtes une famille \(pire.adjectif)."

        case .exorcisme:
            if r < 0.5 {
                modifier(.maudite, -25, etat: &etat)
                retenir("\(j.prenom) a fait exorciser la lignée.", joueur: j, etat: &etat)
                return "L'exorciste hurle en latin pendant deux heures. Un vieux portrait de famille tombe du mur. La malédiction des \(nom) semble levée."
            } else if r < 0.8 {
                return "L'exorciste était un ancien vendeur de cuisines. Il t'a laissé un devis pour une cuisine."
            } else {
                modifier(.maudite, 10, etat: &etat)
                j.stats.sante -= 3
                return "L'exorciste s'enfuit en plein rituel en criant « Elle est trop forte ! ». La malédiction des \(nom) en sort renforcée."
            }

        case .memoires:
            let malin = j.stats.intelligence >= 60
            if malin {
                modifier(.celebre, Int.random(in: 5...10), etat: &etat)
                modifier(.respectee, 4, etat: &etat)
                let droits = Int.random(in: 2...30) * 1000
                j.argent += droits
                retenir("\(j.prenom) a publié les mémoires de la famille.", joueur: j, etat: &etat)
                return "« Les \(nom), une saga » se vend bien. Tu touches \(Format.argent(droits)) de droits d'auteur et tu as un peu enjolivé l'histoire."
            }
            modifier(.ridicule, 6, etat: &etat)
            modifier(.celebre, 3, etat: &etat)
            return "Ton livre contient 43 fautes dans le titre. Il devient culte, pour de mauvaises raisons."

        case .diffamation:
            let cible: RepFamilleAxe = etat.scores.ridicule >= etat.scores.mafieuse ? .ridicule : .mafieuse
            if r < 0.4 {
                modifier(cible, -12, etat: &etat)
                modifier(.respectee, 3, etat: &etat)
                let dommages = Int.random(in: 3...20) * 1000
                j.argent += dommages
                return "Tu gagnes ton procès. Le journal publie des excuses et te verse \(Format.argent(dommages)). Plus personne n'ose se moquer des \(nom)."
            }
            modifier(cible, 6, etat: &etat)
            modifier(.celebre, 2, etat: &etat)
            return "Tu perds le procès. Toute la presse reprend l'histoire que tu voulais faire taire. Bravo."

        case .titreNoblesse:
            if r < 0.15 {
                modifier(.respectee, 5, etat: &etat)
                return "Te voilà « Baron\(j.genre == .femme ? "ne" : "") de la Haute-Pâture ». Étrangement, le notaire y croit."
            }
            modifier(.ridicule, 8, etat: &etat)
            return "Tu signes désormais « \(j.prenom) de \(nom), comte\(j.genre == .femme ? "sse" : "") de Lotissement-sur-Parking ». Tout le monde rit, surtout le facteur."

        case .changerNom:
            let nouveau = Donnees.noms.filter { $0 != nom }.randomElement() ?? "Dupont"
            for axe in RepFamilleAxe.allCases where axe != .maudite {
                modifier(axe, -Int(Double(etat.scores[axe]) * 0.8), etat: &etat)
            }
            modifier(.maudite, -Int(Double(etat.scores[.maudite]) * 0.2), etat: &etat)
            etat.nomChange = true
            retenir("\(j.prenom) \(nom) est devenu\(j.genre == .femme ? "e" : "") \(j.prenom) \(nouveau).", joueur: j, etat: &etat)
            j.nom = nouveau
            if etat.scores[.maudite] >= seuil {
                return "Tu t'appelles désormais \(j.prenom) \(nouveau). Plus personne ne connaît ton passé. La malédiction, elle, a gardé ton adresse."
            }
            return "Tu t'appelles désormais \(j.prenom) \(nouveau). Plus personne ne connaît ton passé. Ta mère, vexée, continue de t'appeler « \(nom) »."

        case .profiterMafia:
            let gain = Int.random(in: 5...40) * 1000
            j.argent += gain
            j.stats.karma -= 5
            modifier(.mafieuse, 6, etat: &etat)
            modifier(.respectee, -4, etat: &etat)
            return "Un coup de fil, deux noms prononcés, et un commerçant te « prête » \(Format.argent(gain)) sans date de remboursement. La réputation des \(nom) s'assombrit encore."

        case .profiterCelebrite:
            let gain = Int.random(in: 3...25) * 1000
            j.argent += gain
            modifier(.celebre, 2, etat: &etat)
            modifier(.ridicule, 3, etat: &etat)
            return "Tu poses pour une marque de chaussettes chauffantes avec le slogan « Les \(nom) ont chaud aux pieds ». \(Format.argent(gain)) sur ton compte, un peu de dignité en moins."
        }
    }
}

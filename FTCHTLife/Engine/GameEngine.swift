import Foundation
import SwiftUI

/// Moteur du jeu : gère la vie en cours, le passage des années, les événements et la sauvegarde.
@MainActor
final class GameEngine: ObservableObject {
    @Published var joueur: Joueur? { didSet { verifierCoherence() } }
    /// Garde-fou contre la récursion de verifierCoherence().
    var enCoherence = false
    @Published var evenementEnCours: EvenementAffiche?
    /// Une du « Journal du monde » à afficher cette année.
    @Published var flashMonde: MondeFlash?

    var fileEvenements: [EvenementAffiche] = []

    init() {
        SignauxModules.configurer()
        charger()
        ShopHooks.emmenagement = { [weak self] nom, _, proprio in
            self?.voisinageEmmenager(logement: .depuis(nom), proprietaire: proprio)
        }
    }

    // MARK: - Nouvelle vie

    func nouvelleVie(prenom: String? = nil, genre: Genre? = nil) {
        let genre = genre ?? Genre.allCases.randomElement()!
        let nom = Donnees.noms.randomElement()!
        let prenomJoueur = (prenom?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? Donnees.prenom(genre)
        let ville = Donnees.villes.randomElement()!

        var relations: [Relation] = [
            Relation(prenom: Donnees.prenom(.femme), nom: nom, genre: .femme, type: .mere,
                     age: Int.random(in: 18...44), lien: Int.random(in: 50...100), argent: Int.random(in: 0...80000)),
            Relation(prenom: Donnees.prenom(.homme), nom: nom, genre: .homme, type: .pere,
                     age: Int.random(in: 18...50), lien: Int.random(in: 40...100), argent: Int.random(in: 0...80000)),
        ]
        let nbFreresSoeurs = [0, 0, 1, 1, 2, 3].randomElement()!
        for _ in 0..<nbFreresSoeurs {
            let g = Genre.allCases.randomElement()!
            relations.append(Relation(prenom: Donnees.prenom(g), nom: nom, genre: g,
                                      type: g == .homme ? .frere : .soeur,
                                      age: Int.random(in: 1...12), lien: Int.random(in: 30...90)))
        }

        var j = Joueur(prenom: prenomJoueur, nom: nom, genre: genre, age: 0, ville: ville,
                       stats: Stats.aleatoire(), argent: 0, diplome: .aucun, filiereDiplome: nil,
                       etudes: nil, emploi: nil, relations: relations, journal: [])
        let mere = relations[0], pere = relations[1]
        var lignes = [
            "Tu es " + j.g("né", "née") + " à \(ville). Félicitations, tu existes !",
            "Ta mère s'appelle \(mere.prenom) (\(mere.age) ans) et ton père \(pere.prenom) (\(pere.age) ans).",
        ]
        let fratrie = relations.filter { $0.type == .frere || $0.type == .soeur }
        if !fratrie.isEmpty {
            let noms = fratrie.map { "\($0.prenom) (\($0.age) ans)" }.joined(separator: ", ")
            lignes.append("Tu as \(fratrie.count == 1 ? "un frère ou une sœur" : "des frères et sœurs") : \(noms).")
        }
        lignes.append(Self.phrasesNaissance.randomElement()!)
        j.journal = [Annee(age: 0, lignes: lignes)]
        let lignesModules = modulesNaissance(&j)
        j.journal[0].lignes += lignesModules

        fileEvenements = []
        evenementEnCours = nil
        flashMonde = nil
        joueur = j
        voisinageNouvelleVie()
        sauvegarder()
    }

    static let phrasesNaissance = [
        "Le médecin a dit que tu avais une tête… intéressante.",
        "Ton premier cri a fait aboyer tous les chiens du quartier.",
        "Tu as fait pipi sur la sage-femme. Ça commence bien.",
        "Ton père s'est évanoui pendant l'accouchement. Ta mère ne lui pardonnera jamais.",
        "Tu ressembles beaucoup au facteur. Personne n'en parle.",
    ]

    // MARK: - Tags

    /// Étiquettes décrivant la situation du joueur, utilisées pour filtrer les événements.
    func tags(_ j: Joueur) -> Set<String> {
        var t: Set<String> = [j.genre == .femme ? "female" : "male"]
        if j.age < 6 { t.insert("baby") }
        if j.niveauScolaire != nil && j.age >= 6 { t.insert("school") }
        if j.etudes != nil { t.insert("university") }
        if j.emploi != nil { t.insert("job") }
        if j.age >= 18 { t.insert("adult") }
        if j.age >= 18 && j.emploi == nil && j.etudes == nil && j.age < 65 { t.insert("unemployed") }
        if j.age >= 65 { t.insert("retired") }
        if j.argent >= 100_000 { t.insert("rich") }
        if j.argent < 1000 { t.insert("poor") }
        if !j.amis.isEmpty { t.insert("friend") }
        if j.mere?.vivant == true { t.insert("mother") }
        if j.pere?.vivant == true { t.insert("father") }
        if j.relations.contains(where: { ($0.type == .frere || $0.type == .soeur) && $0.vivant }) { t.insert("siblings") }
        if j.relations.contains(where: { $0.type == .partenaire && $0.vivant }) { t.insert("partner") }
        if j.relations.contains(where: { $0.type == .enfant && $0.vivant }) { t.insert("children") }
        if j.stats.sante < 30 { t.insert("sick") }
        if j.stats.apparence >= 75 { t.insert("attractive") }
        if j.stats.intelligence >= 75 { t.insert("smart") }
        t.formUnion(tagsModules(j))
        return t
    }

    func conditionsRemplies(_ e: Evenement, _ j: Joueur, tags t: Set<String>) -> Bool {
        guard j.age >= e.minAge && j.age <= e.maxAge else { return false }
        if e.unique == true && j.evenementsVus.contains(e.id) { return false }
        guard let c = e.conditions else { return true }
        if c.gender == "male" && j.genre != .homme { return false }
        if c.gender == "female" && j.genre != .femme { return false }
        if let m = c.minMoney, j.argent < m { return false }
        if let m = c.maxMoney, j.argent > m { return false }
        if let r = c.requiresJob, r != t.contains("job") { return false }
        if let r = c.requiresPartner, r != t.contains("partner") { return false }
        if let r = c.requiresSchool, r != (t.contains("school") || t.contains("university")) { return false }
        if let r = c.tags, !Set(r).isSubset(of: t) { return false }
        if let x = c.excludeTags, !Set(x).isDisjoint(with: t) { return false }
        if !conditionsModules(c, j) { return false }
        return true
    }

    // MARK: - Passer une année

    func vieillir() {
        guard var j = joueur, j.vivant, evenementEnCours == nil else { return }
        j.age += 1
        let actionsPassees = j.actionsAnnee
        j.actionsAnnee = []
        var lignes: [String] = []
        let debut = modulesDebutAnnee(&j)
        lignes += debut.lignes
        var decesModules = debut.deces

        // Relations
        for i in j.relations.indices where j.relations[i].vivant {
            j.relations[i].age += 1
            j.relations[i].lien = Stats.borne(j.relations[i].lien + Int.random(in: -4...1))
            let r = j.relations[i]
            if r.age >= 50 && Double.random(in: 0...1) < Self.chanceDeces(age: r.age, sante: 70) {
                j.relations[i].vivant = false
                lignes.append("💀 \(r.designation), \(r.prenom), est \(r.genre == .femme ? "morte" : "mort") à \(r.age) ans.")
                j.stats.bonheur -= r.type.estParent ? 25 : 10
                if r.type.estParent {
                    modulesDecesParent(r, &j)
                } else {
                    SignauxModules.signaler("deces_proche", &j)
                }
            }
        }

        // Scolarité
        switch j.age {
        case 3: lignes.append("Tu entres à la maternelle. Tu as mordu quelqu'un dès le premier jour.")
        case 6: lignes.append("Tu entres à l'école primaire.")
        case 11 where !j.aQuitteEcole: lignes.append("Tu entres au collège. L'acné aussi.")
        case 15 where !j.aQuitteEcole:
            lignes.append("Tu entres au lycée.")
            if j.diplome < .ecoleObligatoire { j.diplome = .ecoleObligatoire }
        case 18 where !j.aQuitteEcole && j.diplome < .bac:
            let reussite = Shkurtaaa.chanceExamen(Double(j.stats.intelligence) / 100 * 0.7 + 0.35 + scolBonusBac(j))
            if Double.random(in: 0...1) < reussite {
                j.diplome = .bac
                j.stats.bonheur += 10
                lignes.append("🎓 Tu as eu ton bac ! Tes parents ont pleuré. De soulagement, surtout.")
                SignauxModules.signaler("bac_obtenu", &j)
            } else {
                lignes.append("Tu as raté ton bac. Tu blâmes le réchauffement climatique.")
                j.stats.bonheur -= 10
                SignauxModules.signaler("bac_rate", &j)
            }
            lignes.append("La scolarité obligatoire est terminée. Va voir l'onglet Occupation.")
        default: break
        }

        // Université
        if var e = j.etudes {
            j.argent -= MondeJournal.prix(e.filiere.fraisAnnuels, categorie: "etudes", etat: j.monde ?? MondeEtat())
            e.annee += 1
            if e.annee > e.filiere.duree {
                j.diplome = max(j.diplome, e.filiere.diplomeObtenu)
                j.filiereDiplome = e.filiere
                j.etudes = nil
                j.stats.bonheur += 15
                lignes.append("🎓 Tu es " + j.g("diplômé", "diplômée") + " en \(e.filiere.nom.lowercased()) ! Il est temps de chercher un vrai travail.")
                SignauxModules.signaler("diplome", &j)
            } else {
                j.etudes = e
                lignes.append("Tu entames ta \(e.annee)e année de \(e.filiere.nom.lowercased()).")
            }
        }

        coherenceSituation(&j)

        // Emploi (module Métiers si l'emploi vient du catalogue, sinon ancien système)
        if j.carriere != nil {
            lignes += anneeCarriere(&j)
        } else if var e = j.emploi {
            let salaire = MondeJournal.salaire(e.salaire, metierId: e.metierId, titre: e.titre, etat: j.monde ?? MondeEtat())
            let net = Int(Double(salaire) * 0.75)
            j.argent += net
            e.annees += 1
            e.performance = Stats.borne(e.performance + Int.random(in: -8...4))
            if e.performance >= 80 && Double.random(in: 0...1) < Shkurtaaa.chancePromotion(0.35) && e.niveau < 4 {
                e.niveau += 1
                e.salaire = Int(Double(e.salaire) * Double.random(in: 1.10...1.25))
                if let m = Donnees.metier(e.metierId) { e.titre = Donnees.titrePromotion(base: m.titre, niveau: e.niveau) }
                e.performance = 50
                lignes.append("📈 Promotion ! Tu es maintenant \(e.titre) à \(Format.argent(e.salaire))/an.")
                SignauxModules.signaler("promotion", &j)
            } else if e.performance <= 10 && Double.random(in: 0...1) < 0.5 {
                lignes.append("📉 Tu as été " + j.g("viré", "virée") + " de ton poste de \(e.titre.lowercased()). Ton patron a dit « bon courage » sans le penser.")
                j.emploi = nil
                j.stats.bonheur -= 15
                SignauxModules.signaler("licenciement", &j)
            }
            if j.emploi != nil { j.emploi = e }
            if j.age >= 65 && j.emploi != nil && Double.random(in: 0...1) < 0.5 {
                lignes.append("Tu prends ta retraite. Ton pot de départ avait des chips premier prix.")
                j.dernierEmploi = j.emploi
                j.emploi = nil
                SignauxModules.signaler("retraite", &j)
            }
        }
        if j.age >= 65 && j.emploi == nil {
            j.argent += Int(18000 * MondeJournal.multiplicateurRetraite(j.monde ?? MondeEtat()))
        }

        // Modules (amour, crime, santé, permis, placements, politique, téléphone, entreprises, biens…)
        let annee = modulesAnnee(&j, actionsPassees: actionsPassees)
        lignes += annee.lignes
        if decesModules == nil { decesModules = annee.deces }

        // Évolution naturelle des stats
        j.stats.bonheur += Int.random(in: -3...3)
        if j.age > 45 { j.stats.sante -= Int.random(in: 0...3) }
        if j.age > 65 { j.stats.sante -= Int.random(in: 1...4) }
        if j.age > 35 { j.stats.apparence -= Int.random(in: 0...2) }
        if j.age < 18 { j.stats.intelligence += Int.random(in: 0...2) }
        j.stats.borner()

        j.journal.append(Annee(age: j.age, lignes: lignes))
        modulesApresJournal(&j)
        if let cause = decesModules {
            mourir(&j, cause: cause)
            joueur = j
            sauvegarder()
            return
        }
        joueur = j

        // Fêtes, suites, secrets, héritages, voisins, puis événements aléatoires
        modulesAvantTirage()
        tirerEvenements()

        // Mort naturelle
        if var j2 = joueur, j2.vivant {
            if j2.stats.sante <= 0 {
                if Shkurtaaa.peutMourir(deVieillesse: false) { mourir(&j2, cause: "de maladie") } else { j2.stats.sante = 1 }
            } else if let cause = causeDecesModules(j2), Shkurtaaa.peutMourir(deVieillesse: false) {
                mourir(&j2, cause: cause)
            } else if Double.random(in: 0...1) < Self.chanceDeces(age: j2.age, sante: j2.stats.sante) * MondeJournal.multiplicateurMortalite(j2.monde ?? MondeEtat()),
                      Shkurtaaa.peutMourir(deVieillesse: true) {
                mourir(&j2, cause: Self.causesNaturelles.randomElement()!)
            }
            joueur = j2
        }
        sauvegarder()
    }

    static let causesNaturelles = [
        "de vieillesse, dans son sommeil",
        "d'une crise cardiaque en regardant un match",
        "d'un AVC pendant une partie de belote",
        "de vieillesse, en râlant contre la météo",
    ]

    nonisolated static func chanceDeces(age: Int, sante: Int) -> Double {
        let base: Double
        if age < 50 { base = 0.0005 }
        else { base = pow(Double(age - 50) / 50, 4) * 0.6 }
        let facteurSante = 1.6 - Double(sante) / 100
        return min(0.95, base * facteurSante)
    }

    func mourir(_ j: inout Joueur, cause: String) {
        guard j.vivant else { return }
        j.vivant = false
        j.causeDeces = cause
        if j.emploi != nil { j.dernierEmploi = j.emploi }
        modulesMort(&j)
        j.emploi = nil
        j.etudes = nil
        if j.journal.isEmpty { j.journal.append(Annee(age: j.age, lignes: [])) }
        j.journal[j.journal.count - 1].lignes.append("⚰️ Tu es " + j.g("mort", "morte") + " \(cause), à \(j.age) ans.")
        fileEvenements = []
        evenementEnCours = nil
    }

    // MARK: - Événements

    func tirerEvenements() {
        guard let j = joueur, j.vivant else { return }
        let t = tags(j)
        let candidats = (BibliothequeEvenements.tous + evenementsModules(j)).filter {
            conditionsRemplies($0, j, tags: t) && VieSysteme.evenementAutorise($0, tags: t)
        }
        // Au plus 3 événements à choix par année : d'abord les suites de ses choix, puis le hasard.
        limiterFileEvenements()
        let place = Self.maxEvenementsAChoix - fileEvenements.count - (evenementEnCours == nil ? 0 : 1)
        var nombre = 0
        if Double.random(in: 0...1) < 0.85 { nombre += 1 }
        if Double.random(in: 0...1) < 0.40 { nombre += 1 }
        if j.age < 3 && nombre > 1 { nombre = 1 }
        nombre = min(nombre, max(0, place))
        if candidats.isEmpty { nombre = 0 }

        var dejaPris: Set<String> = []
        for _ in 0..<nombre {
            let restants = candidats.filter { !dejaPris.contains($0.id) }
            guard let e = Self.tirage(restants, poids: { self.poidsEvenement($0, j) }) else { break }
            dejaPris.insert(e.id)
            declencher(e)
        }
        if evenementEnCours == nil, !fileEvenements.isEmpty {
            evenementEnCours = fileEvenements.removeFirst()
        }
    }

    func declencher(_ e: Evenement) {
        guard var j = joueur else { return }
        if e.unique == true { j.evenementsVus.append(e.id) }
        let texte = remplir(e.text, j)
        if let choix = e.choices, !choix.isEmpty {
            joueur = j
            fileEvenements.append(EvenementAffiche(evenement: e, texte: texte))
        } else {
            ajouterLigne(&j, texte)
            if let eff = e.effects { appliquer(eff, &j) }
            modulesApresEvenementSimple(e, &j)
            joueur = j
        }
    }

    /// Le joueur choisit une option dans l'événement en cours.
    func choisir(_ index: Int) {
        guard var aff = evenementEnCours, aff.resultat == nil,
              let choix = aff.evenement.choices, choix.indices.contains(index),
              var j = joueur else { return }
        let c = choix[index]
        if Secrets.estCarte(aff.evenement.id) {
            let r = Secrets.resoudre(evenementId: aff.evenement.id, choix: index, joueur: &j)
            ajouterLigne(&j, aff.texte + " → " + c.label + ". " + r.texte)
            joueur = j
            aff.resultat = r.texte
            evenementEnCours = aff
            sauvegarder()
            return
        }
        let issue = Self.tirage(c.outcomes)
        let resultat = remplir(issue?.text ?? "Il ne se passe rien.", j)
        ajouterLigne(&j, aff.texte + " → " + c.label + ". " + resultat)
        if let eff = issue?.effects { appliquer(eff, &j) }
        modulesApresChoix(aff.evenement, choix: index, c, issue: issue, &j)
        joueur = j
        aff.resultat = resultat
        evenementEnCours = aff
        sauvegarder()
    }

    /// Ferme l'événement en cours et passe au suivant.
    func fermerEvenement() {
        if let j = joueur, !j.vivant {
            evenementEnCours = nil
            fileEvenements = []
            return
        }
        evenementEnCours = fileEvenements.isEmpty ? nil : fileEvenements.removeFirst()
    }

    /// Tire un élément au hasard en tenant compte de son poids.
    nonisolated static func tirage<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0.0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.first }
        var r = Double.random(in: 0..<total)
        for element in liste {
            r -= max(0, poids(element))
            if r < 0 { return element }
        }
        return liste.last
    }

    nonisolated static func tirage(_ issues: [Issue]) -> Issue? {
        tirage(issues) { $0.chance ?? 1 }
    }

    // MARK: - Effets

    func appliquer(_ eff: Effets, _ j: inout Joueur) {
        j.stats.sante += eff.health ?? 0
        j.stats.bonheur += eff.happiness ?? 0
        j.stats.intelligence += eff.smarts ?? 0
        j.stats.apparence += eff.looks ?? 0
        j.stats.karma += eff.karma ?? 0
        j.argent += eff.money ?? 0
        j.stats.borner()
        modulesAppliquer(eff, &j)
        if let liens = eff.relationships {
            for (cle, delta) in liens {
                for i in j.relations.indices where j.relations[i].vivant && Self.correspond(j.relations[i].type, cle) {
                    j.relations[i].lien = Stats.borne(j.relations[i].lien + delta)
                }
            }
        }
        if eff.newFriend == true {
            let g = Genre.allCases.randomElement()!
            let ami = Relation(prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement()!, genre: g, type: .ami,
                               age: max(1, j.age + Int.random(in: -2...2)), lien: Int.random(in: 50...80))
            j.relations.append(ami)
            ajouterLigne(&j, "Tu t'es fait " + (g == .femme ? "une nouvelle amie" : "un nouvel ami") + " : \(ami.prenom).")
        }
        if let cause = eff.death, Shkurtaaa.peutMourir(deVieillesse: false) {
            mourir(&j, cause: cause)
        } else if j.stats.sante <= 0, Shkurtaaa.peutMourir(deVieillesse: false) {
            mourir(&j, cause: "de ses blessures")
        }
    }

    nonisolated static func correspond(_ type: TypeRelation, _ cle: String) -> Bool {
        switch cle {
        case "mother": return type == .mere
        case "father": return type == .pere
        case "parent": return type.estParent
        case "sibling": return type == .frere || type == .soeur
        case "friend": return type == .ami
        case "partner": return type == .partenaire
        case "child": return type == .enfant
        default: return false
        }
    }

    func ajouterLigne(_ j: inout Joueur, _ texte: String) {
        if j.journal.isEmpty { j.journal.append(Annee(age: j.age, lignes: [])) }
        j.journal[j.journal.count - 1].lignes.append(texte)
    }

    /// Remplace les mots-clés {prenom}, {mere}, {pere}, {ami}, {ville}, {fratrie}, {e} (accord féminin).
    func remplir(_ texte: String, _ j: Joueur) -> String {
        var t = modulesRemplir(texte, j)
        t = t.replacingOccurrences(of: "{prenom}", with: j.prenom)
        t = t.replacingOccurrences(of: "{nom}", with: j.nom)
        t = t.replacingOccurrences(of: "{ville}", with: j.ville)
        t = t.replacingOccurrences(of: "{mere}", with: j.mere?.prenom ?? "ta mère")
        t = t.replacingOccurrences(of: "{pere}", with: j.pere?.prenom ?? "ton père")
        let parents = j.relations.filter { $0.type.estParent && $0.vivant }
        t = t.replacingOccurrences(of: "{parent}", with: choixStable(parents, j.age)?.prenom ?? "ta tante")
        t = t.replacingOccurrences(of: "{partenaire}", with: j.relations.first { $0.type == .partenaire && $0.vivant }?.prenom ?? "ton crush")
        t = t.replacingOccurrences(of: "{metier}", with: j.emploi?.titre.lowercased() ?? "glandeur professionnel")
        t = t.replacingOccurrences(of: "{ami}", with: choixStable(j.amis, j.age)?.prenom ?? "ton pote")
        let fratrie = j.relations.filter { ($0.type == .frere || $0.type == .soeur) && $0.vivant }
        t = t.replacingOccurrences(of: "{fratrie}", with: choixStable(fratrie, j.age)?.prenom ?? "ton cousin")
        t = t.replacingOccurrences(of: "{e}", with: j.genre == .femme ? "e" : "")
        return t
    }

    // MARK: - Sauvegarde

    private var urlSauvegarde: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ftchtlife-sauvegarde.json")
    }

    func sauvegarder() {
        guard let j = joueur, let data = try? JSONEncoder().encode(j) else { return }
        try? data.write(to: urlSauvegarde, options: .atomic)
    }

    private func charger() {
        guard let data = try? Data(contentsOf: urlSauvegarde),
              let j = try? JSONDecoder().decode(Joueur.self, from: data) else { return }
        joueur = j
    }

    func effacerVie() {
        joueur = nil
        flashMonde = nil
        evenementEnCours = nil
        fileEvenements = []
        try? FileManager.default.removeItem(at: urlSauvegarde)
    }

    /// Modifie le joueur en cours et sauvegarde.
    func modifier(_ action: (inout Joueur) -> Void) {
        guard var j = joueur else { return }
        action(&j)
        j.argent = Shkurtaaa.argent(j.argent)
        revesMettreAJour(&j, etat: \.reves)
        j.stats.borner()
        joueur = j
        sauvegarder()
    }
}

enum Format {
    static func argent(_ montant: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "'"
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: montant)) ?? "\(montant)") + " €"
    }
}

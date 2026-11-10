import Foundation
import SwiftUI

// Suivi des trophées : regarde la vie en cours, compte les signaux, débloque les trophées
// et applique les bonus de départ. Branchement : docs/TROPHEES.md.

/// Branchements optionnels que le fil moteur renseigne au lancement de l'app (voir docs/TROPHEES.md).
/// Par défaut ils ne renvoient rien : le module marche seul avec ce qu'il déduit du joueur.
enum TropheesBranchements {
    /// Compteurs de signaux de la vie en cours (ex. `{ $0.repercussions?.compteurs ?? [:] }`).
    static var compteurs: (Joueur) -> [String: Int] = { _ in [:] }
    /// Drapeaux (souvenirs) actifs (ex. `{ Set($0.repercussions?.flags.keys ?? [:].keys) }`).
    static var drapeaux: (Joueur) -> Set<String> = { _ in [] }
    /// Tags ajoutés par les modules, en plus de `GameEngine.tags`.
    static var tags: (Joueur) -> Set<String> = { _ in [] }
    /// Le mode Shkurtaaa est-il actif ? (ex. `{ Shkurtaaa.actif }`).
    static var modeShkurtaaa: () -> Bool = { false }
}

/// Un trophée obtenu.
struct TropheeObtenu: Codable, Equatable {
    var date: Date
    /// Nom du personnage qui l'a obtenu, et son âge.
    var personnage: String
    var age: Int
    var enShkurtaaa: Bool
}

/// Résumé compact du joueur, pour voir ce qui a changé d'une fois sur l'autre.
struct TropheesResume: Codable, Equatable {
    struct Proche: Codable, Equatable {
        var id: UUID
        var type: String
        var vivant: Bool
    }
    var age: Int
    var vivant: Bool
    var argent: Int
    var diplome: Int
    var metierId: String?
    var niveau: Int
    var proches: [Proche]
    var lignesJournal: Int

    init(_ j: Joueur) {
        age = j.age
        vivant = j.vivant
        argent = j.argent
        diplome = j.diplome.rawValue
        metierId = j.emploi?.metierId
        niveau = j.emploi?.niveau ?? 0
        proches = j.relations.map { Proche(id: $0.id, type: $0.type.rawValue, vivant: $0.vivant) }
        lignesJournal = j.journal.reduce(0) { $0 + $1.lignes.count }
    }
}

/// État de la vie en cours, vu par les trophées.
struct TropheesVie: Codable, Equatable {
    var id: String
    var compteurs: [String: Int] = [:]
    /// Dernière valeur connue de chaque compteur (pour reporter les hausses dans le total).
    var vus: [String: Int] = [:]
    /// Âge du joueur la première / la dernière fois que chaque signal est arrivé.
    var premierAge: [String: Int] = [:]
    var dernierAge: [String: Int] = [:]
    var dernier: TropheesResume?
    var vivant = true
}

/// Tout ce qui est gardé d'une vie à l'autre. Fichier séparé de la sauvegarde de la vie.
struct TropheesSauvegarde: Codable, Equatable {
    var obtenus: [String: TropheeObtenu] = [:]
    /// Compteurs cumulés sur toutes les vies (`vie`, `mort`, `abandon`, `annee` + tous les signaux).
    var total: [String: Int] = [:]
    var causesDeMort: [String] = []
    /// Ids des trophées dont le bonus de départ est équipé.
    var bonusEquipes: [String] = []
    var vie: TropheesVie?
    /// Records.
    var ageRecord = 0
    var fortuneRecord = 0
}

@MainActor
final class Trophees: ObservableObject {
    static let shared = Trophees()

    /// Nombre de bonus de départ équipables en même temps.
    static let maxBonus = 3

    @Published private(set) var etat = TropheesSauvegarde()
    /// Trophées obtenus récemment, à afficher en bandeau.
    @Published var aAnnoncer: [TropheeDef] = []

    private init() {
        charger()
    }

    // MARK: - Lecture

    func estObtenu(_ id: String) -> Bool { etat.obtenus[id] != nil }
    var nombreObtenus: Int { etat.obtenus.keys.filter { CatalogueTrophees.parId[$0] != nil }.count }
    var bonusDisponibles: [TropheeDef] { CatalogueTrophees.tous.filter { $0.bonus != nil && estObtenu($0.id) } }
    func estEquipe(_ id: String) -> Bool { etat.bonusEquipes.contains(id) }

    func basculerBonus(_ id: String) {
        if let i = etat.bonusEquipes.firstIndex(of: id) {
            etat.bonusEquipes.remove(at: i)
        } else if estObtenu(id), etat.bonusEquipes.count < Self.maxBonus {
            etat.bonusEquipes.append(id)
        }
        sauvegarder()
    }

    // MARK: - Signaux directs

    /// Un module peut signaler une action directement aux trophées (si elle ne passe pas par les répercussions).
    func signaler(_ signal: String, _ n: Int = 1) {
        guard var vie = etat.vie else { return }
        vie.compteurs[signal, default: 0] += n
        etat.vie = vie
        sauvegarder()
    }

    // MARK: - Observation du moteur

    /// À appeler à chaque changement du joueur (le modificateur `.suiviTrophees()` le fait).
    func observer(_ engine: GameEngine) {
        guard let j = engine.joueur else {
            // Vie effacée : si le personnage était encore vivant, c'est un abandon.
            if let vie = etat.vie, vie.vivant {
                etat.total["abandon", default: 0] += 1
                etat.vie = nil
                sauvegarder()
            } else if etat.vie != nil {
                etat.vie = nil
                sauvegarder()
            }
            return
        }

        let idVie = j.journal.first?.id.uuidString ?? "\(j.nomComplet)"
        if etat.vie?.id != idVie {
            if let ancienne = etat.vie, ancienne.vivant { etat.total["abandon", default: 0] += 1 }
            let estNaissance = j.age == 0 && j.journal.count <= 1 && j.vivant
            var vie = TropheesVie(id: idVie)
            vie.dernier = TropheesResume(j)
            vie.vivant = j.vivant
            etat.vie = vie
            etat.total["vie", default: 0] += 1
            if estNaissance && !etat.bonusEquipes.isEmpty {
                appliquerBonus(engine)
                return // le changement du joueur rappellera observer()
            }
        }

        guard var vie = etat.vie else { return }
        let avant = vie.dernier ?? TropheesResume(j)
        let apres = TropheesResume(j)
        deduireSignaux(avant: avant, apres: apres, j: j, vie: &vie)
        vie.dernier = apres

        // Report des hausses de compteurs dans le total.
        let compteurs = compteursVie(vie, j)
        for (cle, valeur) in compteurs {
            let ancien = vie.vus[cle] ?? 0
            if valeur > ancien {
                etat.total[cle, default: 0] += valeur - ancien
                vie.vus[cle] = valeur
                if vie.premierAge[cle] == nil { vie.premierAge[cle] = j.age }
                vie.dernierAge[cle] = j.age
            }
        }

        let vientDeMourir = vie.vivant && !j.vivant
        vie.vivant = j.vivant
        etat.vie = vie

        etat.ageRecord = max(etat.ageRecord, j.age)
        etat.fortuneRecord = max(etat.fortuneRecord, j.argent)

        if vientDeMourir {
            etat.total["mort", default: 0] += 1
            if let cause = j.causeDeces?.lowercased(), !etat.causesDeMort.contains(cause) {
                etat.causesDeMort.append(cause)
            }
            // Une chance sur 25 que la mort tombe pile le jour de l'anniversaire.
            if Int.random(in: 0..<25) == 0 {
                vie.compteurs["mort_anniversaire", default: 0] += 1
                vie.vus["mort_anniversaire", default: 0] += 1
                vie.premierAge["mort_anniversaire"] = j.age
                vie.dernierAge["mort_anniversaire"] = j.age
                etat.total["mort_anniversaire", default: 0] += 1
                etat.vie = vie
            }
        }

        verifier(j, engine: engine, mort: vientDeMourir)
        sauvegarder()
    }

    /// Signaux déduits des changements du joueur, en attendant que le moteur et les modules les émettent eux-mêmes.
    /// On garde le maximum entre ce compteur et celui du moteur : pas de double comptage.
    private func deduireSignaux(avant: TropheesResume, apres: TropheesResume, j: Joueur, vie: inout TropheesVie) {
        func plus(_ s: String, _ n: Int = 1) { vie.compteurs[s, default: 0] += n }

        if apres.age > avant.age { plus("annee", apres.age - avant.age) }

        // Travail
        if let m = apres.metierId, m != avant.metierId { plus("embauche") }
        if let m = apres.metierId, m == avant.metierId, apres.niveau > avant.niveau { plus("promotion", apres.niveau - avant.niveau) }
        if avant.metierId != nil && apres.metierId == nil && apres.vivant {
            let nouvelles = nouvellesLignes(j, depuis: avant.lignesJournal)
            if apres.age >= 65 || nouvelles.contains(where: { $0.contains("retraite") }) {
                plus("retraite")
            } else if nouvelles.contains(where: { $0.contains("📉") || $0.contains("viré") }) {
                plus("licenciement")
            } else {
                plus("demission")
            }
        }

        // Études
        if apres.diplome > avant.diplome {
            if apres.diplome == Diplome.bac.rawValue { plus("bac_obtenu") }
            if apres.diplome > Diplome.bac.rawValue { plus("diplome") }
        }

        // Proches
        let anciens = Dictionary(avant.proches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for p in apres.proches {
            if let a = anciens[p.id] {
                if a.vivant && !p.vivant {
                    if p.type == "mere" || p.type == "pere" { plus("deces_parent") }
                    else { plus("deces_proche") }
                    if p.type == "partenaire" { plus("veuvage") }
                }
                if a.type == "partenaire" && p.type == "ex" { plus("rupture") }
            } else {
                switch p.type {
                case "partenaire": plus("couple")
                case "enfant": plus("naissance_enfant")
                case "ami": plus("nouvel_ami")
                default: break
                }
            }
        }
    }

    private func nouvellesLignes(_ j: Joueur, depuis n: Int) -> [String] {
        let toutes = j.journal.flatMap { $0.lignes }
        return n < toutes.count ? Array(toutes[n...]) : []
    }

    /// Compteurs de la vie : maximum entre ceux déduits ici et ceux du moteur (répercussions).
    private func compteursVie(_ vie: TropheesVie, _ j: Joueur) -> [String: Int] {
        var c = vie.compteurs
        for (cle, v) in TropheesBranchements.compteurs(j) { c[cle] = max(c[cle] ?? 0, v) }
        return c
    }

    // MARK: - Bonus de départ

    private func appliquerBonus(_ engine: GameEngine) {
        let bonus = etat.bonusEquipes.compactMap { CatalogueTrophees.parId[$0]?.bonus }
        guard !bonus.isEmpty else { return }
        sauvegarder()
        engine.modifier { j in
            for b in bonus {
                j.argent += b.argent ?? 0
                j.stats.sante += b.sante ?? 0
                j.stats.bonheur += b.bonheur ?? 0
                j.stats.intelligence += b.intelligence ?? 0
                j.stats.apparence += b.apparence ?? 0
                j.stats.karma += b.karma ?? 0
                for i in j.relations.indices where j.relations[i].type.estParent {
                    j.relations[i].argent += b.argentParents ?? 0
                    j.relations[i].lien = Stats.borne(j.relations[i].lien + (b.lienParents ?? 0))
                }
                if b.ami == true {
                    let g = Genre.allCases.randomElement()!
                    j.relations.append(Relation(prenom: Donnees.prenom(g), nom: Donnees.noms.randomElement()!, genre: g,
                                                type: .ami, age: 0, lien: 70))
                }
            }
            let noms = bonus.map { $0.titre }.joined(separator: ", ")
            engine.ajouterLigne(&j, "🏆 Bonus de départ : \(noms).")
        }
    }

    // MARK: - Vérification

    private func verifier(_ j: Joueur, engine: GameEngine, mort: Bool) {
        let tags = engine.tags(j).union(TropheesBranchements.tags(j))
        let drapeaux = TropheesBranchements.drapeaux(j)
        let vie = etat.vie ?? TropheesVie(id: "")
        let compteurs = compteursVie(vie, j)
        let triche = TropheesBranchements.modeShkurtaaa()

        // Deux passes : les trophées « collection » dépendent du nombre de trophées obtenus.
        for _ in 0..<2 {
            var nouveaux: [TropheeDef] = []
            for t in CatalogueTrophees.tous where etat.obtenus[t.id] == nil {
                if TropheesEvaluation.rempli(t.condition, j: j, tags: tags, drapeaux: drapeaux, compteurs: compteurs,
                                             premierAge: vie.premierAge, dernierAge: vie.dernierAge,
                                             total: etat.total, causes: etat.causesDeMort.count,
                                             nbTrophees: nombreObtenus, mort: mort, shkurtaaa: triche) {
                    etat.obtenus[t.id] = TropheeObtenu(date: Date(), personnage: j.nomComplet, age: j.age, enShkurtaaa: triche)
                    nouveaux.append(t)
                }
            }
            guard !nouveaux.isEmpty else { break }
            aAnnoncer.append(contentsOf: nouveaux)
        }
    }

    // MARK: - Sauvegarde

    private var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ftchtlife-trophees.json")
    }

    private func sauvegarder() {
        guard let data = try? JSONEncoder().encode(etat) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func charger() {
        guard let data = try? Data(contentsOf: url),
              let e = try? JSONDecoder().decode(TropheesSauvegarde.self, from: data) else { return }
        etat = e
    }

    /// Remet la collection à zéro (bouton dans l'écran Trophées).
    func toutEffacer() {
        let vie = etat.vie
        etat = TropheesSauvegarde()
        etat.vie = vie
        aAnnoncer = []
        sauvegarder()
    }
}

/// Évaluation pure d'une condition (sans état), pour pouvoir la tester facilement.
enum TropheesEvaluation {
    static func niveauDiplome(_ s: String) -> Int? {
        switch s {
        case "aucun": return Diplome.aucun.rawValue
        case "ecoleObligatoire": return Diplome.ecoleObligatoire.rawValue
        case "bac": return Diplome.bac.rawValue
        case "licence": return Diplome.licence.rawValue
        case "master": return Diplome.master.rawValue
        case "doctorat": return Diplome.doctorat.rawValue
        default: return nil
        }
    }

    static func nombreProches(_ j: Joueur, _ cle: String, vivantsSeulement: Bool) -> Int {
        j.relations.filter { r in
            guard !vivantsSeulement || r.vivant else { return false }
            switch cle {
            case "fratrie": return r.type == .frere || r.type == .soeur
            case "parents": return r.type.estParent
            default: return r.type.rawValue == cle
            }
        }.count
    }

    static func rempli(_ c: TropheeCondition, j: Joueur, tags: Set<String>, drapeaux: Set<String>,
                       compteurs: [String: Int], premierAge: [String: Int] = [:], dernierAge: [String: Int] = [:],
                       total: [String: Int], causes: Int, nbTrophees: Int,
                       mort: Bool, shkurtaaa: Bool) -> Bool {
        if c.moment == .mort && !mort { return false }

        if let m = c.compteurs, !m.allSatisfy({ (compteurs[$0.key] ?? 0) >= $0.value }) { return false }
        if let m = c.maxCompteurs, !m.allSatisfy({ (compteurs[$0.key] ?? 0) <= $0.value }) { return false }
        if let m = c.compteursTotal, !m.allSatisfy({ (total[$0.key] ?? 0) >= $0.value }) { return false }
        if let m = c.apresAge, !m.allSatisfy({ cle, age in (dernierAge[cle] ?? -1) >= age }) { return false }
        if let m = c.avantAge, !m.allSatisfy({ cle, age in (premierAge[cle] ?? Int.max) <= age }) { return false }

        if let d = c.drapeaux, !Set(d).isSubset(of: drapeaux) { return false }
        if let d = c.sansDrapeaux, !Set(d).isDisjoint(with: drapeaux) { return false }
        if let t = c.tags, !Set(t).isSubset(of: tags) { return false }
        if let t = c.excludeTags, !Set(t).isDisjoint(with: tags) { return false }

        if c.gender == "male" && j.genre != .homme { return false }
        if c.gender == "female" && j.genre != .femme { return false }
        if let v = c.minAge, j.age < v { return false }
        if let v = c.maxAge, j.age > v { return false }
        if let v = c.minArgent, j.argent < v { return false }
        if let v = c.maxArgent, j.argent > v { return false }

        let s = j.stats
        if let v = c.minSante, s.sante < v { return false }
        if let v = c.maxSante, s.sante > v { return false }
        if let v = c.minBonheur, s.bonheur < v { return false }
        if let v = c.maxBonheur, s.bonheur > v { return false }
        if let v = c.minIntelligence, s.intelligence < v { return false }
        if let v = c.maxIntelligence, s.intelligence > v { return false }
        if let v = c.minApparence, s.apparence < v { return false }
        if let v = c.maxApparence, s.apparence > v { return false }
        if let v = c.minKarma, s.karma < v { return false }
        if let v = c.maxKarma, s.karma > v { return false }

        if let d = c.diplome, let n = niveauDiplome(d), j.diplome.rawValue < n { return false }
        if let d = c.maxDiplome, let n = niveauDiplome(d), j.diplome.rawValue > n { return false }
        if let f = c.filiere, j.filiereDiplome?.rawValue != f { return false }
        if let e = c.emploi, e != (j.emploi != nil) { return false }
        if let m = c.metiers, !m.contains(j.emploi?.metierId ?? "") { return false }
        if let v = c.minNiveau, (j.emploi?.niveau ?? -1) < v { return false }
        if let v = c.minAnneesEmploi, (j.emploi?.annees ?? -1) < v { return false }

        if let m = c.minRelations, !m.allSatisfy({ nombreProches(j, $0.key, vivantsSeulement: true) >= $0.value }) { return false }
        if let m = c.maxRelations, !m.allSatisfy({ nombreProches(j, $0.key, vivantsSeulement: true) <= $0.value }) { return false }
        if let m = c.minRelationsTotal, !m.allSatisfy({ nombreProches(j, $0.key, vivantsSeulement: false) >= $0.value }) { return false }

        if let mots = c.causeContient {
            guard let cause = j.causeDeces?.lowercased(), mots.contains(where: { cause.contains($0.lowercased()) }) else { return false }
        }
        if let p = c.prenomCommencePar, !p.contains(where: { j.prenom.lowercased().hasPrefix($0.lowercased()) }) { return false }

        if let v = c.minCausesDifferentes, causes < v { return false }
        if let v = c.minTrophees, nbTrophees < v { return false }
        if let v = c.shkurtaaa, v != shkurtaaa { return false }
        return true
    }
}

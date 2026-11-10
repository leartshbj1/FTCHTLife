import Foundation

// Branchement du module Métiers (FTCHTLife/Careers) et de la création de perso (FTCHTLife/CharacterCreation).
// L'emploi du module est rangé dans `Joueur.carriere` ; `Joueur.emploi` est tenu à jour en miroir
// (titre, salaire) pour les autres modules qui le lisent.

extension GameEngine {

    // MARK: - Profil

    func profilCarriere() -> CareerProfile {
        guard let j = joueur else {
            return CareerProfile(firstName: "", age: 0, education: .noDiploma)
        }
        return Self.profilCarriere(j)
    }

    static func profilCarriere(_ j: Joueur) -> CareerProfile {
        var p = CareerProfile(firstName: j.prenom, isFemale: j.genre == .femme, age: j.age,
                              education: CareerEducation(diplomeRaw: j.diploma))
        if let f = j.filiereDiplome { p.majors = CareerMajorMapping.majors(forFiliereRaw: f.rawValue) }
        p.licenses = Set(PermisModule.licences(j.permis, age: j.age))
        p.smarts = j.stats.intelligence
        p.looks = j.stats.apparence
        p.health = j.stats.sante
        p.happiness = j.stats.bonheur
        p.karma = j.stats.karma
        p.hasCriminalRecord = !(j.casier?.condamnations.isEmpty ?? true) || !(j.vie?.justice.casier.isEmpty ?? true)
        return p
    }

    // MARK: - Candidature

    func postulerCarriere(_ job: CareerJob) -> String {
        guard var j = joueur, j.vivant else { return "" }
        if j.etudes != nil { return "Tu es en études. Finis-les d'abord (ou abandonne)." }
        if let raison = CasierSysteme.raisonMetierFerme(id: job.id, titre: job.name, casier: j.casier) { return raison }
        let moteur = CareerEngine()
        var rng = SystemRandomNumberGenerator()
        let texte: String
        switch moteur.apply(to: job, profile: Self.profilCarriere(j), using: &rng) {
        case .hired(let etat, let message):
            terminerCarriere(&j, raison: .quit)
            j.carriere = etat
            synchroniserEmploi(&j)
            j.stats.bonheur += 10
            texte = message
            SignauxModules.signaler("embauche", &j)
        case .rejected(let message):
            j.stats.bonheur -= 3
            texte = message
        }
        j.stats.borner()
        ajouterLigne(&j, texte)
        joueur = j
        sauvegarder()
        return texte
    }

    func actionCarriere(_ a: CareerEngine.WorkAction) -> String {
        guard var j = joueur, let etat = j.carriere else { return "" }
        var rng = SystemRandomNumberGenerator()
        let r = CareerEngine().perform(a, job: etat, profile: Self.profilCarriere(j), using: &rng)
        appliquerEffetsCarriere(r.effects, &j)
        if let fin = r.endReason {
            terminerCarriere(&j, raison: fin)
        } else {
            j.carriere = r.job
            synchroniserEmploi(&j)
        }
        j.stats.borner()
        ajouterLigne(&j, r.message)
        joueur = j
        sauvegarder()
        return r.message
    }

    // MARK: - Année de travail

    /// Appelé chaque année par vieillir() : salaire, promotions, licenciements et un éventuel événement de travail.
    func anneeCarriere(_ j: inout Joueur) -> [String] {
        guard let etat = j.carriere else { return [] }
        var lignes: [String] = []
        var rng = SystemRandomNumberGenerator()
        let moteur = CareerEngine()
        let profil = Self.profilCarriere(j)
        var rapport = moteur.advanceYear(etat, profile: profil, using: &rng)
        let secteur = moteur.catalog.career(etat.careerId)?.sector
        let revenu = MondeJournal.salaire(rapport.income, secteur: secteur, etat: j.monde ?? MondeEtat())
        j.argent += Int(Double(revenu) * 0.75)
        rapport.effects.money = nil
        appliquerEffetsCarriere(rapport.effects, &j)
        lignes += rapport.messages
        if rapport.promoted { SignauxModules.signaler("promotion", &j) }
        if let fin = rapport.endReason {
            terminerCarriere(&j, raison: fin)
            if fin == .fired { SignauxModules.signaler("licenciement", &j) }
            if fin == .retired { SignauxModules.signaler("retraite", &j) }
        } else {
            j.carriere = rapport.job
            j.carriere?.actionsThisYear = 0
            synchroniserEmploi(&j)
            if let c = j.carriere, Double.random(in: 0...1) < 0.45,
               let ev = moteur.randomEvent(for: c, using: &rng) {
                fileEvenements.append(EvenementAffiche(evenement: Self.evenementTravail(ev, c, profil), texte: moteur.fill(ev.text, job: c, career: moteur.catalog.career(c.careerId), profile: profil)))
            }
        }
        return lignes
    }

    /// Transforme un événement de travail du module en événement ordinaire (affiché comme les autres).
    static func evenementTravail(_ ev: CareerWorkEvent, _ c: CareerJobState, _ p: CareerProfile) -> Evenement {
        let moteur = CareerEngine()
        let career = moteur.catalog.career(c.careerId)
        let choix = ev.choices.map { ch in
            Choix(label: moteur.fill(ch.label, job: c, career: career, profile: p),
                  outcomes: ch.outcomes.map { o in
                      Issue(chance: Double(o.chance), text: moteur.fill(o.text, job: c, career: career, profile: p), effects: nil)
                  })
        }
        return Evenement(id: "work:" + ev.id, category: "travail", minAge: 0, maxAge: 200, weight: 1,
                         unique: nil, conditions: nil, text: ev.text, effects: nil, choices: choix)
    }

    /// Effets métier d'une issue d'événement de travail (performance, promotion, licenciement…).
    func apresChoixTravail(_ e: Evenement, choix index: Int, issue k: Int?, _ j: inout Joueur) {
        guard e.id.hasPrefix("work:"), let c = j.carriere, let k else { return }
        let id = String(e.id.dropFirst(5))
        guard let ev = CareerCatalog.shared.workEvents.first(where: { $0.id == id }),
              ev.choices.indices.contains(index), ev.choices[index].outcomes.indices.contains(k) else { return }
        let effets = ev.choices[index].outcomes[k].effects
        let r = CareerEngine().applyEffects(effets, to: c)
        appliquerEffetsCarriere(r.personal, &j)
        if let fin = r.endReason {
            terminerCarriere(&j, raison: fin)
            if fin == .fired { SignauxModules.signaler("licenciement", &j) }
        } else {
            j.carriere = r.job
            synchroniserEmploi(&j)
            if r.promoted { SignauxModules.signaler("promotion", &j) }
        }
    }

    // MARK: - Outils

    func appliquerEffetsCarriere(_ e: CareerEffects, _ j: inout Joueur) {
        j.stats.bonheur += e.happiness ?? 0
        j.stats.sante += e.health ?? 0
        j.stats.intelligence += e.smarts ?? 0
        j.stats.apparence += e.looks ?? 0
        j.stats.karma += e.karma ?? 0
        j.argent += e.money ?? 0
        if e.injured == true { j.stats.sante -= 10 }
        j.stats.borner()
    }

    func terminerCarriere(_ j: inout Joueur, raison: CareerEndReason) {
        guard let c = j.carriere else { return }
        let titre = CareerEngine().title(of: c, female: j.genre == .femme)
        j.historiqueCarriere = (j.historiqueCarriere ?? []) + [CareerRecord(careerId: c.careerId, title: titre, company: c.company,
                                                 startAge: max(0, j.age - c.yearsInJob), endAge: j.age,
                                                 endReason: raison, lastSalary: c.salary)]
        j.dernierEmploi = j.emploi
        j.carriere = nil
        j.emploi = nil
    }

    func synchroniserEmploi(_ j: inout Joueur) {
        guard let c = j.carriere else { return }
        let titre = CareerEngine().title(of: c, female: j.genre == .femme)
        j.emploi = Emploi(metierId: c.careerId, titre: titre, salaire: c.salary,
                          annees: c.yearsInJob, performance: c.performance, niveau: c.level)
    }

    // MARK: - Création de perso

    func nouvelleVie(depuis draft: CharacterDraft) {
        let genre: Genre
        switch draft.gender {
        case .male: genre = .homme
        case .female: genre = .femme
        default: genre = Bool.random() ? .homme : .femme
        }
        nouvelleVie(prenom: draft.firstName, genre: genre)
        guard var j = joueur else { return }
        if !draft.lastName.trimmingCharacters(in: .whitespaces).isEmpty {
            j.nom = draft.lastName
            for i in j.relations.indices where ([.mere, .pere, .frere, .soeur] as [TypeRelation]).contains(j.relations[i].type) {
                j.relations[i].nom = draft.lastName
            }
        }
        if !draft.city.isEmpty { j.ville = draft.city }
        let s = draft.finalStats(catalog: .shared)
        j.stats.sante = Shkurtaaa.statNaissance(s.health)
        j.stats.bonheur = Shkurtaaa.statNaissance(s.happiness)
        j.stats.intelligence = Shkurtaaa.statNaissance(s.smarts)
        j.stats.apparence = Shkurtaaa.statNaissance(s.looks)
        j.stats.borner()
        let argentFamille = draft.wealth.familyMoney
        for i in j.relations.indices where j.relations[i].type.estParent {
            j.relations[i].argent = argentFamille / 2
        }
        if !j.journal.isEmpty {
            j.journal[0].lignes[0] = "Tu es " + j.g("né", "née") + " à \(j.ville). Félicitations, tu existes !"
        }
        joueur = j
        sauvegarder()
    }
}

extension Joueur {
    /// Valeur brute du diplôme, pour le module Métiers.
    var diploma: String {
        switch diplome {
        case .aucun: return "aucun"
        case .ecoleObligatoire: return "ecoleObligatoire"
        case .bac: return "bac"
        case .licence: return "licence"
        case .master: return "master"
        case .doctorat: return "doctorat"
        }
    }
}

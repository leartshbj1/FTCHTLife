import Foundation
import SwiftUI

// Branchement des modules dans le moteur.
// Chaque fonction ici est appelée à un endroit précis de GameEngine (vieillir, tags, appliquer, choisir…).
// Les détails de chaque module sont dans docs/<MODULE>.md, section « Branchement ».

/// Signaux envoyés par le moteur et les modules (mariage, promotion, casino_perte…).
/// Ils vont aux répercussions, à la réputation de la famille et aux secrets.
enum SignauxModules {
    static func signaler(_ signal: String, _ j: inout Joueur, choix: Int? = nil, issue: Int? = nil) {
        var etat = j.repercussions ?? RepercussionsEtat()
        Repercussions.signaler(signal, choix: choix, issue: issue, age: j.age, etat: &etat)
        j.repercussions = etat
        guard !signal.hasPrefix("event:") else { return }
        if var rf = j.reputationFamille {
            ReputationFamille.signaler(signal, joueur: j, etat: &rf)
            j.reputationFamille = rf
        }
        if let ligne = Secrets.signaler(signal, joueur: &j) {
            if j.journal.isEmpty { j.journal.append(Annee(age: j.age, lignes: [])) }
            j.journal[j.journal.count - 1].lignes.append(ligne)
        }
    }

    /// Configure les crochets entre modules. Appelé une fois au démarrage.
    static func configurer() {
        // Où chaque module range son état dans Joueur.
        VieSysteme.acces = \.vie
        Competences.acces = \Joueur.competences
        ScolStockage.chemin = \Joueur.scolarite
        TeleStockage.lire = { $0.tele ?? TeleEtat() }
        TeleStockage.ecrire = { j, etat in j.tele = etat }

        // Signaux vers les répercussions.
        VieSysteme.signal = { s, j in signaler(s, &j) }
        Secrets.surSignal = { s, j in
            var etat = j.repercussions ?? RepercussionsEtat()
            Repercussions.signaler(s, age: j.age, etat: &etat)
            j.repercussions = etat
        }
        CasinoSignaux.recepteur = { s, j in signaler(s, &j) }
        PermisModule.signaler = { j, s in signaler(s, &j) }
        VoisinageStockage.signaler = { s, j in signaler(s, &j) }

        // Crime → casier judiciaire.
        VieSysteme.condamnation = { infraction, mois, j in
            var c = j.casier ?? CasierJudiciaire()
            let g: CasierGravite = mois == 0 ? .contravention : (mois < 60 ? .delit : .crime)
            let ligne = CasierSysteme.condamner(&c, infraction: infraction, gravite: g, age: j.age)
            j.casier = c
            return ligne
        }

        // Générations : la réputation de la famille passe à l'héritier.
        VieGenerations.transmission = { ancien, h in
            let rf = ReputationFamille.transmettre(parent: ancien, etat: ancien.reputationFamille ?? ReputationFamille.aleatoire(), heritier: h)
            h.reputationFamille = rf
            return ReputationFamille.lignesNaissance(rf, joueur: h)
        }

        // Mode Shkurtaaa (triche).
        VieBonus.seductionHook = { Shkurtaaa.chanceSeduction($0) }
        VieBonus.arrestationHook = { Shkurtaaa.chanceArrestation($0) }
        VieBonus.evasionHook = { Shkurtaaa.chanceEvasion($0) }
        VieBonus.guerisonHook = { Shkurtaaa.chanceGuerison($0) }
        VieBonus.santeHook = { Shkurtaaa.sante($0) }
        VieBonus.peutMourirHook = { Shkurtaaa.peutMourir(deVieillesse: false) }
        PermisModule.ajusterChanceExamen = { Shkurtaaa.chanceExamen($0) }
        ShopHooks.money = { Shkurtaaa.argent($0) }
        ShopHooks.canAfford = { Shkurtaaa.peutPayer($0, solde: $1) }

        // Trophées.
        TropheesBranchements.compteurs = { $0.repercussions?.compteurs ?? [:] }
        TropheesBranchements.drapeaux = { Set(($0.repercussions?.flags ?? [:]).keys) }
        TropheesBranchements.modeShkurtaaa = { Shkurtaaa.actif }
    }
}

extension GameEngine {

    // MARK: - Naissance

    func modulesNaissance(_ j: inout Joueur) -> [String] {
        var lignes: [String] = []
        for k in [\Stats.sante, \Stats.bonheur, \Stats.intelligence, \Stats.apparence] {
            j.stats[keyPath: k] = Shkurtaaa.statNaissance(j.stats[keyPath: k])
        }
        lignes += VieSysteme.naissance(&j)
        let rf = ReputationFamille.aleatoire()
        j.reputationFamille = rf
        lignes += ReputationFamille.lignesNaissance(rf, joueur: j)
        j.placements = PlacementsMoteur.nouveau()
        return lignes
    }

    // MARK: - Tags

    func tagsModules(_ j: Joueur) -> Set<String> {
        var t: Set<String> = []
        t.formUnion(VieSysteme.tags(j))
        t.formUnion(ExpatMoteur.tags(j.etatExpat, j))
        t.formUnion(CasierSysteme.tags(j.casier))
        t.formUnion(Competences.tags(j))
        t.formUnion(EntrepriseMoteur.tags(j.entreprises))
        t.formUnion(LoisirsRegles.tags(j.loisirs))
        t.formUnion(PermisModule.tags(j.permis, age: j.age))
        t.formUnion(PhoneEngine.tags(j.telephone))
        t.formUnion(PlacementsMoteur.tags(j.placements ?? PlacementsEtat()))
        t.formUnion(PolMoteur.tags(j.politique))
        t.formUnion(ReputationFamille.tags(j.reputationFamille))
        t.formUnion(RetraiteSysteme.tags(j.retraite))
        t.formUnion(Secrets.tags(j))
        t.formUnion(Successions.tags(j.succession))
        t.formUnion(GameEngine.teleTags(j))
        t.formUnion(ScolRegles.tags(j))
        t.formUnion(CasinoSysteme.tags(j))
        t.formUnion(RevesMoteur.tags(j.reves))
        t.formUnion(MondeJournal.tagsJoueur(j.monde ?? MondeEtat()))
        t.formUnion(tagsAnimaux(j, cle: \.animaux))
        if let v = VoisinageStockage.lire(j) { t.formUnion(VoisinageMoteur.tags(v)) }
        return t
    }

    func conditionsModules(_ c: ConditionsEvenement, _ j: Joueur) -> Bool {
        if !Competences.aLeNiveau(c.skills, j) { return false }
        if !Repercussions.drapeauxOK(flags: c.flags, excludeFlags: c.excludeFlags, etat: j.repercussions) { return false }
        return true
    }

    // MARK: - Année

    /// Début d'année, juste après la remise à zéro des actions.
    func modulesDebutAnnee(_ j: inout Joueur) -> (lignes: [String], deces: String?) {
        j.argent = Shkurtaaa.argent(j.argent)
        let casino = CasinoSysteme.finAnnee(&j)
        return (casino.lignes, casino.deces)
    }

    /// Après le bloc Emploi : tous les modules qui vivent leur année.
    func modulesAnnee(_ j: inout Joueur, actionsPassees: [String]) -> (lignes: [String], deces: String?) {
        var lignes: [String] = []
        var deces: String?

        lignes += scolPasserAnnee(&j, actionsPassees: actionsPassees)
        var expat = j.etatExpat
        lignes += ExpatMoteur.finAnnee(&j, &expat)
        j.etranger = expat
        lignes += VieSysteme.vieillir(&j)
        if var c = j.casier {
            lignes += CasierSysteme.passerAnnee(&c, joueur: j, enPrison: j.vie?.justice.enPrison ?? false)
            j.casier = c
        }

        var permis = j.permis ?? PermisEtat()
        let bilanPermis = PermisModule.passerAnnee(&j, &permis)
        j.permis = permis
        lignes += bilanPermis.lignes
        if let m = bilanPermis.mort { deces = m }

        var pl = j.placements ?? PlacementsMoteur.nouveau()
        let ctx = PlacementsContexte(age: j.age, salaireAnnuel: j.emploi?.salaire ?? 0,
                                     multiplicateurs: MondeJournal.marches(j.monde ?? MondeEtat()),
                                     triche: Shkurtaaa.actif)
        let bilanPl = PlacementsMoteur.passerAnnee(&pl, argent: &j.argent, contexte: ctx)
        j.placements = pl
        lignes += bilanPl.lignes
        j.stats.bonheur += bilanPl.bonheur
        j.stats.karma += bilanPl.karma

        if j.age >= 38 || j.retraite != nil {
            var r = j.retraite ?? RetraiteEtat()
            let b = RetraiteSysteme.annee(&j, &r)
            j.retraite = r
            lignes += b.lignes
            for s in b.signaux { SignauxModules.signaler(s, &j) }
        }

        lignes += passerAnneeLoisirs(&j, etat: \.loisirs)

        var pol = j.politique ?? PolEtat()
        lignes += PolMoteur.passerAnnee(&j, &pol)
        j.politique = pol

        var tel = j.telephone ?? PhoneEtat()
        lignes += PhoneEngine.passerAnnee(&j, &tel, engine: self)
        j.telephone = tel

        lignes += bilanEntreprises(&j)
        passageAnneeBoutique(&j)

        if var rf = j.reputationFamille {
            let a = ReputationFamille.annee(joueur: j, etat: &rf)
            j.reputationFamille = rf
            lignes += a.lignes
            appliquer(a.effets, &j)
        }

        lignes += Competences.finAnnee(&j)
        j.stats.borner()
        return (lignes, deces)
    }

    /// Juste après l'écriture de l'année dans le journal.
    func modulesApresJournal(_ j: inout Joueur) {
        animauxAnnee(&j, cle: \.animaux)
        revesMettreAJour(&j, etat: \.reves)

        var monde = j.monde ?? MondeEtat()
        let rapport = MondeJournal.nouvelleAnnee(&monde, age: j.age, tagsJoueur: tags(j), remplir: { [j] in self.remplir($0, j) })
        j.monde = monde
        for ligne in rapport.lignes { ajouterLigne(&j, ligne) }
        for eff in rapport.effets { appliquer(eff, &j) }
        flashMonde = rapport.flash
        let m = monde
        ShopHooks.priceMultiplier = { MondeJournal.multiplicateurPrix($0, etat: m) }
    }

    /// Juste avant le tirage des événements aléatoires : fêtes, suites, secrets, héritages, voisins.
    func modulesAvantTirage() {
        guard var j = joueur else { return }
        let t = tags(j)

        var etatFetes = j.fetes ?? FetesEtat()
        let fetes = Fetes.evenementsDeLAnnee(age: j.age, etat: &etatFetes,
                                             drapeaux: Set((j.repercussions?.flags ?? [:]).keys)) {
            self.conditionsRemplies($0, j, tags: t)
        }
        j.fetes = etatFetes

        var rep = j.repercussions ?? RepercussionsEtat()
        let suites = Repercussions.echeances(age: j.age, etat: &rep) { self.conditionsRemplies($0, j, tags: t) }
        j.repercussions = rep

        let secrets = Secrets.passerAnnee(joueur: &j)
        secrets.lignes.forEach { ajouterLigne(&j, $0) }

        var suc = j.succession ?? SuccessionEtat()
        let episodes = Successions.episodesDeLAnnee(joueur: j, etat: &suc)
        j.succession = suc

        joueur = j
        fileEvenements += secrets.evenements.map { EvenementAffiche(evenement: $0, texte: $0.text) }
        (fetes + suites + episodes).forEach { declencher($0) }
        voisinageAnnee()
    }

    /// Événements en plus de la bibliothèque (crises du monde, retombées télé).
    func evenementsModules(_ j: Joueur) -> [Evenement] {
        MondeJournal.evenementsActifs(j.monde ?? MondeEtat()) + TeleBibliotheque.evenements
    }

    func poidsEvenement(_ e: Evenement, _ j: Joueur) -> Double {
        MondeJournal.poidsEvenement(e, etat: j.monde ?? MondeEtat())
    }

    func causeDecesModules(_ j: Joueur) -> String? {
        VieSysteme.causeDeces(j)
    }

    // MARK: - Événements

    /// Effets en plus des stats (drapeaux, compétences, casier, réputation, rêves…).
    func modulesAppliquer(_ eff: Effets, _ j: inout Joueur) {
        var etat = j.repercussions ?? RepercussionsEtat()
        Repercussions.appliquerDrapeaux(poser: eff.setFlags, retirer: eff.clearFlags, age: j.age, etat: &etat)
        for id in eff.followUps ?? [] { Repercussions.programmer(id: id, age: j.age, etat: &etat) }
        j.repercussions = etat

        for ligne in Competences.appliquer(eff.skills, &j) { ajouterLigne(&j, ligne) }

        if let ce = eff.casier {
            var c = j.casier ?? CasierJudiciaire()
            for ligne in CasierSysteme.appliquer(ce, &c, age: j.age) { ajouterLigne(&j, ligne) }
            j.casier = c
        }
        if let d = eff.familyRep, var rf = j.reputationFamille {
            ReputationFamille.modifier(d, etat: &rf, joueur: j)
            j.reputationFamille = rf
        }
        if let m = eff.dreamMarks { RevesMoteur.marquer(&j.reves, m) }
        j.argent = Shkurtaaa.argent(j.argent)
    }

    /// Après un choix du joueur dans un événement (l'issue est déjà appliquée).
    func modulesApresChoix(_ e: Evenement, choix index: Int, _ c: Choix, issue: Issue?, _ j: inout Joueur) {
        let k = issue.flatMap { i in c.outcomes.firstIndex(of: i) }
        SignauxModules.signaler("event:\(e.id)", &j, choix: index, issue: k)
        if let fx = issue?.effects?.vie {
            for ligne in VieSysteme.apresIssue(evenementId: e.id, effets: fx, &j) { ajouterLigne(&j, ligne) }
        }
        for ligne in Competences.apresChoix(c, &j) { ajouterLigne(&j, ligne) }
        if e.id.hasPrefix("suc_") {
            var etat = j.succession ?? SuccessionEtat()
            Successions.apresChoix(evenementId: e.id, choix: index, issue: k ?? 0, joueur: j, etat: &etat)
            j.succession = etat
        }
        voisinageApresChoix(e, choix: index, issue: issue, &j)
        apresChoixTravail(e, choix: index, issue: k, &j)
        revesMettreAJour(&j, etat: \.reves)
    }

    /// Événement sans choix.
    func modulesApresEvenementSimple(_ e: Evenement, _ j: inout Joueur) {
        SignauxModules.signaler("event:\(e.id)", &j)
        if let fx = e.effects?.vie {
            for ligne in VieSysteme.apresIssue(evenementId: e.id, effets: fx, &j) { ajouterLigne(&j, ligne) }
        }
    }

    func modulesRemplir(_ texte: String, _ j: Joueur) -> String {
        guard texte.contains("{") else { return texte }
        var t = ReputationFamille.remplir(texte, etat: j.reputationFamille)
        t = VieSysteme.remplir(t, j)
        t = GameEngine.teleRemplir(t, j)
        return t
    }

    // MARK: - Mort

    func modulesMort(_ j: inout Joueur) {
        if var rf = j.reputationFamille {
            _ = ReputationFamille.bilanDeVie(joueur: j, etat: &rf)
            j.reputationFamille = rf
        }
    }

    /// Mort d'un parent : la succession remplace l'héritage simple.
    func modulesDecesParent(_ r: Relation, _ j: inout Joueur) {
        var etat = j.succession ?? SuccessionEtat()
        let autreParent = j.relations.first { $0.type.estParent && $0.id != r.id && $0.vivant }
        Successions.ouvrirPourParent(defunt: r, joueur: j, autreParentVivant: autreParent != nil, etat: &etat)
        j.succession = etat
        SignauxModules.signaler("deces_parent", &j)
    }
}

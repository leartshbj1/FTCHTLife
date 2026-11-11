import SwiftUI

/// Écran ouvert (en feuille) quand on touche une entrée d'un menu.
/// Les écrans qui ont déjà leur barre et leur bouton « Fermer » sont affichés tels quels ;
/// les listes « à pousser » sont habillées par `Feuille`.
struct EcranModule: View {
    @EnvironmentObject var engine: GameEngine
    let module: ModuleJeu

    var body: some View {
        if let j = engine.joueur {
            contenu(j)
        } else {
            Feuille(titre: module.titre) { Text("Aucune vie en cours.") }
        }
    }

    @ViewBuilder
    private func contenu(_ j: Joueur) -> some View {
        switch module {
        // Carrière
        case .ecole: EcoleView()
        case .vieAuBahut: Feuille(titre: "Vie au bahut") { ScolVieView() }
        case .universite: UniversiteView()
        case .offresEmploi: OffresEmploiView()
        case .monTravail: MonTravailView()
        case .entreprise: EntreprisesView().onAppear { engine.normaliserEntreprises() }
        case .politique: PolitiqueView(etat: \.politique)
        case .retraite: RetraiteView(chemin: \.retraite, signaler: Self.signaler)

        // Biens
        case .boutique: ShopView()
        case .mesBiens: Feuille(titre: "Mes biens") { ShopOwnedListView() }
        case .placements: placements(j)
        case .testament: testament(j)
        case .heritages: Feuille(titre: "Héritages") { SuccessionDossierView(etat: j.succession) }

        // Relations
        case .famille: ListeRelationsView(filtre: .famille)
        case .amour: ListeRelationsView(filtre: .amour)
        case .amis: ListeRelationsView(filtre: .amis)
        case .rencontres: Feuille(titre: "Rencontres") { VieRencontresView() }
        case .telephone: TelephoneView(chemin: \.telephone)
        case .voisins: VoisinageView()
        case .animaux: AnimauxView(cle: \.animaux)
        case .reputationFamille: ReputationFamilleEcran()
        case .secrets: Feuille(titre: "Carnet des secrets") { CarnetSecretsView() }

        // Activités
        case .loisirs: LoisirsEcran(etat: \.loisirs, signaler: Self.signaler)
        case .projets: Feuille(titre: "Projets perso") { ProjetsView() }
        case .sante: Feuille(titre: "Santé") { VieSanteView() }
        case .television: TeleView()
        case .casino: CasinoView()
        case .permis: PermisView(chemin: \.permis)
        case .voyages: VoyagesView()
        case .etranger:
            ExpatView(etat: { $0.etatExpat }, ecrire: { j, e in j.etranger = e },
                      visaToujoursAccepte: Shkurtaaa.actif)
        case .crime: Feuille(titre: "Crime") { VieCrimeView() }
        case .prison: PrisonEcran()
        case .casier: CasierView(chemin: \.casier)

        // Moi
        case .profil: ProfilView()
        case .competences: CompetencesView()
        case .trophees: TropheesView()
        case .journalDuMonde:
            MondeJournalView(etat: j.monde ?? MondeEtat(), age: j.age,
                             titresExternes: PolMoteur.titresActualite(j.politique))
        case .musee: MuseeView()
        case .reglages: ReglagesView()
        }
    }

    /// Transmet un signal d'un module au système de répercussions (suites des années suivantes).
    static func signaler(_ signal: String, _ j: inout Joueur) {
        var etat = j.repercussions ?? RepercussionsEtat()
        Repercussions.signaler(signal, age: j.age, etat: &etat)
        j.repercussions = etat
    }

    private func placements(_ j: Joueur) -> some View {
        let monde = j.monde ?? MondeEtat()
        return PlacementsView(
            etat: Binding(get: { engine.joueur?.placements ?? PlacementsEtat() },
                          set: { v in engine.modifier { $0.placements = v } }),
            argent: Binding(get: { engine.joueur?.argent ?? 0 },
                            set: { v in engine.modifier { $0.argent = v } }),
            contexte: PlacementsContexte(age: j.age, salaireAnnuel: j.emploi?.salaire ?? 0,
                                         multiplicateurs: MondeJournal.marches(monde)),
            surKarma: { k in engine.modifier { $0.stats.karma += k } }
        )
    }

    private func testament(_ j: Joueur) -> some View {
        SuccessionTestamentView(joueur: j, actuel: j.succession?.testament, onValider: { t in
            engine.modifier { joueur in
                var etat = joueur.succession ?? SuccessionEtat()
                let lignes = Successions.enregistrer(t, joueur: &joueur, etat: &etat)
                joueur.succession = etat
                for l in lignes { engine.ajouterLigne(&joueur, l) }
            }
        })
    }
}

// MARK: - Petits écrans d'habillage

/// Prison du module crime, avec le bouton d'évasion du mode Shkurtaaa.
struct PrisonEcran: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        Feuille(titre: "Prison") {
            ViePrisonView()
                .safeAreaInset(edge: .bottom) {
                    ShkurtaaaBoutonEvasion {
                        message = engine.vieAction { (j: inout Joueur) -> String in
                            VieCrime.liberer(&j, evasion: true)
                        }
                    }
                    .padding()
                }
                .alerteResultat($message)
        }
    }
}

/// Réputation du nom de famille.
struct ReputationFamilleEcran: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        Feuille(titre: "Réputation du nom") {
            if let j = engine.joueur {
                RepFamilleView(joueur: j, etat: j.reputationFamille ?? RepFamilleEtat()) { action in
                    var texte = ""
                    engine.modifier { joueur in
                        var rf = joueur.reputationFamille ?? ReputationFamille.aleatoire()
                        texte = ReputationFamille.faire(action, joueur: &joueur, etat: &rf)
                        joueur.reputationFamille = rf
                        engine.ajouterLigne(&joueur, texte)
                    }
                    return texte
                }
            }
        }
    }
}

/// Offres d'emploi du module Métiers.
struct OffresEmploiView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        Feuille(titre: "Offres d'emploi") {
            CareerJobBoardView(profile: engine.profilCarriere()) { job in
                message = engine.postulerCarriere(job)
            }
            .alerteResultat($message)
        }
    }
}

/// Travail en cours (module Métiers).
struct MonTravailView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        Feuille(titre: "Mon travail") {
            List {
                if let j = engine.joueur, let job = j.carriere {
                    CareerCurrentJobSection(job: job, female: j.genre == .femme) { action in
                        message = engine.actionCarriere(action)
                    }
                } else {
                    Text("Tu n'as pas de travail. Va voir les offres d'emploi.")
                        .foregroundStyle(.secondary)
                }
            }
            .alerteResultat($message)
        }
    }
}

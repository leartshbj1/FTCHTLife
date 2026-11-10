import SwiftUI

/// École (maternelle → lycée) : actions de la scolarité obligatoire.
struct EcoleView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        Feuille(titre: "École") {
            List {
                if let j = engine.joueur {
                    Section("Situation") {
                        ligne("Niveau", j.niveauScolaire ?? "Plus à l'école")
                        ligne("Diplôme", j.diplome.nom)
                        BarreStat(titre: "Intelligence", icone: "brain.head.profile", valeur: j.stats.intelligence)
                    }
                    if j.niveauScolaire != nil && j.age >= 6 {
                        Section("Que faire cette année ?") {
                            LigneAction(titre: "Étudier plus", sousTitre: "Plus d'intelligence, moins de vie sociale.", icone: "book.fill") {
                                message = engine.etudierPlus()
                            }
                            LigneAction(titre: "Sécher les cours", sousTitre: "Plus de bonheur, moins de bulletin.", icone: "figure.walk.departure") {
                                message = engine.secherLesCours()
                            }
                            if j.age >= 16 {
                                LigneAction(titre: "Quitter l'école", sousTitre: "Définitif. Pas de bac.", icone: "door.left.hand.open") {
                                    message = engine.quitterEcole()
                                }
                            }
                        }
                        if j.age >= 11 {
                            Section {
                                NavigationLink { ScolVieView() } label: { ScolLienLabel() }
                            } footer: {
                                Text("Popularité, groupes, élection de délégué, conseil de classe, voyages et oraux.")
                            }
                        }
                    } else {
                        Text("Tu es trop jeune pour avoir des devoirs. Profites-en.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alerteResultat($message)
        }
    }

    private func ligne(_ t: String, _ v: String) -> some View {
        HStack { Text(t); Spacer(); Text(v).foregroundStyle(.secondary) }
    }
}

/// Université : inscription, année en cours, abandon.
struct UniversiteView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        Feuille(titre: "Université") {
            List {
                if let j = engine.joueur {
                    if let e = j.etudes {
                        Section("En cours : \(e.filiere.nom)") {
                            HStack { Text("Année"); Spacer(); Text("\(e.annee) sur \(e.filiere.duree)").foregroundStyle(.secondary) }
                            HStack { Text("Frais"); Spacer(); Text("\(Format.argent(e.filiere.fraisAnnuels))/an").foregroundStyle(.secondary) }
                            LigneAction(titre: "Étudier plus", icone: "book.fill") { message = engine.etudierPlus() }
                            LigneAction(titre: "Abandonner les études", icone: "xmark.circle") { message = engine.abandonnerEtudes() }
                        }
                    } else {
                        Section {
                            ForEach(Filiere.allCases) { f in
                                LigneAction(titre: f.nom,
                                            sousTitre: "\(f.duree) ans · \(Format.argent(f.fraisAnnuels))/an · intelligence \(f.intelligenceMin) minimum",
                                            icone: "graduationcap.fill",
                                            actif: j.age >= 18 && j.diplome >= .bac) {
                                    message = engine.inscrireUniversite(f)
                                }
                            }
                        } header: {
                            Text("Choisir une filière")
                        } footer: {
                            Text("Ton diplôme : \(j.diplome.nom)\(j.filiereDiplome.map { " (\($0.nom))" } ?? ""). Les frais sont prélevés chaque année.")
                        }
                    }
                }
            }
            .alerteResultat($message)
        }
    }
}

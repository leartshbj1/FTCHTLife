import SwiftUI

struct OccupationView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    contenu(j)
                }
            }
            .navigationTitle("Occupation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    @ViewBuilder
    private func contenu(_ j: Joueur) -> some View {
        Section("Situation") {
            HStack { Text("Statut"); Spacer(); Text(j.occupation).foregroundStyle(.secondary) }
            HStack { Text("Diplôme"); Spacer(); Text(j.diplome.nom + (j.filiereDiplome.map { " (\($0.nom))" } ?? "")).foregroundStyle(.secondary) }
        }

        if j.age < 3 {
            Section {
                Text("Tu es trop jeune. Ton seul travail, c'est de baver.")
            }
        }

        if let niveau = j.niveauScolaire, j.age >= 6 {
            Section(niveau) {
                LigneAction(titre: "Étudier plus", icone: "book.fill") { message = engine.etudierPlus() }
                LigneAction(titre: "Sécher les cours", icone: "figure.walk.departure") { message = engine.secherLesCours() }
                if j.age >= 16 {
                    LigneAction(titre: "Quitter l'école", icone: "door.left.hand.open") { message = engine.quitterEcole() }
                }
            }
        }

        if let e = j.etudes {
            Section("Université : \(e.filiere.nom)") {
                Text("Année \(e.annee) sur \(e.filiere.duree)")
                LigneAction(titre: "Étudier plus", icone: "book.fill") { message = engine.etudierPlus() }
                LigneAction(titre: "Abandonner les études", icone: "xmark.circle") { message = engine.abandonnerEtudes() }
            }
        }

        if let e = j.emploi {
            Section("Mon travail") {
                HStack { Text(e.titre).bold(); Spacer(); Text("\(Format.argent(e.salaire))/an").foregroundStyle(.secondary) }
                HStack { Text("Ancienneté"); Spacer(); Text("\(e.annees) an\(e.annees > 1 ? "s" : "")").foregroundStyle(.secondary) }
                BarreStat(titre: "Performance", icone: "chart.line.uptrend.xyaxis", valeur: e.performance)
                LigneAction(titre: "Travailler plus dur", icone: "bolt.fill") { message = engine.travaillerDur() }
                LigneAction(titre: "Demander une augmentation", icone: "eurosign.circle.fill") { message = engine.demanderAugmentation() }
                LigneAction(titre: "Démissionner", icone: "rectangle.portrait.and.arrow.right") { message = engine.demissionner() }
            }
        }

        if j.age >= 18 && j.etudes == nil && j.diplome >= .bac {
            Section("Université") {
                ForEach(Filiere.allCases) { f in
                    LigneAction(titre: f.nom,
                                sousTitre: "\(f.duree) ans · \(Format.argent(f.fraisAnnuels))/an",
                                icone: "graduationcap.fill") {
                        message = engine.inscrireUniversite(f)
                    }
                }
            }
        }

        if j.age >= 18 && j.etudes == nil {
            Section("Offres d'emploi") {
                ForEach(engine.metiersAccessibles()) { m in
                    LigneAction(titre: m.titre,
                                sousTitre: "\(Format.argent(m.salaire))/an · \(m.diplome == .aucun ? "Sans diplôme" : m.diplome.nom)\(m.filiere.map { " en " + $0.nom.lowercased() } ?? "")",
                                icone: "briefcase.fill",
                                actif: engine.conditionsRemplies(m)) {
                        message = engine.postuler(m)
                    }
                }
            }
        }
    }
}

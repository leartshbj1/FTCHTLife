import SwiftUI

struct RelationsView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    section("Famille", j.relations.filter { [TypeRelation.mere, .pere, .frere, .soeur, .enfant].contains($0.type) })
                    section("Amour", j.relations.filter { $0.type == .partenaire || $0.type == .ex })
                    section("Amis", j.relations.filter { $0.type == .ami })
                }
            }
            .navigationTitle("Relations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private func section(_ titre: String, _ liste: [Relation]) -> some View {
        if !liste.isEmpty {
            Section(titre) {
                ForEach(liste) { r in
                    NavigationLink {
                        RelationDetailView(relationId: r.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(r.nomComplet).font(.headline).foregroundStyle(r.vivant ? Theme.encre : .gray)
                                Spacer()
                                Text(r.vivant ? "\(r.libelle) · \(r.age) ans" : "\(r.libelle) · décédé\(r.genre == .femme ? "e" : "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if r.vivant {
                                BarreStat(titre: "Relation", icone: "heart.fill", valeur: r.lien)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct RelationDetailView: View {
    @EnvironmentObject var engine: GameEngine
    let relationId: UUID
    @State private var message: String?

    var body: some View {
        List {
            if let r = engine.joueur?.relations.first(where: { $0.id == relationId }) {
                Section {
                    HStack { Text("Âge"); Spacer(); Text("\(r.age) ans").foregroundStyle(.secondary) }
                    BarreStat(titre: "Relation", icone: "heart.fill", valeur: r.lien)
                }
                if r.vivant {
                    Section("Actions") {
                        ForEach(engine.actionsPossibles(r)) { a in
                            LigneAction(titre: a.titre, icone: a.icone) {
                                message = engine.agir(a, sur: r.id)
                            }
                        }
                    }
                } else {
                    Text("Repose en paix, \(r.prenom).")
                }
            }
        }
        .navigationTitle(engine.joueur?.relations.first(where: { $0.id == relationId })?.prenom ?? "")
        .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

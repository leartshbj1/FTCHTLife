import SwiftUI

struct ActivitesView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let dispo = GameEngine.activites.filter { j.age >= $0.ageMin }
                    if dispo.isEmpty {
                        Text("Tu es un bébé. Ton activité principale, c'est dormir.")
                    }
                    ForEach(dispo) { a in
                        LigneAction(titre: a.titre,
                                    sousTitre: a.description + (a.cout > 0 && j.age >= 18 ? " · \(Format.argent(a.cout))" : ""),
                                    icone: a.icone,
                                    actif: engine.activiteDisponible(a)) {
                            message = engine.faireActivite(a)
                        }
                    }
                }
            }
            .navigationTitle("Activités")
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
}

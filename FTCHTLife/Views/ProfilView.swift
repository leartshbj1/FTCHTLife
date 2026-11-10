import SwiftUI

struct ProfilView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    Section("Identité") {
                        ligne("Nom", j.nomComplet)
                        ligne("Âge", "\(j.age) ans")
                        ligne("Ville", j.ville)
                        ligne("Occupation", j.occupation)
                        ligne("Diplôme", j.diplome.nom)
                        ligne("Argent", Format.argent(j.argent))
                    }
                    Section("Stats") {
                        BarreStat(titre: "Bonheur", icone: "face.smiling.fill", valeur: j.stats.bonheur)
                        BarreStat(titre: "Santé", icone: "heart.fill", valeur: j.stats.sante)
                        BarreStat(titre: "Intelligence", icone: "brain.head.profile", valeur: j.stats.intelligence)
                        BarreStat(titre: "Apparence", icone: "sparkles", valeur: j.stats.apparence)
                        BarreStat(titre: "Karma", icone: "yinyang", valeur: j.stats.karma)
                    }
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }

    private func ligne(_ t: String, _ v: String) -> some View {
        HStack { Text(t); Spacer(); Text(v).foregroundStyle(.secondary) }
    }
}

import SwiftUI

/// Fiche du personnage : identité, stats détaillées, rêves, réputation du nom.
struct ProfilView: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        Feuille(titre: "Mon profil") {
            List {
                if let j = engine.joueur {
                    Section("Identité") {
                        HStack(spacing: 14) {
                            AvatarJoueur(joueur: j, taille: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(j.nomComplet).font(.headline)
                                Text("\(j.age) an\(j.age > 1 ? "s" : "") · \(j.ville)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        ligne("Occupation", j.occupation)
                        ligne("Diplôme", j.diplome.nom + (j.filiereDiplome.map { " (\($0.nom))" } ?? ""))
                        ligne("Argent", Format.argent(j.argent))
                    }
                    Section("Stats") {
                        BarreStat(titre: "Bonheur", icone: "face.smiling.fill", valeur: j.stats.bonheur)
                        BarreStat(titre: "Santé", icone: "heart.fill", valeur: j.stats.sante)
                        BarreStat(titre: "Intelligence", icone: "brain.head.profile", valeur: j.stats.intelligence)
                        BarreStat(titre: "Apparence", icone: "sparkles", valeur: j.stats.apparence)
                        BarreStat(titre: "Karma", icone: "yinyang", valeur: j.stats.karma)
                    }
                    RevesSection(etat: j.reves, joueur: j)
                    if let rf = j.reputationFamille {
                        Section("Réputation du nom") {
                            RepFamilleBadge(etat: rf)
                        }
                    }
                }
            }
        }
    }

    private func ligne(_ t: String, _ v: String) -> some View {
        HStack { Text(t); Spacer(); Text(v).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
    }
}

/// Réglages : mode Shkurtaaa, aide, nouvelle vie.
struct ReglagesView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var confirmer = false

    var body: some View {
        Feuille(titre: "Réglages") {
            List {
                ShkurtaaaSettingsSection()
                Section("Comment jouer") {
                    Text("Touche **Âge +1** pour vivre une année. Il se passe des choses, parfois on te demande de choisir.")
                    Text("Entre deux années, ouvre les menus du bas : **Carrière**, **Biens**, **Relations**, **Activités**. Le bouton **Moi** en haut donne ton profil, tes talents et tes trophées.")
                    Text("Une entrée grise est fermée pour l'instant : touche-la pour savoir pourquoi.")
                }
                .font(.subheadline)
                Section("Partie") {
                    Button("Abandonner cette vie et recommencer", role: .destructive) { confirmer = true }
                }
            }
            .confirmationDialog("Abandonner cette vie et en commencer une nouvelle ?", isPresented: $confirmer, titleVisibility: .visible) {
                Button("Nouvelle vie", role: .destructive) {
                    dismiss()
                    engine.effacerVie()
                }
            }
        }
    }
}

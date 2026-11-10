import SwiftUI

/// Section à glisser dans l'écran Paramètres :
///
///     Form {
///         ...
///         ShkurtaaaSettingsSection()
///     }
struct ShkurtaaaSettingsSection: View {
    @ObservedObject var mode: Shkurtaaa = .shared
    @State private var confirmation = false

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { mode.estActif },
                set: { nouveau in
                    if nouveau { confirmation = true } else { mode.estActif = false }
                }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mode Shkurtaaa").font(.headline)
                        Text("Riche à vie, intouchable, et un peu tricheur.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "crown.fill").foregroundStyle(.yellow)
                }
            }
            .tint(.yellow)

            if mode.estActif {
                ForEach(ShkurtaaaPerk.allCases) { perk in
                    Toggle(isOn: Binding(
                        get: { mode.perks.contains(perk) },
                        set: { _ in mode.basculer(perk) }
                    )) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(perk.titre)
                                Text(perk.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: perk.symbole)
                        }
                    }
                    .tint(.yellow)
                }
            }
        } header: {
            Text("Shkurtaaa")
        } footer: {
            Text(mode.estActif
                 ? "Le mode s'applique tout de suite à ta vie en cours et aux suivantes."
                 : "Active-le pour vivre la vie de rêve sans aucune limite.")
        }
        .confirmationDialog("Activer le mode Shkurtaaa ?",
                            isPresented: $confirmation,
                            titleVisibility: .visible) {
            Button("Activer, je veux tout") { mode.estActif = true }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ton compte ne descendra plus jamais sous 100 milliards et la prison ne te retiendra plus. Tu peux choisir chaque avantage juste en dessous.")
        }
    }
}

/// Petit badge à afficher sur l'écran principal quand le mode est actif.
struct ShkurtaaaBadge: View {
    @ObservedObject var mode: Shkurtaaa = .shared

    var body: some View {
        if mode.estActif {
            Label("Shkurtaaa", systemImage: "crown.fill")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.yellow.opacity(0.25), in: Capsule())
                .foregroundStyle(.primary)
        }
    }
}

/// Bouton à afficher dans l'écran Prison. Il ne s'affiche que si
/// l'avantage « Évasion express » est actif ; `sEvader` est l'action
/// de libération fournie par le système prison.
struct ShkurtaaaBoutonEvasion: View {
    @ObservedObject var mode: Shkurtaaa = .shared
    let sEvader: () -> Void

    var body: some View {
        if mode.a(.evasionDirecte) {
            Button(action: sEvader) {
                Label("S'évader direct (Shkurtaaa)", systemImage: "figure.run")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
        }
    }
}

/// Phrases à piocher pour le journal de vie quand le mode agit.
enum ShkurtaaaJournal {
    static let evasions = [
        "Tu as dit « Shkurtaaa » au gardien. Il t'a ouvert la porte en s'excusant.",
        "Tu es sorti de prison par la grande porte. Personne n'a osé poser de questions.",
        "Tu as creusé un tunnel avec une cuillère en 4 minutes. Record mondial.",
        "Le directeur de la prison t'a raccompagné en limousine.",
        "Tu as acheté la prison. Puis tu es parti.",
    ]
    static let argent = [
        "Ton compte est remonté tout seul à 100 milliards. La banque ne comprend pas.",
        "Un mystérieux virement « Shkurtaaa » a renfloué ton compte.",
        "Tu as retrouvé quelques milliards dans la poche de ton jean.",
    ]
}

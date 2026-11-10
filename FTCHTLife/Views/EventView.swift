import SwiftUI

struct EventView: View {
    @EnvironmentObject var engine: GameEngine
    let affiche: EvenementAffiche

    /// Toujours lire la version à jour (le résultat s'ajoute après le choix).
    private var courant: EvenementAffiche { engine.evenementEnCours ?? affiche }

    var body: some View {
        let affiche = courant
        return VStack(spacing: 20) {
            Text(affiche.texte)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 28)
                .padding(.horizontal)

            if let resultat = affiche.resultat {
                Text(resultat)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.fond, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                Spacer()
                boutonPrincipal("OK") { engine.fermerEvenement() }
            } else {
                Spacer()
                VStack(spacing: 10) {
                    ForEach(Array((affiche.evenement.choices ?? []).enumerated()), id: \.offset) { i, c in
                        boutonPrincipal(c.label) { engine.choisir(i) }
                    }
                }
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.carte)
    }

    private func boutonPrincipal(_ titre: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titre)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .padding(.horizontal)
    }
}

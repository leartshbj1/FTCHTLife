import SwiftUI

/// Pop-up « Bilan de l'année » montré au passage d'année, avant les événements.
struct SpeBilanView: View {
    @Environment(\.dismiss) private var dismiss
    let bilan: SpeBilanAnnee

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bilan de l'année")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.encre)
                        Text("Tes \(bilan.age) ans")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    ForEach(bilan.sections) { s in
                        carte(s)
                    }
                }
                .padding()
            }
            Button {
                Vibration.legere()
                dismiss()
            } label: {
                Text("Continuer")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(CategorieMenu.carriere.couleur))
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Theme.fond.ignoresSafeArea())
    }

    private func carte(_ s: SpeBilanSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(s.emoji).font(.system(size: 38))
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.titre)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(CategorieMenu.carriere.couleur)
                    Text(s.sousTitre).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if !s.grosChiffre.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.grosChiffre)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.encre)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(s.grosLibelle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 8) {
                ForEach(s.lignes) { l in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(l.emoji).frame(width: 24)
                        Text(l.libelle).font(.subheadline).foregroundStyle(Theme.encre)
                        Spacer(minLength: 8)
                        Text(l.valeur)
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(l.ton > 0 ? Theme.argentPositif : (l.ton < 0 ? Theme.argentNegatif : Theme.encre))
                    }
                }
            }
            if !s.faits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(s.faits.enumerated()), id: \.offset) { _, f in
                        Text(f).font(.footnote).foregroundStyle(Theme.encre.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.carte))
    }
}

/// Montre le bilan de l'année tout seul, juste après « Âge +1 ». S'utilise sur l'écran principal.
struct SpeBilanAuto: ViewModifier {
    @EnvironmentObject var engine: GameEngine
    @State private var affiche: SpeBilanAnnee?

    func body(content: Content) -> some View {
        content
            .background(
                Color.clear.sheet(item: $affiche, onDismiss: { engine.speBilanVu() }) { b in
                    SpeBilanView(bilan: b)
                        .presentationDetents([.large])
                }
            )
            .onChange(of: engine.joueur?.age) { _ in proposer() }
            .onChange(of: engine.flashMonde == nil) { _ in proposer() }
            .onChange(of: engine.evenementEnCours == nil) { _ in proposer() }
            .onAppear { proposer() }
    }

    private func proposer() {
        guard affiche == nil, let b = engine.speBilanEnAttente else { return }
        // Emploi normal sans rien de neuf : pas de pop-up, pour garder le jeu rapide.
        if !b.important && b.sections.allSatisfy({ $0.faits.isEmpty }) {
            engine.speBilanVu()
            return
        }
        // La une du Journal du monde passe d'abord quand aucun événement n'attend.
        if engine.flashMonde != nil && engine.evenementEnCours == nil { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard affiche == nil, engine.speBilanEnAttente?.id == b.id else { return }
            affiche = b
        }
    }
}

extension View {
    func speBilanAuto() -> some View { modifier(SpeBilanAuto()) }
}

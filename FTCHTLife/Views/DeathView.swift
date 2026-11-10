import SwiftUI

struct DeathView: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        if let j = engine.joueur {
            ZStack {
                Theme.encre.ignoresSafeArea()
                VStack(spacing: 18) {
                    Spacer()
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(j.nomComplet)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("0 – \(j.age) ans")
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Mort\(j.genre == .femme ? "e" : "") \(j.causeDeces ?? "mystérieusement").")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)

                    VStack(alignment: .leading, spacing: 8) {
                        resume("Fortune", Format.argent(j.argent))
                        resume("Diplôme", j.diplome.nom)
                        resume("Amis", "\(j.relations.filter { $0.type == .ami }.count)")
                        resume("Karma", "\(j.stats.karma)%")
                    }
                    .padding()
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 32)

                    Spacer()
                    Button {
                        engine.effacerVie()
                    } label: {
                        Text("Nouvelle vie")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func resume(_ titre: String, _ valeur: String) -> some View {
        HStack {
            Text(titre).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(valeur).bold().foregroundStyle(.white)
        }
    }
}

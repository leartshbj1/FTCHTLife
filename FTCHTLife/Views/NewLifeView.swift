import SwiftUI

struct NewLifeView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var prenom = ""
    @State private var genre: Genre = .homme

    var body: some View {
        ZStack {
            Theme.fond.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 6) {
                    Text("FTCHTLife")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    Text("Une vie. Des choix. Beaucoup de mauvais choix.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 14) {
                    TextField("Prénom (vide = au hasard)", text: $prenom)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                    Picker("Genre", selection: $genre) {
                        Text("Garçon").tag(Genre.homme)
                        Text("Fille").tag(Genre.femme)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Button {
                        engine.nouvelleVie(prenom: prenom, genre: genre)
                    } label: {
                        Text("Commencer cette vie")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    Button("Vie totalement au hasard") {
                        engine.nouvelleVie()
                    }
                    .foregroundStyle(Theme.encre)
                }
                .padding(.horizontal, 32)
                Spacer()
            }
        }
    }
}

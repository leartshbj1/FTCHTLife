import SwiftUI

/// Écran d'accueil : créer un personnage, naître au hasard, ou voir trophées et vies passées.
struct NewLifeView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var prenom = ""
    @State private var genre: Genre = .homme
    @State private var creation = false
    @State private var voirTrophees = false
    @State private var voirBonus = false
    @State private var voirMusee = false

    var body: some View {
        ZStack {
            Theme.fond.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 26) {
                    VStack(spacing: 6) {
                        Text("FTCHTLife")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.accent)
                        Text("Une vie. Des choix. Beaucoup de mauvais choix.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 50)

                    Button { creation = true } label: {
                        Label("Créer mon personnage", systemImage: "person.crop.circle.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Naissance rapide")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.encre)
                        TextField("Prénom (vide = au hasard)", text: $prenom)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                        Picker("Genre", selection: $genre) {
                            Text("Garçon").tag(Genre.homme)
                            Text("Fille").tag(Genre.femme)
                        }
                        .pickerStyle(.segmented)
                        HStack(spacing: 10) {
                            Button {
                                engine.nouvelleVie(prenom: prenom, genre: genre)
                            } label: {
                                Text("Naître")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Theme.encre, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(.white)
                            }
                            Button {
                                engine.nouvelleVie()
                            } label: {
                                Text("Totalement au hasard")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Theme.carte, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(Theme.encre)
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.carte.opacity(0.7)))

                    HStack(spacing: 10) {
                        boutonSecondaire("Trophées", "trophy.fill") { voirTrophees = true }
                        boutonSecondaire("Bonus de départ", "gift.fill") { voirBonus = true }
                        boutonSecondaire("Musée des vies", "building.columns") { voirMusee = true }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $creation) {
            CharacterCreationView(onCancel: { creation = false }) { draft in
                creation = false
                engine.nouvelleVie(depuis: draft)
            }
        }
        .sheet(isPresented: $voirTrophees) { TropheesView() }
        .sheet(isPresented: $voirBonus) { Feuille(titre: "Bonus de départ") { BonusDepartView() } }
        .sheet(isPresented: $voirMusee) { MuseeView() }
    }

    private func boutonSecondaire(_ titre: String, _ icone: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icone).font(.system(size: 20))
                Text(titre)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(Theme.encre)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, 8)
            .background(Theme.carte, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

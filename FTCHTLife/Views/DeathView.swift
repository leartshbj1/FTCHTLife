import SwiftUI

/// Écran de fin de vie : pierre tombale, bilan, nécrologie, testament, carte à partager, suite de la lignée.
struct DeathView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var lecture: SuccessionLecture?
    @State private var chroniques: [String] = []
    @State private var voirTestament = false
    @State private var voirTrophees = false
    @State private var voirMusee = false

    var body: some View {
        if let j = engine.joueur {
            ZStack {
                Theme.encre.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        pierreTombale(j)
                        bilan(j)
                        RevesScoreCarte(etat: j.reves, joueur: j)
                            .padding(.horizontal, 20)
                        if let rf = j.reputationFamille, rf.dernierBilan != nil {
                            RepFamilleBilanView(etat: rf)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, 20)
                        }
                        NecrologieView(joueur: j, dernierMetier: j.dernierEmploi?.titre, scoreVieReussie: nil)
                            .padding(.horizontal, 20)
                        actions(j)
                        VieGenerationSection()
                            .padding(.horizontal, 20)
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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                    .padding(.top, 30)
                }
            }
            .onAppear {
                if lecture == nil {
                    let l = Successions.ouvrirPourJoueur(defunt: j, testament: j.succession?.testament)
                    lecture = l
                    chroniques = Successions.chroniques(lecture: l)
                }
            }
            .sheet(isPresented: $voirTestament) {
                if let l = lecture {
                    Feuille(titre: "Lecture du testament") {
                        SuccessionOuvertureView(lecture: l, chroniques: chroniques)
                    }
                }
            }
            .sheet(isPresented: $voirTrophees) { TropheesView() }
            .sheet(isPresented: $voirMusee) { MuseeView() }
        }
    }

    private func pierreTombale(_ j: Joueur) -> some View {
        VStack(spacing: 10) {
            Text("🪦").font(.system(size: 56))
            Text(j.nomComplet)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("0 – \(j.age) ans")
                .foregroundStyle(.white.opacity(0.7))
            Text("Mort\(j.genre == .femme ? "e" : "") \(j.causeDeces ?? "mystérieusement").")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
        }
    }

    private func bilan(_ j: Joueur) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ligne("Fortune", Format.argent(j.argent))
            ligne("Dernier métier", j.dernierEmploi?.titre ?? "Aucun")
            ligne("Diplôme", j.diplome.nom)
            ligne("Amis", "\(j.relations.filter { $0.type == .ami }.count)")
            ligne("Enfants", "\(j.relations.filter { $0.type == .enfant }.count)")
            ligne("Karma", "\(j.stats.karma)%")
        }
        .padding()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    private func actions(_ j: Joueur) -> some View {
        VStack(spacing: 10) {
            CarteVieBouton(joueur: j, surnom: MuseeStore.shared.fiche(pour: j)?.surnom,
                           dernierMetier: j.dernierEmploi?.titre)
            HStack(spacing: 10) {
                boutonSecondaire("Testament", "scroll.fill") { voirTestament = true }
                boutonSecondaire("Trophées", "trophy.fill") { voirTrophees = true }
                boutonSecondaire("Musée", "building.columns") { voirMusee = true }
            }
        }
        .padding(.horizontal, 20)
    }

    private func boutonSecondaire(_ titre: String, _ icone: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icone).font(.system(size: 18))
                Text(titre).font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func ligne(_ titre: String, _ valeur: String) -> some View {
        HStack {
            Text(titre).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(valeur).bold().foregroundStyle(.white)
        }
    }
}

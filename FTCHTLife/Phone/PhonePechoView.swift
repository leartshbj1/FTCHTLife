import SwiftUI

/// Pécho, l'appli de rencontre (18+) : swiper, matcher, proposer un rendez-vous.
@MainActor
struct PhonePechoView: View {
    @EnvironmentObject var engine: GameEngine
    let chemin: PhoneChemin
    @State private var profil: PhoneProfil?
    @State private var message: String?
    @State private var alerte: String?

    var body: some View {
        Group {
            if let j = engine.joueur {
                let t = j[keyPath: chemin] ?? PhoneEtat()
                if j.age < PhoneApp.pecho.ageMin {
                    interdit
                } else {
                    contenu(j, t)
                }
            }
        }
        .navigationTitle(PhoneApp.pecho.nom)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if profil == nil, let j = engine.joueur {
                profil = PhoneEngine.tirerProfil(j, j[keyPath: chemin] ?? PhoneEtat())
            }
        }
        .phoneAlerte($alerte)
    }

    private var interdit: some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 54))
                .foregroundStyle(PhoneApp.pecho.couleur)
            Text("Pécho est réservé aux 18 ans et plus.")
                .font(.headline)
            Text("Reviens avec une carte d'identité. Une vraie, pas celle que tu as dessinée.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func contenu(_ j: Joueur, _ t: PhoneEtat) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Je cherche", selection: Binding(
                    get: { t.recherche },
                    set: { valeur in
                        engine.telephoneModifier(chemin) { _, t in
                            t.recherche = valeur
                        }
                        profil = engine.joueur.flatMap { PhoneEngine.tirerProfil($0, $0[keyPath: chemin] ?? PhoneEtat()) }
                    })) {
                    Text("Hommes").tag("male")
                    Text("Femmes").tag("female")
                    Text("Tout le monde").tag("any")
                }
                .pickerStyle(.segmented)

                if let p = profil {
                    carte(p)
                    HStack(spacing: 40) {
                        boutonSwipe("xmark", .gray) { swiper(p, aDroite: false) }
                        boutonSwipe("heart.fill", PhoneApp.pecho.couleur) { swiper(p, aDroite: true) }
                    }
                    .disabled(PhoneEngine.swipesRestants(t) == 0)
                }
                Text("\(PhoneEngine.swipesRestants(t)) swipe\(PhoneEngine.swipesRestants(t) > 1 ? "s" : "") restant\(PhoneEngine.swipesRestants(t) > 1 ? "s" : "") cette année")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                matchs(t)
            }
            .padding()
        }
    }

    private func carte(_ p: PhoneProfil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                LinearGradient(colors: [PhoneApp.pecho.couleur.opacity(0.85), Theme.accent.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(String(p.prenom.prefix(1)))
                    .font(.system(size: 90, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text("\(p.prenom), \(p.age) ans")
                .font(.title2.bold())
            Text("« \(p.bio) »")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
    }

    private func boutonSwipe(_ icone: String, _ couleur: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icone)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(Circle().fill(couleur))
                .shadow(color: couleur.opacity(0.35), radius: 6, y: 3)
        }
    }

    private func swiper(_ p: PhoneProfil, aDroite: Bool) {
        message = engine.telephoneModifier(chemin) { j, t in
            PhoneEngine.swiper(p, aDroite: aDroite, &j, &t)
        }
        if let j = engine.joueur {
            profil = PhoneEngine.tirerProfil(j, j[keyPath: chemin] ?? PhoneEtat())
        }
    }

    @ViewBuilder
    private func matchs(_ t: PhoneEtat) -> some View {
        if !t.matchs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tes matchs · \(PhoneEngine.rendezVousRestants(t)) rendez-vous possible\(PhoneEngine.rendezVousRestants(t) > 1 ? "s" : "") cette année")
                    .font(.headline)
                ForEach(Array(t.matchs.reversed())) { m in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(m.prenom), \(m.age) ans").font(.subheadline.bold())
                            Text(m.bio)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Rendez-vous") {
                            alerte = engine.telephoneModifier(chemin) { j, t in
                                PhoneEngine.rendezVous(m.id, &j, &t, engine: engine)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PhoneApp.pecho.couleur)
                        .disabled(PhoneEngine.rendezVousRestants(t) == 0)
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

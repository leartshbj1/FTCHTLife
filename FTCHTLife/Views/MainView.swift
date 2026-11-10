import SwiftUI

enum Onglet: String, Identifiable {
    case occupation, relations, activites, profil
    var id: String { rawValue }
}

struct MainView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var onglet: Onglet?
    @State private var confirmerNouvelleVie = false

    var body: some View {
        if let j = engine.joueur {
            VStack(spacing: 0) {
                entete(j)
                journal(j)
                stats(j)
                barreOnglets(j)
            }
            .background(Theme.fond.ignoresSafeArea())
            .sheet(item: $onglet) { o in
                Group {
                    switch o {
                    case .occupation: OccupationView()
                    case .relations: RelationsView()
                    case .activites: ActivitesView()
                    case .profil: ProfilView()
                    }
                }
                .environmentObject(engine)
            }
            .sheet(item: $engine.evenementEnCours) { aff in
                EventView(affiche: aff)
                    .environmentObject(engine)
                    .interactiveDismissDisabled()
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog("Abandonner cette vie et en commencer une nouvelle ?", isPresented: $confirmerNouvelleVie, titleVisibility: .visible) {
                Button("Nouvelle vie", role: .destructive) { engine.effacerVie() }
            }
        }
    }

    // MARK: En-tête

    private func entete(_ j: Joueur) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.15))
                Text(String(j.prenom.prefix(1)))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(j.nomComplet).font(.headline)
                Text("\(j.occupation) · \(j.ville)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.argent(j.argent))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(j.argent < 0 ? .red : Color(red: 0.16, green: 0.6, blue: 0.3))
                Menu {
                    Button("Profil") { onglet = .profil }
                    Button("Nouvelle vie", role: .destructive) { confirmerNouvelleVie = true }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(Theme.encre)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.carte)
    }

    // MARK: Journal

    private func journal(_ j: Joueur) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(j.journal) { annee in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Âge : \(annee.age) an\(annee.age > 1 ? "s" : "")")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.accent)
                            if annee.lignes.isEmpty {
                                Text("Une année calme. Suspicieusement calme.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(Array(annee.lignes.enumerated()), id: \.offset) { _, ligne in
                                Text(ligne)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.encre)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .id(annee.id)
                    }
                    Color.clear.frame(height: 1).id("fin")
                }
                .padding()
            }
            .onChange(of: j.journal.last?.lignes.count) { _ in
                withAnimation { proxy.scrollTo("fin", anchor: .bottom) }
            }
            .onChange(of: j.journal.count) { _ in
                withAnimation { proxy.scrollTo("fin", anchor: .bottom) }
            }
            .onAppear { proxy.scrollTo("fin", anchor: .bottom) }
        }
    }

    // MARK: Stats

    private func stats(_ j: Joueur) -> some View {
        VStack(spacing: 6) {
            BarreStat(titre: "Bonheur", icone: "face.smiling.fill", valeur: j.stats.bonheur)
            BarreStat(titre: "Santé", icone: "heart.fill", valeur: j.stats.sante)
            BarreStat(titre: "Intelligence", icone: "brain.head.profile", valeur: j.stats.intelligence)
            BarreStat(titre: "Apparence", icone: "sparkles", valeur: j.stats.apparence)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.carte)
    }

    // MARK: Onglets

    private func barreOnglets(_ j: Joueur) -> some View {
        HStack(alignment: .center) {
            boutonOnglet("Occupation", "briefcase.fill", .occupation)
            boutonOnglet("Relations", "person.2.fill", .relations)
            Button {
                withAnimation { engine.vieillir() }
            } label: {
                VStack(spacing: 0) {
                    Image(systemName: "plus").font(.system(size: 22, weight: .black))
                    Text("1 AN").font(.system(size: 12, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Theme.accent))
                .shadow(color: Theme.accent.opacity(0.4), radius: 8, y: 4)
            }
            .disabled(!j.vivant)
            .offset(y: -14)
            boutonOnglet("Activités", "figure.run", .activites)
            boutonOnglet("Profil", "person.crop.circle", .profil)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .background(Theme.carte.ignoresSafeArea(edges: .bottom))
    }

    private func boutonOnglet(_ titre: String, _ icone: String, _ o: Onglet) -> some View {
        Button {
            onglet = o
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icone).font(.system(size: 20))
                Text(titre).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Theme.encre)
            .frame(maxWidth: .infinity)
        }
    }
}

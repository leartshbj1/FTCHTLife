import SwiftUI

// Écrans des trophées : la vitrine, les bonus de départ et le bandeau « Trophée obtenu ».

extension TropheeRarete {
    var couleur: Color {
        switch self {
        case .bronze: return Color(red: 0.72, green: 0.45, blue: 0.20)
        case .argent: return Color(red: 0.55, green: 0.58, blue: 0.62)
        case .or: return Color(red: 0.90, green: 0.68, blue: 0.08)
        case .legendaire: return Color(red: 0.55, green: 0.25, blue: 0.85)
        }
    }
}

/// La vitrine des trophées, à ouvrir en feuille depuis l'écran principal, la mort ou la nouvelle vie.
struct TropheesView: View {
    @ObservedObject private var trophees = Trophees.shared
    @Environment(\.dismiss) private var dismiss
    @State private var filtre = Filtre.tous
    @State private var confirmerEffacement = false

    enum Filtre: String, CaseIterable, Identifiable {
        case tous = "Tous", obtenus = "Obtenus", manquants = "À obtenir"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Section { resume }
                if !trophees.bonusDisponibles.isEmpty {
                    Section {
                        NavigationLink {
                            BonusDepartView()
                        } label: {
                            Label("Bonus de départ (\(trophees.etat.bonusEquipes.count)/\(Trophees.maxBonus) équipés)",
                                  systemImage: "gift.fill")
                        }
                    }
                }
                Section {
                    Picker("Filtre", selection: $filtre) {
                        ForEach(Filtre.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                ForEach(CatalogueTrophees.categories) { cat in
                    let items = liste(categorie: cat.id)
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { t in LigneTrophee(trophee: t) }
                        } header: {
                            let total = CatalogueTrophees.tous.filter { $0.categorie == cat.id }
                            let faits = total.filter { trophees.estObtenu($0.id) }.count
                            Label("\(cat.nom) · \(faits)/\(total.count)", systemImage: cat.icone)
                        }
                    }
                }
                Section {
                    Button("Effacer tous les trophées", role: .destructive) { confirmerEffacement = true }
                } footer: {
                    Text("Les trophées restent d'une vie à l'autre. Certains débloquent un bonus de départ pour tes prochaines vies.")
                }
            }
            .navigationTitle("Trophées")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .confirmationDialog("Effacer toute ta collection de trophées ? C'est définitif.",
                                isPresented: $confirmerEffacement, titleVisibility: .visible) {
                Button("Tout effacer", role: .destructive) { trophees.toutEffacer() }
            }
        }
    }

    private func liste(categorie: String) -> [TropheeDef] {
        CatalogueTrophees.tous
            .filter { $0.categorie == categorie }
            .filter { t in
                switch filtre {
                case .tous: return true
                case .obtenus: return trophees.estObtenu(t.id)
                case .manquants: return !trophees.estObtenu(t.id)
                }
            }
            .sorted { a, b in
                let oa = trophees.estObtenu(a.id), ob = trophees.estObtenu(b.id)
                if oa != ob { return oa }
                return a.rarete < b.rarete
            }
    }

    private var resume: some View {
        let total = CatalogueTrophees.tous.count
        let faits = trophees.nombreObtenus
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(faits)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text("/ \(total) trophées").font(.headline).foregroundStyle(.secondary)
                Spacer()
            }
            ProgressView(value: Double(faits), total: Double(max(1, total)))
                .tint(Theme.accent)
            HStack(spacing: 14) {
                ForEach(TropheeRarete.allCases, id: \.self) { r in
                    let n = CatalogueTrophees.tous.filter { $0.rarete == r && trophees.estObtenu($0.id) }.count
                    Label("\(n)", systemImage: "trophy.fill")
                        .font(.caption.bold())
                        .foregroundStyle(r.couleur)
                }
            }
            let e = trophees.etat
            Text("\(e.total["vie"] ?? 0) vies · \(e.total["mort"] ?? 0) morts · record : \(e.ageRecord) ans, \(Format.argent(e.fortuneRecord))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct LigneTrophee: View {
    let trophee: TropheeDef
    @ObservedObject private var trophees = Trophees.shared

    var body: some View {
        let obtenu = trophees.etat.obtenus[trophee.id]
        let cache = trophee.secret == true && obtenu == nil
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(obtenu != nil ? trophee.rarete.couleur.opacity(0.18) : Color.black.opacity(0.05))
                Image(systemName: obtenu != nil ? "trophy.fill" : (cache ? "questionmark" : "lock.fill"))
                    .foregroundStyle(obtenu != nil ? trophee.rarete.couleur : .gray)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(cache ? "???" : trophee.nom)
                        .font(.subheadline.bold())
                        .foregroundStyle(obtenu != nil ? Theme.encre : .secondary)
                    Text(trophee.rarete.nom)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(trophee.rarete.couleur.opacity(0.15), in: Capsule())
                        .foregroundStyle(trophee.rarete.couleur)
                }
                Text(cache ? "Trophée secret. Vis n'importe comment et tu finiras peut-être par le trouver." : trophee.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let b = trophee.bonus, !cache {
                    Label("Bonus : \(b.titre)", systemImage: "gift.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(obtenu != nil ? Theme.accent : .gray)
                }
                if let o = obtenu {
                    Text("Obtenu par \(o.personnage) à \(o.age) ans\(o.enShkurtaaa ? " · en Shkurtaaa" : "")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Choix des bonus de départ (appliqués à la prochaine naissance).
struct BonusDepartView: View {
    @ObservedObject private var trophees = Trophees.shared

    var body: some View {
        List {
            Section {
                ForEach(trophees.bonusDisponibles) { t in
                    if let b = t.bonus {
                        Button {
                            trophees.basculerBonus(t.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: trophees.estEquipe(t.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(trophees.estEquipe(t.id) ? Theme.accent : .gray)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.titre).font(.subheadline.bold()).foregroundStyle(Theme.encre)
                                    Text(b.description).font(.caption).foregroundStyle(.secondary)
                                    Text("Trophée : \(t.nom)").font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .disabled(!trophees.estEquipe(t.id) && trophees.etat.bonusEquipes.count >= Trophees.maxBonus)
                    }
                }
            } footer: {
                Text("Jusqu'à \(Trophees.maxBonus) bonus en même temps. Ils s'appliquent à ta prochaine naissance.")
            }
        }
        .navigationTitle("Bonus de départ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Bandeau « Trophée obtenu » qui s'affiche en haut de l'écran.
struct BandeauTrophee: View {
    let trophee: TropheeDef

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(trophee.rarete.couleur)
            VStack(alignment: .leading, spacing: 2) {
                Text("Trophée \(trophee.rarete.nom.lowercased()) obtenu !")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(trophee.nom).font(.subheadline.bold()).foregroundStyle(Theme.encre)
                if let b = trophee.bonus {
                    Text("Bonus débloqué : \(b.titre)").font(.caption2).foregroundStyle(Theme.accent)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.carte, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(trophee.rarete.couleur.opacity(0.6), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal)
    }
}

/// Suit la vie en cours pour débloquer les trophées, et affiche les bandeaux.
/// À poser une fois, sur la vue racine : `ContentView().suiviTrophees()` (voir docs/TROPHEES.md).
struct SuiviTropheesModifier: ViewModifier {
    @EnvironmentObject var engine: GameEngine
    @ObservedObject private var trophees = Trophees.shared
    @State private var affiche: TropheeDef?

    func body(content: Content) -> some View {
        content
            .onAppear { trophees.observer(engine) }
            .onChange(of: engine.joueur) { _ in trophees.observer(engine) }
            .onChange(of: trophees.aAnnoncer.count) { _ in suivant() }
            .overlay(alignment: .top) {
                if let t = affiche {
                    BandeauTrophee(trophee: t)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { masquer() }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: affiche?.id)
    }

    private func suivant() {
        guard affiche == nil, !trophees.aAnnoncer.isEmpty else { return }
        let t = trophees.aAnnoncer.removeFirst()
        affiche = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            if affiche?.id == t.id { masquer() }
        }
    }

    private func masquer() {
        affiche = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { suivant() }
    }
}

extension View {
    /// Active le suivi des trophées et les bandeaux « Trophée obtenu ».
    func suiviTrophees() -> some View { modifier(SuiviTropheesModifier()) }
}

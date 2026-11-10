import SwiftUI

/// Table de blackjack. Affichée par `CasinoRouteurJeu` (barre de solde et tapis déjà présents).
struct BlackjackVue: View {
    @EnvironmentObject var engine: GameEngine
    let lieu: CasinoLieu
    @StateObject private var table = BlackjackTable()
    @ObservedObject private var stockage = CasinoStockage.shared
    @State private var mise = 0

    private var argent: Int { engine.joueur?.argent ?? 0 }
    private var peutCompter: Bool { (engine.joueur?.stats.intelligence ?? 0) >= 70 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                bulleCroupier
                zoneCroupier
                zoneJoueur
                if let m = table.message {
                    CasinoBandeau(texte: m, gain: table.messageGain)
                }
                if let ban = table.banni {
                    CasinoBandeau(texte: ban, gain: false)
                } else {
                    commandes
                }
                if peutCompter { comptage }
                Text("Le croupier reste sur 17 · Blackjack payé 3 pour 2 · Sabot : \(table.cartesRestantes) cartes")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .onAppear {
            if let j = engine.joueur, lieu.respecteInterdiction, engine.casinoEtat.estInterdit(age: j.age), table.banni == nil {
                table.fermer("Raymond a reconnu ta photo sur le mur. « Pas toi. Pas ici. »")
            }
        }
    }

    // MARK: Croupier

    private var bulleCroupier: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("🤵").font(.system(size: 34))
            Text(table.phraseCroupier)
                .font(.callout.italic())
                .foregroundStyle(.white)
                .padding(10)
                .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 0)
        }
    }

    private var zoneCroupier: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Raymond, croupier").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                if let t = table.totalCroupierVisible {
                    Text(table.carteCacheeVisible ? "\(t)" : "\(t) + ?")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(CasinoStyle.or)
                }
            }
            HStack(spacing: -18) {
                ForEach(Array(table.croupier.enumerated()), id: \.element.id) { i, c in
                    let cachee = i == 1 && !table.carteCacheeVisible
                    CasinoCarteVue(carte: c, cachee: cachee, largeur: 60)
                        .rotation3DEffect(.degrees(i == 1 ? table.angleCachee : 0), axis: (x: 0, y: 1, z: 0))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if table.croupier.isEmpty {
                    CasinoCarteVue(carte: nil, cachee: true, largeur: 60).opacity(0.25)
                }
            }
            .frame(height: 90)
        }
        .padding(12)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Joueur

    private var zoneJoueur: some View {
        VStack(spacing: 10) {
            if table.mains.isEmpty {
                Text("Pose ta mise et clique sur Distribuer.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(height: 90)
            }
            ForEach(Array(table.mains.enumerated()), id: \.element.id) { i, m in
                vueMain(m, active: table.phase == .joueur && i == table.mainActive && table.mains.count > 1)
            }
        }
    }

    private func vueMain(_ m: BlackjackMain, active: Bool) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("Ta main · \(Format.argent(m.mise))\(m.doublee ? " (doublée)" : "")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if let issue = m.issue {
                    Text(issue.libelle)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(couleurIssue(issue), in: Capsule())
                        .foregroundStyle(.white)
                }
                if !m.cartes.isEmpty {
                    Text(m.souple && m.total < 21 ? "\(m.total - 10)/\(m.total)" : "\(m.total)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(m.bust ? CasinoStyle.rouge : CasinoStyle.or)
                }
            }
            HStack(spacing: -18) {
                ForEach(m.cartes) { c in
                    CasinoCarteVue(carte: c, largeur: 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(height: 90)
        }
        .padding(12)
        .background(Color.black.opacity(active ? 0.35 : 0.18), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(active ? CasinoStyle.or : .clear, lineWidth: 2))
    }

    private func couleurIssue(_ issue: BlackjackIssue) -> Color {
        switch issue.estGain {
        case .some(true): return Color(red: 0.12, green: 0.6, blue: 0.3)
        case .some(false): return CasinoStyle.rouge
        case .none: return Color.gray
        }
    }

    // MARK: Commandes

    @ViewBuilder
    private var commandes: some View {
        if table.phase == .mise || table.phase == .fin {
            CasinoSelecteurMise(mise: $mise, lieu: lieu, argent: argent)
            CasinoBouton(titre: table.phase == .fin ? "Nouvelle main" : "Distribuer",
                         actif: !table.occupe && CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent)) {
                table.distribuer(engine: engine, mise: mise, lieu: lieu, comptage: table.compterActif)
            }
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    CasinoBouton(titre: "Tirer", actif: table.peutTirer()) { table.tirer() }
                    CasinoBouton(titre: "Rester", couleur: CasinoStyle.rouge, actif: table.phase == .joueur && !table.occupe) { table.rester() }
                }
                HStack(spacing: 10) {
                    CasinoBouton(titre: "Doubler", couleur: Color(red: 0.2, green: 0.35, blue: 0.75),
                                 actif: table.peutDoubler(argent: argent)) { table.doubler(engine: engine) }
                    CasinoBouton(titre: "Séparer", couleur: Color(red: 0.45, green: 0.25, blue: 0.6),
                                 actif: table.peutSeparer(argent: argent)) { table.separer(engine: engine) }
                }
            }
        }
    }

    // MARK: Comptage

    private var comptage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $table.compterActif) {
                Label("Compter les cartes", systemImage: "brain")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .tint(CasinoStyle.or)
            if table.compterActif {
                HStack {
                    Text("Compte : \(table.compte >= 0 ? "+" : "")\(table.compte)")
                    Spacer()
                    Text("Vrai compte : " + String(format: "%+.1f", table.vraiCompte))
                }
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(CasinoStyle.or)
                Text("Plus le vrai compte est haut, plus le sabot est riche en 10 et en As. Mais augmenter brutalement ta mise attire l'attention.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
    }
}

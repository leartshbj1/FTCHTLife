import SwiftUI

/// Écran racine du casino, à ouvrir en sheet avec le moteur en environmentObject.
struct CasinoView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var stockage = CasinoStockage.shared
    @State private var message: String?
    @State private var lieuOuvert: CasinoLieu?
    @State private var usurierOuvert = false
    @State private var confirmerInterdiction = false

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let e = engine.casinoEtat
                    Section {
                        situation(j, e)
                    }
                    Section("Où jouer ?") {
                        ForEach(CasinoLieu.allCases) { lieu in
                            ligneLieu(lieu)
                        }
                    }
                    Section("Se soigner") {
                        LigneAction(titre: "Joueurs Anonymes",
                                    sousTitre: "Une réunion par an, gratuite. Café tiède inclus.",
                                    icone: "person.3.fill",
                                    actif: engine.casinoPeutAllerJA()) {
                            message = engine.casinoJoueursAnonymes()
                        }
                        LigneAction(titre: "Clinique Les Tilleuls Zen",
                                    sousTitre: "Cure intensive · \(Format.argent(GameEngine.casinoPrixCure))",
                                    icone: "leaf.fill",
                                    actif: engine.casinoPeutFaireCure() && j.argent >= GameEngine.casinoPrixCure) {
                            message = engine.casinoCure()
                        }
                        LigneAction(titre: "Se faire interdire de casino",
                                    sousTitre: e.estInterdit(age: j.age) ? "Déjà interdit jusqu'à \(e.interditJusqua ?? j.age) ans." : "5 ans sans casino ni Palais. Le tripot, lui, s'en moque.",
                                    icone: "hand.raised.fill",
                                    actif: j.age >= 18 && !e.estInterdit(age: j.age)) {
                            confirmerInterdiction = true
                        }
                    }
                    Section("Argent") {
                        LigneAction(titre: "Tonton Gégé, prêteur",
                                    sousTitre: e.detteUsurier > 0 ? "Tu lui dois \(Format.argent(e.detteUsurier))" : "Prêts rapides, intérêts musclés.",
                                    icone: "banknote.fill",
                                    actif: j.age >= 18) {
                            usurierOuvert = true
                        }
                    }
                    Section("Statistiques") {
                        statistiques(e)
                    }
                }
            }
            .navigationTitle("Casino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .navigationDestination(isPresented: Binding(get: { lieuOuvert != nil }, set: { if !$0 { lieuOuvert = nil } })) {
                if let lieu = lieuOuvert { CasinoLieuVue(lieu: lieu) }
            }
            .sheet(isPresented: $usurierOuvert) {
                CasinoUsurierVue().environmentObject(engine)
            }
            .confirmationDialog("Signer une interdiction volontaire de 5 ans ?", isPresented: $confirmerInterdiction, titleVisibility: .visible) {
                Button("Signer", role: .destructive) { message = engine.casinoAutoInterdiction() }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    // MARK: Situation

    private func situation(_ j: Joueur, _ e: CasinoEtat) -> some View {
        let niveau = CasinoNiveauAddiction.pour(e.addiction)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.vip.nom).font(.headline)
                    Text(e.vip.avantage).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: e.vip >= .or ? "crown.fill" : "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(e.vip >= .or ? CasinoStyle.or : .secondary)
            }
            if let suivant = e.vip.suivant {
                ProgressView(value: Double(e.totalMise - e.vip.seuil), total: Double(suivant.seuil - e.vip.seuil)) {
                    Text("Prochain statut : \(suivant.nom) (\(Format.argent(suivant.seuil)) misés)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .tint(CasinoStyle.or)
            }
            BarreStat(titre: "Addiction", icone: "brain.head.profile", valeur: e.addiction)
                .environment(\.colorScheme, .light)
            Text("\(niveau.nom) · \(niveau.description)")
                .font(.caption)
                .foregroundStyle(CasinoStyle.couleurAddiction(e.addiction))
            if e.detteUsurier > 0 {
                Label("Dette envers Tonton Gégé : \(Format.argent(e.detteUsurier))", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
            if e.estInterdit(age: j.age) {
                Label("Interdit de casino jusqu'à \(e.interditJusqua ?? j.age) ans", systemImage: "nosign")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func ligneLieu(_ lieu: CasinoLieu) -> some View {
        let refus = engine.casinoRefusEntree(lieu)
        return Button {
            if let r = refus {
                message = r
            } else {
                if let m = engine.casinoEntrer(lieu) {
                    message = m
                } else {
                    lieuOuvert = lieu
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: lieu.icone)
                    .font(.system(size: 18))
                    .foregroundStyle(refus == nil ? CasinoStyle.tapis : .gray)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lieu.nom).foregroundStyle(refus == nil ? Theme.encre : .gray)
                    Text(lieu.sousTitre).font(.caption).foregroundStyle(.secondary)
                    Text("Mises : \(Format.argent(lieu.miseMin)) à \(Format.argent(lieu.miseMax))")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: refus == nil ? "chevron.right" : "lock.fill").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Statistiques

    @ViewBuilder
    private func statistiques(_ e: CasinoEtat) -> some View {
        ligneStat("Total misé", Format.argent(e.totalMise))
        ligneStat("Bilan de toute la vie", (e.netVie >= 0 ? "+" : "") + Format.argent(e.netVie), couleur: e.netVie >= 0 ? .green : .red)
        ligneStat("Plus gros gain", Format.argent(e.plusGrosGain))
        ligneStat("Plus grosse perte", Format.argent(e.plusGrossePerte))
        ligneStat("Gros lots touchés", "\(e.jackpots)")
        ligneStat("Réunions des Joueurs Anonymes", "\(e.reunionsJA)")
        let jeux = CasinoJeu.allCases.filter { (e.parJeu[$0.rawValue]?.mise ?? 0) > 0 }
        ForEach(jeux) { jeu in
            let s = e.parJeu[jeu.rawValue] ?? CasinoStatJeu()
            ligneStat("\(jeu.nom) (\(s.parties) parties)", (s.net >= 0 ? "+" : "") + Format.argent(s.net), couleur: s.net >= 0 ? .green : .red)
        }
    }

    private func ligneStat(_ titre: String, _ valeur: String, couleur: Color = .primary) -> some View {
        HStack {
            Text(titre).font(.subheadline)
            Spacer()
            Text(valeur).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(couleur)
        }
    }
}

// MARK: - Un lieu

struct CasinoLieuVue: View {
    @EnvironmentObject var engine: GameEngine
    let lieu: CasinoLieu

    var body: some View {
        VStack(spacing: 0) {
            CasinoBarreSolde()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(lieu.sousTitre)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    ForEach(lieu.jeux) { jeu in
                        NavigationLink(value: jeu) { carteJeu(jeu) }
                    }
                }
                .padding()
            }
        }
        .casinoTapis()
        .navigationTitle(lieu.nom)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CasinoJeu.self) { jeu in
            CasinoRouteurJeu(jeu: jeu, lieu: lieu)
        }
    }

    private func carteJeu(_ jeu: CasinoJeu) -> some View {
        HStack(spacing: 14) {
            Image(systemName: jeu.icone)
                .font(.system(size: 24))
                .foregroundStyle(CasinoStyle.or)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(jeu.nom).font(.headline).foregroundStyle(.white)
                Text(jeu.description).font(.caption).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
        }
        .padding(12)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Routeur

/// Ouvre l'écran du jeu demandé, avec la barre de solde en haut et le fond tapis.
struct CasinoRouteurJeu: View {
    let jeu: CasinoJeu
    let lieu: CasinoLieu

    var body: some View {
        VStack(spacing: 0) {
            CasinoBarreSolde()
            contenu
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .casinoTapis()
        .navigationTitle(jeu.nom)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var contenu: some View {
        switch jeu {
        case .blackjack: BlackjackVue(lieu: lieu)
        case .roulette: RouletteVue(lieu: lieu)
        case .machines: MachineASousVue(lieu: lieu)
        case .videoPoker: VideoPokerVue(lieu: lieu)
        case .holdem: HoldemVue(lieu: lieu)
        case .paris: ParisSportifsVue(lieu: lieu)
        case .courses: CoursesVue(lieu: lieu)
        case .loto: LotoVue(lieu: lieu)
        case .grattage: GrattageVue(lieu: lieu)
        case .pileOuFace: PileOuFaceVue(lieu: lieu)
        case .des: DesVue(lieu: lieu)
        case .roue: RoueVue(lieu: lieu)
        case .bonneteau: BonneteauVue(lieu: lieu)
        }
    }
}

// MARK: - Usurier

struct CasinoUsurierVue: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var stockage = CasinoStockage.shared
    @State private var montant: Double = 1_000
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                let e = engine.casinoEtat
                let plafond = engine.casinoPlafondUsurier
                Section {
                    Text("Tonton Gégé reçoit dans l'arrière-salle d'une laverie. Il sent l'after-shave et la menace. Intérêts : 30 % par an. Au bout de deux ans sans remboursement, ses neveux passent te voir.")
                        .font(.subheadline)
                }
                Section("Ta dette") {
                    Text(Format.argent(e.detteUsurier))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(e.detteUsurier > 0 ? .red : .primary)
                    if e.anneesDetteImpayee > 0 {
                        Text("Impayée depuis \(e.anneesDetteImpayee) an\(e.anneesDetteImpayee > 1 ? "s" : "").")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
                Section("Montant") {
                    let maxi = Double(max(plafond, e.detteUsurier, 1_000))
                    Slider(value: $montant, in: 100...max(100.1, maxi), step: 100)
                    Text(Format.argent(Int(montant))).font(.headline).monospacedDigit()
                }
                Section {
                    Button("Emprunter (plafond : \(Format.argent(plafond)))") {
                        message = engine.casinoEmprunter(Int(montant))
                    }
                    .disabled(plafond < Int(montant))
                    Button("Rembourser") {
                        message = engine.casinoRembourser(Int(montant))
                    }
                    .disabled(e.detteUsurier == 0)
                    Button("Tout rembourser") {
                        message = engine.casinoRembourser(e.detteUsurier)
                    }
                    .disabled(e.detteUsurier == 0)
                }
            }
            .navigationTitle("Tonton Gégé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("Tonton Gégé", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }
}

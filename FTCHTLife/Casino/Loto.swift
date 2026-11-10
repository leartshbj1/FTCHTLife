import SwiftUI

/// Une grille de loto : 5 numéros parmi 49 et un numéro chance parmi 10.
struct LotoGrille: Identifiable, Equatable {
    let id = UUID()
    var numeros: Set<Int> = []
    var chance: Int? = nil

    var complete: Bool { numeros.count == 5 && chance != nil }

    static func flash() -> LotoGrille {
        var g = LotoGrille()
        g.numeros = Set(Array(1...49).shuffled().prefix(5))
        g.chance = Int.random(in: 1...10)
        return g
    }
}

enum LotoRegles {
    static let prixGrille = 2

    /// Gain fixe selon le nombre de bons numéros et le numéro chance (nil = gros lot).
    static func gain(bons: Int, chance: Bool) -> Int? {
        switch (bons, chance) {
        case (5, true): return nil
        case (5, false): return 100_000
        case (4, true): return 1_000
        case (4, false): return 500
        case (3, true): return 50
        case (3, false): return 20
        case (2, true): return 10
        case (2, false): return 5
        case (_, true): return 2
        default: return 0
        }
    }
}

struct LotoVue: View {
    @EnvironmentObject var engine: GameEngine
    let lieu: CasinoLieu
    @ObservedObject private var stockage = CasinoStockage.shared

    @State private var grilles: [LotoGrille] = [LotoGrille()]
    @State private var grilleActive = 0
    @State private var tirage: [Int] = []
    @State private var chanceTiree: Int?
    @State private var enTirage = false
    @State private var bandeau: String?
    @State private var bandeauGain: Bool?

    private var argent: Int { engine.joueur?.argent ?? 0 }
    private var prix: Int { grilles.count * LotoRegles.prixGrille }
    private var toutesCompletes: Bool { grilles.allSatisfy { $0.complete } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("GROS LOT : \(Format.argent(engine.casinoEtat.jackpotLoto))")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.black.opacity(0.5), in: Capsule())
                zoneTirage
                if let b = bandeau { CasinoBandeau(texte: b, gain: bandeauGain) }
                onglets
                if grilleActive < grilles.count { editeur }
                HStack(spacing: 10) {
                    CasinoBouton(titre: "Flash", couleur: Color(red: 0.2, green: 0.35, blue: 0.75), actif: !enTirage) {
                        grilles[grilleActive] = LotoGrille.flash()
                    }
                    CasinoBouton(titre: "Tout en flash", couleur: Color(red: 0.45, green: 0.25, blue: 0.6), actif: !enTirage) {
                        grilles = grilles.map { _ in LotoGrille.flash() }
                    }
                }
                CasinoBouton(titre: "Valider \(grilles.count) grille\(grilles.count > 1 ? "s" : "") · \(Format.argent(prix))",
                             actif: !enTirage && toutesCompletes && argent >= prix) { jouer() }
                Text("5 numéros + numéro chance = gros lot · 5 = 100'000 € · 4 + chance = 1'000 € · … · numéro chance seul = grille remboursée")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: Tirage

    private var zoneTirage: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                boule(i < tirage.count ? "\(tirage[i])" : "?", couleur: .white)
            }
            boule(chanceTiree.map { "\($0)" } ?? "?", couleur: CasinoStyle.rouge)
        }
        .padding(10)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
    }

    private func boule(_ texte: String, couleur: Color) -> some View {
        Text(texte)
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(couleur == .white ? CasinoStyle.nuit : .white)
            .frame(width: 42, height: 42)
            .background(Circle().fill(couleur))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            .transition(.scale)
    }

    // MARK: Grilles

    private var onglets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(grilles.indices, id: \.self) { i in
                    Button { grilleActive = i } label: {
                        Text("Grille \(i + 1)\(grilles[i].complete ? " ✓" : "")")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(grilleActive == i ? CasinoStyle.or : Color.black.opacity(0.3), in: Capsule())
                            .foregroundStyle(grilleActive == i ? CasinoStyle.nuit : .white)
                    }
                }
                if grilles.count < 10 {
                    Button { grilles.append(LotoGrille()); grilleActive = grilles.count - 1 } label: {
                        Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(CasinoStyle.or)
                    }
                }
                if grilles.count > 1 {
                    Button {
                        grilles.remove(at: grilleActive)
                        grilleActive = max(0, min(grilleActive, grilles.count - 1))
                    } label: {
                        Image(systemName: "minus.circle.fill").font(.title3).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .disabled(enTirage)
    }

    private var editeur: some View {
        let g = grilles[grilleActive]
        let colonnes = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(spacing: 10) {
            LazyVGrid(columns: colonnes, spacing: 4) {
                ForEach(1...49, id: \.self) { n in
                    caseNumero(n, cochee: g.numeros.contains(n), couleur: CasinoStyle.or) { basculer(n) }
                }
            }
            Text("Numéro chance").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                ForEach(1...10, id: \.self) { n in
                    caseNumero(n, cochee: g.chance == n, couleur: CasinoStyle.rouge) { grilles[grilleActive].chance = n }
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
        .disabled(enTirage)
    }

    private func caseNumero(_ n: Int, cochee: Bool, couleur: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(cochee ? couleur : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(cochee ? .white : .white.opacity(0.85))
        }
    }

    private func basculer(_ n: Int) {
        if grilles[grilleActive].numeros.contains(n) {
            grilles[grilleActive].numeros.remove(n)
        } else if grilles[grilleActive].numeros.count < 5 {
            grilles[grilleActive].numeros.insert(n)
        }
    }

    // MARK: Jeu

    private func jouer() {
        guard toutesCompletes, !enTirage, engine.casinoMiser(prix, jeu: .loto) else { return }
        let joue = grilles
        let prixJoue = prix
        enTirage = true
        bandeau = nil
        tirage = []
        chanceTiree = nil
        let boules = Array(Array(1...49).shuffled().prefix(5))
        let chance = Int.random(in: 1...10)
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 * Double(i + 1)) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { tirage.append(boules[i]) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { chanceTiree = chance }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            regler(joue, boules: Set(boules), chance: chance, prix: prixJoue)
        }
    }

    private func regler(_ joue: [LotoGrille], boules: Set<Int>, chance: Int, prix: Int) {
        var total = 0
        var meilleur = (bons: 0, chance: false)
        var grosLot = false
        for g in joue {
            let bons = g.numeros.intersection(boules).count
            let c = g.chance == chance
            if bons > meilleur.bons || (bons == meilleur.bons && c) { meilleur = (bons, c) }
            if let gain = LotoRegles.gain(bons: bons, chance: c) {
                total += gain
            } else {
                grosLot = true
                total += engine.casinoEtat.jackpotLoto
            }
        }
        if grosLot {
            _ = engine.casinoJackpot(loto: true, reinitialiser: true)
        } else {
            _ = engine.casinoJackpot(loto: true, ajouter: 250_000)
        }
        engine.casinoRegler(mise: prix, paiement: total, jeu: .loto, detail: "Loto")
        withAnimation {
            if grosLot {
                bandeau = "🎉 GROS LOT ! Tu gagnes \(Format.argent(total)) ! " + LotoTextes.grosLot.randomElement()!
            } else if total > prix {
                bandeau = "\(meilleur.bons) bon\(meilleur.bons > 1 ? "s" : "") numéro\(meilleur.bons > 1 ? "s" : "")\(meilleur.chance ? " + chance" : "") : tu gagnes \(Format.argent(total)). " + LotoTextes.gain.randomElement()!
            } else if total > 0 {
                bandeau = "Tu récupères \(Format.argent(total)). " + LotoTextes.rembourse.randomElement()!
            } else {
                bandeau = LotoTextes.perdu.randomElement()!
            }
            bandeauGain = total > prix ? true : (total == 0 ? false : nil)
        }
        enTirage = false
    }
}

enum LotoTextes {
    static let perdu = [
        "Aucun bon numéro. Tes numéros porte-bonheur portent surtout malheur.",
        "Perdu. Tu avais joué la date d'anniversaire de ton chat. Il s'en fiche.",
        "Rien. Mais tu as rêvé pendant 4 secondes, et ça, c'est gratuit. Enfin, 2 €.",
        "Perdu. Le présentateur a souri comme s'il te connaissait.",
        "Pas un seul. Statistiquement impressionnant, dans le mauvais sens.",
        "Perdu. Tu te dis que la semaine prochaine, c'est la bonne. Tu te le dis depuis 1998.",
    ]

    static let rembourse = [
        "C'est pas un gain, c'est un remboursement. Mais tu cries quand même.",
        "Le numéro chance t'a rendu ta mise. Le reste de la chance est en vacances.",
        "Rien de perdu, rien de gagné. La définition de ta vie.",
    ]

    static let gain = [
        "Tu as appelé ta mère pour lui dire. Elle a demandé combien. Elle a raccroché.",
        "Le buraliste t'a serré la main. Il n'avait jamais vu ça.",
        "Tu as déjà dépensé le double dans ta tête.",
        "Pas millionnaire, mais tu te sens millionnaire. Pendant cinq minutes.",
    ]

    static let grosLot = [
        "Tu as hurlé si fort que l'alarme du bar-tabac s'est déclenchée.",
        "Tu as acheté une Rolex avant même d'avoir encaissé le chèque. Puis une deuxième, pour la symétrie.",
        "Ton téléphone sonne déjà : 47 cousins, 3 ex et un prince nigérian.",
        "Tu as démissionné en direct, au téléphone, en chantant. Même si tu n'as pas de travail.",
    ]
}

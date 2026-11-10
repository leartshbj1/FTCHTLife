import SwiftUI

/// Paris sur deux dés. Au tripot, on peut tenter les dés pipés.
struct DesVue: View {
    @EnvironmentObject var engine: GameEngine
    let lieu: CasinoLieu

    @State private var mise = 0
    @State private var pari: DesPari = .plus
    @State private var de1 = 3
    @State private var de2 = 4
    @State private var rotation: Double = 0
    @State private var lance = false
    @State private var pipes = false
    @State private var bandeau: String?
    @State private var bandeauGain: Bool?
    @State private var historique: [Int] = []

    private var argent: Int { engine.joueur?.argent ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    DesFace(valeur: de1).rotationEffect(.degrees(rotation))
                    DesFace(valeur: de2).rotationEffect(.degrees(-rotation * 1.3))
                }
                .padding(.vertical, 10)
                Text("Total : \(de1 + de2)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(CasinoStyle.or)
                if !historique.isEmpty {
                    Text("Derniers lancers : " + historique.map(String.init).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                if let b = bandeau { CasinoBandeau(texte: b, gain: bandeauGain) }

                VStack(spacing: 8) {
                    ForEach(DesPari.allCases) { p in
                        Button { pari = p } label: { lignePari(p) }
                            .disabled(lance)
                    }
                }
                CasinoSelecteurMise(mise: $mise, lieu: lieu, argent: argent)
                if lieu == .tripot {
                    Toggle(isOn: $pipes) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Utiliser des dés pipés 🎲").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text("Plus de chances de gagner. Et de finir dans une poubelle.").font(.caption2).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .tint(CasinoStyle.rouge)
                    .padding(12)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
                }
                CasinoBouton(titre: "Lancer les dés", actif: !lance && CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent)) {
                    lancer()
                }
            }
            .padding()
        }
    }

    private func lignePari(_ p: DesPari) -> some View {
        HStack {
            Image(systemName: pari == p ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(CasinoStyle.or)
            VStack(alignment: .leading, spacing: 1) {
                Text(p.nom).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(p.detail).font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Text("payé \(p.gain):1").font(.caption.weight(.bold)).foregroundStyle(CasinoStyle.or)
        }
        .padding(10)
        .background(Color.black.opacity(pari == p ? 0.35 : 0.18), in: RoundedRectangle(cornerRadius: 10))
    }

    private func lancer() {
        guard !lance, engine.casinoMiser(mise, jeu: .des) else { return }
        let miseJouee = mise
        let pariJoue = pari
        let triche = pipes && lieu == .tripot
        lance = true
        bandeau = nil

        // Tirage. Avec des dés pipés, on relance discrètement une fois sur quatre si le pari est perdu.
        var a = Int.random(in: 1...6), b = Int.random(in: 1...6)
        if triche && !pariJoue.gagne(a, b) && Double.random(in: 0..<1) < 0.25 {
            a = Int.random(in: 1...6); b = Int.random(in: 1...6)
            if !pariJoue.gagne(a, b), let combo = DesPari.combinaisonGagnante(pariJoue) { (a, b) = combo }
        }
        let attrape = triche && Double.random(in: 0..<1) < 0.2

        // Animation : les dés changent de face pendant qu'ils roulent.
        for k in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.09) {
                de1 = Int.random(in: 1...6)
                de2 = Int.random(in: 1...6)
            }
        }
        withAnimation(.easeOut(duration: 0.8)) { rotation += 720 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            de1 = a
            de2 = b
            lance = false
            historique = Array(([a + b] + historique).prefix(8))
            if attrape {
                engine.casinoRegler(mise: miseJouee, paiement: 0, jeu: .des, detail: "Dés pipés")
                let ban = engine.casinoSoupcon(35, raison: "dés pipés")
                withAnimation {
                    bandeau = DesTextes.attrape.randomElement()! + (ban.map { "\n" + $0 } ?? "")
                    bandeauGain = false
                }
                return
            }
            let gagne = pariJoue.gagne(a, b)
            let paiement = gagne ? miseJouee * (pariJoue.gain + 1) : 0
            engine.casinoRegler(mise: miseJouee, paiement: paiement, jeu: .des, detail: "Dés")
            withAnimation {
                if gagne {
                    bandeau = "\(a) et \(b) : gagné, +\(Format.argent(paiement - miseJouee)) ! " + DesTextes.gagne.randomElement()!
                } else {
                    bandeau = "\(a) et \(b) : perdu. " + DesTextes.perdu.randomElement()!
                }
                bandeauGain = gagne
            }
        }
    }
}

/// Les paris possibles, avec des gains un peu en dessous des vraies probabilités (la maison gagne).
enum DesPari: String, CaseIterable, Identifiable {
    case plus, moins, sept, double, doubleSix

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .plus: return "Plus de 7"
        case .moins: return "Moins de 7"
        case .sept: return "Pile 7"
        case .double: return "Un double"
        case .doubleSix: return "Double six"
        }
    }

    var detail: String {
        switch self {
        case .plus: return "Total de 8 à 12"
        case .moins: return "Total de 2 à 6"
        case .sept: return "Le chiffre préféré des escrocs"
        case .double: return "Deux dés identiques"
        case .doubleSix: return "Le rêve, le vrai"
        }
    }

    /// Gain pour 1 misé (la mise est rendue en plus).
    var gain: Int {
        switch self {
        case .plus, .moins: return 1
        case .sept: return 4
        case .double: return 4
        case .doubleSix: return 30
        }
    }

    func gagne(_ a: Int, _ b: Int) -> Bool {
        switch self {
        case .plus: return a + b > 7
        case .moins: return a + b < 7
        case .sept: return a + b == 7
        case .double: return a == b
        case .doubleSix: return a == 6 && b == 6
        }
    }

    static func combinaisonGagnante(_ p: DesPari) -> (Int, Int)? {
        var combos: [(Int, Int)] = []
        for a in 1...6 { for b in 1...6 where p.gagne(a, b) { combos.append((a, b)) } }
        return combos.randomElement()
    }
}

/// Un dé dessiné avec ses points.
struct DesFace: View {
    let valeur: Int

    private var points: [(CGFloat, CGFloat)] {
        let g: CGFloat = 0.25, m: CGFloat = 0.5, d: CGFloat = 0.75
        switch valeur {
        case 1: return [(m, m)]
        case 2: return [(g, g), (d, d)]
        case 3: return [(g, g), (m, m), (d, d)]
        case 4: return [(g, g), (d, g), (g, d), (d, d)]
        case 5: return [(g, g), (d, g), (m, m), (g, d), (d, d)]
        default: return [(g, g), (d, g), (g, m), (d, m), (g, d), (d, d)]
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: geo.size.width * 0.18).fill(CasinoStyle.creme)
                ForEach(0..<points.count, id: \.self) { i in
                    Circle()
                        .fill(valeur == 1 ? CasinoStyle.rouge : Color.black)
                        .frame(width: geo.size.width * 0.17, height: geo.size.width * 0.17)
                        .position(x: geo.size.width * points[i].0, y: geo.size.height * points[i].1)
                }
            }
        }
        .frame(width: 80, height: 80)
        .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
    }
}

enum DesTextes {
    static let gagne = [
        "Les dés t'aiment. Profite, ça ne durera pas.",
        "Tu as soufflé dessus avant, et ça a marché. La science n'explique pas tout.",
        "Le type à côté te regarde comme si tu avais volé sa chance.",
        "Tu fais une petite danse. Personne ne te demandait ça.",
        "Les dés roulent, l'argent aussi. Vers toi, pour une fois.",
        "Tu cries « BANCO ». Ce n'est pas le bon jeu, mais l'intention y est.",
    ]

    static let perdu = [
        "Les dés ont rebondi sur un cendrier et ont changé d'avis.",
        "Tu accuses la gravité. Elle s'en fiche.",
        "Un des dés est tombé par terre. Il a fait 1 en tombant. Évidemment.",
        "Tu avais pourtant embrassé les dés. Ils n'ont rien ressenti.",
        "Le hasard a parlé. Il a dit non.",
        "Tu te jures que c'est le dernier lancer. Tu mens.",
    ]

    static let attrape = [
        "« C'est quoi ce dé qui tombe toujours sur six ? » Trois gaillards te soulèvent et te déposent dans les poubelles de la ruelle. Mise perdue.",
        "Ton dé pipé a roulé sous la table et s'est arrêté pile sur le pied du patron. Il l'a ramassé. Il l'a pesé. Tu es parti en courant, sans ta mise.",
        "Le dé était tellement truqué qu'il a fait un bruit de maracas. Tout le monde a entendu. Mise confisquée, dignité aussi.",
        "Le croupier du tripot a croqué ton dé pour vérifier. Il y avait du plomb dedans. Lui aussi, maintenant. Dehors !",
    ]
}

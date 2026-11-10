import SwiftUI

/// Quitte ou double au tripot : une pièce un peu tordue, un lanceur un peu louche.
struct PileOuFaceVue: View {
    @EnvironmentObject var engine: GameEngine
    let lieu: CasinoLieu

    @State private var mise = 0
    @State private var miseInitiale = 0
    /// Gain en jeu pendant une série (0 = pas de série en cours).
    @State private var enJeu = 0
    @State private var serie = 0
    @State private var angle: Double = 0
    @State private var face: PileOuFaceCote = .pile
    @State private var lance = false
    @State private var phrase = PileOuFaceTextes.accueil.randomElement()!
    @State private var bandeau: String?
    @State private var bandeauGain: Bool?

    private let maxSerie = 10
    private var argent: Int { engine.joueur?.argent ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 10) {
                    Text("🧔").font(.system(size: 34))
                    Text(phrase)
                        .font(.callout.italic())
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    Spacer(minLength: 0)
                }
                piece
                if enJeu > 0 {
                    VStack(spacing: 4) {
                        Text("En jeu : \(Format.argent(enJeu))")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(CasinoStyle.or)
                        Text("Série : \(serie) / \(maxSerie)").font(.caption).foregroundStyle(.white.opacity(0.7))
                    }
                }
                if let b = bandeau { CasinoBandeau(texte: b, gain: bandeauGain) }
                if enJeu == 0 {
                    CasinoSelecteurMise(mise: $mise, lieu: lieu, argent: argent)
                }
                HStack(spacing: 10) {
                    CasinoBouton(titre: enJeu > 0 ? "Doubler : Pile" : "Pile", actif: peutLancer) { lancer(.pile) }
                    CasinoBouton(titre: enJeu > 0 ? "Doubler : Face" : "Face", actif: peutLancer) { lancer(.face) }
                }
                if enJeu > 0 {
                    CasinoBouton(titre: "Encaisser \(Format.argent(enJeu))", couleur: Color(red: 0.12, green: 0.6, blue: 0.3), actif: !lance) {
                        encaisser()
                    }
                }
                Text("Gagne et choisis : encaisser, ou tout remettre en jeu. Jusqu'à \(maxSerie) fois de suite.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private var peutLancer: Bool {
        if lance { return false }
        if enJeu > 0 { return serie < maxSerie }
        return CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent)
    }

    private var piece: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.88, blue: 0.5), CasinoStyle.or, Color(red: 0.6, green: 0.45, blue: 0.1)],
                                     center: .topLeading, startRadius: 5, endRadius: 140))
            Circle().strokeBorder(Color(red: 0.55, green: 0.4, blue: 0.1), lineWidth: 6).padding(4)
            Text(face == .pile ? "PILE" : "FACE")
                .font(.system(size: 28, weight: .black, design: .serif))
                .foregroundStyle(Color(red: 0.45, green: 0.3, blue: 0.05))
        }
        .frame(width: 150, height: 150)
        .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0))
        .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
        .padding(.vertical, 8)
    }

    private func lancer(_ choix: PileOuFaceCote) {
        guard peutLancer else { return }
        if enJeu == 0 {
            guard engine.casinoMiser(mise, jeu: .pileOuFace) else { return }
            miseInitiale = mise
            enJeu = mise
            serie = 0
        }
        lance = true
        bandeau = nil
        // La pièce est « un peu tordue » : 48 % pour le joueur.
        let gagne = Double.random(in: 0..<1) < 0.48
        let resultat: PileOuFaceCote = gagne ? choix : choix.autre
        withAnimation(.easeOut(duration: 1.2)) { angle += 360 * 6 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { face = resultat }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            lance = false
            if gagne {
                enJeu *= 2
                serie += 1
                withAnimation {
                    bandeau = "\(resultat == .pile ? "Pile" : "Face") ! Tu as maintenant \(Format.argent(enJeu)) en jeu."
                    bandeauGain = true
                    phrase = PileOuFaceTextes.phraseSerie(serie)
                }
                if serie >= maxSerie { encaisser() }
            } else {
                engine.casinoRegler(mise: miseInitiale, paiement: 0, jeu: .pileOuFace, detail: "Quitte ou double")
                withAnimation {
                    bandeau = "\(resultat == .pile ? "Pile" : "Face"). Perdu : \(Format.argent(enJeu)) partent dans la poche du monsieur."
                    bandeauGain = false
                    phrase = PileOuFaceTextes.perdu.randomElement()!
                }
                enJeu = 0
                serie = 0
            }
        }
    }

    private func encaisser() {
        guard enJeu > 0 else { return }
        engine.casinoRegler(mise: miseInitiale, paiement: enJeu, jeu: .pileOuFace, detail: "Quitte ou double")
        withAnimation {
            bandeau = "Tu encaisses \(Format.argent(enJeu)) après \(serie) victoire\(serie > 1 ? "s" : "")."
            bandeauGain = true
            phrase = PileOuFaceTextes.encaisse.randomElement()!
        }
        enJeu = 0
        serie = 0
    }
}

enum PileOuFaceCote {
    case pile, face
    var autre: PileOuFaceCote { self == .pile ? .face : .pile }
}

enum PileOuFaceTextes {
    static let accueil = [
        "« Pile ou face, mon ami. Ma pièce est un peu tordue, mais moi je suis honnête. Presque. »",
        "« Une pièce, deux faces, et toi au milieu. C'est beau, non ? »",
        "« Je l'ai trouvée dans une fontaine, cette pièce. Elle porte bonheur. À moi. »",
        "« Approche, approche. Ici on double tout : l'argent, le stress, les regrets. »",
        "« Je lance, tu choisis, je ramasse. Enfin, on verra. »",
        "« Mon cousin a gagné dix fois de suite. Il habite à l'étranger maintenant. Il fuit. »",
    ]

    static func phraseSerie(_ n: Int) -> String {
        switch n {
        case 1: return ["« Pas mal. La chance du débutant. »", "« Bon. Ça arrive. Une fois. »", "« Tu veux pas t'arrêter là ? Je dis ça pour toi. »"].randomElement()!
        case 2...3: return ["« Hé, hé. Tu sais compter jusqu'à deux, toi. »", "« Je commence à transpirer un peu, c'est la chaleur. »", "« Encore ? T'es sûr ? Ma pièce fatigue. »"].randomElement()!
        case 4...5: return ["« Attends, attends. Laisse-moi souffler sur la pièce. »", "« C'est pas normal, ça. Tu as un aimant ? Montre tes poches. »", "« Mon patron va me tuer. Littéralement, il est comme ça. »"].randomElement()!
        case 6...8: return ["« Je… je vais appeler ma mère. Après ce lancer. »", "« La pièce tremble. Moi aussi. »", "« Tu crois au destin ? Moi j'y crois plus. »"].randomElement()!
        default: return ["« STOP. Je t'en supplie. J'ai une famille. Enfin, un chat. »", "« Tu es le diable. Le diable porte tes chaussures. »"].randomElement()!
        }
    }

    static let perdu = [
        "« Ohhh, dommage ! » Il ne cache même pas son sourire.",
        "« La pièce a parlé. Elle dit merci. »",
        "« C'est la vie, mon ami. Surtout la mienne, elle s'améliore. »",
        "« Tu veux te refaire ? Tout le monde veut se refaire. »",
        "« Perdu ! Mais tu as perdu avec style. Non, je mens. »",
        "« Je garde ça au chaud pour toi. Pour toujours. »",
    ]

    static let encaisse = [
        "« Bon… tu pars déjà ? Reviens vite, hein. Avec plus d'argent. »",
        "« Tu encaisses ? Lâche. Mais lâche riche. »",
        "« Prends ton argent et va-t'en avant que je pleure. »",
        "« Sage décision. Je déteste les gens sages. »",
        "« Il range ses billets en marmonnant le prénom de tous tes ancêtres. »",
    ]
}

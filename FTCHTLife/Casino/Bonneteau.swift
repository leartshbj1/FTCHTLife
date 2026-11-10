import SwiftUI

/// Le bonneteau : trois gobelets, une bille, un monsieur très sympa (trop sympa).
struct BonneteauVue: View {
    @EnvironmentObject var engine: GameEngine
    let lieu: CasinoLieu

    /// positions[g] = emplacement (0, 1, 2) où se trouve le gobelet g.
    @State private var positions = [0, 1, 2]
    /// Gobelet qui contient la bille.
    @State private var gobeletBille = 1
    @State private var phase: BonneteauPhase = .attente
    @State private var leve: Int? = nil
    @State private var mise = 0
    @State private var miseJouee = 0
    @State private var phrase = BonneteauTextes.accueil.randomElement()!
    @State private var compere = BonneteauTextes.compere.randomElement()!
    @State private var bandeau: String?
    @State private var bandeauGain: Bool?

    private var argent: Int { engine.joueur?.argent ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 10) {
                    Text("🕴️").font(.system(size: 34))
                    Text(phrase)
                        .font(.callout.italic())
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    Spacer(minLength: 0)
                }
                table
                Text("👀 Dans la foule : " + compere)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let b = bandeau { CasinoBandeau(texte: b, gain: bandeauGain) }
                if phase == .attente || phase == .fin {
                    CasinoSelecteurMise(mise: $mise, lieu: lieu, argent: argent)
                    CasinoBouton(titre: phase == .fin ? "Rejouer" : "Jouer (payé 1 pour 1)",
                                 actif: CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent)) { commencer() }
                } else if phase == .choix {
                    Text("Où est la bille ? Touche un gobelet.")
                        .font(.headline).foregroundStyle(CasinoStyle.or)
                }
            }
            .padding()
        }
    }

    private var table: some View {
        GeometryReader { geo in
            let largeur = geo.size.width / 3
            ZStack {
                // La bille est dessinée sous le gobelet qui la contient.
                Circle()
                    .fill(CasinoStyle.rouge)
                    .frame(width: 22, height: 22)
                    .position(x: largeur * (CGFloat(positions[gobeletBille]) + 0.5), y: 112)
                ForEach(0..<3, id: \.self) { g in
                    BonneteauGobelet()
                        .frame(width: 74, height: 84)
                        .position(x: largeur * (CGFloat(positions[g]) + 0.5), y: leve == g ? 50 : 82)
                        .onTapGesture { choisir(g) }
                }
            }
        }
        .frame(height: 140)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
    }

    private func commencer() {
        guard phase == .attente || phase == .fin, engine.casinoMiser(mise, jeu: .bonneteau) else { return }
        miseJouee = mise
        bandeau = nil
        phrase = BonneteauTextes.montre.randomElement()!
        compere = BonneteauTextes.compere.randomElement()!
        phase = .melange
        positions = [0, 1, 2]
        gobeletBille = Int.random(in: 0...2)
        // On montre la bille, puis on mélange.
        withAnimation(.easeInOut(duration: 0.3)) { leve = gobeletBille }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.3)) { leve = nil }
            melanger(restants: Int.random(in: 6...12), duree: 0.42)
        }
    }

    private func melanger(restants: Int, duree: Double) {
        guard restants > 0 else {
            phrase = BonneteauTextes.choix.randomElement()!
            phase = .choix
            return
        }
        let a = Int.random(in: 0...2)
        var b = Int.random(in: 0...2)
        while b == a { b = Int.random(in: 0...2) }
        // Échange des emplacements a et b.
        withAnimation(.easeInOut(duration: duree)) {
            for g in 0..<3 {
                if positions[g] == a { positions[g] = b } else if positions[g] == b { positions[g] = a }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duree + 0.05) {
            melanger(restants: restants - 1, duree: max(0.16, duree * 0.85))
        }
    }

    private func choisir(_ g: Int) {
        guard phase == .choix else { return }
        phase = .fin

        // La police débarque : tout le monde court, le monsieur part avec la mise.
        if Double.random(in: 0..<1) < 0.05 {
            engine.casinoRegler(mise: miseJouee, paiement: 0, jeu: .bonneteau, detail: "Bonneteau")
            withAnimation {
                bandeau = BonneteauTextes.police.randomElement()!
                bandeauGain = false
            }
            return
        }

        // Le jeu est truqué : la vraie chance ne dépend pas de ce que tu as suivi.
        let intelligence = Double(engine.joueur?.stats.intelligence ?? 50)
        let gagne = Double.random(in: 0..<1) < 0.15 + intelligence / 400
        if gagne {
            gobeletBille = g
        } else if gobeletBille == g {
            gobeletBille = [0, 1, 2].filter { $0 != g }.randomElement()!
        }
        withAnimation(.easeInOut(duration: 0.3)) { leve = g }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if !gagne { withAnimation(.easeInOut(duration: 0.3)) { leve = gobeletBille } }
            let paiement = gagne ? miseJouee * 2 : 0
            engine.casinoRegler(mise: miseJouee, paiement: paiement, jeu: .bonneteau, detail: "Bonneteau")
            withAnimation {
                if gagne {
                    bandeau = "Trouvé ! +\(Format.argent(miseJouee))."
                    phrase = BonneteauTextes.vexe.randomElement()!
                } else {
                    bandeau = "Raté. La bille était sous l'autre gobelet. Évidemment."
                    phrase = BonneteauTextes.gagneLui.randomElement()!
                }
                bandeauGain = gagne
                compere = BonneteauTextes.compere.randomElement()!
            }
        }
    }
}

enum BonneteauPhase {
    case attente, melange, choix, fin
}

/// Un gobelet retourné.
struct BonneteauGobelet: View {
    var body: some View {
        ZStack {
            BonneteauFormeGobelet()
                .fill(LinearGradient(colors: [Color(red: 0.85, green: 0.25, blue: 0.2), Color(red: 0.55, green: 0.1, blue: 0.1)],
                                     startPoint: .leading, endPoint: .trailing))
            BonneteauFormeGobelet().stroke(Color.black.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 3, y: 3)
    }
}

struct BonneteauFormeGobelet: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.22, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.22, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

enum BonneteauTextes {
    static let accueil = [
        "« Approchez, approchez ! Un jeu d'enfant, je vous jure sur la tête de mon cousin ! »",
        "« Trois gobelets, une bille, et la chance de ta vie. Enfin, de la mienne. »",
        "« Ici c'est simple : tu regardes bien, tu gagnes. En théorie. »",
        "« Personne n'a jamais perdu ici. Sauf tout le monde. »",
        "« Je fais ça pour l'art, pas pour l'argent. Mais je prends l'argent. »",
    ]

    static let montre = [
        "« Regarde bien la bille. Elle est là. Elle est jolie. Elle va disparaître. »",
        "« Tu la vois ? Oui ? Garde-la en mémoire, c'est tout ce qu'il te restera. »",
        "« Bille ! Gobelet ! Magie ! Ne cligne pas des yeux. »",
    ]

    static let choix = [
        "« Alors ? Lequel ? Prends ton temps. Pas trop quand même, les flics passent à 16 h. »",
        "« À toi de jouer, champion. »",
        "« Fais confiance à ton instinct. Ton instinct a tort, mais fais-lui confiance. »",
    ]

    static let vexe = [
        "« Quoi ?! » Il regarde ses gobelets comme s'ils l'avaient trahi.",
        "« Bon. Bravo. Je… je dois passer un coup de fil. » Il ne passe aucun coup de fil.",
        "« Tu as triché. Je ne sais pas comment, mais tu as triché. »",
        "« Chance du débutant. Rejoue, rejoue, tu verras. »",
        "Il te paie en billets de 5 tout froissés, en soupirant à chaque billet.",
    ]

    static let gagneLui = [
        "« Ohhh, presque ! » Il range ta mise si vite que tu ne l'as pas vue partir.",
        "« La bille est timide, elle se cache. »",
        "« Une autre ? Allez, une autre. Celle-là c'est la bonne. »",
        "« Tu avais l'œil, pourtant. Mauvais œil, mais l'œil. »",
        "« Merci pour ta contribution à l'économie locale. »",
    ]

    static let compere = [
        "un monsieur en imperméable gagne trois fois de suite, puis s'en va en sifflotant. Bizarre.",
        "une dame crie « je l'avais vu, je l'avais vu ! » Elle a l'air de beaucoup le voir.",
        "un touriste perd sa montre et sourit, il pense que ça fait partie du spectacle.",
        "un type fait le guet au coin de la rue en faisant semblant de lire un journal à l'envers.",
        "un ado filme tout en criant « c'est truqué ! ». Personne ne l'écoute.",
        "un monsieur te glisse « c'est celui du milieu ». Il est payé pour dire ça.",
    ]

    static let police = [
        "🚨 « LES BLEUS ! » Le monsieur, les gobelets, la table et ta mise disparaissent en deux secondes. Tu restes seul avec la bille.",
        "🚨 Une sirène au loin : tout le monde court dans une direction différente. Ta mise est partie dans celle du monsieur.",
        "🚨 Un policier à vélo surgit. Le monsieur se transforme en courant d'air. Ta mise aussi.",
    ]
}

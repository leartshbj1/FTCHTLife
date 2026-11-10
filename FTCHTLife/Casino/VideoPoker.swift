import SwiftUI

// MARK: - Table des gains « Valets ou mieux » 9/6

struct VideoPokerLigne: Identifiable {
    let id: String
    let nom: String
    /// Gain « pour 1 » : ce que rend la machine par euro misé, mise comprise.
    let gain: Int
}

enum VideoPokerGains {
    static let lignes: [VideoPokerLigne] = [
        VideoPokerLigne(id: "royale", nom: "Quinte flush royale", gain: 800),
        VideoPokerLigne(id: "quinteFlush", nom: "Quinte flush", gain: 50),
        VideoPokerLigne(id: "carre", nom: "Carré", gain: 25),
        VideoPokerLigne(id: "full", nom: "Full", gain: 9),
        VideoPokerLigne(id: "couleur", nom: "Couleur", gain: 6),
        VideoPokerLigne(id: "quinte", nom: "Quinte", gain: 4),
        VideoPokerLigne(id: "brelan", nom: "Brelan", gain: 3),
        VideoPokerLigne(id: "doublePaire", nom: "Double paire", gain: 2),
        VideoPokerLigne(id: "valets", nom: "Paire de Valets ou mieux", gain: 1),
    ]

    /// La ligne de la table payée par cette main, ou nil si elle ne paie rien.
    static func ligne(pour v: PokerValeurMain) -> VideoPokerLigne? {
        let id: String
        switch v.categorie {
        case .quinteFlushRoyale: id = "royale"
        case .quinteFlush: id = "quinteFlush"
        case .carre: id = "carre"
        case .full: id = "full"
        case .couleur: id = "couleur"
        case .quinte: id = "quinte"
        case .brelan: id = "brelan"
        case .doublePaire: id = "doublePaire"
        case .paire:
            guard (v.departage.first ?? 0) >= 11 else { return nil }
            id = "valets"
        case .carteHaute:
            return nil
        }
        return lignes.first { $0.id == id }
    }
}

// MARK: - Textes

enum VideoPokerTextes {
    static let royale = [
        "QUINTE FLUSH ROYALE ! La machine joue une fanfare en 8 bits et un monsieur en gilet vient te serrer la main.",
        "Royale ! Tu viens de voir une licorne, mais en cartes.",
        "Dix, Valet, Dame, Roi, As, même couleur. Les gens se retournent. Tu cries un peu trop fort.",
        "La machine clignote si fort que le casino appelle les pompiers par précaution.",
        "Une quinte flush royale. Tu prends une photo de l'écran. Puis trois. Puis tu l'encadres.",
        "Le gros lot tombe. La machine a l'air vexée.",
    ]

    static let gros = [
        "L'écran s'illumine comme un sapin de Noël. Tu fais semblant que c'est normal.",
        "La machine siffle d'admiration. Ou de panne. Dans le doute, encaisse.",
        "Même ta calculatrice est fière de toi.",
        "Tu sens une aura de chance autour de toi. Ou c'est la moquette qui sent bizarre.",
        "Ton voisin de machine te demande ton secret. Tu dis « la méditation ». Tu mens.",
        "Gros coup ! Tu tapotes l'écran avec tendresse.",
    ]

    static let moyen = [
        "Joli ! La machine émet un « ding » satisfait.",
        "Tu fais un petit poing serré discret. Très discret. Bon, tout le monde l'a vu.",
        "Belle main. Tu te sens comme un pro, en pyjama.",
        "Les jetons tombent avec un bruit délicieux.",
        "La machine te respecte. Un peu. Pour l'instant.",
        "Tu notes la date dans ton téléphone : « jour de chance ».",
        "Bien joué. Ne le dis pas à ton banquier, il serait jaloux.",
    ]

    static let petit = [
        "Petit gain. Assez pour un café, pas pour le croissant.",
        "La machine te rend un peu de ce qu'elle t'a pris. Gentille machine.",
        "Ça paie ! Modestement, mais ça paie.",
        "La classe moyenne du poker : ni riche, ni à la rue.",
        "Tu gagnes de quoi rejouer. Le piège est parfait.",
        "Petit « ding ». Petit sourire. Petite victoire.",
    ]

    static let rembourse = [
        "Tu récupères ta mise. Tu as joué pour rien, mais avec style.",
        "Remboursé ! L'équivalent casino d'un match nul.",
        "Ta mise revient vers toi comme un boomerang fatigué.",
        "Ni gagné, ni perdu. Ton compte en banque pousse un soupir de soulagement.",
        "La machine te rend ton argent, l'air de dire « allez, encore une ».",
        "Des têtes couronnées te sauvent la mise. Littéralement.",
    ]

    static let petitePaire = [
        "Une paire de {r}. Les valets, eux, ont réussi dans la vie.",
        "Paire de {r} : la machine fait semblant de ne pas l'avoir vue.",
        "Une petite paire. Mignonne, mais pas payée.",
        "Tu as une paire, mais elle est trop petite pour monter dans le manège.",
        "Paire basse. La machine ricane en silence.",
        "Si près des valets, et pourtant si loin.",
    ]

    static let perdu = [
        "Rien. Le néant. Cinq cartes qui ne se connaissent même pas.",
        "La machine avale ta mise avec un petit bruit de digestion.",
        "Tu as gardé les mauvaises cartes. Ou les bonnes, mais elles t'ont trahi.",
        "Perdu. L'écran affiche « REJOUER ? » en clignotant. C'est un piège.",
        "Hauteur As… ça sonne bien, mais ça ne paie rien.",
        "Ta main ressemble à un tirage de tarot qui annonce des ennuis.",
        "Même un pigeon aurait fait mieux en picorant l'écran.",
        "Tes cartes ont tenu une réunion et décidé de ne pas coopérer.",
        "Perdu. Ta mise est partie rejoindre ses copines dans la machine.",
        "Pas de chance. Enfin si : de la mauvaise.",
    ]
}

// MARK: - Vue

enum VideoPokerPhase { case mise, choix, fin }

struct VideoPokerVue: View {
    let lieu: CasinoLieu
    @EnvironmentObject var engine: GameEngine
    @ObservedObject private var stockage = CasinoStockage.shared

    @State private var phase: VideoPokerPhase = .mise
    @State private var mise = 0
    @State private var miseEngagee = 0
    @State private var main: [CasinoCarte] = []
    @State private var paquet: [CasinoCarte] = []
    @State private var gardes: Set<Int> = []
    @State private var cachees: Set<Int> = []
    @State private var animation = false
    @State private var message: String? = nil
    @State private var messageGain: Bool? = nil
    @State private var ligneGagnante: String? = nil

    private var argent: Int { engine.joueur?.argent ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VideoPokerTableVue(mise: phase == .mise ? mise : miseEngagee, gagnante: ligneGagnante)
                if let m = message {
                    CasinoBandeau(texte: m, gain: messageGain)
                }
                cartes
                indication
                if phase != .choix {
                    CasinoSelecteurMise(mise: $mise, lieu: lieu, argent: argent)
                        .disabled(animation)
                }
                boutonPrincipal
            }
            .padding()
        }
    }

    // MARK: Cartes

    private var cartes: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { i in
                VStack(spacing: 6) {
                    carte(i)
                    Text(gardes.contains(i) ? "GARDÉE" : " ")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(CasinoStyle.or)
                }
            }
        }
        .padding(.top, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func carte(_ i: Int) -> some View {
        if i < main.count {
            CasinoCarteVue(carte: main[i], cachee: cachees.contains(i), largeur: 58, selectionnee: gardes.contains(i))
                .onTapGesture { basculer(i) }
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: gardes)
        } else {
            CasinoCarteVue(carte: nil, largeur: 58)
        }
    }

    @ViewBuilder
    private var indication: some View {
        if phase == .choix && !animation {
            VStack(spacing: 4) {
                Text("Touche les cartes à garder, puis échange les autres.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                if main.count == 5 {
                    let v = PokerEvaluateur.evaluer(main)
                    let paie = VideoPokerGains.ligne(pour: v) != nil
                    Text("En main : \(v.description)" + (paie ? " (payée)" : ""))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(paie ? CasinoStyle.or : .white.opacity(0.6))
                }
            }
        }
    }

    @ViewBuilder
    private var boutonPrincipal: some View {
        switch phase {
        case .choix:
            let n = 5 - gardes.count
            CasinoBouton(titre: n == 0 ? "Tout garder" : "Échanger \(n) carte\(n > 1 ? "s" : "")", actif: !animation) {
                echanger()
            }
        case .mise, .fin:
            CasinoBouton(titre: phase == .fin ? "Rejouer \(Format.argent(mise))" : "Distribuer",
                         actif: !animation && CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent)) {
                distribuer()
            }
        }
    }

    // MARK: Actions

    private func basculer(_ i: Int) {
        guard phase == .choix, !animation else { return }
        if gardes.contains(i) { gardes.remove(i) } else { gardes.insert(i) }
    }

    private func distribuer() {
        guard !animation, phase != .choix, CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent) else { return }
        guard engine.casinoMiser(mise, jeu: .videoPoker) else { return }
        miseEngagee = mise
        var p = CasinoCarte.paquet()
        var nouvelles: [CasinoCarte] = []
        for _ in 0..<5 {
            if let c = p.popLast() { nouvelles.append(c) }
        }
        paquet = p
        main = nouvelles
        gardes = []
        cachees = Set(0..<5)
        message = nil
        messageGain = nil
        ligneGagnante = nil
        phase = .choix
        animation = true
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12 * Double(i + 1)) {
                _ = withAnimation(.easeOut(duration: 0.2)) { cachees.remove(i) }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            animation = false
        }
    }

    private func echanger() {
        guard phase == .choix, !animation, main.count == 5 else { return }
        animation = true
        let moteur = engine
        let misee = miseEngagee
        let aChanger = (0..<5).filter { !gardes.contains($0) }
        var nouvelleMain = main
        for i in aChanger {
            if let c = paquet.popLast() { nouvelleMain[i] = c }
        }
        withAnimation(.easeIn(duration: 0.15)) { cachees = Set(aChanger) }

        // Le résultat est connu tout de suite ; on le révèle carte par carte.
        let valeur = PokerEvaluateur.evaluer(nouvelleMain)
        let ligne = VideoPokerGains.ligne(pour: valeur)
        let paiement = misee * (ligne?.gain ?? 0)
        let texte = VideoPokerVue.texteResultat(valeur: valeur, ligne: ligne, mise: misee, paiement: paiement)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            main = nouvelleMain
        }
        for (k, i) in aChanger.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 0.15 * Double(k)) {
                _ = withAnimation(.easeOut(duration: 0.2)) { cachees.remove(i) }
            }
        }
        let fin = 0.4 + 0.15 * Double(aChanger.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + fin) {
            moteur.casinoRegler(mise: misee, paiement: paiement, jeu: .videoPoker, detail: "Vidéo poker")
            cachees = []
            let resultatGain: Bool?
            if paiement > misee {
                resultatGain = true
            } else if paiement == misee {
                resultatGain = nil
            } else {
                resultatGain = false
            }
            withAnimation(.spring()) {
                message = texte
                messageGain = resultatGain
                ligneGagnante = ligne?.id
                gardes = []
                phase = .fin
            }
            animation = false
        }
    }

    static func texteResultat(valeur: PokerValeurMain, ligne: VideoPokerLigne?, mise: Int, paiement: Int) -> String {
        guard let l = ligne else {
            if valeur.categorie == .paire {
                let r = PokerNoms.pluriel(valeur.departage.first ?? 2)
                let t = VideoPokerTextes.petitePaire.randomElement() ?? ""
                return t.replacingOccurrences(of: "{r}", with: r)
            }
            return VideoPokerTextes.perdu.randomElement() ?? "Perdu."
        }
        let entete = "\(valeur.description) : "
        let blague: String
        switch l.gain {
        case 800: blague = VideoPokerTextes.royale.randomElement() ?? ""
        case 25...: blague = VideoPokerTextes.gros.randomElement() ?? ""
        case 4...: blague = VideoPokerTextes.moyen.randomElement() ?? ""
        case 2...: blague = VideoPokerTextes.petit.randomElement() ?? ""
        default: blague = VideoPokerTextes.rembourse.randomElement() ?? ""
        }
        if paiement > mise {
            return entete + "+\(Format.argent(paiement - mise)) ! " + blague
        }
        return entete + "mise rendue. " + blague
    }
}

// MARK: - Table des gains affichée

struct VideoPokerTableVue: View {
    let mise: Int
    let gagnante: String?

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text("Valets ou mieux").font(.caption.weight(.heavy))
                Spacer()
                Text("pour 1").font(.caption2)
                Text("pour \(Format.argent(max(mise, 0)))")
                    .font(.caption2)
                    .frame(width: 96, alignment: .trailing)
            }
            .foregroundStyle(CasinoStyle.or)
            .padding(.bottom, 4)
            ForEach(VideoPokerGains.lignes) { l in
                ligne(l)
            }
        }
        .padding(10)
        .background(CasinoStyle.nuit.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CasinoStyle.or.opacity(0.5), lineWidth: 1))
    }

    private func ligne(_ l: VideoPokerLigne) -> some View {
        let active = gagnante == l.id
        return HStack {
            Text(l.nom)
                .font(.system(size: 13, weight: active ? .heavy : .medium, design: .rounded))
            Spacer()
            Text("×\(l.gain)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(Format.argent(mise * l.gain))
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(active ? CasinoStyle.nuit : .white)
        .background(active ? CasinoStyle.or : Color.clear, in: RoundedRectangle(cornerRadius: 6))
    }
}

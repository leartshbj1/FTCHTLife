import SwiftUI

// MARK: - Machines

/// Un symbole de rouleau et son poids (fréquence) sur chaque rouleau.
struct MachineSymbole: Hashable {
    let emoji: String
    let poids: Int
    /// Gain pour 3 symboles identiques (multiplicateur de la mise, mise comprise).
    let gain3: Int
}

/// Une machine à sous : un thème, des symboles, et éventuellement un gros lot progressif.
struct MachineModele: Identifiable, Hashable {
    let id: String
    let nom: String
    let slogan: String
    let couleur: Color
    let symboles: [MachineSymbole]
    /// Gain pour 2 premiers symboles identiques (multiplicateur, mise comprise), seulement pour `symboleDeux`.
    let gainDeux: Int
    let symboleDeux: String?
    let progressive: Bool

    static func == (a: MachineModele, b: MachineModele) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var poidsTotal: Int { symboles.reduce(0) { $0 + $1.poids } }

    func tirer() -> MachineSymbole {
        var r = Int.random(in: 0..<poidsTotal)
        for s in symboles {
            r -= s.poids
            if r < 0 { return s }
        }
        return symboles[symboles.count - 1]
    }

    /// Le symbole du gros lot progressif (le plus rare).
    var symboleJackpot: MachineSymbole? { progressive ? symboles.first : nil }

    static let toutes: [MachineModele] = [
        MachineModele(
            id: "fruits", nom: "Fruits Pourris", slogan: "Des fruits frais depuis 1974.",
            couleur: Color(red: 0.75, green: 0.2, blue: 0.25),
            symboles: [
                MachineSymbole(emoji: "7️⃣", poids: 2, gain3: 400),
                MachineSymbole(emoji: "🍉", poids: 4, gain3: 100),
                MachineSymbole(emoji: "🍇", poids: 6, gain3: 40),
                MachineSymbole(emoji: "🍋", poids: 8, gain3: 20),
                MachineSymbole(emoji: "🍌", poids: 10, gain3: 14),
                MachineSymbole(emoji: "🍒", poids: 12, gain3: 8),
            ],
            gainDeux: 3, symboleDeux: "🍒", progressive: false),
        MachineModele(
            id: "pharaon", nom: "Pharaon Fauché", slogan: "Même les momies ont des dettes.",
            couleur: Color(red: 0.75, green: 0.55, blue: 0.15),
            symboles: [
                MachineSymbole(emoji: "👁️", poids: 1, gain3: 1_800),
                MachineSymbole(emoji: "🐫", poids: 3, gain3: 180),
                MachineSymbole(emoji: "🏺", poids: 6, gain3: 55),
                MachineSymbole(emoji: "🐍", poids: 8, gain3: 22),
                MachineSymbole(emoji: "🪲", poids: 12, gain3: 9),
                MachineSymbole(emoji: "🧻", poids: 14, gain3: 5),
            ],
            gainDeux: 3, symboleDeux: "🧻", progressive: false),
        MachineModele(
            id: "mamie", nom: "Mamie Jackpot", slogan: "Gros lot progressif. Mamie garde la monnaie.",
            couleur: Color(red: 0.55, green: 0.3, blue: 0.7),
            symboles: [
                MachineSymbole(emoji: "👵", poids: 1, gain3: 0),
                MachineSymbole(emoji: "🫖", poids: 3, gain3: 150),
                MachineSymbole(emoji: "🧶", poids: 6, gain3: 50),
                MachineSymbole(emoji: "🍪", poids: 9, gain3: 20),
                MachineSymbole(emoji: "🐈", poids: 13, gain3: 10),
                MachineSymbole(emoji: "📺", poids: 14, gain3: 8),
            ],
            gainDeux: 4, symboleDeux: "🍪", progressive: true),
    ]
}

// MARK: - Vue

struct MachineASousVue: View {
    @EnvironmentObject var engine: GameEngine
    let lieu: CasinoLieu
    @ObservedObject private var stockage = CasinoStockage.shared

    @State private var machine = MachineModele.toutes[0]
    @State private var mise = 0
    @State private var rouleaux: [String] = ["🍒", "🍋", "7️⃣"]
    @State private var arretes = [true, true, true]
    @State private var tourne = false
    @State private var autoRestant = 0
    @State private var bandeau: String?
    @State private var bandeauGain: Bool?
    @State private var aTape = false
    @State private var tableVisible = false

    private var argent: Int { engine.joueur?.argent ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("Machine", selection: $machine) {
                    ForEach(MachineModele.toutes) { m in Text(m.nom).tag(m) }
                }
                .pickerStyle(.segmented)
                .disabled(tourne)
                .onChange(of: machine) { m in
                    rouleaux = [m.symboles[5].emoji, m.symboles[3].emoji, m.symboles[1].emoji]
                    bandeau = nil
                }

                facade
                if let b = bandeau { CasinoBandeau(texte: b, gain: bandeauGain) }
                CasinoSelecteurMise(mise: $mise, lieu: lieu, argent: argent)
                HStack(spacing: 10) {
                    CasinoBouton(titre: "Tirer le levier", actif: peutJouer) { tourner() }
                    CasinoBouton(titre: autoRestant > 0 ? "Auto (\(autoRestant))" : "Auto ×10",
                                 couleur: Color(red: 0.2, green: 0.35, blue: 0.75), actif: peutJouer) {
                        autoRestant = 10
                        tourner()
                    }
                }
                HStack(spacing: 10) {
                    CasinoBouton(titre: "Taper sur la machine", couleur: CasinoStyle.rouge, actif: !aTape && !tourne) { taper() }
                    CasinoBouton(titre: tableVisible ? "Cacher les gains" : "Table des gains", couleur: Color.black.opacity(0.5)) {
                        withAnimation { tableVisible.toggle() }
                    }
                }
                if tableVisible { tableGains }
            }
            .padding()
        }
        .onDisappear { autoRestant = 0 }
    }

    private var peutJouer: Bool {
        !tourne && CasinoSelecteurMise.valide(mise, lieu: lieu, argent: argent)
    }

    private var facade: some View {
        VStack(spacing: 10) {
            Text(machine.nom.uppercased())
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(CasinoStyle.or)
            Text(machine.slogan).font(.caption).foregroundStyle(.white.opacity(0.8))
            if machine.progressive {
                Text("GROS LOT : \(Format.argent(engine.casinoEtat.jackpotMachine))")
                    .font(.system(size: 17, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.black.opacity(0.6), in: Capsule())
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Text(rouleaux[i])
                        .font(.system(size: 52))
                        .frame(width: 84, height: 96)
                        .background(CasinoStyle.creme, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.black.opacity(0.3), lineWidth: 2))
                        .blur(radius: arretes[i] ? 0 : 1.5)
                        .scaleEffect(arretes[i] ? 1 : 0.94)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [machine.couleur, machine.couleur.opacity(0.6)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 22)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(CasinoStyle.or, lineWidth: 3))
    }

    private var tableGains: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(machine.symboles, id: \.self) { s in
                HStack {
                    Text("\(s.emoji) \(s.emoji) \(s.emoji)")
                    Spacer()
                    if machine.progressive && s == machine.symboleJackpot {
                        Text("GROS LOT").fontWeight(.bold)
                    } else {
                        Text("× \(s.gain3)")
                    }
                }
            }
            if let d = machine.symboleDeux {
                HStack {
                    Text("\(d) \(d) ·")
                    Spacer()
                    Text("× \(machine.gainDeux)")
                }
            }
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(12)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Jeu

    private func tourner() {
        guard peutJouer else { autoRestant = 0; return }
        let m = machine
        let miseJouee = mise
        guard engine.casinoMiser(miseJouee, jeu: .machines) else { autoRestant = 0; return }
        if m.progressive { _ = engine.casinoJackpot(loto: false, ajouter: max(1, miseJouee * 2 / 100)) }
        tourne = true
        bandeau = nil
        let resultat = [m.tirer(), m.tirer(), m.tirer()]
        arretes = [false, false, false]

        // Défilement : chaque rouleau change de symbole jusqu'à son arrêt.
        let pas = 0.08
        let arrets = [0.9, 1.3, 1.7]
        let nbPas = Int(arrets[2] / pas)
        for k in 0..<nbPas {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * pas) {
                for i in 0..<3 where !arretes[i] {
                    rouleaux[i] = m.symboles.randomElement()!.emoji
                }
            }
        }
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + arrets[i]) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    arretes[i] = true
                    rouleaux[i] = resultat[i].emoji
                }
                if i == 2 { terminer(m, resultat, miseJouee) }
            }
        }
    }

    private func terminer(_ m: MachineModele, _ r: [MachineSymbole], _ miseJouee: Int) {
        var paiement = 0
        var texte: String
        if r[0] == r[1] && r[1] == r[2] {
            if let jp = m.symboleJackpot, r[0] == jp {
                let lot = engine.casinoEtat.jackpotMachine
                paiement = lot + miseJouee
                _ = engine.casinoJackpot(loto: false, reinitialiser: true)
                texte = "👵👵👵 GROS LOT DE MAMIE : \(Format.argent(lot)) ! " + MachineTextes.jackpot.randomElement()!
            } else {
                paiement = miseJouee * r[0].gain3
                texte = "\(r[0].emoji)\(r[0].emoji)\(r[0].emoji) : ×\(r[0].gain3) ! " + (r[0].gain3 >= 50 ? MachineTextes.grosGain.randomElement()! : MachineTextes.petitGain.randomElement()!)
            }
        } else if let d = m.symboleDeux, r[0].emoji == d && r[1].emoji == d {
            paiement = miseJouee * m.gainDeux
            texte = "Deux \(d) : ×\(m.gainDeux). " + MachineTextes.petitGain.randomElement()!
        } else {
            texte = MachineTextes.perdu.randomElement()!
        }
        engine.casinoRegler(mise: miseJouee, paiement: paiement, jeu: .machines, detail: m.nom)
        withAnimation {
            bandeau = paiement > 0 ? texte + " (+\(Format.argent(paiement - miseJouee)))" : texte
            bandeauGain = paiement > miseJouee ? true : (paiement == 0 ? false : nil)
        }
        tourne = false
        if autoRestant > 0 {
            autoRestant -= 1
            if autoRestant > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if autoRestant > 0 { tourner() }
                }
            }
        }
    }

    private func taper() {
        guard !aTape else { return }
        aTape = true
        if Double.random(in: 0..<1) < 0.15 {
            let cadeau = max(lieu.miseMin * 3, 10)
            engine.casinoRegler(mise: 0, paiement: cadeau, jeu: .machines, detail: "Machine tapée")
            withAnimation {
                bandeau = "BLAM ! La machine crache \(Format.argent(cadeau)) de surprise. " + MachineTextes.tapeOk.randomElement()!
                bandeauGain = true
            }
        } else {
            let ban = engine.casinoSoupcon(20, raison: "maltraitance de machine à sous")
            withAnimation {
                bandeau = MachineTextes.tapeVigile.randomElement()! + (ban.map { "\n" + $0 } ?? "")
                bandeauGain = false
            }
        }
    }
}

enum MachineTextes {
    static let perdu = [
        "Rien. La machine fait un petit bruit moqueur.",
        "Perdu. Le voyant clignote « PRESQUE ». Il ment.",
        "Les rouleaux s'arrêtent sur rien du tout, avec beaucoup d'assurance.",
        "Perdu. Ta voisine de machine a soupiré pour toi.",
        "Rien. Tu tires le levier plus fort la prochaine fois, ça aide pas mais ça défoule.",
        "Perdu. La machine te remercie d'une petite musique joyeuse. Elle est joyeuse, elle.",
        "Deux sur trois… et le troisième a calé au dernier moment. Classique.",
        "Ton ticket de parking vient de coûter plus cher que prévu.",
    ]

    static let petitGain = [
        "Ding ding ding ! Pas de quoi s'acheter une maison, mais un sandwich, oui.",
        "La machine recrache quelques pièces avec mépris.",
        "Petit gain. Tu le remets dedans, c'est sûr.",
        "Victoire ! Modeste, mais victoire.",
        "Ta voisine applaudit mollement.",
    ]

    static let grosGain = [
        "Les lumières clignotent, une sirène hurle, un vieux monsieur se réveille en sursaut !",
        "LA MACHINE CHANTE ! Tout le monde se retourne. Tu salues comme une star.",
        "Gros gain ! Tu fais une danse qui restera sur les caméras de surveillance pour l'éternité.",
        "Les pièces tombent si fort que tu dois mettre ton t-shirt en sac.",
    ]

    static let jackpot = [
        "Mamie Gertrude, sur l'écran, te fait un bisou baveux. Le casino entier applaudit.",
        "Le directeur arrive en courant avec un chèque géant et une tête d'enterrement.",
        "Tu t'évanouis. Quand tu te réveilles, quelqu'un t'éventait avec ton propre chèque.",
    ]

    static let tapeOk = [
        "Tu viens de découvrir la maintenance à l'ancienne.",
        "La machine a eu peur. Toi aussi, un peu.",
        "Ça marche à la télé, ça marche en vrai.",
    ]

    static let tapeVigile = [
        "Un vigile grand comme une armoire normande s'approche : « On ne frappe pas les dames. Même les machines. »",
        "BLAM. Rien. Juste un vigile qui note ton visage dans un petit carnet.",
        "Tu t'es fait mal à la main, la machine n'a rien, et le vigile te regarde de travers.",
        "L'alarme se déclenche. Toute la salle te regarde. Un vigile te demande gentiment d'aller « respirer dehors ».",
    ]
}

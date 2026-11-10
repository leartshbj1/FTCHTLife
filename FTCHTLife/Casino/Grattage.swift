import SwiftUI

/// Un type de ticket à gratter.
struct GrattageModele: Identifiable, Hashable {
    let id: String
    let nom: String
    let prix: Int
    let cases: Int
    let couleur: Color
    /// Lots possibles et leur probabilité (le reste = perdu).
    let lots: [(montant: Int, proba: Double)]

    static func == (a: GrattageModele, b: GrattageModele) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    static let tous: [GrattageModele] = [
        GrattageModele(id: "pigeon", nom: "Pigeon Doré", prix: 2, cases: 6,
                       couleur: Color(red: 0.2, green: 0.55, blue: 0.85),
                       lots: [(2, 0.12), (4, 0.06), (10, 0.025), (50, 0.004), (500, 0.0003), (20_000, 0.000005)]),
        GrattageModele(id: "magot", nom: "Le Magot de Tata", prix: 5, cases: 9,
                       couleur: Color(red: 0.85, green: 0.45, blue: 0.15),
                       lots: [(5, 0.13), (10, 0.05), (25, 0.02), (100, 0.004), (1_000, 0.0004), (100_000, 0.000003)]),
        GrattageModele(id: "chateau", nom: "Château en Espagne", prix: 20, cases: 9,
                       couleur: Color(red: 0.6, green: 0.2, blue: 0.55),
                       lots: [(20, 0.14), (40, 0.06), (100, 0.025), (500, 0.004), (5_000, 0.0003), (500_000, 0.000005)]),
    ]

    /// Tire le lot du ticket au moment de l'achat (0 = perdant).
    func tirerLot() -> Int {
        var r = Double.random(in: 0..<1)
        for l in lots {
            r -= l.proba
            if r < 0 { return l.montant }
        }
        return 0
    }

    /// Fabrique les montants affichés : 3 fois le lot s'il est gagnant, jamais 3 identiques sinon.
    func fabriquerCases(lot: Int) -> [Int] {
        let montants = lots.map { $0.montant }
        var cases: [Int] = []
        if lot > 0 { cases = [lot, lot, lot] }
        var compte: [Int: Int] = [:]
        for c in cases { compte[c, default: 0] += 1 }
        while cases.count < self.cases {
            let m = montants.randomElement()!
            if compte[m, default: 0] < 2 {
                cases.append(m)
                compte[m, default: 0] += 1
            }
        }
        return cases.shuffled()
    }
}

struct GrattageVue: View {
    @EnvironmentObject var engine: GameEngine
    let lieu: CasinoLieu

    @State private var modele = GrattageModele.tous[0]
    @State private var cases: [Int] = []
    @State private var grattees: Set<Int> = []
    @State private var lot = 0
    @State private var prixPaye = 0
    @State private var regle = true
    @State private var bandeau: String?
    @State private var bandeauGain: Bool?
    @State private var cadres: [Int: CGRect] = [:]

    private var argent: Int { engine.joueur?.argent ?? 0 }
    private var enCours: Bool { !regle }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("Ticket", selection: $modele) {
                    ForEach(GrattageModele.tous) { m in Text("\(m.nom) · \(m.prix) €").tag(m) }
                }
                .pickerStyle(.menu)
                .tint(CasinoStyle.or)
                .disabled(enCours)

                ticket
                if let b = bandeau { CasinoBandeau(texte: b, gain: bandeauGain) }
                if enCours {
                    CasinoBouton(titre: "Tout gratter") { toutGratter() }
                } else {
                    CasinoBouton(titre: "Acheter un ticket · \(Format.argent(modele.prix))", actif: argent >= modele.prix) { acheter() }
                }
                Text("Trouve 3 montants identiques et gagne ce montant. Gratte avec le doigt !")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            .padding()
        }
    }

    private var ticket: some View {
        let colonnes = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        return VStack(spacing: 10) {
            Text(modele.nom.uppercased())
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            if cases.isEmpty {
                Text("Achète un ticket pour commencer à gratter.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                    .frame(height: 120)
            } else {
                LazyVGrid(columns: colonnes, spacing: 8) {
                    ForEach(cases.indices, id: \.self) { i in
                        caseTicket(i)
                    }
                }
                .coordinateSpace(name: "ticket")
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("ticket"))
                        .onChanged { v in
                            guard enCours else { return }
                            for (i, r) in cadres where r.contains(v.location) { gratter(i) }
                        }
                )
            }
        }
        .padding(14)
        .background(LinearGradient(colors: [modele.couleur, modele.couleur.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
    }

    private func caseTicket(_ i: Int) -> some View {
        let visible = grattees.contains(i)
        let gagnante = regle && lot > 0 && cases[i] == lot
        return ZStack {
            RoundedRectangle(cornerRadius: 10).fill(CasinoStyle.creme)
            Text(Format.argent(cases[i]))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(gagnante ? CasinoStyle.rouge : CasinoStyle.nuit)
                .minimumScaleFactor(0.5)
                .padding(4)
            if !visible {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color(white: 0.78), Color(white: 0.6)], startPoint: .top, endPoint: .bottom))
                    .overlay(Text("?").font(.title2.weight(.black)).foregroundStyle(.white.opacity(0.7)))
                    .transition(.opacity)
            }
        }
        .frame(height: 64)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { cadres[i] = geo.frame(in: .named("ticket")) }
                    .onChange(of: geo.size) { _ in cadres[i] = geo.frame(in: .named("ticket")) }
            }
        )
        .onTapGesture { gratter(i) }
    }

    private func acheter() {
        guard !enCours, engine.casinoMiser(modele.prix, jeu: .grattage) else { return }
        prixPaye = modele.prix
        lot = modele.tirerLot()
        cases = modele.fabriquerCases(lot: lot)
        cadres = [:]
        grattees = []
        bandeau = nil
        regle = false
    }

    private func gratter(_ i: Int) {
        guard enCours, !grattees.contains(i) else { return }
        _ = withAnimation(.easeOut(duration: 0.25)) { grattees.insert(i) }
        if grattees.count == cases.count { terminer() }
    }

    private func toutGratter() {
        withAnimation(.easeOut(duration: 0.3)) { grattees = Set(cases.indices) }
        terminer()
    }

    private func terminer() {
        guard !regle else { return }
        regle = true
        engine.casinoRegler(mise: prixPaye, paiement: lot, jeu: .grattage, detail: modele.nom)
        withAnimation {
            if lot > prixPaye {
                bandeau = "Trois fois \(Format.argent(lot)) ! " + (lot >= 1_000 ? GrattageTextes.gros.randomElement()! : GrattageTextes.petit.randomElement()!)
                bandeauGain = true
            } else if lot > 0 {
                bandeau = "Trois fois \(Format.argent(lot)) : remboursé. " + GrattageTextes.rembourse.randomElement()!
                bandeauGain = nil
            } else {
                bandeau = GrattageTextes.perdu.randomElement()!
                bandeauGain = false
            }
        }
    }
}

enum GrattageTextes {
    static let perdu = [
        "Perdant. Mais il y avait DEUX fois 20'000 €. Le ticket se moque de toi.",
        "Rien. Tu as gratté si fort que tu as troué le ticket. Et la table.",
        "Perdu. Le buraliste te tend déjà un autre ticket, avec un sourire de requin.",
        "Perdu. Tes ongles sont pleins de poussière grise et de regrets.",
        "Rien du tout. C'est écrit en petit : « Le jeu, c'est pour s'amuser. » Tu ne t'amuses pas.",
        "Perdant. Tu le grattes une deuxième fois, au cas où. Toujours perdant.",
    ]

    static let rembourse = [
        "Tu rachètes un ticket avec, bien sûr.",
        "Ni gagné, ni perdu. Juste un peu de poussière sous les ongles.",
        "Le ticket te rend ta mise, comme un ami qui rend un livre sans l'avoir lu.",
    ]

    static let petit = [
        "Le buraliste te paie en pièces jaunes. Il le fait exprès.",
        "Tu as fait un petit bruit aigu. Tout le bar t'a entendu.",
        "Victoire ! Tu offres un café à toi-même.",
        "C'est le début de la fortune. Ou d'un problème.",
    ]

    static let gros = [
        "Tu as relu le ticket 14 fois. C'est vrai. Tu t'assois par terre.",
        "Le buraliste a dû appeler un numéro spécial pour te payer. Tu tremblais tellement qu'il a composé le numéro pour toi.",
        "Tu as embrassé le ticket, puis le buraliste, puis un client au hasard.",
    ]
}

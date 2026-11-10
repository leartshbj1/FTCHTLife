import SwiftUI

/// Le quiz « Cerveau ou Râteau » : 10 questions, un chrono, trois jokers, une trappe.
/// Le casting est passé avant d'ouvrir cet écran (`GameEngine.teleQuizCasting`).
struct TeleQuizView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case question, revele, fini }

    @State private var questions: [TeleQuestion] = []
    @State private var index = 0
    @State private var reponses: [String] = []
    @State private var choisie: String?
    @State private var phase: Phase = .question
    @State private var temps = TeleQuiz.secondesParQuestion
    @State private var masquees: Set<String> = []
    @State private var publicPc: [Int]?
    @State private var appel: String?
    @State private var joker5050 = true
    @State private var jokerAppel = true
    @State private var jokerPublic = true
    @State private var texteFin: String?
    @State private var confirmerEncaisser = false
    @State private var sansFaute = false

    private let horloge = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var question: TeleQuestion? { questions.indices.contains(index) ? questions[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            entete
            ScrollView {
                VStack(spacing: 14) {
                    if let fin = texteFin {
                        ecranFin(fin)
                    } else if let q = question {
                        carteQuestion(q)
                        jokers(q)
                        if let a = appel { bulle(a, icone: "phone.fill") }
                        VStack(spacing: 10) {
                            ForEach(Array(reponses.enumerated()), id: \.offset) { i, r in
                                boutonReponse(r, lettre: ["A", "B", "C", "D"][i % 4], pc: publicPc?[teleSur: i], q: q)
                            }
                        }
                        if phase == .revele {
                            bulle(choisie == q.bonne ? "Bonne réponse ! Le public applaudit, un monsieur se lève."
                                                     : (choisie == nil ? "Temps écoulé ! Le buzzer fait un bruit de canard." : "Hmm…"),
                                  icone: "megaphone.fill")
                        }
                    } else {
                        Text("La régie a perdu les questions. Rentre chez toi.")
                    }
                }
                .padding()
            }
            barreBas
                .padding()
                .background(Theme.carte)
        }
        .background(Theme.fond.ignoresSafeArea())
        .onAppear(perform: demarrer)
        .onReceive(horloge) { _ in tic() }
        .confirmationDialog("Encaisser \(Format.argent(gainActuel)) et rentrer chez toi ?", isPresented: $confirmerEncaisser, titleVisibility: .visible) {
            Button("J'encaisse") { terminer(bonnes: index, encaisse: true) }
            Button("Je continue", role: .cancel) {}
        }
    }

    // MARK: Logique

    private var gainActuel: Int { index > 0 ? TeleQuiz.echelle[min(index, TeleQuiz.echelle.count) - 1] : 0 }

    private func demarrer() {
        guard questions.isEmpty else { return }
        questions = TeleQuiz.tirerQuestions()
        preparer()
    }

    private func preparer() {
        guard let q = question else { return }
        reponses = ([q.bonne] + q.mauvaises).shuffled()
        choisie = nil
        masquees = []
        publicPc = nil
        appel = nil
        temps = TeleQuiz.secondesParQuestion
        phase = .question
    }

    private func tic() {
        guard phase == .question, texteFin == nil, question != nil else { return }
        temps -= 1
        if temps <= 0 { repondre(nil) }
    }

    private func repondre(_ r: String?) {
        guard phase == .question, let q = question else { return }
        withAnimation {
            choisie = r
            phase = .revele
        }
        if r != q.bonne {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                terminer(bonnes: index, encaisse: false)
            }
        } else if index == questions.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                terminer(bonnes: questions.count, encaisse: false)
            }
        }
    }

    private func suivante() {
        withAnimation {
            index += 1
            preparer()
        }
    }

    private func terminer(bonnes: Int, encaisse: Bool) {
        guard texteFin == nil else { return }
        let derniere = encaisse ? nil : question
        sansFaute = bonnes >= questions.count
        withAnimation {
            phase = .fini
            texteFin = engine.teleQuizFin(bonnes: bonnes, encaisse: encaisse, derniereQuestion: derniere)
        }
    }

    // MARK: Vues

    private var entete: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile").font(.title2).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cerveau ou Râteau").font(.headline)
                    Text(texteFin == nil ? "Question \(min(index + 1, 10)) sur \(TeleQuiz.echelle.count) · pour \(Format.argent(TeleQuiz.echelle[min(index, TeleQuiz.echelle.count - 1)]))"
                                         : "Fin de l'émission")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if texteFin == nil && phase == .question {
                    Text("\(temps)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(temps <= 5 ? .red : Theme.encre)
                        .frame(width: 44, height: 44)
                        .background(Circle().stroke(temps <= 5 ? Color.red : Theme.accent, lineWidth: 3))
                }
            }
            echelle
        }
        .padding()
        .background(Theme.carte)
    }

    /// L'échelle des gains, de gauche à droite.
    private var echelle: some View {
        HStack(spacing: 3) {
            ForEach(Array(TeleQuiz.echelle.enumerated()), id: \.offset) { i, g in
                let fait = i < index || (texteFin != nil && i < index)
                Text(Self.court(g))
                    .font(.system(size: 9, weight: i == TeleQuiz.palier ? .black : .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(i == index && texteFin == nil ? Theme.accent : (fait ? Theme.accent.opacity(0.3) : Color.black.opacity(0.06)),
                                in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(i == index && texteFin == nil ? Color.white : Theme.encre)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(i == TeleQuiz.palier ? Theme.accent : Color.clear, lineWidth: 1))
            }
        }
    }

    static func court(_ g: Int) -> String {
        g >= 1000 ? "\(g / 1000)k" : "\(g)"
    }

    private func carteQuestion(_ q: TeleQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(q.theme.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(q.question)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.encre)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.carte, in: RoundedRectangle(cornerRadius: 14))
    }

    private func jokers(_ q: TeleQuestion) -> some View {
        HStack(spacing: 10) {
            joker("50 / 50", icone: "circle.lefthalf.filled", dispo: joker5050) {
                joker5050 = false
                let faux = reponses.filter { $0 != q.bonne }.shuffled().prefix(2)
                withAnimation { masquees = Set(faux) }
            }
            joker("Appel", icone: "phone.fill", dispo: jokerAppel) {
                jokerAppel = false
                let a = engine.teleQuizAppel(q)
                withAnimation {
                    appel = a.sur
                        ? "\(a.nom) : « C'est \(a.reponse), j'en suis sûr·e à 100 %. Enfin, à 80 %. »"
                        : "\(a.nom) : « Euh… \(a.reponse) ? Ou pas. Je suis aux toilettes, là. »"
                }
            }
            joker("Public", icone: "person.3.fill", dispo: jokerPublic) {
                jokerPublic = false
                withAnimation { publicPc = GameEngine.teleQuizPublic(q, reponses: reponses) }
            }
        }
    }

    private func joker(_ titre: String, icone: String, dispo: Bool, action: @escaping () -> Void) -> some View {
        let actif = dispo && phase == .question
        return Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icone)
                Text(titre).font(.caption2.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(actif ? Theme.accent.opacity(0.15) : Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(actif ? Theme.accent : Color.gray)
            .overlay {
                if !dispo { Image(systemName: "xmark").font(.title2.weight(.bold)).foregroundStyle(.red.opacity(0.7)) }
            }
        }
        .disabled(!actif)
    }

    private func boutonReponse(_ r: String, lettre: String, pc: Int?, q: TeleQuestion) -> some View {
        let cachee = masquees.contains(r)
        let couleur: Color = {
            guard phase != .question else { return Theme.carte }
            if r == q.bonne { return Color(red: 0.16, green: 0.68, blue: 0.38) }
            if r == choisie { return Color(red: 0.88, green: 0.22, blue: 0.22) }
            return Theme.carte
        }()
        let blanc = phase != .question && (r == q.bonne || r == choisie)
        return Button { repondre(r) } label: {
            HStack(spacing: 10) {
                Text(lettre)
                    .font(.headline.weight(.black))
                    .foregroundStyle(blanc ? Color.white : Theme.accent)
                    .frame(width: 22)
                Text(cachee ? " " : r)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(blanc ? Color.white : Theme.encre)
                    .multilineTextAlignment(.leading)
                Spacer()
                if let p = pc, !cachee {
                    Text("\(p) %")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(blanc ? Color.white : Color.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(couleur, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
            .opacity(cachee ? 0.35 : 1)
        }
        .disabled(cachee || phase != .question)
    }

    private func bulle(_ texte: String, icone: String) -> some View {
        Label(texte, systemImage: icone)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    private func ecranFin(_ texte: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: sansFaute ? "trophy.fill" : "brain.head.profile")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(texte)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.encre)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.carte, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var barreBas: some View {
        if texteFin != nil || question == nil {
            boutonPlein("Quitter le plateau") { dismiss() }
        } else if phase == .revele, choisie == question?.bonne, index < questions.count - 1 {
            HStack(spacing: 10) {
                boutonPlein("Encaisser \(Self.court(TeleQuiz.echelle[index]))", plein: false) {
                    terminer(bonnes: index + 1, encaisse: true)
                }
                boutonPlein("Question suivante") { suivante() }
            }
        } else if phase == .question {
            boutonPlein(index == 0 ? "Partir sans rien" : "Encaisser \(Format.argent(gainActuel))", plein: false) {
                if index == 0 { terminer(bonnes: 0, encaisse: true) } else { confirmerEncaisser = true }
            }
        } else {
            boutonPlein("…", plein: false) {}
                .disabled(true)
        }
    }

    private func boutonPlein(_ titre: String, plein: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titre)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(plein ? Theme.accent : Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(plein ? Color.white : Theme.accent)
        }
    }
}

private extension Array {
    subscript(teleSur i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

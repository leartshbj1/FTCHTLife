import SwiftUI

/// Mini-jeu de l'oral (oral de français en 1re, grand oral en terminale) :
/// 3 questions du jury, 15 secondes pour répondre à chacune.
struct ScolOralView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let examen: String
    let onFin: () -> Void

    static let duree = 15

    @State private var oral: ScolOral? = nil
    @State private var pret = false
    @State private var commence = false
    @State private var index = 0
    @State private var points = 0
    @State private var temps = ScolOralView.duree
    @State private var reponses: [ScolReponse] = []
    @State private var reaction: String? = nil
    @State private var gain = 0
    @State private var note: Double? = nil
    @State private var resultat: String? = nil
    @State private var contexte = ScolContexte(matiere: "francais", prof: "le jury", camarade: "")

    private let horloge = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var titre: String { examen == "francais" ? "Oral de français" : "Grand oral" }

    var body: some View {
        Group {
            if let r = resultat {
                fin(r)
            } else if let o = oral, commence, o.questions.indices.contains(index) {
                question(o, o.questions[index])
            } else {
                accueil
            }
        }
        .interactiveDismissDisabled(commence && resultat == nil)
        .onAppear {
            guard !pret else { return }
            pret = true
            oral = engine.scolTirerOral(examen)
            let m = examen == "francais" ? "francais" : "philo"
            contexte = ScolContexte(matiere: m, prof: ScolDonnees.prof(m), camarade: "")
        }
        .onReceive(horloge) { _ in
            guard commence, resultat == nil, reaction == nil else { return }
            if temps > 0 { temps -= 1 }
            if temps == 0 { repondre(nil) }
        }
    }

    // MARK: Écrans

    private var accueil: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "mic.fill").font(.system(size: 44)).foregroundStyle(Theme.accent).padding(.top, 20)
                Text(titre).font(.title2.weight(.black))
                if let o = oral {
                    Text("Ton sujet").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(engine.scolTexte(o.sujet, contexte)).font(.headline).multilineTextAlignment(.center)
                    Text(engine.scolTexte(o.intro, contexte)).multilineTextAlignment(.center)
                    Text("3 questions, \(ScolOralView.duree) secondes pour répondre à chacune. Le silence ne rapporte aucun point.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    ScolBouton(titre: "Entrer dans la salle") {
                        preparerQuestion(o)
                        commence = true
                    }
                } else {
                    Text("Le jury est en grève. On te met une note au hasard, comme d'habitude.")
                        .multilineTextAlignment(.center)
                    ScolBouton(titre: "D'accord") {
                        terminer(points: Int.random(in: 5...11), maximum: 15)
                    }
                }
                Button("Plus tard") { dismiss() }.font(.footnote).padding(.top, 4)
            }
            .padding()
        }
    }

    private func question(_ o: ScolOral, _ q: ScolQuestion) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Question \(index + 1)/\(o.questions.count)").font(.caption.weight(.bold))
                    Spacer()
                    Label("\(temps) s", systemImage: "timer")
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(temps <= 5 ? Color.red : Theme.encre)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.08))
                        Capsule().fill(temps <= 5 ? Color.red : Theme.accent)
                            .frame(width: geo.size.width * CGFloat(temps) / CGFloat(ScolOralView.duree))
                            .animation(.linear(duration: 1), value: temps)
                    }
                }
                .frame(height: 8)

                Text(engine.scolTexte(q.question, contexte))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)

                if let r = reaction {
                    Text(r)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.fond, in: RoundedRectangle(cornerRadius: 14))
                    Text(gain >= 4 ? "Le jury note quelque chose. Ça a l'air positif." : gain >= 2 ? "Le jury reste de marbre." : "Le jury soupire en chœur.")
                        .font(.caption).foregroundStyle(.secondary)
                    ScolBouton(titre: index + 1 < o.questions.count ? "Question suivante" : "Fin de l'oral") {
                        suivante(o)
                    }
                } else {
                    ForEach(Array(reponses.enumerated()), id: \.offset) { _, r in
                        ScolBouton(titre: engine.scolTexte(r.text, contexte), secondaire: true) { repondre(r) }
                    }
                }
            }
            .padding()
        }
    }

    private func fin(_ texte: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            if let n = note {
                Text("\(ScolRegles.formatNote(n))/20")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.couleurStat(Int(n * 5)))
            }
            Text(texte).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
            Spacer()
            ScolBouton(titre: "Sortir de la salle", action: onFin)
        }
        .padding()
    }

    // MARK: Logique


    private func preparerQuestion(_ o: ScolOral) {
        guard o.questions.indices.contains(index) else { return }
        reponses = o.questions[index].reponses.shuffled()
        reaction = nil
        temps = ScolOralView.duree
    }

    private func repondre(_ r: ScolReponse?) {
        guard reaction == nil else { return }
        if let r = r {
            gain = r.points
            points += r.points
            reaction = engine.scolTexte(r.reaction, contexte)
        } else {
            gain = 0
            reaction = "Tu as fixé le jury en silence pendant quinze secondes. Eux aussi. C'était très gênant pour tout le monde."
        }
    }

    private func suivante(_ o: ScolOral) {
        index += 1
        if index >= o.questions.count {
            terminer(points: points, maximum: o.questions.count * 5)
        } else {
            preparerQuestion(o)
        }
    }

    private func terminer(points: Int, maximum: Int) {
        let r = engine.scolTerminerOral(examen: examen, points: points, maximum: maximum)
        note = r.note
        resultat = r.texte
    }
}

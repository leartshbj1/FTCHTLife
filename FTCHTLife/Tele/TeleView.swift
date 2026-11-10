import SwiftUI

/// Écran « Télévision » : quiz, téléréalité, célébrité et offres. Voir docs/TELE.md pour le branchement.
struct TeleView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var partie: TelePartie?
    @State private var quizOuvert = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let etat = engine.teleEtat
                    Section { carteCelebrite(j, etat) }

                    Section("Jeu télé") {
                        LigneAction(titre: "Cerveau ou Râteau",
                                    sousTitre: engine.teleQuizIndisponible()
                                        ?? "Quiz de culture générale. 10 questions, jusqu'à \(Format.argent(TeleQuiz.echelle.last ?? 0)).",
                                    icone: "brain.head.profile",
                                    actif: engine.teleQuizIndisponible() == nil) {
                            if let refus = engine.teleQuizCasting() {
                                message = refus
                            } else {
                                quizOuvert = true
                            }
                        }
                    }

                    Section("Téléréalité") {
                        if TeleBibliotheque.emissions.isEmpty {
                            Text("Aucune émission à l'antenne. La grille est en grève.")
                        }
                        ForEach(TeleBibliotheque.emissions) { e in
                            let raison = engine.teleIndisponible(e)
                            LigneAction(titre: e.nom,
                                        sousTitre: raison ?? (e.slogan + " · Gain : \(Format.argent(e.prix))"),
                                        icone: e.icone,
                                        actif: raison == nil) {
                                let r = engine.teleCasting(e)
                                if let p = r.partie {
                                    partie = p
                                } else {
                                    message = r.texte
                                }
                            }
                        }
                    }

                    let offres = engine.teleOffres()
                    if !offres.isEmpty {
                        Section("Monnayer ta célébrité") {
                            ForEach(offres) { o in
                                let dispo = engine.teleOffreDisponible(o)
                                LigneAction(titre: o.titre,
                                            sousTitre: dispo ? o.description : "Déjà fait cette année.",
                                            icone: o.icone,
                                            actif: dispo) {
                                    message = engine.teleAccepterOffre(o)
                                }
                            }
                        }
                    } else if etat.participations > 0 {
                        Section("Monnayer ta célébrité") {
                            Text("Ton téléphone ne sonne plus. Même les supermarchés ne veulent plus de toi pour couper un ruban.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !etat.momentsCultes.isEmpty {
                        Section("Tes moments cultes") {
                            ForEach(Array(etat.momentsCultes.reversed().enumerated()), id: \.offset) { _, m in
                                Label(String(m.prefix(1)).uppercased() + String(m.dropFirst()), systemImage: "film.stack")
                                    .font(.callout)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Télévision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("📺 FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
            .fullScreenCover(item: $partie) { p in
                TeleEmissionView(partie: p).environmentObject(engine)
            }
            .fullScreenCover(isPresented: $quizOuvert) {
                TeleQuizView().environmentObject(engine)
            }
        }
    }

    private func carteCelebrite(_ j: Joueur, _ etat: TeleEtat) -> some View {
        let c = etat.celebrite(age: j.age)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(etat.statut(age: j.age)).font(.headline)
                    Text(etat.participations == 0
                         ? "Tu n'es jamais passé·e à la télé. Pas même en arrière-plan d'un micro-trottoir."
                         : "\(etat.participations) passage\(etat.participations > 1 ? "s" : "") à la télé · \(etat.victoires) victoire\(etat.victoires > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            BarreStat(titre: "Célébrité", icone: "sparkles", valeur: c)
            if etat.participations > 0 {
                HStack {
                    Text("Gains télé : \(Format.argent(etat.gainsTotaux))")
                    Spacer()
                    Text("Record quiz : \(Format.argent(etat.recordQuiz))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("La gloire fond d'un tiers chaque année. Profites-en vite.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Émission à manches

struct TeleEmissionView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var partie: TelePartie
    @State private var confirmerAbandon = false

    init(partie: TelePartie) {
        _partie = State(initialValue: partie)
    }

    var body: some View {
        VStack(spacing: 0) {
            entete
            ScrollView {
                VStack(spacing: 14) {
                    carte(partie.texteSituation, fond: Theme.carte, gras: true)
                    if let r = partie.texteResultat {
                        carte(r, fond: Theme.accent.opacity(0.10), gras: false)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if let f = partie.texteFin {
                        finale(f)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding()
            }
            boutons
                .padding()
                .background(Theme.carte)
        }
        .background(Theme.fond.ignoresSafeArea())
        .confirmationDialog("Quitter l'émission ? La production gardera les images.", isPresented: $confirmerAbandon, titleVisibility: .visible) {
            Button("Abandonner", role: .destructive) {
                withAnimation { engine.teleAbandonner(&partie) }
            }
        }
    }

    private var entete: some View {
        let nb = partie.emission.manches.count
        let titre = partie.emission.manches.indices.contains(partie.manche) ? partie.emission.manches[partie.manche].titre : ""
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: partie.emission.icone)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(partie.emission.nom).font(.headline)
                    Text(titre).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if partie.fin == nil {
                    Button { confirmerAbandon = true } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<nb, id: \.self) { i in
                    Capsule()
                        .fill(i < partie.manche || (i == partie.manche && partie.fin == .victoire) ? Theme.accent
                              : (i == partie.manche ? Theme.accent.opacity(0.45) : Color.black.opacity(0.08)))
                        .frame(height: 6)
                }
            }
            HStack {
                Label("\(Format.argent(partie.cachets)) de cachets", systemImage: "banknote")
                Spacer()
                Label("+\(partie.celebriteGagnee) célébrité", systemImage: "sparkles")
                if partie.enCouple {
                    Image(systemName: "heart.fill").foregroundStyle(.pink)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Theme.carte)
    }

    private func carte(_ texte: String, fond: Color, gras: Bool) -> some View {
        Text(texte)
            .font(gras ? .body.weight(.semibold) : .body)
            .foregroundStyle(Theme.encre)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(fond, in: RoundedRectangle(cornerRadius: 14))
    }

    private func finale(_ texte: String) -> some View {
        let (icone, titre): (String, String) = {
            switch partie.fin {
            case .victoire: return ("trophy.fill", "VICTOIRE !")
            case .defaiteFinale: return ("medal.fill", "Finaliste")
            case .elimine: return ("hand.thumbsdown.fill", "Éliminé·e")
            case .abandon: return ("figure.walk.departure", "Abandon")
            case .mort, nil: return ("cross.fill", "Fin de tournage")
            }
        }()
        return VStack(spacing: 8) {
            Image(systemName: icone).font(.system(size: 40)).foregroundStyle(Theme.accent)
            Text(titre).font(.title2.weight(.black))
            Text(texte).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.carte, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent, lineWidth: 2))
    }

    @ViewBuilder
    private var boutons: some View {
        if partie.fin != nil {
            bouton("Quitter le plateau") { dismiss() }
        } else if partie.attenteSuite {
            bouton(partie.derniereManche ? "Résultat de la finale" : "Verdict de la semaine") {
                withAnimation { engine.teleSuite(&partie) }
            }
        } else {
            VStack(spacing: 10) {
                ForEach(Array(partie.situation.choix.enumerated()), id: \.offset) { i, c in
                    bouton(c.label, sousTitre: Self.libelleStat(c.stat)) {
                        withAnimation { engine.teleChoisir(&partie, i) }
                    }
                }
            }
        }
    }

    private func bouton(_ titre: String, sousTitre: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(titre).font(.headline).multilineTextAlignment(.center)
                if let s = sousTitre {
                    Text(s).font(.caption2).opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
    }

    static func libelleStat(_ stat: String) -> String {
        switch stat {
        case "sante": return "Physique"
        case "bonheur": return "Moral"
        case "intelligence": return "Cerveau"
        case "apparence": return "Look"
        case "karma": return "Karma"
        case "charisme": return "Charisme"
        case "voix": return "Voix"
        case "cuisine": return "Cuisine"
        case "celebrite": return "Célébrité"
        default: return "Chance"
        }
    }
}

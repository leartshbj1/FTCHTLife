import SwiftUI

/// Gros bouton orange, comme dans les événements.
struct ScolBouton: View {
    let titre: String
    var secondaire: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titre)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(secondaire ? Theme.fond : Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(secondaire ? Theme.encre : Color.white)
        }
        .buttonStyle(.plain)
    }
}

/// Ouvre une chose à faire : situation, convocation, voyage ou oral.
struct ScolTacheView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let tache: ScolTache

    var body: some View {
        NavigationStack {
            contenu
                .navigationTitle(engine.scolTitre(tache).titre)
                .navigationBarTitleDisplayMode(.inline)
                .background(Theme.carte)
        }
    }

    @ViewBuilder
    private var contenu: some View {
        switch tache.sorte {
        case .situation, .convocation:
            if let s = engine.scolScene(tache) {
                ScolSceneCarte(scene: s, tache: tache) { dismiss() }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Plus tard") { dismiss() } } }
            } else {
                introuvable
            }
        case .voyage:
            if let v = ScolDonnees.voyage(tache.ref) {
                ScolVoyageView(voyage: v) { dismiss() }
            } else {
                introuvable
            }
        case .oral:
            ScolOralView(examen: tache.ref) { dismiss() }
        }
    }

    private var introuvable: some View {
        VStack(spacing: 20) {
            Text("Cette page du carnet de correspondance a été mangée par le chien.")
                .multilineTextAlignment(.center)
            ScolBouton(titre: "Tant pis") {
                engine.scolRetirer(tache)
                dismiss()
            }
        }
        .padding()
    }
}

/// Une carte à choix (situation, convocation ou scène de voyage).
struct ScolSceneCarte: View {
    @EnvironmentObject var engine: GameEngine
    let scene: ScolScene
    /// La tâche à retirer une fois la scène jouée (nil pour une scène de voyage).
    let tache: ScolTache?
    var boutonFin: String = "OK"
    let onFin: () -> Void

    @State private var ctx: ScolContexte? = nil
    @State private var texte = ""
    @State private var choixFait: String? = nil
    @State private var resultat: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(texte)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                if let r = resultat {
                    if let c = choixFait {
                        Text(c).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                    }
                    Text(r)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.fond, in: RoundedRectangle(cornerRadius: 14))
                    ScolBouton(titre: boutonFin, action: onFin)
                } else {
                    ForEach(Array(scene.choices.enumerated()), id: \.offset) { i, c in
                        ScolBouton(titre: c.label) { choisir(i, c.label) }
                    }
                }
            }
            .padding()
        }
        .onAppear(perform: preparer)
    }

    private func preparer() {
        guard ctx == nil, let j = engine.joueur else { return }
        let c = ScolContexte.nouveau(j)
        ctx = c
        texte = engine.scolTexte(scene.text, c)
    }

    private func choisir(_ i: Int, _ label: String) {
        guard resultat == nil, let c = ctx else { return }
        choixFait = label
        resultat = engine.scolChoisir(scene, choix: i, ctx: c, texteAffiche: texte, tache: tache)
    }
}

/// Le voyage scolaire : partir ou pas, puis deux scènes, puis le retour.
struct ScolVoyageView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let voyage: ScolVoyage
    let onFin: () -> Void

    @State private var depart: String? = nil
    @State private var scenes: [ScolScene] = []
    @State private var etape = 0
    @State private var retour: String? = nil

    var body: some View {
        Group {
            if let r = retour {
                fin(r)
            } else if depart == nil {
                accueil
            } else if etape < scenes.count {
                ScolSceneCarte(scene: scenes[etape], tache: nil, boutonFin: "Suite du voyage") {
                    etape += 1
                    if etape >= scenes.count { retour = engine.scolTerminerVoyage(voyage, parti: true) }
                }
                .id(scenes[etape].id)
            } else {
                fin(retour ?? "")
            }
        }
        .interactiveDismissDisabled(depart != nil && retour == nil)
    }

    private var accueil: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "bus.fill").font(.system(size: 44)).foregroundStyle(Theme.accent).padding(.top, 20)
                Text(voyage.destination).font(.title2.weight(.black))
                Text(engine.scolTexte(voyage.intro, ScolContexte(matiere: "histoire", prof: ScolDonnees.prof("histoire"), camarade: "")))
                    .multilineTextAlignment(.center)
                Text("Prix : \(Format.argent(voyage.cout))" + ((engine.joueur?.age ?? 0) < 18 ? " (tes parents paient)" : ""))
                    .font(.caption).foregroundStyle(.secondary)
                ScolBouton(titre: "Partir !") {
                    let r = engine.scolPartirEnVoyage(voyage)
                    scenes = r.scenes
                    depart = r.texte
                    if scenes.isEmpty { retour = engine.scolTerminerVoyage(voyage, parti: true) }
                }
                ScolBouton(titre: "Rester en cours", secondaire: true) {
                    depart = ""
                    retour = engine.scolTerminerVoyage(voyage, parti: false)
                }
                Button("Plus tard") { dismiss() }.font(.footnote).padding(.top, 4)
            }
            .padding()
        }
    }

    private func fin(_ texte: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            if let d = depart, !d.isEmpty {
                Text(d).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Text(texte).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
            Spacer()
            ScolBouton(titre: "Fin du voyage", action: onFin)
        }
        .padding()
    }
}

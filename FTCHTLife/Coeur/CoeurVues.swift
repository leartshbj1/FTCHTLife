import SwiftUI

// Sections du module « Cœur », affichées dans l'écran Amour (ListeRelationsView, filtre .amour).

struct CoeurSection: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.presentoir) private var presentoir
    @State private var message: String?

    var body: some View {
        Group {
            if let j = engine.joueur {
                let c = j.coeurEtat
                if let l = c.liaison, j.partenaireActuel != nil {
                    sectionLiaison(l, j)
                }
                if j.partenaireActuel != nil {
                    sectionCouple(j, c)
                }
                if !c.enfantsCaches.filter({ !$0.reconnu }).isEmpty {
                    sectionEnfants(j, c)
                }
            }
        }
        .vieAlerte($message)
    }

    private func faire(_ action: CoeurSysteme.Action) {
        let texte = engine.vieAction { j in CoeurSysteme.agir(action, &j) }
        guard !texte.isEmpty else { return }
        if let p = presentoir { p.montrer(texte) } else { message = texte }
    }

    private func lignes(_ options: [CoeurSysteme.Option]) -> some View {
        ForEach(options) { o in
            LigneAction(titre: o.titre, sousTitre: o.sousTitre, icone: o.icone, actif: o.actif) {
                faire(o.action)
            }
        }
    }

    // MARK: Liaison

    private func sectionLiaison(_ l: CoeurLiaison, _ j: Joueur) -> some View {
        let annees = max(0, j.age - l.depuisAge)
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(l.genre == .femme ? "💋" : "🌹")
                        .font(.system(size: 24))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.purple.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.nomComplet).font(.headline)
                        Text("\(l.genre == .femme ? "Maîtresse" : "Amant") · \(l.age) ans · \(l.lieuTexte)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(annees == 0 ? "Depuis cette année" : "Depuis \(annees) an\(annees > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                BarreStat(titre: "Attachement", icone: "heart.fill", valeur: l.intensite)
                if !j.coeurEtat.relationLibre {
                    BarreStat(titre: "Soupçons", icone: "eye.fill", valeur: l.soupcon)
                }
                if l.ultimatum {
                    Label("\(l.prenom) veut que tu choisisses.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
            lignes(CoeurSysteme.optionsLiaison(j))
        } header: {
            Text("Liaison secrète")
        } footer: {
            Text("Plus les soupçons montent, plus ton couple risque de tout découvrir.")
        }
    }

    // MARK: Couple

    private func sectionCouple(_ j: Joueur, _ c: CoeurEtat) -> some View {
        Section {
            if !etiquettes(c).isEmpty {
                Text(etiquettes(c).joined(separator: " · "))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            if c.soupconJoueur >= 30 {
                BarreStat(titre: "Tes doutes", icone: "questionmark.circle.fill", valeur: c.soupconJoueur)
            }
            lignes(CoeurSysteme.optionsCouple(j))
        } header: {
            Text("Ton couple")
        }
    }

    private func etiquettes(_ c: CoeurEtat) -> [String] {
        var e: [String] = []
        if c.trahi { e.append("Trahison découverte") }
        if c.crise > 0 { e.append("En crise") }
        if c.therapie > 0 { e.append("Thérapie en cours") }
        if c.relationLibre { e.append("Relation libre") }
        return e
    }

    // MARK: Enfants cachés

    private func sectionEnfants(_ j: Joueur, _ c: CoeurEtat) -> some View {
        Section {
            ForEach(c.enfantsCaches.filter { !$0.reconnu }) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(e.prenom), \(e.age(j.age)) an\(e.age(j.age) > 1 ? "s" : "")").font(.headline)
                    Text("Avec \(e.autreParent)\(e.pension ? " · pension versée" : "")\(e.revele ? " · ton couple est au courant" : " · secret")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                lignes(CoeurSysteme.optionsEnfant(e, j))
            }
        } header: {
            Text("Enfants hors couple")
        }
    }
}

// MARK: - Actions avec un proche qui ouvrent une carte (fiche d'un proche)

struct CoeurActionsProcheSection: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.presentoir) private var presentoir
    let relationId: UUID
    @State private var carte: CoeurCartePrete?
    @State private var message: String?

    var body: some View {
        Group {
            if let j = engine.joueur, let r = j.relations.first(where: { $0.id == relationId }) {
                let actions = CoeurActionProche.pour(r, j)
                if !actions.isEmpty {
                    Section("Moments ensemble") {
                        ForEach(actions) { a in
                            LigneAction(titre: a.titre,
                                        sousTitre: CoeurActionsSysteme.dejaFait(a, r.id, j) ? "déjà fait cette année" : nil,
                                        icone: a.icone,
                                        actif: !CoeurActionsSysteme.dejaFait(a, r.id, j)) {
                                lancer(a)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $carte) { c in
            CoeurCarteView(carte: c)
                .environmentObject(engine)
                .interactiveDismissDisabled()
                .presentationDetents([.medium, .large])
        }
        .vieAlerte($message)
    }

    private func lancer(_ a: CoeurActionProche) {
        var resultat: (texte: String, carte: CoeurCartePrete?) = ("", nil)
        engine.modifier { j in
            resultat = CoeurActionsSysteme.faire(a, sur: relationId, &j, engine: engine)
        }
        // La carte et le message passent par la racine de l'écran : posés ici, dans la liste,
        // ils seraient refermés aussitôt par le rafraîchissement de la liste.
        if let c = resultat.carte {
            if let p = presentoir { p.ouvrir(CoeurCarteView(carte: c)) } else { carte = c }
        } else if !resultat.texte.isEmpty {
            if let p = presentoir { p.montrer(resultat.texte) } else { message = resultat.texte }
        }
    }
}

/// Carte de choix qui suit une action (même allure qu'un événement).
struct CoeurCarteView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let carte: CoeurCartePrete
    @State private var resultat: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(carte.intro)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(carte.texte)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let r = resultat {
                        Text(r)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.carte))
                        Button("Continuer") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        ForEach(Array(choixVisibles.enumerated()), id: \.offset) { _, paire in
                            Button {
                                resultat = engine.resoudreCarteCoeur(carte, choix: paire.0)
                            } label: {
                                Text(engine.joueur.map { engine.remplir(paire.1.label, $0) } ?? paire.1.label)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(22)
            }
            .navigationTitle("Et maintenant ?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Les choix avec leur index d'origine ; les choix à compétence n'apparaissent qu'avec le niveau.
    private var choixVisibles: [(Int, Choix)] {
        let tous = Array((carte.evenement.choices ?? []).enumerated()).map { ($0.offset, $0.element) }
        guard let j = engine.joueur else { return tous }
        return tous.filter { Competences.aLeNiveau($0.1.requiresSkill, j) }
    }
}

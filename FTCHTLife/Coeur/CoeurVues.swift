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

// MARK: - Ligne d'action « grand format » (icône, titre en gras, sous-titre)

/// Ligne d'action dans le style des menus du jeu : grosse icône, titre gras, petite phrase, « ••• » à droite.
struct CoeurLigneVie: View {
    static let bleu = Color(red: 0.05, green: 0.31, blue: 0.60)

    let emoji: String
    let titre: String
    var sousTitre: String? = nil
    var actif: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 34))
                    .frame(width: 46)
                    .opacity(actif ? 1 : 0.4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(titre)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(actif ? Self.bleu : .gray)
                        .lineLimit(2)
                    if let s = sousTitre, !s.isEmpty {
                        Text(s)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(actif ? Self.bleu.opacity(0.85) : .gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(actif ? Self.bleu : .gray.opacity(0.5))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!actif)
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
                            let fait = CoeurActionsSysteme.dejaFait(a, r.id, j)
                            CoeurLigneVie(emoji: a.emoji, titre: a.titre,
                                          sousTitre: fait ? "Déjà fait cette année" : a.sousTitre(r, j),
                                          actif: !fait) {
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

// MARK: - Fiche du/de la partenaire : toutes les actions de couple au même endroit

/// Une action de la fiche du/de la partenaire, quel que soit le module qui la fait.
enum CoeurActionCouple: Identifiable, Hashable {
    case carte(CoeurActionProche)
    case vie(VieRelations.Action)
    case moteur(GameEngine.ActionRelation)

    var id: String {
        switch self {
        case .carte(let a): return "c_" + a.rawValue
        case .vie(let a): return "v_" + a.rawValue
        case .moteur(let a): return "m_" + a.rawValue
        }
    }
}

struct CoeurCoupleActions: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.presentoir) private var presentoir
    let relationId: UUID
    @State private var carte: CoeurCartePrete?
    @State private var message: String?

    var body: some View {
        Group {
            if let j = engine.joueur, let r = j.relations.first(where: { $0.id == relationId }), r.type == .partenaire {
                Section("Votre couple") {
                    infos(j)
                }
                ForEach(groupes(r, j)) { g in
                    Section(g.titre) {
                        ForEach(g.actions) { a in ligne(a, r, j) }
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

    @ViewBuilder
    private func infos(_ j: Joueur) -> some View {
        let n = j.vieEtat.anneesEnsemble
        HStack { Text("Statut"); Spacer(); Text(j.statutCoupleTexte).foregroundStyle(.secondary) }
        HStack { Text("Ensemble depuis"); Spacer(); Text(n == 0 ? "moins d'un an" : "\(n) an\(n > 1 ? "s" : "")").foregroundStyle(.secondary) }
        if CoeurSysteme.tags(j).contains("contraception_possible") {
            HStack {
                Text("Contraception"); Spacer()
                Text(CoeurSysteme.contraceptionActive(j).map { CoeurSysteme.nomContraception($0).capitalisePremiere } ?? "Aucune")
                    .foregroundStyle(.secondary)
            }
        }
        if j.coeurEtat.therapie > 0 {
            HStack { Text("Thérapie de couple"); Spacer(); Text("encore \(j.coeurEtat.therapie) an\(j.coeurEtat.therapie > 1 ? "s" : "")").foregroundStyle(.secondary) }
        }
    }

    struct Groupe: Identifiable {
        let titre: String
        let actions: [CoeurActionCouple]
        var id: String { titre }
    }

    /// Les actions rangées en trois groupes, dans l'ordre où on les cherche.
    private func groupes(_ r: Relation, _ j: Joueur) -> [Groupe] {
        let cartes = Set(CoeurActionProche.pour(r, j))
        let vie = Set(VieRelations.actions(r, j))
        let moteur = Set(engine.actionsPossibles(r))
        func c(_ a: CoeurActionProche) -> CoeurActionCouple? { cartes.contains(a) ? .carte(a) : nil }
        func v(_ a: VieRelations.Action) -> CoeurActionCouple? { vie.contains(a) ? .vie(a) : nil }
        func m(_ a: GameEngine.ActionRelation) -> CoeurActionCouple? { moteur.contains(a) ? .moteur(a) : nil }

        let ensemble: [CoeurActionCouple?] = [c(.conversation), m(.temps), v(.complimenter), c(.nuit), v(.rendezVous),
                                              v(.voyageAmoureux), m(.cadeau), c(.surprise), c(.anniversaire)]
        let serieux: [CoeurActionCouple?] = [c(.avenir), c(.contraception), v(.bebe), v(.presenterParents),
                                             v(.demanderEnMariage), v(.seMarier), c(.therapie), c(.vendre)]
        let gate: [CoeurActionCouple?] = [v(.disputer), c(.insulter), c(.rompre), v(.divorcer)]
        return [Groupe(titre: "Ensemble", actions: ensemble.compactMap { $0 }),
                Groupe(titre: "Les sujets sérieux", actions: serieux.compactMap { $0 }),
                Groupe(titre: "Quand ça se gâte", actions: gate.compactMap { $0 })].filter { !$0.actions.isEmpty }
    }

    @ViewBuilder
    private func ligne(_ a: CoeurActionCouple, _ r: Relation, _ j: Joueur) -> some View {
        switch a {
        case .carte(let x):
            let fait = CoeurActionsSysteme.dejaFait(x, r.id, j)
            CoeurLigneVie(emoji: x.emoji, titre: x.titre, sousTitre: fait ? "Déjà fait cette année" : x.sousTitre(r, j), actif: !fait) {
                lancer(x)
            }
        case .vie(let x):
            let fait = j.actionsAnnee.contains("vie_\(x.rawValue)_\(r.id.uuidString)")
            CoeurLigneVie(emoji: Self.emoji(x), titre: Self.titre(x), sousTitre: fait ? "Déjà fait cette année" : Self.sousTitre(x), actif: !fait) {
                montrer(engine.vieAction { j in VieRelations.agir(x, sur: relationId, &j) })
            }
        case .moteur(let x):
            let fait = j.actionsAnnee.contains("rel_\(x.rawValue)_\(r.id.uuidString)")
            CoeurLigneVie(emoji: x == .temps ? "🛋️" : "🎁",
                          titre: x == .temps ? "Passer du temps ensemble" : "Offrir un cadeau",
                          sousTitre: fait ? "Déjà fait cette année" : (x == .temps ? "Série, balade, canapé" : "100 €, et l'intention compte"),
                          actif: !fait) {
                montrer(engine.agir(x, sur: relationId))
            }
        }
    }

    static func emoji(_ a: VieRelations.Action) -> String {
        switch a {
        case .complimenter: return "😍"
        case .disputer: return "⚡️"
        case .rendezVous: return "🍷"
        case .voyageAmoureux: return "✈️"
        case .demanderEnMariage: return "💍"
        case .seMarier: return "💒"
        case .divorcer: return "📄"
        case .bebe: return "👶"
        case .presenterParents: return "👪"
        case .rompre: return "💔"
        default: return "❤️"
        }
    }

    static func titre(_ a: VieRelations.Action) -> String {
        switch a {
        case .rendezVous: return "Rendez-vous romantique"
        case .voyageAmoureux: return "Week-end en amoureux"
        case .demanderEnMariage: return "Demander en mariage"
        case .seMarier: return "Organiser le mariage"
        default: return a.titre
        }
    }

    static func sousTitre(_ a: VieRelations.Action) -> String {
        switch a {
        case .complimenter: return "Un mot doux, ça ne coûte rien"
        case .disputer: return "Vider son sac"
        case .rendezVous: return "Restaurant en tête-à-tête (150 €)"
        case .voyageAmoureux: return "Deux jours loin de tout (900 €)"
        case .demanderEnMariage: return "Genou à terre, bague à 2 500 €"
        case .seMarier: return "La fête, la robe, le DJ (12 000 €)"
        case .divorcer: return "Avocats, partage, la moitié de tout"
        case .bebe: return "Agrandir la famille"
        case .presenterParents: return "Le grand repas de famille"
        default: return ""
        }
    }

    private func lancer(_ a: CoeurActionProche) {
        var resultat: (texte: String, carte: CoeurCartePrete?) = ("", nil)
        engine.modifier { j in
            resultat = CoeurActionsSysteme.faire(a, sur: relationId, &j, engine: engine)
        }
        if let c = resultat.carte {
            if let p = presentoir { p.ouvrir(CoeurCarteView(carte: c)) } else { carte = c }
        } else {
            montrer(resultat.texte)
        }
    }

    /// Le message passe par la racine de l'écran (une alerte posée dans la liste se refermerait aussitôt).
    private func montrer(_ texte: String) {
        guard !texte.isEmpty else { return }
        if let p = presentoir { p.montrer(texte) } else { message = texte }
    }
}

private extension String {
    var capitalisePremiere: String { prefix(1).uppercased() + dropFirst() }
}

/// Carte de choix qui suit une action (même allure qu'un événement). Gère les scènes en plusieurs étapes (`then`).
struct CoeurCarteView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let carte: CoeurCartePrete
    @State private var resultat: String?
    /// Étape en cours (nil = la question de la carte).
    @State private var etape: EtapeScene?
    @State private var numero = 0
    /// Étape qui suit le résultat affiché.
    @State private var suite: EtapeScene?
    /// Ce qui s'est déjà passé dans la scène.
    @State private var passe: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(carte.intro)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    ForEach(Array(passe.enumerated()), id: \.offset) { _, t in
                        Text(t)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(question)
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
                        Button(titreBouton) { continuer() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        ForEach(Array(choixVisibles.enumerated()), id: \.offset) { _, paire in
                            Button {
                                let r = engine.resoudreCarteCoeur(carte, etape: etape, numero: numero, choix: paire.0)
                                resultat = r.texte
                                suite = r.suite
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

    private var titreBouton: String { suite == nil ? "Continuer" : "Et ensuite…" }

    private var question: String {
        guard let e = etape else { return carte.texte }
        return engine.joueur.map { engine.remplir(e.text, $0) } ?? e.text
    }

    private func continuer() {
        guard let s = suite else { dismiss(); return }
        passe.append(question + " " + (resultat ?? ""))
        etape = s
        numero += 1
        suite = nil
        resultat = nil
    }

    /// Les choix avec leur index d'origine ; les choix à compétence n'apparaissent qu'avec le niveau.
    private var choixVisibles: [(Int, Choix)] {
        let liste = etape?.choices ?? carte.evenement.choices ?? []
        let tous = Array(liste.enumerated()).map { ($0.offset, $0.element) }
        guard let j = engine.joueur else { return tous }
        return tous.filter { Competences.aLeNiveau($0.1.requiresSkill, j) }
    }
}

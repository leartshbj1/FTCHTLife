import SwiftUI

// Écrans du module amour / crime / santé / générations.
// Le moteur les place où il veut (onglets, feuilles, sections de RelationDetailView, DeathView).

// MARK: - Outils communs

private struct VieAlerte: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

extension View {
    func vieAlerte(_ message: Binding<String?>) -> some View { modifier(VieAlerte(message: message)) }
}

extension GameEngine {
    /// Lance une action du module, écrit son texte dans le journal et renvoie ce texte.
    func vieAction(_ action: (inout Joueur) -> String) -> String {
        var texte = ""
        modifier { j in
            texte = action(&j)
            if !texte.isEmpty { ajouterLigne(&j, texte) }
        }
        return texte
    }

    func vieAction(_ action: (inout Joueur) -> [String]) -> String {
        vieAction { j in action(&j).joined(separator: " ") }
    }
}

// MARK: - Actions en plus sur une relation (à mettre dans RelationDetailView)

struct VieRelationActions: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.presentoir) private var presentoir
    let relationId: UUID
    @State private var message: String?

    var body: some View {
        Group {
            if let j = engine.joueur, let r = j.relations.first(where: { $0.id == relationId }) {
                let actions = VieRelations.actions(r, j)
                if r.type == .partenaire {
                    Section {
                        HStack { Text("Statut"); Spacer(); Text(j.statutCoupleTexte).foregroundStyle(.secondary) }
                        HStack { Text("Ensemble depuis"); Spacer(); Text("\(j.vieEtat.anneesEnsemble) an\(j.vieEtat.anneesEnsemble > 1 ? "s" : "")").foregroundStyle(.secondary) }
                    }
                }
                if !actions.isEmpty {
                    Section("Plus d'actions") {
                        ForEach(actions) { a in
                            LigneAction(titre: a.titre, icone: a.icone) {
                                montrer(engine.vieAction { j in VieRelations.agir(a, sur: relationId, &j) })
                            }
                        }
                    }
                }
            }
        }
        .vieAlerte($message)
    }

    /// Le message passe par la racine de l'écran (une alerte posée dans la liste se refermerait aussitôt).
    private func montrer(_ texte: String) {
        if let p = presentoir { p.montrer(texte) } else { message = texte }
    }
}

// MARK: - Famille élargie, adoption, rencontres (section à ajouter dans RelationsView)

struct VieFamilleSection: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.presentoir) private var presentoir
    @State private var message: String?

    var body: some View {
        Group {
            if let j = engine.joueur {
                let v = j.vieEtat
                let proches = v.proches.filter { $0.vivant && $0.role != .codetenu }
                if !proches.isEmpty {
                    Section("Famille élargie") {
                        ForEach(proches) { p in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(p.nomComplet).font(.headline)
                                    Spacer()
                                    Text("\(p.role.libelle(p.genre)) · \(p.age) ans").font(.caption).foregroundStyle(.secondary)
                                }
                                BarreStat(titre: "Relation", icone: "heart.fill", valeur: p.lien)
                            }
                        }
                    }
                }
                if let mois = v.grossesse {
                    Section { Label("Bébé en route (encore \(min(9, mois)) mois)", systemImage: "figure.and.child.holdinghands") }
                }
                Section("Amour et famille") {
                    // Le lien reste là même une fois en couple : s'il disparaissait au moment où
                    // « Tenter ma chance » réussit, l'écran des rencontres se refermerait sous le doigt.
                    if j.age >= 14 && !v.justice.enPrison {
                        NavigationLink { VieRencontresView() } label: { Label("Faire des rencontres", systemImage: "heart.circle.fill") }
                    }
                    if j.age >= 21 {
                        LigneAction(titre: "Adopter un enfant", sousTitre: "15 000 € de frais", icone: "house.and.flag.fill", actif: !v.justice.enPrison) {
                            montrer(engine.vieAction { j in VieRelations.adopter(&j) })
                        }
                    }
                    if v.mariages > 0 || v.divorces > 0 {
                        Text("Mariages : \(v.mariages) · Divorces : \(v.divorces)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .vieAlerte($message)
    }

    /// Le message passe par la racine de l'écran (une alerte posée dans la liste se refermerait aussitôt).
    private func montrer(_ texte: String) {
        if let p = presentoir { p.montrer(texte) } else { message = texte }
    }
}

struct VieRencontresView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var profils: [VieRelations.Profil] = []
    @State private var genre: Genre?
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Picker("Je cherche", selection: $genre) {
                    Text("Au feeling").tag(Genre?.none)
                    Text("Des hommes").tag(Genre?.some(.homme))
                    Text("Des femmes").tag(Genre?.some(.femme))
                }
                .onChange(of: genre) { _ in recharger() }
            }
            Section("Profils près de chez toi") {
                ForEach(profils) { p in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(p.prenom), \(p.age) ans").font(.headline)
                            Spacer()
                            Text(p.metier).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("« \(p.bio) »").font(.subheadline).italic()
                        BarreStat(titre: "Apparence", icone: "sparkles", valeur: p.apparence)
                        Button("Tenter ma chance") {
                            message = engine.vieAction { j in VieRelations.tenter(p, &j) }
                            profils.removeAll { $0.id == p.id }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                    }
                    .padding(.vertical, 4)
                }
                Button("Voir d'autres profils") { recharger() }
            }
        }
        .navigationTitle("Rencontres")
        .onAppear { if profils.isEmpty { recharger() } }
        .vieAlerte($message)
    }

    private func recharger() {
        guard let j = engine.joueur else { return }
        profils = VieRelations.profils(j, genre: genre)
    }
}

// MARK: - Crime

struct VieCrimeView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                let justice = j.vieEtat.justice
                if j.age >= 13 {
                    Section {
                        NavigationLink { VieMilieuView() } label: {
                            Label(VieMilieu.etat(j).membre ? "Le Milieu : \(VieMilieu.organisation(j)?.nom ?? "")" : "Le Milieu (gangs, mafias, trafic)",
                                  systemImage: "person.3.sequence.fill")
                        }
                    }
                }
                if justice.enPrison {
                    Section { NavigationLink { ViePrisonView() } label: { Label("Tu es en prison", systemImage: "lock.fill") } }
                } else if let p = justice.proces {
                    Section("Procès : \(p.crimeNom)") {
                        Text("Tu risques jusqu'à \(VieCrime.dureeTexte(max(1, p.moisMax))) de prison. Choisis ta défense.")
                            .font(.subheadline)
                        ForEach(VieCrime.Avocat.allCases) { a in
                            LigneAction(titre: a.titre, sousTitre: a.detail, icone: "building.columns.fill", actif: j.argent >= a.prix || a.prix == 0) {
                                message = engine.vieAction { j in VieCrime.juger(a, &j) }
                            }
                        }
                    }
                } else {
                    Section("Crimes") {
                        ForEach(VieCrime.disponibles(j)) { c in
                            LigneAction(titre: c.name, sousTitre: risque(c), icone: c.icon ?? "theatermasks.fill") {
                                message = engine.vieAction { j in VieCrime.commettre(c, &j) }
                            }
                        }
                        if VieCrime.disponibles(j).isEmpty {
                            Text("Tu es trop jeune pour une carrière criminelle. Reviens après le goûter.").foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Casier judiciaire") {
                    if justice.casier.isEmpty {
                        Text("Vierge. Pour l'instant.").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(justice.casier.enumerated()), id: \.offset) { _, l in
                            HStack {
                                Text(l.crime)
                                Spacer()
                                Text("\(l.age) ans · \(l.mois > 0 ? VieCrime.dureeTexte(l.mois) : "amende")").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    HStack { Text("Crimes commis"); Spacer(); Text("\(justice.crimes)").foregroundStyle(.secondary) }
                    HStack { Text("Réputation dans le milieu"); Spacer(); Text("\(justice.notoriete)/100").foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle("Crime")
        .vieAlerte($message)
    }

    private func risque(_ c: CrimeDefinition) -> String {
        let niveau = c.difficulty < 0.3 ? "Facile" : (c.difficulty < 0.6 ? "Risqué" : "Très risqué")
        return "\(niveau) · \(Format.argent(c.lootMin)) à \(Format.argent(c.lootMax))"
    }
}

struct ViePrisonView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                let justice = j.vieEtat.justice
                if justice.enPrison {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(justice.prison ?? "Prison").font(.headline)
                            Text("Encore \(VieCrime.dureeTexte(justice.moisRestants)) à tirer.").foregroundStyle(.secondary)
                            BarreStat(titre: "Conduite", icone: "hand.thumbsup.fill", valeur: justice.comportement)
                        }
                        if let c = j.vieEtat.codetenus.first {
                            HStack { Text(c.role.libelle(c.genre)); Spacer(); Text("\(c.prenom), \(c.age) ans").foregroundStyle(.secondary) }
                        }
                    }
                    Section("Que faire ?") {
                        ForEach(VieDonnees.activitesPrison) { a in
                            LigneAction(titre: a.name, icone: a.icon ?? "figure.walk", actif: !justice.actionsPrisonAnnee.contains(a.id)) {
                                message = engine.vieAction { j in VieCrime.faire(a, &j) }
                            }
                        }
                    }
                } else {
                    Text("Tu es libre. Profite, et évite les supérettes.")
                }
            }
        }
        .navigationTitle("Prison")
        .vieAlerte($message)
    }
}

// MARK: - Santé

struct VieSanteView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                let s = j.vieEtat.sante
                Section {
                    BarreStat(titre: "Santé", icone: "heart.fill", valeur: j.stats.sante)
                    LigneAction(titre: "Bilan de santé", sousTitre: j.age < 18 ? "Payé par tes parents" : "80 €", icone: "stethoscope") {
                        message = engine.vieAction { j in VieSanteSysteme.bilan(&j) }
                    }
                }
                if s.maladies.isEmpty {
                    Section("Maladies") { Text("Aucune maladie connue. Touche du bois.").foregroundStyle(.secondary) }
                }
                ForEach(s.maladies) { mal in
                    if let m = VieDonnees.maladie(mal.id) {
                        Section(m.name) {
                            Text(m.description).font(.subheadline)
                            if m.chronic { Text("Maladie chronique : on peut la soulager, pas la guérir.").font(.caption).foregroundStyle(.secondary) }
                            ForEach(VieSanteSysteme.Soin.allCases) { soin in
                                LigneAction(titre: soin.titre, sousTitre: j.age < 18 ? "Payé par tes parents" : Format.argent(VieSanteSysteme.prix(soin, m)),
                                            icone: soin.icone, actif: !mal.traitee) {
                                    message = engine.vieAction { j in VieSanteSysteme.soigner(m.id, avec: soin, &j) }
                                }
                            }
                            if !VieDonnees.alternatives.isEmpty {
                                Menu {
                                    ForEach(VieDonnees.alternatives) { alt in
                                        Button("\(alt.name) (\(Format.argent(alt.cost)))") {
                                            message = engine.vieAction { j in VieSanteSysteme.alternative(alt, pour: m.id, &j) }
                                        }
                                    }
                                } label: {
                                    Label("Médecine alternative", systemImage: "leaf.fill")
                                }
                                .disabled(mal.traitee)
                            }
                        }
                    }
                }
                if !s.addictions.isEmpty {
                    Section("Addictions") {
                        ForEach(s.addictions, id: \.self) { id in
                            if let a = VieDonnees.addiction(id) {
                                LigneAction(titre: "Cure de désintox : \(a.name)", sousTitre: Format.argent(a.rehabCost), icone: "cross.vial.fill") {
                                    message = engine.vieAction { j in VieSanteSysteme.desintox(id, &j) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Santé")
        .vieAlerte($message)
    }
}

// MARK: - Générations (à mettre dans DeathView)

struct VieGenerationSection: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        if let j = engine.joueur, !j.vivant {
            let heritiers = VieGenerations.heritiers(j)
            if !heritiers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Continuer avec un enfant").font(.headline).foregroundStyle(.white)
                    Text("Chaque enfant hérite de \(Format.argent(VieGenerations.partHeritage(j))).")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    ForEach(heritiers) { e in
                        Button {
                            if let nouveau = VieGenerations.continuer(avec: e.id, depuis: j) {
                                engine.joueur = nouveau
                                engine.sauvegarder()
                            }
                        } label: {
                            HStack {
                                Text("\(e.prenom) · \(e.age) an\(e.age > 1 ? "s" : "")")
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .padding(12)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }
        }
    }
}

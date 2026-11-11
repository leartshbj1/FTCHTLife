import SwiftUI

/// Libellé du lien vers « Vie au bahut », avec le nombre de choses à faire.
struct ScolLienLabel: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        let n = engine.scolEtat?.aFaire.count ?? 0
        HStack(spacing: 12) {
            Image(systemName: "backpack.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text("Vie au bahut").foregroundStyle(Theme.encre)
            Spacer()
            if n > 0 {
                Text("\(n)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent))
            }
        }
    }
}

/// Écran principal du module : réputation, choses à faire, groupe, élection, actions, bulletins.
struct ScolVieView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String? = nil
    @State private var tache: ScolTache? = nil
    @State private var bulletin: ScolBulletin? = nil
    @State private var election = false

    var body: some View {
        List {
            if let j = engine.joueur {
                let etat = ScolStockage.lire(j)
                if ScolRegles.scolarise(j) {
                    reputation(j, etat)
                    aFaire(etat)
                    groupe(j, etat)
                    delegue(j, etat)
                    actions(j)
                } else {
                    Section {
                        Text(j.age < 11 ? "Le collège, c'est à 11 ans. Profite de la cour de récré tant qu'il y a des toboggans."
                                        : "Tu n'es plus au collège ni au lycée. Tes souvenirs, eux, sont toujours là.")
                    }
                }
                souvenirs(etat)
            }
        }
        .navigationTitle("Vie au bahut")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $tache) { t in
            ScolTacheView(tache: t).environmentObject(engine)
        }
        .sheet(item: $bulletin) { b in
            NavigationStack { ScolBulletinView(bulletin: b) }
        }
        .sheet(isPresented: $election) {
            ScolElectionView().environmentObject(engine)
        }
        .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func reputation(_ j: Joueur, _ etat: ScolEtat) -> some View {
        Section("Ta réputation en \(ScolRegles.classe(j.age, etat))") {
            BarreStat(titre: "Popularité", icone: "star.fill", valeur: etat.popularite)
            BarreStat(titre: "Profs", icone: "person.crop.rectangle.fill", valeur: etat.faveurProfs)
            HStack {
                Text("Groupe")
                Spacer()
                Text(ScolDonnees.groupe(etat.groupe)?.nom ?? "Aucun").foregroundStyle(.secondary)
            }
            if etat.estDelegue {
                HStack {
                    Text(j.g("Délégué", "Déléguée") + " de classe")
                    Spacer()
                    Image(systemName: "rosette").foregroundStyle(Theme.accent)
                }
            }
            HStack {
                Text("Colles cette année")
                Spacer()
                Text("\(etat.collesAnnee)\(etat.collesAnnee >= 2 ? " ⚠️" : "")").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func aFaire(_ etat: ScolEtat) -> some View {
        if !etat.aFaire.isEmpty {
            Section("À faire cette année") {
                ForEach(etat.aFaire) { t in
                    let l = engine.scolTitre(t)
                    LigneAction(titre: l.titre, sousTitre: l.sousTitre, icone: l.icone) { tache = t }
                }
            }
        }
    }

    @ViewBuilder
    private func groupe(_ j: Joueur, _ etat: ScolEtat) -> some View {
        Section {
            if let g = ScolDonnees.groupe(etat.groupe) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(g.nom, systemImage: g.icone).font(.headline)
                    Text(g.description).font(.caption).foregroundStyle(.secondary)
                    Text("Depuis \(etat.anneesDansGroupe) an\(etat.anneesDansGroupe > 1 ? "s" : "")").font(.caption2).foregroundStyle(.tertiary)
                }
                LigneAction(titre: "Quitter le groupe", icone: "rectangle.portrait.and.arrow.right") {
                    message = engine.scolQuitterGroupe()
                }
            }
            let dejaTente = j.actionsAnnee.contains("scol_rejoindre")
            ForEach(ScolDonnees.groupes.filter { $0.id != etat.groupe }) { g in
                LigneAction(titre: g.nom,
                            sousTitre: g.description + (g.requis.map { " · conseillé : \(ScolRegles.nomStat($0.stat)) \($0.min)+" } ?? ""),
                            icone: g.icone,
                            actif: !dejaTente) {
                    message = engine.scolRejoindre(g)
                }
            }
        } header: {
            Text(etat.groupe == nil ? "Rejoindre un groupe" : "Ton groupe")
        } footer: {
            Text("Une tentative par an. Chaque groupe a ses avantages, ses défauts et ses actions spéciales.")
        }
    }

    @ViewBuilder
    private func delegue(_ j: Joueur, _ etat: ScolEtat) -> some View {
        Section("Élection de délégué·e") {
            if etat.estDelegue {
                Text("Tu représentes la classe au conseil. Promesse : " + (ScolDonnees.promesse(etat.promesse)?.text ?? "aucune, et c'est très bien comme ça") + ".")
                    .font(.callout)
            } else if engine.scolPeutSePresenter(j) {
                LigneAction(titre: "Se présenter", sousTitre: "Discours, promesses, vote à main levée.", icone: "megaphone.fill") {
                    election = true
                }
            } else {
                Text("L'élection est passée. Rendez-vous à la rentrée prochaine.").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func actions(_ j: Joueur) -> some View {
        let liste = engine.scolActions(j)
        if !liste.isEmpty {
            Section("Au bahut") {
                ForEach(liste) { a in
                    LigneAction(titre: a.titre, sousTitre: a.description, icone: a.icone, actif: !engine.scolActionFaite(a)) {
                        message = engine.scolFaireAction(a)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func souvenirs(_ etat: ScolEtat) -> some View {
        if !etat.bulletins.isEmpty || etat.brevet != nil || etat.noteOralFrancais != nil {
            Section("Bulletins et souvenirs") {
                ForEach(Array(etat.bulletins.reversed())) { b in
                    Button { bulletin = b } label: {
                        HStack {
                            Text(b.classe).foregroundStyle(Theme.encre)
                            Spacer()
                            Text("\(ScolRegles.formatNote(b.moyenne))/20 · \(b.mention.titre)")
                                .font(.caption)
                                .foregroundStyle(b.mention.estAvertissement ? .red : .secondary)
                        }
                    }
                }
                if let b = etat.brevet {
                    HStack { Text("Brevet"); Spacer(); Text(b ? "Obtenu" : "Raté").foregroundStyle(.secondary) }
                }
                if let n = etat.noteOralFrancais {
                    HStack { Text("Oral de français"); Spacer(); Text("\(ScolRegles.formatNote(n))/20").foregroundStyle(.secondary) }
                }
                if let n = etat.noteGrandOral {
                    HStack { Text("Grand oral"); Spacer(); Text("\(ScolRegles.formatNote(n))/20").foregroundStyle(.secondary) }
                }
                if !etat.voyages.isEmpty {
                    HStack {
                        Text("Voyages")
                        Spacer()
                        Text(etat.voyages.compactMap { ScolDonnees.voyage($0)?.destination }.joined(separator: ", ")).foregroundStyle(.secondary)
                    }
                }
                if etat.mandats > 0 || etat.collesTotal > 0 {
                    HStack {
                        Text("Palmarès")
                        Spacer()
                        Text("\(etat.mandats) mandat\(etat.mandats > 1 ? "s" : "") · \(etat.collesTotal) colle\(etat.collesTotal > 1 ? "s" : "")")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Présentation automatique

extension View {
    /// Ouvre tout seul les choses à faire du module après « +1 an » (à mettre sur la vue principale).
    func scolPresentationAuto() -> some View {
        modifier(ScolPresentationAuto())
    }
}

struct ScolPresentationAuto: ViewModifier {
    @EnvironmentObject var engine: GameEngine
    @State private var tache: ScolTache? = nil
    @State private var proposees: Set<String> = []

    func body(content: Content) -> some View {
        content
            .background(
                Color.clear.sheet(item: $tache) { t in
                    ScolTacheView(tache: t).environmentObject(engine)
                }
            )
            .onChange(of: engine.joueur?.age) { _ in proposer() }
            .onChange(of: engine.evenementEnCours == nil) { _ in proposer() }
    }

    private func proposer() {
        guard tache == nil, engine.evenementEnCours == nil, let j = engine.joueur, j.vivant else { return }
        let etat = ScolStockage.lire(j)
        if let t = etat.aFaire.first(where: { !proposees.contains("\(j.age)-\($0.id)") }) {
            proposees.insert("\(j.age)-\(t.id)")
            // Laisse la feuille de l'événement se fermer avant d'ouvrir la suivante.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if engine.evenementEnCours == nil { tache = t }
            }
        }
    }
}

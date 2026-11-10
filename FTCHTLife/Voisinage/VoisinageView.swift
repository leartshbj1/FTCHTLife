import SwiftUI

/// Écran « Voisins » : le quartier, les voisins, et ce qu'on peut leur faire.
struct VoisinageView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    @State private var choisirLogement = false

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur, let etat = engine.voisinage {
                    sectionQuartier(j, etat)
                    sectionVoisins(etat)
                    sectionActions(j, etat)
                    if !etat.anciens.isEmpty { sectionAnciens(etat) }
                } else if let j = engine.joueur, j.vivant {
                    Section {
                        Text("Tu ne connais pas encore tes voisins. Ils te connaissent déjà, eux.")
                        Button("Aller voir dans l'escalier") {
                            engine.modifier { j in _ = engine.voisinageEtat(&j) }
                        }
                    }
                }
            }
            .navigationTitle("Voisins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
            .confirmationDialog("Où veux-tu habiter ? (location)", isPresented: $choisirLogement, titleVisibility: .visible) {
                ForEach(GameEngine.voisinageLoyers) { offre in
                    Button("\(offre.description) · \(Format.argent(offre.loyer))/an") {
                        message = engine.voisinageDemenagerEnLocation(offre.logement)
                    }
                }
            }
        }
    }

    // MARK: Quartier

    private func sectionQuartier(_ j: Joueur, _ e: VoisinageEtat) -> some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: e.logement.icone)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.quartier).font(.headline)
                    Text(e.adresse).font(.caption).foregroundStyle(.secondary)
                    Text(sousTitre(e)).font(.caption).foregroundStyle(.secondary)
                }
            }
            BarreStat(titre: "Ambiance", icone: "sun.max.fill", valeur: e.ambiance)
            if let c = e.copro {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Syndic : \(c.nomSyndic)", systemImage: "building.columns")
                    if e.proprietaire && !e.chezParents {
                        Label("Charges : \(Format.argent(c.chargesAnnuelles)) par an", systemImage: "eurosign.circle")
                    }
                    if c.president {
                        Label(j.g("Président", "Présidente") + " du conseil syndical", systemImage: "crown.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    if !c.travauxVotes.isEmpty {
                        Text("Travaux votés : " + c.travauxVotes.suffix(4).joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
        }
    }

    private func sousTitre(_ e: VoisinageEtat) -> String {
        var s = e.logement.nom
        if e.chezParents { s += " · chez tes parents" }
        else if e.loyerAnnuel != nil { s += " · locataire (\(Format.argent(e.loyerAnnuel ?? 0))/an)" }
        else { s += e.proprietaire ? " · propriétaire" : " · locataire" }
        s += " · \(e.anneesIci) an" + (e.anneesIci > 1 ? "s" : "") + " ici"
        return s
    }

    // MARK: Voisins

    private func sectionVoisins(_ e: VoisinageEtat) -> some View {
        Section("Tes voisins") {
            if e.voisinsPresents.isEmpty {
                Text("Personne autour. Le silence est assourdissant.").foregroundStyle(.secondary)
            }
            ForEach(e.voisinsPresents) { v in
                NavigationLink {
                    VoisinDetailView(voisinId: v.id, message: $message)
                        .environmentObject(engine)
                } label: {
                    VoisinLigne(voisin: v)
                }
            }
        }
    }

    // MARK: Actions de quartier

    private func sectionActions(_ j: Joueur, _ e: VoisinageEtat) -> some View {
        Section("Le quartier") {
            ForEach(engine.voisinageInteractions(voisin: nil), id: \.id) { item in
                let i = item.interaction
                LigneAction(titre: i.titre,
                            sousTitre: i.description + ((i.cout ?? 0) > 0 && j.age >= 18 ? " · \(Format.argent(i.cout ?? 0))" : ""),
                            icone: i.icone,
                            actif: item.dispo) {
                    message = engine.voisinageFaire(i, voisinId: nil)
                }
            }
            if j.vivant && j.age >= 18 && (e.chezParents || e.loyerAnnuel != nil) {
                LigneAction(titre: e.chezParents ? "Quitter le nid" : "Déménager",
                            sousTitre: "Louer un nouveau logement, avec de nouveaux voisins à découvrir.",
                            icone: "shippingbox.fill") {
                    choisirLogement = true
                }
            }
        }
    }

    // MARK: Anciens voisins

    private func sectionAnciens(_ e: VoisinageEtat) -> some View {
        Section {
            DisclosureGroup("Anciens voisins (\(e.anciens.count))") {
                ForEach(Array(e.anciens.reversed())) { v in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.nomComplet).font(.subheadline)
                        Text(VoisinageMoteur.titre(v).voisinageMaj + (v.parti ? " · a déménagé" : " · †"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Ligne d'un voisin

struct VoisinLigne: View {
    let voisin: Voisin

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(voisinageCouleur(voisin.statut).opacity(0.15))
                Text(String(voisin.prenom.prefix(1)))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(voisinageCouleur(voisin.statut))
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(voisin.nomComplet).foregroundStyle(Theme.encre)
                    if voisin.statut != .neutre {
                        Text(voisin.statut.libelle)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(voisinageCouleur(voisin.statut).opacity(0.15)))
                            .foregroundStyle(voisinageCouleur(voisin.statut))
                    }
                }
                Text(VoisinageMoteur.titre(voisin).voisinageMaj + " · \(voisin.age) ans · \(voisin.emplacement)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.08))
                        Capsule().fill(Theme.couleurStat(voisin.lien))
                            .frame(width: geo.size.width * CGFloat(voisin.lien) / 100)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.vertical, 2)
    }
}

func voisinageCouleur(_ s: VoisinStatut) -> Color {
    switch s {
    case .neutre: return Theme.accent
    case .ami: return Color(red: 0.16, green: 0.6, blue: 0.38)
    case .ennemi: return Color(red: 0.85, green: 0.2, blue: 0.2)
    case .amour: return Color(red: 0.9, green: 0.3, blue: 0.55)
    }
}

// MARK: - Fiche d'un voisin

struct VoisinDetailView: View {
    @EnvironmentObject var engine: GameEngine
    let voisinId: UUID
    @Binding var message: String?

    var body: some View {
        List {
            if let v = engine.voisinage?.voisins.first(where: { $0.id == voisinId }), v.vivant {
                Section {
                    VoisinLigne(voisin: v)
                    if let a = VoisinageDonnees.archetype(v.archetype) {
                        Text(a.description).font(.callout).foregroundStyle(.secondary)
                    }
                    Text("Habite \(v.emplacement) depuis \(v.anneesDansLeQuartier) an\(v.anneesDansLeQuartier > 1 ? "s" : "").")
                        .font(.caption)
                    BarreStat(titre: "Relation", icone: "heart.fill", valeur: v.lien)
                }
                if !v.souvenirs.isEmpty {
                    Section(v.genre == .femme ? "Ce qu'elle retient de toi" : "Ce qu'il retient de toi") {
                        ForEach(v.souvenirs, id: \.self) { s in
                            Text("• " + s.replacingOccurrences(of: "_", with: " ").voisinageMaj)
                                .font(.callout)
                        }
                    }
                }
                Section("Que faire ?") {
                    let actions = engine.voisinageInteractions(voisin: v)
                    if actions.isEmpty {
                        Text("Rien à faire avec {voisin} pour l'instant.".replacingOccurrences(of: "{voisin}", with: v.prenom))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(actions, id: \.id) { item in
                        let i = item.interaction
                        LigneAction(titre: i.titre,
                                    sousTitre: i.description + ((i.cout ?? 0) > 0 && (engine.joueur?.age ?? 0) >= 18 ? " · \(Format.argent(i.cout ?? 0))" : ""),
                                    icone: i.icone,
                                    actif: item.dispo) {
                            message = engine.voisinageFaire(i, voisinId: v.id)
                        }
                    }
                }
            } else {
                Text("Ce voisin n'habite plus ici.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle(engine.voisinage?.voisins.first(where: { $0.id == voisinId })?.prenom ?? "Voisin")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension String {
    /// Met la première lettre en majuscule (« la retraitée curieuse » → « La retraitée curieuse »).
    var voisinageMaj: String { prefix(1).uppercased() + dropFirst() }
}

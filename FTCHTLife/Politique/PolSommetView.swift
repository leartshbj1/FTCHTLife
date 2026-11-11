import SwiftUI

// Écrans du sommet de l'État : décrets à signer d'un geste, carte des relations internationales.

/// Exécute une action politique sur le joueur courant et renvoie son texte.
private func polAgir(_ engine: GameEngine, _ etat: WritableKeyPath<Joueur, PolEtat?>,
                     _ f: (inout Joueur, inout PolEtat) -> PolResultat) -> String {
    var t = ""
    engine.modifier { j in
        var p = j[keyPath: etat] ?? PolEtat()
        t = f(&j, &p).texte
        j[keyPath: etat] = p
    }
    return t
}

// MARK: - Décrets

struct PolDecretsView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let etat: WritableKeyPath<Joueur, PolEtat?>
    @State private var message: String?
    @State private var domaine = "tous"

    static let domaines: [(String, String)] = [
        ("tous", "Tous"), ("economie", "Économie"), ("social", "Social"), ("securite", "Sécurité"),
        ("ecologie", "Écologie"), ("institutions", "Institutions"), ("international", "International"), ("urgence", "Urgence"),
    ]

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let e = j[keyPath: etat] ?? PolEtat()
                    let restants = PolMoteur.decretsRestants(j)
                    Section {
                        HStack {
                            Text("Signatures restantes cette année")
                            Spacer()
                            Text("\(restants) / \(PolMoteur.decretsParAn)").bold().foregroundStyle(restants > 0 ? Theme.accent : .gray)
                        }
                        HStack { Text("Capital politique (influence)"); Spacer(); Text("\(e.influence)").foregroundStyle(.secondary) }
                        Picker("Domaine", selection: $domaine) {
                            ForEach(Self.domaines.indices, id: \.self) { k in
                                Text(Self.domaines[k].1).tag(Self.domaines[k].0)
                            }
                        }
                    }
                    let liste = PolMoteur.decretsDisponibles(j, e).filter { domaine == "tous" || $0.domaine == domaine }
                    Section("À signer") {
                        if liste.isEmpty { Text("Aucun décret dans ce domaine.").foregroundStyle(.secondary) }
                        ForEach(liste) { d in
                            ligne(d, j, e, actif: restants > 0 && e.influence >= d.cout)
                        }
                    }
                    let actifs = PolMoteur.decretsAbrogeables(j, e)
                    if !actifs.isEmpty {
                        Section("En vigueur") {
                            ForEach(actifs) { d in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(d.titre).bold().foregroundStyle(Theme.encre)
                                        if let a = e.decrets.first(where: { $0.id == d.id }), let r = a.anneesRestantes {
                                            Text("Encore \(r) an\(r > 1 ? "s" : "")").font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            Text("Jusqu'à abrogation").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button("Abroger") {
                                        message = polAgir(engine, etat) { PolMoteur.abrogerDecret(d.id, &$0, &$1) }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .disabled(PolMoteur.dejaFaitCetteAnnee("decret_abroger", j))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Décrets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func ligne(_ d: PolDecret, _ j: Joueur, _ e: PolEtat, actif: Bool) -> some View {
        let risque = Int((PolMoteur.risqueAnnulation(d, j, e) * 100).rounded())
        let duree = d.duree.map { "\($0) an\($0 > 1 ? "s" : "")" } ?? "permanent"
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(d.titre).bold().foregroundStyle(Theme.encre)
                if d.autoritaire == true {
                    Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.orange)
                }
            }
            Text(PolMoteur.remplir(d.description, j, e)).font(.caption).foregroundStyle(.secondary)
            let resume = PolMoteur.resumeEffets(d.effets)
            if !resume.isEmpty { Text(resume).font(.caption2).foregroundStyle(Theme.encre.opacity(0.8)) }
            HStack {
                Text("\(d.cout) d'influence · \(duree)" + (risque > 0 ? " · annulation \(risque) %" : ""))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button("Signer") {
                    message = polAgir(engine, etat) { PolMoteur.signerDecret(d.id, &$0, &$1) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!actif)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Relations internationales

struct PolMondeView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let etat: WritableKeyPath<Joueur, PolEtat?>
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let e = j[keyPath: etat] ?? PolEtat()
                    let diplomate = PolMoteur.peutDiplomatie(j, e)
                    Section {
                        Text(diplomate
                             ? "Visites d'État : 2 par an. Accord, sanctions et aide : 1 de chaque par an."
                             : "Tu représentes le pays : les visites d'État sont possibles, la diplomatie appartient au gouvernement.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    let pays = PolMoteur.autresPays(e).sorted { PolMoteur.relation($0, e) > PolMoteur.relation($1, e) }
                    Section("Pays") {
                        ForEach(pays, id: \.self) { id in
                            ligne(id, j, e, diplomate: diplomate)
                        }
                    }
                }
            }
            .navigationTitle("Relations internationales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func couleur(_ r: Int) -> Color {
        r >= 40 ? .green : (r >= 0 ? Theme.accent : (r >= -40 ? .orange : .red))
    }

    private func etiquette(_ r: Int) -> String {
        switch r {
        case 60...: return "Allié proche"
        case 25..<60: return "Ami"
        case 0..<25: return "Cordial"
        case -40..<0: return "Froid"
        default: return "Hostile"
        }
    }

    private func ligne(_ id: String, _ j: Joueur, _ e: PolEtat, diplomate: Bool) -> some View {
        let r = PolMoteur.relation(id, e)
        let i = e.international
        let traites = i.traites.filter { $0.pays == id }
        let enGuerre = i.conflit == id
        let sanctionne = i.sanctions.contains(id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(PolMoteur.drapeau(id))
                Text(PolMoteur.nomPaysMaj(id)).bold().foregroundStyle(Theme.encre)
                Spacer()
                Text(enGuerre ? "En guerre" : "\(etiquette(r)) (\(r > 0 ? "+" : "")\(r))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(enGuerre ? .red : couleur(r))
            }
            if !traites.isEmpty || sanctionne {
                HStack(spacing: 6) {
                    ForEach(traites) { t in
                        Label(t.type.nom, systemImage: t.type.icone).font(.caption2).foregroundStyle(.secondary)
                    }
                    if sanctionne { Label("Sanctions", systemImage: "nosign").font(.caption2).foregroundStyle(.red) }
                }
            }
            if !enGuerre {
                HStack(spacing: 8) {
                    Button("Visite") {
                        message = polAgir(engine, etat) { PolMoteur.visiteEtat(id, &$0, &$1) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(PolMoteur.dejaFaitCetteAnnee("visite_2", j) || PolMoteur.dejaFaitCetteAnnee("visite_pays_" + id, j))
                    if diplomate {
                        Menu("Accord") {
                            ForEach(PolTraiteType.allCases) { t in
                                let raison = PolMoteur.empechementTraite(t, id, j, e)
                                Button {
                                    message = polAgir(engine, etat) { PolMoteur.proposerTraite(t, id, &$0, &$1) }
                                } label: {
                                    Label(raison == nil ? "\(t.nom) (\(Int(PolMoteur.chanceTraite(id, e) * 100)) %)" : "\(t.nom) : \(raison ?? "")",
                                          systemImage: t.icone)
                                }
                                .disabled(raison != nil)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(PolMoteur.dejaFaitCetteAnnee("traite", j))
                        Menu("Autre") {
                            Button {
                                message = polAgir(engine, etat) { PolMoteur.aideInternationale(id, &$0, &$1) }
                            } label: { Label("Envoyer une aide d'urgence", systemImage: "shippingbox.and.arrow.backward.fill") }
                            .disabled(PolMoteur.dejaFaitCetteAnnee("aide", j))
                            if sanctionne {
                                Button {
                                    message = polAgir(engine, etat) { PolMoteur.leverSanctions(id, &$0, &$1) }
                                } label: { Label("Lever les sanctions", systemImage: "checkmark.circle") }
                                .disabled(PolMoteur.dejaFaitCetteAnnee("lever_sanctions", j))
                            } else {
                                Button(role: .destructive) {
                                    message = polAgir(engine, etat) { PolMoteur.sanctionner(id, &$0, &$1) }
                                } label: { Label("Imposer des sanctions", systemImage: "nosign") }
                                .disabled(PolMoteur.dejaFaitCetteAnnee("sanctions", j))
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 2)
    }
}

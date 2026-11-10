import SwiftUI

/// Écran principal du module : mes boîtes, fonder une entreprise, anciennes boîtes.
/// À ouvrir en sheet : `EntreprisesView().environmentObject(engine)`.
struct EntreprisesView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var creation = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    contenu(j)
                }
            }
            .navigationTitle("Entreprises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .sheet(isPresented: $creation) {
                EntrepriseCreationView { texte in
                    creation = false
                    message = texte
                }
                .environmentObject(engine)
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    @ViewBuilder
    private func contenu(_ j: Joueur) -> some View {
        let etat = j.entreprises ?? EntreprisesEtat()
        if j.age < 18 {
            Section {
                Text("Reviens à 18 ans. En attendant, tu peux toujours vendre de la limonade tiède devant chez toi.")
            }
        }
        if !etat.actives.isEmpty {
            Section("Mes boîtes") {
                ForEach(etat.actives) { e in
                    NavigationLink {
                        EntrepriseDetailView(entrepriseId: e.id)
                    } label: {
                        LigneEntreprise(entreprise: e, niveau: engine.nomDuNiveau(e))
                    }
                }
            }
        }
        if j.age >= 18 && j.vivant {
            Section {
                LigneAction(titre: "Fonder une entreprise",
                            sousTitre: "\(etat.actives.count) sur \(EntrepriseMoteur.maxEntreprises) boîtes possibles",
                            icone: "plus.circle.fill",
                            actif: etat.actives.count < EntrepriseMoteur.maxEntreprises) {
                    creation = true
                }
            } footer: {
                if etat.actives.isEmpty {
                    Text("Food truck, kebab, salon, startup… Tu choisis le nom, tu embauches tes potes, et tu pries.")
                }
            }
        }
        if !etat.archives.isEmpty {
            Section("Anciennes boîtes") {
                ForEach(Array(etat.archives.reversed())) { a in
                    HStack(spacing: 12) {
                        Image(systemName: EntrepriseCatalogue.type(a.typeId)?.icone ?? "building.2")
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.nom)
                            Text(resumeArchive(a)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func resumeArchive(_ a: EntrepriseArchive) -> String {
        let periode = "de \(a.ageDebut) à \(a.ageFin) ans"
        switch a.fin {
        case "vendue": return "Vendue \(Format.argent(a.montant)) · \(periode)"
        case "fermee": return "Fermée · \(periode)"
        default: return "Faillite 💥 · \(periode)"
        }
    }
}

struct LigneEntreprise: View {
    let entreprise: Entreprise
    let niveau: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: EntrepriseCatalogue.type(entreprise.typeId)?.icone ?? "building.2.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entreprise.nom).font(.headline).foregroundStyle(Theme.encre)
                    if entreprise.crise != nil {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                    }
                }
                Text(niveau).font(.caption).foregroundStyle(.secondary)
                Text("Trésorerie \(Format.argent(entreprise.tresorerie))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(entreprise.tresorerie < 0 ? Color.red : Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Crise

/// Section « crise de l'année » avec ses choix. Utilisée dans la fiche de l'entreprise et dans `EntrepriseCriseView`.
struct EntrepriseCriseSection: View {
    @EnvironmentObject var engine: GameEngine
    let entreprise: Entreprise
    let resultat: (String) -> Void

    var body: some View {
        if let c = entreprise.crise, let ev = EntrepriseCatalogue.evenement(c.evenementId) {
            Section {
                Text(c.texte)
                    .font(.body)
                    .padding(.vertical, 4)
                ForEach(Array(ev.choices.enumerated()), id: \.offset) { i, ch in
                    Button {
                        resultat(engine.resoudreCriseEntreprise(entreprise.id, choix: i))
                    } label: {
                        HStack {
                            Text(engine.libelleChoixEntreprise(ch.label, entreprise))
                                .foregroundStyle(Theme.accent)
                                .bold()
                            Spacer()
                            if let cout = ch.cost, cout > 0 {
                                Text(Format.argent(EntrepriseMoteur.aEchelle(cout, entreprise)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(GameEngine.iconeEvenementEntreprise(ev.kind) + " " + titre(ev.kind))
            } footer: {
                Text("Sans décision avant ton prochain anniversaire, la vie décidera pour toi.")
            }
        }
    }

    private func titre(_ kind: String?) -> String {
        switch kind ?? "crise" {
        case "opportunite": return "Opportunité"
        case "equipe": return "Drame d'équipe"
        case "absurde": return "Situation absurde"
        default: return "Crise"
        }
    }
}

/// Carte autonome pour afficher la crise d'une boîte en fin d'année (sheet du moteur).
struct EntrepriseCriseView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let entrepriseId: UUID
    @State private var resultat: String?

    var body: some View {
        NavigationStack {
            List {
                if let r = resultat {
                    Section { Text(r) }
                    Section {
                        Button("Continuer") { dismiss() }.bold()
                    }
                } else if let e = engine.joueur?.entreprises?.actives.first(where: { $0.id == entrepriseId }), e.crise != nil {
                    EntrepriseCriseSection(entreprise: e) { texte in resultat = texte }
                    Section {
                        Button("Décider plus tard") { dismiss() }
                    }
                } else {
                    Section { Button("Fermer") { dismiss() } }
                }
            }
            .navigationTitle(engine.joueur?.entreprises?.actives.first(where: { $0.id == entrepriseId })?.nom ?? "Entreprise")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

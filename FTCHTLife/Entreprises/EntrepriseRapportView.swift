import SwiftUI
import Charts

// Rapport annuel détaillé d'une boîte, et feuille « Bilan de l'année » affichée après chaque anniversaire.

/// Feuille à afficher après le passage d'une année si `engine.entreprisesAvecRapportNonLu` n'est pas vide.
struct EntreprisesBilanAnnuelView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    /// Boîtes à montrer, figées à l'ouverture (le rapport reste visible même après lecture).
    @State private var ids: [UUID] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(entreprises) { e in
                    if let r = e.rapport, let eco = EntrepriseCatalogue.eco(e.typeId) {
                        Section {
                            ResumeRapportEntreprise(entreprise: e, rapport: r, eco: eco)
                            ForEach(r.faits, id: \.self) { f in Text(f).font(.callout) }
                            ForEach(r.conseils, id: \.self) { c in
                                Label(c, systemImage: "lightbulb.fill")
                                    .font(.callout)
                                    .foregroundStyle(Theme.encre)
                            }
                            NavigationLink {
                                EntrepriseRapportView(entrepriseId: e.id)
                            } label: {
                                Label("Rapport complet", systemImage: "chart.bar.doc.horizontal")
                            }
                            NavigationLink {
                                EntrepriseDetailView(entrepriseId: e.id)
                            } label: {
                                Label("Piloter \(e.nom)", systemImage: "slider.horizontal.3")
                                    .bold()
                            }
                        } header: {
                            Text(e.nom)
                        }
                        EntrepriseCriseSection(entreprise: e) { texte in message = texte }
                    }
                }
                if entreprises.isEmpty {
                    Text("Aucun bilan à afficher.")
                }
            }
            .navigationTitle("Bilan de l'année")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continuer") {
                        engine.marquerRapportsEntreprisesLus()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if ids.isEmpty { ids = engine.entreprisesAvecRapportNonLu.map { $0.id } }
            }
            .onDisappear { engine.marquerRapportsEntreprisesLus() }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private var entreprises: [Entreprise] {
        let actives = engine.joueur?.entreprises?.actives ?? []
        if ids.isEmpty { return actives.filter { $0.rapportNonLu && $0.rapport != nil } }
        return actives.filter { ids.contains($0.id) }
    }
}

/// Les grands chiffres de l'année avec l'évolution par rapport à l'année d'avant.
struct ResumeRapportEntreprise: View {
    let entreprise: Entreprise
    let rapport: EntrepriseRapport
    let eco: EntrepriseEco

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                chiffre("Chiffre d'affaires", Format.argent(rapport.chiffreAffaires), evolution(\.chiffreAffaires))
                Spacer()
                chiffre("Résultat", (rapport.resultat >= 0 ? "+" : "") + Format.argent(rapport.resultat), nil,
                        couleur: rapport.resultat >= 0 ? Color.green : Color.red)
            }
            HStack(alignment: .top) {
                chiffre(eco.vente.pluriel.capitalized, "\(rapport.ventes)", nil)
                Spacer()
                chiffre("Part de marché", "\(Int(rapport.partDeMarche * 100)) %", nil)
                Spacer()
                chiffre("Trésorerie", Format.argent(rapport.tresorerie), nil,
                        couleur: rapport.tresorerie < 0 ? Color.red : Theme.encre)
            }
            if rapport.clientsRefuses > 0 {
                Text("\(rapport.clientsRefuses) clients refusés faute de capacité.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func evolution(_ cle: KeyPath<EntrepriseBilan, Int>) -> String? {
        let h = entreprise.historique
        guard h.count >= 2 else { return nil }
        let avant = h[h.count - 2][keyPath: cle]
        let maintenant = h[h.count - 1][keyPath: cle]
        guard avant > 0 else { return nil }
        let pct = Int((Double(maintenant) / Double(avant) - 1) * 100)
        return (pct >= 0 ? "▲ +" : "▼ ") + "\(pct) %"
    }

    private func chiffre(_ titre: String, _ valeur: String, _ evo: String?, couleur: Color = Theme.encre) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titre).font(.caption).foregroundStyle(.secondary)
            Text(valeur).font(.headline.monospacedDigit()).foregroundStyle(couleur)
            if let evo = evo {
                Text(evo).font(.caption2.bold()).foregroundStyle(evo.hasPrefix("▲") ? Color.green : Color.red)
            }
        }
    }
}

/// Rapport complet : graphique sur plusieurs années, ventes, compte de résultat, équipe.
struct EntrepriseRapportView: View {
    @EnvironmentObject var engine: GameEngine
    let entrepriseId: UUID

    private var entreprise: Entreprise? {
        engine.joueur?.entreprises?.actives.first { $0.id == entrepriseId }
    }

    var body: some View {
        List {
            if let e = entreprise, let eco = EntrepriseCatalogue.eco(e.typeId) {
                if e.historique.count >= 2 {
                    Section("Évolution") {
                        GraphiqueEntreprise(historique: e.historique)
                            .frame(height: 200)
                            .padding(.vertical, 6)
                    }
                }
                if let r = e.rapport {
                    sections(r, eco)
                } else {
                    Text("Premier rapport à ton prochain anniversaire.")
                }
            } else {
                Text("Cette boîte n'existe plus.")
            }
        }
        .navigationTitle(titre)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titre: String {
        guard let age = entreprise?.rapport?.age else { return "Rapport" }
        return "Rapport à \(age) ans"
    }

    static func libelleCapacite(_ r: EntrepriseRapport, _ eco: EntrepriseEco) -> String {
        guard r.usines > 0 else { return "Capacité" }
        let unite: String = r.usines > 1 ? (eco.usine?.pluriel ?? "usines") : (eco.usine?.nom ?? "usine")
        return "Capacité (\(r.usines) \(unite))"
    }

    @ViewBuilder
    private func sections(_ r: EntrepriseRapport, _ eco: EntrepriseEco) -> some View {
        Section("Les clients") {
            ligne("Clients potentiels (\(r.sites) \(r.sites > 1 ? eco.site.pluriel : eco.site.nom))", "\(r.marche)")
            ligne("Demande", "\(r.demande)")
            ligne("Part de marché", "\(Int(r.partDeMarche * 100)) %")
            ligne(Self.libelleCapacite(r, eco), "\(r.capacite)")
            ligne(eco.vente.pluriel.capitalized + " réalisé(e)s", "\(r.ventes)")
            ligne("Clients refusés", "\(r.clientsRefuses)", rouge: r.clientsRefuses > 0)
            ligne("Capacité utilisée", "\(Int(r.tauxOccupation * 100)) %")
            ligne("Prix moyen", Format.argent(Int(r.prixVente.rounded())))
        }
        Section("Compte de résultat") {
            ligne("Chiffre d'affaires", Format.argent(r.chiffreAffaires))
            ligne("Achats et matières", "−" + Format.argent(r.achats))
            ligne("Salaires", "−" + Format.argent(r.salaires))
            ligne("Loyers", "−" + Format.argent(r.loyers))
            ligne("Marketing", "−" + Format.argent(r.marketing))
            if r.leviers > 0 { ligne("Leviers du métier", "−" + Format.argent(r.leviers)) }
            if r.banque > 0 { ligne("Banque (prêt et intérêts)", "−" + Format.argent(r.banque)) }
            ligne("Résultat", (r.resultat >= 0 ? "+" : "") + Format.argent(r.resultat), rouge: r.resultat < 0)
                .bold()
            ligne("Trésorerie en fin d'année", Format.argent(r.tresorerie), rouge: r.tresorerie < 0)
        }
        Section("L'équipe") {
            ligne("Employés", "\(r.effectif)")
            BarreStat(titre: "Moral", icone: "face.smiling", valeur: r.moral)
            BarreStat(titre: "Réputation", icone: "star.fill", valeur: r.reputation)
        }
        if !r.faits.isEmpty {
            Section("Faits marquants") {
                ForEach(r.faits, id: \.self) { Text($0) }
            }
        }
        if !r.conseils.isEmpty {
            Section("Conseils du comptable") {
                ForEach(r.conseils, id: \.self) { c in
                    Label(c, systemImage: "lightbulb.fill")
                }
            }
        }
    }

    private func ligne(_ titre: String, _ valeur: String, rouge: Bool = false) -> some View {
        HStack {
            Text(titre)
            Spacer()
            Text(valeur).monospacedDigit().foregroundStyle(rouge ? Color.red : Color.secondary)
        }
    }
}

/// Chiffre d'affaires (barres) et résultat (ligne) au fil des années.
struct GraphiqueEntreprise: View {
    let historique: [EntrepriseBilan]

    var body: some View {
        Chart {
            ForEach(historique, id: \.age) { b in
                BarMark(x: .value("Âge", "\(b.age)"), y: .value("Montant", b.chiffreAffaires))
                    .foregroundStyle(by: .value("Série", "Chiffre d'affaires"))
            }
            ForEach(historique, id: \.age) { b in
                LineMark(x: .value("Âge", "\(b.age)"), y: .value("Montant", b.resultat))
                    .foregroundStyle(by: .value("Série", "Résultat"))
                    .symbol(.circle)
            }
        }
        .chartForegroundStyleScale(["Chiffre d'affaires": Theme.accent.opacity(0.6), "Résultat": Color.green])
        .chartYAxis {
            AxisMarks { valeur in
                AxisGridLine()
                AxisValueLabel {
                    if let v = valeur.as(Int.self) { Text(GraphiqueEntreprise.court(v)) }
                }
            }
        }
    }

    nonisolated static func court(_ v: Int) -> String {
        let a = abs(v)
        let signe = v < 0 ? "−" : ""
        if a >= 1_000_000_000 { return signe + "\(a / 1_000_000_000) Md" }
        if a >= 1_000_000 { return signe + "\(a / 1_000_000) M" }
        if a >= 1_000 { return signe + "\(a / 1_000) k" }
        return signe + "\(a)"
    }
}

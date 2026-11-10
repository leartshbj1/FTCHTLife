import SwiftUI

/// Écran du casier judiciaire : condamnations, effacement (avocat, TIG, piston), métiers fermés, archives.
///
/// Le moteur passe le chemin du champ de sauvegarde, par ex. `CasierView(chemin: \.casier)`,
/// ce qui permet à ce fichier de compiler avant que le champ existe dans `Joueur`.
struct CasierView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let chemin: WritableKeyPath<Joueur, CasierJudiciaire?>

    @State private var cibleId: UUID?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    contenu(j, j[keyPath: chemin] ?? CasierJudiciaire())
                }
            }
            .navigationTitle("Casier judiciaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("Casier judiciaire", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    // MARK: - Actions

    /// Applique une action sur le casier et le joueur, l'écrit dans le journal et affiche le résultat.
    private func agir(_ action: (inout CasierJudiciaire, inout Joueur) -> String) {
        var texte = ""
        let chemin = self.chemin
        engine.modifier { j in
            var c = j[keyPath: chemin] ?? CasierJudiciaire()
            texte = action(&c, &j)
            j[keyPath: chemin] = c
            engine.ajouterLigne(&j, "⚖️ " + texte.replacingOccurrences(of: "\n\n", with: " "))
        }
        message = texte
    }

    private func cibleVisee(_ c: CasierJudiciaire) -> CasierCondamnation? {
        c.condamnations.first { $0.id == cibleId } ?? c.condamnations.max { $0.gravite < $1.gravite }
    }

    private static func pourcent(_ p: Double) -> String { "\(Int((p * 100).rounded())) %" }

    private static func majuscule(_ s: String) -> String {
        guard let premiere = s.first else { return s }
        return String(premiere).uppercased() + String(s.dropFirst())
    }

    private static func couleur(_ g: CasierGravite) -> Color {
        switch g {
        case .crime: return Theme.couleurStat(10)
        case .delit: return Theme.couleurStat(40)
        case .contravention: return Theme.couleurStat(60)
        }
    }

    // MARK: - Contenu

    @ViewBuilder
    private func contenu(_ j: Joueur, _ c: CasierJudiciaire) -> some View {
        Section {
            if c.estVierge {
                Label(c.effacees.isEmpty ? "Casier vierge. Pour l'instant." : "Casier vierge. On repart de zéro.",
                      systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.couleurStat(90))
            } else {
                ForEach(c.condamnations) { cond in
                    Button { cibleId = cond.id } label: { ligneCondamnation(cond, choisie: cond.id == cibleVisee(c)?.id) }
                }
            }
        } header: {
            Text("Condamnations")
        } footer: {
            if !c.estVierge {
                Text(piedCondamnations(c))
            }
        }

        if !c.estVierge, let cible = cibleVisee(c) {
            sectionMetiers(c)
            sectionTIG(j, c, cible)
            sectionAvocats(j, c, cible)
            sectionPistons(j, c, cible)
        } else if let tig = c.tig {
            Section("Travaux d'intérêt général") { progressionTIG(tig) }
        }

        if !c.effacees.isEmpty {
            Section("Archives (effacé)") {
                ForEach(Array(c.effacees.reversed())) { cond in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.majuscule(cond.infraction))
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Text("Effacé à \(cond.ageEffacement ?? j.age) ans grâce à : \(cond.effaceePar ?? "un miracle")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func ligneCondamnation(_ cond: CasierCondamnation, choisie: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: cond.gravite.icone)
                .foregroundStyle(Self.couleur(cond.gravite))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.majuscule(cond.infraction))
                    .foregroundStyle(Theme.encre)
                Text("\(cond.gravite.nom) · à \(cond.age) ans · effacement auto après \(cond.gravite.delaiRehabilitation) ans sans récidive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if choisie {
                Image(systemName: "scope").foregroundStyle(Theme.accent)
            }
        }
    }

    private func piedCondamnations(_ c: CasierJudiciaire) -> String {
        var t = "\(c.anneesSansRecidive) an\(c.anneesSansRecidive > 1 ? "s" : "") sans récidive."
        if let n = c.prochainEffacementDans {
            t += n == 0 ? " Un effacement automatique arrive à ton prochain anniversaire." : " Prochain effacement automatique dans \(n) an\(n > 1 ? "s" : "")."
        }
        if c.condamnations.count > 1 {
            t += " Touche une condamnation pour la viser (avocat, TIG, piston)."
        }
        return t
    }

    @ViewBuilder
    private func sectionMetiers(_ c: CasierJudiciaire) -> some View {
        let fermes = c.graviteMax.map { g in CasierSysteme.metiersFermes.filter { g >= $0.graviteMin } } ?? []
        if !fermes.isEmpty {
            Section {
                ForEach(fermes, id: \.nom) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(r.nom, systemImage: "lock.fill")
                        Text(r.raison).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Métiers fermés")
            } footer: {
                Text("Ils rouvrent dès que ton casier n'a plus de condamnation assez lourde.")
            }
        }
    }

    @ViewBuilder
    private func sectionTIG(_ j: Joueur, _ c: CasierJudiciaire, _ cible: CasierCondamnation) -> some View {
        Section {
            if let tig = c.tig {
                progressionTIG(tig)
                LigneAction(titre: "Faire des heures en plus",
                            sousTitre: j.actionsAnnee.contains(CasierSysteme.cleTIG) ? "Déjà fait cette année" : "Santé et bonheur en baisse, karma en hausse",
                            icone: "figure.walk",
                            actif: !j.actionsAnnee.contains(CasierSysteme.cleTIG)) {
                    agir { c, j in CasierSysteme.heuresEnPlus(casier: &c, joueur: &j) }
                }
                LigneAction(titre: "Abandonner les TIG", sousTitre: "Toutes les heures sont perdues", icone: "xmark.circle") {
                    agir { c, j in CasierSysteme.abandonnerTIG(casier: &c, joueur: &j) }
                }
            } else {
                let raison = CasierSysteme.tigIndisponible(cible: cible, casier: c, joueur: j)
                LigneAction(titre: "S'inscrire aux TIG",
                            sousTitre: raison ?? "\(cible.gravite.heuresTIG) heures pour « \(cible.infraction) »",
                            icone: "hammer.fill",
                            actif: raison == nil) {
                    agir { c, j in CasierSysteme.commencerTIG(cibleId: cible.id, casier: &c, joueur: &j) }
                }
            }
        } header: {
            Text("Travaux d'intérêt général")
        } footer: {
            Text("Les heures avancent un peu chaque année. À la fin, la condamnation est effacée. Pour un crime, l'attente est raccourcie de 3 ans.")
        }
    }

    private func progressionTIG(_ tig: CasierTIG) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.majuscule(tig.mission))
            ProgressView(value: Double(tig.heuresFaites), total: Double(max(1, tig.heuresTotal)))
                .tint(Theme.accent)
            Text("\(tig.heuresFaites) heures sur \(tig.heuresTotal)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func sectionAvocats(_ j: Joueur, _ c: CasierJudiciaire, _ cible: CasierCondamnation) -> some View {
        Section {
            ForEach(CasierSysteme.avocats) { a in
                let raison = CasierSysteme.avocatIndisponible(a, cible: cible, casier: c, joueur: j)
                let detail = "\(Format.argent(CasierSysteme.prix(a, pour: cible.gravite))) · chances ≈ \(Self.pourcent(CasierSysteme.chance(a, cible: cible, casier: c, joueur: j)))"
                LigneAction(titre: a.nom, sousTitre: raison ?? (a.description + "\n" + detail), icone: "briefcase.fill", actif: raison == nil) {
                    agir { c, j in CasierSysteme.engagerAvocat(a, cibleId: cible.id, casier: &c, joueur: &j) }
                }
            }
        } header: {
            Text("Avocat : effacer « \(cible.infraction) »")
        } footer: {
            Text("Une tentative par an. Les années sans récidive et un bon karma aident le juge à t'oublier.")
        }
    }

    @ViewBuilder
    private func sectionPistons(_ j: Joueur, _ c: CasierJudiciaire, _ cible: CasierCondamnation) -> some View {
        Section {
            ForEach(CasierSysteme.pistons) { p in
                let raison = CasierSysteme.pistonIndisponible(p, cible: cible, casier: c, joueur: j)
                let contact = CasierSysteme.contact(p, j).map { " (\($0.prenom))" } ?? ""
                let detail = (p.prix.map { Format.argent($0) + " · " } ?? "") + "chances ≈ \(Self.pourcent(CasierSysteme.chance(p, cible: cible, casier: c, joueur: j)))"
                LigneAction(titre: p.nom + contact, sousTitre: raison ?? (p.description + "\n" + detail), icone: "person.badge.key.fill", actif: raison == nil) {
                    agir { c, j in CasierSysteme.activerPiston(p, cibleId: cible.id, casier: &c, joueur: &j) }
                }
            }
        } header: {
            Text("Piston")
        } footer: {
            Text("Chaque piston ne sert qu'une fois par vie. Certains finissent dans le journal, et pas la rubrique people.")
        }
    }
}

import SwiftUI

/// Menu Activités → Projets perso : lancer un projet au long cours, suivre celui en cours, revoir les anciens.
struct ProjetsView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?
    @State private var confirmerAbandon = false

    var body: some View {
        List {
            if let j = engine.joueur {
                let etat = j.jeuVivant ?? JeuVivantEtat()
                if let enCours = etat.projet, let p = VivantBibliotheque.projet(enCours.id) {
                    Section("En cours") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text((p.emoji.map { $0 + " " } ?? "") + p.nom).font(.headline)
                            Text(p.description).font(.subheadline).foregroundStyle(.secondary)
                            ProgressView(value: Double(enCours.etape), total: Double(max(1, p.etapes.count)))
                            Text("Étape \(min(enCours.etape + 1, p.etapes.count)) sur \(p.etapes.count) : la prochaine arrive au passage d'année.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button("Abandonner le projet", role: .destructive) { confirmerAbandon = true }
                    }
                } else {
                    Section {
                        Text("Un projet dure plusieurs années. Chaque année, un point d'étape te demande comment tu t'y prends, puis vient la fin : réussite, demi-succès ou échec.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Section("Lancer un projet") {
                        let dispo = engine.projetsDisponibles()
                        if dispo.isEmpty {
                            Text("Aucun projet possible pour l'instant.").foregroundStyle(.secondary)
                        }
                        ForEach(dispo) { p in
                            Button {
                                message = engine.lancerProjet(p) ?? "C'est parti : \(p.nom.lowercased()). Premier point d'étape l'an prochain."
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text((p.emoji.map { $0 + " " } ?? "") + p.nom).font(.headline).foregroundStyle(Theme.encre)
                                        Spacer()
                                        Text("\(p.etapes.count) ans").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(p.description).font(.subheadline).foregroundStyle(.secondary)
                                    if let cout = p.cout, cout > 0 {
                                        Text("Coût de départ : \(Format.argent(cout))").font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let annuel = p.coutAnnuel, annuel > 0 {
                                        Text("Puis \(Format.argent(annuel)) par an").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                if !etat.projetsFinis.isEmpty {
                    Section("Déjà tentés") {
                        ForEach(Array(etat.projetsFinis.enumerated().reversed()), id: \.offset) { _, f in
                            HStack {
                                Text(VivantBibliotheque.projet(f.id)?.nom ?? f.id)
                                Spacer()
                                Text(Self.libelle(f.fin) + " à \(f.ageFin) ans").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .alert("Abandonner ?", isPresented: $confirmerAbandon) {
            Button("Abandonner", role: .destructive) { engine.abandonnerProjet() }
            Button("Continuer", role: .cancel) {}
        } message: {
            Text("Tout ce que tu as fait jusque-là sera perdu.")
        }
        .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    static func libelle(_ fin: String) -> String {
        switch fin {
        case "reussite": return "🏆 Réussi"
        case "moyen": return "📘 À moitié"
        case "echec": return "📕 Raté"
        default: return "Abandonné"
        }
    }
}

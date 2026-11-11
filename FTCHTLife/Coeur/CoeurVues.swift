import SwiftUI

// Sections du module « Cœur », affichées dans l'écran Amour (ListeRelationsView, filtre .amour).

struct CoeurSection: View {
    @EnvironmentObject var engine: GameEngine
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
        if !texte.isEmpty { message = texte }
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

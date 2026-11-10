import SwiftUI

/// Onglet Compétences : la liste par catégorie, puis le détail de chaque compétence (s'entraîner, cours).
struct CompetencesView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let dispo = Competences.accessibles(j)
                    if dispo.isEmpty {
                        Text("Pour l'instant, ta seule compétence, c'est de baver. Reviens dans quelques années.")
                            .foregroundStyle(.secondary)
                    } else {
                        Section {
                            ResumeCompetences(joueur: j)
                        }
                        ForEach(CatalogueCompetences.categories) { cat in
                            let liste = dispo.filter { $0.categorie == cat.id }
                            if !liste.isEmpty {
                                Section(cat.nom) {
                                    ForEach(liste) { def in
                                        NavigationLink {
                                            CompetenceDetailView(def: def)
                                        } label: {
                                            LigneCompetence(def: def, xp: Competences.xp(def.id, j),
                                                            dejaFaite: !engine.competencePratiquable(def))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Compétences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

/// En-tête : nombre de compétences et meilleure compétence.
private struct ResumeCompetences: View {
    let joueur: Joueur

    var body: some View {
        let etat = Competences.etat(joueur)
        let apprises = etat.xp.values.filter { Competences.niveau(xp: $0) >= 1 }.count
        VStack(alignment: .leading, spacing: 4) {
            if let m = Competences.meilleure(joueur) {
                Text("Ton point fort : \(m.def.nom.lowercased())")
                    .font(.headline)
                Text("« \(Competences.titre(m.def, niveau: m.niveau)) » · \(apprises) compétence" + (apprises > 1 ? "s" : "") + " en cours")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Aucun talent connu.")
                    .font(.headline)
                Text("Entraîne-toi, prends des cours, ou attends qu'un miracle arrive. Les talents débloquent des choix cachés.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Une ligne de la liste : icône, nom, titre du niveau, pastilles.
struct LigneCompetence: View {
    let def: CompetenceDef
    let xp: Int
    var dejaFaite: Bool = false

    var body: some View {
        let n = Competences.niveau(xp: xp)
        HStack(spacing: 12) {
            Image(systemName: def.icone)
                .font(.system(size: 18))
                .foregroundStyle(n > 0 ? Theme.accent : .gray)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(def.nom).foregroundStyle(Theme.encre)
                Text(n > 0 ? Competences.titre(def, niveau: n) : "Jamais essayé")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if dejaFaite {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            PastillesNiveau(niveau: n)
        }
    }
}

/// Cinq pastilles, remplies selon le niveau.
struct PastillesNiveau: View {
    let niveau: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= niveau ? Theme.accent : Color.black.opacity(0.12))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Niveau \(niveau) sur 5")
    }
}

/// Détail d'une compétence : niveau, progression, ce qu'elle débloque, entraînement et cours.
struct CompetenceDetailView: View {
    @EnvironmentObject var engine: GameEngine
    let def: CompetenceDef
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                let xp = Competences.xp(def.id, j)
                let n = Competences.niveau(xp: xp)
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: def.icone)
                                .font(.system(size: 30))
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n > 0 ? Competences.titre(def, niveau: n) : "Jamais essayé")
                                    .font(.title3.weight(.semibold))
                                Text("Niveau \(n) · \(Competences.nomNiveau(n))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        BarreProgressionCompetence(avancement: Competences.avancement(xp: xp))
                        if let reste = Competences.xpAvantNiveauSuivant(xp: xp) {
                            Text("Encore \(reste) XP avant « \(Competences.nomNiveau(n + 1)) ».")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Niveau maximum. Tu pourrais l'enseigner. Tu ne le feras pas.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    Text(def.description)
                    Label(def.debloque, systemImage: "lock.open.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.encre)
                }

                Section("S'entraîner") {
                    let cout = j.age < 18 ? 0 : (def.pratique.cout ?? 0)
                    LigneAction(titre: def.pratique.verbe ?? "S'entraîner",
                                sousTitre: "Une fois par an" + (cout > 0 ? " · \(Format.argent(cout))" : " · gratuit"),
                                icone: def.icone,
                                actif: engine.competencePratiquable(def)) {
                        message = engine.pratiquerCompetence(def)
                    }
                }

                let cours = CatalogueCompetences.cours(pour: def.id).filter { engine.coursVisible($0) }
                if !cours.isEmpty {
                    Section("Cours") {
                        ForEach(cours) { c in
                            LigneAction(titre: c.titre,
                                        sousTitre: c.description + (j.age < 18 ? " · payé par tes parents (peut-être)" : " · \(Format.argent(c.cout))"),
                                        icone: "graduationcap.fill",
                                        actif: engine.coursDisponible(c)) {
                                message = engine.suivreCours(c)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(def.nom)
        .navigationBarTitleDisplayMode(.inline)
        .alert(def.nom, isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

struct BarreProgressionCompetence: View {
    let avancement: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.08))
                Capsule().fill(Theme.accent)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, avancement))))
                    .animation(.easeOut(duration: 0.4), value: avancement)
            }
        }
        .frame(height: 10)
    }
}

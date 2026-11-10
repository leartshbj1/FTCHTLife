import SwiftUI

// Écrans des loisirs. Le moteur choisit :
// - `LoisirsEcran(etat: \.loisirs)` : écran complet (barre de navigation + « Fermer ») ;
// - `LoisirsListe(etat: \.loisirs)` : contenu à pousser dans un NavigationStack existant.
// `signaler` (facultatif) reçoit les signaux de chaque séance, pour le système de répercussions.

typealias LoisirSignaleur = (String, inout Joueur) -> Void

struct LoisirsEcran: View {
    @Environment(\.dismiss) private var dismiss
    let etat: WritableKeyPath<Joueur, LoisirsEtat?>
    var signaler: LoisirSignaleur? = nil

    var body: some View {
        NavigationStack {
            LoisirsListe(etat: etat, signaler: signaler)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
                }
        }
    }
}

struct LoisirsListe: View {
    @EnvironmentObject var engine: GameEngine
    let etat: WritableKeyPath<Joueur, LoisirsEtat?>
    var signaler: LoisirSignaleur? = nil
    @State private var recherche = ""

    var body: some View {
        List {
            if let j = engine.joueur {
                let e = j[keyPath: etat] ?? LoisirsEtat()
                let t = engine.tagsLoisirs(j, etat: e)
                let visibles = LoisirsCatalogue.toutes.filter { LoisirsRegles.visible($0, j, tags: t) }
                let verrouillees = LoisirsCatalogue.toutes.filter { j.age < $0.minAge }.count

                Section {
                    LoisirsEnTete(etat: e)
                }

                if visibles.isEmpty {
                    Text(j.age < 3 ? "Tu es un bébé. Ton loisir principal, c'est baver." : "Aucune activité pour l'instant.")
                        .foregroundStyle(.secondary)
                }

                ForEach(LoisirCategorie.allCases) { c in
                    let acts = visibles.filter { $0.categorie == c && correspond($0) }
                    if !acts.isEmpty {
                        Section {
                            ForEach(acts) { a in
                                NavigationLink {
                                    LoisirDetailView(activite: a, etat: etat, signaler: signaler)
                                } label: {
                                    LoisirLigne(activite: a, etat: e, genre: j.genre)
                                }
                            }
                        } header: {
                            Label(c.titre, systemImage: c.icone)
                        }
                    }
                }

                if verrouillees > 0 && recherche.isEmpty {
                    Section {
                        Text("\(verrouillees) autre\(verrouillees > 1 ? "s" : "") activité\(verrouillees > 1 ? "s" : "") se débloque\(verrouillees > 1 ? "nt" : "") en grandissant.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .searchable(text: $recherche, prompt: "Chercher une activité")
        .navigationTitle("Loisirs")
    }

    private func correspond(_ a: LoisirActivite) -> Bool {
        let r = recherche.trimmingCharacters(in: .whitespaces)
        guard !r.isEmpty else { return true }
        return a.title.localizedCaseInsensitiveContains(r) || a.description.localizedCaseInsensitiveContains(r)
    }
}

// MARK: - En-tête

struct LoisirsEnTete: View {
    let etat: LoisirsEtat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                compteur("\(etat.totalSeances)", "séances")
                compteur("\(etat.xp.values.filter { $0 > 0 }.count)", "activités")
                compteur("\(etat.trophees.count)", "trophées")
            }
            ForEach(etat.blessures, id: \.nom) { b in
                Label(LoisirsEnTete.texteBlessure(b), systemImage: "bandage.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if !etat.trophees.isEmpty {
                Text(etat.trophees.map { "🏆 " + $0 }.joined(separator: "   "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    static func texteBlessure(_ b: LoisirBlessureActive) -> String {
        let an = b.anneesRestantes > 1 ? "ans" : "an"
        return "Blessure : \(b.nom), encore \(b.anneesRestantes) \(an)"
    }

    private func compteur(_ valeur: String, _ titre: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(valeur)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text(titre).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Ligne d'activité

struct LoisirLigne: View {
    let activite: LoisirActivite
    let etat: LoisirsEtat
    let genre: Genre

    var body: some View {
        let xp = etat.experience(activite.id)
        let fini = etat.seances(activite.id) >= activite.seancesParAn
        HStack(spacing: 12) {
            Image(systemName: activite.icon)
                .font(.system(size: 18))
                .foregroundStyle(fini ? .gray : Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(activite.title).foregroundStyle(fini ? .gray : Theme.encre)
                    if etat.estAbonne(activite.id) {
                        Image(systemName: "creditcard.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if xp > 0 {
                    HStack(spacing: 6) {
                        Text(LoisirsRegles.nomNiveau(etat.niveau(activite.id), genre: genre))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ProgressView(value: LoisirsRegles.progression(xp: xp))
                            .tint(Theme.accent)
                            .frame(maxWidth: 80)
                    }
                } else {
                    Text(activite.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if fini {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if activite.seancesParAn > 1 {
                Text("\(etat.seances(activite.id))/\(activite.seancesParAn)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Détail d'une activité

struct LoisirDetailView: View {
    @EnvironmentObject var engine: GameEngine
    let activite: LoisirActivite
    let etat: WritableKeyPath<Joueur, LoisirsEtat?>
    var signaler: LoisirSignaleur? = nil
    @State private var resultat: LoisirResultat?
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                let e = j[keyPath: etat] ?? LoisirsEtat()
                sectionPresentation(j, e)
                if let ab = activite.subscription {
                    sectionAbonnement(ab, j, e)
                }
                sectionOptions(j, e)
            }
        }
        .navigationTitle(activite.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $resultat) { r in
            LoisirResultatView(resultat: r)
                .presentationDetents([.medium, .large])
        }
        .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func sectionPresentation(_ j: Joueur, _ e: LoisirsEtat) -> some View {
        let xp = e.experience(activite.id)
        let niveau = e.niveau(activite.id)
        let serie = e.anneesAffilee[activite.id] ?? 0
        return Section {
            HStack(spacing: 14) {
                Image(systemName: activite.icon)
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Theme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(activite.description).font(.subheadline)
                    Text(activite.categorie.titre).font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(LoisirsRegles.nomNiveau(niveau, genre: j.genre)).font(.headline)
                    Spacer()
                    Text("\(xp) xp").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                ProgressView(value: LoisirsRegles.progression(xp: xp)).tint(Theme.accent)
                Text("Séances cette année : \(e.seances(activite.id))/\(activite.seancesParAn)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if serie >= 2 {
                    Text("🔥 \(serie) ans d'affilée").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func sectionAbonnement(_ ab: LoisirAbonnement, _ j: Joueur, _ e: LoisirsEtat) -> some View {
        let abonne = e.estAbonne(activite.id)
        let titre: String = abonne ? "Résilier (\(ab.name.lowercased()))" : "\(ab.name) : \(Format.argent(ab.yearlyCost))/an"
        let icone: String = abonne ? "xmark.circle" : "creditcard.fill"
        let note: String = abonne
            ? "Tu es " + j.g("abonné", "abonnée") + " : les séances sont gratuites."
            : "Abonné, les séances sont gratuites. Prélevé chaque année, que tu y ailles ou non."
        return Section {
            Button {
                message = engine.basculerAbonnementLoisir(activite, etat: etat)
            } label: {
                Label(titre, systemImage: icone)
            }
        } header: {
            Text("Abonnement")
        } footer: {
            Text(note)
        }
    }

    private func sectionOptions(_ j: Joueur, _ e: LoisirsEtat) -> some View {
        Section("Que veux-tu faire ?") {
            ForEach(activite.options) { o in
                ligneOption(o, j, e)
            }
        }
    }

    private func ligneOption(_ o: LoisirOption, _ j: Joueur, _ e: LoisirsEtat) -> some View {
        let statut = LoisirsRegles.statut(activite, o, j, e)
        let prix = LoisirsRegles.cout(activite, o, j, e)
        let actif = statut == .ok && j.vivant
        return Button {
            resultat = engine.pratiquerLoisir(activite, option: o, etat: etat, signaler: signaler)
        } label: {
            LoisirOptionLigne(option: o, prix: prix, prixAffiche: o.cost ?? 0,
                              raison: statut.raison(genre: j.genre),
                              gratuitParAbonnement: e.estAbonne(activite.id),
                              mineur: j.age < 18)
        }
        .disabled(!actif)
    }
}

struct LoisirOptionLigne: View {
    let option: LoisirOption
    let prix: Int
    let prixAffiche: Int
    let raison: String?
    let gratuitParAbonnement: Bool
    let mineur: Bool

    var body: some View {
        let actif = raison == nil
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(option.label).foregroundStyle(actif ? Theme.encre : .gray)
                    if let n = option.minLevel, n > 0 {
                        Text(String(repeating: "★", count: n))
                            .font(.caption2)
                            .foregroundStyle(actif ? Theme.accent : .gray)
                    }
                }
                if let d = option.description, !d.isEmpty {
                    Text(d).font(.caption).foregroundStyle(.secondary)
                }
                if let r = raison {
                    Text(r).font(.caption.weight(.semibold)).foregroundStyle(Color.red.opacity(0.8))
                }
            }
            Spacer()
            Text(etiquettePrix)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(prix > 0 ? Theme.encre : .green)
        }
        .padding(.vertical, 2)
    }

    private var etiquettePrix: String {
        if prixAffiche <= 0 { return "Gratuit" }
        if gratuitParAbonnement { return "Abonné" }
        if mineur { return "Les parents paient" }
        return Format.argent(prixAffiche)
    }
}

// MARK: - Résultat

struct LoisirResultatView: View {
    @Environment(\.dismiss) private var dismiss
    let resultat: LoisirResultat

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: resultat.mort ? "xmark.octagon.fill" : resultat.icone)
                .font(.system(size: 40))
                .foregroundStyle(resultat.mort ? .red : Theme.accent)
                .padding(.top, 24)
            Text(resultat.titre)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
            Text(resultat.texte)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
            if !resultat.resume.isEmpty {
                Text(resultat.resume)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ForEach(resultat.extras, id: \.self) { x in
                Text(x).font(.subheadline).multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Text(resultat.mort ? "Fin de l'aventure" : "Continuer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.fond.ignoresSafeArea())
    }
}

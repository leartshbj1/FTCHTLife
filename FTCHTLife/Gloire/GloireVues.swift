import SwiftUI

// Écrans du module Gloire : Activités → Célébrité, Activités → Procès. Voir docs/GLOIRE.md.
// Style « liste à icônes » : grosse icône emoji, titre gras bleu, sous-titre, chevron ou « … ».

enum GloireTheme {
    static let bleu = Color(red: 0.05, green: 0.30, blue: 0.60)
    static let bleuClair = Color(red: 0.13, green: 0.42, blue: 0.70)
    static let or = Color(red: 0.96, green: 0.72, blue: 0.18)
}

/// Contenu d'une ligne (sans bouton) : à mettre dans un Button ou un NavigationLink.
struct GloireLigneContenu: View {
    let emoji: String
    let titre: String
    var sousTitre: String? = nil
    var detail: String? = nil
    var detailCouleur: Color = Theme.argentPositif
    var actif: Bool = true
    /// "chevron", "points" ou nil.
    var accessoire: String? = "chevron"

    var body: some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 34))
                .frame(width: 50)
                .opacity(actif ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 3) {
                Text(titre)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(actif ? GloireTheme.bleu : Color.gray)
                    .fixedSize(horizontal: false, vertical: true)
                if let s = sousTitre {
                    Text(s)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(actif ? GloireTheme.bleuClair : Color.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let d = detail {
                    Text(d)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(actif ? detailCouleur : Color.gray)
                }
            }
            Spacer(minLength: 6)
            if accessoire == "points" {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(GloireTheme.bleu)
            } else if accessoire == "chevron" {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GloireTheme.bleu)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Ligne qui se touche.
struct GloireLigne: View {
    let emoji: String
    let titre: String
    var sousTitre: String? = nil
    var detail: String? = nil
    var detailCouleur: Color = Theme.argentPositif
    var actif: Bool = true
    var accessoire: String? = "chevron"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GloireLigneContenu(emoji: emoji, titre: titre, sousTitre: sousTitre, detail: detail,
                               detailCouleur: detailCouleur, actif: actif, accessoire: accessoire)
        }
        .buttonStyle(.plain)
    }
}

/// Barre « Gloire » dorée, alignée sur les barres de stats de l'écran principal.
struct BarreGloire: View {
    let valeur: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .frame(width: 18)
                .foregroundStyle(GloireTheme.or)
            Text("Gloire")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.encre)
                .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(GloireTheme.or)
                        .frame(width: max(0, geo.size.width * CGFloat(min(100, max(0, valeur))) / 100))
                        .animation(.easeOut(duration: 0.4), value: valeur)
                }
            }
            .frame(height: 10)
            Text("\(valeur)%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.encre)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Résultat (avec proposition éventuelle)

struct GloireAffiche: Identifiable {
    let id = UUID()
    var titre: String
    var texte: String
    var dilemme: GloireDilemme? = nil
    var suite: String? = nil

    init(_ r: GloireResultat) {
        titre = r.titre
        texte = r.texte
        dilemme = r.dilemme
    }
}

struct GloireResultatFeuille: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State var affiche: GloireAffiche

    private var enAttente: Bool { affiche.dilemme != nil && affiche.suite == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(affiche.texte)
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(Theme.encre)
                        .fixedSize(horizontal: false, vertical: true)
                    if let d = affiche.dilemme {
                        Divider()
                        Text(d.texte)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(GloireTheme.bleu)
                            .fixedSize(horizontal: false, vertical: true)
                        if let s = affiche.suite {
                            Text(s)
                                .font(.system(size: 17, design: .rounded))
                                .foregroundStyle(Theme.encre)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Button { trancher(d, true) } label: {
                                Text(d.accepter).bold().frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(GloireTheme.bleu)
                            Button { trancher(d, false) } label: {
                                Text(d.refuser).bold().frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(affiche.titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }.disabled(enAttente)
                }
            }
            .interactiveDismissDisabled(enAttente)
        }
    }

    private func trancher(_ d: GloireDilemme, _ oui: Bool) {
        Vibration.legere()
        let r = engine.gloireTrancher(d, accepte: oui)
        affiche.suite = r.ok ? r.texte : "…"
    }
}

// MARK: - Célébrité (écran principal du module)

struct GloireView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var affiche: GloireAffiche?
    @State private var message: String?
    @State private var tele = false
    @State private var confirmerAttache = false

    var body: some View {
        List {
            if let j = engine.joueur {
                entete(j)
                let cat = GloireMoteur.catalogue
                Section {
                    NavigationLink { GloireLivreView() } label: {
                        GloireLigneContenu(emoji: "📖", titre: "Écrire un livre", sousTitre: "Roman, autobiographie, livre de cuisine…", accessoire: nil)
                    }
                    NavigationLink { GloirePubsView() } label: {
                        GloireLigneContenu(emoji: "📺", titre: "Faire une pub", sousTitre: "Prête ta tête à une marque, contre un chèque", accessoire: nil)
                    }
                    NavigationLink {
                        GloireActivitesView(titre: "Faire la fête", aide: "Être vu au bon endroit, avec les bonnes personnes. Ou pas.", activites: cat.fetes)
                    } label: {
                        GloireLigneContenu(emoji: "🥂", titre: "Faire la fête", sousTitre: "Soirées VIP, galas, festivals", accessoire: nil)
                    }
                    NavigationLink {
                        GloireActivitesView(titre: "Séance photo", aide: "Ton apparence fait tout. Le photographe fait le reste.", activites: cat.shootings)
                    } label: {
                        GloireLigneContenu(emoji: "📸", titre: "Séance photo", sousTitre: "Magazines, couvertures, campagnes", accessoire: nil)
                    }
                    NavigationLink {
                        GloireActivitesView(titre: "Passer à la télé", aide: "Talk-shows, journaux, débats. Un mot de travers et c'est le buzz.", activites: cat.plateaux)
                    } label: {
                        GloireLigneContenu(emoji: "🎙️", titre: "Participer à la télé", sousTitre: "Plateaux, interviews, débats", accessoire: nil)
                    }
                    GloireLigne(emoji: "🎮", titre: "Jeux télé et téléréalité", sousTitre: "Quiz, île, villa, télé-crochet") {
                        tele = true
                    }
                } header: {
                    Text("Gérer ta gloire")
                }
                Section {
                    let e = GloireMoteur.etat(j)
                    GloireLigne(emoji: "🤵", titre: e.attachePresse ? (e.attacheNom ?? "Attaché·e de presse") : "Engager un attaché de presse",
                                sousTitre: e.attachePresse
                                    ? "Entretient ta gloire chaque année. Touche pour te séparer."
                                    : "Entretient ta gloire chaque année (+5 %), pour \(Format.argent(GloireMoteur.coutAttache(j))) par an.",
                                accessoire: "points") {
                        confirmerAttache = true
                    }
                } header: {
                    Text("Ton équipe")
                }
            }
        }
        .listStyle(.plain)
        .alerteResultat($message)
        .sheet(item: $affiche) { a in
            GloireResultatFeuille(affiche: a)
                .environmentObject(engine)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $tele) {
            TeleView().environmentObject(engine)
        }
        .confirmationDialog("Attaché de presse", isPresented: $confirmerAttache, titleVisibility: .visible) {
            if engine.joueur?.gloire?.attachePresse == true {
                Button("Te séparer de ton attaché·e", role: .destructive) { attache(false) }
            } else {
                Button("Engager") { attache(true) }
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func attache(_ engager: Bool) {
        let r = engine.gloireAttache(engager: engager)
        if r.ok { affiche = GloireAffiche(r) } else { message = r.texte }
    }

    private func entete(_ j: Joueur) -> some View {
        let g = GloireMoteur.gloire(j)
        let e = GloireMoteur.etat(j)
        var faits: [String] = []
        if !e.livres.isEmpty { faits.append("\(e.livres.count) livre\(e.livres.count > 1 ? "s" : "")") }
        if e.pubs > 0 { faits.append("\(e.pubs) pub\(e.pubs > 1 ? "s" : "")") }
        if e.shootings > 0 { faits.append("\(e.shootings) séance\(e.shootings > 1 ? "s" : "") photo") }
        if e.plateaux > 0 { faits.append("\(e.plateaux) plateau\(e.plateaux > 1 ? "x" : "") télé") }
        if e.fetes > 0 { faits.append("\(e.fetes) fête\(e.fetes > 1 ? "s" : "")") }
        if e.scandales > 0 { faits.append("\(e.scandales) scandale\(e.scandales > 1 ? "s" : "")") }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("⭐").font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text(GloireMoteur.statut(g, j))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(GloireTheme.bleu)
                    Text("La gloire fond chaque année si tu ne l'entretiens pas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            BarreGloire(valeur: g)
            if !faits.isEmpty {
                Text(faits.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Écrire un livre

struct GloireLivreView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var pretePlume = false
    @State private var affiche: GloireAffiche?
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                Section {
                    Toggle(isOn: $pretePlume) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🖋️ Engager un prête-plume").font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("\(Format.argent(GloireMoteur.prixPretePlume)) : un bien meilleur livre, mais ce n'est pas toi qui l'écris.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tint(GloireTheme.bleu)
                }
                Section {
                    ForEach(GloireMoteur.catalogue.livres) { g in
                        let refus = GloireMoteur.refusLivre(g, j)
                        GloireLigne(emoji: g.emoji, titre: g.nom, sousTitre: g.description,
                                    detail: g.gloireMin > 0 ? "Gloire \(g.gloireMin) % minimum" : nil,
                                    detailCouleur: GloireTheme.or, actif: refus == nil) {
                            ecrire(g, refus)
                        }
                    }
                } header: {
                    Text("Quel genre ?")
                } footer: {
                    Text("L'intelligence fait la qualité, la gloire fait les ventes. Les droits d'auteur tombent chaque année.")
                }
                let livres = Array((j.gloire?.livres ?? []).reversed())
                if !livres.isEmpty {
                    Section {
                        ForEach(livres) { l in
                            let genre = GloireMoteur.catalogue.livres.first { $0.id == l.genre }
                            GloireLigneContenu(emoji: genre?.emoji ?? "📘", titre: "« \(l.titre) »",
                                               sousTitre: "\(GloireMoteur.etoiles(l.note)) · publié à \(l.age) ans · \(l.ventesTotales.formatted()) exemplaires\(l.adapte ? " · adapté au cinéma" : "")",
                                               detail: "\(Format.argent(l.revenus)) gagnés", accessoire: nil)
                        }
                    } header: {
                        Text("Tes livres")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Écrire un livre")
        .alerteResultat($message)
        .sheet(item: $affiche) { a in
            GloireResultatFeuille(affiche: a)
                .environmentObject(engine)
                .presentationDetents([.medium, .large])
        }
    }

    private func ecrire(_ g: GloireGenreLivre, _ refus: String?) {
        if let r = refus { message = r; return }
        Vibration.moyenne()
        let r = engine.gloireEcrireLivre(g.id, pretePlume: pretePlume)
        if r.ok { affiche = GloireAffiche(r) } else { message = r.texte }
    }
}

// MARK: - Publicités

struct GloirePubsView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var affiche: GloireAffiche?
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                let g = GloireMoteur.gloire(j)
                let offres = GloireMoteur.offresPub(j)
                Section {
                    if offres.isEmpty {
                        Text("Aucune marque ne t'a contacté cette année. Deviens un peu plus connu\(j.genre == .femme ? "e" : "").")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(offres) { p in
                        let refus = GloirePubsView.refus(p, j)
                        GloireLigne(emoji: p.emoji, titre: p.marque, sousTitre: p.produit + (p.louche == true ? " · produit douteux" : ""),
                                    detail: "Cachet ≈ \(Format.argent(GloireMoteur.cachetEstime(p.cachet, gloire: g)))",
                                    actif: refus == nil, accessoire: "points") {
                            tourner(p, refus)
                        }
                    }
                } header: {
                    Text("Les offres de l'année")
                } footer: {
                    Text("Deux pubs par an au plus. Plus tu es connu\(j.genre == .femme ? "e" : ""), plus les marques paient. Un produit douteux paie mieux, mais ton karma trinque.")
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Faire une pub")
        .alerteResultat($message)
        .sheet(item: $affiche) { a in
            GloireResultatFeuille(affiche: a)
                .environmentObject(engine)
                .presentationDetents([.medium, .large])
        }
    }

    static func refus(_ p: GloirePub, _ j: Joueur) -> String? { GloireMoteur.refusPub(p, j) }

    private func tourner(_ p: GloirePub, _ refus: String?) {
        if let r = refus { message = r; return }
        Vibration.moyenne()
        let r = engine.gloireTournerPub(p.id)
        if r.ok { affiche = GloireAffiche(r) } else { message = r.texte }
    }
}

// MARK: - Fêtes, séances photo, plateaux

struct GloireActivitesView: View {
    @EnvironmentObject var engine: GameEngine
    let titre: String
    let aide: String
    let activites: [GloireActivite]
    @State private var affiche: GloireAffiche?
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                let g = GloireMoteur.gloire(j)
                Section {
                    ForEach(activites) { a in
                        let refus = GloireMoteur.refusActivite(a, j)
                        GloireLigne(emoji: a.emoji, titre: a.nom, sousTitre: a.description,
                                    detail: GloireActivitesView.detail(a, g), detailCouleur: a.prix > 0 ? Theme.argentNegatif : Theme.argentPositif,
                                    actif: refus == nil, accessoire: "points") {
                            faire(a, refus)
                        }
                    }
                } footer: {
                    Text(aide)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(titre)
        .alerteResultat($message)
        .sheet(item: $affiche) { a in
            GloireResultatFeuille(affiche: a)
                .environmentObject(engine)
                .presentationDetents([.medium, .large])
        }
    }

    static func detail(_ a: GloireActivite, _ g: Int) -> String? {
        var morceaux: [String] = []
        if a.gloireMin > 0 && g < a.gloireMin { morceaux.append("Gloire \(a.gloireMin) % minimum") }
        if a.prix > 0 { morceaux.append("Coûte \(Format.argent(a.prix))") }
        if a.cachet != nil { morceaux.append("Cachet ≈ \(Format.argent(GloireMoteur.cachetEstime(a.cachet, gloire: g)))") }
        return morceaux.isEmpty ? nil : morceaux.joined(separator: " · ")
    }

    private func faire(_ a: GloireActivite, _ refus: String?) {
        if let r = refus { message = r; return }
        Vibration.moyenne()
        let r = engine.gloireFaire(a.id)
        if r.ok { affiche = GloireAffiche(r) } else { message = r.texte }
    }
}

// MARK: - Procès

struct ProcesView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var cible: ProcesCibleProposee?
    @State private var motif: ProcesMotif?
    @State private var avocatChoisi: ProcesAvocat?
    @State private var confirmer = false
    @State private var audience: ProcesAudience?
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                Section {
                    HStack(spacing: 12) {
                        Text("⚖️").font(.system(size: 40))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Poursuivre quelqu'un")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(GloireTheme.bleu)
                            Text(sousTitreEtape)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    if let r = ProcesMoteur.refus(j) {
                        Text(r).foregroundStyle(.secondary)
                    }
                }
                if ProcesMoteur.refus(j) == nil {
                    etapes(j)
                }
                let dossiers = Array((j.gloire?.proces ?? []).reversed())
                if !dossiers.isEmpty {
                    Section {
                        ForEach(dossiers) { d in
                            GloireLigneContenu(emoji: d.issue == "perdu" ? "❌" : (d.issue == "accord" ? "🤝" : "✅"),
                                               titre: d.cible, sousTitre: "\(d.motif) · à \(d.age) ans",
                                               detail: (d.bilan >= 0 ? "+" : "−") + Format.argent(abs(d.bilan)),
                                               detailCouleur: d.bilan >= 0 ? Theme.argentPositif : Theme.argentNegatif, accessoire: nil)
                        }
                    } header: {
                        Text("Tes procès")
                    }
                }
            }
        }
        .listStyle(.plain)
        .alerteResultat($message)
        .confirmationDialog("Lancer le procès ?", isPresented: $confirmer, titleVisibility: .visible) {
            Button("Lancer la procédure") { lancer() }
            Button("Annuler", role: .cancel) { avocatChoisi = nil }
        } message: {
            if let c = cible, let m = motif, let a = avocatChoisi {
                Text("\(c.nom) · \(engine.joueur.map { GloireMoteur.texte(m.nom, $0) } ?? m.nom)\n\(a.nom) : \(Format.argent(a.honoraires)) d'avance.")
            }
        }
        .sheet(item: Binding(get: { audience.map { ProcesAudienceBoite(audience: $0) } },
                             set: { if $0 == nil { audience = nil; reinitialiser() } })) { b in
            ProcesAudienceFeuille(aud: b.audience)
                .environmentObject(engine)
        }
    }

    private var sousTitreEtape: String {
        if cible == nil { return "1. Qui veux-tu attaquer ?" }
        if motif == nil { return "2. Pour quel motif ?" }
        return "3. Qui te défend ?"
    }

    @ViewBuilder
    private func etapes(_ j: Joueur) -> some View {
        if let c = cible {
            Section {
                GloireLigne(emoji: c.emoji, titre: c.nom, sousTitre: "Changer de cible", accessoire: nil) {
                    cible = nil
                    motif = nil
                }
                if let m = motif {
                    GloireLigne(emoji: "📂", titre: GloireMoteur.texte(m.nom, j), sousTitre: "Changer de motif", accessoire: nil) {
                        motif = nil
                    }
                }
            } header: {
                Text("Ton dossier")
            }
            if let m = motif {
                Section {
                    ForEach(ProcesMoteur.avocats(j)) { a in
                        let chance = ProcesMoteur.chance(c, m, a, j)
                        GloireLigne(emoji: a.emoji, titre: a.nom, sousTitre: a.description,
                                    detail: "\(a.honoraires == 0 ? "Gratuit" : Format.argent(a.honoraires)) · \(ProcesMoteur.estimation(chance))",
                                    detailCouleur: chance >= 0.5 ? Theme.argentPositif : (chance >= 0.3 ? GloireTheme.or : Theme.argentNegatif),
                                    accessoire: "points") {
                            if !Shkurtaaa.peutPayer(a.honoraires, solde: j.argent) {
                                message = "\(a.nom) demande \(Format.argent(a.honoraires)) d'avance. Tu ne les as pas."
                            } else {
                                avocatChoisi = a
                                confirmer = true
                            }
                        }
                    }
                } header: {
                    Text("Ton avocat")
                } footer: {
                    Text("Un bon avocat coûte cher, mais il change tout. Si tu perds, tu paies aussi les frais de l'autre camp.")
                }
            } else {
                Section {
                    ForEach(ProcesMoteur.motifs(c.type)) { m in
                        GloireLigne(emoji: m.frivole == true ? "🤡" : "📂", titre: GloireMoteur.texte(m.nom, j), sousTitre: GloireMoteur.texte(m.description, j),
                                    detail: "Jusqu'à \(Format.argent(Int(Double(m.dommages.last ?? 0) * c.poche)))") {
                            motif = m
                        }
                    }
                } header: {
                    Text("Le motif")
                }
            }
        } else {
            let cibles = ProcesMoteur.cibles(j)
            let proches = cibles.filter { $0.relation != nil }
            let autres = cibles.filter { $0.relation == nil }
            if !proches.isEmpty {
                Section {
                    ForEach(proches) { c in
                        GloireLigne(emoji: c.emoji, titre: c.nom, sousTitre: c.description) {
                            cible = c
                        }
                    }
                } header: {
                    Text("Tes proches")
                }
            }
            Section {
                ForEach(autres) { c in
                    GloireLigne(emoji: c.emoji, titre: c.nom, sousTitre: c.description) {
                        cible = c
                    }
                }
            } header: {
                Text("Entreprises et institutions")
            }
        }
    }

    private func lancer() {
        guard let c = cible, let m = motif, let a = avocatChoisi else { return }
        Vibration.moyenne()
        let res = engine.procesOuvrir(c, m, a)
        if let aud = res.audience {
            audience = aud
        } else {
            message = res.refus
            avocatChoisi = nil
        }
    }

    private func reinitialiser() {
        cible = nil
        motif = nil
        avocatChoisi = nil
    }
}

/// Enveloppe Identifiable pour présenter l'audience en feuille.
struct ProcesAudienceBoite: Identifiable {
    let id = "audience"
    let audience: ProcesAudience
}

struct ProcesAudienceFeuille: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State var aud: ProcesAudience

    var body: some View {
        NavigationStack {
            List {
                Section {
                    GloireLigneContenu(emoji: aud.cibleEmoji, titre: "Toi contre \(aud.cibleNom)",
                                       sousTitre: "\(engine.joueur.map { GloireMoteur.texte(aud.motif.nom, $0) } ?? aud.motif.nom) · défendu\(engine.joueur?.genre == .femme ? "e" : "") par \(aud.avocat.nom)",
                                       detail: "Tu réclames \(Format.argent(aud.demande))", accessoire: nil)
                    Text(aud.texteAudience)
                        .font(.system(size: 16, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                }
                switch aud.phase {
                case .accord:
                    Section {
                        Text(aud.texteOffre ?? "")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(GloireTheme.bleu)
                            .fixedSize(horizontal: false, vertical: true)
                        GloireLigne(emoji: "🤝", titre: "Accepter l'accord", sousTitre: "Tu touches \(Format.argent(aud.offre ?? 0)), sans risque", accessoire: nil) {
                            Vibration.moyenne()
                            engine.procesAccord(&aud)
                        }
                        GloireLigne(emoji: "⚔️", titre: "Refuser, on va au procès", sousTitre: "Tout ou rien devant le juge", accessoire: nil) {
                            ProcesMoteur.refuserAccord(&aud)
                        }
                    } header: {
                        Text("Proposition à l'amiable")
                    }
                case .plaidoirie:
                    Section {
                        ForEach(ProcesMoteur.catalogue.strategies) { s in
                            GloireLigne(emoji: s.emoji, titre: s.nom, sousTitre: s.description, accessoire: nil) {
                                Vibration.moyenne()
                                engine.procesPlaider(s, &aud)
                            }
                        }
                    } header: {
                        Text("Ta plaidoirie")
                    } footer: {
                        Text("Chaque stratégie s'appuie sur une de tes qualités : intelligence, apparence, karma ou bonheur.")
                    }
                case .verdict:
                    Section {
                        Text(aud.gagne ? "🏆 Gagné" : "💸 Perdu")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(aud.gagne ? Theme.argentPositif : Theme.argentNegatif)
                        Text(aud.texteVerdict)
                            .font(.system(size: 16, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Text("Verdict")
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Procès")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }.disabled(aud.phase != .verdict)
                }
            }
            .interactiveDismissDisabled(aud.phase != .verdict)
        }
    }
}

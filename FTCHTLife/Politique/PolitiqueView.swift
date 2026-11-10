import SwiftUI

/// Écran de la carrière politique.
/// Usage : `PolitiqueView(etat: \.politique)` une fois `var politique: PolEtat?` ajouté à `Joueur`.
struct PolitiqueView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let etat: WritableKeyPath<Joueur, PolEtat?>

    @State private var message: String?
    @State private var dossierOuvert: PolDossierAffiche?
    @State private var listePartis = false
    @State private var listeLois = false
    @State private var listeAbrogations = false

    init(etat: WritableKeyPath<Joueur, PolEtat?>) {
        self.etat = etat
    }

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    contenu(j, j[keyPath: etat] ?? PolEtat())
                }
            }
            .navigationTitle("Politique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
            .sheet(item: $dossierOuvert) { aff in
                PolDossierView(affiche: aff) { i in trancher(aff.dossier, i) }
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $listePartis) {
                PolPartisView { id in resultat { PolMoteur.adherer(id, &$0, &$1) } }
            }
            .sheet(isPresented: $listeLois) {
                if let e = engine.joueur?[keyPath: etat] ?? nil {
                    PolLoisView(titre: "Proposer un texte",
                                lois: PolMoteur.loisProposables(e),
                                info: { "Chances d'adoption : \(Int(PolMoteur.chanceAdoption($0, e) * 100)) %" }) { loi in
                        resultat { PolMoteur.proposerLoi(loi.id, &$0, &$1) }
                    }
                }
            }
            .sheet(isPresented: $listeAbrogations) {
                if let e = engine.joueur?[keyPath: etat] ?? nil {
                    PolLoisView(titre: "Abroger un texte", lois: PolMoteur.loisAbrogeables(e), info: { _ in "En vigueur" }) { loi in
                        resultat { PolMoteur.abrogerLoi(loi.id, &$0, &$1) }
                    }
                }
            }
        }
    }

    // MARK: - Contenu

    @ViewBuilder
    private func contenu(_ j: Joueur, _ e: PolEtat) -> some View {
        resume(j, e)

        if j.age < PolMoteur.ageMilitant {
            Section {
                Text("Tu es trop jeune pour la politique. Pour l'instant, ton seul électorat, c'est ton doudou.")
            }
        } else if !j.vivant {
            EmptyView()
        } else {
            dossiers(j, e)
            parti(j, e)
            if e.candidature != nil { campagne(j, e) }
            if j.age >= PolMoteur.ageCandidat { elections(j, e) }
            if e.mandat != nil { mandat(j, e) }
            if j.age >= PolMoteur.ageCandidat { argent(j, e) }
            lois(e)
            historique(j, e)
        }
    }

    @ViewBuilder
    private func resume(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Ta vie politique") {
            if let p = PolCatalogue.parti(e.partiId) {
                HStack {
                    Circle().fill(Color(polHex: p.couleur)).frame(width: 12, height: 12)
                    Text(p.nom).bold()
                    Spacer()
                    Text(p.sigle).foregroundStyle(.secondary)
                }
            } else {
                HStack { Text("Parti"); Spacer(); Text("Sans étiquette").foregroundStyle(.secondary) }
            }
            HStack {
                Text("Mandat")
                Spacer()
                Text(texteMandat(j, e)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            BarreStat(titre: "Popularité", icone: "person.3.fill", valeur: e.popularite)
            BarreStat(titre: "Influence", icone: "point.3.connected.trianglepath.dotted", valeur: e.influence)
            BarreStat(titre: "Intégrité", icone: "checkmark.seal.fill", valeur: 100 - e.casseroles)
            if e.partiId != nil {
                BarreStat(titre: "Loyauté", icone: "flag.fill", valeur: e.loyaute)
            }
            if e.caisse > 0 {
                HStack { Text("Caisse de campagne"); Spacer(); Text(Format.argent(e.caisse)).foregroundStyle(.secondary) }
            }
            if e.parrainages > 0 {
                HStack { Text("Parrainages"); Spacer(); Text("\(e.parrainages) / \(PolMoteur.parrainagesRequis)").foregroundStyle(.secondary) }
            }
            if let s = e.dernierSondage {
                HStack { Text("Dernier sondage"); Spacer(); Text("\(s) %").foregroundStyle(.secondary) }
            }
            if let r = e.dernierResultat {
                Text(r).font(.caption).foregroundStyle(.secondary)
            }
            if e.ineligibilite > 0 {
                Text("⚖️ Inéligible encore \(e.ineligibilite) an\(e.ineligibilite > 1 ? "s" : "").").foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func dossiers(_ j: Joueur, _ e: PolEtat) -> some View {
        let liste = PolMoteur.dossiersEnAttente(e)
        if !liste.isEmpty {
            Section("Sur ton bureau (à traiter avant la fin de l'année)") {
                ForEach(liste) { d in
                    LigneAction(titre: d.title,
                                sousTitre: d.kind == "scandale" ? "Scandale" : (d.kind == "militant" ? "Vie de parti" : "Dossier"),
                                icone: d.kind == "scandale" ? "flame.fill" : "folder.fill") {
                        ouvrir(d, intro: nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func parti(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Parti") {
            if e.partiId == nil {
                LigneAction(titre: "Adhérer à un parti", sousTitre: "Carte, badge et tracts offerts", icone: "person.crop.circle.badge.plus") {
                    listePartis = true
                }
            } else {
                action("Militer", "Tracts, affiches, phoning", "megaphone", cle: "militer", j, PolMoteur.militer)
                action("Flatter les cadres du parti", "Loyauté et influence", "hands.clap.fill", cle: "flatter", j, PolMoteur.flatter)
                LigneAction(titre: "Quitter le parti", sousTitre: "Avec une lettre ouverte", icone: "door.left.hand.open") {
                    agir(PolMoteur.quitterParti)
                }
            }
        }
    }

    @ViewBuilder
    private func campagne(_ j: Joueur, _ e: PolEtat) -> some View {
        if let c = e.candidature {
            Section("Campagne : \(c.poste.nom(j.genre).lowercased())") {
                HStack {
                    Text("Adversaire")
                    Spacer()
                    Text(c.adversaire + (PolCatalogue.parti(c.adversairePartiId).map { " (\($0.sigle))" } ?? ""))
                        .foregroundStyle(.secondary)
                }
                HStack { Text("Dynamique"); Spacer(); Text(dynamique(c.points)).foregroundStyle(.secondary) }
                ForEach(PolMoteur.ActionCampagne.allCases) { a in
                    action(a.titre, nil, a.icone, cle: "cam_" + a.rawValue, j) { PolMoteur.campagne(a, &$0, &$1) }
                }
                LigneAction(titre: "Débat télévisé", sousTitre: c.debatFait ? "Déjà fait" : "Une seule chance", icone: "tv.fill", actif: !c.debatFait) {
                    agir(PolMoteur.debat)
                }
                action("Serrer des mains", "Marché, salon, sortie du métro", "hand.wave.fill", cle: "mains", j, PolMoteur.serrerMains)
                LigneAction(titre: "Abandonner la campagne", icone: "xmark.circle") {
                    agir(PolMoteur.abandonnerCampagne)
                }
            }
        }
    }

    @ViewBuilder
    private func elections(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Élections et nominations") {
            if e.candidature == nil {
                ForEach(PolPoste.allCases.filter { $0.estElu }) { p in
                    let raison = PolMoteur.empechementCandidature(p, j, e)
                    LigneAction(titre: "Se présenter : \(p.nom(j.genre).lowercased())",
                                sousTitre: raison ?? sousTitreCandidature(p, e),
                                icone: "checkmark.rectangle.stack.fill",
                                actif: raison == nil) {
                        agir { PolMoteur.seDeclarer(p, &$0, &$1) }
                    }
                }
            }
            if e.mandat?.poste == .conseiller {
                action("Demander un poste d'adjoint", "Au maire, gentiment", "person.badge.key.fill", cle: "adjoint", j, PolMoteur.briguerAdjoint)
            }
            if PolMoteur.empechementMinistere(j, e) == nil {
                action("Proposer tes services au chef de l'État", "Pour entrer au gouvernement", "building.columns.fill", cle: "ministere", j, PolMoteur.demanderMinistere)
            }
            if (e.aOccupe(.depute) || e.aOccupe(.ministre)) && e.mandat?.poste != .president {
                action("Récolter des parrainages", "\(e.parrainages)/\(PolMoteur.parrainagesRequis) pour la présidentielle", "signature", cle: "parrainages", j, PolMoteur.recolterParrainages)
            }
        }
    }

    @ViewBuilder
    private func mandat(_ j: Joueur, _ e: PolEtat) -> some View {
        if let m = e.mandat {
            Section(m.poste == .ministre ? PolMoteur.nomMinistere(e) : "Ton mandat") {
                if m.poste.niveauLois != nil {
                    LigneAction(titre: m.poste == .ministre ? "Prendre un décret" : "Proposer un texte",
                                sousTitre: PolMoteur.dejaFaitCetteAnnee("loi", j) ? "Déjà fait cette année" : "Une fois par an",
                                icone: "doc.text.fill",
                                actif: !PolMoteur.dejaFaitCetteAnnee("loi", j) && !PolMoteur.loisProposables(e).isEmpty) {
                        listeLois = true
                    }
                    if !PolMoteur.loisAbrogeables(e).isEmpty {
                        LigneAction(titre: "Abroger un texte", icone: "trash.fill", actif: !PolMoteur.dejaFaitCetteAnnee("loi", j)) {
                            listeAbrogations = true
                        }
                    }
                }
                action("Inaugurer quelque chose", "Ruban et grands ciseaux", "scissors", cle: "inaugurer", j, PolMoteur.inaugurer)
                if e.candidature == nil {
                    action("Serrer des mains", "Marché, salon, sortie du métro", "hand.wave.fill", cle: "mains", j, PolMoteur.serrerMains)
                }
                action("Lâcher une petite phrase", "Buzz ou polémique", "quote.bubble.fill", cle: "phrase", j, PolMoteur.phraseChoc)
                action("Se servir dans le budget", "« Frais de représentation »", "eurosign.circle.fill", cle: "servir", j, PolMoteur.seServir)
                LigneAction(titre: "Démissionner", icone: "rectangle.portrait.and.arrow.right") {
                    agir(PolMoteur.demissionner)
                }
            }
        }
    }

    @ViewBuilder
    private func argent(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Caisse de campagne") {
            action("Organiser un dîner de levée de fonds", "Saumon tiède et chèques", "fork.knife", cle: "fonds", j, PolMoteur.leverFonds)
            if e.mandat == nil && e.partiId != nil {
                action("Lâcher une petite phrase", "Buzz ou polémique", "quote.bubble.fill", cle: "phrase", j, PolMoteur.phraseChoc)
            }
            ForEach([1_000, 10_000, 100_000], id: \.self) { montant in
                LigneAction(titre: "Verser \(Format.argent(montant)) de ta poche", icone: "banknote.fill", actif: j.argent >= montant) {
                    agir { PolMoteur.verserCaisse(montant, &$0, &$1) }
                }
            }
        }
    }

    @ViewBuilder
    private func lois(_ e: PolEtat) -> some View {
        let actives = e.loisActives.compactMap { PolCatalogue.loi($0) }
        if !actives.isEmpty {
            Section("Lois en vigueur") {
                ForEach(actives) { loi in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loi.titre).bold()
                        Text(remplir(loi.description)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func historique(_ j: Joueur, _ e: PolEtat) -> some View {
        if !e.historique.isEmpty || e.elections > 0 {
            Section("Historique") {
                if e.elections > 0 {
                    Text("Élections : \(e.electionsGagnees) gagnée\(e.electionsGagnees > 1 ? "s" : "") sur \(e.elections)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(e.historique.reversed())) { h in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.poste == .ministre ? (PolCatalogue.ministere(h.ministereId)?.nom ?? "Ministre") : h.poste.nom(j.genre)).bold()
                        Text("De \(h.ageDebut) à \(h.ageFin) ans · \(h.fin)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Outils

    /// Ligne d'action limitée à une fois par an.
    private func action(_ titre: String, _ sousTitre: String?, _ icone: String, cle: String, _ j: Joueur,
                        _ f: @escaping (inout Joueur, inout PolEtat) -> PolResultat) -> some View {
        let fait = PolMoteur.dejaFaitCetteAnnee(cle, j)
        return LigneAction(titre: titre, sousTitre: fait ? "Déjà fait cette année" : sousTitre, icone: icone, actif: !fait) {
            agir(f)
        }
    }

    private func agir(_ f: (inout Joueur, inout PolEtat) -> PolResultat) {
        guard let r = resultatBrut(f) else { return }
        if let d = r.dossier {
            ouvrir(d, intro: r.texte)
        } else {
            message = r.texte
        }
    }

    /// Exécute une action et renvoie seulement son texte (pour les sous-écrans qui affichent eux-mêmes le résultat).
    private func resultat(_ f: (inout Joueur, inout PolEtat) -> PolResultat) -> String {
        resultatBrut(f)?.texte ?? ""
    }

    private func resultatBrut(_ f: (inout Joueur, inout PolEtat) -> PolResultat) -> PolResultat? {
        var res: PolResultat?
        engine.modifier { j in
            var p = j[keyPath: etat] ?? PolEtat()
            res = f(&j, &p)
            j[keyPath: etat] = p
        }
        return res
    }

    private func ouvrir(_ d: PolDossier, intro: String?) {
        guard let j = engine.joueur else { return }
        let e = j[keyPath: etat] ?? nil
        dossierOuvert = PolDossierAffiche(dossier: d, intro: intro,
                                          texte: PolMoteur.remplir(d.text, j, e),
                                          choix: d.choices.map { PolMoteur.remplir($0.label, j, e) })
    }

    private func trancher(_ d: PolDossier, _ i: Int) -> String {
        var t = ""
        engine.modifier { j in
            var p = j[keyPath: etat] ?? PolEtat()
            t = PolMoteur.trancher(d, choix: i, &j, &p, appliquer: { eff, jj in engine.appliquer(eff, &jj) })
            j[keyPath: etat] = p
        }
        return t
    }

    private func remplir(_ texte: String) -> String {
        guard let j = engine.joueur else { return texte }
        return PolMoteur.remplir(texte, j, j[keyPath: etat] ?? nil)
    }

    private func texteMandat(_ j: Joueur, _ e: PolEtat) -> String {
        guard let m = e.mandat else { return "Aucun" }
        var t = m.poste == .maire ? "Maire de \(j.ville)" : m.poste.nom(j.genre)
        if let r = m.anneesRestantes { t += " · encore \(r) an\(r > 1 ? "s" : "")" }
        if m.numero > 1 { t += " · \(m.numero)e mandat" }
        return t
    }

    private func sousTitreCandidature(_ p: PolPoste, _ e: PolEtat) -> String {
        var t = e.mandat?.poste == p ? "Réélection" : "Élection à la fin de l'année"
        if p.caution > 0 { t += " · caution \(Format.argent(p.caution))" }
        return t
    }

    private func dynamique(_ points: Double) -> String {
        switch points {
        case ..<(-5): return "Catastrophique"
        case ..<0: return "Mauvaise"
        case ..<6: return "Correcte"
        case ..<12: return "Bonne"
        default: return "Excellente"
        }
    }
}

// MARK: - Dossier

struct PolDossierAffiche: Identifiable {
    let id = UUID()
    let dossier: PolDossier
    let intro: String?
    let texte: String
    let choix: [String]
}

struct PolDossierView: View {
    @Environment(\.dismiss) private var dismiss
    let affiche: PolDossierAffiche
    let trancher: (Int) -> String
    @State private var resultat: String?

    init(affiche: PolDossierAffiche, trancher: @escaping (Int) -> String) {
        self.affiche = affiche
        self.trancher = trancher
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let intro = affiche.intro {
                        Text(intro).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Label(etiquette, systemImage: affiche.dossier.kind == "scandale" ? "flame.fill" : "folder.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Text(affiche.dossier.title).font(.title3.weight(.bold))
                    Text(affiche.texte).font(.body)
                    if let r = resultat {
                        Text(r)
                            .font(.body.weight(.semibold))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        Button {
                            dismiss()
                        } label: {
                            Text("Continuer").bold().frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                    } else {
                        ForEach(Array(affiche.choix.enumerated()), id: \.offset) { i, label in
                            Button {
                                resultat = trancher(i)
                            } label: {
                                Text(label)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.encre)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.fond.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    private var etiquette: String {
        switch affiche.dossier.kind {
        case "scandale": return "SCANDALE"
        case "debat": return "DÉBAT TÉLÉVISÉ"
        case "campagne": return "CAMPAGNE"
        case "militant": return "VIE DE PARTI"
        default: return "DOSSIER"
        }
    }
}

// MARK: - Partis

struct PolPartisView: View {
    @Environment(\.dismiss) private var dismiss
    let adherer: (String) -> String
    @State private var message: String?

    init(adherer: @escaping (String) -> String) {
        self.adherer = adherer
    }

    var body: some View {
        NavigationStack {
            List(PolCatalogue.partis) { p in
                Button {
                    message = adherer(p.id)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Circle().fill(Color(polHex: p.couleur)).frame(width: 14, height: 14).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(p.nom) (\(p.sigle))").bold().foregroundStyle(Theme.encre)
                            Text("« \(p.slogan) »").font(.caption).italic().foregroundStyle(Theme.encre)
                            Text(p.description).font(.caption).foregroundStyle(.secondary)
                            Text("Cotisation : \(Format.argent(p.cotisation))/an").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Choisir un parti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil; dismiss() }
            } message: {
                Text(message ?? "")
            }
        }
    }
}

// MARK: - Lois

struct PolLoisView: View {
    @Environment(\.dismiss) private var dismiss
    let titre: String
    let lois: [PolLoi]
    let info: (PolLoi) -> String
    let choisir: (PolLoi) -> String
    @State private var message: String?

    init(titre: String, lois: [PolLoi], info: @escaping (PolLoi) -> String, choisir: @escaping (PolLoi) -> String) {
        self.titre = titre
        self.lois = lois
        self.info = info
        self.choisir = choisir
    }

    var body: some View {
        NavigationStack {
            List {
                if lois.isEmpty {
                    Text("Aucun texte disponible. Tu as déjà tout essayé, même le pire.")
                }
                ForEach(lois) { loi in
                    Button {
                        message = choisir(loi)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(loi.titre).bold().foregroundStyle(Theme.encre)
                            Text(loi.description).font(.caption).foregroundStyle(.secondary)
                            Text(info(loi)).font(.caption2.weight(.semibold)).foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil; dismiss() }
            } message: {
                Text(message ?? "")
            }
        }
    }
}

// MARK: - Couleur

extension Color {
    /// Couleur depuis "#RRGGBB" (gris si invalide).
    init(polHex hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = UInt32(s, radix: 16) else {
            self = .gray
            return
        }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

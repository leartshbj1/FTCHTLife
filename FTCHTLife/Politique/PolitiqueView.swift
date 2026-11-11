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
    @State private var listePM = false
    @State private var listeReferendum = false
    @State private var listeForce = false
    @State private var fonderParti = false
    @State private var recrutement: PolRole?

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
                PolPartisView(partis: PolCatalogue.partisDuPays(engine.joueur.map { PolMoteur.systeme($0).id })) { id in
                    resultat { PolMoteur.adherer(id, &$0, &$1) }
                }
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
            .sheet(isPresented: $listePM) {
                PolChoixPMView(candidats: PolMoteur.candidatsPremierMinistre()) { pnj in
                    resultat { PolMoteur.nommerPremierMinistre(pnj, &$0, &$1) }
                }
            }
            .sheet(item: $recrutement) { role in
                PolRecrutementView(role: role, candidats: PolMoteur.candidatsEquipe(role)) { m in
                    resultat { PolMoteur.recruter(m, &$0, &$1) }
                }
            }
            .sheet(isPresented: $fonderParti) {
                PolFonderPartiView { nom, sigle, slogan, couleur, bord in
                    resultat { PolMoteur.fonderParti(nom: nom, sigle: sigle, slogan: slogan, couleur: couleur, bord: bord, &$0, &$1) }
                }
            }
            .sheet(isPresented: $listeReferendum) {
                if let e = engine.joueur?[keyPath: etat] ?? nil {
                    PolLoisView(titre: "Référendum",
                                lois: loisNationalesDisponibles(e),
                                info: { "Chances de victoire du oui : \(chanceReferendum($0, e)) %" }) { loi in
                        resultat { PolMoteur.referendum(loi.id, &$0, &$1) }
                    }
                }
            }
            .sheet(isPresented: $listeForce) {
                if let e = engine.joueur?[keyPath: etat] ?? nil {
                    PolLoisView(titre: "Adopter sans vote", lois: loisNationalesDisponibles(e),
                                info: { _ in "Adoptée à coup sûr · l'opposition riposte" }) { loi in
                        resultat { PolMoteur.passerEnForce(loi.id, &$0, &$1) }
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
                Text("Tu es trop jeune pour la politique. Tu pourras adhérer à un parti en grandissant.")
            }
        } else if !j.vivant {
            EmptyView()
        } else {
            Group {
                dossiers(j, e)
                if e.mandat?.poste == .president || e.mandat?.poste == .premierMinistre { gouvernement(j, e) }
                parti(j, e)
                if e.partiId != nil { vieDeParti(j, e) }
                if e.candidature != nil { campagne(j, e) }
                if j.age >= PolMoteur.ageCandidat { elections(j, e) }
                if e.mandat != nil { mandat(j, e) }
            }
            Group {
                if PolMoteur.estAncien(e) { apres(j, e) }
                if j.age >= PolMoteur.ageCandidat {
                    argent(j, e)
                    equipe(j, e)
                }
                if !e.rivaux.isEmpty { rivaux(j, e) }
                if j.age >= PolMoteur.ageCandidat { pays(e) }
                lois(e)
                historique(j, e)
            }
        }
    }

    @ViewBuilder
    private func resume(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Ta vie politique") {
            if let p = e.parti {
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
            Group {
                if e.caisse > 0 {
                    HStack { Text("Caisse de campagne"); Spacer(); Text(Format.argent(e.caisse)).foregroundStyle(.secondary) }
                }
                if e.parrainages > 0 && PolMoteur.systeme(j).parrainages == true {
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
                LigneAction(titre: "Adhérer à un parti", sousTitre: "Choisis une famille politique", icone: "person.crop.circle.badge.plus") {
                    listePartis = true
                }
                if j.age >= PolMoteur.ageCandidat && !PolMoteur.systeme(j).estPartiUnique {
                    LigneAction(titre: "Fonder ton propre parti", sousTitre: "20 d'influence ou 20 000 €", icone: "sparkles") {
                        fonderParti = true
                    }
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
            Section("Campagne : \(c.poste.nom(j).polMinuscule())") {
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
                ForEach(PolPoste.allCases.filter { PolMoteur.systeme(j).estElectif($0) && $0.rang <= max(1, e.rangMax + 2) }) { p in
                    let raison = PolMoteur.empechementCandidature(p, j, e)
                    LigneAction(titre: "Se présenter : \(p.nom(j).polMinuscule())",
                                sousTitre: raison ?? sousTitreCandidature(p, e),
                                icone: "checkmark.rectangle.stack.fill",
                                actif: raison == nil) {
                        agir { PolMoteur.seDeclarer(p, &$0, &$1) }
                    }
                }
            }
            ForEach(PolPoste.allCases.filter { PolMoteur.besoinInvestiture($0, e) && PolMoteur.empechementCandidature($0, j, e) == nil && e.investiture != $0.rawValue }) { p in
                action(p == .president ? "Participer à la primaire du parti" : "Demander l'investiture : \(p.nom(j).polMinuscule())",
                       "Sinon : candidature dissidente et exclusion", "person.crop.circle.badge.checkmark", cle: "investiture", j) {
                    PolMoteur.demanderInvestiture(p, &$0, &$1)
                }
            }
            if let inv = e.investiture.flatMap({ PolPoste(rawValue: $0) }) {
                Text("✅ Investi" + j.g("", "e") + " par ton parti pour : \(inv.nom(j).polMinuscule())").font(.caption)
            }
            if PolMoteur.empechementPremierMinistre(j, e) == nil {
                action("Viser le poste de " + PolPoste.premierMinistre.nom(j).polMinuscule(), "Prendre la tête du gouvernement", "building.columns.circle.fill", cle: "premier_ministre", j, PolMoteur.viserPremierMinistre)
            }
            if PolMoteur.empechementCommissaire(j, e) == nil {
                action("Partir à " + PolMoteur.systeme(j).commission, "Devenir commissaire", "globe.europe.africa.fill", cle: "commission", j, PolMoteur.partirCommission)
            }
            if e.mandat?.poste == .conseiller {
                action("Demander un poste d'adjoint", "Au maire, gentiment", "person.badge.key.fill", cle: "adjoint", j, PolMoteur.briguerAdjoint)
            }
            if PolMoteur.empechementMinistere(j, e) == nil {
                action("Proposer tes services pour un ministère", "Pour entrer au gouvernement", "building.columns.fill", cle: "ministere", j, PolMoteur.demanderMinistere)
            }
            if (e.aOccupe(.depute) || e.aOccupe(.ministre)) && e.mandat?.poste != .president && PolMoteur.systeme(j).parrainages == true {
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
            action("Organiser un dîner de levée de fonds", "Dons de sympathisants", "fork.knife", cle: "fonds", j, PolMoteur.leverFonds)
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
                        Text(h.poste == .ministre ? (PolCatalogue.ministere(h.ministereId)?.nom ?? "Ministre") : h.poste.nom(j)).bold()
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
        var t = m.poste == .maire ? "Maire de \(j.ville)" : m.poste.nom(j)
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
    let partis: [PolParti]
    let adherer: (String) -> String
    @State private var message: String?

    init(partis: [PolParti], adherer: @escaping (String) -> String) {
        self.partis = partis
        self.adherer = adherer
    }

    var body: some View {
        NavigationStack {
            List(partis) { p in
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
                    Text("Aucun texte disponible. Reviens quand la situation aura changé.")
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

// MARK: - Deuxième couche

extension PolitiqueView {

    @ViewBuilder
    func pays(_ e: PolEtat) -> some View {
        let p = e.pays
        Section("État du pays") {
            HStack { Text("Croissance"); Spacer(); Text("\(PolMoteur.format1(p.croissance)) %").foregroundStyle(p.croissance >= 1 ? Color.green : Color.red) }
            HStack { Text("Chômage"); Spacer(); Text("\(PolMoteur.format1(p.chomage)) %").foregroundStyle(p.chomage <= 8 ? Color.green : Color.red) }
            HStack { Text("Dette publique"); Spacer(); Text("\(Int(p.dette)) % du PIB").foregroundStyle(.secondary) }
            BarreStat(titre: "Moral", icone: "face.smiling", valeur: p.moral)
            BarreStat(titre: "Sécurité", icone: "lock.shield.fill", valeur: p.securite)
            BarreStat(titre: "Calme social", icone: "hand.raised.slash.fill", valeur: 100 - e.mobilisation)
            if e.mandat?.poste.gouverne == true {
                BarreStat(titre: "Majorité", icone: "building.columns.fill", valeur: e.majorite)
            }
        }
        Section("Ce que pensent les électeurs") {
            ForEach(PolSegment.allCases) { s in
                BarreStat(titre: s.nom, icone: s.icone, valeur: e.opinion(s))
            }
        }
    }

    @ViewBuilder
    func vieDeParti(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Dans le parti") {
            HStack { Text("Rang"); Spacer(); Text(PolMoteur.rangsParti[min(3, max(0, e.rangParti))]).foregroundStyle(.secondary) }
            Menu {
                ForEach(PolMoteur.courants) { c in
                    Button("\(c.nom) : \(c.description)") { agir { PolMoteur.changerCourant(c.nom, &$0, &$1) } }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.branch").foregroundStyle(Theme.accent).frame(width: 28)
                    Text("Courant").foregroundStyle(Theme.encre)
                    Spacer()
                    Text(e.courant ?? "Aucun").foregroundStyle(.secondary)
                }
            }
            .disabled(PolMoteur.dejaFaitCetteAnnee("courant", j))
            if e.rangParti < 2 {
                action("Monter dans l'appareil du parti", "Cadre, puis bureau national", "arrow.up.circle.fill", cle: "rang_parti", j, PolMoteur.monterDansLeParti)
            } else if e.rangParti == 2 {
                action("Briguer la tête du parti au congrès", "Influence, loyauté, popularité", "crown.fill", cle: "congres", j, PolMoteur.congres)
            } else {
                Text("Tu diriges le parti : investitures automatiques, caisse du parti, et la responsabilité des défaites.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    func rivaux(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Tes rivaux") {
            ForEach(e.rivaux.sorted { $0.rancune > $1.rancune }) { r in
                let fait = PolMoteur.dejaFaitCetteAnnee("rival_" + r.id.uuidString, j)
                Menu {
                    Button("Déjeuner de réconciliation") { agir { PolMoteur.reconcilier(r.id, &$0, &$1) } }
                    Button("Proposer une alliance") { agir { PolMoteur.allianceRival(r.id, &$0, &$1) } }
                    Button("Sortir un dossier sur lui", role: .destructive) { agir { PolMoteur.attaquerRival(r.id, &$0, &$1) } }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(r.nomComplet).bold().foregroundStyle(Theme.encre)
                            if let p = PolCatalogue.parti(r.partiId) { Text(p.sigle).font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Text(fait ? "Déjà vu cette année" : "Agir").font(.caption).foregroundStyle(fait ? .gray : Theme.accent)
                        }
                        BarreStat(titre: "Rancune", icone: "flame", valeur: 100 - r.rancune)
                        if r.duels > 0 { Text("\(r.duels) duel\(r.duels > 1 ? "s" : "") électora\(r.duels > 1 ? "ux" : "l")").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                .disabled(fait)
            }
        }
    }

    @ViewBuilder
    func equipe(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Ton équipe") {
            ForEach(e.equipe) { m in
                Menu {
                    Button("Verser une prime (+ loyauté)") { agir { PolMoteur.augmenter(m.id, &$0, &$1) } }
                    Button("Renvoyer", role: .destructive) { agir { PolMoteur.renvoyer(m.id, &$0, &$1) } }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: m.role.icone).foregroundStyle(Theme.accent).frame(width: 28)
                            VStack(alignment: .leading) {
                                Text(m.nomComplet).bold().foregroundStyle(Theme.encre)
                                Text("\(m.role.titre) · \(Format.argent(m.salaire))/an").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        BarreStat(titre: "Talent", icone: "star.fill", valeur: m.competence)
                        BarreStat(titre: "Loyauté", icone: "heart.fill", valeur: m.loyaute)
                    }
                }
            }
            ForEach(PolRole.allCases.filter { r in !e.equipe.contains { $0.role == r } }) { r in
                LigneAction(titre: "Recruter : \(r.titre.lowercased())", sousTitre: r.effet, icone: r.icone) {
                    recrutement = r
                }
            }
        }
    }

    @ViewBuilder
    func gouvernement(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Gouverner") {
            let sys = PolMoteur.systeme(j)
            let presidentGouverne = e.mandat?.poste == .president && !sys.presidentSymbolique
            let pmElu = e.mandat?.poste == .premierMinistre && sys.executifParlementaire
            Text(sys.resume).font(.caption).foregroundStyle(.secondary)
            if presidentGouverne && sys.existe(.premierMinistre) {
                if let pm = e.premierMinistrePNJ {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(sys.nom(.premierMinistre, pm.genre)) : \(pm.nomComplet)").bold()
                        Text(PolMoteur.descriptionTrait(pm.trait)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                LigneAction(titre: e.premierMinistrePNJ == nil ? "Nommer le chef du gouvernement" : "Changer de chef du gouvernement",
                            sousTitre: "Trois profils au choix", icone: "person.crop.rectangle.stack.fill",
                            actif: !PolMoteur.dejaFaitCetteAnnee("nommer_pm", j)) {
                    listePM = true
                }
            }
            if presidentGouverne && sys.referendum == true {
                LigneAction(titre: "Organiser un référendum", sousTitre: "Le peuple tranche, et parfois contre toi",
                            icone: "checkmark.square.fill", actif: !PolMoteur.dejaFaitCetteAnnee("referendum", j)) {
                    listeReferendum = true
                }
            }
            if (presidentGouverne || pmElu) && sys.dissolution == true {
                LigneAction(titre: "Provoquer des élections anticipées", sousTitre: e.dissolutionFaite ? "Déjà fait pendant ce mandat" : "Dissoudre \(sys.parlementNom) : quitte ou double",
                            icone: "arrow.triangle.2.circlepath", actif: !e.dissolutionFaite) {
                    agir(PolMoteur.dissoudre)
                }
            }
            if let procedure = sys.passerEnForce,
               e.mandat?.poste == .premierMinistre || (e.mandat?.poste == .president && (e.premierMinistrePNJ != nil || !sys.existe(.premierMinistre))) {
                LigneAction(titre: "Passer une loi en force", sousTitre: "Par \(procedure) : sans vote, mais l'opposition riposte",
                            icone: "bolt.trianglebadge.exclamationmark.fill", actif: !PolMoteur.dejaFaitCetteAnnee("loi", j)) {
                    listeForce = true
                }
            }
        }
    }

    @ViewBuilder
    func apres(_ j: Joueur, _ e: PolEtat) -> some View {
        Section("Ancien élu") {
            LigneAction(titre: "Écrire tes mémoires", sousTitre: e.memoires ? "Déjà publiées" : "Une avance, et des comptes à régler",
                        icone: "book.closed.fill", actif: !e.memoires) {
                agir(PolMoteur.ecrireMemoires)
            }
            action("Donner des conférences payées", "« L'art de décider »", "mic.fill", cle: "conferences", j, PolMoteur.conferences)
            action("Devenir chroniqueur télé", "Commenter l'actualité politique", "tv", cle: "chroniqueur", j, PolMoteur.chroniqueur)
            action("Rejoindre un conseil d'administration", "Jetons de présence et soupçons de pantouflage", "briefcase.circle.fill", cle: "conseil_admin", j, PolMoteur.conseilAdministration)
            LigneAction(titre: "Créer ta fondation", sousTitre: e.fondation ? "Elle existe déjà" : "50 000 €, karma et prestige",
                        icone: "building.fill", actif: !e.fondation && j.argent >= 50_000) {
                agir(PolMoteur.creerFondation)
            }
        }
    }

    func loisNationalesDisponibles(_ e: PolEtat) -> [PolLoi] {
        PolCatalogue.lois.filter { $0.niveau == "national" && !e.loisActives.contains($0.id) }
    }

    func chanceReferendum(_ loi: PolLoi, _ e: PolEtat) -> Int {
        Int(max(0, min(1, PolMoteur.popularitePonderee(e) / 100 * 0.9 + 0.08 - Double(loi.difficulte) / 400)) * 100)
    }
}

// MARK: - Choisir un Premier ministre

struct PolChoixPMView: View {
    @Environment(\.dismiss) private var dismiss
    let candidats: [PolPNJ]
    let nommer: (PolPNJ) -> String
    @State private var message: String?

    init(candidats: [PolPNJ], nommer: @escaping (PolPNJ) -> String) {
        self.candidats = candidats
        self.nommer = nommer
    }

    var body: some View {
        NavigationStack {
            List(candidats) { c in
                Button {
                    message = nommer(c)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.nomComplet).bold().foregroundStyle(Theme.encre)
                        Text(PolMoteur.descriptionTrait(c.trait)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Premier ministre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } } }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil; dismiss() }
            } message: {
                Text(message ?? "")
            }
        }
    }
}

// MARK: - Recruter

struct PolRecrutementView: View {
    @Environment(\.dismiss) private var dismiss
    let role: PolRole
    let candidats: [PolMembre]
    let recruter: (PolMembre) -> String
    @State private var message: String?

    init(role: PolRole, candidats: [PolMembre], recruter: @escaping (PolMembre) -> String) {
        self.role = role
        self.candidats = candidats
        self.recruter = recruter
    }

    var body: some View {
        NavigationStack {
            List {
                Section(role.effet) {
                    ForEach(candidats) { c in
                        Button {
                            message = recruter(c)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.nomComplet).bold().foregroundStyle(Theme.encre)
                                Text("\(Format.argent(c.salaire))/an").font(.caption).foregroundStyle(.secondary)
                                BarreStat(titre: "Talent", icone: "star.fill", valeur: c.competence)
                                BarreStat(titre: "Loyauté", icone: "heart.fill", valeur: c.loyaute)
                            }
                        }
                    }
                }
            }
            .navigationTitle(role.titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } } }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil; dismiss() }
            } message: {
                Text(message ?? "")
            }
        }
    }
}

// MARK: - Fonder un parti

struct PolFonderPartiView: View {
    @Environment(\.dismiss) private var dismiss
    let fonder: (String, String, String, String, String) -> String
    @State private var nom = ""
    @State private var sigle = ""
    @State private var slogan = ""
    @State private var couleur = "#E74C3C"
    @State private var bord = "ailleurs"
    @State private var message: String?

    static let couleurs = ["#E74C3C", "#2E86C1", "#27AE60", "#F1C40F", "#8E44AD", "#E67E22", "#1ABC9C", "#34495E"]
    static let bords = ["gauche", "centre", "droite", "ailleurs"]

    init(fonder: @escaping (String, String, String, String, String) -> String) {
        self.fonder = fonder
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Nom (ex. Mouvement pour la République)", text: $nom)
                    TextField("Sigle (ex. PBSR)", text: $sigle)
                    TextField("Slogan", text: $slogan)
                }
                Section("Couleur") {
                    HStack {
                        ForEach(Self.couleurs, id: \.self) { c in
                            Circle()
                                .fill(Color(polHex: c))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Theme.encre, lineWidth: couleur == c ? 3 : 0))
                                .onTapGesture { couleur = c }
                        }
                    }
                }
                Section("Positionnement") {
                    Picker("Bord", selection: $bord) {
                        ForEach(Self.bords, id: \.self) { b in Text(b.capitalized).tag(b) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button("Déposer les statuts") { message = fonder(nom, sigle, slogan, couleur, bord) }
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty || sigle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Fonder un parti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } } }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil; dismiss() }
            } message: {
                Text(message ?? "")
            }
        }
    }
}

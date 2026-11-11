import SwiftUI

// Écrans « Ton business » (trafic) et « Monter un coup » (casse). Ouverts depuis « Le Milieu ».

/// Exécute une action du module, l'écrit dans le journal et l'affiche.
@MainActor
private struct VieActionMilieu {
    let engine: GameEngine
    let message: Binding<String?>

    func lignes(_ action: (inout Joueur) -> [String]) {
        var texte = ""
        engine.modifier { j in
            let lignes = action(&j).map { VieMilieu.remplir($0, j) }.filter { !$0.isEmpty }
            texte = lignes.joined(separator: " ")
            for l in lignes { engine.ajouterLigne(&j, l) }
        }
        if !texte.isEmpty { message.wrappedValue = texte }
    }

    func texte(_ action: (inout Joueur) -> String) {
        lignes { j in [action(&j)] }
    }

    func silencieux(_ action: (inout Joueur) -> Void) {
        engine.modifier { j in action(&j) }
    }
}

/// Jauge 0…100 dont la couleur dit si c'est bon ou mauvais.
private struct VieJauge: View {
    let titre: String
    let valeur: Int
    var mauvaisSiHaut = true

    var body: some View {
        let danger = mauvaisSiHaut ? valeur : 100 - valeur
        let couleur: Color = danger >= 70 ? .red : (danger >= 40 ? .orange : .green)
        HStack {
            Text(titre).font(.subheadline)
            ProgressView(value: Double(min(100, max(0, valeur))), total: 100).tint(couleur)
            Text("\(valeur)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Ton business

struct VieTraficView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?
    @State private var produitChoisi: String?
    @State private var zoneChoisie: String?
    @State private var confirmerFermeture = false

    @MainActor private var act: VieActionMilieu { VieActionMilieu(engine: engine, message: $message) }

    var body: some View {
        List {
            if let j = engine.joueur {
                if let t = VieMilieu.etat(j).trafic {
                    business(j, t, t.b)
                } else {
                    ouverture(j)
                }
            }
        }
        .navigationTitle("Ton business")
        .vieAlerte($message)
        .confirmationDialog("Fermer le business ?", isPresented: $confirmerFermeture, titleVisibility: .visible) {
            Button("Tout arrêter", role: .destructive) { act.texte { j in MilieuTrafic.fermer(&j) } }
        } message: {
            Text("Tes revendeurs, tes quartiers et ton stock seront perdus.")
        }
    }

    // MARK: Ouverture

    @ViewBuilder
    private func ouverture(_ j: Joueur) -> some View {
        let m = VieMilieu.etat(j)
        Section {
            Text("Choisis ce que tu vends et où. Ensuite, c'est toi qui fixes les prix, choisis tes fournisseurs, recrutes tes revendeurs et décides comment répondre à la concurrence.")
                .font(.subheadline).foregroundStyle(.secondary)
            if !m.membre {
                Text("À ton compte, tu ne peux vendre qu'une marchandise, dans deux quartiers au plus, avec quatre revendeurs. Et les organisations n'aiment pas les indépendants.")
                    .font(.footnote).foregroundStyle(.orange)
            }
        }
        if !MilieuTrafic.peutDealer(j) {
            Section {
                Text(m.balance ? "Tout le monde sait que tu as parlé à la police. Aucun fournisseur ne te vendra quoi que ce soit."
                     : (j.age < 14 ? "Tu es trop jeune." : "Ce n'est pas possible pour le moment."))
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("Marchandise") {
                ForEach(MilieuTrafic.produitsAccessibles(j)) { p in
                    Button { produitChoisi = p.id } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.nom).font(.headline).foregroundStyle(.primary)
                                Text("Achat \(Format.argent(p.prixLot)) le lot · revente \(Format.argent(p.reventeMin)) à \(Format.argent(p.reventeMax))")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("Peine encourue : \(VieCrime.dureeTexte(p.peineMinMois)) à \(VieCrime.dureeTexte(p.peineMaxMois))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if produitChoisi == p.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        }
                    }
                }
            }
            Section("Quartier") {
                ForEach(MilieuTrafic.zonesAccessibles(j)) { z in
                    Button { zoneChoisie = z.id } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(capitale(z.nom)).font(.headline).foregroundStyle(.primary)
                                Text(z.clientele).font(.caption).foregroundStyle(.secondary)
                                Text("Police : \(niveau(z.police)) · installation \(Format.argent(z.entree))").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if zoneChoisie == z.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        }
                    }
                }
            }
            Section {
                Button("Monter le business") {
                    guard let p = MilieuDonnees.produit(produitChoisi), let z = TraficDonnees.zone(zoneChoisie) else { return }
                    act.lignes { j in MilieuTrafic.ouvrir(p, z, &j) }
                }
                .disabled(produitChoisi == nil || zoneChoisie == nil)
            }
        }
    }

    private func niveau(_ police: Int) -> String {
        switch police {
        case ..<30: return "faible"
        case ..<55: return "moyenne"
        case ..<70: return "forte"
        default: return "très forte"
        }
    }

    // MARK: Business

    @ViewBuilder
    private func business(_ j: Joueur, _ t: VieTrafic, _ b: TraficBusiness) -> some View {
        let enPrison = j.vieEtat.justice.enPrison
        if let d = b.decision {
            Section("À décider") {
                Text(TraficDecisions.titre(d)).font(.headline)
                Text(TraficDecisions.texte(d)).font(.subheadline)
                let options = TraficDecisions.options(d)
                ForEach(options.indices, id: \.self) { i in
                    Button { act.lignes { j in TraficDecisions.repondre(i, &j) } } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(options[i].label).font(.body.weight(.semibold))
                            Text(options[i].detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        Section("Bilan de l'an dernier") {
            if let bi = b.bilan {
                ligne("Lots vendus", "\(bi.lotsVendus)")
                ligne("Demande dans tes quartiers", "≈ \(bi.demande) lots")
                ligne("Capacité de ton réseau", "≈ \(bi.capacite) lots")
                ligne("Chiffre d'affaires", Format.argent(bi.chiffre))
                ligne("Revendeurs (fixe et commissions)", "− " + Format.argent(bi.salaires))
                if bi.securite > 0 { ligne("Sécurité", "− " + Format.argent(bi.securite)) }
                HStack {
                    Text("Bénéfice").bold()
                    Spacer()
                    Text(Format.argent(bi.benefice)).bold().foregroundStyle(bi.benefice >= 0 ? .green : .red)
                }
            } else {
                Text("Premier bilan à la fin de l'année.").foregroundStyle(.secondary)
            }
        }

        Section("Clients et réseau") {
            VieJauge(titre: "Fidélité", valeur: b.fidelite, mauvaisSiHaut: false)
            HStack { Text("Revendeurs"); Spacer(); Text("\(t.reseau) / \(MilieuTrafic.maxReseau(j))").foregroundStyle(.secondary) }
            LigneAction(titre: "Recruter un revendeur", sousTitre: Format.argent(1_500 + 1_000 * t.reseau) + " · puis \(Format.argent(MilieuTrafic.salaireRevendeur)) par an et \(MilieuTrafic.commission) % des ventes",
                        icone: "person.badge.plus", actif: !enPrison && t.reseau < MilieuTrafic.maxReseau(j)) {
                act.texte { j in MilieuTrafic.recruter(&j) }
            }
            if t.reseau > 0 {
                LigneAction(titre: "Se séparer d'un revendeur", icone: "person.badge.minus") {
                    act.texte { j in MilieuTrafic.licencier(&j) }
                }
            }
            Picker("Sécurité", selection: Binding(get: { b.securite }, set: { v in act.silencieux { j in MilieuTrafic.choisirSecurite(v, &j) } })) {
                Text("Aucune").tag(0)
                Text("Quelques guetteurs").tag(1)
                Text("Guetteurs et planques").tag(2)
                Text("Organisation complète").tag(3)
            }
            if b.securite > 0 {
                Text("\(Format.argent(b.securite * MilieuTrafic.coutSecurite * b.zones.count)) par an. Moins d'arrestations, moins d'attention.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker("Stratégie", selection: Binding(get: { b.strategie }, set: { v in act.silencieux { j in MilieuTrafic.choisirStrategie(v, &j) } })) {
                ForEach(TraficStrategie.allCases) { s in Text(s.nom).tag(s) }
            }
            Text(b.strategie.detail).font(.caption).foregroundStyle(.secondary)
        }

        Section("Marchandises (\(b.lignes.count)/\(MilieuTrafic.maxLignes(j)))") {
            ForEach(b.lignes) { l in
                if let p = MilieuDonnees.produit(l.produitId) {
                    marchandise(j, b, l, p, enPrison: enPrison)
                }
            }
            if b.lignes.count < MilieuTrafic.maxLignes(j) {
                let autres = MilieuTrafic.produitsAccessibles(j)
                if !autres.isEmpty {
                    DisclosureGroup("Ajouter une marchandise") {
                        ForEach(autres) { p in
                            LigneAction(titre: p.nom, sousTitre: "Achat \(Format.argent(p.prixLot)) le lot", icone: "plus.circle") {
                                act.texte { j in MilieuTrafic.ajouterProduit(p, &j) }
                            }
                        }
                    }
                }
            }
        }

        Section("Quartiers (\(b.zones.count)/\(MilieuTrafic.maxZones(j)))") {
            ForEach(b.zones) { ze in
                if let z = TraficDonnees.zone(ze.zoneId) {
                    quartier(j, b, ze, z, enPrison: enPrison)
                }
            }
            if b.zones.count < MilieuTrafic.maxZones(j) {
                let autres = MilieuTrafic.zonesAccessibles(j)
                if !autres.isEmpty {
                    DisclosureGroup("S'installer dans un autre quartier") {
                        ForEach(autres) { z in
                            LigneAction(titre: capitale(z.nom), sousTitre: "\(z.clientele) · \(Format.argent(z.entree))", icone: "mappin.and.ellipse", actif: !enPrison) {
                                act.lignes { j in MilieuTrafic.ouvrirZone(z, &j) }
                            }
                        }
                    }
                }
            }
        }

        Section {
            Button("Fermer le business", role: .destructive) { confirmerFermeture = true }
        }
    }

    private func ligne(_ titre: String, _ valeur: String) -> some View {
        HStack { Text(titre); Spacer(); Text(valeur).foregroundStyle(.secondary) }
    }

    @ViewBuilder
    private func marchandise(_ j: Joueur, _ b: TraficBusiness, _ l: VieLigneTrafic, _ p: MilieuProduit, enPrison: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(p.nom).font(.headline)
                Spacer()
                Text("\(l.stock) lot\(l.stock > 1 ? "s" : "") en stock").font(.subheadline).foregroundStyle(l.stock == 0 ? .red : .secondary)
            }
            let cours = b.coursDe(p.id)
            Text("Prix du marché : \(Format.argent(MilieuTrafic.prixMarche(p, b))) le lot (\(cours >= 0 ? "+" : "")\(cours) %) · vendus l'an dernier : \(l.vendus)")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Ton prix", selection: Binding(get: { l.prix }, set: { v in act.silencieux { j in MilieuTrafic.fixerPrix(l.produitId, v, &j) } })) {
                ForEach(TraficPrix.niveaux, id: \.self) { n in Text(TraficPrix.nom(n)).tag(n) }
            }
            Picker("Fournisseur", selection: Binding(get: { l.qualite }, set: { v in
                var erreur: String?
                act.silencieux { j in erreur = MilieuTrafic.choisirQualite(l.produitId, v, &j) }
                if let erreur { message = erreur }
            })) {
                ForEach(TraficQualite.allCases) { q in Text(q.nom).tag(q) }
            }
            Text(l.qualite.detail).font(.caption2).foregroundStyle(.secondary)
            let prix = MilieuTrafic.prixAchat(p, l.qualite, b)
            HStack {
                Button("1 lot · \(Format.argent(prix))") { act.texte { j in MilieuTrafic.acheter(l.produitId, lots: 1, &j) } }
                Button("5 lots · \(Format.argent(prix * 5))") { act.texte { j in MilieuTrafic.acheter(l.produitId, lots: 5, &j) } }
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(enPrison)
            if b.lignes.count > 1 {
                Button("Arrêter cette marchandise") { act.texte { j in MilieuTrafic.retirerProduit(l.produitId, &j) } }
                    .buttonStyle(.borderless).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func quartier(_ j: Joueur, _ b: TraficBusiness, _ ze: VieZoneTrafic, _ z: MilieuZone, enPrison: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(capitale(z.nom)).font(.headline)
                Spacer()
                Text("Part de marché \(ze.part) %").font(.caption).foregroundStyle(.secondary)
            }
            Text("\(z.clientele) · police \(niveau(z.police))").font(.caption).foregroundStyle(.secondary)
            if let c = TraficDonnees.concurrent(ze.concurrentId) {
                Text("Concurrent : \(capitale(c.nom)) (\(c.styleTexte.lowercased()))").font(.subheadline)
                Text("Ses prix : \(ze.prixConcurrent >= 0 ? "+" : "")\(ze.prixConcurrent) % par rapport au marché").font(.caption).foregroundStyle(.secondary)
                VieJauge(titre: "Sa force", valeur: ze.forceConcurrent)
                if ze.treve > 0 {
                    Label("Trêve encore \(ze.treve) an\(ze.treve > 1 ? "s" : "")", systemImage: "hand.raised.fill").font(.caption).foregroundStyle(.green)
                } else {
                    VieJauge(titre: "Tension", valeur: ze.tension)
                }
                HStack {
                    Button("Négocier") { act.texte { j in MilieuTrafic.negocier(ze.zoneId, &j) } }
                    Button("Intimider") { act.lignes { j in MilieuTrafic.intimider(ze.zoneId, &j) } }
                    if ze.forceConcurrent <= 40 {
                        Button("Racheter · \(Format.argent(MilieuTrafic.coutRachat(ze)))") { act.texte { j in MilieuTrafic.racheter(ze.zoneId, &j) } }
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(enPrison)
            } else {
                Text("Aucun concurrent installé. Le quartier est à toi.").font(.caption).foregroundStyle(.green)
            }
            if b.zones.count > 1 {
                Button("Quitter ce quartier") { act.texte { j in MilieuTrafic.quitterZone(ze.zoneId, &j) } }
                    .buttonStyle(.borderless).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Monter un coup

struct VieCoupView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?
    @State private var confirmer = false

    @MainActor private var act: VieActionMilieu { VieActionMilieu(engine: engine, message: $message) }

    var body: some View {
        List {
            if let j = engine.joueur {
                if let co = MilieuCoups.coup(j), let c = MilieuCoups.cible(co.cibleId) {
                    preparation(j, co, c)
                } else {
                    cibles(j)
                }
            }
        }
        .navigationTitle("Monter un coup")
        .vieAlerte($message)
        .confirmationDialog("Passer à l'acte ?", isPresented: $confirmer, titleVisibility: .visible) {
            Button("C'est parti", role: .destructive) { act.lignes { j in MilieuCoups.executer(&j) } }
        } message: {
            Text("Il n'y aura pas de deuxième chance.")
        }
    }

    @ViewBuilder
    private func cibles(_ j: Joueur) -> some View {
        Section {
            Text("Un casse se prépare : une cible, une équipe, des repérages, un plan. Chaque détail négligé se paie.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        if !MilieuCoups.peutPreparer(j) {
            Section { Text(j.age < 16 ? "Tu es trop jeune." : "Ce n'est pas possible pour le moment.").foregroundStyle(.secondary) }
        } else {
            let liste = MilieuCoups.ciblesAccessibles(j)
            Section("Cibles") {
                if liste.isEmpty {
                    Text("Personne ne te prend encore au sérieux. Fais-toi un nom d'abord.").foregroundStyle(.secondary)
                }
                ForEach(liste) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(c.nom, systemImage: c.icon ?? "scope").font(.headline)
                        Text(c.description).font(.subheadline)
                        Text("Butin : \(Format.argent(c.butinMin)) à \(Format.argent(c.butinMax))").font(.caption).foregroundStyle(.secondary)
                        Text("Équipe : \(c.roles.map { CoupRole.nom($0).lowercased() }.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Text("Difficulté").font(.caption).foregroundStyle(.secondary)
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < c.difficulte * 5 ? "flame.fill" : "flame")
                                    .font(.caption2).foregroundStyle(Double(i) < c.difficulte * 5 ? Color.red : Color.gray)
                            }
                        }
                        Button("Préparer ce coup") { act.texte { j in MilieuCoups.choisir(c, &j) } }
                            .buttonStyle(.bordered).tint(Theme.accent)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func preparation(_ j: Joueur, _ co: VieCoupEnCours, _ c: MilieuCible) -> some View {
        Section(c.nom) {
            Text(c.description).font(.subheadline)
            HStack { Text("Butin possible"); Spacer(); Text("\(Format.argent(c.butinMin)) à \(Format.argent(c.butinMax))").foregroundStyle(.secondary) }
            if co.annees > 0 {
                Text("En préparation depuis \(co.annees) an\(co.annees > 1 ? "s" : ""). Plus ça dure, plus ça risque de fuiter.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        Section("Équipe") {
            ForEach(c.roles, id: \.self) { r in
                VStack(alignment: .leading, spacing: 6) {
                    Label(CoupRole.nom(r), systemImage: CoupRole.icone(r)).font(.headline)
                    if let e = co.equipe.first(where: { $0.role == r }) {
                        Text("\(e.nom) · talent \(e.talent) · fiabilité \(e.fiabilite) · \(e.part) % du butin")
                            .font(.subheadline).foregroundStyle(.green)
                    }
                    ForEach(co.candidats.filter { $0.role == r && !co.equipe.contains($0) }) { e in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(e.nom).font(.subheadline)
                                Text("Talent \(e.talent) · fiabilité \(e.fiabilite) · \(e.part) %").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Engager") { act.texte { j in MilieuCoups.recruter(e, &j) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        Section("Repérages (\(co.reperages)/3)") {
            LigneAction(titre: "Faire un repérage", sousTitre: Format.argent(c.reperageCout), icone: "binoculars.fill", actif: co.reperages < 3) {
                act.texte { j in MilieuCoups.reperer(&j) }
            }
        }
        Section("Plan") {
            Picker("Plan", selection: Binding(get: { co.plan }, set: { v in act.silencieux { j in MilieuCoups.choisirPlan(v, &j) } })) {
                ForEach(CoupPlan.allCases) { p in Text(p.nom).tag(p) }
            }
            .pickerStyle(.segmented)
            Text(co.plan.detail).font(.caption).foregroundStyle(.secondary)
        }
        Section("Le jour J") {
            let manquants = MilieuCoups.rolesManquants(co)
            let parts = co.equipe.reduce(0) { $0 + $1.part }
            HStack { Text("Tes chances"); Spacer(); Text(MilieuCoups.chanceTexte(MilieuCoups.chance(co, j))).foregroundStyle(.secondary) }
            HStack { Text("Part de l'équipe"); Spacer(); Text("\(parts) %").foregroundStyle(.secondary) }
            if !manquants.isEmpty {
                Text("Il manque : \(manquants.map { CoupRole.nom($0).lowercased() }.joined(separator: ", ")).").font(.caption).foregroundStyle(.orange)
            }
            Button("Passer à l'acte") { confirmer = true }
                .disabled(!manquants.isEmpty || j.vieEtat.justice.enPrison)
            Button("Abandonner le projet", role: .destructive) { act.texte { j in MilieuCoups.abandonner(&j) } }
        }
    }
}

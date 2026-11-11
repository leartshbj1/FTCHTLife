import SwiftUI

// Écrans « Protection et enquête », « Blanchiment et commerces », « International ».

// MARK: - Protection et enquête

struct VieProtectionView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    @MainActor private var act: VieActionMilieu { VieActionMilieu(engine: engine, message: $message) }

    var body: some View {
        List {
            if let j = engine.joueur {
                contenu(j)
            }
        }
        .navigationTitle("Protection")
        .vieToast($message)
    }

    @ViewBuilder
    private func contenu(_ j: Joueur) -> some View {
        let m = VieMilieu.etat(j)
        let p = MilieuProtection.etat(j)
        let enPrison = j.vieEtat.justice.enPrison

        if p.recherche {
            Section("En fuite") {
                Text("Tu vis à l'étranger sous un faux nom. Un mandat d'arrêt international porte ton nom : chaque année, Interpol peut te retrouver.")
                    .font(.subheadline)
                Button("Te rendre aux autorités", role: .destructive) { act.lignes { j in MilieuEnquete.seRendre(&j) } }
            }
        }

        Section("Surveillance") {
            VieJauge(titre: "Attention de la police", valeur: m.chaleur)
            let explications = MilieuProtection.explications(j)
            ForEach(explications.indices, id: \.self) { i in
                let x = explications[i]
                HStack {
                    Text(x.0).font(.caption)
                    Spacer()
                    Text(x.1 > 0 ? "+\(x.1)" : "\(x.1)").font(.caption.monospacedDigit()).foregroundStyle(x.1 > 0 ? .red : .green)
                }
            }
            HStack {
                Text("Risque d'arrestation cette année")
                Spacer()
                Text("\(Int(MilieuProtection.risqueAnnuel(j) * 100)) %").foregroundStyle(.secondary)
            }
        }

        Section("Enquête") {
            if let e = MilieuEnquete.etape(j) {
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule().fill(i <= e ? Color.red : Color.gray.opacity(0.3)).frame(height: 6)
                    }
                }
                Text(MilieuEnquete.titre(e)).font(.headline)
                Text(MilieuEnquete.description(e)).font(.subheadline)
                if MilieuEnquete.peutReagir(j) {
                    let reactions = MilieuEnquete.reactions(e, j)
                    ForEach(reactions.indices, id: \.self) { i in
                        Button { act.lignes { j in MilieuEnquete.reagir(i, &j) } } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reactions[i].label).font(.body.weight(.semibold))
                                Text(reactions[i].detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text(enPrison ? "Depuis ta cellule, tu ne peux rien faire." : "Tu as déjà réagi cette année.").font(.caption).foregroundStyle(.secondary)
                }
                LigneAction(titre: "Faire disparaître des preuves", sousTitre: Format.argent(MilieuProtection.coutPreuves), icone: "flame.fill", actif: !enPrison) {
                    act.texte { j in MilieuProtection.detruirePreuves(&j) }
                }
            } else {
                Text("Aucune enquête connue contre toi. Pour l'instant.").foregroundStyle(.secondary)
            }
        }

        Section("Défense") {
            Picker("Avocat", selection: Binding(get: { p.avocat }, set: { v in act.texte { j in MilieuProtection.choisirAvocat(v, &j) } })) {
                Text("Aucun").tag(0)
                Text("Sérieux · \(Format.argent(MilieuProtection.coutAvocat(1)))/an").tag(1)
                Text("Ténor · \(Format.argent(MilieuProtection.coutAvocat(2)))/an").tag(2)
            }
            compteur("Policiers payés", p.policiers, MilieuProtection.maxPoliciers, cout: MilieuProtection.coutPolicier(j),
                     plus: { act.lignes { j in MilieuProtection.recruterPolicier(&j) } },
                     moins: { act.texte { j in MilieuProtection.lacherPolicier(&j) } })
            if MilieuInternational.accessible(j) || p.douaniers > 0 {
                compteur("Douaniers payés", p.douaniers, MilieuProtection.maxDouaniers, cout: MilieuProtection.coutDouanier,
                         plus: { act.texte { j in MilieuProtection.recruterDouanier(&j) } },
                         moins: { act.texte { j in MilieuProtection.lacherDouanier(&j) } })
            }
            if p.juge {
                LigneAction(titre: "Un juge te protège", sousTitre: "\(Format.argent(MilieuProtection.coutJuge))/an · ne plus le payer", icone: "building.columns.fill") {
                    act.texte { j in MilieuProtection.lacherJuge(&j) }
                }
            } else if MilieuProtection.peutAcheterJuge(j) {
                LigneAction(titre: "Acheter un juge", sousTitre: "\(Format.argent(MilieuProtection.coutJuge))/an · peut mal tourner", icone: "building.columns", actif: !enPrison) {
                    act.lignes { j in MilieuProtection.acheterJuge(&j) }
                }
            }
        }

        Section("Discrétion") {
            Toggle(isOn: Binding(get: { p.comptable }, set: { _ in act.texte { j in MilieuProtection.basculerComptable(&j) } })) {
                VStack(alignment: .leading) {
                    Text("Comptable")
                    Text("\(Format.argent(MilieuProtection.coutComptable))/an · blanchiment moins cher, argent mis à l'abri").font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { p.preteNom }, set: { _ in act.texte { j in MilieuProtection.basculerPreteNom(&j) } })) {
                VStack(alignment: .leading) {
                    Text("Prête-nom")
                    Text("\(Format.argent(MilieuProtection.coutPreteNom))/an · moins d'enquêtes, moins de contrôles fiscaux").font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { p.jetables }, set: { _ in act.texte { j in MilieuProtection.basculerJetables(&j) } })) {
                VStack(alignment: .leading) {
                    Text("Téléphones jetables")
                    Text("\(Format.argent(MilieuProtection.coutJetables))/an · contre les écoutes").font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { p.profilBas }, set: { _ in act.texte { j in MilieuProtection.basculerProfilBas(&j) } })) {
                VStack(alignment: .leading) {
                    Text("Profil bas cette année")
                    Text("Beaucoup moins de ventes, beaucoup moins d'attention").font(.caption).foregroundStyle(.secondary)
                }
            }
        }

        Section {
            HStack {
                Text("Coût de ta protection").bold()
                Spacer()
                Text("\(Format.argent(MilieuProtection.coutAnnuel(j))) par an").foregroundStyle(.secondary)
            }
        }
    }

    private func compteur(_ titre: String, _ n: Int, _ limite: Int, cout: Int, plus: @escaping @MainActor () -> Void, moins: @escaping @MainActor () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(titre) : \(n)/\(limite)")
                Text("\(Format.argent(cout)) par an chacun").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { moins() } label: { Image(systemName: "minus.circle.fill").font(.title2) }
                .buttonStyle(.borderless).disabled(n == 0)
            Button { plus() } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                .buttonStyle(.borderless).disabled(n >= limite)
        }
    }
}

// MARK: - Blanchiment et commerces de façade

struct VieBlanchimentView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    @MainActor private var act: VieActionMilieu { VieActionMilieu(engine: engine, message: $message) }

    var body: some View {
        List {
            if let j = engine.joueur {
                contenu(j)
            }
        }
        .navigationTitle("Blanchiment")
        .vieToast($message)
    }

    @ViewBuilder
    private func contenu(_ j: Joueur) -> some View {
        let m = VieMilieu.etat(j)
        let commission = (m.rang >= 3 ? 15 : 30) - (MilieuProtection.etat(j).comptable ? 10 : 0)
        let possedees = MilieuFacades.possedees(j)
        Section("Argent sale : \(Format.argent(m.argentSale))") {
            if !possedees.isEmpty {
                LigneAction(titre: "Blanchir par tes commerces", sousTitre: "Encore \(Format.argent(MilieuFacades.capaciteRestante(j))) cette année · commission \(MilieuFacades.commission(j)) %",
                            icone: "building.2.fill", actif: m.argentSale > 0 && MilieuFacades.capaciteRestante(j) > 0) {
                    act.texte { j in MilieuFacades.blanchir(&j) }
                }
            }
            LigneAction(titre: "Tout blanchir par le réseau", sousTitre: "Commission de \(commission) %, sans limite", icone: "arrow.triangle.2.circlepath", actif: m.argentSale > 0) {
                act.texte { j in VieMilieu.blanchir(VieMilieu.etat(j).argentSale, &j) }
            }
            HStack {
                Text("Risque de contrôle fiscal")
                Spacer()
                Text("\(Int(MilieuFacades.risqueControle(j) * 100)) %").foregroundStyle(.secondary)
            }
            Text("Blanchir plus que ce que tes commerces peuvent justifier fait monter le risque de contrôle fiscal.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Tes commerces") {
            if possedees.isEmpty {
                Text("Aucun. Un commerce de façade blanchit ton argent pour presque rien, tant que ses recettes restent crédibles.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(possedees) { f in
                VStack(alignment: .leading, spacing: 4) {
                    Text(f.nom).font(.headline)
                    Text("Blanchit jusqu'à \(Format.argent(f.capacite)) par an · rapporte \(Format.argent(f.revenu)) légalement").font(.caption).foregroundStyle(.secondary)
                    Button("Revendre") { act.texte { j in MilieuFacades.vendre(f.id, &j) } }
                        .buttonStyle(.borderless).font(.caption).foregroundStyle(.red)
                }
            }
        }
        Section("Racheter un commerce") {
            ForEach(MilieuFacades.accessibles(j)) { f in
                LigneAction(titre: f.nom, sousTitre: "\(Format.argent(f.prix)) · blanchit \(Format.argent(f.capacite))/an", icone: "storefront.fill",
                            actif: !j.vieEtat.justice.enPrison) {
                    act.texte { j in MilieuFacades.acheter(f, &j) }
                }
            }
        }
    }
}

// MARK: - International

struct VieInternationalView: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        List {
            if let j = engine.joueur {
                let e = MilieuInternational.etat(j)
                Section {
                    Text("Acheter à la source coûte bien moins cher. Vendre à l'étranger rapporte bien plus. Mais les cargaisons mettent un an à arriver, les douanes veillent, et tes partenaires n'oublient jamais une dette.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack { Text("Cargaisons livrées"); Spacer(); Text("\(e.livrees)").foregroundStyle(.secondary) }
                    HStack { Text("Cargaisons saisies"); Spacer(); Text("\(e.saisies)").foregroundStyle(.secondary) }
                }
                if !e.cargaisons.isEmpty {
                    Section("En route") {
                        ForEach(e.cargaisons) { c in
                            if let r = MilieuInternational.route(c.routeId), let p = MilieuDonnees.produit(c.produitId) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(c.lots) lot\(c.lots > 1 ? "s" : "") de \(p.nom.lowercased())").font(.subheadline)
                                    Text("\(r.estImport ? "Depuis" : "Vers") \(r.region) · \(c.mode.nom.lowercased()) · arrive l'an prochain").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                let routes = MilieuInternational.routesAccessibles(j)
                Section("Importer") {
                    ForEach(routes.filter { $0.estImport }) { r in lien(r, e) }
                }
                Section("Exporter") {
                    ForEach(routes.filter { !$0.estImport }) { r in lien(r, e) }
                }
            }
        }
        .navigationTitle("International")
    }

    private func lien(_ r: MilieuRoute, _ e: VieInternationalEtat) -> some View {
        NavigationLink { VieRouteView(routeId: r.id) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.nom).font(.headline)
                Text("\(capitale(r.partenaire)) · \(r.region)").font(.caption).foregroundStyle(.secondary)
                Text("Confiance \(MilieuInternational.confiance(r.id, e))/100 · \(r.produits.compactMap { MilieuDonnees.produit($0)?.nom.lowercased() }.joined(separator: ", "))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

struct VieRouteView: View {
    let routeId: String
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?
    @State private var produitId: String?
    @State private var lots = 0
    @State private var mode: TransportMode = .port

    @MainActor private var act: VieActionMilieu { VieActionMilieu(engine: engine, message: $message) }

    var body: some View {
        List {
            if let j = engine.joueur, let r = MilieuInternational.route(routeId) {
                contenu(j, r)
            }
        }
        .navigationTitle(MilieuInternational.route(routeId)?.region ?? "Route")
        .vieToast($message)
    }

    @ViewBuilder
    private func contenu(_ j: Joueur, _ r: MilieuRoute) -> some View {
        let e = MilieuInternational.etat(j)
        let pid = produitId ?? r.produits.first ?? ""
        let maxL = MilieuInternational.maxLots(r, j)
        let n = lots == 0 ? r.minLots : min(max(lots, r.minLots), maxL)
        Section(r.nom) {
            Text(r.description).font(.subheadline)
            HStack { Text("Partenaire"); Spacer(); Text(capitale(r.partenaire)).foregroundStyle(.secondary) }
            VieJauge(titre: "Confiance", valeur: MilieuInternational.confiance(r.id, e), mauvaisSiHaut: false)
        }
        Section(r.estImport ? "Commande" : "Envoi") {
            if r.produits.count > 1 {
                Picker("Marchandise", selection: Binding(get: { pid }, set: { produitId = $0 })) {
                    ForEach(r.produits, id: \.self) { id in Text(MilieuDonnees.produit(id)?.nom ?? id).tag(id) }
                }
            }
            Stepper("\(n) lot\(n > 1 ? "s" : "") (de \(r.minLots) à \(maxL))", value: Binding(get: { n }, set: { lots = $0 }), in: r.minLots...max(r.minLots, maxL))
            Picker("Transport", selection: $mode) {
                ForEach(TransportMode.allCases) { m in Text(m.nom).tag(m) }
            }
            .pickerStyle(.segmented)
            Text(mode.detail).font(.caption).foregroundStyle(.secondary)
            if let p = MilieuDonnees.produit(pid) {
                let prix = MilieuInternational.prixLot(r, p, j)
                let transport = MilieuInternational.coutTransport(r, mode)
                if r.estImport {
                    HStack { Text("Prix du lot"); Spacer(); Text("\(Format.argent(prix)) (ici : \(Format.argent(p.prixLot)))").foregroundStyle(.secondary) }
                    HStack { Text("Total, transport compris").bold(); Spacer(); Text(Format.argent(prix * n + transport)).bold() }
                } else {
                    let stock = MilieuTrafic.business(j)?.lignes.first(where: { $0.produitId == pid })?.stock ?? 0
                    HStack { Text("Ton stock"); Spacer(); Text("\(stock) lot\(stock > 1 ? "s" : "")").foregroundStyle(stock == 0 ? .red : .secondary) }
                    HStack { Text("Payé par lot"); Spacer(); Text("\(Format.argent(prix)) (ici : \(Format.argent(MilieuTrafic.prixMarche(p, MilieuTrafic.business(j) ?? TraficBusiness()))))").foregroundStyle(.secondary) }
                    HStack { Text("Transport"); Spacer(); Text(Format.argent(transport)).foregroundStyle(.secondary) }
                }
                HStack {
                    Text("Risque de saisie")
                    Spacer()
                    Text("\(Int(MilieuInternational.risque(r, mode, lots: n, j) * 100)) %").foregroundStyle(.secondary)
                }
                Button(r.estImport ? "Passer commande" : "Envoyer la cargaison") {
                    act.texte { j in MilieuInternational.envoyer(r, produitId: pid, lots: n, mode: mode, &j) }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(j.vieEtat.justice.enPrison || e.cargaisons.count >= MilieuInternational.maxCargaisons)
            }
        }
    }
}

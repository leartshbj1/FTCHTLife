import SwiftUI
import UIKit

// MARK: - Racine

/// Écran racine de la boutique, à ouvrir dans une feuille avec `GameEngine` en environmentObject.
struct ShopView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var evenement: PendingShopEvent?

    var body: some View {
        NavigationStack {
            Group {
                if let j = engine.joueur {
                    contenu(j)
                } else {
                    Text("Aucune vie en cours.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Boutique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $evenement) { ev in
                ShopEventSheet(evenement: ev)
                    .environmentObject(engine)
            }
            .onAppear {
                if let j = engine.joueur, j.boutique.marketAge != j.age {
                    engine.modifier { ShopEngine.refreshMarketIfNeeded(&$0) }
                }
            }
        }
        .tint(Theme.accent)
    }

    @ViewBuilder
    private func contenu(_ j: Joueur) -> some View {
        let b = j.boutique
        List {
            Section {
                ShopInfoRow(titre: "Compte en banque", valeur: Format.argent(j.argent), icone: "banknote.fill")
                ShopInfoRow(titre: "Logement", valeur: ShopEngine.residenceName(b), icone: "house.fill")
                ShopInfoRow(titre: "Valeur de tes biens", valeur: Format.argent(b.assetsValue), icone: "chart.line.uptrend.xyaxis")
                if b.debt > 0 {
                    ShopInfoRow(titre: "Crédits restants", valeur: Format.argent(b.debt), icone: "creditcard.fill")
                }
                ShopInfoRow(titre: "Score de crédit", valeur: "\(b.creditScore)", icone: "gauge.medium")
            }

            if let id = MemoireQuantites.texte("boutique.dernierArticle"), let dernier = ShopCatalog.shared.item(id) {
                Section("Comme la dernière fois") {
                    NavigationLink {
                        ShopItemDetailView(item: dernier, listing: nil)
                    } label: {
                        Label("Racheter : \(dernier.name)", systemImage: "arrow.clockwise")
                    }
                }
            }

            if !b.pendingEvents.isEmpty {
                Section("À régler") {
                    ForEach(b.pendingEvents) { ev in
                        Button {
                            evenement = ev
                        } label: {
                            Label(ev.text, systemImage: "exclamationmark.bubble.fill")
                                .foregroundStyle(Theme.encre)
                                .lineLimit(2)
                        }
                    }
                }
            }

            Section("Chez toi") {
                NavigationLink {
                    ShopOwnedListView()
                } label: {
                    Label("Mes biens (\(b.items.count))", systemImage: "archivebox.fill")
                }
                NavigationLink {
                    ShopHousingView()
                } label: {
                    Label("Logement et location", systemImage: "key.fill")
                }
                NavigationLink {
                    ShopTravelView()
                } label: {
                    Label("Agence de voyages", systemImage: "airplane.departure")
                }
                NavigationLink {
                    VoyagesListe()
                } label: {
                    Label("Voyage sur mesure", systemImage: "suitcase.rolling.fill")
                }
            }

            Section("Magasins") {
                ForEach(ShopCategory.allCases) { cat in
                    NavigationLink {
                        ShopCategoryView(category: cat)
                    } label: {
                        HStack {
                            Label(cat.title, systemImage: cat.icon)
                            Spacer()
                            Text("\(ShopCatalog.shared.items(in: cat).count)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct ShopInfoRow: View {
    let titre: String
    let valeur: String
    let icone: String

    var body: some View {
        HStack {
            Label(titre, systemImage: icone)
            Spacer()
            Text(valeur).fontWeight(.semibold).monospacedDigit().multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Une catégorie de magasin

struct ShopCategoryView: View {
    @EnvironmentObject var engine: GameEngine
    let category: ShopCategory
    @State private var occasion = false
    @State private var sousCategorie: String?

    var body: some View {
        let catalog = ShopCatalog.shared
        let argent = engine.joueur?.argent ?? 0
        List {
            Section {
                Picker("Marché", selection: $occasion) {
                    Text("Neuf").tag(false)
                    Text("Occasion").tag(true)
                }
                .pickerStyle(.segmented)
                let subs = catalog.subcategories(in: category)
                if subs.count > 1 {
                    Picker("Type", selection: $sousCategorie) {
                        Text("Tout").tag(String?.none)
                        ForEach(subs, id: \.self) { s in
                            Text(s.capitalized).tag(String?.some(s))
                        }
                    }
                }
            }

            if occasion {
                let annonces = ShopEngine.usedListings(in: category, engine.joueur?.boutique ?? Possessions())
                    .filter { l in sousCategorie == nil || catalog.item(l.catalogId)?.subcategory == sousCategorie }
                Section("Petites annonces de l'année") {
                    if annonces.isEmpty {
                        Text("Aucune annonce cette année. Reviens l'an prochain.").foregroundStyle(.secondary)
                    }
                    ForEach(annonces) { l in
                        if let item = catalog.item(l.catalogId) {
                            NavigationLink {
                                ShopItemDetailView(item: item, listing: l)
                            } label: {
                                ShopItemRow(item: item, prix: l.price, etat: l.condition, abordable: ShopHooks.canAfford(l.price, argent))
                            }
                        }
                    }
                }
            } else {
                let items = catalog.items(in: category).filter { sousCategorie == nil || $0.subcategory == sousCategorie }
                Section {
                    ForEach(items) { item in
                        NavigationLink {
                            ShopItemDetailView(item: item, listing: nil)
                        } label: {
                            ShopItemRow(item: item, prix: ShopEngine.currentPrice(item), etat: nil, abordable: ShopHooks.canAfford(ShopEngine.currentPrice(item), argent))
                        }
                    }
                }
            }
        }
        .navigationTitle(category.title)
    }
}

struct ShopItemRow: View {
    let item: ShopItem
    let prix: Int
    let etat: Int?
    let abordable: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: shopSymbol(item.icon, item.category.icon))
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body.weight(.semibold)).foregroundStyle(Theme.encre)
                HStack(spacing: 6) {
                    if !item.brand.isEmpty { Text(item.brand) }
                    if let city = item.city { Text(city) }
                    if let etat { Text("État \(etat) %") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.argent(prix))
                .font(.callout.weight(.bold)).monospacedDigit()
                .foregroundStyle(abordable ? Theme.encre : .red)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Fiche produit

struct ShopItemDetailView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let item: ShopItem
    let listing: ShopListing?
    @State private var message: String?
    @State private var achatReussi = false
    /// Nombre d'exemplaires à acheter cash (objets neufs seulement ; une occasion est unique).
    @State private var quantite = 1

    private var prix: Int { listing?.price ?? ShopEngine.currentPrice(item) }

    private var cleQuantite: String { "boutique." + item.id }

    /// Combien d'exemplaires on peut payer cash (100 au plus).
    private func maximumCash(_ argent: Int) -> Int {
        guard listing == nil, prix > 0 else { return 1 }
        return max(1, min(100, argent / prix))
    }

    var body: some View {
        let j = engine.joueur
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: shopSymbol(item.icon, item.category.icon)).font(.system(size: 40)).foregroundStyle(Theme.accent)
                    Text(item.name).font(.title2.bold())
                    if !item.brand.isEmpty { Text(item.brand).foregroundStyle(.secondary) }
                    Text(item.description)
                    if let pitch = listing?.pitch {
                        Text("« \(pitch) »").italic().foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            Section("Détails") {
                ShopInfoRow(titre: "Prix", valeur: Format.argent(prix), icone: "tag.fill")
                if let l = listing {
                    ShopInfoRow(titre: "État", valeur: "\(l.condition) %", icone: "wrench.and.screwdriver.fill")
                }
                if let city = item.city { ShopInfoRow(titre: "Ville", valeur: city, icone: "mappin.and.ellipse") }
                ShopInfoRow(titre: "Entretien par an", valeur: Format.argent(item.upkeep), icone: "arrow.triangle.2.circlepath")
                ShopInfoRow(titre: "Valeur par an", valeur: shopPourcent(item.appreciation), icone: "chart.line.uptrend.xyaxis")
                if item.rentIncome > 0 {
                    ShopInfoRow(titre: "Loyer possible", valeur: Format.argent(item.rentIncome), icone: "person.2.fill")
                }
                ShopInfoRow(titre: "Prestige", valeur: "\(item.prestige)/10", icone: "crown.fill")
                if item.minAge > 0 { ShopInfoRow(titre: "Âge minimum", valeur: "\(item.minAge) ans", icone: "person.fill.questionmark") }
                if item.happiness != 0 || item.looks != 0 || item.health != 0 {
                    ShopInfoRow(titre: "Effet à l'achat", valeur: effets, icone: "sparkles")
                }
            }
            if listing == nil, let j, ShopHooks.canAfford(prix, j.argent), maximumCash(j.argent) > 1 {
                Section("Combien ?") {
                    SelecteurQuantite(quantite: $quantite, maximum: maximumCash(j.argent),
                                      derniere: MemoireQuantites.derniere(cleQuantite))
                }
            }
            Section {
                Button {
                    acheter(.cash)
                } label: {
                    Label(quantite > 1 ? "Payer cash \(quantite) × \(Format.argent(prix)) = \(Format.argent(prix * quantite))"
                                       : "Payer cash \(Format.argent(prix))",
                          systemImage: "banknote")
                }
                .disabled(achatReussi || !(j.map { ShopHooks.canAfford(prix * max(1, quantite), $0.argent) } ?? false))

                if item.financing != .none, let j {
                    let check = ShopEngine.canFinance(item, price: prix, person: j)
                    Button {
                        acheter(.loan)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(item.financing == .mortgage ? "Acheter avec un prêt immobilier" : "Acheter à crédit", systemImage: "creditcard")
                            Text(check.message).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(achatReussi || !check.ok)
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert(achatReussi ? "Achat effectué" : "Achat impossible", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") {
                if achatReussi { dismiss() }
            }
        } message: {
            Text(message ?? "")
        }
    }

    private var effets: String {
        var parts: [String] = []
        if item.happiness != 0 { parts.append("Bonheur \(shopSigne(item.happiness))") }
        if item.looks != 0 { parts.append("Apparence \(shopSigne(item.looks))") }
        if item.health != 0 { parts.append("Santé \(shopSigne(item.health))") }
        return parts.joined(separator: ", ")
    }

    private func acheter(_ mode: ShopEngine.PaymentMode) {
        let avant = engine.joueur?.possessions?.residence
        var resultat = ShopResult(ok: false, message: "")
        let combien = (mode == .cash && listing == nil) ? max(1, quantite) : 1
        engine.modifier { j in
            var achetes = 0
            for _ in 0..<combien {
                let r = ShopEngine.buy(item, listing: listing, mode: mode, &j)
                if !r.ok { if achetes == 0 { resultat = r }; break }
                achetes += 1
                resultat = r
            }
            if achetes > 1 {
                resultat = ShopResult(ok: true, message: "Tu as acheté \(achetes) × \(item.name) cash pour \(Format.argent(prix * achetes)).")
            }
            if resultat.ok { engine.ajouterLigne(&j, resultat.message) }
        }
        if resultat.ok {
            MemoireQuantites.retenir(cleQuantite, combien)
            MemoireQuantites.retenirTexte("boutique.dernierArticle", item.id)
        }
        engine.notifierEmmenagementBoutique(avant: avant)
        achatReussi = resultat.ok
        message = resultat.message
    }
}

/// Certains symboles n'existent que sur les iOS récents : on retombe sur un symbole sûr.
func shopSymbol(_ name: String, _ fallback: String) -> String {
    UIImage(systemName: name) != nil ? name : fallback
}

func shopSigne(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }

func shopPourcent(_ v: Double) -> String {
    let p = Int((v * 100).rounded())
    return p > 0 ? "+\(p) %" : "\(p) %"
}

// MARK: - Mes biens

struct ShopOwnedListView: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        let items = engine.joueur?.boutique.items ?? []
        let catalog = ShopCatalog.shared
        List {
            if items.isEmpty {
                Text("Tu ne possèdes rien à part tes chaussettes. Les magasins t'attendent.")
                    .foregroundStyle(.secondary)
            }
            ForEach(ShopCategory.allCases) { cat in
                let owned = items.filter { catalog.item($0.catalogId)?.category == cat }
                if !owned.isEmpty {
                    Section(cat.title) {
                        ForEach(owned) { o in
                            if let item = catalog.item(o.catalogId) {
                                NavigationLink {
                                    ShopOwnedDetailView(ownedId: o.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: shopSymbol(item.icon, item.category.icon)).foregroundStyle(Theme.accent).frame(width: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(o.nickname ?? item.name).fontWeight(.semibold)
                                            Text("État \(o.condition) %\(o.isRentedOut ? " · loué" : "")\(o.loan != nil ? " · crédit" : "")")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(Format.argent(o.value)).monospacedDigit().font(.callout.weight(.semibold))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Mes biens")
    }
}

struct ShopOwnedDetailView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let ownedId: UUID
    @State private var message: String?
    @State private var offre: Int?
    @State private var dejaNegocie = false
    @State private var renommer = false
    @State private var nouveauNom = ""

    var body: some View {
        let owned = engine.joueur?.boutique.items.first { $0.id == ownedId }
        Group {
            if let o = owned, let item = ShopCatalog.shared.item(o.catalogId) {
                fiche(o, item)
            } else {
                Text("Ce bien ne t'appartient plus.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle(owned.flatMap { $0.nickname } ?? "Mon bien")
        .navigationBarTitleDisplayMode(.inline)
        .alert("", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") {}
        } message: {
            Text(message ?? "")
        }
        .alert("Offre d'achat", isPresented: Binding(get: { offre != nil }, set: { if !$0 { offre = nil } })) {
            Button("Accepter") { vendre() }
            if !dejaNegocie { Button("Négocier") { negocier() } }
            Button("Refuser", role: .cancel) {}
        } message: {
            Text("Un acheteur propose \(Format.argent(offre ?? 0)).")
        }
        .alert("Renommer", isPresented: $renommer) {
            TextField("Nom", text: $nouveauNom)
            Button("Valider") { engine.modifier { ShopEngine.rename(ownedId, to: nouveauNom, &$0) } }
            Button("Annuler", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func fiche(_ o: ShopOwnedItem, _ item: ShopItem) -> some View {
        let isHome = engine.joueur?.boutique.residence == .owned(id: o.id)
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: shopSymbol(item.icon, item.category.icon)).font(.system(size: 36)).foregroundStyle(Theme.accent)
                    Text(o.nickname ?? item.name).font(.title2.bold())
                    if o.nickname != nil { Text(item.name).foregroundStyle(.secondary) }
                    Text(item.description).font(.callout)
                }
                .padding(.vertical, 6)
            }
            Section("Situation") {
                ShopInfoRow(titre: "Valeur estimée", valeur: Format.argent(o.value), icone: "chart.line.uptrend.xyaxis")
                ShopInfoRow(titre: "Payé", valeur: Format.argent(o.purchasePrice), icone: "tag.fill")
                ShopInfoRow(titre: "Revente probable", valeur: Format.argent(ShopEngine.resaleEstimate(of: o)), icone: "arrow.left.arrow.right")
                BarreStat(titre: "État", icone: "wrench.and.screwdriver.fill", valeur: o.condition)
                ShopInfoRow(titre: "Frais par an", valeur: Format.argent(ShopEngine.yearlyCost(of: o)), icone: "arrow.triangle.2.circlepath")
                if o.isRentedOut {
                    ShopInfoRow(titre: "Loyer encaissé par an", valeur: Format.argent(ShopEngine.rentIncome(of: o)), icone: "person.2.fill")
                }
                if let loan = o.loan {
                    ShopInfoRow(titre: "Crédit restant", valeur: Format.argent(loan.remaining), icone: "creditcard.fill")
                    ShopInfoRow(titre: "Échéance annuelle", valeur: "\(Format.argent(loan.yearlyPayment)) · \(loan.yearsLeft) ans", icone: "calendar")
                }
                ShopInfoRow(titre: "Possédé depuis", valeur: "\(o.yearsOwned) an\(o.yearsOwned > 1 ? "s" : "")", icone: "clock.fill")
            }
            Section("Actions") {
                Toggle(isOn: Binding(get: { o.isInsured }, set: { v in engine.modifier { ShopEngine.setInsured(o.id, v, &$0) } })) {
                    VStack(alignment: .leading) {
                        Text("Assurance")
                        Text("\(Format.argent(ShopEngine.insurancePremium(o))) par an, rembourse vol et destruction")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if item.category == .realEstate {
                    if item.rentIncome > 0 && !isHome {
                        Toggle(isOn: Binding(get: { o.isRentedOut }, set: { v in faire { ShopEngine.setRentedOut(o.id, v, &$0) } })) {
                            Text("Mettre en location")
                        }
                    }
                    if !isHome {
                        Button("Emménager ici") { faire { ShopEngine.moveInto(.owned(id: o.id), &$0) } }
                    } else {
                        Text("Tu habites ici.").foregroundStyle(.secondary)
                    }
                }
                if o.condition < 100 {
                    Button("\(item.category == .realEstate ? "Faire des travaux" : "Réparer") (\(Format.argent(ShopEngine.repairCost(of: o))))") {
                        faire { ShopEngine.repair(o.id, &$0) }
                    }
                }
                if let loan = o.loan {
                    Button("Rembourser le crédit (\(Format.argent(loan.remaining)))") { faire { ShopEngine.payOffLoan(o.id, &$0) } }
                }
                Button("Renommer") {
                    nouveauNom = o.nickname ?? ""
                    renommer = true
                }
                Button("Mettre en vente", role: .destructive) {
                    dejaNegocie = false
                    offre = ShopEngine.sellOffer(for: o)
                }
            }
        }
    }

    private func faire(_ action: (inout Joueur) -> ShopResult) {
        let avant = engine.joueur?.possessions?.residence
        var r = ShopResult(ok: false, message: "")
        engine.modifier { r = action(&$0) }
        engine.notifierEmmenagementBoutique(avant: avant)
        message = r.message
    }

    private func negocier() {
        guard let o = offre else { return }
        dejaNegocie = true
        if let mieux = ShopEngine.haggle(o) {
            // L'alerte se ferme d'elle-même : on la rouvre avec la nouvelle offre.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { offre = mieux }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                message = "L'acheteur s'est vexé et il est parti en claquant la porte. Remets en vente pour une autre offre."
            }
        }
    }

    private func vendre() {
        guard let prix = offre else { return }
        var r = ShopResult(ok: false, message: "")
        engine.modifier { j in
            r = ShopEngine.sell(ownedId, price: prix, &j)
            if r.ok { engine.ajouterLigne(&j, r.message) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { message = r.message }
    }
}

// MARK: - Logement

struct ShopHousingView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        let catalog = ShopCatalog.shared
        let b = engine.joueur?.boutique ?? Possessions()
        let argent = engine.joueur?.argent ?? 0
        List {
            Section("Tu vis") {
                Text(ShopEngine.residenceName(b)).font(.headline)
                if case .rental(let id) = b.residence, let r = catalog.rental(id) {
                    Text("Loyer : \(Format.argent(r.rentPerYear)) par an").foregroundStyle(.secondary)
                }
                if b.residence != .parents {
                    Button("Retourner chez tes parents") { faire(.parents) }
                }
            }
            let maisons = b.items.filter { catalog.item($0.catalogId)?.category == .realEstate }
            if !maisons.isEmpty {
                Section("Tes propriétés") {
                    ForEach(maisons) { o in
                        Button {
                            faire(.owned(id: o.id))
                        } label: {
                            Label(o.nickname ?? catalog.item(o.catalogId)?.name ?? "", systemImage: "house.fill")
                        }
                        .disabled(b.residence == .owned(id: o.id))
                    }
                }
            }
            Section("Logements à louer") {
                ForEach(catalog.rentals.sorted { $0.rentPerYear < $1.rentPerYear }) { r in
                    Button {
                        faire(.rental(id: r.id))
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: shopSymbol(r.icon, "house.fill")).foregroundStyle(Theme.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).fontWeight(.semibold).foregroundStyle(Theme.encre)
                                Text(r.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                if let c = r.city { Text(c).font(.caption2).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(Format.argent(r.rentPerYear)).monospacedDigit().font(.callout.weight(.bold))
                                    .foregroundStyle(ShopHooks.canAfford(r.rentPerYear / 6, argent) ? Theme.encre : .red)
                                Text("par an").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(b.residence == .rental(id: r.id))
                }
            }
        }
        .navigationTitle("Logement")
        .alert("", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") {}
        } message: {
            Text(message ?? "")
        }
    }

    private func faire(_ residence: ShopResidence) {
        var r = ShopResult(ok: false, message: "")
        let avant = engine.joueur?.possessions?.residence
        engine.modifier { j in
            r = ShopEngine.moveInto(residence, &j)
            if r.ok { engine.ajouterLigne(&j, r.message) }
        }
        engine.notifierEmmenagementBoutique(avant: avant)
        message = r.message
    }
}

// MARK: - Voyages

struct ShopTravelView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var choisi: ShopTrip?
    @State private var message: String?
    @State private var evenement: PendingShopEvent?
    @State private var budgetSeulement = false

    var body: some View {
        let argent = engine.joueur?.argent ?? 0
        let age = engine.joueur?.age ?? 0
        let trips = ShopCatalog.shared.trips
            .filter { !budgetSeulement || ShopHooks.canAfford(ShopEngine.tripPrice($0), argent) }
            .sorted { $0.price < $1.price }
        List {
            Section {
                Toggle("Dans mon budget", isOn: $budgetSeulement)
                if let n = engine.joueur?.boutique.travels.count, n > 0 {
                    Text("Tu as fait \(n) voyage\(n > 1 ? "s" : "") dans ta vie.").foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(trips) { t in
                    Button {
                        choisi = t
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: shopSymbol(t.icon, "airplane")).foregroundStyle(Theme.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.name).fontWeight(.semibold).foregroundStyle(Theme.encre)
                                Text(t.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            Text(Format.argent(ShopEngine.tripPrice(t))).monospacedDigit().font(.callout.weight(.bold))
                                .foregroundStyle(ShopHooks.canAfford(ShopEngine.tripPrice(t), argent) ? Theme.encre : .red)
                        }
                    }
                    .disabled(age < t.minAge)
                }
            }
        }
        .navigationTitle("Voyages")
        .confirmationDialog(choisi?.name ?? "", isPresented: Binding(get: { choisi != nil }, set: { if !$0 { choisi = nil } }), titleVisibility: .visible) {
            if let t = choisi {
                Button("Partir pour \(Format.argent(ShopEngine.tripPrice(t)))") { partir(t) }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(choisi?.description ?? "")
        }
        .alert("Retour de voyage", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") {}
        } message: {
            Text(message ?? "")
        }
        .sheet(item: $evenement) { ev in
            ShopEventSheet(evenement: ev).environmentObject(engine)
        }
    }

    private func partir(_ t: ShopTrip) {
        var r = ShopEngine.TripResult(ok: false, text: "", event: nil)
        engine.modifier { j in
            r = ShopEngine.travel(t, &j)
            if r.ok { engine.ajouterLigne(&j, r.text) }
        }
        if let ev = r.event {
            evenement = ev
        } else {
            message = r.text
        }
    }
}

// MARK: - Événement lié à un bien

struct ShopEventSheet: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let evenement: PendingShopEvent
    @State private var resultat: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(evenement.text)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            if let resultat {
                Text(resultat).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Continuer") { dismiss() }
                    .buttonStyle(.borderedProminent)
            } else {
                ForEach(Array(evenement.def.choices.enumerated()), id: \.offset) { index, choix in
                    Button {
                        choisir(index)
                    } label: {
                        Text(choix.label).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(24)
        .tint(Theme.accent)
        .interactiveDismissDisabled(resultat == nil)
        .presentationDetents([.medium, .large])
    }

    private func choisir(_ index: Int) {
        var texte = ""
        engine.modifier { j in
            texte = ShopEngine.resolve(evenement, choice: index, &j)
            engine.ajouterLigne(&j, texte)
        }
        resultat = texte
    }
}

import Foundation

/// Points de branchement avec le reste du jeu (mode Shkurtaaa, etc.).
/// Exemple à l'intégration : `ShopHooks.money = { Shkurtaaa.argent($0) }`.
enum ShopHooks {
    static var money: (Int) -> Int = { $0 }
    static var happiness: (Int) -> Int = { $0 }
    static var health: (Int) -> Int = { $0 }
    static var canAfford: (_ price: Int, _ balance: Int) -> Bool = { $0 <= $1 }
    /// Multiplicateur de prix selon l'actualité (Journal du monde). Clé : `ShopCategory.mondeKey` ou "voyages".
    static var priceMultiplier: (_ categorie: String) -> Double = { _ in 1 }
    /// Appelé quand le joueur change de logement (achat, location, emménagement).
    /// Ex. module Voisinage : `ShopHooks.emmenagement = { nom, _, proprio in engine.voisinageEmmenager(logement: .depuis(nom), proprietaire: proprio) }`.
    static var emmenagement: @MainActor (_ nom: String, _ id: String, _ proprietaire: Bool) -> Void = { _, _, _ in }
}

/// Toute la logique argent et biens. Sans état : tout est dans `Possessions`.
enum ShopEngine {
    static var catalog: ShopCatalog { .shared }

    // MARK: Outils

    static func clamp(_ v: Int) -> Int { max(0, min(100, v)) }

    static func formatEuros(_ amount: Int) -> String { Format.argent(amount) }

    static func fill(_ text: String, person: some ShopActor, item: ShopItem? = nil,
                     owned: ShopOwnedItem? = nil, amount: Int? = nil, city: String? = nil) -> String {
        var t = text
        let itemName = owned?.nickname ?? item?.name ?? "bien"
        t = t.replacingOccurrences(of: "{item}", with: itemName)
        t = t.replacingOccurrences(of: "{name}", with: person.firstName)
        t = t.replacingOccurrences(of: "{city}", with: city ?? item?.city ?? "ta ville")
        if let amount { t = t.replacingOccurrences(of: "{amount}", with: formatEuros(amount)) }
        return t
    }

    static func pay<P: ShopActor>(_ amount: Int, _ p: inout P) {
        p.money = ShopHooks.money(p.money - amount)
        if amount > 0 { p.boutique.totalSpent += amount }
    }

    static func earn<P: ShopActor>(_ amount: Int, _ p: inout P) {
        p.money = ShopHooks.money(p.money + amount)
    }

    static func applyStats<P: ShopActor>(happiness: Int = 0, health: Int = 0, looks: Int = 0,
                                          smarts: Int = 0, karma: Int = 0, _ p: inout P) {
        p.happiness = ShopHooks.happiness(clamp(p.happiness + happiness))
        p.health = ShopHooks.health(clamp(p.health + health))
        p.looks = clamp(p.looks + looks)
        p.smarts = clamp(p.smarts + smarts)
        p.karma = clamp(p.karma + karma)
    }

    static func pick<G: RandomNumberGenerator>(_ outcomes: [ShopOutcome], using rng: inout G) -> ShopOutcome? {
        let total = outcomes.map { max(0, $0.weight) }.reduce(0, +)
        guard total > 0 else { return outcomes.first }
        var roll = Int.random(in: 0..<total, using: &rng)
        for o in outcomes {
            roll -= max(0, o.weight)
            if roll < 0 { return o }
        }
        return outcomes.last
    }

    /// Prestige total du perso : son meilleur bien compte plein pot, les autres un peu.
    static func prestige(_ possessions: Possessions) -> Int {
        let values = possessions.items.compactMap { catalog.item($0.catalogId)?.prestige }.sorted(by: >)
        guard let best = values.first else { return 0 }
        return min(10, best + values.dropFirst().count / 4)
    }

    static func yearlyCost(of owned: ShopOwnedItem) -> Int {
        guard let item = catalog.item(owned.catalogId) else { return 0 }
        var cost = item.upkeep
        if owned.isInsured { cost += insurancePremium(owned) }
        return cost
    }

    static func insurancePremium(_ owned: ShopOwnedItem) -> Int {
        guard let item = catalog.item(owned.catalogId) else { return 0 }
        return max(20, Int(Double(owned.value) * item.category.insuranceRate))
    }

    static func rentIncome(of owned: ShopOwnedItem) -> Int {
        guard owned.isRentedOut, let item = catalog.item(owned.catalogId) else { return 0 }
        let factor = 0.5 + 0.5 * Double(owned.condition) / 100
        return Int(Double(item.rentIncome) * factor * 0.9) // 10 % pour l'agence
    }

    static func repairCost(of owned: ShopOwnedItem) -> Int {
        guard let item = catalog.item(owned.catalogId) else { return 0 }
        let missing = Double(100 - owned.condition) / 100
        return Int(Double(item.price) * item.category.repairRate * missing)
    }

    static func resaleEstimate(of owned: ShopOwnedItem) -> Int {
        guard let item = catalog.item(owned.catalogId) else { return 0 }
        return Int(Double(owned.value) * item.category.conditionFactor(owned.condition))
    }

    // MARK: Marché (neuf et occasion), renouvelé chaque année

    static let usedPitches = [
        "Vendu cause départ en Patagonie, pas de questions.",
        "Comme neuf. Enfin, comme neuf il y a longtemps.",
        "Prix ferme. Sauf si tu insistes un peu.",
        "Une seule propriétaire, une dame âgée qui ne sortait que le dimanche. Pour des courses-poursuites.",
        "Petit défaut esthétique invisible à l'œil nu (et au microscope).",
        "Odeur de chien mouillé offerte.",
        "Le vendeur pleure en le montrant, c'est bon signe.",
        "Affaire du siècle selon le vendeur, qui est aussi le seul à l'avoir dit.",
        "Garantie zéro jour, satisfait ou tant pis.",
        "Échange possible contre une raclette et deux poules.",
        "Vu à la télé (dans un reportage sur les arnaques).",
        "Urgent, mon ex veut le récupérer.",
    ]

    static func refreshMarketIfNeeded<P: ShopActor>(_ p: inout P) {
        guard p.boutique.marketAge != p.age else { return }
        var rng = SystemRandomNumberGenerator()
        var listings: [ShopListing] = []
        for category in ShopCategory.allCases {
            let pool = catalog.items(in: category).filter(\.usedMarket)
            let count = category == .realEstate ? 14 : 10
            for item in pool.shuffled(using: &rng).prefix(count) {
                let years = Int.random(in: 1...15, using: &rng)
                var condition: Int
                if item.tags.contains("renover") {
                    condition = Int.random(in: 5...35, using: &rng)
                } else {
                    condition = clamp(100 - item.wear * years + Int.random(in: -10...15, using: &rng))
                }
                condition = max(5, condition)
                let drift = pow(1 + item.appreciation, Double(category == .realEstate ? 0 : years))
                let market = Double.random(in: 0.85...1.15, using: &rng)
                let price = Double(item.price) * drift * market * category.conditionFactor(condition) * ShopHooks.priceMultiplier(category.mondeKey)
                listings.append(ShopListing(catalogId: item.id, price: max(1, Int(price)),
                                              condition: condition, isUsed: true,
                                              pitch: usedPitches.randomElement(using: &rng)))
            }
        }
        p.boutique.market = listings
        p.boutique.marketAge = p.age
    }

    /// Prix neuf du moment (avec l'actualité).
    static func currentPrice(_ item: ShopItem) -> Int {
        max(1, Int(Double(item.price) * ShopHooks.priceMultiplier(item.category.mondeKey)))
    }

    static func tripPrice(_ trip: ShopTrip) -> Int {
        max(1, Int(Double(trip.price) * ShopHooks.priceMultiplier("voyages")))
    }

    static func usedListings(in category: ShopCategory, _ possessions: Possessions) -> [ShopListing] {
        possessions.market.filter { catalog.item($0.catalogId)?.category == category }
            .sorted { $0.price < $1.price }
    }

    // MARK: Achat

    enum PaymentMode: Hashable { case cash, loan }

    static func canFinance(_ item: ShopItem, price: Int, person: some ShopActor) -> ShopResult {
        guard item.financing != .none else { return ShopResult(ok: false, message: "Pas de crédit pour ce genre d'achat.") }
        guard person.age >= 18 else { return ShopResult(ok: false, message: "La banque ne prête pas aux mineurs, même très convaincants.") }
        guard person.boutique.creditScore >= 500 else {
            return ShopResult(ok: false, message: "Ton dossier de crédit fait rire le banquier. Il le montre à ses collègues.")
        }
        let down = Int(Double(price) * item.financing.downPaymentShare)
        guard ShopHooks.canAfford(down, person.money) else {
            return ShopResult(ok: false, message: "Il faut au moins \(formatEuros(down)) d'apport.")
        }
        return ShopResult(ok: true, message: "Apport de \(formatEuros(down)), puis \(formatEuros(ShopLoan.make(amount: price - down, financing: item.financing).yearlyPayment)) par an pendant \(item.financing.years) ans.")
    }

    @discardableResult
    static func buy<P: ShopActor>(_ item: ShopItem, listing: ShopListing? = nil,
                                   mode: PaymentMode = .cash, _ p: inout P) -> ShopResult {
        let price = listing?.price ?? currentPrice(item)
        guard p.age >= item.minAge else {
            return ShopResult(ok: false, message: "Reviens quand tu auras \(item.minAge) ans. Le vendeur a appelé tes parents.")
        }
        var loan: ShopLoan?
        switch mode {
        case .cash:
            guard ShopHooks.canAfford(price, p.money) else {
                return ShopResult(ok: false, message: "Ta carte bancaire a fait un bruit triste.")
            }
            pay(price, &p)
        case .loan:
            let check = canFinance(item, price: price, person: p)
            guard check.ok else { return check }
            let down = Int(Double(price) * item.financing.downPaymentShare)
            pay(down, &p)
            p.boutique.totalSpent += price - down
            loan = ShopLoan.make(amount: price - down, financing: item.financing)
        }
        let owned = ShopOwnedItem(catalogId: item.id, purchasePrice: price, value: price,
                              condition: listing?.condition ?? 100, loan: loan)
        p.boutique.items.append(owned)
        if let listing { p.boutique.market.removeAll { $0.id == listing.id } }
        applyStats(happiness: item.happiness, health: item.health, looks: item.looks, &p)
        if item.category == .realEstate, case .parents = p.boutique.residence {
            p.boutique.residence = .owned(id: owned.id)
        }
        let how = loan == nil ? "cash" : "à crédit"
        return ShopResult(ok: true, message: "Tu as acheté \(item.name) \(how) pour \(formatEuros(price)).")
    }

    // MARK: Revente

    /// Offre d'un acheteur, avec un peu de hasard.
    static func sellOffer(for owned: ShopOwnedItem) -> Int {
        Int(Double(resaleEstimate(of: owned)) * ShopHooks.priceMultiplier(catalog.item(owned.catalogId)?.category.mondeKey ?? "tout") * Double.random(in: 0.85...1.05))
    }

    @discardableResult
    static func sell<P: ShopActor>(_ ownedId: UUID, price: Int, _ p: inout P) -> ShopResult {
        guard let idx = p.boutique.items.firstIndex(where: { $0.id == ownedId }) else {
            return ShopResult(ok: false, message: "Ce bien n'existe plus.")
        }
        let owned = p.boutique.items[idx]
        let name = owned.nickname ?? catalog.item(owned.catalogId)?.name ?? "ton bien"
        let debt = owned.loan?.remaining ?? 0
        earn(price - debt, &p)
        p.boutique.items.remove(at: idx)
        if case .owned(let rid) = p.boutique.residence, rid == ownedId {
            p.boutique.residence = .parents
        }
        var msg = "Tu as vendu \(name) pour \(formatEuros(price))."
        if debt > 0 { msg += " \(formatEuros(debt)) sont partis rembourser le crédit." }
        if price > owned.purchasePrice { msg += " Plus-value : \(formatEuros(price - owned.purchasePrice)). Génie de la finance." }
        else if price < owned.purchasePrice / 2 { msg += " Ça pique un peu." }
        return ShopResult(ok: true, message: msg)
    }

    /// Négocier : 50 % de chances de +10 %, sinon l'acheteur s'en va vexé.
    static func haggle(_ offer: Int) -> Int? {
        Bool.random() ? Int(Double(offer) * 1.1) : nil
    }

    // MARK: Entretien, assurance, location, crédit

    @discardableResult
    static func repair<P: ShopActor>(_ ownedId: UUID, _ p: inout P) -> ShopResult {
        guard let idx = p.boutique.items.firstIndex(where: { $0.id == ownedId }),
              let item = catalog.item(p.boutique.items[idx].catalogId) else {
            return ShopResult(ok: false, message: "Introuvable.")
        }
        let cost = repairCost(of: p.boutique.items[idx])
        guard cost > 0 else { return ShopResult(ok: false, message: "C'est déjà nickel.") }
        guard ShopHooks.canAfford(cost, p.money) else { return ShopResult(ok: false, message: "Pas assez d'argent pour les réparations.") }
        pay(cost, &p)
        p.boutique.items[idx].condition = 100
        if item.category == .realEstate {
            p.boutique.items[idx].value += Int(Double(cost) * 0.8)
        }
        applyStats(happiness: 2, &p)
        return ShopResult(ok: true, message: item.category == .realEstate
                          ? "Travaux terminés : \(formatEuros(cost)). Le plombier est parti avec ta cafetière."
                          : "Remis à neuf pour \(formatEuros(cost)).")
    }

    static func setInsured<P: ShopActor>(_ ownedId: UUID, _ on: Bool, _ p: inout P) {
        guard let idx = p.boutique.items.firstIndex(where: { $0.id == ownedId }) else { return }
        p.boutique.items[idx].isInsured = on
    }

    static func setRentedOut<P: ShopActor>(_ ownedId: UUID, _ on: Bool, _ p: inout P) -> ShopResult {
        guard let idx = p.boutique.items.firstIndex(where: { $0.id == ownedId }),
              let item = catalog.item(p.boutique.items[idx].catalogId) else { return ShopResult(ok: false, message: "Introuvable.") }
        guard item.rentIncome > 0 else { return ShopResult(ok: false, message: "Personne ne veut louer ça. On a demandé.") }
        if on, case .owned(let rid) = p.boutique.residence, rid == ownedId {
            return ShopResult(ok: false, message: "Tu habites dedans. Déménage d'abord.")
        }
        p.boutique.items[idx].isRentedOut = on
        return ShopResult(ok: true, message: on ? "Ton bien est en location : environ \(formatEuros(rentIncome(of: p.boutique.items[idx]))) par an."
                                                : "Tu as récupéré ton bien. Les locataires ont laissé un poisson rouge.")
    }

    @discardableResult
    static func payOffLoan<P: ShopActor>(_ ownedId: UUID, _ p: inout P) -> ShopResult {
        guard let idx = p.boutique.items.firstIndex(where: { $0.id == ownedId }),
              let loan = p.boutique.items[idx].loan else { return ShopResult(ok: false, message: "Aucun crédit.") }
        guard ShopHooks.canAfford(loan.remaining, p.money) else { return ShopResult(ok: false, message: "Il manque des sous pour tout rembourser.") }
        pay(loan.remaining, &p)
        p.boutique.items[idx].loan = nil
        p.boutique.creditScore = min(850, p.boutique.creditScore + 25)
        return ShopResult(ok: true, message: "Crédit soldé. Ton banquier t'envoie un cœur.")
    }

    static func rename<P: ShopActor>(_ ownedId: UUID, to name: String, _ p: inout P) {
        guard let idx = p.boutique.items.firstIndex(where: { $0.id == ownedId }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        p.boutique.items[idx].nickname = trimmed.isEmpty ? nil : String(trimmed.prefix(40))
    }

    /// Retire un bien pour l'offrir (bijou à un partenaire, etc.). Renvoie l'objet offert.
    static func removeForGift<P: ShopActor>(_ ownedId: UUID, _ p: inout P) -> ShopItem? {
        guard let idx = p.boutique.items.firstIndex(where: { $0.id == ownedId }),
              let item = catalog.item(p.boutique.items[idx].catalogId),
              item.category.isGiftable, p.boutique.items[idx].loan == nil else { return nil }
        p.boutique.items.remove(at: idx)
        return item
    }

    // MARK: Logement

    @discardableResult
    static func moveInto<P: ShopActor>(_ residence: ShopResidence, _ p: inout P) -> ShopResult {
        switch residence {
        case .parents:
            p.boutique.residence = .parents
            applyStats(happiness: -3, &p)
            return ShopResult(ok: true, message: "Retour chez les parents. Ta chambre d'ado t'attendait, posters compris.")
        case .rental(let id):
            guard p.age >= 18 else { return ShopResult(ok: false, message: "Aucun propriétaire ne loue à un mineur.") }
            guard let r = catalog.rental(id) else { return ShopResult(ok: false, message: "Annonce expirée.") }
            guard ShopHooks.canAfford(r.rentPerYear / 12 * 2, p.money) else {
                return ShopResult(ok: false, message: "Il faut au moins deux mois de caution.")
            }
            pay(r.rentPerYear / 12 * 2, &p)
            p.boutique.residence = .rental(id: id)
            applyStats(happiness: r.happiness, &p)
            return ShopResult(ok: true, message: "Tu emménages : \(r.name). Caution de \(formatEuros(r.rentPerYear / 6)) versée (et jamais revue).")
        case .owned(let id):
            guard let idx = p.boutique.items.firstIndex(where: { $0.id == id }),
                  let item = catalog.item(p.boutique.items[idx].catalogId), item.category == .realEstate else {
                return ShopResult(ok: false, message: "Tu ne peux pas habiter là-dedans.")
            }
            p.boutique.items[idx].isRentedOut = false
            p.boutique.residence = .owned(id: id)
            return ShopResult(ok: true, message: "Tu t'installes dans \(p.boutique.items[idx].nickname ?? item.name).")
        }
    }

    static func residenceName(_ possessions: Possessions) -> String {
        switch possessions.residence {
        case .parents: return "Chez tes parents"
        case .rental(let id): return catalog.rental(id).map { "\($0.name) (location)" } ?? "Location"
        case .owned(let id):
            guard let o = possessions.items.first(where: { $0.id == id }) else { return "Chez tes parents" }
            return o.nickname ?? catalog.item(o.catalogId)?.name ?? "Chez toi"
        }
    }

    // MARK: Voyages

    struct TripResult: Hashable {
        let ok: Bool
        let text: String
        let event: PendingShopEvent?
    }

    static func travel<P: ShopActor>(_ trip: ShopTrip, _ p: inout P) -> TripResult {
        guard p.age >= trip.minAge else { return TripResult(ok: false, text: "Trop jeune pour ce voyage. Essaie la colo.", event: nil) }
        let price = tripPrice(trip)
        guard ShopHooks.canAfford(price, p.money) else { return TripResult(ok: false, text: "L'agence de voyage a ri au nez de ton compte en banque.", event: nil) }
        var rng = SystemRandomNumberGenerator()
        pay(price, &p)
        applyStats(happiness: trip.happiness, health: trip.health, &p)
        var text = "Voyage : \(trip.name)."
        if let outcome = pick(trip.outcomes, using: &rng) {
            text += " " + fill(outcome.text, person: p, city: trip.destination)
            if let e = outcome.effects { apply(e, itemId: nil, &p) }
        }
        p.boutique.travels.append(ShopTravelRecord(tripId: trip.id, age: p.age))
        var event: PendingShopEvent?
        if Double.random(in: 0..<1, using: &rng) < 0.35,
           let def = catalog.events.filter({ $0.scope == .trip && p.age >= ($0.minAge ?? 0) }).randomElement(using: &rng) {
            event = PendingShopEvent(def: def, itemId: nil, text: fill(def.text, person: p, city: trip.destination))
        }
        return TripResult(ok: true, text: text, event: event)
    }

    // MARK: Passage d'année

    struct YearReport: Hashable {
        var lines: [String] = []
        var events: [PendingShopEvent] = []
        var net: Int = 0
    }

    /// À appeler une fois par « +1 an », après le vieillissement du perso.
    static func yearlyTick<P: ShopActor>(_ p: inout P, maxEvents: Int = 2) -> YearReport {
        var rng = SystemRandomNumberGenerator()
        var report = YearReport()
        var income = 0
        var costs = 0
        var repossess: [UUID] = []

        for i in p.boutique.items.indices {
            var o = p.boutique.items[i]
            guard let item = catalog.item(o.catalogId) else { continue }
            o.yearsOwned += 1
            // Valeur
            let noise = Double.random(in: -1...1, using: &rng) * item.volatility
            let change = 1 + item.appreciation + noise
            o.value = max(1, Int(Double(o.value) * max(0.3, change)))
            // Usure (les locataires abîment un peu plus)
            let extraWear = o.isRentedOut ? 1 : 0
            o.condition = clamp(o.condition - item.wear - Int.random(in: 0...max(0, item.wear / 2), using: &rng) - extraWear)
            // Coûts et revenus
            costs += yearlyCost(of: o)
            income += rentIncome(of: o)
            // Crédit
            if var loan = o.loan {
                let due = min(loan.yearlyPayment, Int(Double(loan.remaining) * (1 + loan.rate)))
                if ShopHooks.canAfford(due, p.money - costs + income) {
                    costs += due
                    loan.remaining = max(0, Int(Double(loan.remaining) * (1 + loan.rate)) - due)
                    loan.yearsLeft -= 1
                    loan.missedPayments = 0
                    p.boutique.creditScore = min(850, p.boutique.creditScore + 5)
                    if loan.remaining == 0 || loan.yearsLeft <= 0 {
                        report.lines.append("Dernière mensualité payée pour \(o.nickname ?? item.name). Il est entièrement à toi !")
                        o.loan = nil
                    } else {
                        o.loan = loan
                    }
                } else {
                    loan.missedPayments += 1
                    loan.remaining = Int(Double(loan.remaining) * (1 + loan.rate))
                    p.boutique.creditScore = max(300, p.boutique.creditScore - 60)
                    o.loan = loan
                    if loan.missedPayments >= 2 {
                        repossess.append(o.id)
                    } else {
                        report.lines.append("Tu n'as pas pu payer le crédit de \(o.nickname ?? item.name). La banque t'envoie une lettre en rouge.")
                    }
                }
            }
            if item.category.isVehicle, o.condition == 0, p.boutique.items[i].condition > 0 {
                report.lines.append("\(o.nickname ?? item.name) a rendu l'âme. Il est temps de réparer ou de vendre à la casse.")
            }
            p.boutique.items[i] = o
        }

        // Loyer si on loue son logement
        if case .rental(let id) = p.boutique.residence, let r = catalog.rental(id) {
            costs += r.rentPerYear
        }

        pay(costs, &p)
        earn(income, &p)
        report.net = income - costs
        if costs > 0 || income > 0 {
            var line = "Biens : \(formatEuros(costs)) de frais"
            if income > 0 { line += ", \(formatEuros(income)) de loyers encaissés" }
            report.lines.append(line + ".")
        }

        // Saisies
        for id in repossess {
            guard let idx = p.boutique.items.firstIndex(where: { $0.id == id }) else { continue }
            let o = p.boutique.items[idx]
            let name = o.nickname ?? catalog.item(o.catalogId)?.name ?? "ton bien"
            let auction = Int(Double(resaleEstimate(of: o)) * 0.7)
            let rest = auction - (o.loan?.remaining ?? 0)
            p.boutique.items.remove(at: idx)
            if case .owned(let rid) = p.boutique.residence, rid == id { p.boutique.residence = .parents }
            if rest > 0 { earn(rest, &p) } else { pay(-rest, &p) }
            applyStats(happiness: -15, &p)
            report.lines.append("La banque a saisi \(name) et l'a vendu aux enchères. Un huissier a même pris ta plante verte.")
        }

        // Vie de luxe : société secrète, mondanité qui retombe…
        report.lines += LuxeMoteur.passageAnnee(&p)

        // Événements
        report.events = rollEvents(p, max: maxEvents, using: &rng)
        p.boutique.pendingEvents = Array((p.boutique.pendingEvents + report.events).suffix(4))
        refreshMarketIfNeeded(&p)
        return report
    }

    static func rollEvents<G: RandomNumberGenerator>(_ p: some ShopActor, max limit: Int, using rng: inout G) -> [PendingShopEvent] {
        var result: [PendingShopEvent] = []
        let prestigeLevel = prestige(p.boutique)
        func matches(_ def: ShopEventDef, _ item: ShopItem) -> Bool {
            if let c = def.categories, !c.isEmpty, !c.contains(item.category) { return false }
            if let s = def.subcategories, !s.isEmpty, !s.contains(item.subcategory) { return false }
            if let t = def.tags, !t.isEmpty, Set(t).isDisjoint(with: item.tags) { return false }
            return true
        }
        let candidates = catalog.events.filter { p.age >= ($0.minAge ?? 0) && prestigeLevel >= ($0.minPrestige ?? 0) }
        for owned in p.boutique.items.shuffled(using: &rng) {
            guard result.count < limit, let item = catalog.item(owned.catalogId) else { continue }
            for def in candidates.shuffled(using: &rng) where def.scope == .item {
                guard matches(def, item), owned.condition <= (def.maxCondition ?? 100) else { continue }
                if Double.random(in: 0..<1, using: &rng) < def.chance {
                    result.append(PendingShopEvent(def: def, itemId: owned.id,
                                                   text: fill(def.text, person: p, item: item, owned: owned)))
                    break
                }
            }
        }
        if result.count < limit {
            let ownedCats = Set(p.boutique.items.compactMap { catalog.item($0.catalogId)?.category })
            for def in candidates.shuffled(using: &rng) where def.scope == .owner {
                let cats = def.categories ?? []
                guard cats.isEmpty ? !p.boutique.items.isEmpty : !ownedCats.isDisjoint(with: cats) else { continue }
                if Double.random(in: 0..<1, using: &rng) < def.chance {
                    result.append(PendingShopEvent(def: def, itemId: nil, text: fill(def.text, person: p)))
                    break
                }
            }
        }
        return result
    }

    /// Applique le choix du joueur pour un événement. Renvoie le texte du résultat.
    static func resolve<P: ShopActor>(_ event: PendingShopEvent, choice: Int, _ p: inout P) -> String {
        p.boutique.pendingEvents.removeAll { $0.id == event.id }
        var rng = SystemRandomNumberGenerator()
        guard event.def.choices.indices.contains(choice),
              let outcome = pick(event.def.choices[choice].outcomes, using: &rng) else { return "" }
        let owned = event.itemId.flatMap { id in p.boutique.items.first { $0.id == id } }
        let item = owned.flatMap { catalog.item($0.catalogId) }
        var text = fill(outcome.text, person: p, item: item, owned: owned, amount: outcome.effects?.money.map(abs))
        if let e = outcome.effects {
            if let extra = apply(e, itemId: event.itemId, &p) { text += " " + extra }
        }
        return text
    }

    /// Applique des effets. Renvoie éventuellement une phrase en plus (assurance…).
    @discardableResult
    static func apply<P: ShopActor>(_ e: ShopEffects, itemId: UUID?, _ p: inout P) -> String? {
        var extra: String?
        if let m = e.money {
            if m < 0 { pay(-m, &p) } else { earn(m, &p) }
        }
        applyStats(happiness: e.happiness ?? 0, health: e.health ?? 0, looks: e.looks ?? 0,
                   smarts: e.smarts ?? 0, karma: e.karma ?? 0, &p)
        if let f = e.fame, f != 0 { p.mondanite += f }
        guard let id = itemId, let idx = p.boutique.items.firstIndex(where: { $0.id == id }) else { return nil }
        if let c = e.condition { p.boutique.items[idx].condition = clamp(p.boutique.items[idx].condition + c) }
        if let v = e.valuePct {
            let o = p.boutique.items[idx]
            p.boutique.items[idx].value = max(1, Int(Double(o.value) * (1 + v)))
        }
        if e.destroy == true || e.stolen == true {
            let o = p.boutique.items[idx]
            if o.isInsured {
                let payout = Int(Double(o.value) * 0.9)
                earn(payout - (o.loan?.remaining ?? 0), &p)
                extra = "L'assurance te rembourse \(formatEuros(payout))."
            } else if let loan = o.loan {
                extra = "Pas d'assurance… et il reste \(formatEuros(loan.remaining)) de crédit à payer."
                pay(loan.remaining, &p)
            } else {
                extra = "Pas d'assurance. Aïe."
            }
            p.boutique.items.remove(at: idx)
            if case .owned(let rid) = p.boutique.residence, rid == id { p.boutique.residence = .parents }
        }
        return extra
    }
}

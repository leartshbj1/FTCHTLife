import SwiftUI

// Écran « Placements » : livret, bourse, cryptos, immobilier locatif.
// Branchement : voir docs/PLACEMENTS.md. L'écran ne connaît pas le moteur du jeu :
// il reçoit l'état des placements et l'argent du joueur en Binding.

struct PlacementsView: View {
    @Binding var etat: PlacementsEtat
    @Binding var argent: Int
    let contexte: PlacementsContexte
    /// Appelé quand une action change le karma du joueur (hausse de loyer, expulsion…).
    var surKarma: (Int) -> Void = { _ in }

    @Environment(\.dismiss) var dismiss
    @State var message: String?
    @State var saisie: PlacementsSaisie?

    var body: some View {
        NavigationStack {
            List {
                resume
                livret
                if PlacementsMoteur.peutInvestir(contexte) {
                    bourse
                    immobilier
                } else {
                    Section {
                        Text("La bourse, les cryptos et l'immobilier, c'est à partir de \(PlacementsMoteur.ageMinBourse) ans. En attendant, il y a le livret. Et la tirelire en forme de cochon.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                nouvelles
            }
            .navigationTitle("Placements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .sheet(item: $saisie) { s in
                PlacementsMontantView(saisie: s)
            }
            .placementsAlerte($message)
        }
    }

    // MARK: Résumé

    private var resume: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Patrimoine placé").font(.caption).foregroundStyle(.secondary)
                    Text(Format.argent(PlacementsMoteur.patrimoine(etat)))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.encre)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Sur ton compte").font(.caption).foregroundStyle(.secondary)
                    Text(Format.argent(argent))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(argent < 0 ? .red : Color(red: 0.16, green: 0.6, blue: 0.3))
                }
            }
            let investi = PlacementsMoteur.investiTitres(etat)
            if investi > 0 {
                let gain = PlacementsMoteur.valeurTitres(etat) - investi
                PlacementsLigneInfo(titre: "Plus-value latente (titres)",
                                    valeur: (gain >= 0 ? "+" : "−") + Format.argent(PlacementsMoteur.entier(abs(gain))),
                                    couleur: gain >= 0 ? Color.green : Color.red)
            }
            if etat.dividendesCumules > 0 {
                PlacementsLigneInfo(titre: "Dividendes touchés", valeur: Format.argent(etat.dividendesCumules))
            }
            if etat.perteCrypto > 0 {
                PlacementsLigneInfo(titre: "Perdu dans des cryptos mortes", valeur: Format.argent(etat.perteCrypto), couleur: .red)
            }
        }
    }

    // MARK: Livret

    private var livret: some View {
        Section {
            PlacementsLigneInfo(titre: "Solde", valeur: Format.argent(etat.livret.solde))
            PlacementsLigneInfo(titre: "Taux cette année", valeur: String(format: "%.1f %%", etat.tauxLivret * 100 * contexte.mult("epargne")))
            if etat.livret.interetsCumules > 0 {
                PlacementsLigneInfo(titre: "Intérêts gagnés", valeur: Format.argent(etat.livret.interetsCumules))
            }
            LigneAction(titre: "Déposer", sousTitre: "Plafond \(Format.argent(PlacementsMoteur.plafondLivret))", icone: "arrow.down.to.line", actif: argent > 0 && etat.livret.solde < PlacementsMoteur.plafondLivret) {
                saisie = PlacementsSaisie(titre: "Déposer sur le livret", maximum: min(argent, PlacementsMoteur.plafondLivret - etat.livret.solde)) { m in
                    message = PlacementsMoteur.deposer(m, &etat, argent: &argent)
                }
            }
            LigneAction(titre: "Retirer", icone: "arrow.up.to.line", actif: etat.livret.solde > 0) {
                saisie = PlacementsSaisie(titre: "Retirer du livret", maximum: etat.livret.solde) { m in
                    message = PlacementsMoteur.retirer(m, &etat, argent: &argent)
                }
            }
        } header: {
            Text("Livret de l'Écureuil Prévoyant")
        } footer: {
            Text("Sans risque, sans frisson. Les intérêts tombent chaque année.")
        }
    }

    // MARK: Bourse

    private var bourse: some View {
        Section {
            NavigationLink {
                PlacementsListeView(titre: "Actions", types: [.action], etat: $etat, argent: $argent, contexte: contexte)
            } label: {
                Label("Actions", systemImage: "chart.line.uptrend.xyaxis")
            }
            NavigationLink {
                PlacementsListeView(titre: "Fonds et or", types: [.fonds, .or], etat: $etat, argent: $argent, contexte: contexte)
            } label: {
                Label("Fonds et or", systemImage: "shield.lefthalf.filled")
            }
            NavigationLink {
                PlacementsListeView(titre: "Cryptos", types: [.crypto], etat: $etat, argent: $argent, contexte: contexte)
            } label: {
                Label("Cryptos (×100 ou zéro)", systemImage: "bitcoinsign.circle")
            }
            ForEach(etat.positions, id: \.actifId) { p in
                if let a = PlacementsCatalogue.actif(p.actifId) {
                    NavigationLink {
                        PlacementsActifView(actif: a, etat: $etat, argent: $argent, contexte: contexte)
                    } label: {
                        PlacementsLignePosition(actif: a, position: p, etat: etat)
                    }
                }
            }
        } header: {
            Text("Bourse")
        } footer: {
            Text("Frais de courtage : 1 % à l'achat et à la vente. Les cours bougent une fois par an.")
        }
    }

    // MARK: Immobilier

    private var immobilier: some View {
        Section {
            ForEach(etat.biens) { b in
                NavigationLink {
                    PlacementsBienView(bienId: b.id, etat: $etat, argent: $argent, surKarma: surKarma)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.nom).foregroundStyle(Theme.encre)
                        Text("\(Format.argent(b.valeur)) · \(b.locataire.map { "loué à \($0)" } ?? "vide")" + (b.credit > 0 ? " · crédit \(Format.argent(b.credit))" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            NavigationLink {
                PlacementsCatalogueBiensView(etat: $etat, argent: $argent, contexte: contexte)
            } label: {
                Label("Acheter un bien à louer", systemImage: "house.and.flag")
            }
        } header: {
            Text("Immobilier locatif")
        } footer: {
            Text("Loyers, charges, crédit et pépins sont comptés chaque année.")
        }
    }

    // MARK: Nouvelles

    @ViewBuilder private var nouvelles: some View {
        if !etat.nouvelles.isEmpty {
            Section("Les échos de la Corbeille") {
                ForEach(Array(etat.nouvelles.enumerated()), id: \.offset) { _, n in
                    Text(n).font(.callout)
                }
            }
        }
    }
}

// MARK: - Liste d'actifs

struct PlacementsListeView: View {
    let titre: String
    let types: [PlacementType]
    @Binding var etat: PlacementsEtat
    @Binding var argent: Int
    let contexte: PlacementsContexte

    private var actifs: [PlacementActif] {
        PlacementsCatalogue.actifs.filter { types.contains($0.type) && etat.cours[$0.id]?.lancee == true }
    }

    var body: some View {
        List {
            let vivants = actifs.filter { etat.cours[$0.id]?.mort == false }
            let morts = actifs.filter { etat.cours[$0.id]?.mort == true }
            if types.contains(.crypto) {
                Section {
                    Text("Chaque année, une crypto peut faire ×10 à ×100… ou disparaître pour toujours. Ne mets que ce que tu es prêt·e à perdre. Ou pas, c'est ta vie.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if types.contains(.action) {
                ForEach(PlacementSecteur.allCases, id: \.self) { s in
                    let liste = vivants.filter { $0.secteur == s }
                    if !liste.isEmpty {
                        Section(s.nom) { lignes(liste) }
                    }
                }
            } else {
                Section { lignes(vivants) }
            }
            if !morts.isEmpty {
                Section(types.contains(.crypto) ? "Cimetière des cryptos" : "Faillites") {
                    ForEach(morts) { a in
                        Text("🪦 \(a.nom) (\(a.ticker))").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(titre)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lignes(_ liste: [PlacementActif]) -> some View {
        ForEach(liste) { a in
            NavigationLink {
                PlacementsActifView(actif: a, etat: $etat, argent: $argent, contexte: contexte)
            } label: {
                PlacementsLigneActif(actif: a, cours: etat.cours[a.id], detenu: PlacementsMoteur.position(etat, a.id) != nil)
            }
        }
    }
}

struct PlacementsLigneActif: View {
    let actif: PlacementActif
    let cours: PlacementCours?
    var detenu: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(actif.nom).foregroundStyle(Theme.encre).lineLimit(1)
                    if detenu { Image(systemName: "briefcase.fill").font(.caption2).foregroundStyle(Theme.accent) }
                }
                Text(actif.ticker).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            if let c = cours {
                PlacementsCourbe(valeurs: c.historique).frame(width: 54, height: 22)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(PlacementsFormat.prix(c.prix)).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text(PlacementsFormat.pourcentage(c.variation))
                        .font(.caption2.bold())
                        .foregroundStyle(c.variation >= 0 ? Color.green : Color.red)
                }
                .frame(minWidth: 70, alignment: .trailing)
            }
        }
    }
}

struct PlacementsLignePosition: View {
    let actif: PlacementActif
    let position: PlacementPosition
    let etat: PlacementsEtat

    var body: some View {
        let v = PlacementsMoteur.valeur(position, etat)
        let gain = position.investi > 0 ? v / position.investi - 1 : 0
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(actif.nom).foregroundStyle(Theme.encre).lineLimit(1)
                Text("\(PlacementsFormat.quantite(position.quantite)) \(actif.type == .crypto ? "jetons" : "parts")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.argent(PlacementsMoteur.entier(v))).font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(PlacementsFormat.pourcentage(gain)).font(.caption2.bold()).foregroundStyle(gain >= 0 ? Color.green : Color.red)
            }
        }
    }
}

// MARK: - Détail d'un actif

struct PlacementsActifView: View {
    let actif: PlacementActif
    @Binding var etat: PlacementsEtat
    @Binding var argent: Int
    let contexte: PlacementsContexte

    @State var message: String?
    @State var saisie: PlacementsSaisie?

    var body: some View {
        let cours = etat.cours[actif.id]
        let position = PlacementsMoteur.position(etat, actif.id)
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(PlacementsFormat.prix(cours?.prix ?? 0))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                        if let c = cours {
                            Text(PlacementsFormat.pourcentage(c.variation))
                                .font(.headline)
                                .foregroundStyle(c.variation >= 0 ? Color.green : Color.red)
                        }
                    }
                    if let c = cours, c.historique.count > 1 {
                        PlacementsCourbe(valeurs: c.historique, epaisseur: 2.5).frame(height: 120)
                        Text("Les \(c.historique.count - 1) dernières années").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(actif.description).font(.callout)
                }
                .padding(.vertical, 4)
                PlacementsLigneInfo(titre: "Type", valeur: actif.type.nom + (actif.secteur.map { " · \($0.nom)" } ?? ""))
                if let d = actif.dividende, d > 0 {
                    PlacementsLigneInfo(titre: "Dividende annuel", valeur: String(format: "%.1f %%", d * 100))
                }
                PlacementsLigneInfo(titre: "Humeur", valeur: humeur)
            }

            if let p = position {
                let v = PlacementsMoteur.valeur(p, etat)
                Section("Ta position") {
                    PlacementsLigneInfo(titre: actif.type == .crypto ? "Jetons" : "Parts", valeur: PlacementsFormat.quantite(p.quantite))
                    PlacementsLigneInfo(titre: "Valeur", valeur: Format.argent(PlacementsMoteur.entier(v)))
                    PlacementsLigneInfo(titre: "Investi", valeur: Format.argent(PlacementsMoteur.entier(p.investi)))
                    let gain = v - p.investi
                    PlacementsLigneInfo(titre: "Résultat",
                                        valeur: (gain >= 0 ? "+" : "−") + Format.argent(PlacementsMoteur.entier(abs(gain))),
                                        couleur: gain >= 0 ? Color.green : Color.red)
                    ForEach([0.25, 0.5, 1.0], id: \.self) { f in
                        LigneAction(titre: f == 1 ? "Tout vendre" : "Vendre \(Int(f * 100)) %", icone: "arrow.up.right.circle") {
                            message = PlacementsMoteur.vendre(actif.id, fraction: f, &etat, argent: &argent)
                        }
                    }
                }
            }

            Section {
                LigneAction(titre: "Acheter", sousTitre: "Frais 1 %", icone: "cart.badge.plus",
                            actif: argent > 1 && cours?.mort == false && PlacementsMoteur.peutInvestir(contexte)) {
                    saisie = PlacementsSaisie(titre: "Acheter \(actif.nom)", maximum: argent) { m in
                        message = PlacementsMoteur.acheter(actif.id, montant: m, &etat, argent: &argent, contexte: contexte)
                    }
                }
            }
        }
        .navigationTitle(actif.ticker)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $saisie) { s in PlacementsMontantView(saisie: s) }
        .placementsAlerte($message)
    }

    private var humeur: String {
        switch actif.type {
        case .crypto: return "Imprévisible (×100 ou zéro)"
        case .or: return "Sage comme un lingot"
        case .fonds: return actif.volatilite < 0.15 ? "Calme" : "Un peu nerveux"
        case .action:
            switch actif.volatilite {
            case ..<0.18: return "Pépère"
            case ..<0.3: return "Normal"
            case ..<0.42: return "Agité"
            default: return "Montagnes russes"
            }
        }
    }
}

// MARK: - Immobilier

struct PlacementsCatalogueBiensView: View {
    @Binding var etat: PlacementsEtat
    @Binding var argent: Int
    let contexte: PlacementsContexte

    @State var choisi: PlacementBienModele?
    @State var message: String?

    var body: some View {
        List {
            ForEach(PlacementsCatalogue.biens.sorted { $0.prix < $1.prix }) { m in
                Button {
                    choisi = m
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: m.icone ?? "house.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.nom).foregroundStyle(Theme.encre)
                            Text(m.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            Text("Loyer \(Format.argent(m.loyerAnnuel))/an · charges \(Format.argent(m.charges))/an · rendement \(String(format: "%.1f", Double(m.loyerAnnuel) / Double(max(1, m.prix)) * 100)) %")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Format.argent(m.prix)).font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
            }
        }
        .navigationTitle("Biens à vendre")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(choisi?.nom ?? "", isPresented: Binding(get: { choisi != nil }, set: { if !$0 { choisi = nil } }), titleVisibility: .visible, presenting: choisi) { m in
            let cash = PlacementsMoteur.coutAchat(m, credit: false)
            let credit = PlacementsMoteur.coutAchat(m, credit: true)
            Button("Comptant : \(Format.argent(cash.apport))") {
                message = PlacementsMoteur.acheterBien(m.id, credit: false, &etat, argent: &argent, contexte: contexte)
            }
            Button("À crédit : \(Format.argent(credit.apport)) d'apport, puis \(Format.argent(credit.annuite))/an") {
                message = PlacementsMoteur.acheterBien(m.id, credit: true, &etat, argent: &argent, contexte: contexte)
            }
            Button("Annuler", role: .cancel) {}
        } message: { m in
            Text("Frais de notaire : 8 %. Crédit sur \(PlacementsMoteur.dureeCredit) ans à \(String(format: "%.1f", PlacementsMoteur.tauxCredit * 100)) %, si la banque veut bien.")
        }
        .placementsAlerte($message)
    }
}

struct PlacementsBienView: View {
    let bienId: UUID
    @Binding var etat: PlacementsEtat
    @Binding var argent: Int
    var surKarma: (Int) -> Void

    @State var message: String?
    @State var confirmerVente = false
    @State var confirmerExpulsion = false

    var body: some View {
        List {
            if let b = etat.biens.first(where: { $0.id == bienId }) {
                Section {
                    PlacementsLigneInfo(titre: "Valeur", valeur: Format.argent(b.valeur))
                    PlacementsLigneInfo(titre: "Prix d'achat", valeur: Format.argent(b.prixAchat))
                    PlacementsLigneInfo(titre: "Loyer", valeur: "\(Format.argent(b.loyerAnnuel))/an")
                    PlacementsLigneInfo(titre: "Charges", valeur: "\(Format.argent(b.charges))/an")
                    PlacementsLigneInfo(titre: "Loyers encaissés", valeur: Format.argent(b.loyersEncaisses))
                    PlacementsLigneInfo(titre: "Détenu depuis", valeur: "\(b.annees) an\(b.annees > 1 ? "s" : "")")
                }
                Section("Locataire") {
                    if let nom = b.locataire {
                        let desc = b.locataireModeleId.flatMap { PlacementsCatalogue.locataire($0)?.description } ?? ""
                        Text("\(nom), \(desc)").font(.callout)
                    } else {
                        Text("Personne pour l'instant. On en cherche un chaque année.").font(.callout).foregroundStyle(.secondary)
                    }
                    LigneAction(titre: "Augmenter le loyer de 10 %", sousTitre: "Une fois par an", icone: "arrow.up.circle", actif: b.anneeHausse != etat.annees) {
                        let r = PlacementsMoteur.augmenterLoyer(bienId, &etat)
                        surKarma(r.karma)
                        message = r.message
                    }
                    if b.locataire != nil {
                        LigneAction(titre: "Expulser le locataire", icone: "figure.walk.departure") { confirmerExpulsion = true }
                    }
                }
                if b.credit > 0 {
                    Section("Crédit") {
                        PlacementsLigneInfo(titre: "Reste à rembourser", valeur: Format.argent(b.credit))
                        PlacementsLigneInfo(titre: "Remboursement", valeur: "\(Format.argent(b.annuite))/an")
                        LigneAction(titre: "Tout rembourser", icone: "checkmark.seal", actif: argent >= b.credit) {
                            message = PlacementsMoteur.rembourserCredit(bienId, &etat, argent: &argent)
                        }
                    }
                }
                Section {
                    LigneAction(titre: "Vendre", sousTitre: "Frais d'agence 5 %", icone: "signpost.right") { confirmerVente = true }
                }
                .navigationTitle(b.nom)
            } else {
                Text("Ce bien ne t'appartient plus.").foregroundStyle(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Vendre ce bien ?", isPresented: $confirmerVente, titleVisibility: .visible) {
            Button("Vendre", role: .destructive) { message = PlacementsMoteur.vendreBien(bienId, &etat, argent: &argent) }
        }
        .confirmationDialog("Mettre le locataire dehors ?", isPresented: $confirmerExpulsion, titleVisibility: .visible) {
            Button("Expulser", role: .destructive) {
                let r = PlacementsMoteur.expulser(bienId, &etat)
                surKarma(r.karma)
                message = r.message
            }
        }
        .placementsAlerte($message)
    }
}

// MARK: - Saisie d'un montant

struct PlacementsSaisie: Identifiable {
    let id = UUID()
    let titre: String
    let maximum: Int
    let valider: (Int) -> Void
}

struct PlacementsMontantView: View {
    let saisie: PlacementsSaisie
    @Environment(\.dismiss) var dismiss
    @State var texte = ""

    private var montant: Int { min(saisie.maximum, Int(texte.filter(\.isNumber)) ?? 0) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Montant en euros", text: $texte)
                        .keyboardType(.numberPad)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                } footer: {
                    Text("Maximum : \(Format.argent(max(0, saisie.maximum)))")
                }
                Section("Raccourcis") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                        ForEach(Array(raccourcis.enumerated()), id: \.offset) { _, r in
                            Button(r.0) { texte = String(r.1) }
                                .buttonStyle(.bordered)
                                .tint(Theme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(saisie.titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        let m = montant
                        dismiss()
                        if m > 0 { saisie.valider(m) }
                    }
                    .disabled(montant <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var raccourcis: [(String, Int)] {
        let max = saisie.maximum
        var r: [(String, Int)] = []
        for m in [100, 1_000, 10_000, 100_000, 1_000_000] where m < max {
            r.append((Format.argent(m), m))
        }
        if max > 3 {
            r.append(("10 %", max / 10))
            r.append(("50 %", max / 2))
        }
        if max > 0 { r.append(("Tout", max)) }
        return r
    }
}

// MARK: - Petits éléments

struct PlacementsLigneInfo: View {
    let titre: String
    let valeur: String
    var couleur: Color? = nil

    var body: some View {
        HStack {
            Text(titre).foregroundStyle(.secondary)
            Spacer()
            Text(valeur)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(couleur ?? Theme.encre)
        }
    }
}

/// Petite courbe des cours, verte si ça monte sur la période, rouge sinon.
struct PlacementsCourbe: View {
    let valeurs: [Double]
    var epaisseur: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let mini = valeurs.min() ?? 0
            let maxi = valeurs.max() ?? 1
            let ecart = Swift.max(maxi - mini, 0.000001)
            let monte = (valeurs.last ?? 0) >= (valeurs.first ?? 0)
            Path { p in
                guard valeurs.count > 1 else { return }
                for (i, v) in valeurs.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(valeurs.count - 1)
                    let y = geo.size.height * (1 - CGFloat((v - mini) / ecart))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(monte ? Color.green : Color.red, style: StrokeStyle(lineWidth: epaisseur, lineCap: .round, lineJoin: .round))
        }
    }
}

extension View {
    /// Affiche le message d'une action dans une alerte.
    func placementsAlerte(_ message: Binding<String?>) -> some View {
        alert("Placements", isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK") { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

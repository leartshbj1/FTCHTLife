import SwiftUI

// Module « Vivre à l'étranger » : écran principal.
// Branchement (voir docs/ETRANGER.md) :
//
//   ExpatView(etat: { $0.etranger ?? ExpatEtat.naissance(pays: "fr", ville: $0.ville, age: $0.age) },
//             ecrire: { j, e in j.etranger = e })
//       .environmentObject(engine)

struct ExpatView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    /// Lit l'état du module dans le joueur (ou le crée).
    let etat: (Joueur) -> ExpatEtat
    /// Range l'état du module dans le joueur.
    let ecrire: (inout Joueur, ExpatEtat) -> Void
    /// Mode triche : le visa est toujours accepté.
    var visaToujoursAccepte: Bool = false

    @State private var message: String?
    private let cat = ExpatCatalogue.shared

    init(etat: @escaping (Joueur) -> ExpatEtat,
         ecrire: @escaping (inout Joueur, ExpatEtat) -> Void,
         visaToujoursAccepte: Bool = false) {
        self.etat = etat
        self.ecrire = ecrire
        self.visaToujoursAccepte = visaToujoursAccepte
    }

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    contenu(j, etat(j))
                }
            }
            .navigationTitle("Vivre à l'étranger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    /// Applique une action du module au joueur, puis sauvegarde.
    private func agir(_ action: (inout Joueur, inout ExpatEtat) -> String) -> String {
        var texte = ""
        engine.modifier { j in
            var e = etat(j)
            texte = action(&j, &e)
            ecrire(&j, e)
        }
        return texte
    }

    @ViewBuilder
    private func contenu(_ j: Joueur, _ e: ExpatEtat) -> some View {
        let p = ExpatMoteur.paysActuel(e, cat)
        let depuis: String = e.vitAilleurs
            ? "Depuis \(e.anneesDansPays) an\(e.anneesDansPays > 1 ? "s" : "") · \(j.g("né", "née")) \(nomPays(e.paysNaissance, prefixe: true))"
            : "Ton pays natal"

        Section("Où tu vis") {
            HStack(spacing: 14) {
                Text(p.drapeau).font(.system(size: 44))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(j.ville), \(p.nom)").font(.headline)
                    Text(depuis)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(p.presentation).font(.callout)
            HStack {
                Text("Nationalités")
                Spacer()
                Text(e.nationalites.compactMap { cat.trouverPays($0)?.drapeau }.joined(separator: " "))
            }
            if e.vitAilleurs {
                ExpatBarreLangue(titre: "Tu te fais comprendre", valeur: ExpatMoteur.communication(e, j, dans: p))
            }
        }

        Section("Coût de la vie ici") {
            ligneCoef("Salaires", icone: "banknote.fill", p.salaire)
            ligneCoef("Prix", icone: "cart.fill", p.prix)
            ligneCoef("Soins", icone: "cross.case.fill", p.sante)
            HStack {
                Label("Impôts sur le salaire", systemImage: "building.columns.fill")
                Spacer()
                Text("\(Int((p.impots * 100).rounded())) %").foregroundStyle(.secondary)
            }
        }

        if !p.lois.isEmpty {
            Section("Lois et règles du coin") {
                ForEach(p.lois) { loi in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loi.titre).font(.subheadline.weight(.semibold))
                        Text(loi.texte).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        if !p.coutumes.isEmpty {
            Section("Coutumes") {
                ForEach(p.coutumes, id: \.self) { c in
                    Text(c).font(.callout)
                }
            }
        }

        Section {
            ForEach(ExpatMoteur.languesParlees(e, j, cat)) { l in
                ExpatBarreLangue(titre: cat.nomLangue(l.id).capitalized, valeur: l.niveau)
            }
            if j.age >= 6 {
                Menu {
                    ForEach(cat.langues.filter { ExpatMoteur.niveau($0.id, e, j) < 99 }) { l in
                        Button("\(l.nom.capitalized) (\(ExpatMoteur.niveau(l.id, e, j))/100)") {
                            message = agir { j, e in ExpatMoteur.prendreCours(&j, &e, langue: l.id, cat) }
                        }
                    }
                } label: {
                    Label("Prendre un cours de langue · \(Format.argent(j.age < 18 ? 0 : ExpatMoteur.prixCours(e, cat)))",
                          systemImage: "graduationcap.fill")
                }
            }
        } header: {
            Text("Tes langues")
        }

        Section {
            if j.age < ExpatMoteur.ageMinimum {
                Text("Tu pourras partir à \(ExpatMoteur.ageMinimum) ans. En attendant, tu peux regarder une carte du monde avec envie.")
                    .font(.callout)
            } else {
                // Liste stable (le pays actuel reste affiché) pour que la fiche ouverte ne se ferme pas
                // toute seule pendant le déménagement.
                ForEach(cat.pays.sorted { $0.nom.localizedStandardCompare($1.nom) == .orderedAscending }) { pays in
                    lienPays(pays, j, e)
                }
            }
        } header: {
            Text("Déménager")
        } footer: {
            Text("Partir coûte un déménagement, parfois un visa. Ton travail ne te suit pas toujours, ton couple non plus.")
        }
    }

    private func lienPays(_ pays: ExpatPays, _ j: Joueur, _ e: ExpatEtat) -> some View {
        NavigationLink {
            ExpatPaysView(pays: pays, etat: etat, visaToujoursAccepte: visaToujoursAccepte) { action in
                agir(action)
            }
            .environmentObject(engine)
        } label: {
            HStack(spacing: 12) {
                Text(pays.drapeau).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pays.nom)
                    Text(sousTitre(pays, e))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sousTitre(_ pays: ExpatPays, _ e: ExpatEtat) -> String {
        if pays.id == e.paysActuel { return "📍 Tu vis ici" }
        let visa = ExpatMoteur.libreCirculation(e, vers: pays, cat) ? "Sans visa" : pays.libelleVisa
        let natal = pays.id == e.paysNaissance ? "🏡 Ton pays natal · " : ""
        return natal + "Salaires \(ExpatFormat.coef(pays.salaire)) · Prix \(ExpatFormat.coef(pays.prix)) · \(visa)"
    }

    private func ligneCoef(_ titre: String, icone: String, _ v: Double) -> some View {
        HStack {
            Label(titre, systemImage: icone)
            Spacer()
            Text(ExpatFormat.coef(v) + " par rapport à la France").foregroundStyle(.secondary).font(.caption)
        }
    }

    private func nomPays(_ id: String, prefixe: Bool) -> String {
        guard let p = cat.trouverPays(id) else { return id }
        return prefixe ? p.enPays : p.nom
    }
}

/// Fiche d'un pays : coûts, visa, lois, coutumes, choix de la ville et départ.
struct ExpatPaysView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    let pays: ExpatPays
    let etat: (Joueur) -> ExpatEtat
    var visaToujoursAccepte: Bool = false
    /// Applique une action au joueur et à l'état du module, renvoie le texte du résultat.
    let agir: ((inout Joueur, inout ExpatEtat) -> String) -> String

    @State private var ville: String = ""
    @State private var confirmer = false
    @State private var message: String?
    @State private var parti = false
    private let cat = ExpatCatalogue.shared

    init(pays: ExpatPays, etat: @escaping (Joueur) -> ExpatEtat, visaToujoursAccepte: Bool = false,
         agir: @escaping ((inout Joueur, inout ExpatEtat) -> String) -> String) {
        self.pays = pays
        self.etat = etat
        self.visaToujoursAccepte = visaToujoursAccepte
        self.agir = agir
    }

    var body: some View {
        List {
            if let j = engine.joueur {
                contenu(j, etat(j))
            }
        }
        .navigationTitle("\(pays.drapeau) \(pays.nom)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if ville.isEmpty { ville = pays.villes.first ?? "" } }
        .confirmationDialog("Partir vivre \(pays.enPays) ?", isPresented: $confirmer, titleVisibility: .visible) {
            Button("Faire mes valises") {
                let v = ville
                message = agir { j, e in
                    let r = ExpatMoteur.demenager(&j, &e, vers: pays, ville: v,
                                                  visaToujoursAccepte: visaToujoursAccepte, cat)
                    if r.reussi { parti = true }
                    return r.lignes.isEmpty ? r.resume : r.lignes.joined(separator: "\n\n")
                }
            }
            Button("Rester", role: .cancel) {}
        } message: {
            Text("Tu peux perdre ton travail, et ton couple peut ne pas suivre.")
        }
        .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") {
                message = nil
                if parti { dismiss() }
            }
        } message: {
            Text(message ?? "")
        }
    }

    @ViewBuilder
    private func contenu(_ j: Joueur, _ e: ExpatEtat) -> some View {
        let v = ExpatMoteur.verdict(j, e, vers: pays, visaToujoursAccepte: visaToujoursAccepte, cat)
        let titreBouton: String = pays.id == e.paysNaissance
            ? "Rentrer au pays · \(Format.argent(v.coutTotal))"
            : "Partir · \(Format.argent(v.coutTotal))"

        Section {
            Text(pays.presentation)
        }

        Section("Économie") {
            ligne("Salaires", ExpatFormat.coef(pays.salaire))
            ligne("Coût de la vie", ExpatFormat.coef(pays.prix))
            ligne("Soins", ExpatFormat.coef(pays.sante))
            ligne("Impôts sur le salaire", "\(Int((pays.impots * 100).rounded())) %")
        }

        Section("Langue") {
            let langues = pays.toutesLangues.map { cat.nomLangue($0) }.joined(separator: ", ")
            ligne("On y parle", langues)
            ExpatBarreLangue(titre: "Ton niveau", valeur: ExpatMoteur.communication(e, j, dans: pays))
        }

        Section("Papiers") {
            ligne("Visa", v.fraisVisa == 0 ? "Pas besoin" : "\(pays.libelleVisa), \(Format.argent(v.fraisVisa))")
            if v.fraisVisa > 0 {
                ligne("Chances d'acceptation", "\(Int((v.chanceVisa * 100).rounded())) %")
            }
            ligne("Déménagement", Format.argent(pays.coutDemenagement))
            if !e.nationalites.contains(pays.id) {
                ligne("Nationalité possible après", "\(pays.naturalisation) ans")
            }
        }

        if !pays.lois.isEmpty {
            Section("Lois et règles") {
                ForEach(pays.lois) { loi in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loi.titre).font(.subheadline.weight(.semibold))
                        Text(loi.texte).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }

        if !pays.coutumes.isEmpty {
            Section("Coutumes") {
                ForEach(pays.coutumes, id: \.self) { Text($0).font(.callout) }
            }
        }

        Section {
            Picker("Ville", selection: $ville) {
                ForEach(pays.villes, id: \.self) { Text($0).tag($0) }
            }
            Button {
                confirmer = true
            } label: {
                Label(titreBouton, systemImage: "airplane.departure")
                    .font(.headline)
            }
            .disabled(!v.possible)
        } footer: {
            Text(v.message)
        }
    }

    private func ligne(_ titre: String, _ valeur: String) -> some View {
        HStack {
            Text(titre)
            Spacer()
            Text(valeur).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}

/// Barre de niveau de langue : nom, niveau sur 100 et libellé (« Débrouillard »…).
struct ExpatBarreLangue: View {
    let titre: String
    let valeur: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(titre).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(valeur)/100").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(min(100, max(0, valeur))), total: 100)
                .tint(Theme.couleurStat(valeur))
            Text(ExpatEtat.libelleNiveau(valeur)).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

enum ExpatFormat {
    /// 1.7 → « ×1,7 ».
    static func coef(_ v: Double) -> String {
        let arrondi = (v * 10).rounded() / 10
        let texte = arrondi == arrondi.rounded() ? String(Int(arrondi)) : String(format: "%.1f", arrondi)
        return "×" + texte.replacingOccurrences(of: ".", with: ",")
    }
}

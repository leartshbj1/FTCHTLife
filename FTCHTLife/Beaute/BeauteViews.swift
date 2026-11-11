import SwiftUI

// Écrans du module Beauté : Activités → Coiffeur, Activités → Chirurgie esthétique.

/// Ligne de choix avec une coche quand elle est sélectionnée.
private struct BeauteLigneChoix: View {
    let titre: String
    var sousTitre: String? = nil
    var detail: String? = nil
    let choisi: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: choisi ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(choisi ? Theme.accent : Theme.gris)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titre).foregroundStyle(Theme.encre)
                    if let s = sousTitre {
                        Text(s).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let d = detail {
                    Text(d).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Coiffeur

struct CoiffeurView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var salonId: String?
    @State private var coupeId: String?
    @State private var couleurId: String?
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                contenu(j)
            }
        }
        .alerteResultat($message)
    }

    @ViewBuilder
    private func contenu(_ j: Joueur) -> some View {
        let salons = BeauteMoteur.salons(j)
        let coupes = BeauteMoteur.coupes(j)
        let salon = salons.first { $0.id == salonId } ?? salons.first
        let coupe = coupes.first { $0.id == coupeId } ?? coupes.first
        let couleur: BeauteCouleur? = (salon?.couleur == true) ? couleurId.flatMap { BeauteCatalogue.charge.couleur($0) } : nil
        let etat = BeauteMoteur.etat(j)

        Section("Ton look") {
            Text(BeauteMoteur.descriptionLook(j))
            if etat.coiffeurVisites > 0 {
                Text("\(etat.coiffeurVisites) passage\(etat.coiffeurVisites > 1 ? "s" : "") chez le coiffeur, dont \(etat.coiffuresRatees) raté\(etat.coiffuresRatees > 1 ? "s" : "").")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if j.age < 18 {
                Text("Tes parents paient dans les salons simples. Les couleurs viennent avec l'âge.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }

        Section("1. Le salon") {
            ForEach(salons) { s in
                BeauteLigneChoix(titre: s.nom, sousTitre: s.description,
                                 detail: s.prix == 0 ? "Gratuit" : "dès \(Format.argent(s.prix))",
                                 choisi: s.id == salon?.id) {
                    salonId = s.id
                }
            }
        }

        Section("2. La coupe") {
            ForEach(coupes) { c in
                BeauteLigneChoix(titre: c.nom, sousTitre: c.description + Self.audace(c.audace),
                                 detail: salon.map { Format.argent(BeauteMoteur.prixCoupe($0, c)) },
                                 choisi: c.id == coupe?.id) {
                    coupeId = c.id
                }
            }
        }

        if salon?.couleur == true {
            Section("3. La couleur (si tu veux)") {
                BeauteLigneChoix(titre: "Pas de couleur", choisi: couleur == nil) { couleurId = nil }
                ForEach(BeauteMoteur.couleurs(j)) { col in
                    BeauteLigneChoix(titre: col.nom, sousTitre: Self.audace(col.audace).trimmingCharacters(in: .whitespaces),
                                     detail: salon.map { "+" + Format.argent(BeauteMoteur.prixCouleur($0, col)) },
                                     choisi: col.id == couleur?.id) {
                        couleurId = col.id
                    }
                }
            }
        }

        if let s = salon, let c = coupe {
            let refus = BeauteMoteur.refusCoiffeur(j, s, c, couleur)
            let prix = BeauteMoteur.prixPaye(j, s, c, couleur)
            Section {
                Button {
                    message = engine.beauteCoiffer(salon: s.id, coupe: c.id, couleur: couleur?.id)
                } label: {
                    HStack {
                        Image(systemName: "scissors")
                        Text(prix == 0 ? "Y aller" : "Y aller · \(Format.argent(prix))").bold()
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(refus != nil)
                if let r = refus {
                    Text(r).font(.caption).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Une coupe audacieuse fait parler d'elle, en bien ou en mal. Plus le salon est bon, moins ça rate. Une coupe repousse en un ou deux ans.")
            }
        }
    }

    static func audace(_ n: Int) -> String {
        switch n {
        case 0: return ""
        case 1: return " · un peu osé"
        case 2: return " · audacieux"
        default: return " · très audacieux"
        }
    }
}

// MARK: - Chirurgie esthétique

struct ChirurgieView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var cliniqueId = "reconnu"
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                contenu(j)
            }
        }
        .alerteResultat($message)
    }

    @ViewBuilder
    private func contenu(_ j: Joueur) -> some View {
        let cat = BeauteCatalogue.charge
        let etat = BeauteMoteur.etat(j)
        let clinique = cat.clinique(cliniqueId) ?? cat.cliniques.first

        Section {
            Text("Chaque passage au bloc a ses risques : complications, résultats ratés, et parfois pire. Le prix, la clinique, ton âge, ta santé et le nombre d'opérations déjà faites changent tout.")
                .font(.subheadline).foregroundStyle(.secondary)
            if etat.nbBloc > 0 || etat.depenseChirurgie > 0 {
                Text("\(etat.nbBloc) passage\(etat.nbBloc > 1 ? "s" : "") au bloc · \(Format.argent(etat.depenseChirurgie)) dépensés")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }

        if !etat.suites.isEmpty {
            Section("Complications en cours") {
                ForEach(etat.suites) { s in
                    if let comp = cat.complication(s.complication) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comp.nom + (comp.grave ? " ⚠️" : "")).font(.headline)
                            Text(comp.texte).font(.caption).foregroundStyle(.secondary)
                            Text(comp.duree >= 99 ? "Ne guérira pas seul." : "Encore \(s.anneesRestantes) an\(s.anneesRestantes > 1 ? "s" : "") sans soin.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button("Faire soigner · \(Format.argent(comp.soin))") {
                            message = engine.beauteSoigner(s.id)
                        }
                    }
                }
            }
        }

        let ratees = etat.operations.filter { $0.aReparer }
        if !ratees.isEmpty {
            Section("À réparer") {
                ForEach(ratees) { op in
                    Button {
                        message = engine.beauteReparer(op.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chirurgie réparatrice : " + (cat.intervention(op.intervention)?.nom ?? "opération")).foregroundStyle(Theme.encre)
                            Text("Ratée à \(op.age) ans · \(Format.argent(BeauteMoteur.prixReparation(op)))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        Section("Où se faire opérer") {
            ForEach(cat.cliniques) { c in
                BeauteLigneChoix(titre: c.nom + (c.illegal == true ? " ⚠️" : ""), sousTitre: c.description,
                                 detail: Self.prixRelatif(c.prixFacteur), choisi: c.id == clinique?.id) {
                    cliniqueId = c.id
                }
            }
        }

        if let c = clinique {
            ForEach(cat.zones, id: \.self) { zone in
                let liste = BeauteMoteur.interventions(j, zone: zone, clinique: c)
                if !liste.isEmpty {
                    Section(zone) {
                        ForEach(liste) { i in
                            NavigationLink {
                                InterventionDetailView(interventionId: i.id, cliniqueId: c.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(i.nom)
                                        Spacer()
                                        Text(Format.argent(BeauteMoteur.prixOperation(i, c))).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    }
                                    Text("Risque " + BeauteMoteur.niveauRisque(i, j, c) + (i.duree != nil ? " · effet temporaire" : ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }

        if !etat.operations.isEmpty {
            Section("Ton historique") {
                ForEach(Array(etat.operations.reversed())) { op in
                    HStack {
                        Text(cat.intervention(op.intervention)?.nom ?? op.intervention)
                        Spacer()
                        Text(Self.libelle(op.resultat) + " à \(op.age) ans").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    static func prixRelatif(_ f: Double) -> String {
        switch f {
        case ..<0.5: return "€"
        case ..<0.9: return "€€"
        case ..<1.5: return "€€€"
        default: return "€€€€"
        }
    }

    static func libelle(_ r: String) -> String {
        switch r {
        case "reussie": return "✅ Réussie"
        case "complication": return "🩹 Complication"
        case "ratee": return "❌ Ratée"
        case "grave": return "🚑 Accident"
        case "reparee": return "🔧 Réparée"
        default: return r
        }
    }
}

/// Fiche d'une intervention avant de se décider.
struct InterventionDetailView: View {
    @EnvironmentObject var engine: GameEngine
    let interventionId: String
    let cliniqueId: String
    @State private var message: String?
    @State private var confirmer = false

    var body: some View {
        let cat = BeauteCatalogue.charge
        List {
            if let j = engine.joueur, let i = cat.intervention(interventionId), let c = cat.clinique(cliniqueId) {
                let prix = BeauteMoteur.prixOperation(i, c)
                let refus = BeauteMoteur.refusOperation(j, i, c)
                Section {
                    Text(i.description)
                    LabeledContent("Où", value: c.nom)
                    LabeledContent("Prix", value: Format.argent(prix))
                    LabeledContent("Risque", value: BeauteMoteur.niveauRisque(i, j, c))
                    LabeledContent("Convalescence", value: i.sante == 0 ? "aucune" : "-\(i.sante) santé")
                    LabeledContent("Durée de l'effet", value: i.duree.map { "\($0) an\($0 > 1 ? "s" : "")" } ?? "définitif")
                }
                if i.risqueGrave >= 0.01 || c.illegal == true {
                    Section {
                        Text(c.illegal == true
                             ? "Produits inconnus, aucune hygiène, aucun médecin. Des gens en meurent ou restent défigurés. Et c'est illégal."
                             : "C'est l'opération esthétique la plus mortelle. Même chez un bon chirurgien, le risque d'accident grave est réel.")
                            .font(.subheadline).foregroundStyle(Theme.argentNegatif)
                    }
                }
                Section {
                    Button {
                        confirmer = true
                    } label: {
                        Text("Prendre rendez-vous").bold().frame(maxWidth: .infinity)
                    }
                    .disabled(refus != nil)
                    if let r = refus {
                        Text(r).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(cat.intervention(interventionId)?.nom ?? "Intervention")
        .confirmationDialog("Passer au bloc ?", isPresented: $confirmer, titleVisibility: .visible) {
            Button("Je me lance") {
                message = engine.beauteOperer(interventionId, clinique: cliniqueId)
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ce n'est pas sans risque. Tu es sûr" + ((engine.joueur?.genre == .femme) ? "e" : "") + " ?")
        }
        .alerteResultat($message)
    }
}

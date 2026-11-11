import SwiftUI

/// Jauge 0-100. `inverse` : plus c'est haut, plus c'est inquiétant (dérive, surveillance).
struct JaugeModule: View {
    let titre: String
    let icone: String
    let valeur: Int
    var inverse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icone).frame(width: 18).foregroundStyle(couleur)
            Text(titre).font(.system(size: 13, weight: .semibold)).frame(width: 100, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(couleur)
                        .frame(width: max(0, geo.size.width * CGFloat(min(100, max(0, valeur))) / 100))
                }
            }
            .frame(height: 10)
            Text("\(valeur)").font(.system(size: 12, weight: .bold, design: .rounded)).monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
    }

    private var couleur: Color { Theme.couleurStat(inverse ? 100 - valeur : valeur) }
}

/// Menu Carrière → Ma secte : fonder un mouvement puis le diriger.
struct SecteView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    @State private var nom = ""
    @State private var doctrineId: String?
    @State private var confirmerDissolution = false

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    if let s = j.sectes?.actuelle {
                        mouvement(s, j)
                    } else {
                        fondation(j)
                    }
                    anciennes(j)
                }
            }
            .navigationTitle("Ma secte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
            .alerteResultat($message)
            .confirmationDialog("Dissoudre le mouvement ?", isPresented: $confirmerDissolution, titleVisibility: .visible) {
                Button("Dissoudre et rendre la caisse aux membres") { message = engine.dissoudreSecte(rendre: true) }
                Button("Dissoudre et garder une partie de la caisse", role: .destructive) { message = engine.dissoudreSecte(rendre: false) }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les membres devront reconstruire leur vie sans toi.")
            }
        }
    }

    // MARK: - Fonder

    @ViewBuilder
    private func fondation(_ j: Joueur) -> some View {
        Section {
            Text("Fonder un mouvement spirituel, attirer des membres, gérer leurs dons. Chaque année, le mouvement grandit ou s'effrite. Plus tu exerces d'emprise, plus la presse, les familles et la justice s'intéressent à toi.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        if let blocage = SecteMoteur.blocageFondation(j) {
            Section { Text(blocage).foregroundStyle(.secondary) }
        } else {
            Section("Doctrine") {
                ForEach(SecteCatalogue.doctrines) { d in
                    Button {
                        doctrineId = d.id
                        if nom.isEmpty { nom = d.nomsSuggeres.randomElement() ?? "" }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: d.icone).foregroundStyle(Theme.accent).frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(d.nom).font(.headline).foregroundStyle(Theme.encre)
                                Text(d.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if doctrineId == d.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        }
                    }
                }
            }
            if let id = doctrineId, let d = SecteCatalogue.doctrine(id) {
                Section("Nom du mouvement") {
                    TextField("Nom", text: $nom)
                    Button("Autre suggestion") { nom = d.nomsSuggeres.randomElement() ?? nom }
                }
                Section {
                    Button {
                        message = engine.fonderSecte(nom: nom, doctrine: d) ?? "Tu fondes « \(nom) ». Tout commence dans ton salon, avec trois chaises et beaucoup de conviction."
                    } label: {
                        Label("Fonder « \(nom.isEmpty ? "…" : nom) »", systemImage: "flame.fill").font(.headline)
                    }
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Diriger

    @ViewBuilder
    private func mouvement(_ s: SecteEtat, _ j: Joueur) -> some View {
        let d = SecteCatalogue.doctrine(s.doctrineId)
        let enPrison = j.vieEtat.justice.enPrison
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: d?.icone ?? "flame.fill").foregroundStyle(Theme.accent)
                    Text(s.nom).font(.title3.bold())
                }
                Text("\(d?.nom ?? "Doctrine") · \(SecteMoteur.stade(s)) · \(SecteMoteur.titre(s, j)) depuis \(s.annees) an\(s.annees > 1 ? "s" : "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Group {
                ligne("Membres", "\(s.adeptes) \(d?.adeptesNom ?? "adeptes")", "person.3.fill")
                ligne("Caisse du mouvement", Format.argent(s.tresor), "banknote.fill")
                ligne("Lieu", s.lieu.nom, "building.columns.fill")
                ligne("Contribution", SecteMoteur.nomsContribution[min(3, max(0, s.contribution))], "hand.raised.fill")
            }
            Group {
                JaugeModule(titre: "Ferveur", icone: "flame.fill", valeur: s.ferveur)
                JaugeModule(titre: "Notoriété", icone: "megaphone.fill", valeur: s.notoriete)
                JaugeModule(titre: "Dérive", icone: "exclamationmark.triangle.fill", valeur: s.derive, inverse: true)
                JaugeModule(titre: "Surveillance", icone: "eye.fill", valeur: s.surveillance, inverse: true)
            }
            if s.enquete > 0 {
                ligne("Justice", SecteMoteur.nomsEnquete[min(4, s.enquete)], "building.columns")
                ligne("Défense", ["Aucun avocat", "Un pénaliste", "Un cabinet réputé", "Les meilleurs du pays"][min(3, s.defense)], "briefcase.fill")
            }
            if s.reglesStrictes {
                Text("Règles strictes en vigueur : isolement, contrôle, rapports.").font(.caption).foregroundStyle(.red)
            }
            if SecteMoteur.pleinTemps(s) {
                Text("Le mouvement occupe tout ton temps : pas de métier à côté.").font(.caption).foregroundStyle(.secondary)
            }
        }
        if let b = s.bilan {
            Section("L'an dernier") {
                ligne("Nouveaux membres", "+\(b.nouveaux)", "person.badge.plus")
                ligne("Départs", "−\(b.departs)", "person.badge.minus")
                ligne("Dons", Format.argent(b.dons), "arrow.down.circle.fill")
                ligne("Charges", Format.argent(b.charges), "arrow.up.circle.fill")
            }
        }

        Section {
            action(.precher, "Prêcher", "Réunion publique, conférence, témoignages. Attire des membres.", "music.mic")
            action(.retraite, "Organiser une retraite payante", "Remplit la caisse et soude le groupe.", "tent.fill")
            action(.communication, "Campagne de communication", "Livre, vidéos, plateau télé. Notoriété et recrues, mais on te regarde.", "megaphone.fill")
            if s.reglesStrictes {
                action(.ouvrir, "Ouvrir les portes", "Familles bienvenues, comptes publiés. Moins d'emprise, moins de membres.", "door.left.hand.open")
            } else {
                action(.durcir, "Durcir les règles", "Isolement, contrôle des téléphones. Ferveur en hausse, dérive aussi.", "lock.fill")
            }
            if s.enquete > 0 && s.defense < 3 {
                action(.defense, "Engager des avocats", "Coût : \(Format.argent(SecteMoteur.coutsDefense[s.defense])). Réduit le risque de prison.", "briefcase.fill")
            }
            Menu {
                Button("Modeste (salaire raisonnable)") { message = engine.secteAgir(.remuneration(1)) }
                Button("Un quart de la caisse") { message = engine.secteAgir(.remuneration(2)) }
                Button("Te servir largement (60 %)", role: .destructive) { message = engine.secteAgir(.remuneration(3)) }
            } label: {
                Label("Te verser de l'argent", systemImage: "eurosign.circle.fill")
            }
            .disabled(enPrison || s.actionsAnnee.contains("remuneration"))
        } header: {
            Text("Cette année")
        } footer: {
            Text("Chaque action une fois par an. Une carte du mouvement peut aussi arriver au passage d'année.")
        }

        Section("Contribution demandée") {
            Picker("Contribution", selection: Binding(get: { s.contribution }, set: { engine.secteContribution($0) })) {
                ForEach(0..<4, id: \.self) { i in Text(SecteMoteur.nomsContribution[i]).tag(i) }
            }
            .pickerStyle(.segmented)
            Text("Plus la contribution est forte, plus la caisse se remplit… et plus les départs, la dérive et les plaintes augmentent.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Lieu") {
            ForEach(SecteLieu.allCases) { lieu in
                Button {
                    message = engine.secteDemenager(lieu)
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lieu.nom).font(.headline).foregroundStyle(Theme.encre)
                            Text(lieu.description).font(.caption).foregroundStyle(.secondary)
                            if lieu.rang > s.lieu.rang {
                                Text("Installation : \(Format.argent(lieu.prix)) · charges \(Format.argent(lieu.charges))/an").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if lieu == s.lieu { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                    }
                }
                .disabled(lieu == s.lieu || enPrison)
            }
        }

        Section("Proches") {
            let membres = j.relations.filter { s.prochesIds.contains($0.id) && $0.vivant }
            if membres.isEmpty {
                Text("Aucun de tes proches n'est membre.").foregroundStyle(.secondary)
            }
            ForEach(membres) { r in
                ligne(r.libelle, r.prenom, "person.fill")
            }
            let recrutables = engine.secteProchesRecrutables()
            if !recrutables.isEmpty {
                Menu {
                    ForEach(recrutables) { r in
                        Button("\(r.libelle) : \(r.prenom)") { message = engine.secteAgir(.recruterProche(r.id)) }
                    }
                } label: {
                    Label("Faire entrer un proche", systemImage: "person.badge.plus")
                }
                .disabled(enPrison || s.actionsAnnee.contains("recruter"))
            }
        }

        Section {
            Button("Dissoudre le mouvement", role: .destructive) { confirmerDissolution = true }
                .disabled(enPrison)
        }
    }

    @ViewBuilder
    private func anciennes(_ j: Joueur) -> some View {
        let liste = j.sectes?.anciennes ?? []
        if !liste.isEmpty {
            Section("Anciens mouvements") {
                ForEach(liste) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.nom).font(.headline)
                        Text("De \(a.ageDebut) à \(a.ageFin) ans · jusqu'à \(a.adeptesMax) membres · \(Self.libelleFin(a.fin))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Petits morceaux

    private func ligne(_ titre: String, _ valeur: String, _ icone: String) -> some View {
        HStack {
            Label(titre, systemImage: icone).foregroundStyle(Theme.encre)
            Spacer()
            Text(valeur).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }

    private func action(_ a: SecteAction, _ titre: String, _ sousTitre: String, _ icone: String) -> some View {
        let s = engine.joueur?.sectes?.actuelle
        let fait = s?.actionsAnnee.contains(a.cle) ?? true
        let enPrison = engine.joueur?.vieEtat.justice.enPrison ?? false
        return LigneAction(titre: titre, sousTitre: fait ? "Déjà fait cette année" : sousTitre, icone: icone, actif: !fait && !enPrison) {
            message = engine.secteAgir(a)
        }
    }

    static func libelleFin(_ fin: String) -> String {
        switch fin {
        case "justice": return "dissous par la justice"
        case "abandon": return "éteint faute de membres"
        case "mort": return "jusqu'à ta mort"
        default: return "dissous par toi"
        }
    }
}

import SwiftUI

/// Écran « Retraite » : maison de retraite, loto, résidents, évasion, petits-enfants, voyages.
///
/// Branchement (fil moteur), une fois `var retraite: RetraiteEtat?` ajouté à `Joueur` :
/// `RetraiteView(chemin: \.retraite)`, ou avec les répercussions :
/// `RetraiteView(chemin: \.retraite) { signal, j in /* Repercussions.signaler(signal, …) */ }`
struct RetraiteView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    /// Où l'état du module est rangé dans le joueur.
    let chemin: WritableKeyPath<Joueur, RetraiteEtat?>
    /// Appelé pour chaque signal émis par une action (pour le module Répercussions).
    var signaler: (String, inout Joueur) -> Void = { _, _ in }

    @State private var message: String?
    @State private var choixLoto = false

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let e = j[keyPath: chemin] ?? RetraiteEtat()
                    if j.age < RetraiteSysteme.ageOnglet {
                        Text("Reviens après \(RetraiteSysteme.ageOnglet) ans. Pour l'instant, la seule résidence qui t'accueille, c'est ton canapé.")
                            .foregroundStyle(.secondary)
                    } else {
                        situation(j, e)
                        sectionResidence(j, e)
                        sectionLoisirs(j, e)
                        if e.enResidence { sectionResidents(j, e) }
                        if !e.petitsEnfants.isEmpty { sectionPetitsEnfants(j, e) }
                        sectionVoyages(j, e)
                    }
                }
            }
            .navigationTitle("Retraite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .confirmationDialog("Combien de cartons ?", isPresented: $choixLoto, titleVisibility: .visible) {
                Button("1 carton (\(Format.argent(RetraiteSysteme.prixCarton)))") { jouerLoto(1, triche: false) }
                Button("3 cartons (\(Format.argent(3 * RetraiteSysteme.prixCarton)))") { jouerLoto(3, triche: false) }
                Button("6 cartons, mode guerrier (\(Format.argent(6 * RetraiteSysteme.prixCarton)))") { jouerLoto(6, triche: false) }
                Button("3 cartons… dont un pré-rempli", role: .destructive) { jouerLoto(3, triche: true) }
                Button("Annuler", role: .cancel) {}
            }
        }
        .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - Actions

    @MainActor
    private func agir(_ action: (inout Joueur, inout RetraiteEtat) -> RetraiteResultat) {
        var resultat: RetraiteResultat?
        let chemin = self.chemin
        let signaler = self.signaler
        engine.modifier { j in
            var e = j[keyPath: chemin] ?? RetraiteEtat()
            let r = action(&j, &e)
            j[keyPath: chemin] = e
            for s in r.signaux { signaler(s, &j) }
            if !r.texte.isEmpty {
                if j.journal.isEmpty { j.journal.append(Annee(age: j.age, lignes: [])) }
                j.journal[j.journal.count - 1].lignes.append(r.texte)
            }
            resultat = r
        }
        message = resultat?.texte
    }

    @MainActor
    private func jouerLoto(_ cartons: Int, triche: Bool) {
        agir { j, e in RetraiteSysteme.loto(&j, &e, cartons: cartons, triche: triche) }
    }

    // MARK: - Sections

    private func situation(_ j: Joueur, _ e: RetraiteEtat) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                if let r = e.residence {
                    Text(r.nom).font(.headline)
                    Text(e.imposee ? "Placé\(j.genre == .femme ? "e" : "") par ta famille. Tu n'as pas eu ton mot à dire."
                                   : "Tu as choisi d'y vivre. Tu peux partir quand tu veux.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Depuis \(e.anneesEnResidence) an\(e.anneesEnResidence > 1 ? "s" : "") · \(Format.argent(r.prixAnnuel))/an")
                        .font(.caption).foregroundStyle(.secondary)
                    if e.tunnel > 0 {
                        Text("Tunnel secret : \(e.tunnel) %").font(.caption.bold()).foregroundStyle(Theme.accent)
                    }
                } else if e.enCavale {
                    Text("En cavale 🏃").font(.headline)
                    Text("Depuis \(e.anneesCavale) an\(e.anneesCavale > 1 ? "s" : ""). Encore \(max(0, RetraiteSysteme.anneesAvantLiberte - e.anneesCavale)) an(s) avant qu'on arrête de te chercher.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Tu vis chez toi").font(.headline)
                    Text(j.age >= RetraiteSysteme.agePlacement && j.relations.contains(where: { $0.type == .enfant && $0.vivant })
                         ? "Tes enfants regardent des brochures de maisons de retraite. Méfiance."
                         : "Libre comme l'air, avec tes pantoufles.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if e.lotoGains > 0 {
                    Text("Loto : \(e.lotoGains) victoire\(e.lotoGains > 1 ? "s" : "") en \(e.lotoParties) partie\(e.lotoParties > 1 ? "s" : "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func sectionResidence(_ j: Joueur, _ e: RetraiteEtat) -> some View {
        Section("Maison de retraite") {
            if e.enCavale {
                LigneAction(titre: "Te rendre", sousTitre: "Rentrer à la résidence avec des croissants.", icone: "flag.fill") {
                    agir { j, e in RetraiteSysteme.seRendre(&j, &e) }
                }
            } else if e.enResidence {
                if e.imposee {
                    LigneAction(titre: "Négocier ta sortie", sousTitre: "Convaincre tes enfants. Une fois par an.",
                                icone: "person.2.wave.2.fill", actif: !j.actionsAnnee.contains("ret_negocier")) {
                        agir { j, e in RetraiteSysteme.negocierSortie(&j, &e) }
                    }
                } else {
                    LigneAction(titre: "Quitter la résidence", sousTitre: "Rendre ta chambre et rentrer chez toi.", icone: "door.left.hand.open") {
                        agir { j, e in RetraiteSysteme.quitter(&j, &e) }
                    }
                }
                NavigationLink {
                    RetraiteEvasionView(agir: { action in agir(action) })
                } label: {
                    Label("Préparer une évasion", systemImage: "figure.run")
                }
            } else if RetraiteSysteme.peutVisiterResidences(j, e) {
                NavigationLink {
                    RetraiteResidencesView(agir: { action in agir(action) })
                } label: {
                    Label("Visiter des résidences", systemImage: "building.2.fill")
                }
            } else {
                Text("Les résidences t'ouvrent leurs portes à \(RetraiteSysteme.ageEntreeChoisie) ans.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func sectionLoisirs(_ j: Joueur, _ e: RetraiteEtat) -> some View {
        Section(e.enResidence ? "La vie à la résidence" : "Club des seniors") {
            if e.enResidence || j.age >= RetraiteSysteme.ageEntreeChoisie {
                LigneAction(titre: RetraiteSysteme.nomLoto(e),
                            sousTitre: RetraiteSysteme.lotoBanni(j, e) ? "Tu es interdit\(j.genre == .femme ? "e" : "") de loto. Tu sais pourquoi."
                                                                     : "Cartons à \(Format.argent(RetraiteSysteme.prixCarton)). Une soirée par an.",
                            icone: "circle.grid.3x3.fill",
                            actif: RetraiteSysteme.lotoDisponible(j, e)) {
                    choixLoto = true
                }
            }
            ForEach(RetraiteSysteme.activitesVisibles(j, e)) { a in
                LigneAction(titre: a.titre,
                            sousTitre: a.description + ((a.cout ?? 0) > 0 ? " · \(Format.argent(a.cout ?? 0))" : ""),
                            icone: a.icone,
                            actif: RetraiteSysteme.activiteDisponible(a, j)) {
                    agir { j, e in RetraiteSysteme.faireActivite(a, &j, &e) }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionResidents(_ j: Joueur, _ e: RetraiteEtat) -> some View {
        Section("Résidents") {
            ForEach(e.residentsVivants) { r in
                NavigationLink {
                    RetraiteResidentView(chemin: chemin, residentId: r.id, agir: { action in agir(action) })
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(r.nomComplet).font(.subheadline.bold())
                            if r.statut.estRomance { Image(systemName: "heart.fill").foregroundStyle(.pink) }
                            if r.complice { Image(systemName: "key.fill").foregroundStyle(.orange) }
                            Spacer()
                            Text("\(r.age) ans").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(r.statut.libelle + " · " + RetraiteSysteme.trait(r))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        BarreStat(titre: "Lien", icone: "heart", valeur: r.lien)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionPetitsEnfants(_ j: Joueur, _ e: RetraiteEtat) -> some View {
        Section("Petits-enfants") {
            ForEach(e.petitsEnfants) { pe in
                let fille = pe.genre == .femme
                let visite: String = pe.derniereVisite.map { " · dernière visite à tes \($0) ans" } ?? (fille ? " · jamais venue" : " · jamais venu")
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(pe.prenom).font(.subheadline.bold())
                        Spacer()
                        Text("\(pe.age) an\(pe.age > 1 ? "s" : "")").font(.caption).foregroundStyle(.secondary)
                    }
                    Text((fille ? "Fille de " : "Fils de ") + pe.parentPrenom + visite)
                        .font(.caption).foregroundStyle(.secondary)
                    BarreStat(titre: "Lien", icone: "heart", valeur: pe.lien)
                }
            }
            LigneAction(titre: "Les appeler", sousTitre: "Tomber sur la messagerie, sans doute.", icone: "phone.fill",
                        actif: !j.actionsAnnee.contains("ret_appel")) {
                agir { j, e in RetraiteSysteme.appeler(&j, &e) }
            }
            LigneAction(titre: "Envoyer une carte avec un billet", sousTitre: "20 € par petit-enfant.", icone: "envelope.fill",
                        actif: !j.actionsAnnee.contains("ret_carte")) {
                agir { j, e in RetraiteSysteme.envoyerCarte(&j, &e) }
            }
            LigneAction(titre: "Parler de l'héritage", sousTitre: "Les visites vont soudain reprendre. Le karma, moins.", icone: "banknote.fill",
                        actif: !j.actionsAnnee.contains("ret_heritage")) {
                agir { j, e in RetraiteSysteme.evoquerHeritage(&j, &e) }
            }
        }
    }

    @ViewBuilder
    private func sectionVoyages(_ j: Joueur, _ e: RetraiteEtat) -> some View {
        Section("Voyages de retraités") {
            ForEach(RetraiteCatalogue.voyages.filter { j.age >= ($0.ageMin ?? 60) }) { v in
                LigneAction(titre: v.titre, sousTitre: v.description + " · \(Format.argent(v.cout))", icone: v.icone,
                            actif: RetraiteSysteme.voyageDisponible(v, j)) {
                    agir { j, e in RetraiteSysteme.partirEnVoyage(v, &j, &e) }
                }
            }
        }
    }
}

/// Type des actions passées aux sous-écrans.
typealias RetraiteAgir = ((inout Joueur, inout RetraiteEtat) -> RetraiteResultat) -> Void

// MARK: - Choisir une résidence

struct RetraiteResidencesView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let agir: RetraiteAgir
    @State private var choisie: RetraiteResidence?

    var body: some View {
        List {
            Section {
                Text("La pension se paie chaque année. Si tu n'as plus d'argent, tes enfants paieront (en râlant) ou l'aide sociale te transférera.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(RetraiteCatalogue.residences) { r in
                Button { choisie = r } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(r.nom).font(.subheadline.bold()).foregroundStyle(Theme.encre)
                            Spacer()
                            Text(Format.argent(r.prixAnnuel) + "/an").font(.caption.bold())
                                .foregroundStyle((engine.joueur?.argent ?? 0) >= r.prixAnnuel ? Theme.encre : .red)
                        }
                        Text(r.description).font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            jauge("Confort", r.confort)
                            jauge("Ambiance", r.ambiance)
                            jauge("Surveillance", r.surveillance)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Résidences")
        .confirmationDialog(choisie.map { "T'installer à \($0.nom) ?" } ?? "",
                            isPresented: Binding(get: { choisie != nil }, set: { if !$0 { choisie = nil } }),
                            titleVisibility: .visible) {
            if let r = choisie {
                Button("Emménager (\(Format.argent(r.prixAnnuel))/an)") {
                    agir { j, e in RetraiteSysteme.sInstaller(r, &j, &e) }
                    choisie = nil
                    dismiss()
                }
            }
            Button("Annuler", role: .cancel) { choisie = nil }
        }
    }

    private func jauge(_ titre: String, _ valeur: Int) -> some View {
        HStack(spacing: 3) {
            Text(titre).font(.caption2).foregroundStyle(.secondary)
            Text(String(repeating: "●", count: max(1, (valeur + 19) / 20)))
                .font(.caption2).foregroundStyle(Theme.couleurStat(valeur))
        }
    }
}

// MARK: - Évasion

struct RetraiteEvasionView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let agir: RetraiteAgir

    var body: some View {
        List {
            if let j = engine.joueur {
                Section {
                    Text(j.actionsAnnee.contains("ret_evasion")
                         ? "Tu as déjà tenté ta chance cette année. Fais profil bas jusqu'à l'an prochain."
                         : "Une tentative par an. Un·e complice parmi les résidents augmente tes chances.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Plans") {
                    ForEach(RetraiteSysteme.MethodeEvasion.allCases) { m in
                        LigneAction(titre: m.titre,
                                    sousTitre: m.description + (m.cout > 0 ? " · \(Format.argent(m.cout))" : "") + " · " + chance(m, j),
                                    icone: m.icone,
                                    actif: !j.actionsAnnee.contains("ret_evasion")) {
                            agir { j, e in RetraiteSysteme.evasion(m, &j, &e) }
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle("Évasion")
    }

    private func chance(_ m: RetraiteSysteme.MethodeEvasion, _ j: Joueur) -> String {
        guard m != .tunnel else { return "réussite garantie… un jour" }
        // L'état exact n'est pas accessible ici : estimation à partir de la santé seulement.
        let c = m.base + Double(j.stats.sante - 50) / 250 - 0.2
        switch c {
        case ..<0.2: return "chances : maigres"
        case ..<0.4: return "chances : correctes"
        default: return "chances : bonnes"
        }
    }
}

// MARK: - Un résident

struct RetraiteResidentView: View {
    @EnvironmentObject var engine: GameEngine
    let chemin: WritableKeyPath<Joueur, RetraiteEtat?>
    let residentId: UUID
    let agir: RetraiteAgir

    var body: some View {
        List {
            if let j = engine.joueur,
               let r = (j[keyPath: chemin] ?? RetraiteEtat()).residents.first(where: { $0.id == residentId }) {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(r.nomComplet).font(.title3.bold())
                        Text("\(r.age) ans · \(r.statut.libelle)").font(.subheadline).foregroundStyle(.secondary)
                        Text(r.prenom + " " + RetraiteSysteme.trait(r) + ".").font(.subheadline)
                        BarreStat(titre: "Lien", icone: "heart", valeur: r.lien)
                        if r.complice { Label("Complice pour ton évasion", systemImage: "key.fill").font(.caption).foregroundStyle(.orange) }
                    }
                    .padding(.vertical, 4)
                }
                if r.vivant {
                    Section("Que faire ?") {
                        ForEach(RetraiteSysteme.interactionsPossibles(r)) { action in
                            LigneAction(titre: action.titre, icone: action.icone,
                                        actif: RetraiteSysteme.interactionDisponible(r, j)) {
                                agir { j, e in RetraiteSysteme.interagir(action, avec: residentId, &j, &e) }
                            }
                        }
                    }
                } else {
                    Text("\(r.prenom) n'est plus là. Sa chaise reste vide, sauf le jeudi.").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Résident")
    }
}

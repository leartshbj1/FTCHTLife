import SwiftUI

// Module « Voyages sur mesure » : écrans.
// Menu Activités → Voyager → Voyage sur mesure (`ModuleJeu.voyages`) et Boutique → Chez toi.

/// Écran du menu (avec sa barre et son bouton Fermer).
struct VoyagesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VoyagesListe()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
                }
        }
    }
}

/// Accueil : partir, et le carnet de voyages.
struct VoyagesListe: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        List {
            if let j = engine.joueur {
                let etat = j.voyages ?? VoyagesEtat()
                Section {
                    if let raison = VoyMoteur.verrou(j) {
                        Label(raison, systemImage: "lock.fill").foregroundStyle(.secondary)
                    } else {
                        NavigationLink {
                            VoyChoixPaysView()
                        } label: {
                            Label("Organiser un voyage", systemImage: "map.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    NavigationLink {
                        ShopTravelView()
                    } label: {
                        Label("Séjours tout faits (agence)", systemImage: "airplane.departure")
                    }
                } footer: {
                    Text("Choisis le pays, le transport (ta voiture, ton bateau, ton jet…), l'hébergement et les proches qui viennent. \(VoyMoteur.maxParAn) voyages sur mesure par an.")
                }

                Section("Carnet de voyages") {
                    HStack {
                        statistique("\(etat.recits.count)", "voyage\(etat.recits.count > 1 ? "s" : "")")
                        Divider()
                        statistique("\(etat.pays.count)", "pays")
                        Divider()
                        statistique("\(etat.recits.map(\.jours).reduce(0, +))", "jours")
                    }
                    if etat.recits.isEmpty {
                        Text("Pas encore de tampon sur ton passeport.").foregroundStyle(.secondary)
                    } else {
                        Text(drapeaux(etat)).font(.title2)
                    }
                }

                if !etat.recits.isEmpty {
                    Section("Tes voyages") {
                        ForEach(etat.recits.reversed()) { r in
                            NavigationLink {
                                VoyRecitView(recit: r)
                            } label: {
                                ligneRecit(r)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Voyages")
    }

    private func statistique(_ valeur: String, _ titre: String) -> some View {
        VStack(spacing: 2) {
            Text(valeur).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(Theme.encre)
            Text(titre).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func drapeaux(_ e: VoyagesEtat) -> String {
        e.pays.keys.sorted().compactMap { VoyCatalogue.shared.destination($0)?.drapeau }.joined(separator: " ")
    }

    private func ligneRecit(_ r: VoyRecit) -> some View {
        let d = VoyCatalogue.shared.destination(r.pays)
        return HStack(spacing: 12) {
            Text(d?.drapeau ?? "🌍").font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(r.ville), \(d?.nom ?? r.pays)").fontWeight(.semibold).foregroundStyle(Theme.encre)
                Text("À \(r.age) ans · \(r.jours) jours · " + (r.compagnons.isEmpty ? "en solo" : VoyMoteur.liste(r.compagnons)))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }
}

/// Détail d'un voyage passé.
struct VoyRecitView: View {
    let recit: VoyRecit

    var body: some View {
        let d = VoyCatalogue.shared.destination(recit.pays)
        List {
            Section {
                HStack(spacing: 14) {
                    Text(d?.drapeau ?? "🌍").font(.system(size: 48))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(recit.ville), \(d?.nom ?? recit.pays)").font(.headline)
                        Text("À \(recit.age) ans, \(recit.jours) jours").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Le voyage") {
                ShopInfoRow(titre: "Transport", valeur: recit.transport, icone: "airplane")
                ShopInfoRow(titre: "Hébergement", valeur: recit.hebergement, icone: "bed.double.fill")
                ShopInfoRow(titre: "Avec", valeur: recit.compagnons.isEmpty ? "Personne" : VoyMoteur.liste(recit.compagnons), icone: "person.2.fill")
                ShopInfoRow(titre: "Coût pour toi", valeur: Format.argent(recit.cout), icone: "eurosign.circle.fill")
            }
            Section("Souvenirs") {
                if recit.souvenirs.isEmpty {
                    Text("Rien de notable. Parfois, c'est ça les meilleures vacances.").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(recit.souvenirs.enumerated()), id: \.offset) { _, s in
                        Label(s, systemImage: "camera.fill")
                    }
                }
            }
        }
        .navigationTitle(d?.nom ?? "Voyage")
    }
}

// MARK: - Choisir le pays

struct VoyChoixPaysView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var recherche = ""

    var body: some View {
        let toutes = VoyCatalogue.shared.destinations
        let filtre = recherche.trimmingCharacters(in: .whitespaces).lowercased()
        let liste = filtre.isEmpty ? toutes : toutes.filter {
            $0.nom.lowercased().contains(filtre) || $0.villes.contains { $0.lowercased().contains(filtre) }
        }
        let visites = engine.joueur?.voyages?.pays ?? [:]
        List {
            ForEach(VoyCatalogue.continents) { c in
                let pays = liste.filter { $0.continent == c.id }
                if !pays.isEmpty {
                    Section(c.nom) {
                        ForEach(pays) { d in
                            NavigationLink {
                                VoyPlanView(destination: d)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(d.drapeau).font(.title)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(d.nom).fontWeight(.semibold).foregroundStyle(Theme.encre)
                                            if let n = visites[d.id], n > 0 {
                                                Text("✓ \(n)×").font(.caption2.weight(.bold)).foregroundStyle(Theme.argentPositif)
                                            }
                                        }
                                        Text(d.presentation).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $recherche, prompt: "Pays ou ville")
        .navigationTitle("Où partir ?")
    }
}

// MARK: - Organiser le voyage

struct VoyPlanView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let destination: VoyDestination

    @State private var ville: String = ""
    @State private var duree: VoyDuree = .semaine
    @State private var hebergement: VoyHebergement = .hotel
    @State private var transportId: String?
    @State private var invites: Set<UUID> = []
    @State private var jInvite = true
    @State private var voyage: VoyEnCours?

    var body: some View {
        Group {
            if let j = engine.joueur {
                formulaire(j)
            } else {
                Text("Aucune vie en cours.")
            }
        }
        .navigationTitle(destination.nom)
        .onAppear { if ville.isEmpty { ville = destination.villes.first ?? destination.nom } }
        .sheet(isPresented: Binding(get: { voyage != nil }, set: { if !$0 { voyage = nil; dismiss() } })) {
            if let v = voyage {
                VoyDeroulementView(depart: v).environmentObject(engine)
            }
        }
    }

    private func proches(_ j: Joueur) -> [Relation] {
        VoyMoteur.prochesPossibles(j).filter { invites.contains($0.id) }
    }

    @ViewBuilder
    private func formulaire(_ j: Joueur) -> some View {
        let compagnons = proches(j)
        let options = VoyMoteur.optionsTransport(destination, j, voyageurs: 1 + compagnons.count, jours: duree.jours)
        let option = options.first { $0.id == transportId }
        let devis = option.map {
            VoyMoteur.devis(destination, option: $0, hebergement: hebergement, duree: duree, compagnons: compagnons,
                            invite: jInvite, j)
        }
        let souci: String? = {
            guard let o = option, let dv = devis else { return "Choisis un moyen de transport." }
            return VoyMoteur.probleme(destination, option: o, hebergement: hebergement, compagnons: compagnons, devis: dv, j)
        }()
        Form {
            Section {
                HStack(spacing: 14) {
                    Text(destination.drapeau).font(.system(size: 46))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(destination.presentation).font(.callout)
                        Text("À voir : " + destination.incontournables.prefix(3).joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Picker("Ville", selection: $ville) {
                    ForEach(destination.villes, id: \.self) { Text($0).tag($0) }
                }
                Picker("Durée", selection: $duree) {
                    ForEach(VoyDuree.allCases) { Text($0.nom).tag($0) }
                }
            }
            sectionProches(j, compagnons)
            sectionHebergement(j, compagnons.count)
            sectionTransport(options)
            sectionDevis(devis, souci)
        }
    }

    @ViewBuilder
    private func sectionProches(_ j: Joueur, _ compagnons: [Relation]) -> some View {
        let possibles = VoyMoteur.prochesPossibles(j)
        Section {
            if possibles.isEmpty {
                Text("Personne à emmener. Le voyage en solo, ça forge.").foregroundStyle(.secondary)
            }
            ForEach(possibles) { r in
                Toggle(isOn: Binding(get: { invites.contains(r.id) }, set: { oui in
                    if oui { if invites.count < VoyMoteur.maxCompagnons { invites.insert(r.id) } } else { invites.remove(r.id) }
                })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(r.prenom), \(r.libelle.lowercased())").foregroundStyle(Theme.encre)
                        Text("\(r.age) ans · lien \(r.lien) %").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tint(Theme.accent)
            }
            if !compagnons.isEmpty && j.age >= 18 {
                Picker("Qui paie ?", selection: $jInvite) {
                    Text("J'invite tout le monde").tag(true)
                    Text("Chacun paie sa part").tag(false)
                }
            }
        } header: {
            Text("Qui vient ? (\(compagnons.count)/\(VoyMoteur.maxCompagnons))")
        } footer: {
            Text(j.age < 18 ? "Avant 18 ans, un parent doit venir. Ce sont tes parents qui paient." : "Inviter rapproche plus que de faire les comptes.")
        }
    }

    @ViewBuilder
    private func sectionHebergement(_ j: Joueur, _ nbProches: Int) -> some View {
        Section("Hébergement") {
            ForEach(VoyHebergement.allCases) { h in
                Button {
                    hebergement = h
                } label: {
                    HStack {
                        Label(h.nom, systemImage: h.icone).foregroundStyle(j.age < h.ageMin ? Color.secondary : Theme.encre)
                        Spacer()
                        Text("\(Format.argent(Int(Double(destination.prixJour) * h.multiplicateur))) / nuit")
                            .font(.caption).foregroundStyle(.secondary)
                        if hebergement == h {
                            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                        }
                    }
                }
                .disabled(j.age < h.ageMin)
            }
        }
    }

    @ViewBuilder
    private func sectionTransport(_ options: [VoyOptionTransport]) -> some View {
        let perso = options.filter { $0.vehiculeId != nil }
        let publics = options.filter { $0.vehiculeId == nil }
        if !perso.isEmpty {
            Section("Tes véhicules") {
                ForEach(perso) { ligneTransport($0) }
            }
        }
        Section("Transports") {
            ForEach(publics.filter { $0.raison == nil }) { ligneTransport($0) }
            ForEach(publics.filter { $0.raison != nil }) { ligneTransport($0) }
        }
    }

    private func ligneTransport(_ o: VoyOptionTransport) -> some View {
        Button {
            transportId = o.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: o.type.icone).frame(width: 26).foregroundStyle(o.raison == nil ? Theme.accent : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(o.nom).fontWeight(.semibold).foregroundStyle(o.raison == nil ? Theme.encre : Color.secondary)
                    Text(o.raison ?? o.detail).font(.caption)
                        .foregroundStyle(o.raison == nil ? Color.secondary : Theme.argentNegatif)
                        .lineLimit(2)
                }
                Spacer()
                if transportId == o.id {
                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                }
            }
        }
        .disabled(o.raison != nil)
    }

    @ViewBuilder
    private func sectionDevis(_ devis: VoyDevis?, _ souci: String?) -> some View {
        Section("Devis") {
            if let dv = devis {
                ShopInfoRow(titre: "Transport (aller-retour)", valeur: Format.argent(dv.transport), icone: "airplane")
                ShopInfoRow(titre: "Hébergement et repas", valeur: Format.argent(dv.hebergement), icone: "bed.double.fill")
                if dv.equipage > 0 {
                    ShopInfoRow(titre: "Équipage", valeur: Format.argent(dv.equipage), icone: "person.badge.key.fill")
                }
                ShopInfoRow(titre: "Total", valeur: Format.argent(dv.total), icone: "sum")
                ShopInfoRow(titre: dv.parLesParents ? "Payé par tes parents" : "Ta part",
                            valeur: Format.argent(dv.parLesParents ? dv.total : dv.partJoueur), icone: "creditcard.fill")
            }
            if let s = souci {
                Text(s).font(.callout).foregroundStyle(Theme.argentNegatif)
            }
            Button {
                partir()
            } label: {
                Label("Partir \(destination.enPays)", systemImage: "suitcase.rolling.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(souci != nil)
        }
    }

    private func partir() {
        guard let j = engine.joueur else { return }
        let compagnons = proches(j)
        let options = VoyMoteur.optionsTransport(destination, j, voyageurs: 1 + compagnons.count, jours: duree.jours)
        guard let o = options.first(where: { $0.id == transportId }) else { return }
        Vibration.moyenne()
        voyage = VoyMoteur.partir(destination, ville: ville, option: o, hebergement: hebergement, duree: duree,
                                  compagnons: compagnons, invite: jInvite || j.age < 18, engine: engine)
    }
}

// MARK: - Pendant le voyage

struct VoyDeroulementView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var v: VoyEnCours

    init(depart: VoyEnCours) {
        _v = State(initialValue: depart)
    }

    private var mort: Bool { engine.joueur?.vivant == false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    entete
                    if mort {
                        carte(titre: "Fin du voyage", texte: "Ce voyage a été ton dernier.")
                        Button("Fermer") { dismiss() }.buttonStyle(.borderedProminent).tint(Theme.accent)
                    } else if v.moments.indices.contains(v.index) {
                        moment(v.moments[v.index])
                    } else {
                        bilan
                    }
                }
                .padding(20)
            }
            .background(Theme.fond.ignoresSafeArea())
            .navigationTitle("\(v.destination.drapeau) \(v.ville)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(!v.termine && !mort)
        .onDisappear {
            if !v.termine && !mort { VoyMoteur.terminer(&v, engine: engine) }
        }
    }

    private var entete: some View {
        VStack(spacing: 6) {
            Text(v.destination.drapeau).font(.system(size: 54))
            Text("\(v.duree.nom) \(v.destination.enPays)").font(.title3.weight(.bold)).foregroundStyle(Theme.encre)
            Text("\(v.option.nom) · \(v.hebergement.nom)").font(.caption).foregroundStyle(.secondary)
            if !v.moments.isEmpty && v.index < v.moments.count {
                Text("Moment \(v.index + 1) sur \(v.moments.count)").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
            }
        }
    }

    private func titrePhase(_ p: String) -> String {
        switch p {
        case "trajet": return "En route"
        case "retour": return "Le retour"
        default: return "Sur place"
        }
    }

    @ViewBuilder
    private func moment(_ m: VoyMomentAffiche) -> some View {
        carte(titre: titrePhase(m.moment.phase), texte: m.texte)
        if let r = m.resultat {
            carte(titre: nil, texte: r)
            Button {
                withAnimation { v.index += 1 }
            } label: {
                Text("Continuer").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        } else {
            ForEach(m.choix) { c in
                Button {
                    Vibration.legere()
                    _ = VoyMoteur.choisir(c.index, voyage: &v, engine: engine)
                } label: {
                    Text(c.label).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
        }
    }

    @ViewBuilder
    private var bilan: some View {
        if v.termine {
            carte(titre: "De retour !", texte: v.recit)
            if !v.souvenirs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Souvenirs").font(.headline).foregroundStyle(Theme.encre)
                    ForEach(Array(v.souvenirs.enumerated()), id: \.offset) { _, s in
                        Label(s, systemImage: "camera.fill").font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.carte, in: RoundedRectangle(cornerRadius: 16))
            }
            Button {
                dismiss()
            } label: {
                Text("Rentrer à la maison").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        } else {
            ProgressView()
                .onAppear { VoyMoteur.terminer(&v, engine: engine) }
        }
    }

    private func carte(titre: String?, texte: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let t = titre {
                Text(t.uppercased()).font(.caption.weight(.heavy)).foregroundStyle(Theme.accent)
            }
            Text(texte).font(.body).foregroundStyle(Theme.encre).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.carte, in: RoundedRectangle(cornerRadius: 16))
    }
}

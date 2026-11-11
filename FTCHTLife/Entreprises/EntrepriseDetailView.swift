import SwiftUI

/// Fiche d'une entreprise : chiffres, crise, actions, équipe, embauche, revente.
struct EntrepriseDetailView: View {
    @EnvironmentObject var engine: GameEngine
    let entrepriseId: UUID
    @State private var message: String?
    @State private var renommer = false
    @State private var nouveauNom = ""
    @State private var choixDividende = false
    @State private var choixInjection = false
    @State private var confirmerVente = false
    @State private var confirmerFermeture = false

    private var entreprise: Entreprise? {
        engine.joueur?.entreprises?.actives.first { $0.id == entrepriseId }
    }

    var body: some View {
        List {
            if let e = entreprise, let type = EntrepriseCatalogue.type(e.typeId), let j = engine.joueur {
                entete(e, type)
                resumeRapport(e)
                EntrepriseCriseSection(entreprise: e) { texte in message = texte }
                pilotage(e, type)
                estimation(e)
                leviersMetier(e, type)
                chiffres(e, type)
                actions(e, type, j)
                equipe(e, j)
                embauche(e, type, j)
                fin(e)
            } else {
                Text("Cette boîte n'existe plus. Paix à son âme et à sa trésorerie.")
            }
        }
        .navigationTitle(entreprise?.nom ?? "Entreprise")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { engine.normaliserEntreprises() }
        .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func entete(_ e: Entreprise, _ type: EntrepriseType) -> some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: type.icone)
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.nom).font(.title3.bold())
                    Text(engine.nomDuNiveau(e)).font(.subheadline)
                    Text("\(type.nom) · \(type.secteurNom) · niveau \(e.niveau + 1)/\(EntrepriseMoteur.niveauMax + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(e.annees == 0 ? "Fondée cette année" : "Fondée il y a \(e.annees) an\(e.annees > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func chiffres(_ e: Entreprise, _ type: EntrepriseType) -> some View {
        Section("Les chiffres") {
            ligne("Trésorerie", Format.argent(e.tresorerie), rouge: e.tresorerie < 0)
            if let b = e.dernierBilan {
                ligne("Chiffre d'affaires (dernière année)", Format.argent(b.chiffreAffaires))
                ligne("Résultat (dernière année)", (b.resultat >= 0 ? "+" : "") + Format.argent(b.resultat), rouge: b.resultat < 0)
            } else {
                Text("Premier bilan à ton prochain anniversaire.").font(.caption).foregroundStyle(.secondary)
            }
            if e.dette > 0 {
                ligne("Prêt bancaire restant", Format.argent(e.dette))
            }
            ligne("Valeur estimée", Format.argent(EntrepriseMoteur.valeur(e, type)))
            BarreStat(titre: "Réputation", icone: "star.fill", valeur: e.reputation)
            if e.elan != 0 {
                ligne("Élan", "\(e.elan > 0 ? "+" : "")\(e.elan) %", rouge: e.elan < 0)
            }
            if e.anneesDansLeRouge > 0 {
                Text("⚠️ Dans le rouge : renfloue la caisse avant le prochain bilan, sinon c'est la faillite.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func actions(_ e: Entreprise, _ type: EntrepriseType, _ j: Joueur) -> some View {
        let id = e.id.uuidString
        Section("Gérer") {
            let coutPub = EntrepriseMoteur.coutPub(e, type)
            LigneAction(titre: "Faire de la pub", sousTitre: "\(Format.argent(coutPub)) · réputation et ventes en hausse",
                        icone: "megaphone.fill",
                        actif: !j.actionsAnnee.contains("ent_pub_" + id)) {
                message = engine.faireDeLaPub(e.id)
            }
            LigneAction(titre: "Bosser jour et nuit", sousTitre: "Bon pour la boîte, mauvais pour toi",
                        icone: "bolt.fill",
                        actif: !j.actionsAnnee.contains("ent_bosse_" + id)) {
                message = engine.travaillerDansSaBoite(e.id)
            }
            LigneAction(titre: "Se verser un dividende", sousTitre: "Une fois par an, 20 % d'impôts",
                        icone: "eurosign.circle.fill",
                        actif: e.tresorerie > 0 && !j.actionsAnnee.contains("ent_div_" + id)) {
                choixDividende = true
            }
            .confirmationDialog("Combien te verser ?", isPresented: $choixDividende, titleVisibility: .visible) {
                Button("25 % de la trésorerie") { message = engine.verserDividende(e.id, part: 0.25) }
                Button("50 % de la trésorerie") { message = engine.verserDividende(e.id, part: 0.5) }
                Button("Tout (100 %)") { message = engine.verserDividende(e.id, part: 1) }
                Button("Annuler", role: .cancel) {}
            }
            LigneAction(titre: "Injecter de l'argent", sousTitre: "De ton compte vers la caisse",
                        icone: "arrow.down.to.line.circle.fill",
                        actif: j.argent > 0) {
                choixInjection = true
            }
            .confirmationDialog("Combien mettre dans la caisse ?", isPresented: $choixInjection, titleVisibility: .visible) {
                ForEach(montantsInjection(e, j), id: \.self) { m in
                    Button(Format.argent(m)) { message = engine.injecterArgent(e.id, montant: m) }
                }
                Button("Annuler", role: .cancel) {}
            }
            if e.dette > 0 {
                LigneAction(titre: "Rembourser la banque", sousTitre: Format.argent(e.dette),
                            icone: "building.columns.fill",
                            actif: engine.budgetEntreprise(e) >= e.dette) {
                    message = engine.rembourserDetteEntreprise(e.id)
                }
            }
            LigneAction(titre: "Changer le nom", icone: "pencil") {
                nouveauNom = e.nom
                renommer = true
            }
            .alert("Nouveau nom", isPresented: $renommer) {
                TextField("Nom de la boîte", text: $nouveauNom)
                Button("Annuler", role: .cancel) {}
                Button("Valider") { message = engine.renommerEntreprise(e.id, nom: nouveauNom) }
            } message: {
                Text("Un rebranding fait toujours un peu perdre la tête aux clients.")
            }
        }
    }

    @ViewBuilder
    private func equipe(_ e: Entreprise, _ j: Joueur) -> some View {
        Section {
            if e.employes.isEmpty {
                Text("Personne. Tu fais tout : la caisse, le ménage, la compta et les pleurs.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(e.employes) { emp in
                Menu {
                    Button {
                        message = engine.augmenterEmploye(e.id, employe: emp.id)
                    } label: {
                        Label("Augmenter de 10 %", systemImage: "arrow.up.circle")
                    }
                    .disabled(j.actionsAnnee.contains("ent_aug_" + emp.id.uuidString))
                    Button(role: .destructive) {
                        message = engine.licencierEmploye(e.id, employe: emp.id)
                    } label: {
                        Label(emp.estProche ? "Virer (ça va jaser)" : "Virer", systemImage: "door.left.hand.open")
                    }
                } label: {
                    LigneEmploye(employe: emp)
                }
            }
        } header: {
            Text("Cadres · \(e.employes.count)/\(EntrepriseMoteur.postes(e)) postes clés")
        } footer: {
            if e.employes.count < EntrepriseMoteur.postes(e) {
                Text("Les cadres rendent toute l'équipe plus efficace. Chaque poste clé vide coûte des clients et te fatigue.")
            }
        }
    }

    @ViewBuilder
    private func embauche(_ e: Entreprise, _ type: EntrepriseType, _ j: Joueur) -> some View {
        if e.employes.count < EntrepriseMoteur.postes(e) {
            Section("Candidats de l'année") {
                ForEach(e.candidats) { c in
                    Button {
                        message = engine.embaucherCandidat(e.id, candidat: c.id)
                    } label: {
                        LigneEmploye(employe: c)
                    }
                }
            }
            let proches = EntrepriseMoteur.prochesEmbauchables(j)
            if !proches.isEmpty {
                Section {
                    ForEach(proches) { r in
                        LigneAction(titre: "\(r.prenom) (\(r.libelle.lowercased()))",
                                    sousTitre: "\(r.age) ans · lien \(r.lien) %",
                                    icone: "person.crop.circle.badge.plus") {
                            message = engine.embaucherProche(e.id, relation: r.id)
                        }
                    }
                } header: {
                    Text("Embaucher un proche")
                } footer: {
                    Text("Un proche est motivé, rarement compétent, et impossible à virer sans drame.")
                }
            }
        }
    }

    @ViewBuilder
    private func fin(_ e: Entreprise) -> some View {
        Section("Et après ?") {
            if let offre = e.offreRachat {
                LigneAction(titre: "Vendre la boîte", sousTitre: "Offre de l'année : \(Format.argent(offre))",
                            icone: "hand.wave.fill") {
                    confirmerVente = true
                }
                .confirmationDialog("Vendre « \(e.nom) » pour \(Format.argent(offre)) ?", isPresented: $confirmerVente, titleVisibility: .visible) {
                    Button("Vendre", role: .destructive) { message = engine.vendreEntreprise(e.id) }
                    Button("Annuler", role: .cancel) {}
                }
            } else {
                Text("Aucune offre de rachat cette année.").font(.caption).foregroundStyle(.secondary)
            }
            LigneAction(titre: e.tresorerie - e.dette >= 0 ? "Fermer la boîte" : "Déposer le bilan",
                        sousTitre: e.tresorerie - e.dette >= 0 ? "Tu récupères \(Format.argent(e.tresorerie - e.dette))" : "Faillite : tu paies la moitié du trou",
                        icone: "xmark.octagon.fill") {
                confirmerFermeture = true
            }
            .confirmationDialog("Fermer « \(e.nom) » pour de bon ?", isPresented: $confirmerFermeture, titleVisibility: .visible) {
                Button("Fermer définitivement", role: .destructive) { message = engine.fermerEntreprise(e.id) }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    // MARK: - Gestion poussée

    @ViewBuilder
    private func resumeRapport(_ e: Entreprise) -> some View {
        if let r = e.rapport, let eco = EntrepriseCatalogue.eco(e.typeId) {
            Section {
                ResumeRapportEntreprise(entreprise: e, rapport: r, eco: eco)
                NavigationLink {
                    EntrepriseRapportView(entrepriseId: e.id)
                } label: {
                    Label("Rapport complet et graphiques", systemImage: "chart.bar.doc.horizontal")
                }
            } header: {
                Text("Bilan à \(r.age) ans")
            }
        }
    }

    @ViewBuilder
    private func pilotage(_ e: Entreprise, _ type: EntrepriseType) -> some View {
        if let eco = EntrepriseCatalogue.eco(type.id) {
            Section {
                Picker(selection: Binding(get: { e.prix }, set: { _ = engine.reglerPrix(e.id, $0) })) {
                    ForEach(EntrepriseSimulation.niveauxPrix, id: \.self) { p in
                        Text(Self.textePrix(p, eco)).tag(p)
                    }
                } label: {
                    Label("Prix", systemImage: "tag.fill")
                }
                Picker(selection: Binding(get: { e.qualite }, set: { _ = engine.reglerQualite(e.id, $0) })) {
                    ForEach(1...5, id: \.self) { q in
                        Text(EntrepriseSimulation.qualiteNoms[q - 1]).tag(q)
                    }
                } label: {
                    Label("Qualité", systemImage: "sparkles")
                }
                Picker(selection: Binding(get: { e.marketing }, set: { _ = engine.reglerMarketing(e.id, $0) })) {
                    ForEach(EntrepriseSimulation.budgetsMarketing, id: \.self) { m in
                        Text(m == 0 ? "Aucun" : "\(m) % du CA").tag(m)
                    }
                } label: {
                    Label("Marketing", systemImage: "megaphone.fill")
                }
                Picker(selection: Binding(get: { e.salaireNiveau }, set: { _ = engine.reglerSalaires(e.id, $0) })) {
                    ForEach(EntrepriseSimulation.niveauxSalaire, id: \.self) { s in
                        Text(Self.texteSalaire(s, type)).tag(s)
                    }
                } label: {
                    Label("Salaires", systemImage: "banknote.fill")
                }
            } header: {
                Text("Pilotage")
            } footer: {
                Text("Les réglages comptent pour le prochain bilan. Regarde l'estimation juste en dessous avant de valider.")
            }

            let conseille = engine.effectifConseilleEntreprise(e)
            Section {
                HStack {
                    Label("Employés", systemImage: "person.3.fill")
                    Spacer()
                    Text("\(max(0, e.effectif))").font(.headline.monospacedDigit())
                }
                HStack(spacing: 8) {
                    boutonEffectif(e, -5)
                    boutonEffectif(e, -1)
                    boutonEffectif(e, 1)
                    boutonEffectif(e, 5)
                    boutonEffectif(e, 20)
                }
                .buttonStyle(.bordered)
                LigneAction(titre: "Ajuster à l'effectif conseillé (\(conseille))",
                            sousTitre: "Juste ce qu'il faut pour servir la demande prévue",
                            icone: "wand.and.stars",
                            actif: conseille != max(0, e.effectif)) {
                    message = engine.ajusterEffectif(e.id)
                }
            } header: {
                Text("Effectif")
            } footer: {
                Text("Embaucher coûte 10 % d'un salaire annuel, licencier 25 % et fait chuter le moral. Salaire de base : \(Format.argent(type.salaireEmploye))/an.")
            }

            Section {
                HStack {
                    Label(eco.site.pluriel.capitalized, systemImage: "storefront.fill")
                    Spacer()
                    Text("\(e.sites)").font(.headline.monospacedDigit())
                }
                LigneAction(titre: "Ouvrir 1 \(eco.site.nom)", sousTitre: Format.argent(eco.coutSite),
                            icone: "plus.circle.fill", actif: engine.budgetEntreprise(e) >= eco.coutSite) {
                    message = engine.ouvrirSites(e.id, nombre: 1)
                }
                if e.sites >= 2 {
                    LigneAction(titre: "Ouvrir 5 \(eco.site.pluriel)", sousTitre: Format.argent(eco.coutSite * 5),
                                icone: "plus.square.fill.on.square.fill", actif: engine.budgetEntreprise(e) >= eco.coutSite * 5) {
                        message = engine.ouvrirSites(e.id, nombre: 5)
                    }
                }
                if e.sites >= 10 {
                    LigneAction(titre: "Ouvrir 25 \(eco.site.pluriel)", sousTitre: Format.argent(eco.coutSite * 25),
                                icone: "building.2.fill", actif: engine.budgetEntreprise(e) >= eco.coutSite * 25) {
                        message = engine.ouvrirSites(e.id, nombre: 25)
                    }
                }
                if e.sites > 1 {
                    LigneAction(titre: "Fermer 1 \(eco.site.nom)", sousTitre: "Tu récupères 30 % de sa valeur",
                                icone: "minus.circle.fill") {
                        message = engine.fermerSites(e.id, nombre: 1)
                    }
                }
                if let u = eco.usine {
                    HStack {
                        Label(u.pluriel.capitalized, systemImage: "building.columns.fill")
                        Spacer()
                        Text("\(max(0, e.usines))").font(.headline.monospacedDigit())
                    }
                    LigneAction(titre: "Construire 1 \(u.nom)", sousTitre: Format.argent(eco.coutUsine),
                                icone: "hammer.fill", actif: engine.budgetEntreprise(e) >= eco.coutUsine) {
                        message = engine.ouvrirUsines(e.id, nombre: 1)
                    }
                    if e.usines > 1 {
                        LigneAction(titre: "Fermer 1 \(u.nom)", sousTitre: "Tu récupères 30 % de sa valeur",
                                    icone: "minus.circle.fill") {
                            message = engine.fermerUsines(e.id, nombre: 1)
                        }
                    }
                }
            } header: {
                Text("Locaux" + (eco.usine != nil ? " et production" : ""))
            } footer: {
                Text(eco.usine != nil
                     ? "Les \(eco.site.pluriel) attirent les clients, les \(eco.usine?.pluriel ?? "usines") fabriquent. Plus de points de vente sans production = ruptures de stock."
                     : "Chaque \(eco.site.nom) attire de nouveaux clients mais demande du personnel et un loyer. Niveau suivant à \(Self.prochainSeuil(e.sites)) \(eco.site.pluriel).")
            }
        }
    }

    @ViewBuilder
    private func estimation(_ e: Entreprise) -> some View {
        if let r = engine.estimationEntreprise(e), let eco = EntrepriseCatalogue.eco(e.typeId) {
            Section {
                ligne("Demande attendue", "\(r.demande) \(eco.vente.pluriel)")
                ligne("Capacité", "\(r.capacite) \(eco.vente.pluriel)", rouge: r.capacite < r.demande)
                ligne("Part de marché", "\(Int(r.partDeMarche * 100)) %")
                ligne("Chiffre d'affaires", Format.argent(r.chiffreAffaires))
                ligne("Coûts", Format.argent(r.couts))
                ligne("Résultat", (r.resultat >= 0 ? "+" : "") + Format.argent(r.resultat), rouge: r.resultat < 0)
                    .bold()
                if r.demande > r.capacite {
                    Text("Tu vas refuser environ \(r.demande - r.capacite) clients.")
                        .font(.caption).foregroundStyle(.orange)
                }
            } header: {
                Text("Estimation pour l'an prochain")
            } footer: {
                Text("Sans compter le hasard du marché, les crises et la concurrence.")
            }
        }
    }

    @ViewBuilder
    private func leviersMetier(_ e: Entreprise, _ type: EntrepriseType) -> some View {
        if let eco = EntrepriseCatalogue.eco(type.id), !eco.leviers.isEmpty {
            Section {
                ForEach(eco.leviers) { l in
                    let actif = e.leviers.contains(l.id)
                    let bloque = e.niveau < (l.niveauMin ?? 0)
                    Button {
                        message = actif ? engine.desactiverLevier(e.id, levier: l.id) : engine.activerLevier(e.id, levier: l.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: l.icone)
                                .font(.system(size: 18))
                                .foregroundStyle(actif ? Color.green : (bloque ? Color.gray : Theme.accent))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(l.nom).foregroundStyle(bloque ? Color.gray : Theme.encre)
                                    if actif {
                                        Text("ACTIF").font(.caption2.bold()).foregroundStyle(.green)
                                    }
                                }
                                Text(engine.remplir(EntrepriseMoteur.remplir(l.description, e, type, employe: nil), engine.joueur!))
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(Self.resumeLevier(l, e, bloque: bloque))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(bloque && !actif)
                }
            } header: {
                Text("Leviers du métier")
            } footer: {
                Text("Touche un levier pour l'activer ou l'arrêter.")
            }
        }
    }

    private func boutonEffectif(_ e: Entreprise, _ delta: Int) -> some View {
        Button(delta > 0 ? "+\(delta)" : "\(delta)") {
            message = engine.changerEffectif(e.id, delta: delta)
        }
        .frame(maxWidth: .infinity)
        .disabled(delta < 0 && e.effectif <= 0)
    }

    static func textePrix(_ p: Double, _ eco: EntrepriseEco) -> String {
        let pct = Int(((p - 1) * 100).rounded())
        let prix = Format.argent(Int((eco.prixUnitaire * p).rounded()))
        if pct == 0 { return "Normal (\(prix))" }
        return (pct > 0 ? "+\(pct) %" : "\(pct) %") + " (\(prix))"
    }

    static func texteSalaire(_ s: Double, _ type: EntrepriseType) -> String {
        let pct = Int(((s - 1) * 100).rounded())
        let montant = Format.argent(Int(Double(type.salaireEmploye) * s))
        if pct == 0 { return "Au prix du marché (\(montant))" }
        return (pct > 0 ? "+\(pct) %" : "\(pct) %") + " (\(montant))"
    }

    static func prochainSeuil(_ sites: Int) -> Int {
        EntrepriseMoteur.seuilsSites.first { $0 > sites } ?? sites
    }

    static func resumeLevier(_ l: EntrepriseLevier, _ e: Entreprise, bloque: Bool) -> String {
        if bloque { return "Réservé aux boîtes de niveau \((l.niveauMin ?? 0) + 1) et plus" }
        var morceaux: [String] = []
        let f = l.effets
        func ajoute(_ v: Int?, _ nom: String) {
            if let v = v, v != 0 { morceaux.append((v > 0 ? "+" : "") + "\(v) % \(nom)") }
        }
        ajoute(f?.demande, "clients")
        ajoute(f?.prix, "prix")
        ajoute(f?.coutVariable, "coûts d'achat")
        ajoute(f?.capacite, "capacité")
        ajoute(f?.productivite, "productivité")
        if let r = f?.reputation, r != 0 { morceaux.append((r > 0 ? "+" : "") + "\(r) réputation/an") }
        if let m = f?.moral, m != 0 { morceaux.append((m > 0 ? "+" : "") + "\(m) moral") }
        if let r = f?.risque, r > 0 { morceaux.append("risque +\(r) %") }
        let parSite = l.parSite == true ? " par site" : ""
        let install = (l.coutInstallation ?? 0) * (l.parSite == true ? e.sites : 1)
        if install > 0 { morceaux.append("mise en place " + Format.argent(install)) }
        if let a = l.coutAnnuel, a > 0 { morceaux.append(Format.argent(a) + "/an" + parSite) }
        return morceaux.joined(separator: " · ")
    }

    // MARK: - Outils

    private func ligne(_ titre: String, _ valeur: String, rouge: Bool = false) -> some View {
        HStack {
            Text(titre)
            Spacer()
            Text(valeur)
                .monospacedDigit()
                .foregroundStyle(rouge ? Color.red : Color.secondary)
        }
    }

    private func nomNiveauSuivant(_ e: Entreprise) -> String {
        var suivante = e
        suivante.niveau += 1
        return engine.nomDuNiveau(suivante)
    }

    private func montantsInjection(_ e: Entreprise, _ j: Joueur) -> [Int] {
        let echelle = e.echelle
        let paliers = [5_000, 20_000, 100_000, 500_000, 2_000_000].map { Int(Double($0) * max(1, echelle / 2)) }
        var montants = paliers.filter { $0 <= j.argent }
        if e.tresorerie < 0 && -e.tresorerie <= j.argent { montants.insert(-e.tresorerie, at: 0) }
        return Array(Set(montants)).sorted()
    }
}

struct LigneEmploye: View {
    let employe: EntrepriseEmploye

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: employe.estProche ? "heart.circle.fill" : "person.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(employe.estProche ? Color.pink : Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(employe.nomComplet + (employe.lienLibelle.map { " (\($0.lowercased()))" } ?? ""))
                    .foregroundStyle(Theme.encre)
                Text("\(employe.poste) · \(Format.argent(employe.salaire))/an")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Compétence \(employe.competence) % · Motivation \(employe.motivation) %")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

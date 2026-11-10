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
                EntrepriseCriseSection(entreprise: e) { texte in message = texte }
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
            if let cout = EntrepriseMoteur.coutAgrandissement(e, type) {
                LigneAction(titre: "Agrandir : " + nomNiveauSuivant(e),
                            sousTitre: Format.argent(cout) + (engine.budgetEntreprise(e) < cout ? " · pas assez d'argent" : ""),
                            icone: "arrow.up.right.circle.fill",
                            actif: engine.budgetEntreprise(e) >= cout && !j.actionsAnnee.contains("ent_agr_" + id)) {
                    message = engine.agrandirEntreprise(e.id)
                }
            } else {
                Text("👑 Tu as atteint le sommet. Il n'y a plus rien à conquérir, à part le respect de ta famille.")
                    .font(.caption)
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
            Text("Équipe · \(e.employes.count)/\(EntrepriseMoteur.postes(e)) postes clés")
        } footer: {
            if e.employes.count < EntrepriseMoteur.postes(e) {
                Text("Chaque poste vide fait perdre 8 % de chiffre d'affaires et te fatigue.")
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

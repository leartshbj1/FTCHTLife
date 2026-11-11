import SwiftUI

/// Menu Carrière → Agence de détective : ouvrir son agence, prendre des affaires, choisir ses méthodes, recruter.
struct AgenceView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    @State private var nom = ""
    @State private var confirmerFermeture = false

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    if let a = j.agences?.actuelle {
                        agence(a, j)
                    } else {
                        ouverture(j)
                    }
                    anciennes(j)
                }
            }
            .navigationTitle("Agence de détective")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
            .alerteResultat($message)
            .alert("Fermer l'agence ?", isPresented: $confirmerFermeture) {
                Button("Fermer l'agence", role: .destructive) { message = engine.fermerMonAgence() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les affaires en cours seront abandonnées et tes enquêteurs remerciés.")
            }
        }
    }

    // MARK: - Ouvrir

    @ViewBuilder
    private func ouverture(_ j: Joueur) -> some View {
        Section {
            Text("Ouvre ton agence de détective privé : des clients viennent avec leurs soupçons, tu choisis les affaires, la méthode (filature, planque, recherches, infiltration… ou méthodes limites), et ce que tu fais de la vérité. C'est un métier à plein temps.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        Section("Nom de l'agence") {
            TextField("Nom", text: $nom)
            Button("Suggestion") { nom = Self.suggestions(j).randomElement() ?? "" }
        }
        Section {
            let coutLegal = AgenceMoteur.coutOuverture(j, agrement: true)
            let blocageLegal = AgenceMoteur.blocageOuverture(j, agrement: true)
            Button {
                message = engine.ouvrirAgence(nom: nom, agrement: true) ?? "Ton agence est ouverte. Les premiers dossiers t'attendent."
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Ouvrir avec une carte professionnelle", systemImage: "checkmark.seal.fill").font(.headline)
                    Text(blocageLegal ?? "Formation et agrément : \(Format.argent(coutLegal)). Légal, rassurant pour les clients.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(blocageLegal != nil || nom.trimmingCharacters(in: .whitespaces).isEmpty)

            let blocageClandestin = AgenceMoteur.blocageOuverture(j, agrement: false)
            Button {
                message = engine.ouvrirAgence(nom: nom, agrement: false) ?? "Ton agence clandestine est ouverte. Discrétion absolue, y compris vis-à-vis de la loi."
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Ouvrir sans agrément", systemImage: "eye.slash.fill").font(.headline)
                    Text(blocageClandestin ?? "\(Format.argent(AgenceMoteur.coutClandestin)). Illégal : moins de clients sérieux, gros risques en cas de plainte.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(blocageClandestin != nil || nom.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    static func suggestions(_ j: Joueur) -> [String] {
        ["Agence \(j.nom) Investigations", "\(j.nom) & Associés, Recherches privées", "L'Œil de \(j.ville)",
         "Cabinet Vérité", "Discrétion \(j.ville)", "Bureau d'enquêtes \(j.nom)", "Agence Lanterne", "Filature & Fils"]
    }

    // MARK: - Agence

    @ViewBuilder
    private func agence(_ a: AgenceEtat, _ j: Joueur) -> some View {
        let enPrison = j.vieEtat.justice.enPrison
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(a.nom).font(.title3.bold())
                Text("\(AgenceMoteur.titre(j)) depuis \(a.annees) an\(a.annees > 1 ? "s" : "") · \(a.agrement ? "carte professionnelle" : "sans agrément")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            JaugeModule(titre: "Réputation", icone: "star.fill", valeur: a.reputation)
            Group {
                ligne("Affaires résolues", "\(a.resolues) (ratées : \(a.ratees))", "checkmark.seal")
                ligne("Bureau", AgenceMoteur.nomsBureau[a.bureau], "building.2.fill")
                ligne("Matériel", AgenceMoteur.nomsEquipement[a.equipement], "camera.fill")
                ligne("Capacité", "\(a.affaires.count) / \(AgenceMoteur.capacite(a)) affaires", "folder.fill")
            }
            if let fin = a.suspenduJusqua {
                Text("Carte professionnelle suspendue jusqu'à tes \(fin) ans : aucune nouvelle affaire.").font(.caption).foregroundStyle(.red)
            }
            if !a.celebres.isEmpty {
                Text("Affaires célèbres : " + a.celebres.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            }
            if let b = a.bilan {
                Text("L'an dernier : recettes \(Format.argent(b.recettes)), charges \(Format.argent(b.charges)).").font(.caption).foregroundStyle(.secondary)
            }
        }

        Section {
            if a.affaires.isEmpty {
                Text("Aucune affaire en cours. Regarde les dossiers proposés.").foregroundStyle(.secondary)
            }
            ForEach(a.affaires) { af in
                affaireEnCours(af, a, j)
            }
        } header: {
            Text("Affaires en cours")
        } footer: {
            Text("La méthode et la personne choisies travaillent toute l'année. Le résultat tombe au passage d'année.")
        }

        Section("Dossiers proposés") {
            if a.offres.isEmpty {
                Text(a.suspendue ? "Carte suspendue : les clients attendent." : "Pas de nouveau client pour l'instant. Reviens l'an prochain, ou fais de la pub.")
                    .foregroundStyle(.secondary)
            }
            ForEach(a.offres) { af in
                offre(af, j)
                    .swipeActions { Button("Refuser", role: .destructive) { engine.refuserAffaire(af.id) } }
            }
        }

        equipe(a, j, enPrison: enPrison)

        Section("Développer l'agence") {
            LigneAction(titre: "Faire de la pub", sousTitre: a.actionsAnnee.contains("pub") ? "Déjà fait cette année" : "\(Format.argent(2_000 * (1 + a.bureau))) · réputation et clients",
                        icone: "megaphone.fill", actif: !a.actionsAnnee.contains("pub") && !enPrison) {
                message = engine.publiciteAgence()
            }
            if a.equipement < 3 {
                LigneAction(titre: "Matériel : \(AgenceMoteur.nomsEquipement[a.equipement + 1])",
                            sousTitre: "\(Format.argent(AgenceMoteur.coutsEquipement[a.equipement + 1])) · enquêtes plus rapides",
                            icone: "camera.aperture", actif: !enPrison) {
                    message = engine.ameliorerEquipement()
                }
            }
            if a.bureau < 3 {
                LigneAction(titre: "S'installer : \(AgenceMoteur.nomsBureau[a.bureau + 1])",
                            sousTitre: "\(Format.argent(AgenceMoteur.coutsBureau[a.bureau + 1])) puis \(Format.argent(AgenceMoteur.loyersBureau[a.bureau + 1]))/an · plus de clients et d'enquêteurs",
                            icone: "building.2.fill", actif: !enPrison) {
                    message = engine.demenagerAgence(a.bureau + 1)
                }
            }
            if !a.agrement {
                LigneAction(titre: "Régulariser : demander la carte professionnelle",
                            sousTitre: "\(Format.argent(AgenceMoteur.coutOuverture(j, agrement: true)))", icone: "checkmark.seal.fill", actif: !enPrison) {
                    message = engine.demanderAgrement()
                }
            }
        }

        Section {
            Button("Fermer l'agence", role: .destructive) { confirmerFermeture = true }
        }
    }

    // MARK: - Affaires

    private func affaireEnCours(_ af: AgenceAffaire, _ a: AgenceEtat, _ j: Joueur) -> some View {
        let type = AgenceCatalogue.type(af.typeId)
        let enq = af.enqueteurId.flatMap { id in a.enqueteurs.first { $0.id == id } }
        let methode = af.methode ?? .terrain
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: type?.icone ?? "magnifyingglass").foregroundStyle(Theme.accent)
                Text(type?.nom ?? "Affaire").font(.headline)
                Spacer()
                Text(Format.argent(af.honoraires)).font(.caption).foregroundStyle(.secondary)
            }
            Text(engine.remplir("Client : \(af.client). Cible : \(af.cible).", j)).font(.caption).foregroundStyle(.secondary)
            ProgressView(value: Double(min(af.progres, af.difficulte)), total: Double(max(1, af.difficulte)))
            Text("Année \(af.annees + 1) sur \(af.dureeMax) · environ \(AgenceMoteur.pointsAttendus(af, a, j)) points par an sur \(max(0, af.difficulte - af.progres)) restants")
                .font(.caption2).foregroundStyle(.secondary)
            if let dernier = af.indices.last {
                Text("🔎 " + engine.remplir(dernier, j)).font(.caption).italic()
            }
            HStack {
                Menu {
                    ForEach(AgenceMethode.allCases) { m in
                        Button {
                            engine.choisirMethode(af.id, m)
                        } label: {
                            Label(m.nom + (m == methode ? " ✓" : ""), systemImage: m.icone)
                        }
                    }
                } label: {
                    Label(methode.nom, systemImage: methode.icone).font(.caption.bold())
                }
                Spacer()
                Menu {
                    Button("Toi-même") { engine.assignerAffaire(af.id, enqueteur: nil) }
                    ForEach(a.enqueteurs) { e in
                        Button("\(e.prenom) (\(e.specialite.nom.lowercased()))") { engine.assignerAffaire(af.id, enqueteur: e.id) }
                    }
                } label: {
                    Label(enq?.prenom ?? "Toi", systemImage: "person.fill").font(.caption.bold())
                }
            }
            Text(methode.description).font(.caption2).foregroundStyle(methode == .limite ? Color.red : Color.secondary)
            Button("Rendre le dossier", role: .destructive) { message = engine.abandonnerAffaire(af.id) }
                .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func offre(_ af: AgenceAffaire, _ j: Joueur) -> some View {
        let type = AgenceCatalogue.type(af.typeId)
        return Button {
            message = engine.accepterAffaire(af.id)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: type?.icone ?? "folder.fill").foregroundStyle(Theme.accent)
                    Text(type?.nom ?? "Affaire").font(.headline).foregroundStyle(Theme.encre)
                    Spacer()
                    Text(Format.argent(af.honoraires)).font(.subheadline.bold()).foregroundStyle(Theme.argentPositif)
                }
                Text(engine.remplir("\(af.client). Cible : \(af.cible).", j)).font(.caption).foregroundStyle(.secondary)
                if let t = type {
                    Text(t.description).font(.caption2).foregroundStyle(.secondary)
                }
                Text("Difficulté \(af.difficulte) · \(af.dureeMax) an\(af.dureeMax > 1 ? "s" : "") max · acompte \(Int(AgenceMoteur.acompte * 100)) %. Touche pour accepter, glisse pour refuser.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Équipe

    @ViewBuilder
    private func equipe(_ a: AgenceEtat, _ j: Joueur, enPrison: Bool) -> some View {
        Section {
            if a.enqueteurs.isEmpty {
                Text("Tu travailles seul\(j.genre == .femme ? "e" : ""). Un enquêteur permet de mener plus d'affaires.").foregroundStyle(.secondary)
            }
            ForEach(a.enqueteurs) { e in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.nomComplet).font(.headline)
                        Text("\(e.specialite.nom) · compétence \(e.competence) · \(Format.argent(e.salaire))/an\(e.relationId != nil ? " · proche" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .swipeActions { Button("Licencier", role: .destructive) { message = engine.licencierEnqueteur(e.id) } }
            }
            if a.enqueteurs.count < AgenceMoteur.maxEnqueteurs(a) && !enPrison {
                Menu {
                    ForEach(a.candidats) { c in
                        Button("\(c.prenom) \(c.nom) · \(c.specialite.nom.lowercased()) · \(c.competence) · \(Format.argent(c.salaire))") {
                            message = engine.embaucherEnqueteur(c.id)
                        }
                    }
                    let proches = engine.agenceProchesEmbauchables()
                    if !proches.isEmpty {
                        Divider()
                        ForEach(proches) { r in
                            Button("\(r.libelle) : \(r.prenom)") { message = engine.embaucherProche(r) }
                        }
                    }
                } label: {
                    Label("Recruter un enquêteur", systemImage: "person.badge.plus")
                }
            }
        } header: {
            Text("Équipe (\(a.enqueteurs.count)/\(AgenceMoteur.maxEnqueteurs(a)))")
        } footer: {
            Text("Glisse un enquêteur vers la gauche pour t'en séparer. Plus de place ? Prends des bureaux plus grands.")
        }
    }

    @ViewBuilder
    private func anciennes(_ j: Joueur) -> some View {
        let liste = j.agences?.anciennes ?? []
        if !liste.isEmpty {
            Section("Anciennes agences") {
                ForEach(liste) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.nom).font(.headline)
                        Text("De \(a.ageDebut) à \(a.ageFin) ans · \(a.resolues) affaires résolues\(a.celebres.isEmpty ? "" : " · \(a.celebres.count) célèbres")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func ligne(_ titre: String, _ valeur: String, _ icone: String) -> some View {
        HStack {
            Label(titre, systemImage: icone).foregroundStyle(Theme.encre)
            Spacer()
            Text(valeur).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}

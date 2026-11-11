import SwiftUI

/// Écran « Le Milieu » : organisations, missions, trafic, argent sale, police.
struct VieMilieuView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?
    @State private var confirmerBalance = false
    @State private var confirmerCoup = false

    private func agir(_ action: (inout Joueur) -> [String]) {
        var texte = ""
        engine.modifier { j in
            let lignes = action(&j).map { VieMilieu.remplir($0, j) }
            texte = lignes.joined(separator: " ")
            for l in lignes where !l.isEmpty { engine.ajouterLigne(&j, l) }
        }
        message = texte
    }

    private func agir(_ action: (inout Joueur) -> String) {
        agir { j in [action(&j)] }
    }

    var body: some View {
        List {
            if let j = engine.joueur {
                let m = VieMilieu.etat(j)
                if let org = VieMilieu.organisation(j) {
                    membre(j, m, org)
                } else {
                    recrutement(j, m)
                }
                police(j, m)
            }
        }
        .navigationTitle("Le Milieu")
        .vieToast($message)
    }

    // MARK: Pas encore membre

    @ViewBuilder
    private func recrutement(_ j: Joueur, _ m: VieMilieuEtat) -> some View {
        Section {
            Text("Gangs, familles, cartels. L'argent y est facile, la sortie beaucoup moins.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack { Text("Ta réputation dans la rue"); Spacer(); Text("\(VieMilieu.notoriete(j))/100").foregroundStyle(.secondary) }
        }
        Section("À ton compte") {
            lienBusiness(j, m)
            lienCoup(j, m)
            if m.argentSale > 0 || m.facades != nil {
                NavigationLink { VieBlanchimentView() } label: {
                    Label("Blanchir \(Format.argent(m.argentSale)) d'argent sale", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
        let orgs = VieMilieu.organisationsAccessibles(j)
        Section("Organisations") {
            if m.balance {
                Text("Tu as parlé à la police. Aucune organisation ne voudra jamais de toi.").foregroundStyle(.secondary)
            } else if orgs.isEmpty {
                Text(j.age < 13 ? "Tu es trop jeune. Va à l'école." : "Personne ne te connaît encore. Commets quelques délits pour te faire un nom.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(orgs) { org in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(org.nom).font(.headline)
                            Spacer()
                            Text(org.typeTexte).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(org.description).font(.subheadline)
                        HStack(spacing: 2) {
                            Text("Danger").font(.caption).foregroundStyle(.secondary)
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: i < org.dangerosite ? "flame.fill" : "flame")
                                    .font(.caption2).foregroundStyle(i < org.dangerosite ? Color.red : Color.gray)
                            }
                        }
                        Button("Chercher à entrer") { agir { j in VieMilieu.rejoindre(org, &j) } }
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                            .disabled(j.vieEtat.justice.enPrison)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: Membre

    @ViewBuilder
    private func membre(_ j: Joueur, _ m: VieMilieuEtat, _ org: MilieuOrganisation) -> some View {
        Section(org.nom) {
            HStack { Text("Rang"); Spacer(); Text(org.rang(m.rang)).foregroundStyle(.secondary) }
            HStack { Text("Chef"); Spacer(); Text(m.rang == 4 ? "Toi" : (m.chefNom ?? "?")).foregroundStyle(.secondary) }
            if let rival = MilieuDonnees.organisation(m.rivalId) {
                HStack { Text("Ennemis"); Spacer(); Text(rival.nom).foregroundStyle(.secondary) }
            }
            HStack { Text("Territoires"); Spacer(); Text("\(m.territoires)").foregroundStyle(.secondary) }
            BarreStat(titre: "Respect", icone: "star.fill", valeur: m.respect)
            BarreStat(titre: "Loyauté", icone: "hand.raised.fill", valeur: m.loyaute)
        }
        let enPrison = j.vieEtat.justice.enPrison
        Section("Opérations") {
            ForEach(VieMilieu.missions(j)) { mi in
                LigneAction(titre: mi.nom, sousTitre: "\(Format.argent(mi.gainMin)) à \(Format.argent(mi.gainMax)) · risque \(Int(mi.risqueArrestation * 100)) %",
                            icone: mi.icon ?? "briefcase.fill", actif: !enPrison && !m.actionsAnnee.contains("mission_\(mi.id)")) {
                    agir { j in VieMilieu.faire(mi, &j) }
                }
            }
        }
        Section("Business") {
            lienBusiness(j, m)
            lienCoup(j, m)
        }
        Section("Argent sale : \(Format.argent(m.argentSale))") {
            NavigationLink { VieBlanchimentView() } label: {
                Label("Blanchiment et commerces de façade", systemImage: "building.2.fill")
            }
            LigneAction(titre: "Tout blanchir", sousTitre: "Commission de \(m.rang >= 3 ? 15 : 30) %", icone: "arrow.triangle.2.circlepath", actif: m.argentSale > 0) {
                agir { j in VieMilieu.blanchir(VieMilieu.etat(j).argentSale, &j) }
            }
        }
        Section("Pouvoir") {
            if m.rang < 3 {
                LigneAction(titre: "Demander à monter en grade", icone: "arrow.up.circle.fill", actif: !enPrison) {
                    agir { j in VieMilieu.demanderPromotion(&j) }
                }
            }
            if m.rang == 3 {
                LigneAction(titre: "Prendre la tête de l'organisation", sousTitre: "Tout ou rien", icone: "crown.fill", actif: !enPrison) {
                    confirmerCoup = true
                }
            }
            if m.rang >= 2 {
                LigneAction(titre: "Lancer une guerre de territoire", icone: "flag.2.crossed.fill", actif: !enPrison) {
                    agir { j in VieMilieu.guerreDeTerritoire(&j) }
                }
                LigneAction(titre: "Acheter un fonctionnaire", sousTitre: "Fait baisser l'attention de la police", icone: "envelope.fill", actif: !enPrison) {
                    agir { j in VieMilieu.corrompre(&j) }
                }
            }
            LigneAction(titre: "Quitter le milieu", icone: "door.left.hand.open") {
                agir { j in VieMilieu.quitter(&j) }
            }
            LigneAction(titre: "Tout raconter à la police", sousTitre: "Protection, mais tu deviens une cible", icone: "person.badge.shield.checkmark.fill") {
                confirmerBalance = true
            }
        }
        .confirmationDialog("Tout balancer ?", isPresented: $confirmerBalance, titleVisibility: .visible) {
            Button("Parler aux enquêteurs", role: .destructive) { agir { j in VieMilieu.balancer(&j) } }
        } message: {
            Text("Ton organisation tombera, ta peine sera allégée, mais plus personne ne te protégera.")
        }
        .confirmationDialog("Prendre le pouvoir ?", isPresented: $confirmerCoup, titleVisibility: .visible) {
            Button("Passer à l'acte", role: .destructive) { agir { j in VieMilieu.prendreLePouvoir(&j) } }
        } message: {
            Text("Si ça échoue, tu peux y laisser la vie.")
        }
    }

    // MARK: Business et casse

    @ViewBuilder
    private func lienBusiness(_ j: Joueur, _ m: VieMilieuEtat) -> some View {
        NavigationLink { VieTraficView() } label: {
            if let t = m.trafic {
                let b = t.b
                VStack(alignment: .leading, spacing: 2) {
                    Label("Ton business", systemImage: "shippingbox.fill")
                    Text("\(b.lignes.count) marchandise\(b.lignes.count > 1 ? "s" : "") · \(b.zones.count) quartier\(b.zones.count > 1 ? "s" : "") · \(t.reseau) revendeur\(t.reseau > 1 ? "s" : "") · stock \(b.stockTotal)")
                        .font(.caption).foregroundStyle(.secondary)
                    if b.decision != nil {
                        Text("Une décision t'attend").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                }
            } else {
                Label(m.membre ? "Monter un trafic" : "Dealer à ton compte", systemImage: "shippingbox")
            }
        }
    }

    @ViewBuilder
    private func lienCoup(_ j: Joueur, _ m: VieMilieuEtat) -> some View {
        NavigationLink { VieCoupView() } label: {
            if let co = m.coup, let c = MilieuCoups.cible(co.cibleId) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Coup en préparation", systemImage: "scope")
                    Text(c.nom).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Label("Monter un coup", systemImage: "scope")
            }
        }
    }

    // MARK: Police

    @ViewBuilder
    private func police(_ j: Joueur, _ m: VieMilieuEtat) -> some View {
        if m.membre || m.trafic != nil || m.coup != nil || m.chaleur > 0 || m.enquete != nil || m.protection != nil {
            Section("Police") {
                BarreStat(titre: "Attention", icone: "light.beacon.max.fill", valeur: m.chaleur)
                if let e = MilieuEnquete.etape(j) {
                    Label("Enquête en cours : \(MilieuEnquete.titre(e).lowercased())", systemImage: "magnifyingglass")
                        .foregroundStyle(.red)
                }
                NavigationLink { VieProtectionView() } label: {
                    Label("Ta protection et l'enquête", systemImage: "shield.lefthalf.filled")
                }
            }
        }
    }
}

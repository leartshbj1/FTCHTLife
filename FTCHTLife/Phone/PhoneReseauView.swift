import SwiftUI

/// Une appli de réseau social (Pozz, Trémousse, Ronchon) : compte, publier, fil des posts.
@MainActor
struct PhoneReseauView: View {
    @EnvironmentObject var engine: GameEngine
    let app: PhoneApp
    let chemin: PhoneChemin
    @State private var publication: PhonePublication?
    @State private var alerte: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                let t = j[keyPath: chemin] ?? PhoneEtat()
                Section {
                    entete(t.compte(app))
                }
                if j.age < app.ageMin {
                    Section {
                        Text("\(app.nom) est interdit aux moins de \(app.ageMin) ans. Tu as essayé de mentir sur ton âge, mais tu as écrit ta vraie date de naissance.")
                            .font(.subheadline)
                    }
                } else {
                    sectionPublier(j, t)
                    sectionAutres(j, t)
                    sectionFil(t)
                }
            }
        }
        .navigationTitle(app.nom)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $publication) { p in
            PhoneResultatPost(publication: p)
        }
        .phoneAlerte($alerte)
    }

    private func entete(_ c: PhoneCompte) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(app.couleur)
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: app.icone).font(.system(size: 24, weight: .semibold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(PhoneFormat.nombre(c.abonnes) + (c.abonnes > 1 ? " abonnés" : " abonné"))
                        .font(.headline)
                    if c.certifie {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
                    }
                }
                Text("\(c.posts) publication\(c.posts > 1 ? "s" : "") · \(app.slogan)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(app.conseil)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func sectionPublier(_ j: Joueur, _ t: PhoneEtat) -> some View {
        let restants = PhoneEngine.postsRestants(app, t)
        let modeles = PhoneEngine.postsDisponibles(app, j, t, engine: engine)
        return Section {
            if modeles.isEmpty {
                Text("Rien à publier pour l'instant.").foregroundStyle(.secondary)
            }
            ForEach(modeles) { m in
                let blocage = PhoneEngine.blocagePublication(m, j, t)
                LigneAction(titre: m.titre,
                            sousTitre: sousTitre(m, t, blocage: blocage),
                            icone: m.icone,
                            actif: blocage == nil) {
                    publier(m)
                }
            }
        } header: {
            Text("Publier · \(restants) post\(restants > 1 ? "s" : "") restant\(restants > 1 ? "s" : "") cette année")
        }
    }

    private func sousTitre(_ m: PhonePostModele, _ t: PhoneEtat, blocage: String?) -> String? {
        if let b = blocage, PhoneEngine.postsRestants(app, t) > 0 { return b }
        var morceaux: [String] = []
        if let cout = m.cout, cout > 0 { morceaux.append(Format.argent(cout)) }
        if m.risque >= 0.25 { morceaux.append("risqué") }
        if m.viralite >= 2 { morceaux.append("peut buzzer") }
        return morceaux.isEmpty ? nil : morceaux.joined(separator: " · ")
    }

    private func publier(_ m: PhonePostModele) {
        let resultat = engine.telephoneModifier(chemin) { j, t in
            PhoneEngine.publier(m, &j, &t, engine: engine)
        }
        if let p = resultat ?? nil {
            publication = p
        }
    }

    @ViewBuilder
    private func sectionAutres(_ j: Joueur, _ t: PhoneEtat) -> some View {
        Section("Autres") {
            if app == .tremousse {
                LigneAction(titre: "Lancer un live",
                            sousTitre: t.compte(.tremousse).abonnes < 500 ? "Il faut 500 abonnés" : "Une fois par an. Les dons sont les bienvenus.",
                            icone: "dot.radiowaves.left.and.right",
                            actif: PhoneEngine.peutFaireLive(j, t)) {
                    alerte = engine.telephoneModifier(chemin) { j, t in
                        PhoneEngine.lancerLive(&j, &t, engine: engine)
                    }
                }
            }
            LigneAction(titre: "Acheter \(PhoneFormat.nombre(PhoneEngine.nombreFauxAbonnes)) abonnés",
                        sousTitre: "\(Format.argent(PhoneEngine.prixFauxAbonnes)) · des vrais faux comptes, risque de scandale",
                        icone: "cart.fill",
                        actif: j.age >= 16 && t.nombreActions("faux_" + app.rawValue) == 0) {
                alerte = engine.telephoneModifier(chemin) { j, t in
                    PhoneEngine.acheterFauxAbonnes(app, &j, &t, engine: engine)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionFil(_ t: PhoneEtat) -> some View {
        let pubs = t.publications.filter { $0.app == app }.reversed()
        Section("Tes publications") {
            if pubs.isEmpty {
                Text("Aucune publication. Ton profil est aussi vide qu'un frigo d'étudiant.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(pubs)) { p in
                PhonePublicationCarte(publication: p)
            }
        }
    }
}

/// Une publication dans le fil.
struct PhonePublicationCarte: View {
    let publication: PhonePublication

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: publication.icone)
                    .foregroundStyle(publication.app.couleur)
                Text(publication.titre).font(.subheadline.bold())
                Spacer()
                PhoneBadgePalier(palier: publication.palier)
            }
            Text(publication.texte)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Label(PhoneFormat.court(publication.likes), systemImage: "heart.fill")
                    .foregroundStyle(.pink)
                Label((publication.gain >= 0 ? "+" : "") + PhoneFormat.court(publication.gain),
                      systemImage: publication.gain >= 0 ? "person.fill.badge.plus" : "person.fill.badge.minus")
                    .foregroundStyle(publication.gain >= 0 ? Color.green : Color.red)
                Spacer()
                Text("à \(publication.age) ans")
                    .foregroundStyle(.secondary)
            }
            .font(.caption.bold())
            if !publication.commentaires.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(publication.commentaires.enumerated()), id: \.offset) { _, c in
                        Text(c)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PhoneBadgePalier: View {
    let palier: String

    var body: some View {
        Text(libelle)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(couleur))
    }

    private var libelle: String {
        switch palier {
        case "flop": return "FLOP"
        case "moyen": return "BOF"
        case "succes": return "SUCCÈS"
        case "buzz": return "BUZZ 🔥"
        default: return "BAD BUZZ"
        }
    }

    private var couleur: Color {
        switch palier {
        case "flop": return .gray
        case "moyen": return .blue
        case "succes": return .green
        case "buzz": return .orange
        default: return .red
        }
    }
}

/// Feuille affichée juste après une publication.
struct PhoneResultatPost: View {
    let publication: PhonePublication
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PhoneBadgePalier(palier: publication.palier)
                        .scaleEffect(1.6)
                        .padding(.top, 16)
                    Text(titre)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    PhonePublicationCarte(publication: publication)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
                }
                .padding()
            }
            .navigationTitle(publication.app.nom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var titre: String {
        switch publication.palier {
        case "flop": return "Personne n'a vu ton post. Même pas toi."
        case "moyen": return "Quelques likes. C'est déjà ça."
        case "succes": return "Ça marche plutôt bien !"
        case "buzz": return "Tu es partout !"
        default: return "Oups. Internet est fâché."
        }
    }
}

import SwiftUI

/// Le bulletin du conseil de classe, façon feuille imprimée.
struct ScolBulletinView: View {
    @Environment(\.dismiss) private var dismiss
    let bulletin: ScolBulletin

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BULLETIN DU 3e TRIMESTRE").font(.caption.weight(.black)).foregroundStyle(.secondary)
                    Text("Classe de \(bulletin.classe)").font(.title2.weight(.black))
                    Text(bulletin.colles == 0 ? "Aucune colle" : "\(bulletin.colles) colle\(bulletin.colles > 1 ? "s" : "") cette année")
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(bulletin.notes) { n in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(ScolDonnees.nomMatiere(n.matiere)).font(.subheadline.weight(.bold))
                                Text(n.appreciation).font(.caption).italic().foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(ScolRegles.formatNote(n.note))
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.couleurStat(Int(n.note * 5)))
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        Divider()
                    }
                }

                HStack {
                    Text("Moyenne générale").font(.headline)
                    Spacer()
                    Text("\(ScolRegles.formatNote(bulletin.moyenne))/20")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.couleurStat(Int(bulletin.moyenne * 5)))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Appréciation du conseil de classe").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(bulletin.appreciationGenerale).italic()
                    Text(bulletin.mention.titre.uppercased())
                        .font(.caption.weight(.black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(couleurMention.opacity(0.15)))
                        .foregroundStyle(couleurMention)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.fond, in: RoundedRectangle(cornerRadius: 14))

                if let mot = bulletin.motDuDelegue {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Le mot du délégué", systemImage: "rosette").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Text(mot)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.fond, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
        .background(Theme.carte)
        .navigationTitle("Conseil de classe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
        }
    }

    private var couleurMention: Color {
        if bulletin.mention.estAvertissement { return .red }
        if bulletin.mention.estPositive { return Color(red: 0.16, green: 0.6, blue: 0.3) }
        return Theme.encre
    }
}

/// Élection de délégué·e : choisir une promesse, puis le dépouillement.
struct ScolElectionView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var promesses: [ScolTexte] = []
    @State private var resultat: ScolResultatElection? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let r = resultat {
                        depouillement(r)
                    } else {
                        Text("Ta classe vote à main levée dans dix minutes. Il te faut une promesse de campagne.")
                            .font(.title3.weight(.semibold))
                        ForEach(promesses, id: \.text) { p in
                            Button {
                                resultat = engine.scolSePresenter(promesse: p)
                                if resultat == nil { dismiss() }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.text).font(.headline).foregroundStyle(Theme.encre)
                                    if let d = p.discours {
                                        Text(d).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.fond, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                        if promesses.isEmpty {
                            ScolBouton(titre: "Promettre « plus de frites »") {
                                resultat = engine.scolSePresenter(promesse: ScolTexte(type: "promesse", text: "Plus de frites",
                                    id: "frites", discours: "« Plus de frites à la cantine. Voilà. »", bonus: 8, realiste: false,
                                    bilan: "Il n'y a pas eu plus de frites. Il y a eu des haricots."))
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.carte)
            .navigationTitle("Élection de délégué·e")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(resultat == nil ? "Annuler" : "Fermer") { dismiss() } }
            }
            .onAppear {
                if promesses.isEmpty { promesses = Array(ScolDonnees.promesses.shuffled().prefix(4)) }
            }
        }
    }

    private func depouillement(_ r: ScolResultatElection) -> some View {
        let total = max(1, r.candidats.reduce(0) { $0 + $1.votes })
        return VStack(alignment: .leading, spacing: 14) {
            Text("Dépouillement").font(.caption.weight(.black)).foregroundStyle(.secondary)
            ForEach(r.candidats) { c in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(c.estJoueur ? "\(c.nom) (toi)" : c.nom).font(.headline)
                        Spacer()
                        Text("\(c.votes) voix").font(.subheadline.weight(.bold)).monospacedDigit()
                    }
                    Text(c.slogan).font(.caption).italic().foregroundStyle(.secondary)
                    GeometryReader { geo in
                        Capsule().fill(c.estJoueur ? Theme.accent : Color.gray.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(c.votes) / CGFloat(total))
                    }
                    .frame(height: 8)
                }
            }
            Text(r.texte).font(.title3.weight(.semibold)).padding(.top, 8)
            ScolBouton(titre: r.elu ? "Prendre ses fonctions" : "Ravaler sa fierté") { dismiss() }
        }
    }
}

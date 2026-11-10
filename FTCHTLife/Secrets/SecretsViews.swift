import SwiftUI

// Écrans du module Secrets. Branchement : docs/SECRETS.md (section « Branchement dans le moteur »).

/// Libellé court d'un statut, pour les listes.
func libelleStatutSecret(_ s: SecretInstance, _ j: Joueur) -> String {
    switch s.statut {
    case .cache:
        if s.estDuJoueur {
            let noms = s.savent.compactMap { Secrets.relation(j, $0)?.prenom }
            return noms.isEmpty ? "Personne ne sait" : "Au courant : " + noms.joined(separator: ", ")
        }
        return "Secret"
    case .garde: return "Tu le gardes pour toi"
    case .partage: return "Vous en avez parlé"
    case .chantage:
        if s.estDuJoueur {
            let nom = Secrets.relation(j, s.maitreChanteurId)?.prenom ?? "Quelqu'un"
            return "\(nom) te fait chanter : \(Format.argent(s.montant))/an"
        }
        return "Tu le fais chanter : \(Format.argent(s.montant))/an"
    case .equilibre: return "Équilibre de la terreur : personne ne parle"
    case .revele: return s.ageRevelation.map { "Révélé à tes \($0) ans" } ?? "Tout le monde le sait"
    }
}

/// Exécute une action de secret sur le joueur en cours, l'écrit dans le journal et renvoie le texte.
@MainActor
func actionSecret(_ engine: GameEngine, _ action: (inout Joueur) -> SecretsResultat) -> String {
    var texte = ""
    engine.modifier { j in
        let r = action(&j)
        texte = r.texte
        if !r.texte.isEmpty { engine.ajouterLigne(&j, r.texte) }
    }
    return texte
}

/// Section « Secrets » de la fiche d'un proche : fouiller, puis agir sur les secrets connus.
/// À mettre dans la `List` de `RelationDetailView` : `SecretsRelationSection(relationId: r.id, message: $message)`.
struct SecretsRelationSection: View {
    @EnvironmentObject var engine: GameEngine
    let relationId: UUID
    @Binding var message: String?

    var body: some View {
        if let j = engine.joueur, let r = j.relations.first(where: { $0.id == relationId }), r.vivant {
            let connus = (j.secrets?.duProche(r.id) ?? []).filter { $0.statut != .cache }
            Section("Secrets") {
                LigneAction(titre: "Fouiller ses affaires",
                            sousTitre: Secrets.peutFouiller(r, j) ? "Téléphone, tiroirs, poubelles… Discrètement." : "Déjà fait cette année",
                            icone: "magnifyingglass",
                            actif: Secrets.peutFouiller(r, j)) {
                    message = actionSecret(engine) { Secrets.fouiller(relationId: relationId, joueur: &$0) }
                }
                ForEach(connus) { s in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.modele?.titre ?? "Secret").font(.headline)
                        Text(Secrets.remplir(s.modele?.resume ?? "", j, cible: r, secret: s))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(libelleStatutSecret(s, j)).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    }
                    .padding(.vertical, 2)
                    actions(s, r, j)
                }
            }
        }
    }

    @ViewBuilder
    private func actions(_ s: SecretInstance, _ r: Relation, _ j: Joueur) -> some View {
        if s.statut == .garde {
            LigneAction(titre: "Lui dire que tu sais", icone: "bubble.left.fill") {
                message = actionSecret(engine) { Secrets.direQueTuSais(s.id, joueur: &$0) }
            }
        }
        if Secrets.peutFaireChanter(s, j) {
            LigneAction(titre: "Faire chanter \(r.prenom)", sousTitre: "Rentable. Pas très moral.", icone: "eurosign.circle.fill") {
                message = actionSecret(engine) { Secrets.faireChanter(s.id, joueur: &$0) }
            }
        }
        if s.statut == .chantage {
            LigneAction(titre: "Arrêter le chantage", icone: "hand.raised.fill") {
                message = actionSecret(engine) { Secrets.arreterChantage(s.id, joueur: &$0) }
            }
        }
        if s.statut == .garde || s.statut == .partage || s.statut == .chantage {
            LigneAction(titre: "Tout révéler", sousTitre: "À toute la famille. Et aux voisins.", icone: "megaphone.fill") {
                message = actionSecret(engine) { Secrets.reveler(s.id, joueur: &$0) }
            }
        }
    }
}

/// Carnet des secrets : les tiens, et ceux que tu connais sur les autres.
/// À ouvrir dans une navigation (NavigationLink, ou sheet entourée d'un NavigationStack).
struct CarnetSecretsView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        List {
            if let j = engine.joueur {
                let etat = j.secrets ?? SecretsEtat()
                let tiens = etat.duJoueur.filter { $0.statut != .revele }
                let eventes = etat.duJoueur.filter { $0.statut == .revele }
                let autres = etat.secrets.filter { !$0.estDuJoueur && $0.statut != .cache }

                Section {
                    if tiens.isEmpty {
                        Text("Aucun secret. Tu es soit un ange, soit très doué{e}."
                            .replacingOccurrences(of: "{e}", with: j.genre == .femme ? "e" : ""))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(tiens) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.modele?.titre ?? "Secret").font(.headline)
                            Text(Secrets.remplir(s.modele?.resumeJoueur ?? "", j, cible: nil, secret: s))
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(libelleStatutSecret(s, j)).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                        }
                        .padding(.vertical, 2)
                        if j.vivant {
                            if s.statut == .chantage {
                                LigneAction(titre: "Arrêter de payer", sousTitre: "Il va tout balancer.", icone: "xmark.circle.fill") {
                                    message = actionSecret(engine) { Secrets.refuserDePayer(s.id, relationId: nil, joueur: &$0) }
                                }
                                if let mc = s.maitreChanteurId, Secrets.secretConnuDe(mc, j) != nil {
                                    LigneAction(titre: "Le menacer avec son propre secret", icone: "bolt.fill") {
                                        message = actionSecret(engine) { Secrets.contreMenacer(s.id, relationId: mc, joueur: &$0) }
                                    }
                                }
                            }
                            LigneAction(titre: "Tout avouer", sousTitre: "Moins grave que de se faire balancer.", icone: "text.bubble.fill") {
                                message = actionSecret(engine) { Secrets.avouer(s.id, joueur: &$0) }
                            }
                        }
                    }
                } header: {
                    Text("Tes secrets")
                }

                if !autres.isEmpty {
                    Section("Ce que tu sais sur les autres") {
                        ForEach(autres) { s in
                            let r = Secrets.relation(j, s.porteurId)
                            NavigationLink {
                                RelationDetailView(relationId: s.porteurId ?? UUID())
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(r?.prenom ?? "?") · \(s.modele?.titre ?? "Secret")").font(.headline)
                                    Text(Secrets.remplir(s.modele?.resume ?? "", j, cible: r, secret: s))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text(libelleStatutSecret(s, j)).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                }

                if !eventes.isEmpty {
                    Section("Tes secrets éventés") {
                        ForEach(eventes) { s in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.modele?.titre ?? "Secret").font(.headline).foregroundStyle(.secondary)
                                Text(libelleStatutSecret(s, j)).font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Carnet des secrets")
        .navigationBarTitleDisplayMode(.inline)
        .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

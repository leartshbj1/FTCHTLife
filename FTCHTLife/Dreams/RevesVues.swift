import SwiftUI

/// Section « Rêves secrets » pour la liste du profil : `RevesSection(etat: j.reves, joueur: j)`.
struct RevesSection: View {
    let etat: RevesDeVie?
    let joueur: Joueur

    private var reves: [ReveActif] { etat?.reves ?? [] }

    var body: some View {
        Section {
            if !reves.isEmpty {
                ForEach(reves) { actif in
                    ReveLigne(actif: actif, joueur: joueur)
                }
            } else {
                Text(messageVide)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Rêves secrets")
        } footer: {
            if !reves.isEmpty {
                Text(resume)
            }
        }
    }

    private var messageVide: String {
        if joueur.age < RevesMoteur.ageTirage {
            return "Pour l'instant tu rêves surtout de bonbons. Les vrais rêves arrivent à \(RevesMoteur.ageTirage) ans."
        }
        return "Aucun rêve pour l'instant. Passe une année, ça va venir."
    }

    private var resume: String {
        let faits = reves.filter { $0.statut == .realise }.count
        if faits == reves.count { return "Tous tes rêves sont réalisés. Tu as gagné la vie (presque)." }
        return "\(faits) sur \(reves.count) réalisé\(faits > 1 ? "s" : ""). Personne d'autre ne connaît ces rêves."
    }
}

/// Une ligne de rêve : niveau, titre, description et statut.
struct ReveLigne: View {
    let actif: ReveActif
    let joueur: Joueur

    private var definition: ReveDefinition? { RevesMoteur.definition(actif.id) }

    private var couleur: Color {
        switch actif.statut {
        case .realise: return Theme.couleurStat(100)
        case .rate: return Theme.couleurStat(0)
        case .enCours: return Theme.accent
        }
    }

    private var icone: String {
        switch actif.statut {
        case .realise: return "checkmark.seal.fill"
        case .rate: return "xmark.circle.fill"
        case .enCours: return definition?.level.icone ?? "sparkles"
        }
    }

    private var statut: String {
        switch actif.statut {
        case .realise: return actif.ageFin.map { "Réalisé à \($0) ans" } ?? "Réalisé"
        case .rate: return actif.ageFin.map { "Raté à \($0) ans" } ?? "Raté"
        case .enCours:
            if let limite = definition?.deadlineAge {
                return "En cours, avant \(limite) ans"
            }
            return "En cours"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icone)
                .font(.title3)
                .foregroundStyle(couleur)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(RevesMoteur.titre(actif, joueur))
                        .font(.headline)
                        .strikethrough(actif.statut == .rate)
                    Spacer(minLength: 6)
                    if let niveau = definition?.level {
                        Text(niveau.nom)
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                }
                if let d = definition {
                    Text(RevesMoteur.texte(d.description, joueur))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(statut)
                    .font(.caption.bold())
                    .foregroundStyle(couleur)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Carte du score « vie réussie » pour l'écran de mort (fond sombre) : `RevesScoreCarte(etat: j.reves, joueur: j)`.
struct RevesScoreCarte: View {
    let etat: RevesDeVie?
    let joueur: Joueur

    private var score: RevesScore { RevesMoteur.score(etat, joueur: joueur) }

    var body: some View {
        let s = score
        VStack(spacing: 8) {
            Text("VIE RÉUSSIE ?")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(s.total)")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.couleurStat(s.total))
                Text("/100")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(s.mention)
                .font(.headline)
                .foregroundStyle(.white)
            Text(s.commentaire)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            if !s.details.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(s.details.enumerated()), id: \.offset) { _, ligne in
                        Text(ligne)
                            .font(.footnote)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            Text(s.revesTires > 0 ? "Rêves \(s.partReves)/60 · Vie \(s.partVie)/40" : "Vie \(s.partVie)/40, sans rêves")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 32)
    }
}

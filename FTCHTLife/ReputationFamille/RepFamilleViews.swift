import SwiftUI

// Écrans de la réputation familiale. Ils ne dépendent pas du moteur : on leur passe le joueur,
// l'état et une fonction qui exécute une action (voir docs/REPUTATION_FAMILLE.md, point 11).

extension RepFamilleAxe {
    var couleur: Color {
        switch self {
        case .respectee: return Color(red: 0.16, green: 0.55, blue: 0.40)
        case .mafieuse: return Color(red: 0.20, green: 0.20, blue: 0.24)
        case .ridicule: return Color(red: 0.96, green: 0.60, blue: 0.10)
        case .maudite: return Color(red: 0.45, green: 0.25, blue: 0.62)
        case .celebre: return Color(red: 0.90, green: 0.70, blue: 0.10)
        }
    }
}

/// Petite pastille « Famille mafieuse » pour le profil ou l'en-tête.
struct RepFamilleBadge: View {
    let etat: RepFamilleEtat

    var body: some View {
        let axe = etat.scores.dominante
        HStack(spacing: 6) {
            Image(systemName: axe?.icone ?? "house.fill")
            Text(ReputationFamille.titre(etat))
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((axe?.couleur ?? .gray).opacity(0.15), in: Capsule())
        .foregroundStyle(axe?.couleur ?? .gray)
    }
}

/// Une jauge de réputation.
struct RepFamilleJauge: View {
    let axe: RepFamilleAxe
    let valeur: Int
    var depart: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: axe.icone)
                .frame(width: 18)
                .foregroundStyle(axe.couleur)
            Text(axe.nomJauge)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(axe.couleur)
                        .frame(width: geo.size.width * CGFloat(valeur) / 100)
                        .animation(.easeOut(duration: 0.4), value: valeur)
                    if let d = depart, d != valeur {
                        Rectangle().fill(Theme.encre.opacity(0.6))
                            .frame(width: 2, height: 14)
                            .offset(x: geo.size.width * CGFloat(d) / 100 - 1)
                    }
                }
            }
            .frame(height: 10)
            Text(texteValeur)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)
        }
    }

    private var texteValeur: String {
        guard let d = depart, d != valeur else { return "\(valeur)" }
        let diff = valeur - d
        return "\(valeur) " + (diff > 0 ? "▲" : "▼")
    }
}

/// Écran « Famille » : réputation, arbre des ancêtres, registre des hauts faits, actions.
struct RepFamilleView: View {
    let joueur: Joueur
    let etat: RepFamilleEtat
    /// Exécute l'action et renvoie le texte du résultat.
    let faire: (RepFamilleAction) -> String

    @State private var resultat: String?
    @State private var confirmerChangement = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 34))
                            .foregroundStyle(etat.scores.dominante?.couleur ?? Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Les \(joueur.nom)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                            Text(ReputationFamille.titre(etat))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Gén. \(etat.generation)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Theme.fond, in: Capsule())
                    }
                    Text(ReputationFamille.resume(etat, nom: joueur.nom))
                        .font(.callout)
                        .italic()
                }
                .padding(.vertical, 4)
            }

            Section {
                ForEach(RepFamilleAxe.allCases) { axe in
                    RepFamilleJauge(axe: axe, valeur: etat.scores[axe], depart: etat.scoresDepart[axe])
                }
            } header: {
                Text("Réputation")
            } footer: {
                Text("Le trait marque la réputation à ta naissance. À ta mort, ton héritier reçoit une bonne partie de tout ça.")
            }

            Section("Redorer ou salir le nom") {
                ForEach(RepFamilleAction.allCases) { a in
                    let raison = ReputationFamille.indisponible(a, joueur: joueur, etat: etat)
                    LigneAction(titre: a.titre,
                                sousTitre: raison ?? a.description(joueur),
                                icone: a.icone,
                                actif: raison == nil) {
                        if a == .changerNom {
                            confirmerChangement = true
                        } else {
                            resultat = faire(a)
                        }
                    }
                }
            }

            if !etat.ancetres.isEmpty {
                Section("Arbre des ancêtres") {
                    ForEach(Array(etat.ancetres.reversed())) { a in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(a.prenom) \(a.nom) \(a.surnom)")
                                .font(.headline)
                            Text(ligneAncetre(a))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            let apports = apportsTexte(a)
                            if !apports.isEmpty {
                                Text(apports)
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !etat.faits.isEmpty {
                Section("Registre de la famille") {
                    ForEach(Array(etat.faits.reversed())) { f in
                        Text(f.texte).font(.callout)
                    }
                }
            }
        }
        .navigationTitle("Famille")
        .alert("Famille \(joueur.nom)", isPresented: Binding(get: { resultat != nil }, set: { if !$0 { resultat = nil } })) {
            Button("OK", role: .cancel) { resultat = nil }
        } message: {
            Text(resultat ?? "")
        }
        .confirmationDialog("Changer de nom de famille ?", isPresented: $confirmerChangement, titleVisibility: .visible) {
            Button("Changer de nom (\(Format.argent(RepFamilleAction.changerNom.prix(joueur))))", role: .destructive) {
                resultat = faire(.changerNom)
            }
            Button("Garder « \(joueur.nom) »", role: .cancel) {}
        } message: {
            Text("La réputation s'efface presque entièrement. Presque.")
        }
    }

    private func ligneAncetre(_ a: RepFamilleAncetre) -> String {
        let lien = ReputationFamille.lien(a, generationActuelle: etat.generation)
        let mort = a.genre == .femme ? "morte" : "mort"
        let lienMaj = lien.prefix(1).uppercased() + String(lien.dropFirst())
        var t = "Génération \(a.generation) · \(lienMaj) · \(mort) à \(a.ageDeces) ans"
        if let c = a.cause { t += " \(c)" }
        return t
    }

    private func apportsTexte(_ a: RepFamilleAncetre) -> String {
        var morceaux: [String] = []
        for axe in RepFamilleAxe.allCases {
            let net = a.apport[axe] - a.apportNegatif[axe]
            if abs(net) >= 5 { morceaux.append("\(axe.nomJauge) \(net > 0 ? "+" : "")\(net)") }
        }
        return morceaux.joined(separator: " · ")
    }
}

/// Section à mettre dans l'écran de mort : ce que cette vie a fait au nom de la famille.
struct RepFamilleBilanView: View {
    let etat: RepFamilleEtat

    var body: some View {
        if let b = etat.dernierBilan {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(b.prenom) \(b.surnom)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                ForEach(b.lignes, id: \.self) { l in
                    Text(l).font(.callout)
                }
                ForEach(RepFamilleAxe.allCases) { axe in
                    let diff = b.apres[axe] - b.avant[axe]
                    if diff != 0 {
                        HStack {
                            Image(systemName: axe.icone).frame(width: 18)
                            Text(axe.nomJauge)
                            Spacer()
                            Text("\(b.avant[axe]) → \(b.apres[axe])").bold().monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

import SwiftUI

/// Menu d'une catégorie : des tuiles rangées par groupe. Une tuile ouvre l'écran d'un module.
struct MenuCategorieView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let categorie: CategorieMenu

    @State private var ouvert: ModuleJeu?
    @State private var message: String?
    @State private var resultat: ResultatRapide?

    private let colonnes = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let j = engine.joueur {
                    VStack(alignment: .leading, spacing: 22) {
                        entete(j)
                        if categorie == .activites {
                            activitesRapides(j)
                        }
                        ForEach(groupes(j), id: \.titre) { g in
                            VStack(alignment: .leading, spacing: 10) {
                                titreGroupe(g.titre)
                                LazyVGrid(columns: colonnes, spacing: 12) {
                                    ForEach(g.modules) { m in
                                        TuileModule(titre: m.titre, description: m.description, icone: m.icone,
                                                    couleur: categorie.couleur, verrou: m.verrou(j), badge: pastille(m, j)) {
                                            if let raison = m.verrou(j) {
                                                message = raison
                                            } else {
                                                Vibration.legere()
                                                ouvert = m
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Theme.fond.ignoresSafeArea())
            .navigationTitle(categorie.titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .sheet(item: $ouvert) { m in
                EcranModule(module: m)
                    .environmentObject(engine)
            }
            .alerteResultat($message)
            .sheet(item: $resultat) { r in
                ResultatRapideView(resultat: r, couleur: categorie.couleur)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: En-tête

    private func entete(_ j: Joueur) -> some View {
        HStack(spacing: 14) {
            Image(systemName: categorie.icone)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(categorie.couleur))
            VStack(alignment: .leading, spacing: 3) {
                Text(resume(j))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.encre)
                Text(categorie.aide)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.carte))
    }

    private func resume(_ j: Joueur) -> String {
        switch categorie {
        case .carriere:
            if let e = j.emploi { return "\(e.titre) · \(Format.argent(e.salaire))/an" }
            return j.occupation
        case .biens:
            return "Argent : \(Format.argent(j.argent))"
        case .relations:
            let n = j.relations.filter { $0.vivant }.count
            return n == 0 ? "Tu es seul\(j.genre == .femme ? "e" : "") au monde" : "\(n) proche\(n > 1 ? "s" : "")"
        case .activites:
            return j.age < 18 ? "Tes parents paient (pour l'instant)" : "Argent : \(Format.argent(j.argent))"
        case .moi:
            return "\(j.nomComplet), \(j.age) an\(j.age > 1 ? "s" : "")"
        }
    }

    private func titreGroupe(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(categorie.couleur)
            .tracking(0.6)
    }

    // MARK: Groupes

    private struct Groupe {
        let titre: String
        let modules: [ModuleJeu]
    }

    private func groupes(_ j: Joueur) -> [Groupe] {
        var ordre: [String] = []
        var parGroupe: [String: [ModuleJeu]] = [:]
        for m in ModuleJeu.allCases where m.categorie == categorie && m.visible(j) {
            if parGroupe[m.groupe] == nil { ordre.append(m.groupe) }
            parGroupe[m.groupe, default: []].append(m)
        }
        return ordre.map { Groupe(titre: $0, modules: parGroupe[$0] ?? []) }
    }

    /// Pastille (nombre de choses en attente) sur une tuile.
    private func pastille(_ m: ModuleJeu, _ j: Joueur) -> Int {
        switch m {
        case .telephone: return PhoneEngine.nonLus(j.telephone)
        case .boutique: return engine.evenementsBoutiqueEnAttente
        case .chirurgie: return j.beaute?.suites.count ?? 0
        case .vieAuBahut, .ecole: return engine.scolEtat?.aFaire.count ?? 0
        default: return 0
        }
    }

    // MARK: Activités rapides (moteur)

    /// Les petites activités du moteur, faites en un geste. Le casino a son propre écran.
    private func activitesRapides(_ j: Joueur) -> some View {
        let liste = GameEngine.activites.filter { $0.id != "casino" }
        return VStack(alignment: .leading, spacing: 10) {
            titreGroupe("Tout de suite (une fois par an)")
            LazyVGrid(columns: colonnes, spacing: 12) {
                ForEach(liste) { a in
                    let raison = verrouActivite(a, j)
                    TuileModule(titre: a.titre,
                                description: a.description + (a.cout > 0 && j.age >= 18 ? " \(Format.argent(a.cout))." : ""),
                                icone: a.icone, couleur: categorie.couleur, verrou: raison, badge: 0) {
                        if let r = raison {
                            message = r
                        } else {
                            Vibration.legere()
                            let avant = Instantane(stats: j.stats, argent: j.argent)
                            let texte = engine.faireActivite(a)
                            let apres = engine.joueur.map { ChangementStat.entre(avant, $0) } ?? []
                            resultat = ResultatRapide(titre: a.titre, icone: a.icone, texte: texte, changements: apres)
                        }
                    }
                }
            }
        }
    }

    private func verrouActivite(_ a: Activite, _ j: Joueur) -> String? {
        if !j.vivant { return "Plus possible." }
        if j.vieEtat.justice.enPrison { return "Tu es en prison." }
        if j.age < a.ageMin { return "Dès \(a.ageMin) ans." }
        if j.actionsAnnee.contains("act_" + a.id) { return "Déjà fait cette année. Reviens après « Âge +1 »." }
        return nil
    }
}

/// Tuile carrée d'un menu : icône, titre, description, cadenas ou pastille.
struct TuileModule: View {
    let titre: String
    let description: String
    let icone: String
    let couleur: Color
    let verrou: String?
    let badge: Int
    let action: () -> Void

    var body: some View {
        let ouvert = verrou == nil
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: icone)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ouvert ? Color.white : Theme.gris)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10).fill(ouvert ? couleur : Color.black.opacity(0.06)))
                    Spacer(minLength: 0)
                    if !ouvert {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.gris)
                    } else if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.argentNegatif))
                    }
                }
                Text(titre)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ouvert ? Theme.encre : Theme.gris)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.carte))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(ouvert ? couleur.opacity(0.25) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(StyleAppui())
    }
}

/// Résultat d'une activité rapide, montré dans une petite fiche.
struct ResultatRapide: Identifiable {
    let id = UUID()
    let titre: String
    let icone: String
    let texte: String
    let changements: [ChangementStat]
}

struct ResultatRapideView: View {
    @Environment(\.dismiss) private var dismiss
    let resultat: ResultatRapide
    let couleur: Color

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: resultat.icone)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(couleur))
                .padding(.top, 24)
            Text(resultat.titre)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.encre)
            Text(resultat.texte)
                .font(.body)
                .foregroundStyle(Theme.encre)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            if !resultat.changements.isEmpty {
                PastillesChangements(elements: resultat.changements)
            }
            Spacer(minLength: 0)
            BoutonEvenement(titre: "OK", couleur: couleur, badge: nil, principal: true) { dismiss() }
                .padding(.horizontal)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.carte)
    }
}

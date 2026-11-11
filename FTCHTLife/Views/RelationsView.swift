import SwiftUI

enum FiltreRelations: String {
    case famille, amour, amis

    var titre: String {
        switch self {
        case .famille: return "Famille"
        case .amour: return "Amour"
        case .amis: return "Amis"
        }
    }

    func garde(_ r: Relation) -> Bool {
        switch self {
        case .famille: return [TypeRelation.mere, .pere, .frere, .soeur, .enfant].contains(r.type)
        case .amour: return r.type == .partenaire || r.type == .ex
        case .amis: return r.type == .ami
        }
    }

    var vide: String {
        switch self {
        case .famille: return "Personne. Même pas un cousin éloigné."
        case .amour: return "Personne pour l'instant. Ton cœur est en mode avion."
        case .amis: return "Aucun ami. Les plantes vertes, ça compte ?"
        }
    }
}

/// Liste des proches d'une catégorie (famille, amour ou amis).
struct ListeRelationsView: View {
    @EnvironmentObject var engine: GameEngine
    let filtre: FiltreRelations

    var body: some View {
        Feuille(titre: filtre.titre) {
            List {
                if let j = engine.joueur {
                    let liste = j.relations.filter { filtre.garde($0) }
                    let vivants = liste.filter { $0.vivant }
                    let morts = liste.filter { !$0.vivant }
                    if liste.isEmpty {
                        Text(filtre.vide).foregroundStyle(.secondary)
                    }
                    if !vivants.isEmpty {
                        Section(filtre == .amour ? "Cœur" : "Proches") {
                            ForEach(vivants) { r in lien(r) }
                        }
                    }
                    if filtre == .amour {
                        CoeurSection()
                    }
                    if filtre == .famille || filtre == .amour {
                        VieFamilleSection()
                    }
                    if !morts.isEmpty {
                        Section("Disparus") {
                            ForEach(morts) { r in lien(r) }
                        }
                    }
                }
            }
            .presentoirRacine()
        }
    }

    private func lien(_ r: Relation) -> some View {
        NavigationLink {
            RelationDetailView(relationId: r.id)
        } label: {
            HStack(spacing: 12) {
                VisageProche(relation: r, taille: 42)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(r.nomComplet).font(.headline).foregroundStyle(r.vivant ? Theme.encre : .gray)
                        Spacer()
                        Text(r.vivant ? "\(r.libelle) · \(r.age) ans" : "\(r.libelle) · décédé\(r.genre == .femme ? "e" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if r.vivant {
                        BarreStat(titre: "Relation", icone: "heart.fill", valeur: r.lien)
                    }
                }
            }
        }
    }
}

/// Fiche d'un proche : actions du moteur, du module amour/crime/santé et des secrets.
struct RelationDetailView: View {
    @EnvironmentObject var engine: GameEngine
    let relationId: UUID
    @State private var message: String?

    var body: some View {
        List {
            if let r = engine.joueur?.relations.first(where: { $0.id == relationId }) {
                Section {
                    FicheProche(relation: r)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if r.vivant && r.type == .partenaire {
                    // Partenaire : toutes les actions de couple, rangées par thème (module Cœur).
                    CoeurCoupleActions(relationId: r.id)
                    SecretsRelationSection(relationId: r.id, message: $message)
                } else if r.vivant {
                    Section("Actions") {
                        ForEach(engine.actionsPossibles(r)) { a in
                            LigneAction(titre: a.titre, icone: a.icone) {
                                message = engine.agir(a, sur: r.id)
                            }
                        }
                    }
                    CoeurActionsProcheSection(relationId: r.id)
                    VieRelationActions(relationId: r.id)
                    SecretsRelationSection(relationId: r.id, message: $message)
                } else {
                    Text("Repose en paix, \(r.prenom).")
                }
            }
        }
        .navigationTitle(engine.joueur?.relations.first(where: { $0.id == relationId })?.prenom ?? "")
        .alerteResultat($message)
        .presentoirRacine()
    }
}

// MARK: - Visage et fiche d'un proche

/// Petit visage d'un proche, selon son âge, son genre et s'il est encore là.
struct VisageProche: View {
    let relation: Relation
    var taille: CGFloat = 42

    private var visage: String {
        let r = relation
        let f = r.genre == .femme
        if !r.vivant { return "🪦" }
        switch r.age {
        case ..<3: return "👶"
        case ..<13: return f ? "👧" : "👦"
        case ..<60: return f ? "👩" : "👨"
        default: return f ? "👵" : "👴"
        }
    }

    private var couleur: Color {
        switch relation.type {
        case .mere, .pere, .frere, .soeur, .enfant: return CategorieMenu.relations.couleur
        case .partenaire, .ex: return Color(red: 0.85, green: 0.15, blue: 0.35)
        case .ami: return CategorieMenu.activites.couleur
        }
    }

    var body: some View {
        Text(visage)
            .font(.system(size: taille * 0.56))
            .frame(width: taille, height: taille)
            .background(Circle().fill(couleur.opacity(0.14)))
            .overlay(Circle().stroke(couleur.opacity(0.4), lineWidth: 2))
    }
}

/// En-tête de la fiche d'un proche : visage, nom, lien, âge, jauge de relation.
struct FicheProche: View {
    let relation: Relation

    private var humeur: String {
        let l = relation.lien
        switch l {
        case ..<15: return "Vous vous détestez cordialement."
        case ..<35: return "C'est tendu."
        case ..<60: return "Ça va, sans plus."
        case ..<85: return "Vous vous entendez bien."
        default: return "Inséparables."
        }
    }

    var body: some View {
        let r = relation
        VStack(spacing: 10) {
            VisageProche(relation: r, taille: 76)
            Text(r.nomComplet)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.encre)
            Text(r.vivant ? "\(r.libelle) · \(r.age) ans" : "\(r.libelle) · parti\(r.genre == .femme ? "e" : "") à \(r.age) ans")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if r.vivant {
                BarreStat(titre: "Relation", icone: "heart.fill", valeur: r.lien)
                    .padding(.top, 4)
                Text(humeur)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.carte))
    }
}

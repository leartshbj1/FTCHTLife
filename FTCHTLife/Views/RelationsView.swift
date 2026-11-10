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
        }
    }

    private func lien(_ r: Relation) -> some View {
        NavigationLink {
            RelationDetailView(relationId: r.id)
        } label: {
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

/// Fiche d'un proche : actions du moteur, du module amour/crime/santé et des secrets.
struct RelationDetailView: View {
    @EnvironmentObject var engine: GameEngine
    let relationId: UUID
    @State private var message: String?

    var body: some View {
        List {
            if let r = engine.joueur?.relations.first(where: { $0.id == relationId }) {
                Section {
                    HStack { Text("Lien"); Spacer(); Text(r.libelle).foregroundStyle(.secondary) }
                    HStack { Text("Âge"); Spacer(); Text("\(r.age) ans").foregroundStyle(.secondary) }
                    if r.vivant {
                        BarreStat(titre: "Relation", icone: "heart.fill", valeur: r.lien)
                    }
                }
                if r.vivant {
                    Section("Actions") {
                        ForEach(engine.actionsPossibles(r)) { a in
                            LigneAction(titre: a.titre, icone: a.icone) {
                                message = engine.agir(a, sur: r.id)
                            }
                        }
                    }
                    VieRelationActions(relationId: r.id)
                    SecretsRelationSection(relationId: r.id, message: $message)
                } else {
                    Text("Repose en paix, \(r.prenom).")
                }
            }
        }
        .navigationTitle(engine.joueur?.relations.first(where: { $0.id == relationId })?.prenom ?? "")
        .alerteResultat($message)
    }
}

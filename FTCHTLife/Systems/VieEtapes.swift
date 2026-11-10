import Foundation

/// Petits messages d'après : premiers pas du bébé, anniversaires de mariage, nouvelles des amis…
/// Données : Data/Relationships/*.json (voir docs/donnees-vie-sociale.md).
enum VieEtapes {

    /// Personnes concernées par un `kind`, avec leur âge.
    private struct Cible {
        let id: String
        let prenom: String
        let age: Int
        let relationId: UUID?
    }

    private static func cibles(_ kind: String, _ j: Joueur) -> [Cible] {
        let v = j.vieEtat
        func rel(_ types: [TypeRelation]) -> [Cible] {
            j.relations.filter { $0.vivant && types.contains($0.type) }.map { Cible(id: $0.id.uuidString, prenom: $0.prenom, age: $0.age, relationId: $0.id) }
        }
        switch kind {
        case "child": return rel([.enfant])
        case "grandchild": return v.petitsEnfants.map { Cible(id: $0.id.uuidString, prenom: $0.prenom, age: $0.age, relationId: nil) }
        case "partner": return v.statutCouple == nil ? rel([.partenaire]) : []
        case "fiance": return v.statutCouple == .fiance ? rel([.partenaire]) : []
        case "spouse": return v.statutCouple == .marie ? rel([.partenaire]) : []
        case "friend": return rel([.ami]).filter { $0.relationId != v.meilleurAmiId }
        case "bestFriend": return rel([.ami]).filter { $0.relationId == v.meilleurAmiId }
        case "ex": return rel([.ex])
        case "mother": return rel([.mere])
        case "father": return rel([.pere])
        case "brother": return rel([.frere])
        case "sister": return rel([.soeur])
        case "self": return [Cible(id: "self", prenom: j.prenom, age: j.age, relationId: nil)]
        default: return []
        }
    }

    static func annoncer(_ j: inout Joueur) -> [String] {
        guard !VieDonnees.etapes.isEmpty else { return [] }
        var lignes: [String] = []
        var aleatoires = 0
        let enPrison = j.vieEtat.justice.enPrison
        for e in VieDonnees.etapes.shuffled() {
            for c in cibles(e.kind, j) {
                let cle = "\(e.id)#\(c.id)"
                var ok = false
                switch e.trigger {
                case "age":
                    ok = c.age == Int(e.value) && !j.vieEtat.etapesVues.contains(cle)
                case "years":
                    ok = j.vieEtat.anneesEnsemble == Int(e.value) && !j.vieEtat.etapesVues.contains(cle)
                case "chance":
                    ok = aleatoires < 2 && !enPrison && VieHasard.reussi(e.value)
                    if ok { aleatoires += 1 }
                default:
                    ok = false
                }
                guard ok else { continue }
                if e.trigger != "chance" {
                    var v = j.vieEtat
                    v.etapesVues.append(cle)
                    j.vieEtat = v
                }
                let texte = e.texts.auHasard("")
                    .replacingOccurrences(of: "{nom}", with: c.prenom)
                    .replacingOccurrences(of: "{prenom}", with: j.prenom)
                if !texte.isEmpty { lignes.append(texte) }
                if let fx = e.effects {
                    VieCrime.appliquer(fx, &j)
                    if let b = fx.bond, let id = c.relationId, let i = j.relations.firstIndex(where: { $0.id == id }) {
                        j.relations[i].lien = Stats.borne(j.relations[i].lien + b)
                    }
                }
            }
        }
        return lignes
    }
}

import Foundation
import SwiftUI

/// Collection des vies terminées, sauvegardée à part de la vie en cours (Documents/ftchtlife-musee.json).
@MainActor
final class MuseeStore: ObservableObject {
    static let shared = MuseeStore()

    /// Vies du musée, la plus récente en premier.
    @Published private(set) var vies: [MuseeVie] = []

    private let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ftchtlife-musee.json")
        charger()
    }

    /// Range une vie terminée au musée et renvoie sa fiche. Une même vie n'est enregistrée qu'une fois :
    /// rappeler la fonction renvoie la fiche existante (même surnom, même nécrologie).
    @discardableResult
    func enregistrer(joueur j: Joueur, dernierMetier: String? = nil, scoreVieReussie: Int? = nil) -> MuseeVie {
        let id = Necrologue.identifiant(j)
        if let existante = vies.first(where: { $0.id == id }) { return existante }
        let vie = Necrologue.generer(joueur: j, dernierMetier: dernierMetier, scoreVieReussie: scoreVieReussie)
        vies.insert(vie, at: 0)
        sauvegarder()
        return vie
    }

    /// Fiche d'une vie déjà au musée, sans rien générer.
    func fiche(pour j: Joueur) -> MuseeVie? {
        let id = Necrologue.identifiant(j)
        return vies.first { $0.id == id }
    }

    /// Met à jour le score « vie réussie » d'une vie déjà rangée (si Rêves de vie le calcule après coup).
    func definirScore(_ score: Int, pourVie id: String) {
        guard let i = vies.firstIndex(where: { $0.id == id }) else { return }
        vies[i].scoreVieReussie = score
        sauvegarder()
    }

    func supprimer(_ id: String) {
        vies.removeAll { $0.id == id }
        sauvegarder()
    }

    func toutEffacer() {
        vies = []
        sauvegarder()
    }

    // MARK: - Records

    var recordLongevite: MuseeVie? { vies.max { $0.age < $1.age } }
    var recordFortune: MuseeVie? { vies.max { $0.fortune < $1.fortune } }
    var recordDettes: MuseeVie? { vies.filter { $0.fortune < 0 }.min { $0.fortune < $1.fortune } }
    var recordBrievete: MuseeVie? { vies.min { $0.age < $1.age } }
    var ageMoyen: Int { vies.isEmpty ? 0 : vies.map(\.age).reduce(0, +) / vies.count }
    var scoreMoyen: Int? {
        let scores = vies.compactMap(\.scoreVieReussie)
        return scores.isEmpty ? nil : scores.reduce(0, +) / scores.count
    }

    // MARK: - Sauvegarde

    private func charger() {
        guard let data = try? Data(contentsOf: url) else { return }
        let decodeur = JSONDecoder()
        decodeur.dateDecodingStrategy = .iso8601
        if let v = try? decodeur.decode([MuseeVie].self, from: data) {
            vies = v
        }
    }

    private func sauvegarder() {
        let encodeur = JSONEncoder()
        encodeur.dateEncodingStrategy = .iso8601
        guard let data = try? encodeur.encode(vies) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

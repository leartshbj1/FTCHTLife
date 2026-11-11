import SwiftUI

// Mode rapide (idée 48) : animations courtes, choix en un tap, « avancer jusqu'au prochain moment ».
// Les deux réglages sont dans Moi > Réglages > Vitesse du jeu, et actifs par défaut.

enum ModeRapide {
    /// Animations courtes partout où le jeu en fait.
    static let cleActif = "modeRapide"
    /// Un seul tap par événement : le résultat s'affiche en bandeau, sans bouton « Continuer ».
    static let cleUnTap = "choixEnUnTap"

    static var actif: Bool { UserDefaults.standard.object(forKey: cleActif) as? Bool ?? true }
    static var unTap: Bool { UserDefaults.standard.object(forKey: cleUnTap) as? Bool ?? true }

    /// L'animation à jouer : la normale, ou une version très courte en mode rapide.
    static func animation(_ normale: Animation, rapide: Bool = ModeRapide.actif) -> Animation {
        rapide ? .easeOut(duration: 0.12) : normale
    }

    /// Nombre maximum d'années passées d'un coup par « Avancer ».
    static let maxAnnees = 10
}

// MARK: - Résultat en bandeau (choix en un tap)

/// Ce qu'un choix vient de donner, affiché un instant en haut de l'écran.
struct ResultatBandeau: Identifiable, Equatable {
    let id = UUID()
    let titre: String
    let texte: String
    let couleur: Color
    let changements: [ChangementStat]
}

struct BandeauResultatView: View {
    let resultat: ResultatBandeau
    let fermer: () -> Void

    var body: some View {
        Button(action: fermer) {
            VStack(alignment: .leading, spacing: 6) {
                Text(resultat.titre)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(resultat.couleur)
                    .lineLimit(1)
                Text(resultat.texte)
                    .font(.subheadline)
                    .foregroundStyle(Theme.encre)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(6)
                if !resultat.changements.isEmpty {
                    PastillesChangements(elements: resultat.changements)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.carte))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(resultat.couleur.opacity(0.35), lineWidth: 1.5))
            .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Touche pour masquer")
    }
}

// MARK: - Avancer jusqu'au prochain moment important

extension GameEngine {
    /// Fait passer les années une par une jusqu'à ce que quelque chose demande le joueur :
    /// un événement à choix, la une du monde, un bilan d'entreprise, un animal, une tâche d'école,
    /// la majorité, la mort… ou au plus `ModeRapide.maxAnnees` ans. Renvoie le nombre d'années passées.
    @discardableResult
    func avancerJusquauProchainMoment(maxAnnees: Int = ModeRapide.maxAnnees) -> Int {
        var annees = 0
        while annees < maxAnnees, let j = joueur, j.vivant, evenementEnCours == nil, flashMonde == nil {
            let tachesAvant = Set((scolEtat?.aFaire ?? []).map { "\($0.id)" })
            let ageAvant = j.age
            vieillir()
            annees += 1
            guard let k = joueur, k.vivant else { break }
            if evenementEnCours != nil || flashMonde != nil { break }
            if !entreprisesAvecRapportNonLu.isEmpty { break }
            if k.speciales?.bilan?.important == true { break }
            if !etatAnimaux(\.animaux).enAttente.isEmpty { break }
            // Un bébé est né : on s'arrête pour choisir son prénom.
            if !k.coeurEtat.bebesANommer.isEmpty { break }
            let tachesApres = Set((scolEtat?.aFaire ?? []).map { "\($0.id)" })
            if !tachesApres.subtracting(tachesAvant).isEmpty { break }
            // Les grands caps de la vie méritent qu'on s'arrête.
            if [6, 11, 15, 18, 25, 30, 40, 50, 60, 65, 70, 80, 90].contains(where: { ageAvant < $0 && k.age >= $0 }) { break }
            if k.journal.last?.lignes.contains(where: { $0.hasPrefix("⚠️") || $0.hasPrefix("🚨") }) == true { break }
        }
        return annees
    }
}

// MARK: - Réglages

/// Section « Vitesse du jeu » de l'écran Réglages.
struct ModeRapideReglages: View {
    @AppStorage(ModeRapide.cleActif) private var rapide = true
    @AppStorage(ModeRapide.cleUnTap) private var unTap = true

    var body: some View {
        Section {
            Toggle(isOn: $rapide) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mode rapide").font(.headline)
                        Text("Animations très courtes, et le bouton ⏩ pour avancer jusqu'au prochain moment important.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hare.fill").foregroundStyle(Theme.accent)
                }
            }
            Toggle(isOn: $unTap) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choix en un tap").font(.headline)
                        Text("Le résultat s'affiche en bandeau et l'événement suivant arrive tout de suite, sans « Continuer ».")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hand.tap.fill").foregroundStyle(Theme.accent)
                }
            }
        } header: {
            Text("Vitesse du jeu")
        }
    }
}

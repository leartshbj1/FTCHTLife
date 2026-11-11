import SwiftUI

// Quantités libres (idée 49) : ×1 ×10 ×100 Max et « comme la dernière fois », partout où l'on
// achète ou mise en nombre (bourse et placements, boutique, casino). Le trafic a son propre écran.

/// Se souvient de la dernière quantité ou du dernier montant choisi pour chaque chose.
enum MemoireQuantites {
    private static let cle = "memoireQuantites"
    private static let cleTextes = "memoireQuantitesTextes"

    static func derniere(_ nom: String) -> Int? {
        let d = UserDefaults.standard.dictionary(forKey: cle) as? [String: Int]
        guard let v = d?[nom], v > 0 else { return nil }
        return v
    }

    static func retenir(_ nom: String, _ valeur: Int) {
        guard valeur > 0 else { return }
        var d = UserDefaults.standard.dictionary(forKey: cle) as? [String: Int] ?? [:]
        d[nom] = valeur
        UserDefaults.standard.set(d, forKey: cle)
    }

    static func texte(_ nom: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: cleTextes) as? [String: String])?[nom]
    }

    static func retenirTexte(_ nom: String, _ valeur: String) {
        var d = UserDefaults.standard.dictionary(forKey: cleTextes) as? [String: String] ?? [:]
        d[nom] = valeur
        UserDefaults.standard.set(d, forKey: cleTextes)
    }
}

/// Rangée de boutons ×1 ×10 ×100 Max (+ « Comme la dernière fois »), avec un compteur pour ajuster.
struct SelecteurQuantite: View {
    @Binding var quantite: Int
    /// Le plus grand nombre possible (argent, stock…). 0 = rien de possible.
    let maximum: Int
    /// Dernière quantité choisie, proposée en raccourci.
    var derniere: Int? = nil
    var unite: String = ""
    var couleur: Color = Theme.accent

    private var paliers: [Int] { [1, 10, 100].filter { $0 <= maximum } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper(value: Binding(get: { quantite }, set: { quantite = min(max(1, $0), max(1, maximum)) }),
                    in: 1...max(1, maximum)) {
                Text("Quantité : \(quantite)\(unite.isEmpty ? "" : " " + unite)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(paliers, id: \.self) { v in
                        puce("×\(v)", actif: quantite == v) { quantite = v }
                    }
                    if maximum > 1 {
                        puce("Max (\(maximum))", actif: quantite == maximum) { quantite = maximum }
                    }
                    if let d = derniere, d <= maximum, d > 0 {
                        puce("Comme la dernière fois (\(d))", actif: false) { quantite = d }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .onAppear { quantite = min(max(1, quantite), max(1, maximum)) }
    }

    private func puce(_ titre: String, actif: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titre)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(actif ? Color.white : couleur)
                .background(Capsule().fill(actif ? couleur : couleur.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

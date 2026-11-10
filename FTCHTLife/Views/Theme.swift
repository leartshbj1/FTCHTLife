import SwiftUI

enum Theme {
    static let accent = Color(red: 0.98, green: 0.36, blue: 0.20)
    static let fond = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let carte = Color.white
    static let encre = Color(red: 0.12, green: 0.12, blue: 0.16)

    static func couleurStat(_ valeur: Int) -> Color {
        switch valeur {
        case ..<25: return Color(red: 0.88, green: 0.22, blue: 0.22)
        case ..<50: return Color(red: 0.95, green: 0.62, blue: 0.13)
        case ..<75: return Color(red: 0.55, green: 0.75, blue: 0.20)
        default: return Color(red: 0.16, green: 0.68, blue: 0.38)
        }
    }
}

struct BarreStat: View {
    let titre: String
    let icone: String
    let valeur: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icone)
                .frame(width: 18)
                .foregroundStyle(Theme.couleurStat(valeur))
            Text(titre)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(Theme.couleurStat(valeur))
                        .frame(width: geo.size.width * CGFloat(valeur) / 100)
                        .animation(.easeOut(duration: 0.4), value: valeur)
                }
            }
            .frame(height: 10)
            Text("\(valeur)%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }
}

/// Bouton de liste réutilisable pour les actions.
struct LigneAction: View {
    let titre: String
    var sousTitre: String? = nil
    let icone: String
    var actif: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icone)
                    .font(.system(size: 18))
                    .foregroundStyle(actif ? Theme.accent : .gray)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titre).foregroundStyle(actif ? Theme.encre : .gray)
                    if let s = sousTitre {
                        Text(s).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .disabled(!actif)
    }
}

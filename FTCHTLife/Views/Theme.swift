import SwiftUI
import UIKit

/// Couleurs et petits composants partagés par tout le jeu.
/// Les modules utilisent `Theme.accent`, `encre`, `fond`, `carte`, `couleurStat`, `BarreStat` et `LigneAction` :
/// ne pas changer leurs noms ni leurs paramètres.
enum Theme {
    static let accent = Color(red: 0.98, green: 0.36, blue: 0.20)
    static let fond = Color(red: 0.95, green: 0.94, blue: 0.91)
    static let carte = Color.white
    static let encre = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let gris = Color(red: 0.55, green: 0.55, blue: 0.60)
    static let argentPositif = Color(red: 0.13, green: 0.58, blue: 0.32)
    static let argentNegatif = Color(red: 0.86, green: 0.20, blue: 0.20)

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
    /// Changement depuis l'an dernier, affiché en petit à côté du pourcentage (optionnel).
    var delta: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icone)
                .frame(width: 18)
                .foregroundStyle(Theme.couleurStat(valeur))
            Text(titre)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.encre)
                .frame(width: 92, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(Theme.couleurStat(valeur))
                        .frame(width: max(0, geo.size.width * CGFloat(min(100, max(0, valeur))) / 100))
                        .animation(.easeOut(duration: 0.4), value: valeur)
                }
            }
            .frame(height: 10)
            Text("\(valeur)%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.encre)
                .frame(width: 40, alignment: .trailing)
            if let d = delta {
                Text(d == 0 ? "" : (d > 0 ? "+\(d)" : "−\(abs(d))"))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(d > 0 ? Theme.argentPositif : Theme.argentNegatif)
                    .frame(width: 30, alignment: .leading)
                    .transition(.opacity)
            }
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

/// Fenêtre d'alerte « FTCHTLife » qui affiche un texte de résultat.
struct AlerteResultat: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

extension View {
    func alerteResultat(_ message: Binding<String?>) -> some View { modifier(AlerteResultat(message: message)) }
}

/// Habille un écran sans barre de navigation (liste à pousser) pour l'ouvrir en feuille, avec un bouton « Fermer ».
struct Feuille<Contenu: View>: View {
    @Environment(\.dismiss) private var dismiss
    let titre: String
    @ViewBuilder let contenu: () -> Contenu

    var body: some View {
        NavigationStack {
            contenu()
                .navigationTitle(titre)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
                }
        }
    }
}

/// Petite vibration (sur iPhone) pour les gestes importants.
enum Vibration {
    static func legere() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func moyenne() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}

extension View {
    /// Les chiffres qui changent défilent (iOS 17 et plus).
    @ViewBuilder
    func chiffresAnimes() -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }
}

import SwiftUI

// MARK: - Couleurs

enum CasinoStyle {
    static let tapis = Color(red: 0.05, green: 0.36, blue: 0.22)
    static let tapisFonce = Color(red: 0.03, green: 0.24, blue: 0.15)
    static let or = Color(red: 0.93, green: 0.74, blue: 0.27)
    static let nuit = Color(red: 0.09, green: 0.08, blue: 0.13)
    static let rouge = Color(red: 0.80, green: 0.13, blue: 0.16)
    static let creme = Color(red: 0.99, green: 0.97, blue: 0.91)

    static func couleurAddiction(_ v: Int) -> Color {
        switch v {
        case ..<10: return Color(red: 0.16, green: 0.68, blue: 0.38)
        case ..<30: return Color(red: 0.55, green: 0.75, blue: 0.20)
        case ..<50: return Color(red: 0.95, green: 0.62, blue: 0.13)
        case ..<75: return Color(red: 0.92, green: 0.40, blue: 0.15)
        default: return Color(red: 0.85, green: 0.15, blue: 0.20)
        }
    }
}

/// Fond « tapis de jeu » pour les écrans de table.
struct CasinoFondTapis: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RadialGradient(colors: [CasinoStyle.tapis, CasinoStyle.tapisFonce],
                               center: .center, startRadius: 40, endRadius: 520)
                    .ignoresSafeArea()
            )
    }
}

extension View {
    /// Applique le fond vert des tables de jeu.
    func casinoTapis() -> some View { modifier(CasinoFondTapis()) }
}

// MARK: - En-tête solde

/// Petite barre en haut des jeux : argent disponible et niveau d'addiction.
struct CasinoBarreSolde: View {
    @EnvironmentObject var engine: GameEngine
    @ObservedObject private var stockage = CasinoStockage.shared

    var body: some View {
        let argent = engine.joueur?.argent ?? 0
        let addiction = engine.casinoEtat.addiction
        HStack {
            Label(Format.argent(argent), systemImage: "banknote.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(argent < 0 ? CasinoStyle.rouge : CasinoStyle.or)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                Text("Addiction \(addiction)%")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(CasinoStyle.couleurAddiction(addiction).opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(CasinoStyle.nuit.opacity(0.85))
    }
}

// MARK: - Sélecteur de mise

/// Choix de la mise avec des jetons, bornée par les limites du lieu et l'argent du joueur.
struct CasinoSelecteurMise: View {
    @Binding var mise: Int
    let lieu: CasinoLieu
    let argent: Int
    var titre: String = "Mise"

    private var jetons: [Int] {
        [1, 5, 10, 50, 100, 500, 1_000, 5_000, 10_000, 50_000, 100_000, 500_000, 1_000_000]
            .filter { $0 >= max(1, lieu.miseMin / 2) && $0 <= lieu.miseMax }
    }

    private var maximum: Int { max(0, min(lieu.miseMax, argent)) }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(titre).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(Format.argent(mise))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(CasinoStyle.or)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button { mise = min(lieu.miseMin, maximum) } label: { CasinoJeton(texte: "Min", couleur: .gray) }
                    ForEach(jetons, id: \.self) { v in
                        Button { mise = min(mise + v, maximum) } label: {
                            CasinoJeton(texte: CasinoSelecteurMise.court(v), couleur: CasinoJeton.couleur(v))
                        }
                        .disabled(mise + v > maximum)
                        .opacity(mise + v > maximum ? 0.35 : 1)
                    }
                    Button { mise = maximum } label: { CasinoJeton(texte: "Tapis", couleur: CasinoStyle.rouge) }
                    Button { mise = 0 } label: { CasinoJeton(texte: "×", couleur: .black) }
                }
                .padding(.vertical, 2)
            }
            Text("Table : \(Format.argent(lieu.miseMin)) à \(Format.argent(lieu.miseMax))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(12)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
        .onAppear { if mise == 0 || mise > maximum { mise = min(lieu.miseMin, maximum) } }
    }

    /// 1500 → « 1,5k », 2000000 → « 2M ».
    static func court(_ v: Int) -> String {
        if v >= 1_000_000 { return v % 1_000_000 == 0 ? "\(v / 1_000_000)M" : String(format: "%.1fM", Double(v) / 1_000_000) }
        if v >= 1_000 { return v % 1_000 == 0 ? "\(v / 1_000)k" : String(format: "%.1fk", Double(v) / 1_000) }
        return "\(v)"
    }

    /// Mise valide pour ce lieu et ce solde ?
    static func valide(_ mise: Int, lieu: CasinoLieu, argent: Int) -> Bool {
        mise >= lieu.miseMin && mise <= lieu.miseMax && mise <= argent
    }
}

/// Un jeton de casino rond.
struct CasinoJeton: View {
    let texte: String
    let couleur: Color

    var body: some View {
        ZStack {
            Circle().fill(couleur)
            Circle().strokeBorder(.white.opacity(0.85), style: StrokeStyle(lineWidth: 3, dash: [4, 4]))
                .padding(3)
            Text(texte)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .padding(6)
        }
        .frame(width: 46, height: 46)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
    }

    static func couleur(_ v: Int) -> Color {
        switch v {
        case ..<5: return Color(white: 0.55)
        case ..<10: return Color(red: 0.8, green: 0.15, blue: 0.15)
        case ..<50: return Color(red: 0.15, green: 0.35, blue: 0.8)
        case ..<100: return Color(red: 0.1, green: 0.55, blue: 0.3)
        case ..<500: return .black
        case ..<1_000: return Color(red: 0.5, green: 0.2, blue: 0.65)
        case ..<10_000: return Color(red: 0.9, green: 0.55, blue: 0.1)
        case ..<100_000: return Color(red: 0.85, green: 0.3, blue: 0.5)
        default: return Color(red: 0.75, green: 0.6, blue: 0.15)
        }
    }
}

// MARK: - Boutons et bandeaux

/// Gros bouton d'action sur un tapis de jeu.
struct CasinoBouton: View {
    let titre: String
    var couleur: Color = CasinoStyle.or
    var actif: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titre)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(actif ? couleur : Color.gray.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(couleur == CasinoStyle.or ? CasinoStyle.nuit : .white)
        }
        .disabled(!actif)
    }
}

/// Bandeau de résultat (gagné / perdu / neutre).
struct CasinoBandeau: View {
    let texte: String
    /// true = gain, false = perte, nil = neutre.
    var gain: Bool? = nil

    var body: some View {
        Text(texte)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(fond, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
            .transition(.scale.combined(with: .opacity))
    }

    private var fond: Color {
        switch gain {
        case .some(true): return Color(red: 0.12, green: 0.6, blue: 0.3)
        case .some(false): return CasinoStyle.rouge
        case .none: return Color.black.opacity(0.4)
        }
    }
}

// MARK: - Cartes à jouer

enum CasinoCouleurCarte: String, CaseIterable, Codable {
    case pique, coeur, carreau, trefle

    var symbole: String {
        switch self {
        case .pique: return "♠"
        case .coeur: return "♥"
        case .carreau: return "♦"
        case .trefle: return "♣"
        }
    }

    var estRouge: Bool { self == .coeur || self == .carreau }
}

/// Une carte à jouer. `rang` va de 2 à 14 (11 = Valet, 12 = Dame, 13 = Roi, 14 = As).
struct CasinoCarte: Identifiable, Hashable {
    let id = UUID()
    let rang: Int
    let couleur: CasinoCouleurCarte

    var nomRang: String {
        switch rang {
        case 11: return "V"
        case 12: return "D"
        case 13: return "R"
        case 14: return "A"
        default: return "\(rang)"
        }
    }

    var nomComplet: String {
        let r: String
        switch rang {
        case 11: r = "Valet"
        case 12: r = "Dame"
        case 13: r = "Roi"
        case 14: r = "As"
        default: r = "\(rang)"
        }
        return "\(r) de \(couleur.rawValue)"
    }

    /// Un ou plusieurs jeux de 52 cartes mélangés.
    static func paquet(jeux: Int = 1) -> [CasinoCarte] {
        var cartes: [CasinoCarte] = []
        for _ in 0..<max(1, jeux) {
            for c in CasinoCouleurCarte.allCases {
                for r in 2...14 { cartes.append(CasinoCarte(rang: r, couleur: c)) }
            }
        }
        return cartes.shuffled()
    }
}

/// Dessin d'une carte à jouer (face visible ou dos).
struct CasinoCarteVue: View {
    let carte: CasinoCarte?
    var cachee: Bool = false
    var largeur: CGFloat = 58
    var selectionnee: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: largeur * 0.12)
                .fill(cachee || carte == nil ? AnyShapeStyle(dos) : AnyShapeStyle(CasinoStyle.creme))
            RoundedRectangle(cornerRadius: largeur * 0.12)
                .strokeBorder(selectionnee ? CasinoStyle.or : Color.black.opacity(0.2), lineWidth: selectionnee ? 3 : 1)
            if let c = carte, !cachee {
                VStack(spacing: 0) {
                    HStack {
                        VStack(spacing: -2) {
                            Text(c.nomRang).font(.system(size: largeur * 0.26, weight: .bold, design: .rounded))
                            Text(c.couleur.symbole).font(.system(size: largeur * 0.2))
                        }
                        Spacer()
                    }
                    Spacer()
                    Text(c.couleur.symbole).font(.system(size: largeur * 0.5))
                    Spacer()
                }
                .padding(largeur * 0.08)
                .foregroundStyle(c.couleur.estRouge ? CasinoStyle.rouge : Color.black)
            }
        }
        .frame(width: largeur, height: largeur * 1.42)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
        .offset(y: selectionnee ? -10 : 0)
    }

    private var dos: LinearGradient {
        LinearGradient(colors: [Color(red: 0.55, green: 0.1, blue: 0.15), Color(red: 0.35, green: 0.05, blue: 0.1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

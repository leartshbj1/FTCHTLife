import SwiftUI

/// Portrait dessiné par défaut sur la carte, si le moteur n'en fournit pas d'autre
/// (par ex. l'avatar de la création de perso). Toujours le même pour un même nom :
/// peau, cheveux et coupe viennent d'un hachage stable du nom complet.
/// Les détails viennent de la fin de vie : cheveux gris, sourire selon le bonheur,
/// lunettes de soleil si riche, auréole ou cornes selon le karma.
struct CarteViePortrait: View {
    let resume: CarteVieResume
    var taille: CGFloat = 120

    private var graine: UInt64 { CarteViePortrait.hachage(resume.nomComplet) }

    private static let peaux: [Color] = [
        Color(red: 0.99, green: 0.86, blue: 0.74), Color(red: 0.94, green: 0.76, blue: 0.60),
        Color(red: 0.80, green: 0.60, blue: 0.43), Color(red: 0.60, green: 0.42, blue: 0.29),
        Color(red: 0.40, green: 0.27, blue: 0.19),
    ]
    private static let cheveux: [Color] = [
        Color(red: 0.12, green: 0.09, blue: 0.08), Color(red: 0.36, green: 0.22, blue: 0.12),
        Color(red: 0.80, green: 0.60, blue: 0.30), Color(red: 0.70, green: 0.28, blue: 0.12),
        Color(red: 0.55, green: 0.40, blue: 0.25),
    ]

    var body: some View {
        let s = taille
        let peau = Self.peaux[Int(graine % 5)]
        let gris = resume.age >= 65
        let chauve = gris && resume.genre == .homme && (graine / 7) % 3 == 0
        let couleurCheveux = gris ? Color(white: 0.82) : Self.cheveux[Int((graine / 5) % 5)]
        let longs = resume.genre == .femme ? (graine / 11) % 4 != 0 : (graine / 11) % 6 == 0
        let bebe = resume.age < 3

        ZStack {
            Circle().fill(LinearGradient(colors: [Theme.accent.opacity(0.9), Color(red: 1.0, green: 0.78, blue: 0.45)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))

            // Cheveux longs derrière le visage
            if longs && !chauve && !bebe {
                RoundedRectangle(cornerRadius: s * 0.22)
                    .fill(couleurCheveux)
                    .frame(width: s * 0.62, height: s * 0.62)
                    .offset(y: s * 0.06)
            }

            // Épaules
            Capsule()
                .fill(Theme.encre)
                .frame(width: s * 0.74, height: s * 0.36)
                .offset(y: s * 0.48)

            // Visage
            Ellipse()
                .fill(peau)
                .frame(width: s * 0.48, height: s * (bebe ? 0.50 : 0.56))
                .offset(y: s * 0.02)

            // Cheveux du dessus
            if !chauve {
                Capsule()
                    .fill(couleurCheveux)
                    .frame(width: s * (bebe ? 0.14 : 0.52), height: s * (bebe ? 0.06 : 0.20))
                    .offset(y: -s * (bebe ? 0.24 : 0.22))
            }

            // Yeux ou lunettes de soleil
            if resume.argent >= 1_000_000 {
                HStack(spacing: s * 0.03) {
                    RoundedRectangle(cornerRadius: s * 0.03).fill(Color.black).frame(width: s * 0.15, height: s * 0.08)
                    RoundedRectangle(cornerRadius: s * 0.03).fill(Color.black).frame(width: s * 0.15, height: s * 0.08)
                }
                .offset(y: -s * 0.01)
            } else {
                HStack(spacing: s * 0.12) {
                    Circle().fill(Theme.encre).frame(width: s * 0.055, height: s * 0.055)
                    Circle().fill(Theme.encre).frame(width: s * 0.055, height: s * 0.055)
                }
                .offset(y: -s * 0.01)
            }

            // Bouche : sourire, trait ou grimace selon le bonheur
            CarteVieBouche(courbure: resume.bonheur >= 60 ? 1 : (resume.bonheur >= 30 ? 0 : -1))
                .stroke(Theme.encre, style: StrokeStyle(lineWidth: s * 0.025, lineCap: .round))
                .frame(width: s * 0.16, height: s * 0.06)
                .offset(y: s * 0.14)

            // Auréole ou cornes
            if resume.karma >= 80 {
                Ellipse()
                    .stroke(Color(red: 1.0, green: 0.85, blue: 0.2), lineWidth: s * 0.035)
                    .frame(width: s * 0.36, height: s * 0.09)
                    .offset(y: -s * 0.38)
            } else if resume.karma <= 20 {
                HStack(spacing: s * 0.28) {
                    CarteVieCorne().fill(Color(red: 0.8, green: 0.1, blue: 0.1)).frame(width: s * 0.08, height: s * 0.12)
                    CarteVieCorne().fill(Color(red: 0.8, green: 0.1, blue: 0.1)).frame(width: s * 0.08, height: s * 0.12)
                }
                .offset(y: -s * 0.32)
            }
        }
        .frame(width: s, height: s)
        .clipShape(Circle())
    }

    /// Hachage FNV-1a : stable d'un lancement à l'autre (contrairement à `hashValue`).
    static func hachage(_ texte: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in texte.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return h
    }
}

/// Bouche : 1 = sourire, 0 = trait, -1 = grimace.
struct CarteVieBouche: Shape {
    var courbure: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY),
                       control: CGPoint(x: r.midX, y: r.midY + courbure * r.height * 1.4))
        return p
    }
}

struct CarteVieCorne: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

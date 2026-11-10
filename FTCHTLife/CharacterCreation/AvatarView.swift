import SwiftUI

/// Avatar dessiné en formes SwiftUI (pas d'images), à partir de l'apparence.
/// `age` permet au moteur de faire vieillir le visage (cheveux gris, rides).
struct AvatarView: View {
    let appearance: Appearance
    var age: Int = 25
    var size: CGFloat = 120

    private var hairColor: Color {
        age >= 65 && appearance.hairColor.isNatural ? HairColor.grey.color : appearance.hairColor.color
    }

    private var isBaby: Bool { age < 3 }

    var body: some View {
        let s = size
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.86, blue: 0.55), Color(red: 1.0, green: 0.62, blue: 0.48)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))

            // Cheveux arrière (longs, afro, chignon)
            backHair(s)

            // Cou + épaules
            RoundedRectangle(cornerRadius: s * 0.2)
                .fill(appearance.skin.color.opacity(0.9))
                .frame(width: s * 0.22, height: s * 0.2)
                .offset(y: s * 0.30)
            Capsule()
                .fill(Color(red: 0.16, green: 0.20, blue: 0.32))
                .frame(width: s * 0.72, height: s * 0.36)
                .offset(y: s * 0.48)

            // Visage
            Ellipse()
                .fill(appearance.skin.color)
                .frame(width: s * 0.50, height: s * 0.58)
                .offset(y: s * 0.02)

            // Oreilles
            HStack(spacing: s * 0.44) {
                Circle().fill(appearance.skin.color).frame(width: s * 0.1)
                Circle().fill(appearance.skin.color).frame(width: s * 0.1)
            }
            .offset(y: s * 0.04)

            face(s)

            frontHair(s)

            if appearance.hasGlasses {
                HStack(spacing: s * 0.04) {
                    Circle().stroke(Color.black.opacity(0.8), lineWidth: s * 0.018).frame(width: s * 0.15)
                    Circle().stroke(Color.black.opacity(0.8), lineWidth: s * 0.018).frame(width: s * 0.15)
                }
                .offset(y: -s * 0.01)
            }
        }
        .frame(width: s, height: s)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private func face(_ s: CGFloat) -> some View {
        ZStack {
        // Yeux
        HStack(spacing: s * 0.12) {
            eye(s)
            eye(s)
        }
        .offset(y: -s * 0.01)

        // Taches de rousseur
        if appearance.hasFreckles {
            HStack(spacing: s * 0.22) {
                freckles(s)
                freckles(s)
            }
            .offset(y: s * 0.08)
        }

        // Rides
        if age >= 55 {
            Capsule().fill(Color.black.opacity(0.15))
                .frame(width: s * 0.16, height: s * 0.012)
                .offset(y: -s * 0.15)
        }

        // Bouche
        SmileShape()
            .stroke(Color(red: 0.55, green: 0.18, blue: 0.20), style: StrokeStyle(lineWidth: s * 0.025, lineCap: .round))
            .frame(width: isBaby ? s * 0.08 : s * 0.14, height: s * 0.05)
            .offset(y: s * 0.16)
        }
    }

    private func eye(_ s: CGFloat) -> some View {
        ZStack {
            Ellipse().fill(.white).frame(width: s * 0.10, height: s * 0.075)
            Circle().fill(appearance.eyes.color).frame(width: s * 0.055)
            Circle().fill(.black).frame(width: s * 0.025)
        }
    }

    private func freckles(_ s: CGFloat) -> some View {
        HStack(spacing: s * 0.015) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(Color(red: 0.6, green: 0.35, blue: 0.2).opacity(0.6)).frame(width: s * 0.015)
            }
        }
    }

    @ViewBuilder
    private func backHair(_ s: CGFloat) -> some View {
        if !isBaby {
            switch appearance.hairStyle {
            case .long:
                RoundedRectangle(cornerRadius: s * 0.2)
                    .fill(hairColor)
                    .frame(width: s * 0.62, height: s * 0.72)
                    .offset(y: s * 0.08)
            case .afro:
                Circle().fill(hairColor).frame(width: s * 0.8).offset(y: -s * 0.08)
            case .curly:
                Circle().fill(hairColor).frame(width: s * 0.64).offset(y: -s * 0.08)
            case .bun:
                Circle().fill(hairColor).frame(width: s * 0.22).offset(y: -s * 0.36)
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func frontHair(_ s: CGFloat) -> some View {
        if isBaby {
            // Petite mèche de bébé
            Circle().trim(from: 0.55, to: 0.8)
                .stroke(hairColor, style: StrokeStyle(lineWidth: s * 0.02, lineCap: .round))
                .frame(width: s * 0.12)
                .offset(y: -s * 0.26)
        } else {
            switch appearance.hairStyle {
            case .bald:
                EmptyView()
            case .buzz:
                TopCapShape()
                    .fill(hairColor.opacity(0.55))
                    .frame(width: s * 0.52, height: s * 0.20)
                    .offset(y: -s * 0.19)
            case .mohawk:
                Capsule()
                    .fill(hairColor)
                    .frame(width: s * 0.09, height: s * 0.32)
                    .offset(y: -s * 0.30)
            case .short, .bun, .long, .curly, .afro:
                TopCapShape()
                    .fill(hairColor)
                    .frame(width: s * 0.56, height: s * 0.24)
                    .offset(y: -s * 0.19)
            }
        }
    }
}

/// Calotte de cheveux : demi-ellipse sur le haut du crâne avec une frange en vague.
private struct TopCapShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.9))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.25), control: CGPoint(x: r.minX + r.width * 0.8, y: r.maxY - r.height * 0.5))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY), control: CGPoint(x: r.minX + r.width * 0.2, y: r.maxY - r.height * 0.1))
        p.closeSubpath()
        return p
    }
}

private struct SmileShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY * 1.6))
        return p
    }
}

#if DEBUG
struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            AvatarView(appearance: Appearance(skin: .tan, hairStyle: .long, hairColor: .red, eyes: .green, hasFreckles: true, hasGlasses: false))
            AvatarView(appearance: Appearance(skin: .deep, hairStyle: .afro, hairColor: .black, eyes: .brown, hasFreckles: false, hasGlasses: true), age: 70)
        }
    }
}
#endif

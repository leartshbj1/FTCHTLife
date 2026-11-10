import SwiftUI

/// La carte elle-même, au format story (9:16). Dessinée à 360 × 640 points,
/// exportée à l'échelle 3, soit une image de 1080 × 1920 pixels.
struct CarteVieVue: View {
    let resume: CarteVieResume
    /// Portrait à afficher à la place du portrait dessiné par défaut (ex. l'avatar de la création de perso).
    var portrait: AnyView? = nil

    static let largeur: CGFloat = 360
    static let hauteur: CGFloat = 640

    private let vert = Color(red: 0.16, green: 0.68, blue: 0.38)
    private let rouge = Color(red: 0.92, green: 0.30, blue: 0.28)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.encre, Color(red: 0.20, green: 0.16, blue: 0.24)],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: 12) {
                // En-tête
                HStack {
                    Text("FTCHTLife")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text("CARTE DE VIE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Portrait et identité
                Group {
                    if let portrait {
                        portrait.frame(width: 104, height: 104).clipShape(Circle())
                    } else {
                        CarteViePortrait(resume: resume, taille: 104)
                    }
                }
                .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 3))
                .padding(.top, 2)

                VStack(spacing: 3) {
                    Text(resume.nomComplet)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("« \(resume.surnom) »")
                        .font(.system(size: 15, weight: .semibold, design: .serif).italic())
                        .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(resume.ville) · 0 – \(resume.age) ans")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(resume.phraseDeces)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 2)
                }

                // Chiffres clés
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(resume.chiffres) { c in
                        VStack(spacing: 3) {
                            Image(systemName: c.icone)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.accent)
                            Text(c.valeur)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                            Text(c.titre.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Moments
                moment(titre: "MEILLEUR MOMENT", icone: "star.fill", couleur: vert, m: resume.meilleur,
                       vide: "Aucun. Vraiment aucun.")
                moment(titre: "PIRE MOMENT", icone: "bolt.fill", couleur: rouge, m: resume.pire,
                       vide: "Rien de grave. Suspect.")

                Spacer(minLength: 0)

                // Note
                HStack(alignment: .center, spacing: 12) {
                    VStack(spacing: 0) {
                        Text("\(resume.note)")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.accent)
                        Text("/20")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 58)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NOTE DE VIE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(resume.verdict)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

                Text("Et toi, tu ferais mieux ? Joue à FTCHTLife.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
        }
        .frame(width: Self.largeur, height: Self.hauteur)
    }

    private func moment(titre: String, icone: String, couleur: Color, m: CarteVieMoment?, vide: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icone)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(couleur)
                .frame(width: 18)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(m.map { "\(titre) · \($0.age) AN\($0.age > 1 ? "S" : "")" } ?? titre)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(couleur)
                Text(m?.texte ?? vide)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(couleur.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(couleur.opacity(0.35), lineWidth: 1))
    }
}

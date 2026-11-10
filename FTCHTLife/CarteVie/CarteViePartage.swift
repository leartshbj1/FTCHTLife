import SwiftUI
import UIKit

// Partage de la carte de vie : rendu en image et feuille de partage iOS.

enum CarteViePartage {
    /// Dessine la carte en image de 1080 × 1920 pixels.
    @MainActor
    static func image(_ resume: CarteVieResume, portrait: AnyView? = nil) -> UIImage? {
        let renderer = ImageRenderer(content:
            CarteVieVue(resume: resume, portrait: portrait)
                .environment(\.colorScheme, .dark)
        )
        renderer.proposedSize = ProposedViewSize(width: CarteVieVue.largeur, height: CarteVieVue.hauteur)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Petit texte qui accompagne l'image (messages, réseaux…).
    static func legende(_ r: CarteVieResume) -> String {
        let mort = r.genre == .femme ? "morte" : "mort"
        return "\(r.nomComplet), « \(r.surnom) », \(mort) à \(r.age) ans. Note de vie : \(r.note)/20. Et toi, tu ferais mieux ? #FTCHTLife"
    }
}

/// Bouton à poser sur l'écran de mort (sous la nécrologie). Ouvre l'aperçu de la carte avec le bouton de partage.
///
///     CarteVieBouton(joueur: j, surnom: MuseeStore.shared.enregistrer(joueur: j).surnom)
struct CarteVieBouton: View {
    let joueur: Joueur
    var surnom: String? = nil
    var dernierMetier: String? = nil
    var portrait: AnyView? = nil

    @State private var ouvert = false

    var body: some View {
        Button {
            ouvert = true
        } label: {
            Label("Partager ma carte de vie", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .sheet(isPresented: $ouvert) {
            CarteVieEcran(resume: CarteVieResume(joueur: joueur, surnom: surnom, dernierMetier: dernierMetier),
                          portrait: portrait)
        }
    }
}

/// Aperçu de la carte, avec le bouton qui ouvre la feuille de partage iOS
/// (Messages, WhatsApp, Instagram, Enregistrer l'image…).
struct CarteVieEcran: View {
    let resume: CarteVieResume
    var portrait: AnyView? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var partageOuvert = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal)

                GeometryReader { geo in
                    let echelle = min(geo.size.width / CarteVieVue.largeur, geo.size.height / CarteVieVue.hauteur)
                    CarteVieVue(resume: resume, portrait: portrait)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .scaleEffect(echelle)
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                Button {
                    if image == nil { image = CarteViePartage.image(resume, portrait: portrait) }
                    partageOuvert = image != nil
                } label: {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $partageOuvert) {
            if let image {
                CarteVieFeuillePartage(elements: [image, CarteViePartage.legende(resume)])
                    .ignoresSafeArea()
            }
        }
    }
}

/// Feuille de partage iOS (UIActivityViewController).
struct CarteVieFeuillePartage: UIViewControllerRepresentable {
    let elements: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: elements, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#if DEBUG
struct CarteVieVue_Previews: PreviewProvider {
    static var joueur: Joueur {
        var j = Joueur(prenom: "Ginette", nom: "Pastaga", genre: .femme, age: 87, ville: "Marseille",
                       stats: Stats(sante: 0, bonheur: 72, intelligence: 64, apparence: 40, karma: 83),
                       argent: 1_250_000, diplome: .licence, filiereDiplome: .commerce, etudes: nil, emploi: nil,
                       relations: [], journal: [])
        j.vivant = false
        j.causeDeces = "de vieillesse, en râlant contre la météo"
        j.journal = [
            Annee(age: 18, lignes: ["🎓 Tu as eu ton bac ! Tes parents ont pleuré. De soulagement, surtout."]),
            Annee(age: 31, lignes: ["📉 Tu as été virée de ton poste de comptable. Ton patron a dit « bon courage » sans le penser."]),
            Annee(age: 44, lignes: ["📈 Promotion ! Tu es maintenant Directrice commerciale à 95'000 €/an."]),
        ]
        return j
    }

    static var previews: some View {
        CarteVieVue(resume: CarteVieResume(joueur: joueur, surnom: "la Reine du loto clandestin"))
            .previewLayout(.sizeThatFits)
    }
}
#endif

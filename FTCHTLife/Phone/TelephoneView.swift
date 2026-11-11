import SwiftUI

// Écran d'accueil du téléphone. Le fil moteur l'ouvre avec :
//     TelephoneView(chemin: \.telephone)
// où `telephone: PhoneEtat?` est le champ ajouté à Joueur (voir docs/PHONE.md).

typealias PhoneChemin = WritableKeyPath<Joueur, PhoneEtat?>

extension GameEngine {
    /// Modifie le joueur et son téléphone ensemble, puis sauvegarde. Renvoie ce que renvoie `action`.
    @discardableResult
    func telephoneModifier<R>(_ chemin: PhoneChemin, _ action: (inout Joueur, inout PhoneEtat) -> R) -> R? {
        var resultat: R?
        modifier { j in
            var t = j[keyPath: chemin] ?? PhoneEtat()
            resultat = action(&j, &t)
            j[keyPath: chemin] = t
        }
        return resultat
    }
}

extension PhoneApp {
    var couleur: Color {
        switch self {
        case .pozz: return Color(red: 0.93, green: 0.30, blue: 0.45)
        case .tremousse: return Color(red: 0.08, green: 0.68, blue: 0.70)
        case .ronchon: return Color(red: 0.93, green: 0.60, blue: 0.08)
        case .pecho: return Color(red: 0.86, green: 0.18, blue: 0.24)
        case .voustube: return Color(red: 0.90, green: 0.12, blue: 0.10)
        case .onlyfesses: return Color(red: 0.05, green: 0.62, blue: 0.95)
        }
    }
}

enum PhoneEcran: Hashable {
    case reseau(PhoneApp)
    case messages
    case message(UUID)
    case pecho
}

enum PhoneCouleurs {
    static let messages = Color(red: 0.20, green: 0.68, blue: 0.35)
    static let ecran = Color(red: 0.11, green: 0.12, blue: 0.17)
}

/// Petit raccourci pour afficher un texte de résultat dans une alerte.
struct PhoneAlerte: ViewModifier {
    @Binding var texte: String?

    func body(content: Content) -> some View {
        content.alert("FTCHTLife", isPresented: Binding(get: { texte != nil }, set: { if !$0 { texte = nil } })) {
            Button("OK") { texte = nil }
        } message: {
            Text(texte ?? "")
        }
    }
}

extension View {
    func phoneAlerte(_ texte: Binding<String?>) -> some View { modifier(PhoneAlerte(texte: texte)) }
}

@MainActor
struct TelephoneView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let chemin: PhoneChemin
    @State private var alerte: String?

    init(chemin: PhoneChemin) {
        self.chemin = chemin
    }

    var body: some View {
        NavigationStack {
            Group {
                if let j = engine.joueur {
                    let t = j[keyPath: chemin] ?? PhoneEtat()
                    if t.aTelephone {
                        accueil(j, t)
                    } else {
                        sansTelephone(j)
                    }
                } else {
                    Text("Aucune vie en cours.")
                }
            }
            .navigationTitle("Téléphone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .navigationDestination(for: PhoneEcran.self) { ecran in
                switch ecran {
                case .reseau(let app): PhoneReseauView(app: app, chemin: chemin)
                case .messages: PhoneMessagesView(chemin: chemin)
                case .message(let id): PhoneConversationView(id: id, chemin: chemin)
                case .pecho: PhonePechoView(chemin: chemin)
                }
            }
            .phoneAlerte($alerte)
        }
    }

    // MARK: Sans téléphone

    private func sansTelephone(_ j: Joueur) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            if j.age < 13 {
                Text("Pas de téléphone avant 13 ans.")
                    .font(.headline)
                Text("Tes parents sont formels. Tu peux toujours jouer avec la télécommande.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Tu n'as pas encore de téléphone.")
                    .font(.headline)
                Button {
                    alerte = engine.telephoneModifier(chemin) { (j: inout Joueur, t: inout PhoneEtat) -> String in
                        let achat = j.age >= 18
                        return PhoneEngine.obtenirTelephone(&j, &t, engine: engine, achat: achat)
                    }
                } label: {
                    Text(j.age >= 18 ? "Acheter un téléphone d'occasion (250 €)" : "Supplier tes parents")
                        .bold()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.fond.ignoresSafeArea())
    }

    // MARK: Accueil

    private func accueil(_ j: Joueur, _ t: PhoneEtat) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                barreEtat(j)
                resume(t)
                grilleApplis(j, t)
                actions(j, t)
                if !t.contrats.isEmpty { contrats(t) }
            }
            .padding()
        }
        .background(PhoneCouleurs.ecran.ignoresSafeArea())
    }

    private func barreEtat(_ j: Joueur) -> some View {
        HStack {
            Text("\(j.age) ans")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
            Image(systemName: "wifi")
            Image(systemName: j.stats.bonheur > 50 ? "battery.75" : "battery.25")
        }
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.8))
    }

    private func resume(_ t: PhoneEtat) -> some View {
        VStack(spacing: 4) {
            Text(PhoneFormat.court(t.abonnesTotal))
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(t.abonnesTotal > 1 ? "abonnés au total" : "abonné au total")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            if t.badBuzzRestant > 0 {
                Label("Bad buzz en cours", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }
            if t.detoxCetteAnnee {
                Label("Détox numérique cette année", systemImage: "leaf.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }

    private func grilleApplis(_ j: Joueur, _ t: PhoneEtat) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 18) {
            // OnlyFesses n'apparaît même pas avant 18 ans.
            ForEach(PhoneApp.reseaux.filter { $0 != .onlyfesses || j.age >= 18 }) { app in
                NavigationLink(value: PhoneEcran.reseau(app)) {
                    tuile(app.nom, app.icone, app.couleur, badge: 0, verrou: j.age < app.ageMin,
                          sousTitre: app == .onlyfesses && t.onlyFerme ? "fermé" : PhoneFormat.court(t.compte(app).abonnes))
                }
            }
            NavigationLink(value: PhoneEcran.pecho) {
                tuile(PhoneApp.pecho.nom, PhoneApp.pecho.icone, PhoneApp.pecho.couleur,
                      badge: 0, verrou: j.age < PhoneApp.pecho.ageMin,
                      sousTitre: t.matchs.isEmpty ? "18+" : "\(t.matchs.count) match\(t.matchs.count > 1 ? "s" : "")")
            }
            NavigationLink(value: PhoneEcran.messages) {
                tuile("Messages", "message.fill", PhoneCouleurs.messages, badge: t.nonLus, verrou: false,
                      sousTitre: "\(t.messages.count)")
            }
        }
    }

    private func tuile(_ nom: String, _ icone: String, _ couleur: Color, badge: Int, verrou: Bool, sousTitre: String) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(couleur.opacity(verrou ? 0.35 : 1))
                    .frame(width: 66, height: 66)
                    .overlay(
                        Image(systemName: verrou ? "lock.fill" : icone)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 6, y: -6)
                }
            }
            Text(nom)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text(sousTitre)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func actions(_ j: Joueur, _ t: PhoneEtat) -> some View {
        VStack(spacing: 10) {
            Button {
                alerte = engine.telephoneModifier(chemin) { j, t in
                    PhoneEngine.detox(&j, &t, engine: engine)
                }
            } label: {
                Label(t.detoxCetteAnnee ? "Détox en cours" : "Détox numérique (cette année)", systemImage: "leaf.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                    .foregroundStyle(.white)
            }
            .disabled(t.detoxCetteAnnee)
            Text("Pas de posts ni de messages pendant un an. Bon pour le moral, mauvais pour les abonnés.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private func contrats(_ t: PhoneEtat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Partenariats en cours")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(t.contrats) { c in
                HStack {
                    Image(systemName: "dollarsign.circle.fill").foregroundStyle(.yellow)
                    Text(c.marque).foregroundStyle(.white)
                    Spacer()
                    if let sp = PhoneBibliotheque.sponsor(c.sponsorId) {
                        Text(Format.argent(PhoneEngine.paiementSponsor(sp, t, bonus: c.bonus)) + "/an")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
    }
}

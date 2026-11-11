import SwiftUI

/// Fiche d'un événement : bandeau de catégorie, texte, choix (les choix cachés n'apparaissent
/// qu'avec la compétence demandée), puis le résultat avec ce que ça a changé.
struct EventView: View {
    @EnvironmentObject var engine: GameEngine
    let affiche: EvenementAffiche
    /// Mode « choix en un tap » : reçoit le résultat à afficher en bandeau, puis l'événement se ferme tout seul.
    /// Sans ce rappel (ou réglage coupé), le résultat s'affiche dans la carte avec « Continuer ».
    var resultatEnUnTap: ((ResultatBandeau) -> Void)? = nil

    @AppStorage(ModeRapide.cleActif) private var rapide = true
    @AppStorage(ModeRapide.cleUnTap) private var unTap = true

    /// Stats et argent juste avant le choix, pour afficher les gains et pertes.
    @State private var avant: Instantane?

    /// La version à jour de CET événement (le résultat s'ajoute après le choix).
    /// Pendant que la carte s'en va, le moteur montre déjà le suivant : on garde alors l'ancienne version.
    private var courant: EvenementAffiche {
        if let e = engine.evenementEnCours, e.id == affiche.id { return e }
        return affiche
    }

    var body: some View {
        let aff = courant
        let style = StyleEvenement.pour(aff.evenement)
        return VStack(spacing: 0) {
            bandeau(style)
            // Sans défilement si tout tient, sinon le texte défile et les boutons restent visibles.
            ViewThatFits(in: .vertical) {
                corps(aff, style)
                ScrollView { corps(aff, style) }
            }
            if aff.resultat != nil {
                BoutonEvenement(titre: "Continuer", couleur: style.couleur, badge: nil, principal: true) {
                    // Un double tap ne doit pas sauter l'événement suivant.
                    guard engine.evenementEnCours?.id == aff.id else { return }
                    avant = nil
                    engine.fermerEvenement()
                }
                .padding(.horizontal)
                .padding(.bottom, 18)
            } else {
                choix(aff, style)
                    .padding(.horizontal)
                    .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.carte)
    }

    private func corps(_ aff: EvenementAffiche, _ style: StyleEvenement) -> some View {
        VStack(spacing: 18) {
            Text(aff.texte)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.encre)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
                .padding(.top, 22)

            if let resultat = aff.resultat {
                resultatVue(resultat, style)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }

    // MARK: Bandeau

    private func bandeau(_ style: StyleEvenement) -> some View {
        HStack(spacing: 10) {
            Image(systemName: style.icone)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(style.couleur)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white))
            Text(style.titre.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white)
            Spacer()
            if let j = engine.joueur {
                Text("\(j.age) an\(j.age > 1 ? "s" : "")")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.22)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(style.couleur)
    }

    // MARK: Choix

    private func choix(_ aff: EvenementAffiche, _ style: StyleEvenement) -> some View {
        let tous = aff.evenement.choices ?? []
        let visibles: [ChoixVisible]
        if let j = engine.joueur {
            visibles = Competences.choixVisibles(tous, j).map { ChoixVisible(index: $0.index, choix: $0.choix) }
        } else {
            visibles = tous.enumerated().map { ChoixVisible(index: $0.offset, choix: $0.element) }
        }
        return VStack(spacing: 10) {
            ForEach(visibles) { item in
                BoutonEvenement(titre: item.choix.label, couleur: style.couleur,
                                badge: Competences.badge(item.choix), principal: false) {
                    choisir(item, aff, style)
                }
            }
        }
    }

    private func choisir(_ item: ChoixVisible, _ aff: EvenementAffiche, _ style: StyleEvenement) {
        // Un double tap ne doit pas répondre à l'événement suivant.
        guard engine.evenementEnCours?.id == aff.id, engine.evenementEnCours?.resultat == nil else { return }
        let instantane = engine.joueur.map { Instantane(stats: $0.stats, argent: $0.argent) }
        avant = instantane
        if unTap, let rapporter = resultatEnUnTap {
            engine.choisir(item.index)
            // Pas de résultat (ex. une étape suivante s'ouvre) : la carte reste, on ne ferme rien.
            guard let apres = engine.evenementEnCours, apres.id == aff.id, let texte = apres.resultat else { return }
            let deltas = instantane.flatMap { a in engine.joueur.map { ChangementStat.entre(a, $0) } } ?? []
            rapporter(ResultatBandeau(titre: item.choix.label, texte: texte, couleur: style.couleur, changements: deltas))
            avant = nil
            engine.fermerEvenement()
        } else {
            withAnimation(ModeRapide.animation(.spring(response: 0.3, dampingFraction: 0.85), rapide: rapide)) {
                engine.choisir(item.index)
            }
        }
    }

    // MARK: Résultat

    private func resultatVue(_ texte: String, _ style: StyleEvenement) -> some View {
        VStack(spacing: 12) {
            Text(texte)
                .font(.body)
                .foregroundStyle(Theme.encre)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            let deltas = changements()
            if !deltas.isEmpty {
                PastillesChangements(elements: deltas)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(style.couleur.opacity(0.09)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(style.couleur.opacity(0.25), lineWidth: 1))
        .padding(.horizontal)
    }

    private func changements() -> [ChangementStat] {
        guard let a = avant, let j = engine.joueur else { return [] }
        return ChangementStat.entre(a, j)
    }
}

struct ChoixVisible: Identifiable {
    let index: Int
    let choix: Choix
    var id: Int { index }
}

struct Instantane: Equatable {
    let stats: Stats
    let argent: Int
}

/// Un gain ou une perte affiché en pastille (« +5 Bonheur », « −200 € »).
struct ChangementStat: Identifiable, Equatable {
    var id: String { nom }
    let nom: String
    let icone: String
    let delta: Int
    var argent: Bool = false

    var texte: String {
        let signe = delta > 0 ? "+" : "−"
        if argent { return signe + Format.argent(abs(delta)) }
        return "\(signe)\(abs(delta)) \(nom)"
    }

    var couleur: Color { delta > 0 ? Theme.argentPositif : Theme.argentNegatif }

    /// Ce qui a changé entre un instantané et le joueur actuel.
    static func entre(_ a: Instantane, _ j: Joueur) -> [ChangementStat] {
        var r: [ChangementStat] = []
        func ajoute(_ nom: String, _ icone: String, _ d: Int, argent: Bool = false) {
            if d != 0 { r.append(ChangementStat(nom: nom, icone: icone, delta: d, argent: argent)) }
        }
        ajoute("Bonheur", "face.smiling.fill", j.stats.bonheur - a.stats.bonheur)
        ajoute("Santé", "heart.fill", j.stats.sante - a.stats.sante)
        ajoute("Intelligence", "brain.head.profile", j.stats.intelligence - a.stats.intelligence)
        ajoute("Apparence", "sparkles", j.stats.apparence - a.stats.apparence)
        ajoute("Karma", "yinyang", j.stats.karma - a.stats.karma)
        ajoute("Argent", "eurosign.circle.fill", j.argent - a.argent, argent: true)
        return r
    }
}

/// Pastilles de changements, sur plusieurs lignes si besoin.
struct PastillesChangements: View {
    let elements: [ChangementStat]

    var body: some View {
        let lignes = stride(from: 0, to: elements.count, by: 3).map { Array(elements[$0..<min($0 + 3, elements.count)]) }
        VStack(spacing: 6) {
            ForEach(Array(lignes.enumerated()), id: \.offset) { _, ligne in
                HStack(spacing: 6) {
                    ForEach(ligne) { c in
                        Label(c.texte, systemImage: c.icone)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(c.couleur)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(c.couleur.opacity(0.12)))
                    }
                }
            }
        }
    }
}

/// Bouton de choix d'un événement.
struct BoutonEvenement: View {
    let titre: String
    let couleur: Color
    let badge: String?
    let principal: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if let b = badge {
                    Label(b, systemImage: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(principal ? Color.white.opacity(0.9) : couleur)
                }
                Text(titre)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(principal ? Color.white : Theme.encre)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(principal ? couleur : Theme.fond))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(couleur.opacity(principal ? 0 : 0.35), lineWidth: 1.5))
        }
        .buttonStyle(StyleAppui())
    }
}

/// Petit enfoncement au toucher, pour tous les gros boutons du jeu.
struct StyleAppui: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Style par catégorie

/// Titre, icône et couleur d'un événement selon sa catégorie (ou le préfixe de son id).
struct StyleEvenement {
    let titre: String
    let icone: String
    let couleur: Color

    private static let bleu = Color(red: 0.20, green: 0.45, blue: 0.88)
    private static let vert = Color(red: 0.12, green: 0.60, blue: 0.40)
    private static let rose = Color(red: 0.90, green: 0.28, blue: 0.45)
    private static let orange = Color(red: 0.96, green: 0.52, blue: 0.12)
    private static let violet = Color(red: 0.50, green: 0.36, blue: 0.84)
    private static let rouge = Color(red: 0.80, green: 0.18, blue: 0.20)
    private static let sombre = Color(red: 0.22, green: 0.22, blue: 0.30)
    private static let turquoise = Color(red: 0.05, green: 0.60, blue: 0.65)
    private static let or = Color(red: 0.85, green: 0.62, blue: 0.10)

    static func pour(_ e: Evenement) -> StyleEvenement {
        let cle = e.category ?? String(e.id.split(separator: "_").first ?? "")
        switch cle {
        case "bebe": return StyleEvenement(titre: "Bébé", icone: "stroller.fill", couleur: rose)
        case "enfance": return StyleEvenement(titre: "Enfance", icone: "teddybear.fill", couleur: orange)
        case "ado": return StyleEvenement(titre: "Ado", icone: "headphones", couleur: violet)
        case "adulte", "quotidien", "base", "ev": return StyleEvenement(titre: "La vie", icone: "sparkles", couleur: Theme.accent)
        case "vieillesse", "retraite": return StyleEvenement(titre: "Vieux jours", icone: "figure.walk", couleur: turquoise)
        case "ecole", "scl", "scv", "etudiant": return StyleEvenement(titre: "École", icone: "book.fill", couleur: bleu)
        case "travail": return StyleEvenement(titre: "Travail", icone: "briefcase.fill", couleur: bleu)
        case "relation", "amour", "saint_valentin": return StyleEvenement(titre: "Amour", icone: "heart.fill", couleur: rose)
        case "famille", "anniv_proche", "fete_meres", "fete_peres": return StyleEvenement(titre: "Famille", icone: "house.fill", couleur: rose)
        case "amitie": return StyleEvenement(titre: "Amitié", icone: "person.2.fill", couleur: orange)
        case "sante": return StyleEvenement(titre: "Santé", icone: "cross.case.fill", couleur: rouge)
        case "argent", "pla", "pin", "pbs": return StyleEvenement(titre: "Argent", icone: "eurosign.circle.fill", couleur: vert)
        case "crime", "casier", "casj": return StyleEvenement(titre: "Crime", icone: "theatermasks.fill", couleur: sombre)
        case "prison": return StyleEvenement(titre: "Prison", icone: "lock.shield.fill", couleur: sombre)
        case "loisirs", "passions", "nature", "cuisine": return StyleEvenement(titre: "Loisirs", icone: "figure.hiking", couleur: vert)
        case "competences": return StyleEvenement(titre: "Talents", icone: "star.circle.fill", couleur: or)
        case "reves": return StyleEvenement(titre: "Rêves", icone: "moon.stars.fill", couleur: violet)
        case "animaux", "ani": return StyleEvenement(titre: "Animaux", icone: "pawprint.fill", couleur: orange)
        case "casino": return StyleEvenement(titre: "Casino", icone: "suit.spade.fill", couleur: sombre)
        case "tele": return StyleEvenement(titre: "Télé", icone: "tv.fill", couleur: violet)
        case "etranger", "albanie": return StyleEvenement(titre: "Ailleurs", icone: "globe.europe.africa.fill", couleur: turquoise)
        case "societe": return StyleEvenement(titre: "Société", icone: "newspaper.fill", couleur: sombre)
        case "absurde": return StyleEvenement(titre: "N'importe quoi", icone: "tornado", couleur: violet)
        case "paranormal": return StyleEvenement(titre: "Paranormal", icone: "eye.fill", couleur: sombre)
        case "testament": return StyleEvenement(titre: "Héritage", icone: "scroll.fill", couleur: or)
        case "permis": return StyleEvenement(titre: "Permis", icone: "car.fill", couleur: bleu)
        case "vsn": return StyleEvenement(titre: "Voisins", icone: "house.and.flag.fill", couleur: vert)
        case "msg": return StyleEvenement(titre: "Téléphone", icone: "iphone", couleur: bleu)
        case "rep": return StyleEvenement(titre: "Ça revient", icone: "arrow.uturn.backward.circle.fill", couleur: violet)
        case "anniversaire": return StyleEvenement(titre: "Anniversaire", icone: "birthday.cake.fill", couleur: rose)
        case "noel": return StyleEvenement(titre: "Noël", icone: "gift.fill", couleur: rouge)
        case "nouvel_an": return StyleEvenement(titre: "Nouvel An", icone: "party.popper.fill", couleur: or)
        case "halloween": return StyleEvenement(titre: "Halloween", icone: "moon.fill", couleur: orange)
        case "paques", "poisson_avril", "galette", "chandeleur", "carnaval", "premier_mai", "fete_musique", "quatorze_juillet":
            return StyleEvenement(titre: "C'est la fête", icone: "party.popper.fill", couleur: or)
        default: return StyleEvenement(titre: "La vie", icone: "sparkles", couleur: Theme.accent)
        }
    }
}

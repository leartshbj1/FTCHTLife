import SwiftUI

// MARK: - Données

/// Une case de la roue de la fortune.
struct RoueFortuneSegment: Identifiable {
    let id: Int
    let multiplicateur: Double
    /// Poids de tirage (sur 1000). La roue est « légèrement » truquée.
    let poids: Int
    /// Emoji affiché sur la roue (cases spéciales à ×0).
    let emoji: String
    /// Nom de la case, affiché dans le résultat.
    let titre: String
    /// Phrases propres à la case (cases ×0) ; vide = phrases selon le multiplicateur.
    let phrases: [String]

    var etiquette: String {
        multiplicateur == 0.5 ? "×0,5" : "×\(Int(multiplicateur))"
    }

    var couleur: Color {
        if emoji == "👵" { return Color(red: 0.62, green: 0.30, blue: 0.55) }
        switch multiplicateur {
        case 50...: return CasinoStyle.or
        case 20...: return CasinoStyle.rouge
        case 10...: return Color(red: 0.92, green: 0.50, blue: 0.10)
        case 5...: return Color(red: 0.50, green: 0.25, blue: 0.70)
        case 3...: return Color(red: 0.10, green: 0.55, blue: 0.60)
        case 2...: return Color(red: 0.15, green: 0.60, blue: 0.30)
        case 1...: return Color(red: 0.20, green: 0.40, blue: 0.80)
        case 0.5...: return Color(red: 0.42, green: 0.47, blue: 0.56)
        default: return Color(white: 0.13)
        }
    }

    var texteFonce: Bool { multiplicateur >= 50 }
}

enum RoueFortuneDonnees {
    /// 24 cases, dans le sens des aiguilles d'une montre en partant du haut.
    /// Retour moyen : somme(poids × multiplicateur) / 1000 = 900 / 1000 = 90 %.
    static let segments: [RoueFortuneSegment] = {
        let brut: [(Double, Int, String, String, [String])] = [
            (50, 1, "👑", "LE GROS LOT", []),
            (0, 101, "👵", "Mamie Gertrude t'a volé ta mise", RoueFortuneTextes.mamie),
            (2, 30, "", "Double", []),
            (1, 42, "", "Remboursé", []),
            (0.5, 40, "", "Demi-mise", []),
            (5, 10, "", "Quintuple", []),
            (1, 42, "", "Remboursé", []),
            (0, 101, "🧾", "Le fisc est passé", RoueFortuneTextes.fisc),
            (3, 20, "", "Triple", []),
            (1, 42, "", "Remboursé", []),
            (10, 5, "", "Dix fois la mise", []),
            (0.5, 40, "", "Demi-mise", []),
            (20, 4, "", "Vingt fois la mise", []),
            (0, 101, "💥", "Banqueroute", RoueFortuneTextes.banqueroute),
            (2, 30, "", "Double", []),
            (1, 42, "", "Remboursé", []),
            (5, 10, "", "Quintuple", []),
            (0.5, 40, "", "Demi-mise", []),
            (0, 101, "🐈", "Le chat du casino", RoueFortuneTextes.chat),
            (3, 20, "", "Triple", []),
            (10, 5, "", "Dix fois la mise", []),
            (1, 42, "", "Remboursé", []),
            (2, 30, "", "Double", []),
            (0, 101, "🎩", "Perdu avec panache", RoueFortuneTextes.panache),
        ]
        var resultat: [RoueFortuneSegment] = []
        for (i, s) in brut.enumerated() {
            resultat.append(RoueFortuneSegment(id: i, multiplicateur: s.0, poids: s.1, emoji: s.2, titre: s.3, phrases: s.4))
        }
        return resultat
    }()

    static var poidsTotal: Int { segments.reduce(0) { $0 + $1.poids } }

    /// Retour moyen théorique (≈ 0,9).
    static var retourMoyen: Double {
        let somme = segments.reduce(0.0) { $0 + Double($1.poids) * $1.multiplicateur }
        return somme / Double(max(poidsTotal, 1))
    }

    /// Tire l'index d'une case selon les poids.
    static func tirer() -> Int {
        var r = Int.random(in: 0..<max(poidsTotal, 1))
        for s in segments {
            if r < s.poids { return s.id }
            r -= s.poids
        }
        return 0
    }
}

// MARK: - Textes

enum RoueFortuneTextes {
    static let accueil = [
        "Le présentateur a un sourire de 64 dents. C'est beaucoup trop de dents.",
        "La roue est certifiée honnête par le cousin du directeur.",
        "« Tournez manège ! » crie un monsieur qui n'a rien à voir avec la roue.",
        "Mamie Gertrude est assise au bar. Elle fait semblant de dormir.",
        "La roue grince un peu. Le présentateur dit que c'est « du caractère ».",
        "Une ampoule sur deux clignote. L'autre a abandonné.",
        "Le présentateur te demande ton prénom, puis l'oublie aussitôt.",
    ]

    static let lancement = [
        "La roue s'élance dans un bruit de crécelle géante.",
        "Tic-tic-tic-tic… Ton cœur se cale sur le rythme du pointeur.",
        "Elle tourne ! Le public retient son souffle. Toi, tu retiens tes larmes.",
        "Le présentateur donne un grand coup de bras. Il faisait du lancer de marteau, avant.",
        "La roue tourne. Mamie Gertrude ouvre un œil.",
        "Ça tourne, ça tourne… Tu regrettes déjà un peu.",
        "La roue tourne si vite que tu vois ta vie défiler. Surtout tes relevés bancaires.",
    ]

    static let mamie = [
        "Mamie Gertrude, 87 ans, a surgi de nulle part, a pris ta mise et est repartie en déambulateur. À une vitesse surprenante.",
        "Mamie Gertrude t'a volé ta mise. Elle dit que c'est pour « l'héritage ». Pas le tien.",
        "Mamie Gertrude a empoché ta mise en te pinçant la joue. Tu n'as pas osé protester.",
        "« C'est pour mes bonbons à la violette », a dit Mamie Gertrude en partant avec tes billets.",
        "Mamie Gertrude t'a pris ta mise et t'a donné un caramel mou en échange. Un seul. Déjà entamé.",
        "Mamie Gertrude a encore frappé. La sécurité refuse d'intervenir : elle leur fait peur aussi.",
        "Mamie Gertrude a glissé ta mise dans son soutien-gorge. Personne n'ira la chercher là.",
    ]

    static let fisc = [
        "Un monsieur en costume gris a prélevé 100 % de ta mise. « Taxe sur l'espoir », a-t-il dit.",
        "Le fisc a saisi ta mise avant même que la roue s'arrête. Rapide, pour une fois.",
        "Ta mise a été déclarée, taxée, puis taxée encore. Il ne reste rien.",
        "Un contrôleur des impôts est sorti de derrière la roue. Personne ne sait depuis combien de temps il attendait.",
        "Ta mise va financer un rond-point. Tu pourras aller le visiter.",
    ]

    static let banqueroute = [
        "BANQUEROUTE ! La roue l'annonce avec un bruit de klaxon très humiliant.",
        "Banqueroute. Un projecteur se braque sur toi pendant que le public fait « ooooh ».",
        "Banqueroute. Le présentateur te serre la main avec une compassion de façade.",
        "Banqueroute ! Ta mise s'évapore dans un nuage de confettis tristes.",
        "Banqueroute. Tu fais un sourire crispé pour des caméras qui n'existent pas.",
    ]

    static let chat = [
        "Le chat du casino a sauté sur la roue et ta mise a disparu avec lui. Il ronronne.",
        "Moustache, le chat du casino, s'est assis sur ta mise. Il refuse de bouger. Elle est à lui maintenant.",
        "Un chat a traversé la roue. Le règlement est clair : tout ce qu'il touche, il le garde.",
        "Le chat t'a regardé, puis a poussé ta mise de la table avec sa patte. Deux fois, pour être sûr.",
        "Le chat est le vrai patron du casino. Il vient d'encaisser.",
    ]

    static let panache = [
        "Perdu, mais avec panache. Tu salues la salle d'un grand geste. Personne ne regarde.",
        "Perdu, mais avec style. Le style ne se mange pas.",
        "Tu as tout perdu avec tant d'élégance que le présentateur a failli te rembourser. Failli.",
        "Perdu. Tu fais une révérence. Tu trébuches un peu. Toujours avec panache.",
        "Ta mise a disparu, mais ta dignité est presque intacte. Presque.",
    ]

    static let moitie = [
        "La roue te rend la moitié de ta mise. Elle garde l'autre pour s'acheter de l'huile.",
        "Tu as perdu, mais à moitié. C'est presque gagner, si on plisse les yeux.",
        "La moitié de ta mise revient. L'autre moitié a fait de mauvais choix de vie.",
        "Demi-mise rendue. Le présentateur appelle ça « une demi-victoire ». Il ment à moitié.",
        "Tu récupères la moitié. Tu fais la moitié d'un sourire.",
        "La roue est d'humeur généreuse. Mais pas trop.",
    ]

    static let rembourse = [
        "La roue te rend exactement ta mise. Elle voulait juste te faire peur.",
        "Remboursé ! Tout ce suspense pour revenir au point de départ.",
        "Mise rendue. Le public applaudit poliment, faute de mieux.",
        "Rien gagné, rien perdu, juste quelques battements de cœur en trop.",
        "La roue te rend ta mise avec un clin d'œil. Elle reviendra la chercher.",
        "Égalité. Tu as tourné en rond, comme la roue.",
    ]

    static func petitGain(_ m: String, _ g: (String, String) -> String) -> String {
        [
            "\(m) ! Tu fais une petite danse. Elle n'est pas belle, mais elle est sincère.",
            "Gagné ! Le présentateur te tape dans le dos un peu trop fort.",
            "\(m) ! Tu commences à croire que tu as « la main ». Attention.",
            "La roue t'a souri. Un sourire en coin, mais un sourire.",
            "Gagné ! Tu cries « ENCORE ! » sans réfléchir. C'est exactement ce qu'ils veulent.",
            "\(m). Tu calcules déjà combien il en faudrait pour un jet-ski.",
            "Gagné ! Tu te sens " + g("le roi du monde", "la reine du monde") + ". Pendant environ quatre secondes.",
        ].randomElement() ?? "Gagné !"
    }

    static func grosGain(_ m: String, _ g: (String, String) -> String) -> String {
        [
            "\(m) ! Le public se lève. Enfin, deux personnes. C'est déjà ça.",
            "\(m) ! Des confettis tombent du plafond. Quelqu'un était payé pour attendre ce moment.",
            "\(m) ! Tu embrasses la roue. Elle est collante.",
            "\(m) ! Le présentateur te demande ce que tu vas faire de l'argent. Tu réponds « rejouer ». Silence gêné.",
            "\(m) ! Ta photo va finir sur le mur des gagnants, entre un dentiste et un pompier.",
            "\(m) ! Tu appelles ta mère. Elle ne répond pas. Elle joue aussi.",
            "\(m) ! Tu es tellement " + g("ému", "émue") + " que tu remercies la roue. À voix haute.",
        ].randomElement() ?? "\(m) !"
    }

    static func jackpot(_ m: String, _ g: (String, String) -> String) -> String {
        [
            "\(m) !!! Les lumières clignotent, une sirène hurle, tu pleures un peu.",
            "\(m) ! Le directeur descend en personne vérifier que la roue n'est pas cassée.",
            "\(m) ! Tu es " + g("porté", "portée") + " en triomphe par des inconnus qui veulent clairement ton numéro de compte.",
            "\(m) ! Mamie Gertrude te regarde depuis le bar. Elle prend des notes.",
            "\(m) ! Tu viens de comprendre pourquoi les gens jouent. C'est terrible.",
            "\(m) ! La roue s'est arrêtée là. Elle-même n'y croit pas.",
            "\(m) ! Tu promets de tout placer intelligemment. Tu ne le feras pas.",
        ].randomElement() ?? "\(m) !"
    }
}

struct RoueFortuneTirage: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Vue du jeu

struct RoueVue: View {
    let lieu: CasinoLieu
    @EnvironmentObject var engine: GameEngine
    @ObservedObject private var stockage = CasinoStockage.shared

    @State private var mise: Int = 0
    @State private var angle: Double = 0
    @State private var enCours = false
    @State private var gagnant: Int?
    @State private var historique: [RoueFortuneTirage] = []
    @State private var message: String = RoueFortuneTextes.accueil.randomElement() ?? "Faites tourner la roue !"
    @State private var messageGain: Bool?

    private var argent: Int { engine.joueur?.argent ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                RoueFortuneDessin(angle: angle, surbrillance: enCours ? nil : gagnant, taille: 290)
                    .padding(.top, 10)
                historiqueVue
                CasinoBandeau(texte: message, gain: messageGain)
                CasinoSelecteurMise(mise: $mise, lieu: lieu, argent: argent)
                    .disabled(enCours)
                CasinoBouton(titre: enCours ? "Ça tourne…" : "Faire tourner la roue · \(Format.argent(mise))",
                             actif: !enCours && mise > 0) {
                    lancer()
                }
                Text("Retour moyen certifié : \(Int((RoueFortuneDonnees.retourMoyen * 100).rounded())) %. Certifié par le casino, pour le casino.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
    }

    private var historiqueVue: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            if historique.isEmpty {
                Text("La roue n'a encore ruiné personne aujourd'hui.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            ForEach(historique) { tirage in
                pastille(RoueFortuneDonnees.segments[tirage.index])
            }
            Spacer(minLength: 0)
        }
        .frame(height: 26)
    }

    private func pastille(_ s: RoueFortuneSegment) -> some View {
        Text(s.multiplicateur == 0 && !s.emoji.isEmpty ? s.emoji : s.etiquette)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(s.texteFonce ? CasinoStyle.nuit : Color.white)
            .padding(.horizontal, 6)
            .frame(height: 24)
            .background(s.couleur, in: Capsule())
    }

    // MARK: Actions

    private func g(_ masculin: String, _ feminin: String) -> String {
        engine.joueur?.g(masculin, feminin) ?? masculin
    }

    private func dire(_ texte: String, _ gain: Bool?) {
        withAnimation(.easeInOut(duration: 0.2)) {
            message = texte
            messageGain = gain
        }
    }

    private func lancer() {
        guard !enCours else { return }
        let m = mise
        guard m >= lieu.miseMin else {
            dire("Mise minimum : \(Format.argent(lieu.miseMin)). Le présentateur ne se déplace pas pour moins.", nil)
            return
        }
        guard m <= lieu.miseMax else {
            dire("Mise maximum : \(Format.argent(lieu.miseMax)). La roue a le vertige au-delà.", nil)
            return
        }
        guard m <= argent, engine.casinoMiser(m, jeu: .roue) else {
            dire("Fonds insuffisants. Même Mamie Gertrude a plus d'argent que toi.", false)
            return
        }

        enCours = true
        dire(RoueFortuneTextes.lancement.randomElement() ?? "Ça tourne !", nil)

        let index = RoueFortuneDonnees.tirer()
        let segment = 360.0 / Double(RoueFortuneDonnees.segments.count)
        // La case `index` est dessinée à index × segment degrés du haut : on l'amène sous le pointeur.
        var delta = (-Double(index) * segment - angle).truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        let cible = angle + 360 * 6 + delta + Double.random(in: (-segment * 0.35)...(segment * 0.35))

        withAnimation(.timingCurve(0.12, 0.6, 0.2, 1, duration: 5.2)) {
            angle = cible
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.4) {
            terminer(index: index, mise: m)
        }
    }

    private func terminer(index: Int, mise m: Int) {
        let s = RoueFortuneDonnees.segments[index]
        let paiement = Int((Double(m) * s.multiplicateur).rounded(.down))
        engine.casinoRegler(mise: m, paiement: paiement, jeu: .roue, detail: "Roue de la fortune (\(s.etiquette))")

        historique.insert(RoueFortuneTirage(index: index), at: 0)
        if historique.count > 9 { historique.removeLast(historique.count - 9) }
        gagnant = index

        let net = paiement - m
        let entete = s.etiquette + " — " + s.titre + ". "
        if s.multiplicateur == 0 {
            dire((s.phrases.randomElement() ?? "Perdu.") + " (−\(Format.argent(m)))", false)
        } else if s.multiplicateur < 1 {
            dire(entete + (RoueFortuneTextes.moitie.randomElement() ?? "") + " Tu récupères \(Format.argent(paiement)).", false)
        } else if s.multiplicateur == 1 {
            dire(entete + (RoueFortuneTextes.rembourse.randomElement() ?? ""), nil)
        } else if s.multiplicateur < 5 {
            dire(RoueFortuneTextes.petitGain(s.etiquette, { g($0, $1) }) + " (+\(Format.argent(net)))", true)
        } else if s.multiplicateur < 20 {
            dire(RoueFortuneTextes.grosGain(s.etiquette, { g($0, $1) }) + " (+\(Format.argent(net)))", true)
        } else {
            dire(RoueFortuneTextes.jackpot(s.etiquette, { g($0, $1) }) + " (+\(Format.argent(net)))", true)
        }
        enCours = false
    }
}

// MARK: - Dessin de la roue

/// Une part de disque entre deux angles, en degrés, 0 = en haut, sens horaire.
struct RoueFortuneSecteurForme: Shape {
    let debut: Double
    let fin: Double

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let rayon = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: centre)
        p.addArc(center: centre, radius: rayon, startAngle: .degrees(debut - 90), endAngle: .degrees(fin - 90), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// La grande roue, ses ampoules et son pointeur.
struct RoueFortuneDessin: View {
    let angle: Double
    let surbrillance: Int?
    var taille: CGFloat = 290

    private var nombre: Int { RoueFortuneDonnees.segments.count }
    private var segment: Double { 360.0 / Double(nombre) }

    var body: some View {
        ZStack {
            Circle()
                .fill(CasinoStyle.nuit)
                .frame(width: taille + 18, height: taille + 18)
                .overlay(Circle().strokeBorder(CasinoStyle.or, lineWidth: 3))
                .shadow(color: .black.opacity(0.5), radius: 8, y: 5)
            roue
                .rotationEffect(.degrees(angle))
            moyeu
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 30))
                .foregroundStyle(CasinoStyle.rouge)
                .overlay(
                    Image(systemName: "arrowtriangle.down")
                        .font(.system(size: 30))
                        .foregroundStyle(CasinoStyle.or)
                )
                .shadow(color: .black.opacity(0.6), radius: 2, y: 2)
                .offset(y: -taille / 2 - 8)
        }
        .frame(width: taille + 18, height: taille + 40)
    }

    private var roue: some View {
        ZStack {
            ForEach(RoueFortuneDonnees.segments) { s in
                secteur(s)
            }
            ForEach(RoueFortuneDonnees.segments) { s in
                etiquette(s)
            }
            ForEach(0..<nombre, id: \.self) { i in
                Circle()
                    .fill(i % 2 == 0 ? CasinoStyle.or : Color.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: CasinoStyle.or.opacity(0.8), radius: 2)
                    .offset(y: -taille * 0.485)
                    .rotationEffect(.degrees(Double(i) * segment + segment / 2))
            }
            if let g = surbrillance, g >= 0, g < nombre {
                RoueFortuneSecteurForme(debut: Double(g) * segment - segment / 2, fin: Double(g) * segment + segment / 2)
                    .stroke(Color.white, lineWidth: 3)
            }
        }
        .frame(width: taille, height: taille)
    }

    private func secteur(_ s: RoueFortuneSegment) -> some View {
        let centre = Double(s.id) * segment
        let forme = RoueFortuneSecteurForme(debut: centre - segment / 2, fin: centre + segment / 2)
        return ZStack {
            forme.fill(s.couleur)
            forme.stroke(CasinoStyle.or.opacity(0.8), lineWidth: 1)
        }
    }

    private func etiquette(_ s: RoueFortuneSegment) -> some View {
        VStack(spacing: 0) {
            if !s.emoji.isEmpty {
                Text(s.emoji).font(.system(size: 13))
            }
            Text(s.etiquette)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(s.texteFonce ? CasinoStyle.nuit : Color.white)
        }
        .frame(width: 30)
        .offset(y: -taille * 0.37)
        .rotationEffect(.degrees(Double(s.id) * segment))
    }

    private var moyeu: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [CasinoStyle.or, Color(red: 0.6, green: 0.42, blue: 0.1)],
                                     center: .topLeading, startRadius: 2, endRadius: taille * 0.12))
                .frame(width: taille * 0.18, height: taille * 0.18)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
            Image(systemName: "star.fill")
                .font(.system(size: taille * 0.07))
                .foregroundStyle(CasinoStyle.nuit)
        }
    }
}

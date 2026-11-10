import SwiftUI

// MARK: - Règles

/// Règles et données de la roulette européenne (un seul zéro).
enum RouletteRegles {
    static let rouges: Set<Int> = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

    /// Ordre des cases sur une roue européenne, dans le sens des aiguilles d'une montre.
    static let ordreRoue: [Int] = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
                                   5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]

    static let vert = Color(red: 0.08, green: 0.55, blue: 0.28)
    static let noir = Color(white: 0.1)

    static func estRouge(_ n: Int) -> Bool { rouges.contains(n) }

    static func couleur(_ n: Int) -> Color {
        if n == 0 { return vert }
        return estRouge(n) ? CasinoStyle.rouge : noir
    }

    static func nomCouleur(_ n: Int) -> String {
        if n == 0 { return "vert" }
        return estRouge(n) ? "rouge" : "noir"
    }

    /// « 17 noir, impair, manque ».
    static func description(_ n: Int) -> String {
        if n == 0 { return "0, le zéro vert" }
        let parite = n % 2 == 0 ? "pair" : "impair"
        let moitie = n <= 18 ? "manque" : "passe"
        return "\(n) \(nomCouleur(n)), \(parite), \(moitie)"
    }
}

// MARK: - Paris

enum RoulettePari: Hashable {
    case plein(Int)
    case rouge, noir, pair, impair, manque, passe
    /// 1 = 1-12, 2 = 13-24, 3 = 25-36.
    case douzaine(Int)
    /// 1 = 1, 4, 7… ; 2 = 2, 5, 8… ; 3 = 3, 6, 9…
    case colonne(Int)

    /// Gain net pour 1 € misé (le paiement rend aussi la mise).
    var cote: Int {
        switch self {
        case .plein: return 35
        case .douzaine, .colonne: return 2
        case .rouge, .noir, .pair, .impair, .manque, .passe: return 1
        }
    }

    var estPlein: Bool {
        switch self {
        case .plein: return true
        default: return false
        }
    }

    func gagne(_ n: Int) -> Bool {
        switch self {
        case .plein(let x): return n == x
        case .rouge: return n != 0 && RouletteRegles.estRouge(n)
        case .noir: return n != 0 && !RouletteRegles.estRouge(n)
        case .pair: return n != 0 && n % 2 == 0
        case .impair: return n % 2 == 1
        case .manque: return n >= 1 && n <= 18
        case .passe: return n >= 19 && n <= 36
        case .douzaine(let d): return n != 0 && (n - 1) / 12 + 1 == d
        case .colonne(let c): return n != 0 && (n - 1) % 3 + 1 == c
        }
    }
}

struct RouletteAction {
    let pari: RoulettePari
    let montant: Int
}

struct RouletteTirage: Identifiable {
    let id = UUID()
    let numero: Int
}

// MARK: - Textes

enum RouletteTextes {
    static let accueil = [
        "Le croupier ajuste son nœud papillon et te regarde comme un futur client fidèle.",
        "« Faites vos jeux ! » Le croupier dit ça 4 000 fois par jour. Il rêve de dire autre chose.",
        "La bille t'attend. Elle a l'air confiante. Plus que toi.",
        "Un monsieur à côté mise tout sur le 17 depuis 1998. Il dit que ça va venir.",
        "Le tapis sent la moquette neuve et les décisions regrettables.",
        "« Ici, chaque numéro a sa chance. Surtout le zéro. » Le croupier te fait un clin d'œil.",
        "Une dame mise uniquement sur l'âge de ses chats. Elle a onze chats.",
    ]

    static let lancement = [
        "« Rien ne va plus ! » La bille part en courant, comme ton salaire.",
        "Le croupier lance la bille avec la grâce d'un danseur fatigué.",
        "La bille tourne. Ton cœur aussi. Seule la bille sait où elle va.",
        "« Les jeux sont faits. » Tu fais semblant de ne pas prier.",
        "La roue tourne. Quelque part, ton banquier frissonne.",
        "Clac-clac-clac… Tu retiens ta respiration. Ce n'est pas obligatoire.",
        "Le croupier lance la bille et regarde ailleurs. Ça ne le concerne pas, au fond.",
        "La bille fait le tour du monde en quatre secondes. Ton argent aussi.",
    ]

    static let zero = [
        "Zéro. Le casino remercie chaleureusement tout le monde.",
        "Le zéro vert : la seule case qui ne joue jamais contre la maison.",
        "Zéro. Le croupier ratisse la table avec un plaisir mal dissimulé.",
        "La bille est tombée dans le zéro. Elle a sûrement été payée pour ça.",
        "Zéro ! Même le monsieur du 17 a pleuré.",
        "Zéro, comme ton solde si tu continues comme ça.",
        "Le zéro est sorti. Le croupier fredonne doucement en ramassant tout.",
    ]

    static func perte(_ g: (String, String) -> String) -> String {
        [
            "Perdu. Le croupier ramasse tes jetons avec son râteau, comme des feuilles mortes.",
            "La bille t'a regardé droit dans les yeux et a choisi une autre case.",
            "Raté. Tu dis « je le sentais pas » alors que tu le sentais très fort.",
            "Le râteau du croupier est passé. Il ne reste rien. Même pas ta dignité.",
            "Perdu. Tu expliques à ton voisin que c'est une « stratégie à long terme ».",
            "Tu étais tellement " + g("sûr", "sûre") + " de toi. La bille, beaucoup moins.",
            "Le croupier dit « dommage ». Il n'a pas l'air de le penser.",
            "Perdu. Tu cherches une horloge au plafond. Il n'y en a jamais eu.",
            "La bille a rebondi trois fois, juste pour te faire espérer. Cruelle.",
        ].randomElement() ?? "Perdu."
    }

    static let partiel = [
        "Tu as gagné… un peu… moins que ce que tu as misé. Félicitations, en quelque sorte.",
        "Une partie de tes paris est passée. Pas assez pour sourire, assez pour rejouer. Le piège classique.",
        "Petite victoire, grosse perte. Le croupier appelle ça « un tour normal ».",
        "Tu récupères des miettes. Les pigeons du parvis sont jaloux.",
        "Couvrir toute la table, c'est être sûr de gagner un peu et de perdre beaucoup.",
        "Bilan : négatif, mais avec des moments forts.",
    ]

    static let nul = [
        "Tu retrouves exactement ta mise. Tout ce stress pour rien.",
        "Ni gagné, ni perdu. Le casino te remercie pour ce moment d'adrénaline gratuit.",
        "Égalité parfaite. Tu as transpiré pour zéro euro.",
        "Opération blanche. Ton comptable serait fier, ton cœur un peu moins.",
        "Retour à la case départ. Comme au jeu de l'oie, mais sans l'oie.",
    ]

    static func gain(_ g: (String, String) -> String) -> String {
        [
            "Gagné ! Le croupier pousse tes jetons vers toi avec une lenteur suspecte.",
            "Gagné ! Tu pousses un petit cri que tu regretteras plus tard.",
            "La bille t'aime. Pour l'instant.",
            "Gagné ! Tu tapes dans la main d'un inconnu. Il a l'air gêné.",
            "Victoire ! Tu calcules déjà ce que tu ferais avec le double.",
            "Tu es " + g("béni", "bénie") + " des dieux de la bille. Profites-en, ils sont lunatiques.",
            "Gagné ! Le vigile note discrètement ton visage.",
            "Gagné ! Ta stratégie (aucune) a payé.",
        ].randomElement() ?? "Gagné !"
    }

    static func plein(_ g: (String, String) -> String) -> String {
        [
            "PLEIN ! 35 fois la mise ! Le croupier recompte deux fois avant de payer.",
            "Le numéro exact ! Tu hurles si fort que le pianiste s'arrête.",
            "Plein ! Toute la table t'applaudit et veut connaître ton numéro porte-bonheur.",
            "Numéro plein ! Tu es " + g("convaincu", "convaincue") + " d'avoir un don. Tu n'en as pas.",
            "Plein ! Le directeur sort de son bureau pour voir qui fait autant de bruit.",
            "PLEIN ! Tu embrasses la bille. Le croupier te demande poliment de la rendre.",
            "Le numéro tombe pile. Tu commences à croire au destin. C'est dangereux.",
        ].randomElement() ?? "Plein !"
    }
}

// MARK: - Vue du jeu

struct RouletteVue: View {
    let lieu: CasinoLieu
    @EnvironmentObject var engine: GameEngine
    @ObservedObject private var stockage = CasinoStockage.shared

    @State private var paris: [RoulettePari: Int] = [:]
    @State private var actions: [RouletteAction] = []
    @State private var parisPrecedents: [RoulettePari: Int] = [:]
    @State private var valeurJeton: Int = 0
    @State private var angleRoue: Double = 0
    @State private var angleBille: Double = 0
    @State private var billeVisible = false
    @State private var enCours = false
    @State private var dernierNumero: Int?
    @State private var historique: [RouletteTirage] = []
    @State private var message: String = RouletteTextes.accueil.randomElement() ?? "Faites vos jeux !"
    @State private var messageGain: Bool?

    private let hauteurCase: CGFloat = 34
    private let largeurZero: CGFloat = 26
    private let largeurColonne: CGFloat = 28

    private var argent: Int { engine.joueur?.argent ?? 0 }
    private var plafond: Int { max(0, min(lieu.miseMax, argent)) }
    private var total: Int { paris.values.reduce(0, +) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                RouletteRoueDessin(angleRoue: angleRoue, angleBille: angleBille, billeVisible: billeVisible, taille: 250)
                    .padding(.top, 10)
                historiqueVue
                CasinoBandeau(texte: message, gain: messageGain)
                tableau
                chancesSimples
                CasinoSelecteurMise(mise: $valeurJeton, lieu: lieu, argent: argent, titre: "Valeur du jeton")
                    .disabled(enCours)
                resumeEtBoutons
                CasinoBouton(titre: titreLancer, actif: !enCours && total > 0) { lancer() }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
    }

    private var titreLancer: String {
        if enCours { return "La bille tourne…" }
        if total == 0 { return "Pose tes jetons sur le tapis" }
        return "Lancer la bille · \(Format.argent(total))"
    }

    // MARK: Historique

    private var historiqueVue: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            if historique.isEmpty {
                Text("Aucun tirage. La bille s'échauffe.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            ForEach(Array(historique.enumerated()), id: \.element.id) { index, tirage in
                pastille(tirage.numero, grande: index == 0)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 30)
    }

    private func pastille(_ n: Int, grande: Bool) -> some View {
        let cote: CGFloat = grande ? 28 : 22
        return Text("\(n)")
            .font(.system(size: grande ? 13 : 10, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: cote, height: cote)
            .background(Circle().fill(RouletteRegles.couleur(n)))
            .overlay(Circle().strokeBorder(grande ? CasinoStyle.or : Color.white.opacity(0.3), lineWidth: grande ? 2 : 1))
    }

    // MARK: Tapis

    private var tableau: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                caseNumero(0)
                    .frame(width: largeurZero, height: hauteurCase * 3 + 4)
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { ligne in
                        ligneNumeros(ligne)
                    }
                }
            }
            HStack(spacing: 2) {
                Color.clear.frame(width: largeurZero, height: 1)
                ForEach(1...3, id: \.self) { d in
                    caseTexte(.douzaine(d), texte: libelleDouzaine(d), couleur: Color.black.opacity(0.3))
                        .frame(height: 30)
                }
                Color.clear.frame(width: largeurColonne, height: 1)
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(CasinoStyle.or.opacity(0.4), lineWidth: 1))
        .disabled(enCours)
    }

    private func libelleDouzaine(_ d: Int) -> String {
        switch d {
        case 1: return "1-12"
        case 2: return "13-24"
        default: return "25-36"
        }
    }

    /// Ligne 0 = en haut (3, 6, 9… 36), ligne 2 = en bas (1, 4, 7… 34).
    private func ligneNumeros(_ ligne: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<12, id: \.self) { k in
                caseNumero(3 * k + 3 - ligne)
                    .frame(height: hauteurCase)
            }
            caseTexte(.colonne(3 - ligne), texte: "2:1", couleur: Color.black.opacity(0.3))
                .frame(width: largeurColonne, height: hauteurCase)
        }
    }

    private func caseNumero(_ n: Int) -> some View {
        let pari = RoulettePari.plein(n)
        let sorti = dernierNumero == n && !enCours
        return Button { poser(pari) } label: {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RouletteRegles.couleur(n), in: RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(sorti ? CasinoStyle.or : Color.white.opacity(0.25), lineWidth: sorti ? 2.5 : 0.5)
                )
                .overlay(alignment: .bottomTrailing) { marqueur(pari) }
        }
        .buttonStyle(.plain)
    }

    private func caseTexte(_ pari: RoulettePari, texte: String, couleur: Color) -> some View {
        let gagnant = !enCours && dernierNumero.map { pari.gagne($0) } == true
        return Button { poser(pari) } label: {
            Text(texte)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(couleur, in: RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(gagnant ? CasinoStyle.or : Color.white.opacity(0.3), lineWidth: gagnant ? 2 : 0.5)
                )
                .overlay(alignment: .topTrailing) { marqueur(pari) }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func marqueur(_ pari: RoulettePari) -> some View {
        if let m = paris[pari], m > 0 {
            RouletteMiniJeton(montant: m)
        }
    }

    private var chancesSimples: some View {
        HStack(spacing: 4) {
            caseTexte(.manque, texte: "1-18", couleur: Color.black.opacity(0.3))
            caseTexte(.pair, texte: "PAIR", couleur: Color.black.opacity(0.3))
            caseTexte(.rouge, texte: "ROUGE", couleur: CasinoStyle.rouge)
            caseTexte(.noir, texte: "NOIR", couleur: RouletteRegles.noir)
            caseTexte(.impair, texte: "IMPAIR", couleur: Color.black.opacity(0.3))
            caseTexte(.passe, texte: "19-36", couleur: Color.black.opacity(0.3))
        }
        .frame(height: 38)
        .disabled(enCours)
    }

    // MARK: Résumé et boutons

    private var resumeEtBoutons: some View {
        VStack(spacing: 8) {
            HStack {
                Text(resumeParis)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("Plein 35:1 · Douz./col. 2:1 · Simples 1:1")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: 8) {
                petitBouton("Annuler", icone: "arrow.uturn.backward", actif: !actions.isEmpty && !enCours) { annuler() }
                petitBouton("Effacer", icone: "trash", actif: !paris.isEmpty && !enCours) { effacer() }
                petitBouton("Remiser", icone: "arrow.clockwise", actif: !parisPrecedents.isEmpty && paris.isEmpty && !enCours) { remiser() }
            }
        }
    }

    private var resumeParis: String {
        if paris.isEmpty { return "Aucun pari posé" }
        let n = paris.count
        return "\(n) pari\(n > 1 ? "s" : "") · \(Format.argent(total))"
    }

    private func petitBouton(_ titre: String, icone: String, actif: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(titre, systemImage: icone)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.black.opacity(actif ? 0.35 : 0.15), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(actif ? Color.white : Color.white.opacity(0.35))
        }
        .buttonStyle(.plain)
        .disabled(!actif)
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

    private func poser(_ pari: RoulettePari) {
        guard !enCours else { return }
        let jeton = valeurJeton
        guard jeton > 0 else {
            dire("Choisis d'abord la valeur de ton jeton, plus bas. Le croupier refuse les boutons de chemise.", nil)
            return
        }
        guard total + jeton <= plafond else {
            if total + jeton > lieu.miseMax {
                dire("Plafond de la table : \(Format.argent(lieu.miseMax)) au total. Le croupier croise les bras.", nil)
            } else {
                dire("Tu n'as pas assez d'argent pour ce jeton. Le croupier fait semblant de ne pas avoir vu.", nil)
            }
            return
        }
        paris[pari, default: 0] += jeton
        actions.append(RouletteAction(pari: pari, montant: jeton))
    }

    private func annuler() {
        guard !enCours, let derniere = actions.popLast() else { return }
        let reste = (paris[derniere.pari] ?? 0) - derniere.montant
        if reste > 0 {
            paris[derniere.pari] = reste
        } else {
            paris[derniere.pari] = nil
        }
    }

    private func effacer() {
        guard !enCours else { return }
        paris = [:]
        actions = []
    }

    private func remiser() {
        guard !enCours, !parisPrecedents.isEmpty else { return }
        let t = parisPrecedents.values.reduce(0, +)
        guard t <= plafond else {
            dire("Impossible de remiser \(Format.argent(t)) : " + (t > lieu.miseMax ? "la table est plafonnée." : "ton compte n'est pas d'accord."), nil)
            return
        }
        paris = parisPrecedents
        actions = parisPrecedents.map { RouletteAction(pari: $0.key, montant: $0.value) }
    }

    private func lancer() {
        guard !enCours else { return }
        let mises = paris
        let t = mises.values.reduce(0, +)
        guard t > 0 else {
            dire("Pose au moins un jeton. Le croupier ne lance pas la bille pour le plaisir.", nil)
            return
        }
        guard t >= lieu.miseMin else {
            dire("Mise minimum de la table : \(Format.argent(lieu.miseMin)) au total. Ici, on ne joue pas des cacahuètes.", nil)
            return
        }
        guard t <= lieu.miseMax else {
            dire("Plafond de la table : \(Format.argent(lieu.miseMax)). Le directeur a ses limites.", nil)
            return
        }
        guard t <= argent, engine.casinoMiser(t, jeu: .roulette) else {
            dire("Fonds insuffisants. Le croupier range tes jetons imaginaires.", false)
            return
        }

        enCours = true
        billeVisible = true
        dire(RouletteTextes.lancement.randomElement() ?? "Rien ne va plus !", nil)

        let numero = Int.random(in: 0...36)
        let index = RouletteRegles.ordreRoue.firstIndex(of: numero) ?? 0
        let segment = 360.0 / Double(RouletteRegles.ordreRoue.count)
        // La case `index` est dessinée à index × segment degrés du haut : on tourne la roue pour l'amener sous le pointeur.
        var delta = (-Double(index) * segment - angleRoue).truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        let cibleRoue = angleRoue + 360 * 5 + delta + Double.random(in: (-segment * 0.3)...(segment * 0.3))
        // La bille tourne dans l'autre sens et finit toujours en haut, sous le pointeur.
        let cibleBille = angleBille - 360 * 8

        withAnimation(.timingCurve(0.1, 0.65, 0.25, 1, duration: 4.5)) {
            angleRoue = cibleRoue
        }
        withAnimation(.timingCurve(0.15, 0.7, 0.3, 1, duration: 4.2)) {
            angleBille = cibleBille
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.7) {
            terminer(numero: numero, mises: mises, total: t)
        }
    }

    private func terminer(numero: Int, mises: [RoulettePari: Int], total t: Int) {
        var paiement = 0
        var pleinGagne = false
        for (pari, montant) in mises where pari.gagne(numero) {
            paiement += montant * (pari.cote + 1)
            if pari.estPlein { pleinGagne = true }
        }
        engine.casinoRegler(mise: t, paiement: paiement, jeu: .roulette,
                            detail: "Roulette (le \(numero) \(RouletteRegles.nomCouleur(numero)))")

        historique.insert(RouletteTirage(numero: numero), at: 0)
        if historique.count > 10 { historique.removeLast(historique.count - 10) }
        dernierNumero = numero
        parisPrecedents = mises
        paris = [:]
        actions = []

        let net = paiement - t
        let entete = "Le \(RouletteRegles.description(numero)). "
        if paiement == 0 && numero == 0 {
            dire(entete + (RouletteTextes.zero.randomElement() ?? "Zéro."), false)
        } else if paiement == 0 {
            dire(entete + RouletteTextes.perte({ g($0, $1) }) + " (−\(Format.argent(t)))", false)
        } else if net < 0 {
            dire(entete + (RouletteTextes.partiel.randomElement() ?? "") + " Tu récupères \(Format.argent(paiement)) sur \(Format.argent(t)).", false)
        } else if net == 0 {
            dire(entete + (RouletteTextes.nul.randomElement() ?? ""), nil)
        } else if pleinGagne {
            dire(entete + RouletteTextes.plein({ g($0, $1) }) + " (+\(Format.argent(net)))", true)
        } else {
            dire(entete + RouletteTextes.gain({ g($0, $1) }) + " (+\(Format.argent(net)))", true)
        }
        enCours = false
    }
}

// MARK: - Petit jeton posé sur le tapis

struct RouletteMiniJeton: View {
    let montant: Int
    var taille: CGFloat = 18

    var body: some View {
        ZStack {
            Circle().fill(CasinoJeton.couleur(montant))
            Circle().strokeBorder(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
            Text(CasinoSelecteurMise.court(montant))
                .font(.system(size: 7, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.white)
                .padding(2)
        }
        .frame(width: taille, height: taille)
        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
        .allowsHitTesting(false)
    }
}

// MARK: - Dessin de la roue

/// Une part de disque (ou d'anneau) entre deux angles, en degrés, 0 = en haut, sens horaire.
struct RouletteSecteurForme: Shape {
    let debut: Double
    let fin: Double
    /// Rayon intérieur en fraction du rayon (0 = part pleine).
    var rayonInterieur: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let rayon = min(rect.width, rect.height) / 2
        let a0 = Angle.degrees(debut - 90)
        let a1 = Angle.degrees(fin - 90)
        var p = Path()
        if rayonInterieur > 0 {
            p.addArc(center: centre, radius: rayon, startAngle: a0, endAngle: a1, clockwise: false)
            p.addArc(center: centre, radius: rayon * rayonInterieur, startAngle: a1, endAngle: a0, clockwise: true)
        } else {
            p.move(to: centre)
            p.addArc(center: centre, radius: rayon, startAngle: a0, endAngle: a1, clockwise: false)
        }
        p.closeSubpath()
        return p
    }
}

/// La roue européenne dessinée en SwiftUI, avec sa bille et son pointeur.
struct RouletteRoueDessin: View {
    let angleRoue: Double
    let angleBille: Double
    let billeVisible: Bool
    var taille: CGFloat = 250

    private var segment: Double { 360.0 / Double(RouletteRegles.ordreRoue.count) }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.26, blue: 0.12), Color(red: 0.22, green: 0.11, blue: 0.04)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: taille + 16, height: taille + 16)
                .overlay(Circle().strokeBorder(CasinoStyle.or.opacity(0.8), lineWidth: 2))
                .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
            roue
                .rotationEffect(.degrees(angleRoue))
            Circle()
                .fill(RadialGradient(colors: [.white, Color(white: 0.75)], center: .topLeading, startRadius: 1, endRadius: 9))
                .frame(width: 11, height: 11)
                .shadow(color: .black.opacity(0.6), radius: 1.5, y: 1)
                .offset(y: -taille * 0.36)
                .rotationEffect(.degrees(angleBille))
                .opacity(billeVisible ? 1 : 0)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 20))
                .foregroundStyle(CasinoStyle.or)
                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                .offset(y: -taille / 2 - 13)
        }
        .frame(width: taille + 16, height: taille + 36)
    }

    private var roue: some View {
        ZStack {
            ForEach(0..<RouletteRegles.ordreRoue.count, id: \.self) { i in
                secteur(i)
            }
            ForEach(0..<RouletteRegles.ordreRoue.count, id: \.self) { i in
                numero(i)
            }
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.55, green: 0.33, blue: 0.15), Color(red: 0.25, green: 0.13, blue: 0.05)],
                                     center: .center, startRadius: 2, endRadius: taille * 0.32))
                .frame(width: taille * 0.64, height: taille * 0.64)
                .overlay(Circle().strokeBorder(CasinoStyle.or.opacity(0.7), lineWidth: 1.5))
            croisillon
        }
        .frame(width: taille, height: taille)
    }

    private func secteur(_ i: Int) -> some View {
        let centre = Double(i) * segment
        let forme = RouletteSecteurForme(debut: centre - segment / 2, fin: centre + segment / 2, rayonInterieur: 0.64)
        return ZStack {
            forme.fill(RouletteRegles.couleur(RouletteRegles.ordreRoue[i]))
            forme.stroke(CasinoStyle.or.opacity(0.7), lineWidth: 0.6)
        }
    }

    private func numero(_ i: Int) -> some View {
        Text("\(RouletteRegles.ordreRoue[i])")
            .font(.system(size: taille * 0.04, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .offset(y: -taille * 0.44)
            .rotationEffect(.degrees(Double(i) * segment))
    }

    private var croisillon: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { k in
                Capsule()
                    .fill(CasinoStyle.or)
                    .frame(width: taille * 0.035, height: taille * 0.42)
                    .rotationEffect(.degrees(Double(k) * 90))
            }
            Circle()
                .fill(CasinoStyle.or)
                .frame(width: taille * 0.09, height: taille * 0.09)
                .shadow(color: .black.opacity(0.4), radius: 2)
        }
    }
}

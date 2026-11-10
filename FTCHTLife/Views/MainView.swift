import SwiftUI

/// Écran principal : en-tête, journal de la vie, barres de stats, barre des menus avec « Âge +1 » au centre.
struct MainView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var categorie: CategorieMenu?
    @State private var moduleDirect: ModuleJeu?
    /// Stats juste avant le dernier « Âge +1 », pour afficher les +/- sur les barres.
    @State private var statsAvant: Stats?
    /// Bulle « 12 ans ! » affichée un instant après chaque année.
    @State private var bulleAge: Int?

    var body: some View {
        if let j = engine.joueur {
            VStack(spacing: 0) {
                entete(j)
                if j.vieEtat.justice.enPrison {
                    bandeauPrison
                }
                JournalVieView(joueur: j)
                PanneauStats(stats: j.stats, reference: statsAvant) { moduleDirect = .profil }
                barreMenus(j)
            }
            .background(Theme.fond.ignoresSafeArea())
            .overlay(alignment: .top) {
                if let age = bulleAge {
                    BulleAge(age: age)
                        .padding(.top, 74)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(item: $categorie) { c in
                MenuCategorieView(categorie: c)
                    .environmentObject(engine)
            }
            .sheet(item: $moduleDirect) { m in
                EcranModule(module: m)
                    .environmentObject(engine)
            }
            .sheet(item: $engine.evenementEnCours) { aff in
                EventView(affiche: aff)
                    .environmentObject(engine)
                    .interactiveDismissDisabled()
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: flashMonde) { f in
                MondeFlashSheet(flash: f, age: engine.joueur?.age ?? 0)
                    .presentationDetents([.medium, .large])
            }
            .animauxEvenements(cle: \.animaux)
            .scolPresentationAuto()
        }
    }

    /// La une du Journal du monde, montrée seulement quand aucun événement n'attend une réponse.
    private var flashMonde: Binding<MondeFlash?> {
        Binding(get: { engine.evenementEnCours == nil ? engine.flashMonde : nil },
                set: { if $0 == nil { engine.flashMonde = nil } })
    }

    // MARK: En-tête

    private func entete(_ j: Joueur) -> some View {
        HStack(spacing: 12) {
            Button { categorie = .moi } label: {
                AvatarJoueur(joueur: j, taille: 50)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(j.nomComplet)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.encre)
                        .lineLimit(1)
                    ShkurtaaaBadge()
                }
                Text("\(j.age) an\(j.age > 1 ? "s" : "") · \(j.occupation)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(Format.argent(j.argent))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(j.argent < 0 ? Theme.argentNegatif : Theme.argentPositif)
                    .chiffresAnimes()
                    .animation(.easeOut(duration: 0.4), value: j.argent)
            }
            Spacer(minLength: 4)
            Button { categorie = .moi } label: {
                VStack(spacing: 2) {
                    Image(systemName: CategorieMenu.moi.icone).font(.system(size: 22))
                    Text("Moi").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(CategorieMenu.moi.couleur)
                .frame(width: 52)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Theme.carte)
    }

    private var bandeauPrison: some View {
        Button { moduleDirect = .prison } label: {
            HStack {
                Image(systemName: "lock.shield.fill")
                Text("Tu es en prison. Touche ici pour agir.")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Theme.encre)
        }
        .buttonStyle(.plain)
    }

    // MARK: Barre des menus

    private func barreMenus(_ j: Joueur) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            boutonMenu(.carriere)
            boutonMenu(.biens)
            BoutonAge(actif: j.vivant && engine.evenementEnCours == nil) {
                vieillir(j)
            }
            .frame(maxWidth: .infinity)
            boutonMenu(.relations)
            boutonMenu(.activites)
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(Theme.carte.ignoresSafeArea(edges: .bottom))
    }

    private func vieillir(_ j: Joueur) {
        Vibration.moyenne()
        statsAvant = j.stats
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            engine.vieillir()
        }
        guard let nouveau = engine.joueur, nouveau.vivant else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { bulleAge = nouveau.age }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeIn(duration: 0.25)) { if bulleAge == nouveau.age { bulleAge = nil } }
        }
    }

    private func boutonMenu(_ c: CategorieMenu) -> some View {
        Button { Vibration.legere(); categorie = c } label: {
            VStack(spacing: 5) {
                Image(systemName: c.icone)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12).fill(c.couleur))
                Text(c.titre)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.encre)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(StyleAppui())
    }
}

/// Bulle qui annonce le nouvel âge.
struct BulleAge: View {
    let age: Int

    var body: some View {
        Text(age == 1 ? "1 an !" : "\(age) ans !")
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.accent))
            .shadow(color: Theme.accent.opacity(0.4), radius: 10, y: 4)
            .allowsHitTesting(false)
    }
}

// MARK: - Bouton « Âge +1 »

struct BoutonAge: View {
    let actif: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: -2) {
                Text("Âge")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                Text("+1")
                    .font(.system(size: 26, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 76, height: 76)
            .background(Circle().fill(actif ? Theme.accent : Theme.gris))
            .overlay(Circle().stroke(Color.white, lineWidth: 4))
            .shadow(color: Theme.accent.opacity(actif ? 0.45 : 0), radius: 8, y: 4)
        }
        .buttonStyle(StyleAppui())
        .disabled(!actif)
        .offset(y: -12)
        .padding(.bottom, -12)
        .accessibilityLabel("Vieillir d'un an")
    }
}

// MARK: - Avatar

struct AvatarJoueur: View {
    let joueur: Joueur
    var taille: CGFloat = 48

    private var visage: String {
        let f = joueur.genre == .femme
        if !joueur.vivant { return "🪦" }
        switch joueur.age {
        case ..<3: return "👶"
        case ..<13: return f ? "👧" : "👦"
        case ..<60: return f ? "👩" : "👨"
        default: return f ? "👵" : "👴"
        }
    }

    var body: some View {
        Text(visage)
            .font(.system(size: taille * 0.58))
            .frame(width: taille, height: taille)
            .background(Circle().fill(Theme.accent.opacity(0.14)))
            .overlay(Circle().stroke(Theme.accent.opacity(0.35), lineWidth: 2))
    }
}

// MARK: - Journal

struct JournalVieView: View {
    let joueur: Joueur

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(joueur.journal) { annee in
                        blocAnnee(annee, courante: annee.id == joueur.journal.last?.id)
                            .id(annee.id)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                    removal: .opacity))
                    }
                    if joueur.journal.count <= 2 && joueur.vivant {
                        CommentJouerCarte()
                    }
                    Color.clear.frame(height: 1).id("fin")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .onChange(of: joueur.journal.last?.lignes.count) { _ in
                withAnimation { proxy.scrollTo("fin", anchor: .bottom) }
            }
            .onChange(of: joueur.journal.count) { _ in
                withAnimation { proxy.scrollTo("fin", anchor: .bottom) }
            }
            .onAppear { proxy.scrollTo("fin", anchor: .bottom) }
        }
    }

    private func blocAnnee(_ annee: Annee, courante: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text("\(annee.age) an\(annee.age > 1 ? "s" : "")")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(courante ? Color.white : Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(courante ? Theme.accent : Theme.accent.opacity(0.12)))
                if courante {
                    Text("Cette année")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if annee.lignes.isEmpty {
                Text("Une année calme. Suspicieusement calme.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(annee.lignes.enumerated()), id: \.offset) { _, ligne in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle().fill(Theme.accent.opacity(courante ? 0.8 : 0.35)).frame(width: 5, height: 5)
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 2 }
                    Text(ligne)
                        .font(.subheadline)
                        .foregroundStyle(courante ? Theme.encre : Theme.encre.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(courante ? Theme.carte : Theme.carte.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(courante ? Theme.accent.opacity(0.3) : Color.clear, lineWidth: 1))
    }
}

/// Petite aide affichée au début de la vie.
struct CommentJouerCarte: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Comment jouer", systemImage: "lightbulb.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text("Touche le gros bouton **Âge +1** pour vivre une année.")
            Text("Entre deux années, les menus du bas te laissent agir : **Carrière** (école, travail), **Biens** (acheter, placer), **Relations** (famille, amour, téléphone), **Activités** (loisirs, santé, casino…).")
            Text("**Moi**, en haut à droite : ton profil, tes talents, tes trophées et les réglages.")
        }
        .font(.subheadline)
        .foregroundStyle(Theme.encre)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }
}

// MARK: - Stats

struct PanneauStats: View {
    let stats: Stats
    /// Stats de l'an dernier : si présentes, chaque barre montre son changement.
    var reference: Stats? = nil
    let ouvrirProfil: () -> Void

    private func d(_ actuel: Int, _ ancien: Int?) -> Int? {
        guard let a = ancien else { return nil }
        return actuel - a
    }

    var body: some View {
        Button(action: ouvrirProfil) {
            VStack(spacing: 6) {
                BarreStat(titre: "Bonheur", icone: "face.smiling.fill", valeur: stats.bonheur, delta: d(stats.bonheur, reference?.bonheur))
                BarreStat(titre: "Santé", icone: "heart.fill", valeur: stats.sante, delta: d(stats.sante, reference?.sante))
                BarreStat(titre: "Intelligence", icone: "brain.head.profile", valeur: stats.intelligence, delta: d(stats.intelligence, reference?.intelligence))
                BarreStat(titre: "Apparence", icone: "sparkles", valeur: stats.apparence, delta: d(stats.apparence, reference?.apparence))
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Theme.carte)
        }
        .buttonStyle(.plain)
        .overlay(Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1), alignment: .bottom)
    }
}

import SwiftUI

// MARK: - Style

enum LuxeTheme {
    static let bleu = Color(red: 0.05, green: 0.31, blue: 0.62)
    static let titre = Color(red: 0.06, green: 0.27, blue: 0.53)
    static let sousTitre = Color(red: 0.16, green: 0.36, blue: 0.62)
    static let vert = Color(red: 0.13, green: 0.62, blue: 0.27)
    static let or = Color(red: 0.82, green: 0.62, blue: 0.16)
    static let creme = Color(red: 1.0, green: 0.97, blue: 0.86)
    static let trait = Color(red: 0.06, green: 0.27, blue: 0.53).opacity(0.18)
}

extension View {
    /// Barre de navigation bleue avec le titre en capitales, comme les menus du jeu.
    func styleLuxe(_ titre: String) -> some View {
        self
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(titre.uppercased())
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .toolbarBackground(LuxeTheme.bleu, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

/// Une ligne de menu : gros émoji, titre en gras, sous-titre, et à droite un prix, un cadenas ou un chevron.
struct LigneEmoji: View {
    let emoji: String
    let titre: String
    var sousTitre: String? = nil
    var detail: String? = nil
    var detailCouleur: Color = LuxeTheme.vert
    var verrou: Bool = false
    var badge: Int = 0
    var chevron: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 36))
                .frame(width: 50)
                .opacity(verrou ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(titre)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(verrou ? Theme.gris : LuxeTheme.titre)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                if let sousTitre {
                    Text(sousTitre)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(verrou ? Theme.gris : LuxeTheme.sousTitre)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 4) {
                if let detail {
                    Text(detail)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(detailCouleur)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.argentNegatif))
                }
            }
            if verrou {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.gris)
            } else if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LuxeTheme.titre.opacity(0.75))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.carte)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LuxeTheme.trait).frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

/// Titre de groupe entre deux séries de lignes.
struct TitreGroupeLuxe: View {
    let titre: String

    var body: some View {
        Text(titre.uppercased())
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(LuxeTheme.bleu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

/// Bandeau du perso : nom, métier, solde bancaire.
struct BandeauLuxe: View {
    let j: Joueur

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(j.nomComplet)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(LuxeTheme.titre)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("⭐️ " + j.occupation)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(LuxeTheme.sousTitre)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Format.argent(j.argent))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(j.argent < 0 ? Theme.argentNegatif : LuxeTheme.vert)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Solde bancaire")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(LuxeTheme.sousTitre)
                }
            }
            HStack(spacing: 8) {
                PastilleLuxe(texte: "Patrimoine " + Format.argent(LuxeMoteur.patrimoine(j)))
                PastilleLuxe(texte: "✨ \(j.mondanite)/100 · " + LuxeMoteur.titreMondain(j.mondanite))
            }
        }
        .padding(16)
        .background(LuxeTheme.creme)
        .overlay(alignment: .bottom) { Rectangle().fill(LuxeTheme.trait).frame(height: 1) }
    }
}

struct PastilleLuxe: View {
    let texte: String

    var body: some View {
        Text(texte)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(LuxeTheme.titre)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.white.opacity(0.8)))
            .overlay(Capsule().stroke(LuxeTheme.or.opacity(0.5), lineWidth: 1))
    }
}

/// En-tête d'un écran : gros émoji et petit texte d'ambiance.
struct EnteteLuxe: View {
    let emoji: String
    let titre: String
    let texte: String

    var body: some View {
        VStack(spacing: 8) {
            Text(emoji).font(.system(size: 54))
            Text(titre)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(LuxeTheme.titre)
                .multilineTextAlignment(.center)
            Text(texte)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(LuxeTheme.sousTitre)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(LuxeTheme.creme)
        .overlay(alignment: .bottom) { Rectangle().fill(LuxeTheme.trait).frame(height: 1) }
    }
}

// MARK: - Concessions et joailliers

struct LuxeMaisonsView: View {
    @EnvironmentObject var engine: GameEngine
    let type: LuxeMaisonType
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                EnteteLuxe(emoji: type.emoji, titre: type.titre, texte: type.sousTitre + ". Certaines maisons ne reçoivent que sur rendez-vous.")
                if let j = engine.joueur {
                    ForEach(LuxeCatalogue.shared.maisons(type)) { m in
                        let raison = LuxeMoteur.verrou(m, j)
                        let n = LuxeCatalogue.shared.vitrine(m).count
                        if let raison {
                            Button { message = raison } label: {
                                LigneEmoji(emoji: m.emoji, titre: m.name, sousTitre: m.description, detail: "\(n) pièces", detailCouleur: Theme.gris, verrou: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                LuxeVitrineView(maison: m)
                            } label: {
                                LigneEmoji(emoji: m.emoji, titre: m.name, sousTitre: m.description, detail: "\(n) pièces", detailCouleur: LuxeTheme.sousTitre)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .background(Theme.fond.ignoresSafeArea())
        .styleLuxe(type.titre)
        .alerteResultat($message)
    }
}

struct LuxeVitrineView: View {
    @EnvironmentObject var engine: GameEngine
    let maison: LuxeMaison

    var body: some View {
        let argent = engine.joueur?.argent ?? 0
        let possedes = Set(engine.joueur?.boutique.items.map(\.catalogId) ?? [])
        ScrollView {
            LazyVStack(spacing: 0) {
                EnteteLuxe(emoji: maison.emoji, titre: maison.name, texte: "« \(maison.accueil) »")
                ForEach(LuxeCatalogue.shared.vitrine(maison)) { item in
                    let prix = ShopEngine.currentPrice(item)
                    NavigationLink {
                        ShopItemDetailView(item: item, listing: nil)
                    } label: {
                        LigneEmoji(emoji: item.emojiAffiche,
                                   titre: item.name,
                                   sousTitre: sousTitre(item, possede: possedes.contains(item.id)),
                                   detail: Format.argent(prix),
                                   detailCouleur: ShopHooks.canAfford(prix, argent) ? LuxeTheme.vert : Theme.argentNegatif)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Theme.fond.ignoresSafeArea())
        .styleLuxe(maison.name)
    }

    private func sousTitre(_ item: ShopItem, possede: Bool) -> String {
        var parts: [String] = []
        if !item.brand.isEmpty { parts.append(item.brand) }
        parts.append("Prestige \(item.prestige)/10")
        if possede { parts.append("déjà à toi") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Spa et soirées VIP

struct LuxeServicesView: View {
    @EnvironmentObject var engine: GameEngine
    let type: LuxeServiceType
    @State private var choisi: LuxeService?
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                entete
                if let j = engine.joueur {
                    ForEach(LuxeCatalogue.shared.services(type)) { s in
                        let raison = LuxeMoteur.verrou(s, j)
                        let prix = LuxeMoteur.prix(s.price)
                        Button {
                            if let raison { message = raison } else { choisi = s }
                        } label: {
                            LigneEmoji(emoji: s.emoji, titre: s.name, sousTitre: s.description,
                                       detail: Format.argent(prix),
                                       detailCouleur: ShopHooks.canAfford(prix, j.argent) ? LuxeTheme.vert : Theme.argentNegatif,
                                       verrou: raison != nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(Theme.fond.ignoresSafeArea())
        .styleLuxe(type == .spa ? "Spa de luxe" : "Soirées VIP")
        .alerteResultat($message)
        .sheet(item: $choisi) { s in
            LuxeServiceFiche(service: s)
                .environmentObject(engine)
        }
    }

    @ViewBuilder
    private var entete: some View {
        if type == .spa {
            EnteteLuxe(emoji: "🧖", titre: "Spa de luxe",
                       texte: "Massages, bains, cures et retraites. Chaque soin, une fois par an. Le peignoir est compris, pas les regrets.")
        } else {
            EnteteLuxe(emoji: "🥂", titre: "Soirées VIP",
                       texte: "Galas, avant-premières, défilés et dîners privés. Plus tu es connu et riche, plus les portes s'ouvrent.")
        }
    }
}

struct LuxeServiceFiche: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let service: LuxeService
    @State private var resultat: ShopResult?

    var body: some View {
        let prix = LuxeMoteur.prix(service.price)
        VStack(spacing: 16) {
            Text(service.emoji).font(.system(size: 60)).padding(.top, 26)
            Text(service.name)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(LuxeTheme.titre)
                .multilineTextAlignment(.center)
            Text(resultat?.message ?? service.description)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(Theme.encre)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if resultat?.ok == true {
                BoutonLuxe(titre: "Continuer") { dismiss() }
            } else {
                BoutonLuxe(titre: (service.type == .spa ? "Réserver · " : "Y aller · ") + Format.argent(prix)) {
                    var r = ShopResult(ok: false, message: "")
                    engine.modifier { j in
                        r = LuxeMoteur.profiter(service, &j)
                        if r.ok { engine.ajouterLigne(&j, r.message) }
                    }
                    Vibration.legere()
                    resultat = r
                }
                Button("Plus tard") { dismiss() }
                    .foregroundStyle(LuxeTheme.sousTitre)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .presentationDetents([.medium, .large])
    }
}

struct BoutonLuxe: View {
    let titre: String
    var couleur: Color = LuxeTheme.vert
    var actif: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titre)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(actif ? couleur : Theme.gris.opacity(0.5)))
        }
        .disabled(!actif)
    }
}

// MARK: - Dons aux œuvres

struct LuxeDonsView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var choisie: LuxeOeuvre?

    var body: some View {
        let l = engine.joueur?.boutique.luxe
        let total = l?.donsTotal ?? 0
        ScrollView {
            LazyVStack(spacing: 0) {
                EnteteLuxe(emoji: "🎗️", titre: "Dons aux œuvres", texte: resume(total))
                ForEach(LuxeCatalogue.shared.oeuvres) { o in
                    let donne = l?.donsParOeuvre[o.id] ?? 0
                    Button { choisie = o } label: {
                        LigneEmoji(emoji: o.emoji, titre: o.name, sousTitre: o.cause,
                                   detail: donne > 0 ? Format.argent(donne) : nil,
                                   detailCouleur: LuxeTheme.or)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Theme.fond.ignoresSafeArea())
        .styleLuxe("Dons aux œuvres")
        .sheet(item: $choisie) { o in
            LuxeDonFiche(oeuvre: o)
                .environmentObject(engine)
        }
    }

    private func resume(_ total: Int) -> String {
        guard total > 0 else { return "Donne à une cause qui te tient à cœur. Le karma suit, la presse aussi (si tu veux)." }
        var t = "Tu as donné \(Format.argent(total)) en tout."
        if let titre = LuxeMoteur.titreDonateur(total) { t += " Titre : \(titre)." }
        return t
    }
}

struct LuxeDonFiche: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let oeuvre: LuxeOeuvre
    @State private var anonyme = false
    @State private var resultat: String?

    private let colonnes = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        let argent = engine.joueur?.argent ?? 0
        ScrollView {
            VStack(spacing: 14) {
                Text(oeuvre.emoji).font(.system(size: 56)).padding(.top, 24)
                Text(oeuvre.name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(LuxeTheme.titre)
                    .multilineTextAlignment(.center)
                Text(resultat ?? oeuvre.description)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Theme.encre)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if resultat != nil {
                    BoutonLuxe(titre: "Continuer") { dismiss() }
                } else {
                    Toggle("Don anonyme (plus de karma, pas de presse)", isOn: $anonyme)
                        .font(.system(size: 15, design: .rounded))
                        .tint(LuxeTheme.vert)
                    LazyVGrid(columns: colonnes, spacing: 10) {
                        ForEach(LuxeMoteur.montantsDon, id: \.self) { m in
                            BoutonLuxe(titre: Format.argent(m), couleur: LuxeTheme.bleu, actif: ShopHooks.canAfford(m, argent)) {
                                donner(m)
                            }
                        }
                    }
                    if argent >= 1_000 {
                        BoutonLuxe(titre: "10 % de mon argent · " + Format.argent(argent / 10), couleur: LuxeTheme.or) {
                            donner(argent / 10)
                        }
                    }
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(LuxeTheme.sousTitre)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .presentationDetents([.large])
    }

    private func donner(_ montant: Int) {
        var r = ShopResult(ok: false, message: "")
        engine.modifier { j in
            r = LuxeMoteur.donner(montant, a: oeuvre, anonyme: anonyme, &j)
            if r.ok { engine.ajouterLigne(&j, r.message) }
        }
        Vibration.legere()
        resultat = r.message
    }
}

// MARK: - Société secrète

struct LuxeSocieteView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var candidature: LuxeSociete?
    @State private var rituel: LuxeRituel?
    @State private var message: String?
    @State private var confirmerQuitter = false
    @State private var confirmerTrahir = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let j = engine.joueur {
                    if let s = LuxeMoteur.societe(j), let m = j.boutique.luxe?.societe {
                        membre(j, s, m)
                    } else {
                        candidat(j)
                    }
                }
            }
        }
        .background(Theme.fond.ignoresSafeArea())
        .styleLuxe("Société secrète")
        .alerteResultat($message)
        .sheet(item: $candidature) { s in
            LuxeCooptationFiche(societe: s)
                .environmentObject(engine)
        }
        .sheet(item: $rituel) { r in
            LuxeRituelFiche(rituel: r)
                .environmentObject(engine)
        }
        .confirmationDialog("Quitter la société ?", isPresented: $confirmerQuitter, titleVisibility: .visible) {
            Button("Rendre mon insigne", role: .destructive) { agir { LuxeMoteur.quitter(&$0) } }
        } message: {
            Text("On n'entre pas deux fois. Et on ne sort jamais tout à fait.")
        }
        .confirmationDialog("Vendre les secrets à la presse ?", isPresented: $confirmerTrahir, titleVisibility: .visible) {
            Button("Appeler le journaliste", role: .destructive) { agir { LuxeMoteur.trahir(&$0) } }
        } message: {
            Text("Beaucoup d'argent, beaucoup de bruit, beaucoup d'ennemis.")
        }
    }

    @ViewBuilder
    private func candidat(_ j: Joueur) -> some View {
        EnteteLuxe(emoji: "🕯️", titre: "Sociétés secrètes",
                   texte: "Elles n'ont pas d'adresse ni de site. Il faut être assez riche, assez connu, et qu'un parrain te présente. Une demande par an et par société.")
        ForEach(LuxeCatalogue.shared.societes) { s in
            let raison = LuxeMoteur.verrouCooptation(s, j)
            Button {
                if let raison { message = raison } else { candidature = s }
            } label: {
                LigneEmoji(emoji: s.emoji, titre: s.name, sousTitre: "« \(s.devise) »",
                           detail: Format.argent(LuxeMoteur.prix(s.droitEntree)),
                           detailCouleur: raison == nil ? LuxeTheme.vert : Theme.gris,
                           verrou: raison != nil)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func membre(_ j: Joueur, _ s: LuxeSociete, _ m: LuxeMembre) -> some View {
        let rang = s.rangs[min(m.rang, s.rangs.count - 1)]
        EnteteLuxe(emoji: s.emoji, titre: s.name,
                   texte: "Grade : \(rang.titre) · \(m.annees) an\(m.annees > 1 ? "s" : "") de fidélité\nCotisation : \(Format.argent(LuxeMoteur.prix(s.cotisation))) par an\n« \(s.devise) »")
        TitreGroupeLuxe(titre: "Ce que tu peux faire")
        let reunion = LuxeMoteur.peutReunion(j)
        Button {
            if reunion {
                var r: LuxeRituel?
                engine.modifier { r = LuxeMoteur.tirerRituel(&$0) }
                if let r { rituel = r } else { message = "La réunion a été annulée. Personne ne dit pourquoi." }
            } else {
                message = "La réunion annuelle a déjà eu lieu. Prochaine convocation après « Âge +1 »."
            }
        } label: {
            LigneEmoji(emoji: "🕯️", titre: "Réunion annuelle", sousTitre: "Une convocation, une cagoule, une décision à prendre", verrou: !reunion)
        }
        .buttonStyle(.plain)

        let promo = LuxeMoteur.verrouPromotion(j)
        Button {
            if let promo { message = promo } else { agirResultat { LuxeMoteur.demanderPromotion(&$0) } }
        } label: {
            LigneEmoji(emoji: "🗝️", titre: "Demander une promotion",
                       sousTitre: LuxeMoteur.prochainRang(j).map { "Prochain grade : \($0.titre)" } ?? "Tu es tout en haut",
                       detail: LuxeMoteur.prochainRang(j).map { Format.argent(LuxeMoteur.prix($0.cout)) },
                       verrou: promo != nil)
        }
        .buttonStyle(.plain)

        Button { confirmerQuitter = true } label: {
            LigneEmoji(emoji: "🚪", titre: "Quitter la société", sousTitre: "Rendre ton insigne et disparaître des registres")
        }
        .buttonStyle(.plain)

        Button { confirmerTrahir = true } label: {
            LigneEmoji(emoji: "📰", titre: "Vendre les secrets à la presse", sousTitre: "Le scoop de l'année. Pour toi aussi, ça pourrait être la dernière.")
        }
        .buttonStyle(.plain)
    }

    private func agir(_ action: (inout Joueur) -> String) {
        var texte = ""
        engine.modifier { j in
            texte = action(&j)
            if !texte.isEmpty { engine.ajouterLigne(&j, texte) }
        }
        message = texte
    }

    private func agirResultat(_ action: (inout Joueur) -> ShopResult) {
        var r = ShopResult(ok: false, message: "")
        engine.modifier { j in
            r = action(&j)
            if r.ok { engine.ajouterLigne(&j, r.message) }
        }
        message = r.message
    }
}

struct LuxeCooptationFiche: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let societe: LuxeSociete
    @State private var resultat: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(societe.emoji).font(.system(size: 58)).padding(.top, 24)
                Text(societe.name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(LuxeTheme.titre)
                    .multilineTextAlignment(.center)
                Text("« \(societe.devise) »")
                    .font(.system(size: 15, design: .rounded).italic())
                    .foregroundStyle(LuxeTheme.sousTitre)
                    .multilineTextAlignment(.center)
                Text(resultat ?? societe.description)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(Theme.encre)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if resultat == nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Droit d'entrée : \(Format.argent(LuxeMoteur.prix(societe.droitEntree)))")
                        Text("Cotisation : \(Format.argent(LuxeMoteur.prix(societe.cotisation))) par an")
                        Text("Grades : " + societe.rangs.map(\.titre).joined(separator: " › "))
                    }
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(LuxeTheme.sousTitre)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    BoutonLuxe(titre: "Demander à être coopté", couleur: LuxeTheme.bleu) {
                        var r = ShopResult(ok: false, message: "")
                        engine.modifier { j in
                            r = LuxeMoteur.demanderCooptation(societe, &j)
                            if r.ok { engine.ajouterLigne(&j, r.message) }
                        }
                        Vibration.legere()
                        resultat = r.message
                    }
                    Button("Pas maintenant") { dismiss() }
                        .foregroundStyle(LuxeTheme.sousTitre)
                } else {
                    BoutonLuxe(titre: "Continuer") { dismiss() }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .presentationDetents([.large])
    }
}

struct LuxeRituelFiche: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let rituel: LuxeRituel
    @State private var resultat: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("🕯️").font(.system(size: 54)).padding(.top, 24)
                Text(rituel.text)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.encre)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let resultat {
                    Text(resultat)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(LuxeTheme.sousTitre)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    BoutonLuxe(titre: "Continuer") { dismiss() }
                } else {
                    ForEach(Array(rituel.choices.enumerated()), id: \.offset) { index, choix in
                        BoutonLuxe(titre: choix.label, couleur: LuxeTheme.bleu) { choisir(index) }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .interactiveDismissDisabled(resultat == nil)
        .presentationDetents([.large])
    }

    private func choisir(_ index: Int) {
        var texte = ""
        engine.modifier { j in
            texte = LuxeMoteur.resoudreRituel(rituel, choix: index, &j)
            if !texte.isEmpty { engine.ajouterLigne(&j, texte) }
        }
        Vibration.legere()
        resultat = texte
    }
}

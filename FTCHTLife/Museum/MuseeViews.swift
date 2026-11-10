import SwiftUI

// MARK: - Couleurs du journal

enum MuseeTheme {
    static let papier = Color(red: 0.97, green: 0.94, blue: 0.86)
    static let encre = Color(red: 0.16, green: 0.13, blue: 0.10)
    static let filet = Color(red: 0.16, green: 0.13, blue: 0.10).opacity(0.35)
    static let pierre = Color(red: 0.55, green: 0.56, blue: 0.58)
}

// MARK: - Nécrologie (écran de mort)

/// À placer dans l'écran de mort : range la vie au musée (une seule fois) et affiche sa nécrologie.
struct NecrologieView: View {
    let joueur: Joueur
    var dernierMetier: String? = nil
    var scoreVieReussie: Int? = nil

    @ObservedObject private var musee = MuseeStore.shared
    @State private var vie: MuseeVie?

    var body: some View {
        Group {
            if let vie = vie {
                NecroJournalCarte(vie: vie)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            if vie == nil {
                vie = musee.enregistrer(joueur: joueur, dernierMetier: dernierMetier, scoreVieReussie: scoreVieReussie)
            }
        }
    }
}

/// La nécrologie façon page de journal.
struct NecroJournalCarte: View {
    let vie: MuseeVie

    private var dateTexte: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .long
        return f.string(from: vie.dateFin)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 2) {
                Text("La Gazette de \(vie.ville)")
                    .font(.system(size: 20, weight: .black, design: .serif))
                    .multilineTextAlignment(.center)
                Text("Avis de décès · \(dateTexte) · 1 €")
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .textCase(.uppercase)
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity)
            filetDouble

            Text(vie.titre)
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline) {
                Text(vie.nomAvecSurnom)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .italic()
                Spacer()
                Text("0 – \(vie.age) ans")
                    .font(.system(size: 13, weight: .bold, design: .serif))
            }
            filet

            ForEach(Array(vie.paragraphes.enumerated()), id: \.offset) { _, p in
                Text(p)
                    .font(.system(size: 15, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let score = vie.scoreVieReussie {
                filet
                HStack {
                    Text("Vie réussie")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                    Spacer()
                    Text("\(score) / 100")
                        .font(.system(size: 15, weight: .black, design: .serif))
                }
            }

            filet
            Text("« \(vie.epitaphe) »")
                .font(.system(size: 14, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(MuseeTheme.encre)
        .padding(18)
        .background(MuseeTheme.papier, in: RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    private var filet: some View {
        Rectangle().fill(MuseeTheme.filet).frame(height: 1)
    }

    private var filetDouble: some View {
        VStack(spacing: 2) {
            Rectangle().fill(MuseeTheme.encre).frame(height: 2)
            Rectangle().fill(MuseeTheme.encre).frame(height: 1)
        }
    }
}

// MARK: - Musée

/// Le musée des vies. Écran autonome (avec sa propre navigation) : à présenter en `.sheet`.
struct MuseeView: View {
    @ObservedObject private var musee = MuseeStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var confirmerEffacement = false

    var body: some View {
        NavigationStack {
            Group {
                if musee.vies.isEmpty {
                    vide
                } else {
                    liste
                }
            }
            .navigationTitle("Musée des vies")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                if !musee.vies.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Vider le musée", role: .destructive) { confirmerEffacement = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog("Vider le musée ? Toutes les vies exposées seront oubliées.",
                                isPresented: $confirmerEffacement, titleVisibility: .visible) {
                Button("Vider", role: .destructive) { musee.toutEffacer() }
            }
        }
    }

    private var vide: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Le musée est vide")
                .font(.headline)
            Text("Chaque vie terminée viendra ici avec sa nécrologie, son surnom et son épitaphe. Pour l'instant, le conservateur s'ennuie.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var liste: some View {
        List {
            Section("Records") {
                record("Vies vécues", "\(musee.vies.count)", icone: "person.3.fill")
                record("Âge moyen", "\(musee.ageMoyen) ans", icone: "hourglass")
                if let v = musee.recordLongevite {
                    record("Plus longue vie", "\(v.prenom), \(v.age) ans", icone: "tortoise.fill")
                }
                if let v = musee.recordBrievete, musee.vies.count > 1 {
                    record("Plus courte vie", "\(v.prenom), \(v.age) ans", icone: "hare.fill")
                }
                if let v = musee.recordFortune, v.fortune > 0 {
                    record("Plus grosse fortune", "\(v.prenom), \(Format.argent(v.fortune))", icone: "banknote.fill")
                }
                if let v = musee.recordDettes {
                    record("Pire ardoise", "\(v.prenom), \(Format.argent(v.fortune))", icone: "creditcard.trianglebadge.exclamationmark")
                }
                if let s = musee.scoreMoyen {
                    record("Vie réussie (moyenne)", "\(s) / 100", icone: "star.fill")
                }
            }
            Section("Galerie") {
                ForEach(musee.vies) { v in
                    NavigationLink {
                        MuseeFicheView(vie: v)
                    } label: {
                        ligne(v)
                    }
                }
                .onDelete { index in
                    let ids = index.map { musee.vies[$0].id }
                    ids.forEach { musee.supprimer($0) }
                }
            }
        }
    }

    private func record(_ titre: String, _ valeur: String, icone: String) -> some View {
        HStack {
            Label(titre, systemImage: icone)
            Spacer()
            Text(valeur).bold().multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func ligne(_ v: MuseeVie) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(MuseeTheme.pierre.opacity(0.25))
                Text("\(v.age)")
                    .font(.system(size: 17, weight: .black, design: .serif))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(v.nomComplet).font(.headline)
                Text("« \(v.surnom) »")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Fiche d'une vie exposée au musée.
struct MuseeFicheView: View {
    let vie: MuseeVie

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NecroJournalCarte(vie: vie)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bilan").font(.headline)
                    info("Cause", "\(vie.mort) \(vie.cause)")
                    if let m = vie.dernierMetier { info("Dernier métier", m) }
                    info("Fortune", Format.argent(vie.fortune))
                    info("Diplôme", vie.diplome)
                    info("Amis", "\(vie.nbAmis)")
                    info("Enfants", "\(vie.nbEnfants)")
                    info("Ex", "\(vie.nbEx)")
                    Divider()
                    BarreStat(titre: "Santé", icone: "heart.fill", valeur: vie.stats.sante)
                    BarreStat(titre: "Bonheur", icone: "face.smiling", valeur: vie.stats.bonheur)
                    BarreStat(titre: "Intelligence", icone: "brain.head.profile", valeur: vie.stats.intelligence)
                    BarreStat(titre: "Apparence", icone: "sparkles", valeur: vie.stats.apparence)
                    BarreStat(titre: "Karma", icone: "leaf.fill", valeur: vie.stats.karma)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                if !vie.faitsMarquants.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Moments forts").font(.headline)
                        ForEach(Array(vie.faitsMarquants.enumerated()), id: \.offset) { _, f in
                            Text(f).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }

                pierreTombale
            }
            .padding()
        }
        .navigationTitle(vie.prenom)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func info(_ titre: String, _ valeur: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titre).foregroundStyle(.secondary)
            Spacer()
            Text(valeur).bold().multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var pierreTombale: some View {
        VStack(spacing: 6) {
            Image(systemName: "cross.fill").font(.title2)
            Text(vie.nomComplet).font(.system(size: 18, weight: .bold, design: .serif))
            Text("dit\(vie.genre == .femme ? "e" : "") « \(vie.surnom) »")
                .font(.system(size: 13, design: .serif)).italic()
            Text(vie.epitaphe)
                .font(.system(size: 14, design: .serif))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            MuseePierreForme()
                .fill(MuseeTheme.pierre)
        )
    }
}

/// Forme de pierre tombale (haut arrondi), compatible iOS 16.
struct MuseePierreForme: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width / 2, 80)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                 startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

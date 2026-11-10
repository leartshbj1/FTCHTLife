import SwiftUI

/// Écran « Journal du monde » : la une de l'année, les crises en cours et leurs effets, les archives.
/// `titresExternes` : gros titres d'autres modules (ex. lois votées par le module Politique).
struct MondeJournalView: View {
    let etat: MondeEtat
    let age: Int
    var titresExternes: [String] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MondeBandeau(age: age)

                    if let une = etat.derniereUne, une.age == age, let f = MondeJournal.flash(une.id) {
                        MondeFlashCarte(flash: f, grand: true)
                    } else {
                        Text("Rien de neuf cette année. Les journalistes sont en grève de l'inspiration.")
                            .font(.callout.italic())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    if !titresExternes.isEmpty {
                        section("Aussi à la une") {
                            ForEach(Array(titresExternes.enumerated()), id: \.offset) { _, titre in
                                Label(titre, systemImage: "newspaper")
                                    .font(.subheadline)
                            }
                        }
                    }

                    let actifs = MondeJournal.flashsActifs(etat)
                    if !actifs.isEmpty {
                        section("Ce qui change en ce moment") {
                            ForEach(actifs, id: \.actif.id) { item in
                                MondeCriseLigne(flash: item.flash, anneesRestantes: item.actif.anneesRestantes)
                            }
                        }
                    }

                    let archives = etat.archives.reversed().filter { $0.age != age || $0.id != etat.derniereUne?.id }
                    if !archives.isEmpty {
                        section("Archives") {
                            ForEach(Array(archives.enumerated()), id: \.offset) { _, une in
                                if let f = MondeJournal.flash(une.id) {
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text("\(une.age) ans")
                                            .font(.caption.bold().monospacedDigit())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 52, alignment: .leading)
                                        Text(f.emojiRubrique + " " + f.titre)
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Theme.fond.ignoresSafeArea())
            .navigationTitle("Journal du monde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func section<Contenu: View>(_ titre: String, @ViewBuilder contenu: () -> Contenu) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titre.uppercased())
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.accent)
            contenu()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.carte, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

/// En-tête façon quotidien.
struct MondeBandeau: View {
    let age: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("L'ÉCHO DE LA PLANÈTE")
                .font(.system(size: 26, weight: .black, design: .serif))
                .foregroundStyle(Theme.encre)
            Rectangle().fill(Theme.encre).frame(height: 2)
            HStack {
                Text("Édition de tes \(age) ans")
                Spacer()
                Text("Prix : ton attention")
            }
            .font(.system(size: 11, weight: .medium, design: .serif))
            .foregroundStyle(.secondary)
            Rectangle().fill(Theme.encre).frame(height: 1)
        }
        .padding(.horizontal)
    }
}

/// Un flash info avec ses effets. `grand` pour la une.
struct MondeFlashCarte: View {
    let flash: MondeFlash
    var grand: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(flash.emojiRubrique + " " + flash.nomRubrique.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Theme.accent)
            Text(flash.titre)
                .font(.system(size: grand ? 24 : 17, weight: .black, design: .serif))
                .foregroundStyle(Theme.encre)
                .fixedSize(horizontal: false, vertical: true)
            Text(flash.texte)
                .font(.system(size: grand ? 16 : 14, design: .serif))
                .foregroundStyle(Theme.encre.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            let effets = MondeJournal.resume(flash)
            if !effets.isEmpty {
                Divider()
                Text(flash.dureeEffets > 1 ? "Pendant \(flash.dureeEffets) ans :" : "Cette année :")
                    .font(.caption.bold())
                ForEach(effets, id: \.self) { ligne in
                    Text(ligne).font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.carte, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

/// Une crise en cours dans la liste « Ce qui change en ce moment ».
struct MondeCriseLigne: View {
    let flash: MondeFlash
    let anneesRestantes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(flash.emojiRubrique + " " + flash.titre)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(anneesRestantes > 1 ? "encore \(anneesRestantes) ans" : "dernière année")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(MondeJournal.resume(flash), id: \.self) { ligne in
                Text(ligne).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Fenêtre à présenter quand un nouveau flash sort (ex. `.sheet(item:)` sur le flash du rapport).
struct MondeFlashSheet: View {
    let flash: MondeFlash
    let age: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            MondeBandeau(age: age)
            MondeFlashCarte(flash: flash, grand: true)
            Button {
                dismiss()
            } label: {
                Text("Tourner la page")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .background(Theme.fond.ignoresSafeArea())
    }
}

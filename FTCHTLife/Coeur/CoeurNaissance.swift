import SwiftUI

// Fenêtre de naissance : quand un bébé naît pendant le passage d'année, le joueur choisit son prénom.
// Les bébés en attente sont dans `CoeurEtat.bebesANommer` (rempli par VieRelations.naissanceBebe).
// Le mode rapide s'arrête dès qu'un bébé attend son prénom.

extension GameEngine {
    /// Le prochain bébé à nommer (nil s'il n'y en a pas, ou si un événement attend une réponse).
    var bebeANommer: Relation? {
        guard let j = joueur, j.vivant else { return nil }
        for id in j.coeurEtat.bebesANommer {
            if let r = j.relations.first(where: { $0.id == id && $0.type == .enfant }) { return r }
        }
        return nil
    }

    /// Donne son prénom au bébé, écrit la ligne du journal et le retire de la file.
    func nommerBebe(_ id: UUID, prenom: String, parQui: String? = nil) {
        modifier { j in
            var c = j.coeurEtat
            c.bebesANommer.removeAll { $0 == id }
            j.coeurEtat = c
            let p = prenom.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let i = j.relations.firstIndex(where: { $0.id == id }), !p.isEmpty else { return }
            j.relations[i].prenom = p
            let r = j.relations[i]
            let accord = r.genre == .femme ? "appelée" : "appelé"
            if let qui = parQui {
                ajouterLigne(&j, "\(qui) a choisi le prénom : \(r.genre == .femme ? "elle" : "il") s'appelle \(p) \(r.nom). Bienvenue !")
            } else {
                ajouterLigne(&j, "Tu l'as \(accord) \(p) \(r.nom). Bienvenue, \(p) !")
            }
        }
    }

    /// Retire de la file les bébés qui n'existent plus (sauvegarde ancienne, enfant parti…).
    func nettoyerBebesANommer() {
        guard let j = joueur, !j.coeurEtat.bebesANommer.isEmpty, bebeANommer == nil else { return }
        modifier { j in
            var c = j.coeurEtat
            c.bebesANommer = []
            j.coeurEtat = c
        }
    }
}

/// Petit habillage pour la feuille (identifiée par le bébé).
struct BebeANommer: Identifiable, Equatable {
    let relation: Relation
    var id: UUID { relation.id }
}

private struct NaissanceBebeHote: ViewModifier {
    @EnvironmentObject var engine: GameEngine

    func body(content: Content) -> some View {
        content
            .sheet(item: Binding(
                get: { engine.evenementEnCours == nil && engine.flashMonde == nil ? engine.bebeANommer.map(BebeANommer.init) : nil },
                set: { _ in })) { b in
                NaissanceBebeView(bebe: b.relation)
                    .environmentObject(engine)
                    .interactiveDismissDisabled()
                    .presentationDetents([.large])
            }
            .onAppear { engine.nettoyerBebesANommer() }
    }
}

extension View {
    /// À placer sur MainView : ouvre la fenêtre de naissance dès qu'un bébé attend son prénom.
    func naissanceBebe() -> some View { modifier(NaissanceBebeHote()) }
}

/// « C'est une fille ! » : choisir le prénom du bébé.
struct NaissanceBebeView: View {
    @EnvironmentObject var engine: GameEngine
    let bebe: Relation
    @State private var prenom = ""
    @State private var idees: [String] = []
    @FocusState private var clavier: Bool

    private var fille: Bool { bebe.genre == .femme }
    private var couleur: Color { fille ? Color(red: 0.93, green: 0.36, blue: 0.58) : Color(red: 0.20, green: 0.50, blue: 0.90) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("👶")
                    .font(.system(size: 76))
                    .padding(.top, 26)
                Text(fille ? "C'est une fille !" : "C'est un garçon !")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(couleur)
                Text(sousTitre)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Son prénom")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Écris un prénom", text: $prenom)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($clavier)
                            .submitLabel(.done)
                            .onSubmit { valider() }
                        Text(bebe.nom)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.carte))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(couleur.opacity(0.5), lineWidth: 2))
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Des idées")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            nouvellesIdees()
                        } label: {
                            Label("Autres idées", systemImage: "dice.fill")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .tint(couleur)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(idees, id: \.self) { n in
                            Button {
                                prenom = n
                            } label: {
                                Text(n)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(prenom == n ? couleur.opacity(0.22) : Color.black.opacity(0.05)))
                                    .foregroundStyle(prenom == n ? couleur : Theme.encre)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Button {
                    valider()
                } label: {
                    Text(prenomPropre.isEmpty ? "Choisis un prénom" : "Bienvenue, \(prenomPropre) !")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(couleur)
                .disabled(prenomPropre.isEmpty)
                .padding(.horizontal, 20)
                .padding(.top, 4)

                if let p = autreParent {
                    Button("Laisser \(p) choisir") {
                        engine.nommerBebe(bebe.id, prenom: idees.first ?? VieDonnees.prenom(bebe.genre), parQui: p)
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tint(.secondary)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Theme.fond.ignoresSafeArea())
        .onAppear {
            if idees.isEmpty { nouvellesIdees() }
            if prenom.isEmpty { prenom = idees.first ?? "" }
        }
    }

    private var prenomPropre: String { prenom.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var autreParent: String? {
        guard let j = engine.joueur else { return nil }
        return j.partenaireActuel?.prenom
    }

    private var sousTitre: String {
        guard let j = engine.joueur else { return "" }
        let aines = j.enfantsVivants.filter { $0.id != bebe.id && !j.coeurEtat.bebesANommer.contains($0.id) }
        var t = fille ? "Elle est née cette année" : "Il est né cette année"
        if let p = autreParent { t += ", et \(p) ne \(fille ? "la" : "le") lâche plus des yeux" }
        t += "."
        if aines.count == 1, let a = aines.first {
            t += " \(a.prenom) découvre \(fille ? "sa petite sœur" : "son petit frère")."
        } else if aines.count > 1 {
            t += " Ses \(aines.count) frères et sœurs se pressent autour du berceau."
        }
        return t
    }

    private func nouvellesIdees() {
        var vus = Set<String>()
        var liste: [String] = []
        var essais = 0
        while liste.count < 6 && essais < 40 {
            let n = VieDonnees.prenom(bebe.genre)
            if vus.insert(n).inserted { liste.append(n) }
            essais += 1
        }
        idees = liste
    }

    private func valider() {
        guard !prenomPropre.isEmpty else { return }
        clavier = false
        engine.nommerBebe(bebe.id, prenom: String(prenomPropre.prefix(30)))
    }
}

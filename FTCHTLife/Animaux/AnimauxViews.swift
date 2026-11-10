import SwiftUI

// Écrans des animaux de compagnie. À ouvrir depuis MainView : `AnimauxView(cle: \.animaux)`.

/// Liste des animaux du joueur, adoption et animaux disparus.
struct AnimauxView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let cle: GameEngine.CleAnimaux

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let etat = engine.etatAnimaux(cle)
                    let titreAdoption: String = j.age < 18 ? "Adopter (avec l'accord des parents)" : "Adopter"
                    if etat.animaux.isEmpty {
                        Section {
                            Text(texteVide(j)).foregroundStyle(.secondary)
                        }
                    } else {
                        Section {
                            ForEach(etat.animaux) { a in
                                NavigationLink {
                                    AnimalDetailView(animalId: a.id, cle: cle)
                                } label: {
                                    LigneAnimal(animal: a)
                                }
                            }
                        } header: {
                            Text("Tes animaux")
                        } footer: {
                            if j.age >= 18 {
                                Text("Entretien : \(Format.argent(etat.coutAnnuel)) par an.")
                            } else {
                                Text("Tes parents paient les croquettes. Pour l'instant.")
                            }
                        }
                    }

                    Section(titreAdoption) {
                        ForEach(SourceAdoption.allCases) { s in
                            NavigationLink {
                                AdoptionView(source: s, cle: cle)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: s.icone)
                                        .foregroundStyle(engine.sourceDisponible(s) ? Theme.accent : .gray)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.titre).foregroundStyle(engine.sourceDisponible(s) ? Theme.encre : .gray)
                                        Text(s.description).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(!engine.sourceDisponible(s) || etat.animaux.count >= Animaux.maxAnimaux)
                        }
                    }

                    if !etat.disparus.isEmpty {
                        Section("Au paradis des animaux") {
                            ForEach(Array(etat.disparus.reversed())) { a in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(a.emoji).font(.title2).grayscale(1).opacity(0.7)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(a.nom) · \(a.nomEspece)").font(.subheadline.weight(.semibold))
                                        Text(a.depart ?? "Parti\(a.accord("", "e"))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Animaux")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }

    private func texteVide(_ j: Joueur) -> String {
        if j.age < Animaux.ageMinimal {
            return "Tu es trop petit" + j.g("", "e") + " pour avoir un animal. Pour l'instant, l'animal de la maison, c'est toi."
        }
        return "Aucun animal à la maison. Ton canapé est intact, mais ta vie est vide."
    }
}

/// Une ligne de la liste : emoji, nom, espèce, âge, caractère, lien et santé.
struct LigneAnimal: View {
    let animal: Animal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(animal.emoji).font(.system(size: 34))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(animal.nom).font(.headline)
                    Spacer()
                    Text("\(animal.nomEspece) · \(animal.age) an\(animal.age > 1 ? "s" : "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let c = animal.caractere {
                    Text("\(c.emoji) \(c.nom)\(animal.maladie != nil ? " · malade" : "")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(animal.maladie != nil ? .red : Theme.accent)
                }
                BarreStat(titre: "Lien", icone: "heart.fill", valeur: animal.lien)
                BarreStat(titre: "Santé", icone: "cross.fill", valeur: animal.sante)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Fiche d'un animal

struct AnimalDetailView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let animalId: UUID
    let cle: GameEngine.CleAnimaux
    @State private var message: String?
    @State private var confirmerAbandon = false

    private var animal: Animal? { engine.etatAnimaux(cle).animaux.first { $0.id == animalId } }

    var body: some View {
        List {
            if let a = animal {
                Section {
                    HStack(spacing: 16) {
                        Text(a.emoji).font(.system(size: 56))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(a.nom).font(.title2.weight(.bold))
                            Text("\(a.nomEspece) · \(a.accord("mâle", "femelle")) · \(a.age) an\(a.age > 1 ? "s" : "")")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if let e = a.espece {
                                Text(e.description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    BarreStat(titre: "Lien", icone: "heart.fill", valeur: a.lien)
                    BarreStat(titre: "Santé", icone: "cross.fill", valeur: a.sante)
                    if let m = a.maladie {
                        Label("Malade : \(m)", systemImage: "thermometer.medium")
                            .font(.subheadline).foregroundStyle(.red)
                    }
                }
                if let c = a.caractere {
                    Section("Caractère") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(c.emoji) \(c.nom)").font(.headline)
                            Text(c.description).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Actions") {
                    ForEach(engine.actionsAnimal(a)) { action in
                        LigneAction(titre: action.titre,
                                    sousTitre: action.cout > 0 && (engine.joueur?.age ?? 0) >= 18 ? Format.argent(action.cout) : nil,
                                    icone: action.icone,
                                    actif: engine.actionAnimalDisponible(action, a)) {
                            message = engine.agirAnimal(action, animalId: a.id, cle: cle)
                        }
                    }
                }
                Section {
                    Button("Abandonner \(a.nom)", role: .destructive) { confirmerAbandon = true }
                } footer: {
                    Text("Adopté\(a.accord("", "e")) quand tu avais \(a.adopteA) an\(a.adopteA > 1 ? "s" : "").")
                }
            } else {
                Text("Cet animal n'est plus là.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle(animal?.nom ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Abandonner \(animal?.nom ?? "cet animal") ? Ton karma va le sentir passer.",
                            isPresented: $confirmerAbandon, titleVisibility: .visible) {
            Button("Abandonner", role: .destructive) {
                message = engine.abandonnerAnimal(animalId, cle: cle)
            }
        }
        .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

// MARK: - Adoption

struct AdoptionView: View {
    @EnvironmentObject var engine: GameEngine
    let source: SourceAdoption
    let cle: GameEngine.CleAnimaux
    @State private var offres: [OffreAnimal] = []
    @State private var choisie: OffreAnimal?
    @State private var nom = ""
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Text(source.description).font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                ForEach(offres) { o in
                    Button {
                        nom = o.animal.nom
                        choisie = o
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text(o.animal.emoji).font(.system(size: 34))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(source == .refuge ? o.animal.nom : o.animal.nomEspece)
                                        .font(.headline).foregroundStyle(Theme.encre)
                                    Spacer()
                                    Text(prixAffiche(o)).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accent)
                                }
                                Text(sousTitre(o)).font(.caption).foregroundStyle(.secondary)
                                if o.caractereVisible, let c = o.animal.caractere {
                                    Text("\(c.emoji) \(c.nom) : \(c.description)")
                                        .font(.caption).foregroundStyle(Theme.encre)
                                } else {
                                    Text("❓ Caractère : surprise").font(.caption).foregroundStyle(Theme.encre)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(source.titre)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if offres.isEmpty { offres = engine.offresAdoption(source) } }
        .alert("Comment va-t-il s'appeler ?", isPresented: Binding(get: { choisie != nil }, set: { if !$0 { choisie = nil } })) {
            TextField("Nom", text: $nom)
            Button("Adopter") {
                if let o = choisie {
                    let resultat = engine.adopter(o, nom: nom, cle: cle)
                    if engine.etatAnimaux(cle).animaux.contains(where: { $0.id == o.animal.id }) {
                        offres.removeAll { $0.id == o.id }
                    }
                    choisie = nil
                    message = resultat
                }
            }
            Button("Annuler", role: .cancel) { choisie = nil }
        } message: {
            if let o = choisie {
                Text("\(o.animal.emoji) \(o.animal.nomEspece), \(o.animal.age) an\(o.animal.age > 1 ? "s" : "") · \(prixAffiche(o))")
            }
        }
        .background {
            Color.clear
                .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                    Button("OK") { message = nil }
                } message: {
                    Text(message ?? "")
                }
        }
    }

    private func prixAffiche(_ o: OffreAnimal) -> String {
        guard let j = engine.joueur, j.age >= 18 else { return "Parents" }
        return o.prix > 0 ? Format.argent(o.prix) : "Gratuit"
    }

    private func sousTitre(_ o: OffreAnimal) -> String {
        let a = o.animal
        let age = a.age == 0 ? "bébé" : "\(a.age) an\(a.age > 1 ? "s" : "")"
        let entretien = a.espece.map { " · entretien \(Format.argent($0.entretien))/an" } ?? ""
        return (source == .refuge ? "\(a.nomEspece) · " : "") + "\(a.accord("mâle", "femelle")) · \(age)" + entretien
    }
}

// MARK: - Événements d'animaux à choix

/// Carte d'un événement d'animal (même présentation que les événements du moteur).
struct AnimalEvenementView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let attente: AnimalEvenementEnAttente
    let cle: GameEngine.CleAnimaux

    /// Version à jour (le résultat s'ajoute après le choix).
    private var courant: AnimalEvenementEnAttente { engine.evenementAnimalEnAttente(attente.id, cle: cle) ?? attente }

    var body: some View {
        let aff = courant
        let etat = engine.etatAnimaux(cle)
        let animal: Animal? = etat.animaux.first(where: { $0.id == aff.animalId })
            ?? etat.disparus.first(where: { $0.id == aff.animalId })
        return VStack(spacing: 18) {
            Text(animal?.emoji ?? "🐾")
                .font(.system(size: 44))
                .padding(.top, 24)
            Text(aff.texte)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let resultat = aff.resultat {
                Text(resultat)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.fond, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                Spacer()
                bouton("OK") { fermer() }
            } else if let choix = Animaux.evenement(aff.evenementId)?.choices, !choix.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    ForEach(Array(choix.enumerated()), id: \.offset) { i, c in
                        bouton(engine.libelleChoixAnimal(c.label, animalId: aff.animalId, cle: cle)) { engine.choisirAnimal(aff.id, choix: i, cle: cle) }
                    }
                }
            } else {
                Spacer()
                bouton("OK") { fermer() }
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.carte)
    }

    private func fermer() {
        engine.fermerEvenementAnimal(attente.id, cle: cle)
        dismiss()
    }

    private func bouton(_ titre: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titre)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
        .padding(.horizontal)
    }
}

/// Affiche les événements d'animaux en attente, un par un, quand aucun événement du moteur n'est ouvert.
/// Vue invisible posée en fond de MainView par `.animauxEvenements(cle:)`.
struct AnimauxEvenementsHote: View {
    @EnvironmentObject var engine: GameEngine
    let cle: GameEngine.CleAnimaux
    @State private var courant: AnimalEvenementEnAttente?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .sheet(item: $courant, onDismiss: { planifier() }) { attente in
                AnimalEvenementView(attente: attente, cle: cle)
                    .environmentObject(engine)
                    .interactiveDismissDisabled()
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: signature) { _ in planifier() }
            .onAppear { planifier() }
    }

    /// Change quand un événement du moteur s'ouvre ou se ferme, ou quand la file des animaux change.
    private var signature: String {
        let moteur = engine.evenementEnCours?.id.uuidString ?? "-"
        let file = engine.etatAnimaux(cle).enAttente.map { $0.id.uuidString }.joined(separator: ",")
        return moteur + "|" + file
    }

    /// Attend la fin des animations des autres feuilles avant d'en ouvrir une.
    private func planifier() {
        guard courant == nil else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            if courant == nil, let prochain = engine.prochainEvenementAnimal(cle) {
                courant = prochain
            }
        }
    }
}

extension View {
    /// À placer sur MainView, après le `.sheet` des événements : `.animauxEvenements(cle: \.animaux)`.
    func animauxEvenements(cle: GameEngine.CleAnimaux) -> some View {
        background(AnimauxEvenementsHote(cle: cle))
    }
}

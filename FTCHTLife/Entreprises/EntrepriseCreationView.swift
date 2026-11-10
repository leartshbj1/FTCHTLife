import SwiftUI

/// Choix du type d'entreprise, par secteur.
struct EntrepriseCreationView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let surCreation: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                if EntrepriseCatalogue.types.isEmpty {
                    Text("Aucun type d'entreprise n'est disponible pour l'instant.")
                }
                if let j = engine.joueur {
                    ForEach(EntrepriseCatalogue.ordreSecteurs, id: \.self) { secteur in
                        let types = EntrepriseCatalogue.types.filter { $0.secteur == secteur }
                        if !types.isEmpty {
                            Section(EntrepriseCatalogue.nomSecteur(secteur)) {
                                ForEach(types) { t in
                                    NavigationLink {
                                        EntrepriseFondationView(type: t, surCreation: surCreation)
                                    } label: {
                                        LigneTypeEntreprise(type: t, blocage: EntrepriseMoteur.blocageCreation(t, j))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fonder une entreprise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
    }
}

struct LigneTypeEntreprise: View {
    let type: EntrepriseType
    let blocage: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icone)
                .font(.system(size: 20))
                .foregroundStyle(blocage == nil ? Theme.accent : .gray)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(type.nom).foregroundStyle(blocage == nil ? Theme.encre : .gray)
                Text(type.description).font(.caption).foregroundStyle(.secondary)
                Text(blocage ?? "Mise de départ : \(Format.argent(type.coutCreation))")
                    .font(.caption2)
                    .foregroundStyle(blocage == nil ? Color.secondary : Color.red)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Nom, financement et signature.
struct EntrepriseFondationView: View {
    @EnvironmentObject var engine: GameEngine
    let type: EntrepriseType
    let surCreation: (String) -> Void
    @State private var nom = ""
    @State private var emprunt = true

    var body: some View {
        List {
            if let j = engine.joueur {
                let apport = emprunt ? Int(Double(type.coutCreation) * EntrepriseMoteur.apportMinimum) : type.coutCreation
                let blocage = EntrepriseMoteur.blocageCreation(type, j)
                    ?? (j.argent < apport ? "Il te faut \(Format.argent(apport)) d'apport. Tu as \(Format.argent(j.argent))." : nil)

                Section {
                    HStack(spacing: 14) {
                        Image(systemName: type.icone)
                            .font(.system(size: 30))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(type.nom).font(.title3.bold())
                            Text(type.description).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    ligne("Mise de départ", Format.argent(type.coutCreation))
                    ligne("Ventes espérées la 1re année", "≈ " + Format.argent(type.chiffreAffairesBase))
                    ligne("Risque", texteRisque)
                }

                Section("Nom de la boîte") {
                    TextField("Ex. \(type.nomsSuggeres.first ?? "Ma Super Boîte")", text: $nom)
                    Button("Une idée de nom, vite") {
                        nom = type.nomsSuggeres.filter { $0 != nom }.randomElement() ?? nom
                    }
                }

                Section {
                    Toggle("Emprunter 70 % à la banque", isOn: $emprunt)
                    ligne("Tu paies maintenant", Format.argent(apport))
                    if emprunt {
                        ligne("Prêt (8 ans, 6 %)", Format.argent(type.coutCreation - apport))
                    }
                } header: {
                    Text("Financement")
                } footer: {
                    Text("Le prêt est remboursé par la boîte chaque année. Si elle coule, tu paies la moitié du trou.")
                }

                Section {
                    Button {
                        surCreation(engine.creerEntreprise(type, nom: nom, emprunt: emprunt))
                    } label: {
                        Text("Signer et fonder « \(nomAffiche) »")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(blocage != nil)
                    if let b = blocage {
                        Text(b).font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(type.nom)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if nom.isEmpty { nom = type.nomsSuggeres.randomElement() ?? "" }
        }
    }

    private var nomAffiche: String {
        let n = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? type.nom : n
    }

    private var texteRisque: String {
        switch type.volatilite {
        case ..<0.2: return "Tranquille"
        case ..<0.35: return "Normal"
        case ..<0.5: return "Montagnes russes"
        default: return "Casino"
        }
    }

    private func ligne(_ titre: String, _ valeur: String) -> some View {
        HStack {
            Text(titre)
            Spacer()
            Text(valeur).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

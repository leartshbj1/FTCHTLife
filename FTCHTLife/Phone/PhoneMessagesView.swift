import SwiftUI

/// Liste des messages reçus.
@MainActor
struct PhoneMessagesView: View {
    @EnvironmentObject var engine: GameEngine
    let chemin: PhoneChemin

    var body: some View {
        List {
            if let j = engine.joueur {
                let t = j[keyPath: chemin] ?? PhoneEtat()
                if t.messages.isEmpty {
                    Text("Aucun message. Même pas une arnaque. C'est presque vexant.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(t.messages.reversed())) { m in
                    NavigationLink(value: PhoneEcran.message(m.id)) {
                        ligne(m)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            engine.telephoneModifier(chemin) { _, t in
                                PhoneEngine.supprimerMessage(m.id, &t)
                            }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Tout lire") {
                    engine.telephoneModifier(chemin) { _, t in
                        PhoneEngine.toutMarquerLu(&t)
                    }
                }
            }
        }
    }

    private func ligne(_ m: PhoneMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(m.lu ? Color.clear : Color.blue)
                .frame(width: 9, height: 9)
                .padding(.top, 6)
            ZStack {
                Circle().fill(PhoneMessageStyle.couleur(m).opacity(0.18))
                Image(systemName: PhoneMessageStyle.icone(m))
                    .foregroundStyle(PhoneMessageStyle.couleur(m))
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(m.expediteur)
                        .font(.subheadline.weight(m.lu ? .regular : .bold))
                        .lineLimit(1)
                    Spacer()
                    Text("\(m.age) ans")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(m.texte)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if m.reponse == nil && !PhoneEngine.choix(m).isEmpty && m.lu {
                    Text("En attente de ta réponse")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

enum PhoneMessageStyle {
    static func icone(_ m: PhoneMessage) -> String {
        if m.sponsorId != nil { return "dollarsign.circle.fill" }
        switch m.categorie {
        case "arnaque": return "exclamationmark.triangle.fill"
        case "famille": return "house.fill"
        case "hater": return "hand.thumbsdown.fill"
        case "fan": return "star.fill"
        case "crush": return "heart.fill"
        case "ami": return "person.2.fill"
        case "pro": return "briefcase.fill"
        default: return "questionmark.bubble.fill"
        }
    }

    static func couleur(_ m: PhoneMessage) -> Color {
        if m.sponsorId != nil { return Color(red: 0.85, green: 0.65, blue: 0.10) }
        switch m.categorie {
        case "arnaque": return .orange
        case "famille": return .green
        case "hater": return .red
        case "fan": return .yellow
        case "crush": return .pink
        case "ami": return .blue
        case "pro": return .indigo
        default: return .purple
        }
    }
}

/// Une conversation : le message, les réponses possibles et le résultat.
@MainActor
struct PhoneConversationView: View {
    @EnvironmentObject var engine: GameEngine
    let id: UUID
    let chemin: PhoneChemin

    var body: some View {
        Group {
            if let j = engine.joueur, let m = (j[keyPath: chemin] ?? PhoneEtat()).messages.first(where: { $0.id == id }) {
                conversation(m)
            } else {
                Text("Ce message a disparu. Comme ton dernier crush.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            engine.telephoneModifier(chemin) { _, t in
                PhoneEngine.marquerLu(id, &t)
            }
        }
    }

    private func conversation(_ m: PhoneMessage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if m.sponsorId != nil {
                    Label("Proposition de partenariat", systemImage: "dollarsign.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(PhoneMessageStyle.couleur(m))
                }
                bulle(m.texte, entrant: true)
                if let choix = m.choixFait {
                    bulle(choix, entrant: false)
                }
                if let reponse = m.reponse {
                    Text(reponse)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                } else {
                    let options = PhoneEngine.choix(m)
                    VStack(spacing: 8) {
                        ForEach(Array(options.enumerated()), id: \.offset) { index, label in
                            Button {
                                engine.telephoneModifier(chemin) { j, t in
                                    PhoneEngine.repondre(m.id, choix: index, &j, &t, engine: engine)
                                }
                            } label: {
                                Text(label)
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.12)))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .padding()
        }
        .navigationTitle(m.expediteur)
    }

    private func bulle(_ texte: String, entrant: Bool) -> some View {
        HStack {
            if !entrant { Spacer(minLength: 50) }
            Text(texte)
                .font(.subheadline)
                .foregroundStyle(entrant ? Theme.encre : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(entrant ? Color(uiColor: .secondarySystemBackground) : PhoneCouleurs.messages)
                )
                .fixedSize(horizontal: false, vertical: true)
            if entrant { Spacer(minLength: 50) }
        }
    }
}

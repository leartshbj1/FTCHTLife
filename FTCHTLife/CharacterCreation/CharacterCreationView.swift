import SwiftUI

/// Écran de création de personnage en 5 étapes.
/// Usage : `CharacterCreationView { draft in engine.startNewLife(from: draft) }`
struct CharacterCreationView: View {
    var catalog: CreationCatalog = .shared
    var onCancel: (() -> Void)? = nil
    let onComplete: (CharacterDraft) -> Void

    @State private var draft: CharacterDraft
    @State private var step: Step = .identity
    @State private var rerollsLeft = 3

    init(catalog: CreationCatalog = .shared,
         onCancel: (() -> Void)? = nil,
         onComplete: @escaping (CharacterDraft) -> Void) {
        self.catalog = catalog
        self.onCancel = onCancel
        self.onComplete = onComplete
        _draft = State(initialValue: CharacterDraft.random(catalog: catalog))
    }

    enum Step: Int, CaseIterable {
        case identity, origin, looks, personality, summary

        var title: String {
            switch self {
            case .identity: return "Qui es-tu ?"
            case .origin: return "D'où tu viens ?"
            case .looks: return "Ta tête"
            case .personality: return "Ton caractère"
            case .summary: return "Prêt à naître ?"
            }
        }
    }

    private var country: CreationCountry? { catalog.country(draft.countryID) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch step {
                    case .identity: identityStep
                    case .origin: originStep
                    case .looks: looksStep
                    case .personality: personalityStep
                    case .summary: summaryStep
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            footer
        }
        .background(CreationPalette.background.ignoresSafeArea())
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: step)
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                if let onCancel {
                    Button("Annuler", action: onCancel).foregroundStyle(CreationPalette.muted)
                }
                Spacer()
                Button {
                    withAnimation { randomizeAll() }
                } label: {
                    Label("Tout au hasard", systemImage: "dice.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(CreationPalette.accent)
            }

            AvatarPersoView(appearance: draft.appearance, age: 25, size: 110)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            Text(draft.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? "Sans nom" : draft.fullName)
                .font(.title2.weight(.heavy))
                .foregroundStyle(CreationPalette.ink)
            if let country {
                Text("\(country.flag) \(draft.city), \(country.name)")
                    .font(.subheadline)
                    .foregroundStyle(CreationPalette.muted)
            }

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? CreationPalette.accent : CreationPalette.muted.opacity(0.25))
                        .frame(height: 5)
                }
            }
            Text(step.title)
                .font(.headline)
                .foregroundStyle(CreationPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(CreationPalette.card)
    }

    // MARK: - Pied de page

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .identity {
                Button {
                    goTo(step.rawValue - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(.bordered)
                .tint(CreationPalette.ink)
            }
            Button {
                if step == .summary {
                    draft.firstName = draft.firstName.trimmingCharacters(in: .whitespaces)
                    draft.lastName = draft.lastName.trimmingCharacters(in: .whitespaces)
                    onComplete(draft)
                } else {
                    goTo(step.rawValue + 1)
                }
            } label: {
                Text(step == .summary ? "Naître !" : "Suivant")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(CreationPalette.accent)
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(CreationPalette.card)
    }

    private var canAdvance: Bool {
        switch step {
        case .identity:
            return !draft.firstName.trimmingCharacters(in: .whitespaces).isEmpty
                && !draft.lastName.trimmingCharacters(in: .whitespaces).isEmpty
        case .summary:
            return draft.isValid
        default:
            return true
        }
    }

    private func goTo(_ raw: Int) {
        if let s = Step(rawValue: raw) { step = s }
    }

    // MARK: - Étape 1 : identité

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("Prénom") {
                HStack {
                    TextField("Prénom", text: $draft.firstName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .modifier(FieldStyle())
                    diceButton {
                        if let country {
                            var rng = SystemRandomNumberGenerator()
                            draft.firstName = country.randomFirstName(for: draft.gender, using: &rng)
                        }
                    }
                }
            }
            section("Nom de famille") {
                HStack {
                    TextField("Nom", text: $draft.lastName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .modifier(FieldStyle())
                    diceButton {
                        draft.lastName = country?.lastNames.randomElement() ?? draft.lastName
                    }
                }
            }
            section("Genre") {
                HStack(spacing: 10) {
                    ForEach(CreationGender.allCases) { g in
                        ChoiceChip(title: "\(g.symbol) \(g.label)", selected: draft.gender == g) {
                            draft.gender = g
                        }
                    }
                }
            }
            Text("Astuce : le dé 🎲 propose un prénom typique de ton pays.")
                .font(.footnote)
                .foregroundStyle(CreationPalette.muted)
        }
    }

    // MARK: - Étape 2 : origine

    private var originStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("Pays") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(catalog.countries) { c in
                        Button {
                            selectCountry(c)
                        } label: {
                            VStack(spacing: 4) {
                                Text(c.flag).font(.largeTitle)
                                Text(c.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, minHeight: 74)
                            .background(draft.countryID == c.id ? CreationPalette.accent.opacity(0.18) : CreationPalette.card)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(draft.countryID == c.id ? CreationPalette.accent : Color.clear, lineWidth: 2))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(CreationPalette.ink)
                    }
                }
            }
            if let country {
                section("Ville") {
                    FlowChips(items: country.cities, selected: draft.city) { draft.city = $0 }
                }
            }
            section("Ta famille est…") {
                VStack(spacing: 8) {
                    ForEach(CreationWealth.allCases) { w in
                        Button {
                            draft.wealth = w
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.label).font(.subheadline.weight(.bold))
                                    Text(w.blurb).font(.caption).foregroundStyle(CreationPalette.muted)
                                }
                                Spacer()
                                if draft.wealth == w {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(CreationPalette.accent)
                                }
                            }
                            .padding(12)
                            .background(CreationPalette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(CreationPalette.ink)
                    }
                }
            }
        }
    }

    private func selectCountry(_ c: CreationCountry) {
        guard c.id != draft.countryID else { return }
        draft.countryID = c.id
        var rng = SystemRandomNumberGenerator()
        draft.city = c.cities.first ?? c.name
        // On propose un nom adapté au pays, l'utilisateur peut toujours le changer.
        draft.firstName = c.randomFirstName(for: draft.gender, using: &rng)
        draft.lastName = c.lastNames.randomElement(using: &rng) ?? draft.lastName
    }

    // MARK: - Étape 3 : apparence

    private var looksStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("Peau") {
                HStack(spacing: 10) {
                    ForEach(CreationSkinTone.allCases) { t in
                        Swatch(color: t.color, selected: draft.appearance.skin == t) { draft.appearance.skin = t }
                    }
                }
            }
            section("Coiffure") {
                FlowChips(items: CreationHairStyle.allCases.map(\.label),
                          selected: draft.appearance.hairStyle.label) { label in
                    if let h = CreationHairStyle.allCases.first(where: { $0.label == label }) { draft.appearance.hairStyle = h }
                }
            }
            section("Couleur des cheveux") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
                    ForEach(CreationHairColor.allCases) { h in
                        Swatch(color: h.color, selected: draft.appearance.hairColor == h) { draft.appearance.hairColor = h }
                            .accessibilityLabel(h.label)
                    }
                }
            }
            section("Yeux") {
                HStack(spacing: 10) {
                    ForEach(CreationEyeColor.allCases) { e in
                        Swatch(color: e.color, selected: draft.appearance.eyes == e) { draft.appearance.eyes = e }
                            .accessibilityLabel(e.label)
                    }
                }
            }
            VStack(spacing: 0) {
                Toggle("Taches de rousseur", isOn: $draft.appearance.hasFreckles).padding(12)
                Divider()
                Toggle("Lunettes", isOn: $draft.appearance.hasGlasses).padding(12)
            }
            .tint(CreationPalette.accent)
            .background(CreationPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Étape 4 : caractère

    private var personalityStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("Traits (\(draft.traitIDs.count)/\(CharacterDraft.maxTraits))") {
                VStack(spacing: 8) {
                    ForEach(catalog.traits) { t in
                        let selected = draft.traitIDs.contains(t.id)
                        let blocked = !selected && (catalog.conflicts(t.id, with: draft.traitIDs)
                                                    || draft.traitIDs.count >= CharacterDraft.maxTraits)
                        TraitRow(emoji: t.emoji, name: t.name, description: t.description,
                                 modifiers: t.modifiers, selected: selected, disabled: blocked) {
                            toggleTrait(t.id)
                        }
                    }
                }
            }
            section("CreationTalent inné") {
                VStack(spacing: 8) {
                    ForEach(catalog.talents) { t in
                        TraitRow(emoji: t.emoji, name: t.name, description: t.description,
                                 modifiers: t.modifiers, selected: draft.talentID == t.id, disabled: false) {
                            draft.talentID = t.id
                        }
                    }
                }
            }
        }
    }

    private func toggleTrait(_ id: String) {
        if let i = draft.traitIDs.firstIndex(of: id) {
            draft.traitIDs.remove(at: i)
        } else if draft.traitIDs.count < CharacterDraft.maxTraits, !catalog.conflicts(id, with: draft.traitIDs) {
            draft.traitIDs.append(id)
        }
    }

    // MARK: - Étape 5 : récap

    private var summaryStep: some View {
        let stats = draft.finalStats(catalog: catalog)
        return VStack(alignment: .leading, spacing: 22) {
            section("Tes gènes") {
                VStack(spacing: 10) {
                    StatBar(label: "Santé", icon: "heart.fill", value: stats.health, color: .red)
                    StatBar(label: "Bonheur", icon: "face.smiling.fill", value: stats.happiness, color: .orange)
                    StatBar(label: "Intelligence", icon: "brain.head.profile", value: stats.smarts, color: .blue)
                    StatBar(label: "Apparence", icon: "sparkles", value: stats.looks, color: .pink)
                }
                .padding(14)
                .background(CreationPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    withAnimation {
                        var rng = SystemRandomNumberGenerator()
                        draft.baseStats = CharacterDraft.randomStats(using: &rng)
                        rerollsLeft -= 1
                    }
                } label: {
                    Label(rerollsLeft > 0 ? "Relancer la génétique (\(rerollsLeft))" : "La génétique a parlé",
                          systemImage: "dice")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(CreationPalette.accent)
                .disabled(rerollsLeft <= 0)
            }

            section("Résumé") {
                VStack(alignment: .leading, spacing: 6) {
                    summaryLine("Genre", draft.gender.label)
                    summaryLine("Famille", "\(draft.wealth.label) (\(formatMoney(draft.wealth.familyMoney)))")
                    summaryLine("Traits", draft.traitIDs.compactMap { catalog.trait($0) }
                        .map { "\($0.emoji) \($0.name)" }.joined(separator: ", ").ifEmpty("Aucun"))
                    summaryLine("CreationTalent", draft.talentID.flatMap { catalog.talent($0) }
                        .map { "\($0.emoji) \($0.name)" } ?? "Aucun")
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CreationPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func summaryLine(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(.subheadline).foregroundStyle(CreationPalette.muted).frame(width: 70, alignment: .leading)
            Text(v).font(.subheadline.weight(.semibold)).foregroundStyle(CreationPalette.ink)
        }
    }

    private func formatMoney(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        let n = f.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(n) \(country?.currency ?? "€")"
    }

    // MARK: - Helpers

    private func randomizeAll() {
        draft = CharacterDraft.random(catalog: catalog)
        rerollsLeft = 3
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(CreationPalette.muted)
                .tracking(0.8)
            content()
        }
    }

    private func diceButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "dice.fill")
                .font(.title3)
                .frame(width: 48, height: 48)
                .background(CreationPalette.accent.opacity(0.15))
                .foregroundStyle(CreationPalette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("Au hasard")
    }
}

// MARK: - CreationPalette

/// CreationPalette propre à FTCHTLife : crème + corail, loin du look des autres jeux du genre.
enum CreationPalette {
    static let background = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let card = Color.white
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.16)
    static let muted = Color(red: 0.45, green: 0.43, blue: 0.48)
    static let accent = Color(red: 0.95, green: 0.38, blue: 0.30)
}

// MARK: - Composants

private struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(CreationPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(CreationPalette.ink)
    }
}

private struct ChoiceChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? CreationPalette.accent : CreationPalette.card)
                .foregroundStyle(selected ? Color.white : CreationPalette.ink)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct FlowChips: View {
    let items: [String]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                ChoiceChip(title: item, selected: item == selected) { onSelect(item) }
            }
        }
    }
}

private struct Swatch: View {
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .overlay(Circle().stroke(selected ? CreationPalette.accent : Color.black.opacity(0.1), lineWidth: selected ? 3 : 1).padding(-3))
        }
        .buttonStyle(.plain)
    }
}

private struct TraitRow: View {
    let emoji: String
    let name: String
    let description: String
    let modifiers: CreationStatModifiers
    let selected: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Text(emoji).font(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.subheadline.weight(.bold))
                    Text(description).font(.caption).foregroundStyle(CreationPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if !modifierText.isEmpty {
                        Text(modifierText).font(.caption2.weight(.semibold)).foregroundStyle(CreationPalette.accent)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? CreationPalette.accent : CreationPalette.muted.opacity(0.5))
            }
            .padding(12)
            .background(selected ? CreationPalette.accent.opacity(0.10) : CreationPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(CreationPalette.ink)
        .disabled(disabled)
    }

    private var modifierText: String {
        var parts: [String] = []
        func add(_ v: Int, _ label: String) {
            if v != 0 { parts.append("\(v > 0 ? "+" : "")\(v) \(label)") }
        }
        add(modifiers.health, "santé")
        add(modifiers.happiness, "bonheur")
        add(modifiers.smarts, "intelligence")
        add(modifiers.looks, "apparence")
        return parts.joined(separator: " · ")
    }
}

private struct StatBar: View {
    let label: String
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 22)
            Text(label).font(.subheadline).frame(width: 96, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 10)
            Text("\(value)%").font(.caption.monospacedDigit().weight(.bold)).frame(width: 40, alignment: .trailing)
        }
        .foregroundStyle(CreationPalette.ink)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

#if DEBUG
struct CharacterCreationView_Previews: PreviewProvider {
    static var previews: some View {
        CharacterCreationView { _ in }
    }
}
#endif

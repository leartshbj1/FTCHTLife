import SwiftUI

// Écrans prêts à brancher. Ils ne lisent que les données du module et renvoient
// les choix du joueur par des closures : le moteur applique les conséquences.

/// Liste des offres d'emploi, filtrable par type et par secteur, avec la raison du refus si le métier est fermé.
struct CareerJobBoardView: View {
    let profile: CareerProfile
    var engine = CareerEngine()
    let onApply: (CareerJob) -> Void

    @State private var kind: CareerKind? = nil
    @State private var sector: String? = nil
    @State private var search = ""
    @State private var onlyEligible = true

    init(profile: CareerProfile, engine: CareerEngine = CareerEngine(), onApply: @escaping (CareerJob) -> Void) {
        self.profile = profile
        self.engine = engine
        self.onApply = onApply
    }

    private var careers: [CareerJob] {
        engine.catalog.careers.filter { c in
            (kind == nil || c.kind == kind)
                && (sector == nil || c.sector == sector)
                && (search.isEmpty || c.name.localizedCaseInsensitiveContains(search)
                    || c.ladder.contains { $0.title.localizedCaseInsensitiveContains(search) })
                && (!onlyEligible || engine.eligibility(for: c, profile: profile).isEligible)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Type", selection: $kind) {
                    Text("Tous").tag(CareerKind?.none)
                    ForEach(CareerKind.allCases, id: \.self) { k in
                        Text(k.label).tag(CareerKind?.some(k))
                    }
                }
                Picker("Secteur", selection: $sector) {
                    Text("Tous").tag(String?.none)
                    ForEach(engine.catalog.sectors, id: \.self) { s in
                        Text(CareerSectors.label(s)).tag(String?.some(s))
                    }
                }
                Toggle("Seulement ceux qui me sont ouverts", isOn: $onlyEligible)
            }
            Section("\(careers.count) offre\(careers.count > 1 ? "s" : "")") {
                ForEach(careers) { c in
                    CareerOfferRow(career: c, eligibility: engine.eligibility(for: c, profile: profile),
                                   chance: engine.hiringChance(for: c, profile: profile), female: profile.isFemale) {
                        onApply(c)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Chercher un métier")
        .navigationTitle("Offres d'emploi")
    }
}

struct CareerOfferRow: View {
    let career: CareerJob
    let eligibility: CareerEngine.Eligibility
    let chance: Int
    var female = false
    let onApply: () -> Void
    @State private var expanded = false

    init(career: CareerJob, eligibility: CareerEngine.Eligibility, chance: Int, female: Bool = false, onApply: @escaping () -> Void) {
        self.career = career
        self.female = female
        self.eligibility = eligibility
        self.chance = chance
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation { expanded.toggle() } } label: {
                HStack {
                    Image(systemName: CareerSectors.icon(career.sector))
                        .foregroundStyle(eligibility.isEligible ? Color.accentColor : .gray)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(CareerText.resolveGender(career.name, female: female)).font(.headline)
                            .foregroundStyle(eligibility.isEligible ? .primary : .secondary)
                        Text("\(CareerEngine.euros(career.entrySalary))/an · \(career.requirements.education.label)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                if let d = career.description { Text(d).font(.subheadline).italic() }
                ForEach(Array(career.ladder.enumerated()), id: \.offset) { i, step in
                    HStack {
                        Text("\(i + 1). \(CareerText.resolveGender(step.title, female: female))").font(.caption)
                        Spacer()
                        Text(CareerEngine.euros(step.salary)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Label("Stress \(career.stress)", systemImage: "flame").font(.caption2)
                    Label("Prestige \(career.prestige)", systemImage: "star").font(.caption2)
                }
                .foregroundStyle(.secondary)
                switch eligibility {
                case .eligible:
                    Button(career.special?.audition == true ? "Passer l'audition (\(chance) %)" : "Postuler (\(chance) %)", action: onApply)
                        .buttonStyle(.borderedProminent)
                case .blocked(let reason):
                    Text(reason).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Section « Mon travail » : poste, entreprise, jauges et actions.
struct CareerCurrentJobSection: View {
    let job: CareerJobState
    var female = false
    var engine = CareerEngine()
    let onAction: (CareerEngine.WorkAction) -> Void

    var body: some View {
        let career = engine.catalog.career(job.careerId)
        Section(career?.name ?? "Mon travail") {
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.title(of: job, female: female)).font(.headline)
                Text("\(job.company) · \(CareerEngine.euros(job.salary))/an").font(.caption).foregroundStyle(.secondary)
                if let c = career {
                    Text("Échelon \(job.level + 1) sur \(c.ladder.count) · \(job.yearsInJob) an\(job.yearsInJob > 1 ? "s" : "") de boîte")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            CareerGauge(title: "Performance", value: job.performance)
            CareerGauge(title: "Patron (\(job.bossName))", value: job.bossRelation)
            CareerGauge(title: "Collègue (\(job.coworkerName))", value: job.coworkerRelation)
            ForEach(CareerEngine.WorkAction.allCases) { a in
                Button { onAction(a) } label: {
                    Label(a.label, systemImage: a.icon)
                }
                .disabled(a != .quit && job.actionsThisYear >= CareerEngine.maxActionsPerYear)
            }
        }
    }
}

struct CareerGauge: View {
    let title: String
    let value: Int

    var body: some View {
        HStack {
            Text(title).font(.caption).frame(width: 130, alignment: .leading).lineLimit(1)
            ProgressView(value: Double(value), total: 100)
                .tint(value < 25 ? .red : value < 50 ? .orange : value < 75 ? .yellow : .green)
            Text("\(value)").font(.caption).monospacedDigit().frame(width: 28, alignment: .trailing)
        }
    }
}

extension CareerEngine.WorkAction {
    var icon: String {
        switch self {
        case .workHarder: return "bolt.fill"
        case .slackOff: return "bed.double.fill"
        case .askRaise: return "eurosign.circle.fill"
        case .askPromotion: return "arrow.up.circle.fill"
        case .befriendBoss: return "hand.thumbsup.fill"
        case .befriendCoworker: return "person.2.fill"
        case .quit: return "rectangle.portrait.and.arrow.right"
        }
    }
}

/// Noms et icônes des secteurs.
enum CareerSectors {
    static func label(_ id: String) -> String {
        switch id {
        case "sante": return "Santé"
        case "education": return "Éducation"
        case "droit": return "Droit"
        case "finance": return "Finance"
        case "tech": return "Tech"
        case "ingenierie": return "Ingénierie"
        case "batiment": return "Bâtiment"
        case "industrie": return "Industrie"
        case "transport": return "Transport"
        case "commerce": return "Commerce"
        case "restauration": return "Restauration"
        case "hotellerie_tourisme": return "Hôtellerie et tourisme"
        case "art_culture": return "Art et culture"
        case "medias": return "Médias"
        case "spectacle": return "Spectacle"
        case "sport": return "Sport"
        case "securite": return "Sécurité"
        case "armee": return "Armée"
        case "administration": return "Administration"
        case "politique": return "Politique"
        case "agriculture": return "Agriculture"
        case "environnement": return "Environnement"
        case "science": return "Science"
        case "beaute_mode": return "Beauté et mode"
        case "services": return "Services"
        case "religion": return "Religion"
        case "crime": return "Crime"
        case "insolite": return "Métiers insolites"
        default: return id.capitalized
        }
    }

    static func icon(_ id: String) -> String {
        switch id {
        case "sante": return "cross.case.fill"
        case "education": return "book.fill"
        case "droit": return "building.columns.fill"
        case "finance": return "banknote.fill"
        case "tech": return "laptopcomputer"
        case "ingenierie": return "gearshape.2.fill"
        case "batiment": return "hammer.fill"
        case "industrie": return "wrench.and.screwdriver.fill"
        case "transport": return "car.fill"
        case "commerce": return "cart.fill"
        case "restauration": return "fork.knife"
        case "hotellerie_tourisme": return "bed.double.fill"
        case "art_culture": return "paintpalette.fill"
        case "medias": return "newspaper.fill"
        case "spectacle": return "theatermasks.fill"
        case "sport": return "figure.run"
        case "securite": return "shield.fill"
        case "armee": return "star.fill"
        case "administration": return "doc.text.fill"
        case "politique": return "megaphone.fill"
        case "agriculture": return "leaf.fill"
        case "environnement": return "tree.fill"
        case "science": return "atom"
        case "beaute_mode": return "scissors"
        case "services": return "person.fill"
        case "religion": return "sparkles"
        case "crime": return "theatermask.and.paintbrush.fill"
        case "insolite": return "questionmark.diamond.fill"
        default: return "briefcase.fill"
        }
    }
}

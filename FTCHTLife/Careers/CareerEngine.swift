import Foundation

/// Règles des carrières : éligibilité, candidature, année de travail, promotions,
/// licenciements, actions au travail et événements. Fonctions pures : le moteur
/// principal applique lui-même les effets renvoyés sur le personnage.
struct CareerEngine {
    let catalog: CareerCatalog

    init(catalog: CareerCatalog = .shared) {
        self.catalog = catalog
    }

    // MARK: - Éligibilité

    enum Eligibility: Equatable {
        case eligible
        case blocked(String)

        var isEligible: Bool { self == .eligible }
    }

    func eligibility(for career: CareerJob, profile p: CareerProfile) -> Eligibility {
        let r = career.requirements
        if p.age < r.minAge { return .blocked("Tu es trop jeune (\(r.minAge) ans minimum).") }
        if let maxAge = r.maxAge, p.age > maxAge { return .blocked("On cherche quelqu'un de moins de \(maxAge) ans. Charmant.") }
        if !p.education.satisfies(r.education) { return .blocked("Il faut au moins : \(r.education.label).") }
        if !r.majors.isEmpty && Set(r.majors).isDisjoint(with: p.majors) {
            let names = r.majors.compactMap { catalog.major($0)?.name }.joined(separator: ", ")
            return .blocked("Diplôme requis : \(names.isEmpty ? "une filière précise" : names).")
        }
        if let license = r.requiresLicense, !Self.isExam(license), !p.licenses.contains(license) {
            return .blocked("Il te manque : \(Self.licenseLabel(license)).")
        }
        if p.smarts < r.minSmarts { return .blocked("Ton intelligence ne suffit pas.") }
        if p.looks < r.minLooks { return .blocked("Ton apparence ne colle pas au poste.") }
        if p.health < r.minHealth { return .blocked("Ta santé ne le permet pas.") }
        return .eligible
    }

    /// Les métiers ouverts au profil, éventuellement filtrés par type ou secteur.
    func availableCareers(for p: CareerProfile, kinds: Set<CareerKind>? = nil, sector: String? = nil) -> [CareerJob] {
        catalog.careers.filter { c in
            (kinds?.contains(c.kind) ?? true)
                && (sector == nil || c.sector == sector)
                && eligibility(for: c, profile: p).isEligible
        }
    }

    // MARK: - Candidature

    enum ApplicationResult {
        case hired(CareerJobState, message: String)
        case rejected(message: String)
    }

    /// Chance d'être embauché, en %.
    func hiringChance(for career: CareerJob, profile p: CareerProfile) -> Int {
        var chance = 85 - career.hiringDifficulty * 3 / 4
        chance += (p.smarts - 50) / 4
        chance += (p.looks - 50) / 8
        chance += (p.karma - 50) / 10
        if let skill = career.special?.skill { chance += (p.value(of: skill) - 50) / 2 }
        if p.hasCriminalRecord && career.kind != .illegal { chance -= 30 }
        if career.kind == .illegal && p.hasCriminalRecord { chance += 15 }
        if career.kind == .partTime { chance += 15 }
        // Concours et examens d'entrée : intégrés à la candidature, ils récompensent l'intelligence.
        if let license = career.requirements.requiresLicense, Self.isExam(license) {
            chance += -10 + (p.smarts - 50) / 3
        }
        return min(max(chance, 3), 97)
    }

    func apply<R: RandomNumberGenerator>(to career: CareerJob, profile p: CareerProfile, using rng: inout R) -> ApplicationResult {
        if case let .blocked(reason) = eligibility(for: career, profile: p) {
            return .rejected(message: reason)
        }
        let roll = Int.random(in: 1...100, using: &rng)
        guard roll <= hiringChance(for: career, profile: p) else {
            let pool = career.special?.audition == true ? Self.auditionFails : Self.rejections
            return .rejected(message: pool.randomElement(using: &rng)!)
        }
        let job = newJob(career, using: &rng)
        let msg = "Tu es embauché{e} comme \(career.step(0).title) chez \(job.company). Salaire : \(Self.euros(job.salary)) par an."
        return .hired(job, message: fill(msg, job: job, career: career, profile: p))
    }

    func newJob<R: RandomNumberGenerator>(_ career: CareerJob, level: Int = 0, using rng: inout R) -> CareerJobState {
        let names = catalog.companies[career.sector] ?? Self.fallbackCompanies
        return CareerJobState(
            careerId: career.id,
            level: level,
            performance: 50,
            bossRelation: Int.random(in: 35...65, using: &rng),
            coworkerRelation: Int.random(in: 35...65, using: &rng),
            salary: career.step(level).salary,
            company: names.randomElement(using: &rng) ?? "Machin & Fils",
            bossName: Self.firstNames.randomElement(using: &rng)!,
            coworkerName: Self.firstNames.randomElement(using: &rng)!
        )
    }

    // MARK: - Année de travail

    struct YearReport {
        var job: CareerJobState?
        /// Revenu de l'année (avant impôts).
        var income: Int = 0
        /// Effets sur le perso (bonheur, santé, célébrité…). `money` n'est pas utilisé ici : voir `income`.
        var effects = CareerEffects()
        var messages: [String] = []
        var promoted = false
        var endReason: CareerEndReason?
    }

    /// À appeler à chaque « +1 an » pour un perso qui travaille.
    func advanceYear<R: RandomNumberGenerator>(_ job: CareerJobState, profile p: CareerProfile, using rng: inout R) -> YearReport {
        guard let career = catalog.career(job.careerId) else { return YearReport(job: nil, endReason: .contractEnded) }
        var j = job
        var report = YearReport()
        j.yearsInJob += 1
        j.yearsAtLevel += 1
        j.actionsThisYear = 0

        // Revenu
        var income = Double(j.salary)
        if let variance = career.special?.incomeVariance, variance > 0 {
            income *= 1 + Double.random(in: -variance...variance, using: &rng)
        }
        report.income = max(0, Int(income))

        // Performance : la compétence clé et le bonheur tirent vers le haut ou le bas.
        let skill = career.special?.skill.map { p.value(of: $0) } ?? p.smarts
        var drift = Int.random(in: -8...8, using: &rng)
        drift += (skill - 50) / 10
        drift += (p.happiness - 50) / 15
        drift += (j.bossRelation - 50) / 20
        j.performance = clamp(j.performance + drift)

        // Stress
        let stressHit = career.stress / 25
        if stressHit > 0 {
            report.effects.happiness = -Int.random(in: 0...stressHit, using: &rng)
            report.effects.health = career.stress >= 75 ? -Int.random(in: 0...2, using: &rng) : nil
        }
        if let fame = career.special?.fameGain, fame > 0 {
            report.effects.fame = Int(Double(fame) * Double(j.performance) / 50.0)
        }

        // Arrestation (carrières illégales)
        if let risk = career.special?.arrestRisk, risk > 0 {
            let adjusted = max(1, risk - (j.performance - 50) / 10)
            if Int.random(in: 1...100, using: &rng) <= adjusted {
                report.effects.arrested = true
                report.endReason = .arrested
                report.messages.append(fill(Self.arrests.randomElement(using: &rng)!, job: j, career: career, profile: p))
                return report
            }
        }

        // Licenciement
        if j.performance < 25 {
            let risk = (25 - j.performance) * 3 + (50 - j.bossRelation) / 3
            if Int.random(in: 1...100, using: &rng) <= max(risk, 5) {
                report.endReason = .fired
                report.messages.append(fill(Self.firings.randomElement(using: &rng)!, job: j, career: career, profile: p))
                return report
            }
            report.messages.append("Ton patron commence à prononcer ton prénom d'une façon inquiétante.")
        }

        // Promotion automatique en fin d'année
        if canBePromoted(j, career: career) {
            let chance = promotionChance(j, career: career, profile: p)
            if Int.random(in: 1...100, using: &rng) <= chance {
                promote(&j, career: career)
                report.promoted = true
                report.effects.happiness = (report.effects.happiness ?? 0) + 8
                report.messages.append(fill("Promotion ! Tu deviens \(career.step(j.level).title). Nouveau salaire : \(Self.euros(j.salary)).", job: j, career: career, profile: p))
            }
        }

        // Petite augmentation d'ancienneté
        if !report.promoted && j.performance >= 60 && Int.random(in: 1...100, using: &rng) <= 30 {
            j.salary = Int(Double(j.salary) * 1.02)
        }

        report.job = j
        return report
    }

    func canBePromoted(_ j: CareerJobState, career: CareerJob) -> Bool {
        j.level < career.topLevel && j.yearsAtLevel >= career.step(j.level).yearsToPromote
    }

    func promotionChance(_ j: CareerJobState, career: CareerJob, profile p: CareerProfile) -> Int {
        var chance = (j.performance - 45) + (j.bossRelation - 50) / 3 + (p.smarts - 50) / 10
        if let skill = career.special?.skill { chance += (p.value(of: skill) - 50) / 5 }
        return min(max(chance, 0), 90)
    }

    func promote(_ j: inout CareerJobState, career: CareerJob) {
        guard j.level < career.topLevel else { return }
        j.level += 1
        j.yearsAtLevel = 0
        j.performance = clamp(j.performance - 10)
        j.salary = max(j.salary, career.step(j.level).salary)
    }

    // MARK: - Actions au travail

    enum WorkAction: String, CaseIterable, Identifiable {
        case workHarder, slackOff, askRaise, askPromotion, befriendBoss, befriendCoworker, quit
        var id: String { rawValue }

        var label: String {
            switch self {
            case .workHarder: return "Travailler plus dur"
            case .slackOff: return "Glander"
            case .askRaise: return "Demander une augmentation"
            case .askPromotion: return "Demander une promotion"
            case .befriendBoss: return "Fayoter avec le patron"
            case .befriendCoworker: return "Sympathiser avec un collègue"
            case .quit: return "Démissionner"
            }
        }
    }

    struct ActionResult {
        var job: CareerJobState?
        var effects = CareerEffects()
        var message: String
        var endReason: CareerEndReason?
    }

    static let maxActionsPerYear = 4

    func perform<R: RandomNumberGenerator>(_ action: WorkAction, job: CareerJobState, profile p: CareerProfile, using rng: inout R) -> ActionResult {
        guard let career = catalog.career(job.careerId) else {
            return ActionResult(job: nil, message: "Ce métier n'existe plus.", endReason: .contractEnded)
        }
        var j = job
        if action != .quit && j.actionsThisYear >= Self.maxActionsPerYear {
            return ActionResult(job: j, message: "Tu en as assez fait cette année. Même ta chaise est fatiguée.")
        }
        j.actionsThisYear += 1
        var r = ActionResult(job: j, message: "")
        let roll = Int.random(in: 1...100, using: &rng)

        switch action {
        case .workHarder:
            j.performance = clamp(j.performance + Int.random(in: 4...10, using: &rng))
            r.effects.happiness = -2
            r.message = ["Tu bosses dur. Ton café a disparu, ta motivation aussi, mais ta performance grimpe.",
                         "Tu restes tard au bureau. Le gardien connaît maintenant ton prénom.",
                         "Tu réponds à tes mails à 23 h. {boss} te trouve impressionnant{e}, et un peu inquiétant{e}."].randomElement(using: &rng)!
        case .slackOff:
            j.performance = clamp(j.performance - Int.random(in: 3...9, using: &rng))
            r.effects.happiness = 4
            r.message = ["Tu passes la journée à regarder des vidéos de chats. Productivité : nulle. Bonheur : immense.",
                         "Tu fais semblant de travailler avec un tableur vide. Du grand art.",
                         "Tu prends une pause de 3 heures. {coworker} te couvre, pour l'instant."].randomElement(using: &rng)!
        case .askRaise:
            let chance = (j.performance - 50) + (j.bossRelation - 50) / 2 + 20
            if roll <= max(chance, 5) {
                let pct = Double.random(in: 0.04...0.12, using: &rng)
                j.salary = Int(Double(j.salary) * (1 + pct))
                r.effects.happiness = 6
                r.message = "{boss} accepte ! Ton salaire passe à \(Self.euros(j.salary)) par an."
            } else {
                j.bossRelation = clamp(j.bossRelation - 8)
                r.effects.happiness = -4
                r.message = ["{boss} éclate de rire, puis comprend que ce n'était pas une blague. Malaise.",
                             "« Pas cette année, la conjoncture… » dit {boss} en montant dans sa voiture neuve."].randomElement(using: &rng)!
            }
        case .askPromotion:
            if j.level >= career.topLevel {
                r.message = "Tu es déjà tout en haut. Au-dessus, il n'y a que le ciel et la retraite."
            } else if j.yearsAtLevel < career.step(j.level).yearsToPromote {
                j.bossRelation = clamp(j.bossRelation - 3)
                r.message = "{boss} te rappelle que tu es arrivé{e} il y a cinq minutes."
            } else if roll <= promotionChance(j, career: career, profile: p) + 10 {
                promote(&j, career: career)
                r.effects.happiness = 10
                r.message = "Tu deviens \(career.step(j.level).title) ! Nouveau salaire : \(Self.euros(j.salary))."
            } else {
                j.bossRelation = clamp(j.bossRelation - 6)
                r.effects.happiness = -5
                r.message = "Refusé. {boss} te conseille de « montrer plus d'énergie ». Tu montres surtout ta déception."
            }
        case .befriendBoss:
            if roll <= 70 {
                j.bossRelation = clamp(j.bossRelation + Int.random(in: 5...12, using: &rng))
                r.message = "Tu ris à toutes les blagues de {boss}. Même celle sur les impôts. Ça marche."
            } else {
                j.coworkerRelation = clamp(j.coworkerRelation - 8)
                r.message = "{coworker} t'a vu{e} lécher les bottes de {boss}. Le surnom « Paillasson » circule."
            }
        case .befriendCoworker:
            j.coworkerRelation = clamp(j.coworkerRelation + Int.random(in: 6...14, using: &rng))
            r.effects.happiness = 3
            r.message = "Tu partages un croissant avec {coworker}. Une alliance est née."
        case .quit:
            r.job = nil
            r.endReason = .quit
            r.effects.happiness = j.performance < 40 || career.stress > 60 ? 8 : -2
            r.message = "Tu démissionnes de chez {company}. Tu claques la porte. Elle était automatique, ça gâche un peu l'effet."
            r.message = fill(r.message, job: j, career: career, profile: p)
            return r
        }
        r.job = j
        r.message = fill(r.message, job: j, career: career, profile: p)
        return r
    }

    // MARK: - Événements de travail

    func matchingEvents(for j: CareerJobState) -> [CareerWorkEvent] {
        guard let career = catalog.career(j.careerId) else { return [] }
        return catalog.workEvents.filter { e in
            let c = e.conditions ?? CareerEventConditions()
            return (c.careers.isEmpty || c.careers.contains(career.id))
                && (c.sectors.isEmpty || c.sectors.contains(career.sector))
                && (c.kinds.isEmpty || c.kinds.contains(career.kind))
                && j.level >= c.minLevel
                && j.yearsInJob >= c.minYearsInJob
        }
    }

    /// Tire un événement de travail (pondéré). Les événements propres au métier passent devant.
    func randomEvent<R: RandomNumberGenerator>(for j: CareerJobState, excluding seen: Set<String> = [], using rng: inout R) -> CareerWorkEvent? {
        let pool = matchingEvents(for: j).filter { !seen.contains($0.id) }
        guard !pool.isEmpty else { return nil }
        func weight(_ e: CareerWorkEvent) -> Int {
            let base = max(e.weight ?? 10, 1)
            let c = e.conditions ?? CareerEventConditions()
            if !c.careers.isEmpty { return base * 3 }
            if !c.sectors.isEmpty { return base * 2 }
            return base
        }
        let total = pool.reduce(0) { $0 + weight($1) }
        var roll = Int.random(in: 0..<total, using: &rng)
        for e in pool {
            roll -= weight(e)
            if roll < 0 { return e }
        }
        return pool.last
    }

    func pickOutcome<R: RandomNumberGenerator>(_ choice: CareerEventChoice, using rng: inout R) -> CareerEventOutcome? {
        let total = choice.outcomes.reduce(0) { $0 + max($1.chance, 0) }
        guard total > 0 else { return choice.outcomes.first }
        var roll = Int.random(in: 0..<total, using: &rng)
        for o in choice.outcomes {
            roll -= max(o.chance, 0)
            if roll < 0 { return o }
        }
        return choice.outcomes.last
    }

    struct EffectResult {
        var job: CareerJobState?
        /// Effets sur le perso (stats, argent, célébrité, arrestation, blessure).
        var personal: CareerEffects
        var endReason: CareerEndReason?
        var promoted = false
    }

    /// Applique les effets d'un résultat sur l'emploi et renvoie ce qui concerne le perso.
    func applyEffects(_ e: CareerEffects?, to job: CareerJobState) -> EffectResult {
        guard let e = e else { return EffectResult(job: job, personal: CareerEffects()) }
        var j = job
        var out = EffectResult(job: j, personal: e)
        if let v = e.performance { j.performance = clamp(j.performance + v) }
        if let v = e.bossRelation { j.bossRelation = clamp(j.bossRelation + v) }
        if let v = e.coworkerRelation { j.coworkerRelation = clamp(j.coworkerRelation + v) }
        if let m = e.salaryMultiplier, m > 0 { j.salary = Int(Double(j.salary) * m) }
        if e.promoted == true, let career = catalog.career(j.careerId), j.level < career.topLevel {
            promote(&j, career: career)
            out.promoted = true
        }
        out.job = j
        if e.arrested == true { out.job = nil; out.endReason = .arrested }
        else if e.fired == true { out.job = nil; out.endReason = .fired }
        else if e.quit == true { out.job = nil; out.endReason = .quit }
        return out
    }

    // MARK: - Retraite

    /// Pension annuelle : environ la moitié du meilleur salaire, si assez d'années travaillées.
    func pension(history: [CareerRecord]) -> Int {
        let years = history.reduce(0) { $0 + max(($1.endAge ?? $1.startAge) - $1.startAge, 0) }
        guard years >= 10, let best = history.map(\.lastSalary).max() else { return 0 }
        let rate = min(0.5, Double(years) / 43.0 * 0.5)
        return Int(Double(best) * rate)
    }

    // MARK: - Texte

    func fill(_ text: String, job: CareerJobState, career: CareerJob?, profile: CareerProfile) -> String {
        var s = text
        s = s.replacingOccurrences(of: "{prenom}", with: profile.firstName)
        s = s.replacingOccurrences(of: "{name}", with: profile.firstName)
        s = s.replacingOccurrences(of: "{e}", with: profile.isFemale ? "e" : "")
        s = s.replacingOccurrences(of: "{boss}", with: job.bossName)
        s = s.replacingOccurrences(of: "{coworker}", with: job.coworkerName)
        s = s.replacingOccurrences(of: "{company}", with: job.company)
        s = s.replacingOccurrences(of: "{title}", with: career?.step(job.level).title ?? "")
        return CareerText.resolveGender(s, female: profile.isFemale)
    }

    func title(of job: CareerJobState, female: Bool = false) -> String {
        CareerText.resolveGender(catalog.career(job.careerId)?.step(job.level).title ?? "Inconnu", female: female)
    }

    // MARK: - Utilitaires

    private func clamp(_ v: Int) -> Int { min(max(v, 0), 100) }

    static func euros(_ amount: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "fr_FR")
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: amount)) ?? "\(amount)") + " €"
    }

    /// Les concours et examens (barreau, concours de police…) se passent pendant la candidature ;
    /// les permis (voiture, poids lourd, pilote…) doivent être obtenus avant, via le module Permis.
    static func isExam(_ id: String) -> Bool {
        id.hasPrefix("concours_") || id.hasPrefix("examen_") || id == "barreau"
    }

    static func licenseLabel(_ id: String) -> String {
        switch id {
        case "permis_scooter": return "le permis scooter"
        case "permis_voiture": return "le permis voiture"
        case "permis_moto": return "le permis moto"
        case "permis_poids_lourd": return "le permis poids lourd"
        case "permis_bus": return "le permis bus"
        case "permis_bateau": return "le permis bateau"
        case "licence_pilote": return "une licence de pilote d'avion"
        case "licence_helico": return "une licence de pilote d'hélicoptère"
        case "permis_armes": return "un permis de port d'arme"
        case "brevet_drone": return "le brevet de télépilote de drone"
        case "permis_fusee": return "le permis fusée"
        default: return id.replacingOccurrences(of: "_", with: " ")
        }
    }

    static let firstNames = ["Gérard", "Sandrine", "Kévin", "Nadia", "Bruno", "Inès", "Thierry", "Chloé",
                             "Mehdi", "Brigitte", "Yannick", "Fatou", "Jean-Mi", "Océane", "Pascal", "Leïla",
                             "Dimitri", "Martine", "Enzo", "Sylvie", "Rachid", "Camille", "Hervé", "Jade"]

    static let fallbackCompanies = ["Machin & Fils", "Groupe Truc", "Bidule SA", "Société Générale de Trucs",
                                    "Les Établissements Pouet", "Synergix Solutions", "Hexagone Services"]

    static let rejections = [
        "« On vous rappellera. » Spoiler : non.",
        "Le recruteur a regardé ton CV, puis toi, puis la fenêtre.",
        "Candidature refusée. Ils ont pris le neveu du directeur.",
        "Ton entretien s'est bien passé, jusqu'à ce que tu appelles la recruteuse « maman ».",
        "Refusé : ton profil est « trop atypique ». Tu prends ça comme un compliment.",
    ]

    static let auditionFails = [
        "Le jury a levé les yeux au ciel avant la fin de ta première phrase.",
        "Audition ratée. Le chien du producteur avait l'air plus convaincant que toi.",
        "« Merci, au suivant. » Tu n'avais pas encore commencé.",
    ]

    static let firings = [
        "{boss} te convoque. Ton badge ne marche déjà plus. Tu es viré{e} de chez {company}.",
        "Licencié{e} ! Officiellement pour « restructuration ». Officieusement, pour la sieste dans la salle des archives.",
        "{company} se sépare de toi. {coworker} récupère ton bureau avant même que tu aies fini ton carton.",
    ]

    static let arrests = [
        "La police débarque au petit matin. Ta carrière s'arrête là, ta garde à vue commence.",
        "Arrêté{e} ! Ton complice a tout balancé pour une réduction de peine et un sandwich.",
        "Menottes, gyrophares, voisins aux fenêtres. Tu fais enfin la une du journal local.",
    ]
}

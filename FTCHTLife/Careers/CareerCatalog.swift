import Foundation

/// Les entreprises fictives d'un secteur (`Data/CareerCompanies/*.json`).
struct CareerCompanyList: Codable, Hashable {
    let sector: String
    let names: [String]
}

/// Charge tous les métiers, filières et événements de travail depuis les JSON de l'app.
final class CareerCatalog: @unchecked Sendable {
    static let shared = CareerCatalog()

    private(set) var careers: [CareerJob] = []
    private(set) var majors: [CareerMajor] = []
    private(set) var workEvents: [CareerWorkEvent] = []
    private(set) var companies: [String: [String]] = [:]

    private var careersById: [String: CareerJob] = [:]

    init() {
        load()
    }

    /// Pour les tests : construit un catalogue à partir de données déjà décodées.
    init(careers: [CareerJob], majors: [CareerMajor] = [], workEvents: [CareerWorkEvent] = [], companies: [String: [String]] = [:]) {
        self.careers = careers
        self.majors = majors
        self.workEvents = workEvents
        self.companies = companies
        reindex()
    }

    func career(_ id: String) -> CareerJob? { careersById[id] }
    func major(_ id: String) -> CareerMajor? { majors.first { $0.id == id } }

    func careers(in sector: String) -> [CareerJob] { careers.filter { $0.sector == sector } }
    func careers(of kind: CareerKind) -> [CareerJob] { careers.filter { $0.kind == kind } }

    var sectors: [String] { Array(Set(careers.map(\.sector))).sorted() }

    // MARK: - Chargement

    /// Lit `Data/Careers`, `Data/WorkEvents`, `Data/CareerMajors` et `Data/CareerCompanies`
    /// (chaque fichier contient un tableau).
    private func load() {
        careers = DonneesJSON.chargerTableaux(dossier: "Careers", type: CareerJob.self)
        workEvents = DonneesJSON.chargerTableaux(dossier: "WorkEvents", type: CareerWorkEvent.self)
        majors = DonneesJSON.chargerTableaux(dossier: "CareerMajors", type: CareerMajor.self)
        let lists = DonneesJSON.chargerTableaux(dossier: "CareerCompanies", type: CareerCompanyList.self)
        companies = Dictionary(lists.map { ($0.sector, $0.names) }, uniquingKeysWith: { a, b in a + b })

        var seen = Set<String>()
        careers = careers.filter { seen.insert($0.id).inserted }
        seen.removeAll()
        workEvents = workEvents.filter { seen.insert($0.id).inserted }
        careers.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
        reindex()
    }

    private func reindex() {
        careersById = Dictionary(careers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
}

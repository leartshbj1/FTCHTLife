import Foundation

// Fêtes de l'année : anniversaire, Noël, Nouvel An, Saint-Valentin, fête des mères…
// Format des données et branchement dans le moteur : docs/FETES.md.
//
// Données :
//  - Resources/Data/FetesCalendrier/*.json : la liste des fêtes (tableaux de FeteCalendrier).
//  - Resources/Data/Fetes/*.json : les variantes de chaque fête, au format des événements
//    (tableaux d'Evenement, `category` = id de la fête).

/// Une fête du calendrier.
struct FeteCalendrier: Codable, Identifiable, Equatable {
    /// Identifiant, repris dans le champ `category` des variantes (ex. "noel").
    var id: String
    /// Nom affiché (ex. "Noël").
    var nom: String
    var emoji: String
    /// Mois et jour, pour ranger les fêtes d'une même année dans l'ordre. 0 = date variable (anniversaires).
    var mois: Int
    var jour: Int?
    /// Fréquence relative de la fête dans le tirage (défaut 1).
    var poids: Double?
}

/// Mémoire des fêtes, sauvegardée avec le joueur (`Joueur.fetes`).
struct FetesEtat: Codable, Equatable {
    /// Fêtes des dernières années (la plus récente à la fin), pour éviter d'avoir Noël trois ans de suite.
    var recentes: [String] = []
    /// Variantes déjà jouées : on ne revoit pas une variante avant d'avoir vu les autres de la même fête.
    var variantesVues: [String] = []
    /// Nombre de fois que chaque fête a été vécue.
    var compteur: [String: Int] = [:]
}

enum Fetes {
    // MARK: - Réglages

    /// Chance d'avoir une fête (carte à choix) dans l'année.
    static let chanceUneFete = 0.75
    /// Chance d'en avoir une deuxième la même année.
    static let chanceDeuxiemeFete = 0.15
    /// Nombre d'années pendant lesquelles une fête vécue est mise de côté.
    static let memoireRecentes = 3
    /// Bonus de tirage d'une fête qui a une variante « souvenir » prête (drapeau posé une année précédente).
    static let bonusSouvenir = 4.0

    // MARK: - Données

    static let calendrier: [FeteCalendrier] =
        DonneesJSON.chargerTableaux(dossier: "FetesCalendrier", type: FeteCalendrier.self)
            .sorted { ($0.mois, $0.jour ?? 0) < ($1.mois, $1.jour ?? 0) }

    static let variantes: [Evenement] = DonneesJSON.chargerTableaux(dossier: "Fetes", type: Evenement.self)

    /// Drapeaux exigés / exclus par chaque variante (`conditions.flags` / `excludeFlags`).
    /// Lus à part pour ne pas dépendre des champs du module Répercussions dans `ConditionsEvenement`.
    private static let drapeauxParVariante: [String: FeteDrapeaux] = {
        let liste = DonneesJSON.chargerTableaux(dossier: "Fetes", type: FeteDrapeaux.self)
        var dico: [String: FeteDrapeaux] = [:]
        for d in liste { dico[d.id] = d }
        return dico
    }()

    static func fete(_ id: String?) -> FeteCalendrier? {
        guard let id = id else { return nil }
        return calendrier.first { $0.id == id }
    }

    // MARK: - Tirage de l'année

    /// Les fêtes à jouer cette année, sous forme d'événements prêts pour `GameEngine.declencher`.
    ///
    /// - `eligible` : en général `{ conditionsRemplies($0, j, tags: t) }` (âge, unique, tags, partenaire…).
    /// - `drapeaux` : drapeaux actifs du joueur (module Répercussions). `nil` si ce module n'est pas branché :
    ///   les variantes « souvenir » (qui exigent un drapeau) sont alors ignorées.
    static func evenementsDeLAnnee(age: Int,
                                   etat: inout FetesEtat,
                                   drapeaux: Set<String>? = nil,
                                   eligible: (Evenement) -> Bool) -> [Evenement] {
        let possibles = variantes.filter { v in
            fete(v.category) != nil && drapeauxOK(v, drapeaux) && eligible(v)
        }
        guard !possibles.isEmpty else { return [] }

        var choisies: [Evenement] = []

        // 1. Anniversaire marquant : une variante prévue pour cet âge précis passe toujours.
        let estJalon: (Evenement) -> Bool = { $0.minAge == age && $0.maxAge == age }
        if let v = tirerVariante(possibles.filter(estJalon), etat: etat, drapeaux: drapeaux) {
            choisies.append(v)
        }

        // 2. Fêtes tirées au sort.
        var nombre = 0
        if Double.random(in: 0..<1) < chanceUneFete { nombre += 1 }
        if Double.random(in: 0..<1) < chanceDeuxiemeFete { nombre += 1 }
        if age < 3 || !choisies.isEmpty { nombre = min(nombre, 1) }

        let ordinaires = possibles.filter { !estJalon($0) }
        var parFete: [String: [Evenement]] = [:]
        for v in ordinaires { parFete[v.category ?? "", default: []].append(v) }

        var dejaPrises = Set(choisies.compactMap { $0.category })
        for _ in 0..<nombre {
            var candidates = calendrier.filter { parFete[$0.id] != nil && !dejaPrises.contains($0.id) }
            let pasRecentes = candidates.filter { !etat.recentes.contains($0.id) }
            if !pasRecentes.isEmpty { candidates = pasRecentes }
            guard let fete = tirage(candidates, poids: { f in
                let base = f.poids ?? 1
                let souvenir = (parFete[f.id] ?? []).contains { exigeDrapeau($0) }
                return souvenir ? base * bonusSouvenir : base
            }) else { break }
            dejaPrises.insert(fete.id)
            if let v = tirerVariante(parFete[fete.id] ?? [], etat: etat, drapeaux: drapeaux) {
                choisies.append(v)
            }
        }

        // 3. Mémoire et mise en forme.
        var resultat: [Evenement] = []
        for v in choisies {
            guard let f = fete(v.category) else { continue }
            noter(v, fete: f, etat: &etat)
            var e = v
            e.text = "\(f.emoji) \(f.nom) : " + v.text
            resultat.append(e)
        }
        let ordre = Dictionary(calendrier.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        return resultat.sorted { (ordre[$0.category ?? ""] ?? 0) < (ordre[$1.category ?? ""] ?? 0) }
    }

    // MARK: - Détails

    /// Choisit une variante : d'abord les souvenirs prêts, puis celles pas encore vues, sinon n'importe laquelle.
    private static func tirerVariante(_ liste: [Evenement], etat: FetesEtat, drapeaux: Set<String>?) -> Evenement? {
        guard !liste.isEmpty else { return nil }
        let souvenirs = liste.filter { exigeDrapeau($0) }
        if !souvenirs.isEmpty, Double.random(in: 0..<1) < 0.8 {
            return tirage(souvenirs) { $0.weight ?? 1 }
        }
        let nouvelles = liste.filter { !etat.variantesVues.contains($0.id) }
        return tirage(nouvelles.isEmpty ? liste : nouvelles) { $0.weight ?? 1 }
    }

    private static func noter(_ v: Evenement, fete: FeteCalendrier, etat: inout FetesEtat) {
        etat.recentes.removeAll { $0 == fete.id }
        etat.recentes.append(fete.id)
        if etat.recentes.count > memoireRecentes { etat.recentes.removeFirst(etat.recentes.count - memoireRecentes) }
        etat.compteur[fete.id, default: 0] += 1

        // Quand toutes les variantes d'une fête ont été vues, on recommence le cycle pour cette fête.
        let ids = Set(variantes.filter { $0.category == fete.id }.map { $0.id })
        if ids.isSubset(of: Set(etat.variantesVues + [v.id])) {
            etat.variantesVues.removeAll { ids.contains($0) }
        }
        if !etat.variantesVues.contains(v.id) { etat.variantesVues.append(v.id) }
    }

    private static func exigeDrapeau(_ v: Evenement) -> Bool {
        !(drapeauxParVariante[v.id]?.conditions?.flags ?? []).isEmpty
    }

    private static func drapeauxOK(_ v: Evenement, _ drapeaux: Set<String>?) -> Bool {
        let c = drapeauxParVariante[v.id]?.conditions
        let exiges = c?.flags ?? []
        let exclus = c?.excludeFlags ?? []
        guard let actifs = drapeaux else { return exiges.isEmpty }
        return Set(exiges).isSubset(of: actifs) && Set(exclus).isDisjoint(with: actifs)
    }

    /// Tirage pondéré (copie locale pour ne pas dépendre de GameEngine, isolé sur le thread principal).
    private static func tirage<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0.0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.randomElement() }
        var r = Double.random(in: 0..<total)
        for element in liste {
            r -= max(0, poids(element))
            if r < 0 { return element }
        }
        return liste.last
    }
}

/// Lecture partielle d'une variante : seulement ses drapeaux.
private struct FeteDrapeaux: Decodable {
    struct Conditions: Decodable {
        var flags: [String]?
        var excludeFlags: [String]?
    }
    var id: String
    var conditions: Conditions?
}

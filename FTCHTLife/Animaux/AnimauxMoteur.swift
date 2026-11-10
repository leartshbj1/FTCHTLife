import Foundation

/// Une offre d'adoption (refuge, animalerie, vendeur exotique).
struct OffreAnimal: Identifiable, Equatable {
    let id = UUID()
    var animal: Animal
    var prix: Int
    /// Le caractère est connu avant l'adoption (refuge) ou c'est une surprise (animalerie).
    var caractereVisible: Bool
}

enum SourceAdoption: String, CaseIterable, Identifiable {
    case refuge, animalerie, exotique
    var id: String { rawValue }

    var titre: String {
        switch self {
        case .refuge: return "Refuge"
        case .animalerie: return "Animalerie"
        case .exotique: return "Animaux exotiques"
        }
    }

    var description: String {
        switch self {
        case .refuge: return "Pas cher, déjà grands, caractère connu."
        case .animalerie: return "Des bébés tout neufs. Caractère : surprise."
        case .exotique: return "Un vendeur louche sur un parking. 18 ans minimum."
        }
    }

    var icone: String {
        switch self {
        case .refuge: return "house.fill"
        case .animalerie: return "cart.fill"
        case .exotique: return "globe.americas.fill"
        }
    }
}

/// Une action possible avec un animal.
struct ActionAnimal: Identifiable, Equatable {
    let id: String
    let titre: String
    let icone: String
    var cout: Int = 0
}

extension GameEngine {

    typealias CleAnimaux = WritableKeyPath<Joueur, AnimauxEtat?>

    /// État des animaux du joueur en cours (vide s'il n'en a jamais eu).
    func etatAnimaux(_ cle: CleAnimaux) -> AnimauxEtat {
        joueur?[keyPath: cle] ?? AnimauxEtat()
    }

    /// Tags pour les événements du moteur : "pet" et "pet_<espèce>".
    func tagsAnimaux(_ j: Joueur, cle: CleAnimaux) -> Set<String> {
        guard let etat = j[keyPath: cle], !etat.animaux.isEmpty else { return [] }
        var t: Set<String> = ["pet"]
        for a in etat.animaux { t.insert("pet_" + a.especeId) }
        return t
    }

    // MARK: - Textes

    /// Remplace les variables d'animal puis celles du moteur.
    func remplirAnimal(_ texte: String, _ a: Animal, _ j: Joueur) -> String {
        var t = texte
        let e = a.espece
        t = t.replacingOccurrences(of: "{animal}", with: a.nom)
        t = t.replacingOccurrences(of: "{le_espece}", with: e?.avecArticle ?? "l'animal")
        t = t.replacingOccurrences(of: "{ton_espece}", with: e?.avecPossessif ?? "ton animal")
        t = t.replacingOccurrences(of: "{espece}", with: e?.nomMinuscule ?? "animal")
        t = t.replacingOccurrences(of: "{cri}", with: e?.cri ?? "fait du bruit")
        t = t.replacingOccurrences(of: "{caractere}", with: a.caractere?.nom.lowercased() ?? "imprévisible")
        t = t.replacingOccurrences(of: "{a}", with: a.femelle ? "e" : "")
        t = t.replacingOccurrences(of: "{il}", with: a.femelle ? "elle" : "il")
        t = t.replacingOccurrences(of: "{Il}", with: a.femelle ? "Elle" : "Il")
        return remplir(t, j)
    }

    /// « Moustache, ton chat, » pour les lignes du journal.
    private func presentation(_ a: Animal) -> String {
        "\(a.nom), \(a.espece?.avecPossessif ?? "ton animal"),"
    }

    // MARK: - Une année de plus

    /// À appeler dans `vieillir()`, après l'ajout de l'année au journal.
    /// Vieillit les animaux, gère maladies, morts, fugues, entretien, et tire leurs événements.
    func animauxAnnee(_ j: inout Joueur, cle: CleAnimaux) {
        guard j.vivant, var etat = j[keyPath: cle], !etat.animaux.isEmpty else { return }

        // Entretien
        let cout = etat.coutAnnuel
        if j.age >= 18 && cout > 0 {
            j.argent -= cout
            ajouterLigne(&j, "🐾 Croquettes, litière et vétérinaire : tes animaux t'ont coûté \(Format.argent(cout)) cette année.")
        }

        for a0 in etat.animaux {
            var a = a0
            a.age += 1
            a.actionsAnnee = []
            a.lien = Stats.borne(a.lien + Int.random(in: -4...1))
            let vieux = a.age >= (a.espece?.debutVieillesse ?? 10)
            a.sante = Stats.borne(a.sante + (vieux ? -Int.random(in: 3...10) : Int.random(in: -2...3)))
            if a.maladie != nil {
                a.sante = Stats.borne(a.sante - Int.random(in: 5...15))
            } else if Double.random(in: 0...1) < (vieux ? 0.18 : 0.06) {
                let m = Animaux.maladies.randomElement()!
                a.maladie = m
                a.sante = Stats.borne(a.sante - Int.random(in: 5...12))
                ajouterLigne(&j, "🤒 \(a.nom) a attrapé \(m). Un tour chez le vétérinaire s'impose.")
            }
            remplacer(a, dans: &etat)

            if a.sante <= 0 {
                let cause = a.maladie.map { Animaux.deMaladie($0) } ?? "d'épuisement"
                retirerAnimal(a.id, mort: true, cause: cause, etat: &etat, j: &j)
            } else if Double.random(in: 0...1) < Animaux.chanceDeces(a) {
                let cause = vieux ? Animaux.mortsDeVieillesse.randomElement()! : "dans un accident domestique très bête"
                retirerAnimal(a.id, mort: true, cause: cause, etat: &etat, j: &j)
            } else if a.lien < 15 && Double.random(in: 0...1) < 0.3 {
                retirerAnimal(a.id, mort: false, cause: "est parti\(a.accord("", "e")) vivre chez des gens plus attentionnés", etat: &etat, j: &j)
            }
        }

        // Événements
        let t = tags(j)
        var nombre = 0
        for a in etat.animaux.shuffled() where nombre < 2 && j.vivant {
            guard Double.random(in: 0...1) < 0.35,
                  etat.animaux.contains(where: { $0.id == a.id }) else { continue }
            let candidats = evenementsPossibles(a, j, tags: t)
            guard let e = Animaux.tirer(candidats, poids: { $0.weight ?? 1 }) else { continue }
            nombre += 1
            if e.unique == true, let i = etat.animaux.firstIndex(where: { $0.id == a.id }) {
                etat.animaux[i].evenementsVus.append(e.id)
            }
            let texte = remplirAnimal(e.text, a, j)
            if let choix = e.choices, !choix.isEmpty {
                etat.enAttente.append(AnimalEvenementEnAttente(evenementId: e.id, animalId: a.id, texte: texte))
            } else {
                ajouterLigne(&j, "🐾 " + texte)
                appliquerEffetsAnimal(e.pet, animalId: a.id, etat: &etat, j: &j)
                if let eff = e.effects { appliquer(eff, &j) }
            }
        }
        if !j.vivant { etat.enAttente = [] }
        j[keyPath: cle] = etat
    }

    func evenementsPossibles(_ a: Animal, _ j: Joueur, tags t: Set<String>) -> [AnimalEvenement] {
        let vieux = a.age >= (a.espece?.debutVieillesse ?? 10)
        return Animaux.evenements.filter { e in
            if let l = e.especes, !l.contains(a.especeId) { return false }
            if let l = e.caracteres, !l.contains(a.caractereId) { return false }
            if let m = e.minAgeAnimal, a.age < m { return false }
            if let m = e.maxAgeAnimal, a.age > m { return false }
            if let m = e.minLien, a.lien < m { return false }
            if let m = e.maxLien, a.lien > m { return false }
            if let m = e.malade, m != (a.maladie != nil) { return false }
            if let v = e.vieux, v != vieux { return false }
            if e.unique == true && a.evenementsVus.contains(e.id) { return false }
            return conditionsRemplies(e.commeEvenement, j, tags: t)
        }
    }

    private func remplacer(_ a: Animal, dans etat: inout AnimauxEtat) {
        if let i = etat.animaux.firstIndex(where: { $0.id == a.id }) { etat.animaux[i] = a }
    }

    /// Fait quitter le foyer à un animal (mort, fugue, abandon) et l'écrit dans le journal.
    /// Pour une fugue, `cause` est la fin de phrase après le nom (« est parti vivre… »).
    private func retirerAnimal(_ id: UUID, mort: Bool, cause: String, etat: inout AnimauxEtat, j: inout Joueur) {
        guard let i = etat.animaux.firstIndex(where: { $0.id == id }) else { return }
        var a = etat.animaux.remove(at: i)
        a.mort = mort
        a.departA = j.age
        etat.enAttente.removeAll { $0.animalId == id }
        if mort {
            a.depart = "Mort\(a.accord("", "e")) \(cause), à \(a.age) an\(a.age > 1 ? "s" : "")"
            ajouterLigne(&j, "💀 \(presentation(a)) est mort\(a.accord("", "e")) \(cause), à \(a.age) an\(a.age > 1 ? "s" : "").")
            j.stats.bonheur -= max(3, a.lien / 5)
        } else {
            a.depart = cause.prefix(1).uppercased() + cause.dropFirst()
            ajouterLigne(&j, "🚪 \(presentation(a)) \(cause).")
            j.stats.bonheur -= max(2, a.lien / 8)
        }
        j.stats.borner()
        etat.disparus.append(a)
    }

    /// Applique les effets d'un événement à l'animal concerné.
    private func appliquerEffetsAnimal(_ eff: AnimalEffets?, animalId: UUID, etat: inout AnimauxEtat, j: inout Joueur) {
        guard let eff = eff, let i = etat.animaux.firstIndex(where: { $0.id == animalId }) else { return }
        var a = etat.animaux[i]
        a.lien = Stats.borne(a.lien + (eff.bond ?? 0))
        a.sante = Stats.borne(a.sante + (eff.health ?? 0))
        if eff.cure == true { a.maladie = nil }
        if let m = eff.sick { a.maladie = m }
        if let t = eff.trait, let c = Animaux.caractere(t), c.id != a.caractereId {
            a.caractereId = c.id
            ajouterLigne(&j, "✨ \(a.nom) a changé : \(a.accord("il", "elle")) est maintenant \(c.nom.lowercased()).")
        }
        etat.animaux[i] = a

        if let cause = eff.death {
            retirerAnimal(a.id, mort: true, cause: remplirAnimal(cause, a, j), etat: &etat, j: &j)
        } else if a.sante <= 0 {
            retirerAnimal(a.id, mort: true, cause: a.maladie.map { Animaux.deMaladie($0) } ?? "de ses blessures", etat: &etat, j: &j)
        } else if eff.runaway == true {
            retirerAnimal(a.id, mort: false, cause: "a fugué et n'est jamais revenu\(a.accord("", "e"))", etat: &etat, j: &j)
        }

        if let id = eff.newPet, let espece = Animaux.espece(id), etat.animaux.count < Animaux.maxAnimaux {
            let bebe = Animaux.nouvelAnimal(espece, age: 0, ageJoueur: j.age)
            etat.animaux.append(bebe)
            ajouterLigne(&j, "🐾 Nouveau venu à la maison : \(bebe.nom), \(espece.avecArticle) (\(bebe.caractere?.nom.lowercased() ?? "caractère inconnu")).")
        }
    }

    // MARK: - Événements à choix

    /// Prochain événement d'animal à afficher (aucun si un événement du moteur est en cours).
    func prochainEvenementAnimal(_ cle: CleAnimaux) -> AnimalEvenementEnAttente? {
        guard let j = joueur, j.vivant, evenementEnCours == nil else { return nil }
        return j[keyPath: cle]?.enAttente.first
    }

    func evenementAnimalEnAttente(_ id: UUID, cle: CleAnimaux) -> AnimalEvenementEnAttente? {
        joueur?[keyPath: cle]?.enAttente.first { $0.id == id }
    }

    /// Libellé d'un choix avec les variables remplacées ({animal}, {espece}…).
    func libelleChoixAnimal(_ label: String, animalId: UUID, cle: CleAnimaux) -> String {
        guard let j = joueur, let a = j[keyPath: cle]?.animaux.first(where: { $0.id == animalId }) else { return label }
        return remplirAnimal(label, a, j)
    }

    /// Le joueur répond à un événement d'animal.
    func choisirAnimal(_ attenteId: UUID, choix index: Int, cle: CleAnimaux) {
        guard var j = joueur, var etat = j[keyPath: cle],
              let k = etat.enAttente.firstIndex(where: { $0.id == attenteId }),
              etat.enAttente[k].resultat == nil else { return }
        let attente = etat.enAttente[k]
        guard let e = Animaux.evenement(attente.evenementId), let choix = e.choices, choix.indices.contains(index),
              let a = etat.animaux.first(where: { $0.id == attente.animalId }) else {
            etat.enAttente[k].resultat = "Finalement, il ne s'est rien passé."
            j[keyPath: cle] = etat
            joueur = j
            sauvegarder()
            return
        }
        let c = choix[index]
        let issue = Animaux.tirer(c.outcomes, poids: { $0.chance ?? 1 })
        let resultat = remplirAnimal(issue?.text ?? "Il ne s'est rien passé.", a, j)
        ajouterLigne(&j, "🐾 " + attente.texte + " → " + remplirAnimal(c.label, a, j) + ". " + resultat)
        etat.enAttente[k].resultat = resultat
        appliquerEffetsAnimal(issue?.pet, animalId: a.id, etat: &etat, j: &j)
        if let eff = issue?.effects { appliquer(eff, &j) }
        if !j.vivant {
            etat.enAttente.removeAll { $0.id != attenteId }
        }
        // L'événement affiché reste en file jusqu'à sa fermeture, même si l'animal est parti.
        if !etat.enAttente.contains(where: { $0.id == attenteId }) {
            var fini = attente
            fini.resultat = resultat
            etat.enAttente.insert(fini, at: 0)
        }
        j[keyPath: cle] = etat
        joueur = j
        sauvegarder()
    }

    /// Ferme un événement d'animal (après avoir lu le résultat).
    func fermerEvenementAnimal(_ attenteId: UUID, cle: CleAnimaux) {
        modifier { j in
            guard var etat = j[keyPath: cle] else { return }
            etat.enAttente.removeAll { $0.id == attenteId }
            j[keyPath: cle] = etat
        }
    }

    // MARK: - Adoption

    func sourceDisponible(_ s: SourceAdoption) -> Bool {
        guard let j = joueur, j.vivant else { return false }
        return s == .exotique ? j.age >= 18 : j.age >= Animaux.ageMinimal
    }

    /// Animaux proposés par une source (à garder pendant que l'écran est ouvert).
    func offresAdoption(_ s: SourceAdoption) -> [OffreAnimal] {
        let age = joueur?.age ?? 0
        switch s {
        case .refuge:
            let communs = Animaux.especes.filter { !$0.exotique }
            return (0..<6).compactMap { _ -> OffreAnimal? in
                guard let e = communs.randomElement() else { return nil }
                let ageAnimal = Int.random(in: 0...max(0, min(8, e.debutVieillesse - 1)))
                var a = Animaux.nouvelAnimal(e, age: ageAnimal, ageJoueur: age)
                a.lien = Int.random(in: 30...55)
                a.sante = Int.random(in: 55...95)
                return OffreAnimal(animal: a, prix: e.prixRefuge ?? e.prix / 3, caractereVisible: true)
            }
        case .animalerie:
            return Animaux.especes.filter { !$0.exotique }.map {
                OffreAnimal(animal: Animaux.nouvelAnimal($0, age: 0, ageJoueur: age), prix: $0.prix, caractereVisible: false)
            }
        case .exotique:
            return Animaux.especes.filter { $0.exotique }.map {
                OffreAnimal(animal: Animaux.nouvelAnimal($0, age: Int.random(in: 0...2), ageJoueur: age), prix: $0.prix, caractereVisible: false)
            }
        }
    }

    /// Adopte l'animal d'une offre et renvoie le texte du résultat.
    func adopter(_ offre: OffreAnimal, nom: String?, cle: CleAnimaux) -> String {
        guard var j = joueur, j.vivant else { return "" }
        var etat = j[keyPath: cle] ?? AnimauxEtat()
        var a = offre.animal
        if let n = nom?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty { a.nom = n }
        a.adopteA = j.age
        let espece = a.espece
        if etat.animaux.count >= Animaux.maxAnimaux {
            return "Tu as déjà \(etat.animaux.count) animaux. Ta maison ressemble à une arche. Non."
        }
        if j.age < Animaux.ageMinimal { return "Tu es trop petit\(j.g("", "e")). Pour l'instant, l'animal de la maison, c'est toi." }
        if j.age < (espece?.ageMinJoueur ?? 0) {
            return "Il faut avoir au moins \(espece?.ageMinJoueur ?? 0) ans pour adopter ce genre d'animal."
        }

        var texte: String
        if j.age < 18 {
            // Il faut convaincre les parents, une fois par an.
            if j.actionsAnnee.contains("animal_demande") {
                return "Tu as déjà supplié tes parents cette année. Ils ont dit « on verra », ce qui veut dire non."
            }
            j.actionsAnnee.append("animal_demande")
            let parents = j.relations.filter { $0.type.estParent && $0.vivant }
            let lien = parents.isEmpty ? 50 : parents.map(\.lien).reduce(0, +) / parents.count
            let chance = 0.15 + Double(lien) / 160 - Double(etat.animaux.count) * 0.12
            guard Double.random(in: 0...1) < chance else {
                let refus = [
                    "Tes parents ont dit non. Selon eux, tu n'arriverais même pas à t'occuper d'un cactus.",
                    "Refusé. Ton père a dit « et qui va le sortir ? » en te regardant comme si c'était évident.",
                    "Ta mère a dit oui, ton père a dit non, et la dispute a duré trois jours. Pas d'animal.",
                    "Tes parents ont promis « pour Noël ». Tu as eu des chaussettes.",
                ]
                let r = refus.randomElement()!
                j.stats.bonheur -= 4
                j.stats.borner()
                ajouterLigne(&j, r)
                joueur = j
                sauvegarder()
                return r
            }
            texte = "Après des semaines de supplications, tes parents ont cédé ! Tu adoptes \(a.nom), \(espece?.avecArticle ?? "un animal")."
        } else {
            guard j.argent >= offre.prix else { return "Tu n'as pas assez d'argent (\(Format.argent(offre.prix)))." }
            j.argent -= offre.prix
            texte = "Tu as adopté \(a.nom), \(espece?.avecArticle ?? "un animal")"
            texte += offre.prix > 0 ? " pour \(Format.argent(offre.prix))." : "."
        }
        texte += " Caractère : \(a.caractere?.nom.lowercased() ?? "mystère"). \(a.caractere?.description ?? "")"
        etat.animaux.append(a)
        j.stats.bonheur += 8
        j.stats.borner()
        ajouterLigne(&j, "🐾 " + texte)
        j[keyPath: cle] = etat
        joueur = j
        sauvegarder()
        return texte
    }

    // MARK: - Actions

    func coutVeterinaire(_ a: Animal) -> Int {
        (a.espece?.exotique ?? false) ? 350 : 150
    }

    func actionsAnimal(_ a: Animal) -> [ActionAnimal] {
        var l = [
            ActionAnimal(id: "caresser", titre: "Câliner", icone: "hand.raised.fill"),
            ActionAnimal(id: "jouer", titre: "Jouer", icone: "tennisball.fill"),
        ]
        if a.espece?.promenable == true {
            l.append(ActionAnimal(id: "promener", titre: "Promener", icone: "figure.walk"))
        }
        l.append(ActionAnimal(id: "friandise", titre: "Donner une friandise", icone: "birthday.cake.fill", cout: 15))
        l.append(ActionAnimal(id: "veterinaire", titre: "Aller chez le vétérinaire", icone: "cross.case.fill", cout: coutVeterinaire(a)))
        if (joueur?.age ?? 0) >= 10 {
            l.append(ActionAnimal(id: "dresser", titre: "Dresser", icone: "graduationcap.fill", cout: 200))
        }
        return l
    }

    func actionAnimalDisponible(_ action: ActionAnimal, _ a: Animal) -> Bool {
        guard let j = joueur, j.vivant else { return false }
        return !a.actionsAnnee.contains(action.id)
    }

    /// Fait une action avec un animal et renvoie le texte du résultat.
    func agirAnimal(_ action: ActionAnimal, animalId: UUID, cle: CleAnimaux) -> String {
        guard var j = joueur, j.vivant, var etat = j[keyPath: cle],
              let i = etat.animaux.firstIndex(where: { $0.id == animalId }) else { return "" }
        var a = etat.animaux[i]
        if a.actionsAnnee.contains(action.id) { return "Tu l'as déjà fait cette année avec \(a.nom)." }
        let paye = j.age < 18 ? 0 : action.cout
        if paye > 0 && j.argent < paye { return "Tu n'as pas assez d'argent (\(Format.argent(paye)))." }
        j.argent -= paye
        a.actionsAnnee.append(action.id)
        let car = a.caractereId
        let il = a.accord("il", "elle")
        let Il = a.accord("Il", "Elle")
        var t: String

        switch action.id {
        case "caresser":
            if car == "diva" && Bool.random() {
                a.lien = Stats.borne(a.lien + 1)
                t = "\(a.nom) a accepté une caresse, une seule, puis t'a regardé comme si tu lui devais de l'argent."
            } else if car == "bagarreur" && Double.random(in: 0...1) < 0.4 {
                a.lien = Stats.borne(a.lien + 2)
                j.stats.sante -= 2
                t = "\(a.nom) a apprécié la caresse pendant quatre secondes, puis t'a attaqué la main. C'est sa façon de dire merci."
            } else if car == "peureux" && Double.random(in: 0...1) < 0.3 {
                t = "Tu as approché ta main trop vite. \(a.nom) s'est caché\(a.accord("", "e")) sous le lit pour l'après-midi."
            } else {
                let g = Int.random(in: 4...9) + (car == "calin" ? 4 : 0)
                a.lien = Stats.borne(a.lien + g)
                j.stats.bonheur += Int.random(in: 2...5)
                t = ["Câlin réussi. \(a.nom) a fermé les yeux de bonheur. Toi aussi.",
                     "\(a.nom) s'est roulé\(a.accord("", "e")) contre toi pendant une heure. Tu as raté ton bus, ça valait le coup.",
                     "Tu as gratté \(a.nom) au bon endroit. \(Il) t'a regardé comme si tu étais une divinité."].randomElement()!
            }
        case "jouer":
            if car == "paresseux" && Bool.random() {
                a.lien = Stats.borne(a.lien + 2)
                t = "Tu as lancé la balle. \(a.nom) l'a regardée partir, puis s'est rendormi\(a.accord("", "e")). Tu es allé\(j.g("", "e")) la chercher toi-même."
            } else if car == "genie" && Double.random(in: 0...1) < 0.35 {
                a.lien = Stats.borne(a.lien + 6)
                j.stats.intelligence += 2
                t = "Tu as voulu jouer avec \(a.nom). \(Il) a inventé un jeu plus intelligent, avec des règles. Tu as perdu."
            } else {
                a.lien = Stats.borne(a.lien + Int.random(in: 5...10))
                a.sante = Stats.borne(a.sante + 2)
                j.stats.bonheur += Int.random(in: 3...6)
                t = ["Vous avez joué tout l'après-midi. \(a.nom) a gagné, évidemment.",
                     "Partie de cache-cache épique. \(a.nom) a été retrouvé\(a.accord("", "e")) dans le panier à linge.",
                     "Tu as couru partout avec \(a.nom). Les voisins pensent que vous êtes fous. Ils n'ont pas tort."].randomElement()!
            }
        case "promener":
            j.stats.sante += Int.random(in: 2...4)
            if car == "fugueur" && Double.random(in: 0...1) < 0.35 {
                a.lien = Stats.borne(a.lien + 2)
                t = "\(a.nom) a glissé de sa laisse au premier carrefour. Tu l'as retrouvé\(a.accord("", "e")) deux heures plus tard devant une boulangerie, \(a.accord("très fier de lui", "très fière d'elle"))."
            } else if car == "peureux" && Double.random(in: 0...1) < 0.4 {
                a.lien = Stats.borne(a.lien + 3)
                t = "Promenade écourtée : \(a.nom) a eu peur d'une feuille morte. Puis d'une autre. Puis du vent."
            } else {
                a.lien = Stats.borne(a.lien + Int.random(in: 5...9))
                a.sante = Stats.borne(a.sante + 3)
                j.stats.bonheur += 3
                t = ["Belle promenade au parc. \(a.nom) a reniflé chaque brin d'herbe comme un inspecteur.",
                     "En promenade, tout le monde s'est arrêté pour caresser \(a.nom). Personne ne t'a regardé, toi.",
                     "Une heure de marche. \(a.nom) en pleine forme, toi un peu moins."].randomElement()!
            }
        case "friandise":
            let g = Int.random(in: 5...10) + (car == "glouton" ? 4 : 0)
            a.lien = Stats.borne(a.lien + g)
            if car == "glouton" {
                a.sante = Stats.borne(a.sante - 1)
                t = "\(a.nom) a avalé la friandise, le paquet, et un bout de ta manche. \(Il) t'aime d'un amour total."
            } else if car == "diva" {
                t = "\(a.nom) a reniflé la friandise et l'a refusée. Pas assez bio. Puis l'a mangée quand tu avais le dos tourné."
            } else {
                t = "\(a.nom) a mangé sa friandise en deux secondes et te fixe maintenant pour la suivante."
            }
        case "veterinaire":
            a.sante = Stats.borne(a.sante + Int.random(in: 12...25))
            if let m = a.maladie {
                if Double.random(in: 0...1) < 0.8 {
                    a.maladie = nil
                    t = "Le vétérinaire a soigné \(m). \(a.nom) va beaucoup mieux, mais ne te pardonnera jamais le thermomètre."
                } else {
                    t = "Le vétérinaire a essayé de soigner \(m). Ça n'a pas marché cette fois. Il faudra revenir."
                }
            } else if car == "dramatique" {
                t = "Chez le vétérinaire, \(a.nom) a fait le mort dans la salle d'attente. Le véto a applaudi. Bilan : en pleine forme."
            } else {
                t = "Bilan de santé : \(a.nom) va bien. Le vétérinaire a quand même trouvé un moyen de te facturer \(Format.argent(paye > 0 ? paye : coutVeterinaire(a)))."
            }
            if car == "peureux" { a.lien = Stats.borne(a.lien - 3) }
        case "dresser":
            var chance = 0.5
            if car == "genie" { chance = 0.9 }
            if car == "paresseux" || car == "diva" { chance = 0.2 }
            if car == "philosophe" { chance = 0.3 }
            if Double.random(in: 0...1) < chance {
                a.lien = Stats.borne(a.lien + Int.random(in: 4...8))
                j.stats.bonheur += 3
                if car != "genie" && Double.random(in: 0...1) < 0.06 {
                    a.caractereId = "genie"
                    t = "Révélation ! Pendant le dressage, \(a.nom) a appris à ouvrir le frigo, à allumer la télé et à te juger. \(Il) est maintenant un génie."
                } else {
                    t = ["\(a.nom) sait maintenant donner la patte. Enfin, une patte. Toujours la même.",
                         "Dressage réussi : \(a.nom) s'assoit sur commande. Quand \(il) en a envie.",
                         "\(a.nom) a appris un tour impressionnant. Tu l'as filmé, personne ne te croit."].randomElement()!
                }
            } else {
                a.lien = Stats.borne(a.lien - 2)
                t = ["Après trois séances, c'est \(a.nom) qui t'a dressé\(j.g("", "e")). Tu donnes une friandise dès qu'\(il) te regarde.",
                     "Le dresseur a rendu son diplôme. \(a.nom) a gagné.",
                     "\(a.nom) a écouté toutes les consignes avec attention. Puis a fait exactement le contraire."].randomElement()!
            }
        default:
            t = ""
        }

        etat.animaux[i] = a
        j.stats.borner()
        ajouterLigne(&j, "🐾 " + t)
        j[keyPath: cle] = etat
        joueur = j
        sauvegarder()
        return t
    }

    /// Abandonne un animal (il quitte le foyer, le karma prend cher).
    func abandonnerAnimal(_ animalId: UUID, cle: CleAnimaux) -> String {
        guard var j = joueur, j.vivant, var etat = j[keyPath: cle],
              let a = etat.animaux.first(where: { $0.id == animalId }) else { return "" }
        j.stats.karma -= 15
        retirerAnimal(animalId, mort: false, cause: "a été confié\(a.accord("", "e")) à un refuge. Tu n'as pas osé te retourner", etat: &etat, j: &j)
        j.stats.borner()
        j[keyPath: cle] = etat
        joueur = j
        sauvegarder()
        return "Tu as abandonné \(a.nom) au refuge. Le bénévole t'a regardé\(j.g("", "e")) comme on regarde quelqu'un qui abandonne \(a.nom)."
    }
}

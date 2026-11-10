import Foundation

/// Actions de l'écran Compétences : s'entraîner et suivre un cours (une fois par an chacun).
extension GameEngine {

    func competencePratiquable(_ def: CompetenceDef) -> Bool {
        guard let j = joueur, j.vivant else { return false }
        return j.age >= def.minAge && !j.actionsAnnee.contains(Competences.cleePratique(def.id))
    }

    /// S'entraîne dans une compétence et renvoie le texte du résultat.
    func pratiquerCompetence(_ def: CompetenceDef) -> String {
        guard var j = joueur, j.vivant else { return "" }
        if j.age < def.minAge {
            return "Tu es trop jeune pour ça. Reviens dans \(def.minAge - j.age) an" + (def.minAge - j.age > 1 ? "s." : ".")
        }
        if j.actionsAnnee.contains(Competences.cleePratique(def.id)) {
            return "Tu t'es déjà " + j.g("entraîné", "entraînée") + " cette année. Même les génies dorment."
        }
        let cout = j.age < 18 ? 0 : (def.pratique.cout ?? 0)
        if cout > 0 && j.argent < cout {
            return "Il te faut \(Format.argent(cout)) pour t'entraîner. Ton compte en banque dit non."
        }
        j.argent -= cout
        j.actionsAnnee.append(Competences.cleePratique(def.id))

        let n = Competences.niveau(def.id, j)
        var texte: String
        var base = Int.random(in: 7...11)
        let accidents = (def.pratique.accidents ?? []).filter { n <= ($0.maxNiveau ?? 5) }
        if let accident = accidents.shuffled().first(where: { Double.random(in: 0..<1) < $0.chance }) {
            texte = remplir(accident.text, j)
            if let eff = accident.effects { appliquer(eff, &j) }
            base = Int.random(in: 2...4)
        } else {
            texte = remplir(Competences.textePratique(def, niveau: n), j)
            if let eff = def.pratique.effects { appliquer(eff, &j) }
        }
        guard j.vivant else {
            joueur = j
            sauvegarder()
            return texte
        }
        let g = Competences.gagner(def.id, base, &j)
        if g.gain > 0 { texte += " (\(def.nom) +\(g.gain) XP)" }
        ajouterLigne(&j, texte)
        g.messages.forEach { ajouterLigne(&j, $0) }
        j.stats.borner()
        joueur = j
        sauvegarder()
        return ([texte] + g.messages).joined(separator: "\n\n")
    }

    /// Le cours est-il proposé à ce joueur (âge, niveau mini) ?
    func coursVisible(_ c: CompetenceCours) -> Bool {
        guard let j = joueur, j.vivant else { return false }
        if let m = c.minAge, j.age < m { return false }
        if let m = c.niveauMin, Competences.niveau(c.competence, j) < m { return false }
        return true
    }

    func coursDisponible(_ c: CompetenceCours) -> Bool {
        guard let j = joueur, coursVisible(c) else { return false }
        return !j.actionsAnnee.contains(Competences.cleeCours(c.id))
    }

    /// Suit un cours et renvoie le texte du résultat.
    func suivreCours(_ c: CompetenceCours) -> String {
        guard var j = joueur, j.vivant else { return "" }
        if let m = c.minAge, j.age < m { return "Ce cours est réservé aux \(m) ans et plus." }
        let n = Competences.niveau(c.competence, j)
        if let m = c.niveauMin, n < m { return "Il faut d'abord le niveau « \(Competences.nomNiveau(m)) »." }
        if j.actionsAnnee.contains(Competences.cleeCours(c.id)) {
            return "Tu as déjà suivi ce cours cette année. Le prof a demandé une ordonnance restrictive."
        }
        if let m = c.niveauMax, n > m {
            return "Tu en sais déjà plus que le prof. Il t'a demandé de partir, gentiment mais fermement."
        }
        // Les parents paient pour les mineurs… quand ils veulent bien.
        var cout = c.cout
        if j.age < 18 {
            if cout > 1000 && Double.random(in: 0..<1) < 0.4 {
                j.actionsAnnee.append(Competences.cleeCours(c.id))
                joueur = j
                sauvegarder()
                return ["Tes parents ont regardé le prix et ont ri pendant quatre minutes. C'est non.",
                        "« On n'est pas une banque. » Fin de la discussion.",
                        "Tes parents te proposent à la place un tutoriel sur YouTube. C'est non."].randomElement()!
            }
            cout = 0
        }
        if cout > 0 && j.argent < cout {
            return "Il te manque de l'argent : ce cours coûte \(Format.argent(cout))."
        }
        j.argent -= cout
        j.actionsAnnee.append(Competences.cleeCours(c.id))

        let mini = c.gain.first ?? 8
        let maxi = max(mini, c.gain.last ?? mini)
        var texte = remplir(c.textes.randomElement() ?? "Tu as suivi le cours.", j)
        if let eff = c.effects { appliquer(eff, &j) }
        let g = Competences.gagner(c.competence, Int.random(in: mini...maxi), &j)
        if g.gain > 0, let def = CatalogueCompetences.def(c.competence) {
            texte += " (\(def.nom) +\(g.gain) XP)"
        }
        ajouterLigne(&j, texte)
        g.messages.forEach { ajouterLigne(&j, $0) }
        j.stats.borner()
        joueur = j
        sauvegarder()
        return ([texte] + g.messages).joined(separator: "\n\n")
    }
}

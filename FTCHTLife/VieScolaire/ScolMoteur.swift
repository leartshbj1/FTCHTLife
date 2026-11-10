import Foundation

/// Candidat·e à l'élection de délégué·e.
struct ScolCandidat: Identifiable, Equatable {
    let id = UUID()
    var nom: String
    var slogan: String
    var votes: Int
    var estJoueur: Bool
}

struct ScolResultatElection: Equatable {
    var candidats: [ScolCandidat]
    var elu: Bool
    var texte: String
}

extension GameEngine {

    // MARK: - Accès

    /// État scolaire du joueur en cours (nil s'il n'y a pas de partie).
    var scolEtat: ScolEtat? {
        guard let j = joueur else { return nil }
        return ScolStockage.lire(j)
    }

    /// Modifie le joueur et son état scolaire en même temps, puis sauvegarde.
    func scolModifier(_ action: (inout Joueur, inout ScolEtat) -> Void) {
        guard var j = joueur else { return }
        var etat = ScolStockage.lire(j)
        action(&j, &etat)
        etat.popularite = ScolRegles.borne(etat.popularite)
        etat.faveurProfs = ScolRegles.borne(etat.faveurProfs)
        j.stats.borner()
        ScolStockage.ecrire(etat, &j)
        joueur = j
        sauvegarder()
        objectWillChange.send()
    }

    func scolTags(_ j: Joueur, _ etat: ScolEtat? = nil) -> Set<String> {
        tags(j).union(ScolRegles.tags(j, etat: etat))
    }

    /// Remplit les variables du module ({prof}, {matiere}, {classe}, {groupe}, {camarade}) puis celles du moteur.
    func scolRemplir(_ texte: String, _ j: Joueur, _ etat: ScolEtat, _ ctx: ScolContexte) -> String {
        var t = texte
        t = t.replacingOccurrences(of: "{prof}", with: ctx.prof)
        t = t.replacingOccurrences(of: "{matiere}", with: ScolDonnees.nomMatiere(ctx.matiere).lowercased())
        t = t.replacingOccurrences(of: "{classe}", with: ScolRegles.classe(min(17, max(11, j.age)), etat))
        t = t.replacingOccurrences(of: "{groupe}", with: ScolDonnees.groupe(etat.groupe)?.nom.lowercased() ?? "personne")
        t = t.replacingOccurrences(of: "{camarade}", with: ctx.camarade)
        return remplir(t, j)
    }

    // MARK: - Effets

    /// Applique des effets complets. Renvoie les lignes à ajouter (colles, groupe…).
    @discardableResult
    func scolAppliquer(_ eff: ScolEffetsComplets?, _ j: inout Joueur, _ etat: inout ScolEtat) -> [String] {
        guard let eff = eff else { return [] }
        if let m = eff.moteur { appliquer(m, &j) }
        guard let s = eff.ecole else { return [] }
        var lignes: [String] = []
        etat.popularite = ScolRegles.borne(etat.popularite + (s.popularity ?? 0))
        etat.faveurProfs = ScolRegles.borne(etat.faveurProfs + (s.teachers ?? 0))
        etat.bonusNotes += s.grades ?? 0
        if s.leaveGroup == true, let g = ScolDonnees.groupe(etat.groupe) {
            etat.groupe = nil
            etat.anneesDansGroupe = 0
            lignes.append("Tu ne fais plus partie de " + g.nom.lowercased() + ".")
        }
        if let id = s.joinGroup, id != etat.groupe, let g = ScolDonnees.groupe(id) {
            etat.groupe = id
            etat.anneesDansGroupe = 0
            lignes.append("👥 Tu fais maintenant partie de " + g.nom.lowercased() + ".")
        }
        if s.loseDelegate == true && etat.estDelegue {
            etat.estDelegue = false
            etat.promesse = nil
            lignes.append("Tu n'es plus " + j.g("délégué", "déléguée") + " de classe. Le pouvoir est éphémère.")
        }
        if let n = s.detention, n > 0 {
            etat.collesAnnee += n
            etat.collesTotal += n
            let colle = ScolDonnees.auHasard("colle", defaut: "Tu as passé deux heures à regarder une horloge qui avançait à reculons.")
            lignes.append("⏰ " + (n > 1 ? "\(n) heures de colle. " : "Heure de colle. ") + remplir(colle, j))
            if etat.collesAnnee >= 3 && !etat.convoqueCetteAnnee {
                lignes += scolPlanifierConvocation(j, &etat)
            }
        }
        if s.summonParents == true && !etat.convoqueCetteAnnee {
            lignes += scolPlanifierConvocation(j, &etat)
        }
        return lignes
    }

    private func scolPlanifierConvocation(_ j: Joueur, _ etat: inout ScolEtat) -> [String] {
        let t = scolTags(j, etat)
        let possibles = ScolDonnees.convocations.filter {
            ScolRegles.ageOK($0, j.age) && ScolRegles.conditionsOK($0.conditions, j, tags: t)
                && !($0.unique == true && etat.scenesVues.contains($0.id))
        }
        guard let s = ScolRegles.tirage(possibles, poids: { $0.weight ?? 1 }) else { return [] }
        etat.convoqueCetteAnnee = true
        etat.convocations += 1
        etat.aFaire.append(ScolTache(sorte: .convocation, ref: s.id))
        let lieu = j.age <= 14 ? "collège" : "lycée"
        return ["📨 Tes parents sont convoqués au \(lieu). Ça sent le roussi."]
    }

    // MARK: - Passage d'une année (appelé par le moteur dans vieillir)

    /// À appeler dans `vieillir()` après `j.age += 1`, avec les actions de l'année qui vient de finir.
    /// Termine l'année scolaire précédente (conseil de classe, brevet, bilan du délégué) et prépare la suivante.
    func scolPasserAnnee(_ j: inout Joueur, actionsPassees: [String]) -> [String] {
        var etat = ScolStockage.lire(j)
        var lignes: [String] = []
        let ancien = j.age - 1

        if (11...17).contains(ancien) && !j.aQuitteEcole && j.vivant {
            lignes += scolFinAnnee(&j, &etat, age: ancien, actions: actionsPassees)
        }
        etat.collesAnnee = 0
        etat.bonusNotes = 0
        etat.convoqueCetteAnnee = false
        etat.aFaire = []
        if etat.estDelegue {
            etat.estDelegue = false
            etat.promesse = nil
        }

        if ScolRegles.scolarise(j) {
            lignes += scolRentree(&j, &etat)
        }
        etat.popularite = ScolRegles.borne(etat.popularite)
        etat.faveurProfs = ScolRegles.borne(etat.faveurProfs)
        j.stats.borner()
        ScolStockage.ecrire(etat, &j)
        return lignes
    }

    /// Bonus (ou malus) sur la chance d'avoir le bac, entre -0,2 et +0,2.
    func scolBonusBac(_ j: Joueur) -> Double {
        let e = ScolStockage.lire(j)
        var b = 0.0
        if let n = e.noteGrandOral { b += (n - 10) * 0.015 }
        if let n = e.noteOralFrancais { b += (n - 10) * 0.01 }
        if let m = e.bulletins.last?.moyenne { b += (m - 10) * 0.02 }
        return min(0.2, max(-0.2, b))
    }

    private func scolRentree(_ j: inout Joueur, _ etat: inout ScolEtat) -> [String] {
        var lignes: [String] = []
        etat.lettreClasse = ["A", "B", "C", "D", "E", "F"].randomElement()!
        let classe = ScolRegles.classe(j.age, etat)
        if j.age == 11 {
            etat.popularite = ScolRegles.borne(45 + (j.stats.apparence - 50) / 4 + Int.random(in: -6...6))
            etat.faveurProfs = ScolRegles.borne(50 + (j.stats.intelligence - 50) / 5)
            lignes.append("🏫 Tu es en \(classe). Ton casier ne ferme pas et quelqu'un a déjà écrit son prénom dessus.")
        } else if j.age == 15 {
            etat.popularite = (etat.popularite + 50) / 2
            etat.faveurProfs = (etat.faveurProfs + 50) / 2
            lignes.append("🏫 Rentrée en \(classe). Nouveau lycée, réputation remise à moitié à zéro.")
        }

        // Situations de l'année.
        let t = scolTags(j, etat)
        var possibles = ScolDonnees.situations.filter {
            ScolRegles.ageOK($0, j.age) && ScolRegles.conditionsOK($0.conditions, j, tags: t)
                && !($0.unique == true && etat.scenesVues.contains($0.id))
        }
        let nombre = Double.random(in: 0...1) < 0.5 ? 2 : 1
        for _ in 0..<nombre {
            guard let s = ScolRegles.tirage(possibles, poids: { $0.weight ?? 1 }) else { break }
            possibles.removeAll { $0.id == s.id }
            etat.aFaire.append(ScolTache(sorte: .situation, ref: s.id))
        }

        // Voyage scolaire en 4e et en 1re.
        if j.age == 13 || j.age == 16 {
            let niveau = ScolRegles.niveau(j.age)
            let voyages = ScolDonnees.voyages.filter { ($0.niveau == niveau || $0.niveau == "tous") && !etat.voyages.contains($0.id) }
            if let v = voyages.randomElement() {
                etat.aFaire.append(ScolTache(sorte: .voyage, ref: v.id))
                lignes.append("🚌 Cette année, voyage scolaire : \(v.destination) !")
            }
        }

        // Oraux.
        if j.age == 16 && etat.noteOralFrancais == nil {
            etat.aFaire.append(ScolTache(sorte: .oral, ref: "francais"))
        }
        if j.age == 17 && etat.noteGrandOral == nil {
            etat.aFaire.append(ScolTache(sorte: .oral, ref: "grand_oral"))
        }
        return lignes
    }

    private func scolFinAnnee(_ j: inout Joueur, _ etat: inout ScolEtat, age: Int, actions: [String]) -> [String] {
        var lignes: [String] = []

        // Ce qui n'a pas été fait.
        for tache in etat.aFaire {
            switch tache.sorte {
            case .oral:
                let note = Double(Int.random(in: 2...6))
                if tache.ref == "francais" { etat.noteOralFrancais = note } else { etat.noteGrandOral = note }
                lignes.append("🎤 Tu ne t'es pas " + j.g("présenté", "présentée") + " à ton oral. Le jury t'a mis \(ScolRegles.formatNote(note))/20 par pure politesse.")
            case .convocation:
                for i in j.relations.indices where j.relations[i].type.estParent && j.relations[i].vivant {
                    j.relations[i].lien = Stats.borne(j.relations[i].lien - 6)
                }
                lignes.append("📨 Tu as « oublié » de donner la convocation à tes parents. Le collège les a appelés directement.")
            case .situation, .voyage:
                break
            }
        }

        // Le groupe.
        if let g = ScolDonnees.groupe(etat.groupe) {
            scolAppliquer(g.parAn, &j, &etat)
            etat.anneesDansGroupe += 1
        }

        // La popularité bouge un peu toute seule.
        etat.popularite = ScolRegles.borne(etat.popularite + (j.stats.apparence - 50) / 12 + Int.random(in: -3...3))
        if etat.popularite >= 75 { j.stats.bonheur += 3 }
        if etat.popularite < 25 { j.stats.bonheur -= 4 }

        // Conseil de classe.
        let bulletin = scolGenererBulletin(j, etat, age: age, actions: actions)
        etat.bulletins.append(bulletin)
        lignes.append("📋 Conseil de classe de \(bulletin.classe) : \(ScolRegles.formatNote(bulletin.moyenne)) de moyenne. \(bulletin.mention.titre).")
        let parents: Int
        switch bulletin.mention {
        case .felicitations: j.stats.bonheur += 6; parents = 6
        case .compliments: j.stats.bonheur += 4; parents = 4
        case .encouragements: j.stats.bonheur += 2; parents = 2
        case .rien: parents = 0
        case .avertissementTravail, .avertissementConduite: j.stats.bonheur -= 4; parents = -6
        }
        if parents != 0 {
            for i in j.relations.indices where j.relations[i].type.estParent && j.relations[i].vivant {
                j.relations[i].lien = Stats.borne(j.relations[i].lien + parents)
            }
        }

        // Bilan du mandat de délégué·e.
        if etat.estDelegue {
            if let p = ScolDonnees.promesse(etat.promesse), p.realiste == false {
                etat.popularite -= 6
                lignes.append("🗳️ Bilan de ton mandat : " + remplir(p.bilan ?? "ta promesse n'a pas été tenue.", j))
            } else {
                etat.popularite += 3
                lignes.append("🗳️ Tu as tenu tes promesses de " + j.g("délégué", "déléguée") + ". Un exploit politique rarissime.")
            }
        }

        // Brevet à la fin de la 3e.
        if age == 14 {
            let chance = min(0.97, max(0.2, 0.3 + bulletin.moyenne / 25))
            if Double.random(in: 0...1) < chance {
                etat.brevet = true
                j.stats.bonheur += 5
                let mention = bulletin.moyenne >= 16 ? " avec mention très bien" : bulletin.moyenne >= 14 ? " avec mention bien" : ""
                lignes.append("🎓 Tu as eu ton brevet\(mention) ! Ta grand-mère l'a encadré à côté du crucifix.")
            } else {
                etat.brevet = false
                j.stats.bonheur -= 5
                lignes.append("Tu as raté ton brevet. Personne ne te le redemandera jamais, mais quand même.")
            }
        }
        return lignes
    }

    private func scolGenererBulletin(_ j: Joueur, _ etat: ScolEtat, age: Int, actions: [String]) -> ScolBulletin {
        var base = 4 + Double(j.stats.intelligence) * 0.12
        base += Double(etat.faveurProfs - 50) / 25
        base += etat.bonusNotes
        if actions.contains("etudier") { base += 1.5 }
        if actions.contains("secher") { base -= 1 }
        base += Double.random(in: -1.5...1.5)

        var notes: [ScolNote] = []
        for m in ScolDonnees.matieres(age: age, lv2: ScolRegles.lv2(j)) {
            var n = base + Double.random(in: -3...3)
            if m == "eps" {
                n = 9 + Double(j.stats.sante - 50) / 8 + Double.random(in: -2...3)
                if etat.groupe == "sportifs" { n += 2 }
            }
            if m == "arts" || m == "musique" {
                n += Double(j.stats.bonheur - 50) / 20
                if etat.groupe == "artistes" { n += 2 }
            }
            n = ScolRegles.arrondi(n)
            let tr = ScolRegles.tranche(n)
            let specifiques = ScolDonnees.textes("appreciation").filter { $0.matiere == m && $0.tranche == tr }
            let generiques = ScolDonnees.textes("appreciation").filter { $0.matiere == "*" && $0.tranche == tr }
            let texte = (Double.random(in: 0...1) < 0.65 ? specifiques.randomElement() : nil)
                ?? generiques.randomElement() ?? specifiques.randomElement()
            notes.append(ScolNote(matiere: m, note: n, appreciation: remplir(texte?.text ?? "Bilan à préciser.", j)))
        }
        let moyenne = ScolRegles.arrondi(notes.map(\.note).reduce(0, +) / Double(max(1, notes.count)))

        let mention: ScolMention
        if etat.collesAnnee >= 2 || etat.faveurProfs < 25 {
            mention = .avertissementConduite
        } else if moyenne < 8 {
            mention = .avertissementTravail
        } else if moyenne >= 16 {
            mention = .felicitations
        } else if moyenne >= 14 {
            mention = .compliments
        } else if moyenne >= 12 || (moyenne >= 10 && moyenne - (etat.bulletins.last?.moyenne ?? 20) >= 1.5) {
            mention = .encouragements
        } else {
            mention = .rien
        }

        var traits: [String] = []
        if etat.popularite >= 70 { traits += ["populaire", "bavard"] }
        if etat.popularite < 30 { traits.append("invisible") }
        if etat.faveurProfs >= 70 { traits.append("chouchou") }
        if etat.faveurProfs < 35 { traits.append("insolent") }
        if actions.contains("secher") { traits.append("absent") }
        if etat.estDelegue { traits.append("delegue") }
        if etat.collesAnnee >= 2 { traits.append("colles") }
        if let g = etat.groupe { traits.append(g) }
        var generale = ScolDonnees.auHasard("generale", defaut: "Année terminée. C'est déjà ça.") { $0.mention == mention.rawValue }
        if let trait = traits.randomElement() {
            let phrase = ScolDonnees.auHasard("comportement", defaut: "") { $0.trait == trait }
            if !phrase.isEmpty { generale += " " + phrase }
        }
        let mot = etat.estDelegue ? ScolDonnees.auHasard("delegue", defaut: "Tu as défendu la classe avec courage et une voix tremblante.") : nil

        return ScolBulletin(age: age, classe: ScolRegles.classe(age, etat), moyenne: moyenne, notes: notes,
                            appreciationGenerale: remplir(generale, j), mention: mention,
                            motDuDelegue: mot.map { remplir($0, j) }, colles: etat.collesAnnee)
    }

    // MARK: - Scènes (situations, convocations, voyage)

    func scolScene(_ tache: ScolTache) -> ScolScene? {
        switch tache.sorte {
        case .situation: return ScolDonnees.situation(tache.ref)
        case .convocation: return ScolDonnees.convocation(tache.ref)
        default: return nil
        }
    }

    /// Texte d'une scène, avec les variables remplies.
    func scolTexte(_ texte: String, _ ctx: ScolContexte) -> String {
        guard let j = joueur else { return texte }
        return scolRemplir(texte, j, ScolStockage.lire(j), ctx)
    }

    /// Le joueur choisit une réponse. Renvoie le texte du résultat (avec les éventuelles lignes en plus).
    func scolChoisir(_ scene: ScolScene, choix index: Int, ctx: ScolContexte, texteAffiche: String? = nil, tache: ScolTache?) -> String {
        guard let j0 = joueur, scene.choices.indices.contains(index) else { return "" }
        let c = scene.choices[index]
        let issue = ScolRegles.tirage(c.outcomes)
        let etat0 = ScolStockage.lire(j0)
        let texteScene = texteAffiche ?? scolRemplir(scene.text, j0, etat0, ctx)
        let resultat = scolRemplir(issue?.text ?? "Il ne se passe rien.", j0, etat0, ctx)
        var extra: [String] = []
        scolModifier { j, etat in
            ajouterLigne(&j, "\(texteScene) → \(c.label). \(resultat)")
            extra = scolAppliquer(issue?.effects, &j, &etat)
            for l in extra { ajouterLigne(&j, l) }
            if !etat.scenesVues.contains(scene.id) { etat.scenesVues.append(scene.id) }
            if let t = tache { etat.aFaire.removeAll { $0 == t } }
        }
        return ([resultat] + extra).joined(separator: "\n\n")
    }

    /// Ferme une tâche sans la jouer (« plus tard » ne la supprime pas : seule la fin d'année le fait).
    func scolRetirer(_ tache: ScolTache) {
        scolModifier { _, etat in etat.aFaire.removeAll { $0 == tache } }
    }

    // MARK: - Voyage

    /// Le joueur part : les parents paient. Renvoie le texte de départ et les 2 scènes à jouer.
    func scolPartirEnVoyage(_ v: ScolVoyage) -> (texte: String, scenes: [ScolScene]) {
        var texte = ""
        scolModifier { j, _ in
            let parents = j.relations.indices.filter { j.relations[$0].type.estParent && j.relations[$0].vivant }
            if j.age >= 18 {
                j.argent -= v.cout
                texte = "Tu as payé \(Format.argent(v.cout))."
            } else if let i = parents.first(where: { j.relations[$0].argent >= v.cout }) {
                j.relations[i].argent -= v.cout
                texte = "\(j.relations[i].designation) a payé \(Format.argent(v.cout)) en soupirant très fort."
            } else if let i = parents.first {
                j.relations[i].lien = Stats.borne(j.relations[i].lien - 3)
                texte = "\(j.relations[i].designation) a payé en quatre fois et te le rappellera jusqu'à tes 40 ans."
            } else {
                texte = "Le collège a payé ton voyage avec la caisse de solidarité. Tout le monde le sait."
            }
            j.stats.bonheur += 5
        }
        return (texte, Array(v.scenes.shuffled().prefix(2)))
    }

    /// Fin du voyage (ou refus). Écrit le journal et retire la tâche.
    func scolTerminerVoyage(_ v: ScolVoyage, parti: Bool) -> String {
        var texte = ""
        scolModifier { j, etat in
            etat.aFaire.removeAll { $0.sorte == .voyage }
            if parti {
                etat.voyages.append(v.id)
                etat.popularite += 3
                texte = remplir(v.retour, j)
                ajouterLigne(&j, "✈️ Voyage scolaire : \(v.destination). " + texte)
            } else {
                etat.popularite -= 3
                texte = "Tu restes en cours avec les trois autres élèves qui ne partent pas. Vous regardez un documentaire sur \(v.destination)."
                ajouterLigne(&j, texte)
            }
        }
        return texte
    }

    // MARK: - Oraux

    func scolTirerOral(_ examen: String) -> ScolOral? {
        ScolDonnees.oraux.filter { $0.examen == examen && $0.questions.count >= 1 }.randomElement()
    }

    /// Calcule la note de l'oral et l'enregistre. Renvoie la note et le commentaire.
    func scolTerminerOral(examen: String, points: Int, maximum: Int) -> (note: Double, texte: String) {
        guard let j0 = joueur else { return (0, "") }
        var n = Double(points) / Double(max(1, maximum)) * 17
        if j0.actionsAnnee.contains("etudier") { n += 1.5 }
        n += Double(j0.stats.intelligence - 50) / 25
        let note = ScolRegles.arrondi(n)
        let nom = examen == "francais" ? "l'oral de français" : "le grand oral"
        let commentaire: String
        switch note {
        case 16...: commentaire = "Le jury s'est levé pour t'applaudir. Un membre a demandé ton autographe."
        case 12..<16: commentaire = "Le jury a souri deux fois. C'est énorme pour un jury."
        case 8..<12: commentaire = "Le jury a pris des notes. Peut-être une liste de courses."
        default: commentaire = "Un membre du jury s'est endormi. L'autre a envié le premier."
        }
        let texte = "🎤 \(ScolRegles.formatNote(note))/20 à \(nom). \(commentaire)"
        scolModifier { j, etat in
            if examen == "francais" { etat.noteOralFrancais = note } else { etat.noteGrandOral = note }
            etat.aFaire.removeAll { $0.sorte == .oral && $0.ref == examen }
            j.stats.bonheur += note >= 12 ? 5 : -3
            ajouterLigne(&j, texte)
        }
        return (note, texte)
    }

    // MARK: - Groupes

    func scolRejoindre(_ g: ScolGroupe) -> String {
        guard let j0 = joueur, ScolRegles.scolarise(j0) else { return "Tu n'es pas au collège ou au lycée." }
        let etat0 = ScolStockage.lire(j0)
        if etat0.groupe == g.id { return "Tu fais déjà partie de \(g.nom.lowercased())." }
        if j0.actionsAnnee.contains("scol_rejoindre") { return "Tu as déjà tenté ta chance auprès d'un groupe cette année." }
        var chance = 0.85
        if let r = g.requis, ScolRegles.stat(r.stat, j0, etat0) < r.min { chance = 0.2 }
        let accepte = Double.random(in: 0...1) < chance
        let ctx = ScolContexte.nouveau(j0)
        var texte = ""
        scolModifier { j, etat in
            j.actionsAnnee.append("scol_rejoindre")
            if accepte {
                if let ancien = ScolDonnees.groupe(etat.groupe) { ajouterLigne(&j, "Tu quittes \(ancien.nom.lowercased()).") }
                etat.groupe = g.id
                etat.anneesDansGroupe = 0
                etat.popularite += 3
                j.stats.bonheur += 4
                texte = scolRemplir(g.accepte, j, etat, ctx)
                ajouterLigne(&j, "👥 " + texte)
            } else {
                j.stats.bonheur -= 3
                etat.popularite -= 2
                texte = scolRemplir(g.refuse, j, etat, ctx)
                ajouterLigne(&j, texte)
            }
        }
        return texte
    }

    func scolQuitterGroupe() -> String {
        guard let j0 = joueur, let g = ScolDonnees.groupe(ScolStockage.lire(j0).groupe) else { return "Tu n'as pas de groupe." }
        let ctx = ScolContexte.nouveau(j0)
        var texte = ""
        scolModifier { j, etat in
            texte = scolRemplir(g.quitte, j, etat, ctx)
            etat.groupe = nil
            etat.anneesDansGroupe = 0
            etat.popularite -= 2
            ajouterLigne(&j, texte)
        }
        return texte
    }

    // MARK: - Actions

    func scolActions(_ j: Joueur) -> [ScolAction] {
        guard ScolRegles.scolarise(j) else { return [] }
        let etat = ScolStockage.lire(j)
        let t = scolTags(j)
        return ScolDonnees.actions.filter {
            j.age >= $0.minAge && j.age <= $0.maxAge
                && ($0.groupe == nil || $0.groupe == etat.groupe)
                && ScolRegles.conditionsOK($0.conditions, j, tags: t)
        }
    }

    func scolActionFaite(_ a: ScolAction) -> Bool {
        joueur?.actionsAnnee.contains("scol_" + a.id) ?? true
    }

    func scolFaireAction(_ a: ScolAction) -> String {
        guard let j0 = joueur, ScolRegles.scolarise(j0) else { return "" }
        if scolActionFaite(a) { return "Tu l'as déjà fait cette année. Garde un peu de mystère." }
        let issue = ScolRegles.tirage(a.outcomes)
        let ctx = ScolContexte.nouveau(j0)
        var morceaux: [String] = []
        scolModifier { j, etat in
            j.actionsAnnee.append("scol_" + a.id)
            let texte = scolRemplir(issue?.text ?? "Il ne se passe rien.", j, etat, ctx)
            ajouterLigne(&j, a.titre + " : " + texte)
            morceaux.append(texte)
            let extra = scolAppliquer(issue?.effects, &j, &etat)
            for l in extra { ajouterLigne(&j, l) }
            morceaux += extra
        }
        return morceaux.joined(separator: "\n\n")
    }

    // MARK: - Élection de délégué·e

    func scolPeutSePresenter(_ j: Joueur) -> Bool {
        ScolRegles.scolarise(j) && ScolStockage.lire(j).electionAge != j.age
    }

    func scolSePresenter(promesse: ScolTexte) -> ScolResultatElection? {
        guard let j0 = joueur, scolPeutSePresenter(j0) else { return nil }
        let etat0 = ScolStockage.lire(j0)
        let effectif = Int.random(in: 24...32)

        var scoreJoueur = Double(etat0.popularite) * 0.6 + Double(promesse.bonus ?? 0) + Double.random(in: -12...12)
        if etat0.groupe == "stars" { scoreJoueur += 8 }
        if etat0.collesAnnee > 0 { scoreJoueur -= 4 }
        var scores: [(String, String, Double, Bool)] = [(j0.prenom, promesse.discours ?? promesse.text, max(1, scoreJoueur), true)]
        var slogans = ScolDonnees.textes("adversaire").map(\.text).shuffled()
        for _ in 0..<Int.random(in: 1...3) {
            let g = Genre.allCases.randomElement()!
            let slogan = slogans.isEmpty ? "« Votez pour moi, j'ai un stylo quatre couleurs. »" : slogans.removeFirst()
            scores.append((Donnees.prenom(g), slogan, Double.random(in: 18...58), false))
        }
        let total = scores.reduce(0.0) { $0 + $1.2 }
        var candidats = scores.map { s in
            ScolCandidat(nom: s.0, slogan: s.1, votes: Int((s.2 / total * Double(effectif)).rounded()), estJoueur: s.3)
        }
        // Les arrondis doivent retomber sur l'effectif de la classe.
        let ecart = effectif - candidats.reduce(0) { $0 + $1.votes }
        if let i = candidats.indices.max(by: { candidats[$0].votes < candidats[$1].votes }) {
            candidats[i].votes = max(0, candidats[i].votes + ecart)
        }
        candidats.sort { $0.votes > $1.votes }
        let maxAutres = candidats.filter { !$0.estJoueur }.map(\.votes).max() ?? 0
        let votesJoueur = candidats.first { $0.estJoueur }?.votes ?? 0
        let elu = votesJoueur > maxAutres
        let premier = candidats.first { !$0.estJoueur }?.nom ?? "quelqu'un"

        var texte = ""
        scolModifier { j, etat in
            etat.electionAge = j.age
            if elu {
                etat.estDelegue = true
                etat.promesse = promesse.id
                etat.mandats += 1
                etat.popularite += 5
                etat.faveurProfs += 2
                j.stats.bonheur += 8
                let titre = j.g("élu délégué", "élue déléguée")
                let classe = ScolRegles.classe(j.age, etat)
                texte = "🗳️ Tu es \(titre) de \(classe) avec \(votesJoueur) voix sur \(effectif) ! Ton premier acte : réclamer un bureau."
            } else if votesJoueur == maxAutres {
                j.stats.bonheur -= 4
                texte = "🗳️ Égalité avec \(premier) ! Départage à pile ou face… perdu. La démocratie est cruelle."
            } else {
                j.stats.bonheur -= 4
                etat.popularite -= 1
                texte = "🗳️ \(votesJoueur) voix sur \(effectif). C'est \(premier) qui est " + "élu·e. Tu as voté pour toi, au moins ?"
            }
            ajouterLigne(&j, texte)
        }
        return ScolResultatElection(candidats: candidats, elu: elu, texte: texte)
    }

    // MARK: - Libellés

    func scolTitre(_ t: ScolTache) -> (titre: String, sousTitre: String, icone: String) {
        switch t.sorte {
        case .situation: return ("Une situation au bahut", "Il se passe un truc. Viens voir.", "exclamationmark.bubble.fill")
        case .convocation: return ("Convocation des parents", "Le carnet de correspondance a parlé.", "envelope.badge.fill")
        case .voyage:
            let d = ScolDonnees.voyage(t.ref)?.destination ?? "?"
            return ("Voyage scolaire : \(d)", "Autorisation de sortie à faire signer.", "bus.fill")
        case .oral:
            return t.ref == "francais"
                ? ("Oral de français", "Le jury t'attend. 15 secondes par question.", "mic.fill")
                : ("Grand oral", "Ton bac en dépend un peu. 15 secondes par question.", "mic.fill")
        }
    }
}

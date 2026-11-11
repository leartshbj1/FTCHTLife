import Foundation

// Actions propres à chaque réseau (Instaglam, TikTac, Twitteur, VousTube, OnlyFesses)
// et revenus de VousTube et OnlyFesses. Voir docs/PHONE.md.

extension PhoneEngine {

    static let prixShooting = 800
    static let prixMateriel = [300, 1_500, 6_000]
    static let nomsMateriel = ["un micro-cravate et une lampe", "une vraie caméra", "un studio complet avec fond vert"]
    static let prixOnlyPossibles = [5, 10, 20, 50]

    // MARK: - Qualité des posts

    /// Bonus de qualité d'un post selon l'appli (shooting photo, matériel VousTube).
    static func bonusQualite(_ app: PhoneApp, _ t: PhoneEtat) -> Double {
        var b = 0.0
        if t.nombreActions("boost_" + app.rawValue) > 0 { b += 0.15 }
        if app == .voustube { b += 0.06 * Double(t.materielTube) }
        if app == .onlyfesses { b -= Double(max(0, t.prixOnly - 10)) / 200 }
        return b
    }

    // MARK: - Revenus de l'année

    static func revenusSpeciaux(_ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) -> [String] {
        var lignes: [String] = []

        // VousTube : la pub paie à partir de 1 000 abonnés.
        let vt = t.compte(.voustube).abonnes
        if vt >= 1_000 && j.age >= 16 {
            let revenu = Int(Double(vt) * Double.random(in: 0.05...0.15) * (1 + 0.15 * Double(t.materielTube)))
            if revenu > 0 {
                j.argent += revenu
                lignes.append("📺 VousTube te verse \(Format.argent(revenu)) de revenus publicitaires. Tu commences tes vidéos par « avant de commencer, un mot de notre sponsor ».")
            }
        } else if vt >= 1_000 {
            lignes.append("📺 Ta chaîne VousTube pourrait rapporter de l'argent, mais il faut 16 ans. L'argent dort sur un compte que tes parents « gèrent ».")
        }

        // OnlyFesses : abonnements mensuels, moins la commission de la plateforme (20 %).
        if t.onlyActif && j.age >= 18 {
            let abonnes = t.compte(.onlyfesses).abonnes
            let revenu = Int(Double(abonnes) * Double(t.prixOnly) * 12 * 0.8 * Double.random(in: 0.2...0.35))
            if revenu > 0 {
                j.argent += revenu
                lignes.append("🔒 OnlyFesses : \(Format.argent(revenu)) d'abonnements cette année. Ton banquier a posé une question. Tu as répondu « consulting ».")
            }
            lignes += decouverteOnly(&j, &t)
        }
        return lignes
    }

    /// Chaque année, quelqu'un peut découvrir le compte OnlyFesses.
    private static func decouverteOnly(_ j: inout Joueur, _ t: inout PhoneEtat) -> [String] {
        let abonnes = t.compte(.onlyfesses).abonnes
        let chance = min(0.5, 0.08 + Double(abonnes) / 40_000)
        guard Double.random(in: 0...1) < chance else { return [] }
        var qui: [String] = []
        if j.partenaireActuel != nil { qui.append("partenaire") }
        if !j.parentsVivants.isEmpty { qui.append("famille") }
        if j.emploi != nil { qui.append("travail") }
        if j.enfantsVivants.contains(where: { $0.age >= 12 }) { qui.append("enfants") }
        qui.removeAll { t.onlyDecouvertPar.contains($0) }
        guard let cible = qui.randomElement() else { return [] }
        return reveleOnly(cible, &j, &t)
    }

    /// Quelqu'un tombe sur le compte OnlyFesses. Conséquences fortes.
    static func reveleOnly(_ cible: String, _ j: inout Joueur, _ t: inout PhoneEtat) -> [String] {
        t.onlyDecouvertPar.append(cible)
        switch cible {
        case "partenaire":
            guard let p = j.partenaireActuel, let i = j.relations.firstIndex(where: { $0.id == p.id }) else { return [] }
            if Double.random(in: 0...1) < 0.35 {
                j.relations[i].lien = Stats.borne(p.lien + 3)
                return ["🔒 \(p.prenom) a découvert ton compte OnlyFesses. Après un long silence : « Bon. Tu déclares bien tout aux impôts, au moins ? » \(p.pronom.capitalized) gère maintenant ta compta."]
            }
            j.relations[i].lien = Stats.borne(p.lien - 25)
            j.stats.bonheur -= 8
            var c = j.coeurEtat; c.crise = max(c.crise, 2); j.coeurEtat = c
            return ["🔒 \(p.prenom) a découvert ton compte OnlyFesses, par une collègue « qui est tombée dessus par hasard ». Dispute jusqu'à l'aube : ce n'est pas le contenu, c'est le secret."]
        case "famille":
            for k in j.relations.indices where j.relations[k].type.estParent && j.relations[k].vivant {
                j.relations[k].lien = Stats.borne(j.relations[k].lien - 20)
            }
            j.stats.bonheur -= 8
            return ["🔒 Ta famille a découvert ton compte OnlyFesses. Le repas de dimanche a duré 12 minutes. Personne n'a parlé, sauf ton oncle, pour demander le lien."]
        case "travail":
            j.stats.bonheur -= 10
            var rep = j.repercussions ?? RepercussionsEtat()
            Repercussions.appliquerDrapeaux(poser: ["honte_publique"], retirer: nil, age: j.age, etat: &rep)
            j.repercussions = rep
            return ["🔒 Au travail, quelqu'un a reconnu ton compte OnlyFesses. Depuis, la machine à café se tait quand tu arrives et ton manager évite ton regard en réunion."]
        default:
            for k in j.relations.indices where j.relations[k].type == .enfant && j.relations[k].vivant && j.relations[k].age >= 12 {
                j.relations[k].lien = Stats.borne(j.relations[k].lien - 15)
            }
            j.stats.bonheur -= 10
            return ["🔒 Tes enfants ont appris l'existence de ton compte OnlyFesses par des camarades de classe. C'est la pire semaine de leur vie, et ils te le font savoir."]
        }
    }

    // MARK: - Actions spéciales

    struct ActionReseau: Identifiable {
        let id: String
        let titre: String
        let sousTitre: String
        let icone: String
        let actif: Bool
    }

    static func actionsSpeciales(_ app: PhoneApp, _ j: Joueur, _ t: PhoneEtat) -> [ActionReseau] {
        guard t.aTelephone, j.age >= app.ageMin else { return [] }
        let compte = t.compte(app)
        let detox = t.detoxCetteAnnee
        switch app {
        case .pozz:
            var a = [ActionReseau(id: "shooting", titre: "Shooting photo pro", sousTitre: "\(Format.argent(prixShooting)) · tes posts de l'année seront plus beaux",
                                  icone: "camera.filters", actif: !detox && t.nombreActions("boost_pozz") == 0 && j.age >= 16)]
            if let p = j.partenaireActuel {
                a.append(ActionReseau(id: "photo_couple", titre: "Poster une photo avec \(p.prenom)", sousTitre: "une fois par an",
                                      icone: "heart.square.fill", actif: !detox && t.nombreActions("photo_couple") == 0))
            }
            return a
        case .tremousse:
            return [ActionReseau(id: "challenge", titre: "Lancer un challenge", sousTitre: "une fois par an · peut buzzer, ou finir aux urgences",
                                 icone: "flame.fill", actif: !detox && t.nombreActions("challenge") == 0)]
        case .ronchon:
            return [
                ActionReseau(id: "clash", titre: "Clasher une célébrité", sousTitre: "une fois par an · tout ou rien",
                             icone: "bolt.fill", actif: !detox && t.nombreActions("clash") == 0 && compte.abonnes >= 100),
                ActionReseau(id: "menage", titre: "Supprimer tes vieux messages", sousTitre: "efface peut-être un bad buzz",
                             icone: "trash.fill", actif: t.nombreActions("menage") == 0 && compte.posts >= 5),
            ]
        case .voustube:
            var a: [ActionReseau] = []
            if t.materielTube < prixMateriel.count {
                let n = t.materielTube
                a.append(ActionReseau(id: "materiel", titre: "Acheter \(nomsMateriel[n])", sousTitre: "\(Format.argent(prixMateriel[n])) · vidéos meilleures, plus de revenus",
                                      icone: "video.badge.plus", actif: j.argent >= prixMateriel[n] || j.age < 18))
            }
            a.append(ActionReseau(id: "collab", titre: "Collab avec un gros vidéaste", sousTitre: "une fois par an · il faut 5 000 abonnés",
                                  icone: "person.2.wave.2.fill", actif: !detox && t.nombreActions("collab") == 0 && compte.abonnes >= 5_000))
            if t.badBuzzRestant > 0 {
                a.append(ActionReseau(id: "excuses", titre: "Vidéo d'excuses", sousTitre: "fond gris, pull sobre, regard humide",
                                      icone: "face.dashed", actif: t.nombreActions("excuses") == 0))
            }
            return a
        case .onlyfesses:
            if t.onlyFerme {
                return [ActionReseau(id: "rouvrir", titre: "Rouvrir ton compte", sousTitre: "tes anciens abonnés sont partis",
                                     icone: "lock.open.fill", actif: true)]
            }
            return [
                ActionReseau(id: "prix", titre: "Changer le prix (\(t.prixOnly) €/mois)", sousTitre: "plus cher = moins d'abonnés, mais plus rentables",
                             icone: "eurosign.circle.fill", actif: true),
                ActionReseau(id: "perso", titre: "Accepter une demande personnalisée", sousTitre: "une fois par an · très bien payé, et risqué",
                             icone: "envelope.badge.fill", actif: !detox && t.nombreActions("perso") == 0 && compte.abonnes >= 100),
                ActionReseau(id: "fermer", titre: "Fermer le compte", sousTitre: "plus de revenus, mais plus de risques non plus",
                             icone: "xmark.octagon.fill", actif: compte.posts > 0),
            ]
        case .pecho:
            return []
        }
    }

    static func faireAction(_ id: String, _ app: PhoneApp, _ j: inout Joueur, _ t: inout PhoneEtat, engine: GameEngine) -> String {
        var c = t.compte(app)
        let a = Double(c.abonnes)
        var texte: String
        switch id {
        case "shooting":
            guard j.argent >= prixShooting else { return "Il te faut \(Format.argent(prixShooting)). Un selfie dans l'ascenseur, peut-être ?" }
            j.argent -= prixShooting
            t.actionsAnnee.append("boost_pozz")
            texte = "Shooting photo avec un pro qui dit « sublime » toutes les quatre secondes. Tu as 600 photos. Tu en aimes deux."

        case "photo_couple":
            t.actionsAnnee.append("photo_couple")
            let gain = Int.random(in: 5...40) + Int(a * Double.random(in: 0.01...0.04))
            c.abonnes += gain
            if let p = j.partenaireActuel, let i = j.relations.firstIndex(where: { $0.id == p.id }) {
                j.relations[i].lien = Stats.borne(p.lien + 6)
                texte = "Photo de couple avec \(p.prenom) au coucher du soleil, légende « mon tout ». +\(PhoneFormat.nombre(gain)) abonnés et un lien plus fort."
                if let l = j.coeurEtat.liaison {
                    var e = j.coeurEtat
                    e.liaison?.intensite = Stats.borne(l.intensite - 8)
                    j.coeurEtat = e
                    texte += " \(l.prenom) a liké. Puis retiré son like. Puis t'a écrit « sympa ». Aïe."
                }
            } else {
                texte = "Tu postes une photo de couple. Sans couple. C'est une photo de toi et ton reflet."
            }

        case "challenge":
            t.actionsAnnee.append("challenge")
            let r = Double.random(in: 0..<1)
            if r < 0.2 {
                let gain = Int.random(in: 2_000...40_000) + Int(a * Double.random(in: 0.2...0.6))
                c.abonnes += gain
                j.stats.bonheur += 10
                texte = "Ton challenge « danse du frigo » est repris par des millions de gens. Même un ministre l'a fait (mal). +\(PhoneFormat.nombre(gain)) abonnés."
            } else if r < 0.55 {
                let gain = Int.random(in: 10...300)
                c.abonnes += gain
                texte = "Ton challenge est repris par 14 personnes, dont ta tante. +\(PhoneFormat.nombre(gain)) abonnés."
            } else if r < 0.8 {
                j.stats.sante -= 12
                j.stats.bonheur -= 5
                texte = "Ton challenge « sauter par-dessus une trottinette » finit aux urgences. Plâtre au poignet. La vidéo de la chute, elle, cartonne chez les autres."
            } else {
                let perte = Int(a * Double.random(in: 0.1...0.25))
                c.abonnes = max(0, c.abonnes - perte)
                t.badBuzzRestant = 2
                j.stats.karma -= 4
                texte = "Ton challenge est jugé dangereux. Un journal titre « La folie TikTac ». Tu perds \(PhoneFormat.nombre(perte)) abonnés."
            }

        case "clash":
            t.actionsAnnee.append("clash")
            let chance = 0.2 + Double(j.stats.intelligence) / 300
            let r = Double.random(in: 0..<1)
            if r < chance {
                let gain = Int.random(in: 1_000...20_000) + Int(a * Double.random(in: 0.2...0.5))
                c.abonnes += gain
                j.stats.bonheur += 8
                texte = "Tu clashes un chanteur très connu en une phrase. Il répond en trois paragraphes : tu as gagné. +\(PhoneFormat.nombre(gain)) abonnés."
            } else if r < chance + 0.35 {
                texte = "Tu clashes une star de la télé. Elle ne répond pas. Ses fans, si. Pendant une semaine. Personne n'a gagné."
                j.stats.bonheur -= 3
            } else {
                let perte = Int(a * Double.random(in: 0.1...0.3))
                c.abonnes = max(0, c.abonnes - perte)
                t.badBuzzRestant = 2
                j.stats.bonheur -= 8
                let amende = j.age >= 18 ? 1_500 : 0
                j.argent -= amende
                texte = "Ton clash tourne au fiasco : la célébrité porte plainte pour diffamation. Tu perds \(PhoneFormat.nombre(perte)) abonnés" + (amende > 0 ? " et \(Format.argent(amende)) d'avocat." : ".")
            }

        case "menage":
            t.actionsAnnee.append("menage")
            if t.badBuzzRestant > 0 && Double.random(in: 0...1) < 0.5 {
                t.badBuzzRestant = 0
                texte = "Tu supprimes 1 400 vieux messages en une nuit. Le bad buzz s'éteint faute de preuves."
            } else if t.badBuzzRestant > 0 {
                texte = "Trop tard : quelqu'un avait fait des captures d'écran. Elles circulent encore mieux maintenant."
                t.badBuzzRestant = 2
            } else {
                texte = "Tu effaces tes vieux messages de tes 15 ans. Personne ne saura jamais que tu as écrit « la vie c nul » 400 fois."
                j.stats.bonheur += 2
            }

        case "materiel":
            let n = t.materielTube
            guard n < prixMateriel.count else { return "" }
            let prix = prixMateriel[n]
            if j.age < 18 {
                texte = "Tes parents refusent de payer \(Format.argent(prix)) pour \(nomsMateriel[n]). « Ton téléphone filme très bien. »"
                return texte
            }
            guard j.argent >= prix else { return "Il te faut \(Format.argent(prix))." }
            j.argent -= prix
            t.materielTube = n + 1
            texte = "Tu t'offres \(nomsMateriel[n]). Tes vidéos ont l'air presque professionnelles."

        case "collab":
            t.actionsAnnee.append("collab")
            if Double.random(in: 0...1) < 0.65 {
                let gain = Int.random(in: 1_000...15_000) + Int(a * Double.random(in: 0.1...0.3))
                c.abonnes += gain
                j.stats.bonheur += 6
                texte = "Collab avec un vidéaste à 3 millions d'abonnés : vous avez testé des bonbons très acides. +\(PhoneFormat.nombre(gain)) abonnés."
            } else {
                j.stats.bonheur -= 4
                texte = "La collab tourne mal : il t'a coupé\(j.g("", "e")) au montage, sauf le moment où tu tombes. Ta seule apparition fait 4 secondes."
            }

        case "excuses":
            t.actionsAnnee.append("excuses")
            if Double.random(in: 0...1) < 0.5 {
                t.badBuzzRestant = 0
                let gain = Int(a * Double.random(in: 0.02...0.08))
                c.abonnes += gain
                texte = "Ta vidéo d'excuses passe bien : fond gris, voix tremblante, un vrai mea culpa. Le bad buzz s'éteint."
            } else {
                t.badBuzzRestant = 2
                let perte = Int(a * Double.random(in: 0.05...0.15))
                c.abonnes = max(0, c.abonnes - perte)
                texte = "Ta vidéo d'excuses est analysée image par image : on t'accuse de lire un prompteur. Le bad buzz repart de plus belle."
            }

        case "prix":
            let i = prixOnlyPossibles.firstIndex(of: t.prixOnly) ?? 1
            t.prixOnly = prixOnlyPossibles[(i + 1) % prixOnlyPossibles.count]
            texte = "Abonnement OnlyFesses : \(t.prixOnly) € par mois."
            return texte

        case "perso":
            t.actionsAnnee.append("perso")
            let gain = Int.random(in: 800...6_000) + c.abonnes / 2
            j.argent += gain
            if Double.random(in: 0...1) < 0.2 {
                t.badBuzzRestant = 2
                var lignes = ["Une demande personnalisée très bien payée (\(Format.argent(gain))). Mais le client a partagé ta vidéo partout."]
                var qui: [String] = []
                if j.partenaireActuel != nil { qui.append("partenaire") }
                if !j.parentsVivants.isEmpty { qui.append("famille") }
                qui.removeAll { t.onlyDecouvertPar.contains($0) }
                if let cible = qui.randomElement() { lignes += reveleOnly(cible, &j, &t) }
                texte = lignes.joined(separator: " ")
            } else {
                texte = "Une demande personnalisée : un abonné veut une vidéo de toi en train de lire l'annuaire en chuchotant. \(Format.argent(gain)). Tu ne poses pas de questions."
            }

        case "fermer":
            t.onlyFerme = true
            c.abonnes = 0
            j.stats.bonheur += 3
            texte = "Tu fermes ton compte OnlyFesses. Une page se tourne. Les captures, elles, restent quelque part sur internet."

        case "rouvrir":
            t.onlyFerme = false
            texte = "Tu rouvres ton compte OnlyFesses. Il va falloir reconquérir tes abonnés."

        default:
            return ""
        }
        t.comptes[app.rawValue] = c
        t.recordAbonnes = max(t.recordAbonnes, t.abonnesTotal)
        j.stats.borner()
        engine.ajouterLigne(&j, "📱 " + texte)
        return texte
    }
}

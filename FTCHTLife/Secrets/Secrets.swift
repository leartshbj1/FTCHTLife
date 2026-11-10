import Foundation

// Secrets et chantage : règles du jeu.
// Toutes les fonctions travaillent sur `Joueur` (champ `secrets`) et n'ont besoin d'aucun autre module.
// Branchement dans le moteur : docs/SECRETS.md.

enum Secrets {
    /// Préfixe des ids des cartes de secrets affichées comme des événements.
    static let prefixeCarte = "secret_carte:"
    static let maxSecretsParProche = 2
    static let maxSecretsJoueur = 4
    static let maxCartesParAn = 2

    /// Branché par le moteur pour transmettre les signaux (au module répercussions par ex.).
    /// Chaque action du module l'appelle, en plus de renvoyer les signaux dans son résultat.
    static var surSignal: ((String, inout Joueur) -> Void)?

    // MARK: - Année qui passe

    /// À appeler une fois par an, après le vieillissement des proches et avant les événements aléatoires.
    static func passerAnnee(joueur j: inout Joueur) -> SecretsAnnee {
        var a = SecretsAnnee()
        var etat = j.secrets ?? SecretsEtat()
        // Les cartes de l'an dernier sans réponse (appli fermée…) sont oubliées.
        etat.cartes = []
        j.secrets = etat

        morts(&j, &a)
        versements(&j, &a)
        nouveauxSecretsProches(&j)
        nouveauSecretJoueur(&j, &a)
        var nbCartes = 0
        indicesEtDecouvertes(&j, &a, &nbCartes)
        prochesDecouvrentTesSecrets(&j, &a, &nbCartes)
        piresMoments(&j, &a, &nbCartes)
        return a
    }

    /// Fin des chantages quand quelqu'un meurt.
    private static func morts(_ j: inout Joueur, _ a: inout SecretsAnnee) {
        guard var etat = j.secrets else { return }
        for i in etat.secrets.indices where etat.secrets[i].statut == .chantage {
            let s = etat.secrets[i]
            if s.estDuJoueur {
                let mc = relation(j, s.maitreChanteurId)
                if mc?.vivant != true {
                    etat.secrets[i].statut = .cache
                    etat.secrets[i].maitreChanteurId = nil
                    etat.secrets[i].montant = 0
                    a.lignes.append(remplir(BibliothequeSecrets.texte("chanteur_mort",
                        secours: "{Cible}, qui te faisait chanter, est mort{eC}. Tu as presque envie d'envoyer des fleurs."),
                        j, cible: mc, secret: s))
                }
            } else if relation(j, s.porteurId)?.vivant != true {
                etat.secrets[i].statut = .garde
                etat.secrets[i].montant = 0
                a.lignes.append(remplir(BibliothequeSecrets.texte("victime_morte",
                    secours: "{Cible} est mort{eC}. Ta petite rente de chantage aussi."),
                    j, cible: relation(j, s.porteurId), secret: s))
            }
        }
        j.secrets = etat
    }

    /// Versements annuels du chantage, dans les deux sens.
    private static func versements(_ j: inout Joueur, _ a: inout SecretsAnnee) {
        guard let etat = j.secrets else { return }
        for s in etat.secrets where s.statut == .chantage {
            if s.estDuJoueur {
                guard let mc = relation(j, s.maitreChanteurId) else { continue }
                if j.argent >= s.montant {
                    j.argent -= s.montant
                    donnerArgent(&j, mc.id, s.montant)
                    modifierSecret(&j, s.id) { $0.anneesChantage += 1 }
                    a.lignes.append(remplir(BibliothequeSecrets.texte("paiement_annuel",
                        secours: "Tu as versé {montant} à {cible} pour qu'{il} se taise. Comme chaque année."),
                        j, cible: mc, secret: s, montant: s.montant))
                } else {
                    let intro = remplir(BibliothequeSecrets.texte("pas_les_moyens",
                        secours: "Tu n'as plus de quoi payer {cible}. {Il} a tenu parole : tout le monde sait."),
                        j, cible: mc, secret: s)
                    let r = exposer(s.id, intro: intro, attenuation: 1, joueur: &j)
                    a.lignes.append(r.texte)
                    a.signaux += r.signaux
                }
            } else {
                guard let r = relation(j, s.porteurId), r.vivant else { continue }
                let montant = s.montant
                if let i = j.relations.firstIndex(where: { $0.id == r.id }) {
                    j.relations[i].argent = max(0, j.relations[i].argent - montant)
                    j.relations[i].lien = Stats.borne(j.relations[i].lien - 3)
                }
                j.argent += montant
                modifierSecret(&j, s.id) { $0.anneesChantage += 1 }
                a.lignes.append(remplir(BibliothequeSecrets.texte("chantage_versement",
                    secours: "{Cible} t'a versé ta « pension » de {montant}, en serrant les dents."),
                    j, cible: r, secret: s, montant: montant))

                // Révolte : plus le chantage dure, plus elle est probable.
                let annees = (secret(j, s.id)?.anneesChantage ?? 1)
                if hasard(0.10 + 0.05 * Double(annees)) {
                    if hasard(0.5) {
                        let age = j.age
                        modifierSecret(&j, s.id) {
                            $0.statut = .revele
                            $0.montant = 0
                            $0.ageRevelation = age
                        }
                        lien(&j, r.id, -20)
                        j.stats.karma = Stats.borne(j.stats.karma - 5)
                        a.lignes.append(remplir(BibliothequeSecrets.texte("chantage_revolte",
                            secours: "{Cible} en a eu assez : {il} a tout avoué à tout le monde. Ta pension s'arrête là."),
                            j, cible: r, secret: s))
                        a.signaux += emettre(["chantage_echoue", "secret_revele"] + signalRevelation(s), &j)
                    } else {
                        let r2 = denonciation(s.id, cible: r, joueur: &j)
                        a.lignes.append(r2.texte)
                        a.signaux += r2.signaux
                    }
                }
            }
        }
    }

    private static func nouveauxSecretsProches(_ j: inout Joueur) {
        var etat = j.secrets ?? SecretsEtat()
        for r in j.relations where r.vivant {
            let actifs = etat.duProche(r.id).filter { $0.statut != .revele }.count
            guard actifs < maxSecretsParProche, hasard(0.03),
                  let s = nouveauSecret(pour: r, joueur: j, etat: etat) else { continue }
            etat.secrets.append(s)
        }
        j.secrets = etat
    }

    private static func nouveauSecretJoueur(_ j: inout Joueur, _ a: inout SecretsAnnee) {
        guard j.age >= 14 else { return }
        var etat = j.secrets ?? SecretsEtat()
        let actifs = etat.duJoueur.filter { $0.statut != .revele }
        guard actifs.count < maxSecretsJoueur, hasard(0.04) else { return }
        let dejaPris = Set(actifs.map { $0.modeleId })
        let candidats = BibliothequeSecrets.modeles.filter {
            $0.seulementSignal != true && !dejaPris.contains($0.id) && $0.resumeJoueur != nil
                && $0.peutEtrePorte(par: "joueur", age: j.age, genre: j.genre)
                && proches(de: j, existent: $0.blesse ?? [])
        }
        guard let m = tirage(candidats, poids: { $0.poids ?? 1 }) else { return }
        let s = creer(m, porteur: nil, age: j.age)
        etat.secrets.append(s)
        j.secrets = etat
        if let t = m.naissances?.randomElement() {
            a.lignes.append("🤫 " + remplir(t, j, cible: nil, secret: s))
        }
    }

    /// Indices sur les secrets des proches, puis découverte par hasard.
    private static func indicesEtDecouvertes(_ j: inout Joueur, _ a: inout SecretsAnnee, _ nbCartes: inout Int) {
        guard j.age >= 6, var etat = j.secrets else { return }
        for i in etat.secrets.indices where !etat.secrets[i].estDuJoueur && etat.secrets[i].statut == .cache {
            let s = etat.secrets[i]
            guard let r = relation(j, s.porteurId), r.vivant, let m = s.modele else { continue }
            var indiceCetteAnnee = false
            if hasard(0.25), let t = m.indices?.randomElement() {
                etat.secrets[i].indices += 1
                indiceCetteAnnee = true
                a.lignes.append("👀 " + remplir(t, j, cible: r, secret: s))
            }
            let decouvre = etat.secrets[i].indices >= 3 || (!indiceCetteAnnee && hasard(0.08))
            guard decouvre, nbCartes < maxCartesParAn, let t = m.decouvertes?.randomElement() else { continue }
            etat.secrets[i].statut = .garde
            nbCartes += 1
            var actions: [SecretAction] = [.garder, .direQueTuSais, .reveler]
            if j.age >= 16 { actions.append(.faireChanter) }
            j.secrets = etat
            let e = carte(remplir(t, j, cible: r, secret: s), actions: actions, secret: s, cible: r, joueur: &j)
            etat = j.secrets ?? etat
            a.evenements.append(e)
            a.signaux += emettre(["secret_decouvert"], &j)
        }
        j.secrets = etat
    }

    /// Un proche tombe sur un de tes secrets : il se tait, te fait chanter, ou le répand.
    private static func prochesDecouvrentTesSecrets(_ j: inout Joueur, _ a: inout SecretsAnnee, _ nbCartes: inout Int) {
        guard let etat = j.secrets else { return }
        for s in etat.duJoueur where s.statut == .cache {
            guard let m = s.modele else { continue }

            // Ceux qui savent et ne t'aiment pas peuvent parler.
            if let bavard = s.savent.compactMap({ relation(j, $0) }).first(where: { $0.vivant && $0.lien < 25 }), hasard(0.05) {
                let intro = "\(bavard.prenom) n'a pas su tenir sa langue."
                let r = exposer(s.id, intro: intro, attenuation: 1, joueur: &j)
                a.lignes.append(r.texte)
                a.signaux += r.signaux
                continue
            }

            guard hasard(0.03 * Double(max(1, m.gravite))) else { continue }
            let candidats = j.relations.filter { $0.vivant && $0.age >= 8 && !s.savent.contains($0.id) }
            guard let r = candidats.randomElement() else { continue }
            modifierSecret(&j, s.id) { $0.savent.append(r.id) }
            let demasque = m.demasques?.randomElement().map { remplir($0, j, cible: r, secret: s) }
                ?? "\(r.prenom) a découvert ton secret."

            if r.lien >= 50 || r.age < 14 || nbCartes >= maxCartesParAn || !hasard(0.7) {
                let tait = remplir(BibliothequeSecrets.texte("proche_se_tait",
                    secours: "{Cible} t'a fait un clin d'œil. Ton secret est en sécurité. Pour l'instant."),
                    j, cible: r, secret: s)
                a.lignes.append("😬 " + demasque + " " + tait)
                continue
            }
            nbCartes += 1
            let montant = demande(gravite: m.gravite, joueur: j)
            let texte = demasque + " " + remplir(BibliothequeSecrets.texte("proche_chantage",
                secours: "{Cible} sait tout ({resume}) et réclame {montant} par an pour se taire."),
                j, cible: r, secret: s, montant: montant)
            var actions: [SecretAction] = [.payer, .refuser, .avouer]
            if secretConnuDe(r.id, j) != nil { actions.append(.contreMenacer) }
            let e = carte(texte, actions: actions, secret: s, cible: r, relationId: r.id, montant: montant, joueur: &j)
            a.evenements.append(e)
        }

        // Le maître chanteur augmente son tarif.
        for s in (j.secrets ?? etat).duJoueur where s.statut == .chantage {
            guard nbCartes < maxCartesParAn, hasard(0.3), let mc = relation(j, s.maitreChanteurId), mc.vivant else { continue }
            nbCartes += 1
            let nouveau = arrondi(Int(Double(s.montant) * Double.random(in: 1.2...1.6)))
            let texte = remplir(BibliothequeSecrets.texte("proche_augmente",
                secours: "{Cible} a « revu ses tarifs » : ton silence coûte maintenant {montant} par an."),
                j, cible: mc, secret: s, montant: nouveau)
            var actions: [SecretAction] = [.payer, .refuser, .avouer]
            if secretConnuDe(mc.id, j) != nil { actions.append(.contreMenacer) }
            let e = carte(texte, actions: actions, secret: s, cible: mc, relationId: mc.id, montant: nouveau, joueur: &j)
            a.evenements.append(e)
        }
    }

    /// Une occasion en or de ressortir un secret gardé.
    private static func piresMoments(_ j: inout Joueur, _ a: inout SecretsAnnee, _ nbCartes: inout Int) {
        guard nbCartes < maxCartesParAn, j.age >= 10, hasard(0.20), let etat = j.secrets else { return }
        let gardes = etat.secrets.filter { s in
            !s.estDuJoueur && s.statut == .garde && relation(j, s.porteurId)?.vivant == true
        }
        guard let s = gardes.randomElement(), let r = relation(j, s.porteurId) else { return }
        let moments = BibliothequeSecrets.moments.filter { m in
            m.porteurs.contains(r.type.rawValue) && r.age >= (m.minAge ?? 0) && r.age <= (m.maxAge ?? 200)
        }
        guard let m = moments.randomElement() else { return }
        nbCartes += 1
        let e = carte(remplir(m.texte, j, cible: r, secret: s), actions: [.revelerMaintenant, .taire],
                      secret: s, cible: r, momentId: m.id, joueur: &j)
        a.evenements.append(e)
    }

    // MARK: - Cartes

    static func estCarte(_ evenementId: String) -> Bool { evenementId.hasPrefix(prefixeCarte) }

    /// Crée une carte, la range dans l'état et renvoie l'événement à afficher.
    private static func carte(_ texte: String, actions: [SecretAction], secret s: SecretInstance, cible: Relation?,
                              momentId: String? = nil, relationId: UUID? = nil, montant: Int? = nil,
                              joueur j: inout Joueur) -> Evenement {
        let id = prefixeCarte + UUID().uuidString
        var etat = j.secrets ?? SecretsEtat()
        etat.cartes.append(SecretCarte(id: id, secretId: s.id, actions: actions, momentId: momentId,
                                       relationId: relationId, montant: montant))
        j.secrets = etat
        let choix = actions.map { Choix(label: libelle($0, cible: cible, montant: montant), outcomes: []) }
        return Evenement(id: id, category: "secrets", minAge: 0, maxAge: 200, text: texte, choices: choix)
    }

    static func libelle(_ action: SecretAction, cible: Relation?, montant: Int?) -> String {
        let nom = cible?.prenom ?? "cette personne"
        switch action {
        case .garder: return "Garder ça pour toi"
        case .direQueTuSais: return "Dire à \(nom) que tu sais"
        case .reveler: return "Tout révéler"
        case .faireChanter: return "Faire chanter \(nom)"
        case .revelerMaintenant: return "Tout balancer maintenant"
        case .taire: return "Te taire, pas aujourd'hui"
        case .payer: return "Payer " + Format.argent(montant ?? 0) + " par an"
        case .refuser: return "Refuser de payer"
        case .avouer: return "Avouer toi-même avant qu'on parle"
        case .contreMenacer: return "Menacer \(nom) avec son propre secret"
        }
    }

    /// Le joueur répond à une carte de secret. Renvoie le texte du résultat.
    static func resoudre(evenementId: String, choix: Int, joueur j: inout Joueur) -> SecretsResultat {
        var etat = j.secrets ?? SecretsEtat()
        guard let k = etat.cartes.firstIndex(where: { $0.id == evenementId }) else {
            return SecretsResultat(texte: "Tu ne sais plus très bien de quoi il était question. C'est peut-être mieux.")
        }
        let c = etat.cartes.remove(at: k)
        j.secrets = etat
        guard c.actions.indices.contains(choix) else { return SecretsResultat(texte: "Il ne se passe rien.") }
        switch c.actions[choix] {
        case .garder: return garder(c.secretId, joueur: &j)
        case .direQueTuSais: return direQueTuSais(c.secretId, joueur: &j)
        case .reveler: return reveler(c.secretId, joueur: &j)
        case .faireChanter: return faireChanter(c.secretId, joueur: &j)
        case .revelerMaintenant: return reveler(c.secretId, momentId: c.momentId, joueur: &j)
        case .taire: return taire(c.secretId, joueur: &j)
        case .payer: return payer(c.secretId, relationId: c.relationId, montant: c.montant ?? 0, joueur: &j)
        case .refuser: return refuserDePayer(c.secretId, relationId: c.relationId, joueur: &j)
        case .avouer: return avouer(c.secretId, joueur: &j)
        case .contreMenacer: return contreMenacer(c.secretId, relationId: c.relationId, joueur: &j)
        }
    }

    // MARK: - Actions sur le secret d'un proche

    static func cleFouille(_ relationId: UUID) -> String { "sec_fouille_\(relationId.uuidString)" }

    static func peutFouiller(_ r: Relation, _ j: Joueur) -> Bool {
        r.vivant && j.vivant && j.age >= 6 && !j.actionsAnnee.contains(cleFouille(r.id))
    }

    /// Fouiller les affaires d'un proche (une fois par an).
    static func fouiller(relationId: UUID, joueur j: inout Joueur) -> SecretsResultat {
        guard let r = relation(j, relationId), r.vivant else { return SecretsResultat(texte: "") }
        guard peutFouiller(r, j) else {
            return SecretsResultat(texte: "Tu as déjà fouillé les affaires de \(r.prenom) cette année. Ça devient louche.")
        }
        j.actionsAnnee.append(cleFouille(r.id))

        if hasard(0.2) {
            lien(&j, r.id, -15)
            j.stats.karma = Stats.borne(j.stats.karma - 2)
            return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("fouille_pris",
                secours: "{Cible} t'a surpris{e} la main dans son tiroir à chaussettes. Long silence."), j, cible: r, secret: nil))
        }

        var etat = j.secrets ?? SecretsEtat()
        let caches = etat.duProche(r.id).filter { $0.statut == .cache }
        let reussite = 0.45 + Double(j.stats.intelligence) / 400
        var trouve: SecretInstance?
        if let s = caches.randomElement(), hasard(reussite) {
            trouve = s
        } else if caches.isEmpty,
                  etat.duProche(r.id).filter({ $0.statut != .revele }).count < maxSecretsParProche,
                  hasard(0.25),
                  let s = nouveauSecret(pour: r, joueur: j, etat: etat) {
            etat.secrets.append(s)
            j.secrets = etat
            trouve = s
        }
        guard let s = trouve, let t = s.modele?.decouvertes?.randomElement() else {
            return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("fouille_rien",
                secours: "Tu as fouillé les affaires de {cible}. Rien, à part des élastiques et une dent de lait."), j, cible: r, secret: nil))
        }
        modifierSecret(&j, s.id) { $0.statut = .garde }
        let sig = emettre(["secret_decouvert"], &j)
        return SecretsResultat(texte: "🔎 " + remplir(t, j, cible: r, secret: s), signaux: sig)
    }

    static func garder(_ secretId: UUID, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId) else { return SecretsResultat(texte: "") }
        if s.statut == .cache { modifierSecret(&j, secretId) { $0.statut = .garde } }
        j.stats.karma = Stats.borne(j.stats.karma + 1)
        let sig = emettre(["secret_garde"], &j)
        return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("garder",
            secours: "Tu gardes ça pour toi. Pour l'instant."), j, cible: relation(j, s.porteurId), secret: s), signaux: sig)
    }

    static func direQueTuSais(_ secretId: UUID, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId), let r = relation(j, s.porteurId), r.vivant else { return SecretsResultat(texte: "") }
        modifierSecret(&j, secretId) { $0.statut = .partage }
        if r.lien >= 50 || hasard(0.4) {
            lien(&j, r.id, 10)
            j.stats.karma = Stats.borne(j.stats.karma + 3)
            return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("dire_bien",
                secours: "{Cible} t'a serré{e} dans ses bras en chuchotant « merci de ne rien dire »."), j, cible: r, secret: s))
        }
        lien(&j, r.id, -10)
        return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("dire_mal",
            secours: "{Cible} est devenu{eC} écarlate et a quitté la pièce. Ambiance."), j, cible: r, secret: s))
    }

    /// Révèle le secret d'un proche à tout le monde, éventuellement au pire moment.
    static func reveler(_ secretId: UUID, momentId: String? = nil, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId), !s.estDuJoueur, s.statut != .revele, let m = s.modele else {
            return SecretsResultat(texte: "Tout le monde le sait déjà.")
        }
        let r = relation(j, s.porteurId)
        let moment = momentId.flatMap { id in BibliothequeSecrets.moments.first { $0.id == id } }
        let mult = moment?.multiplicateur ?? 1
        let g = Double(max(1, m.gravite))
        if let r = r { lien(&j, r.id, -Int((15 + 8 * g) * mult)) }
        j.stats.karma = Stats.borne(j.stats.karma - Int(2 * g * mult))
        j.stats.bonheur = Stats.borne(j.stats.bonheur + Int.random(in: -4...6) + (moment != nil ? 5 : 0))
        let age = j.age
        modifierSecret(&j, secretId) {
            $0.statut = .revele
            $0.montant = 0
            $0.ageRevelation = age
        }
        let texte: String
        if let mo = moment, let t = mo.resultats.randomElement() {
            texte = remplir(t, j, cible: r, secret: s)
        } else {
            let ouverture = BibliothequeSecrets.texte("reveler_soi", secours: "Tu as pris une grande inspiration et tout raconté.")
            texte = remplir(ouverture + " " + (m.revelations?.randomElement() ?? "{resume}"), j, cible: r, secret: s)
        }
        var noms = ["secret_revele"] + signalRevelation(s)
        if moment != nil { noms.append("pire_moment") }
        let sig = emettre(noms, &j)
        return SecretsResultat(texte: "💣 " + texte, signaux: sig)
    }

    static func taire(_ secretId: UUID, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId) else { return SecretsResultat(texte: "") }
        j.stats.karma = Stats.borne(j.stats.karma + 2)
        return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("taire",
            secours: "Tu as rangé le secret de {cible} dans ta poche. Il y sera encore l'an prochain."),
            j, cible: relation(j, s.porteurId), secret: s))
    }

    static func peutFaireChanter(_ s: SecretInstance, _ j: Joueur) -> Bool {
        !s.estDuJoueur && j.age >= 16 && (s.statut == .garde || s.statut == .partage)
            && relation(j, s.porteurId)?.vivant == true
    }

    static func faireChanter(_ secretId: UUID, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId), peutFaireChanter(s, j), let r = relation(j, s.porteurId), let m = s.modele else {
            return SecretsResultat(texte: j.age < 16 ? "Tu es un peu jeune pour le racket organisé." : "Impossible pour l'instant.")
        }
        let g = Double(max(1, m.gravite))
        let reussite = min(0.9, 0.55 + 0.07 * g - (s.statut == .partage ? 0.1 : 0))
        if hasard(reussite) {
            let montant = montantChantage(gravite: m.gravite, cible: r)
            modifierSecret(&j, secretId) {
                $0.statut = .chantage
                $0.montant = montant
                $0.anneesChantage = 0
            }
            j.argent += montant
            donnerArgent(&j, r.id, -montant)
            lien(&j, r.id, -25)
            j.stats.karma = Stats.borne(j.stats.karma - 10)
            let t = m.chantages?.randomElement() ?? "{Cible} a pâli et t'a tendu {montant}."
            let sig = emettre(["chantage"], &j)
            return SecretsResultat(texte: "💰 " + remplir(t, j, cible: r, secret: s, montant: montant)
                                   + " Rendez-vous l'an prochain, même tarif.", signaux: sig)
        }
        lien(&j, r.id, -30)
        if hasard(0.5) {
            let age = j.age
            modifierSecret(&j, secretId) {
                $0.statut = .revele
                $0.ageRevelation = age
            }
            j.stats.karma = Stats.borne(j.stats.karma - 5)
            let sig = emettre(["chantage_echoue", "secret_revele"] + signalRevelation(s), &j)
            return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("chantage_refus_aveu",
                secours: "{Cible} a ri, puis a tout avoué à la famille avant toi. Ton arme est vide."),
                j, cible: r, secret: s), signaux: sig)
        }
        return denonciation(secretId, cible: r, joueur: &j)
    }

    /// Le proche que tu fais chanter va voir la police.
    private static func denonciation(_ secretId: UUID, cible r: Relation, joueur j: inout Joueur) -> SecretsResultat {
        let g = secret(j, secretId)?.modele?.gravite ?? 1
        modifierSecret(&j, secretId) {
            $0.statut = .partage
            $0.montant = 0
        }
        let amende = 500 * max(1, g)
        j.argent -= amende
        j.stats.karma = Stats.borne(j.stats.karma - 15)
        j.stats.bonheur = Stats.borne(j.stats.bonheur - 10)
        lien(&j, r.id, -30)
        let t = remplir(BibliothequeSecrets.texte("chantage_refus_denonce",
            secours: "{Cible} est allé{eC} voir la police avec tes messages de menace. Le juge n'a pas ri."),
            j, cible: r, secret: secret(j, secretId))
        let sig = emettre(["chantage_echoue", "chantage_denonce"], &j)
        return SecretsResultat(texte: "🚨 " + t + " (amende de \(Format.argent(amende)))", signaux: sig)
    }

    static func arreterChantage(_ secretId: UUID, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId), !s.estDuJoueur, s.statut == .chantage else { return SecretsResultat(texte: "") }
        modifierSecret(&j, secretId) {
            $0.statut = .partage
            $0.montant = 0
        }
        j.stats.karma = Stats.borne(j.stats.karma + 5)
        if let r = relation(j, s.porteurId) { lien(&j, r.id, 5) }
        let sig = emettre(["chantage_fin"], &j)
        return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("chantage_fin",
            secours: "Tu as dit à {cible} qu'{il} n'avait plus besoin de payer. {Il} t'a regardé{e} comme un ovni."),
            j, cible: relation(j, s.porteurId), secret: s), signaux: sig)
    }

    // MARK: - Actions sur tes propres secrets

    static func payer(_ secretId: UUID, relationId: UUID?, montant: Int, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId), s.estDuJoueur, s.statut != .revele,
              let r = relation(j, relationId ?? s.maitreChanteurId), r.vivant else {
            return SecretsResultat(texte: "Plus personne à payer.")
        }
        if j.argent < montant {
            let intro = remplir(BibliothequeSecrets.texte("pas_les_moyens",
                secours: "Tu n'as pas de quoi payer {cible}. {Il} a tenu parole : tout le monde sait."), j, cible: r, secret: s)
            return exposer(secretId, intro: intro, attenuation: 1, joueur: &j)
        }
        let premiereFois = s.statut != .chantage
        j.argent -= montant
        donnerArgent(&j, r.id, montant)
        modifierSecret(&j, secretId) {
            $0.statut = .chantage
            $0.maitreChanteurId = r.id
            $0.montant = montant
        }
        j.stats.bonheur = Stats.borne(j.stats.bonheur - 5)
        let sig = premiereFois ? emettre(["victime_chantage"], &j) : []
        return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("payer",
            secours: "Tu as versé {montant} à {cible}. {Il} a recompté deux fois devant toi."),
            j, cible: r, secret: s, montant: montant), signaux: sig)
    }

    static func refuserDePayer(_ secretId: UUID, relationId: UUID?, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId), s.estDuJoueur, s.statut != .revele else { return SecretsResultat(texte: "") }
        let r = relation(j, relationId ?? s.maitreChanteurId)
        if let r = r { lien(&j, r.id, -10) }
        let intro = remplir(BibliothequeSecrets.texte("refuser",
            secours: "Tu as dit non à {cible}. {Il} a souri et sorti son téléphone."), j, cible: r, secret: s)
        return exposer(secretId, intro: intro, attenuation: 1, joueur: &j)
    }

    /// Avouer soi-même : moins grave que de se faire balancer.
    static func avouer(_ secretId: UUID, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId), s.estDuJoueur, s.statut != .revele else { return SecretsResultat(texte: "") }
        j.stats.karma = Stats.borne(j.stats.karma + 5)
        let intro = remplir(BibliothequeSecrets.texte("avouer",
            secours: "Tu as tout avoué avant que quelqu'un d'autre le fasse. Ça pique, mais moins."),
            j, cible: relation(j, s.maitreChanteurId), secret: s)
        var r = exposer(secretId, intro: intro, attenuation: 0.5, joueur: &j)
        r.signaux += emettre(["aveu"], &j)
        return r
    }

    /// Le secret d'un proche que tu connais et que tu peux utiliser contre lui.
    static func secretConnuDe(_ relationId: UUID, _ j: Joueur) -> SecretInstance? {
        j.secrets?.duProche(relationId).first { $0.statut == .garde || $0.statut == .partage || $0.statut == .chantage }
    }

    static func contreMenacer(_ secretId: UUID, relationId: UUID?, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId), s.estDuJoueur, s.statut != .revele,
              let r = relation(j, relationId ?? s.maitreChanteurId) else { return SecretsResultat(texte: "") }
        guard let leSien = secretConnuDe(r.id, j) else {
            return refuserDePayer(secretId, relationId: r.id, joueur: &j)
        }
        let ecart = Double((leSien.modele?.gravite ?? 1) - (s.modele?.gravite ?? 1))
        if hasard(min(0.9, max(0.3, 0.65 + 0.05 * ecart))) {
            modifierSecret(&j, secretId) {
                $0.statut = .equilibre
                $0.maitreChanteurId = nil
                $0.montant = 0
            }
            modifierSecret(&j, leSien.id) {
                $0.statut = .equilibre
                $0.montant = 0
            }
            j.stats.bonheur = Stats.borne(j.stats.bonheur + 5)
            let sig = emettre(["contre_menace"], &j)
            return SecretsResultat(texte: remplir(BibliothequeSecrets.texte("contre_ok",
                secours: "Tu as murmuré « {titre} » à l'oreille de {cible}. {Il} a blêmi. Match nul : personne ne parle."),
                j, cible: r, secret: leSien), signaux: sig)
        }
        j.stats.karma = Stats.borne(j.stats.karma - 5)
        let intro = remplir(BibliothequeSecrets.texte("contre_rate",
            secours: "Tu as tenté de menacer {cible}. {Il} a haussé les épaules : {il} n'a plus rien à perdre."),
            j, cible: r, secret: leSien)
        return exposer(secretId, intro: intro, attenuation: 1, joueur: &j)
    }

    /// Ton secret éclate au grand jour.
    @discardableResult
    static func exposer(_ secretId: UUID, intro: String, attenuation: Double, joueur j: inout Joueur) -> SecretsResultat {
        guard let s = secret(j, secretId), s.estDuJoueur, let m = s.modele else { return SecretsResultat(texte: intro) }
        let g = Double(max(1, m.gravite))
        j.stats.bonheur = Stats.borne(j.stats.bonheur - Int(5 * g * attenuation))
        j.stats.karma = Stats.borne(j.stats.karma - Int(g * attenuation))
        let blesses = m.blesse ?? []
        for i in j.relations.indices where j.relations[i].vivant {
            let t = j.relations[i].type
            let touche = blesses.contains { correspond(t, $0) }
            let proche = t.estParent || t == .partenaire || t == .enfant || t == .frere || t == .soeur
            let delta = touche ? 8 * g : (proche ? 2 * g : 0)
            if delta > 0 {
                j.relations[i].lien = Stats.borne(j.relations[i].lien - Int(delta * attenuation))
            }
        }
        let age = j.age
        modifierSecret(&j, secretId) {
            $0.statut = .revele
            $0.maitreChanteurId = nil
            $0.montant = 0
            $0.ageRevelation = age
        }
        let suite = m.revelationsJoueur?.randomElement().map { remplir($0, j, cible: nil, secret: s) } ?? ""
        let sig = emettre(["secret_expose"] + signalRevelation(s), &j)
        return SecretsResultat(texte: "💥 " + intro + (suite.isEmpty ? "" : " " + suite), signaux: sig)
    }

    // MARK: - Signaux venant du jeu et tags

    /// Un autre module signale quelque chose (« tromperie », « prison_sortie »…) qui peut créer un secret chez le joueur.
    /// Renvoie la ligne de journal à afficher, s'il y en a une.
    @discardableResult
    static func signaler(_ signal: String, joueur j: inout Joueur) -> String? {
        var etat = j.secrets ?? SecretsEtat()
        let actifs = Set(etat.duJoueur.filter { $0.statut != .revele }.map { $0.modeleId })
        let candidats = BibliothequeSecrets.modeles.filter {
            ($0.signaux ?? []).contains(signal) && !actifs.contains($0.id) && $0.resumeJoueur != nil
                && $0.peutEtrePorte(par: "joueur", age: j.age, genre: j.genre)
        }
        guard let m = tirage(candidats, poids: { $0.poids ?? 1 }) else { return nil }
        let s = creer(m, porteur: nil, age: j.age)
        etat.secrets.append(s)
        j.secrets = etat
        return m.naissances?.randomElement().map { "🤫 " + remplir($0, j, cible: nil, secret: s) }
    }

    /// Tags à ajouter à ceux du moteur pour filtrer les événements.
    static func tags(_ j: Joueur) -> Set<String> {
        guard let e = j.secrets else { return [] }
        var t: Set<String> = []
        let tiens = e.duJoueur
        let autres = e.secrets.filter { !$0.estDuJoueur }
        if tiens.contains(where: { $0.statut != .revele }) { t.insert("secret") }
        if tiens.contains(where: { $0.statut == .chantage }) { t.insert("victime_chantage") }
        if tiens.contains(where: { $0.statut == .revele }) { t.insert("secret_expose") }
        if autres.contains(where: { $0.statut == .chantage }) { t.insert("maitre_chanteur") }
        if autres.contains(where: { $0.statut == .garde || $0.statut == .partage }) { t.insert("connait_secret") }
        return t
    }

    // MARK: - Création

    static func nouveauSecret(pour r: Relation, joueur j: Joueur, etat: SecretsEtat) -> SecretInstance? {
        let dejaPris = Set(etat.duProche(r.id).map { $0.modeleId })
        let candidats = BibliothequeSecrets.modeles.filter {
            !dejaPris.contains($0.id) && $0.resume != nil
                && $0.peutEtrePorte(par: r.type.rawValue, age: r.age, genre: r.genre)
        }
        guard let m = tirage(candidats, poids: { $0.poids ?? 1 }) else { return nil }
        return creer(m, porteur: r.id, age: j.age)
    }

    private static func creer(_ m: SecretModele, porteur: UUID?, age: Int) -> SecretInstance {
        var s = SecretInstance(modeleId: m.id, porteurId: porteur, ageCreation: age)
        if m.complice == true {
            let g = Genre.allCases.randomElement() ?? .homme
            s.complice = Donnees.prenom(g)
            s.compliceFemme = g == .femme
        }
        return s
    }

    // MARK: - Montants

    static let baremes = [300, 1000, 3000, 8000, 20000]
    static let baremesMineurs = [10, 20, 30, 50, 80]

    /// Ce que tu peux exiger d'un proche.
    static func montantChantage(gravite: Int, cible: Relation) -> Int {
        let g = min(5, max(1, gravite)) - 1
        if cible.age < 18 { return baremesMineurs[g] }
        let brut = Double(baremes[g] + max(0, cible.argent) / 20) * Double.random(in: 0.8...1.3)
        return arrondi(Int(brut))
    }

    /// Ce qu'un proche exige de toi.
    static func demande(gravite: Int, joueur j: Joueur) -> Int {
        let g = min(5, max(1, gravite)) - 1
        if j.age < 18 { return baremesMineurs[g] }
        let brut = Double(baremes[g] + max(0, j.argent) / 25) * Double.random(in: 0.8...1.3)
        return arrondi(Int(brut))
    }

    static func arrondi(_ m: Int) -> Int {
        m >= 1000 ? (m / 100) * 100 : max(10, (m / 10) * 10)
    }

    // MARK: - Outils

    static func relation(_ j: Joueur, _ id: UUID?) -> Relation? {
        guard let id = id else { return nil }
        return j.relations.first { $0.id == id }
    }

    static func secret(_ j: Joueur, _ id: UUID) -> SecretInstance? {
        j.secrets?.secrets.first { $0.id == id }
    }

    private static func modifierSecret(_ j: inout Joueur, _ id: UUID, _ change: (inout SecretInstance) -> Void) {
        guard var etat = j.secrets, let i = etat.index(id) else { return }
        change(&etat.secrets[i])
        j.secrets = etat
    }

    private static func lien(_ j: inout Joueur, _ id: UUID, _ delta: Int) {
        guard let i = j.relations.firstIndex(where: { $0.id == id }) else { return }
        j.relations[i].lien = Stats.borne(j.relations[i].lien + delta)
    }

    private static func donnerArgent(_ j: inout Joueur, _ id: UUID, _ montant: Int) {
        guard let i = j.relations.firstIndex(where: { $0.id == id }) else { return }
        j.relations[i].argent = max(0, j.relations[i].argent + montant)
    }

    private static func signalRevelation(_ s: SecretInstance) -> [String] {
        s.modele?.signalRevelation.map { [$0] } ?? []
    }

    /// Transmet les signaux au moteur (si branché) et les renvoie.
    private static func emettre(_ signaux: [String], _ j: inout Joueur) -> [String] {
        if let relais = surSignal {
            for s in signaux { relais(s, &j) }
        }
        return signaux
    }

    /// "partenaire", "parent", "mere", "pere", "fratrie", "frere", "soeur", "ami", "enfant", "ex".
    static func correspond(_ type: TypeRelation, _ cle: String) -> Bool {
        switch cle {
        case "parent": return type.estParent
        case "fratrie": return type == .frere || type == .soeur
        default: return type.rawValue == cle
        }
    }

    /// Vrai si le joueur a au moins un proche vivant de chaque type cité (ex. une liaison suppose un partenaire).
    static func proches(de j: Joueur, existent cles: [String]) -> Bool {
        cles.allSatisfy { cle in j.relations.contains { $0.vivant && correspond($0.type, cle) } }
    }

    static func hasard(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }

    static func tirage<T>(_ liste: [T], poids: (T) -> Double) -> T? {
        let total = liste.reduce(0.0) { $0 + max(0, poids($1)) }
        guard total > 0 else { return liste.randomElement() }
        var r = Double.random(in: 0..<total)
        for e in liste {
            r -= max(0, poids(e))
            if r < 0 { return e }
        }
        return liste.last
    }

    // MARK: - Textes

    /// Remplace les variables d'un texte de secret (voir docs/SECRETS.md).
    static func remplir(_ texte: String, _ j: Joueur, cible: Relation?, secret: SecretInstance?, montant: Int? = nil) -> String {
        var t = texte
        let m = secret?.modele
        if t.contains("{resume}") {
            let resume = (secret?.estDuJoueur == true ? m?.resumeJoueur : m?.resume) ?? "tu sais quoi"
            t = t.replacingOccurrences(of: "{resume}", with: resume)
        }
        let femme = cible?.genre == .femme
        let nom = cible?.prenom ?? "Quelqu'un"
        let designation: String = cible?.designation ?? "Quelqu'un"
        let designationMin: String = designation.prefix(1).lowercased() + String(designation.dropFirst())
        let argent: String = Format.argent(montant ?? secret?.montant ?? 0)
        let partenaire: String = j.relations.first { $0.type == .partenaire && $0.vivant }?.prenom ?? "ton crush"
        let remplacements: [(String, String)] = [
            ("{Cible}", nom),
            ("{cible}", nom),
            ("{Designation}", designation),
            ("{designation}", designationMin),
            ("{Il}", femme ? "Elle" : "Il"),
            ("{il}", femme ? "elle" : "il"),
            ("{le}", femme ? "la" : "le"),
            ("{eC}", femme ? "e" : ""),
            ("{heC}", femme ? "he" : ""),
            ("{complice}", secret?.complice ?? "quelqu'un"),
            ("{eX}", secret?.compliceFemme == true ? "e" : ""),
            ("{montant}", argent),
            ("{titre}", m?.titre.lowercased() ?? "ton secret"),
            ("{prenom}", j.prenom),
            ("{nom}", j.nom),
            ("{ville}", j.ville),
            ("{mere}", j.mere?.prenom ?? "ta mère"),
            ("{pere}", j.pere?.prenom ?? "ton père"),
            ("{partenaire}", partenaire),
            ("{e}", j.genre == .femme ? "e" : ""),
        ]
        for (cle, valeur) in remplacements {
            t = t.replacingOccurrences(of: cle, with: valeur)
        }
        return t
    }
}

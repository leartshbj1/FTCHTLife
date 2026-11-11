import SwiftUI

// Écrans des carrières spéciales. Voir docs/CARRIERES_SPECIALES.md.

/// Ligne de liste avec une grande icône, un titre en gras, une phrase et une flèche (ou un cadenas).
struct SpeLigneEmoji: View {
    let emoji: String
    let titre: String
    let sousTitre: String
    var verrou: String? = nil
    var couleur: Color = CategorieMenu.carriere.couleur

    var body: some View {
        let ouvert = verrou == nil
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 36))
                .frame(width: 52, height: 52)
                .opacity(ouvert ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 3) {
                Text(titre)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(ouvert ? couleur : Theme.gris)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(sousTitre)
                    .font(.system(size: 14))
                    .foregroundStyle(ouvert ? Theme.encre.opacity(0.75) : Theme.gris)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: ouvert ? "chevron.right" : "lock.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ouvert ? couleur : Theme.gris)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Ce qu'ouvre une ligne du menu « Carrières spéciales ».
enum SpeEcran: Identifiable {
    case module(ModuleJeu)
    case carriere(SpeCarriereType)
    case salle, musee, invest

    var id: String {
        switch self {
        case .module(let m): return "m_" + m.rawValue
        case .carriere(let t): return "c_" + t.rawValue
        case .salle: return "salle"
        case .musee: return "musee"
        case .invest: return "invest"
        }
    }
}

/// Menu Carrière → Carrières spéciales : toutes les carrières à part, avec leur propre gameplay.
struct CarrieresSpecialesView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var ouvert: SpeEcran?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let e = j.speciales ?? SpeEtat()
                    if let c = e.carriere {
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("En ce moment").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                                Text("\(c.type.emoji) \(SpeMoteur.titre(c, j))").font(.headline).foregroundStyle(Theme.encre)
                                Text("Réputation \(c.reputation)/100 · \(c.annees) an\(c.annees > 1 ? "s" : "") de carrière")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section {
                        ligneModule(.politique, "🏛️", "Politicien", "Se présenter, gouverner, viser le sommet.", j)
                        ligneModule(.entreprise, "💼", "Affaires", "Crée, rachète ou dirige une entreprise.", j)
                        ForEach(SpeCarriereType.allCases) { t in
                            ligneCarriere(t, j, e)
                        }
                        ligneModule(.agenceDetective, "🕵️", "Détective privé", "Filatures, planques et clients louches.", j)
                        ligneModule(.secte, "🕯️", "Gourou", "Fonder un mouvement. À tes risques.", j)
                        ligneModule(.crime, "🕶️", "Milieu", "Larcins, trafics, organisation criminelle.", j)
                    } header: {
                        Text("Carrières spéciales")
                    }
                    Section {
                        ligne(.musee, "🖼️", "Mon musée",
                              e.musee.map { "\($0.nom) · \($0.collection.count) œuvres · prestige \($0.prestige)" } ?? "Ouvre un musée, achète des œuvres, attire les foules.",
                              verrou: j.age < 21 ? "Dès 21 ans." : nil)
                        ligne(.invest, "💰", "Investisseur",
                              investResume(e) ?? "Sponsorise un combattant, produis un film, rachète un club.",
                              verrou: j.age < 18 ? "Dès 18 ans." : nil)
                        ligne(.salle, "🏋️", "Salle de sport",
                              "Force \(e.force) · technique \(e.technique) · cardio \(e.cardio)" + (e.abonnement > 0 ? " · \(e.salleNom)" : ""),
                              verrou: j.age < SpeMoteur.ageMinSalle ? "Dès \(SpeMoteur.ageMinSalle) ans." : nil)
                    } header: {
                        Text("Argent, passion et entraînement")
                    }
                    if !e.anciennes.isEmpty {
                        Section("Carrières passées") {
                            ForEach(e.anciennes) { a in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(a.type.emoji) \(a.type.nom(j.genre == .femme)) · \(a.rang)").font(.subheadline.weight(.semibold))
                                    Text("De \(a.ageDebut) à \(a.ageFin) ans · \(a.resume)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.fond.ignoresSafeArea())
            .navigationTitle("Carrières spéciales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
            .alerteResultat($message)
            .sheet(item: $ouvert) { ecran in
                Group {
                    switch ecran {
                    case .module(let m): EcranModule(module: m)
                    case .carriere(let t): SpeCarriereView(type: t)
                    case .salle: SpeSalleView()
                    case .musee: SpeMuseeView()
                    case .invest: SpeInvestView()
                    }
                }
                .environmentObject(engine)
            }
        }
    }

    private func investResume(_ e: SpeEtat) -> String? {
        let actifs = e.investissements.filter { !$0.termine }
        guard !actifs.isEmpty else { return nil }
        let total = actifs.reduce(0) { $0 + $1.valeur }
        return "\(actifs.count) investissement\(actifs.count > 1 ? "s" : "") en cours · \(Format.argent(total))"
    }

    private func ligneModule(_ m: ModuleJeu, _ emoji: String, _ titre: String, _ sousTitre: String, _ j: Joueur) -> some View {
        ligne(.module(m), emoji, titre, sousTitre, verrou: m.verrou(j))
    }

    private func ligneCarriere(_ t: SpeCarriereType, _ j: Joueur, _ e: SpeEtat) -> some View {
        var emoji = t.emoji
        var sous = t.accroche
        if let c = e.carriere, c.type == t {
            sous = SpeCatalogue.rang(c, femme: j.genre == .femme) + " · " + SpeVue.resume(c)
            if t == .sport { emoji = SpeCatalogue.sport(c.sport).emoji }
        }
        let verrou: String? = j.vivant ? (j.vieEtat.justice.enPrison ? "Tu es en prison." : nil) : "Plus possible."
        return ligne(.carriere(t), emoji, t.nom(j.genre == .femme), sous, verrou: verrou)
    }

    private func ligne(_ ecran: SpeEcran, _ emoji: String, _ titre: String, _ sousTitre: String, verrou: String?) -> some View {
        Button {
            if let v = verrou {
                message = v
            } else {
                Vibration.legere()
                ouvert = ecran
            }
        } label: {
            SpeLigneEmoji(emoji: emoji, titre: titre, sousTitre: sousTitre, verrou: verrou)
        }
        .buttonStyle(.plain)
    }
}

/// Petits morceaux partagés par les écrans.
enum SpeVue {
    static func resume(_ c: SpeCarriere) -> String {
        switch c.type {
        case .mma: return "\(c.victoires) V – \(c.defaites) D"
        case .sport: return c.club
        case .mannequin: return c.agence
        case .cinema: return "\(c.films.count) film\(c.films.count > 1 ? "s" : "")"
        case .musique: return "\(c.nomScene) · \(c.fans) fans"
        }
    }

    static func ligne(_ titre: String, _ valeur: String, _ icone: String) -> some View {
        HStack {
            Label(titre, systemImage: icone).foregroundStyle(Theme.encre)
            Spacer()
            Text(valeur).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Une carrière

struct SpeCarriereView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let type: SpeCarriereType

    @State private var message: String?
    @State private var confirmerArret = false
    // Débuts
    @State private var sportChoisi = "football"
    @State private var genreMusique = "pop"
    @State private var enGroupe = false
    @State private var nomScene = ""
    // MMA
    @State private var difficulte = 0
    @State private var strategie = 0
    // Cinéma
    @State private var titreFilm = ""
    @State private var genreFilm = "drame"
    @State private var tailleFilm = 0
    @State private var castingFilm = 0
    @State private var autoFinance = false

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    let e = j.speciales ?? SpeEtat()
                    if let c = e.carriere, c.type == type {
                        tableau(c, e, j)
                    } else if let c = e.carriere {
                        Section {
                            Text("Tu es déjà \(SpeMoteur.titre(c, j).lowercased()). Arrête cette carrière avant d'en commencer une autre.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        debut(e, j)
                    }
                }
            }
            .navigationTitle(type.nom(engine.joueur?.genre == .femme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
            .alerteResultat($message)
            .confirmationDialog("Mettre fin à ta carrière ?", isPresented: $confirmerArret, titleVisibility: .visible) {
                Button("Arrêter", role: .destructive) { message = engine.speArreter() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Tu ne pourras pas reprendre au même rang.")
            }
        }
    }

    // MARK: Début

    @ViewBuilder
    private func debut(_ e: SpeEtat, _ j: Joueur) -> some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Text(type.emoji).font(.system(size: 40))
                Text(type.accroche).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        switch type {
        case .mma:
            Section("Pour ta licence") {
                JaugeModule(titre: "Force", icone: "dumbbell.fill", valeur: e.force)
                JaugeModule(titre: "Technique", icone: "figure.boxing", valeur: e.technique)
                JaugeModule(titre: "Cardio", icone: "heart.fill", valeur: e.cardio)
                Text("Il faut 30 en force et 30 en technique. Musculation et cours de boxe : Carrières spéciales → Salle de sport.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .sport:
            Section("Ton sport") {
                Picker("Sport", selection: $sportChoisi) {
                    ForEach(SpeCatalogue.sports, id: \.id) { s in Text("\(s.emoji) \(s.nom)").tag(s.id) }
                }
                SpeVue.ligne("Talent", "\(SpeMoteur.talent(e, sport: sportChoisi, j))/100", "star.fill")
                SpeVue.ligne("Chance aux essais", "\(Int(SpeMoteur.chanceEssais(e, sport: sportChoisi, j) * 100)) %", "percent")
                Text("Le talent dépend de ta force, de ton cardio et de ta technique (salle de sport), de ta santé et de la compétence « sport ».")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .mannequin:
            Section {
                SpeVue.ligne("Apparence", "\(j.stats.apparence)/100", "sparkles")
                SpeVue.ligne("Chance qu'une agence réponde", "\(Int(SpeMoteur.chanceAgence(j) * 100)) %", "percent")
            }
        case .cinema:
            EmptyView()
        case .musique:
            Section("Ton projet") {
                Picker("Style", selection: $genreMusique) {
                    ForEach(SpeCatalogue.genresMusique.indices, id: \.self) { i in Text("\(SpeCatalogue.genresMusique[i].emoji) \(SpeCatalogue.genresMusique[i].nom)").tag(SpeCatalogue.genresMusique[i].id) }
                }
                Toggle("En groupe", isOn: $enGroupe)
                TextField(enGroupe ? "Nom du groupe (facultatif)" : "Nom de scène (facultatif)", text: $nomScene)
            }
        }
        Section {
            if let blocage = SpeMoteur.blocageDebut(type, j) {
                Text(blocage).foregroundStyle(.secondary)
            } else {
                Button {
                    message = engine.speCommencer(type, sport: sportChoisi, genre: genreMusique, enGroupe: enGroupe, nomScene: nomScene)
                } label: {
                    Label(texteDebut, systemImage: "play.fill").font(.headline)
                }
            }
        } footer: {
            Text("Dès le deuxième rang, c'est un temps plein : tu quittes ton emploi.")
        }
    }

    private var texteDebut: String {
        switch type {
        case .mma: return "Demander ta licence amateur"
        case .sport: return "Passer des essais"
        case .mannequin: return "Envoyer tes photos aux agences"
        case .cinema: return "Te lancer"
        case .musique: return "Te lancer"
        }
    }

    // MARK: Tableau de bord

    @ViewBuilder
    private func tableau(_ c: SpeCarriere, _ e: SpeEtat, _ j: Joueur) -> some View {
        let f = j.genre == .femme
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(type == .sport ? SpeCatalogue.sport(c.sport).emoji : type.emoji) \(SpeCatalogue.rang(c, femme: f))")
                    .font(.title3.bold())
                Text("\(c.annees) an\(c.annees > 1 ? "s" : "") de carrière · \(Format.argent(c.gainsTotal)) gagnés")
                    .font(.caption).foregroundStyle(.secondary)
            }
            JaugeModule(titre: "Réputation", icone: "star.fill", valeur: c.reputation)
            JaugeModule(titre: type == .cinema || type == .musique ? "Inspiration" : "Forme", icone: "bolt.fill", valeur: c.forme)
            if c.blessure > 0 {
                Text("🩹 Blessure : encore \(c.blessure) an\(c.blessure > 1 ? "s" : "") d'arrêt.").font(.subheadline).foregroundStyle(.red)
            }
            if c.niveau < 5 {
                Text("Prochain rang : réputation \(SpeCatalogue.seuilsReputation[c.niveau + 1])\(conditionRang(c))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        switch type {
        case .mma: mma(c, e, j)
        case .sport: sport(c, e, j)
        case .mannequin: mannequin(c, j)
        case .cinema: cinema(c, j)
        case .musique: musique(c, j)
        }
        if !c.palmares.isEmpty {
            Section("Palmarès") {
                ForEach(Array(c.palmares.enumerated()), id: \.offset) { _, p in
                    Text("🏆 " + p).font(.subheadline)
                }
            }
        }
        Section {
            Button("Mettre fin à ma carrière", role: .destructive) { confirmerArret = true }
        }
    }

    private func conditionRang(_ c: SpeCarriere) -> String {
        let n = c.niveau + 1
        switch c.type {
        case .mma: return n == 5 ? " et gagner le combat pour la ceinture" : ", et deux victoires de suite"
        case .sport: return n == 5 ? ", trois titres et une grande saison" : " et une saison notée 65 ou plus"
        case .mannequin: return " et apparence \(SpeMoteur.apparenceRang[n])"
        case .cinema: return " et \(SpeMoteur.filmsRequis[n]) long(s) métrage(s)"
        case .musique: return " (ou \(SpeCatalogue.seuilsFans[n]) fans)"
        }
    }

    private func action(_ titre: String, _ sousTitre: String, _ icone: String, cle: String, _ c: SpeCarriere, _ faire: @escaping () -> String) -> some View {
        let fait = c.actionsAnnee.contains(cle)
        return LigneAction(titre: titre, sousTitre: fait ? "Déjà fait cette année" : sousTitre, icone: icone, actif: !fait) {
            message = faire()
        }
    }

    // MARK: MMA

    @ViewBuilder
    private func mma(_ c: SpeCarriere, _ e: SpeEtat, _ j: Joueur) -> some View {
        Section("Fiche") {
            SpeVue.ligne("Palmarès", "\(c.victoires) V – \(c.defaites) D (\(c.ko) avant la limite)", "list.number")
            SpeVue.ligne("Ligue", SpeCatalogue.ligues[c.niveau], "flag.fill")
            SpeVue.ligne("Coach", c.coach, "person.fill")
            if c.ceintures > 0 { SpeVue.ligne("Combats de titre gagnés", "\(c.ceintures)", "trophy.fill") }
            if c.commotions >= 2 { SpeVue.ligne("Commotions", "\(c.commotions)", "brain.head.profile") }
            JaugeModule(titre: "Force", icone: "dumbbell.fill", valeur: e.force)
            JaugeModule(titre: "Technique", icone: "figure.boxing", valeur: e.technique)
            JaugeModule(titre: "Cardio", icone: "heart.fill", valeur: e.cardio)
        }
        Section {
            Picker("Adversaire", selection: $difficulte) {
                ForEach(0..<(SpeMoteur.titreDisponible(c) ? 4 : 3), id: \.self) { i in Text(SpeMoteur.nomsDifficulte[i]).tag(i) }
            }
            Picker("Stratégie", selection: $strategie) {
                ForEach(0..<3, id: \.self) { i in Text(SpeMoteur.nomsStrategie[i]).tag(i) }
            }
            Button {
                Vibration.moyenne()
                message = engine.speCombattre(difficulte: min(difficulte, SpeMoteur.titreDisponible(c) ? 3 : 2), strategie: strategie)
            } label: {
                Label("Monter dans la cage", systemImage: "figure.boxing").font(.headline)
            }
            .disabled(c.blessure > 0 || c.combatsAnnee >= 3)
        } header: {
            Text("Combattre (\(c.combatsAnnee)/3 cette année)")
        } footer: {
            Text("Debout : KO plus fréquents, plus de blessures. Au sol : la technique compte. Prudent : moins de risques, moins de gloire. Chaque combat use ta forme.")
        }
        Section("Cette année") {
            action("Camp d'entraînement", "Forme +25, technique, force, cardio. \(Format.argent(max(500, SpeCatalogue.revenu(.mma, c.niveau) / 10))).", "tent.fill", cle: "camp", c) { engine.speMMACamp() }
            action("Conférence de presse", "Réputation en hausse, karma en baisse.", "mic.fill", cle: "presse", c) { engine.speMMAPresse() }
            action("Changer de coach", "Technique +4. \(Format.argent(max(1_000, SpeCatalogue.revenu(.mma, c.niveau) / 8))).", "person.2.fill", cle: "coach", c) { engine.speMMACoach() }
        }
    }

    // MARK: Sport

    @ViewBuilder
    private func sport(_ c: SpeCarriere, _ e: SpeEtat, _ j: Joueur) -> some View {
        let s = SpeCatalogue.sport(c.sport)
        Section("Fiche") {
            SpeVue.ligne("Sport", "\(s.emoji) \(s.nom)", "sportscourt.fill")
            SpeVue.ligne(s.collectif ? "Club" : "Équipe", c.club, "shield.fill")
            SpeVue.ligne("Dernière saison", c.performance > 0 ? "\(c.performance)/100" : "—", "chart.bar.fill")
            SpeVue.ligne("Titres", "\(c.titres)", "trophy.fill")
            SpeVue.ligne("Sélections nationales", "\(c.selections)", "flag.fill")
            SpeVue.ligne("Fans", "\(c.fans)", "person.3.fill")
            JaugeModule(titre: "Talent", icone: "star.circle.fill", valeur: SpeMoteur.talent(e, sport: c.sport, j))
        }
        Section {
            action("Entraînement en plus", "Forme +12, cardio et technique. Meilleure saison.", "figure.run", cle: "entrainement", c) { engine.speSport(.entrainement) }
            action("Préparateur physique", "Moins de blessures. \(Format.argent(max(2_000, SpeCatalogue.revenu(.sport, c.niveau) / 20))).", "stethoscope", cle: "preparateur", c) { engine.speSport(.preparateur) }
            action("Demander un transfert", "Vers un club plus grand, si ta saison le permet.", "arrow.left.arrow.right", cle: "transfert", c) { engine.speSport(.transfert) }
            action("Contrat de sponsoring", "De l'argent, selon ta réputation.", "dollarsign.circle.fill", cle: "sponsor", c) { engine.speSport(.sponsor) }
            action("Médias et réseaux", "Fans et réputation. Attention aux phrases à chaud.", "tv.fill", cle: "medias", c) { engine.speSport(.medias) }
        } header: {
            Text("Cette année")
        } footer: {
            Text("La saison se joue au passage d'année : talent, forme, âge et un peu de chance.")
        }
    }

    // MARK: Mannequin

    @ViewBuilder
    private func mannequin(_ c: SpeCarriere, _ j: Joueur) -> some View {
        Section("Fiche") {
            SpeVue.ligne("Agence", c.agence, "building.2.fill")
            SpeVue.ligne("Apparence", "\(j.stats.apparence)/100", "sparkles")
            SpeVue.ligne("Campagnes", "\(c.campagnes)", "camera.fill")
            SpeVue.ligne("Défilés", "\(c.defiles)", "figure.walk")
            SpeVue.ligne("Abonnés", "\(c.abonnes)", "person.3.fill")
        }
        Section("Cette année") {
            action("Passer un casting", "Une campagne si le jury dit oui.", "person.crop.rectangle.stack.fill", cle: "casting", c) { engine.speMannequin(.casting) }
            action("Shooting photo", "Un peu d'argent et de réputation.", "camera.fill", cle: "shooting", c) { engine.speMannequin(.shooting) }
            action("Défiler", "Dès « Défilés nationaux ». Réputation +5.", "figure.walk", cle: "defile", c) { engine.speMannequin(.defile) }
            action("Prendre soin de toi", "Apparence +3. \(Format.argent(1_500)).", "leaf.fill", cle: "soins", c) { engine.speMannequin(.soins) }
            action("Poster sur les réseaux", "Abonnés en hausse.", "iphone", cle: "reseaux", c) { engine.speMannequin(.reseaux) }
            action("Viser une plus grande agence", "Si ta réputation et ton apparence suivent.", "arrow.up.circle.fill", cle: "agence", c) { engine.speMannequin(.agence) }
        }
    }

    // MARK: Cinéma

    @ViewBuilder
    private func cinema(_ c: SpeCarriere, _ j: Joueur) -> some View {
        Section("Fiche") {
            SpeVue.ligne("Scénarios prêts", "\(c.scenarios)", "doc.text.fill")
            SpeVue.ligne("Films", "\(c.films.count)", "film.fill")
        }
        if let p = c.projet {
            Section("En cours") {
                Text("🎬 « \(p.titre) » · \(SpeCatalogue.nomGenreFilm(p.genre)) · \(SpeCatalogue.taillesFilm[p.taille])")
                Text("Sortie au prochain passage d'année.").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            let tmax = SpeMoteur.tailleMax(c)
            let t = min(tailleFilm, tmax)
            let budget = Int(Double(SpeCatalogue.budgetsFilm[t]) * (1 + SpeCatalogue.surcoutCasting[castingFilm]))
            Section {
                TextField("Titre (facultatif)", text: $titreFilm)
                Picker("Genre", selection: $genreFilm) {
                    ForEach(SpeCatalogue.genresFilm.indices, id: \.self) { i in Text("\(SpeCatalogue.genresFilm[i].emoji) \(SpeCatalogue.genresFilm[i].nom)").tag(SpeCatalogue.genresFilm[i].id) }
                }
                Picker("Taille", selection: $tailleFilm) {
                    ForEach(0...tmax, id: \.self) { i in Text(SpeCatalogue.taillesFilm[i]).tag(i) }
                }
                Picker("Casting", selection: $castingFilm) {
                    ForEach(0..<3, id: \.self) { i in Text(SpeCatalogue.castings[i]).tag(i) }
                }
                if t > 0 {
                    Toggle("Financer avec ton argent", isOn: $autoFinance)
                }
                SpeVue.ligne("Budget", Format.argent(budget), "eurosign.circle.fill")
                Button {
                    message = engine.speTourner(titre: titreFilm, genre: genreFilm, taille: t, casting: castingFilm, autoFinance: autoFinance)
                    titreFilm = ""
                } label: {
                    Label("Tourner ce film", systemImage: "video.fill").font(.headline)
                }
                .disabled(c.actionsAnnee.contains("tournage"))
            } header: {
                Text("Nouveau film")
            } footer: {
                Text(t == 0 ? "Un court-métrage se finance toujours toi-même." : (autoFinance
                     ? "Tu paies le budget, tu touches la moitié des recettes."
                     : "Un producteur paie s'il te fait confiance (réputation \(SpeMoteur.reputationProducteur[t]) minimum) ; tu touches un cachet et un bonus si ça marche."))
            }
        }
        Section("Cette année") {
            action("Écrire un scénario", "Inspiration +10. Les scénarios prêts améliorent tes films.", "pencil", cle: "scenario", c) { engine.speEcrireScenario() }
            if c.niveau >= 3 {
                action("Donner une masterclass", "Argent et réputation.", "graduationcap.fill", cle: "masterclass", c) { engine.speMasterclass() }
            }
        }
        if !c.films.isEmpty {
            Section("Filmographie") {
                ForEach(c.films.reversed()) { film in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("« \(film.titre) » (\(film.ageTournage + 1) ans)").font(.subheadline.weight(.semibold))
                        Text("\(SpeCatalogue.nomGenreFilm(film.genre)) · critique \(film.critique)/100" + (film.taille > 0 ? " · \(Format.argent(film.recettes))" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                        if !film.prix.isEmpty {
                            Text("🏆 " + film.prix.joined(separator: ", ")).font(.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: Musique

    @ViewBuilder
    private func musique(_ c: SpeCarriere, _ j: Joueur) -> some View {
        Section("Fiche") {
            SpeVue.ligne(c.enGroupe ? "Groupe" : "Nom de scène", c.nomScene, "music.mic")
            SpeVue.ligne("Style", SpeCatalogue.nomGenreMusique(c.genre), "music.note")
            SpeVue.ligne("Label", c.label.isEmpty ? "Indépendant" : c.label, "opticaldisc.fill")
            SpeVue.ligne("Fans", "\(c.fans)", "person.3.fill")
            SpeVue.ligne("Chansons en stock", "\(c.chansons)", "doc.text.fill")
        }
        if !c.offreLabel.isEmpty {
            Section {
                action("Signer chez \(c.offreLabel)", "Une avance et de la promo. Le label garde l'essentiel des streams.", "signature", cle: "signer", c) { engine.speMusique(.signer) }
            } header: {
                Text("Offre de label")
            }
        }
        Section("Cette année") {
            action("Écrire des chansons", "Guitare, piano ou chant aident.", "pencil", cle: "ecrire", c) { engine.speMusique(.ecrire) }
            action("Enregistrer un album", "8 chansons minimum." + (c.label.isEmpty ? " Studio : \(Format.argent(2_500 * (c.niveau + 1)))." : " Payé par le label."), "opticaldisc.fill", cle: "album", c) { engine.speMusique(.album) }
            action("Partir en tournée", "Argent et fans. Fatigant.", "bus.fill", cle: "tournee", c) { engine.speMusique(.tournee) }
            action("Tourner un clip", "\(Format.argent(1_500 * (c.niveau + 1))). Parfois, ça devient viral.", "video.fill", cle: "clip", c) { engine.speMusique(.clip) }
            action("Concert caritatif", "Karma et quelques fans.", "heart.fill", cle: "caritatif", c) { engine.speMusique(.caritatif) }
            if !c.label.isEmpty {
                action("Quitter \(c.label)", "Tu gardes tes revenus, sans promo.", "door.left.hand.open", cle: "quitterLabel", c) { engine.speMusique(.quitterLabel) }
            }
        }
        if !c.albums.isEmpty {
            Section("Discographie") {
                ForEach(c.albums.reversed()) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("« \(a.titre) » (\(a.age) ans)").font(.subheadline.weight(.semibold))
                        Text("Note \(a.note)/100 · \(a.ventes) ventes" + (a.certification.map { " · \($0)" } ?? ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Salle de sport

struct SpeSalleView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?

    var body: some View {
        Feuille(titre: "Salle de sport") {
            List {
                if let j = engine.joueur {
                    let e = j.speciales ?? SpeEtat()
                    Section {
                        JaugeModule(titre: "Force", icone: "dumbbell.fill", valeur: e.force)
                        JaugeModule(titre: "Technique", icone: "figure.boxing", valeur: e.technique)
                        JaugeModule(titre: "Cardio", icone: "heart.fill", valeur: e.cardio)
                    } footer: {
                        Text("Sans entraînement, tout baisse doucement chaque année. Utile pour le MMA et le sport pro, et bon pour la santé.")
                    }
                    Section("Abonnement") {
                        ForEach(0..<4, id: \.self) { n in
                            Button {
                                message = engine.speAbonnement(n)
                            } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(SpeCatalogue.abonnements[n]).font(.headline).foregroundStyle(Theme.encre)
                                        if n > 0 {
                                            Text("\(SpeCatalogue.descriptionsAbonnement[n]) \(Format.argent(SpeCatalogue.prixAbonnement[n]))/an.")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if e.abonnement == n { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                                }
                            }
                            .disabled(e.abonnement == n)
                        }
                    }
                    Section("Cette année") {
                        ForEach(SpeEntrainement.allCases) { t in
                            let fait = e.actionsSalle.contains(t.rawValue)
                            Button {
                                message = engine.speEntrainer(t)
                            } label: {
                                SpeLigneEmoji(emoji: t.emoji, titre: t.titre, sousTitre: fait ? "Déjà fait cette année" : t.description,
                                           verrou: fait ? "fait" : nil, couleur: CategorieMenu.activites.couleur)
                            }
                            .buttonStyle(.plain)
                            .disabled(fait)
                        }
                    }
                }
            }
            .alerteResultat($message)
        }
    }
}

// MARK: - Musée

struct SpeMuseeView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?
    @State private var nom = ""
    @State private var theme = "beauxarts"
    @State private var taille = 0
    @State private var confirmerDon = false
    @State private var confirmerVente = false

    var body: some View {
        Feuille(titre: "Mon musée") {
            List {
                if let j = engine.joueur {
                    let e = j.speciales ?? SpeEtat()
                    if let m = e.musee {
                        tableau(m, j)
                    } else {
                        ouverture(e, j)
                    }
                }
            }
            .alerteResultat($message)
            .confirmationDialog("Donner le musée à l'État ?", isPresented: $confirmerDon, titleVisibility: .visible) {
                Button("Donner le musée et ses œuvres") { message = engine.speMusee(.donner) }
                Button("Annuler", role: .cancel) {}
            }
            .confirmationDialog("Vendre le musée ?", isPresented: $confirmerVente, titleVisibility: .visible) {
                Button("Vendre bâtiment et collection", role: .destructive) { message = engine.speMusee(.vendre) }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func ouverture(_ e: SpeEtat, _ j: Joueur) -> some View {
        Section {
            Text("Ouvre ton propre musée : choisis un thème, achète des œuvres, fixe le prix du billet. Plus la collection est prestigieuse, plus les visiteurs viennent. Les charges, elles, tombent chaque année.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        Section("Ton musée") {
            TextField("Nom (facultatif)", text: $nom)
            Picker("Thème", selection: $theme) {
                ForEach(SpeCatalogue.themesMusee.indices, id: \.self) { i in Text("\(SpeCatalogue.themesMusee[i].emoji) \(SpeCatalogue.themesMusee[i].nom)").tag(SpeCatalogue.themesMusee[i].id) }
            }
            Picker("Taille", selection: $taille) {
                ForEach(0..<3, id: \.self) { i in Text("\(SpeCatalogue.taillesMusee[i]) · \(Format.argent(SpeCatalogue.prixOuverture[i]))").tag(i) }
            }
            Button {
                message = engine.speOuvrirMusee(nom: nom, theme: theme, taille: taille)
            } label: {
                Label("Ouvrir le musée", systemImage: "building.columns.fill").font(.headline)
            }
        }
        if !e.anciensMusees.isEmpty {
            Section("Anciens musées") {
                ForEach(e.anciensMusees, id: \.self) { Text($0).font(.subheadline) }
            }
        }
    }

    @ViewBuilder
    private func tableau(_ m: SpeMusee, _ j: Joueur) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("🏛️ \(m.nom)").font(.title3.bold())
                Text("\(SpeCatalogue.taillesMusee[m.taille]) · \(SpeCatalogue.nomTheme(m.theme)) · ouvert à \(m.ageOuverture) ans")
                    .font(.caption).foregroundStyle(.secondary)
            }
            JaugeModule(titre: "Prestige", icone: "crown.fill", valeur: m.prestige)
            JaugeModule(titre: "Notoriété", icone: "megaphone.fill", valeur: m.notoriete)
            SpeVue.ligne("Visiteurs l'an dernier", "\(m.visiteursAn)", "person.3.fill")
            SpeVue.ligne("Résultat l'an dernier", Format.argent(m.resultatAn), "eurosign.circle.fill")
            SpeVue.ligne("Charges par an", Format.argent(SpeCatalogue.chargesMusee[m.taille] + m.collection.count * 2_000), "arrow.up.circle.fill")
            if !m.expoAnnee.isEmpty { SpeVue.ligne("Exposition", m.expoAnnee, "sparkles") }
        }
        Section("Prix du billet") {
            Picker("Billet", selection: Binding(get: { m.prixBillet }, set: { engine.speMuseePrix($0) })) {
                Text("Gratuit").tag(0)
                Text("8 €").tag(8)
                Text("15 €").tag(15)
                Text("25 €").tag(25)
            }
            .pickerStyle(.segmented)
        }
        Section("Cette année") {
            LigneAction(titre: "Exposition temporaire", sousTitre: m.actionsAnnee.contains("expo") ? "Déjà fait cette année" : "Plus de visiteurs et de notoriété. \(Format.argent(40_000 * (m.taille + 1) * (m.taille + 1))).",
                        icone: "sparkles", actif: !m.actionsAnnee.contains("expo")) { message = engine.speMusee(.expo) }
            LigneAction(titre: "Gala de mécènes", sousTitre: m.actionsAnnee.contains("gala") ? "Déjà fait cette année" : "Lever des fonds.",
                        icone: "wineglass.fill", actif: !m.actionsAnnee.contains("gala")) { message = engine.speMusee(.gala) }
            if m.taille < 3 {
                LigneAction(titre: "Agrandir", sousTitre: "\(SpeCatalogue.taillesMusee[m.taille + 1]) · \(Format.argent(SpeCatalogue.prixAgrandir[m.taille + 1]))" + (m.taille == 2 ? " · prestige 70" : ""),
                            icone: "building.2.fill") { message = engine.speMusee(.agrandir) }
            }
        }
        Section {
            ForEach(SpeMoteur.marche(m, age: j.age)) { o in
                Button {
                    message = engine.speAcheterOeuvre(o)
                } label: {
                    oeuvreLigne(o, prix: SpeMoteur.prixAchat(o), action: "Acheter")
                }
            }
        } header: {
            Text("Sur le marché cette année")
        } footer: {
            Text("\(m.collection.count)/\(SpeCatalogue.capaciteOeuvres[m.taille]) places. Trois acquisitions par an. Une œuvre hors thème compte moitié moins pour le prestige.")
        }
        if !m.collection.isEmpty {
            Section("Collection") {
                ForEach(m.collection) { o in
                    oeuvreLigne(o, prix: o.valeur, action: nil)
                        .swipeActions {
                            Button("Vendre", role: .destructive) { message = engine.speVendreOeuvre(o.id) }
                        }
                }
                Text("Glisse une œuvre vers la gauche pour la vendre aux enchères.").font(.caption).foregroundStyle(.secondary)
            }
        }
        Section {
            Button("Donner le musée à l'État") { confirmerDon = true }
            Button("Vendre le musée", role: .destructive) { confirmerVente = true }
        }
    }

    private func oeuvreLigne(_ o: SpeOeuvre, prix: Int, action: String?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(o.nom).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.encre)
                Text("\(o.auteur) · \(SpeCatalogue.nomTheme(o.theme)) · prestige \(o.prestige)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.argent(prix)).font(.caption.weight(.bold)).foregroundStyle(Theme.encre)
                if let a = action { Text(a).font(.caption2).foregroundStyle(Theme.accent) }
            }
        }
    }
}

// MARK: - Investissements

struct SpeInvestView: View {
    @EnvironmentObject var engine: GameEngine
    @State private var message: String?
    @State private var type: SpeInvestType = .combattant
    @State private var palier = 0

    var body: some View {
        Feuille(titre: "Investisseur") {
            List {
                if let j = engine.joueur {
                    let e = j.speciales ?? SpeEtat()
                    Section {
                        Picker("Projet", selection: $type) {
                            ForEach(SpeInvestType.allCases) { t in Text("\(t.emoji) \(t.nom)").tag(t) }
                        }
                        Text(type.description).font(.caption).foregroundStyle(.secondary)
                        Picker("Mise", selection: $palier) {
                            ForEach(0..<3, id: \.self) { i in Text(Format.argent(type.paliers[i])).tag(i) }
                        }
                        .pickerStyle(.segmented)
                        Button {
                            message = engine.speInvestir(type, palier: palier)
                        } label: {
                            Label("Investir", systemImage: "banknote.fill").font(.headline)
                        }
                    } header: {
                        Text("Nouveau placement")
                    } footer: {
                        Text("Les résultats tombent à chaque passage d'année. Rien n'est garanti.")
                    }
                    let actifs = e.investissements.filter { !$0.termine }
                    if !actifs.isEmpty {
                        Section("En cours") {
                            ForEach(actifs) { inv in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(inv.type.emoji) \(inv.nom)").font(.subheadline.weight(.semibold))
                                    Text("Mise \(Format.argent(inv.mise)) · valeur \(Format.argent(inv.valeur))").font(.caption).foregroundStyle(.secondary)
                                    if !inv.dernier.isEmpty { Text(inv.dernier).font(.caption2).foregroundStyle(.secondary) }
                                    if inv.type != .film && inv.type != .album {
                                        Button("Revendre (\(Format.argent(inv.valeur * 9 / 10)))") { message = engine.speRetirer(inv.id) }
                                            .font(.caption.weight(.semibold))
                                            .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    }
                    let finis = e.investissements.filter { $0.termine }
                    if !finis.isEmpty {
                        Section("Terminés") {
                            ForEach(finis) { inv in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(inv.type.emoji) \(inv.nom)").font(.subheadline)
                                    Text(inv.dernier).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .alerteResultat($message)
        }
    }
}

import SwiftUI

/// Écran des permis. Le moteur l'ouvre avec le chemin vers l'état stocké dans le joueur :
/// `PermisView(chemin: \.permis)`.
struct PermisView: View {
    @EnvironmentObject var engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    let chemin: WritableKeyPath<Joueur, PermisEtat?>

    @State private var message: String?
    @State private var session: PermisSession?
    @State private var confirmerSansPermis = false

    private var etat: PermisEtat { engine.joueur?[keyPath: chemin] ?? PermisEtat() }

    /// Modifie le joueur et l'état des permis en une seule sauvegarde.
    private func modifier(_ action: (inout Joueur, inout PermisEtat) -> Void) {
        engine.modifier { j in
            var p = j[keyPath: chemin] ?? PermisEtat()
            action(&j, &p)
            j[keyPath: chemin] = p
        }
    }

    /// Ajoute une ligne au journal et applique une éventuelle mort.
    private func conclure(_ j: inout Joueur, ligne: String, mort: String?) {
        engine.ajouterLigne(&j, ligne)
        if let cause = mort {
            var eff = Effets()
            eff.death = cause
            engine.appliquer(eff, &j)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let j = engine.joueur {
                    enTete(j)
                    sectionDetenus(j)
                    sectionExamens(j)
                    sectionRoute(j)
                    sectionCombines(j)
                    sectionCasier(j)
                }
            }
            .navigationTitle("Permis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
            .alert("FTCHTLife", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
            .confirmationDialog("Conduire sans permis ?", isPresented: $confirmerSansPermis, titleVisibility: .visible) {
                Button("Prendre le volant quand même", role: .destructive) { lancerBalade(nil) }
                Button("Non, je prends le bus", role: .cancel) {}
            } message: {
                Text("Amende, fourrière, prison en cas de récidive. Et ta mère qui va l'apprendre.")
            }
            .sheet(item: $session, onDismiss: {
                if engine.joueur?.vivant == false { dismiss() }
            }) { s in
                contenuSession(s)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func enTete(_ j: Joueur) -> some View {
        let p = etat
        if p.aPermisRoute || p.estAnnule(age: j.age) {
            Section {
                if p.aPermisRoute {
                    HStack {
                        Image(systemName: "creditcard.fill").foregroundStyle(Theme.accent)
                        Text("Points").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(p.points)/12")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.couleurStat(p.points * 100 / 12))
                    }
                    ProgressView(value: Double(p.points), total: 12)
                        .tint(Theme.couleurStat(p.points * 100 / 12))
                }
                Text(statutRoute(p, age: j.age)).font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Permis de conduire")
            }
        }
    }

    private func statutRoute(_ p: PermisEtat, age: Int) -> String {
        if let a = p.annuleJusqua, age < a { return "Annulé. Tu pourras repasser le permis à \(a) ans." }
        if let s = p.suspenduJusqua, age < s { return "Suspendu jusqu'à \(s) ans. Interdit de conduire." }
        if let f = p.finProbatoire, age < f { return "Probatoire jusqu'à \(f) ans. Le « A » collé derrière la voiture, c'est toi." }
        if p.points <= 4 { return "Plus que \(p.points) points. Les radars connaissent ta plaque par cœur." }
        return "Permis définitif. Tu peux râler sur les jeunes conducteurs."
    }

    @ViewBuilder
    private func sectionDetenus(_ j: Joueur) -> some View {
        let detenus = etat.detenus.filter { !$0.retire }
        if !detenus.isEmpty {
            Section("Tes permis") {
                ForEach(detenus) { d in
                    HStack(spacing: 12) {
                        Image(systemName: d.type.icone).foregroundStyle(Theme.accent).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.type.nom)
                            Text(detailDetenu(d, age: j.age)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func detailDetenu(_ d: PermisDetenu, age: Int) -> String {
        if d.faux { return "Faux, acheté à \(d.ageObtention) ans. Il brille bizarrement à la lumière." }
        if d.type.estRoute && etat.estSuspendu(age: age) { return "Obtenu à \(d.ageObtention) ans · suspendu" }
        return "Obtenu à \(d.ageObtention) ans"
    }

    @ViewBuilder
    private func sectionExamens(_ j: Joueur) -> some View {
        let p = etat
        let aPasser = PermisType.allCases.filter { PermisModule.prochaineEtape($0, p) != nil }
        if !aPasser.isEmpty {
            Section {
                ForEach(aPasser) { t in
                    let etape = PermisModule.prochaineEtape(t, p) ?? .code
                    let bloque = PermisModule.blocage(t, j, p)
                    LigneAction(titre: t.nom,
                                sousTitre: bloque ?? sousTitreExamen(t, etape, age: j.age),
                                icone: t.icone,
                                actif: bloque == nil) {
                        lancerExamen(t, etape)
                    }
                }
            } header: {
                Text("Passer un permis")
            } footer: {
                Text("Le code d'abord, la pratique ensuite. Une tentative de chaque par an. Avant 18 ans, tes parents paient.")
            }
        }
    }

    private func sousTitreExamen(_ t: PermisType, _ e: PermisModule.Etape, age: Int) -> String {
        let cout = PermisModule.prix(t, e, age: age)
        let prix = cout > 0 ? Format.argent(cout) : "payé par tes parents"
        switch e {
        case .code: return "Passer le code · \(prix)"
        case .pratique: return "Code réussi ✓ · Passer la pratique · \(prix)"
        }
    }

    @ViewBuilder
    private func sectionRoute(_ j: Joueur) -> some View {
        let p = etat
        let vehicules = PermisModule.vehiculesBalade(j, p)
        let blocageSortie = PermisModule.blocageBalade(j)
        let legal = p.conduitLegalement(age: j.age)
        if j.age >= 12 {
            Section("Sur la route") {
                ForEach(vehicules) { t in
                    LigneAction(titre: "Sortie : \(t.nomSortie)",
                                sousTitre: blocageSortie ?? "Une sortie par an. Il peut se passer n'importe quoi.",
                                icone: t.icone,
                                actif: blocageSortie == nil) {
                        lancerBalade(t)
                    }
                }
                if !legal {
                    LigneAction(titre: "Conduire sans permis",
                                sousTitre: blocageSortie ?? "Emprunter une voiture et prier.",
                                icone: "exclamationmark.triangle.fill",
                                actif: blocageSortie == nil) {
                        confirmerSansPermis = true
                    }
                    Toggle(isOn: Binding(get: { etat.conduiteSansPermis },
                                         set: { v in modifier { _, p in p.conduiteSansPermis = v } })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conduire sans permis au quotidien")
                            Text("Chaque année, un contrôle peut tomber.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tint(Theme.accent)
                }
                if p.aPermisRoute && p.points < 12 {
                    let b = PermisModule.blocageStage(j, p)
                    LigneAction(titre: "Stage de récupération de points",
                                sousTitre: b ?? "Deux jours, +4 points · 250 €",
                                icone: "person.3.fill",
                                actif: b == nil) {
                        var texte = ""
                        modifier { j, p in
                            texte = PermisModule.stageRecuperation(&j, &p)
                            engine.ajouterLigne(&j, "🪪 " + texte)
                        }
                        message = texte
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionCombines(_ j: Joueur) -> some View {
        let p = etat
        if j.age >= 16 {
            Section {
                ForEach(PermisType.allCases.filter { PermisModule.prochaineEtape($0, p) == .pratique }) { t in
                    let b = PermisModule.blocageSoudoyer(t, j, p)
                    LigneAction(titre: "Soudoyer l'examinateur (\(t.nomCourt))",
                                sousTitre: b ?? "Une enveloppe de \(Format.argent(PermisModule.prixPotDeVin(t))). Ou une amende.",
                                icone: "envelope.fill",
                                actif: b == nil) {
                        var texte = ""
                        modifier { j, p in
                            texte = PermisModule.soudoyer(t, &j, &p)
                            engine.ajouterLigne(&j, "💼 " + texte)
                        }
                        message = texte
                    }
                }
                DisclosureGroup("Acheter un faux permis") {
                    ForEach(PermisType.allCases.filter { !p.possede($0) }) { t in
                        let b = PermisModule.blocageFaux(t, j, p)
                        LigneAction(titre: t.nom,
                                    sousTitre: b ?? Format.argent(PermisModule.prixFaux(t)),
                                    icone: t.icone,
                                    actif: b == nil) {
                            var texte = ""
                            modifier { j, p in
                                texte = PermisModule.acheterFaux(t, &j, &p)
                                engine.ajouterLigne(&j, "🕶️ " + texte)
                            }
                            message = texte
                        }
                    }
                }
            } header: {
                Text("Combines")
            } footer: {
                Text("Le karma, lui, n'a pas de permis à points.")
            }
        }
    }

    @ViewBuilder
    private func sectionCasier(_ j: Joueur) -> some View {
        let infractions = etat.infractions.suffix(10).reversed()
        if !infractions.isEmpty {
            Section("Casier routier") {
                ForEach(Array(infractions)) { i in
                    HStack {
                        Text(i.libelle)
                        Spacer()
                        Text(i.points > 0 ? "−\(i.points) pts · \(i.age) ans" : "\(i.age) ans")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Lancement des épreuves

    private func lancerExamen(_ t: PermisType, _ e: PermisModule.Etape) {
        guard let j = engine.joueur else { return }
        if let b = PermisModule.blocage(t, j, etat) { message = b; return }
        var erreur: String?
        modifier { j, p in erreur = PermisModule.commencer(t, e, &j, p) }
        if let erreur = erreur { message = erreur; return }
        switch e {
        case .code:
            let questions = PermisModule.tirerQuestions(t).map { q -> PermisQuestion in
                var q = q
                q.question = PermisModule.remplir(q.question, j)
                return q
            }
            session = PermisSession(type: t, mode: .code(questions))
        case .pratique:
            session = PermisSession(type: t, mode: .pratique(PermisModule.tirerScenesExamen(t).map { remplirScene($0, j) }))
        }
    }

    private func lancerBalade(_ t: PermisType?) {
        guard let j = engine.joueur else { return }
        if let b = PermisModule.blocageBalade(j) { message = b; return }
        guard let scene = PermisModule.tirerBalade(t, j) else {
            message = "Il ne s'est rien passé. Tu as tourné autour du pâté de maisons, puis tu es rentré·e."
            return
        }
        modifier { j, _ in j.actionsAnnee.append(PermisModule.cleBalade) }
        session = PermisSession(type: t, mode: .balade(remplirScene(scene, j)))
    }

    private func remplirScene(_ s: PermisScene, _ j: Joueur) -> PermisScene {
        var s = s
        s.text = PermisModule.remplir(s.text, j)
        for i in s.choices.indices { s.choices[i].label = PermisModule.remplir(s.choices[i].label, j) }
        return s
    }

    @ViewBuilder
    private func contenuSession(_ s: PermisSession) -> some View {
        switch s.mode {
        case .code(let questions):
            let t = s.type ?? .voiture
            PermisCodeView(type: t, questions: questions,
                           triche: (PermisModule.ajusterChanceExamen?(0) ?? 0) >= 1) { bonnes, total in
                var texte = ""
                modifier { j, p in
                    texte = PermisModule.terminerCode(t, bonnes: bonnes, total: total, &j, &p)
                    engine.ajouterLigne(&j, "📝 Code du \(t.nomCourt) : " + texte)
                }
                return texte
            }
        case .pratique(let scenes):
            let t = s.type ?? .voiture
            PermisScenesView(titre: "Pratique · " + t.nom, scenes: scenes, examen: true, jouer: { choix in
                guard let j = engine.joueur else { return PermisResultatChoix(texte: "", reussi: true, eliminatoire: false) }
                let r = PermisModule.jouerChoixExamen(choix, t, j)
                return PermisResultatChoix(texte: r.texte, reussi: r.reussi, eliminatoire: r.eliminatoire)
            }, terminer: { fautes, elim in
                var texte = ""
                modifier { j, p in
                    texte = PermisModule.terminerPratique(t, fautesMineures: fautes, eliminatoire: elim, &j, &p)
                    engine.ajouterLigne(&j, "🚦 Pratique du \(t.nomCourt) : " + texte)
                }
                return texte
            })
        case .balade(let scene):
            PermisScenesView(titre: s.type.map { "Sortie : " + $0.nomSortie } ?? "Sans permis", scenes: [scene], examen: false, jouer: { choix in
                var texte = ""
                modifier { j, p in
                    let r = PermisModule.jouerChoixBalade(choix, type: s.type, &j, &p)
                    texte = r.texte
                    conclure(&j, ligne: (s.type?.emoji ?? "🚗") + " " + scene.text + " → " + choix.label + ". " + r.texte.replacingOccurrences(of: "\n\n", with: " "), mort: r.mort)
                }
                return PermisResultatChoix(texte: texte, reussi: true, eliminatoire: false)
            }, terminer: { _, _ in nil })
        }
    }
}

// MARK: - Session d'épreuve

struct PermisSession: Identifiable {
    enum Mode {
        case code([PermisQuestion])
        case pratique([PermisScene])
        case balade(PermisScene)
    }

    let id = UUID()
    /// nil pour une balade sans permis.
    let type: PermisType?
    let mode: Mode
}

struct PermisResultatChoix {
    var texte: String
    var reussi: Bool
    var eliminatoire: Bool
}

extension PermisType {
    /// « en voiture », « en bateau »… pour les sorties.
    var nomSortie: String {
        switch self {
        case .scooter: return "en scooter"
        case .voiture: return "en voiture"
        case .moto: return "à moto"
        case .poidsLourd: return "en camion"
        case .bus: return "en bus"
        case .bateau: return "en bateau"
        case .avion: return "en avion"
        case .helicoptere: return "en hélicoptère"
        case .chasse: return "à la chasse"
        case .armes: return "au stand de tir"
        case .peche: return "à la pêche"
        case .drone: return "avec ton drone"
        case .fusee: return "dans l'espace"
        }
    }
}

// MARK: - Code (quiz)

struct PermisCodeView: View {
    let type: PermisType
    let questions: [PermisQuestion]
    let triche: Bool
    let terminer: (Int, Int) -> String

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var bonnes = 0
    @State private var repondu: Int?
    @State private var resultat: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let r = resultat {
                        Text(r).font(.title3.weight(.semibold)).foregroundStyle(Theme.encre)
                        Button { dismiss() } label: {
                            Text("Fermer").frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent).tint(Theme.accent)
                    } else if questions.indices.contains(index) {
                        question(questions[index])
                    }
                }
                .padding()
            }
            .background(Theme.fond.ignoresSafeArea())
            .navigationTitle("Code · " + type.nomCourt)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if resultat == nil { Button("Abandonner") { finir() } }
                }
            }
        }
        .interactiveDismissDisabled(resultat == nil)
        .onAppear {
            if questions.isEmpty && resultat == nil {
                resultat = "L'examinateur a perdu les questions. Il te valide le code par pitié. " + terminer(1, 1)
            }
        }
    }

    @ViewBuilder
    private func question(_ q: PermisQuestion) -> some View {
        Text("Question \(index + 1) sur \(questions.count) · \(bonnes) bonne\(bonnes > 1 ? "s" : "") réponse\(bonnes > 1 ? "s" : "")")
            .font(.caption).foregroundStyle(.secondary)
        Text(q.question).font(.title3.weight(.semibold)).foregroundStyle(Theme.encre)
        ForEach(Array(q.reponses.enumerated()), id: \.offset) { i, rep in
            Button { repondre(i, q) } label: {
                HStack {
                    Text(rep).multilineTextAlignment(.leading)
                    Spacer()
                    if let r = repondu {
                        if i == q.bonne { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        else if i == r { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(couleur(i, q)))
                .foregroundStyle(Theme.encre)
            }
            .disabled(repondu != nil)
        }
        if let r = repondu {
            Text(feedback(r, q)).font(.callout).foregroundStyle(.secondary)
            Button { suivant() } label: {
                Text(index + 1 < questions.count ? "Question suivante" : "Voir le résultat")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent)
        }
    }

    private func couleur(_ i: Int, _ q: PermisQuestion) -> Color {
        guard let r = repondu else { return Theme.carte }
        if i == q.bonne { return Color.green.opacity(0.18) }
        if i == r { return Color.red.opacity(0.18) }
        return Theme.carte
    }

    private func feedback(_ r: Int, _ q: PermisQuestion) -> String {
        var texte = r == q.bonne ? "Bonne réponse ! " : "Mauvaise réponse. "
        if r != q.bonne && triche { texte = "Mauvaise réponse… mais l'examinateur a regardé ailleurs (mode Shkurtaaa). " }
        return texte + (q.explication ?? "")
    }

    private func repondre(_ i: Int, _ q: PermisQuestion) {
        repondu = i
        if i == q.bonne || triche { bonnes += 1 }
    }

    private func suivant() {
        repondu = nil
        if index + 1 < questions.count { index += 1 } else { finir() }
    }

    private func finir() {
        guard resultat == nil else { return }
        resultat = terminer(bonnes, questions.count)
    }
}

// MARK: - Situations (pratique et sorties)

struct PermisScenesView: View {
    let titre: String
    let scenes: [PermisScene]
    let examen: Bool
    let jouer: (PermisChoix) -> PermisResultatChoix
    /// Fautes mineures, faute éliminatoire → texte du verdict (nil = pas d'écran de verdict).
    let terminer: (Int, Bool) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var fautes = 0
    @State private var eliminatoire = false
    @State private var choixFait: String?
    @State private var resultat: PermisResultatChoix?
    @State private var verdict: String?
    @State private var fini = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let f = verdict {
                        Text(f).font(.title3.weight(.semibold)).foregroundStyle(Theme.encre)
                        boutonFermer
                    } else if fini {
                        boutonFermer
                    } else if scenes.indices.contains(index) {
                        scene(scenes[index])
                    } else {
                        Text("Il ne se passe rien. Absolument rien.").foregroundStyle(.secondary)
                        boutonFermer
                    }
                }
                .padding()
            }
            .background(Theme.fond.ignoresSafeArea())
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if examen && verdict == nil && !fini { Button("Abandonner") { abandonner() } }
                }
            }
        }
        .interactiveDismissDisabled(!fini && verdict == nil && !scenes.isEmpty)
        .onAppear {
            if scenes.isEmpty && examen && verdict == nil {
                verdict = "L'examinateur a oublié de venir. Il te note par téléphone. " + (terminer(0, false) ?? "")
            }
        }
    }

    private var boutonFermer: some View {
        Button { dismiss() } label: {
            Text("Fermer").frame(maxWidth: .infinity).padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent).tint(Theme.accent)
    }

    @ViewBuilder
    private func scene(_ s: PermisScene) -> some View {
        if examen {
            Text("Situation \(index + 1) sur \(scenes.count) · fautes : \(fautes)")
                .font(.caption).foregroundStyle(.secondary)
        }
        Text(s.text).font(.title3.weight(.semibold)).foregroundStyle(Theme.encre)
        if let r = resultat {
            if let c = choixFait {
                Text("→ " + c).font(.callout.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            Text(r.texte).foregroundStyle(Theme.encre)
            if examen && !r.reussi {
                Text(r.eliminatoire ? "❌ Faute éliminatoire" : "⚠️ Faute").font(.callout.weight(.bold))
                    .foregroundStyle(r.eliminatoire ? Color.red : Color.orange)
            }
            Button { suivant() } label: {
                Text(texteSuivant(r)).frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(Theme.accent)
        } else {
            ForEach(Array(s.choices.enumerated()), id: \.offset) { _, c in
                Button {
                    choixFait = c.label
                    let r = jouer(c)
                    if !r.reussi {
                        if r.eliminatoire { eliminatoire = true } else { fautes += 1 }
                    }
                    resultat = r
                } label: {
                    Text(c.label)
                        .multilineTextAlignment(.leading)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.carte))
                        .foregroundStyle(Theme.encre)
                }
            }
        }
    }

    private func texteSuivant(_ r: PermisResultatChoix) -> String {
        if !examen { return "Continuer" }
        if eliminatoire || index + 1 >= scenes.count { return "Résultat de l'examen" }
        return "Situation suivante"
    }

    private func suivant() {
        resultat = nil
        choixFait = nil
        if examen && !eliminatoire && index + 1 < scenes.count {
            index += 1
            return
        }
        if let f = terminer(fautes, eliminatoire) { verdict = f } else { fini = true; dismiss() }
    }

    private func abandonner() {
        verdict = "Tu as abandonné en plein examen. L'examinateur a noté « a pris la fuite ». " + (terminer(max(fautes, 2), true) ?? "")
    }
}

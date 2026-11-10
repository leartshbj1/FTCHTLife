import SwiftUI

// Écrans du module « Testament et guerre d'héritage ». Branchement : docs/SUCCESSION.md.

// MARK: - Rédiger son testament

struct SuccessionTestamentView: View {
    let joueur: Joueur
    let actuel: SuccessionTestament?
    /// Appelé avec le testament signé : le moteur appelle `Successions.enregistrer`.
    let onValider: (SuccessionTestament) -> Void
    var onDechirer: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var beneficiaire: SuccessionBeneficiaire = .egal
    @State private var choixId: UUID?
    @State private var oeuvreId: String?
    @State private var support: SuccessionSupport = .papier
    @State private var clauses: Set<String> = []
    @State private var annoncer = false
    @State private var initialise = false

    private static let maxClauses = 3

    private var enfants: [Relation] { joueur.relations.filter { $0.type == .enfant && $0.vivant } }
    private var amis: [Relation] { joueur.relations.filter { $0.type == .ami && $0.vivant } }
    private var partenaire: Relation? { joueur.relations.first { $0.type == .partenaire && $0.vivant } }

    private var beneficiairesPossibles: [SuccessionBeneficiaire] {
        SuccessionBeneficiaire.allCases.filter { b in
            switch b {
            case .aucun: return false
            case .enfant: return !enfants.isEmpty
            case .partenaire: return partenaire != nil
            case .ami: return !amis.isEmpty
            case .oeuvre: return true
            default: return true
            }
        }
    }

    private var testament: SuccessionTestament {
        var t = SuccessionTestament(beneficiaire: beneficiaire, support: support, clauses: Array(clauses).sorted(),
                                    secret: !annoncer, redigeA: joueur.age)
        switch beneficiaire {
        case .enfant:
            let e = enfants.first { $0.id == choixId } ?? enfants.first
            t.beneficiaireId = e?.id
            t.beneficiairePrenom = e?.prenom
        case .ami:
            let a = amis.first { $0.id == choixId } ?? amis.first
            t.beneficiaireId = a?.id
            t.beneficiairePrenom = a?.prenom
        case .partenaire:
            t.beneficiaireId = partenaire?.id
            t.beneficiairePrenom = partenaire?.prenom
        case .oeuvre:
            t.oeuvreId = oeuvreId ?? Successions.oeuvres.first?.id
        default:
            break
        }
        return t
    }

    var body: some View {
        NavigationStack {
            Form {
                if let actuel {
                    Section("Ton testament actuel") {
                        Text(Successions.description(actuel))
                        Text("Version n°\(actuel.versions), rédigée à \(actuel.redigeA) ans")
                            .font(.footnote).foregroundStyle(.secondary)
                        if let onDechirer {
                            Button("Le déchirer", role: .destructive) {
                                onDechirer()
                                dismiss()
                            }
                        }
                    }
                }

                Section("Qui touche tout ?") {
                    ForEach(beneficiairesPossibles) { b in
                        Button {
                            beneficiaire = b
                            choixId = nil
                        } label: {
                            HStack {
                                Image(systemName: b.icone).frame(width: 24)
                                Text(b.titre)
                                Spacer()
                                if beneficiaire == b { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    if beneficiaire == .enfant {
                        Picker("Enfant préféré", selection: $choixId) {
                            ForEach(enfants) { e in Text(e.prenom).tag(Optional(e.id)) }
                        }
                    }
                    if beneficiaire == .ami {
                        Picker("Ami", selection: $choixId) {
                            ForEach(amis) { a in Text(a.prenom).tag(Optional(a.id)) }
                        }
                    }
                    if beneficiaire == .oeuvre && !Successions.oeuvres.isEmpty {
                        Picker("Œuvre", selection: $oeuvreId) {
                            ForEach(Successions.oeuvres) { o in Text(Successions.majuscule(o.nom)).tag(Optional(o.id)) }
                        }
                    }
                }

                Section("Écrit sur…") {
                    ForEach(SuccessionSupport.choisissables) { s in
                        Button {
                            support = s
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.titre + (s.cout > 0 ? " · \(Format.argent(s.cout))" : ""))
                                    Text(s.detail).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if support == s { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if !Successions.clauses.isEmpty {
                    Section {
                        ForEach(Successions.clauses) { c in
                            Button {
                                if clauses.contains(c.id) {
                                    clauses.remove(c.id)
                                } else if clauses.count < Self.maxClauses {
                                    clauses.insert(c.id)
                                }
                            } label: {
                                HStack {
                                    Text(c.texte)
                                    Spacer()
                                    if clauses.contains(c.id) { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("Clauses spéciales (\(clauses.count)/\(Self.maxClauses))")
                    }
                }

                Section {
                    Toggle("L'annoncer à la famille", isOn: $annoncer)
                } footer: {
                    Text(annoncer
                         ? "Chacun saura ce qui l'attend. Le prochain repas de famille risque d'être sportif."
                         : "Secret. Ils le découvriront chez le notaire, en même temps que leur tension artérielle.")
                }

                Section("Aperçu") {
                    Text(Successions.description(testament))
                    HStack {
                        Text("Ambiance prévue après ta mort")
                        Spacer()
                        Text(SuccessionFlammes.texte(tensionEstimee)).accessibilityLabel("Tension \(tensionEstimee) sur 100")
                    }
                    if support.cout > 0 {
                        Text("Coût : \(Format.argent(support.cout))").foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        onValider(testament)
                        dismiss()
                    } label: {
                        Text("Signer le testament").bold().frame(maxWidth: .infinity)
                    }
                    .disabled(support.cout > joueur.argent)
                }
            }
            .navigationTitle("Mon testament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .onAppear(perform: initialiser)
        }
    }

    private var tensionEstimee: Int {
        var v = beneficiaire.drame + (100 - support.solidite) / 4
        v += clauses.compactMap { Successions.clause($0)?.drame }.reduce(0, +) * 4
        v += min(max(0, enfants.count - 1), 4) * 6
        v += (50 - joueur.stats.karma) / 5
        return Stats.borne(v)
    }

    private func initialiser() {
        guard !initialise else { return }
        initialise = true
        guard let a = actuel else {
            beneficiaire = enfants.isEmpty ? (partenaire != nil ? .partenaire : .chat) : .egal
            return
        }
        beneficiaire = beneficiairesPossibles.contains(a.beneficiaire) ? a.beneficiaire : .egal
        choixId = a.beneficiaireId
        oeuvreId = a.oeuvreId
        support = a.support == .aucun ? .papier : a.support
        clauses = Set(a.clauses)
        annoncer = !a.secret
    }
}

enum SuccessionFlammes {
    /// 🔥 de 1 à 5 selon la tension.
    static func texte(_ tension: Int) -> String {
        String(repeating: "🔥", count: min(5, max(1, tension / 20 + 1)))
    }

    static func libelle(_ tension: Int) -> String {
        switch tension {
        case ..<20: return "Calme (suspect)"
        case ..<40: return "Regards en coin"
        case ..<60: return "Portes qui claquent"
        case ..<80: return "Avocats en embuscade"
        default: return "Guerre totale"
        }
    }
}

// MARK: - Lecture du testament (écran de mort)

struct SuccessionOuvertureView: View {
    let lecture: SuccessionLecture
    let chroniques: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lecture du testament")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                    Text("Cabinet de \(lecture.notaire), une semaine après ta mort.")
                        .foregroundStyle(.white.opacity(0.7))
                }

                bloc {
                    Text(Successions.description(lecture.testament))
                    if !lecture.testament.clauses.isEmpty {
                        Text("Clauses spéciales :").bold().padding(.top, 4)
                        ForEach(lecture.testament.clauses, id: \.self) { id in
                            if let c = Successions.clause(id) { Text("• " + c.texte) }
                        }
                    }
                }

                bloc {
                    HStack {
                        Text(lecture.patrimoine < 0 ? "Dettes" : "Patrimoine").foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(Format.argent(lecture.patrimoine)).bold()
                    }
                    ForEach(lecture.parts) { p in
                        HStack(alignment: .top) {
                            Text(p.libelle)
                            Spacer()
                            Text(Format.argent(p.montant)).bold().monospacedDigit()
                        }
                    }
                }

                bloc {
                    HStack {
                        Text("Ambiance familiale").foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(SuccessionFlammes.texte(lecture.tension))
                    }
                    Text(SuccessionFlammes.libelle(lecture.tension)).bold()
                }

                if !chroniques.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ce qui s'est passé ensuite").font(.headline)
                        ForEach(Array(chroniques.enumerated()), id: \.offset) { _, ligne in
                            Text(ligne).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(24)
            .foregroundStyle(.white)
        }
        .background(Theme.encre.ignoresSafeArea())
    }

    private func bloc<C: View>(@ViewBuilder _ contenu: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8, content: contenu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Dossiers de succession (pour le joueur vivant)

struct SuccessionDossierView: View {
    let etat: SuccessionEtat?

    var body: some View {
        List {
            Section("Ton testament") {
                if let t = etat?.testament {
                    Text(Successions.description(t))
                    Text(t.secret ? "Secret" : "Annoncé à la famille").font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("Aucun. Ta famille se battra selon la loi, c'est-à-dire n'importe comment.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(Array((etat?.dossiers ?? []).reversed())) { d in
                Section {
                    ligne("Statut", d.ouvert ? "En guerre" : "Affaire classée")
                    ligne("Ta place", libelleRole(d.role))
                    ligne("Patrimoine", Format.argent(d.patrimoine))
                    ligne("Bilan pour toi", Format.argent(d.bilan))
                    ligne("Ambiance", SuccessionFlammes.texte(d.tension))
                    ForEach(d.rivaux.sorted(by: { $0.hostilite > $1.hostilite })) { r in
                        HStack {
                            Text(Successions.majuscule(r.designation))
                            Spacer()
                            Text(r.hostilite >= 60 ? "Ennemi juré" : r.hostilite >= 30 ? "Méfiant" : "Calme")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(Array(d.historique.enumerated()), id: \.offset) { _, h in
                        Text(h).font(.footnote)
                    }
                } header: {
                    Text("Succession de \(d.defuntPrenom) \(d.defuntNom)")
                }
            }
        }
        .navigationTitle("Héritages")
    }

    private func ligne(_ titre: String, _ valeur: String) -> some View {
        HStack {
            Text(titre).foregroundStyle(.secondary)
            Spacer()
            Text(valeur).bold()
        }
    }

    private func libelleRole(_ r: SuccessionRole) -> String {
        switch r {
        case .seul: return "Seul héritier"
        case .favori: return "Enfant préféré"
        case .egal: return "Partage"
        case .desherite: return "Déshérité"
        }
    }
}

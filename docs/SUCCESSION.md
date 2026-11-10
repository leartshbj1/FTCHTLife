# Testament et guerre d'héritage

Le joueur peut rédiger son testament (tout au chat, à l'enfant préféré, rien à personne…), sur un support
plus ou moins solide (notaire, serviette de restaurant, vidéo, tatouage), avec des clauses absurdes.
Quand quelqu'un meurt, la famille se déchire : lecture du testament, cousins qui surgissent, procès,
maison vendue en douce, chat milliardaire. L'héritier (le joueur) vit ça comme une suite d'épisodes à choix,
étalés sur plusieurs années.

Deux cas :

1. **Un parent du joueur meurt** (déjà géré par le moteur) : au lieu de « Tu hérites de X € », on ouvre un
   **dossier de succession**. Le parent PNJ a un testament tiré au hasard (souvent un partage égal, parfois tout au chat).
2. **Le joueur meurt** : l'écran de mort montre la lecture de **son** testament et une chronique de la guerre
   qui a suivi. Si le module générations fait continuer avec un enfant, ce dossier passe à l'enfant, qui joue la guerre.

Code : `FTCHTLife/Succession/`. Données : `FTCHTLife/Resources/Data/Succession/<Episodes|Clauses|Oeuvres|Chroniques>/*.json`,
plus des événements classiques `FTCHTLife/Resources/Data/Events/testament_*.json` (tags ci-dessous).
Vérification : `python3 tools/validate_succession.py`.

## Déroulé d'un dossier

- **Ouverture** (phase `ouverture`) : la lecture du testament, l'année de la mort (ou aux 18 ans de l'héritier
  s'il est mineur). La part du joueur est versée automatiquement en plus des effets de l'épisode.
- **Guerre** (phase `guerre`) : 1 à 4 épisodes selon la **tension** (0 à 100), un tous les 1 à 3 ans.
  Tirés au moment voulu parmi ceux dont les conditions sont remplies.
- **Suites** (phase `suite`) : jamais tirées au hasard, seulement programmées par `next` (procès en appel, cousin qui revient…).
- Le dossier se ferme quand il n'y a plus rien de programmé, ou quand une issue a `"close": true`.

La **tension** vient du testament (tout au chat = 38, partage égal = 5), de son support (une serviette se conteste
facilement), des clauses, du nombre de frères et sœurs, de la taille du patrimoine et du karma du défunt.

**Rôle** du joueur : `seul` (seul héritier), `favori` (désigné parmi d'autres), `egal` (partage), `desherite`
(tout part ailleurs : un frère, le partenaire, le chat, une œuvre, un inconnu, personne).

**Rivaux** : les frères et sœurs (vraies relations) et des prétendants inventés (cousin éloigné, tante, nouveau compagnon du défunt,
demi-frère surprise, voisin qui avait les clés…), avec une hostilité de 0 à 100. Le rival principal est le plus hostile.

## Format d'un épisode (`Data/Succession/Episodes/*.json`)

Chaque fichier est un tableau :

```json
{
  "id": "suc_pro_0001",
  "phase": "guerre",
  "weight": 2,
  "conditions": { "roles": ["egal", "favori"], "fratrie": true, "minTension": 40 },
  "text": "{Rival} conteste le testament de {le_defunt} : « Il était écrit sur une serviette, ça ne compte pas. »",
  "choices": [
    {
      "label": "Prendre un avocat",
      "outcomes": [
        { "chance": 0.5, "text": "Ton avocat gagne. {Rival} pleure dans le couloir.", "effects": { "money": -3000, "happiness": 8, "rival": 10 } },
        { "chance": 0.5, "text": "Procès en appel.", "effects": { "money": -5000 }, "next": ["suc_pro_0002"], "delay": [1, 2] }
      ]
    },
    {
      "label": "Lui laisser la moitié",
      "outcomes": [ { "text": "{Rival} t'embrasse. Tu sens qu'il a déjà prévu la suite.", "effects": { "moneyPct": -25, "rival": -40 }, "close": true } ]
    }
  ]
}
```

| Champ | Rôle | Défaut |
|---|---|---|
| `id` | unique, préfixe `suc_` (le moteur reconnaît ces événements à ce préfixe) | obligatoire |
| `phase` | `ouverture`, `guerre` ou `suite` | obligatoire |
| `weight` | fréquence relative | 1 |
| `unique` | `true` = une fois par vie ; sinon une fois par dossier | false |
| `conditions` | voir ci-dessous | aucune |
| `text` | texte (variables ci-dessous) | obligatoire |
| `effects`, `next`, `delay`, `setFlags`, `close` | pour un épisode **sans** choix | aucun |
| `choices` | `label` + `outcomes` (`chance`, `text`, `effects`, `next`, `delay`, `setFlags`, `clearFlags`, `close`) | aucun |

**Conditions** (toutes optionnelles) : `roles` (`seul`, `favori`, `egal`, `desherite`), `beneficiaires`
(`egal`, `enfant`, `partenaire`, `chat`, `oeuvre`, `personne`, `inconnu`, `ami`, `aucun`), `supports`
(`notaire`, `papier`, `serviette`, `video`, `tatouage`, `aucun`), `liens` (`mere`, `pere`, `autre`),
`minTension`/`maxTension`, `minPatrimoine`/`maxPatrimoine` (en €), `dettes` (patrimoine négatif), `fratrie`
(le joueur a des frères/sœurs cohéritiers), `testament` (le défunt avait écrit un testament), `clauses` (au moins une de ces clauses),
`flags`/`excludeFlags` (drapeaux du dossier), `minAge`/`maxAge` (âge du joueur), `minHostilite`/`maxHostilite` (rival principal).

**Effets** : ceux des événements (`happiness`, `health`, `smarts`, `looks`, `karma`, `money`, `relationships`, `death`) plus
`moneyPct` (pourcentage du patrimoine, ex. `-20` = tu perds 20 % de l'héritage ; ignoré si dettes) et `rival`
(variation de l'hostilité du rival principal, ex. `-30` pour une réconciliation).

**Variables** : celles du moteur (`{prenom}`, `{e}`, `{ville}`…) plus :

| Variable | Exemple |
|---|---|
| `{defunt}` | Josiane |
| `{le_defunt}` / `{Le_defunt}` | ta mère / Ta mère |
| `{rival}` / `{Rival}` | ton cousin Gérard / Ton cousin Gérard |
| `{rival_prenom}` | Gérard |
| `{frere}` | prénom d'un frère ou d'une sœur cohéritier (mettre `"fratrie": true`) |
| `{bien}` | la maison de famille |
| `{patrimoine}` | 240'000 € |
| `{part}` | ta part : 120'000 € |
| `{pct:10}` | 10 % du patrimoine, formaté : 24'000 € |
| `{beneficiaire}` | celui qui touche tout : Kevin, le chat Moustache, la Fondation… |
| `{chat}` | Moustache |
| `{oeuvre}` | l'Association des pigeons sans abri de Lausanne |
| `{notaire}` | Maître Duchemin |

## Clauses, œuvres, chroniques

- `Clauses/*.json` : `{ "id": "cla_0001", "texte": "Être enterré avec mon téléphone chargé", "drame": 1, "reaction": "Ta fille demande qui paiera l'abonnement." }`
- `Oeuvres/*.json` : `{ "id": "oeu_0001", "nom": "la Fondation pour la retraite des pigeons" }`
- `Chroniques/*.json` (ce qui se passe après la mort **du joueur**, raconté au joueur mort) :
  `{ "id": "chr_0001", "weight": 1, "conditions": { "beneficiaires": ["chat"] }, "text": "…" }`.
  Variables : `{heritier}` (celui qui touche le plus), `{enfant}` (un de tes enfants), `{partenaire}`, `{rival}`/`{Rival}`,
  `{bien}`, `{patrimoine}`, `{chat}`, `{oeuvre}`, `{notaire}`, `{beneficiaire}`. Conditions utiles : `beneficiaires`, `supports`,
  `minTension`, `maxTension`, `dettes`, `enfants`, `clauses`, `minPatrimoine`.

## Tags pour les événements classiques

`Successions.tags(etat)` ajoute : `testament` (le joueur a rédigé le sien), `testament_<beneficiaire>` (ex. `testament_chat`),
`testament_secret`, `testament_annonce`, `heritier` (a déjà hérité), `heritier_en_guerre` (un dossier est ouvert),
`desherite`, `a_herite_gros` (≥ 100 000 € touchés). Les événements `Data/Events/testament_*.json` les utilisent.

## Branchement dans le moteur (fil moteur)

1. `Joueur` : `var succession: SuccessionEtat?` (optionnel, anciennes sauvegardes compatibles).
2. `tags(_:)` : `t.formUnion(Successions.tags(j.succession))`.
3. `vieillir`, mort d'un parent : remplacer le bloc « Tu hérites de … » par
   ```swift
   if r.type.estParent {
       var etat = j.succession ?? SuccessionEtat()
       let autreParent = j.relations.first { $0.type.estParent && $0.id != r.id && $0.vivant }
       Successions.ouvrirPourParent(defunt: r, joueur: j, autreParentVivant: autreParent != nil, etat: &etat)
       j.succession = etat
   }
   ```
4. `vieillir`, juste avant `tirerEvenements()` :
   ```swift
   var etat = j.succession ?? SuccessionEtat()
   let episodes = Successions.episodesDeLAnnee(joueur: j, etat: &etat)
   j.succession = etat; joueur = j
   episodes.forEach { declencher($0) }
   ```
   Les épisodes sont des `Evenement` ordinaires (id `suc_…`), textes et montants déjà calculés.
   La part d'héritage est dans les effets de l'épisode d'ouverture.
5. `choisir` : après le tirage de l'issue,
   ```swift
   if aff.evenement.id.hasPrefix("suc_"), let issue {
       var etat = j.succession ?? SuccessionEtat()
       let k = c.outcomes.firstIndex(of: issue) ?? 0
       Successions.apresChoix(evenementId: aff.evenement.id, choix: index, issue: k, joueur: j, etat: &etat)
       j.succession = etat
   }
   ```
   Pour un épisode sans choix, `episodesDeLAnnee` fait déjà le suivi.
6. Activités (18 ans et plus) : « Rédiger mon testament » ouvre
   `SuccessionTestamentView(joueur: j, actuel: j.succession?.testament) { testament, redaction in … }` ;
   dans la fermeture : `engine.modifier { j in Successions.enregistrer(testament, redaction, &j) ; … }` — voir
   `Successions.appliquerRedaction` qui renvoie les lignes de journal ; le moteur applique `redaction.cout`, `bonheur`,
   `karma` et `liens` (par id de relation), puis met `testament` dans `j.succession`.
7. Mort du joueur : `let dossier = Successions.ouvrirPourJoueur(defunt: j, biens: [...])` (une fois, à garder),
   puis afficher `SuccessionOuvertureView(dossier: dossier, chroniques: Successions.chroniques(dossier: dossier, defunt: j))`
   dans `DeathView` (bouton « Lecture du testament »).
8. Générations : quand on continue avec l'enfant `e` (une `Relation` du défunt),
   `nouveauJoueur.succession = Successions.etatPourHeritier(dossier: dossier, heritier: e, defunt: j)`.
   Il héritera à l'ouverture (même année, ou à ses 18 ans).
9. Profil ou Relations : `SuccessionDossierView(etat: j.succession)` liste les successions en cours et passées.
10. Signaux pour les répercussions : `heritage` (ouverture avec part > 0), et si besoin `proces_gagne` / `proces_perdu`
    (drapeaux de dossier `proces_gagne`, `proces_perdu`).

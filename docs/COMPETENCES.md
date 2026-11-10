# Compétences

27 talents (langues, musique, cuisine, bricolage, sport, code, séduction…) notés de 0 à 100 XP, avec 5 niveaux.
Ils montent en pratiquant et **débloquent des choix cachés** dans les événements.

- Code : `FTCHTLife/Competences/` (`Competences.swift` règles, `CompetencesModele.swift` types, `CompetencesActions.swift` actions du moteur, `CompetencesView.swift` écran).
- Données : `Resources/Data/Competences/` (liste), `Resources/Data/CompetencesCours/` (cours), `Resources/Data/CompetencesSources/` (gains automatiques).
- Événements : `Resources/Data/Events/competences_01.json` et `competences_02.json` (ids `cmp_NNNN`, 150 événements, ~150 choix cachés).
- Vérification : `python3 tools/validate_competences.py` (compétences, cours, sources, et tous les événements qui utilisent les clés de compétences).
- Les fichiers JSON de liste, cours et sources sont générés par `tools/gen/*.py` (plus lisibles) : modifiez le script puis relancez-le, ou éditez le JSON directement.

## Niveaux

| Niveau | XP | Nom |
|---|---|---|
| 0 | 0-4 | Jamais essayé |
| 1 | 5 | Débutant |
| 2 | 20 | Amateur |
| 3 | 40 | Confirmé |
| 4 | 65 | Expert |
| 5 | 90 | Maître |

Chaque compétence a aussi un titre rigolo par niveau (« Cordon-bleu du dimanche ») et une phrase quand on l'atteint.

Le gain réel = gain de base × facteur : rendements décroissants (×1 aux niveaux 0-1, ×0,4 au niveau 5), intelligence
(×0,75 à ×1,25), âge (enfants ×1,2, langues ×1,6 ; 55+ ×0,8 ; 70+ ×0,65). Sans pratique depuis 4 ans, une compétence
au-dessus de 20 XP perd 2 XP par an (3 pour les langues et le sport, 1 pour le jardinage), jamais sous 20.

## Ids

- Langues : `anglais`, `espagnol`, `allemand`, `italien`, `albanais`, `japonais`, `portugais`, `arabe`
- Arts : `guitare`, `piano`, `chant`, `danse`, `dessin`, `photo`
- Pratique : `cuisine`, `bricolage`, `mecanique`, `jardinage`
- Corps : `sport`, `survie`
- Tête : `code`, `echecs`
- Social : `seduction`, `eloquence`, `humour`, `marchandage`, `magie`

## Dans les événements (pour tous les fils)

Trois clés optionnelles :

```json
{
  "conditions": { "skills": { "guitare": 3 } },
  "choices": [
    { "label": "Prendre la guitare", "requiresSkill": { "guitare": 2 }, "outcomes": [
      { "chance": 1, "text": "…", "effects": { "happiness": 6, "skills": { "guitare": 4 } } }
    ]},
    { "label": "Applaudir poliment", "outcomes": [ … ] }
  ]
}
```

- `requiresSkill` sur un choix (niveau mini 1 à 5, plusieurs clés = toutes requises) : **choix caché**, visible seulement
  si le joueur a le niveau. Toujours garder au moins un choix sans `requiresSkill`.
- `conditions.skills` : l'événement n'arrive qu'aux joueurs qui ont ce niveau.
- `effects.skills` : XP gagnée (3 à 12 en général, jusqu'à 20 pour un vrai stage) ou perdue (négatif).
- Choisir un choix caché donne aussi +2 XP de base dans la compétence utilisée.

N'importe quel module peut aussi appeler directement :

```swift
let g = Competences.gagner("cuisine", 8, &j)      // g.gain, g.messages (phrases de palier pour le journal)
Competences.niveau("cuisine", j)                   // 0 à 5
Competences.xp("anglais", j)                       // 0 à 100
Competences.aLeNiveau(["code": 3], j)              // Bool
```

Les fonctions de `Competences` n'écrivent jamais dans le journal : elles renvoient les phrases, l'appelant les ajoute.

## Progression automatique (`CompetencesSources`)

Chaque entrée : `id`, `type`, `gains` (XP de base par compétence), et selon le type `ids`, `motsCles`, `minAge`, `maxAge`, `chance` (0 à 1, défaut 1).

| type | quand | filtre |
|---|---|---|
| `ecole` | chaque année d'école (avant le bac) | `minAge`/`maxAge` |
| `filiere` | chaque année d'études | `ids` = filières (`informatique`, `droit`…) |
| `etudes` | chaque année d'études, toute filière | |
| `metier` | chaque année d'emploi | `ids` = `metierId` exacts, ou `motsCles` cherchés (sans accents) dans l'id et l'intitulé du poste |
| `retraite` | chaque année après 65 ans sans emploi | |
| `activite` | après une activité de l'onglet Activités | `ids` = ids d'activités |

Les métiers des autres modules sont reconnus par mots-clés (« cuisin », « develop », « mecan »…). Un module peut ajouter
ses propres entrées (nouveau fichier JSON dans `CompetencesSources`, ex. `src_rando_*` pour la randonnée).

## Cours (`CompetencesCours`)

`id`, `competence`, `titre`, `description`, `cout` (euros), `gain` ([min, max] XP de base), `textes` (au moins 2), et
optionnels `minAge`, `niveauMin` (masterclass), `niveauMax` (cours trop simple au-delà), `effects`.
Chaque cours une fois par an. Les parents paient pour les mineurs, mais refusent parfois au-delà de 1 000 €.

## Branchement dans le moteur (fil moteur)

1. `Joueur` : `var competences: CompetencesEtat?` (optionnel, anciennes sauvegardes compatibles).
   Au démarrage (`GameEngine.init` par ex.) : `Competences.acces = \Joueur.competences`.
2. `conditionsRemplies` : `if let c = e.conditions, !Competences.aLeNiveau(c.skills, j) { return false }`.
3. `appliquer(eff, &j)` : `Competences.appliquer(eff.skills, &j).forEach { ajouterLigne(&j, $0) }`.
4. `choisir(index)` : après le tirage de l'issue, `Competences.apresChoix(c, &j).forEach { ajouterLigne(&j, $0) }`.
5. `EventView` : n'afficher que `Competences.choixVisibles(choix, j)` et appeler `engine.choisir(item.index)` avec
   **l'index d'origine**. Sur un choix caché, afficher le badge : `Competences.badge(c)` (« Cuisine · Confirmé ») et
   l'icône `Competences.iconeBadge(c)`.
6. `vieillir` : juste avant `j.journal.append(Annee(...))`, `lignes += Competences.finAnnee(&j)`
   (gains école/études/métier/retraite + oubli).
7. `faireActivite` : avant d'enregistrer, `let extra = Competences.apresActivite(a.id, &j)` puis
   `texte += " " + extra.joined(separator: " ")` (affiche « (Sport +6 XP) » et les paliers).
8. Interface : une entrée « Compétences » (icône `star.circle.fill`) qui ouvre `CompetencesView()` en feuille,
   comme Activités. L'écran liste les compétences par catégorie ; chaque compétence a un détail avec
   « S'entraîner » (une fois par an) et ses cours.
9. Optionnel : `tags(j)` ∪ `Competences.tags(j)` (`skill_<id>` dès le niveau 3), pour les modules qui ne lisent que les tags ;
   le profil ou la nécrologie peuvent afficher `Competences.meilleure(j)`.
10. Mode Shkurtaaa (optionnel) : `Competences.toutAuMax(&j)` met tout au niveau Maître.

## Écrire des événements à choix cachés (style)

- Le choix caché doit donner envie de progresser : meilleure issue, ou option hilarante qu'on ne voit pas autrement.
- Le label montre le talent utilisé (« Répondre en japonais », « Réparer toi-même le moteur »).
- Mêmes règles de ton que `docs/EVENTS_STYLE.md` : humour décalé, original, effets modestes.

# Loisirs : activités, progression et suites

Module du fil « Ajouter randonnées et activités ». Code : `FTCHTLife/Activities/`.
Données : `FTCHTLife/Resources/Data/Loisirs/<categorie>.json` (un **tableau** d'activités par fichier).
Événements aléatoires liés aux loisirs : `FTCHTLife/Resources/Data/Events/loisirs_act_NN.json` (format normal des événements, ids `lsr_NNNN`).
Validation : `python3 tools/validate_loisirs.py`.

Les activités déjà codées en dur dans `Engine/Actions.swift` (bibliothèque, médecin, chirurgie, loterie, casino, se faire des amis)
ne sont pas dupliquées ici, sauf salle de sport, méditation, soirée et vacances qui ont ici une version plus riche :
le fil moteur peut retirer les versions en dur quand il branche le module. Le casino et la loterie appartiennent à un autre fil.

## Ce que fait le module

- **Activités à options** : une randonnée propose « balade en forêt », « sentier de montagne », « sommet à 4 000 m »… chaque option a son coût, son âge, son niveau et sa santé minimum, et ses issues tirées au hasard.
- **Progression** : chaque séance donne de l'expérience. Niveaux : Débutant (0 xp), Amateur (3), Confirmé (8), Expert (16), Légende (30). Les options difficiles demandent un niveau, et les issues `bad` deviennent plus rares quand le niveau monte.
- **Blessures** : une issue peut blesser pour plusieurs années (perte de santé chaque année, options de niveau 2+ des activités physiques bloquées).
- **Abonnements** : une activité peut avoir un abonnement annuel (salle de sport, club de golf…). Abonné, les séances sont gratuites ; l'abonnement est prélevé chaque année, avec un petit message moqueur si tu n'y es pas allé.
- **Trophées** : une issue peut donner un trophée (une fois par vie).
- **Suites** (« petits messages d'après ») : chaque séance envoie des signaux au système de répercussions (`docs/REPERCUSSIONS.md`), qui programme les messages des années suivantes (« ta vidéo de chute à ski passe à la télé »).
- **Messages annuels automatiques** : séries d'années de pratique (bonus de santé ou de bonheur), activité abandonnée depuis 3 ans, blessure qui guérit, abonnement payé pour rien.

## Format d'une activité

```json
{
  "id": "randonnee",
  "title": "Randonnée",
  "icon": "figure.hiking",
  "category": "nature",
  "description": "Marcher en montée de son plein gré.",
  "minAge": 6,
  "maxAge": null,
  "perYear": 2,
  "physical": true,
  "tags": [],
  "excludeTags": [],
  "subscription": null,
  "options": [
    {
      "id": "balade",
      "label": "Balade en forêt",
      "description": "Deux heures, un sentier plat, zéro risque. En théorie.",
      "cost": 0,
      "minAge": 0,
      "minLevel": 0,
      "minHealth": 0,
      "xp": 1,
      "outcomes": [
        { "chance": 3, "text": "Tu as marché deux heures et vu un écureuil. Il t'a jugé{e}.", "effects": { "health": 2, "happiness": 3 } },
        { "chance": 1, "bad": true, "text": "Tu t'es perdu{e} sur un sentier plat et balisé. Exploit.", "effects": { "happiness": -3 },
          "followUp": { "inYears": 1, "chance": 0.5, "text": "Les gardes forestiers racontent encore ta randonnée à leurs stagiaires.", "effects": { "happiness": -1 } } }
      ]
    }
  ]
}
```

Champs de l'activité :
- `id` : unique dans tout le jeu, en minuscules, `a-z0-9_`.
- `icon` : nom d'un symbole **SF Symbols** existant sur iOS 16 (ex. `figure.hiking`, `figure.run`, `bicycle`, `tennisball.fill`, `music.note`, `paintbrush.fill`, `gamecontroller.fill`, `camera.fill`, `fork.knife`, `film`, `tent.fill`, `fish.fill`, `airplane`, `leaf.fill`, `sparkles`, `star.fill`…). En cas de doute, prendre un symbole simple.
- `category` : `nature`, `sport`, `bien_etre`, `sorties`, `hobbies`, `aventure`.
- `minAge` / `maxAge` : âges permis (maxAge `null` = pas de limite).
- `perYear` : séances possibles par an (défaut 1, max conseillé 3).
- `physical` : activité physique (compte pour le tag `sportif`, bloquée en partie par les blessures).
- `tags` / `excludeTags` : comme pour les événements (voir `docs/ARCHITECTURE.md`), plus les tags des loisirs ci-dessous.
- `subscription` : `null` ou `{ "name": "Abonnement à la salle", "yearlyCost": 480 }`.
- `options` : au moins une option avec `minLevel` 0.

Champs d'une option : `id` (unique dans l'activité), `label`, `description`, `cost` (euros, payés par les parents avant 18 ans),
`minAge`, `minLevel` (0 à 4), `minHealth` (0 à 100), `xp` (défaut 1 ; 2 ou 3 pour les options dures), `outcomes`.

Champs d'une issue :
- `chance` : poids relatif (défaut 1).
- `text` : phrase au présent ou au passé composé, à la 2e personne, avec les variables des événements (`{prenom}`, `{ami}`, `{partenaire}`, `{mere}`, `{pere}`, `{ville}`, `{e}`…).
- `effects` : comme les événements (`happiness`, `health`, `smarts`, `looks`, `karma`, `money`, `relationships`, `newFriend`, `death`).
- `bad` : issue ratée, plus rare quand le niveau monte.
- `minLevel` / `maxLevel` : issue réservée à certains niveaux (ex. une figure d'expert, une erreur de débutant).
- `injury` : `{ "name": "entorse à la cheville", "years": 2, "healthPerYear": -2 }`.
- `trophy` : nom du trophée (« Sommet du Grand Pic »).
- `followUp` (écriture seulement) : `{ "inYears": 1, "chance": 0.5, "text": "…", "effects": { … } }`, suite propre à **cette** issue.
  Pas de `death` ni de `newFriend`. Le jeu ne lit pas ce champ : `python3 tools/convertir_suites_loisirs.py` le transforme en
  `key` sur l'issue + une suite `rep_loi_NNNN` dans `Resources/Data/Repercussions/loisirs_NN.json`. Lancer le script avant de committer.
- `key` : signal précis de l'issue, envoyé sous la forme `<id de l'activité>_<key>` (posé par le script de conversion).
- `signal` : ce qui s'est passé, pour le système de répercussions (`docs/REPERCUSSIONS.md`). Le signal envoyé est
  `<signal de l'activité>_<signal de l'issue>`. Valeurs courantes : `sommet` (exploit, réussite marquante), `perdu`, `blessure`,
  `animal`, `rencontre` (rencontre de quelqu'un), `honte` (humiliation publique), `victoire` (compétition gagnée), `casse` (objet cassé), `arnaque`.
  Une issue avec `injury` envoie automatiquement `_blessure` si elle n'a pas de `signal`.

Champ d'activité en plus : `signal` (défaut : l'`id`). Les voyages et treks lointains utilisent `voyage`, le camping `camping`.
Chaque séance envoie toujours le signal de l'activité, plus celui de l'issue s'il y en a un.

Équilibrage conseillé : effets habituels de ±1 à ±6, rarement ±10 à ±15. `death` seulement dans des options risquées, avec un poids très faible (≈1 % des issues de l'option).
L'argent gagné reste raisonnable sauf exploit rare.

## Tags ajoutés par les loisirs

`pratique_<id>` (a déjà pratiqué), `habitue_<id>` (niveau 2+), `sportif`, `blesse`, `abonne`, `aventurier`, `trophee`.
Ils sont calculés par `LoisirsRegles.tags(_:)` et utilisables dans les événements et dans `tags` d'une activité.

## Branchement dans le moteur (fil moteur)

1. `Models/Models.swift`, dans `Joueur` : `var loisirs: LoisirsEtat?`
2. `GameEngine.tags(_:)`, à la fin : `t.formUnion(LoisirsRegles.tags(j.loisirs))`
3. `GameEngine.vieillir()`, juste après le bloc « Relations » (ou n'importe où avant `j.journal.append`) :
   `lignes += passerAnneeLoisirs(&j, etat: \.loisirs)`
4. Écran : `LoisirsEcran(etat: \.loisirs)` est un écran complet (avec sa barre et « Fermer »), à mettre dans la feuille Activités,
   ou `LoisirsListe(etat: \.loisirs)` à pousser dans un `NavigationStack` existant (par ex. un `NavigationLink` « Loisirs » en haut d'`ActivitesView`).
5. Répercussions : `pratiquerLoisir` renvoie un `LoisirResultat` dont `signaux` (ex. `["randonnee", "randonnee_sommet"]`)
   est à transmettre à `Repercussions.signaler(_:age:etat:)`. Le plus simple : passer le paramètre `signaler:` de `LoisirsEcran` / `LoisirsListe`
   (une closure `(String, inout Joueur) -> Void`) qui appelle `Repercussions.signaler`.
6. Facultatif : retirer « Salle de sport », « Méditation », « Faire la fête » et « Vacances » de `GameEngine.activites`, qui existent ici en plus riche.

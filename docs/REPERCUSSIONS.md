# Répercussions : les suites des événements

Un choix fait à 14 ans peut ressortir à 30. Une nuit au casino laisse des traces. Un mariage a des
suites (bonnes ou terribles). Ce module gère ces conséquences différées :

- **Suites** : « quand X arrive, Y arrive 1 à 3 ans plus tard ». Petit message dans le journal
  (« L'année d'après, … ») ou vraie carte à choix, qui peut elle-même avoir des suites (chaînes).
- **Drapeaux** (souvenirs) : marques durables posées sur le joueur (`a_vole_un_velo`, `ruine_au_casino`)
  que n'importe quel événement peut exiger ou exclure.
- **Compteurs** : combien de fois un signal est arrivé (`casino_perte` × 5 → la suite « addiction »).

Code : `FTCHTLife/Repercussions/Repercussions.swift`. Données : `FTCHTLife/Resources/Data/Repercussions/*.json`.
Vérification : `python3 tools/validate_repercussions.py`.

## Signaux

Une suite se déclenche sur un **signal** (`"on"`) :

- `"event:<id>"` : un événement aléatoire est arrivé (ex. `"event:base_0011"`). Avec `"choice"` (index du
  choix, à partir de 0) et `"outcome"` (index de l'issue dans ce choix), on cible une réponse précise.
  Les suites elles-mêmes sont des événements : `"event:rep_amo_0003"` permet d'enchaîner.
- un **signal de module**, émis par le moteur ou un module quand une action a lieu. Liste commune :

| Domaine | Signaux |
|---|---|
| Amour | `rencontre`, `rendez_vous`, `rendez_vous_rate`, `couple`, `rupture`, `largue` (le joueur se fait quitter), `tromperie`, `tromperie_decouverte`, `demande_mariage`, `demande_refusee`, `fiancailles_rompues`, `mariage`, `divorce`, `veuvage`, `meilleur_ami` |
| Bébés | `grossesse`, `naissance_enfant`, `adoption`, `enfant_majeur`, `enfant_quitte_maison` |
| Casino, jeux | `casino_gain`, `casino_perte`, `casino_jackpot`, `casino_ruine`, `casino_triche`, `casino_triche_attrape`, `loterie_ticket`, `loterie_gain`, `pari_sportif_gain`, `pari_sportif_perte` |
| Loisirs (module Activities) | `<activite>` et `<activite>_<issue>`. Activités : `randonnee`, `camping`, `peche`, `escalade`, `ski`, `kayak`, `champignons`, `salle_sport`, `course`, `natation`, `velo`, `yoga`, `danse`, `meditation`, `spa`, `cinema`, `restaurant`, `concert`, `soiree`, `jardinage`, `cuisine`, `jeux_video`, `voyage` (treks, road trips, tour du monde). Issues : `_sommet`, `_perdu`, `_blessure`, `_animal`, `_rencontre`, `_honte`, `_victoire`, `_casse`, `_arnaque` (ex. `escalade_blessure`) |
| Permis, voiture | `permis_code_obtenu`, `permis_code_rate`, `permis_obtenu`, `permis_rate`, `permis_retire`, `amende_vitesse`, `accident_voiture`, `achat_voiture` |
| Crime, justice | `crime_reussi`, `crime_rate`, `arrestation`, `proces_gagne`, `proces_perdu`, `prison_entree`, `prison_sortie`, `evasion` |
| École, travail | `bac_obtenu`, `bac_rate`, `diplome`, `abandon_etudes`, `embauche`, `promotion`, `licenciement`, `demission`, `retraite` |
| Famille, santé, argent | `deces_parent`, `deces_proche`, `heritage`, `maladie`, `guerison`, `addiction`, `cure_desintox`, `chirurgie_esthetique`, `hopital`, `achat_maison`, `demenagement`, `gros_achat`, `faillite`, `voyage`, `celebrite` |

Un module peut ajouter ses propres signaux : il suffit de les émettre et de les ajouter à ce tableau.

## Format d'une suite

Chaque fichier de `Resources/Data/Repercussions/` est un tableau :

```json
{
  "id": "rep_cas_0001",
  "on": "casino_perte",
  "chance": 0.4,
  "delay": [1, 2],
  "requires": { "minCounters": { "casino_perte": 3 } },
  "remember": ["joueur_du_casino"],
  "conditions": { "tags": ["adult"], "excludeFlags": ["sevre_du_jeu"] },
  "patience": 2,
  "unique": true,
  "text": "L'année d'après, le casino t'envoie une carte d'anniversaire. Ta propre mère a oublié.",
  "effects": { "happiness": -3 },
  "choices": []
}
```

| Champ | Rôle | Défaut |
|---|---|---|
| `id` | unique dans tout le jeu, préfixe `rep_<thème>_NNNN` | obligatoire |
| `on` | signal déclencheur | obligatoire |
| `choice`, `outcome` | pour `event:` : index du choix / de l'issue (à partir de 0) | n'importe lequel |
| `chance` | probabilité (0 à 1) que la suite soit programmée | 1 |
| `delay` | `[min, max]` années après le signal ; `0` = à la fin de la même année | `[1, 1]` |
| `requires` | conditions **au moment du signal** : seulement `flags`, `excludeFlags`, `minCounters`, `maxCounters` | aucune |
| `remember` / `forget` | drapeaux posés / retirés **tout de suite** au signal (même si `chance` rate) | aucun |
| `conditions` | conditions **à l'échéance** : tous les champs des événements (`gender`, `tags`, `requiresPartner`…) + `flags`, `excludeFlags`, `minCounters`, `maxCounters` | aucune |
| `minAge`, `maxAge` | âge requis à l'échéance | aucun |
| `patience` | si les conditions ne sont pas remplies à l'échéance, on réessaie pendant N années, puis on oublie | 0 |
| `unique` | une seule fois par vie | false |
| `setFlags` / `clearFlags` | drapeaux posés / retirés **quand la suite arrive** | aucun |
| `text` | texte (mêmes variables que les événements : `{prenom}`, `{partenaire}`, `{e}`…). Absent = règle qui ne fait que gérer des drapeaux | aucun |
| `effects` | effets directs (format des événements) si pas de choix | aucun |
| `choices` | choix (format des événements) ; chaque issue peut avoir ses propres suites via `"on": "event:<id de cette suite>"` | aucun |

Une règle avec seulement `remember` (sans `text`) sert à **marquer** un joueur : par ex. `"on": "event:base_0007", "choice": 0, "remember": ["a_garde_les_20_euros"]`.

Les compteurs comptent chaque signal (`casino_perte`) et chaque signal+choix (`event:base_0011/0`).

## Drapeaux dans les événements classiques

Le moteur ajoute aux événements de `Data/Events` :

- dans `effects` : `"setFlags": ["a_vole_voiture"]`, `"clearFlags": [...]`, `"followUps": ["rep_xxx_0001"]`
  (programme directement une suite par son id, avec son `delay`) ;
- dans `conditions` : `"flags": [...]`, `"excludeFlags": [...]`.

Ainsi les auteurs d'événements peuvent faire `"setFlags": ["fume"]` sur « Accepter la cigarette » et écrire
plus tard un événement `"conditions": {"flags": ["fume"]}`.

Conventions de noms de drapeaux : minuscules, `_`, au passé ou à l'état (`a_trompe_partenaire`, `casier_judiciaire`,
`permis_en_poche`, `fume`, `phobie_des_ours`). Les drapeaux communs sont listés en bas de ce fichier.

## Style

- Court, une à trois phrases. Commencer souvent par un repère de temps : « L'année d'après », « Deux ans plus tard »,
  « Tu croyais avoir oublié… ». Le délai réel est aléatoire : rester vague (« Quelque temps après ») si `delay` couvre plusieurs années.
- Rappeler l'événement d'origine en une demi-phrase pour que le joueur fasse le lien.
- Humour décalé, absurde, un peu méchant, jamais copié d'un autre jeu.
- Pas de suite pour tout : 30 à 60 % de chance, sinon le journal devient prévisible.

## Branchement dans le moteur (fil moteur)

1. `Joueur` : `var repercussions: RepercussionsEtat?` (optionnel, ancien fichier de sauvegarde compatible).
2. `Effets` : `setFlags: [String]?`, `clearFlags: [String]?`, `followUps: [String]?`.
   `ConditionsEvenement` : `flags: [String]?`, `excludeFlags: [String]?` (à la fin de la struct).
3. `conditionsRemplies` : `if let c = e.conditions, !Repercussions.drapeauxOK(flags: c.flags, excludeFlags: c.excludeFlags, etat: j.repercussions) { return false }`.
4. `appliquer(eff, &j)` :
   ```swift
   var etat = j.repercussions ?? RepercussionsEtat()
   Repercussions.appliquerDrapeaux(poser: eff.setFlags, retirer: eff.clearFlags, age: j.age, etat: &etat)
   for id in eff.followUps ?? [] { Repercussions.programmer(id: id, age: j.age, etat: &etat) }
   j.repercussions = etat
   ```
5. Signaler les événements : dans `choisir`, après le tirage (`let k = c.outcomes.firstIndex(of: issue)`)
   `Repercussions.signaler("event:\(aff.evenement.id)", choix: index, issue: k, age: j.age, etat: &etat)` ;
   dans `declencher` pour un événement sans choix : `Repercussions.signaler("event:\(e.id)", age: j.age, etat: &etat)`.
6. Dans `vieillir`, juste avant `tirerEvenements()` :
   ```swift
   var etat = j.repercussions ?? RepercussionsEtat()
   let suites = Repercussions.echeances(age: j.age, etat: &etat) { conditionsRemplies($0, j, tags: tags(j)) }
   j.repercussions = etat; joueur = j
   suites.forEach { declencher($0) }
   ```
   Les suites passent avant les événements aléatoires, et comptent dans le nombre d'événements de l'année si besoin.
7. Émettre les signaux du moteur : `bac_obtenu`, `bac_rate`, `diplome`, `embauche`, `promotion`, `licenciement`,
   `retraite`, `deces_parent`, `deces_proche`, `heritage`. Les modules (amour, casino, permis…) émettent les leurs
   avec `Repercussions.signaler("mariage", age: j.age, etat: &etat)`.
8. Optionnel : ajouter les drapeaux aux tags (`tags(j)` ∪ `"flag:" + nom`) pour les modules qui ne lisent que les tags.

## Drapeaux communs

`fume`, `casier_judiciaire`, `ancien_detenu`, `permis_en_poche`, `permis_suspendu`, `joueur_du_casino`,
`accro_au_jeu`, `sevre_du_jeu`, `a_trompe_partenaire`, `s_est_fait_tromper`, `divorce`, `marie`, `parent`,
`randonneur`, `phobie_de_la_foret`, `a_gagne_loterie`, `celebre_localement`, `menteur_notoire`.

# Entourage : le monde qui pousse le joueur à agir

Demande de Leart (11/11) : un jeu plus vivant. Les proches, les collègues et la vie viennent chercher le joueur :
{partenaire} demande quand on se marie puis on organise le mariage étape par étape, on tombe malade, des offres
d'emploi arrivent sans qu'on les cherche, la famille et les amis demandent de l'aide, de l'argent, un avis.

Code : `FTCHTLife/Entourage/Entourage.swift`. Contenu : `Resources/Data/Events/entourage_*.json` (ids `ent_<theme>_NNNN`)
et `Resources/Data/Repercussions/entourage_*.json` (ids `rep_ent_<theme>_NNNN`). Format commun des événements :
`docs/EVENTS_FORMAT.md`, suites : `docs/REPERCUSSIONS.md`. Vérification :
`python3 tools/validate_events.py` et `python3 tools/validate_repercussions.py`.

## Effets en plus : `"entourage"`

Dans `effects` d'une issue (événement ou suite), un sous-objet qui change vraiment la situation :

| Clé | Effet |
|---|---|
| `"fiancailles": true` | le joueur se fiance avec {partenaire} (si en couple et pas déjà fiancé/marié). Émet `demande_mariage`, ce qui lance l'organisation du mariage. |
| `"mariage": true` | le joueur épouse {partenaire}. Émet `mariage` (toutes les suites de mariage existantes s'appliquent). |
| `"offreEmploi": "<id métier>"` | embauche directe dans ce métier (ids de `Data/Careers`). Si le profil ne convient pas (diplôme…), l'offre « tombe à l'eau » avec la raison. |
| `"offreEmploi": "secteur:<secteur>"` | un métier ouvert au profil dans ce secteur (`tech`, `sante`, `commerce`, `finance`…). |
| `"offreEmploi": "meme_secteur"` | un autre métier du secteur actuel, au même échelon par défaut (chasseur de têtes, concurrent). |
| `"offreEmploi": "auto"` | n'importe quel métier ouvert au profil (piston, coup de chance). |
| `"niveau": 2` | échelon de départ du poste proposé. |
| `"salaireBonus": 20` | salaire de l'échelon +20 %. |
| `"demission": true` | le joueur quitte son poste actuel (émet `demission`). |
| `"signaux": ["demenagement"]` | émet des signaux communs (voir docs/REPERCUSSIONS.md). |

Une offre n'aboutit pas en prison, pendant un mandat à plein temps, pour un chef de parti ou pendant les études.

Pour le reste on utilise ce qui existe : `"vie": {"disease": "grippe"}` (ids de `Data/Health/maladies.json`),
`"vie": {"cure": true}`, `"vie": {"pregnancy": true}`, `"vie": {"breakup": true}`, `"vie": {"addiction": "alcool"}`,
`"vie": {"newPartner": true}`, `relationships`, `setFlags`, `followUps`.

## Tags en plus (EntourageTags)

`couple_2ans`, `couple_5ans` (ancienneté du couple actuel), `enfant_bebe` (<3 ans), `enfant_petit` (3-11), `enfant_ado` (12-17),
`enfant_adulte` (18+), `parent_age` (un parent vivant de 70 ans ou plus), `parent_tres_age` (80+), `poste_nouveau`
(1re ou 2e année au poste), `poste_ancien` (5 ans ou plus), `carriere` (emploi du module Métiers).

Avec ceux du module vie : `dating`, `engaged`, `married`, `single`, `pregnant`, `ex`, `grandparents`, `grandchildren`,
`malade`, `bien_portant`, `addiction`, et du train de vie : `millionaire`, `endette`, `gros_salaire`, `petit_salaire`,
`chez_parents`, `locataire`, `proprietaire`, `voiture`, `vie_de_luxe`…

## Le mariage, étape par étape (`entourage_mariage.json`, `rep_ent_mar_*`)

1. **La question** (`ent_cpl_0001` à `0004`) : en couple depuis 2 ans, {partenaire} demande « Quand est-ce qu'on se marie ? ».
   Faire sa demande → fiançailles. « Bientôt, promis » → drapeau `mariage_promis`, {partenaire} relance un ou deux ans plus tard,
   moins patiemment. Refuser → le couple encaisse, parfois rompt.
2. **Le budget** (un an après les fiançailles, quelle qu'en soit l'origine : événement ou demande du joueur) : mairie et barbecue,
   mariage classique, mariage de rêve, ou crédit. Pose `mariage_budget_petit|moyen|grand` (et `endette` pour le crédit).
3. **Les invités** et **le lieu** (l'année suivante, deux cartes) : petit comité ou toute la famille, inviter l'ex ou pas,
   la belle-famille qui impose ses cousins ; mairie, château, plage à l'étranger, salle des fêtes.
4. **Le jour J** (l'année d'après) : une carte selon le budget et les choix, qui marie vraiment le joueur (`"mariage": true`).
   Imprévus (pluie, tonton, ex), puis les suites du signal `mariage` (photos, lune de miel, belle-famille, anniversaires).
5. **Après** : remboursement du crédit, lune de miel, cadeaux, disputes de belle-famille.

Si le joueur se marie lui-même entre-temps (menu Relations) ou rompt, la chaîne s'arrête : chaque étape exige le tag `engaged`.

## Règles d'écriture

- Ce sont les **autres** qui viennent chercher le joueur : une demande, une proposition, une nouvelle, un problème. Chaque carte
  pousse à décider, et les choix ont des conséquences réelles (stats, argent, liens, drapeaux, suites).
- Cohérence avec la situation : conditions précises (tags, `requiresJob`, `requiresPartner`, drapeaux). Pas d'offre d'emploi
  à un retraité de 80 ans, pas de « ta copine veut se marier » si tu es déjà marié.
- 3 événements à choix maximum par an (géré par le moteur) : peu de cartes, mais qui comptent.
- Ton : humour décalé du jeu, mais les sujets lourds (maladie grave, parent qui décline) restent justes et respectueux.
- Environ un événement sur trois laisse une trace (drapeau ou suite). Les histoires en plusieurs étapes passent par
  `followUps` vers des suites `rep_ent_*` qui ont elles-mêmes des choix.

## Branchement (fait dans ce module, à vérifier par le fil moteur)

- `Models/Evenement.swift`, `Effets` : `var entourage: EntourageEffets?`.
- `Engine/Branchements.swift` : `tagsModules` ajoute `EntourageTags.tags(j)` ; `modulesApresChoix` et
  `modulesApresEvenementSimple` appellent `entourageAppliquer(...)` et ajoutent ses lignes au journal.

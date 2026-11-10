# Paranormal rare : petites quêtes sur plusieurs années

Des choses étranges arrivent, très rarement. Certaines restent sans suite (un OVNI en forme de croissant),
d'autres deviennent de **petites quêtes** qui reviennent dans la vie du joueur pendant des années :
le fantôme Gérard qui cherche sa tasse, une voyante qui a mis ta mort dans une enveloppe, un enlèvement
extraterrestre qui finit par une offre d'aller simple, une carte au trésor…

## Fichiers

| Fichier | Contenu |
|---|---|
| `FTCHTLife/Resources/Data/Events/paranormal_01.json` | débuts de quêtes (`par_0001` à `par_0010`) et rencontres isolées (`par_0101` et suivants), catégorie `paranormal` |
| `FTCHTLife/Resources/Data/Repercussions/paranormal_01.json` | étapes suivantes des quêtes (`rep_par_0001`…), au format des répercussions |
| `tools/check_paranormal.py` | vérifie que chaque étape est bien accrochée, que les drapeaux exigés sont posés plus tôt, affiche l'arbre des quêtes |

Vérifications : `python3 tools/check_paranormal.py`, plus les validateurs communs
(`tools/validate_events.py`, `tools/validate_repercussions.py`).

## Comment ça marche

Aucun code nouveau : les quêtes utilisent le module **Répercussions** (`docs/REPERCUSSIONS.md`).

1. Le début de quête est un événement aléatoire normal, `unique`, avec un **poids de 0,6**
   (un événement courant pèse environ 5). Les rencontres isolées pèsent 1.
2. Les choix posent un **drapeau** (`setFlags`) : `maison_hantee`, `prediction_voyante`, `enleve_par_aliens`…
3. Chaque étape est une suite `"on": "event:<id de l'étape d'avant>"` (souvent avec `choice`/`outcome`),
   un `delay` de quelques années, de la `patience`, et exige le drapeau de la quête dans `conditions.flags`.
   Si le joueur a « refermé » la quête (drapeau retiré), les étapes suivantes n'arrivent pas.
4. La dernière étape retire le drapeau (`clearFlags`) et pose parfois un drapeau souvenir
   (`a_libere_un_fantome`, `a_trouve_un_tresor`, `boucle_temporelle_bouclee`) que d'autres fils peuvent réutiliser.

Tant que le module Répercussions n'est pas branché dans le moteur, seuls les débuts de quêtes et les rencontres
isolées apparaissent (les clés `setFlags` sont ignorées sans erreur).

## Les quêtes

| Début | Quête | Étapes | Âges | Fins possibles |
|---|---|---|---|---|
| `par_0001` | La maison hantée : Gérard, mort en 1974, cherche sa tasse | 4 à 5 | 20-75 | Gérard part en paix et laisse ses économies, devient ton majordome, procès au tribunal de l'au-delà, émission de télé |
| `par_0002` | La voyante qui prédit ta mort (enveloppe « Aujourd'hui. ») | 3 | 16-60 puis +6 à 14 ans | fausse alerte, journée de folie, très rare mort « prédite » ; ou tu deviens voyant associé |
| `par_0003` | Enlèvement extraterrestre, radio dans le micro-ondes, offre d'aller simple | 3 | 12-75 | retour avec un aimant de frigo, départ définitif (mort « officielle »), dettes effacées |
| `par_0004` | La carte au trésor « derrière le rond-point » | 3 | 10-70 | 250 000 €, une autre carte, une canalisation percée, la police municipale |
| `par_0005` | Ginette, la poupée du grenier qui revient toujours | 3 | 5-11 puis adulte | musée, déménagement, Ginette au salon |
| `par_0006` | La montre du vieil homme qui a ton nez (boucle temporelle) | 3 | 8-16 puis 18+ puis 70+ | tu deviens le vieil homme, ou tu la vends |
| `par_0007` | La Bête de la forêt, le forum de chasseurs, le parking | 3 | 16-70 | colocation avec la Bête, forêt protégée, reportage qui la fait fuir |
| `par_0008` | Bernard, l'esprit de la soirée pyjama | 3 | 12-17 puis 22+ | testament retrouvé dans les cornichons, commission, adieux |
| `par_0009` | Ton double venu d'une autre dimension | 3 | 20-60 | échange de vies, jumeau officiel |
| `par_0010` | Le chat noir immortel né en 1871 | 3 | 6-80 puis 60+ | il te garde en forme jusqu'au bout |

Rencontres isolées (`par_0101`…) : OVNI croissant, horoscope exact, ta propre tombe, miroir « BIENTÔT »,
cercle dans le maïs avec ton numéro, numéros rêvés, photocopieuse hantée, ami imaginaire qui déménage,
déjà-vu de toute une année, radio dans les dents, colis de toi posté il y a 50 ans, voisin qui a connu la peste.

## Rareté

Le poids 0,6 rend chaque début de quête très rare. Quand le nombre total d'événements augmente, les quêtes
deviennent encore plus rares : pour les rendre plus fréquentes, augmenter `weight` dans `paranormal_01.json`
(constante `ENTREE_POIDS` si le fichier est régénéré).

## Ajouter une quête

1. Un début dans `Events/paranormal_NN.json` : `id` `par_00NN`, `unique: true`, `weight` 0,6, un drapeau posé dans les choix qui lancent la quête.
2. Des étapes dans `Repercussions/paranormal_NN.json` : `id` `rep_par_NNNN`, `on: "event:<étape d'avant>"`,
   `delay` de plusieurs années, `patience`, `unique: true`, `conditions.flags` avec le drapeau de la quête.
3. La fin retire le drapeau. Pour qu'une branche rejoigne une autre étape, utiliser `"followUps": ["rep_par_NNNN"]` dans l'issue.
4. `python3 tools/check_paranormal.py`.

Ne jamais changer l'ordre des choix ou des issues d'un nœud publié : les étapes s'y réfèrent par index.

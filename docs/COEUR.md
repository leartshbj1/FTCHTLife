# Module « Cœur » : liaisons, tromperies, enfants cachés, crises de couple

Code : `FTCHTLife/Coeur/` (types préfixés `Coeur`). État : `Joueur.coeur` (`CoeurEtat?`, optionnel : les anciennes
sauvegardes restent lisibles). Données : `Resources/Data/Events/coeur_*.json` (ids `coe_NNNN`),
`Resources/Data/Repercussions/coeur_*.json` (ids `rep_coe_NNNN`), messages du téléphone `Phone/Messages/messages_coeur_*.json`.
Validation : `python3 tools/validate_events.py`, `tools/validate_repercussions.py`, `tools/validate_phone.py`.

## Ce que ça ajoute au jeu

- **Tentations** quand on est en couple, selon la situation (collègue, ex, soirée, voyage, salle de sport, fan sur les
  réseaux, rendez-vous Pécho…). On peut résister, avoir un **écart** d'un soir, ou commencer une **liaison**.
- **Liaison secrète** : l'amant·e a un attachement (0-100) et le/la partenaire des **soupçons** (0-100) qui montent chaque
  année et à chaque rendez-vous caché. À 100, tout est découvert. L'amant·e peut poser un **ultimatum**.
- **Découverte** : le/la partenaire part (divorce = moitié de l'argent perdue) ou reste, avec une **crise** de couple de
  3 ans (le lien baisse chaque année sans thérapie). Les enfants assez grands t'en veulent. Si tu es connu·e, scandale sur
  les réseaux (abonnés perdus, bad buzz).
- **Grossesse** dans la liaison ou après un écart : enfant caché (le joueur) ou paternité douteuse (la joueuse).
  Enfant caché : pension (3 600 €/an), le reconnaître, ou le cacher (procès possible, découverte possible).
- **Partenaire infidèle** : il/elle peut tromper le joueur en secret. Indices, fouille du téléphone, détective, puis
  pardonner ou partir.
- **Thérapie de couple** (2 400 €/an), **relation libre**.
- Écran **Amour** : sections « Liaison secrète », « Ton couple », « Enfants hors couple ».
- **Moments ensemble** (fiche d'un proche) : une action avec le/la partenaire, un enfant, un parent, la fratrie ou un ami
  ouvre tout de suite une carte de choix (voir « Cartes d'action »).

## Sous-objet `"coeur"` des effets

Utilisable dans les événements, les suites (répercussions) et les messages du téléphone :

| Clé | Valeur | Effet |
|---|---|---|
| `ecart` | `true` | aventure d'un soir : tromperie (signal `tromperie`, karma −6), peut se savoir plus tard, rare grossesse |
| `liaison` | `"debut"`, `"fin"`, `"officialiser"`, `"avouer"` | commence une liaison (si en couple et sans liaison) ; y met fin ; quitter son/sa partenaire pour l'amant·e ; tout avouer |
| `via` | `travail`, `ex`, `soiree`, `ami`, `voyage`, `sport`, `voisin`, `pecho`, `reseaux`, `fan`, `autre` | avec `"liaison": "debut"` : où on s'est rencontrés (`ex` réutilise un ex du joueur) |
| `intensite` | entier | attachement de l'amant·e (à 0 il/elle part) |
| `soupcon` | entier | soupçons du/de la partenaire (à 100 : découverte) |
| `decouverte` | `true` | le/la partenaire découvre tout (liaison ou écarts) |
| `grossesse` | `true` | grossesse dans la liaison ; **seulement** dans un événement avec le tag `liaison_hetero` |
| `enfantCache` | `"reconnaitre"`, `"pension"`, `"cacher"`, `"reveler"` | agit sur le dernier enfant caché ; `reveler` révèle aussi une paternité douteuse |
| `partenaireInfidele` | `true` / `false` | le/la partenaire commence / arrête de tromper le joueur (en secret) |
| `soupconJoueur` | entier | doutes du joueur envers son/sa partenaire (≥ 30 : tag `soupcon_partenaire`) |
| `trahisonDecouverte` | `true` | le joueur prend son/sa partenaire sur le fait (si `partenaire_infidele`, sinon fausse alerte) |
| `pardon` | `true` | fin de crise, on pardonne |
| `crise` | entier | années de crise de couple (0 = fin de la crise) |
| `therapie` | entier | années de thérapie de couple |
| `relationLibre` | `true` / `false` | relation libre acceptée / terminée |
| `scandale` | entier (%) | perte d'abonnés si le joueur est un peu connu (≥ 5 000) |
| `lienCible` | entier | lien avec la personne visée par une carte d'action ({cible}) ; cartes d'action seulement |

Exemple : `"effects": {"karma": -8, "coeur": {"liaison": "debut", "via": "travail"}}`.

## Tags (conditions des événements)

`liaison`, `liaison_longue` (≥ 2 ans), `liaison_ultimatum`, `liaison_soupcon` (soupçons ≥ 50), `liaison_hetero`
(amant·e de l'autre sexe, femme de 18 à 45 ans : grossesse possible), `ancien_amant`, `grossesse_liaison`,
`enfant_cache`, `enfant_cache_adulte` (≥ 18 ans, toujours secret), `paternite_douteuse`, `partenaire_infidele`
(vérité cachée : sert aux indices), `soupcon_partenaire`, `trahi` (le joueur a découvert et n'a pas tranché),
`crise_couple`, `therapie_couple`, `relation_libre`, `ecart_secret`, `infidele` (a déjà trompé),
`infidele_recidiviste` (≥ 3), `couple_recent` (ensemble depuis moins d'un an), `couple_fertile` (couple de sexes
différents, la femme a 18 à 47 ans, pas de grossesse en cours).

Tags des réseaux (docs/PHONE.md) : `voustubeur`, `tiktaceur`, `onlyfesses`, `onlyfesses_star`, `onlyfesses_ancien`,
`onlyfesses_connu`.

## Variables de texte

`{amant}` (prénom), `{amant_role}` (« ton amant » / « ta maîtresse »), `{amant_il}` (« il » / « elle »),
`{enfant_cache}` (prénom de l'enfant caché). Toujours avec la condition qui va avec (`liaison`, `enfant_cache`).

## Signaux émis (répercussions)

`tromperie`, `tromperie_decouverte`, `liaison_debut`, `liaison_fin`, `liaison_officialisee`, `grossesse_liaison`,
`enfant_cache_ne`, `enfant_cache_reconnu`, `enfant_cache_revele`, `tromperie_subie` (le joueur est trompé),
`relation_libre`, `therapie_couple`. `coeur_suite` : jamais émis, pour les suites programmées seulement par
`followUps` ou par le code (`rep_coe_0001` après une découverte où le/la partenaire reste, `rep_coe_0002` quand le
joueur découvre une trahison).

## Cartes d'action (`Resources/Data/CoeurCartes/*.json`, ids `cc_NNNN`)

Code : `Coeur/CoeurActions.swift` (`CoeurActionProche`, `CoeurActionsSysteme`), vues `CoeurActionsProcheSection` et
`CoeurCarteView`. Dans la fiche d'un proche, la section « Moments ensemble » liste des actions (une fois par an et par
personne). L'action donne un petit bonus de lien, puis ouvre souvent une carte de choix, résolue comme un événement
(`GameEngine.resoudreCarteCoeur`, hors de la limite de 3 événements par an car c'est le joueur qui la déclenche).

Une carte est un événement normal (conditions et âges = ceux du joueur) avec en plus :
`action` (`nuit`, `avenir`, `surprise` · `jouer`, `devoirs`, `parlerVie`, `punir`, `argentPoche`, `conduite`,
`conseilAdulte` · `visite` · `sortie`), `cibleMinAge` / `cibleMaxAge` (âge de la personne visée) et `cibleGenre`
(`male` / `female`).

Variables : `{cible}` (prénom), `{cible_il}` (il/elle), `{cible_lui}` (lui/elle), `{cible_le}` (le/la), `{cible_e}`
(accord féminin de la personne visée, seulement après une terminaison qui prend juste un « e »). Effet `"coeur":
{"lienCible": n}` pour le lien avec cette personne.

Règles : grossesse (`"vie": {"pregnancy": true}`) seulement avec le tag `couple_fertile` ; IST (`"vie": {"disease":
"ist"}`) plutôt avec `couple_recent` ; aucune rupture ni tromperie dans les cartes avec le/la partenaire (couple
protégé). Validation : `python3 tools/validate_coeur_cartes.py`.

## Couple protégé

`CoeurSysteme.coupleProtege: ((Joueur) -> Bool)?` est un crochet branché par le moteur (par exemple le module âme
sœur). Quand il renvoie vrai : pas d'écart ni de liaison possible (même via Pécho), et le/la partenaire ne devient
jamais infidèle.

## Règles d'écriture

- Au plus 3 événements à choix par an (le moteur s'en charge) : préférer des conditions précises (tags de situation)
  plutôt que des poids élevés.
- Cohérence : une tentation exige `partner` et exclut `liaison` et `relation_libre` ; une liaison au travail exige `job` ;
  un ex exige `ex` ; un fan exige `influencer`.
- Ton : sincère et lourd de conséquences, avec une pointe d'humour. Jamais explicite : on suggère.
- Conséquences fortes : karma, lien avec le/la partenaire et les enfants, argent, drapeaux d'état
  (`coeur_brise`, `anxieux`, `deprime`, `menteur_notoire`, `honte_publique`).

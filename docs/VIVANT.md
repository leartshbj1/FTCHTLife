# Jeu vivant (idées 40 à 47)

Le jeu réagit à ce que le joueur possède, fait ou a lancé. Avant ce module, la politique, les entreprises, les placements,
le casier, l'expatriation ou les achats ne laissaient qu'une ligne dans le journal. Maintenant :

| Idée | Ce qui arrive | Où |
|---|---|---|
| 40 Vie d'élu | moments humains pendant le mandat (marché, permanences, menaces, famille), ton sérieux à 80 % | `Data/Events/vivant_elu_*.json` (`viv_elu_`) |
| 41 Biens et proches | sorties avec un vrai proche grâce à la voiture, au bateau, à la maison… et les biens oubliés | `Data/Events/vivant_biens_*.json` (`viv_bien_`) |
| 42 Résultats en moments | le bac, le permis, le verdict, l'inauguration, le krach deviennent une carte à choix | `Data/Repercussions/vivant_resultats.json` (`rep_viv_0001-0499`) |
| 43 Le métier déborde | le métier actuel rattrape le joueur chez lui (voisins, famille, amis) | `Data/Events/vivant_metier_*.json` (`viv_met_`) |
| 44 Les proches réagissent | un proche réagit à tes achats, ta fortune, ta prison, ta faillite, ton élection… | `Data/Repercussions/vivant_proches.json` (`rep_viv_0500-0999`) |
| 45 Projets au long cours | le joueur lance un projet (roman, marathon, cabane…), un point d'étape par an, puis une fin | `Data/VivantProjets/*.json`, menu Activités → Projets perso |
| 46 Anniversaires de ta vie | 10 ans de mariage, 1 an d'un deuil, 20 ans du bac, 10 ans de ta boîte… | `Data/VivantAnniversaires/*.json` (`viv_anv_`) |
| 47 Notoriété locale | on te reconnaît selon ton statut (élu, star, riche, casier…) | `Data/Events/vivant_notoriete_*.json` (`viv_not_`) |

Code : `FTCHTLife/Vivant/`. Vérification : `python3 tools/validate_vivant.py` (lance aussi `validate_events.py` sur les fichiers `vivant_*`).

## Signaux

Chaque année, juste après l'écriture du journal, `JeuVivant.photo` prend une photo de la situation et la compare à celle
de l'an passé. Les différences deviennent des signaux envoyés à `SignauxModules.signaler` (donc aux Répercussions, aux
secrets et à la réputation de la famille). Une suite à `"delay": [0, 0]` arrive dans ce même passage d'année.

| Domaine | Signaux |
|---|---|
| Achats (Boutique) | `achat_voiture`, `achat_voiture_luxe` (≥ 80 000 €), `achat_moto`, `achat_bateau`, `achat_avion`, `achat_maison`, `achat_bijoux`, `gros_achat` (≥ 50 000 €) |
| Politique | `election_gagnee` (nouveau mandat), `reelection`, `mandat_perdu`, `entree_gouvernement`. La soirée électorale reste au module Politique. |
| Argent | `millionnaire`, `milliardaire` (une fois par vie), `ruine` (plus de 100 000 € puis endetté) |
| Placements | `placements_krach` (−30 % sur un an), `placements_envolee` (+50 %). Les achats et ventes du joueur ne comptent pas. |
| Étranger | `expatriation`, `retour_pays` |
| Justice | `condamnation`, `casier_efface` |
| Célébrité | `celebrite` (star de télé), `star_reseaux` |
| Entreprises | la file `EntreprisesEtat.signaux` est vidée chaque année : `entreprise_creee`, `entreprise_agrandie`, `entreprise_empire`, `entreprise_vendue`, `entreprise_fermee`, `entreprise_faillite` (+ `faillite`), `proche_licencie` |
| Projets | `projet_lance`, `projet_abandon`, `projet_reussite`, `projet_moyen`, `projet_echec`, `projet_<id>_<fin>` |

## Limite d'événements

Au plus **un** moment « vivant » à choix par an (`JeuVivant.maxMomentsParAn`) : suites `rep_viv_` et anniversaires.
Les suites en trop sont repoussées d'un an, un anniversaire sans place devient une ligne du journal (`ligne`).
L'étape du projet en cours passe en tête de file. Le tout reste dans la limite de 3 événements à choix par an du moteur.

## Tags ajoutés

`secteur_<secteur>` et `metier_<id>` (métier actuel), `mandat_debut` (élu depuis un an ou moins), `mandat_installe`
(3 ans ou plus), `bateau_oublie` / `avion_oublie` (possédé depuis 3 ans, aucune sortie depuis 3 ans ; une carte `viv_bien_`
sur ce bien compte comme sortie), `notable` (élu, star de télé ou des réseaux, influenceur, magnat, milliardaire),
`projet_en_cours`.

## Anniversaires

Certains signaux posent un jalon (`JeuVivantEtat.jalons`, avec l'âge et un nom) : `mariage`, `rencontre_couple` (signal
`couple`), `divorce`, `veuvage`, `deces_parent`, `bac_obtenu`, `diplome`, `premier_emploi` (premier `embauche`), `retraite`,
`prison_sortie` (aussi `evasion`), `entreprise_creee`, `achat_maison`, `naissance_enfant` (aussi `adoption`),
`election_gagnee` (premier mandat), `expatriation`, `permis_obtenu`.

Format d'une carte (`Data/VivantAnniversaires`) : `id` (`viv_anv_NNNN`), `jalon`, `annees` (écarts en années),
`conditions`, `ligne` (journal si pas de place), `text`, `choices` ou `effects`. Variables en plus : `{jalon_nom}`
(prénom de la personne épousée, du parent disparu, de l'enfant, nom de la boîte, du pays, du poste) et `{annees}`.
Un anniversaire de mariage ou de couple n'arrive que si le ou la partenaire est toujours la même personne.
Chaque année, parmi les anniversaires possibles, le plus grand écart gagne.

## Projets

Format (`Data/VivantProjets`) : `id`, `nom`, `emoji`, `description`, `minAge`, `maxAge`, `conditions`, `cout` (au lancement),
`coutAnnuel`, `competence` (XP chaque année), `etapes` (3 à 5 : `text` + `choices`), `fins` (`reussite`, `moyen`, `echec` :
`text`, `effects`, `setFlags`), `abandon` (texte). Une issue d'étape a en plus `progres` (−1 à 3) et `abandon` (true).
Un choix peut avoir `requiresTags` (affiché seulement si le joueur a ces tags) et `requiresSkill`.
Fin : progrès ≥ 1,5 × étapes → réussite ; ≥ 0,75 × étapes → moyen ; sinon échec. Un projet à la fois, en pause en prison.

## Branchement (déjà fait)

- `Joueur.jeuVivant: JeuVivantEtat?` (Models.swift).
- `SignauxModules.signaler` → `JeuVivant.surSignal` (jalons).
- `tagsModules` → `vivantTags(j)` ; `modulesApresJournal` → `vivantApresAnnee(&j)` ;
  `modulesAvantTirage` → `vivantAvantTirage()` à la fin ; `modulesApresChoix` → `vivantApresChoix`.
- Navigation : `ModuleJeu.projets` (Activités → Sorties et loisirs) → `ProjetsView`.

# Carrières spéciales

Module `FTCHTLife/Speciales/` (types préfixés `Spe`), données `FTCHTLife/Resources/Data/SpecialesEvents/`.
Validateur : `python3 tools/validate_speciales.py`.

Ces carrières ont leur propre gameplay, comme la politique : on ne les trouve pas dans les offres d'emploi.
Elles se gèrent depuis **Carrière → Carrières spéciales**, une liste avec une grande icône par carrière
(Politique, Ma boîte, Agence de détective et Ma secte y sont aussi, ils ouvrent leurs écrans habituels).

| Carrière | Id | Rangs (`niveau` 0 à 5) |
|---|---|---|
| Combattant MMA | `mma` | Amateur, Pro régional, Pro national, Ligue continentale, Ligue mondiale, Champion du monde |
| Sportif pro | `sport` | Centre de formation, Deuxième division, Première division, Grand club, International, Légende |
| Mannequin | `mannequin` | Catalogues, Agence locale, Défilés nationaux, Semaines de la mode, Égérie, Top model mondial |
| Réalisateur | `cinema` | Courts-métrages, Premier long, Confirmé, Auteur reconnu, Grand réalisateur, Légende du cinéma |
| Musicien | `musique` | Scènes ouvertes, Artiste local, Signé en label, Disque d'or, Star, Légende |

Hors carrière :
- **Salle de sport** (`salle`) : abonnement, musculation (force), cours de boxe (technique), cardio. Ouvert à tous dès 14 ans.
  Force, technique et cardio (0 à 100) sont gardés dans l'état du module et servent au MMA et au sport.
- **Musée** (`musee`) : ouvrir un musée (dès 2 M€), acheter des œuvres, expositions, prix du billet, visiteurs.
  `niveau` = taille du musée : 0 petit, 1 moyen, 2 grand, 3 national.
- **Investissements** (`invest`) : sponsoriser un combattant, produire un film, financer un album, racheter un club,
  monter une agence de mannequins. Résultat chaque année selon le risque.

Une carrière spéciale est un **temps plein** dès le rang 1 (le rang 0 se cumule avec un emploi) : le joueur quitte son emploi.
Le module ajoute **au plus une carte par an** (limite globale : 3 événements à choix par an).

## Format des cartes (`Data/SpecialesEvents/<carriere>_NN.json`)

Chaque fichier est un tableau :

```json
{
  "id": "mma_0001",
  "carriere": "mma",
  "minNiveau": 0,
  "maxNiveau": 5,
  "minAge": 18,
  "maxAge": 60,
  "sports": ["football", "rugby"],
  "genres": ["rap"],
  "unique": true,
  "poids": 1,
  "text": "La veille de la pesée, {coach} te dit qu'il manque encore 2 kilos.",
  "choices": [
    {
      "label": "Sauna et plus une goutte d'eau",
      "outcomes": [
        { "chance": 0.7, "text": "Tu fais le poids, livide.", "effects": { "health": -6 }, "spe": { "forme": -10 } },
        { "chance": 0.3, "text": "Malaise dans le vestiaire. Combat annulé.", "effects": { "health": -12 }, "spe": { "reputation": -5 } }
      ]
    },
    {
      "label": "Accepter de combattre en catégorie supérieure",
      "costPct": 10,
      "outcomes": [ { "text": "Ton adversaire a l'air d'un frigo.", "spe": { "forme": 5 } } ]
    }
  ]
}
```

- `carriere` : `mma`, `sport`, `mannequin`, `cinema`, `musique`, `musee`, `invest`, `salle`.
- Optionnels : `minNiveau`/`maxNiveau` (rang dans la carrière, taille du musée), `minAge`/`maxAge`,
  `sports` (cartes `sport` : `football`, `basket`, `tennis`, `rugby`, `athletisme`, `cyclisme`),
  `genres` (cartes `musique` : `rap`, `pop`, `rock`, `electro`, `variete`, `jazz` ; cartes `cinema` : `comedie`, `drame`,
  `action`, `horreur`, `sf`, `documentaire`, `auteur`), `groupe` (true/false, musique : en groupe ou en solo), `types` (cartes `invest` : `combattant`, `film`, `album`, `club`, `agence`),
  `unique` (une fois par vie), `poids` (défaut 1).
- Choix : 2 à 4. `label`, `outcomes`, et en option `cost` (euros), `costPct` (% du revenu de référence du rang),
  `requiresSkill` (comme les événements, garder au moins un choix sans).
- Issue : `chance`, `text`, `effects` (format standard des événements : happiness, health, smarts, looks, karma, money,
  relationships, setFlags, skills…), et `spe` :

| Clé `spe` | Effet |
|---|---|
| `reputation` | réputation dans le milieu (0-100) |
| `forme` | forme physique / inspiration (0-100) |
| `niveau` | +1 / -1 rang |
| `blessure` | années d'arrêt (MMA, sport, mannequin) |
| `gainPct` | gain d'argent en % du revenu de référence du rang (négatif = perte) |
| `fansPct` | fans en % (musique, sport) |
| `force`, `technique`, `cardio` | stats de salle |
| `prestige`, `visiteursPct`, `collectionPct` | musée |
| `investPct` | valeur d'un investissement au hasard, en % |
| `finCarriere` | true : la carrière s'arrête (retraite forcée, scandale) |
| `signal` | signal pour les répercussions |

Revenu de référence par rang (euros par an) :

| Rang | mma | sport | mannequin | cinema | musique |
|---|---|---|---|---|---|
| 0 | 3 000 | 12 000 | 8 000 | 5 000 | 2 000 |
| 1 | 25 000 | 60 000 | 30 000 | 40 000 | 15 000 |
| 2 | 80 000 | 250 000 | 90 000 | 120 000 | 60 000 |
| 3 | 250 000 | 1 200 000 | 300 000 | 400 000 | 250 000 |
| 4 | 900 000 | 5 000 000 | 1 200 000 | 1 500 000 | 1 500 000 |
| 5 | 3 000 000 | 15 000 000 | 6 000 000 | 5 000 000 | 8 000 000 |

Pour `musee`, `invest` et `salle`, `gainPct`/`costPct` se rapportent à 100 000 € (musée : budget annuel), utilisez plutôt `cost` et `money`.

Variables : celles des événements (`{prenom}`, `{e}`, `{partenaire}`, `{mere}`…) et :
`{rang}` (nom du rang), `{coach}`, `{adversaire}`, `{ligue}`, `{salle}` (MMA, salle de sport) ;
`{club}`, `{sport}` (sport) ; `{agence}`, `{marque}` (mannequin) ; `{film}` (dernier film, cinéma) ;
`{groupe}` (nom de scène ou du groupe), `{label}` (musique) ; `{musee}`, `{oeuvre}` (musée) ; `{projet}` (investissement).

Ids : préfixe = carrière (`mma_`, `spo_`, `man_`, `cin_`, `mus_`, `mee_`, `inv_`, `sal_`) + 4 chiffres. Ne jamais renuméroter.

## Bilan de l'année et cartes de réaction

Au passage d'année, `SpeMoteur.passerAnnee` construit `SpeEtat.bilan` (`SpeBilanAnnee`) : une section par carrière
spéciale (rang, réputation, argent gagné, grand chiffre : combats, note de saison, entrées du film, écoutes, abonnés),
musée (visiteurs, résultat, prestige), investissements (variation de chaque part) et emploi normal (salaire,
performance, promotion). `SpeBilanAuto` (`.speBilanAuto()` sur `MainView`) l'affiche en pop-up avant les événements.
Le mode rapide s'arrête sur un bilan `important` (carrière spéciale, musée, investissements) ; pour un emploi normal,
le pop-up ne s'affiche que s'il y a du neuf (promotion, augmentation, nouveau poste, performance basse).

Le bilan pose aussi des **marqueurs** (`SpeEtat.marqueurs`), valables l'année qui suit. Une carte avec `"marqueurs": [...]`
n'arrive que si l'un d'eux est posé, et passe avant les autres cartes (cartes de réaction au bilan) :

| Carrière | Marqueurs |
|---|---|
| toutes (mma, sport, mannequin, cinema, musique) | `promotion`, `retrogradation`, `reputation_baisse`, `blessure` |
| mma | `victoire`, `defaite`, `defaite_ko`, `titre_gagne`, `inactif` |
| sport | `saison_top`, `saison_ratee`, `titre`, `selection`, `transfert` |
| mannequin | `campagne`, `baisse` |
| cinema | `court_sorti`, `court_prix`, `film_succes`, `film_flop`, `film_moyen`, `film_prix`, `critique_bonne`, `critique_mauvaise`, `sans_film` |
| musique | `album_certifie`, `album_succes`, `album_flop`, `fans_baisse`, `offre_label`, `clip_viral` |
| musee | `record`, `deficit` |
| invest | `invest_succes`, `invest_echec` |

Cartes de réaction : fichiers `<prefixe>_reac.json`, ids `<prefixe>_0101` et suivants.

## Ton

Sérieux avec une touche d'humour (environ 80 / 20). Blessures, dopage, pression sur le poids, contrats abusifs,
harcèlement, burn-out, argent qui monte à la tête : traités sérieusement, sans moraliser. Pas de vraies marques ni de
vraies personnes : ligues, festivals, marques et labels sont inventés.

## Branchement (fait)

- `Joueur.speciales: SpeEtat?`.
- `GameEngine.specialesAnnee` dans `modulesAnnee`, `specialesAvantTirage` dans `modulesAvantTirage`,
  `specialesApresChoix` dans `modulesApresChoix`, `SpeMoteur.tags` dans `tagsModules`.
- `empechementActivite` (Coherence) : une carrière spéciale à temps plein fait quitter l'emploi.
- `Joueur.occupation` affiche le titre de la carrière spéciale.
- Navigation : `ModuleJeu.carrieresSpeciales` (menu Carrière, groupe « Carrières spéciales »).

Tags : `spe_mma`, `spe_sport`, `spe_mannequin`, `spe_cinema`, `spe_musique`, `spe_star` (rang 4 ou plus),
`spe_ancien_<carriere>`, `proprio_musee`, `investisseur`, `salle_sport`, `costaud` (force ≥ 60).

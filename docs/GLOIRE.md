# Gloire et procès

Demandé par Leart (2026-11-11) : « gérer sa fame en écrivant un livre, faire des pubs, faire la fête, séance photo,
participer à la télé » et « pouvoir faire des procès contre quelqu'un ». Écrans en liste à grosses icônes (style des maquettes).

Code : `FTCHTLife/Gloire/` (GloireModeles, GloireMoteur, ProcesMoteur, GloireVues, GameEngine+Gloire).
Données : `FTCHTLife/Resources/Data/Gloire/catalogue.json` et `proces.json`. Suites : `Data/Repercussions/gloire_01.json` (`rep_glo_`).
Vérification : `python3 tools/validate_gloire.py`.

## La jauge « Gloire »

Une seule jauge pour tout le jeu, 0 à 100 % : la célébrité du module Télé (`TeleEtat.celebrite`, fond de 35 % par an).

- Le champ `"fame"` des événements, des suites et des carrières (`CareerEffects.fame`, métiers à `fameGain`) la nourrit
  désormais (avant, il était ignoré). Branché dans `modulesAppliquer` et `appliquerEffetsCarriere`.
- Barre dorée « Gloire » sous les stats de l'écran principal dès 10 % (`GloireMoteur.gloireAffichee`).
- Statut : Parfait inconnu → Vaguement connu → Célébrité locale → Visage connu → Star nationale → Superstar → Icône mondiale.
- À 60 % : le rêve « célèbre » est marqué.

## Activités → Célébrité

| Action | Règle |
|---|---|
| 📖 Écrire un livre | 1 par an. 11 genres (roman, polar, autobiographie dès 25 % de gloire, cuisine, développement perso, enfants, poésie, BD, romance, essai politique, SF). Qualité = intelligence + compétence du genre + hasard ; ventes = qualité × gloire. Prête-plume (25 000 €) : +qualité, −karma. Sans éditeur : auto-édition. Droits d'auteur chaque année (ventes qui baissent), adaptation au cinéma possible au-delà de 150 000 exemplaires. |
| 📺 Faire une pub | 2 par an, 4 offres par an proches de ta gloire (de la boucherie du quartier à l'égérie mondiale). Cachet × gloire. Produits douteux (thé détox, paris en ligne, crypto, pilules) : mieux payés, karma −4, risque de scandale. |
| 🥂 Faire la fête | Boîte branchée, anniversaire d'influenceur, gala, after chez une star, remise de prix, festival, yacht. Réussite selon une stat. Propositions sérieuses possibles (drogue, conduite en état d'ivresse) : accepter / refuser. |
| 📸 Séance photo | Book, journal local, catalogue, calendrier caritatif, maillot, couverture people, campagne de luxe. Payées selon la gloire. |
| 🎙️ Participer à la télé | Télé locale, émission de cuisine, talk-show, débat clash, matinale, JT, documentaire sur ta vie. Lien vers les jeux télé (module Télé). |
| 🤵 Attaché de presse | 15 000 € + 1 200 € par point de gloire, chaque année : +5 % de gloire par an. Part si tu ne peux plus payer. |

Chaque activité se fait une fois par an. Le ton reste léger, sauf drogue et alcool au volant (sérieux, comme le reste du crime).

## Activités → Procès

Dès 18 ans, un procès par an.

1. **Cible** : un proche (relations vivantes) ou une cible fixe : employeur actuel / ancien, entreprises (fast-food, hyper, constructeur,
   compagnie aérienne, banque, géant de la tech), clinique, médecin, tabloïd (si gloire ≥ 20), voisin, chien du quartier, mairie, État,
   police (si casier).
2. **Motif** (33) : dette, diffamation, licenciement abusif, harcèlement, erreur médicale, photos volées… et des motifs frivoles (🤡)
   qui gagnent rarement et valent une amende pour procédure abusive.
3. **Avocat** : commis d'office (gratuit, −8), te défendre toi-même (diplôme de droit ou éloquence 3), avocat de quartier, avocat au
   résultat (40 % des gains), grand cabinet, ténor du barreau (150 000 €, +26).
4. **Audience** : parfois une offre d'accord à l'amiable (accepter = argent sûr).
5. **Plaidoirie** : faits (intelligence), émotion (apparence), sincérité (karma), médiatiser (gloire).
6. **Verdict** : dommages et intérêts, ou frais de justice. Attaquer un proche abîme le lien (−25 au dépôt, −15 à −30 au verdict).

Chances = solidité du motif + bonus avocat − défense adverse + intelligence et karma + stratégie.
Historique dans `GloireEtat.proces`.

## Signaux (répercussions)

`livre_publie`, `best_seller`, `pub_tournee`, `pub_ratee`, `pub_arnaque`, `gloire_scandale`, `gloire_fete`, `gloire_shooting`,
`gloire_plateau`, `drogue_essai`, `poursuite_gagnee`, `poursuite_perdue`, `poursuite_accord`, `poursuite_proche`
(+ `hopital`, `accident_voiture`). `proces_gagne` / `proces_perdu` restent pour la justice pénale.

## Tags

`gloire_celebre` (≥ 40 %), `gloire_superstar` (≥ 75 %), `auteur_publie`, `best_seller`, `attache_presse`, `a_gagne_proces`, `a_perdu_proces`.

## Formats

`catalogue.json` : `livres` (id, nom, emoji, description, ageMin, gloireMin, ventes, poidsGloire, competence?, titres, critiques*),
`pubs` (id, marque, produit, emoji, gloireMin, ageMin, ageMax?, cachet [min,max] à 50 % de gloire, gloire, louche?, risque?, textes,
textesRates?, effetsRates?), `fetes` / `shootings` / `plateaux` (id, nom, emoji, description, ageMin, gloireMin, prix, cachet?, stat,
succes, rates, dilemmes?). Issue = `{chance?, texte, effets?}` ; effets : bonheur, sante, intelligence, apparence, karma, argent,
gloire, nouvelAmi, signal, scandale, deces. Variables : {prenom} {nom} {ville} {e}, + {cachet} {marque} {produit} {titre}.

`proces.json` : `cibles`, `motifs`, `avocats`, `strategies`, `audiences`, `accords`. Variables : {cible} {motif} {montant} {avocat}.

## Branchement (fait)

`Joueur.gloire`, `GloireMoteur.tags` dans `tagsModules`, `GloireMoteur.passerAnnee` dans `modulesAnnee`, `fame` dans
`modulesAppliquer` et `appliquerEffetsCarriere`, `ModuleJeu.celebrite` / `.proces` (groupe « Gloire et justice »), barre dans
`PanneauStats`, phrases de souvenirs dans `Souvenir.phrasesSignaux`.

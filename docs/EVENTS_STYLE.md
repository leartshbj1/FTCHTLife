# Consignes d'écriture des événements (FTCHTLife)

- Français, tutoiement (« tu »), ton humour décalé, absurde, un peu piquant mais jamais haineux ; pas de contenu sexuel explicite, rien sur des mineurs de déplacé.
- 100 % original : ne reprends aucun texte, nom ou situation signature d'un autre jeu (BitLife, etc.).
- Chaque événement : une situation concrète et drôle en 1-2 phrases, 2 à 4 choix courts (labels de 1-5 mots), et pour chaque choix 1 à 3 issues avec `chance` (somme = 1). Les issues ont leur propre chute drôle et des effets cohérents.
- Variété : pas deux événements sur le même gag. Mélange situations banales, dilemmes moraux, coups de chance, catastrophes, absurdités.
- Effets modestes (souvent ±1 à ±10), gros effets réservés aux événements rares (`weight` 1-3). `money` en euros réalistes pour l'âge.
- Utilise les placeholders ({prenom}, {parent}, {ami}, …) pour personnaliser.

## Conséquences (demande de Leart, 11/11)
- Chaque issue doit toucher au moins une stat centrale (`happiness`, `health`, `smarts`, `looks`, `money`), sauf issue volontairement neutre (rare).
- Ordres de grandeur : petit tracas ±3 à ±6 ; vrai coup dur ou belle réussite ±8 à ±15 ; événement rare (weight 1-3) jusqu'à ±25. Le `stress` seul ne suffit pas : traduis-le aussi en bonheur ou santé.
- Les choix risqués doivent vraiment pouvoir mal tourner (santé, argent, réputation), les choix prudents rapporter peu.
- Environ 1 événement sur 4 laisse une trace : `setFlags` (souvenir réutilisé ailleurs) et/ou `followUps` vers une suite que tu écris dans `FTCHTLife/Resources/Data/Repercussions/evenements_NN.json` (ids `rep_evt_…`, format dans `docs/REPERCUSSIONS.md`, vérifier avec `python3 tools/validate_repercussions.py`). Exemple : fumer une cigarette au lycée → drapeau `fume` → quelques années plus tard, toux et santé −10.

# Module Casino

Casino, jeux d'argent, addiction et dettes. Tout le code est dans `FTCHTLife/Casino/`,
les événements dans `FTCHTLife/Resources/Data/Events/casino.json`.

## Branchements à faire par le moteur

1. **Ouvrir le casino** : remplacer l'activité `casino` (et `loterie`) de `Engine/Actions.swift` par une
   entrée qui ouvre `CasinoView()` en sheet, avec `.environmentObject(engine)`. 18 ans minimum
   (la vue refuse elle-même les mineurs avec un texte drôle).
2. **Passage de l'année** : dans `vieillir()`, juste après `j.actionsAnnee = []` :
   ```swift
   let casino = CasinoSysteme.finAnnee(&j)
   lignes += casino.lignes
   ```
   puis, avant les événements aléatoires, si `casino.deces != nil`, faire mourir le joueur avec
   cette cause (la phrase suit « Tu es mort/morte … »).
3. **Étiquettes d'événements** : dans `tags(_:)`, ajouter `t.formUnion(CasinoSysteme.tags(j))`.
   Étiquettes : `gambled` (a déjà joué), `gambler` (addiction ≥ 25), `gambling_addict` (≥ 60),
   `gambler_recovering` (ancien accro guéri), `casino_debt` (dette chez l'usurier), `casino_vip`
   (carte Or ou mieux), `casino_banned`, `casino_winner` (gain ≥ 100 000 €), `casino_ruined`
   (perte nette ≥ 100 000 € sur la vie).
4. **Répercussions** : `CasinoSignaux.recepteur = { signal, j in ... Repercussions.signaler(...) }`
   au démarrage. Signaux : `casino_gain`, `casino_perte`, `casino_jackpot`, `casino_ruine`,
   `casino_triche`, `casino_triche_attrape`, `casino_usurier`, `casino_usurier_violence`,
   `loterie_ticket`, `loterie_gain`, `pari_sportif_gain`, `pari_sportif_perte`.
5. **Sauvegarde** : l'état casino (`CasinoEtat`, Codable) est pour l'instant rangé dans un fichier à
   part (`ftchtlife-casino.json`) par `CasinoStockage`. Pour le mettre dans la sauvegarde du joueur :
   ajouter `var casino: CasinoEtat? = nil` à `Joueur` et réécrire seulement
   `CasinoStockage.etat(pour:)` / `enregistrer(_:pour:)`.
6. **Mode Shkurtaaa** : l'argent passe par `engine.modifier`, donc un `Shkurtaaa.argent(_:)` appliqué
   dans `modifier` couvre aussi le casino.

## API pour les jeux

Chaque jeu est une vue `struct XxxVue: View { let lieu: CasinoLieu }` avec
`@EnvironmentObject var engine: GameEngine`. `CasinoRouteurJeu` l'affiche avec la barre de solde
et le fond tapis : la vue du jeu ne met ni `NavigationStack`, ni titre, ni fond.

- `engine.casinoMiser(mise, jeu:) -> Bool` : retire la mise (false si pas assez d'argent).
  À appeler pour chaque mise, relances comprises.
- `engine.casinoRegler(mise:paiement:jeu:detail:)` : rend `paiement` (mise comprise, 0 si perdu),
  `mise` = total misé dans la partie. Gère stats, bonheur, addiction, journal, signaux.
- `engine.casinoSoupcon(points, raison:) -> String?` : triche détectée ; à 100 points, bannissement
  de 5 ans (renvoie le message).
- `engine.casinoJackpot(loto:ajouter:reinitialiser:) -> Int` : gros lots progressifs.
- `engine.casinoEtat` : état (addiction, VIP, stats). Pour que la vue se rafraîchisse :
  `@ObservedObject private var stockage = CasinoStockage.shared`.
- UI commune (`CasinoUI.swift`) : `CasinoSelecteurMise`, `CasinoBouton`, `CasinoBandeau`,
  `CasinoJeton`, `CasinoCarte` + `CasinoCarteVue`, `CasinoStyle`.

Lieux (`CasinoLieu`) : bar-tabac (petites mises), casino, Palais Doré (carte Or ou 1 M€), tripot
clandestin (ignore les interdictions, risque de descente de police).

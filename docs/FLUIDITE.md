# Fluidité, fenêtres et mode rapide

## Règle pour tous les écrans : pas de fenêtre posée dans une liste

Une `.alert`, `.sheet` ou `.confirmationDialog` posée sur une **section ou une ligne de `List`**
(souvent via `Group { Section … }.alert(…)`) se referme dès que la liste se redessine. Comme chaque
action modifie le joueur, la liste se redessine tout de suite : la fenêtre « apparaît puis disparaît direct ».

À faire à la place :

- l'écran qui contient la liste pose le présentoir, **hors de la liste** :
  `List { … }.presentoirRacine()`
- la section lit `@Environment(\.presentoir) private var presentoir` puis appelle
  `presentoir?.montrer(texte)` (message) ou `presentoir?.ouvrir(MaCarte())` (feuille de choix).

Code : `FTCHTLife/Views/Presentoir.swift`. Déjà branché : `RelationDetailView`, `ListeRelationsView`
(sections Cœur, actions avec un proche, « Plus d'actions », famille élargie, adoption).

Même piège avec les `NavigationLink` : un lien qui disparaît de la liste au moment de l'action
referme l'écran poussé (ex. « Faire des rencontres » qui disparaissait dès qu'on trouvait quelqu'un).

## Événements

L'événement en cours n'est plus une feuille : c'est une carte posée sur `MainView` (`carteEvenement`).
Elle arrive et repart en ~0,1 s, et passer d'un événement au suivant ne fait plus descendre puis remonter
une feuille. Les autres fenêtres de `MainView` (une du monde, bilan, animaux, école) attendent toujours
que `engine.evenementEnCours` soit nil.

## Mode rapide (idée 48)

Réglages > Vitesse du jeu (`FTCHTLife/Rapide/ModeRapide.swift`), actifs par défaut :

- **Mode rapide** : animations très courtes (`ModeRapide.animation(_:)`) et bouton **Avancer** sur le
  journal, qui vit les années jusqu'au prochain moment important (`GameEngine.avancerJusquauProchainMoment`,
  10 ans au plus : événement à choix, une du monde, bilan d'entreprise, animal, tâche d'école, grand âge, mort).
- **Choix en un tap** : le résultat s'affiche en bandeau en haut (avec les +/−) et l'événement suivant
  arrive tout de suite, sans « Continuer ». Si `choisir` ne remplit pas `resultat`, la carte reste.

## Quantités (idée 49)

`FTCHTLife/Rapide/Quantites.swift` : `SelecteurQuantite` (×1 ×10 ×100 Max + « Comme la dernière fois »)
et `MemoireQuantites` (dernière quantité par clé, en UserDefaults).

- Boutique : acheter cash plusieurs exemplaires d'un objet neuf (100 au plus), « Racheter » le dernier article.
- Placements : « Comme la dernière fois » et ×10 / ×100 dans la saisie du montant.
- Casino : jetons ×2 ×10 ×100, et la mise de la dernière fois reprise à l'ouverture d'un jeu.

## Sauvegarde

`GameEngine.sauvegarder()` regroupe les demandes d'un même instant et encode/écrit en arrière-plan
(file série). `Format.argent` garde un seul `NumberFormatter`.

# Carte de vie à partager (idée 26)

À la mort, le joueur peut partager une image résumé de sa vie (format story, 1080 × 1920)
via la feuille de partage iOS : Messages, WhatsApp, Instagram, « Enregistrer l'image »…

Contenu de la carte : portrait, nom, surnom (celui de la nécrologie), ville et âge, cause de la mort,
six chiffres clés (fortune, métier, diplôme, amis, enfants ou amours, karma), meilleur et pire moment
de la vie, et une « note de vie » sur 20 avec un verdict.

## Fichiers (`FTCHTLife/CarteVie/`)

| Fichier | Rôle |
|---|---|
| `CarteVieResume.swift` | calcule tout ce qui est affiché à partir d'un `Joueur` (aucun état sauvegardé) |
| `CarteViePortrait.swift` | portrait dessiné par défaut (stable pour un même nom, lunettes si riche, auréole ou cornes selon le karma) |
| `CarteVieVue.swift` | la carte (360 × 640 points) |
| `CarteViePartage.swift` | rendu en image (`ImageRenderer`, échelle 3), aperçu, feuille de partage, bouton `CarteVieBouton` |

## Branchement (fil moteur)

Sur l'écran de mort, sous la nécrologie du musée :

```swift
CarteVieBouton(joueur: j,
               surnom: MuseeStore.shared.enregistrer(joueur: j).surnom,
               dernierMetier: nil,      // le moteur vide `emploi` à la mort ; sinon la carte le cherche dans le journal
               portrait: nil)           // ou AnyView(AvatarPersoView(appearance: …, age: j.age)) quand la création de perso sera branchée
```

Sans surnom, la carte en invente un petit (« le Roi du pognon », « la Ronchonne »…).

`project.yml` reçoit la clé `NSPhotoLibraryAddUsageDescription` : sans elle, iOS ferme l'app quand on touche
« Enregistrer l'image » dans la feuille de partage.

## Meilleur et pire moment

Par défaut ils sont trouvés dans le journal : chaque ligne reçoit un score selon des mots et emojis
(🎓 📈 🎉 promotion, mariage, jackpot… contre 💀 📉 viré, prison, divorce, ruiné…). La ligne de la mort
est ignorée. À score égal, la plus récente gagne. Les listes sont dans `CarteVieResume.motsPositifs` et
`motsNegatifs` : les modules peuvent y ajouter leurs mots ou emojis.

Si un jour le moteur suit les vrais écarts de stats, il peut passer `meilleur:` et `pire:`
(`CarteVieMoment(age:texte:score:)`) au `CarteVieResume`.

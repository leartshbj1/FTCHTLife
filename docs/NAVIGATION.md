# Navigation de l'interface

L'écran principal (`Views/MainView.swift`) suit le schéma classique du genre, avec un look propre à FTCHTLife :

- **En-tête** : avatar, nom, âge, occupation, argent. L'avatar et le bouton **Moi** ouvrent le menu Moi.
- **Bandeau prison** quand le joueur est en prison (ouvre l'écran Prison).
- **Journal** : une carte par année, l'année en cours mise en avant. Une carte « Comment jouer » au début de la vie.
- **Barres de stats** (bonheur, santé, intelligence, apparence) : un toucher ouvre le profil.
- **Barre du bas** : Carrière, Biens, **Âge +1** (au centre), Relations, Activités.

Chaque bouton ouvre `MenuCategorieView` : des tuiles rangées par groupe. Une tuile grise a un cadenas ;
la toucher explique pourquoi elle est fermée (âge, prison, diplôme…). Une pastille rouge compte ce qui attend
(messages du téléphone, événements de la boutique, choses à faire au collège).

## Fichiers

| Fichier | Rôle |
|---|---|
| `Navigation/Modules.swift` | `CategorieMenu` (5 menus) et `ModuleJeu` (une entrée par écran : titre, description, icône, groupe, `visible`, `verrou`) |
| `Navigation/EcranModule.swift` | l'écran ouvert par chaque entrée, et les petits habillages (`PrisonEcran`, `OffresEmploiView`, `MonTravailView`, `ReputationFamilleEcran`) |
| `Navigation/MenuCategorieView.swift` | le menu en tuiles, les pastilles, les activités rapides du moteur (`GameEngine.activites`, sauf casino) |
| `Views/MainView.swift` | écran principal, `BoutonAge`, `AvatarJoueur`, `JournalVieView`, `PanneauStats` |
| `Views/EtudesViews.swift` | `EcoleView`, `UniversiteView` |
| `Views/RelationsView.swift` | `ListeRelationsView(filtre:)`, `RelationDetailView(relationId:)` (avec actions amour/crime/santé et secrets) |
| `Views/ProfilView.swift` | `ProfilView` (stats, rêves, réputation), `ReglagesView` (mode Shkurtaaa, aide, nouvelle vie) |
| `Views/DeathView.swift` | fin de vie : bilan, rêves, réputation, nécrologie, carte de vie, testament, trophées, musée, lignée |
| `Views/NewLifeView.swift` | accueil : création de perso, naissance rapide, trophées, bonus de départ, musée |
| `Views/Theme.swift` | couleurs, `BarreStat`, `LigneAction`, `Feuille` (habille une liste en feuille avec « Fermer »), `.alerteResultat` |

## Où est chaque module

| Menu | Entrées |
|---|---|
| Carrière | École, Vie au bahut (#28), Université, Offres d'emploi et Mon travail (#7), Ma boîte (#23), Agence de détective et Ma secte (docs/SECTE_DETECTIVE.md), Politique (#25), Retraite (#27) |
| Biens | Boutique et Mes biens (#5), Banque et placements (#14), Mon testament et Héritages (#30) |
| Relations | Famille, Amour, Amis (+ famille élargie #12, secrets #17), Rencontres (#12), Téléphone (#26), Voisins (#35), Animaux (#32), Réputation du nom (#15), Carnet des secrets (#17) |
| Activités | activités rapides du moteur, Loisirs (#31), Coiffeur et Chirurgie esthétique (docs/BEAUTE.md), Télévision (#19), Casino (#16), Santé (#12), Permis (#13), Vivre à l'étranger (#29), Crime, Prison (#12), Casier judiciaire (#11) |
| Activités | activités rapides du moteur, Loisirs (#31), Télévision (#19), Casino (#16), Santé (#12), Permis (#13), Voyage sur mesure (docs/VOYAGES.md), Vivre à l'étranger (#29), Crime, Prison (#12), Casier judiciaire (#11) |
| Moi | Mon profil (rêves #18), Compétences (#21), Trophées (#20), Journal du monde (#34), Musée des vies (#6), Réglages (Shkurtaaa #1) |
| Ailleurs | Création de perso (#2) sur l'accueil ; nécrologie (#6), carte de vie (#8), testament (#30) et lignée (#12) sur l'écran de mort ; une du Journal du monde, événements d'animaux et cartes du collège en feuilles automatiques sur l'écran principal |

Sans écran (ils agissent dans le moteur) : répercussions (#3), paranormal (#9), fêtes (#24).

## Ajouter un module

1. Un `case` dans `ModuleJeu`, puis ses lignes dans `categorie`, `groupe`, `titre`, `description`, `icone`
   (le compilateur signale les `switch` incomplets).
2. Si besoin, une condition dans `visible(_:)` ou `verrou(_:)`.
3. Son écran dans `EcranModule.contenu(_:)`. Un écran qui a sa propre `NavigationStack` et son bouton « Fermer »
   s'appelle directement ; une simple liste s'habille avec `Feuille(titre:) { … }`.

# Architecture de tpg Next

Guide pour modifier l'app sans casser l'iPhone, l'iPad ni la montre.

## Les cibles

| Cible | Dossier | Rôle |
|---|---|---|
| `tpg Next` | `tpg Next/` | L'app iPhone et iPad |
| `tpgNextFunc` | `tpgNextFunc/` | Framework partagé : requêtes OJP, lecture des réponses, modèles, base des arrêts, couleurs des lignes |
| `tpg Next Widget` | `tpg Next Widget/` | Widget des départs (passe par l'App Group) |
| `tpg Next Watch App` | `tpg Next Watch App/` | App Apple Watch |
| `tpgNextFuncTests` | `tpgNextFuncTests/` | Tests du framework, sur de vraies réponses de l'API |

Les dossiers sont **synchronisés** : un fichier créé dans `tpg Next/` (ou un sous-dossier) est
ajouté à l'app automatiquement. Rien à faire dans le projet Xcode.

## Où ranger quoi

```
tpg Next/
├── StopView.swift, LineView.swift, TripView.swift…   écrans (un fichier par écran)
├── Navigation/AppRoute.swift                         tous les écrans ouvrables
├── Layout/                                           mise en page selon la largeur
│   ├── LayoutContext.swift                           \.layout, colonnes, largeur de lecture
│   └── AdaptiveSplit.swift                           deux moitiés sur grand écran
├── Components/                                       morceaux partagés par plusieurs écrans
│   ├── JourneyMap.swift                              parcours d'une course sur une carte
│   ├── LineFilterChips.swift                         lignes à toucher pour filtrer des départs
│   └── ServiceInfoLabels.swift                       libellés accès PMR, capsules d'info
├── Stop/   Line/   Trip/   Home/                     morceaux propres à un écran
```

Règle simple : un morceau utilisé par un seul écran va dans le dossier de cet écran ; dès
qu'un deuxième écran s'en sert, il passe dans `Components/`.

Ce qui parle à l'API ou décode ses réponses va dans `tpgNextFunc`, pas dans l'app : le
widget et la montre en profitent, et les tests peuvent le vérifier.

## Ouvrir un écran

Un lien ne construit jamais l'écran d'arrivée : il dit **quoi** ouvrir, la pile de l'onglet
décide **où**.

1. Ajouter un `case` dans `AppRoute` (`Navigation/AppRoute.swift`) :
   ```swift
   case favoriteStops
   ```
2. Dire quel écran il affiche, dans `AppRouteDestination` :
   ```swift
   case .favoriteStops:
       FavoriteStopsView()
   ```
3. L'ouvrir :
   ```swift
   // Dans une liste : garde l'effet de toucher et l'accessibilité d'un lien.
   NavigationLink(value: AppRoute.favoriteStops) { Text("Favoris") }

   // Depuis un bouton, un menu ou un rappel :
   @Environment(\.openRoute) private var openRoute
   Button("Favoris") { openRoute(.favoriteStops) }
   ```

À éviter : `NavigationLink { FavoriteStopsView() } label: { … }`. L'écran est construit à
chaque affichage du lien, et il ne pourra pas s'ouvrir ailleurs que dans la pile.

## iPhone, iPad, écran pliable : une seule vue

Il n'y a **pas** de vues réservées à l'iPad. Chaque écran lit la largeur disponible et
choisit sa disposition. Un iPad en Split View étroit reçoit donc l'affichage iPhone, et un
écran pliable passe de l'un à l'autre en s'ouvrant.

```swift
@Environment(\.layout) private var layout

if layout.widthClass == .compact {
    // iPhone, fenêtre étroite
} else {
    // .regular (iPad mini, portrait) ou .wide (grand iPad en paysage)
}
```

Outils disponibles :

| Besoin | Outil |
|---|---|
| Deux moitiés sur grand écran | `AdaptiveSplit { gauche } secondary: { droite }` |
| Savoir si la moitié droite est affichée | `layout.showsSecondaryPane` |
| Une liste qui ne s'étire pas sur iPad | `.readableScrollContent()` sur le `ScrollView` |
| Une carte ou un panneau borné et centré | `.readableWidth()` |
| Nombre de colonnes de favoris | `layout.favoriteColumns` |

Exemple réel, la page arrêt (`StopView.swift`) :

```swift
AdaptiveSplit {
    ZStack { /* liste des départs, inchangée depuis l'iPhone */ }
} secondary: {
    StopDetailPane(/* carte + détails */)
}
```

Sur grand écran, toucher un départ le **sélectionne** au lieu d'ouvrir sa course :

```swift
if layout.showsSecondaryPane {
    Button(action: { select(event) }, label: label)
} else {
    NavigationLink(value: AppRoute.line(…), label: label)
}
```

À éviter : `UIScreen.main`, `UIDevice.current.userInterfaceIdiom`, les largeurs fixes
(`.frame(width: 220)` ; préférer `.frame(maxWidth: 220)`).

## Voir le rendu sans lancer l'app

Dans un `#Preview`, forcer la largeur :

```swift
#Preview("iPad") {
    StopView(stopName: "Genève, Rive", stopSloid: "ch:1:sloid:87061", autoRefresh: false)
        .environment(\.layout, LayoutContext(width: 1100))
        // + les .environment(…) habituels de l'aperçu
}
```

Dans le simulateur, choisir un iPad, puis tester aussi le Split View (fenêtre étroite) et la
rotation.

## Données OJP

Toutes les requêtes passent par `OJPClient` (`tpgNextFunc/OJPClient.swift`).

| Écran | Requête | Version | Fichier |
|---|---|---|---|
| Départs d'un arrêt | `OJPStopEventRequest` | 2.0 | `StopFunc.swift`, lecture dans `OJPParsing.swift` |
| Course d'une ligne | `OJPTripInfoRequest` | 2.0 | `LineFunc.swift`, lecture dans `JourneyParser.swift` |
| Itinéraires | `OJPTripRequest` | 1.0 | `TripFunc.swift` |

Bon à savoir :

- **L'ordre des paramètres compte.** L'API refuse (erreur 400) une requête dont les
  paramètres ne suivent pas l'ordre du schéma OJP.
- **Les textes arrivent en allemand**, quelle que soit la langue demandée. Lire les codes
  (`A__NF`, `PLATFORM_ACCESS_WITH_ASSISTANCE`) et écrire les libellés dans l'app
  (`Components/ServiceInfoLabels.swift`).
- **L'exploitant n'est qu'une référence** en 2.0 (`ojp:881`). `OJPOperators.swift` la
  traduit en nom pour `LineColors`. Un exploitant absent de la table prend la couleur par
  défaut : relever sa référence et l'ajouter.
- **Arrêts précédents et suivants** : ne pas les demander avec la liste des départs (8 fois
  plus lourd). Charger la course du départ choisi avec `JourneyTrackModel`.
- **Nouveau champ sur un modèle enregistré** (`StopEvent` est encodé dans les rappels) : le
  déclarer optionnel, pour que les anciennes données se décodent toujours.

Informations disponibles et déjà lues : course supprimée, accès PMR au quai, plancher bas,
mode, numéro de course, tracé routier. Non fournies pour les tpg : position GPS réelle,
taux d'occupation. La position affichée sur la carte de ligne est **estimée** à partir des
horaires (`estimatedVehiclePosition`).

## Tests

Les parseurs sont testés sur des réponses réelles enregistrées dans
`tpgNextFuncTests/Fixtures/`. Après une modification de lecture :

1. Lancer les tests du schéma `tpgNextFunc` (⌘U).
2. Si un instantané `.expected.json` doit changer, le supprimer, relancer : il est recréé et
   le test échoue une fois. **Le relire** avant de le commiter.

Pour enregistrer une nouvelle réponse, faire la requête (même XML que l'app) et placer le
fichier `.xml` dans `Fixtures/`.

## Ouvrir un écran sans toucher l'écran (Debug)

La variable d'environnement `TPG_DEBUG_URLS` ouvre des liens au lancement (séparés par des
espaces). Pratique pour les captures ou pour arriver directement sur un écran :

```
tpgnext://stop?sloid=ch:1:sloid:87061&name=Rive
tpgnext://stop?sloid=ch:1:sloid:87061&name=Rive&journeyRef=…   (course présélectionnée)
tpgnext://line?journeyRef=…&operatingDayRef=…&line=12&sloid=…
tpgnext://tab?name=trip
tpgnext://settings
```

Dans Xcode : Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables.

# Architecture de tpg Next

Guide pour modifier l'app sans casser l'iPhone, l'iPad ni la montre.

## Les cibles

| Cible | Dossier | Rôle |
|---|---|---|
| `tpg Next` | `tpg Next/` | L'app iPhone et iPad |
| `tpgNextFunc` | `tpgNextFunc/` | Framework partagé : requêtes OJP, lecture des réponses, modèles, base des arrêts, couleurs des lignes |
| `tpg Next Widget` | `tpg Next Widget/` | Widget des départs (passe par l'App Group) |
| `tpg Next Watch App` | `tpg Next Watch App/` | App Apple Watch |
| `tpg Next Watch Widget` | `tpg Next Watch Widget/` | Complications de la montre (embarquées dans l'app montre) |
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
├── Previews/                                         données et environnement des aperçus Xcode
└── Preview Content/                                  réponses API des aperçus (hors archive)
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
| Boutons à droite de la barre | `.toolbar { TrailingBarButtons { … } }` : un élément de barre par bouton, posés à la verticale sur l'iPhone Duo fermé |

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

Chaque écran et chaque morceau complexe a ses aperçus, en bas de son fichier. Ils reposent sur
deux outils de `Previews/` :

- **`.previewEnvironment()`** pose tout ce que l'app fournit : modèles d'environnement,
  largeur mesurée (`\.layout`), horloge, dégradé de fond, et une pile qui ouvre les routes.
  Options : `navigation: false` (composant, ou `ContentView` qui a ses piles), `favorites:`,
  `savedTrips:`, `itinerary: (départ, arrivée)`, `background: false`.
- **`PreviewData`** : de vraies réponses de l'API (`Preview Content/*.xml`), lues par les
  parseurs de l'app, heures recalées sur maintenant. Départs de Genève, Rive (`departures`,
  `quays`), course de la ligne 29 avec son tracé (`journeyStops`, `lineDeparture`,
  `journeyModel()`), itinéraires Rive → Cornavin (`trips`, `tripWithTransfer`, `directTrip`).
  Pour un cas précis : `PreviewData.departure(line:destination:inMinutes:delay:cancelled:…)`.

```swift
#Preview("Arrêt — iPad", traits: .iPadLandscape) {
    StopView(stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid, autoRefresh: false)
        .previewEnvironment()
}
```

- Grand écran : `traits: .iPadLandscape` (`.wide`) ou `.iPadPortrait` (`.regular`) ; la
  largeur est mesurée comme dans l'app, sans rien forcer.
- Réglages `@AppStorage` : `.previewSettings([SettingKey.homeShowsFavorites: true])`.
- Écrans qui chargent eux-mêmes une course (`LineView`, carte de ligne) : une course enregistrée
  n'existe plus côté API. `LiveDeparturePreview { departures in … }` demande d'abord de vrais
  départs du jour. Les aperçus marqués « (API) » ont besoin du réseau.
- Les aperçus « bac à sable » (départ, arrêt de ligne) ont des réglages pour modifier un
  élément en direct : passer le canevas en mode interactif.
- Libellés propres aux aperçus : `Text(verbatim:)` ou `"…" as String`, sinon Xcode les ajoute
  à `Localizable.xcstrings`.
- `BasicViews.swift` est aussi compilé pour le widget : ses aperçus n'utilisent pas `PreviewData`.
  Le widget a ses propres aperçus (`WidgetPreviews.swift`), la montre les siens
  (`WatchPreviewData.swift`).

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
- **« Ausfall » ne veut pas dire « supprimé ».** L'attribut d'incident (`…_IncidentTrip…`)
  marque toute course perturbée, même celles qui ne sautent que quelques arrêts. Seul
  `NotServicedStop` dit qu'un arrêt n'est pas desservi (`StopEvent.cancelled`,
  `LineEvent.isCancelled`) ; l'incident seul donne « Parcours modifié » (`routeChanged`).
  Aucun texte de perturbation n'est fourni (`Situations` vide, SIRI-SX non ouvert à notre clé).
  Cas réel : `Fixtures/stopEvents-meinier-incident.xml`.
- **Une déviation prévue n'a aucun marqueur.** Elle est intégrée à l'horaire du jour : les
  arrêts évités sont simplement absents. Seul indice, la course ne circule qu'un jour
  (`OperatingDays/Pattern` avec un seul « 1 ») : `StopEvent.exceptional`, « Horaire
  exceptionnel ». Ce calendrier n'arrive qu'avec les départs, pas avec la course ni les
  itinéraires. Cas réel : `Fixtures/stopEvents-capite-exceptional.xml` (ligne G).
- **Nouveau champ sur un modèle enregistré** (`StopEvent` est encodé dans les rappels) : le
  déclarer optionnel, pour que les anciennes données se décodent toujours.

Informations disponibles et déjà lues : course supprimée, accès PMR au quai, plancher bas,
mode, numéro de course, tracé routier. Non fournies pour les tpg : position GPS réelle,
taux d'occupation. La position affichée sur la carte de ligne est **estimée** à partir des
horaires (`estimatedVehiclePosition`).

## Trajets réguliers et activité en direct

- Un trajet régulier garde une **recette** (`tpgNextFunc/RegularTrip.swift`) : départ, arrivée,
  heure de Genève, lignes et arrêts. Chaque jour, `OJPTripRequest` 1.0 est redemandée et le
  trajet habituel y est reconnu (`.usual`, `.shifted`, `.alternative`). Écrans et
  notifications : `tpg Next/RegularTrips/`.
- **Absent de la réponse ne veut pas dire perdu** : OJP ne propose que ~5 itinéraires, choisis
  d'après le temps réel. Quand le trajet habituel n'y est plus (ou n'y est qu'à une autre
  heure), celui déjà reconnu ce jour-là (`RegularTrip.knownUsual` : courses datées, même jour)
  est vérifié course par course par `TripVerifier` (`OJPTripInfoRequest`) : il reste `.usual`
  tant que ses courses s'arrêtent à la montée et à la descente et qu'aucun véhicule suivant ne
  part avant l'arrivée du précédent (plus serré que la marche : gardé, signalé « compromise »).
  Le trajet connu vient de `RegularTripsModel` (gardé d'un lancement à l'autre,
  `regularTripsKnownUsual`), de l'activité en direct, de l'itinéraire enregistré lui-même, ou
  de l'autre trajet choisi pour ce jour. Une première reconnaissance sans trajet connu (app
  relancée tout près du départ) reste exposée au problème.
- « Mes itinéraires » (`SavedTripsAgenda`, dans `SavedTripsView.swift`) mélange jour par jour les
  itinéraires enregistrés et les prochains trajets réguliers, avec un filtre Tous / Enregistrés /
  Réguliers. Tout va du plus ancien (en haut) au plus récent. Les passés, au-dessus, sont
  repliés derrière un bouton : défiler jusqu'aux prochains à l'ouverture n'a pas lieu pendant
  l'animation d'arrivée de l'écran. C'est la racine de l'onglet **Trajets** (qui remplace
  l'onglet Carte) : un itinéraire s'ouvre par-dessus et le retour ramène à la liste. Son filtre
  est tenu par `NavigationModel.tripsFilter` ; `showTrips(_:)` y ramène (lien
  `tpgnext://savedtrips`, `tpgnext://regulartrips`, routes `.savedTrips` et `.regularTrips`
  venues d'une notification). Poussée sur une autre pile, la liste est `SavedTripsPage`.
- Sur grand écran, la page d'un itinéraire (`FullTripView`) pose sa carte à droite
  (`TripMapCard`, partagée avec `TripDetailPane`) ; toucher une étape la cadre. Dans la
  recherche, la moitié droite a un bouton « Ouvrir en plein écran », repris dans le menu des
  résultats.
- Un trajet régulier se crée aussi sans recherche préalable (`NewRegularTripView`, bouton
  `calendar.badge.plus` de l'agenda) : départ, arrivée, jours et heure, puis
  `RegularTripResolver.trips` propose les itinéraires du prochain jour coché
  (`Weekday.nextDate`) ; celui choisi devient la recette.
- **Un autre trajet pour un jour** : `RegularTrip.dayOverrides` (optionnel) garde l'itinéraire
  choisi par jour ; `recipe(for:)` en fait la recette de ce jour-là (heure, lignes suivies), donc
  reconnaissance, rappels, alertes et activité en direct le suivent sans rien savoir de plus.
- **Itinéraires enregistrés en direct** : `SavedTripResolver` les traite comme un trajet régulier
  d'un seul jour (même course → `.usual`, mêmes lignes à une autre heure → `.shifted`, plus
  proposé → `.alternative` avec le meilleur à sa place). `SavedTripsModel.refresh` les redemande
  une fois dans la semaine qui précède, puis au rythme des trajets réguliers dans les trois
  heures, tant que l'agenda est affiché ; l'état n'est pas enregistré. « Autres horaires » et
  « Choisir un autre trajet » passent par `TripAlternativesView`.
- **Le suivi exige la localisation** (`TripLiveActivities.hasLocation`) : sans elle, rien ne
  garde l'app éveillée et l'activité se figerait. Le bouton reste visible et explique
  (`askForLocation`) ; les lancements automatiques se taisent, et n'ont lieu qu'au premier plan
  (ActivityKit) — un trajet n'est marqué lancé que si l'activité existe vraiment.
- L'activité en direct suit soit un **itinéraire** (redemandé par `OJPTripRequest`), soit une
  **course** choisie depuis un départ (`TrackJourneyView`, route `.trackJourney`) et redemandée
  par `OJPTripInfoRequest` : on reste sur ce véhicule-là même s'il prend du retard.
- L'activité en direct (`tpg Next/LiveActivity/`) : données dans `tpgNextFunc/TripActivity.swift`,
  vues dans `TripLiveActivity.swift`, compilé aussi pour le widget (exception de membre, comme
  `BasicViews.swift`), gestion dans `TripLiveActivities.swift`.
- **Pas de serveur push** : seule l'app met l'activité à jour. Pendant un trajet suivi, une
  session d'activité d'arrière-plan (`TripBackgroundLocation`, `CLBackgroundActivitySession`,
  mode `location`) la tient éveillée : le flux de positions sert d'horloge (une relecture par
  minute) et de source pour la correction des heures. Elle se ferme au dernier trajet terminé,
  et ne s'ouvre pas sans autorisation de localisation — restent alors les réveils d'iOS. L'affichage tient seul entre deux mises à jour :
  minutes restantes en format système (`Text(.currentDate, format: .offset(…))`, « 4 minutes » ;
  un format maison ne serait pas évalué par l'écran verrouillé), étape et position du véhicule
  déduites de l'heure (`phase(at:)`, `vehicleStop(at:)` sur les passages embarqués),
  `staleDate` au prochain changement d'étape. L'état doit tenir en 4 Ko (passages limités).
- Dans l'app, le trajet suivi s'affiche en bandeau sous les onglets (`tabViewBottomAccessory`
  sur iOS 26, capsule au-dessus du dock avant) et en entier sur la route `.liveTrip`
  (`LiveTripView`). L'état vient de `TripLiveActivities.live`, tenu à jour avec l'activité.
  Le bandeau n'est posé que s'il y a un trajet suivi (vide, il occuperait quand même sa place).
  Il s'ouvre en feuille plein écran, posée par `ContentView` (`LiveTripPresentation.shared`) : le
  bandeau est refait à chaque changement d'étape et emporterait sa feuille. Le trajet y est
  déroulé de haut en bas (départ, montées, véhicules et leurs arrêts, attentes, arrivée), l'étape
  en cours sur fond teinté et les étapes passées effacées.
- **Position** : dans le véhicule, la position du voyageur est celle du véhicule.
  `TripPositionEstimator.fix(on:…)` la projette sur le tracé (`TripRoute`, gardé dans l'app :
  l'activité n'a pas la place) et en tire l'avance ou le retard, appliqué par
  `TripActivityState.adjusted(leg:by:now:)`. Deux garde-fous : plus de 150 m du tracé (le trajet
  est suivi de loin) ou plus de 3 minutes d'écart (tracé grossier), et c'est l'horaire d'OJP qui
  reste. La correction part toujours du dernier état d'OJP (`baseStates`), jamais d'un état déjà
  corrigé. Demandée seulement si la localisation est déjà autorisée, et seulement à bord.
- **Un trajet commencé ne se remplace plus** (`TripActivityState.hasLeft(at:)`) : redemander
  l'itinéraire depuis le point de départ renverrait en arrière un voyageur déjà à mi-chemin.
  Un véhicule supprimé ne compte pas comme un départ : tout reste alors à refaire.
- `transferProblem()` dit ce qu'il advient de la première correspondance en défaut, avec le
  temps de correspondance d'OJP (`Leg.transferTime`) plutôt qu'une minute forfaitaire :
  - `.missed` (véhicule parti, ou `Leg.cancelled` : il ne s'arrête plus là) → `TripReplanner.tails`
    redemande la suite depuis l'arrêt de descente, recollée par `TripEvent.splicing(after:with:)`.
    Les autres propositions restent offertes (`alternatives`, `choose(_:for:)`).
  - `.doubtful` (le véhicule partait à l'instant où l'on descendait) → rien n'est réécrit :
    `TripPositionEstimator.isAboard(on:…)` compare la position du voyageur à celle où le véhicule
    devrait être ; à défaut de réponse, `state.question` fait poser la question par l'activité en
    direct elle-même (`TripActivityQuestion`, sur fond teinté, à la place de la frise) et par la
    page du trajet. Les boutons de l'écran verrouillé passent par `TripBoardingIntent`
    (`LiveActivityIntent`, compilé aussi dans le widget) : il poste une notification que l'app
    reçoit, faute de pouvoir appeler `TripLiveActivities` depuis le widget.
- Alertes d'un trajet suivi : `TripStepAlerts`, posées à l'avance comme les rappels, et
  reposées à chaque mise à jour du trajet — donc avec la correction de position. Par véhicule :
  « Votre véhicule arrive » (1 min avant la montée, omise si le « Descendez ici » précédent
  tombe moins de 3 min avant : il l'annonce), « Préparez-vous à descendre · Prochain arrêt : X »
  (au départ de l'arrêt d'avant, lu dans les passages embarqués ; sinon 2 min avant), puis
  « Descendez ici · C'est votre arrêt : X. Ensuite : le 19 à 16:03, quai B. » (30 s avant).
  « Arrivée » seulement si le trajet finit à pied.
  Chacune ne part qu'une fois (`liveStepAlertDates`) : reposer une alerte déjà partie quand
  l'heure reculait la faisait sonner deux fois.
- L'activité s'allume et sonne (`AlertConfiguration`) quand une correspondance serrée pose sa
  question, ou quand son texte de changement change : en route, et avant le départ des
  itinéraires qui ne sont pas des trajets réguliers (ceux-là ont leurs notifications). En route,
  les alertes de trajet régulier se taisent (`TripLiveActivities.isUnderway`) : l'itinéraire
  redemandé depuis le départ n'a plus rien à dire.
- Rappels posés depuis un départ (`BusNotificationManager`) : recalés sur l'heure estimée à
  chaque réveil de l'app (`refreshPending`, appelé par `RegularTripsModel.refresh`), et la
  tâche de fond est demandée une heure avant le prochain. En avance, seule la notification à
  l'heure estimée part. Les rappels des trajets réguliers ne prennent que la place laissée
  sous 60 notifications en attente (iOS n'en garde que les 64 plus proches).
- Une notification dont le moment est passé quitte le centre de notifications :
  `NotificationExpiry.mark(_:after:)` à la pose, `clearExpired()` au ménage (premier plan chaque
  minute, réveils en arrière-plan). iOS ne sait pas le faire seul, donc celles reçues app éteinte
  attendent sa prochaine ouverture.
- Dynamic Island dépliée : le nom du trajet (ou, à bord, l'arrêt du véhicule) à gauche de la
  caméra, l'heure d'arrivée à droite, et dessous la frise sans son en-tête
  (`showsHeader: false`), avec ses traits de lignes — ou la question et ses boutons.
- Dans la Dynamic Island compacte, les minutes du système (« 4 minutes », réduites pour tenir),
  comme sur l'écran verrouillé : le décompte à la seconde (« 4:32 ») promettait une précision
  que les heures estimées n'ont pas, et aucun format système ne donne « 4' » (vérifié : même le
  minuteur réglé à la minute écrit « 2 minutes »). Le marqueur dit ce qu'il y a à faire —
  badge de ligne à bord, `figure.walk` en chemin, `clock` à l'arrêt, puis l'icône du véhicule
  une minute avant la montée estimée (`TripActivityState.approachLead`, échéance ajoutée à
  `nextTransition` pour que le système redessine seul), et le véhicule à l'arrivée.
- Les captures du simulateur (`simctl io screenshot`) ne montrent pas la Dynamic Island :
  utiliser les aperçus de `TripLiveActivity.swift`.

## Accueil et recherche

- **Accueil** (`HomeView`, morceaux dans `Home/`) : sections dans l'ordre choisi par l'utilisateur
  (`HomeSection`, Paramètres → Organiser l'accueil, réglages `HomeSectionsOrder` et `HomeHiddenSections` ; départs masqués sur iPad : une seule colonne, et la carte cherche elle-même les arrêts proches). L'arrêt choisi
  (`NearbyStops.selectedSloid`) est partagé par la liste et la carte : toucher un arrêt de la
  carte le choisit (recherche du plus proche du doigt via `MapReader`, pas de bouton dans les
  marqueurs), toucher ailleurs ouvre la carte plein écran. Contenu : le prochain trajet des douze prochaines
  heures (`NextTripSection`, régulier ou enregistré, avec l'heure où partir
  `TripEvent.leavingDate`), précédé de sa date — sans trajet, pas de date —, les favoris, les
  départs à proximité, puis la carte « Autour de vous » (`HomeMapCard`, aperçu figé qui montre
  les mêmes arrêts que la liste, `NearbyStops`, et met en évidence celui qu'elle affiche ; le toucher ouvre `MapView`
  en plein écran, avec sa propre pile et son propre `\.layout`, mesuré à nouveau). Sur grand
  écran, rien ne défile : à gauche le prochain trajet, les favoris et la carte qui prend la place
  restante ; à droite les départs empilés (`HomeDepartures(stacked:)`, un arrêt déplié à la
  fois) ; les réglages passent dans la barre du haut. Chaque colonne reçoit un `\.layout` de sa
  largeur.
- **Recherche** (`SearchView`, morceaux dans `Search/`) : résultats groupés (mes itinéraires,
  arrêts, lieux de Plans) ; sans texte, les récents (itinéraires, arrêts, lieux) et les arrêts
  proches. Un lieu ou un arrêt ouvre `PlaceSheet` : « Y aller », « Partir d'ici », arrêts proches.
- **Lignes** : le registre national (ATLAS), embarqué comme la base des arrêts
  (`tpgNextFunc/Stops Database/Lines.json`, lu par `LineDirectory`) : toutes les lignes
  régulières de Suisse et leurs transporteurs (`TransitOperator`, dont la référence OJP 2.0,
  `ojp:<numéro d'organisation>`, qui complète `OJPOperators`). À régénérer à chaque horaire
  annuel avec `python3 Scripts/lines-from-atlas.py`. L'utilisateur choisit ses transporteurs
  (`LineOperatorChoice`, réglage `LineOperators`, tpg par défaut) et passe de l'un à l'autre en
  haut de `LinesView` ; la recherche ne propose que leurs lignes. Routes `.lines` et `.lineInfo`
  (terminus, prochains départs de chaque terminus qui ouvrent la course, arrêts principaux). Les arrêts du registre (« Thônex Moillesulaz ») sont retrouvés dans la base
  (« Thônex, Moillesulaz ») par `StopStore.stop(named:)`, à la ponctuation près.
- **Lancer une recherche d'itinéraire depuis ailleurs** (« Y aller », itinéraire récent) :
  `ItineraryViewModel.searchNow(from:to:tab:)`
  (sans départ : depuis la position, par le chemin de « Trajet rapide »). L'onglet Itinéraire
  la lance en s'affichant (`pendingSearch`). Chaque recherche est retenue dans `RecentTrips`.

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
tpgnext://regulartrips
tpgnext://savedtrips
tpgnext://settings
```

Dans Xcode : Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables.

## Widget « Prochain trajet »

L'app écrit les prochains trajets (réguliers et enregistrés, avec leur temps réel s'il est
connu) dans le groupe d'app : `UpcomingTripsPublisher` → `UpcomingTripsStorage`, à chaque
rafraîchissement (premier plan, tâche de fond) et à chaque modification. Le widget
(`tpg Next Widget/NextTripWidget.swift`, ajouté à la main au projet : ce dossier n'est pas
synchronisé) ne fait qu'afficher, avec une entrée par minute dans l'heure qui précède le départ.
Le rechargement n'a lieu que si les trajets changent (budget WidgetKit).

Le décompte (`TripCountdown`, partagé par le widget et la carte « Prochain trajet ») met le
véhicule en avant : ligne → direction, heure de montée et « dans 8 min ». La marche jusqu'à
l'arrêt n'y est jamais comprise ; elle est rappelée à part, avec le marcheur : « Partir dans
11 min · 3 min à pied jusqu'à Rive » (minutes déduites de celles du bus moins la marche, pour
que les chiffres s'additionnent). Une fois monté : « En route · arrivée à … ».

Le suivi en direct automatique des itinéraires enregistrés (réglage `SavedTripAutoTrackMinutes`)
ne peut démarrer que l'app ouverte : `SavedTripAutoTracking` pose une notification à l'heure
voulue, qui ouvre l'app ; `TripLiveActivities.startSoonDepartingSavedTrips` lance alors le suivi.

Rappels avant le départ, réglés par appareil (les trajets arrivent partout par iCloud) :
- trajets réguliers : `RegularTripRemindersOnThisDevice` active les rappels (délai choisi dans
  chaque trajet), `RegularTripAlertsOnThisDevice` les alertes de retard et le suivi en direct ;
- itinéraires enregistrés : `SavedTripReminderMinutes` (−1 : jamais), posé par
  `SavedTripReminders` à l'heure de partir du temps réel. Pas de rappel quand l'invitation au
  suivi automatique tombe au même moment.
Le sous-titre (`TripCountdown.reminderSubtitle`) ne compte jamais la marche dans le départ :
« Partir dans 10 min · 5 min à pied », ou « Départ dans 10 min » depuis l'arrêt même.

Bienvenue (`WelcomeView`) : 1) les deux autorisations, sans sortie tant que chacune n'a pas
reçu de réponse ; 2) au choix, visite guidée, guide complet ou commencer ; 3) la visite
(`Guide/GuideTourView.swift`). Les démonstrations à toucher (`Guide/GuideDemos.swift`, départs
factices sauf l'étoile, qui ajoute vraiment le favori) servent à la visite et au guide
(`GuideEntry.demo`). Elles reprennent les vues de la page d'un arrêt (`StopEventView`,
`SortedStopEventsView` sans rappels, `StopFloatingControls`, `LineFilterSheet`).
L'icône de l'app dans l'app : `AppIconView`, image `AppIconImage` tirée des PNG de
`AppIcon.appiconset` (l'icône `tpgNext26.icon` n'est pas lisible à l'exécution) ; à refaire si
l'icône change.

Guide d'utilisation (Paramètres → Guide d'utilisation, route `.userGuide`) : le texte vit seul
dans `Guide/UserGuideContent.swift` (groupes → rubriques → points, avec un lien facultatif vers
une `AppRoute`) ; `Guide/UserGuideView.swift` l'affiche et y cherche. Capture :
`tpgnext://guide` ou `tpgnext://guide?topic=<id>`.

## Montre

Une seule pile (`ContentView`) : l'accueil (« À proximité », « Favoris ») à la base ; au lancement
et au retour de l'arrière-plan, l'arrêt le plus proche est ouvert par-dessus. Les écrans s'ouvrent
par valeur, comme sur l'iPhone : `WatchRoute` (`JourneyViewWatch.swift`) dit quoi ouvrir, la pile
le construit (`.navigationDestination(for: WatchRoute.self)`).

- Arrêt (`StopView`) → départ → course (`JourneyView`) → arrêt de la course, à l'heure de
  passage du véhicule (`JourneyPassage`), départ entouré.
- Réglages de la montre : `@AppStorage` sur `SettingKey.clockTimeByDefault` et
  `groupByLineByDefault`, propres à la montre (pas de groupe d'app avec l'iPhone).
- Favoris : envoyés par l'iPhone (sens unique, pas de modification sur la montre), relus par
  sloid dans la base de la montre (`resolvedFavorites(in:)`).
- Complications (`tpg Next Watch Widget`, watchOS 26) : `DeparturesProvider` et `SelectStopIntent`
  du widget iPhone sont compilés aussi pour cette cible (`#if os(watchOS)` pour ce qui diffère),
  seules les vues sont propres (`WatchDeparturesWidget.swift`). L'app montre écrit pour elles
  l'index des arrêts, les favoris (`FavoritesStorage.save`) et la dernière position dans le
  groupe d'app. Toucher une complication ouvre `tpgnext://stop?sloid=…&name=…`.
- Complication « Prochain trajet » : mêmes trajets que le widget iPhone, reçus par `WatchContext`
  puis recopiés par l'app montre dans `UpcomingTripsStorage` ; moments d'affichage communs
  (`NextTripTimeline`). Toucher ouvre `tpgnext://trip?id=…`.
- Plan et état d'avancement : `ROADMAP-Montre.md`.
- Pas de toucher sur le simulateur : pour voir un écran poussé, un banc d'essai temporaire
  (vue racine choisie par variable d'environnement, `SIMCTL_CHILD_…`), retiré avant le commit.

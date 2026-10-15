# Feuille de route de l'app Apple Watch

Plan proposé le 1er octobre 2026 pour compléter l'app montre, qui ne montrait alors que les
départs d'un arrêt. Chaque étape est indépendante : on peut en sauter une et y revenir plus tard.

Légende : ✅ fait · ⏳ à faire · ⏭️ sautée pour l'instant · 🚫 écartée

## Décisions prises

- **Pas de gestion des favoris sur la montre** : ils viennent de l'iPhone, en sens unique.
- **watchOS 26 minimum** (depuis watchOS 10.5). watchOS 11 et 26 tournent sur les mêmes
  montres (Series 6 et plus récentes, SE 2, Ultra) ; seules les Series 4, 5 et SE 1 sont
  laissées de côté. Plus besoin de `#available` pour les API de watchOS 26.

## Étape 0 — Fondations ✅

| | Point | État |
|---|---|---|
| 0.1 | Composant commun pour une ligne d'arrêt (`StopRow`, `StopDot`), code mort retiré | ✅ |
| 0.2 | Réglages « heure / temps restant » et « tri » mémorisés (`@AppStorage`) | ✅ |
| 0.3 | États distincts : chargement, pas de départs, connexion impossible + Réessayer, « Hors ligne · 18:12 » | ✅ |
| 0.4 | Favoris relus par sloid dans la base de la montre (`resolvedFavorites(in:)`) | ✅ |
| 0.5 | Une seule `NavigationStack` à la place de `NavigationSplitView` et `.carousel` ; listes système | ✅ |

## Étape 1 — Page d'un arrêt ✅

| | Point | État |
|---|---|---|
| 1.1 | Toucher un départ ouvre sa course (`JourneyView`) : arrêts, heures, quais, véhicule, arrêts sautés | ✅ |
| 1.2 | Filtre par ligne dans le menu | ✅ |
| 1.3 | Départs plus tard : « +15 min », « +30 min », « +1 h », « Maintenant » (la couronne sert déjà à défiler) | ✅ |
| 1.4 | Perturbations : parcours modifié, horaire exceptionnel, ne passe pas ici + arrêt desservi le plus proche | ✅ |
| 1.5 | Double tap (`.handGestureShortcut`) pour rafraîchir | ⏳ demande un bouton visible ; possible sans `#available` depuis le passage à watchOS 26 |

L'info trafic tpg n'existe dans aucune source ouverte (voir la mémoire « Sources info trafic ») : rien à afficher pour l'instant.

## Étape 2 — Trouver un arrêt ⏭️

| | Point | État |
|---|---|---|
| 2.1 | Arrêts proches avec distance et direction, comme sur l'iPhone | ⏭️ |
| 2.2 | Recherche d'un arrêt par dictée ou griffonnage (`StopStore.search`) | ⏭️ |
| 2.3 | Petite carte des arrêts autour de soi (MapKit) | ⏭️ |

## Étape 3 — Voir sans ouvrir l'app

| | Point | État |
|---|---|---|
| 3.1 | Complications et pile intelligente : prochains départs de l'arrêt le plus proche ou d'un favori | ✅ |
| 3.2 | Complication « Prochain trajet » (`TripCountdown`) | ✅ |
| 3.3 | Pertinence dans la pile intelligente (widget remonté à l'approche d'un départ, API de watchOS 26) | ⏳ idée |

Notes sur 3.1 (cible `tpg Next Watch Widget`) :
- Formats : rectangulaire (arrêt + deux départs), rond (ligne + minutes), coin, en ligne.
- Même fournisseur que le widget iPhone (`DeparturesProvider`, `SelectStopIntent`, partagés).
  Le sélecteur propose « Arrêt le plus proche » et les quatre premiers favoris (`recommendations()`),
  chacun une fois par format. Leur aperçu montre la flèche et « Proche », ou l'étoile et le nom du
  favori ; la rectangulaire garde ce repère devant le nom de l'arrêt.
- Rectangulaire : nom entier de l'arrêt (commune en régulier, arrêt en gras, commune retirée s'il
  est trop long), icônes de ligne de l'app, temps restant au format de l'app dans une seule police.
- L'app montre alimente l'extension par le groupe d'app : index binaire des arrêts, favoris,
  dernière position.
- Toucher la complication ouvre l'arrêt (`tpgnext://stop?sloid=…&name=…`).
- **À vérifier sur une vraie montre** : pose de la complication, choix d'un favori, position
  dans l'extension, ouverture de l'arrêt au toucher. Le simulateur ne permet pas de poser une
  complication sans toucher l'écran : seules les vues et le chemin des données ont été vérifiés.

Notes sur 3.2 (`WatchNextTripWidget.swift`) :
- Rectangulaire : le trajet (« Travail » ou « Rive → Cornavin ») et sa pastille, quand partir,
  puis la ligne, sa direction et l'heure de montée ; une fois monté, l'arrivée.
- Rond et coin : ce qu'il faut viser (marcher, monter, arriver) et les minutes qui restent.
- Moments d'affichage partagés avec le widget iPhone (`NextTripTimeline`, tpgNextFunc).
- L'app montre recopie les trajets reçus dans le groupe d'app (`UpcomingTripsStorage`) et ne
  redessine la complication que s'ils changent. Toucher : détail du trajet (`tpgnext://trip?id=…`).
- Limite : la complication affiche les heures envoyées par l'iPhone, sans temps réel propre.

## Étape 4 — Itinéraires

| | Point | État |
|---|---|---|
| 4.1 | L'iPhone envoie le prochain trajet, les trajets réguliers et les itinéraires enregistrés (`updateApplicationContext`) ; écran « Mes trajets » | ✅ |
| 4.2 | Détail d'un itinéraire : étapes, quai, correspondances, heure où partir | ✅ |
| 4.3 | Suivi en direct : vérifier son rendu sur la montre et la vibration des alertes « Descendez ici » | ⏳ |
| 4.4 | « Rentrer à la maison » : itinéraire vers un lieu favori depuis la montre | ⏳ |

Notes sur 4.1 :
- L'iPhone envoie les 4 prochains trajets (36 h), les mêmes que le widget « Prochain trajet »
  (`UpcomingTripsPublisher`), à chaque calcul : premier plan, tâche de fond, modification.
- `WatchContext` (tpgNextFunc) tient le contexte : `updateApplicationContext` remplace tout le
  dictionnaire, chaque envoi reprend donc favoris et trajets.
- Montre : section « Mes trajets » en tête de l'accueil (`MyTripsWatch.swift`) ; toucher un trajet
  ouvre son détail (4.2). **À vérifier sur appareils jumelés** (le simulateur n'envoie pas le contexte).

Notes sur 4.2 (`TripDetailWatch.swift`) :
- Quand partir, état (pastille de l'iPhone, puis « Temps réel · 19:42 » ou « Cet itinéraire ne
  tient plus »), étapes (ligne → direction, montée et descente avec retard et quai, marche
  « jusqu'à … »), arrivée.
- La montre relit elle-même les courses chaque minute (`TripVerifier.verify`) : les heures ne
  dépendent plus du dernier calcul de l'iPhone. L'arrivée suit la descente du dernier véhicule.
- Toucher une étape ouvre sa course, placée sur l'arrêt de montée.

## Étape 5 — Finitions

| | Point | État |
|---|---|---|
| 5.1 | Écran toujours allumé (`isLuminanceReduced`) : affichage simplifié | ⏳ |
| 5.2 | VoiceOver sur les départs et la course, traduction anglaise | ⏳ |
| 5.3 | Raccourcis : Siri (« prochain bus »), bouton Action de l'Ultra, Centre de contrôle | ⏳ |
| 5.4 | Mode autonome (`WKRunsIndependentlyOfCompanionApp`) pour les montres cellulaires | ⏳ |

## Ordre conseillé pour la suite

3.3 ou 1.5 (petits), puis 4.3 / 4.4, et l'étape 2 quand le besoin se fait sentir.

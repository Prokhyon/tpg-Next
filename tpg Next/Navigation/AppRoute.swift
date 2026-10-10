//
//  AppRoute.swift
//  tpg Next
//

import SwiftUI
import MapKit
import tpgNextFunc

/// Tous les écrans qu'on peut ouvrir par-dessus un onglet.
///
/// Une route dit *quoi* afficher, jamais *où* : aujourd'hui chaque onglet la pousse sur sa
/// pile, mais une colonne de détail (iPad, écran plié) pourra l'afficher sans que les vues
/// qui l'ouvrent ne changent. Les liens n'ont plus à construire l'écran d'arrivée.
enum AppRoute: Hashable {
    /// Départs d'un arrêt. `highlight` met en avant une course (ouverture depuis une ligne,
    /// un itinéraire ou un rappel) et fait partir la liste de son heure de passage.
    case stop(name: String, sloid: String, highlight: DepartureHighlight? = nil)
    /// Course d'une ligne. `event.lineName` est la ligne affichée. `alightStop` : la descente
    /// d'un trajet, quand la course en fait partie ; la page montre alors la portion parcourue,
    /// de `currentStop` (la montée) à elle.
    case line(event: StopEvent, currentStop: ShortStop?, alightStop: ShortStop? = nil)
    case stopMap(quays: [Quay], sloid: String, name: String)
    case lineMap(events: [LineEvent], operatorName: String, event: StopEvent, currentStopSloid: String?)
    case trip(TripEvent)
    case tripMap(TripEvent)
    /// La carte des arrêts, ouverte sur `area` (l'aperçu de l'accueil) ou sur la position.
    case stopsMap(MapArea? = nil)
    case settings
    case favoritesOrder
    /// L'ordre et le nom des lieux favoris.
    case favoritePlacesOrder
    /// L'ordre des sections de l'accueil.
    case homeLayout
    /// Le choix de l'icône, et avec elle de la couleur de l'app.
    case appIcon
    case scheduledNotifications
    /// Mes itinéraires : enregistrés et réguliers.
    case savedTrips
    /// Les mêmes, filtrés sur les trajets réguliers (notifications).
    case regularTrips
    /// Toutes les lignes du réseau.
    case lines
    /// Une ligne, sans course choisie : terminus, prochains départs, parcours.
    case lineInfo(TransitLine)
    /// Le trajet suivi en direct, en entier.
    case liveTrip(key: String)
    /// Sa carte, en grand.
    case liveTripMap(key: String)
    /// Le guide d'utilisation.
    case userGuide
    /// L'usage des clés OJP et les échecs vus par cet appareil.
    case apiDiagnostics
    /// Une rubrique du guide ; `entry` : le point à montrer (depuis la recherche du guide).
    case userGuideTopic(id: String, entry: String? = nil)
}

/// Une zone de carte, comparable : `MKCoordinateRegion` ne l'est pas.
struct MapArea: Hashable {
    var latitude: Double
    var longitude: Double
    var latitudeDelta: Double
    var longitudeDelta: Double

    init(_ region: MKCoordinateRegion) {
        latitude = region.center.latitude
        longitude = region.center.longitude
        latitudeDelta = region.span.latitudeDelta
        longitudeDelta = region.span.longitudeDelta
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                           span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta))
    }
}

/// La course à mettre en avant sur la page d'un arrêt.
struct DepartureHighlight: Hashable {
    var journeyRef: String?
    var lineName: String?
    /// Heure de passage (format OJP) ; `nil` pour partir de maintenant.
    var time: String?
}

extension AppRoute {
    static func stop(_ stop: Stop) -> AppRoute {
        .stop(name: stop.name, sloid: stop.sloid)
    }
}

/// L'écran correspondant à une route.
struct AppRouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case let .stop(name, sloid, highlight):
            StopView(stopName: name,
                     stopSloid: sloid,
                     previousLineRef: highlight?.journeyRef,
                     previousLineName: highlight?.lineName,
                     previousLineTime: highlight?.time)
        case let .line(event, currentStop, alightStop):
            LineView(stopEvent: event, currentStop: currentStop, alightStop: alightStop, currentLine: event.lineName)
        case let .stopMap(quays, sloid, name):
            StopMapView(quays: quays, stopSloid: sloid, stopName: name)
        case let .lineMap(events, operatorName, event, currentStopSloid):
            LineMapView(lineEvents: events, lineName: event.lineName, operatorName: operatorName,
                        destination: event.destination, stopEvent: event, currentStopSloid: currentStopSloid)
        case let .trip(trip):
            FullTripView(fullTrip: trip)
        case let .tripMap(trip):
            TripMapView(tripEvent: trip)
        case let .stopsMap(area):
            MapView(initialRegion: area?.region)
        case .settings:
            SettingsView()
        case .favoritesOrder:
            FavoritesOrderView()
                .navigationTitle("Arrêts favoris")
        case .favoritePlacesOrder:
            FavoritePlacesOrderView()
        case .homeLayout:
            HomeLayoutView()
        case .appIcon:
            AppIconSettingsView()
        case .userGuide:
            UserGuideView()
        case .apiDiagnostics:
            APIDiagnosticsView()
        case let .userGuideTopic(id, entry):
            if let topic = UserGuide.topic(id: id) {
                UserGuideTopicView(topic: topic, entry: entry)
            }
        case .scheduledNotifications:
            ScheduledNotifications()
                .navigationTitle("Rappels prévus")
        case .savedTrips:
            SavedTripsPage()
        case .regularTrips:
            SavedTripsPage(filter: .regular)
        case .lines:
            LinesView()
        case let .lineInfo(line):
            LineInfoView(line: line)
        case let .liveTrip(key):
            LiveTripView(key: key)
        case let .liveTripMap(key):
            LiveTripMapPage(key: key)
        }
    }
}

/// Ouvre une route là où la vue est affichée (la pile de son onglet aujourd'hui).
/// Pour les boutons, menus et rappels ; les lignes de liste utilisent `NavigationLink(value:)`.
struct OpenRouteAction {
    let perform: (AppRoute) -> Void

    func callAsFunction(_ route: AppRoute) {
        perform(route)
    }
}

extension EnvironmentValues {
    @Entry var openRoute = OpenRouteAction { _ in }
}

extension View {
    /// À poser sur la racine d'une pile : elle sait alors afficher toutes les routes.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            AppRouteDestination(route: route)
        }
    }
}

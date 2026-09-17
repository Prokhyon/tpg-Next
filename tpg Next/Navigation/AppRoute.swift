//
//  AppRoute.swift
//  tpg Next
//

import SwiftUI
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
    /// Course d'une ligne. `event.lineName` est la ligne affichée.
    case line(event: StopEvent, currentStop: ShortStop?)
    case stopMap(quays: [Quay], sloid: String, name: String)
    case lineMap(events: [LineEvent], operatorName: String, event: StopEvent, currentStopSloid: String?)
    case trip(TripEvent)
    case tripMap(TripEvent)
    case settings
    case favoritesOrder
    case scheduledNotifications
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
        case let .line(event, currentStop):
            LineView(stopEvent: event, currentStop: currentStop, currentLine: event.lineName)
        case let .stopMap(quays, sloid, name):
            StopMapView(quays: quays, stopSloid: sloid, stopName: name)
        case let .lineMap(events, operatorName, event, currentStopSloid):
            LineMapView(lineEvents: events, lineName: event.lineName, operatorName: operatorName,
                        destination: event.destination, stopEvent: event, currentStopSloid: currentStopSloid)
        case let .trip(trip):
            FullTripView(fullTrip: trip)
        case let .tripMap(trip):
            TripMapView(tripEvent: trip)
        case .settings:
            SettingsView()
        case .favoritesOrder:
            FavoritesOrderView()
                .navigationTitle("Ordre des favoris")
        case .scheduledNotifications:
            ScheduledNotifications()
                .navigationTitle("Rappels prévus")
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

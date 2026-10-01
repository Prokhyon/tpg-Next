//
//  UpcomingTripsPublisher.swift
//  tpg Next
//
//  Laisse au widget « Prochain trajet » et à la montre les prochains trajets, avec leur temps
//  réel quand l'app le connaît.
//

import Foundation
import WidgetKit
import tpgNextFunc

enum UpcomingTripsPublisher {
    /// Au-delà, ce n'est plus un « prochain » trajet.
    private static let horizon: TimeInterval = 36 * 3600
    /// Le premier, et de quoi prendre le relais à son arrivée sans attendre l'app.
    private static let count = 4

    /// `saved` absent (tâche de fond) : les itinéraires enregistrés tels qu'enregistrés, sans
    /// leur état du jour.
    @MainActor
    static func publish(regular: RegularTripsModel, saved: SavedTripsModel?, now: Date = Date()) {
        var trips: [UpcomingTrip] = []

        for occurrence in regular.upcoming(after: now, days: 2) {
            guard let recipe = regular.trip(for: occurrence) else { continue }
            let trip = regular.displayedTrip(for: occurrence) ?? recipe.plannedTrip(for: occurrence)
            var alert: String?
            switch regular.state(of: occurrence) {
            case .found(let match, _): alert = RegularTripAlerts.changes(in: match).first
            case .notFound: alert = String(localized: "Plus aucun itinéraire à cette heure-là.")
            default: break
            }
            let badge = RegularTripStatusBadge.badge(for: regular.state(of: occurrence), isSavedTrip: false)
            if let upcoming = UpcomingTrip(trip: trip, id: occurrence.id, title: recipe.displayName, isRegular: true,
                                           alert: alert, badge: badge, url: URL(string: "tpgnext://regulartrips")) {
                trips.append(upcoming)
            }
        }

        for savedTrip in saved?.savedTrips ?? SavedTripsModel.storedTrips {
            let trip = saved?.displayedTrip(for: savedTrip) ?? savedTrip
            var alert: String?
            switch saved?.state(of: savedTrip) {
            case .found(let match, _) where match.kind == .alternative:
                alert = String(localized: "Cet itinéraire n'est plus proposé.")
            case .found(let match, _): alert = RegularTripAlerts.changes(in: match).first
            case .notFound: alert = String(localized: "Plus aucun itinéraire à cette heure-là.")
            default: break
            }
            let badge = RegularTripStatusBadge.badge(for: saved?.state(of: savedTrip), isSavedTrip: true)
            // Comme sur l'accueil : le titre dit le genre, la ligne du dessous le parcours.
            if let upcoming = UpcomingTrip(trip: trip, id: "saved-" + savedTrip.id,
                                           title: String(localized: "Itinéraire enregistré"), isRegular: false,
                                           alert: alert, badge: badge, url: URL(string: "tpgnext://savedtrips")) {
                trips.append(upcoming)
            }
        }

        let upcoming = trips
            .filter { $0.arrival > now && $0.leaving.timeIntervalSince(now) < horizon }
            .sorted { $0.leaving < $1.leaving }
            .prefix(count)
        if UpcomingTripsStorage.save(Array(upcoming)) {
            WidgetCenter.shared.reloadTimelines(ofKind: UpcomingTripsStorage.widgetKind)
        }
        // La montre les affiche dans « Mes trajets » ; rien n'est envoyé s'ils n'ont pas changé.
        if let data = try? JSONEncoder().encode(Array(upcoming)) {
            WatchContext.update(WatchContext.upcomingTripsKey, with: data)
        }
    }
}

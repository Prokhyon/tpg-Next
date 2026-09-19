//
//  TripLiveActivities.swift
//  tpg Next
//
//  Lance, met à jour et termine les activités en direct des trajets.
//

import Foundation
import ActivityKit
import Observation
import tpgNextFunc

/// Les trajets suivis en direct.
///
/// Sans serveur de notifications push, l'activité n'est mise à jour que par l'app : toutes les
/// minutes au premier plan, et quand iOS la réveille en arrière-plan. Entre deux mises à jour,
/// l'activité avance seule (comptes à rebours, barre de progression, étape déduite de l'heure).
@MainActor
@Observable
final class TripLiveActivities {
    static let shared = TripLiveActivities()

    /// Lancée automatiquement ce délai avant le départ d'un trajet régulier.
    static let autoStartLead: TimeInterval = 20 * 60

    /// Ce qu'il faut pour redemander le trajet à OJP.
    private struct Tracked: Codable {
        /// La recette : le trajet régulier, ou un itinéraire transformé en recette d'un jour.
        var recipe: RegularTrip
        var day: String
        var target: Date
        /// Le dernier itinéraire reçu, pour l'ouvrir depuis l'activité.
        var trip: TripEvent
        /// Vrai pour un trajet régulier : il passe par `RegularTripsModel` (alertes, cache).
        var isRegular: Bool

        var occurrence: RegularTripOccurrence { RegularTripOccurrence(trip: recipe, day: day, target: target) }
    }

    private static let store = CodableStore<[String: Tracked]>(key: "liveActivityTrips")
    /// Les trajets réguliers déjà lancés automatiquement : fermés par l'utilisateur, ils ne reviennent pas.
    private static let autoStartedStore = CodableStore<[String]>(key: "liveActivityAutoStarted")

    @ObservationIgnored private var tracked: [String: Tracked]
    @ObservationIgnored private var lastRequest: [String: Date] = [:]
    /// Les passages de chaque course, par `journeyRef`, redemandés au plus une fois par minute.
    @ObservationIgnored private var callsCache: [String: (calls: [TripActivityState.Call], fetched: Date)] = [:]
    /// Les clés des activités en cours, pour les menus.
    private(set) var activeKeys: Set<String> = []

    private init() {
        tracked = Self.store.load() ?? [:]
        syncActiveKeys()
    }

    var areEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func isTracking(_ key: String) -> Bool { activeKeys.contains(key) }

    /// Le dernier itinéraire connu du trajet suivi, pour l'ouvrir depuis l'activité.
    func trip(for key: String) -> TripEvent? { tracked[key]?.trip }

    static func key(for trip: TripEvent) -> String { "trip_" + trip.id }

    // MARK: Lancer et arrêter

    /// Suit un itinéraire quelconque : il devient la recette d'un jour, redemandée à OJP.
    func start(trip: TripEvent) {
        let recipe = RegularTrip(trip: trip, weekdays: Set(Weekday.allCases), reminderMinutes: nil, alertsEnabled: false)
        guard let target = trip.anchorDate(.departure, timetabled: true) else { return }
        let occurrence = RegularTripOccurrence(trip: recipe, day: Calendar.swissTransit.dayKey(for: target), target: target)
        start(key: Self.key(for: trip), tracked: Tracked(recipe: recipe, day: occurrence.day, target: target, trip: trip, isRegular: false),
              title: recipe.routeName, alert: nil)
    }

    /// Suit le trajet régulier du jour, avec l'itinéraire connu (du jour, ou prévu).
    func start(occurrence: RegularTripOccurrence, of recipe: RegularTrip, trip: TripEvent, match: RegularTripMatch?) {
        start(key: occurrence.id,
              tracked: Tracked(recipe: recipe, day: occurrence.day, target: occurrence.target, trip: trip, isRegular: true),
              title: recipe.displayName,
              alert: match.flatMap { RegularTripAlerts.changes(in: $0).first })
    }

    private func start(key: String, tracked entry: Tracked, title: String, alert: String?) {
        guard areEnabled, activity(for: key) == nil,
              let state = TripActivityState(trip: entry.trip, alert: alert),
              state.arrival > Date() else { return }
        let attributes = TripActivityAttributes(key: key, title: title,
                                                origin: entry.recipe.origin.name, destination: entry.recipe.destination.name)
        do {
            let activity = try Activity.request(attributes: attributes, content: content(for: state), pushType: nil)
            tracked[key] = entry
            save()
            syncActiveKeys()
            // Puis les passages des véhicules, pour dire où ils se trouvent.
            Task {
                if let detailed = await self.state(for: entry.trip, alert: alert) {
                    await activity.update(content(for: detailed))
                }
            }
        } catch {
            Log.notifications.error("Activité en direct non lancée : \(error.localizedDescription)")
        }
    }

    /// L'état de l'activité, avec les passages des courses pas encore terminées.
    private func state(for trip: TripEvent, alert: String?, now: Date = Date()) async -> TripActivityState? {
        var calls: [String: [TripActivityState.Call]] = [:]
        for leg in trip.vehicleLegs where !leg.journeyRef.isEmpty && (leg.alightDate ?? .distantFuture) > now {
            if let cached = callsCache[leg.journeyRef], now.timeIntervalSince(cached.fetched) < 60 {
                calls[leg.journeyRef] = cached.calls
            } else if let fetched = await TripActivityState.fetchCalls(for: leg) {
                callsCache[leg.journeyRef] = (fetched, now)
                calls[leg.journeyRef] = fetched
            } else if let cached = callsCache[leg.journeyRef] {
                calls[leg.journeyRef] = cached.calls
            }
        }
        return TripActivityState(trip: trip, alert: alert, calls: calls)
    }

    func stop(_ key: String) {
        guard let activity = activity(for: key) else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            forget(key)
        }
    }

    /// Lance l'activité des trajets réguliers qui partent bientôt. Une seule fois par trajet :
    /// fermée par l'utilisateur, elle ne revient pas.
    func startSoonDepartingTrips(of model: RegularTripsModel, now: Date = Date()) {
        guard areEnabled else { return }
        var started = Set(Self.autoStartedStore.load() ?? [])
        for occurrence in model.upcoming(after: now, days: 1) {
            guard occurrence.plannedDeparture.timeIntervalSince(now) < Self.autoStartLead,
                  !started.contains(occurrence.id),
                  let recipe = model.trip(for: occurrence), recipe.showsLiveActivity,
                  let trip = model.displayedTrip(for: occurrence) else { continue }
            var match: RegularTripMatch?
            if case .found(let found, _) = model.state(of: occurrence) { match = found }
            start(occurrence: occurrence, of: recipe, trip: trip, match: match)
            started.insert(occurrence.id)
        }
        // Les jours passés ne servent plus.
        let today = Calendar.swissTransit.dayKey(for: now)
        Self.autoStartedStore.save(started.filter { String($0.suffix(10)) >= today })
    }

    // MARK: Mettre à jour

    /// Un trajet régulier vient d'être relu (appelé par `RegularTripsModel`).
    func didResolve(_ key: String, match: RegularTripMatch) async {
        guard var entry = tracked[key] else { return }
        entry.trip = match.trip
        tracked[key] = entry
        save()
        guard let activity = activity(for: key),
              let state = await state(for: match.trip, alert: RegularTripAlerts.changes(in: match).first) else { return }
        await activity.update(content(for: state))
    }

    /// Relit les trajets suivis, termine ceux qui sont arrivés, et redessine les autres
    /// (l'étape affichée se déduit de l'heure du dessin).
    func refresh(model: RegularTripsModel, now: Date = Date()) async {
        syncActiveKeys()
        for activity in Activity<TripActivityAttributes>.activities where activity.activityState == .active || activity.activityState == .stale {
            let key = activity.attributes.key
            let state = activity.content.state
            // Arrivé : l'activité se termine sur son dernier écran, que le système retire
            // quelques minutes plus tard. (Rien ne peut la terminer tant que l'app ne tourne
            // pas : c'est ce réveil-là que `scheduleBackgroundRefresh` demande.)
            if now >= state.arrival {
                let dismissal = max(state.arrival.addingTimeInterval(3 * 60), now.addingTimeInterval(60))
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(dismissal))
                forget(key)
                continue
            }
            guard let entry = tracked[key] else { continue }
            if entry.isRegular {
                // Le modèle limite les requêtes, et rend le dernier trajet connu entre-temps.
                if let match = await model.resolve(entry.occurrence) {
                    await didResolve(key, match: match)
                    continue
                }
            } else if lastRequest[key].map({ now.timeIntervalSince($0) >= 60 }) ?? true {
                lastRequest[key] = now
                if let match = try? await RegularTripResolver.resolve(entry.recipe, on: entry.occurrence) {
                    await didResolve(key, match: match)
                    continue
                }
            }
            // Rien de neuf : redessiner quand même, pour passer à l'étape suivante.
            await activity.update(content(for: activity.content.state))
        }
    }

    /// L'échéance est le prochain changement d'étape : le système redessine l'activité à ce moment.
    private func content(for state: TripActivityState) -> ActivityContent<TripActivityState> {
        ActivityContent(state: state, staleDate: state.nextTransition(after: Date()))
    }

    // MARK: Suivi

    private func activity(for key: String) -> Activity<TripActivityAttributes>? {
        Activity<TripActivityAttributes>.activities.first {
            $0.attributes.key == key && ($0.activityState == .active || $0.activityState == .stale)
        }
    }

    private func forget(_ key: String) {
        if let trip = tracked[key]?.trip {
            trip.vehicleLegs.forEach { callsCache[$0.journeyRef] = nil }
        }
        tracked[key] = nil
        lastRequest[key] = nil
        save()
        syncActiveKeys()
    }

    /// L'utilisateur peut fermer une activité depuis l'écran verrouillé : la liste suit.
    private func syncActiveKeys() {
        let keys = Set(Activity<TripActivityAttributes>.activities
            .filter { $0.activityState == .active || $0.activityState == .stale }
            .map(\.attributes.key))
        if keys != activeKeys { activeKeys = keys }
        let stale = tracked.keys.filter { !keys.contains($0) }
        if !stale.isEmpty {
            stale.forEach { tracked[$0] = nil }
            save()
        }
    }

    private func save() { Self.store.save(tracked) }

    /// La première arrivée parmi les trajets suivis : après elle, l'activité doit se terminer.
    var nextActivityArrival: Date? {
        Activity<TripActivityAttributes>.activities
            .filter { $0.activityState == .active || $0.activityState == .stale }
            .map(\.content.state.arrival)
            .min()
    }
}

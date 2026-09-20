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

    /// Ce qu'il faut pour redemander à OJP ce qui est suivi.
    private enum Tracked: Codable {
        /// Un itinéraire (trajet régulier ou non) : redemandé par `OJPTripRequest`.
        case trip(TripTracking)
        /// Une course choisie sur la page d'un arrêt ou d'une ligne : redemandée par
        /// `OJPTripInfoRequest`, pour rester sur ce véhicule-là même s'il prend du retard.
        case journey(JourneyTracking)

        struct TripTracking: Codable {
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

        struct JourneyTracking: Codable {
            /// La course suivie (référence, ligne, exploitant, destination).
            var event: StopEvent
            var boardSloid: String
            var alightSloid: String
            var boardName: String
            var alightName: String
        }
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
    /// Ce que l'app affiche du trajet suivi (bandeau, page de suivi) : le même état que
    /// l'activité, gardé ici pour que les vues se mettent à jour avec lui.
    private(set) var live: [String: LiveTrip] = [:]

    /// Un trajet suivi, tel qu'affiché.
    struct LiveTrip {
        var attributes: TripActivityAttributes
        var state: TripActivityState
    }

    private init() {
        tracked = Self.store.load() ?? [:]
        syncActiveKeys()
    }

    /// Le trajet suivi à mettre en avant : celui qui arrive le plus tôt.
    var current: (key: String, trip: LiveTrip)? {
        live.min { $0.value.state.arrival < $1.value.state.arrival }.map { ($0.key, $0.value) }
    }

    var areEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func isTracking(_ key: String) -> Bool { activeKeys.contains(key) }

    /// L'écran à ouvrir quand on touche l'activité : l'itinéraire suivi, ou la course.
    func route(for key: String) -> AppRoute? {
        switch tracked[key] {
        case .trip(let entry): return .trip(entry.trip)
        case .journey(let entry):
            return .line(event: entry.event, currentStop: ShortStop(name: entry.boardName, sloid: entry.boardSloid))
        case nil: return nil
        }
    }

    static func key(for trip: TripEvent) -> String { "trip_" + trip.id }

    static func key(forJourney event: StopEvent, boardSloid: String) -> String {
        "journey_" + event.journeyRef + "_" + sloidHarmonizer(code: boardSloid)
    }

    // MARK: Lancer et arrêter

    /// Suit un itinéraire quelconque : il devient la recette d'un jour, redemandée à OJP.
    func start(trip: TripEvent) {
        let recipe = RegularTrip(trip: trip, weekdays: Set(Weekday.allCases), reminderMinutes: nil, alertsEnabled: false)
        guard let target = trip.anchorDate(.departure, timetabled: true) else { return }
        let occurrence = RegularTripOccurrence(trip: recipe, day: Calendar.swissTransit.dayKey(for: target), target: target)
        start(key: Self.key(for: trip),
              tracked: .trip(.init(recipe: recipe, day: occurrence.day, target: target, trip: trip, isRegular: false)),
              title: recipe.routeName, state: TripActivityState(trip: trip, alert: nil),
              origin: recipe.origin.name, destination: recipe.destination.name)
    }

    /// Suit le trajet régulier du jour, avec l'itinéraire connu (du jour, ou prévu).
    func start(occurrence: RegularTripOccurrence, of recipe: RegularTrip, trip: TripEvent, match: RegularTripMatch?) {
        let alert = match.flatMap { RegularTripAlerts.changes(in: $0).first }
        start(key: occurrence.id,
              tracked: .trip(.init(recipe: recipe, day: occurrence.day, target: occurrence.target, trip: trip, isRegular: true)),
              title: recipe.displayName, state: TripActivityState(trip: trip, alert: alert),
              origin: recipe.origin.name, destination: recipe.destination.name)
    }

    /// Suit une course choisie sur la page d'un arrêt ou d'une ligne, d'un arrêt à un autre.
    /// `events` sont les passages de la course, déjà chargés par l'écran qui appelle.
    func start(journey event: StopEvent, events: [LineEvent], operatorName: String, board: LineEvent, alight: LineEvent) {
        let key = Self.key(forJourney: event, boardSloid: board.sloid)
        let entry = Tracked.JourneyTracking(event: event, boardSloid: board.sloid, alightSloid: alight.sloid,
                                            boardName: board.stopPointName, alightName: alight.stopPointName)
        start(key: key, tracked: .journey(entry), title: "\(event.lineName) → \(shortStopName(event.destination))",
              state: state(for: entry, events: events, operatorName: operatorName),
              origin: board.stopPointName, destination: alight.stopPointName)
    }

    private func start(key: String, tracked entry: Tracked, title: String,
                       state: TripActivityState?, origin: String, destination: String) {
        guard areEnabled, activity(for: key) == nil, let state, state.arrival > Date() else { return }
        let attributes = TripActivityAttributes(key: key, title: title, origin: origin, destination: destination)
        do {
            let activity = try Activity.request(attributes: attributes, content: content(for: state), pushType: nil)
            tracked[key] = entry
            save()
            syncActiveKeys()
            record(attributes: attributes, state: state)
            // Pour un itinéraire, les passages des véhicules suivent : une requête de plus par
            // course, qui dit où chacun se trouve. Une course suivie les a déjà.
            if case .trip(let trip) = entry {
                Task {
                    if let detailed = await self.state(for: trip.trip, alert: state.alert) {
                        await activity.update(content(for: detailed))
                        self.record(attributes: attributes, state: detailed)
                    }
                }
            }
        } catch {
            Log.notifications.error("Activité en direct non lancée : \(error.localizedDescription)")
        }
    }

    /// L'état d'une course suivie, lu dans ses passages.
    private func state(for entry: Tracked.JourneyTracking, events: [LineEvent], operatorName: String) -> TripActivityState? {
        TripActivityState(journey: events, line: entry.event.lineName,
                          operatorName: operatorName.isEmpty ? entry.event.operatorName : operatorName,
                          transportType: entry.event.transportType, destination: entry.event.destination,
                          boardSloid: entry.boardSloid, alightSloid: entry.alightSloid)
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

    /// Garde l'état affiché dans l'app, et prévoit les alertes de montée, de descente et
    /// d'arrivée. Appelé à chaque fois que l'activité change.
    private func record(attributes: TripActivityAttributes, state: TripActivityState) {
        live[attributes.key] = LiveTrip(attributes: attributes, state: state)
        TripStepAlerts.schedule(key: attributes.key, title: attributes.title, state: state)
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
        guard case .trip(var entry) = tracked[key] else { return }
        entry.trip = match.trip
        tracked[key] = .trip(entry)
        save()
        guard let activity = activity(for: key),
              let state = await state(for: match.trip, alert: RegularTripAlerts.changes(in: match).first) else { return }
        await activity.update(content(for: state))
        record(attributes: activity.attributes, state: state)
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
            let mayRequest = lastRequest[key].map { now.timeIntervalSince($0) >= 60 } ?? true
            switch tracked[key] {
            case .trip(let entry) where entry.isRegular:
                // Le modèle limite les requêtes, et rend le dernier trajet connu entre-temps.
                if let match = await model.resolve(entry.occurrence) {
                    await didResolve(key, match: match)
                    continue
                }
            case .trip(let entry):
                if mayRequest {
                    lastRequest[key] = now
                    if let match = try? await RegularTripResolver.resolve(entry.recipe, on: entry.occurrence) {
                        await didResolve(key, match: match)
                        continue
                    }
                }
            case .journey(let entry):
                if mayRequest {
                    lastRequest[key] = now
                    if let refreshed = await refreshedState(of: entry) {
                        await activity.update(content(for: refreshed))
                        record(attributes: activity.attributes, state: refreshed)
                        continue
                    }
                }
            case nil:
                continue
            }
            // Rien de neuf : redessiner quand même, pour passer à l'étape suivante.
            await activity.update(content(for: activity.content.state))
            record(attributes: activity.attributes, state: activity.content.state)
        }
    }

    /// Redemande la course suivie et relit ses heures (`OJPTripInfoRequest`).
    private func refreshedState(of entry: Tracked.JourneyTracking) async -> TripActivityState? {
        let data: Data? = await withCheckedContinuation { continuation in
            fetchTransportJourney(with: entry.event) { continuation.resume(returning: $0) }
        }
        guard let data else { return nil }
        let result = parseJourneyEventsSync(from: data)
        return state(for: entry, events: result.events, operatorName: result.operatorName)
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
        if case .trip(let entry) = tracked[key] {
            entry.trip.vehicleLegs.forEach { callsCache[$0.journeyRef] = nil }
        }
        tracked[key] = nil
        lastRequest[key] = nil
        live[key] = nil
        TripStepAlerts.cancel(key: key)
        save()
        syncActiveKeys()
    }

    /// L'utilisateur peut fermer une activité depuis l'écran verrouillé : la liste suit.
    private func syncActiveKeys() {
        let activities = Activity<TripActivityAttributes>.activities
            .filter { $0.activityState == .active || $0.activityState == .stale }
        let keys = Set(activities.map(\.attributes.key))
        if keys != activeKeys { activeKeys = keys }
        // Au lancement, l'app retrouve ainsi les trajets suivis avant sa fermeture.
        for activity in activities where live[activity.attributes.key] == nil {
            live[activity.attributes.key] = LiveTrip(attributes: activity.attributes, state: activity.content.state)
        }
        for key in live.keys where !keys.contains(key) {
            live[key] = nil
            TripStepAlerts.cancel(key: key)
        }
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

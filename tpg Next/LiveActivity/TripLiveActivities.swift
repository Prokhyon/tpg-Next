//
//  TripLiveActivities.swift
//  tpg Next
//
//  Lance, met à jour et termine les activités en direct des trajets.
//

import Foundation
import ActivityKit
import CoreLocation
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
            /// Pourquoi la suite a été recalculée en route, s'il y a lieu : affiché tel quel.
            var change: String?

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
    @ObservationIgnored private var journeyCache: [String: (events: [LineEvent], fetched: Date)] = [:]
    /// Le tracé de chaque trajet suivi : il reste ici, l'activité n'en a pas besoin.
    @ObservationIgnored private var routes: [String: TripRoute] = [:]
    /// Le dernier état tiré d'OJP, avant correction par la position : c'est toujours lui qu'on
    /// corrige, sinon le décalage s'appliquerait deux fois.
    @ObservationIgnored private var baseStates: [String: TripActivityState] = [:]
    /// La position sert à savoir où en est le véhicule qu'on occupe. Plus précise qu'ailleurs
    /// dans l'app : elle est projetée sur un parcours.
    @ObservationIgnored private lazy var locationManager = LocationManager(accuracy: kCLLocationAccuracyNearestTenMeters)
    @ObservationIgnored private var lastLocation: CLLocation?
    @ObservationIgnored private var isLocating = false
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
              state: state(for: entry, key: key, events: events, operatorName: operatorName),
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
                    if let detailed = await self.state(for: trip.trip, key: key, alert: state.alert) {
                        await self.push(base: detailed, to: activity)
                    }
                }
            }
        } catch {
            Log.notifications.error("Activité en direct non lancée : \(error.localizedDescription)")
        }
    }

    /// L'état d'une course suivie, lu dans ses passages, et son tracé.
    private func state(for entry: Tracked.JourneyTracking, key: String, events: [LineEvent],
                       operatorName: String) -> TripActivityState? {
        routes[key] = TripRoute(legs: [TripRoute.points(from: events, boardSloid: entry.boardSloid,
                                                        alightSloid: entry.alightSloid)])
        return TripActivityState(journey: events, line: entry.event.lineName,
                          operatorName: operatorName.isEmpty ? entry.event.operatorName : operatorName,
                          transportType: entry.event.transportType, destination: entry.event.destination,
                          boardSloid: entry.boardSloid, alightSloid: entry.alightSloid)
    }

    /// L'état de l'activité, avec les passages des courses pas encore terminées. Les mêmes
    /// passages donnent le tracé, gardé à part pour la correction par la position.
    private func state(for trip: TripEvent, key: String, alert: String?, now: Date = Date()) async -> TripActivityState? {
        var events: [String: [LineEvent]] = [:]
        var calls: [String: [TripActivityState.Call]] = [:]
        for leg in trip.vehicleLegs where !leg.journeyRef.isEmpty && (leg.alightDate ?? .distantFuture) > now {
            if let cached = journeyCache[leg.journeyRef], now.timeIntervalSince(cached.fetched) < 60 {
                events[leg.journeyRef] = cached.events
            } else if let fetched = await TripActivityState.fetchJourney(for: leg) {
                journeyCache[leg.journeyRef] = (fetched, now)
                events[leg.journeyRef] = fetched
            } else if let cached = journeyCache[leg.journeyRef] {
                events[leg.journeyRef] = cached.events
            }
            if let found = events[leg.journeyRef] {
                let legCalls = TripActivityState.calls(from: found, for: leg)
                if !legCalls.isEmpty { calls[leg.journeyRef] = legCalls }
            }
        }
        // Le tracé suit les étapes de l'état : même filtre que `TripActivityState(trip:)`, pour
        // que l'étape en cours désigne le même véhicule de part et d'autre.
        routes[key] = TripRoute(legs: trip.vehicleLegs.compactMap { leg in
            guard leg.boardDate != nil, leg.alightDate != nil else { return nil }
            let points = TripRoute.points(from: events[leg.journeyRef] ?? [], for: leg)
            return points.count >= 2 ? points : TripRoute.endpoints(of: leg)
        })
        // Les heures des courses, relues à la source : le véhicule prend du retard sans qu'on
        // ait à redemander tout l'itinéraire.
        var trip = trip
        trip.legs = trip.legs.map { leg in
            guard let passages = events[leg.journeyRef] else { return leg }
            func time(at sloid: String) -> String? {
                let wanted = sloidHarmonizer(code: sloid)
                let event = passages.first { sloidHarmonizer(code: $0.sloid.isEmpty ? $0.stopPlaceRef : $0.sloid) == wanted }
                return (event?.estimatedTime).flatMap { $0.isEmpty ? nil : $0 }
            }
            var leg = leg
            if let board = time(at: leg.legBoardStopId) { leg.legBoardEstimatedTime = board }
            if let alight = time(at: leg.legAlightStopId) { leg.legAlightEstimatedTime = alight }
            return leg
        }
        return TripActivityState(trip: trip, alert: alert, calls: calls)
    }

    /// Garde l'état affiché dans l'app, et prévoit les alertes de montée, de descente et
    /// d'arrivée. Appelé à chaque fois que l'activité change.
    private func record(attributes: TripActivityAttributes, state: TripActivityState) {
        live[attributes.key] = LiveTrip(attributes: attributes, state: state)
        TripStepAlerts.schedule(key: attributes.key, title: attributes.title, state: state)
    }

    // MARK: La position

    /// Met l'activité à jour avec l'état d'OJP, corrigé par la position quand elle dit quelque
    /// chose de fiable.
    private func push(base state: TripActivityState, to activity: Activity<TripActivityAttributes>,
                      now: Date = Date()) async {
        let key = activity.attributes.key
        baseStates[key] = state
        let corrected = await adjusted(state, key: key, now: now)
        await activity.update(content(for: corrected))
        record(attributes: activity.attributes, state: corrected)
    }

    /// L'état corrigé par la position du voyageur, quand il est dans le véhicule en cours.
    ///
    /// Les deux sources se complètent : OJP donne l'horaire, la position dit l'avance ou le
    /// retard du véhicule qu'on occupe, y compris entre deux requêtes. Un écart trop grand
    /// trahit une position qui ne parle pas de ce véhicule-là (trajet suivi de loin, tracé
    /// grossier) : OJP l'emporte alors, et rien n'est corrigé.
    private func adjusted(_ state: TripActivityState, key: String, now: Date) async -> TripActivityState {
        guard case .riding(let index) = state.phase(at: now) else { return state }
        let points = routes[key]?.points(of: index) ?? []
        guard points.count >= 2, let location = await currentLocation(now: now) else { return state }
        guard let fix = TripPositionEstimator.fix(on: points, latitude: location.coordinate.latitude,
                                                  longitude: location.coordinate.longitude,
                                                  accuracy: location.horizontalAccuracy, now: now) else { return state }
        Log.location.debug("Trajet suivi corrigé de \(Int(fix.offset)) s, à \(Int(fix.distance)) m du parcours")
        return state.adjusted(leg: index, by: fix.offset, now: now)
    }

    /// La position du moment, au plus une par minute, et seulement si elle est déjà autorisée :
    /// le suivi n'a pas à la réclamer, l'horaire d'OJP suffit sans elle.
    private func currentLocation(now: Date) async -> CLLocation? {
        // Pendant un suivi, les positions arrivent d'elles-mêmes : rien à demander.
        if let live = TripBackgroundLocation.shared.lastLocation,
           now.timeIntervalSince(live.timestamp) < 60 { return live }
        if let last = lastLocation, now.timeIntervalSince(last.timestamp) < 45 { return last }
        guard !isLocating, let status = locationManager.locationStatus,
              status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        isLocating = true
        let location: CLLocation? = await withCheckedContinuation { continuation in
            locationManager.requestLocation { continuation.resume(returning: $0) }
        }
        isLocating = false
        // Une position trop vague projetée sur un parcours ne dit rien de bon.
        guard let location, location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= TripPositionEstimator.maximumAccuracy * 2 else { return nil }
        lastLocation = location
        return location
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
    func didResolve(_ key: String, match: RegularTripMatch, now: Date = Date()) async {
        guard case .trip(var entry) = tracked[key] else { return }
        // Parti : un itinéraire recalculé depuis le point de départ renverrait le voyageur en
        // arrière. Seule la suite peut encore changer, et c'est `followedState` qui s'en charge.
        if hasLeft(key, now: now) { return }
        entry.trip = match.trip
        tracked[key] = .trip(entry)
        save()
        guard let activity = activity(for: key),
              let state = await state(for: match.trip, key: key,
                                      alert: RegularTripAlerts.changes(in: match).first) else { return }
        await push(base: state, to: activity)
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
            // Déjà parti : l'itinéraire est figé. On relit les heures de ses courses, et si une
            // correspondance tombe, la suite est redemandée depuis l'arrêt où l'on descend.
            if case .trip(let entry) = tracked[key], hasLeft(key, now: now) {
                if mayRequest {
                    lastRequest[key] = now
                    if let followed = await followedState(of: entry, key: key, now: now) {
                        await push(base: followed, to: activity, now: now)
                        continue
                    }
                }
                if let base = baseStates[key] {
                    await push(base: base, to: activity, now: now)
                } else {
                    await activity.update(content(for: state))
                    record(attributes: activity.attributes, state: state)
                }
                continue
            }
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
                    if let refreshed = await refreshedState(of: entry, key: key) {
                        await push(base: refreshed, to: activity, now: now)
                        continue
                    }
                }
            case nil:
                continue
            }
            // Rien de neuf : redessiner quand même, pour passer à l'étape suivante et suivre
            // la position.
            if let base = baseStates[key] {
                await push(base: base, to: activity, now: now)
            } else {
                await activity.update(content(for: activity.content.state))
                record(attributes: activity.attributes, state: activity.content.state)
            }
        }
    }

    /// Vrai si le voyageur est déjà parti sur ce trajet.
    private func hasLeft(_ key: String, now: Date) -> Bool {
        (baseStates[key] ?? live[key]?.state)?.hasLeft(at: now) ?? false
    }

    /// L'état d'un itinéraire déjà commencé : ses heures relues, et sa suite réparée si elle ne
    /// tient plus.
    ///
    /// Ce qui est parcouru ne bouge plus. Si la descente arrive trop tard pour la correspondance,
    /// un nouvel itinéraire est demandé depuis cet arrêt-là, à cette heure-là, et recollé à la
    /// suite : le voyageur garde son avance, et lit pourquoi le trajet prévu ne tient plus.
    private func followedState(of entry: Tracked.TripTracking, key: String, now: Date) async -> TripActivityState? {
        guard var state = await state(for: entry.trip, key: key, alert: entry.change, now: now) else { return nil }
        guard let broken = state.brokenTransfer() else { return state }
        let leg = state.legs[broken]
        let stop = shortStopName(leg.alightName)
        let planned = entry.trip.trackedLegs
        guard planned.indices.contains(broken),
              let latitude = Double(planned[broken].legAlightLatitude),
              let longitude = Double(planned[broken].legAlightLongitude) else { return state }
        let alightLeg = planned[broken]
        let from = RegularTripPlace(name: alightLeg.legAlightStopName, sloid: alightLeg.legAlightStopId,
                                    coordinates: Coordinates(lon: longitude, lat: latitude))
        let tail = await TripReplanner.tail(from: from,
                                            at: leg.alight.addingTimeInterval(TripActivityState.minimumTransfer),
                                            to: entry.recipe.destination)
        guard let tail else {
            state.alert = String(localized: "Correspondance manquée à \(stop) · aucune suite trouvée")
            return state
        }
        var entry = entry
        entry.trip = entry.trip.splicing(after: alightLeg, with: tail)
        entry.change = String(localized: "Correspondance manquée à \(stop) · suite recalculée")
        self.tracked[key] = .trip(entry)
        save()
        Log.network.info("Suite du trajet recalculée depuis \(stop)")
        return await self.state(for: entry.trip, key: key, alert: entry.change, now: now) ?? state
    }

    /// Redemande la course suivie et relit ses heures (`OJPTripInfoRequest`).
    private func refreshedState(of entry: Tracked.JourneyTracking, key: String) async -> TripActivityState? {
        let data: Data? = await withCheckedContinuation { continuation in
            fetchTransportJourney(with: entry.event) { continuation.resume(returning: $0) }
        }
        guard let data else { return nil }
        let result = parseJourneyEventsSync(from: data)
        return state(for: entry, key: key, events: result.events, operatorName: result.operatorName)
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
            entry.trip.vehicleLegs.forEach { journeyCache[$0.journeyRef] = nil }
        }
        tracked[key] = nil
        lastRequest[key] = nil
        routes[key] = nil
        baseStates[key] = nil
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
        // L'app doit tourner pour mettre les activités à jour : tant qu'un trajet est suivi,
        // la session d'arrière-plan l'y aide.
        if keys.isEmpty {
            TripBackgroundLocation.shared.stop()
        } else {
            TripBackgroundLocation.shared.start()
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

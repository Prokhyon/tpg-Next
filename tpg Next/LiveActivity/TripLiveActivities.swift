//
//  TripLiveActivities.swift
//  tpg Next
//
//  Lance, met à jour et termine les activités en direct des trajets.
//

import Foundation
import ActivityKit
import CoreLocation
import UIKit
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
            /// L'étape dans laquelle le voyageur a confirmé être monté, quand la correspondance
            /// était serrée : on ne lui repose pas la question.
            var boardedLeg: Int?

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

    /// Une correspondance serrée dont ni l'horaire ni la position ne disent si elle a été
    /// attrapée : le voyageur tranche depuis la page du trajet.
    struct DoubtfulTransfer: Hashable {
        /// L'étape d'où l'on descend.
        var leg: Int
        var stop: String
        var line: String
    }

    /// Une autre suite possible, quand le trajet a dû être recalculé en route.
    struct ReplanOption: Identifiable, Hashable {
        var trip: TripEvent
        /// L'étape après laquelle la recoller.
        var after: TripLeg
        var line: String
        var operatorName: String
        var departure: Date
        var arrival: Date

        var id: String { trip.id }
    }

    /// Les correspondances en suspens, par trajet.
    private(set) var doubtful: [String: DoubtfulTransfer] = [:]
    /// Les suites proposées après un recalcul, par trajet, la plus tôt arrivée en tête.
    private(set) var alternatives: [String: [ReplanOption]] = [:]
    /// Celle qui est appliquée, parmi elles.
    private(set) var chosenAlternative: [String: String] = [:]

    private init() {
        tracked = Self.store.load() ?? [:]
        syncActiveKeys()
        // La réponse donnée depuis l'écran verrouillé : l'intention tourne dans le processus de
        // l'app, mais son code est aussi compilé dans le widget et ne peut pas appeler ceci.
        NotificationCenter.default.addObserver(forName: .tripBoardingAnswer, object: nil, queue: .main) { note in
            guard let key = note.userInfo?[TripBoardingAnswer.key] as? String,
                  let aboard = note.userInfo?[TripBoardingAnswer.aboard] as? Bool else { return }
            Task { @MainActor in
                if aboard {
                    TripLiveActivities.shared.confirmBoarded(key)
                } else {
                    TripLiveActivities.shared.confirmMissed(key)
                }
            }
        }
    }

    /// Le trajet suivi à mettre en avant : celui qui arrive le plus tôt.
    var current: (key: String, trip: LiveTrip)? {
        live.min { $0.value.state.arrival < $1.value.state.arrival }.map { ($0.key, $0.value) }
    }

    var areEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Le suivi exige la localisation : sans elle, rien ne garde l'app éveillée une fois
    /// quittée (`TripBackgroundLocation`), et l'activité se figerait sur des heures fausses.
    /// Le statut vient du délégué de `locationManager`, pas d'un `CLLocationManager()` neuf :
    /// sa lecture attend le service de localisation sur le fil principal, et l'app restait figée
    /// (chaque minute, depuis `startSoonDepartingSavedTrips`) quand il ne répondait pas.
    var hasLocation: Bool {
        let status = locationManager.locationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// Dit pourquoi le suivi ne démarre pas, et demande la localisation si elle ne l'a jamais été.
    func askForLocation() {
        if locationManager.locationStatus == .notDetermined {
            locationManager.requestLocationAuthorization()
            NotificationConfirmationViewModel.shared.show(
                message: String(localized: "Le suivi en direct a besoin de votre position. Autorisez-la, puis relancez le suivi."),
                error: true)
        } else {
            NotificationConfirmationViewModel.shared.show(
                message: String(localized: "Le suivi en direct a besoin de votre position pour rester à jour, app fermée.\nAutorisez-la dans les réglages du téléphone"),
                error: true)
        }
    }

    /// Vrai si ce trajet est suivi et que le voyageur est déjà parti : l'activité s'en occupe.
    func isUnderway(_ key: String, now: Date = Date()) -> Bool {
        activity(for: key) != nil && hasLeft(key, now: now)
    }

    func isTracking(_ key: String) -> Bool { activeKeys.contains(key) }

    static func key(for trip: TripEvent) -> String { "trip_" + trip.id }

    static func key(forJourney event: StopEvent, boardSloid: String) -> String {
        "journey_" + event.journeyRef + "_" + sloidHarmonizer(code: boardSloid)
    }

    /// La course suivie en ce moment, quel que soit l'arrêt où l'on y monte : la page d'une
    /// ligne ne sait pas lequel a été choisi. `nil` si elle n'est pas suivie.
    func trackedKey(forJourney journeyRef: String) -> String? {
        guard !journeyRef.isEmpty else { return nil }
        return activeKeys.first { $0.hasPrefix("journey_" + journeyRef + "_") }
    }

    // MARK: Lancer et arrêter

    /// Un itinéraire avec un bus à la demande (tpg flex) ne se suit pas : sans horaire fixe, ni
    /// le décompte ni les alertes de montée ne voudraient rien dire.
    static func canTrack(_ trip: TripEvent) -> Bool {
        !trip.hasOnDemandLeg
    }

    /// Suit un itinéraire quelconque : il devient la recette d'un jour, redemandée à OJP.
    func start(trip: TripEvent) {
        guard Self.canTrack(trip) else { return }
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
        guard Self.canTrack(trip) else { return }
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
        guard hasLocation else {
            askForLocation()
            return
        }
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
        func passage(of sloid: String, in passages: [LineEvent]) -> LineEvent? {
            let wanted = sloidHarmonizer(code: sloid)
            return passages.first { sloidHarmonizer(code: $0.sloid.isEmpty ? $0.stopPlaceRef : $0.sloid) == wanted }
        }
        var trip = trip
        trip.legs = trip.legs.map { leg in
            guard let passages = events[leg.journeyRef] else { return leg }
            var leg = leg
            if let board = passage(of: leg.legBoardStopId, in: passages)?.estimatedTime, !board.isEmpty {
                leg.legBoardEstimatedTime = board
            }
            if let alight = passage(of: leg.legAlightStopId, in: passages)?.estimatedTime, !alight.isEmpty {
                leg.legAlightEstimatedTime = alight
            }
            return leg
        }
        var state = TripActivityState(trip: trip, alert: alert, calls: calls)
        // Un véhicule qui ne s'arrête plus là où l'on devait monter : la suite ne tient pas.
        for (index, leg) in trip.trackedLegs.enumerated() {
            guard let passages = events[leg.journeyRef],
                  passage(of: leg.legBoardStopId, in: passages)?.isCancelled == true,
                  state?.legs.indices.contains(index) == true else { continue }
            state?.legs[index].cancelled = true
        }
        return state
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
        let alert = alertConfiguration(for: corrected, previous: live[key]?.state, key: key,
                                       title: activity.attributes.title, now: now)
        await activity.update(content(for: corrected), alertConfiguration: alert)
        record(attributes: activity.attributes, state: corrected)
    }

    /// Ce qui mérite d'allumer l'écran : une correspondance à trancher, ou un changement annoncé
    /// par l'activité (retard, correspondance perdue, suite recalculée). Avant le départ d'un
    /// trajet régulier, ses propres notifications préviennent déjà (`RegularTripAlerts`).
    private func alertConfiguration(for state: TripActivityState, previous: TripActivityState?,
                                    key: String, title: String, now: Date) -> AlertConfiguration? {
        guard let previous else { return nil }
        let body: String
        if let question = state.question, previous.question == nil {
            body = String(localized: "Correspondance serrée à \(question.stop) · Êtes-vous monté dans le \(question.line) ?")
        } else if let change = state.alert, change != previous.alert {
            if case .trip(let entry) = tracked[key], entry.isRegular, !state.hasLeft(at: now) { return nil }
            body = change
        } else {
            return nil
        }
        return AlertConfiguration(title: LocalizedStringResource(stringLiteral: title),
                                  body: LocalizedStringResource(stringLiteral: body),
                                  sound: .named("tpgNextNotificationSound.caf"))
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
        // Une activité ne démarre qu'app au premier plan : essayer en arrière-plan échouerait,
        // et marquerait le trajet comme lancé.
        guard areEnabled, hasLocation, UIApplication.shared.applicationState == .active,
              RegularTripAlerts.isEnabledOnThisDevice else { return }
        var started = Set(Self.autoStartedStore.load() ?? [])
        for occurrence in model.upcoming(after: now, days: 1) {
            guard occurrence.plannedDeparture.timeIntervalSince(now) < Self.autoStartLead,
                  !started.contains(occurrence.id),
                  let recipe = model.trip(for: occurrence), recipe.showsLiveActivity,
                  let trip = model.displayedTrip(for: occurrence) else { continue }
            var match: RegularTripMatch?
            if case .found(let found, _) = model.state(of: occurrence) { match = found }
            start(occurrence: occurrence, of: recipe, trip: trip, match: match)
            if isTracking(occurrence.id) { started.insert(occurrence.id) }
        }
        // Les jours passés ne servent plus.
        let today = Calendar.swissTransit.dayKey(for: now)
        Self.autoStartedStore.save(started.filter { String($0.suffix(10)) >= today })
    }

    /// Lance le suivi des itinéraires enregistrés qui partent bientôt, si l'utilisateur l'a choisi
    /// (`SavedTripAutoTracking`). Une seule fois par itinéraire : fermé, il ne revient pas.
    func startSoonDepartingSavedTrips(of model: SavedTripsModel, now: Date = Date()) {
        let minutes = SavedTripAutoTracking.leadMinutes
        guard areEnabled, hasLocation, minutes > 0, UIApplication.shared.applicationState == .active else { return }
        var started = Set(Self.autoStartedStore.load() ?? [])
        for saved in model.savedTrips {
            let trip = model.displayedTrip(for: saved)
            guard let departure = trip.leavingDate ?? trip.startDate,
                  departure.timeIntervalSince(now) < TimeInterval(minutes * 60),
                  (trip.endDate ?? departure) > now else { continue }
            // Le jour à la fin : c'est lui qui sert au ménage ci-dessous.
            let startedKey = "saved_\(saved.id)_\(Calendar.swissTransit.dayKey(for: departure))"
            guard !started.contains(startedKey) else { continue }
            start(trip: trip)
            if isTracking(Self.key(for: trip)) { started.insert(startedKey) }
        }
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
                if let match = await model.resolve(entry.occurrence, known: entry.trip) {
                    await didResolve(key, match: match)
                    continue
                }
            case .trip(let entry):
                if mayRequest {
                    lastRequest[key] = now
                    if let match = try? await RegularTripResolver.resolve(entry.recipe, on: entry.occurrence, known: entry.trip) {
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
    /// Ce qui est parcouru ne bouge plus. Une correspondance perdue fait redemander la suite
    /// depuis l'arrêt de descente ; une correspondance serrée attend d'être tranchée, par la
    /// position du voyageur ou par le voyageur lui-même.
    private func followedState(of entry: Tracked.TripTracking, key: String, now: Date) async -> TripActivityState? {
        guard var state = await state(for: entry.trip, key: key, alert: entry.change, now: now) else { return nil }
        switch state.transferProblem() {
        case .held:
            doubtful[key] = nil
            return state
        case .doubtful(let index):
            // Le voyageur a déjà dit qu'il était monté : on n'y revient pas.
            if (entry.boardedLeg ?? -1) > index {
                doubtful[key] = nil
                return state
            }
            switch await aboard(leg: index + 1, key: key, state: state, now: now) {
            case true:
                var entry = entry
                entry.boardedLeg = index + 1
                tracked[key] = .trip(entry)
                save()
                doubtful[key] = nil
                return state
            case false:
                return await replanned(entry, key: key, state: state, after: index, now: now)
            default:
                let stop = shortStopName(state.legs[index].alightName)
                let line = state.legs[index + 1].line
                doubtful[key] = DoubtfulTransfer(leg: index, stop: stop, line: line)
                // L'activité en direct pose la question sur son propre écran, avec ses boutons.
                state.question = TripActivityState.Question(stop: stop, line: line)
                return state
            }
        case .missed(let index):
            doubtful[key] = nil
            return await replanned(entry, key: key, state: state, after: index, now: now)
        }
    }

    /// Redemande la suite depuis l'arrêt de descente, la recolle, et garde les autres
    /// propositions sous la main : la meilleure s'applique, le voyageur peut en préférer une autre.
    private func replanned(_ entry: Tracked.TripTracking, key: String, state: TripActivityState,
                           after index: Int, now: Date) async -> TripActivityState {
        var state = state
        let stop = shortStopName(state.legs[index].alightName)
        let planned = entry.trip.trackedLegs
        guard planned.indices.contains(index),
              let latitude = Double(planned[index].legAlightLatitude),
              let longitude = Double(planned[index].legAlightLongitude) else { return state }
        let alightLeg = planned[index]
        let from = RegularTripPlace(name: alightLeg.legAlightStopName, sloid: alightLeg.legAlightStopId,
                                    coordinates: Coordinates(lon: longitude, lat: latitude))
        let needed = state.legs[index].transferTime.map { TimeInterval($0) } ?? TripActivityState.minimumTransfer
        let leaving = max(now, state.legs[index].alight).addingTimeInterval(needed)
        let tails = await TripReplanner.tails(from: from, at: leaving, to: entry.recipe.destination,
                                              avoiding: entry.recipe.linesToAvoid)
        // Le motif, tel qu'il s'affichera : c'est la seule explication que le voyageur aura.
        let cancelled = state.legs.indices.contains(index + 1) && state.legs[index + 1].cancelled == true
        guard let best = tails.first else {
            state.alert = cancelled
                ? String(localized: "Le \(state.legs[index + 1].line) ne passe plus · aucune suite trouvée depuis \(stop)")
                : String(localized: "Correspondance manquée à \(stop) · aucune suite trouvée")
            return state
        }
        var entry = entry
        entry.trip = entry.trip.splicing(after: alightLeg, with: best)
        entry.change = cancelled
            ? String(localized: "Le \(state.legs[index + 1].line) ne passe plus · suite recalculée depuis \(stop)")
            : String(localized: "Correspondance manquée à \(stop) · suite recalculée")
        entry.boardedLeg = nil
        tracked[key] = .trip(entry)
        save()
        // Toutes les suites restent proposées : celle qui s'applique n'est qu'une par défaut.
        alternatives[key] = tails.compactMap { option(from: $0, after: alightLeg) }
            .sorted { $0.arrival < $1.arrival }
        chosenAlternative[key] = best.id
        Log.network.info("Suite du trajet recalculée depuis \(stop)")
        return await self.state(for: entry.trip, key: key, alert: entry.change, now: now) ?? state
    }

    private func option(from trip: TripEvent, after leg: TripLeg) -> ReplanOption? {
        guard let first = trip.trackedLegs.first, let departure = first.boardDate,
              let arrival = trip.endDate else { return nil }
        return ReplanOption(trip: trip, after: leg, line: first.publishedLineName,
                            operatorName: first.legOperator, departure: departure, arrival: arrival)
    }

    /// Le voyageur est-il dans ce véhicule ? `nil` tant qu'on ne peut pas le dire.
    private func aboard(leg index: Int, key: String, state: TripActivityState, now: Date) async -> Bool? {
        guard state.legs.indices.contains(index) else { return nil }
        // Avant que le véhicule ne s'en aille, la position ne prouve rien : tout le monde est
        // encore à l'arrêt.
        guard now >= state.legs[index].board.addingTimeInterval(60) else { return nil }
        let points = routes[key]?.points(of: index) ?? []
        guard points.count >= 2, let location = await currentLocation(now: now) else { return nil }
        return TripPositionEstimator.isAboard(on: points, latitude: location.coordinate.latitude,
                                              longitude: location.coordinate.longitude,
                                              accuracy: location.horizontalAccuracy, now: now)
    }

    // MARK: Ce que le voyageur tranche

    /// L'étape dont la correspondance est en suspens. Relue dans l'état quand elle n'est plus
    /// en mémoire : répondre depuis l'écran verrouillé peut relancer l'app par ce seul chemin.
    private func doubtfulLeg(_ key: String) -> Int? {
        if let doubt = doubtful[key] { return doubt.leg }
        guard let state = baseStates[key] ?? live[key]?.state,
              case .doubtful(let index) = state.transferProblem() else { return nil }
        return index
    }

    /// « Je suis monté » : la correspondance serrée est attrapée, le trajet reste tel quel.
    func confirmBoarded(_ key: String) {
        guard case .trip(var entry) = tracked[key], let leg = doubtfulLeg(key) else { return }
        entry.boardedLeg = leg + 1
        entry.change = nil
        tracked[key] = .trip(entry)
        save()
        doubtful[key] = nil
        Task { await rebuild(key) }
    }

    /// « Je l'ai manqué » : la suite est redemandée tout de suite.
    func confirmMissed(_ key: String) {
        guard case .trip(let entry) = tracked[key], let leg = doubtfulLeg(key) else { return }
        doubtful[key] = nil
        Task {
            let now = Date()
            guard let state = await self.state(for: entry.trip, key: key, alert: nil, now: now),
                  let activity = self.activity(for: key) else { return }
            let repaired = await self.replanned(entry, key: key, state: state, after: leg, now: now)
            await self.push(base: repaired, to: activity, now: now)
        }
    }

    /// Prend une autre des suites proposées.
    func choose(_ option: ReplanOption, for key: String) {
        guard case .trip(var entry) = tracked[key], chosenAlternative[key] != option.id else { return }
        entry.trip = entry.trip.splicing(after: option.after, with: option.trip)
        tracked[key] = .trip(entry)
        save()
        chosenAlternative[key] = option.id
        Task { await rebuild(key) }
    }

    /// Redessine l'activité après un choix du voyageur.
    private func rebuild(_ key: String) async {
        guard case .trip(let entry) = tracked[key], let activity = activity(for: key),
              let state = await state(for: entry.trip, key: key, alert: entry.change) else { return }
        await push(base: state, to: activity)
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
        doubtful[key] = nil
        alternatives[key] = nil
        chosenAlternative[key] = nil
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
        syncBackgroundLocation()
    }

    /// Vrai une fois `locationStatus` observé, pour ne pas empiler les observations.
    @ObservationIgnored private var observesLocationStatus = false

    /// L'app doit tourner pour mettre les activités à jour : tant qu'un trajet est suivi,
    /// la session d'arrière-plan l'y aide.
    private func syncBackgroundLocation() {
        if activeKeys.isEmpty {
            TripBackgroundLocation.shared.stop()
        } else {
            observeLocationStatus()
            TripBackgroundLocation.shared.start(locationAuthorized: hasLocation)
        }
    }

    /// Au lancement, le délégué ne donne l'autorisation qu'un instant après le premier passage
    /// dans `syncBackgroundLocation` : on y revient à chaque changement, sans quoi la session
    /// d'un trajet suivi avant la fermeture de l'app ne se rouvrirait pas.
    private func observeLocationStatus() {
        guard !observesLocationStatus else { return }
        observesLocationStatus = true
        withObservationTracking {
            _ = locationManager.locationStatus
        } onChange: { [weak self] in
            // Appelé avant le changement : la nouvelle valeur se lit au tour suivant.
            Task { @MainActor in
                guard let self else { return }
                self.observesLocationStatus = false
                self.syncBackgroundLocation()
            }
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

//
//  RegularTripsModel.swift
//  tpg Next
//
//  Les trajets réguliers enregistrés, et leur état du jour auprès d'OJP.
//

import Foundation
import Observation
import BackgroundTasks
import tpgNextFunc

@Observable
final class RegularTripsModel {
    /// Partagée : la tâche de fond et les rappels passent par la même instance que les écrans.
    static let shared = RegularTripsModel()
    static let backgroundTaskID = "com.loristhomas.tpgNext.regularTrips"
    private static let store = CodableStore<[RegularTrip]>(key: "regularTrips")

    /// Un trajet est redemandé à OJP quand son départ approche : avant, le temps réel est vide.
    static let liveWindow: TimeInterval = 3 * 3600
    /// Au plus une requête par trajet et par minute.
    private static let minimumInterval: TimeInterval = 60

    /// Le trajet du jour, retrouvé auprès d'OJP.
    enum LiveState: Equatable {
        case loading
        case found(RegularTripMatch, updated: Date)
        /// Aucun itinéraire ne convient (pas de service ce jour-là, par exemple).
        case notFound
        case failed
    }

    var regularTrips: [RegularTrip] {
        didSet {
            Self.store.save(regularTrips)
            RegularTripAlerts.scheduleReminders(for: self)
        }
    }

    /// Par `RegularTripOccurrence.id`.
    private(set) var live: [String: LiveState] = [:]
    @ObservationIgnored private var lastRequest: [String: Date] = [:]

    init() {
        regularTrips = Self.store.load() ?? []
    }

    /// Pour les aperçus : rien n'est lu ni enregistré.
    init(previewTrips: [RegularTrip], live: [String: LiveState] = [:]) {
        regularTrips = previewTrips
        self.live = live
    }

    // MARK: Modifier

    func save(_ trip: RegularTrip) {
        if let index = regularTrips.firstIndex(where: { $0.id == trip.id }) {
            regularTrips[index] = trip
        } else {
            regularTrips.append(trip)
        }
        // Heure, jours ou lignes ont pu changer : l'état du jour ne vaut plus.
        live = live.filter { !$0.key.hasPrefix(trip.id.uuidString) }
    }

    func remove(_ trip: RegularTrip) {
        regularTrips.removeAll { $0.id == trip.id }
        live = live.filter { !$0.key.hasPrefix(trip.id.uuidString) }
    }

    /// Ce jour-là, le trajet n'est pas fait (congé, télétravail).
    func skip(_ occurrence: RegularTripOccurrence) {
        guard let index = regularTrips.firstIndex(where: { $0.id == occurrence.tripID }) else { return }
        regularTrips[index].skippedDays.insert(occurrence.day)
        // Les jours passés ne servent plus à rien.
        let today = Calendar.swissTransit.dayKey(for: Date())
        regularTrips[index].skippedDays = regularTrips[index].skippedDays.filter { $0 >= today }
    }

    // MARK: Lire

    func trip(for occurrence: RegularTripOccurrence) -> RegularTrip? {
        regularTrips.first { $0.id == occurrence.tripID }
    }

    /// Les prochains trajets, dans l'ordre des départs.
    func upcoming(after date: Date = Date(), days: Int = 7) -> [RegularTripOccurrence] {
        regularTrips.flatMap { $0.occurrences(after: date, days: days) }
            .sorted { $0.plannedDeparture < $1.plannedDeparture }
    }

    func state(of occurrence: RegularTripOccurrence) -> LiveState? {
        live[occurrence.id]
    }

    /// Le trajet à afficher : celui du jour s'il est connu, sinon l'itinéraire prévu.
    func displayedTrip(for occurrence: RegularTripOccurrence) -> TripEvent? {
        if case .found(let match, _) = live[occurrence.id] {
            return match.trip
        }
        return trip(for: occurrence)?.plannedTrip(for: occurrence)
    }

    // MARK: Temps réel

    /// Redemande à OJP les trajets dont le départ approche, puis prévient des changements.
    @MainActor
    func refresh(now: Date = Date()) async {
        let soon = upcoming(after: now, days: 2).filter { $0.plannedDeparture.timeIntervalSince(now) < Self.liveWindow }
        await withTaskGroup(of: Void.self) { group in
            for occurrence in soon {
                group.addTask { await self.resolve(occurrence) }
            }
        }
        RegularTripAlerts.scheduleReminders(for: self)
    }

    /// Retrouve le trajet du jour auprès d'OJP. Rend le trajet trouvé, `nil` sinon.
    @MainActor @discardableResult
    func resolve(_ occurrence: RegularTripOccurrence, force: Bool = false) async -> RegularTripMatch? {
        guard let trip = trip(for: occurrence) else { return nil }
        if !force, let last = lastRequest[occurrence.id], Date().timeIntervalSince(last) < Self.minimumInterval {
            if case .found(let match, _) = live[occurrence.id] { return match }
            return nil
        }
        lastRequest[occurrence.id] = Date()
        if live[occurrence.id] == nil {
            live[occurrence.id] = .loading
        }
        do {
            let match = try await RegularTripResolver.resolve(trip, on: occurrence)
            live[occurrence.id] = .found(match, updated: Date())
            RegularTripAlerts.notifyChanges(of: trip, occurrence: occurrence, match: match)
            return match
        } catch RegularTripResolver.Failure.noTrip {
            live[occurrence.id] = .notFound
        } catch {
            // Garder le dernier état connu plutôt que d'effacer un retard affiché.
            if case .found = live[occurrence.id] {} else { live[occurrence.id] = .failed }
        }
        return nil
    }

    // MARK: Arrière-plan

    /// Demande à iOS un réveil avant le prochain trajet suivi, pour relire le temps réel et
    /// prévenir d'un retard. iOS choisit l'heure exacte, et peut ne pas réveiller l'app
    /// (mode économie d'énergie, app rarement ouverte) : les rappels, eux, partent toujours.
    func scheduleBackgroundRefresh(now: Date = Date()) {
        let watched = upcoming(after: now, days: 2).filter { occurrence in
            guard let trip = trip(for: occurrence) else { return false }
            return trip.alertsEnabled || trip.reminderMinutes != nil
        }
        guard let next = watched.first else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskID)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskID)
        // Une heure avant le départ, et pas plus d'une fois par quart d'heure.
        request.earliestBeginDate = max(next.plannedDeparture.addingTimeInterval(-3600), now.addingTimeInterval(15 * 60))
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Log.notifications.info("Réveil des trajets réguliers non prévu : \(error.localizedDescription)")
        }
    }

    /// À enregistrer avant la fin du lancement de l'app.
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            let work = Task { @MainActor in
                await shared.refresh()
                shared.scheduleBackgroundRefresh()
                task.setTaskCompleted(success: !Task.isCancelled)
            }
            task.expirationHandler = { work.cancel() }
        }
    }
}

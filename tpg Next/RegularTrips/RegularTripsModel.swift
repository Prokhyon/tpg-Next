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
    /// Le trajet habituel reconnu chaque jour, par `RegularTripOccurrence.id` : ses courses
    /// datées servent à le vérifier quand OJP cesse de le proposer. Gardé d'un lancement à
    /// l'autre : c'est souvent tout près du départ qu'il disparaît de la réponse.
    private static let knownStore = CodableStore<[String: TripEvent]>(key: "regularTripsKnownUsual")
    @ObservationIgnored private let cloud = CloudCollection<RegularTrip>(key: "cloud.regularTrips") { $0.id.uuidString }

    /// Un trajet est redemandé à OJP quand son départ approche : avant, le temps réel est vide.
    static let liveWindow: TimeInterval = 3 * 3600
    /// Au plus une requête par trajet et par minute dans la demi-heure avant le départ,
    /// toutes les cinq minutes avant.
    private static func minimumInterval(before departure: Date) -> TimeInterval {
        departure.timeIntervalSinceNow < 30 * 60 ? 60 : 5 * 60
    }

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
            cloud.record(regularTrips)
        }
    }

    /// Par `RegularTripOccurrence.id`.
    private(set) var live: [String: LiveState] = [:]
    @ObservationIgnored private var lastRequest: [String: Date] = [:]

    init() {
        regularTrips = Self.store.load() ?? []
    }

    /// Partage les trajets réguliers avec les autres appareils via iCloud.
    func startCloudSync() {
        cloud.start(current: regularTrips) { [weak self] merged in
            guard let self else { return }
            // Heure, jours ou lignes ont pu changer ailleurs : l'état du jour ne vaut plus.
            let unchanged = Set(merged.filter { self.regularTrips.contains($0) }.map(\.id.uuidString))
            live = live.filter { key, _ in unchanged.contains { key.hasPrefix($0) } }
            regularTrips = merged
        }
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
        forgetDay(of: trip)
    }

    func remove(_ trip: RegularTrip) {
        regularTrips.removeAll { $0.id == trip.id }
        forgetDay(of: trip)
    }

    private func forgetDay(of trip: RegularTrip) {
        live = live.filter { !$0.key.hasPrefix(trip.id.uuidString) }
        if let known = Self.knownStore.load() {
            Self.knownStore.save(known.filter { !$0.key.hasPrefix(trip.id.uuidString) })
        }
    }

    /// Ne plus jamais proposer cette ligne quand le trajet est recalculé. L'état des jours est
    /// oublié : il est redemandé sans elle.
    func avoid(_ line: AvoidedLine, in tripID: UUID) {
        guard let index = regularTrips.firstIndex(where: { $0.id == tripID }),
              !regularTrips[index].linesToAvoid.contains(line) else { return }
        regularTrips[index].linesToAvoid.append(line)
        forgetDay(of: regularTrips[index])
    }

    /// Ce jour-là, le trajet n'est pas fait (congé, télétravail).
    func skip(_ occurrence: RegularTripOccurrence) {
        guard let index = regularTrips.firstIndex(where: { $0.id == occurrence.tripID }) else { return }
        regularTrips[index].skippedDays.insert(occurrence.day)
        // Les jours passés ne servent plus à rien.
        let today = Calendar.swissTransit.dayKey(for: AppClock.now())
        regularTrips[index].skippedDays = regularTrips[index].skippedDays.filter { $0 >= today }
    }

    /// Ce jour-là, un autre itinéraire que le trajet habituel : c'est lui qui est suivi, rappelé
    /// et signalé. `trip` vient d'OJP : il vaut déjà pour l'état du jour.
    func choose(_ trip: TripEvent, for occurrence: RegularTripOccurrence) {
        guard let index = regularTrips.firstIndex(where: { $0.id == occurrence.tripID }) else { return }
        let today = Calendar.swissTransit.dayKey(for: AppClock.now())
        // Les jours passés ne servent plus à rien.
        var overrides = (regularTrips[index].dayOverrides ?? [:]).filter { $0.key >= today }
        overrides[occurrence.day] = trip
        regularTrips[index].dayOverrides = overrides
        let match = RegularTripMatch(trip: trip, kind: .usual)
        live[occurrence.id] = .found(match, updated: AppClock.now())
        lastRequest[occurrence.id] = AppClock.now()
        Task { await TripLiveActivities.shared.didResolve(occurrence.id, match: match) }
    }

    /// Revenir au trajet habituel ce jour-là.
    func restoreUsual(_ occurrence: RegularTripOccurrence) {
        guard let index = regularTrips.firstIndex(where: { $0.id == occurrence.tripID }),
              regularTrips[index].dayOverrides?[occurrence.day] != nil else { return }
        regularTrips[index].dayOverrides?[occurrence.day] = nil
        live[occurrence.id] = nil
        lastRequest[occurrence.id] = nil
        // L'heure a changé avec la recette : le trajet du jour est recalculé.
        guard let restored = upcoming().first(where: { $0.id == occurrence.id }) else { return }
        Task { await resolve(restored, force: true) }
    }

    // MARK: Lire

    func trip(for occurrence: RegularTripOccurrence) -> RegularTrip? {
        regularTrips.first { $0.id == occurrence.tripID }
    }

    /// Les prochains trajets, dans l'ordre des départs.
    func upcoming(after date: Date = AppClock.now(), days: Int = 7) -> [RegularTripOccurrence] {
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
    func refresh(now: Date = AppClock.now()) async {
        let soon = upcoming(after: now, days: 2).filter { $0.plannedDeparture.timeIntervalSince(now) < Self.liveWindow }
        await withTaskGroup(of: Void.self) { group in
            for occurrence in soon {
                group.addTask { await self.resolve(occurrence) }
            }
        }
        RegularTripAlerts.scheduleReminders(for: self)
        TripLiveActivities.shared.startSoonDepartingTrips(of: self, now: now)
        await TripLiveActivities.shared.refresh(model: self, now: now)
        // Les rappels posés depuis un départ : c'est aussi le seul moment où l'app les recale.
        await BusNotificationManager.shared.refreshPending(now: now)
        // Le ménage des notifications dont le moment est passé : c'est ici que l'app est réveillée.
        NotificationExpiry.clearExpired(now: now)
    }

    /// Retrouve le trajet du jour auprès d'OJP. Rend le trajet trouvé, `nil` sinon. `known` :
    /// le trajet habituel du jour tel que le connaît l'appelant (l'activité en direct), à défaut
    /// de celui gardé ici.
    @MainActor @discardableResult
    func resolve(_ occurrence: RegularTripOccurrence, force: Bool = false, known: TripEvent? = nil) async -> RegularTripMatch? {
        guard let trip = trip(for: occurrence) else { return nil }
        if !force, let last = lastRequest[occurrence.id], AppClock.now().timeIntervalSince(last) < Self.minimumInterval(before: occurrence.plannedDeparture) {
            if case .found(let match, _) = live[occurrence.id] { return match }
            return nil
        }
        lastRequest[occurrence.id] = AppClock.now()
        if live[occurrence.id] == nil {
            live[occurrence.id] = .loading
        }
        var knownTrips = Self.knownStore.load() ?? [:]
        let known = trip.knownUsual(known, for: occurrence) ?? trip.known(knownTrips[occurrence.id], for: occurrence)
        do {
            let match = try await RegularTripResolver.resolve(trip, on: occurrence, known: known)
            live[occurrence.id] = .found(match, updated: AppClock.now())
            if match.isSure, let usual = trip.knownUsual(match.trip, for: occurrence) {
                knownTrips[occurrence.id] = usual
                // Les jours passés ne servent plus.
                let today = Calendar.swissTransit.dayKey(for: AppClock.now())
                Self.knownStore.save(knownTrips.filter { String($0.key.suffix(10)) >= today })
            }
            // En route, l'activité en direct suit le trajet de plus près (correspondances,
            // suite recalculée) : l'itinéraire redemandé depuis le départ n'a plus rien à dire.
            if !TripLiveActivities.shared.isUnderway(occurrence.id) {
                RegularTripAlerts.notifyChanges(of: trip, occurrence: occurrence, match: match)
            }
            await TripLiveActivities.shared.didResolve(occurrence.id, match: match)
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
    @MainActor
    func scheduleBackgroundRefresh(now: Date = Date()) {
        let watched = upcoming(after: now, days: 2).filter { occurrence in
            guard let trip = trip(for: occurrence) else { return false }
            // Le réveil relit le temps réel : pour les alertes, et pour que le rappel dise l'heure réelle.
            return (RegularTripAlerts.isEnabledOnThisDevice && trip.alertsEnabled)
                || (RegularTripAlerts.remindersEnabledOnThisDevice && trip.reminderMinutes != nil)
        }
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskID)
        // Un rappel posé depuis un départ : relire son heure estimée avant qu'il ne parte.
        let reminderCheck = BusNotificationManager.shared.nextReminderDeparture
            .map { max($0.addingTimeInterval(-3600), now.addingTimeInterval(15 * 60)) }
        if let arrival = TripLiveActivities.shared.nextActivityArrival {
            // Un trajet suivi en direct : au plus tôt pour suivre les retards, puis juste après
            // l'arrivée, pour terminer l'activité. iOS décide du rythme réel.
            let afterArrival = arrival.addingTimeInterval(3 * 60)
            request.earliestBeginDate = afterArrival.timeIntervalSince(now) < 15 * 60
                ? max(afterArrival, now.addingTimeInterval(60))
                : now.addingTimeInterval(5 * 60)
        } else if let next = watched.first {
            // Une heure avant le départ, et pas plus d'une fois par quart d'heure.
            let tripCheck = max(next.plannedDeparture.addingTimeInterval(-3600), now.addingTimeInterval(15 * 60))
            request.earliestBeginDate = min(tripCheck, reminderCheck ?? tripCheck)
        } else if let reminderCheck {
            request.earliestBeginDate = reminderCheck
        } else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskID)
            return
        }
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
                UpcomingTripsPublisher.publish(regular: shared, saved: nil)
                shared.scheduleBackgroundRefresh()
                task.setTaskCompleted(success: !Task.isCancelled)
            }
            task.expirationHandler = { work.cancel() }
        }
    }
}

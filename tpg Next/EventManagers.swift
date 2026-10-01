//
//  EventManagers.swift
//  tpg Next
//
//  Created by Loris Thomas on 29.12.2024.
//

import Observation
import Foundation
import tpgNextFunc
import MapKit

@Observable
public class TripManager {
    public var tripEvents: [TripEvent] = []
    public var tripError: Bool = false
    
    /// Numéro de la dernière requête : une réponse plus ancienne arrivée après elle
    /// (timer, changement d'heure, rafraîchissement) ne doit pas l'écraser.
    private var latestRequest = 0

    /// Sans départ ou sans arrivée, la requête échoue et `tripError` passe à vrai.
    public func selectTrip(from departure: TripEndpoint?, to arrival: TripEndpoint?, at selectedTime: Date, isArrivalTime: Bool) {
        self.tripError = false
        latestRequest += 1
        let request = latestRequest
        fetchTrips(with: departure?.stop, with: departure?.place, with: departure?.isPlace ?? false,
                   with: arrival?.stop, with: arrival?.place, with: arrival?.isPlace ?? false,
                   with: selectedTime, with: isArrivalTime) { data in
            guard request == self.latestRequest else { return }
            guard let data else {
                self.tripError = true
                return
            }
            let startCoordinate = departure?.coordinates ?? Coordinates(lon: 0, lat: 0)
            let endCoordinate = arrival?.coordinates ?? Coordinates(lon: 0, lat: 0)

            // Décodage hors du thread principal ; seul le résultat y revient.
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result {
                    try parseTripEvents(from: data, startCoordinate: startCoordinate, endCoordinates: endCoordinate,
                                        startName: departure?.name ?? "", endName: arrival?.name ?? "",
                                        startCode: departure?.stop?.sloid, endCode: arrival?.stop?.sloid,
                                        geoDeparture: departure?.isPlace ?? false, geoArrival: arrival?.isPlace ?? false)
                }
                DispatchQueue.main.async {
                    guard request == self.latestRequest else { return }
                    switch result {
                    case .success(var trips):
                        // Repris tel quel : l'itinéraire dont la première étape n'a ni transfert
                        // ni ligne arrive en dernier, et passe en tête.
                        if let firstLeg = trips.last?.legs.first, !firstLeg.transfer, firstLeg.publishedLineName.isEmpty {
                            trips.insert(trips.removeLast(), at: 0)
                        }
                        self.tripEvents = trips
                    case .failure(let error):
                        self.tripError = true
                        if let parserError = error as? ParserError, case .noEventFound(let message) = parserError {
                            Log.network.info("Aucun itinéraire : \(message)")
                        } else {
                            Log.network.error("Itinéraires : réponse illisible")
                        }
                    }
                }
            }
        }
    }
}


@Observable
public class SavedTripsModel {
    private static let store = CodableStore<[TripEvent]>(key: "savedTrips")
    @ObservationIgnored private let cloud = CloudCollection<TripEvent>(key: "cloud.savedTrips", id: \.id)

    public var savedTrips: [TripEvent] {
        didSet {
            Self.store.save(savedTrips)
            cloud.record(savedTrips)
            scheduleNotifications()
        }
    }

    /// Les itinéraires enregistrés, sans instancier le modèle (tâche de fond).
    static var storedTrips: [TripEvent] { withoutExpired(store.load() ?? []) }

    init() {
        let saved = Self.store.load() ?? []
        savedTrips = Self.withoutExpired(saved)
        // didSet ne joue pas dans init.
        if savedTrips.count != saved.count { Self.store.save(savedTrips) }
    }

    /// Partage les itinéraires enregistrés avec les autres appareils via iCloud.
    func startCloudSync() {
        cloud.start(current: savedTrips) { [weak self] merged in
            guard let self else { return }
            // Un appareil pas encore à jour peut renvoyer des itinéraires expirés.
            let kept = Self.withoutExpired(merged)
            // L'état du jour ne vaut plus pour un itinéraire supprimé ou remplacé ailleurs.
            let ids = Set(kept.map(\.id))
            live = live.filter { ids.contains($0.key) }
            savedTrips = kept
        }
    }

    // MARK: Expiration

    /// Un itinéraire passé depuis plus longtemps est supprimé : iCloud ne garde qu'un Mo pour
    /// toute l'app, et un itinéraire enregistré en pèse environ 4 Ko.
    static let retentionDays = 30

    /// Sans date lisible, on garde : mieux vaut un itinéraire de trop qu'un effacé à tort.
    static func withoutExpired(_ trips: [TripEvent], now: Date = Date()) -> [TripEvent] {
        let limit = now.addingTimeInterval(-TimeInterval(retentionDays) * 86_400)
        return trips.filter { trip in
            guard let end = trip.endDate ?? trip.startDate else { return true }
            return end >= limit
        }
    }

    private func removeExpiredTrips(now: Date) {
        let kept = Self.withoutExpired(savedTrips, now: now)
        if kept.count != savedTrips.count { savedTrips = kept }
    }

    public func addTrip(_ trip: TripEvent) {
        if !tripIsSaved(trip) {
            savedTrips.append(trip)
        }
    }

    /// Retire l'itinéraire enregistré, qu'on tienne sa version enregistrée ou celle du jour.
    public func removeTrip(_ trip: TripEvent) {
        let id = savedTrip(for: trip)?.id ?? trip.id
        savedTrips.removeAll { $0.id == id }
        live[id] = nil
    }

    public func tripIsSaved(_ trip: TripEvent) -> Bool {
        savedTrip(for: trip) != nil
    }

    /// L'itinéraire enregistré derrière `trip`. Le détail s'ouvre sur la version du jour
    /// (`displayedTrip`, retards compris) : elle n'est plus égale à celle enregistrée, et le
    /// menu proposait alors de l'enregistrer au lieu de la retirer.
    private func savedTrip(for trip: TripEvent) -> TripEvent? {
        savedTrips.first { $0.id == trip.id || $0 == trip || displayedTrip(for: $0) == trip }
    }

    /// Remplace un itinéraire enregistré qui ne convient plus (supprimé, horaire changé).
    /// `new` vient d'OJP : il vaut déjà pour l'état du jour.
    func replaceTrip(_ old: TripEvent, with new: TripEvent) {
        if let index = savedTrips.firstIndex(where: { $0.id == old.id }) {
            savedTrips[index] = new
        } else {
            savedTrips.append(new)
        }
        live[old.id] = nil
        live[new.id] = .found(RegularTripMatch(trip: new, kind: .usual), updated: Date())
        lastRequest[new.id] = Date()
    }

    // MARK: Temps réel

    /// L'itinéraire redemandé à OJP, par identifiant de l'itinéraire enregistré. Rien n'est
    /// enregistré : l'état ne vaut que pour la session.
    private(set) var live: [String: RegularTripsModel.LiveState] = [:]
    @ObservationIgnored private var lastRequest: [String: Date] = [:]

    func state(of trip: TripEvent) -> RegularTripsModel.LiveState? {
        live[trip.id]
    }

    /// La même course avec son temps réel (ou à sa nouvelle heure), sinon l'itinéraire enregistré.
    func displayedTrip(for trip: TripEvent) -> TripEvent {
        if case .found(let match, _) = live[trip.id], match.kind != .alternative {
            return match.trip
        }
        return trip
    }

    /// Redemande les prochains itinéraires de la semaine : une fois pour savoir s'ils existent
    /// toujours (horaire modifié, course supprimée), puis régulièrement dans les trois heures qui
    /// précèdent le départ, quand OJP a le temps réel.
    @MainActor
    func refresh(now: Date = Date()) async {
        removeExpiredTrips(now: now)
        let soon = savedTrips.filter { trip in
            guard let start = trip.startDate, (trip.endDate ?? start) > now,
                  start.timeIntervalSince(now) < 7 * 86_400 else { return false }
            return shouldRequest(trip, departure: start, now: now)
        }
        await withTaskGroup(of: Void.self) { group in
            for trip in soon {
                group.addTask { await self.resolve(trip) }
            }
        }
        // Le rappel suit l'heure réelle.
        if !soon.isEmpty { SavedTripReminders.schedule(for: savedTrips, displayed: displayedTrip(for:)) }
    }

    /// Repose les notifications de cet appareil : rappels et invitations au suivi en direct.
    func scheduleNotifications() {
        SavedTripAutoTracking.scheduleReminders(for: savedTrips)
        SavedTripReminders.schedule(for: savedTrips, displayed: displayedTrip(for:))
    }

    private func shouldRequest(_ trip: TripEvent, departure: Date, now: Date) -> Bool {
        guard let last = lastRequest[trip.id] else { return true }
        let untilDeparture = departure.timeIntervalSince(now)
        guard untilDeparture < RegularTripsModel.liveWindow else { return false }
        return now.timeIntervalSince(last) >= (untilDeparture < 30 * 60 ? 60 : 5 * 60)
    }

    @MainActor @discardableResult
    func resolve(_ trip: TripEvent) async -> RegularTripMatch? {
        lastRequest[trip.id] = Date()
        if live[trip.id] == nil {
            live[trip.id] = .loading
        }
        do {
            let match = try await SavedTripResolver.resolve(trip)
            live[trip.id] = .found(match, updated: Date())
            return match
        } catch RegularTripResolver.Failure.noTrip {
            live[trip.id] = .notFound
        } catch {
            // Garder le dernier état connu plutôt que d'effacer un retard affiché.
            if case .found = live[trip.id] {} else { live[trip.id] = .failed }
        }
        return nil
    }
}

/// Les derniers itinéraires cherchés, proposés par la recherche (écran vide).
@Observable
final class RecentTrips {
    static let shared = RecentTrips()
    private static let store = CodableStore<[RecentTrip]>(key: "recentTrips")

    /// `origin` absent : depuis la position du moment.
    struct RecentTrip: Codable, Hashable {
        var origin: RegularTripPlace?
        var destination: RegularTripPlace
    }

    private(set) var trips: [RecentTrip] {
        didSet { Self.store.save(trips) }
    }

    private init() {
        trips = Self.store.load() ?? []
    }

    func add(from origin: TripEndpoint?, to destination: TripEndpoint) {
        // « Ma position » ne vaut que pour l'instant : on repartira de la position du moment.
        let start = origin.flatMap { $0.isCurrentPosition ? nil : RegularTripPlace(endpoint: $0) }
        let trip = RecentTrip(origin: start, destination: RegularTripPlace(endpoint: destination))
        trips.removeAll { $0 == trip }
        trips.insert(trip, at: 0)
        if trips.count > 5 {
            trips.removeLast()
        }
    }
}

extension TripEndpoint {
    /// La position de l'utilisateur au moment de la recherche, pas un lieu choisi.
    var isCurrentPosition: Bool {
        place?.name == "Ma position"
    }
}

extension RegularTripPlace {
    init(endpoint: TripEndpoint) {
        self.init(name: endpoint.name, sloid: endpoint.stop?.sloid, coordinates: endpoint.coordinates)
    }
}

@Observable
class RecentSearch {
    private static let store = CodableStore<[RecentSearchItem]>(key: "savedSearch")

    public var searchItems: [RecentSearchItem] {
        didSet { Self.store.save(searchItems) }
    }

    init() {
        searchItems = Self.store.load() ?? []
    }

    func add(name: String, isStop: Bool, stop: Stop?, geoCoordinates: Coordinates?) {
        let item = RecentSearchItem(name: name, isStop: isStop, stop: stop, geoCoordinates: geoCoordinates)
        searchItems.removeAll { $0.name == item.name }
        searchItems.insert(item, at: 0)
        if searchItems.count > 5 {
            searchItems.removeLast()
        }
    }

    struct RecentSearchItem: Encodable, Decodable, Hashable {
        var name: String
        var isStop: Bool
        var stop: Stop?
        var geoCoordinates: Coordinates?

        /// Un lieu est enregistré sous la forme « titre;sous-titre ». Le sous-titre peut être
        /// vide : `split` l'omettait alors, et lire `[1]` plantait.
        var placeTitle: (name: String, subtitle: String) {
            let parts = name.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            return (String(parts.first ?? ""), parts.count > 1 ? String(parts[1]) : "")
        }
    }
}

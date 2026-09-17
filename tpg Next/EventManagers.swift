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

    public var savedTrips: [TripEvent] {
        didSet { Self.store.save(savedTrips) }
    }

    init() {
        savedTrips = Self.store.load() ?? []
    }

    public func addTrip(_ trip: TripEvent) {
        if !savedTrips.contains(trip) {
            savedTrips.append(trip)
        }
    }

    public func removeTrip(_ trip: TripEvent) {
        savedTrips.removeAll { $0.id == trip.id }
    }

    public func tripIsSaved(_ trip: TripEvent) -> Bool {
        savedTrips.contains(trip)
    }
}

@Observable
public class RegularTripsModel {
    private static let store = CodableStore<[RegularTrip]>(key: "regularTrips")

    public var regularTrips: [RegularTrip] {
        didSet { Self.store.save(regularTrips) }
    }

    init() {
        regularTrips = Self.store.load() ?? []
    }

    public func addTrip(_ trip: RegularTrip) {
        if !regularTrips.contains(where: { $0.id == trip.id }) {
            regularTrips.append(trip)
        }
    }

    public func removeTrip(_ trip: RegularTrip) {
        regularTrips.removeAll { $0.id == trip.id }
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

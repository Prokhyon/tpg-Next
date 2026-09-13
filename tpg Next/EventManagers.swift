//
//  EventManagers.swift
//  tpg Next
//
//  Created by Loris Thomas on 29.12.2024.
//

import Foundation
import tpgNextFunc
import MapKit

public class TripManager: ObservableObject {
    @Published public var tripEvents: [TripEvent] = []
    @Published public var tripError: Bool = false
    
    /// Numéro de la dernière requête : une réponse plus ancienne arrivée après elle
    /// (timer, changement d'heure, rafraîchissement) ne doit pas l'écraser.
    private var latestRequest = 0

    public func selectTrip(with departureStop: Stop?, with departureGeoPosition: GeoPosition?, with geoDeparture: Bool, with arrivalStop: Stop?, with arrivalGeoPosition: GeoPosition?, with geoArrival: Bool, with selectedTime: Date, with isArrivalTime: Bool) {
        self.tripError = false
        latestRequest += 1
        let request = latestRequest
        fetchTrips(with: departureStop, with: departureGeoPosition, with: geoDeparture, with: arrivalStop, with: arrivalGeoPosition, with: geoArrival, with: selectedTime, with: isArrivalTime) { data in
            guard request == self.latestRequest else { return }
            guard let data else {
                self.tripError = true
                return
            }
            let startCoordinate = (geoDeparture ? departureGeoPosition?.coordinate.toCoordinates : departureStop?.wgs84Coordinates) ?? Coordinates(lon: 0, lat: 0)
            let endCoordinate = (geoArrival ? arrivalGeoPosition?.coordinate.toCoordinates : arrivalStop?.wgs84Coordinates) ?? Coordinates(lon: 0, lat: 0)
            let startName = (geoDeparture ? departureGeoPosition?.name : departureStop?.name) ?? ""
            let endName = (geoArrival ? arrivalGeoPosition?.name : arrivalStop?.name) ?? ""

            // Décodage hors du thread principal ; seul le résultat y revient.
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result {
                    try parseTripEvents(from: data, startCoordinate: startCoordinate, endCoordinates: endCoordinate, startName: startName, endName: endName, startCode: departureStop?.sloid, endCode: arrivalStop?.sloid, geoDeparture: geoDeparture, geoArrival: geoArrival)
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


public class SavedTripsModel: ObservableObject {
    @Published public var savedTrips: [TripEvent] {
        didSet {
            saveTrips()
        }
    }
    
    private let userDefaultsKey = "savedTrips"
    
    init() {
        self.savedTrips = []
        loadTrips()
    }

    public func addTrip(_ trip: TripEvent) {
        if !savedTrips.contains(trip) {
            savedTrips.append(trip)
            saveTrips()
        }
    }
    
    public func removeTrip(_ trip: TripEvent) {
        savedTrips.removeAll(where: { $0.id == trip.id })
        saveTrips()
    }
    
    public func tripIsSaved(_ trip: TripEvent) -> Bool {
        return savedTrips.contains(trip)
    }
    
    private func saveTrips() {
        do {
            let data = try JSONEncoder().encode(savedTrips)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            Log.data.error("Enregistrement des itinéraires impossible : \(error.localizedDescription)")
        }
    }
    
    private func loadTrips() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let trips = try JSONDecoder().decode([TripEvent].self, from: data)
                self.savedTrips = trips
            } catch {
                Log.data.error("Lecture des itinéraires impossible : \(error.localizedDescription)")
            }
        }
    }
}

public class RegularTripsModel: ObservableObject {
    @Published public var regularTrips: [RegularTrip] {
        didSet { saveTrips() }
    }

    private let userDefaultsKey = "regularTrips"

    init() {
        self.regularTrips = []
        loadTrips()
    }

    public func addTrip(_ trip: RegularTrip) {
        if !regularTrips.contains(where: { $0.id == trip.id }) {
            regularTrips.append(trip)
        }
    }

    public func removeTrip(_ trip: RegularTrip) {
        regularTrips.removeAll { $0.id == trip.id }
    }

    private func saveTrips() {
        do {
            let data = try JSONEncoder().encode(regularTrips)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            Log.data.error("Enregistrement des trajets réguliers impossible : \(error.localizedDescription)")
        }
    }

    private func loadTrips() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let trips = try JSONDecoder().decode([RegularTrip].self, from: data)
                self.regularTrips = trips
            } catch {
                Log.data.error("Lecture des trajets réguliers impossible : \(error.localizedDescription)")
            }
        }
    }
}


class RecentSearch: ObservableObject {
    @Published public var searchItems: [RecentSearchItem] {
        didSet {
            saveSearch()
        }
    }
    
    private let userDefaultsKey = "savedSearch"
    
    init() {
        self.searchItems = []
        loadSearch()
    }
    
    func add(name: String, isStop: Bool, stop: Stop?, geoCoordinates: Coordinates?) {
        let item = RecentSearchItem(name: name, isStop: isStop, stop: stop, geoCoordinates: geoCoordinates)
        searchItems.removeAll { $0.name == item.name }
        searchItems.insert(item, at: 0)
        if searchItems.count > 5 {
            searchItems.removeLast()
        }
    }
    
    private func saveSearch() {
        do {
            let data = try JSONEncoder().encode(searchItems)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            Log.data.error("Enregistrement des recherches récentes impossible : \(error.localizedDescription)")
        }
    }
    
    private func loadSearch() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let items = try JSONDecoder().decode([RecentSearchItem].self, from: data)
                self.searchItems = items
            } catch {
                Log.data.error("Lecture des recherches récentes impossible : \(error.localizedDescription)")
            }
        }
    }
    
    struct RecentSearchItem: Encodable, Decodable, Hashable {
        var name: String
        var isStop: Bool
        var stop: Stop?
        var geoCoordinates: Coordinates?
    }
}

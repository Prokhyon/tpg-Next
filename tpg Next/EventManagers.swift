//
//  EventManagers.swift
//  tpg Next
//
//  Created by Loris Thomas on 29.12.2024.
//

import Foundation
import tpgNextFunc

public class StopManager: ObservableObject {
    @Published public var stopEvents: [StopEvent] = []
    @Published public var stopError: Bool = false
    @Published public var stopErrorMessage: String = ""
    var testing: Bool = false
    
    
    @Published public var quays: [Quay] = []
    public func selectStop(stopName: String, stopSloid: String, stopEventNumber: Int, timeRequest: Date, completion: @escaping () -> Void = {}) {
        self.stopError = false
        self.stopErrorMessage = ""
        
        if testing {
            if self.stopEvents.isEmpty {
                if var mockData = loadStopEventsFromAssets() {
                    print("Using mock data for debugging.")
                    changeTime(&mockData)
                    self.stopEvents = mockData
                    completion()
                    return
                }
            } else {
                return
            }
        }
        
        fetchTransportDepartures(with: stopName, stopSloid: stopSloid, stopEventNumber: stopEventNumber, timeRequest: timeRequest) { success, data in
            if success, let data = data?.data(using: .utf8) {
                parseStopEvents(from: data, stopCode: stopSloid) { stopEvents, quays, error in
                    if let error = error {
                            switch error {
                            case .noEventFound(let msg):
                                self.stopError = true
                                self.stopErrorMessage = msg
                                print("Aucun arrêt trouvé: \(msg)")
                            default:
                                self.stopError = true
                                print("Erreur lors du parsing")
                            }
                            return
                        }
                    DispatchQueue.main.async {
                        self.stopEvents = stopEvents
                        self.quays = quays
                        //                            saveStopEventsToFile(stopEvents: stopEvents)
                        print("Stop events updated: \(stopEvents.count) events found")
                                                    print(stopEvents)
                        completion()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.stopError = true
                    print("Failed to fetch or parse stop events.")
                    completion()
                }
            }
        }
    }
}

class LineManager: ObservableObject {
    @Published var LineEvents: [LineEvent] = []
    @Published var operatorName: String = ""
    let dateFormatter = DateFormatter()
    
    public func selectJourney(_ stopEvent: StopEvent, completion: @escaping () -> Void = {}) {
        fetchTransportJourney(with: stopEvent) { success, data in
            if success, let data = data?.data(using: .utf8) {
                parseJourneyEvents(from: data) { lineEvents, operatorName in
                    self.LineEvents = lineEvents
                    self.operatorName = operatorName
                    //                        print("LineEvents updated: \(self.LineEvents), \(operatorName)")
                    completion()
                }
            } else {
                completion()
            }
        }
    }
}

class TripExistsVerification: ObservableObject {
    
}

public class TripManager: ObservableObject {
    @Published public var tripEvents: [TripEvent] = []
    @Published public var tripError: Bool = false
    let dateFormatter = DateFormatter()
    var testing: Bool = false
    
    public func selectTrip(with departureStop: Stop?, with departureGeoPosition: GeoPosition?, with geoDeparture: Bool, with arrivalStop: Stop?, with arrivalGeoPosition: GeoPosition?, with geoArrival: Bool, with selectedTime: Date, with isArrivalTime: Bool) {
        self.tripError = false
        //        print((departureGeoPosition ?? departureStop) ?? "emptyDeparture")
        //        print((arrivalGeoPosition ?? arrivalStop) ?? "emptyArrival")
        fetchTrips(with: departureStop, with: departureGeoPosition, with: geoDeparture, with: arrivalStop, with: arrivalGeoPosition, with: geoArrival, with: selectedTime, with: isArrivalTime) { success, data in
            if success {
                print("success")
                // Parse XML response
                if success, let data = data?.data(using: .utf8) {
                    let startCoordinate = geoDeparture ? departureGeoPosition?.coordinate.toCoordinates : departureStop?.wgs84Coordinates
                    //                        print(startCoordinate ?? "empty startCoordinates")
                    let endCoordinate = geoArrival ? arrivalGeoPosition?.coordinate.toCoordinates : arrivalStop?.wgs84Coordinates
                    let startName = geoDeparture ? departureGeoPosition?.name : departureStop?.name
                    let endName = geoArrival ? arrivalGeoPosition?.name : arrivalStop?.name
                    let emptyCoordinates: Coordinates = Coordinates(lon: 0.0, lat: 0.0)
                    
                    do {
                        let tripEvents = try parseTripEvents(from: data, startCoordinate: startCoordinate ?? emptyCoordinates, endCoordinates: endCoordinate ?? emptyCoordinates, startName: startName ?? "", endName: endName ?? "", startCode: departureStop?.sloid, endCode: arrivalStop?.sloid, geoDeparture: geoDeparture, geoArrival: geoArrival)
                        self.tripEvents = tripEvents
                    } catch ParserError.noEventFound(let message) {
                        self.tripError = true
                        print("Aucun trajet trouvé: \(message)")
                    } catch {
                        self.tripError = true
                        print("Erreur lors de la recherche de trajets.")
                    }
                }
                if !(self.tripEvents.last?.legs.first?.transfer ?? true) && self.tripEvents.last?.legs.first?.publishedLineName == "" {
                    let transferLast: TripEvent = self.tripEvents.last!
                    var tripEventsTransfer: [TripEvent] = self.tripEvents.dropLast()
                    tripEventsTransfer.insert(transferLast, at: 0)
                    self.tripEvents = tripEventsTransfer
                }
            } else {
                self.tripError = true
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
            print("Error encoding trips: \(error)")
        }
    }
    
    private func loadTrips() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let trips = try JSONDecoder().decode([TripEvent].self, from: data)
                self.savedTrips = trips
                print("trips loaded")
            } catch {
                print("Error decoding trips: \(error)")
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
            print("Error encoding regular trips: \(error)")
        }
    }

    private func loadTrips() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let trips = try JSONDecoder().decode([RegularTrip].self, from: data)
                self.regularTrips = trips
            } catch {
                print("Error decoding regular trips: \(error)")
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
            print("Error encoding recent searches: \(error)")
        }
    }
    
    private func loadSearch() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let items = try JSONDecoder().decode([RecentSearchItem].self, from: data)
                self.searchItems = items
                print("Recent searches loaded")
            } catch {
                print("Error decoding recent searches: \(error)")
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

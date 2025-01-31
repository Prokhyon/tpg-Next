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
    var testing: Bool = false
    
    
    @Published public var quays: [Quay] = []
    public func selectStop(stopName: String, stopCodedidoc: String, stopEventNumber: Int, timeRequest: Date, completion: @escaping () -> Void = {}) {
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
        
        fetchTransportDepartures(with: stopName, stopCodedidoc: stopCodedidoc, stopEventNumber: stopEventNumber, timeRequest: timeRequest) { success, data in
            if success, let data = data?.data(using: .utf8) {
                print("Number of request event: \(stopEventNumber)")
                parseStopEvents(from: data, stopCode: stopCodedidoc) { stopEvents, quays in
                    DispatchQueue.main.async {
                        self.stopEvents = stopEvents
                        self.quays = quays
                        //                            saveStopEventsToFile(stopEvents: stopEvents)
                        print("Stop events updated: \(stopEvents.count) events found")
                        //                            print(stopEvents)
                        completion()
                    }
                }
            } else {
                DispatchQueue.main.async {
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


public class TripManager: ObservableObject {
    @Published public var tripEvents: [TripEvent] = []
    let dateFormatter = DateFormatter()
    
    public func selectTrip(with departureStop: Stop?, with departureGeoPosition: GeoPosition?, with geoDeparture: Bool, with arrivalStop: Stop?, with arrivalGeoPosition: GeoPosition?, with geoArrival: Bool, with selectedTime: Date, with isArrivalTime: Bool) {
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
                    
                    self.tripEvents = parseTripEvents(from: data, startCoordinate: startCoordinate ?? emptyCoordinates, endCoordinates: endCoordinate ?? emptyCoordinates, startName: startName ?? "", endName: endName ?? "", startCode: departureStop?.codedidoc, endCode: arrivalStop?.codedidoc, geoDeparture: geoDeparture, geoArrival: geoArrival)
                }
                if !(self.tripEvents.last?.legs.first?.transfer ?? true) && self.tripEvents.last?.legs.first?.publishedLineName == "" {
                    let transferLast: TripEvent = self.tripEvents.last!
                    var tripEventsTransfer: [TripEvent] = self.tripEvents.dropLast()
                    tripEventsTransfer.insert(transferLast, at: 0)
                    self.tripEvents = tripEventsTransfer
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
    
//    func moveFavorite(fromOffsets source: IndexSet, toOffset destination: Int) {
//        favoriteStops.move(fromOffsets: source, toOffset: destination)
//        saveFavorites()
//    }
    
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

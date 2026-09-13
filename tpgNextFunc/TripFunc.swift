//
//  TripFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 30.06.2024.
//

import Foundation
import SwiftUI
import MapKit
import Combine

var responseTrip = ""

public struct TripEvent: Identifiable, Hashable, Encodable, Decodable {
    public var id: String
    public var duration: String
    public var startTime: String
    public var endTime: String
    public var startCoordinates: Coordinates
    public var endCoordinates: Coordinates
    public var startName: String
    public var endName: String
    public var startCode: String?
    public var endCode: String?
    public var geoDeparture: Bool
    public var geoArrival: Bool
    public var transfers: String
    public var legs: [TripLeg]
}

public struct TripLeg: Identifiable, Hashable, Encodable, Decodable {
    public var id: String
    public var transfer: Bool = false
    public var legBoardStopName: String
    public var legBoardStopId: String
    public var legBoardQuay: String
    public var legBoardTimetableTime: String
    public var legBoardEstimatedTime: String
    public var legBoardLongitude: String
    public var legBoardLatitude: String
    
    public var legAlightStopName: String
    public var legAlightStopId: String
    public var legAlightQuay: String
    public var legAlightTimetableTime: String
    public var legAlightEstimatedTime: String
    public var legAlightLongitude: String
    public var legAlightLatitude: String
    
    public var legIntermediates: [LegIntermediate]
    
    public var legDestination: String
    public var journeyRef: String
    /// Optionnel : les itinéraires enregistrés avant qu'il soit lu n'en ont pas (voir `resolvedOperatingDayRef`).
    public var operatingDayRef: String? = nil
    public var publishedLineName: String
    public var legDuration: String
    public var transferDuration: String
    public var transferWalkDuration: String
    public var transferBuffer: String
    public var transportTypeName: String
    public var legOperator: String
//    var legTrack: [CLLocationCoordinate2D]
}

public struct LegIntermediate: Codable, Identifiable, Hashable {
    public var id: String
    public var stopId: String
    public var stopName: String
    public var longitude: String
    public var latitude: String
}

extension TripLeg {
    /// Jour d'exploitation de la course, à passer à l'OJPTripInfoRequest. À défaut (itinéraire
    /// enregistré avant qu'il soit lu), on l'estime : jusque vers 4 h, les courses de nuit
    /// appartiennent au jour d'exploitation de la veille. `fetchTransportJourney` rattrape les écarts.
    public var resolvedOperatingDayRef: String {
        if let operatingDayRef, !operatingDayRef.isEmpty {
            return operatingDayRef
        }
        guard let date = ISO8601DateFormatter().date(from: legBoardTimetableTime) else {
            return String(legBoardTimetableTime.prefix(10))
        }
        let swissTimeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = swissTimeZone
        let nightDate = calendar.component(.hour, from: date) < 4 ? date.addingTimeInterval(-86_400) : date
        return dayString(from: nightDate, in: swissTimeZone)
    }
}

/// Date locale (yyyy-MM-dd) d'une heure OJP en UTC, pour l'affichage : couper la chaîne
/// UTC donne la veille pour les trajets entre minuit et 2 h.
public func localDayString(fromUTC isoString: String) -> String {
    guard let date = ISO8601DateFormatter().date(from: isoString) else {
        return String(isoString.prefix(10))
    }
    return dayString(from: date, in: .current)
}

private func dayString(from date: Date, in timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

public enum ParserError: Error {
    case noEventFound(message: String)
    case xmlParsingFailed
    case unknown
}

public func parseTripEvents(from data: Data, startCoordinate: Coordinates, endCoordinates: Coordinates, startName: String, endName: String, startCode: String?, endCode: String?, geoDeparture: Bool, geoArrival: Bool) throws -> [TripEvent] {
    class TripEventParserDelegate: NSObject, XMLParserDelegate {
        var error: ParserError?
        
        private var currentElement = ""
        private var currentTripEvent: TripEvent?
        var currentTripLeg: TripLeg?
        var currentLegIntermediate: LegIntermediate?
        var currentPosition: CLLocationCoordinate2D?
        var tripEvents: [TripEvent] = []
        var currentLegs: [TripLeg] = []
        
        var currentIntermediates: [LegIntermediate] = []
        
        private var insideTripEventResult = false
        private var insideTripResponseContext = false
        private var insideStopPoint = false
        private var insideStopPlace = false
        
        private var insideLeg = false
        private var legBoard = false
        private var legAlight = false
        private var legIntermediates = false
        private var linkProjection = false
        private var previousIsTripID = false
        
        private var currentStopPlaceRef = ""
        private var stopPlaceRefMap: [String: (longitude: String, latitude: String)] = [:]
        private var currentStopPointRef = ""
        private var currentLongitude = ""
        private var currentLatitude = ""
        
        private var parentElement = ""
        private var currentTextContent: String = ""
        
        private var startCoordinates: Coordinates
        private var endCoordinates: Coordinates
        private var startName: String
        private var endName: String
        private var startCode: String?
        private var endCode: String?
        private var geoDeparture: Bool
        private var geoArrival: Bool
        
        init(startCoordinates: Coordinates, endCoordinates: Coordinates, startName: String, endName: String, startCode: String?, endCode: String?, geoDeparture: Bool, geoArrival: Bool) {
            self.startCoordinates = startCoordinates
            self.endCoordinates = endCoordinates
            self.startName = startName
            self.endName = endName
            self.startCode = startCode
            self.endCode = endCode
            self.geoDeparture = geoDeparture
            self.geoArrival = geoArrival
        }
        
        func parse(data: Data) -> [TripEvent] {
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
            return tripEvents
        }
        
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            currentElement = elementName
            currentTextContent = "" // Reset text content on a new element
            
//            if elementName == "siri:ErrorText" {
//                currentElement = elementName
//            }
            
            if elementName == "ojp:TripResponseContext" {
                insideTripResponseContext = true
            } else if elementName == "ojp:TripResult" {
                currentTripEvent = TripEvent(id: "", duration: "", startTime: "", endTime: "", startCoordinates: startCoordinates, endCoordinates: endCoordinates, startName: startName, endName: endName, startCode: startCode, endCode: endCode, geoDeparture: geoDeparture, geoArrival: geoArrival, transfers: "", legs: [])
                insideTripEventResult = true
            } else if elementName == "ojp:TripLeg" {
                currentTripLeg = TripLeg(id: "", legBoardStopName: "", legBoardStopId: "", legBoardQuay: "", legBoardTimetableTime: "", legBoardEstimatedTime: "", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "", legAlightStopId: "", legAlightQuay: "", legAlightTimetableTime: "", legAlightEstimatedTime: "", legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "", journeyRef: "", publishedLineName: "", legDuration: "", transferDuration: "", transferWalkDuration: "", transferBuffer: "", transportTypeName: "", legOperator: ""/*, legTrack: []*/)
                insideLeg = true
            } else if elementName == "ojp:LegBoard" {
                legBoard = true
            } else if elementName == "ojp:LegAlight" {
                legAlight = true
            } else if elementName == "ojp:LegIntermediates" {
                currentLegIntermediate = LegIntermediate(id: "", stopId: "", stopName: "", longitude: "", latitude: "")
                legIntermediates = true
            } else if currentElement == "ojp:StopPoint" {
                insideStopPoint = true
            } else if currentElement == "ojp:StopPlace" {
                insideStopPlace = true
                /*} else if currentElement == "ojp:LinkProjection" {
                 currentPosition = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
                 linkProjection = true*/
            } else if currentElement == "ojp:StopPointName" || currentElement == "ojp:PlannedQuay" || currentElement == "ojp:PublishedLineName" || currentElement == "ojp:DestinationText" || currentElement == "ojp:TransportTypeName" || currentElement == "ojp:Position" || currentElement == "ojp:OperatorName"{
                parentElement = currentElement
            }
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentTextContent += string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            
            if currentElement == "siri:ErrorText" {
                error = .noEventFound(message: currentTextContent)
            }
            
            if insideTripResponseContext {
                if !currentTextContent.isEmpty || elementName == "ojp:Location" || elementName == "ojp:StopPoint" || elementName == "ojp:StopPlace" {
                    if elementName == "ojp:StopPoint" {
                        insideStopPoint = false
                    } else if elementName == "ojp:StopPlace" {
                        insideStopPlace = false
                    } else if elementName == "ojp:Location" && !currentStopPointRef.isEmpty && !currentLongitude.isEmpty && !currentLatitude.isEmpty {
                        // Store the stopPointRef along with its geolocation data
                        stopPlaceRefMap[currentStopPointRef] = (longitude: currentLongitude, latitude: currentLatitude)
                        // Reset current values for the next Location
                        currentStopPlaceRef = ""
                        currentStopPointRef = ""
                        currentLongitude = ""
                        currentLatitude = ""
                    } else if insideStopPoint {
                        if currentElement == "siri:StopPointRef" {
                            currentStopPointRef = currentTextContent
                        }
                    } else if !currentStopPointRef.isEmpty {
                        if currentElement == "siri:Longitude" {
                            currentLongitude = currentTextContent
                        } else if currentElement == "siri:Latitude" {
                            currentLatitude = currentTextContent
                        } else if elementName == "ojp:Location" {
                            currentStopPlaceRef = ""
                            currentStopPointRef = ""
                            currentLongitude = ""
                            currentLatitude = ""
                        }
                    } else if elementName == "ojp:Location" && !currentStopPlaceRef.isEmpty && !currentLongitude.isEmpty && !currentLatitude.isEmpty {
                        stopPlaceRefMap[currentStopPlaceRef] = (longitude: currentLongitude, latitude: currentLatitude)
                        // Reset current values for the next Location
                        currentStopPlaceRef = ""
                        currentStopPointRef = ""
                        currentLongitude = ""
                        currentLatitude = ""
                    } else if insideStopPlace {
                        if currentElement == "ojp:StopPlaceRef" {
                            currentStopPlaceRef = currentTextContent
                        }
                    } else if !currentStopPlaceRef.isEmpty {
                        if currentElement == "siri:Longitude" {
                            currentLongitude = currentTextContent
                        } else if currentElement == "siri:Latitude" {
                            currentLatitude = currentTextContent
                        } else if elementName == "ojp:Location" {
                            currentStopPlaceRef = ""
                            currentStopPointRef = ""
                            currentLongitude = ""
                            currentLatitude = ""
                        }
                    }
                }
            }
            if linkProjection {
                if parentElement == "ojp:Position" {
                    if currentElement == "siri:Longitude" {
                        currentPosition?.longitude = Double(currentTextContent)!
                    } else if currentElement == "siri:Latitude" {
                        currentPosition?.latitude = Double(currentTextContent)!
                    }
                }
            } else if legIntermediates {
                if currentElement == "ojp:Order" {
                    currentLegIntermediate?.id = currentTextContent
                } else if currentElement == "siri:StopPointRef" {
                    currentLegIntermediate?.stopId = currentTextContent
                } else if parentElement == "ojp:StopPointName" && currentElement == "ojp:Text" {
                    currentLegIntermediate?.stopName = currentTextContent
                }
            } else if parentElement == "ojp:StopPointName" && currentElement == "ojp:Text" {
                if legBoard {
                    currentTripLeg?.legBoardStopName = currentTextContent
                } else if legAlight {
                    currentTripLeg?.legAlightStopName = currentTextContent
                }
            } else if parentElement == "ojp:PlannedQuay" && currentElement == "ojp:Text" {
                if legBoard {
                    currentTripLeg?.legBoardQuay = currentTextContent
                } else if legAlight {
                    currentTripLeg?.legAlightQuay = currentTextContent
                }
            } else if parentElement == "ojp:PublishedLineName" && currentElement == "ojp:Text" {
                currentTripLeg?.publishedLineName = currentTextContent
            } else if parentElement == "ojp:DestinationText" && currentElement == "ojp:Text" {
                currentTripLeg?.legDestination = currentTextContent
            } else if parentElement == "ojp:TransportTypeName" && currentElement == "ojp:Text" {
                currentTripLeg?.transportTypeName = currentTextContent
            } else if parentElement == "ojp:OperatorName" && currentElement == "ojp:Text" {
                currentTripLeg?.legOperator = currentTextContent
            } else if currentElement == "ojp:TimetabledTime" {
                if legBoard {
                    currentTripLeg?.legBoardTimetableTime = currentTextContent
                } else if legAlight {
                    currentTripLeg?.legAlightTimetableTime = currentTextContent
                }
            } else if currentElement == "ojp:EstimatedTime" {
                if legBoard {
                    currentTripLeg?.legBoardEstimatedTime = currentTextContent
                } else if legAlight {
                    currentTripLeg?.legAlightEstimatedTime = currentTextContent
                }
            } else if currentElement == "siri:StopPointRef" {
                if legBoard {
                    currentTripLeg?.legBoardStopId = currentTextContent
                } else if legAlight {
                    currentTripLeg?.legAlightStopId = currentTextContent
                }
            }
            
            switch currentElement {
            case "ojp:ResultId":
                currentTripEvent?.id = currentTextContent
                previousIsTripID = true
            case "ojp:Duration":
                if previousIsTripID {
                    previousIsTripID = false
                    currentTripEvent?.duration = currentTextContent
                }
                if insideLeg {
                    if currentTripLeg?.transfer == true {
                        currentTripLeg?.transferDuration = currentTextContent
                    } else {
                        currentTripLeg?.legDuration = currentTextContent
                    }
                }
            case "ojp:StartTime":
                currentTripEvent?.startTime = currentTextContent
            case "ojp:EndTime":
                currentTripEvent?.endTime = currentTextContent
            case "ojp:Transfers":
                currentTripEvent?.transfers = currentTextContent
            case "ojp:LegId":
                currentTripLeg?.id = currentTextContent
            case "ojp:JourneyRef":
                currentTripLeg?.journeyRef = currentTextContent
            case "ojp:OperatingDayRef":
                currentTripLeg?.operatingDayRef = currentTextContent
            case "ojp:TransferMode":
                if currentTextContent == "walk" {
                    currentTripLeg?.transfer = true
                }
            case "ojp:IndividualMode":
                if currentTextContent == "walk" {
                    currentTripLeg?.transfer = true
                }
            case "ojp:WalkDuration":
                currentTripLeg?.transferWalkDuration = currentTextContent
            case "ojp:BufferTime":
                currentTripLeg?.transferBuffer = currentTextContent
            default:
                break
            }
            //            }
            /*if linkProjection && elementName == "ojp:Position" {
             if let position = currentPosition {
             currentTripLeg?.legTrack.append(position)
             }
             } else */if elementName == "ojp:TripLeg" {
                 if var leg = currentTripLeg {
                     if let boardData = stopPlaceRefMap[leg.legBoardStopId] {
                         leg.legBoardLongitude = boardData.longitude
                         leg.legBoardLatitude = boardData.latitude
                     }
                     if let alightData = stopPlaceRefMap[leg.legAlightStopId] {
                         leg.legAlightLongitude = alightData.longitude
                         leg.legAlightLatitude = alightData.latitude
                     }
                     leg.legIntermediates = currentIntermediates
                     currentLegs.append(leg)
                     currentTripLeg = nil
                     currentIntermediates = []
                 }
             } else if elementName == "ojp:TripResult" {
                 if var trip = currentTripEvent {
                     trip.legs = currentLegs
                     tripEvents.append(trip)
                     currentLegs = []
                     currentTripEvent = nil
                 }
             } else if elementName == "ojp:TripResponseContext" {
                 insideTripResponseContext = false
             } else if elementName == "ojp:LegBoard" {
                 legBoard = false
             } else if elementName == "ojp:LegAlight" {
                 legAlight = false
             } else if elementName == "ojp:LegIntermediates" {
                 legIntermediates = false
                 
                 if var intermediateData = currentLegIntermediate {
                     if let longitude = stopPlaceRefMap[intermediateData.stopId]?.longitude, let latitude = stopPlaceRefMap[intermediateData.stopId]?.latitude {
                         intermediateData.longitude = longitude
                         intermediateData.latitude = latitude
                     }
                     currentIntermediates.append(intermediateData)
                     currentLegIntermediate = nil
                 }
             } else if elementName == "ojp:LinkProjection" {
                 linkProjection = false
             } else if elementName == "ojp:TripLeg" {
                 insideLeg = false
             }
            currentTextContent = ""
            currentElement = ""
            if parentElement == elementName {
                parentElement = ""
            }
        }
    }
    let parserDelegate = TripEventParserDelegate(startCoordinates: startCoordinate, endCoordinates: endCoordinates, startName: startName, endName: endName, startCode: startCode, endCode: endCode, geoDeparture: geoDeparture, geoArrival: geoArrival)
    let parser = XMLParser(data: data)
    parser.delegate = parserDelegate
    parser.parse()
    
    if let error = parserDelegate.error {
        throw error
    }
    
    return parserDelegate.tripEvents // TripEvents
}
//    let result = parserDelegate.parse(data: data)
////    print("Finished parsing. Result:", result)
//    return result
//}



//Send XMLrequest
    public func fetchTrips(with departureStop: Stop?, with departureGeoPosition: GeoPosition?, with geoDeparture: Bool, with arrivalStop: Stop?, with arrivalGeoPosition: GeoPosition?, with geoArrival: Bool, with selectedTime: Date, with isArrivalTime: Bool, completion: @escaping (Bool, String?) -> Void) {
        
        let urlString = "https://api.opentransportdata.swiss/ojp2020"
        guard let url = URL(string: urlString) else { return }
        
        let outputFormatter1 = DateFormatter()
        outputFormatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        outputFormatter1.timeZone = TimeZone(secondsFromGMT: 0)
        let outputString1 = outputFormatter1.string(from: Date())
        
        let outputFormatter2 = DateFormatter()
        outputFormatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        outputFormatter2.timeZone = TimeZone(secondsFromGMT: 0)
        let tripTime = outputFormatter2.string(from: /*adjustedTime*/selectedTime)
        print("tripTime: ", tripTime)
        
        
        let xmlString = """
    <?xml version="1.0" encoding="utf-8"?>
    <OJP xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.siri.org.uk/siri" version="1.0" xmlns:ojp="http://www.vdv.de/ojp" xsi:schemaLocation="http://www.siri.org.uk/siri ../ojp-xsd-v1.0/OJP.xsd">
        <OJPRequest>
            <ServiceRequest>
                <RequestTimestamp>\(outputString1)</RequestTimestamp>
                <RequestorRef>API-Explorer</RequestorRef>
                <ojp:OJPTripRequest>
                    <RequestTimestamp>\(outputString1)</RequestTimestamp>
                    <ojp:Origin>
                        <ojp:PlaceRef>
                        \(geoDeparture ? """
                                <ojp:GeoPosition>
                                <Longitude>\(departureGeoPosition!.coordinate.longitude)</Longitude>
                                <Latitude>\(departureGeoPosition!.coordinate.latitude)</Latitude>
                                </ojp:GeoPosition>
                                """ : """
                                        <ojp:StopPlaceRef>\(departureStop!.sloid)</ojp:StopPlaceRef>
                                        """)
                            <ojp:LocationName>
                                <ojp:Text>\(geoDeparture ? departureGeoPosition!.name : departureStop!.name)</ojp:Text>
                            </ojp:LocationName>
                        </ojp:PlaceRef>
                        \(isArrivalTime ? "" : "<ojp:DepArrTime>\(tripTime)</ojp:DepArrTime>")
                    </ojp:Origin>
                    <ojp:Destination>
                        <ojp:PlaceRef>
                        \(geoArrival ? """
                             <ojp:GeoPosition>
                                   <Longitude>\(arrivalGeoPosition!.coordinate.longitude)</Longitude>
                                   <Latitude>\(arrivalGeoPosition!.coordinate.latitude)</Latitude>
                                </ojp:GeoPosition>
                             """ : """
                         <ojp:StopPlaceRef>\(arrivalStop!.sloid)</ojp:StopPlaceRef>
                         """)
                            <ojp:LocationName>
                                <ojp:Text>\(geoArrival ? arrivalGeoPosition!.name : arrivalStop!.name)</ojp:Text>
                            </ojp:LocationName>
                        </ojp:PlaceRef>
                        \(isArrivalTime ? "<ojp:DepArrTime>\(tripTime)</ojp:DepArrTime>" : "")
                    </ojp:Destination>
                    <ojp:Params>
                        <ojp:IncludeTrackSections>false</ojp:IncludeTrackSections>
                        <ojp:IncludeLegProjection>false</ojp:IncludeLegProjection>
                        <ojp:IncludeTurnDescription></ojp:IncludeTurnDescription>
                        <ojp:IncludeIntermediateStops>true</ojp:IncludeIntermediateStops>
                    </ojp:Params>
                </ojp:OJPTripRequest>
            </ServiceRequest>
        </OJPRequest>
    </OJP>
"""
        
        guard let xmlData = xmlString.data(using: .utf8) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue("text/XML", forHTTPHeaderField: "Content-Type")
        request.setValue(keySelect(), forHTTPHeaderField: "Authorization")
        request.httpBody = xmlData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                completion(false, nil)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(false, nil)
                return
            }
//            print("Request: \(xmlString)")
            
            if let responseString = String(data: data, encoding: .utf8) {
//                print("Response: \(responseString)")
                DispatchQueue.main.async {
                    // Assuming responseLine is a global variable
                    responseTrip = responseString
                    completion(true, responseString)
                }
            }
        }
        
        task.resume()
        
    }

public class FullTripTest: ObservableObject {
    @Published public var Trip: TripEvent
    public init() {
        self.Trip = TripEvent(id: "AAAA", duration: "PT50M", startTime: "2025-02-08T14:50:42Z", endTime: "2025-02-08T15:35:42Z", startCoordinates: Coordinates(lon: 0.0, lat: 0.0), endCoordinates: Coordinates(lon: 0.0, lat: 0.0), startName: "Meinier, église", endName: "Carouge, Rondeau", startCode: "", endCode: "", geoDeparture: false, geoArrival: false, transfers: "1", legs: [
            TripLeg(id: "A", transfer: true, legBoardStopName: "", legBoardStopId: "", legBoardQuay: "", legBoardTimetableTime: "2025-02-08T14:50:42Z", legBoardEstimatedTime: "2025-02-08T14:50:42Z", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "", legAlightStopId: "", legAlightQuay: "", legAlightTimetableTime: "2025-02-08T14:51:42Z", legAlightEstimatedTime: "2025-02-08T14:51:42Z", legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "", journeyRef: "", publishedLineName: "", legDuration: "PT1M", transferDuration: "PT1M", transferWalkDuration: "PT1M", transferBuffer: "PT1M", transportTypeName: "walk", legOperator: ""),
            TripLeg(id: "1234", legBoardStopName: "Meinier, église", legBoardStopId: "AAA", legBoardQuay: "A", legBoardTimetableTime: "2025-02-08T14:51:42Z", legBoardEstimatedTime: "2025-02-08T14:51:42Z", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "Genève, Place des Eaux-Vives", legAlightStopId: "BBB", legAlightQuay: "B", legAlightTimetableTime: "2025-02-08T15:10:42Z", legAlightEstimatedTime: "2025-02-08T15:10:42Z", legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "Genève, Rive", journeyRef: "", publishedLineName: "A", legDuration: "PT20M", transferDuration: "", transferWalkDuration: "", transferBuffer: "", transportTypeName: "Bus", legOperator: "Transports Publics Genevois"),
            TripLeg(id: "B", legBoardStopName: "", legBoardStopId: "", legBoardQuay: "", legBoardTimetableTime: "", legBoardEstimatedTime: "", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "", legAlightStopId: "", legAlightQuay: "", legAlightTimetableTime: "", legAlightEstimatedTime: "", legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "", journeyRef: "", publishedLineName: "", legDuration: "", transferDuration: "PT10M", transferWalkDuration: "PT4M", transferBuffer: "PT6M", transportTypeName: "", legOperator: ""),
            TripLeg(id: "5678", legBoardStopName: "Genève, Terrassière", legBoardStopId: "CCC", legBoardQuay: "C", legBoardTimetableTime: "2025-02-08T15:20:42Z", legBoardEstimatedTime: "2025-02-08T15:20:42Z", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "Carouge, Rondeau", legAlightStopId: "DDD", legAlightQuay: "D", legAlightTimetableTime: "2025-02-08T15:35:42Z", legAlightEstimatedTime: "2025-02-08T15:35:42Z", legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "Lancy-Bachet, Gare", journeyRef: "", publishedLineName: "12", legDuration: "PT20M", transferDuration: "", transferWalkDuration: "", transferBuffer: "", transportTypeName: "Tram", legOperator: "Transports Publics Genevois")
        ])
    }

}

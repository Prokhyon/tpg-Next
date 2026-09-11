//
//  TripFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 30.06.2024.
//

import Foundation
import SwiftUI

var responseTrip = ""

struct TripEvent: Codable, Identifiable {
    var id: String
    var duration: String
    var startTime: String
    var endTime: String
    var transfers: String
    var legs: [TripLeg]
}

struct TripLeg: Codable, Identifiable {
    var id: String
    var transfer: Bool = false
    var legBoardStopName: String
    var legBoardStopId: String
    var legBoardQuay: String
    var legBoardTimetableTime: String
    var legBoardEstimatedTime: String
    var legAlightStopName: String
    var legAlightStopId: String
    var legAlightQuay: String
    var legAlightTimetableTime: String
    var legAlightEstimatedTime: String
    var legDestination: String
    var journeyRef: String
    var publishedLineName: String
    var transferDuration: String
    var transferWalkDuration: String
    var transferBuffer: String
    var transportTypeName: String
}

func parseTripEvents(from data: Data) -> [TripEvent] {
    class TripEventParserDelegate: NSObject, XMLParserDelegate {
        
        private var currentElement = ""
        private var currentTripEvent: TripEvent?
        var currentTripLeg: TripLeg?
        var tripEvents: [TripEvent] = []
        var currentLegs: [TripLeg] = []
        
        private var insideTripEventResult = false
        private var insideTripResponseContext = false
        private var insideLeg = false
        private var legBoard = false
        private var legAlight = false
        
        private var currentStopPlaceRef = ""
        private var stopPlaceRefMap: [String: String] = [:] // Maps StopPointRef to StopPlaceRef
        private var currentStopPointRef = ""
        
        private var parentElement = ""
        private var currentTextContent: String = ""
        
        func parse(data: Data) -> [TripEvent] {
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
            return tripEvents
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            currentElement = elementName
            currentTextContent = "" // Reset text content on a new element
            
            if elementName == "ojp:TripResponseContext" {
                insideTripResponseContext = true
            } else if elementName == "ojp:TripResult" {
                currentTripEvent = TripEvent(id: "", duration: "", startTime: "", endTime: "", transfers: "", legs: [])
                insideTripEventResult = true
            } else if elementName == "ojp:TripLeg" {
                currentTripLeg = TripLeg(id: "", legBoardStopName: "", legBoardStopId: "", legBoardQuay: "", legBoardTimetableTime: "", legBoardEstimatedTime: "", legAlightStopName: "", legAlightStopId: "", legAlightQuay: "", legAlightTimetableTime: "", legAlightEstimatedTime: "", legDestination: "", journeyRef: "", publishedLineName: "", transferDuration: "", transferWalkDuration: "", transferBuffer: "", transportTypeName: "")
            } else if elementName == "ojp:LegBoard" {
                legBoard = true
            } else if elementName == "ojp:LegAlight" {
                legAlight = true
            } else if currentElement == "ojp:StopPointName" || currentElement == "ojp:PlannedQuay" || currentElement == "ojp:PublishedLineName" || currentElement == "ojp:StopPlaceRef" || currentElement == "siri:StopPointRef" || currentElement == "ojp:DestinationText" || currentElement == "ojp:TransportTypeName" {
                parentElement = currentElement
            }
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentTextContent += string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            
            if !currentTextContent.isEmpty {
                if insideTripResponseContext && currentElement == "ojp:StopPlaceRef" {
                    currentStopPlaceRef = currentTextContent
                } else if insideTripResponseContext && currentElement == "siri:StopPointRef" {
                    stopPlaceRefMap[currentTextContent] = currentStopPlaceRef
                }
                
                if parentElement == "ojp:StopPointName" && currentElement == "ojp:Text" {
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
                case "ojp:Duration":
                    if currentTripLeg?.transfer == true {
                        currentTripLeg?.transferDuration = currentTextContent
                    } else {
                        currentTripEvent?.duration = currentTextContent
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
                case "ojp:TransferMode":
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
            }
            
            if elementName == "ojp:TripLeg" {
                if var leg = currentTripLeg {
                    if let boardRef = stopPlaceRefMap[leg.legBoardStopId] {
                        leg.legBoardStopId = boardRef
                    }
                    if let alightRef = stopPlaceRefMap[leg.legAlightStopId] {
                        leg.legAlightStopId = alightRef
                    }
                    currentLegs.append(leg)
                    currentTripLeg = nil
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
            }
            currentTextContent = ""
            currentElement = ""
            parentElement = ""
        }
    }
    let parserDelegate = TripEventParserDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = parserDelegate
    let result = parserDelegate.parse(data: data)
    print("Finished parsing. Result:", result)
    return result
}



//Send XMLrequest
class TripManager: ObservableObject {
    @Published var tripEvents: [TripEvent] = []
    let dateFormatter = DateFormatter()
    
    func selectTrip(with departureStop: Stop, with arrivalStop: Stop, with selectedTime: Date, with isDepartureTime: Bool) {
            fetchTrips(with: departureStop, with: arrivalStop, with: selectedTime, with: isDepartureTime) { success in
                if success {
                   print("success")
                    // Parse XML response
                    if let data = responseTrip.data(using: .utf8) {
                        self.tripEvents = parseTripEvents(from: data)
                    }
                    if !(self.tripEvents.last?.legs.first?.transfer ?? true) && self.tripEvents.last?.legs.first?.publishedLineName == "" {
                        let transferLast: TripEvent = self.tripEvents.last!
                        var tripEventsTransfer: [TripEvent] = self.tripEvents.dropLast()
                        tripEventsTransfer.insert(transferLast, at: 0)
                        self.tripEvents = tripEventsTransfer
                    }
                }
            }
           // print("Trip Response: \(tripEvents)")
        }
    
    func fetchTrips(with departureStop: Stop, with arrivalStop: Stop, with selectedTime: Date, with isDepartureTime: Bool, completion: @escaping (Bool) -> Void) {
        
        let urlString = "https://api.opentransportdata.swiss/ojp2020"
        guard let url = URL(string: urlString) else { return }
        
//        let oneHourLater = Date().addingTimeInterval(3600)
//        print(selectedTime >= Date())
//        var adjustedTime = (((selectedTime <= oneHourLater && selectedTime >= Date().addingTimeInterval(-60)) && isDepartureTime) ? oneHourLater : selectedTime)
        
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
                            <ojp:StopPlaceRef>\(departureStop.codedidoc)</ojp:StopPlaceRef>
                            <ojp:LocationName>
                                <ojp:Text>\(departureStop.name)</ojp:Text>
                            </ojp:LocationName>
                        </ojp:PlaceRef>
                        \(isDepartureTime ? "<ojp:DepArrTime>\(tripTime)</ojp:DepArrTime>" : "")
                    </ojp:Origin>
                    <ojp:Destination>
                        <ojp:PlaceRef>
                            <ojp:StopPlaceRef>\(arrivalStop.codedidoc)</ojp:StopPlaceRef>
                            <ojp:LocationName>
                                <ojp:Text>\(arrivalStop.name)</ojp:Text>
                            </ojp:LocationName>
                        </ojp:PlaceRef>
                        \(!isDepartureTime ? "<ojp:DepArrTime>\(tripTime)</ojp:DepArrTime>" : "")
                    </ojp:Destination>
                    <ojp:Params>
                        <ojp:IncludeTrackSections></ojp:IncludeTrackSections>
                        <ojp:IncludeTurnDescription></ojp:IncludeTurnDescription>
                        <ojp:IncludeIntermediateStops></ojp:IncludeIntermediateStops>
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
        request.setValue("***CLE-RETIREE***", forHTTPHeaderField: "Authorization")
        request.httpBody = xmlData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(false)
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
                DispatchQueue.main.async {
                    // Assuming responseLine is a global variable
                    responseTrip = responseString
                    completion(true)
                }
            }
        }
        
        task.resume()
        
    }
}

//
//  StopFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 17.06.2024.
//

import SwiftUI
import Foundation
import Combine


// Model to hold the data
public struct StopEvent: Codable, Identifiable, Hashable {
    public var stopPointName: String
    public var stopId: String
    public var plannedQuay: String
    public var timetabledTime: String
    public var estimatedTime: String
    public var lineName: String
    public var origin: String
    public var destination: String
    public var transportType: String
    public var operatorName: String
    public var journeyRef: String
    public var operatingDayRef: String
    
    public var id: String { journeyRef + timetabledTime }
    
    public init(stopPointName: String, stopId: String, plannedQuay: String, timetabledTime: String, estimatedTime: String, lineName: String, origin: String, destination: String, transportType: String, operatorName: String, journeyRef: String, operatingDayRef: String) {
        self.stopPointName = stopPointName
        self.stopId = stopId
        self.plannedQuay = plannedQuay
        self.timetabledTime = timetabledTime
        self.estimatedTime = estimatedTime
        self.lineName = lineName
        self.origin = origin
        self.destination = destination
        self.transportType = transportType
        self.operatorName = operatorName
        self.journeyRef = journeyRef
        self.operatingDayRef = operatingDayRef
    }
}

public struct Quay: Codable, Identifiable, Hashable {
    public var id: String
    public var quayName: String
    public var latitude: String
    public var longitude: String
}


//Send XMLrequest
    public func fetchTransportDepartures(with stopName: String, stopSloid: String, stopEventNumber: Int, timeRequest: Date, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "https://api.opentransportdata.swiss/ojp2020"
        guard let url = URL(string: urlString) else { return }
        
        let outputFormatter1 = DateFormatter()
        outputFormatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        outputFormatter1.timeZone = TimeZone(secondsFromGMT: 0)
        let requestTimestamp = outputFormatter1.string(from: timeRequest)
        
        // En UTC explicite : une heure locale sans fuseau n'est juste que si le téléphone est à l'heure suisse.
        let depArrTime = requestTimestamp
        
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <OJP xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.siri.org.uk/siri" version="1.0" xmlns:ojp="http://www.vdv.de/ojp" xsi:schemaLocation="http://www.siri.org.uk/siri ../ojp-xsd-v1.0/OJP.xsd">
            <OJPRequest>
                <ServiceRequest>
                    <RequestTimestamp>\(requestTimestamp)</RequestTimestamp>
                    <RequestorRef>API-Explorer</RequestorRef>
                    <ojp:OJPStopEventRequest>
                        <RequestTimestamp>\(requestTimestamp)</RequestTimestamp>
                        <ojp:Location>
                            <ojp:PlaceRef>
                                <StopPlaceRef>\(stopSloid.xmlEscaped)</StopPlaceRef>
                                <ojp:LocationName>
                                    <ojp:Text>\(stopName.xmlEscaped)</ojp:Text>
                                </ojp:LocationName>
                            </ojp:PlaceRef>
                            <ojp:DepArrTime>\(depArrTime)</ojp:DepArrTime>
                        </ojp:Location>
                        <ojp:Params>
                            <ojp:NumberOfResults>\(stopEventNumber)</ojp:NumberOfResults>
                            <ojp:StopEventType>departure</ojp:StopEventType>
                            <ojp:IncludeRealtimeData>true</ojp:IncludeRealtimeData>
                        </ojp:Params>
                    </ojp:OJPStopEventRequest>
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
                Log.network.error("Départs : \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false, nil) }
                return
            }
            
            guard let data = data else {
                Log.network.error("Départs : réponse vide")
                DispatchQueue.main.async { completion(false, nil) }
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
//                    print(xmlString)
                    completion(true, responseString)
                }
            }
        }
        
        task.resume()
    }
    
    public func parseStopEvents(from data: Data, stopCode: String, completion: @escaping ([StopEvent], [Quay], ParserError?) -> Void) {
        class StopEventParserDelegate: NSObject, XMLParserDelegate {
            var error: ParserError?
            
            var stopEvents: [StopEvent] = []
            var quays: [Quay] = []
            var positions: [Quay] = []
            
            private var stopCode: String
            private var stopPointRef = ""
            private var currentElement = ""
            private var currentStopEvent: StopEvent?
            private var currentquay: Quay = Quay(id: "", quayName: "", latitude: "", longitude: "")
            
            private var insideStopEventResponseContext = false
            private var insideLocation = false
            private var insideStopPoint = false
            private var insideStopEventResult = false
            
            private var currentStopPointName = ""
            private var currentPlannedQuay = ""
            private var currentTimetabledTime = ""
            private var currentEstimatedTime = ""
            private var currentLineName = ""
            private var currentOrigin = ""
            private var currentDestination = ""
            private var currentTransportType = ""
            private var currentOperatorName = ""
            
            private var parentElement = ""
            
            init(stopCode: String) {
                    self.stopCode = stopCode
                }
            
            func parse(data: Data) -> ([StopEvent], [Quay], ParserError?) {
                let parser = XMLParser(data: data)
                parser.delegate = self
                parser.parse()
                return (stopEvents, positions, error)
            }
            
            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                currentElement = elementName
                
                if elementName.hasPrefix("siri:") {
                    currentElement = String(elementName.dropFirst(5))
                } else if elementName.hasPrefix("ojp:") {
                    currentElement = String(elementName.dropFirst(4))
                }
                
                if elementName == "ojp:StopEventResult" {
                    currentStopEvent = StopEvent(stopPointName: "", stopId: stopCode, plannedQuay: "", timetabledTime: "", estimatedTime: "", lineName: "", origin: "", destination: "", transportType: "", operatorName: "", journeyRef: "", operatingDayRef: "")
                    insideStopEventResult = true
                } else if elementName == "ojp:StopEventResponseContext" {
                    insideStopEventResponseContext = true
                } else if elementName == "ojp:Location" {
                    currentquay = Quay(id: "", quayName: "", latitude: "", longitude: "")
                    insideLocation = true
                } else if elementName == "ojp:StopPoint" {
                    insideStopPoint = true
                } else if currentElement == "StopPointName" || currentElement == "OriginText" || currentElement == "DestinationText" || currentElement == "PlannedQuay" || currentElement == "EstimatedTime" || currentElement == "PublishedLineName" || currentElement == "TransportTypeName" || currentElement == "OperatorName" {
                    parentElement = currentElement
                }
            }
            
            var currentTextContent: String = ""
            
            func parser(_ parser: XMLParser, foundCharacters string: String) {
                currentTextContent += string
            }
            
            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                let trimmedString = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if currentElement == "ErrorText" {
//                    print("StopErrorFound")
                    error = .noEventFound(message: trimmedString)
                }
                if insideStopEventResponseContext {
                    if insideLocation {
                        if insideStopPoint {
                            if currentElement == "StopPointRef" {
                                currentquay.id = trimmedString
                            } else if currentElement == "Value" {
                                currentquay.quayName = String(trimmedString.dropFirst(9))
                            } else if elementName == "ojp:StopPoint" {
                                insideStopPoint = false
                            }
                        }
                        if currentElement == "Longitude" {
                            currentquay.longitude = trimmedString
                        } else if currentElement == "Latitude" {
                            currentquay.latitude = trimmedString
                        } else if elementName == "ojp:Location" {
                            if !currentquay.id.isEmpty {
                                positions.append(currentquay)
//                                print(currentquay)
                                currentquay = Quay(id: "", quayName: "", latitude: "", longitude: "")
                                insideLocation = false
                            }
                        }
                    }
                    if elementName == "ojp:StopEventResponseContext" {
                        insideStopEventResponseContext = false
                    }
                }
                if insideStopEventResult && !trimmedString.isEmpty {
                    if parentElement == "StopPointName" && currentElement == "Text" {
                        currentStopEvent?.stopPointName = trimmedString
                    } else if parentElement == "OriginText" && currentElement == "Text" {
                        currentStopEvent?.origin = trimmedString
                    } else if parentElement == "DestinationText" && currentElement == "Text" {
                        currentStopEvent?.destination = trimmedString
                    } else if parentElement == "PlannedQuay" && currentElement == "Text" {
                        currentStopEvent?.plannedQuay = trimmedString
                    } else if parentElement == "EstimatedTime" && currentElement == "Text" {
                        currentStopEvent?.estimatedTime = trimmedString
                    } else if parentElement == "PublishedLineName" && currentElement == "Text" {
                        currentStopEvent?.lineName = trimmedString
                    } else if parentElement == "TransportTypeName" && currentElement == "Text" {
                        currentStopEvent?.transportType = trimmedString
                    } else if parentElement == "OperatorName" && currentElement == "Text" {
                        currentStopEvent?.operatorName = trimmedString
                    } else {
                        switch currentElement {
                        case "StopPointName":
                            currentStopEvent?.stopPointName = trimmedString
                        case "PlannedQuay":
                            currentStopEvent?.plannedQuay = trimmedString
                        case "TimetabledTime":
                            currentStopEvent?.timetabledTime = trimmedString
                        case "EstimatedTime":
                            currentStopEvent?.estimatedTime = trimmedString
                        case "PublishedLineName":
                            currentStopEvent?.lineName = trimmedString
                        case "OriginText":
                            currentStopEvent?.origin = trimmedString
                        case "DestinationText":
                            currentStopEvent?.destination = trimmedString
                        case "TransportTypeName":
                            currentStopEvent?.transportType = trimmedString
                        case "OperatorName":
                            currentStopEvent?.operatorName = trimmedString
                        case "JourneyRef":
                            currentStopEvent?.journeyRef = trimmedString
                        case "OperatingDayRef":
                            currentStopEvent?.operatingDayRef = trimmedString
                        default:
                            break
                        }
                    }
                }
                
                if elementName == "ojp:StopEventResult" {
                    if var stopEvent = currentStopEvent {
                        // Ensure estimatedTime is set if not provided
                        if stopEvent.estimatedTime.isEmpty {
                            stopEvent.estimatedTime = stopEvent.timetabledTime
                        }
                        stopEvents.append(stopEvent)
                        currentStopEvent = nil
                    }
                    insideStopEventResult = false
                }
                
                currentTextContent = ""
                currentElement = ""
                parentElement = ""
            }
        }
        
        DispatchQueue.global(qos: .background).async {
            let parserDelegate = StopEventParserDelegate(stopCode: stopCode)
            let (stopEvents, positions, error) = parserDelegate.parse(data: data)
            DispatchQueue.main.async {
                completion(stopEvents, positions, error)
            }
        }
    }


public func createStopEventFromTripLeg(tripLeg: TripLeg) -> StopEvent {
    let stopEvent = StopEvent(stopPointName: "", stopId: tripLeg.legBoardStopId, plannedQuay: "", timetabledTime: tripLeg.legBoardTimetableTime, estimatedTime: "", lineName: tripLeg.publishedLineName, origin: "", destination: tripLeg.legDestination, transportType: tripLeg.transportTypeName, operatorName: tripLeg.legOperator, journeyRef: tripLeg.journeyRef, operatingDayRef: tripLeg.resolvedOperatingDayRef)
    return stopEvent
}

public func createEssentialStopEvent(journeyRef: String, operatingDayRef: String, stopPointName: String?, stopId: String?, lineName: String?, origin: String?, destination: String?, transportType: String?, operatorName: String?) -> StopEvent {
    let stopEvent = StopEvent(stopPointName: stopPointName ?? "", stopId: stopId ?? "", plannedQuay: "", timetabledTime: "", estimatedTime: "", lineName: lineName ?? "", origin: origin ?? "", destination: destination ?? "", transportType: transportType ?? "", operatorName: operatorName ?? "", journeyRef: journeyRef, operatingDayRef: operatingDayRef)
    return stopEvent
}

public func createStop(nomarret: String?, sloid: String) -> Stop {
    let stop = Stop(name: nomarret ?? "", sloid: sloid, codedidoc: "", country: "", canton: "", meansOfTransport: "", wgs84Coordinates: Coordinates(lon: 0.0, lat: 0.0))
    return stop
}

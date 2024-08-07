//
//  StopFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 17.06.2024.
//

import SwiftUI
import Foundation

var responseStop = ""
//let dateFormatter = DateFormatter()


// Model to hold the data
struct StopEvent: Codable, Identifiable {
    var id = UUID() // Unique identifier for each StopEvent
    var stopPointName: String
    var plannedQuay: String
    var timetabledTime: String
    var estimatedTime: String
    var lineName: String
    var origin: String
    var destination: String
    var transportType: String
    var operatorName: String
    var journeyRef: String
    var operatingDayRef: String
}


func parseStopEvents(from data: Data) -> [StopEvent] {
    class StopEventParserDelegate: NSObject, XMLParserDelegate {
        var stopEvents: [StopEvent] = []
        private var currentElement = ""
        private var currentStopEvent: StopEvent?
        
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
        
        func parse(data: Data) -> [StopEvent] {
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
            return stopEvents
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            currentElement = elementName
            
            if elementName.hasPrefix("siri:") {
                currentElement = String(elementName.dropFirst(5))
            } else if elementName.hasPrefix("ojp:") {
                currentElement = String(elementName.dropFirst(4))
            }
            
            if elementName == "ojp:StopEventResult" {
                currentStopEvent = StopEvent(stopPointName: "", plannedQuay: "", timetabledTime: "", estimatedTime: "", lineName: "", origin: "", destination: "", transportType: "", operatorName: "", journeyRef: "", operatingDayRef: "")
                insideStopEventResult = true
            } else if currentElement == "StopPointName" || currentElement == "OriginText" || currentElement == "DestinationText" || currentElement == "PlannedQuay" || currentElement == "EstimatedTime" || currentElement == "PublishedLineName" || currentElement == "TransportTypeName" || currentElement == "OperatorName"{
                parentElement = currentElement
            }
        }
        
        var currentTextContent: String = ""
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentTextContent += string
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let trimmedString = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
            
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
                    if stopEvent.estimatedTime.isEmpty {
                     stopEvent.estimatedTime = stopEvent.timetabledTime
                          }
                    stopEvents.append(stopEvent)
                    currentStopEvent = nil
                    //print(stopEvents)
                }
                insideStopEventResult = false
            }
            
            currentTextContent = ""
            currentElement = ""
            parentElement = ""
        }
    }
    let parserDelegate = StopEventParserDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = parserDelegate
    parser.parse()

    return parserDelegate.stopEvents
}

//Send XMLrequest
class StopManager: ObservableObject {
    @Published var stopEvents: [StopEvent] = []
    
    func selectStop(_ stop: Stop, stopEventNumber: Int) {
        //print("selectStop")
        fetchTransportDepartures(with: stop, with: stopEventNumber) { success in
                if success {
                    //print("ftd-Success")
                    // Parse XML response
                    if let data = responseStop.data(using: .utf8) {
                        self.stopEvents = parseStopEvents(from: data)
                    }
                }
            }
        }
    
    func fetchTransportDepartures(with stop: Stop, with stopEventNumber: Int, completion: @escaping (Bool) -> Void) {
        //let stopEventNumber: Int
        let urlString = "https://api.opentransportdata.swiss/ojp2020"
        guard let url = URL(string: urlString) else { return }
        
        let outputFormatter1 = DateFormatter()
        outputFormatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        outputFormatter1.timeZone = TimeZone(secondsFromGMT: 0)
        let outputString1 = outputFormatter1.string(from: Date())

        // Step 3: Convert Date to desired output format 2: "2024-06-24T15:13:57"
        let outputFormatter2 = DateFormatter()
        outputFormatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        outputFormatter2.timeZone = TimeZone(secondsFromGMT: 2 * 3600) // GMT+2
        let outputString2 = outputFormatter2.string(from: Date())

        
        let xmlString = """
    <?xml version="1.0" encoding="UTF-8"?>
        <OJP xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.siri.org.uk/siri" version="1.0" xmlns:ojp="http://www.vdv.de/ojp" xsi:schemaLocation="http://www.siri.org.uk/siri ../ojp-xsd-v1.0/OJP.xsd">
            <OJPRequest>
                <ServiceRequest>
                    <RequestTimestamp>\(outputString1)</RequestTimestamp>
                    <RequestorRef>API-Explorer</RequestorRef>
                    <ojp:OJPStopEventRequest>
                        <RequestTimestamp>\(outputString1)</RequestTimestamp>
                        <ojp:Location>
                            <ojp:PlaceRef>
                                <StopPlaceRef>\(stop.codedidoc)</StopPlaceRef>
                                <ojp:LocationName>
                                    <ojp:Text>\(stop.nomarret)</ojp:Text>
                                </ojp:LocationName>
                            </ojp:PlaceRef>
                            <ojp:DepArrTime>\(outputString2)</ojp:DepArrTime>
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
        request.setValue("eyJvcmciOiI2NDA2NTFhNTIyZmEwNTAwMDEyOWJiZTEiLCJpZCI6ImFhODIyNjI1MTNlNzQzNTc5YzM3ODBlN2E4ZGM4YWRjIiwiaCI6Im11cm11cjEyOCJ9", forHTTPHeaderField: "Authorization")
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
             //print("Response: \(responseString)")
                //print("response received")
                DispatchQueue.main.async {
                    // Assuming responseStop is a global variable
                    responseStop = responseString
                    completion(true)
                }
            }
        }
        
        task.resume()
        
    }
}
func createStopEventFromTripLeg(tripLeg: TripLeg) -> StopEvent {
    let stopEvent = StopEvent(stopPointName: "", plannedQuay: "", timetabledTime: "", estimatedTime: "", lineName: "", origin: "", destination: "", transportType: "", operatorName: "", journeyRef: tripLeg.journeyRef, operatingDayRef: "\(tripLeg.legBoardTimetableTime.dropLast(10))")
    return stopEvent
}

func stopFromId(by codedidoc: Int) -> Stop? {
    // Assuming stopStore is already defined somewhere in your scope
    let stopStore = StopStore()

    
    // Return the first Stop with the matching codedidoc
    return stopStore.activeStops.first { $0.codedidoc == codedidoc }
}


#Preview {
    ContentView()
}

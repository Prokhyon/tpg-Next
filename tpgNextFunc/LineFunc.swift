//
//  LineFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 21.06.2024.
//

import Foundation
import SwiftUI
import Combine


var responseLine = ""

public struct LineEvent: Codable, Identifiable, Hashable {
    
    public var stopPointName: String
    public var plannedQuay: String
    public var timetabledTime: String
    public var estimatedTime: String
    public var stopPlaceRef: String
    public var sloid: String
    public var previousCall: Bool
    public var longitude: String
    public var latitude: String

    public var id: String { sloid + timetabledTime }
    
}


//Send XMLrequest
public func fetchTransportJourney(with stopEvent: StopEvent, calls: Bool = true, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "https://api.opentransportdata.swiss/ojp2020"
        guard let url = URL(string: urlString) else { return }
        
        let outputFormatter1 = DateFormatter()
        outputFormatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        outputFormatter1.timeZone = TimeZone(secondsFromGMT: 0)
        let outputString1 = outputFormatter1.string(from: Date())
        
        
        let xmlString = """
    <?xml version="1.0" encoding="utf-8"?>
    <OJP xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.siri.org.uk/siri" version="1.0" xmlns:ojp="http://www.vdv.de/ojp" xsi:schemaLocation="http://www.siri.org.uk/siri ../ojp-xsd-v1.0/OJP.xsd">
        <OJPRequest>
            <ServiceRequest>
                <RequestTimestamp>\(outputString1)</RequestTimestamp>
                <RequestorRef>tpgNext</RequestorRef>
                <ojp:OJPTripInfoRequest>
                    <RequestTimestamp>\(outputString1)</RequestTimestamp>
                    <ojp:JourneyRef>\(stopEvent.journeyRef)</ojp:JourneyRef>
                    <ojp:OperatingDayRef>\(stopEvent.operatingDayRef)</ojp:OperatingDayRef>
                    <ojp:Params>
                        <ojp:IncludeCalls>\(calls ? "true" : "false")</ojp:IncludeCalls>
                        <ojp:IncludeService>\(calls ? "true" : "false")</ojp:IncludeService>
                    </ojp:Params>
                </ojp:OJPTripInfoRequest>
            </ServiceRequest>
        </OJPRequest>
    </OJP>
    """
        
        guard let xmlData = xmlString.data(using: .utf8) else { return }
        print(xmlString)
    
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
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
                DispatchQueue.main.async {
                    // Assuming responseLine is a global variable
                    responseLine = responseString
                    completion(true, responseString)
                }
            }
        }
        
        task.resume()
        
    }
    
    public func parseJourneyEvents(from data: Data, completion: @escaping ([LineEvent], String) -> Void) {
        class StopEventParserDelegate: NSObject, XMLParserDelegate {
            var lineEvents: [LineEvent] = []
            private var currentElement = ""
            private var currentLineEvent: LineEvent?
            
            private var insideLineEventResult = false
            private var insideTripInfoResponseContext = false
            private var insideStopPoint = false
            private var insideStopPlace = false
            
            private var currentStopPointName = ""
            private var currentPlannedQuay = ""
            private var currentTimetabledTime = ""
            private var currentEstimatedTime = ""
            private var currentStopPlaceRef = ""
            private var currentLongitude = ""
            private var currentLatitude = ""
            
            var operatorName = ""
            
            private var stopPlaceRefMap: [String: (stopPointRef: String, longitude: String, latitude: String)] = [:]
            private var currentStopPointRef = ""
            
            private var parentElement = ""
            
            func parse(data: Data) -> ([LineEvent], String) {
                let parser = XMLParser(data: data)
                parser.delegate = self
                parser.parse()
                return (lineEvents, operatorName)
            }
            
            var currentTextContent: String = ""
            
            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                currentElement = elementName
                
                if elementName.hasPrefix("siri:") {
                    currentElement = String(elementName.dropFirst(5))
                } else if elementName.hasPrefix("ojp:") {
                    currentElement = String(elementName.dropFirst(4))
                }
                
                if elementName == "ojp:TripInfoResponseContext" {
                    insideTripInfoResponseContext = true
                } else if elementName == "ojp:OnwardCall" || elementName == "ojp:PreviousCall" {
                    currentLineEvent = LineEvent(stopPointName: "", plannedQuay: "", timetabledTime: "", estimatedTime: "", stopPlaceRef: "", sloid: "", previousCall: false, longitude: "", latitude: "")
                    insideLineEventResult = true
                } else if elementName == "ojp:StopPoint" {
                    insideStopPoint = true
                } else if elementName == "ojp:StopPlace" {
                    insideStopPlace = true
                } else if currentElement == "StopPointName" || currentElement == "PlannedQuay" || currentElement == "OperatorName" {
                    parentElement = currentElement
                }
            }
            
            func parser(_ parser: XMLParser, foundCharacters string: String) {
                currentTextContent += string
            }
            
            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                let trimmedString = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if insideTripInfoResponseContext {

                    if !trimmedString.isEmpty || elementName == "ojp:Location" || elementName == "ojp:StopPoint" || elementName == "ojp:StopPlace" {
                        if elementName == "ojp:StopPoint" {
                            insideStopPoint = false
                        } else if elementName == "ojp:StopPlace" {
                            insideStopPlace = false
                        } else if elementName == "ojp:Location" && !currentStopPlaceRef.isEmpty && !currentStopPointRef.isEmpty && !currentLongitude.isEmpty && !currentLatitude.isEmpty {
                            // Store the stopPointRef along with its geolocation data
                            stopPlaceRefMap[currentStopPointRef] = (stopPointRef: currentStopPlaceRef, longitude: currentLongitude, latitude: currentLatitude)
                            // Reset current values for the next Location
                            currentStopPlaceRef = ""
                            currentStopPointRef = ""
                            currentLongitude = ""
                            currentLatitude = ""
                        } else if insideStopPoint {
                            if currentElement == "StopPointRef" {
                                currentStopPointRef = currentTextContent
                                currentStopPlaceRef = currentTextContent
                            } else if currentElement == "ParentRef" {
                                currentStopPlaceRef = currentTextContent
                            }
                        } else if !currentStopPointRef.isEmpty && !currentStopPlaceRef.isEmpty {
                            if currentElement == "Longitude" {
                                currentLongitude = currentTextContent
                            } else if currentElement == "Latitude" {
                                currentLatitude = currentTextContent
                            } else if elementName == "ojp:Location" {
                                currentStopPlaceRef = ""
                                currentStopPointRef = ""
                                currentLongitude = ""
                                currentLatitude = ""
                            }
                        } else if elementName == "ojp:Location" && !currentStopPlaceRef.isEmpty && !currentLongitude.isEmpty && !currentLatitude.isEmpty {
                                stopPlaceRefMap[currentStopPlaceRef] = (stopPointRef: currentStopPlaceRef, longitude: currentLongitude, latitude: currentLatitude)
                            // Reset current values for the next Location
                            currentStopPlaceRef = ""
                            currentStopPointRef = ""
                            currentLongitude = ""
                            currentLatitude = ""
                        } else if insideStopPlace {
                            if currentElement == "StopPlaceRef" {
                                currentStopPlaceRef = currentTextContent
                            }
                        } else if !currentStopPlaceRef.isEmpty {
                            if currentElement == "Longitude" {
                                currentLongitude = currentTextContent
                            } else if currentElement == "Latitude" {
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
                
                if insideLineEventResult && !trimmedString.isEmpty {
                    if parentElement == "StopPointName" && currentElement == "Text" {
                        currentLineEvent?.stopPointName = trimmedString
                    } else if parentElement == "PlannedQuay" && currentElement == "Text" {
                        currentLineEvent?.plannedQuay = trimmedString
                    } else if currentElement == "TimetabledTime" {
                        currentLineEvent?.timetabledTime = trimmedString
                    } else if currentElement == "EstimatedTime" {
                        currentLineEvent?.estimatedTime = trimmedString.isEmpty ? currentLineEvent?.timetabledTime ?? "" : trimmedString
                    } else if currentElement == "StopPointRef" {
                        currentStopPointRef = trimmedString
                        currentLineEvent?.stopPlaceRef = trimmedString
                    }
                }
                
                if elementName == "ojp:TripInfoResponseContext" {
                    insideTripInfoResponseContext = false
                } else if elementName == "ojp:PreviousCall" {
                    if var lineEvent = currentLineEvent {
                        if let stopData = stopPlaceRefMap[currentStopPointRef] {
                            lineEvent.previousCall = true
                            lineEvent.sloid = stopData.stopPointRef
                            lineEvent.longitude = stopData.longitude
                            lineEvent.latitude = stopData.latitude
                        }
                        lineEvents.append(lineEvent)
                        currentLineEvent = nil
                    }
                    insideLineEventResult = false
                } else if elementName == "ojp:OnwardCall" {
                    if var lineEvent = currentLineEvent {
                        if let stopData = stopPlaceRefMap[currentStopPointRef] {
                            lineEvent.sloid = stopData.stopPointRef
                            lineEvent.longitude = stopData.longitude
                            lineEvent.latitude = stopData.latitude
                        }
                        lineEvents.append(lineEvent)
                        currentLineEvent = nil
                    }
                    insideLineEventResult = false
                } else if parentElement == "OperatorName" && currentElement == "Text" {
                    operatorName = trimmedString
                }
                
                currentTextContent = ""
                currentElement = ""
                parentElement = ""
            }
        }
        
        DispatchQueue.global(qos: .background).async {
            let parserDelegate = StopEventParserDelegate()
            let parser = XMLParser(data: data)
            parser.delegate = parserDelegate
            let result = parserDelegate.parse(data: data)
            DispatchQueue.main.async {
                completion(result.0, result.1)
            }
        }
    }

public struct BusLineIcon: View {
    let lineName: String
    let operatorName: String
    
    public init(lineName: String, operatorName: String) {
        self.lineName = lineName
        self.operatorName = operatorName
    }

    public var body: some View {
           ZStack {
               Text(lineName)
                   
                   .padding(.horizontal, 8)
                   .padding(.vertical, 4)
                   .frame(minWidth: 35, maxHeight: 25)
                   .background(
//                       RoundedRectangle(cornerRadius: 10)
                    Capsule()
                        .stroke(LineColors.lineColor(for: lineName, operatorName: operatorName), lineWidth: 4)
                   )
           }
       }
   }

public func stopEventToLineEvent(stopEvent: StopEvent, stopID: String) -> LineEvent {
    return LineEvent(stopPointName: stopEvent.stopPointName, plannedQuay: stopEvent.plannedQuay, timetabledTime: stopEvent.timetabledTime, estimatedTime: stopEvent.estimatedTime, stopPlaceRef: stopID, sloid: stopID, previousCall: false, longitude: "", latitude: "")
}

//
//  ContentView.swift
//  TPG4
//
//  Created by Loris Thomas on 17.06.2024.
//

import SwiftUI
import Foundation

//model to hold the data
struct StopEvent {
    var stopPointName: String
    var plannedQuay: String
    var timetabledTime: String
    var estimatedTime: String
    var lineName: String
    var origin: String
    var destination: String
    var transportType: String
    var operatorName: String
}



//XMLParserDelegate to handle the parsing
class StopEventParser: NSObject, XMLParserDelegate {
    private var stopEvents: [StopEvent] = []
    private var currentElement = ""
    private var currentStopEvent: StopEvent?
    
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
        
        // Handle namespaces
        if elementName.hasPrefix("siri:") {
            currentElement = String(elementName.dropFirst(5))
        } else if elementName.hasPrefix("ojp:") {
            currentElement = String(elementName.dropFirst(4))
        }
        
        if elementName == "ojp:StopEvent" {
            currentStopEvent = StopEvent(stopPointName: "", plannedQuay: "", timetabledTime: "", estimatedTime: "", lineName: "", origin: "", destination: "", transportType: "", operatorName: "")
        } else if currentElement == "StopPointName" || currentElement == "OriginText" || currentElement == "DestinationText" || currentElement == "PlannedQuay" || currentElement == "EstimatedTime" || currentElement == "PublishedLineName" || currentElement == "TransportTypeName" || currentElement == "OperatorName"{
            parentElement = currentElement
        }
        print("Started \(currentElement)")
        print("Parent \(parentElement)")
    }
    
    var currentTextContent: String = ""
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentTextContent += string
        print("found \(currentTextContent)")
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmedString = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedString.isEmpty {
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
                        }
            else {
                            switch currentElement {
                            case "StopPointName":
                                currentStopEvent?.stopPointName = trimmedString
                                print("StopPointName")
                            case "PlannedQuay":
                                currentStopEvent?.plannedQuay = trimmedString
                                print("PlannedQuay")
                            case "TimetabledTime":
                                currentStopEvent?.timetabledTime = trimmedString
                                print("TimetableTime")
                            case "EstimatedTime":
                                currentStopEvent?.estimatedTime = trimmedString
                                print("EstimatedTime")
                            case "PublishedLineName":
                                currentStopEvent?.lineName = trimmedString
                                print("PublishedLineName")
                            case "OriginText":
                                currentStopEvent?.origin = trimmedString
                                print("OrigineText")
                            case "DestinationText":
                                currentStopEvent?.destination = trimmedString
                                print("DestinationText")
                            case "TransportTypeName":
                                currentStopEvent?.transportType = trimmedString
                                print("TransportTypeName")
                            case "OperatorName":
                                currentStopEvent?.operatorName = trimmedString
                                print("OperatorName")
                            default:
                                break
                            }
                        }
            print("End \(currentElement)")
        }
        
        if elementName == "ojp:StopEvent" {
            if let stopEvent = currentStopEvent {
                stopEvents.append(stopEvent)
                currentStopEvent = nil
            }
        }
        
        // Reset current text content for next element
        currentTextContent = ""
        currentElement = ""
        parentElement = ""
    }
}


struct ContentView: View {
    @State private var responseStop = ""
    @State private var stopEvents: [StopEvent] = []
    
    var body: some View {
        VStack {
            Button(action: fetchTransportDepartures) {
                Text("Fetch Transport Departures")
            }
            
            Button(action: {
                if !responseStop.isEmpty {
                    if let data = responseStop.data(using: .utf8) {
                        let parser = StopEventParser()
                        self.stopEvents = parser.parse(data: data)
                        print("Parsed stop events: \(self.stopEvents)")
                    }
                }
            }) {
                Text("Parse XML Response")
            }
            
            List(stopEvents, id: \.stopPointName) { event in
                VStack(alignment: .leading) {
                    Text("Stop Point: \(event.stopPointName)")
                    Text("Planned Quay: \(event.plannedQuay)")
                    Text("Timetabled Time: \(event.timetabledTime)")
                    Text("Estimated Time: \(event.estimatedTime)")
                    Text("Line: \(event.lineName)")
                    Text("Origin: \(event.origin)")
                    Text("Destination: \(event.destination)")
                    Text("Transport Type: \(event.transportType)")
                    Text("Operator: \(event.operatorName)")
                }
            }
        }
        .padding()
    }
    
    func fetchTransportDepartures() {
        // URL for the OJP StopEventService
        let urlString = "https://api.opentransportdata.swiss/ojp2020"
        guard let url = URL(string: urlString) else { return }

        // XML payload
        let xmlString = """
        <?xml version="1.0" encoding="UTF-8"?>
        <OJP xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.siri.org.uk/siri" version="1.0" xmlns:ojp="http://www.vdv.de/ojp" xsi:schemaLocation="http://www.siri.org.uk/siri ../ojp-xsd-v1.0/OJP.xsd">
            <OJPRequest>
                <ServiceRequest>
                    <RequestTimestamp>2024-06-17T15:52:15.113Z</RequestTimestamp>
                    <RequestorRef>API-Explorer</RequestorRef>
                    <ojp:OJPStopEventRequest>
                        <RequestTimestamp>2024-06-17T15:52:15.113Z</RequestTimestamp>
                        <ojp:Location>
                            <ojp:PlaceRef>
                                <StopPlaceRef>8507000</StopPlaceRef>
                                <ojp:LocationName>
                                    <ojp:Text>Bern</ojp:Text>
                                </ojp:LocationName>
                            </ojp:PlaceRef>
                            <ojp:DepArrTime>2024-06-17T17:52:15</ojp:DepArrTime>
                        </ojp:Location>
                        <ojp:Params>
                            <ojp:NumberOfResults>1</ojp:NumberOfResults>
                            <ojp:StopEventType>departure</ojp:StopEventType>
                            <ojp:IncludeRealtimeData>true</ojp:IncludeRealtimeData>
                        </ojp:Params>
                    </ojp:OJPStopEventRequest>
                </ServiceRequest>
            </OJPRequest>
        </OJP>
        """

        // Convert the XML string to Data
        guard let xmlData = xmlString.data(using: .utf8) else { return }

        // Create the URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue("text/XML", forHTTPHeaderField: "Content-Type")
        request.setValue("eyJvcmciOiI2NDA2NTFhNTIyZmEwNTAwMDEyOWJiZTEiLCJpZCI6ImFhODIyNjI1MTNlNzQzNTc5YzM3ODBlN2E4ZGM4YWRjIiwiaCI6Im11cm11cjEyOCJ9", forHTTPHeaderField: "Authorization")
        request.httpBody = xmlData
        
        // Create a URLSession task to send the request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle the response
            if let error = error {
                print("Error: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }

            // Print the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
                DispatchQueue.main.async {
                    self.responseStop = responseString
                }
            }
        }

        // Start the task
        task.resume()
    }
}


#Preview {
    ContentView()
}

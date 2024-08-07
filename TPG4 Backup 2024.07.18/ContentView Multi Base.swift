//
//  ContentView.swift
//  TPG4
//
//  Created by Loris Thomas on 17.06.2024.
//

import SwiftUI
import Foundation

var responseStop = ""
let currentDate = Date()
let dateFormatter = DateFormatter()


// Model to hold the data
struct StopEvent: Codable, Identifiable {
    var id = UUID()
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

struct ContentView: View {
    @State private var stopEvents: [StopEvent] = []
    @State private var searchText = ""
    @StateObject private var stopStore = StopStore()


    var filteredStops: [Stop] {
        if searchText.isEmpty {
            return stopStore.stops
        } else {
            return stopStore.stops.filter { $0.nomarret.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                TextField("Search stops", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                // List of filtered stops
                List(filteredStops) { stop in
                    VStack(alignment: .leading) {
                        Text(stop.nomarret)
                            .font(.headline)
                        Text(stop.commune)
                            .font(.subheadline)
                    }
                    .onTapGesture {
                        selectStop(stop)
                    }
                }
                .navigationTitle("Select Stop")
                
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
                
                List(stopEvents, id: \.id) { event in
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
                    .id(event.id)// Ensure each StopEvent has a unique identifier
                }
            }
            .padding()
        }
    }

    func selectStop(_ stop: Stop) {
        fetchTransportDepartures(with: stop)
        print("Selected stop: \(stop)")
    }
}

class StopEventParser: NSObject, XMLParserDelegate {
    private var stopEvents: [StopEvent] = []
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
            currentStopEvent = StopEvent(stopPointName: "", plannedQuay: "", timetabledTime: "", estimatedTime: "", lineName: "", origin: "", destination: "", transportType: "", operatorName: "")
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
                default:
                    break
                }
            }
        }
        
        if elementName == "ojp:StopEventResult" {
            if let stopEvent = currentStopEvent {
                stopEvents.append(stopEvent)
                currentStopEvent = nil
                print(stopEvents)
            }
            insideStopEventResult = false
        }
        
        currentTextContent = ""
        currentElement = ""
        parentElement = ""
    }
}

func fetchTransportDepartures(with stop: Stop) {
    let urlString = "https://api.opentransportdata.swiss/ojp2020"
    guard let url = URL(string: urlString) else { return }
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    let formattedDate = dateFormatter.string(from: currentDate)
    print(formattedDate)
    
    let xmlString = """
    <?xml version="1.0" encoding="UTF-8"?>
        <OJP xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.siri.org.uk/siri" version="1.0" xmlns:ojp="http://www.vdv.de/ojp" xsi:schemaLocation="http://www.siri.org.uk/siri ../ojp-xsd-v1.0/OJP.xsd">
            <OJPRequest>
                <ServiceRequest>
                    <RequestTimestamp>\(formattedDate)</RequestTimestamp>
                    <RequestorRef>API-Explorer</RequestorRef>
                    <ojp:OJPStopEventRequest>
                        <RequestTimestamp>\(formattedDate)</RequestTimestamp>
                        <ojp:Location>
                            <ojp:PlaceRef>
                                <StopPlaceRef>\(stop.codedidoc)</StopPlaceRef>
                                <ojp:LocationName>
                                    <ojp:Text>\(stop.nomarret)</ojp:Text>
                                </ojp:LocationName>
                            </ojp:PlaceRef>
                            <ojp:DepArrTime>\(formattedDate)</ojp:DepArrTime>
                        </ojp:Location>
                        <ojp:Params>
                            <ojp:NumberOfResults>10</ojp:NumberOfResults>
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
            return
        }
        
        guard let data = data else {
            print("No data received")
            return
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Response: \(responseString)")
            DispatchQueue.main.async {
                // Assuming responseStop is a global variable
                responseStop = responseString
            }
        }
    }
    
    task.resume()
}

#Preview {
    ContentView()
}


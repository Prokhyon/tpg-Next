//
//  LineFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 21.06.2024.
//

import Foundation
import SwiftUI


var responseLine = ""

struct LineEvent: Codable, Identifiable {
    
    var stopPointName: String
    var plannedQuay: String
    var timetabledTime: String
    var estimatedTime: String
    var stopPlaceRef: String
    var previousCall: Bool
    
    var id: String { stopPlaceRef }
    
}


//Send XMLrequest
class LineManager: ObservableObject {
    @Published var LineEvents: [LineEvent] = []
    let dateFormatter = DateFormatter()
    
    func selectJourney(_ stopEvent: StopEvent, completion: @escaping () -> Void = {}) {
            fetchTransportJourney(with: stopEvent) { success, data in
                if success, let data = data?.data(using: .utf8) {
                    self.parseJourneyEvents(from: data) { lineEvents in
                        self.LineEvents = lineEvents
                        print("LineEvents updated: \(self.LineEvents)")
                        completion()
                    }
                } else {
                    completion()
                }
            }
        }
    
    func fetchTransportJourney(with stopEvent: StopEvent, completion: @escaping (Bool, String?) -> Void) {
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
                <RequestorRef>API-Explorer</RequestorRef>
                <ojp:OJPTripInfoRequest>
                    <RequestTimestamp>\(outputString1)</RequestTimestamp>
                    <ojp:JourneyRef>\(stopEvent.journeyRef)</ojp:JourneyRef>
                    <ojp:OperatingDayRef>\(stopEvent.operatingDayRef)</ojp:OperatingDayRef>
                    <ojp:Params>
                        <ojp:IncludeCalls>true</ojp:IncludeCalls>
                        <ojp:IncludeService>true</ojp:IncludeService>
                    </ojp:Params>
                </ojp:OJPTripInfoRequest>
            </ServiceRequest>
        </OJPRequest>
    </OJP>
    """
        
        guard let xmlData = xmlString.data(using: .utf8) else { return }
        //print(xmlString)
        
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
    
    func parseJourneyEvents(from data: Data, completion: @escaping ([LineEvent]) -> Void) {
        class StopEventParserDelegate: NSObject, XMLParserDelegate {
            var lineEvents: [LineEvent] = []
            private var currentElement = ""
            private var currentLineEvent: LineEvent?
            
            private var insideLineEventResult = false
            private var insideTripInfoResponseContext = false
            
            private var currentStopPointName = ""
            private var currentPlannedQuay = ""
            private var currentTimetabledTime = ""
            private var currentEstimatedTime = ""
            private var currentStopPlaceRef = ""
            
            private var stopPlaceRefMap: [String: String] = [:] // Maps StopPointRef to StopPlaceRef
            private var currentStopPointRef = ""
            
            private var parentElement = ""
            
            func parse(data: Data) -> [LineEvent] {
                let parser = XMLParser(data: data)
                parser.delegate = self
                parser.parse()
                return lineEvents
            }
            
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
                    currentLineEvent = LineEvent(stopPointName: "", plannedQuay: "", timetabledTime: "", estimatedTime: "", stopPlaceRef: "", previousCall: false)
                    insideLineEventResult = true
                } else if currentElement == "StopPointName" || currentElement == "PlannedQuay" || currentElement == "StopPlaceRef" || currentElement == "StopPointRef" {
                    parentElement = currentElement
                }
            }
            
            var currentTextContent: String = ""
            
            func parser(_ parser: XMLParser, foundCharacters string: String) {
                currentTextContent += string
            }
            
            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                
                let trimmedString = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if insideTripInfoResponseContext && currentElement == "StopPlaceRef" && !trimmedString.isEmpty {
                    currentStopPlaceRef = trimmedString
                } else if insideTripInfoResponseContext && currentElement == "StopPointRef" && !trimmedString.isEmpty {
                    stopPlaceRefMap[trimmedString] = currentStopPlaceRef
                }
                
                if insideLineEventResult && !trimmedString.isEmpty {
                    if parentElement == "StopPointName" && currentElement == "Text" {
                        currentLineEvent?.stopPointName = trimmedString
                    } else if parentElement == "PlannedQuay" && currentElement == "Text" {
                        currentLineEvent?.plannedQuay = trimmedString
                    } else if currentElement == "TimetabledTime" {
                        currentLineEvent?.timetabledTime = trimmedString
                    } else if currentElement == "EstimatedTime" {
//                        print("ET: \(trimmedString)")
                        if trimmedString == "" {
                            currentLineEvent?.estimatedTime = currentLineEvent?.timetabledTime ?? ""
                        } else {
                            currentLineEvent?.estimatedTime = trimmedString
                        }
                    } else if currentElement == "StopPointRef" {
                        currentStopPointRef = trimmedString
                    }
                }
                if elementName == "ojp:TripInfoResponseContext" {
                    insideTripInfoResponseContext = false
                } else if elementName == "ojp:PreviousCall" {
                    if var lineEvent = currentLineEvent {
                        if let stopPlaceRef = stopPlaceRefMap[currentStopPointRef] {
                            lineEvent.previousCall = true
                            lineEvent.stopPlaceRef = stopPlaceRef
                        }
                        if lineEvent.estimatedTime == "" {
                            lineEvent.estimatedTime = lineEvent.timetabledTime
                        }
                        print(lineEvent.estimatedTime)
                        lineEvents.append(lineEvent)
                        currentLineEvent = nil
                    }
                    insideLineEventResult = false
                } else if elementName == "ojp:OnwardCall" {
                    print(currentStopPointName, currentStopPointRef, currentStopPlaceRef)
                    if var lineEvent = currentLineEvent {
                        print(currentStopPointRef.prefix(2))
                        if currentStopPointRef.prefix(2) == "ch" {
                            if let stopPlaceRef = stopPlaceRefMap[currentStopPointRef] {
                                lineEvent.stopPlaceRef = stopPlaceRef
                            }
                        } else {
                            lineEvent.stopPlaceRef = currentStopPointRef
                        }
                        lineEvents.append(lineEvent)
                        currentLineEvent = nil
                    }
                    insideLineEventResult = false
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
            //print("Finished parsing. Result:", result)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}

struct BusLineIcon: View {
    let lineName: String

    var body: some View {
           ZStack {
               Text(lineName)
                   .padding(.horizontal, 8)
                   .padding(.vertical, 4)
                   .frame(minWidth: 35, maxHeight: 25)
                   .background(
                       RoundedRectangle(cornerRadius: 10)
                           .stroke(LineColors.lineColor(for: lineName), lineWidth: 4)
                   )
           }
       }
   }

//struct BusLineIcon_Previews: PreviewProvider {
//    static var previews: some View {
//        BusLineIcon(lineName: "1234")
//            .previewLayout(.sizeThatFits)
//            .padding()
//    }
//}

struct LineColors {
    static let lineBrown = Color(red: 124.0/255.0, green: 74.0/255.0, blue: 38.0/255.0)
    static let lineBlue = Color(red: 77.0/255.0, green: 169.0/255.0, blue: 226.0/255.0)
    static let lineDarkBlue = Color(red: 61.0/255.0, green: 138.0/255.0, blue: 185.0/255.0)
    static let lineOrange = Color(red: 239.0/255.0, green: 133.0/255.0, blue: 50.0/255.0)
    static let lineLightOrange = Color(red: 233.0/255.0, green: 167.0/255.0, blue: 58.0/255.0)
    static let lineIndigo = Color(red: 83.0/255.0, green: 34.0/255.0, blue: 125.0/255.0)
    static let linePurple = Color(red: 170.0/255.0, green: 59.0/255.0, blue: 134.0/255.0)
    static let lineAcidGreen = Color(red: 212.0/255.0, green: 219.0/255.0, blue: 99.0/255.0)
    static let lineDarkGreen = Color(red: 46.0/255.0, green: 108.0/255.0, blue: 66.0/255.0)
    static let lineBordeau = Color(red: 110.0/255.0, green: 18.0/255.0, blue: 59.0/255.0)
    static let lineLightIndigo = Color(red: 122.0/255.0, green: 58.0/255.0, blue: 153.0/255.0)
    static let lineLightMint = Color(red: 152.0/255.0, green: 201.0/255.0, blue: 190.0/255.0)
    static let lineDarkMint = Color(red: 39.0/255.0, green: 93.0/255.0, blue: 96.0/255.0)
    static let linePink = Color(red: 219.0/255.0, green: 106.0/255.0, blue: 157.0/255.0)
    static let lineLightPink = Color(red: 235.0/255.0, green: 184.0/255.0, blue: 209.0/255.0)
    static let lineSalmon = Color(red: 241.0/255.0, green: 160.0/255.0, blue: 171.0/255.0)
    
    static let colors: [String: Color] = [
            "12": lineLightOrange,
            "14": lineIndigo,
            "15": lineBrown,
            "17": lineBlue,
            "18": linePurple,
            "2": lineAcidGreen,
            "3": linePurple,
            "6": lineDarkBlue,
            "7": .green,
            "10": lineDarkGreen,
            "19": lineBrown,
            "1": lineIndigo,
            "5": lineBlue,
            "8": lineBrown,
            "9": .red,
            "11": lineLightIndigo,
            "20": .green,
            "21": lineBrown,
            "22": lineIndigo,
            "23": linePurple,
            "25": lineBrown,
            "28": lineLightIndigo,
            "31": .mint,
            "32": lineLightMint,
            "33": .mint,
            "34": lineLightMint,
            "37": lineDarkMint,
            "38": lineDarkMint,
            "39": .mint,
            "41": .mint,
            "43": lineLightMint,
            "44": .mint,
            "45": lineLightMint,
            "46": .mint,
            "47": .mint,
            "48": lineLightMint,
            "50": .mint,
            "51": .mint,
            "52": lineLightMint,
            "53": lineLightMint,
            "54": lineLightMint,
            "55": lineDarkMint,
            "56": .mint,
            "57": lineLightMint,
            "59": lineDarkMint,
            "60": linePink,
            "61": lineLightPink,
            "64": linePink,
            "66": lineLightPink,
            "67": lineLightPink,
            "68": linePink,
            "69": lineLightPink,
            "70": .mint,
            "71": lineDarkMint,
            "72": lineLightMint,
            "73": lineDarkMint,
            "74": lineLightMint,
            "75": lineDarkMint,
            "78": lineDarkMint,
            "80": lineLightPink,
            "82": linePink,
            "83": linePink,
            "91": lineDarkMint,
            "92": lineLightMint,
            "A": lineOrange,
            "E": lineOrange,
            "G": lineSalmon,
            "J": lineOrange,
            "K": lineSalmon,
            "L": lineOrange,
            "E+": .black,
            "G+": .black,
            "RL1": .red,
            "RL2": .blue,
            "RL3": .green,
            "RL4": .yellow,
            "RL5": lineBordeau,
            "RL6": lineIndigo
            /*"C1": .green,
             "C3": .green,
             "C4": .green,
             "C5": .green,
             "C6": .green,
             "C7": .green,
             "C8": .green,
             "": .green,
             "": .green,*/
            // Add more lines as needed
        ]
    
    static func lineColor(for lineID: String) -> Color {
        return colors[lineID] ?? .primary
    }
}

//
//  LineFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 21.06.2024.
//

import Foundation
import SwiftUI
import Combine



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
public func fetchTransportJourney(with stopEvent: StopEvent, calls: Bool = true, track: Bool = false, completion: @escaping (Bool, String?) -> Void) {
    fetchTransportJourney(journeyRef: stopEvent.journeyRef, operatingDayRef: stopEvent.operatingDayRef, calls: calls, track: track, expectedStopRef: stopEvent.stopId, expectedTime: stopEvent.timetabledTime, completion: completion)
}

/// Course complète, par une OJPTripInfoRequest en OJP 2.0 (voir `JourneyParser.swift`).
///
/// L'API n'est pas cohérente sur le jour d'exploitation de certaines courses de nuit : quand un arrêt
/// et son heure sur la course sont connus, la course reçue est vérifiée et, si elle ne correspond pas,
/// on réessaie avec le lendemain puis la veille. En pratique, une seule requête suffit.
/// - Parameter track: ajoute le tracé géographique de la course (≈ +35 Ko), lu par `parseJourneyTrack`.
/// - Parameter expectedStopRef: un arrêt de la course (quai ou arrêt parent).
/// - Parameter expectedTime: l'heure théorique de la course à cet arrêt.
/// `completion` est appelé sur le thread principal.
public func fetchTransportJourney(journeyRef: String, operatingDayRef: String, calls: Bool = true, track: Bool = false, expectedStopRef: String? = nil, expectedTime: String? = nil, completion: @escaping (Bool, String?) -> Void) {
    let days = operatingDayCandidates(for: operatingDayRef)
    var fallback: String?

    func finish(_ response: String?) {
        DispatchQueue.main.async {
            completion(response != nil, response)
        }
    }

    func attempt(_ index: Int) {
        guard index < days.count else {
            // Aucune course ne correspond : la première non vide vaut mieux que rien.
            finish(fallback)
            return
        }
        requestTripInfo(journeyRef: journeyRef, operatingDayRef: days[index], calls: calls, track: track) { response in
            guard let response else {
                // Erreur réseau : inutile d'essayer d'autres jours.
                finish(fallback)
                return
            }
            // Sans les arrêts, il n'y a rien à vérifier.
            guard calls else {
                finish(response)
                return
            }
            let events = parseJourneyEventsSync(from: Data(response.utf8)).events
            if journeyMatches(events, stopRef: expectedStopRef, timetabledTime: expectedTime) {
                finish(response)
                return
            }
            if fallback == nil && !events.isEmpty {
                fallback = response
            }
            Log.network.info("Course \(journeyRef) introuvable pour le jour \(days[index]), essai suivant")
            attempt(index + 1)
        }
    }

    attempt(0)
}

/// Une OJPTripInfoRequest en OJP 2.0. `completion` reçoit `nil` en cas d'erreur réseau,
/// sur une file d'arrière-plan.
private func requestTripInfo(journeyRef: String, operatingDayRef: String, calls: Bool, track: Bool, completion: @escaping (String?) -> Void) {
    guard let url = URL(string: "https://api.opentransportdata.swiss/ojp20") else {
        completion(nil)
        return
    }

    let outputFormatter1 = DateFormatter()
    outputFormatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    outputFormatter1.timeZone = TimeZone(secondsFromGMT: 0)
    let outputString1 = outputFormatter1.string(from: Date())

    let xmlString = """
    <?xml version="1.0" encoding="utf-8"?>
    <OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
        <OJPRequest>
            <siri:ServiceRequest>
                <siri:RequestTimestamp>\(outputString1)</siri:RequestTimestamp>
                <siri:RequestorRef>tpgNext</siri:RequestorRef>
                <OJPTripInfoRequest>
                    <siri:RequestTimestamp>\(outputString1)</siri:RequestTimestamp>
                    <JourneyRef>\(journeyRef.xmlEscaped)</JourneyRef>
                    <OperatingDayRef>\(operatingDayRef.xmlEscaped)</OperatingDayRef>
                    <Params>
                        <IncludeCalls>\(calls ? "true" : "false")</IncludeCalls>
                        <IncludeService>\(calls ? "true" : "false")</IncludeService>
                        <IncludeTrackProjection>\(track ? "true" : "false")</IncludeTrackProjection>
                    </Params>
                </OJPTripInfoRequest>
            </siri:ServiceRequest>
        </OJPRequest>
    </OJP>
    """

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/xml", forHTTPHeaderField: "Accept")
    request.setValue("text/XML", forHTTPHeaderField: "Content-Type")
    request.setValue(keySelect(), forHTTPHeaderField: "Authorization")
    request.httpBody = Data(xmlString.utf8)

    URLSession.shared.dataTask(with: request) { data, _, error in
        if let error {
            Log.network.error("Course : \(error.localizedDescription)")
            completion(nil)
            return
        }
        guard let data, let responseString = String(data: data, encoding: .utf8) else {
            Log.network.error("Course : réponse vide")
            completion(nil)
            return
        }
        completion(responseString)
    }.resume()
}

public func parseJourneyEvents(from data: Data, completion: @escaping ([LineEvent], String) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let result = parseJourneyEventsSync(from: data)
        DispatchQueue.main.async {
            completion(result.events, result.operatorName)
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

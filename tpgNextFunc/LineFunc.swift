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


/// Course complète d'un départ. Voir `fetchTransportJourney(journeyRef:operatingDayRef:...)`.
public func fetchTransportJourney(with stopEvent: StopEvent, calls: Bool = true, track: Bool = false, completion: @escaping (Data?) -> Void) {
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
/// `completion` reçoit la réponse brute, `nil` en cas d'échec, sur le thread principal.
public func fetchTransportJourney(journeyRef: String, operatingDayRef: String, calls: Bool = true, track: Bool = false, expectedStopRef: String? = nil, expectedTime: String? = nil, completion: @escaping (Data?) -> Void) {
    let days = operatingDayCandidates(for: operatingDayRef)
    var fallback: Data?

    func finish(_ response: Data?) {
        DispatchQueue.main.async { completion(response) }
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
            let events = parseJourneyEventsSync(from: response).events
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

/// Une OJPTripInfoRequest en OJP 2.0. `completion` reçoit `nil` en cas d'échec, sur une file de fond.
private func requestTripInfo(journeyRef: String, operatingDayRef: String, calls: Bool, track: Bool, completion: @escaping (Data?) -> Void) {
    let requestTimestamp = OJPDate.string(from: Date())
    let xmlString = """
    <?xml version="1.0" encoding="utf-8"?>
    <OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
        <OJPRequest>
            <siri:ServiceRequest>
                <siri:RequestTimestamp>\(requestTimestamp)</siri:RequestTimestamp>
                <siri:RequestorRef>tpgNext</siri:RequestorRef>
                <OJPTripInfoRequest>
                    <siri:RequestTimestamp>\(requestTimestamp)</siri:RequestTimestamp>
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
    OJPClient.post(xmlString, to: .v2, completionQueue: .global(qos: .userInitiated)) { completion(try? $0.get()) }
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
    
    var width: CGFloat = 35
    var height: CGFloat = 25
    /// Plafond de hauteur et largeur minimale du badge : identiques à la taille de texte
    /// normale, ils grandissent avec elle (le numéro était écrasé à grande taille).
    @ScaledMetric private var maxHeight: CGFloat = 25
    @ScaledMetric private var minWidth: CGFloat = 35
    
    public init(lineName: String, operatorName: String, width: CGFloat = 35, height: CGFloat = 25) {
        self.lineName = lineName
        self.operatorName = operatorName
        self.height = height
        self.width = width
        
    }

    public var body: some View {
           ZStack {
               Text(lineName)
                   
                   .padding(.horizontal, 8)
                   .padding(.vertical, 4)
                   .frame(minWidth: width < minWidth ? width : minWidth, maxHeight: height < maxHeight ? height : maxHeight)
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

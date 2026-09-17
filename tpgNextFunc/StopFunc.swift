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


/// La requête `OJPStopEventRequest` (OJP 1.0) des `count` prochains départs à partir de `date`.
func stopEventRequestXML(stopName: String, stopSloid: String, count: Int, at date: Date) -> String {
    let requestTimestamp = OJPDate.string(from: Date())
    // En UTC explicite : une heure locale sans fuseau n'est juste que si le téléphone est à l'heure suisse.
    let depArrTime = OJPDate.string(from: date)
    return """
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
                        <ojp:NumberOfResults>\(count)</ojp:NumberOfResults>
                        <ojp:StopEventType>departure</ojp:StopEventType>
                        <ojp:IncludeRealtimeData>true</ojp:IncludeRealtimeData>
                    </ojp:Params>
                </ojp:OJPStopEventRequest>
            </ServiceRequest>
        </OJPRequest>
    </OJP>
    """
}

/// Les prochains départs d'un arrêt. `completion` reçoit la réponse brute,
/// `nil` en cas d'échec, sur le thread principal.
public func fetchTransportDepartures(with stopName: String, stopSloid: String, stopEventNumber: Int, timeRequest: Date, completion: @escaping (Data?) -> Void) {
    let xml = stopEventRequestXML(stopName: stopName, stopSloid: stopSloid, count: stopEventNumber, at: timeRequest)
    OJPClient.post(xml, to: .v1) { completion(try? $0.get()) }
}

/// Les prochains départs d'un arrêt et ses quais, en `async`.
/// Lève `OJPClient.Failure` en cas d'échec réseau, `ParserError` si l'API n'a pas de départ.
public func fetchStopEvents(stopName: String, stopSloid: String, count: Int, at date: Date = Date()) async throws -> (events: [StopEvent], quays: [Quay]) {
    let data = try await OJPClient.post(stopEventRequestXML(stopName: stopName, stopSloid: stopSloid, count: count, at: date), to: .v1)
    let result = parseStopEventsSync(from: data, stopCode: stopSloid)
    if let error = result.error {
        throw error
    }
    return (result.events, result.quays)
}

/// Les départs et les quais d'une réponse `OJPStopEventRequest`, décodés hors du thread
/// principal. `completion` est appelé sur le thread principal.
public func parseStopEvents(from data: Data, stopCode: String, completion: @escaping ([StopEvent], [Quay], ParserError?) -> Void) {
    // .userInitiated et non .background : ces départs sont attendus à l'écran, et une file
    // .background peut être retardée de plusieurs secondes.
    DispatchQueue.global(qos: .userInitiated).async {
        let result = parseStopEventsSync(from: data, stopCode: stopCode)
        DispatchQueue.main.async {
            completion(result.events, result.quays, result.error)
        }
    }
}

public func parseStopEventsSync(from data: Data, stopCode: String) -> (events: [StopEvent], quays: [Quay], error: ParserError?) {
    let parser = StopEventParser(stopCode: stopCode)
    parser.parse(data)
    return (parser.events, parser.quays, parser.error)
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

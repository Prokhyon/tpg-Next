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

    // Informations d'OJP 2.0. Optionnelles : un départ enregistré avant elles (dans un rappel,
    // par exemple) se décode toujours, et les départs construits à la main s'en passent.

    /// Le véhicule ne s'arrête pas ici (`NotServicedStop`) : course supprimée, ou arrêt sauté.
    public var isCancelled: Bool?
    /// Accès au quai pour les personnes à mobilité réduite.
    public var quayAccess: QuayAccess?
    /// Codes des services du véhicule (`A__NF` : plancher bas).
    public var attributeCodes: [String]?
    /// Mode OJP : `bus`, `tram`, `rail`, `water`…
    public var ptMode: String?
    /// La course ne circule qu'un seul jour de l'horaire (`OperatingDays`) : déviation intégrée
    /// à l'horaire du jour, course spéciale… L'API ne dit pas laquelle. `nil` sinon.
    public var isExceptional: Bool?
    /// L'arrêt de destination (`DestinationStopPointRef`, un sloid, souvent de quai) : son nom
    /// officiel remplace le texte d'OJP (voir `StopNames`).
    public var destinationRef: String?

    public var id: String { journeyRef + timetabledTime }

    public var cancelled: Bool { isCancelled == true }
    public var hasLowFloor: Bool { attributeCodes?.contains("A__NF") == true }
    /// La course est touchée par un incident mais dessert cet arrêt : d'autres arrêts sont sautés.
    public var exceptional: Bool { isExceptional == true }
    public var routeChanged: Bool { !cancelled && attributeCodes?.contains(where: isIncidentAttribute) == true }

    public init(stopPointName: String, stopId: String, plannedQuay: String, timetabledTime: String, estimatedTime: String, lineName: String, origin: String, destination: String, transportType: String, operatorName: String, journeyRef: String, operatingDayRef: String,
                isCancelled: Bool? = nil, quayAccess: QuayAccess? = nil, attributeCodes: [String]? = nil, ptMode: String? = nil) {
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
        self.isCancelled = isCancelled
        self.quayAccess = quayAccess
        self.attributeCodes = attributeCodes
        self.ptMode = ptMode
    }
}

/// Attribut d'incident d'une course (`ojp9200A_H_IncidentTrip142_1`, libellé « Ausfall »).
///
/// Il marque toute course perturbée, même celles qui ne sautent que quelques arrêts : il ne
/// dit pas, à lui seul, que la course est supprimée. Le code est lu plutôt que le libellé,
/// toujours en allemand.
public func isIncidentAttribute(_ code: String) -> Bool {
    code.contains("_IncidentTrip")
}

/// Accès au quai pour les personnes à mobilité réduite (`NameSuffix` d'un arrêt en OJP 2.0).
public enum QuayAccess: String, Codable, Hashable, CaseIterable {
    case withoutAssistance = "PLATFORM_ACCESS_WITHOUT_ASSISTANCE"
    case withAssistance = "PLATFORM_ACCESS_WITH_ASSISTANCE"
    case notWheelchairAccessible = "PLATFORM_NOT_WHEELCHAIR_ACCESSIBLE"
    /// Un transport de substitution est proposé aux personnes en fauteuil.
    case alternativeTransport = "ALTERNATIVE_TRANSPORT"
}

public struct Quay: Codable, Identifiable, Hashable {
    public var id: String
    public var quayName: String
    public var latitude: String
    public var longitude: String
}


/// La requête `OJPStopEventRequest` (OJP 2.0) des `count` prochains départs à partir de `date`.
func stopEventRequestXML(stopName: String, stopSloid: String, count: Int, at date: Date) -> String {
    let requestTimestamp = OJPDate.string(from: Date())
    let depArrTime = OJPDate.string(from: date)
    // L'ordre des paramètres suit le schéma OJP 2.0 : l'API refuse une requête désordonnée.
    // Sans arrêts précédents ni suivants : 30 départs pèsent ~70 Ko, contre ~570 Ko avec les suivants.
    return """
    <?xml version="1.0" encoding="utf-8"?>
    <OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
        <OJPRequest>
            <siri:ServiceRequest>
                <siri:RequestTimestamp>\(requestTimestamp)</siri:RequestTimestamp>
                <siri:RequestorRef>tpgNext</siri:RequestorRef>
                <OJPStopEventRequest>
                    <siri:RequestTimestamp>\(requestTimestamp)</siri:RequestTimestamp>
                    <Location>
                        <PlaceRef>
                            <siri:StopPointRef>\(stopSloid.xmlEscaped)</siri:StopPointRef>
                            <Name>
                                <Text>\(stopName.xmlEscaped)</Text>
                            </Name>
                        </PlaceRef>
                        <DepArrTime>\(depArrTime)</DepArrTime>
                    </Location>
                    <Params>
                        <NumberOfResults>\(count)</NumberOfResults>
                        <StopEventType>departure</StopEventType>
                        <IncludePreviousCalls>false</IncludePreviousCalls>
                        <IncludeOnwardCalls>false</IncludeOnwardCalls>
                        <IncludeRealtimeData>true</IncludeRealtimeData>
                        <IncludePlacesContext>true</IncludePlacesContext>
                        <IncludeSituationsContext>true</IncludeSituationsContext>
                    </Params>
                </OJPStopEventRequest>
            </siri:ServiceRequest>
        </OJPRequest>
    </OJP>
    """
}

public func fetchTransportDepartures(with stopName: String, stopSloid: String, stopEventNumber: Int, timeRequest: Date, completion: @escaping (Result<Data, OJPClient.Failure>) -> Void) {
    let xml = stopEventRequestXML(stopName: stopName, stopSloid: stopSloid, count: stopEventNumber, at: timeRequest)
    OJPClient.post(xml, to: .v2, completion: completion)
}

/// Les prochains départs d'un arrêt et ses quais, en `async`.
/// Lève `OJPClient.Failure` en cas d'échec réseau, `ParserError` si l'API n'a pas de départ.
public func fetchStopEvents(stopName: String, stopSloid: String, count: Int, at date: Date = Date()) async throws -> (events: [StopEvent], quays: [Quay]) {
    let data = try await OJPClient.post(stopEventRequestXML(stopName: stopName, stopSloid: stopSloid, count: count, at: date), to: .v2)
    let result = parseStopEventsSync(from: data, stopCode: stopSloid)
    if let error = result.error {
        throw error
    }
    // Les noms officiels des destinations : ici et dans `StopManager`, là où l'app charge les
    // départs, et non dans le décodage, que les tests comparent octet pour octet.
    return (result.events.map(StopNames.withOfficialDestination), result.quays)
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
    if parser.isUnreadable, parser.error == nil {
        OJPUsage.shared.recordUnreadable("départs")
        return ([], [], .xmlParsingFailed)
    }
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

//
//  TripFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 30.06.2024.
//

import Foundation
import SwiftUI
import MapKit
import Combine


public struct TripEvent: Identifiable, Hashable, Encodable, Decodable {
    public var id: String
    public var duration: String
    public var startTime: String
    public var endTime: String
    public var startCoordinates: Coordinates
    public var endCoordinates: Coordinates
    public var startName: String
    public var endName: String
    public var startCode: String?
    public var endCode: String?
    public var geoDeparture: Bool
    public var geoArrival: Bool
    public var transfers: String
    public var legs: [TripLeg]
}

public struct TripLeg: Identifiable, Hashable, Encodable, Decodable {
    public var id: String
    public var transfer: Bool = false
    public var legBoardStopName: String
    public var legBoardStopId: String
    public var legBoardQuay: String
    public var legBoardTimetableTime: String
    public var legBoardEstimatedTime: String
    public var legBoardLongitude: String
    public var legBoardLatitude: String
    
    public var legAlightStopName: String
    public var legAlightStopId: String
    public var legAlightQuay: String
    public var legAlightTimetableTime: String
    public var legAlightEstimatedTime: String
    public var legAlightLongitude: String
    public var legAlightLatitude: String
    
    public var legIntermediates: [LegIntermediate]
    
    public var legDestination: String
    /// L'arrêt de destination du véhicule (`DestinationStopPointRef`) : son nom officiel remplace
    /// le texte d'OJP (voir `StopNames`).
    public var legDestinationRef: String? = nil
    public var journeyRef: String
    /// Optionnel : les itinéraires enregistrés avant qu'il soit lu n'en ont pas (voir `resolvedOperatingDayRef`).
    public var operatingDayRef: String? = nil
    public var publishedLineName: String
    /// Vide pour un bus ou un tram : OJP ne la donne pas. Passer par `duration`.
    public var legDuration: String
    public var transferDuration: String
    public var transferWalkDuration: String
    public var transferBuffer: String
    public var transportTypeName: String
    public var legOperator: String
    /// Codes des services du véhicule. Optionnel : les itinéraires enregistrés avant n'en ont pas.
    public var attributeCodes: [String]? = nil
    /// Le sous-mode d'un bus (`BusSubmode`) : `demandAndResponseBus` pour un bus à la demande.
    public var busSubmode: String? = nil
//    var legTrack: [CLLocationCoordinate2D]

    /// Course touchée par un incident : des arrêts sont sautés (voir `LegIntermediate.notServiced`).
    public var hasIncident: Bool { attributeCodes?.contains(where: isIncidentAttribute) == true }
    /// Les arrêts intermédiaires où le véhicule ne s'arrête pas.
    public var skippedIntermediates: [LegIntermediate] { legIntermediates.filter(\.skipped) }

    /// Réservation obligatoire (attribut `RR`, « Platzreservierung obligatorisch »).
    public var requiresReservation: Bool { attributeCodes?.contains("RR") == true }

    /// Un bus à la demande, comme tpg flex : il ne passe que sur réservation, et l'heure donnée
    /// par OJP n'est qu'une proposition (une toutes les 5 minutes), pas un horaire. Les
    /// itinéraires enregistrés avant la lecture du sous-mode se reconnaissent à la réservation.
    public var isOnDemand: Bool {
        busSubmode == "demandAndResponseBus"
            || (busSubmode == nil && requiresReservation && transportTypeName.localizedCaseInsensitiveCompare("Bus") == .orderedSame)
    }
}

extension TripEvent {
    /// Au moins une étape en bus à la demande.
    public var hasOnDemandLeg: Bool { legs.contains(where: \.isOnDemand) }
}

public struct LegIntermediate: Codable, Identifiable, Hashable {
    public var id: String
    public var stopId: String
    public var stopName: String
    public var longitude: String
    public var latitude: String
    /// Le véhicule ne s'arrête pas ici (`NotServicedStop`). Optionnel : les itinéraires
    /// enregistrés avant qu'il soit lu se décodent toujours.
    public var notServiced: Bool? = nil

    public var skipped: Bool { notServiced == true }
}

extension TripLeg {
    /// Jour d'exploitation de la course, à passer à l'OJPTripInfoRequest. À défaut (itinéraire
    /// enregistré avant qu'il soit lu), on l'estime : jusque vers 4 h, les courses de nuit
    /// appartiennent au jour d'exploitation de la veille. `fetchTransportJourney` rattrape les écarts.
    public var resolvedOperatingDayRef: String {
        if let operatingDayRef, !operatingDayRef.isEmpty {
            return operatingDayRef
        }
        guard let date = OJPDate.date(from: legBoardTimetableTime) else {
            return String(legBoardTimetableTime.prefix(10))
        }
        let swissTimeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = swissTimeZone
        let nightDate = calendar.component(.hour, from: date) < 4 ? date.addingTimeInterval(-86_400) : date
        return dayString(from: nightDate, in: swissTimeZone)
    }
}

extension TripEvent {
    /// Le véhicule du départ, pour son icône. Une première étape à pied donne le piéton :
    /// l'heure affichée est alors celle du départ à pied, pas celle d'un bus.
    public var startTransportType: String { transportType(of: legs.first) }

    /// Le véhicule de l'arrivée, pour son icône : le piéton quand le trajet finit à pied.
    public var endTransportType: String { transportType(of: legs.last) }

    private func transportType(of leg: TripLeg?) -> String {
        guard let leg else { return "Bus" }
        return leg.transfer || leg.publishedLineName.isEmpty ? "walk" : leg.transportTypeName
    }
}

/// Date locale (yyyy-MM-dd) d'une heure OJP en UTC, pour l'affichage : couper la chaîne
/// UTC donne la veille pour les trajets entre minuit et 2 h.
public func localDayString(fromUTC isoString: String) -> String {
    guard let date = OJPDate.date(from: isoString) else {
        return String(isoString.prefix(10))
    }
    return dayString(from: date, in: .current)
}

private func dayString(from date: Date, in timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

public enum ParserError: Error {
    case noEventFound(message: String)
    case xmlParsingFailed
    case unknown
}

public func parseTripEvents(from data: Data, startCoordinate: Coordinates, endCoordinates: Coordinates, startName: String, endName: String, startCode: String?, endCode: String?, geoDeparture: Bool, geoArrival: Bool) throws -> [TripEvent] {
    let template = TripEvent(id: "", duration: "", startTime: "", endTime: "", startCoordinates: startCoordinate,
                             endCoordinates: endCoordinates, startName: startName, endName: endName, startCode: startCode,
                             endCode: endCode, geoDeparture: geoDeparture, geoArrival: geoArrival, transfers: "", legs: [])
    let parser = TripEventParser(template: template)
    parser.parse(data)
    if let error = parser.error {
        throw error
    }
    return parser.trips.map(StopNames.withOfficialDestinations)
}

/// `<ojp:PlaceRef>` d'un départ ou d'une arrivée : l'arrêt, ou les coordonnées d'un lieu.
/// `nil` si l'élément attendu manque.
private func placeRefXML(stop: Stop?, geoPosition: GeoPosition?, useGeoPosition: Bool) -> String? {
    let reference: String
    let name: String
    if useGeoPosition {
        guard let geoPosition else { return nil }
        reference = """
        <ojp:GeoPosition>
            <Longitude>\(geoPosition.coordinate.longitude)</Longitude>
            <Latitude>\(geoPosition.coordinate.latitude)</Latitude>
        </ojp:GeoPosition>
        """
        name = geoPosition.name
    } else {
        guard let stop else { return nil }
        reference = "<ojp:StopPlaceRef>\(stop.sloid.xmlEscaped)</ojp:StopPlaceRef>"
        name = stop.name
    }
    return """
    <ojp:PlaceRef>
        \(reference)
        <ojp:LocationName>
            <ojp:Text>\(name.xmlEscaped)</ojp:Text>
        </ojp:LocationName>
    </ojp:PlaceRef>
    """
}

/// Les itinéraires entre deux points (OJP 1.0). `completion` reçoit la réponse brute,
/// `nil` en cas d'échec, sur le thread principal.
public func fetchTrips(with departureStop: Stop?, with departureGeoPosition: GeoPosition?, with geoDeparture: Bool, with arrivalStop: Stop?, with arrivalGeoPosition: GeoPosition?, with geoArrival: Bool, with selectedTime: Date, with isArrivalTime: Bool, completion: @escaping (Data?) -> Void) {
    // Sans déballage forcé : un lieu attendu mais absent faisait planter l'app.
    guard let origin = placeRefXML(stop: departureStop, geoPosition: departureGeoPosition, useGeoPosition: geoDeparture),
          let destination = placeRefXML(stop: arrivalStop, geoPosition: arrivalGeoPosition, useGeoPosition: geoArrival) else {
        Log.network.error("Itinéraires : départ ou arrivée manquant")
        completion(nil)
        return
    }
    let requestTimestamp = OJPDate.string(from: Date())
    let depArrTime = "<ojp:DepArrTime>\(OJPDate.string(from: selectedTime))</ojp:DepArrTime>"
    let xmlString = """
    <?xml version="1.0" encoding="utf-8"?>
    <OJP xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.siri.org.uk/siri" version="1.0" xmlns:ojp="http://www.vdv.de/ojp" xsi:schemaLocation="http://www.siri.org.uk/siri ../ojp-xsd-v1.0/OJP.xsd">
        <OJPRequest>
            <ServiceRequest>
                <RequestTimestamp>\(requestTimestamp)</RequestTimestamp>
                <RequestorRef>API-Explorer</RequestorRef>
                <ojp:OJPTripRequest>
                    <RequestTimestamp>\(requestTimestamp)</RequestTimestamp>
                    <ojp:Origin>
                        \(origin)
                        \(isArrivalTime ? "" : depArrTime)
                    </ojp:Origin>
                    <ojp:Destination>
                        \(destination)
                        \(isArrivalTime ? depArrTime : "")
                    </ojp:Destination>
                    <ojp:Params>
                        <ojp:IncludeTrackSections>false</ojp:IncludeTrackSections>
                        <ojp:IncludeLegProjection>false</ojp:IncludeLegProjection>
                        <ojp:IncludeTurnDescription></ojp:IncludeTurnDescription>
                        <ojp:IncludeIntermediateStops>true</ojp:IncludeIntermediateStops>
                    </ojp:Params>
                </ojp:OJPTripRequest>
            </ServiceRequest>
        </OJPRequest>
    </OJP>
    """
    OJPClient.post(xmlString, to: .v1) { completion(try? $0.get()) }
}

@Observable
public class FullTripTest {
    public var Trip: TripEvent
    public init() {
        self.Trip = TripEvent(id: "AAAA", duration: "PT45M", startTime: "2025-02-08T14:50:42Z", endTime: "2025-02-08T15:35:42Z", startCoordinates: Coordinates(lon: 0.0, lat: 0.0), endCoordinates: Coordinates(lon: 0.0, lat: 0.0), startName: "Meinier, église", endName: "Carouge, Rondeau", startCode: "", endCode: "", geoDeparture: false, geoArrival: false, transfers: "1", legs: [
            TripLeg(id: "A", transfer: true, legBoardStopName: "", legBoardStopId: "", legBoardQuay: "", legBoardTimetableTime: "2025-02-08T14:50:42Z", legBoardEstimatedTime: "2025-02-08T14:50:42Z", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "", legAlightStopId: "", legAlightQuay: "", legAlightTimetableTime: "2025-02-08T14:51:42Z", legAlightEstimatedTime: "2025-02-08T14:51:42Z", legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "", journeyRef: "", publishedLineName: "", legDuration: "PT1M", transferDuration: "PT1M", transferWalkDuration: "PT1M", transferBuffer: "PT1M", transportTypeName: "walk", legOperator: ""),
            TripLeg(id: "1234", legBoardStopName: "Meinier, église", legBoardStopId: "AAA", legBoardQuay: "A", legBoardTimetableTime: "2025-02-08T14:51:42Z", legBoardEstimatedTime: "2025-02-08T14:51:42Z", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "Genève, Place des Eaux-Vives", legAlightStopId: "BBB", legAlightQuay: "B", legAlightTimetableTime: "2025-02-08T15:10:42Z", legAlightEstimatedTime: "2025-02-08T15:10:42Z", legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "Genève, Rive", journeyRef: "", publishedLineName: "A", legDuration: "PT19M", transferDuration: "", transferWalkDuration: "", transferBuffer: "", transportTypeName: "Bus", legOperator: "Transports Publics Genevois"),
            TripLeg(id: "B", transfer: true, legBoardStopName: "", legBoardStopId: "", legBoardQuay: "", legBoardTimetableTime: "", legBoardEstimatedTime: "", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "", legAlightStopId: "", legAlightQuay: "", legAlightTimetableTime: "", legAlightEstimatedTime: "", legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "", journeyRef: "", publishedLineName: "", legDuration: "", transferDuration: "PT10M", transferWalkDuration: "PT5M", transferBuffer: "PT6M", transportTypeName: "", legOperator: ""),
            TripLeg(id: "5678", legBoardStopName: "Genève, Terrassière", legBoardStopId: "CCC", legBoardQuay: "C", legBoardTimetableTime: "2025-02-08T15:20:42Z", legBoardEstimatedTime: "2025-02-08T15:20:42Z", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "Carouge, Rondeau", legAlightStopId: "DDD", legAlightQuay: "D", legAlightTimetableTime: "2025-02-08T15:35:42Z", legAlightEstimatedTime: "2025-02-08T15:35:42Z", legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "Lancy-Bachet, Gare", journeyRef: "", publishedLineName: "12", legDuration: "PT15M", transferDuration: "", transferWalkDuration: "", transferBuffer: "", transportTypeName: "Tram", legOperator: "Transports Publics Genevois")
        ])
    }

}

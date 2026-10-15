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
    /// La ligne pour OJP (`ojp:91012:B`), la même dans les deux sens : sert à l'éviter
    /// (`AvoidedLine`). Optionnel : les itinéraires enregistrés avant qu'elle soit lue n'en ont pas.
    public var lineRef: String? = nil
    /// Vide pour un bus ou un tram : leur durée se déduit des heures. Passer par `duration`.
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

/// Une ligne que la recherche d'itinéraire évite, choisie dans les résultats.
public struct AvoidedLine: Codable, Hashable, Identifiable, Sendable {
    public let lineRef: String
    public let name: String
    public let operatorName: String
    public var id: String { lineRef }

    /// La ligne d'une étape en véhicule ; `nil` pour la marche ou sans référence de ligne.
    public init?(leg: TripLeg) {
        guard !leg.transfer, !leg.publishedLineName.isEmpty, let lineRef = leg.lineRef, !lineRef.isEmpty else { return nil }
        self.lineRef = lineRef
        name = leg.publishedLineName
        operatorName = leg.legOperator
    }

    /// L'étape passe par cette ligne. Le nom et l'exploitant la reconnaissent aussi : une variante
    /// de la ligne pourrait avoir une autre référence, que le filtre d'OJP laisserait passer.
    public func matches(_ leg: TripLeg) -> Bool {
        guard !leg.transfer else { return false }
        return leg.lineRef == lineRef || (leg.publishedLineName == name && leg.legOperator == operatorName)
    }
}

extension TripEvent {
    /// Les lignes de l'itinéraire, dans l'ordre, chacune une fois.
    public var avoidableLines: [AvoidedLine] {
        var seen: Set<String> = []
        return legs.compactMap(AvoidedLine.init(leg:)).filter { seen.insert($0.lineRef).inserted }
    }
}

extension Array where Element == TripEvent {
    /// Sans les itinéraires qui empruntent une ligne évitée.
    public func avoiding(_ lines: [AvoidedLine]) -> [TripEvent] {
        guard !lines.isEmpty else { return self }
        return filter { trip in !trip.legs.contains { leg in lines.contains { $0.matches(leg) } } }
    }
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
    if parser.isUnreadable {
        OJPUsage.shared.recordUnreadable("itinéraires")
        throw ParserError.xmlParsingFailed
    }
    return parser.trips.map(StopNames.withOfficialDestinations)
}

/// `<PlaceRef>` d'un départ ou d'une arrivée : l'arrêt, ou les coordonnées d'un lieu.
/// `nil` si l'élément attendu manque.
private func placeRefXML(stop: Stop?, geoPosition: GeoPosition?, useGeoPosition: Bool) -> String? {
    let reference: String
    let name: String
    if useGeoPosition {
        guard let geoPosition else { return nil }
        reference = """
        <GeoPosition>
            <siri:Longitude>\(geoPosition.coordinate.longitude)</siri:Longitude>
            <siri:Latitude>\(geoPosition.coordinate.latitude)</siri:Latitude>
        </GeoPosition>
        """
        name = geoPosition.name
    } else {
        guard let stop else { return nil }
        reference = "<StopPlaceRef>\(stop.sloid.xmlEscaped)</StopPlaceRef>"
        name = stop.name
    }
    return """
    <PlaceRef>
        \(reference)
        <Name>
            <Text>\(name.xmlEscaped)</Text>
        </Name>
    </PlaceRef>
    """
}

/// Le `<LineFilter>` qui exclut `lines`, vide sans ligne à éviter. Il précède les autres
/// paramètres de la requête.
func lineFilterXML(avoiding lines: [AvoidedLine]) -> String {
    guard !lines.isEmpty else { return "" }
    let refs = lines.map { "<Line><siri:LineRef>\($0.lineRef.xmlEscaped)</siri:LineRef></Line>" }.joined()
    return "<LineFilter>\(refs)<Exclude>true</Exclude></LineFilter>"
}

/// Les itinéraires entre deux points (OJP 2.0). `completion` reçoit la réponse brute,
/// ou la raison de l'échec, sur le thread principal.
///
/// OJP 2.0 ne propose pas les bus à la demande (tpg flex), que la 1.0 donnait comme des bus
/// ordinaires, parfois seuls : l'heure n'y est qu'une proposition, il faut réserver.
/// `avoidedLines` : les lignes à exclure (`LineFilter`), dans les deux sens.
public func fetchTrips(with departureStop: Stop?, with departureGeoPosition: GeoPosition?, with geoDeparture: Bool, with arrivalStop: Stop?, with arrivalGeoPosition: GeoPosition?, with geoArrival: Bool, with selectedTime: Date, with isArrivalTime: Bool, avoiding avoidedLines: [AvoidedLine] = [], completion: @escaping (Result<Data, OJPClient.Failure>) -> Void) {
    // Sans déballage forcé : un lieu attendu mais absent faisait planter l'app.
    guard let origin = placeRefXML(stop: departureStop, geoPosition: departureGeoPosition, useGeoPosition: geoDeparture),
          let destination = placeRefXML(stop: arrivalStop, geoPosition: arrivalGeoPosition, useGeoPosition: geoArrival) else {
        Log.network.error("Itinéraires : départ ou arrivée manquant")
        completion(.failure(.badRequest(status: 0)))
        return
    }
    let requestTimestamp = OJPDate.string(from: Date())
    let depArrTime = "<DepArrTime>\(OJPDate.string(from: selectedTime))</DepArrTime>"
    // L'ordre des paramètres suit le schéma OJP 2.0 : l'API refuse une requête désordonnée.
    // Sans `NumberOfResults`, elle ne trouve aucun itinéraire (TRIP_NOTRIPFOUND). Elle en
    // rend souvent plus que demandé : 5 en donne 8 à 10.
    let xmlString = """
    <?xml version="1.0" encoding="utf-8"?>
    <OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
        <OJPRequest>
            <siri:ServiceRequest>
                <siri:RequestTimestamp>\(requestTimestamp)</siri:RequestTimestamp>
                <siri:RequestorRef>tpgNext</siri:RequestorRef>
                <OJPTripRequest>
                    <siri:RequestTimestamp>\(requestTimestamp)</siri:RequestTimestamp>
                    <Origin>
                        \(origin)
                        \(isArrivalTime ? "" : depArrTime)
                    </Origin>
                    <Destination>
                        \(destination)
                        \(isArrivalTime ? depArrTime : "")
                    </Destination>
                    <Params>
                        \(lineFilterXML(avoiding: avoidedLines))
                        <NumberOfResults>5</NumberOfResults>
                        <IncludeTrackSections>false</IncludeTrackSections>
                        <IncludeLegProjection>false</IncludeLegProjection>
                        <IncludeTurnDescription>false</IncludeTurnDescription>
                        <IncludeIntermediateStops>true</IncludeIntermediateStops>
                    </Params>
                </OJPTripRequest>
            </siri:ServiceRequest>
        </OJPRequest>
    </OJP>
    """
    OJPClient.post(xmlString, to: .v2, completion: completion)
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

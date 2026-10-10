//
//  LiveTripLinks.swift
//  tpgNextFunc
//
//  Ce que la page d'un trajet suivi ouvre et dessine, en plus de l'état de l'activité en direct.
//

import Foundation
import CoreLocation

/// L'activité en direct ne garde que des noms et des heures : elle doit tenir en 4 Ko. La page
/// du trajet suivi relit ici, dans ce que le suivi garde de son côté, de quoi ouvrir les lignes et
/// les arrêts, et de quoi dessiner la carte.
public struct LiveTripLinks: Hashable {
    /// Un véhicule, dans l'ordre des étapes de `TripActivityState`.
    public struct Leg: Hashable {
        /// La course, pour ouvrir la page de la ligne.
        public var line: StopEvent
        public var board: ShortStop
        public var alight: ShortStop
        /// Les heures prévues (format OJP) : elles désignent le passage de la course à l'arrêt.
        /// Vides quand on ne les connaît pas.
        public var boardTime: String
        public var alightTime: String
        public var boardCoordinates: Coordinates?
        public var alightCoordinates: Coordinates?
        /// L'étape d'itinéraire, pour son tracé réel ; `nil` pour une course suivie seule.
        public var tripLeg: TripLeg?
    }

    public var legs: [Leg]
    /// Le départ et l'arrivée quand ce sont des arrêts ; `nil` pour un lieu ou une adresse.
    public var origin: ShortStop?
    public var destination: ShortStop?
    public var originCoordinates: Coordinates?
    public var destinationCoordinates: Coordinates?

    /// Un itinéraire suivi : ses étapes en véhicule, avec le même filtre que l'activité
    /// (`trackedLegs`), pour que les index se correspondent.
    public init(trip: TripEvent) {
        func coordinates(_ latitude: String, _ longitude: String) -> Coordinates? {
            guard let latitude = Double(latitude), let longitude = Double(longitude),
                  latitude != 0 || longitude != 0 else { return nil }
            return Coordinates(lon: longitude, lat: latitude)
        }
        legs = trip.trackedLegs.map { leg in
            Leg(line: createStopEventFromTripLeg(tripLeg: leg),
                board: ShortStop(name: leg.legBoardStopName, sloid: sloidHarmonizer(code: leg.legBoardStopId)),
                alight: ShortStop(name: leg.legAlightStopName, sloid: sloidHarmonizer(code: leg.legAlightStopId)),
                boardTime: leg.legBoardTimetableTime, alightTime: leg.legAlightTimetableTime,
                boardCoordinates: coordinates(leg.legBoardLatitude, leg.legBoardLongitude),
                alightCoordinates: coordinates(leg.legAlightLatitude, leg.legAlightLongitude),
                tripLeg: leg)
        }
        if !trip.geoDeparture, let code = trip.startCode, !code.isEmpty {
            origin = ShortStop(name: trip.startName, sloid: sloidHarmonizer(code: code))
        }
        if !trip.geoArrival, let code = trip.endCode, !code.isEmpty {
            destination = ShortStop(name: trip.endName, sloid: sloidHarmonizer(code: code))
        }
        originCoordinates = trip.startCoordinates.isKnown ? trip.startCoordinates : legs.first?.boardCoordinates
        destinationCoordinates = trip.endCoordinates.isKnown ? trip.endCoordinates : legs.last?.alightCoordinates
    }

    /// Une course suivie depuis la page d'un arrêt ou d'une ligne, d'un arrêt à un autre.
    /// `points` : son tracé, s'il est connu, pour placer les deux arrêts.
    public init(journey event: StopEvent, board: ShortStop, alight: ShortStop, points: [TripRoute.Point]) {
        let first = points.first.map { Coordinates(lon: $0.longitude, lat: $0.latitude) }
        let last = points.count >= 2 ? points.last.map { Coordinates(lon: $0.longitude, lat: $0.latitude) } : nil
        // L'heure de la course n'est connue qu'à l'arrêt d'où elle a été ouverte.
        let opened = sloidHarmonizer(code: event.stopId) == sloidHarmonizer(code: board.sloid)
        legs = [Leg(line: event,
                    board: ShortStop(name: board.name, sloid: sloidHarmonizer(code: board.sloid)),
                    alight: ShortStop(name: alight.name, sloid: sloidHarmonizer(code: alight.sloid)),
                    boardTime: opened ? event.timetabledTime : "", alightTime: "",
                    boardCoordinates: first, alightCoordinates: last, tripLeg: nil)]
        origin = legs[0].board
        destination = legs[0].alight
        originCoordinates = first
        destinationCoordinates = last
    }
}

extension Coordinates {
    /// Vrai pour de vraies coordonnées : (0, 0) veut dire « inconnues ».
    var isKnown: Bool { lat != 0 || lon != 0 }
}

// MARK: - La carte du trajet suivi

public extension TripRoute {
    /// Où le véhicule devrait être à `date`, d'après ses heures de passage : entre les deux
    /// arrêts qui encadrent l'heure, au prorata du temps écoulé. Au premier arrêt avant le
    /// départ, au dernier après l'arrivée ; `nil` sans point.
    static func expectedPosition(on points: [Point], at date: Date) -> CLLocationCoordinate2D? {
        guard let first = points.first, let last = points.last else { return nil }
        func coordinate(_ point: Point) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        }
        if date <= first.time { return coordinate(first) }
        for index in 0..<(points.count - 1) where date < points[index + 1].time {
            let from = points[index]
            let to = points[index + 1]
            let span = to.time.timeIntervalSince(from.time)
            let fraction = span > 0 ? date.timeIntervalSince(from.time) / span : 0
            return CLLocationCoordinate2D(latitude: from.latitude + fraction * (to.latitude - from.latitude),
                                          longitude: from.longitude + fraction * (to.longitude - from.longitude))
        }
        return coordinate(last)
    }

    /// Coupe un tracé au point le plus proche de `point` : ce qui est parcouru, et ce qui reste.
    /// Le point de coupe appartient aux deux moitiés, pour qu'elles se touchent.
    static func split(_ track: [CLLocationCoordinate2D],
                      at point: CLLocationCoordinate2D) -> (done: [CLLocationCoordinate2D], remaining: [CLLocationCoordinate2D]) {
        guard track.count >= 2 else { return ([], track) }
        // En mètres autour du point : à l'échelle d'une ville, la terre est plate.
        let metersPerLongitude = 111_320.0 * cos(point.latitude * .pi / 180)
        let metersPerLatitude = 111_132.0
        func local(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            ((coordinate.longitude - point.longitude) * metersPerLongitude,
             (coordinate.latitude - point.latitude) * metersPerLatitude)
        }
        var best = (index: 0, fraction: 0.0, distance: Double.infinity)
        for index in 0..<(track.count - 1) {
            let start = local(track[index])
            let end = local(track[index + 1])
            let dx = end.x - start.x
            let dy = end.y - start.y
            let squared = dx * dx + dy * dy
            let fraction = squared > 0 ? min(max(-(start.x * dx + start.y * dy) / squared, 0), 1) : 0
            let distance = hypot(start.x + fraction * dx, start.y + fraction * dy)
            if distance < best.distance { best = (index, fraction, distance) }
        }
        let from = track[best.index]
        let to = track[best.index + 1]
        let cut = CLLocationCoordinate2D(latitude: from.latitude + best.fraction * (to.latitude - from.latitude),
                                         longitude: from.longitude + best.fraction * (to.longitude - from.longitude))
        return (Array(track[...best.index]) + [cut], [cut] + Array(track[(best.index + 1)...]))
    }
}

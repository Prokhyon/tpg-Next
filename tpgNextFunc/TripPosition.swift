//
//  TripPosition.swift
//  tpgNextFunc
//
//  Ce que la position du voyageur dit du véhicule qu'il suit.
//

import Foundation

/// Le tracé d'un trajet suivi : les arrêts de chaque véhicule, avec leurs coordonnées et leurs
/// heures de passage.
///
/// Il reste dans l'app : l'activité en direct, elle, doit tenir en 4 Ko et n'a que faire des
/// coordonnées. C'est la règle du tracé (`TripPositionEstimator`) qui s'en sert.
public struct TripRoute: Codable, Hashable, Sendable {
    /// Un arrêt du tracé : où il est, et quand le véhicule y passe.
    public struct Point: Codable, Hashable, Sendable {
        public var latitude: Double
        public var longitude: Double
        public var time: Date

        public init(latitude: Double, longitude: Double, time: Date) {
            self.latitude = latitude
            self.longitude = longitude
            self.time = time
        }
    }

    /// Les points de chaque véhicule, dans l'ordre des étapes de `TripActivityState`.
    public var legs: [[Point]]

    public init(legs: [[Point]]) { self.legs = legs }

    public func points(of leg: Int) -> [Point] { legs.indices.contains(leg) ? legs[leg] : [] }

    public var isEmpty: Bool { legs.allSatisfy { $0.count < 2 } }
}

public extension TripRoute {
    /// Le tracé d'une course entre deux de ses arrêts. Vide si l'un des deux manque.
    static func points(from events: [LineEvent], boardSloid: String, alightSloid: String) -> [Point] {
        func stop(_ event: LineEvent) -> String {
            sloidHarmonizer(code: event.sloid.isEmpty ? event.stopPlaceRef : event.sloid)
        }
        let board = sloidHarmonizer(code: boardSloid)
        let alight = sloidHarmonizer(code: alightSloid)
        guard let boardIndex = events.firstIndex(where: { stop($0) == board }) else { return [] }
        let alightIndex = events[boardIndex...].firstIndex(where: { stop($0) == alight }) ?? events.count - 1
        return events[boardIndex...alightIndex].compactMap { event in
            guard let time = event.departureDate,
                  let latitude = Double(event.latitude), let longitude = Double(event.longitude) else { return nil }
            return Point(latitude: latitude, longitude: longitude, time: time)
        }
    }

    /// Le tracé d'une étape d'itinéraire, d'après les passages de sa course.
    static func points(from events: [LineEvent], for leg: TripLeg) -> [Point] {
        points(from: events, boardSloid: leg.legBoardStopId, alightSloid: leg.legAlightStopId)
    }

    /// Faute de passages : les deux arrêts de l'étape, reliés en ligne droite. Un vrai parcours
    /// s'en écarte, et la règle du tracé refusera alors de corriger — c'est voulu.
    static func endpoints(of leg: TripLeg) -> [Point] {
        guard let board = leg.boardDate, let alight = leg.alightDate,
              let boardLatitude = Double(leg.legBoardLatitude), let boardLongitude = Double(leg.legBoardLongitude),
              let alightLatitude = Double(leg.legAlightLatitude), let alightLongitude = Double(leg.legAlightLongitude)
        else { return [] }
        return [Point(latitude: boardLatitude, longitude: boardLongitude, time: board),
                Point(latitude: alightLatitude, longitude: alightLongitude, time: alight)]
    }
}

/// Ce que la position apprend sur le véhicule en cours.
public struct TripPositionFix: Hashable, Sendable {
    /// L'écart avec l'heure prévue au point atteint. Positif : le véhicule est en retard.
    public var offset: TimeInterval
    /// La distance entre la position et le tracé, en mètres.
    public var distance: Double
    /// La part parcourue de l'étape, de 0 (montée) à 1 (descente).
    public var progress: Double
    /// L'heure à laquelle le véhicule devait être là où l'on est.
    public var reached: Date

    public init(offset: TimeInterval, distance: Double, progress: Double, reached: Date) {
        self.offset = offset
        self.distance = distance
        self.progress = progress
        self.reached = reached
    }
}

/// Où en est le véhicule, d'après la position du voyageur qui s'y trouve.
///
/// Dans le véhicule, la position du voyageur *est* celle du véhicule : la projeter sur le tracé
/// donne le point atteint, et l'écart entre l'heure de ce point et l'heure qu'il est dit l'avance
/// ou le retard — sans rien demander à personne.
///
/// Deux garde-fous, parce qu'un trajet peut être suivi de loin (on ne monte pas dedans) et que
/// le tracé peut être grossier : au-delà de `maximumDistance` du tracé, la position ne dit rien
/// de ce véhicule ; au-delà de `maximumOffset` d'écart, c'est l'horaire d'OJP qui a raison.
public enum TripPositionEstimator {
    /// Au-delà, le voyageur n'est pas dans ce véhicule.
    public static let maximumDistance: Double = 150
    /// L'imprécision de la position prise en compte, au plus.
    public static let maximumAccuracy: Double = 100
    /// L'écart maximal admis entre la position et l'horaire : au-delà, OJP a raison.
    public static let maximumOffset: TimeInterval = 180

    /// `nil` si la position ne dit rien de fiable : trop loin du tracé, tracé trop court, ou
    /// écart trop grand avec l'horaire.
    public static func fix(on points: [TripRoute.Point], latitude: Double, longitude: Double,
                           accuracy: Double = 0, now: Date) -> TripPositionFix? {
        guard let projected = projections(on: points, latitude: latitude, longitude: longitude, now: now),
              let nearest = projected.fixes.min(by: { $0.distance < $1.distance }),
              nearest.distance <= maximumDistance + min(max(accuracy, 0), maximumAccuracy) else { return nil }
        // Un parcours qui repasse près de lui-même donne deux points aussi proches : celui dont
        // l'heure colle le mieux est le bon.
        let chosen = projected.fixes
            .filter { $0.distance <= nearest.distance + 50 }
            .min { abs($0.offset) < abs($1.offset) } ?? nearest
        guard abs(chosen.offset) <= maximumOffset else { return nil }
        return chosen
    }

    /// Le voyageur est-il dans ce véhicule ?
    ///
    /// Il l'est s'il se trouve là où le véhicule devrait être à cette heure. Resté à l'arrêt
    /// pendant que le véhicule s'éloigne, il ne l'est pas — c'est ce qui départage une
    /// correspondance serrée attrapée d'une correspondance manquée. `nil` quand on ne peut
    /// rien en dire (tracé trop court).
    public static func isAboard(on points: [TripRoute.Point], latitude: Double, longitude: Double,
                                accuracy: Double = 0, now: Date, tolerance: Double = 300) -> Bool? {
        guard let projected = projections(on: points, latitude: latitude, longitude: longitude, now: now),
              let nearest = projected.fixes.min(by: { $0.distance < $1.distance }) else { return nil }
        let margin = min(max(accuracy, 0), maximumAccuracy)
        // Ailleurs que sur le parcours : ce n'est pas dans ce véhicule-là.
        guard nearest.distance <= maximumDistance + margin else { return false }
        let travelled = nearest.progress * projected.length
        return abs(travelled - expected(on: points, lengths: projected.lengths, at: now)) <= tolerance + margin
    }

    /// La distance que le véhicule devrait avoir parcourue à cette heure.
    private static func expected(on points: [TripRoute.Point], lengths: [Double], at date: Date) -> Double {
        guard let first = points.first, let last = points.last, let total = lengths.last else { return 0 }
        if date <= first.time { return 0 }
        if date >= last.time { return total }
        for index in 0..<(points.count - 1) where date < points[index + 1].time {
            let span = points[index + 1].time.timeIntervalSince(points[index].time)
            guard span > 0 else { return lengths[index] }
            let fraction = date.timeIntervalSince(points[index].time) / span
            return lengths[index] + fraction * (lengths[index + 1] - lengths[index])
        }
        return total
    }

    /// La position projetée sur chaque segment du tracé, avec les longueurs cumulées.
    private static func projections(on points: [TripRoute.Point], latitude: Double, longitude: Double,
                                    now: Date) -> (fixes: [TripPositionFix], lengths: [Double], length: Double)? {
        guard points.count >= 2 else { return nil }
        // Tout en mètres autour de la position : à l'échelle d'une ville, la terre est plate.
        let metersPerLatitude = 111_132.0
        let metersPerLongitude = 111_320.0 * cos(latitude * .pi / 180)
        let local = points.map { (x: ($0.longitude - longitude) * metersPerLongitude,
                                  y: ($0.latitude - latitude) * metersPerLatitude) }

        var lengths: [Double] = [0]
        for index in 1..<local.count {
            lengths.append(lengths[index - 1] + hypot(local[index].x - local[index - 1].x,
                                                      local[index].y - local[index - 1].y))
        }
        guard let total = lengths.last, total > 0 else { return nil }

        var fixes: [TripPositionFix] = []
        for index in 0..<(local.count - 1) {
            let (fraction, distance) = closest(from: local[index], to: local[index + 1])
            let span = points[index + 1].time.timeIntervalSince(points[index].time)
            let reached = points[index].time.addingTimeInterval(fraction * span)
            let travelled = lengths[index] + fraction * (lengths[index + 1] - lengths[index])
            fixes.append(TripPositionFix(offset: now.timeIntervalSince(reached), distance: distance,
                                         progress: travelled / total, reached: reached))
        }
        return (fixes, lengths, total)
    }

    /// Le point du segment le plus proche de l'origine : la fraction parcourue et la distance.
    private static func closest(from start: (x: Double, y: Double),
                                to end: (x: Double, y: Double)) -> (fraction: Double, distance: Double) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let squared = dx * dx + dy * dy
        guard squared > 0 else { return (0, hypot(start.x, start.y)) }
        let fraction = min(max(-(start.x * dx + start.y * dy) / squared, 0), 1)
        return (fraction, hypot(start.x + fraction * dx, start.y + fraction * dy))
    }
}

public extension TripActivityState {
    /// Le décalage minimal qui vaut la peine d'être appliqué : en deçà, la position ne fait
    /// que trembler.
    static let minimumPositionOffset: TimeInterval = 30

    /// Décale le véhicule en cours de `offset` : sa descente, ses passages à venir, et l'arrivée
    /// si c'est le dernier. Les véhicules suivants gardent leurs heures : ils ne partagent pas
    /// ce retard-là.
    func adjusted(leg index: Int, by offset: TimeInterval, now: Date) -> TripActivityState {
        guard legs.indices.contains(index), abs(offset) >= Self.minimumPositionOffset else { return self }
        var state = self
        var leg = state.legs[index]
        leg.alight = max(now, leg.alight.addingTimeInterval(offset))
        leg.calls = leg.calls?.map { call in
            call.time > now ? Call(name: call.name, time: call.time.addingTimeInterval(offset)) : call
        }
        state.legs[index] = leg
        if index == state.legs.count - 1 {
            state.arrival = max(now, state.arrival.addingTimeInterval(offset))
        }
        state.positionOffset = Int(offset.rounded())
        return state
    }
}

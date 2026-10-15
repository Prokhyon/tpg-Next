//
//  EventDates.swift
//  tpgNextFunc
//
//  Les heures des modèles, en `Date`.
//

import Foundation

// Les champs texte restent stockés tels quels : ils sont enregistrés (trajets sauvegardés,
// rappels programmés) et leur format ne doit pas changer. Les vues passent par ces dates.

extension StopEvent {
    public var timetabledDate: Date? { OJPDate.date(from: timetabledTime) }
    public var estimatedDate: Date? { OJPDate.date(from: estimatedTime) }
    /// L'heure de passage : estimée si elle est connue, sinon prévue.
    public var departureDate: Date? { estimatedDate ?? timetabledDate }
}

extension LineEvent {
    public var timetabledDate: Date? { OJPDate.date(from: timetabledTime) }
    public var estimatedDate: Date? { OJPDate.date(from: estimatedTime) }
    /// L'heure de passage : estimée si elle est connue, sinon prévue.
    public var departureDate: Date? { estimatedDate ?? timetabledDate }
}

extension TripEvent {
    public var startDate: Date? { OJPDate.date(from: startTime) }
    public var endDate: Date? { OJPDate.date(from: endTime) }
}

extension TripLeg {
    /// La montée : heure estimée si elle est connue, sinon prévue. Sans temps réel, l'API
    /// laisse l'heure estimée vide, et l'étape n'était alors jamais considérée comme passée.
    public var boardDate: Date? { OJPDate.date(from: legBoardEstimatedTime) ?? OJPDate.date(from: legBoardTimetableTime) }
    /// La descente : heure estimée si elle est connue, sinon prévue.
    public var alightDate: Date? { OJPDate.date(from: legAlightEstimatedTime) ?? OJPDate.date(from: legAlightTimetableTime) }

    /// La durée de l'étape. Seule celle des étapes à pied est gardée : celle d'un bus ou d'un
    /// tram (`TimedLeg`) vient de ses heures de montée et de descente.
    public var duration: TimeInterval? {
        if let boardDate, let alightDate {
            return alightDate.timeIntervalSince(boardDate)
        }
        return durationMinutes(transfer ? transferDuration : legDuration).map { TimeInterval($0 * 60) }
    }
}

/// La place d'une étape sur la frise d'un itinéraire, en fractions du trajet :
/// 0 au départ, 1 à l'arrivée.
public struct TripLegSpan: Identifiable {
    public let leg: TripLeg
    public let range: ClosedRange<Double>
    /// La part marchée d'une étape à pied : le début de la correspondance, la suite étant
    /// de l'attente. `nil` pour un bus ou un tram.
    public let walk: ClosedRange<Double>?
    public var id: String { leg.id }
}

extension TripLeg {
    /// Le temps de marche d'une étape à pied. Une correspondance le donne à part de l'attente ;
    /// un trajet entièrement à pied (`ContinuousLeg`) n'a que sa durée. `nil` pour un bus ou un tram.
    public var walkDuration: TimeInterval? {
        guard transfer else { return nil }
        return (durationMinutes(transferWalkDuration) ?? durationMinutes(transferDuration)).map { TimeInterval($0 * 60) }
    }
}

extension TripEvent {
    /// Les étapes placées dans le temps. Additionner leurs durées ne suffit pas : les attentes
    /// entre deux véhicules n'ont pas d'étape à elles.
    ///
    /// Un bus ou un tram se place à ses heures. Une étape à pied n'en a pas : elle couvre toute
    /// la correspondance, jusqu'à la montée suivante (ou l'arrivée), et sa marche n'en occupe
    /// que le début. Sa `Duration` compte une marge et déborderait parfois sur le bus d'après.
    /// Sans heures lisibles, les étapes se partagent la frise à parts égales.
    public var legSpans: [TripLegSpan] {
        guard let startDate, let endDate, endDate > startDate else {
            let count = Double(legs.count)
            return legs.enumerated().map { index, leg in
                let range = Double(index) / count...Double(index + 1) / count
                return TripLegSpan(leg: leg, range: range, walk: leg.transfer ? range : nil)
            }
        }
        let total = endDate.timeIntervalSince(startDate)
        func fraction(_ date: Date) -> Double {
            min(max(date.timeIntervalSince(startDate) / total, 0), 1)
        }
        func range(_ start: Date, _ end: Date) -> ClosedRange<Double> {
            fraction(start)...max(fraction(start), fraction(end))
        }
        var cursor = startDate
        return legs.enumerated().map { index, leg in
            let start = leg.boardDate ?? cursor
            let end: Date
            if let alightDate = leg.alightDate {
                end = alightDate
            } else {
                let next = index + 1 < legs.count ? legs[index + 1].boardDate : endDate
                end = max(start, next ?? start.addingTimeInterval(leg.duration ?? 0))
            }
            cursor = max(cursor, end)
            let walkEnd = leg.walkDuration.map { min(start.addingTimeInterval($0), end) }
            return TripLegSpan(leg: leg, range: range(start, end), walk: walkEnd.map { range(start, $0) })
        }
    }
}

/// `true` si `date` est passée, à la minute près : les secondes sont ignorées.
/// Une date inconnue n'est jamais passée.
/// - Parameter includingCurrentMinute: la minute en cours compte déjà comme passée.
public func hasPassed(_ date: Date?, includingCurrentMinute: Bool, now: Date = AppClock.now()) -> Bool {
    guard let date else { return false }
    let minute = (date.timeIntervalSince1970 / 60).rounded(.down)
    let currentMinute = (now.timeIntervalSince1970 / 60).rounded(.down)
    return includingCurrentMinute ? minute <= currentMinute : minute < currentMinute
}

// Trier le texte des heures ne marche que si elles sont toutes écrites de la même façon ;
// l'API mélange « Z », « +02:00 » et les millisecondes.

extension Sequence where Element == StopEvent {
    /// Du prochain passage au plus lointain ; les heures illisibles en dernier.
    public func sortedByDeparture() -> [StopEvent] {
        sorted { ($0.departureDate ?? .distantFuture) < ($1.departureDate ?? .distantFuture) }
    }
}

extension Sequence where Element == TripEvent {
    /// Du premier départ au dernier ; les heures illisibles en dernier.
    public func sortedByStart() -> [TripEvent] {
        sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
    }
}

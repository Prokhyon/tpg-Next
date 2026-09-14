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
}

/// `true` si `date` est passée, à la minute près : les secondes sont ignorées.
/// Une date inconnue n'est jamais passée.
/// - Parameter includingCurrentMinute: la minute en cours compte déjà comme passée.
public func hasPassed(_ date: Date?, includingCurrentMinute: Bool, now: Date = Date()) -> Bool {
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

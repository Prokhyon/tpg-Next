//
//  TripVerification.swift
//  tpgNextFunc
//
//  Un itinéraire déjà connu, vérifié course par course plutôt que redemandé en entier.
//

import Foundation

/// OJP ne propose que quelques itinéraires par requête, choisis d'après le temps réel du
/// moment : un trajet absent de sa réponse peut très bien rester faisable (un autre est devenu
/// plus rapide, ou il ne tient plus dans les cinq proposés). Avant de le déclarer perdu, on
/// relit chacune de ses courses (`OJPTripInfoRequest`) et on vérifie que les correspondances
/// tiennent toujours.
public enum TripVerifier {
    public enum Outcome: Hashable {
        /// Toutes les courses passent là où il faut et les correspondances tiennent :
        /// l'itinéraire, avec les heures relues.
        case feasible(TripEvent)
        /// Une course ne s'arrête plus à la montée ou à la descente, ou le véhicule suivant part
        /// avant qu'on arrive.
        case broken
        /// Impossible à dire : course sans référence, API muette, arrêt introuvable dans la course.
        case unknown
    }

    /// Relit les courses de l'itinéraire et dit s'il tient toujours.
    public static func verify(_ trip: TripEvent) async -> Outcome {
        let legs = trip.vehicleLegs
        guard !legs.isEmpty, legs.allSatisfy({ !$0.journeyRef.isEmpty }) else { return .unknown }
        var passages: [String: [LineEvent]] = [:]
        for leg in legs where passages[leg.journeyRef] == nil {
            guard let events = await TripActivityState.fetchJourney(for: leg) else { return .unknown }
            passages[leg.journeyRef] = events
        }
        return outcome(of: trip, passages: passages)
    }

    /// Le verdict, d'après les passages de chaque course (par `journeyRef`).
    ///
    /// Une correspondance ne casse que si le véhicule suivant part avant l'arrivée du premier.
    /// Plus serrée que la marche prévue, elle reste jouable : `RegularTripStatus` la signale
    /// alors comme compromise, sans remplacer le trajet.
    static func outcome(of trip: TripEvent, passages: [String: [LineEvent]]) -> Outcome {
        var trip = trip
        for index in trip.legs.indices {
            let leg = trip.legs[index]
            guard !leg.transfer, !leg.publishedLineName.isEmpty else { continue }
            guard let events = passages[leg.journeyRef],
                  let board = passageIndex(of: leg.legBoardStopId, in: events, from: 0,
                                           timetabled: leg.legBoardTimetableTime),
                  let alight = passageIndex(of: leg.legAlightStopId, in: events, from: board + 1,
                                            timetabled: leg.legAlightTimetableTime) else { return .unknown }
            if events[board].isCancelled == true || events[alight].isCancelled == true { return .broken }
            if !events[board].estimatedTime.isEmpty {
                trip.legs[index].legBoardEstimatedTime = events[board].estimatedTime
            }
            if !events[alight].estimatedTime.isEmpty {
                trip.legs[index].legAlightEstimatedTime = events[alight].estimatedTime
            }
        }
        var previous: TripLeg?
        for leg in trip.vehicleLegs {
            if let previous, let alight = previous.alightDate, let board = leg.boardDate, board < alight {
                return .broken
            }
            previous = leg
        }
        return .feasible(trip)
    }

    /// Le passage de la course à cet arrêt, à partir de `start`. Une course peut passer deux
    /// fois au même arrêt (boucle) : l'heure prévue départage.
    private static func passageIndex(of sloid: String, in events: [LineEvent], from start: Int,
                                     timetabled: String) -> Int? {
        let wanted = sloidHarmonizer(code: sloid)
        guard start < events.count else { return nil }
        let candidates = events.indices[start...].filter {
            sloidHarmonizer(code: events[$0].sloid.isEmpty ? events[$0].stopPlaceRef : events[$0].sloid) == wanted
        }
        return candidates.first { events[$0].timetabledTime == timetabled } ?? candidates.first
    }
}

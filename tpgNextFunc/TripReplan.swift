//
//  TripReplan.swift
//  tpgNextFunc
//
//  Quand la suite d'un trajet en cours ne tient plus : garder ce qui est parcouru,
//  redemander le reste depuis là où l'on est.
//

import Foundation

public extension TripActivityState {
    /// Le temps minimal pour assurer une correspondance : en dessous, on ne monte pas.
    static let minimumTransfer: TimeInterval = 60

    /// Vrai dès que le voyageur est parti — la première montée est passée, ou imminente.
    ///
    /// À partir de là, un itinéraire redemandé depuis le point de départ n'a plus de sens : il
    /// renverrait en arrière quelqu'un déjà à mi-chemin. C'est ce qui arrivait quand l'itinéraire
    /// suivi n'était plus proposé par l'API.
    func hasLeft(at date: Date, margin: TimeInterval = 60) -> Bool {
        guard let first = legs.first else { return false }
        return date >= first.board.addingTimeInterval(-margin)
    }

    /// L'étape après laquelle la suite ne tient plus : on en descend trop tard pour monter dans
    /// la suivante. `nil` si tout s'enchaîne encore.
    func brokenTransfer(margin: TimeInterval = minimumTransfer) -> Int? {
        legs.indices.dropLast().first { legs[$0].alight.addingTimeInterval(margin) > legs[$0 + 1].board }
    }
}

public extension TripEvent {
    /// Les étapes en véhicule retenues par l'activité : celles qui ont leurs deux heures.
    /// Même filtre que `TripActivityState(trip:)`, pour que les index se correspondent.
    var trackedLegs: [TripLeg] {
        vehicleLegs.filter { $0.boardDate != nil && $0.alightDate != nil }
    }

    /// Recolle la suite d'un itinéraire en cours : les étapes jusqu'à celle-ci restent telles
    /// quelles, la suite vient de `tail`. Le trajet garde son identité et son départ.
    func splicing(after leg: TripLeg, with tail: TripEvent) -> TripEvent {
        guard let index = legs.firstIndex(where: { $0.id == leg.id }) else { return self }
        var trip = self
        trip.legs = Array(legs.prefix(index + 1)) + tail.legs
        trip.endTime = tail.endTime
        trip.endName = tail.endName
        trip.endCode = tail.endCode
        trip.endCoordinates = tail.endCoordinates
        trip.geoArrival = tail.geoArrival
        trip.transfers = String(max(0, trip.vehicleLegs.count - 1))
        if let start = trip.startDate, let end = trip.endDate {
            trip.duration = "PT\(max(0, Int((end.timeIntervalSince(start) / 60).rounded())))M"
        }
        return trip
    }
}

/// Redemande la suite d'un trajet, depuis l'arrêt où l'on descend et à l'heure où l'on y sera.
///
/// Rien à voir avec la recherche d'itinéraire habituelle : le départ n'est pas celui du trajet,
/// c'est l'endroit où le voyageur se trouve rendu.
public enum TripReplanner {
    /// `nil` si l'API ne répond pas, ou si plus rien ne mène à destination.
    public static func tail(from stop: RegularTripPlace, at time: Date,
                            to destination: RegularTripPlace) async -> TripEvent? {
        let origin = stop.endpoint
        let arrival = destination.endpoint
        let data: Data? = await withCheckedContinuation { continuation in
            fetchTrips(with: origin.stop, with: origin.place, with: origin.isPlace,
                       with: arrival.stop, with: arrival.place, with: arrival.isPlace,
                       with: time, with: false) { continuation.resume(returning: $0) }
        }
        guard let data else { return nil }
        let trips = try? parseTripEvents(from: data, startCoordinate: stop.coordinates,
                                         endCoordinates: destination.coordinates,
                                         startName: stop.name, endName: destination.name,
                                         startCode: stop.sloid, endCode: destination.sloid,
                                         geoDeparture: stop.sloid == nil, geoArrival: destination.sloid == nil)
        guard let trips, !trips.isEmpty else { return nil }
        // Le premier arrivé parmi ceux qu'on peut encore attraper ; à défaut, le plus proche.
        let catchable = trips.filter { ($0.anchorDate(.departure, timetabled: false) ?? .distantPast) >= time }
        return catchable.min { ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture) }
            ?? trips.min { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }
}

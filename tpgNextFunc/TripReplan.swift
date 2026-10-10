//
//  TripReplan.swift
//  tpgNextFunc
//
//  Quand la suite d'un trajet en cours ne tient plus : garder ce qui est parcouru,
//  redemander le reste depuis là où l'on est.
//

import Foundation

public extension TripActivityState {
    /// Faute de mieux : le temps minimal pour changer de véhicule. OJP donne le sien étape par
    /// étape (`Leg.transferTime`), et c'est celui-là qui compte quand il est connu — une minute
    /// suffit là où l'on change de quai, pas dans une gare.
    static let minimumTransfer: TimeInterval = 60

    /// Ce qu'il advient d'une correspondance.
    @frozen enum Transfer: Hashable {
        /// Tout s'enchaîne.
        case held
        /// Serrée : le véhicule est encore là, mais de justesse. La position du voyageur, ou
        /// le voyageur lui-même, dira s'il est monté.
        case doubtful(leg: Int)
        /// Perdue : le véhicule était parti, ou il ne passe plus.
        case missed(leg: Int)
    }

    /// Vrai quand le voyageur est engagé : il est monté, ou il a déjà parcouru une étape.
    ///
    /// À partir de là, un itinéraire redemandé depuis le point de départ n'a plus de sens : il
    /// renverrait en arrière quelqu'un déjà à mi-chemin. C'est ce qui arrivait quand l'itinéraire
    /// suivi n'était plus proposé par l'API. Un véhicule supprimé ne compte pas : personne n'y
    /// est monté, et tout reste à refaire depuis le départ.
    func hasLeft(at date: Date, margin: TimeInterval = 60) -> Bool {
        switch phase(at: date) {
        case .waiting(let index):
            if index > 0 { return true }
            return legs[0].cancelled != true && date >= legs[0].board.addingTimeInterval(-margin)
        case .riding(let index):
            return legs[index].cancelled != true
        case .arrived:
            return legs.last?.cancelled != true
        }
    }

    /// La première correspondance qui pose problème, et ce qu'il lui arrive.
    func transferProblem() -> Transfer {
        for index in legs.indices.dropLast() {
            let next = legs[index + 1]
            if next.cancelled == true { return .missed(leg: index) }
            let needed = legs[index].transferTime.map { TimeInterval($0) } ?? Self.minimumTransfer
            let slack = next.board.timeIntervalSince(legs[index].alight)
            guard slack < needed else { continue }
            // Le véhicule est encore là quand on descend : c'est jouable, à la course.
            return slack >= 0 ? .doubtful(leg: index) : .missed(leg: index)
        }
        return .held
    }
}

public extension TripEvent {
    /// Le temps qu'OJP compte après chaque descente pour rejoindre le véhicule suivant : la
    /// marche des étapes de correspondance qui la suivent, par étape en véhicule.
    var transferTimes: [String: TimeInterval] {
        var times: [String: TimeInterval] = [:]
        var current: TripLeg?
        for leg in legs {
            if leg.transfer || leg.publishedLineName.isEmpty {
                if let current, let walk = leg.walkDuration { times[current.id, default: 0] += walk }
            } else {
                current = leg
            }
        }
        return times
    }

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
    /// Les suites possibles, la meilleure en tête : le premier arrivé parmi ceux qu'on peut
    /// encore attraper. Vide si l'API ne répond pas, ou si plus rien ne mène à destination.
    public static func tails(from stop: RegularTripPlace, at time: Date,
                             to destination: RegularTripPlace, avoiding avoidedLines: [AvoidedLine] = [],
                             limit: Int = 3) async -> [TripEvent] {
        let trips = await options(from: stop, at: time, to: destination, avoiding: avoidedLines)
        let catchable = trips.filter { ($0.anchorDate(.departure, timetabled: false) ?? .distantPast) >= time }
        let ranked = (catchable.isEmpty ? trips : catchable)
            .sorted { ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture) }
        return Array(ranked.prefix(limit))
    }

    /// `nil` si l'API ne répond pas, ou si plus rien ne mène à destination.
    public static func tail(from stop: RegularTripPlace, at time: Date,
                            to destination: RegularTripPlace) async -> TripEvent? {
        await tails(from: stop, at: time, to: destination, limit: 1).first
    }

    private static func options(from stop: RegularTripPlace, at time: Date,
                                to destination: RegularTripPlace, avoiding avoidedLines: [AvoidedLine]) async -> [TripEvent] {
        let origin = stop.endpoint
        let arrival = destination.endpoint
        let data: Data? = await withCheckedContinuation { continuation in
            fetchTrips(with: origin.stop, with: origin.place, with: origin.isPlace,
                       with: arrival.stop, with: arrival.place, with: arrival.isPlace,
                       with: time, with: false, avoiding: avoidedLines) { continuation.resume(returning: try? $0.get()) }
        }
        guard let data else { return [] }
        let trips = try? parseTripEvents(from: data, startCoordinate: stop.coordinates,
                                         endCoordinates: destination.coordinates,
                                         startName: stop.name, endName: destination.name,
                                         startCode: stop.sloid, endCode: destination.sloid,
                                         geoDeparture: stop.sloid == nil, geoArrival: destination.sloid == nil)
        return (trips ?? []).avoiding(avoidedLines)
    }
}

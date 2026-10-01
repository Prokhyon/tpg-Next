//
//  TripVerificationTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Itinéraire vérifié course par course")
struct TripVerificationTests {
    /// Le 12 puis le 19, Rive → Cornavin, dimanche 13.09.2026 vers 17:56.
    private func tripWithTransfer() throws -> TripEvent {
        let trips = try parseTripEvents(from: Fixture.data("trip-rive-cornavin"),
                                        startCoordinate: Coordinates(lon: 6.1418, lat: 46.1985),
                                        endCoordinates: Coordinates(lon: 6.1424, lat: 46.2102),
                                        startName: "Genève, Rive", endName: "Genève, gare Cornavin",
                                        startCode: "ch:1:sloid:87061", endCode: "ch:1:sloid:87057",
                                        geoDeparture: false, geoArrival: false)
        return try #require(trips.first { $0.vehicleLegs.map(\.publishedLineName) == ["12", "19"] })
    }

    private func event(_ sloid: String, _ timetabled: String, delay: TimeInterval?, cancelled: Bool = false) -> LineEvent {
        let estimated = delay.flatMap { delay in
            OJPDate.date(from: timetabled).map { OJPDate.string(from: $0.addingTimeInterval(delay)) }
        } ?? ""
        return LineEvent(stopPointName: sloid, plannedQuay: "", timetabledTime: timetabled, estimatedTime: estimated,
                         stopPlaceRef: sloid, sloid: sloid, previousCall: false, longitude: "", latitude: "",
                         isCancelled: cancelled ? true : nil)
    }

    /// Les passages de la course d'une étape : un arrêt avant, la montée, la descente.
    private func passages(of leg: TripLeg, boardDelay: TimeInterval? = 0, alightDelay: TimeInterval? = 0,
                          cancelledBoard: Bool = false) -> [LineEvent] {
        [event("ch:1:sloid:1", "2026-09-13T15:00:00Z", delay: nil),
         event(leg.legBoardStopId, leg.legBoardTimetableTime, delay: boardDelay, cancelled: cancelledBoard),
         event(leg.legAlightStopId, leg.legAlightTimetableTime, delay: alightDelay)]
    }

    @Test func aTripAbsentFromTheAnswerCanStillBeFeasible() throws {
        let trip = try tripWithTransfer()
        let legs = trip.vehicleLegs
        // Le 12 part avec deux minutes de retard mais en rattrape une et demie ; le 19 attend
        // une minute (prévu : descente à 16:02, montée à 16:03).
        let passages = [legs[0].journeyRef: passages(of: legs[0], boardDelay: 120, alightDelay: 30),
                        legs[1].journeyRef: passages(of: legs[1], boardDelay: 60)]
        guard case .feasible(let verified) = TripVerifier.outcome(of: trip, passages: passages) else {
            Issue.record("Le trajet devrait rester faisable")
            return
        }
        // Les heures relues remplacent celles de l'itinéraire.
        let board = try #require(OJPDate.date(from: legs[0].legBoardTimetableTime))
        #expect(verified.vehicleLegs[0].boardDate == board.addingTimeInterval(120))
        #expect(verified.id == trip.id)
    }

    @Test func aVehicleThatNoLongerStopsBreaksTheTrip() throws {
        let trip = try tripWithTransfer()
        let legs = trip.vehicleLegs
        let passages = [legs[0].journeyRef: passages(of: legs[0]),
                        legs[1].journeyRef: passages(of: legs[1], cancelledBoard: true)]
        #expect(TripVerifier.outcome(of: trip, passages: passages) == .broken)
    }

    /// La marge prévue entre la descente du 12 et la montée dans le 19.
    private func plannedSlack(_ legs: [TripLeg]) throws -> TimeInterval {
        let board = try #require(OJPDate.date(from: legs[1].legBoardTimetableTime))
        let alight = try #require(OJPDate.date(from: legs[0].legAlightTimetableTime))
        return board.timeIntervalSince(alight)
    }

    @Test func aConnectionLeftBeforeArrivingBreaksTheTrip() throws {
        let trip = try tripWithTransfer()
        let legs = trip.vehicleLegs
        let slack = try plannedSlack(legs)
        // Le 12 arrive une minute après le départ du 19.
        let passages = [legs[0].journeyRef: passages(of: legs[0], alightDelay: slack + 60),
                        legs[1].journeyRef: passages(of: legs[1])]
        #expect(TripVerifier.outcome(of: trip, passages: passages) == .broken)
    }

    @Test func aTightConnectionIsKeptButFlagged() throws {
        let trip = try tripWithTransfer()
        let legs = trip.vehicleLegs
        let slack = try plannedSlack(legs)
        // Le 12 arrive juste avant le départ du 19 : jouable, mais plus avec la marche prévue.
        let passages = [legs[0].journeyRef: passages(of: legs[0], alightDelay: slack - 10),
                        legs[1].journeyRef: passages(of: legs[1])]
        guard case .feasible(let verified) = TripVerifier.outcome(of: trip, passages: passages) else {
            Issue.record("Une correspondance serrée ne remplace pas le trajet")
            return
        }
        #expect(!RegularTripStatus(trip: verified).riskyConnections.isEmpty)
    }

    @Test func aSilentJourneyTellsNothing() throws {
        let trip = try tripWithTransfer()
        let legs = trip.vehicleLegs
        #expect(TripVerifier.outcome(of: trip, passages: [legs[0].journeyRef: passages(of: legs[0])]) == .unknown)
    }

    // MARK: Le trajet connu

    @Test func onlyTheSameDaysUsualTripIsKnown() throws {
        let trip = try tripWithTransfer()
        let regular = RegularTrip(trip: trip, weekdays: Weekday.workdays)
        let target = try #require(trip.anchorDate(.departure, timetabled: true))
        let today = RegularTripOccurrence(trip: regular, day: "2026-09-13", target: target)
        #expect(regular.knownUsual(trip, for: today) != nil)
        // Sans course datée, rien à vérifier.
        #expect(regular.knownUsual(regular.plannedTrip(for: today), for: today) == nil)
        // Une semaine plus tard, les courses du 13 ne disent rien.
        let nextWeek = RegularTripOccurrence(trip: regular, day: "2026-09-20", target: target.addingTimeInterval(7 * 86400))
        #expect(regular.knownUsual(trip, for: nextWeek) == nil)
        // Sans suivre les lignes, il n'y a pas de trajet habituel à défendre.
        var anyLine = regular
        anyLine.followsLines = false
        #expect(anyLine.knownUsual(trip, for: today) == nil)
    }

    @Test func aKnownTripAtAnotherTimeIsShifted() throws {
        let trip = try tripWithTransfer()
        let regular = RegularTrip(trip: trip, weekdays: Weekday.workdays)
        let target = try #require(trip.anchorDate(.departure, timetabled: true))
        let later = RegularTripOccurrence(trip: regular, day: "2026-09-13", target: target.addingTimeInterval(-10 * 60))
        #expect(regular.usualMatch(trip, for: later).kind == .shifted(minutes: 10))
        let same = RegularTripOccurrence(trip: regular, day: "2026-09-13", target: target)
        #expect(regular.usualMatch(trip, for: same).kind == .usual)
    }
}

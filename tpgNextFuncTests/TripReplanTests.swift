//
//  TripReplanTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Trajet en cours réparé")
struct TripReplanTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func leg(board: TimeInterval, alight: TimeInterval, line: String = "12") -> TripActivityState.Leg {
        .init(line: line, operatorName: "tpg", transportType: "Tram", destination: "Bachet",
              boardName: "Genève, Rive", boardQuay: "B", board: base.addingTimeInterval(board),
              alight: base.addingTimeInterval(alight), alightName: "Genève, Plainpalais", delay: 0)
    }

    private func state(_ legs: [TripActivityState.Leg]) -> TripActivityState {
        TripActivityState(legs: legs, departure: legs[0].board.addingTimeInterval(-60),
                          arrival: legs[legs.count - 1].alight, arrivalDelay: 0, alert: nil, updated: base)
    }

    @Test func leavingIsBoardingTheFirstVehicle() {
        let state = state([leg(board: 600, alight: 1200)])
        #expect(!state.hasLeft(at: base))
        // Une minute avant la montée, le voyageur est à l'arrêt : le trajet est engagé.
        #expect(state.hasLeft(at: base.addingTimeInterval(540)))
        #expect(state.hasLeft(at: base.addingTimeInterval(900)))
    }

    @Test func aConnectionThatHoldsIsNotBroken() {
        let state = state([leg(board: 0, alight: 600), leg(board: 900, alight: 1500, line: "15")])
        #expect(state.brokenTransfer() == nil)
    }

    @Test func aConnectionMissedByTheDelayIsBroken() {
        // La descente tombe trente secondes avant la montée suivante : on ne monte pas.
        let state = state([leg(board: 0, alight: 870), leg(board: 900, alight: 1500, line: "15")])
        #expect(state.brokenTransfer() == 0)
    }

    @Test func splicingKeepsWhatIsAlreadyTravelled() throws {
        let trip = FullTripTest().Trip
        let first = try #require(trip.trackedLegs.first)
        let index = try #require(trip.legs.firstIndex { $0.id == first.id })
        let spliced = trip.splicing(after: first, with: trip)
        // Les étapes jusqu'à la première descente restent, la suite vient du nouvel itinéraire.
        #expect(spliced.legs.count == index + 1 + trip.legs.count)
        #expect(spliced.legs.prefix(index + 1).map(\.id) == trip.legs.prefix(index + 1).map(\.id))
        #expect(spliced.endTime == trip.endTime)
        #expect(spliced.id == trip.id)
    }

    @Test func splicingIgnoresALegThatIsNotThere() {
        let trip = FullTripTest().Trip
        var stranger = trip.legs[0]
        stranger.id = "ailleurs"
        #expect(trip.splicing(after: stranger, with: trip) == trip)
    }
}

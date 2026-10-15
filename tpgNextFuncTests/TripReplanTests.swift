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

    private func leg(board: TimeInterval, alight: TimeInterval, line: String = "12",
                     transfer: Int? = nil, cancelled: Bool? = nil) -> TripActivityState.Leg {
        .init(line: line, operatorName: "tpg", transportType: "Tram", destination: "Bachet",
              boardName: "Genève, Rive", boardQuay: "B", board: base.addingTimeInterval(board),
              alight: base.addingTimeInterval(alight), alightName: "Genève, Plainpalais", delay: 0,
              calls: nil, transferTime: transfer, cancelled: cancelled)
    }

    private func state(_ legs: [TripActivityState.Leg]) -> TripActivityState {
        TripActivityState(legs: legs, departure: legs[0].board.addingTimeInterval(-60),
                          arrival: legs[legs.count - 1].alight, arrivalDelay: 0, alert: nil, updated: base)
    }

    // MARK: Parti ou non

    @Test func leavingIsBoardingTheFirstVehicle() {
        let state = state([leg(board: 600, alight: 1200)])
        #expect(!state.hasLeft(at: base))
        // Une minute avant la montée, le voyageur est à l'arrêt : le trajet est engagé.
        #expect(state.hasLeft(at: base.addingTimeInterval(540)))
        #expect(state.hasLeft(at: base.addingTimeInterval(900)))
    }

    @Test func aCancelledFirstVehicleLeavesNobody() {
        // Le véhicule ne passe plus : rien n'est commencé, tout peut être redemandé.
        let state = state([leg(board: 600, alight: 1200, cancelled: true)])
        #expect(!state.hasLeft(at: base.addingTimeInterval(900)))
    }

    @Test func aTransferMeansTheTripHasStarted() {
        let state = state([leg(board: 0, alight: 600), leg(board: 900, alight: 1500, line: "15")])
        // Entre les deux véhicules : une étape est déjà parcourue.
        #expect(state.hasLeft(at: base.addingTimeInterval(700)))
    }

    // MARK: Marcher ou attendre

    @Test func walkingBeforeTheFirstBoarding() {
        // Cinq minutes de marche avant la montée.
        let state = TripActivityState(legs: [leg(board: 300, alight: 900)], departure: base,
                                      arrival: base.addingTimeInterval(900), arrivalDelay: 0,
                                      alert: nil, updated: base)
        #expect(!state.isWalking(at: base.addingTimeInterval(-60)))
        #expect(state.isWalking(at: base.addingTimeInterval(60)))
        // Dans le véhicule, on ne marche plus.
        #expect(!state.isWalking(at: base.addingTimeInterval(600)))
    }

    @Test func waitingAtTheStopIsNotWalking() {
        // Le trajet commence à l'arrêt : rien à marcher, on attend.
        let state = state([leg(board: 300, alight: 900)])
        #expect(!state.isWalking(at: base.addingTimeInterval(60)))
    }

    @Test func walkingDuringTheTransferTime() {
        let state = state([leg(board: 0, alight: 600, transfer: 300),
                           leg(board: 1200, alight: 1800, line: "15")])
        // Trois minutes après la descente : encore en chemin vers l'autre quai.
        #expect(state.isWalking(at: base.addingTimeInterval(780)))
        // Passé les cinq minutes de marche, c'est de l'attente.
        #expect(!state.isWalking(at: base.addingTimeInterval(1000)))
    }

    // MARK: L'état d'une correspondance

    @Test func aConnectionThatHoldsIsNotAProblem() {
        let state = state([leg(board: 0, alight: 600), leg(board: 900, alight: 1500, line: "15")])
        #expect(state.transferProblem() == .held)
    }

    @Test func theTransferTimeOfTheApiWins() {
        // Quatre minutes entre la descente et la montée, mais OJP en demande cinq pour marcher.
        #expect(state([leg(board: 0, alight: 600, transfer: 300),
                       leg(board: 840, alight: 1500, line: "15")]).transferProblem() == .doubtful(leg: 0))
        // Une minute demandée : la même correspondance tient.
        #expect(state([leg(board: 0, alight: 600, transfer: 60),
                       leg(board: 840, alight: 1500, line: "15")]).transferProblem() == .held)
    }

    @Test func aTightConnectionIsOnlyDoubtful() {
        // Le 15 part trente secondes après la descente : jouable, à la course.
        let state = state([leg(board: 0, alight: 870), leg(board: 900, alight: 1500, line: "15")])
        #expect(state.transferProblem() == .doubtful(leg: 0))
    }

    @Test func aVehicleAlreadyGoneIsMissed() {
        let state = state([leg(board: 0, alight: 960), leg(board: 900, alight: 1500, line: "15")])
        #expect(state.transferProblem() == .missed(leg: 0))
    }

    @Test func aCancelledNextVehicleIsMissedHoweverEarlyOneArrives() {
        let state = state([leg(board: 0, alight: 300),
                           leg(board: 900, alight: 1500, line: "15", cancelled: true)])
        #expect(state.transferProblem() == .missed(leg: 0))
    }

    // MARK: Recoller la suite

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

    @Test func theTransferTimesComeFromTheTrip() throws {
        // Le trajet d'essai a une correspondance à pied entre ses deux véhicules.
        let trip = FullTripTest().Trip
        let times = trip.transferTimes
        let first = try #require(trip.trackedLegs.first)
        #expect(times[first.id] ?? 0 > 0)
        // Et l'état la reprend telle quelle.
        let state = try #require(TripActivityState(trip: trip, alert: nil))
        #expect(state.legs[0].transferTime == times[first.id].map { Int($0) })
    }
}

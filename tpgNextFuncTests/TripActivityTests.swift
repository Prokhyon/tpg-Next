//
//  TripActivityTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Activité en direct")
struct TripActivityTests {
    /// Meinier → Rondeau : A de 14:51:42 à 15:10:42, puis 12 de 15:20:42 à 15:35:42 (UTC).
    private func state() throws -> TripActivityState {
        try #require(TripActivityState(trip: FullTripTest().Trip, alert: nil))
    }

    private func at(_ time: String) throws -> Date {
        try #require(iso8601.date(from: "2025-02-08T\(time)Z"))
    }

    @Test func legsAndTimes() throws {
        let state = try state()
        #expect(state.legs.map(\.line) == ["A", "12"])
        // Une minute de marche avant la première montée.
        #expect(state.departure == (try at("14:50:42")))
        #expect(state.arrival == (try at("15:35:42")))
    }

    @Test func phaseFollowsTheClock() throws {
        let state = try state()
        #expect(state.phase(at: try at("14:45:00")) == .waiting(leg: 0))
        #expect(state.phase(at: try at("15:00:00")) == .riding(leg: 0))
        #expect(state.phase(at: try at("15:15:00")) == .waiting(leg: 1))
        #expect(state.phase(at: try at("15:30:00")) == .riding(leg: 1))
        #expect(state.phase(at: try at("15:40:00")) == .arrived)
        #expect(state.target(of: .waiting(leg: 1)) == (try at("15:20:42")))
    }

    @Test func nextTransition() throws {
        let state = try state()
        #expect(state.nextTransition(after: try at("15:00:00")) == (try at("15:10:42")))
        #expect(state.nextTransition(after: try at("15:40:00")) == nil)
    }

    @Test func delayIsRead() throws {
        var trip = FullTripTest().Trip
        trip.legs[1].legBoardEstimatedTime = "2025-02-08T14:55:42Z"
        let state = try #require(TripActivityState(trip: trip, alert: "Retard"))
        #expect(state.legs[0].delay == 4)
        #expect(state.alert == "Retard")
    }

    /// L'état voyage dans chaque mise à jour, limitée à 4 Ko par ActivityKit.
    @Test func stateStaysSmall() throws {
        #expect(try JSONEncoder().encode(try state()).count < 2048)
    }
}

@Suite("Activité en direct : étapes et véhicule")
struct TripActivityStepTests {
    private func at(_ time: String) throws -> Date {
        try #require(iso8601.date(from: "2025-02-08T\(time)Z"))
    }

    private func state() throws -> TripActivityState {
        try #require(TripActivityState(trip: FullTripTest().Trip, alert: nil))
    }

    @Test func nextStepFollowsThePhase() throws {
        let state = try state()
        #expect(state.nextStep(after: .waiting(leg: 0)) == .ride(to: "Genève, Place des Eaux-Vives", minutes: 19))
        #expect(state.nextStep(after: .riding(leg: 0)) == .transfer(leg: 1, waitMinutes: 10))
        #expect(state.nextStep(after: .riding(leg: 1)) == .arrival(at: try at("15:35:42"), walkMinutes: 0))
        #expect(state.nextStep(after: .arrived) == nil)
    }

    /// Quatre arrêts avant la montée, puis jusqu'à la descente ; ceux d'après ne servent pas.
    @Test func callsAroundTheLeg() throws {
        let leg = FullTripTest().Trip.legs[1] // montée AAA, descente BBB
        let names = ["P1", "P2", "P3", "P4", "P5", "AAA", "M1", "BBB", "After"]
        // Les noms sont raccourcis : « Genève, P2 » devient « P2 ».
        let events = names.enumerated().map { index, name in
            LineEvent(stopPointName: "Genève, \(name)", plannedQuay: "", timetabledTime: "2025-02-08T14:\(40 + index):00Z",
                      estimatedTime: "", stopPlaceRef: name, sloid: name, previousCall: false, longitude: "", latitude: "")
        }
        let calls = TripActivityState.calls(from: events, for: leg)
        #expect(calls.map(\.name) == ["P2", "P3", "P4", "P5", "AAA", "M1", "BBB"])

        var legState = try state().legs[0]
        legState.calls = calls
        #expect(legState.vehicleStop(at: try at("14:30:00")) == nil)
        #expect(legState.vehicleStop(at: try at("14:44:30")) == "P5")
    }

    @Test func shortNames() {
        #expect(shortStopName("Genève, Bel-Air") == "Bel-Air")
        #expect(shortStopName("Carouge GE, Rondeau") == "Rondeau")
        #expect(shortStopName("Palexpo") == "Palexpo")
    }

    /// Avec les passages, l'état doit rester sous les 4 Ko d'ActivityKit.
    @Test func stateWithCallsStaysSmall() throws {
        var state = try state()
        // Trois étapes, chacune au plus de passages gardés, aux noms longs.
        let call = TripActivityState.Call(name: "Place des Eaux-Vives", time: Date())
        for index in state.legs.indices { state.legs[index].calls = Array(repeating: call, count: 16) }
        state.legs.append(state.legs[0])
        #expect(try JSONEncoder().encode(state).count < 4096)
    }
}

@Suite("Activité en direct : course suivie")
struct TripActivityJourneyTests {
    /// Une course de six arrêts, un passage toutes les deux minutes à partir de 14:00.
    private func journey(delayAt: Int? = nil) -> [LineEvent] {
        ["Bel-Air", "Molard", "Rive", "Terrassière", "Villereuse", "Grange-Canal"].enumerated().map { position, name in
            let timetabled = "2025-02-08T14:\(String(format: "%02d", position * 2)):00Z"
            let estimated = position >= (delayAt ?? .max)
                ? "2025-02-08T14:\(String(format: "%02d", position * 2 + 3)):00Z" : ""
            return LineEvent(stopPointName: "Genève, \(name)", plannedQuay: position == 2 ? "B" : "",
                             timetabledTime: timetabled, estimatedTime: estimated, stopPlaceRef: name, sloid: name,
                             previousCall: false, longitude: "", latitude: "")
        }
    }

    private func state(from board: String = "Rive", to alight: String = "Villereuse", delayAt: Int? = nil) -> TripActivityState? {
        TripActivityState(journey: journey(delayAt: delayAt), line: "12", operatorName: "Transports Publics Genevois",
                          transportType: "Tram", destination: "Carouge, Bachet", boardSloid: board, alightSloid: alight)
    }

    @Test func oneLegFromTheJourney() throws {
        let state = try #require(state())
        let leg = try #require(state.legs.first)
        #expect(state.legs.count == 1)
        #expect(leg.boardName == "Genève, Rive")
        #expect(leg.boardQuay == "B")
        #expect(leg.alightName == "Genève, Villereuse")
        #expect(state.departure == iso8601.date(from: "2025-02-08T14:04:00Z"))
        #expect(state.arrival == iso8601.date(from: "2025-02-08T14:08:00Z"))
        // Les passages vont de deux arrêts avant la montée (la course commence là) à la descente.
        #expect(leg.calls?.map(\.name) == ["Bel-Air", "Molard", "Rive", "Terrassière", "Villereuse"])
    }

    @Test func delayIsRead() throws {
        let state = try #require(state(delayAt: 2))
        #expect(state.legs.first?.delay == 3)
        #expect(state.arrivalDelay == 3)
        #expect(state.departure == iso8601.date(from: "2025-02-08T14:07:00Z"))
    }

    /// L'arrêt de descente doit venir après celui de montée sur la course.
    @Test func wrongOrderIsRefused() {
        #expect(state(from: "Villereuse", to: "Rive") == nil)
        #expect(state(from: "Rive", to: "Inconnu") == nil)
    }
}

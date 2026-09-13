//
//  ParserTests.swift
//  tpgNextFuncTests
//
//  Les parseurs OJP, sur des réponses réelles de l'API enregistrées dans Fixtures/.
//

import Foundation
import CoreLocation
import Testing
@testable import tpgNextFunc

private struct StopEventsSnapshot: Encodable {
    let events: [StopEvent]
    let quays: [Quay]
}

private struct JourneySnapshot: Encodable {
    let events: [LineEvent]
    let operatorName: String
}

@Suite("Départs (OJP 1.0)")
struct StopEventParserTests {
    @Test func departuresAreComplete() async throws {
        let result = await parseStopEventsResult(try Fixture.data("stopEvents-rive"), stopCode: "ch:1:sloid:87061")
        #expect(result.error == nil)
        #expect(!result.events.isEmpty)
        #expect(!result.quays.isEmpty)
        for event in result.events {
            #expect(!event.journeyRef.isEmpty)
            #expect(!event.operatingDayRef.isEmpty)
            #expect(!event.lineName.isEmpty)
            #expect(!event.destination.isEmpty)
            #expect(iso8601.date(from: event.timetabledTime) != nil)
            #expect(iso8601.date(from: event.estimatedTime) != nil)
        }
    }

    @Test func unknownStopReportsTheAPIError() async throws {
        let result = await parseStopEventsResult(try Fixture.data("stopEvents-error"), stopCode: "ch:1:sloid:999999999")
        #expect(result.events.isEmpty)
        guard case .noEventFound(let message)? = result.error else {
            Issue.record("Erreur attendue, reçu \(String(describing: result.error))")
            return
        }
        #expect(message == "STOPEVENT_NOEVENTFOUND")
    }

    @Test func outputIsUnchanged() async throws {
        let result = await parseStopEventsResult(try Fixture.data("stopEvents-rive"), stopCode: "ch:1:sloid:87061")
        try Fixture.assertSnapshot(StopEventsSnapshot(events: result.events, quays: result.quays), named: "stopEvents-rive")
    }
}

@Suite("Itinéraires (OJP 1.0)")
struct TripParserTests {
    static let cases: [(fixture: String, geoDeparture: Bool)] = [
        ("trip-rive-cornavin", false),
        ("trip-geo-cornavin", true),
    ]

    private func parse(_ fixture: String, geoDeparture: Bool) throws -> [TripEvent] {
        try parseTripEvents(from: Fixture.data(fixture),
                            startCoordinate: Coordinates(lon: 6.1418, lat: 46.1985),
                            endCoordinates: Coordinates(lon: 6.1424, lat: 46.2102),
                            startName: geoDeparture ? "Ma position" : "Genève, Rive",
                            endName: "Genève, gare Cornavin",
                            startCode: geoDeparture ? nil : "ch:1:sloid:87061",
                            endCode: "ch:1:sloid:87057",
                            geoDeparture: geoDeparture,
                            geoArrival: false)
    }

    @Test(arguments: cases)
    func tripsAreComplete(_ testCase: (fixture: String, geoDeparture: Bool)) throws {
        let trips = try parse(testCase.fixture, geoDeparture: testCase.geoDeparture)
        #expect(!trips.isEmpty)
        for trip in trips {
            #expect(!trip.id.isEmpty)
            #expect(!trip.legs.isEmpty)
            #expect(durationMinutes(trip.duration) != nil)
            #expect(iso8601.date(from: trip.startTime) != nil)
            #expect(iso8601.date(from: trip.endTime) != nil)
        }
    }

    @Test(arguments: cases)
    func outputIsUnchanged(_ testCase: (fixture: String, geoDeparture: Bool)) throws {
        try Fixture.assertSnapshot(try parse(testCase.fixture, geoDeparture: testCase.geoDeparture), named: testCase.fixture)
    }
}

@Suite("Course (OJP 2.0)")
struct JourneyParserTests {
    @Test func callsAreComplete() throws {
        let result = parseJourneyEventsSync(from: try Fixture.data("tripInfo"))
        #expect(result.events.count > 2)
        #expect(result.operatorName == "Transports Publics Genevois")
        for event in result.events {
            #expect(!event.stopPointName.isEmpty)
            #expect(event.sloid.hasPrefix("ch:1:sloid:"))
            #expect(!isQuaySloid(event.sloid))
            #expect(Double(event.latitude) != nil)
            #expect(Double(event.longitude) != nil)
            #expect(iso8601.date(from: event.timetabledTime) != nil)
        }
    }

    /// La course enregistrée est celle du premier départ de Rive : elle doit y passer à la même heure.
    @Test func journeyMatchesTheDepartureItCameFrom() async throws {
        let departures = await parseStopEventsResult(try Fixture.data("stopEvents-rive"), stopCode: "ch:1:sloid:87061")
        let departure = try #require(departures.events.first)
        let journey = parseJourneyEventsSync(from: try Fixture.data("tripInfo")).events
        #expect(journeyMatches(journey, stopRef: departure.stopId, timetabledTime: departure.timetabledTime))
        #expect(journeyMatches(journey, stopRef: "ch:1:sloid:87061", timetabledTime: departure.timetabledTime))
        #expect(!journeyMatches(journey, stopRef: "ch:1:sloid:1", timetabledTime: departure.timetabledTime))
    }

    @Test func trackIsSplitAtEveryStop() throws {
        let data = try Fixture.data("tripInfo")
        let track = parseJourneyTrack(from: data)
        #expect(track.count > 10)
        let stops = parseJourneyEventsSync(from: data).events.map {
            CLLocationCoordinate2D(latitude: Double($0.latitude) ?? 0, longitude: Double($0.longitude) ?? 0)
        }
        let segments = try #require(splitTrack(track, atStops: stops))
        #expect(segments.count == stops.count - 1)
    }

    @Test func outputIsUnchanged() throws {
        let result = parseJourneyEventsSync(from: try Fixture.data("tripInfo"))
        try Fixture.assertSnapshot(JourneySnapshot(events: result.events, operatorName: result.operatorName), named: "tripInfo")
    }
}

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

    /// OJP ne donne pas de `Duration` aux bus et trams : leur place sur la frise vient de leurs heures.
    @Test(arguments: cases)
    func legsArePlacedInTime(_ testCase: (fixture: String, geoDeparture: Bool)) throws {
        let trips = try parse(testCase.fixture, geoDeparture: testCase.geoDeparture)
        for trip in trips {
            let spans = trip.legSpans
            #expect(spans.count == trip.legs.count)
            var previousEnd = 0.0
            for span in spans {
                #expect(span.range.lowerBound >= 0 && span.range.upperBound <= 1)
                // Au plus quelques secondes de recouvrement, jamais d'étape en arrière.
                #expect(span.range.lowerBound >= previousEnd - 0.05)
                previousEnd = span.range.upperBound
                if !span.leg.publishedLineName.isEmpty {
                    #expect(span.leg.legDuration.isEmpty)
                    #expect((span.leg.duration ?? 0) > 0)
                    #expect(span.range.upperBound > span.range.lowerBound)
                    #expect(span.walk == nil)
                } else if let walk = span.walk {
                    #expect(span.range.lowerBound == walk.lowerBound && walk.upperBound <= span.range.upperBound)
                }
            }
            #expect(abs(previousEnd - 1) < 0.05)
        }
    }

    /// Les pointillés prennent la part marchée de la correspondance, le reste est de l'attente.
    @Test func walkTakesItsShareOfTheChange() throws {
        let trip = FullTripTest().Trip // 45 minutes, correspondance de 15:10:42 à 15:20:42
        let change = try #require(trip.legSpans.first { $0.leg.id == "B" })
        let walk = try #require(change.walk)
        let walkMinutes = try #require(change.leg.walkDuration) / 60
        #expect(walkMinutes < 10)
        #expect(abs((change.range.upperBound - change.range.lowerBound) - 10.0 / 45) < 0.001)
        #expect(abs((walk.upperBound - walk.lowerBound) - walkMinutes / 45) < 0.001)
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

    /// La réponse enregistrée répète Bois-Caran (Order 1 et 2) : une seule ligne doit en rester,
    /// sinon la liste de la course affiche un vide à sa place.
    @Test func eventIdsAreUnique() throws {
        let ids = parseJourneyEventsSync(from: try Fixture.data("tripInfo")).events.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.filter { $0 == "ch:1:sloid:927252026-09-13T15:37:00Z" }.count == 1)
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

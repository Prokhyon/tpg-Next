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

@Suite("Départs (OJP 2.0)")
struct StopEventParserTests {
    @Test func departuresAreComplete() async throws {
        let result = await parseStopEventsResult(try Fixture.data("stopEvents-rive"), stopCode: "ch:1:sloid:87061")
        #expect(result.error == nil)
        #expect(!result.events.isEmpty)
        #expect(!result.quays.isEmpty)
        for event in result.events {
            #expect(!event.stopPointName.isEmpty)
            #expect(!event.plannedQuay.isEmpty)
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

    /// La réponse enregistrée (Rive, 17.09.2026) contient un 8 → Palexpo supprimé.
    @Test func cancelledDepartureIsFlagged() async throws {
        let result = await parseStopEventsResult(try Fixture.data("stopEvents-rive"), stopCode: "ch:1:sloid:87061")
        let cancelled = result.events.filter(\.cancelled)
        #expect(cancelled.count == 1)
        #expect(cancelled.first?.lineName == "8")
        #expect(cancelled.first?.destination == "Palexpo")
        #expect(result.events.count - cancelled.count > 20)
    }

    @Test func serviceDetailsAreRead() async throws {
        let result = await parseStopEventsResult(try Fixture.data("stopEvents-rive"), stopCode: "ch:1:sloid:87061")
        #expect(result.events.allSatisfy { $0.operatorName == "Transports Publics Genevois" })
        #expect(Set(result.events.map(\.transportType)).isSubset(of: ["Bus", "Tram"]))
        #expect(result.events.allSatisfy { $0.ptMode == "bus" || $0.ptMode == "tram" })
        #expect(result.events.allSatisfy { $0.quayAccess != nil })
        #expect(result.events.contains { $0.hasLowFloor })
    }

    @Test func onlyQuaysOfTheStopAreKept() async throws {
        let result = await parseStopEventsResult(try Fixture.data("stopEvents-rive"), stopCode: "ch:1:sloid:87061")
        #expect(result.quays.allSatisfy { $0.id.hasPrefix("ch:1:sloid:87061:") })
        #expect(result.quays.allSatisfy { !$0.quayName.isEmpty && Double($0.latitude) != nil })
    }

    /// Meinier, église (19.09.2026) : incident sur la ligne A. Vers Gy, le bus saute l'arrêt ;
    /// vers Rive, il le dessert et saute d'autres arrêts. Les deux portent l'attribut « Ausfall ».
    @Test func incidentOnlyCancelsTheStopsItSkips() async throws {
        let result = await parseStopEventsResult(try Fixture.data("stopEvents-meinier-incident"), stopCode: "ch:1:sloid:93001")
        let skipped = try #require(result.events.first { $0.lineName == "A" && $0.timetabledTime == "2026-09-19T13:15:00Z" })
        #expect(skipped.cancelled)
        #expect(!skipped.routeChanged)
        let served = try #require(result.events.first { $0.lineName == "A" && $0.timetabledTime == "2026-09-19T13:30:00Z" })
        #expect(!served.cancelled)
        #expect(served.routeChanged)
        #expect(result.events.filter(\.cancelled).count == 2)
        #expect(result.events.filter(\.routeChanged).count == 1)
    }

    /// Vésenaz, Capite (19.09.2026) : le G, dévié par Cologny, suit un horaire d'un seul jour.
    /// Rien d'autre ne le distingue : ni incident, ni arrêt sauté.
    @Test func oneDayTimetableIsExceptional() async throws {
        let result = await parseStopEventsResult(try Fixture.data("stopEvents-capite-exceptional"), stopCode: "ch:1:sloid:87069")
        let exceptional = result.events.filter(\.exceptional)
        #expect(exceptional.count == 8)
        // Hors de `#expect` : une closure composée dans la macro rendait la compilation très lente.
        let onlyLineG = exceptional.allSatisfy { (event: StopEvent) -> Bool in
            event.lineName == "G" && !event.routeChanged && !event.cancelled
        }
        let othersAreRegular = result.events.allSatisfy { (event: StopEvent) -> Bool in
            event.lineName == "G" || !event.exceptional
        }
        #expect(onlyLineG)
        #expect(othersAreRegular)
    }

    /// Un départ enregistré avant OJP 2.0 (dans un rappel) se décode toujours.
    @Test func departureSavedBeforeOJP2StillDecodes() throws {
        let json = #"{"stopPointName":"Genève, Rive","stopId":"ch:1:sloid:87061","plannedQuay":"A","timetabledTime":"2026-09-17T09:18:00Z","estimatedTime":"","lineName":"8","origin":"","destination":"Palexpo","transportType":"Bus","operatorName":"Transports Publics Genevois","journeyRef":"x","operatingDayRef":"2026-09-17"}"#
        let event = try JSONDecoder().decode(StopEvent.self, from: Data(json.utf8))
        #expect(!event.cancelled)
        #expect(event.quayAccess == nil)
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

    /// Rive → Meinier, église (19.09.2026, incident sur la ligne A) : le calculateur passe par
    /// Route de Corsinge, car le A saute seize arrêts, dont Meinier, église.
    /// Avully → Laconnex (02.10.2026) : tpg flex, bus à la demande. OJP le donne comme un bus
    /// ordinaire, avec une heure toutes les 5 minutes ; seuls le sous-mode et l'attribut `RR`
    /// disent qu'il n'a pas d'horaire et qu'il faut le réserver.
    @Test func onDemandBusIsRecognized() throws {
        let trips = try parseTripEvents(from: Fixture.data("trip-avully-laconnex-flex"),
                                        startCoordinate: Coordinates(lon: 6.0039, lat: 46.1697),
                                        endCoordinates: Coordinates(lon: 6.0335, lat: 46.1570),
                                        startName: "Avully", endName: "Laconnex",
                                        startCode: nil, endCode: nil,
                                        geoDeparture: true, geoArrival: true)
        let trip = try #require(trips.first)
        let leg = try #require(trip.legs.first { !$0.publishedLineName.isEmpty })
        #expect(leg.publishedLineName == "tpg flex")
        #expect(leg.busSubmode == "demandAndResponseBus")
        #expect(leg.requiresReservation)
        #expect(leg.isOnDemand)
        #expect(trip.hasOnDemandLeg)
    }

    /// Un itinéraire enregistré avant la lecture du sous-mode : la réservation suffit.
    @Test func savedOnDemandLegWithoutSubmode() throws {
        var leg = FullTripTest().Trip.legs[1]
        #expect(!leg.isOnDemand)
        leg.attributeCodes = ["RR"]
        #expect(leg.isOnDemand)
        leg.busSubmode = "localBus"
        #expect(!leg.isOnDemand)
    }

    @Test func skippedIntermediatesAreFlagged() throws {
        let trips = try parseTripEvents(from: Fixture.data("trip-rive-meinier-incident"),
                                        startCoordinate: Coordinates(lon: 6.1508, lat: 46.2025),
                                        endCoordinates: Coordinates(lon: 6.2338, lat: 46.2465),
                                        startName: "Genève, Rive", endName: "Meinier, église",
                                        startCode: "ch:1:sloid:87061", endCode: "ch:1:sloid:93001",
                                        geoDeparture: false, geoArrival: false)
        let legs = trips.flatMap(\.legs).filter { !$0.publishedLineName.isEmpty }
        let detour = try #require(legs.first { $0.publishedLineName == "A" && !$0.skippedIntermediates.isEmpty })
        #expect(detour.hasIncident)
        #expect(detour.skippedIntermediates.count == 16)
        #expect(detour.skippedIntermediates.first?.stopName == "Cologny, croisée")
        #expect(detour.skippedIntermediates.last?.stopName == "Meinier, église")
        let unaffected = try #require(legs.first { $0.publishedLineName == "39" })
        #expect(!unaffected.hasIncident)
        #expect(unaffected.skippedIntermediates.isEmpty)
    }

    /// Un itinéraire enregistré avant la lecture des arrêts sautés se décode toujours.
    @Test func tripSavedBeforeSkippedStopsStillDecodes() throws {
        let json = #"{"id":"1","stopId":"ch:1:sloid:87061","stopName":"Genève, Rive","longitude":"6.15","latitude":"46.20"}"#
        let stop = try JSONDecoder().decode(LegIntermediate.self, from: Data(json.utf8))
        #expect(!stop.skipped)
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

    /// `tripInfo-rive` est la course du premier départ de `stopEvents-rive` : elle doit y passer à la même heure.
    @Test func journeyMatchesTheDepartureItCameFrom() async throws {
        let departures = await parseStopEventsResult(try Fixture.data("stopEvents-rive"), stopCode: "ch:1:sloid:87061")
        let departure = try #require(departures.events.first)
        let journey = parseJourneyEventsSync(from: try Fixture.data("tripInfo-rive")).events
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

@Suite("Véhicule et position d'une course")
struct JourneyServiceTests {
    @Test func serviceIsRead() throws {
        let service = parseJourneyServiceSync(from: try Fixture.data("tripInfo-rive"))
        #expect(service.ptMode == "bus")
        #expect(service.hasLowFloor)
        #expect(!service.trainNumber.isEmpty)
        #expect(!service.hasIncident)
    }

    /// Le A de 15h30 vers Rive (19.09.2026) : un incident, dix arrêts sautés, pas une suppression.
    @Test func partialIncidentKeepsTheServedStops() throws {
        let data = try Fixture.data("tripInfo-meinier-incident")
        #expect(parseJourneyServiceSync(from: data).hasIncident)
        let events = parseJourneyEventsSync(from: data).events
        let skipped = events.filter { $0.isCancelled == true }.map(\.stopPointName)
        #expect(skipped.first == "Choulex, Rouette")
        #expect(skipped.last == "Cologny, temple")
        #expect(skipped.count == 11)
        #expect(events.contains { $0.stopPointName == "Meinier, église" && $0.isCancelled != true })
    }

    /// Le A de 14h45 vers Gy (19.09.2026) saute seize arrêts d'affilée : un seul bloc dans la liste.
    @Test func consecutiveSkippedStopsAreGrouped() throws {
        let events = parseJourneyEventsSync(from: try Fixture.data("tripInfo-gy-incident")).events
        let rows = journeyRows(events)
        let blocks = rows.compactMap { row -> [LineEvent]? in
            if case .skipped(let stops) = row { return stops }
            return nil
        }
        #expect(blocks.count == 1)
        #expect(blocks.first?.count == 16)
        #expect(blocks.first?.first?.stopPointName == "Cologny, croisée")
        #expect(blocks.first?.last?.stopPointName == "Meinier, église")
        #expect(rows.count == events.count - 15)
        #expect(Set(rows.map(\.id)).count == rows.count)
    }

    @Test func aLoneSkippedStopStaysARow() {
        let events = [stop("2026-09-17T10:00:00Z", lat: 46.0, lon: 6.0),
                      stop("2026-09-17T10:02:00Z", lat: 46.1, lon: 6.0, skipped: true),
                      stop("2026-09-17T10:04:00Z", lat: 46.2, lon: 6.0)]
        #expect(journeyRows(events).count == 3)
    }

    /// Meinier, église est sauté : Route de Corsinge, à 250 m, est desservi six minutes plus tard.
    @Test func nearestServedStopIsSuggested() throws {
        let events = parseJourneyEventsSync(from: try Fixture.data("tripInfo-gy-incident")).events
        let before = try #require(iso8601.date(from: "2026-09-19T12:40:00Z"))
        let alternative = try #require(nearestServedStop(skipping: "ch:1:sloid:93001", in: events, now: before))
        #expect(alternative.stop.stopPointName == "Meinier, Route de Corsinge")
        #expect(alternative.distance > 200 && alternative.distance < 300)
        #expect(alternative.walkingMinutes <= 5)
        // Une fois le bus passé, plus rien à proposer.
        let after = try #require(iso8601.date(from: "2026-09-19T13:00:00Z"))
        #expect(nearestServedStop(skipping: "ch:1:sloid:93001", in: events, now: after) == nil)
        // Un arrêt desservi n'a pas besoin d'alternative.
        #expect(nearestServedStop(skipping: "ch:1:sloid:93006", in: events, now: before) == nil)
    }

    /// Entre Le-Fort et Route de Corsinge, le bus contourne les arrêts sautés : sa position
    /// ne doit pas suivre leurs heures prévues (12h30–12h45), antérieures à son passage réel.
    @Test func vehicleIgnoresSkippedStops() throws {
        let events = parseJourneyEventsSync(from: try Fixture.data("tripInfo-gy-incident")).events
        let leFort = try #require(events.first { $0.stopPointName == "Cologny, Le-Fort" })
        let corsinge = try #require(events.first { $0.stopPointName == "Meinier, Route de Corsinge" })
        let now = try #require(iso8601.date(from: "2026-09-19T12:44:00Z"))
        let position = try #require(estimatedVehiclePosition(events: events, segments: nil, at: now))
        let latitudes = [leFort.coordinate.latitude, corsinge.coordinate.latitude]
        let longitudes = [leFort.coordinate.longitude, corsinge.coordinate.longitude]
        #expect(position.latitude >= latitudes.min()! && position.latitude <= latitudes.max()!)
        #expect(position.longitude >= longitudes.min()! && position.longitude <= longitudes.max()!)
    }

    @Test func callsCarryQuayAccess() throws {
        let events = parseJourneyEventsSync(from: try Fixture.data("tripInfo-rive")).events
        #expect(events.contains { $0.quayAccess != nil })
    }

    private func stop(_ time: String, lat: Double, lon: Double, skipped: Bool = false) -> LineEvent {
        LineEvent(stopPointName: "", plannedQuay: "", timetabledTime: time, estimatedTime: "", stopPlaceRef: "", sloid: time,
                  previousCall: false, longitude: String(lon), latitude: String(lat), isCancelled: skipped ? true : nil)
    }

    @Test func vehicleIsInterpolatedBetweenStops() throws {
        let events = [stop("2026-09-17T10:00:00Z", lat: 46.0, lon: 6.0),
                      stop("2026-09-17T10:04:00Z", lat: 46.2, lon: 6.0)]
        let now = try #require(iso8601.date(from: "2026-09-17T10:01:00Z"))
        let position = try #require(estimatedVehiclePosition(events: events, segments: nil, at: now))
        #expect(abs(position.latitude - 46.05) < 0.001)
        #expect(estimatedVehiclePosition(events: events, segments: nil, at: iso8601.date(from: "2026-09-17T09:59:00Z")!) == nil)
        #expect(estimatedVehiclePosition(events: events, segments: nil, at: iso8601.date(from: "2026-09-17T10:05:00Z")!) == nil)
    }

    @Test func vehicleFollowsTheRoutedTrack() throws {
        let events = [stop("2026-09-17T10:00:00Z", lat: 46.0, lon: 6.0),
                      stop("2026-09-17T10:02:00Z", lat: 46.1, lon: 6.1)]
        // Détour : 11,1 km vers le nord, puis 7,7 km vers l'est. À mi-temps (9,4 km), le véhicule est
        // encore sur la branche nord ; en ligne droite, il serait à mi-chemin en longitude.
        let track = [[CLLocationCoordinate2D(latitude: 46.0, longitude: 6.0),
                      CLLocationCoordinate2D(latitude: 46.1, longitude: 6.0),
                      CLLocationCoordinate2D(latitude: 46.1, longitude: 6.1)]]
        let now = try #require(iso8601.date(from: "2026-09-17T10:01:00Z"))
        let position = try #require(estimatedVehiclePosition(events: events, segments: track, at: now))
        #expect(abs(position.longitude - 6.0) < 0.0001)
        #expect(position.latitude > 46.08 && position.latitude < 46.09)
    }
}

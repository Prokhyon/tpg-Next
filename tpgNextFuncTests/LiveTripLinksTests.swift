//
//  LiveTripLinksTests.swift
//  tpgNextFuncTests
//

import Foundation
import CoreLocation
import Testing
@testable import tpgNextFunc

@Suite("Page du trajet suivi")
struct LiveTripLinksTests {
    /// Rive → Cornavin, le 12 puis le 19, avec une correspondance (13.09.2026).
    private func tripWithTransfer() throws -> TripEvent {
        let trips = try parseTripEvents(from: Fixture.data("trip-rive-cornavin"),
                                        startCoordinate: Coordinates(lon: 6.1418, lat: 46.1985),
                                        endCoordinates: Coordinates(lon: 6.1424, lat: 46.2102),
                                        startName: "Genève, Rive", endName: "Genève, gare Cornavin",
                                        startCode: "ch:1:sloid:87061", endCode: "ch:1:sloid:87057",
                                        geoDeparture: false, geoArrival: false)
        return try #require(trips.first { $0.vehicleLegs.map(\.publishedLineName) == ["12", "19"] })
    }

    private func at(_ minutes: Double) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + minutes * 60)
    }

    /// Un lien par étape de l'activité, dans le même ordre : la course, ses deux arrêts et leurs heures.
    @Test func eachVehicleOpensItsLineAndStops() throws {
        let trip = try tripWithTransfer()
        let links = LiveTripLinks(trip: trip)
        let state = try #require(TripActivityState(trip: trip, alert: nil))
        #expect(links.legs.count == state.legs.count)
        #expect(links.legs.map(\.line.lineName) == ["12", "19"])
        for (link, leg) in zip(links.legs, trip.trackedLegs) {
            #expect(link.line.journeyRef == leg.journeyRef)
            #expect(link.board.sloid == sloidHarmonizer(code: leg.legBoardStopId))
            #expect(link.alight.sloid == sloidHarmonizer(code: leg.legAlightStopId))
            #expect(link.boardTime == leg.legBoardTimetableTime)
            #expect(link.alightTime == leg.legAlightTimetableTime)
            #expect(link.boardCoordinates != nil && link.alightCoordinates != nil)
        }
        #expect(links.origin?.sloid == "ch:1:sloid:87061")
        #expect(links.destination?.sloid == "ch:1:sloid:87057")
    }

    /// Un lieu (adresse, position) n'a pas de page : seulement ses coordonnées.
    @Test func aPlaceHasNoStopPage() throws {
        var trip = try tripWithTransfer()
        trip.geoDeparture = true
        let links = LiveTripLinks(trip: trip)
        #expect(links.origin == nil)
        #expect(links.originCoordinates == trip.startCoordinates)
    }

    /// Une course suivie seule : son heure n'est connue qu'à l'arrêt d'où elle a été ouverte.
    @Test func aFollowedJourneyKnowsItsTimeWhereItWasOpened() {
        let event = StopEvent(stopPointName: "Genève, Rive", stopId: "ch:1:sloid:87061:0:1", plannedQuay: "B",
                              timetabledTime: "2026-09-13T16:00:00Z", estimatedTime: "", lineName: "12",
                              origin: "", destination: "Carouge, Bachet", transportType: "Tram",
                              operatorName: "tpg", journeyRef: "ref-12", operatingDayRef: "2026-09-13")
        let rive = ShortStop(name: "Genève, Rive", sloid: "ch:1:sloid:87061")
        let bachet = ShortStop(name: "Carouge, Bachet", sloid: "ch:1:sloid:87439")
        let points = [TripRoute.Point(latitude: 46.20, longitude: 6.15, time: at(0)),
                      TripRoute.Point(latitude: 46.17, longitude: 6.13, time: at(12))]
        let opened = LiveTripLinks(journey: event, board: rive, alight: bachet, points: points)
        #expect(opened.legs[0].boardTime == "2026-09-13T16:00:00Z")
        #expect(opened.legs[0].boardCoordinates == Coordinates(lon: 6.15, lat: 46.20))
        #expect(opened.legs[0].alightCoordinates == Coordinates(lon: 6.13, lat: 46.17))
        #expect(opened.destination == bachet)

        let elsewhere = LiveTripLinks(journey: event, board: bachet, alight: rive, points: [])
        #expect(elsewhere.legs[0].boardTime.isEmpty)
        #expect(elsewhere.legs[0].boardCoordinates == nil)
    }

    /// Le véhicule est placé d'après ses heures de passage, entre deux arrêts.
    @Test func theVehicleIsPlacedByItsTimes() throws {
        let points = [TripRoute.Point(latitude: 46.0, longitude: 6.0, time: at(0)),
                      TripRoute.Point(latitude: 46.2, longitude: 6.0, time: at(10)),
                      TripRoute.Point(latitude: 46.2, longitude: 6.4, time: at(20))]
        let before = try #require(TripRoute.expectedPosition(on: points, at: at(-5)))
        #expect(before.latitude == 46.0)
        let halfway = try #require(TripRoute.expectedPosition(on: points, at: at(5)))
        #expect(abs(halfway.latitude - 46.1) < 1e-9 && halfway.longitude == 6.0)
        let second = try #require(TripRoute.expectedPosition(on: points, at: at(15)))
        #expect(second.latitude == 46.2 && abs(second.longitude - 6.2) < 1e-9)
        let after = try #require(TripRoute.expectedPosition(on: points, at: at(30)))
        #expect(after.longitude == 6.4)
        #expect(TripRoute.expectedPosition(on: [], at: at(0)) == nil)
    }

    /// Le tracé se coupe là où est le véhicule : les deux moitiés se touchent.
    @Test func theTrackIsSplitWhereTheVehicleIs() {
        let track = [CLLocationCoordinate2D(latitude: 46.20, longitude: 6.10),
                     CLLocationCoordinate2D(latitude: 46.20, longitude: 6.12),
                     CLLocationCoordinate2D(latitude: 46.22, longitude: 6.12)]
        // Un peu à côté du second tronçon, aux trois quarts.
        let (done, remaining) = TripRoute.split(track, at: CLLocationCoordinate2D(latitude: 46.215, longitude: 6.1201))
        #expect(done.count == 3)
        #expect(remaining.count == 2)
        #expect(done.last?.latitude == remaining.first?.latitude)
        #expect(abs((done.last?.latitude ?? 0) - 46.215) < 1e-9)
        #expect(abs((done.last?.longitude ?? 0) - 6.12) < 1e-9)
        #expect(remaining.last?.latitude == 46.22)

        // Avant le départ, rien n'est fait ; un tracé trop court reste entier.
        let start = TripRoute.split(track, at: CLLocationCoordinate2D(latitude: 46.19, longitude: 6.09))
        #expect(start.remaining.count == 3 && start.done.count == 2)
        #expect(TripRoute.split([track[0]], at: track[0]).done.isEmpty)
    }
}

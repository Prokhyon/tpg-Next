//
//  UtilityTests.swift
//  tpgNextFuncTests
//

import Foundation
import CoreLocation
import Testing
@testable import tpgNextFunc

@Suite("Durées ISO 8601")
struct DurationTests {
    @Test(arguments: [("PT20M", 20), ("PT1H5M", 65), ("PT2H", 120), ("P1DT2H", 1560), ("PT5M30S", 6), ("PT0M", 0)])
    func minutes(_ iso: String, _ expected: Int) {
        #expect(durationMinutes(iso) == expected)
    }

    @Test(arguments: ["", "20", "PT", "PTXM", "P2H"])
    func invalidDurations(_ iso: String) {
        #expect(durationMinutes(iso) == nil)
    }

    @Test func text() {
        #expect(durationText("PT20M") == "20'")
        #expect(durationText("PT1H5M") == "1h05")
        #expect(durationText("PT2H") == "2h00")
        #expect(durationText("") == "")
    }
}

@Suite("Chaînes")
struct StringTests {
    @Test func xmlEscaping() {
        #expect("Migros & Co <Rive> \"l'arrêt\"".xmlEscaped == "Migros &amp; Co &lt;Rive&gt; &quot;l&apos;arrêt&quot;")
        #expect("ch:1:sloid:87061".xmlEscaped == "ch:1:sloid:87061")
    }

    @Test func stopNameSplitting() {
        #expect(splitString("Genève, Rive", separator: ",") == ("Genève", "Rive"))
        #expect(splitString("Lausanne", separator: ",") == ("Lausanne", ""))
    }

    @Test func normalization() {
        #expect("Chêne-Bourg, Place Favre".normalized().lowercased() == "chenebourgplacefavre")
    }
}

@Suite("Sloids")
struct SloidTests {
    @Test func quaySloidIsReducedToItsStop() {
        #expect(sloidHarmonizer(code: "ch:1:sloid:87061:0:450545") == "ch:1:sloid:87061")
        #expect(sloidHarmonizer(code: "ch:1:sloid:87061") == "ch:1:sloid:87061")
        #expect(isQuaySloid("ch:1:sloid:87061:0:450545"))
        #expect(!isQuaySloid("ch:1:sloid:87061"))
    }

    @Test func favoriteKeepsTheStopSloid() {
        let stop = Stop(name: "Genève, Rive", sloid: "ch:1:sloid:87061:0:450545", codedidoc: "8587061", country: "CH",
                        canton: "GE", meansOfTransport: "BUS", wgs84Coordinates: Coordinates(lon: 6.152, lat: 46.203))
        let favorite = FavoriteStop(stop: stop)
        #expect(favorite.sloid == "ch:1:sloid:87061")
        #expect(favorite.fallbackStop.name == "Genève, Rive")
        #expect(favorite.fallbackStop.wgs84Coordinates == stop.wgs84Coordinates)
    }
}

@Suite("Jours d'exploitation")
struct OperatingDayTests {
    private func leg(boardingAt time: String, operatingDayRef: String? = nil) -> TripLeg {
        TripLeg(id: "1", legBoardStopName: "", legBoardStopId: "", legBoardQuay: "", legBoardTimetableTime: time,
                legBoardEstimatedTime: "", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "",
                legAlightStopId: "", legAlightQuay: "", legAlightTimetableTime: "", legAlightEstimatedTime: "",
                legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "", journeyRef: "",
                operatingDayRef: operatingDayRef, publishedLineName: "", legDuration: "", transferDuration: "",
                transferWalkDuration: "", transferBuffer: "", transportTypeName: "", legOperator: "")
    }

    @Test func candidatesAreTheDayThenTheNextThenThePrevious() {
        #expect(operatingDayCandidates(for: "2026-09-13") == ["2026-09-13", "2026-09-14", "2026-09-12"])
        #expect(operatingDayCandidates(for: "n/a") == ["n/a"])
    }

    @Test func knownOperatingDayWins() {
        #expect(leg(boardingAt: "2026-09-13T08:00:00Z", operatingDayRef: "2026-09-10").resolvedOperatingDayRef == "2026-09-10")
    }

    /// Avant 4 h (heure suisse), une course de nuit appartient au jour d'exploitation de la veille.
    @Test(arguments: [
        ("2026-09-13T08:00:00Z", "2026-09-13"), // 10 h 00
        ("2026-09-13T01:30:00Z", "2026-09-12"), // 3 h 30
        ("2026-09-12T22:30:00Z", "2026-09-12"), // 0 h 30 le 13
        ("2026-09-13T02:30:00Z", "2026-09-13"), // 4 h 30
    ])
    func dayIsEstimatedFromTheSwissTime(_ time: String, _ expected: String) {
        #expect(leg(boardingAt: time).resolvedOperatingDayRef == expected)
    }
}

@Suite("Affichage des départs")
struct DepartureDisplayTests {
    private let now = iso8601.date(from: "2026-09-13T10:00:00Z")!

    private func localTime(_ iso: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = .current
        return formatter.string(from: iso8601.date(from: iso)!)
    }

    private func display(_ timetabled: String, _ estimated: String = "", showTime: Bool = false) -> String {
        departureDisplay(timetabled: timetabled, estimated: estimated, showTime: showTime, at: now).text
    }

    @Test func countdown() {
        #expect(display("2026-09-13T10:05:00Z") == "5'")
        #expect(display("2026-09-13T10:05:00Z", "2026-09-13T10:07:00Z") == "7'")
        #expect(display("2026-09-13T10:00:40Z") == "< 1'")
        #expect(display("2026-09-13T10:00:20Z") == "0")
    }

    @Test func farOrPastDeparturesShowTheTime() {
        #expect(display("2026-09-13T11:30:00Z") == localTime("2026-09-13T11:30:00Z"))
        #expect(display("2026-09-13T09:50:00Z") == localTime("2026-09-13T09:50:00Z"))
    }

    @Test func timeModeShowsTheDelay() {
        #expect(display("2026-09-13T10:05:00Z", showTime: true) == localTime("2026-09-13T10:05:00Z"))
        if !SharedStorage.bool(forSetting: SettingKey.delayIncludedInTime) {
            #expect(display("2026-09-13T10:05:00Z", "2026-09-13T10:08:00Z", showTime: true) == "\(localTime("2026-09-13T10:05:00Z"));(+3')")
        }
    }

    @Test func cases() {
        #expect(departureDisplay(timetabled: "2026-09-13T10:05:00Z", estimated: "2026-09-13T10:07:00Z", showTime: false, at: now) == .minutes(7, delayed: true))
        #expect(departureDisplay(timetabled: "2026-09-13T10:00:20Z", estimated: "", showTime: false, at: now) == .atStop)
        #expect(departureDisplay(timetabled: "n/a", estimated: "", showTime: false, at: now) == .unknown)
        #expect(DepartureDisplay.plannedWithDelay(planned: "14:05", delay: "(+3')").isHighlighted)
        #expect(!DepartureDisplay.minutes(5, delayed: false).isHighlighted)
    }

    @Test(arguments: [("A", "a.square.fill"), ("3", "3.square.fill"), ("12", "12.square.fill"), ("", nil), ("A1", nil), ("É", nil), ("51", nil)])
    func quaySymbols(_ quay: String, _ expected: String?) {
        #expect(QuayIcon.symbolName(for: quay) == expected)
    }

    @Test func unreadableTimeGivesAnEmptyText() {
        #expect(display("n/a") == "")
    }
}

@Suite("Arrêt proche")
struct NearbyStopSelectorTests {
    private func stop(_ id: Int) -> Stop {
        Stop(name: "Arrêt \(id)", sloid: "ch:1:sloid:\(id)", codedidoc: "", country: "CH", canton: "GE",
             meansOfTransport: "BUS", wgs84Coordinates: Coordinates(lon: 6.15, lat: 46.2))
    }

    @Test func closestFavoriteComesFirst() {
        let candidates = [(stop: stop(1), distance: 40.0), (stop: stop(2), distance: 80.0), (stop: stop(3), distance: 120.0)]
        let result = NearbyStopSelector.prioritized(candidates, favoriteSloids: ["ch:1:sloid:3", "ch:1:sloid:2"])
        #expect(result.map(\.stop.sloid) == ["ch:1:sloid:2", "ch:1:sloid:1", "ch:1:sloid:3"])
    }

    @Test func stopWithinTwentyMetersWins() {
        let candidates = [(stop: stop(1), distance: 15.0), (stop: stop(2), distance: 80.0)]
        let result = NearbyStopSelector.prioritized(candidates, favoriteSloids: ["ch:1:sloid:2"])
        #expect(result.map(\.stop.sloid) == ["ch:1:sloid:1", "ch:1:sloid:2"])
    }

    @Test func quayFavoriteMatchesItsStop() {
        let candidates = [(stop: stop(1), distance: 40.0), (stop: stop(2), distance: 80.0)]
        let result = NearbyStopSelector.prioritized(candidates, favoriteSloids: [sloidHarmonizer(code: "ch:1:sloid:2:0:7")])
        #expect(result.first?.stop.sloid == "ch:1:sloid:2")
    }
}

@Suite("Index binaire des arrêts")
struct StopIndexTests {
    private let stops = [
        Stop(name: "Genève, Rive", sloid: "ch:1:sloid:87061", codedidoc: "", country: "CH", canton: "GE",
             meansOfTransport: "BUS|TRAM", wgs84Coordinates: Coordinates(lon: 6.1520, lat: 46.2030)),
        Stop(name: "Genève, gare Cornavin", sloid: "ch:1:sloid:87057", codedidoc: "", country: "CH", canton: "GE",
             meansOfTransport: "TRAIN", wgs84Coordinates: Coordinates(lon: 6.1424, lat: 46.2102)),
        Stop(name: "Lausanne", sloid: "ch:1:sloid:1120", codedidoc: "", country: "CH", canton: "VD",
             meansOfTransport: "TRAIN", wgs84Coordinates: Coordinates(lon: 6.6291, lat: 46.5168)),
    ]

    private func reader() throws -> StopIndexReader {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bin")
        try StopIndex.encode(stops).write(to: url)
        return try #require(StopIndexReader(url: url))
    }

    @Test func nearestStopsAreSortedByDistance() throws {
        let index = try reader()
        #expect(index.stopCount == 3)
        let nearby = index.nearest(to: CLLocationCoordinate2D(latitude: 46.2031, longitude: 6.1521), limit: 5, maxDistance: 2000)
        #expect(nearby.map(\.stop.sloid) == ["ch:1:sloid:87061", "ch:1:sloid:87057"])
        #expect(nearby[0].distance < 20)
        #expect(nearby[0].stop.meansOfTransport == "BUS|TRAM")
    }

    @Test func lookupsBySloidAndName() throws {
        let index = try reader()
        #expect(index.stop(sloid: "ch:1:sloid:87057:0:1234")?.name == "Genève, gare Cornavin")
        #expect(index.stop(sloid: "ch:1:sloid:4") == nil)
        #expect(index.search("cornavin").map(\.sloid) == ["ch:1:sloid:87057"])
        #expect(index.search("geneve").count == 2)
    }

    @Test func missingFileIsRejected() {
        #expect(StopIndexReader(url: FileManager.default.temporaryDirectory.appendingPathComponent("absent.bin")) == nil)
    }
}

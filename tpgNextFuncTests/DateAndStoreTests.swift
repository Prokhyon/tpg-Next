//
//  DateAndStoreTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Heures OJP")
struct OJPDateTests {
    private let reference = iso8601.date(from: "2026-09-13T15:56:00Z")!

    @Test func parsing() {
        #expect(OJPDate.date(from: "2026-09-13T15:56:00Z") == reference)
        #expect(OJPDate.date(from: "2026-09-13T15:56:00.000Z") == reference)
        #expect(OJPDate.date(from: "2026-09-13T17:56:00+02:00") == reference)
        #expect(OJPDate.date(from: "") == nil)
        #expect(OJPDate.date(from: "13/09/2026") == nil)
    }

    @Test func requestFormat() {
        #expect(OJPDate.string(from: reference) == "2026-09-13T15:56:00Z")
    }

    @Test func localClockTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = .current
        #expect(OJPDate.clockTime(from: reference) == formatter.string(from: reference))
    }

    /// Les secondes sont ignorées : un départ à 10:00:00 est « passé » à partir de 10:01.
    @Test func passedAtTheMinute() {
        let now = iso8601.date(from: "2026-09-13T10:00:30Z")!
        #expect(dateStringHasPassed(with: "2026-09-13T09:59:59Z", equalReturnsTrue: false, now: now))
        #expect(!dateStringHasPassed(with: "2026-09-13T10:00:00Z", equalReturnsTrue: false, now: now))
        #expect(dateStringHasPassed(with: "2026-09-13T10:00:59Z", equalReturnsTrue: true, now: now))
        #expect(!dateStringHasPassed(with: "2026-09-13T10:01:00Z", equalReturnsTrue: true, now: now))
        #expect(!dateStringHasPassed(with: "", equalReturnsTrue: true, now: now))
    }

    @Test func shortDate() {
        #expect(convertDateString("2026-09-13") == "13/9/26")
        #expect(convertDateString("n/a") == nil)
    }
}

@Suite("Base des arrêts")
struct StopStoreTests {
    private static let store = StopStore()

    @Test func stopsAreFoundBySloidOrQuay() async {
        await Self.store.waitUntilLoaded()
        #expect(Self.store.findStop(id: "ch:1:sloid:87061")?.name == "Genève, Rive")
        #expect(Self.store.findStop(id: "ch:1:sloid:87061:0:111210")?.name == "Genève, Rive")
        #expect(Self.store.findStop(id: "ch:1:sloid:87057")?.name == "Genève, gare Cornavin")
        #expect(Self.store.findStop(id: "ch:1:sloid:0") == nil)
    }

    @Test func activeStopsAreUnique() async {
        await Self.store.waitUntilLoaded()
        let sloids = Self.store.activeStops.map(\.sloid)
        #expect(sloids.count > 20_000)
        #expect(Set(sloids).count == sloids.count)
    }

    @Test func searchIgnoresAccentsSpacesAndHyphens() async {
        await Self.store.waitUntilLoaded()
        let names = Set(Self.store.search("geneve rive").map(\.name))
        #expect(names.contains("Genève, Rive"))
        #expect(Self.store.search("Plan-les-Ouates").map(\.name) == Self.store.search("planlesouates").map(\.name))
    }

    /// Des espaces seuls se normalisent en "" : la recherche rendait alors toute la base.
    @Test func blankQueryFindsNothing() async {
        await Self.store.waitUntilLoaded()
        #expect(Self.store.search("").isEmpty)
        #expect(Self.store.search("   ").isEmpty)
    }

    @Test func searchSortsByNameWithoutLocation() async {
        await Self.store.waitUntilLoaded()
        let names = Self.store.search("cornavin").map(\.name)
        #expect(!names.isEmpty)
        #expect(names == names.sorted())
    }
}

//
//  DepartureGroupingTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Regroupement des départs")
struct DepartureGroupingTests {
    @Test func linesAreSortedNumericallyThenByDestination() {
        let keys = ["12;Moillesulaz", "2;Genève-Plage", "A;Gy", "12;Carouge", "E;Veigy"]
        #expect(keys.sorted(by: lineGroupPrecedes) == ["2;Genève-Plage", "12;Carouge", "12;Moillesulaz", "A;Gy", "E;Veigy"])
    }

    @Test func everyDepartureLandsInItsGroup() async throws {
        let departures = await parseStopEventsResult(try Fixture.data("stopEvents-rive"), stopCode: "ch:1:sloid:87061").events
        let groups = departures.groupedByLineAndDestination()
        #expect(groups.values.map(\.count).reduce(0, +) == departures.count)
        for (key, events) in groups {
            #expect(events.allSatisfy { key == "\($0.lineName);\($0.destination)" })
        }
    }
}

@Suite("Requêtes OJP")
struct RequestTests {
    @Test func departuresRequestIsEscapedAndComplete() {
        let date = iso8601.date(from: "2026-09-13T15:56:00Z")!
        let xml = stopEventRequestXML(stopName: "Migros & Co", stopSloid: "ch:1:sloid:87061", count: 7, at: date)
        #expect(xml.contains("<Text>Migros &amp; Co</Text>"))
        #expect(xml.contains("<siri:StopPointRef>ch:1:sloid:87061</siri:StopPointRef>"))
        #expect(xml.contains("<NumberOfResults>7</NumberOfResults>"))
        #expect(xml.contains("<DepArrTime>2026-09-13T15:56:00Z</DepArrTime>"))
        #expect(xml.contains("<IncludeOnwardCalls>false</IncludeOnwardCalls>"))
    }
}

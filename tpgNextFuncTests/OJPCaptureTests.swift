//
//  OJPCaptureTests.swift
//  tpgNextFuncTests
//

#if DEBUG
import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Captures : réponses OJP relues à 9:41")
struct OJPCaptureTests {
    private let recorded = OJPDate.date(from: "2026-10-13T12:20:00Z")!

    @Test func everyTimeMovesBySameShift() {
        let text = """
        <TimetabledTime>2026-10-13T12:25:00Z</TimetabledTime>
        <EstimatedTime>2026-10-13T12:26:30.5Z</EstimatedTime>
        <siri:ResponseTimestamp>2026-10-13T14:20:00.879018+02:00</siri:ResponseTimestamp>
        """
        // Enregistré à 14:20 (heure suisse), relu le 2 novembre à 9:41 (heure d'hiver, UTC+1).
        let target = OJPDate.date(from: "2026-11-02T08:41:00Z")!
        let rebased = OJPCapture.rebase(text, from: recorded, to: target)
        #expect(rebased.contains("<TimetabledTime>2026-11-02T08:46:00Z</TimetabledTime>"))
        #expect(rebased.contains("<EstimatedTime>2026-11-02T08:47:30Z</EstimatedTime>"))
        #expect(rebased.contains("<siri:ResponseTimestamp>2026-11-02T08:41:00Z</siri:ResponseTimestamp>"))
    }

    @Test func operatingDayFollowsTheCalendarDay() {
        let text = "<OperatingDayRef>2026-10-13</OperatingDayRef>"
        let sameDay = OJPCapture.rebase(text, from: recorded, to: OJPDate.date(from: "2026-10-13T07:41:00Z")!)
        #expect(sameDay == text)
        let later = OJPCapture.rebase(text, from: recorded, to: OJPDate.date(from: "2026-11-02T08:41:00Z")!)
        #expect(later == "<OperatingDayRef>2026-11-02</OperatingDayRef>")
    }

    @Test func keyIgnoresWhatChangesBetweenCaptures() {
        let first = stopEventRequestXML(stopName: "Genève, Rive", stopSloid: "ch:1:sloid:87061", count: 30,
                                        at: OJPDate.date(from: "2026-10-13T12:20:00Z")!)
        let second = stopEventRequestXML(stopName: "Genève, Rive", stopSloid: "ch:1:sloid:87061", count: 30,
                                         at: OJPDate.date(from: "2026-11-02T08:41:00Z")!)
        let otherStop = stopEventRequestXML(stopName: "Genève, Bel-Air", stopSloid: "ch:1:sloid:87387", count: 30,
                                            at: OJPDate.date(from: "2026-10-13T12:20:00Z")!)
        #expect(OJPCapture.key(for: first) == OJPCapture.key(for: second))
        #expect(OJPCapture.key(for: first) != OJPCapture.key(for: otherStop))
    }
}
#endif

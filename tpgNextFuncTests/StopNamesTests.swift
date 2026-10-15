//
//  StopNamesTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Nom officiel des destinations")
struct StopNamesTests {
    private func event(destination: String, ref: String?) -> StopEvent {
        var event = StopEvent(stopPointName: "Genève, Rive", stopId: "ch:1:sloid:87061", plannedQuay: "A",
                              timetabledTime: "", estimatedTime: "", lineName: "12", origin: "",
                              destination: destination, transportType: "Tram", operatorName: "",
                              journeyRef: "j", operatingDayRef: "")
        event.destinationRef = ref
        return event
    }

    // Le résolveur est passé en paramètre : le global (`StopNames.resolve`) ne change pas, et les
    // tests de décodage qui tournent en parallèle n'en dépendent pas.
    private let names: (String) -> String? = { $0 == "ch:1:sloid:87400" ? "Thônex, Moillesulaz" : nil }

    @Test func theSameTerminusReadsTheSame() {
        // Le sloid de quai est ramené à l'arrêt, et les deux textes d'OJP donnent le même nom.
        let short = StopNames.withOfficialDestination(event(destination: "Moillesulaz", ref: "ch:1:sloid:87400:0:1"), resolve: names)
        let long = StopNames.withOfficialDestination(event(destination: "Genève, Moillesulaz", ref: "ch:1:sloid:87400"), resolve: names)
        #expect(short.destination == "Thônex, Moillesulaz")
        #expect(long.destination == short.destination)
    }

    @Test func unknownOrMissingKeepsTheOJPText() {
        #expect(StopNames.withOfficialDestination(event(destination: "Annemasse", ref: "ch:1:sloid:9"), resolve: names).destination == "Annemasse")
        #expect(StopNames.withOfficialDestination(event(destination: "Annemasse", ref: nil), resolve: names).destination == "Annemasse")
        #expect(StopNames.withOfficialDestination(event(destination: "Annemasse", ref: "ch:1:sloid:87400"), resolve: nil).destination == "Annemasse")
    }
}

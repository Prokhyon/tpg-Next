//
//  LineDirectoryTests.swift
//  tpgNextFuncTests
//

import Testing
@testable import tpgNextFunc

@Suite("Lignes du réseau")
struct LineDirectoryTests {
    @Test func linesAreBundled() throws {
        let lines = LineDirectory.lines(of: [LineDirectory.tpgID])
        #expect(lines.count > 50)
        let twelve = try #require(lines.first { $0.number == "12" })
        #expect(twelve.isTram)
        #expect(twelve.termini?.to.contains("Moillesulaz") == true)
        #expect(twelve.operatorColorName == "Transports Publics Genevois")
        // Dans l'ordre des numéros, pas de l'alphabet : 2 avant 10.
        let numbers = lines.map(\.number)
        #expect(try #require(numbers.firstIndex(of: "2")) < #require(numbers.firstIndex(of: "10")))
    }

    @Test func wholeSwitzerlandIsBundled() throws {
        #expect(LineDirectory.operators.count > 100)
        #expect(LineDirectory.lines.count > 1000)
        // Chaque ligne a son transporteur dans l'annuaire.
        #expect(LineDirectory.lines.allSatisfy { $0.transitOperator != nil })
        let sbb = try #require(LineDirectory.operators.first { $0.shortName == "CFF" })
        #expect(LineDirectory.lines(of: [sbb.id]).contains { $0.kind == .train })
    }

    @Test func ojpReferenceIsTheOrganisationNumber() {
        // Relevé à la main dans `OJPOperators` : le registre doit donner les mêmes.
        #expect(LineDirectory.operator(ojpRef: "ojp:881")?.id == LineDirectory.tpgID)
        #expect(LineDirectory.operator(ojpRef: "ojp:184")?.colorName == "CGN SA")
        #expect(LineDirectory.operator(ojpRef: "ojp:0") == nil)
    }

    @Test func kindsFollowTheOfferCategory() {
        func line(_ category: String) -> TransitLine {
            TransitLine(slnid: category, number: "1", category: category, description: "A - B", operator: "x")
        }
        #expect(line("T").kind == .tram)
        #expect(line("S").kind == .train)
        #expect(line("IR").kind == .train)
        #expect(line("BN").kind == .nightBus)
        #expect(line("BAT").kind == .boat)
        #expect(line("FUN").kind == .cableway)
        #expect(line("B").kind == .bus)
    }

    @Test func searchPutsTheExactNumberFirst() {
        let lines = [
            TransitLine(slnid: "a", number: "12", category: "T", description: "A - B", operator: "tpg"),
            TransitLine(slnid: "b", number: "1", category: "B", description: "C - D", operator: "tpg"),
            TransitLine(slnid: "c", number: "10", category: "B", description: "E - F", operator: "tpg"),
        ]
        #expect(LineDirectory.search("1", in: lines).map(\.number) == ["1", "12", "10"])
        #expect(LineDirectory.search("12", in: lines).map(\.number) == ["12"])
        // Un nom d'arrêt n'est pas un numéro de ligne.
        #expect(LineDirectory.search("Rive", in: lines).isEmpty)
        #expect(LineDirectory.search("", in: lines).isEmpty)
    }

    @Test func onDemandLineHasNoRoute() {
        let flex = TransitLine(slnid: "x", number: "301", category: "RUB",
                               description: "Zone Champagne (Aire-la-Ville, Avully)", operator: "tpg")
        #expect(flex.mainStops.isEmpty)
        #expect(flex.termini == nil)
    }
}

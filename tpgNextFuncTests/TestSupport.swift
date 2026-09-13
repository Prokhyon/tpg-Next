//
//  TestSupport.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

/// Les réponses OJP réelles enregistrées dans `Fixtures/`.
///
/// Elles sont lues depuis les sources plutôt que depuis le bundle de test, pour que
/// les instantanés puissent y être écrits à côté.
enum Fixture {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent(name + ".xml"))
    }

    /// Compare `value`, encodé en JSON stable, à l'instantané `<name>.expected.json`.
    ///
    /// Sert de garde-fou aux réécritures : le résultat d'un parseur doit rester identique
    /// octet pour octet. Si l'instantané manque, il est créé et le test échoue une fois,
    /// pour qu'il soit relu avant d'être commité.
    static func assertSnapshot<T: Encodable>(_ value: T, named name: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let json = String(decoding: try encoder.encode(value), as: UTF8.self)
        let url = directory.appendingPathComponent(name + ".expected.json")
        guard let expected = try? String(contentsOf: url, encoding: .utf8) else {
            try json.write(to: url, atomically: true, encoding: .utf8)
            Issue.record("Instantané créé : \(url.lastPathComponent). Relire puis relancer les tests.")
            return
        }
        #expect(json == expected, "Le résultat diffère de \(url.lastPathComponent)")
    }
}

/// `parseStopEvents` rend la main par un rappel sur le thread principal.
func parseStopEventsResult(_ data: Data, stopCode: String) async -> (events: [StopEvent], quays: [Quay], error: ParserError?) {
    await withCheckedContinuation { continuation in
        parseStopEvents(from: data, stopCode: stopCode) { events, quays, error in
            continuation.resume(returning: (events, quays, error))
        }
    }
}

let iso8601 = ISO8601DateFormatter()

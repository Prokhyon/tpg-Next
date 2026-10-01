//
//  OJPClientTests.swift
//  tpgNextFuncTests
//
//  Les échecs de l'API, rangés d'après ce que renvoie vraiment son gestionnaire (Tyk), et le
//  quota lu dans les en-têtes des réponses.
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Échecs et quota de l'API OJP")
struct OJPClientTests {
    private func classify(_ status: Int, _ body: String = "") -> String? {
        OJPClient.classify(status: status, body: Data(body.utf8))?.code
    }

    @Test func gatewayAnswersAreClassified() {
        #expect(classify(200, "<OJP/>") == nil)
        #expect(classify(200) == OJPClient.Failure.emptyResponse.code)
        #expect(classify(429, #"{"error": "API Rate limit exceeded"}"#) == OJPClient.Failure.rateLimited.code)
        // Le même 403 pour un quota épuisé et une clé refusée : seul le texte les distingue.
        #expect(classify(403, #"{"error": "Quota exceeded"}"#) == OJPClient.Failure.quotaExceeded.code)
        #expect(classify(403, #"{"error": "Access to this API has been disallowed"}"#)
                == OJPClient.Failure.keyRejected(status: 403).code)
        #expect(classify(401, #"{"error": "Authorization field missing"}"#)
                == OJPClient.Failure.keyRejected(status: 401).code)
        #expect(classify(400, "<html><body><h1>400 Bad Request</h1></body></html>")
                == OJPClient.Failure.badRequest(status: 400).code)
        #expect(classify(503) == OJPClient.Failure.server(status: 503).code)
    }

    @Test func keyFailuresTryAnotherKey() {
        #expect(OJPClient.Failure.rateLimited.isKeySpecific)
        #expect(OJPClient.Failure.quotaExceeded.isKeySpecific)
        #expect(OJPClient.Failure.keyRejected(status: 403).isKeySpecific)
        #expect(!OJPClient.Failure.server(status: 503).isKeySpecific)
        #expect(OJPClient.Failure.server(status: 503).isTransient)
        #expect(!OJPClient.Failure.server(status: 500).isTransient)
    }

    @Test func connectionErrorsAreTheDevicesFault() {
        #expect(OJPClient.classify(URLError(.notConnectedToInternet)).code == OJPClient.Failure.offline.code)
        #expect(OJPClient.classify(URLError(.timedOut)).code == OJPClient.Failure.timeout.code)
        #expect(OJPClient.classify(URLError(.cancelled)).isRecorded == false)
        #expect(OJPClient.classify(CancellationError()).isRecorded == false)
        #expect(OJPClient.classify(URLError(.networkConnectionLost)).isConnectivity)
        // Aucune alerte pour une coupure chez l'utilisateur.
        #expect(OJPClient.Failure.offline.alertKind == nil)
        #expect(OJPClient.Failure.quotaExceeded.alertKind == .quotaExceeded)
    }

    @Test func unreadableResponseIsNotAnEmptyList() {
        let html = Data("<html><body>502 Bad Gateway</body></html>".utf8)
        let result = parseStopEventsSync(from: html, stopCode: "ch:1:sloid:7000")
        guard case .xmlParsingFailed = result.error else {
            Issue.record("Une page HTML doit être signalée comme illisible")
            return
        }
        let truncated = Data(#"<?xml version="1.0"?><OJP><OJPResponse><siri:Service"#.utf8)
        #expect(throws: ParserError.self) {
            try parseTripEvents(from: truncated, startCoordinate: Coordinates(lon: 0, lat: 0),
                                endCoordinates: Coordinates(lon: 0, lat: 0), startName: "", endName: "",
                                startCode: nil, endCode: nil, geoDeparture: false, geoArrival: false)
        }
    }

    @Test func quotaHeadersAreRead() throws {
        // Une clé fictive (99) : l'état des vraies clés n'est pas touché.
        let response = try #require(HTTPURLResponse(
            url: URL(string: "https://api.opentransportdata.swiss/ojp20")!, statusCode: 200, httpVersion: nil,
            headerFields: ["X-Quota-Limit": "20000", "X-Quota-Remaining": "19489", "X-Quota-Reset": "1790939787",
                           "X-Ratelimit-Limit": "50", "X-Ratelimit-Remaining": "48"]))
        OJPUsage.shared.record(response: response, key: 99)
        let state = try #require(OJPUsage.shared.current.keys[99])
        #expect(state.quotaRemaining == 19_489)
        #expect(state.quotaUsed == 511)
        #expect(state.quotaReset == Date(timeIntervalSince1970: 1_790_939_787))
        #expect(state.rateRemaining == 48)
    }

    @Test func everyKeyIsTriedOnce() {
        let all = Set(1...OJPUsage.keyCount)
        #expect(OJPUsage.shared.pickKey(excluding: all) == nil)
        if OJPUsage.keyCount > 1, let picked = OJPUsage.shared.pickKey(excluding: [1]) {
            #expect(picked.number != 1)
        }
    }
}

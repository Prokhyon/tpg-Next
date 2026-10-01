//
//  Managers.swift
//  tpgNextFunc
//
//  Départs d'un arrêt et arrêts d'une course, partagés par l'app et la montre.
//  Chacune en avait sa copie, et les deux avaient divergé.
//

import Observation
import Foundation
import Combine
import CoreLocation

/// Les départs d'un arrêt.
@Observable
public final class StopManager {
    public private(set) var stopEvents: [StopEvent] = []
    public private(set) var stopError = false
    /// Le code d'erreur OJP, par exemple `STOPEVENT_LOCATIONUNSERVED`.
    public private(set) var stopErrorMessage = ""
    public private(set) var quays: [Quay] = []

    /// Numéro de la dernière requête : une réponse plus ancienne arrivée après elle
    /// (timer, changement d'heure, rafraîchissement) ne doit pas l'écraser.
    private var latestRequest = 0

    public init() {}

    /// `completion` est appelé sur le thread principal une fois `stopEvents` à jour, ou
    /// après un échec réseau. Une réponse dépassée par une requête plus récente est ignorée.
    public func selectStop(stopName: String, stopSloid: String, stopEventNumber: Int, timeRequest: Date, completion: @escaping () -> Void = {}) {
        stopError = false
        stopErrorMessage = ""
        latestRequest += 1
        let request = latestRequest

        fetchTransportDepartures(with: stopName, stopSloid: stopSloid, stopEventNumber: stopEventNumber, timeRequest: timeRequest) { data in
            guard request == self.latestRequest else { return }
            guard let data else {
                self.stopError = true
                completion()
                return
            }
            parseStopEvents(from: data, stopCode: stopSloid) { events, quays, error in
                guard request == self.latestRequest else { return }
                if let error {
                    self.stopError = true
                    if case .noEventFound(let message) = error {
                        self.stopErrorMessage = message
                        Log.network.info("Aucun départ : \(message)")
                    } else {
                        Log.network.error("Départs : réponse illisible")
                    }
                    return
                }
                // Le nom officiel de chaque destination (voir `StopNames`).
                self.stopEvents = events.map(StopNames.withOfficialDestination)
                self.quays = quays
                Log.network.debug("\(events.count) départs reçus")
                completion()
            }
        }
    }
}

/// Les arrêts d'une course, et au besoin son tracé.
@Observable
public final class LineManager {
    public private(set) var lineEvents: [LineEvent] = []
    public private(set) var operatorName = ""
    /// Tracé de la dernière requête faite avec `track: true` : `nil` si elle a échoué,
    /// vide si l'API n'a pas fourni de tracé pour cette course.
    public private(set) var track: [CLLocationCoordinate2D]?
    /// Le véhicule de la course (mode, plancher bas, suppression).
    public private(set) var service: JourneyService?

    /// Voir `StopManager.latestRequest`.
    private var latestRequest = 0

    public init() {}

    /// `completion` est appelé sur le thread principal.
    public func selectJourney(_ stopEvent: StopEvent, track: Bool = false, completion: @escaping () -> Void = {}) {
        latestRequest += 1
        let request = latestRequest
        if track {
            self.track = nil
        }
        fetchTransportJourney(with: stopEvent, track: track) { data in
            guard let data else {
                completion()
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let coordinates = track ? parseJourneyTrack(from: data) : nil
                let result = parseJourneyEventsSync(from: data)
                let service = parseJourneyServiceSync(from: data)
                DispatchQueue.main.async {
                    guard request == self.latestRequest else { return }
                    self.lineEvents = result.events
                    self.service = service
                    // OJP 2.0 ne nomme que certains opérateurs : on garde alors celui du départ.
                    self.operatorName = result.operatorName.isEmpty ? stopEvent.operatorName : result.operatorName
                    if let coordinates {
                        self.track = coordinates
                    }
                    completion()
                }
            }
        }
    }
}

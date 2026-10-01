//
//  LineFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 21.06.2024.
//

import Foundation
import CoreLocation
import SwiftUI
import Combine



public struct LineEvent: Codable, Identifiable, Hashable {
    
    public var stopPointName: String
    public var plannedQuay: String
    public var timetabledTime: String
    public var estimatedTime: String
    public var stopPlaceRef: String
    public var sloid: String
    public var previousCall: Bool
    public var longitude: String
    public var latitude: String
    /// Le véhicule ne s'arrête pas ici (OJP 2.0 `NotServicedStop`).
    public var isCancelled: Bool? = nil
    /// Accès au quai pour les personnes à mobilité réduite.
    public var quayAccess: QuayAccess? = nil

    public var id: String { sloid + timetabledTime }

    /// Public pour construire une course hors de l'API (aperçus de la montre). Mêmes paramètres
    /// que l'initialiseur par membres qu'il remplace.
    public init(stopPointName: String, plannedQuay: String, timetabledTime: String, estimatedTime: String, stopPlaceRef: String,
                sloid: String, previousCall: Bool, longitude: String, latitude: String, isCancelled: Bool? = nil, quayAccess: QuayAccess? = nil) {
        self.stopPointName = stopPointName
        self.plannedQuay = plannedQuay
        self.timetabledTime = timetabledTime
        self.estimatedTime = estimatedTime
        self.stopPlaceRef = stopPlaceRef
        self.sloid = sloid
        self.previousCall = previousCall
        self.longitude = longitude
        self.latitude = latitude
        self.isCancelled = isCancelled
        self.quayAccess = quayAccess
    }
}

/// Une rangée de la liste d'une course : un arrêt, ou plusieurs arrêts sautés d'affilée,
/// repliés en un bloc (un incident en saute souvent une quinzaine).
public enum JourneyRow: Identifiable, Hashable {
    case stop(LineEvent)
    case skipped([LineEvent])

    public var id: String {
        switch self {
        case .stop(let event): event.id
        case .skipped(let events): "skipped-" + (events.first?.id ?? "")
        }
    }
}

/// Les rangées de la liste d'une course. Un arrêt sauté seul reste une rangée d'arrêt.
public func journeyRows(_ events: [LineEvent]) -> [JourneyRow] {
    var rows: [JourneyRow] = []
    var run: [LineEvent] = []
    func flush() {
        if run.count == 1 {
            rows.append(.stop(run[0]))
        } else if !run.isEmpty {
            rows.append(.skipped(run))
        }
        run = []
    }
    for event in events {
        if event.isCancelled == true {
            run.append(event)
        } else {
            flush()
            rows.append(.stop(event))
        }
    }
    flush()
    return rows
}


/// Un arrêt desservi proche d'un arrêt que la course saute : où la prendre quand même.
public struct ServedAlternative: Hashable {
    public let stop: LineEvent
    /// Distance à vol d'oiseau depuis l'arrêt sauté, en mètres.
    public let distance: Double

    public init(stop: LineEvent, distance: Double) {
        self.stop = stop
        self.distance = distance
    }

    /// Temps de marche estimé : 80 m/min, et 30 % de plus que la ligne droite pour les rues.
    public var walkingMinutes: Int { max(1, Int((distance * 1.3 / 80).rounded())) }
}

/// Le plus proche des deux arrêts desservis qui encadrent l'arrêt sauté `sloid` sur la course
/// (le dernier avant, le premier après), s'il est à moins de `maxDistance` mètres et que le
/// véhicule n'y est pas encore passé. `nil` si l'arrêt est desservi ou absent de la course.
public func nearestServedStop(skipping sloid: String, in events: [LineEvent], maxDistance: Double = 1_500, now: Date = Date()) -> ServedAlternative? {
    guard let index = events.firstIndex(where: { $0.sloid == sloid }), events[index].isCancelled == true else { return nil }
    let origin = events[index].coordinate
    guard origin.latitude != 0 else { return nil }
    let from = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
    let candidates = [events[..<index].last { $0.isCancelled != true },
                      events[(index + 1)...].first { $0.isCancelled != true }]
    return candidates
        .compactMap { stop -> ServedAlternative? in
            guard let stop, stop.coordinate.latitude != 0,
                  !hasPassed(stop.departureDate, includingCurrentMinute: false, now: now) else { return nil }
            let distance = from.distance(from: CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude))
            return distance <= maxDistance ? ServedAlternative(stop: stop, distance: distance) : nil
        }
        .min { $0.distance < $1.distance }
}

/// Course complète d'un départ. Voir `fetchTransportJourney(journeyRef:operatingDayRef:...)`.
public func fetchTransportJourney(with stopEvent: StopEvent, calls: Bool = true, track: Bool = false, completion: @escaping (Data?) -> Void) {
    fetchTransportJourney(journeyRef: stopEvent.journeyRef, operatingDayRef: stopEvent.operatingDayRef, calls: calls, track: track, expectedStopRef: stopEvent.stopId, expectedTime: stopEvent.timetabledTime, completion: completion)
}

/// Course complète, par une OJPTripInfoRequest en OJP 2.0 (voir `JourneyParser.swift`).
///
/// L'API n'est pas cohérente sur le jour d'exploitation de certaines courses de nuit : quand un arrêt
/// et son heure sur la course sont connus, la course reçue est vérifiée et, si elle ne correspond pas,
/// on réessaie avec le lendemain puis la veille. En pratique, une seule requête suffit.
/// - Parameter track: ajoute le tracé géographique de la course (≈ +35 Ko), lu par `parseJourneyTrack`.
/// - Parameter expectedStopRef: un arrêt de la course (quai ou arrêt parent).
/// - Parameter expectedTime: l'heure théorique de la course à cet arrêt.
/// `completion` reçoit la réponse brute, `nil` en cas d'échec, sur le thread principal.
public func fetchTransportJourney(journeyRef: String, operatingDayRef: String, calls: Bool = true, track: Bool = false, expectedStopRef: String? = nil, expectedTime: String? = nil, completion: @escaping (Data?) -> Void) {
    let days = operatingDayCandidates(for: operatingDayRef)
    var fallback: Data?

    func finish(_ response: Data?) {
        DispatchQueue.main.async { completion(response) }
    }

    func attempt(_ index: Int) {
        guard index < days.count else {
            // Aucune course ne correspond : la première non vide vaut mieux que rien.
            finish(fallback)
            return
        }
        requestTripInfo(journeyRef: journeyRef, operatingDayRef: days[index], calls: calls, track: track) { response in
            guard let response else {
                // Erreur réseau : inutile d'essayer d'autres jours.
                finish(fallback)
                return
            }
            // Sans les arrêts, il n'y a rien à vérifier.
            guard calls else {
                finish(response)
                return
            }
            let events = parseJourneyEventsSync(from: response).events
            if journeyMatches(events, stopRef: expectedStopRef, timetabledTime: expectedTime) {
                finish(response)
                return
            }
            if fallback == nil && !events.isEmpty {
                fallback = response
            }
            Log.network.info("Course \(journeyRef) introuvable pour le jour \(days[index]), essai suivant")
            attempt(index + 1)
        }
    }

    attempt(0)
}

/// Une OJPTripInfoRequest en OJP 2.0. `completion` reçoit `nil` en cas d'échec, sur une file de fond.
private func requestTripInfo(journeyRef: String, operatingDayRef: String, calls: Bool, track: Bool, completion: @escaping (Data?) -> Void) {
    let requestTimestamp = OJPDate.string(from: Date())
    let xmlString = """
    <?xml version="1.0" encoding="utf-8"?>
    <OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
        <OJPRequest>
            <siri:ServiceRequest>
                <siri:RequestTimestamp>\(requestTimestamp)</siri:RequestTimestamp>
                <siri:RequestorRef>tpgNext</siri:RequestorRef>
                <OJPTripInfoRequest>
                    <siri:RequestTimestamp>\(requestTimestamp)</siri:RequestTimestamp>
                    <JourneyRef>\(journeyRef.xmlEscaped)</JourneyRef>
                    <OperatingDayRef>\(operatingDayRef.xmlEscaped)</OperatingDayRef>
                    <Params>
                        <IncludeCalls>\(calls ? "true" : "false")</IncludeCalls>
                        <IncludeService>\(calls ? "true" : "false")</IncludeService>
                        <IncludeTrackProjection>\(track ? "true" : "false")</IncludeTrackProjection>
                    </Params>
                </OJPTripInfoRequest>
            </siri:ServiceRequest>
        </OJPRequest>
    </OJP>
    """
    OJPClient.post(xmlString, to: .v2, completionQueue: .global(qos: .userInitiated)) { completion(try? $0.get()) }
}

public func parseJourneyEvents(from data: Data, completion: @escaping ([LineEvent], String) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let result = parseJourneyEventsSync(from: data)
        DispatchQueue.main.async {
            completion(result.events, result.operatorName)
        }
    }
}

public struct BusLineIcon: View {
    let lineName: String
    let operatorName: String
    
    var width: CGFloat = 35
    var height: CGFloat = 25
    /// Un anneau de la couleur de l'app autour du badge : la course d'où l'on vient (lien entre
    /// pages), à ne pas confondre avec la sélection, bordure orange de la rangée.
    var highlighted = false
    /// Plafond de hauteur et largeur minimale du badge : identiques à la taille de texte
    /// normale, ils grandissent avec elle (le numéro était écrasé à grande taille).
    @ScaledMetric private var maxHeight: CGFloat = 25
    @ScaledMetric private var minWidth: CGFloat = 35
    
    public init(lineName: String, operatorName: String, width: CGFloat = 35, height: CGFloat = 25,
                highlighted: Bool = false) {
        self.lineName = lineName
        self.operatorName = operatorName
        self.height = height
        self.width = width
        self.highlighted = highlighted
    }

    public var body: some View {
           ZStack {
               Text(lineName)
                   
                   .padding(.horizontal, 8)
                   .padding(.vertical, 4)
                   .frame(minWidth: width < minWidth ? width : minWidth, maxHeight: height < maxHeight ? height : maxHeight)
                   .background(
//                       RoundedRectangle(cornerRadius: 10)
                    Capsule()
                        .stroke(LineColors.lineColor(for: lineName, operatorName: operatorName), lineWidth: 4)
                   )
                   .background {
                       if highlighted {
                           // Hors du trait de la ligne (qui déborde de 2 points), comme l'anneau
                           // d'un arrêt sur la page d'une ligne.
                           Capsule()
                               .stroke(Color.accentColor, lineWidth: 3)
                               .padding(-4.5)
                       }
                   }
           }
       }
   }

public func stopEventToLineEvent(stopEvent: StopEvent, stopID: String) -> LineEvent {
    return LineEvent(stopPointName: stopEvent.stopPointName, plannedQuay: stopEvent.plannedQuay, timetabledTime: stopEvent.timetabledTime, estimatedTime: stopEvent.estimatedTime, stopPlaceRef: stopID, sloid: stopID, previousCall: false, longitude: "", latitude: "")
}

//
//  TripActivity.swift
//  tpgNextFunc
//
//  Les données de l'activité en direct d'un trajet, partagées par l'app (qui la lance et la
//  met à jour) et le widget (qui l'affiche sur l'écran verrouillé et dans la Dynamic Island).
//

import Foundation

/// Un trajet suivi en direct, réduit à ce que l'écran verrouillé affiche.
///
/// Sans serveur, seule l'app met l'activité à jour (au premier plan, ou quand iOS la réveille).
/// Tout est donc en dates : comptes à rebours et barre de progression avancent seuls, et
/// l'étape affichée se déduit de l'heure (`phase(at:)`) plutôt que d'être envoyée.
public struct TripActivityState: Codable, Hashable {
    public struct Leg: Codable, Hashable {
        public var line: String
        public var operatorName: String
        public var transportType: String
        public var destination: String
        public var boardName: String
        public var boardQuay: String
        /// Montée et descente : heures estimées si connues, sinon prévues.
        public var board: Date
        public var alight: Date
        public var alightName: String
        /// Retard à la montée, en minutes.
        public var delay: Int
        /// Quelques passages du véhicule (avant la montée, puis jusqu'à la descente), pour dire
        /// où il se trouve. `nil` sans course connue (itinéraire prévu, API muette).
        public var calls: [Call]?

        public init(line: String, operatorName: String, transportType: String, destination: String,
                    boardName: String, boardQuay: String, board: Date, alight: Date, alightName: String, delay: Int,
                    calls: [Call]? = nil) {
            self.line = line
            self.operatorName = operatorName
            self.transportType = transportType
            self.destination = destination
            self.boardName = boardName
            self.boardQuay = boardQuay
            self.board = board
            self.alight = alight
            self.alightName = alightName
            self.delay = delay
            self.calls = calls
        }

        /// Le dernier arrêt passé par le véhicule à `date`, d'après les heures des passages.
        /// `nil` s'il n'a pas encore atteint le premier passage connu.
        public func vehicleStop(at date: Date) -> String? {
            guard let call = calls?.last(where: { $0.time <= date }) else { return nil }
            return call.name
        }
    }

    /// Un passage du véhicule : l'arrêt et l'heure (estimée si connue).
    public struct Call: Codable, Hashable {
        public var name: String
        public var time: Date

        public init(name: String, time: Date) {
            self.name = name
            self.time = time
        }
    }

    public var legs: [Leg]
    /// Départ du trajet, marche comprise.
    public var departure: Date
    public var arrival: Date
    /// Retard à l'arrivée, en minutes.
    public var arrivalDelay: Int
    /// Le changement à signaler, déjà traduit par l'app. `nil` : rien à signaler.
    public var alert: String?
    public var updated: Date
    /// Le décalage appliqué d'après la position du voyageur, en secondes (`nil` : horaires
    /// d'OJP seuls). Facultatif : une activité lancée par une version précédente n'en a pas.
    public var positionOffset: Int?

    public init(legs: [Leg], departure: Date, arrival: Date, arrivalDelay: Int, alert: String?, updated: Date) {
        self.legs = legs
        self.departure = departure
        self.arrival = arrival
        self.arrivalDelay = arrivalDelay
        self.alert = alert
        self.updated = updated
    }

    /// `nil` si le trajet n'a ni véhicule ni heures lisibles. `calls` : les passages de chaque
    /// course, par `journeyRef` (voir `TripActivityState.calls(from:for:)`).
    public init?(trip: TripEvent, alert: String?, calls: [String: [Call]] = [:], updated: Date = Date()) {
        let legs: [Leg] = trip.vehicleLegs.compactMap { leg in
            guard let board = leg.boardDate, let alight = leg.alightDate else { return nil }
            let planned = OJPDate.date(from: leg.legBoardTimetableTime) ?? board
            return Leg(line: leg.publishedLineName, operatorName: leg.legOperator, transportType: leg.transportTypeName,
                       destination: leg.legDestination, boardName: leg.legBoardStopName, boardQuay: leg.legBoardQuay,
                       board: board, alight: alight, alightName: leg.legAlightStopName,
                       delay: Int((board.timeIntervalSince(planned) / 60).rounded()),
                       calls: leg.journeyRef.isEmpty ? nil : calls[leg.journeyRef])
        }
        guard let first = legs.first, let last = legs.last else { return nil }
        let status = RegularTripStatus(trip: trip)
        // Départ à pied : autant d'avance sur la montée que prévu, décalé du retard.
        let walkBefore = max(0, (trip.anchorDate(.departure, timetabled: true) ?? first.board)
            .timeIntervalSince(trip.startDate ?? first.board))
        let walkAfter = max(0, (trip.endDate ?? last.alight)
            .timeIntervalSince(trip.anchorDate(.arrival, timetabled: true) ?? last.alight))
        self.init(legs: legs,
                  departure: first.board.addingTimeInterval(-walkBefore),
                  arrival: last.alight.addingTimeInterval(walkAfter),
                  arrivalDelay: status.arrivalDelay,
                  alert: alert,
                  updated: updated)
    }

    /// Une course suivie depuis la page d'un arrêt ou d'une ligne : un seul véhicule, de
    /// `boardSloid` à `alightSloid`, d'après les passages de la course (`OJPTripInfoRequest`).
    /// `nil` si l'un des deux arrêts manque, ou s'ils sont dans le mauvais ordre.
    public init?(journey events: [LineEvent], line: String, operatorName: String, transportType: String,
                 destination: String, boardSloid: String, alightSloid: String, alert: String? = nil,
                 updated: Date = Date()) {
        func stop(_ event: LineEvent) -> String { sloidHarmonizer(code: event.sloid.isEmpty ? event.stopPlaceRef : event.sloid) }
        let board = sloidHarmonizer(code: boardSloid)
        let alight = sloidHarmonizer(code: alightSloid)
        guard let boardIndex = events.firstIndex(where: { stop($0) == board }),
              let alightIndex = events[boardIndex...].firstIndex(where: { stop($0) == alight }),
              let boardDate = events[boardIndex].departureDate,
              let alightDate = events[alightIndex].departureDate else { return nil }
        let planned = OJPDate.date(from: events[boardIndex].timetabledTime) ?? boardDate
        let plannedAlight = OJPDate.date(from: events[alightIndex].timetabledTime) ?? alightDate
        let calls = events[max(0, boardIndex - 4)...alightIndex].prefix(16).compactMap { event in
            event.departureDate.map { Call(name: shortStopName(event.stopPointName), time: $0) }
        }
        let leg = Leg(line: line, operatorName: operatorName, transportType: transportType, destination: destination,
                      boardName: events[boardIndex].stopPointName, boardQuay: events[boardIndex].plannedQuay,
                      board: boardDate, alight: alightDate, alightName: events[alightIndex].stopPointName,
                      delay: Int((boardDate.timeIntervalSince(planned) / 60).rounded()), calls: Array(calls))
        self.init(legs: [leg], departure: boardDate, arrival: alightDate,
                  arrivalDelay: Int((alightDate.timeIntervalSince(plannedAlight) / 60).rounded()),
                  alert: alert, updated: updated)
    }

    /// Où en est le voyageur.
    @frozen public enum Phase: Hashable {
        /// En attente du véhicule de l'étape (avant la première montée, ou en correspondance).
        case waiting(leg: Int)
        /// À bord.
        case riding(leg: Int)
        case arrived
    }

    public func phase(at date: Date) -> Phase {
        for (index, leg) in legs.enumerated() {
            if date < leg.board { return .waiting(leg: index) }
            if date < leg.alight { return .riding(leg: index) }
        }
        return .arrived
    }

    /// L'heure du prochain changement d'étape : montée ou descente à venir, sinon l'arrivée.
    /// Sert d'échéance (`staleDate`) : le système redessine l'activité à ce moment-là.
    public func nextTransition(after date: Date) -> Date? {
        (legs.flatMap { [$0.board, $0.alight] } + [arrival]).filter { $0 > date }.min()
    }

    /// L'étape d'après, en petit sous l'étape en cours.
    @frozen public enum NextStep: Hashable {
        /// En attente : le trajet à bord jusqu'à la descente.
        case ride(to: String, minutes: Int)
        /// À bord : la correspondance, et l'attente avant la montée suivante.
        case transfer(leg: Int, waitMinutes: Int)
        /// À bord de la dernière étape : l'arrivée, et la marche éventuelle.
        case arrival(at: Date, walkMinutes: Int)
    }

    public func nextStep(after phase: Phase) -> NextStep? {
        func minutes(_ from: Date, _ to: Date) -> Int { max(0, Int((to.timeIntervalSince(from) / 60).rounded())) }
        switch phase {
        case .waiting(let index):
            let leg = legs[index]
            return .ride(to: leg.alightName, minutes: minutes(leg.board, leg.alight))
        case .riding(let index):
            let leg = legs[index]
            if index + 1 < legs.count {
                return .transfer(leg: index + 1, waitMinutes: minutes(leg.alight, legs[index + 1].board))
            }
            return .arrival(at: arrival, walkMinutes: minutes(leg.alight, arrival))
        case .arrived:
            return nil
        }
    }

    /// Les passages utiles d'une course : les `before` arrêts avant la montée, puis ceux
    /// jusqu'à la descente, au plus `limit` (l'état entier doit tenir en 4 Ko). Noms courts.
    /// Vide si l'arrêt de montée n'est pas dans la course.
    public static func calls(from events: [LineEvent], for leg: TripLeg, before: Int = 4, limit: Int = 16) -> [Call] {
        let board = sloidHarmonizer(code: leg.legBoardStopId)
        let alight = sloidHarmonizer(code: leg.legAlightStopId)
        func stop(_ event: LineEvent) -> String { sloidHarmonizer(code: event.sloid.isEmpty ? event.stopPlaceRef : event.sloid) }
        guard let boardIndex = events.firstIndex(where: { stop($0) == board }) else { return [] }
        let alightIndex = events[boardIndex...].firstIndex(where: { stop($0) == alight }) ?? events.count - 1
        return events[max(0, boardIndex - before)...alightIndex].prefix(limit).compactMap { event in
            event.departureDate.map { Call(name: shortStopName(event.stopPointName), time: $0) }
        }
    }

    /// L'heure visée par l'étape en cours : la montée attendue, ou la descente.
    public func target(of phase: Phase) -> Date? {
        switch phase {
        case .waiting(let leg): return legs[leg].board
        case .riding(let leg): return legs[leg].alight
        case .arrived: return nil
        }
    }
}

/// « Genève, Bel-Air » devient « Bel-Air » : la ville prend trop de place sur l'écran verrouillé.
public func shortStopName(_ name: String) -> String {
    guard let comma = name.firstIndex(of: ",") else { return name }
    let rest = name[name.index(after: comma)...].trimmingCharacters(in: .whitespaces)
    return rest.isEmpty ? name : rest
}

extension TripActivityState {
    /// Les passages de la course d'une étape, demandés à OJP (`OJPTripInfoRequest`, 2.0).
    /// `nil` sans référence de course ou si l'API ne répond pas. L'appelant en tire les
    /// passages affichés (`calls(from:for:)`) et le tracé (`TripRoute.points(from:for:)`).
    public static func fetchJourney(for leg: TripLeg) async -> [LineEvent]? {
        guard !leg.journeyRef.isEmpty else { return nil }
        let data: Data? = await withCheckedContinuation { continuation in
            fetchTransportJourney(journeyRef: leg.journeyRef, operatingDayRef: leg.resolvedOperatingDayRef,
                                  expectedStopRef: leg.legBoardStopId, expectedTime: leg.legBoardTimetableTime) {
                continuation.resume(returning: $0)
            }
        }
        guard let data else { return nil }
        let events = parseJourneyEventsSync(from: data).events
        return events.isEmpty ? nil : events
    }

    /// Les passages affichés d'une étape. `nil` si la course est muette.
    public static func fetchCalls(for leg: TripLeg) async -> [Call]? {
        guard let events = await fetchJourney(for: leg) else { return nil }
        let calls = calls(from: events, for: leg)
        return calls.isEmpty ? nil : calls
    }
}

#if os(iOS)
import ActivityKit

public struct TripActivityAttributes: ActivityAttributes {
    public typealias ContentState = TripActivityState

    /// Clé du trajet suivi : l'identifiant d'un trajet régulier du jour, ou d'un itinéraire.
    public var key: String
    public var title: String
    public var origin: String
    public var destination: String

    public init(key: String, title: String, origin: String, destination: String) {
        self.key = key
        self.title = title
        self.origin = origin
        self.destination = destination
    }
}
#endif

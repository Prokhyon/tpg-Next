//
//  RegularTrip.swift
//  tpgNextFunc
//
//  Les trajets réguliers : un itinéraire refait chaque semaine, certains jours, à la même heure.
//

import Foundation
import CoreLocation

// Un itinéraire enregistré ne vaut que pour son jour : ses `journeyRef` désignent des courses
// datées. Un trajet régulier garde donc la *recette* (départ, arrivée, heure, lignes suivies)
// et redemande chaque jour les itinéraires à OJP (`OJPTripRequest`, 1.0). Il y reconnaît le
// trajet habituel par ses lignes et ses arrêts de montée et de descente, et lit le temps réel
// de la réponse : retards, parcours modifiés, correspondances compromises.

/// Un jour de la semaine, du lundi (1) au dimanche (7).
public enum Weekday: Int, Codable, CaseIterable, Comparable, Identifiable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public var id: Int { rawValue }

    /// `Calendar` numérote à partir du dimanche (1), cette énumération à partir du lundi :
    /// les valeurs brutes ne sont pas interchangeables.
    public init?(calendarWeekday: Int) {
        self.init(rawValue: (calendarWeekday + 5) % 7 + 1)
    }

    public var calendarWeekday: Int { rawValue % 7 + 1 }

    public static let workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    public static let weekend: Set<Weekday> = [.saturday, .sunday]

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Le prochain de ces jours, à `minuteOfDay` heure de Genève, encore à venir après `date` :
    /// le jour dont on demande les itinéraires en créant un trajet régulier.
    public static func nextDate(on weekdays: Set<Weekday>, minuteOfDay: Int, after date: Date,
                                calendar: Calendar = .swissTransit) -> Date? {
        let startOfDay = calendar.startOfDay(for: date)
        return (0...7).lazy.compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfDay),
                  let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: day)),
                  weekdays.contains(weekday),
                  let time = calendar.date(byAdding: .minute, value: minuteOfDay, to: day),
                  time > date else { return nil }
            return time
        }.first
    }
}

extension Calendar {
    /// Le calendrier du réseau : les horaires sont ceux de Genève, où que soit l'appareil.
    public static let swissTransit: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()

    /// « 2026-09-19 », dans le fuseau du calendrier.
    public func dayKey(for date: Date) -> String {
        let components = dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

/// Le départ ou l'arrivée d'un trajet régulier. `TripEndpoint` ne s'enregistre pas
/// (`GeoPosition` porte un `CLLocationCoordinate2D`).
public struct RegularTripPlace: Codable, Hashable {
    public var name: String
    /// L'arrêt ; `nil` pour un lieu (adresse, position au moment de l'enregistrement).
    public var sloid: String?
    public var coordinates: Coordinates

    public init(name: String, sloid: String?, coordinates: Coordinates) {
        self.name = name
        self.sloid = sloid
        self.coordinates = coordinates
    }

    /// Le départ d'un itinéraire : l'arrêt, ou le lieu (adresse, position).
    public static func origin(of trip: TripEvent) -> RegularTripPlace {
        RegularTripPlace(name: trip.startName, sloid: trip.geoDeparture ? nil : trip.startCode, coordinates: trip.startCoordinates)
    }

    /// L'arrivée d'un itinéraire.
    public static func destination(of trip: TripEvent) -> RegularTripPlace {
        RegularTripPlace(name: trip.endName, sloid: trip.geoArrival ? nil : trip.endCode, coordinates: trip.endCoordinates)
    }

    public var endpoint: TripEndpoint {
        if let sloid, !sloid.isEmpty {
            return .stop(Stop(name: name, sloid: sloid, codedidoc: "", country: "", canton: "",
                              meansOfTransport: "", wgs84Coordinates: coordinates))
        }
        return .place(GeoPosition(name: name, coordinate: coordinates.toCLLocationCoordinate2D))
    }
}

/// Une étape en véhicule du trajet habituel : ce qui permet de la reconnaître un autre jour.
public struct RegularTripLeg: Codable, Hashable {
    public var line: String
    public var transportType: String
    public var destination: String
    /// L'arrêt de montée, sans le quai : le quai peut changer d'un jour à l'autre.
    public var boardStop: String
    public var boardName: String
    public var alightStop: String
    public var alightName: String

    public init(leg: TripLeg) {
        line = leg.publishedLineName
        transportType = leg.transportTypeName
        destination = leg.legDestination
        boardStop = sloidHarmonizer(code: leg.legBoardStopId)
        boardName = leg.legBoardStopName
        alightStop = sloidHarmonizer(code: leg.legAlightStopId)
        alightName = leg.legAlightStopName
    }

    func matches(_ leg: TripLeg) -> Bool {
        leg.publishedLineName == line
            && sloidHarmonizer(code: leg.legBoardStopId) == boardStop
            && sloidHarmonizer(code: leg.legAlightStopId) == alightStop
    }
}

public struct RegularTrip: Identifiable, Codable, Hashable {
    /// L'heure retenue : celle de la montée dans le premier véhicule, ou de la descente du dernier.
    @frozen public enum Anchor: String, Codable {
        case departure, arrival
    }

    public var id: UUID
    /// « Travail », « Retour de l'école »… Vide : l'app affiche « départ → arrivée ».
    public var name: String
    public var origin: RegularTripPlace
    public var destination: RegularTripPlace
    public var anchor: Anchor
    /// Minutes depuis minuit, heure de Genève.
    public var minuteOfDay: Int
    public var weekdays: Set<Weekday>
    /// Les étapes en véhicule du trajet habituel.
    public var legs: [RegularTripLeg]
    /// Vrai : reprendre ces lignes et ces arrêts, et signaler quand ce n'est plus possible.
    /// Faux : le meilleur itinéraire du moment, quelles que soient les lignes.
    public var followsLines: Bool
    /// Jours sautés (vacances, télétravail), « yyyy-MM-dd ».
    public var skippedDays: Set<String>
    /// Premier et dernier jour, « yyyy-MM-dd » ; `nil` : sans limite.
    public var firstDay: String?
    public var lastDay: String?
    /// Rappel avant le départ, en minutes ; `nil` : pas de rappel.
    public var reminderMinutes: Int?
    /// Prévenir des retards, suppressions et changements avant le départ.
    public var alertsEnabled: Bool
    /// Activité en direct lancée avant le départ. Optionnel : les trajets enregistrés avant
    /// n'en ont pas (voir `showsLiveActivity`).
    public var liveActivity: Bool?
    /// L'itinéraire choisi à la création : affichage hors ligne et écarts entre le départ du
    /// trajet et la montée (marche jusqu'à l'arrêt), puis entre la descente et l'arrivée.
    public var snapshot: TripEvent
    /// Un autre itinéraire choisi pour un jour (« yyyy-MM-dd ») : ce jour-là, il remplace le
    /// trajet habituel, et c'est lui qui est suivi. Optionnel : les trajets enregistrés avant
    /// n'en ont pas.
    public var dayOverrides: [String: TripEvent]?

    public init(trip: TripEvent, weekdays: Set<Weekday>, anchor: Anchor = .departure, name: String = "",
                followsLines: Bool = true, reminderMinutes: Int? = 5, alertsEnabled: Bool = true,
                calendar: Calendar = .swissTransit) {
        id = UUID()
        self.name = name
        origin = .origin(of: trip)
        destination = .destination(of: trip)
        self.anchor = anchor
        self.weekdays = weekdays
        legs = trip.vehicleLegs.map(RegularTripLeg.init(leg:))
        self.followsLines = followsLines
        skippedDays = []
        self.reminderMinutes = reminderMinutes
        self.alertsEnabled = alertsEnabled
        snapshot = trip
        let anchorDate = trip.anchorDate(anchor, timetabled: true) ?? Date()
        let components = calendar.dateComponents([.hour, .minute], from: anchorDate)
        minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// La recette de ce jour-là : le trajet habituel, ou l'itinéraire choisi à sa place, suivi
    /// ligne pour ligne.
    public func recipe(for day: String, calendar: Calendar = .swissTransit) -> RegularTrip {
        guard let chosen = dayOverrides?[day] else { return self }
        var recipe = self
        recipe.dayOverrides = nil
        recipe.snapshot = chosen
        recipe.legs = chosen.vehicleLegs.map(RegularTripLeg.init(leg:))
        recipe.followsLines = true
        if let anchorDate = chosen.anchorDate(anchor, timetabled: true) {
            let components = calendar.dateComponents([.hour, .minute], from: anchorDate)
            recipe.minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
        return recipe
    }

    /// Un autre itinéraire a été choisi pour ce jour-là.
    public func isOverridden(on day: String) -> Bool {
        dayOverrides?[day] != nil
    }

    /// L'activité en direct, activée par défaut.
    public var showsLiveActivity: Bool {
        get { liveActivity ?? true }
        set { liveActivity = newValue }
    }

    /// Le trajet habituel est-il fait ce jour-là ?
    public func runs(on day: Date, calendar: Calendar = .swissTransit) -> Bool {
        guard let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: day)),
              weekdays.contains(weekday) else { return false }
        let key = calendar.dayKey(for: day)
        if skippedDays.contains(key) { return false }
        // Les clés « yyyy-MM-dd » se comparent comme des dates.
        if let firstDay, key < firstDay { return false }
        if let lastDay, key > lastDay { return false }
        return true
    }

    /// Les trajets à venir, du jour de `date` jusqu'à `days` jours plus tard, qui ne sont
    /// pas encore arrivés à `date`.
    public func occurrences(after date: Date, days: Int = 7, calendar: Calendar = .swissTransit) -> [RegularTripOccurrence] {
        let startOfDay = calendar.startOfDay(for: date)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfDay),
                  runs(on: day, calendar: calendar) else { return nil }
            let key = calendar.dayKey(for: day)
            let recipe = recipe(for: key, calendar: calendar)
            // L'itinéraire choisi donne son heure exacte, même s'il passe minuit.
            guard let target = dayOverrides?[key]?.anchorDate(anchor, timetabled: true)
                    ?? calendar.date(byAdding: .minute, value: minuteOfDay, to: day) else { return nil }
            let occurrence = RegularTripOccurrence(trip: recipe, day: key, target: target)
            return occurrence.plannedArrival > date ? occurrence : nil
        }
    }

    /// L'heure envoyée à OJP, avec une marge : le trajet habituel doit figurer dans la réponse
    /// même avancé de quelques minutes par un changement d'horaire.
    public func request(for occurrence: RegularTripOccurrence) -> (time: Date, isArrivalTime: Bool) {
        switch anchor {
        case .departure: return (occurrence.plannedDeparture.addingTimeInterval(-10 * 60), false)
        case .arrival: return (occurrence.plannedArrival.addingTimeInterval(10 * 60), true)
        }
    }

    /// Le trajet de `trips` qui correspond au trajet habituel ce jour-là, sinon le meilleur à sa place.
    public func match(in trips: [TripEvent], for occurrence: RegularTripOccurrence) -> RegularTripMatch? {
        if isOverridden(on: occurrence.day) {
            return recipe(for: occurrence.day).match(in: trips, for: occurrence)
        }
        let target = occurrence.target
        func gap(_ trip: TripEvent) -> TimeInterval {
            abs((trip.anchorDate(anchor, timetabled: true) ?? .distantFuture).timeIntervalSince(target))
        }

        if followsLines, !legs.isEmpty {
            let usual = trips.filter(isUsual).min { gap($0) < gap($1) }
            if let usual, gap(usual) <= 30 * 60 {
                return usualMatch(usual, for: occurrence)
            }
        }

        // Le meilleur itinéraire : le premier arrivé parmi ceux qui partent à l'heure voulue,
        // ou le dernier parti parmi ceux qui arrivent à temps.
        let best: TripEvent?
        switch anchor {
        case .departure:
            best = trips.filter { ($0.anchorDate(.departure, timetabled: true) ?? .distantPast) >= target.addingTimeInterval(-60) }
                .min { ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture) }
        case .arrival:
            best = trips.filter { ($0.anchorDate(.arrival, timetabled: true) ?? .distantFuture) <= target.addingTimeInterval(60) }
                .max { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        }
        // La réponse d'OJP ne compte que quelques itinéraires : s'ils partent tous trop tôt (ou
        // arrivent trop tard), le plus proche de l'heure voulue vaut mieux que rien.
        guard let best = best ?? trips.min(by: { gap($0) < gap($1) }) else { return nil }
        return RegularTripMatch(trip: best, kind: followsLines && !legs.isEmpty ? .alternative : .usual)
    }

    /// Le trajet habituel, à son heure ou décalé (horaire modifié).
    public func usualMatch(_ trip: TripEvent, for occurrence: RegularTripOccurrence) -> RegularTripMatch {
        let target = occurrence.target
        let minutes = Int(((trip.anchorDate(anchor, timetabled: true) ?? target).timeIntervalSince(target) / 60).rounded())
        return RegularTripMatch(trip: trip, kind: abs(minutes) <= 1 ? .usual : .shifted(minutes: minutes))
    }

    /// `trip`, s'il peut servir à vérifier le trajet habituel de ce jour-là course par course :
    /// mêmes lignes et mêmes arrêts, des courses datées (`journeyRef`), et bien de ce jour-là.
    /// `nil` sinon — l'itinéraire enregistré (`snapshot`), par exemple, date d'un autre jour.
    public func knownUsual(_ trip: TripEvent?, for occurrence: RegularTripOccurrence) -> TripEvent? {
        let recipe = recipe(for: occurrence.day)
        guard recipe.followsLines, !recipe.legs.isEmpty, let trip, recipe.isUsual(trip),
              trip.vehicleLegs.allSatisfy({ !$0.journeyRef.isEmpty }),
              let anchorDate = trip.anchorDate(anchor, timetabled: true),
              abs(anchorDate.timeIntervalSince(occurrence.target)) <= 30 * 60 else { return nil }
        return trip
    }

    /// L'itinéraire enregistré, recalé sur ce jour : ce qu'on affiche tant qu'OJP n'a pas été
    /// interrogé. Sans temps réel ni référence de course, qui ne valent que pour le jour enregistré.
    public func plannedTrip(for occurrence: RegularTripOccurrence) -> TripEvent {
        if isOverridden(on: occurrence.day) {
            return recipe(for: occurrence.day).plannedTrip(for: occurrence)
        }
        guard let anchorDate = snapshot.anchorDate(anchor, timetabled: true) else { return snapshot }
        let delta = occurrence.target.timeIntervalSince(anchorDate)
        func shift(_ time: String) -> String {
            OJPDate.date(from: time).map { OJPDate.string(from: $0.addingTimeInterval(delta)) } ?? time
        }
        var trip = snapshot
        trip.id = occurrence.id
        trip.startTime = shift(trip.startTime)
        trip.endTime = shift(trip.endTime)
        trip.legs = trip.legs.map { leg in
            var leg = leg
            leg.legBoardTimetableTime = shift(leg.legBoardTimetableTime)
            leg.legAlightTimetableTime = shift(leg.legAlightTimetableTime)
            leg.legBoardEstimatedTime = ""
            leg.legAlightEstimatedTime = ""
            leg.journeyRef = ""
            leg.operatingDayRef = nil
            return leg
        }
        return trip
    }

    /// Mêmes lignes, mêmes arrêts de montée et de descente, dans le même ordre.
    public func isUsual(_ trip: TripEvent) -> Bool {
        let vehicleLegs = trip.vehicleLegs
        return vehicleLegs.count == legs.count && zip(legs, vehicleLegs).allSatisfy { $0.matches($1) }
    }
}

/// Un trajet régulier, un jour donné.
public struct RegularTripOccurrence: Identifiable, Hashable {
    public let tripID: UUID
    /// « yyyy-MM-dd », heure de Genève.
    public let day: String
    /// La montée ou la descente prévue (selon `RegularTrip.anchor`).
    public let target: Date
    /// Départ et arrivée de l'itinéraire, marche comprise, d'après l'itinéraire enregistré.
    public let plannedDeparture: Date
    public let plannedArrival: Date

    public var id: String { "\(tripID.uuidString)_\(day)" }

    public init(trip: RegularTrip, day: String, target: Date) {
        tripID = trip.id
        self.day = day
        self.target = target
        let snapshot = trip.snapshot
        let anchorDate = snapshot.anchorDate(trip.anchor, timetabled: true)
        func offset(_ date: Date?) -> TimeInterval {
            guard let date, let anchorDate else { return 0 }
            return date.timeIntervalSince(anchorDate)
        }
        plannedDeparture = target.addingTimeInterval(offset(snapshot.startDate))
        plannedArrival = max(target.addingTimeInterval(offset(snapshot.endDate)), plannedDeparture)
    }
}

/// Le trajet retrouvé dans une réponse d'OJP.
public struct RegularTripMatch: Hashable {
    @frozen public enum Kind: Hashable {
        /// Le trajet habituel, à son heure.
        case usual
        /// Le trajet habituel, mais à une autre heure (horaire modifié).
        case shifted(minutes: Int)
        /// Le trajet habituel n'est pas proposé : voici le meilleur à sa place.
        case alternative
    }

    public let trip: TripEvent
    public let kind: Kind

    public init(trip: TripEvent, kind: Kind) {
        self.trip = trip
        self.kind = kind
    }

    public var status: RegularTripStatus { RegularTripStatus(trip: trip) }
}

/// Ce qui change par rapport à l'horaire, lu dans le temps réel d'un itinéraire.
public struct RegularTripStatus: Hashable {
    /// Retard à la montée dans le premier véhicule, en minutes (négatif : en avance).
    public var departureDelay: Int
    /// Retard à la descente du dernier véhicule, en minutes.
    public var arrivalDelay: Int
    /// Les lignes dont la course est perturbée (arrêts sautés, parcours modifié).
    public var disruptedLines: [String]
    /// Les arrêts où la correspondance risque d'être manquée.
    public var riskyConnections: [String]
    /// Pas d'heure estimée : l'API n'a pas encore de temps réel pour ces courses.
    public var hasRealtime: Bool

    public init(trip: TripEvent) {
        let vehicleLegs = trip.vehicleLegs
        func delay(_ timetabled: String?, _ estimated: String?) -> Int {
            guard let planned = timetabled.flatMap(OJPDate.date(from:)),
                  let actual = estimated.flatMap(OJPDate.date(from:)) else { return 0 }
            return Int((actual.timeIntervalSince(planned) / 60).rounded())
        }
        departureDelay = delay(vehicleLegs.first?.legBoardTimetableTime, vehicleLegs.first?.legBoardEstimatedTime)
        arrivalDelay = delay(vehicleLegs.last?.legAlightTimetableTime, vehicleLegs.last?.legAlightEstimatedTime)
        hasRealtime = vehicleLegs.contains { !$0.legBoardEstimatedTime.isEmpty || !$0.legAlightEstimatedTime.isEmpty }

        disruptedLines = vehicleLegs.filter { $0.hasIncident || !$0.skippedIntermediates.isEmpty }
            .map(\.publishedLineName)
            .reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
        // Correspondance : la montée suivante doit laisser le temps de marcher depuis la descente.
        var risky: [String] = []
        var previous: TripLeg?
        var walk: TimeInterval = 0
        for leg in trip.legs {
            if leg.transfer || leg.publishedLineName.isEmpty {
                walk += leg.walkDuration ?? 0
                continue
            }
            if let previous, let alight = previous.alightDate, let board = leg.boardDate,
               board.timeIntervalSince(alight) < walk {
                risky.append(leg.legBoardStopName)
            }
            previous = leg
            walk = 0
        }
        riskyConnections = risky
    }

    /// Rien à signaler : à l'heure (à une minute près), sans perturbation.
    public var isNormal: Bool {
        abs(departureDelay) <= 1 && arrivalDelay <= 2 && disruptedLines.isEmpty && riskyConnections.isEmpty
    }
}

extension TripEvent {
    /// L'heure où partir, marche comprise : la montée estimée, moins la marche prévue jusqu'à
    /// l'arrêt. Sans véhicule, le départ de l'itinéraire.
    public var leavingDate: Date? {
        guard let start = startDate,
              let plannedBoard = anchorDate(.departure, timetabled: true),
              let board = anchorDate(.departure, timetabled: false) else { return startDate }
        return board.addingTimeInterval(-plannedBoard.timeIntervalSince(start))
    }

    /// Les étapes en bus, tram, train ou bateau ; sans la marche.
    public var vehicleLegs: [TripLeg] {
        legs.filter { !$0.transfer && !$0.publishedLineName.isEmpty }
    }

    /// Montée dans le premier véhicule ou descente du dernier ; à défaut (trajet à pied),
    /// départ ou arrivée de l'itinéraire. `timetabled` : l'heure prévue, qui identifie la
    /// course, plutôt que l'heure estimée.
    public func anchorDate(_ anchor: RegularTrip.Anchor, timetabled: Bool) -> Date? {
        switch anchor {
        case .departure:
            guard let leg = vehicleLegs.first else { return startDate }
            return timetabled ? OJPDate.date(from: leg.legBoardTimetableTime) ?? leg.boardDate : leg.boardDate
        case .arrival:
            guard let leg = vehicleLegs.last else { return endDate }
            return timetabled ? OJPDate.date(from: leg.legAlightTimetableTime) ?? leg.alightDate : leg.alightDate
        }
    }
}

/// Retrouve un trajet régulier auprès d'OJP.
public enum RegularTripResolver {
    public enum Failure: Error {
        case request
        case noTrip
    }

    /// Demande les itinéraires du jour et y cherche le trajet habituel. Lève `Failure.request`
    /// si l'API ne répond pas, `Failure.noTrip` si aucun itinéraire ne convient.
    ///
    /// `known` : le trajet habituel déjà reconnu ce jour-là (courses datées). Absent de la
    /// réponse, ou remplacé par une autre course des mêmes lignes, il n'est pas perdu pour
    /// autant : OJP ne propose que quelques itinéraires. Il est alors vérifié course par course
    /// (`TripVerifier`), et gardé tant que ses courses passent et que ses correspondances tiennent.
    public static func resolve(_ trip: RegularTrip, on occurrence: RegularTripOccurrence,
                               known: TripEvent? = nil) async throws -> RegularTripMatch {
        let known = trip.knownUsual(known, for: occurrence)
        let (time, isArrivalTime) = trip.request(for: occurrence)
        var match: RegularTripMatch?
        var failure: Error = Failure.noTrip
        do {
            let trips = try await trips(from: trip.origin, to: trip.destination, at: time, isArrivalTime: isArrivalTime)
            match = trip.match(in: trips, for: occurrence)
        } catch {
            failure = error
        }
        if let match {
            if case .usual = match.kind { return match }
            // La course déjà reconnue, simplement décalée : OJP a raison, rien à vérifier.
            if let known, match.trip.vehicleLegs.map(\.journeyRef) == known.vehicleLegs.map(\.journeyRef) {
                return match
            }
        }
        if let known, case .feasible(let verified) = await TripVerifier.verify(known) {
            return trip.usualMatch(verified, for: occurrence)
        }
        guard let match else { throw failure }
        return match
    }

    /// Les itinéraires proposés par OJP : ceux du jour pour reconnaître le trajet habituel, ou
    /// ceux parmi lesquels choisir en créant un trajet régulier.
    public static func trips(from origin: RegularTripPlace, to destination: RegularTripPlace,
                             at time: Date, isArrivalTime: Bool) async throws -> [TripEvent] {
        let start = origin.endpoint
        let end = destination.endpoint
        let data: Data? = await withCheckedContinuation { continuation in
            fetchTrips(with: start.stop, with: start.place, with: start.isPlace,
                       with: end.stop, with: end.place, with: end.isPlace,
                       with: time, with: isArrivalTime) { continuation.resume(returning: $0) }
        }
        guard let data else { throw Failure.request }
        do {
            return try parseTripEvents(from: data, startCoordinate: origin.coordinates,
                                       endCoordinates: destination.coordinates,
                                       startName: origin.name, endName: destination.name,
                                       startCode: origin.sloid, endCode: destination.sloid,
                                       geoDeparture: origin.sloid == nil, geoArrival: destination.sloid == nil)
        } catch ParserError.noEventFound {
            throw Failure.noTrip
        }
    }
}

/// Un itinéraire enregistré, redemandé à OJP : ses courses sont datées, il n'est donc
/// reconnu que le jour enregistré. On le traite comme un trajet régulier d'un seul jour.
public enum SavedTripResolver {
    /// `.usual` : la même course (à une minute près), avec son temps réel ; `.shifted` : mêmes
    /// lignes, à une autre heure ; `.alternative` : il n'est plus proposé, voici le meilleur à
    /// sa place. `nil` : aucun itinéraire, ou un itinéraire sans heure.
    public static func update(of saved: TripEvent, in trips: [TripEvent]) -> RegularTripMatch? {
        guard let (recipe, occurrence) = recipe(for: saved) else { return nil }
        return recipe.match(in: trips, for: occurrence)
    }

    /// Demande les itinéraires à l'heure de l'itinéraire enregistré et l'y retrouve. Absent de
    /// la réponse, il est vérifié course par course : ses courses sont celles du jour.
    public static func resolve(_ saved: TripEvent) async throws -> RegularTripMatch {
        guard let (recipe, occurrence) = recipe(for: saved) else { throw RegularTripResolver.Failure.noTrip }
        return try await RegularTripResolver.resolve(recipe, on: occurrence, known: saved)
    }

    private static func recipe(for saved: TripEvent) -> (RegularTrip, RegularTripOccurrence)? {
        guard let target = saved.anchorDate(.departure, timetabled: true) else { return nil }
        let calendar = Calendar.swissTransit
        guard let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: target)) else { return nil }
        let recipe = RegularTrip(trip: saved, weekdays: [weekday], reminderMinutes: nil, alertsEnabled: false)
        return (recipe, RegularTripOccurrence(trip: recipe, day: calendar.dayKey(for: target), target: target))
    }
}

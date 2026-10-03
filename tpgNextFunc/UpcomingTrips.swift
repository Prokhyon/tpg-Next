//
//  UpcomingTrips.swift
//  tpgNextFunc
//
//  Les prochains trajets (réguliers et enregistrés), tels que l'app les connaît, pour le widget
//  « Prochain trajet ». Le widget ne voit ni les réglages de l'app ni OJP en direct : l'app lui
//  laisse un instantané dans le groupe d'app.
//

import Foundation
import SwiftUI

/// Quand partir, dit sans ambiguïté sur la marche.
///
/// L'affichage met en avant le véhicule : sa ligne, son heure et « dans 8 min »
/// (`departureRelative`). La marche jusqu'à l'arrêt n'y est jamais comprise ; elle fait l'objet
/// d'un rappel à part (`walkReminder`) : « Partir dans 3 min · 5 min à pied jusqu'à Rive ».
/// `headline` résume le tout en une phrase, pour les petits formats et les trajets à pied.
public struct TripCountdown: Hashable {
    /// L'heure où partir, marche comprise.
    public var leaving: Date
    /// La montée dans le premier véhicule ; `nil` pour un trajet à pied.
    public var boarding: Date?
    public var arrival: Date
    /// L'arrêt où monter.
    public var boardingStop: String?

    public init(leaving: Date, boarding: Date?, arrival: Date, boardingStop: String?) {
        self.leaving = leaving
        self.boarding = boarding
        self.arrival = arrival
        self.boardingStop = boardingStop
    }

    public init?(trip: TripEvent) {
        guard let leaving = trip.leavingDate ?? trip.startDate, let arrival = trip.endDate else { return nil }
        let board = trip.vehicleLegs.first
        self.init(leaving: leaving, boarding: board?.boardDate, arrival: arrival, boardingStop: board?.legBoardStopName)
    }

    /// La marche avant la montée, en minutes ; `nil` quand l'itinéraire part de l'arrêt même.
    public var walkMinutes: Int? {
        guard let boarding else { return nil }
        let minutes = Int((boarding.timeIntervalSince(leaving) / 60).rounded())
        return minutes >= 1 ? minutes : nil
    }

    public enum Phase {
        /// Il faut encore partir : l'heure annoncée comprend la marche.
        case walkToStop
        /// Le véhicule n'est pas encore parti.
        case waitForDeparture
        /// Dans le véhicule, ou après : jusqu'à l'arrivée.
        case onTheWay
    }

    public func phase(at date: Date) -> Phase {
        guard let boarding else { return date < leaving ? .walkToStop : .onTheWay }
        if walkMinutes != nil, date < leaving { return .walkToStop }
        return date < boarding ? .waitForDeparture : .onTheWay
    }

    /// « Partir dans 3 min », « Départ dans 8 min », « Départ à 17:42 », « Demain, départ à
    /// 07:42 », « En route · arrivée à 08:05 ».
    public func headline(at date: Date) -> String {
        switch phase(at: date) {
        case .walkToStop:
            let time = dateToString(with: leaving)
            if !Calendar.current.isDate(leaving, inSameDayAs: date) {
                return String(localized: "Demain, partir à \(time)", bundle: #bundle)
            }
            let minutes = minutesUntilLeaving(from: date)
            return minutes >= 60 ? String(localized: "Partir à \(time)", bundle: #bundle) : String(localized: "Partir dans \(minutes) min", bundle: #bundle)
        case .waitForDeparture:
            let departure = boarding ?? leaving
            let time = dateToString(with: departure)
            if !Calendar.current.isDate(departure, inSameDayAs: date) {
                return String(localized: "Demain, départ à \(time)", bundle: #bundle)
            }
            let minutes = Self.minutes(until: departure, from: date)
            return minutes >= 60 ? String(localized: "Départ à \(time)", bundle: #bundle) : String(localized: "Départ dans \(minutes) min", bundle: #bundle)
        case .onTheWay:
            return String(localized: "En route · arrivée à \(dateToString(with: arrival))", bundle: #bundle)
        }
    }

    /// Le départ du véhicule, à côté de son heure : « dans 8 min », « demain » ; `nil` à plus
    /// d'une heure (l'heure seule suffit) et une fois parti.
    public func departureRelative(at date: Date) -> String? {
        guard phase(at: date) != .onTheWay else { return nil }
        let departure = boarding ?? leaving
        if !Calendar.current.isDate(departure, inSameDayAs: date) {
            return String(localized: "demain", bundle: #bundle)
        }
        let minutes = Self.minutes(until: departure, from: date)
        return minutes < 60 ? String(localized: "dans \(minutes) min", bundle: #bundle) : nil
    }

    /// Le rappel de marche : « Partir dans 3 min · 5 min à pied jusqu'à Rive » tant qu'il faut
    /// partir, puis « 5 min à pied jusqu'à Rive » ; `nil` sans marche ou une fois monté.
    /// `namingStop` faux (petits formats) : « Partir dans 3 min · 5 min à pied ».
    public func walkReminder(at date: Date, namingStop: Bool = true) -> String? {
        guard let walkMinutes, let described = walkDescription else { return nil }
        let walk = namingStop ? described : String(localized: "\(walkMinutes) min à pied", bundle: #bundle)
        switch phase(at: date) {
        case .walkToStop:
            let minutes = minutesUntilLeaving(from: date)
            let leave = minutes < 60 && Calendar.current.isDate(leaving, inSameDayAs: date)
                ? String(localized: "Partir dans \(minutes) min", bundle: #bundle)
                : String(localized: "Partir à \(dateToString(with: leaving))", bundle: #bundle)
            return "\(leave) · \(walk)"
        case .waitForDeparture:
            return walk
        case .onTheWay:
            return nil
        }
    }

    /// Le sous-titre d'un rappel envoyé `minutesBefore` minutes avant l'heure de partir : avec
    /// une marche, « Partir dans 10 min · 5 min à pied » ; sinon « Départ dans 10 min ». La marche
    /// n'est ainsi jamais comptée dans le départ annoncé.
    public func reminderSubtitle(minutesBefore minutes: Int) -> String {
        if let walkMinutes {
            let walk = String(localized: "\(walkMinutes) min à pied", bundle: #bundle)
            return minutes == 0
                ? String(localized: "C'est l'heure de partir · \(walk)", bundle: #bundle)
                : String(localized: "Partir dans \(minutes) min · \(walk)", bundle: #bundle)
        }
        return minutes == 0 ? String(localized: "Départ maintenant", bundle: #bundle) : String(localized: "Départ dans \(minutes) min", bundle: #bundle)
    }

    /// « 5 min à pied jusqu'à Rive » ; `nil` sans marche.
    public var walkDescription: String? {
        guard let walkMinutes else { return nil }
        guard let boardingStop, !boardingStop.isEmpty else { return String(localized: "\(walkMinutes) min à pied jusqu'à l'arrêt", bundle: #bundle) }
        let stop = splitString(boardingStop, separator: ",")
        return String(localized: "\(walkMinutes) min à pied jusqu'à \(stop.1.isEmpty ? stop.0 : stop.1)", bundle: #bundle)
    }

    /// Les minutes avant de partir, déduites de celles du bus moins la marche : chaque durée
    /// arrondie à part, « partir dans 12 min · 3 min à pied » côtoyait « bus dans 14 min ».
    /// Arrondi ainsi, on part au pire un peu tôt.
    private func minutesUntilLeaving(from date: Date) -> Int {
        guard let boarding, let walkMinutes else { return Self.minutes(until: leaving, from: date) }
        return max(1, Self.minutes(until: boarding, from: date) - walkMinutes)
    }

    /// Arrondi au-dessus : « dans 1 min » tant que ce n'est pas l'heure.
    private static func minutes(until target: Date, from date: Date) -> Int {
        max(1, Int((target.timeIntervalSince(date) / 60).rounded(.up)))
    }
}

public struct UpcomingTrip: Codable, Hashable, Identifiable {
    /// L'état du trajet en une pastille (« À l'heure », « +4 min », « Plus proposé »), comme
    /// sur la carte « Prochain trajet » de l'app.
    public struct Badge: Codable, Hashable {
        public enum Tone: String, Codable {
            case neutral, good, warning, critical
        }

        public var text: String
        public var symbol: String
        public var tone: Tone

        public init(text: String, symbol: String, tone: Tone) {
            self.text = text
            self.symbol = symbol
            self.tone = tone
        }
    }

    public var id: String
    /// « Travail » pour un trajet régulier, « Rive → Cornavin » pour un itinéraire enregistré.
    public var title: String
    public var isRegular: Bool
    public var origin: String
    public var destination: String
    /// L'heure où partir (marche comprise), temps réel s'il est connu.
    public var leaving: Date
    public var arrival: Date
    /// La première montée : ligne, exploitant (pour sa couleur), direction, quai, heure.
    public var line: String?
    public var operatorName: String?
    public var lineDestination: String?
    public var quay: String?
    public var boarding: Date?
    /// L'arrêt où monter : il nomme la marche (« 5 min à pied jusqu'à Rive »).
    public var boardingStop: String?
    /// Ce qui a changé (« Retard de 4 min », « Supprimé »…), s'il y a lieu.
    public var alert: String?
    public var badge: Badge?
    /// Ouvre la liste des trajets de l'app.
    public var url: URL?
    /// L'itinéraire lui-même, pour sa frise ; sans les arrêts intermédiaires, que le widget
    /// n'affiche pas. `nil` dans un instantané laissé par une version plus ancienne de l'app.
    public var event: TripEvent?

    public init(id: String, title: String, isRegular: Bool, origin: String, destination: String,
                leaving: Date, arrival: Date, line: String? = nil, operatorName: String? = nil,
                lineDestination: String? = nil, quay: String? = nil, boarding: Date? = nil,
                boardingStop: String? = nil, alert: String? = nil, badge: Badge? = nil, url: URL? = nil,
                event: TripEvent? = nil) {
        self.id = id
        self.title = title
        self.isRegular = isRegular
        self.origin = origin
        self.destination = destination
        self.leaving = leaving
        self.arrival = arrival
        self.line = line
        self.operatorName = operatorName
        self.lineDestination = lineDestination
        self.quay = quay
        self.boarding = boarding
        self.boardingStop = boardingStop
        self.alert = alert
        self.badge = badge
        self.url = url
        self.event = event
    }

    public init?(trip: TripEvent, id: String, title: String, isRegular: Bool, alert: String?, badge: Badge?, url: URL?) {
        guard let leaving = trip.leavingDate ?? trip.startDate,
              let arrival = trip.endDate else { return nil }
        let board = trip.vehicleLegs.first
        self.init(id: id, title: title, isRegular: isRegular, origin: trip.startName, destination: trip.endName,
                  leaving: leaving, arrival: arrival, line: board?.publishedLineName,
                  operatorName: board?.legOperator, lineDestination: board?.legDestination,
                  quay: board.flatMap { $0.legBoardQuay.isEmpty ? nil : $0.legBoardQuay },
                  boarding: board?.boardDate, boardingStop: board?.legBoardStopName, alert: alert, badge: badge, url: url,
                  event: trip.withoutIntermediates)
    }

    public var countdown: TripCountdown {
        TripCountdown(leaving: leaving, boarding: boarding, arrival: arrival, boardingStop: boardingStop)
    }
}

extension UpcomingTrip {
    /// Un exemple, pour la galerie des widgets et les aperçus : 5 min à pied jusqu'à Rive, le 12
    /// jusqu'à Bel-Air, puis le 15 jusqu'à Cornavin. `delay` : les deux véhicules en retard
    /// d'autant de minutes.
    public static func sample(at now: Date = Date(), delay: Double = 0) -> UpcomingTrip {
        func time(_ minutes: Double) -> String { OJPDate.string(from: now.addingTimeInterval(minutes * 60)) }
        func late(_ minutes: Double) -> String { time(minutes + delay) }
        func walk(_ id: String, from start: Double, to end: Double, walking: Int) -> TripLeg {
            TripLeg(id: id, transfer: true, legBoardStopName: "", legBoardStopId: "", legBoardQuay: "",
                    legBoardTimetableTime: time(start), legBoardEstimatedTime: time(start), legBoardLongitude: "", legBoardLatitude: "",
                    legAlightStopName: "", legAlightStopId: "", legAlightQuay: "",
                    legAlightTimetableTime: time(end), legAlightEstimatedTime: time(end), legAlightLongitude: "", legAlightLatitude: "",
                    legIntermediates: [], legDestination: "", journeyRef: "", publishedLineName: "",
                    legDuration: "PT\(Int(end - start))M", transferDuration: "PT\(Int(end - start))M",
                    transferWalkDuration: "PT\(walking)M", transferBuffer: "", transportTypeName: "walk", legOperator: "")
        }
        func ride(_ line: String, from board: String, _ start: Double, to alight: String, _ end: Double,
                  destination: String, quay: String) -> TripLeg {
            TripLeg(id: line, legBoardStopName: board, legBoardStopId: "", legBoardQuay: quay,
                    legBoardTimetableTime: time(start), legBoardEstimatedTime: late(start), legBoardLongitude: "", legBoardLatitude: "",
                    legAlightStopName: alight, legAlightStopId: "", legAlightQuay: "",
                    legAlightTimetableTime: time(end), legAlightEstimatedTime: late(end), legAlightLongitude: "", legAlightLatitude: "",
                    legIntermediates: [], legDestination: destination, journeyRef: "", publishedLineName: line,
                    legDuration: "PT\(Int(end - start))M", transferDuration: "", transferWalkDuration: "", transferBuffer: "",
                    transportTypeName: "Tram", legOperator: "Transports Publics Genevois")
        }
        let event = TripEvent(id: "sample", duration: "PT30M", startTime: late(8), endTime: late(38),
                              startCoordinates: Coordinates(lon: 0, lat: 0), endCoordinates: Coordinates(lon: 0, lat: 0),
                              startName: "Genève, Florissant", endName: "Genève, gare Cornavin",
                              geoDeparture: false, geoArrival: false, transfers: "1", legs: [
                                walk("walk-1", from: 8, to: 13, walking: 5),
                                ride("12", from: "Genève, Rive", 13, to: "Genève, Bel-Air", 20,
                                     destination: "Thônex, Moillesulaz", quay: "B"),
                                walk("walk-2", from: 20, to: 25, walking: 2),
                                ride("15", from: "Genève, Bel-Air", 25, to: "Genève, gare Cornavin", 38,
                                     destination: "Genève, Nations", quay: "C"),
                              ])
        return UpcomingTrip(trip: event, id: "sample", title: "Travail", isRegular: true, alert: nil,
                            badge: .init(text: "À l'heure", symbol: "checkmark.circle.fill", tone: .good), url: nil)!
    }
}

extension TripEvent {
    /// Sans les arrêts intermédiaires : l'instantané du widget reste léger.
    var withoutIntermediates: TripEvent {
        var trip = self
        trip.legs = legs.map { leg in
            var leg = leg
            leg.legIntermediates = []
            return leg
        }
        return trip
    }
}

/// Quand le widget « Prochain trajet » change d'affichage. Partagé par celui de l'iPhone et la
/// complication de la montre, qui ne font qu'afficher les trajets laissés par leur app.
public enum NextTripTimeline {
    /// Le décompte n'est affiché à la minute que dans l'heure qui précède le départ.
    public static let countdownWindow: TimeInterval = 3600

    /// Maintenant, chaque minute pleine de l'heure qui précède le départ du prochain trajet, puis
    /// chaque changement d'étape (partir, monter, arriver : le trajet suivant prend la place).
    /// `refresh` : quand redemander une timeline. L'app recharge le widget quand ses trajets
    /// changent ; sinon, de quoi ne pas rester figé.
    public static func dates(for trips: [UpcomingTrip], now: Date = Date(), limit: Int = 150) -> (dates: [Date], refresh: Date) {
        var dates: Set<Date> = [now]
        if let next = trips.first(where: { $0.arrival > now }) {
            var minute = Calendar.current.dateInterval(of: .minute, for: max(now, next.leaving.addingTimeInterval(-countdownWindow)))?.end ?? now
            while minute < next.leaving {
                dates.insert(minute)
                minute.addTimeInterval(60)
            }
        }
        for trip in trips {
            dates.formUnion([trip.leaving, trip.boarding, trip.arrival].compactMap { $0 })
        }
        let sorted = Array(dates.filter { $0 >= now }.sorted().prefix(limit))
        let refresh = sorted.last.map { max($0, now).addingTimeInterval(60) } ?? now.addingTimeInterval(3600)
        return (sorted, refresh)
    }
}

public enum UpcomingTripsStorage {
    private static let key = "widget.upcomingTrips"
    /// Le genre du widget, pour que l'app le redessine.
    public static let widgetKind = "tpgNextNextTrip"

    public static func load() -> [UpcomingTrip] {
        guard let data = SharedStorage.defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([UpcomingTrip].self, from: data)) ?? []
    }

    /// Enregistre les trajets. Rend `true` s'ils ont changé : le widget n'est redessiné qu'alors,
    /// WidgetKit limitant le nombre de rechargements par jour.
    @discardableResult
    public static func save(_ trips: [UpcomingTrip]) -> Bool {
        guard let data = try? JSONEncoder().encode(trips),
              data != SharedStorage.defaults.data(forKey: key) else { return false }
        SharedStorage.defaults.set(data, forKey: key)
        return true
    }
}

extension UpcomingTrip.Badge.Tone {
    public var color: Color {
        switch self {
        case .neutral: .secondary
        case .good: .green
        case .warning: .orange
        case .critical: .red
        }
    }
}

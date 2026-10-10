//
//  RegularTripTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Trajets réguliers")
struct RegularTripTests {
    /// Rive → Cornavin, dimanche 13.09.2026 vers 17:56 (heure de Genève).
    private func trips() throws -> [TripEvent] {
        try parseTripEvents(from: Fixture.data("trip-rive-cornavin"),
                            startCoordinate: Coordinates(lon: 6.1418, lat: 46.1985),
                            endCoordinates: Coordinates(lon: 6.1424, lat: 46.2102),
                            startName: "Genève, Rive", endName: "Genève, gare Cornavin",
                            startCode: "ch:1:sloid:87061", endCode: "ch:1:sloid:87057",
                            geoDeparture: false, geoArrival: false)
    }

    /// Le 12 puis le 19, avec une correspondance.
    private func tripWithTransfer() throws -> TripEvent {
        try #require(try trips().first { $0.vehicleLegs.map(\.publishedLineName) == ["12", "19"] })
    }

    /// Le trajet du jour de l'enregistrement, à l'heure de l'itinéraire choisi.
    private func occurrence(of regular: RegularTrip, shiftedBy minutes: Int = 0) throws -> RegularTripOccurrence {
        let target = try #require(regular.snapshot.anchorDate(regular.anchor, timetabled: true))
        return RegularTripOccurrence(trip: regular, day: "2026-09-13", target: target.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    @Test func weekdaysFollowCalendar() {
        #expect(Weekday(calendarWeekday: 1) == .sunday)
        #expect(Weekday(calendarWeekday: 2) == .monday)
        for weekday in Weekday.allCases {
            #expect(Weekday(calendarWeekday: weekday.calendarWeekday) == weekday)
        }
    }

    /// Le jour des itinéraires proposés à la création : le jour même si l'heure n'est pas
    /// passée, sinon le prochain jour coché.
    @Test func nextDateSkipsPassedTimeAndUncheckedDays() throws {
        let calendar = Calendar.swissTransit
        // Mercredi 23.09.2026, 08:00 à Genève.
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 8)))
        func components(_ date: Date?) -> DateComponents? {
            date.map { calendar.dateComponents([.day, .hour, .minute], from: $0) }
        }
        let later = Weekday.nextDate(on: [.wednesday], minuteOfDay: 17 * 60 + 30, after: now)
        #expect(components(later) == DateComponents(day: 23, hour: 17, minute: 30))
        let nextWeek = Weekday.nextDate(on: [.wednesday], minuteOfDay: 7 * 60 + 42, after: now)
        #expect(components(nextWeek) == DateComponents(day: 30, hour: 7, minute: 42))
        let weekend = Weekday.nextDate(on: Weekday.weekend, minuteOfDay: 9 * 60, after: now)
        #expect(components(weekend) == DateComponents(day: 26, hour: 9, minute: 0))
        #expect(Weekday.nextDate(on: [], minuteOfDay: 0, after: now) == nil)
    }

    @Test func recipeComesFromTheTrip() throws {
        let trip = try tripWithTransfer()
        let regular = RegularTrip(trip: trip, weekdays: Weekday.workdays)
        #expect(regular.legs.map(\.line) == ["12", "19"])
        // Sans le quai : il peut changer d'un jour à l'autre.
        #expect(regular.legs.first?.boardStop == "ch:1:sloid:87061")
        #expect(regular.origin.sloid == "ch:1:sloid:87061")
        // Montée dans le 12 à 15:59 UTC, soit 17:59 à Genève.
        #expect(regular.minuteOfDay == 17 * 60 + 59)
    }

    @Test func occurrencesFollowTheWeek() throws {
        var regular = RegularTrip(trip: try tripWithTransfer(), weekdays: [.monday, .wednesday])
        let sunday = try #require(iso8601.date(from: "2026-09-13T08:00:00Z"))
        #expect(regular.occurrences(after: sunday).map(\.day) == ["2026-09-14", "2026-09-16"])

        regular.skippedDays = ["2026-09-14"]
        #expect(regular.occurrences(after: sunday).map(\.day) == ["2026-09-16"])

        regular.lastDay = "2026-09-15"
        #expect(regular.occurrences(after: sunday).isEmpty)
    }

    /// Un trajet reste « à venir » jusqu'à son arrivée, puis disparaît.
    @Test func occurrenceLastsUntilArrival() throws {
        let regular = RegularTrip(trip: try tripWithTransfer(), weekdays: [.sunday])
        let occurrence = try occurrence(of: regular)
        #expect(occurrence.plannedDeparture <= occurrence.target)
        #expect(occurrence.plannedArrival > occurrence.target)
        #expect(regular.occurrences(after: occurrence.plannedArrival.addingTimeInterval(-60), days: 1).count == 1)
        #expect(regular.occurrences(after: occurrence.plannedArrival.addingTimeInterval(60), days: 1).isEmpty)
    }

    @Test func plannedTripIsMovedToTheDay() throws {
        let regular = RegularTrip(trip: try tripWithTransfer(), weekdays: [.monday])
        let monday = try #require(iso8601.date(from: "2026-09-14T04:00:00Z"))
        let occurrence = try #require(regular.occurrences(after: monday, days: 1).first)
        let planned = regular.plannedTrip(for: occurrence)
        #expect(planned.anchorDate(.departure, timetabled: true) == occurrence.target)
        #expect(planned.startDate == occurrence.plannedDeparture)
        #expect(planned.endDate == occurrence.plannedArrival)
        #expect(planned.vehicleLegs.allSatisfy { $0.journeyRef.isEmpty && $0.legBoardEstimatedTime.isEmpty })
    }

    @Test func usualTripIsFound() throws {
        let trip = try tripWithTransfer()
        let regular = RegularTrip(trip: trip, weekdays: [.sunday])
        let match = try #require(regular.match(in: try trips(), for: try occurrence(of: regular)))
        #expect(match.kind == .usual)
        #expect(match.trip.id == trip.id)
    }

    /// Même trajet, cinq minutes plus tôt que d'habitude : l'horaire a changé.
    @Test func shiftedTimetableIsReported() throws {
        let trip = try tripWithTransfer()
        let regular = RegularTrip(trip: trip, weekdays: [.sunday])
        let match = try #require(regular.match(in: try trips(), for: try occurrence(of: regular, shiftedBy: 5)))
        #expect(match.kind == .shifted(minutes: -5))
        #expect(match.trip.id == trip.id)
    }

    /// Un autre itinéraire choisi pour un jour : ce jour-là, c'est lui qu'on attend et qu'on suit.
    @Test func chosenTripReplacesTheDay() throws {
        let usual = try tripWithTransfer()
        let chosen = try #require(try trips().first { $0.vehicleLegs.map(\.publishedLineName) != ["12", "19"] && !$0.vehicleLegs.isEmpty })
        var regular = RegularTrip(trip: usual, weekdays: [.sunday])
        regular.dayOverrides = ["2026-09-13": chosen]
        #expect(regular.isOverridden(on: "2026-09-13"))

        let before = try #require(chosen.startDate).addingTimeInterval(-3600)
        let occurrence = try #require(regular.occurrences(after: before, days: 1).first)
        #expect(occurrence.target == chosen.anchorDate(.departure, timetabled: true))
        #expect(regular.plannedTrip(for: occurrence).vehicleLegs.map(\.publishedLineName) == chosen.vehicleLegs.map(\.publishedLineName))
        let match = try #require(regular.match(in: try trips(), for: occurrence))
        #expect(match.kind == .usual)
        #expect(match.trip.id == chosen.id)

        // Les autres jours gardent le trajet habituel.
        #expect(regular.recipe(for: "2026-09-20").legs.map(\.line) == ["12", "19"])
    }

    /// Un itinéraire enregistré retrouvé dans une nouvelle réponse : la même course.
    @Test func savedTripIsFoundAgain() throws {
        let saved = try tripWithTransfer()
        let match = try #require(SavedTripResolver.update(of: saved, in: try trips()))
        #expect(match.kind == .usual)
        #expect(match.trip.id == saved.id)
    }

    /// Ses lignes ne sont plus proposées : il n'est plus possible, le meilleur à sa place.
    @Test func goneSavedTripGivesAProposal() throws {
        let saved = try tripWithTransfer()
        let others = try trips().filter { $0.vehicleLegs.map(\.publishedLineName) != ["12", "19"] }
        let match = try #require(SavedTripResolver.update(of: saved, in: others))
        #expect(match.kind == .alternative)
        #expect(match.trip.id != saved.id)
    }

    @Test func missingLineGivesAnAlternative() throws {
        var regular = RegularTrip(trip: try tripWithTransfer(), weekdays: [.sunday])
        regular.legs[0].line = "99"
        let occurrence = try occurrence(of: regular)
        let match = try #require(regular.match(in: try trips(), for: occurrence))
        #expect(match.kind == .alternative)
        // L'alternative ne part pas avant l'heure voulue.
        #expect(try #require(match.trip.anchorDate(.departure, timetabled: true)) >= occurrence.target.addingTimeInterval(-60))
    }

    /// Tous les itinéraires partent avant l'heure voulue : le plus proche plutôt qu'aucun.
    @Test func closestTripWhenAllLeaveEarlier() throws {
        var regular = RegularTrip(trip: try tripWithTransfer(), weekdays: [.sunday])
        regular.legs[0].line = "99"
        let match = try #require(regular.match(in: try trips(), for: try occurrence(of: regular, shiftedBy: 120)))
        #expect(match.kind == .alternative)
        let latest = try trips().compactMap { $0.anchorDate(.departure, timetabled: true) }.max()
        #expect(match.trip.anchorDate(.departure, timetabled: true) == latest)
    }

    /// Sans lignes à suivre, le meilleur itinéraire est le trajet du jour.
    @Test func bestTripWhenLinesAreFree() throws {
        var regular = RegularTrip(trip: try tripWithTransfer(), weekdays: [.sunday], followsLines: false)
        regular.legs[0].line = "99"
        let match = try #require(regular.match(in: try trips(), for: try occurrence(of: regular)))
        #expect(match.kind == .usual)
    }

    @Test func arrivalAnchorKeepsTheArrival() throws {
        let trip = try tripWithTransfer()
        let regular = RegularTrip(trip: trip, weekdays: [.sunday], anchor: .arrival)
        let occurrence = try occurrence(of: regular)
        #expect(regular.request(for: occurrence).isArrivalTime)
        let match = try #require(regular.match(in: try trips(), for: occurrence))
        #expect(match.trip.id == trip.id)
    }

    @Test func statusReadsDelays() {
        var trip = FullTripTest().Trip
        #expect(RegularTripStatus(trip: trip).isNormal)

        trip.legs[1].legBoardEstimatedTime = "2025-02-08T14:55:42Z"
        trip.legs[1].legAlightEstimatedTime = "2025-02-08T15:14:42Z"
        let status = RegularTripStatus(trip: trip)
        #expect(status.departureDelay == 4)
        #expect(!status.isNormal)
        // Descente à 15:14:42, 5 minutes de marche : le tram de 15:20:42 reste atteignable.
        #expect(status.riskyConnections.isEmpty)

        trip.legs[1].legAlightEstimatedTime = "2025-02-08T15:18:42Z"
        #expect(RegularTripStatus(trip: trip).riskyConnections == ["Genève, Terrassière"])
    }

    /// Rive → Meinier le 19.09.2026 : le A saute seize arrêts.
    @Test func statusReadsIncidents() throws {
        let trips = try parseTripEvents(from: Fixture.data("trip-rive-meinier-incident"),
                                        startCoordinate: Coordinates(lon: 6.1508, lat: 46.2025),
                                        endCoordinates: Coordinates(lon: 6.2338, lat: 46.2465),
                                        startName: "Genève, Rive", endName: "Meinier, église",
                                        startCode: "ch:1:sloid:87061", endCode: "ch:1:sloid:93001",
                                        geoDeparture: false, geoArrival: false)
        let detour = try #require(trips.first { $0.vehicleLegs.contains { $0.publishedLineName == "A" && $0.hasIncident } })
        #expect(RegularTripStatus(trip: detour).disruptedLines.contains("A"))
    }

    /// Les lignes évitées : enregistrées avec le trajet, jamais celles du trajet habituel.
    @Test func avoidedLinesAreKept() throws {
        let usual = try tripWithTransfer()
        var regular = RegularTrip(trip: usual, weekdays: Weekday.workdays)
        #expect(regular.avoidedLines == nil)
        #expect(regular.isUsualLine(try #require(usual.avoidableLines.first)))
        let other = try #require(try trips().flatMap(\.avoidableLines).first { !regular.isUsualLine($0) })
        regular.linesToAvoid = [other]
        let decoded = try JSONDecoder().decode(RegularTrip.self, from: JSONEncoder().encode(regular))
        #expect(decoded.linesToAvoid == [other])
        regular.linesToAvoid = []
        #expect(regular.avoidedLines == nil)
    }

    @Test func survivesEncoding() throws {
        var regular = RegularTrip(trip: try tripWithTransfer(), weekdays: Weekday.workdays, name: "Travail")
        regular.skippedDays = ["2026-12-25"]
        let decoded = try JSONDecoder().decode(RegularTrip.self, from: JSONEncoder().encode(regular))
        #expect(decoded == regular)
    }
}

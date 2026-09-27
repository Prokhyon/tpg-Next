//
//  TripCountdownTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Quand partir")
struct TripCountdownTests {
    /// Midi, pour rester le même jour quel que soit le fuseau des tests.
    private let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

    private func at(_ minutes: Double) -> Date { noon.addingTimeInterval(minutes * 60) }

    @Test func fromAStopItIsTheDeparture() {
        // Le bus part de l'arrêt même : l'heure annoncée ne comprend aucune marche.
        let countdown = TripCountdown(leaving: at(8), boarding: at(8), arrival: at(30), boardingStop: "Genève, Rive")
        #expect(countdown.walkMinutes == nil)
        #expect(countdown.walkDescription == nil)
        #expect(countdown.phase(at: noon) == .waitForDeparture)
        #expect(countdown.headline(at: noon) == "Départ dans 8 min")
    }

    @Test func withAWalkItIsWhenToLeave() {
        let countdown = TripCountdown(leaving: at(3), boarding: at(8), arrival: at(30), boardingStop: "Genève, Rive")
        #expect(countdown.walkMinutes == 5)
        #expect(countdown.walkDescription == "5 min à pied jusqu'à Rive")
        #expect(countdown.headline(at: noon) == "Partir dans 3 min")
    }

    @Test func onceLeftItCountsDownToTheBus() {
        let countdown = TripCountdown(leaving: at(3), boarding: at(8), arrival: at(30), boardingStop: "Genève, Rive")
        // L'heure de partir est passée : c'est désormais le départ du bus qui compte.
        #expect(countdown.phase(at: at(4)) == .waitForDeparture)
        #expect(countdown.headline(at: at(4)) == "Départ dans 4 min")
        #expect(countdown.phase(at: at(9)) == .onTheWay)
        #expect(countdown.headline(at: at(9)).hasPrefix("En route"))
    }

    @Test func laterTheClockTime() {
        let countdown = TripCountdown(leaving: at(90), boarding: at(95), arrival: at(120), boardingStop: nil)
        #expect(countdown.headline(at: noon).hasPrefix("Partir à "))
        #expect(countdown.walkDescription == "5 min à pied jusqu'à l'arrêt")
        #expect(countdown.headline(at: at(92)).hasPrefix("Départ dans 3 min"))
    }

    @Test func theBusComesFirstAndTheWalkApart() {
        let countdown = TripCountdown(leaving: at(3), boarding: at(8), arrival: at(30), boardingStop: "Genève, Rive")
        // L'heure affichée en gros est celle du bus : « dans 8 min », pas 3.
        #expect(countdown.departureRelative(at: noon) == "dans 8 min")
        #expect(countdown.walkReminder(at: noon) == "Partir dans 3 min · 5 min à pied jusqu'à Rive")
        // Parti de chez soi : la marche reste dite, sans décompte.
        #expect(countdown.walkReminder(at: at(4)) == "5 min à pied jusqu'à Rive")
        #expect(countdown.walkReminder(at: noon, namingStop: false) == "Partir dans 3 min · 5 min à pied")
        // Monté : plus rien à attendre.
        #expect(countdown.departureRelative(at: at(9)) == nil)
        #expect(countdown.walkReminder(at: at(9)) == nil)
    }

    @Test func fromAStopNoWalkReminder() {
        let countdown = TripCountdown(leaving: at(8), boarding: at(8), arrival: at(30), boardingStop: "Rive")
        #expect(countdown.walkReminder(at: noon) == nil)
        #expect(countdown.departureRelative(at: noon) == "dans 8 min")
        // À plus d'une heure, l'heure seule suffit.
        #expect(countdown.departureRelative(at: at(-90)) == nil)
    }

    @Test func displayedMinutesAddUp() {
        // Marche de 2 min 42 s, bus dans 13 min 54 s : chaque durée arrondie à part donnait
        // « partir dans 12 min · 3 min à pied » pour un bus « dans 14 min ».
        let countdown = TripCountdown(leaving: at(11.2), boarding: at(13.9), arrival: at(30), boardingStop: "Rive")
        #expect(countdown.departureRelative(at: noon) == "dans 14 min")
        #expect(countdown.walkReminder(at: noon) == "Partir dans 11 min · 3 min à pied jusqu'à Rive")
    }

    @Test func remindersNeverCountTheWalkInTheDeparture() {
        let walking = TripCountdown(leaving: at(3), boarding: at(8), arrival: at(30), boardingStop: "Rive")
        #expect(walking.reminderSubtitle(minutesBefore: 10) == "Partir dans 10 min · 5 min à pied")
        #expect(walking.reminderSubtitle(minutesBefore: 0) == "C'est l'heure de partir · 5 min à pied")
        let fromTheStop = TripCountdown(leaving: at(8), boarding: at(8), arrival: at(30), boardingStop: "Rive")
        #expect(fromTheStop.reminderSubtitle(minutesBefore: 10) == "Départ dans 10 min")
        #expect(fromTheStop.reminderSubtitle(minutesBefore: 0) == "Départ maintenant")
    }

    @Test func aFewSecondsOfWalkAreNotAWalk() {
        // Heure estimée et heure de départ à quelques secondes près : pas de « 0 min à pied ».
        let countdown = TripCountdown(leaving: at(8), boarding: at(8.3), arrival: at(30), boardingStop: "Rive")
        #expect(countdown.walkMinutes == nil)
        #expect(countdown.headline(at: noon) == "Départ dans 9 min")
    }
}

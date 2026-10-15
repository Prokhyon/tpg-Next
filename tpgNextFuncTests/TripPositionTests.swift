//
//  TripPositionTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Position sur un trajet suivi")
struct TripPositionTests {
    /// Un parcours droit vers l'est depuis Rive, un arrêt toutes les 400 m et toutes les 2 min.
    private let start = (latitude: 46.2044, longitude: 6.1532)
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// 400 m vers l'est valent environ 0,00519° de longitude à cette latitude.
    private var step: Double { 400 / (111_320 * cos(start.latitude * .pi / 180)) }

    private func route(stops: Int = 5) -> [TripRoute.Point] {
        (0..<stops).map { index in
            TripRoute.Point(latitude: start.latitude,
                            longitude: start.longitude + Double(index) * step,
                            time: base.addingTimeInterval(Double(index) * 120))
        }
    }

    @Test func onTimeBetweenTwoStops() throws {
        // Au milieu du deuxième segment : prévu à 3 min, et il est 3 min.
        let fix = try #require(TripPositionEstimator.fix(
            on: route(), latitude: start.latitude, longitude: start.longitude + 1.5 * step,
            now: base.addingTimeInterval(180)))
        #expect(abs(fix.offset) < 5)
        #expect(fix.distance < 20)
        #expect(abs(fix.progress - 0.375) < 0.02)
    }

    @Test func lateVehicleGivesPositiveOffset() throws {
        // On est au deuxième arrêt (prévu à 2 min) alors qu'il est 4 min : deux minutes de retard.
        let fix = try #require(TripPositionEstimator.fix(
            on: route(), latitude: start.latitude, longitude: start.longitude + step,
            now: base.addingTimeInterval(240)))
        #expect(abs(fix.offset - 120) < 5)
    }

    @Test func earlyVehicleGivesNegativeOffset() throws {
        let fix = try #require(TripPositionEstimator.fix(
            on: route(), latitude: start.latitude, longitude: start.longitude + 2 * step,
            now: base.addingTimeInterval(180)))
        #expect(abs(fix.offset + 60) < 5)
    }

    @Test func farFromTheRouteTellsNothing() {
        // Un kilomètre au nord du parcours : le voyageur n'est pas dans ce véhicule.
        #expect(TripPositionEstimator.fix(on: route(), latitude: start.latitude + 0.009,
                                          longitude: start.longitude + step,
                                          now: base.addingTimeInterval(120)) == nil)
    }

    @Test func aVaguePositionWidensTheMargin() throws {
        // À 200 m du parcours : refusé si la position est bonne, admis si elle est vague.
        let latitude = start.latitude + 200 / 111_132
        #expect(TripPositionEstimator.fix(on: route(), latitude: latitude, longitude: start.longitude + step,
                                          accuracy: 5, now: base.addingTimeInterval(120)) == nil)
        #expect(TripPositionEstimator.fix(on: route(), latitude: latitude, longitude: start.longitude + step,
                                          accuracy: 80, now: base.addingTimeInterval(120)) != nil)
    }

    @Test func tooLargeAnOffsetLeavesOJPInCharge() {
        // Sur le parcours, mais dix minutes à côté de l'horaire : c'est OJP qui a raison.
        #expect(TripPositionEstimator.fix(on: route(), latitude: start.latitude, longitude: start.longitude + step,
                                          now: base.addingTimeInterval(720)) == nil)
    }

    @Test func aRouteNeedsTwoPoints() {
        #expect(TripPositionEstimator.fix(on: Array(route().prefix(1)), latitude: start.latitude,
                                          longitude: start.longitude, now: base) == nil)
    }

    // MARK: Dans le véhicule, ou resté à l'arrêt

    @Test func movingWithTheVehicleMeansAboard() {
        // Deux arrêts plus loin, à l'heure où le véhicule devrait y être.
        #expect(TripPositionEstimator.isAboard(on: route(), latitude: start.latitude,
                                               longitude: start.longitude + 2 * step,
                                               now: base.addingTimeInterval(240)) == true)
    }

    @Test func stayingAtTheStopMeansTheVehicleLeftWithoutUs() {
        // Toujours au premier arrêt alors que le véhicule est à 800 m : la correspondance est ratée.
        #expect(TripPositionEstimator.isAboard(on: route(), latitude: start.latitude,
                                               longitude: start.longitude,
                                               now: base.addingTimeInterval(240)) == false)
    }

    @Test func farFromTheRouteIsNotAboard() {
        #expect(TripPositionEstimator.isAboard(on: route(), latitude: start.latitude + 0.02,
                                               longitude: start.longitude,
                                               now: base.addingTimeInterval(240)) == false)
    }

    @Test func aWiderToleranceForgivesTheDistance() {
        // À 400 m de là où le véhicule devrait être : trop pour 300 m, assez pour 500.
        #expect(TripPositionEstimator.isAboard(on: route(), latitude: start.latitude,
                                               longitude: start.longitude + step,
                                               now: base.addingTimeInterval(240)) == false)
        #expect(TripPositionEstimator.isAboard(on: route(), latitude: start.latitude,
                                               longitude: start.longitude + step,
                                               now: base.addingTimeInterval(240), tolerance: 500) == true)
    }

    @Test func aRouteTooShortSaysNothing() {
        #expect(TripPositionEstimator.isAboard(on: Array(route().prefix(1)), latitude: start.latitude,
                                               longitude: start.longitude, now: base) == nil)
    }

    // MARK: L'état corrigé

    private func state(now: Date) -> TripActivityState {
        let leg = TripActivityState.Leg(
            line: "12", operatorName: "tpg", transportType: "Tram", destination: "Bachet",
            boardName: "Rive", boardQuay: "B", board: now.addingTimeInterval(-300),
            alight: now.addingTimeInterval(300), alightName: "Plainpalais", delay: 0,
            calls: [.init(name: "Molard", time: now.addingTimeInterval(-60)),
                    .init(name: "Cirque", time: now.addingTimeInterval(120))])
        return TripActivityState(legs: [leg], departure: now.addingTimeInterval(-360),
                                 arrival: now.addingTimeInterval(420), arrivalDelay: 0, alert: nil, updated: now)
    }

    @Test func adjustingShiftsWhatIsStillToCome() {
        let now = base
        let adjusted = state(now: now).adjusted(leg: 0, by: 90, now: now)
        #expect(adjusted.legs[0].alight == now.addingTimeInterval(390))
        // Le dernier véhicule emporte l'arrivée avec lui.
        #expect(adjusted.arrival == now.addingTimeInterval(510))
        // Un passage déjà fait ne bouge plus ; celui à venir suit.
        #expect(adjusted.legs[0].calls?[0].time == now.addingTimeInterval(-60))
        #expect(adjusted.legs[0].calls?[1].time == now.addingTimeInterval(210))
        #expect(adjusted.positionOffset == 90)
    }

    @Test func aTinyOffsetChangesNothing() {
        let now = base
        let adjusted = state(now: now).adjusted(leg: 0, by: 12, now: now)
        #expect(adjusted == state(now: now))
        #expect(adjusted.positionOffset == nil)
    }

    @Test func anEarlyArrivalNeverGoesBackwards() {
        let now = base
        // Dix minutes d'avance sur une descente prévue dans cinq : elle est maintenant.
        let adjusted = state(now: now).adjusted(leg: 0, by: -600, now: now)
        #expect(adjusted.legs[0].alight == now)
        #expect(adjusted.phase(at: now) == .arrived)
    }
}

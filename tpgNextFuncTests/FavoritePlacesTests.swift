//
//  FavoritePlacesTests.swift
//  tpgNextFuncTests
//

import Foundation
import CoreLocation
import Testing
@testable import tpgNextFunc

@Suite("Lieux favoris")
struct FavoritePlacesTests {
    private let uniMail = CLLocationCoordinate2D(latitude: 46.19517, longitude: 6.14046)

    // Le modèle d'aperçu n'écrit ni sur l'appareil ni dans iCloud.
    private func model() -> FavoritePlacesModel {
        FavoritePlacesModel(previewPlaces: [])
    }

    @Test func thePlaceIsRecognisedAFewMetresAway() {
        let model = model()
        model.add(name: "Uni Mail", address: "1205 Genève", coordinate: uniMail)
        // Plans ne rend pas toujours exactement les mêmes coordonnées.
        #expect(model.isFavorite(CLLocationCoordinate2D(latitude: 46.19522, longitude: 6.14051)))
        #expect(!model.isFavorite(CLLocationCoordinate2D(latitude: 46.19700, longitude: 6.14046)))
        // Déjà là : pas de doublon.
        model.add(name: "Uni Mail", address: nil, coordinate: uniMail)
        #expect(model.places.count == 1)
    }

    @Test func toggleAddsThenRemoves() {
        let model = model()
        model.toggle(name: "Uni Mail", address: nil, coordinate: uniMail)
        #expect(model.places.count == 1)
        model.toggle(name: "Uni Mail", address: nil, coordinate: uniMail)
        #expect(model.places.isEmpty)
    }

    @Test func aRenamedPlaceRecallsItsMapsName() throws {
        let model = model()
        model.add(name: "Uni Mail", address: "1205 Genève", coordinate: uniMail)
        let place = try #require(model.places.first)
        #expect(place.detail == "1205 Genève")

        model.rename(place, to: "  Cours  ")
        let renamed = try #require(model.places.first)
        #expect(renamed.name == "Cours")
        #expect(renamed.detail == "Uni Mail")
        #expect(renamed.endpoint.name == "Cours")

        // Un nom vide rend celui de Plans.
        model.rename(renamed, to: " ")
        #expect(model.places.first?.name == "Uni Mail")
        #expect(model.places.first?.isRenamed == false)
    }
}

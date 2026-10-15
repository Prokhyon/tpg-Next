//
//  FavoritePlaces.swift
//  tpgNextFunc
//
//  Les lieux favoris : une adresse ou un point d'intérêt (maison, travail…), surtout pour les
//  itinéraires. Ajoutés depuis Explorer, renommables, partagés entre les appareils via iCloud
//  comme les arrêts favoris.
//

import Foundation
import CoreLocation
import SwiftUI

public struct FavoritePlace: Codable, Hashable, Identifiable {
    public var id: String
    /// Le nom affiché : celui de Plans, ou celui choisi par l'utilisateur (« Maison »).
    public var name: String
    /// Le nom donné par Plans, et son adresse : rappelés sous un nom choisi.
    public var placeName: String
    public var address: String?
    public var latitude: Double
    public var longitude: Double

    public init(id: String = UUID().uuidString, name: String, address: String?, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.placeName = name
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Renommé par l'utilisateur : le nom de Plans passe dessous.
    public var isRenamed: Bool { name != placeName }

    /// Ce qui est rappelé sous le nom : le nom de Plans s'il a été renommé, sinon l'adresse.
    public var detail: String? {
        if isRenamed { return placeName }
        return address?.isEmpty == false ? address : nil
    }

    /// Départ ou arrivée d'un itinéraire, sous le nom choisi.
    public var endpoint: TripEndpoint {
        .place(GeoPosition(name: name, coordinate: coordinate))
    }

    /// Le même endroit, à une quinzaine de mètres près : Plans ne rend pas toujours exactement
    /// les mêmes coordonnées pour un lieu.
    public func isAt(_ other: CLLocationCoordinate2D) -> Bool {
        abs(latitude - other.latitude) < 0.00015 && abs(longitude - other.longitude) < 0.0002
    }
}

@Observable
public final class FavoritePlacesModel {
    public static let shared = FavoritePlacesModel()

    /// Dans l'ordre choisi par l'utilisateur.
    public private(set) var places: [FavoritePlace] = []

    private let store: CodableStore<[FavoritePlace]>?
    private let cloud = CloudCollection<FavoritePlace>(key: "cloud.favoritePlaces", id: \.id)

    public init() {
        store = CodableStore(key: "favoritePlaces", defaults: SharedStorage.defaults)
        places = store?.load() ?? []
    }

    /// Pour les aperçus : rien n'est lu ni enregistré.
    public init(previewPlaces: [FavoritePlace]) {
        store = nil
        places = previewPlaces
    }

    /// Partage les lieux avec les autres appareils via iCloud. Seule l'app iOS l'appelle.
    public func startCloudSync() {
        guard store != nil else { return }
        cloud.start(current: places) { [weak self] merged in
            guard let self else { return }
            places = merged
            store?.save(places)
        }
    }

    // MARK: Lectures

    public func place(at coordinate: CLLocationCoordinate2D) -> FavoritePlace? {
        places.first { $0.isAt(coordinate) }
    }

    public func isFavorite(_ coordinate: CLLocationCoordinate2D) -> Bool {
        place(at: coordinate) != nil
    }

    // MARK: Modifications

    public func add(name: String, address: String?, coordinate: CLLocationCoordinate2D) {
        guard !isFavorite(coordinate) else { return }
        places.append(FavoritePlace(name: name, address: address, coordinate: coordinate))
        commit()
    }

    /// Ajoute le lieu, ou le retire s'il y est déjà.
    public func toggle(name: String, address: String?, coordinate: CLLocationCoordinate2D) {
        if let existing = place(at: coordinate) {
            remove(existing)
        } else {
            add(name: name, address: address, coordinate: coordinate)
        }
    }

    /// Un nom vide rend celui de Plans.
    public func rename(_ place: FavoritePlace, to name: String) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        places[index].name = trimmed.isEmpty ? places[index].placeName : trimmed
        commit()
    }

    public func remove(_ place: FavoritePlace) {
        places.removeAll { $0.id == place.id }
        commit()
    }

    public func remove(atOffsets offsets: IndexSet) {
        places.remove(atOffsets: offsets)
        commit()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        places.move(fromOffsets: source, toOffset: destination)
        commit()
    }

    private func commit() {
        store?.save(places)
        cloud.record(places)
    }
}

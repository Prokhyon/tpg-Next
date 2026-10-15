//
//  NearbyStops.swift
//  tpg Next
//
//  Les arrêts proches de l'accueil. La liste des départs et la carte montrent les mêmes, et la
//  carte met en évidence celui que la liste affiche.
//

import Foundation
import CoreLocation
import Observation
import tpgNextFunc

@Observable
final class NearbyStops {
    enum Status: Equatable {
        case loading
        case found
        /// Position refusée (`denied`) ou introuvable.
        case failed(denied: Bool)
    }

    /// Les plus proches, favori le plus proche en tête (même règle que le widget et la montre).
    private(set) var stops: [Stop] = []
    private(set) var status: Status = .loading
    private(set) var location: CLLocation?
    /// L'arrêt choisi, dans la liste (page du carrousel, arrêt déplié) ou d'un toucher sur la
    /// carte. `nil` : le premier.
    var selectedSloid: String?
    /// L'arrêt que la liste affiche vraiment : la carte le met en évidence.
    var highlightedSloid: String?
    /// Les arrêts de la liste : ceux de la carte, ou des favoris. Un arrêt de la carte qui n'y
    /// est pas (liste des favoris) ouvre sa page au lieu d'être choisi.
    var listedSloids: [String] = []

    /// Assez pour remplir la carte, pas trop pour que la liste reste lisible.
    static let count = 6
    /// Au-delà, un arrêt n'est plus « proche ».
    static let radius: CLLocationDistance = 1000

    @ObservationIgnored private let locationManager = LocationManager()

    /// Redemande la position et recalcule les arrêts. La base se charge en arrière-plan : sans
    /// elle, rien ne se passe, et l'appel suivant (`isLoaded` qui change) recommence.
    func refresh(stopStore: StopStore, favoriteSloids: Set<String>) {
        guard stopStore.isLoaded else { return }
        locationManager.requestLocation { [weak self] location in
            guard let self else { return }
            self.locationManager.locationUpdateHandler = nil
            guard let userLocation = location ?? self.locationManager.userLocation else {
                Log.location.error("Position indisponible pour les arrêts proches")
                self.status = .failed(denied: self.locationManager.lastFailure == .denied)
                return
            }
            let candidates = stopsInBoundingBox(from: userLocation, radius: Self.radius, stops: stopStore.activeStops)
            calculateClosestBusStops(from: userLocation, stops: candidates, nb: Self.count) { _, closest in
                let stops = NearbyStopSelector.prioritized(closest, from: userLocation, favoriteSloids: favoriteSloids)
                DispatchQueue.main.async {
                    self.location = userLocation
                    self.stops = stops
                    self.status = .found
                    stopStore.location = userLocation
                }
            }
        }
    }
}

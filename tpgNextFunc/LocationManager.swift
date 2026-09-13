//
//  LocationManager.swift
//  tpgNextFunc
//
//  Position ponctuelle et arrêts proches, partagés par l'app et la montre.
//

import Foundation
import Combine
import CoreLocation

public final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published public private(set) var userLocation: CLLocation?
    @Published public private(set) var locationStatus: CLAuthorizationStatus?
    /// Rappelé à chaque demande, avec `nil` si la position n'a pas pu être obtenue.
    public var locationUpdateHandler: ((CLLocation?) -> Void)?

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    public func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    public func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        locationUpdateHandler = completion
        locationManager.requestLocation()
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        #if os(iOS)
        // Repli du widget : sans autorisation « Toujours », l'extension n'a pas le droit
        // de demander la position et se rabat sur la dernière connue de l'app.
        SharedStorage.saveLastKnownLocation(location)
        #endif
        Log.location.debug("Position reçue : \(location)")
        locationUpdateHandler?(location)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
        Log.location.info("Autorisation de localisation : \(manager.authorizationStatus.rawValue)")
    }

    /// Sans ce rappel, un refus ou une absence de signal laissait l'appelant attendre
    /// indéfiniment (écran bloqué sur « Chargement... »).
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.location.error("Position indisponible : \(error.localizedDescription)")
        locationUpdateHandler?(nil)
    }
}

/// Les `nb` arrêts les plus proches de `location`, du plus proche au plus lointain.
public func calculateClosestBusStops(from location: CLLocation, stops: [Stop], nb: Int, completion: @escaping (Bool, [Stop]) -> Void) {
    // Distances calculées une fois par arrêt, et non à chaque comparaison du tri.
    let sorted = stops
        .map { (stop: $0, distance: CLLocation(latitude: $0.wgs84Coordinates.lat, longitude: $0.wgs84Coordinates.lon).distance(from: location)) }
        .sorted { $0.distance < $1.distance }
    completion(true, sorted.prefix(nb).map(\.stop))
}

/// Les arrêts dans un carré de `radius` mètres autour de `location` : un premier tri
/// grossier, avant le calcul des distances exactes.
public func stopsInBoundingBox(from location: CLLocation, radius: Double, stops: [Stop]) -> [Stop] {
    let latOffset = radius / 111_000
    let lonOffset = radius / (111_000 * cos(location.coordinate.latitude * .pi / 180))
    let latitudes = (location.coordinate.latitude - latOffset)...(location.coordinate.latitude + latOffset)
    let longitudes = (location.coordinate.longitude - lonOffset)...(location.coordinate.longitude + lonOffset)
    return stops.filter { latitudes.contains($0.wgs84Coordinates.lat) && longitudes.contains($0.wgs84Coordinates.lon) }
}

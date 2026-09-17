//
//  LocationManager.swift
//  tpgNextFunc
//
//  Position ponctuelle et arrêts proches, partagés par l'app et la montre.
//

import Observation
import Foundation
import Combine
import CoreLocation

@Observable
public final class LocationManager: NSObject, CLLocationManagerDelegate {
    /// Créé au premier usage. Une vue qui tient un `LocationManager` dans `@State` en recrée
    /// un à chaque reconstruction et ne garde que le premier : les autres ne doivent rien coûter.
    @ObservationIgnored private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return manager
    }()
    public private(set) var userLocation: CLLocation?
    private var authorizationStatus: CLAuthorizationStatus?
    /// Rappelé à chaque demande, avec `nil` si la position n'a pas pu être obtenue.
    public var locationUpdateHandler: ((CLLocation?) -> Void)?

    /// L'autorisation de localisation. La lire crée le gestionnaire, qui la renseigne aussitôt
    /// (l'écran de bienvenue la consulte avant toute demande de position).
    public var locationStatus: CLAuthorizationStatus? {
        _ = locationManager
        return authorizationStatus
    }

    public override init() {
        super.init()
    }

    public func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// La cause du dernier échec, `nil` après une position obtenue. `.denied` : l'utilisateur
    /// doit autoriser la localisation ; autre chose : la position est introuvable pour l'instant.
    public private(set) var lastFailure: CLError.Code?

    /// Nouveaux essais sur `locationUnknown`, une erreur passagère : iOS n'a pas encore de position.
    private var retriesLeft = 0
    /// Une position est demandée en attendant la réponse à la demande d'autorisation.
    private var awaitsAuthorization = false

    public func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        locationUpdateHandler = completion
        retriesLeft = 2
        // L'autorisation vient du délégué, jamais de `locationManager.authorizationStatus` :
        // cette lecture attend la réponse du service de localisation, sur le fil principal.
        // Quand ce service ne répondait pas, l'app restait figée sur l'écran d'accueil.
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            lastFailure = .denied
            completion(nil)
        default:
            // Pas encore connue (le délégué la donne peu après la création du gestionnaire),
            // ou jamais demandée (accueil passé, app réinstallée) : `requestLocation`
            // échouerait sans rien proposer. Le délégué enchaîne dès qu'il la reçoit.
            awaitsAuthorization = true
            if authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            } else {
                _ = locationManager
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        lastFailure = nil
        #if os(iOS)
        // Repli du widget : sans autorisation « Toujours », l'extension n'a pas le droit
        // de demander la position et se rabat sur la dernière connue de l'app.
        SharedStorage.saveLastKnownLocation(location)
        #endif
        Log.location.debug("Position reçue : \(location)")
        locationUpdateHandler?(location)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        Log.location.info("Autorisation de localisation : \(manager.authorizationStatus.rawValue)")
        guard awaitsAuthorization else { return }
        guard manager.authorizationStatus != .notDetermined else {
            manager.requestWhenInUseAuthorization()
            return
        }
        awaitsAuthorization = false
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            lastFailure = .denied
            locationUpdateHandler?(nil)
        }
    }

    /// Sans ce rappel, un refus ou une absence de signal laissait l'appelant attendre
    /// indéfiniment (écran bloqué sur « Chargement... »). Une position pas encore connue
    /// (`locationUnknown`) est d'abord redemandée : l'annoncer tout de suite affichait
    /// « Position indisponible » alors qu'elle arrivait une seconde plus tard.
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown, retriesLeft > 0 {
            retriesLeft -= 1
            Log.location.debug("Position pas encore connue, nouvel essai")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.locationManager.requestLocation()
            }
            return
        }
        Log.location.error("Position indisponible : \(error.localizedDescription)")
        lastFailure = (error as? CLError)?.code ?? .locationUnknown
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

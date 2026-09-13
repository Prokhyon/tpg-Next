//
//  LocationServices.swift
//  TPG4
//
//  Created by Loris Thomas on 23.06.2024.
//

import Foundation
import CoreLocation
import Combine
import MapKit
import tpgNextFunc

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocation?
//    @Published var region = MKCoordinateRegion(
//        center:  Coordinates(lon: 6.14243773412, lat: 46.20973474672).toCLLocationCoordinate2D,
//        span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007)
//    )
    @Published var locationStatus: CLAuthorizationStatus?
    var locationUpdateHandler: ((CLLocation?) -> Void)?
//    var accuracy = CLLocationAccuracy?.self

    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    var statusString: String {
        guard let status = locationStatus else {
            return "unknown"
        }
        
        switch status {
        case .notDetermined: return "notDetermined"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        case .authorizedAlways: return "authorizedAlways"
        case .restricted: return "restricted"
        case .denied: return "denied"
        @unknown default: return "unknown"
        }
    }
    
    func requestLocationAuthorization() {
            self.locationManager.requestWhenInUseAuthorization()
        }
    
    func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        self.locationUpdateHandler = completion
        locationManager.requestLocation()
    }
    
    func startLocationUpdates() {
        self.locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.userLocation = location
        Log.location.debug("Position reçue : \(location)")
        // Stop updating location after the first update
        locationManager.stopUpdatingLocation()
        locationUpdateHandler?(location)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationStatus = status
        Log.location.info("Autorisation de localisation : \(self.statusString)")
    }

    /// Sans ce rappel, un refus ou une absence de signal laissait l'appelant attendre
    /// indéfiniment (écran bloqué sur « Chargement... »).
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.location.error("Position indisponible : \(error.localizedDescription)")
        locationUpdateHandler?(nil)
    }
}





func calculateClosestBusStops(from location: CLLocation, stops: [Stop], nb: Int, completion: @escaping (Bool, [Stop]) -> Void) {
    let sortedStops = stops.sorted(by: {
        CLLocation(latitude: $0.wgs84Coordinates.lat, longitude: $0.wgs84Coordinates.lon).distance(from: location) <
            CLLocation(latitude: $1.wgs84Coordinates.lat, longitude: $1.wgs84Coordinates.lon).distance(from: location)
    })
    
    completion(true, Array(sortedStops.prefix(nb)))
}

func stopsInBoundingBox(from location: CLLocation, radius: Double, stops: [Stop]) -> [Stop] {
    let latOffset = radius / 111_000  // Convert radius to degrees latitude
    let lonOffset = radius / (111_000 * cos(location.coordinate.latitude * .pi / 180))  // Convert radius to degrees longitude
    
    let maxLat = location.coordinate.latitude + latOffset
    let minLat = location.coordinate.latitude - latOffset
    let maxLon = location.coordinate.longitude + lonOffset
    let minLon = location.coordinate.longitude - lonOffset
    
    return stops.filter {
        $0.wgs84Coordinates.lat >= minLat &&
        $0.wgs84Coordinates.lat <= maxLat &&
        $0.wgs84Coordinates.lon >= minLon &&
        $0.wgs84Coordinates.lon <= maxLon
    }
}


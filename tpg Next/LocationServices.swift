//
//  LocationServices.swift
//  TPG4
//
//  Created by Loris Thomas on 23.06.2024.
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocation?
    @Published var locationStatus: CLAuthorizationStatus?
    var locationUpdateHandler: ((CLLocation) -> Void)?

    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
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
    
    func requestLocation() {
        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.userLocation = location
        print(#function, location)
        // Stop updating location after the first update
        locationManager.stopUpdatingLocation()
        locationUpdateHandler?(location)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationStatus = status
        print(#function, statusString)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(#function, error.localizedDescription)
    }
}





func calculateClosestBusStops(from location: CLLocation, stops: [Stop], nb: Int, completion: @escaping (Bool, [Stop]) -> Void) {
    let sortedStops = stops.sorted(by: {
        CLLocation(latitude: $0.wgs84Coordinates.lat, longitude: $0.wgs84Coordinates.lon).distance(from: location) <
            CLLocation(latitude: $1.wgs84Coordinates.lat, longitude: $1.wgs84Coordinates.lon).distance(from: location)
    })
    
    print(Array(sortedStops.prefix(nb)))
    completion(true, Array(sortedStops.prefix(nb)))
}


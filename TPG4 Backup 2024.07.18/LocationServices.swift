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
            default: return "unknown"
            }
        }
    func updateLocation() {
        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.userLocation = location
        print(#function, location)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationStatus = status
        print(#function, statusString)
    }
}





func calculateClosestBusStops(from location: CLLocation, stops: [Stop]) -> [Stop] {
    let sortedStops = stops.sorted(by: {
        CLLocation(latitude: $0.coordonnees.lat, longitude: $0.coordonnees.lon).distance(from: location) <
            CLLocation(latitude: $1.coordonnees.lat, longitude: $1.coordonnees.lon).distance(from: location)
    })
    
    return Array(sortedStops.prefix(3))
}


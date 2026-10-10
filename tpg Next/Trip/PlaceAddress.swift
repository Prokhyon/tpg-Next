//
//  PlaceAddress.swift
//  tpg Next
//
//  L'adresse d'une position : « Ma position » seul ne dit rien dans un itinéraire enregistré,
//  un rappel ou le suivi en direct.
//

import MapKit
import CoreLocation
import tpgNextFunc

enum PlaceAddress {
    /// « Rue de Carouge 12, Genève », ou `nil` (hors ligne, rien trouvé).
    static func lookUp(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if #available(iOS 26, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let item = try? await request.mapItems.first else { return nil }
            return item.address?.shortAddress ?? item.address?.fullAddress
        }
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        // En Suisse, le numéro suit la rue.
        let street = [placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.joined(separator: " ")
        let parts = [street, placemark.locality ?? ""].filter { !$0.isEmpty }
        return parts.isEmpty ? placemark.name : parts.joined(separator: ", ")
    }
}

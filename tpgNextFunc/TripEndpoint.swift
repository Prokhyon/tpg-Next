//
//  TripEndpoint.swift
//  tpgNextFunc
//
//  Le départ ou l'arrivée d'un itinéraire.
//

import CoreLocation

/// Le départ ou l'arrivée d'un itinéraire : un arrêt, ou un lieu (adresse, « Ma position »).
///
/// Remplace le trio arrêt / lieu / indicateur `geo…`, qui pouvait garder un arrêt
/// périmé à côté d'un lieu choisi ensuite.
public enum TripEndpoint: Hashable {
    case stop(Stop)
    case place(GeoPosition)

    public var name: String {
        switch self {
        case .stop(let stop): return stop.name
        case .place(let place): return place.name
        }
    }

    public var coordinates: Coordinates {
        switch self {
        case .stop(let stop): return stop.wgs84Coordinates
        case .place(let place): return place.coordinate.toCoordinates
        }
    }

    public var stop: Stop? {
        if case .stop(let stop) = self { return stop } else { return nil }
    }

    public var place: GeoPosition? {
        if case .place(let place) = self { return place } else { return nil }
    }

    /// Un lieu, envoyé à l'API par ses coordonnées plutôt que par un arrêt.
    public var isPlace: Bool { place != nil }
}

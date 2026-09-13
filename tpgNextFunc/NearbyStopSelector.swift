//
//  NearbyStopSelector.swift
//  tpgNextFunc
//
//  Created by Loris Thomas on 26.08.2026.
//

import Foundation
import CoreLocation

/// Choisit l'arrêt à afficher quand le widget est en mode automatique.
///
/// Reprend la règle de `HomeDepartures` — un favori parmi les plus proches passe
/// devant — en lui ajoutant un garde-fou : si un arrêt non-favori est à portée
/// immédiate, c'est celui-là qu'on veut, pas le favori d'en face.
public enum NearbyStopSelector {
    /// En deçà de cette distance, l'arrêt le plus proche l'emporte sur un favori voisin.
    public static let favoriteOverrideDistance: CLLocationDistance = 20

    /// Au-delà, on considère qu'il n'y a pas d'arrêt « à proximité ».
    public static let searchRadius: CLLocationDistance = 1000

    /// Le nombre d'arrêts proches parmi lesquels un favori est cherché.
    public static let candidateCount = 3

    public struct Selection {
        public let stop: Stop
        public let distance: CLLocationDistance
        public let isFavorite: Bool
    }

    /// `nil` si aucun arrêt n'est dans le rayon de recherche.
    public static func selectStop(near coordinate: CLLocationCoordinate2D,
                                  using reader: StopIndexReader,
                                  favoriteSloids: Set<String>) -> Selection? {
        let candidates = reader.nearest(to: coordinate, limit: candidateCount, maxDistance: searchRadius)
        guard let first = prioritized(candidates, favoriteSloids: favoriteSloids).first else { return nil }
        return Selection(stop: first.stop,
                         distance: first.distance,
                         isFavorite: favoriteSloids.contains(sloidHarmonizer(code: first.stop.sloid)))
    }

    /// La règle, isolée pour être partagée par l'app, la montre et le widget.
    ///
    /// Reçoit les arrêts proches triés du plus proche au plus lointain et renvoie
    /// la même liste avec l'arrêt à afficher en tête ; l'ordre des autres est conservé.
    /// - Si le plus proche est à `favoriteOverrideDistance` ou moins, rien ne bouge.
    /// - Sinon, le favori **le plus proche** passe en tête, s'il y en a un.
    public static func prioritized(_ candidates: [(stop: Stop, distance: CLLocationDistance)],
                                   favoriteSloids: Set<String>) -> [(stop: Stop, distance: CLLocationDistance)] {
        guard let closest = candidates.first,
              closest.distance > favoriteOverrideDistance,
              let index = candidates.firstIndex(where: { favoriteSloids.contains(sloidHarmonizer(code: $0.stop.sloid)) }),
              index > 0 else { return candidates }
        var reordered = candidates
        reordered.insert(reordered.remove(at: index), at: 0)
        return reordered
    }

    /// Variante pour les appelants qui ont une liste d'arrêts triée et une position,
    /// sans les distances.
    public static func prioritized(_ stops: [Stop],
                                   from location: CLLocation,
                                   favoriteSloids: Set<String>) -> [Stop] {
        let candidates = stops.map { stop in
            (stop: stop,
             distance: CLLocation(latitude: stop.wgs84Coordinates.lat,
                                  longitude: stop.wgs84Coordinates.lon).distance(from: location))
        }
        return prioritized(candidates, favoriteSloids: favoriteSloids).map(\.stop)
    }

    /// Les sloids des favoris, normalisés pour la comparaison.
    public static func favoriteSloids() -> Set<String> {
        Set(FavoritesStorage.load().map { sloidHarmonizer(code: $0.sloid) }.filter { !$0.isEmpty })
    }
}

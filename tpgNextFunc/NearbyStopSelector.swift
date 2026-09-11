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
        guard let closest = candidates.first else { return nil }

        let isFavorite = { (stop: Stop) in favoriteSloids.contains(sloidHarmonizer(code: stop.sloid)) }

        // On est pratiquement sur l'arrêt : aucun favori ne devrait le supplanter.
        if closest.distance <= favoriteOverrideDistance {
            return Selection(stop: closest.stop, distance: closest.distance, isFavorite: isFavorite(closest.stop))
        }

        if let favorite = candidates.first(where: { isFavorite($0.stop) }) {
            return Selection(stop: favorite.stop, distance: favorite.distance, isFavorite: true)
        }

        return Selection(stop: closest.stop, distance: closest.distance, isFavorite: false)
    }

    /// Les sloids des favoris, normalisés pour la comparaison.
    public static func favoriteSloids() -> Set<String> {
        Set(FavoritesStorage.load().map { sloidHarmonizer(code: $0.sloid) }.filter { !$0.isEmpty })
    }
}

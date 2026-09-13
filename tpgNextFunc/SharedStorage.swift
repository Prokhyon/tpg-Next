//
//  SharedStorage.swift
//  tpgNextFunc
//
//  Created by Loris Thomas on 26.08.2026.
//

import Foundation
import CoreLocation

/// Le pont entre l'app et l'extension widget.
///
/// Une extension ne voit ni `UserDefaults.standard` de l'app hôte ni son conteneur :
/// tout ce que le widget doit lire (favoris, dernière position connue, index des
/// arrêts, réglages d'affichage) transite par le groupe d'app.
public enum SharedStorage {
    public static let appGroupIdentifier = "group.com.loristhomas.tpgNext"

    /// Les préférences partagées.
    ///
    /// `UserDefaults(suiteName:)` réussit même sans l'entitlement — elle écrit alors
    /// dans un fichier local que personne d'autre ne lit. On vérifie donc d'abord que
    /// le conteneur du groupe existe vraiment : sans lui on retombe sur `.standard`,
    /// et l'app se comporte exactement comme avant le widget.
    public static let defaults: UserDefaults = {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil,
              let shared = UserDefaults(suiteName: appGroupIdentifier) else { return .standard }
        return shared
    }()

    /// `nil` tant que le groupe d'app n'est pas activé dans les capacités du projet.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    public static var isAvailable: Bool { containerURL != nil }

    // MARK: - Dernière position connue

    private static let latitudeKey = "widget.lastLatitude"
    private static let longitudeKey = "widget.lastLongitude"
    private static let locationDateKey = "widget.lastLocationDate"

    /// Le repli du widget quand il n'a pas le droit de demander la position lui-même.
    /// `CLLocationManager.isAuthorizedForWidgetUpdates` est faux tant que l'app n'a que
    /// l'autorisation « Pendant l'utilisation » ; sans ce repli le mode automatique
    /// n'afficherait rien dès que l'app est fermée.
    public static var lastKnownLocation: CLLocation? {
        let latitude = defaults.double(forKey: latitudeKey)
        let longitude = defaults.double(forKey: longitudeKey)
        guard latitude != 0 || longitude != 0 else { return nil }
        let timestamp = defaults.object(forKey: locationDateKey) as? Date ?? .distantPast
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: kCLLocationAccuracyHundredMeters,
            verticalAccuracy: -1,
            timestamp: timestamp
        )
    }

    public static func saveLastKnownLocation(_ location: CLLocation) {
        defaults.set(location.coordinate.latitude, forKey: latitudeKey)
        defaults.set(location.coordinate.longitude, forKey: longitudeKey)
        defaults.set(location.timestamp, forKey: locationDateKey)
    }

    // MARK: - Réglages d'affichage

    /// Les réglages que le widget doit connaître pour formater les départs comme l'app.
    private static let mirroredSettingKeys = [SettingKey.delayIncludedInTime]

    /// Recopie les réglages `@AppStorage` de l'app vers le groupe. À appeler au lancement
    /// et à chaque modification : `@AppStorage` écrit dans `.standard`, que l'extension ne voit pas.
    public static func mirrorSettings() {
        guard defaults != UserDefaults.standard else { return }
        for key in mirroredSettingKeys {
            defaults.set(UserDefaults.standard.bool(forKey: key), forKey: key)
        }
    }

    /// La valeur partagée si elle existe, sinon celle de l'app. Utilisable des deux côtés.
    public static func bool(forSetting key: String) -> Bool {
        if let shared = defaults.object(forKey: key) as? Bool { return shared }
        return UserDefaults.standard.bool(forKey: key)
    }
}

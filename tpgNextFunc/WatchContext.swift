//
//  WatchContext.swift
//  tpgNextFunc
//
//  Ce que l'iPhone envoie à la montre : favoris et prochains trajets, par le contexte applicatif.
//

import Foundation
import WatchConnectivity

/// Le contexte applicatif de la montre, tenu en un seul endroit.
///
/// `updateApplicationContext` remplace tout le dictionnaire : envoyer les trajets seuls effacerait
/// les favoris côté montre. Chaque envoi reprend donc les dernières valeurs de toutes les clés.
/// Elles sont aussi gardées tant que la session n'est pas activée : le premier envoi après
/// l'activation (`syncFavoritesToWatch` dans l'`AppDelegate`) emporte tout.
public enum WatchContext {
    /// `[Stop]` en JSON.
    public static let favoritesKey = "favoriteStops"
    /// `[UpcomingTrip]` en JSON : les prochains trajets réguliers et enregistrés.
    public static let upcomingTripsKey = "upcomingTrips"

    private static let lock = NSLock()
    nonisolated(unsafe) private static var latest: [String: Any] = [:]

    /// Enregistre la nouvelle valeur d'une clé et envoie le contexte complet s'il a changé.
    public static func update(_ key: String, with data: Data) {
        lock.lock()
        latest[key] = data
        let context = latest
        lock.unlock()
        send(context)
    }

    private static func send(_ context: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        // Les clés envoyées lors d'un lancement précédent restent, à moins d'être remplacées.
        let merged = session.applicationContext.merging(context) { _, new in new }
        guard !NSDictionary(dictionary: merged).isEqual(to: session.applicationContext) else { return }
        do {
            try session.updateApplicationContext(merged)
        } catch {
            Log.sync.error("Envoi du contexte à la montre impossible : \(error.localizedDescription)")
        }
    }
}

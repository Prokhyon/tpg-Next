//
//  SavedTripAutoTracking.swift
//  tpg Next
//
//  Le suivi en direct lancé de lui-même avant le départ d'un itinéraire enregistré, si
//  l'utilisateur l'a choisi (Paramètres). Propre à chaque appareil, comme tous les réglages.
//

import Foundation
import UserNotifications
import tpgNextFunc

enum SavedTripAutoTracking {
    /// Minutes avant le départ ; 0 : jamais.
    static let choices = [0, 15, 30, 60]
    /// Clé du `userInfo` de la notification : la toucher ouvre l'onglet Trajets.
    static let userInfoKey = "savedTripAutoTrack"
    static let prefix = "saved_track_"
    /// iOS ne garde que 64 notifications en attente pour toute l'app.
    private static let maximumReminders = 10

    static var leadMinutes: Int {
        UserDefaults.standard.integer(forKey: SettingKey.savedTripAutoTrackMinutes)
    }

    /// L'activité en direct ne peut démarrer que l'app ouverte (sans serveur de notifications).
    /// Une notification, à l'heure où le suivi doit commencer, l'ouvre donc d'un toucher ; le
    /// suivi démarre alors (`TripLiveActivities.startSoonDepartingSavedTrips`). App déjà
    /// ouverte, elle n'est pas montrée : le suivi démarre seul.
    static func scheduleReminders(for trips: [TripEvent], now: Date = Date()) {
        let minutes = leadMinutes
        var requests: [UNNotificationRequest] = []
        if minutes > 0 {
            let upcoming = trips
                .compactMap { trip in (trip.leavingDate ?? trip.startDate).map { (trip, $0) } }
                .filter { $0.1.addingTimeInterval(-TimeInterval(minutes * 60)) > now }
                .sorted { $0.1 < $1.1 }
                .prefix(maximumReminders)
            for (trip, departure) in upcoming {
                let fireDate = departure.addingTimeInterval(-TimeInterval(minutes * 60))
                let content = UNMutableNotificationContent()
                content.title = "\(trip.startName) → \(trip.endName)"
                content.body = String(localized: "Départ à \(dateToString(with: departure)). Touchez pour suivre le trajet en direct.")
                content.userInfo = [userInfoKey: trip.id]
                content.threadIdentifier = "saved_track"
                NotificationExpiry.mark(content, after: departure)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSince(now), repeats: false)
                requests.append(UNNotificationRequest(identifier: prefix + trip.id, content: content, trigger: trigger))
            }
        }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            for request in requests {
                center.add(request) { error in
                    if let error {
                        Log.notifications.error("Rappel de suivi non prévu : \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

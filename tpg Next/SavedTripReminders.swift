//
//  SavedTripReminders.swift
//  tpg Next
//
//  Le rappel avant le départ d'un itinéraire enregistré, si l'utilisateur l'a choisi
//  (Paramètres). Propre à chaque appareil : les itinéraires, eux, arrivent partout par iCloud.
//

import Foundation
import UserNotifications
import tpgNextFunc

enum SavedTripReminders {
    /// Jamais de rappel.
    static let off = -1
    /// Minutes avant l'heure de partir ; `off` : jamais.
    static let choices = [off, 0, 5, 10, 15, 30]
    /// Clé du `userInfo` : le toucher ouvre l'onglet Trajets.
    static let userInfoKey = "savedTripReminder"
    private static let prefix = "saved_reminder_"
    /// iOS ne garde que 64 notifications en attente pour toute l'app.
    private static let maximumReminders = 10

    static var leadMinutes: Int {
        UserDefaults.standard.object(forKey: SettingKey.savedTripReminderMinutes) as? Int ?? off
    }

    static func label(for minutes: Int) -> String {
        switch minutes {
        case off: String(localized: "Désactivé")
        case 0: String(localized: "À l'heure de partir")
        default: String(localized: "\(minutes) min avant")
        }
    }

    /// Repose les rappels des prochains itinéraires, à l'heure de partir (marche comprise) du
    /// temps réel s'il est connu (`displayed`), ou les retire tous si le réglage est désactivé.
    static func schedule(for trips: [TripEvent], displayed: (TripEvent) -> TripEvent = { $0 }, now: Date = Date()) {
        let minutes = leadMinutes
        var requests: [UNNotificationRequest] = []
        if minutes != off {
            let lead = TimeInterval(minutes * 60)
            let upcoming = trips
                .map { (saved: $0, trip: displayed($0)) }
                .compactMap { pair in (pair.trip.leavingDate ?? pair.trip.startDate).map { (pair.saved, pair.trip, $0) } }
                .filter { $0.2.addingTimeInterval(-lead) > now }
                .sorted { $0.2 < $1.2 }
                .prefix(maximumReminders)
            for (saved, trip, leaving) in upcoming {
                // Le suivi en direct automatique envoie déjà sa notification à ce moment-là.
                if SavedTripAutoTracking.leadMinutes == minutes && minutes > 0 { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(trip.startName) → \(trip.endName)"
                content.subtitle = TripCountdown(trip: trip)?.reminderSubtitle(minutesBefore: minutes)
                    ?? String(localized: "Départ dans \(minutes) min")
                content.body = RegularTripAlerts.description(of: RegularTripMatch(trip: trip, kind: .usual))
                content.sound = UNNotificationSound(named: UNNotificationSoundName("tpgNextNotificationSound.caf"))
                content.userInfo = [userInfoKey: saved.id]
                content.threadIdentifier = "saved_\(saved.id)"
                // Le départ passé, le rappel ne sert plus : il quitte le centre de notifications.
                NotificationExpiry.mark(content, after: (trip.vehicleLegs.first?.boardDate ?? leaving).addingTimeInterval(120))
                let fireDate = leaving.addingTimeInterval(-lead)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(fireDate.timeIntervalSince(now), 1), repeats: false)
                requests.append(UNNotificationRequest(identifier: prefix + saved.id, content: content, trigger: trigger))
            }
        }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            for request in requests {
                center.add(request) { error in
                    if let error {
                        Log.notifications.error("Rappel d'itinéraire enregistré non prévu : \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

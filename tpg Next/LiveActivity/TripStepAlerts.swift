//
//  TripStepAlerts.swift
//  tpg Next
//
//  Les alertes d'un trajet suivi : monter, descendre, arriver.
//

import Foundation
import UserNotifications
import tpgNextFunc

/// Trois moments méritent qu'on lève les yeux de son livre : le véhicule qui arrive, l'arrêt où
/// descendre, et l'arrivée.
///
/// Comme les rappels de départ, ces alertes sont posées à l'avance auprès du système : elles
/// partent même si l'app ne tourne pas. Elles sont reposées à chaque mise à jour du trajet
/// suivi, donc elles suivent les retards tant que l'app a pu relire les horaires.
enum TripStepAlerts {
    private static let prefix = "livestep_"
    /// Le véhicule arrive : une minute avant la montée.
    private static let boardingLead: TimeInterval = 60
    /// Se préparer à descendre : deux minutes avant.
    private static let alightingLead: TimeInterval = 120
    /// Le moment passé, l'alerte ne sert plus : elle quitte le centre de notifications.
    private static let stale: TimeInterval = 60

    static func schedule(key: String, title: String, state: TripActivityState, now: Date = Date()) {
        var requests: [UNNotificationRequest] = []

        for (index, leg) in state.legs.enumerated() {
            let quay = leg.boardQuay.isEmpty ? "" : String(localized: ", quai \(leg.boardQuay)")
            requests.append(contentsOf: [
                request(key: key, step: "board\(index)", at: leg.board.addingTimeInterval(-boardingLead), now: now,
                        until: leg.board.addingTimeInterval(stale),
                        title: title, subtitle: String(localized: "Montée"),
                        body: String(localized: "Le \(leg.line) arrive à \(shortStopName(leg.boardName))\(quay)")),
                request(key: key, step: "alight\(index)", at: leg.alight.addingTimeInterval(-alightingLead), now: now,
                        until: leg.alight.addingTimeInterval(stale),
                        title: title, subtitle: String(localized: "Descente"),
                        body: String(localized: "Descendez à \(shortStopName(leg.alightName))")),
            ].compactMap { $0 })
        }
        // L'arrivée, quand elle n'est pas la descente du dernier véhicule (marche finale).
        if let last = state.legs.last, state.arrival.timeIntervalSince(last.alight) > 60 {
            requests.append(contentsOf: [
                request(key: key, step: "arrival", at: state.arrival, now: now,
                        until: state.arrival.addingTimeInterval(stale),
                        title: title, subtitle: String(localized: "Arrivée"),
                        body: String(localized: "Vous arrivez à destination")),
            ].compactMap { $0 })
        }

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(prefix + key) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for request in requests {
                center.add(request) { error in
                    if let error {
                        Log.notifications.error("Alerte d'étape non prévue : \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Retire les alertes d'un trajet qui n'est plus suivi, y compris celles déjà reçues.
    static func cancel(key: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix + key) })
        }
        center.getDeliveredNotifications { delivered in
            center.removeDeliveredNotifications(
                withIdentifiers: delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix + key) })
        }
    }

    /// `nil` si le moment est déjà passé.
    private static func request(key: String, step: String, at date: Date, now: Date, until: Date,
                                title: String, subtitle: String, body: String) -> UNNotificationRequest? {
        guard date > now else { return nil }
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("tpgNextNotificationSound.caf"))
        content.userInfo = [TripStepAlerts.userInfoKey: key]
        NotificationExpiry.mark(content, after: until)
        content.threadIdentifier = key
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSince(now), 1), repeats: false)
        return UNNotificationRequest(identifier: "\(prefix)\(key)_\(step)", content: content, trigger: trigger)
    }

    /// Clé du `userInfo` : le toucher ouvre la page du trajet suivi.
    static let userInfoKey = "liveTripKey"
}

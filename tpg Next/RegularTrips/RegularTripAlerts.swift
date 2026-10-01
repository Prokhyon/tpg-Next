//
//  RegularTripAlerts.swift
//  tpg Next
//
//  Rappels avant le départ et alertes de retard des trajets réguliers.
//

import Foundation
import UIKit
import UserNotifications
import tpgNextFunc

/// Deux sortes de notifications :
/// - le **rappel**, posé des jours à l'avance à l'heure prévue : il part même si l'app n'est
///   jamais relancée, et son texte est mis à jour dès que le temps réel est connu ;
/// - l'**alerte**, envoyée quand OJP annonce un changement (retard, horaire modifié, trajet
///   habituel absent, parcours modifié, correspondance compromise). Elle dépend du temps réel,
///   donc d'un passage de l'app au premier plan ou d'un réveil en arrière-plan.
enum RegularTripAlerts {
    static let reminderPrefix = "regular_reminder_"
    private static let alertPrefix = "regular_alert_"
    /// Clé du `userInfo` : le toucher ouvre la liste des trajets réguliers.
    static let occurrenceKey = "regularTripOccurrence"
    /// Au-delà, iOS ignore les notifications en attente (64 pour toute l'app, rappels de départ compris).
    private static let maximumReminders = 30
    /// iOS ne garde que les 64 notifications en attente les plus proches, pour toute l'app.
    /// Les rappels des trajets réguliers, reposés à chaque réveil, cèdent la place aux autres
    /// (rappels d'un départ, alertes d'un trajet suivi) : quelques-unes restent de marge.
    private static let pendingLimit = 60
    /// Pas d'alerte plus tôt : le temps réel n'est pas encore fiable.
    private static let alertWindow: TimeInterval = 90 * 60
    /// Ce qui a déjà été signalé, par trajet du jour : on ne répète pas la même alerte.
    private static let notifiedStore = CodableStore<[String: String]>(key: "regularTripAlerts")

    // MARK: Cet appareil

    /// Les trajets réguliers arrivent sur tous les appareils par iCloud : sans ce réglage,
    /// l'iPhone et l'iPad préviendraient chacun. Par défaut, seul l'iPhone prévient.
    static var defaultOnThisDevice: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    /// Alertes de retard et activités en direct lancées d'elles-mêmes.
    static var isEnabledOnThisDevice: Bool {
        UserDefaults.standard.object(forKey: SettingKey.regularTripAlertsOnThisDevice) as? Bool ?? defaultOnThisDevice
    }

    /// Rappels avant le départ, au délai choisi dans chaque trajet.
    static var remindersEnabledOnThisDevice: Bool {
        UserDefaults.standard.object(forKey: SettingKey.regularTripRemindersOnThisDevice) as? Bool ?? defaultOnThisDevice
    }

    // MARK: Rappels

    /// Repose tous les rappels des sept prochains jours, ou les retire tous si cet appareil
    /// ne prévient pas.
    static func scheduleReminders(for model: RegularTripsModel, now: Date = Date()) {
        var requests: [UNNotificationRequest] = []
        for occurrence in remindersEnabledOnThisDevice ? model.upcoming(after: now) : [] {
            guard requests.count < maximumReminders,
                  let trip = model.trip(for: occurrence), let minutes = trip.reminderMinutes else { continue }
            var match: RegularTripMatch?
            if case .found(let found, _) = model.state(of: occurrence) { match = found }
            // Sans horaire fixe (bus à la demande), l'heure de partir n'existe pas.
            guard !(match?.trip ?? trip.plannedTrip(for: occurrence)).hasOnDemandLeg else { continue }
            let departure = leavingTime(occurrence: occurrence, match: match)
            let fireDate = departure.addingTimeInterval(-TimeInterval(minutes * 60))
            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = title(of: trip)
            content.subtitle = TripCountdown(trip: match?.trip ?? trip.plannedTrip(for: occurrence))?
                .reminderSubtitle(minutesBefore: minutes)
                ?? String(localized: "Départ dans \(minutes) min")
            content.body = match.map { description(of: $0) }
                ?? plannedDescription(of: trip.plannedTrip(for: occurrence))
            content.sound = UNNotificationSound(named: UNNotificationSoundName("tpgNextNotificationSound.caf"))
            content.userInfo = [occurrenceKey: occurrence.id]
            // Le départ passé, le rappel ne sert plus : il quitte le centre de notifications.
            NotificationExpiry.mark(content, after: departure.addingTimeInterval(120))
            content.threadIdentifier = trip.id.uuidString
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(fireDate.timeIntervalSince(now), 1), repeats: false)
            requests.append(UNNotificationRequest(identifier: reminderPrefix + occurrence.id, content: content, trigger: trigger))
        }

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(reminderPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            // Les plus proches d'abord : `requests` suit l'ordre des départs.
            let room = max(0, pendingLimit - (pending.count - stale.count))
            for request in requests.prefix(room) {
                center.add(request) { error in
                    if let error {
                        Log.notifications.error("Rappel de trajet régulier non prévu : \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: Alertes

    /// Prévient si le trajet du jour a changé depuis la dernière alerte.
    static func notifyChanges(of trip: RegularTrip, occurrence: RegularTripOccurrence, match: RegularTripMatch, now: Date = Date()) {
        guard trip.alertsEnabled, isEnabledOnThisDevice else { return }
        let untilDeparture = occurrence.plannedDeparture.timeIntervalSince(now)
        guard untilDeparture < alertWindow, untilDeparture > -10 * 60 else { return }

        let changes = self.changes(in: match)
        let signature = changes.joined(separator: "|")
        var notified = notifiedStore.load() ?? [:]
        let previous = notified[occurrence.id]
        // Rien de nouveau, ou tout va bien et rien n'avait été signalé.
        guard signature != (previous ?? "") else { return }
        notified[occurrence.id] = signature
        // Oublier les jours passés.
        let today = Calendar.swissTransit.dayKey(for: now)
        notifiedStore.save(notified.filter { String($0.key.suffix(10)) >= today })

        let content = UNMutableNotificationContent()
        content.title = title(of: trip)
        if changes.isEmpty {
            content.subtitle = String(localized: "Retour à la normale")
            content.body = description(of: match)
        } else {
            content.subtitle = String(localized: "Changement sur votre trajet")
            content.body = changes.joined(separator: "\n")
        }
        content.sound = UNNotificationSound(named: UNNotificationSoundName("tpgNextNotificationSound.caf"))
        content.userInfo = [occurrenceKey: occurrence.id]
        NotificationExpiry.mark(content, after: leavingTime(occurrence: occurrence, match: match).addingTimeInterval(300))
        content.threadIdentifier = trip.id.uuidString
        // Même identifiant : la nouvelle alerte remplace la précédente dans le centre de notifications.
        let request = UNNotificationRequest(identifier: alertPrefix + occurrence.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.notifications.error("Alerte de trajet régulier non envoyée : \(error.localizedDescription)")
            }
        }
    }

    /// Ce qui mérite une alerte, une phrase par changement. Vide : rien à signaler.
    static func changes(in match: RegularTripMatch) -> [String] {
        let status = match.status
        let first = match.trip.vehicleLegs.first
        let line = first?.publishedLineName ?? ""
        var changes: [String] = []
        switch match.kind {
        case .usual:
            break
        case .shifted(let minutes):
            // L'heure prévue : l'estimée bouge à chaque lecture et relancerait l'alerte.
            let time = first.flatMap { OJPDate.date(from: $0.legBoardTimetableTime) }.map(dateToString(with:)) ?? ""
            changes.append(minutes < 0
                ? String(localized: "Horaire modifié : ligne \(line) à \(time), \(-minutes) min plus tôt.")
                : String(localized: "Horaire modifié : ligne \(line) à \(time), \(minutes) min plus tard."))
        case .alternative:
            changes.append(String(localized: "Votre trajet habituel n'est pas proposé. \(plannedDescription(of: match.trip))"))
        }
        // Par tranches : un retard qui passe de 3 à 4 minutes ne mérite pas une nouvelle alerte.
        if status.departureDelay >= 3 {
            let rounded = status.departureDelay < 5 ? status.departureDelay : status.departureDelay / 5 * 5
            changes.append(String(localized: "Ligne \(line) : environ \(rounded) min de retard."))
        }
        for disrupted in status.disruptedLines {
            changes.append(String(localized: "Parcours modifié sur la ligne \(disrupted)."))
        }
        for stop in status.riskyConnections {
            changes.append(String(localized: "Correspondance compromise à \(stop)."))
        }
        return changes
    }

    // MARK: Textes

    static func title(of trip: RegularTrip) -> String { trip.displayName }

    /// « Ligne 12 à 17:59 (+3 min) depuis Genève, Rive, quai B. »
    static func description(of match: RegularTripMatch) -> String {
        guard let leg = match.trip.vehicleLegs.first else { return plannedDescription(of: match.trip) }
        let time = leg.boardDate.map(dateToString(with:)) ?? ""
        let delay = match.status.departureDelay
        let delayText = delay >= 1 ? " (+\(delay) min)" : ""
        let quay = leg.legBoardQuay.isEmpty ? "" : String(localized: ", quai \(leg.legBoardQuay)")
        return String(localized: "Ligne \(leg.publishedLineName) à \(time)\(delayText) depuis \(leg.legBoardStopName)\(quay).")
    }

    /// « Ligne 12 à 17:59 depuis Genève, Rive. », à l'heure prévue.
    static func plannedDescription(of trip: TripEvent) -> String {
        guard let leg = trip.vehicleLegs.first else { return "" }
        let time = OJPDate.date(from: leg.legBoardTimetableTime).map(dateToString(with:)) ?? ""
        return String(localized: "Ligne \(leg.publishedLineName) à \(time) depuis \(leg.legBoardStopName).")
    }

    /// L'heure de départ du trajet, marche comprise : la montée estimée, moins la marche prévue
    /// jusqu'à l'arrêt.
    private static func leavingTime(occurrence: RegularTripOccurrence, match: RegularTripMatch?) -> Date {
        match?.trip.leavingDate ?? occurrence.plannedDeparture
    }
}

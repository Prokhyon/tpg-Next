//
//  NotificationFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 09.07.2024.
//

import SwiftUI
import UserNotifications
import Combine
import Foundation
import tpgNextFunc

/// L'appui long sur un départ : un rappel (le délai se choisit dans une feuille), le suivi en
/// direct (montée ou descente ici, l'autre arrêt dans une feuille), et depuis une ligne les
/// itinéraires vers ou depuis cet arrêt.
struct NotificationContextMenu: View {
    @Environment(\.departureActions) private var departureActions
    let event: StopEvent
    let stopID: String
    var itinerary = false

    var body: some View {
        Group {
            Button {
                departureActions.remind(event, stopID)
            } label: {
                Label("Programmer un rappel…", systemImage: "bell")
            }
            if !event.journeyRef.isEmpty, TripLiveActivities.shared.areEnabled {
                let stopName = shortStopName(event.stopPointName)
                Menu {
                    Button {
                        departureActions.track(event, stopID, true)
                    } label: {
                        Label("À partir de \(stopName)", systemImage: "arrow.up.forward")
                        Text("Monter ici, descendre plus loin")
                    }
                    Button {
                        departureActions.track(event, stopID, false)
                    } label: {
                        Label("Jusqu'à \(stopName)", systemImage: "arrow.down.forward")
                        Text("Monter avant, descendre ici")
                    }
                } label: {
                    Label("Suivre en direct", systemImage: "inset.filled.circle")
                }
            }
            if itinerary {
                Divider()

                TripActionsMenu(stop: createStop(nomarret: event.stopPointName, sloid: sloidHarmonizer(code: stopID)), includesQuickTrip: false)
            }
        }
    }
}



struct NotificationInfo: Equatable {
    let id: String
    let stopID: String
    let journeyRef: String
    let notificationInterval: Double
}

func parseIdentifier(_ identifier: String) -> NotificationInfo? {
    let parts = identifier.split(separator: "_")
    guard parts.count == 3 else { return nil }
    
    let stopID = String(parts[0])
    let journeyRef = String(parts[1])
    let notificationInterval = Double(parts[2])

    
    return NotificationInfo(id: identifier, stopID: stopID, journeyRef: journeyRef, notificationInterval: notificationInterval ?? 0.0)
}

@Observable
class NotificationManager {
    var isNotificationAuthorized: Bool = false
    static let shared = NotificationManager()
    /// Clé du `StopEvent` encodé dans le `userInfo` de chaque rappel.
    static let stopEventKey = "stopEvent"
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    self.isNotificationAuthorized = granted
                }
                if let error = error {
                    Log.notifications.error("Demande d'autorisation impossible : \(error.localizedDescription)")
                }
                Log.notifications.info("Notifications \(granted ? "autorisées" : "refusées")")
            }
        }

        func checkAuthorizationStatus() {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    if settings.authorizationStatus == .authorized {
                        self.isNotificationAuthorized = true
                    } else if settings.authorizationStatus == .denied {
                        self.isNotificationAuthorized = false
                    }
                }
            }
        }
    
    func scheduleNotification(at date: Date, with message: String, identifier: String, title: (String, String), stopEvent: StopEvent) {
        let content = UNMutableNotificationContent()
        content.title = title.0
        content.subtitle = title.1
        content.body = message
        content.sound = UNNotificationSound(named: UNNotificationSoundName("tpgNextNotificationSound.caf"))
        var userInfo: [String: Any] = ["stopID": stopEvent.stopId, "stopName": stopEvent.stopPointName, "journeyRef": stopEvent.journeyRef, "estimatedTime": stopEvent.estimatedTime]
        // Le départ complet, pour reconstruire la liste des rappels prévus après une relance de l'app.
        if let encoded = try? JSONEncoder().encode(stopEvent) {
            userInfo[Self.stopEventKey] = encoded
        }
        content.userInfo = userInfo
        
        let timeInterval = date.timeIntervalSinceNow
        guard timeInterval > 0 else {
            Log.notifications.debug("Heure du rappel dépassée, rien à prévoir")
            return
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(timeInterval, 1), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.notifications.error("Rappel non enregistré : \(error.localizedDescription)")
            } else {
                Log.notifications.debug("Rappel prévu pour \(date)")
            }
        }
    }

    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }
}


@Observable
class BusNotificationManager {
    static let shared = BusNotificationManager()
    
    var scheduledNotificationIdentifiers: [String:StopEvent] = [:]
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    let notificationManager = NotificationManager.shared

    // Schedule notifications based on both timetabledTime and estimatedTime
    func scheduleNotifications(for stopEvent: StopEvent, lineEvent: LineEvent?, stopID: String, notificationInterval: Double, completionHandler: @escaping (Bool) -> ()) {
        

        let timetableDate = dateFromString(lineEvent?.timetabledTime ?? stopEvent.timetabledTime)
        let estimatedDate = dateFromString(lineEvent?.estimatedTime ?? stopEvent.estimatedTime)
        
        guard let timetableDate = timetableDate else {
            Log.notifications.error("Heure de départ illisible, rappel non prévu")
            return completionHandler(false)
        }

        let timetableNotificationTime = timetableDate.addingTimeInterval(-notificationInterval * 60)
        let estimatedNotificationTime = estimatedDate?.addingTimeInterval(-notificationInterval * 60) ?? timetableNotificationTime
        
        let delay = estimatedDate?.timeIntervalSince(timetableDate) ?? 0.0
        let estimatedIdentifier = "estimated_\(stopID)_\(stopEvent.journeyRef)_\(notificationInterval)"
        let timetableIdentifier = "timetable_\(stopID)_\(stopEvent.journeyRef)_\(notificationInterval)"
        
        // Cancel any previous notifications for the same stopEvent and delay
        cancelScheduledNotifications(timetableIdentifier: timetableIdentifier, estimatedIdentifier: estimatedIdentifier, completeCancel: false)
        
        // Schedule notifications
        scheduleNotification(at: timetableNotificationTime, for: stopEvent, delay: delay, identifier: timetableIdentifier, isTimetabled: true, notificationInterval: notificationInterval)
        scheduleNotification(at: estimatedNotificationTime, for: stopEvent, delay: delay, identifier: estimatedIdentifier, isTimetabled: false, notificationInterval: notificationInterval)
        // Le recalage sur le temps réel se fait à chaque réveil de l'app (`refreshPending`).
        let departure = estimatedDate ?? timetableDate
        if departure > Date() {
            nextReminderDeparture = min(nextReminderDeparture ?? departure, departure)
        }
        completionHandler(true)
    }

    // Cancel notifications for a given stopEvent and delay
    func cancelScheduledNotifications(timetableIdentifier: String, estimatedIdentifier: String, completeCancel: Bool) {
        notificationManager.cancelNotification(identifier: timetableIdentifier)
        notificationManager.cancelNotification(identifier: estimatedIdentifier)
        if completeCancel {
            scheduledNotificationIdentifiers.removeValue(forKey: String(estimatedIdentifier.dropFirst(10)))
        }
    }

    /// Les rappels relus à l'instant, par clé : au plus une requête par minute près du départ.
    @ObservationIgnored private var lastCheck: [String: Date] = [:]

    /// Recale les rappels en attente sur la dernière heure estimée.
    ///
    /// Appelé à chaque réveil de l'app (premier plan chaque minute, tâche de fond, suivi en
    /// direct), avec les trajets réguliers : une vérification tenue seulement en mémoire
    /// s'arrêtait dès qu'iOS suspendait l'app. Un rappel dont la notification estimée est déjà
    /// partie n'est plus relu : reposé, il sonnerait une seconde fois.
    @MainActor
    func refreshPending(now: Date = Date()) async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        var reminders: [String: (event: StopEvent, stopID: String, interval: Double)] = [:]
        for request in pending where request.identifier.hasPrefix("estimated_") || request.identifier.hasPrefix("timetable_") {
            let key = String(request.identifier.dropFirst(10))
            guard reminders[key] == nil,
                  let data = request.content.userInfo[NotificationManager.stopEventKey] as? Data,
                  let event = try? JSONDecoder().decode(StopEvent.self, from: data),
                  let info = parseIdentifier(key) else { continue }
            reminders[key] = (event, info.stopID, info.notificationInterval)
        }
        lastCheck = lastCheck.filter { reminders[$0.key] != nil }
        nextReminderDeparture = reminders.values
            .compactMap { dateFromString($0.event.estimatedTime) ?? dateFromString($0.event.timetabledTime) }
            .filter { $0 > now }
            .min()
        for (key, reminder) in reminders {
            guard let departure = dateFromString(reminder.event.estimatedTime) ?? dateFromString(reminder.event.timetabledTime) else { continue }
            let untilDeparture = departure.timeIntervalSince(now)
            // Avant, le temps réel est vide ; ensuite, une relecture par minute tout près du départ.
            guard untilDeparture < RegularTripsModel.liveWindow else { continue }
            let interval: TimeInterval = untilDeparture < 30 * 60 ? 60 : 5 * 60
            if let last = lastCheck[key], now.timeIntervalSince(last) < interval { continue }
            lastCheck[key] = now
            guard let estimated = await estimatedTime(of: reminder.event, at: reminder.stopID),
                  estimated != reminder.event.estimatedTime else { continue }
            Log.notifications.info("Heure estimée modifiée, rappels recalés")
            var updated = reminder.event
            updated.estimatedTime = estimated
            scheduleNotifications(for: updated, lineEvent: nil, stopID: reminder.stopID,
                                  notificationInterval: reminder.interval) { _ in }
        }
    }

    /// L'heure estimée du passage à cet arrêt, relue dans la course (`OJPTripInfoRequest`).
    private func estimatedTime(of stopEvent: StopEvent, at stopID: String) async -> String? {
        let data: Data? = await withCheckedContinuation { continuation in
            fetchTransportJourney(with: stopEvent) { continuation.resume(returning: $0) }
        }
        guard let data else { return nil }
        let stopSloid = sloidHarmonizer(code: stopID)
        let candidates = parseJourneyEventsSync(from: data).events
            .filter { $0.stopPlaceRef == stopID || sloidHarmonizer(code: $0.sloid) == stopSloid }
        // Une ligne peut passer deux fois au même arrêt : l'heure théorique départage.
        let event = candidates.first { $0.timetabledTime == stopEvent.timetabledTime } ?? candidates.first
        guard let estimated = event?.estimatedTime, !estimated.isEmpty else { return nil }
        return estimated
    }

    /// Le prochain départ qui a un rappel : la tâche de fond doit se réveiller avant. Tenu à
    /// jour à la pose et à chaque relecture.
    @ObservationIgnored private(set) var nextReminderDeparture: Date?

    /// Reconstruit la liste des rappels prévus à partir de ceux que le système garde en attente.
    ///
    /// Tenue seulement en mémoire, la liste était vide après chaque relance et gardait les
    /// rappels déjà passés. Un rappel créé avant l'ajout du départ dans `userInfo` n'y figure
    /// que s'il a été prévu pendant la session en cours.
    func refreshScheduledNotifications() {
        notificationManager.getPendingNotifications { [self] requests in
            var scheduled: [String: StopEvent] = [:]
            for request in requests {
                let key = String(request.identifier.dropFirst(10))
                if let data = request.content.userInfo[NotificationManager.stopEventKey] as? Data,
                   let stopEvent = try? JSONDecoder().decode(StopEvent.self, from: data) {
                    scheduled[key] = stopEvent
                } else if let known = scheduledNotificationIdentifiers[key] {
                    scheduled[key] = known
                }
            }
            scheduledNotificationIdentifiers = scheduled
        }
    }
    
    private func scheduleNotification(at date: Date, for stopEvent: StopEvent, delay: Double, identifier: String, isTimetabled: Bool, notificationInterval: Double) {
        let message: String
        let title = splitString(stopEvent.stopPointName, separator: ",")
        let transportType = stopEvent.transportType.lowercased()
        let transport = "\(startsWithVowel(transportType) ? "L'" : "Le") \(transportType) \(stopEvent.lineName)" // à destination de \(stopEvent.destination)
        if (delay > 60) {
            let intDelay = max(1, Int(abs(delay) / 60))
            if notificationInterval == 0.0 {
                let delayMessage = String(localized: "avec \(intDelay) minutes de retard.")
                if isTimetabled {
                    message = String(localized: "\(transport) aurait dû arriver mais arrivera \(delayMessage)")
                } else {
                    message = String(localized: "\(transport) devrait arriver à l'arrêt")
                }
            } else {
                let intNotificationInterval = Int(notificationInterval)
                if isTimetabled {
                    let delayMessage = String(localized: "avec \(intDelay) minutes de retard.")
                    message = String(localized: "\(transport) devait arriver dans \(intNotificationInterval) minutes mais arrivera \(delayMessage)")
                } else {
                    message = String(localized: "\(transport) est estimé dans \(intNotificationInterval) minutes à l'arrêt")
                }
            }
        } else if (delay < -60) {
            // En avance : seule l'heure estimée compte, l'heure prévue serait trop tard.
            if !isTimetabled {
                let intDelay = max(1, Int(abs(delay) / 60))
                let intNotificationInterval = Int(notificationInterval)
                let delayMessage = String(localized: "avec \(intDelay) minutes d'avance")
                if notificationInterval == 0.0 {
                    message = String(localized: "\(transport) devrait arriver à l'arrêt \(delayMessage)")
                } else {
                    message = String(localized: "\(transport) est estimé dans \(intNotificationInterval) minutes à l'arrêt \(delayMessage)")
                }
            } else {
                return
            }
        } else {
            if isTimetabled {
                let intNotificationInterval = Int(notificationInterval)
                if notificationInterval == 0.0 {
                    message = String(localized: "\(transport) devrait arriver à l'arrêt")
                } else {
                    message = String(localized: "\(transport) est dans \(intNotificationInterval) minutes à l'arrêt")
                }
            } else {
                return
            }
        }
        notificationManager.scheduleNotification(at: date, with: message, identifier: identifier, title: title, stopEvent: stopEvent)
        scheduledNotificationIdentifiers[String(identifier.dropFirst(10))] = stopEvent
    }

    private func dateFromString(_ dateString: String) -> Date? {
        OJPDate.date(from: dateString)
    }
}

@Observable
class NotificationConfirmationViewModel {
    static let shared = NotificationConfirmationViewModel()
    
    
    var showConfirmation: Bool = false
    var confirmationMessage: String = ""
    var errorMessage: Bool = false
    
    @ObservationIgnored private var generation = 0

    func show(message: String, error: Bool) {
        confirmationMessage = message
        errorMessage = error
        withAnimation(.bouncy(duration: 0.5)) {
            showConfirmation = true
        }
        generation += 1
        let shown = generation

        // Masqué après 3 s, sauf si un autre message l'a remplacé entre-temps.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            guard shown == self.generation else { return }
            withAnimation(.bouncy(duration: 0.5)) {
                self.showConfirmation = false
                self.errorMessage = false
            }
        }
    }
}

/// Une notification dont le moment est passé n'a plus rien à dire. iOS ne sait pas la retirer
/// seul : l'app fait le ménage dès qu'elle tourne — au premier plan chaque minute, et à chaque
/// réveil en arrière-plan. Une notification reçue pendant que l'app était éteinte reste donc
/// jusqu'à sa prochaine ouverture.
enum NotificationExpiry {
    /// Dans le `userInfo` : le moment après lequel la notification ne sert plus à rien.
    static let key = "clearAfter"

    static func mark(_ content: UNMutableNotificationContent, after date: Date) {
        content.userInfo[key] = date.timeIntervalSince1970
    }

    /// Retire du centre de notifications celles dont le moment est passé.
    static func clearExpired(now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
            let stale = delivered.filter {
                guard let limit = $0.request.content.userInfo[key] as? TimeInterval else { return false }
                return limit <= now.timeIntervalSince1970
            }.map(\.request.identifier)
            guard !stale.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: stale)
        }
    }
}

/// L'écran à ouvrir après un toucher sur un rappel. Au lancement à froid, l'AppDelegate reçoit
/// la réponse avant que `ContentView` n'écoute : une `Notification` postée était perdue.
@Observable
final class PendingNotificationOpen {
    static let shared = PendingNotificationOpen()
    var route: AppRoute?
}

#Preview("Menu des rappels") {
    // Toucher longuement le départ pour ouvrir le menu.
    let event = PreviewData.departure(inMinutes: 12)
    StopEventView(event: event, showTime: false)
        .contextMenu {
            NotificationContextMenu(event: event, stopID: PreviewData.rive.sloid)
        }
        .previewEnvironment()
}

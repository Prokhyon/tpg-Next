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

struct NotificationContextMenu: View {
    @Environment(ItineraryViewModel.self) var tripModel
    @Environment(NavigationModel.self) var navigationModel
    let transportNotificationManager = BusNotificationManager.shared
    let notificationConfirmationViewModel = NotificationConfirmationViewModel.shared
    let event: StopEvent
    let stopID: String
//    var path: ViewStateStack
    var itinerary = false
    
    var body: some View {
        Group {
            ForEach([0.0, 1.0, 5.0, 10.0, 30.0], id: \.self) { notificationInterval in
                Button(action: {
                    if transportNotificationManager.notificationManager.isNotificationAuthorized {
                        transportNotificationManager.scheduleNotifications(for: event, lineEvent: nil, stopID: stopID, notificationInterval: notificationInterval) { success in
                            if success {
                                let intNotificationInterval = Int(notificationInterval)
                                if notificationInterval == 0.0 {
                                    notificationConfirmationViewModel.show(message: String(localized:"Rappel à l'arrivée prévu avec succès"), error: false)
                                } else {
                                    notificationConfirmationViewModel.show(message: String(localized:"Rappel \(intNotificationInterval)' avant prévu avec succès"), error: false)
                                }
                            } else {
                                notificationConfirmationViewModel.show(message: String(localized:"Erreur: Le rappel n'a pas pu être prévu"), error: true)
                            }
                        }
                    } else {
                        notificationConfirmationViewModel.show(message: String(localized:"Les notifications n'ont pas été autorisées pour tpg Next.\nChangez-le dans les paramètres du téléphone"), error: true)
                    }
                }) {
                    Text(notificationLabel(for: notificationInterval))
                }
            }
            if itinerary {
                Divider()
                
                TripActionsMenu(stop: createStop(nomarret: event.stopPointName, sloid: sloidHarmonizer(code: stopID)), includesQuickTrip: false)
            }
        }
    }
    
    private func notificationLabel(for notificationInterval: Double) -> String {
        switch notificationInterval {
        case 0.0:
            return String(localized:"Prévenir à l'arrivée")
        case 1.0:
            return String(localized:"Prévenir 1' avant")
        case 5.0:
            return String(localized:"Prévenir 5' avant")
        case 10.0:
            return String(localized:"Prévenir 10' avant")
        case 30.0:
            return String(localized:"Prévenir 30' avant")
        default:
            return ""
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
        
        // Schedule update check
        scheduleUpdateCheck(at: estimatedDate ?? timetableDate, stopEvent: stopEvent, stopID: stopID, notificationInterval: notificationInterval)
        
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

    // Update logic: Reschedule notifications if estimatedTime changes
    func scheduleUpdateCheck(at estimatedDate: Date, stopEvent: StopEvent, stopID: String, notificationInterval: Double) {
        let now = Date()
        let halfInterval = (estimatedDate.timeIntervalSince(now)) / 2
        let nextCheckTime = now.addingTimeInterval(halfInterval)
        
        if halfInterval > 60 { // Only schedule if more than 1 minute to check
            Log.notifications.debug("Vérification du retard prévue à \(nextCheckTime)")
            DispatchQueue.main.asyncAfter(deadline: .now() + halfInterval) {
                self.updateNotifications(for: stopEvent, stopID: stopID, notificationInterval: notificationInterval)
            }
        }
    }

    /// Recale les rappels sur la dernière heure estimée.
    ///
    /// La course est redemandée à l'API et lue une fois la réponse arrivée : l'ancienne
    /// version lisait le résultat avant la réponse, et ne recalait donc jamais rien.
    /// Tant que l'heure ne bouge pas, une nouvelle vérification est prévue à mi-chemin.
    /// Ne fonctionne que tant que l'app reste en mémoire.
    func updateNotifications(for stopEvent: StopEvent, stopID: String, notificationInterval: Double) {
        let lineManager = LineManager()
        lineManager.selectJourney(stopEvent) { [self] in
            let stopSloid = sloidHarmonizer(code: stopID)
            let candidates = lineManager.lineEvents.filter { $0.stopPlaceRef == stopID || $0.sloid == stopSloid }
            // Une ligne peut passer deux fois au même arrêt : l'heure théorique départage.
            guard let updatedEvent = candidates.first(where: { $0.timetabledTime == stopEvent.timetabledTime }) ?? candidates.first else {
                Log.notifications.info("Arrêt introuvable dans la course, rappel laissé tel quel")
                return
            }
            guard !updatedEvent.estimatedTime.isEmpty, updatedEvent.estimatedTime != stopEvent.estimatedTime else {
                scheduleUpdateCheck(at: dateFromString(stopEvent.estimatedTime) ?? Date(), stopEvent: stopEvent, stopID: stopID, notificationInterval: notificationInterval)
                return
            }
            Log.notifications.info("Heure estimée modifiée, rappels recalés")
            var updatedStopEvent = stopEvent
            updatedStopEvent.estimatedTime = updatedEvent.estimatedTime
            scheduleNotifications(for: updatedStopEvent, lineEvent: nil, stopID: stopID, notificationInterval: notificationInterval) { _ in }
        }
    }

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
                    message = String(localized: "\(transport) aurait du arriver mais arrivera \(delayMessage)")
                } else {
                    message = String(localized: "\(transport) devrait arriver à l'arrêt")
                }
            } else {
                let intNotificationInterval = Int(notificationInterval)
                if isTimetabled {
                    let delayMessage = String(format: "avec \(intDelay) minutes de retard.")
                    message = String(localized: "\(transport) devait arriver dans \(intNotificationInterval) minutes mais arrivera \(delayMessage)")
                } else {
                    message = String(localized: "\(transport) est estimé dans \(intNotificationInterval) minutes à l'arrêt")
                }
            }
        } else if (delay < 0) {
            if isTimetabled {
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

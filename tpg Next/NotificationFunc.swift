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
    @EnvironmentObject var tripModel: ItineraryViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    let transportNotificationManager = BusNotificationManager.shared
    let notificationConfirmationViewModel = NotificationConfirmationViewModel.shared
    let event: StopEvent
    let stopID: String
//    @ObservedObject var path: ViewStateStack
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
                
                Button(action: {
                    tripModel.outerTrip(tab: navigationModel, isDeparture: true, stop: createStop(nomarret: event.stopPointName, sloid: sloidHarmonizer(code: stopID)), isQuickTrip: false)
                }) {
                    Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                }
                Button(action: {
                    tripModel.outerTrip(tab: navigationModel, isDeparture: false, stop: createStop(nomarret: event.stopPointName, sloid: sloidHarmonizer(code: stopID)), isQuickTrip: false)
                }) {
                    Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                }
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



func splitNotificationIdentifier(_ input: String) -> (String, String, String, String, String, Double) {
    let parts = input.split(separator: "_")
    
    guard parts.count == 6 else {
        return (input, "", "", "", "", 0)
    }
    
    let type = parts[0].trimmingCharacters(in: .whitespaces)
    let stopId = parts[1].trimmingCharacters(in: .whitespaces)
    let lineName = parts[2].trimmingCharacters(in: .whitespaces)
    let destination = parts[3].trimmingCharacters(in: .whitespaces)
    let time = parts[4].trimmingCharacters(in: .whitespaces)
    let notificationInterval = Double(parts[5]) ?? 0
    
    print(type, stopId, lineName, destination, time, notificationInterval)
    return (type, stopId, lineName, destination, time, notificationInterval)
}

struct NotificationInfo: Equatable {
    let id: String
    let stopID: String
    let journeyRef: String
    let notificationInterval: Double
}

func parseIdentifier(_ identifier: String) -> NotificationInfo? {
    print("parsing: \(identifier)")
    let parts = identifier.split(separator: "_")
    guard parts.count == 3 else { print("parsing error"); return nil }
    
    let stopID = String(parts[0])
    let journeyRef = String(parts[1])
    let notificationInterval = Double(parts[2])
    print("stopID: \(stopID), journeyRef: \(journeyRef), notificationInterval: \(notificationInterval?.description ?? "nil")")

    
    return NotificationInfo(id: identifier, stopID: stopID, journeyRef: journeyRef, notificationInterval: notificationInterval ?? 0.0)
}

func timeSplitter(_ input: String) -> (String, String, String) {
    let parts = input.split(separator: ";")
    
    guard parts.count == 3 else {
        return (input, "", "")
    }
    
    let timetableTime = parts[0].trimmingCharacters(in: .whitespaces)
    let delay = parts[1].trimmingCharacters(in: .whitespaces)
    let estimatedTime = parts[2].trimmingCharacters(in: .whitespaces)
    
    return (timetableTime, delay, estimatedTime)
}

class NotificationManager {
    @Published var isNotificationAuthorized: Bool = false
    static let shared = NotificationManager()
    
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
                    print("Notification authorization request failed: \(error.localizedDescription)")
                }
                if granted {
                    print("Notification authorization granted.")
                } else {
                    print("Notification authorization denied.")
                }
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
        content.userInfo = ["stopID": stopEvent.stopId, "stopName": stopEvent.stopPointName, "journeyRef": stopEvent.journeyRef, "estimatedTime": stopEvent.estimatedTime]
        
        let timeInterval = date.timeIntervalSinceNow
        guard timeInterval > 0 else {
            print("Notification time has already passed. Not scheduling.")
            return
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(timeInterval, 1), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for \(date) with message: \(message)")
            }
        }
    }

    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled notification with identifier: \(identifier)")
    }
    
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }
}


class BusNotificationManager: ObservableObject {
    static let shared = BusNotificationManager()
    
    @Published var scheduledNotificationIdentifiers: [String:StopEvent] = [:]
    private var cancellables = Set<AnyCancellable>()
    let notificationManager = NotificationManager.shared

    // Schedule notifications based on both timetabledTime and estimatedTime
    func scheduleNotifications(for stopEvent: StopEvent, lineEvent: LineEvent?, stopID: String, notificationInterval: Double, completionHandler: @escaping (Bool) -> ()) {
        print("Scheduling notifications for stopEvent: \(stopEvent.lineName), stopPoint: \(stopEvent.stopPointName)")
        

        let timetableDate = dateFromString(lineEvent?.timetabledTime ?? stopEvent.timetabledTime)
        let estimatedDate = dateFromString(lineEvent?.estimatedTime ?? stopEvent.estimatedTime)
        
        guard let timetableDate = timetableDate else {
            print("Invalid timetable date.")
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
            print("Scheduling update check at \(nextCheckTime)")
            DispatchQueue.main.asyncAfter(deadline: .now() + halfInterval) {
                self.updateNotifications(for: stopEvent, stopID: stopID, notificationInterval: notificationInterval)
            }
        }
    }

    // Handle updates
    func updateNotifications(for stopEvent: StopEvent, stopID: String, notificationInterval: Double) {
        let lineManager = LineManager()
        lineManager.selectJourney(stopEvent)
        
        guard let updatedEvent = lineManager.LineEvents.first(where: { $0.sloid == stopID || $0.stopPlaceRef == stopID }) else {
                print("No relevant updates found for stopEvent.")
                return
            }

            if updatedEvent.estimatedTime != stopEvent.estimatedTime {
                print("Estimated time has changed. Rescheduling notifications.")
                self.scheduleNotifications(for: stopEvent, lineEvent: updatedEvent, stopID: stopID, notificationInterval: notificationInterval) { success in
                    
                }
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
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.date(from: dateString)
    }
}

class NotificationConfirmationViewModel: ObservableObject {
    static let shared = NotificationConfirmationViewModel()
    
    
    @Published var showConfirmation: Bool = false
    @Published var confirmationMessage: String = ""
    @Published var errorMessage: Bool = false
    
    func show(message: String, error: Bool) {
        confirmationMessage = message
        errorMessage = error
        withAnimation(.bouncy(duration: 0.5)) {
            showConfirmation = true
        }
        print("confirmationShow, \(showConfirmation)")
        
        // Automatically hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.bouncy(duration: 0.5)) {
                self.showConfirmation = false
                self.errorMessage = false
            }
        }
    }
}

extension Notification.Name {
    static let didReceiveNotification = Notification.Name("didReceiveNotification")
}

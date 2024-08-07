//
//  NotificationFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 09.07.2024.
//

import SwiftUI
import UserNotifications
import Combine

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() { }
        
    func scheduleNotification(at date: Date, with message: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Bus Arrival"
        content.body = message
        content.sound = UNNotificationSound.default
        
        let timeInterval = date.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(timeInterval, 1), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        print("Scheduling notification with identifier: \(identifier), message: \(message) at \(date) with timeInterval: \(timeInterval)")

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled successfully for date: \(date) with message: \(message)")
            }
        }
    }

    func cancelNotification(with identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("Cancelled notification with identifier: \(identifier)")
    }
}


var cancellables = Set<AnyCancellable>()

func scheduleBusNotifications(for stopEvent: StopEvent, stopID: String, timeDelay: Double, lineManager: LineManager) {
    print("scheduleBusNotifications called for: \(stopEvent.lineName), stopID: \(stopID)")
    let notificationManager = NotificationManager.shared

    var scheduledNotificationIdentifiers: [String] = []

    func stringToDate(with string: String) -> Date? {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.date(from: string)
    }

    func cancelScheduledNotifications() {
        for identifier in scheduledNotificationIdentifiers {
            notificationManager.cancelNotification(with: identifier)
        }
        scheduledNotificationIdentifiers.removeAll()
    }

    func scheduleNotification(at date: Date, with message: String, identifier: String) {
        notificationManager.scheduleNotification(at: date, with: message, identifier: identifier)
        scheduledNotificationIdentifiers.append(identifier)
    }

    func scheduleUpdateCheck(at time: Date) {
        let now = Date()
        let timeInterval = time.timeIntervalSince(now)
        if timeInterval > 60 { // Only schedule if more than 1 minute
            let halfInterval = timeInterval / 2
            let checkTime = now.addingTimeInterval(halfInterval)
            print("Scheduling next check at \(checkTime)")
            DispatchQueue.main.asyncAfter(deadline: .now() + halfInterval) {
                updateNotifications()
            }
        }
    }

    func updateNotifications() {
        guard let relevantEvent = lineManager.LineEvents.first(where: { event in
            let isMatch = event.stopPlaceRef == stopID // Adjust comparison as needed
            print("Comparing event.stopPointName: \(event.stopPointName) with stopPointName: \(stopEvent.stopPointName) - Match: \(isMatch)")
            return isMatch
        }) else {
            print("No relevant event found for stopPointName: \(stopEvent.stopPointName)")
            return
        }

        print("Relevant event found: \(relevantEvent)")

        let stringTimetableTime = relevantEvent.timetabledTime
        let stringEstimatedTime = relevantEvent.estimatedTime.isEmpty ? relevantEvent.timetabledTime : relevantEvent.estimatedTime

        guard let timetableTime = stringToDate(with: stringTimetableTime),
              let estimatedTime = stringToDate(with: stringEstimatedTime) else {
            print("Error converting string to date: timetableTime = \(stringTimetableTime), estimatedTime = \(stringEstimatedTime)")
            return
        }

        print("Timetable time: \(timetableTime), Estimated time: \(estimatedTime)")

        // Cancel previously scheduled notifications before scheduling new ones
        cancelScheduledNotifications()

        let estimatedNotificationTime = estimatedTime.addingTimeInterval(-timeDelay * 60)
        let estimatedNotificationIdentifier = "estimated_\(stopID)_\(stopEvent.lineName)"

        let timetableNotificationTime = timetableTime.addingTimeInterval(-timeDelay * 60)
        let timetableNotificationIdentifier = "timetable_\(stopID)_\(stopEvent.lineName)"
        let delay = estimatedTime.timeIntervalSince(timetableTime)
        
        if (delay > 0) {
            if timeDelay == 0.0 {
                let delayMessage = String(format: "avec %d minutes de retard.", Int(delay / 60))
                scheduleNotification(at: timetableNotificationTime, with: "Le \(stopEvent.transportType.lowercased()) \(stopEvent.lineName) à destination de \(stopEvent.destination) aurait du arriver mais arrivera \(delayMessage)", identifier: timetableNotificationIdentifier)
                scheduleNotification(at: estimatedNotificationTime, with: "Le \(stopEvent.transportType.lowercased()) \(stopEvent.lineName) à destination de \(stopEvent.destination) devrait arriver à l'arrêt \(stopEvent.stopPointName)", identifier: estimatedNotificationIdentifier)
            } else {
                let delayMessage = String(format: "avec %d minutes de retard.", Int(delay / 60))
                scheduleNotification(at: timetableNotificationTime, with: "Le \(stopEvent.transportType.lowercased()) \(stopEvent.lineName) à destination de \(stopEvent.destination) devait arriver dans \(Int(timeDelay)) minutes mais arrivera \(delayMessage)", identifier: timetableNotificationIdentifier)
                scheduleNotification(at: estimatedNotificationTime, with: "Le \(stopEvent.transportType.lowercased()) \(stopEvent.lineName) à destination de \(stopEvent.destination) est estimé dans \(Int(timeDelay)) minutes à l'arrêt \(stopEvent.stopPointName)", identifier: estimatedNotificationIdentifier)
            }
        } else if (delay < 0) {
            if timeDelay == 0.0 {
                scheduleNotification(at: estimatedNotificationTime, with: "Le \(stopEvent.transportType.lowercased()) \(stopEvent.lineName) à destination de \(stopEvent.destination) devrait arriver à l'arrêt \(stopEvent.stopPointName) avec \(Int(delay / 60)) minutes d'avance", identifier: estimatedNotificationIdentifier)
            } else {
                scheduleNotification(at: estimatedNotificationTime, with: "Le \(stopEvent.transportType.lowercased()) \(stopEvent.lineName) à destination de \(stopEvent.destination) est estimé dans \(Int(timeDelay)) minutes à l'arrêt \(stopEvent.stopPointName) avec \(Int(delay / 60)) minutes d'avance", identifier: estimatedNotificationIdentifier)
            }
        } else {
            if timeDelay == 0.0 {
                scheduleNotification(at: timetableNotificationTime, with: "Le \(stopEvent.transportType.lowercased()) \(stopEvent.lineName) à destination de \(stopEvent.destination) devrait arriver à l'arrêt \(stopEvent.stopPointName)", identifier: timetableNotificationIdentifier)
            } else {
                scheduleNotification(at: timetableNotificationTime, with: "Le \(stopEvent.transportType.lowercased()) \(stopEvent.lineName) à destination de \(stopEvent.destination) est dans \(Int(timeDelay)) minutes à l'arrêt \(stopEvent.stopPointName)", identifier: timetableNotificationIdentifier)
            }
        }
            
        // Schedule next update check
        scheduleUpdateCheck(at: estimatedNotificationTime)
    }

    // Call selectJourney to initiate data fetching and update LineEvents
    lineManager.selectJourney(stopEvent) {
        // Call updateNotifications after LineEvents are updated
        updateNotifications()
    }
}
//func scheduleBusNotifications(for stopEvent: StopEvent, stopID: String, lineManager: LineManager) {
//    print("scheduleBusNotifications called for: \(stopEvent.lineName), stopID: \(stopID)")
//    let notificationManager = NotificationManager.shared
//
//    func updateNotifications() {
//        guard let relevantEvent = lineManager.LineEvents.first(where: { event in
//            let isMatch = event.stopPointName == stopEvent.stopPointName // Adjust comparison as needed
//            print("Comparing event.stopPointName: \(event.stopPointName) with stopPointName: \(stopEvent.stopPointName) - Match: \(isMatch)")
//            return isMatch
//        }) else {
//            print("No relevant event found for stopPointName: \(stopEvent.stopPointName)")
//            return
//        }
//
//        print("Relevant event found: \(relevantEvent)")
//
//        let stringTimetableTime = relevantEvent.timetabledTime
//        let stringEstimatedTime = relevantEvent.estimatedTime.isEmpty ? relevantEvent.timetabledTime : relevantEvent.estimatedTime
//
//        guard let timetableTime = stringToDate(with: stringTimetableTime),
//              let estimatedTime = stringToDate(with: stringEstimatedTime) else {
//            print("Error converting string to date: timetableTime = \(stringTimetableTime), estimatedTime = \(stringEstimatedTime)")
//            return
//        }
//
//        print("Timetable time: \(timetableTime), Estimated time: \(estimatedTime)")
//
//        let estimatedNotificationTime = estimatedTime.addingTimeInterval(-5 * 60)
//        notificationManager.scheduleNotification(at: estimatedNotificationTime, with: "Bus is arriving in 5 minutes (estimated).")
//
//        let timetableNotificationTime = timetableTime.addingTimeInterval(-5 * 60)
//        let delay = estimatedTime.timeIntervalSince(timetableTime)
//        if delay > 0 {
//            let delayMessage = String(format: "The bus is %d minutes late.", Int(delay / 60))
//            notificationManager.scheduleNotification(at: timetableNotificationTime, with: "Bus was scheduled to arrive in 5 minutes. \(delayMessage)")
//            print("Bus was scheduled to arrive in 5 minutes. \(delayMessage)")
//        } else {
//            notificationManager.scheduleNotification(at: timetableNotificationTime, with: "Bus is scheduled to arrive in 5 minutes.")
//            print("Bus is scheduled to arrive in 5 minutes.")
//        }
//    }
//
//    // Call selectJourney to initiate data fetching and update LineEvents
//    lineManager.selectJourney(stopEvent) {
//        // Call updateNotifications after LineEvents are updated
//        updateNotifications()
//    }
//}




//func arrivalWarning(stopEvent: StopEvent, stop: Stop) {
//    var lineManager = LineManager()
//    var timer: AnyCancellable?
////        lineManager.selectJourney(stopEvent)
//        timer = Timer.publish(every: 30, on: .main, in: .common)
//            .autoconnect()
//            .sink { _ in
//                lineManager.selectJourney(stopEvent)
//            }
////        timer?.cancel()
//}
func schNotification() {
    let center = UNUserNotificationCenter.current()

    let content = UNMutableNotificationContent()
    content.title = "Hello!"
    content.body = "This is a notification from your app."
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

    center.add(request) { error in
        if let error = error {
            print("Error scheduling notification: \(error.localizedDescription)")
        }
    }
}



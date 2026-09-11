//
//  TPG4App.swift
//  TPG4
//
//  Created by Loris Thomas on 17.06.2024.
//

import SwiftUI
import Foundation
import Combine
import tpgNextFunc
import WatchConnectivity
import WidgetKit
//import SwissPassClient

let isTesting: Bool = {
    #if DEBUG
    return true
    #else
    return false
    #endif
}()

@main
struct TPG4App: App {
    @StateObject private var stopStore = StopStore()
    // Doit être l'instance partagée : l'AppDelegate passe par FavoritesViewModel.shared
    // pour la synchronisation avec la montre.
    @StateObject private var favoritesViewModel = FavoritesViewModel.shared
    @StateObject private var appRequirementsClass = AppRequirementsClass()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @SwiftUICore.Environment(\.scenePhase) var scenePhase
    
    init() {
        if #available(iOS 26, *) {
        } else {
            UINavigationBar.setTransparentAppearance()
        }
    }

    /// Alimente l'extension widget : elle ne peut ni charger la base des arrêts
    /// (6 Mo de JSON pour ~30 Mo de mémoire disponible) ni lire les réglages de l'app.
    private func prepareWidgetData() {
        SharedStorage.mirrorSettings()
        let stops = stopStore.activeStops
        Task.detached(priority: .utility) {
            if StopIndex.ensureIndex(for: stops) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
//            StoryboardView()
            ContentView()
                .environmentObject(stopStore)
                .environmentObject(favoritesViewModel)
                .environmentObject(appRequirementsClass)
                .task {
                    // Relie les favoris à la base : les noms suivent alors la base
                    // au lieu de rester figés sur l'instantané enregistré.
                    favoritesViewModel.attach(stopStore: stopStore)
                    prepareWidgetData()
                }
                .background (
                    Gradient(colors: [.accent, .color1, .color1]).opacity(0.7)
                )
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, WCSessionDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self  // Set the delegate
        
        // Initialize WCSession
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        return true
    }

    // MARK: - WCSessionDelegate Methods

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
            // La session peut s'activer après attach(stopStore:) : on repousse ici,
            // sinon le contexte du lancement serait perdu.
            if activationState == .activated {
                DispatchQueue.main.async {
                    FavoritesViewModel.shared.syncFavoritesToWatch()
                }
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate the session if needed
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Handle incoming messages from the watch
        if message["requestSync"] as? Bool == true {
                    FavoritesViewModel.shared.syncFavoritesToWatch()
                }
        if let data = message["favoriteStops"] as? Data {
            do {
                let favorites = try JSONDecoder().decode([Stop].self, from: data)
                DispatchQueue.main.async {
                    // Update your shared FavoritesViewModel or other storage
                    FavoritesViewModel.shared.replaceAll(with: favorites)
                }
            } catch {
                print("Failed to decode favoriteStops: \(error)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            // Extract information from the notification
            let userInfo = response.notification.request.content.userInfo
            if let stopID = userInfo["stopID"] as? String,
               let stopName = userInfo["stopName"] as? String,
               let journeyRef = userInfo["journeyRef"] as? String,
               let estimatedTime = userInfo["estimatedTime"] as? String {
                // Post a notification to SwiftUI to handle navigation
                NotificationCenter.default.post(
                    name: .didReceiveNotification,
                    object: nil,
                    userInfo: ["stopID": stopID, "stopName": stopName, "journeyRef": journeyRef, "estimatedTime": estimatedTime]
                )
            }
            completionHandler()
        }
    
    // MARK: - App Lifecycle Methods

    func applicationWillResignActive(_ application: UIApplication) {
        print("Application will resign active.")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("Application entered background.")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("Application will enter foreground.")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("Application became active.")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("Application will terminate.")
    }
}

extension UINavigationBar {
    static func setTransparentAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.backgroundEffect = nil
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        
        print("UINavigationBar.transparentAppearance Set")
    }
}

class AppRequirementsClass: ObservableObject {
    @Published var version26: Bool

    init() {
        // Par exemple, active la fonctionnalité pour iOS 17 et plus (iOS 26 quand disponible)
        if #available(iOS 26, *) {
            self.version26 = true
        } else {
            self.version26 = false
        }
    }
}

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

@main
struct TPG4App: App {
    @State private var stopStore = StopStore()
    // Doit être l'instance partagée : l'AppDelegate passe par FavoritesViewModel.shared
    // pour la synchronisation avec la montre.
    @State private var favoritesViewModel = FavoritesViewModel.shared
    @State private var appRequirementsClass = AppRequirementsClass()
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
                .tickingClock()
                .environment(stopStore)
                .environment(favoritesViewModel)
                .environment(appRequirementsClass)
                .task {
                    // La base se charge en arrière-plan : on l'attend avant de s'en servir.
                    await stopStore.waitUntilLoaded()
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
            Log.sync.error("Activation de WCSession impossible : \(error.localizedDescription)")
        } else {
            Log.sync.debug("WCSession activée, état \(activationState.rawValue)")
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
                Log.sync.error("Favoris reçus de la montre illisibles : \(error.localizedDescription)")
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
        
    }
}

@Observable
class AppRequirementsClass {
    var version26: Bool

    init() {
        // Par exemple, active la fonctionnalité pour iOS 17 et plus (iOS 26 quand disponible)
        if #available(iOS 26, *) {
            self.version26 = true
        } else {
            self.version26 = false
        }
    }
}

//
//  TPG4App.swift
//  TPG4
//
//  Created by Loris Thomas on 17.06.2024.
//

import SwiftUI
import Foundation
import Combine

@main
struct TPG4App: App {
    @StateObject private var stopStore = StopStore()
    @StateObject private var favoritesViewModel = FavoritesViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
//            let stopStore = StopStore()
//            _stopStore = StateObject(wrappedValue: stopStore)
//            _favoritesViewModel = StateObject(wrappedValue: FavoritesViewModel(stopStore: stopStore))
            UINavigationBar.setTransparentAppearance()
        }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(stopStore) 
                .environmentObject(favoritesViewModel)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self  // Set the delegate
        requestNotificationAuthorization()
        return true
    }

    private func requestNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization request failed with error: \(error.localizedDescription)")
            }

            if granted {
                print("Notification authorization granted.")
            } else {
                print("Notification authorization denied.")
            }
        }
    }

    // Handle notifications when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])  // Use .banner instead of .alert
    }
}
//struct AppTabBarView_Previews: PreviewProvider {
//    static var previews: some View {
//        let stopStore = StopStore()
//        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)
//
//        return AppTabBarView()
//            .environmentObject(stopStore)
//            .environmentObject(favoritesViewModel)
//    }
//}

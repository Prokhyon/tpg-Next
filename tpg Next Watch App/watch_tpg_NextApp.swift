//
//  watch_tpg_NextApp.swift
//  watch tpg Next Watch App
//
//  Created by Loris Thomas on 30.12.2024.
//

import SwiftUI
import tpgNextFunc
import WatchConnectivity
import Combine

@main
struct watch_tpg_Next_Watch_AppApp: App {
    @StateObject private var stopStore = StopStore()
    @StateObject private var watchFavorites = WatchFavoritesViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .accentColor(Color.primary)
                .environmentObject(stopStore)
                .environmentObject(watchFavorites)
//            TestWatchView()
        }
    }
}

class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate {
    
    func applicationDidFinishLaunching() {
        setupWCSession()
    }
    
    func applicationDidBecomeActive() {
        requestSyncFromPhone()
    }
    
    private func setupWCSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    private func requestSyncFromPhone() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["requestSync": true], replyHandler: nil) { error in
            print("Failed to request sync: \(error)")
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            requestSyncFromPhone()
        }
    }
}


class WatchFavoritesViewModel: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchFavoritesViewModel()
    
    @Published var favoriteStops: [Stop] = [] {
        didSet {
            saveFavorites()
        }
    }
    
    private let userDefaultsKey = "favoriteStops"
    
    override init() {
        super.init()
        setupWCSession()
        loadFavorites()
    }
    
    private func setupWCSession() {
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["favoriteStops"] as? Data else { return }
        
        do {
            let stops = try JSONDecoder().decode([Stop].self, from: data)
            DispatchQueue.main.async {
                self.favoriteStops = stops
                self.saveFavorites()
            }
        } catch {
            print("Decoding error: \(error)")
        }
    }
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteStops)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Error encoding favorite stops: \(error)")
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let stops = try JSONDecoder().decode([Stop].self, from: data)
                self.favoriteStops = stops
            } catch {
                print("Error decoding favorite stops: \(error)")
            }
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}

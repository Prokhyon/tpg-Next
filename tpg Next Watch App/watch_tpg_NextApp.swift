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
    
    private static let store = CodableStore<[Stop]>(key: "favoriteStops")
    
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
    
    /// Chemin principal : l'iPhone pousse les favoris via le contexte applicatif,
    /// livré même si l'app montre n'était pas lancée au moment de la modification.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyFavorites(from: applicationContext)
    }

    /// Conservé pour rester compatible avec une version de l'app iPhone
    /// qui pousse encore les favoris par sendMessage.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyFavorites(from: message)
    }

    private func applyFavorites(from payload: [String: Any]) {
        guard let data = payload["favoriteStops"] as? Data else { return }

        do {
            let stops = try JSONDecoder().decode([Stop].self, from: data)
            DispatchQueue.main.async {
                self.favoriteStops = stops // le didSet enregistre
            }
        } catch {
            Log.sync.error("Favoris reçus illisibles : \(error.localizedDescription)")
        }
    }
    
    private func saveFavorites() {
        Self.store.save(favoriteStops)
    }

    private func loadFavorites() {
        if let stops = Self.store.load() {
            favoriteStops = stops
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        // Un contexte poussé pendant que l'app montre était éteinte attend déjà ici.
        applyFavorites(from: session.receivedApplicationContext)
    }
}

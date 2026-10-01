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
import WidgetKit

@main
struct watch_tpg_Next_Watch_AppApp: App {
    @State private var stopStore = StopStore(publishesNames: true)
    @State private var watchTrips: WatchTripsModel
    @State private var watchFavorites: WatchFavoritesViewModel

    init() {
        let trips = WatchTripsModel()
        _watchTrips = State(initialValue: trips)
        _watchFavorites = State(initialValue: WatchFavoritesViewModel(trips: trips))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tickingClock()
                .accentColor(Color.primary)
                .environment(stopStore)
                .environment(watchFavorites)
                .environment(watchTrips)
                .task { await prepareWidgetData() }
        }
    }

    /// Les complications ne peuvent pas charger la base des arrêts (6 Mo de JSON) : elles lisent
    /// l'index binaire que l'app écrit dans le groupe d'app, comme le widget de l'iPhone.
    private func prepareWidgetData() async {
        await stopStore.waitUntilLoaded()
        let stops = stopStore.activeStops
        await Task.detached(priority: .utility) {
            if StopIndex.ensureIndex(for: stops) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }.value
    }
}


/// Les favoris reçus de l'iPhone. Délégué unique de la session : il transmet aussi les
/// prochains trajets à `WatchTripsModel` (un second délégué volerait la réception).
@Observable
class WatchFavoritesViewModel: NSObject, WCSessionDelegate {
    var favoriteStops: [Stop] = [] {
        didSet {
            saveFavorites()
        }
    }
    
    private static let store = CodableStore<[Stop]>(key: "favoriteStops")
    @ObservationIgnored private let trips: WatchTripsModel?

    init(trips: WatchTripsModel? = nil) {
        self.trips = trips
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
        applyContext(applicationContext)
    }

    /// Le contexte contient toujours toutes les clés (`WatchContext`) : chacune n'est appliquée
    /// que si elle a changé.
    private func applyContext(_ context: [String: Any]) {
        applyFavorites(from: context)
        trips?.apply(from: context)
    }

    /// Conservé pour rester compatible avec une version de l'app iPhone
    /// qui pousse encore les favoris par sendMessage.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyFavorites(from: message)
    }

    private func applyFavorites(from payload: [String: Any]) {
        guard let data = payload[WatchContext.favoritesKey] as? Data else { return }

        do {
            let stops = try JSONDecoder().decode([Stop].self, from: data)
            DispatchQueue.main.async {
                // Sans changement, rien à enregistrer ni de complication à recharger.
                guard stops != self.favoriteStops else { return }
                self.favoriteStops = stops // le didSet enregistre
            }
        } catch {
            Log.sync.error("Favoris reçus illisibles : \(error.localizedDescription)")
        }
    }
    
    /// Les favoris tels que la base de la montre les connaît : l'iPhone envoie des arrêts complets,
    /// mais le sloid seul fait foi (nom à jour). Un arrêt absent de la base garde la copie reçue.
    func resolvedFavorites(in stopStore: StopStore) -> [Stop] {
        favoriteStops.map { stopStore.findStop(id: $0.sloid) ?? $0 }
    }

    private func saveFavorites() {
        Self.store.save(favoriteStops)
        // Les complications choisissent leur arrêt parmi les favoris et en proposent quelques-uns.
        FavoritesStorage.save(favoriteStops.map(FavoriteStop.init(stop:)))
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.invalidateConfigurationRecommendations()
    }

    private func loadFavorites() {
        if let stops = Self.store.load() {
            favoriteStops = stops
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        // Un contexte poussé pendant que l'app montre était éteinte attend déjà ici.
        applyContext(session.receivedApplicationContext)
    }
}

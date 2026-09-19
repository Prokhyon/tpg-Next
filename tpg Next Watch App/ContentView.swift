//
//  ContentView.swift
//  watch tpg Next Watch App
//
//  Created by Loris Thomas on 30.12.2024.
//

import SwiftUI
import tpgNextFunc

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(StopStore.self) var stopStore
    @Environment(WatchFavoritesViewModel.self) var watchFavorites
    @State var locationManager = LocationManager()
    @State private var closestStops: [Stop] = []
    @State var closeStop: Stop? = nil
    @State var viewCloseStops = false
    @State var selected: Stop? = nil
    @State var autoRefresh = true
    @State var viewLineSorted = true
    @State private var showTime = false
    
    var body: some View {
        ZStack {
            NavigationSplitView() {
                List(selection: $selected) {
                    if !viewCloseStops {
                        Button(action: {
                            viewCloseStops.toggle()
                        }) {
                            HStack {
                                Image(systemName: "location.magnifyingglass")
                                Text("Autres arrêts proches")
                            }
                            .foregroundStyle(.black)
                        }
                        .listRowPlatterColor(.primary)
                    }
                    if viewCloseStops {
                        ForEach(closestStops) { stop in
                            NavigationLink(value: stop) {
                                HStack {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 5)
                                        .background(
                                            Circle()
                                                .fill(.black)
                                        )
                                        .frame(width: 20, height: 20)
                                    SmallStopTitleView(stopName: stop.name)
                                    Image(systemName: "location.fill")
                                }
                            }
                        }
                    } else if closeStop != nil {
                        NavigationLink(value: closeStop) {
                            HStack {
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: 5)
                                    .background(
                                        Circle()
                                            .fill(.black)
                                    )
                                    .frame(width: 20, height: 20)
                                SmallStopTitleView(stopName: closeStop!.name)
                                Image(systemName: "location.fill")
                            }
                        }
                    }
                    ForEach(watchFavorites.favoriteStops, id: \.self) { favorite in
                        if (!viewCloseStops && favorite.name != closeStop?.name) || (viewCloseStops && !closestStops.contains(favorite)) {
                            NavigationLink(value: favorite) {
                                HStack {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 5)
                                        .background(
                                            Circle()
                                                .fill(.black)
                                        )
                                        .frame(width: 20, height: 20)
                                    SmallStopTitleView(stopName: favorite.name)
                                }
                            }
                        }
                    }
                }
                .listStyle(.carousel)
                .onAppear {
                    viewCloseStops = false
                    getLocation(withSelection: false)
                }
                
            } detail: {
                if let selected = selected {
                        StopView(stopName: selected.name, stopSloid: selected.sloid, isCloseStop: closestStops.contains(selected), showTime: $showTime, viewLineSorted: $viewLineSorted, autoRefresh: $autoRefresh)
                } else {
                    Text("Sélectionnez un arrêt")
                }
            }
        }
        .onAppear {
            getLocation(withSelection: true)
        }
        .onChange(of: stopStore.isLoaded) {
            getLocation(withSelection: true)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                getLocation(withSelection: true)
            }
        }
    }
    private func getLocation(withSelection: Bool) {
        // La base se charge en arrière-plan : `onChange(of: stopStore.isLoaded)` relance la recherche.
        guard stopStore.isLoaded else { return }
        locationManager.requestLocation { location in
            if let userLocation = location ?? locationManager.userLocation {
                let stopList = stopStore.activeStops
                let radiusList = stopsInBoundingBox(from: userLocation, radius: 1000, stops: stopList)
                calculateClosestBusStops(from: userLocation, stops: radiusList, nb: 3) { success, stops in
                    DispatchQueue.main.async {
                        closestStops = stops
                        // Même règle que l'iPhone et le widget. La comparaison se fait par
                        // sloid : l'égalité complète de `Stop` échoue dès qu'un champ secondaire
                        // diffère entre la copie synchronisée depuis l'iPhone et la base locale.
                        let favoriteSloids = Set(watchFavorites.favoriteStops.map { sloidHarmonizer(code: $0.sloid) })
                        closeStop = NearbyStopSelector.prioritized(stops, from: userLocation, favoriteSloids: favoriteSloids).first
                        if withSelection {
                            selected = closeStop
                        }
                    }
                }
                stopStore.location = userLocation
            } else {
                Log.location.error("Position indisponible")
            }
            locationManager.locationUpdateHandler = nil
        }
    }
}

#Preview("Montre") {
    ContentView(closeStop: WatchPreviewData.rive, autoRefresh: false)
        .watchPreviewEnvironment()
}

#Preview("Montre — sans favori") {
    ContentView(closeStop: WatchPreviewData.rive, autoRefresh: false)
        .watchPreviewEnvironment(favorites: [])
}

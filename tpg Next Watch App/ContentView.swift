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
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var watchFavorites: WatchFavoritesViewModel
    @StateObject var locationManager = LocationManager()
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
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                getLocation(withSelection: true)
            }
        }
    }
    private func getLocation(withSelection: Bool) {
        locationManager.requestLocation { location in
            if let userLocation = locationManager.userLocation {
                let stopList = stopStore.activeStops
                let radiusList = stopsInBoundingBox(from: userLocation, radius: 1000, stops: stopList)
                print(radiusList)
                calculateClosestBusStops(from: userLocation, stops: radiusList, nb: 3) { success, stops in
                    DispatchQueue.main.async {
                        closestStops = stops
                        
                        for stop in stops {
                            if watchFavorites.favoriteStops.contains(stop) {
                                closeStop = stop
                                if withSelection {
                                    selected = stop
                                }
                                return
                            }
                        }
                            closeStop = closestStops.first
                        if withSelection {
                            selected = closeStop
                        }
                    }
                }
                stopStore.location = userLocation
            } else {
                print("Location error")
            }
            locationManager.locationUpdateHandler = nil
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var stopStore = StopStore()
        @StateObject var watchFavorites = WatchFavoritesViewModel()
        @State var autoRefresh: Bool = false
        @State var viewLineSorted: Bool = true
        @State var showTime: Bool = false
        let stop = Stop(name: "Genève, Rive", sloid: "ch:1:sloid:93006", codedidoc: "8593006", country: "CH", canton: "GE", meansOfTransport: "bus", wgs84Coordinates: Coordinates(lon: 46.2167, lat: 6.1667))
        
        return ContentView(closeStop: stop, autoRefresh: false)
            .environmentObject(stopStore)
            .environmentObject(watchFavorites)
    }
}

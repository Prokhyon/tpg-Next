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
    @Environment(WatchTripsModel.self) private var watchTrips
    @Environment(\.displayTime) private var now
    @State var locationManager = LocationManager()
    @State private var closestStops: [Stop] = []
    @State var closeStop: Stop? = nil
    @State private var showsMoreNearby = false
    @State private var locationUnavailable = false
    @State private var path: [WatchRoute] = []
    /// Au lancement et au retour de l'arrière-plan, la montre ouvre l'arrêt le plus proche dès
    /// que la position est connue.
    @State private var opensNearestStop = true

    private var favorites: [Stop] {
        watchFavorites.resolvedFavorites(in: stopStore)
    }

    private var favoriteSloids: Set<String> {
        Set(favorites.map { sloidHarmonizer(code: $0.sloid) })
    }

    /// L'arrêt le plus proche, ou les trois plus proches une fois la liste dépliée.
    private var nearbyStops: [Stop] {
        showsMoreNearby ? closestStops : closeStop.map { [$0] } ?? []
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                let trips = watchTrips.upcoming(at: now)
                if !trips.isEmpty {
                    Section("Mes trajets") {
                        ForEach(trips) { trip in
                            NavigationLink(value: WatchRoute.trip(trip)) { UpcomingTripRow(trip: trip) }
                        }
                    }
                }
                Section("À proximité") {
                    if nearbyStops.isEmpty {
                        locationStatus
                    }
                    ForEach(nearbyStops) { stop in
                        stopLink(stop, isNearby: true)
                    }
                    if !showsMoreNearby && closestStops.count > 1 {
                        Button {
                            withAnimation { showsMoreNearby = true }
                        } label: {
                            Label("Autres arrêts proches", systemImage: "location.magnifyingglass")
                        }
                    }
                }
                Section("Favoris") {
                    // Un favori déjà affiché à proximité n'est pas répété.
                    let shown = Set(nearbyStops.map { sloidHarmonizer(code: $0.sloid) })
                    ForEach(favorites.filter { !shown.contains(sloidHarmonizer(code: $0.sloid)) }) { stop in
                        stopLink(stop, isNearby: false)
                    }
                    if favorites.isEmpty {
                        Text("Ajoutez des favoris dans l'app iPhone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("tpg Next")
            .navigationDestination(for: WatchRoute.self) { $0.destination }
            .onAppear {
                getLocation()
            }
        }
        .onOpenURL(perform: open)
        .onChange(of: stopStore.isLoaded) {
            getLocation()
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .background:
                opensNearestStop = true
                showsMoreNearby = false
            case .active:
                getLocation()
            default:
                break
            }
        }
    }

    private func stopLink(_ stop: Stop, isNearby: Bool) -> some View {
        NavigationLink(value: WatchRoute.stop(name: stop.name, sloid: stop.sloid, isNearby: isNearby)) {
            StopRow(name: stop.name, isNearby: isNearby,
                    isFavorite: isNearby && favoriteSloids.contains(sloidHarmonizer(code: stop.sloid)))
        }
    }

    @ViewBuilder private var locationStatus: some View {
        if locationUnavailable {
            Label("Position indisponible", systemImage: "location.slash")
                .foregroundStyle(.secondary)
        } else {
            HStack {
                ProgressView()
                    .frame(width: 24)
                Text("Recherche des arrêts…")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func getLocation() {
        // La base se charge en arrière-plan : `onChange(of: stopStore.isLoaded)` relance la recherche.
        guard stopStore.isLoaded else { return }
        locationManager.requestLocation { location in
            if let userLocation = location ?? locationManager.userLocation {
                let stopList = stopStore.activeStops
                let radiusList = stopsInBoundingBox(from: userLocation, radius: 1000, stops: stopList)
                calculateClosestBusStops(from: userLocation, stops: radiusList, nb: 3) { success, stops in
                    DispatchQueue.main.async {
                        locationUnavailable = false
                        closestStops = stops
                        // Même règle que l'iPhone et le widget. La comparaison se fait par
                        // sloid : l'égalité complète de `Stop` échoue dès qu'un champ secondaire
                        // diffère entre la copie synchronisée depuis l'iPhone et la base locale.
                        closeStop = NearbyStopSelector.prioritized(stops, from: userLocation, favoriteSloids: favoriteSloids).first
                        openNearestStopIfNeeded()
                    }
                }
                stopStore.location = userLocation
                // Le repli des complications, qui n'ont pas toujours le droit de demander la position.
                SharedStorage.saveLastKnownLocation(userLocation)
            } else {
                Log.location.error("Position indisponible")
                locationUnavailable = true
            }
            locationManager.locationUpdateHandler = nil
        }
    }

    /// `tpgnext://stop?sloid=…&name=…`, envoyé par une complication : ouvre cet arrêt, à la place
    /// du plus proche.
    private func open(_ url: URL) {
        guard url.scheme == "tpgnext", url.host == "stop",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let sloid = items.first(where: { $0.name == "sloid" })?.value else { return }
        let name = items.first(where: { $0.name == "name" })?.value ?? stopStore.findStop(id: sloid)?.name ?? ""
        opensNearestStop = false
        path = [.stop(name: name, sloid: sloid, isNearby: sloidHarmonizer(code: sloid) == closeStop.map { sloidHarmonizer(code: $0.sloid) })]
    }

    /// Ouvre l'arrêt le plus proche, sauf s'il est déjà à la base de la pile : une course
    /// ouverte depuis lui reste affichée.
    private func openNearestStopIfNeeded() {
        guard opensNearestStop, let closeStop else { return }
        opensNearestStop = false
        let route = WatchRoute.stop(name: closeStop.name, sloid: closeStop.sloid, isNearby: true)
        if path.first != route {
            path = [route]
        }
    }
}

/// Un arrêt dans la liste de l'accueil.
struct StopRow: View {
    let name: String
    var isNearby = false
    var isFavorite = false

    var body: some View {
        HStack {
            StopDot()
            SmallStopTitleView(stopName: name)
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favori")
            }
            if isNearby {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .accessibilityLabel("À proximité")
            }
        }
    }
}

#Preview("Montre") {
    ContentView(closeStop: WatchPreviewData.rive)
        .watchPreviewEnvironment()
}

#Preview("Montre — sans favori") {
    ContentView(closeStop: WatchPreviewData.rive)
        .watchPreviewEnvironment(favorites: [])
}

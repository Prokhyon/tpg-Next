//
//  SearchView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import Foundation
import SwiftUI
import MapKit
import tpgNextFunc

struct SearchView: View {
    @Environment(\.displayTime) private var now
    //    var path: ViewStateStack
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(ItineraryViewModel.self) var tripViewModel
    @Environment(NavigationModel.self) var navigationModel
    @Environment(RecentSearch.self) var recentSearchModel
    @State var locationManager = LocationManager()
    @Environment(SavedTripsModel.self) var savedTripsModel
    
    @State private var resultDetail: searchResultItem?
    @State private var activeFutureTrip: TripEvent?
    //    @State private var recentSearchDestination: RecentSearchItem?
    @Environment(\.openRoute) private var openRoute
    @State private var stopResults: [Stop] = []
    @State private var showTripDetail = false
    
    @FocusState private var isFocused: Bool
    
    @AppStorage(SettingKey.homeShowsFavorites) var homeFavorites = false
    
    //    var futureTrips: [TripEvent] = []
    var futureTrips: [TripEvent] {
        savedTripsModel.savedTrips.sortedByStart().filter { trip in
            !hasPassed(trip.startDate, includingCurrentMinute: false, now: now)
        }
    }
    
    var body: some View {
//        let searchView = VStack {}
        let searchView = ZStack {
            VStack(alignment: .leading, spacing: 0) {
            if navigationModel.searchQuery.isEmpty {
                ScrollView {
                    if !recentSearchModel.searchItems.isEmpty {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Recherches récentes")
                                    .font(.title2).bold()
                                //                            .padding(.top)
                                Spacer()
                            }
                            .padding(.horizontal)
                            ForEach(recentSearchModel.searchItems, id: \.self) { item in
                                if item.isStop {
                                    if let stop = item.stop {
                                        Button(action: {
                                            recentSearchModel.add(name: item.name, isStop: true, stop: stop, geoCoordinates: item.geoCoordinates)
                                            openRoute(.stop(stop))
                                        }) {
                                                BasicLocationView(name: item.name, transportType: stop.meansOfTransport, isFavorite: favoritesViewModel.isFavorite(stop), showButton: true, showFavorite: true, buttonAction: {
                                                    resultDetail = searchResultItem(title: item.name, coordinates: CLLocationCoordinate2D(latitude: stop.wgs84Coordinates.lat, longitude: stop.wgs84Coordinates.lon))
                                                }, favoriteAction: {toggleFavorite(stop: stop)})
                                        }
                                        .foregroundStyle(.primary)
                                        .padding(5)
                                        .contentShape(.contextMenuPreview, Capsule())
                                        .contextMenu {
                                            TripActionsMenu(stop: stop)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    if !futureTrips.isEmpty {
                        HStack {
                            Text("Prochains itinéraires")
                                .font(.title2).bold()
                                .padding(.top)
                            Spacer()
                        }
                        .padding(.horizontal)
                        HStack {
                            Text(formatDate(activeFutureTrip?.startDate))
                                .font(.headline)
                            //                                .padding(.top)
                            Spacer()
                        }
                        .padding(.horizontal)
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(futureTrips, id: \.self) { trip in
                                        //                            if !hasPassed(trip.startDate, includingCurrentMinute: false, now: now) {
                                        NavigationLink(value: AppRoute.trip(trip)) {
                                            VStack {
                                                SavedTripView(event: trip)
                                                //                                                    .frame(width: geometry.size.width)
                                                    .padding(15)
                                            }
                                            .background(
                                                BasicCard(cornerRadius: 30)
                                            )
                                        }
                                        //                                        .frame(width: geometry.size.width-10)
                                        .padding(5)
                                        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 35))
                                        .contextMenu {
                                            Button(action: {
                                                savedTripsModel.removeTrip(trip)
                                            }) {
                                                Label("Ne plus enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.minus")
                                            }
                                        }
                                        //                                        .padding(15)
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 10)
                                        .foregroundStyle(.primary)
                                        //                            }
                                    }
                                    .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                                }
                            }
                            .scrollTargetLayout()
                            .scrollTargetBehavior(.viewAligned)
                            .scrollPosition(id: $activeFutureTrip)
//                            .mask {
//                                Rectangle()
//                                    .overlay(alignment: .top) {
//                                        ScrollMask(leading: false, vertical: true, gradientLength: 10)
//                                    }
//                            }
//                            .mask {
//                                Rectangle()
//                                    .overlay(alignment: .bottom) {
//                                        ScrollMask(leading: true, vertical: true, gradientLength: 10)
//                                    }
//                            }
                            //                            .padding(.vertical)
                            //                            .scrollTargetBehavior(.paging)
                            .onAppear {
                                activeFutureTrip = futureTrips.first
                            }
                    }
                }
                .readableScrollContent()
            } else {
                if stopResults.isEmpty {
                    Text("Aucun résultat pour « \(navigationModel.searchQuery) »")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(stopResults) { stop in
                                Button(action: {
                                    recentSearchModel.add(name: stop.name, isStop: true, stop: stop, geoCoordinates: nil)
                                    openRoute(.stop(stop))
                                }) {
                                    BasicLocationView(name: stop.name, transportType: stop.meansOfTransport, isFavorite: favoritesViewModel.isFavorite(stop), showButton: true, showFavorite: true, buttonAction: {
                                        resultDetail = searchResultItem(title: stop.name, coordinates: CLLocationCoordinate2D(latitude: stop.wgs84Coordinates.lat, longitude: stop.wgs84Coordinates.lon))
                                    }, favoriteAction: {toggleFavorite(stop: stop)})
                                }
                                .foregroundStyle(.primary)
                                .padding(5)
                                .contentShape(.contextMenuPreview, Capsule())
                                .contextMenu {
                                    TripActionsMenu(stop: stop)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .contentMargins(.bottom, 40, for: .automatic)
                    .readableScrollContent()
                }
            }
            }
            VStack {
                BackdropBlurView(radius: 5)
                    .frame(height: 70)
                    .mask {
                        Rectangle()
                            .overlay(alignment: .top) {
                                ScrollMask(leading: true, vertical: true, gradientLength: 70)
                            }
                    }
                    .ignoresSafeArea()
            Spacer()
            }
        }
            .navigationTitle("Explorer") // Set back button text
        //            .navigationBarTitleDisplayMode(.inline)
        //            .toolbar {
        //                ToolbarItem(placement: .principal) {
        //                    Text("") // Visible title
        //                }
        //            }
            .scrollDismissesKeyboard(.immediately)
            .searchingStops(navigationModel.searchQuery, results: $stopResults)
        
        
            .onAppear {
                isFocused = true
                if homeFavorites {
                    locationManager.requestLocation { location in
                        if let userLocation = locationManager.userLocation {
                            stopStore.location = userLocation
                        } else {
                            Log.location.error("Position indisponible")
                        }
                        locationManager.locationUpdateHandler = nil
                    }
                }
            }
                .sheet(item: $resultDetail) { detail in
                    MapPreview(resultDetail: detail, position: .region(MKCoordinateRegion(center: detail.coordinates, span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007))))
                        .presentationDetents([.medium, .fraction(0.9)])
                        .presentationCornerRadius(35)
                }
                                   //            .navigationDestination(isPresented: $showTripDetail) {
                                   //                if let stop = selectedSearchResult {
                                   //                    StopView(stopName: stop.title, stopSloid: stop.stop.sloid)
                                   ////                        .environment(savedTripsModel)
                                   //                }
                                   //            }
               
        if #available(iOS 26, *) {
            searchView
                .searchable(text: Bindable(navigationModel).searchQuery)
        } else {
            searchView
        }
    }

    private func toggleFavorite(stop: Stop) {
        if favoritesViewModel.isFavorite(stop) {
            favoritesViewModel.removeFavoriteStop(stop)
        } else {
            favoritesViewModel.addFavorite(stop)
        }
    }
    func formatDate(_ date: Date?) -> String {
        if let date = date {
            let dateFormatter = DateFormatter()
            //            dateFormatter.dateFormat = "EEE, d MMMM yyyy"
            dateFormatter.dateStyle = .full
            dateFormatter.timeStyle = .none
            let formattedDate = dateFormatter.string(from: date)
            return formattedDate.prefix(1).capitalized + formattedDate.dropFirst()
        } else {
            return ""
        }
    }
}

#Preview("Recherche") {
    // Les trajets à venir viennent des itinéraires enregistrés.
    SearchView()
        .previewEnvironment(savedTrips: PreviewData.trips)
}

#Preview("Recherche — sans trajet enregistré") {
    SearchView()
        .previewEnvironment()
}

#Preview("Recherche — iPad", traits: .iPadLandscape) {
    SearchView()
        .previewEnvironment(savedTrips: PreviewData.trips)
}

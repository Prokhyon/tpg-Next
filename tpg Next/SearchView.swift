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
    @State var searchResult: Stop?
    @State private var stopResults: [Stop] = []
    @State private var showTripDetail = false
    
    @FocusState private var isFocused: Bool
    
    @AppStorage(SettingKey.homeShowsFavorites) var homeFavorites = false
    
    //    var futureTrips: [TripEvent] = []
    var futureTrips: [TripEvent] {
        savedTripsModel.savedTrips.sorted(by: { $0.startTime < $1.startTime }).filter { trip in
            !dateStringHasPassed(with: trip.startTime, equalReturnsTrue: false)
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
                                            searchResult = stop
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
                            Text(formatDate(stringToDate(with: activeFutureTrip?.startTime ?? "") ?? nil))
                                .font(.headline)
                            //                                .padding(.top)
                            Spacer()
                        }
                        .padding(.horizontal)
                        GeometryReader { geometry in
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(futureTrips, id: \.self) { trip in
                                        //                            if !dateStringHasPassed(with: trip.startTime, equalReturnsTrue: false) {
                                        NavigationLink {
                                            FullTripView(fullTrip: trip)
                                        } label: {
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
                            .mask {
                                Rectangle()
                                    .overlay(alignment: .top) {
                                        ScrollMask(leading: false, vertical: true, gradientLength: 10)
                                    }
                            }
                            .mask {
                                Rectangle()
                                    .overlay(alignment: .bottom) {
                                        ScrollMask(leading: true, vertical: true, gradientLength: 10)
                                    }
                            }
                            //                            .padding(.vertical)
                            //                            .scrollTargetBehavior(.paging)
                            .onAppear {
                                activeFutureTrip = futureTrips.first
                            }
                        }
                    }
                }
            } else {
                if stopResults.isEmpty {
                    Text("Aucun résultat pour « \(navigationModel.searchQuery) »")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(stopResults) { stop in
                                Button(action: {
                                    recentSearchModel.add(name: stop.name, isStop: true, stop: stop, geoCoordinates: nil)
                                    searchResult = stop
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
            .navigationDestination(item: $searchResult) { stop in
                StopView(stopName: stop.name, stopSloid: stop.sloid)
            }
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

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        @State var stopStore = StopStore()
        @State var favoritesViewModel = FavoritesViewModel()
        @State var fullTripTest = FullTripTest()
        @State var showSearch: Bool = true
        
        return NavigationStack() {
            SearchView(/*futureTrips: [fullTripTest.Trip]*/)
                .environment(favoritesViewModel)
                .environment(stopStore)
                .environment(RecentSearch())
//                    .background(Background())
            }
            
    }
}

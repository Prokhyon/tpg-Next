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
    //    @ObservedObject var path: ViewStateStack
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var tripViewModel: ItineraryViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    @ObservedObject var recentSearchModel = RecentSearch()
    @StateObject var locationManager = LocationManager()
    @EnvironmentObject var savedTripsModel: SavedTripsModel
    
    @State private var resultDetail: searchResultItem?
    @State private var activeFutureTrip: TripEvent?
    //    @State private var recentSearchDestination: RecentSearchItem?
    @State var searchResult: Stop?
    @State private var showTripDetail = false
    
    @FocusState private var isFocused: Bool
    
    @AppStorage("homeFavorites") var homeFavorites = false
    
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
            if stopStore.searchText.isEmpty {
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
                                            Button(action: {
                                                tripViewModel.outerTrip(tab: navigationModel, isDeparture: true, stop: stop, isQuickTrip: false)
                                            }) {
                                                Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                                            }
                                            Button(action: {
                                                tripViewModel.outerTrip(tab: navigationModel, isDeparture: false, stop: stop, isQuickTrip: false)
                                            }) {
                                                Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                                            }
                                            Button(action: {
                                                tripViewModel.outerTrip(tab: navigationModel, isDeparture: false, stop: stop, isQuickTrip: true)
                                            }) {
                                                Label("Trajet rapide", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
                                            }
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
                                            .onAppear(perform: {
                                                print(trip.startCoordinates)
                                            })
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
                if stopStore.filteredStops.isEmpty {
                    Text("Aucun résultat pour « \(stopStore.searchText) »")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(stopStore.filteredStops) { stop in
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
                                    Button(action: {
                                        tripViewModel.outerTrip(tab: navigationModel, isDeparture: true, stop: stop, isQuickTrip: false)
                                    }) {
                                        Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                                    }
                                    Button(action: {
                                        tripViewModel.outerTrip(tab: navigationModel, isDeparture: false, stop: stop, isQuickTrip: false)
                                    }) {
                                        Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                                    }
                                    Button(action: {
                                        tripViewModel.outerTrip(tab: navigationModel, isDeparture: false, stop: stop, isQuickTrip: true)
                                    }) {
                                        Label("Trajet rapide", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
                                    }
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
        
        
            .onAppear {
                isFocused = true
                if homeFavorites {
                    locationManager.requestLocation { location in
                        if let userLocation = locationManager.userLocation {
                            stopStore.location = userLocation
                        } else {
                            print("Location error")
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
                                   ////                        .environmentObject(savedTripsModel)
                                   //                }
                                   //            }
               
        if #available(iOS 26, *) {
            searchView
                .searchable(text: $stopStore.searchText)
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
        print(favoritesViewModel.favoriteStops)
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
        @StateObject var stopStore = StopStore()
        @StateObject var favoritesViewModel = FavoritesViewModel()
        @StateObject var fullTripTest = FullTripTest()
        @State var showSearch: Bool = true
        
        return NavigationStack() {
            SearchView(/*futureTrips: [fullTripTest.Trip]*/)
                .environmentObject(favoritesViewModel)
                .environmentObject(stopStore)
//                    .background(Background())
            }
            
    }
}

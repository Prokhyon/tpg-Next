//
//  HomeView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import SwiftUI
import CoreLocation
import Combine

struct FavoriteView: View {
    @StateObject private var stopStore = StopStore()
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    
    @Binding var isExpanded: Bool
    
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    private let maxRows = 5 // Set the maximum number of rows you want to display

    var body: some View {
        VStack {
            LazyVGrid(columns: columns, spacing: 10) {
                if favoritesViewModel.fullFavorites.count > 10 {
                    let favorites = isExpanded ? favoritesViewModel.fullFavorites : Array(favoritesViewModel.fullFavorites.prefix(maxRows * columns.count - (isExpanded ? 0 : 1)))
                    ForEach(favorites, id: \.self) { stop in
                        NavigationLink {
                            NewStopViewTest(favoritesViewModel: favoritesViewModel, stop: stop)
                        } label: {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.color1)
                                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                                .shadow(radius: 2)
                                .overlay(
                                    Text(stop.nomarret)
                                        .font(.headline)
                                        .foregroundColor(Color.primary)
                                )
                        }
                    }
                } else {
                    let favorites = favoritesViewModel.fullFavorites
                    ForEach(favorites, id: \.self) { stop in
                        NavigationLink {
                            StopView(favoritesViewModel: favoritesViewModel, stop: stop)
                        } label: {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.color1)
                                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                                .shadow(radius: 2)
                                .overlay(
                            Text(stop.nomarret)
                                .font(.headline)
                                .foregroundColor(Color.primary)
                            )
                        }
                    }
                }
                
                if !isExpanded && favoritesViewModel.fullFavorites.count > 10 {
                    Button(action: {
                        withAnimation(.spring(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.color1)
                            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                            .shadow(radius: 2)
                            .overlay(
                        Image(systemName: "plus")
                            .foregroundColor(Color.primary)
                            .font(.headline)
                        )
                    }
                }
                if isExpanded && favoritesViewModel.fullFavorites.count % 2 != 0 {
                    Button(action: {
                        withAnimation(.spring(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.color1)
                            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                            .shadow(radius: 2)
                            .overlay(
                        Image(systemName: "minus")
                            .foregroundColor(Color.primary)
                            .font(.headline)
                        )
                    }
                }
            }
            .padding()
            .onAppear {
                favoritesViewModel.id2stop(favoriteStops: favoritesViewModel.favoriteStops, stopsArray: stopStore.activeStops)
            }
            if isExpanded && favoritesViewModel.fullFavorites.count % 2 == 0 {
                Button(action: {
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.color1)
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                        .shadow(radius: 2)
                        .overlay(
                    Image(systemName: "minus")
                        .foregroundColor(Color.primary)
                        .font(.headline)                    )
                }
                .padding(.bottom)
                .padding(.horizontal)
            }
        }
        .padding(.top, 1.0)
        .background(Color.color1)
        .scrollDisabled(true)
        .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
        .padding(.horizontal)
        .shadow(radius: 5)
        
    }
}




struct ClosestStopsView: View {
    @StateObject private var stopStore = StopStore()
    @StateObject var locationManager = LocationManager()
    @StateObject private var stopManager = StopManager()
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    //@State var stop: Stop?

    var body: some View {
            if let userLocation = locationManager.userLocation, !stopStore.activeStops.isEmpty {
                let closestStops = calculateClosestBusStops(from: userLocation, stops: stopStore.activeStops)
                               if !closestStops.isEmpty {
                                   GeometryReader { geometry in
                                       ScrollView(.horizontal) {
                                           HStack {
                                               ForEach(closestStops, id: \.id) { stop in
                                                       CloseDeparturesView(stop: stop)
                                                       .frame(width: geometry.size.width, height: geometry.size.height)
                                               }
                                               
                                           }
                                           
                                           .scrollTargetLayout()
                                       }
                                       .scrollTargetBehavior(.viewAligned)
                                   }
                                   
                } else {
                    Text("No bus stops found.")
                }
            } else {
                Text("Loading...")
            }
    }
}

struct CloseDeparturesView: View {
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @StateObject private var stopManager = StopManager()
    @State private var timer: AnyCancellable?
    var stop: Stop
    var body: some View {

            List{
                Section() {
                    ForEach(stopManager.stopEvents, id: \.id) { event in
                        NavigationLink {
                            NewLineView(stopEvent: event, currentStop: stop, currentLine: event.lineName)
                        } label: {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.color1)
                                .frame(width: 340, height: 50)
                                .shadow(radius: 2)
                                .overlay(
                            NewStopBus(event: event, showTime: false)
                                .padding(.vertical, 0)
                            )
                                .padding(.vertical, 4)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                        //.listRowBackground(Color.color1)
                    }
                } header: {
                    NavigationLink {
                        NewStopViewTest(favoritesViewModel: favoritesViewModel, stop: stop)
                    } label: {
                        Text("\(stop.nomarret)")
                            .bold()
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                }
                .textCase(.none)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .onAppear {
                stopManager.selectStop(stop, stopEventNumber: 3)
                timer = Timer.publish(every: 30, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        stopManager.selectStop(stop, stopEventNumber: 3)
                    }
            }
            .onDisappear {
                timer?.cancel()
            }
           /* .refreshable {
                stopManager.selectStop(stop, stopEventNumber: 3)
            }*/
            

            .background(.color1)
        .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
        .padding(.horizontal)
        .padding(.vertical, 10.0)
        .shadow(radius: 5)
        
    }
}

struct HomeView: View {
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @State private var isExpanded: Bool = false
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                NavigationStack {
                    ScrollView {
                        VStack {
                            HStack {
                                Text("Favoris")
                                    .font(.title)
                                    .bold()
                                    .padding(.leading, 15)
                                    .frame(height: 20.0)
                                Spacer()
                            }
                            .padding(.bottom, 5)
                            
                            FavoriteView(isExpanded: $isExpanded)
                            VStack {
                                HStack {
                                    Text("Départs à proximité")
                                        .font(.title)
                                        .bold()
                                        .padding(.leading, 15)
                                        .frame(height: 20.0)
                                    Spacer()
                                }
                                .padding(.top, 30)
                                
                                ClosestStopsView()
                                    .frame(width: geometry.size.width, height: geometry.size.height / 3)
                                // }
                                // .transition(.scale) // Add transition animation
                            }
                            
                            Spacer()
                            
                        }
                    }
                    .scrollDisabled(isExpanded ? false : true)
                }
            }
            VStack {
                if isExpanded {
                    Rectangle()
                        .frame(width: 395, height: 40)
                        .foregroundStyle(.white)
                        .shadow(color: .white, radius: 7, x: 0, y: 15)
                        .ignoresSafeArea(edges: .top)
                    Spacer()
                }
            }
        }
    }
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return AppTabBarView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

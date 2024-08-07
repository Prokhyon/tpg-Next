//
//  ContentView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var stopStore = StopStore()
    @StateObject private var favoritesViewModel: FavoritesViewModel
    @State private var homeView: Bool = true
    @State private var tripView: Bool = false
    @State private var stopView: Bool = false
    @State private var lineView: Bool = false
    @State private var fullTripView: Bool = false
    @State private var searchView: Bool = false
    @State private var currentStop: Stop? = nil
    @State private var currentStopEvent: StopEvent? = nil
    @State private var currentLine: String = ""
    
    init() {
        let stopStore = StopStore()
        _favoritesViewModel = StateObject(wrappedValue: FavoritesViewModel(stopStore: stopStore))
    }
    
    var body: some View {
        VStack {
            if homeView {
                HomeView()
            }
            
            if tripView {
                TripView()
            }
            
            if stopView {
                StopView(favoritesViewModel: favoritesViewModel, stop: currentStop!)
            }
            
            if lineView {
                LineView(stopEvent: currentStopEvent!, currentStop: currentStop!, currentLine: currentLine)
            }
            
            // Example buttons to switch views
            HStack {
                Button("Show Home View") {
                    homeView = true
                    tripView = false
                    stopView = false
                    lineView = false
                }
                Button("Show Trip View") {
                    homeView = false
                    tripView = true
                    stopView = false
                    lineView = false
                }
            }
        }
    }
}
//        TabView {
//            // Tab 1: HomeView
//            HomeView()
//                .tabItem {
//                    Image(systemName: "house")
//                    Text("Accueil")
//                }
//            
//            // Tab 2: SearchView
//            SearchView()
//                .tabItem {
//                    Image(systemName: "magnifyingglass")
//                    Text("Recherche")
//                }
//            
//            // Tab 3: SettingsView
//            SettingsView()
//                .tabItem {
//                    Image(systemName: "gear")
//                    Text("Réglages")
//                }
//            
//           /* NewStopViewTest()
//                .tabItem {
//                    Text("Stop")
//                }*/
//        }
//        .accentColor(.orange) // Set the active tab color
//        .environmentObject(favoritesViewModel)
//       /* .background {
//            RoundedRectangle(cornerRadius: 45.0)
//                .frame(width: 395, height: 200)
//                .foregroundStyle(.color1)
//                .shadow(radius: 10)
//                .ignoresSafeArea(edges: .bottom)
//        }*/


struct SettingsView: View {
    @StateObject private var stopStore = StopStore()
    var body: some View {
        VStack {
            Text("Settings View")
                .font(.largeTitle)
                .padding()
        }
    }
}

struct ContentView2_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return ContentView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

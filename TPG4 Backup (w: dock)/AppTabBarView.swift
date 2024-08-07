//
//  AppTabBarView.swift
//  TPG4
//
//  Created by Loris Thomas on 29.06.2024.
//

import SwiftUI

struct AppTabBarView: View {
    @State private var selection: String = "home"
    @State private var tabSelection: TabBarItem = .home
    
    @StateObject private var stopStore = StopStore()
    @StateObject private var favoritesViewModel: FavoritesViewModel
    
    init() {
        let stopStore = StopStore()
        _favoritesViewModel = StateObject(wrappedValue: FavoritesViewModel(stopStore: stopStore))
    }
    
    var body: some View {
        CustomTabBarContainerView(selection: $tabSelection) {
            HomeView()
                .tabBarItem(tab: .home, selection: $tabSelection)
            SearchView()
                .tabBarItem(tab: .search, selection: $tabSelection)
            
            TripView()
            .tabBarItem(tab: .trip, selection: $tabSelection)        }
    }
}




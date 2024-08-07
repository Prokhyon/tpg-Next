//
//  TPG4App.swift
//  TPG4
//
//  Created by Loris Thomas on 17.06.2024.
//

import SwiftUI
import Foundation
import Combine

@main
struct TPG4App: App {
    @StateObject private var stopStore = StopStore()
    @StateObject private var favoritesViewModel: FavoritesViewModel
    
    init() {
            let stopStore = StopStore()
            _stopStore = StateObject(wrappedValue: stopStore)
            _favoritesViewModel = StateObject(wrappedValue: FavoritesViewModel(stopStore: stopStore))
            UINavigationBar.setTransparentAppearance()
        }

    var body: some Scene {
        WindowGroup {
            AppTabBarView()
                .environmentObject(favoritesViewModel)
        }
    }
}


struct AppTabBarView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return AppTabBarView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

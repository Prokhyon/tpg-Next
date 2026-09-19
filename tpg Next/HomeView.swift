//
//  HomeView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import SwiftUI
import CoreLocation
import Combine
import tpgNextFunc

struct HomeView: View {
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    
    @State private var isExpanded: Bool = false
    @State private var maxRows: Int = 5
    var testing: Bool
    @AppStorage(SettingKey.homeShowsFavorites) var homeFavorites = false
        
    var body: some View {
            GeometryReader { geometry in
                ZStack {
                    ScrollView {
                        VStack {
                            HStack {
                                Text("Favoris")
                                    .font(.title)
                                    .bold()
                                    .padding(.leading, 15)
                                    .heightGrowingWithText(20)
                                Spacer()
//                                Button(action: {
//                                    self.showSettings.toggle()
                                NavigationLink(value: AppRoute.settings) {
                                    Image(systemName: "gear")
                                        .font(.title)
                                        .padding(TPGSurface.isGlass ? 5 : 0)
                                }
                                .tpgSurface(interactive: true, legacy: nil)
                                .padding(.leading, 5)
                                .padding(.trailing, 15)
                            }
                            
                            // Une rangée de favoris pour 168 points de hauteur de fenêtre : 3 à 5 selon l'iPhone, au moins 1
                            // (au premier passage, la fenêtre mesure 0 et `prefix(-1)` plantait). La fenêtre
                            // et non l'écran (`UIScreen.main`) : sur iPad ou en multifenêtre, elle est plus petite.
                            FavoriteView(isExpanded: $isExpanded, maxRows: max(1, Int(((geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom) / 168).rounded())))
                            VStack(spacing: 0) {

                                
                                HomeDepartures(testing: testing)
//                                    .background(Rectangle().fill(.red))
                            }
                            Spacer()
                        }
                    }
                    .readableScrollContent()
                    // Toujours défilable : bloqué tant que la grille des favoris n'était pas dépliée,
                    // l'accueil cachait ses départs avec beaucoup de favoris ou un texte agrandi.
                    VStack {
                        BackdropBlurView(radius: 5)
                            .frame(height: geometry.safeAreaInsets.top)
                            .mask {
                                Rectangle()
                                    .overlay(alignment: .top) {
                                        ScrollMask(leading: true, vertical: true, gradientLength: 100)
                                    }
                            }
                            .ignoresSafeArea()
                    Spacer()
                    }
//                    VStack {
//                        HStack {
//                            Spacer()
//                            if #available(iOS 26, *) {
//                                NavigationLink {
//                                    SettingsView()
//                                } label: {
//                                    Image(systemName: "gear")
//                                        .font(.title)
//                                        .padding(5)
//                                }
//                                .glassEffect(.regular.interactive())
//                                .padding(.leading, 5)
//                                .padding(.trailing, 15)
//                            } else {
//                                NavigationLink {
//                                    SettingsView()
//                                } label: {
//                                    Image(systemName: "gear")
//                                        .font(.title)
//                                }
//                                .padding(.leading, 5)
//                                .padding(.trailing, 15)
//                            }
//                        }
//                        Spacer()
//                    }
                }
                .sensoryFeedback(.selection, trigger: isExpanded)
            }
        .navigationTitle("Départs") // Set back button text
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("") // Visible title
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Accueil — arrêts proches") {
    // Départs autour de la position du simulateur (Features → Location dans le simulateur).
    HomeView(testing: false)
        .previewEnvironment()
}

#Preview("Accueil — départs des favoris") {
    HomeView(testing: false)
        .previewSettings([SettingKey.homeShowsFavorites: true])
        .previewEnvironment()
}

#Preview("Accueil — sans favori") {
    HomeView(testing: true)
        .previewEnvironment(favorites: [])
}

#Preview("Accueil — hors ligne") {
    // Départs figés de SmallStopView, sans position ni API.
    HomeView(testing: true)
        .previewEnvironment()
}

#Preview("Accueil — iPad", traits: .iPadLandscape) {
    HomeView(testing: false)
        .previewSettings([SettingKey.homeShowsFavorites: true])
        .previewEnvironment()
}

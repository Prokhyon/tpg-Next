//
//  NearbyDepartures.swift
//  tpg Next
//
//  Départs des arrêts proches (ou favoris), une carte par page.
//

import SwiftUI
import CoreLocation
import tpgNextFunc

struct HomeDepartures: View {
//    var path: ViewStateStack
    @Environment(StopStore.self) var stopStore
    @State var locationManager = LocationManager()
//    @State private var stopManager = StopManager()
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @State private var closestStops: [Stop] = []
    @State private var testStop: [Stop] = [Stop(name: "Genève, Rive", sloid: "ch:1:sloid:87061", codedidoc: "8587061", country: "CH", canton: "GE", meansOfTransport: "Bus", wgs84Coordinates: Coordinates(lon: 0.0, lat: 0.0)), Stop(name: "Genève, Place des Eaux-Vives", sloid: "ch:1:sloid:87062", codedidoc: "8587062", country: "CH", canton: "GE", meansOfTransport: "Bus", wgs84Coordinates: Coordinates(lon: 0.0, lat: 0.0))]
    @State private var calculationSuccess = false
    /// Position refusée ou introuvable : sans ça l'accueil restait sur « Chargement... ».
    @State private var locationFailed = false
    @State private var currentIndex = 0
    /// Hauteur de la plus grande carte d'arrêt affichée : les pages grandissent avec le texte.
    @State private var pageContentHeight: CGFloat = 0
    @AppStorage(SettingKey.homeShowsFavorites) var homeFavorites = false
    var testing: Bool = false
//    @State var autoRefresh = true
    
    var body: some View {
                        VStack(spacing:0) {
                            if testing {
                                departuresPager(count: testStop.count, isHome: true, testing: true) { testStop[$0] }
                            } else if !homeFavorites {
                                if calculationSuccess {
                                    if !closestStops.isEmpty {
                                        departuresPager(count: closestStops.count, isHome: true, testing: false) { closestStops[$0] }
                                    } else {
                                        Text("Pas d'arrêt à proximité trouvé.")
                                            .padding(.top, 70)
                                    }
                                } else if locationFailed {
                                    Group {
                                        if locationManager.lastFailure == .denied {
                                            Text("Autorisez la localisation pour voir les départs à proximité.")
                                        } else {
                                            Text("Position introuvable pour l'instant.")
                                        }
                                    }
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 70)
                                    .padding(.horizontal)
                                } else {
                                    Text("Chargement...")
                                        .padding(.top, 70)
                                }
                            } else {
                                if favoritesViewModel.favoriteStops.count > 0 {
                                    departuresPager(count: min(3, favoritesViewModel.favoriteStops.count), isHome: false, testing: testing) { index in
                                        let shortStop = favoritesViewModel.favoriteStops[index]
                                        return createStop(nomarret: shortStop.name, sloid: shortStop.sloid)
                                    }
                                } else {
                                    Text("Pas d'arrets en favoris")
                                        .padding(.top, 70)
                                }
                            }
                        }
        // `testing` passe à false à la fermeture de la bienvenue : la recherche démarre alors.
        .periodicRefresh(repeats: !testing) { _ in
            getLocation()
        }
        .onChange(of: stopStore.isLoaded) {
            getLocation()
        }
    }

    /// Les départs de quelques arrêts, un par page, sous le titre de la section.
    ///
    /// Le titre était superposé en haut de pages de hauteur fixe (320), les cartes collées en
    /// bas : avec un texte agrandi, la carte montait sous le titre. Il est désormais au-dessus,
    /// et les pages prennent la hauteur de la plus grande carte (au moins l'ancienne place).
    private func departuresPager(count: Int, isHome: Bool, testing: Bool, stop: @escaping (Int) -> Stop) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(homeFavorites ? "Départs" : "Départs à proximité")
                    .font(.title)
                    .bold()
                    .padding(.leading, 15)
                Spacer()
            }
            ZStack(alignment: .bottom) {
                TabView(selection: $currentIndex.animation()) {
                    ForEach(0..<count, id: \.self) { index in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            SmallStopView(stop: stop(index), isHome: isHome, testing: testing)
                                // Hauteur naturelle, pas celle de la page : mesurée dans une page trop
                                // basse, la carte se comprimait et la page ne grandissait jamais.
                                .fixedSize(horizontal: false, vertical: true)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                    pageContentHeight = max(pageContentHeight, height)
                                }
                                .padding(.bottom, 20)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                // 320 moins la ligne du titre, désormais au-dessus : même place qu'avant.
                .frame(height: max(286, pageContentHeight + 20))
                Fancy3DotsIndexView(numberOfPages: count, currentIndex: currentIndex)
            }
        }
    }

    private func getLocation() {
        // La base se charge en arrière-plan : `onChange(of: stopStore.isLoaded)` relance la recherche.
        guard !testing, stopStore.isLoaded else { return }
        locationManager.requestLocation { location in
            if let userLocation = location ?? locationManager.userLocation {
                locationFailed = false
                let stopList = stopStore.activeStops
                let radiusList = stopsInBoundingBox(from: userLocation, radius: 1000, stops: stopList)
                calculateClosestBusStops(from: userLocation, stops: radiusList, nb: 3) { success, stops in
                    DispatchQueue.main.async {
                        calculationSuccess = success
                        // Même règle que le widget et la montre : favori le plus proche
                        // en tête, sauf si un arrêt est à moins de 20 m.
                        closestStops = NearbyStopSelector.prioritized(
                            stops,
                            from: userLocation,
                            favoriteSloids: Set(favoritesViewModel.favoriteStops.map { sloidHarmonizer(code: $0.sloid) })
                        )
                    }
                }
                stopStore.location = userLocation
            } else {
                Log.location.error("Position indisponible pour les départs à proximité")
                locationFailed = true
            }
            locationManager.locationUpdateHandler = nil
        }
    }
}

struct Fancy3DotsIndexView: View {
  
  //Public Properties
  
  let numberOfPages: Int
  let currentIndex: Int
  
  
  //Drawing Constants
  
  private let circleSize: CGFloat = 10
  private let circleSpacing: CGFloat = 10
  
    private let primaryColor = Color.primary
  private let secondaryColor = Color.primary.opacity(0.6)
  
  private let smallScale: CGFloat = 0.6
  
  
    //Body
  
    var body: some View {
        HStack(spacing: circleSpacing) {
            ForEach(0..<numberOfPages/*3*/, id: \.self) { index in // 1
                if shouldShowIndex(index) {
                    Circle()
                        .fill(currentIndex == index ? primaryColor : secondaryColor) // 2
                        .scaleEffect(currentIndex == index ? 1 : smallScale)
                    
                        .frame(width: circleSize, height: circleSize)
                    
                        .transition(AnyTransition.opacity.combined(with: .scale)) // 3
                    
                        .id(index) // 4
                }
            }
        }
    }
  
//Private Methods
  func shouldShowIndex(_ index: Int) -> Bool {
    ((currentIndex - 1)...(currentIndex + 1)).contains(index)
  }
}

#Preview("Départs de l'accueil — hors ligne") {
    ScrollView {
        HomeDepartures(testing: true)
    }
    .previewEnvironment()
}

#Preview("Départs de l'accueil — favoris") {
    ScrollView {
        HomeDepartures()
    }
    .previewSettings([SettingKey.homeShowsFavorites: true])
    .previewEnvironment()
}

#Preview("Indicateur de page", traits: .sizeThatFitsLayout) {
    @Previewable @State var index = 2
    VStack(spacing: 20) {
        Fancy3DotsIndexView(numberOfPages: 6, currentIndex: index)
            .animation(.default, value: index)
        Stepper("Page \(index + 1)" as String, value: $index, in: 0...5)
    }
    .padding()
}

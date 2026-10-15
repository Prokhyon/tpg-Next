//
//  NearbyDepartures.swift
//  tpg Next
//
//  Départs des arrêts proches (ou favoris) : une carte par page, ou les arrêts l'un sous
//  l'autre dans la colonne d'un grand écran. L'arrêt affiché est mis en évidence sur la carte
//  de l'accueil (`NearbyStops.highlightedSloid`).
//

import SwiftUI
import CoreLocation
import tpgNextFunc

struct HomeDepartures: View {
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(NearbyStops.self) private var nearby
    @State private var testStop: [Stop] = [Stop(name: "Genève, Rive", sloid: "ch:1:sloid:87061", codedidoc: "8587061", country: "CH", canton: "GE", meansOfTransport: "Bus", wgs84Coordinates: Coordinates(lon: 0.0, lat: 0.0)), Stop(name: "Genève, Place des Eaux-Vives", sloid: "ch:1:sloid:87062", codedidoc: "8587062", country: "CH", canton: "GE", meansOfTransport: "Bus", wgs84Coordinates: Coordinates(lon: 0.0, lat: 0.0))]
    /// Hauteur de la plus grande carte d'arrêt affichée : les pages grandissent avec le texte.
    @State private var pageContentHeight: CGFloat = 0
    @AppStorage(SettingKey.homeShowsFavorites) var homeFavorites = false
    var testing: Bool = false
    /// Les arrêts l'un sous l'autre plutôt qu'en pages : la colonne d'un grand écran est haute,
    /// et des pages y coupaient net au bord.
    var stacked: Bool = false
    /// Départs d'un arrêt déplié de la pile : la place ne manque pas.
    private static let stackedDepartureCount = 7

    /// Les arrêts de la liste : ceux de la carte, ou les premiers favoris.
    private var displayedStops: [Stop] {
        if testing { return testStop }
        if homeFavorites {
            return favoritesViewModel.favoriteStops.prefix(3).map { createStop(nomarret: $0.name, sloid: $0.sloid) }
        }
        return nearby.stops
    }

    /// Les arrêts proches ont leur distance ; pas les favoris.
    private var distanceFrom: CLLocation? {
        homeFavorites || testing ? nil : nearby.location
    }

    /// L'arrêt que la liste montre (page courante, arrêt déplié) : celui choisi dans la liste ou
    /// sur la carte, sinon le premier. Par sloid, pour survivre au rafraîchissement de la liste.
    private var displayedSloid: String? {
        let stops = displayedStops
        return (stops.first { $0.sloid == nearby.selectedSloid } ?? stops.first)?.sloid
    }

    var body: some View {
        VStack(spacing: 0) {
            if testing {
                departures(testStop, tripMenu: false)
            } else if !homeFavorites {
                switch nearby.status {
                case .found where !nearby.stops.isEmpty:
                    departures(nearby.stops, tripMenu: false)
                case .found:
                    Text("Pas d'arrêt à proximité trouvé.")
                        .padding(.top, 70)
                case .failed(let denied):
                    Group {
                        if denied {
                            Text("Autorisez la localisation pour voir les départs à proximité.")
                        } else {
                            Text("Position introuvable pour l'instant.")
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 70)
                    .padding(.horizontal)
                case .loading:
                    // Position et départs attendus : des départs fantômes.
                    LoadingPlaceholder(kind: .departure, count: 3)
                        .padding(.top, 8)
                }
            } else if !displayedStops.isEmpty {
                departures(displayedStops, tripMenu: true)
            } else {
                Text("Aucun arrêt favori")
                    .padding(.top, 70)
            }
        }
        // Toute la largeur : les messages (chargement, position refusée) restent centrés quel que
        // soit l'alignement de la section.
        .frame(maxWidth: .infinity)
        // `testing` passe à false à la fermeture de la bienvenue : la recherche démarre alors.
        .periodicRefresh(repeats: !testing) { _ in
            refreshNearby()
        }
        .onChange(of: stopStore.isLoaded) {
            refreshNearby()
        }
        .onChange(of: displayedSloid, initial: true) {
            nearby.highlightedSloid = displayedSloid
        }
        .onChange(of: displayedStops.map(\.sloid), initial: true) {
            nearby.listedSloids = displayedStops.map(\.sloid)
        }
    }

    private func refreshNearby() {
        guard !testing else { return }
        nearby.refresh(stopStore: stopStore,
                       favoriteSloids: Set(favoritesViewModel.favoriteStops.map { sloidHarmonizer(code: $0.sloid) }))
    }

    /// `tripMenu` : le bouton d'itinéraire d'un favori ouvre le menu ; celui d'un arrêt proche
    /// lance un itinéraire depuis l'arrêt. Le style reste celui de l'accueil dans les deux cas :
    /// la version en verre des favoris avait une ombre plus forte, coupée par la colonne sur iPad.
    private func departures(_ stops: [Stop], tripMenu: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                HomeSectionTitle(homeFavorites ? "Départs" : "Départs à proximité")
                Spacer()
            }
            if stacked {
                departuresStack(stops, tripMenu: tripMenu)
            } else {
                departuresPager(stops, tripMenu: tripMenu)
            }
        }
    }

    /// Les arrêts l'un sous l'autre, un seul déplié : toucher le nom d'un autre le déplie et
    /// replie le précédent ; toucher celui du déplié ouvre sa page, comme ailleurs.
    private func departuresStack(_ stops: [Stop], tripMenu: Bool) -> some View {
        let expanded = displayedSloid
        return VStack(spacing: 12) {
            ForEach(stops, id: \.sloid) { stop in
                SmallStopView(stop: stop, isHome: true, tripMenu: tripMenu,
                              distanceFrom: distanceFrom,
                              // Un peu plus que montré : certaines courses sont écartées à l'affichage.
                              stopEventNumber: Self.stackedDepartureCount + 2,
                              departureCount: Self.stackedDepartureCount,
                              testing: testing,
                              isExpanded: stop.sloid == expanded) {
                    withAnimation(.snappy) { nearby.selectedSloid = stop.sloid }
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 20)
        .sensoryFeedback(.selection, trigger: expanded)
    }

    /// Les départs de quelques arrêts, un par page.
    ///
    /// Le titre était superposé en haut de pages de hauteur fixe (320), les cartes collées en
    /// bas : avec un texte agrandi, la carte montait sous le titre. Il est désormais au-dessus,
    /// et les pages prennent la hauteur de la plus grande carte (au moins l'ancienne place).
    private func departuresPager(_ stops: [Stop], tripMenu: Bool) -> some View {
        // La page suit l'arrêt choisi, aussi quand il l'est d'un toucher sur la carte.
        let selection = Binding<String?>(get: { displayedSloid }, set: { nearby.selectedSloid = $0 })
        return ZStack(alignment: .bottom) {
            TabView(selection: selection.animation()) {
                ForEach(stops, id: \.sloid) { stop in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        SmallStopView(stop: stop, isHome: true, tripMenu: tripMenu,
                                      distanceFrom: distanceFrom, testing: testing)
                            // Hauteur naturelle, pas celle de la page : mesurée dans une page trop
                            // basse, la carte se comprimait et la page ne grandissait jamais.
                            .fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                pageContentHeight = max(pageContentHeight, height)
                            }
                            .padding(.bottom, 20)
                    }
                    .tag(Optional(stop.sloid))
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            // 320 moins la ligne du titre, désormais au-dessus : même place qu'avant.
            .frame(height: max(286, pageContentHeight + 20))
            Fancy3DotsIndexView(numberOfPages: stops.count,
                                currentIndex: stops.firstIndex { $0.sloid == displayedSloid } ?? 0)
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
    .environment(NearbyStops())
    .previewEnvironment()
}

#Preview("Départs de l'accueil — empilés (iPad)") {
    ScrollView {
        HomeDepartures(testing: true, stacked: true)
    }
    .environment(NearbyStops())
    .previewEnvironment()
}

#Preview("Départs de l'accueil — favoris") {
    ScrollView {
        HomeDepartures()
    }
    .environment(NearbyStops())
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

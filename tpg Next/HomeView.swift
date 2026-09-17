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

struct FavoriteStopView: View {
    @Environment(ItineraryViewModel.self) var tripViewModel
    @Environment(NavigationModel.self) var navigationModel
    var stop: Stop
    var body: some View {
        NavigationLink {
            StopView(
                stopName: stop.name,
                stopSloid: stop.sloid
            )
        } label: {
            BasicLocationView(name: stop.name, transportType: stop.meansOfTransport)
        }
        .foregroundStyle(.primary)
        .contentShape(.contextMenuPreview, Capsule())
        .contextMenu {
            TripActionsMenu(stop: stop)
        }
    }
}

struct FavoriteView: View {
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(NavigationModel.self) var navigationModel
    @Binding var isExpanded: Bool

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var maxRows: Int // Set the maximum number of rows you want to display

    var body: some View {
        VStack {
            VStack {
                if favoritesViewModel.favoriteStops.isEmpty {
                    Button(action: {
                        withAnimation {
                            navigationModel.selectedTab = .search
                        }
                    }) {
                        HStack {
                            Image(systemName: "star").font(.largeTitle)
                            Text("Ajoutez un arrêt aux favoris en cliquant sur l'étoile depuis la recherche ou le menu d'une page arrêt").multilineTextAlignment(.leading)
                        }
                        .padding()
                        .foregroundColor(Color.primary)
                        .background {
                            BasicCard(cornerRadius: 35)
                        }
                    }
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    if favoritesViewModel.favoriteStops.count > maxRows*2 {
                        let favorites = isExpanded ? favoritesViewModel.favoriteStops : Array(favoritesViewModel.favoriteStops.prefix(max(0, maxRows * columns.count - (isExpanded ? 0 : 1))))
                        ForEach(favorites, id: \.self) { stop in
                            FavoriteStopView(stop: stop)
                        }
                    } else {
                        let favorites = favoritesViewModel.favoriteStops
                        ForEach(favorites, id: \.self) { stop in
                         FavoriteStopView(stop: stop)
                        }
                    }
                    
                    if !isExpanded && favoritesViewModel.favoriteStops.count > maxRows*2 {
                        Button(action: {
                            withAnimation(.spring(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            BasicElement()
                                .overlay(
                                    Image(systemName: "plus")
                                        .foregroundColor(Color.primary)
                                        .font(.headline)
                                )
                        }
                    }
                    
                    if isExpanded && favoritesViewModel.favoriteStops.count % 2 != 0 {
                        Button(action: {
                            withAnimation(.spring(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            BasicElement()
                                .overlay(
                                    Image(systemName: "minus")
                                        .foregroundColor(Color.primary)
                                        .font(.headline)
                                )
                        }
                    }
                }
                
                if isExpanded && favoritesViewModel.favoriteStops.count % 2 == 0 {
                    Button(action: {
                        withAnimation(.spring(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        BasicElement()
                            .frame(height: 45)
                            .overlay(
                                Image(systemName: "minus")
                                    .foregroundColor(Color.primary)
                                    .font(.headline)
                            )
                    }
                    .padding(.top, 3.0)
                }
            }
            .padding(15)
//            .background(.thinMaterial)
//            .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
//            .padding(.horizontal)
//            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
            .scrollDisabled(true)
        }
    }
}

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

struct SmallStopView: View {
    @Environment(ItineraryViewModel.self) var tripViewModel
    @Environment(NavigationModel.self) var navigationModel
    @State var stopManager = StopManager()
    @State private var lineManager = LineManager()
    @State private var isShowingPopover = false
    
    var stop: Stop
    var quay = ""
    var isQuay: Bool = false
    var isHome: Bool = false
    var stopEventNumber: Int = 3
    //    var autoRefresh = true
    var testing: Bool = false
    @Namespace private var namespace
    
    
    var body: some View {
        
        //main view
        VStack {
            if #available(iOS 26, *), !isHome {
                GlassEffectContainer() {
                    VStack {
                        HeaderView()
                            DeparturesList()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 15)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 40))
                                .glassEffectID("departures", in: namespace)
                    }
                }
            } else {
                VStack {
                    HeaderView()
                    if !testing {
                        DeparturesList()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 5)
                            .background {
                                BasicCard(cornerRadius: 35)
                            }
                    } else {
                        DeparturesTestList()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 5)
                            .background {
                                BasicCard(cornerRadius: 35)
                            }
                    }
                }
                .padding(.horizontal)
                
                //                VStack {
                //                     HeaderView()
                //                        .padding(.horizontal)
                //                     DeparturesList()
                //                 }
                //                    .padding(.vertical, 15)
                //                    .background {
                //                        RoundedRectangle(cornerRadius: 35)
                //                            .foregroundStyle(.thinMaterial)
                //                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                //                    }
            }
        }
        .periodicRefresh(id: stop, repeats: !testing) { _ in
            refreshDepartures()
        }
    }
    
    private func HeaderView() -> some View {
        HStack {
            if #available(iOS 26, *), !isHome {
                HStack {
                    if isQuay {
                        Text("Quai \(quay)").font(.title3).bold()
                    } else {
                        StopTitleView()
                    }
                }
                .frame(height: 45)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .padding(.trailing, 50)
                .glassEffect(.regular.interactive())
                .glassEffectID("title", in: namespace)
                .foregroundStyle(.primary)
                Spacer()
                TripButton()
                    .frame(width: 45, height: 45)
                    .padding(10)
                    .foregroundStyle(.primary)
                    .glassEffect(.regular.interactive())
                    .glassEffectID("trip", in: namespace)
            } else {
                HStack {
                    if isQuay {
                        Text("Quai \(quay)").font(.title3).bold()
                    } else {
                        StopTitleView()
                    }
                }
                .frame(height: 45)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .padding(.trailing, 40)
                .foregroundStyle(.primary)
                .background {
                    BasicElement()
                }
                Spacer()
                TripButton()
                    .frame(width: 45, height: 45)
                    .padding(5)
                    .foregroundStyle(.primary)
                    .background {
                        BasicElement()
                    }
            }
        }
    }
    
    private func StopTitleView() -> some View {
        NavigationLink {
            StopView(
                stopName: stop.name,
                stopSloid: stop.sloid
            )
        } label: {
            HStack {
                //                StopIcon(color: .color1)
                StopNameView(stop.name, style: .card, transportType: stop.meansOfTransport)
                if splitString(stop.name, separator: ",").1.isEmpty {
                    Spacer() // Un nom sur une ligne occupe toute la largeur de la carte.
                }
            }
        }
    }
    
    private func TripButton() -> some View {
        HStack {
            let menu = Group {
                TripActionsMenu(stop: stop)
            }
            if isHome {
                Button(action: {
                    tripViewModel.outerTrip(tab: navigationModel, isDeparture: true, stop: stop, isQuickTrip: false)
                }) {
                    Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            } else {
                Menu {
                    menu
                } label: {
                    Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
            }
        }
    }
    
    private func DeparturesList() -> some View {
        VStack(spacing: 0) {
            if !stopManager.stopEvents.isEmpty {
                ForEach(isQuay ? filteredEvents.sortedByDeparture().prefix(3) : stopManager.stopEvents.sortedByDeparture().prefix(3), id: \.id) { event in
                    NavigationLink {
                        LineView(stopEvent: event, currentStop: ShortStop(name: stop.name, sloid: sloidHarmonizer(code: stop.sloid)), currentLine: event.lineName)
                    } label: {
                        StopEventView(event: event, showTime: false, mapVersion: !isHome)
                    }
                    .contentShape(.contextMenuPreview, Capsule())
                    .foregroundStyle(.primary)
                    .contextMenu {
                        NotificationContextMenu(event: event, stopID: stop.sloid)
                    }
                }
            } else if stopManager.stopError {
                HStack {
                    Spacer()
                    if stopManager.stopErrorMessage == "STOPEVENT_LOCATIONUNSERVED" {
                        Text("Malheureusement, cet arrêt n'est pas disponible depuis l'application, ou n'est pas desservi")
                    } else {
                        Text("Pas de départs trouvés")
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Spacer()
                    Text("Recherche des départs...")
                    Spacer()
                }
            }
        }
        .heightGrowingWithText(170)
    }
    
    private func DeparturesTestList() -> some View {
        VStack(spacing: 0) {
            StopEventView(event: StopEvent(stopPointName: "1", stopId: "1", plannedQuay: "k", timetabledTime: "2025/09/24T17:48:00Z", estimatedTime: "", lineName: "25", origin: "1", destination: "Thônex, Vallard", transportType: "", operatorName: "Transports Publics Genevois", journeyRef: "1", operatingDayRef: ""), showTime: false, mapVersion: !isHome)
            StopEventView(event: StopEvent(stopPointName: "", stopId: "2", plannedQuay: "b", timetabledTime: "2025/09/24T17:49:00Z", estimatedTime: "", lineName: "12", origin: "", destination: "Thônex, Moillesulaz", transportType: "", operatorName: "Transports Publics Genevois", journeyRef: "1", operatingDayRef: ""), showTime: false, mapVersion: !isHome)
            StopEventView(event: StopEvent(stopPointName: "", stopId: "3", plannedQuay: "c", timetabledTime: "2025/09/24T17:50:00Z", estimatedTime: "", lineName: "17", origin: "", destination: "Lancy-Bachet, gare", transportType: "", operatorName: "Transports Publics Genevois", journeyRef: "1", operatingDayRef: ""), showTime: false, mapVersion: !isHome)
        }
        .heightGrowingWithText(170)
    }
    
    private func refreshDepartures() {
        guard !testing else { return }
        stopManager.selectStop(stopName: stop.name, stopSloid: stop.sloid, stopEventNumber: stopEventNumber, timeRequest: Date())
    }
    private var filteredEvents: [StopEvent] {
        stopManager.stopEvents.filter { $0.plannedQuay == quay }
       }
}

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
                                NavigationLink {
                                    SettingsView()
                                } label: {
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()
        let navigationModel = NavigationModel()
        @State var autoRefresh: Bool = false

        return
            NavigationStack {
                HomeView(testing: false)
                    .environment(stopStore)
                    .environment(favoritesViewModel)
                    .environment(navigationModel)
            }
//            HomeDepartures(testing: true)
//            .environment(stopStore)
//            .environment(favoritesViewModel)
        
//            ContentView()
//            .environment(stopStore)
//            .environment(favoritesViewModel)
        
//            VStack {
//                Spacer()
//                SmallStopView(stop: Stop(name: "Genève, Rive", sloid: "ch:1:sloid:87061", codedidoc: "8587061", country: "CH", canton: "GE", meansOfTransport: "Bus", wgs84Coordinates: Coordinates(lon: 0.0, lat: 0.0)), autoRefresh: $autoRefresh)
//            }
//            .background(Image("tpgMap"))
//            .environment(stopStore)
//            .environment(favoritesViewModel)
        
//        VStack {
//            ClosestStopsView(autoRefresh: $autoRefresh)
//                .environment(stopStore)
//                .environment(favoritesViewModel)
//        }
    }
}

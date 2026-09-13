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
    @EnvironmentObject var tripViewModel: ItineraryViewModel
    @EnvironmentObject var navigationModel: NavigationModel
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

struct FavoriteView: View {
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var navigationModel: NavigationModel
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
                        let favorites = isExpanded ? favoritesViewModel.favoriteStops : Array(favoritesViewModel.favoriteStops.prefix(maxRows * columns.count - (isExpanded ? 0 : 1)))
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
//    @ObservedObject var path: ViewStateStack
    @EnvironmentObject var stopStore: StopStore
    @StateObject var locationManager = LocationManager()
//    @StateObject private var stopManager = StopManager()
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @State private var timer: AnyCancellable?
    @State private var closestStops: [Stop] = []
    @State private var testStop: [Stop] = [Stop(name: "Genève, Rive", sloid: "ch:1:sloid:87061", codedidoc: "8587061", country: "CH", canton: "GE", meansOfTransport: "Bus", wgs84Coordinates: Coordinates(lon: 0.0, lat: 0.0)), Stop(name: "Genève, Place des Eaux-Vives", sloid: "ch:1:sloid:87062", codedidoc: "8587062", country: "CH", canton: "GE", meansOfTransport: "Bus", wgs84Coordinates: Coordinates(lon: 0.0, lat: 0.0))]
    @State private var calculationSuccess = false
    /// Position refusée ou introuvable : sans ça l'accueil restait sur « Chargement... ».
    @State private var locationFailed = false
    @State private var currentIndex = 0
    @AppStorage("homeFavorites") var homeFavorites = false
    var testing: Bool = false
//    @State var autoRefresh = true
    
    var body: some View {
                        VStack(spacing:0) {
                            if testing {
                                ZStack {
                                TabView(selection: $currentIndex.animation()) {
                                    ForEach(0..<testStop.count, id: \.self) { index in
                                        VStack(spacing:0) {
                                            Spacer()
//                                                    Rectangle().fill(.blue).frame(height: 10)
                                            SmallStopView(stop: testStop[index], isHome: true, testing: true)
//                                                    Rectangle().fill(.blue).frame(height: 10)
                                                .padding(.bottom, 20)
//                                                        .padding(.top, 20)
                                        }
//                                                .background(Rectangle().fill(.red))
                                        
                                        .tag(index)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
//                                        .background(Rectangle().fill(.red))
                                    VStack {
                                        HStack {
                                            Text(homeFavorites ? "Départs" : "Départs à proximité")
                                                .font(.title)
                                                .bold()
                                                .padding(.leading, 15)
                                            Spacer()
                                        }
                                        Spacer()
                                        Fancy3DotsIndexView(numberOfPages: testStop.count, currentIndex: currentIndex)
                                    }
                                }
                                .frame(height: 320)
                            } else if !homeFavorites {
                                if calculationSuccess {
                                    if !closestStops.isEmpty {
                                        ZStack {
                                        TabView(selection: $currentIndex.animation()) {
                                            ForEach(0..<closestStops.count, id: \.self) { index in
                                                VStack(spacing:0) {
                                                    Spacer()
//                                                    Rectangle().fill(.blue).frame(height: 10)
                                                    SmallStopView(stop: closestStops[index], isHome: true)
//                                                    Rectangle().fill(.blue).frame(height: 10)
                                                        .padding(.bottom, 20)
//                                                        .padding(.top, 20)
                                                }
//                                                .background(Rectangle().fill(.red))
                                                
                                                .tag(index)
                                            }
                                        }
                                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
//                                        .background(Rectangle().fill(.red))
                                            VStack {
                                                HStack {
                                                    Text(homeFavorites ? "Départs" : "Départs à proximité")
                                                        .font(.title)
                                                        .bold()
                                                        .padding(.leading, 15)
                                                    Spacer()
                                                }
                                                Spacer()
                                                Fancy3DotsIndexView(numberOfPages: closestStops.count, currentIndex: currentIndex)
                                            }
                                        }
                                        .frame(height: 320)
                                        
                                    } else {
                                            Text("Pas d'arrêt à proximité trouvé.")
                                            .padding(.top, 70)
                                    }
                                } else if locationFailed {
                                        Text("Position indisponible. Autorisez la localisation pour voir les départs à proximité.")
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 70)
                                        .padding(.horizontal)
                                } else {
                                        Text("Chargement...")
                                        .padding(.top, 70)
                                }
                            } else {
                                if favoritesViewModel.favoriteStops.count > 0 {
                                    ZStack {
                                        TabView(selection: $currentIndex.animation()) {
                                            ForEach(0..<min(3, favoritesViewModel.favoriteStops.count), id: \.self) { index in
                                                let shortStop = favoritesViewModel.favoriteStops[index]
                                                VStack(spacing:0) {
                                                    Spacer()
                                                    SmallStopView(stop: createStop(nomarret: shortStop.name, sloid: shortStop.sloid) , isHome: false, testing: testing)
                                                        .padding(.bottom, 20)
                                                }
                                                .tag(index)
                                            }
                                        }
                                        .frame(height: 320)
                                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                        VStack {
                                            HStack {
                                                Text(homeFavorites ? "Départs" : "Départs à proximité")
                                                    .font(.title)
                                                    .bold()
                                                    .padding(.leading, 15)
                                                Spacer()
                                            }
                                            Spacer()
                                            Fancy3DotsIndexView(numberOfPages: min(3, favoritesViewModel.favoriteStops.count), currentIndex: currentIndex)
                                        }
                                    }
                                } else {
                                    Text("Pas d'arrets en favoris")
                                        .padding(.top, 70)
                                }
                            }
                        }
        .onAppear {
                setupLocationAndTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                setupLocationAndTimer()
        }
        .onDisappear {
            timer?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            timer?.cancel()
        }
//        .onChange(of: autoRefresh) {
//            if !autoRefresh {
//                timer?.cancel()
//            } else {
//                setupLocationAndTimer()
//            }
//        }
    }
    
    private func setupLocationAndTimer() {
        if !testing {
            getLocation()
            timer = Timer.publish(every: 30, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    getLocation()
                }
        }
    }
    
    private func getLocation() {
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
    @EnvironmentObject var tripViewModel: ItineraryViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    @StateObject var stopManager = StopManager()
    @StateObject private var lineManager = LineManager()
    @State private var timer: AnyCancellable?
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
        .onAppear {
            setupStopManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            setupStopManager()
        }
        .onDisappear {
            timer?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            timer?.cancel()
        }
        .onChange(of: stop) {
            setupStopManager()
        }
//        .onChange(of: autoRefresh) {
//            if !autoRefresh {
//                timer?.cancel()
//            } else {
//                setupStopManager()
//            }
//        }
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
                let splitStopName = splitString(stop.name, separator: ",")
                if splitStopName.1.isEmpty {
                    Text(splitStopName.0)
                        .font(.title3)
                        .bold()
                        .minimumScaleFactor(0.5)
                    if stop.meansOfTransport == "TRAIN" {
                        Image(systemName: "lightrail").font(.headline)
                    } else if stop.meansOfTransport == "BOAT" {
                        Image(systemName: "ferry").font(.headline)
                    }
                    Spacer()
                } else {
                    VStack(alignment: .leading) {
                        Text(splitStopName.0).font(.subheadline)
                        Text(splitStopName.1).font(.title3).bold()
                    }
                    .minimumScaleFactor(0.5)
                }
            }
        }
    }
    
    private func TripButton() -> some View {
        HStack {
            let menu = Group {
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
                ForEach(isQuay ? filteredEvents.sorted(by: { $0.estimatedTime < $1.estimatedTime }).prefix(3) : stopManager.stopEvents.sorted(by: { $0.estimatedTime < $1.estimatedTime }).prefix(3), id: \.id) { event in
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
        .frame(height: 170)
    }
    
    private func DeparturesTestList() -> some View {
        VStack(spacing: 0) {
            StopEventView(event: StopEvent(stopPointName: "1", stopId: "1", plannedQuay: "k", timetabledTime: "2025/09/24T17:48:00Z", estimatedTime: "", lineName: "25", origin: "1", destination: "Thônex, Vallard", transportType: "", operatorName: "Transports Publics Genevois", journeyRef: "1", operatingDayRef: ""), showTime: false, mapVersion: !isHome)
            StopEventView(event: StopEvent(stopPointName: "", stopId: "2", plannedQuay: "b", timetabledTime: "2025/09/24T17:49:00Z", estimatedTime: "", lineName: "12", origin: "", destination: "Thônex, Moillesulaz", transportType: "", operatorName: "Transports Publics Genevois", journeyRef: "1", operatingDayRef: ""), showTime: false, mapVersion: !isHome)
            StopEventView(event: StopEvent(stopPointName: "", stopId: "3", plannedQuay: "c", timetabledTime: "2025/09/24T17:50:00Z", estimatedTime: "", lineName: "17", origin: "", destination: "Lancy-Bachet, gare", transportType: "", operatorName: "Transports Publics Genevois", journeyRef: "1", operatingDayRef: ""), showTime: false, mapVersion: !isHome)
        }
        .frame(height: 170)
    }
    
    private func setupStopManager() {
        if !testing {
            stopManager.selectStop(stopName: stop.name, stopSloid: stop.sloid, stopEventNumber: stopEventNumber, timeRequest: Date())
        }
        if !testing {
            timer = Timer.publish(every: 30, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    stopManager.selectStop(stopName: stop.name, stopSloid: stop.sloid, stopEventNumber: stopEventNumber, timeRequest: Date())
                }
        }
    }
    private var filteredEvents: [StopEvent] {
        stopManager.stopEvents.filter { $0.plannedQuay == quay }
       }
}

struct HomeView: View {
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    
    @State private var isExpanded: Bool = false
    @State private var maxRows: Int = 5
    var testing: Bool
    @AppStorage("homeFavorites") var homeFavorites = false
    @AppStorage("UseCircleButton") var useCircleButton = false
        
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
                                    .frame(height: 20.0)
                                Spacer()
//                                Button(action: {
//                                    self.showSettings.toggle()
                                if #available(iOS 26, *) {
                                    NavigationLink {
                                        SettingsView()
                                    } label: {
                                        Image(systemName: "gear")
                                            .font(.title)
                                            .padding(5)
                                    }
                                    .glassEffect(.regular.interactive())
                                    .padding(.leading, 5)
                                    .padding(.trailing, 15)
                                } else {
                                    NavigationLink {
                                        SettingsView()
                                    } label: {
                                        Image(systemName: "gear")
                                            .font(.title)
                                    }
                                    .padding(.leading, 5)
                                    .padding(.trailing, 15)
                                }
                            }
                            
                            FavoriteView(isExpanded: $isExpanded, maxRows: Int((UIScreen.main.bounds.height/168).rounded()))//168 used to obtain the right amount of rows based on the screen size. 3 for the SE, 4 for the mini and 5 for regular size.
                            VStack(spacing: 0) {

                                
                                HomeDepartures(testing: testing)
//                                    .background(Rectangle().fill(.red))
                            }
                            Spacer()
                        }
                    }
                    .scrollDisabled(isExpanded ? false : true)
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
                    .environmentObject(stopStore)
                    .environmentObject(favoritesViewModel)
                    .environmentObject(navigationModel)
            }
//            HomeDepartures(testing: true)
//            .environmentObject(stopStore)
//            .environmentObject(favoritesViewModel)
        
//            ContentView()
//            .environmentObject(stopStore)
//            .environmentObject(favoritesViewModel)
        
//            VStack {
//                Spacer()
//                SmallStopView(stop: Stop(name: "Genève, Rive", sloid: "ch:1:sloid:87061", codedidoc: "8587061", country: "CH", canton: "GE", meansOfTransport: "Bus", wgs84Coordinates: Coordinates(lon: 0.0, lat: 0.0)), autoRefresh: $autoRefresh)
//            }
//            .background(Image("tpgMap"))
//            .environmentObject(stopStore)
//            .environmentObject(favoritesViewModel)
        
//        VStack {
//            ClosestStopsView(autoRefresh: $autoRefresh)
//                .environmentObject(stopStore)
//                .environmentObject(favoritesViewModel)
//        }
    }
}

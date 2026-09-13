//
//  ContentView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import SwiftUI
import Combine
import MapKit
import tpgNextFunc

enum Tabs: String, Equatable, Hashable {
    case home = "Départs"
    case trip = "Itinéraire"
    case map = "Carte"
    case search = "Recherche"
    
    var imageName: String {
            switch self {
            case .home: return "house.fill"
            case .trip: return "point.bottomleft.forward.to.point.topright.scurvepath.fill"
            case .map: return "map.fill"
            case .search: return "magnifyingglass"
            }
        }
}




class NavigationModel: ObservableObject {
    @Published var selectedTab: Tabs = .home
//    @Published var homePath: NavigationPath
    @Published var tripPath: NavigationPath
    @Published var mapPath: NavigationPath
    @Published var searchPath: NavigationPath
    
    init(selectedTab: Tabs = .home) {
        self.selectedTab = selectedTab
//        self.homePath = NavigationPath()
        self.tripPath = NavigationPath()
        self.mapPath = NavigationPath()
        self.searchPath = NavigationPath()
    }
}

/// `navigationDestination(item:)` exige `Hashable` : la donnée *est* la présentation,
/// il n'y a plus de booléen à garder synchronisé avec elle.
struct StopViewData: Identifiable, Hashable {
    let id = UUID()
    let stopID: String
    let stopName: String
    let journeyRef: String
    let estimatedTime: String
}

/// Une ligne ouverte depuis le widget. `LineView` ne consomme du `StopEvent` que
/// `journeyRef` et `operatingDayRef` pour interroger l'API : le reste sert à
/// afficher l'en-tête en attendant la réponse.
struct LineViewData: Identifiable, Hashable {
    let id = UUID()
    let event: StopEvent
    let stop: ShortStop
}

struct ContentView: View {
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var appRequirementsClass: AppRequirementsClass
    @StateObject var savedTripsModel = SavedTripsModel()
    @StateObject var regularTripsModel = RegularTripsModel()
    @StateObject var itineraryViewModel = ItineraryViewModel()
    @StateObject private var keyboardResponder = KeyboardResponder()
    @StateObject private var tripManager = TripManager()
    @StateObject var notificationConfirmationViewModel = NotificationConfirmationViewModel.shared
    @StateObject var locationManager = LocationManager()
    @StateObject var navigationModel = NavigationModel()
    
    @State private var selectedStopViewData: StopViewData? = nil
    @State private var selectedLineViewData: LineViewData? = nil
    
    @State private var viewingTrip = false
    @State private var showMenu = false
    @AppStorage("ShowWelcome") var showWelcome = true
    @AppStorage(WhatsNew.lastSeenKey) var lastSeenWhatsNew = ""
    @State private var showWhatsNew = false
    @State var autoRefresh = true
    @AppStorage("UseCircleButton") var useCircleButton = false
    
    var testingNewDock: Bool = false
    
    @State var lastUsedTime: Date?
    @SwiftUICore.Environment(\.scenePhase) var scenePhase
    
    @State var homePath = NavigationPath()
    
    var body: some View {
        ZStack {
                TabView(selection: $navigationModel.selectedTab) {
                    Tab("Départs", systemImage: "house", value: .home) {
                        NavigationStack() {
                            HomeView(testing: !autoRefresh)
//                                .background(Background())
                                // Doivent rester à l'intérieur du NavigationStack : appliquées
                                // sur la pile elle-même, les destinations ne sont jamais poussées.
                                .navigationDestination(item: $selectedStopViewData) { data in
                                    StopView(
                                        stopName: data.stopName,
                                        stopSloid: data.stopID,
                                        previousLineRef: data.journeyRef.isEmpty ? nil : data.journeyRef,
                                        previousLineName: nil,
                                        // Vide quand l'ouverture vient du widget : aucun départ à mettre en avant.
                                        previousLineTime: data.estimatedTime.isEmpty ? nil : data.estimatedTime
                                    )
                                }
                                .navigationDestination(item: $selectedLineViewData) { data in
                                    LineView(stopEvent: data.event,
                                             currentStop: data.stop,
                                             currentLine: data.event.lineName)
                                }
                        }
                        .toolbar(appRequirementsClass.version26 ? .automatic : .hidden, for: .tabBar)
                    }
                    Tab("Itinéraire", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath", value: .trip) {
                        NavigationStack() {
                            TripView(tripManager: tripManager)
//                                .background(Background())
                        }
                        .toolbar(appRequirementsClass.version26 ? .automatic : .hidden, for: .tabBar)
//                        .id(navigationModel.tripNavigationId)
                        .environmentObject(savedTripsModel)
                        .environmentObject(regularTripsModel)
                    }
                    Tab("Carte", systemImage: "map", value: .map) {
                        NavigationStack() {
                            MapView()
                        }
                        .toolbar(appRequirementsClass.version26 ? .automatic : .hidden, for: .tabBar)
                    }
                    Tab(value: .search, role: .search) {
                        NavigationStack() {
                            SearchView()
                        }
                        .environmentObject(savedTripsModel)
                        .toolbar(appRequirementsClass.version26 ? .automatic : .hidden, for: .tabBar)
                    }
                }
                .environmentObject(itineraryViewModel)
                .environmentObject(navigationModel)
                .environmentObject(appRequirementsClass)
            if #available(iOS 26, *), !testingNewDock {
            } else {
                if !(keyboardResponder.isKeyboardVisible && navigationModel.selectedTab != .search) {
                    VStack {
                        Spacer()
                        DockView()
                            .padding(.bottom)
                            .environmentObject(navigationModel)
                            .offset(y: keyboardResponder.isKeyboardVisible ? 0 : 20)
                            .background {
                                Capsule()
                                    .fill(.gray)
                                    .blur(radius: 10)
                                    .opacity(keyboardResponder.isKeyboardVisible ? 0.3 : 0)
                            }
                    }
//                    .ignoresSafeArea(edges: .bottom)
                }
            }
            
            VStack {
                if notificationConfirmationViewModel.showConfirmation {
                    Rectangle()
                        .frame(height:70)
                        .foregroundStyle(.clear)
                    VStack {
                        HStack {
                            if notificationConfirmationViewModel.errorMessage {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.accent)
                            }
                            Text(notificationConfirmationViewModel.confirmationMessage)
                        }
                        .padding()
                        
                        .background(BasicElement())
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.5))) // Animation when it appears/disappears
                }
                Spacer()
//                if !keyboardResponder.isKeyboardVisible {
                    //                        switch useCircleButton {
                    //                        case true:
                    //                            CircleView(stopStore: stopStore, currentView: $currentView, path: path, showMenu: $showMenu, showSettings: $showSettings, showSearch: $showSearch)
                    //                        case false:
                    //                            Dock(stopStore: stopStore, currentView: $currentView, path: path, showMenu: $showMenu, showSettings: $showSettings, showSearch: $showSearch)
                    //                        }
                    //                        ClassicDock(stopStore: stopStore, currentView: $currentView, path: path)
//                }
            }
            //                .sheet(isPresented: $showSearch) {
            //                    SearchView(showSearch: $showSearch)
            //                        .presentationDetents([.fraction(0.9)])
            //                        .presentationCornerRadius(35)
            //                        .presentationBackground(.thinMaterial)
            //                        .environmentObject(stopStore)
            //                        .navigationTitle("Recherche") // Set back button text
            //                        .navigationBarTitleDisplayMode(.inline)
            //                        .toolbar {
            //                            ToolbarItem(placement: .principal) {
            //                                Text("") // Visible title
            //                            }
            //                        }
            //                }
        }
                .sheet(isPresented: $showWelcome) {
                    WelcomeView(viewingWelcome: $showWelcome)
                        .presentationDetents([.large])
                        .presentationCornerRadius(35)
//                        .presentationBackground(.thinMaterial)
                        .interactiveDismissDisabled()
                        .onAppear {
                            autoRefresh = false
                        }
                }
//                .onChange(of: showSettings) {
//                    if showSettings {
//                        autoRefresh = false
//                    } else {
//                        autoRefresh = true
//                    }
//                }
                .onChange(of: showWelcome) {
                    if showWelcome {
                        autoRefresh = false
                    } else {
                        autoRefresh = true
                    }
                }
                // Un nouvel utilisateur passe par la bienvenue : l'annonce en cours
                // ne le concerne pas, on la marque comme vue.
                .sheet(isPresented: $showWhatsNew, onDismiss: {
                    lastSeenWhatsNew = WhatsNew.current?.id ?? lastSeenWhatsNew
                }) {
                    if let whatsNew = WhatsNew.current {
                        WhatsNewView(whatsNew: whatsNew)
                            .presentationDetents([.large])
                            .presentationCornerRadius(35)
                    }
                }
                .task {
                    guard let whatsNew = WhatsNew.current,
                          lastSeenWhatsNew != whatsNew.id else { return }
                    if showWelcome {
                        lastSeenWhatsNew = whatsNew.id
                    } else {
                        showWhatsNew = true
                    }
                }
        //open StopView directly from a notification, with the time of arrival and event ref to have it at the top.
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveNotification)) { notification in
            if let userInfo = notification.userInfo,
               let stopID = userInfo["stopID"] as? String,
               let stopName = userInfo["stopName"] as? String,
               let journeyRef = userInfo["journeyRef"] as? String,
               let estimatedTime = userInfo["estimatedTime"] as? String {
                selectedStopViewData = StopViewData(
                    stopID: stopID,
                    stopName: stopName,
                    journeyRef: journeyRef,
                    estimatedTime: estimatedTime
                )
                selectedLineViewData = nil
                navigationModel.selectedTab = .home
            }
        }
        // Ouverture depuis le widget :
        //   tpgnext://stop?sloid=…&name=…
        //   tpgnext://line?journeyRef=…&operatingDayRef=…&line=…&sloid=…
        .onOpenURL { url in
            guard url.scheme == "tpgnext",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
            func query(_ name: String) -> String? {
                components.queryItems?.first { $0.name == name }?.value
            }
            guard let sloid = query("sloid"), !sloid.isEmpty else { return }
            // Le nom transporté par l'URL peut être périmé : la base gagne quand elle résout.
            let stopName = stopStore.findStop(id: sloid)?.name ?? query("name") ?? ""

            switch url.host {
            case "stop":
                selectedLineViewData = nil
                selectedStopViewData = StopViewData(
                    stopID: sloid,
                    stopName: stopName,
                    journeyRef: "",
                    estimatedTime: ""
                )
            case "line":
                guard let journeyRef = query("journeyRef"), !journeyRef.isEmpty else { return }
                let event = createEssentialStopEvent(
                    journeyRef: journeyRef,
                    operatingDayRef: query("operatingDayRef") ?? "",
                    stopPointName: stopName,
                    stopId: sloid,
                    lineName: query("line"),
                    origin: nil,
                    destination: query("destination"),
                    transportType: query("transportType"),
                    operatorName: query("operator")
                )
                selectedStopViewData = nil
                selectedLineViewData = LineViewData(
                    event: event,
                    stop: ShortStop(name: stopName, sloid: sloidHarmonizer(code: sloid))
                )
            default:
                return
            }
            navigationModel.selectedTab = .home
        }
            .onChange(of: scenePhase) {
                            if scenePhase == .inactive {
                                if lastUsedTime == nil {
                                    lastUsedTime = Date()
                                }
                               
                            } else if scenePhase == .active {
                                if lastUsedTime?.timeIntervalSinceNow ?? 0 < -3600 { //if the app hasn't been used for over an hour, reset to home, remove any trip search and results
                                    withAnimation {
                                        navigationModel.selectedTab = .home
                                    }
//                                    path.path.removeAll()
                                    
                                    itineraryViewModel.resetModel()
                                    tripManager.tripEvents.removeAll()
                                }
                                lastUsedTime = nil
                            } else if scenePhase == .background {
                                
                            }
                        }
    }
}


class KeyboardResponder: ObservableObject {
    @Published var isKeyboardVisible = false
    private var cancellable: AnyCancellable?

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }

        cancellable = Publishers.Merge(willShow, willHide)
            .assign(to: \.isKeyboardVisible, on: self)
    }

    deinit {
        cancellable?.cancel()
    }
}

struct DockView: View {
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var stopStore: StopStore
    @Namespace var animationNamespace
    
    @State var previousMainTab: Tabs = .home
    @State var searchText: String = ""
    
    @FocusState private var searchFocus: Bool
    

    var body: some View {
        let search = navigationModel.selectedTab == .search
        HStack {
                HStack {
                        if !search || (search && previousMainTab == .home) {
                            ZStack {
                                if navigationModel.selectedTab == .home {
                                    Capsule()
                                        .fill(.gray.opacity(0.1))
                                        .stroke(Color.accent.opacity(0.4), lineWidth: 2)
                                        .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
                                        .matchedGeometryEffect(id: "activeTab", in: animationNamespace)
                                }
                                dockButton(previousMainTab: $previousMainTab, searchFocus: $searchFocus, tab: .home)

                            }
                            .frame(width: !search ? 90 : 40)
                        }
                    if !search || (search && previousMainTab == .trip) {
                        ZStack {
                            if navigationModel.selectedTab == .trip {
                                Capsule()
                                    .fill(.gray.opacity(0.1))
                                    .stroke(Color.accent.opacity(0.4), lineWidth: 2)
                                    .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
                                    .matchedGeometryEffect(id: "activeTab", in: animationNamespace)
                            }
                            dockButton(previousMainTab: $previousMainTab, searchFocus: $searchFocus, tab: .trip)
                        }
                        .frame(width: !search ? 90 : 40)
                    }
                        if !search || (search && previousMainTab == .map) {
                            ZStack {
                                if navigationModel.selectedTab == .map {
                                    Capsule()
                                        .fill(.gray.opacity(0.1))
                                        .stroke(Color.accent.opacity(0.4), lineWidth: 2)
                                        .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
                                        .matchedGeometryEffect(id: "activeTab", in: animationNamespace)
                                }
                                dockButton(previousMainTab: $previousMainTab, searchFocus: $searchFocus, tab: .map)
                            }
                            .frame(width: !search ? 90 : 40)
                    }
                }
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 40)
                        .fill(.thinMaterial)
                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                )
                .frame(height: !search ? 60 : 50)
            
            
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(search ? .callout : .title2)
                        .foregroundStyle(search ? .gray : .primary)
                    if search {
                        TextField("Rechercher un arrêt", text: $searchText)
                            .focused($searchFocus)
                    }
                }
                        .padding()
                        .padding(5)
                        .frame(width: search ? nil : 60, height: search ? 50 : 60)
                        .background(
                            Capsule() 
                                .fill(.thinMaterial)
                                .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                        )
                        .onTapGesture {
                            searchText = ""
                            if search {
                                withAnimation(.spring()) {
                                    searchFocus = true
                                }
                            } else {
                                withAnimation(.spring(duration: 0.3)) {
                                    navigationModel.selectedTab = .search
                                }
                            }
                        }
            
            if (searchFocus || searchText != "") && search {
                    Button(action: {
                        withAnimation(.spring()) {
                            searchFocus = false
                            searchText = ""
                            stopStore.searchText = ""
                        }
                    }, label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                    })
                    .transition(.slide)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .padding(5)
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                    )
                }
        }
        .padding(.horizontal)
        .sensoryFeedback(.selection, trigger: navigationModel.selectedTab)
        .onChange(of: searchText) {
            stopStore.searchText = searchText
        }
        .onAppear {
            stopStore.searchText = searchText
        }
    }

    struct dockButton: View {
        @EnvironmentObject var navigationModel: NavigationModel
        @Binding var previousMainTab: Tabs
        var searchFocus: FocusState<Bool>.Binding
        let tab: Tabs

        
        var body: some View {
            let search = navigationModel.selectedTab == .search
            Button(action: {
                if navigationModel.selectedTab == tab {
                    resetNavigation()
                } else {
                    
                    withAnimation(.spring(duration: 0.3)) {
                        searchFocus.wrappedValue = false
                        navigationModel.selectedTab = tab
                        previousMainTab = tab
                    }
                }
            }) {
                    VStack(spacing: 5) {
                        Image(systemName: tab.imageName).font(.title2)
                        if !search {
                            Text(tab.rawValue).font(.caption2)
                        }
                    }
//                    .symbolEffect(.bounce, value: navigationModel.selectedTab == tab)
                    .foregroundStyle(navigationModel.selectedTab == tab ? .accent : .primary)
//                    .matchedGeometryEffect(id: "icon-\(systemImage)", in: animationNamespace)
//                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: navigationModel.selectedTab)
            }
            .frame(width: !search ? nil : 40, height: !search ? 50 : 40)
        }
        func saveNavigation() {
            switch tab {
                case .home:
                navigationModel.tripPath = NavigationPath()
                case .trip:
                    navigationModel.tripPath = NavigationPath()
                case .map:
                    navigationModel.mapPath = NavigationPath()
                case .search:
                    navigationModel.searchPath = NavigationPath()
            }
        }
        func resetNavigation() {
            switch tab {
                case .home:
                    navigationModel.tripPath = NavigationPath()
                case .trip:
                    navigationModel.tripPath = NavigationPath()
                case .map:
                    navigationModel.mapPath = NavigationPath()
                case .search:
                    navigationModel.searchPath = NavigationPath()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        @StateObject var favoritesViewModel = FavoritesViewModel()
        @StateObject var appRequirementsClass = AppRequirementsClass()
        
        return ContentView(testingNewDock: false)
//        return DockTestView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
            .environmentObject(appRequirementsClass)
        
        
//            .mask {
//                Rectangle()
//                    .overlay(alignment: .bottom) {
//                        LinearGradient(colors: [.black, .clear], startPoint: UnitPoint(x: 0, y: 1), endPoint: UnitPoint(x: 0, y: 0))
//                            .frame(height: 100)
////                            .frame(width: width)
//                            .blendMode(.destinationOut)
//
//                    }
//            }
    
//            .background(Image("tpgMap"))
            
    }
}

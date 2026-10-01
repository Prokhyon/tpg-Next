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
    case home = "Accueil"
    case trip = "Itinéraire"
    /// Mes itinéraires : enregistrés et réguliers.
    case trips = "Trajets"
    case search = "Recherche"

    /// Pour le dock d'avant iOS 26. Les trajets ont un symbole de l'app, pas un symbole système.
    var image: Image {
        switch self {
        case .home: Image(systemName: "house.fill")
        case .trip: Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
        case .trips: Image("scurvepath.stack.fill")
        case .search: Image(systemName: "magnifyingglass")
        }
    }
}




extension View {
    /// Choisir l'onglet Recherche active aussitôt son champ (iOS 26). Sans effet avant.
    @ViewBuilder func searchTabActivatesField() -> some View {
        if #available(iOS 26, *) {
            tabViewSearchActivation(.searchTabSelection)
        } else {
            self
        }
    }
}

@Observable
class NavigationModel {
    var selectedTab: Tabs = .home {
        // La carte plein écran couvre les onglets : un itinéraire lancé depuis elle
        // (bouton d'un arrêt) doit la refermer pour laisser voir l'onglet Itinéraire.
        didSet { if selectedTab != .home { showsFullMap = false } }
    }
    /// Le filtre de l'onglet Trajets : une notification de trajet régulier l'ouvre sur les réguliers.
    var tripsFilter: SavedTripsFilter = .all
    /// La carte des arrêts en plein écran, ouverte depuis l'accueil.
    var showsFullMap = false
    /// Texte de l'onglet Recherche, partagé par son champ et celui du dock (avant iOS 26).
    var searchQuery = ""
    /// Les écrans ouverts par-dessus chaque onglet.
    private var paths: [Tabs: [AppRoute]] = [:]
    /// Identité de la pile de chaque onglet : la changer recrée aussi la racine (l'itinéraire
    /// repart ainsi de son état initial quand on y envoie un arrêt).
    private var stackResets: [Tabs: Int] = [:]

    init(selectedTab: Tabs = .home) {
        self.selectedTab = selectedTab
    }

    func stackID(_ tab: Tabs) -> Int {
        stackResets[tab, default: 0]
    }

    func path(for tab: Tabs) -> Binding<[AppRoute]> {
        Binding(get: { self.paths[tab, default: []] },
                set: { self.paths[tab] = $0 })
    }

    func open(_ route: AppRoute, in tab: Tabs) {
        // Toucher deux fois le même widget ou rappel n'empile pas deux fois le même écran.
        guard paths[tab]?.last != route else { return }
        paths[tab, default: []].append(route)
    }

    /// L'onglet Trajets, revenu à sa liste, sur ce filtre.
    func showTrips(_ filter: SavedTripsFilter = .all) {
        paths[.trips] = []
        tripsFilter = filter
        selectedTab = .trips
    }

    func popToRoot(_ tab: Tabs) {
        paths[tab] = []
        stackResets[tab, default: 0] += 1
    }
}

/// La pile d'un onglet : elle sait afficher toutes les routes et les ouvre chez elle.
private struct TabStack<Root: View>: View {
    @Environment(NavigationModel.self) private var navigationModel
    let tab: Tabs
    @ViewBuilder var root: Root

    var body: some View {
        NavigationStack(path: navigationModel.path(for: tab)) {
            root.appRouteDestinations()
        }
        .environment(\.openRoute, OpenRouteAction { navigationModel.open($0, in: tab) })
        .departureActionSheets()
        // Toutes les pages qui défilent, et leurs feuilles : le dégradé doux sous la barre.
        .softTopScrollEdge()
        .id(navigationModel.stackID(tab))
        .toolbar(TPGSurface.isGlass ? .automatic : .hidden, for: .tabBar)
    }
}

struct ContentView: View {
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @State var savedTripsModel = SavedTripsModel()
    /// Partagée avec la tâche de fond et les notifications des trajets réguliers.
    @State var regularTripsModel = RegularTripsModel.shared
    /// Une seule instance, partagée par la recherche et l'itinéraire : chacun avait la sienne.
    @State var recentSearchModel = RecentSearch()
    @State var itineraryViewModel = ItineraryViewModel()
    @State private var keyboardResponder = KeyboardResponder()
    @State private var tripManager = TripManager()
    @State var notificationConfirmationViewModel = NotificationConfirmationViewModel.shared
    @State var navigationModel = NavigationModel()
    /// Le trajet suivi, affiché en bandeau sous les onglets.
    private var liveActivities = TripLiveActivities.shared
    /// Le trajet suivi ouvert en plein écran par-dessus l'app.
    @State private var liveTrip = LiveTripPresentation.shared
    
    
    @AppStorage(SettingKey.showWelcome) var showWelcome = true
    @AppStorage(WhatsNew.lastSeenKey) var lastSeenWhatsNew = ""
    @State private var showWhatsNew = false
    #if DEBUG
    /// Une feuille ouverte par `tpgnext://sheet?name=…` pour les captures.
    @State private var debugSheet: DebugSheet?
    #endif
    @State var autoRefresh = true
    
    var testingNewDock: Bool = false
    
    @State var lastUsedTime: Date?
    @SwiftUICore.Environment(\.scenePhase) var scenePhase
    
    
    var body: some View {
        ZStack {
                TabView(selection: Bindable(navigationModel).selectedTab) {
                    Tab("Accueil", systemImage: "house", value: .home) {
                        TabStack(tab: .home) {
                            HomeView(testing: !autoRefresh)
                        }
                    }
                    Tab("Itinéraire", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath", value: .trip) {
                        TabStack(tab: .trip) {
                            TripView(tripManager: tripManager)
                                .singleColumnWhenFoldedPortrait()
                        }
                    }
                    Tab("Trajets", image: "scurvepath.stack.fill", value: .trips) {
                        TabStack(tab: .trips) {
                            SavedTripsView(filter: Bindable(navigationModel).tripsFilter)
                        }
                    }
                    Tab(value: .search, role: .search) {
                        TabStack(tab: .search) {
                            SearchView()
                        }
                    }
                }
                // Au niveau des onglets : une route (un itinéraire, par exemple) peut s'ouvrir dans n'importe lequel.
                .environment(savedTripsModel)
                .environment(regularTripsModel)
                .environment(itineraryViewModel)
                .environment(recentSearchModel)
                .environment(navigationModel)
                .searchTabActivatesField()
                // iOS 26 : le bandeau du trajet suivi s'attache aux onglets, comme dans Musique.
                .liveTripAccessory()
            if #available(iOS 26, *), !testingNewDock {
            } else {
                if !(keyboardResponder.isKeyboardVisible && navigationModel.selectedTab != .search) {
                    VStack {
                        Spacer()
                        // Avant iOS 26, le bandeau du trajet suivi flotte au-dessus du dock.
                        if let current = liveActivities.current {
                            TripLiveAccessory(key: current.key, live: current.trip)
                                .frame(height: 52)
                                .background(Capsule().fill(.thinMaterial).shadow(color: .customShadows, radius: 2, y: 1.5))
                                .padding(.horizontal, 20)
                                .padding(.bottom, 4)
                        }
                        DockView()
                            .padding(.bottom)
                            .environment(navigationModel)
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
            //                        .environment(stopStore)
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
                    WelcomeView(viewingWelcome: $showWelcome) {
                        navigationModel.open(.userGuide, in: navigationModel.selectedTab)
                    }
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
                        // Le choix d'iCloud est fait : la synchro peut commencer (ou non).
                        CloudSync.settingChanged()
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
        // `initial` : au lancement à froid, l'ouverture est déposée avant que cette vue n'existe.
        .onChange(of: PendingNotificationOpen.shared.route, initial: true) {
            guard let route = PendingNotificationOpen.shared.route else { return }
            PendingNotificationOpen.shared.route = nil
            // Le trajet suivi s'ouvre en plein écran, comme depuis le bandeau.
            if case let .liveTrip(key) = route {
                liveTrip.open(key)
                return
            }
            switch route {
            case .savedTrips: navigationModel.showTrips()
            case .regularTrips: navigationModel.showTrips(.regular)
            default:
                let tab = Self.tab(for: route)
                navigationModel.open(route, in: tab)
                navigationModel.selectedTab = tab
            }
        }
        // Le bandeau s'ouvre en plein écran, et se referme en glissant vers le bas.
        .sheet(isPresented: Bindable(liveTrip).isOpen) {
            if let key = liveTrip.openedKey {
                LiveTripView(key: key)
                    .departureActionSheets()
                    .presentationDragIndicator(.visible)
            }
        }
        #if DEBUG
        .sheet(item: $debugSheet) { sheet in
            switch sheet {
            case .reminder:
                ReminderSheet(event: PreviewData.departure(inMinutes: 12), stopID: PreviewData.rive.sloid)
            case .newRegular:
                NewRegularTripView()
                    .environment(regularTripsModel)
            case .editRegular:
                RegularTripEditor(trip: RegularTrip(trip: PreviewData.tripWithTransfer, weekdays: Weekday.workdays))
                    .environment(regularTripsModel)
            }
        }
        #endif
        .onOpenURL { handleOpenURL($0) }
        // Au premier plan, chaque minute : temps réel des trajets réguliers proches, rappels,
        // alertes et activités en direct (qui ne sont mises à jour que par l'app).
        .periodicRefresh(every: .seconds(60)) { _ in
            Task {
                await regularTripsModel.refresh()
                UpcomingTripsPublisher.publish(regular: regularTripsModel, saved: savedTripsModel)
            }
            liveActivities.startSoonDepartingSavedTrips(of: savedTripsModel)
        }
        // Un trajet ajouté, modifié ou supprimé : le widget « Prochain trajet » suit aussitôt.
        .onChange(of: savedTripsModel.savedTrips) {
            UpcomingTripsPublisher.publish(regular: regularTripsModel, saved: savedTripsModel)
        }
        .onChange(of: regularTripsModel.regularTrips) {
            UpcomingTripsPublisher.publish(regular: regularTripsModel, saved: savedTripsModel)
        }
        .task {
            savedTripsModel.startCloudSync()
            savedTripsModel.scheduleNotifications()
        }
        #if DEBUG
        .task { openDebugURLs() }
        #endif
            .onChange(of: scenePhase) {
                            if scenePhase == .inactive {
                                if lastUsedTime == nil {
                                    lastUsedTime = Date()
                                }
                               
                            } else if scenePhase == .active {
                                // Les alertes reçues pendant l'absence de l'app, dont le moment est passé.
                                NotificationExpiry.clearExpired()
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
                                regularTripsModel.scheduleBackgroundRefresh()
                            }
                        }
    }
    /// L'onglet où ouvrir une route venue de l'extérieur (notification) : les itinéraires dans
    /// l'onglet Trajets, par-dessus leur liste, le reste dans Départs.
    private static func tab(for route: AppRoute) -> Tabs {
        switch route {
        case .savedTrips, .regularTrips, .trip, .tripMap: .trips
        default: .home
        }
    }

    // Ouverture depuis le widget :
    //   tpgnext://stop?sloid=…&name=…
    //   tpgnext://line?journeyRef=…&operatingDayRef=…&line=…&sloid=…
    //   tpgnext://regulartrips   tpgnext://livetrip?key=…   (activité en direct)
    //   tpgnext://savedtrips
    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "tpgnext",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        if url.host == "savedtrips" {
            navigationModel.showTrips()
            return
        }
        if url.host == "regulartrips" || url.host == "livetrip" {
            // Toucher l'activité en direct ouvre le suivi, comme le bandeau.
            let key = components.queryItems?.first { $0.name == "key" }?.value
            if let key, TripLiveActivities.shared.isTracking(key) {
                liveTrip.open(key)
            } else {
                navigationModel.showTrips(.regular)
            }
            return
        }
        func query(_ name: String) -> String? {
            components.queryItems?.first { $0.name == name }?.value
        }
        guard let sloid = query("sloid"), !sloid.isEmpty else { return }
        // Le nom transporté par l'URL peut être périmé : la base gagne quand elle résout.
        let stopName = stopStore.findStop(id: sloid)?.name ?? query("name") ?? ""

        switch url.host {
        case "stop":
            // `journeyRef` (facultatif) met une course en avant, comme à l'ouverture depuis un rappel.
            let highlight = query("journeyRef").map { DepartureHighlight(journeyRef: $0) }
            navigationModel.open(.stop(name: stopName, sloid: sloid, highlight: highlight), in: .home)
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
            navigationModel.open(.line(event: event, currentStop: ShortStop(name: stopName, sloid: sloidHarmonizer(code: sloid))), in: .home)
        default:
            return
        }
        navigationModel.selectedTab = .home
    }

    #if DEBUG
    /// Captures et vérifications sans toucher l'écran : `TPG_DEBUG_URLS` liste des liens séparés par
    /// des espaces, ouverts dans l'ordre au lancement. En plus des liens du widget :
    ///   tpgnext://tab?name=home|trip|trips|search   tpgnext://settings   tpgnext://map   tpgnext://lines   tpgnext://guide[?topic=…]
    ///   tpgnext://homelayout   tpgnext://places   tpgnext://sheet?name=reminder|newRegular|editRegular
    private func openDebugURLs() {
        guard let list = ProcessInfo.processInfo.environment["TPG_DEBUG_URLS"] else { return }
        for url in list.split(separator: " ").compactMap({ URL(string: String($0)) }) {
            switch url.host {
            case "tab":
                let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
                navigationModel.selectedTab = [Tabs.home, .trip, .trips, .search].first { "\($0)" == name } ?? .home
            case "settings":
                navigationModel.open(.settings, in: navigationModel.selectedTab)
            case "homelayout":
                navigationModel.open(.homeLayout, in: navigationModel.selectedTab)
            case "places":
                navigationModel.open(.favoritePlacesOrder, in: navigationModel.selectedTab)
            case "sheet":
                // tpgnext://sheet?name=reminder|newRegular|editRegular
                let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value ?? ""
                debugSheet = DebugSheet(rawValue: name)
            case "map":
                navigationModel.selectedTab = .home
                navigationModel.showsFullMap = true
            case "lines":
                navigationModel.selectedTab = .search
                navigationModel.open(.lines, in: .search)
            case "guide":
                // tpgnext://guide, ou tpgnext://guide?topic=stop pour une rubrique.
                let topic = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
                navigationModel.open(topic.map { .userGuideTopic(id: $0) } ?? .userGuide, in: navigationModel.selectedTab)
            default:
                handleOpenURL(url)
            }
        }
    }
    #endif
}

#if DEBUG
private enum DebugSheet: String, Identifiable {
    case reminder, newRegular, editRegular
    var id: String { rawValue }
}
#endif


@Observable
class KeyboardResponder {
    var isKeyboardVisible = false
    @ObservationIgnored private var cancellable: AnyCancellable?

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
    @Environment(NavigationModel.self) var navigationModel
    @Environment(StopStore.self) var stopStore
    @Namespace var animationNamespace
    
    @State var previousMainTab: Tabs = .home
    
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
                        if !search || (search && previousMainTab == .trips) {
                            ZStack {
                                if navigationModel.selectedTab == .trips {
                                    Capsule()
                                        .fill(.gray.opacity(0.1))
                                        .stroke(Color.accent.opacity(0.4), lineWidth: 2)
                                        .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
                                        .matchedGeometryEffect(id: "activeTab", in: animationNamespace)
                                }
                                dockButton(previousMainTab: $previousMainTab, searchFocus: $searchFocus, tab: .trips)
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
                        TextField("Arrêts, lieux, itinéraires", text: Bindable(navigationModel).searchQuery)
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
                            navigationModel.searchQuery = ""
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
            
            if (searchFocus || navigationModel.searchQuery != "") && search {
                    Button(action: {
                        withAnimation(.spring()) {
                            searchFocus = false
                            navigationModel.searchQuery = ""
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
    }

    struct dockButton: View {
        @Environment(NavigationModel.self) var navigationModel
        @Binding var previousMainTab: Tabs
        var searchFocus: FocusState<Bool>.Binding
        let tab: Tabs

        
        var body: some View {
            let search = navigationModel.selectedTab == .search
            Button(action: {
                if navigationModel.selectedTab == tab {
                    navigationModel.popToRoot(tab)
                } else {
                    
                    withAnimation(.spring(duration: 0.3)) {
                        searchFocus.wrappedValue = false
                        navigationModel.selectedTab = tab
                        previousMainTab = tab
                    }
                }
            }) {
                    VStack(spacing: 5) {
                        tab.image.font(.title2)
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
    }
}

#Preview("App") {
    ContentView()
        .previewSettings([SettingKey.showWelcome: false, WhatsNew.lastSeenKey: WhatsNew.current?.id ?? ""])
        .previewEnvironment(navigation: false)
}

#Preview("App — iPad", traits: .iPadLandscape) {
    ContentView()
        .previewSettings([SettingKey.showWelcome: false, WhatsNew.lastSeenKey: WhatsNew.current?.id ?? ""])
        .previewEnvironment(navigation: false)
}

#Preview("App — premier lancement") {
    // Bienvenue, puis nouveautés.
    ContentView()
        .previewSettings([SettingKey.showWelcome: true])
        .previewEnvironment(navigation: false, favorites: [])
}

#Preview("Dock (avant iOS 26)") {
    VStack {
        Spacer()
        DockView()
            .padding(.bottom)
    }
    .previewEnvironment(navigation: false)
}

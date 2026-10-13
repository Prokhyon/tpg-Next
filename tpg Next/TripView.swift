//
//  TripView.swift
//  TPG4
//
//  Created by Loris Thomas on 30.06.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc

struct TripView: View {
    var tripManager = TripManager()
    @Environment(SavedTripsModel.self) var savedTripsModel
    @Environment(ItineraryViewModel.self) var viewModel
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @State private var locationViewModel = LocationSearchViewModel()
    @State var locationManager = LocationManager()
    @Environment(RecentSearch.self) var recentSearchModel
    /// Hauteur des champs et de la carte de recherche : les listes de résultats s'arrêtent au-dessus.
    @State private var searchOverlayHeight: CGFloat = 0

    
    @FocusState var focusField: TripField?
    
    @State private var showCloseStops = false
    @State private var timeRequest = AppClock.now()
    
    @State private var closestStops: [Stop] = []
    @State private var calculationSuccess = false
    @State private var userPosition: CLLocation?
    
    @State private var showTime = true
    @Environment(\.layout) private var layout
    /// Sur grand écran, le trajet détaillé dans la moitié droite.
    @State private var selectedTrip: TripEvent?
    
    @Namespace private var animation
    @State private var switchAnimate: Bool = false
    @State private var switchRotation: Bool = false
    
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    /// La carte a pris l'onglet Trajets : leur liste s'ouvre d'ici.
    @AppStorage(SettingKey.mapTab) private var mapTab = false
    @Environment(\.openRoute) private var openRoute
    
    enum Results {
        case empty, favorites, search, closeStops, tripResults, loading, error
    }
    
    @State var results = Results.favorites
    
    var body: some View {
        AdaptiveSplit {
            ZStack {
                VStack {
                        let resultsView = VStack {switch results {
                        case .empty:
                            ResultsEmptyView()
                        case .favorites:
    //                        ListView()
                            ResultsFavoritesView(viewModel: viewModel, results: $results)
                                .environment(recentSearchModel)
                        case.search:
                            ResultsSearchView(viewModel: viewModel, locationViewModel: locationViewModel, results: $results, focusField: $focusField)
                                .environment(recentSearchModel)
                        case.closeStops:
                            ResultsCloseStopsView(viewModel: viewModel, calculationSuccess: $calculationSuccess, showCloseStops: $showCloseStops, closestStops: $closestStops, results: $results)
                        case.tripResults:
                            AvoidedLinesBar(viewModel: viewModel, search: searchTrips)
                            ResultsTripView(viewModel: viewModel, tripManager: tripManager, showTime: $showTime, adjustTime: adjustTime, timeChange: timeChange, searchTrips: searchTrips,
                                            selectedID: selectedTrip?.id, onSelect: layout.showsSecondaryPane ? { trip in
                                                // Retoucher l'itinéraire détaillé le désélectionne.
                                                withAnimation { selectedTrip = selectedTrip?.id == trip.id ? nil : trip }
                                            } : nil)
                        case.loading:
                            Rectangle()//Placé suite à un bug d'affichage du titre. A tester sans hors beta
                                .opacity(0)
                                .frame(height: 50)
                        
                            // Les itinéraires attendus, en rangées fantômes.
                            LoadingPlaceholder(kind: .trip, count: 4)
                        case.error:
                            Rectangle()//Placé suite à un bug d'affichage du titre. A tester sans hors beta
                                .opacity(0)
                                .frame(height: 50)
                        
                                Text(tripManager.failure?.userMessage
                                     ?? (viewModel.avoidedLines.isEmpty ? "Aucun itinéraire trouvé" : "Aucun itinéraire n'évite ces lignes"))
                            AvoidedLinesBar(viewModel: viewModel, search: searchTrips)
                        }
                    }
                    if #available(iOS 26, *) {
                        ScrollView {
                            resultsView
                        }
                        .scrollEdgeEffectStyle(.soft, for: .top)
    //                    .scrollDismissesKeyboard(.immediately)
    //                    .contentMargins(.top, 320.0, for: .automatic)
                        // Au moins la hauteur des champs et de la carte de recherche, qui grandit avec le texte.
                        .contentMargins(.bottom, (results == .tripResults) ? max(340, searchOverlayHeight + 70) : (focusField != nil) ? 70 : max(270, searchOverlayHeight), for: .automatic)
                        // Titre compact sur grand écran : la première ligne passait sous les barres.
                        .contentMargins(.top, layout.showsSecondaryPane ? 12 : 0, for: .automatic)
                        .readableScrollContent()
                    } else {
                        ScrollView {
                            resultsView
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .contentMargins(.bottom, (results == .tripResults || focusField != nil) ? max(340, searchOverlayHeight + 70) : (focusField != nil) ? 70 : max(270, searchOverlayHeight), for: .automatic)
                        .contentMargins(.bottom, TPGSurface.isGlass ? 0: 75, for: .automatic)
                        .readableScrollContent()
                    }
                }
                .onChange(of: viewModel.selectedField) {
                    withAnimation {
    //                    focusField = nil
                        if (viewModel.departure.text == viewModel.departure.endpoint?.stop?.name && viewModel.selectedField == .departure) || (viewModel.arrival.text == viewModel.arrival.endpoint?.stop?.name && viewModel.selectedField == .arrival) {
                            results = Results.empty
                            if viewModel.selectedField != nil {
                                viewModel.selectedField = nil
                            }
                        } else {
                            results = Results.favorites
                        }
                    }
                }
    //            .onChange(of: showSearchField) {
    //                if showSearchField {
    //                    focusField = nil
    //                }
    //            }
                .onChange(of: focusField) {
                    withAnimation {
                        if focusField == .arrival {
                            viewModel.selectedField = .arrival
                        } else if focusField == .departure {
                            viewModel.selectedField = .departure
                        } else if focusField == nil {
                            if viewModel.departure.endpoint == nil {
                                viewModel.departure.text = ""
                            }
                            if viewModel.arrival.endpoint == nil {
                                viewModel.arrival.text = ""
                            }
                        }
                    }
                }
                .onChange(of: viewModel.departure.text) {
                    locationViewModel.searchQuery = viewModel.departure.text
                    viewModel.stopQuery = viewModel.departure.text
                }
                .onChange(of: viewModel.arrival.text) {
                    locationViewModel.searchQuery = viewModel.arrival.text
                    viewModel.stopQuery = viewModel.arrival.text
                }
                .onChange(of: tripManager.tripEvents) {
                    withAnimation {
                        if !tripManager.tripEvents.isEmpty {
                            results = Results.tripResults
                        }
                    }
                    #if DEBUG
                    if CaptureOptions.selectsBestTrip, layout.showsSecondaryPane {
                        selectedTrip = tripManager.tripEvents.bestForCapture()
                    }
                    #endif
                }
                .onChange(of: tripManager.tripError) {
                    withAnimation {
                        if tripManager.tripError {
                            results = Results.error
                        }
                    }
                }
                .onChange(of: viewModel.tripDone) {
                    withAnimation {
                        if viewModel.tripDone {
                            results = Results.loading
                        } else {
                            results = Results.favorites
                            tripManager.tripEvents.removeAll()
                        }
                    }
                }
                .onAppear(perform: {
                    showTime = timeDefault
                    if !viewModel.tripDone {
                        viewModel.selectedTime = AppClock.now()
                        viewModel.isArrivalTime = false
                        results = Results.favorites
                    }
                    if viewModel.quickTrip && !viewModel.tripDone {
                    
                        locationManager.requestLocation { location in
                            guard let userLocation = locationManager.userLocation else {
                                Log.location.error("Position indisponible")
                                return
                            }
                        
                            let coordinate = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
    //                                           print(coordinate)
                        
                            viewModel.selectCurrentPosition(coordinate, for: .departure)
                        
                            locationManager.locationUpdateHandler = nil
                        
                            viewModel.selectedTime = AppClock.now()
                            viewModel.isArrivalTime = false
                        
                            tripManager.tripEvents.removeAll()
                            requestTrips()
                            if let arrival = viewModel.arrival.endpoint {
                                RecentTrips.shared.add(from: nil, to: arrival)
                            }
                            viewModel.tripDone = true
    //                        results = Results.tripResults
                            viewModel.quickTrip = false
                        }
                    }
                    if viewModel.quickTrip && viewModel.tripDone {
                        withAnimation {
                            results = Results.loading
                        }
                    }
                    runPendingSearch()
                })
                .onChange(of: viewModel.pendingSearch) { runPendingSearch() }
            
                VStack(spacing: 0) {
                    Spacer()
                    //Previous and next buttons
                    if results == .tripResults {
                        HStack {
                            Spacer()
                            if #available(iOS 26, *) {
                                TimeShiftButtons(moveTime: moveTime,
                                                 earlierTitle: "Itinéraires précédents",
                                                 laterTitle: "Itinéraires suivants")
                            } else {
                                AdjustTimeButton(moveTime: moveTime)
                                    .tpgSurface(interactive: true)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 10)
    //                    .opacity(results == .tripResults ? 1 : 0)
                        .background {
                            VStack {
                                Spacer()
                                BackdropBlurView(radius: 1)
                                    .frame(height: 20)
                                    .mask {
                                        Rectangle()
                                            .overlay(alignment: .top) {
                                                ScrollMask(leading: false, vertical: true, gradientLength: 20)
                                            }
                                    }
                            }
                        }
                    }
                    Group {
                        let switchButton = Button {
                            withAnimation {
                                switchAnimate.toggle()
                                switchRotation.toggle()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    switchRotation.toggle()
                                    withAnimation {
                                        switchAnimate.toggle()
                                        viewModel.invertStops()
                                        if viewModel.selectedField == .departure {
                                            viewModel.stopQuery = viewModel.departure.text
                                            viewModel.selectedField = .arrival
                                        } else if viewModel.selectedField == .arrival {
                                            viewModel.stopQuery = viewModel.arrival.text
                                            viewModel.selectedField = .departure
                                        }
                                        viewModel.tripDone = false
                                        results = Results.favorites
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.title)
                                .padding(10)
                                .rotationEffect(.degrees(switchRotation ? 180 : 0))
    //                            .symbolEffect(.rotate, value: switchRotation)
                        }
                        VStack(spacing: 10) {
                            TPGGlassContainer {
                                HStack {
                                    VStack(spacing: 10) {
                                        if focusField != .arrival {
                                            HStack {
                                        TripPointField(viewModel: viewModel, results: $results, focusField: $focusField, field: .departure)
                                            .heightGrowingWithText(40)
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .tpgSurface(interactive: true, glassID: "departure", namespace: animation)

                                        if TripFieldButton.isVisible(field: .departure, focus: focusField, text: viewModel.departure.text, selected: viewModel.selectedField) {
                                        TripFieldButton(viewModel: viewModel, searchText: Bindable(viewModel).departure.text, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focusField: $focusField, field: .departure)
                                            .frame(width: 40, height: 40)
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .tpgSurface(interactive: true, glassID: "departureButton", namespace: animation)
                                        }
                                            }
                                            .padding(.vertical, focusField == .departure ? 10 : 0)
                                            .offset(y: switchAnimate ? 25 : 0)
                                        }
                                        if focusField != .departure {
                                            HStack {
                                        TripPointField(viewModel: viewModel, results: $results, focusField: $focusField, field: .arrival)
                                            .heightGrowingWithText(40)
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .tpgSurface(interactive: true, glassID: "arrival", namespace: animation)

                                        if TripFieldButton.isVisible(field: .arrival, focus: focusField, text: viewModel.arrival.text, selected: viewModel.selectedField) {
                                        TripFieldButton(viewModel: viewModel, searchText: Bindable(viewModel).arrival.text, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focusField: $focusField, field: .arrival)
                                            .frame(width: 40, height: 40)
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .tpgSurface(interactive: true, glassID: "arrivalButton", namespace: animation)
                                        }
                                            }
                                            .padding(.vertical, focusField == .arrival ? 10 : 0)
                                            .offset(y: switchAnimate ? -25 : 0)
                                        }
                                    }
                                    if focusField == nil {
                                        switchButton
                                            .frame(width: 60, height: 60)
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .tpgSurface(interactive: true)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        
                            let bottomTripSearch = TripTimeSearchPanel(search: searchTrips)
                                .onAppear(perform: {
                                    if !tripManager.tripEvents.isEmpty {
                                        withAnimation {
                                            results = Results.tripResults
                                        }
                                    }
                                })
                            if focusField == nil {
                                bottomTripSearch
                                    // Plafonnée comme les barres d'outils : en taille d'accessibilité, elle
                                    // couvrait l'écran.
                                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                    .tpgSurface(in: .rect(cornerRadius: 35))
                                    .padding(.horizontal)
                                    .padding(.bottom, TPGSurface.isGlass ? 20 : 70)
                            }
                        }
                        .readableWidth()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { searchOverlayHeight = $0 }
    //                    .shadow(color: .black.opacity(0.08), radius: 15)
                        .background {
                            ZStack {
                                Rectangle()
                                    .foregroundStyle(.customBackground)
                                    .opacity(0.5)
                                    .blur(radius: 10)
                                BackdropBlurView(radius: 1)
                            
                            }
                        }
                    }
                }
            }
        } secondary: {
            TripDetailPane(trip: selectedTrip, showTime: $showTime) {
                withAnimation { selectedTrip = nil }
            }
        }
        // Nouvelle recherche : le trajet détaillé n'en fait plus partie.
        .onChange(of: tripManager.tripEvents) {
            if let selectedTrip, !tripManager.tripEvents.contains(selectedTrip) {
                self.selectedTrip = nil
            }
        }
        .navigationTitle("Itinéraire") // Set back button text
        // Grand écran : le grand titre chevauchait la liste, et son repli faisait bouger toute
        // la page au moindre défilement des détails.
        .navigationBarTitleDisplayMode(layout.showsSecondaryPane ? .inline : .automatic)
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text("") // Visible title
//            }   
//        }
//        .toolbar(.hidden, for: .navigationBar)
        // Les itinéraires enregistrés ont leur onglet, Trajets, sauf si la carte l'a pris.
        .toolbar {
            if results == .tripResults || mapTab {
                TrailingBarButtons {
                    if results == .tripResults {
                        ShowTimeButton(showTime: $showTime)
                    }
                    if mapTab {
                        // Une page de la pile : le retour depuis un itinéraire ramène à la liste.
                        Button {
                            openRoute(.savedTrips)
                        } label: {
                            Label {
                                Text("Mes itinéraires")
                            } icon: {
                                Image("scurvepath.stack.fill")
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    func adjustTime(byAdding minutes: Int) {
        if let newTimeRequest = Calendar.current.date(byAdding: .minute, value: minutes, to: viewModel.selectedTime) {
            viewModel.selectedTime = newTimeRequest
        } else {
            Log.ui.error("Décalage de l'heure impossible")
        }
    }
    
    func timeChange() -> Int {
        let tripEventsSorted = tripManager.tripEvents.sortedByStart()
        let firstTime: Date = tripEventsSorted.first?.startDate ?? AppClock.now()
        let lastTime: Date = tripEventsSorted.last?.startDate ?? AppClock.now()
        let timeChange = lastTime.timeIntervalSince(firstTime)/60
        
        return Int(timeChange)
    }
    private func moveTime(previous: Bool) { //Move departures time earlier or later (with top and bottom buttons)
        adjustTime(byAdding: previous ? -timeChange() : timeChange())
        searchTrips()
    }
    
    /// La recherche demandée depuis un autre écran (`ItineraryViewModel.searchNow`).
    private func runPendingSearch() {
        guard viewModel.pendingSearch else { return }
        viewModel.pendingSearch = false
        searchTrips()
    }

    /// Demande les itinéraires, une fois l'adresse de « Ma position » trouvée (2 s au plus) :
    /// elle les nomme.
    private func requestTrips() {
        Task { @MainActor in
            await viewModel.waitForAddresses()
            tripManager.selectTrip(from: viewModel.departure.endpoint, to: viewModel.arrival.endpoint, at: viewModel.selectedTime,
                                   isArrivalTime: viewModel.isArrivalTime, avoiding: viewModel.avoidedLines)
        }
    }

    func searchTrips() {
        if viewModel.canSearch {
            if let arrival = viewModel.arrival.endpoint {
                RecentTrips.shared.add(from: viewModel.departure.endpoint, to: arrival)
            }
            results = Results.loading
            tripManager.tripEvents.removeAll()
            requestTrips()
            viewModel.tripDone = true
            showCloseStops = false
            calculationSuccess = false
//            results = Results.tripResults
        }
    }
}

#Preview("Itinéraire") {
    TripView()
        .previewEnvironment()
}

#Preview("Itinéraire — résultats") {
    // Rive → Cornavin, résultats enregistrés (hors ligne).
    let manager = TripManager()
    manager.tripEvents = PreviewData.trips
    return TripView(tripManager: manager, results: .tripResults)
        .previewEnvironment(itinerary: (PreviewData.rive, PreviewData.cornavin))
}

#Preview("Itinéraire — recherche réelle (API)") {
    @Previewable @State var manager = TripManager()
    TripView(tripManager: manager, results: .loading)
        .task {
            manager.selectTrip(from: .stop(PreviewData.meinier), to: .stop(PreviewData.rondeau), at: Date(), isArrivalTime: false)
        }
        .previewEnvironment(itinerary: (PreviewData.meinier, PreviewData.rondeau))
}

#Preview("Itinéraire — aucun résultat") {
    TripView(results: .error)
        .previewEnvironment(itinerary: (PreviewData.rive, PreviewData.cornavin))
}

#Preview("Itinéraire — iPad", traits: .iPadLandscape) {
    let manager = TripManager()
    manager.tripEvents = PreviewData.trips
    return TripView(tripManager: manager, results: .tripResults)
        .previewEnvironment(itinerary: (PreviewData.rive, PreviewData.cornavin))
}

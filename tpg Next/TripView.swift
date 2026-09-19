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
    @Environment(RegularTripsModel.self) var regularTripsModel
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
    @State private var timeRequest = Date()
    
    @State private var closestStops: [Stop] = []
    @State private var calculationSuccess = false
    @State private var userPosition: CLLocation?
    
    @State private var showTime = true
    @State private var showSavedTrips = false
    @Environment(\.openRoute) private var openRoute
    @Environment(\.layout) private var layout
    /// Sur grand écran, le trajet détaillé dans la moitié droite.
    @State private var selectedTrip: TripEvent?
    
    @Namespace private var animation
    @State private var switchAnimate: Bool = false
    @State private var switchRotation: Bool = false
    
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    
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
                            ResultsTripView(viewModel: viewModel, tripManager: tripManager, showTime: $showTime, adjustTime: adjustTime, timeChange: timeChange, searchTrips: searchTrips,
                                            selectedID: selectedTrip?.id, onSelect: layout.showsSecondaryPane ? { trip in withAnimation { selectedTrip = trip } } : nil)
                        case.loading:
                            Rectangle()//Placé suite à un bug d'affichage du titre. A tester sans hors beta
                                .opacity(0)
                                .frame(height: 50)
                        
                                Text("Chargement...")
                        case.error:
                            Rectangle()//Placé suite à un bug d'affichage du titre. A tester sans hors beta
                                .opacity(0)
                                .frame(height: 50)
                        
                                Text("Erreur, pas d'itinéraires trouvés")
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
                        viewModel.selectedTime = Date()
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
                        
                            viewModel.departure.select(.place(GeoPosition(name: "Ma position", coordinate: coordinate)))
                        
                            locationManager.locationUpdateHandler = nil
                        
                            viewModel.selectedTime = Date()
                            viewModel.isArrivalTime = false
                        
                            tripManager.tripEvents.removeAll()
                            tripManager.selectTrip(from: viewModel.departure.endpoint, to: viewModel.arrival.endpoint, at: viewModel.selectedTime, isArrivalTime: viewModel.isArrivalTime)
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
                })
            
                VStack(spacing: 0) {
                    Spacer()
                    //Previous and next buttons
                    if results == .tripResults {
                        HStack {
                            Spacer()
                            AdjustTimeButton(moveTime: moveTime)
                                .glassForegroundStyle(.primary)
                                .tpgSurface(interactive: true)
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

                                        TripFieldButton(viewModel: viewModel, searchText: Bindable(viewModel).departure.text, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focusField: $focusField, field: .departure)
                                            .frame(width: 40, height: 40)
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .tpgSurface(interactive: true, glassID: "departureButton", namespace: animation)
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

                                        TripFieldButton(viewModel: viewModel, searchText: Bindable(viewModel).arrival.text, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focusField: $focusField, field: .arrival)
                                            .frame(width: 40, height: 40)
                                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                            .tpgSurface(interactive: true, glassID: "arrivalButton", namespace: animation)
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
        .sheet(isPresented: $showSavedTrips) {
            SavedTripsView(isPresented: $showSavedTrips, onTripSelected: { trip in
                showSavedTrips = false
                if layout.showsSecondaryPane {
                    selectedTrip = trip
                } else {
                    openRoute(.trip(trip))
                }
            })
                .environment(savedTripsModel)
                .environment(regularTripsModel)
                .presentationDetents([.fraction(0.99)])
                .presentationCornerRadius(35)
                .presentationBackground(.thinMaterial)
        }
        .navigationTitle("Itinéraire") // Set back button text
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text("") // Visible title
//            }   
//        }
//        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            HStack {
                if results == .tripResults {
                    ShowTimeButton(showTime: $showTime)
                        .padding(.trailing, 5)
                }
                Button {
                    self.showSavedTrips.toggle()
                } label: {
                    Image("scurvepath.stack.fill")
                        .foregroundColor(TPGSurface.isGlass ? Color.text : .accent)
                        .symbolEffect(.bounce, value: showSavedTrips)
                        .scaleEffect(0.9)
                        .padding(.trailing, TPGSurface.isGlass && results == .tripResults ? 10 : 0)
                }
                .frame(width: TPGSurface.isGlass ? 30 : 40, height: 30)
            }
            .background {
                Capsule()
                    .frame(height: 40)
                    .foregroundStyle(.ultraThinMaterial)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                    .opacity(TPGSurface.isGlass ? 0 : 1)
                    .offset(x: 4)
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
        let firstTime: Date = tripEventsSorted.first?.startDate ?? Date()
        let lastTime: Date = tripEventsSorted.last?.startDate ?? Date()
        let timeChange = lastTime.timeIntervalSince(firstTime)/60
        
        return Int(timeChange)
    }
    private func moveTime(previous: Bool) { //Move departures time earlier or later (with top and bottom buttons)
        adjustTime(byAdding: previous ? -timeChange() : timeChange())
        searchTrips()
    }
    
    func searchTrips() {
        if viewModel.canSearch {
            results = Results.loading
            tripManager.tripEvents.removeAll()
            tripManager.selectTrip(from: viewModel.departure.endpoint, to: viewModel.arrival.endpoint, at: viewModel.selectedTime, isArrivalTime: viewModel.isArrivalTime)
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

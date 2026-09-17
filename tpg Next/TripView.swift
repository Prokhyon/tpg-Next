//
//  TripView.swift
//  TPG4
//
//  Created by Loris Thomas on 30.06.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc

/// « Partir d'ici », « Aller ici » et, au besoin, « Trajet rapide » pour un arrêt.
/// À placer dans un `contextMenu` ou un `Menu`.
struct TripActionsMenu: View {
    @Environment(ItineraryViewModel.self) var tripViewModel
    @Environment(NavigationModel.self) var navigationModel
    let stop: Stop
    var includesQuickTrip = true

    var body: some View {
        Button {
            tripViewModel.outerTrip(tab: navigationModel, isDeparture: true, stop: stop, isQuickTrip: false)
        } label: {
            Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
        }
        Button {
            tripViewModel.outerTrip(tab: navigationModel, isDeparture: false, stop: stop, isQuickTrip: false)
        } label: {
            Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
        }
        if includesQuickTrip {
            Button {
                tripViewModel.outerTrip(tab: navigationModel, isDeparture: false, stop: stop, isQuickTrip: true)
            } label: {
                Label("Trajet rapide", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
            }
        }
    }
}

struct TripView: View {
    var tripManager = TripManager()
    @Environment(SavedTripsModel.self) var savedTripsModel
    @Environment(RegularTripsModel.self) var regularTripsModel
    @Environment(ItineraryViewModel.self) var viewModel
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(AppRequirementsClass.self) var appRequirementsClass
    @State private var locationViewModel = LocationSearchViewModel()
    @State var locationManager = LocationManager()
    @Environment(RecentSearch.self) var recentSearchModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    
    @Namespace private var animation
    @State private var switchAnimate: Bool = false
    @State private var switchRotation: Bool = false
    
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    
    enum Results {
        case empty, favorites, search, closeStops, tripResults, loading, error
    }
    
    @State var results = Results.favorites
    @State var timeAnimate = false
    
    var body: some View {
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
                        ResultsTripView(viewModel: viewModel, tripManager: tripManager, showTime: $showTime, adjustTime: adjustTime, timeChange: timeChange, searchTrips: searchTrips)
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
                } else {
                    ScrollView {
                        resultsView
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .contentMargins(.bottom, (results == .tripResults || focusField != nil) ? max(340, searchOverlayHeight + 70) : (focusField != nil) ? 70 : max(270, searchOverlayHeight), for: .automatic)
                    .contentMargins(.bottom, appRequirementsClass.version26 ? 0: 75, for: .automatic)
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
                        
                        let bottomTripSearch = VStack(spacing: 15) {
                            
                            let resetTimeButton = Button(action: {
                                viewModel.selectedTime = Date()
                                viewModel.tripDone = false
                                timeAnimate.toggle()
                            }) {
                                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                    .symbolEffect(.rotate, value: timeAnimate)
                                    .font(.title2)
                            }
                            // Jusqu'à la taille de texte par défaut, le libellé reste à gauche (sur deux
                            // lignes au besoin) ; au-delà, il passe au-dessus : il s'étirait sinon à une
                            // ou deux lettres par ligne.
                            if dynamicTypeSize <= .large {
                                HStack {
                                    DatePicker(selection: Bindable(viewModel).selectedTime) {
                                        Text("Date et heure:")
                                    }
                                    .padding(.trailing, 5)
                                    resetTimeButton
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Date et heure:")
                                    HStack {
                                        DatePicker("Date et heure:", selection: Bindable(viewModel).selectedTime)
                                            .labelsHidden()
                                        Spacer()
                                        resetTimeButton
                                    }
                                }
                            }
                            
                            
                            if #available(iOS 26, *) {
                                HStack {
                                    Picker("", selection: Bindable(viewModel).isArrivalTime) {
                                        Text("Départ").tag(false)
                                        Text("Arrivée").tag(true)
                                    }
                                    .pickerStyle(.segmented)
                                    Button {
                                        
                                        if viewModel.canSearch {
                                            withAnimation {
                                                searchTrips()
                                                viewModel.tripDone = true
                                            }
                                        }
                                    } label: {
                                        Text("Rechercher")
                                            .foregroundStyle(.white)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal)
                                            .glassEffect(.regular.tint(viewModel.canSearch ? .accentColor : .gray).interactive(viewModel.canSearch))
                                    }
                                    .disabled(!viewModel.canSearch)
                                }
                            } else {
                                HStack {
                                    CustomPicker(secondSelected: Bindable(viewModel).isArrivalTime, height: 45, firstOption: String(localized: "Départ"), firstIcon: nil, secondOption: String(localized: "Arrivée"), secondIcon: nil, animation: animation)
                                        .frame(width: 220)
                                    
                                    Button {
                                        if viewModel.canSearch {
                                            searchTrips()
                                            viewModel.tripDone = true
                                        }
                                    } label: {
                                        // Au moins 110 × 45 : le bouton s'élargit avec un texte agrandi.
                                        Text("Rechercher")
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .frame(minWidth: 110, minHeight: 45)
                                            .background {
                                                Capsule()
                                                    .fill(viewModel.canSearch ? .accent : .gray)
                                                    .shadow(color: Color.customShadows, radius: 1, y: 0.8)
                                            }
                                    }
                                    .disabled(!viewModel.canSearch)
                                }
                            }
                        }
                            .padding()
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
        .sheet(isPresented: $showSavedTrips) {
            SavedTripsView(isPresented: $showSavedTrips, onTripSelected: { trip in
                showSavedTrips = false
                openRoute(.trip(trip))
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
                        .foregroundColor(appRequirementsClass.version26 ? Color.text : .accent)
                        .symbolEffect(.bounce, value: showSavedTrips)
                        .scaleEffect(0.9)
                        .padding(.trailing, appRequirementsClass.version26 && results == .tripResults ? 10 : 0)
                }
                .frame(width: appRequirementsClass.version26 ? 30 : 40, height: 30)
            }
            .background {
                Capsule()
                    .frame(height: 40)
                    .foregroundStyle(.ultraThinMaterial)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                    .opacity(appRequirementsClass.version26 ? 0 : 1)
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

struct TripView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()
        @State var fullTripTest = FullTripTest()
        
        @State var savedTripsModel = SavedTripsModel()
        @State var regularTripsModel = RegularTripsModel()
        @State var appRequirementsClass = AppRequirementsClass()
            @State var itineraryViewModel = ItineraryViewModel()
        @State var boolTest: Bool = true
        @State var showTime: Bool = true
        
        return
            NavigationStack {
                TripView(tripManager: TripManager())
                    .environment(itineraryViewModel)
                    .environment(stopStore)
                    .environment(favoritesViewModel)
                    .environment(savedTripsModel)
                    .environment(regularTripsModel)
                    .environment(appRequirementsClass)
                    .environment(RecentSearch())
                    .background(Image("tpgMap"))
            }
        
//        VStack {
//            Capsule()
//            .fill(.thinMaterial)
//            .padding(4)
//            .frame(height: 80)
//            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
//            .overlay(
//                TripElementView(event: fullTripTest.Trip, showTime: showTime)
////                    .padding(.horizontal, 20)
//            )
//            .padding()
//        }
    }
}

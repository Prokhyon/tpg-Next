//
//  TripView.swift
//  TPG4
//
//  Created by Loris Thomas on 30.06.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc

enum TripField: Hashable {
        case departure
        case arrival
    }

class ItineraryViewModel: ObservableObject {
    
    @Published var departureStop: Stop?
    @Published var departureGeoPosition: GeoPosition?
    @Published var geoDeparture: Bool = false
    
    @Published var arrivalStop: Stop?
    @Published var arrivalGeoPosition: GeoPosition?
    @Published var geoArrival: Bool = false
    
    @Published var invertStop: Stop?
    @Published var invertLocation: GeoPosition?
    @Published var invertGeo: Bool = false
    @Published var selectedTime = Date()
    @Published var isArrivalTime = false
    @Published var departureSearchText = ""
    @Published var arrivalSearchText = ""
    
    @Published var tripDone = false
    @Published var quickTrip = false
    
    @Published var selectedTextField: Int = 1

    @Published var selectedField: TripField? = .departure

    var hasDeparture: Bool { departureStop != nil || departureGeoPosition != nil }
    var hasArrival: Bool { arrivalStop != nil || arrivalGeoPosition != nil }
    /// Départ et arrivée renseignés : la recherche d'itinéraire peut être lancée.
    var canSearch: Bool { hasDeparture && hasArrival }
    
    func invertStops() {
        departureSearchText = ""
        arrivalSearchText = ""
        invertStop = departureStop
        invertLocation = departureGeoPosition
        invertGeo = geoDeparture
        departureStop = arrivalStop
        departureGeoPosition = arrivalGeoPosition
        geoDeparture = geoArrival
        arrivalStop = invertStop
        arrivalGeoPosition = invertLocation
        geoArrival = invertGeo
        if geoDeparture {
            departureSearchText = departureGeoPosition?.name ?? ""
        } else {
            departureSearchText = departureStop?.name ?? ""
        }
        if geoArrival {
            arrivalSearchText = arrivalGeoPosition?.name ?? ""
        } else {
            arrivalSearchText = arrivalStop?.name ?? ""
        }
    }
    func resetModel() {
        departureStop = nil
        departureGeoPosition = nil
        geoDeparture = false
        arrivalStop = nil
        arrivalGeoPosition = nil
        geoArrival = false
        invertStop = nil
        invertLocation = nil
        invertGeo = false
        selectedTime = Date()
        isArrivalTime = false
        departureSearchText = ""
        arrivalSearchText = ""
    }
    
    func outerTrip(tab: NavigationModel, isDeparture: Bool, stop: Stop, isQuickTrip: Bool) {
        if isDeparture {
            //        print("TripViewAppear: inputDeparture != nil && inputArrival == nil")
            departureStop = stop
            departureSearchText = stop.name
            arrivalStop = nil
            arrivalSearchText = ""
            selectedTextField = 2
        } else {
            //        print("TripViewAppear: inputArrival != nil && inputDeparture == nil")
            departureStop = nil
            departureSearchText = ""
            arrivalStop = stop
            arrivalSearchText = stop.name
            selectedTextField = 1
        }
        tripDone = false
        quickTrip = isQuickTrip
//        tab.tripNavigationId = "trip"
        tab.tripPath = NavigationPath()
        tab.selectedTab = .trip
    }
}

class LocationSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery: String = "" {
        didSet {
            updateSearchResults()
        }
    }
    @Published var searchResults = [MKLocalSearchCompletion]()
    
    private var completer: MKLocalSearchCompleter
    
    // Define the region you want to limit the search to
    var searchRegion: MKCoordinateRegion? {
        didSet {
            if let region = searchRegion {
                completer.region = region
            }
        }
    }
    
    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        
        // Optionally set an initial region here
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.8182, longitude: 8.2275),
            span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
        )
        completer.region = initialRegion
    }
    
    func updateSearchResults() {
        completer.queryFragment = searchQuery
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchResults = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Log.ui.error("Recherche de lieux : \(error.localizedDescription)")
    }
    
    func getCoordinate(for suggestion: MKLocalSearchCompletion, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: suggestion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            if let coordinate = response?.mapItems.first?.placemark.coordinate {
                completion(coordinate)
            } else {
                completion(nil)
            }
        }
    }
}


struct TripElementView: View {
    var event: TripEvent
    var showTime: Bool = true
    var body: some View {
        VStack(alignment: .center) {
            HStack {
                let startTime = displayTimeOrMinutesRemaining(for: event.startTime, estimatedInput: event.startTime, with: showTime)
                if startTime.text  == "0" { transportIcon(with: event.legs.first?.transportTypeName ?? "Bus")
                            .frame(width:55)
                    } else {
                        if startTime.text.count > 6 {
                            let splitTime = splitString(startTime.text, separator: ";" )
                            VStack {
                                Text(splitTime.0)
                                Text(splitTime.1).foregroundStyle(startTime.color)
                                
                            }
                            .frame(width:55)
                            .minimumScaleFactor(0.5)
                        } else {
                            Text(startTime.text)
                                .frame(width:55)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(startTime.color)
                        }
                    }
                    Spacer()

                    // Scrollable icon area
                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Spacer()
                            ForEach(event.legs, id: \.id) { leg in
                                if !(leg.publishedLineName == "") {
                                    BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
                                        .padding(2)
                                } else if /*!*/leg.transfer && Int(leg.transferWalkDuration.dropFirst(2).dropLast(1)) ?? 0 >= 5 {
                                    Image(systemName: "figure.walk").font(.caption)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(minWidth: 200)
                    }
                    .mask {
                        Rectangle()
                            .overlay(alignment: .leading) {
                                ScrollMask(leading: true, vertical: false, gradientLength: 25)
                            }
                    }
                    .mask {
                        Rectangle()
                            .overlay(alignment: .trailing) {
                                ScrollMask(leading: false, vertical: false, gradientLength: 25)
                            }
                    }

                }
                .frame(minWidth: 200, maxHeight: 30)
                    Spacer()
                let endTime = displayTimeOrMinutesRemaining(for: event.endTime, estimatedInput: event.endTime, with: showTime)
                if endTime.text  == "0" { transportIcon(with: event.legs.last?.transportTypeName ?? "Bus")
                            .frame(width:55)
                } else {
                    if endTime.text.count > 6 {
                        let splitTime = splitString(endTime.text, separator: ";" )
                        VStack {
                            Text(splitTime.0)
                            Text(splitTime.1).foregroundStyle(endTime.color)
                        }
                        .frame(width:55)
                        .minimumScaleFactor(0.5)
                    } else {
                        Text(endTime.text)
                            .frame(width:55)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(endTime.color)
                    }
                }
            }
            .padding(.horizontal)
            
            HStack {
                Image(systemName: "arrowshape.bounce.forward")
                Text(": \(event.transfers)")
                    .padding(.trailing)
                Image(systemName: "timer")
                if event.duration.count == 7 {
                    Text(": \(event.duration.dropFirst(2).dropLast(1))")
                } else {
                    Text(": \(event.duration.dropFirst(2).dropLast(1))'")
                }
            }
        }
        .padding(.horizontal)
    }
}

struct TripView: View {
    @ObservedObject var tripManager = TripManager()
    @EnvironmentObject var savedTripsModel: SavedTripsModel
    @EnvironmentObject var regularTripsModel: RegularTripsModel
    @EnvironmentObject var viewModel: ItineraryViewModel
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var appRequirementsClass: AppRequirementsClass
    @StateObject private var locationViewModel = LocationSearchViewModel()
    @StateObject var locationManager = LocationManager()
    @StateObject var recentSearchModel = RecentSearch()

    
    @FocusState var focusField: TripField?
    
    @State private var showCloseStops = false
    @State private var timeRequest = Date()
    
    @State private var closestStops: [Stop] = []
    @State private var calculationSuccess = false
    @State private var userPosition: CLLocation?
    
    @State private var showTime = true
    @State private var showSavedTrips = false
    @State private var selectedSavedTrip: TripEvent?
    @State private var showTripDetail = false
    
    @Namespace private var animation
    @State private var switchAnimate: Bool = false
    @State private var switchRotation: Bool = false
    
    @AppStorage("TimeDefault") var timeDefault = false
    
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
                            .environmentObject(recentSearchModel)
                    case.search:
                        ResultsSearchView(viewModel: viewModel, locationViewModel: locationViewModel, results: $results, focusField: $focusField)
                            .environmentObject(recentSearchModel)
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
                    .contentMargins(.bottom, (results == .tripResults) ? 340 : (focusField != nil) ? 70 : 270, for: .automatic)
                } else {
                    ScrollView {
                        resultsView
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .contentMargins(.bottom, (results == .tripResults || focusField != nil) ? 340 : (focusField != nil) ? 70 : 270 , for: .automatic)
                    .contentMargins(.bottom, appRequirementsClass.version26 ? 0: 75, for: .automatic)
                }
            }
            .onChange(of: viewModel.selectedField) {
                withAnimation {
//                    focusField = nil
                    if (viewModel.departureSearchText == viewModel.departureStop?.name && viewModel.selectedField == .departure) || (viewModel.arrivalSearchText == viewModel.arrivalStop?.name && viewModel.selectedField == .arrival) {
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
                        if !viewModel.hasDeparture {
                            viewModel.departureSearchText = ""
                        }
                        if !viewModel.hasArrival {
                            viewModel.arrivalSearchText = ""
                        }
                    }
                }
            }
            .onChange(of: viewModel.departureSearchText) {
                locationViewModel.searchQuery = viewModel.departureSearchText
                stopStore.searchText = viewModel.departureSearchText
            }
            .onChange(of: viewModel.arrivalSearchText) {
                locationViewModel.searchQuery = viewModel.arrivalSearchText
                stopStore.searchText = viewModel.arrivalSearchText
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
                        
                        viewModel.departureGeoPosition = GeoPosition(name: "Ma position", coordinate: coordinate)
                        viewModel.geoDeparture = true
                        viewModel.departureSearchText = "Ma position"
                        
                        locationManager.locationUpdateHandler = nil
                        
                        viewModel.selectedTime = Date()
                        viewModel.isArrivalTime = false
                        
                        tripManager.tripEvents.removeAll()
                        tripManager.selectTrip(with: viewModel.departureStop, with: viewModel.departureGeoPosition, with: viewModel.geoDeparture, with: viewModel.arrivalStop, with: viewModel.arrivalGeoPosition, with: viewModel.geoArrival, with: viewModel.selectedTime, with: viewModel.isArrivalTime)
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
                        if #available(iOS 26, *) {
//                            HStack {
//                                Button(action: {
//                                    withAnimation {
//                                        adjustTime(byAdding: -timeChange())
//                                        searchTrips()
//                                    }
//                                }) {
//                                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
//                                        .padding()
//                                        .symbolEffect(.bounce.up.byLayer, value: viewModel.selectedTime)
//                                }
//                                Button(action: {
//                                    withAnimation {
//                                        adjustTime(byAdding: timeChange())
//                                        searchTrips()
//                                    }
//                                }) {
//                                    Image(systemName: "text.line.last.and.arrowtriangle.forward")
//                                        .padding()
//                                        .symbolEffect(.bounce.down.byLayer, value: viewModel.selectedTime)
//                                }
//                            }
                            AdjustTimeButton(moveTime: moveTime)
                            .foregroundStyle(.primary)
                            .glassEffect(.regular.interactive())
                        } else {
//                            HStack {
//                                Button(action: {
//                                    withAnimation {
//                                        adjustTime(byAdding: -timeChange())
//                                        searchTrips()
//                                    }
//                                }) {
//                                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
//                                        .padding()
//                                }
//                                Button(action: {
//                                    withAnimation {
//                                        adjustTime(byAdding: timeChange())
//                                        searchTrips()
//                                    }
//                                }) {
//                                    Image(systemName: "text.line.last.and.arrowtriangle.forward")
//                                        .padding()
//                                }
//                            }
                            AdjustTimeButton(moveTime: moveTime)
                            .background {
                                Capsule()
                                    .foregroundStyle(.ultraThinMaterial)
                                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                            }
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
                                        stopStore.searchText = viewModel.departureSearchText
                                        viewModel.selectedField = .arrival
                                    } else if viewModel.selectedField == .arrival {
                                        stopStore.searchText = viewModel.arrivalSearchText
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
                        if #available(iOS 26, *) {
                            GlassEffectContainer {
                                HStack {
                                    VStack(spacing: 10) {
                                        if focusField != .arrival {
                                            HStack {
                                                TripPointField(viewModel: viewModel, results: $results, focusField: $focusField, field: .departure)
                                                    .frame(height: 40)
                                                    .glassEffect(.regular.interactive())
                                                    .glassEffectID("departure", in: animation)
                                                
                                                TripFieldButton(viewModel: viewModel, searchText: $viewModel.departureSearchText, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focusField: $focusField, field: .departure)
                                                    .frame(width: 40, height: 40)
                                                    .glassEffect(.regular.interactive())
                                                    .glassEffectID("departureButton", in: animation)
                                            }
                                            .padding(.vertical, focusField == .departure ? 10 : 0)
                                            .offset(y: switchAnimate ? 25 : 0)
                                        }
                                        if focusField != .departure {
                                            HStack {
                                                TripPointField(viewModel: viewModel, results: $results, focusField: $focusField, field: .arrival)
                                                    .frame(height: 40)
                                                    .glassEffect(.regular.interactive())
                                                    .glassEffectID("arrival", in: animation)
                                                
                                                TripFieldButton(viewModel: viewModel, searchText: $viewModel.arrivalSearchText, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focusField: $focusField, field: .arrival)
                                                    .frame(width: 40, height: 40)
                                                    .glassEffect(.regular.interactive())
                                                    .glassEffectID("arrivalButton", in: animation)
                                            }
                                            .padding(.vertical, focusField == .arrival ? 10 : 0)
                                            .offset(y: switchAnimate ? -25 : 0)
                                        }
                                    }
                                    if focusField == nil {
                                        switchButton
                                            .frame(width: 60, height: 60)
                                            .glassEffect(.regular.interactive())
                                    }
                                }
                                .padding(.horizontal)
                            }
//                            .padding(.top, 20)
                        } else {
                                HStack {
                                    VStack(spacing: 10) {
                                        if focusField != .arrival {
                                            HStack {
                                                TripPointField(viewModel: viewModel, results: $results, focusField: $focusField, field: .departure)
                                                    .frame(height: 40)
                                                    .background {
                                                        Capsule()
                                                            .foregroundStyle(.ultraThinMaterial)
                                                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                                    }
                                                
                                                TripFieldButton(viewModel: viewModel, searchText: $viewModel.departureSearchText, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focusField: $focusField, field: .departure)
                                                    .frame(width: 40, height: 40)
                                                    .background {
                                                        Capsule()
                                                            .foregroundStyle(.ultraThinMaterial)
                                                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                                    }
                                            }
                                            .padding(.vertical, focusField == .departure ? 10 : 0)
                                            .offset(y: switchAnimate ? 25 : 0)
                                        }
                                        if focusField != .departure {
                                            HStack {
                                                TripPointField(viewModel: viewModel, results: $results, focusField: $focusField, field: .arrival)
                                                    .frame(height: 40)
                                                    .background {
                                                        Capsule()
                                                            .foregroundStyle(.ultraThinMaterial)
                                                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                                    }
                                                
                                                TripFieldButton(viewModel: viewModel, searchText: $viewModel.arrivalSearchText, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focusField: $focusField, field: .arrival)
                                                    .frame(width: 40, height: 40)
                                                    .background {
                                                        Capsule()
                                                            .foregroundStyle(.ultraThinMaterial)
                                                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                                    }
                                            }
                                            .padding(.vertical, focusField == .arrival ? 10 : 0)
                                            .offset(y: switchAnimate ? -25 : 0)
                                        }
                                    }
                                    if focusField == nil {
                                        switchButton
                                            .frame(width: 60, height: 60)
                                            .background {
                                                Capsule()
                                                    .foregroundStyle(.ultraThinMaterial)
                                                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                            }
                                    }
                                }
                                .padding(.horizontal)
                        }
                        
                        let bottomTripSearch = VStack(spacing: 15) {
                            
                            HStack {
                                DatePicker(selection: $viewModel.selectedTime) {
                                    Text("Date et heure:")
                                }
                                .padding(.trailing, 5)
                                Button(action: {
                                    viewModel.selectedTime = Date()
                                    viewModel.tripDone = false
                                    timeAnimate.toggle()
                                }) {
                                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                        .symbolEffect(.rotate, value: timeAnimate)
                                        .font(.title2)
                                }
                            }
                            
                            
                            if #available(iOS 26, *) {
                                HStack {
                                    Picker("", selection: $viewModel.isArrivalTime) {
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
                                    CustomPicker(secondSelected: $viewModel.isArrivalTime, height: 45, firstOption: String(localized: "Départ"), firstIcon: nil, secondOption: String(localized: "Arrivée"), secondIcon: nil, animation: animation)
                                        .frame(width: 220)
                                    
                                    Button {
                                        if viewModel.canSearch {
                                            searchTrips()
                                            viewModel.tripDone = true
                                        }
                                    } label: {
                                        Capsule()
                                            .fill(viewModel.canSearch ? .accent : .gray)
                                            .shadow(color: Color.customShadows, radius: 1, y: 0.8)
                                            .frame(width: 110, height: 45)
                                            .overlay(Text("Rechercher").foregroundStyle(.white))
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
                            if #available(iOS 26, *) {
                                bottomTripSearch
                                    .glassEffect(in: .rect(cornerRadius: 35))
                                //                                .shadow(color: Color.black.opacity(0.05), radius: 20)
                                    .padding(.horizontal)
                                    .padding(.bottom, 20)
                            } else {
                                bottomTripSearch
                                    .background {
                                        RoundedRectangle(cornerRadius: 35.0)
                                            .foregroundStyle(.ultraThinMaterial)
                                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 70)
                            }
                        }
                    }
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
        .navigationDestination(isPresented: $showTripDetail) {
            if let trip = selectedSavedTrip {
                FullTripView(fullTrip: trip)
                    .environmentObject(savedTripsModel)
            }
        }
        .sheet(isPresented: $showSavedTrips) {
            SavedTripsView(isPresented: $showSavedTrips, onTripSelected: { trip in
                selectedSavedTrip = trip
                showTripDetail = true
                showSavedTrips = false
            })
                .environmentObject(savedTripsModel)
                .environmentObject(regularTripsModel)
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
    
    struct ResultsFavoritesView: View {
        @EnvironmentObject var stopStore: StopStore
        @EnvironmentObject var favoritesViewModel: FavoritesViewModel
        @ObservedObject var viewModel: ItineraryViewModel
        @EnvironmentObject var recentSearchModel: RecentSearch
        @Binding var results: Results

        var body: some View {
            VStack {
                if !favoritesViewModel.favoriteStops.isEmpty {
                    HStack {
                        Text("Favoris")
                            .font(.title3).bold()
                        Spacer()
                    }
                }
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    ForEach(favoritesViewModel.favoriteStops, id: \.self) { stop in
                        Button(action: {
                            withAnimation {
                                let geoPosition = GeoPosition(name: stop.name, coordinate: CLLocationCoordinate2D(latitude: Double(stop.wgs84Coordinates.lat), longitude: Double(stop.wgs84Coordinates.lon)))
                                if viewModel.selectedField == .departure {
                                    viewModel.departureStop = stop
                                    viewModel.departureSearchText = stop.name
                                    viewModel.geoDeparture = false
                                    viewModel.departureGeoPosition = geoPosition
                                    viewModel.selectedField = .arrival
                                    results = Results.favorites
                                    viewModel.tripDone = false
                                } else if viewModel.selectedField == .arrival {
                                    viewModel.arrivalStop = stop
                                    viewModel.arrivalSearchText = stop.name
                                    viewModel.geoArrival = false
                                    viewModel.arrivalGeoPosition = geoPosition
                                    viewModel.selectedField = .departure
                                    results = Results.favorites
                                    viewModel.tripDone = false
                                }
                            }
                        }){
                            BasicLocationView(name: stop.name, transportType: stop.meansOfTransport)
                        }
                        .foregroundStyle(.primary)
                    }
                }
                if !recentSearchModel.searchItems.isEmpty {
                    RecentSearchFavoritesView(recentSearchModel: recentSearchModel, viewModel: viewModel, results: $results)
                }
            }
            .padding(.horizontal, 30)
        }
    }
    
    struct ResultsSearchView: View {
        @EnvironmentObject var stopStore: StopStore
        @ObservedObject var viewModel: ItineraryViewModel
        @ObservedObject var locationViewModel: LocationSearchViewModel
        @EnvironmentObject var recentSearchModel: RecentSearch
        @Binding var results: Results
        @StateObject var locationManager = LocationManager()
        
        
        @State private var showMap = false
        @State private var resultCoordinates: CLLocationCoordinate2D?
        @State private var resultTitle: String?
        @State private var resultDetail: searchResultItem?
        @State private var locationSearch = false
        
        var focusField: FocusState<TripField?>.Binding
        
        var body: some View {
                LazyVStack {
                    Picker("", selection: $locationSearch) {
                        Text("Arrêts").tag(false)
                        Text("Lieux").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    if !locationSearch {
                        if !stopStore.filteredStops.isEmpty {
                            HStack {
                                Text("Arrêts")
                                    .font(.title3).bold()
                                Spacer()
                            }
                            .padding(.horizontal, 30)
                        }
                        ForEach(stopStore.filteredStops) { stop in
                            Button(action: {
                                let geoPosition = GeoPosition(name: stop.name, coordinate: CLLocationCoordinate2D(latitude: Double(stop.wgs84Coordinates.lat), longitude: Double(stop.wgs84Coordinates.lon)))
                                withAnimation {
                                    if viewModel.selectedField == .departure {
                                        viewModel.departureStop = stop
                                        viewModel.departureSearchText = stop.name
                                        viewModel.geoDeparture = false
                                        viewModel.departureGeoPosition = geoPosition
                                        viewModel.selectedField = .arrival
                                    } else {
                                        viewModel.arrivalStop = stop
                                        viewModel.arrivalSearchText = stop.name
                                        viewModel.geoArrival = false
                                        viewModel.arrivalGeoPosition = geoPosition
                                        viewModel.selectedField = .departure
                                    }
                                    results = Results.favorites
                                    viewModel.tripDone = false
                                    focusField.wrappedValue = nil
                                    recentSearchModel.add(name: stop.name, isStop: true, stop: stop, geoCoordinates: nil)
                                    stopStore.searchText = ""
                                }
                            }) {
                                BasicLocationView(name: stop.name, transportType: stop.meansOfTransport, showButton: true, favoriteAction:  {
                                    resultDetail = searchResultItem(title: stop.name, coordinates: CLLocationCoordinate2D(latitude: stop.wgs84Coordinates.lat, longitude: stop.wgs84Coordinates.lon))
                                    resultTitle = stop.name
                                })
                                .padding(.horizontal, 30)
                            }
                            .foregroundStyle(.primary)
                        }
                    } else {
                        HStack {
                            Text("Lieux")
                                .font(.title3).bold()
                                .padding(.top)
                            Spacer()
                        }
                        .padding(.horizontal, 30)
                        ForEach(locationViewModel.searchResults, id: \.self) { result in
                            Button(action: {
                                self.locationViewModel.getCoordinate(for: result) { coordinate in
                                    if let coordinate = coordinate {
                                        withAnimation {
                                            if viewModel.selectedField == .departure {
                                                viewModel.departureGeoPosition = GeoPosition(name: result.title, coordinate: coordinate)
                                                viewModel.geoDeparture = true
                                                viewModel.departureSearchText = result.title
                                                viewModel.selectedField = .arrival
                                            } else if viewModel.selectedField == .arrival {
                                                viewModel.arrivalGeoPosition = GeoPosition(name: result.title, coordinate: coordinate)
                                                viewModel.geoArrival = true
                                                viewModel.arrivalSearchText = result.title
                                                viewModel.selectedField = .departure
                                            }
                                            results = Results.favorites
                                            viewModel.tripDone = false
                                            focusField.wrappedValue = nil
                                            stopStore.searchText = ""
                                            recentSearchModel.add(name: "\(result.title);\(result.subtitle)", isStop: false, stop: nil, geoCoordinates: coordinate.toCoordinates)
                                        }
                                    }
                                }
                            }) {
                                BasicLocationView(name: result.title, subtitle: result.subtitle, isGeoPosition: true, showButton: true, favoriteAction:  {
                                    self.locationViewModel.getCoordinate(for: result) { coordinate in
                                        resultDetail = searchResultItem(title: result.title, coordinates: coordinate ?? CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0))
                                    }
                                })
                            }
                            .padding(.horizontal, 30)
                            .foregroundStyle(.primary)
                            
                        }
                    }
                }
                .sheet(item: $resultDetail) { detail in
                    MapPreview(resultDetail: detail, position: .region(MKCoordinateRegion(center: detail.coordinates, span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007))))
                        .presentationDetents([.medium, .fraction(0.9)])
                        .presentationCornerRadius(35)
                }
        }
    }
    
    struct ResultsCloseStopsView: View {
        @EnvironmentObject var stopStore: StopStore
        @ObservedObject var viewModel: ItineraryViewModel
        
        @Binding var calculationSuccess: Bool
        @Binding var showCloseStops: Bool
        @Binding var closestStops: [Stop]
        @Binding var results: Results
                
        @StateObject var locationManager = LocationManager()
        
        @State private var showMap = false
        @State private var resultCoordinates: CLLocationCoordinate2D?
        @State private var resultTitle: String?
        @State private var resultDetail: searchResultItem?
        
        var body: some View {
            if calculationSuccess {
                if showCloseStops {
                    if !closestStops.isEmpty {
                        LazyVStack {
                            Button {
                                locationManager.requestLocation { location in
                                    guard let userLocation = locationManager.userLocation else {
                                        Log.location.error("Position indisponible")
                                        return
                                    }
                                    
                                    let coordinate = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
                                    withAnimation {
                                        if viewModel.selectedField == .departure {
                                            // Execute only when selectedTextField is 1
                                            viewModel.departureGeoPosition = GeoPosition(name: "Ma position", coordinate: coordinate)
                                            viewModel.geoDeparture = true
                                            viewModel.departureSearchText = "Ma position"
                                            results = Results.favorites
                                            showCloseStops = false
                                            calculationSuccess = false
                                            viewModel.selectedField = .arrival
                                            viewModel.tripDone = false
                                        } else if viewModel.selectedField == .arrival {
                                            // Execute only when selectedTextField is 2
                                            viewModel.arrivalGeoPosition = GeoPosition(name: "Ma position", coordinate: coordinate)
                                            viewModel.geoArrival = true
                                            viewModel.arrivalSearchText = "Ma position"
                                            results = Results.favorites
                                            showCloseStops = false
                                            calculationSuccess = false
                                            viewModel.selectedField = .departure
                                            viewModel.tripDone = false
                                        }
                                    }
                                    
                                    // Clear the location update handler after executing the action
                                    locationManager.locationUpdateHandler = nil
                                }
                            } label: {
//                                RoundedRectangle(cornerRadius: 20)
                                BasicElement()
                                    .frame(height: 45)
                                    .overlay(
                                        HStack {
                                            Text("Utiliser la position actuelle")
                                            Spacer()
                                            Image(systemName: "location.circle").font(.title2).foregroundStyle(.accent)
                                        }
                                            .padding(.horizontal, 20)
                                    )
                                    .padding(.horizontal, 30)
                            }
                            HStack {
                                Text("Arrêts à proximité")
                                    .font(.title3).bold()
                                    .padding(.top)
                                Spacer()
                            }
                            .padding(.horizontal, 30)
                            ForEach(closestStops, id: \.id) { stop in
                                Button(action: {
                                    let geoPosition = GeoPosition(name: stop.name, coordinate: CLLocationCoordinate2D(latitude: Double(stop.wgs84Coordinates.lat), longitude: Double(stop.wgs84Coordinates.lon)))
                                    withAnimation {
                                        if viewModel.selectedField == .departure {
                                            viewModel.departureStop = stop
                                            viewModel.departureSearchText = stop.name
                                            viewModel.geoDeparture = false
                                            viewModel.departureGeoPosition = geoPosition
                                            viewModel.selectedField = .arrival
                                            showCloseStops = false
                                            calculationSuccess = false
                                            results = Results.favorites
                                            viewModel.tripDone = false
                                        } else if viewModel.selectedField == .arrival {
                                            viewModel.arrivalStop = stop
                                            viewModel.arrivalSearchText = stop.name
                                            viewModel.geoArrival = false
                                            viewModel.arrivalGeoPosition = geoPosition
                                            viewModel.selectedField = .departure
                                            showCloseStops = false
                                            calculationSuccess = false
                                            results = Results.favorites
                                            viewModel.tripDone = false
                                        }
                                    }
                                }) {
                                    BasicLocationView(name: stop.name, transportType: stop.meansOfTransport, showButton: true, favoriteAction:  {
                                        resultDetail = searchResultItem(title: stop.name, coordinates: CLLocationCoordinate2D(latitude: stop.wgs84Coordinates.lat, longitude: stop.wgs84Coordinates.lon))
                                        resultTitle = stop.name
                                    })
                                }
                                .padding(.horizontal, 30)
                                .foregroundStyle(.primary)
                            }
                        }
                        .sheet(item: $resultDetail) { detail in
                            MapPreview(resultDetail: detail, position: .region(MKCoordinateRegion(center: detail.coordinates, span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007))))
                                .presentationDetents([.medium, .fraction(0.9)])
                                .presentationCornerRadius(35)
                        }
                    } else {
                        Text("Pas d'arrêts trouvés à proximité")
                    }
                } else {
                    Text("Chargement...")
                }
            }
            
        }
    }
    
    struct ResultsTripView: View {
        @ObservedObject var viewModel: ItineraryViewModel
        
        @ObservedObject var tripManager: TripManager
        @EnvironmentObject var savedTripsModel: SavedTripsModel
        @Binding var showTime: Bool
        
        let adjustTime: (Int) -> Void
        let timeChange: () -> Int
        let searchTrips: () -> Void
        
        var body: some View {
            LazyVStack(spacing: 5) {

                ForEach(tripManager.tripEvents.sorted(by: { $0.startTime < $1.startTime }), id: \.id) { event in
                        NavigationLink {
                            FullTripView(fullTrip: event)
//                                .environmentObject(savedTripsModel)
                        } label: {
                            BasicElement()
                            .padding(4)
                            .frame(height: 80)
//                            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                            .overlay(
                                TripElementView(event: event, showTime: showTime)
                                    .padding(.horizontal, 20)
                            )
                            
//                            TripElementView(event: event, showTime: showTime)
//                                .padding(.horizontal)
//                                .background {
//                                    Capsule()
//                                    .fill(.thinMaterial)
//                                    .frame(height: 80)
//                                    .shadow(color: Color.customShadows, radius: 1.5, y: 1)
//                                }
                    }
                    .foregroundStyle(.primary)
                    .contentShape(.contextMenuPreview, Capsule())
                    .padding(.horizontal, 25)
                    .contextMenu {
                        if savedTripsModel.tripIsSaved(event) {
                            Button(action: {
                                savedTripsModel.removeTrip(event)
                            }) {
                                Label("Ne plus enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.minus")
                            }
                        } else {
                            Button(action: {
                                savedTripsModel.addTrip(event)
                            }) {
                                Label("Enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.plus")
                            }
                        }
                    } preview: {
                        TripMapView(tripEvent: event, isPreview: true)
                            .frame(width: UIScreen.main.bounds.width, height: 300)
                    }
                }
            }
        }
    }
    
    struct ResultsEmptyView: View {
        var body: some View {
            Spacer()
        }
    }
    
    struct TripFieldButton: View {
        @ObservedObject var viewModel: ItineraryViewModel
        @Binding var searchText: String
        @Binding var showCloseStops: Bool
        @Binding var calculationSuccess: Bool
        @Binding var closestStops: [Stop]
        @Binding var results: Results
        
        var focusField: FocusState<TripField?>.Binding
        
        
        var field: TripField
        
        @StateObject var locationManager = LocationManager()
        @EnvironmentObject var stopStore: StopStore
        
        var body: some View {
            if searchText.isEmpty && viewModel.selectedField == field {
                Button(action: {
                    if !showCloseStops {
                        withAnimation {
                            results = Results.closeStops
                            focusField.wrappedValue = nil
                        }
                    } else {
                        withAnimation {
                            results = Results.favorites
                        }
                    }
                    showCloseStops.toggle()
                    if showCloseStops {
                        locationManager.requestLocation { location in
                            if let userLocation = locationManager.userLocation {
                                calculateClosestBusStops(from: userLocation, stops: stopStore.activeStops, nb: 6) { success, stops in
                                    if success {
                                        closestStops = stops
                                        calculationSuccess = true
                                    }
                                }
                            } else {
                                // Sans position, la liste vide affiche « Pas d'arrêts trouvés à proximité » au lieu de charger indéfiniment.
                                Log.location.error("Position indisponible pour les arrêts proches")
                                closestStops = []
                                calculationSuccess = true
                            }
                            locationManager.locationUpdateHandler = nil
                        }
                    }
                }) {
                    Image(systemName: (showCloseStops ? "location.fill" :  "location")).font(.title3)
                }
            } else if !searchText.isEmpty {
                Button(action: {
                    withAnimation {
                        searchText = ""
                        viewModel.selectedField = field
                        viewModel.tripDone = false
                        if field == .departure {
                            viewModel.departureStop = nil
                            viewModel.departureGeoPosition = nil
                            viewModel.geoDeparture = false
                        } else if field == .arrival {
                            viewModel.arrivalStop = nil
                            viewModel.arrivalGeoPosition = nil
                            viewModel.geoArrival = false
                        }
                    }
                }) {
                    Image(systemName: "xmark").font(.title2)
                }
            }
        }
    }
    struct TripPointField: View {
        @ObservedObject var viewModel: ItineraryViewModel
        @Binding var results: Results
        var focusField: FocusState<TripField?>.Binding

        var field: TripField
        
        var body: some View {
            let selected = viewModel.selectedField == field
            let hasSelection = (field == .departure && viewModel.hasDeparture) || (field == .arrival && viewModel.hasArrival)
            ZStack {
                HStack {
                    HStack {
                        if hasSelection && focusField.wrappedValue != field {
                            if field == .departure {
                                Image(systemName: viewModel.geoDeparture ? "mappin.and.ellipse.circle" : "figure.wave.circle")
                                    .font(.title2)
                                    .foregroundStyle(selected ? .accent : .primary)
                            } else if field == .arrival {
                                Image(systemName: viewModel.geoArrival ? "mappin.and.ellipse.circle" : "figure.wave.circle")
                                    .font(.title2)
                                    .foregroundStyle(selected ? .accent : .primary)
                            }
                        } else {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(selected ? .accent : .primary.opacity(0.2))
                        }
                        if field == .arrival {
                            TextField("Destination", text: $viewModel.arrivalSearchText)
                            //                            .frame(height: size)
                                .focused(focusField, equals: .arrival)
                            //                            .opacity(focusField.wrappedValue == .arrival ? 1:0)
                                .onChange(of: viewModel.arrivalSearchText) {
                                    if selected {
                                        if hasSelection && focusField.wrappedValue == nil {
                                            results = Results.empty
                                        } else if !viewModel.arrivalSearchText.isEmpty {
                                            results = Results.search
                                        } else if viewModel.arrivalSearchText.isEmpty {
                                            results = Results.favorites
                                        }
                                    }
                                }
                        } else {
                            TextField("Origine", text: $viewModel.departureSearchText)
                            //                            .frame(height: size)
                                .focused(focusField, equals: .departure)
                            //                            .opacity(focusField.wrappedValue == .departure ? 1:0)
                                .onChange(of: viewModel.departureSearchText) {
                                    if selected {
                                        if hasSelection && focusField.wrappedValue == nil {
                                            results = Results.empty
                                        } else if !viewModel.departureSearchText.isEmpty {
                                            results = Results.search
                                        } else if viewModel.departureSearchText.isEmpty {
                                            results = Results.favorites
                                        }
                                    }
                                }
                        }
                        //                    if text.isEmpty {
                        ////                        Text(emptyText)
                        ////                            .opacity(0.4)
                        //                        TextField
                        //                    } else {
                        ////                        Text(text)
                        //                    }
                        Spacer()
                    }
                    
                    .mask {
                        Rectangle()
                            .overlay(alignment: .trailing) {
                                ScrollMask(leading: false, vertical: false, gradientLength: 40)
                            }
                            .padding(.trailing, 20)
                    }
                    if selected {
                        Image(systemName: "record.circle.fill")
                            .foregroundStyle(.accent)
                    }
                }
                .onTapGesture {
                    withAnimation {
                        focusField.wrappedValue = field
                        viewModel.selectedField = field
                        
                        if viewModel.geoArrival {
                            viewModel.arrivalSearchText = viewModel.arrivalGeoPosition?.name ?? ""
                        } else {
                            viewModel.arrivalSearchText = viewModel.arrivalStop?.name ?? ""
                        }
                    }
                }
                .padding(.horizontal)
                
//                Capsule()
//                        .stroke(textFieldSelected ? .accent : .gray.opacity(0.3), lineWidth: 2)
//                        .shadow(color: textFieldSelected ? Color.customShadows2 : .clear, radius: 2, y: 1.5)
            }
        }
    }
    
    struct RecentSearchFavoritesView: View {
        @ObservedObject var recentSearchModel: RecentSearch
        @ObservedObject var viewModel: ItineraryViewModel
        @Binding var results: Results
        
        @State private var showMap = false
        @State private var resultCoordinates: CLLocationCoordinate2D?
        @State private var resultTitle: String?
        @State private var resultDetail: searchResultItem?
        
        var body: some View {
            VStack(spacing: 10) {
                HStack {
                    Text("Recherches récentes")
                        .font(.title3).bold()
                        .padding(.top)
                    Spacer()
                }
                ForEach(recentSearchModel.searchItems, id: \.self) { item in
                    Button(action : {
                        if item.isStop {
                            if viewModel.selectedField == .departure {
                                viewModel.departureStop = item.stop
                                viewModel.departureSearchText = item.name
                                viewModel.geoDeparture = false
                                viewModel.selectedField = .arrival
                            } else {
                                viewModel.arrivalStop = item.stop
                                viewModel.arrivalSearchText = item.name
                                viewModel.geoArrival = false
                                viewModel.selectedField = .departure
                            }
                            results = Results.favorites
                            recentSearchModel.add(name: item.name, isStop: true, stop: item.stop, geoCoordinates: nil)
                        } else {
                            let title = item.name.split(separator: ";")
                            let coordinates = item.geoCoordinates?.toCLLocationCoordinate2D ?? CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
                            if viewModel.selectedField == .departure {
                                viewModel.departureGeoPosition = GeoPosition(name: String(title[0]), coordinate: coordinates)
                                viewModel.geoDeparture = true
                                viewModel.departureSearchText = String(title[0])
                                viewModel.selectedField = .arrival
                            } else if viewModel.selectedField == .arrival {
                                viewModel.arrivalGeoPosition = GeoPosition(name: String(title[0]), coordinate: coordinates)
                                viewModel.geoArrival = true
                                viewModel.arrivalSearchText = String(title[0])
                                viewModel.selectedField = .departure
                            }
                            results = Results.favorites
                            viewModel.tripDone = false
                            recentSearchModel.add(name: item.name, isStop: false, stop: nil, geoCoordinates: item.geoCoordinates)
                        }
                        
                    }) {
                        if item.isStop {
                            BasicLocationView(name: item.name, showButton: true, favoriteAction:  {
                                resultDetail = searchResultItem(title: item.name, coordinates: item.stop?.wgs84Coordinates.toCLLocationCoordinate2D ?? CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0))
                                resultTitle = item.name
                            })
                        } else {
                            let title = item.name.split(separator: ";")
                            BasicLocationView(name: String(title[0]), subtitle: String(title[1]), isGeoPosition: true, showButton: true, favoriteAction:  {
                                resultDetail = searchResultItem(title: String(title[0]), coordinates:item.geoCoordinates?.toCLLocationCoordinate2D ?? CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0))
                            })
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .sheet(item: $resultDetail) { detail in
                MapPreview(resultDetail: detail, position: .region(MKCoordinateRegion(center: detail.coordinates, span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007))))
                    .presentationDetents([.medium, .fraction(0.9)])
                    .presentationCornerRadius(35)
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
        let tripEventsSorted = tripManager.tripEvents.sorted(by: { $0.startTime < $1.startTime })
        let firstTime: Date = stringToDate(with: tripEventsSorted.first?.startTime ?? "") ?? Date()
        let lastTime: Date = stringToDate(with: tripEventsSorted.last?.startTime ?? "") ?? Date()
        let timeChange = lastTime.timeIntervalSince(firstTime)/60
        
        return Int(timeChange)
    }
    private func moveTime(previous: Bool) { //Move departures time earlier or later (with top and bottom buttons)
        adjustTime(byAdding: previous ? -timeChange() : timeChange())
        searchTrips()
    }
    
    func searchTrips() {
        if ((viewModel.geoDeparture && viewModel.departureGeoPosition != nil) || viewModel.departureStop != nil) && ((viewModel.geoArrival && viewModel.arrivalGeoPosition != nil) || viewModel.arrivalStop != nil) {
            results = Results.loading
            tripManager.tripEvents.removeAll()
            tripManager.selectTrip(with: viewModel.departureStop, with: viewModel.departureGeoPosition, with: viewModel.geoDeparture, with: viewModel.arrivalStop, with: viewModel.arrivalGeoPosition, with: viewModel.geoArrival, with: viewModel.selectedTime, with: viewModel.isArrivalTime)
            viewModel.tripDone = true
            showCloseStops = false
            calculationSuccess = false
//            results = Results.tripResults
        }
    }
}

struct MapPreview: View {
    var resultDetail: searchResultItem
    @State var position: MapCameraPosition
    
    var body: some View {
            Map(position: $position) {
                Annotation(resultDetail.title, coordinate: resultDetail.coordinates, anchor: .center) {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                        .background(
                            Circle()
                                .fill(.color1)
                        )
                        .frame(width: 15, height: 15)
                }
                UserAnnotation()
            }
            .safeAreaPadding(10)
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
    }
}

struct CustomPicker: View {
    @Binding var secondSelected: Bool
    var height: CGFloat
    var firstOption: String
    var firstIcon: String?
    var secondOption: String
    var secondIcon: String?
    var name = "shape"
    var animation: Namespace.ID
    @State var firstSelected: Bool = true
    var body: some View {
            HStack {
                ZStack {
                        if firstSelected {
//                            RoundedRectangle(cornerRadius: 20)
                            BasicElement()
                                .frame(height: height)
                                .matchedGeometryEffect(id: name, in: animation)
                        }
                    Button {
                                            withAnimation {
                                                firstSelected = true
                                            }
                    } label: {
                        
                        HStack {
                            Spacer()
                            if firstIcon != nil {
                                Image(systemName: firstIcon!)
                            }
                            Text(firstOption)
                            Spacer()
                        }
                        .scaleEffect(firstSelected ?  1 : 0.9)
                    }
                }
                ZStack {
                        if !firstSelected {
//                            RoundedRectangle(cornerRadius: 20)
                            BasicElement()
                                .frame(height: height)
                                .matchedGeometryEffect(id: name, in: animation)
                        }
                    Button {
                                            withAnimation {
                                                firstSelected = false
                                            }
                    } label: {
                        HStack {
                            Spacer()
                            if secondIcon != nil {
                                Image(systemName: secondIcon!)
                            }
                            Text(secondOption)
                            Spacer()
                        }
                        .scaleEffect(!firstSelected ?  1 : 0.9)
                    }
                }
            }
            .foregroundStyle(.primary)
            .background {
//                RoundedRectangle(cornerRadius: 20)
                Capsule()
                    .stroke(.gray.opacity(0.3), lineWidth: 2)
                    .frame(height: height-3)
//                    .padding(5)
            }
            .onAppear {
                firstSelected = !secondSelected
            }
            .onChange(of: firstSelected) {
                withAnimation {
                    secondSelected = !firstSelected
                }
            }
    }
}

struct SavedTripsView: View {
    @EnvironmentObject var savedTripsModel: SavedTripsModel
    @EnvironmentObject var regularTripsModel: RegularTripsModel
    @Binding var isPresented: Bool
    
    let onTripSelected: (TripEvent) -> Void
    
    var body: some View {
        ZStack {
            VStack {
                Rectangle()
                    .frame(height: 10)
                    .foregroundStyle(.clear)
                ScrollView {
                    ForEach(groupedEvents.keys.sorted(by: { $0 > $1 }), id: \.self) { date in
                        VStack(spacing: 0) {
                            // Display date as header in the desired format
                            HStack {
                                Text(formatDate(date))
                                    .font(.title3).bold()
                                    .padding(.top)
                                Spacer()
                            }
                            .padding(.horizontal, 30)
                            // Display events for this date
                            ForEach(groupedEvents[date]!.sorted(by: { $0.startTime < $1.startTime }), id: \.self) { trip in
                                Button(action: {
                                    onTripSelected(trip)
                                }) {
                                    VStack {
                                        SavedTripView(event: trip)
                                            .padding(15)
                                    }
                                    .background(
                                        BasicCard(cornerRadius: 30)
                                    )
                                }
                                .padding(5)
                                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 35))
                                .contextMenu {
                                    Button(action: {
                                        savedTripsModel.removeTrip(trip)
                                    }) {
                                        Label("Ne plus enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.minus")
                                    }
                                }
                                .padding(.horizontal, 15)
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                    Rectangle()
                        .frame(height: 10)
                        .foregroundStyle(.clear)
                }
                .contentMargins(.top, 60.0, for: .automatic)
            }
            VStack {
//                RoundedRectangle(cornerRadius: 25)
                Capsule()
                    .fill(.thinMaterial)
                    .frame(height: 60)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                    .padding(10)
                    .overlay(
                        Text("Itinéraires sauvegardés")
                            .font(.title2)
                            .bold()
                            .frame(height: 20.0)
                    )
                Spacer()
            }
            .contentMargins(.horizontal, 20, for: .automatic)
        }
    }
    var weeklyGeneratedTrips: [TripEvent] {
        let calendar = Calendar.current
        let today = Date()
        let weekdays = (0...6).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }

        return regularTripsModel.regularTrips.flatMap { regularTrip in
            weekdays.compactMap { day -> TripEvent? in
                guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: day)) else { return nil }
                guard regularTrip.repeatingDays.contains(weekday) else { return nil }
                if let start = regularTrip.startDate, day < start { return nil }
                if let end = regularTrip.endDate, day > end { return nil }
                if regularTrip.exceptions.contains(where: { calendar.isDate($0, inSameDayAs: day) }) { return nil }

                var trip = regularTrip.trip
                trip.id = trip.id + UUID().uuidString // Differentiate each instance
                return trip
            }
        }
        
        func updateRegularTrip(_ trip: inout RegularTrip) {
            for leg in trip.trip.legs {
                if leg.transfer == false && leg.journeyRef != "" {
                    
                }
            }
        }
    }

    var groupedEvents: [Date: [TripEvent]] {
        let combined = savedTripsModel.savedTrips + weeklyGeneratedTrips
        return Dictionary(grouping: combined) { event in
            if let date = stringToDate(with: event.startTime) {
                return Calendar.current.startOfDay(for: date)
            } else {
                return Calendar.current.startOfDay(for: Date())
            }
        }
    }
    func formatDate(_ date: Date) -> String {
            let dateFormatter = DateFormatter()
//            dateFormatter.dateFormat = "EEE, d MMMM yyyy"
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        let formattedDate = dateFormatter.string(from: date)
            return formattedDate.prefix(1).capitalized + formattedDate.dropFirst()
        }
}

struct SavedTripView: View {
    var event: TripEvent
    
    var body: some View {
        VStack(alignment: .center) {
            HStack {
//                RoundedRectangle(cornerRadius: 20.0)
                BasicElement()
                    .frame(height: 45)
//                    .foregroundStyle(.thinMaterial)
//                    .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                    .overlay (
                        HStack {
                            Circle()
                                .strokeBorder(.primary, lineWidth: 5)
                                .background(Circle().fill(.color1))
                                .frame(width: 18, height: 18)
                            SmallStopTitleView(stopName: event.startName)
                            Text(dateToString(with: stringToDate(with: event.startTime) ?? Date()))
                            Spacer()
                        }
                            .padding(.horizontal)
                        )
            }
            HStack(spacing: 0) {
                    Image(systemName: "arrowshape.bounce.forward")
                    Text(" : \(event.transfers)")
                        .padding(.trailing)
                    Image(systemName: "timer")
                    if event.duration.count == 7 {
                        Text(" : \(event.duration.dropFirst(2).dropLast(1))")
                    } else {
                        Text(" : \(event.duration.dropFirst(2).dropLast(1))'")
                    }
                // Scrollable icon area
                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Spacer()
                            ForEach(event.legs, id: \.id) { leg in
                                if !(leg.publishedLineName == "") {
                                    BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
                                        .padding(2)
                                } else if leg.transfer && Int(leg.transferWalkDuration.dropFirst(2).dropLast(1)) ?? 0 >= 5 {
                                    Image(systemName: "figure.walk").font(.caption)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                    }
                    .mask {
                        Rectangle()
                            .overlay(alignment: .leading) {
                                ScrollMask(leading: true, vertical: false, gradientLength: 25)
                            }
                    }
                    .mask {
                        Rectangle()
                            .overlay(alignment: .trailing) {
                                ScrollMask(leading: false, vertical: false, gradientLength: 25)
                            }
                    }
                    
                }
            }
            .padding(.vertical, 3)
            HStack {
//                RoundedRectangle(cornerRadius: 20.0)
                BasicElement()
                    .frame(height: 45)
                    .overlay (
                        HStack {
                            Circle()
                                .strokeBorder(.primary, lineWidth: 5)
                                .background(Circle().fill(.color1))
                                .frame(width: 18, height: 18)
                            SmallStopTitleView(stopName: event.endName)
                            Text(dateToString(with: stringToDate(with: event.endTime) ?? Date()))
                            Spacer()
                        }
                            .padding(.horizontal)
                        )
            }
            
        }
    }
}
struct TripView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()
        @StateObject var fullTripTest = FullTripTest()
        
        @StateObject var savedTripsModel = SavedTripsModel()
        @StateObject var regularTripsModel = RegularTripsModel()
        @StateObject var appRequirementsClass = AppRequirementsClass()
            @StateObject var itineraryViewModel = ItineraryViewModel()
        @State var boolTest: Bool = true
        @State var showTime: Bool = true
        
        return
            NavigationStack {
                TripView(tripManager: TripManager())
                    .environmentObject(itineraryViewModel)
                    .environmentObject(stopStore)
                    .environmentObject(favoritesViewModel)
                    .environmentObject(savedTripsModel)
                    .environmentObject(regularTripsModel)
                    .environmentObject(appRequirementsClass)
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

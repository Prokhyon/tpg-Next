//
//  TripView.swift
//  TPG4
//
//  Created by Loris Thomas on 30.06.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc


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
    
    func invertStops() {
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
        print("Error: \(error.localizedDescription)")
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

struct ListView: View {
    let range = 1..<10
    enum Results {
        case one, two
    }
    
    @State var results = Results.one
    var body: some View {
        ForEach(range) {_ in 
            Capsule()
                .frame(height: 50)
                .padding()
        }
        var test = VStack {
            switch results {
                
            case .one:
                Text("")
            case .two:
                Text("")
            }
        }
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
    
    @FocusState private var firstIsFocused: Bool
    @FocusState private var secondIsFocused: Bool
    
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
    
    @AppStorage("TimeDefault") var timeDefault = false
    
    enum Results {
        case empty, favorites, search, closeStops, tripResults, loading
    }
    
    @State var results = Results.favorites
    
    var body: some View {
        ZStack {
            VStack {
                    let resultsView = VStack {switch results {
                    case .empty:
                        ResultsEmptyView()
                    case .favorites:
//                        ListView()
                        ResultsFavoritesView(viewModel: viewModel, results: $results, firstFocus: $firstIsFocused, secondFocus: $secondIsFocused)
                            .environmentObject(recentSearchModel)
                    case.search:
                        ResultsSearchView(viewModel: viewModel, locationViewModel: locationViewModel, results: $results, firstFocus: $firstIsFocused, secondFocus: $secondIsFocused)
                            .environmentObject(recentSearchModel)
                    case.closeStops:
                        ResultsCloseStopsView(viewModel: viewModel, calculationSuccess: $calculationSuccess, showCloseStops: $showCloseStops, closestStops: $closestStops, results: $results, firstFocus: $firstIsFocused, secondFocus: $secondIsFocused)
                    case.tripResults:
                        ResultsTripView(viewModel: viewModel, tripManager: tripManager, showTime: $showTime, adjustTime: adjustTime, timeChange: timeChange, searchTrips: searchTrips)
                    case.loading:
                        Text("Chargement...")
                    }
                }
                if #available(iOS 26, *) {
                    ScrollView {
                        resultsView
                    }
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .scrollDismissesKeyboard(.immediately)
//                    .contentMargins(.top, 320.0, for: .automatic)
                    .contentMargins(.bottom, 320.0, for: .automatic)
                } else {
                    ScrollView {
                        resultsView
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .contentMargins(.top, 320.0, for: .automatic)
                    .contentMargins(.bottom, appRequirementsClass.version26 ? 0: 75, for: .automatic)
                }
            }
            .onChange(of: viewModel.selectedTextField) {
                if (viewModel.departureSearchText == viewModel.departureStop?.name && viewModel.selectedTextField == 1) || (viewModel.arrivalSearchText == viewModel.arrivalStop?.name && viewModel.selectedTextField == 2) {
                    results = Results.empty
                }
            }
            .onChange(of: firstIsFocused) {
                if firstIsFocused {
                    viewModel.selectedTextField = 1
                }
            }
            .onChange(of: secondIsFocused) {
                if secondIsFocused {
                    viewModel.selectedTextField = 2
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
                if !tripManager.tripEvents.isEmpty {
                    results = Results.tripResults
                }
            }
            .onChange(of: viewModel.tripDone) {
                if viewModel.tripDone {
                    results = Results.loading
                } else {
                    results = Results.favorites
                }
            }
            .onAppear(perform: {
                showTime = timeDefault
                if !viewModel.tripDone {
                    viewModel.selectedTime = Date()
                    viewModel.isArrivalTime = false
                }
                if viewModel.quickTrip && !viewModel.tripDone {
                    print("TripViewAppear: quickTrip")
                    
                    locationManager.requestLocation { location in
                        guard let userLocation = locationManager.userLocation else {
                            print("error")
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
                    print("TripViewAppear: quickTrip && tripDone")
                    results = Results.loading
                }
                print(results)
            })
            
            VStack(spacing: 5) {
//                HStack {
//                    Text("Itinéraire")
//                        .font(.title)
//                        .bold()
//                    Spacer()
//                    if #available(iOS 26, *) {
//                        HStack(spacing: 0) {
//                            //                            if results == .tripResults {
//                            Button {
//                                self.showTime.toggle()
//                            } label: {
//                                Image(systemName: "hourglass")
//                                    .padding(.horizontal, 5)
//                                    .foregroundColor(showTime ? .white : Color.text)
//                                    .padding(16)
//                                    .background {
//                                        Capsule()
//                                            .fill(showTime ? Color.accentColor : Color.clear)
//                                        //                                                .opacity(0.8)
//                                            .padding(5)
//                                    }
//                            }
//                            
//                            //                            }
//                            Button {
//                                self.showSavedTrips.toggle()
//                            } label: {
//                                Image("scurvepath.stack.fill")
//                                    .foregroundColor(Color.text)
//                                    .padding(.horizontal, 15)
//                                    .padding(.vertical, 15)
//                            }
//                        }
//                        .glassEffect(.regular.interactive())
//                        
//                    } else {
//                        HStack {
//                            if results == .tripResults {
//                                Button(action: {
//                                    self.showTime.toggle()
//                                }) {
//                                    Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill")
//                                        .font(.title)
//                                        .padding(.trailing)
//                                }
//                            }
//                            Button(action: {
//                                self.showSavedTrips.toggle()
//                            }) {
//                                Image("scurvepath.stack.fill")
//                                    .font(.title)
//                            }
//                        }
//                        .frame(height: 25)
//                        .padding(.bottom, 10)
//                    }
//                }
//                .padding(.horizontal)
//                .padding(.bottom, 5)
//                .offset(y: 60)
//                .zIndex(1)
//                .ignoresSafeArea(edges: .top)
                
                //Previous and next buttons
                if results == .tripResults {
                    HStack {
                        Spacer()
                        if #available(iOS 26, *) {
                            HStack {
                                Button(action: {
                                    adjustTime(byAdding: -timeChange())
                                    searchTrips()
                                }) {
                                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                        .padding()
                                }
                                Button(action: {
                                    adjustTime(byAdding: timeChange())
                                    searchTrips()
                                }) {
                                    Image(systemName: "text.line.last.and.arrowtriangle.forward")
                                        .padding()
                                }
                            }
                            .foregroundStyle(.primary)
                            .glassEffect(.regular.interactive())
                        } else {
                            HStack {
                                Button(action: {
                                    adjustTime(byAdding: -timeChange())
                                    searchTrips()
                                }) {
                                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                        .padding()
                                }
                                Button(action: {
                                    adjustTime(byAdding: timeChange())
                                    searchTrips()
                                }) {
                                    Image(systemName: "text.line.last.and.arrowtriangle.forward")
                                        .padding()
                                }
                            }
                            .background {
                                Capsule()
                                    .foregroundStyle(.thinMaterial)
                                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
                VStack(spacing: 20) {
                    HStack {
                        VStack {
                            CustomTextField(viewModel: viewModel, text: $viewModel.departureSearchText, results: $results, focus: $firstIsFocused, fieldNumber: 1, emptyText: String(localized: "départ"))
                                .onTapGesture {
                                    viewModel.selectedTextField = 1
                                    firstIsFocused = true
                                    
                                    if viewModel.geoArrival {
                                        viewModel.arrivalSearchText = viewModel.arrivalGeoPosition?.name ?? ""
                                    } else {
                                        viewModel.arrivalSearchText = viewModel.arrivalStop?.name ?? ""
                                    }
                                }
                                .overlay {
                                    HStack {
                                        Spacer()
                                        textFieldOverlay(viewModel: viewModel, searchText: $viewModel.departureSearchText, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focus: $firstIsFocused, textField: 1).padding(.horizontal, 7)
                                    }
                                }
                            
                            CustomTextField(viewModel: viewModel, text: $viewModel.arrivalSearchText, results: $results, focus: $secondIsFocused, fieldNumber: 2, emptyText: String(localized: "arrivée"))
                                .onTapGesture {
                                    viewModel.selectedTextField = 2
                                    secondIsFocused = true
                                    
                                    if viewModel.geoDeparture {
                                        viewModel.departureSearchText = viewModel.departureGeoPosition?.name ?? ""
                                    } else {
                                        viewModel.departureSearchText = viewModel.departureStop?.name ?? ""
                                    }
                                }
                                .overlay {
                                    HStack {
                                        Spacer()
                                        textFieldOverlay(viewModel: viewModel, searchText: $viewModel.arrivalSearchText, showCloseStops: $showCloseStops, calculationSuccess: $calculationSuccess, closestStops: $closestStops, results: $results, focus: $secondIsFocused, textField: 2).padding(.horizontal, 7)
                                    }
                                }
                        }
                        Button {
                            viewModel.invertStops()
                            if viewModel.selectedTextField == 1 {
                                stopStore.searchText = viewModel.departureSearchText
                            } else if viewModel.selectedTextField == 2 {
                                stopStore.searchText = viewModel.arrivalSearchText
                            }
                            viewModel.tripDone = false
                            results = Results.favorites
                        } label: {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.title)
                        }
                    }
                    HStack {
                        DatePicker(selection: $viewModel.selectedTime) {
                            Text("Date et heure:")
                        }
                        .padding(.trailing, 5)
                        Button(action: {
                            viewModel.selectedTime = Date()
                            viewModel.tripDone = false
                        }) {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90").font(.title2)
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
                                if (viewModel.departureStop != nil || viewModel.departureGeoPosition != nil) &&  (viewModel.arrivalStop != nil || viewModel.arrivalGeoPosition != nil) {
                                    searchTrips()
                                    viewModel.tripDone = true
                                }
                            } label: {
                                Text("Rechercher")
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal)
                                    .glassEffect(.regular.tint(.accentColor).interactive())
                            }
                        }
                    } else {
                        HStack {
                            CustomPicker(secondSelected: $viewModel.isArrivalTime, height: 45, firstOption: String(localized: "Départ"), firstIcon: nil, secondOption: String(localized: "Arrivée"), secondIcon: nil, animation: animation)
                                .frame(width: 220)
                            
                            Button {
                                if (viewModel.departureStop != nil || viewModel.departureGeoPosition != nil) &&  (viewModel.arrivalStop != nil || viewModel.arrivalGeoPosition != nil) {
                                    searchTrips()
                                    viewModel.tripDone = true
                                }
                            } label: {
                                Capsule()
                                    .fill(.accent)
                                    .shadow(color: Color.customShadows, radius: 1, y: 0.8)
                                    .frame(width: 110, height: 45)
                                    .overlay(Text("Rechercher").foregroundStyle(.white))
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 20)
                .background {
                    RoundedRectangle(cornerRadius: 35.0)
                        .foregroundStyle(.thinMaterial)
                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                }
                .onAppear(perform: {
                    if !tripManager.tripEvents.isEmpty {
                        print("changed to tripResults")
                        results = Results.tripResults
                    }
                })
                .padding(.horizontal)

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
            Button {
                self.showTime.toggle()
            } label: {
                Image(systemName: "hourglass")
                    .padding(.horizontal, 5)
                    .foregroundColor(showTime ? .white : Color.text)
                    .padding(16)
                    .background {
                        Capsule()
                            .fill(showTime ? Color.accentColor : Color.clear)
                        //                                                .opacity(0.8)
                            .padding(5)
                    }
            }
            
            //                            }
            Button {
                self.showSavedTrips.toggle()
            } label: {
                Image("scurvepath.stack.fill")
                    .foregroundColor(Color.text)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 15)
            }
        }
    }
    
    struct ResultsFavoritesView: View {
        @EnvironmentObject var stopStore: StopStore
        @EnvironmentObject var favoritesViewModel: FavoritesViewModel
        @ObservedObject var viewModel: ItineraryViewModel
        @EnvironmentObject var recentSearchModel: RecentSearch
        @Binding var results: Results
        var firstFocus: FocusState<Bool>.Binding
        var secondFocus: FocusState<Bool>.Binding
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
                            let geoPosition = GeoPosition(name: stop.name, coordinate: CLLocationCoordinate2D(latitude: Double(stop.wgs84Coordinates.lat), longitude: Double(stop.wgs84Coordinates.lon)))
                            if viewModel.selectedTextField == 1 {
                                viewModel.departureStop = stop
                                viewModel.departureSearchText = stop.name
                                viewModel.geoDeparture = false
                                viewModel.departureGeoPosition = geoPosition
                                viewModel.selectedTextField = 2
                                results = Results.favorites
                                firstFocus.wrappedValue = false
                                secondFocus.wrappedValue = false
                                viewModel.tripDone = false
                            } else if viewModel.selectedTextField == 2 {
                                viewModel.arrivalStop = stop
                                viewModel.arrivalSearchText = stop.name
                                viewModel.geoArrival = false
                                viewModel.arrivalGeoPosition = geoPosition
                                viewModel.selectedTextField = 1
                                results = Results.favorites
                                firstFocus.wrappedValue = false
                                secondFocus.wrappedValue = false
                                viewModel.tripDone = false
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
        
        var firstFocus: FocusState<Bool>.Binding
        var secondFocus: FocusState<Bool>.Binding
        
        @State private var showMap = false
        @State private var resultCoordinates: CLLocationCoordinate2D?
        @State private var resultTitle: String?
        @State private var resultDetail: searchResultItem?
        
        var body: some View {
                LazyVStack {
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
                            if viewModel.selectedTextField == 1 {
                                viewModel.departureStop = stop
                                viewModel.departureSearchText = stop.name
                                viewModel.geoDeparture = false
                                viewModel.departureGeoPosition = geoPosition
                                viewModel.selectedTextField = 2
                            } else {
                                viewModel.arrivalStop = stop
                                viewModel.arrivalSearchText = stop.name
                                viewModel.geoArrival = false
                                viewModel.arrivalGeoPosition = geoPosition
                                viewModel.selectedTextField = 1
                            }
                            results = Results.favorites
                            firstFocus.wrappedValue = false
                            secondFocus.wrappedValue = false
                            viewModel.tripDone = false
                            recentSearchModel.add(name: stop.name, isStop: true, stop: stop, geoCoordinates: nil)
                            stopStore.searchText = ""
                        }) {
                            BasicLocationView(name: stop.name, transportType: stop.meansOfTransport, showButton: true, favoriteAction:  {
                                resultDetail = searchResultItem(title: stop.name, coordinates: CLLocationCoordinate2D(latitude: stop.wgs84Coordinates.lat, longitude: stop.wgs84Coordinates.lon))
                                resultTitle = stop.name
                            })
                                .padding(.horizontal, 30)
                        }
                        .foregroundStyle(.primary)
                    }
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
                                        if viewModel.selectedTextField == 1 {
                                            viewModel.departureGeoPosition = GeoPosition(name: result.title, coordinate: coordinate)
                                            viewModel.geoDeparture = true
                                            viewModel.departureSearchText = result.title
                                            viewModel.selectedTextField = 2
                                        } else if viewModel.selectedTextField == 2 {
                                            viewModel.arrivalGeoPosition = GeoPosition(name: result.title, coordinate: coordinate)
                                            viewModel.geoArrival = true
                                            viewModel.arrivalSearchText = result.title
                                            viewModel.selectedTextField = 1
                                        }
                                        results = Results.favorites
                                        firstFocus.wrappedValue = false
                                        secondFocus.wrappedValue = false
                                        viewModel.tripDone = false
                                        stopStore.searchText = ""
                                        recentSearchModel.add(name: "\(result.title);\(result.subtitle)", isStop: false, stop: nil, geoCoordinates: coordinate.toCoordinates)
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
        
        var firstFocus: FocusState<Bool>.Binding
        var secondFocus: FocusState<Bool>.Binding
        
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
                                        print("error")
                                        return
                                    }
                                    
                                    let coordinate = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
                                    
                                    if viewModel.selectedTextField == 1 {
                                        // Execute only when selectedTextField is 1
                                        viewModel.departureGeoPosition = GeoPosition(name: "Ma position", coordinate: coordinate)
                                        viewModel.geoDeparture = true
                                        viewModel.departureSearchText = "Ma position"
                                        results = Results.favorites
                                        showCloseStops = false
                                        calculationSuccess = false
                                        firstFocus.wrappedValue = false
                                        secondFocus.wrappedValue = false
                                        viewModel.selectedTextField = 2
                                        viewModel.tripDone = false
                                    } else if viewModel.selectedTextField == 2 {
                                        // Execute only when selectedTextField is 2
                                        viewModel.arrivalGeoPosition = GeoPosition(name: "Ma position", coordinate: coordinate)
                                        viewModel.geoArrival = true
                                        viewModel.arrivalSearchText = "Ma position"
                                        results = Results.favorites
                                        showCloseStops = false
                                        calculationSuccess = false
                                        firstFocus.wrappedValue = false
                                        secondFocus.wrappedValue = false
                                        viewModel.selectedTextField = 1
                                        viewModel.tripDone = false
                                    }
                                    
                                    // Clear the location update handler after executing the action
                                    locationManager.locationUpdateHandler = nil
                                }
                            } label: {
//                                RoundedRectangle(cornerRadius: 20)
                                Capsule()
                                    .fill(.thinMaterial)
                                    .frame(height: 45)
                                    .shadow(color: Color.customShadows, radius: 1.5, y: 1)
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
                                    if viewModel.selectedTextField == 1 {
                                        viewModel.departureStop = stop
                                        viewModel.departureSearchText = stop.name
                                        viewModel.geoDeparture = false
                                        viewModel.departureGeoPosition = geoPosition
                                        viewModel.selectedTextField = 2
                                        showCloseStops = false
                                        calculationSuccess = false
                                        firstFocus.wrappedValue = false
                                        results = Results.favorites
                                        viewModel.tripDone = false
                                    } else if viewModel.selectedTextField == 2 {
                                        viewModel.arrivalStop = stop
                                        viewModel.arrivalSearchText = stop.name
                                        viewModel.geoArrival = false
                                        viewModel.arrivalGeoPosition = geoPosition
                                        viewModel.selectedTextField = 1
                                        showCloseStops = false
                                        calculationSuccess = false
                                        secondFocus.wrappedValue = false
                                        results = Results.favorites
                                        viewModel.tripDone = false
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
            LazyVStack(spacing: 0) {

                ForEach(tripManager.tripEvents.sorted(by: { $0.startTime < $1.startTime }), id: \.id) { event in
                        NavigationLink {
                            FullTripView(fullTrip: event)
//                                .environmentObject(savedTripsModel)
                        } label: {
                            Capsule()
                            .fill(.thinMaterial)
                            .padding(4)
                            .frame(height: 80)
                            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                            .overlay(
                                TripElementView(event: event, showTime: showTime)
                                    .padding(.horizontal)
                            )
                    }
                    .foregroundStyle(.primary)
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20))
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
    
    struct CustomTextField: View {
        @ObservedObject var viewModel: ItineraryViewModel
        @Binding var text: String
        @Binding var results: Results
        
        var focus: FocusState<Bool>.Binding
        var fieldNumber: Int
        var emptyText: String
        
        var body: some View {
            let textFieldSelected = viewModel.selectedTextField == fieldNumber
            let hasSelection = (fieldNumber == 1 && (viewModel.departureStop != nil || viewModel.departureGeoPosition != nil)) || (fieldNumber == 2 && (viewModel.arrivalStop != nil || viewModel.arrivalGeoPosition != nil))
            ZStack {
                HStack {
                    if hasSelection && !focus.wrappedValue {
                        if fieldNumber == 1 {
                            Image(systemName: viewModel.geoDeparture ? "mappin.and.ellipse.circle" : "figure.wave.circle").font(.title2)
                        } else if fieldNumber == 2 {
                            Image(systemName: viewModel.geoArrival ? "mappin.and.ellipse.circle" : "figure.wave.circle").font(.title2)
                        }
                    } else {
                        Image(systemName: "magnifyingglass").opacity(textFieldSelected ? 1 : 0.2)
                    }
                    TextField(emptyText, text: $text)
                    
                        .autocorrectionDisabled(true)
                        .focused(focus)
                        .onChange(of: text) {
                            if viewModel.selectedTextField == fieldNumber {
                                if hasSelection && !focus.wrappedValue {
                                    results = Results.empty
                                } else if !text.isEmpty {
                                    results = Results.search
                                } else if text.isEmpty {
                                    results = Results.favorites
                                }
                            }
                        }
                }
                .mask {
                    Rectangle()
                        .overlay(alignment: .trailing) {
                            ScrollMask(leading: false, vertical: false, gradientLength: 40)
                        }
                        .padding(.trailing, 20)
                }
                //                .overlay(
                //
                //                )
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 15)
                
//                    RoundedRectangle(cornerRadius: 17)
                Capsule()
                        .stroke(textFieldSelected ? .accent : .gray.opacity(0.3), lineWidth: 2)
                        .shadow(color: textFieldSelected ? Color.customShadows2 : .clear, radius: 2, y: 1.5)
            }
            .frame(height: 40)
        }
    }
    
    struct textFieldOverlay: View {
        @ObservedObject var viewModel: ItineraryViewModel
        @Binding var searchText: String
        @Binding var showCloseStops: Bool
        @Binding var calculationSuccess: Bool
        @Binding var closestStops: [Stop]
        @Binding var results: Results
        
        var focus: FocusState<Bool>.Binding
        
        var textField: Int
        
        @StateObject var locationManager = LocationManager()
        @EnvironmentObject var stopStore: StopStore
        
        var body: some View {
            if searchText.isEmpty && viewModel.selectedTextField == textField {
                Button(action: {
                    if !showCloseStops {
                        results = Results.closeStops
                        focus.wrappedValue = false
                    } else {
                        results = Results.favorites
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
                            } else { print("error")}
                            locationManager.locationUpdateHandler = nil
                        }
                    }
                }) {
                    Image(systemName: (showCloseStops ? "location.circle.fill" :  "location.circle")).font(.title2)
                }
            } else if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    viewModel.selectedTextField = textField
                    viewModel.tripDone = false
                    if textField == 1 {
                        viewModel.departureStop = nil
                        viewModel.departureGeoPosition = nil
                        viewModel.geoDeparture = false
                    } else if textField == 2 {
                        viewModel.arrivalStop = nil
                        viewModel.arrivalGeoPosition = nil
                        viewModel.geoArrival = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                }
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
                            if viewModel.selectedTextField == 1 {
                                viewModel.departureStop = item.stop
                                viewModel.departureSearchText = item.name
                                viewModel.geoDeparture = false
                                viewModel.selectedTextField = 2
                            } else {
                                viewModel.arrivalStop = item.stop
                                viewModel.arrivalSearchText = item.name
                                viewModel.geoArrival = false
                                viewModel.selectedTextField = 1
                            }
                            results = Results.favorites
                            recentSearchModel.add(name: item.name, isStop: true, stop: item.stop, geoCoordinates: nil)
                        } else {
                            let title = item.name.split(separator: ";")
                            let coordinates = item.geoCoordinates?.toCLLocationCoordinate2D ?? CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
                            if viewModel.selectedTextField == 1 {
                                viewModel.departureGeoPosition = GeoPosition(name: String(title[0]), coordinate: coordinates)
                                viewModel.geoDeparture = true
                                viewModel.departureSearchText = String(title[0])
                                viewModel.selectedTextField = 2
                            } else if viewModel.selectedTextField == 2 {
                                viewModel.arrivalGeoPosition = GeoPosition(name: String(title[0]), coordinate: coordinates)
                                viewModel.geoArrival = true
                                viewModel.arrivalSearchText = String(title[0])
                                viewModel.selectedTextField = 1
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
            print("Failed to modify the date.")
        }
    }
    
    func timeChange() -> Int {
        let tripEventsSorted = tripManager.tripEvents.sorted(by: { $0.startTime < $1.startTime })
        let firstTime: Date = stringToDate(with: tripEventsSorted.first?.startTime ?? "") ?? Date()
        let lastTime: Date = stringToDate(with: tripEventsSorted.last?.startTime ?? "") ?? Date()
        let timeChange = lastTime.timeIntervalSince(firstTime)/60
        
        return Int(timeChange)
    }
    
    func searchTrips() {
        if ((viewModel.geoDeparture && viewModel.departureGeoPosition != nil) || viewModel.departureStop != nil) && ((viewModel.geoArrival && viewModel.arrivalGeoPosition != nil) || viewModel.arrivalStop != nil) {
            print("searching for trips")
            results = Results.loading
            tripManager.tripEvents.removeAll()
            tripManager.selectTrip(with: viewModel.departureStop, with: viewModel.departureGeoPosition, with: viewModel.geoDeparture, with: viewModel.arrivalStop, with: viewModel.arrivalGeoPosition, with: viewModel.geoArrival, with: viewModel.selectedTime, with: viewModel.isArrivalTime)
            viewModel.tripDone = true
            firstIsFocused = false
            secondIsFocused = false
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
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .frame(height: height)
                                .shadow(color: Color.customShadows, radius: 1, y: 0.8)
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
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .frame(height: height)
                                .shadow(color: Color.customShadows, radius: 1, y: 0.8)
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
                                        RoundedRectangle(cornerRadius: 30)
                                            .fill(.thinMaterial)
                                            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
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
                                    .onAppear(perform: {
                                        print(trip.startCoordinates)
                                    })
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
                Capsule()
                    .frame(height: 45)
                    .foregroundStyle(.thinMaterial)
                    .shadow(color: Color.customShadows, radius: 1.5, y: 1)
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
                Capsule()
                    .frame(height: 45)
                    .foregroundStyle(.thinMaterial)
                    .shadow(color: Color.customShadows, radius: 1.5, y: 1)
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
        @StateObject var savedTripsModel = SavedTripsModel()
        @StateObject var regularTripsModel = RegularTripsModel()
        @StateObject var appRequirementsClass = AppRequirementsClass()
            @StateObject var itineraryViewModel = ItineraryViewModel()
        @State var boolTest: Bool = true
        
        return
            NavigationStack {
                TripView(tripManager: TripManager())
                    .environmentObject(itineraryViewModel)
                    .environmentObject(stopStore)
                    .environmentObject(favoritesViewModel)
                    .environmentObject(savedTripsModel)
                    .environmentObject(regularTripsModel)
                    .environmentObject(appRequirementsClass)
            }
    }
}

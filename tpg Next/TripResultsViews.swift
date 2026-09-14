//
//  TripResultsViews.swift
//  tpg Next
//
//  Listes affichées sous les champs de l'itinéraire : favoris, recherche, arrêts proches, résultats.
//

import SwiftUI
import MapKit
import tpgNextFunc

extension TripView {
    struct ResultsFavoritesView: View {
        @Environment(StopStore.self) var stopStore
        @Environment(FavoritesViewModel.self) var favoritesViewModel
        @Bindable var viewModel: ItineraryViewModel
        @Environment(RecentSearch.self) var recentSearchModel
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
                                if viewModel.selectedField == .departure {
                                    viewModel.departure.select(.stop(stop))
                                    viewModel.selectedField = .arrival
                                    results = Results.favorites
                                    viewModel.tripDone = false
                                } else if viewModel.selectedField == .arrival {
                                    viewModel.arrival.select(.stop(stop))
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
        @Environment(StopStore.self) var stopStore
        @Bindable var viewModel: ItineraryViewModel
        var locationViewModel: LocationSearchViewModel
        @Environment(RecentSearch.self) var recentSearchModel
        @Binding var results: Results
        @State var locationManager = LocationManager()
        
        
        @State private var showMap = false
        @State private var resultCoordinates: CLLocationCoordinate2D?
        @State private var resultTitle: String?
        @State private var resultDetail: searchResultItem?
        @State private var locationSearch = false
        @State private var stopResults: [Stop] = []
        
        var focusField: FocusState<TripField?>.Binding
        
        var body: some View {
                LazyVStack {
                    Picker("", selection: $locationSearch) {
                        Text("Arrêts").tag(false)
                        Text("Lieux").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    // Sur le sélecteur : le seul enfant toujours présent de la LazyVStack.
                    .searchingStops(viewModel.stopQuery, results: $stopResults)
                    if !locationSearch {
                        if !stopResults.isEmpty {
                            HStack {
                                Text("Arrêts")
                                    .font(.title3).bold()
                                Spacer()
                            }
                            .padding(.horizontal, 30)
                        }
                        ForEach(stopResults) { stop in
                            Button(action: {
                                withAnimation {
                                    if viewModel.selectedField == .departure {
                                        viewModel.departure.select(.stop(stop))
                                        viewModel.selectedField = .arrival
                                    } else {
                                        viewModel.arrival.select(.stop(stop))
                                        viewModel.selectedField = .departure
                                    }
                                    results = Results.favorites
                                    viewModel.tripDone = false
                                    focusField.wrappedValue = nil
                                    recentSearchModel.add(name: stop.name, isStop: true, stop: stop, geoCoordinates: nil)
                                    viewModel.stopQuery = ""
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
                                                viewModel.departure.select(.place(GeoPosition(name: result.title, coordinate: coordinate)))
                                                viewModel.selectedField = .arrival
                                            } else if viewModel.selectedField == .arrival {
                                                viewModel.arrival.select(.place(GeoPosition(name: result.title, coordinate: coordinate)))
                                                viewModel.selectedField = .departure
                                            }
                                            results = Results.favorites
                                            viewModel.tripDone = false
                                            focusField.wrappedValue = nil
                                            viewModel.stopQuery = ""
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
        @Environment(StopStore.self) var stopStore
        @Bindable var viewModel: ItineraryViewModel
        
        @Binding var calculationSuccess: Bool
        @Binding var showCloseStops: Bool
        @Binding var closestStops: [Stop]
        @Binding var results: Results
                
        @State var locationManager = LocationManager()
        
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
                                            viewModel.departure.select(.place(GeoPosition(name: "Ma position", coordinate: coordinate)))
                                            results = Results.favorites
                                            showCloseStops = false
                                            calculationSuccess = false
                                            viewModel.selectedField = .arrival
                                            viewModel.tripDone = false
                                        } else if viewModel.selectedField == .arrival {
                                            // Execute only when selectedTextField is 2
                                            viewModel.arrival.select(.place(GeoPosition(name: "Ma position", coordinate: coordinate)))
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
                                        HStack {
                                            Text("Utiliser la position actuelle")
                                            Spacer()
                                            Image(systemName: "location.circle").font(.title2).foregroundStyle(.accent)
                                        }
                                            .padding(.horizontal, 20)
                                            .basicElementBackground(minHeight: 45)
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
                                    withAnimation {
                                        if viewModel.selectedField == .departure {
                                            viewModel.departure.select(.stop(stop))
                                            viewModel.selectedField = .arrival
                                            showCloseStops = false
                                            calculationSuccess = false
                                            results = Results.favorites
                                            viewModel.tripDone = false
                                        } else if viewModel.selectedField == .arrival {
                                            viewModel.arrival.select(.stop(stop))
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
        @Bindable var viewModel: ItineraryViewModel
        
        var tripManager: TripManager
        @Environment(SavedTripsModel.self) var savedTripsModel
        @Binding var showTime: Bool
        
        let adjustTime: (Int) -> Void
        let timeChange: () -> Int
        let searchTrips: () -> Void
        
        var body: some View {
            LazyVStack(spacing: 5) {

                ForEach(tripManager.tripEvents.sortedByStart(), id: \.id) { event in
                        NavigationLink {
                            FullTripView(fullTrip: event)
//                                .environment(savedTripsModel)
                        } label: {
                            TripElementView(event: event, showTime: showTime)
                                .padding(.horizontal, 20)
                                // La capsule prend la largeur disponible, pas celle du contenu : plus
                                // large que l'écran, il la faisait déborder sur les côtés.
                                .frame(maxWidth: .infinity)
                                .basicElementBackground(minHeight: 72)
                                .padding(4)
                            
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
        @Bindable var viewModel: ItineraryViewModel
        @Binding var searchText: String
        @Binding var showCloseStops: Bool
        @Binding var calculationSuccess: Bool
        @Binding var closestStops: [Stop]
        @Binding var results: Results
        
        var focusField: FocusState<TripField?>.Binding
        
        
        var field: TripField
        
        @State var locationManager = LocationManager()
        @Environment(StopStore.self) var stopStore
        
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
                            viewModel.departure.endpoint = nil
                        } else if field == .arrival {
                            viewModel.arrival.endpoint = nil
                        }
                    }
                }) {
                    Image(systemName: "xmark").font(.title2)
                }
            }
        }
    }
    struct TripPointField: View {
        @Bindable var viewModel: ItineraryViewModel
        @Binding var results: Results
        var focusField: FocusState<TripField?>.Binding

        var field: TripField
        
        var body: some View {
            let selected = viewModel.selectedField == field
            let hasSelection = (field == .departure && viewModel.departure.endpoint != nil) || (field == .arrival && viewModel.arrival.endpoint != nil)
            ZStack {
                HStack {
                    HStack {
                        if hasSelection && focusField.wrappedValue != field {
                            if field == .departure {
                                Image(systemName: viewModel.departure.endpoint?.isPlace == true ? "mappin.and.ellipse.circle" : "figure.wave.circle")
                                    .font(.title2)
                                    .foregroundStyle(selected ? .accent : .primary)
                            } else if field == .arrival {
                                Image(systemName: viewModel.arrival.endpoint?.isPlace == true ? "mappin.and.ellipse.circle" : "figure.wave.circle")
                                    .font(.title2)
                                    .foregroundStyle(selected ? .accent : .primary)
                            }
                        } else {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(selected ? .accent : .primary.opacity(0.2))
                        }
                        if field == .arrival {
                            TextField("Destination", text: $viewModel.arrival.text)
                            //                            .frame(height: size)
                                .focused(focusField, equals: .arrival)
                            //                            .opacity(focusField.wrappedValue == .arrival ? 1:0)
                                .onChange(of: viewModel.arrival.text) {
                                    if selected {
                                        if hasSelection && focusField.wrappedValue == nil {
                                            results = Results.empty
                                        } else if !viewModel.arrival.text.isEmpty {
                                            results = Results.search
                                        } else if viewModel.arrival.text.isEmpty {
                                            results = Results.favorites
                                        }
                                    }
                                }
                        } else {
                            TextField("Origine", text: $viewModel.departure.text)
                            //                            .frame(height: size)
                                .focused(focusField, equals: .departure)
                            //                            .opacity(focusField.wrappedValue == .departure ? 1:0)
                                .onChange(of: viewModel.departure.text) {
                                    if selected {
                                        if hasSelection && focusField.wrappedValue == nil {
                                            results = Results.empty
                                        } else if !viewModel.departure.text.isEmpty {
                                            results = Results.search
                                        } else if viewModel.departure.text.isEmpty {
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
                        
                        viewModel.arrival.text = viewModel.arrival.endpoint?.name ?? ""
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
        var recentSearchModel: RecentSearch
        @Bindable var viewModel: ItineraryViewModel
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
                                viewModel.departure = TripPoint(endpoint: item.stop.map(TripEndpoint.stop), text: item.name)
                                viewModel.selectedField = .arrival
                            } else {
                                viewModel.arrival = TripPoint(endpoint: item.stop.map(TripEndpoint.stop), text: item.name)
                                viewModel.selectedField = .departure
                            }
                            results = Results.favorites
                            recentSearchModel.add(name: item.name, isStop: true, stop: item.stop, geoCoordinates: nil)
                        } else {
                            let title = item.name.split(separator: ";")
                            let coordinates = item.geoCoordinates?.toCLLocationCoordinate2D ?? CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
                            if viewModel.selectedField == .departure {
                                viewModel.departure.select(.place(GeoPosition(name: String(title[0]), coordinate: coordinates)))
                                viewModel.selectedField = .arrival
                            } else if viewModel.selectedField == .arrival {
                                viewModel.arrival.select(.place(GeoPosition(name: String(title[0]), coordinate: coordinates)))
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
}

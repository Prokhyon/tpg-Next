//
//  ItineraryViewModel.swift
//  tpg Next
//
//  État de l'écran d'itinéraire : départ, arrivée, heure et recherche de lieux.
//

import SwiftUI
import MapKit
import tpgNextFunc

enum TripField: Hashable {
        case departure
        case arrival
    }

/// Le départ ou l'arrivée d'un itinéraire : l'extrémité choisie et le texte de son champ.
struct TripPoint {
    var endpoint: TripEndpoint?
    var text = ""

    /// Choisit `endpoint` et affiche son nom dans le champ.
    mutating func select(_ endpoint: TripEndpoint) {
        self.endpoint = endpoint
        text = endpoint.name
    }
}

@Observable
class ItineraryViewModel {
    /// Texte cherché dans les arrêts pour le champ actif (départ ou arrivée).
    var stopQuery = ""

    var departure = TripPoint()
    var arrival = TripPoint()
    var selectedTime = Date()
    var isArrivalTime = false

    var tripDone = false
    var quickTrip = false

    var selectedTextField: Int = 1

    var selectedField: TripField? = .departure

    /// Départ et arrivée renseignés : la recherche d'itinéraire peut être lancée.
    var canSearch: Bool { departure.endpoint != nil && arrival.endpoint != nil }

    /// Échange départ et arrivée ; les champs affichent le nom de leur nouvelle extrémité.
    func invertStops() {
        (departure.endpoint, arrival.endpoint) = (arrival.endpoint, departure.endpoint)
        departure.text = departure.endpoint?.name ?? ""
        arrival.text = arrival.endpoint?.name ?? ""
    }

    func resetModel() {
        departure = TripPoint()
        arrival = TripPoint()
        selectedTime = Date()
        isArrivalTime = false
    }

    func outerTrip(tab: NavigationModel, isDeparture: Bool, stop: Stop, isQuickTrip: Bool) {
        // L'extrémité remplace aussi un lieu choisi avant (« Ma position ») : l'ancien trio
        // arrêt / lieu / indicateur devait être remis à zéro à la main.
        if isDeparture {
            departure.select(.stop(stop))
            arrival = TripPoint()
            selectedTextField = 2
        } else {
            departure = TripPoint()
            arrival.select(.stop(stop))
            selectedTextField = 1
        }
        tripDone = false
        quickTrip = isQuickTrip
        tab.popToRoot(.trip)
        tab.selectedTab = .trip
    }
}

@Observable
class LocationSearchViewModel: NSObject, MKLocalSearchCompleterDelegate {
    var searchQuery: String = "" {
        didSet {
            updateSearchResults()
        }
    }
    var searchResults = [MKLocalSearchCompletion]()
    
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

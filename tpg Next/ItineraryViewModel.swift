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

    var departure = TripPoint() {
        didSet { if departure.endpoint != oldValue.endpoint { avoidedLines = [] } }
    }
    var arrival = TripPoint() {
        didSet { if arrival.endpoint != oldValue.endpoint { avoidedLines = [] } }
    }
    /// Les lignes que la recherche évite, choisies dans les résultats. Elles ne valent que
    /// pour ce départ et cette arrivée.
    var avoidedLines: [AvoidedLine] = []
    var selectedTime = Date()
    var isArrivalTime = false

    var tripDone = false
    var quickTrip = false
    /// Une recherche demandée depuis un autre écran (raccourci, « Y aller », itinéraire récent) :
    /// l'onglet Itinéraire la lance en s'affichant.
    var pendingSearch = false

    var selectedTextField: Int = 1

    var selectedField: TripField? = .departure

    /// Les adresses de « Ma position » en cours de recherche, par champ.
    @ObservationIgnored private var addressLookups: [TripField: Task<Void, Never>] = [:]

    /// Choisit la position actuelle (« Ma position ») et cherche aussitôt son adresse, qui
    /// nommera l'itinéraire.
    func selectCurrentPosition(_ coordinate: CLLocationCoordinate2D, for field: TripField) {
        let place = GeoPosition(name: "Ma position", coordinate: coordinate)
        let point: ReferenceWritableKeyPath<ItineraryViewModel, TripPoint> = field == .departure ? \.departure : \.arrival
        self[keyPath: point].select(.place(place))
        addressLookups[field]?.cancel()
        addressLookups[field] = Task { @MainActor [weak self] in
            guard let address = await PlaceAddress.lookUp(coordinate), !Task.isCancelled, let self,
                  // Un autre lieu a pu être choisi entre-temps.
                  self[keyPath: point].endpoint?.place == place else { return }
            var located = place
            located.address = address
            self[keyPath: point].endpoint = .place(located)
        }
    }

    /// Attend les adresses en cours, 2 secondes au plus : sans réponse, l'itinéraire garde
    /// « Ma position ».
    func waitForAddresses() async {
        let lookups = Array(addressLookups.values)
        guard !lookups.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for lookup in lookups { await lookup.value }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(2))
            }
            await group.next()
            group.cancelAll()
        }
    }

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

    /// Cherche les itinéraires de maintenant dans l'onglet Itinéraire, et y bascule. Sans
    /// départ, on part de la position actuelle (comme « Trajet rapide »).
    func searchNow(from origin: TripEndpoint?, to destination: TripEndpoint, tab: NavigationModel) {
        if let origin {
            departure.select(origin)
            quickTrip = false
            pendingSearch = true
        } else {
            departure = TripPoint()
            quickTrip = true
        }
        arrival.select(destination)
        selectedTime = Date()
        isArrivalTime = false
        selectedField = nil
        tripDone = false
        tab.popToRoot(.trip)
        tab.selectedTab = .trip
    }

    /// Un itinéraire qui part de `origin` : l'arrivée reste à choisir dans l'onglet Itinéraire.
    func start(from origin: TripEndpoint, tab: NavigationModel) {
        departure.select(origin)
        arrival = TripPoint()
        selectedTextField = 2
        tripDone = false
        quickTrip = false
        tab.popToRoot(.trip)
        tab.selectedTab = .trip
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

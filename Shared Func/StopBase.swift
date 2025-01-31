//
//  StopBase.swift
//  TPG4
//
//  Created by Loris Thomas on 20.06.2024.
//

import SwiftUI
import Foundation
import Combine
import CoreLocation
import ClusterMap

struct Stopv1: Codable, Identifiable, Hashable, Equatable {
    
    let arretcodelong: String
    let nomarret: String
    let commune: String
    let pays: String
    var codedidoc: Int
    let coordonnees: Coordonnees
    let actif: String
    
    var id: Int { codedidoc }
    
    struct Coordonnees: Codable, Hashable {
        let lon: Double
        let lat: Double
    }
}

struct LocationStop: CoordinateIdentifiable, Identifiable, Hashable, Sendable {
    var coordinate: CLLocationCoordinate2D
    var id: String
    var name: String
    
}

struct Stop: Codable, Identifiable, Hashable, Equatable {
    let name: String
    let sloid: String
    let codedidoc: String
    let country: String
    let canton: String
    let meansOfTransport: String
    let wgs84Coordinates: Coordinates
    
    var id: String { codedidoc }
    
}

struct Coordinates: Codable, Hashable {
    let lon: Double
    let lat: Double
}


extension Coordinates {
    var toCLLocationCoordinate2D: CLLocationCoordinate2D {
//        print("lat: \(lat), lon: \(lon)")
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

extension CLLocationCoordinate2D {
    var toCoordinates: Coordinates {
        return Coordinates(lon: self.longitude, lat: self.latitude)
    }
}

struct ShortStop: Codable, Identifiable, Hashable, Equatable {
    let name: String
    let codedidoc: String
    
    var id: String { codedidoc }
}

struct GeoPosition: Hashable {
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct searchResultItem: Identifiable {
    let title: String
    let coordinates: CLLocationCoordinate2D
    
    var id = UUID()
}

extension String {
    // Function to normalize the string by removing accents and hyphens
    func normalized() -> String {
        let normalizedString = self.folding(options: .diacriticInsensitive, locale: .current)
        return normalizedString.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
    }
}

class StopStore: ObservableObject {
    @Published var stops: [Stop] = []
    @Published var searchText: String = ""
    @Published private(set) var filteredStops: [Stop] = []
    @Published var activeStops: [Stop] = []
    @Published var mapStops: [LocationStop] = []
    @Published var location: CLLocation?
    
    private var cancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval = 0.3 // 300ms debounce interval

    init() {
        loadAllStops()
        copyToMapStops()
        setupSearch()
    }

    // MARK: - Data Loading and Initialization

    private func loadAllStops() {
        let stopFiles = ["FullStopsCH", "TrainStopsFR"] // Replace with actual JSON file names

        for file in stopFiles {
            loadStops(from: file)
        }

        filterActiveStops()
    }

    private func loadStops(from fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("Failed to locate \(fileName).json in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            print("Data loaded successfully from \(url).")

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            struct TempStop: Codable {
                let designationOfficial: String?
                let sloid: String?
                let number: String?
                let isoCountryCode: String?
                let cantonName: String?
                let meansOfTransport: String?
                let wgs84East: Double?
                let wgs84North: Double?
            }

            let tempStops = try decoder.decode([TempStop].self, from: data)
            print("TempStops from \(fileName) decoded successfully.")

            let filteredStops = tempStops.compactMap { tempStop -> Stop? in
                guard let name = tempStop.designationOfficial,
                      let sloid = tempStop.sloid,
                      let codedidoc = tempStop.number,
                      let country = tempStop.isoCountryCode,
                      let canton = tempStop.cantonName,
                      let meansOfTransport = tempStop.meansOfTransport,
                      let wgs84East = tempStop.wgs84East,
                      let wgs84North = tempStop.wgs84North else {
                    return nil
                }
                return Stop(name: name, sloid: sloid, codedidoc: codedidoc, country: country, canton: canton, meansOfTransport: meansOfTransport, wgs84Coordinates: Coordinates(lon: wgs84East, lat: wgs84North))
            }

            print("Filtered Stops from \(fileName): \(filteredStops.count)")
            self.stops.append(contentsOf: filteredStops)
        } catch {
            print("Error loading or decoding \(fileName).json:", error.localizedDescription)
        }
    }

    private func filterActiveStops() {
        var uniqueStops: [String: Stop] = [:]
        for stop in stops {
            uniqueStops[stop.codedidoc] = stop
        }
        activeStops = Array(uniqueStops.values)
    }

    private func copyToMapStops() {
        mapStops = activeStops.map { stop in
            LocationStop(coordinate: stop.wgs84Coordinates.toCLLocationCoordinate2D, id: stop.id, name: stop.name)
        }
        print("mapStops copy done")
    }

    // MARK: - Search Logic with Combine Debounce

    private func setupSearch() {
        $searchText
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateSearchResults()
                }
            }
            .store(in: &cancellables)
    }

    @MainActor private func updateSearchResults() {
        guard !searchText.isEmpty else {
            filteredStops = []
            return
        }

        let normalizedSearchText = searchText.normalized().lowercased()
        
        let matchingStops = activeStops.filter { stop in
            stop.name.normalized().lowercased().contains(normalizedSearchText)
        }

        if let currentLocation = location {
            filteredStops = matchingStops.sorted {
                CLLocation(latitude: $0.wgs84Coordinates.lat, longitude: $0.wgs84Coordinates.lon)
                    .distance(from: currentLocation) <
                CLLocation(latitude: $1.wgs84Coordinates.lat, longitude: $1.wgs84Coordinates.lon)
                    .distance(from: currentLocation)
            }
        } else {
            filteredStops = matchingStops.sorted { $0.name < $1.name }
        }
    }

    // MARK: - Utility Function

    func findStop(id: String) -> Stop? {
        activeStops.first { $0.codedidoc == id || $0.sloid == id }
    }
}


class FavoritesViewModel: ObservableObject {
    @EnvironmentObject var stopStore: StopStore
    @Published var favoriteStops: [Stop] {
        didSet {
            saveFavorites()
        }
    }
    
    private let userDefaultsKey = "favoriteStops"
    
    init() {
        self.favoriteStops = []
        loadFavorites()
    }

    func addFavorite(_ stop: Stop) {
        if !favoriteStops.contains(stop) {
            favoriteStops.append(stop)
            saveFavorites()
        }
    }
    
    func removeFavoriteStop(_ stop: Stop) {
        favoriteStops.removeAll(where: { $0.codedidoc == stop.codedidoc })
        saveFavorites()
    }
    
    func removeFavoriteIndex(atOffsets offsets: IndexSet) {
        favoriteStops.remove(atOffsets: offsets)
        saveFavorites()
    }
    
    func isFavorite(_ stop: Stop) -> Bool {
        return favoriteStops.contains(stop)
    }
    
    func isFavoriteID(_ id: String) -> Bool {
        return favoriteStops.contains(where: { $0.codedidoc == id || $0.sloid == id })
    }
    
    func moveFavorite(fromOffsets source: IndexSet, toOffset destination: Int) {
        favoriteStops.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteStops)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Error encoding favorite stops: \(error)")
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            do {
                let stops = try JSONDecoder().decode([Stop].self, from: data)
                self.favoriteStops = stops
                print("favorites loaded")
            } catch {
                print("Error decoding favorite stops: \(error)")
            }
        }
    }
}

struct splitStopName: View {
    var stopName: String
    
    var body: some View {
        HStack {
            let splitStopName = splitString(stopName, separator: ",")
            if splitStopName.1.isEmpty {
                Text(splitStopName.0)
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 10)
                Spacer()
            } else {
                VStack {
                    HStack {
                        Text(splitStopName.0)
                            .font(.title2)
                        Spacer()
                    }
                    HStack {
                        Text(splitStopName.1)
                            .font(.largeTitle)
                            .bold()
                        Spacer()
                    }
                }
            }
        }
    }
}

func codedidocHarmonizer(code: String) -> String {
    if code.hasPrefix("ch") {
        let codedidoc = code.dropFirst(11).dropLast(9)
        return "85\(codedidoc)"
    } else {
        return code
    }
}

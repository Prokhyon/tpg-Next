//
//  StopBase.swift
//  TPG4
//
//  Created by Loris Thomas on 20.06.2024.
//

import SwiftUI
import Foundation
import Combine

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

struct Stop: Codable, Identifiable, Hashable, Equatable {
    let name: String
    let sloid: String
    let codedidoc: String
    let country: String
    let canton: String
    let meansOfTransport: String
    let lv95Coordinates: Coordinates
    let wgs84Coordinates: Coordinates
    
    var id: String { codedidoc }
    
    struct Coordinates: Codable, Hashable {
        let lon: Double
        let lat: Double
    }
}

struct ShortStop: Codable, Identifiable, Hashable, Equatable {
    let name: String
    let codedidoc: String
    
    var id: String { codedidoc }
}


class StopStore: ObservableObject {
    @Published var stops: [Stop] = []
    @Published var searchText: String = ""
    @Published var activeStops: [Stop] = []

    var filteredStops: [Stop] {
        let stops = searchText.isEmpty ? activeStops : activeStops.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return stops.sorted { $0.name < $1.name }
    }

    init() {
        loadAllStops()
    }

    func loadAllStops() {
        let stopFiles = ["FullStopsTPG", "TrainStopsFR", "TrainStopsCH"] // Replace with the actual names of your JSON files without the .json extension

        for file in stopFiles {
            loadStops(from: file)
        }

        filterActiveStops()
    }

    func loadStops(from fileName: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("Failed to locate \(fileName).json in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            print("Data loaded successfully from \(url).")

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            // Temporary struct for initial decoding
            struct TempStop: Codable {
                let designationOfficial: String?
                let sloid: String?
                let number: String?
                let isoCountryCode: String?
                let cantonName: String?
                let meansOfTransport: String?
                let lv95East: Double?
                let lv95North: Double?
                let wgs84East: Double?
                let wgs84North: Double?
            }

            let tempStops = try decoder.decode([TempStop].self, from: data)
            print("TempStops from \(fileName) decoded successfully.")

            // Filter out unwanted stops
            let filteredStops = tempStops.compactMap { tempStop -> Stop? in
                guard let name = tempStop.designationOfficial,
                let sloid = tempStop.sloid,
                let codedidoc = tempStop.number,
                let country = tempStop.isoCountryCode,
                let canton = tempStop.cantonName,
                let meansOfTransport = tempStop.meansOfTransport,
                let lv95East = tempStop.lv95East,
                let lv95North = tempStop.lv95North,
                let wgs84East = tempStop.wgs84East,
                let wgs84North = tempStop.wgs84North else {
                    return nil
                }
                return Stop(name: name, sloid: sloid, codedidoc: codedidoc, country: country, canton: canton, meansOfTransport: meansOfTransport, lv95Coordinates: Stop.Coordinates(lon: lv95East, lat: lv95North), wgs84Coordinates: Stop.Coordinates(lon: wgs84East, lat: wgs84North))
            }

            print("Filtered Stops from \(fileName): \(filteredStops.count)")

            self.stops.append(contentsOf: filteredStops)
        } catch DecodingError.dataCorrupted(let context) {
            print("Data corrupted in \(fileName): \(context.debugDescription)")
        } catch DecodingError.keyNotFound(let key, let context) {
            print("Key '\(key.stringValue)' not found in \(fileName): \(context.debugDescription)")
        } catch DecodingError.typeMismatch(let type, let context) {
            print("Type mismatch for type \(type) in \(fileName): \(context.debugDescription)")
        } catch DecodingError.valueNotFound(let type, let context) {
            print("Value not found for type \(type) in \(fileName): \(context.debugDescription)")
        } catch {
            print("Error loading or decoding \(fileName).json:", error.localizedDescription)
        }
    }

    private func filterActiveStops() {
        // Filter stops based on `actif` being "y" and remove duplicates based on `codedidoc`
                        var uniqueStops: [String: Stop] = [:]
                for stop in stops {
                        uniqueStops[stop.codedidoc] = stop
                }
                // Assign the filtered and unique stops to `activeStops`
                        activeStops = Array(uniqueStops.values)
    }
}

class FavoritesViewModel: ObservableObject {
    @EnvironmentObject var stopStore: StopStore
    @Published var favoriteStops: [ShortStop] {
        didSet {
            saveFavorites()
        }
    }
    
    private let userDefaultsKey = "favoriteStops"
    
    init(/*stopStore: StopStore*/) {
//        self.stopStore = stopStore
        self.favoriteStops = []
        loadFavorites()
    }

    func addFavorite(_ stop: ShortStop) {
        if !favoriteStops.contains(stop) {
            favoriteStops.append(stop)
            saveFavorites()
        }
    }
    
    func removeFavoriteStop(_ stop: ShortStop) {
        favoriteStops.removeAll(where: { $0 == stop })
        saveFavorites()
    }
    
    func removeFavoriteIndex(atOffsets offsets: IndexSet) {
        favoriteStops.remove(atOffsets: offsets)
        saveFavorites()
    }
    
    func isFavorite(_ stop: ShortStop) -> Bool {
        return favoriteStops.contains(stop)
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
                let stops = try JSONDecoder().decode([ShortStop].self, from: data)
                self.favoriteStops = stops
            } catch {
                print("Error decoding favorite stops: \(error)")
            }
        }
    }
}

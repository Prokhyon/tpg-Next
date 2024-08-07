//
//  StopBase.swift
//  TPG4
//
//  Created by Loris Thomas on 20.06.2024.
//

import SwiftUI
import Foundation
import Combine

struct Stop: Codable, Identifiable, Hashable, Equatable {
    
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



class StopStore: ObservableObject {
    @Published var stops: [Stop] = []
    @Published var searchText: String = ""
    @Published var activeStops: [Stop] = []

    var filteredStops: [Stop] {
        let stops = searchText.isEmpty ? activeStops : activeStops.filter { $0.nomarret.localizedCaseInsensitiveContains(searchText) }
        return stops.sorted { $0.nomarret < $1.nomarret }
    }

    init() {
        loadAllStops()
    }

    func loadAllStops() {
        let stopFiles = ["arrets-tpg", "GETrainStops"] // Replace with the actual names of your JSON files without the .json extension

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
                let arretcodelong: String?
                let nomarret: String?
                let commune: String?
                let pays: String?
                let codedidoc: Int?
                let coordonnees: Stop.Coordonnees?
                let actif: String?
            }

            let tempStops = try decoder.decode([TempStop].self, from: data)
            print("TempStops from \(fileName) decoded successfully.")

            // Filter out unwanted stops
            let filteredStops = tempStops.compactMap { tempStop -> Stop? in
                guard let arretcodelong = tempStop.arretcodelong,
                      let nomarret = tempStop.nomarret,
                      let commune = tempStop.commune,
                      let pays = tempStop.pays,
                      let codedidoc = tempStop.codedidoc,
                      let coordonnees = tempStop.coordonnees,
                      let actif = tempStop.actif, actif == "Y" else {
                    return nil
                }
                return Stop(arretcodelong: arretcodelong, nomarret: nomarret, commune: commune, pays: pays, codedidoc: codedidoc, coordonnees: coordonnees, actif: actif)
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
                        var uniqueStops: [Int: Stop] = [:]
                for stop in stops {
                    if stop.actif == "Y" {
                        uniqueStops[stop.codedidoc] = stop
                    }
                }
                // Assign the filtered and unique stops to `activeStops`
                        activeStops = Array(uniqueStops.values)
    }
}

class FavoritesViewModel: ObservableObject {
    @Published private var stopStore = StopStore()
    @Published var favoriteStops: [Int] {
        didSet {
            saveFavorites()
            id2stop(favoriteStops: favoriteStops, stopsArray: stopStore.activeStops)
        }
    }
    @Published var fullFavorites: [Stop] = [] 
    private let userDefaultsKey = "favoriteStops"
    
    init(stopStore: StopStore) {
            self.stopStore = stopStore
            self.favoriteStops = UserDefaults.standard.array(forKey: userDefaultsKey) as? [Int] ?? []
            id2stop(favoriteStops: favoriteStops, stopsArray: stopStore.activeStops)
        }
    
    func id2stop(favoriteStops: [Int], stopsArray: [Stop]) {
        fullFavorites = []
        for id in favoriteStops {
            if let stop = stopsArray.first(where: { $0.codedidoc == id }) {
                fullFavorites.append(stop)
            }
        }
    }
    func addFavorite(_ stop: Stop) {
        if !favoriteStops.contains(stop.codedidoc) {
            favoriteStops.append(stop.codedidoc)
            saveFavorites()
            id2stop(favoriteStops: favoriteStops, stopsArray: stopStore.activeStops)
        }
    }
    func removeFavoriteStop(_ stop: Stop) {
        favoriteStops.removeAll(where: { $0 == stop.codedidoc })
        saveFavorites()
        id2stop(favoriteStops: favoriteStops, stopsArray: stopStore.activeStops)
    }
    
    func removeFavoriteIndex(atOffsets offsets: IndexSet) {
            fullFavorites.remove(atOffsets: offsets)
        }
    
    func isFavorite(_ stop: Stop) -> Bool {
            return favoriteStops.contains(stop.codedidoc)
        }

    func moveFavorite(fromOffsets source: IndexSet, toOffset destination: Int) {
        favoriteStops.move(fromOffsets: source, toOffset: destination)
        id2stop(favoriteStops: favoriteStops, stopsArray: stopStore.activeStops)
        saveFavorites()
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(favoriteStops, forKey: userDefaultsKey)
    }
    
    
}

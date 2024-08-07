//
//  StopBase.swift
//  TPG4
//
//  Created by Loris Thomas on 20.06.2024.
//

import SwiftUI
import Foundation
import Combine

struct Stop: Codable, Identifiable, Hashable {
    
    let arretcodelong: String
    let nomarret: String
    let commune: String
    let pays: String
    var codedidoc: Int  // Make codedidoc optional to handle null values
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
            
            // Convert to array and sort alphabetically by `nomarret`
            return stops.sorted { $0.nomarret < $1.nomarret }
        }
    init() {
        loadStops()
        filterActiveStops()
    }
    
    func loadStops() {
        guard let url = Bundle.main.url(forResource: "stopsGE", withExtension: "json") else {
            print("Failed to locate stops.json in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            print("Data loaded successfully.")
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase  // Adjust as needed
            
            // Customize decoding to handle null values
           // decoder.decodeNil(forKey: .coordonnees)
            
            let stops = try decoder.decode([Stop].self, from: data)
            print("Stops decoded successfully.")
            
            self.stops = stops
        } catch {
            print("Error loading or decoding stops.json:", error.localizedDescription)
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
    func removeFavorite(_ stop: Stop) {
        favoriteStops.removeAll(where: { $0 == stop.codedidoc })
        saveFavorites()
        id2stop(favoriteStops: favoriteStops, stopsArray: stopStore.activeStops)
    }
    
    func isFavorite(_ stop: Stop) -> Bool {
            return favoriteStops.contains(stop.codedidoc)
        }

    func moveFavorite() {
        //A faire, en mode échange de place
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(favoriteStops, forKey: userDefaultsKey)
    }
    
    
}

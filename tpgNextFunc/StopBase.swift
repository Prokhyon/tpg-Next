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
import WatchConnectivity
#if canImport(WidgetKit)
import WidgetKit
#endif
//import ClusterMap

//Makes CLLocationCoordinate2D equatable
extension CLLocationCoordinate2D {
    /// Custom equality check
    func isEqual(to other: CLLocationCoordinate2D) -> Bool {
        return self.latitude == other.latitude && self.longitude == other.longitude
    }

    /// Custom hash value computation
    func hashValue() -> Int {
        var hasher = Hasher()
        hasher.combine(latitude)
        hasher.combine(longitude)
        return hasher.finalize()
    }
}

//public struct Stopv1: Codable, Identifiable, Hashable, Equatable {
//    
//    let arretcodelong: String
//    let nomarret: String
//    let commune: String
//    let pays: String
//    var codedidoc: Int
//    let coordonnees: Coordonnees
//    let actif: String
//    
//    public var id: Int { codedidoc }
//    
//    struct Coordonnees: Codable, Hashable {
//        let lon: Double
//        let lat: Double
//    }
//}

public struct LocationStop: CoordinateIdentifiable, Identifiable, Hashable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    public var id: String
    public var name: String

    public init(coordinate: CLLocationCoordinate2D, id: String, name: String) {
        self.coordinate = coordinate
        self.id = id
        self.name = name
    }

    // Custom equality implementation
    public static func == (lhs: LocationStop, rhs: LocationStop) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    // Custom hashing implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}

//Code copied from ClusterMap Framework in order to keep LocationStop in this framework without using ClusterMap
protocol CoordinateIdentifiable {
    /// The geographical coordinate of the object.
    var coordinate: CLLocationCoordinate2D { get set }

    /// A Boolean value that determines whether the object should be included in clustering operations.
    ///
    /// The default value is `true`.
    var shouldCluster: Bool { get }
}

extension CoordinateIdentifiable {
    var shouldCluster: Bool { true }
}
//End of copied code


public struct Stop: Codable, Identifiable, Hashable, Equatable {
    public let name: String
    public let sloid: String
    public let codedidoc: String
    public let country: String
    public let canton: String
    public let meansOfTransport: String
    public let wgs84Coordinates: Coordinates

    public var id: String { sloid }

    public init(name: String, sloid: String, codedidoc: String, country: String, canton: String, meansOfTransport: String, wgs84Coordinates: Coordinates) {
        self.name = name
        self.sloid = sloid
        self.codedidoc = codedidoc
        self.country = country
        self.canton = canton
        self.meansOfTransport = meansOfTransport
        self.wgs84Coordinates = wgs84Coordinates
    }
}

public struct Coordinates: Codable, Hashable {
    public let lon: Double
    public let lat: Double
    
    public init(lon: Double, lat: Double) {
            self.lon = lon
            self.lat = lat
        }
}


extension Coordinates {
    public var toCLLocationCoordinate2D: CLLocationCoordinate2D {
//        print("lat: \(lat), lon: \(lon)")
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

extension CLLocationCoordinate2D {
    public var toCoordinates: Coordinates {
        return Coordinates(lon: self.longitude, lat: self.latitude)
    }
}

public struct ShortStop: Codable, Identifiable, Hashable, Equatable {
    public let name: String
    public let sloid: String

    public var id: String { sloid }

    public init(name: String, sloid: String) {
            self.name = name
            self.sloid = sloid
//            self.id = id
        }
}

public struct GeoPosition: Hashable {
    public let name: String
    public let coordinate: CLLocationCoordinate2D

    public init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.coordinate = coordinate
    }

    public static func == (lhs: GeoPosition, rhs: GeoPosition) -> Bool {
        return lhs.name == rhs.name &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}

public struct searchResultItem: Identifiable {
    public let title: String
    public let coordinates: CLLocationCoordinate2D
    
    public var id = UUID()
    
    public init(title: String, coordinates: CLLocationCoordinate2D) {
        self.title = title
        self.coordinates = coordinates
    }
}

extension String {
    // Function to normalize the string by removing accents and hyphens
    public func normalized() -> String {
        let normalizedString = self.folding(options: .diacriticInsensitive, locale: .current)
        return normalizedString.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
    }
}

public class StopStore: ObservableObject {
    @Published public var stops: [Stop] = []
    @Published public var searchText: String = ""
    @Published public private(set) var filteredStops: [Stop] = []
    @Published public var activeStops: [Stop] = []
    @Published public var mapStops: [LocationStop] = []
    @Published public var location: CLLocation?
    
    private var cancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval = 0.3 // 300ms debounce interval

    public init() {
        loadAllStops()
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

    /// La base des arrêts est embarquée dans tpgNextFunc, pas dans les apps,
    /// pour que iOS et watchOS partagent exactement les mêmes fichiers.
    private static let stopsBundle = Bundle(for: StopStore.self)

    private func loadStops(from fileName: String) {
        guard let url = Self.stopsBundle.url(forResource: fileName, withExtension: "json") else {
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
            uniqueStops[stop.sloid] = stop
        }
        activeStops = Array(uniqueStops.values)
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

    public func findStop(id: String) -> Stop? {
        let harmonizedID = sloidHarmonizer(code: id)
        return activeStops.first { $0.sloid == harmonizedID }
    }
}


/// Identité persistée d'un favori.
///
/// Le `sloid` est la seule source de vérité : le nom et le type de transport sont
/// des instantanés du dernier état connu, utilisés uniquement si la base ne résout
/// pas le sloid (arrêt supprimé de la base, base pas encore chargée).
public struct FavoriteStop: Codable, Identifiable, Hashable {
    public var sloid: String
    public var cachedName: String
    public var cachedMeansOfTransport: String
    public var cachedCoordinates: Coordinates
    /// Conservé uniquement pour rattraper les favoris hérités sans sloid.
    public var legacyCodedidoc: String

    public var id: String { sloid.isEmpty ? legacyCodedidoc : sloid }

    public init(stop: Stop) {
        self.sloid = sloidHarmonizer(code: stop.sloid)
        self.cachedName = stop.name
        self.cachedMeansOfTransport = stop.meansOfTransport
        self.cachedCoordinates = stop.wgs84Coordinates
        self.legacyCodedidoc = stop.codedidoc
    }

    /// L'arrêt reconstruit depuis l'instantané, quand la base ne peut pas le résoudre.
    public var fallbackStop: Stop {
        Stop(name: cachedName,
             sloid: sloid,
             codedidoc: legacyCodedidoc,
             country: "",
             canton: "",
             meansOfTransport: cachedMeansOfTransport,
             wgs84Coordinates: cachedCoordinates)
    }

    /// Rafraîchit l'instantané depuis la base. Retourne `true` si quelque chose a changé.
    fileprivate mutating func refreshCache(from stop: Stop) -> Bool {
        guard cachedName != stop.name
                || cachedMeansOfTransport != stop.meansOfTransport
                || cachedCoordinates != stop.wgs84Coordinates
                || sloid != stop.sloid else { return false }
        sloid = stop.sloid
        cachedName = stop.name
        cachedMeansOfTransport = stop.meansOfTransport
        cachedCoordinates = stop.wgs84Coordinates
        legacyCodedidoc = stop.codedidoc
        return true
    }
}

/// L'accès bas niveau aux favoris enregistrés.
///
/// Le widget a besoin de la liste sans instancier tout `FavoritesViewModel`
/// (qui parle à la montre et à la base des arrêts, hors sujet dans une extension).
public enum FavoritesStorage {
    public static let key = "favoriteStopsV2"
    public static let legacyKey = "favoriteStops"

    /// Les favoris tels qu'enregistrés, sans résolution contre la base.
    public static func load(from defaults: UserDefaults = SharedStorage.defaults) -> [FavoriteStop] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([FavoriteStop].self, from: data)) ?? []
    }
}

public class FavoritesViewModel: ObservableObject {
    public static let shared = FavoritesViewModel()

    /// Les identités persistées, dans l'ordre choisi par l'utilisateur.
    @Published public private(set) var favorites: [FavoriteStop] = []

    /// Les favoris résolus contre la base — c'est ce que consomment les vues.
    /// Même ordre et même cardinalité que `favorites`, donc les index restent alignés.
    @Published public private(set) var favoriteStops: [Stop] = []

    private weak var stopStore: StopStore?

    private let storageKey = FavoritesStorage.key
    private let legacyStorageKey = FavoritesStorage.legacyKey

    /// Les favoris vivent dans le groupe d'app : le widget doit pouvoir les lire.
    private var store: UserDefaults { SharedStorage.defaults }

    public init() {
        loadFavorites()
    }

    /// Relie le modèle à la base des arrêts. À appeler une fois la base disponible :
    /// sans ça les favoris restent affichés depuis leur instantané.
    public func attach(stopStore: StopStore) {
        self.stopStore = stopStore
        refresh()
        // Les noms viennent d'être re-résolus : la montre doit recevoir cette version-là.
        syncFavoritesToWatch()
    }

    // MARK: - Mutations

    public func addFavorite(_ stop: Stop) {
        let entry = FavoriteStop(stop: stop)
        guard !favorites.contains(where: { $0.id == entry.id }) else { return }
        favorites.append(entry)
        commit()
    }

    public func removeFavoriteStop(_ stop: Stop) {
        let sloid = sloidHarmonizer(code: stop.sloid)
        favorites.removeAll { $0.sloid == sloid || (!stop.codedidoc.isEmpty && $0.legacyCodedidoc == stop.codedidoc) }
        commit()
    }

    public func removeFavoriteIndex(atOffsets offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        commit()
    }

    public func moveFavorite(fromOffsets source: IndexSet, toOffset destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        commit()
    }

    /// Remplace toute la liste (utilisé par la synchronisation depuis la montre).
    public func replaceAll(with stops: [Stop]) {
        favorites = stops.map(FavoriteStop.init(stop:))
        commit()
    }

    // MARK: - Lectures

    public func isFavorite(_ stop: Stop) -> Bool {
        isFavoriteID(stop.sloid.isEmpty ? stop.codedidoc : stop.sloid)
    }

    public func isFavoriteID(_ id: String) -> Bool {
        let harmonizedID = sloidHarmonizer(code: id)
        return favorites.contains { $0.sloid == harmonizedID || $0.legacyCodedidoc == harmonizedID }
    }

    // MARK: - Résolution contre la base

    /// Re-résout chaque favori. La base gagne toujours ; l'instantané ne sert que
    /// si le sloid est introuvable. Les instantanés périmés sont rafraîchis au passage.
    public func refresh() {
        var cacheChanged = false
        var resolved: [Stop] = []
        resolved.reserveCapacity(favorites.count)

        for index in favorites.indices {
            if let stop = resolveStop(for: favorites[index]) {
                if favorites[index].refreshCache(from: stop) { cacheChanged = true }
                resolved.append(stop)
            } else {
                resolved.append(favorites[index].fallbackStop)
            }
        }

        favoriteStops = resolved
        if cacheChanged { saveFavorites() }
    }

    private func resolveStop(for favorite: FavoriteStop) -> Stop? {
        guard let stopStore else { return nil }
        if !favorite.sloid.isEmpty, let stop = stopStore.findStop(id: favorite.sloid) {
            return stop
        }
        // Favori hérité sans sloid : on le retrouve par codedidoc, refreshCache le corrigera.
        guard !favorite.legacyCodedidoc.isEmpty else { return nil }
        return stopStore.activeStops.first { $0.codedidoc == favorite.legacyCodedidoc }
    }

    private func commit() {
        saveFavorites()
        refresh()
        syncFavoritesToWatch()
    }

    // MARK: - Persistance

    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            store.set(data, forKey: storageKey)
            reloadWidgets()
        } catch {
            print("Error encoding favorite stops: \(error)")
        }
    }

    /// Le widget choisit son arrêt en fonction des favoris : il doit être redessiné
    /// dès que la liste change.
    private func reloadWidgets() {
        #if canImport(WidgetKit) && !os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func loadFavorites() {
        // Les favoris enregistrés avant l'arrivée du groupe d'app sont encore
        // dans .standard : on les y récupère une fois, sans effacer l'original.
        if store != UserDefaults.standard, store.data(forKey: storageKey) == nil,
           let inherited = UserDefaults.standard.data(forKey: storageKey) {
            store.set(inherited, forKey: storageKey)
        }

        if let data = store.data(forKey: storageKey) {
            do {
                favorites = try JSONDecoder().decode([FavoriteStop].self, from: data)
                refresh()
                return
            } catch {
                print("Error decoding favorite stops: \(error)")
            }
        }
        migrateLegacyFavorites()
    }

    /// Migration depuis l'ancien format ([Stop] complets sous la clé "favoriteStops").
    /// L'ancienne clé est laissée intacte pour permettre un retour arrière.
    private func migrateLegacyFavorites() {
        guard let data = store.data(forKey: legacyStorageKey)
                ?? UserDefaults.standard.data(forKey: legacyStorageKey) else { return }
        do {
            let legacyStops = try JSONDecoder().decode([Stop].self, from: data)
            favorites = legacyStops.map(FavoriteStop.init(stop:))
            saveFavorites()
            refresh()
            print("Migrated \(favorites.count) favorites to \(storageKey)")
        } catch {
            print("Error migrating legacy favorite stops: \(error)")
        }
    }

    /// Pousse les favoris vers la montre via le contexte applicatif.
    ///
    /// Contrairement à `sendMessage`, ça n'exige pas que la montre soit joignable :
    /// le système conserve le dernier contexte et le livre au prochain réveil de l'app
    /// montre. C'est la sémantique voulue ici — « le dernier état gagne ».
    public func syncFavoritesToWatch() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        do {
            let data = try JSONEncoder().encode(favoriteStops)
            try session.updateApplicationContext(["favoriteStops": data])
        } catch {
            print("Failed to sync favorites to watch: \(error)")
        }
    }
}


public struct splitStopName: View {
    var stopName: String
    
    public var body: some View {
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

/// Ramène un sloid de quai (`ch:1:sloid:87061:0:450545`) au sloid de l'arrêt parent (`ch:1:sloid:87061`).
/// Un sloid déjà au niveau de l'arrêt (4 composants) est retourné tel quel.
public func sloidHarmonizer(code: String) -> String {
    let components = code.split(separator: ":")
    guard components.count > 4 else { return code }
    return components.prefix(4).joined(separator: ":")
}

/// `true` si le sloid désigne un quai et non l'arrêt parent.
public func isQuaySloid(_ code: String) -> Bool {
    code.split(separator: ":").count > 4
}

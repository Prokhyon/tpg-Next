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
    /// L'adresse de « Ma position », trouvée après coup : elle nomme l'itinéraire. Hors de
    /// l'égalité : la trouver ne change pas de lieu.
    public var address: String?

    public init(name: String, coordinate: CLLocationCoordinate2D, address: String? = nil) {
        self.name = name
        self.coordinate = coordinate
        self.address = address
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
    /// Le texte sans accents ni ponctuation, pour la recherche : « Genève, Rive » devient
    /// « GeneveRive », que « geneve rive » retrouve. La virgule restait, et « geneve rive »
    /// ne trouvait pas « Genève, Rive ».
    public func normalized() -> String {
        String(folding(options: .diacriticInsensitive, locale: .current).filter { $0.isLetter || $0.isNumber })
    }
}

@Observable
public class StopStore {
    public private(set) var stops: [Stop] = []
    public private(set) var activeStops: [Stop] = []
    public var location: CLLocation?
    /// Vrai une fois la base chargée, ce qui se fait en arrière-plan.
    public private(set) var isLoaded = false
    /// Les appels à `waitUntilLoaded` en attente, repris à la fin du chargement.
    @ObservationIgnored private var loadWaiters: [CheckedContinuation<Void, Never>] = []
    
    /// `findStop` était un parcours des ~29 000 arrêts, appelé pour chaque favori.
    private var stopsBySloid: [String: Stop] = [:]
    /// Noms normalisés une fois pour toutes : la recherche les recalculait à chaque frappe.
    private(set) var searchIndex: [(key: String, stop: Stop)] = []

    /// - Parameter publishesNames: donne les noms officiels à `StopNames` une fois la base
    ///   chargée. Pour l'app et la montre ; les tests ne touchent pas à ce réglage global.
    public init(publishesNames: Bool = false) {
        // ~6 Mo de JSON : décodés hors du thread principal, qu'ils bloquaient au lancement
        // (et bien plus longtemps sur la montre).
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = Self.loadAllStops()
            var unique: [String: Stop] = [:]
            for stop in loaded {
                unique[stop.sloid] = stop
            }
            let active = Array(unique.values)
            let index = active.map { (key: $0.name.normalized().lowercased(), stop: $0) }
            DispatchQueue.main.async {
                self.stops = loaded
                self.stopsBySloid = unique
                self.activeStops = active
                self.searchIndex = index
                self.isLoaded = true
                // Une copie de l'index, qui ne change plus : lue sans risque pendant le décodage
                // des départs, hors du thread principal.
                if publishesNames {
                    StopNames.resolve = { unique[$0]?.name }
                }
                self.loadWaiters.forEach { $0.resume() }
                self.loadWaiters = []
            }
        }
    }

    /// Rend la main une fois la base chargée, tout de suite si elle l'est déjà.
    @MainActor
    public func waitUntilLoaded() async {
        guard !isLoaded else { return }
        await withCheckedContinuation { loadWaiters.append($0) }
    }

    // MARK: - Chargement

    /// La base des arrêts est embarquée dans tpgNextFunc, pas dans les apps,
    /// pour que iOS et watchOS partagent exactement les mêmes fichiers.
    private static let stopsBundle = Bundle(for: StopStore.self)

    private static func loadAllStops() -> [Stop] {
        ["FullStopsCH", "TrainStopsFR"].flatMap(loadStops(from:))
    }

    private static func loadStops(from fileName: String) -> [Stop] {
        guard let url = stopsBundle.url(forResource: fileName, withExtension: "json") else {
            Log.data.error("\(fileName).json introuvable dans le bundle")
            return []
        }

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

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let tempStops = try decoder.decode([TempStop].self, from: Data(contentsOf: url))
            let stops = tempStops.compactMap { tempStop -> Stop? in
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
            Log.data.debug("\(fileName).json : \(stops.count) arrêts")
            return stops
        } catch {
            Log.data.error("Lecture de \(fileName).json impossible : \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Recherche

    /// Les arrêts dont le nom contient `query` (accents, espaces et tirets ignorés), du plus
    /// proche au plus lointain si la position est connue, sinon par ordre alphabétique.
    /// Chaque écran appelle `searchingStops`, qui garde son propre texte de recherche.
    public func search(_ query: String) -> [Stop] {
        let normalizedQuery = query.normalized().lowercased()
        // Des espaces seuls se normalisent en "" : `contains("")` rendrait toute la base.
        guard !normalizedQuery.isEmpty else { return [] }

        let matchingStops = searchIndex.filter { $0.key.contains(normalizedQuery) }.map(\.stop)

        if let currentLocation = location {
            // Distances calculées une fois par arrêt, et non à chaque comparaison du tri.
            return matchingStops
                .map { (stop: $0, distance: CLLocation(latitude: $0.wgs84Coordinates.lat, longitude: $0.wgs84Coordinates.lon).distance(from: currentLocation)) }
                .sorted { $0.distance < $1.distance }
                .map(\.stop)
        }
        return matchingStops.sorted { $0.name < $1.name }
    }

    // MARK: - Utility Function

    public func findStop(id: String) -> Stop? {
        let harmonizedID = sloidHarmonizer(code: id)
        return stopsBySloid[harmonizedID]
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

    /// Enregistre les favoris là où le widget les lit. Pour la montre, qui reçoit les siens de
    /// l'iPhone : sur l'iPhone, `FavoritesViewModel` s'en charge.
    public static func save(_ favorites: [FavoriteStop], to defaults: UserDefaults = SharedStorage.defaults) {
        do {
            defaults.set(try JSONEncoder().encode(favorites), forKey: key)
        } catch {
            Log.data.error("Enregistrement des favoris impossible : \(error.localizedDescription)")
        }
    }
}

@Observable
public class FavoritesViewModel {
    public static let shared = FavoritesViewModel()

    /// Les identités persistées, dans l'ordre choisi par l'utilisateur.
    public private(set) var favorites: [FavoriteStop] = []

    /// Les favoris résolus contre la base — c'est ce que consomment les vues.
    /// Même ordre et même cardinalité que `favorites`, donc les index restent alignés.
    public private(set) var favoriteStops: [Stop] = []

    private weak var stopStore: StopStore?

    private let storageKey = FavoritesStorage.key
    private let legacyStorageKey = FavoritesStorage.legacyKey

    /// Les favoris vivent dans le groupe d'app : le widget doit pouvoir les lire.
    private var store: UserDefaults { SharedStorage.defaults }

    /// Seul le sloid compte : chaque appareil rafraîchit l'instantané depuis sa propre base,
    /// qui peut ne pas être à la même version.
    private let cloud = CloudCollection<FavoriteStop>(key: "cloud.favorites", id: \.id,
                                                       isSame: { $0.id == $1.id })

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

    /// Partage les favoris avec les autres appareils via iCloud. Seule l'app iOS l'appelle.
    public func startCloudSync() {
        cloud.start(current: favorites) { [weak self] merged in
            guard let self else { return }
            favorites = merged
            saveFavorites()
            refresh()
            syncFavoritesToWatch()
        }
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
        cloud.record(favorites)
    }

    // MARK: - Persistance

    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            store.set(data, forKey: storageKey)
            reloadWidgets()
        } catch {
            Log.data.error("Enregistrement des favoris impossible : \(error.localizedDescription)")
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
                Log.data.error("Lecture des favoris impossible : \(error.localizedDescription)")
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
            Log.data.info("\(self.favorites.count) favoris migrés vers \(self.storageKey)")
        } catch {
            Log.data.error("Migration des anciens favoris impossible : \(error.localizedDescription)")
        }
    }

    /// Pousse les favoris vers la montre via le contexte applicatif.
    ///
    /// Contrairement à `sendMessage`, ça n'exige pas que la montre soit joignable :
    /// le système conserve le dernier contexte et le livre au prochain réveil de l'app
    /// montre. C'est la sémantique voulue ici — « le dernier état gagne ».
    public func syncFavoritesToWatch() {
        do {
            WatchContext.update(WatchContext.favoritesKey, with: try JSONEncoder().encode(favoriteStops))
        } catch {
            Log.sync.error("Envoi des favoris à la montre impossible : \(error.localizedDescription)")
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
/// Les noms officiels des arrêts (« Commune, Nom »), par sloid, une fois la base chargée.
///
/// Le texte de destination d'OJP (`DestinationText`) est celui que l'exploitant affiche sur le
/// véhicule, et il varie d'une course à l'autre pour le même terminus : « Moillesulaz » ou
/// « Genève, Moillesulaz ». Le sloid de destination, lui, est stable : son nom officiel s'affiche
/// sur deux lignes, avec la commune, et regroupe les départs d'une même direction.
public enum StopNames {
    /// Le nom d'un arrêt par son sloid (d'arrêt, pas de quai). Posé par la `StopStore` de l'app
    /// et de la montre à la fin du chargement, par l'index des arrêts dans le widget ; sans rien,
    /// le texte d'OJP reste.
    public static var resolve: ((String) -> String?)?

    /// Le départ, avec le nom officiel de sa destination quand la base le connaît.
    public static func withOfficialDestination(_ event: StopEvent) -> StopEvent {
        withOfficialDestination(event, resolve: resolve)
    }

    /// L'itinéraire, avec le nom officiel de la destination de chaque véhicule.
    public static func withOfficialDestinations(_ trip: TripEvent) -> TripEvent {
        guard let resolve else { return trip }
        var trip = trip
        trip.legs = trip.legs.map { leg in
            guard let ref = leg.legDestinationRef, let name = resolve(sloidHarmonizer(code: ref)), !name.isEmpty else { return leg }
            var leg = leg
            leg.legDestination = name
            return leg
        }
        return trip
    }

    static func withOfficialDestination(_ event: StopEvent, resolve: ((String) -> String?)?) -> StopEvent {
        guard let ref = event.destinationRef, let name = resolve?(sloidHarmonizer(code: ref)), !name.isEmpty else { return event }
        var event = event
        event.destination = name
        return event
    }
}

public func sloidHarmonizer(code: String) -> String {
    let components = code.split(separator: ":")
    guard components.count > 4 else { return code }
    return components.prefix(4).joined(separator: ":")
}

/// `true` si le sloid désigne un quai et non l'arrêt parent.
public func isQuaySloid(_ code: String) -> Bool {
    code.split(separator: ":").count > 4
}

//
//  LineTrack.swift
//  tpgNextFunc
//
//  Tracé géographique réel d'une course, fourni par l'OJPTripInfoRequest
//  (IncludeTrackSections + IncludeTrackProjection).
//

import Foundation
import CoreLocation
import CryptoKit

/// Extrait les positions de tous les `LinkProjection` d'une réponse TripInfo, dans l'ordre.
/// Accepte OJP 1.0 (`ojp:Position` / `siri:Longitude`) comme OJP 2.0 (sans préfixe).
public func parseJourneyTrack(from data: Data) -> [CLLocationCoordinate2D] {
    final class TrackParserDelegate: NSObject, XMLParserDelegate {
        var coordinates: [CLLocationCoordinate2D] = []
        private var insideProjection = false
        private var text = ""
        private var longitude: Double?
        private var latitude: Double?

        private func localName(_ name: String) -> Substring {
            name.split(separator: ":").last ?? Substring(name)
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            switch localName(elementName) {
            case "LinkProjection":
                insideProjection = true
            case "Position":
                longitude = nil
                latitude = nil
            default:
                break
            }
            text = ""
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if insideProjection {
                text += string
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            guard insideProjection else { return }
            switch localName(elementName) {
            case "Longitude":
                longitude = Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
            case "Latitude":
                latitude = Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
            case "Position":
                if let longitude, let latitude {
                    coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                }
            case "LinkProjection":
                insideProjection = false
            default:
                break
            }
            text = ""
        }
    }

    let delegate = TrackParserDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = delegate
    parser.parse()
    return delegate.coordinates
}

/// Découpe le tracé complet en un segment par paire d'arrêts consécutifs,
/// pour pouvoir griser séparément la partie déjà parcourue.
///
/// Renvoie `stops.count - 1` segments, ou `nil` si le tracé ne correspond pas aux arrêts
/// (plus d'un quart des arrêts à plus de 300 m) : l'appelant retombe alors sur des lignes droites.
/// Un arrêt sans coordonnées donne un segment vide ; le suivant couvre alors le trou.
public func splitTrack(_ rawTrack: [CLLocationCoordinate2D], atStops stops: [CLLocationCoordinate2D]) -> [[CLLocationCoordinate2D]]? {
    guard rawTrack.count >= 2, stops.count >= 2 else { return nil }

    func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dx = (b.longitude - a.longitude) * cos(a.latitude * .pi / 180) * 111_320
        let dy = (b.latitude - a.latitude) * 110_540
        return (dx * dx + dy * dy).squareRoot()
    }
    func isValid(_ stop: CLLocationCoordinate2D) -> Bool { stop.latitude != 0 && stop.longitude != 0 }

    // En ligne droite, deux points du tracé peuvent être à plusieurs centaines de mètres :
    // on en intercale tous les 20 m, sinon deux arrêts proches tombent sur le même point
    // et le segment qui les relie disparaît.
    var track: [CLLocationCoordinate2D] = [rawTrack[0]]
    for (a, b) in zip(rawTrack, rawTrack.dropFirst()) {
        let steps = Int(distance(a, b) / 20)
        if steps > 0 {
            for k in 1...steps {
                let t = Double(k) / Double(steps + 1)
                track.append(CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                                    longitude: a.longitude + (b.longitude - a.longitude) * t))
            }
        }
        track.append(b)
    }

    // Place chaque arrêt sur un point du tracé, dans l'ordre de passage, en minimisant la somme
    // des distances (programmation dynamique). Contrairement au « plus proche point suivant »,
    // une boucle qui repasse près d'un arrêt ou un arrêt un peu à l'écart ne décale pas les autres.
    let n = track.count
    var cost = [Double](repeating: 0, count: n)
    var back: [[Int]] = []
    for (s, stop) in stops.enumerated() {
        var newCost = [Double](repeating: 0, count: n)
        var previous = [Int](repeating: 0, count: n)
        var bestPrevious = Double.infinity
        var bestPreviousIndex = 0
        for j in 0..<n {
            if s == 0 {
                bestPrevious = 0
            } else if cost[j] < bestPrevious {
                bestPrevious = cost[j]
                bestPreviousIndex = j
            }
            newCost[j] = bestPrevious + (isValid(stop) ? distance(track[j], stop) : 0)
            previous[j] = bestPreviousIndex
        }
        cost = newCost
        back.append(previous)
    }

    var indices = [Int](repeating: 0, count: stops.count)
    indices[stops.count - 1] = cost.indices.min { cost[$0] < cost[$1] } ?? 0
    for s in stride(from: stops.count - 1, to: 0, by: -1) {
        indices[s - 1] = back[s][indices[s]]
    }

    let farStops = stops.indices.filter { isValid(stops[$0]) && distance(track[indices[$0]], stops[$0]) > 300 }.count
    guard farStops * 4 <= stops.count else { return nil }

    return (0..<(stops.count - 1)).map { i in
        indices[i + 1] > indices[i] ? Array(track[indices[i]...indices[i + 1]]) : []
    }
}

/// Cache disque des tracés, indexé par la suite des arrêts desservis : toutes les courses
/// d'un même parcours partagent la même entrée. Expire après 30 jours (changements d'horaire, travaux).
public enum LineTrackCache {
    private static let maxAge: TimeInterval = 30 * 24 * 3600

    private static var directory: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let url = caches.appendingPathComponent("LineTracks", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// `nil` tant que les arrêts ne sont pas connus.
    public static func key(for events: [LineEvent]) -> String? {
        key(forStopRefs: events.map(\.stopPlaceRef))
    }

    /// Même clé pour une étape d'itinéraire qui couvre toute la course : le contenu est alors identique.
    public static func key(forStopRefs refs: [String]) -> String? {
        guard refs.count >= 2, !refs.contains(where: \.isEmpty) else { return nil }
        let digest = SHA256.hash(data: Data(refs.joined(separator: "|").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func load(key: String) -> [CLLocationCoordinate2D]? {
        guard let url = directory?.appendingPathComponent(key + ".json"),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < maxAge,
              let data = try? Data(contentsOf: url),
              let flat = try? JSONDecoder().decode([Double].self, from: data),
              flat.count >= 4, flat.count % 2 == 0 else { return nil }
        return stride(from: 0, to: flat.count, by: 2).map {
            CLLocationCoordinate2D(latitude: flat[$0], longitude: flat[$0 + 1])
        }
    }

    public static func save(_ track: [CLLocationCoordinate2D], key: String) {
        guard let url = directory?.appendingPathComponent(key + ".json") else { return }
        let flat = track.flatMap { [$0.latitude, $0.longitude] }
        if let data = try? JSONEncoder().encode(flat) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// Portion du tracé qui passe par `stops` (du premier au dernier), d'un seul tenant.
public func trackPortion(_ track: [CLLocationCoordinate2D], alongStops stops: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D]? {
    guard let segments = splitTrack(track, atStops: stops) else { return nil }
    var portion: [CLLocationCoordinate2D] = []
    for segment in segments where segment.count >= 2 {
        portion += portion.isEmpty ? segment : Array(segment.dropFirst())
    }
    return portion.count >= 2 ? portion : nil
}

extension TripLeg {
    /// Montée, arrêts intermédiaires et descente, dans l'ordre.
    var trackStopRefs: [String] {
        [legBoardStopId] + legIntermediates.map(\.stopId) + [legAlightStopId]
    }

    public var trackStops: [CLLocationCoordinate2D] {
        let latitudes = [legBoardLatitude] + legIntermediates.map(\.latitude) + [legAlightLatitude]
        let longitudes = [legBoardLongitude] + legIntermediates.map(\.longitude) + [legAlightLongitude]
        return zip(latitudes, longitudes).map {
            CLLocationCoordinate2D(latitude: Double($0) ?? 0, longitude: Double($1) ?? 0)
        }
    }

    /// Connue avant toute requête : un itinéraire déjà affiché se rouvre sans réseau.
    public var trackCacheKey: String? {
        LineTrackCache.key(forStopRefs: trackStopRefs)
    }
}

/// Tracé d'une étape d'itinéraire : on demande la course entière (OJPTripInfoRequest) et on n'en
/// garde que la portion entre la montée et la descente. La course entière est aussi mise en cache,
/// pour que sa carte de ligne s'affiche ensuite sans requête. Appelle `completion` sur le thread principal.
public func fetchLegTrack(for leg: TripLeg, completion: @escaping ([CLLocationCoordinate2D]?) -> Void) {
    func finish(_ track: [CLLocationCoordinate2D]?) {
        DispatchQueue.main.async { completion(track) }
    }
    guard !leg.transfer, !leg.journeyRef.isEmpty, let legKey = leg.trackCacheKey else {
        finish(nil)
        return
    }
    fetchTransportJourney(journeyRef: leg.journeyRef, operatingDayRef: leg.resolvedOperatingDayRef, track: true, expectedStopRef: leg.legBoardStopId, expectedTime: leg.legBoardTimetableTime) { data in
        guard let data else {
            finish(nil)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let track = parseJourneyTrack(from: data)
            let portion = trackPortion(track, alongStops: leg.trackStops)
            parseJourneyEvents(from: data) { events, _ in
                if track.count >= 2, let journeyKey = LineTrackCache.key(for: events) {
                    LineTrackCache.save(track, key: journeyKey)
                }
                if let portion {
                    LineTrackCache.save(portion, key: legKey)
                }
                finish(portion)
            }
        }
    }
}


/// Position estimée du véhicule d'une course, sans GPS : entre les deux arrêts qui encadrent
/// `now`, au prorata du temps écoulé entre leurs heures de départ (estimées si connues).
///
/// Suit le tracé routier quand `segments` en fournit un par intervalle, une ligne droite sinon.
/// `nil` avant le départ du premier arrêt ou après le terminus.
public func estimatedVehiclePosition(events: [LineEvent], segments: [[CLLocationCoordinate2D]]?, at now: Date) -> CLLocationCoordinate2D? {
    guard events.count >= 2 else { return nil }
    for index in 0..<(events.count - 1) {
        guard let start = events[index].departureDate, let end = events[index + 1].departureDate,
              start <= now, now < end else { continue }
        let duration = end.timeIntervalSince(start)
        let fraction = duration > 0 ? now.timeIntervalSince(start) / duration : 0
        let from = CLLocationCoordinate2D(latitude: Double(events[index].latitude) ?? 0, longitude: Double(events[index].longitude) ?? 0)
        let to = CLLocationCoordinate2D(latitude: Double(events[index + 1].latitude) ?? 0, longitude: Double(events[index + 1].longitude) ?? 0)
        var path = [from, to]
        if let segments, segments.count == events.count - 1, segments[index].count >= 2 {
            path = segments[index]
        }
        return point(along: path, fraction: fraction)
    }
    return nil
}

/// Le point situé à `fraction` (0…1) de la longueur d'un chemin.
func point(along path: [CLLocationCoordinate2D], fraction: Double) -> CLLocationCoordinate2D? {
    guard let first = path.first else { return nil }
    let lengths = zip(path, path.dropFirst()).map { a, b in
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
    let total = lengths.reduce(0, +)
    guard total > 0 else { return first }
    var remaining = min(max(fraction, 0), 1) * total
    for (index, length) in lengths.enumerated() {
        if remaining <= length, length > 0 {
            let ratio = remaining / length
            let a = path[index], b = path[index + 1]
            return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * ratio,
                                          longitude: a.longitude + (b.longitude - a.longitude) * ratio)
        }
        remaining -= length
    }
    return path.last
}

//
//  JourneyParser.swift
//  tpgNextFunc
//
//  Lecture d'une réponse OJPTripInfoRequest en OJP 2.0. OJP 1.0 attend comme jour
//  d'exploitation la date locale de départ de la course, et renvoie la course de la
//  nuit précédente (ou rien) pour celles qui partent après minuit : OJP 2.0 accepte
//  le jour d'exploitation que l'API renvoie partout ailleurs.
//

import Foundation

/// Arrêts d'une course, depuis une réponse OJP 2.0. Mêmes `LineEvent` que l'ancien parser
/// OJP 1.0 : l'heure retenue est celle de départ (d'arrivée au terminus), `sloid` est l'arrêt
/// parent (StopPlace) et les coordonnées sont celles du quai.
/// `operatorName` est vide quand l'opérateur est inconnu.
public func parseJourneyEventsSync(from data: Data) -> (events: [LineEvent], operatorName: String) {
    final class JourneyParserDelegate: NSObject, XMLParserDelegate {
        struct Place {
            var parentRef: String
            var longitude: String
            var latitude: String
        }

        var events: [LineEvent] = []
        var places: [String: Place] = [:]
        var operatorRef = ""
        var operatorName = ""

        private var path: [String] = []
        private var text = ""
        private var call: LineEvent?
        private var placeRef = ""
        private var placeParent = ""
        private var placeLongitude = ""
        private var placeLatitude = ""

        private func localName(_ name: String) -> String {
            String(name.split(separator: ":").last ?? Substring(name))
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            let name = localName(elementName)
            path.append(name)
            text = ""
            switch name {
            case "PreviousCall", "OnwardCall":
                call = LineEvent(stopPointName: "", plannedQuay: "", timetabledTime: "", estimatedTime: "", stopPlaceRef: "", sloid: "", previousCall: name == "PreviousCall", longitude: "", latitude: "")
            case "Place":
                placeRef = ""
                placeParent = ""
                placeLongitude = ""
                placeLatitude = ""
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let name = localName(elementName)
            let parent = path.count >= 2 ? path[path.count - 2] : ""
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            defer {
                path.removeLast()
                text = ""
            }

            if var current = call {
                switch name {
                case "StopPointRef":
                    current.stopPlaceRef = value
                case "Text" where parent == "StopPointName":
                    current.stopPointName = value
                case "Text" where parent == "PlannedQuay":
                    current.plannedQuay = value
                case "Text" where parent == "NameSuffix":
                    current.quayAccess = QuayAccess(rawValue: value) ?? current.quayAccess
                case "NotServicedStop" where value == "true":
                    current.isCancelled = true
                // L'arrivée précède le départ : le départ l'emporte, comme avec OJP 1.0.
                case "TimetabledTime" where !value.isEmpty:
                    current.timetabledTime = value
                case "EstimatedTime" where !value.isEmpty:
                    current.estimatedTime = value
                case "PreviousCall", "OnwardCall":
                    events.append(current)
                    call = nil
                    return
                default:
                    break
                }
                call = current
            } else if path.contains("Place") {
                switch name {
                case "StopPointRef" where parent == "StopPoint", "StopPlaceRef" where parent == "StopPlace":
                    placeRef = value
                case "ParentRef" where parent == "StopPoint":
                    placeParent = value
                case "Longitude" where parent == "GeoPosition":
                    placeLongitude = value
                case "Latitude" where parent == "GeoPosition":
                    placeLatitude = value
                case "Place" where !placeRef.isEmpty:
                    places[placeRef] = Place(parentRef: placeParent.isEmpty ? placeRef : placeParent, longitude: placeLongitude, latitude: placeLatitude)
                default:
                    break
                }
            } else if name == "OperatorRef" {
                operatorRef = value
            } else if name == "Text" && parent == "OperatorName" {
                operatorName = value
            }
        }
    }

    let delegate = JourneyParserDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = delegate
    parser.parse()

    // Le contexte (lieux) peut suivre les appels : les coordonnées sont résolues à la fin.
    var events = delegate.events
    for index in events.indices {
        if let place = delegate.places[events[index].stopPlaceRef] {
            events[index].sloid = place.parentRef
            events[index].longitude = place.longitude
            events[index].latitude = place.latitude
        }
    }
    // L'API répète parfois un arrêt (même quai, même heure, Order 1 et 2). Deux lignes de
    // même identifiant laissaient un vide dans la liste de la course (LazyVStack).
    var seen = Set<String>()
    events = events.filter { seen.insert($0.id).inserted }
    let operatorName = delegate.operatorName.isEmpty ? (OJPOperators.name(forRef: delegate.operatorRef) ?? "") : delegate.operatorName
    return (events, operatorName)
}

/// La course reçue passe-t-elle par l'arrêt attendu, à l'heure prévue (à 5 minutes près) ?
/// L'arrêt peut être un quai ou l'arrêt parent. Sans arrêt ni heure, toute course non vide convient.
public func journeyMatches(_ events: [LineEvent], stopRef: String?, timetabledTime: String?) -> Bool {
    guard !events.isEmpty else { return false }
    let stop = (stopRef?.isEmpty ?? true) ? nil : stopRef
    let expected = timetabledTime.flatMap(OJPDate.date(from:))
    guard stop != nil || expected != nil else { return true }

    return events.contains { event in
        let stopMatches = stop.map { stop in
            [event.stopPlaceRef, event.sloid].contains { $0 == stop || $0.hasPrefix(stop + ":") }
        } ?? true
        let timeMatches = expected.map { expected in
            OJPDate.date(from: event.timetabledTime).map { abs($0.timeIntervalSince(expected)) <= 300 } ?? false
        } ?? true
        return stopMatches && timeMatches
    }
}

/// Jours d'exploitation à essayer, dans l'ordre : celui fourni, puis le lendemain et la veille.
/// L'API n'est pas cohérente d'un service à l'autre pour certaines courses de nuit.
public func operatingDayCandidates(for day: String) -> [String] {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: day) else { return [day] }
    return [0, 1, -1].map { formatter.string(from: date.addingTimeInterval(Double($0) * 86_400)) }
}


/// Le véhicule d'une course : ce que l'élément `Service` d'une réponse TripInfo en dit.
public struct JourneyService: Hashable {
    /// Mode OJP : `bus`, `tram`, `rail`, `water`…
    public var ptMode = ""
    /// Nom du mode tel que l'API l'écrit (« Bus », « Tram »), en allemand.
    public var modeName = ""
    public var trainNumber = ""
    public var attributeCodes: [String] = []
    /// Course entière supprimée (incident « Ausfall »).
    public var isCancelled = false

    public var hasLowFloor: Bool { attributeCodes.contains("A__NF") }
}

/// Lit l'élément `Service` d'une réponse OJPTripInfoRequest (OJP 2.0).
public func parseJourneyServiceSync(from data: Data) -> JourneyService {
    let parser = JourneyServiceParser()
    parser.parse(data)
    return parser.service
}

final class JourneyServiceParser: OJPParser {
    private(set) var service = JourneyService()

    override func didEnd(_ name: String, parent: String, value: String) {
        guard isInside("Service"), !value.isEmpty else { return }
        switch name {
        case "PtMode": service.ptMode = value
        case "Text" where parent == "Name" && isInside("Mode"): service.modeName = value
        case "TrainNumber": service.trainNumber = value
        case "Code" where parent == "Attribute": service.attributeCodes.append(value)
        case "Text" where parent == "UserText" && isInside("Attribute") && value == "Ausfall": service.isCancelled = true
        default: break
        }
    }
}

//
//  OJPParsing.swift
//  tpgNextFunc
//
//  Lecture des réponses OJP 1.0 (départs, itinéraires). Même approche que
//  `JourneyParser` : une pile des éléments ouverts plutôt qu'une série de drapeaux
//  « à l'intérieur de… » à tenir à jour à la main.
//

import Foundation

/// Le nom d'un élément sans son préfixe d'espace de noms : `ojp:Text` devient `Text`.
/// OJP 1.0 et 2.0 ne préfixent pas les mêmes éléments ; les parseurs ne regardent que le nom.
func ojpLocalName(_ name: String) -> String {
    guard let colon = name.lastIndex(of: ":") else { return name }
    return String(name[name.index(after: colon)...])
}

/// Base des parseurs : tient la pile des éléments ouverts et le texte de l'élément courant.
class OJPParser: NSObject, XMLParserDelegate {
    private(set) var path: [String] = []
    private var text = ""
    /// La réponse n'est pas un document OJP lisible : XML cassé ou tronqué, page HTML d'une
    /// passerelle. Sans ce drapeau, elle donnait une liste vide, comme s'il n'y avait aucun départ.
    private(set) var isUnreadable = false
    private var root: String?

    func parse(_ data: Data) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        isUnreadable = !parser.parse() || root != "OJP"
    }

    /// À l'ouverture d'un élément, déjà sur la pile.
    func didStart(_ name: String) {}

    /// À la fermeture d'un élément, encore sur la pile. `value` est son texte propre,
    /// sans les espaces autour ; il est vide pour un élément qui n'a que des enfants.
    func didEnd(_ name: String, parent: String, value: String) {}

    func isInside(_ name: String) -> Bool {
        path.contains(name)
    }

    final func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                      qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = ojpLocalName(elementName)
        if path.isEmpty, root == nil { root = name }
        path.append(name)
        text = ""
        didStart(name)
    }

    final func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    final func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = ojpLocalName(elementName)
        let parent = path.count >= 2 ? path[path.count - 2] : ""
        didEnd(name, parent: parent, value: text.trimmingCharacters(in: .whitespacesAndNewlines))
        path.removeLast()
        text = ""
    }
}

// MARK: - Départs

/// Départs d'un arrêt, depuis une réponse OJPStopEventRequest en OJP 2.0.
///
/// Les champs de l'arrêt (heure, quai, accès, suppression) sont lus dans `ThisCall` seulement :
/// si la requête demandait les arrêts précédents ou suivants, leurs champs homonymes
/// n'écrasent rien. Les quais viennent du contexte (`Places`).
final class StopEventParser: OJPParser {
    private let stopCode: String
    private(set) var events: [StopEvent] = []
    private(set) var quays: [Quay] = []
    private(set) var error: ParserError?

    private var event: StopEvent?
    private var operatorRef = ""
    private var quay: Quay?
    private var quayParent = ""

    init(stopCode: String) {
        self.stopCode = stopCode
    }

    override func didStart(_ name: String) {
        switch name {
        case "StopEventResult":
            event = StopEvent(stopPointName: "", stopId: stopCode, plannedQuay: "", timetabledTime: "", estimatedTime: "",
                              lineName: "", origin: "", destination: "", transportType: "", operatorName: "",
                              journeyRef: "", operatingDayRef: "")
            operatorRef = ""
        case "Place" where isInside("StopEventResponseContext"):
            quay = Quay(id: "", quayName: "", latitude: "", longitude: "")
            quayParent = ""
        default:
            break
        }
    }

    override func didEnd(_ name: String, parent: String, value: String) {
        // OJP 2.0 : `ErrorCondition/StopEventProblemType` (STOPEVENT_NOEVENTFOUND, STOPEVENT_LOCATIONUNSERVED…).
        if name == "StopEventProblemType" || name == "ErrorText" {
            error = .noEventFound(message: value)
        }
        if var current = event {
            readEvent(&current, name: name, parent: parent, value: value)
            if name == "StopEventResult" {
                if current.estimatedTime.isEmpty {
                    current.estimatedTime = current.timetabledTime
                }
                if current.operatorName.isEmpty {
                    current.operatorName = OJPOperators.name(forRef: operatorRef) ?? ""
                }
                events.append(current)
                event = nil
            } else {
                event = current
            }
        }
        if var current = quay {
            switch name {
            case "StopPointRef" where parent == "StopPoint":
                current.id = value
            // Le code privé EFA se termine par le nom du quai : « 124816:0:D ».
            case "Value" where isInside("StopPoint"):
                current.quayName = value.split(separator: ":").last.map(String.init) ?? value
            case "ParentRef" where parent == "StopPoint":
                quayParent = value
            case "Longitude":
                current.longitude = value
            case "Latitude":
                current.latitude = value
            case "Place":
                // Le contexte peut aussi décrire d'autres arrêts (origine, destination) :
                // seuls les quais de l'arrêt demandé sont gardés.
                let parentStop = sloidHarmonizer(code: stopCode)
                if !current.id.isEmpty && (quayParent.isEmpty || quayParent == parentStop || current.id == stopCode) {
                    quays.append(current)
                }
                quay = nil
                return
            default:
                break
            }
            quay = current
        }
    }

    private func readEvent(_ event: inout StopEvent, name: String, parent: String, value: String) {
        // Les libellés sont dans un `<Text>` enfant : à la fermeture du parent, sa valeur vide
        // écraserait celle qui vient d'être lue.
        guard !value.isEmpty else { return }
        if isInside("ThisCall") {
            switch name == "Text" ? parent : name {
            case "StopPointName": event.stopPointName = value
            case "PlannedQuay": event.plannedQuay = value
            case "TimetabledTime" where isInside("ServiceDeparture"): event.timetabledTime = value
            case "EstimatedTime" where isInside("ServiceDeparture"): event.estimatedTime = value
            case "NameSuffix": event.quayAccess = QuayAccess(rawValue: value) ?? event.quayAccess
            case "NotServicedStop" where value == "true": event.isCancelled = true
            default: break
            }
            return
        }
        // Un « 1 » par jour de circulation dans l'année d'horaire. Une course habituelle en
        // compte au moins une dizaine ; celle qui n'en a qu'un remplace l'horaire ce jour-là
        // (la ligne G déviée le 19.09.2026, par exemple). Aucun autre marqueur ne le signale.
        if name == "Pattern" && parent == "OperatingDays" {
            if value.filter({ $0 == "1" }).count == 1 {
                event.isExceptional = true
            }
            return
        }
        guard isInside("Service") else { return }
        switch name {
        case "PtMode":
            event.ptMode = value
        case "Text" where parent == "Name" && isInside("Mode"):
            event.transportType = value
        case "Text" where parent == "PublishedServiceName":
            event.lineName = value
        case "Text" where parent == "OriginText":
            event.origin = value
        case "Text" where parent == "DestinationText":
            event.destination = value
        case "DestinationStopPointRef":
            event.destinationRef = value
        case "OperatorRef":
            operatorRef = value
        case "JourneyRef":
            event.journeyRef = value
        case "OperatingDayRef":
            event.operatingDayRef = value
        case "Code" where parent == "Attribute":
            // Un incident (`…_IncidentTrip…`, libellé « Ausfall ») ne supprime pas forcément ce
            // départ : la course peut ne sauter qu'une partie de ses arrêts. Seul `NotServicedStop`
            // sur l'arrêt affiché dit s'il est desservi. Voir `StopEvent.routeChanged`.
            event.attributeCodes = (event.attributeCodes ?? []) + [value]
        default:
            break
        }
    }
}


// MARK: - Itinéraires

/// Les itinéraires d'une réponse `OJPTripRequest`.
///
/// Le contexte (coordonnées des quais et des arrêts) précède les résultats : il est lu
/// d'abord, puis sert à placer la montée, la descente et les arrêts intermédiaires.
final class TripEventParser: OJPParser {
    private let template: TripEvent
    private(set) var trips: [TripEvent] = []
    private(set) var error: ParserError?

    private var trip: TripEvent?
    private var leg: TripLeg?
    private var intermediate: LegIntermediate?
    private var legs: [TripLeg] = []
    private var intermediates: [LegIntermediate] = []
    /// La première `Duration` après `ResultId` est celle de l'itinéraire entier.
    private var nextDurationIsTrip = false

    private var coordinates: [String: (longitude: String, latitude: String)] = [:]
    private var placeRef = ""
    private var placeLongitude = ""
    private var placeLatitude = ""

    /// `template` porte ce que la réponse ne contient pas : noms, codes et coordonnées
    /// du départ et de l'arrivée tels que choisis par l'utilisateur.
    init(template: TripEvent) {
        self.template = template
    }

    override func didStart(_ name: String) {
        switch name {
        case "TripResult":
            trip = template
        case "TripLeg":
            leg = TripLeg(id: "", legBoardStopName: "", legBoardStopId: "", legBoardQuay: "", legBoardTimetableTime: "",
                          legBoardEstimatedTime: "", legBoardLongitude: "", legBoardLatitude: "", legAlightStopName: "",
                          legAlightStopId: "", legAlightQuay: "", legAlightTimetableTime: "", legAlightEstimatedTime: "",
                          legAlightLongitude: "", legAlightLatitude: "", legIntermediates: [], legDestination: "",
                          journeyRef: "", publishedLineName: "", legDuration: "", transferDuration: "",
                          transferWalkDuration: "", transferBuffer: "", transportTypeName: "", legOperator: "")
        case "LegIntermediates":
            intermediate = LegIntermediate(id: "", stopId: "", stopName: "", longitude: "", latitude: "")
        case "Location" where isInside("TripResponseContext"):
            placeRef = ""
            placeLongitude = ""
            placeLatitude = ""
        default:
            break
        }
    }

    override func didEnd(_ name: String, parent: String, value: String) {
        if name == "ErrorText" {
            error = .noEventFound(message: value)
        }
        if isInside("TripResponseContext") {
            readContext(name, value: value)
            return
        }
        if isInside("LegIntermediates") {
            readIntermediate(name, parent: parent, value: value)
        } else {
            readStopOfLeg(name, parent: parent, value: value)
        }
        readTripAndLeg(name, value: value)
        close(name)
    }

    private func readContext(_ name: String, value: String) {
        switch name {
        case "StopPointRef" where isInside("StopPoint"), "StopPlaceRef" where isInside("StopPlace"):
            placeRef = value
        case "Longitude":
            placeLongitude = value
        case "Latitude":
            placeLatitude = value
        case "Location":
            if !placeRef.isEmpty, !placeLongitude.isEmpty, !placeLatitude.isEmpty {
                coordinates[placeRef] = (placeLongitude, placeLatitude)
            }
        default:
            break
        }
    }

    private func readIntermediate(_ name: String, parent: String, value: String) {
        switch name {
        case "Order": intermediate?.id = value
        case "StopPointRef": intermediate?.stopId = value
        case "Text" where parent == "StopPointName": intermediate?.stopName = value
        case "NotServicedStop" where value == "true": intermediate?.notServiced = true
        default: break
        }
    }

    /// Montée, descente et libellés du service.
    private func readStopOfLeg(_ name: String, parent: String, value: String) {
        let boarding = isInside("LegBoard")
        let alighting = isInside("LegAlight")
        if name == "Text" {
            switch parent {
            case "StopPointName":
                if boarding { leg?.legBoardStopName = value } else if alighting { leg?.legAlightStopName = value }
            case "PlannedQuay":
                if boarding { leg?.legBoardQuay = value } else if alighting { leg?.legAlightQuay = value }
            case "PublishedLineName": leg?.publishedLineName = value
            case "DestinationText": leg?.legDestination = value
            case "TransportTypeName": leg?.transportTypeName = value
            case "OperatorName": leg?.legOperator = value
            default: break
            }
        } else {
            switch name {
            case "TimetabledTime":
                if boarding { leg?.legBoardTimetableTime = value } else if alighting { leg?.legAlightTimetableTime = value }
            case "EstimatedTime":
                if boarding { leg?.legBoardEstimatedTime = value } else if alighting { leg?.legAlightEstimatedTime = value }
            case "StopPointRef":
                if boarding { leg?.legBoardStopId = value } else if alighting { leg?.legAlightStopId = value }
            case "DestinationStopPointRef": leg?.legDestinationRef = value
            default: break
            }
        }
    }

    private func readTripAndLeg(_ name: String, value: String) {
        switch name {
        case "ResultId":
            trip?.id = value
            nextDurationIsTrip = true
        case "Duration":
            if nextDurationIsTrip {
                nextDurationIsTrip = false
                trip?.duration = value
            }
            // Une étape à pied porte sa durée de correspondance après son mode de transfert.
            if leg?.transfer == true {
                leg?.transferDuration = value
            } else {
                leg?.legDuration = value
            }
        case "StartTime": trip?.startTime = value
        case "EndTime": trip?.endTime = value
        case "Transfers": trip?.transfers = value
        case "LegId": leg?.id = value
        case "JourneyRef": leg?.journeyRef = value
        case "OperatingDayRef": leg?.operatingDayRef = value
        case "TransferMode", "IndividualMode":
            if value == "walk" { leg?.transfer = true }
        case "Code" where isInside("Attribute") && isInside("Service"):
            let codes = leg?.attributeCodes ?? []
            leg?.attributeCodes = codes + [value]
        case "BusSubmode" where isInside("Service"):
            leg?.busSubmode = value
        case "WalkDuration": leg?.transferWalkDuration = value
        case "BufferTime": leg?.transferBuffer = value
        default: break
        }
    }

    private func close(_ name: String) {
        switch name {
        case "LegIntermediates":
            if var stop = intermediate {
                if let place = coordinates[stop.stopId] {
                    stop.longitude = place.longitude
                    stop.latitude = place.latitude
                }
                intermediates.append(stop)
                intermediate = nil
            }
        case "TripLeg":
            if var current = leg {
                if let board = coordinates[current.legBoardStopId] {
                    current.legBoardLongitude = board.longitude
                    current.legBoardLatitude = board.latitude
                }
                if let alight = coordinates[current.legAlightStopId] {
                    current.legAlightLongitude = alight.longitude
                    current.legAlightLatitude = alight.latitude
                }
                current.legIntermediates = intermediates
                legs.append(current)
            }
            leg = nil
            intermediates = []
        case "TripResult":
            if var current = trip {
                current.legs = legs
                trips.append(current)
            }
            trip = nil
            legs = []
        default:
            break
        }
    }
}

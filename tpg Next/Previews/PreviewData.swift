//
//  PreviewData.swift
//  tpg Next
//
//  Données des aperçus Xcode (`#Preview`) : de vraies réponses de l'API, lues par les
//  parseurs de l'app, dont les heures sont recalées sur l'heure courante. Un aperçu montre
//  ainsi des décomptes, des retards et des arrêts déjà desservis comme dans l'app.
//
//  Les réponses sont dans `Preview Content/` (exclu des archives) :
//  - `PreviewDepartures.xml` : départs de Genève, Rive (retards, course supprimée, quais) ;
//  - `PreviewJourney.xml`    : course de la ligne 29 avec son tracé routier ;
//  - `PreviewTrips.xml`      : itinéraires Genève, Rive → Genève, gare Cornavin.
//
//  Pour un cas précis (retard, suppression, nom long…), construire un départ avec
//  `PreviewData.departure(…)` plutôt que modifier les fichiers.
//

import SwiftUI
import MapKit
import tpgNextFunc

enum PreviewData {

    // MARK: - Arrêts

    static let rive = stop("Genève, Rive", sloid: "ch:1:sloid:87061", number: "8587061", lon: 6.15281, lat: 46.20186)
    static let cornavin = stop("Genève, gare Cornavin", sloid: "ch:1:sloid:87057", number: "8587057", lon: 6.14244, lat: 46.20973)
    static let plainpalais = stop("Genève, Plainpalais", sloid: "ch:1:sloid:87907", number: "8587907", lon: 6.14281, lat: 46.19804)
    static let belAir = stop("Genève, Bel-Air", sloid: "ch:1:sloid:87387", number: "8587387", lon: 6.14305, lat: 46.20473)
    static let eauxVives = stop("Genève, Place des Eaux-Vives", sloid: "ch:1:sloid:92883", number: "8592883", lon: 6.15601, lat: 46.20229, transport: "BUS")
    static let rondeau = stop("Carouge GE, Rondeau", sloid: "ch:1:sloid:87437", number: "8587437", lon: 6.13840, lat: 46.17986)
    static let meinier = stop("Meinier, église", sloid: "ch:1:sloid:93001", number: "8593001", lon: 6.23380, lat: 46.24652, transport: "BUS")
    static let airport = stop("Genève-Aéroport", sloid: "ch:1:sloid:1026", number: "8501026", lon: 6.11199, lat: 46.23254, transport: "TRAIN")

    /// Favoris de démonstration, dans l'ordre de la grille.
    static let favorites = [rive, cornavin, plainpalais, belAir, eauxVives, rondeau, meinier, airport]

    /// Lieux favoris : un renommé (« Maison »), deux sous leur nom de Plans.
    static let places: [FavoritePlace] = {
        var home = FavoritePlace(name: "Rue de Carouge 50", address: "1205 Genève",
                                 coordinate: CLLocationCoordinate2D(latitude: 46.19512, longitude: 6.14199))
        home.name = "Maison"
        return [
            home,
            FavoritePlace(name: "Université de Genève – Uni Mail", address: "Boulevard du Pont-d'Arve 40, 1205 Genève",
                          coordinate: CLLocationCoordinate2D(latitude: 46.19517, longitude: 6.14046)),
            FavoritePlace(name: "Bains des Pâquis", address: "Quai du Mont-Blanc 30, 1201 Genève",
                          coordinate: CLLocationCoordinate2D(latitude: 46.21087, longitude: 6.15205)),
        ]
    }()

    // MARK: - Départs (Genève, Rive)

    /// Une trentaine de départs, du plus proche au plus lointain. Le premier (G) est parti
    /// à l'horaire depuis 11 min mais attendu dans 2 min ; le 8 vers Palexpo est supprimé.
    static var departures: [StopEvent] { stopEvents.events }

    /// Les quais de Genève, Rive, avec leurs coordonnées.
    static var quays: [Quay] { stopEvents.quays }

    /// Le premier départ d'une ligne, par exemple `departure(line: "12")`.
    static func departure(line: String) -> StopEvent {
        departures.first { $0.lineName == line } ?? departures[0]
    }

    /// Un départ sur mesure, pour isoler un cas.
    /// - Parameters:
    ///   - minutes: dans combien de minutes le véhicule est attendu (négatif : déjà passé).
    ///   - delay: retard en minutes (négatif : en avance), l'horaire est décalé d'autant.
    static func departure(line: String = "12",
                          destination: String = "Genève, Moillesulaz",
                          quay: String = "B",
                          inMinutes minutes: Double = 4,
                          delay: Double = 0,
                          cancelled: Bool = false,
                          routeChanged: Bool = false,
                          quayAccess: QuayAccess? = .withoutAssistance,
                          lowFloor: Bool = true,
                          transportType: String = "Tram",
                          operatorName: String = "Transports Publics Genevois",
                          stop: Stop = rive) -> StopEvent {
        StopEvent(stopPointName: stop.name,
                  stopId: stop.sloid,
                  plannedQuay: quay,
                  timetabledTime: OJPDate.string(from: now.addingTimeInterval((minutes - delay) * 60)),
                  estimatedTime: OJPDate.string(from: now.addingTimeInterval(minutes * 60)),
                  lineName: line,
                  origin: stop.name,
                  destination: destination,
                  transportType: transportType,
                  operatorName: operatorName,
                  journeyRef: "preview-\(line)-\(destination)-\(minutes)",
                  operatingDayRef: OJPDate.string(from: now).prefix(10).description,
                  isCancelled: cancelled ? true : nil,
                  quayAccess: quayAccess,
                  attributeCodes: (lowFloor ? ["A__NF"] : []) + (routeChanged ? ["ojp9200A_R_IncidentTrip305_1"] : []),
                  ptMode: transportType.lowercased())
    }

    // MARK: - Course (ligne 29, Collonge-Bellerive → Versoix)

    /// Les arrêts de la course. Genève, Rive est desservi dans 4 min : les arrêts d'avant
    /// sont passés, le trait de la ligne est estompé jusque-là.
    static var journeyStops: [LineEvent] { journey.events }

    /// Le départ de la ligne 29 à Genève, Rive, d'où la page ligne est ouverte.
    static var lineDeparture: StopEvent {
        let rive = journeyStops.first { $0.sloid == Self.rive.sloid }
        return StopEvent(stopPointName: Self.rive.name,
                         stopId: rive?.stopPlaceRef ?? Self.rive.sloid,
                         plannedQuay: rive?.plannedQuay ?? "D",
                         timetabledTime: rive?.timetabledTime ?? OJPDate.string(from: now),
                         estimatedTime: rive?.estimatedTime ?? OJPDate.string(from: now),
                         lineName: "29",
                         origin: journeyStops.first?.stopPointName ?? "",
                         destination: journeyStops.last?.stopPointName ?? "Versoix, La Scie",
                         transportType: "Bus",
                         operatorName: journey.operatorName,
                         journeyRef: "ch:1:sjyid:100680:HAS-26-29-16-Dimanche-35283399",
                         operatingDayRef: "2026-09-13",
                         quayAccess: rive?.quayAccess,
                         attributeCodes: ["A__NF"],
                         ptMode: "bus")
    }

    /// L'arrêt courant de la page ligne.
    static var lineCurrentStop: ShortStop { ShortStop(name: rive.name, sloid: rive.sloid) }

    /// La course déjà chargée, avec son tracé : pour les cartes et panneaux qui la reçoivent.
    /// Les vues qui la chargent elles-mêmes (`LineView`) passent par `LiveDeparturePreview`.
    static func journeyModel(withTrack: Bool = true) -> JourneyTrackModel {
        let journey = journey
        return JourneyTrackModel(previewEvents: journey.events, operatorName: journey.operatorName,
                                 service: journey.service, track: withTrack ? journey.track : nil)
    }

    // MARK: - Itinéraires (Genève, Rive → Genève, gare Cornavin)

    /// Six itinéraires : à pied puis 9 ; 12, correspondance, 19 ; 29, correspondance, 8 ;
    /// à pied puis 6 ; 10 direct ; tout à pied.
    static var trips: [TripEvent] {
        let data = rebasedResponse("PreviewTrips", anchor: "2026-09-13T15:54:00Z")
        return (try? parseTripEvents(from: data, startCoordinate: rive.wgs84Coordinates, endCoordinates: cornavin.wgs84Coordinates,
                                     startName: rive.name, endName: cornavin.name, startCode: rive.sloid, endCode: cornavin.sloid,
                                     geoDeparture: false, geoArrival: false)) ?? []
    }

    /// Un itinéraire avec une correspondance : 12, marche, 19.
    static var tripWithTransfer: TripEvent { trips.first { $0.legs.count == 3 } ?? FullTripTest().Trip }

    /// Un itinéraire direct : la ligne 10.
    static var directTrip: TripEvent { trips.first { $0.legs.count == 1 && !$0.legs[0].transfer } ?? FullTripTest().Trip }

    // MARK: - Lecture des réponses

    /// L'heure de référence, arrondie à la minute : les décomptes ne tombent pas entre deux.
    static var now: Date {
        Date(timeIntervalSinceReferenceDate: (Date().timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
    }

    private static var stopEvents: (events: [StopEvent], quays: [Quay]) {
        let result = parseStopEventsSync(from: rebasedResponse("PreviewDepartures", anchor: "2026-09-17T09:28:00Z"), stopCode: rive.sloid)
        return (result.events, result.quays)
    }

    private static var journey: (events: [LineEvent], operatorName: String, service: JourneyService, track: [CLLocationCoordinate2D]) {
        let data = rebasedResponse("PreviewJourney", anchor: "2026-09-13T15:52:00Z")
        let parsed = parseJourneyEventsSync(from: data)
        return (parsed.events, parsed.operatorName.isEmpty ? "Transports Publics Genevois" : parsed.operatorName,
                parseJourneyServiceSync(from: data), parseJourneyTrack(from: data))
    }

    /// La réponse enregistrée, toutes ses heures décalées pour que `anchor` tombe maintenant.
    private static func rebasedResponse(_ name: String, anchor: String) -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "xml"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let anchorDate = OJPDate.date(from: anchor),
              let timestamp = try? Regex(#"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z"#) else {
            assertionFailure("\(name).xml manque dans Preview Content")
            return Data()
        }
        let shift = now.timeIntervalSince(anchorDate)
        let rebased = text.replacing(timestamp) { match in
            let original = String(text[match.range])
            guard let date = OJPDate.date(from: original) else { return original }
            return OJPDate.string(from: date.addingTimeInterval(shift))
        }
        return Data(rebased.utf8)
    }

    private static func stop(_ name: String, sloid: String, number: String, lon: Double, lat: Double, transport: String = "BUS|TRAM") -> Stop {
        Stop(name: name, sloid: sloid, codedidoc: number, country: "CH", canton: "Genève",
             meansOfTransport: transport, wgs84Coordinates: Coordinates(lon: lon, lat: lat))
    }
}

//
//  JourneyMap.swift
//  tpg Next
//
//  Le parcours d'une course sur une carte : chargement des arrêts et du tracé routier, et
//  contenu de carte (arrêts, segments colorés). Partagé par la carte de ligne et les panneaux
//  des pages arrêt et ligne sur grand écran.
//

import SwiftUI
import MapKit
import tpgNextFunc

/// Arrêts et tracé d'une course. Le tracé, lourd, n'est demandé qu'une fois par parcours
/// (mis en cache par `LineTrackCache`) ; les rafraîchissements suivants ne relisent que les horaires.
@Observable
final class JourneyTrackModel {
    private(set) var events: [LineEvent]
    private(set) var operatorName = ""
    /// Un segment de tracé par intervalle entre deux arrêts, `nil` tant que le tracé manque.
    private(set) var segments: [[CLLocationCoordinate2D]]?

    @ObservationIgnored private let lineManager = LineManager()
    @ObservationIgnored private var track: [CLLocationCoordinate2D]?
    @ObservationIgnored private var trackKey: String?
    /// La course affichée : une réponse arrivée pour une course précédente est ignorée.
    @ObservationIgnored private var journeyRef: String?

    init(events: [LineEvent] = []) {
        self.events = events
    }

    func load(_ stopEvent: StopEvent) {
        // Autre course : on repart de zéro. À la première course, les arrêts reçus à la
        // création (carte ouverte depuis la ligne) restent affichés en attendant la réponse.
        if let journeyRef, journeyRef != stopEvent.journeyRef {
            events = []
            operatorName = ""
            segments = nil
            track = nil
            trackKey = nil
        }
        journeyRef = stopEvent.journeyRef
        let currentKey = LineTrackCache.key(for: events)
        if let currentKey, currentKey != trackKey, let cached = LineTrackCache.load(key: currentKey) {
            applyTrack(cached, key: currentKey)
        }
        let requestTrack = currentKey == nil || currentKey != trackKey
        let requested = stopEvent.journeyRef
        lineManager.selectJourney(stopEvent, track: requestTrack) { [weak self] in
            guard let self, self.journeyRef == requested else { return }
            events = lineManager.lineEvents
            operatorName = lineManager.operatorName
            guard requestTrack, let coordinates = lineManager.track,
                  let newKey = LineTrackCache.key(for: events) else {
                updateSegments()
                return
            }
            if coordinates.count >= 2 {
                LineTrackCache.save(coordinates, key: newKey)
                applyTrack(coordinates, key: newKey)
            } else {
                applyTrack(nil, key: newKey)
            }
        }
    }

    private func applyTrack(_ coordinates: [CLLocationCoordinate2D]?, key: String) {
        track = coordinates
        trackKey = key
        updateSegments()
    }

    private func updateSegments() {
        guard let track, trackKey == LineTrackCache.key(for: events) else {
            segments = nil
            return
        }
        segments = splitTrack(track, atStops: events.map(\.coordinate))
    }
}

extension LineEvent {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: Double(latitude) ?? 0, longitude: Double(longitude) ?? 0)
    }
}

/// Arrêts et segments d'une course, à poser dans un `Map`. Les parties déjà parcourues sont estompées.
struct JourneyMapContent: MapContent {
    let events: [LineEvent]
    let segments: [[CLLocationCoordinate2D]]?
    let lineName: String
    let operatorName: String
    var currentStopSloid: String?
    let now: Date

    var body: some MapContent {
        ForEach(events, id: \.self) { event in
            let isEnd = event == events.first || event == events.last
            let splitStopName = splitString(event.stopPointName, separator: ",")
            Annotation("\(splitStopName.0)\n\(splitStopName.1)", coordinate: event.coordinate, anchor: .center) {
                StopIcon(color: LineColors.lineColor(for: lineName, operatorName: operatorName, inverted: true),
                         currentStop: event.sloid == currentStopSloid && event.sloid != "",
                         size: isEnd ? 18 : 12)
                    .opacity(hasPassed(event.departureDate, includingCurrentMinute: false, now: now) ? 0.4 : 1)
            }
        }

        ForEach(mapSegments) { segment in
            MapPolyline(coordinates: segment.coordinates)
                .stroke(LineColors.lineColor(for: lineName, operatorName: operatorName).opacity(segment.passed ? 0.4 : 1),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
    }

    private struct MapSegment: Identifiable {
        let id: String
        let coordinates: [CLLocationCoordinate2D]
        let passed: Bool
    }

    /// Le tracé routier quand il correspond aux arrêts, des lignes droites sinon.
    private var mapSegments: [MapSegment] {
        guard events.count >= 2 else { return [] }
        let routed = segments?.count == events.count - 1 ? segments : nil
        let source = routed == nil ? "straight" : "track"
        return (0..<(events.count - 1)).compactMap { index in
            let coordinates = routed?[index] ?? [events[index].coordinate, events[index + 1].coordinate]
            guard coordinates.count >= 2 else { return nil }
            return MapSegment(id: "\(source)-\(index)", coordinates: coordinates,
                              passed: hasPassed(events[index].departureDate, includingCurrentMinute: false, now: now))
        }
    }
}

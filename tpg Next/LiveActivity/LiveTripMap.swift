//
//  LiveTripMap.swift
//  tpg Next
//
//  La carte du trajet suivi : ce qui est parcouru, ce qui reste, et où l'on en est.
//

import SwiftUI
import MapKit
import tpgNextFunc

/// Le trajet suivi sur une carte, comme la carte d'un itinéraire, mais en mouvement : ce qui est
/// déjà parcouru est grisé, le véhicule en cours est coupé là où il devrait être, et un repère
/// dit où l'on en est. La position du téléphone s'y ajoute.
///
/// Les heures du tracé (`TripRoute`) sont celles d'OJP : la correction par la position
/// (`TripActivityState.positionOffset`) s'y applique pour placer le véhicule.
struct LiveTripMap: View {
    let state: TripActivityState
    let links: LiveTripLinks?
    let route: TripRoute?
    /// Dans la page du trajet : petite, sans geste ni bouton, cadrée sur ce qui reste à faire.
    var compact = false

    var body: some View {
        // Le véhicule avance à la seconde, d'après ses heures de passage : il glisse le long du
        // tracé au lieu de sauter d'une mise à jour à l'autre.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            LiveTripMapContent(state: state, links: links, route: route, compact: compact, now: AppClock.shifted(context.date))
        }
    }
}

/// La carte à un instant donné.
private struct LiveTripMapContent: View {
    let state: TripActivityState
    let links: LiveTripLinks?
    let route: TripRoute?
    let compact: Bool
    let now: Date

    @State private var position: MapCameraPosition = .automatic
    /// Le tracé réel de chaque véhicule, par index d'étape, quand il est connu.
    @State private var tracks: [Int: [CLLocationCoordinate2D]] = [:]

    var body: some View {
        let segments = segments
        let here = currentPosition
        let hereStop = currentStopID
        Map(position: $position, interactionModes: compact ? [] : .all) {
            ForEach(segments) { segment in
                if segment.walking {
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(segment.done ? Color(uiColor: .systemGray3) : Color.gray,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 5]))
                } else {
                    // Le parcouru en gris opaque : semi-transparent, il foncissait là où deux bouts
                    // se rejoignent.
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(segment.done ? Color(uiColor: .systemGray3) : segment.color,
                                style: StrokeStyle(lineWidth: segment.done ? 3 : 4, lineCap: .round, lineJoin: .round))
                }
            }
            ForEach(stops) { stop in
                Annotation(compact ? "" : stop.name, coordinate: stop.coordinate, anchor: .center) {
                    // À l'arrêt, c'est l'arrêt lui-même qui dit où l'on en est : un repère posé
                    // dessus passerait dessous.
                    if stop.id == hereStop {
                        hereMarker
                    } else if stop.isDestination {
                        Image(systemName: "flag.checkered")
                            .font(.caption.bold())
                            .padding(5)
                            .background(Circle().fill(.background))
                            .overlay(Circle().strokeBorder(Color.primary, lineWidth: 2))
                    } else {
                        StopIcon(color: stop.color, terminus: stop.isEnd, size: stop.isEnd ? 15 : 9)
                            .opacity(stop.past ? 0.45 : 1)
                    }
                }
                .annotationTitles(stop.isEnd ? .automatic : .hidden)
            }
            if hereStop == nil, let here {
                Annotation("", coordinate: here, anchor: .center) {
                    hereMarker
                }
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            if !compact {
                MapUserLocationButton()
                MapCompass()
            }
        }
        .onAppear {
            position = camera(around: segments, here: here)
            loadTracks()
        }
        // Le tracé arrive après coup (passages des courses, tracé réel) : la petite carte se
        // recadre ; la grande ne bouge plus une fois que le voyageur l'a en main.
        .onChange(of: frameSignature) {
            if compact { position = camera(around: self.segments, here: currentPosition) }
        }
    }

    /// Où l'on en est, avec un halo qui respire.
    private var hereMarker: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 18, height: 18)
            .background { PulsingHalo(spread: 2.2) }
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(radius: 2)
            .accessibilityLabel(Text("Où vous en êtes"))
    }

    // MARK: Les tracés

    private struct Segment: Identifiable {
        let id: String
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
        let walking: Bool
        let done: Bool
    }

    /// L'heure à laquelle le tracé est coupé : arrondie à 5 s. Une ligne coupée ailleurs est une
    /// autre ligne pour MapKit (voir `segments`) : la recouper à chaque seconde la redessinerait
    /// sans cesse, pour un écart qui ne se voit pas.
    private var cutTime: Date {
        Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 5).rounded(.down) * 5)
    }

    /// Les véhicules, coupés à la position du véhicule en cours, et les marches entre eux.
    /// MapKit ne redessine pas une ligne dont seules les coordonnées changent : l'id porte la
    /// source du tracé et le point de coupe.
    private var segments: [Segment] {
        var result: [Segment] = []
        let phase = state.phase(at: now)
        for (index, leg) in state.legs.enumerated() {
            let line = path(of: index)
            guard line.count >= 2 else { continue }
            let color = LineColors.lineColor(for: leg.line, operatorName: leg.operatorName)
            let source = tracks[index] != nil ? "track" : "\(line.count)"
            if phase == .riding(leg: index), let vehicle = vehiclePosition(of: index, at: cutTime) {
                let (done, remaining) = TripRoute.split(line, at: vehicle)
                let cut = String(format: "%.5f,%.5f", vehicle.latitude, vehicle.longitude)
                if done.count >= 2 {
                    result.append(Segment(id: "\(index)-done-\(source)-\(cut)", coordinates: done, color: color,
                                          walking: false, done: true))
                }
                if remaining.count >= 2 {
                    result.append(Segment(id: "\(index)-next-\(source)-\(cut)", coordinates: remaining, color: color,
                                          walking: false, done: false))
                }
            } else {
                let done = leg.alight <= now
                result.append(Segment(id: "\(index)-\(source)-\(done)", coordinates: line, color: color,
                                      walking: false, done: done))
            }
        }
        // Les marches : jusqu'à la première montée, entre deux véhicules, puis jusqu'à l'arrivée.
        for (index, walk) in walks.enumerated() {
            result.append(Segment(id: "walk-\(index)-\(walk.done)", coordinates: [walk.from, walk.to], color: .gray,
                                  walking: true, done: walk.done))
        }
        return result
    }

    private var walks: [(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, done: Bool)] {
        guard let links, links.legs.count == state.legs.count else { return [] }
        var result: [(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, done: Bool)] = []
        func add(_ from: Coordinates?, _ to: Coordinates?, done: Bool) {
            guard let from, let to else { return }
            let start = from.toCLLocationCoordinate2D
            let end = to.toCLLocationCoordinate2D
            // Le départ est souvent l'arrêt même de la montée : rien à tracer.
            guard CLLocation(latitude: start.latitude, longitude: start.longitude)
                .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude)) > 30 else { return }
            result.append((start, end, done))
        }
        add(links.originCoordinates, links.legs.first?.boardCoordinates, done: (state.legs.first?.board ?? now) <= now)
        for index in links.legs.indices.dropLast() {
            add(links.legs[index].alightCoordinates, links.legs[index + 1].boardCoordinates,
                done: state.legs[index + 1].board <= now)
        }
        add(links.legs.last?.alightCoordinates, links.destinationCoordinates, done: state.arrival <= now)
        return result
    }

    /// Le parcours d'un véhicule : son tracé réel, sinon ses arrêts, sinon la ligne droite de la
    /// montée à la descente.
    private func path(of index: Int) -> [CLLocationCoordinate2D] {
        if let track = tracks[index], track.count >= 2 { return track }
        let points = route?.points(of: index) ?? []
        if points.count >= 2 {
            return points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        guard let leg = link(index), let board = leg.boardCoordinates, let alight = leg.alightCoordinates else { return [] }
        return [board.toCLLocationCoordinate2D, alight.toCLLocationCoordinate2D]
    }

    private func link(_ index: Int) -> LiveTripLinks.Leg? {
        guard let links, links.legs.count == state.legs.count, links.legs.indices.contains(index) else { return nil }
        return links.legs[index]
    }

    /// Où le véhicule devrait être, d'après ses heures de passage et la correction par la position.
    private func vehiclePosition(of index: Int, at now: Date) -> CLLocationCoordinate2D? {
        let points = route?.points(of: index) ?? []
        if points.count >= 2 {
            let reference = now.addingTimeInterval(-TimeInterval(state.positionOffset ?? 0))
            return TripRoute.expectedPosition(on: points, at: reference)
        }
        guard let leg = link(index), let board = leg.boardCoordinates, let alight = leg.alightCoordinates else { return nil }
        let times = state.legs[index]
        return TripRoute.expectedPosition(on: [
            .init(latitude: board.lat, longitude: board.lon, time: times.board),
            .init(latitude: alight.lat, longitude: alight.lon, time: times.alight),
        ], at: now)
    }

    /// Où l'on en est : dans le véhicule, à l'arrêt où l'on attend, ou arrivé.
    private var currentPosition: CLLocationCoordinate2D? {
        switch state.phase(at: now) {
        case .riding(let index):
            return vehiclePosition(of: index, at: now)
        case .waiting(let index):
            // En route vers le premier arrêt, on n'est pas encore à l'arrêt : seule la position
            // du téléphone le dit.
            if index == 0, state.isWalking(at: now) { return nil }
            return link(index)?.boardCoordinates?.toCLLocationCoordinate2D
        case .arrived:
            return (links?.destinationCoordinates ?? links?.legs.last?.alightCoordinates)?.toCLLocationCoordinate2D
        }
    }

    /// L'arrêt où l'on se trouve : celui où l'on attend, ou l'arrivée. `nil` en route.
    private var currentStopID: String? {
        switch state.phase(at: now) {
        case .riding:
            return nil
        case .waiting(let index):
            if index == 0, state.isWalking(at: now) { return nil }
            return "\(index)-board"
        case .arrived:
            return stops.contains { $0.isDestination } ? "destination" : "\(state.legs.count - 1)-alight"
        }
    }

    // MARK: Les arrêts

    private struct MapStop: Identifiable {
        let id: String
        let name: String
        let coordinate: CLLocationCoordinate2D
        let color: Color
        let isEnd: Bool
        let isDestination: Bool
        let past: Bool
    }

    /// Montée et descente de chaque véhicule, ses arrêts entre les deux, et l'arrivée.
    private var stops: [MapStop] {
        var result: [MapStop] = []
        for (index, leg) in state.legs.enumerated() {
            let color = LineColors.lineColor(for: leg.line, operatorName: leg.operatorName, inverted: true)
            let points = route?.points(of: index) ?? []
            for (offset, point) in points.enumerated() where offset > 0 && offset < points.count - 1 {
                result.append(MapStop(id: "\(index)-\(offset)", name: "",
                                      coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                                      color: color, isEnd: false, isDestination: false, past: point.time < now))
            }
            if let board = link(index)?.boardCoordinates ?? points.first.map({ Coordinates(lon: $0.longitude, lat: $0.latitude) }) {
                result.append(MapStop(id: "\(index)-board", name: shortStopName(leg.boardName),
                                      coordinate: board.toCLLocationCoordinate2D, color: color, isEnd: true,
                                      isDestination: false, past: leg.board < now))
            }
            if let alight = link(index)?.alightCoordinates ?? (points.count >= 2 ? points.last : nil).map({ Coordinates(lon: $0.longitude, lat: $0.latitude) }) {
                result.append(MapStop(id: "\(index)-alight", name: shortStopName(leg.alightName),
                                      coordinate: alight.toCLLocationCoordinate2D, color: color, isEnd: true,
                                      isDestination: false, past: leg.alight < now))
            }
        }
        // L'arrivée, quand elle n'est pas la dernière descente.
        if let destination = links?.destinationCoordinates, let last = link(state.legs.count - 1)?.alightCoordinates,
           CLLocation(latitude: destination.lat, longitude: destination.lon)
            .distance(from: CLLocation(latitude: last.lat, longitude: last.lon)) > 30 {
            result.append(MapStop(id: "destination", name: "", coordinate: destination.toCLLocationCoordinate2D,
                                  color: .white, isEnd: true, isDestination: true, past: state.arrival < now))
        }
        return result
    }

    // MARK: Le cadrage

    /// Change quand le tracé change de nature : c'est là que la petite carte se recadre.
    private var frameSignature: String {
        state.legs.indices.map { "\(path(of: $0).count)" }.joined(separator: "-") + "\(state.phase(at: now))"
    }

    /// Ce qui reste à faire, et où l'on en est ; tout le trajet une fois arrivé.
    private func camera(around segments: [Segment], here: CLLocationCoordinate2D?) -> MapCameraPosition {
        let ahead = segments.filter { !$0.done }.flatMap(\.coordinates) + (here.map { [$0] } ?? [])
        let coordinates = (ahead.count >= 2 ? ahead : segments.flatMap(\.coordinates))
            .filter { $0.latitude != 0 || $0.longitude != 0 }
        guard let first = coordinates.first else { return .automatic }
        let rect = coordinates.dropFirst().reduce(MKMapRect(origin: MKMapPoint(first), size: MKMapSize())) { rect, coordinate in
            rect.union(MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize()))
        }
        // De l'air pour les noms d'arrêts et les boutons de la carte.
        let margin = max(rect.width, rect.height) * (compact ? 0.15 : 0.25) + 250
        return .rect(rect.insetBy(dx: -margin, dy: -margin))
    }

    /// Le tracé réel des véhicules d'un itinéraire : en cache, sinon demandé une fois.
    private func loadTracks() {
        for (index, leg) in (links?.legs ?? []).enumerated() where tracks[index] == nil {
            guard let tripLeg = leg.tripLeg else { continue }
            if let key = tripLeg.trackCacheKey, let cached = LineTrackCache.load(key: key) {
                tracks[index] = cached
            } else {
                fetchLegTrack(for: tripLeg) { track in
                    if let track, track.count >= 2 { tracks[index] = track }
                }
            }
        }
    }
}

/// La carte du trajet suivi, en grand.
struct LiveTripMapPage: View {
    let key: String
    var previewTrip: TripLiveActivities.LiveTrip?
    var previewLinks: LiveTripLinks?
    var previewRoute: TripRoute?
    private var liveActivities = TripLiveActivities.shared

    init(key: String, previewTrip: TripLiveActivities.LiveTrip? = nil, previewLinks: LiveTripLinks? = nil,
         previewRoute: TripRoute? = nil) {
        self.key = key
        self.previewTrip = previewTrip
        self.previewLinks = previewLinks
        self.previewRoute = previewRoute
    }

    var body: some View {
        Group {
            if let trip = liveActivities.live[key] ?? previewTrip {
                LiveTripMap(state: trip.state, links: liveActivities.links(for: key) ?? previewLinks,
                            route: liveActivities.route(for: key) ?? previewRoute)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                ContentUnavailableView("Ce trajet n'est plus suivi", systemImage: "inset.filled.circle.slash")
            }
        }
        .navigationTitle("Carte du trajet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

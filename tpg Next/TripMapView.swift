//
//  TripMapView.swift
//  tpg Next
//
//  Created by Loris Thomas on 12.08.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc

/// Ce que la carte d'un trajet doit cadrer : un arrêt, une étape ou une correspondance.
struct TripMapFocus: Equatable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]

    static func == (lhs: TripMapFocus, rhs: TripMapFocus) -> Bool { lhs.id == rhs.id }
}

struct TripMapView: View {
    var tripEvent: TripEvent
    var isPreview: Bool = false
    /// Partie du trajet à cadrer ; `nil` = le trajet entier.
    var focus: TripMapFocus? = nil
    @State private var position: MapCameraPosition = .automatic
    @Environment(\.paneTopInset) private var topInset
    
    @State private var polylines: [Int : MKPolyline] = [:]
    /// Tracé réel des étapes en transport, par index d'étape.
    @State private var legTracks: [Int : [CLLocationCoordinate2D]] = [:]
    
    var body: some View {
            ZStack {
                Map(position: $position) {
                    ForEach(polylines.keys.sorted(), id: \.self) { key in
                        if let polyline = polylines[key] {
                            if tripEvent.legs[key].transfer {
                                MapPolyline(polyline)
                                    .stroke(.gray, style: StrokeStyle(lineWidth: 1, dash: [5]))
                            } else {
                                MapPolyline(polyline)
                                    .stroke(LineColors.lineColor(for: tripEvent.legs[key].publishedLineName, operatorName: tripEvent.legs[key].legOperator), lineWidth: 3)
                            }
                        }
                    }
                    
                    ForEach(transitSegments) { segment in
                        MapPolyline(coordinates: segment.coordinates)
                            .stroke(segment.color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }

                    ForEach(tripEvent.legs.indices, id: \.self) { index in
                        let leg = tripEvent.legs[index]
                        let lineColorInverted = LineColors.lineColor(for: leg.publishedLineName, operatorName: leg.legOperator, inverted: true)
                        
                        if leg.transfer {
                            if index == 0 {
                                let splitStopName = splitString(tripEvent.startName, separator: ",")
                                
                                Annotation("\(splitStopName.0)\n\(splitStopName.1)", coordinate: tripEvent.startCoordinates.toCLLocationCoordinate2D, anchor: .center) {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 3)
                                        .background(
                                            Circle()
                                                .fill(lineColorInverted)
                                        )
                                        .frame(width: 15, height: 15)
                                }
                                
                            } else if index == tripEvent.legs.count - 1 {
                                let splitStopName = splitString(tripEvent.endName, separator: ",")
                                Annotation("\(splitStopName.0)\n\(splitStopName.1)", coordinate: tripEvent.endCoordinates.toCLLocationCoordinate2D, anchor: .center) {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 3)
                                        .background(
                                            Circle()
                                                .fill(lineColorInverted)
                                        )
                                        .frame(width: 15, height: 15)
                                }
                            }
                        } else if !leg.transfer {
                            let splitBoardStopName = splitString(leg.legBoardStopName, separator: ",")
                            
                            Annotation("\(splitBoardStopName.0)\n\(splitBoardStopName.1)", coordinate: CLLocationCoordinate2D(latitude: Double(leg.legBoardLatitude) ?? 0.0, longitude: Double(leg.legBoardLongitude) ?? 0.0)) {
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: 3)
                                    .background(
                                        Circle()
                                            .fill(lineColorInverted)
                                    )
                                    .frame(width: 15, height: 15)
                            }
                            
                            
                            if !isPreview {
                                ForEach(leg.legIntermediates.indices, id: \.self) { index in
                                    let intermediate = leg.legIntermediates[index]
                                    Annotation(intermediate.stopName, coordinate: CLLocationCoordinate2D(latitude: Double(intermediate.latitude) ?? 0.0, longitude: Double(intermediate.longitude) ?? 0.0), anchor: .center) {
                                        Circle()
                                            .strokeBorder(Color.primary, lineWidth: 3)
                                            .background(
                                                Circle()
                                                    .fill(lineColorInverted)
                                            )
                                            .frame(width: 12, height: 12)
                                    }
                                }
                            }
                            
                            let splitArrivalStopName = splitString(leg.legAlightStopName, separator: ",")
                            
                            Annotation("\(splitArrivalStopName.0)\n\(splitArrivalStopName.1)", coordinate: CLLocationCoordinate2D(latitude: Double(leg.legAlightLatitude) ?? 0.0, longitude: Double(leg.legAlightLongitude) ?? 0.0)) {
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: 3)
                                    .background(
                                        Circle()
                                            .fill(lineColorInverted)
                                            .overlay {
                                                Circle()
                                                    .fill(Color.primary)
                                                    .frame(width: 4, height: 4)
                                            }
                                    )
                                    .frame(width: 15, height: 15)
                            }
                        }
                    }
                    if !isPreview {
                        UserAnnotation()
                    }
                }
                .safeAreaPadding(.top, topInset)
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .onAppear {
                    position = cameraPosition(for: focus)
                    calculateRoutes()
                    loadLegTracks()
                }
                .onChange(of: focus) {
                    withAnimation { position = cameraPosition(for: focus) }
                }
                .mapControls {
                    if !isPreview {
                        MapUserLocationButton()
                        MapCompass()
                    }
                }
//                if !isPreview {
//                    VStack {
//                        HStack {
//                            Button(action: {
//                                withAnimation(.easeInOut(duration: 0.4)) {
//                                    path.pop()
//                                }
//                            }) {
//                                HStack {
//                                    Image(systemName: "chevron.backward")
//                                    Text("Trajet détaillé")
//                                }
//                                .padding(.vertical, 10)
//                                .padding(.horizontal)
//                                .background(RoundedRectangle(cornerRadius: 8)
//                                    .foregroundStyle(.thickMaterial)
//                                    .shadow(color: .customShadows.opacity(0.25), radius: 3)
//                                )
//                            }
//                            .padding(.horizontal)
//                            .offset(y: 5)
//                            Spacer()
//                        }
//                        Spacer()
//                    }
//                }
            }
//            .toolbar(.hidden, for: .navigationBar)
    }
    
    /// Le cadrage automatique de MapKit ne tient compte que des annotations visibles au premier
    /// affichage : le trajet est cadré explicitement, arrêts intermédiaires compris.
    private func cameraPosition(for focus: TripMapFocus?) -> MapCameraPosition {
        let coordinates = (focus?.coordinates ?? tripEvent.mapCoordinates)
            .filter { $0.latitude != 0 && $0.longitude != 0 }
        guard let first = coordinates.first else { return .automatic }
        if coordinates.count == 1 {
            return .region(MKCoordinateRegion(center: first, latitudinalMeters: 400, longitudinalMeters: 400))
        }
        let rect = coordinates.dropFirst().reduce(MKMapRect(origin: MKMapPoint(first), size: MKMapSize())) { rect, coordinate in
            rect.union(MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize()))
        }
        // Marge pour les noms d'arrêts et les boutons de la carte.
        let margin = max(rect.width, rect.height) * 0.25 + 300
        return .rect(rect.insetBy(dx: -margin, dy: -margin))
    }

    /// MapKit ne redessine pas une MapPolyline dont seules les coordonnées changent : l'id porte
    /// donc la source de la géométrie, pour que la ligne droite soit remplacée par le tracé.
    private struct MapSegment: Identifiable {
        let id: String
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    private var transitSegments: [MapSegment] {
        tripEvent.legs.indices.compactMap { index -> MapSegment? in
            let leg = tripEvent.legs[index]
            guard !leg.transfer else { return nil }
            let color = LineColors.lineColor(for: leg.publishedLineName, operatorName: leg.legOperator)
            if let track = legTracks[index] {
                return MapSegment(id: "\(index)-track", coordinates: track, color: color)
            }
            let stops = leg.trackStops.filter { $0.latitude != 0 && $0.longitude != 0 }
            guard stops.count >= 2 else { return nil }
            return MapSegment(id: "\(index)-straight", coordinates: stops, color: color)
        }
    }

    func loadLegTracks() {
        for index in tripEvent.legs.indices where !tripEvent.legs[index].transfer && legTracks[index] == nil {
            let leg = tripEvent.legs[index]
            if let key = leg.trackCacheKey, let cached = LineTrackCache.load(key: key) {
                legTracks[index] = cached
            } else if !isPreview {
                // L'aperçu du menu contextuel ne dure que quelques secondes : cache uniquement.
                fetchLegTrack(for: leg) { track in
                    if let track {
                        legTracks[index] = track
                    }
                }
            }
        }
    }

    func calculateRoutes() {
        polylines.removeAll()
        
        for index in tripEvent.legs.indices {
            let leg = tripEvent.legs[index]
                if leg.transfer {//Calculate itinerary for walking legs
                                    if index == 0 {
                                        if tripEvent.legs.count - 1 == 0 { //if only one leg and walking in trip (Startpoint -> Endpoint)
                                            calculateRoute(from: tripEvent.startCoordinates.toCLLocationCoordinate2D, to: tripEvent.endCoordinates.toCLLocationCoordinate2D, index: index, transportType: .walking)
                                            
                                        } else { //Starting walking leg (Startpoint -> first stop)
                                            calculateRoute(from: tripEvent.startCoordinates.toCLLocationCoordinate2D, to: CLLocationCoordinate2D(latitude: Double(tripEvent.legs[index+1].legBoardLatitude) ?? 0.0, longitude: Double(tripEvent.legs[index+1].legBoardLongitude) ?? 0.0), index: index, transportType: .walking)
                                        }
                                    } else if index == tripEvent.legs.count - 1 { //Finishing walking leg (Last stop to Endpoint)
                                        calculateRoute(from: CLLocationCoordinate2D(latitude: Double(tripEvent.legs[index-1].legAlightLatitude) ?? 0.0, longitude: Double(tripEvent.legs[index-1].legAlightLongitude) ?? 0.0), to: tripEvent.endCoordinates.toCLLocationCoordinate2D, index: index, transportType: .walking)
                                        
                                    } else { //Default walking leg (stop -> stop)
                                        calculateRoute(from: CLLocationCoordinate2D(latitude: Double(tripEvent.legs[index-1].legAlightLatitude) ?? 0.0, longitude: Double(tripEvent.legs[index-1].legAlightLongitude) ?? 0.0), to: CLLocationCoordinate2D(latitude: Double(tripEvent.legs[index+1].legBoardLatitude) ?? 0.0, longitude: Double(tripEvent.legs[index+1].legBoardLongitude) ?? 0.0), index: index, transportType: .walking)

                                    }
                                    
            } 
        }
    }
    
    func calculateRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, index: Int, transportType: MKDirectionsTransportType) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = transportType
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else {
                Log.ui.error("Itinéraire à pied indisponible : \(String(describing: error))")
                return
            }
            
            // Ensure the update to the polylines dictionary is done on the main thread
            DispatchQueue.main.async {
                polylines[index] = route.polyline
            }
        }
    }

}

#Preview("Carte du trajet") {
    TripMapView(tripEvent: PreviewData.tripWithTransfer)
        .previewEnvironment()
}

#Preview("Carte du trajet — aperçu de menu", traits: .fixedLayout(width: 390, height: 300)) {
    TripMapView(tripEvent: PreviewData.tripWithTransfer, isPreview: true)
        .previewEnvironment(navigation: false)
}

extension TripEvent {
    /// Tous les points du trajet : départ, arrêts de chaque étape, arrivée.
    var mapCoordinates: [CLLocationCoordinate2D] {
        [startCoordinates.toCLLocationCoordinate2D]
            + legs.indices.flatMap { mapCoordinates(forLeg: $0) }
            + [endCoordinates.toCLLocationCoordinate2D]
    }

    /// Les points d'une étape : ses arrêts en transport, ses deux bouts à pied.
    func mapCoordinates(forLeg index: Int) -> [CLLocationCoordinate2D] {
        let leg = legs[index]
        guard leg.transfer || leg.publishedLineName.isEmpty else { return leg.trackStops }
        let from = index > 0 ? legs[index - 1].alightCoordinate : startCoordinates.toCLLocationCoordinate2D
        let to = index < legs.count - 1 ? legs[index + 1].boardCoordinate : endCoordinates.toCLLocationCoordinate2D
        return [from, to]
    }
}

extension TripLeg {
    var boardCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: Double(legBoardLatitude) ?? 0, longitude: Double(legBoardLongitude) ?? 0)
    }

    var alightCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: Double(legAlightLatitude) ?? 0, longitude: Double(legAlightLongitude) ?? 0)
    }
}

//
//  LineMapView.swift
//  tpg Next
//
//  Created by Loris Thomas on 11.08.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc
import Combine

struct LineMapView: View {
    @EnvironmentObject var appRequirementsClass: AppRequirementsClass
    @EnvironmentObject var stopStore: StopStore
    @StateObject private var lineManager = LineManager()
    @State var autoRefresh = true
    @State private var timer: AnyCancellable?
    @State var lineEvents: [LineEvent]
    var lineName: String
    var operatorName: String
    var destination: String
    var stopEvent: StopEvent
    var currentStopSloid: String?
    @State private var polylines: [Int : MKPolyline] = [:]
    @State private var track: [CLLocationCoordinate2D]?
    /// Parcours auquel `track` correspond, ou pour lequel l'API n'a pas de tracé (`track == nil`).
    @State private var trackKey: String?
    @State private var trackSegments: [[CLLocationCoordinate2D]]?

    @State private var selectedResult: String?

    var body: some View {
            GeometryReader { geometry in
                
                ZStack {
                    Map(selection: $selectedResult) {
                        ForEach(lineEvents, id: \.self) { event in
                            if event == lineEvents.first || event == lineEvents.last {
                                let splitStopName = splitString(event.stopPointName, separator: ",")
                                Annotation("\(splitStopName.0)\n\(splitStopName.1)", coordinate: CLLocationCoordinate2D(latitude: Double(event.latitude) ?? 0.0, longitude: Double(event.longitude) ?? 0.0), anchor: .center) {
                                    StopIcon(color: LineColors.lineColor(for: lineName, operatorName: operatorName, inverted: true), currentStop: event.sloid == currentStopSloid && event.sloid != "")
                                        .opacity(dateStringHasPassed(with: event.estimatedTime, equalReturnsTrue: false) ? 0.4 : 1)
                                }
                            } else {
                                let splitStopName = splitString(event.stopPointName, separator: ",")
                                Annotation("\(splitStopName.0)\n\(splitStopName.1)", coordinate: CLLocationCoordinate2D(latitude: Double(event.latitude) ?? 0.0, longitude: Double(event.longitude) ?? 0.0), anchor: .center) {
                                    StopIcon(color: LineColors.lineColor(for: lineName, operatorName: operatorName, inverted: true), currentStop: event.sloid == currentStopSloid && event.sloid != "", size: 12)
                                        .opacity(dateStringHasPassed(with: event.estimatedTime, equalReturnsTrue: false) ? 0.4 : 1)
                                }
                            }
                        }
                        
                        ForEach(mapSegments) { segment in
                            MapPolyline(coordinates: segment.coordinates)
                                .stroke(LineColors.lineColor(for: lineName, operatorName: operatorName).opacity(segment.passed ? 0.4 : 1), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .mapControls {
                        MapUserLocationButton()
                    }
//                    .mapControlVisibility(.hidden)
                    VStack {
                        BackdropBlurView(radius: 5)
                            .frame(height: 50)
                            .mask {
                                Rectangle()
                                    .overlay(alignment: .top) {
                                        ScrollMask(leading: true, vertical: true, gradientLength: 100)
                                    }
                            }
                            .ignoresSafeArea()
                        Spacer()
                    }
                    VStack {
                        HStack {
                            if #available(iOS 26, *) {
                                HStack {
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(width: 50, height: 1)
                                    LineViewTitle(destination: destination, currentLine: lineName, operatorName: operatorName)
                                        .foregroundStyle(Color.text)
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(maxWidth: 50, maxHeight: 1)
                                }
                                .padding(10)
                                .glassEffect()
                                .offset(x: -50, y: 0)
                                
                            } else {
                                HStack {
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(width: 50, height: 1)
                                    LineViewTitle(destination: destination, currentLine: lineName, operatorName: operatorName)
                                    Rectangle()
                                        .fill(.clear)
                                    //                                        .frame(width: 50, height: 1)
                                        .frame(maxWidth: 50, maxHeight: 1)
                                }
                                .padding(10)
                                .background {
                                    Capsule()
                                    //                                        .frame(width: geometry.size.width-100, height: 90)
                                        .foregroundStyle(.thinMaterial)
                                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                    //                                        .padding(.trailing, 200)
                                }
                                .offset(x: 0)
                            }
                            Spacer()
                        }
                        Spacer()
                        if let selectedResult, let stop = stopStore.findStop(id: selectedResult) {
                            SmallStopView(stop: stop, testing: !autoRefresh)
                                .frame(height: geometry.size.height / 3 + 10)
                                .transition(.slide)
                                .animation(.easeInOut(duration: 0.8), value: selectedResult)
                                .layoutPriority(1)
                        }
                        Rectangle()
                            .foregroundStyle(.clear)
                            .frame(height: 75)
                    }
                }
                .toolbar(appRequirementsClass.version26 ? .automatic : .hidden, for: .navigationBar)
//                .navigationTitle() // Set back button text
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("") // Visible title
                    }
                }
                .onAppear {
                    getLineEvents(for: stopEvent)
                    if autoRefresh {
                        timer = Timer.publish(every: 30, on: .main, in: .common)
                            .autoconnect()
                            .sink { _ in
                                getLineEvents(for: stopEvent)
                            }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    if autoRefresh {
                        getLineEvents(for: stopEvent)
                        timer = Timer.publish(every: 30, on: .main, in: .common)
                            .autoconnect()
                            .sink { _ in
                                getLineEvents(for: stopEvent)
                            }
                    }
                }
                .onDisappear {
                    timer?.cancel()
                }
                .onChange(of: lineEvents) {
                    updateTrackSegments()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    timer?.cancel()
                }
                .onChange(of: autoRefresh) {
                    if !autoRefresh {
                        timer?.cancel()
                    } else {
                        getLineEvents(for: stopEvent)
                        timer = Timer.publish(every: 30, on: .main, in: .common)
                            .autoconnect()
                            .sink { _ in
                                getLineEvents(for: stopEvent)
                            }
                    }
                }
            }
    }
    
    func getLineEvents(for stopEvent: StopEvent) {
        let currentKey = LineTrackCache.key(for: lineEvents)
        if let currentKey, currentKey != trackKey, let cached = LineTrackCache.load(key: currentKey) {
            applyTrack(cached, key: currentKey)
        }
        // Le tracé ne change pas pendant la course : on ne le demande qu'une fois par parcours,
        // les rafraîchissements suivants restent légers.
        let requestTrack = currentKey == nil || currentKey != trackKey
        lineManager.selectJourney(stopEvent, track: requestTrack) {
//            operatorName = self.lineManager.operatorName
//            lineColor = LineColors.lineColor(for: currentLine, operatorName: operatorName)
            lineEvents = self.lineManager.lineEvents
            guard requestTrack, let coordinates = lineManager.track,
                  let newKey = LineTrackCache.key(for: lineEvents) else { return }
            if coordinates.count >= 2 {
                LineTrackCache.save(coordinates, key: newKey)
                applyTrack(coordinates, key: newKey)
            } else {
                // Pas de tracé pour ce parcours : lignes droites, sans redemander toutes les 30 s.
                applyTrack(nil, key: newKey)
            }
        }
    }

    /// MapKit ne redessine pas une MapPolyline dont seules les coordonnées changent : l'id porte
    /// donc la source de la géométrie, pour que les lignes droites soient remplacées par le tracé.
    private struct MapSegment: Identifiable {
        let id: String
        let coordinates: [CLLocationCoordinate2D]
        let passed: Bool
    }

    private var mapSegments: [MapSegment] {
        guard lineEvents.count >= 2 else { return [] }
        let segments = trackSegments?.count == lineEvents.count - 1 ? trackSegments : nil
        let source = segments == nil ? "straight" : (trackKey ?? "track")
        return (0..<(lineEvents.count - 1)).compactMap { index in
            let coordinates = segments?[index] ?? [coordinate(of: lineEvents[index]), coordinate(of: lineEvents[index + 1])]
            guard coordinates.count >= 2 else { return nil }
            return MapSegment(id: "\(source)-\(index)", coordinates: coordinates, passed: dateStringHasPassed(with: lineEvents[index].estimatedTime, equalReturnsTrue: false))
        }
    }

    private func coordinate(of event: LineEvent) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: Double(event.latitude) ?? 0, longitude: Double(event.longitude) ?? 0)
    }

    func applyTrack(_ coordinates: [CLLocationCoordinate2D]?, key: String) {
        track = coordinates
        trackKey = key
        updateTrackSegments()
    }

    func updateTrackSegments() {
        guard let track, trackKey == LineTrackCache.key(for: lineEvents) else {
            trackSegments = nil
            return
        }
        let stops = lineEvents.map {
            CLLocationCoordinate2D(latitude: Double($0.latitude) ?? 0, longitude: Double($0.longitude) ?? 0)
        }
        trackSegments = splitTrack(track, atStops: stops)
    }
    
//    func calculateRoutes() {
//        polylines.removeAll()
//        
//        for index in lineEvents.indices {
//            if !(index == lineEvents.count - 1) {
//                
//                let startCoordinate = CLLocationCoordinate2D(latitude: Double(lineEvents[index].latitude) ?? 0.0, longitude: Double(lineEvents[index].longitude) ?? 0.0)
//                let endCoordinate = CLLocationCoordinate2D(latitude: Double(lineEvents[index+1].latitude) ?? 0.0, longitude: Double(lineEvents[index+1].longitude) ?? 0.0)
//                print("calculating from \(startCoordinate) to \(endCoordinate)")
//                calculateRoute(from: startCoordinate, to: endCoordinate, index: index, transportType: .automobile)
//            }
//        }
//    }
    
//    func calculateRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, index: Int, transportType: MKDirectionsTransportType) {
//        let request = MKDirections.Request()
//        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
//        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
//        request.transportType = transportType
//        
//        let directions = MKDirections(request: request)
//        directions.calculate { response, error in
//            guard let route = response?.routes.first else {
//                print("Error calculating route: \(String(describing: error))")
//                return
//            }
//            
//            // Ensure the update to the polylines dictionary is done on the main thread
//            DispatchQueue.main.async {
//                polylines[index] = route.polyline
//            }
//        }
//    }
}

struct lineMapPreview: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()
        let date = "2026-03-30"
        @StateObject var fullTripTest = FullTripTest()
        
        @StateObject var savedTripsModel = SavedTripsModel()
        @StateObject var regularTripsModel = RegularTripsModel()
        @StateObject var appRequirementsClass = AppRequirementsClass()
            @StateObject var itineraryViewModel = ItineraryViewModel()
        return LineMapView(lineEvents: [], lineName: "A", operatorName: "tpg", destination: "Meinier, Eglise",stopEvent: StopEvent(stopPointName: "Genève, Rive", stopId: "ch:1:sloid:87061:0:450545", plannedQuay: "I", timetabledTime: "\(date)T11:13:00Z", estimatedTime: "\(date)T11:13:00Z", lineName: "A", origin: "Genève, Rive", destination: "Gy, temple", transportType: "bus", operatorName: "Transports Publics Genevois", journeyRef: "ch:1:sjyid:100680:HAS-26-A-0-Lun-Ven-33791918", operatingDayRef: date))
            .environmentObject(itineraryViewModel)
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
            .environmentObject(savedTripsModel)
            .environmentObject(regularTripsModel)
            .environmentObject(appRequirementsClass)
        
//        VStack {
//            HStack {
//                StopIcon(color: .blue, currentStop: true)
//                Spacer()
//            }
//            Spacer()
//        }
//        .padding()
    }
}

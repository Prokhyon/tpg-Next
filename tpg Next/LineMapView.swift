//
//  LineMapView.swift
//  tpg Next
//
//  Created by Loris Thomas on 11.08.2024.
//

import SwiftUI
import MapKit

struct LineMapView: View {
    @ObservedObject var path: ViewStateStack
    var lineEvents: [LineEvent]
    var lineName: String
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var polylines: [Int : MKPolyline] = [:]

    @Binding var selectedResult: String?

    var body: some View {
            GeometryReader { geometry in
                
                ZStack {
                    Map(selection: $selectedResult) {
                        ForEach(lineEvents, id: \.self) { event in
                            if event == lineEvents.first || event == lineEvents.last {
                                let splitStopName = splitString(event.stopPointName, separator: ",")
                                Annotation("\(splitStopName.0)\n\(splitStopName.1)", coordinate: CLLocationCoordinate2D(latitude: Double(event.latitude) ?? 0.0, longitude: Double(event.longitude) ?? 0.0), anchor: .center) {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 3)
                                        .background(
                                            Circle()
                                                .fill(LineColors.lineColor(for: lineName, inverted: true))
                                        )
                                        .frame(width: 18, height: 18)
                                }
                            } else {
                                let splitStopName = splitString(event.stopPointName, separator: ",")
                                //                    Marker("\(splitStopName.0)\n\(splitStopName.1)", systemImage: "figure.wave", coordinate: CLLocationCoordinate2D(latitude: Double(event.latitude) ?? 0.0, longitude: Double(event.longitude) ?? 0.0)).tint(LineColors.lineColor(for: lineName))
                                Annotation("\(splitStopName.0)\n\(splitStopName.1)", coordinate: CLLocationCoordinate2D(latitude: Double(event.latitude) ?? 0.0, longitude: Double(event.longitude) ?? 0.0), anchor: .center) {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 3)
                                        .background(
                                            Circle()
                                                .fill(LineColors.lineColor(for: lineName, inverted: true))
                                        )
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                        
                        //                ForEach(polylines.keys.sorted(), id: \.self) { key in
                        //                    if let polyline = polylines[key] {
                        //                        MapPolyline(polyline)
                        //                                .stroke(LineColors.lineColor(for: lineName), lineWidth: 3)
                        //                    }
                        //                }
                        
                        MapPolyline(coordinates: lineEvents.map {
                            CLLocationCoordinate2D(latitude: Double($0.latitude) ?? 0.0, longitude: Double($0.longitude) ?? 0.0)
                        }).stroke(LineColors.lineColor(for: lineName), lineWidth: 5)
                        if !routeCoordinates.isEmpty {
                            MapPolyline(coordinates: routeCoordinates)
                                .stroke(.blue, lineWidth: 3)
                        }
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        //                MapScaleView()
                    }
                    //            .onAppear {
                    //                print("calculating")
                    //                calculateRoutes()
                    //            }
                    VStack {
                        BlurView()
                            .blur(radius: 10.0)
                            .frame(height: 100)
                        //                    .opacity(0.98)
                            .ignoresSafeArea()
                            .offset(y: -120)
                        Spacer()
                        
                        if let selectedResult {
                            CloseDeparturesView(path: path, stop: stopFromId(by: selectedResult)!)
                                .frame(height: geometry.size.height / 3 + 10)
                                .transition(.slide)
                                .animation(.easeInOut(duration: 0.8), value: selectedResult)
                                .layoutPriority(1)
                        }
                        Rectangle()
                            .foregroundStyle(.clear)
                            .frame(height: 75)
                    }
                    VStack {
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    path.pop()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.backward")
                                    Text("Ligne \(lineName)")
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal)
                                .background(RoundedRectangle(cornerRadius: 8)
                                    .foregroundStyle(.thickMaterial)
                                    .shadow(
                                        color: .customShadows.opacity(0.25),
                                        radius: 3)
                                )
                            }
                            .padding(.horizontal)
                            .offset(y: 5)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
    }
    
    func calculateRoutes() {
        polylines.removeAll()
        
        for index in lineEvents.indices {
            if !(index == lineEvents.count - 1) {
                
//            } else {
                let startCoordinate = CLLocationCoordinate2D(latitude: Double(lineEvents[index].latitude) ?? 0.0, longitude: Double(lineEvents[index].longitude) ?? 0.0)
                let endCoordinate = CLLocationCoordinate2D(latitude: Double(lineEvents[index+1].latitude) ?? 0.0, longitude: Double(lineEvents[index+1].longitude) ?? 0.0)
                print("calculating from \(startCoordinate) to \(endCoordinate)")
                calculateRoute(from: startCoordinate, to: endCoordinate, index: index, transportType: .automobile)
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
                print("Error calculating route: \(String(describing: error))")
                return
            }
            
            // Ensure the update to the polylines dictionary is done on the main thread
            DispatchQueue.main.async {
                polylines[index] = route.polyline
            }
        }
    }
}

// Helper extension to extract coordinates from MKPolyline
//extension MKPolyline {
//    var coordinates: [CLLocationCoordinate2D] {
//        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: Int(pointCount))
//        getCoordinates(&coords, range: NSRange(location: 0, length: Int(pointCount)))
//        return coords
//    }
//}

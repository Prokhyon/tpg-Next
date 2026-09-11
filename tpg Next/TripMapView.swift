//
//  TripMapView.swift
//  tpg Next
//
//  Created by Loris Thomas on 12.08.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc

struct TripMapView: View {
    var tripEvent: TripEvent
    var isPreview: Bool = false
    
    @State private var polylines: [Int : MKPolyline] = [:]
    
    var body: some View {
            ZStack {
                Map {
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
                    
                    ForEach(tripEvent.legs.indices, id: \.self) { index in
                        let leg = tripEvent.legs[index]
                        let lineColor = LineColors.lineColor(for: leg.publishedLineName, operatorName: leg.legOperator)
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
                            
                            
                            if leg.legIntermediates.isEmpty {
                                MapPolyline(coordinates: [CLLocationCoordinate2D(latitude: Double(leg.legBoardLatitude) ?? 0.0, longitude: Double(leg.legBoardLongitude) ?? 0.0), CLLocationCoordinate2D(latitude: Double(leg.legAlightLatitude) ?? 0.0, longitude: Double(leg.legAlightLongitude) ?? 0.0)])
                                    .stroke(lineColor, lineWidth: 3)
                            } else {
                                ForEach(leg.legIntermediates.indices) { index in
                                    let intermediate = leg.legIntermediates[index]
                                    
                                    if !isPreview {
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
                                    if index == 0 {
                                        MapPolyline(coordinates: [CLLocationCoordinate2D(latitude: Double(leg.legBoardLatitude) ?? 0.0, longitude: Double(leg.legBoardLongitude) ?? 0.0), CLLocationCoordinate2D(latitude: Double(intermediate.latitude) ?? 0.0, longitude: Double(intermediate.longitude) ?? 0.0)])
                                            .stroke(lineColor, lineWidth: 3)
                                    } else {
                                        let previousIntermediate = leg.legIntermediates[index - 1]
                                        MapPolyline(coordinates: [CLLocationCoordinate2D(latitude: Double(intermediate.latitude) ?? 0.0, longitude: Double(intermediate.longitude) ?? 0.0), CLLocationCoordinate2D(latitude: Double(previousIntermediate.latitude) ?? 0.0, longitude: Double(previousIntermediate.longitude) ?? 0.0)])
                                            .stroke(lineColor, lineWidth: 3)
                                    }
                                    if index == leg.legIntermediates.count - 1 {
                                        MapPolyline(coordinates: [CLLocationCoordinate2D(latitude: Double(intermediate.latitude) ?? 0.0, longitude: Double(intermediate.longitude) ?? 0.0), CLLocationCoordinate2D(latitude: Double(leg.legAlightLatitude) ?? 0.0, longitude: Double(leg.legAlightLongitude) ?? 0.0)])
                                            .stroke(lineColor, lineWidth: 3)
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
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .onAppear {
                    print("calculating")
                    calculateRoutes()
                    print("tripmap start: ", tripEvent.startCoordinates)
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


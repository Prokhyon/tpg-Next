//
//  TripComponents.swift
//  tpg Next
//
//  Éléments d'itinéraire partagés : étape, aperçu de carte, sélecteur.
//

import SwiftUI
import MapKit
import tpgNextFunc

struct TripElementView: View {
    var event: TripEvent
    var showTime: Bool = true
    var body: some View {
        VStack(alignment: .center) {
            HStack {
                let startTime = departureDisplay(timetabled: event.startTime, estimated: event.startTime, showTime: showTime)
                DepartureTimeView(startTime, transportType: event.legs.first?.transportTypeName ?? "Bus", iconWidth: 55)
                    .frame(width: 55)
                    .minimumScaleFactor(0.5)
                    Spacer()

                    // Scrollable icon area
                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Spacer()
                            ForEach(event.legs, id: \.id) { leg in
                                if !(leg.publishedLineName == "") {
                                    BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
                                        .padding(2)
                                } else if /*!*/leg.transfer && durationMinutes(leg.transferWalkDuration) ?? 0 >= 5 {
                                    Image(systemName: "figure.walk").font(.caption)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(minWidth: 200)
                    }
                    .mask {
                        Rectangle()
                            .overlay(alignment: .leading) {
                                ScrollMask(leading: true, vertical: false, gradientLength: 25)
                            }
                    }
                    .mask {
                        Rectangle()
                            .overlay(alignment: .trailing) {
                                ScrollMask(leading: false, vertical: false, gradientLength: 25)
                            }
                    }

                }
                .frame(minWidth: 200, maxHeight: 30)
                    Spacer()
                let endTime = departureDisplay(timetabled: event.endTime, estimated: event.endTime, showTime: showTime)
                DepartureTimeView(endTime, transportType: event.legs.last?.transportTypeName ?? "Bus", iconWidth: 55)
                    .frame(width: 55)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal)
            
            HStack {
                Image(systemName: "arrowshape.bounce.forward")
                Text(": \(event.transfers)")
                    .padding(.trailing)
                Image(systemName: "timer")
                Text(": \(durationText(event.duration))")
            }
        }
        .padding(.horizontal)
    }
}

struct MapPreview: View {
    var resultDetail: searchResultItem
    @State var position: MapCameraPosition
    
    var body: some View {
            Map(position: $position) {
                Annotation(resultDetail.title, coordinate: resultDetail.coordinates, anchor: .center) {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                        .background(
                            Circle()
                                .fill(.color1)
                        )
                        .frame(width: 15, height: 15)
                }
                UserAnnotation()
            }
            .safeAreaPadding(10)
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
    }
}

struct CustomPicker: View {
    @Binding var secondSelected: Bool
    var height: CGFloat
    var firstOption: String
    var firstIcon: String?
    var secondOption: String
    var secondIcon: String?
    var name = "shape"
    var animation: Namespace.ID
    @State var firstSelected: Bool = true
    var body: some View {
            HStack {
                ZStack {
                        if firstSelected {
//                            RoundedRectangle(cornerRadius: 20)
                            BasicElement()
                                .frame(height: height)
                                .matchedGeometryEffect(id: name, in: animation)
                        }
                    Button {
                                            withAnimation {
                                                firstSelected = true
                                            }
                    } label: {
                        
                        HStack {
                            Spacer()
                            if firstIcon != nil {
                                Image(systemName: firstIcon!)
                            }
                            Text(firstOption)
                            Spacer()
                        }
                        .scaleEffect(firstSelected ?  1 : 0.9)
                    }
                }
                ZStack {
                        if !firstSelected {
//                            RoundedRectangle(cornerRadius: 20)
                            BasicElement()
                                .frame(height: height)
                                .matchedGeometryEffect(id: name, in: animation)
                        }
                    Button {
                                            withAnimation {
                                                firstSelected = false
                                            }
                    } label: {
                        HStack {
                            Spacer()
                            if secondIcon != nil {
                                Image(systemName: secondIcon!)
                            }
                            Text(secondOption)
                            Spacer()
                        }
                        .scaleEffect(!firstSelected ?  1 : 0.9)
                    }
                }
            }
            .foregroundStyle(.primary)
            .background {
//                RoundedRectangle(cornerRadius: 20)
                Capsule()
                    .stroke(.gray.opacity(0.3), lineWidth: 2)
                    .frame(height: height-3)
//                    .padding(5)
            }
            .onAppear {
                firstSelected = !secondSelected
            }
            .onChange(of: firstSelected) {
                withAnimation {
                    secondSelected = !firstSelected
                }
            }
    }
}

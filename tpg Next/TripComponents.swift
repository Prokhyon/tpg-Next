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
    @Environment(\.displayTime) private var now
    /// Hauteur de la rangée de badges : 30 à la taille normale, plus avec un texte agrandi.
    @ScaledMetric private var iconRowHeight: CGFloat = 30
    var event: TripEvent
    var showTime: Bool = true
    var body: some View {
        VStack(alignment: .center) {
            HStack {
                let startTime = departureDisplay(timetabled: event.startTime, estimated: event.startTime, showTime: showTime, at: now)
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
                .frame(minWidth: 200, maxHeight: iconRowHeight)
                    Spacer()
                let endTime = departureDisplay(timetabled: event.endTime, estimated: event.endTime, showTime: showTime, at: now)
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

    /// Une option : la pastille de l'option choisie glisse de l'une à l'autre et suit la hauteur
    /// du texte (elle restait à `height`, et un texte agrandi en débordait).
    private func pickerOption(isSelected: Bool, icon: String?, title: String, select: @escaping () -> Void) -> some View {
        Button {
            withAnimation { select() }
        } label: {
            HStack {
                Spacer()
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                Spacer()
            }
            .scaleEffect(isSelected ? 1 : 0.9)
            .frame(minHeight: height)
        }
        .background {
            if isSelected {
                BasicElement()
                    .matchedGeometryEffect(id: name, in: animation)
            }
        }
    }

    var body: some View {
            HStack {
                pickerOption(isSelected: firstSelected, icon: firstIcon, title: firstOption) { firstSelected = true }
                pickerOption(isSelected: !firstSelected, icon: secondIcon, title: secondOption) { firstSelected = false }
            }
            .foregroundStyle(.primary)
            .background {
                Capsule()
                    .stroke(.gray.opacity(0.3), lineWidth: 2)
                    .padding(.vertical, 1.5)
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

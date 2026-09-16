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
    var event: TripEvent
    var showTime: Bool = true
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack {
                let startTime = departureDisplay(timetabled: event.startTime, estimated: event.startTime, showTime: showTime, at: now)
                DepartureTimeView(startTime, transportType: event.startTransportType, iconWidth: 55)
                    .frame(width: 55)
                    .minimumScaleFactor(0.5)
                Spacer()
                HStack {
                    Image(systemName: "arrowshape.bounce.forward")
                    Text(": \(event.transfers)")
                        .padding(.trailing)
                    Image(systemName: "timer")
                    Text(": \(durationText(event.duration))")
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Aux tailles d'accessibilité, il ne restait que « : » et « … » entre les deux heures.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                Spacer()
                let endTime = departureDisplay(timetabled: event.endTime, estimated: event.endTime, showTime: showTime, at: now)
                DepartureTimeView(endTime, transportType: event.endTransportType, iconWidth: 55)
                    .frame(width: 55)
                    .minimumScaleFactor(0.5)
            }
            TripTimeline(event: event)
                .padding(.horizontal)
        }
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

#Preview("Itinéraire") {
    TripElementView(event: FullTripTest().Trip)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .basicElementBackground(minHeight: 72)
        .padding(4)
}

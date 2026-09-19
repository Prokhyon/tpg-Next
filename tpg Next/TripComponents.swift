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
                    if event.legs.contains(where: \.hasIncident) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .padding(.leading, 4)
                            .accessibilityLabel("Parcours modifié")
                    }
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

#Preview("Résultat d'itinéraire") {
    @Previewable @State var showTime = true
    ScrollView {
        Toggle("Heure affichée" as String, isOn: $showTime)
            .padding(.horizontal, 30)
        ForEach(PreviewData.trips) { trip in
            TripElementView(event: trip, showTime: showTime)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .basicElementBackground(minHeight: 72)
                .padding(4)
                .padding(.horizontal, 10)
        }
    }
    .previewEnvironment(navigation: false)
}

#Preview("Résultat d'itinéraire — texte très grand") {
    VStack {
        ForEach(PreviewData.trips.prefix(3)) { trip in
            TripElementView(event: trip)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .basicElementBackground(minHeight: 72)
                .padding(4)
        }
    }
    .dynamicTypeSize(.accessibility2)
    .previewEnvironment(navigation: false)
}

#Preview("Sélecteur à deux options", traits: .sizeThatFitsLayout) {
    @Previewable @State var second = false
    @Previewable @Namespace var animation
    VStack(spacing: 20) {
        CustomPicker(secondSelected: $second, height: 40, firstOption: "Départ", firstIcon: "arrow.up.right",
                     secondOption: "Arrivée", secondIcon: "arrow.down.right", animation: animation)
        CustomPicker(secondSelected: $second, height: 40, firstOption: "Minutes", secondOption: "Heure",
                     name: "second", animation: animation)
    }
    .padding()
}

#Preview("Aperçu d'un lieu", traits: .fixedLayout(width: 390, height: 300)) {
    let place = searchResultItem(title: "Parc des Bastions", coordinates: CLLocationCoordinate2D(latitude: 46.2003, longitude: 6.1455))
    MapPreview(resultDetail: place, position: .region(MKCoordinateRegion(center: place.coordinates, latitudinalMeters: 800, longitudinalMeters: 800)))
}

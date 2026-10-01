//
//  PlaceSheet.swift
//  tpg Next
//
//  Un lieu ou un arrêt trouvé par la recherche : sa carte, « Y aller », « Partir d'ici », et
//  pour un lieu l'étoile des lieux favoris et les arrêts les plus proches.
//

import SwiftUI
import MapKit
import tpgNextFunc

/// Ce que montre la fiche : un arrêt, ou un lieu (adresse, commerce, point d'intérêt).
struct PlaceSheetItem: Identifiable {
    let id = UUID()
    let name: String
    var subtitle: String?
    let coordinate: CLLocationCoordinate2D
    var stop: Stop?

    init(stop: Stop) {
        name = stop.name
        coordinate = stop.wgs84Coordinates.toCLLocationCoordinate2D
        self.stop = stop
    }

    init(name: String, subtitle: String?, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
    }

    var endpoint: TripEndpoint {
        stop.map { .stop($0) } ?? .place(GeoPosition(name: name, coordinate: coordinate))
    }
}

struct PlaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openRoute) private var openRoute
    @Environment(ItineraryViewModel.self) private var itinerary
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(StopStore.self) private var stopStore
    @Environment(FavoritePlacesModel.self) private var favoritePlaces
    let place: PlaceSheetItem

    @State private var position: MapCameraPosition
    @State private var nearbyStops: [Stop] = []

    init(place: PlaceSheetItem) {
        self.place = place
        _position = State(initialValue: .region(MKCoordinateRegion(center: place.coordinate,
                                                                   span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007))))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Map(position: $position) {
                    Marker(place.name, coordinate: place.coordinate)
                        .tint(.accent)
                    UserAnnotation()
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 25))

                VStack(alignment: .leading, spacing: 2) {
                    if let stop = place.stop {
                        StopNameView(stop.name, style: .card, transportType: stop.meansOfTransport)
                    } else {
                        Text(place.name)
                            .font(.title3.bold())
                        if let subtitle = place.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                actions

                if place.stop == nil, !nearbyStops.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Arrêts proches")
                            .font(.headline)
                        ForEach(nearbyStops) { stop in
                            Button {
                                close { openRoute(.stop(stop)) }
                            } label: {
                                HStack {
                                    SmallStopTitleView(stopName: stop.name, transportType: stop.meansOfTransport)
                                    Text(distanceText(to: stop))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .basicElementBackground(minHeight: 45)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(35)
        .task { findNearbyStops() }
    }

    private var actions: some View {
        HStack {
            Button {
                close { itinerary.searchNow(from: nil, to: place.endpoint, tab: navigationModel) }
            } label: {
                Label("Y aller", systemImage: "figure.walk.departure")
            }
            .buttonStyle(.borderedProminent)
            Button {
                close { itinerary.start(from: place.endpoint, tab: navigationModel) }
            } label: {
                Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
            }
            .buttonStyle(.bordered)
            if let stop = place.stop {
                Button {
                    close { openRoute(.stop(stop)) }
                } label: {
                    Label("Départs", systemImage: "clock")
                }
                .buttonStyle(.bordered)
            } else {
                // Un lieu : le garder parmi les lieux favoris (accueil, itinéraire).
                let isFavorite = favoritePlaces.isFavorite(place.coordinate)
                Button {
                    withAnimation {
                        favoritePlaces.toggle(name: place.name, address: place.subtitle, coordinate: place.coordinate)
                    }
                } label: {
                    Label(isFavorite ? "Retirer des lieux favoris" : "Ajouter aux lieux favoris",
                          systemImage: isFavorite ? "star.fill" : "star")
                        .labelStyle(.iconOnly)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.bordered)
                .sensoryFeedback(.selection, trigger: isFavorite)
            }
        }
        .buttonBorderShape(.capsule)
        .lineLimit(1)
    }

    /// La fiche se ferme d'abord : l'écran d'arrivée s'ouvre dans la pile (ou l'onglet) derrière.
    private func close(then action: @escaping () -> Void) {
        dismiss()
        action()
    }

    private func findNearbyStops() {
        guard place.stop == nil else { return }
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let candidates = stopsInBoundingBox(from: location, radius: 800, stops: stopStore.activeStops)
        calculateClosestBusStops(from: location, stops: candidates, nb: 4) { _, stops in
            DispatchQueue.main.async { nearbyStops = stops }
        }
    }

    private func distanceText(to stop: Stop) -> String {
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let meters = CLLocation(latitude: stop.wgs84Coordinates.lat, longitude: stop.wgs84Coordinates.lon).distance(from: location)
        return Measurement(value: meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

#Preview("Fiche d'un lieu") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PlaceSheet(place: PlaceSheetItem(name: "Jet d'eau", subtitle: "Quai Gustave-Ador, Genève",
                                             coordinate: CLLocationCoordinate2D(latitude: 46.2074, longitude: 6.1557)))
        }
        .previewEnvironment(navigation: false)
}

#Preview("Fiche d'un arrêt") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PlaceSheet(place: PlaceSheetItem(stop: PreviewData.rive))
        }
        .previewEnvironment(navigation: false)
}

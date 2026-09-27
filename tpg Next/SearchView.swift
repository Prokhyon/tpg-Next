//
//  SearchView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//
//  Un seul champ pour aller quelque part ou trouver quelque chose : les lignes, mes
//  itinéraires, les arrêts et les lieux. Sans texte, les recherches récentes, les arrêts
//  proches et la liste des lignes.
//

import Foundation
import SwiftUI
import MapKit
import tpgNextFunc

struct SearchView: View {
    @Environment(\.displayTime) private var now
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(ItineraryViewModel.self) var itinerary
    @Environment(NavigationModel.self) var navigationModel
    @Environment(RecentSearch.self) var recentSearchModel
    @Environment(SavedTripsModel.self) var savedTripsModel
    @Environment(RegularTripsModel.self) var regularTripsModel
    @Environment(\.openRoute) private var openRoute
    @AppStorage(SettingKey.lineOperators) private var lineOperators = LineOperatorChoice.defaultValue

    @State private var locationManager = LocationManager()
    @State private var locationSearch = LocationSearchViewModel()
    @State private var stopResults: [Stop] = []
    @State private var nearbyStops: [Stop] = []
    @State private var userLocation: CLLocation?
    /// La fiche d'un lieu ou d'un arrêt, avec « Y aller ».
    @State private var place: PlaceSheetItem?
    private var recentTrips = RecentTrips.shared

    private var query: String { navigationModel.searchQuery }

    var body: some View {
        let searchView = ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if query.isEmpty {
                    emptyState
                } else {
                    results
                }
            }
            .padding(.bottom, 40)
        }
        .readableScrollContent()
        .overlay(alignment: .top) {
            BackdropBlurView(radius: 5)
                .frame(height: 70)
                .mask {
                    Rectangle()
                        .overlay(alignment: .top) {
                            ScrollMask(leading: true, vertical: true, gradientLength: 70)
                        }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .navigationTitle("Explorer") // Set back button text
        .scrollDismissesKeyboard(.immediately)
        .searchingStops(query, results: $stopResults)
        .onChange(of: query, initial: true) { locationSearch.searchQuery = query }
        .onAppear(perform: locate)
        .sheet(item: $place) { place in
            PlaceSheet(place: place)
        }

        if #available(iOS 26, *) {
            searchView
                .searchable(text: Bindable(navigationModel).searchQuery, prompt: Text("Arrêts, lieux, itinéraires"))
        } else {
            searchView
        }
    }

    // MARK: Sans texte

    /// Les recherches récentes (itinéraires, arrêts, lieux) et les arrêts proches.
    @ViewBuilder private var emptyState: some View {
        let recentItems = recentSearchModel.searchItems
        if !recentTrips.trips.isEmpty || !recentItems.isEmpty {
            sectionTitle("Récents")
            ForEach(recentTrips.trips.prefix(3), id: \.self) { trip in
                row(title: recentTripTitle(trip), subtitle: nil, systemImage: "point.bottomleft.forward.to.point.topright.scurvepath") {
                    itinerary.searchNow(from: trip.origin?.endpoint, to: trip.destination.endpoint, tab: navigationModel)
                }
            }
            ForEach(recentItems, id: \.self) { item in
                if item.isStop, let stop = item.stop {
                    stopRow(stop)
                } else if let coordinates = item.geoCoordinates {
                    let title = item.placeTitle
                    placeRow(title: title.name, subtitle: title.subtitle) {
                        place = PlaceSheetItem(name: title.name, subtitle: title.subtitle, coordinate: coordinates.toCLLocationCoordinate2D)
                    }
                }
            }
        }
        if !nearbyStops.isEmpty {
            sectionTitle("À proximité")
            ForEach(nearbyStops) { stop in
                stopRow(stop, distance: userLocation.map { distance(from: $0, to: stop) })
            }
        }
        sectionTitle("Réseau")
        row(title: String(localized: "Toutes les lignes"),
            subtitle: LineOperatorChoice.operators(from: lineOperators).map(\.shortName).formatted(.list(type: .and)),
            systemImage: "list.number") {
            openRoute(.lines)
        }
    }

    /// « Rive → gare Cornavin », « Ma position → Jet d'eau ».
    private func recentTripTitle(_ trip: RecentTrips.RecentTrip) -> String {
        "\(trip.origin?.name ?? String(localized: "Ma position")) → \(trip.destination.name)"
    }

    // MARK: Résultats

    @ViewBuilder private var results: some View {
        // Seulement les transporteurs choisis : « 1 » ne donne pas les 1 de toute la Suisse.
        let lines = LineDirectory.search(query, in: LineOperatorChoice.lines(from: lineOperators))
        let myTrips = matchingTrips
        let places = Array(locationSearch.searchResults.prefix(5))
        if lines.isEmpty && myTrips.isEmpty && stopResults.isEmpty && places.isEmpty {
            Text("Aucun résultat pour « \(query) »")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
        if !lines.isEmpty {
            sectionTitle("Lignes")
            ForEach(lines) { line in
                lineRow(line)
            }
        }
        if !myTrips.isEmpty {
            sectionTitle("Mes itinéraires")
            ForEach(myTrips) { myTrip in
                myTripRow(myTrip)
            }
        }
        if !stopResults.isEmpty {
            sectionTitle("Arrêts")
            ForEach(stopResults) { stop in
                stopRow(stop)
            }
        }
        if !places.isEmpty {
            sectionTitle("Lieux")
            ForEach(places, id: \.self) { completion in
                placeRow(title: completion.title, subtitle: completion.subtitle) {
                    open(completion)
                }
            }
        }
    }

    /// Les trajets réguliers et les prochains itinéraires enregistrés, par nom ou par arrêt.
    private var matchingTrips: [MyTrip] {
        let wanted = query.normalized().lowercased()
        guard !wanted.isEmpty else { return [] }
        func matches(_ texts: String...) -> Bool {
            texts.contains { $0.normalized().lowercased().contains(wanted) }
        }
        let regular = regularTripsModel.regularTrips
            .filter { matches($0.name, $0.origin.name, $0.destination.name) }
            .map(MyTrip.regular)
        let saved = savedTripsModel.savedTrips
            .filter { ($0.endDate ?? .distantPast) > now && matches($0.startName, $0.endName) }
            .sortedByStart()
            .prefix(5)
            .map(MyTrip.saved)
        return regular + saved
    }

    enum MyTrip: Identifiable {
        case regular(RegularTrip)
        case saved(TripEvent)

        var id: String {
            switch self {
            case .regular(let trip): "regular-\(trip.id)"
            case .saved(let trip): "saved-\(trip.id)"
            }
        }
    }

    @ViewBuilder
    private func myTripRow(_ myTrip: MyTrip) -> some View {
        switch myTrip {
        case .regular(let trip):
            let next = regularTripsModel.upcoming(after: now).first { $0.tripID == trip.id }
            row(title: trip.displayName, subtitle: regularSubtitle(trip, next: next), systemImage: "repeat") {
                // Le trajet du jour s'il y en a un dans la semaine, sinon la liste des trajets réguliers.
                if let next, let displayed = regularTripsModel.displayedTrip(for: next) {
                    openRoute(.trip(displayed))
                } else {
                    openRoute(.regularTrips)
                }
            }
            .contextMenu {
                Button {
                    itinerary.searchNow(from: trip.origin.endpoint, to: trip.destination.endpoint, tab: navigationModel)
                } label: {
                    Label("Chercher maintenant", systemImage: "arrow.right")
                }
                Button {
                    itinerary.searchNow(from: trip.destination.endpoint, to: trip.origin.endpoint, tab: navigationModel)
                } label: {
                    Label("Retour maintenant", systemImage: "arrow.uturn.left")
                }
            }
        case .saved(let trip):
            row(title: "\(trip.startName) → \(trip.endName)", subtitle: savedSubtitle(trip), image: "scurvepath.stack.fill") {
                openRoute(.trip(savedTripsModel.displayedTrip(for: trip)))
            }
        }
    }

    /// « Demain · 17:58 », ou les jours et l'heure s'il n'y a rien dans la semaine.
    private func regularSubtitle(_ trip: RegularTrip, next: RegularTripOccurrence?) -> String {
        guard let next else { return "\(trip.daysSummary) · \(trip.timeText)" }
        return "\(SavedTripsAgenda.dayTitle(next.plannedDeparture)) · \(dateToString(with: next.plannedDeparture))"
    }

    private func savedSubtitle(_ trip: TripEvent) -> String {
        guard let start = trip.startDate else { return "" }
        return "\(SavedTripsAgenda.dayTitle(start)) · \(dateToString(with: start))"
    }

    // MARK: Lignes

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.title2).bold()
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    /// Un arrêt : ses départs au toucher, sa fiche (carte, « Y aller ») par le bouton.
    private func stopRow(_ stop: Stop, distance: String? = nil) -> some View {
        Button {
            recentSearchModel.add(name: stop.name, isStop: true, stop: stop, geoCoordinates: nil)
            openRoute(.stop(stop))
        } label: {
            BasicLocationView(name: stop.name, subtitle: distance, transportType: stop.meansOfTransport,
                              isFavorite: favoritesViewModel.isFavorite(stop), showButton: true, showFavorite: true,
                              buttonAction: { place = PlaceSheetItem(stop: stop) },
                              favoriteAction: { toggleFavorite(stop: stop) })
        }
        .foregroundStyle(.primary)
        .padding(5)
        .padding(.horizontal)
        .contentShape(.contextMenuPreview, Capsule())
        .contextMenu {
            TripActionsMenu(stop: stop)
        }
    }

    /// Une ligne : son numéro, et ses terminus.
    private func lineRow(_ line: TransitLine) -> some View {
        Button {
            openRoute(.lineInfo(line))
        } label: {
            HStack(spacing: 12) {
                BusLineIcon(lineName: line.number, operatorName: line.operatorColorName)
                    .font(.callout.bold())
                Text(verbatim: line.termini.map { "\($0.from) ↔ \($0.to)" } ?? line.description)
                    .font(.callout)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .basicElementBackground(minHeight: 45)
        }
        .foregroundStyle(.primary)
        .padding(5)
        .padding(.horizontal)
    }

    private func placeRow(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            BasicLocationView(name: title, subtitle: subtitle, isGeoPosition: true)
        }
        .foregroundStyle(.primary)
        .padding(5)
        .padding(.horizontal)
    }

    private func row(title: String, subtitle: String?, systemImage: String? = nil, image: String? = nil,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if let systemImage {
                        Image(systemName: systemImage)
                    } else if let image {
                        Image(image)
                    }
                }
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .basicElementBackground(minHeight: 45)
        }
        .foregroundStyle(.primary)
        .padding(5)
        .padding(.horizontal)
    }

    // MARK: Actions

    /// Un lieu proposé par Plans : ses coordonnées d'abord, puis sa fiche.
    private func open(_ completion: MKLocalSearchCompletion) {
        locationSearch.getCoordinate(for: completion) { coordinate in
            guard let coordinate else { return }
            DispatchQueue.main.async {
                recentSearchModel.add(name: "\(completion.title);\(completion.subtitle)", isStop: false, stop: nil,
                                      geoCoordinates: coordinate.toCoordinates)
                place = PlaceSheetItem(name: completion.title, subtitle: completion.subtitle, coordinate: coordinate)
            }
        }
    }

    /// La position : les arrêts proches, et des résultats triés du plus proche au plus lointain.
    private func locate() {
        locationManager.requestLocation { location in
            guard let location = location ?? locationManager.userLocation else {
                Log.location.error("Position indisponible")
                return
            }
            locationManager.locationUpdateHandler = nil
            stopStore.location = location
            let candidates = stopsInBoundingBox(from: location, radius: 1000, stops: stopStore.activeStops)
            calculateClosestBusStops(from: location, stops: candidates, nb: 5) { _, stops in
                DispatchQueue.main.async {
                    userLocation = location
                    nearbyStops = stops
                }
            }
        }
    }

    private func distance(from location: CLLocation, to stop: Stop) -> String {
        let meters = CLLocation(latitude: stop.wgs84Coordinates.lat, longitude: stop.wgs84Coordinates.lon).distance(from: location)
        return Measurement(value: meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private func toggleFavorite(stop: Stop) {
        if favoritesViewModel.isFavorite(stop) {
            favoritesViewModel.removeFavoriteStop(stop)
        } else {
            favoritesViewModel.addFavorite(stop)
        }
    }
}

#Preview("Recherche") {
    SearchView()
        .environment(RegularTripsModel(previewTrips: [
            RegularTrip(trip: PreviewData.tripWithTransfer, weekdays: Weekday.workdays, name: "Travail"),
        ]))
        .previewEnvironment(savedTrips: PreviewData.trips)
}

#Preview("Recherche — iPad", traits: .iPadLandscape) {
    SearchView()
        .previewEnvironment(savedTrips: PreviewData.trips)
}

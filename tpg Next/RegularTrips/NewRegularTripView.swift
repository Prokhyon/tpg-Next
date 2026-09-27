//
//  NewRegularTripView.swift
//  tpg Next
//
//  Créer un trajet régulier sans passer par une recherche d'itinéraire : départ, arrivée,
//  jours et heure, puis l'itinéraire habituel parmi ceux proposés par OJP.
//

import SwiftUI
import tpgNextFunc

struct NewRegularTripView: View {
    @Environment(RegularTripsModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var origin: Stop?
    @State private var destination: Stop?
    @State private var weekdays = Weekday.workdays
    @State private var anchor = RegularTrip.Anchor.departure
    /// Minutes depuis minuit, heure de Genève.
    @State private var minuteOfDay = 7 * 60 + 30
    @State private var path: [Step] = []
    @State private var search = Search.idle

    init(origin: Stop? = nil, destination: Stop? = nil) {
        _origin = State(initialValue: origin)
        _destination = State(initialValue: destination)
    }

    enum Step: Hashable {
        case origin, destination
        case trip(TripEvent)
    }

    enum Search: Equatable {
        case idle, loading
        case results([TripEvent], day: Date)
        case noTrip, failed
    }

    /// Ce qui relance la recherche des itinéraires.
    private struct Query: Equatable {
        let origin: Stop?
        let destination: Stop?
        let weekdays: Set<Weekday>
        let anchor: RegularTrip.Anchor
        let minuteOfDay: Int
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    NavigationLink(value: Step.origin) {
                        placeRow("Départ", stop: origin)
                    }
                    NavigationLink(value: Step.destination) {
                        placeRow("Arrivée", stop: destination)
                    }
                    if origin != nil || destination != nil {
                        Button {
                            (origin, destination) = (destination, origin)
                        } label: {
                            Label("Inverser le départ et l'arrivée", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }

                Section {
                    WeekdayPicker(selection: $weekdays)
                        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    WeekdayPresets(selection: $weekdays)
                } header: {
                    Text("Jours")
                }

                Section {
                    Picker("Heure retenue", selection: $anchor) {
                        Text("Départ").tag(RegularTrip.Anchor.departure)
                        Text("Arrivée").tag(RegularTrip.Anchor.arrival)
                    }
                    .pickerStyle(.segmented)
                    DatePicker(anchor == .departure ? "Partir vers" as LocalizedStringKey : "Arriver avant",
                               selection: timeBinding, displayedComponents: .hourAndMinute)
                        // Les horaires sont ceux de Genève, même depuis l'étranger.
                        .environment(\.timeZone, Calendar.swissTransit.timeZone)
                } header: {
                    Text("Heure")
                }

                tripsSection
            }
            .navigationTitle("Nouveau trajet régulier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .origin:
                    RegularTripStopPicker(title: "Départ", selection: $origin)
                case .destination:
                    RegularTripStopPicker(title: "Arrivée", selection: $destination)
                case .trip(let trip):
                    RegularTripEditor(creatingFrom: trip, weekdays: weekdays, anchor: anchor) { dismiss() }
                }
            }
            .task(id: Query(origin: origin, destination: destination, weekdays: weekdays, anchor: anchor, minuteOfDay: minuteOfDay)) {
                await searchTrips()
            }
        }
    }

    // MARK: Itinéraires

    @ViewBuilder private var tripsSection: some View {
        switch search {
        case .idle:
            Section {
                Text(origin == nil || destination == nil
                     ? "Choisissez le départ et l'arrivée : les itinéraires proposés s'afficheront ici." as LocalizedStringKey
                     : "Choisissez au moins un jour.")
                    .foregroundStyle(.secondary)
            }
        case .loading:
            Section {
                HStack {
                    ProgressView()
                    Text("Recherche des itinéraires…")
                        .foregroundStyle(.secondary)
                }
            }
        case .noTrip:
            Section {
                Text("Aucun itinéraire à cette heure-là.")
                    .foregroundStyle(.secondary)
            }
        case .failed:
            Section {
                Text("Impossible de charger les itinéraires.")
                    .foregroundStyle(.secondary)
                Button("Réessayer") {
                    Task { await searchTrips() }
                }
            }
        case .results(let trips, let day):
            Section {
                ForEach(trips) { trip in
                    NavigationLink(value: Step.trip(trip)) {
                        SavedTripView(event: trip)
                            .padding(.vertical, 6)
                    }
                }
            } header: {
                Text("Itinéraires \(dayText(day))")
            } footer: {
                Text("Choisissez celui que vous prenez d'habitude : ses lignes et ses arrêts seront reconnus chaque jour.")
            }
        }
    }

    /// Les itinéraires du prochain jour coché, à l'heure choisie.
    private func searchTrips() async {
        guard let origin, let destination, origin.sloid != destination.sloid,
              let date = Weekday.nextDate(on: weekdays, minuteOfDay: minuteOfDay, after: Date()) else {
            search = .idle
            return
        }
        search = .loading
        // Le temps de finir de régler l'heure.
        do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
        do {
            let trips = try await RegularTripResolver.trips(from: Self.place(origin), to: Self.place(destination),
                                                            at: date, isArrivalTime: anchor == .arrival)
            guard !Task.isCancelled else { return }
            search = .results(trips.sortedByStart(), day: date)
        } catch RegularTripResolver.Failure.noTrip {
            search = .noTrip
        } catch {
            guard !Task.isCancelled else { return }
            search = .failed
        }
    }

    private static func place(_ stop: Stop) -> RegularTripPlace {
        RegularTripPlace(name: stop.name, sloid: stop.sloid, coordinates: stop.wgs84Coordinates)
    }

    // MARK: Textes et liaisons

    /// « du lundi 28 septembre ».
    private func dayText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "d'aujourd'hui") }
        if calendar.isDateInTomorrow(date) { return String(localized: "de demain") }
        return String(localized: "du \(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
    }

    private func placeRow(_ title: LocalizedStringKey, stop: Stop?) -> some View {
        LabeledContent(title) {
            if let stop {
                Text(stop.name)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("Choisir")
            }
        }
    }

    private var timeBinding: Binding<Date> {
        let calendar = Calendar.swissTransit
        let today = calendar.startOfDay(for: Date())
        return Binding {
            calendar.date(byAdding: .minute, value: minuteOfDay, to: today) ?? today
        } set: { date in
            let components = calendar.dateComponents([.hour, .minute], from: date)
            minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }
}

/// Choisir un arrêt : favoris et recherches récentes, ou recherche par nom.
struct RegularTripStopPicker: View {
    @Environment(FavoritesViewModel.self) private var favorites
    @Environment(RecentSearch.self) private var recentSearch
    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    @Binding var selection: Stop?

    @State private var query = ""
    @State private var results: [Stop] = []

    var body: some View {
        List {
            if query.isEmpty {
                if !favorites.favoriteStops.isEmpty {
                    Section("Favoris") {
                        ForEach(favorites.favoriteStops) { stopRow($0) }
                    }
                }
                if !recentStops.isEmpty {
                    Section("Recherches récentes") {
                        ForEach(recentStops) { stopRow($0) }
                    }
                }
            } else {
                ForEach(results) { stopRow($0) }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Rechercher un arrêt"))
        .searchingStops(query, results: $results)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Les arrêts des recherches récentes, sans les favoris déjà proposés.
    private var recentStops: [Stop] {
        let favoriteIDs = Set(favorites.favoriteStops.map(\.sloid))
        var seen = Set<String>()
        return recentSearch.searchItems.compactMap(\.stop).filter { stop in
            !favoriteIDs.contains(stop.sloid) && seen.insert(stop.sloid).inserted
        }
    }

    private func stopRow(_ stop: Stop) -> some View {
        Button {
            selection = stop
            dismiss()
        } label: {
            HStack {
                SmallStopTitleView(stopName: stop.name, transportType: stop.meansOfTransport)
                if stop.sloid == selection?.sloid {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

#Preview("Nouveau trajet régulier") {
    NewRegularTripView()
        .environment(RegularTripsModel(previewTrips: []))
        .previewEnvironment(navigation: false)
}

#Preview("Nouveau trajet régulier — itinéraires (API)") {
    NewRegularTripView(origin: PreviewData.rive, destination: PreviewData.cornavin)
        .environment(RegularTripsModel(previewTrips: []))
        .previewEnvironment(navigation: false)
}

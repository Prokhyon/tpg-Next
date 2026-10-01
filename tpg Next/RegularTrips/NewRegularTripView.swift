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
    /// L'inversion, comme sur la page Itinéraire : les deux arrêts se rapprochent, la flèche
    /// tourne, puis ils échangent leur place.
    @State private var switchAnimate = false
    @State private var switchRotation = false

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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stopsSection

                    RegularTripDaysCard(selection: $weekdays)

                    RegularTripTimeCard(anchor: $anchor, time: timeBinding,
                                        title: anchor == .departure ? "Partir vers" : "Arriver avant")

                    tripsSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .readableScrollContent()
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
            tripsMessage(origin == nil || destination == nil
                         ? "Choisissez le départ et l'arrivée : les itinéraires proposés s'afficheront ici."
                         : "Choisissez au moins un jour.", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                Text("Recherche des itinéraires…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        case .noTrip:
            tripsMessage("Aucun itinéraire à cette heure-là.", systemImage: "clock.badge.questionmark")
        case .failed:
            VStack(spacing: 12) {
                tripsMessage("Impossible de charger les itinéraires.", systemImage: "wifi.exclamationmark")
                Button {
                    Task { await searchTrips() }
                } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 18)
                        .basicElementBackground(minHeight: 40)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        case .results(let trips, let day):
            VStack(alignment: .leading, spacing: 10) {
                Text("Itinéraires \(dayText(day))")
                    .font(.headline)
                    .padding(.leading, 8)
                ForEach(trips) { trip in
                    NavigationLink(value: Step.trip(trip)) {
                        SavedTripView(event: trip)
                            .padding(15)
                            .background(BasicCard())
                            .contentShape(RoundedRectangle(cornerRadius: 30))
                    }
                    .buttonStyle(.plain)
                }
                Text("Choisissez celui que vous prenez d'habitude : ses lignes et ses arrêts seront reconnus chaque jour.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tripsMessage(_ text: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
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

    // MARK: Arrêts

    /// Le départ et l'arrivée l'un sous l'autre, et la flèche d'inversion à côté, comme sur la
    /// page Itinéraire. Ici, pas de saisie : un toucher ouvre le choix de l'arrêt.
    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trajet")
                .font(.headline)
                .padding(.leading, 8)
            HStack(spacing: 10) {
                VStack(spacing: 10) {
                    NavigationLink(value: Step.origin) {
                        stopRow("Départ", stop: origin, terminus: false)
                    }
                    .buttonStyle(.plain)
                    .offset(y: switchAnimate ? 25 : 0)
                    NavigationLink(value: Step.destination) {
                        stopRow("Arrivée", stop: destination, terminus: true)
                    }
                    .buttonStyle(.plain)
                    .offset(y: switchAnimate ? -25 : 0)
                }
                Button(action: invertStops) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.title)
                        .padding(10)
                        .rotationEffect(.degrees(switchRotation ? 180 : 0))
                        .frame(width: 60, height: 60)
                        .background(BasicElement())
                }
                .buttonStyle(.plain)
                .disabled(origin == nil && destination == nil)
                .opacity(origin == nil && destination == nil ? 0.4 : 1)
                .accessibilityLabel("Inverser le départ et l'arrivée")
            }
        }
    }

    /// L'arrêt sur une ligne, commune en normal et arrêt en gras ; sans arrêt, son rôle en gris.
    private func stopRow(_ title: LocalizedStringKey, stop: Stop?, terminus: Bool) -> some View {
        HStack(spacing: 12) {
            StopIcon(color: .color1, terminus: terminus)
            Group {
                if let stop {
                    Text(stopName: stop.name)
                        .foregroundStyle(.primary)
                } else {
                    Text(title)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .basicElementBackground(minHeight: 46)
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(stop.map { Text(verbatim: $0.name) } ?? Text("Choisir un arrêt"))
    }

    private func invertStops() {
        withAnimation {
            switchAnimate.toggle()
            switchRotation.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            switchRotation.toggle()
            withAnimation {
                switchAnimate.toggle()
                (origin, destination) = (destination, origin)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if query.isEmpty {
                    if !favorites.favoriteStops.isEmpty {
                        header("Favoris")
                        ForEach(favorites.favoriteStops) { stopRow($0) }
                    }
                    if !recentStops.isEmpty {
                        header("Recherches récentes")
                        ForEach(recentStops) { stopRow($0) }
                    }
                } else {
                    ForEach(results) { stopRow($0) }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .readableScrollContent()
        .scrollDismissesKeyboard(.interactively)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Rechercher un arrêt"))
        .searchingStops(query, results: $results)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .padding(.leading, 8)
            .padding(.top, 12)
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
                Spacer(minLength: 4)
                if stop.sloid == selection?.sloid {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .basicElementBackground(minHeight: 54, selected: stop.sloid == selection?.sloid)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
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

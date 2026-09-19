//
//  RegularTripsView.swift
//  tpg Next
//
//  Les prochains trajets réguliers, avec leur état en direct, et la liste des trajets enregistrés.
//

import SwiftUI
import tpgNextFunc

/// L'écran des trajets réguliers (ouvert aussi depuis une notification).
struct RegularTripsView: View {
    @Environment(\.openRoute) private var openRoute

    var body: some View {
        ScrollView {
            RegularTripsContent { openRoute(.trip($0)) }
                .padding(.horizontal, 15)
                .padding(.bottom, 30)
        }
        .readableScrollContent()
        .navigationTitle("Trajets réguliers")
    }
}

/// Prochains trajets puis trajets enregistrés. `onSelect` ouvre le trajet du jour.
struct RegularTripsContent: View {
    @Environment(RegularTripsModel.self) private var model
    @Environment(\.displayTime) private var now
    /// Nombre de prochains trajets affichés.
    var upcomingLimit = 10
    let onSelect: (TripEvent) -> Void

    @State private var editing: RegularTrip?
    /// Le trajet en cours de chargement après un toucher.
    @State private var opening: String?

    var body: some View {
        let upcoming = Array(model.upcoming(after: now).prefix(upcomingLimit))
        VStack(alignment: .leading, spacing: 8) {
            if model.regularTrips.isEmpty {
                RegularTripsEmptyView()
            } else {
                sectionTitle("Prochains trajets")
                if upcoming.isEmpty {
                    Text("Aucun trajet dans les sept prochains jours.")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                }
                ForEach(upcoming) { occurrence in
                    if let trip = model.trip(for: occurrence), let displayed = model.displayedTrip(for: occurrence) {
                        Button { open(occurrence, displayed: displayed) } label: {
                            UpcomingRegularTripCard(occurrence: occurrence, trip: trip, displayed: displayed,
                                                    state: model.state(of: occurrence), isOpening: opening == occurrence.id)
                        }
                        .buttonStyle(.plain)
                        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 30))
                        .contextMenu {
                            Button {
                                withAnimation { model.skip(occurrence) }
                            } label: {
                                Label("Pas de trajet ce jour-là", systemImage: "calendar.badge.minus")
                            }
                            Button {
                                editing = trip
                            } label: {
                                Label("Modifier le trajet régulier", systemImage: "pencil")
                            }
                        }
                    }
                }

                sectionTitle("Mes trajets réguliers")
                    .padding(.top, 10)
                ForEach(model.regularTrips) { trip in
                    Button { editing = trip } label: {
                        RegularTripRow(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 30))
                    .contextMenu {
                        Button {
                            editing = trip
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            withAnimation { model.remove(trip) }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .sheet(item: $editing) { trip in
            RegularTripEditor(trip: trip)
                .environment(model)
        }
        // Le temps réel des trajets proches, tant que la liste est affichée.
        .periodicRefresh(every: .seconds(60)) { _ in
            Task { await model.refresh() }
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.title3).bold()
            .padding(.horizontal, 10)
            .padding(.top, 6)
    }

    /// Le trajet du jour s'il est connu ; sinon il est demandé d'abord, et l'itinéraire prévu
    /// s'ouvre si OJP ne répond pas.
    private func open(_ occurrence: RegularTripOccurrence, displayed: TripEvent) {
        if case .found(let match, _) = model.state(of: occurrence) {
            onSelect(match.trip)
            return
        }
        guard opening == nil else { return }
        opening = occurrence.id
        Task {
            let match = await model.resolve(occurrence, force: true)
            opening = nil
            onSelect(match?.trip ?? displayed)
        }
    }
}

/// Un prochain trajet : le jour, l'état en direct et l'itinéraire du jour (ou prévu).
struct UpcomingRegularTripCard: View {
    let occurrence: RegularTripOccurrence
    let trip: RegularTrip
    let displayed: TripEvent
    let state: RegularTripsModel.LiveState?
    var isOpening = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayLabel)
                        .font(.headline)
                    Text(trip.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isOpening {
                    ProgressView()
                } else {
                    RegularTripStatusBadge(state: state)
                }
            }
            SavedTripView(event: displayed)
            if case .found(let match, _) = state {
                let changes = RegularTripAlerts.changes(in: match)
                if !changes.isEmpty {
                    Label {
                        Text(changes.joined(separator: "\n"))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding(15)
        .background(BasicCard(cornerRadius: 30))
        .padding(.vertical, 2)
    }

    /// « Aujourd'hui », « Demain », « lundi 21 septembre ».
    private var dayLabel: String {
        let calendar = Calendar.current
        let date = occurrence.plannedDeparture
        if calendar.isDateInToday(date) { return String(localized: "Aujourd'hui") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Demain") }
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return text.prefix(1).capitalized + text.dropFirst()
    }
}

/// L'état du trajet du jour, en une capsule.
struct RegularTripStatusBadge: View {
    let state: RegularTripsModel.LiveState?

    var body: some View {
        let (text, symbol, color) = content
        Label(text, systemImage: symbol)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .lineLimit(1)
    }

    private var content: (String, String, Color) {
        switch state {
        case nil:
            return (String(localized: "Horaire prévu"), "calendar", .secondary)
        case .loading:
            return (String(localized: "Vérification…"), "arrow.triangle.2.circlepath", .secondary)
        case .notFound:
            return (String(localized: "Aucun trajet"), "xmark.octagon.fill", .red)
        case .failed:
            return (String(localized: "Hors ligne"), "wifi.slash", .secondary)
        case .found(let match, _):
            let status = match.status
            switch match.kind {
            case .alternative:
                return (String(localized: "Trajet modifié"), "arrow.triangle.branch", .orange)
            case .shifted:
                return (String(localized: "Horaire modifié"), "clock.badge.exclamationmark", .orange)
            case .usual:
                break
            }
            if !status.riskyConnections.isEmpty {
                return (String(localized: "Correspondance"), "exclamationmark.triangle.fill", .red)
            }
            if !status.disruptedLines.isEmpty {
                return (String(localized: "Perturbé"), "exclamationmark.triangle.fill", .orange)
            }
            if status.departureDelay >= 2 {
                return (String(localized: "+\(status.departureDelay) min"), "clock.fill", status.departureDelay >= 5 ? .red : .orange)
            }
            if !status.hasRealtime {
                return (String(localized: "Horaire"), "calendar", .secondary)
            }
            return (String(localized: "À l'heure"), "checkmark.circle.fill", .green)
        }
    }
}

/// Un trajet régulier enregistré : nom, jours, heure, lignes et notifications.
struct RegularTripRow: View {
    let trip: RegularTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.displayName)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if trip.reminderMinutes != nil || trip.alertsEnabled {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Notifications activées")
                }
            }
            (trip.anchor == .departure
                ? Text("\(trip.daysSummary) · départ \(trip.timeText)")
                : Text("\(trip.daysSummary) · arrivée \(trip.timeText)"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !trip.legs.isEmpty {
                RegularTripLines(snapshot: trip.snapshot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(BasicCard(cornerRadius: 30))
        .padding(.vertical, 2)
    }
}

/// Aucun trajet régulier : comment en créer un.
struct RegularTripsEmptyView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Aucun trajet régulier")
                .font(.headline)
            Text("Dans un itinéraire, touchez « Répéter chaque semaine » : le trajet reviendra ici chaque jour choisi, avec les retards en direct et un rappel avant de partir.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(25)
    }
}

// MARK: - Aperçus

private enum RegularTripsPreview {
    static let work = RegularTrip(trip: PreviewData.tripWithTransfer, weekdays: Weekday.workdays, name: "Travail")
    static let sport = RegularTrip(trip: PreviewData.directTrip, weekdays: [.tuesday, .thursday], anchor: .arrival,
                                   reminderMinutes: nil, alertsEnabled: false)

    /// Le premier trajet de chaque trajet régulier, avec un état différent.
    static var model: RegularTripsModel {
        var live: [String: RegularTripsModel.LiveState] = [:]
        if let next = work.occurrences(after: Date()).first {
            var delayed = work.plannedTrip(for: next)
            if let index = delayed.legs.firstIndex(where: { !$0.transfer && !$0.publishedLineName.isEmpty }),
               let board = OJPDate.date(from: delayed.legs[index].legBoardTimetableTime) {
                delayed.legs[index].legBoardEstimatedTime = OJPDate.string(from: board.addingTimeInterval(6 * 60))
            }
            live[next.id] = .found(RegularTripMatch(trip: delayed, kind: .usual), updated: Date())
        }
        return RegularTripsModel(previewTrips: [work, sport], live: live)
    }
}

#Preview("Trajets réguliers") {
    RegularTripsView()
        .environment(RegularTripsPreview.model)
        .previewEnvironment()
}

#Preview("Trajets réguliers — iPad", traits: .iPadLandscape) {
    RegularTripsView()
        .environment(RegularTripsPreview.model)
        .previewEnvironment()
}

#Preview("Trajets réguliers — vide") {
    RegularTripsView()
        .environment(RegularTripsModel(previewTrips: []))
        .previewEnvironment()
}

#Preview("Badges d'état") {
    let trip = PreviewData.tripWithTransfer
    VStack(alignment: .leading) {
        RegularTripStatusBadge(state: nil)
        RegularTripStatusBadge(state: .loading)
        RegularTripStatusBadge(state: .found(RegularTripMatch(trip: trip, kind: .usual), updated: Date()))
        RegularTripStatusBadge(state: .found(RegularTripMatch(trip: trip, kind: .shifted(minutes: 4)), updated: Date()))
        RegularTripStatusBadge(state: .found(RegularTripMatch(trip: trip, kind: .alternative), updated: Date()))
        RegularTripStatusBadge(state: .notFound)
        RegularTripStatusBadge(state: .failed)
    }
    .padding()
    .previewEnvironment(navigation: false)
}

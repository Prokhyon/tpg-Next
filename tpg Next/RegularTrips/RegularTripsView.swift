//
//  RegularTripsView.swift
//  tpg Next
//
//  Les cartes des trajets réguliers : un prochain trajet avec son état en direct, un trajet
//  enregistré. La liste elle-même est l'agenda de `SavedTripsView`.
//

import SwiftUI
import tpgNextFunc

/// Un prochain trajet, dans l'agenda déjà groupé par jour : son nom, l'état en direct et
/// l'itinéraire du jour (ou prévu). Sans fond : l'agenda le pose avec les actions.
struct UpcomingRegularTripCard: View {
    let occurrence: RegularTripOccurrence
    let trip: RegularTrip
    let displayed: TripEvent
    let state: RegularTripsModel.LiveState?
    var isOpening = false
    /// Suivi en direct sur l'écran verrouillé.
    var isLive = false
    /// Un autre itinéraire que le trajet habituel a été choisi pour ce jour.
    var isChosen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    if isLive {
                        Image(systemName: "inset.filled.circle")
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Suivi en direct")
                    }
                    Label(trip.displayName, systemImage: "repeat")
                        .lineLimit(1)
                }
                .font(.headline)
                Spacer()
                // L'état est sur la languette de la carte (`AgendaCard`).
                if isOpening {
                    ProgressView()
                }
            }
            if isChosen {
                Label("Autre trajet choisi pour ce jour", systemImage: "arrow.triangle.swap")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
            }
            SavedTripView(event: displayed)
            if case .found(let match, _) = state {
                RegularTripChanges(changes: RegularTripAlerts.changes(in: match))
            }
        }
    }
}

/// Retards, horaire modifié, parcours perturbé : une phrase par changement.
struct RegularTripChanges: View {
    let changes: [String]

    var body: some View {
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

/// L'état du trajet en languette : un petit rectangle de couleur qui dépasse du haut de la
/// carte, comme un marque-page. Le bas est caché sous la carte.
struct BookmarkTab: View {
    let badge: UpcomingTrip.Badge
    /// La partie qui dépasse ; elle grandit avec le texte (`AgendaCard` la mesure).
    var visibleHeight: CGFloat = 24
    static let hiddenHeight: CGFloat = 12

    var body: some View {
        Label(badge.text, systemImage: badge.symbol)
            .font(.caption.bold())
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: visibleHeight)
            .padding(.bottom, Self.hiddenHeight)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                    .fill(badge.tone.tabColor.gradient)
            )
            .accessibilityElement(children: .combine)
    }
}

extension UpcomingTrip.Badge.Tone {
    /// Pleine, sous un texte blanc : le gris secondaire y serait trop pâle.
    var tabColor: Color {
        self == .neutral ? .gray : color
    }
}

/// L'état du trajet du jour, en une capsule.
struct RegularTripStatusBadge: View {
    let state: RegularTripsModel.LiveState?
    /// Un itinéraire enregistré : ne plus le retrouver veut dire qu'il n'est plus possible.
    var isSavedTrip = false

    var body: some View {
        let badge = Self.badge(for: state, isSavedTrip: isSavedTrip)
        let color = badge.tone.color
        Label(badge.text, systemImage: badge.symbol)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .lineLimit(1)
    }

    /// Le texte, le symbole et le ton : repris tels quels par le widget « Prochain trajet ».
    static func badge(for state: RegularTripsModel.LiveState?, isSavedTrip: Bool) -> UpcomingTrip.Badge {
        switch state {
        case nil:
            return .init(text: String(localized: "Horaire prévu"), symbol: "calendar", tone: .neutral)
        case .loading:
            return .init(text: String(localized: "Vérification…"), symbol: "arrow.triangle.2.circlepath", tone: .neutral)
        case .notFound:
            return .init(text: String(localized: "Aucun trajet"), symbol: "xmark.octagon.fill", tone: .critical)
        case .failed:
            return .init(text: String(localized: "Hors ligne"), symbol: "wifi.slash", tone: .neutral)
        case .found(let match, _):
            let status = match.status
            switch match.kind {
            case .alternative where isSavedTrip:
                return .init(text: String(localized: "Plus proposé"), symbol: "xmark.circle.fill", tone: .critical)
            case .alternative:
                return .init(text: String(localized: "Trajet modifié"), symbol: "arrow.triangle.branch", tone: .warning)
            case .shifted:
                return .init(text: String(localized: "Horaire modifié"), symbol: "clock.badge.exclamationmark", tone: .warning)
            case .usual:
                break
            }
            if !status.riskyConnections.isEmpty {
                return .init(text: String(localized: "Correspondance"), symbol: "exclamationmark.triangle.fill", tone: .critical)
            }
            if !status.disruptedLines.isEmpty {
                return .init(text: String(localized: "Perturbé"), symbol: "exclamationmark.triangle.fill", tone: .warning)
            }
            if status.departureDelay >= 2 {
                return .init(text: String(localized: "+\(status.departureDelay) min"), symbol: "clock.fill",
                             tone: status.departureDelay >= 5 ? .critical : .warning)
            }
            if !status.hasRealtime {
                return .init(text: String(localized: "Horaire"), symbol: "calendar", tone: .neutral)
            }
            return .init(text: String(localized: "À l'heure"), symbol: "checkmark.circle.fill", tone: .good)
        }
    }
}

/// Un trajet régulier enregistré : nom, jours, heure, lignes et notifications.
struct RegularTripRow: View {
    let trip: RegularTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                trip.displayTitle
                    .font(.headline.weight(.regular))
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
    var onCreate: (() -> Void)?

    var body: some View {
        AgendaEmptyView(symbol: "calendar.badge.clock", title: "Aucun trajet régulier",
                        message: "Créez-en un ici, ou touchez longuement un itinéraire puis « Répéter chaque semaine » : le trajet reviendra chaque jour choisi, avec les retards en direct et un rappel avant de partir.",
                        onCreate: onCreate)
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
    SavedTripsPage(filter: .regular)
        .environment(RegularTripsPreview.model)
        .previewEnvironment()
}

#Preview("Trajets réguliers — iPad", traits: .iPadLandscape) {
    SavedTripsPage(filter: .regular)
        .environment(RegularTripsPreview.model)
        .previewEnvironment()
}

#Preview("Trajets réguliers — vide") {
    SavedTripsPage(filter: .regular)
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
        RegularTripStatusBadge(state: .found(RegularTripMatch(trip: trip, kind: .alternative), updated: Date()), isSavedTrip: true)
        RegularTripStatusBadge(state: .notFound)
        RegularTripStatusBadge(state: .failed)
    }
    .padding()
    .previewEnvironment(navigation: false)
}

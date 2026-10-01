//
//  WatchNextTripWidget.swift
//  tpg Next Watch Widget
//
//  Le prochain trajet, régulier ou enregistré, en complication : quand partir, puis monter,
//  puis arriver. L'app montre laisse les trajets reçus de l'iPhone dans le groupe d'app
//  (`UpcomingTripsStorage`) ; la complication ne fait que les afficher.
//

import WidgetKit
import SwiftUI
import tpgNextFunc

struct WatchNextTripEntry: TimelineEntry {
    let date: Date
    /// Ceux qui ne sont pas encore arrivés à `date`, le prochain en tête.
    let trips: [UpcomingTrip]
}

struct WatchNextTripProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchNextTripEntry {
        WatchNextTripEntry(date: Date(), trips: [.sample()])
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchNextTripEntry) -> Void) {
        let trips = UpcomingTripsStorage.load().filter { $0.arrival > Date() }
        // Le sélecteur montre un exemple plutôt qu'une complication vide.
        completion(WatchNextTripEntry(date: Date(), trips: trips.isEmpty && context.isPreview ? [.sample()] : trips))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchNextTripEntry>) -> Void) {
        let trips = UpcomingTripsStorage.load()
        let timeline = NextTripTimeline.dates(for: trips)
        let entries = timeline.dates.map { date in
            WatchNextTripEntry(date: date, trips: trips.filter { $0.arrival > date })
        }
        completion(Timeline(entries: entries, policy: .after(timeline.refresh)))
    }
}

struct WatchNextTripWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: UpcomingTripsStorage.widgetKind, provider: WatchNextTripProvider()) { entry in
            WatchNextTripView(entry: entry)
        }
        .configurationDisplayName("Prochain trajet")
        .description("Quand partir pour votre prochain trajet régulier ou itinéraire enregistré.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

struct WatchNextTripView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchNextTripEntry

    private var trip: UpcomingTrip? { entry.trips.first }

    var body: some View {
        content
            .widgetURL(tripURL)
            .containerBackground(for: .widget) {
                // Pile intelligente seulement : les cadrans ignorent ce fond.
                if let trip, let line = trip.line {
                    Rectangle()
                        .fill(LineColors.lineColor(for: line, operatorName: trip.operatorName ?? "").gradient.opacity(0.5))
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            corner
        case .accessoryInline:
            inline
        default:
            rectangular
        }
    }

    // MARK: - Formats

    /// Le trajet en titre, quand partir, puis le véhicule à prendre (ou l'arrivée, une fois monté).
    @ViewBuilder private var rectangular: some View {
        if let trip {
            let countdown = trip.countdown
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    title(trip)
                        .font(.body.bold())
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if let badge = trip.badge {
                        Image(systemName: badge.symbol)
                            .font(.footnote)
                            .foregroundStyle(badge.tone.color)
                    }
                }
                Text(countdown.headline(at: entry.date))
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if countdown.phase(at: entry.date) != .onTheWay, let line = trip.line {
                    HStack(spacing: 5) {
                        BusLineIcon(lineName: line, operatorName: trip.operatorName ?? "", width: 30, height: 21)
                            .font(.system(.caption, weight: .bold))
                        Text(shortName(trip.lineDestination ?? trip.destination))
                            .font(.footnote)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if let boarding = trip.boarding {
                            Text(boarding, format: .dateTime.hour().minute())
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                } else {
                    Label {
                        Text(shortName(trip.destination))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "flag.checkered")
                    }
                    .font(.footnote)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aucun trajet prévu")
                    .font(.body.bold())
                Text("Créez-en un sur l'iPhone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Le prochain moment à viser : partir, monter ou arriver, et le temps qui reste.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let trip {
                let step = Step(trip: trip, at: entry.date)
                VStack(spacing: 0) {
                    step.icon
                        .font(.system(size: 11, weight: .bold))
                        .widgetAccentable()
                    Text(step.value)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if step.isMinutes {
                        Text("min")
                            .font(.system(size: 9, weight: .medium))
                    }
                }
                .padding(3)
            } else {
                Image(systemName: Step.emptySymbol)
                    .font(.title3)
            }
        }
    }

    private var corner: some View {
        Group {
            if let trip {
                let step = Step(trip: trip, at: entry.date)
                Text(step.isMinutes ? "\(step.value)'" : step.value)
                    .font(.title3.bold())
                    .monospacedDigit()
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text(trip.countdown.headline(at: entry.date))
                    }
            } else {
                Image(systemName: Step.emptySymbol)
                    .widgetLabel { Text("Aucun trajet prévu") }
            }
        }
    }

    private var inline: some View {
        Group {
            if let trip {
                Text(verbatim: "\(trip.countdown.headline(at: entry.date)) · \(trip.isRegular ? trip.title : shortName(trip.destination))")
            } else {
                Text("Aucun trajet prévu")
            }
        }
    }

    // MARK: - Textes

    /// « Travail » pour un trajet régulier ; le parcours pour un itinéraire enregistré.
    private func title(_ trip: UpcomingTrip) -> Text {
        trip.isRegular ? Text(trip.title) : Text(verbatim: "\(shortName(trip.origin)) → \(shortName(trip.destination))")
    }

    /// « Moillesulaz » pour « Thônex, Moillesulaz ».
    private func shortName(_ name: String) -> String {
        let parts = splitString(name, separator: ",")
        return parts.1.isEmpty ? parts.0 : parts.1
    }

    /// Toucher la complication ouvre le détail du trajet dans l'app (`ContentView.open(_:)`).
    private var tripURL: URL? {
        guard let trip else { return nil }
        var components = URLComponents()
        components.scheme = "tpgnext"
        components.host = "trip"
        components.queryItems = [URLQueryItem(name: "id", value: trip.id)]
        return components.url
    }
}

/// Ce que visent les petits formats : partir (avec la marche), monter, puis arriver.
private struct Step {
    static let emptySymbol = "point.topleft.down.to.point.bottomright.curvepath.fill"

    let icon: Image
    /// « 8 » (minutes) dans l'heure qui vient, l'heure (« 07:42 ») au-delà.
    let value: String
    let isMinutes: Bool

    init(trip: UpcomingTrip, at date: Date) {
        let countdown = trip.countdown
        let target: Date
        switch countdown.phase(at: date) {
        case .walkToStop:
            icon = Image(systemName: "figure.walk")
            target = countdown.leaving
        case .waitForDeparture:
            icon = transportIcon(with: trip.event?.vehicleLegs.first?.transportTypeName ?? "Bus")
            target = countdown.boarding ?? countdown.leaving
        case .onTheWay:
            icon = Image(systemName: "flag.checkered")
            target = countdown.arrival
        @unknown default:
            icon = Image(systemName: "clock")
            target = countdown.leaving
        }
        let minutes = Int((target.timeIntervalSince(date) / 60).rounded(.up))
        if minutes < 60 {
            value = "\(max(0, minutes))"
            isMinutes = true
        } else {
            value = dateToString(with: target)
            isMinutes = false
        }
    }
}

// MARK: - Aperçus

#Preview("Prochain trajet — rectangulaire", as: .accessoryRectangular) {
    WatchNextTripWidget()
} timeline: {
    WatchNextTripEntry(date: Date(), trips: [.sample()])
    WatchNextTripEntry(date: Date(), trips: [.sample(delay: 4)])
    WatchNextTripEntry(date: Date(), trips: [])
}

#Preview("Prochain trajet — rond", as: .accessoryCircular) {
    WatchNextTripWidget()
} timeline: {
    WatchNextTripEntry(date: Date(), trips: [.sample()])
}

#Preview("Prochain trajet — coin", as: .accessoryCorner) {
    WatchNextTripWidget()
} timeline: {
    WatchNextTripEntry(date: Date(), trips: [.sample()])
}

#Preview("Prochain trajet — en ligne", as: .accessoryInline) {
    WatchNextTripWidget()
} timeline: {
    WatchNextTripEntry(date: Date(), trips: [.sample()])
}

//
//  WatchDeparturesWidget.swift
//  tpg Next Watch Widget
//
//  Les prochains départs en complication et dans la pile intelligente. Le choix de l'arrêt,
//  la requête et la timeline sont ceux du widget iPhone (`DeparturesProvider`,
//  `SelectStopIntent`, partagés avec cette cible) : seules les vues sont propres à la montre.
//

import WidgetKit
import SwiftUI
import tpgNextFunc

@main
struct tpgNextWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchDeparturesWidget()
    }
}

struct WatchDeparturesWidget: Widget {
    let kind = "tpgNextWatchDepartures"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectStopIntent.self, provider: DeparturesProvider()) { entry in
            WatchDeparturesView(entry: entry)
        }
        .configurationDisplayName("Prochains départs")
        .description("Les prochains départs d'un arrêt, ou de l'arrêt le plus proche de vous.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

struct WatchDeparturesView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DeparturesEntry

    /// Les départs qui passent vraiment : un cadran n'a pas la place d'afficher « Supprimé »
    /// à la place d'un bus qui roule. Tous supprimés, ils restent affichés comme tels.
    private var shownEvents: [StopEvent] {
        let running = entry.events.filter { !$0.cancelled }
        return running.isEmpty ? entry.events : running
    }

    private var next: StopEvent? {
        entry.events.first { !$0.cancelled }
    }

    var body: some View {
        content
            .widgetURL(stopURL)
            .containerBackground(for: .widget) {
                // Pile intelligente seulement : les cadrans ignorent ce fond.
                if let next {
                    Rectangle()
                        .fill(LineColors.lineColor(for: next.lineName, operatorName: next.operatorName).gradient.opacity(0.5))
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

    /// L'arrêt en titre, puis ses deux prochains départs en colonnes : ligne, direction, minutes.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                if entry.distance != nil {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(shortName(entry.stop?.name ?? "tpg Next"))
                    .font(.system(.footnote, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Self.accent)
            .widgetAccentable()
            if entry.status == .ok {
                Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 2) {
                    ForEach(shownEvents.prefix(2), id: \.id) { event in
                        GridRow {
                            LineBadge(event: event)
                            Text(shortName(event.destination))
                                .font(.system(.footnote, weight: .medium))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            RemainingTime(event: event, date: entry.date)
                                .gridColumnAlignment(.trailing)
                        }
                    }
                }
            } else {
                Label(message, systemImage: statusSymbol)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// La ligne au-dessus des minutes.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let next {
                VStack(spacing: -1) {
                    Text(next.lineName)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                    timeText(next)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(4)
            } else {
                Image(systemName: statusSymbol)
            }
        }
    }

    /// Les minutes dans le coin, la ligne et sa direction sur l'arc.
    private var corner: some View {
        Group {
            if let next {
                timeText(next)
                    .font(.title3.bold())
                    .widgetCurvesContent()
                    .widgetLabel {
                        Text("\(next.lineName) → \(shortName(next.destination))")
                    }
            } else {
                Image(systemName: statusSymbol)
                    .widgetLabel {
                        Text(message)
                    }
            }
        }
    }

    private var inline: some View {
        Group {
            if let next {
                Text("\(next.lineName) → \(shortName(next.destination)) · \(timeText(next))")
            } else {
                Text(message)
            }
        }
    }

    // MARK: - Textes

    /// « 4' », « 14:05 », ou l'icône du véhicule quand il est à l'arrêt.
    private func timeText(_ event: StopEvent) -> Text {
        let display = departureDisplay(for: event, showTime: false, at: entry.date)
        if display == .atStop {
            return Text(transportIcon(with: event.transportType))
        }
        return Text(display.text)
    }

    /// La couleur d'accent de l'app montre (`AccentColor`), que l'extension n'embarque pas.
    static let accent = Color(.displayP3, red: 0.896, green: 0.539, blue: 0)

    /// « Rive » pour « Genève, Rive » : la commune ne tient pas dans une complication.
    private func shortName(_ name: String) -> String {
        let parts = splitString(name, separator: ",")
        return parts.1.isEmpty ? parts.0 : parts.1
    }

    /// Toucher la complication ouvre l'arrêt dans l'app (`ContentView.open(_:)`).
    private var stopURL: URL? {
        guard let stop = entry.stop else { return nil }
        var components = URLComponents()
        components.scheme = "tpgnext"
        components.host = "stop"
        components.queryItems = [URLQueryItem(name: "sloid", value: stop.sloid), URLQueryItem(name: "name", value: stop.name)]
        return components.url
    }

    private var message: LocalizedStringKey {
        switch entry.status {
        case .noLocation: "Position indisponible"
        case .indexMissing: "Ouvrez tpg Next sur la montre"
        case .sharedStorageUnavailable: "Données de l'app inaccessibles"
        case .noStopNearby: "Pas d'arrêt à proximité"
        case .noDepartures: "Pas de départ prévu"
        case .networkError: "Départs indisponibles"
        case .ok: ""
        }
    }

    private var statusSymbol: String {
        switch entry.status {
        case .noLocation: "location.slash"
        case .indexMissing: "arrow.down.circle"
        case .sharedStorageUnavailable: "exclamationmark.triangle"
        case .noStopNearby: "mappin.slash"
        case .noDepartures: "moon.zzz"
        case .networkError: "wifi.slash"
        case .ok: "bus"
        }
    }
}

// MARK: - Morceaux

/// Le numéro de ligne sur sa couleur, comme sur les arrêts. Sur un cadran teinté, les couleurs
/// disparaissent : un fond discret le remplace.
private struct LineBadge: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.self) private var environment
    let event: StopEvent

    var body: some View {
        let color = LineColors.lineColor(for: event.lineName, operatorName: event.operatorName)
        let fullColor = renderingMode == .fullColor
        Text(event.lineName)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(fullColor ? textColor(on: color) : .primary)
            .padding(.horizontal, 3)
            .frame(minWidth: 24, minHeight: 17)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(fullColor ? color : Color.primary.opacity(0.25)))
    }

    /// Noir ou blanc, selon ce qui contraste le plus avec la couleur de la ligne (WCAG) :
    /// le jaune de la ligne 2 demande du noir, le bleu de la 12 du blanc.
    private func textColor(on color: Color) -> Color {
        let resolved = color.resolve(in: environment)
        let luminance = 0.2126 * Double(resolved.linearRed) + 0.7152 * Double(resolved.linearGreen)
            + 0.0722 * Double(resolved.linearBlue)
        return (luminance + 0.05) / 0.05 > 1.05 / (luminance + 0.05) ? .black : .white
    }
}

/// « 4 min » avec le chiffre en grand ; l'heure au-delà d'une heure, le véhicule quand il est là.
private struct RemainingTime: View {
    let event: StopEvent
    let date: Date

    var body: some View {
        let display = departureDisplay(for: event, showTime: false, at: date)
        Group {
            switch display {
            case .minutes(let minutes, let delayed):
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(minutes, format: .number)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    Text("min")
                        .font(.system(.caption2, weight: .medium))
                }
                .foregroundStyle(delayed ? .orange : .primary)
            case .lessThanAMinute:
                Text("< 1 min")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            case .atStop:
                transportIcon(with: event.transportType)
                    .font(.system(.footnote, weight: .semibold))
            case .cancelled:
                Text(display.text)
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(.red)
            default:
                Text(display.text)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
    }
}

// MARK: - Aperçu

/// Ce que montre l'écran de choix des complications, via `DeparturesProvider.placeholder(in:)`.
enum PreviewData {
    static let stop = Stop(name: "Genève, Rive", sloid: "ch:1:sloid:87061", codedidoc: "8587061", country: "CH", canton: "GE",
                           meansOfTransport: "BUS|TRAM", wgs84Coordinates: Coordinates(lon: 6.152, lat: 46.203))

    static let events: [StopEvent] = [
        event(line: "12", destination: "Genève, Moillesulaz", quay: "B", minutes: 2, type: "Tram"),
        event(line: "2", destination: "Genève, Genève-Plage", quay: "A", minutes: 4, type: "Bus"),
        event(line: "6", destination: "Vernier, Village", quay: "D", minutes: 6, type: "Bus"),
    ]

    private static func event(line: String, destination: String, quay: String, minutes: Int, type: String) -> StopEvent {
        let time = OJPDate.string(from: Date().addingTimeInterval(Double(minutes) * 60))
        return StopEvent(stopPointName: stop.name, stopId: stop.sloid, plannedQuay: quay, timetabledTime: time, estimatedTime: time,
                         lineName: line, origin: "", destination: destination, transportType: type,
                         operatorName: "Transports Publics Genevois", journeyRef: "preview-\(line)", operatingDayRef: "")
    }

    static func entry(_ status: DeparturesEntry.Status = .ok) -> DeparturesEntry {
        DeparturesEntry(date: Date(), stop: stop, events: status == .ok ? events : [], status: status, distance: 120)
    }
}

#Preview("Rectangulaire", as: .accessoryRectangular) {
    WatchDeparturesWidget()
} timeline: {
    PreviewData.entry()
    PreviewData.entry(.networkError)
}

#Preview("Rond", as: .accessoryCircular) {
    WatchDeparturesWidget()
} timeline: {
    PreviewData.entry()
}

#Preview("Coin", as: .accessoryCorner) {
    WatchDeparturesWidget()
} timeline: {
    PreviewData.entry()
}

#Preview("En ligne", as: .accessoryInline) {
    WatchDeparturesWidget()
} timeline: {
    PreviewData.entry()
}

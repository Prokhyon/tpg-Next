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
        WatchNextTripWidget()
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
        if entry.isGalleryPreview && family != .accessoryRectangular {
            // Le sélecteur propose un réglage par favori : sans place pour le nom de l'arrêt,
            // des départs d'exemple les rendaient tous identiques.
            galleryIdentity
        } else {
            familyContent
        }
    }

    @ViewBuilder private var familyContent: some View {
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

    /// Le réglage d'une complication : la flèche pour l'arrêt le plus proche, l'étoile pour un favori.
    private var settingSymbol: String {
        entry.distance != nil ? "location.fill" : "star.fill"
    }

    /// « Proche » ou le nom du favori, à la place des départs, dans le sélecteur.
    private var settingName: String {
        entry.distance != nil ? String(localized: "Proche") : shortName(entry.stop?.name ?? "")
    }

    @ViewBuilder private var galleryIdentity: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: settingSymbol)
                        .font(.system(size: 12, weight: .bold))
                        .widgetAccentable()
                    Text(settingName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
                .padding(4)
            }
        case .accessoryCorner:
            Image(systemName: settingSymbol)
                .font(.title3.bold())
                .widgetCurvesContent()
                .widgetLabel { Text(settingName) }
        default:
            Text("\(Image(systemName: settingSymbol)) \(settingName)")
        }
    }

    /// L'arrêt en titre, puis ses deux prochains départs en colonnes : ligne, direction, temps.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                if entry.stop != nil {
                    Image(systemName: settingSymbol)
                        .font(.system(size: 10, weight: .semibold))
                }
                StopTitle(name: entry.stop?.name ?? "tpg Next")
            }
            if entry.status == .ok {
                Grid(alignment: .leading, horizontalSpacing: 5, verticalSpacing: 3) {
                    ForEach(shownEvents.prefix(2), id: \.id) { event in
                        GridRow {
                            BusLineIcon(lineName: event.lineName, operatorName: event.operatorName, width: 30, height: 21)
                                .font(.system(.caption, weight: .bold))
                                .gridColumnAlignment(.center)
                            Text(shortName(event.destination))
                                .font(.footnote)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            DepartureTime(event: event, date: entry.date)
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

/// Le nom entier de l'arrêt sur une ligne, la commune en régulier et l'arrêt en gras :
/// « Genève **Rive** ». Trop long, la commune disparaît.
private struct StopTitle: View {
    let name: String

    var body: some View {
        let parts = splitString(name, separator: ",")
        Group {
            if parts.1.isEmpty {
                Text(parts.0).bold()
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        Text(parts.0)
                        Text(parts.1).bold()
                    }
                    Text(parts.1).bold()
                }
            }
        }
        .font(.body)
        .lineLimit(1)
    }
}

/// Le temps restant comme dans l'app (« 4' », « < 1' », « 14:05 »), toujours dans la même
/// police : pas de rétrécissement d'une ligne à l'autre selon ce qui est affiché.
private struct DepartureTime: View {
    let event: StopEvent
    let date: Date

    var body: some View {
        let display = departureDisplay(for: event, showTime: false, at: date)
        Group {
            switch display {
            case .atStop:
                Text(transportIcon(with: event.transportType))
            case .cancelled:
                Text(display.text)
                    .foregroundStyle(.red)
            default:
                Text(display.text)
                    .foregroundStyle(display.isHighlighted ? .orange : .primary)
            }
        }
        .font(.system(.body, design: .rounded, weight: .semibold))
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
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

#Preview("Sélecteur — favori", as: .accessoryCircular) {
    WatchDeparturesWidget()
} timeline: {
    DeparturesEntry(date: Date(), stop: PreviewData.stop, events: PreviewData.events, status: .ok, distance: nil, isGalleryPreview: true)
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

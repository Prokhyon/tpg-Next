//
//  DeparturesWidgetView.swift
//  tpg Next Widget
//
//  Created by Loris Thomas on 26.08.2026.
//

import SwiftUI
import WidgetKit
import CoreLocation
import tpgNextFunc

struct DeparturesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DeparturesEntry

    /// Deux départs sur le petit format, trois sur le moyen, sept sur le grand.
    private var rowCount: Int {
        switch family {
        case .systemSmall: 3
        case .systemLarge: 7
        default: 3
        }
    }

    /// WidgetKit impose 16 pt de marge par défaut, trop large pour des lignes de
    /// départ. `contentMarginsDisabled()` les retire et on reprend la main ici.
    /// C'est le seul endroit à toucher pour resserrer ou aérer le contenu.
    private let contentInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    /// Le petit format n'a pas la place de 16 pt de chaque côté.
    private let smallContentInsets = EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let stop = entry.stop {
                HeaderView(stop: stop, distance: entry.distance, compact: family == .systemSmall)
            }

            if entry.status == .ok {
                VStack(spacing: 4) {
                    ForEach(entry.events.prefix(rowCount), id: \.id) { event in
                        // Le petit format ignore `Link` : tout le widget ouvre l'arrêt,
                        // avec une ligne plus serrée.
                        // Ailleurs, tout tap qui ne tombe pas sur un `Link` retombe sur
                        // `widgetURL`, donc sur la page de l'arrêt.
                        if family == .systemSmall {
                            CompactDepartureRow(event: event, referenceDate: entry.date)
                        } else if let lineURL = lineLink(for: event) {
                            Link(destination: lineURL) {
                                DepartureRow(event: event, referenceDate: entry.date)
                            }
                            .foregroundStyle(.primary)
                        } else {
                            DepartureRow(event: event, referenceDate: entry.date)
                        }
                    }
                    // Aligne la liste en haut : sans ça une liste courte flotte
                    // au milieu d'un cadre prévu pour plus de départs.
                    Spacer(minLength: 0)
                }
            } else {
                StatusView(status: entry.status)
            }
        }
        .padding(family == .systemSmall ? smallContentInsets : contentInsets)

        .widgetURL(deepLink)
        // Obligatoire depuis iOS 17 : sans ça WidgetKit refuse de dessiner le widget
        // (« Widget needs to adopt container background »). C'est aussi ce qui permet
        // au système de retirer le fond en mode veille ou sur l'écran verrouillé.
//        .containerBackground(for: .widget) {
//            LinearGradient(colors: [.color1, .color1],
//                           startPoint: .topLeading,
//                           endPoint: .bottomTrailing)
//        }
        .containerBackground(.color1, for: .widget)
    }

    /// Ouvre la page de la ligne pour ce départ. `nil` sans `journeyRef` :
    /// la ligne reste alors sur le lien de l'arrêt plutôt que d'ouvrir un écran vide.
    private func lineLink(for event: StopEvent) -> URL? {
        guard let stop = entry.stop, !event.journeyRef.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "tpgnext"
        components.host = "line"
        components.queryItems = [
            URLQueryItem(name: "journeyRef", value: event.journeyRef),
            URLQueryItem(name: "operatingDayRef", value: event.operatingDayRef),
            URLQueryItem(name: "line", value: event.lineName),
            URLQueryItem(name: "destination", value: event.destination),
            URLQueryItem(name: "transportType", value: event.transportType),
            URLQueryItem(name: "operator", value: event.operatorName),
            URLQueryItem(name: "sloid", value: stop.sloid),
            URLQueryItem(name: "name", value: stop.name)
        ]
        return components.url
    }

    /// Ouvre l'arrêt affiché dans l'app ; à défaut, l'app tout court.
    private var deepLink: URL? {
        guard let stop = entry.stop, !stop.sloid.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "tpgnext"
        components.host = "stop"
        components.queryItems = [
            URLQueryItem(name: "sloid", value: stop.sloid),
            URLQueryItem(name: "name", value: stop.name)
        ]
        return components.url
    }
}

// MARK: - En-tête

struct HeaderView: View {
    let stop: Stop
    let distance: CLLocationDistance?
    /// Petit format : la distance chiffrée prendrait la place du nom, seule l'icône reste.
    var compact = false

    var body: some View {
        HStack(alignment: .center) {
            StopNameView(stop.name, style: .widget)
            Spacer(minLength: 4)
            if distance != nil, compact {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let distance {
                Label("\(Int(distance.rounded())) m", systemImage: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            } else if stop.meansOfTransport.contains("TRAIN") {
                Image(systemName: "lightrail").font(.caption)
            } else if stop.meansOfTransport.contains("BOAT") {
                Image(systemName: "ferry").font(.caption)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Ligne de départ

struct DepartureRow: View {
    let event: StopEvent
    /// L'instant de l'entrée de timeline, pas l'heure courante : le widget est dessiné
    /// à l'avance et le décompte doit correspondre au moment où il sera affiché.
    let referenceDate: Date

    /// « Thônex, Vallard » devient « Vallard » : la commune ne tient pas dans un widget.
    private var shortDestination: String { Self.shortDestination(event.destination) }

    static func shortDestination(_ destination: String) -> String {
        let split = splitString(destination, separator: ",")
        return split.1.isEmpty ? split.0 : split.1
    }

    var body: some View {
        let departure = departureDisplay(for: event, showTime: false, at: referenceDate)
        HStack(spacing: 6) {
            BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                .font(.caption)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
            Text(shortDestination)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            DepartureTimeView(departure, transportType: event.transportType)
                .font(.caption)
                .bold()
                .lineLimit(1)
            QuayIcon(quay: event.plannedQuay, dimsUnknown: true)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background { RowBackground() }
    }
}

/// Le petit format : ligne à gauche, destination au centre sur deux lignes au
/// besoin, décompte à droite avec le quai en dessous.
struct CompactDepartureRow: View {
    let event: StopEvent
    let referenceDate: Date

    var body: some View {
        let departure = departureDisplay(for: event, showTime: false, at: referenceDate)
        HStack(spacing: 6) {
            BusLineIcon(lineName: event.lineName, operatorName: event.operatorName, width: 30, height: 20)
                .font(.caption)
                
            Text(DepartureRow.shortDestination(event.destination))
                .font(.caption2)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
//            VStack(alignment: .center, spacing: 1) {
                DepartureTimeView(departure, transportType: event.transportType)
                    .font(.caption)
                    .bold()
                    .lineLimit(1)
                QuayIcon(quay: event.plannedQuay, dimsUnknown: true)
                    .font(.caption2)
//            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background { RowBackground() }
    }
}

/// Le fond d'une ligne, plus discret quand l'écran d'accueil est teinté ou transparent.
struct RowBackground: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var body: some View {
        switch widgetRenderingMode {
        case .fullColor:
            BasicElement(transparent: true)
        case .accented:
            BasicElement().opacity(0.1)
        case .vibrant:
            BasicElement().opacity(0.2)
        default:
            BasicElement().opacity(0.5)
        }
    }
}

// MARK: - États sans départ

struct StatusView: View {
    let status: DeparturesEntry.Status

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Image(systemName: symbol).font(.title3).foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var symbol: String {
        switch status {
        case .noLocation: return "location.slash"
        case .indexMissing: return "arrow.down.circle"
        case .sharedStorageUnavailable: return "exclamationmark.triangle"
        case .noStopNearby: return "mappin.slash"
        case .noDepartures: return "moon.zzz"
        case .networkError: return "wifi.slash"
        case .ok: return "bus"
        }
    }

    private var message: LocalizedStringKey {
        switch status {
        case .noLocation: return "Position indisponible"
        case .indexMissing: return "Ouvrez l'app pour préparer le widget"
        case .sharedStorageUnavailable: return "Widget sans accès aux données de l'app"
        case .noStopNearby: return "Pas d'arrêt à proximité"
        case .noDepartures: return "Pas de départ prévu"
        case .networkError: return "Départs indisponibles"
        case .ok: return ""
        }
    }
}

// MARK: - Aperçu

enum PreviewData {
    static let stop = Stop(name: "Genève, Rive",
                           sloid: "ch:1:sloid:87061",
                           codedidoc: "8587061",
                           country: "CH",
                           canton: "GE",
                           meansOfTransport: "BUS|TRAM",
                           wgs84Coordinates: Coordinates(lon: 6.152, lat: 46.203))

    /// Ce que montre la galerie de widgets, via `placeholder(in:)`.
    /// Il en faut au moins autant que le grand format affiche de lignes (7),
    /// sinon l'aperçu de la galerie apparaît à moitié vide. Les numéros sont
    /// choisis pour couvrir des couleurs tpg différentes.
    static let events: [StopEvent] = [
        event(line: "12", destination: "Genève, Moillesulaz", quay: "B", minutes: 2),
        event(line: "2", destination: "Genève, Genève-Plage", quay: "A", minutes: 4),
        event(line: "6", destination: "Vernier, Village", quay: "D", minutes: 6),
        event(line: "9", destination: "Chêne-Bourg, Petit-Bel-Air", quay: "N", minutes: 8),
        event(line: "25", destination: "Thônex, Vallard", quay: "C", minutes: 11),
        event(line: "17", destination: "Onex, Onex-Rive", quay: "A", minutes: 13),
        event(line: "1", destination: "Genève, Hôpital", quay: "E", minutes: 16),
        event(line: "18", destination: "Carouge, Grand-Lancy", quay: "F", minutes: 19)
    ]

    private static func event(line: String, destination: String, quay: String, minutes: Int) -> StopEvent {
        let time = OJPDate.string(from: Date().addingTimeInterval(Double(minutes) * 60))
        return StopEvent(stopPointName: "Genève, Rive",
                         stopId: stop.sloid,
                         plannedQuay: quay,
                         timetabledTime: time,
                         estimatedTime: time,
                         lineName: line,
                         origin: "",
                         destination: destination,
                         transportType: "Bus",
                         operatorName: "Transports Publics Genevois",
                         journeyRef: "preview-\(line)",
                         operatingDayRef: "")
    }
}

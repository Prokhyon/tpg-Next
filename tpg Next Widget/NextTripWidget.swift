//
//  NextTripWidget.swift
//  tpg Next Widget
//
//  Le prochain trajet, régulier ou enregistré : quand partir, l'itinéraire, ce qui a changé.
//  L'app laisse les trajets dans le groupe d'app (`UpcomingTripsStorage`) ; le widget se
//  contente de les afficher, avec un décompte minute par minute avant le départ.
//

import WidgetKit
import SwiftUI
import tpgNextFunc

struct NextTripEntry: TimelineEntry {
    let date: Date
    /// Ceux qui ne sont pas encore arrivés à `date`, le prochain en tête.
    let trips: [UpcomingTrip]
}

struct NextTripProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextTripEntry {
        NextTripEntry(date: Date(), trips: [Self.sample])
    }

    func getSnapshot(in context: Context, completion: @escaping (NextTripEntry) -> Void) {
        let trips = UpcomingTripsStorage.load()
        // La galerie des widgets montre un exemple plutôt qu'un widget vide.
        completion(NextTripEntry(date: Date(), trips: trips.isEmpty && context.isPreview ? [Self.sample] : trips))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextTripEntry>) -> Void) {
        let trips = UpcomingTripsStorage.load()
        let timeline = NextTripTimeline.dates(for: trips)
        let entries = timeline.dates.map { date in
            NextTripEntry(date: date, trips: trips.filter { $0.arrival > date })
        }
        completion(Timeline(entries: entries, policy: .after(timeline.refresh)))
    }

    /// Un trajet avec une correspondance, qui part dans 8 min.
    static var sample: UpcomingTrip { .sample() }

    /// Le même, en retard : pour les aperçus.
    static var delayed: UpcomingTrip {
        var trip = UpcomingTrip.sample(delay: 4)
        trip.alert = "Retard de 4 min"
        trip.badge = .init(text: "+4 min", symbol: "clock.badge.exclamationmark.fill", tone: .warning)
        return trip
    }
}

struct NextTripWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: UpcomingTripsStorage.widgetKind, provider: NextTripProvider()) { entry in
            NextTripWidgetView(entry: entry)
        }
        .configurationDisplayName("Prochain trajet")
        .description("Quand partir pour votre prochain trajet régulier ou itinéraire enregistré.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

/// Le prochain trajet en widget : quand partir et quand arriver, puis le trajet de haut en bas,
/// comme le détail d'un itinéraire : le départ, les lignes, l'arrivée. Le moyen format pose le
/// trajet à droite des heures ; le petit, dessous, sans le départ.
struct NextTripWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextTripEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: inline
            case .accessoryRectangular: rectangular
            default:
                if let trip = entry.trips.first {
                    card(trip, compact: family == .systemSmall)
                } else {
                    empty
                }
            }
        }
        .widgetURL(entry.trips.first?.url ?? URL(string: "tpgnext://savedtrips"))
        .containerBackground(.color1, for: .widget)
    }

    // MARK: Carte

    /// Ce qui a changé n'est affiché que s'il reste de la place.
    private func card(_ trip: UpcomingTrip, compact: Bool) -> some View {
        ViewThatFits(in: .vertical) {
            if trip.alert != nil {
                cardContent(trip, compact: compact, showsAlert: true)
            }
            cardContent(trip, compact: compact, showsAlert: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func cardContent(_ trip: UpcomingTrip, compact: Bool, showsAlert: Bool) -> some View {
        if compact {
            VStack(alignment: .leading, spacing: 3) {
                times(trip, compact: true, showsAlert: showsAlert)
                Spacer(minLength: 4)
                route(trip, compact: true)
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    times(trip, compact: false, showsAlert: showsAlert)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                route(trip, compact: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Quand partir (et le retard du véhicule), la marche ou le quai, l'heure d'arrivée, et ce
    /// qui a changé.
    @ViewBuilder
    private func times(_ trip: UpcomingTrip, compact: Bool, showsAlert: Bool) -> some View {
        let countdown = trip.countdown
        let phase = countdown.phase(at: entry.date)
        let status = trip.event.map(RegularTripStatus.init(trip:))
        // Le retard du véhicule, tant qu'on ne l'a pas pris, au bout du texte même sur deux lignes.
        let delay = phase != .onTheWay ? status?.departureDelay ?? 0 : 0
        (Text(verbatim: countdown.headline(at: entry.date))
         + (delay >= 2 ? Text(verbatim: " +\(delay)'").foregroundStyle(.orange) : Text(verbatim: "")))
            .font((compact ? Font.headline : .title3).bold())
            .lineLimit(2)
            .minimumScaleFactor(0.7)
        if !compact {
            departureDetail(trip, phase: phase)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Arrivée à \(dateToString(with: trip.arrival))")
                .foregroundStyle(.secondary)
            if let status {
                DelayText(minutes: status.arrivalDelay)
            }
        }
        .font((compact ? Font.caption : .subheadline).monospacedDigit())
        .lineLimit(1)
        if showsAlert, let alert = trip.alert {
            Label(alert, systemImage: trip.badge?.tone == .critical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(trip.badge?.tone == .critical ? Color.red : .orange)
                .lineLimit(compact ? 1 : 2)
        }
    }

    /// À côté de l'heure : la marche tant qu'il faut partir, puis le quai.
    @ViewBuilder
    private func departureDetail(_ trip: UpcomingTrip, phase: TripCountdown.Phase) -> some View {
        if phase == .walkToStop, let minutes = trip.countdown.walkMinutes {
            Label("\(minutes) min à pied", systemImage: "figure.walk")
        } else if phase != .onTheWay, let quay = trip.quay {
            Text("Quai \(quay)")
        }
    }

    // MARK: Trajet

    private static let iconSize: CGFloat = 14

    /// Le départ, une barre aux couleurs des lignes avec leurs numéros, puis l'arrivée et son
    /// point de terminus. Le petit format ne garde que les lignes et l'arrivée.
    private func route(_ trip: UpcomingTrip, compact: Bool) -> some View {
        let legs = trip.event?.vehicleLegs ?? []
        return VStack(alignment: .leading, spacing: 4) {
            if !compact {
                stop(trip.origin, terminus: false)
            }
            HStack(spacing: 8) {
                connector(legs)
                lineBadges(legs, fallback: trip)
            }
            .frame(minHeight: 24)
            stop(trip.destination, terminus: true)
        }
    }

    private func stop(_ name: String, terminus: Bool) -> some View {
        HStack(spacing: 8) {
            StopIcon(color: .color1, terminus: terminus, size: Self.iconSize)
            StopNameView(name, style: .row)
        }
    }

    /// Le trait qui relie les deux arrêts, aux couleurs des lignes dans l'ordre.
    private func connector(_ legs: [TripLeg]) -> some View {
        let colors = legs.map { LineColors.lineColor(for: $0.publishedLineName, operatorName: $0.legOperator) }
        return Capsule()
            .fill(LinearGradient(colors: colors.isEmpty ? [.secondary] : colors.count == 1 ? colors + colors : colors,
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 4)
            .frame(width: Self.iconSize)
    }

    /// « 12 › 19 » ; trop de lignes pour la largeur, les premières puis « +2 ».
    @ViewBuilder
    private func lineBadges(_ legs: [TripLeg], fallback trip: UpcomingTrip) -> some View {
        if legs.isEmpty, let line = trip.line {
            BusLineIcon(lineName: line, operatorName: trip.operatorName ?? "")
                .font(.caption.bold())
                // Le badge s'allonge plutôt que de couper « IR 90 ».
                .fixedSize()
        } else {
            ViewThatFits(in: .horizontal) {
                ForEach(Array(stride(from: legs.count, through: 1, by: -1)), id: \.self) { shown in
                    HStack(spacing: 3) {
                        ForEach(Array(legs.prefix(shown).enumerated()), id: \.offset) { index, leg in
                            if index > 0 {
                                Image(systemName: "chevron.compact.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
                                .font(.caption.bold())
                                .fixedSize()
                        }
                        if shown < legs.count {
                            Text(verbatim: "+\(legs.count - shown)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Écran verrouillé

    @ViewBuilder private var rectangular: some View {
        if let trip = entry.trips.first {
            let countdown = trip.countdown
            VStack(alignment: .leading, spacing: 1) {
                if let line = trip.line, countdown.phase(at: entry.date) != .onTheWay {
                    Text(verbatim: "\(line) → \(Self.short(trip.lineDestination ?? trip.destination))")
                        .font(.caption.bold())
                        .widgetAccentable()
                        .lineLimit(1)
                    Text(verbatim: [trip.boarding.map(dateToString(with:)), countdown.departureRelative(at: entry.date)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text(verbatim: trip.title)
                        .font(.caption.bold())
                        .widgetAccentable()
                        .lineLimit(1)
                    Text(verbatim: countdown.headline(at: entry.date))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let walk = countdown.walkReminder(at: entry.date) {
                    Label(walk, systemImage: "figure.walk")
                        .font(.caption)
                        .lineLimit(1)
                } else if let quay = trip.quay, trip.line != nil {
                    Text("Quai \(quay)")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Aucun trajet prévu")
                .font(.headline)
        }
    }

    @ViewBuilder private var inline: some View {
        if let trip = entry.trips.first {
            let countdown = trip.countdown
            if let line = trip.line, let boarding = trip.boarding, countdown.phase(at: entry.date) != .onTheWay {
                Text(verbatim: "\(line) \(dateToString(with: boarding)) · \(countdown.departureRelative(at: entry.date) ?? trip.title)")
            } else {
                Text(verbatim: "\(countdown.headline(at: entry.date)) · \(trip.title)")
            }
        } else {
            Text("Aucun trajet prévu")
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image("scurvepath.stack.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Aucun trajet prévu")
                .font(.headline)
            Text("Enregistrez un itinéraire ou créez un trajet régulier.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// « Thônex, Moillesulaz » devient « Moillesulaz » : la commune ne tient pas dans un widget.
    private static func short(_ name: String) -> String {
        DepartureRow.shortDestination(name)
    }
}

/// « +4' » en orange, comme dans le suivi en direct ; rien à moins de 2 min de retard.
private struct DelayText: View {
    let minutes: Int

    var body: some View {
        if minutes >= 2 {
            Text(verbatim: "+\(minutes)'")
                .foregroundStyle(.orange)
        }
    }
}

#Preview("Prochain trajet", as: .systemSmall) {
    NextTripWidget()
} timeline: {
    NextTripEntry(date: .now, trips: [NextTripProvider.sample])
    NextTripEntry(date: .now, trips: [])
}

#Preview("Prochain trajet — moyen", as: .systemMedium) {
    NextTripWidget()
} timeline: {
    NextTripEntry(date: .now, trips: [NextTripProvider.sample])
    // En attendant le véhicule, avec un changement.
    NextTripEntry(date: .now.addingTimeInterval(10 * 60), trips: [NextTripProvider.delayed])
}

#Preview("Prochain trajet — écran verrouillé", as: .accessoryRectangular) {
    NextTripWidget()
} timeline: {
    NextTripEntry(date: .now, trips: [NextTripProvider.sample])
}

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
    /// Le décompte n'est affiché à la minute que dans l'heure qui précède le départ.
    private static let countdownWindow: TimeInterval = 3600

    func placeholder(in context: Context) -> NextTripEntry {
        NextTripEntry(date: Date(), trips: [Self.sample])
    }

    func getSnapshot(in context: Context, completion: @escaping (NextTripEntry) -> Void) {
        let trips = UpcomingTripsStorage.load()
        // La galerie des widgets montre un exemple plutôt qu'un widget vide.
        completion(NextTripEntry(date: Date(), trips: trips.isEmpty && context.isPreview ? [Self.sample] : trips))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextTripEntry>) -> Void) {
        let now = Date()
        let trips = UpcomingTripsStorage.load()
        var dates: Set<Date> = [now]
        // Chaque minute pleine de l'heure qui précède le départ du prochain trajet.
        if let next = trips.first(where: { $0.arrival > now }) {
            var minute = Calendar.current.dateInterval(of: .minute, for: max(now, next.leaving.addingTimeInterval(-Self.countdownWindow)))?.end ?? now
            while minute < next.leaving {
                dates.insert(minute)
                minute.addTimeInterval(60)
            }
        }
        // Puis chaque changement d'étape : partir, monter, arriver (le trajet suivant prend la place).
        for trip in trips {
            dates.formUnion([trip.leaving, trip.boarding, trip.arrival].compactMap { $0 })
        }
        let entries = dates.filter { $0 >= now }.sorted().prefix(150).map { date in
            NextTripEntry(date: date, trips: trips.filter { $0.arrival > date })
        }
        // L'app recharge le widget quand ses trajets changent ; sinon, de quoi ne pas rester figé.
        let refresh = entries.last.map { max($0.date, now).addingTimeInterval(60) } ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: Array(entries), policy: .after(refresh)))
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

/// Le prochain trajet en widget : quand partir, la frise, le départ et l'arrivée. Le petit
/// format ne garde que l'arrivée.
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

    /// Quand partir, l'heure d'arrivée, puis l'itinéraire comme dans les résultats : la frise, et
    /// dessous le départ et l'arrivée, nommés en entier (la commune au-dessus). Les retards
    /// suivent les heures. Ce qui a changé n'est affiché que s'il reste de la place.
    private func card(_ trip: UpcomingTrip, compact: Bool) -> some View {
        ViewThatFits(in: .vertical) {
            if trip.alert != nil {
                cardContent(trip, compact: compact, density: .withAlert)
            }
            cardContent(trip, compact: compact, density: .regular)
            cardContent(trip, compact: compact, density: .tight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Un widget ne défile pas : une frise trop large devient la suite de ses lignes.
        .environment(\.tripTimelineScrolls, false)
    }

    private enum Density {
        /// Avec ce qui a changé, sous les heures.
        case withAlert
        case regular
        /// Heure de départ sur une seule ligne, rapetissée au besoin.
        case tight
    }

    private func cardContent(_ trip: UpcomingTrip, compact: Bool, density: Density) -> some View {
        let countdown = trip.countdown
        let phase = countdown.phase(at: entry.date)
        let status = trip.event.map(RegularTripStatus.init(trip:))
        return VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: countdown.headline(at: entry.date))
                    .font((compact ? Font.headline : .title3).bold())
                    .lineLimit(compact && density != .tight ? 2 : 1)
                    .minimumScaleFactor(0.7)
                // Le retard du véhicule, tant qu'on ne l'a pas pris.
                if phase != .onTheWay, let status {
                    DelayText(minutes: status.departureDelay)
                        .font((compact ? Font.subheadline : .headline).bold())
                }
                if !compact {
                    Spacer(minLength: 4)
                    departureDetail(trip, phase: phase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
            if density == .withAlert, let alert = trip.alert {
                Label(alert, systemImage: trip.badge?.tone == .critical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(trip.badge?.tone == .critical ? Color.red : .orange)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let event = trip.event {
                TripTimeline(event: event)
                endpoints(trip, compact: compact)
            } else {
                // Instantané d'une version plus ancienne de l'app, sans l'itinéraire.
                Text(verbatim: "\(trip.origin) → \(trip.destination)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
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

    /// Sous la frise, comme dans les résultats : le départ à gauche, l'arrivée à droite. Le
    /// petit format ne garde que l'arrivée.
    private func endpoints(_ trip: UpcomingTrip, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if !compact {
                StopNameView(trip.origin, style: .row)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            StopNameView(trip.destination, style: .row, alignment: compact ? .leading : .trailing)
                .frame(maxWidth: .infinity, alignment: compact ? .leading : .trailing)
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

//
//  NextTripWidget.swift
//  tpg Next Widget
//
//  Le prochain trajet, régulier ou enregistré : quand partir, la montée, ce qui a changé.
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

    static let sample = UpcomingTrip(id: "sample", title: "Travail", isRegular: true,
                                     origin: "Genève, Rive", destination: "Genève, gare Cornavin",
                                     leaving: Date().addingTimeInterval(8 * 60), arrival: Date().addingTimeInterval(25 * 60),
                                     line: "12", operatorName: "Transports Publics Genevois",
                                     lineDestination: "Moillesulaz", quay: "B",
                                     boarding: Date().addingTimeInterval(13 * 60), boardingStop: "Genève, Rive",
                                     badge: .init(text: "À l'heure", symbol: "checkmark.circle.fill", tone: .good))
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

/// La carte « Prochain trajet » de l'accueil, en widget : même ordre, mêmes textes. Le petit
/// format la resserre ; le moyen la reprend telle quelle, pour le seul prochain trajet.
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

    /// En-tête et pastille d'état, le véhicule (ligne, direction, heure), le quai et « dans
    /// 8 min », le rappel de marche, le parcours, ce qui a changé.
    private func card(_ trip: UpcomingTrip, compact: Bool) -> some View {
        let countdown = trip.countdown
        let phase = countdown.phase(at: entry.date)
        // Le petit format ne nomme pas l'arrêt : il n'y tiendrait pas.
        let walk = countdown.walkReminder(at: entry.date, namingStop: !compact)
        return VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                title(trip, compact: compact)
                    .font((compact ? Font.caption2 : .caption).bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let badge = trip.badge {
                    BadgeView(badge: badge, iconOnly: compact)
                }
            }
            if let line = trip.line, phase != .onTheWay {
                if compact {
                    // Trop étroit pour tout sur une ligne : l'heure passe dessous, en gros.
                    vehicle(line, trip: trip)
                        .font(.subheadline.bold())
                    Text(verbatim: trip.boarding.map(dateToString(with:)) ?? "")
                        .font(.title2.bold().monospacedDigit())
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        vehicle(line, trip: trip)
                        Spacer(minLength: 4)
                        if let boarding = trip.boarding {
                            Text(dateToString(with: boarding))
                                .monospacedDigit()
                        }
                    }
                    .font(.title3.bold())
                }
                HStack(spacing: 6) {
                    if let quay = trip.quay {
                        Text("Quai \(quay)")
                    }
                    Spacer(minLength: 0)
                    if let relative = countdown.departureRelative(at: entry.date) {
                        Text(verbatim: relative)
                    }
                }
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(.secondary)
            } else {
                // À pied, ou déjà dans le véhicule : une phrase suffit.
                Text(verbatim: countdown.headline(at: entry.date))
                    .font((compact ? Font.headline : .title3).bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            if let walk {
                Label(walk, systemImage: "figure.walk")
                    .font((compact ? Font.caption2 : .footnote).weight(phase == .walkToStop ? .semibold : .regular))
                    .foregroundStyle(phase == .walkToStop ? .primary : .secondary)
                    .lineLimit(compact || trip.alert == nil ? 2 : 1)
                    .minimumScaleFactor(0.8)
            }
            // Le parcours, si la place le permet : il cède à la marche et à l'alerte.
            if !compact, walk == nil || trip.alert == nil {
                Text(verbatim: "\(trip.origin) → \(trip.destination)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let alert = trip.alert, !(compact && walk != nil) {
                Label(alert, systemImage: trip.badge?.tone == .critical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(trip.badge?.tone == .critical ? Color.red : .orange)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func title(_ trip: UpcomingTrip, compact: Bool) -> some View {
        if trip.isRegular {
            Label(trip.title, systemImage: "repeat")
        } else {
            // « Itinéraire enregistré » ne tient pas à côté de la pastille dans le petit format.
            Label(compact ? String(localized: "Enregistré") : trip.title, image: "scurvepath.stack.fill")
        }
    }

    private func vehicle(_ line: String, trip: UpcomingTrip) -> some View {
        HStack(spacing: 6) {
            BusLineIcon(lineName: line, operatorName: trip.operatorName ?? "")
            Text(verbatim: "→ \(Self.short(trip.lineDestination ?? trip.destination))")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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

/// La pastille d'état de l'accueil. `iconOnly` : le petit format n'a pas la place du texte.
private struct BadgeView: View {
    let badge: UpcomingTrip.Badge
    var iconOnly = false

    var body: some View {
        let color = badge.tone.color
        Group {
            if iconOnly {
                Image(systemName: badge.symbol)
            } else {
                Label(badge.text, systemImage: badge.symbol)
            }
        }
        .font(.caption2.bold())
        .foregroundStyle(color)
        .padding(.horizontal, iconOnly ? 5 : 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
        .lineLimit(1)
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
}

#Preview("Prochain trajet — écran verrouillé", as: .accessoryRectangular) {
    NextTripWidget()
} timeline: {
    NextTripEntry(date: .now, trips: [NextTripProvider.sample])
}

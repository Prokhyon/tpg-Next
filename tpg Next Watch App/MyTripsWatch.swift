//
//  MyTripsWatch.swift
//  tpg Next Watch App
//
//  « Mes trajets » : les prochains trajets réguliers et itinéraires enregistrés, envoyés par
//  l'iPhone (`UpcomingTripsPublisher`, clé `WatchContext.upcomingTripsKey`).
//

import SwiftUI
import tpgNextFunc

/// Les prochains trajets reçus de l'iPhone, gardés pour le prochain lancement.
@Observable
final class WatchTripsModel {
    private(set) var trips: [UpcomingTrip]

    private static let store = CodableStore<[UpcomingTrip]>(key: "upcomingTrips")

    /// - Parameter trips: aperçus ; sinon les derniers trajets reçus.
    init(trips: [UpcomingTrip]? = nil) {
        self.trips = trips ?? Self.store.load() ?? []
    }

    /// Les trajets pas encore arrivés : l'iPhone n'envoie de nouvelle liste que s'il tourne.
    func upcoming(at date: Date) -> [UpcomingTrip] {
        trips.filter { $0.arrival > date }
    }

    /// Appelé avec le contexte reçu de l'iPhone, sur n'importe quelle file.
    func apply(from payload: [String: Any]) {
        guard let data = payload[WatchContext.upcomingTripsKey] as? Data else { return }
        do {
            let trips = try JSONDecoder().decode([UpcomingTrip].self, from: data)
            DispatchQueue.main.async {
                guard trips != self.trips else { return }
                self.trips = trips
                Self.store.save(trips)
            }
        } catch {
            Log.sync.error("Trajets reçus illisibles : \(error.localizedDescription)")
        }
    }
}

/// Un trajet à venir : quand partir, le premier véhicule et ce qui a changé.
struct UpcomingTripRow: View {
    @Environment(\.displayTime) private var now
    let trip: UpcomingTrip

    var body: some View {
        let countdown = trip.countdown
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                title
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let badge = trip.badge {
                    Image(systemName: badge.symbol)
                        .font(.caption)
                        .foregroundStyle(badge.tone.color)
                        .accessibilityLabel(badge.text)
                }
            }
            Text(countdown.headline(at: now))
                .font(.headline)
                .lineLimit(2)
            if let line = trip.line {
                HStack(spacing: 4) {
                    BusLineIcon(lineName: line, operatorName: trip.operatorName ?? "", width: 28, height: 19)
                        .font(.caption.bold())
                    // La direction sans sa commune : « Thônex, Moillesulaz » ne tenait pas.
                    Text(directionName)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if let boarding = trip.boarding {
                        Text(boarding, format: .dateTime.hour().minute())
                            .font(.caption.monospacedDigit())
                    }
                }
            }
            if countdown.phase(at: now) == .walkToStop, let walk = countdown.walkDescription {
                Label(walk, systemImage: "figure.walk")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let alert = trip.alert {
                Text(alert)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private var directionName: String {
        let parts = splitString(trip.lineDestination ?? trip.destination, separator: ",")
        return parts.1.isEmpty ? parts.0 : parts.1
    }

    /// « Travail » pour un trajet régulier ; le parcours pour un itinéraire enregistré, dont le
    /// titre (« Itinéraire enregistré ») ne dit rien.
    private var title: Text {
        trip.isRegular ? Text(trip.title) : Text(route: trip.origin, to: trip.destination)
    }
}

#Preview("Trajets") {
    List {
        UpcomingTripRow(trip: .sample())
        UpcomingTripRow(trip: .sample(delay: 4))
    }
    .watchPreviewEnvironment()
}

//
//  TripDetailWatch.swift
//  tpg Next Watch App
//
//  Le détail d'un trajet de « Mes trajets » : quand partir, les étapes avec leurs heures et
//  leurs quais, l'arrivée. Les heures sont relues en temps réel par la montre elle-même.
//

import SwiftUI
import tpgNextFunc

struct TripDetailView: View {
    /// Ce que dit le temps réel de la montre, par-dessus l'état envoyé par l'iPhone.
    private enum LiveStatus: Equatable {
        /// Pas encore relu : l'état et les heures de l'iPhone.
        case snapshot
        /// Courses relues à cette heure ; les heures affichées sont les leurs.
        case live(Date)
        /// Une course ne passe plus, ou une correspondance ne tient plus.
        case broken
    }

    @Environment(\.displayTime) private var now
    let trip: UpcomingTrip
    var autoRefresh = true
    @State private var liveTrip: TripEvent?
    @State private var status = LiveStatus.snapshot

    private var event: TripEvent? { liveTrip ?? trip.event }

    var body: some View {
        List {
            header
                .listRowBackground(Color.clear)
            if let event {
                ForEach(Array(event.legs.enumerated()), id: \.element.id) { index, leg in
                    legRow(leg, walkingTo: walkTarget(after: index, in: event))
                }
                arrivalRow(event)
            }
        }
        .navigationTitle(trip.isRegular ? trip.title : String(localized: "Itinéraire"))
        .periodicRefresh(every: .seconds(60), repeats: autoRefresh) { _ in
            refresh()
        }
    }

    // MARK: - En-tête

    private var header: some View {
        let countdown = self.countdown
        return VStack(alignment: .leading, spacing: 4) {
            if !trip.isRegular {
                Text(route: trip.origin, to: trip.destination)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(countdown.headline(at: now))
                .font(.title3.bold())
            statusLabel
            // Ce qu'a vu l'iPhone ; le temps réel de la montre le remplace.
            if status == .snapshot, let alert = trip.alert {
                Text(alert)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch status {
        case .live(let date):
            Label {
                Text("Temps réel · \(date, format: .dateTime.hour().minute())")
            } icon: {
                Image(systemName: "dot.radiowaves.left.and.right")
            }
            .font(.caption2)
            .foregroundStyle(.green)
        case .broken:
            Label("Cet itinéraire ne tient plus", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case .snapshot:
            if let badge = trip.badge {
                Label(badge.text, systemImage: badge.symbol)
                    .font(.caption2)
                    .foregroundStyle(badge.tone.color)
            }
        }
    }

    /// Quand partir, d'après les heures relues si elles le sont.
    private var countdown: TripCountdown {
        guard let event, let leaving = event.leavingDate ?? event.startDate else { return trip.countdown }
        let board = event.vehicleLegs.first
        return TripCountdown(leaving: leaving, boarding: board?.boardDate, arrival: arrival(of: event) ?? trip.arrival,
                             boardingStop: board?.legBoardStopName)
    }

    // MARK: - Étapes

    /// Où mène une marche : l'arrêt du véhicule suivant, ou l'arrivée.
    private func walkTarget(after index: Int, in event: TripEvent) -> String {
        let next = event.legs[(index + 1)...].first { !$0.transfer && !$0.publishedLineName.isEmpty }
        return shortStopName(next?.legBoardStopName ?? event.endName)
    }

    @ViewBuilder private func legRow(_ leg: TripLeg, walkingTo target: String) -> some View {
        if leg.transfer {
            // La marche, jusqu'au premier arrêt, entre deux véhicules ou jusqu'à l'arrivée.
            if let walk = leg.walkDuration, walk >= 60 {
                Label("\(Int((walk / 60).rounded())) min à pied jusqu'à \(target)", systemImage: "figure.walk")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
        } else if !leg.publishedLineName.isEmpty {
            NavigationLink(value: WatchRoute.journey(leg.stopEvent, fromStopSloid: leg.legBoardStopId)) {
                VehicleLegView(leg: leg)
            }
            .opacity(hasPassed(leg.alightDate, includingCurrentMinute: false, now: now) ? 0.5 : 1)
        }
    }

    private func arrivalRow(_ event: TripEvent) -> some View {
        HStack {
            Image(systemName: "flag.checkered")
            Text(stopName: event.endName)
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: 4)
            if let arrival = arrival(of: event) {
                Text(arrival, format: .dateTime.hour().minute())
                    .font(.footnote.bold().monospacedDigit())
            }
        }
        .listRowBackground(Color.clear)
    }

    /// L'arrivée : la descente du dernier véhicule, relue, plus la marche prévue ensuite.
    /// `endTime` ne bouge pas avec le temps réel.
    private func arrival(of event: TripEvent) -> Date? {
        guard let end = event.endDate else { return nil }
        guard let last = event.vehicleLegs.last, let alight = last.alightDate,
              let planned = OJPDate.date(from: last.legAlightTimetableTime) else { return end }
        return alight.addingTimeInterval(end.timeIntervalSince(planned))
    }

    // MARK: - Temps réel

    /// Toujours depuis l'itinéraire reçu : chaque lecture repart des courses prévues.
    private func refresh() {
        guard let base = trip.event, !base.vehicleLegs.isEmpty else { return }
        Task {
            switch await TripVerifier.verify(base) {
            case .feasible(let checked):
                liveTrip = checked
                status = .live(Date())
            case .broken:
                status = .broken
            case .unknown:
                // L'API n'a pas répondu : on garde ce qu'on avait.
                break
            @unknown default:
                break
            }
        }
    }
}

/// Une étape en bus, tram, train ou bateau : la ligne et sa direction, puis la montée et la descente.
private struct VehicleLegView: View {
    let leg: TripLeg

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator, width: 30, height: 21)
                    .font(.caption.bold())
                Image(systemName: "arrow.right")
                    .font(.caption2)
                Text(shortStopName(leg.legDestination))
                    .font(.footnote)
                    .lineLimit(1)
            }
            LegStopLine(stop: leg.legBoardStopName, quay: leg.legBoardQuay,
                        timetabled: leg.legBoardTimetableTime, estimated: leg.legBoardEstimatedTime)
            LegStopLine(stop: leg.legAlightStopName, quay: leg.legAlightQuay,
                        timetabled: leg.legAlightTimetableTime, estimated: leg.legAlightEstimatedTime)
            if leg.hasIncident {
                Label("Parcours modifié", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

/// « 07:42 +3'  Rive  [B] » : l'heure (estimée si connue) et son retard, l'arrêt, le quai.
private struct LegStopLine: View {
    let stop: String
    let quay: String
    let timetabled: String
    let estimated: String

    var body: some View {
        let planned = OJPDate.date(from: timetabled)
        let time = OJPDate.date(from: estimated) ?? planned
        let delay = planned.flatMap { planned in time.map { Int(($0.timeIntervalSince(planned) / 60).rounded()) } } ?? 0
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            VStack(alignment: .trailing, spacing: 0) {
                if let time {
                    Text(time, format: .dateTime.hour().minute())
                        .font(.footnote.bold().monospacedDigit())
                }
                if delay != 0 {
                    Text(delay > 0 ? "+\(delay)'" : "\(delay)'")
                        .font(.caption2.bold())
                        .foregroundStyle(delay > 0 ? .orange : .green)
                }
            }
            .frame(minWidth: 40, alignment: .trailing)
            Text(shortStopName(stop))
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: 2)
            if !quay.isEmpty {
                QuayIcon(quay: quay)
                    .font(.caption)
            }
        }
    }
}

extension TripLeg {
    /// Le départ de cette étape, pour ouvrir sa course (`JourneyView`).
    var stopEvent: StopEvent {
        StopEvent(stopPointName: legBoardStopName, stopId: legBoardStopId, plannedQuay: legBoardQuay,
                  timetabledTime: legBoardTimetableTime, estimatedTime: legBoardEstimatedTime, lineName: publishedLineName,
                  origin: "", destination: legDestination, transportType: transportTypeName, operatorName: legOperator,
                  journeyRef: journeyRef, operatingDayRef: resolvedOperatingDayRef, attributeCodes: attributeCodes)
    }
}

#Preview("Détail d'un trajet") {
    NavigationStack {
        TripDetailView(trip: .sample(), autoRefresh: false)
    }
    .watchPreviewEnvironment()
}

#Preview("Détail — en retard") {
    NavigationStack {
        TripDetailView(trip: .sample(delay: 4), autoRefresh: false)
    }
    .watchPreviewEnvironment()
}

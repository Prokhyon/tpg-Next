//
//  TrackJourneyView.swift
//  tpg Next
//
//  Suivre une course en direct depuis un départ : d'où l'on part, jusqu'où l'on va.
//

import SwiftUI
import tpgNextFunc

/// Deux questions : l'arrêt touché est-il la montée ou la descente, puis quel est l'autre.
struct TrackJourneyView: View {
    /// Le départ touché (la course, la ligne, la destination).
    let event: StopEvent
    /// L'arrêt de ce départ, sur la course.
    let stopSloid: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayTime) private var now
    @State private var manager = LineManager()
    @State private var loaded = false
    /// `true` : on part de cet arrêt ; `false` : on y descend ; `nil` : la question est posée.
    @State private var departsFromStop: Bool?
    private var liveActivities = TripLiveActivities.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !loaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if currentStop == nil {
                    Text("Cette course n'est pas disponible pour le moment.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let departsFromStop {
                    Text(departsFromStop ? "Jusqu'à quel arrêt ?" as LocalizedStringKey : "Depuis quel arrêt ?")
                        .font(.title3).bold()
                        .padding(.horizontal, 10)
                    ForEach(otherStops) { stop in
                        Button {
                            start(other: stop)
                        } label: {
                            stopRow(stop)
                        }
                        .buttonStyle(.plain)
                    }
                    if otherStops.isEmpty {
                        Text(departsFromStop
                             ? "Cet arrêt est le terminus de la course." as LocalizedStringKey
                             : "La course commence à cet arrêt.")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                    }
                } else {
                    Text("Que suivez-vous ?")
                        .font(.title3).bold()
                        .padding(.horizontal, 10)
                    choice(departs: true, title: "À partir de \(shortStopName(event.stopPointName))",
                           subtitle: "Monter ici, descendre plus loin", symbol: "arrow.up.forward")
                    choice(departs: false, title: "Jusqu'à \(shortStopName(event.stopPointName))",
                           subtitle: "Monter avant, descendre ici", symbol: "arrow.down.forward")
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .readableScrollContent()
        .navigationTitle("Suivre en direct")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !loaded else { return }
            manager.selectJourney(event) { loaded = true }
        }
    }

    // MARK: Morceaux

    private func choice(departs: Bool, title: String, subtitle: LocalizedStringKey, symbol: String) -> some View {
        Button {
            withAnimation { departsFromStop = departs }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(lineColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BasicCard(cornerRadius: 25))
        }
        .buttonStyle(.plain)
    }

    private func stopRow(_ stop: LineEvent) -> some View {
        HStack {
            StopNameView(stop.stopPointName, style: .row)
            Spacer()
            if let date = stop.departureDate {
                Text(dateToString(with: date))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .basicElementBackground(minHeight: 54)
        .padding(.horizontal, 4)
    }

    // MARK: Course

    private var lineColor: Color {
        LineColors.lineColor(for: event.lineName, operatorName: manager.operatorName.isEmpty ? event.operatorName : manager.operatorName)
    }

    /// L'arrêt touché, retrouvé sur la course.
    private var currentStop: LineEvent? {
        let sloid = sloidHarmonizer(code: stopSloid)
        return manager.lineEvents.first { sloidHarmonizer(code: $0.sloid) == sloid }
    }

    /// Les arrêts proposés : après celui-ci si on en part, avant si on y descend. Un arrêt
    /// déjà passé ne sert à rien.
    private var otherStops: [LineEvent] {
        guard let current = currentStop,
              let index = manager.lineEvents.firstIndex(where: { $0.id == current.id }) else { return [] }
        if departsFromStop == true {
            return manager.lineEvents.suffix(from: min(index + 1, manager.lineEvents.count))
                .filter { $0.isCancelled != true }
        }
        return manager.lineEvents.prefix(index)
            .filter { $0.isCancelled != true && !hasPassed($0.departureDate, includingCurrentMinute: false, now: now) }
    }

    private func start(other stop: LineEvent) {
        guard let current = currentStop else { return }
        let board = departsFromStop == true ? current : stop
        let alight = departsFromStop == true ? stop : current
        guard liveActivities.areEnabled else {
            NotificationConfirmationViewModel.shared.show(
                message: String(localized: "Les activités en direct sont désactivées pour tpg Next.\nChangez-le dans les réglages du téléphone"),
                error: true)
            return
        }
        liveActivities.start(journey: event, events: manager.lineEvents, operatorName: manager.operatorName,
                             board: board, alight: alight)
        let started = liveActivities.isTracking(TripLiveActivities.key(forJourney: event, boardSloid: board.sloid))
        NotificationConfirmationViewModel.shared.show(
            message: started
                ? String(localized: "Suivi en direct de la ligne \(event.lineName) lancé")
                : String(localized: "Le suivi en direct n'a pas pu être lancé"),
            error: !started)
        dismiss()
    }
}

#Preview("Suivre une course — (API)") {
    LiveDeparturePreview(stop: PreviewData.rive) { departures in
        TrackJourneyView(event: departures.event, stopSloid: PreviewData.rive.sloid)
    }
    .previewEnvironment()
}

//
//  TrackJourneyView.swift
//  tpg Next
//
//  Suivre une course en direct depuis un départ : d'où l'on part, jusqu'où l'on va.
//

import SwiftUI
import tpgNextFunc

/// L'autre arrêt de la course : la descente si l'on monte à l'arrêt touché, la montée si l'on
/// y descend. Le sens vient du menu du départ ; il se change en haut de la feuille.
struct TrackJourneyView: View {
    /// Le départ touché (la course, la ligne, la destination).
    let event: StopEvent
    /// L'arrêt de ce départ, sur la course.
    let stopSloid: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayTime) private var now
    @State private var manager = LineManager()
    @State private var loaded = false
    /// `true` : on part de cet arrêt ; `false` : on y descend.
    @State private var departsFromStop: Bool
    private var liveActivities = TripLiveActivities.shared

    init(event: StopEvent, stopSloid: String, departsFromStop: Bool = true) {
        self.event = event
        self.stopSloid = stopSloid
        _departsFromStop = State(initialValue: departsFromStop)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                let stopName = shortStopName(event.stopPointName)
                Picker("Sens", selection: $departsFromStop.animation()) {
                    Text("À partir de \(stopName)").tag(true)
                    Text("Jusqu'à \(stopName)").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 6)
                if !loaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if currentStop == nil {
                    Text("Cette course n'est pas disponible pour le moment.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    HStack(spacing: 8) {
                        BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                        Text(departsFromStop ? "Jusqu'à quel arrêt ?" as LocalizedStringKey : "Depuis quel arrêt ?")
                            .font(.title3).bold()
                    }
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
        if departsFromStop {
            return manager.lineEvents.suffix(from: min(index + 1, manager.lineEvents.count))
                .filter { $0.isCancelled != true }
        }
        return manager.lineEvents.prefix(index)
            .filter { $0.isCancelled != true && !hasPassed($0.departureDate, includingCurrentMinute: false, now: now) }
    }

    private func start(other stop: LineEvent) {
        guard let current = currentStop else { return }
        let board = departsFromStop ? current : stop
        let alight = departsFromStop ? stop : current
        guard liveActivities.areEnabled else {
            NotificationConfirmationViewModel.shared.show(
                message: String(localized: "Les activités en direct sont désactivées pour tpg Next.\nChangez-le dans les réglages du téléphone"),
                error: true)
            return
        }
        guard liveActivities.hasLocation else {
            liveActivities.askForLocation()
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
        TrackJourneySheet(event: departures.event, stopSloid: PreviewData.rive.sloid, departsFromStop: true)
    }
    .previewEnvironment()
}

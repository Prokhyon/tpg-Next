//
//  TripAlternativesView.swift
//  tpg Next
//
//  Les itinéraires proposés autour d'une heure, pour remplacer un itinéraire enregistré ou,
//  pour un jour, un trajet régulier.
//

import SwiftUI
import tpgNextFunc

struct TripAlternativesView: View {
    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    /// Ce que devient l'itinéraire choisi.
    let footer: LocalizedStringKey
    let origin: RegularTripPlace
    let destination: RegularTripPlace
    let isArrivalTime: Bool
    /// L'itinéraire actuel, marqué dans la liste.
    let current: TripEvent?
    let onChoose: (TripEvent) -> Void

    /// L'heure demandée à OJP : un peu avant l'heure voulue (ou après, pour une arrivée), pour
    /// que les propositions l'encadrent.
    @State private var time: Date
    private let margin: TimeInterval
    @State private var search = Search.loading

    enum Search {
        case loading
        case results([TripEvent])
        case noTrip, failed
    }

    init(title: LocalizedStringKey, footer: LocalizedStringKey, origin: RegularTripPlace, destination: RegularTripPlace,
         around time: Date, isArrivalTime: Bool = false, current: TripEvent?, onChoose: @escaping (TripEvent) -> Void) {
        self.title = title
        self.footer = footer
        self.origin = origin
        self.destination = destination
        self.isArrivalTime = isArrivalTime
        self.current = current
        self.onChoose = onChoose
        margin = isArrivalTime ? 15 * 60 : -15 * 60
        _time = State(initialValue: time.addingTimeInterval(margin))
    }

    /// Les itinéraires de `trip`, autour de son heure de départ.
    init(title: LocalizedStringKey, footer: LocalizedStringKey, replacing trip: TripEvent, onChoose: @escaping (TripEvent) -> Void) {
        self.init(title: title, footer: footer, origin: .origin(of: trip), destination: .destination(of: trip),
                  around: trip.anchorDate(.departure, timetabled: true) ?? trip.startDate ?? Date(),
                  current: trip, onChoose: onChoose)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(route: origin.name, to: destination.name)
                    Text(dayText)
                        .foregroundStyle(.secondary)
                }

                switch search {
                case .loading:
                    HStack {
                        ProgressView()
                        Text("Recherche des itinéraires…")
                            .foregroundStyle(.secondary)
                    }
                case .noTrip:
                    Text("Aucun itinéraire à cette heure-là.")
                        .foregroundStyle(.secondary)
                    moveButtons
                case .failed:
                    Text("Impossible de charger les itinéraires.")
                        .foregroundStyle(.secondary)
                    Button("Réessayer") {
                        Task { await load() }
                    }
                case .results(let trips):
                    Section {
                        moveButton(earlier: true)
                        ForEach(trips) { trip in
                            Button {
                                onChoose(trip)
                                dismiss()
                            } label: {
                                row(trip)
                            }
                            .foregroundStyle(.primary)
                        }
                        moveButton(earlier: false)
                    } footer: {
                        Text(footer)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .task(id: time) { await load() }
        }
    }

    private func row(_ trip: TripEvent) -> some View {
        let status = RegularTripStatus(trip: trip)
        return VStack(alignment: .leading, spacing: 6) {
            SavedTripView(event: trip)
            HStack(spacing: 10) {
                if let current, trip.isSameCourse(as: current) {
                    Label("Itinéraire actuel", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
                if status.departureDelay >= 1 {
                    Label("Départ +\(status.departureDelay) min", systemImage: "clock.fill")
                        .foregroundStyle(status.departureDelay >= 5 ? .red : .orange)
                }
                if !status.disruptedLines.isEmpty {
                    Label("Perturbé", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption.bold())
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder private var moveButtons: some View {
        moveButton(earlier: true)
        moveButton(earlier: false)
    }

    /// Une demi-heure plus tôt ou plus tard.
    private func moveButton(earlier: Bool) -> some View {
        Button {
            time = time.addingTimeInterval(earlier ? -30 * 60 : 30 * 60)
        } label: {
            Label(earlier ? "Plus tôt" as LocalizedStringKey : "Plus tard",
                  systemImage: earlier ? "chevron.up" : "chevron.down")
                .font(.subheadline)
        }
    }

    /// « Mercredi 23 septembre, vers 17:45 » : l'heure voulue, pas celle demandée à OJP.
    private var dayText: String {
        let wanted = time.addingTimeInterval(-margin)
        let text = wanted.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let day = text.prefix(1).capitalized + text.dropFirst()
        return String(localized: "\(day), vers \(dateToString(with: wanted))")
    }

    private func load() async {
        search = .loading
        do {
            let trips = try await RegularTripResolver.trips(from: origin, to: destination, at: time, isArrivalTime: isArrivalTime)
            guard !Task.isCancelled else { return }
            search = .results(trips.sortedByStart())
        } catch RegularTripResolver.Failure.noTrip {
            search = .noTrip
        } catch {
            guard !Task.isCancelled else { return }
            search = .failed
        }
    }
}

extension TripEvent {
    /// Les mêmes véhicules : mêmes courses si OJP les donne, sinon mêmes lignes aux mêmes heures prévues.
    func isSameCourse(as other: TripEvent) -> Bool {
        let mine = vehicleLegs, theirs = other.vehicleLegs
        guard mine.count == theirs.count else { return false }
        return zip(mine, theirs).allSatisfy { a, b in
            if !a.journeyRef.isEmpty, !b.journeyRef.isEmpty { return a.journeyRef == b.journeyRef }
            return a.publishedLineName == b.publishedLineName && a.legBoardTimetableTime == b.legBoardTimetableTime
        }
    }
}

#Preview("Autres horaires (API)") {
    TripAlternativesView(title: "Autres horaires", footer: "L'itinéraire choisi remplace celui enregistré.",
                         origin: .origin(of: PreviewData.tripWithTransfer), destination: .destination(of: PreviewData.tripWithTransfer),
                         around: Date(), current: nil) { _ in }
        .previewEnvironment(navigation: false)
}

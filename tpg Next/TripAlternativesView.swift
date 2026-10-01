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
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(route: origin.name, to: destination.name)
                            .font(.headline.weight(.regular))
                        Text(dayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                    switch search {
                    case .loading:
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Recherche des itinéraires…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    case .noTrip:
                        message("Aucun itinéraire à cette heure-là.", systemImage: "clock.badge.questionmark")
                        moveButton(earlier: true)
                        moveButton(earlier: false)
                    case .failed:
                        message("Impossible de charger les itinéraires.", systemImage: "wifi.exclamationmark")
                        capsuleButton("Réessayer", systemImage: "arrow.clockwise") {
                            Task { await load() }
                        }
                    case .results(let trips):
                        moveButton(earlier: true)
                        ForEach(trips) { trip in
                            Button {
                                onChoose(trip)
                                dismiss()
                            } label: {
                                row(trip)
                            }
                            .buttonStyle(.plain)
                        }
                        moveButton(earlier: false)
                        Text(footer)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .readableScrollContent()
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

    /// Un itinéraire en carte ; l'actuel est cerclé d'orange.
    private func row(_ trip: TripEvent) -> some View {
        let status = RegularTripStatus(trip: trip)
        let isCurrent = current.map { trip.isSameCourse(as: $0) } ?? false
        return VStack(alignment: .leading, spacing: 8) {
            SavedTripView(event: trip)
            if isCurrent || status.departureDelay >= 1 || !status.disruptedLines.isEmpty {
                HStack(spacing: 10) {
                    if isCurrent {
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
        }
        .padding(15)
        .background(BasicCard(cornerRadius: 30, highlighted: isCurrent, lineColors: trip.lineColors))
        .contentShape(RoundedRectangle(cornerRadius: 30))
        .padding(.vertical, 2)
    }

    private func message(_ text: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
            Text(text)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    /// Une demi-heure plus tôt ou plus tard.
    private func moveButton(earlier: Bool) -> some View {
        capsuleButton(earlier ? "Plus tôt" : "Plus tard", systemImage: earlier ? "chevron.up" : "chevron.down") {
            time = time.addingTimeInterval(earlier ? -30 * 60 : 30 * 60)
        }
    }

    private func capsuleButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .basicElementBackground(minHeight: 40)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 40)
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

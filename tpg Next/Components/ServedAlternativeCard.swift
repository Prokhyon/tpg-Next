//
//  ServedAlternativeCard.swift
//  tpg Next
//
//  Quand un départ ne passe pas à l'arrêt affiché (incident, arrêts sautés), l'arrêt desservi
//  le plus proche où prendre ce même véhicule. Voir `nearestServedStop(skipping:in:)`.
//

import SwiftUI
import tpgNextFunc

struct ServedAlternativeCard: View {
    @Environment(\.displayTime) private var now
    let alternative: ServedAlternative
    let transportType: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.title3)
                    .foregroundStyle(.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Passe à \(Text(stopName: alternative.stop.stopPointName))")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                    Text("\(Measurement(value: alternative.distance.rounded(), unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road)) · ≈ \(alternative.walkingMinutes) min à pied")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DepartureTimeView(departureDisplay(timetabled: alternative.stop.timetabledTime, estimated: alternative.stop.estimatedTime,
                                                   showTime: true, at: now),
                                  transportType: transportType, layout: .inline(spacing: 4), showsIcon: false)
                    .font(.headline)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.06)))
        }
        .foregroundStyle(.primary)
        .accessibilityHint("Ouvre l'arrêt")
    }
}

#Preview("Arrêt desservi le plus proche") {
    // Un arrêt à venir de la course d'exemple (ligne 29).
    let stop = PreviewData.journeyStops.last { ($0.departureDate ?? .distantPast) > PreviewData.now } ?? PreviewData.journeyStops[0]
    ServedAlternativeCard(alternative: ServedAlternative(stop: stop, distance: 253), transportType: "Bus") {}
        .padding()
        .previewEnvironment(navigation: false)
}

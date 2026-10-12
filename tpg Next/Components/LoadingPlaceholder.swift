//
//  LoadingPlaceholder.swift
//  tpg Next
//
//  Pendant qu'OJP répond : la forme de ce qui arrive, qui respire.
//

import SwiftUI

/// Des rangées fantômes à la place de la liste attendue : départs, arrêts d'une course ou
/// itinéraires. Elles pâlissent et reviennent, en boucle ; immobiles quand « Réduire les
/// animations » est activé.
struct LoadingPlaceholder: View {
    enum Kind {
        /// Un départ : le badge de la ligne, la destination, l'heure.
        case departure
        /// Un arrêt d'une course : son point, son nom, l'heure.
        case stop
        /// Un itinéraire : départ, frise, arrivée.
        case trip
    }

    var kind: Kind = .departure
    var count = 4

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                row(index)
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .modifier(BreathingEffect())
                    .padding(.horizontal)
                    .basicElementBackground(minHeight: kind == .trip ? 70 : 50)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Chargement…"))
    }

    /// Les longueurs varient d'une rangée à l'autre, comme de vrais noms.
    @ViewBuilder private func row(_ index: Int) -> some View {
        let widths: [CGFloat] = [150, 120, 170, 135]
        switch kind {
        case .departure, .stop:
            HStack(spacing: 12) {
                if kind == .departure {
                    Capsule().frame(width: 38, height: 24)
                } else {
                    Circle().frame(width: 18, height: 18)
                }
                // La commune, petite, puis le nom de l'arrêt, en gras : souvent le plus long.
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).frame(width: 70, height: 8)
                    RoundedRectangle(cornerRadius: 4).frame(width: widths[index % widths.count], height: 13)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 4).frame(width: 34, height: 16)
            }
        case .trip:
            VStack(spacing: 10) {
                HStack {
                    RoundedRectangle(cornerRadius: 4).frame(width: 44, height: 15)
                    Spacer()
                    RoundedRectangle(cornerRadius: 4).frame(width: 44, height: 15)
                }
                Capsule().frame(height: 10)
            }
            .padding(.vertical, 12)
        }
    }
}

/// Le contenu pâlit et revient, doucement, en boucle.
struct BreathingEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.phaseAnimator([1.0, 0.45]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in .easeInOut(duration: 0.9) }
        }
    }
}

#Preview("Chargement") {
    ScrollView {
        LoadingPlaceholder(kind: .departure, count: 3)
        LoadingPlaceholder(kind: .stop, count: 3)
        LoadingPlaceholder(kind: .trip, count: 2)
    }
}

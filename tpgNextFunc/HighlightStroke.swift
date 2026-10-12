//
//  HighlightStroke.swift
//  tpgNextFunc
//
//  Le surlignage animé : l'anneau d'un arrêt, la capsule d'une ligne.
//

import SwiftUI

/// Le trait de surlignage (arrêt d'où l'on vient, étape en cours, montée et descente d'un
/// trajet) : la forme ne bouge pas, mais son remplissage, une comète aux couleurs de l'app (tête
/// vive, traîne qui pâlit), en fait le tour. Immobile quand « Réduire les animations » est activé.
public struct HighlightStroke<S: Shape>: View {
    let shape: S
    var lineWidth: CGFloat
    /// Le temps d'un tour, en secondes.
    var period: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ shape: S, lineWidth: CGFloat, period: Double = 4) {
        self.shape = shape
        self.lineWidth = lineWidth
        self.period = period
    }

    public var body: some View {
        if reduceMotion {
            shape.stroke(gradient(at: .zero), lineWidth: lineWidth)
        } else {
            // L'angle découle de l'heure : l'animation ne repart pas de zéro quand la rangée
            // réapparaît dans une liste, et tous les surlignages tournent ensemble.
            TimelineView(.animation) { context in
                let turns = context.date.timeIntervalSinceReferenceDate / period
                shape.stroke(gradient(at: .degrees(turns.truncatingRemainder(dividingBy: 1) * 360)),
                             lineWidth: lineWidth)
            }
        }
    }

    /// Le premier et le dernier se rejoignent : pas de couture sur le tour.
    private func gradient(at angle: Angle) -> AngularGradient {
        let accent = Color.accentColor
        return AngularGradient(colors: [accent, accent.opacity(0.6), accent.opacity(0.2),
                                        accent.opacity(0.2), accent.opacity(0.6), accent],
                               center: .center, angle: angle)
    }
}

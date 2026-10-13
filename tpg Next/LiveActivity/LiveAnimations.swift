//
//  LiveAnimations.swift
//  tpg Next
//
//  Les petites animations du trajet suivi : un halo qui respire, des minutes qui défilent.
//

import SwiftUI
import tpgNextFunc

/// Un halo qui s'élargit et s'efface, en boucle : c'est ici que ça se passe, maintenant (le
/// véhicule arrive à l'arrêt, on est là sur la carte). Rien quand « Réduire les animations » est
/// activé : l'élément garde son propre surlignage.
struct PulsingHalo: View {
    var color: Color = .accentColor
    /// Jusqu'où il s'élargit, en multiple de sa taille.
    var spread: CGFloat = 2.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            Circle()
                .fill(color)
                .phaseAnimator([false, true]) { circle, expanded in
                    circle
                        .scaleEffect(expanded ? spread : 1)
                        .opacity(expanded ? 0 : 0.45)
                } animation: { expanded in
                    // Il s'élargit en 1,6 s, puis repart d'un coup de la taille de l'élément.
                    expanded ? .easeOut(duration: 1.6) : nil
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Les minutes restantes dans l'app : « 3 minutes », dont le chiffre roule quand il change.
///
/// `TripActivityMinutes` s'écrit au format système, que l'écran verrouillé fait avancer sans
/// l'app, mais que SwiftUI ne sait pas animer. Ici, l'app compte elle-même, à la seconde, avec
/// le même arrondi (à la minute la plus proche).
struct LiveMinutes: View {
    let target: Date?

    var body: some View {
        if let target {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let minutes = max(0, Int((target.timeIntervalSince(AppClock.shifted(context.date)) + 30) / 60))
                Text(Duration.seconds(minutes * 60), format: .units(allowed: [.minutes], width: .wide))
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: minutes)
            }
        }
    }
}

extension View {
    /// Une heure ou un retard qui change (temps réel) : ses chiffres roulent au lieu de sauter.
    func rollingDigits<Value: Equatable>(_ value: Value) -> some View {
        contentTransition(.numericText())
            .animation(.snappy, value: value)
    }
}

/// Un symbole d'alerte (retard, horaire modifié, parcours perturbé) qui rebondit une fois quand
/// il apparaît, puis à chaque fois que l'alerte change (`value`). `active` à faux : rien.
struct AlertBounce<Value: Equatable>: ViewModifier {
    let value: Value
    var active = true
    @State private var trigger = 0

    func body(content: Content) -> some View {
        content
            .symbolEffect(.bounce, value: trigger)
            // Après l'apparition : un effet lancé dans la même transaction ne se jouait pas.
            .task {
                guard active else { return }
                try? await Task.sleep(for: .milliseconds(250))
                trigger += 1
            }
            .onChange(of: value) {
                if active { trigger += 1 }
            }
    }
}

extension View {
    /// Le symbole d'alerte rebondit à son apparition, puis quand `value` change.
    func alertBounce<Value: Equatable>(_ value: Value, active: Bool = true) -> some View {
        modifier(AlertBounce(value: value, active: active))
    }
}

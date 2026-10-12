//
//  LiveTrackingButton.swift
//  tpg Next
//
//  « Suivre en direct », en bas à droite des pages d'une ligne et d'un itinéraire.
//

import SwiftUI

/// Le suivi en direct d'une course ou d'un itinéraire, dans une capsule de verre posée en bas à
/// droite de la liste. Déjà suivi : « Arrêter le suivi », sur la pastille de la couleur de l'app
/// (la forme des boutons actifs).
struct LiveTrackingButton: View {
    var isTracking = false
    let action: () -> Void
    /// Le symbole s'anime à chaque démarrage.
    @State private var started = false

    var body: some View {
        Button {
            action()
            if !isTracking { started.toggle() }
        } label: {
            // En suivi, un anneau autour d'un carré plein, comme l'anneau autour d'un disque pour
            // le lancer ; il respire tant que le suivi dure.
            Label(isTracking ? "Arrêter le suivi" : "Suivre en direct",
                  systemImage: isTracking ? "stop.circle" : "inset.filled.circle")
                .font(.headline)
                .symbolEffect(.bounce, value: started)
                .symbolEffect(.breathe, isActive: isTracking)
                .foregroundStyle(isTracking ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
                .background {
                    if isTracking {
                        Capsule().fill(.tint)
                    }
                }
                .contentShape(Capsule())
                .animation(.snappy, value: isTracking)
        }
        .buttonStyle(.plain)
        .tpgSurface(interactive: true, legacy: .thinMaterial)
        // Plafonné comme les barres d'outils : en taille d'accessibilité, il couvrait la liste.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

#Preview("Suivi en direct", traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        LiveTrackingButton {}
        LiveTrackingButton(isTracking: true) {}
    }
    .padding()
}

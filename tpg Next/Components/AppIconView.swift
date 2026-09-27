//
//  AppIconView.swift
//  tpg Next
//
//  L'icône de l'app, dans l'app : bienvenue, notification d'exemple. L'icône réelle
//  (`tpgNext26.icon`) n'est pas lisible à l'exécution ; `AppIconImage` en reprend le dessin,
//  clair et sombre, depuis les PNG de `AppIcon.appiconset`.
//

import SwiftUI

struct AppIconView: View {
    var size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        Image("AppIconImage")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // L'icône sombre est transparente : le fond d'une icône sombre d'iOS.
            .background(Color(.secondarySystemBackground))
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

#Preview("Icône") {
    HStack(spacing: 20) {
        AppIconView(size: 68)
        AppIconView(size: 34)
    }
    .padding()
}

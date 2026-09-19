//
//  ServiceInfoLabels.swift
//  tpg Next
//
//  Libellés des informations de service d'OJP 2.0 (accès au quai, plancher bas), partagés
//  par les panneaux de détails. L'API envoie des codes : leur texte est rédigé ici.
//

import SwiftUI
import tpgNextFunc

extension QuayAccess {
    var label: LocalizedStringKey {
        switch self {
        case .withoutAssistance: "Accès en fauteuil sans aide"
        case .withAssistance: "Accès en fauteuil avec aide"
        case .notWheelchairAccessible: "Quai non accessible en fauteuil"
        case .alternativeTransport: "Transport de substitution pour fauteuil"
        @unknown default: "Accès au quai"
        }
    }

    var systemImage: String {
        switch self {
        case .withoutAssistance: "figure.roll"
        case .withAssistance: "figure.roll.runningpace"
        case .notWheelchairAccessible: "xmark.circle"
        case .alternativeTransport: "car.side"
        @unknown default: "figure.roll"
        }
    }
}

/// Une information en capsule : icône et texte.
struct InfoChip: View {
    let text: LocalizedStringKey
    let systemImage: String
    var tint: Color = .primary

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
}

/// Titre de section des panneaux.
struct PaneSectionTitle: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.title3)
            .bold()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Informations de service", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 10) {
        PaneSectionTitle(text: "Accessibilité des prochains arrêts")
        ForEach(QuayAccess.allCases, id: \.self) { access in
            InfoChip(text: access.label, systemImage: access.systemImage)
        }
        PaneSectionTitle(text: "Véhicule")
        // Mêmes icônes que les panneaux de détails.
        InfoChip(text: "Plancher bas", systemImage: "arrow.down.to.line")
        InfoChip(text: "Course supprimée", systemImage: "exclamationmark.triangle.fill", tint: .red)
    }
    .padding()
    .frame(width: 360)
}

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
        }
    }

    var systemImage: String {
        switch self {
        case .withoutAssistance: "figure.roll"
        case .withAssistance: "figure.roll.runningpace"
        case .notWheelchairAccessible: "xmark.circle"
        case .alternativeTransport: "car.side"
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

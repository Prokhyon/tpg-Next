//
//  ButtonStyles.swift
//  tpg Next
//
//  Les deux styles de bouton de l'app, comme dans le message de démarrage : l'action principale
//  pleine, couleur de l'app, en verre à partir d'iOS 26 ; l'action d'à côté, plus discrète.
//

import SwiftUI

extension View {
    /// L'action principale : verre proéminent à partir d'iOS 26, proéminent avant.
    @ViewBuilder func prominentButtonStyle() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
    }

    /// L'action secondaire, posée à côté d'une principale : du verre à partir d'iOS 26, une
    /// capsule teintée avant.
    @ViewBuilder func secondaryButtonStyle() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }
}

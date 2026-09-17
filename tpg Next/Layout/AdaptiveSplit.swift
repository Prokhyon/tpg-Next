//
//  AdaptiveSplit.swift
//  tpg Next
//

import SwiftUI

/// Deux moitiés côte à côte quand la fenêtre est large (iPad, écran déplié), le contenu
/// principal seul sinon. L'écran ne change pas de vue selon l'appareil : il pose simplement
/// son panneau secondaire quand la place le permet.
struct AdaptiveSplit<Primary: View, Secondary: View>: View {
    @Environment(\.layout) private var layout
    @ViewBuilder var primary: Primary
    @ViewBuilder var secondary: Secondary

    /// Vrai quand le panneau secondaire est affiché.
    static func isSplit(_ layout: LayoutContext) -> Bool {
        layout.widthClass != .compact
    }

    var body: some View {
        if Self.isSplit(layout) {
            HStack(spacing: 0) {
                primary
                    .frame(maxWidth: .infinity)
                    // Les titres flottants débordent volontairement du bord : coupés à la moitié.
                    .clipped()
                secondary
                    .frame(maxWidth: .infinity)
            }
        } else {
            primary
        }
    }
}

extension LayoutContext {
    /// L'écran affiche-t-il son panneau secondaire (carte et détails) ?
    var showsSecondaryPane: Bool {
        widthClass != .compact
    }
}

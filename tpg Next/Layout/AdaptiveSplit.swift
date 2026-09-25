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
    /// Espace mort à récupérer en haut, pour un écran dont la barre de navigation est vide :
    /// son contenu remonte d'autant vers les barres flottantes.
    var topGapReduction: CGFloat = 0
    @ViewBuilder var primary: Primary
    @ViewBuilder var secondary: Secondary

    /// Vrai quand le panneau secondaire est affiché.
    static func isSplit(_ layout: LayoutContext) -> Bool {
        layout.widthClass != .compact
    }

    /// Jamais plus haut que le bas des barres flottantes.
    private var minimumTopInset: CGFloat { 56 }

    /// De combien le contenu remonte : l'espace demandé, mais seulement tant qu'il reste
    /// sous les barres.
    private func topShift(_ safeAreaTop: CGFloat) -> CGFloat {
        min(topGapReduction, max(0, safeAreaTop - minimumTopInset))
    }

    var body: some View {
        if Self.isSplit(layout) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    primary
                        .frame(maxWidth: .infinity)
                        // Les titres flottants débordent volontairement du bord : coupés à la moitié.
    //                    .clipped()
                    secondary
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, -topShift(geometry.safeAreaInsets.top))
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

#Preview("Deux moitiés — iPad", traits: .iPadLandscape) {
    AdaptiveSplit {
        Color.blue.opacity(0.2).overlay { Text(verbatim: "primary") }
    } secondary: {
        Color.orange.opacity(0.2).overlay { Text(verbatim: "secondary") }
    }
    .providingLayoutContext()
}

#Preview("Deux moitiés — iPhone") {
    // Une seule colonne : `secondary` n'est pas affiché.
    AdaptiveSplit {
        Color.blue.opacity(0.2).overlay { Text(verbatim: "primary") }
    } secondary: {
        Color.orange.opacity(0.2).overlay { Text(verbatim: "secondary") }
    }
    .providingLayoutContext()
}

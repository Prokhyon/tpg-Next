//
//  AdaptiveSplit.swift
//  tpg Next
//

import SwiftUI

/// Deux moitiés côte à côte quand la fenêtre est large (iPad, écran déplié), le contenu
/// principal seul sinon. L'écran ne change pas de vue selon l'appareil : il pose simplement
/// son panneau secondaire quand la place le permet.
///
/// Sur un écran à moitié plié (iPhone Duo), chaque moitié prend un côté du pli : à gauche et à
/// droite d'un pli vertical ; d'un pli horizontal, le panneau secondaire (carte) en haut et le
/// contenu principal en bas, sous les doigts.
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
                let shift = topShift(geometry.safeAreaInsets.top)
                // Le contenu remonte de `shift` : le pli, mesuré sur le lecteur, descend d'autant
                // dans le repère des deux moitiés.
                FoldSplitLayout(fold: Self.fold(in: geometry)?.offsetBy(dx: 0, dy: shift)) {
                    primary
                    secondary
                }
                .padding(.top, -shift)
            }
            .modifier(FixedNavigationBar())
        } else {
            primary
        }
    }

    /// Le pli d'un écran à moitié plié, marges comprises. Absent à plat, fermé ou sans pli.
    private static func fold(in geometry: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        return geometry.reservedRegions(kind: .division)
            .first { $0.isActive }?
            .frame
    }
}

/// Depuis iOS 27, la barre de navigation se réduit quand une liste défile, et la safe area du
/// haut rétrécit d'autant : titres flottants, carte et panneau remontaient avec elle, même en
/// faisant défiler l'autre moitié. Deux moitiés défilent chacune de leur côté : la barre reste.
private struct FixedNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.toolbarMinimizationBehavior(.never, for: .navigationBar)
        } else {
            content
        }
    }
}

/// Deux vues, principale puis secondaire, de part et d'autre du pli, ou à parts égales sans pli.
/// Une seule disposition pour tous les cas : les deux vues gardent leur état (défilement,
/// sélection) quand l'écran se plie ou se déplie.
private struct FoldSplitLayout: Layout {
    /// Le pli dans le repère de la disposition.
    var fold: CGRect?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let (primaryFrame, secondaryFrame) = frames(in: bounds)
        subviews[0].place(at: primaryFrame.origin, proposal: ProposedViewSize(primaryFrame.size))
        subviews[1].place(at: secondaryFrame.origin, proposal: ProposedViewSize(secondaryFrame.size))
    }

    private func frames(in bounds: CGRect) -> (primary: CGRect, secondary: CGRect) {
        guard let fold = fold?.offsetBy(dx: bounds.minX, dy: bounds.minY).intersection(bounds),
              !fold.isNull else {
            let half = bounds.width / 2
            return (CGRect(x: bounds.minX, y: bounds.minY, width: half, height: bounds.height),
                    CGRect(x: bounds.minX + half, y: bounds.minY, width: bounds.width - half, height: bounds.height))
        }
        if fold.height >= fold.width {
            // Pli vertical : le livre ouvert.
            return (CGRect(x: bounds.minX, y: bounds.minY, width: fold.minX - bounds.minX, height: bounds.height),
                    CGRect(x: fold.maxX, y: bounds.minY, width: bounds.maxX - fold.maxX, height: bounds.height))
        } else {
            // Pli horizontal : l'écran posé, la carte debout, la liste à plat.
            return (CGRect(x: bounds.minX, y: fold.maxY, width: bounds.width, height: bounds.maxY - fold.maxY),
                    CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: fold.minY - bounds.minY))
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

#Preview("Pli vertical, décentré") {
    FoldSplitLayout(fold: CGRect(x: 220, y: 0, width: 40, height: 2000)) {
        Color.blue.opacity(0.2).overlay { Text(verbatim: "primary") }
        Color.orange.opacity(0.2).overlay { Text(verbatim: "secondary") }
    }
    .background(.red)
}

#Preview("Pli horizontal") {
    FoldSplitLayout(fold: CGRect(x: 0, y: 300, width: 2000, height: 40)) {
        Color.blue.opacity(0.2).overlay { Text(verbatim: "primary") }
        Color.orange.opacity(0.2).overlay { Text(verbatim: "secondary") }
    }
    .background(.red)
}

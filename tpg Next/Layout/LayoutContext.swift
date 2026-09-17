//
//  LayoutContext.swift
//  tpg Next
//

import SwiftUI

/// La place dont dispose l'interface, mesurée sur la fenêtre et non déduite de l'appareil.
///
/// Un iPad en Split View ou en Stage Manager peut n'offrir qu'une largeur d'iPhone, et un
/// écran pliable change de largeur sans changer d'appareil : les vues décident donc d'après
/// `layout`, jamais d'après `UIDevice` ou `UIScreen`.
struct LayoutContext: Equatable {
    enum WidthClass: Comparable {
        /// iPhone, fenêtre étroite sur iPad.
        case compact
        /// iPad mini, iPad en portrait, écran déplié.
        case regular
        /// Grand iPad en paysage.
        case wide
    }

    var width: CGFloat

    var widthClass: WidthClass {
        switch width {
        case ..<600: .compact
        case ..<1000: .regular
        default: .wide
        }
    }

    /// Largeur au-delà de laquelle une liste ou une carte n'a plus intérêt à s'étirer.
    static let readableWidth: CGFloat = 680

    /// Colonnes de la grille des favoris.
    var favoriteColumns: Int {
        switch widthClass {
        case .compact: 2
        case .regular: 3
        case .wide: 4
        }
    }

    /// Largeur d'un aperçu de menu contextuel : celle de la fenêtre sur iPhone, bornée au-delà.
    var previewWidth: CGFloat {
        min(width, 500)
    }

    /// Avant la première mesure : une largeur d'iPhone, l'affichage historique.
    static let initial = LayoutContext(width: 393)
}

extension EnvironmentValues {
    @Entry var layout = LayoutContext.initial
}

extension View {
    /// À poser sur la racine de la fenêtre : mesure sa largeur et la transmet à toutes les vues,
    /// feuilles comprises.
    func providingLayoutContext() -> some View {
        modifier(LayoutContextProvider())
    }

    /// Borne le contenu à une largeur de lecture et le centre. Sans effet sur iPhone,
    /// plus étroit que la borne.
    func readableWidth(_ maxWidth: CGFloat = LayoutContext.readableWidth) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Pour un `ScrollView` : le contenu défile dans une colonne de lecture centrée, mais la zone
    /// de défilement et ses indicateurs gardent toute la largeur. Mesuré sur la vue elle-même,
    /// pour rester juste dans une colonne plus étroite que la fenêtre.
    func readableScrollContent(_ maxWidth: CGFloat = LayoutContext.readableWidth) -> some View {
        modifier(ReadableScrollContent(maxWidth: maxWidth))
    }
}

private struct ReadableScrollContent: ViewModifier {
    let maxWidth: CGFloat
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        let inset = max(0, (width - maxWidth) / 2)
        Group {
            // Aucune marge ajoutée tant que la vue tient dans la colonne (iPhone) :
            // les marges déjà posées par l'écran restent seules en jeu.
            if inset > 0 {
                content.contentMargins(.horizontal, inset, for: .scrollContent)
            } else {
                content
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

private struct LayoutContextProvider: ViewModifier {
    @State private var layout = LayoutContext.initial

    func body(content: Content) -> some View {
        content
            .environment(\.layout, layout)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                layout.width = width
            }
    }
}

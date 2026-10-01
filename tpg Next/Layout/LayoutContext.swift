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
    var height: CGFloat = 0
    /// Écran à moitié plié (iPhone Duo) : un pli actif le partage en deux.
    var isFolded = false
    /// Forcé à l'affichage iPhone, quelle que soit la largeur : voir `singleColumnWhenFoldedPortrait()`.
    var isSingleColumn = false

    var widthClass: WidthClass {
        if isSingleColumn { return .compact }
        return switch width {
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

    /// Plié en portrait, chaque moitié est plus étroite qu'un iPhone.
    var isFoldedPortrait: Bool {
        isFolded && height > width
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

    /// Plié en portrait (iPhone Duo), la vue garde l'affichage iPhone sur toute la largeur, sans
    /// panneau à côté : dans une moitié d'écran, ni la liste ni le détail n'avaient la place.
    func singleColumnWhenFoldedPortrait() -> some View {
        modifier(SingleColumnWhenFoldedPortrait())
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
        // Une zone sûre élargie plutôt qu'une marge de contenu : une marge posée ici pour
        // `.scrollContent` l'emportait sur celles de l'écran (`.automatic`), y compris en haut.
        // La liste d'un arrêt ou d'une ligne remontait alors sous son titre, dès que la colonne
        // dépassait la largeur de lecture (iPad en paysage). Sans effet tant qu'elle tient (iPhone).
        content
            .safeAreaPadding(.horizontal, max(0, (width - maxWidth) / 2))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

private struct LayoutContextProvider: ViewModifier {
    @State private var layout = LayoutContext.initial

    private struct Measure: Equatable {
        var size: CGSize
        var isFolded: Bool
    }

    func body(content: Content) -> some View {
        content
            .environment(\.layout, layout)
            .onGeometryChange(for: Measure.self) { proxy in
                Measure(size: proxy.size, isFolded: Self.isFolded(proxy))
            } action: { measure in
                layout.width = measure.size.width
                layout.height = measure.size.height
                layout.isFolded = measure.isFolded
            }
    }

    private static func isFolded(_ proxy: GeometryProxy) -> Bool {
        guard #available(iOS 27.1, *) else { return false }
        return proxy.reservedRegions(kind: .division).contains { $0.isActive }
    }
}

private struct SingleColumnWhenFoldedPortrait: ViewModifier {
    @Environment(\.layout) private var layout

    func body(content: Content) -> some View {
        var single = layout
        single.isSingleColumn = layout.isFoldedPortrait
        return content.environment(\.layout, single)
    }
}

//
//  StopNameView.swift
//  tpgNextFunc
//
//  Le nom d'un arrêt, affiché de la même façon par l'app, la montre et le widget.
//

import SwiftUI

/// « Genève, Rive » : la commune en petit au-dessus, l'arrêt en dessous. Un nom sans
/// commune (« Cornavin ») tient sur une ligne, suivi de l'icône du train ou du bateau.
public struct StopNameView: View {
    /// Les polices d'un usage. Les réunir ici permettra d'adapter tous les noms
    /// d'arrêts d'un coup (tailles de police dynamiques, iPad).
    public struct Style {
        var single: Font
        var locality: Font
        var name: Font
        var boldName = true
        var spacing: CGFloat?
        var singleScale: CGFloat = 0.5
        var localityScale: CGFloat = 0.5
        var nameScale: CGFloat = 0.5
        var singleLineLimit: Int?
        var localityLineLimit: Int?
        var nameLineLimit: Int?
        var dimsLocality = false
        var icon: Font = .subheadline

        /// En-tête de l'écran d'un arrêt.
        public static let title = Style(single: .largeTitle, locality: .title2, name: .largeTitle)
        /// Départ et arrivée d'un trajet.
        public static let header = Style(single: .title3, locality: .callout, name: .title2)
        /// Carte d'arrêt de l'accueil et des cartes.
        public static let card = Style(single: .title3, locality: .subheadline, name: .title3, icon: .headline)
        /// Ligne de liste. Les limites de lignes ne jouent qu'avec un texte agrandi : sans elles,
        /// un nom se coupait presque syllabe par syllabe au lieu de rapetisser.
        public static let row = Style(single: .headline, locality: .caption, name: .callout,
                                      localityScale: 0.4, singleLineLimit: 2, localityLineLimit: 1, nameLineLimit: 1)
        /// Montre.
        public static let compact = Style(single: .headline, locality: .caption2, name: .caption,
                                          singleScale: 0.2, localityScale: 0.2, nameScale: 0.3,
                                          singleLineLimit: 2, localityLineLimit: 1, nameLineLimit: 1)
        /// En-tête du widget.
        public static let widget = Style(single: .headline, locality: .caption2, name: .headline,
                                         boldName: false, spacing: -2,
                                         singleScale: 0.6, localityScale: 1, nameScale: 0.6,
                                         singleLineLimit: 1, localityLineLimit: 1, nameLineLimit: 1,
                                         dimsLocality: true)
    }

    let stopName: String
    let style: Style
    let transportType: String?

    /// - Parameter transportType: `"TRAIN"` ou `"BOAT"` ajoute l'icône après un nom sans commune.
    public init(_ stopName: String, style: Style, transportType: String? = nil) {
        self.stopName = stopName
        self.style = style
        self.transportType = transportType
    }

    public var body: some View {
        let parts = splitString(stopName, separator: ",")
        if parts.1.isEmpty {
            HStack {
                Text(parts.0)
                    .font(style.single)
                    .bold(style.boldName)
                    .lineLimit(style.singleLineLimit)
                    .minimumScaleFactor(style.singleScale)
                if transportType == "TRAIN" {
                    Image(systemName: "lightrail").font(style.icon)
                } else if transportType == "BOAT" {
                    Image(systemName: "ferry").font(style.icon)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: style.spacing) {
                Text(parts.0)
                    .font(style.locality)
                    .foregroundStyle(style.dimsLocality ? AnyShapeStyle(.secondary) : AnyShapeStyle(.foreground))
                    .lineLimit(style.localityLineLimit)
                    .minimumScaleFactor(style.localityScale)
                Text(parts.1)
                    .font(style.name)
                    .bold(style.boldName)
                    .lineLimit(style.nameLineLimit)
                    .minimumScaleFactor(style.nameScale)
            }
        }
    }
}

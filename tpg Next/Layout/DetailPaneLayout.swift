//
//  DetailPaneLayout.swift
//  tpg Next
//
//  Disposition commune des panneaux de détail sur grand écran : la carte flotte en haut, un
//  titre en capsule juste dessous, et les détails défilent derrière — comme les titres flottants
//  des pages complètes.
//

import SwiftUI

struct DetailPaneLayout<MapContent: View, Title: View, Details: View>: View {
    /// Part de la hauteur occupée par la carte.
    var mapFraction: CGFloat = 0.5
    @ViewBuilder var map: MapContent
    @ViewBuilder var title: Title
    @ViewBuilder var details: Details

    /// Hauteur du titre : les détails commencent dessous, même avec un texte agrandi.
    @State private var titleHeight: CGFloat = 0
    private let spacing: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            let mapHeight = geometry.size.height * mapFraction
            ZStack(alignment: .top) {
                ScrollView {
                    details
                        .padding(.bottom, 30)
                }
                // Les détails passent sous la carte : ils commencent au-dessous du titre.
                .contentMargins(.top, mapHeight + titleHeight + spacing * 2, for: .automatic)

                VStack(spacing: spacing) {
                    map
                        .frame(height: mapHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                    title
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
                    // Le reste de la colonne laisse passer les touchers vers les détails.
                    Spacer(minLength: 0)
                }
            }
        }
        .padding([.horizontal, .bottom])
        .padding(.top, 8)
    }
}

/// Titre d'un panneau de détail : une capsule posée entre la carte et les détails.
struct PaneTitleCapsule<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .glassForegroundStyle(Color.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .tpgSurface(interactive: true, legacy: .thinMaterial)
            // Plafonné comme les barres d'outils : en taille d'accessibilité, le titre
            // couvrait les détails.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

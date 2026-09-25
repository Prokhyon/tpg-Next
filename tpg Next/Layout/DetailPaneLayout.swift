//
//  DetailPaneLayout.swift
//  tpg Next
//
//  Disposition commune des panneaux de détail sur grand écran : la carte flotte en haut, un
//  titre en capsule juste dessous, et les détails défilent derrière — comme les titres flottants
//  des pages complètes.
//

import SwiftUI

struct DetailPaneLayout<MapContent: View, Title: View, Actions: View, Details: View>: View {
    /// Part de la hauteur occupée par la carte.
    var mapFraction: CGFloat = 0.5
    /// Toucher le titre ouvre la page complète de ce qu'il nomme.
    var openFull: (() -> Void)? = nil
    /// Ferme le détail : une bulle à droite du titre.
    var close: (() -> Void)? = nil
    /// Ouvre la carte en plein écran : un bouton sur la carte.
    var expandMap: (() -> Void)? = nil
    @ViewBuilder var map: MapContent
    @ViewBuilder var title: Title
    /// Boutons flottants en bas à droite du panneau.
    @ViewBuilder var actions: Actions
    @ViewBuilder var details: Details

    /// Hauteur du titre : les détails commencent dessous, même avec un texte agrandi.
    @State private var titleHeight: CGFloat = 0
    private let spacing: CGFloat = 10
    /// Carte, titre et détails partagent ces bords : les rangées glissent derrière la carte
    /// sans dépasser d'un côté ni de l'autre.
    private let sideInset: CGFloat = 16
    private let corner: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            let mapHeight = geometry.size.height * mapFraction
            ZStack(alignment: .top) {
                // Les rangées passent derrière la carte, qui les cache. La zone de défilement
                // commence sous ses coins hauts : rien ne peut apparaître au-dessus d'elle.
                VStack(spacing: 0) {
                    Color.clear.frame(height: corner)
                    ScrollView {
                        details
                            .padding(.horizontal, sideInset)
                    }
                    .contentMargins(.top, mapHeight + titleHeight + spacing * 2 - corner, for: .automatic)
                    .contentMargins(.bottom, 30, for: .automatic)
                    .ignoresSafeArea(.container, edges: .bottom)
                }

                VStack(spacing: spacing) {
                    map
                        .frame(height: mapHeight)
                        .clipShape(RoundedRectangle(cornerRadius: corner))
                        .overlay(alignment: .bottomTrailing) {
                            if let expandMap {
                                Button(action: expandMap) {
                                    Image(systemName: "arrow.down.backward.and.arrow.up.forward")
                                        .font(.subheadline.bold())
                                        .padding(10)
                                }
                                .tpgSurface(interactive: true, legacy: .thinMaterial)
                                .padding(12)
                                .accessibilityLabel("Carte en plein écran")
                            }
                        }

                    HStack(spacing: spacing) {
                        if let openFull {
                            Button(action: openFull) { title }
                                .buttonStyle(.plain)
                        } else {
                            title
                        }
                        if let close {
                            Button(action: close) {
                                Image(systemName: "xmark")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                            }
                            .tpgSurface(interactive: true, legacy: .thinMaterial)
                            .accessibilityLabel("Fermer")
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }

                    // Le reste de la colonne laisse passer les touchers vers les détails.
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, sideInset)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        actions
                    }
                }
                .padding([.horizontal, .bottom])
            }
        }
        .padding(.top, 8)
    }
}

extension DetailPaneLayout where Actions == EmptyView {
    /// Un panneau sans boutons flottants.
    init(mapFraction: CGFloat = 0.5,
         openFull: (() -> Void)? = nil,
         close: (() -> Void)? = nil,
         expandMap: (() -> Void)? = nil,
         @ViewBuilder map: () -> MapContent,
         @ViewBuilder title: () -> Title,
         @ViewBuilder details: () -> Details) {
        self.init(mapFraction: mapFraction, openFull: openFull, close: close, expandMap: expandMap,
                  map: map, title: title, actions: { EmptyView() }, details: details)
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

/// Bouton flottant d'un panneau, en bas à droite.
struct PaneActionButton: View {
    let icon: Image
    var label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon
                .font(.title3)
                .padding(12)
        }
        .tpgSurface(interactive: true, legacy: .thinMaterial)
        .accessibilityLabel(label)
    }
}

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

    var body: some View {
        GeometryReader { geometry in
            // La carte monte jusqu'en haut de la fenêtre, sous les barres flottantes ; ses
            // commandes, elles, restent sous elles.
            let topInset = geometry.safeAreaInsets.top
            let height = geometry.size.height + topInset
            let mapHeight = height * mapFraction
            ZStack(alignment: .top) {
                // Pleine largeur : le défilement part du bord de la fenêtre.
                ScrollView {
                    details
                        .padding(.bottom, 30)
                }
                // Les détails commencent sous le titre et disparaissent au bas de la carte.
                .contentMargins(.top, mapHeight + titleHeight + spacing * 2, for: .automatic)
                .mask(Rectangle().padding(.top, mapHeight + spacing))

                VStack(spacing: spacing) {
                    map
                        // La carte passe sous les barres ; ses commandes restent dessous.
                        .environment(\.paneTopInset, topInset)
                        .frame(height: mapHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
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
                .padding(.horizontal)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        actions
                    }
                }
                .padding([.horizontal, .bottom])
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .padding(.bottom)
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

/// Hauteur des barres flottantes au-dessus d'une carte de panneau : ses commandes s'en écartent.
extension EnvironmentValues {
    @Entry var paneTopInset: CGFloat = 0
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

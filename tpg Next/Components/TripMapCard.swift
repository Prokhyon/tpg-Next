//
//  TripMapCard.swift
//  tpg Next
//
//  La carte d'un trajet dans un cadre arrondi : la moitié droite de la recherche d'itinéraire
//  et celle de la page d'un itinéraire, sur grand écran.
//

import SwiftUI
import tpgNextFunc

struct TripMapCard: View {
    let trip: TripEvent
    /// L'étape cadrée ; `nil` = le trajet entier.
    @Binding var focus: TripMapFocus?

    var body: some View {
        // Nouvelle carte à chaque trajet : les tracés sont calculés à l'apparition.
        TripMapView(tripEvent: trip, focus: focus)
            .id(trip)
            .overlay(alignment: .bottomTrailing) {
                if focus != nil {
                    Button {
                        focus = nil
                    } label: {
                        Label("Tout le trajet", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                    .tpgSurface(interactive: true, legacy: .thinMaterial)
                    .padding(12)
                    .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

//
//  TripActionsMenu.swift
//  tpg Next
//
//  Actions d'itinéraire proposées sur un arrêt : partir d'ici, y aller, trajet rapide.
//

import SwiftUI
import tpgNextFunc

/// « Partir d'ici », « Aller ici » et, au besoin, « Trajet rapide » pour un arrêt.
/// À placer dans un `contextMenu` ou un `Menu`.
struct TripActionsMenu: View {
    @Environment(ItineraryViewModel.self) var tripViewModel
    @Environment(NavigationModel.self) var navigationModel
    let stop: Stop
    var includesQuickTrip = true

    var body: some View {
        Button {
            tripViewModel.outerTrip(tab: navigationModel, isDeparture: true, stop: stop, isQuickTrip: false)
        } label: {
            Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
        }
        Button {
            tripViewModel.outerTrip(tab: navigationModel, isDeparture: false, stop: stop, isQuickTrip: false)
        } label: {
            Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
        }
        if includesQuickTrip {
            Button {
                tripViewModel.outerTrip(tab: navigationModel, isDeparture: false, stop: stop, isQuickTrip: true)
            } label: {
                Label("Trajet rapide", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
            }
        }
    }
}

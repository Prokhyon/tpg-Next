//
//  TripDetailPane.swift
//  tpg Next
//
//  Moitié droite de la page itinéraire sur grand écran : la carte du trajet sélectionné sur un
//  tiers de la hauteur, ses étapes sur les deux tiers restants.
//

import SwiftUI
import tpgNextFunc

struct TripDetailPane: View {
    let trip: TripEvent?
    @Binding var showTime: Bool
    let close: () -> Void

    /// L'étape cadrée sur la carte ; `nil` = le trajet entier.
    @State private var focus: TripMapFocus?

    var body: some View {
        Group {
            if let trip {
                DetailPaneLayout(mapFraction: 1.0 / 3.0) {
                    TripMapCard(trip: trip, focus: $focus)
                } title: {
                    PaneTitleCapsule {
                        TripDetailHeader(trip: trip, close: close)
                    }
                } details: {
                    TripLegsList(fullTrip: trip, showTime: $showTime, onFocus: toggleFocus, focusedID: focus?.id)
                        .id(trip)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.largeTitle)
                    Text("Choisissez un itinéraire pour voir son trajet et sa carte.")
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding([.horizontal, .bottom])
                .padding(.top, 8)
            }
        }
        // Autre trajet : la carte repart sur le trajet entier.
        .onChange(of: trip?.id) { focus = nil }
    }

    /// Toucher l'étape déjà cadrée revient au trajet entier.
    private func toggleFocus(_ target: TripMapFocus) {
        withAnimation { focus = focus == target ? nil : target }
    }
}

/// Départ → arrivée, date et durée, pleine page, enregistrement et fermeture.
private struct TripDetailHeader: View {
    @Environment(SavedTripsModel.self) private var savedTripsModel
    @Environment(\.openRoute) private var openRoute
    let trip: TripEvent
    let close: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                fullTripViewTitle(departureStopName: trip.startName, arrivalStopName: trip.endName)
                fullTripViewTimeDate(duration: trip.duration, date: localDayString(fromUTC: trip.startTime))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            // La page de l'itinéraire, avec la carte à côté des étapes : le retour ramène ici.
            Button {
                openRoute(.trip(trip))
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.title2)
            }
            .accessibilityLabel("Ouvrir en plein écran")
            Button {
                if savedTripsModel.tripIsSaved(trip) {
                    savedTripsModel.removeTrip(trip)
                } else {
                    savedTripsModel.addTrip(trip)
                }
            } label: {
                Image(savedTripsModel.tripIsSaved(trip) ? "scurvepath.stack.fill.badge.minus" : "scurvepath.stack.fill.badge.plus")
                    .font(.title2)
            }
            .accessibilityLabel(savedTripsModel.tripIsSaved(trip) ? "Ne plus enregistrer l'itinéraire" : "Enregistrer l'itinéraire")
            Button(action: close) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Fermer")
        }
    }
}

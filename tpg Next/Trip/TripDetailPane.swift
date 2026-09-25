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
    @Environment(SavedTripsModel.self) private var savedTripsModel
    @Environment(\.openRoute) private var openRoute
    let trip: TripEvent?
    @Binding var showTime: Bool
    let close: () -> Void

    /// L'étape cadrée sur la carte ; `nil` = le trajet entier.
    @State private var focus: TripMapFocus?

    var body: some View {
        Group {
            if let trip {
                DetailPaneLayout(mapFraction: 1.0 / 3.0,
                                 openFull: { openRoute(.trip(trip)) },
                                 close: close,
                                 expandMap: { openRoute(.tripMap(trip)) }) {
                    TripMapCard(trip: trip, focus: $focus)
                } title: {
                    // Plusieurs bulles plutôt qu'une grande capsule : le trajet, puis sa date
                    // et sa durée — qui s'efface quand la place manque.
                    ViewThatFits(in: .horizontal) {
                        titleBubbles(trip, showsTimeDate: true)
                        titleBubbles(trip, showsTimeDate: false)
                    }
                } actions: {
                    HStack(spacing: 10) {
                        PaneActionButton(icon: Image(savedTripsModel.tripIsSaved(trip) ? "scurvepath.stack.fill.badge.minus" : "scurvepath.stack.fill.badge.plus"),
                                         label: savedTripsModel.tripIsSaved(trip) ? "Ne plus enregistrer l'itinéraire" : "Enregistrer l'itinéraire") {
                            if savedTripsModel.tripIsSaved(trip) {
                                savedTripsModel.removeTrip(trip)
                            } else {
                                savedTripsModel.addTrip(trip)
                            }
                        }
                        PaneActionButton(icon: Image(systemName: "arrow.up.forward.square"), label: "Ouvrir en plein écran") {
                            openRoute(.trip(trip))
                        }
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

    private func titleBubbles(_ trip: TripEvent, showsTimeDate: Bool) -> some View {
        HStack(spacing: 10) {
            PaneTitleCapsule {
                HStack(spacing: 8) {
                    fullTripViewTitle(departureStopName: trip.startName, arrivalStopName: trip.endName)
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if showsTimeDate {
                PaneTitleCapsule {
                    fullTripViewTimeDate(duration: trip.duration, date: localDayString(fromUTC: trip.startTime))
                        .font(.subheadline)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Toucher l'étape déjà cadrée revient au trajet entier.
    private func toggleFocus(_ target: TripMapFocus) {
        withAnimation { focus = focus == target ? nil : target }
    }
}

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

    private let spacing: CGFloat = 12

    var body: some View {
        Group {
            if let trip {
                GeometryReader { geometry in
                    VStack(spacing: spacing) {
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
                            .frame(height: (geometry.size.height - spacing) / 3)

                        VStack(spacing: 0) {
                            TripDetailHeader(trip: trip, close: close)
                                .padding(20)
                            Divider()
                            ScrollView {
                                TripLegsList(fullTrip: trip, showTime: $showTime, onFocus: toggleFocus, focusedID: focus?.id)
                                    .padding(.vertical, 10)
                            }
                            .id(trip)
                        }
                        .frame(maxHeight: .infinity)
                        .background { BasicCard(cornerRadius: 30) }
                    }
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
                .background { BasicCard(cornerRadius: 30) }
            }
        }
        .padding([.horizontal, .bottom])
        .padding(.top, 8)
        // Autre trajet : la carte repart sur le trajet entier.
        .onChange(of: trip?.id) { focus = nil }
    }

    /// Toucher l'étape déjà cadrée revient au trajet entier.
    private func toggleFocus(_ target: TripMapFocus) {
        withAnimation { focus = focus == target ? nil : target }
    }
}

/// Départ → arrivée, date et durée, enregistrement et fermeture.
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

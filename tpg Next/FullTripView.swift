//
//  FullTripView.swift
//  tpg Next
//
//  Created by Loris Thomas on 03.12.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc

struct FullTripView: View {
    @Environment(\.displayTime) private var now
    @Environment(SavedTripsModel.self) var savedTripsModel
    @Environment(\.openRoute) private var openRoute
    @Environment(\.layout) private var layout
    var fullTrip: TripEvent
    /// Sur grand écran, l'étape cadrée sur la carte ; `nil` = le trajet entier.
    @State private var focus: TripMapFocus?
    @State private var lineManager = LineManager()
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    @State private var showTime = true
    /// L'itinéraire à répéter chaque semaine.
    @State private var repeating: TripEvent?
    private var liveActivities = TripLiveActivities.shared
    
    @Namespace private var namespace


    var body: some View {
//        GeometryReader { geometry in
        // Sur grand écran, la carte à droite des étapes : toucher une étape la cadre.
        AdaptiveSplit {
            ZStack {
                VStack(alignment: .leading) {
//                    Spacer(minLength: 70) //Space for trip title to be placed on top
                    ScrollView { //trip details scroll area
                        TripLegsList(fullTrip: fullTrip, showTime: $showTime,
                                     onFocus: layout.showsSecondaryPane ? toggleFocus : nil, focusedID: focus?.id)
                    }
                    .contentMargins(.top, 80.0, for: .automatic)
                    .contentMargins(.bottom, 40, for: .automatic)
                    .readableScrollContent()
                    .onAppear {
                        showTime = timeDefault
                    }
                }
                LegacyTopFade()
                
                VStack { //Trip title above the details
                    TPGGlassContainer {
                        HStack {
                            fullTripViewTitle(departureStopName: fullTrip.startName, arrivalStopName: fullTrip.endName)
                                .glassForegroundStyle(.text)
                                .frame(height: 70)
                                .padding(.horizontal, 20)
                                .tpgSurface(interactive: true, legacy: .thinMaterial, glassID: "title", namespace: namespace)
                            if !TPGSurface.isGlass {
                                Spacer()
                            }
                            fullTripViewTimeDate(duration: fullTrip.duration, date: localDayString(fromUTC: fullTrip.startTime))
                                .glassForegroundStyle(.text)
                                .frame(height: 70)
                                .padding(.horizontal, 20)
                                .tpgSurface(interactive: true, legacy: .thinMaterial, glassID: "timeDate", namespace: namespace)
                        }
                        .padding(.horizontal)
                    }
                    Spacer()
                }
            }
        } secondary: {
            TripMapCard(trip: fullTrip, focus: $focus)
                .padding([.horizontal, .bottom])
                .padding(.top, 8)
        }
            .toolbar {
                TrailingBarButtons {
                    ShowTimeButton(showTime: $showTime)
                    Menu {
                        if savedTripsModel.tripIsSaved(fullTrip) {
                            Button(action: {
                                savedTripsModel.removeTrip(fullTrip)
                            }) {
                                Label("Ne plus enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.minus")
                            }
                        } else {
                            Button(action: {
                                savedTripsModel.addTrip(fullTrip)
                            }) {
                                Label("Enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.plus")
                            }
                        }
                        if liveActivities.isTracking(TripLiveActivities.key(for: fullTrip)) {
                            Button {
                                liveActivities.stop(TripLiveActivities.key(for: fullTrip))
                            } label: {
                                Label("Arrêter le suivi en direct", systemImage: "stop.circle")
                            }
                        } else if liveActivities.areEnabled, !hasPassed(fullTrip.endDate, includingCurrentMinute: true, now: now) {
                            Button {
                                liveActivities.start(trip: fullTrip)
                            } label: {
                                Label("Suivre en direct", systemImage: "inset.filled.circle")
                            }
                        }
                        Button {
                            repeating = fullTrip
                        } label: {
                            Label("Répéter chaque semaine…", systemImage: "calendar.badge.plus")
                        }
                        if !layout.showsSecondaryPane {
                            Button {
                                openRoute(.tripMap(fullTrip))
                            } label: {
                                Label("Afficher la carte", systemImage: "map")
                            }
                        }
                        //                    Button(action: {
                        //
                        //                    }) {
                        //                        Label("Partager l'itinéraire", systemImage: "square.and.arrow.up")
                        //                    }
                    } label: {
                        Label("Actions de l'itinéraire", systemImage: "ellipsis")
                    }
                }
            }
        .sheet(item: $repeating) { trip in
            RegularTripEditor(creatingFrom: trip)
        }
        .navigationTitle("Détail itinéraire") // Set back button text
        // Barre transparente pour cet écran seulement : l'ancien réglage UIKit s'appliquait à toute l'app.
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("") // Visible title
            }
        }
    }

    /// Toucher l'étape déjà cadrée revient au trajet entier.
    private func toggleFocus(_ target: TripMapFocus) {
        withAnimation { focus = focus == target ? nil : target }
    }
}

struct fullTripViewTitle: View {
    var departureStopName: String
    var arrivalStopName: String
    
    var body: some View {
                HStack(alignment: .center) {
                    StopNameView(departureStopName, style: .header)
                    Image(systemName: "arrow.right")
                    StopNameView(arrivalStopName, style: .header)
                }
//                .padding(.leading, 50)
//                .padding(.trailing,10)
//                .frame(height: 60)
    }
}

struct fullTripViewTimeDate: View {
    var duration: String
    var date: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "calendar")
                if let formattedDate = convertDateString(date) {
                    Text(formattedDate)//.minimumScaleFactor(0.5)
                }
            }
            HStack {
                Image(systemName: "timer")
                Text(durationText(duration))
            }
        }
        .fixedSize()
    }
}

#Preview("Trajet — avec correspondance") {
    FullTripView(fullTrip: PreviewData.tripWithTransfer)
        .previewEnvironment()
}

#Preview("Trajet — direct") {
    FullTripView(fullTrip: PreviewData.directTrip)
        .previewEnvironment()
}

#Preview("Trajet — tous les résultats") {
    // Faire défiler les pages pour passer d'un itinéraire enregistré à l'autre.
    TabView {
        ForEach(PreviewData.trips) { trip in
            FullTripView(fullTrip: trip)
        }
    }
    .tabViewStyle(.page)
    .previewEnvironment()
}

#Preview("Trajet — enregistré") {
    FullTripView(fullTrip: PreviewData.tripWithTransfer)
        .previewEnvironment(savedTrips: [PreviewData.tripWithTransfer])
}

#Preview("Trajet — iPad", traits: .iPadLandscape) {
    FullTripView(fullTrip: PreviewData.tripWithTransfer)
        .previewEnvironment()
}

#Preview("En-têtes de trajet", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 20) {
        fullTripViewTitle(departureStopName: "Genève, Rive", arrivalStopName: "Genève, gare Cornavin")
        fullTripViewTitle(departureStopName: "Ma position", arrivalStopName: "Plan-les-Ouates, ZIPLO-Pré-Fleuri Nord")
        fullTripViewTimeDate(duration: PreviewData.tripWithTransfer.duration, date: PreviewData.tripWithTransfer.startTime)
    }
    .padding()
}

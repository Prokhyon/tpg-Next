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
    var fullTrip: TripEvent
    @State private var lineManager = LineManager()
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    @State private var showTime = true
    /// L'itinéraire à répéter chaque semaine.
    @State private var repeating: TripEvent?
    
    @Namespace private var namespace


    var body: some View {
//        GeometryReader { geometry in
            ZStack {
                VStack(alignment: .leading) {
//                    Spacer(minLength: 70) //Space for trip title to be placed on top
                    ScrollView { //trip details scroll area
                        TripLegsList(fullTrip: fullTrip, showTime: $showTime)
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
        
            .toolbar {
                HStack {
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
                        Button {
                            repeating = fullTrip
                        } label: {
                            Label("Répéter chaque semaine…", systemImage: "calendar.badge.plus")
                        }
                        Button {
                            openRoute(.tripMap(fullTrip))
                        } label: {
                            Label("Afficher la carte", systemImage: "map")
                        }
                        //                    Button(action: {
                        //
                        //                    }) {
                        //                        Label("Partager l'itinéraire", systemImage: "square.and.arrow.up")
                        //                    }
                    } label: {
                        Image(systemName: "ellipsis").font(.title3)
                            .padding(.trailing, 10)
                    }
                }
                .background {
                    Capsule()
                        .opacity(TPGSurface.isGlass ? 0 : 1)
                        .foregroundStyle(.ultraThinMaterial)
                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
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

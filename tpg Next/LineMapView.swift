//
//  LineMapView.swift
//  tpg Next
//
//  Created by Loris Thomas on 11.08.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc
import Combine

/// La carte d'une course en plein écran : la carte de la moitié droite (`LineMapPanel`, avec
/// la position estimée du véhicule), le titre flottant et les départs de l'arrêt touché.
struct LineMapView: View {
    @Environment(StopStore.self) var stopStore
    @State var autoRefresh = true
    @State private var journey: JourneyTrackModel
    var lineName: String
    var operatorName: String
    var destination: String
    var stopEvent: StopEvent
    var currentStopSloid: String?

    @State private var selectedStop: LineEvent?

    init(lineEvents: [LineEvent], lineName: String, operatorName: String, destination: String, stopEvent: StopEvent, currentStopSloid: String? = nil) {
        _journey = State(initialValue: JourneyTrackModel(events: lineEvents, operatorName: operatorName))
        self.lineName = lineName
        self.operatorName = operatorName
        self.destination = destination
        self.stopEvent = stopEvent
        self.currentStopSloid = currentStopSloid
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LineMapPanel(stopEvent: stopEvent, currentStopSloid: currentStopSloid, journey: journey,
                             selectedStop: selectedStop) { stop in
                    withAnimation { selectedStop = selectedStop == stop ? nil : stop }
                }
                VStack {
                    BackdropBlurView(radius: 5)
                        .frame(height: 50)
                        .mask {
                            Rectangle()
                                .overlay(alignment: .top) {
                                    ScrollMask(leading: true, vertical: true, gradientLength: 100)
                                }
                        }
                        .ignoresSafeArea()
                    Spacer()
                }
                .allowsHitTesting(false)
                VStack {
                    HStack {
                        FloatingLineTitle(destination: destination, currentLine: lineName, operatorName: operatorName)
                            .offset(x: TPGSurface.isGlass ? -50 : 0)
                        Spacer()
                    }
                    Spacer()
                    if let selectedStop, let stop = stopStore.findStop(id: selectedStop.sloid) {
                        SmallStopView(stop: stop, testing: !autoRefresh)
                            .frame(height: geometry.size.height / 3 + 10)
                            .padding(.horizontal, 15)
                            .transition(.opacity)
                            .layoutPriority(1)
                    }
                    Rectangle()
                        .foregroundStyle(.clear)
                        .frame(height: 75)
                }
                .animation(.easeInOut(duration: 0.3), value: selectedStop)
            }
            .toolbar(TPGSurface.isGlass ? .automatic : .hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .periodicRefresh(repeats: autoRefresh) { _ in
                journey.load(stopEvent)
            }
        }
    }
}

#Preview("Carte de ligne") {
    // La carte recharge la course : elle part d'un vrai départ du jour.
    LiveDeparturePreview { departures in
        LineMapView(lineEvents: [], lineName: departures.event.lineName, operatorName: departures.event.operatorName,
                    destination: departures.event.destination, stopEvent: departures.event,
                    currentStopSloid: PreviewData.rive.sloid)
    }
    .previewEnvironment()
}

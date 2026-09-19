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

struct LineMapView: View {
    @Environment(\.displayTime) private var now
    @Environment(StopStore.self) var stopStore
    @State var autoRefresh = true
    @State private var journey: JourneyTrackModel
    var lineName: String
    var operatorName: String
    var destination: String
    var stopEvent: StopEvent
    var currentStopSloid: String?

    @State private var selectedResult: String?

    init(lineEvents: [LineEvent], lineName: String, operatorName: String, destination: String, stopEvent: StopEvent, currentStopSloid: String? = nil) {
        _journey = State(initialValue: JourneyTrackModel(events: lineEvents))
        self.lineName = lineName
        self.operatorName = operatorName
        self.destination = destination
        self.stopEvent = stopEvent
        self.currentStopSloid = currentStopSloid
    }

    var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Map(selection: $selectedResult) {
                        JourneyMapContent(events: journey.events, segments: journey.segments, lineName: lineName,
                                          operatorName: operatorName, currentStopSloid: currentStopSloid, now: now)
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .mapControls {
                        MapUserLocationButton()
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
                    VStack {
                        HStack {
                            FloatingLineTitle(destination: destination, currentLine: lineName, operatorName: operatorName)
                                .offset(x: TPGSurface.isGlass ? -50 : 0)
                            Spacer()
                        }
                        Spacer()
                        if let selectedResult, let stop = stopStore.findStop(id: selectedResult) {
                            SmallStopView(stop: stop, testing: !autoRefresh)
                                .frame(height: geometry.size.height / 3 + 10)
                                .transition(.slide)
                                .animation(.easeInOut(duration: 0.8), value: selectedResult)
                                .layoutPriority(1)
                        }
                        Rectangle()
                            .foregroundStyle(.clear)
                            .frame(height: 75)
                    }
                }
                .toolbar(TPGSurface.isGlass ? .automatic : .hidden, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("") // Visible title
                    }
                }
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

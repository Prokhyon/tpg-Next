//
//  StopMapView.swift
//  tpg Next
//
//  Created by Loris Thomas on 30.08.2024.
//

import SwiftUI
import MapKit
import Combine
import tpgNextFunc

/// La carte d'un arrêt en plein écran : la carte de la moitié droite (`StopMapPanel`), avec
/// le titre flottant, les boutons de la carte dessous, et les départs du quai touché.
struct StopMapView: View {
    @State var autoRefresh = true
    var quays: [Quay]
    var stopSloid: String
    var stopName: String

    @State private var selectedQuay: Quay?
    /// Aucun départ ne s'y affiche : la carte montre les quais seuls.
    @State private var journey = JourneyTrackModel()
    @Namespace private var mapScope

    var body: some View {
        ZStack {
            StopMapPanel(stopSloid: stopSloid, quays: quays, selected: nil, journey: journey,
                         highlightedQuays: selectedQuay.map { [$0.quayName] } ?? [],
                         tapQuay: { quay in
                             withAnimation { selectedQuay = selectedQuay?.id == quay.id ? nil : quay }
                         },
                         zoomedQuay: selectedQuay, controlsScope: mapScope)

            VStack {
                BackdropBlurView(radius: 5)
                    .frame(height: 100)
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
                    Spacer()
                    let title = HStack {
                        StopTitleView(stopName: stopName)
                            .foregroundStyle(Color.text)
                        Rectangle()
                            .fill(.clear)
                            .frame(width: 100, height: 0)
                    }
                    .padding(.horizontal)
                    if #available(iOS 26, *) {
                        title
                            .glassEffect(.regular.interactive())
                            .offset(x: 50, y: 0)
                    } else {
                        title
                            .background {
                                Capsule()
                                    .foregroundStyle(.ultraThinMaterial)
                                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                            }
                            .offset(x: 50, y: 0)
                    }
                }
                HStack {
                    Spacer()
                    VStack {
                        MapUserLocationButton(scope: mapScope)
                            .tpgSurface(in: Circle())
                        MapCompass(scope: mapScope)
                    }
                    .padding(.horizontal)
                }
                Spacer()
                if let selectedQuay {
                    SmallStopView(stop: createStop(nomarret: stopName, sloid: selectedQuay.id), quay: selectedQuay.quayName,
                                  isQuay: true, stopEventNumber: quays.count * 10, testing: !autoRefresh)
                        .heightGrowingWithText(250)
                        .padding(.horizontal, 15)
                        .transition(.opacity)
                }
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(height: TPGSurface.isGlass ? 50 : 60)
            }
            .animation(.easeInOut(duration: 0.2), value: selectedQuay?.id)
        }
        .mapScope(mapScope)
        #if DEBUG
        .task {
            if let name = CaptureOptions.quay, let quay = quays.first(where: { $0.quayName == name }) {
                try? await Task.sleep(for: .seconds(1))
                withAnimation { selectedQuay = quay }
            }
        }
        #endif
        .toolbar(TPGSurface.isGlass ? .automatic : .hidden, for: .navigationBar)
        .navigationTitle("Carte \(stopName)") // Set back button text
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
    }
}

#Preview("Carte des quais") {
    StopMapView(quays: PreviewData.quays, stopSloid: PreviewData.rive.sloid, stopName: PreviewData.rive.name)
        .previewEnvironment()
}

#Preview("Carte des quais — iPad", traits: .iPadLandscape) {
    StopMapView(quays: PreviewData.quays, stopSloid: PreviewData.rive.sloid, stopName: PreviewData.rive.name)
        .previewEnvironment()
}

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

struct StopMapView: View {
    @EnvironmentObject var appRequirementsClass: AppRequirementsClass
    @State var autoRefresh = true
    var quays: [Quay]
    var stopSloid: String
    var stopName: String
    
    @State private var selectedResult: String?
    @State private var position: MapCameraPosition = .automatic
    @Namespace var mapScope
    
    var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Map(position: $position, selection: $selectedResult, scope: mapScope) {
                        ForEach(filteredQuays) { quay in
                            let isSelected = quay.id == selectedResult ? true : false
                            Annotation(String(localized: "quai \(quay.quayName)"), coordinate: CLLocationCoordinate2D(latitude: Double(quay.latitude) ?? 0.0, longitude: Double(quay.longitude) ?? 0.0), anchor: .center) {
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: isSelected ? 5 : 3)
                                    .background(
                                        Circle()
                                            .fill(isSelected ? .accent : .color1).animation(.bouncy, value: selectedResult)
                                    )
                                    .frame(width: (isSelected ? 25 : 18), height: (isSelected ? 25 : 18)).animation(.bouncy, value: selectedResult)
                            }
                            .tag(quay.id)
                        }
                        UserAnnotation().tint(.accent)
                    }
                    .mapControlVisibility(.hidden)
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .onChange(of: selectedResult) {
                        if let selectedId = selectedResult,
                           let quay = returnQuayFromId(id: selectedId) {
                            // Set the new camera position to center and zoom on the selected stop
                            withAnimation {
                                position = .region(
                                    MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(latitude: Double(quay.latitude) ?? 0.0, longitude: Double(quay.longitude) ?? 0.0),
                                        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001) // Adjust the zoom level by changing latitudeDelta and longitudeDelta
                                    )
                                )
                            }
                        }
                    }
                    
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
                    VStack {
                        HStack {
                            Spacer()
                            let title = HStack {
                                VStack {
                                    StopTitleView(stopName: stopName)
                                }
                                    .foregroundStyle(Color.text)
                                Rectangle()
                                    .fill(.clear)
                                    .frame(width: 100, height: 0)
                            }
                            .padding(.horizontal)
                            if #available (iOS 26, *) {
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
                                if #available(iOS 26, *) {
                                    MapUserLocationButton(scope: mapScope)
                                        .glassEffect()
                                } else {
                                    MapUserLocationButton(scope: mapScope)
                                        .background {
                                            Circle()
                                                .foregroundStyle(.ultraThinMaterial)
                                                .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                        }
                                }
                                MapCompass(scope: mapScope)
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                        ZStack {
                            if let selectedResult {
                                SmallStopView(stop: createStop(nomarret: stopName, sloid: selectedResult), quay: returnQuayFromId(id: selectedResult)?.quayName ?? "?", isQuay: true, stopEventNumber: filteredQuays.count*10, testing: !autoRefresh)
//                                    .frame(width: geometry.size.width-30, height: 250)
                                    .frame(height: 250)
                                    .padding(.horizontal, 15)
                                    .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: selectedResult)
                        Rectangle()
                            .foregroundStyle(.clear)
                            .frame(height: appRequirementsClass.version26 ? 50 : 60)
                    }
                }
                .mapScope(mapScope)
                .toolbar(appRequirementsClass.version26 ? .automatic : .hidden, for: .navigationBar)
                .navigationTitle("Carte \(stopName)") // Set back button text
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("") // Visible title
                    }
                }
//                .toolbar(.hidden, for: .navigationBar)

            }
    }
    
        private var filteredQuays: [Quay] {
        // Les quais portent le sloid de l'arrêt parent suivi de leur propre suffixe.
        let parentSloid = sloidHarmonizer(code: stopSloid)
        return quays.filter { sloidHarmonizer(code: $0.id) == parentSloid }
    }
    
    func returnQuayFromId(id: String) -> Quay? {
        return quays.first { $0.id == id }
    }
}

struct stopMapPreview: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()
        @StateObject var fullTripTest = FullTripTest()
        
        @StateObject var savedTripsModel = SavedTripsModel()
        @StateObject var regularTripsModel = RegularTripsModel()
        @StateObject var appRequirementsClass = AppRequirementsClass()
            @StateObject var itineraryViewModel = ItineraryViewModel()
        return StopMapView(quays: [], stopSloid: "", stopName: "Meinier, Eglise")
            .environmentObject(itineraryViewModel)
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
            .environmentObject(savedTripsModel)
            .environmentObject(regularTripsModel)
            .environmentObject(appRequirementsClass)
        
    }
}

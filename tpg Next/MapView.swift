//
//  MapView.swift
//  tpg Next
//
//  Created by Loris Thomas on 09.08.2024.
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit
import ClusterMap
import ClusterMapSwiftUI
import Foundation
import tpgNextFunc

struct LocationStop: CoordinateIdentifiable, Identifiable, Hashable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    public var id: String
    public var name: String
}

struct MapView: View {
    @Environment(StopStore.self) var stopStore
    @State private var stopManager = StopManager()
    @State var locationManager = LocationManager()
    @State private var dataSource = DataSource()
    @State private var selectedResult: String?
    @State private var selectedStop: Stop?
    @State private var selectedQuays: [Quay] = []
    @State private var QuayIsSelected = false
    @State var autoRefresh = true
    @State private var mapSize: CGSize = .zero
    
    
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Map(position: $position, selection: $selectedResult) {
                        if selectedResult != nil || selectedStop != nil {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                ForEach(filteredQuays) { quay in
                                    let isSelected = quay.id == selectedResult ? true : false
                                    Annotation(String(localized: "quai \(quay.quayName)"), coordinate: CLLocationCoordinate2D(latitude: Double(quay.latitude) ?? 0.0, longitude: Double(quay.longitude) ?? 0.0), anchor: .center) {
                                            Circle()
                                                .strokeBorder(Color.primary, lineWidth: isSelected ? 4 : 2).animation(.bouncy, value: selectedResult)
                                                .background(
                                                    Circle()
                                                        .fill(isSelected ? .accent : .color1).animation(.bouncy, value: selectedResult)
                                                )
                                                .frame(width: 15, height: 15)
                                        }
                                        .tag(quay.id)
                                }
                            }
                        }
                        ForEach(dataSource.annotations) { stop in
                            let splitStopName = splitString(stop.name, separator: ",")
                            let isSelected = stop.id == selectedResult ? true : false
                            Annotation("\(splitStopName.0)\n\(splitStopName.1)", coordinate: stop.coordinate, anchor: .center) {
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: isSelected ? 5 : 3).animation(.bouncy, value: selectedResult)
                                    .background(
                                        Circle()
                                            .fill(isSelected ? .accent : .color1).animation(.bouncy, value: selectedResult)
                                    )
                                    .frame(width: (isSelected ? 30 : 18), height: (isSelected ? 25 : 18)).animation(.bouncy, value: selectedResult)
                            }
                            .tag(stop.id)
                        }
                        ForEach(dataSource.clusters) { item in
                            
                            Annotation("\(item.count)", coordinate: item.coordinate, anchor: .center) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .blur(radius: 1)
                                    .frame(width: 40)
                                    .overlay(
                                        Text("\(item.count)")
                                    )
                            }
                            .annotationTitles(.hidden)
                        }
                        
                        UserAnnotation()
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                  
                    .readSize(onChange: { newValue in
                        dataSource.mapSize = newValue
                    })
                    .onMapCameraChange { context in
                        dataSource.currentRegion = context.region
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        // Pas de `Task.detached` : la taille et la région de la carte, écrites sur
                        // le fil principal, étaient lues en parallèle depuis un autre fil.
                        Task { await dataSource.reloadAnnotations() }
                    }
                    .onChange(of: selectedResult) {
                        if let selectedId = selectedResult,
                           let stop = stopStore.findStop(id: selectedId) {
                            selectedStop = stop
                            // Set the new camera position to center and zoom on the selected stop
//                            withAnimation {
//                                position = .region(
//                                    MKCoordinateRegion(
//                                        center: stop.wgs84Coordinates.toCLLocationCoordinate2D,
//                                        span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007) // Adjust the zoom level by changing latitudeDelta and longitudeDelta
//                                    )
//                                )
//                            }
                        }
                        if selectedResult == nil {
                            selectedStop = nil
                            
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
                        
                        ZStack {
                            if let selectedResult {
                                if isQuaySloid(selectedResult) {
                                    SmallStopView(stop: createStop(nomarret: selectedStop?.name, sloid: selectedResult), quay: returnQuayFromId(id: selectedResult)?.quayName ?? "?", isQuay: true, stopEventNumber: filteredQuays.count*10, testing: !autoRefresh)
                                        .heightGrowingWithText(250)
                                        .padding(.horizontal, 15)
                                        .readableWidth()
                                        .transition(.opacity)
                                        .onAppear {
                                            QuayIsSelected = true
                                        }
                                        .onDisappear {
                                            QuayIsSelected = false
                                        }
                                } else if let stop = stopStore.findStop(id: selectedResult) {
                                    SmallStopView(stopManager: stopManager, stop: stop, stopEventNumber: 20, testing: !autoRefresh)
                                        .heightGrowingWithText(250)
                                        .padding(.horizontal, 15)
                                        .readableWidth()
                                        .transition(.opacity)
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: selectedResult)
                        if #available(iOS 26, *) { //remplacer avec appVersion object
                            Rectangle()
                                .foregroundStyle(.clear)
                                .frame(height: 50)
                        } else {
                            Rectangle()
                                .foregroundStyle(.clear)
                                .frame(height: 60)
                        }
                    }
                }
                .navigationTitle("Carte") // Set back button text
//                .navigationBarTitleDisplayMode(.inline)
//                .toolbar {
//                    ToolbarItem(placement: .principal) {
//                        Text("") // Visible title
//                    }
//                }
                .toolbar(.hidden, for: .navigationBar)
                .onAppear {
                    if (selectedResult == nil) {
                        withAnimation {
                            getLocationRegion { region in
                                position = .region(region)
                            }
                            
                        }
                    } else {
                        if let selectedId = selectedResult,
                           let stop = stopStore.findStop(id: selectedId) {
                            // Set the new camera position to center and zoom on the selected stop
                            withAnimation {
                                position = .region(
                                    MKCoordinateRegion(
                                        center: stop.wgs84Coordinates.toCLLocationCoordinate2D,
                                        span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007) // Adjust the zoom level by changing latitudeDelta and longitudeDelta
                                    )
                                )
                            }
                        }
                    }
                    dataSource.setStopStore(stopStore.activeStops)
                    Task {
                        await dataSource.removeAnnotations()
                        await dataSource.addAnnotations()
                    }
                }
                // La base se charge en arrière-plan : la carte l'attend si elle s'ouvre avant.
                .onChange(of: stopStore.isLoaded) {
                    dataSource.setStopStore(stopStore.activeStops)
                    Task {
                        await dataSource.removeAnnotations()
                        await dataSource.addAnnotations()
                    }
                }
            }
    }
    func FilterQuays() {
        selectedQuays = filteredQuays
    }
    
    private var filteredQuays: [Quay] {
        if let selectedStop {
            // Les quais portent le sloid de l'arrêt parent suivi de leur propre suffixe.
            stopManager.quays.filter { sloidHarmonizer(code: $0.id) == selectedStop.sloid }
        } else {
            []
        }
    }
    
    func returnQuayFromId(id: String) -> Quay? {
        return stopManager.quays.first { $0.id == id }
    }
    
    func getLocationRegion(completion: @escaping (MKCoordinateRegion) -> Void) {
        var region = MKCoordinateRegion(
            center: Coordinates(lon: 6.14243773412, lat: 46.20973474672).toCLLocationCoordinate2D,
            span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007)
        )
        
        locationManager.requestLocation { location in
            if let userLocation = location {
                region = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            completion(region)  // Return the region after location is fetched
        }
    }
}

struct BlurView: UIViewRepresentable {
    var removeAllFilters: Bool = false

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        DispatchQueue.main.async {
            if let backdropLayer = uiView.layer.sublayers?.first {
                if removeAllFilters {
                    backdropLayer.filters = []
                } else {
                    backdropLayer.filters?.removeAll(where: { filter in
                        String(describing: filter) != "gaussianBlur"
                    })
                }
            }
        }
    }
}

extension MapView {
    struct LocationStopCluster: Identifiable {
            var id = UUID()
            var coordinate: CLLocationCoordinate2D
            var count: Int
        }
    @Observable
    final class DataSource {
        private let clusterManager = ClusterManager<LocationStop>()
        private var mapStops: [LocationStop] = []
        let test = [33, 57, 39843, 78925]

        var annotations: [LocationStop] = []
        var clusters: [LocationStopCluster] = []

        var mapSize: CGSize = .zero
        var currentRegion: MKCoordinateRegion = .sanFrancisco

        func setStopStore(_ stopStore: [Stop]) {
            self.mapStops = copyToMapStops(activeStops: stopStore)
        }
        func addAnnotations() async {
           
            await clusterManager.add(mapStops)
            await reloadAnnotations()
        }

        func removeAnnotations() async {
            await clusterManager.removeAll()
            await reloadAnnotations()
        }

        func reloadAnnotations() async {
            async let changes = clusterManager.reload(mapViewSize: mapSize, coordinateRegion: currentRegion)
            await applyChanges(changes)
            
        }

        @MainActor
        private func applyChanges(_ difference: ClusterManager<LocationStop>.Difference) {
            for removal in difference.removals {
                switch removal {
                case .annotation(let annotation):
                    annotations.removeAll { $0 == annotation }
                case .cluster(let clusterAnnotation):
                    clusters.removeAll { $0.id == clusterAnnotation.id }
                }
            }
            for insertion in difference.insertions {
                switch insertion {
                case .annotation(let newItem):
                    annotations.append(newItem)
                case .cluster(let newItem):
                    clusters.append(LocationStopCluster(
                        id: newItem.id,
                        coordinate: newItem.coordinate,
                        count: newItem.memberAnnotations.count
                    ))
                }
            }
        }
    }
}

public extension MKCoordinateRegion {
    static var sanFrancisco: MKCoordinateRegion {
        .init(
            center: CLLocationCoordinate2D(latitude: 37.787_994, longitude: -122.407_437),
            span: .init(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }
}

func copyToMapStops(activeStops: [Stop]) -> [LocationStop] {
    let mapStops = activeStops.map { stop in
        LocationStop(coordinate: stop.wgs84Coordinates.toCLLocationCoordinate2D, id: stop.id, name: stop.name)
    }
    return mapStops
}

struct MapView2_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()

        let keyboardResponder = KeyboardResponder()

        return MapView()
            .environment(stopStore)
            .environment(favoritesViewModel)
            .environment(keyboardResponder)
    }
}

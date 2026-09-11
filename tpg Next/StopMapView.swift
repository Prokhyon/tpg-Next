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
                .onAppear {
                    print(stopSloid)
                    print(quays)
                }
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

struct CloseDeparturesViewFiltered: View {
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var tripViewModel: ItineraryViewModel
    @EnvironmentObject var tabSelection: NavigationModel
    @StateObject private var stopManager = StopManager()
    @StateObject private var lineManager = LineManager()
    @State private var timer: AnyCancellable?
    var quay: String
    var stop: Stop
    var quayCountRequest: Int
    @State private var isShowingPopover = false
    var isHome: Bool = false
    var autoRefresh = true
    
    @Namespace private var namespace

    var body: some View {
        VStack {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    HeaderQuayView()
                        .padding(.horizontal, 10)
                    DeparturesList()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 15)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 40))
//                        .padding(.horizontal, 10)
                }
            } else {
                HeaderQuayView()
                RoundedRectangle(cornerRadius: 35, style: .continuous)
                    .foregroundStyle(.thinMaterial)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                    .overlay(
                        VStack {
                            //                    HeaderView()
                            DeparturesList()
                        }
                    )
            }
        }
            .onAppear {
                setupStopManager()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                setupStopManager()
            }
            .onDisappear {
                timer?.cancel()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                timer?.cancel()
            }
            .onChange(of: stop) {
                setupStopManager()
            }
            .onChange(of: autoRefresh) {
                if !autoRefresh {
                    timer?.cancel()
                } else {
                    setupStopManager()
                }
            }
    }
    
    private func HeaderQuay1View() -> some View {
        HStack {
            Text("Quai \(quay)")
                .frame(height: 45)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .padding(.trailing, 50)
            Spacer()
            TripButton()
        }
    }
    
    private func HeaderQuayView() -> some View {
        HStack {
            if #available(iOS 26, *), !isHome {
                HStack {
                    Text("Quai \(quay)")
                        .frame(height: 45)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .padding(.trailing, 50)
                }
//                .frame(maxWidth: 200, maxHeight: 45)
                .glassEffect(.regular.interactive())
                .glassEffectID("title", in: namespace)
                Spacer()
                TripButton()
                    .frame(width: 45, height: 45)
                    .padding(10)
                    .glassEffect(.regular.interactive())
                    .glassEffectID("trip", in: namespace)
            } else {
                HStack {
                    Text("Quai \(quay)")
                        .frame(height: 45)
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .padding(.trailing, 40)
                }
//                .frame(maxWidth: 200, maxHeight: 45)
                .background {
                    Capsule()
                        .foregroundStyle(.thinMaterial)
                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                }
                Spacer()
                TripButton()
                    .frame(width: 45, height: 45)
                    .padding(5)
                    .background {
                        Capsule()
                            .foregroundStyle(.thinMaterial)
                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                    }
            }
        }
//        .frame(height: 45)
    }
    private func HeaderView() -> some View {
        HStack {
            NavigationLink {
                StopView(stopName: stop.name, stopSloid: stop.sloid)
            } label: {
                HStack {
                    let splitStopName = splitString(stop.name, separator: ",")
                    if splitStopName.1.isEmpty {
                        Text("\(splitStopName.0) - \(quay)")
                            .font(.title3)
                            .bold()
                            .minimumScaleFactor(0.5)
                        Spacer()
                    } else {
                        VStack {
                            HStack {
                                Text(splitStopName.0).font(.subheadline)
                                Spacer()
                            }
                            HStack {
                                Text("\(splitStopName.1) - \(quay)").font(.title3).bold()
                                Spacer()
                            }
                        }
                        .minimumScaleFactor(0.5)
                    }
                }
            }
            Spacer()
            TripButton()
        }
        .frame(height: 45)
        .padding(.horizontal, 25)
    }
    
    private func TripButton() -> some View {
        if isHome {
            return AnyView(Button(action: {
                tripViewModel.outerTrip(tab: tabSelection, isDeparture: true, stop: stop, isQuickTrip: false)
            }) {
                Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                    .font(.title3)
            })
        } else {
            return AnyView(Menu {
                Button(action: {
                    tripViewModel.outerTrip(tab: tabSelection, isDeparture: true, stop: stop, isQuickTrip: false)
                }) {
                    Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                }
                Button(action: {
                    tripViewModel.outerTrip(tab: tabSelection, isDeparture: false, stop: stop, isQuickTrip: false)
                }) {
                    Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                }
                Button(action: {
                    tripViewModel.outerTrip(tab: tabSelection, isDeparture: false, stop: stop, isQuickTrip: true)
                }) {
                    Label("Trajet rapide", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
                }
            } label: {
                Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                    .font(.title3)
            })
        }
    }

    
    private func DeparturesList() -> some View {
        VStack(spacing:0) {
            if !stopManager.stopEvents.isEmpty {
                ForEach(filteredEvents.sorted(by: { $0.estimatedTime < $1.estimatedTime }).prefix(3), id: \.id) { event in
                    NavigationLink {
                        LineView(stopEvent: event, currentStop: ShortStop(name: stop.name, sloid: sloidHarmonizer(code: stop.sloid)), currentLine: event.lineName)
                    } label: {
                        StopEventView(event: event, showTime: false)
                    }
                    .foregroundStyle(.primary)
                    .contentShape(.contextMenuPreview, Capsule())
                    .contextMenu {
                        NotificationContextMenu(event: event, stopID: stop.sloid)
                    }
                }
            } else {
                HStack {
                    Spacer()
                    if stopManager.stopError {
                        if stopManager.stopErrorMessage == "STOPEVENT_LOCATIONUNSERVED" {
                            Text("Malheureusement, cet arrêt n'est pas disponible depuis l'application, ou n'est pas desservi")
                        } else {
                            Text("Pas de départs trouvés")
                        }
                        Text("Pas de départs trouvés")
                    } else {
                        Text("Recherche des départs...")
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 170)
    }
    
    private func setupStopManager() {
        if autoRefresh {
            stopManager.selectStop(stopName: stop.name, stopSloid: stop.sloid, stopEventNumber: quayCountRequest, timeRequest: Date()) {
                print("Stop selected: \(stop.name)")
            }
            timer = Timer.publish(every: 30, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    stopManager.selectStop(stopName: stop.name, stopSloid: stop.sloid, stopEventNumber: quayCountRequest, timeRequest: Date()) {
                        print("Timer refreshed for stop: \(stop.name)")
                    }
                }
        }
    }
    private var filteredEvents: [StopEvent] {
        stopManager.stopEvents.filter { $0.plannedQuay == quay }
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

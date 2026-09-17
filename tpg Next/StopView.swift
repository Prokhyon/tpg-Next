//
//  NewStopViewTest.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Combine
import tpgNextFunc

struct StopView: View {
    @Environment(\.displayTime) private var now
    @State private var stopManager = StopManager()
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(ItineraryViewModel.self) var tripViewModel
    @Environment(NavigationModel.self) var navigationModel
    @State private var lineManager = LineManager()
    @State private var stopEvents: [StopEvent] = []
    @Environment(StopStore.self) var stopStore
    /// Incrémenté quand l'utilisateur décale l'heure : relance le rafraîchissement sans revenir à l'heure d'origine.
    @State private var refreshGeneration = 0
    /// Hauteur du titre flottant : la liste commence dessous, même avec un texte agrandi.
    @State private var titleHeight: CGFloat = 0
    let stopName: String
    let stopSloid: String
    @State var previousLineRef: String?
    var previousLineName: String?
    var previousLineTime: String?
    @State private var showTime = false
    @State private var timeIntervalNotification = 0
    @State private var viewLineSorted = false //Events are grouped by line
    @State private var viewLineFiltered = false //Filter is active
    @State private var selectedNumber = 5
    @State private var timeRequest = Date() //Time sent to the api for departures
    @State private var requestNumber = 30
    @State private var selectTime = false //display time selection sheet
    @State private var filterLines = false //display filter sheet
    @State private var scrollID = ""
    @State private var scrollNextEvents: Bool = false
    var autoRefresh: Bool = true

    
    var groupedStopEvents: [String: [StopEvent]] {
        stopManager.stopEvents.groupedByLineAndDestination()
    }

    var filteredStopEvents: [String: [StopEvent]] {
            if selectedFilters.isEmpty {
                return groupedStopEvents
            } else {
                return groupedStopEvents.filter { selectedFilters.contains($0.key) }
            }
    }
    var allFilteredStopEvents: [StopEvent] {
        filteredStopEvents.values.flatMap { $0 }.sortedByDeparture()
    }
    
    @State private var selectedFilters: Set<String> = []
        
    @AppStorage(SettingKey.groupByLineByDefault) var groupedDefault = false
//    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    
    @Namespace var topID
    @Namespace var bottomID

    var body: some View {
            ZStack {
                    ScrollViewReader { scroll in
                        ScrollView {
                            if !stopManager.stopError {
                                LazyVStack(spacing: 0) {
                                    
                                    if viewLineSorted {
                                        ForEach(filteredStopEvents.keys.sorted(by: lineGroupPrecedes), id: \.self) { key in
                                            SortedStopEventsView(key: key, filteredStopEvents: filteredStopEvents, groupedStopEvents: groupedStopEvents, showTime: $showTime, previousLineRef: $previousLineRef, stopName: stopName, stopSloid: stopSloid)
                                        }
                                    } else {
                                        ForEach(allFilteredStopEvents, id: \.id) { event in
                                            NavigationLink(value: AppRoute.line(event: event, currentStop: ShortStop(name: stopName, sloid: sloidHarmonizer(code: stopSloid)))) {
                                                StopEventView(event: event, showTime: showTime, previousLineRef: previousLineRef)
                                                    .foregroundStyle(determineColor(for: event.estimatedTime, now: now))
                                            }
                                            .contentShape(.contextMenuPreview, Capsule())
                                            .padding(.horizontal, 15)
                                            .if(!hasPassed(event.departureDate, includingCurrentMinute: false, now: now)) { view in
                                                view.contextMenu {
                                                    NotificationContextMenu(event: event, stopID: stopSloid)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                VStack {
                                    Spacer()
                                    DeparturesUnavailableText(errorMessage: stopManager.stopErrorMessage)
                                        .padding()
                                    Spacer()
                                }
                            }
                        }
                        .contentMargins(.top, max(90.0, titleHeight + 10), for: .automatic)
                        .contentMargins(.bottom, TPGSurface.isGlass ? 75.0 : 125, for: .automatic)
                        .readableScrollContent()
                        
                        .refreshable {
                            timeRequest = Date()
                            getStopEvents()
                        }
                        .onChange(of: allFilteredStopEvents) {
                            if !viewLineSorted {
                                scroll.scrollTo(scrollID, anchor: scrollNextEvents ? UnitPoint(x: 0, y: 0.87) : UnitPoint(x: 0, y: 0.13))
                                scrollID = ""
                            }
                        }
                    }
                VStack {
                    VStack(alignment: .center) {
                        //Stop title element
                        HStack {
                            Spacer()
                            HStack {
                                StopTitleView(stopName: stopName)
                                    .glassForegroundStyle(Color.text)
                                Rectangle()
                                    .fill(.clear)
                                    .frame(width: 100, height: 0)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, TPGSurface.isGlass ? 5 : 0)
                            .tpgSurface(interactive: true)
                            .offset(x: 50)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
                        }
                        Spacer()

                        StopFloatingControls(isGroupedByLine: viewLineSorted,
                                             toggleGrouping: toggleGrouping,
                                             showsFilters: $filterLines,
                                             isFiltered: $viewLineFiltered,
                                             moveTime: moveTime)
                    }
                    .padding(.bottom, TPGSurface.isGlass ? 0 : 50)
                }
                .onAppear {
                    viewLineSorted = groupedDefault
                }
                .periodicRefresh(id: refreshGeneration, repeats: autoRefresh) { trigger in
                    // Sans heure choisie par l'utilisateur, chaque rafraîchissement repart de
                    // maintenant : les bus déjà partis quittent la liste. Ouvert depuis une course,
                    // l'arrêt part de son heure de passage, gardée tant qu'elle est à venir.
                    if refreshGeneration == 0 {
                        let origin = timeRequest(for: previousLineTime)
                        timeRequest = trigger == .start ? origin : max(Date(), origin)
                    }
                    getStopEvents()
                }
            }
        .toolbar {
            HStack {
                ShowTimeButton(showTime: $showTime)

                Button {
                    selectTime.toggle()
                } label: {
                    Label("Selectionner l'heure", systemImage: "clock")
                        .symbolEffect(.bounce.down.byLayer, value: selectTime)
                }

                StopActionsMenu(stopName: stopName, stopSloid: stopSloid, quays: stopManager.quays)
            }
            .legacySurface()
        }
        
        
        .sheet(isPresented: $selectTime) {
            DepartureTimeSheet(time: $timeRequest) {
                refreshGeneration += 1
                selectTime.toggle()
            }
        }
        .sheet(isPresented: $filterLines) {
            LineFilterSheet(groups: groupedStopEvents, selection: $selectedFilters, isFiltered: $viewLineFiltered) {
                filterLines = false
            }
        }

        .navigationTitle("\(stopName)") // Set back button text
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("") // Visible title
            }
        }
    }
    
    private func toggleGrouping() {
        withAnimation(TPGSurface.isGlass ? nil : .default) {
            viewLineSorted.toggle()
        }
        requestNumber = max(viewLineSorted ? groupedStopEvents.keys.count * 5 : 30, 30)
    }
    
    private func getStopEvents() {
        stopManager.selectStop(stopName: stopName, stopSloid: stopSloid, stopEventNumber: requestNumber, timeRequest: timeRequest) {
                    stopEvents = self.stopManager.stopEvents
        }
    }
    private func adjustTime(byAdding minutes: Int) {
        if let newTimeRequest = Calendar.current.date(byAdding: .minute, value: minutes, to: timeRequest) {
            timeRequest = newTimeRequest
        } else {
            Log.ui.error("Décalage de l'heure impossible")
        }
    }
    func timeRequest(for time: String?) -> Date {
        // Une heure absente ou illisible (ouverture depuis le widget, par exemple)
        // veut simplement dire « les départs à partir de maintenant ».
        guard let time, let date = stringToDate(with: time) else { return Date() }
        return date
    }
    private func estimatedTypicalTimeInterval(from events: [StopEvent]) -> Int { //calcul d'interval pour décalement d'heure
        let dates = events.compactMap(\.departureDate).sorted()

        guard dates.count > 2 else {
            return 10 // Valeur par défaut minimale
        }

        // Prendre le 80e percentile (ou autre)
        let index = Int(Double(dates.count - 1) * 0.8)
        let typicalEnd = dates[index]
        let start = dates.first!

        let timeInterval = typicalEnd.timeIntervalSince(start) / 60.0
        return max(5, Int(timeInterval)) // minimum 5 minutes
    }
    
    private func moveTime(previous: Bool) { //Move departures time earlier or later (with top and bottom buttons)
        let interval = estimatedTypicalTimeInterval(from: stopEvents)
        adjustTime(byAdding: previous ? -interval : interval)
        scrollNextEvents = !previous
        // Liste vide (arrêt sans départ, erreur) : on décale l'heure sans cible de défilement.
        scrollID = (previous ? allFilteredStopEvents.first?.id : allFilteredStopEvents.last?.id) ?? ""
        // Recharge à la nouvelle heure et repousse le prochain rafraîchissement de 30 s.
        refreshGeneration += 1
    }
}

#Preview("StopEventView preview") {
    let stopStore = StopStore()
    let favoritesViewModel = FavoritesViewModel()

    return VStack {
        StopEventView(
            event: StopEvent(
                stopPointName: "Meinier, Eglise",
                stopId: "8587061",
                plannedQuay: "A",
                timetabledTime: "2025-08-13T14:55:18Z",
                estimatedTime: "2025-08-13T14:55:18Z",
                lineName: "A",
                origin: "Gy, Temple",
                destination: "Genève, Rive",
                transportType: "Bus",
                operatorName: "Transports Publics Genevois",
                journeyRef: "ch:1:sjyid:100680:HAS-25-A-31-Lun-Ven-32504874",
                operatingDayRef: "2025-08-13"
            ),
            showTime: false
        )
    }
    .environment(favoritesViewModel)
    .environment(stopStore)
}

#Preview("StopView preview") {
    let stopStore = StopStore()
    let favoritesViewModel = FavoritesViewModel()
    let navigationModel = NavigationModel()
    let tripViewModel = ItineraryViewModel()

    return NavigationStack {
        ZStack {
            StopView(stopName: "Genève, Rive", stopSloid: "ch:1:sloid:87061", autoRefresh: false)
                .environment(favoritesViewModel)
                .environment(stopStore)
                .environment(tripViewModel)
                .navigationTitle("Genève, Rive")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("")
                    }
                }
            if #available(iOS 26, *) {
                // No dock in iOS 26 preview
            } else {
                VStack {
                    Spacer()
                    DockView()
                        .padding(.bottom)
                        .environment(navigationModel)
                        .environment(stopStore)
                        .offset(y: 20)
                }
            }
        }
    }
}

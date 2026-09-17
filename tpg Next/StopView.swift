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
    @Environment(AppRequirementsClass.self) var appRequirementsClass
    @State private var lineManager = LineManager()
    @State private var stopEvents: [StopEvent] = []
    @Environment(StopStore.self) var stopStore
    @Environment(\.openRoute) private var openRoute
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
    @State private var timeAnimate = false //animate time selection symbol
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
                                    if stopManager.stopErrorMessage == "STOPEVENT_LOCATIONUNSERVED" {
                                        Text("Malheureusement, cet arrêt n'est pas disponible depuis l'application, ou n'est pas desservi")
                                            .padding()
                                    } else {
                                        Text("Pas de départs trouvés")
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .contentMargins(.top, max(90.0, titleHeight + 10), for: .automatic)
                        .contentMargins(.bottom, appRequirementsClass.version26 ? 75.0 : 125, for: .automatic)
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

                        //Bottom buttons
                        HStack {
                            HStack(spacing: TPGSurface.isGlass ? 0 : nil) {
                                Button(action: {
                                    withAnimation(TPGSurface.isGlass ? nil : .default) {
                                        viewLineSorted.toggle()
                                    }
                                    requestNumber = max(viewLineSorted ? groupedStopEvents.keys.count * 5 : 30, 30)
                                }) {
                                    Image(systemName: viewLineSorted ? "text.justify" : "rectangle.grid.1x2.fill")
                                        .contentTransition(.symbolEffect(.replace.upUp.byLayer))
                                        .padding()
                                        .foregroundStyle(.foreground)
                                }

                                Filterbutton(filterLines: $filterLines, viewLineFiltered: $viewLineFiltered)
                                    .padding(.trailing, 7)
                            }
                            .tpgSurface(interactive: true, legacy: .thinMaterial)
                            Spacer()
                            AdjustTimeButton(moveTime: moveTime)
                                .tpgSurface(interactive: true, legacy: .thinMaterial)
                        }
                        .padding()
                        .foregroundStyle(.primary)
                        // Plafonnés, comme les barres d'outils du système : en taille d'accessibilité,
                        // ces boutons flottants masquaient le bas de la liste.
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
//                Button(action: {
//                    showTime.toggle()
//                }) {
//                        Image(systemName: "hourglass")
//                        .foregroundColor(showTime ? .text : .white)
//                            .padding(.horizontal, 10)
////                            .padding(.vertical, 15)
//                        .background {
//                            Capsule()
//                                .foregroundStyle(showTime ? .clear : .accent)
////                                .padding(.horizontal, 5)
////                                .padding(.vertical, 5)
//                        }
//                }
                ShowTimeButton(showTime: $showTime)
                
                Button {
                    selectTime.toggle()
                } label: {
                    Label("Selectionner l'heure", systemImage: "clock")
                        .symbolEffect(.bounce.down.byLayer, value: selectTime)
                }
                
                Menu {
                    Button(action: {
                        toggleFavorite()
                    }) {
                        favoritesViewModel.isFavoriteID(stopSloid) ? Label("Retirer des favoris", systemImage: "star.fill") : Label("Ajouter aux favoris", systemImage: "star")
                    }
                    Divider()
                    if !stopManager.quays.isEmpty {
                        Button {
                            openRoute(.stopMap(quays: stopManager.quays, sloid: stopSloid, name: stopName))
                        } label: {
                            Label("Carte des quais", systemImage: "map")
                        }
                    }
                    
                        TripActionsMenu(stop: createStop(nomarret: stopName, sloid: sloidHarmonizer(code: stopSloid)), includesQuickTrip: false)
                } label: {
                        Label("", systemImage: "ellipsis")
                            .padding(.horizontal, 5)
                }
            }
            .legacySurface()
        }
        
        
        .sheet(isPresented: $selectTime) {
                let timeSelectSheet = VStack(spacing: 0) {
                    Spacer()
                    Text("Sélectionnez l'heure de départ")
                        .font(.title2)
                        .bold()
//                        .padding()
                        HStack {
                            DatePicker(selection: $timeRequest) {
                                
                            }
                            .datePickerStyle(.wheel)
                            Button(action: {
                                timeRequest = Date()
                                timeAnimate.toggle()
                            }) {
                                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                    .font(.title2)
                                    .symbolEffect(.rotate, value: timeAnimate)
                            }
                        }
                        if #available(iOS 26, *) {
                            Button {
                                refreshGeneration += 1
                                selectTime.toggle()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Selectionner")
                                    Spacer()
                                }
                                .frame(height: 40)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(action: {
                                refreshGeneration += 1
                                selectTime.toggle()
                            }) {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.accent)
                                    .frame(height: 50)
                                    .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                                    .overlay(Text("Selectionner").foregroundStyle(.white))
                            }
                            .padding(.bottom)
                        }
            }
            .padding()
            .presentationDetents([.fraction(0.4)])
//            .presentationCornerRadius(35)
//            .presentationBackground(#available(ios 26, *) ? .clear : .thinMaterial)
            if #available(iOS 26, *) {
                timeSelectSheet
            } else {
                timeSelectSheet
                    .presentationBackground(.thinMaterial)
            }
        }
        
        .sheet(isPresented: $filterLines) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Filtrer par lignes")
                    .font(.title2)
                    .bold()
                    .padding()
                
                    let scroll = VStack {
                        ForEach(groupedStopEvents.keys.sorted(by: lineGroupPrecedes), id: \.self) { key in
//                            let splitLineOperator = splitString(key, separator: "$")
                            let splitLine = splitString(key, separator: ";")
                            Button(action: {
//                                print(key)
                                viewLineFiltered = true
                                if selectedFilters.contains(key) {
                                    selectedFilters.remove(key) // Unselect if already selected
                                } else {
                                    selectedFilters.insert(key) // Add to selected filters
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedFilters.contains(key) ? "checkmark.circle.fill" : "circle")
                                    BusLineIcon(lineName: splitLine.0, operatorName: groupedStopEvents[key]![0].operatorName)
                                    Image(systemName: "arrow.right")
                                    Text(splitLine.1)
                                    Spacer()
                                }
                                .padding()
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                        ScrollView {
                            scroll
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .top) {
                                    ScrollMask(leading: false, vertical: true, gradientLength: 30)
                                }
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .bottom) {
                                    ScrollMask(leading: true, vertical: true, gradientLength: 30)
                                }
                        }
                
                if !selectedFilters.isEmpty {
                    Button(role: .destructive, action: {
                        viewLineFiltered = false
                        selectedFilters = []
                    }) {
                        HStack {
                            Label("Supprimer les filtres", systemImage: "xmark.circle")
                            Spacer()
                        }
                        .frame(height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                
                Button {
                    filterLines = false
                } label: {
                    HStack {
                        Label("Filtrer", systemImage: "line.3.horizontal.decrease")
//                            .font(.title3)
                        Spacer()
                    }
                    .padding()
                    .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
//            .padding(.horizontal)
            .padding(.top)
            .presentationDetents([.fraction(0.7)])
        }
        
        .navigationTitle("\(stopName)") // Set back button text
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("") // Visible title
            }
        }
    }
    
    private func toggleFavorite() {
        if let stop = stopStore.findStop(id: stopSloid) {
            if favoritesViewModel.isFavorite(stop) {
                favoritesViewModel.removeFavoriteStop(stop)
            } else {
                favoritesViewModel.addFavorite(stop)
            }
        }
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
    let appRequirementsClass = AppRequirementsClass()

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
    .environment(appRequirementsClass)
    .environment(stopStore)
}

#Preview("StopView preview") {
    let stopStore = StopStore()
    let favoritesViewModel = FavoritesViewModel()
    let appRequirementsClass = AppRequirementsClass()
    let navigationModel = NavigationModel()
    let tripViewModel = ItineraryViewModel()

    return NavigationStack {
        ZStack {
            StopView(stopName: "Genève, Rive", stopSloid: "ch:1:sloid:87061", autoRefresh: false)
                .environment(favoritesViewModel)
                .environment(appRequirementsClass)
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

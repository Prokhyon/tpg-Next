//
//  NewStopViewTest.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Combine
import tpgNextFunc

struct SortedStopEventsView: View {
    var key: String
    var filteredStopEvents: [String: [StopEvent]]
    var groupedStopEvents: [String: [StopEvent]]
    @Binding var showTime: Bool
    @Binding var previousLineRef: String?
    var stopName: String
    var stopSloid: String
    
    var body: some View {
            let splitLine = splitString(key, separator: ";")
        BasicCard(cornerRadius: 30)
                .padding(.vertical, 5)
                .frame(height: 110)
                .overlay(
                    VStack(spacing: 0) {
                        Spacer()
                        HStack {
                            let quay = groupedStopEvents[key]!.first!.plannedQuay
                            BusLineIcon(lineName: splitLine.0, operatorName: filteredStopEvents[key]![0].operatorName)
                            Image(systemName: "arrow.right")
                            SmallStopTitleView(stopName: splitLine.1)
                            Spacer()
                            QuayIcon(quay: quay)
                        }
                        .frame(height: 30)
//                        .background(Rectangle().fill(.red))
                        .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(filteredStopEvents[key]!, id: \.id) { stopEvent in
                                    let time = departureDisplay(timetabled: stopEvent.timetabledTime, estimated: stopEvent.estimatedTime, showTime: showTime)
                                    NavigationLink {
                                        LineView(stopEvent: stopEvent, currentStop: ShortStop(name: stopName, sloid: sloidHarmonizer(code: stopSloid)), currentLine: stopEvent.lineName)
                                    } label: {
                                    Group {
                                            DepartureTimeView(time, transportType: stopEvent.transportType, layout: .inline(spacing: 2), iconWidth: 15)
                                        }
                                        .foregroundStyle(determineColor(for: stopEvent.estimatedTime))
                                        .padding(.horizontal, 17)
                                        .padding(.vertical, 5)
                                        .background(
                                            BasicElement(highlighted: stopEvent.journeyRef == (previousLineRef ?? ""))
//                                                .padding(2)
                                        )
                                        
                                        
                                    }
                                    .padding(2)
                                    .contentShape(.contextMenuPreview, Capsule())
                                    .if(!dateStringHasPassed(with: stopEvent.estimatedTime, equalReturnsTrue: false)) { view in
                                        view.contextMenu {
                                            NotificationContextMenu(event: stopEvent, stopID: stopSloid)
                                        } preview: {
                                            StopEventView(event: stopEvent, showTime: showTime, previousLineRef: previousLineRef)
                                                .foregroundStyle(.primary)
                                                .frame(width: UIScreen.main.bounds.width)
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                            }
                            .frame(height: 40)
//                            .background(Rectangle().fill(.red))
                            .padding(.horizontal)
                            .padding(.vertical, 7)
                            
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .leading) {
                                    ScrollMask(leading: true, vertical: false, gradientLength: 10)
                                }
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .trailing) {
                                    ScrollMask(leading: false, vertical: false, gradientLength: 10)
                                }
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .top) {
                                    ScrollMask(leading: false, vertical: true, gradientLength: 10)
                                }
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .bottom) {
                                    ScrollMask(leading: true, vertical: true, gradientLength: 10)
                                }
                        }
                        .padding(.horizontal, 5)
//                        Spacer()
                    }
                        .padding(.vertical, 10)
//                        .background(Rectangle().fill(.red))
                )
                .padding(.horizontal, 20)
        }
}

struct StopView: View {
    @StateObject private var stopManager = StopManager()
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var tripViewModel: ItineraryViewModel
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var appRequirementsClass: AppRequirementsClass
    @StateObject private var lineManager = LineManager()
    @State private var stopEvents: [StopEvent] = []
    @EnvironmentObject var stopStore: StopStore
    @State private var timer: AnyCancellable?
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
        filteredStopEvents.values.flatMap { $0 }.sorted(by: { $0.estimatedTime < $1.estimatedTime })
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
                                            NavigationLink {
                                                LineView(stopEvent: event, currentStop: ShortStop(name: stopName, sloid: sloidHarmonizer(code: stopSloid)), currentLine: event.lineName)
                                            }label: {
                                                StopEventView(event: event, showTime: showTime, previousLineRef: previousLineRef)
                                                    .foregroundStyle(determineColor(for: event.estimatedTime))
                                            }
                                            .contentShape(.contextMenuPreview, Capsule())
                                            .padding(.horizontal, 15)
                                            .if(!dateStringHasPassed(with: event.estimatedTime, equalReturnsTrue: false)) { view in
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
                        .contentMargins(.top, 90.0, for: .automatic)
                        .contentMargins(.bottom, appRequirementsClass.version26 ? 75.0 : 125, for: .automatic)
                        
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
                    if #available(iOS 26, *) {
                        VStack(alignment: .center) {
                            HStack {
                                Spacer()
                                HStack {
                                    StopTitleView(stopName: stopName)
                                        .foregroundStyle(Color.text)
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(width: 100, height: 0)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 5)
                                .glassEffect(.regular.interactive())
                                .offset(x: 50)
                            }
                            Spacer()
                            HStack {
                                HStack(spacing: 0) {
                                    Button(action: {
                                        viewLineSorted.toggle()
                                        requestNumber = viewLineSorted ? groupedStopEvents.keys.count * 5 : 30
                                    }) {
                                        Image(systemName: viewLineSorted ? "text.justify" : "rectangle.grid.1x2.fill")
                                            .contentTransition(.symbolEffect(.replace.upUp.byLayer))
                                            .padding()
                                            .foregroundStyle(.foreground)
                                    }
                                    
                                    Filterbutton(filterLines: $filterLines, viewLineFiltered: $viewLineFiltered)
                                        .padding(.trailing, 7)
//                                        .padding(.vertical)
//                                    Button {
//                                        filterLines.toggle()
//                                    } label: {
//                                        Image(systemName: "line.3.horizontal.decrease")
//                                            .foregroundStyle(viewLineFiltered ? .white : Color.text)
//                                            .padding()
////                                            .glassEffect(.regular)
//                                            .background {
//                                                Capsule()
//                                                    .fill(viewLineFiltered ? Color.accentColor : Color.clear)
//                                                    .padding(5)
//                                            }
//                                    }
                                    
                                }
                                .glassEffect(.regular.interactive())
                                Spacer()
//                                HStack(spacing: 0) {
//                                    Button(action: {
//                                        moveTime(previous: true)
//                                    }) {
//                                        Image(systemName: "text.line.first.and.arrowtriangle.forward")
//                                    }
//                                    .padding()
//                                    Button(action: {
//                                        moveTime(previous: false)
//                                    }) {
//                                        Image(systemName: "text.line.last.and.arrowtriangle.forward")
//                                    }
//                                    .padding()
//                                }
                                AdjustTimeButton(moveTime: moveTime)
                                .glassEffect(.regular.interactive())
                            }
                            .padding()
                            .foregroundStyle(.primary)
                        }

                    } else {
                        VStack(alignment: .center) {
                            
                            //Stop title element
                            HStack {
                                Spacer()
                                HStack {
                                    StopTitleView(stopName: stopName)
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(width: 100, height: 0)
                                }
                                .padding(.horizontal)
                                .background {
                                    Capsule()
                                        .foregroundStyle(.ultraThinMaterial)
                                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                }
                                .offset(x: 50)
                            }
                            Spacer()
                            
                            //Bottom buttons
                            HStack {
                                HStack {
                                    Button(action: {
                                        withAnimation {
                                            viewLineSorted.toggle()
                                        }
                                    }) {
                                        Image(systemName: viewLineSorted ? "text.justify" : "rectangle.grid.1x2.fill")
                                            .contentTransition(.symbolEffect(.replace.upUp.byLayer))
                                            .padding()
                                            .foregroundStyle(.foreground)
                                    }
                                    
                                    Filterbutton(filterLines: $filterLines, viewLineFiltered: $viewLineFiltered)
                                        .padding(.trailing, 7)
                                }
                                .background {
                                    Capsule()
                                        .foregroundStyle(.thinMaterial)
                                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                }
                                Spacer()
//                                HStack {
//                                    Button(action: {
//                                        moveTime(previous: true)
//                                    }) {
//                                        Image(systemName: "text.line.first.and.arrowtriangle.forward")
//                                            .padding()
//                                    }
//                                    Button(action: {
//                                        moveTime(previous: false)
//                                    }) {
//                                        Image(systemName: "text.line.last.and.arrowtriangle.forward")
//                                            .padding()
//                                    }
//                                }
                                AdjustTimeButton(moveTime: moveTime)
                                .background {
                                    Capsule()
                                        .foregroundStyle(.thinMaterial)
                                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                }
                            }
                            .padding()
                            .foregroundStyle(.primary)
                        }
                        .padding(.bottom, 50)
                    }
                }
                .onAppear {
                    viewLineSorted = groupedDefault
//                    showTime = timeDefault
                    timeRequest = timeRequest(for: previousLineTime)
                    getStopEvents()
                    if autoRefresh {
                        startTimer()
                    }
                    requestNumber = viewLineSorted ? groupedStopEvents.keys.count * 5 : 30
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    if autoRefresh {
                        timeRequest = timeRequest(for: previousLineTime)
                        getStopEvents()
                        startTimer()
                    }
                }
                .onDisappear {
                    timer?.cancel()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    timer?.cancel()
                }
                .onChange(of: autoRefresh) {
                    if !autoRefresh {
                        timer?.cancel()
                    } else {
                        timeRequest = timeRequest(for: previousLineTime)
                        getStopEvents()
                        startTimer()
                    }
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
                        NavigationLink {
                                                    StopMapView(quays: stopManager.quays, stopSloid: stopSloid, stopName: stopName)
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
            .background {
                Capsule()
                    .opacity(appRequirementsClass.version26 ? 0 : 1)
                    .foregroundStyle(.ultraThinMaterial)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
            }
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
                                getStopEvents()
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
                                getStopEvents()
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
    private func startTimer() {
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                getStopEvents()
            }
    }
    
    private func estimatedTypicalTimeInterval(from events: [StopEvent]) -> Int { //calcul d'interval pour décalement d'heure
        let dates = events.compactMap { OJPDate.date(from: $0.estimatedTime) }.sorted()

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
        getStopEvents()
        startTimer()
    }
}

struct StopTitleView : View {
    var stopName: String
    
    var body: some View {
        VStack {
                let splitStopName = splitString(stopName, separator: ",")
                if splitStopName.1.isEmpty {
                    HStack {
                        Text(splitStopName.0)
                            .font(.largeTitle)
                            .bold()
                            .minimumScaleFactor(0.5)
//                        Spacer()
                    }
                    .frame(height: 70)
                    .padding(.horizontal, 25)
//                    .padding(.bottom, 10)
                    
                } else {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(splitStopName.0)
                                .font(.title2)
//                            Spacer()
                        }
                        HStack {
                            Text(splitStopName.1)
                                .font(.largeTitle)
                                .bold()
//                            Spacer()
                        }
                    }
//                    .padding(.bottom, 15)
                    .frame(height: 70)
                    .padding(.horizontal, 25)
                    .minimumScaleFactor(0.5)
                }
        }
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
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
    .environmentObject(favoritesViewModel)
    .environmentObject(appRequirementsClass)
    .environmentObject(stopStore)
}

#Preview("StopView preview") {
    let stopStore = StopStore()
    let favoritesViewModel = FavoritesViewModel()
    let appRequirementsClass = AppRequirementsClass()
    let navigationModel = NavigationModel()

    return NavigationStack {
        ZStack {
            StopView(stopName: "Genève, Rive", stopSloid: "ch:1:sloid:87061", autoRefresh: false)
                .environmentObject(favoritesViewModel)
                .environmentObject(appRequirementsClass)
                .environmentObject(stopStore)
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
                        .environmentObject(navigationModel)
                        .environmentObject(stopStore)
                        .offset(y: 20)
                }
            }
        }
    }
}

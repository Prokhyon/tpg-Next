//
//  NewStopViewTest.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Combine

struct StopEventView: View  {
    var event: StopEvent
    var showTime: Bool
    
    var body: some View {
            RoundedRectangle(cornerRadius: 20)
                        .fill(.thinMaterial)
                .frame(height: 50)
                .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                .overlay(
                    HStack {
                        let transportTime = displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime,  with: showTime)
                        BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                        Image(systemName: "arrow.right").font(.caption)
                        SmallStopTitleView(stopName: event.destination)
                        Spacer()
                        if transportTime == "0" {
                            transportIcon(with: event.transportType).frame(width: 10)
                        } else {
                            if transportTime.count > 4 {
                                Text(transportTime)
                                    .padding(.vertical, 4)
                                    .minimumScaleFactor(0.5)
                            } else {
                                Text(transportTime)
                                    .padding(.vertical, 4)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                        if event.plannedQuay == "" {
                            Image(systemName: "questionmark.square.fill")
                        } else {
                            Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
                        }
                    }
                        .padding(.horizontal)
                )
                .padding(5)
    }
}

struct SortedStopEventsView: View {
    var body: some View {
        VStack {
            
        }
    }
}

struct StopView: View {
    @ObservedObject var path: ViewStateStack
    @StateObject private var stopManager = StopManager()
    @State var favoritesViewModel: FavoritesViewModel
    @StateObject private var lineManager = LineManager()
    @State private var stopEvents: [StopEvent] = []
    @EnvironmentObject var stopStore: StopStore
    @State private var timer: AnyCancellable?
    let stopName: String
    let stopCodedidoc: String
    var previousLineRef: String?
    var previousLineName: String?
    var previousLineTime: String?
    @State private var showTime = false
    @State private var timeIntervalNotification = 0
    @State private var viewLineSorted = false
    @State private var viewLineFiltered = false
    @State private var selectedNumber = 5
    @State private var timeRequest = Date()
    @State private var requestNumber = 30
    @Binding var autoRefresh: Bool
    
    var groupedStopEvents: [String: [StopEvent]] {
            Dictionary(grouping: stopManager.stopEvents) { stopEvent in
                "\(stopEvent.lineName);\(stopEvent.destination)"
            }
        }

    var filteredStopEvents: [String: [StopEvent]] {
            if selectedFilters.isEmpty {
                return groupedStopEvents
            } else {
                return groupedStopEvents.filter { selectedFilters.contains($0.key) }
            }
    }
    var allFilteredStopEvents: [StopEvent] {
        filteredStopEvents.values.flatMap { $0 }
    }
    
    @State private var selectedFilters: Set<String> = []
        
    @AppStorage("GoupedDefault") var groupedDefault = false
    @AppStorage("TimeDefault") var timeDefault = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing:0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if !stopManager.stopEvents.isEmpty {
                                Button(action: {
                                    let halfTime = Int(halfTimeDifferenceInMinutes(from: stopEvents.first?.estimatedTime ?? "0", to: stopEvents.last?.estimatedTime ?? "0") ?? 15)
                                    adjustTime(byAdding: -halfTime)
                                    getStopEvents()
                                }) {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.thinMaterial)
                                        .frame(height: 50)
                                        .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                                        .overlay(
                                            Text("Départs précédents")
                                        )
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 20)
                                }
                            }
                            
                            if viewLineSorted {
                                ForEach(filteredStopEvents.keys.sorted(), id: \.self) { key in
                                    let splitLine = splitString(key, separator: ";")
                                    RoundedRectangle(cornerRadius: 20)
                                        .foregroundStyle(.thinMaterial)
                                        .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                                        .padding(.vertical, 5)
                                        .frame(height: 110)
                                        .overlay(
                                            VStack {
                                                HStack {
                                                    let quay = groupedStopEvents[key]!.first!.plannedQuay
                                                    BusLineIcon(lineName: splitLine.0, operatorName: filteredStopEvents[key]![0].operatorName)
                                                    Image(systemName: "arrow.right")
                                                    SmallStopTitleView(stopName: splitLine.1)
                                                    Spacer()
                                                    if quay == "" {
                                                        Image(systemName: "questionmark.square.fill")
                                                    } else {
                                                        Image(systemName: "\(quay).square.fill".lowercased())
                                                    }
                                                }
                                                .padding(.horizontal, 20)
                                                ZStack {
                                                    ScrollView(.horizontal, showsIndicators: false) {
                                                        HStack {
                                                            ForEach(filteredStopEvents[key]!, id: \.id) { stopEvent in
                                                                let time = displayTimeOrMinutesRemaining(for: stopEvent.timetabledTime, estimatedInput: stopEvent.estimatedTime,  with: showTime)
                                                                Button(action: {
                                                                    path.push(.line(stopEvent: stopEvent, currentStop: ShortStop(name: stopName, codedidoc: codedidocHarmonizer(code: stopCodedidoc)), currentLine: stopEvent.lineName))
                                                                }) {
                                                                    Group {
                                                                        if time == "0" {
                                                                            transportIcon(with: stopEvent.transportType)
                                                                                .frame(width: 10)
                                                                        } else {
                                                                            Text(time)
                                                                        }
                                                                    }
                                                                    .foregroundStyle(determineColor(for: stopEvent))
                                                                    .padding(.horizontal, 10)
                                                                    .padding(.vertical, 5)
                                                                    .background(Color.gray.opacity(0.2))
                                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                                                }
                                                                .foregroundStyle(.primary)
                                                            }
                                                        }
                                                        .padding(.horizontal)
                                                    }
                                                    .mask {
                                                        Rectangle()
                                                            .overlay(alignment: .leading) {
                                                                ScrollMask(leading: true, width: 30)
                                                            }
                                                    }
                                                    .mask {
                                                        Rectangle()
                                                            .overlay(alignment: .trailing) {
                                                                ScrollMask(leading: false, width: 30)
                                                            }
                                                    }
                                                }
                                                .padding(.horizontal, 10)
                                            }
                                                .padding(.vertical, 15)
                                                 )
                                        .padding(.horizontal, 20)
                                        }
                            } else {
                                    ForEach(allFilteredStopEvents.sorted(by: { $0.estimatedTime < $1.estimatedTime }), id: \.id) { event in
                                        
                                        Button(action: {
                                            path.push(.line(stopEvent: event, currentStop: ShortStop(name: stopName, codedidoc: codedidocHarmonizer(code: stopCodedidoc)), currentLine: event.lineName))
                                        }) {
                                            StopEventView(event: event, showTime: showTime)
                                                .foregroundStyle(determineColor(for: event))
                                        }
                                        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20))
                                        .padding(.horizontal, 15)
                                        .if(!compareDateString(with: event.estimatedTime, equalPossible: false)) { view in
                                            view.contextMenu {
                                                NotificationContextMenu(event: event, stopID: stopCodedidoc, path: path)
                                            }
                                        }
                                    }
                            }
                            if !stopManager.stopEvents.isEmpty {
                                Button(action: {
                                    let halfTime = Int(halfTimeDifferenceInMinutes(from: stopEvents.first?.estimatedTime ?? "0", to: stopEvents.last?.estimatedTime ?? "0") ?? 15)
                                    adjustTime(byAdding: halfTime)
                                    getStopEvents()
                                }) {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.thinMaterial)
                                        .frame(height: 50)
                                        .shadow(color: Color.customShadows, radius: 1, y: 1)
                                        .overlay(
                                            Text("Départs suivants")
                                        )
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .contentMargins(.top, 90.0, for: .automatic)
                    .contentMargins(.bottom, 75.0, for: .automatic)

                    .refreshable {
                        timeRequest = Date()
                        getStopEvents()
                    }
                }
                VStack {
                    VStack {
                            let splitStopName = splitString(stopName, separator: ",")
                            if splitStopName.1.isEmpty {
                                HStack {
                                    Text(splitStopName.0)
                                        .font(.largeTitle)
                                        .bold()
                                        .minimumScaleFactor(0.5)
                                    Spacer()
                                }
                                .frame(height: 60)
                                .padding(.horizontal, 25)
                                .padding(.bottom, 10)
                            } else {
                                VStack {
                                    HStack {
                                        Text(splitStopName.0)
                                            .font(.title2)
                                        Spacer()
                                    }
                                    HStack {
                                        Text(splitStopName.1)
                                            .font(.largeTitle)
                                            .bold()
                                        Spacer()
                                    }
                                }
                                .padding(.bottom, 15)
                                .frame(height: 80)
                                .padding(.horizontal, 25)
                                .minimumScaleFactor(0.5)
                            }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 45.0)
                            .frame(width: geometry.size.width, height: 200 + geometry.safeAreaInsets.top)
                            .foregroundStyle(.thinMaterial)
                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                            .ignoresSafeArea(edges: .top)
                            .offset(y: -105)
                    }
                    Spacer()
                }
                .onAppear {
                    viewLineSorted = groupedDefault
                    showTime = timeDefault
                    timeRequest = timeRequest(for: previousLineTime)
                    getStopEvents()
                    timer = Timer.publish(every: 30, on: .main, in: .common)
                        .autoconnect()
                        .sink { _ in
                            getStopEvents()
                        }
                    requestNumber = viewLineSorted ? groupedStopEvents.keys.count * 5 : 30
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    if autoRefresh {
                        timeRequest = timeRequest(for: previousLineTime)
                        getStopEvents()
                        timer = Timer.publish(every: 30, on: .main, in: .common)
                            .autoconnect()
                            .sink { _ in
                                getStopEvents()
                            }
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
                        timer = Timer.publish(every: 30, on: .main, in: .common)
                            .autoconnect()
                            .sink { _ in
                                getStopEvents()
                            }
                    }
                }
            }
        }
        .toolbar {
            HStack {
                    Spacer()
                    Button(action: {
                        showTime.toggle()
                    }) {
                        Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill").font(.title3)
                    }
                Menu {
                    Button(action: {
                        toggleFavorite()
                    }) {
                        favoritesViewModel.isFavoriteID(stopCodedidoc) ? Label("Retirer des favoris", systemImage: "star.fill") : Label("Ajouter aux favoris", systemImage: "star")
                    }
                    if !stopManager.quays.isEmpty {
                        Button(action: {
                            path.push(.stopMap(quays: stopManager.quays, stopPointRef: stopCodedidoc, stopName: stopName))
                        }) {
                            Label("Carte des quais", systemImage: "map")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        path.push(.trip(selectedTextField: 2, departureStop: createStop(nomarret: stopName, codedidoc: stopCodedidoc), arrivalStop: nil, quickTrip: false))
                    }) {
                        Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                    }
                    Button(action: {
                        path.push(.trip(selectedTextField: 1, departureStop: nil, arrivalStop: createStop(nomarret: stopName, codedidoc: stopCodedidoc), quickTrip: false))
                    }) {
                        Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                    }
                    
                    Divider()
                    if !viewLineSorted {
                        Button(action: {
                            viewLineSorted = true
                            requestNumber = groupedStopEvents.keys.count * 5
                            getStopEvents()
                        }) {
                            Label("Trier par ligne", systemImage: "rectangle.grid.1x2.fill")
                        }
                    } else {
                        Button(action: {
                            viewLineSorted = false
                            requestNumber = 30
                            getStopEvents()
                        }) {
                            Label("Trier par horaire", systemImage: "list.bullet")
                        }
                    }
                    Menu {
                        if !selectedFilters.isEmpty {
                            Button(role: .destructive, action: {
                                viewLineFiltered = false
                                selectedFilters = []
                            }) {
                                Label("Supprimer les filtres", systemImage: "xmark.circle")
                            }
                            .menuActionDismissBehavior(.disabled)
                        }
                        ForEach(groupedStopEvents.keys.sorted(), id: \.self) { key in
                            let splitLine = splitString(key, separator: ";")
                            Button(action: {
                                viewLineFiltered = true
                                if selectedFilters.contains(key) {
                                                selectedFilters.remove(key) // Unselect if already selected
                                            } else {
                                                selectedFilters.insert(key) // Add to selected filters
                                            }
                            }) {
                                Label(splitLine.0 + " ➔ " + splitLine.1, systemImage: selectedFilters.contains(key) ? "checkmark.circle.fill" : "circle")
                            }
                            .menuActionDismissBehavior(.disabled)
                        }
                    } label: {
                        Label("Filtrer par ligne", systemImage: selectedFilters.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                }
                }
            }
        }

    private func toggleFavorite() {
        if let stop = stopStore.findStop(id: stopCodedidoc) {
            if favoritesViewModel.isFavorite(stop) {
                favoritesViewModel.removeFavoriteStop(stop)
            } else {
                favoritesViewModel.addFavorite(stop)
            }
            print(favoritesViewModel.favoriteStops)
        }
    }
    
    private func getStopEvents () {
        
        stopManager.selectStop(stopName: stopName, stopCodedidoc: stopCodedidoc, stopEventNumber: requestNumber, timeRequest: timeRequest) {
                    stopEvents = self.stopManager.stopEvents
        }
    }
    private func adjustTime(byAdding minutes: Int) {
        if let newTimeRequest = Calendar.current.date(byAdding: .minute, value: minutes, to: timeRequest) {
            timeRequest = newTimeRequest
        } else {
            print("Failed to modify the date.")
        }
    }
    func halfTimeDifferenceInMinutes(from startTime: String, to endTime: String) -> Double? {
        let dateFormatter = ISO8601DateFormatter()
        // Convert the input strings to Date objects
        guard let startDate = dateFormatter.date(from: startTime),
              let endDate = dateFormatter.date(from: endTime) else {
            return nil
        }
        // Calculate the time difference in seconds
        let timeDifference = endDate.timeIntervalSince(startDate)
        // Convert the time difference to minutes and return half of it
        let halfDifferenceInMinutes = timeDifference / 60 / 2
        return halfDifferenceInMinutes
    }
    func determineColor(for event: StopEvent) -> Color {
        if event.journeyRef == previousLineRef {
            return Color.accentColor
        } else if compareDateString(with: event.estimatedTime, equalPossible: false) {
            return Color.gray
        } else {
            return Color.primary
        }
    }
    func timeRequest(for time: String?) -> Date {
        if time != nil {
            return stringToDate(with: time!)!
        } else {
            return Date()
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

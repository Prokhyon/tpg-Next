//
//  StopViewWatch.swift
//  watch tpg Next Watch App
//
//  Created by Loris Thomas on 30.12.2024.
//

import SwiftUI
import Combine
import tpgNextFunc

struct SmallStopTitleView: View {
    var stopName: String

    var body: some View {
        HStack {
            let splitStopName = splitString(stopName, separator: ",")
            if splitStopName.1.isEmpty {
                HStack {
                    Text(splitStopName.0)
                        .font(.headline)
                        .bold()
                        .minimumScaleFactor(0.2)
                        .lineLimit(2)
                }
            } else {
                    VStack(alignment: .leading) {
                        Text(splitStopName.0)
                            .font(.caption2)
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                        Text(splitStopName.1)
                            .font(.caption)
                            .bold()
                            .minimumScaleFactor(0.3)
                            .lineLimit(1)
                    }
            }
            Spacer()
        }
    }
}

struct StopEventView: View  {
    var event: StopEvent
    var showTime: Bool
    var previousLineRef: String?
    
    var body: some View {
//                .stroke(event.journeyRef == (previousLineRef ?? "") ? .accent : .clear, lineWidth: 3)
        VStack {
            let transportTime = displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime,  with: showTime)
            HStack {
                BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                Image(systemName: "arrow.right").font(.caption)
                SmallStopTitleView(stopName: event.destination)
            }
            HStack {
                if transportTime.text == "0" {
                    transportIcon(with: event.transportType)
                        .frame(width: 15)
                        .padding(4)
                } else {
                    if transportTime.text.count > 6 {
                        let splitTime = splitString(transportTime.text, separator: ";" )
                        HStack(spacing: 5) {
                            Text(splitTime.0)
                            Text(splitTime.1)
                                .foregroundStyle(transportTime.color)
                                .minimumScaleFactor(0.5)
                        }
                        .padding(4)
                        
                    } else {
                        Text(transportTime.text)
                            .padding(4)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(transportTime.color)
                    }
                }
                Spacer()
                if event.plannedQuay == "" {
                    Image(systemName: "questionmark.square.fill")
                } else {
                    Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
                }
            }
            
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.2))
        }
    }
}

struct StopView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewIsVisible = false
    @StateObject private var stopManager = StopManager()
    @State private var stopEvents: [StopEvent] = []
    @EnvironmentObject var stopStore: StopStore
    @State private var timer: AnyCancellable?
    let stopName: String
    let stopSloid: String
    var previousLineRef: String?
    var previousLineName: String?
    var previousLineTime: String?
    var isCloseStop: Bool
    @Binding var showTime: Bool
    @State private var timeIntervalNotification = 0
    @Binding var viewLineSorted: Bool
    @State private var viewLineFiltered = false
    @State private var selectedNumber = 5
    @State private var timeRequest = Date()
    @State private var requestNumber = 30
    @Binding var autoRefresh: Bool
    @State private var showMenu = false
    
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
    
    var body: some View {
        Group {
            if !stopManager.stopError {
                if viewLineSorted {
                    ZStack {
                        TabView {
                            ForEach(filteredStopEvents.keys.sorted(by: sortStopEventsKeys), id: \.self) { key in
                                let splitLine = splitString(key, separator: ";")
                                StopSortedView(lineName: splitLine.0, destination: splitLine.1, currentStopName: stopName, stopEventsList: filteredStopEvents[key]!, showTime: $showTime)
                                    .containerBackground(LineColors.lineColor(for: splitLine.0, operatorName: filteredStopEvents[key]![0].operatorName).gradient,
                                                         for: .tabView)
                            }
                        }
                        .tabViewStyle(.verticalPage)
                        VStack {
                            HStack {
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: 5)
                                    .background(
                                        Circle()
                                            .fill(.black)
                                    )
                                    .frame(width: 20, height: 20)
                                SmallStopTitleView(stopName: stopName)
                                if isCloseStop {
                                    Image(systemName: "location.fill")
                                }
                            }
                            .padding(.horizontal, 10)
                            Spacer()
                        }
                    }
                } else {
                    ScrollView {
                        HStack {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 5)
                                .background(
                                    Circle()
                                        .fill(.black)
                                )
                                .frame(width: 20, height: 20)
                            SmallStopTitleView(stopName: stopName)
                            if isCloseStop {
                                Image(systemName: "location.fill")
                            }
                        }
                        .padding(.leading, 10)
                        ForEach(allFilteredStopEvents.sorted(by: { $0.estimatedTime < $1.estimatedTime }), id: \.id) { event in
                            
                            Button(action: {
                                //define navigation
                            }) {
                                StopEventView(event: event, showTime: showTime, previousLineRef: previousLineRef)
                                    .foregroundStyle(determineColor(for: event))
                                
                            }
                            .buttonStyle(.plain)
                            
                        }
                    }
                    .containerBackground(Color(white: 0.2).gradient, for: .tabView)
                }
            } else {
                VStack {
                    HStack {
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: 5)
                            .background(
                                Circle()
                                    .fill(.black)
                            )
                            .frame(width: 20, height: 20)
                        SmallStopTitleView(stopName: stopName)
                        if isCloseStop {
                            Image(systemName: "location.fill")
                        }
                    }
                    .padding(.horizontal, 10)
                    Spacer()
                    Text("Pas de départs trouvés")
                    Spacer()
                }
            }
        }
        .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMenu.toggle()
                    } label: {
                        Image(systemName: "ellipsis")
                    }
            }
        }
        .sheet(isPresented: $showMenu) {
            StopMenuView(showMenu: $showMenu, showTime: $showTime, viewLineSorted: $viewLineSorted)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active && viewIsVisible {
                getStopEvents()
                if autoRefresh {
                    timer = Timer.publish(every: 30, on: .main, in: .common)
                        .autoconnect()
                        .sink { _ in
                            getStopEvents()
                        }
                }
            } else {
                timer?.cancel()
                            }
            
        }
        .onAppear {
            viewIsVisible = true
            timeRequest = timeRequest(for: previousLineTime)
            getStopEvents()
            if autoRefresh {
                timer = Timer.publish(every: 30, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        getStopEvents()
                    }
            }
            requestNumber = max(viewLineSorted ? groupedStopEvents.keys.count * 5 : 30, 30)
//            if requestNumber > 30 {
//                getStopEvents()
//            }
        }
        .onDisappear {
            viewIsVisible = false
            timer?.cancel()
        }
    }
    
//    private func toggleFavorite() {
//        if let stop = stopStore.findStop(id: stopSloid) {
//            if favoritesViewModel.isFavorite(stop) {
//                favoritesViewModel.removeFavoriteStop(stop)
//            } else {
//                favoritesViewModel.addFavorite(stop)
//            }
//            print(favoritesViewModel.favoriteStops)
//        }
//    }
    
    private func getStopEvents () {
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
    func determineColor(for event: StopEvent) -> Color {
        /*if event.journeyRef == previousLineRef {
            return Color.accentColor
        } else*/ if dateStringHasPassed(with: event.estimatedTime, equalReturnsTrue: false) {
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
    private func sortStopEventsKeys(lhs: String, rhs: String) -> Bool {
        let lhsComponents = lhs.split(separator: ";")
        let rhsComponents = rhs.split(separator: ";")
        
        let lhsLineName = lhsComponents.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lhsDestination = lhsComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let rhsLineName = rhsComponents.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rhsDestination = rhsComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Sort primarily by LineName
        if lhsLineName != rhsLineName {
            if let lhsLineNameInt = Int(lhsLineName), let rhsLineNameInt = Int(rhsLineName) {
                return lhsLineNameInt < rhsLineNameInt
            } else {
                return lhsLineName < rhsLineName
            }
        }
        
        // If LineName is the same, sort by Destination
        return lhsDestination < rhsDestination
    }
}


struct StopSortedView: View {
    var lineName: String
    var destination: String
    var currentStopName: String
    var previousLineRef: String?
    var stopEventsList: [StopEvent]
    @Binding var showTime: Bool
    
    var body: some View {
        ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(stopEventsList, id: \.id) { stopEvent in
                            let time = displayTimeOrMinutesRemaining(for: stopEvent.timetabledTime, estimatedInput: stopEvent.estimatedTime,  with: showTime)
                            Button(action: {
                                //define navigation
                            }) {
                                Group {
                                    if time.text == "0" {
                                        transportIcon(with: stopEvent.transportType)
                                            .frame(width: 15)
                                    } else {
                                        if time.text.count > 6 {
                                            HStack(spacing: 2) {
                                                let splitTime = time.text.split(separator: ";")
                                                Text(splitTime[0])
                                                Text(splitTime[1])
                                                    .foregroundStyle(time.color)
                                                    .minimumScaleFactor(0.5)
                                            }
                                        } else {
                                            Text(time.text)
                                                .foregroundStyle(time.color)
                                        }
                                        
                                    }
                                }
                                .padding(.horizontal)
                                
                            }
                            .padding(2)
                            .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal)
                }
            VStack {
                Spacer()
                HStack {
                    let quay = stopEventsList.first?.plannedQuay ?? "?"
                    BusLineIcon(lineName: lineName, operatorName: stopEventsList[0].operatorName)
                    Image(systemName: "arrow.right")
                    SmallStopTitleView(stopName: destination)
                    Spacer()
                    if quay == "" {
                        Image(systemName: "questionmark.square.fill")
                    } else {
                        Image(systemName: "\(quay).square.fill".lowercased())
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

struct StopMenuView: View {
    @Binding var showMenu: Bool
    @Binding var showTime: Bool
    @Binding var viewLineSorted: Bool
    
    var body: some View {
        List {
            Button {
                showTime.toggle()
                showMenu = false
            } label: {
                showTime ? Label("Temps restant", systemImage: "hourglass.circle") : Label("Afficher l'heure", systemImage: "hourglass.circle.fill")
            }
            Button {
                viewLineSorted.toggle()
                showMenu = false
            } label: {
                viewLineSorted ? Label("Trier par horaire", systemImage: "text.justify") : Label("Trier par ligne", systemImage: "rectangle.grid.1x2.fill")
            }
        }
    }
}

struct StopView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var stopStore = StopStore()
        @StateObject var watchFavorites = WatchFavoritesViewModel()
        @State var autoRefresh: Bool = false
        @State var viewLineSorted: Bool = false
        @State var showTime: Bool = false
        
        return StopView(stopName: "Genève, Rive", stopSloid: "ch:1:sloid:93006", isCloseStop: false, showTime: $showTime, viewLineSorted: $viewLineSorted, autoRefresh: $autoRefresh)
            .environmentObject(stopStore)
            .environmentObject(watchFavorites)
    }
}

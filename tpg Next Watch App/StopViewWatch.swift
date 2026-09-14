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
            StopNameView(stopName, style: .compact)
            Spacer()
        }
    }
}

struct StopEventView: View  {
    @Environment(\.displayTime) private var now
    var event: StopEvent
    var showTime: Bool
    var previousLineRef: String?
    
    var body: some View {
//                .stroke(event.journeyRef == (previousLineRef ?? "") ? .accent : .clear, lineWidth: 3)
        VStack {
            let transportTime = departureDisplay(timetabled: event.timetabledTime, estimated: event.estimatedTime, showTime: showTime, at: now)
            HStack {
                BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                Image(systemName: "arrow.right").font(.caption)
                SmallStopTitleView(stopName: event.destination)
            }
            HStack {
                DepartureTimeView(transportTime, transportType: event.transportType, layout: .inline(spacing: 5), iconWidth: 15)
                    .padding(4)
                Spacer()
                QuayIcon(quay: event.plannedQuay)
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
    @Environment(\.displayTime) private var now
    @State private var stopManager = StopManager()
    @State private var stopEvents: [StopEvent] = []
    @Environment(StopStore.self) var stopStore
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
        filteredStopEvents.values.flatMap { $0 }
    }
    
    @State private var selectedFilters: Set<String> = []
    
    var body: some View {
        Group {
            if !stopManager.stopError {
                if viewLineSorted {
                    ZStack {
                        TabView {
                            ForEach(filteredStopEvents.keys.sorted(by: lineGroupPrecedes), id: \.self) { key in
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
                        ForEach(allFilteredStopEvents.sortedByDeparture(), id: \.id) { event in
                            
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
        .periodicRefresh(repeats: autoRefresh) { trigger in
            // Au retour dans l'app, la liste repart de l'heure d'origine : l'heure
            // demandée au premier affichage serait dépassée.
            if trigger == .start {
                timeRequest = timeRequest(for: previousLineTime)
            }
            getStopEvents()
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
        } else*/ if hasPassed(event.departureDate, includingCurrentMinute: false, now: now) {
            return Color.gray
        } else {
            return Color.primary
        }
    }
    func timeRequest(for time: String?) -> Date {
        // Une heure absente ou illisible veut dire « les départs à partir de maintenant ».
        guard let time, let date = stringToDate(with: time) else { return Date() }
        return date
    }
}


struct StopSortedView: View {
    @Environment(\.displayTime) private var now
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
                            let time = departureDisplay(timetabled: stopEvent.timetabledTime, estimated: stopEvent.estimatedTime, showTime: showTime, at: now)
                            Button(action: {
                                //define navigation
                            }) {
                                Group {
                                    DepartureTimeView(time, transportType: stopEvent.transportType, layout: .inline(spacing: 2), iconWidth: 15)
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
                    QuayIcon(quay: quay)
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
        @State var stopStore = StopStore()
        @State var watchFavorites = WatchFavoritesViewModel()
        @State var autoRefresh: Bool = false
        @State var viewLineSorted: Bool = false
        @State var showTime: Bool = false
        
        return StopView(stopName: "Genève, Rive", stopSloid: "ch:1:sloid:93006", isCloseStop: false, showTime: $showTime, viewLineSorted: $viewLineSorted, autoRefresh: $autoRefresh)
            .environment(stopStore)
            .environment(watchFavorites)
    }
}

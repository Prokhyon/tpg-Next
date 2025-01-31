//
//  NewLineView.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Combine

struct CustomNavigationTitle: View {
    var stopEvent: StopEvent
    var currentLine: String
    var operatorName: String
    
    var body: some View {
            VStack {
                HStack {
                    Text("Ligne ")
                        .font(.largeTitle)
                        .bold()
                    BusLineIcon(lineName: currentLine, operatorName: operatorName)
                    Spacer()
                }
                HStack {
                    Image(systemName: "arrow.right")
                    eventStopName(stopName: stopEvent.destination)
                    Spacer()
            }
        }
            .padding(.leading, 30)
    }
}

struct LineView: View {
    @ObservedObject var path: ViewStateStack
    @StateObject private var lineManager = LineManager()
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @State private var timer: AnyCancellable?
    @Binding var autoRefresh: Bool
    var stopEvent: StopEvent
    var currentStop: ShortStop?
    var currentLine: String
    
    @State private var operatorName: String = ""
    @State private var lineColor: Color = .primary
    
    @State private var scrollDone = false
    @State private var showTime = false
    @State private var lineEvents: [LineEvent] = []
    @State private var busIsHere: Bool = false

    var body: some View {
            GeometryReader { geometry in
                ZStack {
                    
                    //Events view
                    VStack {
                        Rectangle()
                            .frame(height: 15)
                            .opacity(0.0)
                        ScrollViewReader { scroll in
                            ScrollView {
                                LazyVStack {
                                    ForEach(lineEvents, id: \.id) { event in
                                        Button(action: {
                                            path.push(.stop(stopCodedidoc: event.codedidoc, stopName: event.stopPointName, previousLineRef: stopEvent.journeyRef, previousLineName: currentLine, previousLineTime: event.timetabledTime))
                                        }) {
                                            LineEventElementView(event: event, stopEvent: stopEvent, currentLine: currentLine, operatorName: operatorName, currentStopCodedidoc: currentStop?.codedidoc ?? "", showTime: $showTime)
                                        }
                                        .onAppear {
                                            if !scrollDone {
                                                DispatchQueue.main.async {
                                                    withAnimation(.easeInOut(duration: 0.4)) {
                                                        if let currentStop = currentStop {
                                                            let currentStopID = currentStop.codedidoc + stopEvent.timetabledTime
                                                            scroll.scrollTo(currentStopID, anchor: UnitPoint(x: 0.0, y: 0.05))
                                                            scrollDone = true
                                                        }
                                                    }
                                                }
                                            }
                                            print("Ligne " + stopEvent.lineName + ",\n" + stopEvent.transportType + ",\n operateur: " +
                                                  stopEvent.operatorName)
                                        }
                                        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20))
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 5)
                                        .if(!compareDateString(with: event.estimatedTime, equalPossible: false)) { view in
                                            view.contextMenu {
                                                NotificationContextMenu(event: StopEvent(stopPointName: event.stopPointName, stopId: event.codedidoc, plannedQuay: event.plannedQuay, timetabledTime: event.timetabledTime, estimatedTime: event.estimatedTime, lineName: currentLine, origin: stopEvent.origin, destination: stopEvent.destination, transportType: stopEvent.transportType, operatorName: operatorName, journeyRef: stopEvent.journeyRef, operatingDayRef: stopEvent.operatingDayRef), stopID: event.codedidoc, path: path, itinerary: true)
                                            }
                                        }
                                        .background(
                                            GeometryReader { geometry in
                                                if event.id == lineEvents.first?.id {
                                                    Rectangle()
                                                        .frame(width: 7, height: geometry.size.height / 2 + 8)
                                                        .foregroundColor(compareDateString(with: event.estimatedTime, equalPossible: false) ? lineColor.opacity(0.3) : lineColor)
                                                        .position(x: 45, y: geometry.size.height / 4 * 3)
                                                } else if event.id == lineManager.LineEvents.last?.id {
                                                    Rectangle()
                                                        .frame(width: 7, height: geometry.size.height / 2 + 8)
                                                        .foregroundColor(compareDateString(with: event.estimatedTime, equalPossible: true) ? lineColor.opacity(0.3) : lineColor)
                                                        .position(x: 45, y: geometry.size.height / 4)
                                                } else {
                                                    var colorUp = compareDateString(with: event.estimatedTime, equalPossible: true)
                                                    let colorDown = compareDateString(with: event.estimatedTime, equalPossible: false)
                                                    
                                                    Rectangle()
                                                        .frame(width: 7, height: geometry.size.height / 2 + 8)
                                                        .foregroundColor(colorUp ? lineColor.opacity(0.3) : lineColor)
                                                        .position(x: 45, y: geometry.size.height / 4)
                                                    Rectangle()
                                                        .frame(width: 7, height: geometry.size.height / 2 + 8)
                                                        .foregroundColor(colorDown ? lineColor.opacity(0.3) : lineColor)
                                                        .position(x: 45, y: geometry.size.height / 4 * 3)
                                                        .onAppear {
                                                            if busIsHere {
                                                                colorUp = false
                                                            } else if !busIsHere && colorUp && !colorDown {
                                                                busIsHere = true
                                                            }
                                                        }
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                            .contentMargins(.top, 79.0, for: .automatic)
                            .contentMargins(.bottom, 75.0, for: .automatic)
                            .refreshable {
                                getLineEvents(for: stopEvent)
                            }
                        }
                    }
                    .onAppear {
                        getLineEvents(for: stopEvent)
                        timer = Timer.publish(every: 30, on: .main, in: .common)
                            .autoconnect()
                            .sink { _ in
                                getLineEvents(for: stopEvent)
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        if autoRefresh {
                            getLineEvents(for: stopEvent)
                            timer = Timer.publish(every: 30, on: .main, in: .common)
                                .autoconnect()
                                .sink { _ in
                                    getLineEvents(for: stopEvent)
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
                            getLineEvents(for: stopEvent)
                            timer = Timer.publish(every: 30, on: .main, in: .common)
                                .autoconnect()
                                .sink { _ in
                                    getLineEvents(for: stopEvent)
                                }
                        }
                    }
                    //Top card
                    VStack {
                        CustomNavigationTitle(stopEvent: stopEvent, currentLine: currentLine, operatorName: operatorName)
                            .background {
                                RoundedRectangle(cornerRadius: 35.0)
                                    .frame(width: geometry.size.width+100, height: 90)
                                    .foregroundStyle(.thinMaterial)
                                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                    .padding(.trailing, 120)
                            }
                            .padding(.top)
                        Spacer()
                    }
                }
            }
        .toolbar {
            HStack {
                Spacer()
                Button(action: {
                    path.push(.lineMap(lineEvents: lineEvents, lineName: currentLine, lineOperator: operatorName))
                }) {
                    Image(systemName: "map")
                        .font(.title3)
                }
                Button(action: {
                    self.showTime.toggle()
                    // Call the external function with the updated boolean value
                    
                }) {
                    Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill").font(.title3)
                }
            }
        }
    }

    func findDatabaseItem(for id: String, in activeStops: [Stop]) -> Stop? {
        return activeStops.first { $0.id == id }
    }

    
    func getLineEvents(for stopEvent: StopEvent) {
        lineManager.selectJourney(stopEvent) {
            operatorName = self.lineManager.operatorName
            print(operatorName)
            lineColor = LineColors.lineColor(for: currentLine, operatorName: operatorName)
            print(lineColor)
            lineEvents = self.lineManager.LineEvents
        }
    }
}

struct LineEventElementView: View {
    var event: LineEvent
    var stopEvent: StopEvent
    var currentLine: String
    var operatorName: String
    var currentStopCodedidoc: String
    @Binding var showTime: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.thinMaterial)
            .frame(height: 45)
            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
            .overlay(
                HStack {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 5)
                        .background(
                            Circle()
                                .fill(compareDateString(with: event.estimatedTime, equalPossible: false) ? LineColors.lineColor(for: currentLine, operatorName: operatorName).opacity(0.3) : LineColors.lineColor(for: currentLine, operatorName: operatorName, inverted: true))
                        )
                        .frame(width: 18, height: 18)
                    SmallStopTitleView(stopName: event.stopPointName)
                    Spacer()
                    let transportTime = displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime)
                    if transportTime == "0" {
                        transportIcon(with: stopEvent.transportType).frame(width: 10)
                    } else {
                        Text(transportTime)
                            .padding(.vertical, 2)
                            .minimumScaleFactor(0.5)
                    }
                    if event.plannedQuay == "" {
                        Image(systemName: "questionmark.square.fill")
                    } else {
                        Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
                    }
                }
                .foregroundStyle(determineColor(for: event))
                .padding(.horizontal)
            )
            .padding(5)
    }
    
    func determineColor(for event: LineEvent) -> Color {
        print(event.timetabledTime, event.estimatedTime)
        let eventET = event.estimatedTime.isEmpty ? event.timetabledTime : event.estimatedTime
        if event.codedidoc == currentStopCodedidoc {
            return Color.accentColor
        } else if compareDateString(with: eventET, equalPossible: false) {
            return Color.gray
        } else {
            return Color.primary
        }
    }
}
 

struct LineView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()

        return ContentView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

//
//  NewLineView.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Foundation
import Combine
import tpgNextFunc

struct LineViewTitle: View {
    var destination: String
    var currentLine: String
    var operatorName: String
    
    var body: some View {
        VStack(alignment: .leading) {
                HStack {
                    Text("Ligne ")
                        .font(.largeTitle)
                        .bold()
                    BusLineIcon(lineName: currentLine, operatorName: operatorName)
//                    Spacer()
                }
                HStack {
                    Image(systemName: "arrow.right")
                    eventStopName(stopName: destination)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
//                    Spacer()
            }
        }
//            .padding(.leading, 30)
    }
}

struct LineView: View {
    @StateObject private var lineManager = LineManager()
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @EnvironmentObject var appRequirementsClass: AppRequirementsClass
    @State private var timer: AnyCancellable?
    var autoRefresh: Bool = true
    
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
//                        Rectangle()
//                            .frame(height: 15)
//                            .opacity(0.0)
                        ScrollViewReader { scroll in
                            ScrollView {
                                LazyVStack {
                                    ForEach(lineEvents, id: \.id) { event in
                                        NavigationLink {
                                            StopView(stopName: event.stopPointName, stopSloid: event.sloid, previousLineRef: stopEvent.journeyRef, previousLineName: currentLine, previousLineTime: event.timetabledTime)
                                        } label: {
                                            LineEventElementView(currentLine: currentLine, operatorName: operatorName, transportType: stopEvent.transportType, currentStop: event.sloid == currentStop?.sloid ?? "noCurrentStop", eventName: event.stopPointName, estimatedTime: event.estimatedTime, timetabledTime: event.timetabledTime, plannedQuay: event.plannedQuay, showTime: $showTime)
                                        }
                                        .foregroundStyle(.primary)
                                        .onAppear {
                                            if !scrollDone {
                                                DispatchQueue.main.async {
                                                    withAnimation(.easeInOut(duration: 0.4)) {
                                                        if let currentStop = currentStop {
                                                            let currentStopID = currentStop.sloid + stopEvent.timetabledTime
                                                            scroll.scrollTo(currentStopID, anchor: UnitPoint(x: 0.0, y: 0.05))
                                                            scrollDone = true
                                                        }
                                                    }
                                                }
                                            }
//                                            print("Ligne " + stopEvent.lineName + ",\n" + stopEvent.transportType + ",\n operateur: " + stopEvent.operatorName)
                                        }
                                        .contentShape(.contextMenuPreview, Capsule())
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 5)
                                        .if(!dateStringHasPassed(with: event.estimatedTime, equalReturnsTrue: false)) { view in
                                            view.contextMenu {
                                                NotificationContextMenu(event: StopEvent(stopPointName: event.stopPointName, stopId: event.sloid, plannedQuay: event.plannedQuay, timetabledTime: event.timetabledTime, estimatedTime: event.estimatedTime, lineName: currentLine, origin: stopEvent.origin, destination: stopEvent.destination, transportType: stopEvent.transportType, operatorName: operatorName, journeyRef: stopEvent.journeyRef, operatingDayRef: stopEvent.operatingDayRef), stopID: event.sloid, itinerary: true)
                                            }
                                        }
                                        .background(
                                            LineBackground(event: event, firstEventId: lineEvents.first?.id, lastEventId: lineManager.LineEvents.last?.id, lineColor: lineColor, busIsHere: $busIsHere)
                                        )
                                    }
                                }
                            }
                            .contentMargins(.top, 95.0, for: .automatic)
                            .contentMargins(.bottom, appRequirementsClass.version26 ? 0.0 : 60, for: .automatic)
                            .refreshable {
                                getLineEvents(for: stopEvent)
                            }
                        }
                    }
                    .onAppear {
                        getLineEvents(for: stopEvent)
                        if autoRefresh {
                            timer = Timer.publish(every: 30, on: .main, in: .common)
                                .autoconnect()
                                .sink { _ in
                                    getLineEvents(for: stopEvent)
                                }
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
                    
                    if #available(iOS 26, *) {
                    } else {
                        VStack(spacing: 0) {
                            Rectangle()
                                .foregroundStyle(.ultraThickMaterial)
                                .frame(height: 50)
                            Rectangle()
                                .foregroundStyle(.ultraThickMaterial)
                                .frame(height: 100)
                                .mask {
                                    Rectangle()
                                        .overlay(alignment: .trailing) {
                                            ScrollMask(leading: true, vertical: true, gradientLength: 100)
                                        }
                                }
                            Spacer()
                        }
                        //                    .blur(radius: 10)
                        .ignoresSafeArea(edges: .top)
                    }
                    //Top card
                    VStack {
                        HStack {
                        if #available(iOS 26, *) {
                                HStack {
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(width: 50, height: 1)
                                    LineViewTitle(destination: stopEvent.destination, currentLine: currentLine, operatorName: operatorName)
                                        .foregroundStyle(Color.text)
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(maxWidth: 50, maxHeight: 1)
                                }
                                .padding(10)
                                .glassEffect()
                                .offset(x: -50)
                                
                            } else {
                                HStack {
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(width: 50, height: 1)
                                    LineViewTitle(destination: stopEvent.destination, currentLine: currentLine, operatorName: operatorName)
                                    Rectangle()
                                        .fill(.clear)
//                                        .frame(width: 50, height: 1)
                                        .frame(maxWidth: 50, maxHeight: 1)
                                }
                                .padding(10)
                                .background {
                                    Capsule()
//                                        .frame(width: geometry.size.width-100, height: 90)
                                        .foregroundStyle(.thinMaterial)
                                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
//                                        .padding(.trailing, 200)
                                }
                                .offset(x: -50)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    
                }
            }
        .toolbar {
//            Button(action: {
//                showTime.toggle()
//            }) {
//                Image(systemName: "hourglass")
//                    .foregroundColor(showTime ? .text : .white)
//                    .padding(.horizontal, 10)
//                    .padding(.vertical, 15)
//            }
//            .background {
//                Capsule()
//                    .foregroundStyle(showTime ? .clear : .accent)
//                    .padding(.horizontal, 5)
//                    .padding(.vertical, 2)
//            }
            HStack {
                ShowTimeButton(showTime: $showTime)
                
                NavigationLink {
                    LineMapView(lineEvents: lineEvents, lineName: currentLine, operatorName: operatorName, destination: stopEvent.destination, stopEvent: stopEvent, currentStopSloid: currentStop?.sloid)
                } label: {
                    Image(systemName: "map")
                        .padding(.trailing, appRequirementsClass.version26 ? 5 : 10)
                    //                        .font(.title3)
                }
            }
            .background {
                Capsule()
                    .opacity(appRequirementsClass.version26 ? 0 : 1)
                    .foregroundStyle(.ultraThinMaterial)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
            }
        }
        .navigationTitle("Ligne \(currentLine)") // Set back button text
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("") // Visible title
            }
        }
    }

    func findDatabaseItem(for id: String, in activeStops: [Stop]) -> Stop? {
        return activeStops.first { $0.id == id }
    }

    
    func getLineEvents(for stopEvent: StopEvent) {
        lineManager.selectJourney(stopEvent) {
            operatorName = self.lineManager.operatorName
//            print(operatorName)
            lineColor = LineColors.lineColor(for: currentLine, operatorName: operatorName)
//            print(lineColor)
            lineEvents = self.lineManager.LineEvents
        }
    }
}

struct LineBackground: View {
    var event: LineEvent
    var firstEventId: String?
    var lastEventId: String?
    var lineColor: Color
    @Binding var busIsHere: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if event.id == firstEventId {
                Rectangle()
                    .frame(width: 7, height: geometry.size.height / 2 + 8)
                    .foregroundColor(dateStringHasPassed(with: event.estimatedTime, equalReturnsTrue: false) ? lineColor.opacity(0.3) : lineColor)
                    .position(x: 45, y: geometry.size.height / 4 * 3)
            } else if event.id == lastEventId {
                Rectangle()
                    .frame(width: 7, height: geometry.size.height / 2 + 8)
                    .foregroundColor(dateStringHasPassed(with: event.estimatedTime, equalReturnsTrue: true) ? lineColor.opacity(0.3) : lineColor)
                    .position(x: 45, y: geometry.size.height / 4)
            } else {
                var colorUp = dateStringHasPassed(with: event.estimatedTime, equalReturnsTrue: true)
                let colorDown = dateStringHasPassed(with: event.estimatedTime, equalReturnsTrue: false)
                
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
    }
}

struct LineEventElementView: View {
    var currentLine: String
    var operatorName: String
    var transportType: String
    var currentStop: Bool = false
    var eventName: String
    var estimatedTime: String
    var timetabledTime: String
    var plannedQuay: String
    @Binding var showTime: Bool
    var pastEventPossible: Bool = true //If the event is in the past, it will become grey.
    var geoPositionDisplay: Bool = false //Changes the name display type
    var displayIcon: Bool = true //Display a transport icon if event time equals current time
    
    var body: some View {
//        RoundedRectangle(cornerRadius: 20)
//        Capsule()
//            .stroke(currentStop ? .accent : .border, lineWidth: 1)
//            .fill(.thinMaterial)
//            .fill(.color1)
        BasicElement(highlighted: currentStop)
            .frame(height: 45)
//            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
//            .shadow(color: .customShadows.opacity(0.2), radius: 10)
            .overlay(
                HStack {
                    StopIcon(color: LineColors.lineColor(for: currentLine, operatorName: operatorName, inverted: true))
                    if geoPositionDisplay {
                        Text(eventName)
                    } else {
                        SmallStopTitleView(stopName: eventName)
                    }
                    Spacer()
                    let transportTime = displayTimeOrMinutesRemaining(for: timetabledTime, estimatedInput: estimatedTime, with: showTime)
                    if transportTime.text == "0" && displayIcon {
                        transportIcon(with: transportType).frame(width: 10)
                    } else {
                        if transportTime.text.count > 6 { //Time with delay
                            let splitTime = splitString(transportTime.text, separator: ";" )
                            VStack(spacing: 0) {
                                Text(splitTime.0)
                                Text(splitTime.1).foregroundStyle(transportTime.color)
                                    .minimumScaleFactor(0.5)
                            }
                            .padding(.vertical, 4)
                        } else {
                            Text(transportTime.text)
                                .padding(.vertical, 4)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(transportTime.color)
                        }
                    }
                    if plannedQuay == "" { //Unkown quay
                        Image(systemName: "questionmark.square.fill")
                    } else if plannedQuay == "ignore" { //Used for trip, if no transport connection
                        Image(systemName: "dot.square.fill")
                    } else {
                        Image(systemName: "\(plannedQuay.lowercased()).square.fill")
                    }
                }
                    .foregroundStyle(.primary)
//                .foregroundStyle(pastEventPossible ? determineColor(for: estimatedTime): .primary)
                    .opacity(pastEventPossible && dateStringHasPassed(with: estimatedTime, equalReturnsTrue: false) ? 0.3 : 1)
                .padding(.horizontal)
            )
            .padding(5)
    }
}

struct LineView_Previews: PreviewProvider {
    static var previews: some View {
        @StateObject var appRequirementsClass = AppRequirementsClass()
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()
        let date = "2025-09-12"
//        @State var showTime: Bool = false

        return
            NavigationStack {
                LineView(autoRefresh: false,
                         stopEvent: StopEvent(stopPointName: "Genève, Rive", stopId: "ch:1:sloid:87061:0:450545", plannedQuay: "I", timetabledTime: "\(date)T11:13:00Z", estimatedTime: "\(date)T11:13:00Z", lineName: "A", origin: "Genève, Rive", destination: "Gy, temple", transportType: "bus", operatorName: "Transports Publics Genevois", journeyRef: "ch:1:sjyid:100680:HAS-26-A-0-Lun-Ven-33791918", operatingDayRef: date),
                         currentStop: ShortStop(name: "Genève, Rive", sloid: "ch:1:sloid:87061"),
                         currentLine: "A")
            }
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
            .environmentObject(appRequirementsClass)
//        return LineEventElementView(currentLine: "A", operatorName: "tpg", transportType: "Bus", currentStopCodedidoc: "1", eventCodedidoc: "1", eventName: "Meinier, église", estimatedTime: "2025-06-27T18:18:18Z", timetabledTime: "2025-06-27T18:18:18Z", plannedQuay: "H", showTime: $showTime)
    }
}


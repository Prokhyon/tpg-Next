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

/// Le titre de ligne flottant en haut de la liste et de la carte.
struct FloatingLineTitle: View {
    var destination: String
    var currentLine: String
    var operatorName: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(.clear)
                .frame(width: 50, height: 1)
            LineViewTitle(destination: destination, currentLine: currentLine, operatorName: operatorName)
                .glassForegroundStyle(Color.text)
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: 50, maxHeight: 1)
        }
        .padding(10)
        .tpgSurface(legacy: .thinMaterial)
    }
}

struct LineView: View {
    @State private var lineManager = LineManager()
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(AppRequirementsClass.self) var appRequirementsClass
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
                                            LineEventElementView(currentLine: currentLine, operatorName: operatorName, transportType: stopEvent.transportType, currentStop: event.sloid == currentStop?.sloid, eventName: event.stopPointName, estimatedTime: event.estimatedTime, timetabledTime: event.timetabledTime, plannedQuay: event.plannedQuay, showTime: $showTime)
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
                                            LineBackground(event: event, firstEventId: lineEvents.first?.id, lastEventId: lineManager.lineEvents.last?.id, lineColor: lineColor, busIsHere: $busIsHere)
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
                    .periodicRefresh(repeats: autoRefresh) { _ in
                        getLineEvents(for: stopEvent)
                    }
                    
                    LegacyTopFade()
                    //Top card
                    VStack {
                        HStack {
                        FloatingLineTitle(destination: stopEvent.destination, currentLine: currentLine, operatorName: operatorName)
                            .offset(x: -50)
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
            lineEvents = self.lineManager.lineEvents
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
                    let transportTime = departureDisplay(timetabled: timetabledTime, estimated: estimatedTime, showTime: showTime)
                    DepartureTimeView(transportTime, transportType: transportType, iconWidth: 10, showsIcon: displayIcon)
                        .padding(.vertical, 4)
                    if plannedQuay == "ignore" { // Étape d'itinéraire sans transport : pas de quai
                        Image(systemName: "dot.square.fill")
                    } else {
                        QuayIcon(quay: plannedQuay)
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
        @State var appRequirementsClass = AppRequirementsClass()
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
            .environment(stopStore)
            .environment(favoritesViewModel)
            .environment(appRequirementsClass)
//        return LineEventElementView(currentLine: "A", operatorName: "tpg", transportType: "Bus", currentStopCodedidoc: "1", eventCodedidoc: "1", eventName: "Meinier, église", estimatedTime: "2025-06-27T18:18:18Z", timetabledTime: "2025-06-27T18:18:18Z", plannedQuay: "H", showTime: $showTime)
    }
}


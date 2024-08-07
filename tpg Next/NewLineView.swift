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
    
    var body: some View {
            VStack {
                HStack {
                    Text("Ligne ")
                        .font(.largeTitle)
                        .bold()
                        .padding(.leading, 15)
                    BusLineIcon(lineName: currentLine)
                    Spacer()
                }
                HStack {
                    Image(systemName: "arrow.right")
                        .padding(.leading, 15)
//                    Text(stopEvent.destination)
                    eventStopName(stopName: stopEvent.destination)
//                        .padding(.leading, 15)
                    Spacer()
            }
        }
    }
}

struct LineView: View {
    @StateObject private var lineManager = LineManager()
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @State private var timer: AnyCancellable?
    var stopEvent: StopEvent
    var currentStop: ShortStop?
    var currentLine: String
    @State private var scrollDone = false
    @State private var showTime = false
    @ObservedObject var viewStateStack: ViewStateStack
    @State private var lineEvents: [LineEvent] = []
    @Binding var transition: AnyTransition

    var body: some View {
        ZStack {
            
            //Events view
            VStack {
                Spacer(minLength: 110)
                ScrollViewReader { scroll in
                    ScrollView {
                        //Spacer(minLength: 10)
                        Rectangle()
                            .frame(height: 30)
                            .opacity(0.0)
                        ForEach(lineEvents) { event in
//                            if let stop = findDatabaseItem(for: event.id, in: stopStore.activeStops) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        transition = .trailingIn
                                        viewStateStack.push(.stop(stopCodedidoc: event.stopPlaceRef, stopName: event.stopPointName, previousLineRef: stopEvent.journeyRef, previousLineName: currentLine))
                                    }
                                }) {
                                    LineEventElementView(event: event, stopEvent: stopEvent, currentLine: currentLine, currentStopCodedidoc: currentStop?.codedidoc ?? "", showTime: $showTime)
                                }
                                .onAppear {
                                    if !scrollDone {
                                        DispatchQueue.main.async {
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                if let currentStop = currentStop {
                                                    scroll.scrollTo(currentStop.codedidoc, anchor: UnitPoint(x: 0.0, y: 0.05))
                                                    scrollDone = true
                                                }
                                            }
                                        }
                                    }
                                }
                                .if(!compareDateString(with: event.estimatedTime)) { view in
                                    view.contextMenu {
                                        Button(action: {
                                            scheduleBusNotifications(for: createEssentialStopEvent(journeyRef: stopEvent.journeyRef , operatingDayRef: stopEvent.operatingDayRef, stopPointName: stopEvent.stopPointName, lineName: currentLine, origin: stopEvent.origin, destination: stopEvent.destination, transportType: stopEvent.transportType), stopID: "\(event.stopPlaceRef)", timeDelay: 0.0, lineManager: lineManager)
                                        }) {
                                            Text("Prévenir à l'arrivée")
                                        }
                                        Button(action: {
                                            scheduleBusNotifications(for: createEssentialStopEvent(journeyRef: stopEvent.journeyRef , operatingDayRef: stopEvent.operatingDayRef, stopPointName: stopEvent.stopPointName, lineName: currentLine, origin: stopEvent.origin, destination: stopEvent.destination, transportType: stopEvent.transportType), stopID: "\(event.stopPlaceRef)", timeDelay: 1.0, lineManager: lineManager)
                                        }) {
                                            Text("Prévenir 1' avant")
                                        }
                                        Button(action: {
                                            print("arret: \(event.stopPointName), \(stopEvent)")
                                            scheduleBusNotifications(for: createEssentialStopEvent(journeyRef: stopEvent.journeyRef , operatingDayRef: stopEvent.operatingDayRef, stopPointName: event.stopPointName, lineName: currentLine, origin: stopEvent.origin, destination: stopEvent.destination, transportType: stopEvent.transportType), stopID: "\(event.stopPlaceRef)", timeDelay: 5.0, lineManager: lineManager)
                                        }) {
                                            Text("Prévenir 5' avant")
                                        }
                                        Button(action: {
                                            scheduleBusNotifications(for: createEssentialStopEvent(journeyRef: stopEvent.journeyRef , operatingDayRef: stopEvent.journeyRef, stopPointName: stopEvent.stopPointName, lineName: currentLine, origin: stopEvent.origin, destination: stopEvent.destination, transportType: stopEvent.transportType), stopID: "\(event.stopPlaceRef)", timeDelay: 10.0, lineManager: lineManager)
                                        }) {
                                            Text("Prévenir 10' avant")
                                        }
                                        Button(action: {
                                            scheduleBusNotifications(for: createEssentialStopEvent(journeyRef: stopEvent.journeyRef , operatingDayRef: stopEvent.operatingDayRef, stopPointName: stopEvent.stopPointName, lineName: currentLine, origin: stopEvent.origin, destination: stopEvent.destination, transportType: stopEvent.transportType), stopID: "\(event.stopPlaceRef)", timeDelay: 30.0, lineManager: lineManager)
                                        }) {
                                            Text("Prévenir 30' avant")
                                        }
                                    }
                                }
                                .background(
                                    GeometryReader { geometry in
                                        if event.id == lineEvents.first?.id {
                                            Rectangle()
                                                .frame(width: 7, height: geometry.size.height / 2 + 8)
                                                .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                .position(x: 30, y: geometry.size.height / 4 * 3)
                                        } else if event.id == lineManager.LineEvents.last?.id {
                                            Rectangle()
                                                .frame(width: 7, height: geometry.size.height / 2 + 8)
                                                .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                .position(x: 30, y: geometry.size.height / 4)
                                        } else {
                                            Rectangle()
                                                .frame(width: 7, height: geometry.size.height / 2 + 8)
                                                .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                .position(x: 30, y: geometry.size.height / 4)
                                            Rectangle()
                                                .frame(width: 7, height: geometry.size.height / 2 + 8)
                                                .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                .position(x: 30, y: geometry.size.height / 4 * 3)
                                        }
                                    }
                                )
//                            }
                        }
                        Rectangle()
                        .frame(height: 70)
                        .opacity(0.0)
                    }
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
                getLineEvents(for: stopEvent)
                timer = Timer.publish(every: 30, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        getLineEvents(for: stopEvent)
                    }
                            }
            .onDisappear {
                timer?.cancel()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                timer?.cancel()
                            }
            
            //Top card
            VStack {
                HStack {
                    Button(action: {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        transition = .leadingIn
                                        viewStateStack.pop()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "chevron.backward")
                                        Text(currentStop?.name ?? "Accueil")
                                    }
                                }
                    Spacer()
            Button(action: {
                self.showTime.toggle()
        // Call the external function with the updated boolean value
        
                }) {
            Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill")
                 .font(.title)
               }
            }
                .frame(width: 350)
                CustomNavigationTitle(stopEvent: stopEvent, currentLine: currentLine)
                    .background {
                        RoundedRectangle(cornerRadius: 35.0)
                            .frame(width: 450, height: 90)
                            .foregroundStyle(Color.color1)
                            .shadow(color: Color.customShadows, radius: 3, y: 2)
                            .padding(.trailing, 100)
                    }
                    .padding(.top)
                Spacer()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    if value.startLocation.x < 20 && value.translation.width > 50 {
                        // Edge swipe detected
                        withAnimation(.easeInOut(duration: 0.4)) {
                            transition = .leadingIn
                            viewStateStack.pop()
                        }
                    }
                }
        )
//        .transition(.truSlide)
    }

    func findDatabaseItem(for id: String, in activeStops: [Stop]) -> Stop? {
        return activeStops.first { $0.id == id }
    }

//    func determineColor(for event: LineEvent) -> Color {
//        print(event.timetabledTime, event.estimatedTime)
//        let eventET = event.estimatedTime.isEmpty ? event.timetabledTime : event.estimatedTime
//        if event.stopPlaceRef == "\(currentStop?.codedidoc ?? "")" {
//            return Color.accentColor
//        } else if compareDateString(with: eventET) {
//            return Color.gray
//        } else {
//            return Color.primary
//        }
//    }
    
    func getLineEvents(for stopEvent: StopEvent) {
        lineManager.selectJourney(stopEvent) {
            lineEvents = self.lineManager.LineEvents
        }
    }
}

struct LineEventElementView: View {
    var event: LineEvent
    var stopEvent: StopEvent
//    var stop: Stop
    var currentLine: String
    var currentStopCodedidoc: String
    @Binding var showTime: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.color1)
            .frame(width: 330, height: 45)
            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
            .overlay(
                HStack {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 5)
                        .background(
                            Circle()
                                .fill(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                        )
                        .frame(width: 18, height: 18)
//                    Text(event.stopPointName)
                    eventStopName(stopName: event.stopPointName)
                    Spacer()
                    if displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime) == "0" {
                        transportIcon(with: stopEvent.transportType)
                    } else {
                        Text("\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))")
                    }
                    if event.plannedQuay == "" {
                        Image(systemName: "questionmark.square.fill")
                    } else {
                        Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
                    }
                }
                .foregroundStyle(determineColor(for: event))
                .padding(.horizontal)
                .padding(.vertical, 0)
            )
            .padding(.horizontal, 5)
            .padding(.vertical, 10)
    }
    
    func determineColor(for event: LineEvent) -> Color {
        print(event.timetabledTime, event.estimatedTime)
        let eventET = event.estimatedTime.isEmpty ? event.timetabledTime : event.estimatedTime
        if event.stopPlaceRef == currentStopCodedidoc {
            return Color.accentColor
        } else if compareDateString(with: eventET) {
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

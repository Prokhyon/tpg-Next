//
//  LineView.swift
//  TPG4
//
//  Created by Loris Thomas on 21.06.2024.
//

import SwiftUI
import Combine

struct LineTitle: View {
    var stopEvent: StopEvent
    var currentLine: String
    
    var body: some View {
        VStack {
            HStack {
                Text("Ligne \(currentLine)")
                    .font(.largeTitle)
                    .bold()
                    .padding(.leading, 15)
                Spacer()
            }
            HStack {
                Image(systemName: "arrow.right")
                    .padding(.leading, 15)
                Text(stopEvent.destination)
                    .padding(.leading, 15)
                Spacer()
            }
        }
    }
}


//struct OldLineView: View {
//    @StateObject private var lineManager = LineManager()
//    @StateObject private var stopStore = StopStore()
//    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
//    @State private var timer: AnyCancellable?
//    var stopEvent: StopEvent
//    var currentStop: Stop
//    var currentLine: String
//    @State private var scrollDone = false
//    @State private var showTime = false
//    
//    
//    
//    var body: some View {
//        ScrollViewReader { scroll in
//            VStack {
//                /*HStack {
//                 Image(systemName: "arrow.right")
//                 .offset(x:15)
//                 Text(stopEvent.destination)
//                 .offset(x:15)
//                 Spacer()
//                 }*/
//                LineTitle(stopEvent: stopEvent, currentLine: currentLine)
//                List(lineManager.LineEvents, id: \.id) { event in
//                    if let stop = findDatabaseItem(for: event.id, in: stopStore.activeStops) {
//                        NavigationLink {
//                            StopView(favoritesViewModel: favoritesViewModel, stop: stop, previousLineRef: stopEvent.journeyRef)
//                        } label: {
//                            HStack {
//                                Circle()
//                                //.strokeBorder(determineColor(for: event) == Color.gray ? LineColors.lineColor(for: currentLine).opacity(0.1) : LineColors.lineColor(for: currentLine), lineWidth: 4)
//                                //.background(Circle().fill(determineColor(for: event)))
//                                //.foregroundStyle(determineColor(for: event) == Color.gray ? Color.gray : Color.primary )
//                                    .strokeBorder(.primary, lineWidth: 5)
//                                    .background(
//                                        Circle()
//                                            .fill(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3): LineColors.lineColor(for: currentLine)))
//                                    .frame(width: 18, height: 18)
//                                
//                                Text(stop.nomarret)
//                                Spacer()
//                                if displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime)  == "0" { Image(systemName: "bus.fill")
//                                } else { Text("\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))") }
//                                Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
//                                
//                            }
//                            .foregroundStyle(determineColor(for: event))
//                            //.foregroundStyle(compareDateString(with: event.timetabledTime) ? Color.gray : Color.primary)
//                            .background(
//                                GeometryReader { geometry in
//                                    if event.id == lineManager.LineEvents.first?.id {
//                                        Rectangle()
//                                            .frame(width: 7, height: geometry.size.height+5)
//                                            .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
//                                            .position(x: 9, y: geometry.size.height+10)
//                                    } else if event.id == lineManager.LineEvents.last?.id {
//                                        Rectangle()
//                                            .frame(width: 7, height: geometry.size.height+5)
//                                            .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
//                                            .position(x: 9, y: 0 )
//                                    } else {
//                                        Rectangle()
//                                            .frame(width: 7, height: geometry.size.height*2+5)
//                                            .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
//                                            .position(x: 9, y: geometry.size.height / 2)
//                                    }
//                                }
//                            )
//                            /* let isFirst = event.id == lineManager.LineEvents.first?.id
//                             let isLast = event.id == lineManager.LineEvents.last?.id
//                             
//                             let rectangleHeight: CGFloat = isFirst || isLast ? geometry.size.height / 2 : geometry.size.height
//                             let yOffset: CGFloat = isFirst ? rectangleHeight / 2 : (isLast ? geometry.size.height / 2 : 0)
//                             
//                             Rectangle()
//                             .frame(width: 7, height: rectangleHeight)
//                             .foregroundColor(LineColors.color(for: event.lineID))
//                             .position(x: 3.5, y: geometry.size.height / 2 + yOffset)
//                             }
//                             )*/
//                            /*.background(
//                             GeometryReader { geometry in
//                             Rectangle()
//                             .frame(width: 7, height: geometry.size.height*2+5)
//                             .foregroundColor(determineColor(for: event) == Color.gray ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
//                             .position(x: 10, y: geometry.size.height / 2)
//                             }
//                             )*/
//                        }
//                        .listRowBackground(Color.color1)
//                        .onAppear {
//                            if !scrollDone {
//                                withAnimation(.easeInOut(duration: 0.01)) {
//                                    scroll.scrollTo(currentStop.codedidoc, anchor: .top)
//                                    scrollDone = true
//                                }
//                            }
//                        }
//                        .background(Color.color1)
//                    }
//                    
//                }
//                .onAppear {
//                    lineManager.selectJourney(stopEvent)
//                    timer = Timer.publish(every: 30, on: .main, in: .common)
//                        .autoconnect()
//                        .sink { _ in
//                            lineManager.selectJourney(stopEvent)
//                        }
//                }
//                .onDisappear {
//                    timer?.cancel()
//                }
//                .refreshable {
//                    lineManager.selectJourney(stopEvent)
//                }
//                //.navigationTitle("Ligne \(currentLine)")
//                /*.toolbar {
//                 ToolbarItem(placement: .topBarLeading) {
//                 CustomNavigationTitle(line: currentLine)
//                 }
//                 }*/
//                .toolbar {
//                    Button(action: {
//                        self.showTime.toggle()
//                        // Call the external function with the updated boolean value
//                        
//                    }) {
//                        Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill")
//                            .font(.title)
//                    }
//                }
//                .listStyle(.plain)
//                .background()
//                .background(.regularMaterial)
//                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
//                .padding(.horizontal)
//                .padding(.vertical, 10.0)
//                .shadow(radius: 5)
//            }
//        }
//    }
//    func findDatabaseItem(for id: Int, in activeStops: [Stop]) -> Stop? {
//        return activeStops.first { $0.id == id }
//    }
//    
//    
//
//    func determineColor(for event: LineEvent) -> Color {
//            if event.stopPlaceRef == "\(currentStop.codedidoc)" {
//                return Color.accentColor
//            } else if compareDateString(with: event.estimatedTime) {
//                return Color.gray
//            } else {
//                return Color.primary
//            }
//        }
//}


#Preview {
    ContentView()
}

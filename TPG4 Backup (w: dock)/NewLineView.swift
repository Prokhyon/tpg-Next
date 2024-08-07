//
//  NewLineView.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Combine

struct NewLineView: View {
    @StateObject private var lineManager = LineManager()
    @StateObject private var stopStore = StopStore()
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @State private var timer: AnyCancellable?
    var stopEvent: StopEvent
    var currentStop: Stop?
    var currentLine: String
    @State private var scrollDone = false
    @State private var showTime = false
    
    
    
    var body: some View {
        ZStack {
                VStack {
                    Spacer(minLength: 85)
                    NavigationStack {
                        ScrollViewReader { scroll in
                            List(lineManager.LineEvents, id: \.id) { event in
                                if let stop = findDatabaseItem(for: event.id, in: stopStore.activeStops) {
                                    NavigationLink {
                                        NewStopViewTest(favoritesViewModel: favoritesViewModel, stop: stop, previousLineRef: stopEvent.journeyRef)
                                    } label: { RoundedRectangle(cornerRadius: 20)
                                            .fill(.color1)
                                            .frame(width: 330, height: 45)
                                            .shadow(radius: 5)
                                            .overlay(
                                                HStack {
                                                    Circle()
                                                        .strokeBorder(.primary, lineWidth: 5)
                                                        .background(
                                                            Circle()
                                                                .fill(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3): LineColors.lineColor(for: currentLine)))
                                                        .frame(width: 18, height: 18)
                                                    
                                                    Text(stop.nomarret)
                                                    Spacer()
                                                    if displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime)  == "0" { Image(systemName: "bus.fill")
                                                    } else { Text("\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))") }
                                                    Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
                                                    
                                                }
                                                    .foregroundStyle(determineColor(for: event))
                                                /*.background(
                                                 GeometryReader { geometry in
                                                 if event.id == lineManager.LineEvents.first?.id {
                                                 Rectangle()
                                                 .frame(width: 7, height: geometry.size.height+5)
                                                 .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                 .position(x: 9, y: geometry.size.height+10)
                                                 } else if event.id == lineManager.LineEvents.last?.id {
                                                 Rectangle()
                                                 .frame(width: 7, height: geometry.size.height+5)
                                                 .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                 .position(x: 9, y: 0 )
                                                 } else {
                                                 Rectangle()
                                                 .frame(width: 7, height: geometry.size.height*2+5)
                                                 .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                 .position(x: 9, y: geometry.size.height / 2)
                                                 }
                                                 }
                                                 )*/
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 0)
                                            )
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                                    //.listRowBackground(Color.color1)
                                    .onAppear {
                                        if !scrollDone {
                                            withAnimation(.easeInOut(duration: 0.01)) {
                                                if currentStop != nil {
                                                    scroll.scrollTo(currentStop?.codedidoc, anchor: .top)
                                                    scrollDone = true
                                                }
                                            }
                                        }
                                    }
                                    .background(
                                        GeometryReader { geometry in
                                            if event.id == lineManager.LineEvents.first?.id {
                                                Rectangle()
                                                    .frame(width: 7, height: geometry.size.height/2)
                                                    .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                    .position(x: 44, y: geometry.size.height/4*3)
                                            } else if event.id == lineManager.LineEvents.last?.id {
                                                Rectangle()
                                                    .frame(width: 7, height: geometry.size.height / 2)
                                                    .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                    .position(x: 44, y: geometry.size.height/4)
                                            } else {
                                                Rectangle()
                                                    .frame(width: 7, height: geometry.size.height/2)
                                                    .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                    .position(x: 44, y: geometry.size.height/4)
                                                Rectangle()
                                                    .frame(width: 7, height: geometry.size.height/2)
                                                    .foregroundColor(compareDateString(with: event.estimatedTime) ? LineColors.lineColor(for: currentLine).opacity(0.3) : LineColors.lineColor(for: currentLine))
                                                    .position(x: 44, y: geometry.size.height/4*3)
                                            }
                                        }
                                    )
                                }
                                
                            }
                            .onAppear {
                                lineManager.selectJourney(stopEvent)
                                timer = Timer.publish(every: 30, on: .main, in: .common)
                                    .autoconnect()
                                    .sink { _ in
                                        lineManager.selectJourney(stopEvent)
                                    }
                            }
                            .onDisappear {
                                timer?.cancel()
                            }
                            .refreshable {
                                lineManager.selectJourney(stopEvent)
                            }
                            .toolbar {
                                HStack {
                                    Button(action: {
                                        self.showTime.toggle()
                                        // Call the external function with the updated boolean value
                                        
                                    }) {
                                        Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill")
                                            .font(.title)
                                    }
                                }
                            }
                            .listStyle(.plain)
                            //.padding(.horizontal)
                            .padding(.top, 10.0)
                            .background(Color.color1)
                        }
                    }
                Spacer(minLength: 45)
            }
            VStack {
                CustomNavigationTitle(stopEvent: stopEvent, currentLine: currentLine)
                    .background {
                        RoundedRectangle(cornerRadius: 35.0)
                            .frame(width: 450, height: 90)
                            .foregroundStyle(.color1)
                            .shadow(radius: 10)
                            .padding(.trailing, 100)
                            //.ignoresSafeArea(edges: .top)
                    }
                    .padding(.top, 30)
                Spacer()
            }
        }
    }
    func findDatabaseItem(for id: Int, in activeStops: [Stop]) -> Stop? {
        return activeStops.first { $0.id == id }
    }
    
    

    func determineColor(for event: LineEvent) -> Color {
        if event.stopPlaceRef == "\(currentStop?.codedidoc)" {
                return Color.accentColor
            } else if compareDateString(with: event.estimatedTime) {
                return Color.gray
            } else {
                return Color.primary
            }
        }
}
 

struct LineView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return AppTabBarView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

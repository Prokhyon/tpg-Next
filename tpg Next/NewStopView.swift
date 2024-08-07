//
//  StopView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import SwiftUI
import Combine

struct AdaptiveTitleView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
               .font(.largeTitle)
                .bold()
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                //.frame(width: 400)
            Spacer()
        }
    }
}

struct StopBus: View  {
    var event: StopEvent
    var showTime: Bool
    
    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerSize: CGSize(width: 10, height: 10))
                    .stroke(LineColors.lineColor(for: event.lineName), lineWidth: 4)
                    .frame(width: 35, height: 25)
                Text("\(event.lineName)")
            }
            //Image(systemName: "\(event.lineName).square").font(.title2)
            Image(systemName: "arrow.right")
            Text("\(event.destination)")
            Spacer()
            if displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime,  with: showTime)  == "0" { Image(systemName: "bus.fill")
            } else {
                if "\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))".count > 3 {
                    Text("\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))").frame(width: 45)
                } else {
                    Text("\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))")
                }
            }
            Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
        }
    }
}

struct StopView: View {
    @StateObject private var stopManager = StopManager()
    @ObservedObject var favoritesViewModel: FavoritesViewModel
    @State private var timer: AnyCancellable?
    let stop: Stop
    var previousLineRef: String?
    @State private var showTime = false
    
    var body: some View {
            NavigationStack {
                HStack {
                    Spacer()
                    Spacer()
                    Spacer()
                    AdaptiveTitleView(title: stop.nomarret)
                    //Spacer()
                }
                List(stopManager.stopEvents.sorted(by: {$0.estimatedTime < $1.estimatedTime}), id: \.id) { event in
                    
                    if !compareDateString(with: event.estimatedTime){
                        NavigationLink {
                            LineView(stopEvent: event, currentStop: stop, currentLine: event.lineName)
                        } label: {
                            StopBus(event: event, showTime: showTime)
                                .foregroundStyle(event.journeyRef == previousLineRef ? Color.accentColor : Color.primary)
                        }
                    }
                }
                .background(Capsule())
                .onAppear {
                    stopManager.selectStop(stop, stopEventNumber: 30)
                    timer = Timer.publish(every: 30, on: .main, in: .common)
                        .autoconnect()
                        .sink { _ in
                            stopManager.selectStop(stop, stopEventNumber: 30)
                        }
                }
                .onDisappear {
                    timer?.cancel()
                }
                .refreshable {
                    stopManager.selectStop(stop, stopEventNumber: 30)
                }
                //.navigationTitle(Text(stop.nomarret).frame(width: 400))
                .toolbar {
                   /* ToolbarItem(placement: .principal) {
                                        AdaptiveTitleView(nomarret: stop.nomarret)
                                    }
                    ToolbarItem(placement: .navigationBarTrailing) {*/
                        HStack {
                            Button(action: {
                                self.showTime.toggle()
                                // Call the external function with the updated boolean value
                                
                            }) {
                                Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill")
                                    .font(.title)
                            }
                            Button(action: {
                                toggleFavorite()
                            }) {
                                Image(systemName: favoritesViewModel.isFavorite(stop) ? "star.fill" : "star")
                                    .foregroundColor(.accentColor)
                                    .font(.title)
                           // }
                        }
                        
                    }
                }
            }
        }
    
    private func toggleFavorite() {
           if favoritesViewModel.isFavorite(stop) {
               favoritesViewModel.removeFavorite(stop)
           } else {
               favoritesViewModel.addFavorite(stop)
           }
        print(favoritesViewModel.favoriteStops)
       }
}

#Preview {
    ContentView()
}

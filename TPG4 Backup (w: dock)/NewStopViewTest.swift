//
//  NewStopViewTest.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Combine

struct NewStopBus: View  {
    var event: StopEvent
    var showTime: Bool
    
    var body: some View {
        HStack {
            BusLineIcon(lineName: event.lineName)
            //Image(systemName: "\(event.lineName).square").font(.title2)
            Image(systemName: "arrow.right")
            Text("\(event.destination)")
            Spacer()
            if displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime,  with: showTime)  == "0" { Image(systemName: "bus.fill")
            } else {
                if "\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))".count > 3 {
                    Text("\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))").frame(width: 50)
                } else {
                    Text("\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))")
                }
            }
            Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
        }
        .padding(.horizontal)
    }
}

struct NewStopViewTest: View {
    @StateObject private var stopManager = StopManager()
    @ObservedObject var favoritesViewModel: FavoritesViewModel
    @State private var timer: AnyCancellable?
    let stop: Stop
    var previousLineRef: String?
    @State private var showTime = false
    
    
    var body: some View {
        ZStack {
            VStack {
                Spacer(minLength: 65)
                NavigationStack {
                        List(stopManager.stopEvents.sorted(by: {$0.estimatedTime < $1.estimatedTime}), id: \.id) { event in
                            
                            if !compareDateString(with: event.estimatedTime){
                                NavigationLink {
                                    NewLineView(stopEvent: event, currentStop: stop, currentLine: event.lineName)
                                } label: {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.color1)
                                        .frame(width: 350, height: 50)
                                        .shadow(radius: 3)
                                        .overlay(
                                    NewStopBus(event: event, showTime: showTime)
                                        .foregroundStyle(event.journeyRef == previousLineRef ? Color.accentColor : Color.primary)
                                        .padding(.vertical, 0)
                                        
                                    )
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 20)
                                    
                                }
                                //.listRowBackground(Color.color1)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.color1)
                       // .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        //.padding(.horizontal)
                        .padding(.top, 10.0)
                        //.shadow(radius: 5)
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
                        //.scrollDisabled(true)
                        /*RoundedRectangle(cornerRadius: 25.0)
                         .frame(width: 360, height: 600)
                         .foregroundStyle(.color1)
                         .shadow(radius: 10)*/
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
                Spacer(minLength: 50)
                }
            VStack {
                AdaptiveTitleView(title: stop.nomarret)
                    .background {
                        RoundedRectangle(cornerRadius: 45.0)
                            .frame(width: 395, height: 180)
                            .foregroundStyle(.color1)
                            .shadow(radius: 10)
                            .ignoresSafeArea(edges: .top)
                    }
                Spacer()
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


struct NewStopView: View {
    var body: some View {
        Spacer()
        RoundedRectangle(cornerRadius: 25.0)
            .frame(width: 360, height: 600)
            .foregroundStyle(.color1)
            .shadow(radius: 10)
    }
}

struct AdaptiveTitleView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
               .font(.largeTitle)
                .bold()
                //.foregroundColor(.primary)
                //.multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .padding(.leading, 15)
                //.frame(width: 400)
            Spacer()
        }
    }
}

struct StopView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return AppTabBarView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

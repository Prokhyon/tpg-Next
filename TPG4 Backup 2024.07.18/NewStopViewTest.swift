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
            if displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime,  with: showTime)  == "0" { 
                transportIcon(with: event.transportType).frame(width: 10)
            } else {
                if "\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))".count > 3 {
                    Text("\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))").frame(width: 50)
                } else {
                    Text("\(displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime, with: showTime))")
                }
            }
            if event.plannedQuay == "" {
                Image(systemName: "questionmark.square.fill")
            } else {
                Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
            }
        }
        .padding(.horizontal)
    }
}

struct StopView: View {
    @StateObject private var stopManager = StopManager()
    @ObservedObject var viewStateStack: ViewStateStack
    @ObservedObject var favoritesViewModel: FavoritesViewModel
    @StateObject private var lineManager = LineManager()
    @State private var stopEvents: [StopEvent] = []
    @State private var timer: AnyCancellable?
    let stop: Stop
    var previousLineRef: String?
    var previousLineName: String?
    @State private var showTime = false
    @State private var isShowingPopover = false
    @State private var timeIntervalNotification = 0
    @State private var showingPicker = false
    @State private var selectedNumber = 5
    @Binding var useLeadingToTrailing: Bool
    @State private var timeRequest = Date()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    Spacer(minLength: 110)
                    ScrollView {
                        Spacer(minLength: 20)
                        Button(action: {
                            timeRequest = Date()
                            adjustTime(byAdding: -15)
                            getStopEvents(for: stop)
                        }) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.color1)
                                .frame(width: 350, height: 50)
                                .shadow(color: Color.customShadows, radius: 3)
                                .overlay(
                                    Text("Départs précédents")
                                )
                                .padding(.vertical, 3)
                                .padding(.horizontal, 20)
                        }
                        ForEach(stopManager.stopEvents.sorted(by: { $0.estimatedTime < $1.estimatedTime }), id: \.id) { event in
                            //                        if !compareDateString(with: event.estimatedTime) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    useLeadingToTrailing = false
                                    viewStateStack.push(.line(stopEvent: event, currentStop: stop, currentLine: event.lineName))
                                }
                            }) {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.color1)
                                    .frame(width: 350, height: 50)
                                    .shadow(color: Color.customShadows, radius: 3)
                                    .overlay(
                                        NewStopBus(event: event, showTime: showTime)
                                            .foregroundStyle(determineColor(for: event))
                                            .padding(.vertical, 0)
                                    )
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 5)
                            }
                            //                            .onLongPressGesture {
                            //                                showingPicker = true
                            //                            }
                            //                            .popover(isPresented: $showingPicker) {
                            //                                NumberPickerView(selectedNumber: $selectedNumber)
                            //                                    .presentationCompactAdaptation(.popover)
                            //                            }
                            .if(!compareDateString(with: event.estimatedTime)) { view in
                                view.contextMenu {
                                    Button(action: {
                                        scheduleBusNotifications(for: event, stopID: "\(stop.codedidoc)", timeDelay: 0.0, lineManager: lineManager)
                                    }) {
                                        Text("Prévenir à l'arrivée")
                                    }
                                    Button(action: {
                                        scheduleBusNotifications(for: event, stopID: "\(stop.codedidoc)", timeDelay: 1.0, lineManager: lineManager)
                                    }) {
                                        Text("Prévenir 1' avant")
                                    }
                                    Button(action: {
                                        scheduleBusNotifications(for: event, stopID: "\(stop.codedidoc)", timeDelay: 5.0, lineManager: lineManager)
                                    }) {
                                        Text("Prévenir 5' avant")
                                    }
                                    Button(action: {
                                        scheduleBusNotifications(for: event, stopID: "\(stop.codedidoc)", timeDelay: 10.0, lineManager: lineManager)
                                    }) {
                                        Text("Prévenir 10' avant")
                                    }
                                    Button(action: {
                                        scheduleBusNotifications(for: event, stopID: "\(stop.codedidoc)", timeDelay: 30.0, lineManager: lineManager)
                                    }) {
                                        Text("Prévenir 30' avant")
                                    }
                                }
                            }
                        }
                        Button(action: {
                            timeRequest = Date()
                            adjustTime(byAdding: 15)
                            getStopEvents(for: stop)
                        }) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.color1)
                                .frame(width: 350, height: 50)
                                .shadow(color: Color.customShadows, radius: 3)
                                .overlay(
                                    Text("Départs suivants")
                                )
                                .padding(.vertical, 3)
                                .padding(.horizontal, 20)
                        }
                        //.background(Color.color1)
                        Spacer(minLength: 75)
                    }
                    .frame(width: geometry.size.width - 50)
                    .refreshable {
                        timeRequest = Date()
                        getStopEvents(for: stop)
                    }
                }
                VStack {
                    VStack {
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    useLeadingToTrailing = true
                                    viewStateStack.pop()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.backward")
                                    if ((previousLineName?.isEmpty) != nil) {
                                        Text("ligne \(previousLineName!)")
                                    } else {
                                        Text("Accueil")
                                    }
                                }
                            }
                            Spacer()
                            Button(action: {
                                self.isShowingPopover = true
                            }) {
                                Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                            }
                            .popover(isPresented: $isShowingPopover) {
                                VStack {
                                    Button(action: {
                                        let newViewModel = ItineraryViewModel()
                                        print(stop.nomarret)
                                        newViewModel.departureStop = stop  // Set the desired stop here
                                        newViewModel.departureSearchText = stop.nomarret
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            useLeadingToTrailing = false
                                            viewStateStack.push(.trip(viewModel: newViewModel, firstSelected: false))
                                        }
                                    }) {
                                        Text("Partir d'ici")
                                    }
                                    Rectangle()
                                        .frame(width: 100, height: 1)
                                        .foregroundStyle(.gray)
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            let newViewModel = ItineraryViewModel()
                                            print(stop.nomarret)
                                            newViewModel.arrivalStop = stop  // Set the desired stop here
                                            newViewModel.arrivalSearchText = stop.nomarret
                                            useLeadingToTrailing = false
                                            viewStateStack.push(.trip(viewModel: newViewModel, firstSelected: true))
                                        }
                                    }) {
                                        Text("Aller ici")
                                    }
                                }
                                .presentationCompactAdaptation(.popover)
                                .padding()
                            }
                            Button(action: {
                                showTime.toggle()
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
                            }
                        }
                        .frame(width: 350)
                        HStack {
                            Text(stop.nomarret)
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
                    .background {
                        RoundedRectangle(cornerRadius: 45.0)
                            .frame(width: 395, height: 180)
                            .foregroundStyle(.color1)
                            .shadow(color: Color.customShadows, radius: 10)
                            .ignoresSafeArea(edges: .top)
                    }
                    Spacer()
                }
                .onAppear {
                    timeRequest = Date()
                    getStopEvents(for: stop)
                    timer = Timer.publish(every: 30, on: .main, in: .common)
                        .autoconnect()
                        .sink { _ in
                            timeRequest = Date()
                            getStopEvents(for: stop)
                        }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    timeRequest = Date()
                    getStopEvents(for: stop)
                    timer = Timer.publish(every: 30, on: .main, in: .common)
                        .autoconnect()
                        .sink { _ in
                            timeRequest = Date()
                            getStopEvents(for: stop)
                        }
                }
                .onDisappear {
                    timer?.cancel()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    timer?.cancel()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        if value.startLocation.x < 20 && value.translation.width > 50 {
                            // Edge swipe detected
                            withAnimation(.easeInOut(duration: 0.3)) {
                                useLeadingToTrailing = true
                                viewStateStack.pop()
                            }
                        }
                    }
            )
            //        .transition(.truSlide)
        }
    }

    private func toggleFavorite() {
        if favoritesViewModel.isFavorite(stop) {
            favoritesViewModel.removeFavoriteStop(stop)
        } else {
            favoritesViewModel.addFavorite(stop)
        }
        print(favoritesViewModel.favoriteStops)
    }
    
    private func getStopEvents (for stop: Stop) {
        
        stopManager.selectStop(stop, stopEventNumber: 30, timeRequest: timeRequest) {
                    stopEvents = self.stopManager.stopEvents
        }
    }
    private func adjustTime(byAdding minutes: Int) {
        if let newTimeRequest = Calendar.current.date(byAdding: .minute, value: minutes, to: timeRequest) {
            timeRequest = newTimeRequest
        } else {
            print("Failed to modify the date.")
        }
    }
    func determineColor(for event: StopEvent) -> Color {
        if event.journeyRef == previousLineRef {
            return Color.accentColor
        } else if compareDateString(with: event.estimatedTime) {
            return Color.gray
        } else {
            return Color.primary
        }
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct NumberPickerView: View {
    @Binding var selectedNumber: Int
    let numbers = Array(0...100) // Example range of numbers

    var body: some View {
        VStack {
            Text("Select a Number")
                .font(.headline)

            Picker("Select a Number", selection: $selectedNumber) {
                ForEach(numbers, id: \.self) { number in
                    Text("\(number) min")
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 200) // Adjust the height as needed

            Button("Done") {
                // Close the picker view
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .padding()
        }
        .padding()
    }
}

struct NewStopView: View {
    var body: some View {
        Spacer()
        RoundedRectangle(cornerRadius: 25.0)
            .frame(width: 360, height: 600)
            .foregroundStyle(.color1)
            .shadow(color: Color.customShadows, radius: 10)
    }
}

struct StopView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return ContentView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

//struct StopView_Previews: PreviewProvider {
//    static var previews: some View {
//        let stopStore = StopStore()
//        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)
//
//        return AppTabBarView()
//            .environmentObject(stopStore)
//            .environmentObject(favoritesViewModel)
//    }
//}

//
//  TripView.swift
//  TPG4
//
//  Created by Loris Thomas on 30.06.2024.
//

import SwiftUI



class ItineraryViewModel: ObservableObject {
   private var stopStore = StopStore()
    
    @Published var departureStop: Stop?
    @Published var arrivalStop: Stop?
    @Published var invertStop: Stop?
    @Published var selectedTime = Date()
    @Published var isDepartureTime = true
    @Published var stops: [Stop] = []
    @Published var departureSearchText = "" {
        didSet {
            searchDepartureStops()
        }
    }
    @Published var arrivalSearchText = "" {
        didSet {
            searchArrivalStops()
        }
    }
    
    init(stopStore: StopStore = StopStore()) {
            self.stopStore = stopStore
        }
    
    @Published var filteredDepartureStops: [Stop] = []
    @Published var filteredArrivalStops: [Stop] = []
    
    // Function to search stops in the database
    private func searchDepartureStops() {
        let filteredStops = departureSearchText.isEmpty ? stopStore.activeStops : stopStore.activeStops.filter { $0.nomarret.localizedCaseInsensitiveContains(departureSearchText) }
            
            // Sort alphabetically by `nomarret` and update `stops`
            filteredDepartureStops = filteredStops.sorted { $0.nomarret < $1.nomarret }
        }
    private func searchArrivalStops() {
        let filteredStops = arrivalSearchText.isEmpty ? stopStore.activeStops : stopStore.activeStops.filter { $0.nomarret.localizedCaseInsensitiveContains(arrivalSearchText) }
            
            // Sort alphabetically by `nomarret` and update `stops`
        filteredArrivalStops = filteredStops.sorted { $0.nomarret < $1.nomarret }
        }

    func invertStops() {
        invertStop = departureStop
        departureStop = arrivalStop
        arrivalStop = invertStop
        departureSearchText = departureStop?.nomarret ?? ""
        arrivalSearchText = arrivalStop?.nomarret ?? ""
    }
}

struct TripElementView: View {
    var event: TripEvent
    var showTime: Bool = true
    var body: some View {
        VStack(alignment: .center) {
            HStack {
                //Spacer()
                if displayTimeOrMinutesRemaining(for: event.startTime, estimatedInput: event.startTime, with: showTime)  == "0" { transportIcon(with: event.legs.first?.transportTypeName ?? "Bus")
                } else { Text("\(displayTimeOrMinutesRemaining(for: event.startTime, estimatedInput: event.startTime, with: showTime))")
                    .frame(width:50)}
                Spacer()
                HStack {
                    Spacer()
                    ForEach(event.legs, id: \.id) { leg in
                        if !(leg.publishedLineName == "") {
                            BusLineIcon(lineName: leg.publishedLineName)
                                .padding(.horizontal, 3)
                        } /*else {Image(systemName: "figure.walk")}
                           if !leg.transferDuration.isEmpty {
                           Text("\(leg.transferDuration.dropFirst(2).dropLast(1))'")
                           }*/
                        //Spacer()
                    }
                    Spacer()
                }
                .frame(width: 180)
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                Spacer()
                if displayTimeOrMinutesRemaining(for: event.endTime, estimatedInput: event.endTime, with: showTime)  == "0" { transportIcon(with: event.legs.last?.transportTypeName ?? "Bus")
                } else { Text("\(displayTimeOrMinutesRemaining(for: event.endTime, estimatedInput: event.endTime, with: showTime))").frame(width:50) }
                //Spacer()
            }
            .padding(.horizontal)
            
            HStack {
                Image(systemName: "arrowshape.bounce.forward")
                Text(": \(event.transfers)")
                    .padding(.trailing)
                Image(systemName: "timer")
                if event.duration.count == 7 {
                    Text(": \(event.duration.dropFirst(2).dropLast(1))")
                } else {
                    Text(": \(event.duration.dropFirst(2).dropLast(1))'")
                }
            }
        }
        .padding(.horizontal)
    }
}

struct TripView: View {
    @StateObject private var tripManager = TripManager()
    @ObservedObject var viewModel: ItineraryViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @StateObject private var stopStore = StopStore()
    
    @Binding var firstSelected: Bool
    @FocusState private var firstIsFocused: Bool
    @FocusState private var secondIsFocused: Bool
    @State private var tripDone: Bool = false
    
    @State private var showTime = true
    @ObservedObject var viewStateStack: ViewStateStack
    @Binding var useLeadingToTrailing: Bool
    
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
            ZStack {
                    VStack {
                        Spacer(minLength: 280)
                        if ((firstIsFocused || firstSelected) && viewModel.departureSearchText == "") || ((secondIsFocused || !firstSelected) &&  viewModel.arrivalSearchText == "") || (viewModel.departureSearchText == viewModel.departureStop?.nomarret && firstIsFocused) || ( viewModel.arrivalSearchText == viewModel.arrivalStop?.nomarret && secondIsFocused) {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 10) {
                                //Spacer(minLength: 30)
                               // Spacer(minLength: 30)
                                ForEach(favoritesViewModel.fullFavorites, id: \.self) { stop in
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.color1)
                                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                                        .shadow(color: Color.customShadows, radius: 4)
                                        .overlay(
                                            Text(stop.nomarret)
                                                .font(.headline)
                                                .foregroundColor(Color.primary)
                                                .onTapGesture {
                                                    if firstSelected {
                                                        viewModel.departureStop = stop
                                                        viewModel.departureSearchText = stop.nomarret
                                                        firstSelected = false
                                                    } else {
                                                        viewModel.arrivalStop = stop
                                                        viewModel.arrivalSearchText = stop.nomarret
                                                        firstSelected = true
                                                    }
                                                }
                                        )
                                }
                            }
                            .padding(30)
                        }
                        .scrollDismissesKeyboard(.immediately)
                    } else if (viewModel.departureSearchText != viewModel.departureStop?.nomarret && firstSelected) || ( viewModel.arrivalSearchText != viewModel.arrivalStop?.nomarret && !firstSelected) {
                        ScrollView {
                            LazyVStack {
                                Spacer(minLength: 20)
                                if firstSelected {
                                    ForEach(viewModel.filteredDepartureStops) { stop in
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(.color1)
                                            .frame(height: 44)
                                            .shadow(color: Color.customShadows, radius: 4)
                                            .overlay(
                                                Text(stop.nomarret)
                                                    .font(.headline)
                                                    .foregroundColor(Color.primary)
                                                    .frame(width: 130)
                                                    .minimumScaleFactor(0.5)
                                                    .onTapGesture {
                                                        viewModel.departureStop = stop
                                                        viewModel.departureSearchText = stop.nomarret
                                                        firstSelected = false
                                                    }
                                            )
                                            .padding(.horizontal, 30)
                                    }
                                } else {
                                    ForEach(viewModel.filteredArrivalStops) { stop in
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(.color1)
                                            .frame(height: 44)
                                            .shadow(color: Color.customShadows, radius: 4)
                                            .overlay(
                                                Text(stop.nomarret)
                                                    .font(.headline)
                                                    .foregroundColor(Color.primary)
                                                    .onTapGesture {
                                                        viewModel.arrivalStop = stop
                                                        viewModel.arrivalSearchText = stop.nomarret
                                                        firstSelected = true
                                                    }
                                            )
                                            .padding(.horizontal, 30)
                                    }
                                }
                            }
                            .padding()
                        }
                        .scrollDismissesKeyboard(.immediately)
                    } else if /*tripDone && */!(firstIsFocused || secondIsFocused) {
                        ScrollView {
                            LazyVStack {
                                Spacer(minLength: 30)
                                ForEach(tripManager.tripEvents, id: \.id) { event in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            useLeadingToTrailing = false
                                            viewStateStack.push(.fullTrip(fullTrip: event, departureStop: viewModel.departureStop!, arrivalStop: viewModel.arrivalStop!))
                                            //FullTripView(fullTrip: event)
                                        }
                                    }) {
                                        RoundedRectangle(cornerRadius: 30)
                                            .fill(.color1)
                                            .padding(.horizontal, 30)
                                            .frame(height: 80)
                                            .shadow(color: Color.customShadows, radius: 4)
                                            .overlay(
                                                TripElementView(event: event, showTime: showTime)
                                                    .padding(.horizontal)
                                            )
                                            
                                    }
                                    .foregroundStyle(.primary)
                                }
                                Spacer(minLength: 60)
                            }
                        }
                        .scrollDismissesKeyboard(.immediately)
                    }
                }
                
                VStack {
                    HStack {
                        Text("Itinéraire")
                            .font(.title)
                            .bold()
                            .padding(.leading, 15)
                            .frame(height: 20.0)
                        Spacer()
                        Button(action: {
                            self.showTime.toggle()
                            }) {
                            Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill")
                                .font(.title)
                                .padding(.trailing)
                        }
                    }
                    .padding(.bottom, 5)

                    RoundedRectangle(cornerRadius: 35.0)
                        .foregroundStyle(Color.color1)
                        .shadow(color: Color.customShadows, radius: 10)
                        .frame(height: 250)
                        .overlay(
                            VStack {
                                HStack {
                                    VStack {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .shadow(color: Color.customShadows, radius: 4)
                                                .frame(width: 280, height: 40)
                                                .foregroundStyle(.color1)
                                                .overlay(
                                                    TextField("départ", text: $viewModel.departureSearchText)
                                                        .focused($firstIsFocused)
                                                        .foregroundStyle(.primary)
                                                        .padding(.leading)
                                                        .overlay(
                                                          Button(action: {
                                                                 viewModel.departureSearchText = ""
                                                                firstSelected = true
                                                                 firstIsFocused = true
                                                                  secondIsFocused = false
                                                                }) {
                                                                 Image(systemName: "xmark.circle.fill")
                                                                 .opacity(viewModel.departureSearchText .isEmpty ? 0 : 1).padding()
                                                             }
                                                              .padding(),
                                                               alignment: .trailing
                                                              )
                                                        .onTapGesture(perform: {
                                                            firstSelected = true
                                                            firstIsFocused = true
                                                            secondIsFocused = false
                                                        })
                                                )
                                                .frame(width: 280)
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .stroke(firstSelected ? Color.accentColor : .clear, lineWidth: 1)
                                                .frame(width: 280, height: 40)
                                        }
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .frame(width: 280, height: 40)
                                                .foregroundStyle(.color1)
                                                .shadow(color: Color.customShadows, radius: 4)
                                                .overlay(
                                                    TextField("arrivée", text: $viewModel.arrivalSearchText)
                                                        .focused($secondIsFocused)
                                                        .padding(.leading)
                                                        .overlay(
                                                                            Button(action: {
                                                                                viewModel.arrivalSearchText = ""
                                                                                firstSelected = false
                                                                                firstIsFocused = false
                                                                                secondIsFocused = true
                                                                            }) {
                                                                                Image(systemName: "xmark.circle.fill")
                                                                                    .opacity(viewModel.arrivalSearchText .isEmpty ? 0 : 1).padding()
                                                                            }
                                                                            .padding(),
                                                                            alignment: .trailing
                                                                        )
                                                        .onTapGesture(perform: {
                                                            firstSelected = false
                                                            firstIsFocused = false
                                                            secondIsFocused = true
                                                        })
                                                )
                                                .frame(width: 280)
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .stroke(!firstSelected ? Color.accentColor : .clear, lineWidth: 1)
                                                .frame(width: 280, height: 40)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        viewModel.invertStops()
                                    } label: {
                                        Image(systemName: "arrow.triangle.swap")
                                            .font(.title)
                                    }
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal)
                                
                                DatePicker("Date et heure:", selection: $viewModel.selectedTime)
                                    .padding(.horizontal)
                                    .padding(.vertical, 5)
                                HStack {
                                    Picker("Time Type", selection: $viewModel.isDepartureTime) {
                                        Text("Départ").tag(true)
                                        Text("Arrivée").tag(false)
                                    }
                                    .pickerStyle(.segmented)
//                                    .frame(height: 40)
                                    //.padding(.horizontal)
                                    Button("Rechercher") {
                                        if viewModel.departureStop != nil && viewModel.arrivalStop != nil {
                                            tripManager.selectTrip(with: viewModel.departureStop!, with: viewModel.arrivalStop!, with: viewModel.selectedTime, with: viewModel.isDepartureTime)
                                            tripDone = true
                                            firstIsFocused = false
                                            secondIsFocused = false
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .onAppear(perform: {
                                        if viewModel.departureStop != nil && viewModel.arrivalStop != nil {
                                            tripManager.selectTrip(with: viewModel.departureStop!, with: viewModel.arrivalStop!, with: viewModel.selectedTime, with: viewModel.isDepartureTime)
                                            tripDone = true
                                            firstIsFocused = false
                                            secondIsFocused = false
                                        }
                                    })
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal)
                            })
                        .padding(.horizontal)
                    Spacer()
                }
            }
//        .transition(.truSlide)
    }
}
//extension UISegmentedControl {
//    override open func didMoveToSuperview() {
//        super.didMoveToSuperview()
//        self.setContentHuggingPriority(.defaultLow, for: .vertical)  // << here !!
//    }
//}

struct FullTripView: View {
    var fullTrip: TripEvent
    var departureStop: Stop
    var arrivalStop: Stop
    @ObservedObject var viewStateStack: ViewStateStack
    @StateObject private var lineManager = LineManager()
    @State private var showTime = true
    @Binding var useLeadingToTrailing: Bool

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                Spacer(minLength: 130)
                ScrollView {
                    Spacer(minLength: 30)
                    if fullTrip.legs.first?.transfer ?? false {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                useLeadingToTrailing = false
                                viewStateStack.push(.stop(stop: departureStop, previousLineRef: "", previousLineName: ""))
                            }
                        }) {
                            RoundedRectangle(cornerRadius: 25.0)
                                .frame(width: 330, height: 45)
                                .foregroundStyle(.color1)
                                .shadow(color: Color.customShadows, radius: 4)
                                .padding(.horizontal)
//                                .padding(.vertical, 4)
                                .overlay (
                                    HStack {
                                        Circle()
                                            .strokeBorder(.primary, lineWidth: 5)
                                            .background(Circle().fill(.color1))
                                            .frame(width: 18, height: 18)
                                        Text(departureStop.nomarret)
                                        Spacer()
                                    }
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 0)
                                )
                                .onAppear {
                                    print("\(fullTrip.legs.first?.legBoardStopId ?? "") != \(arrivalStop.codedidoc)") }
                        }
                        .foregroundStyle(.primary)
                    }
                    ForEach(fullTrip.legs) { leg in
                        if !leg.publishedLineName.isEmpty {
                            ZStack {
                                VStack {
                                    Spacer(minLength: 45)
                                    HStack {
                                        Rectangle()
                                            .frame(width: 7, height: 60)
                                            .foregroundStyle(LineColors.lineColor(for: leg.publishedLineName))
                                            .padding(.trailing, 285)
                                    }
                                    Spacer(minLength: 45)
                                }
                                VStack {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            useLeadingToTrailing = false
                                            viewStateStack.push(.stop(stop: stopFromId(by: leg.legBoardStopId)!, previousLineRef: leg.journeyRef, previousLineName: nil))
                                        }
                                    }) {
                                        RoundedRectangle(cornerRadius: 25.0)
                                            .frame(width: 330, height: 45)
                                            .foregroundStyle(.color1)
                                            .shadow(color: Color.customShadows, radius: 4)
                                            .padding(.horizontal)
                                            .padding(.vertical, 4)
                                            .overlay (
                                                HStack {
                                                    Circle()
                                                        .strokeBorder(.primary, lineWidth: 5)
                                                        .background(Circle().fill(LineColors.lineColor(for: leg.publishedLineName)))
                                                        .frame(width: 18, height: 18)
                                                    Text(leg.legBoardStopName)
                                                    Spacer()
                                                    if displayTimeOrMinutesRemaining(for: leg.legBoardTimetableTime, estimatedInput: leg.legBoardEstimatedTime, with: showTime) == "0" {
                                                        transportIcon(with: leg.transportTypeName)
                                                    } else {
                                                        Text("\(displayTimeOrMinutesRemaining(for: leg.legBoardTimetableTime, estimatedInput: leg.legBoardEstimatedTime, with: showTime))")
                                                            .frame(width: 50)
                                                    }
                                                    Image(systemName: "\(leg.legBoardQuay).square.fill".lowercased())
                                                }
                                                .padding(.horizontal, 30)
                                                .padding(.vertical, 0)
                                            )
                                    }
                                        .foregroundStyle(.primary)
                                        .contextMenu {
                                            let stopBoardEvent = createEssentialStopEvent(journeyRef: leg.journeyRef, operatingDayRef: "\(leg.legBoardTimetableTime.dropLast(10))", stopPointName: leg.legBoardStopName, lineName: leg.publishedLineName, origin: "", destination: leg.legDestination, transportType: leg.transportTypeName)
                                            
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopBoardEvent, stopID: "\(leg.legBoardStopId)", timeDelay: 0.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir à l'arrivée")
                                                }
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopBoardEvent, stopID: "\(leg.legBoardStopId)", timeDelay: 1.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir 1' avant")
                                                }
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopBoardEvent, stopID: "\(leg.legBoardStopId)", timeDelay: 5.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir 5' avant")
                                                }
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopBoardEvent, stopID: "\(leg.legBoardStopId)", timeDelay: 10.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir 10' avant")
                                                }
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopBoardEvent, stopID: "\(leg.legBoardStopId)", timeDelay: 30.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir 30' avant")
                                                }
                                        }
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            useLeadingToTrailing = false
                                            viewStateStack.push(.line(stopEvent: createStopEventFromTripLeg(tripLeg: leg), currentStop: nil, currentLine: leg.publishedLineName))
                                        }
                                    }) {
                                        HStack {
                                            BusLineIcon(lineName: leg.publishedLineName)
                                            Image(systemName: "arrow.right")
                                            Text(leg.legDestination)
                                            Spacer()
                                        }
                                        .frame(width: 300, height: 30)
                                        .padding(.leading, 50)
                                    }
                                        .foregroundStyle(.primary)
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            useLeadingToTrailing = false
                                            viewStateStack.push(.stop(stop: stopFromId(by: leg.legBoardStopId)!, previousLineRef: leg.journeyRef, previousLineName: nil))
                                        }
                                    }) {
                                        RoundedRectangle(cornerRadius: 25.0)
                                            .frame(width: 330, height: 45)
                                            .foregroundStyle(.color1)
                                            .padding(.horizontal)
                                            .padding(.vertical, 4)
                                            .shadow(color: Color.customShadows, radius: 4)
                                            .overlay (
                                                HStack {
                                                    Circle()
                                                        .strokeBorder(.primary, lineWidth: 5)
                                                        .background(Circle().fill(LineColors.lineColor(for: leg.publishedLineName)))
                                                        .frame(width: 18, height: 18)
                                                    Text(leg.legAlightStopName)
                                                    Spacer()
                                                    if displayTimeOrMinutesRemaining(for: leg.legAlightTimetableTime, estimatedInput: leg.legAlightEstimatedTime, with: showTime) == "0" {
                                                        transportIcon(with: leg.transportTypeName)
                                                    } else {
                                                        Text("\(displayTimeOrMinutesRemaining(for: leg.legAlightTimetableTime, estimatedInput: leg.legAlightEstimatedTime, with: showTime))")
                                                            .frame(width: 50)
                                                    }
                                                    Image(systemName: "\(leg.legAlightQuay).square.fill".lowercased())
                                                }
                                                .padding(.horizontal, 30)
                                                .padding(.vertical, 0)
                                            )
                                    }
                                        .foregroundStyle(.primary)
                                        .contextMenu {
                                            let stopAlightEvent = createEssentialStopEvent(journeyRef: leg.journeyRef, operatingDayRef: "\(leg.legAlightTimetableTime.dropLast(10))", stopPointName: leg.legAlightStopName, lineName: leg.publishedLineName, origin: "", destination: leg.legDestination, transportType: leg.transportTypeName)
                                            
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopAlightEvent, stopID: "\(leg.legAlightStopId)", timeDelay: 0.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir à l'arrivée")
                                                }
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopAlightEvent, stopID: "\(leg.legAlightStopId)", timeDelay: 1.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir 1' avant")
                                                }
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopAlightEvent, stopID: "\(leg.legAlightStopId)", timeDelay: 5.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir 5' avant")
                                                }
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopAlightEvent, stopID: "\(leg.legAlightStopId)", timeDelay: 10.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir 10' avant")
                                                }
                                                Button(action: {
                                                    scheduleBusNotifications(for: stopAlightEvent, stopID: "\(leg.legAlightStopId)", timeDelay: 30.0, lineManager: lineManager)
                                                }) {
                                                    Text("Prévenir 30' avant")
                                                }
                                        }
                                }
                            }
                        } else {
                            HStack {
                                if !leg.transferDuration.isEmpty {
                                    Image(systemName: "timer")
                                        .padding(.leading, 124)
                                    Text("\(leg.transferDuration.dropFirst(2).dropLast(1))'")
                                        .padding(.trailing, 30)
                                    Image(systemName: "figure.walk")
                                    Text("\(leg.transferWalkDuration.dropFirst(2).dropLast(1))'")
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    if fullTrip.legs.last?.transfer ?? false {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                useLeadingToTrailing = false
                                viewStateStack.push(.stop(stop: arrivalStop, previousLineRef: "", previousLineName: ""))
                            }
                        }) {
                            RoundedRectangle(cornerRadius: 25.0)
                                .frame(width: 330, height: 45)
                                .foregroundStyle(.color1)
                                .shadow(color: Color.customShadows, radius: 4)
                                .padding(.horizontal)
//                                .padding(.vertical, 4)
                                .overlay (
                                    HStack {
                                        Circle()
                                            .strokeBorder(.primary, lineWidth: 5)
                                            .background(Circle().fill(.color1))
                                            .frame(width: 18, height: 18)
                                        Text(arrivalStop.nomarret)
                                        Spacer()
                                    }
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 0)
                                )
                                .onAppear {
                                    print("\(fullTrip.legs.last?.legAlightStopId ?? "") != \(arrivalStop.codedidoc)") }
                        }
                        .foregroundStyle(.primary)
                    }
                    Rectangle()
                        .frame(height: 70)
                        .foregroundStyle(.clear)
//                    .background(Color.color1)
                }
                .onAppear {
                    UINavigationBar.setTransparentAppearance()
                }
            }
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
                            Text("Itinéraire")
                        }
                    }
                    Spacer()
                    Button(action: {
                        self.showTime.toggle()
                    }) {
                        Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill")
                            .font(.title)
                    }
                }
                .frame(width: 350)
                HStack {
                    RoundedRectangle(cornerRadius: 35)
                        .frame(width: 450, height: 90)
                        .foregroundStyle(.color1)
                        .shadow(color: Color.customShadows, radius: 10)
                        .padding(.leading, 100)
                        .overlay(
                            VStack {
                                Text(departureStop.nomarret)
                                    .font(.title3)
                                    .bold()
                                Image(systemName: "arrow.down")
                                Text(arrivalStop.nomarret)
                                    .font(.title3)
                                    .bold()
                            }
                        )
                }
                Spacer()
            }
        }
    }
}



struct TripView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return ContentView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

//
//  TripView.swift
//  TPG4
//
//  Created by Loris Thomas on 30.06.2024.
//

import SwiftUI

class ItineraryViewModel: ObservableObject {
    @StateObject private var stopStore = StopStore()
    
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
                if displayTimeOrMinutesRemaining(for: event.startTime, estimatedInput: event.startTime, with: showTime)  == "0" { Image(systemName: "bus.fill")
                } else { Text("\(displayTimeOrMinutesRemaining(for: event.startTime, estimatedInput: event.startTime, with: showTime))")
                    .frame(width:50)}
                Spacer()
                Spacer()
                ForEach(event.legs, id: \.id) { leg in
                    if !(leg.publishedLineName == "") {
                        BusLineIcon(lineName: leg.publishedLineName)
                            .padding(.horizontal, 5)
                    } /*else {Image(systemName: "figure.walk")}
                    if !leg.transferDuration.isEmpty {
                        Text("\(leg.transferDuration.dropFirst(2).dropLast(1))'")
                    }*/
                    //Spacer()
                }
                Spacer()
                Spacer()
                if displayTimeOrMinutesRemaining(for: event.endTime, estimatedInput: event.endTime, with: showTime)  == "0" { Image(systemName: "bus.fill")
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
    @StateObject private var viewModel = ItineraryViewModel()
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @StateObject private var stopStore = StopStore()
    
    @State private var firstSelected: Bool = true
    @FocusState private var firstIsFocused: Bool
    @FocusState private var secondIsFocused: Bool
    @State private var tripDone: Bool = false
    
    @State private var showTime = true

    
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        NavigationStack {
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
                                        .shadow(radius: 4)
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
                    } else if /*!tripDone*/ firstIsFocused || secondIsFocused {
                        ScrollView {
                            LazyVStack {
                                Spacer(minLength: 20)
                                if firstSelected {
                                    ForEach(viewModel.filteredDepartureStops) { stop in
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(.color1)
                                            .frame(height: 44)
                                            .shadow(radius: 4)
                                            .overlay(
                                                Text(stop.nomarret)
                                                    .font(.headline)
                                                    .foregroundColor(Color.primary)
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
                                            .shadow(radius: 4)
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
                    } else if /*tripDone && */!(firstIsFocused || secondIsFocused) {
                        ScrollView {
                            LazyVStack {
                                Spacer(minLength: 30)
                                ForEach(tripManager.tripEvents, id: \.id) { event in
                                    NavigationLink {
                                        FullTripView(fullTrip: event)
                                    } label: {
                                        RoundedRectangle(cornerRadius: 30)
                                            .fill(.color1)
                                            .padding(.horizontal, 30)
                                            .frame(height: 80)
                                            .shadow(radius: 4)
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
                        .shadow(radius: 10)
                        .frame(height: 250)
                        .overlay(
                            VStack {
                                HStack {
                                    VStack {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .shadow(radius: 4)
                                                .frame(width: 270, height: 40)
                                                .foregroundStyle(.color1)
                                                .overlay(
                                                    TextField("départ", text: $viewModel.departureSearchText)
                                                        .focused($firstIsFocused)
                                                        .foregroundStyle(.primary)
                                                        .padding(.leading)
                                                        .onTapGesture(perform: {
                                                            firstSelected = true
                                                            firstIsFocused = true
                                                            secondIsFocused = false
                                                        })
                                                )
                                                .frame(width: 270)
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .stroke(firstSelected ? Color.accentColor : .clear, lineWidth: 1)
                                                .frame(width: 270, height: 40)
                                        }
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .frame(width: 270, height: 40)
                                                .foregroundStyle(.color1)
                                                .shadow(radius: 4)
                                                .overlay(
                                                    TextField("arrivée", text: $viewModel.arrivalSearchText)
                                                        .focused($secondIsFocused)
                                                        .padding(.leading)
                                                        .onTapGesture(perform: {
                                                            firstSelected = false
                                                            firstIsFocused = false
                                                            secondIsFocused = true
                                                        })
                                                )
                                                .frame(width: 270)
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .stroke(!firstSelected ? Color.accentColor : .clear, lineWidth: 1)
                                                .frame(width: 270, height: 40)
                                        }
                                    }
                                    Button {
                                        viewModel.invertStops()
                                    } label: {
                                        Image(systemName: "arrow.triangle.swap")
                                            .font(.title)
                                    }
                                }
                                .padding(.vertical, 5)
                                
                                DatePicker("Date et heure:", selection: $viewModel.selectedTime)
                                    .padding(.horizontal)
                                    .padding(.vertical, 5)
                                HStack {
                                    Picker("Time Type", selection: $viewModel.isDepartureTime) {
                                        Text("Heure de départ").tag(true)
                                        Text("Heure d'arrivée").tag(false)
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    //.padding(.horizontal)
                                    Button("Rechercher") {
                                        if viewModel.departureStop != nil && viewModel.arrivalStop != nil {
                                            tripManager.selectTrip(with: viewModel.departureStop!, with: viewModel.arrivalStop!, with: viewModel.selectedTime, with: viewModel.isDepartureTime)
                                            tripDone = true
                                            firstIsFocused = false
                                            secondIsFocused = false
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal)
                            })
                        .padding(.horizontal)
                    Spacer()
                }
            }
        }
    }
}

struct FullTripView: View {
    var fullTrip: TripEvent
    @State private var showTime = true
    
    var body: some View {
            ZStack {
                VStack(alignment: .leading) {
                    Spacer(minLength: 40)
                    ScrollView {
                        NavigationStack {
                        Spacer(minLength: 80)
                        //Spacer(minLength: 90)
                        ForEach(fullTrip.legs, id: \.id) { leg in
                            if !(leg.publishedLineName.isEmpty) {
                                ZStack {
                                    VStack {
                                        Spacer(minLength: 45)
                                        HStack {
                                            //Spacer(minLength: 5)
                                            Rectangle()
                                                .frame(width: 7, height: 60)
                                                .foregroundStyle(LineColors.lineColor(for: leg.publishedLineName))
                                                .padding(.trailing, 285)
                                            //Spacer(minLength: 300)
                                        }
                                        Spacer(minLength: 45)
                                    }
                                    VStack {
//                                        NavigationLink(destination: NewStopViewTest(stop: stopFromId(by: leg.legBoardStopId), previousLineRef: leg.journeyRef)
//                                        ) {
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .frame(width: 330, height: 45)
                                                .foregroundStyle(.color1)
                                                .shadow(radius: 4)
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
                                                        if displayTimeOrMinutesRemaining(for: leg.legBoardTimetableTime, estimatedInput: leg.legBoardEstimatedTime, with: showTime)  == "0" { Image(systemName: "bus.fill")
                                                        } else { Text("\(displayTimeOrMinutesRemaining(for: leg.legBoardTimetableTime, estimatedInput: leg.legBoardEstimatedTime, with: showTime))")
                                                            .frame(width:50)}
                                                        Image(systemName: "\(leg.legBoardQuay).square.fill".lowercased())
                                                    }
                                                        .padding(.horizontal, 30)
                                                        .padding(.vertical, 0)
                                                )
//                                        }
                                            //BusLineIcon(lineName: leg.publishedLineName)
                                               // .padding(.trailing, 200)
//                                                    NavigationLink(destination: NewLineView(stopEvent: createStopEventFromTripLeg(tripLeg: leg), currentLine: leg.publishedLineName)
//                                                    ){
                                                            HStack {
                                                                BusLineIcon(lineName: leg.publishedLineName)
                                                                Image(systemName: "arrow.right")
                                                                Text(leg.legDestination)
                                                                Spacer()
                                                            }
                                                            .frame(width: 300, height: 30)
                                                            .padding(.leading, 50)
//                                                    }
                                                    .foregroundStyle(.primary)
                                        RoundedRectangle(cornerRadius: 25.0)
                                            .frame(width: 330, height: 45)
                                            .foregroundStyle(.color1)
                                            .padding(.horizontal)
                                            .padding(.vertical, 4)
                                            .shadow(radius: 4)
                                            .overlay (
                                                HStack {
                                                    Circle()
                                                        .strokeBorder(.primary, lineWidth: 5)
                                                        .background(Circle().fill(LineColors.lineColor(for: leg.publishedLineName)))
                                                        .frame(width: 18, height: 18)
                                                    Text(leg.legAlightStopName)
                                                    Spacer()
                                                    if displayTimeOrMinutesRemaining(for: leg.legAlightTimetableTime, estimatedInput: leg.legAlightEstimatedTime, with: showTime)  == "0" { Image(systemName: "bus.fill")
                                                    } else { Text("\(displayTimeOrMinutesRemaining(for: leg.legAlightTimetableTime, estimatedInput: leg.legAlightEstimatedTime, with: showTime))")
                                                        .frame(width:50)}
                                                    Image(systemName: "\(leg.legAlightQuay).square.fill".lowercased())
                                                }
                                                    .padding(.horizontal, 30)
                                                    .padding(.vertical, 0)
                                            )
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
                                //.frame(height: 50)
                            }
                        }
                        //.padding(.top, 10.0)
                        .background(Color.color1)
                    }
                        }
                        .onAppear {
                                       UINavigationBar.setTransparentAppearance()
                                   }
                        .toolbar {
                            Button(action: {
                                self.showTime.toggle()
                            }) {
                                Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill")
                                    .font(.title)
                            }
                        }
                }
                //.padding(.horizontal, -1.0)
                VStack {
                    HStack {
                        RoundedRectangle(cornerRadius: 35)
                            .frame(width: 450, height: 90)
                            .foregroundStyle(.color1)
                            .shadow(radius: 10)
                            .padding(.leading, 100)
                            .padding(.vertical)
                        //.ignoresSafeArea(edges: .top)
                            .overlay(
                                VStack {
                                    Text(fullTrip.legs.first!.legBoardStopName)
                                        .font(.title3)
                                        .bold()
                                    Image(systemName: "arrow.down")
                                    Text(fullTrip.legs.last!.legAlightStopName)
                                        .font(.title3)
                                        .bold()
                                }
                            )
                        //Spacer()
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

        return AppTabBarView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

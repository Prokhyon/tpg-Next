//
//  NewTripView.swift
//  TPG4
//
//  Created by Loris Thomas on 11.07.2024.
//
import SwiftUI

class NewItineraryViewModel: ObservableObject {
   private var stopStore = StopStore()
    
    @Published var departureStop: Stop?
    @Published var arrivalStop: Stop?
    @Published var invertStop: Stop?
    @Published var selectedTime = Date()
    @Published var isDepartureTime = true
    @Published var stops: [Stop] = []
//    @Published var departureSearchText = "" {
//        didSet {
//            searchDepartureStops()
//        }
//    }
//    @Published var arrivalSearchText = "" {
//        didSet {
//            searchArrivalStops()
//        }
//    }
//    
//    init(stopStore: StopStore = StopStore()) {
//            self.stopStore = stopStore
//        }
//    
//    @Published var filteredDepartureStops: [Stop] = []
//    @Published var filteredArrivalStops: [Stop] = []
//    
//    // Function to search stops in the database
//    private func searchDepartureStops() {
//        let filteredStops = departureSearchText.isEmpty ? stopStore.activeStops : stopStore.activeStops.filter { $0.nomarret.localizedCaseInsensitiveContains(departureSearchText) }
//            
//            // Sort alphabetically by `nomarret` and update `stops`
//            filteredDepartureStops = filteredStops.sorted { $0.nomarret < $1.nomarret }
//        }
//    private func searchArrivalStops() {
//        let filteredStops = arrivalSearchText.isEmpty ? stopStore.activeStops : stopStore.activeStops.filter { $0.nomarret.localizedCaseInsensitiveContains(arrivalSearchText) }
//            
//            // Sort alphabetically by `nomarret` and update `stops`
//        filteredArrivalStops = filteredStops.sorted { $0.nomarret < $1.nomarret }
//        }

//    func invertStops() {
//        invertStop = departureStop
//        departureStop = arrivalStop
//        arrivalStop = invertStop
//        departureSearchText = departureStop?.nomarret ?? ""
//        arrivalSearchText = arrivalStop?.nomarret ?? ""
//    }
}

struct NewTripView: View {
    @StateObject private var tripManager = TripManager()
    @ObservedObject var viewModel: NewItineraryViewModel
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @StateObject private var stopStore = StopStore()
    
    @Binding var firstSelected: Bool
    @FocusState private var firstIsFocused: Bool
    @FocusState private var secondIsFocused: Bool
    @State private var tripDone: Bool = false
    
    @State private var showTime = true
    @ObservedObject var viewStateStack: ViewStateStack
//    @Binding var useLeadingToTrailing: Bool
    
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
            ZStack {
                
                VStack {

                    RoundedRectangle(cornerRadius: 35.0)
                        .foregroundStyle(Color.color1)
                        .shadow(radius: 10)
                        .frame(height: 250)
                        .overlay(
                            VStack {
                                HStack {
                                    VStack {
                                        Button(action: {
                                            self.firstSelected.toggle()
                                            print(firstSelected)
                                        }) {
                                            Text("toggle")
                                        }
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .shadow(radius: 4)
                                                .frame(width: 270, height: 40)
                                                .foregroundStyle(.color1)
//                                                .overlay(
//                                                    TextField("départ", text: $viewModel.departureSearchText)
//                                                        .focused($firstIsFocused)
//                                                        .foregroundStyle(.primary)
//                                                        .padding(.leading)
//                                                        .onTapGesture(perform: {
//                                                            firstSelected = true
//                                                            firstIsFocused = true
//                                                            secondIsFocused = false
//                                                        })
//                                                )
                                                .frame(width: 270)
                                                .onTapGesture(perform: {
                                                    firstSelected = true
                                                    firstIsFocused = true
                                                    secondIsFocused = false
                                                })
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .stroke(firstSelected ? Color.accentColor : .clear, lineWidth: 1)
                                                .frame(width: 270, height: 40)
                                        }
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .frame(width: 270, height: 40)
                                                .foregroundStyle(.color1)
                                                .shadow(radius: 4)
//                                                .overlay(
//                                                    TextField("arrivée", text: $viewModel.arrivalSearchText)
//                                                        .focused($secondIsFocused)
//                                                        .padding(.leading)
//                                                        .onTapGesture(perform: {
//                                                            firstSelected = false
//                                                            firstIsFocused = false
//                                                            secondIsFocused = true
//                                                        })
//                                                )
                                                .frame(width: 270)
                                                .onTapGesture(perform: {
                                                  firstSelected = false
                                                         firstIsFocused = false
                                                 secondIsFocused = true
                                                      })
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .stroke(!firstSelected ? Color.accentColor : .clear, lineWidth: 1)
                                                .frame(width: 270, height: 40)
                                        }
                                    }
                                    Button {
//                                        viewModel.invertStops()
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
                                    .onAppear(perform: {
//                                        firstSelected = true
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

struct NewTripView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return ContentView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

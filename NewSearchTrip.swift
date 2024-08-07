//
//  NewSearchTrip.swift
//  TPG4
//
//  Created by Loris Thomas on 02.07.2024.
//

//import SwiftUI
//import Combine
//
//class ItModel: ObservableObject {
//    @Published var stops: [Stop] = []
//    @Published var activeAStops: [Stop] = []
//
//    func searchAStops(with searchText: String) {
//        let filteredStops = searchText.isEmpty ? activeAStops : activeAStops.filter { $0.nomarret.localizedCaseInsensitiveContains(searchText) }
//        
//        // Sort alphabetically by `nomarret` and update `stops`
//        stops = filteredStops.sorted { $0.nomarret < $1.nomarret }
//        print(stops)
//    }
//}
//
//struct CView: View {
//    @StateObject var viewModel = ItModel()
//    @StateObject private var stopStore = StopStore()
//    @State private var searchText = ""
//
//    var body: some View {
//        VStack {
//            TextField("Search Stops", text: $searchText)
//                .padding()
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//                .onSubmit {
//                    viewModel.searchAStops(with: searchText)
//                }
//            
//            List(viewModel.stops) { stop in
//                Text(stop.nomarret)
//            }
//        }
//        .onAppear {
//            viewModel.activeAStops = stopStore.activeStops
//        }
//    }
//}
//
//
//#Preview {
//    CView()
//}

//
//  SearchView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import Foundation
import SwiftUI

class Search: ObservableObject {
    @StateObject private var stopStore = StopStore()
    @StateObject private var stopManager = StopManager()
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @Published var searchText: String = "" {
        didSet {
            searchStops()
        }
    }
    @Published var filteredStops: [Stop] = []
    
    private func searchStops() {
        let filterStops = searchText.isEmpty ? stopStore.activeStops : stopStore.activeStops.filter { $0.nomarret.localizedCaseInsensitiveContains(searchText) }
            
            // Sort alphabetically by `nomarret` and update `stops`
            filteredStops = filterStops.sorted { $0.nomarret < $1.nomarret }
        }
}

struct SearchView: View {
    @StateObject private var stopStore = StopStore()
    @StateObject private var stopManager = StopManager()
    @State var showSearchResults = false
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @StateObject private var search = Search()
    
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    VStack {
                        ScrollView {
                            Spacer(minLength: 50)
                            ForEach(search.filteredStops) { stop in
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.color1)
                                    .frame(height: 40)
                                    .shadow(radius: 3)
                                    .overlay(
                                        Text(stop.nomarret)
                                            .font(.headline)
                                            .foregroundColor(Color.primary)
                                            .onTapGesture {
                                            }
                                    )
                                    .padding(.horizontal, 30)
                            }
                        }
                    }
                    VStack {
                        RoundedRectangle(cornerRadius: 25.0)
                            .shadow(radius: 10)
                            .frame(width: 350, height: 40)
                            .foregroundStyle(.color1)
                            .overlay(
                                TextField("Rechercher", text: $search.searchText)
                                    .foregroundStyle(.primary)
                                    .padding(.leading)
                                    .onTapGesture(perform: {
                                    })
                            )
                        Spacer()
                    }
                }
            }
           /* List(stopStore.searchStops(with: searchText)) { stop in
                NavigationLink {
                    StopView(favoritesViewModel: favoritesViewModel, stop: stop)
                } label: {
                    Text((stop.nomarret))
                        
                }
                .listRowBackground(Color.color1)
            }
            .listStyle(.plain)
            .background(.color1)
            .scrollContentBackground(.hidden)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal)
            .padding(.vertical, 10.0)
            .shadow(radius: 5)
                //.searchable(text: $stopStore.searchText)
                //.searchSuggestions(T##suggestions: () -> View##() -> View)
                .navigationTitle("Arrêts")
               */
            }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return AppTabBarView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}

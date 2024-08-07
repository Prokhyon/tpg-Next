//
//  HomeView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import SwiftUI
import CoreLocation
import Combine

import SwiftUI

struct FavoriteView: View {
    @StateObject private var stopStore = StopStore()
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @ObservedObject var viewStateStack: ViewStateStack
    @Binding var useLeadingToTrailing: Bool  // Binding to control transition direction

    @Binding var isExpanded: Bool
    @State private var draggingItem: Stop?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let maxRows = 5 // Set the maximum number of rows you want to display

    var body: some View {
        VStack {
            LazyVGrid(columns: columns, spacing: 10) {
                if favoritesViewModel.fullFavorites.count > 10 {
                    let favorites = isExpanded ? favoritesViewModel.fullFavorites : Array(favoritesViewModel.fullFavorites.prefix(maxRows * columns.count - (isExpanded ? 0 : 1)))
                    ForEach(favorites, id: \.self) { stop in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                useLeadingToTrailing = false
                                viewStateStack.push(.stop(stop: stop, previousLineRef: nil, previousLineName: nil))
                            }
                        }) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.color1)
                                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                                .shadow(color: Color.customShadows, radius: 2)
                                .overlay(
                                    Text(stop.nomarret)
                                        .font(.headline)
                                        .foregroundColor(Color.primary)
                                        .frame(width: 130)
//                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                )
                        }
                        .onDrag {
                            self.draggingItem = stop
                            return NSItemProvider(object: String(stop.codedidoc) as NSString)
                        }
                        .onDrop(of: [.text], delegate: StopDropDelegate(item: stop, current: $favoritesViewModel.fullFavorites, draggingItem: $draggingItem))
                    }
                } else {
                    let favorites = favoritesViewModel.fullFavorites
                    ForEach(favorites, id: \.self) { stop in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                useLeadingToTrailing = false
                                viewStateStack.push(.stop(stop: stop, previousLineRef: nil, previousLineName: nil))
                                
                            }
                        }) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.color1)
                                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                                .shadow(color: Color.customShadows, radius: 2)
                                .overlay(
                                    Text(stop.nomarret)
                                        .font(.headline)
                                        .foregroundColor(Color.primary)
                                        .frame(width: 130)
//                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                )
                        }
                        .onDrag {
                            self.draggingItem = stop
                            return NSItemProvider(object: String(stop.codedidoc) as NSString)
                        }
                        .onDrop(of: [.text], delegate: StopDropDelegate(item: stop, current: $favoritesViewModel.fullFavorites, draggingItem: $draggingItem))
                    }
                }

                if !isExpanded && favoritesViewModel.fullFavorites.count > 10 {
                    Button(action: {
                        withAnimation(.spring(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.color1)
                            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                            .shadow(color: Color.customShadows, radius: 2)
                            .overlay(
                                Image(systemName: "plus")
                                    .foregroundColor(Color.primary)
                                    .font(.headline)
                            )
                    }
                }

                if isExpanded && favoritesViewModel.fullFavorites.count % 2 != 0 {
                    Button(action: {
                        withAnimation(.spring(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.color1)
                            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                            .shadow(color: Color.customShadows, radius: 2)
                            .overlay(
                                Image(systemName: "minus")
                                    .foregroundColor(Color.primary)
                                    .font(.headline)
                            )
                    }
                }
            }
            .padding()
            .onAppear {
                favoritesViewModel.id2stop(favoriteStops: favoritesViewModel.favoriteStops, stopsArray: stopStore.activeStops)
            }

            if isExpanded && favoritesViewModel.fullFavorites.count % 2 == 0 {
                Button(action: {
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.color1)
                        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                        .shadow(color: Color.customShadows, radius: 2)
                        .overlay(
                            Image(systemName: "minus")
                                .foregroundColor(Color.primary)
                                .font(.headline)
                        )
                }
                .padding(.bottom)
                .padding(.horizontal)
            }
        }
        .padding(.top, 1.0)
        .background(Color.color1)
        .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
        .padding(.horizontal)
        .shadow(color: Color.customShadows, radius: 5)
        .scrollDisabled(true)
    }
}


struct StopDropDelegate: DropDelegate {
    let item: Stop
    @Binding var current: [Stop]
    @Binding var draggingItem: Stop?
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = self.draggingItem,
              draggingItem != item,
              let fromIndex = current.firstIndex(of: draggingItem),
              let toIndex = current.firstIndex(of: item) else { return }
        
        withAnimation {
            self.current.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
}


struct ClosestStopsView: View {
    @StateObject private var stopStore = StopStore()
    @StateObject var locationManager = LocationManager()
    @StateObject private var stopManager = StopManager()
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @ObservedObject var viewStateStack: ViewStateStack
    @Binding var useLeadingToTrailing: Bool
//    @Binding var viewState: ViewState
    //@State var stop: Stop?

    var body: some View {
            if let userLocation = locationManager.userLocation, !stopStore.activeStops.isEmpty {
                let closestStops = calculateClosestBusStops(from: userLocation, stops: stopStore.activeStops)
                               if !closestStops.isEmpty {
                                   GeometryReader { geometry in
                                       ScrollView(.horizontal) {
                                           HStack {
                                               ForEach(closestStops, id: \.id) { stop in
                                                   CloseDeparturesView(stop: stop, useLeadingToTrailing: $useLeadingToTrailing, viewStateStack: viewStateStack)
                                                       .frame(width: geometry.size.width, height: geometry.size.height)
                                               }
                                               
                                           }
                                           
                                           .scrollTargetLayout()
                                       }
                                       .scrollTargetBehavior(.viewAligned)
                                   }
                                   
                } else {
                    Text("No bus stops found.")
                }
            } else {
                Text("Loading...")
            }
    }
}

struct CloseDeparturesView: View {
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @StateObject private var stopManager = StopManager()
    @StateObject private var lineManager = LineManager()
    @State private var timer: AnyCancellable?
    var stop: Stop
    @State private var isShowingPopover = false
    @Binding var useLeadingToTrailing: Bool
//    @Binding var viewState: ViewState
    @ObservedObject var viewStateStack: ViewStateStack
    var body: some View {

            RoundedRectangle(cornerRadius: 35, style: .continuous)
                .foregroundStyle(.color1)
                .padding(.horizontal)
                .padding(.vertical, 10.0)
                .shadow(color: Color.customShadows, radius: 5)
                .overlay(
                    VStack {
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    useLeadingToTrailing = false
                                    viewStateStack.push(.stop(stop: stop, previousLineRef: nil, previousLineName: nil))
                                    //                    viewState = .stop(stop)
                                }
                            }) {
//                                HStack() {
                                    Text("\(stop.nomarret)")
                                        .bold()
                                        .font(.title2)
                                        .foregroundStyle(.primary)
//                                    Spacer()
//                                }
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
                                        let newViewModel = ItineraryViewModel()
                                        print(stop.nomarret)
                                        newViewModel.arrivalStop = stop  // Set the desired stop here
                                         newViewModel.arrivalSearchText = stop.nomarret
                                        withAnimation(.easeInOut(duration: 0.3)) {
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
                        }
                        .padding(.horizontal, 35)
                        .padding(.top, 10)
                        VStack {
                            ForEach(stopManager.stopEvents, id: \.id) { event in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        useLeadingToTrailing = false
                                        viewStateStack.push(.line(stopEvent: event, currentStop: stop, currentLine: event.lineName))
                                        //                                    viewState = .line(stopEvent: event, currentStop: stop, currentLine: event.lineName)
                                    }
                                }) {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.color1)
                                        .frame(width: 340, height: 50)
                                        .shadow(color: Color.customShadows, radius: 2)
                                        .overlay(
                                            NewStopBus(event: event, showTime: false)
                                                .padding(.vertical, 0)
                                        )
                                        .padding(.vertical, 1)
                                }
                                .foregroundStyle(.primary)
                                .contextMenu {
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
                        .frame(height: 170)
            })
        .onAppear {
            stopManager.selectStop(stop, stopEventNumber: 3, timeRequest: Date())
//            timer = Timer.publish(every: 30, on: .main, in: .common)
//                .autoconnect()
//                .sink { _ in
//                    stopManager.selectStop(stop, stopEventNumber: 3)
//                }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            stopManager.selectStop(stop, stopEventNumber: 3, timeRequest: Date())
//            timer = Timer.publish(every: 30, on: .main, in: .common)
//                .autoconnect()
//                .sink { _ in
//                    stopManager.selectStop(stop, stopEventNumber: 3)
//                }
                        }
        .onDisappear {
            timer?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            timer?.cancel()
                        }
    }
}

struct HomeView: View {
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @State private var isExpanded: Bool = false
    @ObservedObject var viewStateStack: ViewStateStack
    @StateObject private var search = Search()
    @FocusState private var isFocused: Bool
    @Binding var useLeadingToTrailing: Bool
    @State private var viewSearch: Bool = false
    @State private var showSettings = false
    @Namespace private var animationNamespace
    
    var body: some View {
        VStack {
            ZStack {
                GeometryReader { geometry in
                    VStack {
                        ScrollView {
                            ZStack {
                                if search.searchText.isEmpty {
                                    VStack {
                                        if viewSearch {
                                            Rectangle()
                                                .frame(height: 50)
                                                .foregroundStyle(.clear)
                                        }
                                        //                                Spacer(minLength: 20)
                                        HStack {
                                            Text("Favoris")
                                                .font(.title)
                                                .bold()
                                                .padding(.leading, 15)
                                                .frame(height: 20.0)
                                            Spacer()
                                        }
                                        .padding(.vertical, 5)
                                        
                                        FavoriteView(viewStateStack: viewStateStack, useLeadingToTrailing: $useLeadingToTrailing, isExpanded: $isExpanded)
                                        VStack {
                                            HStack {
                                                Text("Départs à proximité")
                                                    .font(.title)
                                                    .bold()
                                                    .padding(.leading, 15)
                                                    .frame(height: 20.0)
                                                Spacer()
                                            }
                                            .padding(.top, 30)
                                            
                                            ClosestStopsView(viewStateStack: viewStateStack, useLeadingToTrailing: $useLeadingToTrailing)
                                                .frame(width: geometry.size.width, height: geometry.size.height / 3 + 10)
                                        }
                                        HStack {
                                            Spacer()
                                            Button(action: {
                                                
                                            }){
                                                Image(systemName: "map")
                                                    .font(.largeTitle)
                                            }
                                            Spacer()
                                            Button(action: {
                                                showSettings = true
                                            }){
                                                Image(systemName: "gear")
                                                    .font(.largeTitle)
                                            }
                                            Spacer()
                                        }
                                        .popover(isPresented: $showSettings) {
                                            SettingsView()
                                        }
                                        Spacer(minLength: 70)
                                    }
                                }
                                if !search.searchText.isEmpty {
                                    ScrollView {
                                        Rectangle()
                                            .frame(height: 60)
                                            .foregroundStyle(.clear)
                                        ForEach(search.filteredStops) { stop in
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    useLeadingToTrailing = false
                                                    viewStateStack.push(.stop(stop: stop, previousLineRef: nil, previousLineName: nil))
                                                }
                                            }) {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(.color1)
                                                    .frame(height: 40)
                                                    .shadow(color: Color.customShadows, radius: 3)
                                                    .overlay(
                                                        Text(stop.nomarret)
                                                            .font(.headline)
                                                            .foregroundColor(Color.primary)
                                                    )
                                                    .padding(.horizontal, 30)
                                            }
                                        }
                                        Rectangle()
                                            .frame(height: 80)
                                            .foregroundStyle(.clear)
                                    }
                                    .scrollDismissesKeyboard(.immediately)
        //                                .scrollDisabled((viewSearch) ? false : true)
                                }
                                VStack {
                                    if viewSearch {
                                        RoundedRectangle(cornerRadius: 25.0)
                                            .opacity((isFocused || !search.searchText.isEmpty) ? 0 : 1)
                                            .shadow(color: Color.customShadows, radius: 5)
                                            .frame(height: 40)
                                            .padding(.horizontal)
                                            .foregroundStyle(.color1)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                            .onTapGesture {
                                                isFocused = true
                                            }
                                            .overlay(
                                                TextField("Rechercher un arrêt", text: $search.searchText)
                                                    .opacity((isFocused || !search.searchText.isEmpty) ? 0 : 1)
                                                    .foregroundStyle(.primary)
                                                    .padding(.leading, 30)
                                                    .onTapGesture {
                                                        isFocused = true
                                                    }
                                            )
                                    }
                                            RoundedRectangle(cornerRadius: 25.0)
                                                .opacity(search.searchText.isEmpty ? 1 : 0)
                                                .frame(width: 60, height: 10)
                                                .foregroundStyle(.gray)
                //                                        .matchedGeometryEffect(id: "searchBar", in: animationNamespace)
                                                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                                    .onChanged( { value in
                                                        if value.translation.height > 0 {
                                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                                viewSearch = true
                                                            }
                                                        }
                                                        if value.translation.height < 0 {
                                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                                    viewSearch = false
                                                                    search.searchText = ""
                                                            }
                                                        }
                                                    }))
                                        Spacer()
                                    }
                                }
                            }
                            .scrollDismissesKeyboard(.immediately)
                            .scrollDisabled((isExpanded || !search.searchText.isEmpty) ? false : true)
                    }
                }
                VStack {
                    Rectangle()
                        .frame(width: 395, height: 40)
                        .foregroundStyle(Color(UIColor.systemBackground))
                        .shadow(color: Color(UIColor.systemBackground), radius: 7, x: 0, y: 15)
                        .ignoresSafeArea(edges: .top)
                    Spacer()
                }
                VStack {
                    if viewSearch {
                        RoundedRectangle(cornerRadius: 25.0)
                            .opacity((isFocused || !search.searchText.isEmpty) ? 1 : 0)
                            .shadow(color: Color.customShadows, radius: 5)
                            .frame(height: 40)
                            .padding(.horizontal)
                            .foregroundStyle(.color1)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .overlay(
                                TextField("Rechercher un arrêt", text: $search.searchText)
                                    .focused($isFocused)
                                    .opacity((isFocused || !search.searchText.isEmpty) ? 1 : 0)
                                    .foregroundStyle(.primary)
                                    .padding(.leading, 30)
                                    .overlay(
                                                        Button(action: {
                                                            search.searchText = ""
                                                        }) {
                                                            Image(systemName: "xmark.circle.fill")
                                                                .opacity(search.searchText.isEmpty ? 0 : 1).padding()
                                                        }
                                                        
                                                        .padding(),
                                                        alignment: .trailing
                                                    )
                            )
                    }
                            RoundedRectangle(cornerRadius: 25.0)
                                .opacity(!search.searchText.isEmpty ? 1 : 0)
                                .frame(width: 60, height: 10)
                                .foregroundStyle(.gray)
//                                        .matchedGeometryEffect(id: "searchBar", in: animationNamespace)
                                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                    .onChanged( { value in
                                        if value.translation.height > 0 {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                viewSearch = true
                                            }
                                        }
                                        if value.translation.height < 0 {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    viewSearch = false
                                                    search.searchText = ""
                                                
                                            }
                                        }
                                    }))
                        Spacer()
                    }
            }
        }
//        .transition(.truSlide)
    }
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return ContentView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
            .environmentObject(Search())
    }
}

//struct HomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        let stopStore = StopStore()
//        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)
//
//        return AppTabBarView()
//            .environmentObject(stopStore)
//            .environmentObject(favoritesViewModel)
//    }
//}

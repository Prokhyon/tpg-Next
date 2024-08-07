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
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @ObservedObject var viewStateStack: ViewStateStack
    @Binding var transition: AnyTransition

    @Binding var isExpanded: Bool
    @State private var draggingItem: Stop?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let maxRows = 5 // Set the maximum number of rows you want to display

    var body: some View {
        VStack {
            VStack {
                LazyVGrid(columns: columns, spacing: 10) {
                    if favoritesViewModel.favoriteStops.count > 10 {
                        let favorites = isExpanded ? favoritesViewModel.favoriteStops : Array(favoritesViewModel.favoriteStops.prefix(maxRows * columns.count - (isExpanded ? 0 : 1)))
                        ForEach(favorites, id: \.self) { stop in
                            Button(action: {
                                transition = .trailingIn
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    
                                    viewStateStack.push(.stop(stopCodedidoc: stop.codedidoc, stopName: stop.name, previousLineRef: nil, previousLineName: nil))
                                }
                            }) {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.color1)
                                    .frame(maxWidth: .infinity, minHeight: 45, maxHeight: 45)
                                    .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
                                    .overlay(
                                        Text(stop.name)
                                            .font(.headline)
                                            .foregroundColor(Color.primary)
                                            .frame(width: 130)
                                        //                                        .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                    )
                            }
                            //                        .onDrag {
                            //                            self.draggingItem = stop
                            //                            return NSItemProvider(object: String(stop.codedidoc) as NSString)
                            //                        }
                            //                        .onDrop(of: [.text], delegate: StopDropDelegate(item: stop, current: $favoritesViewModel.fullFavorites, draggingItem: $draggingItem))
                        }
                    } else {
                        let favorites = favoritesViewModel.favoriteStops
                        ForEach(favorites, id: \.self) { stop in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    transition = .trailingIn
                                    viewStateStack.push(.stop(stopCodedidoc: stop.codedidoc, stopName: stop.name, previousLineRef: nil, previousLineName: nil))
                                    
                                }
                            }) {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.color1)
                                    .frame(maxWidth: .infinity, minHeight: 45, maxHeight: 45)
                                    .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
                                    .overlay(
                                        Text(stop.name)
                                            .font(.headline)
                                            .foregroundColor(Color.primary)
                                            .frame(width: 130)
                                        //                                        .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                    )
                            }
                            //                        .onDrag {
                            //                            self.draggingItem = stop
                            //                            return NSItemProvider(object: String(stop.codedidoc) as NSString)
                            //                        }
                            //                        .onDrop(of: [.text], delegate: StopDropDelegate(item: stop, current: $favoritesViewModel.fullFavorites, draggingItem: $draggingItem))
                        }
                    }
                    
                    if !isExpanded && favoritesViewModel.favoriteStops.count > 10 {
                        Button(action: {
                            withAnimation(.spring(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.color1)
                                .frame(maxWidth: .infinity, minHeight: 45, maxHeight: 45)
                                .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
                                .overlay(
                                    Image(systemName: "plus")
                                        .foregroundColor(Color.primary)
                                        .font(.headline)
                                )
                        }
                    }
                    
                    if isExpanded && favoritesViewModel.favoriteStops.count % 2 != 0 {
                        Button(action: {
                            withAnimation(.spring(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.color1)
                                .frame(maxWidth: .infinity, minHeight: 45, maxHeight: 45)
                                .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
                                .overlay(
                                    Image(systemName: "minus")
                                        .foregroundColor(Color.primary)
                                        .font(.headline)
                                )
                        }
                    }
                }            
                //            .onAppear {
                //                favoritesViewModel.id2stop(favoriteStops: favoritesViewModel.favoriteStops, stopsArray: stopStore.activeStops)
                //            }
                
                if isExpanded && favoritesViewModel.favoriteStops.count % 2 == 0 {
                    Button(action: {
                        withAnimation(.spring(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.color1)
                            .frame(maxWidth: .infinity, minHeight: 45, maxHeight: 45)
                            .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
                            .overlay(
                                Image(systemName: "minus")
                                    .foregroundColor(Color.primary)
                                    .font(.headline)
                            )
                    }
                    .padding(.top, 3.0)
//                    .padding(.bottom)
//                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .padding(.top, 1.0)
        .background(Color.color1)
        .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
        .padding(.horizontal)
        .shadow(color: Color.customShadows, radius: 3, y: 2)
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
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @StateObject var locationManager = LocationManager()
    @StateObject private var stopManager = StopManager()
    @ObservedObject var viewStateStack: ViewStateStack
    @Binding var transition: AnyTransition
    @State private var timer: AnyCancellable?
    @State private var closestStops: [Stop] = []
    @State private var calculationSuccess = false
//    @Binding var viewState: ViewState
    //@State var stop: Stop?

    var body: some View {
        VStack {
                if calculationSuccess {
                    if !closestStops.isEmpty {
                        GeometryReader { geometry in
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(closestStops, id: \.id) { stop in
                                        CloseDeparturesView(stop: stop, transition: $transition, viewStateStack: viewStateStack)
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
        .onAppear {
            getLocation()
            timer = Timer.publish(every: 30, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    getLocation()
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            getLocation()
            timer = Timer.publish(every: 30, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    getLocation()
                }
                        }
        .onDisappear {
            timer?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            timer?.cancel()
                        }
    }
    private func getLocation () {
        locationManager.locationUpdateHandler = { location in
            if let userLocation = locationManager.userLocation {
                print("if location")
                calculateClosestBusStops(from: userLocation, stops: stopStore.activeStops, nb: 3) { success, stops in
                    if success {
                        closestStops = stops
                        calculationSuccess = true
                    }
                }
            } else { print("error")}
        }
        locationManager.requestLocation()
    }
}

struct CloseDeparturesView: View {
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @StateObject private var stopManager = StopManager()
    @StateObject private var lineManager = LineManager()
    @State private var timer: AnyCancellable?
    var stop: Stop
    @State private var isShowingPopover = false
    @Binding var transition: AnyTransition
//    @Binding var viewState: ViewState
    @ObservedObject var viewStateStack: ViewStateStack
    var body: some View {

            RoundedRectangle(cornerRadius: 35, style: .continuous)
//            .fill(.shadow(.inner(radius: 2)))
                .foregroundStyle(.color1)
                .padding(.horizontal)
                .padding(.vertical, 10.0)
                .shadow(color: Color.customShadows, radius: 3, y: 2)
                .overlay(
                    VStack {
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    transition = .trailingIn
                                    viewStateStack.push(.stop(stopCodedidoc: stop.codedidoc, stopName: stop.name, previousLineRef: nil, previousLineName: nil))
                                    //                    viewState = .stop(stop)
                                }
                            }) {
//                                HStack() {
                                    Text("\(stop.name)")
                                        .bold()
                                        .font(.title2)
                                        .foregroundStyle(.primary)
//                                    Spacer()
//                                }
                            }
                            Spacer()
                            Button(action: {
                                let newViewModel = ItineraryViewModel()
                                print(stop.name)
                                newViewModel.departureStop = stop  // Set the desired stop here
                                 newViewModel.departureSearchText = stop.name
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    transition = .trailingIn
                                    viewStateStack.push(.trip(viewModel: newViewModel, firstSelected: false))
                                }
                            }) {
                                Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                            }
                        }
                        .padding(.horizontal, 35)
                        .padding(.top, 10)
                        VStack {
                            ForEach(stopManager.stopEvents, id: \.id) { event in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        transition = .trailingIn
                                        viewStateStack.push(.line(stopEvent: event, currentStop: ShortStop(name: stop.name, codedidoc: stop.codedidoc), currentLine: event.lineName))
                                        //                                    viewState = .line(stopEvent: event, currentStop: stop, currentLine: event.lineName)
                                    }
                                }) {
                                    RoundedRectangle(cornerRadius: 20)
//                                        .fill(.shadow(.inner(radius: 2, y: 0.5)))
//                                        .fill(.color1)
                                        .foregroundStyle(.color1)
                                        .frame(width: 340, height: 50)
                                        .shadow(color: Color.customShadows2, radius: 2, y: 1.5)
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
            stopManager.selectStop(stopName: stop.name, stopCodedidoc: stop.codedidoc, stopEventNumber: 3, timeRequest: Date())
            timer = Timer.publish(every: 30, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    stopManager.selectStop(stopName: stop.name, stopCodedidoc: stop.codedidoc, stopEventNumber: 3, timeRequest: Date())
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            stopManager.selectStop(stopName: stop.name, stopCodedidoc: stop.codedidoc, stopEventNumber: 3, timeRequest: Date())
            timer = Timer.publish(every: 30, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    stopManager.selectStop(stopName: stop.name, stopCodedidoc: stop.codedidoc, stopEventNumber: 3, timeRequest: Date())
                }
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
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @State private var isExpanded: Bool = false
    @ObservedObject var viewStateStack: ViewStateStack
    @StateObject private var search: Search
    @FocusState private var isFocused: Bool
    @Binding var transition: AnyTransition
    @State private var viewSearch: Bool = false
    @Namespace private var animationNamespace
    
//    @StateObject private var stopStore = StopStore()
    @StateObject private var stopManager = StopManager()
    
    init(viewStateStack: ViewStateStack,transition: Binding<AnyTransition>) {
            _viewStateStack = ObservedObject(wrappedValue: viewStateStack)
            _transition = transition
//            let stopStore = StopStore()
            let stopManager = StopManager()
        _search = StateObject(wrappedValue: Search(stopManager: stopManager))
        }
    
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
                                        
                                        FavoriteView(viewStateStack: viewStateStack, transition: $transition, isExpanded: $isExpanded)
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
                                            
                                            ClosestStopsView(viewStateStack: viewStateStack, transition: $transition)
                                                .frame(width: geometry.size.width, height: geometry.size.height / 3 + 10)
                                        }
                                        Spacer(minLength: 75)
                                    }
                                }
                                if !search.searchText.isEmpty {
                                    ScrollView {
                                        Rectangle()
                                            .frame(height: 60)
                                            .foregroundStyle(.clear)
                                        ForEach(search.filteredStops) { stop in
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.4)) {
                                                    transition = .trailingIn
                                                    viewStateStack.push(.stop(stopCodedidoc: stop.codedidoc, stopName: stop.name, previousLineRef: nil, previousLineName: nil))
                                                }
                                            }) {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(.color1)
                                                    .frame(height: 40)
                                                    .shadow(color: Color.customShadows, radius: 3, y: 2)
                                                    .overlay(
                                                        Text(stop.name)
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
                                            .shadow(color: Color.customShadows, radius: 3, y: 2)
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
                        .foregroundStyle(.customBackground)
                        .shadow(color: .customBackground, radius: 7, x: 0, y: 15)
                        .ignoresSafeArea(edges: .top)
                    Spacer()
                }
                VStack {
                    if viewSearch {
                        RoundedRectangle(cornerRadius: 25.0)
                            .opacity((isFocused || !search.searchText.isEmpty) ? 1 : 0)
                            .shadow(color: Color.customShadows, radius: 3, y: 2)
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
        let favoritesViewModel = FavoritesViewModel()

        return ContentView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
//            .environmentObject(Search())
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

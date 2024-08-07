//
//  ContentView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import SwiftUI
import Combine

enum ViewState {
    case home
    case trip(viewModel: ItineraryViewModel, firstSelected: Bool)
    case fullTrip(fullTrip: TripEvent, departureStop: Stop, arrivalStop: Stop)
    case stop(stopCodedidoc: String, stopName: String, previousLineRef: String?, previousLineName: String?)
    case line(stopEvent: StopEvent, currentStop: ShortStop?, currentLine: String)
}

class ViewStateStack: ObservableObject {
    @Published var stack: [ViewState] = [.home]

    var currentState: ViewState {
        stack.last ?? .home
    }

    func push(_ state: ViewState) {
        stack.append(state)
    }

    func pop() {
        if stack.count > 1 {
            stack.removeLast()
        }
    }

    func reset(to state: ViewState) {
        stack = [state]
    }
}

struct ContentView: View {
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
    @StateObject private var viewStateStack = ViewStateStack()
    @StateObject private var itineraryViewModel = ItineraryViewModel() // Initialize here
    @StateObject private var keyboardResponder = KeyboardResponder()

    @State private var viewingHome = true
    @State private var firstSelected: Bool = true
    @State private var useLeadingToTrailing = true
    @State private var showMenu = false
    @State private var showSettings = false
//    @State private var showTransition = false
    @State private var transition: AnyTransition = .opacity

    var body: some View {
        ZStack {
            Group {
                switch viewStateStack.currentState {
                case .home:
                    HomeView(viewStateStack: viewStateStack, transition: $transition)
                        .transition(transition)
//                        .transition(.move(edge: .leading))
//                        .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
                        .environmentObject(stopStore)
                        .environmentObject(favoritesViewModel)
                case .trip(let viewModel, _):
                    TripView(viewModel: viewModel, firstSelected: $firstSelected, viewStateStack: viewStateStack, transition: $transition)
                        .transition(transition)
                        .environmentObject(stopStore)
//                        .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
//                        .transition(.move(edge: .leading))
                case .stop(let stopCodedidoc, let stopName, let previousLineRef, let previousLineName):
                    StopView(viewStateStack: viewStateStack, favoritesViewModel: favoritesViewModel, stopName: stopName, stopCodedidoc: stopCodedidoc, previousLineRef: previousLineRef, previousLineName: previousLineName, transition: $transition)
                        .transition(transition)
                        .environmentObject(stopStore)
//                        .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
//                        .transition(.move(edge: .leading))
                case .line(let stopEvent, let stop, let currentLine):
                    LineView(stopEvent: stopEvent, currentStop: stop, currentLine: currentLine, viewStateStack: viewStateStack, transition: $transition)
                        .transition(transition)
//                        .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
//                        .transition(.move(edge: .leading))
                        .environmentObject(stopStore)
                case .fullTrip(let fullTrip, let departureStop, let arrivalStop):
                    FullTripView(fullTrip: fullTrip, departureStop: departureStop, arrivalStop: arrivalStop, viewStateStack: viewStateStack, transition: $transition)
                        .transition(transition)
//                        .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
//                        .transition(.move(edge: .leading))
                        .environmentObject(stopStore)
                }
            }

            if showMenu {
                Rectangle()
                    .foregroundStyle(.black)
                    .ignoresSafeArea()
                    .opacity(0.2)
                    .transition(.opacity)
            }

            VStack {
                Spacer()
                
                Group {
                    if showMenu {
                        HStack {
                            Spacer()
                            Circle()
                                .foregroundStyle(.color1)
                                .frame(height: 60)
                                .shadow(color: Color.customShadows, radius: 4, y: 3)
                                .overlay(
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showMenu = false
                                        }
                                    }){
                                        Image(systemName: "map")
                                            .font(.title)
                                    }
                                )
                            Spacer()
                            Circle()
                                .foregroundStyle(.color1)
                                .frame(height: 60)
                                .shadow(color: Color.customShadows, radius: 4, y: 3)
                                .overlay(
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showSettings = true
                                            showMenu = false
                                        }
                                    }){
                                        Image(systemName: "gear")
                                            .font(.title)
                                    }
                                )
                            Spacer()
                        }
                        .transition(.scale.combined(with: .move(edge: .bottom)))
                    }
                }
                if !keyboardResponder.isKeyboardVisible {
                    Circle()
                        .frame(width: 150, height: 70)
                        .foregroundStyle(.color1)
                        .shadow(color: Color.customShadows, radius: 4, y: 3)
                        .overlay(
                            HStack {
                                if showMenu {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showMenu = false
                                        }
                                    }) {
                                        Image(systemName: "xmark").font(.largeTitle).foregroundStyle(.accent)
                                    }
                                    .transition(.symbolEffect)
                                }
                                else if case .home = viewStateStack.currentState {
                                    Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill").font(.largeTitle).foregroundStyle(.accent)
                                        .onTapGesture {
                                            
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                useLeadingToTrailing = false
                                                transition = .trailingIn
                                                viewStateStack.reset(to: .trip(viewModel: itineraryViewModel, firstSelected: true))
                                            }
                                        }
                                        .onLongPressGesture(
                                            minimumDuration: 0.1,
                                            perform: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    showMenu = true
                                                }
                                            }
                                        )
                                } else {
                                    Image(systemName: "house.fill").font(.largeTitle).foregroundStyle(.accent)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.4)) {
                                                useLeadingToTrailing = true
                                                transition = .leadingIn
                                                viewStateStack.reset(to: .home)
                                            }
                                        }
                                        .onLongPressGesture(
                                            minimumDuration: 0.1,
                                            perform: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    showMenu = true
                                                }
                                            }
                                        )
                                }
                            }
                            .padding()
                        )
                }
//                Button(action: {
//                    showTransition = true
//                }) {
//                    Text("transition")
//                }
            }
            .popover(isPresented: $showSettings) {
                SettingsView()
            }
//            .popover(isPresented: $showTransition) {
//                VStack {
//                    List {
//                        Button(action: {
//                            transition = .moveLeadingToTrailing
//                        }) {
//                            Text("leading to trailing")
//                        }
//                        Button(action: {
//                            transition = .moveTrailingToLeading
//                        }) {
//                            Text("trailing to leading")
//                        }
//                        Button(action: {
//                            transition = .left2Right
//                        }) {
//                            Text("left to right")
//                        }
//                        Button(action: {
//                            transition = .right2Left
//                        }) {
//                            Text("right to left")
//                        }
//                    }
//                }
//            }
        }
        .background(.customBackground)
    }
}

extension AnyTransition {
    static var right2Left: AnyTransition {
        let insertion = AnyTransition.move(edge: .trailing).combined(with: .opacity)
        let removal = AnyTransition.move(edge: .leading).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}
extension AnyTransition {
    static var left2Right: AnyTransition {
        let insertion = AnyTransition.move(edge: .leading).combined(with: .opacity)
        let removal = AnyTransition.move(edge: .trailing).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

extension AnyTransition {
    static var truSlide: AnyTransition {
        let insertion = AnyTransition.move(edge: .leading).combined(with: .opacity)
        let removal = AnyTransition.move(edge: .leading).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

extension AnyTransition {
    static var trailingIn: AnyTransition {
        let insertion = AnyTransition.move(edge: .trailing)
        let removal = AnyTransition.opacity
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

extension AnyTransition {
    static var leadingIn: AnyTransition {
        let insertion = AnyTransition.move(edge: .leading)
        let removal = AnyTransition.opacity
        return .asymmetric(insertion: insertion, removal: removal)
    }
}

extension AnyTransition {
    static var moveLeadingToTrailing: AnyTransition {
        AnyTransition.move(edge: .leading).combined(with: .opacity)
    }
    
    static var moveTrailingToLeading: AnyTransition {
        AnyTransition.move(edge: .trailing).combined(with: .opacity)
    }
}


class KeyboardResponder: ObservableObject {
    @Published var isKeyboardVisible = false
    private var cancellable: AnyCancellable?

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }

        cancellable = Publishers.Merge(willShow, willHide)
            .assign(to: \.isKeyboardVisible, on: self)
    }

    deinit {
        cancellable?.cancel()
    }
}

//        TabView {
//            // Tab 1: HomeView
//            HomeView()
//                .tabItem {
//                    Image(systemName: "house")
//                    Text("Accueil")
//                }
//            
//            // Tab 2: SearchView
//            SearchView()
//                .tabItem {
//                    Image(systemName: "magnifyingglass")
//                    Text("Recherche")
//                }
//            
//            // Tab 3: SettingsView
//            SettingsView()
//                .tabItem {
//                    Image(systemName: "gear")
//                    Text("Réglages")
//                }
//            
//           /* NewStopViewTest()
//                .tabItem {
//                    Text("Stop")
//                }*/
//        }
//        .accentColor(.orange) // Set the active tab color
//        .environmentObject(favoritesViewModel)
//       /* .background {
//            RoundedRectangle(cornerRadius: 45.0)
//                .frame(width: 395, height: 200)
//                .foregroundStyle(.color1)
//                .shadow(radius: 10)
//                .ignoresSafeArea(edges: .bottom)
//        }*/


struct SettingsView: View {
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
                var body: some View {
                        NavigationView {
                            List {
                                NavigationLink(destination: reorderFavoritesView) {
                                    Text("Ordre des favoris")
                                }
                            }
                            .navigationTitle("Paramètres")
                        }
                    }
                    
                    var reorderFavoritesView: some View {
                        List {
                            ForEach(favoritesViewModel.favoriteStops) { favorite in
                                    Text(favorite.name)
                            }
                            .onMove { indices, newOffset in
                                favoritesViewModel.moveFavorite(fromOffsets: indices, toOffset: newOffset)
                            }
                            .onDelete { indices in
                                            favoritesViewModel.removeFavoriteIndex(atOffsets: indices)
                                        }
                        }
                        .environment(\.editMode, .constant(.active)) // Enable editing mode to allow reordering
                        .navigationTitle("Favoris")
    }
}

struct ContentView2_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()
        let viewStateStack = ViewStateStack()
        let itineraryViewModel = ItineraryViewModel()
        let keyboardResponder = KeyboardResponder()

        return ContentView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
            .environmentObject(viewStateStack)
            .environmentObject(itineraryViewModel)
            .environmentObject(keyboardResponder)
    }
}

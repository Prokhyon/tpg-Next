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
    case stop(stop: Stop, previousLineRef: String?, previousLineName: String?)
    case line(stopEvent: StopEvent, currentStop: Stop?, currentLine: String)
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
    @StateObject private var stopStore = StopStore()
    @StateObject private var favoritesViewModel: FavoritesViewModel
    @StateObject private var viewStateStack = ViewStateStack()
    @StateObject private var itineraryViewModel = ItineraryViewModel() // Initialize here
    @StateObject private var keyboardResponder = KeyboardResponder()

    @State private var viewingHome = true
    @State private var firstSelected: Bool = true
    @State private var useLeadingToTrailing = true

    init() {
        let stopStore = StopStore()
        _favoritesViewModel = StateObject(wrappedValue: FavoritesViewModel(stopStore: stopStore))
    }

    var body: some View {
        ZStack {
            // Transition between views based on current state
            switch viewStateStack.currentState {
                        case .home:
                            HomeView(viewStateStack: viewStateStack, useLeadingToTrailing: $useLeadingToTrailing)
                                .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
                                .environmentObject(favoritesViewModel)
                        case .trip(let viewModel, _):
                            TripView(viewModel: viewModel, firstSelected: $firstSelected, viewStateStack: viewStateStack, useLeadingToTrailing: $useLeadingToTrailing)
                                .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
                        case .stop(let stop, let previousLineRef, let previousLineName):
                StopView(viewStateStack: viewStateStack, favoritesViewModel: favoritesViewModel, stop: stop, previousLineRef: previousLineRef, previousLineName: previousLineName, useLeadingToTrailing: $useLeadingToTrailing)
                                .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
                        case .line(let stopEvent, let stop, let currentLine):
                            LineView(stopEvent: stopEvent, currentStop: stop, currentLine: currentLine, viewStateStack: viewStateStack, useLeadingToTrailing: $useLeadingToTrailing)
                                .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
                        case .fullTrip(let fullTrip, let departureStop, let arrivalStop):
                FullTripView(fullTrip: fullTrip, departureStop: departureStop, arrivalStop: arrivalStop, viewStateStack: viewStateStack, useLeadingToTrailing: $useLeadingToTrailing)
                                .transition(useLeadingToTrailing ? .moveLeadingToTrailing : .moveTrailingToLeading)
                        }

            VStack {
                Spacer()
                if !keyboardResponder.isKeyboardVisible {
                    Circle()
                        .frame(width: 150, height: 70)
                        .foregroundStyle(.color1)
                        .shadow(color: Color.customShadows, radius: 5)
                        .overlay(
                            HStack {
                                if case .home = viewStateStack.currentState {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            useLeadingToTrailing = false
                                            viewStateStack.reset(to: .trip(viewModel: itineraryViewModel, firstSelected: true))
                                        }
                                    }) {
                                        Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill").font(.largeTitle)
                                    }
                                } else {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            useLeadingToTrailing = true
                                            viewStateStack.reset(to: .home)
                                        }
                                    }) {
                                        Image(systemName: "house.fill").font(.largeTitle)
                                    }
                                }
                            }
                                .padding()
                        )
                }
            }
        }
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
    static var ca: AnyTransition {
        let insertion = AnyTransition.move(edge: .trailing).combined(with: .opacity)
        let removal = AnyTransition.move(edge: .leading).combined(with: .opacity)
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
    @StateObject private var stopStore = StopStore()
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
                            ForEach(favoritesViewModel.fullFavorites) { favorite in
                                    Text(favorite.nomarret)
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
        let favoritesViewModel = FavoritesViewModel(stopStore: stopStore)

        return ContentView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
            .environmentObject(Search())
    }
}

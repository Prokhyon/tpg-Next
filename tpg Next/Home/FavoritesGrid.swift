//
//  FavoritesGrid.swift
//  tpg Next
//
//  Grille des arrêts favoris de l'accueil.
//

import SwiftUI
import tpgNextFunc

struct FavoriteStopView: View {
    @Environment(ItineraryViewModel.self) var tripViewModel
    @Environment(NavigationModel.self) var navigationModel
    var stop: Stop
    var body: some View {
        NavigationLink(value: AppRoute.stop(stop)) {
            BasicLocationView(name: stop.name, transportType: stop.meansOfTransport)
        }
        .foregroundStyle(.primary)
        .contentShape(.contextMenuPreview, Capsule())
        .contextMenu {
            TripActionsMenu(stop: stop)
        }
    }
}

struct FavoriteView: View {
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(NavigationModel.self) var navigationModel
    @Environment(\.layout) private var layout
    @Binding var isExpanded: Bool

    /// 2 colonnes sur iPhone, davantage quand la fenêtre s'élargit.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: layout.favoriteColumns)
    }

    var maxRows: Int // Set the maximum number of rows you want to display

    var body: some View {
        VStack {
            VStack {
                LazyVGrid(columns: columns, spacing: 8) {
                    // Sans favori : une case en pointillés, de la taille des autres, ouvre Explorer.
                    if favoritesViewModel.favoriteStops.isEmpty {
                        AddFavoriteButton("Ajouter un arrêt") {
                            withAnimation {
                                navigationModel.selectedTab = .search
                            }
                        }
                    }
                    if favoritesViewModel.favoriteStops.count > maxRows * columns.count {
                        let favorites = isExpanded ? favoritesViewModel.favoriteStops : Array(favoritesViewModel.favoriteStops.prefix(max(0, maxRows * columns.count - (isExpanded ? 0 : 1))))
                        ForEach(favorites, id: \.self) { stop in
                            FavoriteStopView(stop: stop)
                        }
                    } else {
                        let favorites = favoritesViewModel.favoriteStops
                        ForEach(favorites, id: \.self) { stop in
                         FavoriteStopView(stop: stop)
                        }
                    }
                    
                    if !isExpanded && favoritesViewModel.favoriteStops.count > maxRows * columns.count {
                        Button(action: {
                            withAnimation(.spring(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            BasicElement()
                                .overlay(
                                    Image(systemName: "plus")
                                        .foregroundColor(Color.primary)
                                        .font(.headline)
                                )
                        }
                    }
                    
                    // Rangée incomplète : le bouton la termine ; sinon il passe sous la grille.
                    if isExpanded && favoritesViewModel.favoriteStops.count % columns.count != 0 {
                        Button(action: {
                            withAnimation(.spring(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            BasicElement()
                                .overlay(
                                    Image(systemName: "minus")
                                        .foregroundColor(Color.primary)
                                        .font(.headline)
                                )
                        }
                    }
                }
                
                if isExpanded && favoritesViewModel.favoriteStops.count % columns.count == 0 {
                    Button(action: {
                        withAnimation(.spring(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        BasicElement()
                            .frame(height: 45)
                            .overlay(
                                Image(systemName: "minus")
                                    .foregroundColor(Color.primary)
                                    .font(.headline)
                            )
                    }
                    .padding(.top, 3.0)
                }
            }
            .padding(15)
//            .background(.thinMaterial)
//            .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
//            .padding(.horizontal)
//            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
            .scrollDisabled(true)
        }
    }
}

#Preview("Grille des favoris") {
    @Previewable @State var isExpanded = false
    ScrollView {
        FavoriteView(isExpanded: $isExpanded, maxRows: 3)
    }
    .previewEnvironment()
}

#Preview("Grille des favoris — vide") {
    @Previewable @State var isExpanded = false
    FavoriteView(isExpanded: $isExpanded, maxRows: 3)
        .previewEnvironment(favorites: [])
}

#Preview("Grille des favoris — iPad", traits: .iPadLandscape) {
    @Previewable @State var isExpanded = false
    ScrollView {
        FavoriteView(isExpanded: $isExpanded, maxRows: 2)
    }
    .previewEnvironment()
}

#Preview("Favori", traits: .sizeThatFitsLayout) {
    VStack {
        FavoriteStopView(stop: PreviewData.rive)
        FavoriteStopView(stop: PreviewData.meinier)
        FavoriteStopView(stop: PreviewData.airport)
    }
    .frame(width: 190)
    .padding()
    .previewEnvironment()
}

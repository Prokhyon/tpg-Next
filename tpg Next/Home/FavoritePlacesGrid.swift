//
//  FavoritePlacesGrid.swift
//  tpg Next
//
//  Les lieux favoris : la section de l'accueil, leurs cases, leur ordre et leur nom.
//  Un toucher cherche l'itinéraire pour y aller, depuis la position actuelle.
//

import SwiftUI
import tpgNextFunc

/// La section « Lieux favoris » de l'accueil.
struct FavoritePlacesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionTitle("Lieux favoris")
            FavoritePlacesGrid()
        }
    }
}

/// Les lieux favoris en grille, comme les arrêts favoris. Sans lieu, une case en pointillés
/// ouvre Explorer.
struct FavoritePlacesGrid: View {
    @Environment(FavoritePlacesModel.self) private var favoritePlaces
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.layout) private var layout
    @State private var renaming: FavoritePlace?
    @State private var shownOnMap: PlaceSheetItem?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: layout.favoriteColumns)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(favoritePlaces.places) { place in
                FavoritePlaceCell(place: place,
                                  rename: { renaming = place },
                                  showOnMap: { shownOnMap = PlaceSheetItem(place: place) })
            }
            if favoritePlaces.places.isEmpty {
                AddFavoriteButton("Ajouter un lieu") {
                    navigationModel.selectedTab = .search
                }
            }
        }
        .padding(15)
        .renamingFavoritePlace($renaming)
        .sheet(item: $shownOnMap) { place in
            PlaceSheet(place: place)
        }
    }
}

/// Un lieu favori : y aller d'un toucher ; partir d'ici, le voir sur la carte, le renommer ou
/// le retirer par un appui long.
struct FavoritePlaceCell: View {
    @Environment(ItineraryViewModel.self) private var itinerary
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(FavoritePlacesModel.self) private var favoritePlaces
    let place: FavoritePlace
    let rename: () -> Void
    let showOnMap: () -> Void

    var body: some View {
        Button {
            itinerary.searchNow(from: nil, to: place.endpoint, tab: navigationModel)
        } label: {
            FavoritePlaceLabel(place: place)
                .padding(.horizontal, 15)
                .basicElementBackground(minHeight: 45)
        }
        .foregroundStyle(.primary)
        .contentShape(.contextMenuPreview, Capsule())
        .contextMenu {
            Button {
                itinerary.searchNow(from: nil, to: place.endpoint, tab: navigationModel)
            } label: {
                Label("Y aller", systemImage: "figure.walk.departure")
            }
            Button {
                itinerary.start(from: place.endpoint, tab: navigationModel)
            } label: {
                Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
            }
            Button(action: showOnMap) {
                Label("Voir sur la carte", systemImage: "map")
            }
            Button(action: rename) {
                Label("Renommer…", systemImage: "pencil")
            }
            Button(role: .destructive) {
                withAnimation { favoritePlaces.remove(place) }
            } label: {
                Label("Retirer des lieux favoris", systemImage: "star.slash")
            }
        }
    }
}

/// Le nom du lieu, et dessous le nom de Plans s'il a été renommé, sinon son adresse.
struct FavoritePlaceLabel: View {
    let place: FavoritePlace

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse.circle")
                .font(.title3)
//                .foregroundStyle(.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: place.name)
                    .font(.callout.bold())
                    .lineLimit(1)
                if let detail = place.detail {
                    Text(verbatim: detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }
}

/// Une case vide, en pointillés et grisée, de la taille des autres : elle invite à ajouter un
/// favori (arrêt ou lieu) depuis Explorer.
struct AddFavoriteButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 15)
                .frame(maxWidth: .infinity, minHeight: 45)
                .background {
                    Capsule()
                        .strokeBorder(.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// L'ordre des lieux favoris, affiché comme celui des arrêts favoris : glisser pour
/// réordonner, ⊖ ou balayer pour retirer, le crayon pour renommer.
struct FavoritePlacesOrderView: View {
    @Environment(FavoritePlacesModel.self) private var favoritePlaces
    @Environment(NavigationModel.self) private var navigationModel
    @State private var renaming: FavoritePlace?

    var body: some View {
        Group {
            if favoritePlaces.places.isEmpty {
                VStack(spacing: 16) {
                    Text("Touchez l'étoile d'un lieu dans Explorer pour le retrouver ici, sur l'accueil et dans l'itinéraire.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    AddFavoriteButton("Ajouter un lieu") {
                        navigationModel.selectedTab = .search
                    }
                    .frame(maxWidth: 240)
                }
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                List {
                    ForEach(favoritePlaces.places) { place in
                        HStack {
                            FavoritePlaceLabel(place: place)
                            Button {
                                renaming = place
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.accent)
                                    .frame(width: 30, height: 30)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Renommer")
                        }
                        .heightGrowingWithText(30)
                        .padding(.horizontal, 20)
                    }
                    .onMove { indices, newOffset in
                        favoritePlaces.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    .onDelete { indices in
                        favoritePlaces.remove(atOffsets: indices)
                    }
                    .listRowBackground(
                        BasicElement()
                            .padding(.vertical, 5)
                            .padding(.horizontal, 60)
                    )
                    .listRowSeparator(.hidden)
                }
                .contentMargins(.bottom, 20.0, for: .automatic)
                .contentMargins(.horizontal, 5.0, for: .automatic)
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .readableList()
            }
        }
        .navigationTitle("Lieux favoris")
        .renamingFavoritePlace($renaming)
    }
}

extension PlaceSheetItem {
    init(place: FavoritePlace) {
        self.init(name: place.name, subtitle: place.detail, coordinate: place.coordinate)
    }
}

extension View {
    /// Le nom d'un lieu favori, à changer dans une alerte. Vide, il reprend celui de Plans.
    func renamingFavoritePlace(_ place: Binding<FavoritePlace?>) -> some View {
        modifier(RenameFavoritePlace(place: place))
    }
}

private struct RenameFavoritePlace: ViewModifier {
    @Environment(FavoritePlacesModel.self) private var favoritePlaces
    @Binding var place: FavoritePlace?
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert("Renommer le lieu",
                   isPresented: Binding(get: { place != nil }, set: { if !$0 { place = nil } }),
                   presenting: place) { place in
                TextField(place.placeName, text: $name)
                Button("Annuler", role: .cancel) {}
                Button("Renommer") {
                    favoritePlaces.rename(place, to: name)
                }
            } message: { place in
                Text("Laissez vide pour reprendre « \(place.placeName) ».")
            }
            .onChange(of: place) {
                name = place?.name ?? ""
            }
    }
}

#Preview("Lieux favoris") {
    ScrollView {
        FavoritePlacesSection()
    }
    .previewEnvironment()
}

#Preview("Lieux favoris — vide") {
    ScrollView {
        FavoritePlacesSection()
    }
    .previewEnvironment(places: [])
}

#Preview("Ordre des lieux favoris") {
    FavoritePlacesOrderView()
        .previewEnvironment()
}

#Preview("Ordre des lieux favoris — vide") {
    FavoritePlacesOrderView()
        .previewEnvironment(places: [])
}

#Preview("Cases", traits: .sizeThatFitsLayout) {
    VStack {
        FavoritePlaceLabel(place: PreviewData.places[0])
            .padding(.horizontal, 15)
            .basicElementBackground(minHeight: 45)
        FavoritePlaceLabel(place: PreviewData.places[1])
            .padding(.horizontal, 15)
            .basicElementBackground(minHeight: 45)
        AddFavoriteButton("Ajouter un arrêt") {}
        AddFavoriteButton("Ajouter un lieu") {}
    }
    .frame(width: 190)
    .padding()
    .background(Color.color1)
}

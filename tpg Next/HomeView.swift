//
//  HomeView.swift
//  TPG4
//
//  Created by Loris Thomas on 19.06.2024.
//

import SwiftUI
import CoreLocation
import Combine
import tpgNextFunc

/// L'accueil : ce qui me concerne maintenant. Le prochain trajet, les favoris, les lieux favoris, les départs à
/// proximité (ou des favoris) et la carte, dans l'ordre choisi par l'utilisateur (`HomeSection`).
/// Sur grand écran, les départs passent dans une seconde colonne ; les autres sections restent
/// à gauche, et la carte y prend la place restante.
struct HomeView: View {
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(RegularTripsModel.self) private var regularTripsModel
    @Environment(SavedTripsModel.self) private var savedTripsModel
    @Environment(\.layout) private var layout
    @Environment(\.displayTime) private var now

    @State private var isExpanded: Bool = false
    /// Partagés par la liste des départs et la carte.
    @State private var nearby = NearbyStops()
    var testing: Bool
    @AppStorage(SettingKey.homeShowsFavorites) var homeFavorites = false
    @AppStorage(SettingKey.homeSectionsOrder) private var storedOrder = ""
    @AppStorage(SettingKey.homeHiddenSections) private var storedHidden = ""

    /// Les sections affichées, dans l'ordre choisi.
    private var order: [HomeSection] {
        let hidden = HomeSection.hidden(from: storedHidden)
        return HomeSection.order(from: storedOrder).filter { !hidden.contains($0) }
    }
    private var showsDepartures: Bool { order.contains(.departures) }

    var body: some View {
        GeometryReader { geometry in
            // Une rangée de favoris pour 168 points de hauteur de fenêtre : 3 à 5 selon l'iPhone, au moins 1
            // (au premier passage, la fenêtre mesure 0 et `prefix(-1)` plantait). La fenêtre
            // et non l'écran (`UIScreen.main`) : sur iPad ou en multifenêtre, elle est plus petite.
            let maxRows = max(1, Int(((geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom) / 168).rounded()))
            ZStack {
                if layout.showsSecondaryPane && showsDepartures && order.count == 1 {
                    // Seuls les départs : ils prennent toute la largeur.
                    ScrollView {
                        HomeDepartures(testing: testing, stacked: true)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .readableScrollContent()
                } else if layout.showsSecondaryPane && !showsDepartures {
                    // Départs masqués : une seule colonne, sur toute la largeur.
                    let next = nextTrip
                    ViewThatFits(in: .vertical) {
                        wideMainColumn(maxRows: next == nil ? 5 : 3, next: next, mapFillsHeight: true)
                        ScrollView {
                            wideMainColumn(maxRows: next == nil ? 5 : 3, next: next, mapFillsHeight: false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else if layout.showsSecondaryPane {
                    // Chaque colonne se met en page comme sur une fenêtre de sa largeur.
                    let column = LayoutContext(width: layout.width / 2)
                    let next = nextTrip
                    // Cinq rangées de favoris, trois sous un prochain trajet : la carte, en dessous,
                    // prend ce qui reste et peut rester petite.
                    let rows = next == nil ? 5 : 3
                    HStack(alignment: .top, spacing: 0) {
                        // Rien ne défile : la carte prend toute la place laissée par les favoris. Seule
                        // une grille dépliée trop longue, ou un texte très agrandi, fait défiler la colonne.
                        ViewThatFits(in: .vertical) {
                            wideMainColumn(maxRows: rows, next: next, mapFillsHeight: true)
                            ScrollView {
                                wideMainColumn(maxRows: rows, next: next, mapFillsHeight: false)
                            }
                        }
                        // Deux moitiés égales, comme le dit `column` : sans ça, la colonne au contenu le
                        // plus large (une ligne de favoris, par exemple) prenait presque tout.
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        // Sept départs et deux arrêts repliés tiennent : ça ne défile qu'en cas de besoin.
                        ScrollView {
                            HomeDepartures(testing: testing, stacked: true)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(maxWidth: .infinity)
                    }
                    .environment(\.layout, column)
                } else {
                    // Toujours défilable : bloqué tant que la grille des favoris n'était pas dépliée,
                    // l'accueil cachait ses départs avec beaucoup de favoris ou un texte agrandi.
                    ScrollView {
                        sections(order, maxRows: maxRows, next: nextTrip, mapFillsHeight: false)
                            .padding(.bottom, 20)
                    }
                    .readableScrollContent()
                }
            }
            .sensoryFeedback(.selection, trigger: isExpanded)
            .environment(nearby)
        }
        // Les itinéraires enregistrés ne sont redemandés à OJP que là où on les affiche : ici,
        // pour qu'un itinéraire devienne « prochain » et que sa carte suive le temps réel.
        .task {
            guard !testing else { return }
            while !Task.isCancelled {
                await savedTripsModel.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
            }
        }
        .navigationTitle("Accueil") // Set back button text
        // Deux colonnes qui défilent chacune : ni grand titre qui se réduit, ni barre qui se
        // minimise. Sans quoi faire défiler les départs faisait remonter la colonne de gauche.
        .navigationBarTitleDisplayMode(layout.showsSecondaryPane ? .inline : .automatic)
        .fixedNavigationBar()
        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text("")
//            }
            // Des éléments de barre, que le système peut poser à la verticale (iPhone Duo).
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.scheduledNotifications) {
                    Label("Rappels prévus", systemImage: "bell")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.settings) {
                    Label("Paramètres", systemImage: "gear")
                }
            }
        }
    }

    private var nextTrip: NextTrip? {
        testing || !order.contains(.nextTrip) ? nil : NextTrip.next(regular: regularTripsModel, saved: savedTripsModel, now: now)
    }

    /// La colonne de gauche sur grand écran : les sections choisies, sauf les départs (à droite).
    private func wideMainColumn(maxRows: Int, next: NextTrip?, mapFillsHeight: Bool) -> some View {
        sections(order.filter { $0 != .departures }, maxRows: maxRows, next: next,
                 mapFillsHeight: mapFillsHeight)
            .padding(.bottom, 20)
    }

    /// Les sections, dans l'ordre choisi (Paramètres → Organiser l'accueil).
    private func sections(_ sections: [HomeSection], maxRows: Int, next: NextTrip?,
                          mapFillsHeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(sections) { section in
                switch section {
                case .nextTrip:
                    if let next {
                        nextTripSection(next)
                    }
                case .favorites:
                    VStack(alignment: .leading, spacing: 8) {
                        HomeSectionTitle("Favoris")
                        FavoriteView(isExpanded: $isExpanded, maxRows: maxRows)
                    }
                case .places:
                    FavoritePlacesSection()
                case .departures:
                    HomeDepartures(testing: testing)
                case .map:
                    // Sans la liste des départs, la carte cherche elle-même les arrêts proches.
                    HomeMapCard(fillsHeight: mapFillsHeight,
                                withoutDepartures: !showsDepartures, testing: testing)
                }
            }
        }
    }

    /// La date au-dessus du prochain trajet : seule, elle n'apprendrait rien.
    private func nextTripSection(_ next: NextTrip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.dayTitle(next.plannedDeparture))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 15)
            NextTripSection(next: next)
        }
    }

    /// « Jeudi 24 septembre ».
    private static func dayTitle(_ day: Date) -> String {
        let text = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return text.prefix(1).capitalized + text.dropFirst()
    }
}

#Preview("Accueil — arrêts proches") {
    // Départs autour de la position du simulateur (Features → Location dans le simulateur).
    HomeView(testing: false)
        .previewEnvironment()
}

#Preview("Accueil — départs des favoris") {
    HomeView(testing: false)
        .previewSettings([SettingKey.homeShowsFavorites: true])
        .previewEnvironment()
}

#Preview("Accueil — sans favori") {
    HomeView(testing: true)
        .previewEnvironment(favorites: [])
}

#Preview("Accueil — hors ligne") {
    // Départs figés de SmallStopView, sans position ni API.
    HomeView(testing: true)
        .previewEnvironment()
}

#Preview("Accueil — iPad", traits: .iPadLandscape) {
    HomeView(testing: false)
        .previewSettings([SettingKey.homeShowsFavorites: true])
        .previewEnvironment()
}

#Preview("Accueil — départs et carte masqués") {
    HomeView(testing: true)
        .previewSettings([SettingKey.homeHiddenSections: HomeSection.stored([.departures, .map])])
        .previewEnvironment()
}

#Preview("Accueil — iPad, départs masqués", traits: .iPadLandscape) {
    HomeView(testing: true)
        .previewSettings([SettingKey.homeHiddenSections: HomeSection.stored([.departures])])
        .previewEnvironment()
}

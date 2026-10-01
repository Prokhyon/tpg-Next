//
//  PreviewEnvironment.swift
//  tpg Next
//
//  Ce qu'un aperçu doit fournir pour qu'un écran s'affiche comme dans l'app : les modèles
//  d'environnement, la largeur mesurée, le fond et, au besoin, une pile de navigation qui
//  sait ouvrir toutes les routes.
//
//      #Preview {
//          StopView(stopName: "Genève, Rive", stopSloid: "ch:1:sloid:87061")
//              .previewEnvironment()
//      }
//
//  Grand écran : `#Preview("iPad", traits: .iPadLandscape)` (ou choisir un iPad dans le
//  canevas) ; la largeur est mesurée, comme dans l'app.
//

import SwiftUI
import tpgNextFunc

extension View {
    /// Pose tout l'environnement de l'app autour d'un aperçu.
    /// - Parameters:
    ///   - navigation: enveloppe la vue dans une pile qui ouvre les routes (liens, `openRoute`).
    ///     `false` pour un composant, ou un écran qui a déjà sa pile (`ContentView`).
    ///   - favorites: favoris posés au lancement de l'aperçu ; `[]` pour l'état sans favori.
    ///   - places: lieux favoris ; `[]` pour l'état sans lieu.
    ///   - savedTrips: itinéraires enregistrés.
    ///   - itinerary: départ et arrivée déjà choisis dans l'itinéraire (recherche faite).
    ///   - background: le dégradé de l'app derrière la vue.
    func previewEnvironment(navigation: Bool = true,
                            favorites: [Stop] = PreviewData.favorites,
                            places: [FavoritePlace] = PreviewData.places,
                            savedTrips: [TripEvent] = [],
                            itinerary: (from: Stop, to: Stop)? = nil,
                            background: Bool = true) -> some View {
        modifier(PreviewEnvironment(navigation: navigation, favorites: favorites, places: places, savedTrips: savedTrips,
                                    itinerary: itinerary, background: background))
    }
}

extension View {
    /// Réglages lus par `@AppStorage` (voir `SettingKey`), propres à cet aperçu :
    /// `.previewSettings([SettingKey.groupByLineByDefault: true])`.
    func previewSettings(_ values: [String: Any]) -> some View {
        let defaults = UserDefaults(suiteName: "preview-settings")!
        defaults.removePersistentDomain(forName: "preview-settings")
        values.forEach { defaults.set($1, forKey: $0) }
        return defaultAppStorage(defaults)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    /// Grand iPad en paysage : l'écran passe en deux moitiés (`.wide`).
    static var iPadLandscape: PreviewTrait<T> { .fixedLayout(width: 1180, height: 820) }
    /// iPad en portrait ou iPad mini : `.regular`.
    static var iPadPortrait: PreviewTrait<T> { .fixedLayout(width: 820, height: 1180) }
}

private struct PreviewEnvironment: ViewModifier {
    let navigation: Bool
    let favorites: [Stop]
    let savedTrips: [TripEvent]
    let background: Bool

    @State private var stopStore = StopStore()
    @State private var favoritesViewModel = FavoritesViewModel()
    @State private var favoritePlaces: FavoritePlacesModel
    @State private var navigationModel = NavigationModel()
    @State private var itineraryViewModel: ItineraryViewModel
    @State private var savedTripsModel = SavedTripsModel()
    @State private var regularTripsModel = RegularTripsModel()
    @State private var recentSearch = RecentSearch()
    @State private var path: [AppRoute] = []

    init(navigation: Bool, favorites: [Stop], places: [FavoritePlace], savedTrips: [TripEvent],
         itinerary: (from: Stop, to: Stop)?, background: Bool) {
        _favoritePlaces = State(initialValue: FavoritePlacesModel(previewPlaces: places))
        self.navigation = navigation
        self.favorites = favorites
        self.savedTrips = savedTrips
        self.background = background
        let itineraryViewModel = ItineraryViewModel()
        if let itinerary {
            itineraryViewModel.departure.select(.stop(itinerary.from))
            itineraryViewModel.arrival.select(.stop(itinerary.to))
            itineraryViewModel.selectedField = nil
            itineraryViewModel.tripDone = true
        }
        _itineraryViewModel = State(initialValue: itineraryViewModel)
    }

    func body(content: Content) -> some View {
        Group {
            if navigation {
                NavigationStack(path: $path) {
                    content.appRouteDestinations()
                }
                .environment(\.openRoute, OpenRouteAction { path.append($0) })
            } else {
                content
            }
        }
        .environment(stopStore)
        .environment(favoritesViewModel)
        .environment(favoritePlaces)
        .environment(navigationModel)
        .environment(itineraryViewModel)
        .environment(savedTripsModel)
        .environment(regularTripsModel)
        .environment(recentSearch)
        .providingLayoutContext()
        .tickingClock()
        .background(background ? AnyShapeStyle(Gradient(colors: [.accent, .color1, .color1]).opacity(0.7))
                                : AnyShapeStyle(.clear))
        .task {
            // Les favoris et itinéraires sont enregistrés dans le bac à sable des aperçus :
            // on les repose à chaque lancement pour partir d'un état connu.
            favoritesViewModel.replaceAll(with: favorites)
            savedTripsModel.savedTrips = savedTrips
            await stopStore.waitUntilLoaded()
            favoritesViewModel.attach(stopStore: stopStore)
        }
    }
}

/// Affiche `content` avec de vrais départs, demandés à l'API au lancement de l'aperçu.
///
/// Pour les écrans qui chargent eux-mêmes une course (`LineView`, carte de ligne) : une
/// course enregistrée n'existe plus côté API, il leur faut un départ du jour.
struct LiveDeparturePreview<Content: View>: View {
    let stop: Stop
    let pick: ([StopEvent]) -> StopEvent?
    let content: (LiveDepartures) -> Content

    @State private var manager = StopManager()

    /// - Parameter pick: le départ à montrer ; par défaut le premier qui n'est pas supprimé.
    init(stop: Stop = PreviewData.rive,
         pick: @escaping ([StopEvent]) -> StopEvent? = { $0.first { !$0.cancelled } },
         @ViewBuilder content: @escaping (LiveDepartures) -> Content) {
        self.stop = stop
        self.pick = pick
        self.content = content
    }

    var body: some View {
        Group {
            if let event = pick(manager.stopEvents) {
                content(LiveDepartures(event: event, all: manager.stopEvents, quays: manager.quays))
            } else if manager.stopError {
                ContentUnavailableView {
                    Label("Départs indisponibles" as String, systemImage: "wifi.slash")
                } description: {
                    Text(verbatim: "Cet aperçu interroge l'API : vérifiez la connexion.")
                }
            } else {
                ProgressView("Départs de \(stop.name)…" as String)
            }
        }
        .task {
            manager.selectStop(stopName: stop.name, stopSloid: stop.sloid, stopEventNumber: 20, timeRequest: Date())
        }
    }
}

/// Les départs reçus par `LiveDeparturePreview`.
struct LiveDepartures {
    /// Le départ retenu par `pick`.
    let event: StopEvent
    let all: [StopEvent]
    let quays: [Quay]
}

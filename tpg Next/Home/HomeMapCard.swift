//
//  HomeMapCard.swift
//  tpg Next
//
//  La carte des arrêts, en aperçu sur l'accueil : elle remplace l'onglet Carte. Elle montre les
//  arrêts de la liste des départs, et met en évidence celui que la liste affiche. La toucher
//  l'ouvre en plein écran.
//

import SwiftUI
import MapKit
import CoreLocation
import tpgNextFunc

struct HomeMapCard: View {
    @Environment(StopStore.self) private var stopStore
    @Environment(FavoritesViewModel.self) private var favoritesViewModel
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(NearbyStops.self) private var nearby
    @Environment(\.layout) private var layout
    @Environment(\.openRoute) private var openRoute
    /// Prend toute la hauteur que lui laisse la colonne (grand écran, sans défilement).
    var fillsHeight = false
    /// La liste des départs est masquée : la carte cherche les arrêts proches, rien n'y est mis
    /// en évidence, et toucher un arrêt ouvre sa page.
    var withoutDepartures = false
    var testing = false
    @Namespace private var transition
    @State private var region = Self.region(around: Self.geneva)
    @State private var position: MapCameraPosition = .region(Self.region(around: Self.geneva))
    /// Sans arrêts proches (position refusée), ceux autour du centre de la carte.
    @State private var fallbackStops: [Stop] = []
    /// Les pages ouvertes depuis la carte plein écran (arrêt, ligne) : elle a sa propre pile.
    @State private var fullMapPath: [AppRoute] = []

    /// Sans position : le centre de Genève.
    private static let geneva = CLLocationCoordinate2D(latitude: 46.20973, longitude: 6.14244)
    /// Sans position : les arrêts à cette distance du centre de Genève.
    private static let fallbackRadius: CLLocationDistance = 500

    private var stops: [Stop] { nearby.stops.isEmpty ? fallbackStops : nearby.stops }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionTitle("Autour de vous")
            preview
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Carte des arrêts")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { navigationModel.showsFullMap = true }
                .matchedTransitionSource(id: "map", in: transition)
                .padding(.horizontal, 10)
        }
        .fullScreenCover(isPresented: Bindable(navigationModel).showsFullMap) {
            NavigationStack(path: $fullMapPath) {
                MapView(initialRegion: region) { navigationModel.showsFullMap = false }
                    .appRouteDestinations()
            }
            .environment(\.openRoute, OpenRouteAction { fullMapPath.append($0) })
            .departureActionSheets()
            // Mesurée à nouveau : sur grand écran, l'accueil passe à la carte le `\.layout` de sa
            // colonne, et les pages arrêt et ligne s'ouvraient alors dans leur version iPhone.
            .providingLayoutContext()
            .navigationTransition(.zoom(sourceID: "map", in: transition))
        }
        .onChange(of: nearby.stops, initial: true) { recenter() }
        // Ce que fait la liste des départs quand elle est là.
        .periodicRefresh(repeats: withoutDepartures && !testing) { _ in refreshNearby() }
        .onChange(of: stopStore.isLoaded) { refreshNearby() }
        .onChange(of: stopStore.isLoaded) { recenter() }
    }

    /// Une carte figée. Toucher un arrêt le choisit dans la liste des départs ; toucher ailleurs
    /// ouvre la carte en plein écran.
    private var preview: some View {
        // Lus ici, dans le corps de la vue : lus dans le contenu de la carte, évalué plus tard,
        // leurs changements ne la redessinaient pas.
        let stops = self.stops
        let highlighted = withoutDepartures ? nil : nearby.highlightedSloid
        let userCoordinate = nearby.location?.coordinate
        return MapReader { proxy in
            map(stops: stops, highlighted: highlighted, user: userCoordinate)
                // Pas de bouton dans les marqueurs : leur toucher se mêlait à celui de la carte.
                // On cherche l'arrêt le plus proche du doigt.
                .onTapGesture { point in
                    if let stop = Self.stop(near: point, in: stops, proxy: proxy) {
                        choose(stop)
                    } else {
                        navigationModel.showsFullMap = true
                    }
                }
        }
        .if(fillsHeight) { $0.frame(minHeight: 160, idealHeight: 160, maxHeight: .infinity) }
        // Une colonne d'iPad est bien plus large qu'un iPhone : la même hauteur l'écrasait.
        .if(!fillsHeight) { $0.frame(height: layout.width > 500 ? 340 : 200) }
        .overlay(alignment: .bottomTrailing) {
            Button {
                navigationModel.showsFullMap = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.subheadline.bold())
                    .frame(width: 36, height: 36)
                    .tpgSurface(in: Circle(), interactive: true, legacy: .thinMaterial)
            }
            .foregroundStyle(.primary)
            .accessibilityLabel("Ouvrir la carte des arrêts")
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .contentShape(RoundedRectangle(cornerRadius: 30))
    }

    /// `user` : la position de la dernière recherche des arrêts proches, pas `UserAnnotation()`.
    /// Celle-ci suit chaque position reçue, et pendant un trajet suivi (positions en continu, en
    /// mouvement) MapKit redessinait la carte à chaque image, même défilée hors de l'écran :
    /// 15 à 35 % du processeur, défilement et touchers en retard dans toute l'app.
    private func map(stops: [Stop], highlighted: String?, user: CLLocationCoordinate2D?) -> some View {
        Map(position: $position, interactionModes: []) {
            ForEach(stops) { stop in
                // Comme un arrêt touché sur la carte plein écran : plus gros, en couleur, nommé.
                let isHighlighted = stop.sloid == highlighted
                Annotation(stop.name, coordinate: stop.wgs84Coordinates.toCLLocationCoordinate2D, anchor: .center) {
                    StopMapMarker(isSelected: isHighlighted)
                }
                .annotationTitles(isHighlighted ? .automatic : .hidden)
            }
            if let user {
                Annotation("", coordinate: user, anchor: .center) {
                    HomeMapUserDot()
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }

    /// Un arrêt de la liste devient celui qu'elle affiche ; un autre (liste des favoris) ouvre
    /// sa page.
    private func refreshNearby() {
        guard withoutDepartures, !testing else { return }
        nearby.refresh(stopStore: stopStore,
                       favoriteSloids: Set(favoritesViewModel.favoriteStops.map { sloidHarmonizer(code: $0.sloid) }))
    }

    private func choose(_ stop: Stop) {
        if !withoutDepartures && nearby.listedSloids.contains(stop.sloid) {
            withAnimation(.snappy) { nearby.selectedSloid = stop.sloid }
        } else {
            openRoute(.stop(stop))
        }
    }

    /// L'arrêt le plus proche du toucher, à portée de doigt.
    private static func stop(near point: CGPoint, in stops: [Stop], proxy: MapProxy) -> Stop? {
        let reach: CGFloat = 28
        return stops
            .compactMap { stop -> (Stop, CGFloat)? in
                guard let position = proxy.convert(stop.wgs84Coordinates.toCLLocationCoordinate2D, to: .local) else { return nil }
                return (stop, hypot(position.x - point.x, position.y - point.y))
            }
            .filter { $0.1 <= reach }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// Cadre la position et tous les arrêts de la liste.
    private func recenter() {
        if nearby.stops.isEmpty {
            let center = nearby.location?.coordinate ?? Self.geneva
            let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
            fallbackStops = stopsInBoundingBox(from: location, radius: Self.fallbackRadius, stops: stopStore.activeStops)
            region = Self.region(around: center)
        } else {
            var coordinates = nearby.stops.map(\.wgs84Coordinates.toCLLocationCoordinate2D)
            if let location = nearby.location { coordinates.append(location.coordinate) }
            region = Self.region(fitting: coordinates)
        }
        withAnimation { position = .region(region) }
    }

    private static func region(around center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))
    }

    /// La plus petite zone qui contient tous les points, avec une marge pour les marqueurs.
    private static func region(fitting coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else {
            return region(around: geneva)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        // Au moins la zone d'un quartier : deux arrêts voisins ne remplissent pas toute la carte.
        let span = MKCoordinateSpan(latitudeDelta: max(0.004, (maxLat - minLat) * 1.6),
                                    longitudeDelta: max(0.004, (maxLon - minLon) * 1.6))
        return MKCoordinateRegion(center: center, span: span)
    }
}

#Preview("Carte de l'accueil") {
    ScrollView {
        HomeMapCard()
    }
    .environment(NearbyStops())
    .previewEnvironment()
}

/// La position sur la carte de l'accueil, dessinée comme celle du système, mais immobile entre
/// deux recherches des arrêts proches.
private struct HomeMapUserDot: View {
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}

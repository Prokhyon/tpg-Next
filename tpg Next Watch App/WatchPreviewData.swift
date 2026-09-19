//
//  WatchPreviewData.swift
//  tpg Next Watch App
//
//  Données et environnement des aperçus de la montre (voir `PreviewData` pour l'iPhone).
//

import SwiftUI
import tpgNextFunc

enum WatchPreviewData {
    static let rive = Stop(name: "Genève, Rive", sloid: "ch:1:sloid:87061", codedidoc: "8587061", country: "CH", canton: "Genève",
                           meansOfTransport: "BUS|TRAM", wgs84Coordinates: Coordinates(lon: 6.15281, lat: 46.20186))
    static let cornavin = Stop(name: "Genève, gare Cornavin", sloid: "ch:1:sloid:87057", codedidoc: "8587057", country: "CH", canton: "Genève",
                               meansOfTransport: "BUS|TRAM", wgs84Coordinates: Coordinates(lon: 6.14244, lat: 46.20973))
    static let plainpalais = Stop(name: "Genève, Plainpalais", sloid: "ch:1:sloid:87907", codedidoc: "8587907", country: "CH", canton: "Genève",
                                  meansOfTransport: "BUS|TRAM", wgs84Coordinates: Coordinates(lon: 6.14281, lat: 46.19804))

    static let favorites = [rive, cornavin, plainpalais]

    /// Un départ de Genève, Rive dans `minutes` minutes, `delay` minutes de retard.
    static func departure(line: String = "12", destination: String = "Genève, Moillesulaz", quay: String = "B",
                          inMinutes minutes: Double = 4, delay: Double = 0, cancelled: Bool = false,
                          transportType: String = "Tram") -> StopEvent {
        let now = Date()
        return StopEvent(stopPointName: rive.name, stopId: rive.sloid, plannedQuay: quay,
                         timetabledTime: OJPDate.string(from: now.addingTimeInterval((minutes - delay) * 60)),
                         estimatedTime: OJPDate.string(from: now.addingTimeInterval(minutes * 60)),
                         lineName: line, origin: rive.name, destination: destination, transportType: transportType,
                         operatorName: "Transports Publics Genevois", journeyRef: "preview-\(line)-\(destination)-\(minutes)",
                         operatingDayRef: "", isCancelled: cancelled ? true : nil)
    }

    /// Plusieurs passages d'une même ligne, pour la vue triée par ligne.
    static func departures(line: String = "12", destination: String = "Genève, Moillesulaz", quay: String = "B",
                           every interval: Double = 6, count: Int = 5) -> [StopEvent] {
        (0..<count).map { departure(line: line, destination: destination, quay: quay, inMinutes: 2 + Double($0) * interval,
                                    delay: $0 == 1 ? 3 : 0) }
    }
}

extension View {
    /// La base des arrêts et les favoris de la montre, comme au lancement de l'app.
    func watchPreviewEnvironment(favorites: [Stop] = WatchPreviewData.favorites) -> some View {
        modifier(WatchPreviewEnvironment(favorites: favorites))
    }
}

private struct WatchPreviewEnvironment: ViewModifier {
    let favorites: [Stop]
    @State private var stopStore = StopStore()
    @State private var watchFavorites = WatchFavoritesViewModel()

    func body(content: Content) -> some View {
        content
            .environment(stopStore)
            .environment(watchFavorites)
            .tickingClock()
            .task { watchFavorites.favoriteStops = favorites }
    }
}

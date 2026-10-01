//
//  StopDistanceLabel.swift
//  tpg Next
//
//  À quelle distance est un arrêt proche, et dans quelle direction : une flèche qui pointe
//  vers lui en suivant l'orientation du téléphone, ou le point cardinal sans boussole.
//

import SwiftUI
import CoreLocation
import tpgNextFunc

/// La position et l'orientation du téléphone, suivies tant qu'une distance est à l'écran.
/// La position avance avec la marche : la distance reste juste sans relancer la recherche.
@MainActor
@Observable
final class StopCompass: NSObject, CLLocationManagerDelegate {
    static let shared = StopCompass()

    private(set) var location: CLLocation?
    /// Le cap du haut du téléphone, en degrés depuis le nord. `nil` sans boussole (simulateur).
    private(set) var heading: CLLocationDirection?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var users = 0

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.headingFilter = 5
    }

    /// Chaque étiquette affichée s'inscrit ; la dernière disparue arrête les capteurs.
    func start() {
        users += 1
        guard users == 1 else { return }
        // La permission est demandée ailleurs (accueil, itinéraire) : sans elle, rien ne part.
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        users = max(0, users - 1)
        guard users == 0 else { return }
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.location = last }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let degrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in self.heading = degrees }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// « ↗ 240 m » : la distance à pied d'oiseau et la direction de l'arrêt.
struct StopDistanceLabel: View {
    let coordinate: CLLocationCoordinate2D
    /// La position connue de l'écran (celle qui a servi à trouver les arrêts), en attendant
    /// celle du suivi.
    var fallback: CLLocation?
    private var compass = StopCompass.shared

    init(coordinate: CLLocationCoordinate2D, fallback: CLLocation? = nil) {
        self.coordinate = coordinate
        self.fallback = fallback
    }

    var body: some View {
        Group {
            if let from = compass.location ?? fallback {
                let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = from.distance(from: target)
                let bearing = Self.bearing(from: from.coordinate, to: coordinate)
                HStack(spacing: 3) {
                    if let heading = compass.heading {
                        Image(systemName: "location.north.fill")
                            .font(.caption2)
                            .rotationEffect(.degrees(bearing - heading))
                    } else {
                        Text(verbatim: Self.cardinal(bearing))
                            .fontWeight(.semibold)
                    }
                    Text(Self.distanceText(distance))
                }
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("À \(Self.distanceText(distance)), \(Self.cardinalName(bearing))"))
            }
        }
        .onAppear { compass.start() }
        .onDisappear { compass.stop() }
    }

    // MARK: Calculs

    static func distanceText(_ meters: CLLocationDistance) -> String {
        Measurement(value: meters.rounded(), unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    /// Le cap initial de `from` vers `to`, en degrés depuis le nord (0–360).
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func sector(_ bearing: Double) -> Int {
        Int((bearing + 22.5) / 45) % 8
    }

    /// « NE » : sans boussole, la flèche ne saurait pas où pointer.
    static func cardinal(_ bearing: Double) -> String {
        ["N", "NE", "E", "SE", "S", "SO", "O", "NO"][sector(bearing)]
    }

    static func cardinalName(_ bearing: Double) -> String {
        [String(localized: "au nord"), String(localized: "au nord-est"), String(localized: "à l'est"),
         String(localized: "au sud-est"), String(localized: "au sud"), String(localized: "au sud-ouest"),
         String(localized: "à l'ouest"), String(localized: "au nord-ouest")][sector(bearing)]
    }
}

extension Stop {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: wgs84Coordinates.lat, longitude: wgs84Coordinates.lon)
    }
}

#Preview("Distance d'un arrêt", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 12) {
        // Rive, depuis la place du Molard.
        StopDistanceLabel(coordinate: PreviewData.rive.coordinate,
                          fallback: CLLocation(latitude: 46.2036, longitude: 6.1460))
        StopDistanceLabel(coordinate: PreviewData.cornavin.coordinate,
                          fallback: CLLocation(latitude: 46.2036, longitude: 6.1460))
    }
    .padding()
}

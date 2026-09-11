//
//  WidgetPreviews.swift
//  tpg Next Widget
//
//  Created by Loris Thomas on 30.08.2026.
//
//  Tous les aperçus du widget, regroupés ici pour itérer sur les visuels dans le
//  canevas Xcode sans passer par le simulateur.
//
//  Deux niveaux :
//  - les aperçus « widget » (`#Preview(as:)`) rendent le vrai widget, à la vraie
//    taille, avec le fond système — c'est ce qui fait foi ;
//  - les aperçus « composants » rendent une ligne ou un en-tête isolé, avec un
//    rafraîchissement quasi instantané, pour régler le détail typographique.
//
//  Le canevas Xcode a son propre sélecteur clair/sombre : inutile de dupliquer
//  les aperçus pour ça.
//

import SwiftUI
import WidgetKit
import CoreLocation
import tpgNextFunc

// MARK: - Scénarios

extension PreviewData {

    /// L'heure passée à l'API, au format des réponses OJP (UTC).
    static func timestamp(inMinutes minutes: Double, from reference: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: reference.addingTimeInterval(minutes * 60))
    }

    /// Un départ sur mesure. `delay` en minutes décale l'heure estimée par rapport
    /// à l'horaire, ce qui fait passer le décompte en couleur accent.
    static func departure(line: String,
                          destination: String,
                          quay: String = "A",
                          inMinutes minutes: Double,
                          delay: Double = 0,
                          operatorName: String = "Transports Publics Genevois",
                          transportType: String = "Bus") -> StopEvent {
        StopEvent(stopPointName: stop.name,
                  stopId: stop.sloid,
                  plannedQuay: quay,
                  timetabledTime: timestamp(inMinutes: minutes - delay),
                  estimatedTime: timestamp(inMinutes: minutes),
                  lineName: line,
                  origin: "",
                  destination: destination,
                  transportType: transportType,
                  operatorName: operatorName,
                  journeyRef: "preview-\(line)-\(minutes)",
                  operatingDayRef: "")
    }

    static func entry(stop: Stop = PreviewData.stop,
                      events: [StopEvent] = PreviewData.events,
                      status: DeparturesEntry.Status = .ok,
                      distance: CLLocationDistance? = 120,
                      at date: Date = Date()) -> DeparturesEntry {
        DeparturesEntry(date: date, stop: stop, events: events, status: status, distance: distance)
    }

    // MARK: Cas limites visuels

    /// Retards, départ imminent, quai inconnu : tout ce qui change la couleur ou
    /// remplace le décompte par une icône.
    static let edgeCaseEvents: [StopEvent] = [
        departure(line: "12", destination: "Genève, Moillesulaz", quay: "B", inMinutes: 0.2),
        departure(line: "17", destination: "Onex, Bandol", quay: "A", inMinutes: 0.8),
        departure(line: "9", destination: "Vernier, Blandonnet-Aéroport", quay: "", inMinutes: 4, delay: 3),
        departure(line: "25", destination: "Thônex, Vallard", quay: "C", inMinutes: 9, delay: 1),
        departure(line: "61", destination: "Saint-Julien-en-Genevois, Gare routière", quay: "D", inMinutes: 21)
    ]

    /// Noms longs, sans virgule, avec exploitants variés : le test de troncature.
    static let longNameStop = Stop(name: "Genève-Quai Gustave Ador (lac)",
                                   sloid: "ch:1:sloid:30700",
                                   codedidoc: "",
                                   country: "CH",
                                   canton: "GE",
                                   meansOfTransport: "BOAT",
                                   wgs84Coordinates: Coordinates(lon: 6.155, lat: 46.204))

    static let longNameEvents: [StopEvent] = [
        departure(line: "M2", destination: "Genève-Pâquis (lac)", quay: "2", inMinutes: 2,
                  operatorName: "Mouettes Genevoises Navigation", transportType: "Schiff"),
        departure(line: "M2", destination: "Genève-Pâquis (lac)", quay: "2", inMinutes: 12,
                  operatorName: "Mouettes Genevoises Navigation", transportType: "Schiff"),
        departure(line: "M2", destination: "Genève-Pâquis (lac)", quay: "2", inMinutes: 22,
                  operatorName: "Mouettes Genevoises Navigation", transportType: "Schiff")
    ]

    /// Un arrêt ferroviaire : icône lightrail dans l'en-tête, couleurs CFF.
    static let trainStop = Stop(name: "Genève, Cornavin",
                                sloid: "ch:1:sloid:7000",
                                codedidoc: "8501008",
                                country: "CH",
                                canton: "GE",
                                meansOfTransport: "TRAIN|BUS|TRAM",
                                wgs84Coordinates: Coordinates(lon: 6.142, lat: 46.210))

    static let trainEvents: [StopEvent] = [
        departure(line: "IC5", destination: "St. Gallen", quay: "7", inMinutes: 6,
                  operatorName: "Schweizerische Bundesbahnen SBB", transportType: "InterCity"),
        departure(line: "RE", destination: "Annemasse", quay: "3", inMinutes: 11, delay: 4,
                  operatorName: "Schweizerische Bundesbahnen SBB", transportType: "RegioExpress"),
        departure(line: "18", destination: "Carouge, Grand-Lancy", quay: "F", inMinutes: 3),
        departure(line: "14", destination: "Bernex, Vailly", quay: "E", inMinutes: 7),
        departure(line: "6", destination: "Vernier, Village", quay: "D", inMinutes: 13)
    ]

    /// Le fond du widget, reproduit pour les aperçus de composants
    /// (`containerBackground` ne s'applique que dans un vrai widget).
    static var background: some View {
        LinearGradient(colors: [.color1, .color1],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }
}

// MARK: - Aperçus du widget entier

#Preview("Moyen — proximité", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    PreviewData.entry()
}

#Preview("Moyen — arrêt choisi", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    PreviewData.entry(distance: nil)
}

#Preview("Moyen — retards et imminence", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    PreviewData.entry(events: PreviewData.edgeCaseEvents, distance: 12)
}

#Preview("Moyen — nom long", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    PreviewData.entry(stop: PreviewData.longNameStop,
                      events: PreviewData.longNameEvents,
                      distance: 65)
}

#Preview("Moyen — décompte qui descend", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    // Les mêmes départs vus à cinq minutes d'intervalle : le canevas laisse
    // parcourir la timeline pour vérifier que les départs passés disparaissent.
    PreviewData.entry(at: Date())
    PreviewData.entry(at: Date().addingTimeInterval(5 * 60))
    PreviewData.entry(at: Date().addingTimeInterval(10 * 60))
    PreviewData.entry(at: Date().addingTimeInterval(15 * 60))
}

#Preview("Grand — proximité", as: .systemLarge) {
    DeparturesWidget()
} timeline: {
    PreviewData.entry()
}

#Preview("Grand — gare", as: .systemLarge) {
    DeparturesWidget()
} timeline: {
    PreviewData.entry(stop: PreviewData.trainStop,
                      events: PreviewData.trainEvents,
                      distance: nil)
}

#Preview("Grand — trois départs seulement", as: .systemLarge) {
    DeparturesWidget()
} timeline: {
    // Vérifie que la liste reste calée en haut au lieu de flotter au centre.
    PreviewData.entry(events: Array(PreviewData.events.prefix(3)))
}

// MARK: - Aperçus des états sans départ

#Preview("État — position indisponible", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    DeparturesEntry.message(.noLocation)
}

#Preview("État — index absent", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    DeparturesEntry.message(.indexMissing)
}

#Preview("État — aucun arrêt proche", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    DeparturesEntry.message(.noStopNearby)
}

#Preview("État — aucun départ", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    PreviewData.entry(events: [], status: .noDepartures)
}

#Preview("État — réseau", as: .systemMedium) {
    DeparturesWidget()
} timeline: {
    PreviewData.entry(events: [], status: .networkError)
}

// MARK: - Aperçus de composants

#Preview("Composant — lignes", traits: .fixedLayout(width: 340, height: 300)) {
    VStack(spacing: 4) {
        ForEach(PreviewData.edgeCaseEvents, id: \.id) { event in
            DepartureRow(event: event, referenceDate: Date())
        }
    }
    .padding()
    .background(PreviewData.background)
}

#Preview("Composant — en-têtes", traits: .fixedLayout(width: 340, height: 200)) {
    VStack(alignment: .leading, spacing: 18) {
        HeaderView(stop: PreviewData.stop, distance: 120)
        HeaderView(stop: PreviewData.longNameStop, distance: 65)
        HeaderView(stop: PreviewData.trainStop, distance: nil)
        HeaderView(stop: PreviewData.stop, distance: nil)
    }
    .padding()
    .background(PreviewData.background)
}

#Preview("Composant — quais", traits: .sizeThatFitsLayout) {
    HStack(spacing: 10) {
        ForEach(["A", "B", "3", "", "AB"], id: \.self) { quay in
            QuayIcon(quay: quay)
        }
    }
    .padding()
}

#Preview("Composant — états", traits: .fixedLayout(width: 340, height: 320)) {
    VStack(spacing: 12) {
        StatusView(status: .noLocation)
        StatusView(status: .indexMissing)
        StatusView(status: .noStopNearby)
        StatusView(status: .noDepartures)
        StatusView(status: .networkError)
    }
    .padding()
    .background(PreviewData.background)
}

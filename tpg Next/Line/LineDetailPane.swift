//
//  LineDetailPane.swift
//  tpg Next
//
//  Moitié droite de la page ligne sur grand écran : la carte du parcours avec la position
//  estimée du véhicule, et en bas les prochains passages à l'arrêt sélectionné ou, à défaut,
//  le véhicule et l'accessibilité des arrêts.
//

import SwiftUI
import MapKit
import tpgNextFunc

struct LineDetailPane: View {
    let stopEvent: StopEvent
    let currentStopSloid: String?
    let journey: JourneyTrackModel
    let selectedStop: LineEvent?
    let deselect: () -> Void

    /// Ouvert depuis un lien, le départ n'a pas toujours sa destination : le terminus de la
    /// course la remplace.
    private var destinationName: String {
        stopEvent.destination.isEmpty ? (journey.events.last?.stopPointName ?? "") : stopEvent.destination
    }

    var body: some View {
        DetailPaneLayout {
            LineMapPanel(stopEvent: stopEvent, currentStopSloid: currentStopSloid, journey: journey, selectedStop: selectedStop)
        } title: {
            PaneTitleCapsule {
                HStack(spacing: 8) {
                    if let selectedStop {
                        StopNameView(selectedStop.stopPointName, style: .row)
                        Spacer(minLength: 0)
                        Button(action: deselect) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Fermer")
                    } else {
                        BusLineIcon(lineName: stopEvent.lineName, operatorName: journey.operatorName)
                        Image(systemName: "arrow.right").font(.caption)
                        StopNameView(destinationName, style: .row)
                        Spacer(minLength: 0)
                    }
                }
            }
        } details: {
            Group {
                if let selectedStop {
                    LineStopDeparturesPanel(stop: selectedStop, stopEvent: stopEvent)
                } else {
                    VehicleInfoPanel(stopEvent: stopEvent, journey: journey, currentStopSloid: currentStopSloid)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

/// Carte de la course : tracé, arrêts, arrêt sélectionné et position estimée du véhicule.
struct LineMapPanel: View {
    @Environment(\.displayTime) private var now
    let stopEvent: StopEvent
    let currentStopSloid: String?
    let journey: JourneyTrackModel
    let selectedStop: LineEvent?
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            JourneyMapContent(events: journey.events, segments: journey.segments, lineName: stopEvent.lineName,
                              operatorName: journey.operatorName, currentStopSloid: currentStopSloid, now: now)
            if let selectedStop {
                Annotation("", coordinate: selectedStop.coordinate, anchor: .center) {
                    Circle()
                        .strokeBorder(Color.accent, lineWidth: 4)
                        .frame(width: 28, height: 28)
                }
            }
            if let vehicle = estimatedVehiclePosition(events: journey.events, segments: journey.segments, at: now) {
                Annotation(String(localized: "Position estimée"), coordinate: vehicle, anchor: .center) {
                    transportIcon(with: stopEvent.transportType)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Circle().fill(LineColors.lineColor(for: stopEvent.lineName, operatorName: journey.operatorName)))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .shadow(radius: 3)
                }
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onChange(of: journey.events.count) { withAnimation { position = .automatic } }
        .onChange(of: selectedStop?.id) {
            guard let selectedStop else { return }
            withAnimation {
                position = .region(MKCoordinateRegion(center: selectedStop.coordinate,
                                                      span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
            }
        }
    }
}

/// Sans arrêt sélectionné : le véhicule, sa position estimée et l'accessibilité des arrêts restants.
struct VehicleInfoPanel: View {
    @Environment(\.displayTime) private var now
    @Environment(\.openRoute) private var openRoute
    let stopEvent: StopEvent
    let journey: JourneyTrackModel
    /// L'arrêt d'où la course a été ouverte.
    var currentStopSloid: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                PaneSectionTitle(text: "Véhicule")
                HStack(spacing: 10) {
                    transportIcon(with: stopEvent.transportType).font(.title2)
                    BusLineIcon(lineName: stopEvent.lineName, operatorName: journey.operatorName)
                    Image(systemName: "arrow.right").font(.caption)
                    StopNameView(stopEvent.destination, style: .row)
                }
                if !journey.operatorName.isEmpty {
                    Text(journey.operatorName).foregroundStyle(.secondary)
                }
                chips
                if stopEvent.cancelled, let currentStopSloid,
                   let alternative = nearestServedStop(skipping: currentStopSloid, in: journey.events, now: now) {
                    ServedAlternativeCard(alternative: alternative, transportType: stopEvent.transportType) {
                        openRoute(.stop(name: alternative.stop.stopPointName, sloid: alternative.stop.sloid,
                                        highlight: DepartureHighlight(journeyRef: stopEvent.journeyRef, lineName: stopEvent.lineName, time: alternative.stop.timetabledTime)))
                    }
                }
            }

            if let nextStop {
                VStack(alignment: .leading, spacing: 6) {
                    PaneSectionTitle(text: "Position estimée")
                    HStack {
                        Text("Prochain arrêt")
                            .foregroundStyle(.secondary)
                        StopNameView(nextStop.stopPointName, style: .row)
                        Spacer()
                        DepartureTimeView(departureDisplay(timetabled: nextStop.timetabledTime, estimated: nextStop.estimatedTime, showTime: false, at: now),
                                          transportType: stopEvent.transportType, showsIcon: false)
                    }
                    Text("Calculée à partir des horaires en temps réel, sans suivi GPS.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                PaneSectionTitle(text: "Accessibilité des prochains arrêts")
                if upcomingStops.isEmpty {
                    Text("Chargement du parcours…").foregroundStyle(.secondary)
                } else {
                    ForEach(QuayAccess.allCases, id: \.self) { access in
                        let stops = upcomingStops.filter { $0.quayAccess == access }
                        if !stops.isEmpty {
                            DisclosureGroup {
                                ForEach(stops) { stop in
                                    StopNameView(stop.stopPointName, style: .row)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 2)
                                }
                            } label: {
                                Label {
                                    Text(access.label) + Text(" · \(stops.count)").foregroundStyle(.secondary)
                                } icon: {
                                    Image(systemName: access.systemImage)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }

    /// Sur une rangée ; défilante quand elle ne tient pas (sinon chaque capsule se replie sur plusieurs lignes).
    private var chips: some View {
        ViewThatFits(in: .horizontal) {
            chipRow
            ScrollView(.horizontal, showsIndicators: false) { chipRow }
        }
    }

    private var chipRow: some View {
        let service = journey.service
        return HStack(spacing: 8) {
            // Un incident ne supprime souvent qu'une partie de la course : le bus peut sauter
            // l'arrêt de départ et rouler ailleurs, ou le desservir et sauter d'autres arrêts.
            if journeyIsCancelled {
                InfoChip(text: "Course supprimée", systemImage: "exclamationmark.triangle.fill", tint: .red)
            } else if stopEvent.cancelled {
                InfoChip(text: "Ne passe pas à cet arrêt", systemImage: "exclamationmark.triangle.fill", tint: .red)
            } else if service?.hasIncident == true || stopEvent.routeChanged {
                InfoChip(text: "Parcours modifié", systemImage: "exclamationmark.triangle.fill", tint: .orange)
            }
            if stopEvent.exceptional {
                InfoChip(text: "Horaire exceptionnel", systemImage: "calendar.badge.exclamationmark", tint: .orange)
            }
            if service?.hasLowFloor == true || stopEvent.hasLowFloor {
                InfoChip(text: "Plancher bas", systemImage: "arrow.down.to.line")
            }
            if let skipped = skippedStopsCount, skipped > 0 {
                InfoChip(text: "\(skipped) arrêt(s) non desservi(s)", systemImage: "nosign", tint: .red)
            }
            if let number = service?.trainNumber, !number.isEmpty {
                InfoChip(text: "Course \(number)", systemImage: "number")
            }
        }
    }

    /// Les arrêts desservis pas encore quittés.
    private var upcomingStops: [LineEvent] {
        journey.events.filter { $0.isCancelled != true && !hasPassed($0.departureDate, includingCurrentMinute: false, now: now) }
    }

    private var nextStop: LineEvent? {
        guard estimatedVehiclePosition(events: journey.events, segments: journey.segments, at: now) != nil else { return nil }
        return upcomingStops.first
    }

    /// Aucun arrêt de la course n'est desservi.
    private var journeyIsCancelled: Bool {
        !journey.events.isEmpty && journey.events.allSatisfy { $0.isCancelled == true }
    }

    private var skippedStopsCount: Int? {
        journey.events.isEmpty ? nil : journey.events.filter { $0.isCancelled == true }.count
    }
}

/// Un arrêt de la ligne sélectionné : tous ses départs, filtrables par ligne.
struct LineStopDeparturesPanel: View {
    @Environment(\.displayTime) private var now
    @Environment(\.openRoute) private var openRoute
    let stop: LineEvent
    let stopEvent: StopEvent
    @State private var stopManager = StopManager()
    /// Lignes affichées ; vide = toutes.
    @State private var lineFilters: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let access = stop.quayAccess {
                InfoChip(text: access.label, systemImage: access.systemImage)
            }

            PaneSectionTitle(text: "Départs")
            if !lines.isEmpty {
                LineFilterChips(lines: lines, selection: $lineFilters)
            }

            if departures.isEmpty {
                Text(stopManager.stopError ? "Pas de départ trouvé" : "Recherche des départs…")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(departures) { departure in
                        NavigationLink(value: AppRoute.line(event: departure, currentStop: ShortStop(name: stop.stopPointName, sloid: stop.sloid))) {
                            StopEventView(event: departure, showTime: false, previousLineRef: stopEvent.journeyRef)
                                .foregroundStyle(determineColor(for: departure.estimatedTime, now: now))
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }

            Button {
                openRoute(.stop(name: stop.stopPointName, sloid: stop.sloid,
                                highlight: DepartureHighlight(journeyRef: stopEvent.journeyRef, lineName: stopEvent.lineName, time: stop.timetabledTime)))
            } label: {
                Label("Ouvrir l'arrêt", systemImage: "signpost.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .periodicRefresh(id: stop.id) { _ in
            stopManager.selectStop(stopName: stop.stopPointName, stopSloid: stop.sloid, stopEventNumber: 40, timeRequest: Date())
        }
        // Autre arrêt : ses lignes ne sont plus les mêmes.
        .onChange(of: stop.sloid) { lineFilters = [] }
    }

    /// Les lignes de l'arrêt, dans l'ordre habituel.
    private var lines: [LineFilterChips.Line] {
        var seen = Set<String>()
        return stopManager.stopEvents
            .filter { seen.insert($0.lineName).inserted }
            .map { LineFilterChips.Line(name: $0.lineName, operatorName: $0.operatorName) }
            .sorted { lineGroupPrecedes($0.name, $1.name) }
    }

    private var departures: [StopEvent] {
        let events = stopManager.stopEvents.sortedByDeparture()
        return lineFilters.isEmpty ? events : events.filter { lineFilters.contains($0.lineName) }
    }
}

#Preview("Panneau ligne — véhicule", traits: .fixedLayout(width: 560, height: 820)) {
    LineDetailPane(stopEvent: PreviewData.lineDeparture, currentStopSloid: PreviewData.rive.sloid,
                   journey: PreviewData.journeyModel(), selectedStop: nil, deselect: {})
        .previewEnvironment()
}

#Preview("Panneau ligne — arrêt sélectionné (API)", traits: .fixedLayout(width: 560, height: 820)) {
    // Les prochains passages de l'arrêt sont demandés à l'API.
    let journey = PreviewData.journeyModel()
    LineDetailPane(stopEvent: PreviewData.lineDeparture, currentStopSloid: PreviewData.rive.sloid,
                   journey: journey, selectedStop: journey.events.first { $0.sloid == PreviewData.cornavin.sloid }
                        ?? journey.events.first { $0.sloid == PreviewData.rive.sloid },
                   deselect: {})
        .previewEnvironment()
}

#Preview("Carte de la course", traits: .fixedLayout(width: 520, height: 520)) {
    LineMapPanel(stopEvent: PreviewData.lineDeparture, currentStopSloid: PreviewData.rive.sloid,
                 journey: PreviewData.journeyModel(), selectedStop: nil)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .padding()
        .previewEnvironment(navigation: false)
}

#Preview("Carte de la course — sans tracé", traits: .fixedLayout(width: 520, height: 520)) {
    // Avant l'arrivée du tracé routier : arrêts reliés en ligne droite.
    let journey = PreviewData.journeyModel(withTrack: false)
    LineMapPanel(stopEvent: PreviewData.lineDeparture, currentStopSloid: PreviewData.rive.sloid,
                 journey: journey, selectedStop: journey.events.last)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .padding()
        .previewEnvironment(navigation: false)
}

#Preview("Véhicule et accessibilité", traits: .fixedLayout(width: 520, height: 700)) {
    ScrollView {
        VehicleInfoPanel(stopEvent: PreviewData.lineDeparture, journey: PreviewData.journeyModel(withTrack: false))
            .padding(20)
    }
    .previewEnvironment(navigation: false)
}

#Preview("Passages à un arrêt (API)", traits: .fixedLayout(width: 520, height: 600)) {
    let stop = PreviewData.journeyStops.first { $0.sloid == PreviewData.rive.sloid } ?? PreviewData.journeyStops[0]
    ScrollView {
        LineStopDeparturesPanel(stop: stop, stopEvent: PreviewData.lineDeparture)
            .padding(20)
    }
    .previewEnvironment()
}

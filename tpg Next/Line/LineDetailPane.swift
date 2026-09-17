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

    var body: some View {
        VStack(spacing: 12) {
            LineMapPanel(stopEvent: stopEvent, currentStopSloid: currentStopSloid, journey: journey, selectedStop: selectedStop)
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .frame(maxHeight: .infinity)

            ScrollView {
                Group {
                    if let selectedStop {
                        LineStopDeparturesPanel(stop: selectedStop, stopEvent: stopEvent, close: deselect)
                    } else {
                        VehicleInfoPanel(stopEvent: stopEvent, journey: journey)
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: .infinity)
            .background { BasicCard(cornerRadius: 30) }
        }
        .padding([.horizontal, .bottom])
        .padding(.top, 8)
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
    let stopEvent: StopEvent
    let journey: JourneyTrackModel

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

    private var chips: some View {
        let service = journey.service
        return HStack(spacing: 8) {
            if service?.isCancelled == true || stopEvent.cancelled {
                InfoChip(text: "Course supprimée", systemImage: "exclamationmark.triangle.fill", tint: .red)
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

    /// Les arrêts pas encore quittés.
    private var upcomingStops: [LineEvent] {
        journey.events.filter { !hasPassed($0.departureDate, includingCurrentMinute: false, now: now) }
    }

    private var nextStop: LineEvent? {
        guard estimatedVehiclePosition(events: journey.events, segments: journey.segments, at: now) != nil else { return nil }
        return upcomingStops.first
    }

    private var skippedStopsCount: Int? {
        journey.events.isEmpty ? nil : journey.events.filter { $0.isCancelled == true }.count
    }
}

/// Un arrêt de la ligne sélectionné : les prochains passages de cette ligne à cet arrêt.
struct LineStopDeparturesPanel: View {
    @Environment(\.displayTime) private var now
    @Environment(\.openRoute) private var openRoute
    let stop: LineEvent
    let stopEvent: StopEvent
    let close: () -> Void
    @State private var stopManager = StopManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                StopNameView(stop.stopPointName, style: .row)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Fermer")
            }
            if let access = stop.quayAccess {
                InfoChip(text: access.label, systemImage: access.systemImage)
            }

            HStack {
                PaneSectionTitle(text: "Prochains passages")
                BusLineIcon(lineName: stopEvent.lineName, operatorName: stopEvent.operatorName)
            }
            if departures.isEmpty {
                Text(stopManager.stopError ? "Pas de passage trouvé" : "Recherche des passages…")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(departures) { departure in
                    HStack {
                        Image(systemName: "arrow.right").font(.caption)
                        StopNameView(departure.destination, style: .row)
                            .strikethrough(departure.cancelled)
                        Spacer()
                        DepartureTimeView(departureDisplay(for: departure, showTime: false, at: now), transportType: departure.transportType)
                        DepartureTimeView(departureDisplay(for: departure, showTime: true, at: now), transportType: departure.transportType, showsIcon: false)
                            .foregroundStyle(.secondary)
                        QuayIcon(quay: departure.plannedQuay)
                    }
                    .padding(.vertical, 6)
                    Divider()
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
    }

    /// Les passages de la même ligne ; dans la même direction quand l'arrêt en a d'autres.
    private var departures: [StopEvent] {
        let sameLine = stopManager.stopEvents.filter { $0.lineName == stopEvent.lineName }.sortedByDeparture()
        let sameDirection = sameLine.filter { $0.destination == stopEvent.destination }
        return Array((sameDirection.isEmpty ? sameLine : sameDirection).prefix(8))
    }
}

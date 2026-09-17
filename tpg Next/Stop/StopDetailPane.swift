//
//  StopDetailPane.swift
//  tpg Next
//
//  Moitié droite de la page arrêt sur grand écran : la carte en haut, en bas le départ
//  sélectionné ou, à défaut, les lignes et les quais de l'arrêt.
//

import SwiftUI
import MapKit
import tpgNextFunc

struct StopDetailPane: View {
    @Environment(\.displayTime) private var now
    let stopName: String
    let stopSloid: String
    let quays: [Quay]
    let departures: [StopEvent]
    let selected: StopEvent?
    let deselect: () -> Void

    /// Parcours du départ sélectionné, chargé à la sélection (pas avec la liste : 8 fois plus lourd).
    @State private var journey = JourneyTrackModel()

    var body: some View {
        VStack(spacing: 12) {
            StopMapPanel(stopSloid: stopSloid, quays: quays, selected: selected, journey: journey)
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .frame(maxHeight: .infinity)

            ScrollView {
                Group {
                    if let selected {
                        DepartureDetailPanel(event: selected, stopName: stopName, stopSloid: stopSloid,
                                             journey: journey, close: deselect)
                    } else {
                        StopInfoPanel(departures: departures)
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: .infinity)
            .background { BasicCard(cornerRadius: 30) }
        }
        .padding([.horizontal, .bottom])
        .padding(.top, 8)
        .periodicRefresh(id: selected?.journeyRef) { _ in
            if let selected {
                journey.load(selected)
            }
        }
    }
}

/// Carte de l'arrêt : ses quais, et le parcours du départ sélectionné.
struct StopMapPanel: View {
    @Environment(\.displayTime) private var now
    let stopSloid: String
    let quays: [Quay]
    let selected: StopEvent?
    let journey: JourneyTrackModel
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if let selected, !journey.events.isEmpty {
                JourneyMapContent(events: journey.events, segments: journey.segments, lineName: selected.lineName,
                                  operatorName: selected.operatorName, currentStopSloid: sloidHarmonizer(code: stopSloid), now: now)
            }
            ForEach(stopQuays) { quay in
                let isSelected = quay.quayName == selected?.plannedQuay
                Annotation(String(localized: "quai \(quay.quayName)"), coordinate: quay.coordinate, anchor: .center) {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: isSelected ? 4 : 2)
                        .background(Circle().fill(isSelected ? .accent : .color1))
                        .frame(width: isSelected ? 22 : 15, height: isSelected ? 22 : 15)
                }
            }
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        // Recadre sur les quais, ou sur tout le parcours quand il arrive.
        .onChange(of: selected?.journeyRef) { withAnimation { position = .automatic } }
        .onChange(of: journey.events.count) { withAnimation { position = .automatic } }
    }

    private var stopQuays: [Quay] {
        let parent = sloidHarmonizer(code: stopSloid)
        return quays.filter { sloidHarmonizer(code: $0.id) == parent }
    }
}

extension Quay {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: Double(latitude) ?? 0, longitude: Double(longitude) ?? 0)
    }
}

/// Le départ sélectionné : son heure, son quai, son véhicule, et ses prochains arrêts.
struct DepartureDetailPanel: View {
    @Environment(\.displayTime) private var now
    @Environment(\.openRoute) private var openRoute
    let event: StopEvent
    let stopName: String
    let stopSloid: String
    let journey: JourneyTrackModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                Image(systemName: "arrow.right")
                StopNameView(event.destination, style: .row)
                    .strikethrough(event.cancelled)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Fermer")
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Départ").font(.caption).foregroundStyle(.secondary)
                    DepartureTimeView(departureDisplay(for: event, showTime: false, at: now), transportType: event.transportType, layout: .inline(spacing: 4))
                        .font(.title2.bold())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heure").font(.caption).foregroundStyle(.secondary)
                    DepartureTimeView(departureDisplay(for: event, showTime: true, at: now), transportType: event.transportType, layout: .inline(spacing: 4), showsIcon: false)
                        .font(.title2.bold())
                }
                if !event.plannedQuay.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quai").font(.caption).foregroundStyle(.secondary)
                        QuayIcon(quay: event.plannedQuay).font(.title2)
                    }
                }
            }

            FlowChips(event: event)

            VStack(spacing: 0) {
                PaneSectionTitle(text: "Prochains arrêts")
                    .padding(.bottom, 8)
                if onwardStops.isEmpty {
                    Text("Chargement du parcours…")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(onwardStops) { stop in
                        Button {
                            openRoute(.stop(name: stop.stopPointName, sloid: stop.sloid,
                                            highlight: DepartureHighlight(journeyRef: event.journeyRef, lineName: event.lineName, time: stop.timetabledTime)))
                        } label: {
                            HStack {
                                StopNameView(stop.stopPointName, style: .row)
                                Spacer()
                                DepartureTimeView(departureDisplay(timetabled: stop.timetabledTime, estimated: stop.estimatedTime, showTime: true, at: now),
                                                  transportType: event.transportType, showsIcon: false)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                        Divider()
                    }
                }
            }

            Button {
                openRoute(.line(event: event, currentStop: ShortStop(name: stopName, sloid: sloidHarmonizer(code: stopSloid))))
            } label: {
                Label("Voir toute la course", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    /// Les arrêts après celui-ci sur la course.
    private var onwardStops: [LineEvent] {
        let parent = sloidHarmonizer(code: stopSloid)
        guard let index = journey.events.firstIndex(where: { $0.sloid == parent }) else { return [] }
        return Array(journey.events.dropFirst(index + 1))
    }
}

/// Les informations de service d'un départ, en capsules.
private struct FlowChips: View {
    let event: StopEvent

    var body: some View {
        let chips = HStack(spacing: 8) {
            if event.cancelled {
                InfoChip(text: "Course supprimée", systemImage: "exclamationmark.triangle.fill", tint: .red)
            }
            if let access = event.quayAccess {
                InfoChip(text: access.label, systemImage: access.systemImage)
            }
            if event.hasLowFloor {
                InfoChip(text: "Plancher bas", systemImage: "arrow.down.to.line")
            }
        }
        ViewThatFits(in: .horizontal) {
            chips
            ScrollView(.horizontal, showsIndicators: false) { chips }
        }
    }
}

/// Sans départ sélectionné : les lignes qui desservent l'arrêt et ses quais.
struct StopInfoPanel: View {
    let departures: [StopEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Touchez un départ pour voir son parcours.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                PaneSectionTitle(text: "Lignes")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 10) {
                    ForEach(lineGroups, id: \.key) { group in
                        HStack {
                            BusLineIcon(lineName: group.event.lineName, operatorName: group.event.operatorName)
                            Image(systemName: "arrow.right").font(.caption)
                            StopNameView(group.event.destination, style: .row)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                PaneSectionTitle(text: "Quais")
                ForEach(quayGroups, id: \.quay) { group in
                    HStack(alignment: .top, spacing: 12) {
                        QuayIcon(quay: group.quay).font(.title2)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                ForEach(group.lines, id: \.self) { line in
                                    BusLineIcon(lineName: line.lineName, operatorName: line.operatorName)
                                }
                            }
                            if let access = group.access {
                                Label(access.label, systemImage: access.systemImage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Divider()
                }
            }
        }
    }

    private var lineGroups: [(key: String, event: StopEvent)] {
        departures.groupedByLineAndDestination()
            .compactMap { key, events in events.first.map { (key, $0) } }
            .sorted { lineGroupPrecedes($0.key, $1.key) }
    }

    private struct LineRef: Hashable {
        let lineName: String
        let operatorName: String
    }

    private var quayGroups: [(quay: String, lines: [LineRef], access: QuayAccess?)] {
        Dictionary(grouping: departures.filter { !$0.plannedQuay.isEmpty }, by: \.plannedQuay)
            .map { quay, events in
                var seen = Set<LineRef>()
                let lines = events
                    .map { LineRef(lineName: $0.lineName, operatorName: $0.operatorName) }
                    .filter { seen.insert($0).inserted }
                    .sorted { lineGroupPrecedes($0.lineName, $1.lineName) }
                return (quay, lines, events.compactMap(\.quayAccess).first)
            }
            .sorted { $0.quay.localizedStandardCompare($1.quay) == .orderedAscending }
    }
}

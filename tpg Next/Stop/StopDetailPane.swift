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
    let showTime: Bool
    /// Filtres de la liste de gauche : groupes « ligne;destination » et quais.
    @Binding var lineFilters: Set<String>
    @Binding var quayFilters: Set<String>
    let select: (StopEvent) -> Void
    let deselect: () -> Void

    @Environment(\.openRoute) private var openRoute

    /// Parcours du départ sélectionné, chargé à la sélection (pas avec la liste : 8 fois plus lourd).
    @State private var journey = JourneyTrackModel()

    var body: some View {
        DetailPaneLayout(openFull: selected.map { event in { openFullJourney(event) } },
                         close: selected == nil ? nil : deselect,
                         expandMap: quays.isEmpty ? nil : { openRoute(.stopMap(quays: quays, sloid: stopSloid, name: stopName)) }) {
            StopMapPanel(stopSloid: stopSloid, quays: quays, selected: selected, journey: journey,
                         highlightedQuays: highlightedQuays, toggleQuay: toggleQuay)
        } title: {
            PaneTitleCapsule {
                HStack(spacing: 8) {
                    if let selected {
                        BusLineIcon(lineName: selected.lineName, operatorName: selected.operatorName)
                        Image(systemName: "arrow.right").font(.caption)
                        StopNameView(selected.destination, style: .row)
                            .strikethrough(selected.cancelled)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("Lignes et quais").font(.title3).bold()
                        Spacer(minLength: 0)
                    }
                }
            }
        } details: {
            Group {
                if let selected {
                    DepartureDetailPanel(event: selected, stopName: stopName, stopSloid: stopSloid,
                                         departures: departures, showTime: showTime, journey: journey,
                                         select: select)
                } else {
                    StopInfoPanel(departures: departures, lineFilters: $lineFilters, quayFilters: $quayFilters,
                                  toggleQuay: toggleQuay)
                }
            }
        }
        .periodicRefresh(id: selected?.journeyRef) { _ in
            if let selected {
                journey.load(selected)
            }
        }
    }

    /// Le titre mène à la course entière du départ affiché.
    private func openFullJourney(_ event: StopEvent) {
        openRoute(.line(event: event, currentStop: ShortStop(name: stopName, sloid: sloidHarmonizer(code: stopSloid))))
    }

    /// Quais mis en avant sur la carte : ceux filtrés, sinon ceux des lignes filtrées.
    private var highlightedQuays: Set<String> {
        if !quayFilters.isEmpty { return quayFilters }
        guard !lineFilters.isEmpty else { return [] }
        return Set(departures.filter { lineFilters.contains("\($0.lineName);\($0.destination)") }.map(\.plannedQuay))
    }

    private func toggleQuay(_ quay: String) {
        withAnimation {
            if quayFilters.contains(quay) {
                quayFilters.remove(quay)
            } else {
                quayFilters.insert(quay)
            }
        }
    }
}

/// La carte d'un arrêt : ses quais, et le parcours du départ sélectionné. La même dans la
/// moitié droite de la page arrêt et en plein écran (`StopMapView`), qui n'ajoute que le titre,
/// ses boutons et les départs du quai touché.
struct StopMapPanel: View {
    @Environment(\.displayTime) private var now
    let stopSloid: String
    let quays: [Quay]
    let selected: StopEvent?
    let journey: JourneyTrackModel
    /// Sans départ sélectionné, les quais mis en avant (filtrés, ou touché en plein écran).
    var highlightedQuays: Set<String> = []
    /// Toucher un quai, sans départ sélectionné : le filtre de la liste (moitié droite).
    var toggleQuay: ((String) -> Void)?
    /// Toucher un quai, en plein écran : ses départs. Prend le pas sur `toggleQuay`.
    var tapQuay: ((Quay) -> Void)?
    /// Le quai sur lequel zoomer ; `nil` : tout l'arrêt.
    var zoomedQuay: Quay?
    /// Les boutons de la carte (position, boussole) sont posés par la vue qui la contient,
    /// dans cette portée ; sans elle, en haut à droite de la carte.
    var controlsScope: Namespace.ID?
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if let controlsScope {
                Map(position: $position, scope: controlsScope) { content }
                    .mapControls {}
            } else {
                Map(position: $position) { content }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        // Recadre sur les quais, ou sur tout le parcours quand il arrive.
        .onChange(of: selected?.journeyRef) { withAnimation { position = .automatic } }
        .onChange(of: journey.events.count) { withAnimation { position = .automatic } }
        .onChange(of: zoomedQuay?.id) {
            withAnimation {
                position = zoomedQuay.map {
                    .region(MKCoordinateRegion(center: $0.coordinate,
                                               span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)))
                } ?? .automatic
            }
        }
    }

    @MapContentBuilder private var content: some MapContent {
        if let selected, !journey.events.isEmpty {
            JourneyMapContent(events: journey.events, segments: journey.segments, lineName: selected.lineName,
                              operatorName: selected.operatorName, currentStopSloid: sloidHarmonizer(code: stopSloid), now: now)
        }
        ForEach(stopQuays) { quay in
            let isSelected = selected.map { quay.quayName == $0.plannedQuay } ?? highlightedQuays.contains(quay.quayName)
            Annotation(String(localized: "quai \(quay.quayName)"), coordinate: quay.coordinate, anchor: .center) {
                Circle()
                    .strokeBorder(Color.primary, lineWidth: isSelected ? 4 : 2)
                    .background(Circle().fill(isSelected ? Color.accentColor : .color1))
                    .frame(width: isSelected ? 22 : 15, height: isSelected ? 22 : 15)
                    .animation(.bouncy, value: isSelected)
                    // Zone de toucher plus large que le point.
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .onTapGesture {
                        if let tapQuay {
                            tapQuay(quay)
                        } else if selected == nil {
                            toggleQuay?(quay.quayName)
                        }
                    }
            }
        }
        UserAnnotation()
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

/// Le départ sélectionné : son heure, son quai, son véhicule, les départs suivants de la ligne
/// et son parcours, présenté comme sur la page ligne.
struct DepartureDetailPanel: View {
    @Environment(\.displayTime) private var now
    @Environment(\.openRoute) private var openRoute
    let event: StopEvent
    let stopName: String
    let stopSloid: String
    /// Les départs de l'arrêt, pour les horaires suivants de la même ligne.
    let departures: [StopEvent]
    let showTime: Bool
    let journey: JourneyTrackModel
    let select: (StopEvent) -> Void

    @State private var showsPreviousStops = false
    @State private var busIsHere = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Départ").font(.caption).foregroundStyle(.secondary)
                    DepartureTimeView(departureDisplay(for: event, showTime: false, at: now), transportType: event.transportType, layout: .inline(spacing: 4))
                        .font(.title2.bold())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heure").font(.caption).foregroundStyle(.secondary)
                    // Supprimé : l'heure prévue, barrée. « Départ » dit déjà « Supprimé ».
                    if event.cancelled, let planned = OJPDate.date(from: event.timetabledTime) {
                        Text(OJPDate.clockTime(from: planned))
                            .strikethrough()
                            .foregroundStyle(.secondary)
                            .font(.title2.bold())
                    } else {
                        DepartureTimeView(departureDisplay(for: event, showTime: true, at: now), transportType: event.transportType, layout: .inline(spacing: 4), showsIcon: false)
                            .font(.title2.bold())
                    }
                }
                if !event.plannedQuay.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quai").font(.caption).foregroundStyle(.secondary)
                        QuayIcon(quay: event.plannedQuay).font(.title2)
                    }
                }
            }

            FlowChips(event: event)

            if event.cancelled, let alternative = nearestServedStop(skipping: currentSloid, in: journey.events, now: now) {
                ServedAlternativeCard(alternative: alternative, transportType: event.transportType) {
                    openRoute(.stop(name: alternative.stop.stopPointName, sloid: alternative.stop.sloid,
                                    highlight: DepartureHighlight(journeyRef: event.journeyRef, lineName: event.lineName, time: alternative.stop.timetabledTime)))
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                PaneSectionTitle(text: "Départs suivants")
                    .padding(.bottom, 4)
                if nextDepartures.isEmpty {
                    Text("Pas d'autre départ de cette ligne dans la liste.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(nextDepartures) { departure in
                        Button { select(departure) } label: {
                            StopEventView(event: departure, showTime: showTime)
                                .foregroundStyle(determineColor(for: departure.estimatedTime, now: now))
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                PaneSectionTitle(text: "Parcours")
                    .padding(.bottom, 4)
                if currentIndex == nil {
                    Text("Chargement du parcours…")
                        .foregroundStyle(.secondary)
                } else {
                    if previousCount > 0 {
                        Button {
                            withAnimation { showsPreviousStops.toggle() }
                        } label: {
                            Label(showsPreviousStops ? "Masquer les arrêts précédents" : "Afficher les \(previousCount) arrêts précédents",
                                  systemImage: showsPreviousStops ? "chevron.down" : "chevron.up")
                                .frame(maxWidth: .infinity)
                        }
                        .secondaryButtonStyle()
                        .padding(.bottom, 8)
                    }
                    ForEach(visibleStops) { stop in
                        Button {
                            openRoute(.stop(name: stop.stopPointName, sloid: stop.sloid,
                                            highlight: DepartureHighlight(journeyRef: event.journeyRef, lineName: event.lineName, time: stop.timetabledTime)))
                        } label: {
                            LineEventElementView(currentLine: event.lineName, operatorName: operatorName, transportType: event.transportType,
                                                 currentStop: stop.sloid == currentSloid, eventName: stop.stopPointName,
                                                 estimatedTime: stop.estimatedTime, timetabledTime: stop.timetabledTime,
                                                 plannedQuay: stop.plannedQuay, showTime: .constant(showTime),
                                                 skipped: stop.isCancelled == true)
                        }
                        .foregroundStyle(.primary)
                        .padding(.vertical, 5)
                        .background(
                            LineBackground(event: stop, firstEventId: journey.events.first?.id, lastEventId: journey.events.last?.id,
                                           lineColor: LineColors.lineColor(for: event.lineName, operatorName: operatorName), busIsHere: $busIsHere,
                                           trailX: 30, skipped: stop.isCancelled == true)
                        )
                    }
                }
            }

            Button {
                openRoute(.line(event: event, currentStop: ShortStop(name: stopName, sloid: currentSloid)))
            } label: {
                Label("Voir toute la course", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .frame(maxWidth: .infinity)
            }
            .prominentButtonStyle()
        }
        // Autre départ : le parcours repart replié.
        .onChange(of: event.journeyRef) {
            showsPreviousStops = false
            busIsHere = false
        }
    }

    private var currentSloid: String { sloidHarmonizer(code: stopSloid) }

    private var operatorName: String {
        journey.operatorName.isEmpty ? event.operatorName : journey.operatorName
    }

    private var currentIndex: Int? {
        journey.events.firstIndex { $0.sloid == currentSloid }
    }

    private var previousCount: Int { currentIndex ?? 0 }

    /// Depuis cet arrêt jusqu'au terminus ; depuis le départ de la course une fois déplié.
    private var visibleStops: [LineEvent] {
        guard let currentIndex else { return [] }
        return Array(journey.events.dropFirst(showsPreviousStops ? 0 : currentIndex))
    }

    /// Les départs suivants de la même ligne vers la même destination, dans la liste de l'arrêt.
    private var nextDepartures: [StopEvent] {
        let after = event.departureDate ?? .distantPast
        return Array(departures
            .filter { $0.lineName == event.lineName && $0.destination == event.destination && $0.id != event.id }
            .filter { ($0.departureDate ?? .distantFuture) >= after }
            .sortedByDeparture()
            .prefix(4))
    }
}

/// Les informations de service d'un départ, en capsules.
private struct FlowChips: View {
    let event: StopEvent

    var body: some View {
        let chips = HStack(spacing: 8) {
            // `cancelled` ne dit que l'arrêt affiché : la course peut rouler ailleurs.
            if event.cancelled {
                InfoChip(text: "Ne passe pas à cet arrêt", systemImage: "exclamationmark.triangle.fill", tint: .red)
            } else if event.routeChanged {
                InfoChip(text: "Parcours modifié", systemImage: "exclamationmark.triangle.fill", tint: .orange)
            }
            if event.exceptional {
                InfoChip(text: "Horaire exceptionnel", systemImage: "calendar.badge.exclamationmark", tint: .orange)
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

/// Sans départ sélectionné : les lignes qui desservent l'arrêt et ses quais. Les toucher
/// filtre la liste des départs.
struct StopInfoPanel: View {
    let departures: [StopEvent]
    @Binding var lineFilters: Set<String>
    @Binding var quayFilters: Set<String>
    let toggleQuay: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Touchez une ligne ou un quai pour filtrer les départs, un départ pour voir son parcours.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    PaneSectionTitle(text: "Lignes")
                    if !lineFilters.isEmpty {
                        Button("Toutes") { withAnimation { lineFilters = [] } }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 10) {
                    ForEach(lineGroups, id: \.key) { group in
                        let isOn = lineFilters.contains(group.key)
                        Button {
                            withAnimation {
                                if isOn { lineFilters.remove(group.key) } else { lineFilters.insert(group.key) }
                            }
                        } label: {
                            HStack {
                                BusLineIcon(lineName: group.event.lineName, operatorName: group.event.operatorName)
                                Image(systemName: "arrow.right").font(.caption)
                                StopNameView(group.event.destination, style: .row)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(filterBackground(isOn: isOn))
                            .opacity(lineFilters.isEmpty || isOn ? 1 : 0.5)
                            .contentShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    PaneSectionTitle(text: "Quais")
                    if !quayFilters.isEmpty {
                        Button("Tous") { withAnimation { quayFilters = [] } }
                    }
                }
                ForEach(quayGroups, id: \.quay) { group in
                    let isOn = quayFilters.contains(group.quay)
                    Button {
                        toggleQuay(group.quay)
                    } label: {
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
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(filterBackground(isOn: isOn))
                        .opacity(quayFilters.isEmpty || isOn ? 1 : 0.5)
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    private func filterBackground(isOn: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(isOn ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
            .strokeBorder(isOn ? Color.accentColor : .clear, lineWidth: 1.5)
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

#Preview("Panneau arrêt — lignes et quais", traits: .fixedLayout(width: 560, height: 820)) {
    @Previewable @State var lineFilters: Set<String> = []
    @Previewable @State var quayFilters: Set<String> = []
    StopDetailPane(stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid, quays: PreviewData.quays,
                   departures: PreviewData.departures, selected: nil, showTime: false,
                   lineFilters: $lineFilters, quayFilters: $quayFilters, select: { _ in }, deselect: {})
        .previewEnvironment(navigation: false)
}

#Preview("Panneau arrêt — départ sélectionné (API)", traits: .fixedLayout(width: 560, height: 820)) {
    @Previewable @State var lineFilters: Set<String> = []
    @Previewable @State var quayFilters: Set<String> = []
    // Le panneau charge lui-même la course : il lui faut un départ du jour.
    LiveDeparturePreview { departures in
        StopDetailPane(stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid, quays: departures.quays,
                       departures: departures.all, selected: departures.event, showTime: false,
                       lineFilters: $lineFilters, quayFilters: $quayFilters, select: { _ in }, deselect: {})
    }
    .previewEnvironment(navigation: false)
}

#Preview("Détail d'un départ", traits: .fixedLayout(width: 520, height: 700)) {
    @Previewable @State var event = PreviewData.lineDeparture
    @Previewable @State var journey = PreviewData.journeyModel()
    ScrollView {
        DepartureDetailPanel(event: event, stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid,
                             departures: PreviewData.departures, showTime: false, journey: journey,
                             select: { event = $0 })
            .padding(20)
    }
    .padding()
    .previewEnvironment()
}

#Preview("Carte de l'arrêt", traits: .fixedLayout(width: 520, height: 420)) {
    @Previewable @State var highlighted: Set<String> = ["B", "C"]
    StopMapPanel(stopSloid: PreviewData.rive.sloid, quays: PreviewData.quays, selected: nil,
                 journey: JourneyTrackModel(), highlightedQuays: highlighted) { quay in
        if highlighted.contains(quay) { highlighted.remove(quay) } else { highlighted.insert(quay) }
    }
    .clipShape(RoundedRectangle(cornerRadius: 30))
    .padding()
    .previewEnvironment(navigation: false)
}

#Preview("Carte de l'arrêt — parcours du départ", traits: .fixedLayout(width: 520, height: 420)) {
    StopMapPanel(stopSloid: PreviewData.rive.sloid, quays: PreviewData.quays, selected: PreviewData.lineDeparture,
                 journey: PreviewData.journeyModel())
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .padding()
        .previewEnvironment(navigation: false)
}

#Preview("Lignes et quais", traits: .fixedLayout(width: 520, height: 600)) {
    @Previewable @State var lineFilters: Set<String> = []
    @Previewable @State var quayFilters: Set<String> = []
    ScrollView {
        StopInfoPanel(departures: PreviewData.departures, lineFilters: $lineFilters, quayFilters: $quayFilters) { quay in
            if quayFilters.contains(quay) { quayFilters.remove(quay) } else { quayFilters.insert(quay) }
        }
        .padding(20)
    }
    .previewEnvironment(navigation: false)
}

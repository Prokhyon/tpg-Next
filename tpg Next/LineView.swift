//
//  NewLineView.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Foundation
import Combine
import tpgNextFunc

struct LineViewTitle: View {
    var destination: String
    var currentLine: String
    var operatorName: String
    
    var body: some View {
        VStack(alignment: .leading) {
                HStack {
                    Text("Ligne ")
                        .font(.largeTitle)
                        .bold()
                    BusLineIcon(lineName: currentLine, operatorName: operatorName)
//                    Spacer()
                }
                HStack {
                    Image(systemName: "arrow.right")
                    eventStopName(stopName: destination)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
//                    Spacer()
            }
        }
//            .padding(.leading, 30)
    }
}

/// Le titre de ligne flottant en haut de la liste et de la carte.
struct FloatingLineTitle: View {
    var destination: String
    var currentLine: String
    var operatorName: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(.clear)
                .frame(width: 50, height: 1)
            LineViewTitle(destination: destination, currentLine: currentLine, operatorName: operatorName)
                .glassForegroundStyle(Color.text)
            Rectangle()
                .fill(.clear)
                .frame(maxWidth: 50, maxHeight: 1)
        }
        .padding(10)
        .tpgSurface(legacy: .thinMaterial)
    }
}

struct LineView: View {
    @Environment(\.displayTime) private var now
    /// Arrêts de la course ; avec le tracé quand la carte est à l'écran (grand écran).
    @State private var journey = JourneyTrackModel()
    @Environment(\.layout) private var layout
    /// Sur grand écran, l'arrêt dont la moitié droite montre les prochains passages.
    @State private var selectedStop: LineEvent?
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(\.openRoute) private var openRoute
    @Environment(\.departureActions) private var departureActions
    var autoRefresh: Bool = true
    
    var stopEvent: StopEvent
    var currentStop: ShortStop?
    /// La descente d'un trajet qui emprunte cette course : la portion parcourue, de
    /// `currentStop` (la montée) à elle, est mise en avant.
    var alightStop: ShortStop? = nil
    var currentLine: String
    
    private var operatorName: String { journey.operatorName }
    private var lineColor: Color {
        journey.events.isEmpty ? .primary : LineColors.lineColor(for: currentLine, operatorName: operatorName)
    }
    
    @State private var scrollDone = false
    @State private var showTime = false
    private var lineEvents: [LineEvent] { journey.events }
    /// Blocs d'arrêts sautés dont l'utilisateur a inversé l'état (replié ou déplié).
    @State private var expandedSkippedBlocks: Set<String> = []
    /// Hauteur du titre flottant : la liste commence dessous, même avec un texte agrandi.
    /// Bas du titre flottant et haut de la liste, dans le repère de la colonne : la liste
    /// commence sous le titre, quels que soient les décalages de la barre (grand écran).
    @State private var titleBottom: CGFloat = 0
    @State private var listTop: CGFloat = 0
    private static let columnSpace = "lineColumn"

    var body: some View {
        AdaptiveSplit(topGapReduction: 48) {
            GeometryReader { geometry in
                ZStack {
                    
                    //Events view
                    VStack {
//                        Rectangle()
//                            .frame(height: 15)
//                            .opacity(0.0)
                        ScrollViewReader { scroll in
                            ScrollView {
                                let range = tripRange
                                LazyVStack {
                                    // La course est attendue : ses arrêts en rangées fantômes.
                                    if lineEvents.isEmpty {
                                        LoadingPlaceholder(kind: .stop, count: 8)
                                    }
                                    ForEach(journeyRows(lineEvents)) { row in
                                        switch row {
                                        case .stop(let event):
                                            stopRow(event, range: range, scroll: scroll)
                                        case .skipped(let stops):
                                            skippedBlock(stops, range: range, scroll: scroll)
                                        }
                                    }
                                }
                            }
                            .contentMargins(.top, max(95.0, titleBottom - listTop + 14), for: .automatic)
                            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.columnSpace)).minY + $0.safeAreaInsets.top } action: { listTop = $0 }
                            .readableScrollContent()
                            .refreshable {
                                getLineEvents(for: stopEvent)
                            }
                            // Sur iPhone : le départ ne passe pas à l'arrêt d'où la course a été
                            // ouverte. Sur grand écran, la moitié droite le dit déjà.
                            .safeAreaInset(edge: .bottom) {
                                VStack(alignment: .trailing, spacing: 8) {
                                    if !layout.showsSecondaryPane, stopEvent.cancelled, let currentStop,
                                       let alternative = nearestServedStop(skipping: currentStop.sloid, in: lineEvents, now: now) {
                                        ServedAlternativeCard(alternative: alternative, transportType: stopEvent.transportType) {
                                            openRoute(.stop(name: alternative.stop.stopPointName, sloid: alternative.stop.sloid,
                                                            highlight: DepartureHighlight(journeyRef: stopEvent.journeyRef, lineName: currentLine, time: alternative.stop.timetabledTime)))
                                        }
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                                    }
                                    // En bas à droite, sous le pouce, comme sur la page d'un itinéraire.
                                    // Course déjà suivie : le même bouton l'arrête.
                                    let trackedKey = TripLiveActivities.shared.trackedKey(forJourney: stopEvent.journeyRef)
                                    if trackedKey != nil || (TripLiveActivities.shared.areEnabled && !stopEvent.journeyRef.isEmpty) {
                                        HStack {
                                            Spacer()
                                            LiveTrackingButton(isTracking: trackedKey != nil) {
                                                if let trackedKey {
                                                    TripLiveActivities.shared.stop(trackedKey)
                                                } else {
                                                    departureActions.track(stopEvent, currentStop?.sloid ?? stopEvent.stopId, true)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    .periodicRefresh(repeats: autoRefresh) { _ in
                        getLineEvents(for: stopEvent)
                    }
                    
                    LegacyTopFade()
                    //Top card
                    VStack {
                        HStack {
                        FloatingLineTitle(destination: stopEvent.destination, currentLine: currentLine, operatorName: operatorName)
                            .offset(x: -50)
                            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.columnSpace)).maxY } action: { titleBottom = $0 }
                            Spacer()
                        }
                        Spacer()
                    }
                    
                }
                .coordinateSpace(.named(Self.columnSpace))
            }
        } secondary: {
            LineDetailPane(stopEvent: stopEvent, currentStopSloid: currentStop?.sloid, journey: journey, selectedStop: selectedStop) {
                withAnimation { selectedStop = nil }
            }
        }
        // Le tracé n'est demandé qu'une fois la carte affichée (fenêtre élargie en cours de route).
        .onChange(of: layout.showsSecondaryPane) {
            getLineEvents(for: stopEvent)
        }
        .toolbar {
//            Button(action: {
//                showTime.toggle()
//            }) {
//                Image(systemName: "hourglass")
//                    .foregroundColor(showTime ? .text : .white)
//                    .padding(.horizontal, 10)
//                    .padding(.vertical, 15)
//            }
//            .background {
//                Capsule()
//                    .foregroundStyle(showTime ? .clear : .accent)
//                    .padding(.horizontal, 5)
//                    .padding(.vertical, 2)
//            }
            // Le suivi en direct est en bas à droite de la liste (`LiveTrackingButton`).
            TrailingBarButtons(showTime: $showTime) {
                // Sur grand écran, la carte est déjà là : son plein écran est sur elle.
                if !layout.showsSecondaryPane {
                    Button {
                        openRoute(.lineMap(events: lineEvents, operatorName: operatorName, event: stopEvent, currentStopSloid: currentStop?.sloid))
                    } label: {
                        Label("Carte de la ligne", systemImage: "map")
                    }
                }
            }
        }
        .navigationTitle("Ligne \(currentLine)") // Set back button text
        .navigationBarTitleDisplayMode(.inline)
        // Le titre de la barre ne sert qu'au bouton retour : la page a le sien. Un titre vide
        // plutôt que `.toolbar(removing: .title)` : le décalage vers le haut d'`AdaptiveSplit`
        // (`topGapReduction`) est réglé sur cette barre ; sans titre, elle compte moins haut sur
        // iPad, et le titre flottant et la carte passaient sous les onglets.
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
            }
        }
    }

    /// La portion d'un trajet sur la course, par `LineEvent.id` : la montée, la descente, et
    /// tous les arrêts de l'une à l'autre. `nil` hors d'un trajet, ou si l'un des deux manque.
    private var tripRange: TripRange? {
        guard let currentStop, let alightStop else { return nil }
        func stop(_ event: LineEvent) -> String {
            sloidHarmonizer(code: event.sloid.isEmpty ? event.stopPlaceRef : event.sloid)
        }
        let board = sloidHarmonizer(code: currentStop.sloid)
        let alight = sloidHarmonizer(code: alightStop.sloid)
        let boards = lineEvents.indices.filter { stop(lineEvents[$0]) == board }
        // Une course peut passer deux fois au même arrêt (boucle) : l'heure de montée départage.
        let boardTime = OJPDate.date(from: stopEvent.timetabledTime)
        guard let boardIndex = boards.first(where: { boardTime != nil && OJPDate.date(from: lineEvents[$0].timetabledTime) == boardTime }) ?? boards.first,
              let alightIndex = lineEvents.indices.first(where: { $0 > boardIndex && stop(lineEvents[$0]) == alight }) else { return nil }
        return TripRange(board: lineEvents[boardIndex].id, alight: lineEvents[alightIndex].id,
                         inside: Set(lineEvents[boardIndex...alightIndex].map(\.id)),
                         after: Set(lineEvents[(alightIndex + 1)...].map(\.id)))
    }

    /// Un arrêt de la course, avec son trait de ligne. Dans un trajet, la montée et la descente
    /// sont mises en avant ; les arrêts d'avant la montée s'effacent, ceux d'après la descente
    /// gardent leur texte, sur un trait en points.
    private func stopRow(_ event: LineEvent, range: TripRange?, scroll: ScrollViewProxy) -> some View {
        let skipped = event.isCancelled == true
        let role: LocalizedStringKey? = event.id == range?.board ? "Montée" : event.id == range?.alight ? "Descente" : nil
        let isCurrent = range.map { event.id == $0.board || event.id == $0.alight } ?? (event.sloid == currentStop?.sloid)
        let after = range?.after.contains(event.id) ?? false
        let before = range.map { !$0.inside.contains(event.id) && !after } ?? false
        return stopLink(event) {
            LineEventElementView(currentLine: currentLine, operatorName: operatorName, transportType: stopEvent.transportType, currentStop: isCurrent, selected: event.id == selectedStop?.id, eventName: event.stopPointName, estimatedTime: event.estimatedTime, timetabledTime: event.timetabledTime, plannedQuay: event.plannedQuay, showTime: $showTime, skipped: skipped, role: role, dimmed: before)
        }
        .foregroundStyle(.primary)
        .onAppear {
            if !scrollDone {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        if let target = range?.board ?? currentStop.map({ $0.sloid + stopEvent.timetabledTime }) {
                            scroll.scrollTo(target, anchor: UnitPoint(x: 0.0, y: 0.05))
                            scrollDone = true
                        }
                    }
                }
            }
        }
        .contentShape(.contextMenuPreview, Capsule())
        .padding(.horizontal, 15)
        .padding(.vertical, 5)
        // Pas de rappel pour un arrêt où le véhicule ne passe pas.
        .if(!skipped && !hasPassed(event.departureDate, includingCurrentMinute: false, now: now)) { view in
            view.contextMenu {
                NotificationContextMenu(event: StopEvent(stopPointName: event.stopPointName, stopId: event.sloid, plannedQuay: event.plannedQuay, timetabledTime: event.timetabledTime, estimatedTime: event.estimatedTime, lineName: currentLine, origin: stopEvent.origin, destination: stopEvent.destination, transportType: stopEvent.transportType, operatorName: operatorName, journeyRef: stopEvent.journeyRef, operatingDayRef: stopEvent.operatingDayRef), stopID: event.sloid, itinerary: true)
            }
        }
        .background(
            LineBackground(event: event, firstEventId: lineEvents.first?.id, lastEventId: lineEvents.last?.id,
                           lineColor: before ? lineColor.mix(with: Color(uiColor: .systemBackground), by: 0.65) : lineColor,
                           skipped: skipped, dashed: after ? .all : event.id == range?.alight ? .below : .none,
                           previous: servedPassage(before: event), next: servedPassage(after: event))
        )
        .id(event.id)
    }

    /// Le passage au premier arrêt desservi avant (ou après) celui-ci : là où le véhicule était
    /// (ou sera), pour faire avancer le trait entre les deux. Un arrêt sauté n'a pas d'heure qui vaille.
    private func servedPassage(before event: LineEvent) -> Date? {
        guard let index = lineEvents.firstIndex(where: { $0.id == event.id }) else { return nil }
        return lineEvents[..<index].last { $0.isCancelled != true }?.departureDate
    }

    private func servedPassage(after event: LineEvent) -> Date? {
        guard let index = lineEvents.firstIndex(where: { $0.id == event.id }) else { return nil }
        return lineEvents[(index + 1)...].first { $0.isCancelled != true }?.departureDate
    }

    /// Plusieurs arrêts sautés d'affilée, repliés en un bloc. Déplié d'office s'il contient
    /// l'arrêt d'où la course a été ouverte : c'est lui que l'utilisateur cherche.
    @ViewBuilder private func skippedBlock(_ stops: [LineEvent], range: TripRange?, scroll: ScrollViewProxy) -> some View {
        let id = JourneyRow.skipped(stops).id
        let containsCurrent = stops.contains { $0.sloid == currentStop?.sloid }
        let expanded = expandedSkippedBlocks.contains(id) != containsCurrent
        Button {
            withAnimation {
                if expandedSkippedBlocks.remove(id) == nil {
                    expandedSkippedBlocks.insert(id)
                }
            }
        } label: {
            SkippedStopsRow(stops: stops, expanded: expanded)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 15)
        .padding(.vertical, 5)
        .background(
            LineBackground(event: stops[0], lineColor: lineColor, skipped: true)
        )
        if expanded {
            ForEach(stops) { stopRow($0, range: range, scroll: scroll) }
        }
    }

    func findDatabaseItem(for id: String, in activeStops: [Stop]) -> Stop? {
        return activeStops.first { $0.id == id }
    }

    
    func getLineEvents(for stopEvent: StopEvent) {
        journey.load(stopEvent, includeTrack: layout.showsSecondaryPane)
    }

    /// Sur iPhone, un arrêt ouvre sa page ; sur grand écran, ses passages s'affichent à droite.
    @ViewBuilder private func stopLink<Label: View>(_ event: LineEvent, @ViewBuilder label: () -> Label) -> some View {
        if layout.showsSecondaryPane {
            // Retoucher l'arrêt détaillé le désélectionne.
            Button(action: { withAnimation { selectedStop = selectedStop?.id == event.id ? nil : event } }, label: label)
        } else {
            NavigationLink(value: AppRoute.stop(name: event.stopPointName, sloid: event.sloid,
                                                highlight: DepartureHighlight(journeyRef: stopEvent.journeyRef, lineName: currentLine, time: event.timetabledTime)),
                           label: label)
        }
    }
}

/// La portion d'un trajet sur une course, par `LineEvent.id`.
struct TripRange {
    var board: String
    var alight: String
    var inside: Set<String>
    /// Les arrêts après la descente.
    var after: Set<String>
}

struct LineBackground: View {
    @Environment(\.displayTime) private var now
    var event: LineEvent
    var firstEventId: String?
    var lastEventId: String?
    var lineColor: Color
    /// Abscisse du trait, alignée sur les points d'arrêt de la rangée.
    var trailX: CGFloat = 45
    /// Arrêt sauté : le véhicule n'y passe pas, le trait est en pointillé.
    var skipped = false
    /// Au-delà de la descente d'un trajet : le véhicule continue sans le voyageur, le trait est
    /// en points de la couleur de la ligne (sous l'arrêt seulement, pour la descente).
    var dashed: DashedPart = .none
    /// Les passages aux arrêts voisins (desservis). Connus, la limite entre parcouru (pâle) et à
    /// venir (plein) avance avec le temps entre deux arrêts ; sinon, elle saute à chaque passage.
    var previous: Date? = nil
    var next: Date? = nil

    enum DashedPart {
        case none, below, all
    }

    /// Le trait parcouru : la couleur de la ligne pâlie, mais opaque. Semi-transparents, deux
    /// bouts de trait qui se chevauchent entre deux rangées se voyaient plus foncés.
    private var fadedColor: Color { lineColor.mix(with: Color(uiColor: .systemBackground), by: 0.7) }

    var body: some View {
        // Le véhicule entre l'arrêt précédent et le suivant : la limite avance toutes les deux
        // secondes. Ailleurs, l'heure de l'app (15 s) suffit.
        if let start = previous ?? event.departureDate, let end = next ?? event.departureDate,
           now >= start.addingTimeInterval(-15), now <= end.addingTimeInterval(15) {
            TimelineView(.periodic(from: .now, by: 2)) { context in
                trait(at: AppClock.shifted(context.date))
            }
        } else {
            trait(at: now)
        }
    }

    private func trait(at now: Date) -> some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let half = height / 2 + 4
            let isFirst = event.id == firstEventId
            let isLast = event.id == lastEventId
            if skipped {
                Path { path in
                    path.move(to: CGPoint(x: trailX, y: -4))
                    path.addLine(to: CGPoint(x: trailX, y: height + 4))
                }
                .stroke(lineColor.opacity(0.4), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 10]))
            } else if dashed == .all {
                dashes(from: isFirst ? height / 2 : -4, to: isLast ? height / 2 : height + 4, at: now)
            } else {
                if !isFirst {
                    halfTrait(top: -4, height: half, passed: upperProgress(at: now))
                }
                if dashed == .below {
                    if !isLast { dashes(from: height / 2, to: height + 4, at: now) }
                } else if !isLast {
                    halfTrait(top: height / 2, height: half, passed: lowerProgress(at: now))
                }
            }
        }
    }

    /// La moitié haute : la seconde moitié du tronçon depuis l'arrêt précédent (0 à 1).
    private func upperProgress(at now: Date) -> Double {
        guard let previous, let time = event.departureDate else {
            return hasPassed(event.departureDate, includingCurrentMinute: true, now: now) ? 1 : 0
        }
        return progress(from: previous, to: time, at: now) * 2 - 1
    }

    /// La moitié basse : la première moitié du tronçon vers l'arrêt suivant (0 à 1).
    private func lowerProgress(at now: Date) -> Double {
        guard let next, let time = event.departureDate else {
            return hasPassed(event.departureDate, includingCurrentMinute: false, now: now) ? 1 : 0
        }
        return progress(from: time, to: next, at: now) * 2
    }

    /// La part écoulée d'un tronçon, de 0 (au départ) à 1 (à l'arrivée).
    private func progress(from start: Date, to end: Date, at now: Date) -> Double {
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return now >= end ? 1 : 0 }
        return now.timeIntervalSince(start) / span
    }

    /// Une demi-hauteur de trait : pâle sur la part `passed` (depuis le haut), pleine dessous.
    private func halfTrait(top: CGFloat, height: CGFloat, passed: Double) -> some View {
        let faded = height * min(max(passed, 0), 1)
        return VStack(spacing: 0) {
            Rectangle().fill(fadedColor).frame(height: faded)
            Rectangle().fill(lineColor)
        }
        .frame(width: 7, height: height)
        .position(x: trailX, y: top + height / 2)
    }

    /// Le trait en points, de `from` à `to` dans la rangée.
    private func dashes(from top: CGFloat, to bottom: CGFloat, at now: Date) -> some View {
        Path { path in
            path.move(to: CGPoint(x: trailX, y: top))
            path.addLine(to: CGPoint(x: trailX, y: bottom))
        }
        .stroke(hasPassed(event.departureDate, includingCurrentMinute: false, now: now) ? fadedColor : lineColor,
                // Des points, comme la marche dans la frise d'un itinéraire (`TripTimeline`).
                style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [0, 10]))
    }
}

struct LineEventElementView: View {
    @Environment(\.displayTime) private var now
    var currentLine: String
    var operatorName: String
    var transportType: String
    var currentStop: Bool = false
    var selected: Bool = false
    var eventName: String
    var estimatedTime: String
    var timetabledTime: String
    var plannedQuay: String
    @Binding var showTime: Bool
    var pastEventPossible: Bool = true //If the event is in the past, it will become grey.
    var geoPositionDisplay: Bool = false //Changes the name display type
    var displayIcon: Bool = true //Display a transport icon if event time equals current time
    /// Arrêt sauté (`NotServicedStop`) : nom barré, « Non desservi » à la place de l'heure.
    var skipped = false
    /// Ce qu'on y fait dans un trajet (« Montée », « Descente »), sous le nom.
    var role: LocalizedStringKey? = nil
    /// Hors du trajet (avant la montée) : le contenu s'efface comme un passage passé, pas le
    /// fond, sous lequel le trait de la ligne se verrait.
    var dimmed = false
    
    var body: some View {
//        RoundedRectangle(cornerRadius: 20)
//        Capsule()
//            .stroke(currentStop ? .accent : .border, lineWidth: 1)
//            .fill(.thinMaterial)
//            .fill(.color1)
                HStack {
                    StopIcon(color: LineColors.lineColor(for: currentLine, operatorName: operatorName, inverted: true), currentStop: currentStop)
                    if geoPositionDisplay {
                        // Une adresse (celle de « Ma position ») peut être longue : elle rétrécit
                        // plutôt que de se couper, avec de l'air au-dessus et au-dessous.
                        Text(eventName)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .padding(.vertical, 8)
                    } else if let role {
                        VStack(alignment: .leading, spacing: 0) {
                            SmallStopTitleView(stopName: eventName)
                                .strikethrough(skipped)
                            Text(role)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        .padding(.vertical, 4)
                    } else {
                        SmallStopTitleView(stopName: eventName)
                            .strikethrough(skipped)
                    }
                    Spacer()
                    if skipped {
                        Text("Non desservi")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        timeAndQuay
                    }
                }
                    .foregroundStyle(.primary)
//                .foregroundStyle(pastEventPossible ? determineColor(for: estimatedTime): .primary)
                    // Même règle que le trait de la ligne : sans temps réel, l'heure prévue.
                    .opacity(skipped || dimmed ? 0.5 : pastEventPossible && hasPassed(OJPDate.date(from: estimatedTime) ?? OJPDate.date(from: timetabledTime), includingCurrentMinute: false, now: now) ? 0.3 : 1)
                .padding(.horizontal)
                .basicElementBackground(minHeight: 45, highlighted: currentStop, selected: selected)
                .padding(5)
    }

    @ViewBuilder private var timeAndQuay: some View {
                    let transportTime = departureDisplay(timetabled: timetabledTime, estimated: estimatedTime, showTime: showTime, at: now)
                    DepartureTimeView(transportTime, transportType: transportType, iconWidth: 10, showsIcon: displayIcon)
                        .padding(.vertical, 4)
                    if plannedQuay == "ignore" { // Étape d'itinéraire sans transport : pas de quai
                        Image(systemName: "dot.square.fill")
                    } else {
                        QuayIcon(quay: plannedQuay)
                    }
    }
}

/// Bloc replié des arrêts sautés d'affilée : leur nombre, le premier et le dernier.
struct SkippedStopsRow: View {
    let stops: [LineEvent]
    let expanded: Bool

    var body: some View {
        HStack {
            Image(systemName: "nosign")
                .font(.body.bold())
                .foregroundStyle(.red)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(stops.count) arrêts non desservis")
                    .font(.subheadline.bold())
                if let first = stops.first, let last = stops.last {
                    Text(route: first.stopPointName, to: last.stopPointName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.down")
                .rotationEffect(.degrees(expanded ? 180 : 0))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .basicElementBackground(minHeight: 45)
        .padding(5)
        .accessibilityElement(children: .combine)
        .accessibilityHint(expanded ? "Masquer ces arrêts" : "Afficher ces arrêts")
    }
}

// La page ligne charge elle-même sa course : une course enregistrée n'existe plus côté API,
// ces aperçus partent donc d'un vrai départ du jour à Genève, Rive.

#Preview("Ligne") {
    LiveDeparturePreview { departures in
        LineView(autoRefresh: false, stopEvent: departures.event,
                 currentStop: ShortStop(name: PreviewData.rive.name, sloid: PreviewData.rive.sloid),
                 currentLine: departures.event.lineName)
    }
    .previewEnvironment()
}

#Preview("Ligne — tram 12") {
    LiveDeparturePreview(pick: { $0.first { $0.lineName == "12" && !$0.cancelled } }) { departures in
        LineView(autoRefresh: false, stopEvent: departures.event,
                 currentStop: ShortStop(name: PreviewData.rive.name, sloid: PreviewData.rive.sloid),
                 currentLine: departures.event.lineName)
    }
    .previewEnvironment()
}

#Preview("Ligne — iPad", traits: .iPadLandscape) {
    LiveDeparturePreview { departures in
        LineView(autoRefresh: false, stopEvent: departures.event,
                 currentStop: ShortStop(name: PreviewData.rive.name, sloid: PreviewData.rive.sloid),
                 currentLine: departures.event.lineName)
    }
    .previewEnvironment()
}

#Preview("Parcours — données d'exemple") {
    // La liste de la page ligne, hors ligne : ligne 29, Genève, Rive dans 4 min.
    @Previewable @State var showTime = false
    let stops = PreviewData.journeyStops
    let color = LineColors.lineColor(for: "29", operatorName: "Transports Publics Genevois")
    ScrollView {
        LazyVStack {
            ForEach(stops) { stop in
                LineEventElementView(currentLine: "29", operatorName: "Transports Publics Genevois", transportType: "Bus",
                                     currentStop: stop.sloid == PreviewData.rive.sloid, eventName: stop.stopPointName,
                                     estimatedTime: stop.estimatedTime, timetabledTime: stop.timetabledTime,
                                     plannedQuay: stop.plannedQuay, showTime: $showTime)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 5)
                    .background(
                        LineBackground(event: stop, firstEventId: stops.first?.id, lastEventId: stops.last?.id,
                                       lineColor: color)
                    )
            }
        }
    }
    .safeAreaInset(edge: .top) {
        FloatingLineTitle(destination: "Versoix, La Scie", currentLine: "29", operatorName: "Transports Publics Genevois")
    }
    .previewEnvironment(navigation: false)
}

#Preview("Arrêt de ligne — cas") {
    let at = { (minutes: Double) in OJPDate.string(from: PreviewData.now.addingTimeInterval(minutes * 60)) }
    VStack(spacing: 0) {
        LineEventElementView(currentLine: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                             eventName: "Genève, Bel-Air", estimatedTime: at(-6), timetabledTime: at(-7), plannedQuay: "A",
                             showTime: .constant(false))
        LineEventElementView(currentLine: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                             eventName: "Genève, Molard", estimatedTime: at(0), timetabledTime: at(0), plannedQuay: "B",
                             showTime: .constant(false))
        LineEventElementView(currentLine: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                             currentStop: true, eventName: "Genève, Rive", estimatedTime: at(3), timetabledTime: at(2),
                             plannedQuay: "B", showTime: .constant(false))
        LineEventElementView(currentLine: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                             eventName: "Genève, Terrassière", estimatedTime: at(6), timetabledTime: at(6), plannedQuay: "C",
                             showTime: .constant(true))
        LineEventElementView(currentLine: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                             eventName: "Marcher jusqu'à l'arrêt", estimatedTime: at(8), timetabledTime: at(8),
                             plannedQuay: "ignore", showTime: .constant(false), geoPositionDisplay: true)
    }
    .previewEnvironment(navigation: false)
}

#Preview("Arrêt de ligne — bac à sable") {
    @Previewable @State var line = "12"
    @Previewable @State var name = "Genève, Rive"
    @Previewable @State var quay = "B"
    @Previewable @State var minutes = 3.0
    @Previewable @State var delay = 0.0
    @Previewable @State var current = true
    @Previewable @State var showTime = false
    @Previewable @State var greysPast = true

    VStack {
        LineEventElementView(currentLine: line, operatorName: "Transports Publics Genevois", transportType: "Tram",
                             currentStop: current, eventName: name,
                             estimatedTime: OJPDate.string(from: PreviewData.now.addingTimeInterval(minutes * 60)),
                             timetabledTime: OJPDate.string(from: PreviewData.now.addingTimeInterval((minutes - delay) * 60)),
                             plannedQuay: quay, showTime: $showTime, pastEventPossible: greysPast)
            .padding(.top)
        Form {
            TextField("Ligne" as String, text: $line)
            TextField("Arrêt" as String, text: $name)
            TextField("Quai" as String, text: $quay)
            Stepper("Dans \(minutes.formatted()) min" as String, value: $minutes, in: -10...60, step: 0.5)
            Stepper("Retard \(delay.formatted()) min" as String, value: $delay, in: -5...30)
            Toggle("Arrêt courant" as String, isOn: $current)
            Toggle("Heure affichée" as String, isOn: $showTime)
            Toggle("Griser si passé" as String, isOn: $greysPast)
        }
        .scrollContentBackground(.hidden)
    }
    .previewEnvironment(navigation: false)
}

#Preview("Titres de ligne", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 20) {
        FloatingLineTitle(destination: "Versoix, La Scie", currentLine: "29", operatorName: "Transports Publics Genevois")
        FloatingLineTitle(destination: "Lancy-Bachet-Gare", currentLine: "12", operatorName: "Transports Publics Genevois")
        FloatingLineTitle(destination: "Genève, gare Cornavin", currentLine: "L1", operatorName: "SBB")
        LineViewTitle(destination: "Plan-les-Ouates, ZIPLO-Pré-Fleuri Nord", currentLine: "NA", operatorName: "Transports Publics Genevois")
    }
    .padding()
}

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
    var autoRefresh: Bool = true
    
    var stopEvent: StopEvent
    var currentStop: ShortStop?
    var currentLine: String
    
    private var operatorName: String { journey.operatorName }
    private var lineColor: Color {
        journey.events.isEmpty ? .primary : LineColors.lineColor(for: currentLine, operatorName: operatorName)
    }
    
    @State private var scrollDone = false
    @State private var showTime = false
    private var lineEvents: [LineEvent] { journey.events }
    @State private var busIsHere: Bool = false
    /// Blocs d'arrêts sautés dont l'utilisateur a inversé l'état (replié ou déplié).
    @State private var expandedSkippedBlocks: Set<String> = []
    /// Hauteur du titre flottant : la liste commence dessous, même avec un texte agrandi.
    @State private var titleHeight: CGFloat = 0

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
                                LazyVStack {
                                    ForEach(journeyRows(lineEvents)) { row in
                                        switch row {
                                        case .stop(let event):
                                            stopRow(event, scroll: scroll)
                                        case .skipped(let stops):
                                            skippedBlock(stops, scroll: scroll)
                                        }
                                    }
                                }
                            }
                            .contentMargins(.top, max(95.0, titleHeight + 10), for: .automatic)
                            .contentMargins(.bottom, TPGSurface.isGlass ? 0.0 : 60, for: .automatic)
                            .readableScrollContent()
                            .refreshable {
                                getLineEvents(for: stopEvent)
                            }
                            // Sur iPhone : le départ ne passe pas à l'arrêt d'où la course a été
                            // ouverte. Sur grand écran, la moitié droite le dit déjà.
                            .safeAreaInset(edge: .bottom) {
                                if !layout.showsSecondaryPane, stopEvent.cancelled, let currentStop,
                                   let alternative = nearestServedStop(skipping: currentStop.sloid, in: lineEvents, now: now) {
                                    ServedAlternativeCard(alternative: alternative, transportType: stopEvent.transportType) {
                                        openRoute(.stop(name: alternative.stop.stopPointName, sloid: alternative.stop.sloid,
                                                        highlight: DepartureHighlight(journeyRef: stopEvent.journeyRef, lineName: currentLine, time: alternative.stop.timetabledTime)))
                                    }
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                                }
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
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
                            Spacer()
                        }
                        Spacer()
                    }
                    
                }
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
            HStack {
                ShowTimeButton(showTime: $showTime)
                
                if TripLiveActivities.shared.areEnabled, !stopEvent.journeyRef.isEmpty {
                    Button {
                        openRoute(.trackJourney(event: stopEvent, stopSloid: currentStop?.sloid ?? stopEvent.stopId))
                    } label: {
                        Image(systemName: "livephoto")
                            .padding(.horizontal, 2)
                    }
                    .accessibilityLabel("Suivre en direct")
                }
                // Sur grand écran, la carte est déjà là : son plein écran est sur elle.
                if !layout.showsSecondaryPane {
                    Button {
                        openRoute(.lineMap(events: lineEvents, operatorName: operatorName, event: stopEvent, currentStopSloid: currentStop?.sloid))
                    } label: {
                        Image(systemName: "map")
                            .padding(.trailing, TPGSurface.isGlass ? 5 : 10)
                    }
                }
            }
            .background {
                Capsule()
                    .opacity(TPGSurface.isGlass ? 0 : 1)
                    .foregroundStyle(.ultraThinMaterial)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
            }
        }
        .navigationTitle("Ligne \(currentLine)") // Set back button text
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("") // Visible title
            }
        }
    }

    /// Un arrêt de la course, avec son trait de ligne.
    private func stopRow(_ event: LineEvent, scroll: ScrollViewProxy) -> some View {
        let skipped = event.isCancelled == true
        return stopLink(event) {
            LineEventElementView(currentLine: currentLine, operatorName: operatorName, transportType: stopEvent.transportType, currentStop: event.sloid == currentStop?.sloid || event.id == selectedStop?.id, eventName: event.stopPointName, estimatedTime: event.estimatedTime, timetabledTime: event.timetabledTime, plannedQuay: event.plannedQuay, showTime: $showTime, skipped: skipped)
        }
        .foregroundStyle(.primary)
        .onAppear {
            if !scrollDone {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        if let currentStop = currentStop {
                            let currentStopID = currentStop.sloid + stopEvent.timetabledTime
                            scroll.scrollTo(currentStopID, anchor: UnitPoint(x: 0.0, y: 0.05))
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
            LineBackground(event: event, firstEventId: lineEvents.first?.id, lastEventId: lineEvents.last?.id, lineColor: lineColor, busIsHere: $busIsHere, skipped: skipped)
        )
        .id(event.id)
    }

    /// Plusieurs arrêts sautés d'affilée, repliés en un bloc. Déplié d'office s'il contient
    /// l'arrêt d'où la course a été ouverte : c'est lui que l'utilisateur cherche.
    @ViewBuilder private func skippedBlock(_ stops: [LineEvent], scroll: ScrollViewProxy) -> some View {
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
            LineBackground(event: stops[0], lineColor: lineColor, busIsHere: $busIsHere, skipped: true)
        )
        if expanded {
            ForEach(stops) { stopRow($0, scroll: scroll) }
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
            Button(action: { withAnimation { selectedStop = event } }, label: label)
        } else {
            NavigationLink(value: AppRoute.stop(name: event.stopPointName, sloid: event.sloid,
                                                highlight: DepartureHighlight(journeyRef: stopEvent.journeyRef, lineName: currentLine, time: event.timetabledTime)),
                           label: label)
        }
    }
}

struct LineBackground: View {
    @Environment(\.displayTime) private var now
    var event: LineEvent
    var firstEventId: String?
    var lastEventId: String?
    var lineColor: Color
    @Binding var busIsHere: Bool
    /// Abscisse du trait, alignée sur les points d'arrêt de la rangée.
    var trailX: CGFloat = 45
    /// Arrêt sauté : le véhicule n'y passe pas, le trait est en pointillé.
    var skipped = false
    
    var body: some View {
        GeometryReader { geometry in
            if skipped {
                Path { path in
                    path.move(to: CGPoint(x: trailX, y: -4))
                    path.addLine(to: CGPoint(x: trailX, y: geometry.size.height + 4))
                }
                .stroke(lineColor.opacity(0.4), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 10]))
            } else if event.id == firstEventId {
                Rectangle()
                    .frame(width: 7, height: geometry.size.height / 2 + 8)
                    .foregroundColor(hasPassed(event.departureDate, includingCurrentMinute: false, now: now) ? lineColor.opacity(0.3) : lineColor)
                    .position(x: trailX, y: geometry.size.height / 4 * 3)
            } else if event.id == lastEventId {
                Rectangle()
                    .frame(width: 7, height: geometry.size.height / 2 + 8)
                    .foregroundColor(hasPassed(event.departureDate, includingCurrentMinute: true, now: now) ? lineColor.opacity(0.3) : lineColor)
                    .position(x: trailX, y: geometry.size.height / 4)
            } else {
                var colorUp = hasPassed(event.departureDate, includingCurrentMinute: true, now: now)
                let colorDown = hasPassed(event.departureDate, includingCurrentMinute: false, now: now)
                
                Rectangle()
                    .frame(width: 7, height: geometry.size.height / 2 + 8)
                    .foregroundColor(colorUp ? lineColor.opacity(0.3) : lineColor)
                    .position(x: trailX, y: geometry.size.height / 4)
                Rectangle()
                    .frame(width: 7, height: geometry.size.height / 2 + 8)
                    .foregroundColor(colorDown ? lineColor.opacity(0.3) : lineColor)
                    .position(x: trailX, y: geometry.size.height / 4 * 3)
                    .onAppear {
                        if busIsHere {
                            colorUp = false
                        } else if !busIsHere && colorUp && !colorDown {
                            busIsHere = true
                        }
                    }
            }
        }
    }
}

struct LineEventElementView: View {
    @Environment(\.displayTime) private var now
    var currentLine: String
    var operatorName: String
    var transportType: String
    var currentStop: Bool = false
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
    
    var body: some View {
//        RoundedRectangle(cornerRadius: 20)
//        Capsule()
//            .stroke(currentStop ? .accent : .border, lineWidth: 1)
//            .fill(.thinMaterial)
//            .fill(.color1)
                HStack {
                    StopIcon(color: LineColors.lineColor(for: currentLine, operatorName: operatorName, inverted: true))
                    if geoPositionDisplay {
                        Text(eventName)
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
                    .opacity(skipped ? 0.5 : pastEventPossible && hasPassed(OJPDate.date(from: estimatedTime) ?? OJPDate.date(from: timetabledTime), includingCurrentMinute: false, now: now) ? 0.3 : 1)
                .padding(.horizontal)
                .basicElementBackground(minHeight: 45, highlighted: currentStop)
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
                    Text(verbatim: "\(first.stopPointName) → \(last.stopPointName)")
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
    @Previewable @State var busIsHere = false
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
                                       lineColor: color, busIsHere: $busIsHere)
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

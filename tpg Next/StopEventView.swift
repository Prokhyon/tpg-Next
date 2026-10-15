//
//  NewStopViewTest.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Combine
import tpgNextFunc

struct StopEventView: View  {
    @Environment(\.displayTime) private var now
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var event: StopEvent
    var showTime: Bool
    /// La course d'où l'on vient (lien entre pages) : un anneau autour de sa ligne.
    var previousLineRef: String?
    var mapVersion = false
    /// Le départ détaillé à côté, sur grand écran : la bordure orange de la rangée.
    var isSelected = false

    var body: some View {
        let transportTime = departureDisplay(for: event, showTime: showTime, at: now)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Tailles d'accessibilité : sur une seule rangée, la destination n'avait plus
                // que quelques lettres de large. Elle passe dessous, en pleine largeur.
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        BusLineIcon(lineName: event.lineName, operatorName: event.operatorName, highlighted: isLinked)
                        Spacer()
                        DepartureTimeView(transportTime, transportType: event.transportType, iconWidth: 10)
                        QuayIcon(quay: event.plannedQuay)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "arrow.right").font(.caption)
                        SmallStopTitleView(stopName: event.destination)
                        .strikethrough(event.cancelled)
                        RouteChangedIcon(event: event)
                    }
                }
            } else {
                HStack {
                    BusLineIcon(lineName: event.lineName, operatorName: event.operatorName, highlighted: isLinked)
                    Image(systemName: "arrow.right").font(.caption)
                    SmallStopTitleView(stopName: event.destination)
                    .strikethrough(event.cancelled)
                    RouteChangedIcon(event: event)
                    Spacer()
                    DepartureTimeView(transportTime, transportType: event.transportType, iconWidth: 10)
                        .padding(.vertical, 4)
                    QuayIcon(quay: event.plannedQuay)
                }
            }
        }
        .padding(.horizontal)
        .basicElementBackground(minHeight: 50, transparent: mapVersion, selected: isSelected,
                                lineColors: [LineColors.lineColor(for: event.lineName, operatorName: event.operatorName)])
        .padding(5)
    }

    private var isLinked: Bool {
        event.journeyRef == (previousLineRef ?? "")
    }
}

/// Repère orange, sans barrer le départ : la course dessert l'arrêt mais en saute d'autres,
/// ou suit un horaire exceptionnel (course d'un seul jour, souvent une déviation).
private struct RouteChangedIcon: View {
    let event: StopEvent

    var body: some View {
        if event.routeChanged {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("Parcours modifié")
        } else if event.exceptional {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("Horaire exceptionnel")
        }
    }
}

#Preview("Départ — cas") {
    ScrollView {
        VStack(spacing: 0) {
            StopEventView(event: PreviewData.departure(inMinutes: 6), showTime: false)
            StopEventView(event: PreviewData.departure(inMinutes: 8, delay: 3), showTime: false)
            StopEventView(event: PreviewData.departure(inMinutes: 3, delay: -1), showTime: false)
            StopEventView(event: PreviewData.departure(inMinutes: 0.5), showTime: false)
            StopEventView(event: PreviewData.departure(inMinutes: 0), showTime: false)
            StopEventView(event: PreviewData.departure(line: "8", destination: "Palexpo", quay: "E", inMinutes: 5,
                                                       cancelled: true, transportType: "Bus"), showTime: false)
            StopEventView(event: PreviewData.departure(line: "A", destination: "Rive", quay: "A", inMinutes: 9, delay: 4,
                                                       routeChanged: true, transportType: "Bus"), showTime: false)
            StopEventView(event: PreviewData.departure(inMinutes: 12, delay: 2), showTime: true)
            StopEventView(event: PreviewData.departure(line: "E", destination: "Hermance-Village", quay: "J", inMinutes: 7,
                                                       transportType: "Bus"),
                          showTime: false, previousLineRef: "preview-E-Hermance-Village-7.0")
            StopEventView(event: PreviewData.departure(line: "NA", destination: "Chancy-Douane, Frontière franco-suisse",
                                                       quay: "M", inMinutes: 45, transportType: "Bus"), showTime: false)
        }
    }
    .previewEnvironment(navigation: false)
}

#Preview("Départ — vrais départs de Rive") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(PreviewData.departures) { event in
                StopEventView(event: event, showTime: false)
            }
        }
    }
    .previewEnvironment(navigation: false)
}

#Preview("Départ — texte très grand") {
    VStack(spacing: 0) {
        StopEventView(event: PreviewData.departure(inMinutes: 6), showTime: false)
        StopEventView(event: PreviewData.departure(line: "8", destination: "Palexpo", quay: "E", inMinutes: 5,
                                                   cancelled: true, transportType: "Bus"), showTime: false)
    }
    .dynamicTypeSize(.accessibility3)
    .previewEnvironment(navigation: false)
}

#Preview("Départ — bac à sable") {
    @Previewable @State var line = "12"
    @Previewable @State var destination = "Genève, Moillesulaz"
    @Previewable @State var quay = "B"
    @Previewable @State var minutes = 4.0
    @Previewable @State var delay = 0.0
    @Previewable @State var cancelled = false
    @Previewable @State var showTime = false
    @Previewable @State var highlighted = false
    @Previewable @State var mapVersion = false

    let event = PreviewData.departure(line: line, destination: destination, quay: quay, inMinutes: minutes,
                                      delay: delay, cancelled: cancelled)
    VStack {
        StopEventView(event: event, showTime: showTime,
                      previousLineRef: highlighted ? event.journeyRef : nil, mapVersion: mapVersion)
            .padding(.top)
        Form {
            TextField("Ligne" as String, text: $line)
            TextField("Destination" as String, text: $destination)
            TextField("Quai" as String, text: $quay)
            Stepper("Dans \(minutes.formatted()) min" as String, value: $minutes, in: -5...90, step: 0.5)
            Stepper("Retard \(delay.formatted()) min" as String, value: $delay, in: -5...30)
            Toggle("Supprimé" as String, isOn: $cancelled)
            Toggle("Heure affichée" as String, isOn: $showTime)
            Toggle("Mis en avant" as String, isOn: $highlighted)
            Toggle("Version carte (transparente)" as String, isOn: $mapVersion)
        }
        .scrollContentBackground(.hidden)
    }
    .previewEnvironment(navigation: false)
}

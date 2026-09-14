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
    var previousLineRef: String?
    var mapVersion = false

    var body: some View {
        let transportTime = departureDisplay(timetabled: event.timetabledTime, estimated: event.estimatedTime, showTime: showTime, at: now)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Tailles d'accessibilité : sur une seule rangée, la destination n'avait plus
                // que quelques lettres de large. Elle passe dessous, en pleine largeur.
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                        Spacer()
                        DepartureTimeView(transportTime, transportType: event.transportType, iconWidth: 10)
                        QuayIcon(quay: event.plannedQuay)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "arrow.right").font(.caption)
                        SmallStopTitleView(stopName: event.destination)
                    }
                }
            } else {
                HStack {
                    BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                    Image(systemName: "arrow.right").font(.caption)
                    SmallStopTitleView(stopName: event.destination)
                    Spacer()
                    DepartureTimeView(transportTime, transportType: event.transportType, iconWidth: 10)
                        .padding(.vertical, 4)
                    QuayIcon(quay: event.plannedQuay)
                }
            }
        }
        .padding(.horizontal)
        .basicElementBackground(minHeight: 50, transparent: mapVersion, highlighted: event.journeyRef == (previousLineRef ?? ""))
        .padding(5)
    }
}

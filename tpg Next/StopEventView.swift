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
    var event: StopEvent
    var showTime: Bool
    var previousLineRef: String?
    var mapVersion = false
    
    var body: some View {
        let content = HStack {
            let transportTime = departureDisplay(timetabled: event.timetabledTime, estimated: event.estimatedTime, showTime: showTime, at: now)
            BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
            Image(systemName: "arrow.right").font(.caption)
            SmallStopTitleView(stopName: event.destination)
            Spacer()
            DepartureTimeView(transportTime, transportType: event.transportType, iconWidth: 10)
                .padding(.vertical, 4)
            QuayIcon(quay: event.plannedQuay)
        }
            .padding(.horizontal)
//            Capsule()
            //            .stroke(event.journeyRef == (previousLineRef ?? "") ? .accent : .clear, lineWidth: 3)
            ////                .fill(.color1)
            //                .fill(.ultraThinMaterial)
            ////                .fill(.)
            //                .frame(height: 50)
            //                .shadow(color: Color.customShadows, radius: 1.5, y: 1)
            //
//                .fill(.color1.opacity(mapVersion ? 0.5 : 1))
//                .stroke(event.journeyRef == (previousLineRef ?? "") ? .accent : .border, lineWidth: 1)
//                .stroke(.borderColor.opacity(1), lineWidth: 1)
//                .shadow(color: .customShadows.opacity(0.2), radius: 10)
            //            .shadow(color: LineColors.lineColor(for: event.lineName, operatorName: event.operatorName).opacity(0.3), radius: 3)
            BasicElement(transparent: mapVersion ,highlighted: event.journeyRef == (previousLineRef ?? ""))
//            .shadow(color: LineColors.lineColor(for: event.lineName, operatorName: event.operatorName).opacity(0.3), radius: 3)
                .frame(height: 50)
                .overlay(content)
                .padding(5)
    }
}

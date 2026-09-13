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
    var event: StopEvent
    var showTime: Bool
    var previousLineRef: String?
    var mapVersion = false
    
    var body: some View {
        let content = HStack {
            let transportTime = displayTimeOrMinutesRemaining(for: event.timetabledTime, estimatedInput: event.estimatedTime,  with: showTime)
            BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
            Image(systemName: "arrow.right").font(.caption)
            SmallStopTitleView(stopName: event.destination)
            Spacer()
            if transportTime.text == "0" {
                transportIcon(with: event.transportType).frame(width: 10)
            } else {
                if transportTime.text.count > 6 {
                    let splitTime = splitString(transportTime.text, separator: ";" )
                    VStack(spacing: 0) {
                        Text(splitTime.0)
                        Text(splitTime.1)
                            .foregroundStyle(transportTime.color)
                            .minimumScaleFactor(0.5)
                    }
                    .padding(.vertical, 4)
                    
                } else {
                    Text(transportTime.text)
                        .padding(.vertical, 4)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(transportTime.color)
                }
            }
            if event.plannedQuay == "" {
                Image(systemName: "questionmark.square.fill")
            } else {
                Image(systemName: "\(event.plannedQuay).square.fill".lowercased())
            }
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

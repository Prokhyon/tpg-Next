//
//  LineDeparturesCard.swift
//  tpg Next
//
//  Départs d'une ligne vers une destination, en carte horizontale (tri par ligne).
//

import SwiftUI
import tpgNextFunc

struct SortedStopEventsView: View {
    @Environment(\.displayTime) private var now
    @Environment(\.layout) private var layout
    var key: String
    var filteredStopEvents: [String: [StopEvent]]
    var groupedStopEvents: [String: [StopEvent]]
    @Binding var showTime: Bool
    @Binding var previousLineRef: String?
    var stopName: String
    var stopSloid: String
    /// Sur grand écran : un départ se sélectionne au lieu d'ouvrir sa course.
    var onSelect: ((StopEvent) -> Void)? = nil

    @ViewBuilder private func chipLink<Label: View>(_ event: StopEvent, @ViewBuilder label: () -> Label) -> some View {
        if let onSelect {
            Button(action: { onSelect(event) }, label: label)
        } else {
            NavigationLink(value: AppRoute.line(event: event, currentStop: ShortStop(name: stopName, sloid: sloidHarmonizer(code: stopSloid))), label: label)
        }
    }

    var body: some View {
            let splitLine = splitString(key, separator: ";")
        BasicCard(cornerRadius: 30)
                .padding(.vertical, 5)
                .frame(height: 110)
                .overlay(
                    VStack(spacing: 0) {
                        Spacer()
                        HStack {
                            let quay = groupedStopEvents[key]!.first!.plannedQuay
                            BusLineIcon(lineName: splitLine.0, operatorName: filteredStopEvents[key]![0].operatorName)
                            Image(systemName: "arrow.right")
                            SmallStopTitleView(stopName: splitLine.1)
                            Spacer()
                            QuayIcon(quay: quay)
                        }
                        .frame(height: 30)
//                        .background(Rectangle().fill(.red))
                        .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(filteredStopEvents[key]!, id: \.id) { stopEvent in
                                    let time = departureDisplay(for: stopEvent, showTime: showTime, at: now)
                                    chipLink(stopEvent) {
                                    Group {
                                            DepartureTimeView(time, transportType: stopEvent.transportType, layout: .inline(spacing: 2), iconWidth: 15)
                                        }
                                        .foregroundStyle(determineColor(for: stopEvent.estimatedTime, now: now))
                                        .padding(.horizontal, 17)
                                        .padding(.vertical, 5)
                                        .background(
                                            BasicElement(highlighted: stopEvent.journeyRef == (previousLineRef ?? ""))
//                                                .padding(2)
                                        )
                                        
                                        
                                    }
                                    .padding(2)
                                    .contentShape(.contextMenuPreview, Capsule())
                                    .if(!stopEvent.cancelled && !hasPassed(stopEvent.departureDate, includingCurrentMinute: false, now: now)) { view in
                                        view.contextMenu {
                                            NotificationContextMenu(event: stopEvent, stopID: stopSloid)
                                        } preview: {
                                            StopEventView(event: stopEvent, showTime: showTime, previousLineRef: previousLineRef)
                                                .foregroundStyle(.primary)
                                                .frame(width: layout.previewWidth)
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                            }
                            .frame(height: 40)
//                            .background(Rectangle().fill(.red))
                            .padding(.horizontal)
                            .padding(.vertical, 7)
                            
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .leading) {
                                    ScrollMask(leading: true, vertical: false, gradientLength: 10)
                                }
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .trailing) {
                                    ScrollMask(leading: false, vertical: false, gradientLength: 10)
                                }
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .top) {
                                    ScrollMask(leading: false, vertical: true, gradientLength: 10)
                                }
                        }
                        .mask {
                            Rectangle()
                                .overlay(alignment: .bottom) {
                                    ScrollMask(leading: true, vertical: true, gradientLength: 10)
                                }
                        }
                        .padding(.horizontal, 5)
//                        Spacer()
                    }
                        .padding(.vertical, 10)
//                        .background(Rectangle().fill(.red))
                )
                .padding(.horizontal, 20)
        }
}

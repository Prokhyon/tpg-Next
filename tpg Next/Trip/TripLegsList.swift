//
//  TripLegsList.swift
//  tpg Next
//
//  Les étapes d'un itinéraire : arrêts de montée et de descente, lignes, correspondances.
//  Partagé par la page du trajet (iPhone) et le panneau de détail des itinéraires (grand écran).
//

import SwiftUI
import tpgNextFunc

struct TripLegsList: View {
    @Environment(\.displayTime) private var now
    @Environment(\.openRoute) private var openRoute
    let fullTrip: TripEvent
    @Binding var showTime: Bool
    /// Sur grand écran, toucher une étape la cadre sur la carte au lieu d'ouvrir sa page ;
    /// la page reste accessible par le menu contextuel.
    var onFocus: ((TripMapFocus) -> Void)? = nil
    /// L'étape cadrée, mise en avant.
    var focusedID: String? = nil

    var body: some View {
        VStack {
            // Sans code d'arrêt, le lien plantait : la destination est construite dès l'affichage.
            if !fullTrip.geoDeparture && (fullTrip.legs.first?.transfer ?? false || fullTrip.legs.first?.publishedLineName == ""), let startCode = fullTrip.startCode { //Display departure stop input by user, if the first transport is from another stop
                let route = AppRoute.stop(name: fullTrip.startName, sloid: startCode)
                step(route, focusing: startFocus) {
                    LineEventElementView(currentLine: "", operatorName: "", transportType: "walk", currentStop: isFocused(startFocus), eventName: fullTrip.startName, estimatedTime: fullTrip.startTime, timetabledTime: fullTrip.startTime, plannedQuay: "ignore", showTime: $showTime, pastEventPossible: false)
                }
                .padding(.horizontal, 15)
                .foregroundStyle(.primary)
                .contextMenu { openItem(route, title: "Ouvrir l'arrêt", systemImage: "signpost.right") }

            } else if fullTrip.geoDeparture { //Display geoPosition departure
                focusable(startFocus) {
                    LineEventElementView(currentLine: "", operatorName: "", transportType: "walk", currentStop: isFocused(startFocus), eventName: fullTrip.startName, estimatedTime: fullTrip.startTime, timetabledTime: fullTrip.startTime, plannedQuay: "ignore", showTime: $showTime, pastEventPossible: false, geoPositionDisplay: true)
                }
                .padding(.horizontal, 15)
            }

            ForEach(Array(fullTrip.legs.enumerated()), id: \.element.id) { index, leg in
                if !leg.publishedLineName.isEmpty { //check the leg for a transport line name. If absent, it means the leg is a transfer
                    let boardFocus = TripMapFocus(id: "board-\(leg.id)", coordinates: [leg.boardCoordinate])
                    let legFocus = TripMapFocus(id: "leg-\(leg.id)", coordinates: fullTrip.mapCoordinates(forLeg: index))
                    let alightFocus = TripMapFocus(id: "alight-\(leg.id)", coordinates: [leg.alightCoordinate])
                    let boardRoute = AppRoute.stop(name: leg.legBoardStopName, sloid: leg.legBoardStopId, //Departure stop for the leg
                                                   highlight: DepartureHighlight(journeyRef: leg.journeyRef, lineName: leg.publishedLineName, time: leg.legBoardTimetableTime))
                    let lineRoute = AppRoute.line(event: createStopEventFromTripLeg(tripLeg: leg), currentStop: nil)
                    let alightRoute = AppRoute.stop(name: leg.legAlightStopName, sloid: leg.legAlightStopId, //Arrival stop for the leg
                                                    highlight: DepartureHighlight(journeyRef: leg.journeyRef, lineName: leg.publishedLineName, time: leg.legAlightTimetableTime))
                    let notice = incidentNotice(leg)
                    ZStack {
                            HStack { //Colored line background for the leg
                                RoundedRectangle(cornerRadius: 5)
                                    .frame(width: 8, height: notice == nil ? 108 : 128)
                                    .foregroundStyle(LineColors.lineColor(for: leg.publishedLineName, operatorName: leg.legOperator))
                                Spacer()
                            }
                            .padding(.horizontal, 26)
                        VStack {
                            step(boardRoute, focusing: boardFocus) {
                                LineEventElementView(currentLine: leg.publishedLineName, operatorName: leg.legOperator, transportType: leg.transportTypeName, currentStop: isFocused(boardFocus), eventName: leg.legBoardStopName, estimatedTime: leg.legBoardEstimatedTime, timetabledTime: leg.legBoardTimetableTime, plannedQuay: leg.legBoardQuay, showTime: $showTime, pastEventPossible: false)
                            }
                            .foregroundStyle(.primary)
                            .contentShape(.contextMenuPreview, Capsule())
                            .contextMenu {
                                openItem(boardRoute, title: "Ouvrir l'arrêt", systemImage: "signpost.right")
                                if !hasPassed(leg.boardDate, includingCurrentMinute: false, now: now) {
                                    NotificationContextMenu(event: StopEvent(stopPointName: leg.legBoardStopName, stopId: leg.legBoardStopId, plannedQuay: leg.legBoardQuay, timetabledTime: leg.legBoardTimetableTime, estimatedTime: leg.legBoardEstimatedTime, lineName: leg.publishedLineName, origin: "", destination: leg.legDestination, transportType: leg.transportTypeName, operatorName: leg.legOperator, journeyRef: leg.journeyRef, operatingDayRef: leg.resolvedOperatingDayRef), stopID: leg.legBoardStopId)
                                }
                            }

                            HStack { //Transport line name and destination for the leg. Navigates to a LineView
                                Rectangle()
                                    .fill(.clear)
                                    .frame(width: 50)
                                step(lineRoute, focusing: legFocus) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
                                            Image(systemName: "arrow.right")
                                            SmallStopTitleView(stopName: leg.legDestination)
                                        }
                                        if let notice {
                                            Label(notice, systemImage: "exclamationmark.triangle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .background {
                                        if isFocused(legFocus) {
                                            Capsule().strokeBorder(Color.accent, lineWidth: 1.5)
                                        }
                                    }
                                }
                                .contextMenu { openItem(lineRoute, title: "Voir la ligne", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
                                Spacer()
                            }
                            .frame(height: notice == nil ? 30 : 50)
                            .foregroundStyle(.primary)

                            step(alightRoute, focusing: alightFocus) {
                                LineEventElementView(currentLine: leg.publishedLineName, operatorName: leg.legOperator, transportType: leg.transportTypeName, currentStop: isFocused(alightFocus), eventName: leg.legAlightStopName, estimatedTime: leg.legAlightEstimatedTime, timetabledTime: leg.legAlightTimetableTime, plannedQuay: leg.legAlightQuay, showTime: $showTime, pastEventPossible: false)
                            }
                            .foregroundStyle(.primary)
                            .contentShape(.contextMenuPreview, Capsule())
                            .contextMenu {
                                openItem(alightRoute, title: "Ouvrir l'arrêt", systemImage: "signpost.right")
                                if !hasPassed(leg.alightDate, includingCurrentMinute: false, now: now) {
                                    NotificationContextMenu(event: createEssentialStopEvent(journeyRef: leg.journeyRef, operatingDayRef: leg.resolvedOperatingDayRef, stopPointName: leg.legAlightStopName, stopId: leg.legAlightStopId, lineName: leg.publishedLineName, origin: "", destination: leg.legDestination, transportType: leg.transportTypeName, operatorName: leg.legOperator), stopID: leg.legAlightStopId)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 15)

                } else {
                    let walkFocus = TripMapFocus(id: "walk-\(leg.id)", coordinates: fullTrip.mapCoordinates(forLeg: index))
                    focusable(walkFocus) {
                        HStack {
                            if !leg.transferDuration.isEmpty {
                                if leg.transferWalkDuration.isEmpty { //if walk leg without waiting time, display only the walking time
                                    Image(systemName: "figure.walk")
                                        .padding(.leading, 30)
                                    Text(durationText(leg.transferDuration))
                                    Spacer()
                                } else {
                                    Image(systemName: "timer") //Time between previous leg arrival and next leg departure
                                        .padding(.leading, 30)
                                    Text(durationText(leg.transferDuration))
                                        .padding(.trailing, 30)
                                    Image(systemName: "figure.walk")//walk time
                                    Text(durationText(leg.transferWalkDuration))
                                    Spacer()
                                }
                            } else if leg.publishedLineName.isEmpty { //Used if trip without transport, only walking
                                Image(systemName: "figure.walk")
                                    .padding(.leading, 30)
                                Text(durationText(fullTrip.duration))
                                    .padding(.trailing, 30)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 10)
                        .background {
                            if isFocused(walkFocus) {
                                Capsule().strokeBorder(Color.accent, lineWidth: 1.5)
                                    .padding(.horizontal, 15)
                            }
                        }
                    }
                }
            }

            if !fullTrip.geoArrival && (fullTrip.legs.last?.transfer ?? false || fullTrip.legs.last?.publishedLineName == ""), let endCode = fullTrip.endCode { //Trip arrival stop if different from last transport leg arrival
                let route = AppRoute.stop(name: fullTrip.endName, sloid: endCode)
                step(route, focusing: endFocus) {
                   LineEventElementView(currentLine: "", operatorName: "", transportType: "walk", currentStop: isFocused(endFocus), eventName: fullTrip.endName, estimatedTime: fullTrip.endTime, timetabledTime: fullTrip.endTime, plannedQuay: "ignore", showTime: $showTime, pastEventPossible: false, displayIcon: false)
                }
                .padding(.horizontal, 15)
                .foregroundStyle(.primary)
                .contextMenu { openItem(route, title: "Ouvrir l'arrêt", systemImage: "signpost.right") }

            } else if fullTrip.geoArrival { //Display geoPosition arrival
                focusable(endFocus) {
                    LineEventElementView(currentLine: "", operatorName: "", transportType: "walk", currentStop: isFocused(endFocus), eventName: fullTrip.endName, estimatedTime: fullTrip.endTime, timetabledTime: fullTrip.endTime, plannedQuay: "ignore", showTime: $showTime, pastEventPossible: false, geoPositionDisplay: true, displayIcon: false)
                }
                .padding(.horizontal, 15)
            }
        }
    }

    /// Incident sur la course de l'étape : combien d'arrêts le véhicule saute entre la montée
    /// et la descente, ou seulement « Parcours modifié » s'il les saute ailleurs.
    private func incidentNotice(_ leg: TripLeg) -> LocalizedStringKey? {
        let skipped = leg.skippedIntermediates.count
        if skipped > 0 {
            return "\(skipped) arrêt(s) non desservi(s)"
        }
        return leg.hasIncident ? "Parcours modifié" : nil
    }

    private var startFocus: TripMapFocus {
        TripMapFocus(id: "start", coordinates: [fullTrip.startCoordinates.toCLLocationCoordinate2D])
    }

    private var endFocus: TripMapFocus {
        TripMapFocus(id: "end", coordinates: [fullTrip.endCoordinates.toCLLocationCoordinate2D])
    }

    private func isFocused(_ target: TripMapFocus) -> Bool {
        onFocus != nil && focusedID == target.id
    }

    /// Une étape qui a sa page : l'ouvre sur iPhone, la cadre sur la carte sur grand écran.
    @ViewBuilder private func step<Label: View>(_ route: AppRoute, focusing target: TripMapFocus, @ViewBuilder label: () -> Label) -> some View {
        if let onFocus {
            Button(action: { onFocus(target) }, label: label)
        } else {
            NavigationLink(value: route, label: label)
        }
    }

    /// Une étape sans page (position, marche) : touchable seulement quand la carte est affichée.
    @ViewBuilder private func focusable<Content: View>(_ target: TripMapFocus, @ViewBuilder content: () -> Content) -> some View {
        if let onFocus {
            Button(action: { onFocus(target) }, label: content)
                .foregroundStyle(.primary)
        } else {
            content()
        }
    }

    /// L'accès à la page, dans le menu contextuel, quand toucher l'étape ne l'ouvre plus.
    @ViewBuilder private func openItem(_ route: AppRoute, title: LocalizedStringKey, systemImage: String) -> some View {
        if onFocus != nil {
            Button { openRoute(route) } label: { Label(title, systemImage: systemImage) }
        }
    }
}

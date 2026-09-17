//
//  FullTripView.swift
//  tpg Next
//
//  Created by Loris Thomas on 03.12.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc

struct FullTripView: View {
    @Environment(\.displayTime) private var now
    @Environment(SavedTripsModel.self) var savedTripsModel
    @Environment(\.openRoute) private var openRoute
    var fullTrip: TripEvent
    @State private var lineManager = LineManager()
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    @State private var showTime = true
    
    @Namespace private var namespace


    var body: some View {
//        GeometryReader { geometry in
            ZStack {
                VStack(alignment: .leading) {
//                    Spacer(minLength: 70) //Space for trip title to be placed on top
                    ScrollView { //trip details scroll area
                        // Sans code d'arrêt, le lien plantait : la destination est construite dès l'affichage.
                        if !fullTrip.geoDeparture && (fullTrip.legs.first?.transfer ?? false || fullTrip.legs.first?.publishedLineName == ""), let startCode = fullTrip.startCode { //Display departure stop input by user, if the first transport is from another stop
                            NavigationLink(value: AppRoute.stop(name: fullTrip.startName, sloid: startCode)) {
                                LineEventElementView(currentLine: "", operatorName: "", transportType: "walk", currentStop: false, eventName: fullTrip.startName, estimatedTime: fullTrip.startTime, timetabledTime: fullTrip.startTime, plannedQuay: "ignore", showTime: $showTime, pastEventPossible: false)
                            }
                            .padding(.horizontal, 15)
                            .foregroundStyle(.primary)
                            
                        } else if fullTrip.geoDeparture { //Display geoPosition departure
                            LineEventElementView(currentLine: "", operatorName: "", transportType: "walk", currentStop: false, eventName: fullTrip.startName, estimatedTime: fullTrip.startTime, timetabledTime: fullTrip.startTime, plannedQuay: "ignore", showTime: $showTime, pastEventPossible: false, geoPositionDisplay: true)
                                .padding(.horizontal, 15)
                        }
                        
                        ForEach(fullTrip.legs) { leg in
                            if !leg.publishedLineName.isEmpty { //check the leg for a transport line name. If absent, it means the leg is a transfer
                                ZStack {
                                        HStack { //Colored line background for the leg
                                            RoundedRectangle(cornerRadius: 5)
                                                .frame(width: 8, height: 108)
                                                .foregroundStyle(LineColors.lineColor(for: leg.publishedLineName, operatorName: leg.legOperator))
                                            Spacer()
                                        }
                                        .padding(.horizontal, 26)
                                    VStack {
                                            NavigationLink(value: AppRoute.stop(name: leg.legBoardStopName, sloid: leg.legBoardStopId, //Departure stop for the leg
                                                                                highlight: DepartureHighlight(journeyRef: leg.journeyRef, lineName: leg.publishedLineName, time: leg.legBoardTimetableTime))) {
                                                LineEventElementView(currentLine: leg.publishedLineName, operatorName: leg.legOperator, transportType: leg.transportTypeName, currentStop: false, eventName: leg.legBoardStopName, estimatedTime: leg.legBoardEstimatedTime, timetabledTime: leg.legBoardTimetableTime, plannedQuay: leg.legBoardQuay, showTime: $showTime, pastEventPossible: false)

                                        }
                                        .foregroundStyle(.primary)
                                        .contentShape(.contextMenuPreview, Capsule())
                                        .if(!hasPassed(leg.boardDate, includingCurrentMinute: false, now: now)) { view in
                                            view.contextMenu {
                                                NotificationContextMenu(event: StopEvent(stopPointName: leg.legBoardStopName, stopId: leg.legBoardStopId, plannedQuay: leg.legBoardQuay, timetabledTime: leg.legBoardTimetableTime, estimatedTime: leg.legBoardEstimatedTime, lineName: leg.publishedLineName, origin: "", destination: leg.legDestination, transportType: leg.transportTypeName, operatorName: leg.legOperator, journeyRef: leg.journeyRef, operatingDayRef: leg.resolvedOperatingDayRef), stopID: leg.legBoardStopId)
                                            }
                                        }
                                        
                                        HStack { //Transport line name and destination for the leg. Navigates to a LineView
                                            Rectangle()
                                                .fill(.clear)
                                                .frame(width: 50)
                                            NavigationLink(value: AppRoute.line(event: createStopEventFromTripLeg(tripLeg: leg), currentStop: nil)) {
                                                HStack {
                                                    BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
                                                    Image(systemName: "arrow.right")
                                                    SmallStopTitleView(stopName: leg.legDestination)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .frame(height: 30)
                                        .foregroundStyle(.primary)
                                        
                                            NavigationLink(value: AppRoute.stop(name: leg.legAlightStopName, sloid: leg.legAlightStopId, //Arrival stop for the leg
                                                                                highlight: DepartureHighlight(journeyRef: leg.journeyRef, lineName: leg.publishedLineName, time: leg.legAlightTimetableTime))) {
                                                LineEventElementView(currentLine: leg.publishedLineName, operatorName: leg.legOperator, transportType: leg.transportTypeName, currentStop: false, eventName: leg.legAlightStopName, estimatedTime: leg.legAlightEstimatedTime, timetabledTime: leg.legAlightTimetableTime, plannedQuay: leg.legAlightQuay, showTime: $showTime, pastEventPossible: false)
//
                                        }
                                        .foregroundStyle(.primary)
                                        .contentShape(.contextMenuPreview, Capsule())
                                        .if(!hasPassed(leg.alightDate, includingCurrentMinute: false, now: now)) { view in
                                            view.contextMenu {
                                                NotificationContextMenu(event: createEssentialStopEvent(journeyRef: leg.journeyRef, operatingDayRef: leg.resolvedOperatingDayRef, stopPointName: leg.legAlightStopName, stopId: leg.legAlightStopId, lineName: leg.publishedLineName, origin: "", destination: leg.legDestination, transportType: leg.transportTypeName, operatorName: leg.legOperator), stopID: leg.legAlightStopId)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 15)
                                
                            } else {
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
                            }
                        }
                        
                        if !fullTrip.geoArrival && (fullTrip.legs.last?.transfer ?? false || fullTrip.legs.last?.publishedLineName == ""), let endCode = fullTrip.endCode { //Trip arrival stop if different from last transport leg arrival
                            NavigationLink(value: AppRoute.stop(name: fullTrip.endName, sloid: endCode)) {
                               LineEventElementView(currentLine: "", operatorName: "", transportType: "walk", currentStop: false, eventName: fullTrip.endName, estimatedTime: fullTrip.endTime, timetabledTime: fullTrip.endTime, plannedQuay: "ignore", showTime: $showTime, pastEventPossible: false, displayIcon: false)
                            }
                           .padding(.horizontal, 15)
                            .foregroundStyle(.primary)
                            
                        } else if fullTrip.geoArrival { //Display geoPosition arrival
                            LineEventElementView(currentLine: "", operatorName: "", transportType: "walk", currentStop: false, eventName: fullTrip.endName, estimatedTime: fullTrip.endTime, timetabledTime: fullTrip.endTime, plannedQuay: "ignore", showTime: $showTime, pastEventPossible: false, geoPositionDisplay: true, displayIcon: false)
                                .padding(.horizontal, 15)
                        }
                    }
                    .contentMargins(.top, 80.0, for: .automatic)
                    .contentMargins(.bottom, 40, for: .automatic)
                    .readableScrollContent()
                    .onAppear {
                        showTime = timeDefault
                    }
                }
                LegacyTopFade()
                
                VStack { //Trip title above the details
                    TPGGlassContainer {
                        HStack {
                            fullTripViewTitle(departureStopName: fullTrip.startName, arrivalStopName: fullTrip.endName)
                                .glassForegroundStyle(.text)
                                .frame(height: 70)
                                .padding(.horizontal, 20)
                                .tpgSurface(interactive: true, legacy: .thinMaterial, glassID: "title", namespace: namespace)
                            if !TPGSurface.isGlass {
                                Spacer()
                            }
                            fullTripViewTimeDate(duration: fullTrip.duration, date: localDayString(fromUTC: fullTrip.startTime))
                                .glassForegroundStyle(.text)
                                .frame(height: 70)
                                .padding(.horizontal, 20)
                                .tpgSurface(interactive: true, legacy: .thinMaterial, glassID: "timeDate", namespace: namespace)
                        }
                        .padding(.horizontal)
                    }
                    Spacer()
                }
            }
        
            .toolbar {
                HStack {
                    ShowTimeButton(showTime: $showTime)
                    Menu {
                        if savedTripsModel.tripIsSaved(fullTrip) {
                            Button(action: {
                                savedTripsModel.removeTrip(fullTrip)
                            }) {
                                Label("Ne plus enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.minus")
                            }
                        } else {
                            Button(action: {
                                savedTripsModel.addTrip(fullTrip)
                            }) {
                                Label("Enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.plus")
                            }
                        }
                        //                    Button(action: {
                        //
                        //                    }) {
                        //                        Label("Enregistrer comme trajet régulier", systemImage: "calendar.badge.plus")
                        //                    }
                        Button {
                            openRoute(.tripMap(fullTrip))
                        } label: {
                            Label("Afficher la carte", systemImage: "map")
                        }
                        //                    Button(action: {
                        //
                        //                    }) {
                        //                        Label("Partager l'itinéraire", systemImage: "square.and.arrow.up")
                        //                    }
                    } label: {
                        Image(systemName: "ellipsis").font(.title3)
                            .padding(.trailing, 10)
                    }
                }
                .background {
                    Capsule()
                        .opacity(TPGSurface.isGlass ? 0 : 1)
                        .foregroundStyle(.ultraThinMaterial)
                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                }

            }
        .navigationTitle("Détail itinéraire") // Set back button text
        // Barre transparente pour cet écran seulement : l'ancien réglage UIKit s'appliquait à toute l'app.
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("") // Visible title
            }
        }
    }
}

struct fullTripViewTitle: View {
    var departureStopName: String
    var arrivalStopName: String
    
    var body: some View {
                HStack(alignment: .center) {
                    StopNameView(departureStopName, style: .header)
                    Image(systemName: "arrow.right")
                    StopNameView(arrivalStopName, style: .header)
                }
//                .padding(.leading, 50)
//                .padding(.trailing,10)
//                .frame(height: 60)
    }
}

struct fullTripViewTimeDate: View {
    var duration: String
    var date: String
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "calendar")
                if let formattedDate = convertDateString(date) {
                    Text(formattedDate)//.minimumScaleFactor(0.5)
                }
            }
            HStack {
                Image(systemName: "timer")
                Text(durationText(duration))
            }
        }
        .fixedSize()
    }
}

struct FullTripView_Previews: PreviewProvider {
    static var previews: some View {
        @State var savedTripsModel = SavedTripsModel()
//        @State var favoritesViewModel = FavoritesViewModel()
        @State var fullTripTest = FullTripTest()
        @State var autoRefresh: Bool = false
        
        return NavigationStack() {
            FullTripView(fullTrip: fullTripTest.Trip)
                .environment(savedTripsModel)
//                .background(Background())
                    .navigationTitle("Genève, Rive") // Set back button text
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Text("") // Visible title
                        }
                    }
            }
            
    }
}

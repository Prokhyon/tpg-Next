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
    @EnvironmentObject var savedTripsModel: SavedTripsModel
    @EnvironmentObject var appRequirementsClass: AppRequirementsClass
    var fullTrip: TripEvent
    @StateObject private var lineManager = LineManager()
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    @State private var showTime = true
    
    @Namespace private var namespace


    var body: some View {
//        GeometryReader { geometry in
            ZStack {
                VStack(alignment: .leading) {
//                    Spacer(minLength: 70) //Space for trip title to be placed on top
                    ScrollView { //trip details scroll area
                        if !fullTrip.geoDeparture && (fullTrip.legs.first?.transfer ?? false || fullTrip.legs.first?.publishedLineName == "") { //Display departure stop input by user, if the first transport is from another stop
                            NavigationLink {
                                StopView(stopName: fullTrip.startName, stopSloid: fullTrip.startCode!, previousLineRef: "", previousLineName: "", previousLineTime: nil)
                            } label: {
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
                                            NavigationLink {//Departure stop for the leg
                                                StopView(stopName: leg.legBoardStopName, stopSloid: leg.legBoardStopId, previousLineRef: leg.journeyRef, previousLineName: leg.publishedLineName, previousLineTime: leg.legBoardTimetableTime)
                                            } label : {
                                                LineEventElementView(currentLine: leg.publishedLineName, operatorName: leg.legOperator, transportType: leg.transportTypeName, currentStop: false, eventName: leg.legBoardStopName, estimatedTime: leg.legBoardEstimatedTime, timetabledTime: leg.legBoardTimetableTime, plannedQuay: leg.legBoardQuay, showTime: $showTime, pastEventPossible: false)

                                        }
                                        .foregroundStyle(.primary)
                                        .contentShape(.contextMenuPreview, Capsule())
                                        .if(!dateStringHasPassed(with: leg.legBoardEstimatedTime, equalReturnsTrue: false)) { view in
                                            view.contextMenu {
                                                NotificationContextMenu(event: StopEvent(stopPointName: leg.legBoardStopName, stopId: leg.legBoardStopId, plannedQuay: leg.legBoardQuay, timetabledTime: leg.legBoardTimetableTime, estimatedTime: leg.legBoardEstimatedTime, lineName: leg.publishedLineName, origin: "", destination: leg.legDestination, transportType: leg.transportTypeName, operatorName: leg.legOperator, journeyRef: leg.journeyRef, operatingDayRef: leg.resolvedOperatingDayRef), stopID: leg.legBoardStopId)
                                            }
                                        }
                                        
                                        HStack { //Transport line name and destination for the leg. Navigates to a LineView
                                            Rectangle()
                                                .fill(.clear)
                                                .frame(width: 50)
                                            NavigationLink {
                                                LineView(stopEvent: createStopEventFromTripLeg(tripLeg: leg), currentStop: nil, currentLine: leg.publishedLineName)
                                            } label: {
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
                                        
                                            NavigationLink {//Arrival stop for the leg
                                                StopView(stopName: leg.legAlightStopName, stopSloid: leg.legAlightStopId, previousLineRef: leg.journeyRef, previousLineName: leg.publishedLineName, previousLineTime: leg.legAlightTimetableTime)
                                            } label: {
                                                LineEventElementView(currentLine: leg.publishedLineName, operatorName: leg.legOperator, transportType: leg.transportTypeName, currentStop: false, eventName: leg.legAlightStopName, estimatedTime: leg.legAlightEstimatedTime, timetabledTime: leg.legAlightTimetableTime, plannedQuay: leg.legAlightQuay, showTime: $showTime, pastEventPossible: false)
//
                                        }
                                        .foregroundStyle(.primary)
                                        .contentShape(.contextMenuPreview, Capsule())
                                        .if(!dateStringHasPassed(with: leg.legAlightEstimatedTime, equalReturnsTrue: false)) { view in
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
                        
                        if !fullTrip.geoArrival && (fullTrip.legs.last?.transfer ?? false || fullTrip.legs.last?.publishedLineName == "") { //Trip arrival stop if different from last transport leg arrival
                            NavigationLink {
                                StopView(stopName: fullTrip.endName, stopSloid: fullTrip.endCode!, previousLineRef: "", previousLineName: "", previousLineTime: nil)
                            } label: {
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
                    .onAppear {
                        showTime = timeDefault
                    }
                }
                if #available(iOS 26, *) {
                } else {
                    VStack(spacing: 0) {
                        Rectangle()
                            .foregroundStyle(.ultraThickMaterial)
                            .frame(height: 50)
                        Rectangle()
                            .foregroundStyle(.ultraThickMaterial)
                            .frame(height: 100)
                            .mask {
                                Rectangle()
                                    .overlay(alignment: .trailing) {
                                        ScrollMask(leading: true, vertical: true, gradientLength: 100)
                                    }
                            }
                        Spacer()
                    }
                    //                    .blur(radius: 10)
                    .ignoresSafeArea(edges: .top)
                }
                
                VStack { //Trip title above the details
                    if #available(iOS 26, *) {
                        GlassEffectContainer() {
                            HStack {
                                fullTripViewTitle(departureStopName: fullTrip.startName, arrivalStopName: fullTrip.endName)
                                    .foregroundStyle(.text)
                                    .frame(height: 70)
                                    .padding(.horizontal, 20)
                                    .glassEffect(.regular.interactive())
                                    .glassEffectID("title", in: namespace)
                                fullTripViewTimeDate(duration: fullTrip.duration, date: localDayString(fromUTC: fullTrip.startTime))
                                    .foregroundStyle(.text)
                                    .frame(height: 70)
                                    .padding(.horizontal, 20)
                                    .glassEffect(.regular.interactive())
                                    .glassEffectID("timeDate", in: namespace)
                            }
//                            .foregroundStyle(.primary)
                            .padding(.horizontal)
                        }
//                        .offset(x: 35)

                    } else {
                        HStack {
                            fullTripViewTitle(departureStopName: fullTrip.startName, arrivalStopName: fullTrip.endName)
                                .frame(height: 70)
                                .padding(.horizontal, 20)
                                .background {
                                    Capsule()
                                        .foregroundStyle(.thinMaterial)
                                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                }
                            Spacer()
                            fullTripViewTimeDate(duration: fullTrip.duration, date: localDayString(fromUTC: fullTrip.startTime))
                                .frame(height: 70)
                                .padding(.horizontal, 20)
                                .background {
                                    Capsule()
                                        .foregroundStyle(.thinMaterial)
                                        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                                }
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
                        NavigationLink {
                            TripMapView(tripEvent: fullTrip)
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
                        .opacity(appRequirementsClass.version26 ? 0 : 1)
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
                            VStack(alignment: .leading) {
                                let splitStopName = splitString(departureStopName, separator: ",")
                                if splitStopName.1.isEmpty {
                                    HStack(alignment: .center) {
                                        VStack {
                                    Text(splitStopName.0)
                                        .font(.title3)
                                        .bold()
                                        .minimumScaleFactor(0.5)
                                        }
                                    }
                                    .frame(height: 60)
                                } else {
                                    Text(splitStopName.0)
                                        .font(.callout)
                                        .minimumScaleFactor(0.5)
                                    Text(splitStopName.1)
                                        .font(.title2)
                                        .bold()
                                }
                            }
                            .minimumScaleFactor(0.5)
                            
                        Image(systemName: "arrow.right")

                            VStack(alignment: .leading) {
                            let splitStopName = splitString(arrivalStopName, separator: ",")
                            if splitStopName.1.isEmpty {
                                HStack(alignment: .center) {
                                    VStack {
                                        Text(splitStopName.0)
                                            .font(.title3)
                                            .bold()
                                            .minimumScaleFactor(0.5)
                                    }
                                }
                                .frame(height: 60)
                            } else {
                                        Text(splitStopName.0)
                                            .font(.callout)
                                            .minimumScaleFactor(0.5)
                                        Text(splitStopName.1)
                                            .font(.title2)
                                            .bold()
                                            
                            }
                        }
                        .minimumScaleFactor(0.5)
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
        @StateObject var savedTripsModel = SavedTripsModel()
        @StateObject var appRequirementsClass = AppRequirementsClass()
//        @StateObject var favoritesViewModel = FavoritesViewModel()
        @StateObject var fullTripTest = FullTripTest()
        @State var autoRefresh: Bool = false
        
        return NavigationStack() {
            FullTripView(fullTrip: fullTripTest.Trip)
                .environmentObject(savedTripsModel)
                .environmentObject(appRequirementsClass)
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

//
//  lineTest.swift
//  tpg Next
//
//  Created by Loris Thomas on 10.04.2025.
//

import tpgNextFunc
import SwiftUI

struct LineTest: View {
    var body: some View {
        Text("Hello, World!")
            .onAppear {
                fetchTransportJourney(with: StopEvent(stopPointName: "", stopId: "", plannedQuay: "", timetabledTime: "", estimatedTime: "", lineName: "", origin: "", destination: "", transportType: "", operatorName: "", journeyRef: "ch:1:sjyid:100680:HAS-25-A-1-Lun-Ven-32526383", operatingDayRef: "2025-04-10"), calls: false) { _,_ in
                    
                }
            }
    }
}

import MapKit

struct MapTest: View {
    @EnvironmentObject var appRequirementsClass: AppRequirementsClass
    var autoRefresh = true
    @Namespace var mapScope
    @State private var selectedResult: String?
    @State private var position: MapCameraPosition = .automatic
    var body: some View {
        ZStack {
            Map(scope: mapScope) {
                UserAnnotation().tint(.accent)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                    .foregroundStyle(.orange)
                MapPitchToggle()
                        .tint(.purple)
                //                        MapCompass()
                //                    MapScaleView()
            }
            HStack {
                MapUserLocationButton(scope: mapScope)
                    .tint(.orange)
                MapCompass(scope: mapScope)
            }
        }
        .mapScope(mapScope)
    }
}

struct MenuButton: View {
    
    var body: some View {
        if #available(iOS 26, *) {
            let menu = Group {
                Button(action: {
                }) {
                    Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                }
                Button(action: {
                }) {
                    Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                }
                Button(action: {
                }) {
                    Label("Trajet rapide", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
                }
            }
            Menu {
                menu
            } label: {
                Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                    .font(.title2)
            }
            .buttonStyle(.glass)
            //        .buttonStyle(.borderless)
            .foregroundStyle(.primary)
        }
    }
}
    
    struct StopEventTest: View {
        var event = StopEvent(stopPointName: "Meinier, Eglise", stopId: "8587061", plannedQuay: "A", timetabledTime: "2025-08-13T14:55:18Z", estimatedTime: "2025-08-13T14:55:18Z", lineName: "A", origin: "Gy, Temple", destination: "Genève, Rive", transportType: "Bus", operatorName: "Transports Publics Genevois", journeyRef: "ch:1:sjyid:100680:HAS-25-A-31-Lun-Ven-32504874", operatingDayRef: "2025-08-13")
        
        var body: some View {
            VStack {
                Spacer()
                
                if #available (iOS 26, *) {
                    StopEventViewContent(event: event, showTime: false)
                        .glassEffect()
                }
                
                StopEventViewContent(event: event, showTime: false)
                    .background(Capsule().fill(.color1).shadow(color: .gray.opacity(0.3), radius: 10))
                
                Capsule().fill(.color1).shadow(color: .gray.opacity(0.3), radius: 10)
                    .frame(height: 50)
                    .overlay (
                        StopEventViewContent(event: event, showTime: false)
                    )
                
                StopEventViewContent(event: event, showTime: false)
                    .background(Capsule().fill(.regularMaterial).shadow(color: .customShadows.opacity(0.3), radius: 10))
                
                Spacer()
            }
            .padding()
        }
    }

#Preview {
//    MapTest()
//    MenuButton()
    StopEventTest()
//        .background (Gradient(colors: [.accent, .color1, .color1]).opacity(0.7))
}

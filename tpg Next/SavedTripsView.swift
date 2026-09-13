//
//  SavedTripsView.swift
//  tpg Next
//
//  Trajets enregistrés.
//

import SwiftUI
import MapKit
import tpgNextFunc

struct SavedTripsView: View {
    @Environment(SavedTripsModel.self) var savedTripsModel
    @Environment(RegularTripsModel.self) var regularTripsModel
    @Binding var isPresented: Bool
    
    let onTripSelected: (TripEvent) -> Void
    
    var body: some View {
        ZStack {
            VStack {
                Rectangle()
                    .frame(height: 10)
                    .foregroundStyle(.clear)
                ScrollView {
                    ForEach(groupedEvents.keys.sorted(by: { $0 > $1 }), id: \.self) { date in
                        VStack(spacing: 0) {
                            // Display date as header in the desired format
                            HStack {
                                Text(formatDate(date))
                                    .font(.title3).bold()
                                    .padding(.top)
                                Spacer()
                            }
                            .padding(.horizontal, 30)
                            // Display events for this date
                            ForEach(groupedEvents[date]!.sorted(by: { $0.startTime < $1.startTime }), id: \.self) { trip in
                                Button(action: {
                                    onTripSelected(trip)
                                }) {
                                    VStack {
                                        SavedTripView(event: trip)
                                            .padding(15)
                                    }
                                    .background(
                                        BasicCard(cornerRadius: 30)
                                    )
                                }
                                .padding(5)
                                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 35))
                                .contextMenu {
                                    Button(action: {
                                        savedTripsModel.removeTrip(trip)
                                    }) {
                                        Label("Ne plus enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.minus")
                                    }
                                }
                                .padding(.horizontal, 15)
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                    Rectangle()
                        .frame(height: 10)
                        .foregroundStyle(.clear)
                }
                .contentMargins(.top, 60.0, for: .automatic)
            }
            VStack {
//                RoundedRectangle(cornerRadius: 25)
                Capsule()
                    .fill(.thinMaterial)
                    .frame(height: 60)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                    .padding(10)
                    .overlay(
                        Text("Itinéraires sauvegardés")
                            .font(.title2)
                            .bold()
                            .frame(height: 20.0)
                    )
                Spacer()
            }
            .contentMargins(.horizontal, 20, for: .automatic)
        }
    }
    var weeklyGeneratedTrips: [TripEvent] {
        let calendar = Calendar.current
        let today = Date()
        let weekdays = (0...6).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }

        return regularTripsModel.regularTrips.flatMap { regularTrip in
            weekdays.compactMap { day -> TripEvent? in
                guard let weekday = Weekday(rawValue: calendar.component(.weekday, from: day)) else { return nil }
                guard regularTrip.repeatingDays.contains(weekday) else { return nil }
                if let start = regularTrip.startDate, day < start { return nil }
                if let end = regularTrip.endDate, day > end { return nil }
                if regularTrip.exceptions.contains(where: { calendar.isDate($0, inSameDayAs: day) }) { return nil }

                var trip = regularTrip.trip
                trip.id = trip.id + UUID().uuidString // Differentiate each instance
                return trip
            }
        }
        
        func updateRegularTrip(_ trip: inout RegularTrip) {
            for leg in trip.trip.legs {
                if leg.transfer == false && leg.journeyRef != "" {
                    
                }
            }
        }
    }

    var groupedEvents: [Date: [TripEvent]] {
        let combined = savedTripsModel.savedTrips + weeklyGeneratedTrips
        return Dictionary(grouping: combined) { event in
            if let date = stringToDate(with: event.startTime) {
                return Calendar.current.startOfDay(for: date)
            } else {
                return Calendar.current.startOfDay(for: Date())
            }
        }
    }
    func formatDate(_ date: Date) -> String {
            let dateFormatter = DateFormatter()
//            dateFormatter.dateFormat = "EEE, d MMMM yyyy"
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        let formattedDate = dateFormatter.string(from: date)
            return formattedDate.prefix(1).capitalized + formattedDate.dropFirst()
        }
}

struct SavedTripView: View {
    var event: TripEvent
    
    var body: some View {
        VStack(alignment: .center) {
            HStack {
//                RoundedRectangle(cornerRadius: 20.0)
                BasicElement()
                    .frame(height: 45)
//                    .foregroundStyle(.thinMaterial)
//                    .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                    .overlay (
                        HStack {
                            Circle()
                                .strokeBorder(.primary, lineWidth: 5)
                                .background(Circle().fill(.color1))
                                .frame(width: 18, height: 18)
                            SmallStopTitleView(stopName: event.startName)
                            Text(dateToString(with: stringToDate(with: event.startTime) ?? Date()))
                            Spacer()
                        }
                            .padding(.horizontal)
                        )
            }
            HStack(spacing: 0) {
                    Image(systemName: "arrowshape.bounce.forward")
                    Text(" : \(event.transfers)")
                        .padding(.trailing)
                    Image(systemName: "timer")
                    Text(" : \(durationText(event.duration))")
                // Scrollable icon area
                ZStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Spacer()
                            ForEach(event.legs, id: \.id) { leg in
                                if !(leg.publishedLineName == "") {
                                    BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
                                        .padding(2)
                                } else if leg.transfer && durationMinutes(leg.transferWalkDuration) ?? 0 >= 5 {
                                    Image(systemName: "figure.walk").font(.caption)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                    }
                    .mask {
                        Rectangle()
                            .overlay(alignment: .leading) {
                                ScrollMask(leading: true, vertical: false, gradientLength: 25)
                            }
                    }
                    .mask {
                        Rectangle()
                            .overlay(alignment: .trailing) {
                                ScrollMask(leading: false, vertical: false, gradientLength: 25)
                            }
                    }
                    
                }
            }
            .padding(.vertical, 3)
            HStack {
//                RoundedRectangle(cornerRadius: 20.0)
                BasicElement()
                    .frame(height: 45)
                    .overlay (
                        HStack {
                            Circle()
                                .strokeBorder(.primary, lineWidth: 5)
                                .background(Circle().fill(.color1))
                                .frame(width: 18, height: 18)
                            SmallStopTitleView(stopName: event.endName)
                            Text(dateToString(with: stringToDate(with: event.endTime) ?? Date()))
                            Spacer()
                        }
                            .padding(.horizontal)
                        )
            }
            
        }
    }
}

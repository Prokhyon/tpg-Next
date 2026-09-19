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
                            ForEach(groupedEvents[date]!.sortedByStart(), id: \.self) { trip in
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
                .readableScrollContent()
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
                guard let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: day)) else { return nil }
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
            if let date = event.startDate {
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

/// Un itinéraire enregistré : les heures et le résumé, la frise, puis le départ et
/// l'arrivée, chacun sous son arrêt.
struct SavedTripView: View {
    var event: TripEvent

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(dateToString(with: event.startDate ?? Date()))
                Spacer()
                HStack {
                    Image(systemName: "arrowshape.bounce.forward")
                    Text(": \(event.transfers)")
                        .padding(.trailing)
                    Image(systemName: "timer")
                    Text(": \(durationText(event.duration))")
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Spacer()
                Text(dateToString(with: event.endDate ?? Date()))
            }
            // Aux tailles d'accessibilité, les deux heures ne laissaient que « : » entre elles.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            TripTimeline(event: event)
            HStack(alignment: .top, spacing: 12) {
                StopNameView(event.startName, style: .row)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StopNameView(event.endName, style: .row, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

#Preview("Trajets enregistrés") {
    @Previewable @State var isPresented = true
    SavedTripsView(isPresented: $isPresented) { _ in }
        .previewEnvironment(savedTrips: PreviewData.trips)
}

#Preview("Trajets enregistrés — vide") {
    @Previewable @State var isPresented = true
    SavedTripsView(isPresented: $isPresented) { _ in }
        .previewEnvironment(savedTrips: [])
}

#Preview("Trajet enregistré") {
    VStack {
        ForEach(PreviewData.trips.prefix(3)) { trip in
            SavedTripView(event: trip)
                .padding(15)
                .background(BasicCard(cornerRadius: 30))
                .padding(5)
        }
    }
    .padding()
    .previewEnvironment(navigation: false)
}

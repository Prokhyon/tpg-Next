//
//  RegularTrips.swift
//  tpg Next
//
//  Created by Loris Thomas on 26.03.2025.
//

//Trajet régulier
//  Répétition dans la semaine
//  Exceptions ?

//sauvegarder sous forme de lineEvent ou tripEvent ? Possibilité de facilement obtenir des mises à jour sur un trajet avec tripEvent ?
//pour l'instant faire les mises à jour avec lineEventRequest

//Recherche de trajet:
// point de départ, d'arrivée. heures de départ, choix si aller simple
//Choix des répétitions dans la semaine -> Vérification pour chaque jour si fonctionne ? (ou séparation weekday, saturday, Sunday ? )
//-> choix des trajets auxquels s'abonner
import tpgNextFunc

enum Weekday: Int, Codable, CaseIterable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// `Calendar` numérote à partir du dimanche (1), cette énumération à partir du lundi :
    /// les valeurs brutes ne sont pas interchangeables.
    init?(calendarWeekday: Int) {
        self.init(rawValue: (calendarWeekday + 5) % 7 + 1)
    }

    var calendarWeekday: Int { rawValue % 7 + 1 }
}

public struct RegularTrip: Identifiable, Codable {
    public var id: String { trip.id }
    var trip: TripEvent
    var repeatingDays: [Weekday] // e.g. [.monday, .wednesday, .friday]
    var exceptions: [Date] = [] // dates to skip the regular trip
    var startDate: Date? = nil
    var endDate: Date? = nil
    
}


import SwiftUI

struct WeeklyRegularTripsView: View {
    let regularTrips: [RegularTrip]
    let calendar = Calendar.current
    let today = Date()
    
    var body: some View {
        List {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                let tripsForDay = regularTripsFor(weekday: weekday)
                
                if !tripsForDay.isEmpty {
                    Section(header: Text(weekdayDisplayName(for: weekday))) {
                        ForEach(tripsForDay, id: \.trip.id) { regularTrip in
                            SavedTripView(event: regularTrip.trip)
                        }
                    }
                }
            }
        }
        .navigationTitle("This Week’s Trips")
    }

    private func regularTripsFor(weekday: Weekday) -> [RegularTrip] {
        regularTrips.filter { trip in
            trip.repeatingDays.contains(weekday) &&
            !trip.exceptions.contains(where: { calendar.isDate($0, inSameDayAs: date(for: weekday)) }) &&
            (trip.startDate == nil || (trip.startDate! <= date(for: weekday))) &&
            (trip.endDate == nil || (trip.endDate! >= date(for: weekday)))
        }
    }

    private func weekdayDisplayName(for weekday: Weekday) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        return formatter.weekdaySymbols[weekday.calendarWeekday - 1].capitalized
    }

    private func date(for weekday: Weekday) -> Date {
        calendar.nextDate(after: today, matching: DateComponents(weekday: weekday.calendarWeekday), matchingPolicy: .nextTimePreservingSmallerComponents) ?? today
    }
}


struct AddRegularTripView: View {
    var trip: TripEvent
    @State var tripDays: [Weekday] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Regular Trip")
                .font(.title)
            SavedTripView(event: trip)
                .padding(15)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.thinMaterial)
                        .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                )

            Text("Select days to repeat:")
                .font(.headline)

            VStack(alignment: .leading) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button(action: {
                        if tripDays.contains(day) {
                            tripDays.removeAll { $0 == day }
                        } else {
                            tripDays.append(day)
                        }
                    }) {
                        HStack {
                            Text(weekdayDisplayName(for: day))
                            Spacer()
                            if tripDays.contains(day) {
                                Image(systemName: "checkmark.circle.fill")
                            } else {
                                Image(systemName: "circle")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            Button("Save Trip") {
                addTripToRegular(trip)
            }
            .padding(.top, 20)
            .disabled(tripDays.isEmpty)

            Spacer()
        }
        .padding()
    }
    func addTripToRegular(_ trip: TripEvent) {
        let regularTrip = RegularTrip(trip: trip, repeatingDays: tripDays)
        // Save logic goes here
    }
}

func weekdayDisplayName(for weekday: Weekday) -> String {
    let formatter = DateFormatter()
    formatter.locale = .current
    return formatter.weekdaySymbols[weekday.calendarWeekday - 1].capitalized
}

#Preview("Ajouter un trajet régulier") {
    AddRegularTripView(trip: PreviewData.tripWithTransfer)
        .previewEnvironment()
}

#Preview("Trajets réguliers de la semaine") {
    WeeklyRegularTripsView(regularTrips: [
        RegularTrip(trip: PreviewData.tripWithTransfer, repeatingDays: [.monday, .tuesday, .thursday]),
        RegularTrip(trip: PreviewData.directTrip, repeatingDays: [.wednesday, .friday]),
    ])
    .previewEnvironment()
}

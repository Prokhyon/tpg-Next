//
//  WidgetClose.swift
//  TPG4
//
//  Created by Loris Thomas on 25.06.2024.
//

import SwiftUI

struct Event {
    let title: String
    let date: Date
    let location: String
    let symbol: String
}

struct EventTile: View {
    @StateObject private var stopManager = StopManager()
    @StateObject private var stopStore = StopStore()
    let listTest: [String] = ["aa", "bb", "cc"]
    let event: Event
    let stripeHeight = 15.0
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: event.symbol)
                .font(.title)
            VStack(/*alignment: .leading*/) {
                /*Text(event.title)
                    .font(.title)
                Text(
                    event.date,
                    format: Date.FormatStyle()
                        .day(.defaultDigits)
                        .month(.wide)
                )
                Text(event.location)*/
                List(stopManager.stopEvents, id: \.id) { event in
                    Text(event.lineName)
                    Text(event.destination)
                }
                .scrollContentBackground(.hidden)
                .onAppear {
                    stopManager.selectStop(stopStore.activeStops[4], stopEventNumber: 4)
                }
            }
        }
        .padding()
        .padding(.top, stripeHeight)
        .background {
            ZStack(alignment: .top) {
                Rectangle()
                    .opacity(0.3)
                Rectangle()
                    .frame(maxHeight: stripeHeight)
            }
            .foregroundColor(.teal)
        }
        .clipShape(RoundedRectangle(cornerRadius: stripeHeight, style: .continuous))
    }
}

struct WidgetClose: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

/*#Preview {
    WidgetClose()
}*/

struct EventTile_Previews: PreviewProvider {
    static let event = Event(title: "Buy Daisies", date: .now, location: "Flower Shop", symbol: "gift")
    
    static var previews: some View {
        EventTile(event: event)
    }
}

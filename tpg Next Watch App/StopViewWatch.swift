//
//  StopViewWatch.swift
//  watch tpg Next Watch App
//
//  Created by Loris Thomas on 30.12.2024.
//

import SwiftUI
import Combine
import tpgNextFunc

struct SmallStopTitleView: View {
    var stopName: String

    var body: some View {
        HStack {
            StopNameView(stopName, style: .compact)
            Spacer()
        }
    }
}

/// Le rond qui marque un arrêt dans les listes de la montre.
struct StopDot: View {
    var body: some View {
        Circle()
            .strokeBorder(Color.primary, lineWidth: 5)
            .background(Circle().fill(.black))
            .frame(width: 20, height: 20)
    }
}

/// Un départ dans la liste triée par horaire.
struct StopEventView: View  {
    @Environment(\.displayTime) private var now
    var event: StopEvent
    var showTime: Bool

    var body: some View {
        VStack {
            let transportTime = departureDisplay(for: event, showTime: showTime, at: now)
            HStack {
                BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                Image(systemName: "arrow.right").font(.caption)
                SmallStopTitleView(stopName: event.destination)
            }
            HStack {
                DepartureTimeView(transportTime, transportType: event.transportType, layout: .inline(spacing: 5), iconWidth: 15)
                    .padding(4)
                RouteChangedIcon(event: event)
                Spacer()
                QuayIcon(quay: event.plannedQuay)
            }

        }
        .padding(.vertical, 4)
    }
}

extension StopEvent {
    /// Le départ de la course d'où l'arrêt a été ouvert.
    func isLinked(to journeyRef: String?) -> Bool {
        !self.journeyRef.isEmpty && self.journeyRef == journeyRef
    }
}

/// Le fond d'une rangée de départ : entouré pour celui de la course d'où l'arrêt a été ouvert.
private struct LinkedRowBackground: ViewModifier {
    let isLinked: Bool

    func body(content: Content) -> some View {
        if isLinked {
            content.listRowBackground(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.15))
                    .strokeBorder(.white, lineWidth: 2)
            )
        } else {
            content
        }
    }
}

/// Repère orange, comme sur l'iPhone : la course dessert l'arrêt mais en saute d'autres, ou
/// suit un horaire exceptionnel. Une course supprimée l'est déjà en rouge à la place de l'heure.
struct RouteChangedIcon: View {
    let event: StopEvent

    var body: some View {
        if event.routeChanged {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("Parcours modifié")
        } else if event.exceptional {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("Horaire exceptionnel")
        }
    }
}

struct StopView: View {
    @Environment(\.displayTime) private var now
    @AppStorage(SettingKey.clockTimeByDefault) private var showTime = false
    @AppStorage(SettingKey.groupByLineByDefault) private var viewLineSorted = true
    @State private var stopManager = StopManager()
    let stopName: String
    let stopSloid: String
    /// Ouvert depuis une course : son départ est mis en évidence…
    var previousLineRef: String?
    /// … et la liste part de son heure de passage.
    var previousLineTime: String?
    var isCloseStop: Bool
    var autoRefresh = true
    @State private var timeRequest = Date()
    /// L'heure choisie dans le menu (« +30 min ») ; `nil` : maintenant, ou l'heure de la course.
    @State private var chosenStart: Date?
    private let requestNumber = 30
    /// La dernière réponse reçue : affichée quand le réseau manque.
    @State private var lastUpdate: Date?
    @State private var showMenu = false
    /// Les lignes affichées ; vide : toutes.
    @State private var selectedLines: Set<String> = []
    /// La page affichée dans le tri par ligne (« ligne;destination »).
    @State private var selectedGroup: String?

    private var filteredStopEvents: [StopEvent] {
        selectedLines.isEmpty ? stopManager.stopEvents : stopManager.stopEvents.filter { selectedLines.contains($0.lineName) }
    }

    private var groupedStopEvents: [String: [StopEvent]] {
        filteredStopEvents.groupedByLineAndDestination()
    }

    /// Les lignes de l'arrêt, dans l'ordre des pages, avec leur exploitant pour la couleur.
    private var lines: [StopMenuView.Line] {
        var seen = Set<String>()
        return stopManager.stopEvents
            .sorted { lineGroupPrecedes("\($0.lineName);", "\($1.lineName);") }
            .compactMap { event in
                seen.insert(event.lineName).inserted ? StopMenuView.Line(name: event.lineName, operatorName: event.operatorName) : nil
            }
    }

    /// La liste part plus tard que maintenant : on l'indique sous le nom de l'arrêt.
    private var isShifted: Bool {
        timeRequest.timeIntervalSince(now) > 60
    }

    /// L'API répond qu'il n'y a aucun départ (et non une erreur réseau).
    private var hasNoDepartures: Bool {
        stopManager.stopError && !stopManager.stopErrorMessage.isEmpty
    }

    /// Le réseau a manqué : les départs affichés sont ceux de la dernière réponse.
    private var isOffline: Bool {
        stopManager.stopError && stopManager.stopErrorMessage.isEmpty
    }

    var body: some View {
        Group {
            if hasNoDepartures {
                message("Pas de départs trouvés")
            } else if stopManager.stopEvents.isEmpty && isOffline {
                message("Connexion impossible", retry: true)
            } else if stopManager.stopEvents.isEmpty {
                VStack {
                    header
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if filteredStopEvents.isEmpty {
                message("Aucun départ pour ces lignes")
            } else if viewLineSorted {
                ZStack {
                    TabView(selection: $selectedGroup) {
                        ForEach(groupedStopEvents.keys.sorted(by: lineGroupPrecedes), id: \.self) { key in
                            let splitLine = splitString(key, separator: ";")
                            let events = groupedStopEvents[key]!
                            StopSortedView(lineName: splitLine.0, destination: splitLine.1, currentStopSloid: stopSloid,
                                           previousLineRef: previousLineRef, stopEventsList: events, showTime: showTime)
                                .containerBackground(LineColors.lineColor(for: splitLine.0, operatorName: events[0].operatorName).gradient,
                                                     for: .tabView)
                                .tag(Optional(key))
                        }
                    }
                    .tabViewStyle(.verticalPage)
                    VStack {
                        header
                        Spacer()
                    }
                }
            } else {
                List {
                    header
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    ForEach(filteredStopEvents.sortedByDeparture(), id: \.id) { event in
                        NavigationLink(value: WatchRoute.journey(event, fromStopSloid: stopSloid)) {
                            StopEventView(event: event, showTime: showTime)
                                .foregroundStyle(determineColor(for: event))
                        }
                        .modifier(LinkedRowBackground(isLinked: event.isLinked(to: previousLineRef)))
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMenu.toggle()
                } label: {
                    Image(systemName: selectedLines.isEmpty ? "ellipsis" : "line.3.horizontal.decrease")
                }
                .accessibilityLabel("Options")
            }
        }
        .sheet(isPresented: $showMenu) {
            StopMenuView(showMenu: $showMenu, showTime: $showTime, viewLineSorted: $viewLineSorted,
                         lines: lines, selectedLines: $selectedLines, start: isShifted ? timeRequest : nil,
                         shiftStart: shiftStart)
        }
        .onChange(of: stopManager.stopEvents) {
            selectPreviousLineGroup()
        }
        .periodicRefresh(repeats: autoRefresh) { trigger in
            // Chaque rafraîchissement repart de maintenant : les bus déjà partis quittent la
            // liste. Ouvert depuis une course, ou décalé dans le menu, l'arrêt part de cette
            // heure, gardée tant qu'elle est à venir.
            let origin = chosenStart ?? timeRequest(for: previousLineTime)
            timeRequest = trigger == .start ? origin : max(Date(), origin)
            getStopEvents()
        }
    }

    /// Le nom de l'arrêt, en haut de toutes les dispositions.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            StopRow(name: stopName, isNearby: isCloseStop)
            HStack(spacing: 4) {
                if isShifted {
                    HeaderCapsule(systemImage: "clock") {
                        Text("Dès \(timeRequest, format: .dateTime.hour().minute())")
                    }
                }
                if isOffline, let lastUpdate {
                    HeaderCapsule(systemImage: "wifi.slash") {
                        Text("Hors ligne · \(lastUpdate, format: .dateTime.hour().minute())")
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }

    private func message(_ text: LocalizedStringKey, retry: Bool = false) -> some View {
        VStack {
            header
            Spacer()
            Text(text)
                .multilineTextAlignment(.center)
            if retry {
                Button("Réessayer", action: reload)
            }
            Spacer()
        }
    }

    private func getStopEvents() {
        stopManager.selectStop(stopName: stopName, stopSloid: stopSloid, stopEventNumber: requestNumber, timeRequest: timeRequest) {
            if !stopManager.stopError {
                lastUpdate = Date()
            }
        }
    }

    /// Redemande les départs, comme un rafraîchissement automatique.
    private func reload() {
        timeRequest = max(Date(), chosenStart ?? timeRequest(for: previousLineTime))
        getStopEvents()
    }

    /// Décale le début de la liste de `minutes` ; `nil` revient à maintenant.
    private func shiftStart(by minutes: Int?) {
        let start = minutes.map { timeRequest.addingTimeInterval(Double($0) * 60) } ?? Date()
        chosenStart = start
        timeRequest = start
        getStopEvents()
    }

    /// Ouvert depuis une course, le tri par ligne s'ouvre sur la page de sa ligne.
    private func selectPreviousLineGroup() {
        guard selectedGroup == nil, let previousLineRef,
              let event = filteredStopEvents.first(where: { $0.journeyRef == previousLineRef }) else { return }
        selectedGroup = "\(event.lineName);\(event.destination)"
    }

    func determineColor(for event: StopEvent) -> Color {
        hasPassed(event.departureDate, includingCurrentMinute: false, now: now) ? .gray : .primary
    }

    func timeRequest(for time: String?) -> Date {
        // Une heure absente ou illisible veut dire « les départs à partir de maintenant ».
        guard let time, let date = stringToDate(with: time) else { return Date() }
        return date
    }
}


/// Une information sous le nom de l'arrêt : heure choisie, réseau absent.
private struct HeaderCapsule<Content: View>: View {
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        Label {
            content
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption2)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(.thinMaterial, in: Capsule())
    }
}

struct StopSortedView: View {
    @Environment(\.displayTime) private var now
    var lineName: String
    var destination: String
    var currentStopSloid: String
    var previousLineRef: String?
    var stopEventsList: [StopEvent]
    var showTime: Bool

    var body: some View {
        ZStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(stopEventsList, id: \.id) { stopEvent in
                        let time = departureDisplay(for: stopEvent, showTime: showTime, at: now)
                        NavigationLink(value: WatchRoute.journey(stopEvent, fromStopSloid: currentStopSloid)) {
                            HStack(spacing: 2) {
                                DepartureTimeView(time, transportType: stopEvent.transportType, layout: .inline(spacing: 2), iconWidth: 15)
                                RouteChangedIcon(event: stopEvent)
                            }
                            .padding(.horizontal)
                        }
                        .padding(2)
                        .foregroundStyle(.primary)
                        .overlay {
                            if stopEvent.isLinked(to: previousLineRef) {
                                Capsule().strokeBorder(.white, lineWidth: 2)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            VStack {
                Spacer()
                HStack {
                    let quay = stopEventsList.first?.plannedQuay ?? "?"
                    BusLineIcon(lineName: lineName, operatorName: stopEventsList[0].operatorName)
                    Image(systemName: "arrow.right")
                    SmallStopTitleView(stopName: destination)
                    Spacer()
                    QuayIcon(quay: quay)
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

struct StopMenuView: View {
    struct Line: Hashable {
        let name: String
        let operatorName: String
    }

    @Binding var showMenu: Bool
    @Binding var showTime: Bool
    @Binding var viewLineSorted: Bool
    var lines: [Line] = []
    @Binding var selectedLines: Set<String>
    /// Le début de la liste quand il a été décalé ; `nil` : maintenant.
    var start: Date?
    /// Minutes à ajouter au début de la liste ; `nil` revient à maintenant.
    var shiftStart: (Int?) -> Void = { _ in }

    var body: some View {
        List {
            Section {
                Button {
                    showTime.toggle()
                    showMenu = false
                } label: {
                    showTime ? Label("Temps restant", systemImage: "hourglass.circle") : Label("Afficher l'heure", systemImage: "hourglass.circle.fill")
                }
                Button {
                    viewLineSorted.toggle()
                    showMenu = false
                } label: {
                    viewLineSorted ? Label("Trier par horaire", systemImage: "text.justify") : Label("Trier par ligne", systemImage: "rectangle.grid.1x2.fill")
                }
            }
            Section {
                HStack {
                    shiftButton("+15 min", minutes: 15)
                    shiftButton("+30 min", minutes: 30)
                    shiftButton("+1 h", minutes: 60)
                }
                .buttonStyle(.bordered)
                .listRowBackground(Color.clear)
                if start != nil {
                    Button {
                        shiftStart(nil)
                        showMenu = false
                    } label: {
                        Label("Maintenant", systemImage: "clock.arrow.circlepath")
                    }
                }
            } header: {
                if let start {
                    Text("Départs dès \(start, format: .dateTime.hour().minute())")
                } else {
                    Text("Départs plus tard")
                }
            }
            if lines.count > 1 {
                Section("Lignes") {
                    if !selectedLines.isEmpty {
                        Button {
                            selectedLines = []
                        } label: {
                            Label("Toutes les lignes", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                    ForEach(lines, id: \.self) { line in
                        Button {
                            if selectedLines.remove(line.name) == nil {
                                selectedLines.insert(line.name)
                            }
                        } label: {
                            HStack {
                                BusLineIcon(lineName: line.name, operatorName: line.operatorName)
                                Spacer()
                                if selectedLines.contains(line.name) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .accessibilityAddTraits(selectedLines.contains(line.name) ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func shiftButton(_ title: LocalizedStringKey, minutes: Int) -> some View {
        Button {
            shiftStart(minutes)
            showMenu = false
        } label: {
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

#Preview("Arrêt (API)") {
    NavigationStack {
        StopView(stopName: WatchPreviewData.rive.name, stopSloid: WatchPreviewData.rive.sloid, isCloseStop: false, autoRefresh: false)
            .navigationDestination(for: WatchRoute.self) { $0.destination }
    }
    .watchPreviewEnvironment()
    .defaultAppStorage(.previewSettings(groupByLine: false))
}

#Preview("Arrêt par ligne (API)") {
    NavigationStack {
        StopView(stopName: WatchPreviewData.rive.name, stopSloid: WatchPreviewData.rive.sloid, isCloseStop: true, autoRefresh: false)
            .navigationDestination(for: WatchRoute.self) { $0.destination }
    }
    .watchPreviewEnvironment()
    .defaultAppStorage(.previewSettings(groupByLine: true))
}

#Preview("Départs") {
    List {
        StopEventView(event: WatchPreviewData.departure(inMinutes: 0), showTime: false)
        StopEventView(event: WatchPreviewData.departure(inMinutes: 4), showTime: false)
        StopEventView(event: WatchPreviewData.departure(line: "7", destination: "Vessy, Grands-Esserts", quay: "A",
                                                        inMinutes: 7, delay: 3, transportType: "Bus"), showTime: false)
        StopEventView(event: WatchPreviewData.departure(line: "8", destination: "Palexpo", quay: "E", inMinutes: 9,
                                                        cancelled: true, transportType: "Bus"), showTime: false)
        StopEventView(event: WatchPreviewData.departure(line: "5", destination: "Aéroport", quay: "C", inMinutes: 11,
                                                        routeChanged: true, transportType: "Bus"), showTime: false)
        StopEventView(event: WatchPreviewData.departure(inMinutes: 12), showTime: true)
        StopEventView(event: WatchPreviewData.departure(line: "E", destination: "Hermance-Village", quay: "J",
                                                        inMinutes: 15, transportType: "Bus"), showTime: false)
            .modifier(LinkedRowBackground(isLinked: true))
    }
    .watchPreviewEnvironment()
}

#Preview("Départs par ligne") {
    // Comme dans StopView : une page par ligne, fond à la couleur de la ligne.
    let groups = [
        ("12", "Genève, Moillesulaz", WatchPreviewData.departures()),
        ("7", "Vessy, Grands-Esserts", WatchPreviewData.departures(line: "7", destination: "Vessy, Grands-Esserts", quay: "A", every: 10)),
        ("E", "Hermance-Village", WatchPreviewData.departures(line: "E", destination: "Hermance-Village", quay: "J", every: 20, count: 3)),
    ]
    TabView {
        ForEach(groups, id: \.0) { line, destination, events in
            StopSortedView(lineName: line, destination: destination, currentStopSloid: WatchPreviewData.rive.sloid,
                           previousLineRef: events.count > 1 ? events[1].journeyRef : nil,
                           stopEventsList: events, showTime: false)
                .containerBackground(LineColors.lineColor(for: line, operatorName: "Transports Publics Genevois").gradient,
                                     for: .tabView)
        }
    }
    .tabViewStyle(.verticalPage)
    .watchPreviewEnvironment()
}

#Preview("Menu de l'arrêt") {
    @Previewable @State var showMenu = true
    @Previewable @State var showTime = false
    @Previewable @State var viewLineSorted = false
    @Previewable @State var selectedLines: Set<String> = ["12"]
    StopMenuView(showMenu: $showMenu, showTime: $showTime, viewLineSorted: $viewLineSorted,
                 lines: [.init(name: "7", operatorName: "Transports Publics Genevois"),
                         .init(name: "12", operatorName: "Transports Publics Genevois"),
                         .init(name: "E", operatorName: "Transports Publics Genevois")],
                 selectedLines: $selectedLines, start: Date().addingTimeInterval(30 * 60))
}

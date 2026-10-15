//
//  JourneyViewWatch.swift
//  tpg Next Watch App
//
//  La course d'un départ : ses arrêts, ses heures de passage et la position du véhicule.
//

import SwiftUI
import tpgNextFunc

/// Les écrans qu'on ouvre depuis la page d'un arrêt. Comme `AppRoute` sur l'iPhone : un lien dit
/// quoi ouvrir, la pile de navigation (`ContentView`) construit l'écran.
enum WatchRoute: Hashable {
    /// La course d'un départ, ouverte depuis l'arrêt `fromStopSloid`.
    case journey(StopEvent, fromStopSloid: String)
    /// Les départs d'un arrêt. Ouvert depuis une course (`passage`), à partir de l'heure de
    /// passage du véhicule.
    case stop(name: String, sloid: String, isNearby: Bool = false, passage: JourneyPassage? = nil)
    /// Le détail d'un trajet de « Mes trajets ».
    case trip(UpcomingTrip)

    @ViewBuilder var destination: some View {
        switch self {
        case .journey(let event, let sloid):
            JourneyView(stopEvent: event, currentStopSloid: sloid)
        case .stop(let name, let sloid, let isNearby, let passage):
            StopView(stopName: name, stopSloid: sloid, previousLineRef: passage?.journeyRef, previousLineTime: passage?.time,
                     isCloseStop: isNearby)
        case .trip(let trip):
            TripDetailView(trip: trip)
        }
    }
}

/// Le passage d'une course à un arrêt : la page de l'arrêt part de cette heure et entoure ce départ.
struct JourneyPassage: Hashable {
    let journeyRef: String
    let time: String
}

struct JourneyView: View {
    @Environment(\.displayTime) private var now
    @AppStorage(SettingKey.clockTimeByDefault) private var showTime = false
    @State private var lineManager = LineManager()
    @State private var events: [LineEvent]
    @State private var operatorName: String
    @State private var service: JourneyService?
    @State private var failed = false
    /// Blocs d'arrêts sautés dont l'utilisateur a inversé l'état (replié ou déplié).
    @State private var expandedSkippedBlocks: Set<String> = []
    @State private var scrollDone = false

    let stopEvent: StopEvent
    /// L'arrêt d'où la course a été ouverte : mis en évidence, et la liste s'y place.
    let currentStopSloid: String
    let autoRefresh: Bool

    /// - Parameter events: les arrêts à afficher sans les demander (aperçus, avec `autoRefresh: false`).
    init(stopEvent: StopEvent, currentStopSloid: String, autoRefresh: Bool = true, events: [LineEvent] = []) {
        self.stopEvent = stopEvent
        self.currentStopSloid = currentStopSloid
        self.autoRefresh = autoRefresh
        _events = State(initialValue: events)
        _operatorName = State(initialValue: stopEvent.operatorName)
    }

    private var lineColor: Color {
        LineColors.lineColor(for: stopEvent.lineName, operatorName: operatorName)
    }

    /// L'arrêt que le véhicule va desservir ensuite (ou où il se trouve).
    private var nextStopID: String? {
        events.first { $0.isCancelled != true && !hasPassed($0.departureDate, includingCurrentMinute: false, now: now) }?.id
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, 6)
                    if events.isEmpty {
                        placeholder
                    }
                    ForEach(journeyRows(events)) { row in
                        switch row {
                        case .stop(let event):
                            stopRow(event)
                        case .skipped(let stops):
                            skippedBlock(stops)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .onChange(of: events) {
                guard !scrollDone, let current = events.first(where: { $0.sloid == currentStopSloid }) else { return }
                scrollDone = true
                // Après la mise en page des nouvelles rangées.
                DispatchQueue.main.async {
                    scroll.scrollTo(current.id, anchor: .top)
                }
            }
        }
        .containerBackground(lineColor.gradient.opacity(0.6), for: .navigation)
        .navigationTitle(Text("Ligne \(stopEvent.lineName)"))
        .periodicRefresh(repeats: autoRefresh) { _ in
            load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                BusLineIcon(lineName: stopEvent.lineName, operatorName: operatorName)
                Image(systemName: "arrow.right")
                    .font(.caption)
                StopNameView(stopEvent.destination, style: .compact)
            }
            disruption
            if stopEvent.cancelled, let alternative = nearestServedStop(skipping: currentStopSloid, in: events, now: now) {
                alternativeLink(alternative)
            }
        }
    }

    /// Même ordre que l'iPhone (`LineDetailPane`) : la suppression avant le parcours modifié.
    @ViewBuilder private var disruption: some View {
        if !events.isEmpty, events.allSatisfy({ $0.isCancelled == true }) {
            DisruptionLabel(text: "Course supprimée", systemImage: "exclamationmark.triangle.fill", tint: .red)
        } else if stopEvent.cancelled {
            DisruptionLabel(text: "Ne passe pas à cet arrêt", systemImage: "exclamationmark.triangle.fill", tint: .red)
        } else if service?.hasIncident == true || stopEvent.routeChanged {
            DisruptionLabel(text: "Parcours modifié", systemImage: "exclamationmark.triangle.fill", tint: .orange)
        }
        if stopEvent.exceptional {
            DisruptionLabel(text: "Horaire exceptionnel", systemImage: "calendar.badge.exclamationmark", tint: .orange)
        }
    }

    /// Le départ ne passe pas à l'arrêt affiché : où prendre ce même véhicule à pied.
    private func alternativeLink(_ alternative: ServedAlternative) -> some View {
        NavigationLink(value: WatchRoute.stop(name: alternative.stop.stopPointName, sloid: alternative.stop.sloid,
                                              passage: JourneyPassage(journeyRef: stopEvent.journeyRef, time: alternative.stop.timetabledTime))) {
            HStack {
                Image(systemName: "figure.walk")
                VStack(alignment: .leading) {
                    Text("Passe à \(Text(stopName: alternative.stop.stopPointName))")
                        .font(.caption)
                    Text("≈ \(alternative.walkingMinutes) min à pied")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var placeholder: some View {
        if failed {
            VStack {
                Text("Course introuvable")
                    .foregroundStyle(.secondary)
                Button("Réessayer", action: load)
            }
            .frame(maxWidth: .infinity)
            .padding(.top)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top)
        }
    }

    /// Un arrêt de la course ; le toucher ouvre ses départs à l'heure de passage du véhicule.
    private func stopRow(_ event: LineEvent) -> some View {
        NavigationLink(value: WatchRoute.stop(name: event.stopPointName, sloid: event.sloid,
                                              passage: JourneyPassage(journeyRef: stopEvent.journeyRef, time: event.timetabledTime))) {
            JourneyStopRow(event: event, transportType: stopEvent.transportType, showTime: showTime,
                           isFirst: event.id == events.first?.id, isLast: event.id == events.last?.id,
                           isCurrent: event.sloid == currentStopSloid, isNext: event.id == nextStopID)
        }
        .buttonStyle(.plain)
        .id(event.id)
    }

    /// Plusieurs arrêts sautés d'affilée, repliés. Déplié d'office s'il contient l'arrêt
    /// d'où la course a été ouverte : c'est lui que l'utilisateur cherche.
    @ViewBuilder private func skippedBlock(_ stops: [LineEvent]) -> some View {
        let id = JourneyRow.skipped(stops).id
        let containsCurrent = stops.contains { $0.sloid == currentStopSloid }
        let expanded = expandedSkippedBlocks.contains(id) != containsCurrent
        Button {
            withAnimation {
                if expandedSkippedBlocks.remove(id) == nil {
                    expandedSkippedBlocks.insert(id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                JourneyTrail(isFirst: false, isLast: false, passedAbove: false, passedBelow: false, skipped: true)
                    .frame(width: JourneyTrail.width)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(stops.count) arrêts non desservis")
                        .font(.caption.bold())
                    if let first = stops.first, let last = stops.last {
                        Text(route: first.stopPointName, to: last.stopPointName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if expanded {
            ForEach(stops) { stopRow($0) }
        }
    }

    private func load() {
        // Aperçus : la course est déjà là et ne doit pas être redemandée.
        guard autoRefresh || events.isEmpty else { return }
        lineManager.selectJourney(stopEvent) {
            // Un échec garde la course déjà affichée.
            if lineManager.lineEvents.isEmpty {
                failed = events.isEmpty
                return
            }
            failed = false
            events = lineManager.lineEvents
            operatorName = lineManager.operatorName
            service = lineManager.service
        }
    }
}

/// Une perturbation de la course, en une ligne colorée.
private struct DisruptionLabel: View {
    let text: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(tint)
    }
}

/// Un arrêt de la course : le trait de la ligne, le nom, l'heure de passage et le quai.
struct JourneyStopRow: View {
    @Environment(\.displayTime) private var now
    let event: LineEvent
    let transportType: String
    let showTime: Bool
    let isFirst: Bool
    let isLast: Bool
    /// L'arrêt d'où la course a été ouverte.
    let isCurrent: Bool
    /// Le prochain arrêt du véhicule : il y est, ou il y va.
    let isNext: Bool

    private var skipped: Bool { event.isCancelled == true }

    var body: some View {
        // Arrivé à l'arrêt (minute en cours) ou plus loin ; reparti.
        let reached = hasPassed(event.departureDate, includingCurrentMinute: true, now: now)
        let left = hasPassed(event.departureDate, includingCurrentMinute: false, now: now)
        HStack(spacing: 8) {
            JourneyTrail(isFirst: isFirst, isLast: isLast, passedAbove: reached, passedBelow: left, skipped: skipped,
                         isCurrent: isCurrent, vehicle: vehicle(reached: reached), transportType: transportType)
                .frame(width: JourneyTrail.width)
            VStack(alignment: .leading, spacing: 1) {
                StopNameView(event.stopPointName, style: .compact)
                    .strikethrough(skipped)
                if skipped {
                    Text("Non desservi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if !skipped {
                VStack(alignment: .trailing, spacing: 2) {
                    DepartureTimeView(departureDisplay(timetabled: event.timetabledTime, estimated: event.estimatedTime,
                                                       showTime: showTime, at: now),
                                      transportType: transportType, iconWidth: 15)
                        .font(.footnote)
                    if !event.plannedQuay.isEmpty {
                        QuayIcon(quay: event.plannedQuay)
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.trailing, 6)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.18))
            }
        }
        .opacity(skipped ? 0.5 : left ? 0.45 : 1)
        .contentShape(Rectangle())
    }

    private func vehicle(reached: Bool) -> JourneyTrail.Vehicle {
        guard isNext else { return .none }
        if reached { return .atStop }
        // Pas encore parti du terminus : rien à montrer.
        return isFirst ? .none : .approaching
    }
}

/// Le trait de la ligne d'une rangée : plein jusqu'au passage du véhicule, atténué ensuite,
/// en pointillé là où il ne s'arrête pas.
struct JourneyTrail: View {
    enum Vehicle { case none, approaching, atStop }

    static let width: CGFloat = 18

    let isFirst: Bool
    let isLast: Bool
    let passedAbove: Bool
    let passedBelow: Bool
    let skipped: Bool
    var isCurrent = false
    var vehicle: Vehicle = .none
    var transportType = ""

    var body: some View {
        GeometryReader { geometry in
            let x = geometry.size.width / 2
            let middle = geometry.size.height / 2
            if skipped {
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                .stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 6]))
            } else {
                if !isFirst {
                    segment(passed: passedAbove, height: middle)
                        .position(x: x, y: middle / 2)
                }
                if !isLast {
                    segment(passed: passedBelow, height: middle)
                        .position(x: x, y: middle * 1.5)
                }
                if vehicle == .atStop {
                    vehicleIcon.position(x: x, y: middle)
                } else {
                    Circle()
                        .fill(.black)
                        .overlay(Circle().strokeBorder(.white, lineWidth: isCurrent ? 4 : 3))
                        .frame(width: isCurrent ? 14 : 10, height: isCurrent ? 14 : 10)
                        .position(x: x, y: middle)
                    if vehicle == .approaching {
                        vehicleIcon.position(x: x, y: 0)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func segment(passed: Bool, height: CGFloat) -> some View {
        Rectangle()
            .fill(.white.opacity(passed ? 0.3 : 1))
            .frame(width: 4, height: height)
    }

    private var vehicleIcon: some View {
        transportIcon(with: transportType)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: Self.width, height: Self.width)
            .background(Circle().fill(.white))
    }
}

#Preview("Course") {
    // Ligne 12, ouverte depuis Genève, Rive : deux arrêts passés, le tram arrive à Rive.
    let stops = WatchPreviewData.journey()
    NavigationStack {
        JourneyView(stopEvent: WatchPreviewData.departure(inMinutes: 1), currentStopSloid: WatchPreviewData.rive.sloid,
                    autoRefresh: false, events: stops)
    }
    .watchPreviewEnvironment()
}

#Preview("Course — arrêts sautés") {
    let stops = WatchPreviewData.journey(skipping: 3...5)
    NavigationStack {
        JourneyView(stopEvent: WatchPreviewData.departure(inMinutes: 1, routeChanged: true),
                    currentStopSloid: WatchPreviewData.rive.sloid, autoRefresh: false, events: stops)
    }
    .watchPreviewEnvironment()
}

#Preview("Course (API)") {
    // Une course n'existe que le jour même : on part d'un vrai départ de Genève, Rive.
    @Previewable @State var event: StopEvent?
    @Previewable @State var manager = StopManager()
    NavigationStack {
        if let event {
            JourneyView(stopEvent: event, currentStopSloid: WatchPreviewData.rive.sloid)
        } else {
            ProgressView()
        }
    }
    .watchPreviewEnvironment()
    .task {
        manager.selectStop(stopName: WatchPreviewData.rive.name, stopSloid: WatchPreviewData.rive.sloid,
                           stopEventNumber: 5, timeRequest: Date()) {
            event = manager.stopEvents.first { !$0.cancelled }
        }
    }
}

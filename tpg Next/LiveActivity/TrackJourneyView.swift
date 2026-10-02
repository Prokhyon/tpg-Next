//
//  TrackJourneyView.swift
//  tpg Next
//
//  Suivre une course en direct depuis un départ : d'où l'on part, jusqu'où l'on va. Les arrêts
//  de la course en capsules sur le trait de la ligne, comme sur la page d'une ligne ; le tronçon
//  suivi prend la couleur de la ligne, le reste s'estompe.
//

import SwiftUI
import tpgNextFunc

/// L'autre arrêt de la course : la descente si l'on monte à l'arrêt touché, la montée si l'on
/// y descend. Le sens vient du menu du départ ; il se change en haut de la feuille. Le suivi
/// part du bouton du bas, une fois l'arrêt choisi : un toucher de trop ne le lance plus.
struct TrackJourneyView: View {
    /// Le départ touché (la course, la ligne, la destination).
    let event: StopEvent
    /// L'arrêt de ce départ, sur la course.
    let stopSloid: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayTime) private var now
    @State private var manager = LineManager()
    @State private var events: [LineEvent]
    @State private var operatorName: String
    @State private var loaded: Bool
    /// `true` : on part de cet arrêt ; `false` : on y descend.
    @State private var departsFromStop: Bool
    /// L'autre arrêt choisi.
    @State private var otherID: LineEvent.ID?
    private var liveActivities = TripLiveActivities.shared

    /// - Parameter previewSelection: l'autre arrêt déjà choisi, pour les aperçus.
    init(event: StopEvent, stopSloid: String, departsFromStop: Bool = true,
         previewEvents: [LineEvent]? = nil, previewSelection: LineEvent.ID? = nil) {
        self.event = event
        self.stopSloid = stopSloid
        _departsFromStop = State(initialValue: departsFromStop)
        _events = State(initialValue: previewEvents ?? [])
        _operatorName = State(initialValue: event.operatorName)
        _loaded = State(initialValue: previewEvents != nil)
        _otherID = State(initialValue: previewSelection)
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !loaded {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if currentIndex == nil {
                        Text("Cette course n'est pas disponible pour le moment.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        stopList
                    }
                }
                .padding(.bottom, 20)
            }
            .readableScrollContent()
            // La ligne et le sens restent en haut : la liste défile jusqu'à l'arrêt du départ.
            .pinnedTop {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    directionPicker
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom) {
                if loaded, currentIndex != nil {
                    bottomAction
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .animation(.snappy, value: otherID)
                }
            }
            .onChange(of: loaded) { scrollToCurrent(scroll) }
            .onAppear { scrollToCurrent(scroll) }
        }
        .navigationTitle("Suivre en direct")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !loaded else { return }
            manager.selectJourney(event) {
                events = manager.lineEvents
                if !manager.operatorName.isEmpty { operatorName = manager.operatorName }
                loaded = true
            }
        }
    }

    // MARK: En-tête

    /// « [29] → Versoix **La Scie** », comme le titre d'une page ligne.
    private var header: some View {
        HStack(spacing: 10) {
            BusLineIcon(lineName: event.lineName, operatorName: operatorName)
            Image(systemName: "arrow.right")
                .font(.headline)
            Text(stopName: event.destination)
                .font(.title3)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 20)
    }

    /// Le sens, en deux capsules : monter ou descendre à l'arrêt du départ.
    private var directionPicker: some View {
        HStack(spacing: 8) {
            directionButton(true, title: "À partir d'ici", systemImage: "arrow.down.to.line")
            directionButton(false, title: "Jusqu'ici", systemImage: "arrow.up.to.line")
        }
        .padding(.horizontal)
    }

    private func directionButton(_ value: Bool, title: LocalizedStringKey, systemImage: String) -> some View {
        Button {
            guard departsFromStop != value else { return }
            withAnimation(.snappy) {
                departsFromStop = value
                otherID = nil
            }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .basicElementBackground(minHeight: 44, selected: departsFromStop == value)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(departsFromStop == value ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: departsFromStop)
    }

    private var instruction: LocalizedStringKey {
        let stop = shortStopName(event.stopPointName)
        if choices.isEmpty {
            return departsFromStop ? "\(stop) est le terminus de la course." : "La course commence à \(stop)."
        }
        return departsFromStop ? "Touchez l'arrêt où vous descendez" : "Touchez l'arrêt où vous montez"
    }

    // MARK: Arrêts

    private var lineColor: Color {
        LineColors.lineColor(for: event.lineName, operatorName: operatorName)
    }

    private var stopList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, stop in
                let choosable = choices.contains(index)
                Button {
                    withAnimation(.snappy) {
                        otherID = otherID == stop.id ? nil : stop.id
                    }
                } label: {
                    stopRow(stop, index: index)
                }
                .buttonStyle(.plain)
                // Pas `.disabled` : l'arrêt du départ, qu'on ne choisit pas, s'afficherait grisé.
                .allowsHitTesting(choosable)
                .accessibilityRespondsToUserInteraction(choosable)
                .padding(.horizontal, 15)
                .padding(.vertical, 5)
                .background(TrackedTrail(index: index, count: events.count, tracked: trackedRange, color: lineColor))
                .id(stop.id)
                .sensoryFeedback(.selection, trigger: otherID)
            }
        }
    }

    private func stopRow(_ stop: LineEvent, index: Int) -> some View {
        let isCurrent = index == currentIndex
        let isOther = stop.id == otherID
        let skipped = stop.isCancelled == true
        let active = isCurrent || choices.contains(index)
        return HStack {
            StopIcon(color: LineColors.lineColor(for: event.lineName, operatorName: operatorName, inverted: true),
                     currentStop: isCurrent, terminus: isOther)
            SmallStopTitleView(stopName: stop.stopPointName)
                .strikethrough(skipped)
            Spacer()
            if skipped {
                Text("Non desservi")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                DepartureTimeView(departureDisplay(timetabled: stop.timetabledTime, estimated: stop.estimatedTime,
                                                   showTime: true, at: now),
                                  transportType: event.transportType, iconWidth: 10, showsIcon: false)
                    .padding(.vertical, 4)
            }
        }
        .padding(.horizontal)
        .opacity(active ? 1 : 0.35)
        .basicElementBackground(minHeight: 45, highlighted: isCurrent, selected: isOther)
        .padding(5)
        .contentShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOther ? .isSelected : [])
        .accessibilityHint(isCurrent ? Text("Arrêt du départ") : Text(""))
    }

    // MARK: Bouton

    /// Tant qu'aucun arrêt n'est choisi, la consigne ; ensuite, le bouton qui lance le suivi.
    @ViewBuilder private var bottomAction: some View {
        if otherStop != nil {
            confirmButton
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        } else {
            Label(instruction, systemImage: choices.isEmpty ? "info.circle" : "hand.tap")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .basicElementBackground(minHeight: 50)
                .transition(.opacity)
        }
    }

    private var confirmButton: some View {
        Button {
            startTracking()
        } label: {
            VStack(spacing: 2) {
                Text("Lancer le suivi")
                    .font(.headline)
                if let summary {
                    Text(summary)
                        .font(.caption)
                        .opacity(0.85)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .prominentButtonStyle()
    }

    /// « Rive 14:32 → Cornavin 14:41 ».
    private var summary: String? {
        guard let current = currentStop, let other = otherStop else { return nil }
        let (board, alight) = departsFromStop ? (current, other) : (other, current)
        func label(_ stop: LineEvent) -> String {
            let time = stop.departureDate.map { dateToString(with: $0) } ?? ""
            return "\(shortStopName(stop.stopPointName)) \(time)"
        }
        return "\(label(board)) → \(label(alight))"
    }

    // MARK: Course

    /// La place de l'arrêt touché sur la course.
    private var currentIndex: Int? {
        let sloid = sloidHarmonizer(code: stopSloid)
        return events.firstIndex { sloidHarmonizer(code: $0.sloid) == sloid }
    }

    private var currentStop: LineEvent? { currentIndex.map { events[$0] } }

    private var otherStop: LineEvent? {
        guard let otherID, let index = events.firstIndex(where: { $0.id == otherID }), choices.contains(index) else { return nil }
        return events[index]
    }

    /// Les arrêts qu'on peut choisir : après celui-ci si on en part, avant si on y descend.
    /// Un arrêt sauté ou une montée déjà passée ne servent à rien.
    private var choices: Set<Int> {
        guard let current = currentIndex else { return [] }
        let range = departsFromStop ? Array(events.indices.dropFirst(current + 1)) : Array(events.indices.prefix(current))
        return Set(range.filter { index in
            let stop = events[index]
            return stop.isCancelled != true
                && (departsFromStop || !hasPassed(stop.departureDate, includingCurrentMinute: false, now: now))
        })
    }

    /// Le tronçon suivi : de l'arrêt touché à l'arrêt choisi.
    private var trackedRange: ClosedRange<Int>? {
        guard let current = currentIndex,
              let other = otherID.flatMap({ id in events.firstIndex { $0.id == id } }) else { return nil }
        return min(current, other)...max(current, other)
    }

    private func scrollToCurrent(_ scroll: ScrollViewProxy) {
        guard loaded, let current = currentStop else { return }
        DispatchQueue.main.async {
            scroll.scrollTo(current.id, anchor: UnitPoint(x: 0, y: 0.1))
        }
    }

    private func startTracking() {
        guard let current = currentStop, let other = otherStop else { return }
        let board = departsFromStop ? current : other
        let alight = departsFromStop ? other : current
        guard liveActivities.areEnabled else {
            NotificationConfirmationViewModel.shared.show(
                message: String(localized: "Les activités en direct sont désactivées pour tpg Next.\nChangez-le dans les réglages du téléphone"),
                error: true)
            return
        }
        guard liveActivities.hasLocation else {
            liveActivities.askForLocation()
            return
        }
        liveActivities.start(journey: event, events: events, operatorName: operatorName,
                             board: board, alight: alight)
        let started = liveActivities.isTracking(TripLiveActivities.key(forJourney: event, boardSloid: board.sloid))
        NotificationConfirmationViewModel.shared.show(
            message: started
                ? String(localized: "Suivi en direct de la ligne \(event.lineName) lancé")
                : String(localized: "Le suivi en direct n'a pas pu être lancé"),
            error: !started)
        dismiss()
    }
}

private extension View {
    /// En haut de la feuille. Sur iOS 26, la liste s'estompe dessous comme sous une barre ;
    /// avant, elle passe sous un fond de barre.
    @ViewBuilder func pinnedTop<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .top, content: content)
        } else {
            safeAreaInset(edge: .top) { content().background(.bar) }
        }
    }
}

/// Le trait de la ligne derrière une rangée, aligné sur le point d'arrêt (comme `LineBackground`) :
/// de la couleur de la ligne sur le tronçon suivi, estompé ailleurs.
private struct TrackedTrail: View {
    let index: Int
    let count: Int
    let tracked: ClosedRange<Int>?
    let color: Color
    var trailX: CGFloat = 45

    var body: some View {
        GeometryReader { geometry in
            let half = geometry.size.height / 2 + 8
            if index > 0 {
                Rectangle()
                    .fill(color.opacity(isTracked(index - 1, index) ? 1 : 0.25))
                    .frame(width: 7, height: half)
                    .position(x: trailX, y: geometry.size.height / 4)
            }
            if index < count - 1 {
                Rectangle()
                    .fill(color.opacity(isTracked(index, index + 1) ? 1 : 0.25))
                    .frame(width: 7, height: half)
                    .position(x: trailX, y: geometry.size.height / 4 * 3)
            }
        }
    }

    private func isTracked(_ from: Int, _ to: Int) -> Bool {
        guard let tracked else { return false }
        return tracked.contains(from) && tracked.contains(to)
    }
}

#Preview("Suivre une course") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            TrackJourneySheet(event: PreviewData.lineDeparture, stopSloid: PreviewData.rive.sloid,
                              departsFromStop: true, previewEvents: PreviewData.journeyStops)
        }
        .previewEnvironment()
}

#Preview("Suivre une course — (API)") {
    LiveDeparturePreview(stop: PreviewData.rive) { departures in
        TrackJourneySheet(event: departures.event, stopSloid: PreviewData.rive.sloid, departsFromStop: true)
    }
    .previewEnvironment()
}

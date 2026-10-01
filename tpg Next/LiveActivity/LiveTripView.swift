//
//  LiveTripView.swift
//  tpg Next
//
//  Le trajet suivi dans l'app : le bandeau attaché en bas, et le trajet en entier par-dessus.
//

import SwiftUI
import tpgNextFunc

/// Le trajet suivi ouvert par-dessus l'app, comme le lecteur de Musique : le bandeau s'ouvre en
/// plein écran, et se referme en glissant vers le bas (le bandeau réapparaît alors).
///
/// La feuille est posée par `ContentView`, au-dessus des onglets : le bandeau, lui, est refait à
/// chaque changement d'étape, et emporterait sa feuille avec lui.
@MainActor
@Observable
final class LiveTripPresentation {
    static let shared = LiveTripPresentation()

    /// Le trajet ouvert en plein écran, s'il y en a un.
    private(set) var openedKey: String?

    var isOpen: Bool {
        get { openedKey != nil }
        set { if !newValue { openedKey = nil } }
    }

    func open(_ key: String) { openedKey = key }
    func close() { openedKey = nil }
}

/// Le bandeau du trajet suivi, attaché au-dessus des onglets (comme le lecteur de Musique).
/// Il montre l'étape en cours, et ouvre le trajet en entier.
struct TripLiveAccessory: View {
    @Environment(\.displayTime) private var now
    let key: String
    let live: TripLiveActivities.LiveTrip

    var body: some View {
        let step = TripActivityStep(attributes: live.attributes, state: live.state, now: now)
        Button {
            LiveTripPresentation.shared.open(key)
        } label: {
            HStack(spacing: 10) {
                TripActivityMarker(step: step, compact: true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(step.action)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(step.stopName)
                        .font(.subheadline.bold())
                }
                .lineLimit(1)
                Spacer(minLength: 6)
                TripActivityMinutes(target: step.target)
                    .font(.subheadline.bold())
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Trajet suivi : \(step.action) \(step.stopName)"))
    }
}

/// Pose le bandeau du trajet suivi : attaché aux onglets sur iOS 26, flottant avant.
struct TripLiveAccessoryModifier: ViewModifier {
    private var liveActivities = TripLiveActivities.shared

    /// Un bandeau vide occupe quand même sa place : quand rien n'est suivi, il n'est pas posé
    /// du tout, plutôt que posé sans contenu.
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *), let current = liveActivities.current {
            content.tabViewBottomAccessory {
                TripLiveAccessory(key: current.key, live: current.trip)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Le trajet suivi, attaché sous les onglets.
    func liveTripAccessory() -> some View { modifier(TripLiveAccessoryModifier()) }
}

// MARK: - Le trajet en entier

/// Tout le trajet suivi, de haut en bas : le départ, chaque véhicule avec ses arrêts, les
/// attentes et l'arrivée. L'étape en cours est mise en évidence, les étapes passées s'effacent.
struct LiveTripView: View {
    let key: String
    /// Pour les aperçus : le trajet à afficher quand rien n'est suivi.
    var previewTrip: TripLiveActivities.LiveTrip?

    @Environment(\.displayTime) private var now
    @Environment(\.dismiss) private var dismiss
    /// Les véhicules dont on a déplié les arrêts intermédiaires.
    @State private var expanded: Set<Int> = []
    private var liveActivities = TripLiveActivities.shared

    private var trip: TripLiveActivities.LiveTrip? { liveActivities.live[key] ?? previewTrip }

    var body: some View {
        ZStack {
            ScrollView {
                if let trip {
                    VStack(alignment: .leading, spacing: 0) {
                        header(trip)
                        if let doubt = liveActivities.doubtful[key] {
                            DoubtfulTransferCard(doubt: doubt,
                                                 boarded: { liveActivities.confirmBoarded(key) },
                                                 missed: { liveActivities.confirmMissed(key) })
                            .padding(.bottom, 14)
                        }
                        if let options = liveActivities.alternatives[key], options.count > 1 {
                            ReplanOptionsCard(options: options, chosen: liveActivities.chosenAlternative[key]) {
                                liveActivities.choose($0, for: key)
                            }
                            .padding(.bottom, 14)
                        }
                        timeline(trip)
                    }
                    .padding(.horizontal, 15)
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "inset.filled.circle.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Ce trajet n'est plus suivi")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .readableScrollContent()
            .navigationTitle(trip?.attributes.title ?? String(localized: "Trajet suivi"))
            .navigationBarTitleDisplayMode(.inline)
            VStack {
                Spacer()
                Button(role: .destructive) {
                    liveActivities.stop(key)
                    dismiss()
                } label: {
                    Label("Arrêter le suivi", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .tpgSurface(interactive: true)
                .buttonStyle(.bordered)
                .padding()
            }
        }
    }

    // MARK: En-tête

    private func header(_ trip: TripLiveActivities.LiveTrip) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(trip.attributes.title)
                .font(.title2.bold())
            HStack(spacing: 5) {
                Text("Arrivée \(trip.state.arrival.formatted(date: .omitted, time: .shortened))")
                if trip.state.arrivalDelay >= 2 {
                    Text("+\(trip.state.arrivalDelay)'")
                        .foregroundStyle(trip.state.arrivalDelay >= 5 ? .red : .orange)
                }
                Text("· \(shortStopName(trip.attributes.destination))")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.subheadline)
            if let alert = trip.state.alert {
                Label(alert, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }
            // Dans le véhicule, la position affine l'horaire : le dire, pour que l'écart avec
            // l'heure annoncée ailleurs ne surprenne pas.
            if let offset = trip.state.positionOffset {
                let minutes = max(1, Int((Double(abs(offset)) / 60).rounded()))
                Label {
                    if offset > 0 {
                        Text("Ajusté d'après votre position : \(minutes)' de retard")
                    } else {
                        Text("Ajusté d'après votre position : \(minutes)' d'avance")
                    }
                } icon: {
                    Image(systemName: "location.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 20)
    }

    // MARK: La frise

    @ViewBuilder
    private func timeline(_ trip: TripLiveActivities.LiveTrip) -> some View {
        let state = trip.state
        let phase = state.phase(at: now)
        let legs = state.legs
        // Une marche finale sépare la dernière descente de l'arrivée ; sans elle, la descente
        // est l'arrivée, et une seule rangée suffit.
        let finalWalk = legs.last.map { state.arrival.timeIntervalSince($0.alight) > 60 } ?? false
        let start = hasStart(state)

        VStack(spacing: 0) {
            if start, let first = legs.first {
                place(name: trip.attributes.origin, time: state.departure, label: "Départ",
                      symbol: "figure.walk.circle.fill", tint: .secondary,
                      above: .none, below: .dotted, past: state.departure < now)
                note(walkText(from: state.departure, to: first.board), past: first.board < now)
            }

            ForEach(Array(legs.enumerated()), id: \.offset) { index, leg in
                let color = LineColors.lineColor(for: leg.line, operatorName: leg.operatorName)
                let isLast = index == legs.count - 1
                let isEnd = isLast && !finalWalk

                place(name: leg.boardName, time: leg.board, label: boardLabel(leg),
                      symbol: "arrow.up.circle.fill", tint: color,
                      above: index == 0 && !start ? .none : .dotted, below: .solid(color),
                      past: leg.board < now, highlighted: phase == .waiting(leg: index),
                      target: phase == .waiting(leg: index) ? leg.board : nil, delay: leg.delay)

                ride(leg, index: index, color: color, riding: phase == .riding(leg: index))

                place(name: leg.alightName, time: leg.alight,
                      label: isEnd ? "Arrivée" : "Descente",
                      symbol: isEnd ? "mappin.circle.fill" : "arrow.down.circle.fill",
                      tint: color, above: .solid(color), below: isEnd ? .none : .dotted,
                      past: leg.alight < now,
                      highlighted: phase == .riding(leg: index) || (isEnd && phase == .arrived),
                      target: phase == .riding(leg: index) ? leg.alight : nil)

                if index + 1 < legs.count {
                    note(waitText(from: leg.alight, to: legs[index + 1].board), past: legs[index + 1].board < now)
                }
            }

            if let last = legs.last, finalWalk {
                note(walkText(from: last.alight, to: state.arrival), past: state.arrival < now)
                place(name: trip.attributes.destination, time: state.arrival, label: "Arrivée",
                      symbol: "mappin.circle.fill", tint: .secondary, above: .dotted, below: .none,
                      past: state.arrival < now, highlighted: phase == .arrived)
            }
        }
    }

    /// Vrai si la frise commence par le départ à pied : la première montée a alors un trait au-dessus.
    private func hasStart(_ state: TripActivityState) -> Bool {
        guard let first = state.legs.first else { return false }
        return first.board.timeIntervalSince(state.departure) > 60
    }

    private func boardLabel(_ leg: TripActivityState.Leg) -> LocalizedStringKey {
        leg.boardQuay.isEmpty ? "Montée" : "Montée · quai \(leg.boardQuay)"
    }

    private func walkText(from: Date, to: Date) -> LocalizedStringKey {
        "\(minutes(from, to))' à pied"
    }

    private func waitText(from: Date, to: Date) -> LocalizedStringKey {
        "\(minutes(from, to))' d'attente"
    }

    private func minutes(_ from: Date, _ to: Date) -> Int {
        max(0, Int((to.timeIntervalSince(from) / 60).rounded()))
    }

    // MARK: Les rangées

    /// Un arrêt de la frise : le départ, une montée, une descente ou l'arrivée.
    private func place(name: String, time: Date, label: LocalizedStringKey, symbol: String, tint: Color,
                       above: LiveTripRail, below: LiveTripRail, past: Bool,
                       highlighted: Bool = false, target: Date? = nil, delay: Int = 0) -> some View {
        LiveTripRow(above: above, below: below, highlighted: highlighted, tint: tint,
                    past: past && !highlighted) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .background(Circle().fill(.background).padding(3))
        } content: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    StopNameView(shortStopName(name), style: .row)
                        .font(highlighted ? .title3.bold() : .body.weight(.medium))
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(dateToString(with: time))
                            .font(.subheadline.bold())
                        if delay >= 2 {
                            Text("+\(delay)'")
                                .font(.subheadline.bold())
                                .foregroundStyle(delay >= 5 ? .red : .orange)
                        }
                    }
                    if let target {
                        TripActivityMinutes(target: target)
                            .font(.caption.bold())
                            .foregroundStyle(tint)
                    }
                }
            }
        }
    }

    /// Le trajet à bord : la ligne, sa direction, et les arrêts entre la montée et la descente.
    @ViewBuilder
    private func ride(_ leg: TripActivityState.Leg, index: Int, color: Color, riding: Bool) -> some View {
        let calls = (leg.calls ?? []).filter { $0.time > leg.board && $0.time < leg.alight }
        // Le véhicule en route : ses arrêts s'ouvrent d'eux-mêmes, pour voir où il en est.
        let open = expanded.contains(index) || riding
        let vehicleStop = riding ? leg.vehicleStop(at: now) : nil
        LiveTripRow(above: .solid(color), below: .solid(color), highlighted: riding, tint: color,
                    past: leg.alight < now && !riding) {
            TripActivityLineBadge(line: leg.line, color: color)
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("→ \(Text(stopName: leg.destination))")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        if let vehicleStop {
                            Text("Actuellement à \(vehicleStop)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(minutes(leg.board, leg.alight))' de trajet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 4)
                    if !calls.isEmpty {
                        Button {
                            withAnimation(.snappy) {
                                if expanded.contains(index) { expanded.remove(index) } else { expanded.insert(index) }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("\(calls.count) arrêts")
                                Image(systemName: open ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if open {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(calls, id: \.self) { call in
                            let atVehicle = call.name == vehicleStop
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(atVehicle ? color : Color.secondary.opacity(0.4))
                                    .frame(width: atVehicle ? 9 : 5, height: atVehicle ? 9 : 5)
                                    .frame(width: 10)
                                Text(call.name)
                                    .font(.footnote.weight(atVehicle ? .semibold : .regular))
                                Spacer(minLength: 4)
                                Text(dateToString(with: call.time))
                                    .font(.footnote)
                            }
                            .foregroundStyle(call.time < now && !atVehicle ? .tertiary : .secondary)
                        }
                    }
                }
            }
        }
    }

    /// Une attente ou une marche : pas de marqueur, le trait pointillé traverse la rangée.
    private func note(_ text: LocalizedStringKey, past: Bool) -> some View {
        LiveTripRow(above: .dotted, below: .dotted, highlighted: false, tint: .secondary, past: past,
                    markerInset: 0) {
            EmptyView()
        } content: {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)
        }
    }
}

/// La correspondance serrée : ni l'horaire ni la position ne tranchent, seul le voyageur sait.
struct DoubtfulTransferCard: View {
    let doubt: TripLiveActivities.DoubtfulTransfer
    let boarded: () -> Void
    let missed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Correspondance serrée à \(doubt.stop)")
                    .font(.subheadline.bold())
            } icon: {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
            }
            Text("Le \(doubt.line) partait au moment où vous descendiez. Êtes-vous monté dedans ?")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(action: boarded) {
                    Text("Je suis monté").frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                Button(action: missed) {
                    Text("Je l'ai manqué").frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BasicCard(cornerRadius: 25))
    }
}

/// Les suites proposées après un recalcul : la plus tôt arrivée s'applique, le voyageur peut
/// en préférer une autre.
struct ReplanOptionsCard: View {
    let options: [TripLiveActivities.ReplanOption]
    let chosen: String?
    let choose: (TripLiveActivities.ReplanOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Autres suites possibles")
                .font(.subheadline.bold())
                .padding(.bottom, 2)
            ForEach(options) { option in
                Button {
                    choose(option)
                } label: {
                    HStack(spacing: 10) {
                        TripActivityLineBadge(line: option.line,
                                              color: LineColors.lineColor(for: option.line,
                                                                          operatorName: option.operatorName),
                                              compact: true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Départ \(dateToString(with: option.departure))")
                                .font(.subheadline)
                            Text("Arrivée \(dateToString(with: option.arrival))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: chosen == option.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(chosen == option.id ? Color.accentColor : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BasicCard(cornerRadius: 25))
    }
}

// MARK: - Les traits et les rangées

/// Un trait de la frise : plein à la couleur de la ligne à bord, en pointillés à pied ou en
/// attente, absent avant le départ et après l'arrivée.
enum LiveTripRail {
    case none
    case solid(Color)
    case dotted

    @ViewBuilder
    var segment: some View {
        switch self {
        case .none:
            Color.clear.frame(width: 5)
        case .solid(let color):
            Rectangle().fill(color).frame(width: 5)
        case .dotted:
            DottedLine()
                .stroke(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 6]))
                .frame(width: 3)
                .padding(.vertical, 2)
        }
    }

    private struct DottedLine: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            }
        }
    }
}

/// Une rangée de la frise : le trait et son marqueur à gauche, l'étape à droite. L'étape en
/// cours est posée sur un fond teinté ; les étapes passées s'effacent.
struct LiveTripRow<Marker: View, Content: View>: View {
    let above: LiveTripRail
    let below: LiveTripRail
    let highlighted: Bool
    let tint: Color
    let past: Bool
    /// La hauteur de trait au-dessus du marqueur, pour l'aligner sur la première ligne de texte.
    var markerInset: CGFloat = 4
    @ViewBuilder let marker: Marker
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                above.segment.frame(height: markerInset)
                marker
                below.segment.frame(maxHeight: .infinity)
            }
            .frame(width: 42)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if highlighted {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(tint.opacity(0.14))
                    }
                }
                .padding(.bottom, 8)
                .opacity(past ? 0.45 : 1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Aperçus

#Preview("Bandeau du trajet suivi") {
    VStack {
        Spacer()
        TripLiveAccessory(key: "preview", live: .preview)
            .frame(height: 50)
            .background(Capsule().fill(.thinMaterial))
            .padding(.horizontal)
    }
    .previewEnvironment()
}

extension TripLiveActivities.LiveTrip {
    /// Données inventées : le 12 dans quatre minutes, puis le 19.
    static var preview: TripLiveActivities.LiveTrip {
        let now = Date()
        let board = now.addingTimeInterval(4 * 60)
        let calls = ["Bel-Air", "Molard", "Rive", "Terrassière"].enumerated().map { index, name in
            TripActivityState.Call(name: name, time: board.addingTimeInterval(TimeInterval(index - 2) * 100))
        }
        let state = TripActivityState(
            legs: [
                .init(line: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                      destination: "Carouge, Bachet", boardName: "Genève, Rive", boardQuay: "B",
                      board: board, alight: board.addingTimeInterval(300), alightName: "Genève, Terrassière",
                      delay: 0, calls: calls),
            ],
            departure: now, arrival: board.addingTimeInterval(420), arrivalDelay: 0, alert: nil, updated: now)
        return TripLiveActivities.LiveTrip(
            attributes: TripActivityAttributes(key: "preview", title: "Travail", origin: "Genève, Rive",
                                               destination: "Genève, gare Cornavin"),
            state: state)
    }

    /// Deux véhicules et une correspondance, pour voir toute la frise.
    static var previewTransfer: TripLiveActivities.LiveTrip {
        let now = Date()
        let board = now.addingTimeInterval(3 * 60)
        let firstAlight = board.addingTimeInterval(9 * 60)
        let secondBoard = firstAlight.addingTimeInterval(4 * 60)
        func calls(_ names: [String], from: Date, step: TimeInterval) -> [TripActivityState.Call] {
            names.enumerated().map { .init(name: $0.element, time: from.addingTimeInterval(TimeInterval($0.offset) * step)) }
        }
        let state = TripActivityState(
            legs: [
                .init(line: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                      destination: "Carouge, Bachet", boardName: "Genève, Rive", boardQuay: "B",
                      board: board, alight: firstAlight, alightName: "Genève, Plainpalais", delay: 3,
                      calls: calls(["Bel-Air", "Molard", "Rive", "Cirque", "Plainpalais"],
                                   from: board.addingTimeInterval(-120), step: 150)),
                .init(line: "15", operatorName: "Transports Publics Genevois", transportType: "Tram",
                      destination: "Nations", boardName: "Genève, Plainpalais", boardQuay: "",
                      board: secondBoard, alight: secondBoard.addingTimeInterval(6 * 60),
                      alightName: "Genève, gare Cornavin", delay: 0, calls: nil),
            ],
            departure: now, arrival: secondBoard.addingTimeInterval(9 * 60), arrivalDelay: 3, alert: nil, updated: now)
        return TripLiveActivities.LiveTrip(
            attributes: TripActivityAttributes(key: "preview", title: "Travail", origin: "Genève, Terrassière",
                                               destination: "Genève, Servette"),
            state: state)
    }
}

extension TripLiveActivities.LiveTrip {
    /// À bord du premier véhicule : ses arrêts s'ouvrent, et sa position s'y lit.
    static var previewRiding: TripLiveActivities.LiveTrip {
        var trip = previewTransfer
        let shift: TimeInterval = -7 * 60
        trip.state.legs = trip.state.legs.map { leg in
            var leg = leg
            leg.board.addTimeInterval(shift)
            leg.alight.addTimeInterval(shift)
            leg.calls = leg.calls?.map { .init(name: $0.name, time: $0.time.addingTimeInterval(shift)) }
            return leg
        }
        trip.state.departure.addTimeInterval(shift)
        trip.state.arrival.addTimeInterval(shift)
        trip.state.positionOffset = 95
        return trip
    }
}

#Preview("Trajet suivi — à bord") {
    LiveTripView(key: "preview", previewTrip: .previewRiding)
        .previewEnvironment()
}

#Preview("Trajet suivi") {
    LiveTripView(key: "preview", previewTrip: .preview)
        .previewEnvironment()
}

#Preview("Trajet suivi — correspondance") {
    LiveTripView(key: "preview", previewTrip: .previewTransfer)
        .previewEnvironment()
}

extension TripLiveActivities.ReplanOption {
    /// Deux suites inventées depuis Plainpalais, pour l'aperçu.
    static var previews: [TripLiveActivities.ReplanOption] {
        var trip = PreviewData.tripWithTransfer
        guard let after = trip.trackedLegs.first, let departure = after.boardDate,
              let arrival = trip.endDate else { return [] }
        let first = TripLiveActivities.ReplanOption(
            trip: trip, after: after, line: "15", operatorName: "Transports Publics Genevois",
            departure: departure, arrival: arrival)
        trip.id += "-bis"
        let second = TripLiveActivities.ReplanOption(
            trip: trip, after: after, line: "1", operatorName: "Transports Publics Genevois",
            departure: departure.addingTimeInterval(240), arrival: arrival.addingTimeInterval(180))
        return [first, second]
    }
}

#Preview("Correspondance serrée et autres suites") {
    ScrollView {
        VStack(spacing: 14) {
            DoubtfulTransferCard(doubt: .init(leg: 0, stop: "Plainpalais", line: "15"),
                                 boarded: {}, missed: {})
            ReplanOptionsCard(options: TripLiveActivities.ReplanOption.previews,
                              chosen: TripLiveActivities.ReplanOption.previews.first?.id) { _ in }
        }
        .padding(15)
    }
    .previewEnvironment()
}

#Preview("Trajet suivi — plus suivi") {
    LiveTripView(key: "preview")
        .previewEnvironment()
}
